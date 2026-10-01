--[[
    HARMONIE - Home Medic : surgery system, authoritative side
    (dedicated server in MP; the same Lua state in single player)

    Begin  -- checks everything again with the server's own view (supplies
              are searched on the doctor, the floor and nearby containers),
              uses up the consumables, and hands out a permit.
    Finish -- the client only reports how each minigame went (0..1 per
              step). The server clamps that, computes the quality and
              decides everything else: stages removed, blood lost, pain,
              the new incision, surgical-site infection, XP. Then syncs.
    Nothing here runs on a tick; it all happens on those two commands.
]]--

require "HARMONIEHomeMedic/Surgery/HM_Surgery"
require "HARMONIEHomeMedic/Surgery/HM_SurgeryRules"

local S = HM_Surgery
S.Server = S.Server or {}
local SV = S.Server
SV.permits = SV.permits or {}
SV.MODULE = "HARMONIE_HM_Surgery"

local function nowMs() return getTimestampMs and getTimestampMs() or 0 end
local function hours() return getGameTime and getGameTime():getWorldAgeHours() or 0 end
local function call(obj, method, ...)
    if not obj or not obj[method] then return nil end
    local ok, v = pcall(obj[method], obj, ...)
    if ok then return v end
    return nil
end
local function rand100() return ZombRand and ZombRand(10000) / 100 or math.random() * 100 end

local function keyOf(player)
    local u = call(player, "getUsername")
    if u and u ~= "" then return u end
    return tostring(call(player, "getPlayerNum") or 0)
end

function SV.reply(doctor, command, args)
    if isServer and isServer() then
        if sendServerCommand then sendServerCommand(doctor, SV.MODULE, command, args or {}) end
    elseif S.Client and S.Client.onServerCommand then
        S.Client.onServerCommand(SV.MODULE, command, args or {})
    end
end

local function findPatient(doctor, args)
    if isServer and isServer() then
        local id = tonumber(args.patientOnline)
        if not id then return doctor end
        local online = getOnlinePlayers and getOnlinePlayers()
        if online then
            for i = 0, online:size() - 1 do
                local p = online:get(i)
                if p and call(p, "getOnlineID") == id then return p end
            end
        end
        return nil
    end
    local n = tonumber(args.patientNum)
    return n and getSpecificPlayer and getSpecificPlayer(n) or doctor
end

local function consentOk(doctor, patient)
    if doctor == patient or not (isServer and isServer()) then return true end
    local f = EHR and EHR.ServerCommands and EHR.ServerCommands.HasActiveExamSession
    if not f then return true end
    local ok, r = pcall(f, doctor, patient, true)
    return ok and r == true
end

-- ------------------------------------------------------------ consumption
local function takeFromWorld(it)
    local wi = call(it, "getWorldItem")
    if not wi then return false end
    local sq = call(wi, "getSquare")
    if sq and isServer and isServer() and sq.transmitRemoveItemFromSquare then pcall(sq.transmitRemoveItemFromSquare, sq, wi) end
    call(wi, "removeFromWorld")
    call(wi, "removeFromSquare")
    call(it, "setWorldItem", nil)
    return true
end

local function removeItem(it)
    if takeFromWorld(it) then return true end
    local c = call(it, "getContainer")
    if not c then return false end
    call(c, "DoRemoveItem", it)
    if isServer and isServer() and sendRemoveItemFromContainer then pcall(sendRemoveItemFromContainer, c, it) end
    return true
end

function SV.consume(it)
    if not it then return end
    local fc = call(it, "getFluidContainer")
    if fc then
        local amount = tonumber(call(fc, "getAmount")) or 0
        call(fc, "adjustAmount", math.max(0, amount - 0.1))
        if isServer and isServer() and sendItemStats then pcall(sendItemStats, it) end
        return
    end
    if call(it, "IsDrainable") then
        if it.UseAndSync then call(it, "UseAndSync") else call(it, "Use") end
        if isServer and isServer() and sendItemStats then pcall(sendItemStats, it) end
        return
    end
    removeItem(it)
end

-- ------------------------------------------------------------ begin
function SV.Begin(doctor, args)
    if not doctor or type(args) ~= "table" then return end
    local deny = function(reason) SV.reply(doctor, "Denied", { reason = reason }) end
    if SandboxVars and SandboxVars.HomeMedic and SandboxVars.HomeMedic.SurgeryEnabled == false then return deny("Disabled") end
    local sid = tostring(args.sid or "")
    local s = S.Surgeries[sid]
    if not s or s.planned then return deny("Unknown") end
    local patient = findPatient(doctor, args)
    if not patient or call(patient, "isDead") then return deny("NoPatient") end
    if S.distance(doctor, patient) > S.MAX_DISTANCE + 0.5 then return deny("TooFar") end
    if not consentOk(doctor, patient) then return deny("Consent") end
    if not S.surgeryUnlocked(doctor, sid) then return deny("Locked") end
    local part = S.partByName(patient, args.part)
    if not part then return deny("NoPart") end

    S.Sources.forget(doctor)
    local ev = S.evaluate(doctor, patient, part, sid)
    if not ev.canStart then return deny("NotReady") end

    -- use up the consumables now (an aborted operation has still used them)
    local dressing = ev.slots.dressing and ev.slots.dressing.item
    local permit = {
        id = tostring(nowMs()) .. "-" .. tostring(ZombRand and ZombRand(100000) or 0),
        sid = sid, doctor = doctor, patient = patient, part = args.part,
        started = nowMs(), asepsis = ev.asepsis or 0, anesthesia = ev.anesthesia or 0, toolQ = ev.toolQ or 1,
        aspiration = ev.aspiration or 0,
        dressingPower = tonumber(call(dressing, "getBandagePower")) or 2,
        dressingAlcohol = call(dressing, "isAlcoholic") == true or (ev.slots.dressing and ev.slots.dressing.q or 0) >= 1,
        dressingType = call(dressing, "getFullType"),
    }
    for _, slotId in ipairs(s.supplies) do
        local fill = ev.slots[slotId]
        if fill and S.Supplies[slotId].kind == "use" then SV.consume(fill.item) end
    end
    -- transfusion during the operation (the bag was used up above)
    if ev.slots.blood then
        local ptype = S.bloodType(patient)
        permit.transfusion = { kind = "blood", donor = ev.slots.blood.donor,
            compatible = S.compatible(ev.slots.blood.donor, ptype) }
    elseif ev.slots.saline then
        permit.transfusion = { kind = "saline" }
    end
    S.Sources.forget(doctor)
    SV.permits[keyOf(doctor)] = permit

    local d = S.difficulty(doctor, patient, permit.anesthesia, permit.toolQ)
    SV.reply(doctor, "Begin", { permit = permit.id, sid = sid, part = args.part,
        skill = d.skill, shake = d.shake, tool = d.tool })
end

-- ------------------------------------------------------------ outcome
local function clearWoundInfection(patient, part)
    local W = EHR and EHR.WoundInfection
    local name = S.partName(part)
    local data = W and W.GetData and W.GetData(patient)
    if data and data.parts then data.parts[name] = nil end
    if W and W.ClearPartSymptomPain then pcall(W.ClearPartSymptomPain, patient, name) end
    if W and W.ClearVanillaInfection then pcall(W.ClearVanillaInfection, part, "harmonie-surgery")
    else call(part, "setInfectedWound", false) end
end

local function removeForeignBodies(part)
    if call(part, "haveBullet") == true then call(part, "setHaveBullet", false, 0) end
    if call(part, "haveGlass") == true then call(part, "setHaveGlass", false) end
end

-- Gene therapy delivered surgically: EHR's own chance, better with a good operation.
local function experimentalKnox(patient, q)
    local K = EHR and EHR.KnoxCure
    if not K or not K.IsInfected or not K.IsInfected(patient) then return "none" end
    local base = K.GetGeneTherapyChance and K.GetGeneTherapyChance(patient) or 50
    local chance = math.max(5, math.min(95, base + (q - 0.5) * 40))
    if rand100() < chance then
        pcall(K.CureInfection, patient)
        local data = K.GetData and K.GetData(patient)
        if data then
            local immune = K.IsPatientZeroTraitEnabled and K.IsPatientZeroTraitEnabled()
            data.geneTherapySurvivor = true
            data.geneTherapyImmune = immune
            data.immunityTraitGranted = false
            if immune and K.GrantImmunityTrait then pcall(K.GrantImmunityTrait, patient, data) end
        end
        if K.ApplyGeneTherapySideEffects then pcall(K.ApplyGeneTherapySideEffects, patient) end
        return "cured"
    end
    if q < S.SUCCESS then
        if EHR.RecordDeathCause then pcall(EHR.RecordDeathCause, patient, "Gene therapy rejection during experimental surgery") end
        call(patient, "setHealth", 0)
        return "rejected"
    end
    return "failed"
end

local function amputate(doctor, patient, part, q)
    local limb = S.tocLimb(part)
    if not limb then return false end
    local ok, AH = pcall(require, "TOC/Handlers/AmputationHandler")
    if not ok or not AH then return false end
    local done = pcall(function()
        local h = AH:new(doctor, patient, limb)
        h:execute(q < S.EXCELLENT)
        h:close()
    end)
    return done
end

local function clamp01(v) v = tonumber(v) or 0; if v < 0 then return 0 elseif v > 1 then return 1 end return v end

function SV.Finish(doctor, args)
    if not doctor or type(args) ~= "table" then return end
    local key = keyOf(doctor)
    local permit = SV.permits[key]
    if not permit or permit.id ~= args.permit then return end
    SV.permits[key] = nil
    if nowMs() - permit.started > S.PERMIT_MS then return end
    local s = S.Surgeries[permit.sid]
    local patient = permit.patient
    local part = S.partByName(patient, permit.part)
    if not s or not part or call(patient, "isDead") then return end

    -- scores: clamp, and a step finished impossibly fast counts as failed
    local scores = {}
    local minMs = 1500 * #s.steps
    local tooFast = (nowMs() - permit.started) < minMs
    for n = 1, #s.steps do
        scores[n] = tooFast and 0 or clamp01(args.scores and args.scores[n])
    end
    local aborted = args.aborted == true
    local q = S.quality(permit.sid, scores, permit.toolQ)
    if aborted then q = math.min(q, S.SUCCESS - 0.01) end
    local function stepScore(pid)
        for n, p in ipairs(s.steps) do if p == pid then return scores[n] end end
        return nil
    end

    -- 1. what it treats
    local changes = {}
    local amputated = false
    if q >= S.SUCCESS then
        local md = patient:getModData()
        md.HARMONIE_Surgery = md.HARMONIE_Surgery or { cool = {} }
        md.HARMONIE_Surgery.cool = md.HARMONIE_Surgery.cool or {}
        local factor = q >= S.EXCELLENT and S.EXCELLENT_TREAT or 1
        for _, ind in ipairs(S.indications(patient, part, permit.sid)) do
            if not ind.cool then
                local t = s.targets[ind.id] or {}
                local change
                if ind.id == "wound_infection" then
                    clearWoundInfection(patient, part); change = "cleared"
                elseif ind.id == "foreign_body" then
                    removeForeignBodies(part); change = "removed"
                elseif ind.id == "knox" then
                    change = experimentalKnox(patient, q)
                elseif ind.id == "knox_bite" or ind.id == "necrosis" then
                    if not amputated then amputated = amputate(doctor, patient, part, q) end
                    change = amputated and "amputated" or "failed"
                elseif t.cure then
                    -- an illness that heals by itself (concussion): the operation ends it now
                    local Dz = EHR and EHR.Disease
                    if Dz and Dz.Cure and pcall(Dz.Cure, patient, ind.id) then change = "cured" else change = "failed" end
                elseif t.treat then
                    local h = math.floor(t.treat * factor + 0.5)
                    if S.Rules.treat(patient, ind.id, h, permit.sid) then
                        changes[#changes + 1] = { id = ind.id, kind = "treat", hours = h }
                        md.HARMONIE_Surgery.cool[S.coolKey(ind.id, part)] = hours()
                    end
                end
                if change then
                    changes[#changes + 1] = { id = ind.id, kind = change }
                    md.HARMONIE_Surgery.cool[S.coolKey(ind.id, part)] = hours()
                end
            end
        end
    end

    -- 2. what it costs
    local hemo = stepScore("P02") or 0.5
    local incision = stepScore("P01") or 0.5
    local blood = math.floor(s.bloodLoss * (0.6 + (1 - hemo) * 0.9 + (1 - incision) * 0.4) + 0.5)
    if EHR and EHR.Blood and EHR.Blood.ModifyBloodVolume then pcall(EHR.Blood.ModifyBloodVolume, patient, -blood) end
    -- the transfusion given during the operation
    local transfusion
    local B = EHR and EHR.Blood
    if permit.transfusion and B and B.ModifyBloodVolume then
        local bd = patient:getModData().EHR_Blood
        if permit.transfusion.kind == "blood" then
            local amt = tonumber(B.TRANSFUSION_AMOUNT) or 450
            pcall(B.ModifyBloodVolume, patient, amt)
            if bd then bd.transfusedBlood = (bd.transfusedBlood or 0) + amt end
            transfusion = { kind = "blood", amount = amt, ok = permit.transfusion.compatible == true, donor = permit.transfusion.donor }
            if not permit.transfusion.compatible then
                -- wrong blood type: acute haemolytic transfusion reaction
                local Dz = EHR and EHR.Disease
                local dd = Dz and Dz.GetDiseaseData and Dz.GetDiseaseData(patient)
                if Dz and Dz.Contract and not (dd and dd.active and dd.active.ahtr) then pcall(Dz.Contract, patient, "ahtr") end
            end
        else
            local amt = tonumber(B.SALINE_AMOUNT) or 500
            pcall(B.ModifyBloodVolume, patient, amt)
            if bd then bd.transfusedSaline = (bd.transfusedSaline or 0) + amt end
            transfusion = { kind = "saline", amount = amt }
        end
    end
    local pain = math.floor(s.pain * (1 - 0.8 * (permit.anesthesia or 0)) + 0.5)
    call(part, "setAdditionalPain", math.min(100, (tonumber(call(part, "getAdditionalPain")) or 0) + pain))

    -- 3. the incision (only operations that open the skin; TOC dresses an amputation stump itself)
    local suture = stepScore("P08") or 0
    if not amputated and stepScore("P01") ~= nil then
        call(part, "setCut", true)
        call(part, "setCutTime", math.max(tonumber(call(part, "getCutTime")) or 0, 8 + 14 * (1 - suture)))
        if suture >= 0.5 and not aborted then
            call(part, "setStitched", true)
            call(part, "setStitchTime", 0)
            call(part, "setBleeding", false)
        else
            call(part, "setBleeding", true)
            call(part, "setBleedingTime", math.max(tonumber(call(part, "getBleedingTime")) or 0, 2 + 6 * (1 - hemo)))
        end
        if permit.dressingType then
            pcall(part.setBandaged, part, true, permit.dressingPower or 2, permit.dressingAlcohol == true, permit.dressingType)
        end
    end

    -- 4. surgical-site infection
    local clean = stepScore("P03") or 0.5
    local ssi = (1 - (permit.asepsis or 0)) * (1 - clean) * 60 + (aborted and 15 or 0)
    if stepScore("P01") == nil then ssi = ssi * 0.25 end            -- a needle, not an incision
    local infected = false
    local D = EHR and EHR.Disease
    local data = D and D.GetDiseaseData and D.GetDiseaseData(patient)
    if rand100() < ssi and D and D.Contract and not (data and data.active and data.active.cellulitis) then
        pcall(D.Contract, patient, "cellulitis")
        infected = true
    end

    -- 4b. aspiration: operated on a full stomach
    local aspirated = false
    if (permit.aspiration or 0) > 0 and rand100() < permit.aspiration then
        aspirated = true
        if D and D.Contract and not (data and data.active and data.active.pneumonia) then pcall(D.Contract, patient, "pneumonia") end
        local stats = call(patient, "getStats")
        if stats and CharacterStat and CharacterStat.SICKNESS then
            pcall(function() stats:set(CharacterStat.SICKNESS, math.min(1, (stats:get(CharacterStat.SICKNESS) or 0) + 0.25)) end)
        end
    end

    -- 5. experience
    local xp = math.floor(10 + 35 * q + 0.5)
    if EHR and EHR.SkillXP and EHR.SkillXP.AwardXP then pcall(EHR.SkillXP.AwardXP, doctor, xp, "surgery", nil)
    elseif Perks and Perks.Doctor then
        local xpObj = call(doctor, "getXp")
        if xpObj then pcall(xpObj.AddXP, xpObj, Perks.Doctor, xp) end
    end

    -- 6. sync
    if syncBodyPart then pcall(syncBodyPart, part, 0xFFFFFFFFFFF) end
    local bd = call(patient, "getBodyDamage")
    if bd and bd.DamageUpdate then pcall(bd.DamageUpdate, bd) end
    if EHR and EHR.SafeTransmitModData then pcall(EHR.SafeTransmitModData, patient) end

    local grade = aborted and "Aborted" or (q >= S.EXCELLENT and "Excellent" or (q >= S.SUCCESS and "Success" or "Failed"))
    if EHR and EHR.Locale and EHR.Locale.Say then
        pcall(EHR.Locale.Say, patient, S.T("Say_" .. grade, ""))
    end
    SV.reply(doctor, "Result", { permit = permit.id, sid = permit.sid, quality = q, grade = grade,
        changes = changes, blood = blood, pain = pain, infected = infected, aspirated = aspirated, transfusion = transfusion, xp = xp, scores = scores })
end

function SV.Abort(doctor, args)
    -- the client closed the window before finishing: treat as an aborted finish
    args = type(args) == "table" and args or {}
    args.aborted = true
    SV.Finish(doctor, args)
end

local function onClientCommand(module, command, player, args)
    if module ~= SV.MODULE then return end
    if command == "Begin" then SV.Begin(player, args)
    elseif command == "Finish" then SV.Finish(player, args)
    elseif command == "Abort" then SV.Abort(player, args) end
end

if Events and Events.OnClientCommand and not SV.registered then
    SV.registered = true
    Events.OnClientCommand.Add(onClientCommand)
end

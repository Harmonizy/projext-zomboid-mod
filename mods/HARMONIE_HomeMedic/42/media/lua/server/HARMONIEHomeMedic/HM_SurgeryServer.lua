--[[
    HARMONIE - Home Medic : surgery system, authoritative side
    (dedicated server in MP; the same Lua state in single player)

    Begin  -- checks everything again with the server's own view (supplies
              are searched on the doctor, the floor and nearby containers),
              asks the PATIENT for consent with the list of risks (owner,
              2026-10-10), and only after a yes uses up the consumables and
              hands out a permit.
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
SV.consents = SV.consents or {}   -- patient key -> { id, doctor, args, at }
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

-- ------------------------------------------------------------ consent
-- yes when: on yourself and you accepted the form (args.consent), or the
-- patient just answered yes to THIS request (args.consentId, set by
-- SV.ConsentReply -- never trusted from the doctor's own message)
function SV.consentGiven(doctor, patient, args)
    if doctor == patient then return args.consent == true end
    if not (isServer and isServer()) then return args.consent == true end   -- single player, split screen: one screen, one form
    return args.consentOk == true
end

function SV.ConsentReply(patient, args)
    if type(args) ~= "table" then return end
    local key = keyOf(patient)
    local c = SV.consents[key]
    if not c or c.id ~= args.id then
        HMLog("Surgery", "%s: consent answer IGNORED -- no matching request", HMLogName(patient))
        return
    end
    SV.consents[key] = nil
    local doctor = c.doctor
    if nowMs() - c.at > (S.CONSENT_SECONDS + 5) * 1000 then
        HMLog("Surgery", "%s: consent answer too late", HMLogName(patient))
        SV.reply(doctor, "Denied", { reason = "ConsentTimeout" })
        return
    end
    if args.yes ~= true then
        HMLog("Surgery", "%s DECLINED %s by %s", HMLogName(patient), tostring(c.args and c.args.sid), HMLogName(doctor))
        SV.reply(doctor, "Denied", { reason = "ConsentDeclined" })
        return
    end
    HMLog("Surgery", "%s accepted %s by %s", HMLogName(patient), tostring(c.args and c.args.sid), HMLogName(doctor))
    local a = {}
    for k, v in pairs(c.args or {}) do a[k] = v end
    a.fromClient = nil
    a.consentOk = true
    SV.Begin(doctor, a)
end

-- ------------------------------------------------------------ begin
function SV.Begin(doctor, args)
    if not doctor or type(args) ~= "table" then return end
    if args.fromClient then args.consentOk = nil end
    local deny = function(reason)
        HMLog("Surgery", "%s: surgery %s on %s DENIED (%s)", HMLogName(doctor), tostring(args and args.sid), tostring(args and args.part), tostring(reason))
        SV.reply(doctor, "Denied", { reason = reason })
    end
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

    -- consent: the patient decides, knowing the risks. On yourself the
    -- client showed you the same form (args.consent); another player gets
    -- the form on their own screen and answers with "ConsentReply".
    if not SV.consentGiven(doctor, patient, args) then
        if doctor == patient or not (isServer and isServer()) then return deny("NoConsent") end
        local risks = S.risks(doctor, patient, sid, ev)
        local id = tostring(nowMs()) .. "-" .. tostring(ZombRand and ZombRand(100000) or 0)
        SV.consents[keyOf(patient)] = { id = id, doctor = doctor, args = args, at = nowMs() }
        HMLog("Surgery", "%s asks %s for consent to %s on %s (%d risks, worst level %d)", HMLogName(doctor), HMLogName(patient),
            tostring(sid), tostring(args.part), #risks, S.riskLevel(risks))
        if sendServerCommand then
            sendServerCommand(patient, SV.MODULE, "ConsentAsk", { id = id, sid = sid, part = args.part,
                doctor = call(doctor, "getDisplayName") or keyOf(doctor), risks = risks, seconds = S.CONSENT_SECONDS })
        end
        SV.reply(doctor, "AwaitConsent", { sid = sid })
        return
    end

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

    -- the instruments only set the starting quality (S.quality), the games
    -- play the same with any of them (request 2026-10-02)
    -- skill against the recommended level sets how hard the games are; each
    -- step also handles like its own instrument (Procedures[].tool)
    local d = S.difficulty(doctor, patient, permit.anesthesia, 1, sid, ev.slots)
    permit.gap = d.gap
    HMLog("Surgery", "%s begins %s on %s's %s (First Aid gap %s, skill %.2f, k %.2f, start quality %s, anesthesia %s)", HMLogName(doctor), tostring(sid), HMLogName(patient),
        tostring(args.part), tostring(d.gap), tonumber(d.skill) or -1, tonumber(d.k) or -1, tostring(permit.toolQ), tostring(permit.anesthesia))
    SV.reply(doctor, "Begin", { permit = permit.id, sid = sid, part = args.part,
        skill = d.skill, shake = d.shake, tool = d.tool, k = d.k, under = d.under, gap = d.gap, tools = d.tools,
        startQ = permit.toolQ })
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

local function amputate(doctor, patient, part, q, sawDamage)
    local limb = S.tocLimb(part)
    if not limb then return false end
    local ok, AH = pcall(require, "TOC/Handlers/AmputationHandler")
    if not ok or not AH then return false end
    local done = pcall(function()
        local h = AH:new(doctor, patient, limb)
        -- a dirty (infected-risk) stump unless excellent with a clean bone cut
        h:execute(q < S.EXCELLENT or (tonumber(sawDamage) or 0) > 0.3)
        h:close()
    end)
    return done
end

local function clamp01(v) v = tonumber(v) or 0; if v < 0 then return 0 elseif v > 1 then return 1 end return v end

-- the step's reported side effects, only known keys, clamped
local function cleanEffects(raw, n)
    local out = {}
    for i = 1, n do
        local e = type(raw) == "table" and raw[i] or nil
        local c = {}
        if type(e) == "table" then
            for _, key in ipairs(S.EFFECT_KEYS) do
                if e[key] ~= nil then c[key] = clamp01(e[key]) end
            end
        end
        out[i] = c
    end
    return out
end

function SV.Finish(doctor, args)
    if not doctor or type(args) ~= "table" then return end
    local key = keyOf(doctor)
    local permit = SV.permits[key]
    if not permit or permit.id ~= args.permit then
        HMLog("Surgery", "%s: finish IGNORED -- no matching permit (have %s, got %s)", HMLogName(doctor), tostring(permit and permit.id), tostring(args.permit))
        return
    end
    SV.permits[key] = nil
    if nowMs() - permit.started > S.PERMIT_MS then HMLog("Surgery", "%s: finish IGNORED -- permit expired", HMLogName(doctor)); return end
    local s = S.Surgeries[permit.sid]
    local patient = permit.patient
    local part = S.partByName(patient, permit.part)
    if not s or not part or call(patient, "isDead") then
        HMLog("Surgery", "%s: finish IGNORED -- %s", HMLogName(doctor), not s and "unknown surgery" or (not part and "body part gone" or "patient dead"))
        return
    end

    -- scores: clamp, and a step finished impossibly fast counts as failed
    local scores = {}
    local minMs = 1500 * #s.steps
    local tooFast = (nowMs() - permit.started) < minMs
    local played = 0
    for n = 1, #s.steps do
        scores[n] = tooFast and 0 or clamp01(args.scores and args.scores[n])
        if args.scores and args.scores[n] ~= nil then played = played + 1 end
    end
    local effects = cleanEffects(args.effects, #s.steps)
    local aborted = args.aborted == true
    if tooFast then HMLog("Surgery", "%s: steps finished impossibly fast -- all scored 0", HMLogName(doctor)); played = #s.steps end
    local q = S.quality(permit.sid, scores, permit.toolQ)
    -- a serious complication can happen to anyone; far more often below
    -- the recommended level (S.complicationChance)
    local complication = false
    if not aborted and played > 0 and rand100() < S.complicationChance(permit.gap or 0) then
        complication = true
        q = math.max(0, q - S.COMPLICATION_COST)
        HMLog("Surgery", "%s: COMPLICATION during %s (gap %s) -- quality -%.2f", HMLogName(doctor), tostring(permit.sid), tostring(permit.gap), S.COMPLICATION_COST)
    end
    if aborted then q = math.min(q, S.SUCCESS - 0.01) end
    local function stepScore(pid)
        for n, p in ipairs(s.steps) do if p == pid then return scores[n] end end
        return nil
    end
    local function stepEffect(pid, k)
        for n, p in ipairs(s.steps) do if p == pid then return effects[n][k] end end
        return nil
    end
    -- the worst / summed value of one effect over all steps
    local function worst(k)
        local m
        for n = 1, #s.steps do local v = effects[n][k]; if v and (not m or v > m) then m = v end end
        return m
    end
    local function total(k)
        local t = 0
        for n = 1, #s.steps do t = t + (effects[n][k] or 0) end
        return math.min(1, t)
    end
    local tissue = total("tissue")
    local bleed = stepEffect("P02", "bleed") or worst("bleed") or (1 - (stepScore("P02") or 0.5))
    -- slower treatment when the job was left half done (pus, fluid, organ
    -- damage, a poor dialysis): up to x1.8
    local slow = 1 + 0.6 * (worst("residual") or 0) + 0.5 * (worst("organ") or 0)
    if stepScore("P11") then slow = slow + 0.5 * (1 - stepScore("P11")) end
    slow = math.min(1.8, slow)
    local notes = {}

    -- 1. what it treats
    local changes = {}
    local amputated = false
    if q >= S.SUCCESS then
        local md = patient:getModData()
        md.HARMONIE_Surgery = md.HARMONIE_Surgery or { cool = {} }
        md.HARMONIE_Surgery.cool = md.HARMONIE_Surgery.cool or {}
        local factor = (q >= S.EXCELLENT and S.EXCELLENT_TREAT or 1) * slow
        for _, ind in ipairs(S.indications(patient, part, permit.sid)) do
            if not ind.cool and not ind.undiagnosed then
                local t = s.targets[ind.id] or {}
                local change
                if ind.id == "wound_infection" then
                    -- dead tissue left behind keeps the infection going
                    if (stepEffect("P04", "residual") or 0) >= 0.5 then change = "failed"
                    else clearWoundInfection(patient, part); change = "cleared" end
                elseif ind.id == "foreign_body" then
                    -- only what really came out (P06)
                    if (stepEffect("P06", "residual") or 0) >= 0.5 then change = "failed"
                    else removeForeignBodies(part); change = "removed" end
                elseif ind.id == "knox" then
                    change = experimentalKnox(patient, q)
                elseif ind.id == "knox_bite" or ind.id == "necrosis" then
                    if not amputated then amputated = amputate(doctor, patient, part, q, stepEffect("P07", "tissue")) end
                    change = amputated and "amputated" or "failed"
                elseif t.cure then
                    -- an illness that heals by itself (concussion): the operation
                    -- ends it now -- unless the clot stayed or the brain was hurt
                    local Dz = EHR and EHR.Disease
                    if (worst("residual") or 0) >= 0.5 or (worst("neuro") or 0) >= 0.5 then change = "failed"
                    elseif Dz and Dz.Cure and pcall(Dz.Cure, patient, ind.id) then change = "cured" else change = "failed" end
                elseif t.treat then
                    -- parasites left in the muscle (P06) are not treated
                    if permit.sid == "parasite_extraction" and (stepEffect("P06", "residual") or 0) >= 0.5 then
                        change = "failed"
                    else
                        local h = math.floor(t.treat * factor + 0.5)
                        if S.Rules.treat(patient, ind.id, h, permit.sid) then
                            changes[#changes + 1] = { id = ind.id, kind = "treat", hours = h }
                            md.HARMONIE_Surgery.cool[S.coolKey(ind.id, part)] = hours()
                        end
                    end
                end
                if change then
                    changes[#changes + 1] = { id = ind.id, kind = change }
                    md.HARMONIE_Surgery.cool[S.coolKey(ind.id, part)] = hours()
                end
            end
        end
        if slow > 1.05 then notes[#notes + 1] = { k = "Slow", a = math.floor((slow - 1) * 100 + 0.5) } end
    end

    -- 2. what it costs: blood by grade (S.GRADES: -10% excellent ... -50%
    -- failed, of full volume), in proportion to how far it got
    local progress = #s.steps > 0 and played / #s.steps or 1
    local gradeId, lossShare = S.gradeOf(q)
    local blood = 0
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
    local bdc = patient:getModData().EHR_Blood
    local maxV = type(bdc) == "table" and tonumber(bdc.maxVolume) or nil
    local curV = type(bdc) == "table" and tonumber(bdc.currentVolume) or nil
    local bloodAfter
    if B and B.ModifyBloodVolume and maxV and curV and maxV > 0 then
        local loss = math.floor(lossShare * maxV * progress + 0.5)
        if loss > 0 then pcall(B.ModifyBloodVolume, patient, -loss) end
        blood = loss
        local nowV = tonumber(bdc.currentVolume) or (curV - loss)
        bloodAfter = nowV / maxV
        HMLog("Surgery", "%s: blood %.0f%% -> %.0f%% (grade %s -%d%%, progress %.2f)", HMLogName(patient),
            curV / maxV * 100, bloodAfter * 100, tostring(gradeId), math.floor(lossShare * 100 + 0.5), progress)
    end
    -- pain: the operation, plus tissue hurt, a craniotomy that slipped, tight stitches
    local pain = s.pain * (1 - 0.8 * (permit.anesthesia or 0)) + 25 * tissue + 30 * (worst("neuro") or 0) + 10 * (worst("tension") or 0)
    pain = math.floor(math.min(100, pain) + 0.5)
    call(part, "setAdditionalPain", math.min(100, (tonumber(call(part, "getAdditionalPain")) or 0) + pain))
    if (worst("neuro") or 0) >= 0.3 then notes[#notes + 1] = { k = "Neuro", a = math.floor((worst("neuro") or 0) * 100 + 0.5) } end
    if (worst("misplace") or 0) >= 0.5 then notes[#notes + 1] = { k = "Misplaced", a = 0 } end

    -- 3. the incision (only operations that open the skin; TOC dresses an amputation stump itself)
    local suture = stepScore("P08") or 0
    local gapE = stepEffect("P08", "gap") or 0
    if not amputated and stepScore("P01") ~= nil then
        call(part, "setCut", true)
        -- damaged tissue and a gaping closure heal slower
        call(part, "setCutTime", math.max(tonumber(call(part, "getCutTime")) or 0, 8 + 14 * (1 - suture) + 10 * tissue + 6 * gapE))
        if suture >= 0.5 and not aborted then
            call(part, "setStitched", true)
            call(part, "setStitchTime", 0)
            call(part, "setBleeding", gapE >= 0.6)
            if gapE >= 0.6 then call(part, "setBleedingTime", 1 + 3 * gapE) end
        else
            call(part, "setBleeding", true)
            call(part, "setBleedingTime", math.max(tonumber(call(part, "getBleedingTime")) or 0, 2 + 6 * bleed))
        end
        if permit.dressingType then
            pcall(part.setBandaged, part, true, permit.dressingPower or 2, permit.dressingAlcohol == true, permit.dressingType)
        end
    elseif stepScore("P10") ~= nil and (worst("misplace") or 0) >= 0.5 then
        -- a misplaced line: a bruise that bleeds a little and hurts
        call(part, "setScratched", true, true)
    end

    -- 4. surgical-site infection: asepsis, dirt left (P03), dead tissue left
    -- (P04), tissue hurt; a needle is not an incision but is not risk-free
    local clean = stepScore("P03")
    local dirt = stepEffect("P03", "dirt") or (clean and (1 - clean)) or 0.5
    local contamination = math.min(1, dirt + 0.5 * (stepEffect("P04", "residual") or 0) + 0.3 * tissue)
    local ssi = (1 - (permit.asepsis or 0)) * contamination * 60 + (aborted and 15 or 0)
    if stepScore("P01") == nil then ssi = ssi * 0.5 + 10 * (worst("misplace") or 0) end
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
    if syncBodyPart then HMLogErr("Surgery", "syncBodyPart", pcall(syncBodyPart, part, 0xFFFFFFFFFFF)) end
    local bd = call(patient, "getBodyDamage")
    if bd and bd.DamageUpdate then HMLogErr("Surgery", "DamageUpdate", pcall(bd.DamageUpdate, bd)) end
    if EHR and EHR.SafeTransmitModData then HMLogErr("Surgery", "SafeTransmitModData", pcall(EHR.SafeTransmitModData, patient)) end

    local grade = aborted and "Aborted" or gradeId
    if EHR and EHR.Locale and EHR.Locale.Say then
        pcall(EHR.Locale.Say, patient, S.T("Say_" .. grade, ""))
    end
    HMLog("Surgery", "%s finished %s on %s: %s (quality %.2f, %d changes, amputated %s, complication %s, tissue %.2f, ssi %.0f%%)", HMLogName(doctor), tostring(permit.sid), HMLogName(patient),
        grade, tonumber(q) or -1, #changes, tostring(amputated), tostring(complication), tissue, ssi)
    SV.reply(doctor, "Result", { permit = permit.id, sid = permit.sid, quality = q, grade = grade,
        changes = changes, blood = blood, bloodAfter = bloodAfter, pain = pain, infected = infected, aspirated = aspirated,
        transfusion = transfusion, xp = xp, scores = scores, complication = complication, notes = notes })
end

function SV.Abort(doctor, args)
    -- the client closed the window before finishing: treat as an aborted finish
    args = type(args) == "table" and args or {}
    args.aborted = true
    SV.Finish(doctor, args)
end

local function onClientCommand(module, command, player, args)
    if module ~= SV.MODULE then return end
    if command == "Begin" then
        if type(args) == "table" then args.fromClient = true end
        SV.Begin(player, args)
    elseif command == "ConsentReply" then SV.ConsentReply(player, args)
    elseif command == "Finish" then SV.Finish(player, args)
    elseif command == "Abort" then HMLog("Surgery", "%s closed the surgery window -- aborted", HMLogName(player)); SV.Abort(player, args)
    else HMLog("Surgery", "%s sent unknown command %s", HMLogName(player), tostring(command)) end
end

if Events and Events.OnClientCommand and not SV.registered then
    SV.registered = true
    Events.OnClientCommand.Add(onClientCommand)
end

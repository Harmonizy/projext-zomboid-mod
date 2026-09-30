--[[
    HARMONIE - Home Medic : surgery system core (shared: client + server)

    * Sources   -- supplies are found on the doctor (bags too), on the floor
                   and in any container within S.REACH tiles (request: "การใช้
                   อุปกรณ์หรือวัตถุดิบให้สามารถดูบนพื้นหรือในกล่องรอบตัวและใน
                   inventory ได้"). The server consumes from wherever they are.
    * Unlocks   -- a procedure needs First Aid at its tier and, if it lists
                   diseases, EHR knowledge of one of them.
    * Indication-- what the operation would treat on this body part.
    * Readiness -- one row per check (indication, skill, each supply,
                   asepsis, anesthesia, blood, distance, cooldown) for the
                   "pre-op" window; the server runs the same checks again.
    * Quality   -- step scores (0..1 from the minigames) x tool quality.
    Pure data / questions only; changes happen in server/HARMONIEHomeMedic/HM_SurgeryServer.lua.
]]--

require "HARMONIEHomeMedic/Surgery/HM_SurgeryData"

local S = HM_Surgery

-- ---------------------------------------------------------------- text
function S.T(key, fallback, ...)
    local k = "UI_HomeMedic_Surg_" .. key
    local t = getText and getText(k)
    if not t or t == k or t == "?" then t = fallback or key end
    local args = { ... }
    for i = 1, #args do t = t:gsub("%%" .. i, (tostring(args[i]):gsub("%%", "%%%%"))) end
    return t
end

local function now() return getGameTime and getGameTime():getWorldAgeHours() or 0 end

local function call(obj, method, ...)
    if not obj or not obj[method] then return nil end
    local ok, v = pcall(obj[method], obj, ...)
    if ok then return v end
    return nil
end

-- ---------------------------------------------------------------- sources
S.Sources = S.Sources or {}
local Src = S.Sources

local function collect(player)
    local conts, floor = {}, {}
    local inv = call(player, "getInventory")
    if inv then conts[#conts + 1] = { c = inv, where = "inv" } end
    local sq = call(player, "getCurrentSquare")
    local cell = getCell and getCell()
    if sq and cell and S.REACH > 0 then
        local x, y, z = sq:getX(), sq:getY(), sq:getZ()
        for dx = -S.REACH, S.REACH do
            for dy = -S.REACH, S.REACH do
                local s = cell:getGridSquare(x + dx, y + dy, z)
                if s then
                    local objs = s:getObjects()
                    for i = 0, objs:size() - 1 do
                        local o = objs:get(i)
                        local n = o and call(o, "getContainerCount") or 0
                        for k = 0, n - 1 do
                            local c = call(o, "getContainerByIndex", k)
                            if c then conts[#conts + 1] = { c = c, where = "box" } end
                        end
                    end
                    local w = call(s, "getWorldObjects")
                    if w then
                        for i = 0, w:size() - 1 do
                            local it = call(w:get(i), "getItem")
                            if it then floor[#floor + 1] = it end
                        end
                    end
                end
            end
        end
    end
    return { conts = conts, floor = floor }
end

local cache = {}
function Src.get(player)
    local client = not (isServer and isServer())
    local t = getTimestampMs and getTimestampMs() or 0
    local c = client and cache[player]
    if c and t - c.at < 500 then return c.src end
    local src = collect(player)
    if client then cache[player] = { at = t, src = src } end
    return src
end
function Src.forget(player) if player then cache[player] = nil else cache = {} end end

-- every item: fn(item, where) -- bags inside containers too (3 deep); stop when fn returns true
function Src.each(src, fn)
    local function walk(cont, where, depth)
        local items = cont and call(cont, "getItems")
        if not items then return false end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then
                if fn(it, where) then return true end
                if depth < 3 and instanceof and instanceof(it, "InventoryContainer") then
                    if walk(it:getInventory(), where, depth + 1) then return true end
                end
            end
        end
        return false
    end
    for _, c in ipairs(src.conts) do
        if walk(c.c, c.where, 0) then return end
    end
    for _, it in ipairs(src.floor) do
        if fn(it, "floor") then return end
    end
end

-- ---------------------------------------------------------------- item tests
local function fullType(it) return call(it, "getFullType") or "" end
local function isBroken(it) return call(it, "isBroken") == true end

local function hasUses(it)
    if call(it, "IsDrainable") then
        local u = call(it, "getCurrentUsesFloat")
        if u ~= nil then return u > 0.001 end
        u = call(it, "getCurrentUses")
        if u ~= nil then return u > 0 end
    end
    return true
end

local MATCH = {
    knife = function(it)
        local ty = (call(it, "getType") or ""):lower()
        return ty:find("knife", 1, true) ~= nil and not ty:find("butter", 1, true)
    end,
    bandage = function(it)
        return call(it, "isCanBandage") == true or (tonumber(call(it, "getBandagePower")) or 0) > 0
    end,
    disinfectant = function(it)
        -- same test as EHR's health panel: a fluid that is >= 40% alcohol, or an old-style alcohol drainable
        local fc = call(it, "getFluidContainer")
        if fc then
            local amount = tonumber(call(fc, "getAmount")) or 0
            if amount <= 0.15 then return false end
            local props = call(fc, "getProperties")
            local alcohol = tonumber(props and call(props, "getAlcohol")) or 0
            return (alcohol / amount + 0.001) >= 0.4
        end
        return call(it, "IsDrainable") == true and tonumber(call(it, "getAlcoholPower")) == 4.0
    end,
}

local function optionMatches(opt, it)
    if isBroken(it) or not hasUses(it) then return false end
    if opt.type then return fullType(it) == opt.type end
    return opt.match and MATCH[opt.match] and MATCH[opt.match](it) or false
end

local function findType(src, t)
    local found, where
    Src.each(src, function(it, w)
        if fullType(it) == t and not isBroken(it) then found, where = it, w; return true end
    end)
    return found, where
end

-- Best option for a supply slot: { slot, opt, item, where, need, needWhere, q } or nil
function S.fillSlot(src, slotId)
    local slot = S.Supplies[slotId]
    if not slot then return nil end
    for _, opt in ipairs(slot.options) do
        local item, where
        Src.each(src, function(it, w)
            if optionMatches(opt, it) then item, where = it, w; return true end
        end)
        if item then
            local need, needWhere
            if opt.needs then need, needWhere = findType(src, opt.needs) end
            if not opt.needs or need then
                return { slot = slotId, opt = opt, item = item, where = where, need = need, needWhere = needWhere, q = opt.q or 1 }
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- people
function S.firstAid(player)
    if not player or not Perks or not Perks.Doctor then return 0 end
    return tonumber(call(player, "getPerkLevel", Perks.Doctor)) or 0
end

function S.knows(player, diseaseId)
    local F = EHR and EHR.DiseaseFlyers
    if F and F.HasMedicalKnowledge then
        local ok, r = pcall(F.HasMedicalKnowledge, player, diseaseId, 8)
        if ok then return r == true end
    end
    return S.firstAid(player) >= 8
end

-- procedure unlocked for `doctor`? -> ok, needFirstAid, missingKnowledge(list or nil)
function S.procedureUnlocked(doctor, pid)
    local p = S.Procedures[pid]
    if not p or p.planned then return false, 99, nil end
    local need = S.TIERS[p.tier].firstAid
    local fa = S.firstAid(doctor)
    local knowOk = true
    if p.knowledge then
        knowOk = false
        for _, id in ipairs(p.knowledge) do
            if S.knows(doctor, id) then knowOk = true; break end
        end
    end
    return fa >= need and knowOk, need, (not knowOk) and p.knowledge or nil
end

function S.surgeryUnlocked(doctor, sid)
    local s = S.Surgeries[sid]
    if not s or s.planned then return false end
    if S.firstAid(doctor) < S.TIERS[s.tier].firstAid then return false end
    for _, pid in ipairs(s.steps) do
        if not S.procedureUnlocked(doctor, pid) then return false end
    end
    return true
end

-- ---------------------------------------------------------------- body part
function S.partName(bodyPart)
    local t = call(bodyPart, "getType")
    if not t then return nil end
    if BodyPartType and BodyPartType.ToString then
        local ok, s = pcall(BodyPartType.ToString, t)
        if ok and s then return s end
    end
    return tostring(t)
end

function S.partByName(patient, name)
    local bd = call(patient, "getBodyDamage")
    if not bd or not name or not BodyPartType or not BodyPartType.FromString then return nil end
    local ok, t = pcall(BodyPartType.FromString, name)
    if not ok or not t then return nil end
    return call(bd, "getBodyPart", t)
end

function S.hasWound(bodyPart)
    for _, m in ipairs(S.WOUND_METHODS) do
        if call(bodyPart, m) == true then return true end
    end
    return false
end

-- ---------------------------------------------------------------- indication
-- `exam` (optional): the snapshot EHR's remote health panel keeps for a
-- patient on another machine (their ModData is not synced to our client).
local function activeDisease(patient, id, exam)
    local data = exam and exam.EHR_Disease
    if not data then
        data = EHR and EHR.Disease and EHR.Disease.GetDiseaseData and EHR.Disease.GetDiseaseData(patient)
    end
    local d = data and data.active and data.active[id]
    if d then return tonumber(d.stage) or 1 end
    return nil
end

local function woundInfectionStage(patient, bodyPart, exam)
    local name = S.partName(bodyPart)
    local pd
    if exam and exam.EHR_WoundInfection then
        pd = exam.EHR_WoundInfection.parts and exam.EHR_WoundInfection.parts[name]
    else
        local W = EHR and EHR.WoundInfection
        pd = W and W.GetPartData and name and W.GetPartData(patient, name)
    end
    local stage = pd and tonumber(pd.stage) or 0
    if stage <= 0 and call(bodyPart, "isInfectedWound") == true then stage = 1 end
    return stage
end

-- Conditions this operation would treat through this body part.
-- -> list of { id, stage, cool = hours left or nil }
function S.indications(patient, bodyPart, sid, exam)
    local s = S.Surgeries[sid]
    local out = {}
    if not s or not patient or not bodyPart then return out end
    local wound = S.hasWound(bodyPart)
    for id, _ in pairs(s.targets) do
        local stage
        if id == "wound_infection" then
            stage = woundInfectionStage(patient, bodyPart, exam)
            if stage <= 0 then stage = nil end
        elseif wound then
            stage = activeDisease(patient, id, exam)
        end
        if stage then
            out[#out + 1] = { id = id, stage = stage, cool = S.cooldownLeft(patient, id, bodyPart) }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- A patient on another machine whose data we cannot see: the server checks.
function S.isRemote(doctor, patient)
    return doctor ~= patient and isClient and isClient() and call(patient, "isLocalPlayer") ~= true
end

-- ---------------------------------------------------------------- cooldown
function S.coolKey(id, bodyPart)
    if id == "wound_infection" then return id .. ":" .. tostring(S.partName(bodyPart)) end
    return id
end

function S.cooldownLeft(patient, id, bodyPart)
    local md = call(patient, "getModData")
    local c = md and md.HARMONIE_Surgery and md.HARMONIE_Surgery.cool
    local last = c and tonumber(c[S.coolKey(id, bodyPart)])
    if not last then return nil end
    local left = S.COOLDOWN_HOURS - (now() - last)
    if left > 0 then return left end
    return nil
end

-- ---------------------------------------------------------------- asepsis / anesthesia
local function wearsGloves(player)
    local worn = call(player, "getWornItems")
    if not worn then return false end
    for i = 0, worn:size() - 1 do
        local w = worn:get(i)
        local it = w and call(w, "getItem")
        local ty = (it and call(it, "getType") or ""):lower()
        if ty:find("glove", 1, true) and (ty:find("surg", 1, true) or ty:find("latex", 1, true) or ty:find("medical", 1, true)) then
            return true
        end
    end
    return false
end

local function handsClean(player)
    local W = EHR and EHR.WashHands
    if W and W.GetDirtyPartCount then
        local ok, n = pcall(W.GetDirtyPartCount, player)
        if ok then return (tonumber(n) or 0) == 0 end
    end
    return false
end

-- -> value 0..1, list of { key, ok, weight }
function S.asepsis(doctor, antisepticFound)
    local parts = {
        { key = "Antiseptic", ok = antisepticFound == true, weight = 0.45 },
        { key = "Gloves", ok = wearsGloves(doctor), weight = 0.25 },
        { key = "CleanHands", ok = handsClean(doctor), weight = 0.20 },
        { key = "Indoors", ok = call(call(doctor, "getCurrentSquare"), "isOutside") == false, weight = 0.10 },
    }
    local v = 0
    for _, p in ipairs(parts) do if p.ok then v = v + p.weight end end
    return v, parts
end

-- -> value 0..1, list of { key, ok }
function S.anesthesia(patient)
    local asleep = call(patient, "isAsleep") == true
    local analgesic = false
    local M = EHR and EHR.Medication
    if M and M.IsAnalgesicActive then
        local ok, r = pcall(M.IsAnalgesicActive, patient)
        analgesic = ok and r == true
    end
    if not analgesic then
        local bd = call(patient, "getBodyDamage")
        analgesic = (tonumber(call(bd, "getPainReduction")) or 0) > 0
    end
    local drunk = false
    local stats = call(patient, "getStats")
    if stats and CharacterStat and CharacterStat.INTOXICATION then
        drunk = (tonumber(call(stats, "get", CharacterStat.INTOXICATION)) or 0) >= 30
    end
    local v = asleep and 1 or math.min(1, (analgesic and 0.7 or 0) + (drunk and 0.3 or 0))
    return v, {
        { key = "Analgesic", ok = analgesic },
        { key = "Alcohol", ok = drunk },
        { key = "Asleep", ok = asleep },
    }
end

function S.bloodFraction(patient)
    local B = HARMONIE_HomeMedic_BloodImpact
    if B and B.bloodFraction then
        local ok, f = pcall(B.bloodFraction, patient)
        if ok and f then return f end
    end
    return nil
end

function S.distance(a, b)
    if a == b then return 0 end
    local dx = (call(a, "getX") or 0) - (call(b, "getX") or 0)
    local dy = (call(a, "getY") or 0) - (call(b, "getY") or 0)
    if math.abs((call(a, "getZ") or 0) - (call(b, "getZ") or 0)) > 0.1 then return 99 end
    return math.sqrt(dx * dx + dy * dy)
end

-- ---------------------------------------------------------------- readiness
-- -> { rows = {...}, canStart, slots = {slotId = fill}, indications, asepsis, anesthesia, toolQ }
-- row = { key, state = "ok"|"warn"|"fail"|"info", required, label, value, tip }
function S.evaluate(doctor, patient, bodyPart, sid, exam)
    local s = S.Surgeries[sid]
    local r = { rows = {}, slots = {}, canStart = true }
    if not s then r.canStart = false; return r end
    local function row(t)
        r.rows[#r.rows + 1] = t
        if t.required and t.state == "fail" then r.canStart = false end
    end

    -- indication
    local ind = S.indications(patient, bodyPart, sid, exam)
    r.indications = ind
    local remoteUnknown = #ind == 0 and not exam and S.isRemote(doctor, patient)
    local usable = 0
    local names = {}
    for _, i in ipairs(ind) do
        if not i.cool then usable = usable + 1 end
        names[#names + 1] = S.T("Cond_" .. i.id, i.id) .. " " .. S.T("Stage", "St.%1", i.stage)
            .. (i.cool and (" (" .. S.T("CoolShort", "%1h", math.ceil(i.cool)) .. ")") or "")
    end
    row({ key = "indication", required = not remoteUnknown,
          state = usable > 0 and "ok" or (remoteUnknown and "info" or "fail"),
          label = S.T("Row_Indication", "Indication"),
          value = #names > 0 and table.concat(names, ", ")
              or (remoteUnknown and S.T("ServerChecks", "Checked when you start") or S.T("None", "None")),
          tip = S.T("Tip_Indication", "What this operation treats through this body part.")
              .. "\n" .. S.T("Tip_Targets_" .. sid, "") })

    -- skill: one row per procedure (step)
    for n, pid in ipairs(s.steps) do
        local ok, needFa, missing = S.procedureUnlocked(doctor, pid)
        local tip = S.T("Tip_" .. pid, "") .. "\n\n" .. S.T("Tip_UnlockFA", "Needs First Aid %1.", needFa)
        if S.Procedures[pid].knowledge then
            local k = {}
            for _, id in ipairs(S.Procedures[pid].knowledge) do k[#k + 1] = S.T("Cond_" .. id, id) end
            tip = tip .. "\n" .. S.T("Tip_UnlockKnow", "And knowledge of: %1 (a disease flyer, or First Aid 8).", table.concat(k, " / "))
        end
        row({ key = "step" .. n, required = true, state = ok and "ok" or "fail",
              label = n .. ". " .. S.T("Proc_" .. pid, pid),
              value = ok and S.T("Ready", "Ready") or S.T("Locked", "Locked"),
              tip = tip })
    end

    -- supplies
    local qSum, qN = 0, 0
    for _, slotId in ipairs(s.supplies) do
        local slot = S.Supplies[slotId]
        local fill = S.fillSlot(Src.get(doctor), slotId)
        r.slots[slotId] = fill
        local value, state
        if fill then
            value = (call(fill.item, "getDisplayName") or fullType(fill.item)) .. " · " .. S.T("Where_" .. fill.where, fill.where)
            state = fill.q >= 0.8 and "ok" or "warn"
            if slot.kind == "tool" then qSum = qSum + fill.q; qN = qN + 1 end
        else
            value = S.T("Missing", "Missing")
            state = slot.required and "fail" or "warn"
        end
        local opts = {}
        for _, o in ipairs(slot.options) do
            local nm = o.type and (getItemNameFromFullType and getItemNameFromFullType(o.type) or o.type) or S.T("Match_" .. o.match, o.match)
            opts[#opts + 1] = nm .. (o.needs and (" + " .. (getItemNameFromFullType and getItemNameFromFullType(o.needs) or o.needs)) or "")
        end
        row({ key = "slot_" .. slotId, required = slot.required, state = state,
              label = S.T("Slot_" .. slotId, slotId) .. (slot.kind == "use" and (" " .. S.T("Consumed", "(used up)")) or ""),
              value = value,
              tip = S.T("Tip_Slot_" .. slotId, "") .. "\n\n" .. S.T("Tip_Options", "Accepts: %1", table.concat(opts, ", "))
                  .. "\n" .. S.T("Tip_Sources", "Found in your inventory, on the floor or in containers next to you.") })
    end
    r.toolQ = qN > 0 and (qSum / qN) or 1

    -- asepsis
    local asep, parts = S.asepsis(doctor, r.slots.antiseptic ~= nil)
    r.asepsis = asep
    local lines = {}
    for _, p in ipairs(parts) do lines[#lines + 1] = (p.ok and "+ " or "- ") .. S.T("Asep_" .. p.key, p.key) end
    row({ key = "asepsis", state = asep >= 0.6 and "ok" or (asep >= 0.3 and "warn" or "fail"),
          label = S.T("Row_Asepsis", "Asepsis"), value = math.floor(asep * 100 + 0.5) .. "%",
          tip = S.T("Tip_Asepsis", "Low asepsis = risk of a surgical-site infection (Cellulitis).") .. "\n" .. table.concat(lines, "\n") })

    -- anesthesia
    local an, aparts = S.anesthesia(patient)
    r.anesthesia = an
    lines = {}
    for _, p in ipairs(aparts) do lines[#lines + 1] = (p.ok and "+ " or "- ") .. S.T("Anes_" .. p.key, p.key) end
    row({ key = "anesthesia", state = an >= 0.6 and "ok" or "warn",
          label = S.T("Row_Anesthesia", "Anesthesia"), value = math.floor(an * 100 + 0.5) .. "%",
          tip = S.T("Tip_Anesthesia", "Without pain relief the patient flinches: the steps shake and hurt more.") .. "\n" .. table.concat(lines, "\n") })

    -- blood
    local bf = S.bloodFraction(patient)
    if bf then
        row({ key = "blood", state = bf >= 0.7 and "ok" or (bf >= 0.55 and "warn" or "fail"),
              label = S.T("Row_Blood", "Blood volume"), value = math.floor(bf * 100 + 0.5) .. "%",
              tip = S.T("Tip_Blood", "The operation costs about %1 mL of blood (more if hemostasis goes badly).", s.bloodLoss) })
    end

    -- position
    local dist = S.distance(doctor, patient)
    row({ key = "distance", required = true, state = dist <= S.MAX_DISTANCE and "ok" or "fail",
          label = S.T("Row_Patient", "Patient"),
          value = doctor == patient and S.T("Self", "Yourself (harder)") or (call(patient, "getDisplayName") or call(patient, "getUsername") or "?"),
          tip = S.T("Tip_Patient", "Stay next to the patient. Operating on yourself makes every step shakier.") })
    return r
end

-- ---------------------------------------------------------------- quality
-- steps: { [n] = score 0..1 }; returns 0..1
function S.quality(sid, scores, toolQ)
    local s = S.Surgeries[sid]
    if not s then return 0 end
    local sum, wsum = 0, 0
    for n, pid in ipairs(s.steps) do
        local w = S.Procedures[pid].weight or 1
        local v = tonumber(scores and scores[n]) or 0
        if v < 0 then v = 0 elseif v > 1 then v = 1 end
        sum = sum + v * w
        wsum = wsum + w
    end
    local q = wsum > 0 and sum / wsum or 0
    return q * (0.75 + 0.25 * math.max(0, math.min(1, toolQ or 1)))
end

-- Difficulty knobs for the minigames (client) from who operates and how.
function S.difficulty(doctor, patient, anesthesia, toolQ)
    local fa = S.firstAid(doctor)
    local skill = math.min(1, fa / 10)
    local shake = (1 - (anesthesia or 0)) * 0.8 + ((doctor == patient) and 0.5 or 0)
    return {
        skill = skill,                                   -- 0..1 wider windows / slower timers
        shake = math.min(1.2, shake),                    -- patient movement
        tool = toolQ or 1,
    }
end

return S

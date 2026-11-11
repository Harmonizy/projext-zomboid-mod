--[[
    HARMONIE - How to Survive : every sign an illness lists is real (shared)

    Owner, 2026-11-11: "บางโรค อาการขึ้นไม่ครบในแท็บสถานะตัวละคร ... มันควรขึ้น
    ครบ แล้วค่อยเอาส่วนอื่นๆมาตรวจดูว่ามีอาการอะไรบ้าง แล้วไปทำให้ส่งผลจริงๆ
    บางอาการยังไม่ทำอะไรจริงๆเลยด้วยซ้ำ".

    HM_Diagnosis.STAGE_SIGNS is the list of signs per illness and stage (what
    tab 3 / the handbook / the diagnosis show). EHR makes almost all of them
    real, but not these (checked in EHR's code, 2026-11-11):
      * stage 1 of the illnesses EHR.Disease.ApplyEffects drives: it runs
        only from stage 2 (UpdateProgression: stage > 1 or
        applyEffectsInStage1) -- corpse sickness, cadaveric aspergillosis,
        trichinosis, scabies, cellulitis, tuberculosis, insomnia, painkiller
        addiction list stage-1 signs that nothing caused;
      * corpse sickness "eye burn" was a line only; delirium "confusion" had
        no effect at all.
    For those (illness, stage, sign) this file adds a mild real effect, every
    E.INTERVAL_MS, only where EHR is authoritative (server in MP, the game in
    SP). A medicine taken for that illness cuts it (E.TREATED_MULT). It never
    touches health (the non-lethal floor stays EHR's).

    It also records when a sign EVENT happened (cough, sneeze, vomit,
    dizziness, collapse, cramp, confusion, scratch -- EHR's own and ours) in
    modData EHR_Disease.hmSignEvents[tag] = game hour: EHR syncs EHR_Disease
    to the client, and tab 3 shows "N min ago".

    E.currentSigns(patient) -> { [tag] = illness id } of the signs the
    patient's illnesses show at their current stage (tab 3, HM_Stats).
]]--

require "HARMONIEHomeMedic/HM_Diagnosis"

HM_SignEffects = HM_SignEffects or {}
local E = HM_SignEffects
local D = HM_Diagnosis

E.INTERVAL_MS = 10000
E.TREATED_MULT = 0.4
-- ApplyEffects starts at stage 2 for these (stage 1 signs are ours)
E.FROM_STAGE2 = {
    corpse_sickness = true, cadaveric_aspergillosis = true, trichinosis = true,
    hyperkeratotic_scabies = true, cellulitis = true, tuberculosis = true,
    insomnia = true, painkiller_addiction = true,
}
-- signs EHR never made real
E.COSMETIC = {
    corpse_sickness = { eye_burn = true },
    delirium = { confusion = true },
}
-- real in stage 1 already, by their own module
E.NATIVE = {
    insomnia = { sleepless = true },          -- EHR_Insomnia blocks sleep
    hyperkeratotic_scabies = { itch = true }, -- the bite scratch at onset
}

local function log(fmt, ...) if HMLog then HMLog("SignEffects", fmt, ...) end end
local function logOnce(key, fmt, ...) if HMLogOnce then HMLogOnce("signfx:" .. key, "SignEffects", fmt, ...) end end
local function nameOf(p) return HMLogName and HMLogName(p) or "?" end
local function call(obj, m, ...)
    if not obj or not obj[m] then return nil end
    local ok, v = pcall(obj[m], obj, ...)
    if ok then return v end
    return nil
end
local function hours() return getGameTime and getGameTime():getWorldAgeHours() or 0 end
local function nowMs()
    if getTimestampMs then
        local ok, v = pcall(getTimestampMs)
        if ok and tonumber(v) then return tonumber(v) end
    end
    return (os and os.time and os.time() or 0) * 1000
end
local function authoritative() return (isServer and isServer()) or not (isClient and isClient()) end

-- ------------------------------------------------------------- reading
local function diseaseEntry(get, id)
    local dis = get("EHR_Disease")
    local active = type(dis) == "table" and type(dis.active) == "table" and dis.active or {}
    for k, v in pairs(active) do
        if type(v) == "table" and D.normalize(k) == id then return v end
    end
    return nil
end

-- the illness's stage now (1..4)
function E.stageOf(get, id)
    if id == "sepsis" then
        local s = get("EHR_Sepsis")
        return type(s) == "table" and tonumber(s.stage) or 1
    end
    if id == "wound_infection" then
        local w = get("EHR_WoundInfection")
        local best = 0
        for _, pd in pairs(type(w) == "table" and type(w.parts) == "table" and w.parts or {}) do
            if type(pd) == "table" then best = math.max(best, tonumber(pd.stage) or 0) end
        end
        return math.max(1, best)
    end
    if id == "knox_infection" then return 1 end
    local e = diseaseEntry(get, id)
    return e and tonumber(e.stage) or 1
end

-- { [tag] = illness id } of the signs of every active illness at its stage
function E.currentSigns(patient, exam)
    local out, stages = {}, {}
    if not (D and D.activeIds and D.stageSigns) then return out, stages end
    local get = D.getter(patient, exam)
    for _, id in ipairs(D.activeIds(patient, exam)) do
        local st = E.stageOf(get, id)
        stages[id] = st
        for _, tag in ipairs(D.stageSigns(id, st)) do
            out[tag] = out[tag] or id
        end
    end
    return out, stages
end

function E.isGap(id, stage, tag)
    if E.NATIVE[id] and E.NATIVE[id][tag] then return false end
    if E.COSMETIC[id] and E.COSMETIC[id][tag] then return true end
    return E.FROM_STAGE2[id] == true and (tonumber(stage) or 1) <= 1
end

-- ------------------------------------------------------------- events
function E.recordEvent(player, tag)
    local md = call(player, "getModData")
    if not md then return end
    md.EHR_Disease = type(md.EHR_Disease) == "table" and md.EHR_Disease or {}
    md.EHR_Disease.hmSignEvents = type(md.EHR_Disease.hmSignEvents) == "table" and md.EHR_Disease.hmSignEvents or {}
    md.EHR_Disease.hmSignEvents[tag] = hours()
end

function E.lastEvent(get, tag)
    local dis = get("EHR_Disease")
    local ev = type(dis) == "table" and type(dis.hmSignEvents) == "table" and dis.hmSignEvents or nil
    return ev and tonumber(ev[tag]) or nil
end

-- EHR's own events are recorded too (wrapped once)
local WRAP = {
    { "TriggerCough", "cough" }, { "TriggerSneeze", "sneeze" }, { "TriggerVomit", "vomit" },
    { "TriggerDizziness", "dizziness" }, { "TriggerCollapse", "collapse" }, { "TriggerCramp", "spasm" },
    { "TriggerConfusion", "confusion" },
}
function E.install()
    if E.installed then return end
    local Env = EHR and EHR.Environmental
    if not Env then log("EHR.Environmental missing -- EHR's own sign events are not recorded"); return end
    local n = 0
    for _, w in ipairs(WRAP) do
        local fname, tag = w[1], w[2]
        local orig = Env[fname]
        if type(orig) == "function" then
            Env[fname] = function(player, ...)
                pcall(E.recordEvent, player, tag)
                return orig(player, ...)
            end
            n = n + 1
        end
    end
    local Sc = EHR and EHR.HyperkeratoticScabies
    if Sc and type(Sc.ApplyScratch) == "function" then
        local orig = Sc.ApplyScratch
        Sc.ApplyScratch = function(player, ...)
            pcall(E.recordEvent, player, "itch")
            return orig(player, ...)
        end
        n = n + 1
    end
    E.installed = true
    log("installed: %d EHR sign events recorded for tab 3; mild effects for the signs EHR leaves without one", n)
end

-- ------------------------------------------------------------- effects
local function stats(p) return call(p, "getStats") end
local function statOf(name) return CharacterStat and CharacterStat[name] or nil end
local function getS(st, name)
    local s = statOf(name)
    if not st or not s then return nil end
    local ok, v = pcall(function() return st:get(s) end)
    return ok and tonumber(v) or nil
end
local function setS(st, name, v)
    local s = statOf(name)
    if not st or not s then return end
    pcall(function() st:set(s, math.max(0, math.min(1, v))) end)
end
local function raise(p, name, target, step)
    local st = stats(p); local cur = getS(st, name)
    if cur and cur < target then setS(st, name, math.min(target, cur + step)) end
end
local function lower(p, name, target, step)
    local st = stats(p); local cur = getS(st, name)
    if cur and cur > target then setS(st, name, math.max(target, cur - step)) end
end
local function add(p, name, amount)
    local st = stats(p); local cur = getS(st, name)
    if cur then setS(st, name, cur + amount) end
end
local function part(p, name)
    local bd = call(p, "getBodyDamage")
    if not bd or not BodyPartType or not BodyPartType.FromString then return nil end
    local ok, pt = pcall(BodyPartType.FromString, name)
    if not ok or not pt then return nil end
    local ok2, bp = pcall(function() return bd:getBodyPart(pt) end)
    return ok2 and bp or nil
end
local function painUp(p, name, target, step)
    local bp = part(p, name)
    local cur = bp and tonumber(call(bp, "getAdditionalPain"))
    if cur and cur < target then call(bp, "setAdditionalPain", math.min(target, cur + step)) end
end
local function stiffUp(p, name, target, step)
    local bp = part(p, name)
    local cur = bp and tonumber(call(bp, "getStiffness"))
    if cur and cur < target then call(bp, "setStiffness", math.min(target, cur + step)) end
end
local LIMBS = { "UpperArm_L", "UpperArm_R", "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }

-- one event per player and tag at most every `cd` game hours (EHR's own count)
local function eventDue(p, tag, cd)
    local md = call(p, "getModData") or {}
    local get = function(k) return md[k] end
    local last = E.lastEvent(get, tag)
    return not last or hours() - last >= cd
end

-- the illness's part for skin signs: cellulitis' wound, scabies' bite
local function skinPart(entry)
    if type(entry) ~= "table" then return "ForeArm_L" end
    local n = entry.sourceBodyPart or entry.scabiesBitePartName or entry.hmSkinPart
    if type(n) == "string" and n ~= "" then return n end
    entry.hmSkinPart = LIMBS[(ZombRand and ZombRand(#LIMBS) or 0) + 1]
    return entry.hmSkinPart
end

local EFFECT = {
    fatigue = function(p, m) raise(p, "FATIGUE", 0.30 * m, 0.004 * m) end,
    weakness = function(p, m) lower(p, "ENDURANCE", 1 - 0.25 * m, 0.010 * m) end,
    nausea = function(p, m) raise(p, "SICKNESS", 0.25 * m, 0.004 * m) end,
    thirst = function(p, m) add(p, "THIRST", 0.0020 * m) end,
    hunger = function(p, m) add(p, "HUNGER", 0.0010 * m) end,
    stress = function(p, m) raise(p, "STRESS", 0.30 * m, 0.004 * m) end,
    craving = function(p, m) raise(p, "STRESS", 0.25 * m, 0.003 * m); raise(p, "UNHAPPINESS", 0.20 * m, 0.003 * m) end,
    headache = function(p, m) painUp(p, "Head", 12 * m, 1.5) end,
    chest_pain = function(p, m) painUp(p, "Torso_Upper", 12 * m, 1.5) end,
    abdominal = function(p, m) painUp(p, "Torso_Lower", 12 * m, 1.5) end,
    back_pain = function(p, m) painUp(p, "Torso_Lower", 10 * m, 1.5); stiffUp(p, "Torso_Lower", 15 * m, 1.5) end,
    muscle_pain = function(p, m) for _, n in ipairs(LIMBS) do painUp(p, n, 8 * m, 1.0); stiffUp(p, n, 15 * m, 1.0) end end,
    stiffness = function(p, m) stiffUp(p, "Neck", 15 * m, 1.0); for _, n in ipairs(LIMBS) do stiffUp(p, n, 15 * m, 1.0) end end,
    skin_pain = function(p, m, entry) painUp(p, skinPart(entry), 8 * m, 1.0) end,
    wound_inflamed = function(p, m, entry) painUp(p, skinPart(entry), 10 * m, 1.0) end,
    eye_burn = function(p, m)
        raise(p, "DISCOMFORT", 0.30 * m, 0.006 * m)
        raise(p, "STRESS", 0.20 * m, 0.003 * m)
    end,
    -- events
    cough = function(p, m, entry, stage)
        local Env = EHR and EHR.Environmental
        if Env and Env.TriggerCough and eventDue(p, "cough", stage <= 1 and 3 or 0.75) then Env.TriggerCough(p, false) end
    end,
    sneeze = function(p, m)
        local Env = EHR and EHR.Environmental
        if Env and Env.TriggerSneeze and eventDue(p, "sneeze", 1) then Env.TriggerSneeze(p) end
    end,
    dizziness = function(p, m)
        local Env = EHR and EHR.Environmental
        if Env and Env.TriggerDizziness and eventDue(p, "dizziness", 2) then Env.TriggerDizziness(p, "hm_sign_dizzy", 2) end
    end,
    confusion = function(p, m)
        local Env = EHR and EHR.Environmental
        if Env and Env.TriggerConfusion and eventDue(p, "confusion", 0.75) then Env.TriggerConfusion(p, "hm_sign_confusion", 0.75) end
    end,
    itch = function(p, m, entry)
        local Sc = EHR and EHR.HyperkeratoticScabies
        if Sc and Sc.ApplyScratch and eventDue(p, "itch", 3) then Sc.ApplyScratch(p, "hm_sign_itch", entry) end
    end,
}
E.EFFECT = EFFECT

-- a medicine for this illness in effect now
local function treated(p, id)
    local md = call(p, "getModData") or {}
    local doses = type(md.EHR_Medication) == "table" and md.EHR_Medication.activeDoses or nil
    if type(doses) ~= "table" then return false end
    local now = hours()
    for _, d in pairs(doses) do
        if type(d) == "table" and (d.treatingDisease == id or (type(d.diseaseTargets) == "table" and d.diseaseTargets[id])) then
            local last, iv = tonumber(d.lastDoseTime), tonumber(d.intervalHours)
            if last and iv and now - last >= 0 and now - last <= iv then return true end
        end
    end
    return false
end

function E.applyPlayer(p)
    if not p or call(p, "isDead") then return end
    local md = call(p, "getModData") or {}
    local get = function(k) return md[k] end
    for _, id in ipairs(D.activeIds(p)) do
        local stage = E.stageOf(get, id)
        local entry = diseaseEntry(get, id)
        local m = treated(p, id) and E.TREATED_MULT or 1
        for _, tag in ipairs(D.stageSigns(id, stage)) do
            if E.isGap(id, stage, tag) then
                local fx = EFFECT[tag]
                if fx then
                    local ok, err = pcall(fx, p, m, entry, stage)
                    if not ok then
                        logOnce("err:" .. tag, "%s / %s: effect FAILED: %s", tostring(id), tag, tostring(err))
                    else
                        logOnce(nameOf(p) .. ":" .. id .. ":" .. tostring(stage) .. ":" .. tag,
                            "%s: %s stage %d -- sign '%s' made real here (EHR gives it none)%s", nameOf(p), id, stage, tag,
                            m < 1 and " (cut, medicine in effect)" or "")
                    end
                else
                    logOnce("none:" .. id .. ":" .. tag, "%s stage %d lists '%s' and EHR gives it no effect -- no effect written for it",
                        tostring(id), stage, tag)
                end
            end
        end
    end
end

local lastRun = 0
function E.tick()
    if not authoritative() then return end
    local now = nowMs()
    if now - lastRun < E.INTERVAL_MS then return end
    lastRun = now
    if not E.installed then E.install() end
    local list = {}
    if isServer and isServer() and getOnlinePlayers then
        local online = getOnlinePlayers()
        for i = 0, online:size() - 1 do list[#list + 1] = online:get(i) end
    elseif getSpecificPlayer then
        local p = getSpecificPlayer(0)
        if p then list[1] = p end
    end
    for _, p in ipairs(list) do
        local ok, err = pcall(E.applyPlayer, p)
        if not ok then logOnce("player", "apply FAILED: %s", tostring(err)) end
    end
end

if Events then
    if Events.OnGameStart then Events.OnGameStart.Add(E.install) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(E.install) end
    if Events.OnTick then Events.OnTick.Add(E.tick) end
end

return E

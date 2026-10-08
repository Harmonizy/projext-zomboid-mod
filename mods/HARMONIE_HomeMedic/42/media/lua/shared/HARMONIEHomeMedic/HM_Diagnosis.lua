--[[
    HARMONIE - Home Medic : diagnosis by symptoms (shared data + rules)

    Request 2026-10-01: the medical window shows every illness as "Unknown"
    until someone diagnoses it in the Diagnosis tab. The doctor ticks the
    signs the patient shows (tags); the candidate list narrows to the
    illnesses that cause ALL of them. Only illnesses the doctor knows (disease
    flyer, First Aid 8, or self-evident ones) can be picked -- the others stay
    "Unknown" in the list too. Picking an illness the patient really has
    records the diagnosis on the patient (modData.HM_Diagnosis[id] = hour);
    a wrong pick is refused (and the doctor waits a little before trying
    again).

    The tags come from what each illness actually does in game -- read from
    EHR's stage effects and effect code (EHR_DiseaseDefinitions,
    EHR_Disease.ApplyEffects, EHR_Sepsis.StageEffects, EHR_WoundInfection).

    The server decides (MP: dedicated server; SP: same Lua state). Entries
    of cured illnesses are pruned, so a new infection starts unknown again.
    Sandbox HomeMedic.DiagnosisRequired = false turns the whole gate off.
]]--

HM_Diagnosis = HM_Diagnosis or {}
local D = HM_Diagnosis
D.MODULE = "HARMONIE_HM_Diag"
D.KEY = "HM_Diagnosis"
D.MAX_DISTANCE = 3
D.WRONG_LOCK_MS = 8000

-- ------------------------------------------------------------- tags
-- groups keep the chip grid readable; order = display order
D.GROUPS = {
    { id = "general", tags = { "fever", "chills", "overheat", "fatigue", "weakness", "slow", "health_loss", "collapse" } },
    { id = "breath", tags = { "runny_nose", "sneeze", "cough", "chest_pain", "short_breath" } },
    { id = "gut", tags = { "nausea", "vomit", "abdominal", "bloody_stool", "thirst", "hunger" } },
    { id = "body", tags = { "muscle_pain", "stiffness", "spasm", "back_pain", "itch", "skin_pain", "wound_inflamed" } },
    { id = "mind", tags = { "headache", "dizziness", "eye_burn", "confusion", "hallucination", "sleepless", "craving", "stress" } },
}

-- Request 2026-10-02 (R59): what each illness REALLY does, per stage --
-- read from the code that runs, not from the descriptions:
--   EHR.Disease.ApplyEffects (per-illness code), EHR.Environmental.
--   ApplyDiseaseEffects (stage tables -- only cold, pneumonia, dysentery,
--   hypothermia and heat stroke), EHR.BodyTemp.DiseaseFeverTargets (fever),
--   food sickness (nausea), EHR.Sepsis.StageEffects, the wound infection
--   STAGE_EFFECTS. A dizzy spell always blurs the sight (EHR.ToxinVision),
--   so "dizziness" covers both. The diagnosis chips, the handbook (tab 5)
--   and the condition cards all read THIS table, so they use the same words.
-- [stage] = signs; all = every stage
D.STAGE_SIGNS = {
    common_cold = {
        [1] = { "sneeze" },
        [2] = { "runny_nose", "sneeze", "fever", "fatigue" },
        [3] = { "runny_nose", "sneeze", "fever", "fatigue" },
        [4] = { "sneeze" },
    },
    pneumonia = {
        [1] = { "cough", "chest_pain", "fever", "fatigue" },
        [2] = { "cough", "chest_pain", "fever", "fatigue", "weakness" },
        [3] = { "cough", "chest_pain", "fever", "fatigue", "weakness", "health_loss" },
        [4] = { "cough", "chest_pain", "fever", "fatigue", "weakness", "health_loss" },
    },
    dysentery = {
        [1] = { "thirst", "hunger" },
        [2] = { "abdominal", "bloody_stool", "vomit", "thirst", "hunger" },
        [3] = { "abdominal", "bloody_stool", "vomit", "thirst", "hunger", "slow" },
        [4] = { "thirst", "hunger" },
    },
    hypothermia = {
        [1] = { "chills", "slow", "weakness", "fatigue" },
        [2] = { "chills", "slow", "weakness", "fatigue", "confusion", "health_loss" },
        [3] = { "chills", "slow", "weakness", "fatigue", "confusion", "health_loss", "dizziness" },
        [4] = { "chills", "slow", "weakness", "fatigue", "confusion", "health_loss", "dizziness", "collapse" },
    },
    heat_stroke = {
        all = { "overheat", "fever", "thirst", "slow", "confusion", "dizziness", "collapse", "health_loss" },
    },
    corpse_sickness = {
        [1] = { "nausea", "weakness", "dizziness" },
        [2] = { "nausea", "weakness", "cough", "eye_burn", "dizziness", "thirst" },
        [3] = { "nausea", "weakness", "cough", "eye_burn", "dizziness", "thirst", "collapse" },
        [4] = { "nausea", "weakness", "cough", "dizziness" },
    },
    cadaveric_aspergillosis = {
        [1] = { "nausea", "fatigue", "weakness", "cough" },
        [2] = { "nausea", "fatigue", "weakness", "cough", "fever", "short_breath" },
        [3] = { "nausea", "fatigue", "weakness", "cough", "fever", "short_breath", "health_loss" },
        [4] = { "nausea", "fatigue", "weakness", "cough", "fever" },
    },
    food_poisoning = {
        [1] = {},
        [2] = { "nausea", "vomit", "weakness" },
        [3] = { "nausea", "vomit", "weakness", "hunger", "thirst" },
        [4] = { "nausea", "weakness" },
    },
    gastroenteritis = {
        [1] = {},
        [2] = { "nausea", "vomit", "weakness", "thirst", "hunger" },
        [3] = { "nausea", "vomit", "weakness", "thirst", "hunger" },
        [4] = { "nausea", "weakness" },
    },
    toxin_poisoning = {
        [1] = {},
        [2] = { "nausea", "vomit", "weakness", "thirst", "fatigue", "dizziness" },
        [3] = { "nausea", "vomit", "weakness", "thirst", "fatigue", "dizziness", "hunger", "health_loss" },
        [4] = { "nausea", "weakness", "thirst" },
    },
    trichinosis = {
        [1] = { "weakness", "fatigue", "nausea", "muscle_pain", "stiffness" },
        [2] = { "weakness", "fatigue", "nausea", "muscle_pain", "stiffness", "fever", "thirst", "spasm" },
        [3] = { "weakness", "fatigue", "nausea", "muscle_pain", "stiffness", "fever", "thirst", "spasm", "health_loss" },
        [4] = { "weakness", "fatigue", "nausea", "muscle_pain", "stiffness", "fever" },
    },
    hyperkeratotic_scabies = {
        [1] = { "itch", "skin_pain" },
        [2] = { "itch", "skin_pain", "fever", "health_loss" },
        [3] = { "itch", "skin_pain", "fever", "health_loss" },
        [4] = { "skin_pain", "fever", "health_loss" },
    },
    cellulitis = {
        [1] = { "skin_pain", "wound_inflamed", "weakness" },
        [2] = { "skin_pain", "wound_inflamed", "weakness", "nausea", "fatigue", "fever" },
        [3] = { "skin_pain", "wound_inflamed", "weakness", "nausea", "fatigue", "fever" },
        [4] = { "skin_pain", "wound_inflamed", "weakness", "nausea", "fatigue", "fever" },
    },
    wound_infection = {
        [1] = { "wound_inflamed" },
        [2] = { "wound_inflamed", "skin_pain" },
        [3] = { "wound_inflamed", "skin_pain", "fever" },
        [4] = { "wound_inflamed", "skin_pain", "fever" },
    },
    sepsis = {
        [1] = { "fever", "fatigue", "health_loss" },
        [2] = { "fever", "fatigue", "health_loss", "confusion" },
        [3] = { "fever", "fatigue", "health_loss", "confusion" },
        [4] = { "fever", "fatigue", "health_loss", "confusion" },
    },
    tetanus = {
        [1] = {},
        [2] = { "stiffness", "muscle_pain", "weakness", "fatigue", "health_loss" },
        [3] = { "stiffness", "muscle_pain", "spasm", "weakness", "fatigue", "fever", "health_loss" },
        [4] = { "fever", "weakness" },
    },
    tuberculosis = {
        [1] = { "cough" },
        [2] = { "cough", "fever", "fatigue", "weakness" },
        [3] = { "cough", "fever", "fatigue", "weakness" },
        [4] = { "cough", "fever", "fatigue", "weakness" },
    },
    ahtr = {
        [1] = {},
        [2] = { "back_pain", "weakness", "nausea", "fever", "health_loss" },
        [3] = { "back_pain", "weakness", "nausea", "fever", "health_loss" },
        [4] = { "back_pain", "weakness", "nausea", "fever", "health_loss" },
    },
    concussion = { all = { "headache", "nausea", "dizziness", "health_loss" } },
    delirium = { all = { "hallucination", "confusion" } },
    insomnia = { all = { "sleepless", "fatigue", "stress", "headache" } },
    painkiller_addiction = { all = { "craving", "stress", "thirst" } },
    knox_infection = { all = { "fever", "nausea", "fatigue", "health_loss" } },
}
-- a sign that only shows in some cases: [illness][tag] = note key
D.SIGN_NOTES = {
    toxin_poisoning = { health_loss = "MushroomOnly" },
}

-- signs of `id` at `stage` (nil stage = every stage together)
function D.stageSigns(id, stage)
    local t = D.STAGE_SIGNS[id]
    if not t then return {} end
    if t.all then return t.all end
    if stage then return t[tonumber(stage)] or {} end
    return D.DISEASES[id] or {}
end

-- illness -> signs it can show (all stages together, chip-grid order)
D.DISEASES = {}
for id, stages in pairs(D.STAGE_SIGNS) do
    local set = {}
    for _, list in pairs(stages) do
        for _, t in ipairs(list) do set[t] = true end
    end
    local out = {}
    for _, grp in ipairs(D.GROUPS) do
        for _, t in ipairs(grp.tags) do
            if set[t] then out[#out + 1] = t; set[t] = nil end
        end
    end
    for t in pairs(set) do out[#out + 1] = t end   -- (a tag missing from GROUPS)
    D.DISEASES[id] = out
end

-- the stage-table numbers EHR really applies besides the signs above:
-- [illness] = where its stage table is ("disease" = def.effects, read by
-- EHR only for these environmental illnesses; "sepsis"; "wound"). Fields
-- like staminaPenalty are in the tables but nothing reads them.
D.REAL_EFFECTS = {
    common_cold = "disease", pneumonia = "disease", dysentery = "disease",
    hypothermia = "disease", heat_stroke = "disease",
    sepsis = "sepsis", wound_infection = "wound",
}
D.REAL_FIELDS = {
    disease = { "healthDrainPerHour", "enduranceCap", "fatigueCap", "movementPenalty", "canSprint" },
    sepsis = { "healthDamagePerHour", "minHealth" },
    wound = { "healingPenalty" },
}
-- -> the stage table and the fields of it that are real, or nil
function D.realEffects(id, stage)
    local src = D.REAL_EFFECTS[id]
    local tbl
    if src == "disease" then
        local def = EHR and EHR.Disease and EHR.Disease.Diseases and EHR.Disease.Diseases[id]
        tbl = def and def.effects and def.effects[tonumber(stage) or 1]
    elseif src == "sepsis" then
        tbl = EHR and EHR.Sepsis and EHR.Sepsis.StageEffects and EHR.Sepsis.StageEffects[tonumber(stage) or 1]
    elseif src == "wound" then
        local cfg = EHR and EHR.WoundInfection and EHR.WoundInfection.Config
        tbl = cfg and cfg.STAGE_EFFECTS and cfg.STAGE_EFFECTS[tonumber(stage) or 1]
    end
    if type(tbl) ~= "table" then return nil end
    return tbl, D.REAL_FIELDS[src]
end
D.ORDER = {
    "common_cold", "pneumonia", "tuberculosis", "cadaveric_aspergillosis", "corpse_sickness", "food_poisoning",
    "gastroenteritis", "dysentery", "toxin_poisoning", "trichinosis", "hypothermia", "heat_stroke", "wound_infection",
    "cellulitis", "sepsis", "tetanus", "hyperkeratotic_scabies", "ahtr", "concussion", "delirium", "insomnia",
    "painkiller_addiction", "knox_infection",
}
D.TAGSET = {}
for id, tags in pairs(D.DISEASES) do
    local set = {}
    for _, t in ipairs(tags) do set[t] = true end
    D.TAGSET[id] = set
end

-- ------------------------------------------------------------- signs <-> readings
-- Where each sign can be checked. at = "stats" (tab 3, read off the body:
-- the reading shows in tab 3's Signs group), or "observe" (only seen or
-- heard: coughing, vomiting...). test(v) gets HM_Stats.vitals(patient)
-- and returns present, reading. The handbook (tab 5) lists the same
-- thresholds per illness (keys UI_HomeMedic_SignWhere_<tag>).
local LIMBS = { "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Hand_L", "Hand_R",
    "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R", "Foot_L", "Foot_R" }
D.STIFF_PARTS = { "Neck" }
for _, n in ipairs(LIMBS) do D.STIFF_PARTS[#D.STIFF_PARTS + 1] = n end
D.SKIN_PARTS = { "Neck" }
for _, n in ipairs(LIMBS) do D.SKIN_PARTS[#D.SKIN_PARTS + 1] = n end
local function pct(x) return tostring(math.floor((x or 0) * 100 + 0.5)) .. "%" end
local function stat(name, op, limit)
    return function(v)
        local x = v[name]
        if type(x) ~= "number" then return false end
        local on = (op == ">=" and x >= limit) or (op == "<=" and x <= limit)
        return on, pct(x)
    end
end
local function temp(op, limit)
    return function(v)
        if type(v.temp) ~= "number" then return false end
        local on = (op == ">=" and v.temp >= limit) or (op == "<=" and v.temp <= limit)
        return on, string.format("%.1f C", v.temp)
    end
end
-- Thresholds follow what EHR really does to the body (R43 check):
--   fever: EHR moves the body temperature (37.6-40.5 C) for pneumonia, cold,
--     heat stroke, aspergillosis, trichinosis, scabies, cellulitis, TB,
--     tetanus, AHTR, sepsis, wound infection; >= 40.3 C only heat stroke
--   part pain (BodyPart additional pain): head = concussion / insomnia;
--     upper torso = pneumonia; lower torso / groin = dysentery;
--     lower back pain WITH stiffness = AHTR; limbs with stiffness =
--     tetanus / trichinosis; one part without stiffness = cellulitis / scabies
--   nausea: the Sickness stat (Queasy moodle) - also raised by trichinosis
--     and aspergillosis
-- Not measured (R45): hunger, thirst, tiredness, weakness, short breath and
-- stress are everyday needs -- a hungry player is not a sick one. EHR's
-- illnesses make them RISE FASTER, which only shows over time, so they are
-- "observe" signs. Arm / leg stiffness needs pain with it (workouts stiffen
-- muscles too).
local function partName(name)
    if BodyPartType and BodyPartType.FromString and BodyPartType.getDisplayName then
        local ok, n = pcall(function() return BodyPartType.getDisplayName(BodyPartType.FromString(name)) end)
        if ok and n and n ~= "" then return n end
    end
    return name
end
D.partName = partName
-- the worst part among `names` whose pain >= minPain and stiffness passes
local function partPain(names, minPain, stiff)
    return function(v)
        local m, at = 0, nil
        for _, n in ipairs(names) do
            local p = v.parts and v.parts[n]
            if p then
                local s = tonumber(p.stiff) or 0
                local sNeed = 10 + (tonumber(v.stiffFloor) or 0)   -- above GTP's vitamin D floor
                local ok = stiff == nil or (stiff == "with" and s >= sNeed) or (stiff == "without" and s < sNeed)
                if ok and (tonumber(p.pain) or 0) > m then m, at = tonumber(p.pain), n end
            end
        end
        return m >= minPain, string.format("%d", math.floor(m + 0.5)) .. (at and (" (" .. partName(at) .. ")") or "")
    end
end
local function partStiff(names, minStiff)
    return function(v)
        local need = minStiff + (tonumber(v.stiffFloor) or 0)   -- above GTP's vitamin D floor
        local m, at = 0, nil
        for _, n in ipairs(names) do
            local p = v.parts and v.parts[n]
            if p and (tonumber(p.stiff) or 0) > m then m, at = tonumber(p.stiff), n end
        end
        return m >= need, string.format("%d", math.floor(m + 0.5)) .. (at and (" (" .. partName(at) .. ")") or "")
    end
end
-- arm / leg stiffness that comes with pain: on the part itself, or
-- overall (trichinosis strains every muscle and raises the Pain stat)
local function strainedMuscle(v)
    local on, reading = partStiff(LIMBS, 10)(v)
    if not on then return false end
    local m = 0
    for _, n in ipairs(LIMBS) do
        local p = v.parts and v.parts[n]
        if p and (tonumber(p.stiff) or 0) >= 10 + (tonumber(v.stiffFloor) or 0) and (tonumber(p.pain) or 0) > m then m = tonumber(p.pain) end
    end
    if m >= 5 or (v.PAIN or 0) >= 0.4 then return true, reading end
    return false
end
D.SIGN_LIMBS = LIMBS
D.SIGNS = {
    fever = { at = "stats", test = temp(">=", 37.5) },
    chills = { at = "stats", test = temp("<=", 35.8) },
    overheat = { at = "stats", test = temp(">=", 40.3) },
    health_loss = { at = "stats", test = function(v)
        if type(v.health) ~= "number" then return false end
        return v.health < 80, tostring(math.floor(v.health + 0.5))
    end },
    collapse = { at = "stats", test = function(v)
        if type(v.health) ~= "number" then return false end
        return v.health < 25, tostring(math.floor(v.health + 0.5))
    end },
    nausea = { at = "stats", test = function(v)
        local x = math.max(v.SICKNESS or 0, v.FOOD_SICKNESS or 0)
        return x >= 0.25, pct(x)
    end },
    headache = { at = "stats", test = partPain({ "Head" }, 10) },
    chest_pain = { at = "stats", test = partPain({ "Torso_Upper" }, 10, "without") },
    abdominal = { at = "stats", test = partPain({ "Torso_Lower", "Groin" }, 10, "without") },
    back_pain = { at = "stats", test = partPain({ "Torso_Lower" }, 10, "with") },
    muscle_pain = { at = "stats", test = function(v)
        local on, reading = partPain(LIMBS, 10, "with")(v)
        if on then return on, reading end
        return strainedMuscle(v)
    end },
    skin_pain = { at = "stats", test = partPain(D.SKIN_PARTS, 10, "without") },
    stiffness = { at = "stats", test = function(v)
        -- the neck (tetanus) always counts; arms and legs only with pain --
        -- a workout leaves them stiff too, without pain (vanilla)
        local on, reading = partStiff({ "Neck" }, 10)(v)
        if on then return on, reading end
        return strainedMuscle(v)
    end },
    wound_inflamed = { at = "stats", test = function(v)
        for name, p in pairs(v.parts or {}) do
            if p.infected then return true, partName(name) end
        end
        return false
    end },
}
-- every other tag is only seen or heard
for _, grp in ipairs(D.GROUPS) do
    for _, tag in ipairs(grp.tags) do
        D.SIGNS[tag] = D.SIGNS[tag] or { at = "observe" }
    end
end

-- -> { {tag, reading} } of the measurable signs present now
function D.readSigns(v)
    local out = {}
    if type(v) ~= "table" or v.dead then return out end
    for _, grp in ipairs(D.GROUPS) do
        for _, tag in ipairs(grp.tags) do
            local sg = D.SIGNS[tag]
            if sg and sg.test then
                local ok, on, reading = pcall(sg.test, v)
                if ok and on then out[#out + 1] = { tag = tag, reading = reading or "" } end
            end
        end
    end
    return out
end

-- ------------------------------------------------------------- helpers
local function call(obj, method, ...)
    if not obj or not obj[method] then return nil end
    local ok, v = pcall(obj[method], obj, ...)
    if ok then return v end
    return nil
end
local function hours() return getGameTime and getGameTime():getWorldAgeHours() or 0 end

local ALIAS = { Sepsis = "sepsis", Knox_Infection = "knox_infection", Wound_Infection = "wound_infection",
    knox = "knox_infection", heat_exhaustion = "heat_stroke" }
function D.normalize(id)
    id = tostring(id or "")
    if ALIAS[id] then return ALIAS[id] end
    local low = id:lower()
    return ALIAS[low] or low
end

-- illnesses that are not "diseases" (exposure meters etc.) are never gated
function D.gated(id)
    return D.DISEASES[D.normalize(id)] ~= nil
end

function D.enabled()
    local o = SandboxVars and SandboxVars.HomeMedic
    if o and o.DiagnosisRequired == false then return false end
    return true
end

function D.store(player, create)
    local md = call(player, "getModData")
    if not md then return nil end
    if create and type(md[D.KEY]) ~= "table" then md[D.KEY] = {} end
    return md[D.KEY]
end

-- getter(key) -> table (patient modData or remote exam snapshot)
function D.getter(patient, exam)
    if type(exam) == "table" then return function(k) return exam[k] end end
    local md = call(patient, "getModData") or {}
    return function(k) return md[k] end
end

-- is `id` active on the patient right now?
function D.isActive(get, id, patient, exam)
    id = D.normalize(id)
    if id == "sepsis" then
        local s = get("EHR_Sepsis")
        return type(s) == "table" and (tonumber(s.stage) or 0) > 0
    end
    if id == "wound_infection" then
        local w = get("EHR_WoundInfection")
        if type(w) == "table" and type(w.parts) == "table" then
            for _, pd in pairs(w.parts) do
                if type(pd) == "table" and (tonumber(pd.stage) or 0) > 0 then return true end
            end
        end
        return false
    end
    if id == "knox_infection" then
        if type(exam) == "table" then
            return type(exam.EHR_KnoxStatus) == "table" and exam.EHR_KnoxStatus.infected == true
        end
        local K = EHR and EHR.KnoxCure
        if K and K.IsInfected and patient then
            local ok, r = pcall(K.IsInfected, patient)
            return ok and r == true
        end
        return false
    end
    local dis = get("EHR_Disease")
    local active = type(dis) == "table" and dis.active or nil
    if type(active) ~= "table" then return false end
    for k, v in pairs(active) do
        if v and D.normalize(k) == id then return true end
    end
    return false
end

-- every gated illness the patient has now
function D.activeIds(patient, exam)
    local get = D.getter(patient, exam)
    local list = {}
    for _, id in ipairs(D.ORDER) do
        if D.isActive(get, id, patient, exam) then list[#list + 1] = id end
    end
    return list
end

-- when the CURRENT bout of `id` began (game hours), or nil
function D.onset(get, id)
    id = D.normalize(id)
    if id == "sepsis" then
        local s = get("EHR_Sepsis")
        return type(s) == "table" and tonumber(s.startTime) or nil
    end
    if id == "wound_infection" then
        local w = get("EHR_WoundInfection")
        local first
        for _, pd in pairs(type(w) == "table" and type(w.parts) == "table" and w.parts or {}) do
            local t = type(pd) == "table" and (tonumber(pd.stage) or 0) > 0 and tonumber(pd.startTime) or nil
            if t and (not first or t < first) then first = t end
        end
        return first
    end
    local dis = get("EHR_Disease")
    local active = type(dis) == "table" and type(dis.active) == "table" and dis.active or {}
    for k, v in pairs(active) do
        if type(v) == "table" and D.normalize(k) == id then return tonumber(v.startTime) end
    end
    return nil
end

-- Request 2026-10-02: an illness that was cured and caught again must be
-- diagnosed again -- a diagnosis only counts for the bout it was made in
-- (made before that bout began = an old one). The server also drops
-- diagnoses of illnesses that are gone (D.prune).
function D.isDiagnosed(patient, id, exam)
    if not D.enabled() then return true end
    id = D.normalize(id)
    if not D.DISEASES[id] then return true end
    local data
    if type(exam) == "table" then data = exam[D.KEY] else data = D.store(patient) end
    local at = type(data) == "table" and data[id] or nil
    if at == nil then return false end
    local onset = tonumber(at) and D.onset(D.getter(patient, exam), id)
    if onset and onset > tonumber(at) + 0.01 then return false end
    return true
end

-- can the doctor recognise (and so pick) this illness?
function D.knows(doctor, id)
    id = D.normalize(id)
    local F = EHR and EHR.DiseaseFlyers
    if id == "knox_infection" then
        return F and F.KnowsDisease and F.KnowsDisease(doctor, "knox_infection") == true or false
    end
    if F and F.CanIdentifyDisease then
        local ok, r = pcall(F.CanIdentifyDisease, doctor, id)
        if ok then return r == true end
    end
    return HM_Surgery and HM_Surgery.knows and HM_Surgery.knows(doctor, id) or false
end

-- illnesses that show ALL the selected signs (selected: set tag -> true)
function D.candidates(selected)
    local out = {}
    for _, id in ipairs(D.ORDER) do
        local set, ok = D.TAGSET[id], true
        for t, on in pairs(selected or {}) do
            if on and not set[t] then ok = false; break end
        end
        if ok then out[#out + 1] = id end
    end
    return out
end

-- drop diagnoses of illnesses that are gone (a new infection starts unknown)
function D.prune(patient)
    local data = D.store(patient)
    if type(data) ~= "table" then return false end
    local get = D.getter(patient, nil)
    local changed = false
    for id, at in pairs(data) do
        local onset = tonumber(at) and D.onset(get, id)
        if not D.isActive(get, id, patient, nil) or (onset and onset > tonumber(at) + 0.01) then
            data[id] = nil; changed = true
        end
    end
    return changed
end

-- ------------------------------------------------------------- server
D.Server = D.Server or {}
local SV = D.Server

local function reply(doctor, command, args)
    if isServer and isServer() then
        if sendServerCommand then sendServerCommand(doctor, D.MODULE, command, args or {}) end
    elseif D.Client and D.Client.onServerCommand then
        D.Client.onServerCommand(D.MODULE, command, args or {})
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

local function distance(a, b)
    if a == b then return 0 end
    local ax, ay, bx, by = call(a, "getX"), call(a, "getY"), call(b, "getX"), call(b, "getY")
    if not (ax and ay and bx and by) then return 999 end
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- send the patient's own copy (MP: their client keeps its own modData)
function SV.push(patient)
    if isServer and isServer() and sendServerCommand then
        sendServerCommand(patient, D.MODULE, "Sync", { data = D.store(patient) or {} })
    end
end

function SV.Diagnose(doctor, args)
    args = type(args) == "table" and args or {}
    local id = D.normalize(args.id)
    local patient = findPatient(doctor, args)
    local base = { id = id, patientOnline = args.patientOnline, patientNum = args.patientNum }
    local function deny(reason)
        HMLog("Diagnose", "%s diagnosing %s for %s: DENIED (%s)", HMLogName(doctor), HMLogName(patient), tostring(id), tostring(reason))
        base.ok = false
        base.reason = reason
        reply(doctor, "Result", base)
    end
    if not patient or not D.DISEASES[id] then return deny("Invalid") end
    if distance(doctor, patient) > D.MAX_DISTANCE then return deny("TooFar") end
    if not D.knows(doctor, id) then return deny("Unknown") end
    if not D.isActive(D.getter(patient, nil), id, patient, nil) then return deny("Wrong") end
    local data = D.store(patient, true)
    data[id] = hours()
    HMLog("Diagnose", "%s diagnosed %s with %s", HMLogName(doctor), HMLogName(patient), tostring(id))
    base.ok = true
    base.data = data
    SV.push(patient)
    reply(doctor, "Result", base)
end

local function onClientCommand(module, command, player, args)
    if module ~= D.MODULE then return end
    if command == "Diagnose" then SV.Diagnose(player, args)
    else HMLog("Diagnose", "%s sent unknown command %s", HMLogName(player), tostring(command)) end
end

local function pruneAll()
    if isClient and isClient() then return end
    local online = getOnlinePlayers and getOnlinePlayers()
    -- (single player: the online list is empty -> the local players)
    if online and online:size() > 0 then
        for i = 0, online:size() - 1 do
            local p = online:get(i)
            if p and D.prune(p) then HMLog("Diagnose", "%s: healed illnesses' diagnoses dropped", HMLogName(p)); SV.push(p) end
        end
    elseif getSpecificPlayer then
        for n = 0, 3 do
            local p = getSpecificPlayer(n)
            if p and D.prune(p) then HMLog("Diagnose", "%s: healed illnesses' diagnoses dropped", HMLogName(p)) end
        end
    end
end

if Events and not D.registered then
    D.registered = true
    if Events.OnClientCommand then Events.OnClientCommand.Add(onClientCommand) end
    if Events.EveryTenMinutes then Events.EveryTenMinutes.Add(pruneAll) end
end

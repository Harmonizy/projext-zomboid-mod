--[[
    HARMONIE - Home Medic : vitamin deficiencies from our "From Garden to
    Plate" mod (shared)

    Request 2026-10-02: when HARMONIE_GardenToPlate is loaded, its vitamin
    deficiencies are real conditions here: diagnosed like any illness, with
    a disease-handbook page and their remedies in the medication handbook.
    Without GTP nothing of this exists.

    One condition per vitamin, id "vitdef_<letter>" (lower case, like every
    HM_Diagnosis id). It is ACTIVE while GTP marks the vitamin afflicted
    (Reserve fell below Critical and has not climbed back to Sufficient).
    Its signs are what GTP really does while the penalty runs
    (HARMONIE_VitaminEffects.lua):
        A  INTOXICATION floor  -> blurred vision
        B  STRESS floor        -> stress
        C  random head scratch -> bleeding gums / nosebleed
        D  stiffness 20 on every body part -> stiffness
        E  UNHAPPINESS floor   -> low mood
        K  overall health capped 10 lower -> health never full
        all: Endurance capped 10 points lower per deficient vitamin -> weakness
    Recognising one: First Aid 5 (GTP's own bar to read a nutrition check),
    Cooking 3 or the Nutritionist trait.

    Multivitamin pills: EHR treats Base.PillsVitamins as caffeine pills
    (12 h without sleep, then a crash), GTP as multivitamins (+1 pause day
    to every vitamin). With both mods each pill did both. With GTP loaded
    the EHR entry becomes a plain multivitamin (no caffeine, no crash).
]]--

require "HARMONIEHomeMedic/HM_Diagnosis"

HM_Vitamins = HM_Vitamins or {}
local V = HM_Vitamins
local D = HM_Diagnosis

V.LETTERS = { "A", "B", "C", "D", "E", "K" }
V.TAGS = {
    A = { "blurred", "weakness" },
    B = { "stress", "weakness" },
    C = { "bleeding_gums", "weakness" },
    D = { "stiffness", "weakness" },
    E = { "low_mood", "weakness" },
    K = { "low_max_health", "weakness" },
}
-- new signs and the diagnosis chip group they join
V.NEW_TAGS = { { "low_max_health", "general" }, { "bleeding_gums", "body" }, { "low_mood", "mind" } }

local function call(obj, method, ...)
    if not obj or not obj[method] then return nil end
    local ok, v = pcall(obj[method], obj, ...)
    if ok then return v end
    return nil
end

function V.enabled()
    return HARMONIE_GTP ~= nil and type(HARMONIE_GTP.Vitamins) == "table"
end

function V.id(letter) return "vitdef_" .. string.lower(letter) end
function V.letter(id)
    id = tostring(id or "")
    if id:sub(1, 7) ~= "vitdef_" then return nil end
    return string.upper(id:sub(8, 8))
end
function V.ids()
    local out = {}
    for _, l in ipairs(V.LETTERS) do out[#out + 1] = V.id(l) end
    return out
end

-- the GTP store of a patient: getter (modData or exam snapshot) first
function V.store(get, patient)
    local s = get and get("HARMONIE_Vitamins")
    if type(s) ~= "table" and patient then
        local md = call(patient, "getModData")
        s = md and md.HARMONIE_Vitamins
    end
    return type(s) == "table" and s or nil
end

-- can this survivor recognise a vitamin deficiency?
local NUTRITIONIST
function V.knows(doctor)
    if not doctor then return false end
    local fa = Perks and Perks.Doctor and tonumber(call(doctor, "getPerkLevel", Perks.Doctor)) or 0
    local need = HARMONIE_GTP and HARMONIE_GTP.Config and HARMONIE_GTP.Config.assessmentRequiredFirstAid or 5
    if fa >= need then return true end
    local cook = Perks and Perks.Cooking and tonumber(call(doctor, "getPerkLevel", Perks.Cooking)) or 0
    if cook >= 3 then return true end
    if NUTRITIONIST == nil then
        local ok, t = pcall(function() return CharacterTrait.get(ResourceLocation.of("Nutritionist")) end)
        NUTRITIONIST = ok and t or false
    end
    if NUTRITIONIST then
        local ok, has = pcall(function() return doctor:hasTrait(NUTRITIONIST) end)
        if ok and has then return true end
    end
    return false
end

-- ------------------------------------------------------------- registration
local function patchPills()
    local M = EHR and EHR.Medication
    local db = M and M.Database
    if type(db) ~= "table" or V.pillsPatched then return end
    V.pillsPatched = true
    db["Base.PillsVitamins"] = {
        tier = 0,
        treats = {},
        displayName = "Multivitamin Pills",
        usageMessage = "You take a multivitamin.",
        -- HomeMedic only: what the medication handbook lists it for
        hmEases = V.ids(),
    }
    -- and no "strong caffeine pills" tooltip block (GTP's own tooltip explains it)
    if EHR.Tooltips and type(EHR.Tooltips.Data) == "table" then EHR.Tooltips.Data["Base.PillsVitamins"] = nil end
end

function V.register()
    if V.registered or not V.enabled() or not D then return V.registered == true end
    V.registered = true
    -- signs
    for _, nt in ipairs(V.NEW_TAGS) do
        for _, g in ipairs(D.GROUPS) do
            if g.id == nt[2] then
                local have = false
                for _, t in ipairs(g.tags) do if t == nt[1] then have = true end end
                if not have then g.tags[#g.tags + 1] = nt[1] end
            end
        end
        D.SIGNS[nt[1]] = D.SIGNS[nt[1]] or { at = "observe" }
    end
    -- conditions
    for _, l in ipairs(V.LETTERS) do
        local id = V.id(l)
        D.DISEASES[id] = V.TAGS[l]
        local set = {}
        for _, t in ipairs(V.TAGS[l]) do set[t] = true end
        D.TAGSET[id] = set
        D.ORDER[#D.ORDER + 1] = id
    end
    -- active / known
    local isActive, knows = D.isActive, D.knows
    function D.isActive(get, id, patient, exam)
        local l = V.letter(D.normalize(id))
        if l then
            local s = V.store(get, patient)
            local e = s and s[l]
            return type(e) == "table" and e.afflicted == true
        end
        return isActive(get, id, patient, exam)
    end
    function D.knows(doctor, id)
        if V.letter(D.normalize(id)) then return V.knows(doctor) end
        return knows(doctor, id)
    end
    patchPills()
    if HM_Handbook then HM_Handbook._meds = nil end   -- rebuilt with the vitamin entries
    return true
end

-- GTP loads with its own mod: try now and once everything is loaded
V.register()
if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(V.register) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(V.register) end
    if Events.OnGameStart then Events.OnGameStart.Add(V.register) end
end

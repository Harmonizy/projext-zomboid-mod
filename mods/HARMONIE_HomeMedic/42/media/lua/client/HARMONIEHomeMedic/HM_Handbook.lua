--[[
    HARMONIE - Home Medic : handbook text built from the game's own data (client)

    Request 2026-10-01: the handbook (tab 5) must say what really happens in
    game, and pair every sign with where it shows, so a diagnosis can be
    made step by step:

    HM_Handbook.symptoms(id)   -- per stage, from the stage effects EHR
                                  applies (EHR.Disease.Diseases[id].effects,
                                  EHR.Sepsis.StageEffects, wound infection
                                  STAGE_EFFECTS); the sign list otherwise
    HM_Handbook.howToCheck(id) -- each sign of the illness (HM_Diagnosis)
                                  and where to read it: tab 3 "Signs" with
                                  the threshold, or watch the patient
    HM_Handbook.treatment(id)  -- the medicines EHR.Medication.Database
                                  lists for it: tier 2+ cure, tier 0-1 only
                                  ease the symptoms; plus "no cure" notes
]]--

require "HARMONIEHomeMedic/HM_Text"

HM_Handbook = HM_Handbook or {}
local H = HM_Handbook

local function L(key, fallback, ...) return HM_Text("UI_HomeMedic_Hb_" .. key, fallback, ...) end
local function C() return HM_Diagnosis and HM_Diagnosis.Client end
local function tagName(tag)
    local c = C()
    if c and c.tagName then return c.tagName(tag) end
    return HM_Text("UI_HomeMedic_Diag_Tag_" .. tag, tag)
end

local function stageTables(id)
    if id == "sepsis" then return EHR and EHR.Sepsis and EHR.Sepsis.StageEffects end
    if id == "wound_infection" then
        local cfg = EHR and EHR.WoundInfection and EHR.WoundInfection.Config
        return cfg and cfg.STAGE_EFFECTS
    end
    local def = EHR and EHR.Disease and EHR.Disease.Diseases and EHR.Disease.Diseases[id]
    return def and def.effects
end

-- ------------------------------------------------------------- vitamins
-- vitamin deficiencies of our Garden to Plate mod (HM_Vitamins)
local function vitLetter(id) return HM_Vitamins and HM_Vitamins.letter(id) end
local function DL(key, fallback, ...) return HM_Text("UI_HomeMedic_Diag_" .. key, fallback, ...) end

-- the foods richest in a vitamin -> { {fullType, amount, displayName}, ... }
function H.topFoods(letter, limit)
    local G = HARMONIE_GTP
    if not (G and G.GetTopFoods) then return {} end
    local ok, list = pcall(G.GetTopFoods, letter, limit or 6)
    return ok and type(list) == "table" and list or {}
end

local function foodNames(letter, limit)
    local out = {}
    for _, f in ipairs(H.topFoods(letter, limit)) do out[#out + 1] = tostring(f.displayName or f.fullType) end
    return out
end
H.foodNames = foodNames

local function vitSymptoms(id, l)
    local lines = { DL("Vit_Effect_" .. l, l), DL("Vit_Endurance", "Endurance capped 10% lower (stacks per vitamin)") }
    local tags = {}
    for _, t in ipairs(HM_Diagnosis and HM_Diagnosis.DISEASES[id] or {}) do tags[#tags + 1] = tagName(t) end
    if #tags > 0 then lines[#lines + 1] = L("Signs", "Signs: %1", table.concat(tags, ", ")) end
    lines[#lines + 1] = L("VitShield", "No effect while the vitamin still has a banked day (from a good meal or a multivitamin).")
    return table.concat(lines, "\n")
end

local function vitTreatment(id, l)
    local cfg = HARMONIE_GTP and HARMONIE_GTP.Config or {}
    local lines = {}
    local foods = foodNames(l, 6)
    lines[#lines + 1] = L("VitCure", "Cures it: eat foods rich in vitamin %1 until it is back to %2 (Sufficient).", l, cfg.sufficientThreshold or 50)
    if #foods > 0 then lines[#lines + 1] = L("VitFoods", "Best sources: %1", table.concat(foods, ", ")) end
    lines[#lines + 1] = L("VitPills", "Multivitamin Pills only hold the effects off for a day each; they do not raise the vitamin.")
    lines[#lines + 1] = L("SeeMeds", "Details of each medicine: Medication Handbook tab.")
    return table.concat(lines, "\n")
end

function H.symptoms(id)
    local vl = vitLetter(id)
    if vl then return vitSymptoms(id, vl) end
    local c = C()
    local lines = {}
    local stages = stageTables(id)
    if type(stages) == "table" and c and c.effectLines then
        local keys = {}
        for k in pairs(stages) do if type(k) == "number" then keys[#keys + 1] = k end end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local eff = c.effectLines(stages[k])
            if #eff > 0 then lines[#lines + 1] = L("Stage", "Stage %1: %2", k, table.concat(eff, ", ")) end
        end
    end
    local tags = {}
    for _, t in ipairs(HM_Diagnosis and HM_Diagnosis.DISEASES[id] or {}) do tags[#tags + 1] = tagName(t) end
    if #tags > 0 then lines[#lines + 1] = L("Signs", "Signs: %1", table.concat(tags, ", ")) end
    local def = EHR and EHR.Disease and EHR.Disease.Diseases and EHR.Disease.Diseases[id]
    if def and def.reverseProgression then
        lines[#lines + 1] = L("Reverse", "Starts at its worst stage and eases by itself over time.")
    end
    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end

function H.howToCheck(id)
    local D = HM_Diagnosis
    if not (D and D.DISEASES[id]) then return nil end
    local lines = {}
    for _, t in ipairs(D.DISEASES[id]) do
        local where = HM_Text("UI_HomeMedic_SignWhere_" .. t, "")
        if where == "" then
            local sg = D.SIGNS and D.SIGNS[t]
            where = (sg and sg.at == "stats") and L("WhereStats", "Tab 3, Signs") or L("WhereObserve", "Watch and listen to the patient")
        end
        lines[#lines + 1] = "- " .. tagName(t) .. ": " .. where
    end
    if vitLetter(id) then
        lines[#lines + 1] = L("VitCheck", "Vitamin %1 level: Body Stats tab, Vitamins group (red below Sufficient), or Garden to Plate's nutrition check.", vitLetter(id))
    end
    lines[#lines + 1] = L("CheckHint", "Tab 3 (needs a medical monitor watch) lists the signs it can measure right now; tick the matching signs in tab 4 to diagnose.")
    return table.concat(lines, "\n")
end

local function itemName(fullType, med)
    if getItemNameFromFullType then
        local ok, n = pcall(getItemNameFromFullType, fullType)
        if ok and n and n ~= "" and n ~= fullType then return n end
    end
    return med and med.displayName or fullType
end

-- ------------------------------------------------------------- medicines
-- Same rule as EHR (EHR_MedicationCanCure): a medicine cures when its tier
-- can cure (2+) or it has its own cure time, unless it is prevention only
-- or marked canCure = false. Everything else only eases the symptoms.
function H.isCurative(med)
    if type(med) ~= "table" then return false end
    if med.preventionOnly == true or med.canCure == false then return false end
    local tiers = EHR and EHR.Medication and EHR.Medication.TierEffectiveness
    local te = tiers and tiers[tonumber(med.tier) or 0]
    return (te and te.canCure == true) or med.canCure == true or med.cureTimeHours ~= nil
        or med.diseaseCureTimeHours ~= nil or med.isKnoxCure == true
end

local function itemExists(fullType)
    local sm = getScriptManager and getScriptManager()
    if not sm then return true end
    local ok, it = pcall(function() return sm:FindItem(fullType) end)
    return ok and it ~= nil
end
H.itemExists = itemExists

-- every medicine of the game (items another mod adds only when it is loaded)
function H.meds()
    if H._meds then return H._meds end
    local db = EHR and EHR.Medication and EHR.Medication.Database
    local out = {}
    if type(db) ~= "table" then return out end
    for fullType, med in pairs(db) do
        if type(med) == "table" and itemExists(fullType) then
            local treats = {}
            for _, t in ipairs(med.treats or {}) do
                treats[#treats + 1] = HM_Diagnosis and HM_Diagnosis.normalize(t) or t
            end
            local curative = H.isCurative(med) and #treats > 0
            -- HM_Vitamins: the multivitamin only holds the deficiencies off
            for _, t in ipairs(type(med.hmEases) == "table" and med.hmEases or {}) do treats[#treats + 1] = t end
            out[#out + 1] = { id = fullType, med = med, name = itemName(fullType, med), tier = tonumber(med.tier) or 0,
                curative = curative, treats = treats, vitamin = med.hmEases ~= nil or nil }
        end
    end
    -- HM_Vitamins: food is the real cure of a vitamin deficiency
    local V = HM_Vitamins
    if V and V.registered then
        for _, l in ipairs(V.LETTERS) do
            local top = H.topFoods(l, 1)[1]
            out[#out + 1] = { id = "food:" .. l, med = { tier = 0, hmFood = l, icon = nil }, food = l, vitamin = true,
                iconType = top and top.fullType or nil,
                name = L("FoodName", "Foods rich in vitamin %1", l), tier = 0, curative = true, treats = { V.id(l) } }
        end
    end
    table.sort(out, function(a, b)
        if a.curative ~= b.curative then return a.curative end
        return tostring(a.name) < tostring(b.name)
    end)
    H._meds = out
    return out
end

-- names of the medicines listed for an illness (search text)
function H.medNames(id)
    local out = {}
    for _, m in ipairs(H.meds()) do
        for _, t in ipairs(m.treats) do if t == id then out[#out + 1] = m.name end end
    end
    local vl = vitLetter(id)
    if vl then for _, n in ipairs(foodNames(vl, 6)) do out[#out + 1] = n end end
    return out
end

function H.treatment(id)
    local vl = vitLetter(id)
    if vl then return vitTreatment(id, vl) end
    local cure, ease = {}, {}
    for _, m in ipairs(H.meds()) do
        for _, t in ipairs(m.treats) do
            if t == id then
                if m.curative then cure[#cure + 1] = m.name else ease[#ease + 1] = m.name end
            end
        end
    end
    local lines = {}
    if #cure > 0 then lines[#lines + 1] = L("Cures", "Cures it (course of treatment): %1", table.concat(cure, ", ")) end
    if #ease > 0 then lines[#lines + 1] = L("Eases", "Only eases the symptoms: %1", table.concat(ease, ", ")) end
    local def = EHR and EHR.Disease and EHR.Disease.Diseases and EHR.Disease.Diseases[id]
    if def and (def.noCure or def.noStandardTreatment) and #cure == 0 then
        lines[#lines + 1] = L("NoCure", "No medicine cures it: rest and wait it out.")
    elseif #cure == 0 and #ease == 0 then
        lines[#lines + 1] = L("NoMeds", "No medicine in the game is listed for it.")
    end
    lines[#lines + 1] = L("SeeMeds", "Details of each medicine: Medication Handbook tab.")
    return table.concat(lines, "\n")
end

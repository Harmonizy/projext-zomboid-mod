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

function H.symptoms(id)
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

function H.treatment(id)
    local db = EHR and EHR.Medication and EHR.Medication.Database
    local cure, ease = {}, {}
    if type(db) == "table" then
        local keys = {}
        for fullType in pairs(db) do keys[#keys + 1] = fullType end
        table.sort(keys)
        for _, fullType in ipairs(keys) do
            local med = db[fullType]
            for _, t in ipairs(type(med) == "table" and med.treats or {}) do
                if t == id then
                    local n = itemName(fullType, med)
                    if (tonumber(med.tier) or 0) >= 2 then cure[#cure + 1] = n else ease[#ease + 1] = n end
                end
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
    return table.concat(lines, "\n")
end

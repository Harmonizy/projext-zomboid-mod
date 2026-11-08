--[[
    HARMONIE - Home Medic : handbook text built from the game's own data (client)

    Request 2026-10-01: the handbook (tab 5) must say what really happens in
    game, and pair every sign with where it shows, so a diagnosis can be
    made step by step:

    HM_Handbook.symptoms(id)   -- per stage, the signs the code really
                                  gives (HM_Diagnosis.STAGE_SIGNS, R59) and
                                  the real numbers of the stage table
    HM_Handbook.howToCheck(id) -- each sign of the illness (HM_Diagnosis)
                                  and where to read it: tab 3 "Signs" with
                                  the threshold, or watch the patient
    HM_Handbook.treatment(id)  -- the medicines EHR.Medication.Database
                                  lists for it: tier 2+ cure, tier 0-1 only
                                  ease the symptoms; plus "no cure" notes
                                  and what else really helps (H.CARE)
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

-- R59: per stage, the signs of HM_Diagnosis.STAGE_SIGNS (what the code
-- really does, in the diagnosis chips' words) + the real numbers of the
-- stage table (HM_Diagnosis.Client.stageLines)
function H.symptoms(id)
    local D, c = HM_Diagnosis, C()
    local st = D and D.STAGE_SIGNS and D.STAGE_SIGNS[id]
    if not st then return nil end
    local lines = {}
    if st.all then
        lines[#lines + 1] = L("AllStages", "Every stage: %1", c and c.signText and c.signText(id, st.all) or "")
    else
        local keys = {}
        for k in pairs(st) do if type(k) == "number" then keys[#keys + 1] = k end end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local parts = c and c.stageLines and c.stageLines(id, k) or {}
            -- "Signs: a, b" -> "a, b" inside the stage line
            local tags = D.stageSigns(id, k)
            local first = #tags > 0 and c.signText(id, tags) or L("NoSigns", "no signs yet")
            local rest = {}
            for i = 2, #parts do rest[#rest + 1] = parts[i] end
            local text = first
            if #rest > 0 then text = text .. "; " .. table.concat(rest, ", ") end
            lines[#lines + 1] = L("Stage", "Stage %1: %2", k, text)
        end
    end
    local def = EHR and EHR.Disease and EHR.Disease.Diseases and EHR.Disease.Diseases[id]
    if def and def.reverseProgression then
        lines[#lines + 1] = L("Reverse", "Starts at its worst stage and eases by itself over time.")
    end
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
            out[#out + 1] = { id = fullType, med = med, name = itemName(fullType, med), tier = tonumber(med.tier) or 0,
                curative = H.isCurative(med) and #treats > 0, treats = treats }
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
    return out
end

-- what helps besides medicine, checked in EHR's code (R59):
--   hypothermia: its stage follows the body temperature (EHR.BodyTemp), and
--     it cannot kill while IsWarmEnoughForRecovery
--   heat stroke: a cold bath (EHR_HeatStrokeBath, 8 water, 3 h) cures it
--   dysentery: it kills by thirst (killMechanic "dehydration")
--   insomnia: only a sleep aid lets you fall asleep (HasActiveSleepAid)
--   painkiller addiction: an active painkiller dose holds off withdrawal
--   (concussion eases with time -- the "Reverse" line of H.symptoms;
--     delirium does NOT: it lasts until a medicine cures it)
H.CARE = {
    hypothermia = "Warm up: get dry and warm (warm room, fire, dry clothes). The stage follows the body temperature, and it cannot kill while you are warm.",
    heat_stroke = "Cool down: a cold bath (right-click a bathtub with 8 units of water, 3 hours) cures it.",
    dysentery = "Keep drinking: it kills through thirst.",
    insomnia = "Only a sleep aid lets you fall asleep while it lasts.",
    painkiller_addiction = "An active painkiller dose holds the withdrawal off for a while.",
}

-- ------------------------------------------------------------- how it ends
-- 2026-11-08 (owner: "มีข้อมูลนี้ในคู่มือไหม มี indicator หรือมีคำอะไรบอกไหม ควรชัดเจน"):
-- one clear verdict per illness -- needs surgery / a medicine course cures
-- it / it clears by itself (and how long) / it does not -- as badges in the
-- disease handbook and its list, plus one paragraph. Built from the game's
-- data (HM_Surgery.SURGICAL, the curing medicines, the illness's duration);
-- H.NO_SELF / H.OUT_NOTE are the cases the code handles on its own way.
H.NO_SELF = {
    wound_infection = "It does not clear by itself: left alone it turns into sepsis (about 84 hours).",
    sepsis = "It does not clear by itself: it keeps getting worse.",
    cellulitis = "It does not clear by itself: its last stage turns into sepsis.",
    delirium = "It never clears by itself: only antipsychotics end it.",
    knox_infection = "It does not clear: the zombie infection. Only the experimental gene therapy, or cutting off a bitten arm in time (no other bite), saves you.",
}
-- illnesses that end by something other than a medicine or time alone
H.OUT_SPECIAL = {
    hypothermia = { key = "self", tag = "Clears once warm", text = "It clears only once the body is warm again; while you stay cold it stays at its worst stage." },
    heat_stroke = { key = "meds", tag = "Cooling cures it", text = "Cooling the body cures it (see below)." },
}
H.OUT_NOTE = {
    common_cold = "Untreated, it may turn into pneumonia (35 percent).",
    concussion = "No medicine helps; brain surgery ends it at once.",
    dysentery = "Keep drinking: it harms you through thirst.",
    heat_stroke = "Cool down: an instant ice pack, or a cold bath (a bathtub with 8 units of water, 3 hours).",
    tuberculosis = "It takes weeks: a medicine course is much faster.",
}
local function spanText(def)
    local a, b = tonumber(def and def.durationMin), tonumber(def and def.durationMax)
    if not a or not b or b >= 9999 then return nil end
    if b < 24 then return L("Out_Hours", "%1-%2 hours", math.floor(a + 0.5), math.floor(b + 0.5)) end
    local da, db = math.max(1, math.floor(a / 24 + 0.5)), math.max(1, math.floor(b / 24 + 0.5))
    if da == db then return L("Out_Day", "%1 days", da) end
    return L("Out_Days", "%1-%2 days", da, db)
end

-- { tags = { { key, text } ... }, text = paragraph }; key: surgery | meds | self | noself
function H.outcome(id)
    id = HM_Diagnosis and HM_Diagnosis.normalize(id) or id
    local out = { tags = {}, lines = {} }
    local S = HM_Surgery
    local surgical = S and S.SURGICAL and S.SURGICAL[id] ~= nil
    local cure = 0
    for _, m in ipairs(H.meds()) do
        for _, t in ipairs(m.treats) do if t == id and m.curative then cure = cure + 1 end end
    end
    local defs = EHR and EHR.Disease and EHR.Disease.Diseases
    local def = defs and (defs[id] or (id == "knox_infection" and defs.Knox_Infection))
    local function tag(key, text) out.tags[#out.tags + 1] = { key = key, text = text } end
    local sp = H.OUT_SPECIAL[id]
    if sp then
        tag(sp.key, L("Out_Tag_" .. id, sp.tag))
        out.lines[#out.lines + 1] = L("Out_Special_" .. id, sp.text)
    end
    if sp then
        -- its own verdict above; only the time it takes, when it has one
    elseif surgical then
        tag("surgery", L("Out_Surgery", "Needs surgery"))
        out.lines[#out.lines + 1] = L("Out_SurgeryText", "Needs surgery: its medicine only holds it (Awaiting surgery) and does not cure it. A successful operation starts the treatment.")
    elseif cure > 0 or id == "heat_stroke" then
        tag("meds", L("Out_Meds", "Medicine cures it"))
        out.lines[#out.lines + 1] = L("Out_MedsText", "A course of its medicine cures it (see Treatment).")
    end
    if H.NO_SELF[id] then
        tag("noself", L("Out_NoSelf", "Does not clear by itself"))
        out.lines[#out.lines + 1] = L("Out_NoSelf_" .. id, H.NO_SELF[id])
    elseif not surgical and not (sp and sp.key == "self") then
        local span = spanText(def)
        if span then
            tag("self", L("Out_Self", "Clears by itself: %1", span))
            out.lines[#out.lines + 1] = L("Out_SelfText", "Left alone it clears by itself in about %1.", span)
        end
    end
    if H.OUT_NOTE[id] then out.lines[#out.lines + 1] = L("Out_Note_" .. id, H.OUT_NOTE[id]) end
    out.text = table.concat(out.lines, "\n")
    return out
end

function H.treatment(id)
    local cure, ease = {}, {}
    for _, m in ipairs(H.meds()) do
        for _, t in ipairs(m.treats) do
            if t == id then
                if m.curative then cure[#cure + 1] = m.name else ease[#ease + 1] = m.name end
            end
        end
    end
    local lines = {}
    -- R59: what else really helps, read from the code
    local care = H.CARE[id]
    if care then lines[#lines + 1] = L("Care_" .. id, care) end
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

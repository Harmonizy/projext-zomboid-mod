--[[
    Extensive Health Rework B42
    Disease Handbook UI

    Replaces the old diagnosis-history journal with a compact disease codex.
    The data journal still exists for persistence/statistics, but J opens this UI.
]]--

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "ExtensiveHealth/EHR_Main"
require "ExtensiveHealth/EHR_Disease"
require "ExtensiveHealth/EHR_DiseaseFlyers"
pcall(function() require "ExtensiveHealth/EHR_Localization" end)

EHR_MedicalJournalUI = ISPanel:derive("EHR_MedicalJournalUI")
EHR_MedicalJournalUI.instance = nil

require "HARMONIEHomeMedic/Surgery/HM_Surgery"
require "HARMONIEHomeMedic/HM_Text"
local WINDOW_WIDTH = 900
local WINDOW_HEIGHT = 640
local PADDING = 14
local HEADER_HEIGHT = 42
local LIST_WIDTH = 326
local SEARCH_H = 24     -- HARMONIE: search box


local function L(key, fallback)
    return EHR.Locale.Text(key, fallback)
end

local function LF(key, fallback, ...)
    return EHR.Locale.Format(key, fallback, ...)
end

local function codexKey(diseaseId, field)
    diseaseId = tostring(diseaseId or "unknown"):gsub("[^%w_]", "_")
    return "UI_EHR_Codex_" .. diseaseId .. "_" .. tostring(field or "Text")
end

local function codexText(diseaseId, field, fallback)
    return L(codexKey(diseaseId, field), fallback)
end

local Colors = {
    -- HARMONIE: blue theme (HM_Theme); red stays for danger
    accent = { r = 0.3, g = 0.84, b = 1.0, a = 1.0 },
    bg = { r = 0.012, g = 0.05, b = 0.068, a = 0.97 },
    panel = { r = 0.025, g = 0.085, b = 0.115, a = 0.94 },
    panelSoft = { r = 0.05, g = 0.14, b = 0.18, a = 0.72 },
    header = { r = 0.02, g = 0.075, b = 0.1, a = 0.98 },
    red = { r = 0.95, g = 0.08, b = 0.07, a = 1.0 },
    redDark = { r = 0.03, g = 0.24, b = 0.34, a = 1.0 },
    orange = { r = 1.0, g = 0.38, b = 0.12, a = 1.0 },
    green = { r = 0.18, g = 0.92, b = 0.32, a = 1.0 },
    cyan = { r = 0.22, g = 0.82, b = 1.0, a = 1.0 },
    yellow = { r = 1.0, g = 0.78, b = 0.12, a = 1.0 },
    text = { r = 0.9, g = 0.93, b = 0.97, a = 1.0 },
    textDim = { r = 0.6, g = 0.67, b = 0.74, a = 1.0 },
    border = { r = 0.22, g = 0.72, b = 0.95, a = 1.0 },
    borderDim = { r = 0.1, g = 0.34, b = 0.46, a = 1.0 },
}

local DiseaseIcons = {
    unknown = "media/textures/EHR_Disease_Unknown.png",
    ahtr = "media/textures/EHR_Disease_AHTR.png",
    cadaveric_aspergillosis = "media/textures/EHR_Disease_CadavericAspergillosis.png",
    cellulitis = "media/textures/EHR_Disease_Cellulitis.png",
    common_cold = "media/textures/EHR_Disease_CommonCold.png",
    concussion = "media/textures/EHR_Disease_Concussion.png",
    corpse_sickness = "media/textures/EHR_Disease_CorpseSickness.png",
    delirium = "media/textures/EHR_Disease_Delirium.png",
    dysentery = "media/textures/EHR_Disease_Dysentery.png",
    food_poisoning = "media/textures/EHR_Disease_FoodPoisoning.png",
    gastroenteritis = "media/textures/EHR_Disease_Gastroenteritis.png",
    heat_exhaustion = "media/textures/EHR_Disease_HeatExhaustion.png",
    heat_stroke = "media/textures/EHR_Disease_HeatStroke.png",
    hyperkeratotic_scabies = "media/textures/EHR_Disease_hyperkeratoticScabies.png",
    hypothermia = "media/textures/EHR_Disease_Hypotermia.png",
    insomnia = "media/textures/EHR_Disease_Insomina.png",
    painkiller_addiction = "media/textures/EHR_Disease_PainkillerAddiction.png",
    knox_infection = "media/textures/EHR_Disease_KnoxInfection.png",
    pneumonia = "media/textures/EHR_Disease_Pneumonia.png",
    sepsis = "media/textures/EHR_Disease_Sepsis.png",
    tetanus = "media/textures/EHR_Disease_Tetanus.png",
    toxin_poisoning = "media/textures/EHR_Disease_ToxinPoisoning.png",
    trichinosis = "media/textures/EHR_Disease_Trichinosis.png",
    tuberculosis = "media/textures/EHR_Disease_Tuberculosis.png",
    wound_infection = "media/textures/EHR_Disease_Wound_Infection.png",
}

local CategoryNames = {
    food = "Food-borne",
    environmental = "Environmental",
    wound = "Wound / trauma",
    corpse = "Corpse exposure",
    infection = "Infection",
    blood = "Blood / transfusion",
    mental = "Mental",
}

local CategoryUnknownNames = {
    food = "Unknown Food-borne Illness",
    environmental = "Unknown Environmental Illness",
    wound = "Unknown Wound Illness",
    corpse = "Unknown Corpse-related Illness",
    infection = "Unknown Infection",
    blood = "Unknown Blood Reaction",
    mental = "Unknown Mental Condition",
}

local CatalogOrder = {
    "food_poisoning",
    "gastroenteritis",
    "trichinosis",
    "toxin_poisoning",
    "dysentery",
    "common_cold",
    "pneumonia",
    "hypothermia",
    "heat_exhaustion",
    "heat_stroke",
    "corpse_sickness",
    "cadaveric_aspergillosis",
    "tuberculosis",
    "wound_infection",
    "cellulitis",
    "sepsis",
    "tetanus",
    "hyperkeratotic_scabies",
    "concussion",
    "delirium",
    "insomnia",
    "painkiller_addiction",
    "ahtr",
    "knox_infection",
}

local CodexInfo = {
    food_poisoning = {
        category = "food",
        cause = "Rotten food, burned food, or stale food.",
        symptoms = "Nausea, vomiting, endurance drain, increased hunger and thirst.",
        prevention = "Eat fresh food and avoid food that has spoiled, burned badly, or gone stale.",
        treatment = "Anti-nausea tablets, electrolyte powder, and activated charcoal. Activated charcoal can cure it over time.",
    },
    gastroenteritis = {
        category = "food",
        cause = "Eating with bloody or dirty hands.",
        symptoms = "Severe nausea, vomiting, dehydration, stomach pain, and fatigue.",
        prevention = "Wash hands before eating. Soap and clean water are best.",
        treatment = "Anti-diarrheal medicine, electrolyte powder, antiviral capsules, or IV ciprofloxacin for severe bacterial cases.",
    },
    trichinosis = {
        category = "food",
        cause = "Raw or undercooked wild game and unsafe raw meat.",
        symptoms = "Intense muscle pain, fever, weakness, and dangerous health loss in severe stages.",
        prevention = "Cook meat thoroughly, especially wild game.",
        treatment = "Muscle relaxants and anti-inflammatory medicine for symptoms; antiparasitic pills or albendazole injection to cure.",
    },
    toxin_poisoning = {
        category = "food",
        cause = "Poisonous berries, poisonous mushrooms, or other toxic food.",
        symptoms = "Violent nausea, vomiting, dizziness, blurred vision, weakness, and dangerous systemic poisoning.",
        prevention = "Avoid unidentified wild food unless you can verify it is safe.",
        treatment = "Activated charcoal is the main treatment. Anti-nausea tablets and electrolytes help symptoms.",
    },
    dysentery = {
        category = "environmental",
        cause = "Tainted water or severe gastrointestinal contamination.",
        symptoms = "Severe diarrhea, vomiting, dehydration, fever, weakness, and possible blood loss.",
        prevention = "Drink clean or boiled water and avoid unsafe water sources.",
        treatment = "Electrolytes and anti-diarrheal medicine for symptoms; IV ciprofloxacin for severe bacterial infection.",
    },
    common_cold = {
        category = "environmental",
        cause = "Cold, wet, or prolonged exposure while exhausted.",
        symptoms = "Coughing, sneezing, mild fever, fatigue, and reduced stamina.",
        prevention = "Stay warm, dry, rested, and protected from bad weather.",
        treatment = "Rest, fluids, cough medicine, antipyretics for fever; Cold & Flu tablets or antiviral capsules can cure it over time.",
    },
    pneumonia = {
        category = "environmental",
        cause = "Severe or untreated respiratory illness, cold exposure, or weakened health.",
        symptoms = "Fever, coughing, chest pain, endurance loss, and potentially lethal respiratory failure.",
        prevention = "Treat respiratory illness early and avoid prolonged cold exposure.",
        treatment = "Prescription or broad spectrum antibiotics cure over time; IV Ciprofloxacin is the fast clinical cure. Bronchodilator helps breathing, cough medicine suppresses coughing, antipyretics reduce fever.",
    },
    hypothermia = {
        category = "environmental",
        cause = "Low body temperature from cold, wet clothing, wind, or exposure.",
        symptoms = "Shivering, weakness, confusion, fatigue, and dangerous temperature drop.",
        prevention = "Wear insulation, stay dry, and get indoors during severe cold.",
        treatment = "Warm up, change into dry clothes, rest, and use external heat sources.",
    },
    heat_exhaustion = {
        category = "environmental",
        cause = "Heat exposure, dehydration, heavy clothing, or exertion in hot weather.",
        symptoms = "Dizziness, nausea, weakness, thirst, fatigue, and overheating.",
        prevention = "Hydrate, rest in shade, wear lighter clothing, and avoid overexertion in heat.",
        treatment = "Cool down, rest, drink water, and use electrolyte powder.",
    },
    heat_stroke = {
        category = "environmental",
        name = "Heat Stroke",
        incubation = "Can develop from untreated heat exhaustion.",
        duration = "Critical until body temperature is controlled.",
        cause = "Extreme heat exposure or severe dehydration.",
        symptoms = "Extreme body temperature, delirium, confusion, vomiting, collapse/blackouts, dehydration, and life-threatening health loss.",
        prevention = "Avoid extreme heat, hydrate aggressively, and treat heat exhaustion early.",
        treatment = "Immediate cooling. Instant ice packs can cure heat stroke with a 4-dose cooling course; fluids and electrolytes help dehydration.",
    },
    corpse_sickness = {
        category = "corpse",
        cause = "Prolonged exposure to decomposing corpses, especially in enclosed spaces.",
        symptoms = "Eye irritation, nausea, dizziness, weakness, coughing, and possible collapse at high exposure.",
        prevention = "Ventilate corpse-filled spaces and wear effective face protection.",
        treatment = "Fresh air immediately. Anti-nausea tablets help symptoms; respiratory support kit or corticosteroids can treat severe cases.",
    },
    cadaveric_aspergillosis = {
        category = "corpse",
        cause = "Fungal spores from decomposing corpses in damp, wet, or cold conditions.",
        symptoms = "Respiratory irritation, fever, coughing, wheezing, endurance loss, and weakness.",
        prevention = "Wear face protection near damp corpse-filled areas and avoid breathing contaminated air.",
        treatment = "Bronchodilator inhaler and antipyretics for symptoms; antifungal tablets or IV amphotericin to cure.",
    },
    tuberculosis = {
        category = "corpse",
        cause = "Long-term respiratory exposure in contaminated corpse-heavy environments.",
        symptoms = "Persistent cough, fever, fatigue, weight loss, night sweats, and coughing blood in severe cases.",
        prevention = "Avoid prolonged corpse exposure and wear respiratory protection.",
        treatment = "TB antibiotics or rifampicin combo pack. Cough suppressants and antipyretics only reduce symptoms.",
    },
    wound_infection = {
        category = "wound",
        cause = "Dirty wounds, poor bandaging, or untreated injury contamination.",
        symptoms = "Pain, swelling, redness, pus, fever, and worsening wound condition.",
        prevention = "Clean wounds, use sterile bandages, and change dirty bandages quickly.",
        treatment = "Disinfect wounds, use antibiotic ointment, and escalate to antibiotics if infection spreads.",
    },
    cellulitis = {
        category = "wound",
        name = "Cellulitis",
        cause = "A spreading bacterial skin infection after a poorly closed wound. Rough suturing has a high risk of starting cellulitis.",
        symptoms = "Hot red skin, swelling, local pain, fever, fatigue, weakness, and reduced endurance. Untreated stage 4 can progress into sepsis.",
        prevention = "Clean wounds before suturing, use sterile supplies, and avoid rough stitching when possible.",
        treatment = "Antibiotic ointment can treat mild cases. Prescription antibiotics, broad-spectrum antibiotics, plant-based antibiotics, IV antibiotics, or IV vancomycin treat more serious cases. Anti-inflammatory and antipyretic tablets reduce symptoms only.",
    },
    sepsis = {
        category = "wound",
        cause = "Untreated severe infection entering the bloodstream.",
        symptoms = "High fever, extreme weakness, confusion, rapid decline, and life-threatening systemic illness.",
        prevention = "Treat wound infections and cellulitis before they spread.",
        treatment = "IV antibiotics and aggressive medical support. This is an emergency condition.",
    },
    tetanus = {
        category = "wound",
        cause = "Deep contaminated puncture wounds, rusty metal injuries, or severe dirty wounds.",
        symptoms = "Jaw stiffness, muscle spasms, pain, fever, and dangerous neuromuscular failure.",
        prevention = "Clean deep wounds quickly and use tetanus prophylaxis when possible.",
        treatment = "Muscle relaxants for symptoms; tetanus antitoxin or tetanus immunoglobulin with a syringe to cure.",
    },
    hyperkeratotic_scabies = {
        category = "infection",
        cause = "Prolonged exposure to contaminated dirt or grass. The first bite leaves a scratch-like wound.",
        symptoms = "Severe itching, repeated scratch wounds, bite-site pain, fever, and dangerous health decline in late stages.",
        prevention = "Avoid lingering on bare dirt or grass when possible, cover exposed skin, and keep wounds clean.",
        treatment = "Topical permethrin is the main treatment. Antiparasitic pills can also cure it, but the course is longer.",
    },
    concussion = {
        category = "wound",
        cause = "A hard head impact from a height fall or serious vehicle crash.",
        symptoms = "Headache, dizziness, blurred vision, nausea, and disorientation that gradually improves over time.",
        prevention = "Avoid high falls and severe crashes. Treat head impacts as dangerous even if you can still walk.",
        treatment = "No direct cure. Rest and time are the main treatment; symptom medicine can make recovery easier.",
    },
    delirium = {
        category = "mental",
        cause = "Extreme stress held at its breaking point for many hours.",
        symptoms = "Hallucinated sounds, irrational speech, visual distortion, and unsafe impulsive behavior.",
        prevention = "Reduce stress before it reaches a prolonged maximum state.",
        treatment = "Antipsychotics. Requires an 8-dose course over 4 days.",
    },
    insomnia = {
        category = "mental",
        incubation = "Triggered after 12 hours at very high fatigue, or rarely after stimulant crashes.",
        duration = "Stage 3 is persistent until treated.",
        cause = "Prolonged extreme fatigue, caffeine crash, combat stimulant crash, or nitric oxide booster crash.",
        symptoms = "Poor rest, inability to sleep naturally in later stages, stress, fatigue, and headache.",
        prevention = "Sleep before exhaustion becomes prolonged and avoid stacking strong stimulants.",
        treatment = "Sleeping pills allow sleep while active. Dual orexin receptor medication cures over 96 hours; antidepressants cure over 168 hours.",
    },
    painkiller_addiction = {
        category = "mental",
        incubation = "Develops after sustained or excessive painkiller use.",
        duration = "Persistent. Stage 3 does not recover naturally.",
        cause = "Repeated use of regular or homemade painkillers, especially five or more doses within 24 hours or doses taken too close together.",
        symptoms = "Craving, persistent stress and depression, and increased thirst. An active painkiller or buprenorphine dose temporarily suppresses withdrawal symptoms.",
        prevention = "Avoid frequent redosing and keep daily painkiller use below the high-risk range.",
        treatment = "Buprenorphine cures the condition over 120 hours: 10 doses, one every 12 hours. Each active dose suppresses withdrawal symptoms.",
    },
    ahtr = {
        category = "blood",
        name = "Acute Hemolytic Transfusion Reaction",
        incubation = "1-6 hours after incompatible blood transfusion.",
        duration = "2-4 days without treatment; can become fatal quickly.",
        cause = "Receiving blood that is incompatible with your body.",
        symptoms = "Lower back pain, severe weakness, nausea, high fever, hemolysis, endurance loss, and dangerous health decline.",
        prevention = "Use compatible blood and test compatibility whenever possible.",
        treatment = "IV fluids and furosemide are the main treatments. Antipyretics, anti-nausea tablets, and anti-inflammatory pills reduce symptoms.",
    },
    knox_infection = {
        category = "infection",
        name = "Knox Infection",
        incubation = "Unknown.",
        duration = "Progressive and fatal.",
        cause = "Transmission after infected wounds.",
        symptoms = "Fever, nausea, weakness, pale skin, and terminal systemic infection.",
        prevention = "Avoid bites and infected wounds.",
        treatment = "No known cure.",
    },
}

local function safeText(key, fallback)
    local text = nil
    if getText then
        text = getText(key)
    end
    if not text or text == key then
        return fallback
    end
    return text
end

local function normalizeDiseaseId(id)
    if EHR.DiseaseFlyers and EHR.DiseaseFlyers.NormalizeDiseaseId then
        return EHR.DiseaseFlyers.NormalizeDiseaseId(id)
    end
    return id
end

local function getDiseaseDefinition(id)
    local normalized = normalizeDiseaseId(id)
    local diseases = EHR.Disease and EHR.Disease.Diseases or nil
    return diseases and (diseases[normalized] or diseases[id]) or nil
end

local function hoursToText(hours)
    hours = tonumber(hours)
    if not hours then return nil end
    if hours >= 24 then
        local days = hours / 24
        if math.floor(days) == days then
            return tostring(days) .. "d"
        end
        return string.format("%.1fd", days)
    end
    return tostring(hours) .. "h"
end

local function rangeHoursToText(minHours, maxHours)
    local minText = hoursToText(minHours)
    local maxText = hoursToText(maxHours)
    if not minText and not maxText then return L("UI_EHR_Codex_Unknown", "Unknown") end
    if minText == maxText then return minText end
    return tostring(minText or "?") .. " - " .. tostring(maxText or "?")
end

local function measureText(font, text)
    if getTextManager then
        local ok, width = pcall(function()
            return getTextManager():MeasureStringX(font, tostring(text or ""))
        end)
        if ok and width then return width end
    end
    return string.len(tostring(text or "")) * 8
end

local function trimLastCharacter(text)
    -- HARMONIE: Kahlua-safe (Java strings: a Thai letter is one char there,
    -- three bytes in plain Lua); always shortens, so loops always end
    local len = #text
    if len <= 1 then return "" end
    local cut = len
    while cut > 1 do
        local byte = string.byte(text, cut)
        if not byte or byte < 128 or byte >= 192 then break end
        cut = cut - 1
    end
    return text:sub(1, cut - 1)
end

local function truncateText(text, maxWidth, font)
    text = tostring(text or "")
    if measureText(font, text) <= maxWidth then return text end
    local suffix = "..."
    local suffixW = measureText(font, suffix)
    while #text > 0 and measureText(font, text) + suffixW > maxWidth do
        text = trimLastCharacter(text)
    end
    return text .. suffix
end

local function categoryName(category)
    local key = "UI_EHR_Codex_Category_" .. tostring(category or "unknown")
    return L(key, CategoryNames[category] or tostring(category or L("UI_EHR_Codex_Unknown", "Unknown")))
end

-- HARMONIE: embedded = true -> a child view of the medical window's
-- "handbook" tab (HM_PanelTabs.lua): no close button, not draggable
function EHR_MedicalJournalUI:new(x, y, width, height, player, embedded)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.embedded = embedded == true
    o.backgroundColor = Colors.bg
    o.borderColor = Colors.border
    o.moveWithMouse = not o.embedded
    o.textureCache = {}
    return o
end

function EHR_MedicalJournalUI:initialise()
    ISPanel.initialise(self)
end

function EHR_MedicalJournalUI:createChildren()
    ISPanel.createChildren(self)

    if not self.embedded then
    self.closeBtn = ISButton:new(self.width - 34, 9, 24, 24, "X", self, EHR_MedicalJournalUI.onClose)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self.closeBtn.borderColor = Colors.border
    self.closeBtn.backgroundColor = { r = 0.02, g = 0.09, b = 0.12, a = 0.9 }
    self.closeBtn.backgroundColorMouseOver = { r = 0.06, g = 0.28, b = 0.38, a = 0.95 }
    self.closeBtn:setAnchorRight(true)
    self:addChild(self.closeBtn)
    end

    -- HARMONIE: search box + filter chips above the list
    local searchY = HEADER_HEIGHT + PADDING + 38
    self.searchBox = ISTextEntryBox:new("", PADDING + 8, searchY, LIST_WIDTH - 16, SEARCH_H)
    self.searchBox.font = UIFont.Small
    self.searchBox:initialise()
    self.searchBox:instantiate()
    if self.searchBox.setPlaceholderText then
        self.searchBox:setPlaceholderText(L("UI_HomeMedic_Hb_Search", "Search name, sign, medicine..."))
    end
    local ui = self
    self.searchBox.onTextChange = function(box) ui:refreshEntries() end
    self:addChild(self.searchBox)

    local listY = self:getListTop()
    self.diseaseList = ISScrollingListBox:new(PADDING, listY, LIST_WIDTH, self.height - listY - PADDING - 4)
    self.diseaseList:initialise()
    self.diseaseList:instantiate()
    self.diseaseList.itemheight = 76
    self.diseaseList.font = UIFont.Small
    self.diseaseList.doDrawItem = self.drawListItem or EHR_MedicalJournalUI.drawDiseaseItem
    self.diseaseList.drawBorder = false
    self.diseaseList.parentUI = self
    self.diseaseList:setAnchorBottom(true)
    self:addChild(self.diseaseList)

    self:refreshEntries()
end

function EHR_MedicalJournalUI:getTexture(path)
    if not path then return nil end
    if self.textureCache[path] ~= nil then
        return self.textureCache[path] or nil
    end
    local texture = nil
    if getTexture then
        local ok, result = pcall(getTexture, path)
        if ok then texture = result end
    end
    self.textureCache[path] = texture or false
    return texture
end

function EHR_MedicalJournalUI:getDiseaseIcon(diseaseId, known)
    local id = normalizeDiseaseId(diseaseId)
    local path = known and DiseaseIcons[id] or DiseaseIcons.unknown
    return self:getTexture(path or DiseaseIcons.unknown)
end

function EHR_MedicalJournalUI:getFirstAidLevel()
    if self.player and Perks and Perks.Doctor and self.player.getPerkLevel then
        local ok, level = pcall(function() return self.player:getPerkLevel(Perks.Doctor) end)
        if ok then return tonumber(level) or 0 end
    end
    return 0
end

function EHR_MedicalJournalUI:knowsDisease(diseaseId)
    local id = normalizeDiseaseId(diseaseId)
    if EHR.DiseaseFlyers and EHR.DiseaseFlyers.IsKnoxDiseaseId and EHR.DiseaseFlyers.IsKnoxDiseaseId(id) then
        return EHR.DiseaseFlyers.KnowsDisease
            and EHR.DiseaseFlyers.KnowsDisease(self.player, id) == true
    end

    local level = self:getFirstAidLevel()
    if level >= 8 then return true end
    if EHR.DiseaseFlyers and EHR.DiseaseFlyers.CanIdentifyDisease then
        return EHR.DiseaseFlyers.CanIdentifyDisease(self.player, id) == true
    end
    return false
end

function EHR_MedicalJournalUI:getCatalogEntry(diseaseId)
    local id = normalizeDiseaseId(diseaseId)
    local def = getDiseaseDefinition(id)
    local info = CodexInfo[id] or {}
    local category = info.category or (def and def.category) or "infection"
    local known = self:knowsDisease(id)
    local realName = info.name or (def and def.name) or (EHR.DiseaseFlyers and EHR.DiseaseFlyers.GetDiseaseFriendlyName and EHR.DiseaseFlyers.GetDiseaseFriendlyName(id)) or id
    local displayName = known and realName or L("UI_EHR_Codex_UnknownCategory_" .. tostring(category or "unknown"), CategoryUnknownNames[category] or L("UI_EHR_DiseaseUnknown", "Unknown Illness"))

    return {
        id = id,
        definition = def,
        info = info,
        category = category,
        known = known,
        realName = codexText(id, "Name", realName),
        displayName = known and codexText(id, "Name", displayName) or displayName,
        incubation = codexText(id, "Incubation", info.incubation or rangeHoursToText(def and def.incubationMin, def and def.incubationMax)),
        duration = codexText(id, "Duration", info.duration or rangeHoursToText(def and def.durationMin, def and def.durationMax)),
        canKill = (def and def.canKill == true) or info.canKill == true,
    }
end

function EHR_MedicalJournalUI:getCatalogEntries()
    local entries = {}
    for _, diseaseId in ipairs(CatalogOrder) do
        table.insert(entries, self:getCatalogEntry(diseaseId))
    end
    -- HARMONIE: alphabetical by the name shown (HM_SortKey: Thai-aware)
    if HM_SortKey then
        for _, e in ipairs(entries) do e.sortKey = HM_SortKey(e.displayName) end
        table.sort(entries, function(a, b)
            if a.sortKey ~= b.sortKey then return a.sortKey < b.sortKey end
            return tostring(a.id) < tostring(b.id)
        end)
    end
    return entries
end

-- HARMONIE: filter chips + search. A subclass (the medication handbook)
-- gives its own getFilters / entryMatches / searchText.
function EHR_MedicalJournalUI:getFilters()
    return {
        { id = "all", label = L("UI_HomeMedic_Hb_Filter_all", "All") },
        { id = "known", label = L("UI_HomeMedic_Hb_Filter_known", "Known") },
        { id = "locked", label = L("UI_HomeMedic_Hb_Filter_locked", "Locked") },
        { id = "lethal", label = L("UI_HomeMedic_Hb_Filter_lethal", "Lethal") },
        { id = "surgery", label = L("UI_HomeMedic_Hb_Filter_surgery", "Surgery") },
    }
end

function EHR_MedicalJournalUI:entryMatches(entry, filter)
    if filter == "known" then return entry.known end
    if filter == "locked" then return not entry.known end
    if filter == "lethal" then return entry.canKill end
    if filter == "surgery" then
        local S = HM_Surgery
        local hbId = HM_Diagnosis and HM_Diagnosis.normalize(entry.id) or entry.id
        return S and S.surgeriesFor and #S.surgeriesFor(hbId) > 0 or false
    end
    return true
end

-- what the search box looks in: name, category, and (when known) the signs
function EHR_MedicalJournalUI:searchText(entry)
    local parts = { entry.displayName or "", categoryName(entry.category) }
    if entry.known then
        parts[#parts + 1] = entry.realName or ""
        local D = HM_Diagnosis
        local hbId = D and D.normalize(entry.id) or entry.id
        for _, t in ipairs(D and D.DISEASES[hbId] or {}) do
            parts[#parts + 1] = L("UI_HomeMedic_Diag_Tag_" .. t, t)
        end
        if HM_Handbook and HM_Handbook.medNames then
            for _, n in ipairs(HM_Handbook.medNames(hbId)) do parts[#parts + 1] = n end
        end
    end
    return string.lower(table.concat(parts, " "))
end

function EHR_MedicalJournalUI:getListTop()
    local chipH = getTextManager():getFontHeight(UIFont.Small) + 6
    return HEADER_HEIGHT + PADDING + 38 + SEARCH_H + 6 + chipH + 6
end

function EHR_MedicalJournalUI:refreshEntries()
    if not self.diseaseList then return end
    local keepId = self:getSelectedEntry() and self:getSelectedEntry().id
    self.diseaseList:clear()
    self.allEntries = self:getCatalogEntries()
    local query = self.searchBox and string.lower(tostring(self.searchBox:getText() or "")) or ""
    query = query:gsub("^%s+", ""):gsub("%s+$", "")
    local filter = self.hmFilter or "all"
    self.catalogEntries = {}
    local knownCount = 0
    for _, entry in ipairs(self.allEntries) do
        if entry.known then knownCount = knownCount + 1 end
        if self:entryMatches(entry, filter) and (query == "" or string.find(self:searchText(entry), query, 1, true)) then
            self.catalogEntries[#self.catalogEntries + 1] = entry
            self.diseaseList:addItem(entry.displayName, entry)
        end
    end
    self.knownCount = knownCount
    self.diseaseList.selected = 1
    for i, entry in ipairs(self.catalogEntries) do
        if entry.id == keepId then self.diseaseList.selected = i end
    end
end

-- select an entry by id (clears search and filter so it is listed)
function EHR_MedicalJournalUI:selectEntryId(id)
    if not id then return end
    if self.searchBox then self.searchBox:setText("") end
    self.hmFilter = "all"
    self:refreshEntries()
    local D = HM_Diagnosis
    for i, entry in ipairs(self.catalogEntries or {}) do
        if entry.id == id or (D and D.normalize(entry.id) == D.normalize(id)) then
            self.diseaseList.selected = i
            if self.diseaseList.ensureVisible then pcall(function() self.diseaseList:ensureVisible(i) end) end
            return true
        end
    end
    return false
end

function EHR_MedicalJournalUI:drawFilterChips()
    local c = Colors
    local font = UIFont.Small
    local chipH = getTextManager():getFontHeight(font) + 6
    local x = PADDING + 8
    local y = HEADER_HEIGHT + PADDING + 38 + SEARCH_H + 6
    local maxX = PADDING + LIST_WIDTH - 8
    local mx, my = self:getMouseX(), self:getMouseY()
    self.filterChips = {}
    for _, f in ipairs(self:getFilters()) do
        local w = measureText(font, f.label) + 14
        if x + w > maxX then break end
        local on = (self.hmFilter or "all") == f.id
        local hov = mx >= x and mx <= x + w and my >= y and my <= y + chipH
        local bg = on and c.redDark or c.panelSoft
        local bd = on and c.accent or c.borderDim
        self:drawRect(x, y, w, chipH, on and 0.95 or (hov and 0.75 or 0.5), bg.r, bg.g, bg.b)
        self:drawRectBorder(x, y, w, chipH, 1, bd.r, bd.g, bd.b)
        local tc = (on or hov) and c.text or c.textDim
        self:drawText(f.label, x + 7, y + 3, tc.r, tc.g, tc.b, 1, font)
        self.filterChips[#self.filterChips + 1] = { x = x, y = y, w = w, h = chipH, id = f.id }
        x = x + w + 5
    end
    -- results count at the right of the search row
    local count = tostring(#(self.catalogEntries or {})) .. "/" .. tostring(#(self.allEntries or {}))
    self:drawText(count, maxX - measureText(font, count), y - SEARCH_H - 6 - getTextManager():getFontHeight(font) - 2, c.textDim.r, c.textDim.g, c.textDim.b, 0.8, font)
end

function EHR_MedicalJournalUI:onMouseDown(x, y)
    for _, chip in ipairs(self.filterChips or {}) do
        if x >= chip.x and x <= chip.x + chip.w and y >= chip.y and y <= chip.y + chip.h then
            self.hmFilter = chip.id
            self:refreshEntries()
            if getSoundManager then pcall(function() getSoundManager():playUISound("UISelectListItem") end) end
            return true
        end
    end
    return ISPanel.onMouseDown(self, x, y)
end

function EHR_MedicalJournalUI:getSelectedEntry()
    if not self.diseaseList or not self.diseaseList.items then return nil end
    local selected = self.diseaseList.selected or 1
    local item = self.diseaseList.items[selected]
    return item and item.item or nil
end

function EHR_MedicalJournalUI:drawPanelFrame(x, y, w, h, title)
    local c = Colors
    self:drawRect(x, y, w, h, c.panel.a, c.panel.r, c.panel.g, c.panel.b)
    self:drawRectBorder(x, y, w, h, c.borderDim.a, c.borderDim.r, c.borderDim.g, c.borderDim.b)
    if title then
        self:drawRect(x + 1, y + 1, w - 2, 30, c.header.a, c.header.r, c.header.g, c.header.b)
        self:drawText(title, x + 10, y + math.max(2, math.floor((30 - getTextManager():getFontHeight(UIFont.Medium)) / 2)), c.accent.r, c.accent.g, c.accent.b, c.accent.a, UIFont.Medium)
        self:drawRect(x + 10, y + 29, w - 20, 1, 0.75, c.border.r, c.border.g, c.border.b)
    end
end

function EHR_MedicalJournalUI:drawWrappedText(text, x, y, w, color, font, lineHeight)
    text = tostring(text or "")
    color = color or Colors.text
    font = font or UIFont.Small
    -- HARMONIE: never tighter than the font (Thai glyphs are taller)
    local fontH = getTextManager():getFontHeight(font) + 2
    lineHeight = math.max(lineHeight or 19, fontH)

    -- HARMONIE: HM_Surgery.wrap also breaks space-less (Thai) text at character boundaries
    for _, line in ipairs(HM_Surgery.wrap(text, w, font)) do
        self:drawText(line, x, y, color.r, color.g, color.b, color.a or 1, font)
        y = y + lineHeight
    end
    return y
end

function EHR_MedicalJournalUI:drawInfoSection(label, value, x, y, w)
    local c = Colors
    self:drawText(label, x, y, c.accent.r, c.accent.g, c.accent.b, c.accent.a, UIFont.Medium)
    y = y + math.max(24, getTextManager():getFontHeight(UIFont.Medium) + 4)
    return self:drawWrappedText(value, x + 8, y, w - 16, c.text, UIFont.Small, 19) + 10
end

-- HARMONIE: texts a subclass replaces
function EHR_MedicalJournalUI:titleText() return L("UI_EHR_DiseaseHandbook_Title", "HOW TO SURVIVE DISEASE HANDBOOK") end
function EHR_MedicalJournalUI:indexTitle() return L("UI_EHR_DiseaseHandbook_Index", "DISEASE INDEX") end
function EHR_MedicalJournalUI:progressText()
    return LF("UI_EHR_DiseaseHandbook_KnownCount", "%1/%2 known", tonumber(self.knownCount) or 0, #CatalogOrder)
end

function EHR_MedicalJournalUI:prerender()
    ISPanel.prerender(self)
    local c = Colors
    self:drawRect(0, 0, self.width, self.height, c.bg.a, c.bg.r, c.bg.g, c.bg.b)
    self:drawRectBorder(0, 0, self.width, self.height, c.border.a, c.border.r, c.border.g, c.border.b)
    self:drawRect(0, 0, self.width, HEADER_HEIGHT, 0.82, 0.02, 0.02, 0.02)
    self:drawText(self:titleText(), 16, 8, c.text.r, c.text.g, c.text.b, c.text.a, UIFont.Large)

    local progress = self:progressText()
    local progressW = measureText(UIFont.Medium, progress)
    self:drawText(progress, self.width - progressW - (self.embedded and 16 or 50), 11, c.green.r, c.green.g, c.green.b, c.green.a, UIFont.Medium)

    self:drawPanelFrame(PADDING, HEADER_HEIGHT + PADDING, LIST_WIDTH, self.height - HEADER_HEIGHT - PADDING * 2, self:indexTitle())
    self:drawFilterChips()

    local detailX = PADDING + LIST_WIDTH + 12
    local detailY = HEADER_HEIGHT + PADDING
    local detailW = self.width - detailX - PADDING
    local detailH = self.height - detailY - PADDING
    self:drawPanelFrame(detailX, detailY, detailW, detailH, L("UI_EHR_DiseaseHandbook_Details", "ENTRY DETAILS"))
end

function EHR_MedicalJournalUI:render()
    ISPanel.render(self)

    local detailX = PADDING + LIST_WIDTH + 12
    local detailY = HEADER_HEIGHT + PADDING
    local detailW = self.width - detailX - PADDING
    local detailH = self.height - detailY - PADDING

    local entry = self:getSelectedEntry()
    if entry then
        -- HARMONIE: the details scroll (mouse wheel) and are clipped to their frame
        if self.detailEntryId ~= entry.id then self.detailEntryId = entry.id; self.detailScroll = 0 end
        local top = detailY + 34
        local viewH = detailH - 40
        self.detailBounds = { x = detailX, y = top, w = detailW, h = viewH }
        self:setStencilRect(detailX + 2, top, detailW - 4, viewH)
        local startY = detailY + 46 - (self.detailScroll or 0)
        local endY = self:drawDiseaseDetails(entry, detailX + 18, startY, detailW - 36, detailH - 58) or startY
        self:clearStencilRect()
        local contentH = endY - startY + 12
        self.detailMaxScroll = math.max(0, contentH - (viewH - 12))
        if (self.detailScroll or 0) > self.detailMaxScroll then self.detailScroll = self.detailMaxScroll end
        -- HARMONIE (2026-10-11): the shared scroll bar -- drag it or the wheel
        if HARMONIE_Scroll then
            HARMONIE_Scroll.bar(self, "detail", detailX + detailW - 8, top, 5, viewH, self.detailScroll or 0, self.detailMaxScroll,
                function(v) self.detailScroll = v end, { Colors.accent.r, Colors.accent.g, Colors.accent.b })
        elseif self.detailMaxScroll > 0 then
            local barH = math.max(24, viewH * viewH / (contentH + viewH))
            local barY = top + (viewH - barH) * ((self.detailScroll or 0) / self.detailMaxScroll)
            self:drawRect(detailX + detailW - 7, barY, 3, barH, 0.8, Colors.accent.r, Colors.accent.g, Colors.accent.b)
        end
    end
end

function EHR_MedicalJournalUI:onMouseWheel(del)
    local b = self.detailBounds
    if not b or (self.detailMaxScroll or 0) <= 0 then return false end
    local mx, my = self:getMouseX(), self:getMouseY()
    if mx < b.x or mx > b.x + b.w or my < b.y or my > b.y + b.h then return false end
    self.detailScroll = math.max(0, math.min(self.detailMaxScroll, (self.detailScroll or 0) + del * 40))
    return true
end

function EHR_MedicalJournalUI:drawDiseaseDetails(entry, x, y, w, h)
    local c = Colors
    local iconSize = 86
    local icon = self:getDiseaseIcon(entry.id, entry.known)
    if icon and self.drawTextureScaled then
        self:drawTextureScaled(icon, x, y, iconSize, iconSize, 1, 1, 1, 1)
    else
        self:drawRectBorder(x, y, iconSize, iconSize, c.border.a, c.border.r, c.border.g, c.border.b)
        self:drawText("?", x + 32, y + 22, c.cyan.r, c.cyan.g, c.cyan.b, 1, UIFont.Large)
    end

    local titleX = x + iconSize + 18
    -- HARMONIE: measured rows + truncation, so long (Thai) names never overflow
    local tm = getTextManager()
    local titleW = x + w - titleX
    local ty = y + 4
    self:drawText(truncateText(entry.displayName, titleW, UIFont.Large), titleX, ty, c.text.r, c.text.g, c.text.b, c.text.a, UIFont.Large)
    ty = ty + tm:getFontHeight(UIFont.Large) + 2
    self:drawText(truncateText(categoryName(entry.category), titleW, UIFont.Medium), titleX, ty, c.textDim.r, c.textDim.g, c.textDim.b, c.textDim.a, UIFont.Medium)
    ty = ty + tm:getFontHeight(UIFont.Medium) + 2
    local badge = entry.known and L("UI_EHR_Codex_KnownUpper", "KNOWN") or L("UI_EHR_Codex_LockedUpper", "LOCKED")
    local badgeColor = entry.known and c.green or c.yellow
    self:drawText(badge, titleX, ty, badgeColor.r, badgeColor.g, badgeColor.b, badgeColor.a, UIFont.Medium)

    if entry.canKill then
        local lethal = L("UI_EHR_Codex_LethalRisk", "LETHAL RISK")
        local lethalW = measureText(UIFont.Medium, lethal)
        self:drawText(lethal, x + w - lethalW, ty, c.red.r, c.red.g, c.red.b, c.red.a, UIFont.Medium)
    end
    ty = ty + tm:getFontHeight(UIFont.Medium)

    y = math.max(y + iconSize, ty) + 18
    self:drawRect(x, y, w, 1, 0.76, c.border.r, c.border.g, c.border.b)
    y = y + 16

    if not entry.known then
        self:drawText(L("UI_EHR_Codex_KnowledgeUnavailable", "Knowledge unavailable"), x, y, c.red.r, c.red.g, c.red.b, c.red.a, UIFont.Medium)
        y = y + 28
        return self:drawWrappedText(
            L("UI_EHR_Codex_LockedDesc", "Read the matching disease flyer or reach First Aid level 8 to unlock symptoms, causes, prevention, and treatment notes."),
            x + 8, y, w - 16, c.textDim, UIFont.Small, 19
        )
    end

    local info = entry.info or {}
    y = self:drawInfoSection(L("UI_EHR_Codex_Cause", "Cause"), codexText(entry.id, "Cause", info.cause or L("UI_EHR_Codex_UnknownSentence", "Unknown.")), x, y, w)
    -- HARMONIE: symptoms / how to check / treatment from the game's own data (HM_Handbook)
    local HB = HM_Handbook
    local hbId = HM_Diagnosis and HM_Diagnosis.normalize(entry.id) or entry.id
    local realSymptoms = HB and HB.symptoms(hbId)
    y = self:drawInfoSection(L("UI_EHR_Codex_Symptoms", "Symptoms"), realSymptoms or codexText(entry.id, "Symptoms", info.symptoms or L("UI_EHR_Codex_NoSymptoms", "No symptom notes available.")), x, y, w)
    local check = HB and HB.howToCheck(hbId)
    if check then y = self:drawInfoSection(L("UI_HomeMedic_Hb_HowToCheck", "How to check"), check, x, y, w) end
    y = self:drawInfoSection(L("UI_EHR_Codex_Timing", "Timing"), LF("UI_EHR_Codex_TimingText", "Incubation: %1. Duration: %2.", tostring(entry.incubation or L("UI_EHR_Codex_Unknown", "Unknown")), tostring(entry.duration or L("UI_EHR_Codex_Unknown", "Unknown"))), x, y, w)
    y = self:drawInfoSection(L("UI_EHR_Codex_Prevention", "Prevention"), codexText(entry.id, "Prevention", info.prevention or L("UI_EHR_Codex_NoPrevention", "No prevention notes available.")), x, y, w)
    local realTreatment = HB and HB.treatment(hbId)
    y = self:drawInfoSection(L("UI_EHR_Codex_Treatment", "Treatment"), realTreatment or codexText(entry.id, "Treatment", info.treatment or L("UI_EHR_Codex_NoTreatment", "No treatment notes available.")), x, y, w)
    -- HARMONIE: surgery notes (HM_Surgery.handbookText)
    local surgery = HM_Surgery and HM_Surgery.handbookText and HM_Surgery.handbookText(entry.id)
    if surgery then
        y = self:drawInfoSection(L("UI_EHR_Codex_Surgery", "Surgery"), surgery, x, y, w)
    end
    return y
end

function EHR_MedicalJournalUI.drawDiseaseItem(self, y, item, alt)
    local parent = self.parentUI
    local entry = item and item.item or nil
    if not parent or not entry then return y + self.itemheight end

    local c = Colors
    local selected = (self.selected == item.index) or (self.items and self.items[self.selected] == item)
    local rowAlpha = selected and 0.82 or (alt and 0.38 or 0.24)
    local rowR = selected and c.redDark.r or c.panel.r
    local rowG = selected and c.redDark.g or c.panel.g
    local rowB = selected and c.redDark.b or c.panel.b
    self:drawRect(4, y + 4, self:getWidth() - 12, self.itemheight - 8, rowAlpha, rowR, rowG, rowB)
    self:drawRectBorder(4, y + 4, self:getWidth() - 12, self.itemheight - 8, selected and c.border.a or c.borderDim.a, c.border.r, c.border.g, c.border.b)

    local icon = parent:getDiseaseIcon(entry.id, entry.known)
    if icon and self.drawTextureScaled then
        self:drawTextureScaled(icon, 14, y + 12, 52, 52, entry.known and 1 or 0.72, 1, 1, 1)
    else
        self:drawText("?", 32, y + 22, c.cyan.r, c.cyan.g, c.cyan.b, 1, UIFont.Medium)
    end

    local nameColor = entry.known and c.text or c.textDim
    local name = truncateText(entry.displayName, self:getWidth() - 90, UIFont.Medium)
    self:drawText(name, 76, y + 14, nameColor.r, nameColor.g, nameColor.b, nameColor.a, UIFont.Medium)

    local category = truncateText(categoryName(entry.category), self:getWidth() - 118, UIFont.Small)
    self:drawText(category, 76, y + 42, c.textDim.r, c.textDim.g, c.textDim.b, c.textDim.a, UIFont.Small)

    local status = entry.known and L("UI_EHR_Codex_Known", "Known") or L("UI_EHR_Codex_Locked", "Locked")
    local statusColor = entry.known and c.green or c.yellow
    local statusW = measureText(UIFont.Small, status)
    self:drawText(status, self:getWidth() - statusW - 18, y + 42, statusColor.r, statusColor.g, statusColor.b, statusColor.a, UIFont.Small)

    return y + self.itemheight
end

function EHR_MedicalJournalUI:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    EHR_MedicalJournalUI.instance = nil
end

function EHR_MedicalJournalUI.Toggle(player)
    player = player or getSpecificPlayer(0)
    if not player then return end

    if EHR_MedicalJournalUI.instance and EHR_MedicalJournalUI.instance:isVisible() then
        EHR_MedicalJournalUI.instance:onClose()
        return
    end

    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local x = math.floor((screenW - WINDOW_WIDTH) / 2)
    local y = math.floor((screenH - WINDOW_HEIGHT) / 2)

    EHR_MedicalJournalUI.instance = EHR_MedicalJournalUI:new(x, y, WINDOW_WIDTH, WINDOW_HEIGHT, player)
    EHR_MedicalJournalUI.instance:initialise()
    EHR_MedicalJournalUI.instance:instantiate()
    EHR_MedicalJournalUI.instance:addToUIManager()
    EHR_MedicalJournalUI.instance:setVisible(true)
    EHR_MedicalJournalUI.instance:bringToTop()
end

function EHR_MedicalJournalUI.IsOpen()
    return EHR_MedicalJournalUI.instance ~= nil and EHR_MedicalJournalUI.instance:isVisible()
end

EHR = EHR or {}
EHR.UI = EHR.UI or {}
EHR.UI.ToggleJournal = EHR_MedicalJournalUI.Toggle

if EHR and EHR.Log then
    EHR.Log("DiseaseHandbookUI module loaded")
end

-- HARMONIE (2026-10-11): drag the scroll bars (HARMONIE_UIKit)
pcall(require, "HARMONIE_UIKit")
if HARMONIE_Scroll then HARMONIE_Scroll.install(EHR_MedicalJournalUI) end

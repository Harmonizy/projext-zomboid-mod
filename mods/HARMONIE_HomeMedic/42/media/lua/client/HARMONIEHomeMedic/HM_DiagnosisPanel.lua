--[[
    HARMONIE - Home Medic : "Diagnosis" tab of the medical window (client)

    Request 2026-09-30: "เพิ่มส่วนการวินิจฉัยใน ui ehr เพื่อดูว่าแต่ละโรคตอนนี้
    ทำอะไรกับสถานะร่างกายอยู่". One card per condition -- EHR diseases, sepsis,
    infected wounds, blood loss, Knox infection -- with its stage, status
    (treating / awaiting surgery / needs surgery / untreated) and what the
    current stage does to the body, read from the disease's own stage
    effects (EHR_DiseaseDefinitions / EHR_Sepsis / EHR_WoundInfection /
    Home Medic's blood impact). Hover a card for its treatment notes.

    Works for another player too (EHR's remote exam snapshot). The list
    scrolls with the wheel; hover tests use the scrolled coordinates, so
    the tooltip stays under the mouse.
]]--

require "ExtensiveHealth/EHR_HealthPanelUI"
require "HARMONIEHomeMedic/Surgery/HM_Surgery"
local S = HM_Surgery

local FONT, FONT_M = UIFont.Small, UIFont.Medium
local function fh(f) return getTextManager():getFontHeight(f or FONT) end
local function tw(t, f) return getTextManager():MeasureStringX(f or FONT, t or "") end
local function L(key, fallback, ...)
    local k = "UI_HomeMedic_Diag_" .. key
    local t = getText and getText(k)
    if not t or t == k or t == "?" then t = fallback or key end
    local args = { ... }
    for i = 1, #args do t = t:gsub("%%" .. i, (tostring(args[i]):gsub("%%", "%%%%"))) end
    return t
end
local function pct(v) return math.floor((tonumber(v) or 0) * 100 + 0.5) end
local function num(v) return string.format("%.1f", tonumber(v) or 0) end

local function wrap(text, width) return S.wrap(text, width, FONT) end

-- ------------------------------------------------------------- effects
-- stage-effect field -> readable line (nil = not shown)
local FIELD = {
    staminaPenalty = function(v) return v > 0 and L("Stamina", "Endurance -%1%", pct(v)) end,
    enduranceCap = function(v) return v > 0 and v < 1 and L("EnduranceCap", "Endurance capped at %1%", pct(v)) end,
    fatigueDrain = function(v) return v > 0 and L("Fatigue", "Tiring faster") end,
    fatigueCap = function(v) return v > 0 and L("FatigueCap", "Tiredness up to %1%", pct(v)) end,
    fatigueTarget = function(v) return v > 0 and L("FatigueCap", "Tiredness up to %1%", pct(v)) end,
    movementPenalty = function(v) return v > 0 and L("Movement", "Movement -%1%", pct(v)) end,
    canSprint = function(v) return v == false and L("NoSprint", "Cannot sprint") end,
    thirstDrain = function(v) return v > 0 and L("Thirst", "Thirst rises faster") end,
    hungerDrain = function(v) return v > 0 and L("Hunger", "Hunger rises faster") end,
    vomitChance = function(v) return v > 0 and L("Vomit", "Vomiting") end,
    coughingChance = function(v) return v > 0 and L("Cough", "Coughing (the noise draws zombies)") end,
    coughIntervalHours = function(v) return v > 0 and L("Cough", "Coughing (the noise draws zombies)") end,
    coughBlood = function(v) return v and L("CoughBlood", "Coughing up blood") end,
    sneezeIntervalHours = function(v) return v > 0 and L("Sneeze", "Sneezing (noise)") end,
    healthDrainPerHour = function(v) return v > 0 and L("HealthDrain", "Health -%1 per hour", num(v)) end,
    healthDamagePerHour = function(v) return v > 0 and L("HealthDrain", "Health -%1 per hour", num(v)) end,
    healthCap = function(v) return v > 0 and L("HealthCap", "Health capped at %1", math.floor(v <= 1 and v * 100 or v)) end,
    minHealth = function(v) return v < 100 and L("MinHealth", "Can bring health down to %1", math.floor(v)) end,
    confusionChance = function(v) return v > 0 and L("Confusion", "Confusion") end,
    dizzinessChance = function(v) return v > 0 and L("Dizziness", "Dizziness") end,
    painLevel = function(v) return v > 0 and L("Pain", "Pain %1", math.floor(v <= 1 and v * 100 or v)) end,
    painBonus = function(v) return v > 0 and L("PainPlus", "Pain +%1", math.floor(v)) end,
    chestPain = function(v) return v and v ~= 0 and L("ChestPain", "Chest pain") end,
    abdominalPain = function(v) return v and v ~= 0 and L("AbdominalPain", "Abdominal pain") end,
    bloodLoss = function(v) return v and v ~= 0 and L("BloodLoss", "Losing blood") end,
    collapseChance = function(v) return v > 0 and L("Collapse", "May collapse") end,
    jawStiffness = function(v) return v and v ~= 0 and L("Jaw", "Lockjaw: hard to eat") end,
    feverLevel = function(v) return v > 0 and L("Fever", "Fever") end,
    feverTemp = function(v) return v > 0 and L("FeverTemp", "Fever %1 C", num(v)) end,
    feverTarget = function(v) return v > 0 and L("FeverTemp", "Fever %1 C", num(v)) end,
    feverBonus = function(v) return v > 0 and L("FeverPlus", "Fever +%1%", pct(v)) end,
    coldStrength = function(v) return v > 0 and L("Cold", "Cold symptoms") end,
    breathingDifficulty = function(v) return v and v ~= 0 and L("Breath", "Short of breath") end,
    meleePenalty = function(v) return v > 0 and L("Melee", "Melee -%1%", pct(v)) end,
    spasmChance = function(v) return v > 0 and L("Spasm", "Muscle spasms") end,
    blackoutChance = function(v) return v > 0 and L("Blackout", "Blackouts") end,
    healingPenalty = function(v) return v > 0 and L("Healing", "Wound healing -%1%", pct(v)) end,
}
local ORDER = {
    "healthDrainPerHour", "healthDamagePerHour", "healthCap", "minHealth", "bloodLoss", "staminaPenalty", "enduranceCap",
    "movementPenalty", "canSprint", "meleePenalty", "fatigueDrain", "fatigueCap", "fatigueTarget", "feverLevel", "feverTemp",
    "feverTarget", "feverBonus", "painLevel", "painBonus", "chestPain", "abdominalPain", "healingPenalty", "breathingDifficulty",
    "coughingChance", "coughIntervalHours", "coughBlood", "sneezeIntervalHours", "vomitChance", "thirstDrain", "hungerDrain",
    "confusionChance", "dizzinessChance", "collapseChance", "blackoutChance", "spasmChance", "jawStiffness", "coldStrength",
}

local function effectLines(eff)
    local out, seen = {}, {}
    if type(eff) ~= "table" then return out end
    for _, k in ipairs(ORDER) do
        local v = eff[k]
        if v ~= nil and FIELD[k] then
            local ok, line = pcall(FIELD[k], type(v) == "number" and v or v)
            if ok and line and not seen[line] then seen[line] = true; out[#out + 1] = line end
        end
    end
    return out
end

-- ------------------------------------------------------------- data
local function source(panel)
    local exam = panel.isRemoteHealthPanel and panel.remoteExamData or nil
    local md = panel.player and panel.player.getModData and panel.player:getModData() or {}
    local function get(key)
        if exam then return exam[key] end
        return md[key]
    end
    return get, exam
end

local function codex(id, field)
    local k = "UI_HomeMedic_Codex_" .. tostring(id):gsub("[^%w_]", "_") .. "_" .. field
    local t = getText and getText(k)
    if t and t ~= k then return t end
    return nil
end

local function statusFor(panel, id, exam, treating)
    if S.isHeld(panel.player, id, exam) then return L("Held", "AWAITING SURGERY"), { 0.45, 0.70, 1.0 } end
    if treating then return L("Treating", "TREATING"), { 0.35, 0.85, 0.45 } end
    if S.needsSurgery(panel.player, id, exam) then return L("NeedsSurgery", "NEEDS SURGERY"), { 0.95, 0.45, 0.25 } end
    return L("Untreated", "UNTREATED"), { 0.95, 0.75, 0.25 }
end

local function surgeryHint(id)
    local list = S.surgeriesFor(id)
    if #list == 0 then return nil end
    local names = {}
    for _, sid in ipairs(list) do names[#names + 1] = S.T("Name_" .. sid, sid) end
    local from = S.SURGICAL[id]
    if from then return L("SurgeryFrom", "Surgery needed from stage %1: %2", from, table.concat(names, ", ")) end
    return L("SurgeryOption", "Surgery option: %1", table.concat(names, ", "))
end

-- -> list of cards { title, stage, status, statusColor, lines, tip }
function EHR_HealthPanelUI:collectDiagnosis()
    local get, exam = source(self)
    local cards = {}
    local med = get("EHR_Medication")
    local treatments = type(med) == "table" and med.activeTreatments or {}

    local function nameOf(id, entry)
        local info = self.getDiseaseDisplayInfo and self:getDiseaseDisplayInfo(id, entry)
        if type(info) == "table" and info.displayName then return info.displayName, info.canIdentify ~= false end
        return S.T("Cond_" .. id, id), true
    end

    -- EHR diseases
    local dis = get("EHR_Disease")
    local active = type(dis) == "table" and dis.active or {}
    local ids = {}
    for id in pairs(active) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local e = active[id]
        if type(e) == "table" then
            local stage = tonumber(e.stage) or 1
            local def = EHR and EHR.Disease and EHR.Disease.Diseases and EHR.Disease.Diseases[id]
            local title, known = nameOf(id, e)
            local lines = effectLines(def and def.effects and def.effects[stage])
            if #lines == 0 then
                local sym = known and codex(id, "Symptoms")
                if sym then lines = { sym } elseif def and def.symptoms then lines = { table.concat(def.symptoms, ", ") } end
            end
            local status, col = statusFor(self, id, exam, treatments[id] ~= nil)
            local hint = known and surgeryHint(id)
            if hint then lines[#lines + 1] = hint end
            cards[#cards + 1] = { title = title, stage = stage, status = status, statusColor = col, lines = lines,
                tip = known and (codex(id, "Treatment") or "") or L("UnknownTip", "Identify it first (disease flyer, First Aid 8).") }
        end
    end

    -- sepsis (own module)
    local sep = get("EHR_Sepsis")
    if type(sep) == "table" and (tonumber(sep.stage) or 0) > 0 then
        local st = tonumber(sep.stage)
        local eff = EHR and EHR.Sepsis and EHR.Sepsis.StageEffects and EHR.Sepsis.StageEffects[st]
        local lines = effectLines(eff)
        local hint = surgeryHint("sepsis")
        if hint then lines[#lines + 1] = hint end
        local status, col = statusFor(self, "sepsis", exam, treatments.sepsis ~= nil)
        cards[#cards + 1] = { title = S.T("Cond_sepsis", "Sepsis"), stage = st, status = status, statusColor = col,
            lines = lines, tip = codex("sepsis", "Treatment") or "" }
    end

    -- infected wounds (per body part)
    local wi = get("EHR_WoundInfection")
    local cfg = EHR and EHR.WoundInfection and EHR.WoundInfection.Config
    if type(wi) == "table" and type(wi.parts) == "table" then
        for part, pd in pairs(wi.parts) do
            local st = type(pd) == "table" and tonumber(pd.stage) or 0
            if st > 0 then
                local lines = effectLines(cfg and cfg.STAGE_EFFECTS and cfg.STAGE_EFFECTS[st])
                lines[#lines + 1] = surgeryHint("wound_infection")
                local where = part
                if BodyPartType and BodyPartType.FromString and BodyPartType.getDisplayName then
                    local okT, t = pcall(BodyPartType.FromString, part)
                    if okT and t then where = BodyPartType.getDisplayName(t) or part end
                end
                cards[#cards + 1] = { title = S.T("Cond_wound_infection", "Wound Infection") .. " · " .. tostring(where), stage = st,
                    status = treatments.wound_infection and L("Treating", "TREATING") or L("Untreated", "UNTREATED"),
                    statusColor = treatments.wound_infection and { 0.35, 0.85, 0.45 } or { 0.95, 0.75, 0.25 },
                    lines = lines, tip = codex("wound_infection", "Treatment") or "" }
            end
        end
    end

    -- blood loss
    local B = HARMONIE_HomeMedic_BloodImpact
    local blood = get("EHR_Blood")
    if type(blood) == "table" and tonumber(blood.currentVolume) and tonumber(blood.maxVolume) and blood.maxVolume > 0 then
        local f = blood.currentVolume / blood.maxVolume
        local t = EHR and EHR.Blood and EHR.Blood.GetThresholds and EHR.Blood.GetThresholds() or {}
        local healthy = tonumber(t.healthy) or 0.85
        if f < healthy then
            local lines = { L("BloodLevel", "Blood %1% (%2 mL)", pct(f), math.floor(blood.currentVolume)) }
            if B and B.enduranceCap then
                local ok, cap = pcall(B.enduranceCap, f)
                if ok and cap and cap < 1 then lines[#lines + 1] = L("EnduranceCap", "Endurance capped at %1%", pct(cap)) end
            end
            if f < (tonumber(t.moderate) or 0.70) then lines[#lines + 1] = L("Vision", "Vision darkens and throbs") end
            cards[#cards + 1] = { title = L("BloodLoss_Title", "Blood loss"), status = L("Untreated", "UNTREATED"),
                statusColor = { 0.95, 0.30, 0.28 }, lines = lines,
                tip = L("BloodTip", "Stop the bleeding, then transfuse or rest; blood slowly regenerates.") }
        end
    end

    -- Knox
    local K = EHR and EHR.KnoxCure
    if not exam and K and K.IsInfected then
        local ok, inf = pcall(K.IsInfected, self.player)
        if ok and inf then
            cards[#cards + 1] = { title = S.T("Cond_knox", "Knox infection"), status = L("Untreated", "UNTREATED"),
                statusColor = { 0.95, 0.30, 0.28 }, lines = { surgeryHint("knox") or "", surgeryHint("knox_bite") or "" },
                tip = codex("knox_infection", "Treatment") or "" }
        end
    end
    return cards
end

-- ------------------------------------------------------------- drawing
function EHR_HealthPanelUI:drawDiagnosisPanel()
    local c = EHR_HealthPanelUI.Colors
    local b = self:getTabContentBounds()
    self:drawPanelFrame(b.x, b.y, b.w, b.h, L("Title", "DIAGNOSIS"), nil)
    local top = b.y + 36
    local viewH = b.h - 44
    local x, w = b.x + 14, b.w - 28
    if self.diagCacheAt == nil or (getTimestampMs() - self.diagCacheAt) > 500 then
        self.diagCards = self:collectDiagnosis()
        self.diagCacheAt = getTimestampMs()
    end
    local cards = self.diagCards or {}
    local mx, my = self:getLocalMousePosition()
    self.diagHoverTip = nil
    self.diagScroll = self.diagScroll or 0
    self:setStencilRect(b.x + 2, top, b.w - 4, viewH)
    local y = top - self.diagScroll
    if #cards == 0 then
        self:drawText(L("Healthy", "No active conditions."), x, top + 10, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT_M)
    end
    for _, card in ipairs(cards) do
        local lines = {}
        for _, l in ipairs(card.lines or {}) do
            if l and l ~= "" then for _, wl in ipairs(wrap("- " .. l, w - 24)) do lines[#lines + 1] = wl end end
        end
        local h = 12 + fh(FONT_M) + 6 + #lines * (fh() + 2) + 10
        if y + h >= top and y <= top + viewH then
            local hovered = mx >= x and mx <= x + w and my >= math.max(y, top) and my <= math.min(y + h, top + viewH)
            self:drawRect(x, y, w, h - 6, hovered and 0.55 or 0.4, c.panelSoft.r, c.panelSoft.g, c.panelSoft.b)
            self:drawRectBorder(x, y, w, h - 6, 0.8, c.borderDim.r, c.borderDim.g, c.borderDim.b)
            local status = tostring(card.status or "")
            local sc = card.statusColor or { 1, 1, 1 }
            local statusW = tw(status, FONT)
            local title = tostring(card.title) .. (card.stage and ("  ·  " .. L("Stage", "Stage %1", card.stage)) or "")
            local maxT = w - statusW - 36
            title = S.fitText(title, maxT, function(t) return tw(t, FONT_M) end, "")
            self:drawText(title, x + 10, y + 8, c.text.r, c.text.g, c.text.b, 1, FONT_M)
            self:drawText(status, x + w - 12 - statusW, y + 8 + (fh(FONT_M) - fh()) / 2, sc[1], sc[2], sc[3], 1, FONT)
            local ly = y + 12 + fh(FONT_M) + 4
            for _, l in ipairs(lines) do
                self:drawText(l, x + 14, ly, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT)
                ly = ly + fh() + 2
            end
            if hovered and card.tip and card.tip ~= "" then self.diagHoverTip = card.tip end
        end
        y = y + h
    end
    self:clearStencilRect()
    local contentH = y + self.diagScroll - top
    self.diagMaxScroll = math.max(0, contentH - viewH)
    if self.diagScroll > self.diagMaxScroll then self.diagScroll = self.diagMaxScroll end
    if self.diagMaxScroll > 0 then
        local barH = math.max(24, viewH * viewH / contentH)
        local barY = top + (viewH - barH) * (self.diagScroll / self.diagMaxScroll)
        self:drawRect(b.x + b.w - 7, barY, 3, barH, 0.8, c.red.r, c.red.g, c.red.b)
    end
end

function EHR_HealthPanelUI:onDiagnosisWheel(del)
    if (self.diagMaxScroll or 0) <= 0 then return false end
    self.diagScroll = math.max(0, math.min(self.diagMaxScroll, (self.diagScroll or 0) + del * 40))
    return true
end

function EHR_HealthPanelUI:drawDiagnosisTooltip()
    local text = self.diagHoverTip
    if not text or text == "" then return end
    local c = EHR_HealthPanelUI.Colors
    local lines = wrap(text, 320)
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, tw(l)) end
    w = w + 16
    local h = #lines * (fh() + 2) + 12
    local mx, my = self:getLocalMousePosition()
    local x, y = mx + 16, my + 16
    if x + w > self.width - 4 then x = mx - w - 12 end
    if y + h > self.height - 4 then y = my - h - 12 end
    self:drawRect(x, y, w, h, 0.96, 0.015, 0.012, 0.012)
    self:drawRectBorder(x, y, w, h, 0.88, c.border.r, c.border.g, c.border.b)
    for i, l in ipairs(lines) do
        self:drawText(l, x + 8, y + 6 + (i - 1) * (fh() + 2), c.text.r, c.text.g, c.text.b, 1, FONT)
    end
end

-- ------------------------------------------------------------- status / names in the EHR window
local function install()
    if not EHR_HealthPanelUI or EHR_HealthPanelUI.harmonieDiagInstalled then return end
    EHR_HealthPanelUI.harmonieDiagInstalled = true
    local origInfo = EHR_HealthPanelUI.getDiseaseDisplayInfo
    if origInfo then
        function EHR_HealthPanelUI:getDiseaseDisplayInfo(diseaseId, disease)
            local info = origInfo(self, diseaseId, disease)
            if type(info) ~= "table" or info.statusText then return info end
            local id = self.getNormalizedDiseaseId and self:getNormalizedDiseaseId(diseaseId) or diseaseId
            local exam = self.isRemoteHealthPanel and self.remoteExamData or nil
            if S.isHeld(self.player, id, exam) then
                local copy = {}
                for k, v in pairs(info) do copy[k] = v end
                copy.statusText = L("HeldShort", "AWAIT SURGERY")
                copy.statusColor = EHR_HealthPanelUI.Colors.blue
                return copy
            end
            return info
        end
    end
    local origName = EHR_HealthPanelUI.getTreatmentName
    if origName then
        function EHR_HealthPanelUI:getTreatmentName(treatment)
            if type(treatment) == "table" and treatment.source == S.TREATMENT_SOURCE and treatment.surgery then
                return S.T("Name_" .. treatment.surgery, treatment.surgery)
            end
            return origName(self, treatment)
        end
    end
end

install()
if Events and Events.OnGameStart then Events.OnGameStart.Add(install) end

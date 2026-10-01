--[[
    HARMONIE - Home Medic : "Diagnosis" tab of the medical window (client)

    Request 2026-10-01 -- a diagnosis game: the doctor ticks the signs the
    patient shows; the candidate list narrows to the illnesses that cause
    all of them (HM_Diagnosis.DISEASES, built from what each illness really
    does in game). Illnesses the doctor does not know stay "Unknown" and
    cannot be picked. Picking one the patient really has records the
    diagnosis (server-checked); from then on the medical window names it.
    Until then every illness shows as Unknown, on every tab.

    The right column, "Findings", shows what each DIAGNOSED illness is doing
    to the body now (its own stage effects) and blood loss. Works for
    another player too (EHR's remote exam snapshot). Both columns scroll
    with the wheel; hover tests use the drawn (scrolled) coordinates.
]]--

require "HARMONIEHomeMedic/HM_Text"
require "ExtensiveHealth/EHR_HealthPanelUI"
require "HARMONIEHomeMedic/Surgery/HM_Surgery"
require "HARMONIEHomeMedic/HM_Diagnosis"
local S = HM_Surgery
local D = HM_Diagnosis
D.Client = D.Client or {}
local C = D.Client

local FONT, FONT_M = UIFont.Small, UIFont.Medium
local function fh(f) return getTextManager():getFontHeight(f or FONT) end
local function tw(t, f) return getTextManager():MeasureStringX(f or FONT, t or "") end
local function L(key, fallback, ...)
    return HM_Text("UI_HomeMedic_Diag_" .. key, fallback or key, ...)
end
local function pct(v) return math.floor((tonumber(v) or 0) * 100 + 0.5) end
local function num(v) return string.format("%.1f", tonumber(v) or 0) end
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end

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

local function codex(id, field)
    local k = "UI_EHR_Codex_" .. tostring(id):gsub("[^%w_]", "_") .. "_" .. field
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

-- doctor, patient, exam snapshot of this panel
local function parties(panel)
    local exam = panel.isRemoteHealthPanel and panel.remoteExamData or nil
    local doctor = panel.isRemoteHealthPanel and panel.remoteDoctor or panel.player
    return doctor, panel.player, exam
end

local function diseaseName(id)
    local t = codex(id, "Name")
    if t then return t end
    local F = EHR and EHR.DiseaseFlyers
    if F and F.GetDiseaseFriendlyName then
        local ok, n = pcall(F.GetDiseaseFriendlyName, id)
        if ok and n and n ~= "" and n ~= id then return n end
    end
    return S.T("Cond_" .. id, id)
end
C.diseaseName = diseaseName

local function tagName(tag) return L("Tag_" .. tag, tag) end

-- -> cards { title, stage, status, statusColor, lines, tip } of DIAGNOSED
-- illnesses (+ blood loss), and how many illnesses are still undiagnosed
function EHR_HealthPanelUI:collectDiagnosis()
    local get, exam = source(self)
    local _, patient = parties(self)
    local cards, unknown = {}, 0
    local med = get("EHR_Medication")
    local treatments = type(med) == "table" and med.activeTreatments or {}
    local function seen(id)
        if D.isDiagnosed(patient, id, exam) then return true end
        unknown = unknown + 1
        return false
    end

    -- EHR diseases
    local dis = get("EHR_Disease")
    local active = type(dis) == "table" and dis.active or {}
    local ids = {}
    for id in pairs(active) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, rawId in ipairs(ids) do
        local e = active[rawId]
        local id = D.normalize(rawId)
        if type(e) == "table" and (not D.gated(id) or seen(id)) then
            local stage = tonumber(e.stage) or 1
            local def = EHR and EHR.Disease and EHR.Disease.Diseases and EHR.Disease.Diseases[rawId]
            local lines = effectLines(def and def.effects and def.effects[stage])
            if #lines == 0 then
                local tags = {}
                for _, t in ipairs(D.DISEASES[id] or {}) do tags[#tags + 1] = tagName(t) end
                if #tags > 0 then lines = { table.concat(tags, ", ") } end
            end
            local status, col = statusFor(self, id, exam, treatments[rawId] ~= nil or treatments[id] ~= nil)
            local hint = surgeryHint(id)
            if hint then lines[#lines + 1] = hint end
            cards[#cards + 1] = { title = diseaseName(id), stage = stage, status = status, statusColor = col, lines = lines,
                tip = codex(id, "Treatment") or "" }
        end
    end

    -- sepsis (own module)
    local sep = get("EHR_Sepsis")
    if type(sep) == "table" and (tonumber(sep.stage) or 0) > 0 and seen("sepsis") then
        local st = tonumber(sep.stage)
        local eff = EHR and EHR.Sepsis and EHR.Sepsis.StageEffects and EHR.Sepsis.StageEffects[st]
        local lines = effectLines(eff)
        local hint = surgeryHint("sepsis")
        if hint then lines[#lines + 1] = hint end
        local status, col = statusFor(self, "sepsis", exam, treatments.sepsis ~= nil)
        cards[#cards + 1] = { title = diseaseName("sepsis"), stage = st, status = status, statusColor = col,
            lines = lines, tip = codex("sepsis", "Treatment") or "" }
    end

    -- infected wounds (per body part; one diagnosis covers them all)
    local wi = get("EHR_WoundInfection")
    local cfg = EHR and EHR.WoundInfection and EHR.WoundInfection.Config
    if type(wi) == "table" and type(wi.parts) == "table" and D.isActive(get, "wound_infection", patient, exam)
            and seen("wound_infection") then
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
                cards[#cards + 1] = { title = diseaseName("wound_infection") .. " - " .. tostring(where), stage = st,
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
    if D.isActive(get, "knox_infection", patient, exam) and seen("knox_infection") then
        cards[#cards + 1] = { title = diseaseName("knox_infection"), status = L("Untreated", "UNTREATED"),
            statusColor = { 0.95, 0.30, 0.28 }, lines = { surgeryHint("knox") or "", surgeryHint("knox_bite") or "" },
            tip = codex("knox_infection", "Treatment") or "" }
    end
    return cards, unknown
end

-- ------------------------------------------------------------- requests
function C.send(panel, id)
    local doctor, patient = parties(panel)
    if not doctor or not patient then return end
    local args = { id = id }
    C.lastPanel = panel
    if isClient and isClient() then
        if patient ~= doctor then args.patientOnline = patient:getOnlineID() end
        sendClientCommand(doctor, D.MODULE, "Diagnose", args)
    else
        args.patientNum = patient.getPlayerNum and patient:getPlayerNum() or 0
        D.Server.Diagnose(doctor, args)
    end
end

function C.onServerCommand(module, command, args)
    if module ~= D.MODULE then return end
    args = args or {}
    if command == "Sync" then
        local p = getPlayer and getPlayer()
        local md = p and p:getModData()
        if md then md[D.KEY] = args.data or {} end
        return
    end
    if command ~= "Result" then return end
    local panel = C.lastPanel
    local st = panel and panel.dxState
    if not st then return end
    local name = diseaseName(args.id)
    if args.ok then
        if panel.isRemoteHealthPanel and type(panel.remoteExamData) == "table" then
            panel.remoteExamData[D.KEY] = args.data or {}
        elseif panel.player and panel.player.getModData then
            panel.player:getModData()[D.KEY] = args.data or {}
        end
        st.msg, st.msgColor = L("Confirmed", "Diagnosis: %1", name), { 0.35, 0.90, 0.45 }
        st.tags = {}
        panel.diagCacheAt = nil
    else
        local r = tostring(args.reason or "Wrong")
        st.msg = L("Denied_" .. r, "%1 does not fit this patient.", name)
        st.msgColor = { 0.95, 0.40, 0.30 }
        if r == "Wrong" then st.lockUntil = nowMs() + D.WRONG_LOCK_MS end
    end
end

if Events and Events.OnServerCommand and not C.registered then
    C.registered = true
    Events.OnServerCommand.Add(C.onServerCommand)
end

-- ------------------------------------------------------------- drawing
local function inside(mx, my, x, y, w, h) return mx >= x and mx <= x + w and my >= y and my <= y + h end

local function drawScrollbar(self, x, top, viewH, contentH, scroll)
    local maxScroll = math.max(0, contentH - viewH)
    if maxScroll <= 0 then return 0 end
    local c = EHR_HealthPanelUI.Colors
    local barH = math.max(24, viewH * viewH / contentH)
    local barY = top + (viewH - barH) * (math.min(scroll, maxScroll) / maxScroll)
    self:drawRect(x, barY, 3, barH, 0.8, c.accent.r, c.accent.g, c.accent.b)
    return maxScroll
end

-- findings cards (right column)
local function drawCards(self, st, cards, x, w, top, viewH, mx, my)
    local c = EHR_HealthPanelUI.Colors
    local y = top - st.scrollR
    for _, card in ipairs(cards) do
        local lines = {}
        for _, l in ipairs(card.lines or {}) do
            if l and l ~= "" then for _, wl in ipairs(wrap("- " .. l, w - 24)) do lines[#lines + 1] = wl end end
        end
        local h = 12 + fh(FONT_M) + 6 + #lines * (fh() + 2) + 10
        if y + h >= top and y <= top + viewH then
            local hovered = inside(mx, my, x, math.max(y, top), w, math.min(y + h, top + viewH) - math.max(y, top))
            self:drawRect(x, y, w, h - 6, hovered and 0.55 or 0.4, c.panelSoft.r, c.panelSoft.g, c.panelSoft.b)
            self:drawRectBorder(x, y, w, h - 6, 0.8, c.borderDim.r, c.borderDim.g, c.borderDim.b)
            local status = tostring(card.status or "")
            local sc = card.statusColor or { 1, 1, 1 }
            local statusW = tw(status, FONT)
            local title = tostring(card.title) .. (card.stage and ("  -  " .. L("Stage", "Stage %1", card.stage)) or "")
            title = S.fitText(title, w - statusW - 36, function(t) return tw(t, FONT_M) end, "")
            self:drawText(title, x + 10, y + 8, c.text.r, c.text.g, c.text.b, 1, FONT_M)
            self:drawText(status, x + w - 12 - statusW, y + 8 + (fh(FONT_M) - fh()) / 2, sc[1], sc[2], sc[3], 1, FONT)
            local ly = y + 12 + fh(FONT_M) + 4
            for _, l in ipairs(lines) do
                self:drawText(l, x + 14, ly, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT)
                ly = ly + fh() + 2
            end
            if hovered and card.tip and card.tip ~= "" then st.tip = card.tip end
        end
        y = y + h
    end
    return y + st.scrollR - top
end

function EHR_HealthPanelUI:drawDiagnosisPanel()
    local c = EHR_HealthPanelUI.Colors
    local b = self:getTabContentBounds()
    local doctor, patient, exam = parties(self)
    local st = self.dxState
    if not st or st.patient ~= patient then
        st = { tags = {}, scrollL = 0, scrollR = 0, patient = patient }
        self.dxState = st
    end
    self:drawPanelFrame(b.x, b.y, b.w, b.h, L("Title", "DIAGNOSIS"), nil)
    if st.msg then
        local m = S.fitText(st.msg, b.w * 0.55, function(t) return tw(t, FONT) end)
        local mc = st.msgColor or { 1, 1, 1 }
        self:drawText(m, b.x + b.w - 16 - tw(m), b.y + 9, mc[1], mc[2], mc[3], 1, FONT)
    end

    local top, viewH = b.y + 48, b.h - 56
    local leftW = math.floor((b.w - 40) * 0.55)
    local lx = b.x + 14
    local rx = lx + leftW + 14
    local rw = b.x + b.w - 16 - rx
    local mx, my = self:getLocalMousePosition()
    local inView = my >= top and my <= top + viewH
    st.hits, st.tip, st.leftEdge = {}, nil, rx - 7
    local function hit(x, y, w, h, kind, id)
        if y + h >= top and y <= top + viewH then st.hits[#st.hits + 1] = { x = x, y = y, w = w, h = h, kind = kind, id = id } end
    end

    -- ---- left: signs, then candidates
    self:setStencilRect(lx - 2, top, leftW + 4, viewH)
    local y = top - st.scrollL
    if not D.enabled() then
        for _, l in ipairs(wrap(L("Off", "Diagnosis is switched off on this server: every illness is named."), leftW)) do
            self:drawText(l, lx, y, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT); y = y + fh() + 2
        end
    end
    for _, l in ipairs(wrap(L("Intro", "Tick the signs the patient shows. The list narrows to illnesses that cause all of them."), leftW)) do
        self:drawText(l, lx, y, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT); y = y + fh() + 2
    end
    y = y + 8
    local chipH = fh() + 8
    local selected = 0
    for _, g in ipairs(D.GROUPS) do
        self:drawText(L("Group_" .. g.id, g.id), lx, y, c.accent.r, c.accent.g, c.accent.b, 1, FONT)
        y = y + fh() + 4
        local x = lx
        for _, tag in ipairs(g.tags) do
            local label = tagName(tag)
            local w = math.min(leftW, tw(label) + 18)
            if x > lx and x + w > lx + leftW then x = lx; y = y + chipH + 6 end
            local on = st.tags[tag] == true
            if on then selected = selected + 1 end
            local hov = inView and inside(mx, my, x, y, w, chipH)
            local bg = on and c.accentDark or c.panelSoft
            local bd = on and c.accent or c.borderDim
            self:drawRect(x, y, w, chipH, on and 0.95 or (hov and 0.7 or 0.45), bg.r, bg.g, bg.b)
            self:drawRectBorder(x, y, w, chipH, on and 1 or 0.8, bd.r, bd.g, bd.b)
            local tc = on and c.text or (hov and c.text or c.textDim)
            self:drawText(S.fitText(label, w - 12, function(t) return tw(t) end), x + 9, y + 4, tc.r, tc.g, tc.b, 1, FONT)
            hit(x, y, w, chipH, "tag", tag)
            x = x + w + 6
        end
        y = y + chipH + 12
    end

    -- candidates
    local head = L("Candidates", "Possible illnesses")
    self:drawText(head, lx, y, c.text.r, c.text.g, c.text.b, 1, FONT_M)
    if selected > 0 then
        local clear = L("Clear", "Clear")
        local cw = tw(clear) + 16
        local cx = lx + leftW - cw
        local hov = inView and inside(mx, my, cx, y, cw, chipH)
        self:drawRectBorder(cx, y, cw, chipH, hov and 1 or 0.7, c.border.r, c.border.g, c.border.b)
        self:drawText(clear, cx + 8, y + 4, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT)
        hit(cx, y, cw, chipH, "clear")
    end
    y = y + math.max(fh(FONT_M), chipH) + 6
    if selected == 0 then
        for _, l in ipairs(wrap(L("PickSigns", "Pick at least one sign."), leftW)) do
            self:drawText(l, lx, y, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT); y = y + fh() + 2
        end
    else
        local list = D.candidates(st.tags)
        if #list == 0 then
            for _, l in ipairs(wrap(L("NoMatch", "No illness causes all of these signs. Remove one."), leftW)) do
                self:drawText(l, lx, y, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT); y = y + fh() + 2
            end
        end
        local locked = (st.lockUntil or 0) > nowMs()
        local rowH = fh(FONT_M) + 10
        for _, id in ipairs(list) do
            local known = D.knows(doctor, id)
            local done = known and D.isDiagnosed(patient, id, exam) and D.isActive(D.getter(patient, exam), id, patient, exam)
            local hov = inView and inside(mx, my, lx, y, leftW, rowH)
            self:drawRect(lx, y, leftW, rowH - 4, hov and 0.55 or 0.35, c.panelSoft.r, c.panelSoft.g, c.panelSoft.b)
            self:drawRectBorder(lx, y, leftW, rowH - 4, 0.7, c.borderDim.r, c.borderDim.g, c.borderDim.b)
            local btn, btnColor
            if done then
                btn, btnColor = L("Done", "DIAGNOSED"), c.green
            elseif not known then
                btn, btnColor = "?", c.textDim
            elseif locked then
                btn, btnColor = L("Wait", "Wait %1s", math.ceil(((st.lockUntil or 0) - nowMs()) / 1000)), c.textDim
            else
                btn, btnColor = L("Diagnose", "Diagnose"), c.yellow
            end
            local bw = tw(btn) + 16
            local bx = lx + leftW - bw - 6
            local by = y + math.floor((rowH - 4 - chipH) / 2)
            local name = known and diseaseName(id) or L("Unknown", "Unknown illness")
            local nc = known and c.text or c.textDim
            self:drawText(S.fitText(name, bx - lx - 18, function(t) return tw(t, FONT_M) end), lx + 10, y + 3, nc.r, nc.g, nc.b, 1, FONT_M)
            local canPick = known and not done and not locked
            local bh = canPick and inView and inside(mx, my, bx, by, bw, chipH)
            if canPick then
                self:drawRect(bx, by, bw, chipH, bh and 0.9 or 0.6, c.accentDark.r, c.accentDark.g, c.accentDark.b)
                self:drawRectBorder(bx, by, bw, chipH, 1, c.accent.r, c.accent.g, c.accent.b)
                hit(bx, by, bw, chipH, "pick", id)
            end
            self:drawText(btn, bx + 8, by + 4, btnColor.r, btnColor.g, btnColor.b, 1, FONT)
            if hov then
                st.tip = known and (codex(id, "Symptoms") or "") or L("UnknownTip", "You do not know this illness yet: read its flyer or reach First Aid 8.")
            end
            y = y + rowH
        end
    end
    local contentL = y + st.scrollL - top + 8
    self:clearStencilRect()
    st.maxL = drawScrollbar(self, lx + leftW + 4, top, viewH, contentL, st.scrollL)
    if st.scrollL > st.maxL then st.scrollL = st.maxL end
    self:drawRect(rx - 8, top, 1, viewH, 0.5, c.borderDim.r, c.borderDim.g, c.borderDim.b)

    -- ---- right: findings
    if self.diagCacheAt == nil or (nowMs() - self.diagCacheAt) > 500 then
        self.diagCards, self.diagUnknown = self:collectDiagnosis()
        self.diagCacheAt = nowMs()
    end
    self:setStencilRect(rx, top, rw, viewH)
    self:drawText(L("Findings", "Findings"), rx, top - st.scrollR, c.text.r, c.text.g, c.text.b, 1, FONT_M)
    local cards = {}
    if (self.diagUnknown or 0) > 0 then
        cards[1] = { title = L("Undiagnosed", "Undiagnosed illness x%1", self.diagUnknown), status = "?",
            statusColor = { 0.95, 0.75, 0.25 }, lines = { L("UndiagnosedHint", "Find it with the signs on the left.") } }
    end
    for _, card in ipairs(self.diagCards or {}) do cards[#cards + 1] = card end
    if #cards == 0 then
        self:drawText(L("Healthy", "No active conditions."), rx, top + fh(FONT_M) + 8 - st.scrollR, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT)
    end
    st.scrollR = st.scrollR or 0
    local saved = st.scrollR
    st.scrollR = saved - (fh(FONT_M) + 8)
    local contentR = drawCards(self, st, cards, rx, rw - 8, top, viewH, mx, my) + fh(FONT_M) + 8
    st.scrollR = saved
    self:clearStencilRect()
    st.maxR = drawScrollbar(self, b.x + b.w - 7, top, viewH, contentR, st.scrollR)
    if st.scrollR > st.maxR then st.scrollR = st.maxR end
end

function EHR_HealthPanelUI:onDiagnosisWheel(del)
    local st = self.dxState
    if not st then return false end
    local mx = self:getLocalMousePosition()
    if mx < (st.leftEdge or 0) then
        if (st.maxL or 0) <= 0 then return false end
        st.scrollL = math.max(0, math.min(st.maxL, st.scrollL + del * 40))
    else
        if (st.maxR or 0) <= 0 then return false end
        st.scrollR = math.max(0, math.min(st.maxR, st.scrollR + del * 40))
    end
    return true
end

function EHR_HealthPanelUI:onDiagnosisMouseDown(x, y)
    local st = self.dxState
    if not st or not st.hits then return false end
    local b = self:getTabContentBounds()
    if y < b.y + 48 or y > b.y + b.h - 8 then return false end
    for i = #st.hits, 1, -1 do
        local h = st.hits[i]
        if inside(x, y, h.x, h.y, h.w, h.h) then
            if h.kind == "tag" then
                st.tags[h.id] = not st.tags[h.id] or nil
            elseif h.kind == "clear" then
                st.tags = {}
            elseif h.kind == "pick" then
                st.msg = nil
                C.send(self, h.id)
            end
            if getSoundManager then pcall(function() getSoundManager():playUISound("UISelectListItem") end) end
            return true
        end
    end
    return false
end

function EHR_HealthPanelUI:drawDiagnosisTooltip()
    local st = self.dxState
    local text = st and st.tip
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

EHR_HealthPanelUI.ExtraTabs = EHR_HealthPanelUI.ExtraTabs or {}
EHR_HealthPanelUI.ExtraTabs.diagnosis = {
    draw = function(panel) panel:drawDiagnosisPanel() end,
    render = function(panel) panel:drawDiagnosisTooltip() end,
    wheel = function(panel, del) return panel:onDiagnosisWheel(del) end,
    mouseDown = function(panel, x, y) return panel:onDiagnosisMouseDown(x, y) end,
}

-- ------------------------------------------------------------- names in the EHR windows
-- every gated illness reads "Unknown" until it is diagnosed
-- Two different states:
--   "Undiagnosed" -- the doctor knows this illness, nobody has diagnosed it
--                    yet: go to the Diagnosis tab.
--   "Unknown"     -- the doctor does not know this illness at all (no flyer,
--                    First Aid < 8): even the Diagnosis tab cannot name it.
local function unknownInfo(panel, info, id)
    local copy = {}
    for k, v in pairs(info) do copy[k] = v end
    local doctor = parties(panel)
    local known = doctor and D.knows(doctor, id)
    local name, detail
    if known then
        name = L("Undiagnosed_Name", "Undiagnosed illness")
        detail = L("UndiagnosedDetail", "Not diagnosed yet: use the Diagnosis tab.")
        copy.hmState = "undiagnosed"
    else
        local u = panel.getUnknownDiseaseInfo and panel:getUnknownDiseaseInfo(id) or {}
        name = u.displayName or L("Unknown", "Unknown illness")
        detail = L("UnknownDetail", "You do not know this illness (disease flyer or First Aid 8).")
        copy.hmState = "unknown"
    end
    copy.displayName, copy.realName, copy.sortName = name, name, name
    copy.canIdentify = false
    copy.iconKey = "unknown"
    copy.showStageSeverity, copy.showProgress, copy.showTreatmentStatus = false, false, false
    copy.statusText, copy.statusColor = nil, nil
    copy.detailText = detail
    copy.detailColor = known and EHR_HealthPanelUI.Colors.yellow or EHR_HealthPanelUI.Colors.textDim
    copy.hideProgressBar, copy.progressText = true, ""
    return copy
end
C.unknownInfo = unknownInfo

-- ------------------------------------------------------------- buttons on the first tab's illness rows
-- Undiagnosed -> "Diagnose" (Diagnosis tab). Diagnosed and at a stage that
-- needs surgery -> "Surgery" (Surgery tab, that operation selected).
local function rowButton(panel, diseaseId, disease, x, y, w, rowH)
    if type(disease) == "table" and (disease.isCorpseExposure or disease.isExposureCondition) then return end
    local id = D.normalize(type(disease) == "table" and disease.isKnox and "knox_infection" or diseaseId)
    if not D.gated(id) then return end
    local doctor, patient, exam = parties(panel)
    local label, action, sid
    if D.enabled() and not D.isDiagnosed(patient, id, exam) then
        if not D.knows(doctor, id) then return end
        label, action = L("Btn_Diagnose", "Diagnose"), "diagnosis"
    else
        local list = S.surgeriesFor(id)
        if #list == 0 then return end
        local needed = S.needsSurgery(patient, id, exam) or S.isHeld(patient, id, exam)
        if not needed then return end
        label, action, sid = S.T("Btn_Surgery", "Surgery"), "surgery", list[1]
    end
    local c = EHR_HealthPanelUI.Colors
    local bh = fh() + 8
    local bw = tw(label) + 20
    local bx = x + w - bw - 12
    local by = y + rowH - bh - 8
    local mx, my = panel:getLocalMousePosition()
    local hov = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
    panel:drawRect(bx, by, bw, bh, hov and 0.95 or 0.75, c.accentDark.r, c.accentDark.g, c.accentDark.b)
    panel:drawRectBorder(bx, by, bw, bh, 1, c.accent.r, c.accent.g, c.accent.b)
    panel:drawText(label, bx + 10, by + 4, c.text.r, c.text.g, c.text.b, 1, FONT)
    panel.hmRowButtons = panel.hmRowButtons or {}
    table.insert(panel.hmRowButtons, { x = bx, y = by, w = bw, h = bh, action = action, sid = sid, id = id })
end

local function installRowButtons()
    if EHR_HealthPanelUI.hmRowButtonsInstalled or not EHR_HealthPanelUI.drawDiseaseRow then return end
    EHR_HealthPanelUI.hmRowButtonsInstalled = true
    local origRow = EHR_HealthPanelUI.drawDiseaseRow
    function EHR_HealthPanelUI:drawDiseaseRow(diseaseId, disease, x, y, w)
        local used = origRow(self, diseaseId, disease, x, y, w)
        local rowH = (tonumber(used) or 98) - 10
        pcall(rowButton, self, diseaseId, disease, x, y, w, rowH)
        return used
    end
    local origPre = EHR_HealthPanelUI.prerender
    function EHR_HealthPanelUI:prerender()
        self.hmRowButtons = {}
        return origPre(self)
    end
    local origDown = EHR_HealthPanelUI.onMouseDown
    function EHR_HealthPanelUI:onMouseDown(x, y)
        if self.activeTab == "ehr" and not self.hmCollapsed then
            for _, b in ipairs(self.hmRowButtons or {}) do
                if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h and y >= self:getEHRContentTop() then
                    if b.action == "surgery" then self.hmSurgerySelect = { sid = b.sid, id = b.id } end
                    self:setActiveTab(b.action)
                    return true
                end
            end
        end
        return origDown(self, x, y)
    end
end

local function install()
    if not EHR_HealthPanelUI or EHR_HealthPanelUI.harmonieDiagInstalled then return end
    EHR_HealthPanelUI.harmonieDiagInstalled = true
    local origInfo = EHR_HealthPanelUI.getDiseaseDisplayInfo
    if origInfo then
        function EHR_HealthPanelUI:getDiseaseDisplayInfo(diseaseId, disease)
            local info = origInfo(self, diseaseId, disease)
            if type(info) ~= "table" then return info end
            if type(disease) == "table" and (disease.isCorpseExposure or disease.isExposureCondition) then return info end
            local id = D.normalize(type(disease) == "table" and disease.isKnox and "knox_infection" or diseaseId)
            local _, patient, exam = parties(self)
            if D.gated(id) and not D.isDiagnosed(patient, id, exam) then return unknownInfo(self, info, id) end
            if info.statusText then return info end
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
installRowButtons()
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(install)
    Events.OnGameStart.Add(installRowButtons)
end

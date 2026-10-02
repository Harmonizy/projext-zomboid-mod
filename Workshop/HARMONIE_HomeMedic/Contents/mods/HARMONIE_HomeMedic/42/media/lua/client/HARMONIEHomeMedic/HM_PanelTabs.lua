--[[
    HARMONIE - Home Medic : medical window tabs 3, 6 and 7 (client)

    "stats"    -- every stat of the player in this window (yourself or the
                  patient you examine), mods' stats included (HM_Stats).
                  A snapshot taken when the tab opens; Refresh takes a new
                  one. Remote patients: one request to the server, which
                  answers with its view and then the patient's own.
    "handbook" -- the disease handbook (EHR_MedicalJournalUI), embedded as a
                  child view. The J key opens the window on this tab.
    "meds"     -- the medication handbook (HM_MedHandbookUI), the same way.

    Tabs 1, 2 are EHR's own; tab 4 is HM_DiagnosisPanel.lua, tab 5
    Surgery/HM_SurgeryTab.lua.
]]--

require "HARMONIEHomeMedic/HM_Text"
require "ExtensiveHealth/EHR_HealthPanelUI"
require "ExtensiveHealth/EHR_MedicalJournalUI"
require "HARMONIEHomeMedic/Surgery/HM_Surgery"
require "HARMONIEHomeMedic/HM_Stats"
require "HARMONIEHomeMedic/HM_MedHandbookUI"
local S = HM_Surgery
local St = HM_Stats

local FONT, FONT_M = UIFont.Small, UIFont.Medium
local function fh(f) return getTextManager():getFontHeight(f or FONT) end
local function tw(t, f) return getTextManager():MeasureStringX(f or FONT, t or "") end
local function txt(key, fallback)
    local t = key and getText and getText(key)
    if not t or t == key or t == "?" then return fallback end
    return t
end
local function L(key, fallback, ...)
    return HM_Text("UI_HomeMedic_Stats_" .. key, fallback or key, ...)
end
local function inside(mx, my, x, y, w, h) return mx >= x and mx <= x + w and my >= y and my <= y + h end

-- ============================================================= stats tab
-- bars where "more" is good (green when full); the rest turn red when full
local GOOD = {
    UI_HomeMedic_Stat_Health = true, UI_HomeMedic_Stat_Blood = true, UI_HomeMedic_Stat_Immunity = true,
    UI_HomeMedic_Stat_ENDURANCE = true, UI_HomeMedic_Stat_SANITY = true, UI_HomeMedic_Stat_MORALE = true,
    UI_HomeMedic_Stat_FITNESS = true,
}

local function prettify(name)
    name = tostring(name or ""):gsub("_", " "):lower()
    return (name:gsub("^%l", string.upper))
end

local function rowLabel(row)
    return txt(row.k, nil) or (row.t and row.t:match("^[A-Z_]+$") and prettify(row.t)) or tostring(row.t or "?")
end

local function barColor(row)
    local f = row.f or 0
    if row.k == "UI_HomeMedic_Stat_TEMPERATURE" or row.k == "UI_HomeMedic_Stat_BodyTemp" then return 0.35, 0.65, 0.95 end
    if GOOD[row.k] or row.g == "mods" then f = 1 - f end
    -- 0 = green, 1 = red
    return 0.30 + 0.65 * f, 0.85 - 0.55 * f, 0.30
end

local function patientOf(panel) return panel.player end
local BAD = { r = 1.0, g = 0.33, b = 0.28 }   -- abnormal values (bright red on the dark panel)

-- vanilla moodle icon by moodle type name; tries the game's texture paths,
-- nil when none is found (a drawn badge is used instead)
local moodleTex = {}
local function moodleIcon(mt)
    if not mt or not getTexture then return nil end
    if moodleTex[mt] ~= nil then return moodleTex[mt] or nil end
    local name = tostring(mt):gsub("^.*[:%.]", "")
    local cap = name:sub(1, 1):upper() .. name:sub(2)
    local found = false
    for _, n in ipairs({ name, cap }) do
        for _, path in ipairs({
            "media/ui/Moodles/Moodle_Icon_" .. n .. ".png", "media/ui/Moodle_Icon_" .. n .. ".png",
            "Moodle_Icon_" .. n, "media/ui/Moodles/" .. n .. ".png", "media/ui/Moodles/64/" .. n .. ".png",
            "media/ui/Moodles/128/" .. n .. ".png" }) do
            local ok, t = pcall(getTexture, path)
            if ok and t then found = t; break end
        end
        if found then break end
    end
    if not found then print("[HARMONIE HomeMedic] no vanilla moodle icon found for " .. tostring(mt) .. " (drawn badge used)") end
    moodleTex[mt] = found
    return found or nil
end

local function drawMoodle(panel, row, x, y, size)
    local gb = row.gb or 0
    local r, g, b = 0.45, 0.5, 0.55
    if gb == 1 then r, g, b = 0.22, 0.75, 0.3 elseif gb == 2 then r, g, b = 0.85, 0.22, 0.15 end
    local lv = math.max(1, math.min(4, row.lv or 1))
    local a = 0.35 + 0.15 * lv
    panel:drawRect(x, y, size, size, a, r * 0.6, g * 0.6, b * 0.6)
    panel:drawRectBorder(x, y, size, size, 0.9, r, g, b)
    local tex = moodleIcon(row.mt)
    if tex then
        panel:drawTextureScaled(tex, x + 1, y + 1, size - 2, size - 2, 1, 1, 1, 1)
    else
        local letter = tostring(row.t or "?"):sub(1, 1)
        panel:drawTextCentre(letter, x + size / 2, y + math.floor((size - fh()) / 2), 1, 1, 1, 1, FONT)
    end
end

function EHR_HealthPanelUI:hmStatsRequest()
    local patient = patientOf(self)
    local st = self.hmStats or {}
    self.hmStats = st
    st.scroll = st.scroll or 0
    st.patient = patient
    st.at = getGameTime and getGameTime():getWorldAgeHours() or 0
    if self.isRemoteHealthPanel and isClient and isClient() and patient and patient.getOnlineID then
        st.waiting = true
        st.rows = st.rows or {}
        St.Client.panels[patient:getOnlineID()] = self
        sendClientCommand(self.remoteDoctor or getPlayer(), St.MODULE, "Snapshot", { patientOnline = patient:getOnlineID() })
    else
        st.waiting = false
        st.rows = St.collect(patient)
    end
end

St.Client = St.Client or { panels = {} }
function St.Client.onServerCommand(module, command, args)
    if module ~= St.MODULE then return end
    args = args or {}
    if command == "Collect" then
        -- someone examines us: answer with our own view of our stats
        local me = getPlayer and getPlayer()
        if me then sendClientCommand(me, St.MODULE, "Collected", { doctorOnline = args.doctorOnline, rows = St.collect(me) }) end
    elseif command == "Snapshot" then
        local panel = St.Client.panels[tonumber(args.patientOnline) or -1]
        local st = panel and panel.hmStats
        if not st then return end
        if st.source == "patient" and args.source == "server" then return end
        st.rows = type(args.rows) == "table" and args.rows or {}
        st.source = args.source
        st.waiting = args.source ~= "patient"
        st.failed = args.ok == false
    end
end
if Events and Events.OnServerCommand and not St.Client.registered then
    St.Client.registered = true
    Events.OnServerCommand.Add(St.Client.onServerCommand)
end

local function hoursText(h)
    local day = math.floor(h / 24)
    local hh = math.floor(h % 24)
    local mm = math.floor((h * 60) % 60)
    return string.format("%d, %02d:%02d", day, hh, mm)
end

-- tab 3 opens only with a powered medical monitor watch on the patient
-- (same rule and sandbox option as EHR's blood composition)
function EHR_HealthPanelUI:hmStatsUnlocked()
    return (not self:isMedicalWatchRequired()) or self:hasMedicalMonitorWatch()
end

function EHR_HealthPanelUI:hmDrawStatsLocked()
    local c = EHR_HealthPanelUI.Colors
    local b = self:getTabContentBounds()
    self:drawPanelFrame(b.x, b.y, b.w, b.h, L("Title", "BODY STATS"), nil)
    local iw, ih = 90, 110
    local cx = b.x + math.floor(b.w / 2)
    local iy = b.y + math.max(60, math.floor(b.h / 2) - 120)
    self:drawMedicalWatchIcon(cx - math.floor(iw / 2), iy, iw, ih)
    local lines = S.wrap(L("Locked", "The patient must wear a powered medical monitor watch (MedicalMonitorWatch, left or right wrist) to read the body stats and blood composition."), math.min(520, b.w - 60), FONT_M)
    local y = iy + ih + 14
    for _, l in ipairs(lines) do
        self:drawTextCentre(l, cx, y, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT_M)
        y = y + fh(FONT_M) + 2
    end
end

function EHR_HealthPanelUI:hmDrawStats()
    local c = EHR_HealthPanelUI.Colors
    if not self:hmStatsUnlocked() then return self:hmDrawStatsLocked() end
    -- blood composition on top (moved here from tab 1), stats below
    self:drawBloodCompositionPanel(self:getContentTop())
    local b = self:getTabContentBounds()
    local shift = self.BLOOD_PANEL_HEIGHT + 10
    b.y, b.h = b.y + shift, math.max(120, b.h - shift)
    local st = self.hmStats
    if not st or st.patient ~= patientOf(self) then self:hmStatsRequest(); st = self.hmStats end
    self:drawPanelFrame(b.x, b.y, b.w, b.h, L("Title", "BODY STATS"), nil)

    -- header: whose, when, refresh
    local mx, my = self:getLocalMousePosition()
    local who = patientOf(self)
    local name = who and (who.getDisplayName and who:getDisplayName() or (who.getUsername and who:getUsername())) or "?"
    local info = L("Snapshot", "%1 - snapshot of day %2", tostring(name), hoursText(st.at or 0))
    if st.waiting then info = info .. "  " .. L("Waiting", "(waiting for the patient...)") end
    local refresh = L("Refresh", "Refresh")
    local rw = tw(refresh) + 18
    local rx = b.x + b.w - rw - 14
    local ry = b.y + 6
    local rh = fh() + 8
    local hov = inside(mx, my, rx, ry, rw, rh)
    self:drawRect(rx, ry, rw, rh, hov and 0.9 or 0.6, c.accentDark.r, c.accentDark.g, c.accentDark.b)
    self:drawRectBorder(rx, ry, rw, rh, 1, c.accent.r, c.accent.g, c.accent.b)
    self:drawText(refresh, rx + 9, ry + 4, c.text.r, c.text.g, c.text.b, 1, FONT)
    st.refreshBtn = { x = rx, y = ry, w = rw, h = rh }
    local titleW = tw(L("Title", "BODY STATS"), FONT_M) + 40
    local infoMax = rx - (b.x + titleW) - 12
    if infoMax > 60 then
        self:drawText(S.fitText(info, infoMax, function(t) return tw(t) end), b.x + titleW, b.y + 9, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT)
    end

    -- group rows into two balanced columns
    local groups = {}
    for _, row in ipairs(st.rows or {}) do
        local g = row.g or "body"
        groups[g] = groups[g] or {}
        table.insert(groups[g], row)
    end
    local top, viewH = b.y + 48, b.h - 56
    local colW = math.floor((b.w - 28 - 18) / 2)
    local cols = { { x = b.x + 14, h = 0, items = {} }, { x = b.x + 14 + colW + 18, h = 0, items = {} } }
    local rowH = fh() + 7
    local headH = fh(FONT_M) + 8
    for _, gid in ipairs(St.GROUPS) do
        local rows = groups[gid]
        if rows and #rows > 0 then
            local col = cols[1].h <= cols[2].h and cols[1] or cols[2]
            col.items[#col.items + 1] = { g = gid, rows = rows }
            col.h = col.h + headH + #rows * rowH + 12
        end
    end
    if #(st.rows or {}) == 0 then
        self:drawText(st.waiting and L("Loading", "Loading...") or L("Empty", "No data."), b.x + 14, top + 6, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT_M)
    end
    st.scroll = st.scroll or 0
    self:setStencilRect(b.x + 2, top, b.w - 4, viewH)
    local contentH = 0
    st.tip = nil
    for _, col in ipairs(cols) do
        local y = top - st.scroll
        for _, item in ipairs(col.items) do
            self:drawText(L("Group_" .. item.g, item.g), col.x, y, c.accent.r, c.accent.g, c.accent.b, 1, FONT_M)
            y = y + headH
            self:drawRect(col.x, y - 4, colW, 1, 0.6, c.borderDim.r, c.borderDim.g, c.borderDim.b)
            for i, row in ipairs(item.rows) do
                if y + rowH >= top and y <= top + viewH then
                    if i % 2 == 0 then self:drawRect(col.x, y - 1, colW, rowH, 0.18, c.panelSoft.r, c.panelSoft.g, c.panelSoft.b) end
                    local value = tostring(row.s or row.v or "")
                    local valueW = tw(value)
                    local labelW = math.floor(colW * 0.45)
                    local lx = col.x + 6 + (row.indent or 0) * 14
                    if row.g == "moodles" then
                        -- icon, name, level pips (1..4) instead of a bar
                        drawMoodle(self, row, lx, y, rowH - 2)
                        lx = lx + rowH + 2
                        value, valueW = "", 0
                        local lv = math.max(0, math.min(4, row.lv or 0))
                        for k = 1, 4 do
                            local px = col.x + colW - 6 - (5 - k) * 10
                            local on = k <= lv
                            local pc = row.gb == 1 and c.green or (row.gb == 2 and c.red or c.textDim)
                            self:drawRect(px, y + math.floor(rowH / 2) - 3, 7, 7, on and 0.95 or 0.25, pc.r, pc.g, pc.b)
                        end
                    end
                    local labelText = rowLabel(row)
                    if row.g == "moodles" then labelW = colW - 50 end
                    local label = S.fitText(labelText, labelW - (lx - col.x), function(t) return tw(t) end)
                    -- abnormal (HM_Stats.markAbnormal): label and value red
                    local lc = row.bad and BAD or c.text
                    local vc = row.bad and BAD or c.textDim
                    if row.bad then self:drawRect(col.x, y - 1, 3, rowH, 0.9, BAD.r, BAD.g, BAD.b) end
                    self:drawText(label, lx, y + 2, lc.r, lc.g, lc.b, 1, FONT)
                    self:drawText(value, col.x + colW - 6 - valueW, y + 2, vc.r, vc.g, vc.b, 1, FONT)
                    if row.f then
                        local bx = col.x + labelW + 6
                        local bw = colW - labelW - valueW - 24
                        if bw > 20 then
                            local by = y + math.floor(rowH / 2) - 3
                            self:drawRect(bx, by, bw, 6, 0.6, 0.08, 0.07, 0.07)
                            local r, g, bl = barColor(row)
                            self:drawRect(bx, by, math.floor(bw * math.max(0, math.min(1, row.f))), 6, 0.95, r, g, bl)
                        end
                    end
                    if inside(mx, my, col.x, y, colW, rowH) and my >= top and my <= top + viewH then
                        st.tip = rowLabel(row) .. (value ~= "" and (": " .. value) or "")
                        if row.g == "signs" and row.tag then
                            st.tip = st.tip .. "\n" .. HM_Text("UI_HomeMedic_SignWhere_" .. row.tag, "")
                        elseif row.g == "moodles" then
                            st.tip = st.tip .. "\n" .. L("MoodleLevel", "Level %1 of 4", tostring(row.lv or 0))
                        end
                        if row.tip and row.tip ~= "" then st.tip = st.tip .. "\n" .. row.tip end
                    end
                end
                y = y + rowH
            end
            y = y + 12
        end
        contentH = math.max(contentH, y + st.scroll - top)
    end
    self:clearStencilRect()
    st.maxScroll = math.max(0, contentH - viewH)
    if st.scroll > st.maxScroll then st.scroll = st.maxScroll end
    if st.maxScroll > 0 then
        local barH = math.max(24, viewH * viewH / contentH)
        local barY = top + (viewH - barH) * (st.scroll / st.maxScroll)
        self:drawRect(b.x + b.w - 7, barY, 3, barH, 0.8, c.accent.r, c.accent.g, c.accent.b)
    end
end

EHR_HealthPanelUI.ExtraTabs = EHR_HealthPanelUI.ExtraTabs or {}
EHR_HealthPanelUI.ExtraTabs.stats = {
    open = function(panel) if panel:hmStatsUnlocked() then panel:hmStatsRequest() end end,
    draw = function(panel) panel:hmDrawStats() end,
    render = function(panel)
        local st = panel.hmStats
        if not st or not st.tip or st.tip == "" or not panel.drawDiagnosisTooltip then return end
        local keep = panel.dxState
        panel.dxState = { tip = st.tip }
        panel:drawDiagnosisTooltip()
        panel.dxState = keep
    end,
    wheel = function(panel, del)
        local st = panel.hmStats
        if not st or (st.maxScroll or 0) <= 0 then return false end
        st.scroll = math.max(0, math.min(st.maxScroll, st.scroll + del * 40))
        return true
    end,
    mouseDown = function(panel, x, y)
        local st = panel.hmStats
        local r = st and st.refreshBtn
        if r and panel:hmStatsUnlocked() and inside(x, y, r.x, r.y, r.w, r.h) then
            panel:hmStatsRequest()
            return true
        end
        return false
    end,
}

-- ============================================================= handbook tabs
-- the disease handbook (EHR_MedicalJournalUI) and the medication handbook
-- (HM_MedHandbookUI) as child views of their tabs
local function bookTab(field, class)
    local function bookFor(panel)
        local j = panel[field]
        if j then return j end
        local b = panel:getTabContentBounds()
        local reader = panel.getKnowledgePlayer and panel:getKnowledgePlayer() or panel.player
        j = class():new(b.x, b.y, b.w, b.h, reader, true)
        j:initialise()
        j:instantiate()
        j:setVisible(false)
        panel:addChild(j)
        panel[field] = j
        return j
    end
    return {
        open = function(panel)
            local j = bookFor(panel)
            j.player = panel.getKnowledgePlayer and panel:getKnowledgePlayer() or panel.player
            j:refreshEntries()
            -- "show this entry" (diagnosis result -> handbook)
            if panel.hmBookSelect and panel.hmBookSelect[field] then
                j:selectEntryId(panel.hmBookSelect[field])
                panel.hmBookSelect[field] = nil
            end
        end,
        draw = function(panel) end,
        sync = function(panel, shown)
            local j = panel[field]
            if not j then
                if not shown then return end
                j = bookFor(panel)
            end
            if shown then
                local b = panel:getTabContentBounds()
                if j:getX() ~= b.x or j:getY() ~= b.y then j:setX(b.x); j:setY(b.y) end
                if j:getWidth() ~= b.w then j:setWidth(b.w) end
                if j:getHeight() ~= b.h then j:setHeight(b.h) end
            end
            if j:isVisible() ~= shown then j:setVisible(shown) end
        end,
    }
end

EHR_HealthPanelUI.ExtraTabs.handbook = bookTab("hmJournal", function() return EHR_MedicalJournalUI end)
EHR_HealthPanelUI.ExtraTabs.meds = bookTab("hmMedBook", function() return HM_MedHandbookUI end)

-- J key / any "open the handbook": the medical window on its handbook tab
function EHR_MedicalJournalUI.Toggle(player)
    player = player or getSpecificPlayer(0)
    if not player or not EHR or not EHR.UI then return end
    local panel = EHR.UI.HealthPanelInstance
    if panel and panel:isVisible() and panel.activeTab == "handbook" then
        if EHR.UI.HideHealthPanel then EHR.UI.HideHealthPanel() end
        return
    end
    if EHR.UI.ShowHealthPanel then EHR.UI.ShowHealthPanel(player) end
    panel = EHR.UI.HealthPanelInstance
    if panel then panel:setActiveTab("handbook") end
end

function EHR_MedicalJournalUI.IsOpen()
    local panel = EHR and EHR.UI and EHR.UI.HealthPanelInstance
    return panel ~= nil and panel:isVisible() and panel.activeTab == "handbook"
end

EHR = EHR or {}
EHR.UI = EHR.UI or {}
EHR.UI.ToggleJournal = EHR_MedicalJournalUI.Toggle

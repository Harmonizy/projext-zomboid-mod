--[[
    HARMONIE - Home Medic : pin / unpin for the medical windows (client)

    Like the inventory window: a pin button in the header. Pinned (the
    default) the window stays as it is. Unpinned, it folds up to its header
    a moment after the mouse leaves it and unfolds when the mouse comes back.
    Used by the medical window (EHR_HealthPanelUI, also when examining
    someone) and the Medical Monitor (EHR_MedicalMonitorUI).
]]--

require "ISUI/ISButton"
require "ExtensiveHealth/EHR_HealthPanelUI"
require "ExtensiveHealth/EHR_MedicalMonitorUI"

HM_Pin = HM_Pin or {}
local P = HM_Pin
P.DELAY_MS = 350
P.SIZE = 20

local function nowMs() return getTimestampMs and getTimestampMs() or 0 end
local function tex(name)
    return getTexture and getTexture("media/textures/HARMONIE_HomeMedic/" .. name .. ".png") or nil
end
local function tip(pinned)
    local key = pinned and "UI_HomeMedic_Pin_Unpin" or "UI_HomeMedic_Pin_Pin"
    local t = getText and getText(key)
    if not t or t == key then t = pinned and "Unpin: fold up when the mouse leaves" or "Pin: keep the window open" end
    return t
end

local function refreshButton(panel)
    local b = panel.hmPinBtn
    if not b then return end
    local img = tex(panel.hmPinned and "pin_on" or "pin_off")
    if img then b:setImage(img); b:setTitle("") else b:setTitle(panel.hmPinned and "P" or "U") end
    b:setTooltip(tip(panel.hmPinned))
end

function P.toggle(panel)
    panel.hmPinned = not panel.hmPinned
    panel.hmLeaveAt = nil
    refreshButton(panel)
    if panel.hmPinned and panel.hmCollapsed then P.expand(panel) end
end

-- cfg: { header = fn(panel) -> h, place = fn(panel, button), keep = { field names } }
function P.ensure(panel, cfg)
    if panel.hmPinBtn then
        cfg.place(panel, panel.hmPinBtn)
        return
    end
    if panel.hmPinned == nil then panel.hmPinned = true end
    local w, h = cfg.size and cfg.size[1] or 24, cfg.size and cfg.size[2] or 22
    local b = ISButton:new(0, 0, w, h, "", panel, function(target) P.toggle(target) end)
    b:initialise()
    b:instantiate()
    -- same look as the window's other header buttons, so it is easy to spot
    local th = HM_Theme
    b.borderColor = th and th.button.border or { r = 0.35, g = 0.62, b = 0.95, a = 1 }
    b.backgroundColor = th and th.button.bg or { r = 0.03, g = 0.06, b = 0.10, a = 0.85 }
    b.backgroundColorMouseOver = th and th.button.over or { r = 0.08, g = 0.20, b = 0.36, a = 0.95 }
    b.forcedWidthImage = w - 6
    b.forcedHeightImage = h - 6
    panel:addChild(b)
    panel.hmPinBtn = b
    panel.hmPinCfg = cfg
    cfg.place(panel, b)
    refreshButton(panel)
end

local function kept(panel, child)
    if child == panel.hmPinBtn then return true end
    for _, f in ipairs(panel.hmPinCfg and panel.hmPinCfg.keep or {}) do
        if panel[f] == child then return true end
    end
    return false
end

function P.collapse(panel)
    if panel.hmCollapsed then return end
    local h = panel.hmPinCfg.header(panel)
    panel.hmFullH = panel.height
    panel.hmHidden = {}
    for _, child in pairs(panel.children or {}) do
        if child and not kept(panel, child) and child.isVisible and child:isVisible() then
            child:setVisible(false)
            panel.hmHidden[#panel.hmHidden + 1] = child
        end
    end
    panel.hmCollapsed = true
    panel:setHeight(h)
end

function P.expand(panel)
    if not panel.hmCollapsed then return end
    panel.hmCollapsed = false
    if panel.hmFullH then panel:setHeight(panel.hmFullH) end
    for _, child in ipairs(panel.hmHidden or {}) do child:setVisible(true) end
    panel.hmHidden = nil
    panel.hmLeaveAt = nil
end

local function mouseOver(panel)
    local mx, my = getMouseX(), getMouseY()
    local x, y = panel:getAbsoluteX(), panel:getAbsoluteY()
    return mx >= x and mx <= x + panel.width and my >= y and my <= y + panel.height
end

-- every frame, before the panel draws
function P.update(panel)
    if not panel.hmPinBtn then return end
    local busy = panel.dragging or panel.resizing or panel.moving
    if panel.hmPinned or busy then
        if panel.hmPinned and panel.hmCollapsed then P.expand(panel) end
        panel.hmLeaveAt = nil
        return
    end
    if mouseOver(panel) then
        panel.hmLeaveAt = nil
        if panel.hmCollapsed then P.expand(panel) end
    elseif not panel.hmCollapsed then
        panel.hmLeaveAt = panel.hmLeaveAt or nowMs()
        if nowMs() - panel.hmLeaveAt >= P.DELAY_MS then P.collapse(panel) end
    end
end

-- ------------------------------------------------------------- medical window
local HEALTH = {
    header = function(panel) return panel.HEADER_HEIGHT or 40 end,
    -- right side, just left of the -/+ (collapse / expand) button
    place = function(panel, b)
        b:setX(panel.width - 90)
        b:setY(math.floor(((panel.HEADER_HEIGHT or 40) - b.height) / 2))
    end,
    keep = { "closeButton", "expandButton", "antibodiesButton", "administerMedicationButton" },
}

local function installHealth()
    if not EHR_HealthPanelUI or EHR_HealthPanelUI.hmPinInstalled then return end
    EHR_HealthPanelUI.hmPinInstalled = true
    local origPre = EHR_HealthPanelUI.prerender
    function EHR_HealthPanelUI:prerender()
        P.ensure(self, HEALTH)
        P.update(self)
        if self.hmCollapsed then
            ISPanel.prerender(self)
            if self.closeRemoteExamIfOutOfRange and self:closeRemoteExamIfOutOfRange() then return end
            self:drawHeader()
            return
        end
        origPre(self)
    end
    local origRender = EHR_HealthPanelUI.render
    function EHR_HealthPanelUI:render()
        if self.hmCollapsed then return end
        origRender(self)
    end
    local origDown = EHR_HealthPanelUI.onMouseDown
    function EHR_HealthPanelUI:onMouseDown(x, y)
        if self.hmCollapsed and y > (self.HEADER_HEIGHT or 40) then return false end
        return origDown(self, x, y)
    end
    -- a window that was folded up opens unfolded
    local origShow = EHR.UI and EHR.UI.ShowHealthPanel
    if origShow then
        EHR.UI.ShowHealthPanel = function(player)
            origShow(player)
            local panel = EHR.UI.HealthPanelInstance
            if panel and panel.hmCollapsed then P.expand(panel) end
        end
    end
end

-- ------------------------------------------------------------- medical monitor
local MONITOR = {
    size = { 20, 20 },
    header = function(panel) return panel.HEADER_HEIGHT or 30 end,
    place = function(panel, b)
        b:setX(panel.width - 75)
        b:setY(panel.HEADER_BUTTON_Y or 3)
    end,
    keep = { "closeBtn", "toggleBtn" },
}

local function installMonitor()
    if not EHR_MedicalMonitorUI or EHR_MedicalMonitorUI.hmPinInstalled then return end
    EHR_MedicalMonitorUI.hmPinInstalled = true
    local origPre = EHR_MedicalMonitorUI.prerender
    function EHR_MedicalMonitorUI:prerender()
        P.ensure(self, MONITOR)
        P.update(self)
        origPre(self)
    end
    local origRender = EHR_MedicalMonitorUI.render
    function EHR_MedicalMonitorUI:render()
        if self.hmCollapsed then ISPanel.render(self); return end
        origRender(self)
    end
    local origAdaptive = EHR_MedicalMonitorUI.updateAdaptiveHeight
    if origAdaptive then
        function EHR_MedicalMonitorUI:updateAdaptiveHeight()
            if self.hmCollapsed then return end
            return origAdaptive(self)
        end
    end
    local origToggle = EHR_MedicalMonitorUI.onToggleExpand
    if origToggle then
        function EHR_MedicalMonitorUI:onToggleExpand()
            if self.hmCollapsed then P.expand(self) end
            return origToggle(self)
        end
    end
end

installHealth()
installMonitor()
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(installHealth)
    Events.OnGameStart.Add(installMonitor)
end

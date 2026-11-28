--[[
    HARMONIE Hub: action bar (Hub 5.3, owner 2026-11-24):
      "while doing something I can't tell whether it is done -- our tab
       covers the vanilla progress bar. A progress bar in the tab, or
       anything that tells me it is being done, has started, and is done."

    While ANY of our windows is open and your character runs a timed action,
    a small bar sits at the top centre of the screen (above the windows):
      Doing: <action>   [=====-----] 48%
    When it ends it shows for 2 s:
      Done: <action>    (green)   -- it reached the end
      Stopped: <action> (orange)  -- it ended before the end (moved, cancelled)
    The name is IGUI_HUB_Act_<action class> when we have one, else the
    class name made readable ("ISApplyBandage" -> "Apply Bandage").
    Draws only; it never starts, stops or changes an action. Clicks fall
    through (every mouse handler returns false).
]]--

require "ISUI/ISUIElement"

HARMONIE_ActionBar = HARMONIE_ActionBar or {}
local AB = HARMONIE_ActionBar
AB.W, AB.H = 360, 38
AB.SHOW_END_MS = 2000

local function now() return getTimestampMs and getTimestampMs() or 0 end
local function log(fmt, ...) print(string.format("[HARMONIE_Hub][ActionBar] " .. fmt, ...)) end

-- is one of our windows open?
local function vis(w)
    if not w then return false end
    local ok, v = pcall(function() return w:getIsVisible() end)
    return ok and v == true
end
function AB.anyOpen()
    if GTPGuide and vis(GTPGuide.window) then return true end
    if TWACraftUI and vis(TWACraftUI.window) then return true end
    if EHR and EHR.UI and vis(EHR.UI.HealthPanelInstance) then return true end
    if HSVU and vis(HSVU.window) then return true end
    if HMLWorkbench and vis(HMLWorkbench.instance) then return true end
    if HARMONIE_InvHelper and vis(HARMONIE_InvHelper.window) then return true end
    if LWSWindow and LWSWindow.isOpen then
        local ok, o = pcall(LWSWindow.isOpen)
        if ok and o then return true end
    end
    return false
end

local nameCache = {}
function AB.nameOf(action)
    local t = action and action.Type or "?"
    if nameCache[t] then return nameCache[t] end
    local key = "IGUI_HUB_Act_" .. tostring(t)
    local txt = getText and getText(key)
    if not txt or txt == key then
        local s = tostring(t):gsub("^IS", ""):gsub("^HM_", ""):gsub("^TWA_", ""):gsub("Action$", "")
        s = s:gsub("_", " "):gsub("(%l)(%u)", "%1 %2")
        txt = s
    end
    nameCache[t] = txt
    return txt
end

local function current(p)
    local ok, q = pcall(function() return ISTimedActionQueue.getTimedActionQueue(p) end)
    local a = ok and q and q.queue and q.queue[1] or nil
    return a
end
local function deltaOf(a)
    local d
    pcall(function() d = a.action and a.action:getJobDelta() end)
    return tonumber(d)
end

AB.Panel = ISUIElement:derive("HARMONIE_ActionBarPanel")
local P = AB.Panel

function P:new()
    local o = ISUIElement.new(self, 0, 0, AB.W, AB.H)
    o.anchorLeft, o.anchorTop = true, true
    return o
end
function P:onMouseDown() return false end
function P:onMouseUp() return false end
function P:onRightMouseDown() return false end
function P:onRightMouseUp() return false end
function P:onMouseMove() return false end
function P:onMouseWheel() return false end
function P:isMouseOver() return false end

function P:prerender()
    -- follow the screen size; sit at the top centre
    local sw = getCore():getScreenWidth()
    local x = math.floor((sw - AB.W) / 2)
    if self:getX() ~= x then self:setX(x) end
    if self:getY() ~= 6 then self:setY(6) end
end

function P:render()
    local ok, err = pcall(self.drawBar, self)
    if not ok and not self.errLogged then
        self.errLogged = true
        log("draw error: %s", tostring(err))
    end
end

function P:drawBar()
    local p = getSpecificPlayer and getSpecificPlayer(0)
    if not p then return end
    local a = current(p)
    local t = now()
    if a ~= self.cur then
        -- the last one ended
        if self.cur then
            local done = (self.lastDelta or 0) >= 0.95
            self.ending = { name = self.curName, done = done, at = t }
        end
        self.cur = a
        self.curName = a and AB.nameOf(a) or nil
        self.lastDelta = 0
    end
    if not AB.anyOpen() then return end
    local f = UIFont.Small
    local tm = getTextManager()
    if a then
        local d = deltaOf(a)
        if d then self.lastDelta = d end
        self:drawRect(0, 0, AB.W, AB.H, 0.85, 0.05, 0.06, 0.08)
        self:drawRectBorder(0, 0, AB.W, AB.H, 0.9, 0.85, 0.7, 0.3)
        local label = getText("IGUI_HUB_Act_Doing", self.curName or "?")
        self:drawText(label, 10, 4, 1, 0.92, 0.75, 1, f)
        local bx, by, bw, bh = 10, AB.H - 13, AB.W - 60, 7
        self:drawRect(bx, by, bw, bh, 0.9, 0.15, 0.15, 0.18)
        local frac = math.max(0, math.min(1, d or 0))
        if d then
            self:drawRect(bx, by, math.floor(bw * frac), bh, 1, 0.45, 0.85, 0.40)
            local pct = tostring(math.floor(frac * 100 + 0.5)) .. "%"
            self:drawText(pct, AB.W - 10 - tm:MeasureStringX(f, pct), by - 5, 0.9, 0.9, 0.9, 1, f)
        else
            -- no progress reported (e.g. walking to something): a moving block
            local k = (t % 1200) / 1200
            self:drawRect(bx + math.floor((bw - 40) * k), by, 40, bh, 1, 0.85, 0.7, 0.3)
        end
    elseif self.ending and t - self.ending.at < AB.SHOW_END_MS then
        local e = self.ending
        self:drawRect(0, 0, AB.W, AB.H, 0.85, 0.05, 0.06, 0.08)
        local col = e.done and { 0.45, 0.9, 0.45 } or { 1, 0.65, 0.25 }
        self:drawRectBorder(0, 0, AB.W, AB.H, 0.9, col[1], col[2], col[3])
        local label = getText(e.done and "IGUI_HUB_Act_Done" or "IGUI_HUB_Act_Stopped", e.name or "?")
        self:drawText(label, 10, math.floor((AB.H - tm:getFontHeight(f)) / 2), col[1], col[2], col[3], 1, f)
    end
end

function AB.install()
    if AB.panel then return end
    local ok, err = pcall(function()
        local pnl = P:new()
        pnl:initialise()
        pnl:addToUIManager()
        pnl:setAlwaysOnTop(true)
        AB.panel = pnl
    end)
    log(ok and "installed (top of the screen while one of our windows is open)" or ("NOT installed: " .. tostring(err)))
end

if Events and Events.OnGameStart then Events.OnGameStart.Add(AB.install) end

--[[
    HARMONIE - Mercenary Is Life: the gun workbench (client), phase 2.

    Owner, 2026-10-09: "สร้างหน้าต่างสีแดง ที่มี layout เดียวกับ ehr ที่เป็นหน้าต่าง
    มีหลายแท็บและฟังก์ชันส่วนต่างๆ แต่อันนี้เป็นการปรับปรุงดัดแปลงปืนและชิ้นส่วนแบบ 3D
    โดยเอา UI 3D ทุกประการของทางม็อดอ้างอิงมาใส่ในหน้าต่างเลย"

    One red window in How to Survive's layout (a header with the title, the
    tabs and the close button; the content framed below):
      1 inspect   the original mod's whole 3D inspect view, as it is (the 3D
                  gun and its parts, the part slots around it, the stat bars,
                  ammo / repair kit / part-position buttons) -- the original
                  panel (riskyUI) lives inside this tab
      2 stats     every number of the gun in hand: now, base, what the parts add
      3 parts     every part slot: what is on it (remove), what fits from the
                  bags and containers around you (install -- the original's
                  own picker)
      4 ammo      ammunition, boxes, magazines that fit, what is loaded
      5 guide     how all of it works

    Every way the original opened its inspect window (right-click > Inspect,
    the inspect key, the Inspect timed action, the HARMONIE tab) goes through
    MFSInspectFix.open, which opens this window instead.

    The original's code finds its window through the global
    riskyInspectWindow (placing its part picker next to a slot, redrawing
    after a part is attached). While this window is open that global is a
    small stand-in that forwards everything to the embedded panel but
    answers getX / getY with the panel's place on the screen.

    console.txt: [HARMONIE_MFSFix] workbench open / close / tab / actions,
    every failure (nothing per frame).
]]--

require "ISUI/ISPanel"
require "ISUI/ISButton"

HMLWorkbench = ISPanel:derive("HMLWorkbench")
local W = HMLWorkbench
W.VERSION = 1
W.HEADER_H = 40
W.TAB_H = 58
W.CARD_T = 26
W.PANE_W, W.PANE_H = 1298, 716      -- the original inspect panel's own size
W.TABS = {
    { id = "inspect", icon = "tab_inspect", key = "IGUI_MIL_Tab_inspect", tip = "IGUI_MIL_Tab_inspect_Tip" },
    { id = "stats", icon = "tab_stats", key = "IGUI_MIL_Tab_stats", tip = "IGUI_MIL_Tab_stats_Tip" },
    { id = "parts", icon = "tab_parts", key = "IGUI_MIL_Tab_parts", tip = "IGUI_MIL_Tab_parts_Tip" },
    { id = "ammo", icon = "tab_ammo", key = "IGUI_MIL_Tab_ammo", tip = "IGUI_MIL_Tab_ammo_Tip" },
    { id = "guide", icon = "tab_guide", key = "IGUI_MIL_Tab_guide", tip = "IGUI_MIL_Tab_guide_Tip" },
}
-- tabs that need a gun in the main hand (owner, 2026-10-09: "ทุกหน้าต่างสามารถ
-- เปิดได้ แต่แท็บไหนในแต่ละหน้าต่างที่ต้องการคลิกขวา ก็ให้ล็อกแค่แท็บนั้น"): without
-- one the window still opens, on the guide, with these tabs locked
W.NEEDS_GUN = { inspect = true, stats = true, parts = true, ammo = true }
-- red theme (How to Survive's palette turned red); the frame, tab row,
-- cards, pin and text size are the same as Car for Crash's and How to
-- Survive's windows
W.C = {
    accent = { 0.92, 0.24, 0.20 }, accentDark = { 0.26, 0.04, 0.04 },
    background = { 0.035, 0.012, 0.014, 0.97 }, panel = { 0.075, 0.025, 0.028, 0.94 },
    header = { 0.07, 0.018, 0.02, 0.98 }, border = { 0.82, 0.22, 0.20 }, borderDim = { 0.40, 0.10, 0.10 },
    text = { 0.97, 0.92, 0.91 }, textDim = { 0.74, 0.62, 0.61 }, good = { 0.45, 0.92, 0.45 }, bad = { 1.0, 0.42, 0.38 }, warn = { 1.0, 0.80, 0.32 },
    row = { 0.11, 0.035, 0.04 }, rowAlt = { 0.085, 0.028, 0.032 },
    card = { 0.10, 0.03, 0.035, 0.93 }, tabRow = { 0.05, 0.012, 0.016 },
}

-- ----------------------------------------------------------------- log
local function fmt(f, ...)
    local ok, s = pcall(string.format, f, ...)
    return ok and s or tostring(f)
end
local function log(f, ...) print("[HARMONIE_MFSFix] workbench: " .. fmt(f, ...)) end
local once = {}
local function logOnce(key, f, ...)
    if once[key] then return end
    once[key] = true
    log(f, ...)
end
W.log = log

local function T(key, ...)
    local ok, s
    if select("#", ...) > 0 then ok, s = pcall(getText, key, ...) else ok, s = pcall(getText, key) end
    return (ok and s) or key
end
local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
local tex = {}
local function texture(name)
    if tex[name] == nil then
        tex[name] = getTexture("media/textures/MIL_UI/" .. name .. ".png") or false
        if not tex[name] then logOnce("tex:" .. name, "texture MIL_UI/%s.png did not load", name) end
    end
    return tex[name] or nil
end
local function itemName(item)
    local n = call(item, "getDisplayName")
    return n and tostring(n) or "?"
end
local function fullType(item)
    local n = call(item, "getFullType")
    return n and tostring(n) or "?"
end

-- ----------------------------------------------------------------- data (no UI; tested)
function W.slots()
    return (AWCWF_AdditionalParts and AWCWF_AdditionalParts.partlist) or
        { "Scope", "Canon", "Stock", "Grip", "Laser", "Light", "Stool", "R_Scope", "L_Scope", "Sling", "RecoilPad", "Barrel", "Misc" }
end

W.baseCache = {}
local function baseOf(weapon)
    local ft = fullType(weapon)
    if W.baseCache[ft] == nil then
        local ok, it = pcall(instanceItem, ft)
        W.baseCache[ft] = (ok and it) or false
    end
    return W.baseCache[ft] or nil
end

-- each stat: label key, getter, lower-is-better
W.STATS = {
    { key = "IGUI_WeaponUI_DamegeMin", get = "getMinDamage" },
    { key = "IGUI_WeaponUI_DamegeMax", get = "getMaxDamage" },
    { key = "IGUI_WeaponUI_RangeMin", get = "getMinRange" },
    { key = "IGUI_WeaponUI_RangeMax", get = "getMaxRange" },
    { key = "IGUI_WeaponUI_CriticalChance", get = "getCriticalChance" },
    { key = "IGUI_MIL_CritDamage", get = "getCriticalDamageMultiplier" },
    { key = "IGUI_WeaponUI_HitChance", get = "getHitChance" },
    { key = "IGUI_WeaponUI_AimingTime", get = "getAimingTime", lowerBetter = true },
    { key = "IGUI_WeaponUI_ReloadTime", get = "getReloadTime", lowerBetter = true },
    { key = "IGUI_WeaponUI_RecoilDelayModifier", get = "getRecoilDelay", lowerBetter = true },
    { key = "IGUI_WeaponUI_MaxHitCount", get = "getMaxHitCount" },
    { key = "IGUI_WeaponUI_Sound", get = "getSoundRadius", lowerBetter = true },
    { key = "IGUI_WeaponUI_Weight", get = "getActualWeight", baseGet = "getWeight", lowerBetter = true },
    { key = "IGUI_WeaponUI_ClipNow", get = "getMaxAmmo" },
    { key = "IGUI_MIL_Projectiles", get = "getProjectileCount" },
}

local function num(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

-- the gun's numbers: { {key, now, base, delta, better} }
function W.statRows(weapon)
    local base = baseOf(weapon)
    local rows = {}
    for _, s in ipairs(W.STATS) do
        local now = num(call(weapon, s.get))
        if now then
            local b = num(call(base, s.baseGet or s.get)) or now
            local d = now - b
            local better = nil
            if math.abs(d) > 0.0001 then
                better = (d > 0) ~= (s.lowerBetter == true)
            end
            rows[#rows + 1] = { key = s.key, now = now, base = b, delta = d, better = better }
        end
    end
    return rows
end

function W.fmtNum(v)
    if not v then return "--" end
    if math.abs(v - math.floor(v + 0.5)) < 0.005 then return tostring(math.floor(v + 0.5)) end
    return string.format("%.2f", v)
end

-- parts that fit `slot` of `weapon` within reach (the original's own scan)
function W.partsFor(player, weapon, slot)
    local found = {}
    if not (scanParts and getReachableContainers) then
        logOnce("noscan", "the original's part scan (scanParts / getReachableContainers) is missing -- no part lists")
        return found
    end
    local ok, err = pcall(function()
        local visited = {}
        for _, c in ipairs(getReachableContainers(player)) do scanParts(c, player, weapon, slot, found, visited) end
    end)
    if not ok then logOnce("scanfail:" .. slot, "scanning parts for %s FAILED: %s", slot, tostring(err)) end
    return found
end

-- every slot: { slot, part (or nil), fits = n }
function W.partRows(player, weapon)
    local rows = {}
    for _, slot in ipairs(W.slots()) do
        if slot ~= "Clip" and slot ~= "Hide_Beam" then
            local part = call(weapon, "getWeaponPart", slot)
            rows[#rows + 1] = { slot = slot, part = part, fits = #W.partsFor(player, weapon, slot) }
        end
    end
    return rows
end

-- ammunition: { ammoName, loose, boxName, boxes, magName, loaded, max }
function W.ammoInfo(player, weapon)
    local info = { loaded = num(call(weapon, "getCurrentAmmoCount")) or 0, max = num(call(weapon, "getMaxAmmo")) or 0 }
    local inv = call(player, "getInventory")
    local at = call(weapon, "getAmmoType")
    local key = at and call(at, "getItemKey")
    if key then
        local ok, it = pcall(instanceItem, key)
        info.ammoName = ok and it and itemName(it) or tostring(key)
        info.ammoItem = ok and it or nil
        info.loose = num(call(inv, "getItemCountRecurse", key)) or 0
    end
    local box = call(weapon, "getAmmoBox")
    if box then
        local ok, it = pcall(instanceItem, box)
        info.boxName = ok and it and itemName(it) or tostring(box)
        info.boxItem = ok and it or nil
        info.boxes = num(call(inv, "getItemCountRecurse", box)) or 0
    end
    local mag = call(weapon, "getMagazineType")
    if mag then
        local ok, it = pcall(instanceItem, mag)
        info.magName = ok and it and itemName(it) or tostring(mag)
        info.magItem = ok and it or nil
        info.mags = num(call(inv, "getItemCountRecurse", mag)) or 0
    end
    return info
end

-- ----------------------------------------------------------------- the embedded original panel
-- made the first time the window opens: this file loads before the
-- original's UI files (client/H... < client/UI/...), so riskyUI does not
-- exist yet at load time
function W.paneClass()
    if HMLInspectPane then return HMLInspectPane end
    if not riskyUI then return nil end
    HMLInspectPane = riskyUI:derive("HMLInspectPane")
    local P = HMLInspectPane
    -- the original background, tinted red
    function P:prerender()
        local orig = self.drawTextureScaled
        local bg = getTexture("media/textures/UI/EFK_BackGround.png")
        self.drawTextureScaled = function(s, t, x, y, w, h, a, r, g, b)
            if t == bg then return orig(s, t, x, y, w, h, a, 0.62, 0.22, 0.22) end
            return orig(s, t, x, y, w, h, a, r, g, b)
        end
        local ok, err = pcall(riskyUI.prerender, self)
        self.drawTextureScaled = orig
        if not ok then logOnce("paneprerender", "inspect tab draw FAILED: %s", tostring(err)) end
        -- our header has the close button
        if self.closebutton then self.closebutton:setVisible(false) end
    end
    -- the part-position sliders open left of the whole window
    local function openSliders(self)
        if riskyUI_slider and riskyUI_slider.instance then
            pcall(function() riskyUI_slider.instance:close() end)
            riskyUI_slider.instance = nil
        end
        local width = math.floor(self.width / 3)
        local x = math.max(0, self:getAbsoluteX() - width)
        self.settingpanel = riskyUI_slider:new(x, self:getAbsoluteY(), width, self.height, self)
        self.settingpanel:initialise()
        riskyUI_slider.instance = self.settingpanel
        self.settingpanel:addToUIManager()
    end
    P.openSettingPanel = openSliders
    P.reopenSettingPanel = openSliders
    -- the original closes itself when the gun leaves the hand, on a swing, on
    -- its key: then the whole workbench closes
    function P:close()
        pcall(riskyUI.close, self)
        if self.workbench and not self.workbench.closing then self.workbench:close() end
    end
    return P
end

-- what the original's code sees as riskyInspectWindow
local function makeProxy(pane)
    local proxy = { __hmlProxy = true, pane = pane }
    setmetatable(proxy, { __index = function(_, k)
        if k == "getX" then return function() return pane:getAbsoluteX() end end
        if k == "getY" then return function() return pane:getAbsoluteY() end end
        local v = pane[k]
        if type(v) == "function" then return function(_, ...) return v(pane, ...) end end
        return v
    end })
    return proxy
end

-- ----------------------------------------------------------------- prefs
-- (this computer only: Zomboid/Lua/HARMONIE_MIL_Window.txt, like Car for
-- Crash's and How to Survive's windows)
W.PREFS_FILE = "HARMONIE_MIL_Window.txt"
W.pinned = true
W.textStep = 0
function W.ensurePrefs()
    if W.prefsLoaded then return end
    W.prefsLoaded = true
    if not getFileReader then return end
    local ok, reader = pcall(getFileReader, W.PREFS_FILE, true)
    if not ok or not reader then return end
    pcall(function()
        local line = reader:readLine()
        while line do
            local k, v = line:match("^%s*([%w_]+)%s*=%s*(%S+)")
            if k == "text" then W.textStep = math.max(0, math.min(2, math.floor(tonumber(v) or 0)))
            elseif k == "pinned" then W.pinned = v ~= "0" end
            line = reader:readLine()
        end
    end)
    pcall(function() reader:close() end)
    log("prefs loaded: text step %s, pinned %s", tostring(W.textStep), tostring(W.pinned))
end
function W.savePrefs()
    if not getFileWriter then return end
    local ok, writer = pcall(getFileWriter, W.PREFS_FILE, true, false)
    if not ok or not writer then log("could not write %s: %s", W.PREFS_FILE, tostring(writer)); return end
    pcall(function()
        writer:write("text=" .. tostring(W.textStep) .. "\n")
        writer:write("pinned=" .. (W.pinned and "1" or "0") .. "\n")
    end)
    pcall(function() writer:close() end)
end
local FONTS = { "Small", "Medium", "Large" }
local function fontAt(level)
    level = math.max(1, math.min(#FONTS, level))
    return UIFont[FONTS[level]] or UIFont.Small
end
function W.small() return fontAt(1 + W.textStep) end
function W.medium() return fontAt(2 + W.textStep) end
function W.stepText(d)
    W.textStep = math.max(0, math.min(2, W.textStep + d))
    log("text size step: %d", W.textStep)
    W.savePrefs()
end

-- ----------------------------------------------------------------- window
function W.contentTop() return W.HEADER_H + W.TAB_H + 6 end

function W:new(player, weapon)
    W.ensurePrefs()
    -- the 3D tab holds the original panel at its own fixed size, so the
    -- window is that size plus the frame
    local w = W.PANE_W + 8
    local h = W.contentTop() + W.PANE_H + 4
    local x, y = 100, 100
    if MFSInspectFix and MFSInspectFix.ensurePosition then x, y = MFSInspectFix.ensurePosition(player) end
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.weapon = weapon
    o.moveWithMouse = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.tab = weapon and "inspect" or "guide"
    o.scroll = 0
    o.guidePage = 1
    o.buttons = {}
    o.fullH = h
    return o
end

function W:createChildren()
    ISPanel.createChildren(self)
    -- 1: the original panel, inside the content frame (needs a gun)
    local Pane = self.weapon and W.paneClass() or nil
    if not self.weapon then
        log("opened without a gun: the gun tabs are locked")
    elseif Pane then
        local ok, pane = pcall(function() return Pane:new(4, W.contentTop(), 0, 0) end)
        if ok and pane then
            pane.workbench = self
            pane.moveWithMouse = false
            self.pane = pane
            self:addChild(pane)
            riskyInspectWindow = makeProxy(pane)
            local okR, err = pcall(function() pane:renderInventory() end)
            if not okR then log("the 3D inspect view FAILED to build: %s", tostring(err)) end
            pane:setX(4); pane:setY(W.contentTop())
        else
            log("the 3D inspect view could not be created: %s", tostring(pane))
        end
    else
        logOnce("noriskyui", "the original inspect panel (riskyUI) is missing -- the inspect tab is empty")
    end
end

function W:locked(id) return W.NEEDS_GUN[id] == true and self.weapon == nil end

function W:setTab(id)
    if self.tab == id then return end
    if self:locked(id) then
        log("tab %s is locked: no gun in the main hand", tostring(id))
        pcall(function() getSoundManager():playUISound("UIDeactivate") end)
        self.lockFlashAt = getTimestampMs and getTimestampMs() or 0
        return
    end
    log("tab %s -> %s", tostring(self.tab), tostring(id))
    self.tab = id
    self.scroll = 0
    if self.pane then self.pane:setVisible(id == "inspect" and not self.collapsed) end
    if id ~= "inspect" and riskyUI_slider and riskyUI_slider.instance then
        pcall(function() riskyUI_slider.instance:close() end)
        riskyUI_slider.instance = nil
    end
    pcall(function() getSoundManager():playUISound("UISelectListItem") end)
end

function W:close()
    if self.closing then return end
    self.closing = true
    if MFSInspectFix and MFSInspectFix.rememberPosition then MFSInspectFix.rememberPosition(self, self.player) end
    if self.pane then pcall(function() self.pane:close() end) end
    if riskyUI_slider and riskyUI_slider.instance then
        pcall(function() riskyUI_slider.instance:close() end)
        riskyUI_slider.instance = nil
    end
    if type(riskyInspectWindow) == "table" and riskyInspectWindow.__hmlProxy and riskyInspectWindow.pane == self.pane then
        riskyInspectWindow = nil
    end
    self:setVisible(false)
    self:removeFromUIManager()
    if W.instance == self then W.instance = nil end
    log("closed")
end

function W:update()
    ISPanel.update(self)
    if self.closing then return end
    local held = call(self.player, "getPrimaryHandItem")
    if self.weapon == nil then
        -- opened without a gun: when one is taken in hand, reopen with it
        local Fix = MFSInspectFix
        if held and Fix and Fix.getInspectableWeapon and Fix.getInspectableWeapon(self.player) then
            log("a gun was taken in hand -- reopening with it")
            local p = self.player
            self:close()
            W.open(p)
        end
        return
    end
    if held ~= self.weapon then
        log("the gun left the hand -- closing")
        self:close()
    end
end

-- ----------------------------------------------------------------- pin
-- unpinned, the window folds up to its header a moment after the mouse
-- leaves it and unfolds when the mouse comes back (How to Survive's pin)
W.FOLD_DELAY_MS = 350
function W:togglePin()
    W.pinned = not W.pinned
    log("pinned: %s", tostring(W.pinned))
    self.leaveAt = nil
    if W.pinned then self:expand() end
    W.savePrefs()
end
function W:collapse()
    if self.collapsed then return end
    -- never fold while the original's part picker or sliders are in use
    if riskyUI_slider and riskyUI_slider.instance then return end
    self.collapsed = true
    self:setHeight(W.HEADER_H)
    if self.pane then self.pane:setVisible(false) end
end
function W:expand()
    if not self.collapsed then return end
    self.collapsed = false
    self:setHeight(self.fullH)
    if self.pane then self.pane:setVisible(self.tab == "inspect") end
    self.leaveAt = nil
end
function W:updatePin()
    if W.pinned or self.moving then
        if W.pinned then self:expand() end
        self.leaveAt = nil
        return
    end
    local mx, my = getMouseX(), getMouseY()
    local x, y = self:getAbsoluteX(), self:getAbsoluteY()
    local over = mx >= x and mx <= x + self.width and my >= y and my <= y + self.height
    local now = getTimestampMs and getTimestampMs() or 0
    if over then
        self.leaveAt = nil
        self:expand()
    elseif not self.collapsed then
        self.leaveAt = self.leaveAt or now
        if now - self.leaveAt >= W.FOLD_DELAY_MS then self:collapse() end
    end
end

-- ----------------------------------------------------------------- drawing
local function fh(font) return getTextManager():getFontHeight(font) end
local function lineH(font) return fh(font) + 2 end
local function tw(font, s) return getTextManager():MeasureStringX(font, s) end
local function inside(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end
local function shadowText(panel, s, x, y, c, a, font)
    a = a or 1
    panel:drawText(s, x + 1, y + 1, 0, 0, 0, a * 0.8, font)
    panel:drawText(s, x, y, c[1], c[2], c[3], a, font)
end
local function fit(s, maxW, font)
    s = tostring(s or "")
    if tw(font, s) <= maxW then return s end
    while #s > 1 and tw(font, s .. "...") > maxW do s = s:sub(1, -2) end
    return s .. "..."
end
local function wrap(text, maxW, font)
    local out = {}
    for para in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in para:gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            if tw(font, try) > maxW and line ~= "" then out[#out + 1] = line; line = word else line = try end
        end
        out[#out + 1] = line
    end
    return out
end

-- header buttons, right to left: close, pin, A+, A-
function W:headerButtons()
    local s = 26
    local y = math.floor((W.HEADER_H - s) / 2)
    local x = self.width - s - 8
    local b = {}
    for _, id in ipairs({ "close", "pin", "plus", "minus" }) do
        b[#b + 1] = { id = id, x = x, y = y, w = s, h = s }
        x = x - s - 6
    end
    return b
end

-- a card: title strip, accent corners (the same card as the other windows)
function W:drawCard(x, y, w, h, title)
    local C = W.C
    self:drawRect(x, y, w, h, C.card[4], C.card[1], C.card[2], C.card[3])
    self:drawRectBorder(x, y, w, h, 0.75, C.borderDim[1], C.borderDim[2], C.borderDim[3])
    local th = W.CARD_T
    self:drawRect(x + 1, y + 1, w - 2, th - 1, 0.6, C.accentDark[1], C.accentDark[2], C.accentDark[3])
    self:drawRect(x + 6, y + th - 1, w - 12, 1, 0.8, C.border[1], C.border[2], C.border[3])
    local k = 9
    for _, c in ipairs({ { x, y, 1, 1 }, { x + w, y, -1, 1 }, { x, y + h, 1, -1 }, { x + w, y + h, -1, -1 } }) do
        local cx, cy, dx, dy = c[1], c[2], c[3], c[4]
        self:drawRect(dx > 0 and cx or cx - k, dy > 0 and cy or cy - 2, k, 2, 0.95, C.accent[1], C.accent[2], C.accent[3])
        self:drawRect(dx > 0 and cx or cx - 2, dy > 0 and cy or cy - k, 2, k, 0.95, C.accent[1], C.accent[2], C.accent[3])
    end
    if title and title ~= "" then
        local font = W.small()
        self:drawRect(x + 8, y + math.floor((th - 8) / 2), 3, 8, 1, C.accent[1], C.accent[2], C.accent[3])
        shadowText(self, fit(title, w - 24, font), x + 16, y + math.floor((th - fh(font)) / 2), C.accent, 1, font)
    end
    return x + 10, y + th + 6, w - 20, h - th - 12
end

function W:button(x, y, w, h, label, fn, enabled)
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = mx >= x and mx <= x + w and my >= y and my <= y + h
    enabled = enabled ~= false
    local C = W.C
    local font = W.small()
    self:drawRect(x, y, w, h, enabled and (over and 0.98 or 0.85) or 0.4, C.accentDark[1], C.accentDark[2], C.accentDark[3])
    if enabled and over then self:drawRect(x + 2, y + 2, w - 4, h - 4, 0.18, C.accent[1], C.accent[2], C.accent[3]) end
    self:drawRectBorder(x, y, w, h, enabled and (over and 1 or 0.8) or 0.4, C.border[1], C.border[2], C.border[3])
    label = fit(label, w - 8, font)
    shadowText(self, label, x + math.floor((w - tw(font, label)) / 2), y + math.floor((h - fh(font)) / 2), enabled and C.text or C.textDim, 1, font)
    if enabled then self.buttons[#self.buttons + 1] = { x = x, y = y, w = w, h = h, fn = fn } end
end

function W:prerender()
    local C = W.C
    local hh, th = W.HEADER_H, W.TAB_H
    self.buttons = {}
    self.hoverTip = nil
    self:drawRect(0, 0, self.width, self.height, C.background[4], C.background[1], C.background[2], C.background[3])
    self:drawRectBorder(0, 0, self.width, self.height, 1, C.border[1], C.border[2], C.border[3])
    self:drawRect(1, 1, self.width - 2, hh - 1, C.header[4], C.header[1], C.header[2], C.header[3])
    self:drawRect(0, hh - 1, self.width, 1, 0.8, C.border[1], C.border[2], C.border[3])
    -- title
    local font = W.medium()
    local ix = 10
    local logo = texture("emblem")
    if logo then
        self:drawTextureScaled(logo, ix, math.floor((hh - 28) / 2), 28, 28, 1, 1, 1, 1)
        ix = ix + 34
    end
    local title = self.weapon and (T("IGUI_MIL_Title") .. " - " .. itemName(self.weapon)) or T("IGUI_MIL_Title")
    shadowText(self, fit(title, self.width - ix - 150, font), ix, math.floor((hh - fh(font)) / 2), C.accent, 1, font)
    -- header buttons
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, b in ipairs(self:headerButtons()) do
        local over = inside(b, mx, my)
        local tint = b.id == "close" and { 0.95, 0.55, 0.45 } or C.accent
        self:drawRect(b.x, b.y, b.w, b.h, over and 0.95 or 0.75, C.accentDark[1], C.accentDark[2], C.accentDark[3])
        self:drawRectBorder(b.x, b.y, b.w, b.h, over and 1 or 0.7, tint[1], tint[2], tint[3])
        local name = b.id == "pin" and (W.pinned and "pin_on" or "pin_off") or ("icon_" .. b.id)
        local icon = texture(name)
        local disabled = (b.id == "plus" and W.textStep >= 2) or (b.id == "minus" and W.textStep <= 0)
        if icon then self:drawTextureScaled(icon, b.x + 3, b.y + 3, b.w - 6, b.h - 6, disabled and 0.35 or 1, 1, 1, 1) end
        if over then
            local key = ({ close = "IGUI_MIL_Close", pin = W.pinned and "IGUI_MIL_Unpin" or "IGUI_MIL_Pin",
                plus = "IGUI_MIL_TextBigger", minus = "IGUI_MIL_TextSmaller" })[b.id]
            self.hoverTip = { text = T(key), x = b.x - 60, y = b.y + b.h + 4 }
        end
        local id = b.id
        self.buttons[#self.buttons + 1] = { x = b.x, y = b.y, w = b.w, h = b.h, fn = function()
            if id == "close" then self:close()
            elseif id == "pin" then self:togglePin()
            elseif id == "plus" then W.stepText(1)
            else W.stepText(-1) end
        end }
    end
    if self.collapsed then return end
    -- the tab row
    self:drawRect(1, hh, self.width - 2, th, 0.92, C.tabRow[1], C.tabRow[2], C.tabRow[3])
    self:drawRect(0, hh + th - 1, self.width, 1, 0.8, C.border[1], C.border[2], C.border[3])
    local gap = 5
    local tabW = math.floor((self.width - 16 - gap * (#W.TABS - 1)) / #W.TABS)
    local x = 8
    local sf = W.small()
    for _, t in ipairs(W.TABS) do
        local active = self.tab == t.id
        local locked = self:locked(t.id)
        local ty, tH = hh + 6, th - 12
        local bg = active and C.accentDark or C.background
        local bd = active and C.accent or C.borderDim
        self:drawRect(x, ty, tabW, tH, active and 0.98 or (locked and 0.45 or 0.82), bg[1], bg[2], bg[3])
        self:drawRectBorder(x, ty, tabW, tH, active and 0.95 or 0.62, bd[1], bd[2], bd[3])
        if active then
            self:drawRect(x + 2, ty + 2, tabW - 4, tH - 4, 0.16, C.accent[1], C.accent[2], C.accent[3])
            self:drawRect(x + 3, ty + tH - 5, tabW - 6, 2, 0.75, C.accent[1], C.accent[2], C.accent[3])
        end
        local size = math.min(tH - 8, 40)
        local label = fit(T(t.key), tabW - size - 24, sf)
        local icon = texture(t.icon)
        local total = size + 8 + tw(sf, label)
        local tx = x + math.floor((tabW - total) / 2)
        if icon then self:drawTextureScaled(icon, tx, ty + math.floor((tH - size) / 2), size, size, active and 1 or (locked and 0.25 or 0.65), 1, 1, 1) end
        shadowText(self, label, tx + size + 8, ty + math.floor((tH - fh(sf)) / 2), active and C.text or C.textDim, locked and 0.45 or 1, sf)
        if locked then
            -- a small padlock in the corner
            local lx, ly = x + tabW - 18, ty + 6
            self:drawRect(lx, ly + 5, 10, 8, 0.9, C.textDim[1], C.textDim[2], C.textDim[3])
            self:drawRectBorder(lx + 2, ly, 6, 7, 0.9, C.textDim[1], C.textDim[2], C.textDim[3])
        end
        local bounds = { x = x, y = ty, w = tabW, h = tH }
        if inside(bounds, mx, my) then self.hoverTip = { text = locked and T("IGUI_MIL_LockedTip") or T(t.tip), x = x + 30, y = ty + tH + 4 } end
        local id = t.id
        self.buttons[#self.buttons + 1] = { x = x, y = ty, w = tabW, h = tH, fn = function() self:setTab(id) end }
        x = x + tabW + gap
    end
    local top = hh + th + 2
    self:drawRect(4, top, self.width - 8, self.height - top - 4, C.panel[4], C.panel[1], C.panel[2], C.panel[3])
end

function W:render()
    if not self.collapsed then
        local x, y = 8, W.contentTop()
        local w, h = self.width - 16, self.height - y - 8
        if self.tab == "inspect" then
            if not self.pane then shadowText(self, T("IGUI_MIL_NoInspect"), x + 12, y + 12, W.C.bad, 1, W.medium()) end
        else
            self:setStencilRect(x, y, w, h)
            local ok, err = pcall(function()
                if self.tab == "stats" then self:renderStats(x, y, w, h)
                elseif self.tab == "parts" then self:renderParts(x, y, w, h)
                elseif self.tab == "ammo" then self:renderAmmo(x, y, w, h)
                else self:renderGuide(x, y, w, h) end
            end)
            self:clearStencilRect()
            if not ok then logOnce("render:" .. self.tab, "tab %s draw FAILED: %s", self.tab, tostring(err)) end
        end
    end
    self:drawHoverTip()
    self:updatePin()
end

function W:drawHoverTip()
    local t = self.hoverTip
    if not t or not t.text or t.text == "" or t.text:find("IGUI_", 1, true) then return end
    local C = W.C
    local font = W.small()
    local lines = wrap(t.text, 340, font)
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, tw(font, l)) end
    w = w + 16
    local h = #lines * lineH(font) + 10
    local x = math.max(4, math.min(self.width - w - 4, t.x))
    self:drawRect(x, t.y, w, h, 0.97, C.header[1], C.header[2], C.header[3])
    self:drawRectBorder(x, t.y, w, h, 1, C.border[1], C.border[2], C.border[3])
    for i, l in ipairs(lines) do shadowText(self, l, x + 8, t.y + 5 + (i - 1) * lineH(font), C.text, 1, font) end
end

-- ----------------------------------------------------------------- tab 2: stats
function W:renderStats(x, y, w, h)
    local C = W.C
    local sf, mf = W.small(), W.medium()
    local lh = lineH(sf) + 6
    local rows = W.statRows(self.weapon)
    local leftW = math.floor(w * 0.62)
    -- the table card
    local cardH = W.CARD_T + 18 + lh * (#rows + 1)
    local cx, cy, cw = self:drawCard(x, y - self.scroll, leftW, cardH, T("IGUI_MIL_StatsTitle"))
    local cols = { cx, cx + math.floor(cw * 0.46), cx + math.floor(cw * 0.64), cx + math.floor(cw * 0.82) }
    shadowText(self, T("IGUI_MIL_StatName"), cols[1], cy, C.textDim, 1, sf)
    shadowText(self, T("IGUI_MIL_StatNow"), cols[2], cy, C.textDim, 1, sf)
    shadowText(self, T("IGUI_MIL_StatBase"), cols[3], cy, C.textDim, 1, sf)
    shadowText(self, T("IGUI_MIL_StatParts"), cols[4], cy, C.textDim, 1, sf)
    local yy = cy + lh
    for i, r in ipairs(rows) do
        local bg = (i % 2 == 0) and C.row or C.rowAlt
        self:drawRect(cx - 4, yy - 3, cw + 8, lh, 0.9, bg[1], bg[2], bg[3])
        shadowText(self, fit(T(r.key), cols[2] - cols[1] - 8, sf), cols[1], yy, C.text, 1, sf)
        shadowText(self, W.fmtNum(r.now), cols[2], yy, C.text, 1, sf)
        shadowText(self, W.fmtNum(r.base), cols[3], yy, C.textDim, 1, sf)
        if r.better ~= nil then
            shadowText(self, (r.delta > 0 and "+" or "") .. W.fmtNum(r.delta), cols[4], yy, r.better and C.good or C.bad, 1, sf)
        else
            shadowText(self, "-", cols[4], yy, C.textDim, 1, sf)
        end
        yy = yy + lh
    end
    -- the condition card + how to read it
    local rx, rw = x + leftW + 10, w - leftW - 10
    local cond, cmax = num(call(self.weapon, "getCondition")) or 0, num(call(self.weapon, "getConditionMax")) or 1
    local ix, iy, iw = self:drawCard(rx, y - self.scroll, rw, W.CARD_T + 70, T("IGUI_MIL_ConditionTitle"))
    shadowText(self, T("IGUI_MIL_Condition", tostring(math.floor(cond)), tostring(math.floor(cmax))), ix, iy, C.text, 1, mf)
    local f = math.max(0, math.min(1, cond / math.max(1, cmax)))
    local by = iy + lineH(mf) + 6
    self:drawRect(ix, by, iw, 14, 0.9, 0.12, 0.03, 0.03)
    self:drawRect(ix, by, math.floor(iw * f), 14, 1, 1 - f, f, 0.15)
    self:drawRectBorder(ix, by, iw, 14, 0.8, C.borderDim[1], C.borderDim[2], C.borderDim[3])
    local note = wrap(T("IGUI_MIL_StatsNote"), rw - 24, sf)
    local ny = y - self.scroll + W.CARD_T + 80
    local nx, nyy = self:drawCard(rx, ny, rw, W.CARD_T + 16 + #note * lineH(sf), T("IGUI_MIL_StatsHowTitle"))
    for _, l in ipairs(note) do shadowText(self, l, nx, nyy, C.textDim, 1, sf); nyy = nyy + lineH(sf) end
    self.contentH = math.max(cardH, ny + self.scroll - y + W.CARD_T + 16 + #note * lineH(sf))
end

function W:openPicker(slot, ax, ay)
    if not selectAttachmentPane then log("the original part picker is missing"); return end
    local ok, err = pcall(function()
        local pane = selectAttachmentPane:new(self:getAbsoluteX() + ax, self:getAbsoluteY() + ay, slot)
        pane:addToUIManager()
        pane:bringToTop()
    end)
    log("part picker for %s %s", slot, ok and "opened" or ("FAILED: " .. tostring(err)))
end

function W:removePart(slot, part)
    local ok, err = pcall(function()
        ISTimedActionQueue.add(ISRemoveWeaponUpgrade:new(self.player, self.weapon, part:getPartType(), 1))
    end)
    log("remove %s from %s: %s", itemName(part), slot, ok and "queued" or ("FAILED: " .. tostring(err)))
    self.partCache = nil
end

-- ----------------------------------------------------------------- tab 3: parts
function W:renderParts(x, y, w, h)
    local C = W.C
    local sf = W.small()
    -- the part lists scan containers: refresh twice a second, not every frame
    local now = getTimestampMs and getTimestampMs() or 0
    if not self.partCache or now - (self.partCacheAt or 0) > 500 then
        self.partCache = W.partRows(self.player, self.weapon)
        self.partCacheAt = now
    end
    local note = wrap(T("IGUI_MIL_PartsNote"), w - 24, sf)
    local top = y - self.scroll
    local nx, ny = self:drawCard(x, top, w, W.CARD_T + 16 + #note * lineH(sf), T("IGUI_MIL_PartsHowTitle"))
    for _, l in ipairs(note) do shadowText(self, l, nx, ny, C.textDim, 1, sf); ny = ny + lineH(sf) end
    top = top + W.CARD_T + 26 + #note * lineH(sf)
    -- the slots, two cards a row
    local gap = 10
    local cw = math.floor((w - gap) / 2)
    local ch = W.CARD_T + 12 + math.max(44, lineH(sf) * 2 + 8)
    for i, r in ipairs(self.partCache) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local px, py = x + col * (cw + gap), top + row * (ch + gap)
        local slotKey = "IGUI_" .. r.slot
        local ix, iy, iw = self:drawCard(px, py, cw, ch, T(slotKey))
        local t0 = r.part and call(r.part, "getTexture")
        if t0 then self:drawTextureScaled(t0, ix, iy, 40, 40, 1, 1, 1, 1) end
        local bw = 110
        local textW = iw - 48 - bw * 2 - 16
        shadowText(self, fit(r.part and itemName(r.part) or T("IGUI_MIL_Empty"), textW, sf), ix + 48, iy + 2, r.part and C.text or C.textDim, 1, sf)
        shadowText(self, fit(T("IGUI_MIL_PartsFit", tostring(r.fits)), textW, sf), ix + 48, iy + 2 + lineH(sf), C.textDim, 1, sf)
        local slot, part = r.slot, r.part
        local bx = ix + iw - bw * 2 - 8
        if part then self:button(bx, iy + 8, bw, 28, T("IGUI_MIL_Remove"), function() self:removePart(slot, part) end) end
        local ax, ay = ix + iw - bw, iy + 36
        self:button(ix + iw - bw, iy + 8, bw, 28, T("IGUI_MIL_Install"), function() self:openPicker(slot, ax, ay) end, r.fits > 0)
    end
    local rows = math.ceil(#self.partCache / 2)
    self.contentH = top + self.scroll - y + rows * (ch + gap)
end

-- ----------------------------------------------------------------- tab 4: ammo
function W:renderAmmo(x, y, w, h)
    local C = W.C
    local sf, mf = W.small(), W.medium()
    local a = W.ammoInfo(self.player, self.weapon)
    local list = { { item = a.magItem, title = T("IGUI_MIL_Loaded"), value = tostring(a.loaded) .. " / " .. tostring(a.max) } }
    if a.ammoName then list[#list + 1] = { item = a.ammoItem, title = a.ammoName, value = T("IGUI_MIL_InBags", tostring(a.loose)) } end
    if a.boxName then list[#list + 1] = { item = a.boxItem, title = a.boxName, value = T("IGUI_MIL_InBags", tostring(a.boxes)) } end
    if a.magName then list[#list + 1] = { item = a.magItem, title = a.magName, value = T("IGUI_MIL_InBags", tostring(a.mags)) } end
    local gap = 10
    local cw = math.floor((w - gap) / 2)
    local ch = W.CARD_T + 64
    local top = y - self.scroll
    for i, e in ipairs(list) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local ix, iy = self:drawCard(x + col * (cw + gap), top + row * (ch + gap), cw, ch, e.title)
        local t0 = e.item and call(e.item, "getTexture")
        if t0 then self:drawTextureScaled(t0, ix, iy, 44, 44, 1, 1, 1, 1) end
        shadowText(self, e.value, ix + 56, iy + 8, C.text, 1, mf)
    end
    top = top + math.ceil(#list / 2) * (ch + gap)
    local note = wrap(T("IGUI_MIL_AmmoNote"), w - 24, sf)
    local nx, ny = self:drawCard(x, top, w, W.CARD_T + 60 + #note * lineH(sf), T("IGUI_MIL_AmmoHowTitle"))
    for _, l in ipairs(note) do shadowText(self, l, nx, ny, C.textDim, 1, sf); ny = ny + lineH(sf) end
    self:button(nx, ny + 8, 220, 30, T("IGUI_MIL_ToInspect"), function() self:setTab("inspect") end)
    self.contentH = top + self.scroll - y + W.CARD_T + 70 + #note * lineH(sf)
end

-- ----------------------------------------------------------------- tab 5: guide
-- chapters on the left, the page on the right (Car for Crash's guide)
W.GUIDE = {}
for _, k in ipairs({ "Open", "View", "Parts", "Position", "Ammo", "Repair", "Modes", "Adapt", "Tabs" }) do
    W.GUIDE[#W.GUIDE + 1] = { title = "IGUI_MIL_Guide_" .. k .. "_T", body = "IGUI_MIL_Guide_" .. k }
end
function W:renderGuide(x, y, w, h)
    local C = W.C
    local sf, mf = W.small(), W.medium()
    if not self.weapon then
        -- the gun tabs are locked: say why, above the guide
        local lines = wrap(T("IGUI_MIL_NoGun"), w - 24, sf)
        local bh = W.CARD_T + 14 + #lines * lineH(sf)
        local bx, by = self:drawCard(x, y, w, bh, T("IGUI_MIL_NoGunTitle"))
        local flash = self.lockFlashAt and ((getTimestampMs and getTimestampMs() or 0) - self.lockFlashAt) < 600
        for _, l in ipairs(lines) do shadowText(self, l, bx, by, flash and C.bad or C.warn, 1, sf); by = by + lineH(sf) end
        y = y + bh + 10
        h = h - bh - 10
    end
    local listW = math.floor(w * 0.28)
    local lx, ly, lw = self:drawCard(x, y, listW, h, T("IGUI_MIL_GuideTitle"))
    local bh = lineH(sf) + 12
    for i, g in ipairs(W.GUIDE) do
        local by = ly + (i - 1) * (bh + 4)
        local active = self.guidePage == i
        local bg = active and C.accentDark or C.background
        self:drawRect(lx, by, lw, bh, active and 0.98 or 0.8, bg[1], bg[2], bg[3])
        self:drawRectBorder(lx, by, lw, bh, active and 0.95 or 0.55, (active and C.accent or C.borderDim)[1], (active and C.accent or C.borderDim)[2], (active and C.accent or C.borderDim)[3])
        shadowText(self, fit(tostring(i) .. ". " .. T(g.title), lw - 12, sf), lx + 8, by + 6, active and C.text or C.textDim, 1, sf)
        local idx = i
        self.buttons[#self.buttons + 1] = { x = lx, y = by, w = lw, h = bh, fn = function()
            self.guidePage = idx
            pcall(function() getSoundManager():playUISound("UISelectListItem") end)
        end }
    end
    local g = W.GUIDE[self.guidePage] or W.GUIDE[1]
    local px, py, pw = self:drawCard(x + listW + 10, y, w - listW - 10, h, tostring(self.guidePage) .. ". " .. T(g.title))
    for _, l in ipairs(wrap(T(g.body), pw - 12, sf)) do shadowText(self, l, px, py, C.text, 1, sf); py = py + lineH(sf) end
    self.contentH = 0
end

function W:onMouseDown(x, y)
    for i = #self.buttons, 1, -1 do
        local b = self.buttons[i]
        if inside(b, x, y) then
            local ok, err = pcall(b.fn)
            if not ok then log("button FAILED: %s", tostring(err)) end
            return true
        end
    end
    return ISPanel.onMouseDown(self, x, y)
end

function W:onMouseWheel(del)
    if self.tab == "inspect" or self.collapsed then return false end
    local maxS = math.max(0, (self.contentH or 0) - (self.height - W.contentTop() - 8))
    self.scroll = math.max(0, math.min(maxS, self.scroll + del * 40))
    return true
end

-- ----------------------------------------------------------------- open
-- allowNoGun: the HARMONIE tab opens the window even without a gun in hand
-- (the gun tabs are then locked); the inspect paths need the gun
function W.open(player, expectedWeaponId, allowNoGun)
    player = player or (getPlayer and getPlayer() or nil)
    local Fix = MFSInspectFix
    local weapon = Fix and Fix.getInspectableWeapon and Fix.getInspectableWeapon(player, expectedWeaponId)
    if not weapon and not allowNoGun then
        log("open refused: no gun in the main hand")
        return false
    end
    if W.instance then W.instance:close() end
    if type(riskyInspectWindow) == "table" and not riskyInspectWindow.__hmlProxy and Fix and Fix.closeCurrentWindow then
        pcall(Fix.closeCurrentWindow)
    end
    local ok, win = pcall(function() return W:new(player, weapon) end)
    if not ok or not win then log("open FAILED: %s", tostring(win)); return false end
    local ok2, err = pcall(function()
        win:initialise()
        win:addToUIManager()
        if Fix and Fix.clampWindowToScreen then Fix.clampWindowToScreen(win) end
        win:bringToTop()
    end)
    if not ok2 then
        log("open FAILED while building: %s", tostring(err))
        pcall(function() win:removeFromUIManager() end)
        return false
    end
    W.instance = win
    log("opened for %s", weapon and fullType(weapon) or "no gun (gun tabs locked)")
    return true
end

function W.isOpen() return W.instance ~= nil and W.instance:getIsVisible() end

-- every way the original opened its window now opens this one
function W.install(quiet)
    local Fix = MFSInspectFix
    if not Fix or not Fix.open then
        -- at file load MFSInspectFix is not loaded yet (it sorts after this file)
        if not quiet then logOnce("nofix", "MFSInspectFix is missing -- the original inspect window stays as it was") end
        return
    end
    if Fix.__hmlWorkbench then return end
    Fix.__hmlWorkbench = true
    Fix.openOriginal = Fix.open
    Fix.open = function(player, expectedWeaponId)
        if W.open(player, expectedWeaponId) then return true end
        log("falling back to the original inspect window")
        return Fix.openOriginal(player, expectedWeaponId)
    end
    log("version %d installed (the inspect window opens the Mercenary Is Life workbench)", W.VERSION)
end

-- ----------------------------------------------------------------- right-click: Upgrade gun
-- Owner, 2026-10-09: "คลิกขวาที่ปืนไม่มีขึ้น อัพเกรดปืน ที่จะพาไปหน้าต่าง". Right-click a
-- gun (inventory or a container next to you) > Upgrade gun: the gun is taken
-- in the main hand (moved into the inventory first when needed) and this
-- window opens on it.
function W.upgradeGun(player, gun)
    if not player or not gun then return end
    local held = call(player, "getPrimaryHandItem")
    if held == gun then
        log("right-click > Upgrade gun: %s (already in hand)", fullType(gun))
        W.open(player)
        return
    end
    local ok, err = pcall(function()
        local inv = player:getInventory()
        local src = gun:getContainer()
        if src and src ~= inv and ISInventoryTransferAction then
            ISTimedActionQueue.add(ISInventoryTransferAction:new(player, gun, src, inv))
        end
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, gun, 50, true, gun:isTwoHandWeapon()))
        -- the original's inspect action opens the window when the gun is in hand
        ISTimedActionQueue.add(riskyInspectAction:new(player, 1))
    end)
    log("right-click > Upgrade gun: %s %s", fullType(gun), ok and "-- equip queued, then the window" or ("FAILED: " .. tostring(err)))
end

function W.onInventoryMenu(playerNum, context, items)
    local player = getSpecificPlayer and getSpecificPlayer(playerNum)
    local Fix = MFSInspectFix
    if not player or not context or not items or not (Fix and Fix.isInspectableWeapon) then return end
    local guns, seen = {}, {}
    for _, v in ipairs(items) do
        local list = (type(v) == "table" and v.items) or { v }
        for _, it in ipairs(list) do
            if it and not seen[it] and Fix.isInspectableWeapon(it) then
                seen[it] = true
                guns[#guns + 1] = it
            end
        end
    end
    if #guns == 0 then return end
    if #guns == 1 then
        context:addOption(T("IGUI_MIL_UpgradeGun"), player, W.upgradeGun, guns[1])
    else
        local parent = context:addOption(T("IGUI_MIL_UpgradeGun"))
        local sub = context:getNew(context)
        context:addSubMenu(parent, sub)
        for _, g in ipairs(guns) do sub:addOption(itemName(g), player, W.upgradeGun, g) end
    end
end
if Events and Events.OnFillInventoryObjectContextMenu and not W.menuHooked then
    W.menuHooked = true
    Events.OnFillInventoryObjectContextMenu.Add((HARMONIE_Ours or function(f) return f end)(W.onInventoryMenu, "MFS"))
end

W.install(true)
if Events and Events.OnGameStart then Events.OnGameStart.Add(function() W.install(false) end) end

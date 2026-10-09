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
W.HEADER_H = 46
W.PANE_W, W.PANE_H = 1298, 716      -- the original inspect panel's own size
W.TABS = {
    { id = "inspect", icon = "tab_inspect", key = "IGUI_MIL_Tab_inspect" },
    { id = "stats", icon = "tab_stats", key = "IGUI_MIL_Tab_stats" },
    { id = "parts", icon = "tab_parts", key = "IGUI_MIL_Tab_parts" },
    { id = "ammo", icon = "tab_ammo", key = "IGUI_MIL_Tab_ammo" },
    { id = "guide", icon = "tab_guide", key = "IGUI_MIL_Tab_guide" },
}
-- red theme (How to Survive's palette turned red)
W.C = {
    accent = { 0.92, 0.24, 0.20 }, accentDark = { 0.26, 0.04, 0.04 },
    background = { 0.035, 0.012, 0.014, 0.97 }, panel = { 0.075, 0.025, 0.028, 0.94 },
    header = { 0.07, 0.018, 0.02, 0.98 }, border = { 0.82, 0.22, 0.20 }, borderDim = { 0.40, 0.10, 0.10 },
    text = { 0.97, 0.92, 0.91 }, textDim = { 0.74, 0.62, 0.61 }, good = { 0.45, 0.92, 0.45 }, bad = { 1.0, 0.42, 0.38 },
    row = { 0.11, 0.035, 0.04 }, rowAlt = { 0.085, 0.028, 0.032 },
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

-- ----------------------------------------------------------------- window
function W:new(player, weapon)
    local w = W.PANE_W
    local h = W.HEADER_H + W.PANE_H
    local x, y = 100, 100
    if MFSInspectFix and MFSInspectFix.ensurePosition then x, y = MFSInspectFix.ensurePosition(player) end
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.weapon = weapon
    o.moveWithMouse = true
    o.backgroundColor = { r = W.C.background[1], g = W.C.background[2], b = W.C.background[3], a = W.C.background[4] }
    o.borderColor = { r = W.C.border[1], g = W.C.border[2], b = W.C.border[3], a = 1 }
    o.tab = "inspect"
    o.scroll = 0
    o.buttons = {}
    return o
end

function W:createChildren()
    ISPanel.createChildren(self)
    -- 1: the original panel
    local Pane = W.paneClass()
    if Pane then
        local ok, pane = pcall(function() return Pane:new(0, W.HEADER_H, 0, 0) end)
        if ok and pane then
            pane.workbench = self
            pane.moveWithMouse = false
            self.pane = pane
            self:addChild(pane)
            riskyInspectWindow = makeProxy(pane)
            local okR, err = pcall(function() pane:renderInventory() end)
            if not okR then log("the 3D inspect view FAILED to build: %s", tostring(err)) end
            pane:setX(0); pane:setY(W.HEADER_H)
        else
            log("the 3D inspect view could not be created: %s", tostring(pane))
        end
    else
        logOnce("noriskyui", "the original inspect panel (riskyUI) is missing -- the inspect tab is empty")
    end
end

function W:setTab(id)
    if self.tab == id then return end
    self.tab = id
    self.scroll = 0
    if self.pane then self.pane:setVisible(id == "inspect") end
    if id ~= "inspect" and riskyUI_slider and riskyUI_slider.instance then
        pcall(function() riskyUI_slider.instance:close() end)
        riskyUI_slider.instance = nil
    end
    pcall(function() getSoundManager():playUISound("UISelectListItem") end)
    log("tab %s", id)
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
    local p = self.player
    local held = call(p, "getPrimaryHandItem")
    if held ~= self.weapon then
        log("the gun left the hand -- closing")
        self:close()
    end
end

-- ----------------------------------------------------------------- drawing
local function txt(self, s, x, y, c, font, a)
    self:drawText(s, x, y, c[1], c[2], c[3], a or 1, font or UIFont.Small)
end
local function fh(font) return getTextManager():getFontHeight(font) end
local function tw(font, s) return getTextManager():MeasureStringX(font, s) end
local function wrap(text, maxW, font)
    local out = {}
    for para in tostring(text or ""):gmatch("[^\n]+") do
        local line = ""
        for word in para:gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            if tw(font, try) > maxW and line ~= "" then out[#out + 1] = line; line = word else line = try end
        end
        out[#out + 1] = line
    end
    return out
end

function W:button(x, y, w, h, label, fn, enabled)
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = mx >= x and mx <= x + w and my >= y and my <= y + h
    enabled = enabled ~= false
    local c = W.C
    self:drawRect(x, y, w, h, enabled and (over and 0.95 or 0.75) or 0.3, c.accentDark[1] * (over and 1.6 or 1), c.accentDark[2], c.accentDark[3])
    self:drawRectBorder(x, y, w, h, enabled and 1 or 0.4, c.border[1], c.border[2], c.border[3])
    local lw = tw(UIFont.Small, label)
    txt(self, label, x + math.floor((w - lw) / 2), y + math.floor((h - fh(UIFont.Small)) / 2), enabled and c.text or c.textDim)
    if enabled then self.buttons[#self.buttons + 1] = { x = x, y = y, w = w, h = h, fn = fn } end
end

function W:prerender()
    ISPanel.prerender(self)
    self.buttons = {}
    local c = W.C
    -- header
    self:drawRect(0, 0, self.width, W.HEADER_H, c.header[4], c.header[1], c.header[2], c.header[3])
    self:drawRect(0, W.HEADER_H - 2, self.width, 2, 1, c.accent[1], c.accent[2], c.accent[3])
    local em = texture("emblem")
    if em then self:drawTextureScaled(em, 8, 7, 32, 32, 1, 1, 1, 1) end
    txt(self, T("IGUI_MIL_Title"), 48, 6, c.accent, UIFont.Medium)
    txt(self, itemName(self.weapon), 48, 6 + fh(UIFont.Medium), c.textDim, UIFont.Small)
    -- tabs
    local tx = 380
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, t in ipairs(W.TABS) do
        local label = T(t.key)
        local w = 40 + tw(UIFont.Small, label) + 12
        local active = self.tab == t.id
        local over = mx >= tx and mx <= tx + w and my >= 4 and my <= W.HEADER_H - 4
        self:drawRect(tx, 5, w, W.HEADER_H - 10, active and 0.95 or (over and 0.7 or 0.45),
            active and c.accentDark[1] * 2 or c.accentDark[1], c.accentDark[2], c.accentDark[3])
        self:drawRectBorder(tx, 5, w, W.HEADER_H - 10, active and 1 or 0.5, c.border[1], c.border[2], c.border[3])
        local ic = texture(t.icon)
        if ic then self:drawTextureScaled(ic, tx + 5, 9, 28, 28, 1, 1, 1, 1) end
        txt(self, label, tx + 38, math.floor((W.HEADER_H - fh(UIFont.Small)) / 2), active and c.text or c.textDim)
        local id = t.id
        self.buttons[#self.buttons + 1] = { x = tx, y = 5, w = w, h = W.HEADER_H - 10, fn = function() self:setTab(id) end }
        tx = tx + w + 6
    end
    -- close
    local cl = texture("icon_close")
    local cx = self.width - 40
    if cl then self:drawTextureScaled(cl, cx, 7, 32, 32, 1, 1, 1, 1) else self:button(cx, 7, 32, 32, "X", function() self:close() end) end
    self.buttons[#self.buttons + 1] = { x = cx, y = 7, w = 32, h = 32, fn = function() self:close() end }
end

function W:render()
    ISPanel.render(self)
    if self.tab == "inspect" then
        if not self.pane then txt(self, T("IGUI_MIL_NoInspect"), 20, W.HEADER_H + 20, W.C.bad, UIFont.Medium) end
        return
    end
    local top = W.HEADER_H
    self:drawRect(0, top, self.width, self.height - top, 0.97, W.C.panel[1], W.C.panel[2], W.C.panel[3])
    self:setStencilRect(0, top, self.width, self.height - top)
    local ok, err = pcall(function()
        if self.tab == "stats" then self:renderStats(top)
        elseif self.tab == "parts" then self:renderParts(top)
        elseif self.tab == "ammo" then self:renderAmmo(top)
        elseif self.tab == "guide" then self:renderGuide(top) end
    end)
    self:clearStencilRect()
    if not ok then logOnce("render:" .. self.tab, "tab %s draw FAILED: %s", self.tab, tostring(err)) end
end

local function heading(self, s, x, y)
    txt(self, s, x, y, W.C.accent, UIFont.Medium)
    self:drawRect(x, y + fh(UIFont.Medium) + 2, 300, 2, 0.8, W.C.accent[1], W.C.accent[2], W.C.accent[3])
    return y + fh(UIFont.Medium) + 10
end

function W:renderStats(top)
    local c = W.C
    local x0, y = 30, top + 16 - self.scroll
    y = heading(self, T("IGUI_MIL_StatsTitle"), x0, y)
    local cols = { x0, x0 + 360, x0 + 520, x0 + 680 }
    txt(self, T("IGUI_MIL_StatName"), cols[1], y, c.textDim)
    txt(self, T("IGUI_MIL_StatNow"), cols[2], y, c.textDim)
    txt(self, T("IGUI_MIL_StatBase"), cols[3], y, c.textDim)
    txt(self, T("IGUI_MIL_StatParts"), cols[4], y, c.textDim)
    y = y + fh(UIFont.Small) + 6
    local rowH = fh(UIFont.Small) + 10
    for i, r in ipairs(W.statRows(self.weapon)) do
        local bg = (i % 2 == 0) and c.row or c.rowAlt
        self:drawRect(x0 - 6, y - 4, 860, rowH, 0.9, bg[1], bg[2], bg[3])
        txt(self, T(r.key), cols[1], y, c.text)
        txt(self, W.fmtNum(r.now), cols[2], y, c.text)
        txt(self, W.fmtNum(r.base), cols[3], y, c.textDim)
        if r.better ~= nil then
            txt(self, (r.delta > 0 and "+" or "") .. W.fmtNum(r.delta), cols[4], y, r.better and c.good or c.bad)
        else
            txt(self, "-", cols[4], y, c.textDim)
        end
        y = y + rowH
    end
    -- condition
    y = y + 16
    local cond, cmax = num(call(self.weapon, "getCondition")) or 0, num(call(self.weapon, "getConditionMax")) or 1
    txt(self, T("IGUI_MIL_Condition", tostring(math.floor(cond)), tostring(math.floor(cmax))), x0, y, c.text, UIFont.Medium)
    y = y + fh(UIFont.Medium) + 6
    self:drawRect(x0, y, 400, 14, 0.8, 0.15, 0.05, 0.05)
    local f = math.max(0, math.min(1, cond / math.max(1, cmax)))
    self:drawRect(x0, y, math.floor(400 * f), 14, 1, 1 - f, f, 0.15)
    y = y + 30
    for _, l in ipairs(wrap(T("IGUI_MIL_StatsNote"), self.width - 80, UIFont.Small)) do txt(self, l, x0, y, c.textDim); y = y + fh(UIFont.Small) + 2 end
    self.contentH = y + self.scroll - top
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

function W:renderParts(top)
    local c = W.C
    local x0, y = 30, top + 16 - self.scroll
    y = heading(self, T("IGUI_MIL_PartsTitle"), x0, y)
    for _, l in ipairs(wrap(T("IGUI_MIL_PartsNote"), self.width - 80, UIFont.Small)) do txt(self, l, x0, y, c.textDim); y = y + fh(UIFont.Small) + 2 end
    y = y + 8
    -- the part lists scan containers: refresh twice a second, not every frame
    local now = getTimestampMs and getTimestampMs() or 0
    if not self.partCache or now - (self.partCacheAt or 0) > 500 then
        self.partCache = W.partRows(self.player, self.weapon)
        self.partCacheAt = now
    end
    local rowH = 52
    for i, r in ipairs(self.partCache) do
        local bg = (i % 2 == 0) and c.row or c.rowAlt
        self:drawRect(x0 - 6, y, self.width - 48, rowH - 4, 0.9, bg[1], bg[2], bg[3])
        local slotKey = "IGUI_" .. r.slot
        txt(self, T(slotKey), x0, y + 4, c.accent)
        local tex0 = r.part and call(r.part, "getTexture")
        if tex0 then self:drawTextureScaled(tex0, x0 + 200, y + 4, 36, 36, 1, 1, 1, 1) end
        txt(self, r.part and itemName(r.part) or T("IGUI_MIL_Empty"), x0 + 244, y + 4, r.part and c.text or c.textDim)
        txt(self, T("IGUI_MIL_PartsFit", tostring(r.fits)), x0 + 244, y + 10 + fh(UIFont.Small), c.textDim)
        local bx = self.width - 300
        local slot, part = r.slot, r.part
        local yy = y
        if part then
            self:button(bx, y + 8, 120, 28, T("IGUI_MIL_Remove"), function() self:removePart(slot, part) end)
        end
        self:button(bx + 130, y + 8, 120, 28, T("IGUI_MIL_Install"), function() self:openPicker(slot, bx + 130, yy + 36) end, r.fits > 0)
        y = y + rowH
    end
    self.contentH = y + self.scroll - top
end

function W:renderAmmo(top)
    local c = W.C
    local x0, y = 30, top + 16 - self.scroll
    y = heading(self, T("IGUI_MIL_AmmoTitle"), x0, y)
    local a = W.ammoInfo(self.player, self.weapon)
    local function line(item, label, value)
        local t0 = item and call(item, "getTexture")
        if t0 then self:drawTextureScaled(t0, x0, y, 40, 40, 1, 1, 1, 1) end
        txt(self, label, x0 + 52, y + 2, c.textDim)
        txt(self, value, x0 + 52, y + 2 + fh(UIFont.Small), c.text, UIFont.Medium)
        y = y + 54
    end
    line(a.magItem, T("IGUI_MIL_Loaded"), tostring(a.loaded) .. " / " .. tostring(a.max))
    if a.ammoName then line(a.ammoItem, a.ammoName, T("IGUI_MIL_InBags", tostring(a.loose))) end
    if a.boxName then line(a.boxItem, a.boxName, T("IGUI_MIL_InBags", tostring(a.boxes))) end
    if a.magName then line(a.magItem, a.magName, T("IGUI_MIL_InBags", tostring(a.mags))) end
    y = y + 8
    for _, l in ipairs(wrap(T("IGUI_MIL_AmmoNote"), self.width - 80, UIFont.Small)) do txt(self, l, x0, y, c.textDim); y = y + fh(UIFont.Small) + 2 end
    y = y + 10
    self:button(x0, y, 220, 30, T("IGUI_MIL_ToInspect"), function() self:setTab("inspect") end)
    self.contentH = y + 40 + self.scroll - top
end

W.GUIDE = {}
for _, k in ipairs({ "Open", "View", "Parts", "Position", "Ammo", "Repair", "Modes", "Adapt", "Tabs" }) do
    W.GUIDE[#W.GUIDE + 1] = { title = "IGUI_MIL_Guide_" .. k .. "_T", body = "IGUI_MIL_Guide_" .. k }
end
function W:renderGuide(top)
    local c = W.C
    local x0, y = 30, top + 16 - self.scroll
    y = heading(self, T("IGUI_MIL_GuideTitle"), x0, y)
    local maxW = self.width - 80
    for _, g in ipairs(W.GUIDE) do
        txt(self, T(g.title), x0, y, c.accent, UIFont.Medium)
        y = y + fh(UIFont.Medium) + 2
        for _, l in ipairs(wrap(T(g.body), maxW, UIFont.Small)) do txt(self, l, x0 + 12, y, c.text); y = y + fh(UIFont.Small) + 2 end
        y = y + 10
    end
    self.contentH = y + self.scroll - top
end

function W:onMouseDown(x, y)
    for i = #self.buttons, 1, -1 do
        local b = self.buttons[i]
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            local ok, err = pcall(b.fn)
            if not ok then log("button FAILED: %s", tostring(err)) end
            return true
        end
    end
    return ISPanel.onMouseDown(self, x, y)
end

function W:onMouseWheel(del)
    if self.tab == "inspect" then return false end
    local maxS = math.max(0, (self.contentH or 0) - (self.height - W.HEADER_H) + 20)
    self.scroll = math.max(0, math.min(maxS, self.scroll + del * 40))
    return true
end

-- ----------------------------------------------------------------- open
function W.open(player, expectedWeaponId)
    player = player or (getPlayer and getPlayer() or nil)
    local Fix = MFSInspectFix
    local weapon = Fix and Fix.getInspectableWeapon and Fix.getInspectableWeapon(player, expectedWeaponId)
    if not weapon then
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
    log("opened for %s", fullType(weapon))
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

W.install(true)
if Events and Events.OnGameStart then Events.OnGameStart.Add(function() W.install(false) end) end

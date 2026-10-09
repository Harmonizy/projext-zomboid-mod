--[[
    HARMONIE Hub (the same file in every HARMONIE mod that has a window --
    the game loads one copy of a path; master copy: mods/_HarmonieHub,
    install.sh copies it into each mod). Owner, 2026-10-09:

    1. "ทำให้คลิกขวาของเรารวมอยู่ติดกันเสมอ ไม่โดนคำสั่งอื่นคั่น": after the
       world / inventory right-click menu is built, every option our mods
       added (marked by HARMONIE_Ours, shared/000_HARMONIE_HubBoot.lua) is
       moved next to the first one, in the order they were added; the debug
       entry goes last. Nothing else in the menu changes order.
    2. "เพิ่มแท็บในค่าสถานะตัวละคร vanilla แทนช่อง วิตามิน เพื่อไว้ให้เปิดหน้าต่าง
       ทั้ 5 อันของเราได้เลยโดยตรง": a HARMONIE tab in the character window
       (instead of Garden to Plate's Vitamins tab) with one card per window
       of the mods that are installed. A window that needs something first
       (a gun in the hand, a vehicle next to you) says so instead of opening.
    3. "ทำให้มีคลิกขวาดีบัคไว้ปรับค่าในม็อดต่างๆ ... ต้องเป็น admin หรือ -debug":
       right-click > HARMONIE debug (admins and -debug only): every sandbox
       value of our mods, live (single player: applied here; multiplayer:
       sent to the server like vanilla's admin sandbox screen), plus each
       mod's own debug window.

    Logs to console.txt as [HARMONIE_Hub] (setup, every action, every
    failure; nothing per frame).
]]--

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISContextMenu"
require "XpSystem/ISUI/ISCharacterInfoWindow"

HARMONIE_Hub = HARMONIE_Hub or {}
local Hub = HARMONIE_Hub
if Hub.loaded then return end
Hub.loaded = true
Hub.VERSION = 1
local Boot = HARMONIE_HubBoot or {}

-- ------------------------------------------------------------------ log
local function fmt(f, ...)
    local ok, s = pcall(string.format, f, ...)
    return ok and s or tostring(f)
end
local function log(f, ...) print("[HARMONIE_Hub] " .. fmt(f, ...)) end
local once = {}
local function logOnce(key, f, ...)
    if once[key] then return end
    once[key] = true
    log(f, ...)
end
Hub.log, Hub.logOnce = log, logOnce

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
local function nameOf(p)
    local n = call(p, "getUsername")
    return n and tostring(n) or "?"
end

-- ------------------------------------------------------------------ 1. grouping
-- every option marked ours moves next to the first one; ids follow the new
-- order when the menu numbered them by position
function Hub.regroup(context)
    local opts = type(context) == "table" and context.options
    if type(opts) ~= "table" then return 0 end
    local ours, debug, rest, first = {}, {}, {}, nil
    local off, idsByPos = nil, true
    for i, o in ipairs(opts) do
        if type(o) == "table" then
            if type(o.id) == "number" then
                off = off or (o.id - i)
                if o.id - i ~= off then idsByPos = false end
            else
                idsByPos = false
            end
            if o.harmonie then
                if not first then first = #rest + 1 end
                if o.harmonie == "debug" then debug[#debug + 1] = o else ours[#ours + 1] = o end
            else
                rest[#rest + 1] = o
            end
        else
            rest[#rest + 1] = o
        end
    end
    if not first then return 0 end
    for _, o in ipairs(debug) do ours[#ours + 1] = o end
    local new = {}
    for i = 1, #rest + 1 do
        if i == first then for _, o in ipairs(ours) do new[#new + 1] = o end end
        if rest[i] ~= nil then new[#new + 1] = rest[i] end
    end
    for i = 1, #new do opts[i] = new[i] end
    if idsByPos and off then
        for i, o in ipairs(opts) do if type(o) == "table" then o.id = i + off end end
    end
    return #ours
end

local function hookMenu(owner, ownerName, fname)
    if type(owner) ~= "table" or type(owner[fname]) ~= "function" then
        logOnce("nohook:" .. ownerName, "%s.%s not found -- our options there are not grouped", ownerName, fname)
        return
    end
    Hub.hooked = Hub.hooked or {}
    if Hub.hooked[ownerName] == owner[fname] then return end
    local orig = owner[fname]
    owner[fname] = function(...)
        local ctx = orig(...)
        if type(ctx) == "table" then
            local ok, n = pcall(Hub.regroup, ctx)
            if not ok then
                logOnce("regroupfail:" .. ownerName, "grouping our options in %s FAILED: %s", ownerName, tostring(n))
            elseif n > 0 then
                logOnce("regroup:" .. ownerName, "%s: our %d option(s) kept together (later menus not logged)", ownerName, n)
            end
        end
        return ctx
    end
    Hub.hooked[ownerName] = owner[fname]
    log("grouping our options in %s.%s", ownerName, fname)
end
function Hub.hookMenus()
    hookMenu(ISWorldObjectContextMenu, "ISWorldObjectContextMenu", "createMenu")
    hookMenu(ISInventoryPaneContextMenu, "ISInventoryPaneContextMenu", "createMenu")
    Hub.hookPool()
end

-- vanilla reuses option tables (a pool): a reused one must not stay "ours"
function Hub.hookPool()
    if Hub.poolHooked or not (ISContextMenu and type(ISContextMenu.allocOption) == "function") then return end
    Hub.poolHooked = true
    local orig = ISContextMenu.allocOption
    ISContextMenu.allocOption = function(self, ...)
        local o = orig(self, ...)
        if type(o) == "table" and o.harmonie then
            o.harmonie = nil
            if Boot.icon and o.iconTexture == Boot.icon() then o.iconTexture = nil end
        end
        return o
    end
end

-- ------------------------------------------------------------------ admin
-- admins (multiplayer access level "admin"; single player isAdmin()) and
-- -debug only
function Hub.isAdmin(player)
    if getDebug and getDebug() then return true, "debug" end
    if isClient and isClient() then
        local lvl = call(player, "getAccessLevel")
        return lvl ~= nil and string.lower(tostring(lvl)) == "admin", tostring(lvl)
    end
    local ok, a = pcall(function() return isAdmin() end)
    return ok and a == true, "singleplayer"
end

-- ------------------------------------------------------------------ the windows
-- one card per window; shown only when its mod is loaded. need(player)
-- returns nil when it can open, else the text key of what is missing.
local function heldGun(p)
    local w = call(p, "getPrimaryHandItem")
    if w and instanceof(w, "HandWeapon") and call(w, "isRanged") then return w end
    return nil
end
Hub.CARDS = {
    { id = "gtp", name = "IGUI_HUB_GTP_Name", desc = "IGUI_HUB_GTP_Desc",
      present = function() return GTPGuide ~= nil and GTPGuide.open ~= nil end,
      open = function(p) GTPGuide.open(p, nil, "cook") end },
    { id = "twa", name = "IGUI_HUB_TWA_Name", desc = "IGUI_HUB_TWA_Desc",
      present = function() return TWACraftUI ~= nil and TWACraftUI.open ~= nil end,
      open = function(p) TWACraftUI.open(p) end },
    { id = "hm", name = "IGUI_HUB_HM_Name", desc = "IGUI_HUB_HM_Desc",
      present = function() return EHR ~= nil and EHR.UI ~= nil and EHR.UI.ShowHealthPanel ~= nil end,
      open = function(p) EHR.UI.ShowHealthPanel(p) end },
    { id = "svu", name = "IGUI_HUB_SVU_Name", desc = "IGUI_HUB_SVU_Desc",
      present = function() return HSVU ~= nil and HSVU.open ~= nil end,
      need = function(p) if not (HSVU.nearVehicle and HSVU.nearVehicle(p)) then return "IGUI_HUB_NeedVehicle" end end,
      open = function(p) HSVU.open(p, HSVU.nearVehicle(p)) end },
    { id = "mfs", name = "IGUI_HUB_MFS_Name", desc = "IGUI_HUB_MFS_Desc",
      present = function() return MFSInspectFix ~= nil and MFSInspectFix.open ~= nil end,
      need = function(p) if not heldGun(p) then return "IGUI_HUB_NeedGun" end end,
      open = function(p) MFSInspectFix.open(p) end },
}

function Hub.openCard(card, player)
    local need = card.need and card.need(player)
    if need then
        log("%s: %s cannot open yet (%s)", nameOf(player), card.id, need)
        return false, need
    end
    local ok, err = pcall(card.open, player)
    if ok then log("%s opened the %s window from the HARMONIE tab", nameOf(player), card.id)
    else log("opening the %s window FAILED: %s", card.id, tostring(err)) end
    return ok
end

HARMONIE_HubPanel = ISPanel:derive("HARMONIE_HubPanel")
local P = HARMONIE_HubPanel
P.DESIRED_W = 470
local COL = {
    bg = { 0.04, 0.035, 0.05 }, card = { 0.08, 0.07, 0.10 }, cardHi = { 0.13, 0.11, 0.16 },
    gold = { 0.94, 0.77, 0.33 }, text = { 0.93, 0.92, 0.95 }, dim = { 0.66, 0.64, 0.70 }, warn = { 1.0, 0.78, 0.30 },
    btn = { 0.34, 0.26, 0.08 },
}

function P:new(x, y, w, h, playerNum)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum or 0
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.buttons = {}
    return o
end

function P:player() return getSpecificPlayer and getSpecificPlayer(self.playerNum) or getPlayer() end

function P:prerender()
    pcall(function() self:setWidthAndParentWidth(math.max(self:getWidth(), P.DESIRED_W)) end)
    if self.wantH then pcall(function() self:setHeightAndParentHeight(math.max(160, math.min(self.wantH, 760))) end) end
    self:drawRect(0, 0, self.width, self.height, 0.92, COL.bg[1], COL.bg[2], COL.bg[3])
end

local function th(font) return getTextManager():getFontHeight(font) end
local function tw(font, s) return getTextManager():MeasureStringX(font, s) end
local function wrap(text, maxW, font)
    local lines, line = {}, ""
    for word in tostring(text):gmatch("%S+") do
        local try = line == "" and word or (line .. " " .. word)
        if tw(font, try) > maxW and line ~= "" then lines[#lines + 1] = line; line = word else line = try end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

function P:render()
    local p = self:player()
    local sf, mf = UIFont.Small, UIFont.Medium
    local y, pad = 10, 12
    local icon = Boot.icon and Boot.icon()
    if icon then self:drawTextureScaled(icon, pad, y, 28, 28, 1, 1, 1, 1) end
    self:drawText(T("IGUI_HUB_Title"), pad + 36, y + 4, COL.gold[1], COL.gold[2], COL.gold[3], 1, mf)
    y = y + 40
    for _, l in ipairs(wrap(T("IGUI_HUB_Intro"), self.width - pad * 2, sf)) do
        self:drawText(l, pad, y, COL.dim[1], COL.dim[2], COL.dim[3], 1, sf); y = y + th(sf) + 1
    end
    y = y + 8
    self.buttons = {}
    local mx, my = self:getMouseX(), self:getMouseY()
    local shown = 0
    for _, card in ipairs(Hub.CARDS) do
        local okP, present = pcall(card.present)
        if okP and present then
            shown = shown + 1
            local need = card.need and p and select(2, pcall(card.need, p)) or nil
            local desc = wrap(T(card.desc), self.width - pad * 2 - 130, sf)
            local h = math.max(58, 12 + th(mf) + 4 + #desc * (th(sf) + 1) + (need and (th(sf) + 4) or 0) + 8)
            local over = mx >= pad and mx <= self.width - pad and my >= y and my <= y + h
            local c = over and COL.cardHi or COL.card
            self:drawRect(pad, y, self.width - pad * 2, h, 0.95, c[1], c[2], c[3])
            self:drawRect(pad, y, 3, h, 1, COL.gold[1], COL.gold[2], COL.gold[3])
            self:drawText(T(card.name), pad + 12, y + 8, COL.text[1], COL.text[2], COL.text[3], 1, mf)
            local ty = y + 12 + th(mf)
            for _, l in ipairs(desc) do self:drawText(l, pad + 12, ty, COL.dim[1], COL.dim[2], COL.dim[3], 1, sf); ty = ty + th(sf) + 1 end
            if need then
                self:drawText(T(need), pad + 12, ty + 2, COL.warn[1], COL.warn[2], COL.warn[3], 1, sf)
            end
            -- the open button on the right
            local bw, bh = 104, 28
            local bx, by = self.width - pad - bw - 10, y + math.floor((h - bh) / 2)
            local enabled = not need
            local b = { x = bx, y = by, w = bw, h = bh, card = card }
            local bover = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
            self:drawRect(bx, by, bw, bh, enabled and (bover and 1 or 0.85) or 0.35, COL.btn[1], COL.btn[2], COL.btn[3])
            self:drawRectBorder(bx, by, bw, bh, enabled and 1 or 0.4, COL.gold[1], COL.gold[2], COL.gold[3])
            local label = T("IGUI_HUB_Open")
            self:drawText(label, bx + math.floor((bw - tw(sf, label)) / 2), by + math.floor((bh - th(sf)) / 2),
                enabled and COL.text[1] or COL.dim[1], enabled and COL.text[2] or COL.dim[2], enabled and COL.text[3] or COL.dim[3], 1, sf)
            if enabled then self.buttons[#self.buttons + 1] = b end
            y = y + h + 8
        end
    end
    if shown == 0 then
        self:drawText(T("IGUI_HUB_None"), pad, y, COL.dim[1], COL.dim[2], COL.dim[3], 1, sf); y = y + th(sf) + 8
    end
    self.wantH = y + 6
end

function P:onMouseDown(x, y)
    for _, b in ipairs(self.buttons or {}) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            pcall(function() getSoundManager():playUISound("UISelectListItem") end)
            Hub.openCard(b.card, self:player())
            return true
        end
    end
    return true
end

function Hub.hookCharacterWindow()
    if Hub.charHooked then return end
    if not (ISCharacterInfoWindow and ISCharacterInfoWindow.createChildren) then
        logOnce("nochar", "ISCharacterInfoWindow not found -- no HARMONIE tab")
        return
    end
    Hub.charHooked = true
    local orig = ISCharacterInfoWindow.createChildren
    ISCharacterInfoWindow.createChildren = function(self, ...)
        orig(self, ...)
        if not self.panel then return end
        local ok, err = pcall(function()
            local view = HARMONIE_HubPanel:new(0, 8, self.panel:getWidth(), self.height - 8, self.playerNum)
            view:initialise()
            self.panel:addView(T("IGUI_HUB_Tab"), view)
            self.harmonieHubView = view
        end)
        if ok then logOnce("tab", "HARMONIE tab added to the character window")
        else log("adding the HARMONIE tab FAILED: %s", tostring(err)) end
    end
    log("character window: HARMONIE tab ready")
end

-- ------------------------------------------------------------------ 3. debug
-- our sandbox pages (the "option NS.Name" prefix of each mod's sandbox-options.txt)
Hub.NAMESPACES = {
    { ns = "HARMONIE_GardenToPlate", label = "Garden to Plate" },
    { ns = "HARMONIE_TheWayToAttack", label = "The Way To Attack" },
    { ns = "ExtensiveHealthRework", label = "How to Survive: health" },
    { ns = "HomeMedic", label = "How to Survive" },
    { ns = "TOC", label = "How to Survive: amputation" },
    { ns = "MultiplierConfig", label = "How to Survive: multipliers" },
    { ns = "HARMONIE_SVU3PartWear", label = "Car for Crash" },
    { ns = "HARMONIE_ModernFirearmsSystemFix", label = "Mercenary Is Life: HARMONIE" },
    { ns = "MFSSandbox", label = "Mercenary Is Life" },
    { ns = "MFSEject", label = "Mercenary Is Life: eject" },
    { ns = "MFSCommunityFixLoot", label = "Mercenary Is Life: loot" },
    { ns = "MFSCommunityFixGunRates", label = "Mercenary Is Life: gun rates" },
    { ns = "ModernFirearmsSystemSandboxGun", label = "Mercenary Is Life: guns on/off" },
}

-- every sandbox option of ours -> { [ns] = { {name, label, type, opt} } }
function Hub.collectOptions()
    local so = getSandboxOptions and getSandboxOptions()
    local wanted = {}
    for _, n in ipairs(Hub.NAMESPACES) do wanted[n.ns] = true end
    local out, total = {}, 0
    local count = so and tonumber(call(so, "getNumOptions")) or 0
    for i = 0, count - 1 do
        local opt = call(so, "getOptionByIndex", i)
        local co = opt and (call(opt, "asConfigOption") or opt)
        local name = co and call(co, "getName")
        local ns = name and tostring(name):match("^([^%.]+)%.")
        if ns and wanted[ns] then
            local label = call(opt, "getTranslatedName")
            out[ns] = out[ns] or {}
            out[ns][#out[ns] + 1] = { name = tostring(name), short = tostring(name):sub(#ns + 2), label = label and tostring(label) or nil,
                type = tostring(call(co, "getType") or "?"), opt = opt, co = co }
            total = total + 1
        end
    end
    logOnce("collect", "debug: %d sandbox options of ours found (of %d)", total, count)
    return out, total
end

-- one value: parsed into the game's own option (so it is saved), mirrored
-- into SandboxVars (so our code sees it at once); MP: sent to the server
function Hub.setOption(entry, text, player)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local old = tostring(call(entry.co, "getValueAsString") or "?")
    if text == old then return false end
    local ok, err = pcall(function() entry.co:parse(text) end)
    if not ok then
        log("%s: %s = %q was not accepted (%s)", nameOf(player), entry.name, text, tostring(err))
        return false
    end
    local now = tostring(call(entry.co, "getValueAsString") or text)
    local ns = entry.name:match("^([^%.]+)%.")
    if SandboxVars then
        SandboxVars[ns] = SandboxVars[ns] or {}
        local v = now
        if now == "true" then v = true elseif now == "false" then v = false elseif tonumber(now) then v = tonumber(now) end
        SandboxVars[ns][entry.short] = v
    end
    log("%s set %s: %s -> %s", nameOf(player), entry.name, old, now)
    return true
end

function Hub.applyAll(changed, player)
    if changed == 0 then return end
    local so = getSandboxOptions and getSandboxOptions()
    if isClient and isClient() then
        local ok, err = pcall(function() so:sendToServer() end)
        log("%d sandbox change(s) sent to the server%s", changed, ok and "" or (" -- FAILED: " .. tostring(err)))
    else
        local ok, err = pcall(function() so:toLua() end)
        if not ok then logOnce("tolua", "SandboxOptions:toLua failed (%s) -- SandboxVars were set directly", tostring(err)) end
        log("%d sandbox change(s) applied", changed)
    end
    -- our mods that cache sandbox values read them again
    if HARMONIE_GTP and HARMONIE_GTP.RefreshFromSandbox then pcall(HARMONIE_GTP.RefreshFromSandbox) end
end

HARMONIE_HubSandbox = ISPanel:derive("HARMONIE_HubSandbox")
local S = HARMONIE_HubSandbox
S.ROWS = 13
S.ROW_H = 30

function S:new(player)
    local w, h = 820, 40 + 34 + S.ROWS * S.ROW_H + 60
    local core = getCore()
    local o = ISPanel:new(math.floor((core:getScreenWidth() - w) / 2), math.floor((core:getScreenHeight() - h) / 2), w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.moveWithMouse = true
    o.backgroundColor = { r = 0.04, g = 0.035, b = 0.05, a = 0.97 }
    o.borderColor = { r = 0.94, g = 0.77, b = 0.33, a = 1 }
    o.opts, o.total = Hub.collectOptions()
    o.nsList = {}
    for _, n in ipairs(Hub.NAMESPACES) do if o.opts[n.ns] then o.nsList[#o.nsList + 1] = n end end
    o.ns = o.nsList[1] and o.nsList[1].ns or nil
    o.page = 1
    o.entries = {}
    o.message = ""
    return o
end

function S:createChildren()
    ISPanel.createChildren(self)
    local by = self.height - 42
    local function btn(x, w, label, fn)
        local b = ISButton:new(x, by, w, 30, label, self, fn)
        b:initialise(); b:instantiate()
        b.borderColor = { r = 0.94, g = 0.77, b = 0.33, a = 1 }
        self:addChild(b)
        return b
    end
    btn(self.width - 120, 108, T("IGUI_HUB_Close"), S.onClose)
    btn(self.width - 240, 108, T("IGUI_HUB_Apply"), S.onApply)
    btn(210, 60, "<", S.onPrev)
    btn(276, 60, ">", S.onNext)
    self:buildRows()
end

function S:rows()
    return (self.ns and self.opts[self.ns]) or {}
end

function S:buildRows()
    for _, e in ipairs(self.entries) do self:removeChild(e.box) end
    self.entries = {}
    local list = self:rows()
    local start = (self.page - 1) * S.ROWS
    for i = 1, S.ROWS do
        local entry = list[start + i]
        if not entry then break end
        local y = 74 + (i - 1) * S.ROW_H
        local box = ISTextEntryBox:new(tostring(call(entry.co, "getValueAsString") or ""), self.width - 210, y, 190, 24)
        box.font = UIFont.Small
        box:initialise(); box:instantiate()
        self:addChild(box)
        self.entries[#self.entries + 1] = { box = box, entry = entry }
    end
end

function S:prerender()
    ISPanel.prerender(self)
    local sf, mf = UIFont.Small, UIFont.Medium
    local icon = Boot.icon and Boot.icon()
    if icon then self:drawTextureScaled(icon, 10, 8, 24, 24, 1, 1, 1, 1) end
    self:drawText(T("IGUI_HUB_DebugTitle", tostring(self.total)), 42, 10, COL.gold[1], COL.gold[2], COL.gold[3], 1, mf)
    -- the mods on the left
    self.nsRects = {}
    local y = 44
    for _, n in ipairs(self.nsList) do
        local active = n.ns == self.ns
        local r = { x = 10, y = y, w = 186, h = 24, ns = n.ns }
        self:drawRect(r.x, r.y, r.w, r.h, active and 0.95 or 0.5, active and 0.34 or 0.10, active and 0.26 or 0.09, active and 0.08 or 0.12)
        self:drawText(n.label, r.x + 6, r.y + 4, active and COL.text[1] or COL.dim[1], active and COL.text[2] or COL.dim[2], active and COL.text[3] or COL.dim[3], 1, sf)
        self.nsRects[#self.nsRects + 1] = r
        y = y + 26
    end
    -- the options of the chosen one
    local list = self:rows()
    local pages = math.max(1, math.ceil(#list / S.ROWS))
    self:drawText(T("IGUI_HUB_Page", tostring(self.page), tostring(pages), tostring(#list)), 210, 44, COL.dim[1], COL.dim[2], COL.dim[3], 1, sf)
    for i, e in ipairs(self.entries) do
        local ry = 74 + (i - 1) * S.ROW_H
        local label = e.entry.label and e.entry.label ~= "" and e.entry.label or e.entry.short
        local maxW = self.width - 210 - 222
        while #label > 4 and tw(sf, label) > maxW do label = label:sub(1, #label - 2) end
        self:drawText(label, 210, ry + 2, COL.text[1], COL.text[2], COL.text[3], 1, sf)
        self:drawText(e.entry.short .. "  (" .. e.entry.type .. ")", 210, ry + 15, 0.5, 0.48, 0.55, 1, UIFont.NewSmall or sf)
    end
    if self.message ~= "" then self:drawText(self.message, 350, self.height - 36, COL.warn[1], COL.warn[2], COL.warn[3], 1, sf) end
end

function S:onMouseDown(x, y)
    for _, r in ipairs(self.nsRects or {}) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            self.ns = r.ns; self.page = 1; self:buildRows()
            return true
        end
    end
    return ISPanel.onMouseDown(self, x, y)
end
function S:onPrev() if self.page > 1 then self.page = self.page - 1; self:buildRows() end end
function S:onNext()
    if self.page * S.ROWS < #self:rows() then self.page = self.page + 1; self:buildRows() end
end
function S:onApply()
    if not Hub.isAdmin(self.player) then
        self.message = T("IGUI_HUB_NotAdmin"); log("%s pressed Apply without admin rights -- nothing sent", nameOf(self.player)); return
    end
    local changed = 0
    for _, e in ipairs(self.entries) do
        if Hub.setOption(e.entry, e.box:getText(), self.player) then changed = changed + 1 end
    end
    Hub.applyAll(changed, self.player)
    self.message = T("IGUI_HUB_Applied", tostring(changed))
    self:buildRows()
end
function S:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    if Hub.sandboxWindow == self then Hub.sandboxWindow = nil end
end

function Hub.openSandbox(player)
    if Hub.sandboxWindow then Hub.sandboxWindow:onClose() end
    local w = HARMONIE_HubSandbox:new(player)
    w:initialise()
    w:addToUIManager()
    Hub.sandboxWindow = w
    log("%s opened the HARMONIE sandbox values", nameOf(player))
end

function Hub.onDebugMenu(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer and getSpecificPlayer(playerNum)
    if not player or not context then return end
    local admin, why = Hub.isAdmin(player)
    if not admin then return end
    logOnce("debugmenu", "HARMONIE debug menu offered (%s)", tostring(why))
    local parent = context:addOption(T("IGUI_HUB_Debug"), nil, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)
    local icon = Boot.icon and Boot.icon()
    local function add(label, fn)
        local o = sub:addOption(label, player, function(p)
            log("%s: debug > %s", nameOf(p), label)
            local ok, err = pcall(fn, p)
            if not ok then log("debug > %s FAILED: %s", label, tostring(err)) end
        end)
        if icon and o then o.iconTexture = icon end
    end
    add(T("IGUI_HUB_DebugSandbox"), function(p) Hub.openSandbox(p) end)
    if HARMONIE_AdminPanel and HARMONIE_AdminPanel.Open then
        add(T("IGUI_HUB_DebugGTP"), function(p) HARMONIE_AdminPanel.Open(p) end)
    end
    if TWAWeaponDebugWindow and TWAWeaponDebugWindow.open then
        local w = call(player, "getPrimaryHandItem")
        if w and instanceof(w, "HandWeapon") then add(T("IGUI_HUB_DebugTWA"), function(p) TWAWeaponDebugWindow.open(p, w) end) end
    end
    if EHR and EHR.DebugV2 and EHR.DebugV2.Toggle then
        add(T("IGUI_HUB_DebugHM"), function() EHR.DebugV2.Toggle() end)
    end
end

-- ------------------------------------------------------------------ setup
Hub.hookMenus()
Hub.hookCharacterWindow()
if Events then
    if Events.OnFillWorldObjectContextMenu then
        Events.OnFillWorldObjectContextMenu.Add(HARMONIE_Ours and HARMONIE_Ours(Hub.onDebugMenu, "debug") or Hub.onDebugMenu)
    end
    -- another mod may replace the menu functions after us: hook again
    if Events.OnGameStart then Events.OnGameStart.Add(Hub.hookMenus) end
end
log("HARMONIE hub %d ready (shared by our mods)", Hub.VERSION)

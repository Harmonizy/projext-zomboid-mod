--============================================================================
-- HARMONIE - From Garden to Plate -- the vitamin guide window (client)
--
-- Request 2026-10-05 ("ทำหน้าจอสีเขียวสำหรับ gardentoplate เปิดเพื่อดูคู่มือ
-- ว่าผลเสียการขาดวิตามินนั้นๆคืออะไร วิตามินแต่ละอันหามาได้จากอะไรบ้างเอาให้ครบ
-- พร้อมรูปประกอบของ vanilla และอื่นๆที่คิดว่าควรมี ผูกให้เปิดปิดกับหน้าต่าง
-- ... เช่นหน้าต่างโภชนาการ ไม่ใช่จากแท็บค่าสถานะตัวละครของ ehr"): the same
-- window layout as Home Medic / The Way To Attack / the SVU3 window -- a
-- header bar (title, text size, pin, close), a row of big icon tabs, the
-- content in cards -- in green:
--   1 overview  your own vitamin bands, how the system works, where to
--               see your status
--   2 vitamins  per vitamin: what goes wrong when it is short, how much a
--               day, and EVERY food that has it (picture, amount, Reserve
--               per serving)
--   3 foods     every tracked food in one table, A..K side by side,
--               sortable by any column
--   4 other     vitamin pills, home canning, cooking, freshness, what is
--               not tracked, tips
-- All numbers come from the live data (HARMONIE_GTP.FoodVitaminDB,
-- DailyRequirement, Config), so the guide never drifts from the rules.
-- Pictures: the game's own item icons (vanilla food) and this mod's
-- vitamin moodle icons.
--
-- When it opens: together with the Nutritional Assessment window
-- (HARMONIE_NutritionUI.Open calls GTPGuide.onAssessmentOpened), docked
-- beside it, and it closes with it; that window also has a button for it.
-- Options > Mods: "open with the assessment" tick, and an unbound key of
-- its own. Not tied to the character info window (EHR replaces parts of
-- it).
--
-- Everything is drawn in render() except the search box (an
-- ISTextEntryBox, shown on the Vitamins and All foods tabs); the size,
-- text step and pin are kept in Zomboid/Lua/HARMONIE_GTP_Guide.txt.
--
-- Request 2026-10-06 ("ทำตามที่แนะนำเลย อย่าลืมทำช่อง search"): every
-- food's NAME and picture is shown to everyone, but the numbers -- amount,
-- Reserve per serving, the richest-first order -- need the same knowledge
-- as the food tooltip and the Vitamins tab's best-foods list: Cooking 3 or
-- the Nutritionist trait (H.knows). Without it the lists are A-Z and the
-- table only marks which vitamins a food has. A search box filters both
-- lists by name.
--============================================================================

require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"
require "HARMONIEGardenToPlate/HARMONIE_FoodVitaminDatabase"
require "HARMONIEGardenToPlate/HARMONIE_TopFoods"
require "HARMONIEGardenToPlate/HARMONIE_GrowableFoods"
require "HARMONIEGardenToPlate/HARMONIE_ExtraFoodVitamins"
require "HARMONIEGardenToPlate/HARMONIE_SunVitaminD"

GTPGuide = GTPGuide or {}
local H = GTPGuide

-- console.txt: "[HARMONIE_GTP][Guide]" lines (see HARMONIE_VitaminConfig.lua)
local function log(...) if HARMONIE_GTP and HARMONIE_GTP.Log then HARMONIE_GTP.Log("Guide", ...) end end
local function logOnce(key, ...) if HARMONIE_GTP and HARMONIE_GTP.LogOnce then HARMONIE_GTP.LogOnce("Guide:" .. key, "Guide", ...) end end
H.log, H.logOnce = log, logOnce

H.HEADER_H = 40
H.TAB_H = 58
H.CARD_T = 26
H.GRIP = 18
H.DEFAULT_W, H.DEFAULT_H = 940, 660
H.MIN_W, H.MIN_H = 760, 500
H.FOLD_DELAY_MS = 350
H.TABS = { "overview", "check", "vitamins", "foods", "cook", "calendar", "other" }
H.NEAR_TILES = 3 -- how close another survivor must be to check them
H.UNITS = { A = "mcg", B = "mg", C = "mg", D = "mcg", E = "mg", K = "mcg" }
-- 2026-10-08: "Grow" first -- Fruit Farming (B42) by leina is built in
H.OTHER = { "Grow", "Sun", "Dried", "Sprouts", "FishOil", "Pills", "Canning", "Cooking", "Fresh", "NotTracked", "Tips" }

-- green (Home Medic's palette turned leaf green)
H.C = {
    accent = { 0.50, 0.90, 0.52 },
    accentDark = { 0.06, 0.24, 0.10 },
    background = { 0.012, 0.04, 0.018, 0.97 },
    panel = { 0.02, 0.07, 0.03, 0.94 },
    header = { 0.02, 0.075, 0.032, 0.98 },
    card = { 0.03, 0.095, 0.045, 0.93 },
    border = { 0.32, 0.76, 0.40 },
    borderDim = { 0.14, 0.36, 0.18 },
    text = { 0.94, 1.0, 0.94 },
    textDim = { 0.66, 0.82, 0.68 },
    good = { 0.45, 0.90, 0.50 },
    bad = { 1.0, 0.42, 0.38 },
    warn = { 1.0, 0.82, 0.32 },
}

local UI_DIR = "media/textures/GTP_UI/"
local tex = {}
local function texture(path)
    if not path then return nil end
    if tex[path] == nil then tex[path] = getTexture(path) or false end
    return tex[path] or nil
end

-- ----------------------------------------------------------------- text
local FONTS = { "Small", "Medium", "Large" }
H.textStep = 0
local function fontAt(level)
    level = math.max(1, math.min(#FONTS, level))
    return UIFont[FONTS[level]] or UIFont.Small
end
function H.small() return fontAt(1 + H.textStep) end
function H.medium() return fontAt(2 + H.textStep) end
local function fh(font) return getTextManager():getFontHeight(font) end
local function lineH(font) return fh(font) + 2 end
local function tw(font, s) return getTextManager():MeasureStringX(font, s) end

local function T(key, ...)
    local ok, s = pcall(getText, key, ...)
    return ok and s or key
end

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
            if tw(font, try) > maxW and line ~= "" then
                out[#out + 1] = line
                line = word
            else
                line = try
            end
        end
        out[#out + 1] = line
    end
    return out
end

local function inside(r, x, y) return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- ----------------------------------------------------------------- data
local function cfg() return HARMONIE_GTP.Config end

function H.vitName(v) return T("IGUI_HARMONIE_Vitamin_" .. v) end
function H.vitIcon(v) return texture("media/ui/Moodles/128/Vitamin" .. v .. ".png") or texture("media/ui/Vitamin" .. v .. ".png") end

-- Reserve one whole serving of a food gives (the eat hook's own formula:
-- percent of the daily requirement / reserveGainDivisor)
function H.reserveOf(vit, amount)
    local dr = HARMONIE_GTP.DailyRequirement[vit] or 1
    local div = tonumber(cfg().reserveGainDivisor) or 10
    if div <= 0 then div = 10 end
    return (amount or 0) / dr * 100 / div
end

function H.fmt1(v) return string.format("%.1f", v) end

local itemCache = {}
-- display name and picture of an item type (nil when the game has no such item)
function H.item(fullType)
    local c = itemCache[fullType]
    if c ~= nil then return c or nil end
    local ok, si = pcall(function() return getScriptManager():FindItem(fullType) end)
    if not ok or not si then itemCache[fullType] = false return nil end
    local name = fullType
    local okN, n = pcall(si.getDisplayName, si)
    if okN and n and n ~= "" then name = n end
    local icon
    local okT, t = pcall(function() return si:getNormalTexture() end)
    if okT and t then icon = t end
    if not icon then
        local okI, i = pcall(function() return si:getIcon() end)
        if okI and i and i ~= "" then icon = getTexture("Item_" .. i) end
    end
    c = { fullType = fullType, name = name, icon = icon }
    itemCache[fullType] = c
    return c
end

-- every tracked food the game knows, once per name + profile (several
-- type names of the same food -- CannedTomatoOpen / CannedTomato_Open --
-- show once)
function H.foods()
    if H.foodCache then return H.foodCache end
    local list, seen = {}, {}
    for fullType, prof in pairs(HARMONIE_GTP.FoodVitaminDB or {}) do
        -- home-canned jars (4 fresh pieces each) are left out, as in the
        -- Vitamins tab's best-foods list (HARMONIE_TopFoods); the canning
        -- section explains them
        local it = not fullType:find("HomeCanned", 1, true) and H.item(fullType)
        if it then
            local parts = {}
            for _, v in ipairs(HARMONIE_GTP.Vitamins) do parts[#parts + 1] = tostring(prof[v] or 0) end
            local key = it.name .. "|" .. table.concat(parts, ",")
            if not seen[key] then
                seen[key] = true
                list[#list + 1] = { fullType = fullType, name = it.name, icon = it.icon, prof = prof,
                    canned = fullType:find("HomeCanned", 1, true) ~= nil,
                    grow = HARMONIE_GTP.IsGrowable and HARMONIE_GTP.IsGrowable(fullType) or false }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.fullType < b.fullType
    end)
    H.foodCache = list
    return list
end

-- the foods with vitamin `v`, richest first
function H.foodsWith(v)
    H.byVit = H.byVit or {}
    if H.byVit[v] then return H.byVit[v] end
    local out = {}
    for _, f in ipairs(H.foods()) do
        if (f.prof[v] or 0) > 0 then out[#out + 1] = f end
    end
    table.sort(out, function(a, b)
        if a.prof[v] ~= b.prof[v] then return a.prof[v] > b.prof[v] end
        return a.name < b.name
    end)
    H.byVit[v] = out
    return out
end

function H.bandOf(player, v)
    local ok, val = pcall(HARMONIE_GTP.VitData.Get, player, v)
    if not ok or not val then return nil end
    return HARMONIE_GTP.GetBand(val)
end

-- the numbers need Cooking 3 or the Nutritionist trait (see the header)
H.KNOW_COOKING = 3
function H.knows(player)
    if not player then return false end
    local ok, lvl = pcall(function() return player:getPerkLevel(Perks.Cooking) end)
    if ok and (tonumber(lvl) or 0) >= H.KNOW_COOKING then return true end
    local ok2, t = pcall(function() return player:hasTrait(CharacterTrait.NUTRITIONIST) end)
    return ok2 and t == true
end

-- the search text matches the food's shown name (or its item type)
function H.matches(f, q)
    if not q or q == "" then return true end
    if string.lower(f.name):find(q, 1, true) then return true end
    return string.lower(f.fullType):find(q, 1, true) ~= nil
end

-- the foods with vitamin `v`, A-Z (what someone without the knowledge sees)
function H.foodsWithByName(v)
    H.byVitName = H.byVitName or {}
    if H.byVitName[v] then return H.byVitName[v] end
    local out = {}
    for _, f in ipairs(H.foods()) do
        if (f.prof[v] or 0) > 0 then out[#out + 1] = f end
    end
    H.byVitName[v] = out
    return out
end

local BAND_COL = { critical = "bad", low = "warn", sufficient = "good" }
local BAND_KEY = { critical = "IGUI_HARMONIE_Band_Critical", low = "IGUI_HARMONIE_Band_Low", sufficient = "IGUI_HARMONIE_Band_Sufficient" }

-- ----------------------------------------------------------------- prefs
H.PREFS_FILE = "HARMONIE_GTP_Guide.txt"
H.pinned = true
function H.ensurePrefs()
    if H.prefsLoaded then return end
    H.prefsLoaded = true
    if not getFileReader then return end
    local ok, reader = pcall(getFileReader, H.PREFS_FILE, true)
    if not ok or not reader then return end
    pcall(function()
        local line = reader:readLine()
        while line do
            local k, v = line:match("^%s*([%w_]+)%s*=%s*(%S+)")
            if k == "w" then H.prefW = tonumber(v)
            elseif k == "h" then H.prefH = tonumber(v)
            elseif k == "text" then H.textStep = math.max(0, math.min(2, math.floor(tonumber(v) or 0)))
            elseif k == "pinned" then H.pinned = v ~= "0" end
            line = reader:readLine()
        end
    end)
    pcall(function() reader:close() end)
    log("prefs loaded: size %sx%s, text step %s, pinned %s", tostring(H.prefW), tostring(H.prefH), tostring(H.textStep), tostring(H.pinned))
end

function H.savePrefs()
    if not getFileWriter then return end
    local ok, writer = pcall(getFileWriter, H.PREFS_FILE, true, false)
    if not ok or not writer then log("could not write %s: %s", tostring(H.PREFS_FILE), tostring(writer)); return end
    pcall(function()
        if H.prefW then writer:write("w=" .. tostring(math.floor(H.prefW)) .. "\n") end
        if H.prefH then writer:write("h=" .. tostring(math.floor(H.prefH)) .. "\n") end
        writer:write("text=" .. tostring(H.textStep) .. "\n")
        writer:write("pinned=" .. (H.pinned and "1" or "0") .. "\n")
    end)
    pcall(function() writer:close() end)
end

-- ----------------------------------------------------------------- window
GTPGuideWindow = ISPanel:derive("GTPGuideWindow")
local Win = GTPGuideWindow

function Win:new(x, y, w, h, player)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.tab = "overview"
    o.vit = "A"
    o.sortKey = "name"
    o.scroll = {}
    o.maxScroll = {}
    o.moveWithMouse = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    return o
end

function Win:contentTop() return H.HEADER_H + H.TAB_H + 6 end

-- the search box (the only child widget); built again when the text size
-- changes, keeping what was typed
function Win:createChildren()
    ISPanel.createChildren(self)
    self:buildSearch("")
end

function Win:buildSearch(text)
    if self.search then
        self:removeChild(self.search)
        self.search = nil
    end
    local font = H.small()
    local box = ISTextEntryBox:new(text or "", 0, 0, 200, lineH(font) + 6)
    box.font = font
    box:initialise()
    box:instantiate()
    if box.setPlaceholderText then box:setPlaceholderText(T("IGUI_GTPG_SearchHint")) end
    self:addChild(box)
    box:setVisible(false)
    self.search = box
    self.searchFont = font
end

function Win:query()
    if not self.search then return "" end
    local ok, t = pcall(self.search.getText, self.search)
    t = ok and t or ""
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    return string.lower(t)
end

-- puts the box (and its clear button) at x, y, w on this frame; returns
-- the height used
function Win:placeSearch(x, y, w, noToggle)
    local box = self.search
    if not box then return 0 end
    if self.searchFont ~= H.small() then
        self:buildSearch(box:getText())
        box = self.search
    end
    local h = box.height
    local sf = H.small()
    local growLabel = T("IGUI_GTPG_GrowOnly")
    local gw = tw(sf, growLabel) + 34
    local bw = noToggle and (w - h - 4) or (w - h - 4 - gw - 6)
    if box.x ~= x or box.y ~= y or box.width ~= bw then
        box:setX(x)
        box:setY(y)
        box:setWidth(bw)
    end
    self.searchShown = true
    local C = H.C
    local clear = { x = x + bw + 4, y = y, w = h, h = h, clear = true }
    local has = self:query() ~= ""
    self:drawRect(clear.x, clear.y, clear.w, clear.h, has and 0.9 or 0.4, 0.04, 0.16, 0.07)
    self:drawRectBorder(clear.x, clear.y, clear.w, clear.h, has and 1 or 0.5, C.border[1], C.border[2], C.border[3])
    local icon = texture(UI_DIR .. "icon_close.png")
    if icon then self:drawTextureScaled(icon, clear.x + 3, clear.y + 3, clear.w - 6, clear.h - 6, has and 1 or 0.35, 1, 1, 1) end
    if has then self.clicks[#self.clicks + 1] = clear end
    if noToggle then return h end
    -- "can grow only" toggle (2026-10-08)
    local g = { x = clear.x + clear.w + 6, y = y, w = gw, h = h }
    local on = self.growOnly == true
    local over = inside(g, self:getMouseX(), self:getMouseY())
    self:drawRect(g.x, g.y, g.w, g.h, on and 0.95 or (over and 0.85 or 0.6), C.accentDark[1], C.accentDark[2], C.accentDark[3])
    self:drawRectBorder(g.x, g.y, g.w, g.h, on and 1 or 0.6, C.border[1], C.border[2], C.border[3])
    local bs = h - 10
    self:drawRectBorder(g.x + 6, g.y + 5, bs, bs, 1, C.accent[1], C.accent[2], C.accent[3])
    if on then self:drawRect(g.x + 9, g.y + 8, bs - 6, bs - 6, 1, C.accent[1], C.accent[2], C.accent[3]) end
    shadowText(self, growLabel, g.x + bs + 12, g.y + math.floor((h - fh(sf)) / 2), on and C.text or C.textDim, 1, sf)
    g.action = function(win) win.growOnly = not win.growOnly; win.sortedFor = nil; log("Can grow filter: %s", tostring(win.growOnly)) end
    self.clicks[#self.clicks + 1] = g
    return h
end

-- the search text and the "can grow only" toggle
function Win:keep(f, q)
    if self.growOnly and not f.grow then return false end
    return H.matches(f, q)
end

-- a food's name with its "(can grow)" mark
local function foodLabel(f)
    if f.grow then return f.name .. " " .. T("IGUI_GTPG_GrowMark") end
    return f.name
end

function Win:headerButtons()
    local s = 26
    local y = math.floor((H.HEADER_H - s) / 2)
    local x = self.width - s - 8
    local b = {}
    for _, id in ipairs({ "close", "pin", "settings", "plus", "minus" }) do
        b[#b + 1] = { id = id, x = x, y = y, w = s, h = s }
        x = x - s - 6
    end
    return b
end

-- ----------------------------------------------------------------- drawing
function Win:drawCard(x, y, w, h, title, icon)
    local C = H.C
    self:drawRect(x, y, w, h, C.card[4], C.card[1], C.card[2], C.card[3])
    self:drawRectBorder(x, y, w, h, 0.75, C.borderDim[1], C.borderDim[2], C.borderDim[3])
    local th = H.CARD_T
    self:drawRect(x + 1, y + 1, w - 2, th - 1, 0.6, C.accentDark[1], C.accentDark[2], C.accentDark[3])
    self:drawRect(x + 6, y + th - 1, w - 12, 1, 0.8, C.border[1], C.border[2], C.border[3])
    local k = 9
    for _, c in ipairs({ { x, y, 1, 1 }, { x + w, y, -1, 1 }, { x, y + h, 1, -1 }, { x + w, y + h, -1, -1 } }) do
        local cx, cy, dx, dy = c[1], c[2], c[3], c[4]
        self:drawRect(dx > 0 and cx or cx - k, dy > 0 and cy or cy - 2, k, 2, 0.95, C.accent[1], C.accent[2], C.accent[3])
        self:drawRect(dx > 0 and cx or cx - 2, dy > 0 and cy or cy - k, 2, k, 0.95, C.accent[1], C.accent[2], C.accent[3])
    end
    if title and title ~= "" then
        local font = H.small()
        local tx = x + 16
        if icon then
            self:drawTextureScaled(icon, x + 8, y + 4, th - 8, th - 8, 1, 1, 1, 1)
            tx = x + th + 6
        else
            self:drawRect(x + 8, y + math.floor((th - 8) / 2), 3, 8, 1, C.accent[1], C.accent[2], C.accent[3])
        end
        shadowText(self, fit(title, x + w - 8 - tx, font), tx, y + math.floor((th - fh(font)) / 2), C.accent, 1, font)
    end
    return x + 10, y + th + 6, w - 20, h - th - 12
end

function Win:drawBar(x, y, w, h, frac, col)
    local C = H.C
    self:drawRect(x, y, w, h, 0.9, 0.04, 0.12, 0.05)
    self:drawRect(x, y, math.floor(w * math.max(0, math.min(1, frac))), h, 1, col[1], col[2], col[3])
    self:drawRectBorder(x, y, w, h, 0.8, C.borderDim[1], C.borderDim[2], C.borderDim[3])
end

function Win:prerender()
    local C = H.C
    local hh, th = H.HEADER_H, H.TAB_H
    self:drawRect(0, 0, self.width, self.height, C.background[4], C.background[1], C.background[2], C.background[3])
    self:drawRectBorder(0, 0, self.width, self.height, 1, C.border[1], C.border[2], C.border[3])
    self:drawRect(1, 1, self.width - 2, hh - 1, C.header[4], C.header[1], C.header[2], C.header[3])
    self:drawRect(0, hh - 1, self.width, 1, 0.8, C.border[1], C.border[2], C.border[3])
    local font = H.medium()
    local ix = 10
    local logo = texture(UI_DIR .. "tab_vitamins.png")
    if logo then
        self:drawTextureScaled(logo, ix, math.floor((hh - 28) / 2), 28, 28, 1, 1, 1, 1)
        ix = ix + 34
    end
    shadowText(self, fit(T("IGUI_GTPG_Title"), self.width - ix - 150, font), ix, math.floor((hh - fh(font)) / 2), C.accent, 1, font)
    self.hoverTip = nil
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, b in ipairs(self:headerButtons()) do
        local over = inside(b, mx, my)
        local tint = b.id == "close" and { 0.95, 0.4, 0.35 } or C.accent
        self:drawRect(b.x, b.y, b.w, b.h, over and 0.95 or 0.75, 0.04, 0.16, 0.07)
        self:drawRectBorder(b.x, b.y, b.w, b.h, over and 1 or 0.7, tint[1], tint[2], tint[3])
        local name = b.id == "pin" and (H.pinned and "pin_on" or "pin_off") or ("icon_" .. b.id)
        local icon = texture(UI_DIR .. name .. ".png")
        local disabled = (b.id == "plus" and H.textStep >= 2) or (b.id == "minus" and H.textStep <= 0)
        if icon then self:drawTextureScaled(icon, b.x + 3, b.y + 3, b.w - 6, b.h - 6, disabled and 0.35 or 1, 1, 1, 1) end
        if over then
            local key = ({ close = "IGUI_GTPG_Close", pin = H.pinned and "IGUI_GTPG_Unpin" or "IGUI_GTPG_Pin", settings = "IGUI_GTPG_Settings",
                plus = "IGUI_GTPG_TextBigger", minus = "IGUI_GTPG_TextSmaller" })[b.id]
            self.hoverTip = { text = T(key), x = b.x - 40, y = b.y + b.h + 4 }
        end
    end
    if self.collapsed then return end
    self:drawRect(1, hh, self.width - 2, th, 0.92, 0.012, 0.05, 0.02)
    self:drawRect(0, hh + th - 1, self.width, 1, 0.8, C.border[1], C.border[2], C.border[3])
    local gap = 5
    local tabW = math.floor((self.width - 16 - gap * (#H.TABS - 1)) / #H.TABS)
    local x = 8
    self.tabBounds = {}
    local sf = H.small()
    for _, id in ipairs(H.TABS) do
        local active = self.tab == id and not self.settingsOpen
        local ty, tH = hh + 6, th - 12
        local bg = active and C.accentDark or C.background
        local bd = active and C.accent or C.borderDim
        self:drawRect(x, ty, tabW, tH, active and 0.98 or 0.82, bg[1], bg[2], bg[3])
        self:drawRectBorder(x, ty, tabW, tH, active and 0.95 or 0.62, bd[1], bd[2], bd[3])
        if active then
            self:drawRect(x + 2, ty + 2, tabW - 4, tH - 4, 0.16, C.accent[1], C.accent[2], C.accent[3])
            self:drawRect(x + 3, ty + tH - 5, tabW - 6, 2, 0.75, C.accent[1], C.accent[2], C.accent[3])
        end
        local size = math.min(tH - 8, 40)
        local label = fit(T("IGUI_GTPG_Tab_" .. id), tabW - size - 24, sf)
        local icon = texture(UI_DIR .. "tab_" .. id .. ".png")
        local total = size + 8 + tw(sf, label)
        local tx = x + math.floor((tabW - total) / 2)
        if icon then self:drawTextureScaled(icon, tx, ty + math.floor((tH - size) / 2), size, size, active and 1 or 0.65, 1, 1, 1) end
        shadowText(self, label, tx + size + 8, ty + math.floor((tH - fh(sf)) / 2), active and C.text or C.textDim, 1, sf)
        local bounds = { id = id, x = x, y = ty, w = tabW, h = tH }
        self.tabBounds[#self.tabBounds + 1] = bounds
        if inside(bounds, mx, my) then
            self.hoverTip = { text = T("IGUI_GTPG_Tab_" .. id .. "_Tip"), x = x + 30, y = ty + tH + 4 }
        end
        x = x + tabW + gap
    end
    local top = hh + th + 2
    self:drawRect(4, top, self.width - 8, self.height - top - 4, C.panel[4], C.panel[1], C.panel[2], C.panel[3])
end

function Win:render()
    if not self.collapsed then
        self.clicks = {}
        self.searchShown = false
        self.scrollBox = {}
        local x, y = 8, self:contentTop()
        local w, h = self.width - 16, self.height - y - 8
        if self.settingsOpen then self:renderSettings(x, y, w, h)
        elseif self.tab == "check" then self:renderCheck(x, y, w, h)
        elseif self.tab == "calendar" then self:renderCalendar(x, y, w, h)
        elseif self.tab == "overview" then self:renderOverview(x, y, w, h)
        elseif self.tab == "vitamins" then self:renderVitamins(x, y, w, h)
        elseif self.tab == "foods" then self:renderFoods(x, y, w, h)
        elseif self.tab == "cook" and self.renderCook then self:renderCook(x, y, w, h)
        else self:renderOther(x, y, w, h) end
        if self.search and self.search:getIsVisible() ~= self.searchShown then self.search:setVisible(self.searchShown) end
        local C = H.C
        local gx, gy = self.width - 16, self.height - 16
        for i, len in ipairs({ 12, 8, 4 }) do
            local o = (i - 1) * 4
            self:drawRect(gx + 10 - o, gy + 14 - len, 2, len, 0.85 - 0.15 * (i - 1), C.accent[1], C.accent[2], C.accent[3])
        end
    end
    if self.collapsed and self.search and self.search:getIsVisible() then self.search:setVisible(false) end
    self:drawHoverTip()
    self:updatePin()
end

function Win:drawHoverTip()
    local t = self.hoverTip
    if not t or not t.text or t.text == "" or t.text:find("IGUI_", 1, true) then return end
    local C = H.C
    local font = H.small()
    local lines = wrap(t.text, 360, font)
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, tw(font, l)) end
    w = w + 16
    local h = #lines * lineH(font) + 10
    local x = math.max(4, math.min(self.width - w - 4, t.x))
    local y = math.min(t.y, self.height - h - 4)
    self:drawRect(x, y, w, h, 0.97, 0.02, 0.08, 0.03)
    self:drawRectBorder(x, y, w, h, 1, C.border[1], C.border[2], C.border[3])
    for i, l in ipairs(lines) do shadowText(self, l, x + 8, y + 5 + (i - 1) * lineH(font), C.text, 1, font) end
end

-- scrolled content: draws f(yOffset) clipped to the box, remembers how far it can scroll
function Win:scrolled(key, x, y, w, h, f)
    local off = self.scroll[key] or 0
    -- registered before drawing (hover checks inside f use it); the list
    -- holds only this frame's areas -- render() empties it -- so the mouse
    -- wheel never lands on an area of another tab / vitamin / search that
    -- happens to sit at the same spot (2026-10-08 bug report: "บางอัน
    -- scroll ไม่ได้")
    self.scrollBox = self.scrollBox or {}
    self.scrollBox[key] = { x = x, y = y, w = w, h = h }
    self:setStencilRect(x, y, w, h)
    local used = f(y - off)
    self:clearStencilRect()
    self.maxScroll[key] = math.max(0, (used or 0) - h)
    if off > self.maxScroll[key] then self.scroll[key] = self.maxScroll[key] end
    if self.maxScroll[key] > 0 then
        local C = H.C
        local bh = math.max(20, math.floor(h * h / (h + self.maxScroll[key])))
        local by = y + math.floor((h - bh) * (self.scroll[key] or 0) / self.maxScroll[key])
        self:drawRect(x + w - 4, by, 3, bh, 0.8, C.accent[1], C.accent[2], C.accent[3])
    end
end

-- wrapped paragraphs; returns the height used
function Win:paragraphs(text, x, y, w, col, font)
    font = font or H.small()
    local lh = lineH(font)
    local yy = y
    for _, l in ipairs(wrap(text, w, font)) do
        shadowText(self, l, x, yy, col or H.C.text, 1, font)
        yy = yy + lh
    end
    return yy - y
end

local function clickable(self, r) self.clicks[#self.clicks + 1] = r end

-- the drawing helpers, for the tabs kept in their own files (Cooking)
H.util = { T = T, shadowText = shadowText, fit = fit, wrap = wrap, inside = inside, clickable = clickable,
    lineH = lineH, fh = fh, tw = tw, texture = texture, UI_DIR = UI_DIR }

-- ----------------------------------------------------------------- tab 1
function Win:renderOverview(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local leftW = math.min(320, math.floor(w * 0.36))
    local rowH = math.max(30, lh + 12)
    local statusH = H.CARD_T + 12 + #HARMONIE_GTP.Vitamins * rowH + lh * 2 + 6
    statusH = math.min(statusH, h - 140)
    local cx, cy, cw = self:drawCard(x, y, leftW, statusH, T("IGUI_GTPG_Card_Status"))
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, v in ipairs(HARMONIE_GTP.Vitamins) do
        if cy + rowH > y + statusH - lh * 2 then break end
        local r = { x = cx, y = cy, w = cw, h = rowH - 4, vit = v }
        if inside(r, mx, my) then self:drawRect(r.x, r.y, r.w, r.h, 0.5, C.accentDark[1], C.accentDark[2], C.accentDark[3]) end
        local icon = H.vitIcon(v)
        if icon then self:drawTextureScaled(icon, cx + 2, cy + 1, rowH - 6, rowH - 6, 1, 1, 1, 1) end
        shadowText(self, H.vitName(v), cx + rowH + 2, cy + math.floor((rowH - 4 - fh(sf)) / 2), C.text, 1, sf)
        local band = self.player and H.bandOf(self.player, v)
        if band then
            local bt = T(BAND_KEY[band])
            local pause = HARMONIE_GTP.VitData.GetPauseDays(self.player, v) >= 1
            local mark = pause and " +" or ""
            shadowText(self, bt .. mark, cx + cw - tw(sf, bt .. mark) - 4, cy + math.floor((rowH - 4 - fh(sf)) / 2), C[BAND_COL[band]], 1, sf)
        end
        clickable(self, r)
        cy = cy + rowH
    end
    self:paragraphs(T("IGUI_GTPG_StatusHint"), cx, y + statusH - lh * 2 - 4, cw, C.textDim, sf)
    -- where to see it
    local wy = y + statusH + 8
    local wx, wy2, ww, wh = self:drawCard(x, wy, leftW, h - statusH - 8, T("IGUI_GTPG_Card_WhereToSee"))
    self:scrolled("where", wx, wy2, ww, wh, function(yy)
        return self:paragraphs(T("IGUI_GTPG_WhereToSee", tostring(cfg().assessmentRequiredFirstAid)), wx, yy, ww - 8, C.text, sf)
    end)
    -- how it works
    local rx = x + leftW + 8
    local hx, hy, hw, hh2 = self:drawCard(rx, y, w - leftW - 8, h, T("IGUI_GTPG_Card_HowItWorks"))
    local c = cfg()
    local body = T("IGUI_GTPG_HowItWorks", tostring(c.maxValue), tostring(c.criticalThreshold), tostring(c.sufficientThreshold),
        tostring(c.decayPerDay), H.fmt1(100 / (tonumber(c.reserveGainDivisor) or 10)), tostring(c.reservePerPauseDay))
    local afflictedNote = c.effectsEnabled and T("IGUI_GTPG_EffectsOn") or T("IGUI_GTPG_EffectsOff")
    self:scrolled("how", hx, hy, hw, hh2, function(yy)
        local used = self:paragraphs(body, hx, yy, hw - 8, C.text, sf)
        used = used + 6
        used = used + self:paragraphs(afflictedNote, hx, yy + used, hw - 8, c.effectsEnabled and C.warn or C.textDim, sf)
        return used
    end)
end

-- ----------------------------------------------------------------- tab 2
function Win:renderVitamins(x, y, w, h)
    local C = H.C
    local sf, mf = H.small(), H.medium()
    local lh = lineH(sf)
    local listW = math.min(220, math.floor(w * 0.24))
    local cx, cy, cw = self:drawCard(x, y, listW, h, T("IGUI_GTPG_Card_VitaminList"))
    local mx, my = self:getMouseX(), self:getMouseY()
    local rowH = math.max(40, lineH(mf) + 16)
    for _, v in ipairs(HARMONIE_GTP.Vitamins) do
        if cy + rowH > y + h - 6 then break end
        local r = { x = cx, y = cy, w = cw, h = rowH - 4, vit = v }
        local active = self.vit == v
        if active or inside(r, mx, my) then
            self:drawRect(r.x, r.y, r.w, r.h, active and 0.9 or 0.5, C.accentDark[1], C.accentDark[2], C.accentDark[3])
        end
        if active then self:drawRect(r.x, r.y, 3, r.h, 1, C.accent[1], C.accent[2], C.accent[3]) end
        local icon = H.vitIcon(v)
        if icon then self:drawTextureScaled(icon, cx + 6, cy + 3, rowH - 10, rowH - 10, 1, 1, 1, 1) end
        shadowText(self, fit(H.vitName(v), cw - rowH - 8, mf), cx + rowH + 2, cy + math.floor((rowH - 4 - fh(mf)) / 2), active and C.text or C.textDim, 1, mf)
        clickable(self, r)
        cy = cy + rowH
    end
    local v = self.vit
    local rx = x + listW + 8
    local rw = w - listW - 8
    -- what goes wrong
    local effect = T("IGUI_GTPG_Vit_" .. v .. "_Effect")
    local why = T("IGUI_GTPG_Vit_" .. v .. "_Why")
    local need = T("IGUI_GTPG_DailyNeed", tostring(HARMONIE_GTP.DailyRequirement[v]), H.UNITS[v], H.fmt1(H.reserveOf(v, HARMONIE_GTP.DailyRequirement[v])))
    local innerW = rw - 28
    local topLines = #wrap(effect, innerW, sf) + #wrap(why, innerW, sf) + #wrap(need, innerW, sf)
    local topH = math.min(math.floor(h * 0.5), H.CARD_T + 18 + topLines * lh + 12)
    local ex, ey, ew, eh = self:drawCard(rx, y, rw, topH, T("IGUI_GTPG_Card_WhenShort", H.vitName(v)), H.vitIcon(v))
    self:scrolled("effect" .. v, ex, ey, ew, eh, function(yy)
        local used = self:paragraphs(effect, ex, yy, ew - 8, C.bad, sf)
        used = used + 4 + self:paragraphs(why, ex, yy + used + 4, ew - 8, C.textDim, sf)
        used = used + 4 + self:paragraphs(need, ex, yy + used + 4, ew - 8, C.accent, sf)
        return used
    end)
    -- where to get it: names for everyone, numbers with the knowledge
    local knows = H.knows(self.player)
    local q = self:query()
    local all = knows and H.foodsWith(v) or H.foodsWithByName(v)
    local list = {}
    for _, f in ipairs(all) do if self:keep(f, q) then list[#list + 1] = f end end
    local fy = y + topH + 8
    local titleKey = knows and "IGUI_GTPG_Card_Sources" or "IGUI_GTPG_Card_SourcesLocked"
    local fx, fy2, fw, fh2 = self:drawCard(rx, fy, rw, h - topH - 8, T(titleKey, H.vitName(v), tostring(#list)))
    local used = self:placeSearch(fx, fy2, fw)
    fy2 = fy2 + used + 6
    fh2 = fh2 - used - 6
    if not knows then
        local hint = T("IGUI_GTPG_LockedHint", tostring(H.KNOW_COOKING))
        local hh = self:paragraphs(hint, fx, fy2, fw - 8, C.warn, sf)
        fy2 = fy2 + hh + 4
        fh2 = fh2 - hh - 4
    end
    local top = all[1] and all[1].prof[v] or 1
    local itemH = math.max(30, lh + 14)
    local cols = fw >= 560 and 2 or 1
    local colW = math.floor((fw - 8 - (cols - 1) * 10) / cols)
    self:scrolled("src" .. v .. "|" .. q, fx, fy2, fw, fh2, function(yy)
        local start = yy
        for i, f in ipairs(list) do
            local col = (i - 1) % cols
            local ix = fx + col * (colW + 10)
            if f.icon then self:drawTextureScaled(f.icon, ix, yy + 1, itemH - 4, itemH - 4, 1, 1, 1, 1) end
            local tx = ix + itemH + 2
            local amount = H.fmt1(f.prof[v]) .. " " .. H.UNITS[v]
            local gain = "+" .. H.fmt1(H.reserveOf(v, f.prof[v]))
            local right = knows and gain or ""
            if knows then shadowText(self, right, ix + colW - tw(sf, right) - 4, yy + 1, C.accent, 1, sf) end
            shadowText(self, fit(foodLabel(f), ix + colW - tw(sf, right) - 14 - tx, sf), tx, yy + 1, f.canned and C.warn or C.text, 1, sf)
            if knows then self:drawBar(tx, yy + lh + 2, colW - (tx - ix) - 8, 4, f.prof[v] / top, C.accent) end
            local r = { x = ix, y = yy, w = colW, h = itemH }
            if knows and inside(r, mx, my) and inside(self.scrollBox and self.scrollBox["src" .. v .. "|" .. q], mx, my) then
                self.hoverTip = { text = T("IGUI_GTPG_FoodTip", f.name, amount, gain, H.vitName(v)), x = ix + 20, y = yy + itemH }
            end
            if col == cols - 1 or i == #list then yy = yy + itemH + 4 end
        end
        if #list == 0 then
            shadowText(self, T(q ~= "" and "IGUI_GTPG_NoMatch" or "IGUI_GTPG_NoFoods"), fx, yy, C.textDim, 1, sf)
            yy = yy + lh
        end
        return yy - start
    end)
end

-- ----------------------------------------------------------------- tab 3
function Win:renderFoods(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local foods = H.foods()
    local knows = H.knows(self.player)
    local q = self:query()
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, T("IGUI_GTPG_Card_AllFoods", tostring(#foods)))
    local used = self:placeSearch(cx, cy, math.min(cw, 420))
    cy = cy + used + 6
    if not knows then
        cy = cy + self:paragraphs(T("IGUI_GTPG_LockedHint", tostring(H.KNOW_COOKING)), cx, cy, cw - 8, C.warn, sf) + 4
    end
    -- column headers (click to sort)
    local colW = math.max(54, math.floor((cw - 8) * 0.085))
    local nameW = cw - 8 - colW * #HARMONIE_GTP.Vitamins
    local mx, my = self:getMouseX(), self:getMouseY()
    local hh = math.max(26, lh + 8)
    local heads = { { key = "name", x = cx, w = nameW, label = T("IGUI_GTPG_ColFood") } }
    for i, v in ipairs(HARMONIE_GTP.Vitamins) do
        heads[#heads + 1] = { key = v, x = cx + nameW + (i - 1) * colW, w = colW, label = v }
    end
    for _, hd in ipairs(heads) do
        local r = { x = hd.x, y = cy, w = hd.w - 2, h = hh, sort = hd.key }
        local active = self.sortKey == hd.key
        self:drawRect(r.x, r.y, r.w, r.h, active and 0.95 or (inside(r, mx, my) and 0.8 or 0.6), C.accentDark[1], C.accentDark[2], C.accentDark[3])
        local tx = r.x + 6
        if hd.key ~= "name" then
            local icon = H.vitIcon(hd.key)
            local s = hh - 6
            if icon then self:drawTextureScaled(icon, r.x + math.floor((r.w - s) / 2), r.y + 3, s, s, 1, 1, 1, 1) end
        else
            shadowText(self, hd.label, tx, r.y + math.floor((hh - fh(sf)) / 2), active and C.text or C.textDim, 1, sf)
        end
        if active then self:drawRect(r.x, r.y + r.h - 2, r.w, 2, 1, C.accent[1], C.accent[2], C.accent[3]) end
        clickable(self, r)
    end
    shadowText(self, fit(T(knows and "IGUI_GTPG_FoodsHint" or "IGUI_GTPG_FoodsHintLocked"), cw, sf), cx, cy + hh + 4, C.textDim, 1, sf)
    local listY = cy + hh + lh + 8
    -- sorted copy
    -- sorted / filtered copy: with the knowledge a vitamin column sorts
    -- richest first; without it, it keeps only the foods with that vitamin, A-Z
    local key = self.sortKey
    local sig = key .. "|" .. q .. "|" .. tostring(knows) .. "|" .. tostring(self.growOnly)
    if self.sortedFor ~= sig then
        self.sortedFor = sig
        self.sorted = {}
        for _, f in ipairs(foods) do
            if self:keep(f, q) and (key == "name" or knows or (f.prof[key] or 0) > 0) then
                self.sorted[#self.sorted + 1] = f
            end
        end
        if key ~= "name" and knows then
            table.sort(self.sorted, function(a, b)
                local va, vb = a.prof[key] or 0, b.prof[key] or 0
                if va ~= vb then return va > vb end
                return a.name < b.name
            end)
        end
        self.scroll.foods = 0
    end
    local maxBy = {}
    for _, v in ipairs(HARMONIE_GTP.Vitamins) do
        local m = 0
        for _, f in ipairs(foods) do m = math.max(m, H.reserveOf(v, f.prof[v] or 0)) end
        maxBy[v] = m > 0 and m or 1
    end
    local rowH = math.max(26, lh + 8)
    self:scrolled("foods", cx, listY, cw, y + h - 6 - listY, function(yy)
        local start = yy
        if #self.sorted == 0 then
            shadowText(self, T("IGUI_GTPG_NoMatch"), cx, yy, C.textDim, 1, sf)
            yy = yy + lh
        end
        for i, f in ipairs(self.sorted) do
            if i % 2 == 0 then self:drawRect(cx, yy, cw - 8, rowH, 0.35, 0.05, 0.16, 0.07) end
            if f.icon then self:drawTextureScaled(f.icon, cx + 2, yy + 1, rowH - 2, rowH - 2, 1, 1, 1, 1) end
            shadowText(self, fit(foodLabel(f), nameW - rowH - 10, sf), cx + rowH + 6, yy + math.floor((rowH - fh(sf)) / 2), f.canned and C.warn or C.text, 1, sf)
            for j, v in ipairs(HARMONIE_GTP.Vitamins) do
                local amt = f.prof[v]
                if amt and amt > 0 then
                    local g = H.reserveOf(v, amt)
                    local bx = cx + nameW + (j - 1) * colW
                    if knows then
                        self:drawRect(bx + 2, yy + 2, colW - 6, rowH - 4, 0.15 + 0.6 * math.min(1, g / maxBy[v]), C.accentDark[1] * 2, C.accentDark[2] * 2, C.accentDark[3] * 2)
                        local s = H.fmt1(g)
                        shadowText(self, s, bx + math.floor((colW - tw(sf, s)) / 2), yy + math.floor((rowH - fh(sf)) / 2), C.text, 1, sf)
                    else
                        -- only "has it": a dot, no amount
                        local d = math.max(6, math.floor(rowH / 3))
                        self:drawRect(bx + math.floor((colW - d) / 2) - 2, yy + math.floor((rowH - d) / 2), d, d, 0.95, C.accent[1], C.accent[2], C.accent[3])
                    end
                end
            end
            yy = yy + rowH
        end
        return yy - start
    end)
end

-- ----------------------------------------------------------------- tab 4
-- each section: an item picture, a title, wrapped text, and (for recipes)
-- a row of the ingredients' pictures
local OTHER_ITEMS = {
    Grow = { "Base.Apple" },
    Sun = { "Base.Hat_StrawHat" },
    Dried = { "HARMONIEGardenToPlate.DriedApple" },
    Sprouts = { "HARMONIEGardenToPlate.BeanSprouts" },
    FishOil = { "HARMONIEGardenToPlate.FishLiverOil" },
    Pills = { "Base.PillsVitamins" },
    Canning = { "Base.TinCanEmpty", "Base.Carrots", "Base.Salt" },
    Cooking = { "Base.PotOfStew", "Base.Pot" },
    Fresh = { "Base.Carrots" },
    NotTracked = { "Base.Milk", "Base.CandyPackage" },
    Tips = { "Base.Salmon", "Base.Egg", "Base.Orange", "Base.Spinach" },
}
local RECIPE_ROWS = {
    Dried = { "Base.Apple", "Base.Pear", "Base.Peach", "Base.Mango", "Base.Banana", "Base.Cherry", "Base.Grapes", "Base.Pineapple" },
    Sprouts = { "Base.EmptyJar", "Base.DriedLentils", "Base.SoybeansSeed", "HARMONIEGardenToPlate.SproutingJar", "HARMONIEGardenToPlate.BeanSproutsJar", "HARMONIEGardenToPlate.BeanSprouts" },
    FishOil = { "Base.Pot", "Base.EmptyJar", "Base.FishGuts", "Base.FishGuts", "Base.FishFillet", "HARMONIEGardenToPlate.FishLiverOil" },
    Grow = { "Base.KitchenKnife", "Base.Apple", "FruitFarming.AppleSeed", "Base.HandShovel", "Base.WateredCan" },
    Pills = { "Base.MortarPestle", "Base.EmptyJar", "Base.Carrots", "Base.Egg", "Base.Tomato", "Base.Salmon", "Base.Peanuts", "Base.Broccoli", "Base.Salt" },
    Canning = { "Base.TinCanEmpty", "Base.Carrots", "Base.Carrots", "Base.Carrots", "Base.Carrots", "Base.Salt" },
}

function Win:renderOther(x, y, w, h)
    local C = H.C
    local sf, mf = H.small(), H.medium()
    local lh = lineH(sf)
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, T("IGUI_GTPG_Tab_other"))
    self:scrolled("other", cx, cy, cw, ch, function(yy)
        local start = yy
        for _, key in ipairs(H.OTHER) do
            local pic = OTHER_ITEMS[key] and H.item(OTHER_ITEMS[key][1])
            local isz = 40
            if pic and pic.icon then self:drawTextureScaled(pic.icon, cx, yy, isz, isz, 1, 1, 1, 1) end
            local tx = cx + isz + 10
            shadowText(self, T("IGUI_GTPG_Other_" .. key .. "_Title"), tx, yy, C.accent, 1, mf)
            local ty = yy + lineH(mf) + 2
            local body
            if key == "Sun" and HARMONIE_GTP.SunD then
                -- the live sandbox numbers
                body = T("IGUI_GTPG_Other_Sun_Body", H.fmt1(HARMONIE_GTP.SunD.perHour()), H.fmt1(HARMONIE_GTP.SunD.maxPerDay()))
            else
                body = T("IGUI_GTPG_Other_" .. key .. "_Body")
            end
            ty = ty + self:paragraphs(body, tx, ty, cw - (tx - cx) - 12, C.text, sf)
            local row = RECIPE_ROWS[key]
            if row then
                ty = ty + 4
                local ix = tx
                local s = math.max(28, lh + 10)
                local list = row
                if key == "Grow" then
                    list = {}
                    for _, ft in ipairs(row) do list[#list + 1] = ft end
                    list[#list + 1] = "|"
                    for _, c in ipairs(HARMONIE_GTP.FruitFarmingCrops or {}) do list[#list + 1] = c.food end
                end
                for _, ft in ipairs(list) do
                    local it = ft ~= "|" and H.item(ft)
                    if ft == "|" or ix + s > cx + cw - 10 then
                        ix = tx
                        ty = ty + s + 4
                    end
                    if it and it.icon then
                        self:drawRect(ix, ty, s, s, 0.6, 0.04, 0.14, 0.06)
                        self:drawTextureScaled(it.icon, ix + 2, ty + 2, s - 4, s - 4, 1, 1, 1, 1)
                        local r = { x = ix, y = ty, w = s, h = s }
                        if inside(r, self:getMouseX(), self:getMouseY()) and inside(self.scrollBox and self.scrollBox.other, self:getMouseX(), self:getMouseY()) then
                            self.hoverTip = { text = it.name, x = ix, y = ty + s + 2 }
                        end
                        ix = ix + s + 4
                    end
                end
                ty = ty + s
            end
            yy = math.max(yy + isz, ty) + 14
            self:drawRect(cx, yy - 7, cw - 10, 1, 0.5, C.borderDim[1], C.borderDim[2], C.borderDim[3])
        end
        return yy - start
    end)
end

-- ----------------------------------------------------------------- tab 2: check
-- Request 2026-10-08 ("อยากให้มีแท็บสำหรับตรวจสอบและดูโภชนาการคนอื่นด้วย
-- การดูตัวเองและคนอื่นสามารถดูได้แต่ดูได้จำกัด และรายละเอียดมากขึ้นเมื่อเลเวล
-- ถึงขั้น"): yourself or a survivor within H.NEAR_TILES tiles. What you see
-- grows with the viewer's First Aid (Perks.Doctor):
--   yourself  0: band + banked pause days   3: + Reserve number and bar
--             5: + deficiency active / days in deficiency
--   others    0: only how they look (well / unwell)   3: band per vitamin
--             5 (assessmentRequiredFirstAid): Reserve, pause days, deficiency
-- Another player's vitamins are READ ONLY (VitData.Peek: their ModData,
-- or in MP the copy the server sends; never VitData.Get).
H.CHECK_SELF = { 3, 5 }
function H.checkOther() return { 3, tonumber(cfg().assessmentRequiredFirstAid) or 5 } end

function H.firstAid(player)
    local ok, v = pcall(function() return player:getPerkLevel(Perks.Doctor) end)
    return ok and (tonumber(v) or 0) or 0
end

function H.readStore(target)
    -- 0.11.1: in MP another player's store is asked from the server
    local VD = HARMONIE_GTP.VitData
    if VD and VD.Peek then return VD.Peek(target) end
    local ok, md = pcall(function() return target:getModData() end)
    local st = ok and md and md.HARMONIE_Vitamins
    return type(st) == "table" and st or nil
end

local function playerName(p)
    local ok, n = pcall(function() return p:getDisplayName() end)
    if ok and n and n ~= "" then return n end
    local ok2, u = pcall(function() return p:getUsername() end)
    return ok2 and u or "?"
end

local function tiles(a, b)
    local ok, d = pcall(function() return math.abs(a:getX() - b:getX()) + math.abs(a:getY() - b:getY()) end)
    return ok and d or 999
end

-- yourself first, then everyone close enough (split screen and online)
function H.nearby(player)
    local out, seen = { player }, { [player] = true }
    local function add(p)
        if not p or seen[p] then return end
        local okD, dead = pcall(function() return p:isDead() end)
        if okD and dead then return end
        if tiles(player, p) <= H.NEAR_TILES then
            seen[p] = true
            out[#out + 1] = p
        end
    end
    local ok, list = pcall(function() return IsoPlayer.getPlayers() end)
    if ok and list then for i = 0, list:size() - 1 do add(list:get(i)) end end
    if isClient and isClient() and getOnlinePlayers then
        local ok2, online = pcall(getOnlinePlayers)
        if ok2 and online then for i = 0, online:size() - 1 do add(online:get(i)) end end
    end
    return out
end

function Win:checkTargets()
    local now = getTimestampMs and getTimestampMs() or 0
    if not self.targetsAt or now - self.targetsAt > 1000 or not self.targets then
        self.targetsAt = now
        self.targets = self.player and H.nearby(self.player) or {}
    end
    local found = false
    for _, p in ipairs(self.targets) do if p == self.checkTarget then found = true end end
    if not found then self.checkTarget = self.player end
    return self.targets
end

function Win:renderCheck(x, y, w, h)
    local C = H.C
    local sf, mf = H.small(), H.medium()
    local lh = lineH(sf)
    local mx, my = self:getMouseX(), self:getMouseY()
    local leftW = math.min(300, math.floor(w * 0.32))
    local targets = self:checkTargets()
    local listH = math.min(math.floor(h * 0.45), H.CARD_T + 18 + math.max(3, #targets) * (lh + 12) + lh * 2)
    -- who
    local cx, cy, cw = self:drawCard(x, y, leftW, listH, T("IGUI_GTPG_Card_Who"))
    for _, p in ipairs(targets) do
        local r = { x = cx, y = cy, w = cw, h = lh + 8 }
        if r.y + r.h > y + listH - lh - 8 then break end
        local active = p == self.checkTarget
        if active or inside(r, mx, my) then self:drawRect(r.x, r.y, r.w, r.h, active and 0.9 or 0.5, C.accentDark[1], C.accentDark[2], C.accentDark[3]) end
        if active then self:drawRect(r.x, r.y, 3, r.h, 1, C.accent[1], C.accent[2], C.accent[3]) end
        local label = p == self.player and T("IGUI_GTPG_You", playerName(p)) or playerName(p)
        shadowText(self, fit(label, cw - 16, sf), r.x + 10, r.y + 4, active and C.text or C.textDim, 1, sf)
        r.action = function(win)
            if win.checkTarget ~= p then log("check target: %s (First Aid %d)", playerName(p), H.firstAid(win.player)) end
            win.checkTarget = p
        end
        clickable(self, r)
        cy = cy + r.h + 2
    end
    self:paragraphs(T("IGUI_GTPG_WhoHint", tostring(H.NEAR_TILES)), cx, y + listH - lh * 2 - 4, cw - 4, C.textDim, sf)
    -- what your First Aid lets you see
    local fa = H.firstAid(self.player)
    local target = self.checkTarget or self.player
    local isSelf = target == self.player
    local levels = isSelf and H.CHECK_SELF or H.checkOther()
    local ly = y + listH + 8
    local lx, ly2, lw = self:drawCard(x, ly, leftW, h - listH - 8, T("IGUI_GTPG_Card_Detail", tostring(fa)))
    local who = isSelf and "Self" or "Other"
    local steps = { { 0, T("IGUI_GTPG_Detail" .. who .. "0") }, { levels[1], T("IGUI_GTPG_Detail" .. who .. "1") }, { levels[2], T("IGUI_GTPG_Detail" .. who .. "2") } }
    self:scrolled("detail" .. who, lx, ly2, lw, y + h - 6 - ly2, function(yy)
        local start = yy
        for _, st in ipairs(steps) do
            local have = fa >= st[1]
            local head = T("IGUI_GTPG_DetailLevel", tostring(st[1])) .. (have and ("  " .. T("IGUI_GTPG_Unlocked")) or "")
            shadowText(self, head, lx, yy, have and C.good or C.textDim, 1, sf)
            yy = yy + lh
            yy = yy + self:paragraphs(st[2], lx + 10, yy, lw - 18, have and C.text or C.textDim, sf) + 6
        end
        return yy - start
    end)
    -- the result
    local rx = x + leftW + 8
    local rw = w - leftW - 8
    local tx, ty, tw2, th2 = self:drawCard(rx, y, rw, h, T("IGUI_GTPG_Card_Result", playerName(target)))
    local store = H.readStore(target)
    if not store then
        logOnce("nodata:" .. playerName(target), "check: no vitamin data for %s yet (MP: asked the server)", playerName(target))
        self:paragraphs(T("IGUI_GTPG_NoData"), tx, ty, tw2 - 8, C.textDim, sf)
        return
    end
    local c = cfg()
    local function bandOfValue(v) return HARMONIE_GTP.GetBand(tonumber(v) or 0) end
    if not isSelf and fa < levels[1] then
        -- only how they look
        local unwell = false
        for _, v in ipairs(HARMONIE_GTP.Vitamins) do
            local e = store[v]
            if type(e) == "table" and e.afflicted and (tonumber(e.pauseDays) or 0) < 1 then unwell = true end
        end
        shadowText(self, T(unwell and "IGUI_GTPG_LooksUnwell" or "IGUI_GTPG_LooksWell"), tx, ty, unwell and C.warn or C.good, 1, mf)
        self:paragraphs(T("IGUI_GTPG_LooksHint", tostring(levels[1])), tx, ty + lineH(mf) + 6, tw2 - 8, C.textDim, sf)
        return
    end
    local showNum = fa >= levels[isSelf and 1 or 2]
    local showMore = fa >= levels[2]
    local rowH = lh * (showMore and 3 or 2) + 14
    self:scrolled("result", tx, ty, tw2, th2, function(yy)
        local start = yy
        for _, v in ipairs(HARMONIE_GTP.Vitamins) do
            local e = store[v]
            if type(e) == "table" then
                local value = tonumber(e.value) or 0
                local band = bandOfValue(value)
                local col = C[BAND_COL[band]]
                self:drawRect(tx, yy, tw2 - 8, rowH - 4, 0.45, 0.03, 0.12, 0.05)
                self:drawRect(tx, yy, 3, rowH - 4, 1, col[1], col[2], col[3])
                local icon = H.vitIcon(v)
                local isz = math.min(rowH - 12, 36)
                if icon then self:drawTextureScaled(icon, tx + 8, yy + 4, isz, isz, 1, 1, 1, 1) end
                local nx = tx + isz + 16
                shadowText(self, H.vitName(v), nx, yy + 4, C.text, 1, sf)
                local bt = T(BAND_KEY[band])
                shadowText(self, bt, tx + tw2 - 16 - tw(sf, bt), yy + 4, col, 1, sf)
                local line2 = {}
                if isSelf or showMore then
                    local pd = math.floor(tonumber(e.pauseDays) or 0)
                    line2[#line2 + 1] = T("IGUI_GTPG_PauseDays", tostring(pd))
                end
                if showNum then
                    line2[#line2 + 1] = T("IGUI_GTPG_ReserveOf", tostring(math.floor(value + 0.5)), tostring(c.maxValue))
                    self:drawBar(nx, yy + lh * 2 + 6, tw2 - (nx - tx) - 20, 5, value / (tonumber(c.maxValue) or 100), col)
                end
                if #line2 > 0 then shadowText(self, fit(table.concat(line2, "   "), tw2 - (nx - tx) - 16, sf), nx, yy + 4 + lh, C.textDim, 1, sf) end
                if showMore then
                    local s
                    if e.afflicted then
                        s = T((tonumber(e.pauseDays) or 0) >= 1 and "IGUI_GTPG_DeficiencyQuiet" or "IGUI_GTPG_DeficiencyActive",
                            tostring(math.floor(tonumber(e.afflictedDays) or 0)), tostring(c.sufficientThreshold))
                    else
                        s = T("IGUI_GTPG_NoDeficiency")
                    end
                    shadowText(self, fit(s, tw2 - (nx - tx) - 16, sf), nx, yy + 12 + lh * 2, e.afflicted and C.bad or C.textDim, 1, sf)
                end
                local r = { x = tx, y = yy, w = tw2 - 8, h = rowH - 4 }
                if inside(r, mx, my) and inside(self.scrollBox and self.scrollBox.result, mx, my) then
                    self.hoverTip = { text = T("IGUI_GTPG_Vit_" .. v .. "_Effect"), x = nx, y = yy + rowH }
                end
                yy = yy + rowH
            end
        end
        return yy - start
    end)
end

-- ----------------------------------------------------------------- settings
-- 2026-10-08 ("มีให้ตั้งค่าได้ในบนแท็บ"): the gear in the header opens this
-- page (the tabs stay; clicking one goes back). The same options as
-- Options > Mods, plus this window's own text size / pin / size.
H.KEY_ID = "OpenVitaminGuideKey"

function H.keyName(k)
    if not k or k == 0 then return T("IGUI_GTPG_KeyNone") end
    local ok, n = pcall(getKeyName, k)
    if ok and n and n ~= "" then return n end
    return tostring(k)
end

function H.currentKey()
    local K = HARMONIE_GTP.Keybinds
    return K and K.GetKey and K.GetKey(H.KEY_ID) or 0
end

function H.setKey(k)
    local o = H.option(H.KEY_ID)
    if not o then return end
    o.key = k
    log("open-guide key set to %s (%s)", tostring(k), H.keyName and H.keyName(k) or "?")
    if o.setValue then pcall(o.setValue, o, k) end
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then pcall(PZAPI.ModOptions.save, PZAPI.ModOptions) end
end

function H.setFollow(v)
    local o = H.option("GuideWithAssessment")
    log("open with the assessment window: %s%s", tostring(v), o and "" or " (option not found!)")
    if o and o.setValue then pcall(o.setValue, o, v) end
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then pcall(PZAPI.ModOptions.save, PZAPI.ModOptions) end
end

-- the next key pressed becomes the guide's key (Esc cancels); the hotkeys
-- stay quiet meanwhile and for a moment after (H.typing)
function H.onKeyCapture(key)
    if not H.capturing then return end
    H.capturing = false
    H.quietUntil = (getTimestampMs and getTimestampMs() or 0) + 400
    if key and key ~= 1 then H.setKey(key) else log("key capture cancelled (Esc)") end
end
if Events and Events.OnKeyPressed then Events.OnKeyPressed.Add(H.onKeyCapture) end

function Win:settingButton(x, y, label, action, wide)
    local C = H.C
    local sf = H.small()
    local bw = wide or (tw(sf, label) + 24)
    local bh = lineH(sf) + 8
    local r = { x = x, y = y, w = bw, h = bh, action = action }
    local over = inside(r, self:getMouseX(), self:getMouseY())
    self:drawRect(x, y, bw, bh, over and 0.95 or 0.8, C.accentDark[1], C.accentDark[2], C.accentDark[3])
    self:drawRectBorder(x, y, bw, bh, 1, C.border[1], C.border[2], C.border[3])
    shadowText(self, label, x + math.floor((bw - tw(sf, label)) / 2), y + 4, C.text, 1, sf)
    self.clicks[#self.clicks + 1] = r
    return bw
end

function Win:renderSettings(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, T("IGUI_GTPG_Settings"), texture(UI_DIR .. "icon_settings.png"))
    local rowH = lh * 2 + 14
    local valX = cx + math.floor(cw * 0.55)
    local function row(label, tip)
        shadowText(self, fit(label, valX - cx - 12, sf), cx, cy + 4, C.text, 1, sf)
        if tip then shadowText(self, fit(tip, valX - cx - 12, sf), cx, cy + 4 + lh, C.textDim, 1, sf) end
    end
    -- key
    row(T("IGUI_GTPG_KeybindGuide"), T("IGUI_GTPG_SetKeyTip"))
    local kx = valX
    local keyText = H.capturing and T("IGUI_GTPG_PressKey") or H.keyName(H.currentKey())
    shadowText(self, keyText, kx, cy + 8, H.capturing and C.warn or C.accent, 1, sf)
    kx = kx + math.max(tw(sf, keyText), 90) + 12
    kx = kx + self:settingButton(kx, cy + 4, T("IGUI_GTPG_SetKeyChange"), function() H.capturing = true; log("waiting for a key press to set the open-guide key") end) + 6
    self:settingButton(kx, cy + 4, T("IGUI_GTPG_SetKeyClear"), function() H.capturing = false; H.setKey(0) end)
    cy = cy + rowH
    -- open with the assessment
    row(T("IGUI_GTPG_OptFollow"), T("IGUI_GTPG_OptFollow_tt"))
    local follow = H.followEnabled()
    self:settingButton(valX, cy + 4, follow and T("IGUI_GTPG_On") or T("IGUI_GTPG_Off"), function() H.setFollow(not H.followEnabled()) end, 90)
    cy = cy + rowH
    -- text size
    row(T("IGUI_GTPG_SetText"), nil)
    local tx = valX + self:settingButton(valX, cy + 4, "A-", function() H.stepText(-1) end, 44) + 8
    local sizeName = T("IGUI_GTPG_TextSize" .. tostring(H.textStep + 1))
    shadowText(self, sizeName, tx, cy + 8, C.accent, 1, sf)
    self:settingButton(tx + math.max(80, tw(sf, sizeName) + 12), cy + 4, "A+", function() H.stepText(1) end, 44)
    cy = cy + rowH
    -- pin
    row(T("IGUI_GTPG_SetPin"), T("IGUI_GTPG_Unpin"))
    self:settingButton(valX, cy + 4, H.pinned and T("IGUI_GTPG_On") or T("IGUI_GTPG_Off"), function(win) win:togglePin() end, 90)
    cy = cy + rowH
    -- window size
    row(T("IGUI_GTPG_SetSize"), T("IGUI_GTPG_SetSizeTip"))
    self:settingButton(valX, cy + 4, T("IGUI_GTPG_SetSizeReset"), function(win)
        log("window size reset to %dx%d", H.DEFAULT_W, H.DEFAULT_H)
        win:setWidth(H.DEFAULT_W); win:setHeight(H.DEFAULT_H); H.prefW, H.prefH = nil, nil; H.savePrefs()
    end)
    cy = cy + rowH + 6
    self:paragraphs(T("IGUI_GTPG_SetNote"), cx, cy, cw - 8, C.textDim, sf)
end

-- ----------------------------------------------------------------- calendar tab
-- 2026-10-08 (from the suggestions list: "ปฏิทินฤดูปลูก"): a crop x month
-- grid -- best month to sow, other sowing months, risky, bad (frost / too
-- cold), the rest neutral -- with this month marked. Read from the live
-- farming config (farming_vegetableconf.props: sowMonth / bestMonth /
-- riskMonth / badMonth) when it is loaded -- single player and the host --
-- else the Fruit Farming crops' months kept in HARMONIE_GrowableFoods.lua
-- (a multiplayer client does not load server/ files).
local function set(list)
    local s = {}
    for _, m in ipairs(list or {}) do s[tonumber(m) or m] = true end
    return s
end

local function cropName(key)
    local k = "Farming_" .. key
    local s = T(k)
    if s ~= k then return s end
    return (tostring(key):gsub("^FF", ""))
end

function H.calendarRows()
    if H.calCache then return H.calCache end
    local rows = {}
    local conf = farming_vegetableconf and type(farming_vegetableconf.props) == "table" and farming_vegetableconf.props
    if conf then
        for key, p in pairs(conf) do
            if type(p) == "table" and type(p.sowMonth) == "table" and #p.sowMonth > 0 then
                local icon = p.icon and getTexture(p.icon) or nil
                if not icon and p.vegetableName then local it = H.item(p.vegetableName); icon = it and it.icon end
                rows[#rows + 1] = { key = key, name = cropName(key), icon = icon, food = p.vegetableName,
                    sow = set(p.sowMonth), best = set(p.bestMonth), risk = set(p.riskMonth), bad = set(p.badMonth) }
            end
        end
        H.calFromConf = true
    else
        for _, c in ipairs(HARMONIE_GTP.FruitFarmingCrops or {}) do
            if c.sow then
                local it = H.item(c.food)
                rows[#rows + 1] = { key = c.crop, name = cropName(c.crop), icon = it and it.icon, food = c.food,
                    sow = set(c.sow), best = set(c.best), risk = set(c.risk), bad = set(c.bad) }
            end
        end
        H.calFromConf = false
    end
    table.sort(rows, function(a, b) return a.name < b.name end)
    H.calCache = rows
    return rows
end

function Win:renderCalendar(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local rows = H.calendarRows()
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, T("IGUI_GTPG_Card_Calendar", tostring(#rows)))
    -- legend
    local lx = cx
    for _, l in ipairs({ { "best", C.good, 1 }, { "sow", C.good, 0.45 }, { "risk", C.warn, 0.7 }, { "bad", C.bad, 0.45 } }) do
        self:drawRect(lx, cy + 3, lh - 4, lh - 4, l[3], l[2][1], l[2][2], l[2][3])
        local label = T("IGUI_GTPG_Cal_" .. l[1])
        shadowText(self, label, lx + lh, cy + 1, C.text, 1, sf)
        lx = lx + lh + tw(sf, label) + 16
    end
    cy = cy + lh + 6
    if not H.calFromConf then
        cy = cy + self:paragraphs(T("IGUI_GTPG_CalOnlyFF"), cx, cy, cw - 8, C.textDim, sf) + 4
    end
    local nameW = math.min(240, math.floor(cw * 0.3))
    local colW = math.floor((cw - 8 - nameW) / 12)
    local gt = getGameTime and getGameTime()
    local nowMonth = gt and (gt:getMonth() + 1) or 0
    local hh = lh + 6
    for m = 1, 12 do
        local mx0 = cx + nameW + (m - 1) * colW
        if m == nowMonth then self:drawRect(mx0, cy, colW - 2, hh, 0.9, C.accentDark[1], C.accentDark[2], C.accentDark[3]) end
        local s = T("IGUI_GTPG_Month" .. m)
        shadowText(self, s, mx0 + math.floor((colW - tw(sf, s)) / 2), cy + 3, m == nowMonth and C.accent or C.textDim, 1, sf)
    end
    shadowText(self, T("IGUI_GTPG_Cal_Crop"), cx + 4, cy + 3, C.textDim, 1, sf)
    cy = cy + hh + 2
    local rowH = math.max(24, lh + 6)
    local mx, my = self:getMouseX(), self:getMouseY()
    self:scrolled("calendar", cx, cy, cw, y + h - 6 - cy, function(yy)
        local start = yy
        for i, r in ipairs(rows) do
            if i % 2 == 0 then self:drawRect(cx, yy, cw - 8, rowH, 0.3, 0.05, 0.16, 0.07) end
            if r.icon then self:drawTextureScaled(r.icon, cx + 2, yy + 1, rowH - 2, rowH - 2, 1, 1, 1, 1) end
            shadowText(self, fit(r.name, nameW - rowH - 10, sf), cx + rowH + 6, yy + math.floor((rowH - fh(sf)) / 2), C.text, 1, sf)
            for m = 1, 12 do
                local bx = cx + nameW + (m - 1) * colW
                local col, a
                if r.best[m] then col, a = C.good, 1
                elseif r.sow[m] then col, a = C.good, 0.45
                elseif r.risk[m] then col, a = C.warn, 0.7
                elseif r.bad[m] then col, a = C.bad, 0.45 end
                if col then self:drawRect(bx + 1, yy + 3, colW - 4, rowH - 6, a, col[1], col[2], col[3]) end
                if m == nowMonth then self:drawRectBorder(bx, yy, colW - 2, rowH, 0.6, C.accent[1], C.accent[2], C.accent[3]) end
            end
            local rr = { x = cx, y = yy, w = cw - 8, h = rowH }
            if inside(rr, mx, my) and inside(self.scrollBox and self.scrollBox.calendar, mx, my) and r.food then
                local f = nil
                for _, ff in ipairs(H.foods()) do if ff.fullType == r.food then f = ff end end
                if f then
                    local parts = {}
                    for _, v in ipairs(HARMONIE_GTP.Vitamins) do if (f.prof[v] or 0) > 0 then parts[#parts + 1] = v end end
                    if #parts > 0 then self.hoverTip = { text = T("IGUI_GTPG_CalVitamins", r.name, table.concat(parts, ", ")), x = cx + 40, y = yy + rowH } end
                end
            end
            yy = yy + rowH
        end
        return yy - start
    end)
end

-- ----------------------------------------------------------------- mouse
function Win:onMouseDown(x, y)
    if y < H.HEADER_H then
        for _, b in ipairs(self:headerButtons()) do
            if inside(b, x, y) then
                getSoundManager():playUISound("UISelectListItem")
                if b.id == "close" then H.close()
                elseif b.id == "pin" then self:togglePin()
                elseif b.id == "settings" then self.settingsOpen = not self.settingsOpen; H.capturing = false
                elseif b.id == "plus" then H.stepText(1)
                elseif b.id == "minus" then H.stepText(-1) end
                return true
            end
        end
        return ISPanel.onMouseDown(self, x, y)
    end
    if self.collapsed then return true end
    if x >= self.width - H.GRIP and y >= self.height - H.GRIP then
        self.resizing = true
        self.resizeMX, self.resizeMY = getMouseX(), getMouseY()
        self.resizeW, self.resizeH = self.width, self.height
        self:bringToTop()
        return true
    end
    for _, t in ipairs(self.tabBounds or {}) do
        if inside(t, x, y) then
            getSoundManager():playUISound("UISelectListItem")
            if self.tab ~= t.id then log("tab %s -> %s", tostring(self.tab), tostring(t.id)) end
            self.tab = t.id
            self.settingsOpen = false
            H.capturing = false
            return true
        end
    end
    for _, r in ipairs(self.clicks or {}) do
        if inside(r, x, y) then
            getSoundManager():playUISound("UISelectListItem")
            if r.action then
                r.action(self)
            elseif r.clear then
                if self.search then self.search:setText("") end
            elseif r.vit then
                self.vit = r.vit
                self.tab = "vitamins"
            elseif r.sort then
                self.sortKey = r.sort
            end
            return true
        end
    end
    return true
end

function Win:onMouseWheel(del)
    local x, y = self:getMouseX(), self:getMouseY()
    for key, box in pairs(self.scrollBox or {}) do
        if inside(box, x, y) and (self.maxScroll[key] or 0) > 0 then
            local step = lineH(H.small()) * 3
            self.scroll[key] = math.max(0, math.min(self.maxScroll[key], (self.scroll[key] or 0) + del * step))
            return true
        end
    end
    return true
end

function Win:resizeTo()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    self:setWidth(math.max(H.MIN_W, math.min(sw - 20, self.resizeW + getMouseX() - self.resizeMX)))
    self:setHeight(math.max(H.MIN_H, math.min(sh - 20, self.resizeH + getMouseY() - self.resizeMY)))
end

function Win:onMouseMove(dx, dy)
    if self.resizing then self:resizeTo() return end
    ISPanel.onMouseMove(self, dx, dy)
end

function Win:onMouseMoveOutside(dx, dy)
    if self.resizing then self:resizeTo() return end
    ISPanel.onMouseMoveOutside(self, dx, dy)
end

local function endResize(self)
    if not self.resizing then return false end
    self.resizing = false
    H.prefW, H.prefH = self.width, self.height
    H.savePrefs()
    return true
end

function Win:onMouseUp(x, y)
    if endResize(self) then return end
    ISPanel.onMouseUp(self, x, y)
end

function Win:onMouseUpOutside(x, y)
    if endResize(self) then return end
    ISPanel.onMouseUpOutside(self, x, y)
end

function Win:onRightMouseDown(x, y)
    if not self.collapsed and x >= self.width - H.GRIP and y >= self.height - H.GRIP then
        self:setWidth(H.DEFAULT_W)
        self:setHeight(H.DEFAULT_H)
        H.prefW, H.prefH = nil, nil
        H.savePrefs()
        return true
    end
    return false
end

-- ----------------------------------------------------------------- pin
function Win:togglePin()
    H.pinned = not H.pinned
    log("pinned: %s", tostring(H.pinned))
    self.leaveAt = nil
    if H.pinned then self:expand() end
    H.savePrefs()
end

function Win:collapse()
    if self.collapsed then return end
    self.fullH = self.height
    self.collapsed = true
    self:setHeight(H.HEADER_H)
end

function Win:expand()
    if not self.collapsed then return end
    self.collapsed = false
    self:setHeight(self.fullH or H.DEFAULT_H)
    self.leaveAt = nil
end

function Win:updatePin()
    if H.pinned or self.resizing or self.moving then
        if H.pinned then self:expand() end
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
        if now - self.leaveAt >= H.FOLD_DELAY_MS then self:collapse() end
    end
end

-- ----------------------------------------------------------------- open / close
function H.stepText(d)
    H.textStep = math.max(0, math.min(2, H.textStep + d))
    log("text size step: %d", H.textStep)
    H.savePrefs()
end

local function place(w, h, beside)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    if beside then
        local bx, by = beside:getAbsoluteX(), beside:getAbsoluteY()
        local y = math.max(10, math.min(sh - h - 10, by))
        if bx + beside.width + 8 + w <= sw then return bx + beside.width + 8, y end
        if bx - 8 - w >= 0 then return bx - 8 - w, y end
    end
    return math.floor((sw - w) / 2), math.floor((sh - h) / 2)
end

function H.isOpen()
    return H.window ~= nil and H.window.inManager and H.window:getIsVisible()
end

function H.open(player, beside)
    H.ensurePrefs()
    player = player or getPlayer()
    if not player then log("open: no player, not opened"); return end
    log("open (%s), %s", beside and "beside the assessment window" or "key/button", H.knows and (H.knows(player) and "player knows nutrition" or "player does NOT know nutrition yet (locked parts)") or "")
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w = math.max(H.MIN_W, math.min(sw - 20, H.prefW or H.DEFAULT_W))
    local h = math.max(H.MIN_H, math.min(sh - 20, H.prefH or H.DEFAULT_H))
    local win = H.window
    if not win then
        local x, y = place(w, h, beside)
        win = GTPGuideWindow:new(x, y, w, h, player)
        win:initialise()
        H.window = win
    elseif beside and not H.isOpen() then
        local x, y = place(win.width, win.collapsed and (win.fullH or h) or win.height, beside)
        win:setX(x)
        win:setY(y)
    end
    win.player = player
    win.openedByLink = beside ~= nil
    if not H.isOpen() then
        win:addToUIManager()
        win.inManager = true
        win:setVisible(true)
    end
    win:bringToTop()
end

function H.close()
    local win = H.window
    if not win then return end
    log("close")
    win:setVisible(false)
    win:removeFromUIManager()
    win.inManager = false
end

-- true while the player types in the search box (hotkeys stay quiet)
function H.typing()
    if H.capturing then return true end
    if H.quietUntil and (getTimestampMs and getTimestampMs() or 0) < H.quietUntil then return true end
    local box = H.isOpen() and H.window.search
    if not box or not box:getIsVisible() then return false end
    local ok, f = pcall(function() return box:isFocused() end)
    return ok and f == true
end

function H.toggle(player, beside)
    if H.isOpen() then H.close() else H.open(player, beside) end
end

-- the Nutritional Assessment window (HARMONIE_NutritionUI) opened / closed
function H.onAssessmentOpened(assessWindow)
    if not H.followEnabled() or H.isOpen() then return end
    H.open(assessWindow and assessWindow.assessor or getPlayer(), assessWindow)
end

function H.onAssessmentClosed()
    if H.isOpen() and H.window.openedByLink then H.close() end
end

-- ----------------------------------------------------------------- options
-- Options > Mods > HARMONIE: Garden to Plate (the same ModOptions page as
-- the hotkeys, HARMONIE_KeybindManager)
function H.option(id)
    local K = HARMONIE_GTP.Keybinds
    if K and K.Initialize then pcall(K.Initialize) end
    local mo = K and K.modOptions
    return mo and mo.getOption and mo:getOption(id) or nil
end

function H.followEnabled()
    local o = H.option("GuideWithAssessment")
    if o and o.getValue then
        local ok, v = pcall(o.getValue, o)
        if ok and v ~= nil then return v == true end
    end
    return true
end

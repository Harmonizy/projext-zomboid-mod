--============================================================================
-- HARMONIE - Life With Style -- the wardrobe window (client)
--
-- Owner, 2026-10-20: "ใช้รูปแบบหน้าต่างเหมือนม็อดอื่นๆของฉันด้วย ธีมสีขาว". Our
-- windows' layout -- a header (title, A-, A+, settings, pin, close), big
-- icon tabs, content in cards, a size grip, the shared scroll bar -- in white:
--   1 dress       a dressing room: the 18 slots on both sides, head to
--                 feet, the drawer with the pieces of the picked slot in
--                 the middle ("show my real clothes" / take off). The
--                 header's small-window button turns the whole window into
--                 a compact dresser beside the character.
--   2 collection  every piece the player has (filter by slot)
--   3 trade       requests and the players online; an open trade: what I
--                 give, my collection, what they give, agree / cancel
--                 (LWS_Trade.lua on the server does the swap)
--   4 admin       (admins only) every owner, their pieces, the catalog:
--                 click a catalog piece to give it, x on a piece to take it
--   5 guide       how it works
-- Everything is drawn in render() (no child widgets). Size, text step,
-- pin and mute are kept in Zomboid/Lua/HARMONIE_LWS_Window.txt.
--============================================================================

require "ISUI/ISPanel"
require "HARMONIE_UIKit"
require "HARMONIELifeWithStyle/LWS_Core"
require "HARMONIELifeWithStyle/LWS_Client"

LWSWindow = LWSWindow or {}
local H = LWSWindow
local C = LWS.Client
local function log(...) LWS.log("Window", ...) end

H.HEADER_H = 40
H.TAB_H = 58
H.CARD_T = 26
H.GRIP = 18
H.DEFAULT_W, H.DEFAULT_H = 940, 660
H.MIN_W, H.MIN_H = 760, 500
H.FOLD_DELAY_MS = 350
-- owner, 2026-10-20: "อยากให้สามารถย่อได้ จะได้ขยับไปข้างๆและดูตัวละครได้ตลอดเวลา":
-- the compact window -- only the dress-up page, small, beside the character
H.COMPACT_W, H.COMPACT_H = 400, 620
H.COMPACT_MIN_W, H.COMPACT_MIN_H = 340, 420
-- the dress-up page: slots on both sides of the character, head to feet
H.LEFT = { "hat", "mask", "eyes", "ears", "neck", "top", "outer", "full", "back" }
H.RIGHT = { "hands", "wrist", "rings", "waist", "bottom", "shoes", "makeup", "tail", "extra" }
H.TILE_W, H.TILE_H = 116, 128
H.GUIDE = { "What", "Dress", "Show", "Death", "Trade", "Admin", "Soon" }

-- white, ink and champagne gold
H.C = {
    accent = { 0.70, 0.49, 0.28 },
    accentSoft = { 0.97, 0.93, 0.87 },
    background = { 0.965, 0.958, 0.948, 0.985 },
    panel = { 0.985, 0.98, 0.972, 0.98 },
    header = { 1, 1, 1, 1 },
    card = { 1, 1, 1, 0.99 },
    border = { 0.78, 0.64, 0.48 },
    borderDim = { 0.86, 0.83, 0.79 },
    text = { 0.14, 0.12, 0.11 },
    textDim = { 0.46, 0.43, 0.40 },
    good = { 0.18, 0.58, 0.30 },
    bad = { 0.80, 0.24, 0.22 },
    hover = { 0.99, 0.96, 0.91 },
}

local UI_DIR = "media/textures/HARMONIE_LWS/"
local tex = {}
local function texture(path)
    if not path then return nil end
    if tex[path] == nil then tex[path] = getTexture(path) or false end
    return tex[path] or nil
end
local function pieceIcon(pieceId)
    local c = LWS.PIECE[pieceId]
    if not c then return nil end
    return texture("Item_" .. c.icon) or texture("media/textures/Item_" .. c.icon .. ".png")
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
local T = LWS.T

local function text(panel, s, x, y, c, a, font)
    panel:drawText(s, x, y, c[1], c[2], c[3], a or 1, font)
end

local function fit(s, maxW, font)
    s = tostring(s or "")
    if maxW <= 0 then return "" end
    if tw(font, s) <= maxW then return s end
    while #s > 1 and tw(font, s .. "...") > maxW do s = s:sub(1, -2) end
    return s .. "..."
end

local function wrap(t, maxW, font)
    local out = {}
    for para in (tostring(t or "") .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in para:gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            if tw(font, try) > maxW and line ~= "" then out[#out + 1] = line; line = word else line = try end
        end
        out[#out + 1] = line
    end
    return out
end

local function inside(r, x, y) return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- ----------------------------------------------------------------- prefs
H.PREFS_FILE = "HARMONIE_LWS_Window.txt"
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
            elseif k == "muted" then H.muted = v == "1"
            elseif k == "pinned" then H.pinned = v ~= "0"
            elseif k == "compact" then H.compact = v == "1"
            elseif k == "fw" then H.fullW = tonumber(v)
            elseif k == "fh" then H.fullH = tonumber(v) end
            line = reader:readLine()
        end
    end)
    pcall(function() reader:close() end)
    log("prefs loaded: size %sx%s, text step %s, pinned %s", tostring(H.prefW), tostring(H.prefH), tostring(H.textStep), tostring(H.pinned))
end

function H.savePrefs()
    if not getFileWriter then return end
    local ok, writer = pcall(getFileWriter, H.PREFS_FILE, true, false)
    if not ok or not writer then log("could not write %s", H.PREFS_FILE); return end
    pcall(function()
        if H.prefW then writer:write("w=" .. tostring(math.floor(H.prefW)) .. "\n") end
        if H.prefH then writer:write("h=" .. tostring(math.floor(H.prefH)) .. "\n") end
        writer:write("text=" .. tostring(H.textStep) .. "\n")
        writer:write("pinned=" .. (H.pinned and "1" or "0") .. "\n")
        writer:write("muted=" .. (H.muted and "1" or "0") .. "\n")
        writer:write("compact=" .. (H.compact and "1" or "0") .. "\n")
        if H.fullW then writer:write("fw=" .. tostring(math.floor(H.fullW)) .. "\n") end
        if H.fullH then writer:write("fh=" .. tostring(math.floor(H.fullH)) .. "\n") end
    end)
    pcall(function() writer:close() end)
end

function H.sound(name)
    if H.muted then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function H.stepText(d)
    H.textStep = math.max(0, math.min(2, H.textStep + d))
    log("text size step: %d", H.textStep)
    H.savePrefs()
end

-- the shared settings window, white
function H.openSettings()
    log("settings opened")
    local c = H.C
    HARMONIE_SettingsUI.open(T("IGUI_LWS_Set_Title"), function()
        return HARMONIE_SettingsUI.commonRows({
            getText = function() return H.textStep end,
            setText = function(v) H.stepText(v - H.textStep) end,
            resetSize = function()
                H.prefW, H.prefH = nil, nil
                H.savePrefs()
                local win = H.window
                if win then
                    win:setWidth(H.DEFAULT_W); win:setHeight(H.DEFAULT_H)
                    local core = getCore()
                    win:setX(math.max(0, math.floor((core:getScreenWidth() - win.width) / 2)))
                    win:setY(math.max(0, math.floor((core:getScreenHeight() - win.height) / 2)))
                end
            end,
            getPin = function() return H.pinned end,
            setPin = function(v) if v ~= H.pinned then if H.window then H.window:togglePin() else H.pinned = v; H.savePrefs() end end end,
            getMuted = function() return H.muted == true end,
            setMuted = function(v) H.muted = v == true; H.savePrefs() end,
        })
    end, {
        bg = c.background, header = c.header, row = { 0.95, 0.93, 0.90 }, rowHover = c.hover,
        border = c.border, borderDim = c.borderDim, accent = c.accent, accentDark = c.accentSoft,
        text = c.text, textDim = c.textDim, noShadow = true,
    }, { textStep = H.textStep })
end

-- ----------------------------------------------------------------- window
LWSWindowPanel = ISPanel:derive("LWSWindowPanel")
local Win = LWSWindowPanel

function Win:new(x, y, w, h, player)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.tab = "dress"
    o.slot = LWS.SLOTS[1].id
    o.filter = "all"
    o.scroll = {}
    o.maxScroll = {}
    o.guidePage = 1
    o.moveWithMouse = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    return o
end

function Win:tabs()
    local list = { "dress", "collection", "trade" }
    if LWS.isAdmin(self.player) then list[#list + 1] = "admin" end
    list[#list + 1] = "guide"
    return list
end

function Win:contentTop() return H.compact and (H.HEADER_H + 6) or (H.HEADER_H + H.TAB_H + 6) end

function Win:headerButtons()
    local s = 26
    local y = math.floor((H.HEADER_H - s) / 2)
    local x = self.width - s - 8
    local b = {}
    for _, id in ipairs({ "close", "pin", "settings", "compact", "plus", "minus" }) do
        b[#b + 1] = { id = id, x = x, y = y, w = s, h = s }
        x = x - s - 6
    end
    return b
end

function Win:drawCard(x, y, w, h, title)
    local c = H.C
    self:drawRect(x, y, w, h, c.card[4], c.card[1], c.card[2], c.card[3])
    self:drawRectBorder(x, y, w, h, 1, c.borderDim[1], c.borderDim[2], c.borderDim[3])
    local th = H.CARD_T
    self:drawRect(x + 1, y + 1, w - 2, th - 1, 1, c.accentSoft[1], c.accentSoft[2], c.accentSoft[3])
    self:drawRect(x + 6, y + th - 1, w - 12, 1, 0.9, c.border[1], c.border[2], c.border[3])
    if title and title ~= "" then
        local font = H.small()
        self:drawRect(x + 8, y + math.floor((th - 8) / 2), 3, 8, 1, c.accent[1], c.accent[2], c.accent[3])
        text(self, fit(title, w - 24, font), x + 16, y + math.floor((th - fh(font)) / 2), c.accent, 1, font)
    end
    return x + 10, y + th + 6, w - 20, h - th - 12
end

function Win:button(id, label, x, y, w, h, on, enabled)
    local c = H.C
    local mx, my = self:getMouseX(), self:getMouseY()
    local r = { id = id, x = x, y = y, w = w, h = h, enabled = enabled ~= false }
    local over = inside(r, mx, my) and r.enabled
    local bg = on and c.accent or (over and c.hover or c.card)
    self:drawRect(x, y, w, h, r.enabled and 1 or 0.5, bg[1], bg[2], bg[3])
    self:drawRectBorder(x, y, w, h, 1, (on and c.accent or c.border)[1], (on and c.accent or c.border)[2], (on and c.accent or c.border)[3])
    local font = H.small()
    local col = on and { 1, 1, 1 } or (r.enabled and c.text or c.textDim)
    local s = fit(label, w - 10, font)
    text(self, s, x + math.floor((w - tw(font, s)) / 2), y + math.floor((h - fh(font)) / 2), col, 1, font)
    self.buttons[#self.buttons + 1] = r
    return r
end

-- scrolled content: f(yOffset) draws, returns the height used
function Win:scrolled(key, x, y, w, h, f)
    local off = self.scroll[key] or 0
    self.scrollBox[key] = { x = x, y = y, w = w, h = h }
    self:setStencilRect(x, y, w, h)
    local used = f(y - off)
    self:clearStencilRect()
    self.maxScroll[key] = math.max(0, (used or 0) - h)
    if off > self.maxScroll[key] then self.scroll[key] = self.maxScroll[key] end
    HARMONIE_Scroll.bar(self, key, x + w - 7, y, 6, h, self.scroll[key] or 0, self.maxScroll[key],
        function(v) self.scroll[key] = v end, H.C.accent, H.C.borderDim)
end

-- one piece tile; returns its rect
function Win:tile(x, y, e, opts)
    local c = H.C
    opts = opts or {}
    local w, h = opts.tw or H.TILE_W, opts.th or H.TILE_H
    local mx, my = self:getMouseX(), self:getMouseY()
    local r = { x = x, y = y, w = w, h = h }
    local over = inside(r, mx, my) and inside(self.clip, mx, my)
    local bg = over and c.hover or c.card
    self:drawRect(x, y, w, h, 1, bg[1], bg[2], bg[3])
    local bd = opts.worn and c.accent or c.borderDim
    self:drawRectBorder(x, y, w, h, 1, bd[1], bd[2], bd[3])
    if opts.worn then self:drawRectBorder(x + 1, y + 1, w - 2, h - 2, 1, c.accent[1], c.accent[2], c.accent[3]) end
    local icon = pieceIcon(e.p)
    local isz = opts.isz or 56
    if icon then self:drawTextureScaled(icon, x + math.floor((w - isz) / 2), y + 10, isz, isz, 1, 1, 1, 1) end
    local font = H.small()
    local lines = wrap(LWS.pieceName(e.p), w - 12, font)
    local ty = y + 10 + isz + 6
    -- a label under the name (Wearing, the slot...) leaves room for one line
    local bottom = opts.label and (h - lineH(font) - 4) or (h - 4)
    local room = math.max(1, math.min(2, math.floor((bottom - (10 + isz + 6)) / lineH(font))))
    for i = 1, math.min(room, #lines) do
        local l = lines[i]
        if i == room and #lines > room then l = l .. " " .. lines[i + 1] end  -- cut with "..."
        l = fit(l, w - 10, font)
        text(self, l, x + math.floor((w - tw(font, l)) / 2), ty, c.text, 1, font)
        ty = ty + lineH(font)
    end
    if opts.label then
        local l = fit(opts.label, w - 10, font)
        text(self, l, x + math.floor((w - tw(font, l)) / 2), y + h - lineH(font) - 4, opts.labelCol or c.textDim, 1, font)
    end
    if opts.remove then
        local rr = { x = x + w - 20, y = y + 4, w = 16, h = 16 }
        local ov = inside(rr, mx, my)
        self:drawRect(rr.x, rr.y, rr.w, rr.h, 1, ov and c.bad[1] or 0.96, ov and c.bad[2] or 0.92, ov and c.bad[3] or 0.9)
        self:drawRectBorder(rr.x, rr.y, rr.w, rr.h, 1, c.bad[1], c.bad[2], c.bad[3])
        local xi = texture(UI_DIR .. "icon_close.png")
        if xi then self:drawTextureScaled(xi, rr.x + 3, rr.y + 3, 10, 10, 1, ov and 1 or c.bad[1], ov and 1 or c.bad[2], ov and 1 or c.bad[3]) end
        r.remove = rr
    end
    if over then
        self.hoverTip = { text = LWS.pieceName(e.p) .. "\n" .. LWS.slotName(LWS.PIECE[e.p] and LWS.PIECE[e.p].slot or "") .. (opts.tip and ("\n" .. opts.tip) or ""), x = x + 20, y = y + h + 4 }
    end
    return r
end

-- a grid of tiles in the box; returns the height used
function Win:grid(key, x, y, w, h, list, opts, size)
    self.tiles[key] = {}
    self.clip = { x = x, y = y, w = w, h = h }
    local TW, TH = (size and size.w) or H.TILE_W, (size and size.h) or H.TILE_H
    self:scrolled(key, x, y, w, h, function(top)
        local gap = (size and size.gap) or 10
        local cols = math.max(1, math.floor((w - 12 + gap) / (TW + gap)))
        for i, e in ipairs(list) do
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            local tx, ty = x + col * (TW + gap), top + row * (TH + gap)
            local o = opts(e)
            o.tw, o.th, o.isz = TW, TH, size and size.isz or nil
            local r = self:tile(tx, ty, e, o)
            r.e = e
            self.tiles[key][#self.tiles[key] + 1] = r
        end
        local rows = math.ceil(#list / cols)
        return rows * (TH + gap)
    end)
end

-- ----------------------------------------------------------------- frame
function Win:prerender()
    local c = H.C
    local hh, th = H.HEADER_H, H.TAB_H
    self:drawRect(0, 0, self.width, self.height, c.background[4], c.background[1], c.background[2], c.background[3])
    self:drawRectBorder(0, 0, self.width, self.height, 1, c.border[1], c.border[2], c.border[3])
    self:drawRect(1, 1, self.width - 2, hh - 1, c.header[4], c.header[1], c.header[2], c.header[3])
    self:drawRect(0, hh - 1, self.width, 1, 1, c.border[1], c.border[2], c.border[3])
    local font = H.medium()
    local ix = 10
    local logo = texture(UI_DIR .. "logo.png")
    if logo then self:drawTextureScaled(logo, ix, math.floor((hh - 30) / 2), 30, 30, 1, 1, 1, 1); ix = ix + 38 end
    text(self, fit(T("IGUI_LWS_Title"), self.width - ix - 218, font), ix, math.floor((hh - fh(font)) / 2), c.text, 1, font)
    self.hoverTip = nil
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, b in ipairs(self:headerButtons()) do
        local over = inside(b, mx, my)
        local tint = b.id == "close" and c.bad or c.border
        self:drawRect(b.x, b.y, b.w, b.h, 1, over and c.hover[1] or 1, over and c.hover[2] or 1, over and c.hover[3] or 1)
        self:drawRectBorder(b.x, b.y, b.w, b.h, 1, tint[1], tint[2], tint[3])
        local name = b.id == "pin" and (H.pinned and "pin_on" or "pin_off")
            or (b.id == "compact" and (H.compact and "icon_expand" or "icon_compact")) or ("icon_" .. b.id)
        local icon = texture(UI_DIR .. name .. ".png")
        local disabled = (b.id == "plus" and H.textStep >= 2) or (b.id == "minus" and H.textStep <= 0)
        if icon then self:drawTextureScaled(icon, b.x + 4, b.y + 4, b.w - 8, b.h - 8, disabled and 0.3 or 1, 1, 1, 1) end
        if over then
            local key = ({ close = "IGUI_LWS_Close", pin = H.pinned and "IGUI_LWS_Unpin" or "IGUI_LWS_Pin",
                plus = "IGUI_LWS_TextBigger", minus = "IGUI_LWS_TextSmaller", settings = "IGUI_LWS_Settings",
                compact = H.compact and "IGUI_LWS_Expand" or "IGUI_LWS_Compact" })[b.id]
            self.hoverTip = { text = T(key), x = b.x - 40, y = b.y + b.h + 4 }
        end
    end
    if self.collapsed then return end
    if H.compact then
        self.tabBounds = {}
        local top = hh + 2
        self:drawRect(4, top, self.width - 8, self.height - top - 4, c.panel[4], c.panel[1], c.panel[2], c.panel[3])
        return
    end
    -- tabs
    self:drawRect(1, hh, self.width - 2, th, 1, 0.98, 0.975, 0.965)
    self:drawRect(0, hh + th - 1, self.width, 1, 1, c.borderDim[1], c.borderDim[2], c.borderDim[3])
    local tabs = self:tabs()
    if not self:hasTab(self.tab) then self.tab = "dress" end
    local gap = 5
    local tabW = math.floor((self.width - 16 - gap * (#tabs - 1)) / #tabs)
    local x = 8
    self.tabBounds = {}
    local sf = H.small()
    for _, id in ipairs(tabs) do
        local active = self.tab == id
        local ty, tH = hh + 6, th - 12
        local bg = active and c.accentSoft or c.card
        local bd = active and c.accent or c.borderDim
        self:drawRect(x, ty, tabW, tH, 1, bg[1], bg[2], bg[3])
        self:drawRectBorder(x, ty, tabW, tH, 1, bd[1], bd[2], bd[3])
        if active then self:drawRect(x + 3, ty + tH - 4, tabW - 6, 2, 1, c.accent[1], c.accent[2], c.accent[3]) end
        local size = math.min(tH - 8, 36)
        local name = T("IGUI_LWS_Tab_" .. id)
        if id == "trade" then
            local n = #C.openAsks()
            if C.trade then name = name .. " *" elseif n > 0 then name = name .. " (" .. n .. ")" end
        end
        local label = fit(name, tabW - size - 24, sf)
        local icon = texture(UI_DIR .. "tab_" .. id .. ".png")
        local total = size + 8 + tw(sf, label)
        local tx = x + math.floor((tabW - total) / 2)
        if icon then self:drawTextureScaled(icon, tx, ty + math.floor((tH - size) / 2), size, size, active and 1 or 0.7, 1, 1, 1) end
        text(self, label, tx + size + 8, ty + math.floor((tH - fh(sf)) / 2), active and c.text or c.textDim, 1, sf)
        local bounds = { id = id, x = x, y = ty, w = tabW, h = tH }
        self.tabBounds[#self.tabBounds + 1] = bounds
        if inside(bounds, mx, my) then self.hoverTip = { text = T("IGUI_LWS_Tab_" .. id .. "_Tip"), x = x + 30, y = ty + tH + 4 } end
        x = x + tabW + gap
    end
    local top = hh + th + 2
    self:drawRect(4, top, self.width - 8, self.height - top - 4, c.panel[4], c.panel[1], c.panel[2], c.panel[3])
end

function Win:hasTab(id)
    for _, t in ipairs(self:tabs()) do if t == id then return true end end
    return false
end

function Win:render()
    if not self.collapsed then
        self.scrollBox, self.buttons, self.tiles, self.rows = {}, {}, {}, {}
        local x, y = 8, self:contentTop()
        local w, h = self.width - 16, self.height - y - 8
        if H.compact then self:renderCompact(x, y, w, h)
        elseif self.tab == "dress" then self:renderDress(x, y, w, h)
        elseif self.tab == "collection" then self:renderCollection(x, y, w, h)
        elseif self.tab == "admin" then self:renderAdmin(x, y, w, h)
        elseif self.tab == "trade" then self:renderTrade(x, y, w, h)
        else self:renderGuide(x, y, w, h) end
        local c = H.C
        local gx, gy = self.width - 16, self.height - 16
        for i, len in ipairs({ 12, 8, 4 }) do
            local o = (i - 1) * 4
            self:drawRect(gx + 10 - o, gy + 14 - len, 2, len, 0.9 - 0.15 * (i - 1), c.accent[1], c.accent[2], c.accent[3])
        end
    end
    self:drawHoverTip()
    self:updatePin()
end

function Win:drawHoverTip()
    local t = self.hoverTip
    if not t or not t.text or t.text == "" or t.text:find("IGUI_", 1, true) then return end
    local c = H.C
    local font = H.small()
    local lines = wrap(t.text, 340, font)
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, tw(font, l)) end
    w = w + 16
    local h = #lines * lineH(font) + 10
    local x = math.max(4, math.min(self.width - w - 4, t.x))
    local y = math.min(t.y, self.height - h - 4)
    self:drawRect(x, y, w, h, 0.99, 1, 1, 1)
    self:drawRectBorder(x, y, w, h, 1, c.border[1], c.border[2], c.border[3])
    for i, l in ipairs(lines) do text(self, l, x + 8, y + 5 + (i - 1) * lineH(font), c.text, 1, font) end
end

-- ----------------------------------------------------------------- tab 1: dress
-- owner, 2026-10-20: "ไม่อยากใช้รูปแบบการสวมใส่แบบเดิม มันดูไม่มีสไตล์" -- a dressing
-- room: the slots on both sides head to feet, a gold line from the picked
-- slot to the drawer in the middle with its pieces. (The 3D character of
-- 0.3.0 did not show in the game -- owner: "3d ไม่ขึ้น ไม่ต้องมีก็ได้" -- removed.)

-- one slot tile (both layouts); returns its rect
function Win:slotTile(slot, x, y, w, h, small)
    local c = H.C
    local mx, my = self:getMouseX(), self:getMouseY()
    local r = { x = x, y = y, w = w, h = h, slot = slot }
    local active = self.slot == slot
    local over = inside(r, mx, my)
    local worn = C.wornIn(slot)
    local bg = active and c.accentSoft or (over and c.hover or c.card)
    self:drawRect(x, y, w, h, 1, bg[1], bg[2], bg[3])
    local bd = active and c.accent or (worn and c.border or c.borderDim)
    self:drawRectBorder(x, y, w, h, 1, bd[1], bd[2], bd[3])
    if active then self:drawRectBorder(x + 1, y + 1, w - 2, h - 2, 1, c.accent[1], c.accent[2], c.accent[3]) end
    local sf = H.small()
    local isz = small and (math.min(w, h) - 8) or (h - 8)
    local ix, iy = small and (x + math.floor((w - isz) / 2)) or (x + 4), y + 4
    self:drawRect(ix, iy, isz, isz, 1, 0.975, 0.965, 0.95)
    local icon = worn and pieceIcon(worn.p)
    if icon then
        self:drawTextureScaled(icon, ix + 2, iy + 2, isz - 4, isz - 4, 1, 1, 1, 1)
    else
        local l = fit(LWS.slotName(slot), isz - 4, sf)
        if small then text(self, l, ix + math.floor((isz - tw(sf, l)) / 2), iy + math.floor((isz - fh(sf)) / 2), c.borderDim, 1, sf) end
    end
    if worn and C.state.show and C.state.show[slot] then
        self:drawRect(ix + isz - 9, iy + 3, 6, 6, 1, c.good[1], c.good[2], c.good[3])
    end
    if not small then
        local tx = x + isz + 12
        text(self, fit(LWS.slotName(slot), w - isz - 18, sf), tx, y + math.floor(h / 2) - lineH(sf) + 1, active and c.accent or c.text, 1, sf)
        local sub = worn and LWS.pieceName(worn.p) or T("IGUI_LWS_Empty")
        text(self, fit(sub, w - isz - 18, sf), tx, y + math.floor(h / 2) + 1, worn and c.text or c.textDim, worn and 0.85 or 1, sf)
    end
    if over then
        self.hoverTip = { text = LWS.slotName(slot) .. "\n" .. (worn and LWS.pieceName(worn.p) or T("IGUI_LWS_Empty")), x = x + 10, y = y + h + 4 }
    end
    self.rows[#self.rows + 1] = r
    return r
end

-- the pieces of the picked slot, with "real clothes" and "take off"
function Win:drawer(x, y, w, h, size)
    local c = H.C
    local sf = H.small()
    local worn = C.wornIn(self.slot)
    local showing = C.state.show and C.state.show[self.slot] == true
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, LWS.slotName(self.slot) .. (worn and ("  -  " .. LWS.pieceName(worn.p)) or ""))
    local bh = lineH(sf) + 8
    local bx = cx
    local function btn(id, label, on, enabled)
        local bw = math.max(100, tw(sf, label) + 20)
        self:button(id, label, bx, cy, bw, bh, on, enabled)
        bx = bx + bw + 6
    end
    btn("show", T(showing and "IGUI_LWS_ShowOn" or "IGUI_LWS_ShowOff"), showing, #(LWS.SLOT[self.slot] and LWS.SLOT[self.slot].hides or {}) > 0)
    btn("takeoff", T("IGUI_LWS_TakeOff"), false, worn ~= nil)
    local gy = cy + bh + 6
    local list = C.piecesFor(self.slot)
    if #list == 0 then
        for i, l in ipairs(wrap(T("IGUI_LWS_NoPieces"), cw - 20, sf)) do
            text(self, l, cx + 4, gy + 6 + (i - 1) * lineH(sf), c.textDim, 1, sf)
        end
        return
    end
    self:grid("pieces", cx, gy, cw, cy + ch - gy, list, function(e)
        local isWorn = worn and worn.uid == e.uid
        return { worn = isWorn, label = isWorn and T("IGUI_LWS_Wearing") or nil, labelCol = c.accent,
                 tip = T(isWorn and "IGUI_LWS_ClickTakeOff" or "IGUI_LWS_ClickWear") }
    end, size)
end

function Win:renderDress(x, y, w, h)
    local c = H.C
    local gap = 6
    local colW = math.max(170, math.min(240, math.floor(w * 0.23)))
    local tileH = math.max(34, math.floor((h - gap * 8) / 9))
    local rx = x + w - colW
    local picked
    for i, slot in ipairs(H.LEFT) do
        local r = self:slotTile(slot, x, y + (i - 1) * (tileH + gap), colW, tileH, false)
        if slot == self.slot then picked = { r = r, side = "L" } end
    end
    for i, slot in ipairs(H.RIGHT) do
        local r = self:slotTile(slot, rx, y + (i - 1) * (tileH + gap), colW, tileH, false)
        if slot == self.slot then picked = { r = r, side = "R" } end
    end
    -- the middle: the drawer of the picked slot, full height
    local sx, sw = x + colW + 12, w - 2 * colW - 24
    -- a gold line from the picked slot to the drawer
    if picked then
        local ly = picked.r.y + math.floor(picked.r.h / 2)
        if picked.side == "L" then
            self:drawRect(picked.r.x + picked.r.w, ly - 1, sx - (picked.r.x + picked.r.w), 2, 1, c.accent[1], c.accent[2], c.accent[3])
        else
            self:drawRect(sx + sw, ly - 1, picked.r.x - (sx + sw), 2, 1, c.accent[1], c.accent[2], c.accent[3])
        end
    end
    self:drawer(sx, y, sw, h)
end

-- the compact window: the 18 slots as small tiles, then the drawer
function Win:renderCompact(x, y, w, h)
    local gap = 6
    local cols = 6
    local tile = math.max(40, math.floor((w - gap * (cols - 1)) / cols))
    local order = {}
    for _, s in ipairs(H.LEFT) do order[#order + 1] = s end
    for _, s in ipairs(H.RIGHT) do order[#order + 1] = s end
    for i, slot in ipairs(order) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        self:slotTile(slot, x + col * (tile + gap), y + row * (tile + gap), tile, tile, true)
    end
    local rows = math.ceil(#order / cols)
    local dy = y + rows * (tile + gap) + 4
    self:drawer(x, dy, w, y + h - dy, { w = 84, h = 98, isz = 42, gap = 6 })
end

function Win:toggleCompact()
    H.compact = not H.compact
    log("compact: %s", tostring(H.compact))
    local core = getCore()
    if H.compact then
        H.fullW, H.fullH = self.width, self.height
        self:setWidth(H.compactW or H.COMPACT_W)
        self:setHeight(math.min(core:getScreenHeight() - 20, H.compactH or H.COMPACT_H))
        -- to the right edge of the screen, out of the character's way
        self:setX(math.max(0, core:getScreenWidth() - self.width - 20))
        self.tab = "dress"
    else
        self:setWidth(math.max(H.MIN_W, H.fullW or H.prefW or H.DEFAULT_W))
        self:setHeight(math.max(H.MIN_H, H.fullH or H.prefH or H.DEFAULT_H))
        self:setX(math.max(0, math.min(self:getX(), core:getScreenWidth() - self.width - 10)))
    end
    self.fullH = self.height
    H.savePrefs()
end

-- ----------------------------------------------------------------- tab 2: collection
function Win:renderCollection(x, y, w, h)
    local c = H.C
    local all = C.piecesFor(nil)
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, T("IGUI_LWS_CollectionTitle", tostring(#all)))
    local sf = H.small()
    -- filter chips: all + every slot that has pieces
    local counts = {}
    for _, e in ipairs(all) do local s = LWS.PIECE[e.p].slot; counts[s] = (counts[s] or 0) + 1 end
    local chips = { { id = "all", label = T("IGUI_LWS_All") .. " (" .. #all .. ")" } }
    for _, s in ipairs(LWS.SLOTS) do
        if counts[s.id] then chips[#chips + 1] = { id = s.id, label = LWS.slotName(s.id) .. " (" .. counts[s.id] .. ")" } end
    end
    local bh = lineH(sf) + 8
    local bx, by = cx, cy
    for _, chip in ipairs(chips) do
        local bw = tw(sf, chip.label) + 20
        if bx + bw > cx + cw then bx = cx; by = by + bh + 6 end
        self:button("chip:" .. chip.id, chip.label, bx, by, bw, bh, self.filter == chip.id, true)
        bx = bx + bw + 6
    end
    local gy = by + bh + 10
    local list = {}
    for _, e in ipairs(all) do
        if self.filter == "all" or LWS.PIECE[e.p].slot == self.filter then list[#list + 1] = e end
    end
    if #list == 0 then
        for i, l in ipairs(wrap(T("IGUI_LWS_CollectionEmpty"), cw - 20, sf)) do
            text(self, l, cx + 4, gy + 10 + (i - 1) * lineH(sf), c.textDim, 1, sf)
        end
        return
    end
    self:grid("collection", cx, gy, cw, cy + ch - gy, list, function(e)
        local slot = LWS.PIECE[e.p].slot
        local worn = C.wornIn(slot)
        local isWorn = worn and worn.uid == e.uid
        return { worn = isWorn, label = isWorn and T("IGUI_LWS_Wearing") or LWS.slotName(slot), labelCol = isWorn and c.accent or c.textDim,
                 tip = T("IGUI_LWS_ClickGoDress") }
    end)
end

-- ----------------------------------------------------------------- tab 3: trade
-- no trade open: requests to me (accept / decline) and the players online
-- (ask); a trade open: what I give (click to take back), my collection
-- (click to offer), what they give, agree / cancel
function Win:renderTrade(x, y, w, h)
    local c = H.C
    local sf = H.small()
    local bh = lineH(sf) + 10
    local mx, my = self:getMouseX(), self:getMouseY()
    local mp = isClient and isClient()
    local tr = C.trade
    if not tr then
        local half = math.floor((w - 8) / 2)
        local ax, ay, aw, ah = self:drawCard(x, y, half, h, T("IGUI_LWS_TradeAsks"))
        local asks = C.openAsks()
        if #asks == 0 then
            for i, l in ipairs(wrap(T(mp and "IGUI_LWS_TradeNoAsks" or "IGUI_LWS_Msg_TradeMPOnly"), aw - 10, sf)) do
                text(self, l, ax + 4, ay + 6 + (i - 1) * lineH(sf), c.textDim, 1, sf)
            end
        end
        local yy = ay
        for _, a in ipairs(asks) do
            self:drawRect(ax, yy, aw - 4, bh * 2 + 12, 1, c.accentSoft[1], c.accentSoft[2], c.accentSoft[3])
            self:drawRectBorder(ax, yy, aw - 4, bh * 2 + 12, 1, c.border[1], c.border[2], c.border[3])
            text(self, fit(T("IGUI_LWS_TradeAskFrom", a.from, tostring(a.left)), aw - 20, sf), ax + 8, yy + 6, c.text, 1, sf)
            self:button("accept:" .. a.from, T("IGUI_LWS_TradeAccept"), ax + 8, yy + bh + 4, 120, bh, true, true)
            self:button("decline:" .. a.from, T("IGUI_LWS_TradeDecline"), ax + 136, yy + bh + 4, 120, bh, false, true)
            yy = yy + bh * 2 + 18
        end
        local px, py, pw, ph = self:drawCard(x + half + 8, y, w - half - 8, h, T("IGUI_LWS_TradePlayers"))
        local players = C.otherPlayers()
        if #players == 0 then
            for i, l in ipairs(wrap(T(mp and "IGUI_LWS_TradeNobody" or "IGUI_LWS_Msg_TradeMPOnly"), pw - 10, sf)) do
                text(self, l, px + 4, py + 6 + (i - 1) * lineH(sf), c.textDim, 1, sf)
            end
            return
        end
        self.clip = { x = px, y = py, w = pw, h = ph }
        self:scrolled("tradePlayers", px, py, pw, ph, function(top)
            local ty = top
            for _, name in ipairs(players) do
                local r = { x = px, y = ty, w = pw - 10, h = bh + 8 }
                local over = inside(r, mx, my) and inside(self.clip, mx, my)
                local bg = over and c.hover or c.card
                self:drawRect(r.x, r.y, r.w, r.h, 1, bg[1], bg[2], bg[3])
                self:drawRectBorder(r.x, r.y, r.w, r.h, 1, c.borderDim[1], c.borderDim[2], c.borderDim[3])
                text(self, fit(name, r.w - 150, sf), r.x + 8, r.y + math.floor((r.h - fh(sf)) / 2), c.text, 1, sf)
                self:button("ask:" .. name, T("IGUI_LWS_TradeAsk"), r.x + r.w - 128, r.y + 4, 120, bh, false, true)
                ty = ty + r.h + 6
            end
            return ty - top
        end)
        return
    end
    -- a trade is open
    local top = y
    local bar = bh + 12
    self:drawRect(x, top, w, bar, 1, c.card[1], c.card[2], c.card[3])
    self:drawRectBorder(x, top, w, bar, 1, c.border[1], c.border[2], c.border[3])
    local status = T("IGUI_LWS_TradeWith", tostring(tr.partner)) .. "   " ..
        T(tr.myLock and "IGUI_LWS_TradeYouAgree" or "IGUI_LWS_TradeYouNot") .. "   " ..
        T(tr.theirLock and "IGUI_LWS_TradeTheyAgree" or "IGUI_LWS_TradeTheyNot")
    text(self, fit(status, w - 300, sf), x + 10, top + math.floor((bar - fh(sf)) / 2), c.text, 1, sf)
    self:button("cancelTrade", T("IGUI_LWS_TradeCancel"), x + w - 128, top + 6, 120, bh, false, true)
    self:button("lock", T(tr.myLock and "IGUI_LWS_TradeUnagree" or "IGUI_LWS_TradeAgree"), x + w - 256, top + 6, 120, bh, tr.myLock, true)
    local by = top + bar + 8
    local bhh = y + h - by
    local half = math.floor((w - 8) / 2)
    local giveH = math.floor((bhh - 8) * 0.45)
    -- what I give
    local gx, gy, gw, gh = self:drawCard(x, by, half, giveH, T("IGUI_LWS_TradeIGive", tostring(#(tr.mine or {}))))
    local offered = {}
    for _, e in ipairs(tr.mine or {}) do offered[e.uid] = true end
    if #(tr.mine or {}) == 0 then
        text(self, T("IGUI_LWS_TradeGiveHint"), gx + 4, gy + 6, c.textDim, 1, sf)
    else
        self:grid("tradeMine", gx, gy, gw, gh, tr.mine, function() return { worn = true, label = T("IGUI_LWS_TradeOffered"), labelCol = c.accent, tip = T("IGUI_LWS_ClickTakeBack") } end)
    end
    -- my collection
    local have = {}
    for _, e in ipairs(C.state.items or {}) do if not offered[e.uid] then have[#have + 1] = e end end
    local hx, hy, hw, hh2 = self:drawCard(x, by + giveH + 8, half, bhh - giveH - 8, T("IGUI_LWS_TradeMyPieces"))
    if #have == 0 then
        text(self, T("IGUI_LWS_TradeNoPieces"), hx + 4, hy + 6, c.textDim, 1, sf)
    else
        self:grid("tradeHave", hx, hy, hw, hh2, have, function(e)
            local slot = LWS.PIECE[e.p] and LWS.PIECE[e.p].slot
            local worn = slot and C.wornIn(slot)
            return { label = (worn and worn.uid == e.uid) and T("IGUI_LWS_Wearing") or LWS.slotName(slot), tip = T("IGUI_LWS_ClickOffer") }
        end)
    end
    -- what they give
    local tx, ty, tw2, th2 = self:drawCard(x + half + 8, by, w - half - 8, bhh, T("IGUI_LWS_TradeTheyGive", tostring(tr.partner), tostring(#(tr.theirs or {}))))
    if #(tr.theirs or {}) == 0 then
        text(self, T("IGUI_LWS_TradeTheyNothing"), tx + 4, ty + 6, c.textDim, 1, sf)
    else
        self:grid("tradeTheirs", tx, ty, tw2, th2, tr.theirs, function() return { label = T("IGUI_LWS_TradeForYou"), tip = T("IGUI_LWS_TradeTheirTip") } end)
    end
end

-- ----------------------------------------------------------------- tab 4: admin
function Win:renderAdmin(x, y, w, h)
    local c = H.C
    local sf = H.small()
    local data = C.admin
    if not self.adminAsked then
        self.adminAsked = true
        C.send("AdminList", { owner = self.adminOwner })
    end
    local leftW = math.max(230, math.min(300, math.floor(w * 0.28)))
    local lx, ly, lw, lh = self:drawCard(x, y, leftW, h, T("IGUI_LWS_Owners"))
    local mx, my = self:getMouseX(), self:getMouseY()
    local bh = lineH(sf) + 8
    self:button("refresh", T("IGUI_LWS_Refresh"), lx, ly, lw - 10, bh, false, true)
    local oy = ly + bh + 6
    self.clip = { x = lx, y = oy, w = lw, h = ly + lh - oy }
    self:scrolled("owners", lx, oy, lw, ly + lh - oy, function(top)
        local yy = top
        local rowH = lineH(sf) * 2 + 8
        for _, o in ipairs(data and data.owners or {}) do
            local r = { x = lx, y = yy, w = lw - 10, h = rowH - 4, owner = o.key }
            local active = self.adminOwner == o.key
            local over = inside(r, mx, my) and inside(self.clip, mx, my)
            local bg = active and c.accentSoft or (over and c.hover or c.card)
            self:drawRect(r.x, r.y, r.w, r.h, 1, bg[1], bg[2], bg[3])
            self:drawRectBorder(r.x, r.y, r.w, r.h, 1, (active and c.accent or c.borderDim)[1], (active and c.accent or c.borderDim)[2], (active and c.accent or c.borderDim)[3])
            local dot = o.online and c.good or c.borderDim
            self:drawRect(r.x + 6, r.y + 8, 7, 7, 1, dot[1], dot[2], dot[3])
            text(self, fit(o.name, r.w - 26, sf), r.x + 20, r.y + 3, c.text, 1, sf)
            text(self, fit(T("IGUI_LWS_OwnerCount", tostring(o.count or 0)) .. (o.online and "" or (" - " .. T("IGUI_LWS_Offline"))), r.w - 26, sf), r.x + 20, r.y + 3 + lineH(sf), c.textDim, 1, sf)
            self.rows[#self.rows + 1] = r
            yy = yy + rowH
        end
        if not data then text(self, T("IGUI_LWS_Loading"), lx + 4, yy + 4, c.textDim, 1, sf); yy = yy + lineH(sf) + 8 end
        return yy - top
    end)
    local rx, rw = x + leftW + 8, w - leftW - 8
    local half = math.floor((h - 8) / 2)
    -- the owner's pieces
    local view = data and data.view == self.adminOwner and data.state or nil
    local ownerName = self.adminOwner or "-"
    for _, o in ipairs(data and data.owners or {}) do if o.key == self.adminOwner then ownerName = o.name end end
    local ax, ay, aw, ah = self:drawCard(rx, y, rw, half, T("IGUI_LWS_OwnerPieces", tostring(ownerName)))
    if not self.adminOwner then
        text(self, T("IGUI_LWS_PickOwner"), ax + 4, ay + 8, c.textDim, 1, sf)
    elseif not view then
        text(self, T("IGUI_LWS_Loading"), ax + 4, ay + 8, c.textDim, 1, sf)
    elseif #view.items == 0 then
        text(self, T("IGUI_LWS_OwnerNone"), ax + 4, ay + 8, c.textDim, 1, sf)
    else
        local wornBy = {}
        for slot, uid in pairs(view.worn or {}) do wornBy[uid] = true end
        self:grid("ownerPieces", ax, ay, aw, ah, view.items, function(e)
            return { worn = wornBy[e.uid], remove = true, label = "#" .. tostring(e.uid), tip = T("IGUI_LWS_ClickRevoke") }
        end)
    end
    -- the catalog
    local kx, ky, kw, kh = self:drawCard(rx, y + half + 8, rw, h - half - 8, T("IGUI_LWS_Catalog", tostring(#LWS.CATALOG)))
    local cat = {}
    for _, cpiece in ipairs(LWS.CATALOG) do cat[#cat + 1] = { p = cpiece.id, catalog = true } end
    self:grid("catalog", kx, ky, kw, kh, cat, function(e)
        return { label = LWS.slotName(LWS.PIECE[e.p].slot), tip = self.adminOwner and T("IGUI_LWS_ClickGive", tostring(ownerName)) or T("IGUI_LWS_PickOwner") }
    end)
end

-- ----------------------------------------------------------------- tab 5: guide
function Win:renderGuide(x, y, w, h)
    local c = H.C
    local sf, mf = H.small(), H.medium()
    local leftW = math.max(200, math.min(260, math.floor(w * 0.26)))
    local lx, ly, lw, lh = self:drawCard(x, y, leftW, h, T("IGUI_LWS_Tab_guide"))
    self.chapterBounds = {}
    local mx, my = self:getMouseX(), self:getMouseY()
    local yy = ly
    for i, id in ipairs(H.GUIDE) do
        local r = { x = lx, y = yy, w = lw, h = lineH(mf) + 8, i = i }
        local active = self.guidePage == i
        local bg = active and c.accentSoft or (inside(r, mx, my) and c.hover or c.card)
        self:drawRect(r.x, r.y, r.w, r.h, 1, bg[1], bg[2], bg[3])
        self:drawRectBorder(r.x, r.y, r.w, r.h, 1, (active and c.accent or c.borderDim)[1], (active and c.accent or c.borderDim)[2], (active and c.accent or c.borderDim)[3])
        text(self, fit(T("IGUI_LWS_Guide_" .. id .. "_Title"), r.w - 16, mf), r.x + 8, r.y + 4, c.text, 1, mf)
        self.chapterBounds[#self.chapterBounds + 1] = r
        yy = yy + r.h + 6
    end
    local id = H.GUIDE[self.guidePage] or H.GUIDE[1]
    local px, py, pw, ph = self:drawCard(x + leftW + 8, y, w - leftW - 8, h, T("IGUI_LWS_Guide_" .. id .. "_Title"))
    self:scrolled("guide", px, py, pw, ph, function(top)
        local ty = top
        local body = T("IGUI_LWS_Guide_" .. id .. "_Body")
        for _, l in ipairs(wrap(body:gsub("<br>", "\n"), pw - 20, sf)) do
            if l ~= "" then text(self, l, px + 4, ty, c.text, 1, sf) end
            ty = ty + lineH(sf)
        end
        return ty - top + 10
    end)
end

-- ----------------------------------------------------------------- mouse
function Win:onMouseDown(x, y)
    if y < H.HEADER_H then
        for _, b in ipairs(self:headerButtons()) do
            if inside(b, x, y) then
                H.sound("UISelectListItem")
                if b.id == "close" then H.close()
                elseif b.id == "pin" then self:togglePin()
                elseif b.id == "plus" then H.stepText(1)
                elseif b.id == "settings" then H.openSettings()
                elseif b.id == "compact" then self:toggleCompact()
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
            H.sound("UISelectListItem")
            if self.tab ~= t.id then log("tab %s -> %s", tostring(self.tab), tostring(t.id)) end
            self.tab = t.id
            if t.id == "admin" then self.adminAsked = false end
            return true
        end
    end
    for _, b in ipairs(self.buttons or {}) do
        if inside(b, x, y) and b.enabled then
            H.sound("UISelectListItem")
            self:onButton(b.id)
            return true
        end
    end
    for _, r in ipairs(self.rows or {}) do
        -- slot tiles are not in a scroll box; the admin's owner rows are
        if inside(r, x, y) and (r.slot or inside(self:scrollBoxAt(x, y), x, y)) then
            H.sound("UISelectListItem")
            if r.slot then self.slot = r.slot; self.scroll.pieces = 0; log("slot %s", r.slot) end
            if r.owner then
                self.adminOwner = r.owner
                self.scroll.ownerPieces = 0
                C.send("AdminList", { owner = r.owner })
            end
            return true
        end
    end
    for key, list in pairs(self.tiles or {}) do
        local box = self.scrollBox and self.scrollBox[key]
        if box and inside(box, x, y) then
            for _, r in ipairs(list) do
                if inside(r, x, y) then
                    H.sound("UISelectListItem")
                    self:onTile(key, r, x, y)
                    return true
                end
            end
        end
    end
    if self.tab == "guide" then
        for _, b in ipairs(self.chapterBounds or {}) do
            if inside(b, x, y) then H.sound("UISelectListItem"); self.guidePage = b.i; self.scroll.guide = 0; return true end
        end
    end
    return true
end

function Win:scrollBoxAt(x, y)
    for _, box in pairs(self.scrollBox or {}) do if inside(box, x, y) then return box end end
    return nil
end

function Win:onButton(id)
    if id == "show" then
        local on = not (C.state.show and C.state.show[self.slot] == true)
        C.setShow(self.slot, on)
    elseif id == "takeoff" then
        C.takeOff(self.slot)
    elseif id:sub(1, 4) == "ask:" then
        C.tradeAsk(id:sub(5))
    elseif id:sub(1, 7) == "accept:" then
        C.tradeAnswer(id:sub(8), true)
    elseif id:sub(1, 8) == "decline:" then
        C.tradeAnswer(id:sub(9), false)
    elseif id == "lock" then
        C.tradeLock(not (C.trade and C.trade.myLock))
    elseif id == "cancelTrade" then
        C.tradeCancel()
    elseif id == "refresh" then
        C.send("AdminList", { owner = self.adminOwner })
    elseif id:sub(1, 5) == "chip:" then
        self.filter = id:sub(6)
        self.scroll.collection = 0
    end
end

function Win:onTile(key, r, x, y)
    local e = r.e
    if key == "pieces" then
        local worn = C.wornIn(self.slot)
        if worn and worn.uid == e.uid then C.takeOff(self.slot) else C.wear(self.slot, e.uid) end
    elseif key == "collection" then
        self.slot = LWS.PIECE[e.p].slot
        self.tab = "dress"
        log("collection -> dress, slot %s", self.slot)
    elseif key == "ownerPieces" then
        if r.remove and inside(r.remove, x, y) then
            log("admin: take piece #%s from %s", tostring(e.uid), tostring(self.adminOwner))
            C.send("AdminRevoke", { owner = self.adminOwner, uid = e.uid })
        end
    elseif key == "tradeMine" then
        C.tradeOffer(e.uid, false)
    elseif key == "tradeHave" then
        C.tradeOffer(e.uid, true)
    elseif key == "catalog" then
        if not self.adminOwner then C.say(T("IGUI_LWS_PickOwner")); return end
        log("admin: give %s to %s", tostring(e.p), tostring(self.adminOwner))
        C.send("AdminGrant", { owner = self.adminOwner, piece = e.p })
    end
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
    local minW, minH = H.MIN_W, H.MIN_H
    if H.compact then minW, minH = H.COMPACT_MIN_W, H.COMPACT_MIN_H end
    local w = math.max(minW, math.min(sw - 20, self.resizeW + getMouseX() - self.resizeMX))
    local h = math.max(minH, math.min(sh - 20, self.resizeH + getMouseY() - self.resizeMY))
    self:setWidth(w)
    self:setHeight(h)
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
    if H.compact then H.compactW, H.compactH = self.width, self.height else H.prefW, H.prefH = self.width, self.height end
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
        self:setWidth(H.DEFAULT_W); self:setHeight(H.DEFAULT_H)
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
    local ax, ay = self:getAbsoluteX(), self:getAbsoluteY()
    local over = mx >= ax and mx <= ax + self.width and my >= ay and my <= ay + self.height
    local now = getTimestampMs and getTimestampMs() or 0
    if over then self.leaveAt = nil; self:expand()
    elseif not self.collapsed then
        self.leaveAt = self.leaveAt or now
        if now - self.leaveAt >= H.FOLD_DELAY_MS then self:collapse() end
    end
end

-- ----------------------------------------------------------------- open / close
function H.open(player, tab)
    H.ensurePrefs()
    player = player or getPlayer()
    if not player then log("open: no player"); return end
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w = math.max(H.MIN_W, math.min(sw - 20, H.prefW or H.DEFAULT_W))
    local h = math.max(H.MIN_H, math.min(sh - 20, H.prefH or H.DEFAULT_H))
    if H.compact then
        w = math.max(H.COMPACT_MIN_W, math.min(sw - 20, H.compactW or H.COMPACT_W))
        h = math.max(H.COMPACT_MIN_H, math.min(sh - 20, H.compactH or H.COMPACT_H))
    end
    local win = H.window
    if not win then
        win = LWSWindowPanel:new(math.floor((sw - w) / 2), math.floor((sh - h) / 2), w, h, player)
        win:initialise()
        H.window = win
    end
    win.player = player
    if tab and win:hasTab(tab) then
        win.tab = tab
        -- another page than dress-up: the full window
        if tab ~= "dress" and H.compact then win:toggleCompact() end
    end
    if win.tab == "admin" then win.adminAsked = false end
    if not win:getIsVisible() or not win.inManager then
        win:addToUIManager()
        win.inManager = true
        win:setVisible(true)
    end
    win:bringToTop()
    log("open (%s), %d pieces in the wardrobe", tostring(win.tab), #(C.state.items or {}))
    -- fresh state (a piece may have come while it was closed)
    C.hello("window opened")
end

function H.close()
    local win = H.window
    if not win then return end
    log("close")
    win:setVisible(false)
    win:removeFromUIManager()
    win.inManager = false
end

function H.isOpen() return H.window ~= nil and H.window.inManager and H.window:getIsVisible() end
function H.toggle(player) if H.isOpen() then H.close() else H.open(player) end end
function H.refresh() end -- everything is drawn from LWS.Client each frame

-- ----------------------------------------------------------------- options, key
if PZAPI and PZAPI.ModOptions and not H.options then
    local ok = pcall(function()
        H.options = PZAPI.ModOptions:create("HARMONIE_LifeWithStyle", getText("UI_options_HARMONIE_LWS_title"))
        if H.options.addKeyBind then
            H.optKey = H.options:addKeyBind("openWindow", getText("UI_options_HARMONIE_LWS_key"), 0, getText("UI_options_HARMONIE_LWS_key_tooltip"))
        end
        if PZAPI.ModOptions.load then PZAPI.ModOptions:load() end
    end)
    if not ok then H.options = nil; log("mod options could NOT be made -- no key") else log("mod options made (key bind %s)", H.optKey and "yes" or "no") end
end

function H.onKey(key)
    local o = H.optKey
    if not key or key == 0 or not o or not o.getValue then return end
    local ok, bound = pcall(o.getValue, o)
    if ok and bound and bound ~= 0 and bound == key then log("window key pressed"); H.toggle(getPlayer()) end
end
if Events and Events.OnKeyPressed then Events.OnKeyPressed.Add(H.onKey) end

-- right-click anywhere: "Life With Style", at the top level beside The Way To
-- Attack's crafting (owner, 2026-10-20: "อยากให้ตู้เสื้อผ้าอยู่ในชั้นเดียวกับการคราฟ
-- อาวุธ ไม่อยากให้ไปอยู่ในดีบัก")
local function onWorldMenu(playerNum, context, worldObjects, test)
    if test then return end
    local p = getSpecificPlayer(playerNum)
    if not p then return end
    context:addOption(T("IGUI_LWS_Menu_Open"), p, function(pl)
        log("world right-click: open the wardrobe")
        H.open(pl, "dress")
    end)
end
if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add((HARMONIE_Ours or function(f) return f end)(onWorldMenu, "LWS"))
end

-- the HARMONIE tab of the character window: our card, also when the hub copy
-- the game loaded is an older one without it
local function registerCard()
    local Hub = HARMONIE_Hub
    if not Hub or type(Hub.CARDS) ~= "table" then log("no HARMONIE hub -- no card in the HARMONIE tab"); return end
    for _, card in ipairs(Hub.CARDS) do if card.id == "lws" then return end end
    table.insert(Hub.CARDS, { id = "lws", name = "IGUI_HUB_LWS_Name", desc = "IGUI_HUB_LWS_Desc",
        present = function() return LWSWindow ~= nil and LWSWindow.open ~= nil end,
        open = function(pl) LWSWindow.open(pl, "dress") end })
    log("added the Life With Style card to the HARMONIE tab (the loaded hub had none)")
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(registerCard) end

HARMONIE_Scroll.install(LWSWindowPanel)

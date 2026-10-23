--============================================================================
-- HARMONIE - Life With Style -- the wardrobe window (client)
--
-- Owner, 2026-10-20: "ใช้รูปแบบหน้าต่างเหมือนม็อดอื่นๆของฉันด้วย ธีมสีขาว". Our
-- windows' layout -- a header (title, A-, A+, settings, pin, close), big
-- icon tabs, content in cards, a size grip, the shared scroll bar -- in white:
--   1 dress       a paper doll: 18 boxes around a figure, a dotted line
--                 from each to its spot on the body; my pieces beside it.
--                 Drag a piece onto its box (or click it) to wear it, drag
--                 it off the box (or right-click the box) to take it off.
--                 The header's small-window button turns the whole window
--                 into a compact dresser beside the character.
--   2 collection  every piece the player has, or the whole catalog: search,
--                 kind (clothes / pets), worn / not worn, slot
--   2b gacha      the gacha items (RWZ Retention Items, moved here): search,
--                 category, a detail card with Use (or Equip for the New
--                 Dawn set) and the buffs running (LWS_Gacha.lua)
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
require "ISUI/ISTextEntryBox"
require "HARMONIE_UIKit"
require "HARMONIELifeWithStyle/LWS_Core"
require "HARMONIELifeWithStyle/LWS_Client"
require "HARMONIELifeWithStyle/LWS_GachaData"

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
H.COMPACT_W, H.COMPACT_H = 400, 700
H.COMPACT_MIN_W, H.COMPACT_MIN_H = 340, 480
-- owner, 2026-10-20: "ทำให้ช่องสวมใส่เป็นช่องที่อยู่บน ui รูปคน แล้วใช้การลากไอเท็ม
-- เข้าไปใส่ หรือคลิกที่ชองเพื่อใส่ก็ได้" -- the dress-up page is a paper doll.
-- H.DOLL: each slot's spot on doll.png (256x512 pixels, tools/gen_lws_art.py);
-- each column is in the order of its spots, top to bottom, so no lines cross
H.DOLL_W, H.DOLL_H = 256, 512
H.DOLL = {
    hat = { 128, 26 }, ears = { 103, 58 }, neck = { 128, 94 }, outer = { 84, 130 }, top = { 116, 170 },
    waist = { 106, 250 }, wrist = { 46, 262 }, bottom = { 110, 350 }, shoes = { 110, 488 },
    extra = { 176, 30 }, eyes = { 140, 50 }, mask = { 146, 68 }, makeup = { 130, 80 }, back = { 172, 130 },
    full = { 150, 210 }, hands = { 208, 288 }, rings = { 212, 306 }, tail = { 150, 312 },
    pet = { 206, 486 },   -- at the feet: the pet walks beside you (LWS_Pets.lua)
}
H.LEFT = { "hat", "ears", "neck", "outer", "top", "waist", "wrist", "bottom", "shoes" }
H.RIGHT = { "extra", "eyes", "mask", "makeup", "back", "full", "hands", "rings", "tail", "pet" }
H.TILE_W, H.TILE_H = 116, 128
H.GUIDE = { "What", "Dress", "Show", "Pet", "Gacha", "Death", "Trade", "Admin", "Soon" }

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
    local list = { "dress", "collection", "gacha", "trade" }
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
    local icon = opts.icon and texture(opts.icon) or (e.p and pieceIcon(e.p))
    local isz = opts.isz or 56
    if icon then self:drawTextureScaled(icon, x + math.floor((w - isz) / 2), y + 10, isz, isz, opts.dim and 0.3 or 1, 1, 1, 1) end
    local font = H.small()
    local name = opts.name or LWS.pieceName(e.p)
    local lines = wrap(name, w - 12, font)
    local ty = y + 10 + isz + 6
    -- a label under the name (Wearing, the slot...) leaves room for one line
    local bottom = opts.label and (h - lineH(font) - 4) or (h - 4)
    local room = math.max(1, math.min(2, math.floor((bottom - (10 + isz + 6)) / lineH(font))))
    for i = 1, math.min(room, #lines) do
        local l = lines[i]
        if i == room and #lines > room then l = l .. " " .. lines[i + 1] end  -- cut with "..."
        l = fit(l, w - 10, font)
        text(self, l, x + math.floor((w - tw(font, l)) / 2), ty, opts.dim and c.textDim or c.text, 1, font)
        ty = ty + lineH(font)
    end
    if opts.badge then
        local bw = tw(font, opts.badge) + 10
        self:drawRect(x + w - bw - 4, y + 4, bw, lineH(font) + 2, 1, c.accent[1], c.accent[2], c.accent[3])
        text(self, opts.badge, x + w - bw + 1, y + 5, { 1, 1, 1 }, 1, font)
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
        local tip = opts.tipText or (name .. "\n" .. LWS.slotName(LWS.PIECE[e.p] and LWS.PIECE[e.p].slot or ""))
        self.hoverTip = { text = tip .. (opts.tip and ("\n" .. opts.tip) or ""), x = x + 20, y = y + h + 4 }
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

-- a search box (a real text box, the one child widget): shown only in the
-- frames that ask for it; returns what is typed, lower case
function Win:searchBox(key, x, y, w, h)
    self.searchBoxes = self.searchBoxes or {}
    local b = self.searchBoxes[key]
    if not b then
        b = ISTextEntryBox:new("", x, y, w, h)
        b.font = UIFont.Small
        b:initialise()
        b:instantiate()
        if b.setPlaceholderText then pcall(function() b:setPlaceholderText(T("IGUI_LWS_Search")) end) end
        -- dark ink on the white window (the default is light text for dark windows)
        local okInk = pcall(function() b.javaObject:setTextColor(ColorInfo.new(0.14, 0.12, 0.11, 1)) end)
        if okInk then
            b.backgroundColor = { r = 1, g = 1, b = 1, a = 1 }
        else
            b.backgroundColor = { r = 0.22, g = 0.19, b = 0.17, a = 1 }
            LWS.logOnce("searchink", "Window", "search box: no setTextColor -- dark box instead")
        end
        b.borderColor = { r = H.C.border[1], g = H.C.border[2], b = H.C.border[3], a = 1 }
        local win = self
        b.onTextChange = function() win.scroll[key] = 0 end
        self:addChild(b)
        self.searchBoxes[key] = b
        log("search box made: %s", key)
    end
    if b.x ~= x or b.y ~= y then b:setX(x); b:setY(y) end
    if b.width ~= w then b:setWidth(w) end
    if not b:getIsVisible() then b:setVisible(true) end
    self.searchShown[key] = true
    local ok, txt = pcall(function() return b:getText() end)
    return ok and string.lower(tostring(txt or "")) or ""
end

function Win:hideUnusedSearch()
    for key, b in pairs(self.searchBoxes or {}) do
        if not self.searchShown[key] and b:getIsVisible() then b:setVisible(false) end
    end
end

local function matches(q, ...)
    if not q or q == "" then return true end
    for _, s in ipairs({ ... }) do
        if s and string.find(string.lower(tostring(s)), q, 1, true) then return true end
    end
    return false
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
        self.searchShown = {}
        local x, y = 8, self:contentTop()
        local w, h = self.width - 16, self.height - y - 8
        if H.compact then self:renderCompact(x, y, w, h)
        elseif self.tab == "dress" then self:renderDress(x, y, w, h)
        elseif self.tab == "collection" then self:renderCollection(x, y, w, h)
        elseif self.tab == "gacha" then self:renderGacha(x, y, w, h)
        elseif self.tab == "admin" then self:renderAdmin(x, y, w, h)
        elseif self.tab == "trade" then self:renderTrade(x, y, w, h)
        else self:renderGuide(x, y, w, h) end
        if H.compact or self.tab == "dress" then self:drawDragged() end
        local c = H.C
        local gx, gy = self.width - 16, self.height - 16
        for i, len in ipairs({ 12, 8, 4 }) do
            local o = (i - 1) * 4
            self:drawRect(gx + 10 - o, gy + 14 - len, 2, len, 0.9 - 0.15 * (i - 1), c.accent[1], c.accent[2], c.accent[3])
        end
    end
    if self.collapsed then self.searchShown = {} end
    self:hideUnusedSearch()
    self:drawHoverTip()
    self:updatePin()
end

function Win:drawHoverTip()
    local t = self.hoverTip
    if self.dragging then return end
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
-- owner, 2026-10-20: "ไม่อยากใช้รูปแบบการสวมใส่แบบเดิม มันดูไม่มีสไตล์", then the
-- paper doll (0.4.0). (The 3D character of 0.3.0 did not show in the game --
-- owner: "3d ไม่ขึ้น ไม่ต้องมีก็ได้" -- removed.)

-- one box on the doll; returns its rect. While a piece is dragged its own
-- box lights up and the others fade.
function Win:slotBox(slot, x, y, B, dragSlot)
    local c = H.C
    local mx, my = self:getMouseX(), self:getMouseY()
    local r = { x = x, y = y, w = B, h = B, slot = slot }
    local active = self.slot == slot
    local over = inside(r, mx, my)
    local worn = C.wornIn(slot)
    local target = dragSlot ~= nil and dragSlot == slot
    local bg = target and c.accentSoft or (active and c.accentSoft or (over and c.hover or c.card))
    self:drawRect(x, y, B, B, 1, bg[1], bg[2], bg[3])
    local bd = (target or active) and c.accent or (worn and c.border or c.borderDim)
    self:drawRectBorder(x, y, B, B, 1, bd[1], bd[2], bd[3])
    if target or active then self:drawRectBorder(x + 1, y + 1, B - 2, B - 2, 1, c.accent[1], c.accent[2], c.accent[3]) end
    if target and over then self:drawRectBorder(x + 2, y + 2, B - 4, B - 4, 1, c.accent[1], c.accent[2], c.accent[3]) end
    local sf = H.small()
    local icon = worn and pieceIcon(worn.p)
    if icon then
        self:drawTextureScaled(icon, x + 4, y + 4, B - 8, B - 8, 1, 1, 1, 1)
    else
        -- an empty box says what goes in it, when the name fits (two lines);
        -- a small box gets a faint + (the tip and the line to the body say it)
        local lines = wrap(LWS.slotName(slot), B - 6, sf)
        local fits = #lines <= 2 and #lines * lineH(sf) <= B - 4
        for _, l in ipairs(lines) do if tw(sf, l) > B - 6 then fits = false end end
        if fits then
            local ty = y + math.floor((B - #lines * lineH(sf)) / 2)
            for _, l in ipairs(lines) do
                text(self, l, x + math.floor((B - tw(sf, l)) / 2), ty, c.textDim, 0.9, sf)
                ty = ty + lineH(sf)
            end
        else
            local ps = math.floor(B * 0.36)
            local px, py = x + math.floor((B - ps) / 2), y + math.floor((B - ps) / 2)
            self:drawRect(px, py + math.floor(ps / 2) - 1, ps, 2, 1, c.borderDim[1], c.borderDim[2], c.borderDim[3])
            self:drawRect(px + math.floor(ps / 2) - 1, py, 2, ps, 1, c.borderDim[1], c.borderDim[2], c.borderDim[3])
        end
    end
    if worn and C.state.show and C.state.show[slot] then
        self:drawRect(x + B - 9, y + 3, 6, 6, 1, c.good[1], c.good[2], c.good[3])
    end
    if dragSlot ~= nil and not target then self:drawRect(x, y, B, B, 0.55, 0.985, 0.98, 0.972) end
    if over and not self.dragging then
        self.hoverTip = { text = LWS.slotName(slot) .. "\n" .. (worn and LWS.pieceName(worn.p) or T("IGUI_LWS_Empty"))
            .. "\n" .. T(worn and "IGUI_LWS_BoxTipWorn" or "IGUI_LWS_BoxTipEmpty"), x = x + 10, y = y + B + 4 }
    end
    self.rows[#self.rows + 1] = r
    return r
end

-- a dotted line (small squares) from (x1, y1) to (x2, y2)
function Win:dotted(x1, y1, x2, y2, col, a, size)
    local dx, dy = x2 - x1, y2 - y1
    local n = math.max(1, math.floor(math.sqrt(dx * dx + dy * dy) / 7))
    local half = math.floor(size / 2)
    for i = 0, n do
        local t = i / n
        self:drawRect(math.floor(x1 + dx * t) - half, math.floor(y1 + dy * t) - half, size, size, a, col[1], col[2], col[3])
    end
end

-- the box size for a doll area of this height
local function boxSize(h, w)
    local rows = math.max(#H.LEFT, #H.RIGHT)
    local B = math.min(60, math.floor((h - 4 * (rows - 1)) / rows))
    if w then B = math.min(B, math.floor((w - 90) / 2)) end
    return math.max(26, B)
end

-- the doll in x, y, w, h: the picture in the middle, 9 boxes on each side,
-- a dotted gold line from each box to its spot on the body
function Win:drawDoll(x, y, w, h)
    local c = H.C
    local B = boxSize(h, w)
    local dh = h
    local dw = math.floor(dh * H.DOLL_W / H.DOLL_H)
    local room = w - 2 * B - 24
    if dw > room then dw = room; dh = math.floor(dw * H.DOLL_H / H.DOLL_W) end
    local dx, dy = x + math.floor((w - dw) / 2), y + math.floor((h - dh) / 2)
    local s = dw / H.DOLL_W
    local doll = texture(UI_DIR .. "doll.png")
    if doll then self:drawTextureScaled(doll, dx, dy, dw, dh, 1, 1, 1, 1) end
    local drag = self.dragging and self.press and self.press.e
    local dragSlot = drag and LWS.PIECE[drag.p] and LWS.PIECE[drag.p].slot or nil
    local boxes = {}
    for _, side in ipairs({ { H.LEFT, x }, { H.RIGHT, x + w - B } }) do
        local step = (h - B) / math.max(1, #side[1] - 1)
        for i, slot in ipairs(side[1]) do
            boxes[#boxes + 1] = { slot = slot, x = side[2], y = y + math.floor((i - 1) * step), left = side[2] == x }
        end
    end
    -- the lines first, the boxes over them
    for _, b in ipairs(boxes) do
        local a = H.DOLL[b.slot] or { 128, 256 }
        local ax, ay = dx + a[1] * s, dy + a[2] * s
        local hot = b.slot == self.slot or b.slot == dragSlot
        local worn = C.wornIn(b.slot) ~= nil
        local col = (hot or worn) and c.accent or c.borderDim
        self:dotted(b.left and (b.x + B) or b.x, b.y + math.floor(B / 2), ax, ay, col, hot and 1 or (worn and 0.75 or 0.6), hot and 3 or 2)
        local d = hot and 7 or 5
        self:drawRect(math.floor(ax - d / 2), math.floor(ay - d / 2), d, d, 1, col[1], col[2], col[3])
    end
    for _, b in ipairs(boxes) do self:slotBox(b.slot, b.x, b.y, B, dragSlot) end
end

-- every piece I have (or those of the picked slot); drag one onto the doll
-- or click it; "real clothes" and "take off" for the picked slot
function Win:wardrobe(x, y, w, h, size)
    local c = H.C
    local sf = H.small()
    local all = C.piecesFor(nil)
    local mine = C.piecesFor(self.slot)
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, T("IGUI_LWS_CollectionTitle", tostring(#all)))
    local bh = lineH(sf) + 8
    local bx, by = cx, cy
    local function btn(id, label, on, enabled)
        local bw = math.max(70, tw(sf, label) + 20)
        if bx > cx and bx + bw > cx + cw then bx = cx; by = by + bh + 6 end
        self:button(id, label, bx, by, bw, bh, on, enabled)
        bx = bx + bw + 6
    end
    btn("dress:all", T("IGUI_LWS_All") .. " (" .. #all .. ")", self.dressFilter ~= "slot", true)
    btn("dress:slot", LWS.slotName(self.slot) .. " (" .. #mine .. ")", self.dressFilter == "slot", true)
    bx = bx + 8
    local worn = C.wornIn(self.slot)
    local gy
    if self.slot == "pet" then
        -- the pet: orders, food, and how it is
        local pet = C.pet or {}
        local out = worn ~= nil and pet.out == true
        local cmd = out and pet.commands ~= false
        btn("pet:follow", T("IGUI_LWS_PetFollow"), out and pet.mode ~= "stay", cmd)
        btn("pet:stay", T("IGUI_LWS_PetStay"), out and pet.mode == "stay", cmd)
        btn("pet:come", T("IGUI_LWS_PetCome"), false, cmd)
        btn("pet:speak", T("IGUI_LWS_PetSpeak"), false, cmd)
        btn("pet:feed", T("IGUI_LWS_PetFeed"), false, out and pet.feeding ~= false)
        btn("takeoff", T("IGUI_LWS_PetPutAway"), false, worn ~= nil)
        local line
        if pet.enabled == false then line = T("IGUI_LWS_PetOff")
        elseif not worn then line = T("IGUI_LWS_PetNone")
        elseif not out then line = T("IGUI_LWS_PetComing")
        else
            line = T(pet.mode == "stay" and "IGUI_LWS_PetStaying" or "IGUI_LWS_PetFollowing", LWS.pieceName(worn.p))
            if pet.hungerOn ~= false then line = line .. "   " .. T("IGUI_LWS_PetHunger", tostring(math.floor((tonumber(pet.hunger) or 1) * 100 + 0.5))) end
        end
        text(self, fit(line, cw - 8, sf), cx + 2, by + bh + 6, (pet.hunger and pet.hunger < 0.25 and out) and c.bad or c.textDim, 1, sf)
        gy = by + bh + 6 + lineH(sf) + 4
    else
        local showing = C.state.show and C.state.show[self.slot] == true
        btn("show", T(showing and "IGUI_LWS_ShowOn" or "IGUI_LWS_ShowOff"), showing, worn ~= nil and #(LWS.SLOT[self.slot] and LWS.SLOT[self.slot].hides or {}) > 0)
        btn("takeoff", T("IGUI_LWS_TakeOff"), false, worn ~= nil)
        gy = by + bh + 6
    end
    -- the hint at the bottom
    local hint = wrap(T("IGUI_LWS_DollHint"), cw - 8, sf)
    if #hint > 2 then hint = wrap(T("IGUI_LWS_DollHintShort"), cw - 8, sf) end
    local hn = math.min(2, #hint)
    local bottom = cy + ch - hn * lineH(sf) - 4
    for i = 1, hn do text(self, fit(hint[i], cw - 8, sf), cx + 2, bottom + 4 + (i - 1) * lineH(sf), c.textDim, 1, sf) end
    local list = self.dressFilter == "slot" and mine or all
    if #list == 0 then
        for i, l in ipairs(wrap(T(#all == 0 and "IGUI_LWS_CollectionEmpty" or "IGUI_LWS_NoPieces"), cw - 20, sf)) do
            text(self, l, cx + 4, gy + 6 + (i - 1) * lineH(sf), c.textDim, 1, sf)
        end
        return
    end
    self:grid("wardrobe", cx, gy, cw, bottom - gy, list, function(e)
        local slot = LWS.PIECE[e.p].slot
        local w2 = C.wornIn(slot)
        local isWorn = w2 and w2.uid == e.uid
        return { worn = isWorn, label = isWorn and T("IGUI_LWS_Wearing") or LWS.slotName(slot), labelCol = isWorn and c.accent or c.textDim,
                 tip = T(isWorn and "IGUI_LWS_DragTipWorn" or "IGUI_LWS_DragTip") }
    end, size)
end

function Win:renderDress(x, y, w, h)
    local dollW = math.min(math.floor(w * 0.56), math.floor(h * H.DOLL_W / H.DOLL_H) + 2 * boxSize(h) + 40)
    local dx, dy, dw, dh = self:drawCard(x, y, dollW, h, T("IGUI_LWS_Tab_dress"))
    self:drawDoll(dx, dy, dw, dh)
    self:wardrobe(x + dollW + 8, y, w - dollW - 8, h)
end

-- the compact window: the doll on top, the pieces under it
function Win:renderCompact(x, y, w, h)
    local dh = math.floor(h * 0.58)
    self:drawDoll(x, y, w, dh)
    self:wardrobe(x, y + dh + 8, w, h - dh - 8, { w = 84, h = 98, isz = 42, gap = 6 })
end

-- ----------------------------------------------------------------- drag and drop
-- press on a piece (or a worn box) and move: it follows the mouse; let go on
-- its box to wear it, anywhere else from a box to take it off. No move = a click.
H.DRAG_PX = 5

function Win:dragMove()
    local p = self.press
    if not p or self.dragging or not p.e then return end
    local dx, dy = self:getMouseX() - p.x, self:getMouseY() - p.y
    if dx * dx + dy * dy >= H.DRAG_PX * H.DRAG_PX then
        self.dragging = true
        log("drag %s (%s)", tostring(p.e.p), p.box and ("from the " .. p.box .. " box") or "from the wardrobe")
    end
end

function Win:boxAt(x, y)
    for _, r in ipairs(self.rows or {}) do if r.slot and inside(r, x, y) then return r end end
    return nil
end

function Win:wearPiece(e)
    local slot = LWS.PIECE[e.p] and LWS.PIECE[e.p].slot
    if not slot then return end
    self.slot = slot
    local worn = C.wornIn(slot)
    if worn and worn.uid == e.uid then return end
    C.wear(slot, e.uid)
end

function Win:drop(p, x, y)
    local box = self:boxAt(x, y)
    local slot = LWS.PIECE[p.e.p] and LWS.PIECE[p.e.p].slot
    if box then
        if box.slot == p.box then return end
        if box.slot == slot then
            log("dropped %s on the %s box: wear", tostring(p.e.p), tostring(slot))
            self:wearPiece(p.e)
        else
            log("dropped %s on the %s box: wrong slot (it goes in %s)", tostring(p.e.p), tostring(box.slot), tostring(slot))
            C.say(T("IGUI_LWS_Msg_WrongSlot", LWS.pieceName(p.e.p), LWS.slotName(slot)))
        end
    elseif p.box then
        log("dragged %s off the %s box: take off", tostring(p.e.p), p.box)
        C.takeOff(p.box)
    end
end

function Win:click(p)
    if p.box then
        self.slot = p.box
        self.dressFilter = "slot"
        self.scroll.wardrobe = 0
        log("slot %s", p.box)
        return
    end
    local slot = LWS.PIECE[p.e.p] and LWS.PIECE[p.e.p].slot
    local worn = slot and C.wornIn(slot)
    if worn and worn.uid == p.e.uid then self.slot = slot; C.takeOff(slot) else self:wearPiece(p.e) end
end

-- the dragged piece under the mouse
function Win:drawDragged()
    if not self.dragging or not self.press or not self.press.e then return end
    local icon = pieceIcon(self.press.e.p)
    local mx, my = self:getMouseX(), self:getMouseY()
    local c = H.C
    self:drawRect(mx - 24, my - 24, 48, 48, 0.85, 1, 1, 1)
    self:drawRectBorder(mx - 24, my - 24, 48, 48, 1, c.accent[1], c.accent[2], c.accent[3])
    if icon then self:drawTextureScaled(icon, mx - 20, my - 20, 40, 40, 0.95, 1, 1, 1) end
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
-- owner, 2026-10-23: "ให้มีหน้ารวมของแฟชั่นและให้มีการค้นหาและฟิลเตอร์" -- my pieces or
-- the whole catalog (what I do not have yet greyed), search by name or slot,
-- kind (clothes / pets), worn / not worn, slot
function Win:chips(prefix, list, cur, x, y, maxW, bh)
    local sf = H.small()
    local bx, by = x, y
    for _, chip in ipairs(list) do
        local bw = tw(sf, chip.label) + 20
        if bx > x and bx + bw > x + maxW then bx = x; by = by + bh + 6 end
        self:button(prefix .. chip.id, chip.label, bx, by, bw, bh, cur == chip.id, chip.enabled ~= false)
        bx = bx + bw + 6
    end
    return by + bh + 6
end

function Win:renderCollection(x, y, w, h)
    local c = H.C
    local sf = H.small()
    local mine = C.piecesFor(nil)
    local whole = self.colCatalog == true
    local title = whole and T("IGUI_LWS_CatalogAll", tostring(#LWS.CATALOG), tostring(#mine)) or T("IGUI_LWS_CollectionTitle", tostring(#mine))
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, title)
    local bh = lineH(sf) + 8
    -- the search box, and "mine / whole catalog"
    local sw = math.min(320, math.floor(cw * 0.45))
    local q = self:searchBox("collection", cx, cy, sw, bh)
    local bx = cx + sw + 10
    self:button("col:mine", T("IGUI_LWS_ColMine"), bx, cy, 110, bh, not whole, true)
    self:button("col:catalog", T("IGUI_LWS_ColCatalog"), bx + 116, cy, 130, bh, whole, true)
    local yy = cy + bh + 6
    -- the list before the filters (for the counts on the chips)
    local owned = {}
    for _, e in ipairs(mine) do owned[e.p] = owned[e.p] or e end
    local base = {}
    if whole then
        for _, piece in ipairs(LWS.CATALOG) do base[#base + 1] = owned[piece.id] or { p = piece.id, missing = true } end
    else
        for _, e in ipairs(mine) do base[#base + 1] = e end
    end
    local function wornE(e)
        if e.missing then return false end
        local wn = C.wornIn(LWS.PIECE[e.p].slot)
        return wn ~= nil and wn.uid == e.uid
    end
    local kind, worn, slot = self.colType or "all", self.colWorn or "all", self.filter or "all"
    local function pass(e, skip)
        local piece = LWS.PIECE[e.p]
        if not piece then return false end
        if skip ~= "kind" and kind ~= "all" and ((kind == "pets") ~= (piece.pet ~= nil)) then return false end
        if skip ~= "worn" and worn ~= "all" and ((worn == "worn") ~= wornE(e)) then return false end
        if skip ~= "slot" and slot ~= "all" and piece.slot ~= slot then return false end
        return matches(q, LWS.pieceName(e.p), LWS.slotName(piece.slot))
    end
    local function count(skip, f) local n = 0; for _, e in ipairs(base) do if pass(e, skip) and f(e) then n = n + 1 end end; return n end
    yy = self:chips("col:type:", {
        { id = "all", label = T("IGUI_LWS_All") .. " (" .. count("kind", function() return true end) .. ")" },
        { id = "clothes", label = T("IGUI_LWS_ColClothes") .. " (" .. count("kind", function(e) return not LWS.PIECE[e.p].pet end) .. ")" },
        { id = "pets", label = T("IGUI_LWS_ColPets") .. " (" .. count("kind", function(e) return LWS.PIECE[e.p].pet ~= nil end) .. ")" },
    }, kind, cx, yy, math.floor(cw / 2) - 10, bh)
    local wy = cy + bh + 6
    local wx = cx + math.floor(cw / 2)
    self:chips("col:worn:", {
        { id = "all", label = T("IGUI_LWS_All") },
        { id = "worn", label = T("IGUI_LWS_ColWorn") .. " (" .. count("worn", wornE) .. ")", enabled = true },
        { id = "notworn", label = T("IGUI_LWS_ColNotWorn") .. " (" .. count("worn", function(e) return not wornE(e) end) .. ")" },
    }, worn, wx, wy, math.floor(cw / 2), bh)
    -- slot chips: every slot that has something under the other filters
    local per = {}
    for _, e in ipairs(base) do if pass(e, "slot") then local sl = LWS.PIECE[e.p].slot; per[sl] = (per[sl] or 0) + 1 end end
    local slots = { { id = "all", label = T("IGUI_LWS_AllSlots") } }
    for _, sdef in ipairs(LWS.SLOTS) do
        if per[sdef.id] then slots[#slots + 1] = { id = sdef.id, label = LWS.slotName(sdef.id) .. " (" .. per[sdef.id] .. ")" } end
    end
    yy = self:chips("chip:", slots, slot, cx, yy, cw, bh)
    local gy = yy + 4
    local list = {}
    for _, e in ipairs(base) do if pass(e) then list[#list + 1] = e end end
    if #list == 0 then
        for i, l in ipairs(wrap(T((#base == 0 and not whole) and "IGUI_LWS_CollectionEmpty" or "IGUI_LWS_NoMatch"), cw - 20, sf)) do
            text(self, l, cx + 4, gy + 10 + (i - 1) * lineH(sf), c.textDim, 1, sf)
        end
        return
    end
    self:grid("collection", cx, gy, cw, cy + ch - gy, list, function(e)
        local pslot = LWS.PIECE[e.p].slot
        if e.missing then
            return { dim = true, label = LWS.slotName(pslot), tip = T("IGUI_LWS_NotOwned") }
        end
        local isWorn = wornE(e)
        return { worn = isWorn, label = isWorn and T("IGUI_LWS_Wearing") or LWS.slotName(pslot), labelCol = isWorn and c.accent or c.textDim,
                 tip = T("IGUI_LWS_ClickGoDress") }
    end)
end

-- ----------------------------------------------------------------- tab 2b: gacha items
-- owner, 2026-10-23: "ไอเท็มในกาชา ... แอดมินเป็นคนให้ และไม่สามารถไปโผล่ใน inventory ของ
-- vanilla และดรอปไม่ได้ ... ต้องกดใช้งานในแท็บของเรา แยกไปเป็นแท็บ ไอเท็มกาชา"
local function GC() return LWS.GachaClient end

function Win:renderGacha(x, y, w, h)
    local c = H.C
    local sf = H.small()
    local gc = GC()
    if not gc then text(self, "Gacha client not loaded", x + 10, y + 10, c.bad, 1, sf); return end
    local bh = lineH(sf) + 8
    local rightW = math.max(260, math.min(340, math.floor(w * 0.34)))
    local lw = w - rightW - 8
    local total, kinds = 0, 0
    for _, g in ipairs(LWS.GACHA_ITEMS) do local n = gc.count(g.id); if n > 0 then total = total + n; kinds = kinds + 1 end end
    local lx, ly, lww, lh = self:drawCard(x, y, lw, h, T("IGUI_LWSG_Title", tostring(total), tostring(kinds)))
    local sw = math.min(300, math.floor(lww * 0.5))
    local q = self:searchBox("gacha", lx, ly, sw, bh)
    local all = self.gachaAll == true
    self:button("gacha:mine", T("IGUI_LWS_ColMine"), lx + sw + 10, ly, 110, bh, not all, true)
    self:button("gacha:all", T("IGUI_LWSG_AllItems"), lx + sw + 126, ly, 130, bh, all, true)
    local cat = self.gachaCat or "all"
    local base = {}
    for _, g in ipairs(LWS.GACHA_ITEMS) do
        if (all or gc.count(g.id) > 0) and matches(q, T("IGUI_LWSG_Name_" .. g.id), T("IGUI_LWSG_Desc_" .. g.id), T("IGUI_LWSG_Cat_" .. g.cat)) then
            base[#base + 1] = g
        end
    end
    local per = {}
    for _, g in ipairs(base) do per[g.cat] = (per[g.cat] or 0) + 1 end
    local chips = { { id = "all", label = T("IGUI_LWS_All") .. " (" .. #base .. ")" } }
    for _, cid in ipairs(LWS.GACHA_CATEGORIES) do
        chips[#chips + 1] = { id = cid, label = T("IGUI_LWSG_Cat_" .. cid) .. " (" .. (per[cid] or 0) .. ")", enabled = (per[cid] or 0) > 0 or cat == cid }
    end
    local gy = self:chips("gacha:cat:", chips, cat, lx, ly + bh + 6, lww, bh) + 4
    local list = {}
    for _, g in ipairs(base) do if cat == "all" or g.cat == cat then list[#list + 1] = g end end
    if #list == 0 then
        local key = (kinds == 0 and not all) and "IGUI_LWSG_None" or "IGUI_LWS_NoMatch"
        for i, l in ipairs(wrap(T(key), lww - 20, sf)) do text(self, l, lx + 4, gy + 10 + (i - 1) * lineH(sf), c.textDim, 1, sf) end
    else
        self:grid("gacha", lx, gy, lww, ly + lh - gy, list, function(g)
            local n = gc.count(g.id)
            local on = g.use and g.use.set and gc.equipped(g.id)
            return { icon = g.icon, name = T("IGUI_LWSG_Name_" .. g.id), badge = n > 0 and ("x" .. n) or nil, dim = n == 0,
                     worn = self.gachaSel == g.id or on, label = on and T("IGUI_LWSG_Equipped") or T("IGUI_LWSG_Cat_" .. g.cat),
                     labelCol = on and c.accent or c.textDim,
                     tipText = T("IGUI_LWSG_Name_" .. g.id) .. "\n" .. T("IGUI_LWSG_Desc_" .. g.id) }
        end, { w = 108, h = 124, isz = 52, gap = 8 })
    end
    -- the picked item, and the buffs running
    local rx = x + lw + 8
    local half = math.floor(h * 0.58)
    local dx, dy, dw, dh = self:drawCard(rx, y, rightW, half, T("IGUI_LWSG_Detail"))
    local g = self.gachaSel and LWS.GACHA_ITEM[self.gachaSel]
    if not g then
        for i, l in ipairs(wrap(T("IGUI_LWSG_PickOne"), dw - 8, sf)) do text(self, l, dx + 2, dy + 6 + (i - 1) * lineH(sf), c.textDim, 1, sf) end
    else
        local n = gc.count(g.id)
        local icon = texture(g.icon)
        if icon then self:drawTextureScaled(icon, dx, dy, 64, 64, n > 0 and 1 or 0.35, 1, 1, 1) end
        local mf = H.medium()
        local ty = dy
        for i, l in ipairs(wrap(T("IGUI_LWSG_Name_" .. g.id), dw - 76, mf)) do
            if i <= 2 then text(self, l, dx + 72, ty, c.text, 1, mf); ty = ty + lineH(mf) end
        end
        text(self, fit(T("IGUI_LWSG_Cat_" .. g.cat) .. "   " .. T("IGUI_LWSG_Have", tostring(n)), dw - 76, sf), dx + 72, ty + 2, c.textDim, 1, sf)
        ty = math.max(dy + 70, ty + lineH(sf) + 6)
        for _, l in ipairs(wrap(T("IGUI_LWSG_Desc_" .. g.id), dw - 4, sf)) do
            if ty + lineH(sf) < dy + dh - bh - 8 then text(self, l, dx + 2, ty, c.text, 1, sf) end
            ty = ty + lineH(sf)
        end
        local by = dy + dh - bh
        if g.use and g.use.set then
            local on = gc.equipped(g.id)
            self:button("gacha:equip", T(on and "IGUI_LWSG_Unequip" or "IGUI_LWSG_Equip"), dx, by, dw, bh, on, n > 0)
        else
            self:button("gacha:use", T("IGUI_LWSG_Use"), dx, by, dw, bh, false, n > 0)
        end
    end
    local bx2, by2, bw2, bh2 = self:drawCard(rx, y + half + 8, rightW, h - half - 8, T("IGUI_LWSG_Active"))
    local rows = {}
    local t = getTimestampMs and getTimestampMs() or 0
    for k, b in pairs(gc.activeBuffs()) do rows[#rows + 1] = { label = gc.buffLabel(k), left = b.u - t, s = b.s } end
    table.sort(rows, function(a, b2) return a.s < b2.s end)
    local sb, sc = gc.setBonus()
    if sc > 0 then rows[#rows + 1] = { label = T("IGUI_LWSG_SetLine", tostring(sc), tostring(math.floor(sb * 100 + 0.5))) } end
    if #rows == 0 then
        text(self, T("IGUI_LWSG_NoActive"), bx2 + 2, by2 + 4, c.textDim, 1, sf)
    else
        self:scrolled("gachaActive", bx2, by2, bw2, bh2, function(top)
            local yy = top
            for _, r in ipairs(rows) do
                local left = r.left and gc.fmt(r.left) or ""
                text(self, fit(r.label, bw2 - tw(sf, left) - 20, sf), bx2 + 2, yy, c.text, 1, sf)
                if left ~= "" then text(self, left, bx2 + bw2 - tw(sf, left) - 10, yy, c.accent, 1, sf) end
                yy = yy + lineH(sf) + 4
            end
            return yy - top
        end)
    end
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
    local gachaMode = self.adminCat == "gacha"
    local ax, ay, aw, ah = self:drawCard(rx, y, rw, half, T(gachaMode and "IGUI_LWSG_OwnerItems" or "IGUI_LWS_OwnerPieces", tostring(ownerName)))
    local gview = C.adminGacha and C.adminGacha.owner == self.adminOwner and C.adminGacha.state or nil
    if gachaMode and self.adminOwner and not gview and self.adminGachaAsked ~= self.adminOwner then
        self.adminGachaAsked = self.adminOwner
        C.send("AdminGachaView", { owner = self.adminOwner })
    end
    if gachaMode then
        if not self.adminOwner then
            text(self, T("IGUI_LWS_PickOwner"), ax + 4, ay + 8, c.textDim, 1, sf)
        elseif not gview then
            text(self, T("IGUI_LWS_Loading"), ax + 4, ay + 8, c.textDim, 1, sf)
        else
            local have = {}
            for _, gi in ipairs(LWS.GACHA_ITEMS) do if (gview.items[gi.id] or 0) > 0 then have[#have + 1] = gi end end
            if #have == 0 then text(self, T("IGUI_LWSG_None"), ax + 4, ay + 8, c.textDim, 1, sf) end
            self:grid("ownerGacha", ax, ay, aw, ah, have, function(gi)
                return { icon = gi.icon, name = T("IGUI_LWSG_Name_" .. gi.id), badge = "x" .. tostring(gview.items[gi.id]), remove = true,
                         label = T("IGUI_LWSG_Cat_" .. gi.cat), tipText = T("IGUI_LWSG_Name_" .. gi.id), tip = T("IGUI_LWSG_ClickRevoke") }
            end, { w = 104, h = 120, isz = 48, gap = 8 })
        end
    elseif not self.adminOwner then
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
    -- the catalog: fashion or gacha items
    local kx, ky, kw, kh = self:drawCard(rx, y + half + 8, rw, h - half - 8,
        gachaMode and T("IGUI_LWSG_Catalog", tostring(#LWS.GACHA_ITEMS)) or T("IGUI_LWS_Catalog", tostring(#LWS.CATALOG)))
    local sbh = lineH(sf) + 8
    self:button("admin:fashion", T("IGUI_LWS_AdminFashion"), kx, ky, 120, sbh, not gachaMode, true)
    self:button("admin:gacha", T("IGUI_LWS_AdminGacha"), kx + 126, ky, 120, sbh, gachaMode, true)
    local q = self:searchBox("admin", kx + 256, ky, math.max(120, kw - 266), sbh)
    ky, kh = ky + sbh + 6, kh - sbh - 6
    if gachaMode then
        local glist = {}
        for _, gi in ipairs(LWS.GACHA_ITEMS) do
            if matches(q, T("IGUI_LWSG_Name_" .. gi.id), T("IGUI_LWSG_Cat_" .. gi.cat)) then glist[#glist + 1] = gi end
        end
        self:grid("adminGacha", kx, ky, kw, kh, glist, function(gi)
            return { icon = gi.icon, name = T("IGUI_LWSG_Name_" .. gi.id), label = T("IGUI_LWSG_Cat_" .. gi.cat),
                     tipText = T("IGUI_LWSG_Name_" .. gi.id) .. "\n" .. T("IGUI_LWSG_Desc_" .. gi.id),
                     tip = self.adminOwner and T("IGUI_LWS_ClickGive", tostring(ownerName)) or T("IGUI_LWS_PickOwner") }
        end, { w = 104, h = 120, isz = 48, gap = 8 })
        return
    end
    local cat = {}
    for _, cpiece in ipairs(LWS.CATALOG) do
        if matches(q, LWS.pieceName(cpiece.id), LWS.slotName(cpiece.slot)) then cat[#cat + 1] = { p = cpiece.id, catalog = true } end
    end
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
            if r.slot then self.press = { box = r.slot, e = C.wornIn(r.slot), x = x, y = y }; return true end
            if r.owner then
                self.adminOwner = r.owner
                self.scroll.ownerPieces = 0
                C.send("AdminList", { owner = r.owner })
                if self.adminCat == "gacha" then C.send("AdminGachaView", { owner = r.owner }) end
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
                    if key == "wardrobe" then self.press = { e = r.e, x = x, y = y } else self:onTile(key, r, x, y) end
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
    elseif id == "pet:follow" then C.petMode("follow")
    elseif id == "pet:stay" then C.petMode("stay")
    elseif id == "pet:come" then C.petCome()
    elseif id == "pet:speak" then C.petSpeak()
    elseif id == "pet:feed" then C.petFeed(nil)
    elseif id == "col:mine" or id == "col:catalog" then
        self.colCatalog = id == "col:catalog"; self.scroll.collection = 0
    elseif id:sub(1, 9) == "col:type:" then
        self.colType = id:sub(10); self.scroll.collection = 0
    elseif id:sub(1, 9) == "col:worn:" then
        self.colWorn = id:sub(10); self.scroll.collection = 0
    elseif id == "gacha:mine" or id == "gacha:all" then
        self.gachaAll = id == "gacha:all"; self.scroll.gacha = 0
    elseif id:sub(1, 10) == "gacha:cat:" then
        self.gachaCat = id:sub(11); self.scroll.gacha = 0
    elseif id == "gacha:use" then
        if self.gachaSel and LWS.GachaClient then LWS.GachaClient.use(self.gachaSel) end
    elseif id == "gacha:equip" then
        if self.gachaSel and LWS.GachaClient then LWS.GachaClient.equip(self.gachaSel, not LWS.GachaClient.equipped(self.gachaSel)) end
    elseif id == "admin:fashion" or id == "admin:gacha" then
        self.adminCat = id:sub(7)
        if self.adminCat == "gacha" and self.adminOwner then C.send("AdminGachaView", { owner = self.adminOwner }) end
    elseif id == "dress:all" or id == "dress:slot" then
        self.dressFilter = id:sub(7)
        self.scroll.wardrobe = 0
    elseif id:sub(1, 5) == "chip:" then
        self.filter = id:sub(6)
        self.scroll.collection = 0
    end
end

function Win:onTile(key, r, x, y)
    local e = r.e
    if key == "collection" then
        if e.missing then return end
        self.slot = LWS.PIECE[e.p].slot
        self.dressFilter = "slot"
        self.tab = "dress"
        log("collection -> dress, slot %s", self.slot)
    elseif key == "gacha" then
        self.gachaSel = e.id
        log("gacha: picked %s", tostring(e.id))
    elseif key == "adminGacha" then
        if not self.adminOwner then C.say(T("IGUI_LWS_PickOwner")); return end
        log("admin: give gacha %s to %s", tostring(e.id), tostring(self.adminOwner))
        C.send("AdminGachaGrant", { owner = self.adminOwner, id = e.id, n = 1 })
    elseif key == "ownerGacha" then
        if r.remove and inside(r.remove, x, y) then
            log("admin: take gacha %s from %s", tostring(e.id), tostring(self.adminOwner))
            C.send("AdminGachaRevoke", { owner = self.adminOwner, id = e.id, n = 1 })
        end
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
    if self.press then self:dragMove() return end
    ISPanel.onMouseMove(self, dx, dy)
end
function Win:onMouseMoveOutside(dx, dy)
    if self.resizing then self:resizeTo() return end
    if self.press then self:dragMove() return end
    ISPanel.onMouseMoveOutside(self, dx, dy)
end
local function endResize(self)
    if not self.resizing then return false end
    self.resizing = false
    if H.compact then H.compactW, H.compactH = self.width, self.height else H.prefW, H.prefH = self.width, self.height end
    H.savePrefs()
    return true
end
-- the end of a press: a drop when it moved, else a click
local function endPress(self, x, y, outside)
    local p = self.press
    if not p then return false end
    local dragged = self.dragging
    self.press, self.dragging = nil, false
    if dragged then
        if outside then
            -- let go outside the window: a worn piece comes off, a wardrobe piece goes back
            if p.box then log("dragged %s out of the window: take off", tostring(p.e and p.e.p)); C.takeOff(p.box) end
        else
            self:drop(p, x, y)
        end
    elseif not outside then
        self:click(p)
    end
    return true
end
function Win:onMouseUp(x, y)
    if endResize(self) then return end
    if endPress(self, x, y, false) then return end
    ISPanel.onMouseUp(self, x, y)
end
function Win:onMouseUpOutside(x, y)
    if endResize(self) then return end
    if endPress(self, x, y, true) then return end
    ISPanel.onMouseUpOutside(self, x, y)
end
function Win:onRightMouseDown(x, y)
    if not self.collapsed and x >= self.width - H.GRIP and y >= self.height - H.GRIP then
        self:setWidth(H.DEFAULT_W); self:setHeight(H.DEFAULT_H)
        H.prefW, H.prefH = nil, nil
        H.savePrefs()
        return true
    end
    -- right-click a box on the doll: take it off
    local box = not self.collapsed and (H.compact or self.tab == "dress") and self:boxAt(x, y)
    if box then
        self.slot = box.slot
        if C.wornIn(box.slot) then H.sound("UISelectListItem"); log("right-click the %s box: take off", box.slot); C.takeOff(box.slot) end
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
    -- the pet out: the same menu as on the pet itself (LWS_PetMenu.lua)
    if LWS.PetMenu and LWS.PetMenu.build then
        local ok, err = pcall(LWS.PetMenu.build, context, p, nil)
        if not ok then LWS.logOnce("petmenu", "Window", "pet menu FAILED: %s", tostring(err)) end
    end
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

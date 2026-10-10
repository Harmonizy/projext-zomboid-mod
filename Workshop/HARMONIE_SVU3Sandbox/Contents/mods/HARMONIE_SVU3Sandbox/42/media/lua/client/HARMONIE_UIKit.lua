--[[
    HARMONIE Hub UI kit (the same file in every HARMONIE mod -- master copy
    mods/_HarmonieHub, install.sh). Owner, 2026-10-11: "หน้าต่างทั้ง 5 มี
    Consistency ที่แย่มาก ทุกหน้าต่างต้องมีตั้งค่า ในตั้งค่าต้องมีการปรับเสียง ขนาด
    หน้าต่าง ขนาดอักษร ... การ scrollbar แบบเดียวกันที่ใช้เม้าคลิกเลื่อนได้".

    HARMONIE_Scroll -- ONE scroll bar for every window of ours: a track and a
        thumb you can grab and drag (or click the track to jump); the wheel
        still works. In a window:
          HARMONIE_Scroll.bar(self, key, x, y, w, h, value, max, set, col, trackCol)
              -- each frame where the bar is (set(v) stores the new value)
          HARMONIE_Scroll.install(MyWindowClass)
              -- once: the window's mouse handlers let a drag on a bar go first

    HARMONIE_SettingsUI -- ONE settings window (the gear in every header):
        HARMONIE_SettingsUI.open(title, buildRows, theme, { textStep = n })
        rows: section / tick / slider / choice / step / button / note.
        HARMONIE_SettingsUI.commonRows(o) -- the rows every window has
        (text size, window size, pin, sound), then the mod adds its own.
]]--

require "ISUI/ISPanel"

if HARMONIE_UIKit_loaded then return end
HARMONIE_UIKit_loaded = true

-- ================================================================ scroll bars
HARMONIE_Scroll = HARMONIE_Scroll or {}
local SB = HARMONIE_Scroll
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end

function SB.bar(ui, key, x, y, w, h, value, max, set, col, trackCol)
    if not ui or (tonumber(max) or 0) <= 0 or h <= 4 then
        if ui and ui.hBars then ui.hBars[key] = nil end
        return
    end
    value = math.max(0, math.min(max, tonumber(value) or 0))
    col = col or { 0.8, 0.8, 0.8 }
    trackCol = trackCol or { col[1] * 0.4, col[2] * 0.4, col[3] * 0.4 }
    local thumbH = math.max(24, math.floor(h * h / (h + max)))
    local thumbY = y + math.floor((h - thumbH) * value / max)
    local drag = ui.hDrag and ui.hDrag.key == key
    ui:drawRect(x, y, w, h, 0.45, trackCol[1], trackCol[2], trackCol[3])
    ui:drawRect(x, thumbY, w, thumbH, drag and 1 or 0.85, col[1], col[2], col[3])
    ui.hBars = ui.hBars or {}
    ui.hBars[key] = { x = x - 3, y = y, w = w + 6, h = h, thumbY = thumbY, thumbH = thumbH, max = max, value = value, set = set, at = nowMs() }
end

-- the bar under (x, y), drawn in the last half second
local function barAt(ui, x, y)
    local t = nowMs()
    for key, b in pairs(ui.hBars or {}) do
        if t - (b.at or 0) < 500 and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then return key, b end
    end
    return nil
end

function SB.down(ui, x, y)
    local key, b = barAt(ui, x, y)
    if not key then return false end
    local grab
    if y >= b.thumbY and y <= b.thumbY + b.thumbH then
        grab = y - b.thumbY
    else
        -- the track: jump there, keep dragging from the middle of the thumb
        grab = b.thumbH / 2
    end
    ui.hDrag = { key = key, grab = grab }
    SB.move(ui, y)
    return true
end

function SB.move(ui, y)
    local d = ui.hDrag
    local b = d and ui.hBars and ui.hBars[d.key]
    if not b then return false end
    local span = math.max(1, b.h - b.thumbH)
    local frac = (y - d.grab - b.y) / span
    frac = math.max(0, math.min(1, frac))
    if b.set then pcall(b.set, frac * b.max) end
    return true
end

function SB.up(ui)
    if not ui.hDrag then return false end
    ui.hDrag = nil
    return true
end

-- wrap a window class's mouse handlers once
function SB.install(cls)
    if not cls or cls.hScrollInstalled then return end
    cls.hScrollInstalled = true
    local down, move, moveOut, up, upOut = cls.onMouseDown, cls.onMouseMove, cls.onMouseMoveOutside, cls.onMouseUp, cls.onMouseUpOutside
    cls.onMouseDown = function(self, x, y)
        if SB.down(self, x, y) then return true end
        if down then return down(self, x, y) end
        return false
    end
    cls.onMouseMove = function(self, dx, dy)
        if self.hDrag then SB.move(self, self:getMouseY()); return true end
        if move then return move(self, dx, dy) end
        return false
    end
    cls.onMouseMoveOutside = function(self, dx, dy)
        if self.hDrag then SB.move(self, self:getMouseY()); return true end
        if moveOut then return moveOut(self, dx, dy) end
        return false
    end
    cls.onMouseUp = function(self, x, y)
        if SB.up(self) then return true end
        if up then return up(self, x, y) end
        return false
    end
    cls.onMouseUpOutside = function(self, x, y)
        if SB.up(self) then return true end
        if upOut then return upOut(self, x, y) end
        return false
    end
end

-- ================================================================ settings window
-- Home Medic's windows use the game's fonts as they are
local HMFont = {
    -- the text size step of the window that opened it (0..2)
    step = 0,
    small = function() return ({ UIFont.Small, UIFont.Medium, UIFont.Large })[1 + HMFont.step] or UIFont.Small end,
    medium = function() return ({ UIFont.Medium, UIFont.Large, UIFont.Large })[1 + HMFont.step] or UIFont.Medium end,
    lineH = function(f) local tm = getTextManager(); return tm:getFontHeight(f or UIFont.Small) + 1 end,
}

HARMONIE_SettingsUI = ISPanel:derive("HARMONIE_SettingsUI")
local U = HARMONIE_SettingsUI
U.W, U.H = 520, 560
U.ICON_DIR = "media/ui/HARMONIE_"

local texCache = {}
local function icon(name)
    local p = U.ICON_DIR .. name .. ".png"
    if texCache[p] == nil then texCache[p] = getTexture(p) or false end
    return texCache[p] or nil
end

local function shadowText(panel, s, x, y, c, a, font)
    panel:drawText(s, x + 1, y + 1, 0, 0, 0, (a or 1) * 0.8, font)
    panel:drawText(s, x, y, c[1], c[2], c[3], a or 1, font)
end

local function textW(s, font) return getTextManager():MeasureStringX(font, s) end

local function fit(s, maxW, font)
    s = tostring(s or "")
    if maxW <= 0 then return "" end
    if textW(s, font) <= maxW then return s end
    while #s > 0 and textW(s .. "..", font) > maxW do
        local i = #s
        while i > 1 and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do i = i - 1 end
        s = s:sub(1, i - 1)
    end
    return s .. ".."
end

local function wrap(text, maxW, font)
    local out, line = {}, ""
    for word in tostring(text or ""):gmatch("%S+") do
        local try = line == "" and word or (line .. " " .. word)
        if textW(try, font) > maxW and line ~= "" then out[#out + 1] = line; line = word else line = try end
    end
    if line ~= "" then out[#out + 1] = line end
    return out
end

-- Home Medic's blue (HM_Theme)
U.THEME = {
    bg = { 0.012, 0.05, 0.068, 0.97 }, header = { 0.02, 0.075, 0.1, 0.98 },
    row = { 0.02, 0.07, 0.095 }, rowHover = { 0.05, 0.18, 0.24 },
    border = { 0.24, 0.74, 0.96 }, borderDim = { 0.1, 0.34, 0.46 },
    accent = { 0.3, 0.84, 1.0 }, accentDark = { 0.03, 0.24, 0.34 },
    text = { 0.93, 0.91, 0.86 }, textDim = { 0.62, 0.68, 0.76 },
}

-- console.txt: what the player changed here, and any setter that failed
local function rowName(r) return tostring(r and (r.id or r.key or r.label or r.text) or "?") end
local function klog(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print("[HARMONIE_Hub][Settings] " .. (ok and s or tostring(fmt)))
end
local function logSet(r, what, ok, err)
    if ok then klog("%s: %s", rowName(r), tostring(what))
    else klog("%s: %s FAILED: %s", rowName(r), tostring(what), tostring(err)) end
end

-- opts (optional): { textStep = 0..2 } -- the text size of the window that opens it
function U.open(title, buildRows, theme, opts)
    klog("open %s", tostring(title))
    HMFont.step = math.max(0, math.min(2, math.floor(tonumber(opts and opts.textStep) or 0)))
    if U.instance then
        local same = U.instance.title == title
        U.instance:close()
        if same then return nil end
    end
    local core = getCore()
    local sw, sh = core and core:getScreenWidth() or 1280, core and core:getScreenHeight() or 720
    local h = math.min(U.H, sh - 40)
    local o = ISPanel:new(math.floor((sw - U.W) / 2), math.floor((sh - h) / 2), U.W, h)
    setmetatable(o, U)
    U.__index = U
    o.title = title
    o.buildRows = buildRows
    o.theme = theme or U.THEME
    o.scroll = 0
    o.background = false
    o:initialise()
    o:addToUIManager()
    o:bringToTop()
    U.instance = o
    return o
end

function U:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if U.instance == self then U.instance = nil end
end

-- layout numbers (scale with the text)
function U:metrics()
    local font = HMFont.small()
    local lh = HMFont.lineH(font)
    return {
        font = font, med = HMFont.medium(), lh = lh,
        headerH = math.max(34, HMFont.lineH(HMFont.medium()) + 14),
        rowH = math.max(30, lh + 14),
        tipH = 2 * lh + 16,
        ctrlW = 230, pad = 12,
    }
end

-- one row's rect (window coordinates) and its control area
function U:layoutRows()
    local m = self:metrics()
    -- built once per open (the values are read live by each row's get())
    if not self.rows then self.rows = self.buildRows and self.buildRows() or {} end
    local rows = self.rows
    local y = m.headerH + 6 - self.scroll
    local out = {}
    for _, r in ipairs(rows) do
        local h = m.rowH
        if r.kind == "note" then
            h = math.max(m.rowH, #wrap(r.label, self.width - 2 * m.pad - 10, m.font) * m.lh + 10)
        end
        out[#out + 1] = { row = r, y = y, h = h }
        y = y + h + (r.kind == "section" and 2 or 3)
    end
    self.contentH = y + self.scroll - (m.headerH + 6)
    return out, m
end

function U:viewTop(m) return m.headerH + 6 end
function U:viewBottom(m) return self.height - m.tipH - 8 end

-- Drawing --------------------------------------------------------------------

function U:prerender()
    local C = self.theme
    self:drawRect(0, 0, self.width, self.height, C.bg[4], C.bg[1], C.bg[2], C.bg[3])
    self:drawRectBorder(0, 0, self.width, self.height, 1, C.border[1], C.border[2], C.border[3])
    local list, m = self:layoutRows()
    -- header: title, X
    self:drawRect(1, 1, self.width - 2, m.headerH - 1, C.header[4], C.header[1], C.header[2], C.header[3])
    self:drawRect(0, m.headerH - 1, self.width, 1, 0.8, C.border[1], C.border[2], C.border[3])
    local gear = icon("icon_settings")
    local tx = m.pad
    if gear then
        local s = m.headerH - 14
        self:drawTextureScaled(gear, m.pad, 7, s, s, 1, C.accent[1], C.accent[2], C.accent[3])
        tx = m.pad + s + 8
    end
    local fh = getTextManager():getFontHeight(m.med)
    shadowText(self, fit(self.title, self.width - tx - 50, m.med), tx, math.floor((m.headerH - fh) / 2), C.accent, 1, m.med)
    local cs = m.headerH - 12
    self.closeRect = { x = self.width - cs - 8, y = 6, w = cs, h = cs }
    local over = self:isOver(self.closeRect)
    self:drawRect(self.closeRect.x, 6, cs, cs, over and 0.9 or 0.6, 0.45, 0.12, 0.08)
    self:drawRectBorder(self.closeRect.x, 6, cs, cs, 1, 0.9, 0.35, 0.25)
    local x = icon("icon_close")
    if x then self:drawTextureScaled(x, self.closeRect.x + 3, 9, cs - 6, cs - 6, 1, 1, 1, 1) end

    -- the rows, clipped to the view
    local top, bottom = self:viewTop(m), self:viewBottom(m)
    self.maxScroll = math.max(0, (self.contentH or 0) - (bottom - top))
    self.scroll = math.max(0, math.min(self.scroll, self.maxScroll))
    self:setStencilRect(0, top, self.width, bottom - top)
    self.hoverRow = nil
    local my = self:getMouseY()
    local mx = self:getMouseX()
    for _, it in ipairs(list) do
        if it.y + it.h >= top and it.y <= bottom then
            local hovered = my >= it.y and my < it.y + it.h and my >= top and my <= bottom and mx >= 0 and mx <= self.width
            if hovered then self.hoverRow = it.row end
            self:drawRow(it, m, hovered)
        end
    end
    self:clearStencilRect()
    -- scroll bar (drag it, or the wheel)
    HARMONIE_Scroll.bar(self, "rows", self.width - 9, top, 7, bottom - top, self.scroll, self.maxScroll,
        function(v) self.scroll = v end, C.accent, C.borderDim)
    -- the explanation of the hovered row
    local ty = bottom + 4
    self:drawRect(m.pad - 4, ty, self.width - 2 * m.pad + 8, m.tipH, 0.85, C.row[1], C.row[2], C.row[3])
    self:drawRectBorder(m.pad - 4, ty, self.width - 2 * m.pad + 8, m.tipH, 0.7, C.borderDim[1], C.borderDim[2], C.borderDim[3])
    local tip = self.hoverRow and self.hoverRow.tip
    if tip and tip ~= "" then
        for i, l in ipairs(wrap(tip, self.width - 2 * m.pad - 8, m.font)) do
            if i > 2 then break end
            shadowText(self, l, m.pad + 2, ty + 6 + (i - 1) * m.lh, C.textDim, 1, m.font)
        end
    end
end

function U:isOver(r)
    local mx, my = self:getMouseX(), self:getMouseY()
    return r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end

-- the control area of a row: right part of it
function U:ctrlRect(it, m)
    local w = math.min(m.ctrlW, math.floor(self.width * 0.48))
    return self.width - m.pad - w - 6, it.y, w, it.h
end

local function value(fn, default)
    if not fn then return default end
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return default
end

function U:drawRow(it, m, hovered)
    local C = self.theme
    local r, y, h = it.row, it.y, it.h
    local fh = getTextManager():getFontHeight(m.font)
    local ty = y + math.floor((h - fh) / 2)
    if r.kind == "section" then
        self:drawRect(m.pad - 4, y + 2, self.width - 2 * m.pad + 8, h - 4, 0.6, C.accentDark[1], C.accentDark[2], C.accentDark[3])
        self:drawRect(m.pad + 2, y + math.floor(h / 2) - 4, 3, 8, 1, C.accent[1], C.accent[2], C.accent[3])
        shadowText(self, fit(r.label, self.width - 3 * m.pad, m.font), m.pad + 12, ty, C.accent, 1, m.font)
        return
    end
    if r.kind == "note" then
        for i, l in ipairs(wrap(r.label, self.width - 2 * m.pad - 10, m.font)) do
            shadowText(self, l, m.pad + 4, y + 5 + (i - 1) * m.lh, C.textDim, 1, m.font)
        end
        return
    end
    local bg = hovered and C.rowHover or C.row
    self:drawRect(m.pad - 4, y, self.width - 2 * m.pad + 8, h, 0.85, bg[1], bg[2], bg[3])
    local cx, _, cw = self:ctrlRect(it, m)
    shadowText(self, fit(r.label, cx - m.pad - 12, m.font), m.pad + 4, ty, C.text, 1, m.font)
    local bs = h - 8 -- square button size
    if r.kind == "tick" then
        local on = value(r.get, false) == true
        local bx = cx + cw - bs
        self:drawRect(bx, y + 4, bs, bs, 0.95, 0.02, 0.02, 0.02)
        self:drawRectBorder(bx, y + 4, bs, bs, 1, (on and C.accent or C.borderDim)[1], (on and C.accent or C.borderDim)[2], (on and C.accent or C.borderDim)[3])
        if on then
            local t = icon("icon_check")
            if t then self:drawTextureScaled(t, bx + 2, y + 6, bs - 4, bs - 4, 1, 1, 1, 1) end
        end
    elseif r.kind == "slider" then
        local v = tonumber(value(r.get, r.min)) or r.min
        local label = r.fmt and value(function() return r.fmt(v) end, tostring(v)) or tostring(v)
        local vw = math.max(52, textW(label, m.font) + 6)
        local bw = cw - vw - 8
        local by = y + math.floor(h / 2) - 3
        local frac = (r.max > r.min) and (v - r.min) / (r.max - r.min) or 0
        frac = math.max(0, math.min(1, frac))
        self:drawRect(cx, by, bw, 6, 0.9, 0.12, 0.10, 0.05)
        self:drawRect(cx, by, math.floor(bw * frac), 6, 1, C.accent[1], C.accent[2], C.accent[3])
        self:drawRectBorder(cx, by, bw, 6, 0.7, C.borderDim[1], C.borderDim[2], C.borderDim[3])
        self:drawRect(cx + math.floor(bw * frac) - 3, by - 5, 6, 16, 1, C.text[1], C.text[2], C.text[3])
        shadowText(self, label, cx + bw + 8, ty, C.text, 1, m.font)
        r._bar = { x = cx, w = bw }
    elseif r.kind == "choice" or r.kind == "step" then
        local text
        if r.kind == "step" then
            text = value(r.text, "")
        else
            local i = value(r.get, 1)
            text = (r.values and r.values[i]) or value(r.text, "")
        end
        local left = icon(r.kind == "step" and "icon_minus" or "icon_left")
        local right = icon(r.kind == "step" and "icon_plus" or "icon_right")
        for _, b in ipairs({ { cx, left }, { cx + cw - bs, right } }) do
            self:drawRect(b[1], y + 4, bs, bs, 0.95, 0.05, 0.04, 0.02)
            self:drawRectBorder(b[1], y + 4, bs, bs, 1, C.borderDim[1], C.borderDim[2], C.borderDim[3])
            if b[2] then self:drawTextureScaled(b[2], b[1] + 3, y + 7, bs - 6, bs - 6, 1, C.accent[1], C.accent[2], C.accent[3]) end
        end
        local t = fit(text, cw - 2 * bs - 12, m.font)
        shadowText(self, t, cx + math.floor((cw - textW(t, m.font)) / 2), ty, C.text, 1, m.font)
    elseif r.kind == "button" then
        local over = hovered and self:getMouseX() >= cx
        self:drawRect(cx, y + 3, cw, h - 6, over and 0.95 or 0.75, C.accentDark[1], C.accentDark[2], C.accentDark[3])
        self:drawRectBorder(cx, y + 3, cw, h - 6, 1, C.border[1], C.border[2], C.border[3])
        local t = fit(r.text or "", cw - 10, m.font)
        shadowText(self, t, cx + math.floor((cw - textW(t, m.font)) / 2), ty, C.text, 1, m.font)
    end
end

-- Input ----------------------------------------------------------------------

function U:rowAt(y)
    local list, m = self:layoutRows()
    if y < self:viewTop(m) or y > self:viewBottom(m) then return nil, m end
    for _, it in ipairs(list) do
        if y >= it.y and y < it.y + it.h then return it, m end
    end
    return nil, m
end

local function sliderValue(r, frac)
    local v = r.min + frac * (r.max - r.min)
    local step = r.step or 1
    v = r.min + math.floor((v - r.min) / step + 0.5) * step
    return math.max(r.min, math.min(r.max, v))
end

function U:onMouseDown(x, y)
    local m = self:metrics()
    if self.closeRect and self:isOver(self.closeRect) then self:close() return true end
    if y < m.headerH then
        self.dragging = true
        self.dragX, self.dragY = getMouseX() - self.x, getMouseY() - self.y
        self:bringToTop()
        return true
    end
    local it
    it, m = self:rowAt(y)
    if not it then return true end
    local r = it.row
    local cx, _, cw = self:ctrlRect(it, m)
    local bs = it.h - 8
    local function play() if getSoundManager then getSoundManager():playUISound("UISelectListItem") end end
    if r.kind == "tick" then
        if r.set then
            local nv = not (value(r.get, false) == true)
            logSet(r, "set " .. tostring(nv), pcall(r.set, nv))
        end
        play()
    elseif r.kind == "slider" and x >= cx then
        local b = r._bar or { x = cx, w = cw - 60 }
        self.sliding = { row = r, x = b.x, w = b.w }
        self:slideTo(x)
    elseif (r.kind == "choice" or r.kind == "step") and x >= cx then
        local d = (x < cx + bs + 4) and -1 or ((x > cx + cw - bs - 4) and 1 or 0)
        if d == 0 then d = 1 end
        if r.kind == "step" then
            logSet(r, d < 0 and "minus" or "plus", pcall(d < 0 and r.minus or r.plus))
        else
            local n = #(r.values or {})
            if n > 0 then
                local i = value(r.get, 0)
                if i < 1 then i = d > 0 and 0 or n + 1 end
                i = ((i - 1 + d) % n) + 1
                logSet(r, "choice " .. tostring(r.values[i]), pcall(r.set, i))
            end
        end
        play()
    elseif r.kind == "button" and x >= cx then
        if r.run then logSet(r, "pressed", pcall(r.run)) end
        play()
    end
    return true
end

function U:slideTo(mx)
    local s = self.sliding
    if not s then return end
    local bw = s.w
    local frac = math.max(0, math.min(1, (mx - s.x) / math.max(1, bw)))
    local ok, err = pcall(s.row.set, sliderValue(s.row, frac))
    if not ok then logSet(s.row, "slider", ok, err) end
end

function U:onMouseMove(dx, dy)
    if self.dragging then
        local core = getCore()
        local nx, ny = getMouseX() - self.dragX, getMouseY() - self.dragY
        if core then
            nx = math.max(0, math.min(nx, core:getScreenWidth() - self.width))
            ny = math.max(0, math.min(ny, core:getScreenHeight() - self.height))
        end
        self:setX(nx); self:setY(ny)
        return true
    end
    if self.sliding then self:slideTo(self:getMouseX()) return true end
    return false
end
function U:onMouseMoveOutside(dx, dy) return self:onMouseMove(dx, dy) end
function U:onMouseUp()
    if self.sliding then klog("%s: slider set to %s", rowName(self.sliding.row), tostring(value(self.sliding.row.get, "?"))) end
    self.dragging = false; self.sliding = nil return true
end
function U:onMouseUpOutside() self.dragging = false; self.sliding = nil return true end

function U:onMouseWheel(del)
    local m = self:metrics()
    self.scroll = math.max(0, math.min(self.maxScroll or 0, self.scroll + del * m.rowH))
    return true
end

function U:render() end


SB.install(HARMONIE_SettingsUI)

-- ---------------------------------------------------------------- the rows every window has
-- o = {
--   T = function(key) -> text,                      (labels; Hub keys IGUI_HUB_Set_*)
--   getText / setText(step 0..2)                    text size
--   resetSize = function()                           window size and place back
--   getPin / setPin                                  keep open
--   getVolume / setVolume (0..maxVolume)             this mod's sounds   -- or
--   getMuted / setMuted                              sounds on/off
-- }
function U.commonRows(o)
    o = o or {}
    local function T(k, fb)
        local t = getText and getText(k)
        if not t or t == k then return fb or k end
        return t
    end
    local rows = {
        { kind = "note", label = T("IGUI_HUB_Set_Client", "These settings are yours only (this computer). Server rules are in the sandbox options.") },
        { kind = "section", label = T("IGUI_HUB_Set_Window", "Window") },
    }
    if o.getText and o.setText then
        rows[#rows + 1] = { kind = "step", id = "text", label = T("IGUI_HUB_Set_Text", "Text size"), tip = T("IGUI_HUB_Set_Text_Tip"),
            text = function()
                local s = o.getText() or 0
                return ({ T("IGUI_HUB_Set_TextS", "Normal"), T("IGUI_HUB_Set_TextM", "Large"), T("IGUI_HUB_Set_TextL", "Largest") })[s + 1] or tostring(s)
            end,
            minus = function() o.setText(math.max(0, (o.getText() or 0) - 1)) end,
            plus = function() o.setText(math.min(2, (o.getText() or 0) + 1)) end }
    end
    if o.resetSize then
        rows[#rows + 1] = { kind = "button", id = "size", label = T("IGUI_HUB_Set_Size", "Window size and place"), tip = T("IGUI_HUB_Set_Size_Tip"),
            text = T("IGUI_HUB_Set_Reset", "Reset"), run = o.resetSize }
    end
    if o.getPin and o.setPin then
        rows[#rows + 1] = { kind = "tick", id = "pin", label = T("IGUI_HUB_Set_Pin", "Keep the window open (pin)"), tip = T("IGUI_HUB_Set_Pin_Tip"),
            get = o.getPin, set = o.setPin }
    end
    if (o.getVolume and o.setVolume) or (o.getMuted and o.setMuted) then
        rows[#rows + 1] = { kind = "section", label = T("IGUI_HUB_Set_Sound", "Sound") }
    end
    if o.getVolume and o.setVolume then
        rows[#rows + 1] = { kind = "slider", id = "volume", label = T("IGUI_HUB_Set_Volume", "Volume of this mod's sounds"), tip = T("IGUI_HUB_Set_Volume_Tip"),
            min = 0, max = o.maxVolume or 1, step = o.volumeStep or 0.1, get = o.getVolume, set = o.setVolume,
            fmt = function(v) return tostring(math.floor((tonumber(v) or 0) * 100 + 0.5)) .. "%" end }
    end
    if o.getMuted and o.setMuted then
        rows[#rows + 1] = { kind = "tick", id = "mute", label = T("IGUI_HUB_Set_Mute", "Mute this mod's sounds"), tip = T("IGUI_HUB_Set_Mute_Tip"),
            get = o.getMuted, set = o.setMuted }
    end
    return rows
end

-- a gear button drawn in a header (the windows draw their own headers)
function U.gearIcon()
    local p = U.ICON_DIR .. "icon_settings.png"
    if U._gear == nil then U._gear = getTexture(p) or false end
    return U._gear or nil
end

--[[
    HARMONIE - Home Medic : surgery minigames (client)

    One small game per procedure TYPE, reused by every operation:
      trace  -- P01 Incision        : drag the scalpel along the line
      pulse  -- P02 Hemostasis      : press each bleeder when the ring closes on it
      clean  -- P03 Irrigation      : click the debris away before time runs out
      necro  -- P04 Necrotic tissue : cut only the dark tissue
      gauge  -- P05 Aspiration      : hold to keep suction in the green band
      suture -- P08 Wound closure   : place the stitches in order
    Every game: G.new(kind, p) with p = { skill 0..1, shake 0..1.2, tool 0..1 },
    then :update(ms), :render(ui, x, y, w, h), :mouseDown/Up/Move(x, y) in
    board coordinates, .done, :score() -> 0..1. Pure drawing on the host
    panel; no world access.
]]--

HM_SurgeryGames = HM_SurgeryGames or {}
local G = HM_SurgeryGames

local DOT = "media/textures/HARMONIE_HomeMedic/surg_dot.png"
local RING = "media/textures/HARMONIE_HomeMedic/surg_ring.png"
local function tex(path)
    G._tex = G._tex or {}
    if G._tex[path] == nil then G._tex[path] = (getTexture and getTexture(path)) or false end
    return G._tex[path] or nil
end
local function rnd(n) return ZombRand and ZombRand(n) or math.random(0, n - 1) end
local function rndf() return rnd(10000) / 10000 end
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

-- circle helper (texture, or a square if the texture is missing)
local function circle(ui, cx, cy, r, a, cr, cg, cb, ring)
    local t = tex(ring and RING or DOT)
    if t then ui:drawTextureScaled(t, cx - r, cy - r, r * 2, r * 2, a, cr, cg, cb)
    else
        if ring then ui:drawRectBorder(cx - r, cy - r, r * 2, r * 2, a, cr, cg, cb)
        else ui:drawRect(cx - r, cy - r, r * 2, r * 2, a, cr, cg, cb) end
    end
end

local Base = {}
Base.__index = Base
function Base:update(ms) end
function Base:mouseDown(x, y) end
function Base:mouseUp(x, y) end
function Base:mouseMove(x, y) end
function Base:score() return clamp(self.result or 0, 0, 1) end
function Base:timeLeft() return math.max(0, (self.limit or 0) - (self.t or 0)) end
function Base:tick(ms)
    self.t = (self.t or 0) + ms
    if self.limit and self.t >= self.limit and not self.done then self:timeout() end
end
function Base:timeout() self.done = true end
-- skin background used by all games
function Base:skin(ui, x, y, w, h)
    ui:drawRect(x, y, w, h, 1, 0.55, 0.36, 0.30)
    ui:drawRect(x + 6, y + 6, w - 12, h - 12, 1, 0.78, 0.55, 0.47)
    ui:drawRectBorder(x, y, w, h, 1, 0.25, 0.12, 0.10)
end
-- sway from an unanaesthetised patient
function Base:sway(scale)
    local s = (self.p.shake or 0) * (scale or 8)
    local t = (self.t or 0) / 1000
    return math.sin(t * 2.3) * s + math.sin(t * 5.1) * s * 0.35, math.cos(t * 1.7) * s * 0.6
end

local function make(kind, p)
    local o = setmetatable({ kind = kind, p = p or {}, t = 0, done = false }, G.kinds[kind])
    o:init()
    return o
end
function G.new(kind, p) return G.kinds[kind] and make(kind, p) or nil end
G.kinds = {}
local function kind(name)
    local k = setmetatable({}, { __index = Base })
    k.__index = k
    G.kinds[name] = k
    return k
end

-- ============================================================= trace (P01)
local Trace = kind("trace")
function Trace:init()
    self.limit = 16000 + 6000 * (self.p.skill or 0)
    self.tol = 9 + 12 * (self.p.skill or 0) + 5 * (self.p.tool or 1)
    self.pts = {}
    local a1, a2 = rndf() * 0.25 + 0.1, rndf() * 0.25 + 0.1
    for i = 0, 40 do
        local u = i / 40
        self.pts[#self.pts + 1] = { u = u, v = 0.5 + math.sin(u * math.pi * 1.2) * a1 * 0.6 - math.sin(u * math.pi * 2.3) * a2 * 0.4 }
    end
    self.progress = 0; self.inside = 0; self.samples = 0; self.drawing = false; self.marks = {}
end
function Trace:pathAt(u, w, h, x, y)
    local n = #self.pts - 1
    local i = clamp(math.floor(u * n), 0, n - 1)
    local a, b = self.pts[i + 1], self.pts[i + 2]
    local f = u * n - i
    local sx, sy = self:sway(6)
    return x + 30 + (a.u + (b.u - a.u) * f) * (w - 60) + sx, y + (a.v + (b.v - a.v) * f) * h + sy
end
function Trace:update(ms) self:tick(ms) end
function Trace:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:skin(ui, x, y, w, h)
    local last
    for i = 0, 60 do
        local px, py = self:pathAt(i / 60, w, h, x, y)
        if last then
            local done = i / 60 <= self.progress
            ui:drawRect(px - 2, py - 2, 4, 4, 0.9, done and 0.55 or 0.15, done and 0.05 or 0.25, done and 0.05 or 0.55)
        end
        last = true
    end
    for _, m in ipairs(self.marks) do circle(ui, m.x, m.y, 4, 0.8, 0.6, 0.02, 0.02) end
    local sx, sy = self:pathAt(self.progress, w, h, x, y)
    circle(ui, sx, sy, 9, 0.9, 0.2, 0.9, 0.3, true)
    local ex, ey = self:pathAt(1, w, h, x, y)
    circle(ui, ex, ey, 7, 0.9, 1, 1, 1, true)
end
function Trace:mouseDown(mx, my)
    if not self.box then return end
    local x, y, w, h = unpack(self.box)
    local sx, sy = self:pathAt(self.progress, w, h, x, y)
    if (mx - sx) ^ 2 + (my - sy) ^ 2 <= (self.tol + 8) ^ 2 then self.drawing = true end
end
function Trace:mouseUp() self.drawing = false end
function Trace:mouseMove(mx, my)
    if not self.drawing or not self.box or self.done then return end
    local x, y, w, h = unpack(self.box)
    local u = clamp((mx - x - 30) / (w - 60), 0, 1)
    if u < self.progress - 0.02 then return end
    local px, py = self:pathAt(u, w, h, x, y)
    local d = math.abs(my - py)
    self.samples = self.samples + 1
    if d <= self.tol then self.inside = self.inside + 1
    elseif #self.marks < 40 then self.marks[#self.marks + 1] = { x = mx, y = my } end
    if u > self.progress and u - self.progress < 0.08 then self.progress = u end
    if self.progress >= 0.985 then self.done = true end
    self.result = (self.samples > 0 and self.inside / self.samples or 0) * self.progress
end
function Trace:timeout() self.done = true; self.result = (self.samples > 0 and self.inside / self.samples or 0) * self.progress end

-- ============================================================= pulse (P02)
local Pulse = kind("pulse")
function Pulse:init()
    self.count = 5
    self.period = 1500 - 500 * (self.p.skill or 0)
    self.window = 5 + 7 * (self.p.skill or 0) + 3 * (self.p.tool or 1)
    self.hits = {}; self.i = 0
    self:next()
end
function Pulse:next()
    self.i = self.i + 1
    if self.i > self.count then self.done = true; return end
    self.cur = { u = 0.15 + rndf() * 0.7, v = 0.2 + rndf() * 0.6, age = 0 }
end
function Pulse:ringR() return 10 + 60 * (1 - self.cur.age / self.period) end
function Pulse:update(ms)
    self:tick(ms)
    if self.done or not self.cur then return end
    self.cur.age = self.cur.age + ms
    if self.cur.age >= self.period then self.hits[#self.hits + 1] = 0; self:next() end
end
function Pulse:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:skin(ui, x, y, w, h)
    if not self.cur or self.done then return end
    local sx, sy = self:sway(5)
    local cx, cy = x + self.cur.u * w + sx, y + self.cur.v * h + sy
    circle(ui, cx, cy, 10, 1, 0.75, 0.02, 0.02)
    local r = self:ringR()
    local near = math.abs(r - 10) <= self.window
    circle(ui, cx, cy, r, 0.9, near and 0.2 or 1, near and 1 or 1, near and 0.3 or 1, true)
end
function Pulse:mouseDown(mx, my)
    if self.done or not self.cur or not self.box then return end
    local x, y, w, h = unpack(self.box)
    local sx, sy = self:sway(5)
    local cx, cy = x + self.cur.u * w + sx, y + self.cur.v * h + sy
    if (mx - cx) ^ 2 + (my - cy) ^ 2 > 40 ^ 2 then return end
    local off = math.abs(self:ringR() - 10)
    self.hits[#self.hits + 1] = off <= self.window and (1 - 0.5 * off / self.window) or 0
    self:next()
end
function Pulse:score()
    local s = 0
    for _, v in ipairs(self.hits) do s = s + v end
    return clamp(s / self.count, 0, 1)
end

-- ============================================================= clean (P03)
local Clean = kind("clean")
function Clean:init()
    self.limit = 10000 + 5000 * (self.p.skill or 0)
    self.total = 14
    self.bits = {}
    for i = 1, self.total do self.bits[i] = { u = 0.1 + rndf() * 0.8, v = 0.15 + rndf() * 0.7, alive = true, ph = rndf() * 6 } end
    self.left = self.total
    self.radius = 8 + 4 * (self.p.tool or 1)
end
function Clean:update(ms) self:tick(ms) end
function Clean:pos(b, x, y, w, h)
    local sx, sy = self:sway(4)
    local t = (self.t or 0) / 1000
    return x + b.u * w + math.sin(t * 1.3 + b.ph) * 3 + sx, y + b.v * h + math.cos(t * 1.1 + b.ph) * 3 + sy
end
function Clean:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:skin(ui, x, y, w, h)
    ui:drawRect(x + w * 0.08, y + h * 0.12, w * 0.84, h * 0.76, 0.55, 0.55, 0.08, 0.08)
    for _, b in ipairs(self.bits) do
        if b.alive then
            local cx, cy = self:pos(b, x, y, w, h)
            circle(ui, cx, cy, 6, 1, 0.45, 0.38, 0.12)
        end
    end
end
function Clean:mouseDown(mx, my)
    if self.done or not self.box then return end
    local x, y, w, h = unpack(self.box)
    for _, b in ipairs(self.bits) do
        if b.alive then
            local cx, cy = self:pos(b, x, y, w, h)
            if (mx - cx) ^ 2 + (my - cy) ^ 2 <= (self.radius + 6) ^ 2 then
                b.alive = false; self.left = self.left - 1
                if self.left <= 0 then self.done = true end
                return
            end
        end
    end
end
function Clean:score() return clamp((self.total - self.left) / self.total, 0, 1) end

-- ============================================================= necro (P04)
local Necro = kind("necro")
function Necro:init()
    self.limit = 14000 + 6000 * (self.p.skill or 0)
    self.cols, self.rows = 7, 4
    self.cells = {}
    self.dead = 0
    for i = 1, self.cols * self.rows do
        local isDead = rnd(100) < 32
        self.cells[i] = { dead = isDead, cut = false }
        if isDead then self.dead = self.dead + 1 end
    end
    if self.dead == 0 then self.cells[1].dead = true; self.dead = 1 end
    self.cutDead, self.cutGood = 0, 0
end
function Necro:update(ms) self:tick(ms) end
function Necro:cellAt(mx, my)
    if not self.box then return nil end
    local x, y, w, h = unpack(self.box)
    local gx, gy = x + 20, y + 20
    local cw, ch = (w - 40) / self.cols, (h - 40) / self.rows
    local c = math.floor((mx - gx) / cw)
    local r = math.floor((my - gy) / ch)
    if c < 0 or r < 0 or c >= self.cols or r >= self.rows then return nil end
    return r * self.cols + c + 1
end
function Necro:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:skin(ui, x, y, w, h)
    local gx, gy = x + 20, y + 20
    local cw, ch = (w - 40) / self.cols, (h - 40) / self.rows
    for i, c in ipairs(self.cells) do
        local col, row = (i - 1) % self.cols, math.floor((i - 1) / self.cols)
        local cx, cy = gx + col * cw + 2, gy + row * ch + 2
        if c.cut then
            ui:drawRect(cx, cy, cw - 4, ch - 4, 1, c.dead and 0.55 or 0.8, c.dead and 0.1 or 0.05, c.dead and 0.1 or 0.05)
        elseif c.dead then
            ui:drawRect(cx, cy, cw - 4, ch - 4, 1, 0.16, 0.12, 0.10)
            ui:drawRect(cx + 4, cy + 4, cw - 12, ch - 12, 1, 0.28, 0.22, 0.15)
        else
            ui:drawRect(cx, cy, cw - 4, ch - 4, 1, 0.86, 0.52, 0.52)
        end
    end
end
function Necro:mouseDown(mx, my)
    if self.done then return end
    local i = self:cellAt(mx, my)
    local c = i and self.cells[i]
    if not c or c.cut then return end
    c.cut = true
    if c.dead then
        self.cutDead = self.cutDead + 1
        if self.cutDead >= self.dead then self.done = true end
    else self.cutGood = self.cutGood + 1 end
end
function Necro:score() return clamp(self.cutDead / self.dead - 0.15 * self.cutGood, 0, 1) end

-- ============================================================= gauge (P05)
local Gauge = kind("gauge")
function Gauge:init()
    self.limit = 16000 + 6000 * (self.p.skill or 0)
    self.band = 0.12 + 0.10 * (self.p.skill or 0) + 0.04 * (self.p.tool or 1)
    self.level, self.fill, self.damage, self.holding = 0.2, 0, 0, false
end
function Gauge:center()
    local t = (self.t or 0) / 1000
    return 0.5 + math.sin(t * 0.9) * 0.18 + math.sin(t * 2.2) * 0.06 * (1 + (self.p.shake or 0))
end
function Gauge:update(ms)
    self:tick(ms)
    if self.done then return end
    local dt = ms / 1000
    self.level = clamp(self.level + (self.holding and 0.55 or -0.45) * dt, 0, 1)
    local c = self:center()
    if math.abs(self.level - c) <= self.band / 2 then self.fill = self.fill + dt / 7
    elseif self.level > c + self.band / 2 + 0.12 then self.damage = self.damage + dt / 10 end
    if self.fill >= 1 then self.fill = 1; self.done = true end
end
function Gauge:render(ui, x, y, w, h)
    self:skin(ui, x, y, w, h)
    local gx, gw, gy, gh = x + w / 2 - 30, 60, y + 16, h - 32
    ui:drawRect(gx, gy, gw, gh, 1, 0.08, 0.08, 0.1)
    local c = self:center()
    local bandTop = gy + gh * (1 - (c + self.band / 2))
    ui:drawRect(gx, bandTop, gw, gh * self.band, 0.85, 0.15, 0.7, 0.25)
    ui:drawRect(gx, gy, gw, gh * (1 - (c + self.band / 2 + 0.12)), 0.45, 0.8, 0.1, 0.1)
    local ly = gy + gh * (1 - self.level)
    ui:drawRect(gx - 8, ly - 2, gw + 16, 4, 1, 1, 1, 1)
    ui:drawRect(x + 24, gy + gh * (1 - self.fill), 22, gh * self.fill, 1, 0.85, 0.8, 0.35)
    ui:drawRectBorder(x + 24, gy, 22, gh, 1, 0.3, 0.3, 0.3)
end
function Gauge:mouseDown() self.holding = true end
function Gauge:mouseUp() self.holding = false end
function Gauge:score() return clamp(self.fill * (1 - self.damage), 0, 1) end

-- ============================================================= suture (P08)
local Suture = kind("suture")
function Suture:init()
    self.limit = 16000 + 6000 * (self.p.skill or 0)
    self.count = 8
    self.tol = 8 + 10 * (self.p.skill or 0) + 4 * (self.p.tool or 1)
    self.i, self.acc = 1, {}
end
function Suture:point(i, x, y, w, h)
    local u = 0.12 + (i - 1) / (self.count - 1) * 0.76
    local side = (i % 2 == 1) and -1 or 1
    local sx, sy = self:sway(5)
    return x + u * w + sx, y + h / 2 + side * h * 0.16 + sy
end
function Suture:update(ms) self:tick(ms) end
function Suture:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:skin(ui, x, y, w, h)
    ui:drawRect(x + w * 0.1, y + h / 2 - 3, w * 0.8, 6, 1, 0.55, 0.05, 0.05)
    for i = 1, self.count do
        local px, py = self:point(i, x, y, w, h)
        if i < self.i then
            circle(ui, px, py, 4, 1, 0.1, 0.1, 0.12)
            if i > 1 then
                local qx, qy = self:point(i - 1, x, y, w, h)
                ui:drawRect(math.min(px, qx), math.min(py, qy) + math.abs(py - qy) / 2 - 1, math.abs(px - qx), 2, 1, 0.1, 0.1, 0.12)
            end
        elseif i == self.i then
            circle(ui, px, py, self.tol, 0.8, 0.2, 0.9, 0.3, true)
            circle(ui, px, py, 4, 1, 1, 1, 1)
        else
            circle(ui, px, py, 3, 0.7, 1, 1, 1)
        end
    end
end
function Suture:mouseDown(mx, my)
    if self.done or not self.box then return end
    local x, y, w, h = unpack(self.box)
    local px, py = self:point(self.i, x, y, w, h)
    local d = math.sqrt((mx - px) ^ 2 + (my - py) ^ 2)
    if d > self.tol * 2.2 then return end
    self.acc[#self.acc + 1] = clamp(1 - d / (self.tol * 2), 0, 1)
    self.i = self.i + 1
    if self.i > self.count then self.done = true end
end
function Suture:score()
    local s = 0
    for _, v in ipairs(self.acc) do s = s + v end
    return clamp(s / self.count, 0, 1)
end

return G

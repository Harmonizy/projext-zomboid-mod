--[[
    HARMONIE - Home Medic : surgery minigames (client)

    One small game per procedure TYPE, reused by every operation:
      trace  -- P01 Incision        : draw the scalpel along the marked line
      pulse  -- P02 Hemostasis      : clamp each bleeding vessel as the spurt peaks
      clean  -- P03 Irrigation      : flush the dirt out of the wound
      necro  -- P04 Necrotic tissue : cut away only the dead (black) tissue
      gauge  -- P05 Aspiration      : hold to keep suction in the green band
      suture -- P08 Wound closure   : place the stitches in order
      extract   -- P06 Extraction / P14 (clot): draw the object out without
                   touching the walls of the wound track
      dialysis  -- P11 Blood purification: keep both pumps on target
      cells     -- P12 Cell graft: place the cells in ascending order
      variants  -- gauge: saw (P07), valve (P09), drill (P13); trace: catheter (P10);
                   necro: organ (P15)

    Round 2026-10-02 ("มินิเกมไม่มีความสมจริง ... ใส่ใจ texture"): every game is
    now drawn as an operative field -- surgical drape, skin painted with
    Betadine, real tissue layers, blood, the actual instrument in the hand
    (it follows the mouse and turns with it), particles, a shake when the
    patient is hurt, and sounds. Art and sounds are our own (tools/
    gen_surgery_art.py, tools/gen_surgery_sounds.py). Rules and scoring are
    unchanged; mistakes now also count as `hurt`, which the operating
    window's vitals monitor shows (heart rate climbs, alarm).

    Every game: G.new(kind, p) with p = { skill 0..1, shake 0..1.2, tool 0..1,
    variant, sid }, then :update(ms), :render(ui, x, y, w, h),
    :mouseDown/Up/Move(x, y) in host-panel coordinates, .done, :score() -> 0..1.
]]--

HM_SurgeryGames = HM_SurgeryGames or {}
local G = HM_SurgeryGames

local ART = "media/textures/HARMONIE_HomeMedic/surg/"
local function tex(name)
    G._tex = G._tex or {}
    if G._tex[name] == nil then
        G._tex[name] = (getTexture and getTexture(ART .. name .. ".png")) or false
    end
    return G._tex[name] or nil
end
local function rnd(n) return ZombRand and ZombRand(n) or math.random(0, n - 1) end
local function rndf() return rnd(10000) / 10000 end
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end

-- ============================================================= sound
G.lastSound = G.lastSound or {}
function G.sfx(name, minGapMs)
    local t = nowMs()
    if minGapMs and G.lastSound[name] and t - G.lastSound[name] < minGapMs then return end
    G.lastSound[name] = t
    if getSoundManager then pcall(function() getSoundManager():playUISound("HM_Surg_" .. name) end) end
end

-- ============================================================= drawing (host-panel coordinates)
-- A quad through four points; nil texture = a flat colour. Lines, discs,
-- rings and rotated sprites are all built from it.
local function quad(ui, t, x1, y1, x2, y2, x3, y3, x4, y4, a, r, g, b)
    local jo = ui.javaObject
    if not jo then return end
    local ax, ay = ui:getAbsoluteX(), ui:getAbsoluteY()
    jo:DrawTexture(t, ax + x1, ay + y1, ax + x2, ay + y2, ax + x3, ay + y3, ax + x4, ay + y4, r or 1, g or 1, b or 1, a or 1)
end
G.quad = quad

local function line(ui, x1, y1, x2, y2, th, a, r, g, b)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.01 then return end
    local nx, ny = -dy / len * th / 2, dx / len * th / 2
    quad(ui, nil, x1 + nx, y1 + ny, x2 + nx, y2 + ny, x2 - nx, y2 - ny, x1 - nx, y1 - ny, a, r, g, b)
end
G.line = line

local function disc(ui, cx, cy, rad, a, r, g, b)
    local seg = math.max(10, math.floor(rad / 2))
    local px, py = cx + rad, cy
    for i = 1, seg do
        local ang = i / seg * 6.2832
        local x, y = cx + math.cos(ang) * rad, cy + math.sin(ang) * rad
        quad(ui, nil, cx, cy, px, py, x, y, cx, cy, a, r, g, b)
        px, py = x, y
    end
end
G.disc = disc

local function ring(ui, cx, cy, rad, th, a, r, g, b)
    local seg = math.max(14, math.floor(rad / 1.5))
    local px, py = cx + rad, cy
    for i = 1, seg do
        local ang = i / seg * 6.2832
        local x, y = cx + math.cos(ang) * rad, cy + math.sin(ang) * rad
        line(ui, px, py, x, y, th, a, r, g, b)
        px, py = x, y
    end
end
G.ring = ring

-- arc from angle a1 to a2 (radians; 0 = right, clockwise on screen)
local function arc(ui, cx, cy, rad, th, a1, a2, a, r, g, b)
    local seg = math.max(6, math.floor(math.abs(a2 - a1) * rad / 6))
    local px, py = cx + math.cos(a1) * rad, cy + math.sin(a1) * rad
    for i = 1, seg do
        local ang = a1 + (a2 - a1) * i / seg
        local x, y = cx + math.cos(ang) * rad, cy + math.sin(ang) * rad
        line(ui, px, py, x, y, th, a, r, g, b)
        px, py = x, y
    end
end
G.arc = arc

-- whole texture into a rect
local function img(ui, name, x, y, w, h, a, r, g, b)
    local t = tex(name)
    if t then ui:drawTextureScaled(t, x, y, w, h, a or 1, r or 1, g or 1, b or 1)
    else ui:drawRect(x, y, w, h, (a or 1) * 0.6, (r or 1) * 0.5, (g or 1) * 0.3, (b or 1) * 0.3) end
end
G.img = img

-- texture rotated by `ang` about the point (px, py) of the sprite, drawn so
-- that point lands on (cx, cy). px, py in 0..1 of the sprite.
local function sprite(ui, name, cx, cy, w, h, ang, px, py, a, r, g, b)
    local t = tex(name)
    if not t then return end
    local c, s = math.cos(ang), math.sin(ang)
    local ox, oy = -(px or 0.5) * w, -(py or 0.5) * h
    local function R(x, y) x, y = x + ox, y + oy; return cx + x * c - y * s, cy + x * s + y * c end
    local x1, y1 = R(0, 0); local x2, y2 = R(w, 0); local x3, y3 = R(w, h); local x4, y4 = R(0, h)
    quad(ui, t, x1, y1, x2, y2, x3, y3, x4, y4, a, r, g, b)
end
G.sprite = sprite

-- a texture stretched along a segment (wound, vein, thread)
local function strip(ui, name, x1, y1, x2, y2, th, a, r, g, b)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.5 then return end
    sprite(ui, name, x1, y1, len, th, math.atan2(dy, dx), 0, 0.5, a, r, g, b)
end
G.strip = strip

-- ============================================================= base game
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
    -- particles
    local keep = {}
    for _, p in ipairs(self.parts or {}) do
        p.age = p.age + ms
        if p.age < p.ttl then
            p.vy = p.vy + (p.grav or 0) * ms
            p.x, p.y = p.x + p.vx * ms, p.y + p.vy * ms
            keep[#keep + 1] = p
        end
    end
    self.parts = keep
    if self.shakeUntil and self.t > self.shakeUntil then self.shakeAmt = 0 end
end
function Base:timeout() self.done = true end

-- the host feeds the mouse even when no game rule cares
function Base:track(x, y)
    if self.cx then
        local dx, dy = x - self.cx, y - self.cy
        if dx * dx + dy * dy > 4 then
            local want = math.atan2(dy, dx)
            local d = (want - (self.toolAng or want) + math.pi) % (2 * math.pi) - math.pi
            self.toolAng = (self.toolAng or want) + d * 0.25
        end
    end
    self.cx, self.cy = x, y
end

-- the patient was hurt (a slip, a nick, a missed clamp): blood, a shake, the monitor reacts
function Base:hurtAt(x, y, amount, quiet)
    self.hurt = (self.hurt or 0) + (amount or 1)
    self.lastHurt = self.t or 0
    self:burst("blood", x, y, 6 + math.floor(6 * (amount or 1)))
    self.shakeAmt = math.max(self.shakeAmt or 0, 3 * (amount or 1))
    self.shakeUntil = (self.t or 0) + 260
    if not quiet then G.sfx("Splat", 120) end
end

function Base:burst(kind, x, y, n)
    self.parts = self.parts or {}
    for _ = 1, n do
        if #self.parts > 160 then return end
        local ang = rndf() * 6.283
        local spd = (0.04 + rndf() * 0.14)
        local p = { kind = kind, x = x, y = y, vx = math.cos(ang) * spd, vy = math.sin(ang) * spd, age = 0,
                    ttl = 350 + rnd(500), size = 3 + rnd(5), grav = 0.0004 }
        if kind == "water" then p.size = 4 + rnd(6); p.grav = 0.0006
        elseif kind == "dust" then p.size = 2 + rnd(3); p.grav = 0.0002; p.ttl = 500 + rnd(500)
        elseif kind == "spark" then p.size = 2; p.grav = 0.0008; p.ttl = 200 + rnd(200) end
        self.parts[#self.parts + 1] = p
    end
end

function Base:drawParticles(ui)
    for _, p in ipairs(self.parts or {}) do
        local a = 1 - p.age / p.ttl
        if p.kind == "blood" then img(ui, "drop", p.x - p.size, p.y - p.size, p.size * 2, p.size * 2, a, 0.62, 0.03, 0.03)
        elseif p.kind == "water" then img(ui, "splash", p.x - p.size, p.y - p.size, p.size * 2, p.size * 2, a * 0.6, 0.75, 0.88, 1)
        elseif p.kind == "dust" then ui:drawRect(p.x, p.y, p.size, p.size, a, 0.92, 0.88, 0.78)
        elseif p.kind == "spark" then ui:drawRect(p.x, p.y, p.size, p.size, a, 1, 0.85, 0.5) end
    end
end

-- screen shake offset for this frame
function Base:jolt()
    local s = self.shakeAmt or 0
    if s <= 0 then return 0, 0 end
    return (rndf() - 0.5) * 2 * s, (rndf() - 0.5) * 2 * s
end

-- sway from an unanaesthetised patient
function Base:sway(scale)
    local s = (self.p.shake or 0) * (scale or 8)
    local t = (self.t or 0) / 1000
    local jx, jy = self:jolt()
    return math.sin(t * 2.3) * s + math.sin(t * 5.1) * s * 0.35 + jx, math.cos(t * 1.7) * s * 0.6 + jy
end

-- the operative field: drape all round, a window of prepped skin, lamp light
function Base:field(ui, x, y, w, h, inner)
    local d = tex("drape")
    if d then
        for ty = y, y + h - 1, 128 do
            for tx = x, x + w - 1, 128 do
                ui:drawTextureScaled(d, tx, ty, math.min(128, x + w - tx), math.min(128, y + h - ty), 1, 1, 1, 1)
            end
        end
    else
        ui:drawRect(x, y, w, h, 1, 0.16, 0.36, 0.40)
    end
    local m = 14
    local fx, fy, fw, fh = x + m, y + m, w - 2 * m, h - 2 * m
    ui:drawRect(fx - 3, fy - 3, fw + 6, fh + 6, 0.55, 0.05, 0.12, 0.14)  -- drape fold shadow
    img(ui, inner or "field_skin", fx, fy, fw, fh, 1)
    self.fieldBox = { fx, fy, fw, fh }
    return fx, fy, fw, fh
end

-- an opened wound (oval, ragged retracted edges) inside the field
function Base:bed(ui, x, y, w, h, organ)
    img(ui, organ and "organ_bed" or "wound_bed", x, y, w, h, 1)
end

function Base:lamp(ui)
    local b = self.fieldBox
    if b then img(ui, "vignette", b[1], b[2], b[3], b[4], 0.7) end
end

-- the instrument in the hand: tip on the mouse, turned with the movement
G.TOOL = {
    scalpel = { w = 150, h = 38 }, hemostat = { w = 150, h = 56 }, needle = { w = 150, h = 56 },
    forceps = { w = 150, h = 38 }, syringe = { w = 150, h = 38 }, suction = { w = 150, h = 38 },
    saw = { w = 160, h = 62 }, drill = { w = 160, h = 62 }, pipette = { w = 140, h = 35 },
    catheter = { w = 140, h = 35 }, curette = { w = 140, h = 35 },
}
function Base:drawTool(ui, name, angFixed)
    if not self.cx or not name then return end
    local d = G.TOOL[name] or { w = 110, h = 30 }
    -- held from the lower right like a pen (handle -> tip points up-left,
    -- about -135 degrees); leans a little with the stroke
    local lean = 0
    if self.toolAng then lean = clamp(math.sin(self.toolAng) * 0.25, -0.25, 0.25) end
    local ang = angFixed or (-2.356 + lean)
    sprite(ui, "tool_" .. name, self.cx, self.cy, d.w, d.h, ang, 1, 0.5, 1)
end

local function make(kind, p)
    local o = setmetatable({ kind = kind, p = p or {}, t = 0, done = false, parts = {}, hurt = 0 }, G.kinds[kind])
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

-- ============================================================= vitals monitor (drawn by the operating window)
-- Heart rate rises with pain (no anaesthesia -> p.shake) and every recent
-- injury; an alarm sounds while it is high.
function G.drawVitals(ui, game, x, y, w, h)
    local t = (game and game.t or 0) / 1000
    local recent = game and game.lastHurt and math.max(0, 1 - ((game.t or 0) - game.lastHurt) / 4000) or 0
    local hurt = game and game.hurt or 0
    local hr = math.floor(76 + 18 * ((game and game.p.shake) or 0) + 40 * recent + math.min(25, hurt * 2))
    local spo2 = math.max(86, 99 - math.floor(hurt / 3))
    ui:drawRect(x, y, w, h, 0.92, 0.01, 0.03, 0.04)
    ui:drawRectBorder(x, y, w, h, 1, 0.20, 0.45, 0.70)
    local alarm = hr >= 120
    local c = alarm and { 1, 0.3, 0.3 } or { 0.3, 1, 0.45 }
    if alarm and math.floor(t * 2) % 2 == 0 then ui:drawRect(x + 1, y + 1, w - 2, h - 2, 0.18, 1, 0.1, 0.1) end
    if alarm and game then G.sfx("Alarm", 1500) end
    ui:drawText("HR " .. hr, x + 6, y + 3, c[1], c[2], c[3], 1, UIFont.Small)
    ui:drawText("SpO2 " .. spo2 .. "%", x + w - 70, y + 3, 0.4, 0.8, 1, 1, UIFont.Small)
    -- ECG trace
    local beat = 60 / hr
    local top, bh = y + 22, h - 26
    local px, py
    for i = 0, w - 12, 2 do
        local tt = t - (w - 12 - i) / 90
        local ph = (tt % beat) / beat
        local v = 0
        if ph < 0.06 then v = math.sin(ph / 0.06 * math.pi) * 0.12
        elseif ph < 0.10 then v = -0.15
        elseif ph < 0.13 then v = 1
        elseif ph < 0.17 then v = -0.35
        elseif ph > 0.32 and ph < 0.45 then v = math.sin((ph - 0.32) / 0.13 * math.pi) * 0.22 end
        local sx, sy = x + 6 + i, top + bh * 0.6 - v * bh * 0.5
        if px then line(ui, px, py, sx, sy, 1.5, 1, c[1], c[2], c[3]) end
        px, py = sx, sy
    end
end

-- ============================================================= trace (P01, P10 catheter)
local Trace = kind("trace")
function Trace:init()
    local cath = self.p.variant == "catheter"
    self.limit = (cath and 20000 or 16000) + 6000 * (self.p.skill or 0)
    self.tol = (cath and 6 or 9) + (cath and 8 or 12) * (self.p.skill or 0) + 5 * (self.p.tool or 1)
    self.pts = {}
    local a1, a2 = rndf() * 0.25 + 0.1, rndf() * 0.25 + 0.1
    local waves = cath and 3.6 or 1.2
    for i = 0, 40 do
        local u = i / 40
        self.pts[#self.pts + 1] = { u = u, v = 0.5 + math.sin(u * math.pi * waves) * (a1 * 0.6 + (cath and 0.12 or 0)) - math.sin(u * math.pi * 2.3) * a2 * 0.4 }
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
    local fx, fy, fw, fh = self:field(ui, x, y, w, h)
    local cath = self.p.variant == "catheter"
    local N = 60
    if cath then          -- the vein to follow, blue under the skin
        local lx, ly
        for i = 0, N do
            local px, py = self:pathAt(i / N, w, h, x, y)
            if lx then strip(ui, "vein", lx, ly, px, py, self.tol * 2.2, 0.9) end
            lx, ly = px, py
        end
    end
    -- the surgeon's marking (dashed purple) and the cut so far (opened skin)
    local lx, ly
    for i = 0, N do
        local u = i / N
        local px, py = self:pathAt(u, w, h, x, y)
        if lx then
            if u <= self.progress then
                if cath then line(ui, lx, ly, px, py, 3, 0.95, 0.92, 0.92, 0.95)
                else strip(ui, "wound", lx, ly, px, py, 14 + 5 * math.min(1, (self.t or 0) / 4000), 1) end
            elseif i % 2 == 0 then
                line(ui, lx, ly, px, py, 2, 0.85, 0.45, 0.20, 0.65)
            end
        end
        lx, ly = px, py
    end
    for _, m in ipairs(self.marks) do img(ui, "drop", m.x - 4, m.y - 4, 8, 8, 0.9, 0.6, 0.04, 0.04) end
    local sx, sy = self:pathAt(self.progress, w, h, x, y)
    if not self.drawing then ring(ui, sx, sy, 10 + math.sin((self.t or 0) / 150) * 2, 2, 0.9, 0.3, 1, 0.4) end
    local ex, ey = self:pathAt(1, w, h, x, y)
    ring(ui, ex, ey, 7, 2, 0.9, 1, 1, 1)
    self:lamp(ui)
    self:drawParticles(ui)
    self:drawTool(ui, cath and "catheter" or "scalpel")
end
function Trace:mouseDown(mx, my)
    self:track(mx, my)
    if not self.box then return end
    local x, y, w, h = unpack(self.box)
    local sx, sy = self:pathAt(self.progress, w, h, x, y)
    if (mx - sx) ^ 2 + (my - sy) ^ 2 <= (self.tol + 8) ^ 2 then self.drawing = true end
end
function Trace:mouseUp() self.drawing = false end
function Trace:mouseMove(mx, my)
    self:track(mx, my)
    if not self.drawing or not self.box or self.done then return end
    local x, y, w, h = unpack(self.box)
    local u = clamp((mx - x - 30) / (w - 60), 0, 1)
    if u < self.progress - 0.02 then return end
    local px, py = self:pathAt(u, w, h, x, y)
    local d = math.abs(my - py)
    self.samples = self.samples + 1
    if d <= self.tol then
        self.inside = self.inside + 1
        G.sfx(self.p.variant == "catheter" and "Stitch" or "Cut", 260)
    elseif #self.marks < 40 then
        self.marks[#self.marks + 1] = { x = mx, y = my }
        if d > self.tol * 1.6 then self:hurtAt(mx, my, 0.5) end
    end
    if u > self.progress and u - self.progress < 0.08 then self.progress = u end
    if self.progress >= 0.985 then self.done = true end
    self.result = (self.samples > 0 and self.inside / self.samples or 0) * self.progress
end
function Trace:timeout() self.done = true; self.result = (self.samples > 0 and self.inside / self.samples or 0) * self.progress end

-- ============================================================= pulse (P02 hemostasis)
local Pulse = kind("pulse")
function Pulse:init()
    self.count = 5
    self.period = 1500 - 500 * (self.p.skill or 0)
    self.window = 5 + 7 * (self.p.skill or 0) + 3 * (self.p.tool or 1)
    self.hits = {}; self.i = 0
    self.clamps, self.pools = {}, {}
    self:next()
end
function Pulse:next()
    self.i = self.i + 1
    if self.i > self.count then self.done = true; return end
    self.cur = { u = 0.2 + rndf() * 0.6, v = 0.3 + rndf() * 0.4, age = 0 }
end
function Pulse:ringR() return 10 + 60 * (1 - self.cur.age / self.period) end
function Pulse:update(ms)
    self:tick(ms)
    for _, pool in ipairs(self.pools) do pool.r = math.min(pool.max, pool.r + ms * 0.01) end
    if self.done or not self.cur then return end
    self.cur.age = self.cur.age + ms
    if self.cur.age >= self.period then
        self.hits[#self.hits + 1] = 0
        self.pools[#self.pools + 1] = { u = self.cur.u, v = self.cur.v, r = 6, max = 26 + rnd(10) }
        self.hurt = self.hurt + 1; self.lastHurt = self.t
        G.sfx("Splat")
        self:next()
    end
end
function Pulse:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:field(ui, x, y, w, h)
    -- the opened wound: tissue bed inside retracted skin edges
    self:bed(ui, x + w * 0.08, y + h * 0.10, w * 0.84, h * 0.80)
    for _, pool in ipairs(self.pools) do
        img(ui, "blood", x + pool.u * w - pool.r, y + pool.v * h - pool.r, pool.r * 2, pool.r * 2, 0.92, 0.45, 0.02, 0.03)
    end
    for _, c in ipairs(self.clamps) do
        sprite(ui, "tool_hemostat", x + c.u * w, y + c.v * h, 90, 34, c.ang, 1, 0.5, 1)
    end
    if self.cur and not self.done then
        local sx, sy = self:sway(5)
        local cx, cy = x + self.cur.u * w + sx, y + self.cur.v * h + sy
        -- the bleeder: spurts with every heartbeat, biggest when the ring closes
        local beat = 1 - math.abs(self:ringR() - 10) / 60
        local r = 8 + 10 * beat
        img(ui, "blood", cx - r, cy - r, r * 2, r * 2, 1, 0.70, 0.03, 0.04)
        local rr = self:ringR()
        local near = math.abs(rr - 10) <= self.window
        ring(ui, cx, cy, rr, 2, 0.85, near and 0.3 or 1, near and 1 or 1, near and 0.4 or 1)
        if rndf() < 0.15 then self:burst("blood", cx, cy, 1) end
    end
    self:lamp(ui)
    self:drawParticles(ui)
    self:drawTool(ui, "hemostat")
end
function Pulse:mouseMove(mx, my) self:track(mx, my) end
function Pulse:mouseDown(mx, my)
    self:track(mx, my)
    if self.done or not self.cur or not self.box then return end
    local x, y, w, h = unpack(self.box)
    local sx, sy = self:sway(5)
    local cx, cy = x + self.cur.u * w + sx, y + self.cur.v * h + sy
    if (mx - cx) ^ 2 + (my - cy) ^ 2 > 40 ^ 2 then return end
    local off = math.abs(self:ringR() - 10)
    local good = off <= self.window
    self.hits[#self.hits + 1] = good and (1 - 0.5 * off / self.window) or 0
    G.sfx("Clamp")
    self.clamps[#self.clamps + 1] = { u = self.cur.u, v = self.cur.v, ang = 2.2 + rndf() * 0.8 }
    if not good then
        self.pools[#self.pools + 1] = { u = self.cur.u, v = self.cur.v, r = 5, max = 18 }
        self:hurtAt(cx, cy, 0.6)
    end
    self:next()
end
function Pulse:score()
    local s = 0
    for _, v in ipairs(self.hits) do s = s + v end
    return clamp(s / self.count, 0, 1)
end

-- ============================================================= clean (P03 irrigation)
local Clean = kind("clean")
function Clean:init()
    self.limit = 10000 + 5000 * (self.p.skill or 0)
    self.total = 14
    self.bits = {}
    for i = 1, self.total do
        self.bits[i] = { u = 0.2 + rndf() * 0.6, v = 0.25 + rndf() * 0.5, alive = true, ph = rndf() * 6, k = 1 + rnd(4), s = 22 + rnd(14) }
    end
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
    self:field(ui, x, y, w, h)
    local wx, wy, ww, wh = x + w * 0.08, y + h * 0.10, w * 0.84, h * 0.80
    self:bed(ui, wx, wy, ww, wh)
    -- a dirty wound: dried blood and grime fade as it is cleaned
    local dirt = self.left / self.total
    img(ui, "blood", wx + ww * 0.15, wy + wh * 0.15, ww * 0.7, wh * 0.7, 0.55 * dirt, 0.25, 0.10, 0.05)
    for _, b in ipairs(self.bits) do
        if b.alive then
            local cx, cy = self:pos(b, x, y, w, h)
            img(ui, "debris" .. b.k, cx - b.s / 2, cy - b.s / 2, b.s, b.s, 1)
        end
    end
    self:lamp(ui)
    self:drawParticles(ui)
    self:drawTool(ui, "syringe")
end
function Clean:mouseMove(mx, my) self:track(mx, my) end
function Clean:mouseDown(mx, my)
    self:track(mx, my)
    if self.done or not self.box then return end
    local x, y, w, h = unpack(self.box)
    G.sfx("Squirt", 150)
    self:burst("water", mx, my, 6)
    for _, b in ipairs(self.bits) do
        if b.alive then
            local cx, cy = self:pos(b, x, y, w, h)
            if (mx - cx) ^ 2 + (my - cy) ^ 2 <= (self.radius + b.s / 2) ^ 2 then
                b.alive = false; self.left = self.left - 1
                if self.left <= 0 then self.done = true end
                return
            end
        end
    end
end
function Clean:score() return clamp((self.total - self.left) / self.total, 0, 1) end

-- ============================================================= necro (P04 debridement, P15 organ)
local Necro = kind("necro")
function Necro:init()
    self.organ = self.p.variant == "organ"
    self.limit = 14000 + 6000 * (self.p.skill or 0)
    self.cols, self.rows = self.organ and 8 or 7, self.organ and 5 or 4
    self.cells = {}
    self.dead = 0
    for i = 1, self.cols * self.rows do
        local isDead = rnd(100) < (self.organ and 22 or 32)
        self.cells[i] = { dead = isDead, cut = false, jx = rndf() * 6 - 3, jy = rndf() * 6 - 3 }
        if isDead then self.dead = self.dead + 1 end
    end
    if self.dead == 0 then self.cells[1].dead = true; self.dead = 1 end
    self.cutDead, self.cutGood = 0, 0
end
function Necro:update(ms) self:tick(ms) end
function Necro:grid()
    local b = self.wbox
    if not b then return nil end
    return b[1], b[2], b[3] / self.cols, b[4] / self.rows
end
function Necro:cellAt(mx, my)
    local gx, gy, cw, ch = self:grid()
    if not gx then return nil end
    local c = math.floor((mx - gx) / cw)
    local r = math.floor((my - gy) / ch)
    if c < 0 or r < 0 or c >= self.cols or r >= self.rows then return nil end
    return r * self.cols + c + 1
end
function Necro:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:field(ui, x, y, w, h)
    self:bed(ui, x + w * 0.04, y + h * 0.04, w * 0.92, h * 0.92, self.organ)
    -- the cells (the rule's grid) sit inside the opening; each is drawn as an
    -- irregular patch, not a square
    local wx, wy, ww, wh = x + w * 0.17, y + h * 0.17, w * 0.66, h * 0.66
    self.wbox = { wx, wy, ww, wh }
    local gx, gy, cw, ch = self:grid()
    for i, c in ipairs(self.cells) do
        local col, row = (i - 1) % self.cols, math.floor((i - 1) / self.cols)
        local cx, cy = gx + col * cw + cw / 2 + c.jx, gy + row * ch + ch / 2 + c.jy
        local pw, ph = cw * 1.35, ch * 1.35
        if c.cut then
            -- freshly debrided: raw bleeding bed (a healthy cut bleeds much more)
            img(ui, "raw_patch", cx - pw / 2, cy - ph / 2, pw, ph, 0.85)
            img(ui, "blood", cx - pw * 0.35, cy - ph * 0.35, pw * 0.7, ph * 0.7, c.dead and 0.3 or 0.9, 0.55, 0.02, 0.03)
        elseif c.dead then
            img(ui, "necro_patch", cx - pw / 2, cy - ph / 2, pw, ph, 1)
        end
    end
    self:lamp(ui)
    self:drawParticles(ui)
    self:drawTool(ui, self.organ and "scalpel" or "curette")
end
function Necro:mouseMove(mx, my) self:track(mx, my) end
function Necro:mouseDown(mx, my)
    self:track(mx, my)
    if self.done then return end
    local i = self:cellAt(mx, my)
    local c = i and self.cells[i]
    if not c or c.cut then return end
    c.cut = true
    G.sfx("Cut", 80)
    if c.dead then
        self.cutDead = self.cutDead + 1
        self:burst("dust", mx, my, 5)
        if self.cutDead >= self.dead then self.done = true end
    else
        self.cutGood = self.cutGood + 1
        self:hurtAt(mx, my, 1)
    end
end
function Necro:score() return clamp(self.cutDead / self.dead - 0.15 * self.cutGood, 0, 1) end

-- ============================================================= gauge (P05 aspiration, P07 saw, P09 valve, P13 drill)
local Gauge = kind("gauge")
local GAUGE = {
    default = { band = 0.12, drift = 0.18, speed = 0.9, up = 0.55, down = 0.45, fillSec = 7, danger = 0.12, tool = "suction", sound = "Suction" },
    saw     = { band = 0.16, drift = 0.06, speed = 0.5, up = 0.9,  down = 0.9,  fillSec = 8, danger = 0.10, tool = "saw", sound = "Saw" },
    valve   = { band = 0.14, drift = 0.26, speed = 1.3, up = 0.45, down = 0.35, fillSec = 7, danger = 0.14, tool = "suction", sound = "Suction" },
    drill   = { band = 0.08, drift = 0.10, speed = 0.7, up = 0.40, down = 0.50, fillSec = 9, danger = 0.06, tool = "drill", sound = "Drill" },
}
Gauge.vitalsLeft = true   -- the dial is on the right
function Gauge:init()
    self.var = self.p.variant or "default"
    self.cfg = GAUGE[self.var] or GAUGE.default
    self.limit = 16000 + 6000 * (self.p.skill or 0)
    self.band = self.cfg.band + 0.10 * (self.p.skill or 0) + 0.04 * (self.p.tool or 1)
    self.level, self.fill, self.damage, self.holding = 0.2, 0, 0, false
end
function Gauge:center()
    local t = (self.t or 0) / 1000
    local c = self.cfg
    return 0.5 + math.sin(t * c.speed) * c.drift + math.sin(t * 2.2) * 0.06 * (1 + (self.p.shake or 0))
end
function Gauge:update(ms)
    self:tick(ms)
    if self.done then return end
    local dt = ms / 1000
    local cfg = self.cfg
    self.level = clamp(self.level + (self.holding and cfg.up or -cfg.down) * dt, 0, 1)
    local c = self:center()
    if self.holding then G.sfx(cfg.sound, 280) end
    if math.abs(self.level - c) <= self.band / 2 then
        self.fill = self.fill + dt / cfg.fillSec
        if self.holding and self.work and rndf() < 0.3 then
            self:burst(self.var == "default" and "water" or (self.var == "valve" and "water" or "dust"), self.work[1], self.work[2], 1)
        end
    elseif self.level > c + self.band / 2 + cfg.danger then
        self.damage = self.damage + dt / 10
        if self.work and (not self.lastHurt or self.t - self.lastHurt > 700) then self:hurtAt(self.work[1], self.work[2], 0.4) end
    end
    if self.fill >= 1 then self.fill = 1; self.done = true end
end
-- the analog dial: green band = the target, red past it, needle = your pressure / force
function Gauge:dial(ui, cx, cy, r)
    disc(ui, cx, cy, r + 8, 1, 0.08, 0.09, 0.11)
    disc(ui, cx, cy, r + 4, 1, 0.88, 0.89, 0.86)
    local a0, a1 = math.pi * 0.85, math.pi * 2.15
    local function ang(v) return a0 + (a1 - a0) * clamp(v, 0, 1) end
    local c = self:center()
    arc(ui, cx, cy, r - 6, 8, ang(c + self.band / 2 + self.cfg.danger), a1, 0.9, 0.85, 0.15, 0.12)
    arc(ui, cx, cy, r - 6, 8, ang(c - self.band / 2), ang(c + self.band / 2), 1, 0.15, 0.70, 0.25)
    for i = 0, 10 do
        local a = ang(i / 10)
        line(ui, cx + math.cos(a) * (r - 1), cy + math.sin(a) * (r - 1), cx + math.cos(a) * (r - (i % 5 == 0 and 14 or 8)), cy + math.sin(a) * (r - (i % 5 == 0 and 14 or 8)), 2, 1, 0.15, 0.15, 0.18)
    end
    local na = ang(self.level)
    line(ui, cx, cy, cx + math.cos(na) * (r - 10), cy + math.sin(na) * (r - 10), 3, 1, 0.75, 0.05, 0.05)
    disc(ui, cx, cy, 6, 1, 0.15, 0.15, 0.18)
end
function Gauge:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    local sceneW = w * 0.62
    self:field(ui, x, y, sceneW, h, self.var == "drill" and "skull" or nil)
    local sx, sy, sw, sh = x + 14, y + 14, sceneW - 28, h - 28
    local cx, cy = sx + sw / 2, sy + sh / 2
    local jx, jy = self:jolt()
    cx, cy = cx + jx, cy + jy
    if self.var == "saw" then
        -- a long bone across the field, the cut deepening
        self:bed(ui, sx + 6, cy - 80, sw - 12, 160)
        img(ui, "bone", cx - 46, cy - 46, 92, 92, 1)
        local depth = self.fill * 92
        ui:drawRect(cx - 2, cy - 46, 4, depth, 1, 0.25, 0.05, 0.04)
        self.work = { cx, cy - 46 + depth }
    elseif self.var == "drill" then
        -- burr hole widening in the skull
        local r = 6 + 22 * self.fill
        disc(ui, cx, cy, r + 3, 1, 0.55, 0.45, 0.35)
        disc(ui, cx, cy, r, 1, 0.25 + 0.3 * (1 - self.fill), 0.06, 0.06)
        self.work = { cx, cy }
    else
        -- an abscess cavity: pus (yellow-green) going down as it drains
        self:bed(ui, sx + 6, sy + 16, sw - 12, sh - 32)
        local pr = 70 * (1 - self.fill) + 8
        img(ui, "blood", cx - pr, cy - pr, pr * 2, pr * 2, 0.95, 0.82, 0.78, 0.35)
        self.work = { cx, cy }
    end
    self:lamp(ui)
    self:drawParticles(ui)
    -- the instrument at work (fixed in the field, it is the hand on the button that counts)
    local saved = { self.cx, self.cy }
    self.cx, self.cy = self.work[1], self.work[2]
    self:drawTool(ui, self.cfg.tool, self.var == "saw" and math.pi * 0.5 or nil)
    self.cx, self.cy = saved[1], saved[2]
    -- device panel on the right: dial + progress (jar / depth)
    local px, pw = x + sceneW + 8, w - sceneW - 8
    ui:drawRect(px, y, pw, h, 1, 0.10, 0.12, 0.15)
    ui:drawRectBorder(px, y, pw, h, 1, 0.25, 0.30, 0.38)
    local r = math.min(pw * 0.38, h * 0.26)
    self:dial(ui, px + pw / 2, y + 16 + r + 8, r)
    local jx0, jy0, jw, jh = px + pw / 2 - 24, y + 16 + r * 2 + 40, 48, h - (16 + r * 2 + 56)
    if jh > 30 then
        ui:drawRect(jx0, jy0, jw, jh, 0.6, 0.75, 0.85, 0.95)
        local col = (self.var == "saw" or self.var == "drill") and { 0.85, 0.80, 0.70 } or { 0.80, 0.75, 0.30 }
        ui:drawRect(jx0 + 3, jy0 + jh - 3 - (jh - 6) * self.fill, jw - 6, (jh - 6) * self.fill, 0.95, col[1], col[2], col[3])
        ui:drawRectBorder(jx0, jy0, jw, jh, 1, 0.6, 0.7, 0.8)
    end
end
function Gauge:mouseMove(mx, my) self:track(mx, my) end
function Gauge:mouseDown() self.holding = true end
function Gauge:mouseUp() self.holding = false end
function Gauge:score() return clamp(self.fill * (1 - self.damage), 0, 1) end

-- ============================================================= suture (P08 closure)
local Suture = kind("suture")
function Suture:init()
    self.limit = 16000 + 6000 * (self.p.skill or 0)
    self.count = 8
    self.tol = 8 + 10 * (self.p.skill or 0) + 4 * (self.p.tool or 1)
    self.i, self.acc, self.placed = 1, {}, {}
end
function Suture:point(i, x, y, w, h)
    local u = 0.14 + (i - 1) / (self.count - 1) * 0.72
    local side = (i % 2 == 1) and -1 or 1
    local sx, sy = self:sway(5)
    return x + u * w + sx, y + h / 2 + side * h * 0.13 + sy
end
function Suture:update(ms) self:tick(ms) end
function Suture:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:field(ui, x, y, w, h)
    -- the incision closes as the stitches go in
    local open = 1 - (self.i - 1) / self.count
    local sx, sy = self:sway(5)
    strip(ui, "wound", x + w * 0.1 + sx, y + h / 2 + sy, x + w * 0.9 + sx, y + h / 2 + sy, 8 + 26 * open, 1)
    for i = 1, self.count do
        local px, py = self:point(i, x, y, w, h)
        if i < self.i then
            local p = self.placed[i]
            local qx, qy = p and p.x or px, p and p.y or py
            if i > 1 then
                local p0 = self.placed[i - 1]
                local ox, oy
                if p0 then ox, oy = p0.x, p0.y else ox, oy = self:point(i - 1, x, y, w, h) end
                strip(ui, "thread", ox, oy, qx, qy, 5, 1)
            end
            disc(ui, qx, qy, 3, 1, 0.12, 0.2, 0.45)
        elseif i == self.i then
            ring(ui, px, py, self.tol, 2, 0.85, 0.3, 1, 0.4)
            disc(ui, px, py, 3, 1, 0.45, 0.20, 0.65)
        else
            disc(ui, px, py, 2.5, 0.8, 0.45, 0.20, 0.65)
        end
    end
    self:lamp(ui)
    self:drawParticles(ui)
    self:drawTool(ui, "needle")
end
function Suture:mouseMove(mx, my) self:track(mx, my) end
function Suture:mouseDown(mx, my)
    self:track(mx, my)
    if self.done or not self.box then return end
    local x, y, w, h = unpack(self.box)
    local px, py = self:point(self.i, x, y, w, h)
    local d = math.sqrt((mx - px) ^ 2 + (my - py) ^ 2)
    if d > self.tol * 2.2 then return end
    local acc = clamp(1 - d / (self.tol * 2), 0, 1)
    self.acc[#self.acc + 1] = acc
    self.placed[self.i] = { x = mx, y = my }
    G.sfx("Stitch")
    if acc < 0.35 then self:hurtAt(mx, my, 0.4) end
    self.i = self.i + 1
    if self.i > self.count then self.done = true end
end
function Suture:score()
    local s = 0
    for _, v in ipairs(self.acc) do s = s + v end
    return clamp(s / self.count, 0, 1)
end

-- ============================================================= extract (P06 foreign body / parasite, P14 clot)
local Extract = kind("extract")
function Extract:init()
    self.clot = self.p.variant == "clot"
    self.object = self.clot and "clot" or (self.p.sid == "parasite_extraction" and "worm" or (rnd(2) == 0 and "bullet" or "glass"))
    self.limit = 18000 + 6000 * (self.p.skill or 0)
    self.count = self.clot and 3 or 1
    self.width = (self.clot and 0.10 or 0.14) + 0.06 * (self.p.skill or 0) + 0.03 * (self.p.tool or 1)
    self.i, self.touches, self.got = 1, 0, 0
    self:place()
end
function Extract:place()
    self.obj = { u = 0.25 + rndf() * 0.5, v = 0.78 }
    self.held = false
    self.lastTouch = -1000
end
function Extract:chan(v)
    local t = (self.t or 0) / 1000
    local s = (self.p.shake or 0) * 0.02
    return self.obj0 or 0.5, s * math.sin(t * 3 + v * 6)
end
function Extract:centerAt(v)
    local base = self.baseU or self.obj.u
    local _, sway = self:chan(v)
    return base + math.sin(v * 7 + (self.phase or 0)) * 0.08 + sway
end
function Extract:update(ms) self:tick(ms) end
function Extract:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:field(ui, x, y, w, h)
    self:bed(ui, x + 6, y + 6, w - 12, h - 12, self.clot)
    self.baseU = self.baseU or self.obj.u
    self.phase = self.phase or rndf() * 6
    -- the wound track: a dark, wet channel through the tissue (soft stamps)
    local tw = self.width * w
    for i = 0, 70 do
        local v = i / 70 * 0.82
        local cu = self:centerAt(v)
        local cx, cy = x + cu * w, y + v * h
        img(ui, "track", cx - tw * 0.5, cy - tw * 0.5, tw, tw, 0.8)
    end
    ui:drawRect(x + 14, y + 14, w - 28, 8, 0.8, 0.25, 0.75, 0.35)   -- the way out
    local ox, oy = x + (self.heldU or self.obj.u) * w, y + (self.heldV or self.obj.v) * h
    local size = self.object == "worm" and 80 or (self.clot and 30 or 28)
    if self.object == "worm" then
        sprite(ui, "worm", ox, oy, size, size * 0.4, (self.t or 0) / 400 % 0.6 - 0.3, 0.5, 0.5, 1)
    elseif self.object == "clot" then
        img(ui, "clot", ox - size / 2, oy - size / 2, size, size, 1, 0.35, 0.03, 0.06)
    else
        img(ui, self.object, ox - size / 2, oy - size / 2, size, size, 1)
    end
    if (self.t or 0) - (self.lastTouch or -1000) < 300 then ui:drawRectBorder(x, y, w, h, 1, 1, 0.2, 0.2) end
    self:lamp(ui)
    self:drawParticles(ui)
    self:drawTool(ui, "forceps")
end
function Extract:mouseDown(mx, my)
    self:track(mx, my)
    if self.done or not self.box then return end
    local x, y, w, h = unpack(self.box)
    local ox, oy = x + self.obj.u * w, y + self.obj.v * h
    if (mx - ox) ^ 2 + (my - oy) ^ 2 <= 18 ^ 2 then self.held = true; G.sfx("Clamp") end
end
function Extract:mouseUp() self.held = false end
function Extract:mouseMove(mx, my)
    self:track(mx, my)
    if not self.held or not self.box or self.done then return end
    local x, y, w, h = unpack(self.box)
    local u, v = (mx - x) / w, (my - y) / h
    self.heldU, self.heldV = u, v
    local cu = self:centerAt(clamp(v, 0, 0.82))
    if math.abs(u - cu) > self.width / 2 then
        if (self.t or 0) - (self.lastTouch or -1000) > 350 then
            self.touches = self.touches + 1; self.lastTouch = self.t
            self:hurtAt(mx, my, 0.5)
        end
    end
    if v <= 0.06 then
        self.got = self.got + 1
        G.sfx("Good")
        self.held = false; self.heldU, self.heldV = nil, nil; self.baseU = nil
        if self.got >= self.count then self.done = true else self:place() end
    end
end
function Extract:score()
    return clamp(self.got / self.count - 0.12 * self.touches, 0, 1)
end

-- ============================================================= dialysis (P11)
local Dialysis = kind("dialysis")
Dialysis.vitalsAt = "center"   -- the pump dials fill both sides
function Dialysis:init()
    self.limit = 18000 + 6000 * (self.p.skill or 0)
    self.band = 0.14 + 0.08 * (self.p.skill or 0)
    self.a, self.b, self.fill, self.side = 0.2, 0.2, 0, nil
end
function Dialysis:targets()
    local t = (self.t or 0) / 1000
    return 0.5 + math.sin(t * 0.7) * 0.2, 0.5 + math.cos(t * 0.5) * 0.2
end
function Dialysis:update(ms)
    self:tick(ms)
    if self.done then return end
    local dt = ms / 1000
    self.a = clamp(self.a + ((self.side == "a") and 0.5 or -0.35) * dt, 0, 1)
    self.b = clamp(self.b + ((self.side == "b") and 0.5 or -0.35) * dt, 0, 1)
    if self.side then G.sfx("Pump", 300) end
    local ta, tb = self:targets()
    local inA = math.abs(self.a - ta) <= self.band / 2
    local inB = math.abs(self.b - tb) <= self.band / 2
    if inA and inB then self.fill = self.fill + dt / 8 elseif inA or inB then self.fill = self.fill + dt / 24 end
    if self.fill >= 1 then self.fill = 1; self.done = true end
end
-- one pump: a dial (pressure) like the gauge's
local function pumpDial(ui, cx, cy, r, val, tgt, band)
    disc(ui, cx, cy, r + 7, 1, 0.08, 0.09, 0.11)
    disc(ui, cx, cy, r + 3, 1, 0.88, 0.89, 0.86)
    local a0, a1 = math.pi * 0.85, math.pi * 2.15
    local function ang(v) return a0 + (a1 - a0) * clamp(v, 0, 1) end
    arc(ui, cx, cy, r - 6, 8, ang(tgt - band / 2), ang(tgt + band / 2), 1, 0.15, 0.70, 0.25)
    local na = ang(val)
    line(ui, cx, cy, cx + math.cos(na) * (r - 9), cy + math.sin(na) * (r - 9), 3, 1, 0.75, 0.05, 0.05)
    disc(ui, cx, cy, 5, 1, 0.15, 0.15, 0.18)
end
function Dialysis:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    ui:drawRect(x, y, w, h, 1, 0.82, 0.84, 0.86)                 -- the machine's face
    ui:drawRect(x + 6, y + 6, w - 12, h - 12, 1, 0.70, 0.73, 0.76)
    ui:drawRectBorder(x, y, w, h, 1, 0.35, 0.38, 0.42)
    local ta, tb = self:targets()
    local r = math.min(w * 0.16, h * 0.28)
    local ay, ax, bx = y + h * 0.38, x + w * 0.22, x + w * 0.78
    pumpDial(ui, ax, ay, r, self.a, ta, self.band)
    pumpDial(ui, bx, ay, r, self.b, tb, self.band)
    ui:drawTextCentre("ART", ax, ay + r + 12, 0.15, 0.15, 0.2, 1, UIFont.Small)
    ui:drawTextCentre("VEN", bx, ay + r + 12, 0.15, 0.15, 0.2, 1, UIFont.Small)
    -- the filter cartridge in the middle, blood going in dark and out clean
    local fx, fy, fw, fh = x + w / 2 - 18, y + 76, 36, h - 96
    ui:drawRect(fx, fy, fw, fh, 1, 0.92, 0.94, 0.96)
    ui:drawRect(fx + 4, fy + fh - 4 - (fh - 8) * self.fill, fw - 8, (fh - 8) * self.fill, 1, 0.75, 0.08, 0.08)
    ui:drawRectBorder(fx, fy, fw, fh, 1, 0.4, 0.45, 0.5)
    -- tubing with moving blood
    local t = (self.t or 0) / 1000
    local function tube(x1, y1, x2, y2, flow)
        line(ui, x1, y1, x2, y2, 9, 1, 0.92, 0.93, 0.95)
        line(ui, x1, y1, x2, y2, 5, 1, 0.55, 0.04, 0.05)
        local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        for k = 0, 6 do
            local u = ((k / 7) + t * 0.6 * (flow + 0.1)) % 1
            disc(ui, x1 + (x2 - x1) * u, y1 + (y2 - y1) * u, 2.5, 0.9, 0.95, 0.4, 0.4)
        end
        return len
    end
    tube(ax + r + 8, ay, fx, fy + 20, self.a)
    tube(fx + fw, fy + fh - 20, bx - r - 8, ay, self.b)
end
function Dialysis:mouseMove(mx, my) self:track(mx, my) end
function Dialysis:mouseDown(mx) if self.box then self.side = (mx < self.box[1] + self.box[3] / 2) and "a" or "b" end end
function Dialysis:mouseUp() self.side = nil end
function Dialysis:score() return clamp(self.fill, 0, 1) end

-- ============================================================= cells (P12 cell graft)
local Cells = kind("cells")
function Cells:init()
    self.limit = 16000 + 6000 * (self.p.skill or 0)
    self.n = 9
    self.order = {}
    for i = 1, self.n do self.order[i] = i end
    for i = self.n, 2, -1 do local j = rnd(i) + 1; self.order[i], self.order[j] = self.order[j], self.order[i] end
    self.next, self.wrong = 1, 0
    self.spots = {}
    for k = 1, self.n do
        local a = (k / self.n) * 6.283 + rndf() * 0.4
        local d = 0.2 + rndf() * 0.22
        self.spots[k] = { u = 0.5 + math.cos(a) * d, v = 0.5 + math.sin(a) * d, ph = rndf() * 6 }
    end
end
function Cells:update(ms) self:tick(ms) end
function Cells:cellPos(k, x, y, w, h)
    local s = self.spots[k]
    local t = (self.t or 0) / 1000
    local sx, sy = self:sway(3)
    local size = math.min(w, h) * 0.86
    local dx, dy = x + (w - size) / 2, y + (h - size) / 2
    return dx + s.u * size + math.sin(t * 0.9 + s.ph) * 4 + sx, dy + s.v * size + math.cos(t * 0.7 + s.ph) * 4 + sy, size * 0.09
end
function Cells:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    ui:drawRect(x, y, w, h, 1, 0.10, 0.11, 0.13)
    local size = math.min(w, h) * 0.92
    img(ui, "dish", x + (w - size) / 2, y + (h - size) / 2, size, size, 1)
    for k = 1, self.n do
        local cx, cy, r = self:cellPos(k, x, y, w, h)
        local num = self.order[k]
        local done = num < self.next
        img(ui, "cell", cx - r, cy - r, r * 2, r * 2, 1, done and 0.5 or 0.55, done and 0.9 or 0.45, done and 0.55 or 0.85)
        ui:drawTextCentre(tostring(num), cx, cy - 8, 1, 1, 1, done and 0.35 or 1, UIFont.Medium)
    end
    -- microscope eyepiece edge
    img(ui, "vignette", x, y, w, h, 0.9)
    self:drawParticles(ui)
    self:drawTool(ui, "pipette")
end
function Cells:mouseMove(mx, my) self:track(mx, my) end
function Cells:mouseDown(mx, my)
    self:track(mx, my)
    if self.done or not self.box then return end
    local x, y, w, h = unpack(self.box)
    for k = 1, self.n do
        local cx, cy, r = self:cellPos(k, x, y, w, h)
        if (mx - cx) ^ 2 + (my - cy) ^ 2 <= (r + 4) ^ 2 then
            if self.order[k] == self.next then
                self.next = self.next + 1
                G.sfx("Pop")
                self:burst("water", cx, cy, 3)
                if self.next > self.n then self.done = true end
            elseif self.order[k] > self.next then
                self.wrong = self.wrong + 1
                G.sfx("Bad")
                self.shakeAmt, self.shakeUntil = 2, (self.t or 0) + 200
            end
            return
        end
    end
end
function Cells:score() return clamp((self.next - 1) / self.n - 0.1 * self.wrong, 0, 1) end

return G

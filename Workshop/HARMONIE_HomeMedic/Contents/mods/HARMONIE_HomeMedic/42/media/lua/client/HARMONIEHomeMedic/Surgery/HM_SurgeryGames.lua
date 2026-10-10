--[[
    HARMONIE - How to Survive : surgery minigames (client)

    One small game per procedure, reused by every operation. Round
    2026-10-10 (owner's design doc "ออกแบบมินิเกมผ่าตัด P01-P15 ให้สมจริงตาม
    หลักการแพทย์"): each game copies what is really done at that step, a
    mistake has the consequence it has in medicine, and besides its score
    (quality of the work, not speed) every game reports its SIDE EFFECTS
    separately (:effects(), keys in HM_Surgery.EFFECT_KEYS) -- the server
    turns those into tissue damage, bleeding, infection risk, things left
    behind, a misplaced line, brain injury or organ function lost.

      trace    P01 Incision      : follow the marked line at an even depth
                                   (stroke speed = depth; too slow cuts deep)
      pulse    P02 Hemostasis    : several bleeders of different severity at
                                   once -- clamp vessels on the pulse, press
                                   small oozers; crushing tissue hurts
      clean    P03 Irrigation    : hold to flush, keep the pressure in the
                                   band; high pressure on clean tissue harms
      necro    P04 Necrectomy    : probe the doubtful tissue (right click),
                                   mark what is dead, excise the marked area
      gauge    P05 Aspiration    : put the needle in the pocket, then keep
                                   suction in a band that narrows as it drains
      extract  P06 Extraction    : grip, turn (wheel) and draw out along the
                                   track; a worm tears if pulled fast
      saw      P07 Bone cut      : force in the band, steer along the line
      suture   P08 Closure       : interrupted stitches -- bite in, bite out,
                                   tie at the right tension; edge gap shown
      valve    P09 Chest drain   : keep the drain in its range, fix a kinked
                                   tube and a leaking connector
      catheter P10 Catheter      : follow the vein, avoid artery and nerve,
                                   confirm position (flashback) at checkpoints
      dialysis P11 Dialysis      : blood pump and ultrafiltration together,
                                   watch venous pressure, flush a clotting
                                   filter, clamp air in the line
      cells    P12 Cell graft    : sort the cells, discard abnormal ones
                                   (right click), then cover the bed evenly
      drill    P13 Craniotomy    : on the mark, through the bone layers, stop
                                   at the breakthrough (holding on = plunge)
      clot     P14 Hematoma      : suction the clot only; let the field clear
      organ    P15 Organ repair  : suture the tears, resect dead tissue

    Difficulty: p.k (HM_Surgery.difficulty: the surgeon's First Aid against
    the recommended level) scales every tolerance and timer; p.tool is the
    quality of THIS step's instrument; p.prev the effects of earlier steps.

    Every game: G.new(kind, p) with p = { skill 0..1, shake, tool 0..1, k,
    under, variant, sid, prev }, then :update(ms), :render(ui, x, y, w, h),
    :mouseDown/Up/Move(x, y), :rightDown(x, y), :wheel(d) in host-panel
    coordinates, .done, :score() -> 0..1, :effects() -> { key = 0..1 }.
    The art and sounds are our own (tools/gen_surgery_art.py,
    tools/gen_surgery_sounds.py).
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

-- tolerance / band scale from the surgeon's skill against the recommended
-- level and from this step's instrument
function Base:K() return clamp(tonumber(self.p.k) or 1, 0.3, 1.6) end
function Base:toolK(weight) return 1 - (weight or 0.3) * (1 - clamp(tonumber(self.p.tool) or 1, 0, 1)) end
function Base:timeK() return clamp(0.7 + 0.3 * self:K(), 0.6, 1.2) end
function Base:prev(key) return clamp(tonumber(self.p.prev and self.p.prev[key]) or 0, 0, 1) end
function Base:effects() return {} end
function Base:rightDown(x, y) end
function Base:wheel(d) end

-- a button drawn on the board (labels via HM_Surgery texts when loaded)
local function T(key, fallback)
    local S = HM_Surgery
    if S and S.T then return S.T(key, fallback) end
    return fallback
end
G.T = T
function Base:button(ui, id, x, y, w, h, label, active, col)
    self.buttons = self.buttons or {}
    self.buttons[id] = { x, y, w, h }
    local c = col or { 0.25, 0.65, 0.95 }
    ui:drawRect(x, y, w, h, active and 0.85 or 0.55, c[1] * (active and 0.8 or 0.35), c[2] * (active and 0.8 or 0.35), c[3] * (active and 0.8 or 0.35))
    ui:drawRectBorder(x, y, w, h, 1, c[1], c[2], c[3])
    ui:drawTextCentre(label, x + w / 2, y + (h - 16) / 2, 1, 1, 1, 1, UIFont.Small)
end
function Base:hitButton(mx, my)
    for id, b in pairs(self.buttons or {}) do
        if mx >= b[1] and mx <= b[1] + b[3] and my >= b[2] and my <= b[2] + b[4] then return id end
    end
    return nil
end
-- a short label that floats up from a point (feedback: "Too deep", "Good")
function Base:say(text, x, y, col)
    self.says = self.says or {}
    self.says[#self.says + 1] = { text = text, x = x, y = y, t = self.t or 0, col = col or { 1, 1, 1 } }
    if #self.says > 6 then table.remove(self.says, 1) end
end
function Base:drawSays(ui)
    for _, s in ipairs(self.says or {}) do
        local age = (self.t or 0) - s.t
        if age < 1400 then
            local a = 1 - age / 1400
            ui:drawTextCentre(s.text, s.x, s.y - age / 30, s.col[1], s.col[2], s.col[3], a, UIFont.Small)
        end
    end
end
-- a vertical meter with a target band (depth, pressure, tension)
function Base:meter(ui, x, y, w, h, v, lo, hi, label)
    ui:drawRect(x, y, w, h, 0.85, 0.04, 0.05, 0.06)
    ui:drawRect(x, y + h * (1 - hi), w, h * (hi - lo), 0.8, 0.15, 0.65, 0.25)
    local f = clamp(v, 0, 1)
    ui:drawRect(x + 3, y + h * (1 - f) - 2, w - 6, 4, 1, 1, 0.9, 0.3)
    ui:drawRectBorder(x, y, w, h, 1, 0.8, 0.8, 0.85)
    if label then ui:drawTextCentre(label, x + w / 2, y + h + 2, 0.85, 0.85, 0.9, 1, UIFont.Small) end
end

-- game + variant -> its own kind (P10 is not an incision, P15 not a debridement)
G.VARIANT_KIND = {
    trace_catheter = "catheter", necro_organ = "organ", extract_clot = "clot",
    gauge_saw = "saw", gauge_valve = "valve", gauge_drill = "drill",
}
local function make(kind, p)
    local o = setmetatable({ kind = kind, p = p or {}, t = 0, done = false, parts = {}, hurt = 0 }, G.kinds[kind])
    o:init()
    return o
end
function G.new(kind, p)
    p = p or {}
    local k = (p.variant and G.VARIANT_KIND[kind .. "_" .. p.variant]) or kind
    if not G.kinds[k] then k = kind end
    return G.kinds[k] and make(k, p) or nil
end
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
    -- a soft beep on every heartbeat, like a bedside monitor
    if game then
        local n = math.floor(t * hr / 60)
        if game.beatN and n ~= game.beatN and not alarm then G.sfx("Beep", 250) end
        game.beatN = n
    end
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

-- ============================================================= trace (P01 incision)
-- Follow the surgeon's marking from the green ring to the white one. The
-- stroke speed is the depth: too slow and the blade sinks (cuts too deep,
-- tissue damage), too fast and it skates (too shallow). Score = staying on
-- the line and at an even depth; leaving the line nicks the skin.
local Trace = kind("trace")
Trace.IDEAL_SPEED = 0.22     -- px per ms that keeps the blade at the right depth
function Trace:init()
    local K = self:K() * self:toolK(0.35)
    self.limit = (16000 + 6000 * (self.p.skill or 0)) * self:timeK()
    self.tol = (8 + 12 * (self.p.skill or 0)) * K
    self.band = { 0.5 - 0.17 * K, 0.5 + 0.17 * K }   -- right depth
    self.pts = {}
    local a1, a2 = rndf() * 0.25 + 0.1, rndf() * 0.25 + 0.1
    for i = 0, 40 do
        local u = i / 40
        self.pts[#self.pts + 1] = { u = u, v = 0.5 + math.sin(u * math.pi * 1.2) * (a1 * 0.6) - math.sin(u * math.pi * 2.3) * a2 * 0.4 }
    end
    self.progress, self.inside, self.samples, self.drawing, self.marks = 0, 0, 0, false, {}
    self.depth, self.depthGood, self.deep, self.off = 0.5, 0, 0, 0
end
function Trace:pathAt(u, w, h, x, y)
    local n = #self.pts - 1
    local i = clamp(math.floor(u * n), 0, n - 1)
    local a, b = self.pts[i + 1], self.pts[i + 2]
    local f = u * n - i
    local sx, sy = self:sway(6)
    return x + 30 + (a.u + (b.u - a.u) * f) * (w - 60) + sx, y + (a.v + (b.v - a.v) * f) * h + sy
end
function Trace:update(ms)
    self:tick(ms)
    -- a blade held still sinks in
    if self.drawing and self.lastMove and (self.t - self.lastMove) > 120 then
        self.depth = math.min(1, self.depth + ms / 900)
    end
end
function Trace:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:field(ui, x, y, w, h)
    local N = 60
    local lx, ly
    for i = 0, N do
        local u = i / N
        local px, py = self:pathAt(u, w, h, x, y)
        if lx then
            if u <= self.progress then
                strip(ui, "wound", lx, ly, px, py, 10 + 10 * (self.cutDepth and self.cutDepth[i] or 0.5), 1)
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
    -- depth meter (left) and the live deviation bar (bottom)
    self:meter(ui, x + 22, y + 30, 14, h - 80, self.depth, self.band[1], self.band[2], T("UI_HomeMedic_Surg_G_Depth", "Depth"))
    local dev = clamp((self.lastDev or 0) / (self.tol * 2), 0, 1)
    ui:drawRect(x + 60, y + h - 26, w - 120, 8, 0.8, 0.05, 0.05, 0.06)
    ui:drawRect(x + 60, y + h - 26, (w - 120) * 0.5, 8, 0.5, 0.15, 0.6, 0.25)
    ui:drawRect(x + 60 + (w - 120) * dev - 2, y + h - 29, 4, 14, 1, dev > 0.5 and 1 or 0.4, dev > 0.5 and 0.3 or 1, 0.3)
    self:drawSays(ui)
    self:drawTool(ui, "scalpel")
end
function Trace:mouseDown(mx, my)
    self:track(mx, my)
    if not self.box then return end
    local x, y, w, h = unpack(self.box)
    local sx, sy = self:pathAt(self.progress, w, h, x, y)
    if (mx - sx) ^ 2 + (my - sy) ^ 2 <= (self.tol + 10) ^ 2 then
        self.drawing = true
        self.lastMove, self.lastX, self.lastY = self.t, mx, my
    end
end
function Trace:mouseUp() self.drawing = false end
function Trace:mouseMove(mx, my)
    self:track(mx, my)
    if not self.drawing or not self.box or self.done then return end
    local x, y, w, h = unpack(self.box)
    -- stroke speed -> depth
    local dt = math.max(1, (self.t or 0) - (self.lastMove or 0))
    local dist = math.sqrt((mx - (self.lastX or mx)) ^ 2 + (my - (self.lastY or my)) ^ 2)
    self.lastMove, self.lastX, self.lastY = self.t, mx, my
    local speed = dist / dt
    local want = clamp(0.5 + (Trace.IDEAL_SPEED - speed) / Trace.IDEAL_SPEED * 0.45, 0, 1)
    self.depth = self.depth + (want - self.depth) * 0.35 + (rndf() - 0.5) * 0.04 * (self.p.shake or 0)
    self.depth = clamp(self.depth, 0, 1)
    local u = clamp((mx - x - 30) / (w - 60), 0, 1)
    if u < self.progress - 0.02 then return end
    local _, py = self:pathAt(u, w, h, x, y)
    local d = math.abs(my - py)
    self.lastDev = d
    self.samples = self.samples + 1
    if self.depth >= self.band[1] and self.depth <= self.band[2] then self.depthGood = self.depthGood + 1 end
    if self.depth > 0.85 then
        self.deep = self.deep + 1
        if self.deep % 12 == 1 then self:hurtAt(mx, my, 0.4); self:say(T("UI_HomeMedic_Surg_G_TooDeep", "Too deep!"), mx, my - 20, { 1, 0.4, 0.3 }) end
    end
    if d <= self.tol then
        self.inside = self.inside + 1
        G.sfx("Cut", 260)
    else
        self.off = self.off + 1
        if #self.marks < 40 then self.marks[#self.marks + 1] = { x = mx, y = my } end
        if d > self.tol * 1.6 and self.off % 6 == 1 then self:hurtAt(mx, my, 0.5) end
    end
    if u > self.progress and u - self.progress < 0.08 then
        self.cutDepth = self.cutDepth or {}
        for i = math.floor(self.progress * 60), math.floor(u * 60) do self.cutDepth[i] = self.depth end
        self.progress = u
    end
    if self.progress >= 0.985 then self.done = true end
end
function Trace:score()
    local n = math.max(1, self.samples)
    local acc = self.inside / n
    local even = self.depthGood / n
    return clamp(self.progress * (0.55 * acc + 0.45 * even), 0, 1)
end
function Trace:effects()
    local n = math.max(1, self.samples)
    return { tissue = clamp(0.9 * self.deep / n + 0.6 * self.off / n, 0, 1) }
end

-- ============================================================= pulse (P02 hemostasis)
-- Several bleeders at once, of different severity: an ARTERY spurts with
-- the pulse (clamp it when its ring closes), a VEIN wells up steadily (a
-- wider window), a small OOZER only needs pressure (hold on it). Every
-- second a bleeder stays open costs blood in proportion to its severity;
-- a clamp that misses or a press on bare tissue crushes it.
local Pulse = kind("pulse")
Pulse.SEV_NAME = { "ooze", "vein", "artery" }
function Pulse:init()
    local K = self:K() * self:toolK(0.3)
    self.limit = (24000 + 6000 * (self.p.skill or 0)) * self:timeK()
    self.window = (6 + 8 * (self.p.skill or 0)) * K
    self.holdNeed = 900 / K
    self.list, self.pools, self.clamps = {}, {}, {}
    self.total = 5 + ((self.p.under or 0) >= 2 and 1 or 0)
    self.spawned, self.nextSpawn = 0, 0
    self.lost, self.crush, self.slips = 0, 0, 0
end
function Pulse:spawn()
    self.spawned = self.spawned + 1
    local sev = (self.spawned == 1) and 3 or (1 + rnd(3))
    local b = { u = 0.2 + rndf() * 0.6, v = 0.25 + rndf() * 0.5, sev = sev, ph = rndf(), open = true, hold = 0,
                period = (sev == 3 and 1100 or 1700) * (0.9 + rndf() * 0.2) }
    self.list[#self.list + 1] = b
end
function Pulse:phase(b) return ((self.t or 0) / b.period + b.ph) % 1 end
function Pulse:ringR(b) return 10 + 50 * (1 - self:phase(b)) end
function Pulse:update(ms)
    self:tick(ms)
    if self.done then return end
    if self.spawned < self.total and (self.t >= self.nextSpawn) then
        self:spawn()
        self.nextSpawn = self.t + (self.spawned < 3 and 400 or 3000)
    end
    local openAny = false
    for _, b in ipairs(self.list) do
        if b.open then
            openAny = true
            self.lost = self.lost + b.sev * ms / 1000
            if b.sev == 1 and self.pressing == b then
                b.hold = b.hold + ms
                if b.hold >= self.holdNeed then b.open = false; G.sfx("Good"); self:say(T("UI_HomeMedic_Surg_G_Stopped", "Stopped"), self.bx or 0, self.by or 0, { 0.4, 1, 0.5 }) end
            end
            if rndf() < 0.02 * b.sev and #self.pools < 40 then
                self.pools[#self.pools + 1] = { u = b.u + (rndf() - 0.5) * 0.05, v = b.v + 0.03, r = 4, max = 10 + 6 * b.sev }
            end
        end
    end
    for _, pool in ipairs(self.pools) do pool.r = math.min(pool.max, pool.r + ms * 0.01) end
    if not openAny and self.spawned >= self.total then self.done = true end
end
function Pulse:pos(b, x, y, w, h)
    local sx, sy = self:sway(5)
    return x + b.u * w + sx, y + b.v * h + sy
end
function Pulse:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:field(ui, x, y, w, h)
    self:bed(ui, x + w * 0.08, y + h * 0.10, w * 0.84, h * 0.80)
    for _, pool in ipairs(self.pools) do
        img(ui, "blood", x + pool.u * w - pool.r, y + pool.v * h - pool.r, pool.r * 2, pool.r * 2, 0.92, 0.45, 0.02, 0.03)
    end
    for _, c in ipairs(self.clamps) do sprite(ui, "tool_hemostat", x + c.u * w, y + c.v * h, 90, 34, c.ang, 1, 0.5, 1) end
    for _, b in ipairs(self.list) do
        if b.open then
            local cx, cy = self:pos(b, x, y, w, h)
            local pulse = b.sev == 1 and 0.4 or (1 - math.abs(self:ringR(b) - 10) / 50)
            local r = 5 + 4 * b.sev + 6 * pulse
            local dark = b.sev == 2 and 0.55 or 1
            img(ui, "blood", cx - r, cy - r, r * 2, r * 2, 1, 0.70 * dark, 0.03, 0.04 + (b.sev == 2 and 0.06 or 0))
            if b.sev >= 2 then
                local win = self.window * (b.sev == 2 and 1.6 or 1)
                local near = math.abs(self:ringR(b) - 10) <= win
                ring(ui, cx, cy, self:ringR(b), 2, 0.85, near and 0.3 or 1, 1, near and 0.4 or 1)
                if b.sev == 3 and rndf() < 0.2 then self:burst("blood", cx, cy, 1) end
            else
                -- an oozer: press and hold -- the arc fills
                arc(ui, cx, cy, r + 6, 3, -1.57, -1.57 + 6.283 * clamp(b.hold / self.holdNeed, 0, 1), 0.95, 0.4, 0.8, 1)
                ring(ui, cx, cy, r + 6, 1, 0.5, 0.4, 0.8, 1)
            end
        end
    end
    self:lamp(ui)
    self:drawParticles(ui)
    -- blood lost so far
    local lostF = clamp(self.lost / (self.total * 2 * 6), 0, 1)
    ui:drawText(T("UI_HomeMedic_Surg_G_Lost", "Blood loss"), x + 20, y + h - 40, 1, 0.85, 0.85, 1, UIFont.Small)
    ui:drawRect(x + 20, y + h - 22, 160, 8, 0.8, 0.05, 0.05, 0.06)
    ui:drawRect(x + 20, y + h - 22, 160 * lostF, 8, 1, 0.85, 0.12, 0.1)
    self:drawSays(ui)
    self:drawTool(ui, "hemostat")
end
function Pulse:at(mx, my)
    if not self.box then return nil end
    local x, y, w, h = unpack(self.box)
    local best, bd
    for _, b in ipairs(self.list) do
        if b.open then
            local cx, cy = self:pos(b, x, y, w, h)
            local d = (mx - cx) ^ 2 + (my - cy) ^ 2
            if d <= 34 ^ 2 and (not bd or d < bd) then best, bd = b, d end
        end
    end
    return best
end
function Pulse:mouseMove(mx, my)
    self:track(mx, my)
    if self.pressing and self:at(mx, my) ~= self.pressing then self.pressing = nil end
end
function Pulse:mouseDown(mx, my)
    self:track(mx, my)
    if self.done then return end
    local b = self:at(mx, my)
    self.bx, self.by = mx, my - 24
    if not b then
        -- a clamp on bare tissue: crushed
        self.crush = self.crush + 1
        self:hurtAt(mx, my, 0.5)
        self:say(T("UI_HomeMedic_Surg_G_Crushed", "Crushed tissue"), mx, my - 20, { 1, 0.4, 0.3 })
        return
    end
    if b.sev == 1 then self.pressing = b; return end
    local win = self.window * (b.sev == 2 and 1.6 or 1)
    local off = math.abs(self:ringR(b) - 10)
    G.sfx("Clamp")
    if off <= win then
        b.open = false
        local x, y, w, h = unpack(self.box)
        self.clamps[#self.clamps + 1] = { u = b.u, v = b.v, ang = 2.2 + rndf() * 0.8 }
        self:say(T("UI_HomeMedic_Surg_G_Clamped", "Clamped"), mx, my - 20, { 0.4, 1, 0.5 })
    else
        self.slips = self.slips + 1
        self:hurtAt(mx, my, 0.6)
        self:say(T("UI_HomeMedic_Surg_G_Slipped", "Slipped"), mx, my - 20, { 1, 0.6, 0.3 })
    end
end
function Pulse:mouseUp() self.pressing = nil end
function Pulse:weights()
    local tot, done = 0, 0
    for _, b in ipairs(self.list) do
        tot = tot + b.sev
        if not b.open then done = done + b.sev end
    end
    -- bleeders that never appeared (time ran out) count as open arteries
    tot = tot + 2 * (self.total - self.spawned)
    return tot, done
end
function Pulse:score()
    local tot, done = self:weights()
    local lostF = clamp(self.lost / (self.total * 2 * 6), 0, 1)
    return clamp((tot > 0 and done / tot or 0) * (1 - 0.45 * lostF) - 0.05 * self.crush, 0, 1)
end
function Pulse:effects()
    local tot, done = self:weights()
    local lostF = clamp(self.lost / (self.total * 2 * 6), 0, 1)
    return { bleed = clamp(0.6 * (1 - (tot > 0 and done / tot or 0)) + 0.4 * lostF, 0, 1),
             tissue = clamp(0.1 * self.crush + 0.08 * self.slips, 0, 1) }
end

-- ============================================================= clean (P03 irrigation)
-- Hold the mouse to flush at the pointer; the stream PRESSURE climbs while
-- held and falls when released. In the green band debris washes out; too
-- low barely moves it; too high drives it into the tissue and, aimed at
-- clean tissue, damages it. What stays is contamination (infection risk).
local Clean = kind("clean")
function Clean:init()
    local K = self:K() * self:toolK(0.3)
    self.limit = (16000 + 6000 * (self.p.skill or 0)) * self:timeK()
    self.total = 14
    self.bits = {}
    for i = 1, self.total do
        self.bits[i] = { u = 0.2 + rndf() * 0.6, v = 0.25 + rndf() * 0.5, hp = 1, ph = rndf() * 6, k = 1 + rnd(4), s = 22 + rnd(14) }
    end
    self.radius = 30 * K
    self.band = { 0.40 - 0.12 * K, 0.62 + 0.10 * K }
    self.pressure, self.harm, self.holding = 0, 0, false
end
function Clean:left()
    local l = 0
    for _, b in ipairs(self.bits) do l = l + math.max(0, b.hp) end
    return l
end
function Clean:pos(b, x, y, w, h)
    local sx, sy = self:sway(4)
    local t = (self.t or 0) / 1000
    return x + b.u * w + math.sin(t * 1.3 + b.ph) * 3 + sx, y + b.v * h + math.cos(t * 1.1 + b.ph) * 3 + sy
end
function Clean:update(ms)
    self:tick(ms)
    if self.done then return end
    local dt = ms / 1000
    self.pressure = clamp(self.pressure + (self.holding and 0.55 or -0.8) * dt, 0, 1)
    if not (self.holding and self.box and self.cx) then return end
    G.sfx("Squirt", 180)
    if rndf() < 0.5 then self:burst("water", self.cx, self.cy, 1) end
    local x, y, w, h = unpack(self.box)
    local inBand = self.pressure >= self.band[1] and self.pressure <= self.band[2]
    local high = self.pressure > self.band[2]
    local eff = inBand and 1 or (high and 0.6 or 0.25)
    local hit = false
    for _, b in ipairs(self.bits) do
        if b.hp > 0 then
            local bx, by = self:pos(b, x, y, w, h)
            local dx, dy = bx - self.cx, by - self.cy
            local d = math.sqrt(dx * dx + dy * dy)
            if d <= self.radius + b.s / 2 then
                hit = true
                b.hp = b.hp - dt * 1.4 * eff
                -- flushed outwards, away from the stream
                if d > 0.1 then b.u = b.u + dx / d * dt * 0.05 * eff; b.v = b.v + dy / d * dt * 0.05 * eff end
            end
        end
    end
    if high then
        -- overpressure: tissue hurt, more when aimed at clean tissue
        self.harm = self.harm + dt * (hit and 0.04 or 0.12)
        if not self.lastHurtAt or self.t - self.lastHurtAt > 900 then
            self.lastHurtAt = self.t
            self:hurtAt(self.cx, self.cy, 0.25, true)
            self:say(T("UI_HomeMedic_Surg_G_TooHard", "Too hard!"), self.cx, self.cy - 20, { 1, 0.4, 0.3 })
        end
    end
    if self:left() <= 0.01 then self.done = true end
end
function Clean:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:field(ui, x, y, w, h)
    local wx, wy, ww, wh = x + w * 0.08, y + h * 0.10, w * 0.84, h * 0.80
    self:bed(ui, wx, wy, ww, wh)
    local dirt = self:left() / self.total
    img(ui, "blood", wx + ww * 0.15, wy + wh * 0.15, ww * 0.7, wh * 0.7, 0.55 * dirt, 0.25, 0.10, 0.05)
    for _, b in ipairs(self.bits) do
        if b.hp > 0 then
            local cx, cy = self:pos(b, x, y, w, h)
            local sz = b.s * (0.5 + 0.5 * b.hp)
            img(ui, "debris" .. b.k, cx - sz / 2, cy - sz / 2, sz, sz, 0.4 + 0.6 * b.hp)
        end
    end
    if self.holding and self.cx then ring(ui, self.cx, self.cy, self.radius, 1, 0.4, 0.7, 0.85, 1) end
    self:lamp(ui)
    self:drawParticles(ui)
    self:meter(ui, x + w - 34, y + 30, 14, h - 80, self.pressure, self.band[1], self.band[2], T("UI_HomeMedic_Surg_G_Pressure", "Pressure"))
    self:drawSays(ui)
    self:drawTool(ui, "syringe")
end
function Clean:mouseMove(mx, my) self:track(mx, my) end
function Clean:mouseDown(mx, my) self:track(mx, my); if not self.done then self.holding = true end end
function Clean:mouseUp() self.holding = false end
function Clean:score() return clamp((self.total - self:left()) / self.total - 1.2 * self.harm, 0, 1) end
function Clean:effects() return { dirt = clamp(self:left() / self.total, 0, 1), tissue = clamp(self.harm * 2, 0, 1) } end

-- ============================================================= necro (P04 necrectomy)
-- Real debridement is decided tissue by tissue: black = dead, pink = alive,
-- and DUSKY patches nobody can judge by colour alone. Right click a patch
-- to PROBE it (it bleeds and blanches if alive -- takes a moment), left
-- click to MARK it for excision, then press Excise. Dead tissue left behind
-- keeps the infection going; healthy tissue cut makes the wound bigger.
local Necro = kind("necro")
function Necro:init()
    local K = self:K() * self:toolK(0.3)
    self.limit = (24000 + 8000 * (self.p.skill or 0)) * self:timeK()
    self.cols, self.rows = 7, 4
    self.cells = {}
    self.dead = 0
    local dusky = clamp(0.20 / K, 0.08, 0.40)
    for i = 1, self.cols * self.rows do
        local roll = rndf()
        local isDead = roll < 0.30
        local c = { dead = isDead, mark = false, jx = rndf() * 6 - 3, jy = rndf() * 6 - 3 }
        c.dusky = rndf() < dusky
        if c.dusky and not isDead and rndf() < 0.5 then c.dead = true end
        if c.dead then self.dead = self.dead + 1 end
        self.cells[i] = c
    end
    if self.dead == 0 then self.cells[1].dead = true; self.dead = 1 end
    self.probeMs = 650 / K
    self.cutDead, self.cutGood = 0, 0
end
function Necro:update(ms)
    self:tick(ms)
    local pr = self.probing
    if pr and not self.done then
        pr.left = pr.left - ms
        if pr.left <= 0 then
            pr.cell.known = true
            pr.cell.dusky = false
            self.probing = nil
            G.sfx(pr.cell.dead and "Bad" or "Good")
        end
    end
end
function Necro:timeout() self:excise() end
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
    self:bed(ui, x + w * 0.04, y + h * 0.04, w * 0.92, h * 0.92)
    local wx, wy, ww, wh = x + w * 0.17, y + h * 0.14, w * 0.66, h * 0.62
    self.wbox = { wx, wy, ww, wh }
    local gx, gy, cw, ch = self:grid()
    for i, c in ipairs(self.cells) do
        local col, row = (i - 1) % self.cols, math.floor((i - 1) / self.cols)
        local cx, cy = gx + col * cw + cw / 2 + c.jx, gy + row * ch + ch / 2 + c.jy
        local pw, ph = cw * 1.3, ch * 1.3
        if c.cut then
            img(ui, "raw_patch", cx - pw / 2, cy - ph / 2, pw, ph, 0.85)
            img(ui, "blood", cx - pw * 0.35, cy - ph * 0.35, pw * 0.7, ph * 0.7, c.dead and 0.3 or 0.9, 0.55, 0.02, 0.03)
        elseif c.dusky then
            img(ui, "necro_patch", cx - pw / 2, cy - ph / 2, pw, ph, 0.55, 0.75, 0.55, 0.85)
            ui:drawTextCentre("?", cx, cy - 8, 1, 1, 1, 0.9, UIFont.Medium)
        elseif c.dead then
            img(ui, "necro_patch", cx - pw / 2, cy - ph / 2, pw, ph, 1)
        elseif c.known then
            -- probed and alive: it bled
            disc(ui, cx, cy, 3, 0.9, 0.7, 0.05, 0.05)
        end
        if c.mark and not c.cut then
            ui:drawRectBorder(cx - cw / 2 + 3, cy - ch / 2 + 3, cw - 6, ch - 6, 1, 1, 0.85, 0.2)
        end
        if self.probing and self.probing.cell == c then
            arc(ui, cx, cy, math.min(cw, ch) * 0.35, 3, -1.57, -1.57 + 6.283 * (1 - self.probing.left / self.probeMs), 1, 0.4, 0.8, 1)
        end
    end
    self:lamp(ui)
    self:drawParticles(ui)
    if not self.done then
        self:button(ui, "excise", x + w - 170, y + h - 40, 150, 26, T("UI_HomeMedic_Surg_G_Excise", "Excise marked"), true, { 0.95, 0.55, 0.2 })
    end
    self:drawSays(ui)
    self:drawTool(ui, "curette")
end
function Necro:mouseMove(mx, my) self:track(mx, my) end
function Necro:mouseDown(mx, my)
    self:track(mx, my)
    if self.done then return end
    if self:hitButton(mx, my) == "excise" then self:excise(); return end
    local i = self:cellAt(mx, my)
    local c = i and self.cells[i]
    if not c or c.cut then return end
    c.mark = not c.mark
    G.sfx("Clamp", 60)
end
function Necro:rightDown(mx, my)
    self:track(mx, my)
    if self.done or self.probing then return end
    local i = self:cellAt(mx, my)
    local c = i and self.cells[i]
    if not c or c.cut or c.known then return end
    self.probing = { cell = c, left = self.probeMs }
    G.sfx("Stitch", 100)
end
function Necro:excise()
    if self.done then return end
    local gx, gy, cw, ch = self:grid()
    for i, c in ipairs(self.cells) do
        if c.mark and not c.cut then
            c.cut = true
            local col, row = (i - 1) % self.cols, math.floor((i - 1) / self.cols)
            local cx, cy = (gx or 0) + col * (cw or 0) + (cw or 0) / 2, (gy or 0) + row * (ch or 0) + (ch or 0) / 2
            if c.dead then self.cutDead = self.cutDead + 1; self:burst("dust", cx, cy, 4)
            else self.cutGood = self.cutGood + 1; self:hurtAt(cx, cy, 0.5, true) end
        end
    end
    G.sfx("Cut")
    self.done = true
end
function Necro:score() return clamp(self.cutDead / self.dead - 0.12 * self.cutGood, 0, 1) end
function Necro:effects()
    return { residual = clamp(1 - self.cutDead / self.dead, 0, 1), tissue = clamp(0.1 * self.cutGood, 0, 1) }
end

-- ============================================================= gauge (P05 aspiration) and the dial shared by saw / valve / drill
-- First put the needle into the pocket (click where it fluctuates: the
-- middle of the abscess); then hold to keep suction in the green band.
-- The band narrows as the cavity empties (finer control at the end); past
-- it into the red the tissue tears. Pus left = it can come back.
local Gauge = kind("gauge")
G.GAUGE = {
    default = { band = 0.12, drift = 0.18, speed = 0.9, up = 0.55, down = 0.45, fillSec = 7, danger = 0.12, tool = "suction", sound = "Suction" },
    saw     = { band = 0.16, drift = 0.06, speed = 0.5, up = 0.9,  down = 0.9,  fillSec = 8, danger = 0.10, tool = "saw", sound = "Saw" },
    valve   = { band = 0.14, drift = 0.20, speed = 1.0, up = 0.45, down = 0.35, fillSec = 9, danger = 0.14, tool = "suction", sound = "Suction" },
    drill   = { band = 0.10, drift = 0.08, speed = 0.7, up = 0.40, down = 0.50, fillSec = 9, danger = 0.08, tool = "drill", sound = "Drill" },
}
Gauge.vitalsLeft = true   -- the dial is on the right
function Gauge:setup(var)
    self.var = var
    self.cfg = G.GAUGE[var] or G.GAUGE.default
    self.limit = (18000 + 6000 * (self.p.skill or 0)) * self:timeK()
    self.band0 = (self.cfg.band + 0.10 * (self.p.skill or 0)) * self:K() * self:toolK(0.35)
    self.band = self.band0
    self.level, self.fill, self.damage, self.holding = 0.2, 0, 0, false
end
function Gauge:init()
    self:setup("default")
    self.placed = false
    self.placeAcc = 0
    self.misses = 0
    self.pocket = { u = 0.35 + rndf() * 0.3, v = 0.35 + rndf() * 0.3, r = 0.16 * self:K() }
end
function Gauge:center()
    local t = (self.t or 0) / 1000
    local c = self.cfg
    return 0.5 + math.sin(t * c.speed) * c.drift + math.sin(t * 2.2) * 0.06 * (1 + (self.p.shake or 0))
end
-- one frame of the pressure/force rule; returns inBand
function Gauge:pump(ms, canFill)
    local dt = ms / 1000
    local cfg = self.cfg
    self.level = clamp(self.level + (self.holding and cfg.up or -cfg.down) * dt, 0, 1)
    local c = self:center()
    if self.holding then G.sfx(cfg.sound, 280) end
    local inBand = math.abs(self.level - c) <= self.band / 2
    if inBand and canFill ~= false then
        self.fill = self.fill + dt / cfg.fillSec
        if self.holding and self.work and rndf() < 0.3 then
            self:burst((self.var == "default" or self.var == "valve") and "water" or "dust", self.work[1], self.work[2], 1)
        end
    elseif self.level > c + self.band / 2 + cfg.danger then
        self.damage = self.damage + dt / 10
        if self.work and (not self.lastHurt or self.t - self.lastHurt > 700) then self:hurtAt(self.work[1], self.work[2], 0.4) end
    end
    if self.fill >= 1 then self.fill = 1 end
    return inBand
end
function Gauge:update(ms)
    self:tick(ms)
    if self.done or not self.placed then return end
    -- the end of the drainage needs a finer hand
    self.band = self.band0 * (1 - 0.45 * self.fill)
    self:pump(ms)
    if self.fill >= 1 then self.done = true end
end
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
-- the device panel on the right: dial + progress (jar / depth); -> scene width
function Gauge:panel(ui, x, y, w, h, col)
    local sceneW = w * 0.62
    local px, pw = x + sceneW + 8, w - sceneW - 8
    ui:drawRect(px, y, pw, h, 1, 0.10, 0.12, 0.15)
    ui:drawRectBorder(px, y, pw, h, 1, 0.25, 0.30, 0.38)
    local r = math.min(pw * 0.38, h * 0.26)
    self:dial(ui, px + pw / 2, y + 16 + r + 8, r)
    local jx0, jy0, jw, jh = px + pw / 2 - 24, y + 16 + r * 2 + 40, 48, h - (16 + r * 2 + 56)
    if jh > 30 then
        ui:drawRect(jx0, jy0, jw, jh, 0.6, 0.75, 0.85, 0.95)
        local c = col or { 0.80, 0.75, 0.30 }
        ui:drawRect(jx0 + 3, jy0 + jh - 3 - (jh - 6) * self.fill, jw - 6, (jh - 6) * self.fill, 0.95, c[1], c[2], c[3])
        ui:drawRectBorder(jx0, jy0, jw, jh, 1, 0.6, 0.7, 0.8)
    end
    self.panelBox = { px, y, pw, h }
    return sceneW
end
function Gauge:drawWorkTool(ui, ang)
    if not self.work then return end
    local saved = { self.cx, self.cy }
    self.cx, self.cy = self.work[1], self.work[2]
    self:drawTool(ui, self.cfg.tool, ang)
    self.cx, self.cy = saved[1], saved[2]
end
function Gauge:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    local sceneW = w * 0.62
    self:field(ui, x, y, sceneW, h)
    local sx, sy, sw, sh = x + 14, y + 14, sceneW - 28, h - 28
    local jx, jy = self:jolt()
    self:bed(ui, sx + 6, sy + 16, sw - 12, sh - 32)
    -- the abscess: a swelling of pus that shrinks as it drains
    local pu, pv = self.pocket.u, self.pocket.v
    local pcx, pcy = sx + pu * sw + jx, sy + pv * sh + jy
    local pr = (60 * (1 - self.fill) + 10)
    img(ui, "blood", pcx - pr, pcy - pr, pr * 2, pr * 2, 0.95, 0.82, 0.78, 0.35)
    self.sceneBox = { sx, sy, sw, sh }
    if not self.placed then
        -- the fluctuating middle pulses faintly: that is where the needle goes
        local rr = self.pocket.r * sw * (0.8 + 0.2 * math.sin((self.t or 0) / 200))
        ring(ui, pcx, pcy, rr, 1, 0.35, 1, 1, 0.6)
        self.work = nil
    else
        self.work = { self.needleX or pcx, self.needleY or pcy }
    end
    self:lamp(ui)
    self:drawParticles(ui)
    if self.placed then self:drawWorkTool(ui) else self:drawTool(ui, "syringe") end
    self:panel(ui, x, y, w, h)
    self:drawSays(ui)
end
function Gauge:mouseMove(mx, my) self:track(mx, my) end
function Gauge:mouseDown(mx, my)
    self:track(mx, my)
    if self.done then return end
    if not self.placed then
        local b = self.sceneBox
        if not b then return end
        local pcx, pcy = b[1] + self.pocket.u * b[3], b[2] + self.pocket.v * b[4]
        local d = math.sqrt((mx - pcx) ^ 2 + (my - pcy) ^ 2) / (self.pocket.r * b[3])
        if d <= 1 then
            self.placed = true
            self.placeAcc = clamp(1 - d * 0.6, 0, 1)
            self.needleX, self.needleY = mx, my
            G.sfx("Stitch")
            self:say(T("UI_HomeMedic_Surg_G_InPocket", "In the pocket"), mx, my - 20, { 0.4, 1, 0.5 })
        else
            self.misses = self.misses + 1
            self:hurtAt(mx, my, 0.4)
            self:say(T("UI_HomeMedic_Surg_G_DryTap", "Dry tap"), mx, my - 20, { 1, 0.6, 0.3 })
        end
        return
    end
    self.holding = true
end
function Gauge:mouseUp() self.holding = false end
function Gauge:score()
    return clamp(self.fill * (1 - self.damage) * (0.75 + 0.25 * self.placeAcc), 0, 1)
end
function Gauge:effects()
    return { residual = clamp(1 - self.fill, 0, 1), tissue = clamp(self.damage + 0.12 * self.misses, 0, 1) }
end

-- ============================================================= extract (P06 foreign body / parasite)
-- Grip the object (press on it) and draw it up the wound track to the
-- green edge. A shard of glass has an edge: turn it with the mouse wheel
-- so it lies along the track, or it snags the walls. A bump is scored by
-- how hard it hits, not counted flat. A worm must come out slowly -- pulled
-- fast it tears and a piece stays in the muscle.
local Extract = kind("extract")
function Extract:init()
    self.object = (self.p.sid == "parasite_extraction") and "worm" or (rnd(2) == 0 and "bullet" or "glass")
    local K = self:K() * self:toolK(0.35)
    self.limit = (20000 + 6000 * (self.p.skill or 0)) * self:timeK()
    self.count = 1
    self.width = (0.12 + 0.06 * (self.p.skill or 0)) * K
    self.len = self.object == "glass" and 0.09 or (self.object == "worm" and 0.07 or 0.03)
    self.touches, self.impact, self.got, self.torn = 0, 0, 0, false
    self.ang = (rnd(2) == 0 and 1 or -1) * (0.8 + rndf() * 0.6)
    self:place()
end
function Extract:place()
    self.obj = { u = 0.25 + rndf() * 0.5, v = 0.78 }
    self.held = false
    self.lastTouch = -1000
    self.baseU = self.obj.u
    self.phase = rndf() * 6
end
function Extract:centerAt(v)
    local t = (self.t or 0) / 1000
    local sway = (self.p.shake or 0) * 0.02 * math.sin(t * 3 + v * 6)
    return self.baseU + math.sin(v * 7 + self.phase) * 0.08 + sway
end
-- the track's direction at depth v (radians from straight up)
function Extract:trackAng(v)
    local dv = 0.02
    local du = self:centerAt(v - dv) - self:centerAt(v + dv)
    return math.atan2(du, dv * 2)
end
function Extract:update(ms)
    self:tick(ms)
    -- how fast it is being drawn out (px per ms), measured per frame -- the
    -- mouse can report several moves inside one frame
    if self.held and self.curY then
        local v = math.max(0, ((self.prevY or self.curY) - self.curY) / math.max(1, ms))
        self.speed = (self.speed or 0) * 0.5 + 0.5 * v
        self.prevY = self.curY
    else
        self.speed, self.prevY = 0, nil
    end
end
function Extract:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:field(ui, x, y, w, h)
    self:bed(ui, x + 6, y + 6, w - 12, h - 12)
    local tw = self.width * w
    for i = 0, 70 do
        local v = i / 70 * 0.82
        local cx, cy = x + self:centerAt(v) * w, y + v * h
        img(ui, "track", cx - tw * 0.5, cy - tw * 0.5, tw, tw, 0.8)
    end
    ui:drawRect(x + 14, y + 14, w - 28, 8, 0.8, 0.25, 0.75, 0.35)   -- the way out
    if self.got < self.count then
        local ox, oy = x + (self.heldU or self.obj.u) * w, y + (self.heldV or self.obj.v) * h
        if self.object == "worm" then
            sprite(ui, "worm", ox, oy, 80, 32, (self.t or 0) / 400 % 0.6 - 0.3, 0.5, 0.5, 1)
        elseif self.object == "glass" then
            sprite(ui, "glass", ox, oy, 46, 22, self.ang - math.pi / 2, 0.5, 0.5, 1)
        else
            img(ui, "bullet", ox - 14, oy - 14, 28, 28, 1)
        end
    end
    if (self.t or 0) - (self.lastTouch or -1000) < 300 then ui:drawRectBorder(x, y, w, h, 1, 1, 0.2, 0.2) end
    if self.object == "worm" and self.held then
        -- pull speed: keep it in the green
        local f = clamp((self.speed or 0) / 0.30, 0, 1)
        ui:drawRect(x + 20, y + h - 24, 150, 8, 0.8, 0.05, 0.05, 0.06)
        ui:drawRect(x + 20, y + h - 24, 150 * 0.5, 8, 0.4, 0.15, 0.6, 0.25)
        ui:drawRect(x + 20 + 150 * f - 2, y + h - 27, 4, 14, 1, f > 0.5 and 1 or 0.4, f > 0.5 and 0.3 or 1, 0.3)
    end
    self:lamp(ui)
    self:drawParticles(ui)
    self:drawSays(ui)
    self:drawTool(ui, "forceps")
end
function Extract:mouseDown(mx, my)
    self:track(mx, my)
    if self.done or not self.box then return end
    local x, y, w, h = unpack(self.box)
    local ox, oy = x + (self.heldU or self.obj.u) * w, y + (self.heldV or self.obj.v) * h
    if (mx - ox) ^ 2 + (my - oy) ^ 2 <= 22 ^ 2 then
        self.held = true; self.curY, self.prevY = my, my; G.sfx("Clamp")
    end
end
function Extract:mouseUp() self.held = false end
function Extract:wheel(d)
    if self.object ~= "glass" or self.done then return end
    self.ang = self.ang + (d > 0 and 0.18 or -0.18)
end
function Extract:mouseMove(mx, my)
    self:track(mx, my)
    if not self.held or not self.box or self.done then return end
    local x, y, w, h = unpack(self.box)
    local u, v = (mx - x) / w, (my - y) / h
    self.curY = my
    self.heldU, self.heldV = u, v
    local vv = clamp(v, 0, 0.82)
    -- the object's half width across the track: a shard lying crosswise is wide
    local half = self.width / 2
    local across = self.len / 2
    if self.object == "glass" then across = self.len / 2 * math.abs(math.sin(self.ang - self:trackAng(vv))) end
    local over = math.abs(u - self:centerAt(vv)) + across - half
    if over > 0 then
        if (self.t or 0) - (self.lastTouch or -1000) > 350 then
            self.touches = self.touches + 1; self.lastTouch = self.t
            self.impact = self.impact + clamp(over / half, 0.1, 1) * 0.25
            self:hurtAt(mx, my, 0.3 + clamp(over / half, 0, 1) * 0.5)
        end
    end
    if self.object == "worm" and not self.torn and (self.speed or 0) > 0.30 then
        self.torn = true
        self:hurtAt(mx, my, 0.4)
        self:say(T("UI_HomeMedic_Surg_G_Torn", "It tore - a piece stayed in"), mx, my - 24, { 1, 0.4, 0.3 })
    end
    if v <= 0.06 then
        self.got = self.got + 1
        G.sfx("Good")
        self.held = false; self.heldU, self.heldV = nil, nil
        if self.got >= self.count then self.done = true else self:place() end
    end
end
function Extract:score()
    return clamp(self.got / self.count * (self.torn and 0.6 or 1) - self.impact, 0, 1)
end
function Extract:effects()
    local left = (self.count - self.got) / self.count
    if self.torn then left = math.max(left, 0.5) end
    return { residual = clamp(left, 0, 1), tissue = clamp(self.impact, 0, 1) }
end

-- ============================================================= saw (P07 bone cut)
-- Hold to saw; the force must stay in the green band (too little: no
-- progress, too much: the bone splinters and the soft tissue around it is
-- torn). The blade wanders, more with force and shaky hands: move the
-- mouse left / right to keep it on the marked line.
local Saw = kind("saw")
Saw.vitalsLeft = true
for k2, v2 in pairs(Gauge) do if rawget(Saw, k2) == nil and type(v2) == "function" then Saw[k2] = v2 end end
function Saw:init()
    self:setup("saw")
    self.blade, self.drift, self.offSum, self.samples = 0, 0, 0, 0
end
function Saw:update(ms)
    self:tick(ms)
    if self.done then return end
    local inBand = self:pump(ms)
    -- the blade wanders with force and shake; the hand steers it back
    local push = (self.level - 0.4) * 0.6 + (self.p.shake or 0) * 0.3
    self.drift = self.drift + (rndf() - 0.5) * 0.002 * ms * math.max(0.2, push)
    self.drift = clamp(self.drift * 0.995, -0.4, 0.4)
    local want = self.steer or 0
    self.blade = self.blade + ((want + self.drift) - self.blade) * math.min(1, ms / 120)
    if self.holding then
        self.samples = self.samples + 1
        self.offSum = self.offSum + math.abs(self.blade)
    end
    if self.fill >= 1 then self.done = true end
end
function Saw:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    local sceneW = w * 0.62
    self:field(ui, x, y, sceneW, h)
    local sx, sy, sw, sh = x + 14, y + 14, sceneW - 28, h - 28
    local cx, cy = sx + sw / 2, sy + sh / 2
    local jx, jy = self:jolt()
    cx, cy = cx + jx, cy + jy
    self.sceneBox = { sx, sy, sw, sh }
    self:bed(ui, sx + 6, cy - 80, sw - 12, 160)
    img(ui, "bone", cx - 46, cy - 46, 92, 92, 1)
    -- the marked line and the cut actually made
    line(ui, cx, cy - 52, cx, cy + 52, 1, 0.8, 0.45, 0.2, 0.65)
    local bx = cx + self.blade * 46
    local depth = self.fill * 92
    ui:drawRect(bx - 2, cy - 46, 4, depth, 1, 0.25, 0.05, 0.04)
    self.work = { bx, cy - 46 + depth }
    self:lamp(ui)
    self:drawParticles(ui)
    self:drawWorkTool(ui, math.pi * 0.5)
    self:panel(ui, x, y, w, h, { 0.85, 0.80, 0.70 })
    self:drawSays(ui)
end
function Saw:mouseMove(mx, my)
    self:track(mx, my)
    local b = self.sceneBox
    -- the blade follows the hand (plus its own wander)
    if b then self.steer = clamp((mx - (b[1] + b[3] / 2)) / 46, -1, 1) end
end
function Saw:mouseDown(mx, my) self:track(mx, my); if not self.done then self.holding = true end end
function Saw:align() return clamp(1 - (self.samples > 0 and self.offSum / self.samples or 0) * 2.5, 0, 1) end
function Saw:score() return clamp(self.fill * (1 - self.damage) * (0.6 + 0.4 * self:align()), 0, 1) end
function Saw:effects() return { tissue = clamp(self.damage + (1 - self:align()) * 0.5, 0, 1) } end

-- ============================================================= suture (P08 closure)
-- Round 2026-10-09 ("มินิเกมเย็บแผลละเอียดน้อยไป"): simple interrupted
-- sutures, one at a time, the way they are really placed --
--   1 bite in   : the needle goes in at the marked point on the upper edge
--   2 bite out  : it comes out on the lower edge, straight across (the
--                 two bites should mirror each other: same distance, same line)
--   3 tie       : hold the mouse to draw the knot tight and let go in the
--                 green band -- too loose leaves a gap, too tight blanches
--                 and tears the skin edge
-- The wound closes only where the stitches are tied; each stitch shows its
-- two punctures, the thread across, the knot and its two tails, and says how
-- it approximates the edges (good / loose = a gap / tight = blanched skin /
-- uneven). Round 2026-10-10: a ragged incision (P01 tissue damage) is
-- harder to stitch; the step reports the gap and the over-tight stitches.
local Suture = kind("suture")
function Suture:init()
    local K = self:K() * self:toolK(0.35)
    self.limit = (22000 + 8000 * (self.p.skill or 0)) * self:timeK()
    self.count = 6
    self.tol = (9 + 9 * (self.p.skill or 0)) * K * (1 - 0.35 * self:prev("tissue"))
    local half = (0.11 + 0.04 * (self.p.skill or 0)) * K
    self.band = { 0.665 - half, 0.665 + half }   -- good knot tension
    self.i, self.phase = 1, "in"
    self.stitches = {}           -- { inX, inY, inAcc, outX, outY, outAcc, sym, tie, tied }
    self.tension = 0
end
-- the planned bite points of stitch i (u along the wound, 0..1 of the box)
function Suture:plan(i, x, y, w, h)
    local u = 0.18 + (i - 1) / (self.count - 1) * 0.64
    local sx, sy = self:sway(5)
    local cx = x + u * w + sx
    local bite = h * 0.13
    return cx, y + h / 2 - bite + sy, cx, y + h / 2 + bite + sy
end
-- how open the wound is around u (1 = gaping, small near tied stitches)
function Suture:gapAt(u, w)
    local open = 1
    for _, s in ipairs(self.stitches) do
        if s.tied and s.u then
            local d = math.abs(u - s.u)
            local reach = 0.09
            if d < reach then
                local closed = (1 - d / reach) * (s.tie or 0.5)
                open = math.min(open, 1 - closed * 0.85)
            end
        end
    end
    return open
end
function Suture:update(ms)
    self:tick(ms)
    if self.phase == "tie" and self.holding then
        -- the knot tightens while held; it speeds up, so timing matters
        self.tension = math.min(1.2, self.tension + ms / 1000 * (0.35 + self.tension * 0.9))
        if self.tension > self.band[2] + 0.14 and not self.tornWarned then
            self.tornWarned = true
            local s = self.stitches[self.i]
            if s then self:hurtAt(s.inX, s.inY, 0.25, true) end
        end
    end
end
function Suture:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:field(ui, x, y, w, h)
    local sx, sy = self:sway(5)
    local wx1, wx2 = x + w * 0.1 + sx, x + w * 0.9 + sx
    local wy = y + h / 2 + sy
    -- the incision, drawn in short pieces so it closes only where tied
    local pieces = 28
    for k = 0, pieces - 1 do
        local u0, u1 = k / pieces, (k + 1) / pieces
        local um = 0.1 + (u0 + u1) / 2 * 0.8
        local open = self:gapAt(um, w)
        local th = 6 + 26 * open
        strip(ui, "wound", wx1 + (wx2 - wx1) * u0, wy, wx1 + (wx2 - wx1) * u1 + 1, wy, th, 1)
        -- the everted, slightly swollen edges
        line(ui, wx1 + (wx2 - wx1) * u0, wy - th / 2, wx1 + (wx2 - wx1) * u1, wy - th / 2, 2, 0.55, 0.85, 0.55, 0.55)
        line(ui, wx1 + (wx2 - wx1) * u0, wy + th / 2, wx1 + (wx2 - wx1) * u1, wy + th / 2, 2, 0.55, 0.85, 0.55, 0.55)
    end
    -- the surgeon's marks for every bite (faint skin-pen dots)
    for i = 1, self.count do
        local ix, iy, ox, oy = self:plan(i, x, y, w, h)
        if i >= self.i then
            disc(ui, ix, iy, 2.2, 0.75, 0.45, 0.22, 0.62)
            disc(ui, ox, oy, 2.2, 0.75, 0.45, 0.22, 0.62)
        end
    end
    -- the stitches already in
    for i, s in ipairs(self.stitches) do
        -- the two punctures
        disc(ui, s.inX, s.inY, 3, 1, 0.35, 0.05, 0.05)
        if s.outX then disc(ui, s.outX, s.outY, 3, 1, 0.35, 0.05, 0.05) end
        if s.tied then
            -- across the wound, pulled in by the knot
            local pull = (s.tie or 0.5) * 0.35
            local my = (s.inY + s.outY) / 2
            local ay, by = s.inY + (my - s.inY) * pull, s.outY + (my - s.outY) * pull
            strip(ui, "thread", s.inX, ay, s.outX, by, 4, 1)
            -- the knot on the upper side and its two tails
            disc(ui, s.inX, ay - 2, 3.5, 1, 0.10, 0.16, 0.38)
            line(ui, s.inX, ay - 3, s.inX - 9, ay - 12, 1.6, 0.95, 0.12, 0.2, 0.45)
            line(ui, s.inX, ay - 3, s.inX + 8, ay - 13, 1.6, 0.95, 0.12, 0.2, 0.45)
            if s.tie and s.tie > 1.0 then
                -- too tight: blanched, torn skin
                disc(ui, s.inX, ay, 6, 0.35, 0.95, 0.9, 0.85)
            end
        elseif s.outX then
            -- passed but not yet tied: the loop lies loose across the gap
            strip(ui, "thread", s.inX, s.inY, s.outX, s.outY, 3, 0.85)
        elseif i == self.i then
            -- the needle has gone in: the thread runs from the hole to it
            if self.cx then strip(ui, "thread", s.inX, s.inY, self.cx, self.cy, 3, 0.9) end
            disc(ui, s.inX, s.inY + 4, 2, 0.9, 0.55, 0.05, 0.05)   -- a drop of blood
        end
    end
    -- the target of this step
    if not self.done then
        local ix, iy, ox, oy = self:plan(self.i, x, y, w, h)
        if self.phase == "in" then
            ring(ui, ix, iy, self.tol, 2, 0.85, 0.3, 1, 0.4)
        elseif self.phase == "out" then
            -- mirror of the actual entry, straight across
            local s = self.stitches[self.i]
            local tx = s and s.inX or ox
            ring(ui, tx, oy, self.tol, 2, 0.85, 0.3, 1, 0.4)
            line(ui, tx, iy + 4, tx, oy - 4, 1, 0.35, 0.3, 1, 0.4)
        elseif self.phase == "tie" then
            -- the tension gauge beside the stitch
            local gx, gy, gw, gh = ix + 18, iy - 34, 14, 68
            ui:drawRect(gx, gy, gw, gh, 0.8, 0.05, 0.05, 0.06)
            local lo, hi = self.band[1] / 1.2, self.band[2] / 1.2
            ui:drawRect(gx, gy + gh * (1 - hi), gw, gh * (hi - lo), 0.85, 0.2, 0.75, 0.3)
            local f = clamp(self.tension / 1.2, 0, 1)
            ui:drawRect(gx + 3, gy + gh * (1 - f), gw - 6, gh * f, 0.95, 0.95, 0.85, 0.3)
            ui:drawRectBorder(gx, gy, gw, gh, 1, 0.9, 0.9, 0.9)
        end
    end
    self:lamp(ui)
    self:drawParticles(ui)
    self:drawSays(ui)
    self:drawTool(ui, self.phase == "tie" and "hemostat" or "needle")
end
function Suture:mouseMove(mx, my) self:track(mx, my) end
function Suture:mouseDown(mx, my)
    self:track(mx, my)
    if self.done or not self.box then return end
    local x, y, w, h = unpack(self.box)
    local ix, iy, ox, oy = self:plan(self.i, x, y, w, h)
    if self.phase == "in" then
        local d = math.sqrt((mx - ix) ^ 2 + (my - iy) ^ 2)
        if d > self.tol * 2.4 then return end
        local u = 0.18 + (self.i - 1) / (self.count - 1) * 0.64
        self.stitches[self.i] = { inX = mx, inY = my, inAcc = clamp(1 - d / (self.tol * 2.2), 0, 1), u = u }
        G.sfx("Stitch")
        if self.stitches[self.i].inAcc < 0.3 then self:hurtAt(mx, my, 0.3) end
        self.phase = "out"
    elseif self.phase == "out" then
        local s = self.stitches[self.i]
        local d = math.sqrt((mx - s.inX) ^ 2 + (my - oy) ^ 2)
        if d > self.tol * 2.4 then return end
        s.outX, s.outY = mx, my
        s.outAcc = clamp(1 - d / (self.tol * 2.2), 0, 1)
        -- symmetry: same distance from the wound line on both sides
        local midY = y + h / 2
        local a, b = math.abs(s.inY - midY), math.abs(s.outY - midY)
        s.sym = clamp(1 - math.abs(a - b) / math.max(6, (a + b) / 2), 0, 1)
        G.sfx("Stitch")
        if s.outAcc < 0.3 then self:hurtAt(mx, my, 0.3) end
        self.phase = "tie"
        self.tension = 0
        self.tornWarned = false
    elseif self.phase == "tie" then
        self.holding = true
    end
end
function Suture:mouseUp()
    if self.phase ~= "tie" or not self.holding then return end
    self.holding = false
    local s = self.stitches[self.i]
    if not s then return end
    local t = self.tension
    local lo, hi = self.band[1], self.band[2]
    local q
    if t >= lo and t <= hi then q = 1
    elseif t < lo then q = clamp(t / lo, 0, 1) * 0.7
    else q = clamp(1 - (t - hi) / 0.4, 0, 1) * 0.6 end
    s.tieQ = q
    s.tie = t
    s.tied = true
    s.loose = t < lo
    s.tight = t > hi
    G.sfx("Stitch")
    local word, col
    if s.tight then word, col = T("UI_HomeMedic_Surg_G_Tight", "Too tight"), { 1, 0.4, 0.3 }
    elseif s.loose then word, col = T("UI_HomeMedic_Surg_G_Loose", "Loose - gap"), { 1, 0.75, 0.3 }
    elseif (s.sym or 1) < 0.6 then word, col = T("UI_HomeMedic_Surg_G_Uneven", "Uneven"), { 1, 0.75, 0.3 }
    else word, col = T("UI_HomeMedic_Surg_G_Good", "Good"), { 0.4, 1, 0.5 } end
    self:say(word, s.inX, s.inY - 26, col)
    self.i = self.i + 1
    self.phase = "in"
    self.tension = 0
    if self.i > self.count then self.done = true end
end
function Suture:score()
    local total = 0
    for i = 1, self.count do
        local s = self.stitches[i]
        if s and s.tied then
            total = total + 0.3 * (s.inAcc or 0) + 0.25 * (s.outAcc or 0) * (0.5 + 0.5 * (s.sym or 0)) + 0.45 * (s.tieQ or 0)
        end
    end
    return clamp(total / self.count, 0, 1)
end

function Suture:effects()
    local gap, tight = 0, 0
    for i = 1, self.count do
        local st = self.stitches[i]
        if not (st and st.tied) then gap = gap + 1
        else
            if st.loose then gap = gap + 0.7 end
            if st.tight then tight = tight + 1 end
        end
    end
    return { gap = clamp(gap / self.count, 0, 1), tension = clamp(tight / self.count, 0, 1) }
end

-- ============================================================= valve (P09 chest drain)
-- A chest tube drains into a water-seal bottle. Hold to open the suction
-- valve and keep the needle in its range (too much = the lung is pulled
-- against the tube). Things go wrong as they do on a ward: the tube KINKS
-- (no flow -- click the tube to straighten it) or the connector LEAKS (air
-- bubbles through the seal -- click the connector). Unnoticed problems cost.
local Valve = kind("valve")
Valve.vitalsLeft = true
for k2, v2 in pairs(Gauge) do if rawget(Valve, k2) == nil and type(v2) == "function" then Valve[k2] = v2 end end
function Valve:init()
    self:setup("valve")
    self.events, self.nextEvent = {}, 3500 + rnd(2500)
    self.unnoticed, self.fixed = 0, 0
end
function Valve:update(ms)
    self:tick(ms)
    if self.done then return end
    if self.t >= self.nextEvent and not self.problem then
        self.problem = { kind = (rnd(2) == 0) and "kink" or "leak", at = self.t }
        self.nextEvent = self.t + 5000 + rnd(4000)
        G.sfx("Alarm", 1500)
    end
    local flowing = not (self.problem and self.problem.kind == "kink")
    self:pump(ms, flowing)
    if self.problem then
        self.unnoticed = self.unnoticed + ms / 1000
        if self.problem.kind == "leak" and self.panelBox and rndf() < 0.3 then
            local b = self.panelBox
            self:burst("water", b[1] + b[3] / 2, b[2] + b[4] - 30, 1)
        end
    end
    if self.fill >= 1 then self.done = true end
end
function Valve:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    local sceneW = w * 0.62
    self:field(ui, x, y, sceneW, h)
    local sx, sy, sw, sh = x + 14, y + 14, sceneW - 28, h - 28
    self:bed(ui, sx + 6, sy + 16, sw - 12, sh - 32)
    -- the tube from the chest to the bottle; the connector half way
    local tx1, ty1 = sx + sw * 0.35, sy + sh * 0.45
    local tx2, ty2 = x + sceneW, sy + sh * 0.75
    local kink = self.problem and self.problem.kind == "kink"
    local mx, my = (tx1 + tx2) / 2, (ty1 + ty2) / 2 + (kink and 18 or 0)
    line(ui, tx1, ty1, mx, my, 9, 1, 0.92, 0.93, 0.95)
    line(ui, mx, my, tx2, ty2, 9, 1, 0.92, 0.93, 0.95)
    line(ui, tx1, ty1, mx, my, 5, 0.9, 0.75, 0.3, 0.25)
    line(ui, mx, my, tx2, ty2, 5, kink and 0.3 or 0.9, 0.75, 0.3, 0.25)
    local cx2, cy2 = tx1 + (tx2 - tx1) * 0.8, ty1 + (ty2 - ty1) * 0.8
    disc(ui, cx2, cy2, 8, 1, 0.55, 0.6, 0.7)
    self.kinkAt, self.connAt = { mx, my }, { cx2, cy2 }
    if self.problem then
        local p = self.problem.kind == "kink" and self.kinkAt or self.connAt
        if math.floor(self.t / 250) % 2 == 0 then ring(ui, p[1], p[2], 16, 3, 1, 1, 0.3, 0.2) end
        ui:drawTextCentre(self.problem.kind == "kink" and T("UI_HomeMedic_Surg_G_Kink", "Kinked!") or T("UI_HomeMedic_Surg_G_Leak", "Air leak!"),
            p[1], p[2] - 34, 1, 0.5, 0.4, 1, UIFont.Small)
    end
    self.work = { tx1, ty1 }
    self:lamp(ui)
    self:drawParticles(ui)
    self:panel(ui, x, y, w, h, { 0.75, 0.25, 0.22 })
    self:drawSays(ui)
end
function Valve:mouseDown(mx, my)
    self:track(mx, my)
    if self.done then return end
    if self.problem then
        local p = self.problem.kind == "kink" and self.kinkAt or self.connAt
        if p and (mx - p[1]) ^ 2 + (my - p[2]) ^ 2 <= 26 ^ 2 then
            self.fixed = self.fixed + 1
            self.problem = nil
            G.sfx("Clamp")
            self:say(T("UI_HomeMedic_Surg_G_Fixed", "Fixed"), mx, my - 20, { 0.4, 1, 0.5 })
            return
        end
    end
    self.holding = true
end
function Valve:score() return clamp(self.fill * (1 - self.damage) - 0.03 * self.unnoticed, 0, 1) end
function Valve:effects()
    return { residual = clamp(1 - self.fill, 0, 1), tissue = clamp(self.damage + 0.02 * self.unnoticed, 0, 1) }
end

-- ============================================================= catheter (P10 catheterization)
-- A line threaded along a vein under the skin. Stay in the vein (blue);
-- next to it run an ARTERY (red) and a NERVE (yellow) -- touching them
-- hurts and is how lines end up in the wrong place. At each checkpoint the
-- needle stops: release and click the checkpoint to ASPIRATE -- dark blood
-- back (flashback) confirms you are in the vein. At the end click the hub
-- to FLUSH. A line that is not confirmed may be misplaced.
local Cath = kind("catheter")
function Cath:init()
    local K = self:K() * self:toolK(0.35)
    self.limit = (22000 + 6000 * (self.p.skill or 0)) * self:timeK()
    self.tol = (7 + 9 * (self.p.skill or 0)) * K
    self.pts = {}
    local a1 = rndf() * 0.2 + 0.1
    for i = 0, 40 do
        local u = i / 40
        self.pts[#self.pts + 1] = { u = u, v = 0.5 + math.sin(u * math.pi * 3.0) * (a1 * 0.5 + 0.1) }
    end
    self.checks = { 0.33, 0.66, 1.0 }
    self.ci = 1
    self.progress, self.inside, self.samples, self.drawing = 0, 0, 0, false
    self.segIn, self.segN = 0, 0
    self.confirmed, self.noFlash, self.nerve, self.artery = 0, 0, 0, 0
    self.waiting = false
end
Cath.pathAt = Trace.pathAt
function Cath:update(ms) self:tick(ms) end
function Cath:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:field(ui, x, y, w, h)
    local N = 60
    -- the artery runs just below the vein, the nerve just above (the
    -- dangerous neighbours)
    local off = self.tol * 2.6
    local lx, ly
    for i = 0, N do
        local px, py = self:pathAt(i / N, w, h, x, y)
        if lx then
            strip(ui, "vein", lx, ly + off, px, py + off, self.tol * 1.4, 0.75, 1, 0.35, 0.35)
            line(ui, lx, ly - off, px, py - off, 3, 0.8, 1, 0.9, 0.3)
            strip(ui, "vein", lx, ly, px, py, self.tol * 2.2, 0.9)
            if i / N <= self.progress then line(ui, lx, ly, px, py, 3, 0.95, 0.92, 0.92, 0.95) end
        end
        lx, ly = px, py
    end
    -- checkpoints
    for n, u in ipairs(self.checks) do
        local cx, cy = self:pathAt(u, w, h, x, y)
        local done = n < self.ci
        local now = n == self.ci and self.waiting
        ring(ui, cx, cy, now and (11 + math.sin(self.t / 120) * 2) or 8, 2, 0.9, done and 0.3 or 1, done and 1 or 1, done and 0.4 or (now and 0.3 or 1))
    end
    local sx, sy = self:pathAt(self.progress, w, h, x, y)
    if not self.drawing and not self.waiting then ring(ui, sx, sy, 10 + math.sin((self.t or 0) / 150) * 2, 2, 0.9, 0.3, 1, 0.4) end
    if self.flash and self.t - self.flash.t < 1200 then
        disc(ui, self.flash.x, self.flash.y, 6, 0.9, self.flash.ok and 0.35 or 0.9, self.flash.ok and 0.02 or 0.85, self.flash.ok and 0.05 or 0.85)
    end
    self:lamp(ui)
    self:drawParticles(ui)
    self:drawSays(ui)
    self:drawTool(ui, "catheter")
end
function Cath:mouseDown(mx, my)
    self:track(mx, my)
    if not self.box or self.done then return end
    local x, y, w, h = unpack(self.box)
    if self.waiting then
        -- aspirate at the checkpoint: flashback if the last stretch stayed in the vein
        local cx, cy = self:pathAt(self.checks[self.ci], w, h, x, y)
        if (mx - cx) ^ 2 + (my - cy) ^ 2 > 22 ^ 2 then return end
        local acc = self.segN > 0 and self.segIn / self.segN or 0
        local ok = acc >= 0.6
        self.flash = { x = cx, y = cy, ok = ok, t = self.t }
        if ok then self.confirmed = self.confirmed + 1; G.sfx("Good")
            self:say(self.ci == #self.checks and T("UI_HomeMedic_Surg_G_Flushed", "Flushes freely") or T("UI_HomeMedic_Surg_G_Flashback", "Flashback - in the vein"), cx, cy - 22, { 0.4, 1, 0.5 })
        else self.noFlash = self.noFlash + 1; G.sfx("Bad")
            self:say(T("UI_HomeMedic_Surg_G_NoFlash", "No flashback - misplaced?"), cx, cy - 22, { 1, 0.6, 0.3 }) end
        self.waiting = false
        self.segIn, self.segN = 0, 0
        self.ci = self.ci + 1
        if self.ci > #self.checks then self.done = true end
        return
    end
    local sx, sy = self:pathAt(self.progress, w, h, x, y)
    if (mx - sx) ^ 2 + (my - sy) ^ 2 <= (self.tol + 10) ^ 2 then self.drawing = true end
end
function Cath:mouseUp() self.drawing = false end
function Cath:mouseMove(mx, my)
    self:track(mx, my)
    if not self.drawing or self.waiting or not self.box or self.done then return end
    local x, y, w, h = unpack(self.box)
    local u = clamp((mx - x - 30) / (w - 60), 0, 1)
    if u < self.progress - 0.02 then return end
    local stop = self.checks[self.ci]
    u = math.min(u, stop)
    local _, py = self:pathAt(u, w, h, x, y)
    local d = my - py
    self.samples = self.samples + 1
    self.segN = self.segN + 1
    local off = self.tol * 2.6
    if math.abs(d) <= self.tol then
        self.inside = self.inside + 1
        self.segIn = self.segIn + 1
        G.sfx("Stitch", 260)
    elseif math.abs(d - off) < self.tol * 0.8 then
        if self.t - (self.lastNick or -1000) > 600 then self.lastNick = self.t; self.artery = self.artery + 1; self:hurtAt(mx, my, 0.8)
            self:say(T("UI_HomeMedic_Surg_G_Artery", "Artery!"), mx, my - 20, { 1, 0.3, 0.3 }) end
    elseif math.abs(d + off) < self.tol * 0.8 then
        if self.t - (self.lastNick or -1000) > 600 then self.lastNick = self.t; self.nerve = self.nerve + 1; self:hurtAt(mx, my, 0.5)
            self:say(T("UI_HomeMedic_Surg_G_Nerve", "Nerve - sharp pain"), mx, my - 20, { 1, 0.9, 0.3 }) end
    end
    if u > self.progress and u - self.progress < 0.08 then self.progress = u end
    if self.progress >= stop - 0.005 then
        self.progress = stop
        self.drawing = false
        self.waiting = true
        G.sfx("Clamp")
    end
end
function Cath:score()
    local acc = self.samples > 0 and self.inside / self.samples or 0
    return clamp(self.progress * (0.6 * acc + 0.4 * self.confirmed / #self.checks) - 0.08 * self.artery, 0, 1)
end
function Cath:effects()
    return { misplace = clamp(0.35 * self.noFlash + 0.2 * self.artery + (self.ci <= #self.checks and 0.5 or 0), 0, 1),
             tissue = clamp(0.15 * self.artery + 0.1 * self.nerve, 0, 1) }
end

-- ============================================================= dialysis (P11)
-- A blood circuit: out of the vein, through the filter, back. Hold the LEFT
-- half to speed the BLOOD PUMP, the RIGHT half to raise ULTRAFILTRATION
-- (water taken off); each falls when released. Both must sit in their
-- green band -- and the pump is not free: more flow pushes up the VENOUS
-- PRESSURE, which must stay out of the red. The filter slowly clots (the
-- pressure creeps up: press FLUSH), and air can get into the line (CLAMP
-- it at once). Efficiency x stability is the treatment.
local Dialysis = kind("dialysis")
Dialysis.vitalsAt = "center"
function Dialysis:init()
    local K = self:K() * self:toolK(0.3)
    self.limit = (24000 + 6000 * (self.p.skill or 0)) * self:timeK()
    self.band = (0.13 + 0.07 * (self.p.skill or 0)) * K
    self.qb, self.uf, self.fill, self.side = 0.2, 0.2, 0, nil
    self.clotLv, self.unstable, self.total = 0, 0, 0
    self.air, self.airMissed, self.nextAir = nil, 0, 7000 + rnd(5000)
    self.flushUntil = 0
end
function Dialysis:targets()
    local t = (self.t or 0) / 1000
    return 0.55 + math.sin(t * 0.45) * 0.15, 0.45 + math.cos(t * 0.35) * 0.15
end
function Dialysis:venous() return clamp(0.25 + 0.55 * self.qb + 0.5 * self.clotLv, 0, 1.2) end
function Dialysis:update(ms)
    self:tick(ms)
    if self.done then return end
    local dt = ms / 1000
    self.qb = clamp(self.qb + ((self.side == "a") and 0.45 or -0.30) * dt, 0, 1)
    self.uf = clamp(self.uf + ((self.side == "b") and 0.45 or -0.30) * dt, 0, 1)
    if self.side then G.sfx("Pump", 300) end
    self.clotLv = clamp(self.clotLv + dt * 0.035, 0, 1)
    if self.t >= self.nextAir and not self.air then
        self.air = { at = self.t }
        self.nextAir = self.t + 9000 + rnd(6000)
        G.sfx("Alarm", 1200)
    end
    if self.air and self.t - self.air.at > 3000 then
        -- air reached the patient
        self.air = nil
        self.airMissed = self.airMissed + 1
        if self.box then self:hurtAt(self.box[1] + self.box[3] / 2, self.box[2] + self.box[4] / 2, 1) end
    end
    local ta, tb = self:targets()
    local inA = math.abs(self.qb - ta) <= self.band / 2
    local inB = math.abs(self.uf - tb) <= self.band / 2
    local pv = self:venous()
    local alarm = pv > 0.85 or self.air ~= nil
    self.total = self.total + dt
    if alarm or not (inA and inB) then self.unstable = self.unstable + dt end
    if self.t >= self.flushUntil and not alarm then
        if inA and inB then self.fill = self.fill + dt / 9 * (0.6 + 0.6 * self.qb)
        elseif inA or inB then self.fill = self.fill + dt / 28 end
    end
    if self.fill >= 1 then self.fill = 1; self.done = true end
end
local function pumpDial(ui, cx, cy, r, val, tgt, band, redFrom)
    disc(ui, cx, cy, r + 7, 1, 0.08, 0.09, 0.11)
    disc(ui, cx, cy, r + 3, 1, 0.88, 0.89, 0.86)
    local a0, a1 = math.pi * 0.85, math.pi * 2.15
    local function ang(v) return a0 + (a1 - a0) * clamp(v, 0, 1) end
    if tgt then arc(ui, cx, cy, r - 6, 8, ang(tgt - band / 2), ang(tgt + band / 2), 1, 0.15, 0.70, 0.25) end
    if redFrom then arc(ui, cx, cy, r - 6, 8, ang(redFrom), a1, 0.9, 0.85, 0.15, 0.12) end
    local na = ang(val)
    line(ui, cx, cy, cx + math.cos(na) * (r - 9), cy + math.sin(na) * (r - 9), 3, 1, 0.75, 0.05, 0.05)
    disc(ui, cx, cy, 5, 1, 0.15, 0.15, 0.18)
end
function Dialysis:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    ui:drawRect(x, y, w, h, 1, 0.82, 0.84, 0.86)
    ui:drawRect(x + 6, y + 6, w - 12, h - 12, 1, 0.70, 0.73, 0.76)
    ui:drawRectBorder(x, y, w, h, 1, 0.35, 0.38, 0.42)
    local ta, tb = self:targets()
    local r = math.min(w * 0.13, h * 0.22)
    local ay, ax, bx = y + h * 0.36, x + w * 0.18, x + w * 0.82
    pumpDial(ui, ax, ay, r, self.qb, ta, self.band)
    pumpDial(ui, bx, ay, r, self.uf, tb, self.band)
    ui:drawTextCentre(T("UI_HomeMedic_Surg_G_BloodPump", "Blood pump"), ax, ay + r + 12, 0.15, 0.15, 0.2, 1, UIFont.Small)
    ui:drawTextCentre(T("UI_HomeMedic_Surg_G_UF", "Fluid removal"), bx, ay + r + 12, 0.15, 0.15, 0.2, 1, UIFont.Small)
    -- venous pressure (small dial, red zone) under the filter
    local pv = self:venous()
    pumpDial(ui, x + w / 2, y + h - 52, 30, pv / 1.2, nil, 0, 0.85 / 1.2)
    ui:drawTextCentre(T("UI_HomeMedic_Surg_G_Venous", "Venous pressure"), x + w / 2, y + h - 18, 0.15, 0.15, 0.2, 1, UIFont.Small)
    -- the filter: darker as it clots
    local fx, fy, fw, fh = x + w / 2 - 18, y + 70, 36, h * 0.45
    ui:drawRect(fx, fy, fw, fh, 1, 0.92, 0.94, 0.96)
    ui:drawRect(fx + 4, fy + fh - 4 - (fh - 8) * self.fill, fw - 8, (fh - 8) * self.fill, 1, 0.75, 0.08, 0.08)
    ui:drawRect(fx + 4, fy + 4, fw - 8, (fh - 8), 0.45 * self.clotLv, 0.15, 0.02, 0.02)
    ui:drawRectBorder(fx, fy, fw, fh, 1, 0.4, 0.45, 0.5)
    local t = (self.t or 0) / 1000
    local function tube(x1, y1, x2, y2, flow, air)
        line(ui, x1, y1, x2, y2, 9, 1, 0.92, 0.93, 0.95)
        line(ui, x1, y1, x2, y2, 5, 1, 0.55, 0.04, 0.05)
        for k = 0, 6 do
            local u = ((k / 7) + t * 0.6 * (flow + 0.1)) % 1
            disc(ui, x1 + (x2 - x1) * u, y1 + (y2 - y1) * u, 2.5, 0.9, 0.95, 0.4, 0.4)
        end
        if air then
            local u = clamp((self.t - air.at) / 3000, 0, 1)
            disc(ui, x1 + (x2 - x1) * u, y1 + (y2 - y1) * u, 5, 1, 1, 1, 1)
        end
    end
    tube(ax + r + 8, ay, fx, fy + 20, self.qb)
    tube(fx + fw, fy + fh - 20, bx - r - 8, ay, self.qb, self.air)
    -- buttons
    self:button(ui, "flush", x + 16, y + h - 40, 110, 26, T("UI_HomeMedic_Surg_G_Flush", "Flush filter"), self.clotLv > 0.4, { 0.3, 0.7, 1 })
    self:button(ui, "clamp", x + w - 126, y + h - 40, 110, 26, T("UI_HomeMedic_Surg_G_Clamp", "Clamp line"), self.air ~= nil, { 1, 0.35, 0.3 })
    if self.air and math.floor(self.t / 250) % 2 == 0 then
        ui:drawTextCentre(T("UI_HomeMedic_Surg_G_AirLine", "AIR IN LINE"), x + w / 2, y + 30, 0.9, 0.1, 0.1, 1, UIFont.Medium)
    end
    self:drawParticles(ui)
    self:drawSays(ui)
end
function Dialysis:mouseMove(mx, my) self:track(mx, my) end
function Dialysis:mouseDown(mx, my)
    self:track(mx, my)
    if self.done or not self.box then return end
    local b = self:hitButton(mx, my)
    if b == "flush" then
        self.clotLv = 0
        self.flushUntil = self.t + 1200
        G.sfx("Squirt")
        return
    elseif b == "clamp" then
        if self.air then self.air = nil; G.sfx("Clamp"); self:say(T("UI_HomeMedic_Surg_G_Fixed", "Fixed"), mx, my - 20, { 0.4, 1, 0.5 }) end
        return
    end
    self.side = (mx < self.box[1] + self.box[3] / 2) and "a" or "b"
end
function Dialysis:mouseUp() self.side = nil end
function Dialysis:stability() return clamp(1 - (self.total > 0 and self.unstable / self.total or 1), 0, 1) end
function Dialysis:score() return clamp(self.fill * (0.6 + 0.4 * self:stability()) - 0.2 * self.airMissed, 0, 1) end
function Dialysis:effects()
    return { residual = clamp(1 - self.fill, 0, 1), tissue = clamp(0.3 * self.airMissed, 0, 1) }
end

-- ============================================================= cells (P12 cell graft)
-- Experimental gene therapy, two parts. PREPARE: pick the healthy cells in
-- order 1, 2, 3...; malformed ones (dark, irregular) must be thrown out
-- with a right click -- they are not in the count. GRAFT: put the patches
-- on the recipient bed so it is covered evenly; a patch on a patch is
-- wasted. (The ordering is a rule of this experimental technique, not of
-- real cell transplantation.)
local Cells = kind("cells")
function Cells:init()
    local K = self:K() * self:toolK(0.3)
    self.limit = (24000 + 8000 * (self.p.skill or 0)) * self:timeK()
    self.n = 9
    self.order = {}
    for i = 1, self.n do self.order[i] = i end
    for i = self.n, 2, -1 do local j = rnd(i) + 1; self.order[i], self.order[j] = self.order[j], self.order[i] end
    self.bad = {}
    local nBad = (K < 0.8) and 3 or 2
    local picked = 0
    while picked < nBad do
        local k = rnd(self.n) + 1
        if not self.bad[k] then self.bad[k] = true; picked = picked + 1 end
    end
    self.normalOrder = {}
    for k = 1, self.n do if not self.bad[k] then self.normalOrder[#self.normalOrder + 1] = self.order[k] end end
    table.sort(self.normalOrder)
    self.next, self.wrong, self.badUsed, self.discarded = 1, 0, 0, 0
    self.got, self.gone = {}, {}
    self.spots = {}
    for k = 1, self.n do
        local a = (k / self.n) * 6.283 + rndf() * 0.4
        local d = 0.2 + rndf() * 0.22
        self.spots[k] = { u = 0.5 + math.cos(a) * d, v = 0.5 + math.sin(a) * d, ph = rndf() * 6 }
    end
    self.phase = "prep"
    self.cols, self.rows = 5, 3
    self.slots = {}
    self.patches, self.waste = 0, 0
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
function Cells:startGraft()
    self.phase = "graft"
    self.patches = 2 * #self.normalOrder
    for _, v in pairs(self.got) do if v == "bad" then self.patches = self.patches - 2 end end
    self.patches = math.max(0, self.patches)
    G.sfx("Good")
end
function Cells:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    ui:drawRect(x, y, w, h, 1, 0.10, 0.11, 0.13)
    if self.phase == "prep" then
        local size = math.min(w, h) * 0.92
        img(ui, "dish", x + (w - size) / 2, y + (h - size) / 2, size, size, 1)
        for k = 1, self.n do
            if not self.gone[k] then
                local cx, cy, r = self:cellPos(k, x, y, w, h)
                local bad = self.bad[k]
                local done = self.got[k] ~= nil
                local rr = bad and r * 1.15 or r
                img(ui, "cell", cx - rr, cy - rr * (bad and 0.8 or 1), rr * 2, rr * 2 * (bad and 0.8 or 1), 1,
                    bad and 0.35 or (done and 0.5 or 0.55), bad and 0.25 or (done and 0.9 or 0.45), bad and 0.40 or (done and 0.55 or 0.85))
                if bad then disc(ui, cx + r * 0.2, cy - r * 0.1, r * 0.45, 0.85, 0.18, 0.05, 0.22) end
                ui:drawTextCentre(tostring(self.order[k]), cx, cy - 8, 1, 1, 1, done and 0.35 or 1, UIFont.Medium)
            end
        end
        img(ui, "vignette", x, y, w, h, 0.9)
    else
        -- the recipient bed: a grid of slots to cover
        local gw, gh = w * 0.7, h * 0.6
        local gx, gy = x + (w - gw) / 2, y + (h - gh) / 2
        self.grid = { gx, gy, gw / self.cols, gh / self.rows }
        img(ui, "organ_bed", gx - 10, gy - 10, gw + 20, gh + 20, 1)
        for r = 0, self.rows - 1 do
            for c = 0, self.cols - 1 do
                local i = r * self.cols + c + 1
                local sx, sy = gx + c * gw / self.cols, gy + r * gh / self.rows
                if self.slots[i] then
                    img(ui, "cell", sx + 3, sy + 3, gw / self.cols - 6, gh / self.rows - 6, 0.9, 0.5, 0.9, 0.55)
                else
                    ui:drawRectBorder(sx + 3, sy + 3, gw / self.cols - 6, gh / self.rows - 6, 0.5, 1, 1, 1)
                end
            end
        end
        ui:drawText(T("UI_HomeMedic_Surg_G_Patches", "Patches left") .. ": " .. tostring(self.patches), x + 16, y + h - 30, 1, 1, 1, 1, UIFont.Small)
    end
    self:drawParticles(ui)
    self:drawSays(ui)
    self:drawTool(ui, "pipette")
end
function Cells:mouseMove(mx, my) self:track(mx, my) end
function Cells:pick(mx, my)
    local x, y, w, h = unpack(self.box)
    for k = 1, self.n do
        if not self.gone[k] and self.got[k] == nil then
            local cx, cy, r = self:cellPos(k, x, y, w, h)
            if (mx - cx) ^ 2 + (my - cy) ^ 2 <= (r + 4) ^ 2 then return k, cx, cy end
        end
    end
    return nil
end
function Cells:mouseDown(mx, my)
    self:track(mx, my)
    if self.done or not self.box then return end
    if self.phase == "prep" then
        local k, cx, cy = self:pick(mx, my)
        if not k then return end
        if self.bad[k] then
            -- a malformed cell put into the graft
            self.badUsed = self.badUsed + 1
            self.got[k] = "bad"
            G.sfx("Bad")
            self:say(T("UI_HomeMedic_Surg_G_Malformed", "Malformed cell used!"), cx, cy - 24, { 1, 0.4, 0.3 })
        elseif self.order[k] == self.normalOrder[self.next] then
            self.got[k] = "ok"
            self.next = self.next + 1
            G.sfx("Pop")
            self:burst("water", cx, cy, 3)
        else
            self.wrong = self.wrong + 1
            G.sfx("Bad")
            self.shakeAmt, self.shakeUntil = 2, (self.t or 0) + 200
        end
        if self.next > #self.normalOrder then self:startGraft() end
        return
    end
    -- graft
    if not self.grid or self.patches <= 0 then return end
    local gx, gy, cw, ch = unpack(self.grid)
    local c, r = math.floor((mx - gx) / cw), math.floor((my - gy) / ch)
    if c < 0 or r < 0 or c >= self.cols or r >= self.rows then return end
    local i = r * self.cols + c + 1
    self.patches = self.patches - 1
    if self.slots[i] then self.waste = self.waste + 1; G.sfx("Bad") else self.slots[i] = true; G.sfx("Pop") end
    if self.patches <= 0 or self:coverage() >= 1 then self.done = true end
end
function Cells:rightDown(mx, my)
    self:track(mx, my)
    if self.done or not self.box or self.phase ~= "prep" then return end
    local k, cx, cy = self:pick(mx, my)
    if not k then return end
    self.gone[k] = true
    if self.bad[k] then
        self.discarded = self.discarded + 1
        G.sfx("Good")
        self:say(T("UI_HomeMedic_Surg_G_Discarded", "Discarded"), cx, cy - 24, { 0.4, 1, 0.5 })
    else
        -- a healthy cell thrown away: one less patch
        self.wrong = self.wrong + 1
        self.normalOrder = (function()
            local out = {}
            for _, v in ipairs(self.normalOrder) do if v ~= self.order[k] then out[#out + 1] = v end end
            return out
        end)()
        G.sfx("Bad")
        if self.next > #self.normalOrder then self:startGraft() end
    end
end
function Cells:coverage()
    local n = 0
    for _ in pairs(self.slots) do n = n + 1 end
    return n / (self.cols * self.rows)
end
function Cells:sortScore()
    return clamp((self.next - 1) / math.max(1, #self.normalOrder) - 0.08 * self.wrong - 0.25 * self.badUsed, 0, 1)
end
function Cells:score() return clamp(0.45 * self:sortScore() + 0.55 * self:coverage() - 0.03 * self.waste, 0, 1) end
function Cells:effects() return { residual = clamp(1 - self:coverage(), 0, 1), tissue = clamp(0.3 * self.badUsed, 0, 1) } end

-- ============================================================= drill (P13 craniotomy)
-- A burr hole: keep the drill tip on the mark (move the mouse; the head
-- moves with an unsedated patient) and hold to drill with the force in the
-- green band. The bone has layers -- the hard outer table, the soft spongy
-- middle (it bleeds), the inner table -- and then the dura. When it breaks
-- through (BREAKTHROUGH), let go at once: drilling on is a plunge into the
-- brain.
local Drill = kind("drill")
Drill.vitalsLeft = true
for k2, v2 in pairs(Gauge) do if rawget(Drill, k2) == nil and type(v2) == "function" then Drill[k2] = v2 end end
Drill.LAYERS = { { to = 0.35, band = 1.0 }, { to = 0.65, band = 1.4 }, { to = 0.95, band = 0.75 } }
function Drill:init()
    self:setup("drill")
    self.depth, self.neuro, self.offSum, self.samples = 0, 0, 0, 0
    self.through, self.throughAt = false, nil
    self.mark = { u = 0.5, v = 0.5 }
    self.aim = self:K() * self:toolK(0.35) * 26
end
function Drill:layer()
    for i, l in ipairs(Drill.LAYERS) do if self.depth < l.to then return i, l end end
    return 4, nil
end
function Drill:update(ms)
    self:tick(ms)
    if self.done then return end
    local i, l = self:layer()
    self.band = self.band0 * (l and l.band or 0.6) * (self.depth > 0.8 and 0.7 or 1)
    local before = self.fill
    local onMark = self:onMark()
    self:pump(ms, onMark)
    local gained = self.fill - before
    self.depth = clamp(self.depth + gained, 0, 1)
    self.fill = self.depth
    if self.holding then
        self.samples = self.samples + 1
        if not onMark then self.offSum = self.offSum + 1 end
    end
    if not self.through and self.depth >= 0.95 then
        self.through, self.throughAt = true, self.t
        G.sfx("Clamp")
        self:say(T("UI_HomeMedic_Surg_G_Through", "BREAKTHROUGH - stop!"), self.work and self.work[1] or 0, (self.work and self.work[2] or 0) - 30, { 1, 0.9, 0.3 })
    end
    if self.through then
        if self.holding and self.t - self.throughAt > 300 then
            self.neuro = clamp(self.neuro + ms / 2500, 0, 1)
            if not self.lastHurt or self.t - self.lastHurt > 600 then self:hurtAt(self.work[1], self.work[2], 0.8) end
        elseif not self.holding then
            self.depth, self.fill = 1, 1
            self.done = true
        end
    end
end
function Drill:markPos()
    local b = self.sceneBox
    if not b then return 0, 0 end
    local sx, sy = self:sway(8)
    return b[1] + self.mark.u * b[3] + sx, b[2] + self.mark.v * b[4] + sy
end
function Drill:onMark()
    if not self.cx then return false end
    local mx, my = self:markPos()
    return (self.cx - mx) ^ 2 + (self.cy - my) ^ 2 <= self.aim ^ 2
end
function Drill:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    local sceneW = w * 0.62
    self:field(ui, x, y, sceneW, h, "skull")
    local sx, sy, sw, sh = x + 14, y + 14, sceneW - 28, h - 28
    self.sceneBox = { sx, sy, sw, sh }
    local mx, my = self:markPos()
    -- the burr hole: colour by layer reached
    local r = 6 + 16 * self.depth
    local i = self:layer()
    local col = (i == 1) and { 0.85, 0.80, 0.68 } or (i == 2 and { 0.70, 0.35, 0.30 } or (i == 3 and { 0.80, 0.75, 0.65 } or { 0.55, 0.15, 0.20 }))
    disc(ui, mx, my, r + 3, 1, 0.55, 0.45, 0.35)
    disc(ui, mx, my, r, 1, col[1], col[2], col[3])
    ring(ui, mx, my, self.aim, 1, 0.5, 0.3, 1, 0.4)
    self.work = { self.cx or mx, self.cy or my }
    self:lamp(ui)
    self:drawParticles(ui)
    self:drawWorkTool(ui)
    self:panel(ui, x, y, w, h, { 0.85, 0.80, 0.70 })
    -- layer ruler beside the dial
    local p = self.panelBox
    if p then
        local rx, ry, rh = p[1] + 10, p[2] + p[4] - 150, 120
        for li, l in ipairs(Drill.LAYERS) do
            local y0 = ry + rh * ((li == 1) and 0 or Drill.LAYERS[li - 1].to)
            ui:drawRect(rx, y0, 10, rh * (l.to - ((li == 1) and 0 or Drill.LAYERS[li - 1].to)), 0.9, li == 2 and 0.7 or 0.85, li == 2 and 0.35 or 0.8, li == 2 and 0.3 or 0.68)
        end
        ui:drawRect(rx, ry + rh * 0.95, 10, rh * 0.05, 1, 0.9, 0.2, 0.2)
        ui:drawRect(rx - 3, ry + rh * self.depth - 1, 16, 3, 1, 1, 1, 0.3)
        if self.depth > 0.8 and not self.through and math.floor(self.t / 200) % 2 == 0 then
            ui:drawText(T("UI_HomeMedic_Surg_G_NearDura", "Near the dura"), rx + 16, ry + rh * 0.8, 1, 0.5, 0.3, 1, UIFont.Small)
        end
    end
    self:drawSays(ui)
end
function Drill:mouseMove(mx, my) self:track(mx, my) end
function Drill:mouseDown(mx, my) self:track(mx, my); if not self.done then self.holding = true end end
function Drill:align() return clamp(1 - (self.samples > 0 and self.offSum / self.samples or 0), 0, 1) end
function Drill:score() return clamp(self.depth * (1 - self.damage) * (1 - self.neuro) * (0.6 + 0.4 * self:align()), 0, 1) end
function Drill:effects()
    return { neuro = clamp(self.neuro, 0, 1), tissue = clamp(self.damage + 0.4 * (1 - self:align()), 0, 1) }
end

-- ============================================================= clot (P14 hematoma evacuation)
-- Through the opening, a clot (dark red) sits on the brain (pink). Hold to
-- suction at the pointer: the clot comes away, but suction on brain where
-- there is no clot injures it. Suction makes the field bleed and fill with
-- blood -- you can no longer see the clot's edge; let go for a moment and
-- the irrigation clears it again.
local Clot = kind("clot")
function Clot:init()
    local K = self:K() * self:toolK(0.35)
    self.limit = (22000 + 6000 * (self.p.skill or 0)) * self:timeK()
    self.radius = 18 * K
    self.bits = {}
    local cu, cv = 0.5, 0.5
    for _ = 1, 70 do
        local a = rndf() * 6.283
        local d = math.sqrt(rndf()) * 0.24
        self.bits[#self.bits + 1] = { u = cu + math.cos(a) * d * 1.3, v = cv + math.sin(a) * d, alive = true, s = 10 + rnd(8) }
    end
    self.total = #self.bits
    self.removed, self.neuro, self.blood, self.holding = 0, 0, 0, false
end
function Clot:update(ms)
    self:tick(ms)
    if self.done then return end
    local dt = ms / 1000
    if self.holding and self.box and self.cx then
        G.sfx("Suction", 300)
        self.blood = clamp(self.blood + dt * 0.35, 0, 1)
        local x, y, w, h = unpack(self.box)
        local any = false
        for _, b in ipairs(self.bits) do
            if b.alive then
                local bx, by = x + b.u * w, y + b.v * h
                if (bx - self.cx) ^ 2 + (by - self.cy) ^ 2 <= (self.radius + b.s / 2) ^ 2 then
                    any = true
                    if rndf() < dt * 5 then b.alive = false; self.removed = self.removed + 1; self:burst("blood", bx, by, 1) end
                end
            end
        end
        if not any then
            self.neuro = clamp(self.neuro + dt * 0.18, 0, 1)
            if not self.lastHurt or self.t - self.lastHurt > 700 then
                self:hurtAt(self.cx, self.cy, 0.5)
                self:say(T("UI_HomeMedic_Surg_G_Brain", "That is brain!"), self.cx, self.cy - 20, { 1, 0.4, 0.3 })
            end
        end
    else
        self.blood = clamp(self.blood - dt * 0.6, 0, 1)
    end
    if self.removed >= self.total then self.done = true end
end
function Clot:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:field(ui, x, y, w, h, "organ_bed")
    for _, b in ipairs(self.bits) do
        if b.alive then img(ui, "clot", x + b.u * w - b.s / 2, y + b.v * h - b.s / 2, b.s, b.s, 1, 0.35, 0.03, 0.06) end
    end
    -- fresh bleeding hides the field
    if self.blood > 0.02 then ui:drawRect(x + 14, y + 14, w - 28, h - 28, 0.8 * self.blood, 0.45, 0.02, 0.03) end
    if self.cx then ring(ui, self.cx, self.cy, self.radius, 1, 0.4, 1, 1, 1) end
    self:lamp(ui)
    self:drawParticles(ui)
    self:drawSays(ui)
    self:drawTool(ui, "suction")
end
function Clot:mouseMove(mx, my) self:track(mx, my) end
function Clot:mouseDown(mx, my) self:track(mx, my); if not self.done then self.holding = true end end
function Clot:mouseUp() self.holding = false end
function Clot:score() return clamp(self.removed / self.total - 1.2 * self.neuro, 0, 1) end
function Clot:effects() return { residual = clamp(1 - self.removed / self.total, 0, 1), neuro = clamp(self.neuro, 0, 1) } end

-- ============================================================= organ (P15 organ repair)
-- The damaged organ: TEARS (dark lines) are closed with stitches along them,
-- DEAD tissue (grey patches) is resected; healthy tissue must stay. Pick
-- the instrument with the buttons (or right click to switch): Suture or
-- Resect. Resecting healthy tissue, or a tear, loses organ function;
-- unrepaired tears keep bleeding.
local Organ = kind("organ")
function Organ:init()
    local K = self:K() * self:toolK(0.35)
    self.limit = (26000 + 8000 * (self.p.skill or 0)) * self:timeK()
    self.tol = 14 * K
    self.tears, self.dead = {}, {}
    for i = 1, 2 do
        local u0, v0 = 0.25 + rndf() * 0.45, 0.3 + (i - 1) * 0.35 + rndf() * 0.08
        local t = { pts = {}, next = 1 }
        for k = 0, 3 do t.pts[#t.pts + 1] = { u = u0 + k * 0.05, v = v0 + (rndf() - 0.5) * 0.04 } end
        self.tears[#self.tears + 1] = t
    end
    for _ = 1, 3 do
        self.dead[#self.dead + 1] = { u = 0.2 + rndf() * 0.6, v = 0.2 + rndf() * 0.6, r = 0.05 + rndf() * 0.02, gone = false }
    end
    self.mode = "suture"
    self.wrong, self.healthyCut = 0, 0
end
function Organ:update(ms) self:tick(ms) end
function Organ:counts()
    local need, done = 0, 0
    for _, t in ipairs(self.tears) do need = need + #t.pts; done = done + (t.next - 1) end
    for _, d in ipairs(self.dead) do need = need + 1; if d.gone then done = done + 1 end end
    return need, done
end
function Organ:render(ui, x, y, w, h)
    self.box = { x, y, w, h }
    self:field(ui, x, y, w, h)
    self:bed(ui, x + w * 0.06, y + h * 0.06, w * 0.88, h * 0.80, true)
    local sx, sy = self:sway(4)
    for _, d in ipairs(self.dead) do
        local cx, cy = x + d.u * w + sx, y + d.v * h + sy
        if d.gone then img(ui, "raw_patch", cx - d.r * w, cy - d.r * w, d.r * w * 2, d.r * w * 2, 0.85)
        else img(ui, "necro_patch", cx - d.r * w, cy - d.r * w, d.r * w * 2, d.r * w * 2, 1, 0.65, 0.62, 0.62) end
    end
    for _, t in ipairs(self.tears) do
        for k = 1, #t.pts - 1 do
            local a, b = t.pts[k], t.pts[k + 1]
            local closed = k < t.next - 1
            strip(ui, "wound", x + a.u * w + sx, y + a.v * h + sy, x + b.u * w + sx, y + b.v * h + sy, closed and 4 or 12, 1)
        end
        for k, p in ipairs(t.pts) do
            local px, py = x + p.u * w + sx, y + p.v * h + sy
            if k < t.next then disc(ui, px, py, 3.5, 1, 0.10, 0.16, 0.38)
            elseif k == t.next and self.mode == "suture" then ring(ui, px, py, self.tol, 2, 0.85, 0.3, 1, 0.4) end
        end
    end
    self:lamp(ui)
    self:drawParticles(ui)
    self:button(ui, "suture", x + 16, y + h - 40, 110, 26, T("UI_HomeMedic_Surg_G_ModeSuture", "Suture"), self.mode == "suture", { 0.3, 0.8, 1 })
    self:button(ui, "resect", x + 136, y + h - 40, 110, 26, T("UI_HomeMedic_Surg_G_ModeResect", "Resect"), self.mode == "resect", { 1, 0.55, 0.25 })
    self:drawSays(ui)
    self:drawTool(ui, self.mode == "suture" and "needle" or "scalpel")
end
function Organ:mouseMove(mx, my) self:track(mx, my) end
function Organ:rightDown(mx, my) self.mode = (self.mode == "suture") and "resect" or "suture"; G.sfx("Clamp", 60) end
function Organ:mouseDown(mx, my)
    self:track(mx, my)
    if self.done or not self.box then return end
    local btn = self:hitButton(mx, my)
    if btn then self.mode = btn; G.sfx("Clamp", 60); return end
    local x, y, w, h = unpack(self.box)
    local sx, sy = self:sway(4)
    if self.mode == "suture" then
        for _, t in ipairs(self.tears) do
            local p = t.pts[t.next]
            if p and (mx - (x + p.u * w + sx)) ^ 2 + (my - (y + p.v * h + sy)) ^ 2 <= self.tol ^ 2 then
                t.next = t.next + 1
                G.sfx("Stitch")
                break
            end
        end
    else
        local hit = false
        for _, d in ipairs(self.dead) do
            if not d.gone and (mx - (x + d.u * w + sx)) ^ 2 + (my - (y + d.v * h + sy)) ^ 2 <= (d.r * w) ^ 2 then
                d.gone, hit = true, true
                G.sfx("Cut")
                self:burst("dust", mx, my, 4)
                break
            end
        end
        if not hit then
            -- healthy organ (or a tear) cut away
            self.healthyCut = self.healthyCut + 1
            self:hurtAt(mx, my, 0.6)
            self:say(T("UI_HomeMedic_Surg_G_Healthy", "Healthy tissue!"), mx, my - 20, { 1, 0.4, 0.3 })
        end
    end
    local need, done = self:counts()
    if done >= need then self.done = true end
end
function Organ:tearsLeft()
    local left, tot = 0, 0
    for _, t in ipairs(self.tears) do tot = tot + #t.pts; left = left + (#t.pts - (t.next - 1)) end
    return tot > 0 and left / tot or 0
end
function Organ:score()
    local need, done = self:counts()
    return clamp(done / need - 0.12 * self.healthyCut, 0, 1)
end
function Organ:effects()
    local need, done = self:counts()
    return { organ = clamp(1 - done / need + 0.12 * self.healthyCut, 0, 1), bleed = clamp(self:tearsLeft(), 0, 1) }
end

return G

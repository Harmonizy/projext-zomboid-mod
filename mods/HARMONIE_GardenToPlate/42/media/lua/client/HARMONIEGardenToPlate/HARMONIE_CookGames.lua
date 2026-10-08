--[[
    HARMONIE - From Garden to Plate: the cooking minigames (client).
    Written for this mod (the same idea as The Way To Attack's procedure
    games, nothing copied); the scene art is this mod's own
    (tools/gen_cook_art.py). One modal panel, one simple action per step:

      timing  chop / slice / mince / trim / core -- the knife sweeps over
              the board, click on each cut line
      ring    knead / pound / crack / toss -- click when the ring closes
      scrub   wash / scale / peel / spread -- rub over the spots (peel in
              order around the food; spread covers the toast)
      lane    grate / zest / roll -- full strokes up and down the lane
      circle  stir / whisk / fold / grind -- circle at the right speed
      press   mash -- press every lump flat
      fill    season / measure -- hold to pour, let go in the green band
      watch   steep / flip -- wait, click when it is just right

    0.13.0 (owner: "มินิเกมให้ใส่ใจรายละเอียดและมีความสวยงาม ... texture ...
    ไม่ต้องมีขั้นตอนซับซ้อน ... รูปบนเมาส์ก็เอาให้ตรงกับของที่ใช้จริง"): the
    mouse carries the real thing in use -- the knife, spoon or fork that
    was found (its own item picture), the food being washed or grated, the
    seasoning being shaken, the pan being tossed, or a bare hand.

    The result is a word, as in The Way To Attack: Excellent (0.85+),
    Good (0.6+), Bad (0.3+), else Miss (do it again). Harder at a low
    Cooking level, with an ok / makeshift tool or bare hands, easier with
    a cutting board, bowl or rolling pin at hand (K.difficulty).
]]--

require "ISUI/ISPanel"
require "HARMONIEGardenToPlate/HARMONIE_CookCore"
require "HARMONIEGardenToPlate/HARMONIE_CookFX"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.CookGames = HARMONIE_GTP.CookGames or {}
local G = HARMONIE_GTP.CookGames
local K = HARMONIE_GTP.Cook
local FX = HARMONIE_GTP.CookFX
local log = K.log

local W, H = 600, 470
local PX, PY, PW, PH = 20, 78, 560, 290

local C = {
    bg = { 0.012, 0.04, 0.018 }, panel = { 0.025, 0.08, 0.035 }, border = { 0.32, 0.76, 0.40 }, accent = { 0.50, 0.90, 0.52 },
    text = { 0.94, 1.0, 0.94 }, dim = { 0.66, 0.82, 0.68 }, good = { 0.45, 0.92, 0.48 }, bad = { 1.0, 0.42, 0.38 }, warn = { 1.0, 0.82, 0.32 },
    metal = { 0.72, 0.74, 0.78 }, water = { 0.35, 0.62, 0.92 }, dirt = { 0.42, 0.30, 0.16 },
}
-- what is inside the pot / bowl / mortar / mug, by step and dish family
local FILL = {
    soup = { 0.82, 0.56, 0.22 }, stew = { 0.52, 0.28, 0.12 }, pasta = { 0.90, 0.82, 0.58 }, rice = { 0.95, 0.94, 0.86 },
    oatmeal = { 0.86, 0.76, 0.56 }, drink = { 0.47, 0.27, 0.13 }, stirfry = { 0.60, 0.70, 0.30 },
    whisk = { 0.98, 0.84, 0.36 }, fold = { 0.96, 0.88, 0.70 }, grind = { 0.42, 0.56, 0.24 }, mash = { 0.94, 0.86, 0.58 },
}

local function T(key, ...)
    local ok, s = pcall(getText, key, ...)
    return ok and s or key
end
local function now() return getTimestampMs and getTimestampMs() or 0 end
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local function dist(x1, y1, x2, y2) local dx, dy = x2 - x1, y2 - y1 return math.sqrt(dx * dx + dy * dy) end

local TEX = {}
local function art(name)
    if TEX[name] == nil then
        local ok, t = pcall(getTexture, "media/textures/GTP_UI/cookgame_" .. name .. ".png")
        TEX[name] = (ok and t) or false
        if not TEX[name] then K.logOnce("art:" .. name, "minigame picture cookgame_%s.png missing -- drawn plain", name) end
    end
    return TEX[name] or nil
end

GTPCookGamePanel = ISPanel:derive("GTPCookGamePanel")
local P = GTPCookGamePanel

-- ------------------------------------------------------------------ open
function G.busy() return G.instance ~= nil end

function G.play(player, pid, opts, onWord)
    if G.instance then return false end
    local proc = K.PROCS[pid]
    if not proc then log("minigame for unknown step %s", tostring(pid)); onWord("Good"); return true end
    local core = getCore()
    local x = math.floor((core:getScreenWidth() - W) / 2)
    local y = math.floor((core:getScreenHeight() - H) / 2)
    local o = ISPanel:new(x, y, W, H)
    setmetatable(o, P)
    P.__index = P
    o.player, o.pid, o.proc, o.onWord = player, pid, proc, onWord
    o.kind, o.variant = proc.game, proc.variant
    o.opts = opts or {}
    o.d = clamp(tonumber(o.opts.difficulty) or 0.5, 0.05, 1)
    o.background = false
    o.moveWithMouse = false
    o.q = 1
    o.flashes = {}
    o.fxNext = {}
    o.started = now()
    o.last = o.started
    local ok, err = pcall(function()
        o:initialise()
        o:instantiate()
        o:addToUIManager()
        o:setAlwaysOnTop(true)
        o:setWantKeyEvents(true)
        o:bringToTop()
        o:setup()
    end)
    if not ok then
        log("minigame %s failed to open (%s) -- scored Good", pid, tostring(err))
        pcall(function() o:removeFromUIManager() end)
        onWord("Good")
        return true
    end
    G.instance = o
    o:speak("Tip_" .. pid, C.text, true)
    log("minigame %s (%s/%s) started, difficulty %.2f, cursor %s", pid, o.kind, o.variant, o.d,
        o.opts.cursor and "item" or (o.opts.bare and "bare hand" or tostring(proc.cursor)))
    return true
end

function G.close()
    if G.instance then G.instance:finish(nil, true) end
end

-- tolerance factor: 1.4 at the easiest, 0.45 at the hardest
function P:tol() return 1.45 - self.d end

-- ------------------------------------------------------------------ setup
local SWEEP = { chop = { 5, 240, 14 }, slice = { 7, 250, 11 }, mince = { 8, 330, 14 }, trim = { 4, 190, 9 }, core = { 3, 180, 10 } }
local RING = { knead = { 6, 1100 }, pound = { 5, 850 }, crack = { 2, 1000 }, toss = { 4, 950 } }
local LANE = { grate = 9, zest = 6, roll = 6 }
local CIRCLE = { stir = { 2.2, 6.0, 5200, 128 }, whisk = { 8.5, 17, 4200, 112 }, fold = { 1.2, 3.4, 4600, 112 }, grind = { 4.5, 10, 4200, 78 } }

function P:setup()
    local v = self.variant
    local cx, cy = PX + PW / 2, PY + PH / 2
    self.limit = 14000
    if self.kind == "timing" then
        local def = SWEEP[v] or SWEEP.chop
        local n = def[1]
        self.speed = def[2] * (0.8 + 0.4 * self.d)
        self.tolW = def[3] * self:tol()
        self.targets = {}
        local left, right = PX + 110, PX + PW - 110
        for i = 1, n do
            local tx = left + (right - left) * (i - 0.5) / n + ZombRand(-10, 11)
            self.targets[i] = { x = tx, hit = false, score = 0 }
        end
        self.mx, self.dir = left - 40, 1
        self.limit = 9000 + n * 900
    elseif self.kind == "ring" then
        local def = RING[v] or RING.knead
        self.beats, self.beat, self.ring = def[1], 0, 0
        self.period = def[2] - 280 * self.d
        self.limit = self.beats * self.period + 3000
        self.scores = {}
        self.hop = 0
    elseif self.kind == "scrub" then
        self.spots = {}
        local n = ({ wash = 7, scale = 10, peel = 9, spread = 9 })[v] or 7
        for i = 1, n do
            local sx, sy
            if v == "peel" then
                local a = (i / n) * math.pi * 2
                sx, sy = cx + math.cos(a) * 120, cy + math.sin(a) * 78
            elseif v == "spread" then
                local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
                sx, sy = cx - 54 + col * 54, cy - 46 + row * 46
            elseif v == "scale" then
                local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
                sx, sy = cx - 110 + col * 55, cy - 26 + row * 52
            else
                local a, r = ZombRand(0, 628) / 100, ZombRand(20, 90)
                sx, sy = cx + math.cos(a) * r * 1.3, cy + 14 + math.sin(a) * r * 0.75
            end
            self.spots[i] = { x = sx, y = sy, dirt = 1, order = i }
        end
        self.nextSpot = 1
        self.radius = (v == "spread" and 30 or 26) * self:tol()
        self.limit = v == "peel" and 15000 or 13000
    elseif self.kind == "lane" then
        self.lane = { x = cx - 50, y = PY + 24, w = 100, h = PH - 48 }
        if v == "roll" then self.lane = { x = cx - 120, y = PY + 30, w = 240, h = PH - 60 } end
        self.strokes, self.need, self.phaseDown = 0, LANE[v] or 8, true
        self.limit = 12000
    elseif self.kind == "circle" then
        local def = CIRCLE[v] or CIRCLE.stir
        self.cx, self.cy = cx, cy + 10
        self.rOut = def[4]
        local widen = (self:tol() - 1) * (def[2] - def[1]) * 0.35
        self.band = { def[1] - widen, def[2] + widen }
        self.needMs = def[3]
        self.progress, self.av, self.lastA, self.swirl = 0, 0, nil, 0
        self.limit = 16000
    elseif self.kind == "press" then
        self.lumps = {}
        local n = 6
        for i = 1, n do
            local a = (i / n) * math.pi * 2 + ZombRand(0, 40) / 100
            local r = ZombRand(20, 70)
            self.lumps[i] = { x = cx + math.cos(a) * r, y = cy + math.sin(a) * r * 0.9, left = 3, size = ZombRand(16, 24) }
        end
        self.pressR = 22 * self:tol()
        self.limit = 12000
    elseif self.kind == "fill" then
        self.rounds = v == "season" and 3 or 1
        self.round, self.level, self.vel, self.scores = 1, 0, 0, {}
        self.bandW = (v == "season" and 0.10 or 0.14) * self:tol()
        self:newBand()
        self.limit = v == "season" and 14000 or 9000
    elseif self.kind == "watch" then
        self.rounds = v == "flip" and 2 or 1
        self.round, self.scores = 1, {}
        self.bandW = 0.16 * self:tol()
        self:newWatch()
        self.limit = 16000
    end
end

function P:newBand()
    local c = 0.35 + ZombRand(0, 40) / 100
    self.band2 = { c - self.bandW / 2, c + self.bandW / 2 }
    self.level, self.vel, self.pouring = 0, 0, false
end

function P:newWatch()
    local c = 0.62 + ZombRand(0, 16) / 100
    self.band2 = { c - self.bandW / 2, c + self.bandW / 2 }
    self.level = 0
    -- a little faster when harder, never the same twice
    self.rate = (0.16 + 0.10 * self.d) * (0.9 + ZombRand(0, 20) / 100)
end

-- ------------------------------------------------------------------ helpers
-- 0.13.1: what used to float up as a word at the mouse is now said by the
-- cook in the speech bubble (owner: "เปลี่ยนเป็นบทพูดในกล่องข้อความเด้งขึ้นมา")
function P:flash(key, col)
    self:speak("Ev_" .. key, col)
end

-- a line in the bubble. A new one waits until the last has been up a
-- moment, unless it matters more (force: the start tip, the end word)
function P:speak(key, col, force)
    local t = now()
    local b = self.bubble
    if b and not force and t - b.at < 750 then return end
    local text = FX.line(key)
    if not text then return end
    self.bubble = { text = text, col = col or C.text, at = t, key = key }
    log("minigame %s says [%s]: %s", self.pid, key, text)
end

-- every = false: each slip costs (a click); else at most once per 0.6 s
-- (something held or dragged that keeps happening every frame)
function P:spend(amount, key, every)
    local t = now()
    self.lastSpend = self.lastSpend or {}
    if every ~= false and self.lastSpend[key] and t - self.lastSpend[key] < 600 then return end
    self.lastSpend[key] = t
    self.q = clamp(self.q - amount, 0, 1)
    self:flash(key, C.bad)
    FX.play("Slip")
end


function P:wordFor(q)
    if q >= 0.85 then return "Excellent" elseif q >= 0.6 then return "Good" elseif q >= 0.3 then return "Bad" end
    return "Miss"
end

-- end: word shown a moment, then handed back. cancelled -> nil (nothing)
function P:finish(word, cancelled)
    if self.done then return end
    self.done = true
    self.result = cancelled and nil or word
    self.endAt = now()
    if word and not cancelled then
        local col = ({ Excellent = C.good, Good = C.accent, Bad = C.warn, Miss = C.bad })[word]
        self:speak("End_" .. word, col, true)
        FX.play(word)
    end
    log("minigame %s ended: %s (quality %.2f)", self.pid, cancelled and "cancelled" or tostring(word), self.q)
    if cancelled then self:deliver() end
end

function P:deliver()
    if self.delivered then return end
    self.delivered = true
    pcall(function() self:setVisible(false) end)
    pcall(function() self:removeFromUIManager() end)
    if G.instance == self then G.instance = nil end
    local cb, w = self.onWord, self.result
    self.onWord = nil
    if cb then
        local ok, err = pcall(cb, w)
        if not ok then log("minigame result handler FAILED: %s", tostring(err)) end
    end
end

-- ------------------------------------------------------------------ update
function P:tick()
    local t = now()
    local dt = math.min(100, t - self.last)
    self.last = t
    if self.done then
        if t - self.endAt > 1100 then self:deliver() end
        return
    end
    if t - self.started > self.limit then return self:timeout() end
    local mx, my = self:getMouseX(), self:getMouseY()
    local held = self.held
    local k = self.kind
    if k == "timing" then
        self.mx = self.mx + self.dir * self.speed * dt / 1000
        local left, right = PX + 60, PX + PW - 60
        if self.mx > right then self.mx, self.dir = right, -1 elseif self.mx < left then self.mx, self.dir = left, 1 end
    elseif k == "ring" then
        self.ring = ((t - self.started) % self.period) / self.period
        self.hop = math.max(0, self.hop - dt / 300)
        local b = math.floor((t - self.started) / self.period)
        if b > self.beat then
            if not self.clickedThisBeat and self.beat > 0 then self.scores[#self.scores + 1] = 0; self:spend(0.08, "Late") end
            self.beat = b
            self.clickedThisBeat = false
            if self.beat > self.beats then return self:complete() end
        end
    elseif k == "lane" then
        if held and self.variant == "roll" and self.lastLaneY and math.abs(my - self.lastLaneY) > 1 then FX.keep(self, "Roll") end
        self.lastLaneY = my
        if held then
            local L = self.lane
            if self.variant ~= "roll" and (mx < L.x - 6 or mx > L.x + L.w + 6) then self:spend(0.1, "Knuckle") end
            if self.phaseDown and my > L.y + L.h - 18 then self.phaseDown = false
            elseif not self.phaseDown and my < L.y + 18 then
                self.phaseDown = true
                self.strokes = self.strokes + 1
                FX.play(self.variant == "roll" and "Thump" or "Scrape")
                if self.strokes >= self.need then return self:complete() end
            end
        end
    elseif k == "scrub" then
        if held and self.prevX then
            local moved = dist(self.prevX, self.prevY, mx, my)
            for _, s in ipairs(self.spots) do
                if s.dirt > 0 and dist(mx, my, s.x, s.y) < self.radius then
                    if self.variant == "peel" and s.order ~= self.nextSpot then
                        self:spend(0.08, "Deep")
                    else
                        s.dirt = math.max(0, s.dirt - moved / 160)
                        if moved > 0.5 then FX.keep(self, ({ wash = "Scrub", scale = "Scrape", peel = "Scrape", spread = "Spread" })[self.variant] or "Scrub") end
                        if s.dirt <= 0 then
                            if self.variant == "peel" then self.nextSpot = self.nextSpot + 1 end
                        end
                    end
                end
            end
            local left = 0
            for _, s in ipairs(self.spots) do if s.dirt > 0 then left = left + 1 end end
            if left == 0 then return self:complete() end
        end
        self.prevX, self.prevY = mx, my
    elseif k == "circle" then
        local r = dist(mx, my, self.cx, self.cy)
        local inRing = r > self.rOut * 0.2 and r < self.rOut
        if held and inRing then
            local a = atan2(my - self.cy, mx - self.cx)
            if self.lastA then
                local da = a - self.lastA
                if da > math.pi then da = da - 2 * math.pi elseif da < -math.pi then da = da + 2 * math.pi end
                local inst = math.abs(da) / math.max(1, dt) * 1000
                self.av = self.av * 0.85 + inst * 0.15
            end
            self.lastA = a
        else
            self.lastA = nil
            self.av = self.av * 0.9
        end
        self.swirl = self.swirl + self.av * dt / 1000
        if held and self.av > self.band[1] * 0.5 then
            FX.keep(self, ({ stir = "Stir", fold = "Stir", whisk = "Whisk", grind = "Grind" })[self.variant] or "Stir")
        end
        if self.av >= self.band[1] and self.av <= self.band[2] then
            self.progress = self.progress + dt / self.needMs
            if self.progress >= 1 then return self:complete() end
        elseif self.av > self.band[2] + 1 then
            self:spend(0.06, self.variant == "grind" and "Spill" or "Splash")
        end
    elseif k == "fill" then
        if self.pouring then
            FX.keep(self, "Pour")
            self.vel = self.vel + dt / 1000 * (self.variant == "measure" and 1.2 or 0.8) * (0.8 + 0.4 * self.d)
            self.level = self.level + self.vel * dt / 1000
            if self.level >= 1 then self:releasePour() end
        end
    elseif k == "watch" then
        FX.keep(self, self.variant == "flip" and "Sizzle" or "Bubble")
        self.level = self.level + self.rate * dt / 1000
        if self.level >= 1.08 then
            self.scores[#self.scores + 1] = 0
            self:flash((self.variant == "flip" and "Burnt" or "Bitter"), C.bad)
            self:nextWatch()
        end
    end
end

function P:timeout()
    log("minigame %s timed out", self.pid)
    -- what was reached counts, what was not is a Miss
    if self.kind == "timing" and self.targets then
        local hit = 0
        for _, t in ipairs(self.targets) do if t.hit then hit = hit + 1 end end
        if hit >= #self.targets then return self:complete() end
    end
    self:flash(("Time"), C.bad)
    self:finish("Miss")
end

function P:complete()
    local q = self.q
    local k = self.kind
    if k == "timing" or k == "ring" then
        local sum, n = 0, 0
        for _, t in ipairs(self.targets or self.scores) do sum = sum + (type(t) == "table" and t.score or t); n = n + 1 end
        q = q * (n > 0 and sum / n or 0)
    elseif k == "scrub" or k == "circle" or k == "lane" or k == "press" then
        local used = (now() - self.started) / self.limit
        q = q * (1 - 0.45 * clamp(used, 0, 1))
    elseif k == "fill" or k == "watch" then
        local sum = 0
        for _, s in ipairs(self.scores) do sum = sum + s end
        q = q * (#self.scores > 0 and sum / #self.scores or 0)
    end
    self.q = clamp(q, 0, 1)
    local word = self:wordFor(self.q)
    self:finish(word)
end

-- ------------------------------------------------------------------ input
function P:onMouseDown(x, y)
    if self.cancelRect and x >= self.cancelRect.x and x <= self.cancelRect.x + self.cancelRect.w
            and y >= self.cancelRect.y and y <= self.cancelRect.y + self.cancelRect.h then
        self:finish(nil, true)
        return true
    end
    if self.done then return true end
    self.held = true
    local k = self.kind
    if k == "ring" then
        if self.clickedThisBeat or self.beat < 1 then return true end
        self.clickedThisBeat = true
        -- best at the end of the beat, when the ring meets the target
        local off = math.min(math.abs(1 - self.ring), self.ring)
        local s = clamp(1 - off / (0.22 * self:tol()), 0, 1)
        self.scores[#self.scores + 1] = s
        self.hop = 1
        self:flash((s > 0.7 and "Nice" or (s > 0.2 and "Ok" or "Late")), s > 0.7 and C.good or (s > 0.2 and C.warn or C.bad))
        FX.play(({ knead = "Thump", pound = "Thump", crack = "Crack", toss = "Toss" })[self.variant] or "Thump")
    elseif k == "timing" then
        local best, bd
        for _, t in ipairs(self.targets) do
            if not t.hit then
                local d = math.abs(t.x - self.mx)
                if not bd or d < bd then best, bd = t, d end
            end
        end
        if best and bd <= self.tolW then
            best.hit = true
            best.score = clamp(1 - bd / self.tolW * 0.6, 0, 1)
            self:flash((best.score > 0.8 and "Nice" or "Ok"), best.score > 0.8 and C.good or C.warn)
            FX.play((self.variant == "slice" or self.variant == "core" or self.variant == "trim") and "Slice" or "Chop")
            local all = true
            for _, t in ipairs(self.targets) do if not t.hit then all = false end end
            if all then self:complete() end
        else
            self:spend(0.12, "Slip", false)
        end
    elseif k == "press" then
        local hit
        for _, l in ipairs(self.lumps) do
            if l.left > 0 and dist(x, y, l.x, l.y) < self.pressR + l.size * 0.5 then hit = l; break end
        end
        if hit then
            hit.left = hit.left - 1
            FX.play("Squish")
            local left = 0
            for _, l in ipairs(self.lumps) do left = left + l.left end
            if left == 0 then return self:complete() end
        else
            self:spend(0.08, "Splash", false)
        end
    elseif k == "fill" then
        self.pouring = true
    elseif k == "watch" then
        self:stopWatch()
    end
    return true
end

function P:stopWatch()
    local b = self.band2
    local s
    if self.level >= b[1] and self.level <= b[2] then
        local c = (b[1] + b[2]) / 2
        s = clamp(1 - math.abs(self.level - c) / (b[2] - b[1]) * 0.8, 0, 1)
        self:flash((s > 0.75 and "Nice" or "Ok"), s > 0.75 and C.good or C.warn)
    elseif self.level > b[2] then
        s = clamp(0.5 - (self.level - b[2]) * 3, 0, 0.5)
        self:flash((self.variant == "flip" and "Dark" or "Strong"), C.warn)
    else
        s = clamp(0.5 - (b[1] - self.level) * 3, 0, 0.5)
        self:flash((self.variant == "flip" and "Pale" or "Weak"), C.warn)
    end
    self.scores[#self.scores + 1] = s
    if self.variant == "flip" then FX.play("Toss") end
    self:nextWatch()
end

function P:nextWatch()
    if self.round >= self.rounds then return self:complete() end
    self.round = self.round + 1
    self:newWatch()
end

function P:releasePour()
    if not self.pouring then return end
    self.pouring = false
    local b = self.band2
    local s
    if self.level >= b[1] and self.level <= b[2] then
        local c = (b[1] + b[2]) / 2
        s = clamp(1 - math.abs(self.level - c) / (b[2] - b[1]) * 0.8, 0, 1)
        self:flash((s > 0.75 and "Nice" or "Ok"), s > 0.75 and C.good or C.warn)
    elseif self.level > b[2] then
        s = 0
        self:flash(("Over"), C.bad)
    else
        s = clamp(0.5 - (b[1] - self.level) * 3, 0, 0.5)
        self:flash(("Under"), C.warn)
    end
    self.scores[#self.scores + 1] = s
    if self.round >= self.rounds then return self:complete() end
    self.round = self.round + 1
    self:newBand()
end

function P:onMouseUp(x, y)
    self.held = false
    if self.kind == "fill" and not self.done then self:releasePour() end
    return true
end
function P:onMouseUpOutside(x, y) return self:onMouseUp(x, y) end
function P:onMouseMove() return true end
function P:onMouseMoveOutside() return true end
function P:onMouseWheel() return true end
function P:isKeyConsumed(key) return key == Keyboard.KEY_ESCAPE end
function P:onKeyRelease(key) if key == Keyboard.KEY_ESCAPE then self:finish(nil, true) end end

-- ------------------------------------------------------------------ drawing
function P:circle(cx, cy, r, a, col, seg, size)
    seg, size = seg or 48, size or 2
    for i = 0, seg - 1 do
        local t = i / seg * math.pi * 2
        self:drawRect(cx + math.cos(t) * r - size / 2, cy + math.sin(t) * r - size / 2, size, size, a, col[1], col[2], col[3])
    end
end

function P:disc(cx, cy, r, a, col)
    for yy = -r, r, 2 do
        local half = math.sqrt(math.max(0, r * r - yy * yy))
        self:drawRect(cx - half, cy + yy, half * 2, 2, a, col[1], col[2], col[3])
    end
end

function P:text(s, x, y, col, f, center)
    f = f or UIFont.Small
    if center then x = x - getTextManager():MeasureStringX(f, s) / 2 end
    self:drawText(s, x + 1, y + 1, 0, 0, 0, 0.8, f)
    self:drawText(s, x, y, col[1], col[2], col[3], 1, f)
end

-- a scene picture centred on (cx, cy) at its own size (scaled by k)
function P:pic(name, cx, cy, k, a)
    local t = art(name)
    if not t then return false end
    k = k or 1
    local w, h = t:getWidth() * k, t:getHeight() * k
    self:drawTextureScaled(t, cx - w / 2, cy - h / 2, w, h, a or 1, 1, 1, 1)
    return true
end

function P:food(cx, cy, size, a)
    local icon = self.opts.icon
    if icon then
        self:drawTextureScaled(icon, cx - size / 2, cy - size / 2, size, size, a or 1, 1, 1, 1)
    else
        self:disc(cx, cy, size * 0.4, a or 1, { 0.85, 0.45, 0.15 })
    end
end

-- the thing in the hand, drawn at the mouse: the real item (tool, food,
-- seasoning, pan) or a bare hand
function P:drawHeld(mx, my, size)
    size = size or 46
    local tex = self.opts.cursor
    if tex then
        -- the item's tip / edge sits on the pointer
        self:drawTextureScaled(tex, mx - size * 0.2, my - size * 0.8, size, size, 1, 1, 1, 1)
        return
    end
    if self.proc.cursor == "hand" or self.opts.bare then
        local h = art("hand")
        if h then self:drawTextureScaled(h, mx - 20, my - 34, 44, 44, 0.95, 1, 1, 1) end
    end
end

-- words / UTF-8 characters that fit `maxW` per line (Thai has no spaces
-- between words, so a too-long piece is cut between characters)
local function wrap(text, f, maxW)
    local tm = getTextManager()
    local function w(x) return tm:MeasureStringX(f, x) end
    local lines, cur = {}, ""
    for word in tostring(text):gmatch("%S+") do
        local try = cur == "" and word or (cur .. " " .. word)
        if w(try) <= maxW then
            cur = try
        else
            if cur ~= "" then lines[#lines + 1] = cur; cur = "" end
            if w(word) <= maxW then
                cur = word
            else
                -- UTF-8 characters by their lead byte (no patterns: the
                -- game's Lua is picky about byte escapes in patterns)
                local i, n = 1, #word
                while i <= n do
                    local b = string.byte(word, i)
                    local len = (b >= 240 and 4) or (b >= 224 and 3) or (b >= 192 and 2) or 1
                    local ch = string.sub(word, i, i + len - 1)
                    if w(cur .. ch) > maxW and cur ~= "" then lines[#lines + 1] = cur; cur = ch else cur = cur .. ch end
                    i = i + len
                end
            end
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    return lines
end
G.wrap = wrap

-- the cook (left of the header) and what they are saying, popping up
function P:drawBubble()
    local chef = art("chef")
    if chef then self:drawTextureScaled(chef, 10, 36, 42, 42, 1, 1, 1, 1) end
    local b = self.bubble
    if not b then return end
    local f = UIFont.Small
    local lh = getTextManager():getFontHeight(f)
    local bx, by = 62, 38
    local bw = W - 14 - bx
    if b.lines == nil or b.lineW ~= bw then b.lines, b.lineW = wrap(b.text, f, bw - 18), bw end
    local n = math.max(1, math.min(3, #b.lines))
    local bh = n * lh + 10
    local age = now() - b.at
    local pop = math.min(1, age / 140)
    local k = 0.82 + 0.18 * pop + (pop < 1 and 0 or 0)
    -- grows out of the cook's mouth (the left end)
    local w, h = bw * k, bh * k
    local y = by + (bh - h) / 2
    self:drawRect(bx + 3, y + 3, w, h, 0.35 * pop, 0, 0, 0)
    self:drawRect(bx, y, w, h, 0.97 * pop, 0.98, 0.97, 0.92)
    local col = b.col or C.text
    self:drawRectBorder(bx, y, w, h, pop, col[1] * 0.8, col[2] * 0.8, col[3] * 0.8)
    for i = 0, 5 do -- the tail towards the cook
        self:drawRect(bx - 6 + i, y + h / 2 - 3 + i * 0.5, 1, 6 - i, 0.97 * pop, 0.98, 0.97, 0.92)
    end
    if pop < 0.6 then return end
    for i = 1, n do
        local line = b.lines[i]
        if i == 3 and #b.lines > 3 then line = line .. " ..." end
        self:drawText(line, bx + 9, y + 5 + (i - 1) * lh, 0.12, 0.10, 0.08, 1, f)
    end
end

function P:prerender()
    pcall(function() self:tick() end)
    self:drawRect(0, 0, W, H, 0.97, C.bg[1], C.bg[2], C.bg[3])
    self:drawRectBorder(0, 0, W, H, 1, C.border[1], C.border[2], C.border[3])
    self:drawRect(1, 1, W - 2, 34, 0.95, 0.03, 0.12, 0.05)
    self:text(T("IGUI_GTPC_Proc_" .. self.pid), 14, 8, C.accent, UIFont.Medium)
    local counter = art("counter")
    if counter then
        self:drawTextureScaled(counter, PX, PY, PW, PH, 1, 1, 1, 1)
    else
        self:drawRect(PX, PY, PW, PH, 0.9, C.panel[1], C.panel[2], C.panel[3])
    end
    self:drawRectBorder(PX, PY, PW, PH, 0.8, 0.14, 0.36, 0.18)
end

function P:render()
    local ok, err = pcall(function() self:renderGame() end)
    if not ok then
        log("minigame %s draw error (%s) -- scored Good", self.pid, tostring(err))
        self.result = "Good"
        self.done = true
        self:deliver()
        return
    end
    -- bars
    local by = PY + PH + 14
    self:text(T("IGUI_GTPC_Game_Quality"), PX, by, C.dim)
    local bx, bw = PX + 110, 300
    self:drawRect(bx, by + 3, bw, 10, 0.9, 0.04, 0.12, 0.05)
    local qc = self.q > 0.85 and C.good or (self.q > 0.6 and C.accent or (self.q > 0.3 and C.warn or C.bad))
    self:drawRect(bx, by + 3, bw * self.q, 10, 1, qc[1], qc[2], qc[3])
    local t = math.max(0, 1 - (now() - self.started) / self.limit)
    if self.done then t = 0 end
    self:text(T("IGUI_GTPC_Game_Time"), PX, by + 22, C.dim)
    self:drawRect(bx, by + 25, bw, 10, 0.9, 0.04, 0.12, 0.05)
    self:drawRect(bx, by + 25, bw * t, 10, 1, C.water[1], C.water[2], C.water[3])
    -- cancel
    local cw, ch = 120, 30
    self.cancelRect = { x = W - cw - 20, y = H - ch - 16, w = cw, h = ch }
    local r = self.cancelRect
    self:drawRect(r.x, r.y, r.w, r.h, 0.9, 0.16, 0.05, 0.04)
    self:drawRectBorder(r.x, r.y, r.w, r.h, 1, C.bad[1], C.bad[2], C.bad[3])
    self:text(T("IGUI_GTPC_Game_Cancel"), r.x + r.w / 2, r.y + 7, C.text, UIFont.Small, true)
    -- the cook's speech bubble (on top of everything)
    local okB, errB = pcall(function() self:drawBubble() end)
    if not okB then K.logOnce("bubble", "speech bubble draw error: %s", tostring(errB)) end
    -- the word
    if self.done and self.result then
        local col = ({ Excellent = C.good, Good = C.accent, Bad = C.warn, Miss = C.bad })[self.result] or C.text
        self:drawRect(PX + 120, PY + PH / 2 - 34, PW - 240, 68, 0.92, 0.02, 0.06, 0.03)
        self:drawRectBorder(PX + 120, PY + PH / 2 - 34, PW - 240, 68, 1, col[1], col[2], col[3])
        self:text(T("IGUI_GTPC_Word_" .. self.result), PX + PW / 2, PY + PH / 2 - 14, col, UIFont.Large, true)
    end
end

local function fillCol(self)
    return FILL[self.variant] or FILL[self.opts.family or ""] or FILL.soup
end

function P:renderGame()
    local mx, my = self:getMouseX(), self:getMouseY()
    local cx, cy = PX + PW / 2, PY + PH / 2
    local k, v = self.kind, self.variant
    if k == "timing" then
        self:pic("board", cx, cy + 6)
        for i = -1, 1 do self:food(cx + i * 120, cy, 104) end
        for _, t in ipairs(self.targets) do
            local col = t.hit and C.good or C.warn
            for yy = cy - 58, cy + 56, 8 do self:drawRect(t.x - 1, yy, 2, 5, t.hit and 0.95 or 0.8, col[1], col[2], col[3]) end
            self:drawRect(t.x - self.tolW, cy + 66, self.tolW * 2, 3, 0.45, col[1], col[2], col[3])
            if t.hit then self:drawRect(t.x - 1, cy - 58, 2, 114, 0.35, 0.1, 0.06, 0.03) end
        end
        -- the real knife sweeps over the board, its edge on the dotted line
        local kx = self.mx
        for yy = cy - 50, cy + 66, 6 do self:drawRect(kx - 0.5, yy, 1, 3, 0.45, 1, 1, 1) end
        local tex = self.opts.tool or self.opts.cursor
        if tex then
            self:drawTextureScaled(tex, kx - 32, cy - 128, 64, 64, 1, 1, 1, 1)
        else
            self:drawRect(kx - 2, cy - 110, 4, 60, 1, C.metal[1], C.metal[2], C.metal[3])
            self:drawRect(kx - 4, cy - 132, 8, 24, 1, 0.15, 0.10, 0.06)
        end
    elseif k == "ring" then
        local tx, ty = cx, cy + 16
        if v == "knead" then
            self:pic("dough", tx, ty, 0.9 + 0.08 * self.hop)
        elseif v == "pound" then
            self:pic("board", tx, ty, 0.85)
            self:food(tx, ty - 4 * self.hop, 120 + 20 * self.hop)
        elseif v == "crack" then
            self:disc(tx, ty, 104, 1, { 0.98, 0.88, 0.48 })
            self:pic("bowl", tx, ty, 0.8)
        elseif v == "toss" then
            self:disc(cx - 50, ty, 104, 1, { 0.18, 0.18, 0.20 })
            for i = 0, 4 do
                local a = i * 1.3
                self:food(cx - 50 + math.cos(a) * 40, ty + math.sin(a) * 34 - 40 * self.hop * (0.6 + 0.1 * i), 48)
            end
            self:pic("pan", cx, ty, 0.82)
        end
        local r0 = v == "crack" and 40 or 74
        -- the ring closes from the edge of the counter onto the target
        local r = r0 + (1 - self.ring) * (PH / 2 - 14 - r0)
        -- dark colours: they sit on the light worktop
        self:circle(tx, ty, r0, 0.95, { 0.85, 0.45, 0.05 }, 64, 4)
        self:circle(tx, ty, r, 1, { 0.08, 0.45, 0.16 }, 80, 4)
        self:text(T("IGUI_GTPC_Game_Beat", math.min(self.beat, self.beats), self.beats), cx, PY + 10, C.text, UIFont.Small, true)
        self:drawHeld(mx, my, 46)
    elseif k == "scrub" then
        if v == "wash" then
            self:pic("basin", cx, cy + 10)
            self:food(cx, cy + 14, 170)
            for i = 1, 6 do self:drawRect(mx - 18 + i * 5, my - 22 - (now() / 6 + i * 13) % 20, 2, 4, 0.8, 0.85, 0.93, 1) end
        elseif v == "spread" then
            self:pic("toast", cx, cy)
        else
            self:pic("board", cx, cy + 6)
            self:food(cx, cy, v == "scale" and 230 or 190)
        end
        for _, s in ipairs(self.spots) do
            if v == "spread" then
                -- the spread goes on where it is rubbed
                local covered = 1 - s.dirt
                if covered > 0 then self:disc(s.x, s.y, 10 + 20 * covered, 0.85, { 0.98, 0.92, 0.55 }) end
                if s.dirt > 0 then self:circle(s.x, s.y, 24, 0.5, C.warn, 28, 2) end
            elseif s.dirt > 0 then
                local col = (v == "peel" and { 0.55, 0.36, 0.14 }) or (v == "scale" and { 0.80, 0.84, 0.88 }) or C.dirt
                self:disc(s.x, s.y, 8 + 13 * s.dirt, 0.55 + 0.4 * s.dirt, col)
                if v == "peel" and s.order == self.nextSpot then self:circle(s.x, s.y, 26, 1, C.accent, 36, 2) end
            end
        end
        self:circle(mx, my, self.radius, 0.45, v == "wash" and C.water or C.text, 32, 2)
        self:drawHeld(mx, my, v == "wash" and 54 or 46)
    elseif k == "lane" then
        local L = self.lane
        if v == "roll" then
            local grow = math.min(1, self.strokes / self.need)
            self:pic("dough", cx, cy, 0.8 + 0.5 * grow)
            self:drawRectBorder(L.x, L.y, L.w, L.h, 0.35, 1, 1, 1)
        else
            -- the real grater, or the makeshift tool standing in for it
            if not self.opts.tool or self.opts.toolIsGrater ~= false then
                self:pic("grater", cx, cy)
            end
            if self.opts.tool and self.opts.toolIsGrater == false then
                self:drawTextureScaled(self.opts.tool, cx - 60, cy - 60, 120, 120, 1, 1, 1, 1)
            end
            self:drawRect(L.x - 6, L.y, 6, L.h, 0.35, C.bad[1], C.bad[2], C.bad[3])
            self:drawRect(L.x + L.w, L.y, 6, L.h, 0.35, C.bad[1], C.bad[2], C.bad[3])
            local pile = math.min(1, self.strokes / self.need)
            local col = v == "zest" and { 1.0, 0.82, 0.25 } or { 0.95, 0.78, 0.30 }
            for i = 0, 7 do
                self:disc(L.x + L.w + 70 + (i % 4) * 12, L.y + L.h - 12 - math.floor(i / 4) * 10, 3 + 6 * pile, pile > i / 8 and 1 or 0.1, col)
            end
        end
        local arrow = self.phaseDown and "v" or "^"
        self:text(arrow, L.x - 30, self.phaseDown and (L.y + L.h - 30) or (L.y + 10), C.accent, UIFont.Large, true)
        self:text(T("IGUI_GTPC_Game_Strokes", self.strokes, self.need), cx, PY + 8, C.text, UIFont.Small, true)
        self:drawHeld(mx, my, v == "roll" and 64 or 56)
    elseif k == "circle" then
        local col = fillCol(self)
        local inner = self.rOut * (v == "grind" and 0.82 or 0.9)
        self:disc(self.cx, self.cy, inner, 1, col)
        -- swirl of the contents, following the stirring
        for i = 0, 7 do
            local a = self.swirl + i * math.pi / 4
            local rr = inner * (0.35 + 0.08 * (i % 3))
            self:disc(self.cx + math.cos(a) * rr, self.cy + math.sin(a) * rr, 5, 0.35, { 1, 1, 1 })
        end
        local pic = (v == "grind" and "mortar") or ((v == "whisk" or v == "fold") and "bowl") or (self.opts.family == "drink" and "mug") or "pot"
        self:pic(pic, self.cx + (pic == "mug" and 30 or 0), self.cy, (self.rOut + 14) / (pic == "mortar" and 112 or 128))
        local barX, barY, barW = PX + 18, PY + 20, 22
        local maxV = self.band[2] * 1.6
        self:drawRect(barX, barY, barW, PH - 40, 0.9, 0.04, 0.12, 0.05)
        local b1 = barY + (PH - 40) * (1 - self.band[2] / maxV)
        local b2 = barY + (PH - 40) * (1 - self.band[1] / maxV)
        self:drawRect(barX, b1, barW, b2 - b1, 0.6, C.good[1], C.good[2], C.good[3])
        local vy = barY + (PH - 40) * (1 - clamp(self.av / maxV, 0, 1))
        self:drawRect(barX - 4, vy - 2, barW + 8, 4, 1, C.text[1], C.text[2], C.text[3])
        self:drawRect(PX + PW - 40, PY + 20, 22, PH - 40, 0.9, 0.04, 0.12, 0.05)
        local ph = (PH - 40) * clamp(self.progress, 0, 1)
        self:drawRect(PX + PW - 40, PY + PH - 20 - ph, 22, ph, 1, C.accent[1], C.accent[2], C.accent[3])
        self:text(T(self.av > self.band[2] and "IGUI_GTPC_Game_Faster0" or (self.av < self.band[1] and "IGUI_GTPC_Game_Faster" or "IGUI_GTPC_Game_Keep")),
            self.cx, PY + 8, self.av > self.band[2] and C.bad or C.text, UIFont.Small, true)
        self:drawHeld(mx, my, 50)
    elseif k == "press" then
        self:disc(cx, cy, 116, 1, { 0.96, 0.93, 0.84 })
        for _, l in ipairs(self.lumps) do
            local f = l.left / 3
            local col = FILL.mash
            if l.left > 0 then
                self:disc(l.x, l.y, l.size * (0.55 + 0.45 * f), 1, col)
                self:disc(l.x - l.size * 0.2, l.y - l.size * 0.2, l.size * 0.25 * f, 0.6, { 1, 1, 1 })
            else
                self:disc(l.x, l.y, l.size * 1.1, 0.75, col)
            end
        end
        self:pic("bowl", cx, cy, 0.95)
        self:circle(mx, my, self.pressR, 0.35, C.text, 28, 2)
        self:drawHeld(mx, my, 54)
    elseif k == "fill" then
        local gx, gy, gw, gh = cx - 40, PY + 26, 80, PH - 50
        self:drawRect(gx + 4, gy + 4, gw - 8, gh - 8, 0.35, 0.05, 0.1, 0.12)
        local b = self.band2
        self:drawRect(gx + 4, gy + gh * (1 - b[2]), gw - 8, gh * (b[2] - b[1]), 0.55, C.good[1], C.good[2], C.good[3])
        local lh = (gh - 8) * clamp(self.level, 0, 1)
        local col = v == "season" and { 0.94, 0.92, 0.86 } or { 0.96, 0.86, 0.58 }
        self:drawRect(gx + 6, gy + gh - 4 - lh, gw - 12, lh, 1, col[1], col[2], col[3])
        self:pic("jug", cx, gy + gh / 2, gh / 250)
        if self.pouring then
            for i = 1, 10 do self:drawRect(cx - 2 + ZombRand(-6, 7), gy - 34 + i * 3, 2, 3, 0.9, col[1], col[2], col[3]) end
        end
        self:food(cx + 170, cy, 110)
        -- the seasoning itself is held over the jug while pouring
        local held = self.opts.cursor or self.opts.spice
        if held then self:drawTextureScaled(held, cx - 100, gy + 4 + (self.pouring and 10 or 0), 52, 52, 1, 1, 1, 1) end
        self:text(T("IGUI_GTPC_Game_Round", self.round, self.rounds), cx, PY + 4, C.text, UIFont.Small, true)
    elseif k == "watch" then
        local b = self.band2
        local lv = clamp(self.level, 0, 1.1)
        if v == "steep" then
            -- clear water slowly turning the colour of the tea
            local base = { 0.80, 0.86, 0.90 }
            local strong = FILL.drink
            local c = { base[1] + (strong[1] - base[1]) * lv, base[2] + (strong[2] - base[2]) * lv, base[3] + (strong[3] - base[3]) * lv }
            self:disc(cx - 40, cy + 6, 94, 1, c)
            self:pic("mug", cx - 10, cy + 6, 0.98)
            -- the tea itself hangs in the cup (it is not in the hand)
            if self.opts.cursor then self:drawTextureScaled(self.opts.cursor, cx - 66, cy - 30, 52, 52, 0.9, 1, 1, 1) end
        else
            -- the underside browning: pale batter to golden to burnt
            local c
            if lv < 0.7 then c = { 0.98 - 0.12 * lv, 0.90 - 0.30 * lv, 0.62 - 0.40 * lv }
            else c = { 0.90 - 0.9 * (lv - 0.7), 0.69 - 0.9 * (lv - 0.7), 0.34 - 0.6 * (lv - 0.7) } end
            self:disc(cx - 50, cy + 16, 100, 1, { 0.18, 0.18, 0.20 })
            self:disc(cx - 50, cy + 16, 72, 1, c)
            self:pic("pan", cx, cy + 16, 0.82)
        end
        -- the "just right" shade and where it is now
        local sx, sy, sw = PX + PW - 60, PY + 24, 24
        local sh = PH - 48
        self:drawRect(sx, sy, sw, sh, 0.9, 0.04, 0.12, 0.05)
        self:drawRect(sx, sy + sh * (1 - b[2]), sw, sh * (b[2] - b[1]), 0.6, C.good[1], C.good[2], C.good[3])
        local vy = sy + sh * (1 - clamp(lv, 0, 1))
        self:drawRect(sx - 4, vy - 2, sw + 8, 4, 1, C.text[1], C.text[2], C.text[3])
        self:text(T("IGUI_GTPC_Game_Round", self.round, self.rounds), cx, PY + 4, C.text, UIFont.Small, true)
        if v ~= "steep" then self:drawHeld(mx, my, 50) end
    end
end

-- for tests: the panel class
G.Panel = P

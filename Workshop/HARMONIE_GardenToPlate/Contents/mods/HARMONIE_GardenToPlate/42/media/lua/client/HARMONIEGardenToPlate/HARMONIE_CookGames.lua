--[[
    HARMONIE - From Garden to Plate: the cooking minigames (client).
    Written for this mod (the same idea as The Way To Attack's procedure
    games, nothing copied): one modal panel, four kinds of game.

      timing  chop / mince / trim / crack -- a knife sweeps over the food,
              click on each cut line; knead -- click when the ring closes
      scrub   wash -- scrub every dirty spot; peel -- around the food in
              order; grate -- up and down the grater, keep the fingers in
      circle  stir / whisk -- circle the pot at the right speed
      fill    season / measure -- hold to pour, let go in the green band

    The result is a word, as in The Way To Attack: Excellent (0.85+),
    Good (0.6+), Bad (0.3+), else Miss (do it again). Harder when the
    Cooking level is low or a makeshift tool is used (a fork as a whisk),
    easier with a cutting board / rolling pin at hand (K.difficulty).
]]--

require "ISUI/ISPanel"
require "HARMONIEGardenToPlate/HARMONIE_CookCore"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.CookGames = HARMONIE_GTP.CookGames or {}
local G = HARMONIE_GTP.CookGames
local K = HARMONIE_GTP.Cook
local log = K.log

local W, H = 600, 470
local PX, PY, PW, PH = 20, 78, 560, 290

local C = {
    bg = { 0.012, 0.04, 0.018 }, panel = { 0.025, 0.08, 0.035 }, border = { 0.32, 0.76, 0.40 }, accent = { 0.50, 0.90, 0.52 },
    text = { 0.94, 1.0, 0.94 }, dim = { 0.66, 0.82, 0.68 }, good = { 0.45, 0.92, 0.48 }, bad = { 1.0, 0.42, 0.38 }, warn = { 1.0, 0.82, 0.32 },
    wood = { 0.45, 0.30, 0.16 }, wood2 = { 0.33, 0.21, 0.10 }, metal = { 0.72, 0.74, 0.78 }, water = { 0.35, 0.62, 0.92 },
    dirt = { 0.42, 0.30, 0.16 }, pot = { 0.30, 0.31, 0.34 }, soup = { 0.78, 0.52, 0.20 },
}

local function T(key, ...)
    local ok, s = pcall(getText, key, ...)
    return ok and s or key
end
local function now() return getTimestampMs and getTimestampMs() or 0 end
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local function dist(x1, y1, x2, y2) local dx, dy = x2 - x1, y2 - y1 return math.sqrt(dx * dx + dy * dy) end
local function font(n) return ({ UIFont.Small, UIFont.Medium, UIFont.Large })[n] or UIFont.Small end

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
    log("minigame %s (%s/%s) started, difficulty %.2f", pid, o.kind, o.variant, o.d)
    return true
end

function G.close()
    if G.instance then G.instance:finish(nil, true) end
end

-- tolerance factor: 1.4 at the easiest, 0.45 at the hardest
function P:tol() return 1.45 - self.d end

-- ------------------------------------------------------------------ setup
function P:setup()
    local v = self.variant
    self.limit = 14000
    if self.kind == "timing" then
        if v == "knead" then
            self.beats, self.beat, self.ring = 6, 0, 0
            self.period = 1100 - 300 * self.d
            self.limit = self.beats * self.period + 3000
            self.scores = {}
        else
            local n = ({ chop = 5, mince = 8, trim = 4, crack = 2 })[v] or 5
            self.speed = ({ chop = 240, mince = 330, trim = 190, crack = 280 })[v] or 240
            self.speed = self.speed * (0.8 + 0.4 * self.d)
            self.tolW = ({ trim = 9, crack = 12 })[v] or 14
            self.tolW = self.tolW * self:tol()
            self.targets = {}
            local left, right = PX + 110, PX + PW - 110
            for i = 1, n do
                local tx = left + (right - left) * (i - 0.5) / n + ZombRand(-12, 13)
                self.targets[i] = { x = tx, hit = false, score = 0 }
            end
            self.mx, self.dir = left - 40, 1
            self.limit = 9000 + n * 900
        end
    elseif self.kind == "scrub" then
        self.spots = {}
        local cx, cy = PX + PW / 2, PY + PH / 2
        if v == "grate" then
            self.lane = { x = cx - 50, y = PY + 30, w = 100, h = PH - 60 }
            self.strokes, self.need, self.phaseDown = 0, 9, true
            self.limit = 12000
        else
            local n = v == "peel" and 9 or 7
            for i = 1, n do
                local a = (i / n) * math.pi * 2
                local r = v == "peel" and 92 or ZombRand(20, 105)
                if v ~= "peel" then a = ZombRand(0, 628) / 100 end
                self.spots[i] = { x = cx + math.cos(a) * r * 1.3, y = cy + math.sin(a) * r * 0.85, dirt = 1, order = i }
            end
            self.nextSpot = 1
            self.radius = 26 * self:tol()
            self.limit = v == "peel" and 15000 or 13000
        end
    elseif self.kind == "circle" then
        self.cx, self.cy = PX + PW / 2, PY + PH / 2 + 10
        local whisk = v == "whisk"
        self.band = whisk and { 8.5, 17 } or { 2.2, 6.0 }
        local widen = (self:tol() - 1) * (whisk and 3 or 1.2)
        self.band = { self.band[1] - widen, self.band[2] + widen }
        self.needMs = whisk and 4200 or 5200
        self.progress, self.av, self.lastA = 0, 0, nil
        self.limit = 16000
    elseif self.kind == "fill" then
        self.rounds = v == "season" and 3 or 1
        self.round, self.level, self.vel, self.scores = 1, 0, 0, {}
        self.bandW = (v == "season" and 0.10 or 0.14) * self:tol()
        self:newBand()
        self.limit = v == "season" and 14000 or 9000
    end
end

function P:newBand()
    local c = 0.35 + ZombRand(0, 40) / 100
    self.band2 = { c - self.bandW / 2, c + self.bandW / 2 }
    self.level, self.vel, self.pouring = 0, 0, false
end

-- ------------------------------------------------------------------ helpers
function P:flash(text, col)
    self.flashes[#self.flashes + 1] = { text = text, col = col or C.text, at = now(), x = self:getMouseX(), y = self:getMouseY() - 20 }
end

-- every = false: each slip costs (a click); else at most once per 0.6 s
-- (something held or dragged that keeps happening every frame)
function P:spend(amount, key, every)
    local t = now()
    self.lastSpend = self.lastSpend or {}
    if every ~= false and self.lastSpend[key] and t - self.lastSpend[key] < 600 then return end
    self.lastSpend[key] = t
    self.q = clamp(self.q - amount, 0, 1)
    self:flash(T("IGUI_GTPC_Flash_" .. key), C.bad)
end

local function sfx(name)
    if getSoundManager then pcall(function() getSoundManager():playUISound(name) end) end
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
    if self.kind == "timing" then
        if self.variant == "knead" then
            self.ring = ((t - self.started) % self.period) / self.period
            local b = math.floor((t - self.started) / self.period)
            if b > self.beat then
                if not self.clickedThisBeat and self.beat > 0 then self.scores[#self.scores + 1] = 0; self:spend(0.08, "Late") end
                self.beat = b
                self.clickedThisBeat = false
                if self.beat > self.beats then return self:complete() end
            end
        else
            self.mx = self.mx + self.dir * self.speed * dt / 1000
            local left, right = PX + 60, PX + PW - 60
            if self.mx > right then self.mx, self.dir = right, -1 elseif self.mx < left then self.mx, self.dir = left, 1 end
        end
    elseif self.kind == "scrub" then
        if self.variant == "grate" then
            if held then
                local L = self.lane
                if mx < L.x - 6 or mx > L.x + L.w + 6 then self:spend(0.1, "Knuckle") end
                if self.phaseDown and my > L.y + L.h - 18 then self.phaseDown = false
                elseif not self.phaseDown and my < L.y + 18 then
                    self.phaseDown = true
                    self.strokes = self.strokes + 1
                    sfx("UISelectListItem")
                    if self.strokes >= self.need then return self:complete() end
                end
            end
        elseif held and self.prevX then
            local moved = dist(self.prevX, self.prevY, mx, my)
            for _, s in ipairs(self.spots) do
                if s.dirt > 0 and dist(mx, my, s.x, s.y) < self.radius then
                    if self.variant == "peel" and s.order ~= self.nextSpot then
                        self:spend(0.08, "Deep")
                    else
                        s.dirt = math.max(0, s.dirt - moved / 160)
                        if s.dirt <= 0 then
                            sfx("UISelectListItem")
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
    elseif self.kind == "circle" then
        local r = dist(mx, my, self.cx, self.cy)
        local inRing = r > 28 and r < 128
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
        if self.av >= self.band[1] and self.av <= self.band[2] then
            self.progress = self.progress + dt / self.needMs
            if self.progress >= 1 then return self:complete() end
        elseif self.av > self.band[2] + 1 then
            self:spend(0.06, "Splash")
        end
    elseif self.kind == "fill" then
        if self.pouring then
            self.vel = self.vel + dt / 1000 * (self.variant == "measure" and 1.2 or 0.8) * (0.8 + 0.4 * self.d)
            self.level = self.level + self.vel * dt / 1000
            if self.level >= 1 then self:releasePour() end
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
    self:flash(T("IGUI_GTPC_Flash_Time"), C.bad)
    self:finish("Miss")
end

function P:complete()
    local q = self.q
    if self.kind == "timing" then
        local sum, n = 0, 0
        if self.targets then
            for _, t in ipairs(self.targets) do sum = sum + t.score; n = n + 1 end
        else
            for _, s in ipairs(self.scores) do sum = sum + s; n = n + 1 end
        end
        q = q * (n > 0 and sum / n or 0)
    elseif self.kind == "scrub" or self.kind == "circle" then
        local used = (now() - self.started) / self.limit
        q = q * (1 - 0.45 * clamp(used, 0, 1))
    elseif self.kind == "fill" then
        local sum = 0
        for _, s in ipairs(self.scores) do sum = sum + s end
        q = q * (#self.scores > 0 and sum / #self.scores or 0)
    end
    self.q = clamp(q, 0, 1)
    local word = self:wordFor(self.q)
    sfx(word == "Miss" and "UIMenuBack" or "UISelectListItem")
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
    if self.kind == "timing" then
        if self.variant == "knead" then
            if self.clickedThisBeat or self.beat < 1 then return true end
            self.clickedThisBeat = true
            -- best at the end of the beat, when the ring meets the dough
            local off = math.abs(1 - self.ring)
            off = math.min(off, self.ring)
            local s = clamp(1 - off / (0.22 * self:tol()), 0, 1)
            self.scores[#self.scores + 1] = s
            self:flash(T(s > 0.7 and "IGUI_GTPC_Flash_Nice" or (s > 0.2 and "IGUI_GTPC_Flash_Ok" or "IGUI_GTPC_Flash_Late")), s > 0.7 and C.good or (s > 0.2 and C.warn or C.bad))
            sfx("UISelectListItem")
        else
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
                self:flash(T(best.score > 0.8 and "IGUI_GTPC_Flash_Nice" or "IGUI_GTPC_Flash_Ok"), best.score > 0.8 and C.good or C.warn)
                sfx("UISelectListItem")
                local all = true
                for _, t in ipairs(self.targets) do if not t.hit then all = false end end
                if all then self:complete() end
            else
                self:spend(0.12, "Slip", false)
            end
        end
    elseif self.kind == "fill" then
        self.pouring = true
    end
    return true
end

function P:releasePour()
    if not self.pouring then return end
    self.pouring = false
    local b = self.band2
    local s
    if self.level >= b[1] and self.level <= b[2] then
        local c = (b[1] + b[2]) / 2
        s = clamp(1 - math.abs(self.level - c) / (b[2] - b[1]) * 0.8, 0, 1)
        self:flash(T(s > 0.75 and "IGUI_GTPC_Flash_Nice" or "IGUI_GTPC_Flash_Ok"), s > 0.75 and C.good or C.warn)
    elseif self.level > b[2] then
        s = 0
        self:flash(T("IGUI_GTPC_Flash_Over"), C.bad)
    else
        s = clamp(0.5 - (b[1] - self.level) * 3, 0, 0.5)
        self:flash(T("IGUI_GTPC_Flash_Under"), C.warn)
    end
    self.scores[#self.scores + 1] = s
    sfx("UISelectListItem")
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

function P:food(cx, cy, size)
    local icon = self.opts.icon
    if icon then
        self:drawTextureScaled(icon, cx - size / 2, cy - size / 2, size, size, 1, 1, 1, 1)
    else
        self:disc(cx, cy, size * 0.4, 1, { 0.85, 0.45, 0.15 })
    end
end

function P:prerender()
    pcall(function() self:tick() end)
    self:drawRect(0, 0, W, H, 0.97, C.bg[1], C.bg[2], C.bg[3])
    self:drawRectBorder(0, 0, W, H, 1, C.border[1], C.border[2], C.border[3])
    self:drawRect(1, 1, W - 2, 34, 0.95, 0.03, 0.12, 0.05)
    self:text(T("IGUI_GTPC_Proc_" .. self.pid), 14, 8, C.accent, UIFont.Medium)
    self:text(T("IGUI_GTPC_Hint_" .. self.pid), 14, 44, C.dim, UIFont.Small)
    self:drawRect(PX, PY, PW, PH, 0.9, C.panel[1], C.panel[2], C.panel[3])
    self:drawRectBorder(PX, PY, PW, PH, 0.7, 0.14, 0.36, 0.18)
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
    -- flashes
    local tn = now()
    for i = #self.flashes, 1, -1 do
        local f = self.flashes[i]
        local age = tn - f.at
        if age > 900 then table.remove(self.flashes, i)
        else self:text(f.text, f.x, f.y - age / 30, f.col, UIFont.Small, true) end
    end
    -- the word
    if self.done and self.result then
        local col = ({ Excellent = C.good, Good = C.accent, Bad = C.warn, Miss = C.bad })[self.result] or C.text
        self:drawRect(PX + 120, PY + PH / 2 - 34, PW - 240, 68, 0.92, 0.02, 0.06, 0.03)
        self:drawRectBorder(PX + 120, PY + PH / 2 - 34, PW - 240, 68, 1, col[1], col[2], col[3])
        self:text(T("IGUI_GTPC_Word_" .. self.result), PX + PW / 2, PY + PH / 2 - 14, col, UIFont.Large, true)
    end
end

function P:renderGame()
    local mx, my = self:getMouseX(), self:getMouseY()
    local cx, cy = PX + PW / 2, PY + PH / 2
    if self.kind == "timing" then
        if self.variant == "knead" then
            self:disc(cx, cy + 20, 70, 1, { 0.92, 0.84, 0.62 })
            self:circle(cx, cy + 20, 74, 1, { 0.75, 0.62, 0.40 }, 64, 3)
            local r = 74 + (1 - self.ring) * 110
            self:circle(cx, cy + 20, r, 0.9, C.accent, 72, 3)
            self:text(T("IGUI_GTPC_Game_Beat", math.min(self.beat, self.beats), self.beats), cx, PY + 12, C.text, UIFont.Small, true)
        else
            self:drawRect(PX + 40, cy - 70, PW - 80, 150, 1, C.wood[1], C.wood[2], C.wood[3])
            self:drawRect(PX + 40, cy + 72, PW - 80, 8, 1, C.wood2[1], C.wood2[2], C.wood2[3])
            for i = 0, 4 do self:drawRect(PX + 40, cy - 60 + i * 30, PW - 80, 1, 0.25, 0.2, 0.12, 0.05) end
            local size = 120
            for i = -1, 1 do self:food(cx + i * 130, cy, size) end
            for _, t in ipairs(self.targets) do
                local col = t.hit and C.good or C.warn
                for yy = cy - 62, cy + 60, 8 do self:drawRect(t.x - 1, yy, 2, 5, t.hit and 0.9 or 0.75, col[1], col[2], col[3]) end
                self:drawRect(t.x - self.tolW, cy + 66, self.tolW * 2, 3, 0.35, col[1], col[2], col[3])
            end
            -- the knife
            local kx = self.mx
            self:drawRect(kx - 2, cy - 110, 4, 60, 1, C.metal[1], C.metal[2], C.metal[3])
            self:drawRect(kx - 4, cy - 132, 8, 24, 1, 0.15, 0.10, 0.06)
            if self.opts.tool then self:drawTextureScaled(self.opts.tool, kx - 20, cy - 150, 40, 40, 0.9, 1, 1, 1) end
            for yy = cy - 50, cy + 70, 6 do self:drawRect(kx - 0.5, yy, 1, 3, 0.35, 1, 1, 1) end
        end
    elseif self.kind == "scrub" then
        if self.variant == "grate" then
            local L = self.lane
            self:drawRect(L.x, L.y, L.w, L.h, 1, C.metal[1], C.metal[2], C.metal[3])
            for yy = L.y + 8, L.y + L.h - 8, 10 do
                for xx = L.x + 8, L.x + L.w - 12, 14 do self:drawRect(xx, yy, 6, 3, 1, 0.25, 0.26, 0.29) end
            end
            self:drawRect(L.x - 6, L.y, 6, L.h, 0.35, C.bad[1], C.bad[2], C.bad[3])
            self:drawRect(L.x + L.w, L.y, 6, L.h, 0.35, C.bad[1], C.bad[2], C.bad[3])
            local pile = math.min(1, self.strokes / self.need)
            self:disc(L.x + L.w + 90, L.y + L.h - 20, 10 + 40 * pile, 1, { 0.95, 0.78, 0.30 })
            self:food(mx, my, 70)
            self:text(T("IGUI_GTPC_Game_Strokes", self.strokes, self.need), cx, PY + 10, C.text, UIFont.Small, true)
        else
            self:food(cx, cy, 200)
            for _, s in ipairs(self.spots) do
                if s.dirt > 0 then
                    local col = self.variant == "peel" and { 0.55, 0.36, 0.14 } or C.dirt
                    self:disc(s.x, s.y, 8 + 14 * s.dirt, 0.55 + 0.4 * s.dirt, col)
                    if self.variant == "peel" and s.order == self.nextSpot then self:circle(s.x, s.y, 26, 1, C.accent, 36, 2) end
                end
            end
            if self.variant == "wash" then
                for i = 1, 6 do self:drawRect(mx - 18 + i * 5, my - 22 - (now() / 6 + i * 13) % 20, 2, 4, 0.7, C.water[1], C.water[2], C.water[3]) end
            end
            self:circle(mx, my, self.radius, 0.6, C.water, 32, 2)
        end
    elseif self.kind == "circle" then
        self:disc(self.cx, self.cy, 132, 1, C.pot)
        self:disc(self.cx, self.cy, 120, 1, self.variant == "whisk" and { 0.95, 0.86, 0.48 } or C.soup)
        self:circle(self.cx, self.cy, 28, 0.5, C.text, 24, 2)
        local swirl = (now() / 1000) * self.av
        for i = 0, 5 do
            local a = swirl + i * math.pi / 3
            self:drawRect(self.cx + math.cos(a) * 80 - 3, self.cy + math.sin(a) * 80 - 3, 6, 6, 0.55, 1, 1, 1)
        end
        local barX, barY, barW = PX + 30, PY + 20, 26
        local maxV = self.band[2] * 1.6
        self:drawRect(barX, barY, barW, PH - 40, 0.9, 0.04, 0.12, 0.05)
        local b1 = barY + (PH - 40) * (1 - self.band[2] / maxV)
        local b2 = barY + (PH - 40) * (1 - self.band[1] / maxV)
        self:drawRect(barX, b1, barW, b2 - b1, 0.6, C.good[1], C.good[2], C.good[3])
        local vy = barY + (PH - 40) * (1 - clamp(self.av / maxV, 0, 1))
        self:drawRect(barX - 4, vy - 2, barW + 8, 4, 1, C.text[1], C.text[2], C.text[3])
        self:drawRect(PX + PW - 60, PY + 20, 26, PH - 40, 0.9, 0.04, 0.12, 0.05)
        local ph = (PH - 40) * clamp(self.progress, 0, 1)
        self:drawRect(PX + PW - 60, PY + PH - 20 - ph, 26, ph, 1, C.accent[1], C.accent[2], C.accent[3])
        self:text(T(self.av > self.band[2] and "IGUI_GTPC_Game_Faster0" or (self.av < self.band[1] and "IGUI_GTPC_Game_Faster" or "IGUI_GTPC_Game_Keep")),
            self.cx, PY + 8, self.av > self.band[2] and C.bad or C.text, UIFont.Small, true)
        if self.opts.tool then self:drawTextureScaled(self.opts.tool, mx - 20, my - 20, 40, 40, 1, 1, 1, 1) end
    elseif self.kind == "fill" then
        local gx, gy, gw, gh = cx - 40, PY + 24, 80, PH - 48
        self:drawRect(gx, gy, gw, gh, 0.9, 0.04, 0.12, 0.05)
        self:drawRectBorder(gx, gy, gw, gh, 1, C.border[1], C.border[2], C.border[3])
        local b = self.band2
        self:drawRect(gx, gy + gh * (1 - b[2]), gw, gh * (b[2] - b[1]), 0.6, C.good[1], C.good[2], C.good[3])
        local lh = gh * clamp(self.level, 0, 1)
        local col = self.variant == "season" and { 0.92, 0.92, 0.88 } or { 0.95, 0.85, 0.55 }
        self:drawRect(gx + 4, gy + gh - lh, gw - 8, lh, 1, col[1], col[2], col[3])
        if self.pouring then
            for i = 1, 8 do self:drawRect(cx - 2 + ZombRand(-6, 7), gy - 30 + i * 3, 2, 3, 0.9, col[1], col[2], col[3]) end
        end
        self:food(cx + 170, cy, 110)
        self:text(T("IGUI_GTPC_Game_Round", self.round, self.rounds), cx, PY + 4, C.text, UIFont.Small, true)
    end
end

-- for tests: the panel class
G.Panel = P

--============================================================================
-- HARMONIE_TheWayToAttack -- STRIKE minigame (client)
--
-- Hammering of every kind: nails and rivets into a board, a spike into a
-- head, forging hot metal, knapping a stone, smashing a bottle.
--
-- Over the current target a ring shrinks onto it again and again (the
-- hammer coming down). Put the hammer on the target and click as the ring
-- meets the mark: dead on drives it deep, close drives it less and costs a
-- little, badly timed bends the nail / cracks the metal, and missing the
-- target altogether hits the work. Each target needs to be driven home;
-- then the next one lights up.
--
-- variant "forge": the bar glows with heat and cools as you work. Striking
-- cold metal cracks it -- hold the hammer on the coals at the left to bring
-- the heat back up. variant "knap": flakes fly and a missed strike chips
-- the edge. variant "smash": one hard, well-timed blow.
--============================================================================

require "HARMONIE_TWA_MinigameBase"

TWAStrikeGame = TWAMinigameBase:derive("TWAStrikeGame")

local B = TWAMinigameBase
local C = B.COL

local VARIANTS = {
    nails = { count = function(req) return 2 + math.ceil(req / 3) end, surface = "wood" },
    rivet = { count = function(req) return 2 + math.ceil(req / 3) end, surface = "metal" },
    forge = { count = function(req) return 3 + math.floor(req / 2) end, surface = "hot" },
    knap  = { count = function() return 3 end, surface = "stone" },
    smash = { count = function() return 1 end, surface = "glass" },
}

function TWAStrikeGame:onStart()
    local v = VARIANTS[self.variant] or VARIANTS.nails
    self.v = v
    self.surface = v.surface
    local n = math.max(1, math.min(8, v.count(self.req)))

    -- The work piece: a band across the middle of the play area.
    self.wx, self.wy, self.ww, self.wh = 150, 150, 400, 90
    self.targets = {}
    for i = 1, n do
        local fx = (i - 0.5) / n
        self.targets[i] = {
            x = self.wx + 30 + fx * (self.ww - 60) + ZombRandFloat(-10, 10),
            y = self.wy + self.wh * 0.5 + ZombRandFloat(-18, 18),
            depth = 0,
        }
    end
    self.idx = 1
    self.ringT = 0
    -- Request 2026-09-28 ("มินิเกมการตีง่ายเกินไป ทำให้วงกลมหดเร็วขึ้น และ
    -- วงกลมเริ่มต้นใหญ่ขึ้น2เท่า"): the ring starts twice as big (70 -> 140
    -- px) and closes in 900 ms instead of 1150 -- about 3x faster across
    -- the target, so the timing window is ~45 ms (perfect ~20 ms) instead
    -- of ~115 ms. The ring-error window itself is NOT also halved: at this
    -- speed half of it would be under one frame, i.e. luck, not skill. The
    -- "zones half as wide" request applies to how close the hammer must be
    -- to the mark instead (22 -> 11 px).
    self.period = 900 / self.pace           -- ms for the ring to close
    -- The lit mark is bigger (request 2026-09-28: "ทำจุดสว่างให้ใหญ่ขึ้น")
    -- -- 13 -> 22 px, and the hammer may land anywhere on it.
    self.R0, self.Rt = 140, 22
    self.lastRing = self.R0
    -- Follow-up request (same day): "มินิเกมตอกตะปูพลาดทุกครั้ง ปรับให้ช่วง
    -- เวลาที่กดแล้วนับว่าตรงจังหวะ 115 เหมือนเดิม" -- the timing window is set
    -- in TIME (115 ms either side, perfect = 45% of it, ~52 ms) and turned
    -- into ring pixels from the ring's own speed, so it stays 115 ms however
    -- fast the ring closes. The big fast ring stays.
    self.window = 115 * (self.R0 / self.period) * self.tol -- px of ring error still "good"
    self.aim = self.Rt * self.tol            -- anywhere on the lit mark counts
    self.heat = 1
    self.coal = { x = 20, y = 150, w = 100, h = 90 }
    self.timeLimit = 25000 + n * 9000
    -- Cursor (request 2026-09-28): always the ball-peen hammer, except in
    -- Blacksmithing (internal category "Metallurgy"), where it's the hammer
    -- pictured on the procedure itself (ForgeShape = hammerstone, ForgeFold =
    -- ball-peen, ForgeComplex = smithing hammer, ForgeVacuum = sledgehammer).
    local picture = "BallPeenHammer_Forged"
    if self.proc and self.proc.category == "Metallurgy" and self.proc.icon then picture = self.proc.icon end
    self.toolTex = B.itemTex(picture) or self.toolTex
    self.toolSize = 52

    local key = "IGUI_TWA_MG_Strike_Hint_" .. (self.variant or "nails")
    self.hint = getText("IGUI_TWA_MG_Strike_Hint")
    self.hint2 = getText(key)
end

function TWAStrikeGame:current()
    return self.targets[self.idx]
end

function TWAStrikeGame:ringRadius()
    return self.R0 * (1 - self.ringT)
end

function TWAStrikeGame:inCoal(x, y)
    local c = self.coal
    return x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h
end

function TWAStrikeGame:onGrab(x, y)
    if self.surface == "hot" and self:inCoal(x, y) then
        self.reheating = true
        return
    end
    local t = self:current()
    if not t then return end
    self.ringT = 0 -- the hammer comes up again whatever happened
    local d = B.dist(x, y, t.x, t.y)
    if d > self.aim then
        self:spend(0.12, getText("IGUI_TWA_MG_Strike_OffTarget"))
        self:burst(self.surface == "wood" and "dust" or "chip", x, y, 8, { speed = 0.25 })
        return
    end
    local err = math.abs(self.lastRing - self.Rt)
    local cold = self.surface == "hot" and self.heat < 0.35
    -- Smashing is one blow (request 2026-09-28: "กรรมวิธี ทุบ ให้ทุบครั้งเดียว
    -- พอ"): any timed hit on the mark finishes it; the timing still decides
    -- how much quality it costs.
    local oneBlow = self.variant == "smash"
    if err <= self.window * 0.45 then
        t.depth = oneBlow and 1 or (t.depth + 0.55)
        self:flash(getText("IGUI_TWA_MG_Strike_Perfect"), false, 500)
        self:shake(5, 180)
    elseif err <= self.window then
        t.depth = oneBlow and 1 or (t.depth + 0.35)
        self:spend(0.035)
        self:shake(3, 150)
    else
        t.depth = oneBlow and 1 or math.max(0, t.depth - 0.1)
        local key = self.surface == "wood" and "IGUI_TWA_MG_Strike_Bent" or "IGUI_TWA_MG_Strike_BadTiming"
        self:spend(0.11, getText(key))
    end
    if cold then
        self:spend(0.08, getText("IGUI_TWA_MG_Strike_TooCold"))
    end
    local kind = (self.surface == "hot" or self.surface == "metal") and "spark"
        or (self.surface == "wood" and "dust") or "chip"
    local col = self.surface == "stone" and C.faint or (self.surface == "glass" and C.steam) or nil
    self:burst(kind, t.x, t.y, self.surface == "hot" and 18 or 10, { speed = 0.35, col = col })
    self:burst("ring", t.x, t.y, 1, { size = self.Rt, grow = 0.08, ttl = 300 })
    if t.depth >= 1 then
        t.depth = 1
        t.done = true
        self.idx = self.idx + 1
        if self.idx > #self.targets then
            self:succeed(getText("IGUI_TWA_MG_Strike_Done"))
        end
    end
end

function TWAStrikeGame:onDrag(x, y, dt)
    if self.reheating then
        if self:inCoal(x, y) then
            self.heat = math.min(1, self.heat + dt / 1800)
            if ZombRand(3) == 0 then self:burst("ember", x, y, 1) end
        else
            self.reheating = false
        end
    end
end

function TWAStrikeGame:onRelease()
    self.reheating = false
end

function TWAStrikeGame:updateGame(dt)
    if not self.reheating then
        self.ringT = self.ringT + dt / self.period
        if self.ringT >= 1 then self.ringT = 0 end
    end
    self.lastRing = self:ringRadius()
    if self.surface == "hot" and not self.reheating then
        self.heat = math.max(0, self.heat - dt / (14000 + 700 * self.have))
        if self.heat > 0.5 and ZombRand(6) == 0 then
            self:burst("ember", self.wx + ZombRandFloat(0, self.ww), self.wy, 1, { ttl = 500 })
        end
    end
    -- The hammer rises as the ring opens, drops as it closes.
    self.toolLift = 26 * (1 - self.ringT)
    local done = 0
    for _, t in ipairs(self.targets) do done = done + t.depth end
    self.progress = done / #self.targets
end

function TWAStrikeGame:renderGame()
    local wx, wy, ww, wh = self.wx, self.wy, self.ww, self.wh
    -- Anvil / bench under the work.
    self:rect(wx - 20, wy + wh, ww + 40, 22, 1, C.dark)
    self:line(wx - 20, wy + wh, wx + ww + 20, wy + wh, 2, 1, C.faint)

    if self.surface == "wood" then
        self:rect(wx, wy, ww, wh, 1, C.wood)
        for i = 1, 5 do
            local gy = wy + i * wh / 6
            self:line(wx + 6, gy, wx + ww - 6, gy + ((i % 2) * 2 - 1) * 3, 1, 0.5, C.wood2)
        end
    elseif self.surface == "hot" then
        local r, g, b = B.heatColor(self.heat)
        self:rectRGB(wx, wy + 20, ww, wh - 40, 1, r, g, b)
        self:frame(wx, wy + 20, ww, wh - 40, 1, C.line)
        -- The coals.
        local c = self.coal
        self:rect(c.x, c.y, c.w, c.h, 1, C.dark)
        for i = 0, 5 do
            local glow = 0.4 + 0.3 * math.sin(self.elapsed * 0.004 + i)
            self:disc(c.x + 12 + i * 15, c.y + c.h - 18 - (i % 2) * 10, 9, glow, C.ember, 10)
        end
        self:frame(c.x, c.y, c.w, c.h, 1, self.reheating and C.guide or C.faint)
        self:textC(getText("IGUI_TWA_MG_Strike_Coals"), c.x + c.w / 2, c.y - 18, C.faint)
        -- Heat bar.
        self:rect(wx, wy - 26, ww, 8, 1, C.dark)
        local hr, hg, hb = B.heatColor(self.heat)
        self:rectRGB(wx, wy - 26, ww * self.heat, 8, 1, hr, hg, hb)
        self:line(wx + ww * 0.35, wy - 30, wx + ww * 0.35, wy - 14, 2, 1, C.bad)
    elseif self.surface == "stone" then
        local pts = { { wx + 20, wy + wh }, { wx, wy + 40 }, { wx + 60, wy + 4 }, { wx + ww - 80, wy },
                      { wx + ww, wy + 30 }, { wx + ww - 20, wy + wh } }
        self:polyline(pts, 2, 1, C.line, true)
        for i = 1, 6 do
            self:line(wx + i * 55, wy + 10, wx + i * 55 + 20, wy + wh - 10, 1, 0.35, C.faint)
        end
    elseif self.surface == "glass" then
        local cx = wx + ww / 2
        self:polyline({ { cx - 35, wy + wh }, { cx - 35, wy + 20 }, { cx - 12, wy - 10 }, { cx - 12, wy - 50 },
                        { cx + 12, wy - 50 }, { cx + 12, wy - 10 }, { cx + 35, wy + 20 }, { cx + 35, wy + wh } }, 2, 1, C.steam)
    else -- metal (rivets)
        self:rect(wx, wy, ww, wh, 1, C.metal)
        self:frame(wx, wy, ww, wh, 1, C.line)
    end

    -- The workpiece's own icon, faint, so you see what you are making.
    if self.workTex then self:tex(self.workTex, wx + ww - 64, wy - 70, 56, 56, 0.55) end

    -- Targets.
    for i, t in ipairs(self.targets) do
        local active = i == self.idx
        if self.surface == "wood" or self.surface == "metal" then
            local h = 30 * (1 - t.depth)
            self:line(t.x, t.y - h, t.x, t.y, 3, 1, C.metal)
            self:rect(t.x - 7, t.y - h - 3, 14, 4, 1, t.done and C.faint or C.line)
        else
            self:ring(t.x, t.y, 6, 2, t.done and 0.35 or 1, t.done and C.faint or C.line, 14)
        end
        if active then
            self:ring(t.x, t.y, self.Rt, 2, 0.9, C.guide)
        end
    end
end

function TWAStrikeGame:renderOverlay()
    local t = self:current()
    if not t or self.word or self.reheating then return end
    local r = self:ringRadius()
    local err = math.abs(r - self.Rt)
    local c = err <= self.window * 0.45 and C.good or (err <= self.window and C.guide or C.line)
    self:ring(t.x, t.y, r, 3, 0.9, c)
end

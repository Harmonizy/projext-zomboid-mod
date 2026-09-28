--============================================================================
-- HARMONIE_TheWayToAttack -- FACET minigame (client), gem-cutting
--
-- Round 15 (new category การเจียระไน). Cutting the facets of a gem on the
-- lap: the gauge on the right is the angle the stone is held at -- the
-- mouse's height while you hold the button. Keep the needle in the green
-- band (it drifts -- "moving zones") until the current facet is cut, then
-- the next one lights up. Out of the band the facet is cut at the wrong
-- angle and quality drops; far out it chips the stone.
--   "facet" (Faceting): 8 facets.
--   "fine"  (Fine Cutting): 12 facets, a narrower band that moves faster.
--============================================================================

require "HARMONIE_TWA_MinigameBase"

TWAFacetGame = TWAMinigameBase:derive("TWAFacetGame")

local B = TWAMinigameBase
local C = B.COL
local GX, GY, GH = 540, 60, 240

function TWAFacetGame:onStart()
    self.fine = self.variant == "fine"
    self.n = self.fine and 12 or 8
    self.idx = 1
    self.cut = 0                                  -- 0..1 of the current facet
    self.half = (self.fine and 0.05 or 0.08) * self.tol
    self.period = self.fine and 2600 or 3600
    self.centre0 = 0.5
    self.angle = 0.5
    self.perFacet = 1400 / self.pace
    self.timeLimit = 20000 + self.n * 4000
    self.toolSize = 40
    self.loopSoundName = "TWA_Grind"
    self.hint = getText("IGUI_TWA_MG_Facet_Hint")
    self.hint2 = getText(self.fine and "IGUI_TWA_MG_Facet_Hint2_fine" or "IGUI_TWA_MG_Facet_Hint2")
    self.gemCol = ({ { r = 0.3, g = 0.55, b = 0.95 }, { r = 0.9, g = 0.2, b = 0.32 }, { r = 0.25, g = 0.8, b = 0.45 }, { r = 0.65, g = 0.35, b = 0.9 }, { r = 0.95, g = 0.72, b = 0.2 } })[ZombRand(5) + 1]
end

function TWAFacetGame:centre()
    return self.centre0 + self:drift(self.fine and 0.22 or 0.18, self.period)
end

function TWAFacetGame:updateGame(dt)
    if self.dragging and self.hy then
        self.angle = B.clamp(1 - (self.hy - GY) / GH, 0, 1)
        local off = math.abs(self.angle - self:centre())
        if off <= self.half then
            self.cut = self.cut + dt / self.perFacet
            if ZombRand(3) == 0 then self:burst("spark", 280, 180, 1, { speed = 0.2, ttl = 250, col = C.steam }) end
        elseif off > self.half * 3 then
            self:spend(dt * 0.0003, getText("IGUI_TWA_MG_Facet_Chip"), true)
            if ZombRand(6) == 0 then self:burst("chip", 280, 180, 2, { col = self.gemCol }) end
        else
            self:spend(dt * 0.00012, getText("IGUI_TWA_MG_Facet_Angle"), true)
        end
        if self.cut >= 1 then
            self.cut = 0
            self.idx = self.idx + 1
            self:burst("ring", 280, 180, 1, { size = 10, grow = 0.12, ttl = 350, col = C.good })
            if self.idx > self.n then self:succeed(getText("IGUI_TWA_MG_Facet_Done")) end
        end
    end
    self.progress = math.min(1, (self.idx - 1 + self.cut) / self.n)
end

function TWAFacetGame:renderGame()
    -- The lap (a spinning disc) and the gem held on it, seen from above.
    -- Round 16: a polished lap with turning grooves and a real brilliant
    -- whose kite facets turn from frosted to cut one by one.
    local cx, cy, R = 280, 180, 130
    self:woodBoard(0, 0, 620, 350, { seed = 22, knots = 2, tint = { r = 0.26, g = 0.18, b = 0.11 } })
    self:disc(cx + 5, cy + 8, R + 10, 0.4, { r = 0, g = 0, b = 0 }, 48)
    self:disc(cx, cy, R + 8, 1, { r = 0.22, g = 0.23, b = 0.26 }, 48)
    for i = 0, 7 do
        local k = i / 7
        self:disc(cx, cy, R * (1 - k * 0.85), 1, { r = 0.5 + 0.18 * math.sin(k * 5), g = 0.52 + 0.18 * math.sin(k * 5), b = 0.58 + 0.16 * math.sin(k * 5) }, 48)
    end
    local spin = self.elapsed * 0.01
    for i = 0, 17 do
        local a = spin + i * 0.349
        self:line(cx + math.cos(a) * 24, cy + math.sin(a) * 24, cx + math.cos(a + 0.4) * R, cy + math.sin(a + 0.4) * R, 1, 0.12, C.line)
    end
    self:quad(cx - R * 0.7, cy - R * 0.2, cx - R * 0.2, cy - R * 0.7, cx - R * 0.1, cy - R * 0.6, cx - R * 0.6, cy - R * 0.1, 0.12, 1, 1, 1)
    -- the dop stick holding the gem
    self:line(cx + 60, cy - 60, cx + 200, cy - 150, 12, 1, { r = 0.32, g = 0.2, b = 0.1 })
    self:line(cx + 60, cy - 60, cx + 200, cy - 150, 3, 0.4, { r = 0.6, g = 0.42, b = 0.25 })
    self:gemBrilliant(cx, cy, 76, self.gemCol, { m = self.n, done = self.idx - 1, current = self.idx, cut = self.cut, seed = 7 })
    -- the angle gauge
    self:rect(GX - 3, GY - 3, 30, GH + 6, 1, { r = 0.35, g = 0.3, b = 0.22 })
    self:rect(GX, GY, 24, GH, 1, C.dark)
    local c = self:centre()
    local function yOf(v) return GY + GH * (1 - v) end
    self:rect(GX, yOf(c + self.half), 24, yOf(c - self.half) - yOf(c + self.half), 0.85, C.good)
    self:line(GX - 8, yOf(self.angle), GX + 32, yOf(self.angle), 3, 1, C.line)
    self:textC(getText("IGUI_TWA_MG_Facet_Angle_Label"), GX + 12, GY - 20, C.faint)
    self:textC(string.format("%d / %d", math.min(self.idx, self.n), self.n), cx, 330, C.line, 0.9)
end

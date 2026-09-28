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
    self.gemCol = ({ { r = 0.3, g = 0.55, b = 0.95 }, { r = 0.9, g = 0.25, b = 0.35 }, { r = 0.35, g = 0.8, b = 0.5 } })[ZombRand(3) + 1]
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
    local cx, cy, R = 280, 180, 130
    self:disc(cx, cy, R + 6, 1, { r = 0.25, g = 0.26, b = 0.3 }, 40)
    self:disc(cx, cy, R, 1, { r = 0.45, g = 0.47, b = 0.52 }, 40)
    local spin = self.elapsed * 0.01
    for i = 0, 11 do
        local a = spin + i * 0.5236
        self:line(cx + math.cos(a) * 20, cy + math.sin(a) * 20, cx + math.cos(a) * R, cy + math.sin(a) * R, 1, 0.25, C.line)
    end
    -- the gem: n facets around a table, cut ones bright, the current one pulsing
    local r1, r2 = 70, 34
    for i = 1, self.n do
        local a1 = (i - 1) / self.n * 6.2832 - 1.5708
        local a2 = i / self.n * 6.2832 - 1.5708
        local col = self.gemCol
        local k = 0.45
        if i < self.idx then k = 0.9 + 0.2 * math.cos(a1 + 2.4) end
        if i == self.idx then k = 0.6 + 0.3 * math.abs(math.sin(self.elapsed * 0.008)) + 0.4 * self.cut end
        self:quad(cx + math.cos(a1) * r2, cy + math.sin(a1) * r2, cx + math.cos(a1) * r1, cy + math.sin(a1) * r1,
            cx + math.cos(a2) * r1, cy + math.sin(a2) * r1, cx + math.cos(a2) * r2, cy + math.sin(a2) * r2,
            1, math.min(1, col.r * k), math.min(1, col.g * k), math.min(1, col.b * k))
        self:line(cx + math.cos(a1) * r2, cy + math.sin(a1) * r2, cx + math.cos(a1) * r1, cy + math.sin(a1) * r1, 1, 0.6, C.dark)
    end
    self:disc(cx, cy, r2, 1, { r = math.min(1, self.gemCol.r * 1.2), g = math.min(1, self.gemCol.g * 1.2), b = math.min(1, self.gemCol.b * 1.2) }, 24)
    self:disc(cx - 10, cy - 12, 6, 0.8, { r = 1, g = 1, b = 1 }, 10)
    -- the angle gauge
    self:rect(GX, GY, 24, GH, 1, C.dark)
    local c = self:centre()
    local function yOf(v) return GY + GH * (1 - v) end
    self:rect(GX, yOf(c + self.half), 24, yOf(c - self.half) - yOf(c + self.half), 0.85, C.good)
    self:line(GX - 8, yOf(self.angle), GX + 32, yOf(self.angle), 3, 1, C.line)
    self:textC(getText("IGUI_TWA_MG_Facet_Angle_Label"), GX + 12, GY - 20, C.faint)
    self:textC(string.format("%d / %d", math.min(self.idx, self.n), self.n), cx, 330, C.line, 0.9)
end

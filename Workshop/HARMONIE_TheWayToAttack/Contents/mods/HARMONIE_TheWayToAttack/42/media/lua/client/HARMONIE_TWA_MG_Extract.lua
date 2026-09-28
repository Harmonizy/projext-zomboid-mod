--============================================================================
-- HARMONIE_TheWayToAttack -- EXTRACT minigame (client)
--
-- Boring a hole straight and slow, then drawing the bit back out: DrillCore.
-- Idea taken from Casualties Undead's shrapnel/bullet extraction (request
-- 2026-09-28, "ชอบไอเดียมินิเกม 3"), written from scratch.
--
--   1. DRILL IN: put the bit on the gold mark and hold, drawing it DOWN the
--      guide to the depth line. Keep it inside the guide -- a bit that leans
--      snags, and leaning far snaps it out of the hole (start again). Faster
--      than the speed limit and it chatters and costs quality.
-- Round 6: the guide is half as wide, the block stands upright (grain
-- running up and down) and the hole goes deeper -- still stopping short
-- of the far end -- and a bored hole stays bored while the bit comes out.
--
--   2. DRAW OUT: without letting go, draw it back UP out of the hole, just
--      as straight and just as slow. Letting go half way leaves the bit
--      jammed: take hold again at the bit and carry on.
--============================================================================

require "HARMONIE_TWA_MinigameBase"

TWAExtractGame = TWAMinigameBase:derive("TWAExtractGame")

local B = TWAMinigameBase
local C = B.COL

function TWAExtractGame:onStart()
    self.holes = math.max(1, math.min(3, 1 + math.floor(self.req / 2)))
    self.doneHoles = 0
    self.lateral = 4 * self.tol
    self.speedLimit = 0.12 * self.tol / self.pace
    -- The block: upright, the hole bored from its top end.
    self.bx, self.by, self.bw, self.bh = 230, 70, 170, 285
    self.depthPx = 225
    self:newHole()
    self.timeLimit = 25000 + self.holes * 15000
    self.toolSize = 44
    if not self.realTool then self.toolTex = B.itemTex("Drill_OldFashioned") or self.toolTex end
    self.hint = getText("IGUI_TWA_MG_Extract_Hint")
    self.hint2 = getText("IGUI_TWA_MG_Extract_Hint2")
end

function TWAExtractGame:holeX(i)
    return self.bx + self.bw * (i + 0.5) / self.holes
end

function TWAExtractGame:newHole()
    self.hx0 = self:holeX(self.doneHoles)
    self.topY = self.by
    self.bored = 0      -- deepest the bit has gone in this hole
    self.phase = "in"
    self.depth = 0      -- 0..1 of depthPx
    self.holding = false
end

function TWAExtractGame:bitY()
    return self.topY + self.depth * self.depthPx
end

function TWAExtractGame:onGrab(x, y)
    local bx, by = self.hx0, self:bitY()
    if B.dist(x, y, bx, by) > 24 then
        self:flash(getText(self.phase == "in" and self.depth == 0 and "IGUI_TWA_MG_Extract_StartHere"
            or "IGUI_TWA_MG_Extract_TakeBit"), false, 800)
        return
    end
    self.holding = true
end

function TWAExtractGame:onRelease()
    if self.holding and (self.depth > 0.02 and self.depth < 0.98 or self.phase == "out") then
        self:flash(getText("IGUI_TWA_MG_Extract_Jammed"), true, 900)
    end
    self.holding = false
end

function TWAExtractGame:onDrag(x, y, dt)
    if not self.holding then return end
    local off = math.abs(x - self.hx0)
    if off > self.lateral * 3 then
        self:spend(0.08, getText("IGUI_TWA_MG_Extract_Snapped"))
        self:burst("chip", self.hx0, self:bitY(), 8, { col = C.metal })
        self.holding = false
        if self.phase == "in" then self.depth = 0 end
        return
    elseif off > self.lateral then
        self:spend(dt * 0.0004 * (off / self.lateral), getText("IGUI_TWA_MG_Extract_Lean"), true)
    end
    local vy = math.abs(self.handVY or 0)
    if vy > self.speedLimit then
        self:tooFast(dt * 0.0005 * (vy / self.speedLimit - 1), getText("IGUI_TWA_MG_Extract_TooFast"), x, y)
    end

    -- Only along the direction of the current phase, never jumping ahead.
    local want = B.clamp((y - self.topY) / self.depthPx, 0, 1)
    if self.phase == "in" then
        if want > self.depth and want - self.depth < 0.15 then
            self.depth = want
            self.bored = math.max(self.bored, want)
            if ZombRand(3) == 0 then self:burst("dust", self.hx0 + ZombRandFloat(-6, 6), self.topY, 2) end
        end
        if self.depth >= 0.98 then
            self.depth = 1
            self.phase = "out"
            self:flash(getText("IGUI_TWA_MG_Extract_NowOut"), false, 900)
        end
    else
        if want < self.depth and self.depth - want < 0.15 then self.depth = want end
        if self.depth <= 0.02 then
            self.doneHoles = self.doneHoles + 1
            self:burst("ring", self.hx0, self.topY, 1, { size = 8, grow = 0.1, ttl = 350, col = C.good })
            if self.doneHoles >= self.holes then
                self:succeed(getText("IGUI_TWA_MG_Extract_Done"))
            else
                self:newHole()
            end
        end
    end
end

function TWAExtractGame:updateGame(dt)
    local part = self.phase == "in" and self.depth * 0.5 or (0.5 + (1 - self.depth) * 0.5)
    self.progress = math.min(1, (self.doneHoles + part) / self.holes)
end

function TWAExtractGame:renderGame()
    -- An upright block, grain running up and down, the holes bored so far
    -- and the one in work (as deep as it was bored, whether or not the bit
    -- is still in it).
    local bx, by, bw, bh = self.bx, self.by, self.bw, self.bh
    self:woodBoard(bx, by, bw, bh, { vertical = true, seed = 14, knots = 2 })
    -- End grain on top.
    self:rect(bx, by - 8, bw, 8, 1, { r = 0.58, g = 0.42, b = 0.24 })
    for r = 1, 4 do self:line(bx + 6, by - 4 + (r % 2), bx + bw - 6, by - 4 + (r % 2), 1, 0.25, C.wood2) end
    local function hole(x, depth)
        local d = depth * self.depthPx
        if d <= 0 then return end
        self:rect(x - 6, by, 12, d, 1, { r = 0.1, g = 0.06, b = 0.03 })
        self:line(x - 6, by, x - 6, by + d, 1.5, 0.8, { r = 0.3, g = 0.2, b = 0.1 })
        self:line(x + 6, by, x + 6, by + d, 1.5, 0.6, { r = 0.62, g = 0.46, b = 0.28 })
        self:disc(x, by + d, 6, 1, { r = 0.1, g = 0.06, b = 0.03 }, 10)
    end
    for i = 0, self.doneHoles - 1 do hole(self:holeX(i), 1) end
    local x = self.hx0
    hole(x, self.bored or 0)
    -- Guide and depth line.
    local col = self.holding and C.guide or C.faint
    self:line(x - self.lateral, by - 40, x - self.lateral, by + self.depthPx, 1, 0.6, col)
    self:line(x + self.lateral, by - 40, x + self.lateral, by + self.depthPx, 1, 0.6, col)
    self:line(x - 26, by + self.depthPx, x + 26, by + self.depthPx, 2, 0.9, C.bad)
    -- The bit: a twisted steel shank down to its tip.
    local ty = self:bitY()
    self:line(x, ty - 70, x, ty, 5, 1, { r = 0.5, g = 0.52, b = 0.56 })
    for k = 0, 9 do
        local yy = ty - 66 + k * 7
        self:line(x - 2.5, yy, x + 2.5, yy + 4, 1.2, 0.8, { r = 0.8, g = 0.82, b = 0.86 })
    end
    self:quad(x - 2.5, ty, x + 2.5, ty, x + 0.5, ty + 5, x - 0.5, ty + 5, 1, 0.75, 0.77, 0.8)
    if not self.holding and not self.word then
        local pulse = 1 + 0.15 * math.sin(self.elapsed * 0.008)
        self:ring(x, ty, 12 * pulse, 2, 1, C.guide, 16)
    end
    if self.workTex then self:tex(self.workTex, 540, 20, 60, 60, 0.55) end
    self:textC(string.format("%d / %d", self.doneHoles, self.holes), 480, 200, C.line, 0.9)
end

--============================================================================
-- HARMONIE_TheWayToAttack -- SUTURE minigame (client)
--
-- Threading sinew/line through a binding and pulling each stitch tight:
-- StringSinew, ReinforcedBind. Idea taken from Casualties Undead's suture
-- game (request 2026-09-28, "ชอบไอเดียมินิเกม 2"), written from scratch.
--
-- Every stitch is two moves:
--   1. PIERCE: pick the needle up at the gold ring above the seam and draw
--      it along the dashed arc -- in at the top hole, under, out at the
--      bottom hole. Stray off the arc and it costs; far off and the needle
--      slips out (start the stitch again).
--   2. PULL: hold and draw the thread away from the exit hole. The further,
--      the tighter (the gauge). Let go inside the green band: slack and you
--      pull again, past the red line the thread cuts in and must be pulled
--      again too.
--============================================================================

require "HARMONIE_TWA_MinigameBase"

TWASutureGame = TWAMinigameBase:derive("TWASutureGame")

local B = TWAMinigameBase
local C = B.COL

local THREAD = { r = 0.86, g = 0.78, b = 0.60 }
local PULL_FULL = 220      -- px of pull for a full gauge
local ARC_STEPS = 14

function TWASutureGame:onStart()
    self.need = 3 + math.floor(self.req / 2)
    self.done = 0
    self.band = 12 * self.tol
    self.lo, self.hi = 0.55, 0.55 + 0.18 * self.tol
    self.tear = math.min(0.98, self.hi + 0.12)
    self.phase = "pierce"
    self.timeLimit = 25000 + self.need * 9000
    self.toolSize = 36
    self:layoutStitch()
    self.hint = getText("IGUI_TWA_MG_Suture_Hint")
    self.hint2 = getText("IGUI_TWA_MG_Suture_Hint2")
end

-- Hole pair for the current stitch, spaced along the seam, and the arc
-- the needle follows between them (bulging to the right, "under" the work).
function TWASutureGame:layoutStitch()
    local x = 170 + self.done * (300 / math.max(1, self.need - 1))
    self.topX, self.topY = x, 130
    self.botX, self.botY = x, 250
    self.arc = {}
    for i = 0, ARC_STEPS do
        local a = math.pi * (i / ARC_STEPS)
        self.arc[#self.arc + 1] = { x + math.sin(a) * 55, 190 - math.cos(a) * 60 }
    end
    self.startX, self.startY = self.topX - 30, self.topY - 40
    self.along = 0
    self.tension = 0
end

local function projectOnPolyline(pts, x, y)
    local total = 0
    local lens = {}
    for i = 1, #pts - 1 do
        lens[i] = B.dist(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2])
        total = total + lens[i]
    end
    local acc, bestT, bestD = 0, 0, math.huge
    for i = 1, #pts - 1 do
        local ax, ay, bx, by = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
        local dx, dy = bx - ax, by - ay
        local u = B.clamp(((x - ax) * dx + (y - ay) * dy) / (lens[i] * lens[i]), 0, 1)
        local d = B.dist(x, y, ax + dx * u, ay + dy * u)
        if d < bestD then bestD, bestT = d, (acc + u * lens[i]) / total end
        acc = acc + lens[i]
    end
    return bestT, bestD
end

function TWASutureGame:onGrab(x, y)
    if self.phase == "pierce" then
        if B.dist(x, y, self.startX, self.startY) > 30 and B.dist(x, y, self.arc[1][1], self.arc[1][2]) > 30 then
            self:flash(getText("IGUI_TWA_MG_Suture_StartHere"), false, 800)
            return
        end
        self.piercing = true
    else
        self.pulling = true
    end
end

function TWASutureGame:onDrag(x, y, dt)
    if self.phase == "pierce" and self.piercing then
        local t, d = projectOnPolyline(self.arc, x, y)
        if d > self.band * 3 then
            self:spend(0.05, getText("IGUI_TWA_MG_Suture_Slipped"))
            self.piercing = false
            self.along = 0
            return
        elseif d > self.band then
            self:spend(dt * 0.0003 * (d / self.band), getText("IGUI_TWA_MG_Suture_OffArc"), true)
        end
        if (self.handSpeed or 0) > 0.7 * self.tol then
            self:tooFast(dt * 0.0003, getText("IGUI_TWA_MG_Suture_TooFast"), x, y)
        end
        if t > self.along and t - self.along < 0.25 then self.along = t end
        if self.along >= 0.97 then
            self.piercing = false
            self.phase = "pull"
            self:burst("ring", self.botX, self.botY, 1, { size = 6, grow = 0.08, ttl = 300, col = C.good })
            self:flash(getText("IGUI_TWA_MG_Suture_NowPull"), false, 900)
        end
    elseif self.phase == "pull" and self.pulling then
        self.tension = B.clamp(B.dist(x, y, self.botX, self.botY) / PULL_FULL, 0, 1.1)
        if self.tension > self.tear then
            self:spend(0.08, getText("IGUI_TWA_MG_Suture_Tore"))
            self:burst("chip", self.botX, self.botY, 6, { col = THREAD })
            self.pulling = false
            self.tension = 0
        end
    end
end

function TWASutureGame:onRelease()
    if self.phase == "pierce" then
        if self.piercing and self.along > 0.05 then
            self:spend(0.03, getText("IGUI_TWA_MG_Suture_Slipped"))
            self.along = 0
        end
        self.piercing = false
        return
    end
    if not self.pulling then return end
    self.pulling = false
    if self.tension < self.lo then
        self:spend(0.02, getText("IGUI_TWA_MG_Suture_Slack"))
        self.tension = 0
        return
    end
    -- Set -- a little over the green band holds but bites into the work.
    if self.tension > self.hi then
        self:spend(0.05, getText("IGUI_TWA_MG_Suture_TooTight"))
    end
    self.done = self.done + 1
    self:burst("ring", self.botX, self.botY, 1, { size = 8, grow = 0.1, ttl = 350, col = C.good })
    if self.done >= self.need then
        self:succeed(getText("IGUI_TWA_MG_Suture_Done"))
    else
        self.phase = "pierce"
        self:layoutStitch()
    end
end

function TWASutureGame:updateGame(dt)
    local part = self.phase == "pierce" and self.along * 0.6 or (0.6 + 0.4 * math.min(1, self.tension / self.lo))
    self.progress = math.min(1, (self.done + part) / self.need)
end

function TWASutureGame:renderGame()
    -- The binding: a strap over a wooden handle, the seam running across.
    self:rect(120, 110, 380, 160, 1, C.wood)
    self:rect(120, 150, 380, 80, 1, { r = 0.5, g = 0.32, b = 0.17 })
    self:line(120, 190, 500, 190, 1, 0.5, C.wood2)
    -- Stitches already set.
    for i = 0, self.done - 1 do
        local x = 170 + i * (300 / math.max(1, self.need - 1))
        self:line(x, 130, x, 250, 3, 1, THREAD)
        self:line(x - 8, 130, x + 8, 130, 2, 1, THREAD)
        self:line(x - 8, 250, x + 8, 250, 2, 1, THREAD)
    end
    -- Current holes.
    self:disc(self.topX, self.topY, 5, 1, C.dark, 10)
    self:disc(self.botX, self.botY, 5, 1, C.dark, 10)
    self:ring(self.topX, self.topY, 7, 2, 1, C.guide, 12)
    self:ring(self.botX, self.botY, 7, 2, 1, C.guide, 12)
    if self.workTex then self:tex(self.workTex, 540, 20, 60, 60, 0.55) end

    if self.phase == "pierce" and not self.word then
        -- The arc to follow, dashed; the part already sewn solid.
        for i = 1, #self.arc - 1, 2 do
            self:line(self.arc[i][1], self.arc[i][2], self.arc[i + 1][1], self.arc[i + 1][2], 2, 0.6, C.guide)
        end
        local n = math.floor(self.along * (#self.arc - 1))
        for i = 1, n do
            self:line(self.arc[i][1], self.arc[i][2], self.arc[i + 1][1], self.arc[i + 1][2], 3, 1, THREAD)
        end
        if not self.piercing then
            local pulse = 1 + 0.15 * math.sin(self.elapsed * 0.008)
            self:ring(self.startX, self.startY, 12 * pulse, 2, 1, C.guide, 18)
        end
    elseif self.phase == "pull" then
        -- Thread from the exit hole to the hand, and the tension gauge.
        if self.hx and self.pulling then
            self:line(self.botX, self.botY, self.hx, self.hy, 2, 1, THREAD)
        end
        local gx, gy, gw = 150, 300, 320
        self:rect(gx, gy, gw, 12, 1, C.dark)
        self:rect(gx + gw * self.lo, gy, gw * (self.hi - self.lo), 12, 0.8, C.good)
        self:line(gx + gw * self.tear, gy - 5, gx + gw * self.tear, gy + 17, 2, 1, C.bad)
        self:rect(gx, gy + 3, gw * math.min(1, self.tension), 6, 1, C.line)
    end
end

-- The needle at the hand.
function TWASutureGame:drawTool()
    if not self.hx then return end
    local x, y = self.hx, self.hy
    self:line(x, y, x + 22, y - 22, 2, 1, C.metal)
    self:ring(x + 22, y - 22, 3, 1, 1, C.metal, 8)
    self:disc(x, y, 2.5, 1, C.guide, 10)
end

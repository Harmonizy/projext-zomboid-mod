--============================================================================
-- HARMONIE_TheWayToAttack -- SUTURE minigame (client)
--
-- Threading sinew/line through a binding and pulling each stitch tight:
-- StringSinew, ReinforcedBind. Idea taken from Casualties Undead's suture
-- game (request 2026-09-28, "ชอบไอเดียมินิเกม 2"), written from scratch.
--
-- Round 6 ("มินิเกม ร้อยเอ็น และ พันแน่นหนา ยังดูแปลกๆ"): redrawn as what it
-- is -- a leather wrap on a wooden handle, sewn shut along its seam with
-- diagonal stitches -- instead of a big sideways arc across a flat box.
--
-- Every stitch is two moves:
--   1. PIERCE: pick the needle up at the gold ring and draw it along the
--      dashed line -- in at the hole above the seam, across, out at the
--      hole below it. Stray off the arc and it costs; far off and the needle
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

local SEAM_Y = 190

-- Where stitch i sits: its hole above the seam and its hole below it,
-- offset so every stitch runs on the same diagonal.
function TWASutureGame:stitchHoles(i)
    local x = 175 + i * (270 / math.max(1, self.need - 1))
    return x - 12, SEAM_Y - 34, x + 12, SEAM_Y + 34
end

-- Hole pair for the current stitch, and the path the needle follows
-- between them (a gentle curve: in, across under the seam, out).
function TWASutureGame:layoutStitch()
    self.topX, self.topY, self.botX, self.botY = self:stitchHoles(self.done)
    self.arc = {}
    for i = 0, ARC_STEPS do
        local u = i / ARC_STEPS
        local bulge = math.sin(u * math.pi) * 10
        self.arc[#self.arc + 1] = { self.topX + (self.botX - self.topX) * u + bulge,
                                    self.topY + (self.botY - self.topY) * u }
    end
    self.startX, self.startY = self.topX - 22, self.topY - 30
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

function TWASutureGame:drawStitch(i)
    local tx, ty, bx, by = self:stitchHoles(i)
    self:line(tx + 1, ty + 1.5, bx + 1, by + 1.5, 3, 0.45, C.dark)   -- shadow
    self:line(tx, ty, bx, by, 3, 1, THREAD)
    self:line(tx, ty - 0.8, bx, by - 0.8, 1, 0.7, { r = 1, g = 0.95, b = 0.82 })
end

function TWASutureGame:drawHole(x, y, active)
    self:disc(x, y, 4.5, 1, { r = 0.2, g = 0.11, b = 0.05 }, 10)
    self:ring(x, y, 5, 1, 0.8, { r = 0.62, g = 0.42, b = 0.24 }, 10)
    if active then self:ring(x, y, 9, 2, 0.9, C.guide, 14) end
end

function TWASutureGame:renderGame()
    -- The wooden handle, and the leather wrapped round it: two edges of
    -- the wrap meet along the seam in the middle.
    self:woodBoard(90, 140, 440, 100, { seed = 12, knots = 1 })
    self:leather(130, 128, 360, SEAM_Y - 128 - 2)
    self:leather(130, SEAM_Y + 2, 360, 252 - SEAM_Y - 2, { tint = { r = 0.42, g = 0.25, b = 0.13 } })
    self:line(130, SEAM_Y, 490, SEAM_Y, 3, 0.9, { r = 0.12, g = 0.07, b = 0.03 })
    -- Stitches already set.
    for i = 0, self.done - 1 do self:drawStitch(i) end
    -- The holes still to come, faint, so the row reads as a seam.
    for i = self.done + 1, self.need - 1 do
        local tx, ty, bx, by = self:stitchHoles(i)
        self:disc(tx, ty, 2, 0.5, C.dark, 8)
        self:disc(bx, by, 2, 0.5, C.dark, 8)
    end
    self:drawHole(self.topX, self.topY, self.phase == "pierce")
    self:drawHole(self.botX, self.botY, self.phase == "pull")
    if self.workTex then self:tex(self.workTex, 540, 20, 60, 60, 0.55) end

    if self.phase == "pierce" and not self.word then
        -- The line to follow, dashed; the part already sewn solid.
        for i = 1, #self.arc - 1, 2 do
            self:line(self.arc[i][1], self.arc[i][2], self.arc[i + 1][1], self.arc[i + 1][2], 2, 0.7, C.guide)
        end
        local n = math.floor(self.along * (#self.arc - 1))
        for i = 1, n do
            self:line(self.arc[i][1], self.arc[i][2], self.arc[i + 1][1], self.arc[i + 1][2], 3, 1, THREAD)
        end
        if not self.piercing then
            local pulse = 1 + 0.15 * math.sin(self.elapsed * 0.008)
            self:ring(self.startX, self.startY, 12 * pulse, 2, 1, C.guide, 18)
            self:line(self.startX, self.startY, self.topX, self.topY, 1, 0.5, C.guide)
        end
    elseif self.phase == "pull" then
        -- This stitch's thread through its holes, and out to the hand.
        self:drawStitch(self.done)
        if self.hx and self.pulling then
            self:line(self.botX, self.botY, self.hx, self.hy, 2, 1, THREAD)
            -- The leather puckers round the hole as the thread tightens.
            local t = self.tension
            local col = t > self.hi and C.bad or { r = 0.25, g = 0.14, b = 0.06 }
            for k = 0, 5 do
                local a = k / 6 * 6.2832
                local r0, r1 = 6, 6 + 16 * math.min(1.2, t)
                self:line(self.botX + math.cos(a) * r0, self.botY + math.sin(a) * r0,
                    self.botX + math.cos(a) * r1, self.botY + math.sin(a) * r1, 1.2, 0.6, col)
            end
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

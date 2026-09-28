--============================================================================
-- HARMONIE_TheWayToAttack -- INCISION minigame (client)
--
-- Cutting along a line at the right depth: carving a handle (MakeHandle,
-- MakeLongHandle) and engraving a pattern (EngravePattern). Idea taken from
-- Casualties Undead's incision game (request 2026-09-28, "ชอบไอเดียมินิเกม
-- 6"), written from scratch.
--
-- Hold and draw the blade along the guide from the gold start mark. The
-- DEPTH follows your speed: slow digs deep, fast skims. Keep the depth
-- needle in the green band as you go -- every stretch of the cut is scored
-- (shallow = grey, right = green, too deep = red), and going right through
-- (the red line) gouges the work. Carving takes several passes.
--============================================================================

require "HARMONIE_TWA_MinigameBase"

TWAIncisionGame = TWAMinigameBase:derive("TWAIncisionGame")

local B = TWAMinigameBase
local C = B.COL

local function pathFor(variant)
    if variant == "engrave" then
        -- Round 8 ("สลักลวดลายให้วาดเป็นก้นหอยไปหาตรงกลาง"): a spiral from
        -- the outside in to the centre, two turns, 50 px between turns --
        -- wider than the slip distance, so the cut can't jump a turn.
        local pts, cx, cy = {}, 310, 195
        local turns, r0, r1, n = 2, 110, 10, 64
        for i = 0, n do
            local u = i / n
            local a = -math.pi / 2 + u * turns * 2 * math.pi
            local r = r0 + (r1 - r0) * u
            pts[#pts + 1] = { cx + math.cos(a) * r, cy + math.sin(a) * r }
        end
        return pts
    end
    return { { 110, 200 }, { 510, 200 } }
end

function TWAIncisionGame:onStart()
    self.engrave = self.variant == "engrave"
    self.path = pathFor(self.variant)
    self.seg, self.total = {}, 0
    for i = 1, #self.path - 1 do
        local a, b = self.path[i], self.path[i + 1]
        local len = B.dist(a[1], a[2], b[1], b[2])
        self.seg[i] = { a = a, b = b, len = len, start = self.total }
        self.total = self.total + len
    end
    self.passes = self.engrave and 1 or (2 + math.floor(self.req / 3))
    self.done = 0
    self.band = 8 * self.tol
    -- Depth model: the depth eases towards 1.25 - speed/vref. Around
    -- 0.35-0.65 x vref lands in the band.
    self.vref = 0.9 / self.pace
    self.dLo, self.dHi = 0.45, 0.45 + 0.3 * self.tol
    self.through = 1.05
    if self.engrave then
        -- Round 8: the depth band covers 90% of the gauge (0..1.3).
        -- (0.10..1.27 = 1.17 of 1.3; holding still settles at 1.25, inside.)
        self.dLo, self.dHi = 0.10, 1.27
        self.through = 1.29
    end
    self.depth = 0
    self.timeLimit = 25000 + self.passes * 12000
    self.toolSize = 44
    if not self.realTool then self.toolTex = B.itemTex("KnifeSushi") or self.toolTex end
    self:newPass()
    self.hint = getText("IGUI_TWA_MG_Incision_Hint")
    self.hint2 = getText(self.engrave and "IGUI_TWA_MG_Incision_Hint_engrave" or "IGUI_TWA_MG_Incision_Hint_carve")
end

function TWAIncisionGame:newPass()
    self.along = 0
    self.active = false
    self.marks = {} -- { t, class } along this pass
end

function TWAIncisionGame:pointAt(t)
    local target = t * self.total
    for i, s in ipairs(self.seg) do
        if target <= s.start + s.len or i == #self.seg then
            local u = B.clamp((target - s.start) / s.len, 0, 1)
            return s.a[1] + (s.b[1] - s.a[1]) * u, s.a[2] + (s.b[2] - s.a[2]) * u
        end
    end
end

function TWAIncisionGame:project(x, y)
    local bestT, bestD = 0, math.huge
    for _, s in ipairs(self.seg) do
        local ax, ay, bx, by = s.a[1], s.a[2], s.b[1], s.b[2]
        local dx, dy = bx - ax, by - ay
        local u = B.clamp(((x - ax) * dx + (y - ay) * dy) / (s.len * s.len), 0, 1)
        local d = B.dist(x, y, ax + dx * u, ay + dy * u)
        if d < bestD then bestD, bestT = d, (s.start + u * s.len) / self.total end
    end
    return bestT, bestD
end

function TWAIncisionGame:onGrab(x, y)
    local sx, sy = self:pointAt(0)
    if B.dist(x, y, sx, sy) > self.band * 3 then
        self:flash(getText("IGUI_TWA_MG_Incision_StartHere"), false, 800)
        return
    end
    self.active = true
    self.depth = 0
end

function TWAIncisionGame:onRelease()
    if self.active and self.along > 0.05 then
        self:spend(0.03, getText("IGUI_TWA_MG_Incision_Lifted"))
        self:newPass()
    end
    self.active = false
end

function TWAIncisionGame:onDrag(x, y, dt)
    if not self.active then return end
    local t, d = self:project(x, y)
    if d > self.band * 3 then
        self:spend(0.06, getText("IGUI_TWA_MG_Incision_Slipped"))
        self:newPass()
        return
    elseif d > self.band then
        self:spend(dt * 0.0003 * (d / self.band), getText("IGUI_TWA_MG_Incision_OffLine"), true)
    end

    local speed = self.handSpeed or 0
    local target = B.clamp(1.25 - speed / self.vref, 0, 1.3)
    self.depth = self.depth + (target - self.depth) * math.min(1, dt / 180)

    if self.depth > self.through then
        self:spend(dt * 0.0006, getText("IGUI_TWA_MG_Incision_Through"), true)
        if ZombRand(3) == 0 then self:burst("chip", x, y, 2, { col = C.wood }) end
    elseif self.depth > self.dHi then
        self:spend(dt * 0.00018, getText("IGUI_TWA_MG_Incision_Deep"), true)
    elseif self.depth < self.dLo and self.along > 0.03 then
        self:spend(dt * 0.00018, getText("IGUI_TWA_MG_Incision_Shallow"), true)
    end

    if t > self.along and t - self.along < 0.2 then
        self.along = t
        local class = self.depth < self.dLo and "shallow" or (self.depth > self.dHi and "deep" or "good")
        self.marks[#self.marks + 1] = { t = t, class = class }
        if ZombRand(4) == 0 then self:burst("chip", x, y, 1, { col = self.engrave and C.metal or C.wood, size = 2 }) end
    end
    if self.along >= 0.97 then
        self.done = self.done + 1
        self:burst("ring", x, y, 1, { size = 6, grow = 0.1, ttl = 350, col = C.good })
        if self.done >= self.passes then
            self:succeed(getText("IGUI_TWA_MG_Incision_Done"))
        else
            self:flash(getText("IGUI_TWA_MG_Incision_Again"), false, 800)
            self:newPass()
        end
    end
end

function TWAIncisionGame:updateGame(dt)
    if not self.active then self.depth = math.max(0, self.depth - dt / 400) end
    self.progress = math.min(1, (self.done + self.along) / self.passes)
end

local CLASS_COL = {
    shallow = { r = 0.6, g = 0.6, b = 0.6 },
    good = C.good,
    deep = C.bad,
}

function TWAIncisionGame:renderGame()
    if self.engrave then
        self:metalPlate(180, 65, 260, 260, { seed = 4 })
    else
        self:woodBoard(100, 182, 420, 36, { seed = 6, knots = 1 })
        local shaved = 420 * self.done / self.passes
        if shaved > 1 then self:woodBoard(100, 182, shaved, 36, { tint = { r = 0.66, g = 0.5, b = 0.3 }, seed = 7, knots = 0 }) end
    end
    -- Guide band.
    for _, s in ipairs(self.seg) do
        local dx, dy = s.b[1] - s.a[1], s.b[2] - s.a[2]
        local nx, ny = -dy / s.len * self.band, dx / s.len * self.band
        local col = self.active and C.guide or C.faint
        self:line(s.a[1] + nx, s.a[2] + ny, s.b[1] + nx, s.b[2] + ny, 1, 0.45, col)
        self:line(s.a[1] - nx, s.a[2] - ny, s.b[1] - nx, s.b[2] - ny, 1, 0.45, col)
    end
    -- The cut so far, coloured by how deep each stretch went.
    local px, py
    for _, m in ipairs(self.marks) do
        local x, y = self:pointAt(m.t)
        if px then self:line(px, py, x, y, 3, 1, CLASS_COL[m.class]) end
        px, py = x, y
    end
    local sx, sy = self:pointAt(0)
    if not self.active and not self.word then
        local pulse = 1 + 0.15 * math.sin(self.elapsed * 0.008)
        self:ring(sx, sy, 10 * pulse, 2, 1, C.guide, 18)
    end
    -- Depth meter on the right.
    local gx, gy, gh = 560, 110, 180
    local function yOf(v) return gy + gh * math.min(1.3, v) / 1.3 end
    self:rect(gx, gy, 16, gh, 1, C.dark)
    self:rect(gx, yOf(self.dLo), 16, yOf(self.dHi) - yOf(self.dLo), 0.85, C.good)
    self:line(gx - 4, yOf(self.through), gx + 20, yOf(self.through), 2, 1, C.bad)
    self:line(gx - 6, yOf(self.depth), gx + 22, yOf(self.depth), 3, 1, C.line)
    self:textC(getText("IGUI_TWA_MG_Incision_Depth"), gx + 8, gy - 18, C.faint)
    if self.workTex then self:tex(self.workTex, 540, 20, 50, 50, 0.55) end
    self:textC(string.format("%d / %d", self.done, self.passes), 310, 335, C.line, 0.9)
end

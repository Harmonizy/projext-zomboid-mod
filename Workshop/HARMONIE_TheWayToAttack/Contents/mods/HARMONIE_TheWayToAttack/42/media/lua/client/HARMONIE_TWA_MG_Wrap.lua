--============================================================================
-- HARMONIE_TheWayToAttack -- WRAP minigame (client)
--
-- Anything done by going round and round: wrapping cloth/leather/tape/wire/
-- sinew round a handle, turning a screwdriver or a wrench, turning a hand
-- drill, cranking a grindstone.
--
-- Hold the button and circle the hand round the work along the guide ring,
-- in the direction the arrows run. Each full turn lays one wrap. Too close
-- to the handle pulls it too tight, too far out lays it slack -- both cost
-- quality. Going the wrong way unwinds what you laid. Swinging round too
-- fast (a jump of more than a sixth of a turn at once) doesn't count.
--
-- variant "screw": turn until the gauge reaches the gold mark, then LET GO
-- -- the gauge runs on past the mark into red, and past the red line the
-- thread strips. variant "drill": turns bore the hole deeper. variant
-- "grind" (request 2026-09-28: grinding must not be the polish game): crank
-- a grindstone at a steady speed -- too slow and the stone doesn't bite,
-- too fast and the steel overheats.
--============================================================================

require "HARMONIE_TWA_MinigameBase"

TWAWrapGame = TWAMinigameBase:derive("TWAWrapGame")

local B = TWAMinigameBase
local C = B.COL

local MATERIAL = {
    cloth   = { r = 0.88, g = 0.86, b = 0.80 },
    leather = { r = 0.55, g = 0.34, b = 0.18 },
    tape    = { r = 0.62, g = 0.64, b = 0.66 },
    wire    = { r = 0.70, g = 0.72, b = 0.76 },
    sinew   = { r = 0.86, g = 0.78, b = 0.60 },
}

local TWO_PI = 6.2832
-- Kahlua (PZ) is Lua 5.1 and has math.atan2; newer Lua folds it into math.atan.
local atan2 = math.atan2 or math.atan

-- Screw: how far past snug the gauge shows, and where the thread strips.
local STRIP_AT = 0.5
-- A release this close under the mark still counts as snug (the readout
-- rounds to one decimal -- "3.0" on screen must be releasable).
local SNUG_SLACK = 0.05

-- Grind: crank speed band, turns per second.
local GRIND_LO, GRIND_HI = 0.55, 1.25

function TWAWrapGame:onStart()
    local vr = self.variant or "cloth"
    self.mat = MATERIAL[vr] or MATERIAL.cloth
    self.screw = vr == "screw"
    self.drill = vr == "drill"
    self.grind = vr == "grind"
    self.cx, self.cy = 310, 180
    -- The screw ring was bigger than the plate behind it (bug report
    -- 2026-09-28): smaller ring, bigger plate (see renderGame).
    self.R = self.screw and 55 or (self.drill and 70 or 105)
    self.band = 10 * self.tol -- halved (request 2026-09-28)
    -- Wrapping cloth: twice that again (request 2026-09-28: "กรรมวิธีพันผ้า
    -- ประกอบผ้าอยากให้โซนใหญ่กว่านี้ สองเท่า").
    if vr == "cloth" then self.band = self.band * 2 end
    if self.grind then self.band = 30 * self.tol end -- grinding judges speed, not the circle
    if self.screw then
        self.need = 3
    elseif self.drill then
        self.need = 4
    elseif self.grind then
        self.need = 6 + math.floor(self.req / 2)
    else
        self.need = 4 + math.floor(self.req / 2)
    end
    self.turns = 0
    self.lastAng = nil
    self.stripped = false
    self.omega = 0     -- smoothed turns per second (grind)
    self.wheelAng = 0
    self.timeLimit = 20000 + self.need * 6000
    self.toolSize = 46
    -- (No screwdriver override: Base.Screwdriver has no single Icon field,
    -- only IconsForTexture -- workflow.txt 8.12 -- so the real tool found in
    -- the inventory (TWAMinigameBase) or the procedure's own icon is used.)
    if self.drill and not self.realTool then self.toolTex = B.itemTex("Drill_OldFashioned") or self.toolTex end
    self.hint = getText("IGUI_TWA_MG_Wrap_Hint")
    self.hint2 = getText(self.screw and "IGUI_TWA_MG_Wrap_Hint_screw"
        or (self.drill and "IGUI_TWA_MG_Wrap_Hint_drill"
        or (self.grind and "IGUI_TWA_MG_Wrap_Hint_grind" or "IGUI_TWA_MG_Wrap_Hint_wrap")))
end

function TWAWrapGame:angleOf(x, y)
    return atan2(y - self.cy, x - self.cx)
end

function TWAWrapGame:onGrab(x, y)
    self.lastAng = self:angleOf(x, y)
end

function TWAWrapGame:onRelease()
    self.lastAng = nil
    if self.screw and self.turns >= self.need - SNUG_SLACK then
        self:succeed(getText(self.stripped and "IGUI_TWA_MG_Wrap_Stripped" or "IGUI_TWA_MG_Wrap_Snug"))
    end
end

function TWAWrapGame:onDrag(x, y, dt)
    if not self.lastAng then return end
    local ang = self:angleOf(x, y)
    local d = ang - self.lastAng
    if d > math.pi then d = d - TWO_PI elseif d < -math.pi then d = d + TWO_PI end
    self.lastAng = ang

    local r = B.dist(x, y, self.cx, self.cy)
    if r < 18 then return end -- too near the centre to read a direction

    if math.abs(d) > TWO_PI / 6 then
        self:tooFast(0.03, getText("IGUI_TWA_MG_Wrap_TooFast"), x, y)
        return
    end

    local err = r - self.R
    if math.abs(err) > self.band then
        local key = err < 0 and "IGUI_TWA_MG_Wrap_TooTight" or "IGUI_TWA_MG_Wrap_Slack"
        self:spend(dt * 0.0003 * (math.abs(err) / self.band), getText(key), true)
    end

    if d < 0 then
        -- The wrong way round unwinds it.
        self.turns = math.max(0, self.turns + d / TWO_PI)
        self.backward = (self.backward or 0) - d
        if self.backward > 0.6 then
            self.backward = 0
            self:spend(0.04, getText("IGUI_TWA_MG_Wrap_WrongWay"))
        end
        return
    end

    -- Moving forward again forgives the little back-jitters of a shaky hand;
    -- only a sustained wrong-way turn (0.6 rad in one go) is a blunder.
    self.backward = 0

    if self.grind then
        -- Crank speed, smoothed over ~0.3 s.
        local inst = dt > 0 and (d / TWO_PI) / (dt / 1000) or 0
        self.omega = self.omega + (inst - self.omega) * math.min(1, dt / 300)
        self.wheelAng = self.wheelAng + d * 3
        if self.omega < GRIND_LO then
            self:flash(getText("IGUI_TWA_MG_Wrap_GrindSlow"), false, 300)
            return -- the stone isn't biting: no progress, no penalty
        elseif self.omega > GRIND_HI then
            self:tooFast(dt * 0.00035 * (self.omega / GRIND_HI), getText("IGUI_TWA_MG_Wrap_GrindFast"), x, y)
        end
        if ZombRand(2) == 0 then
            self:burst("spark", self.cx + 62, self.cy - 10, 2, { speed = 0.3, ttl = 350 })
        end
    end

    local before = math.floor(self.turns)
    self.turns = self.turns + d / TWO_PI
    if math.floor(self.turns) > before then
        self:burst("ring", self.cx, self.cy, 1, { size = 12, grow = 0.08, ttl = 300, col = C.good })
    end
    if self.drill and ZombRand(3) == 0 then
        self:burst("dust", self.cx + ZombRandFloat(-8, 8), self.cy, 2)
    end

    if self.screw then
        if self.turns > self.need + STRIP_AT and not self.stripped then
            self.stripped = true
            self:spend(0.35, getText("IGUI_TWA_MG_Wrap_Stripped"))
            self:burst("spark", self.cx, self.cy, 10)
        end
    elseif self.turns >= self.need then
        self:succeed(getText("IGUI_TWA_MG_Wrap_Done"))
    end
end

function TWAWrapGame:onHover(x, y, dt)
    if self.grind then self.omega = self.omega * math.exp(-dt / 250) end
end

function TWAWrapGame:updateGame(dt)
    self.progress = math.min(1, self.turns / self.need)
end

-- A steel plate that actually reads as metal: a darker bevel, brushed
-- lines, a highlight edge, bolt heads in the corners.
function TWAWrapGame:drawPlate(x, y, w, h)
    self:rect(x - 3, y - 3, w + 6, h + 6, 1, { r = 0.22, g = 0.23, b = 0.25 })
    self:rect(x, y, w, h, 1, { r = 0.56, g = 0.58, b = 0.62 })
    for i = 1, math.floor(h / 6) do
        local yy = y + i * 6
        local shade = 0.5 + 0.12 * math.sin(i * 1.7)
        self:line(x + 4, yy, x + w - 4, yy, 1, 0.35, { r = shade, g = shade + 0.02, b = shade + 0.05 })
    end
    self:line(x, y + 1, x + w, y + 1, 2, 0.8, { r = 0.85, g = 0.87, b = 0.9 })
    self:line(x + 1, y, x + 1, y + h, 2, 0.6, { r = 0.8, g = 0.82, b = 0.86 })
    for _, p in ipairs({ { x + 14, y + 14 }, { x + w - 14, y + 14 }, { x + 14, y + h - 14 }, { x + w - 14, y + h - 14 } }) do
        self:disc(p[1], p[2], 6, 1, { r = 0.35, g = 0.36, b = 0.4 }, 12)
        self:line(p[1] - 4, p[2], p[1] + 4, p[2], 2, 1, C.dark)
    end
end

function TWAWrapGame:renderGame()
    local cx, cy = self.cx, self.cy
    if self.screw then
        -- A plate bigger than the whole turning ring, and the screw head in
        -- it, its slot turning with you.
        self:drawPlate(cx - 170, cy - 110, 340, 220)
        self:disc(cx, cy, 20, 1, { r = 0.4, g = 0.41, b = 0.45 }, 20)
        self:ring(cx, cy, 20, 2, 1, C.line, 20)
        local a = self.turns * TWO_PI
        self:line(cx - math.cos(a) * 16, cy - math.sin(a) * 16, cx + math.cos(a) * 16, cy + math.sin(a) * 16, 4, 1, C.dark)
        -- Tightness gauge (bug report 2026-09-28: going past the mark wasn't
        -- clear): the bar runs PAST the gold "snug" mark into an orange zone
        -- and a red strip line, and the fill keeps going with you.
        local gx, gy, gw, gh = cx - 150, cy + 125, 300, 14
        local maxT = self.need + STRIP_AT + 0.25
        local function xAt(t) return gx + gw * math.min(1, t / maxT) end
        self:rect(gx, gy, gw, gh, 1, C.dark)
        self:rect(xAt(self.need), gy, xAt(self.need + STRIP_AT) - xAt(self.need), gh, 0.35, { r = 0.95, g = 0.55, b = 0.1 })
        self:rect(xAt(self.need + STRIP_AT), gy, gx + gw - xAt(self.need + STRIP_AT), gh, 0.45, C.bad)
        local fillCol = self.stripped and C.bad or (self.turns >= self.need - SNUG_SLACK and { r = 0.95, g = 0.6, b = 0.1 } or C.good)
        self:rect(gx, gy + 3, xAt(self.turns) - gx, gh - 6, 1, fillCol)
        self:line(xAt(self.need), gy - 8, xAt(self.need), gy + gh + 8, 3, 1, C.guide)
        self:line(xAt(self.need + STRIP_AT), gy - 6, xAt(self.need + STRIP_AT), gy + gh + 6, 2, 1, C.bad)
        if self.turns >= self.need - SNUG_SLACK and not self.stripped and not self.word then
            local pulse = 0.6 + 0.4 * math.sin(self.elapsed * 0.02)
            self:textC(getText("IGUI_TWA_MG_Wrap_LetGo"), cx, gy - 26, C.guide, pulse)
        end
    elseif self.drill then
        self:rect(cx - 140, cy - 80, 280, 160, 1, C.wood)
        local depth = math.min(1, self.turns / self.need)
        self:disc(cx, cy, 8 + 10 * depth, 1, C.wood2, 18)
        self:disc(cx, cy, 4 + 8 * depth, 1, C.dark, 14)
    elseif self.grind then
        -- The grindstone, spinning with the crank, and the blade held to it.
        self:disc(cx, cy, 60, 1, { r = 0.5, g = 0.47, b = 0.42 }, 28)
        self:ring(cx, cy, 60, 2, 1, C.faint, 28)
        for i = 0, 5 do
            local a = self.wheelAng + i * TWO_PI / 6
            self:line(cx, cy, cx + math.cos(a) * 56, cy + math.sin(a) * 56, 2, 0.6, C.dark)
        end
        self:quad(cx + 58, cy - 20, cx + 200, cy - 45, cx + 200, cy - 25, cx + 58, cy - 4, 1, 0.6, 0.62, 0.66)
        -- Crank speed meter with its band.
        local mx, my, mw = cx - 150, cy + 125, 300
        local function xAt(v) return mx + mw * math.min(1, v / 2) end
        self:rect(mx, my, mw, 12, 1, C.dark)
        self:rect(xAt(GRIND_LO), my, xAt(GRIND_HI) - xAt(GRIND_LO), 12, 0.8, C.good)
        self:line(xAt(self.omega), my - 6, xAt(self.omega), my + 18, 3, 1, C.line)
    else
        -- The handle, standing up, and the wraps laid round it so far.
        local hx, top, bot, hw = cx - 16, cy - 130, cy + 130, 32
        self:rect(hx, top, hw, bot - top, 1, C.wood)
        self:disc(cx, top, hw / 2, 1, C.wood, 14)
        local n = math.floor(self.turns)
        local pitch = (bot - top - 20) / (self.need + 1)
        for i = 1, n do
            local y = bot - 10 - i * pitch
            self:line(hx - 3, y + 7, hx + hw + 3, y - 7, 6, 1, self.mat)
        end
        -- The strand from the last wrap out to the hand.
        if self.dragging and self.hx then
            local y = bot - 10 - (n + (self.turns - n)) * pitch
            self:line(cx, y, self.hx, self.hy, 2, 0.9, self.mat)
        end
    end

    if self.workTex then self:tex(self.workTex, 540, 20, 60, 60, 0.55) end

    -- Guide ring with arrows running round it (clockwise on screen).
    local col = self.dragging and C.guide or C.faint
    self:ring(cx, cy, self.R - self.band, 1, 0.35, col, 40)
    self:ring(cx, cy, self.R + self.band, 1, 0.35, col, 40)
    local spin = self.elapsed * 0.0015
    for i = 0, 5 do
        local a = spin + i * TWO_PI / 6
        local x, y = cx + math.cos(a) * self.R, cy + math.sin(a) * self.R
        local tx, ty = -math.sin(a), math.cos(a)
        self:line(x - tx * 8, y - ty * 8, x + tx * 8, y + ty * 8, 3, 0.8, C.guide)
        self:disc(x + tx * 8, y + ty * 8, 3, 0.9, C.guide, 8)
    end
end

function TWAWrapGame:renderOverlay()
    if self.word then return end
    -- Rounded DOWN, so "3.0" on screen really is 3.0 or more.
    local shown = math.floor(self.turns * 10) / 10
    self:textC(string.format("%.1f / %d", shown, self.need), self.cx, self.screw and 20 or 330, C.line, 0.9)
end

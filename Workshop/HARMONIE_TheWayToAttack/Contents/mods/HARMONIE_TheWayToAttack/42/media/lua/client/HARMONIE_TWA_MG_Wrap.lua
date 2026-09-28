--============================================================================
-- HARMONIE_TheWayToAttack -- WRAP minigame (client)
--
-- Anything done by going round and round: wrapping cloth/leather/tape/wire/
-- sinew round a handle, turning a screwdriver or a wrench, turning a hand
-- drill.
--
-- Hold the button and circle the hand round the work along the guide ring,
-- in the direction the arrows run. Each full turn lays one wrap. Too close
-- to the handle pulls it too tight, too far out lays it slack -- both cost
-- quality. Going the wrong way unwinds what you laid. Swinging round too
-- fast (a jump of more than a sixth of a turn at once) doesn't count.
--
-- variant "screw": a few turns, then LET GO: keep turning more than half a
-- turn past snug and the thread strips. variant "drill": turns bore the hole
-- deeper, wood dust spills out.
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

function TWAWrapGame:onStart()
    local vr = self.variant or "cloth"
    self.mat = MATERIAL[vr] or MATERIAL.cloth
    self.screw = vr == "screw"
    self.drill = vr == "drill"
    self.cx, self.cy = 310, 180
    self.R = (self.screw or self.drill) and 70 or 105
    self.band = 10 * self.tol -- halved (request 2026-09-28)
    if self.screw then
        self.need = 3
    elseif self.drill then
        self.need = 4
    else
        self.need = 4 + math.floor(self.req / 2)
    end
    self.turns = 0
    self.lastAng = nil
    self.stripped = false
    self.timeLimit = 20000 + self.need * 6000
    self.toolSize = 46
    -- (No screwdriver override: Base.Screwdriver has no single Icon field,
    -- only IconsForTexture -- workflow.txt 8.12 -- so the procedure's own
    -- icon is used.)
    if self.drill and not self.realTool then self.toolTex = B.itemTex("Drill_OldFashioned") or self.toolTex end
    self.hint = getText("IGUI_TWA_MG_Wrap_Hint")
    self.hint2 = getText(self.screw and "IGUI_TWA_MG_Wrap_Hint_screw"
        or (self.drill and "IGUI_TWA_MG_Wrap_Hint_drill" or "IGUI_TWA_MG_Wrap_Hint_wrap"))
end

function TWAWrapGame:angleOf(x, y)
    return atan2(y - self.cy, x - self.cx)
end

function TWAWrapGame:onGrab(x, y)
    self.lastAng = self:angleOf(x, y)
end

function TWAWrapGame:onRelease()
    self.lastAng = nil
    if self.screw and self.turns >= self.need then
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
    local before = math.floor(self.turns)
    self.turns = self.turns + d / TWO_PI
    if math.floor(self.turns) > before then
        self:burst("ring", self.cx, self.cy, 1, { size = 12, grow = 0.08, ttl = 300, col = C.good })
    end
    if self.drill and ZombRand(3) == 0 then
        self:burst("dust", self.cx + ZombRandFloat(-8, 8), self.cy, 2)
    end

    if self.screw then
        if self.turns > self.need + 0.5 and not self.stripped then
            self.stripped = true
            self:spend(0.35, getText("IGUI_TWA_MG_Wrap_Stripped"))
            self:burst("spark", self.cx, self.cy, 10)
        end
    elseif self.turns >= self.need then
        self:succeed(getText("IGUI_TWA_MG_Wrap_Done"))
    end
end

function TWAWrapGame:updateGame(dt)
    self.progress = math.min(1, self.turns / self.need)
end

function TWAWrapGame:renderGame()
    local cx, cy = self.cx, self.cy
    if self.screw then
        -- A plate and the screw head, its slot turning with you.
        self:rect(cx - 120, cy - 70, 240, 140, 1, C.metal)
        self:disc(cx, cy, 22, 1, C.dark, 20)
        self:ring(cx, cy, 22, 2, 1, C.line, 20)
        local a = self.turns * TWO_PI
        self:line(cx - math.cos(a) * 18, cy - math.sin(a) * 18, cx + math.cos(a) * 18, cy + math.sin(a) * 18, 4, 1, C.line)
        -- Snug gauge.
        local f = math.min(1.3, self.turns / self.need)
        self:rect(cx - 100, cy + 95, 200, 10, 1, C.dark)
        self:rect(cx - 100, cy + 95, 200 * math.min(1, f), 10, 1, f > 1.15 and C.bad or C.good)
        self:line(cx + 100, cy + 88, cx + 100, cy + 112, 2, 1, C.guide)
    elseif self.drill then
        self:rect(cx - 140, cy - 80, 280, 160, 1, C.wood)
        local depth = math.min(1, self.turns / self.need)
        self:disc(cx, cy, 8 + 10 * depth, 1, C.wood2, 18)
        self:disc(cx, cy, 4 + 8 * depth, 1, C.dark, 14)
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
    self:textC(string.format("%.1f / %d", math.min(self.turns, self.need + 0.99), self.need), self.cx, 330, C.line, 0.9)
end

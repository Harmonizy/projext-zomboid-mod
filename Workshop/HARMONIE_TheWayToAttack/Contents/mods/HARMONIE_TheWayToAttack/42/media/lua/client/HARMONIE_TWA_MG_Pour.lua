--============================================================================
-- HARMONIE_TheWayToAttack -- POUR minigame (client)
--
-- Pouring molten metal from a crucible into a mold.
--
-- Hold the button to tip the crucible -- the longer it's held the further
-- it tips and the faster the metal runs. Let go and it rights itself, but
-- metal already on its way still lands. Stop with the mold filled to the
-- marked line: short leaves a thin bar (pour again, a cold join costs a
-- little), over the top spills and is ruined.
--============================================================================

require "HARMONIE_TWA_MinigameBase"

TWAPourGame = TWAMinigameBase:derive("TWAPourGame")

local B = TWAMinigameBase
local C = B.COL

function TWAPourGame:onStart()
    self.loopSoundName = "TWA_Pour" -- round 11
    self.fill = 0
    self.tilt = 0
    self.flow = 0
    -- Round 13 ("มินิเกมเทลงเบ้าง่ายไป"): the fill line sits somewhere new each
    -- time, the crucible tips faster and rights itself slower (metal keeps
    -- coming for a moment after you let go), and the stream lags more.
    self.target = 0.72 + ZombRandFloat(0, 0.16)
    self.half = TWAConfig.num("PourZone", 0.001) * self.tol -- sandbox (round 9), default 0.025
    self.pours = 0
    self.timeLimit = 45000
    self.toolSize = 40
    if not self.realTool then self.toolTex = B.itemTex("BlacksmithTongs") or self.toolTex end
    self.hint = getText("IGUI_TWA_MG_Pour_Hint")
    self.hint2 = getText("IGUI_TWA_MG_Pour_Hint2")
end

function TWAPourGame:onGrab()
    if self.fill > 0.05 and self.flow < 0.01 then
        self:spend(0.06, getText("IGUI_TWA_MG_Pour_ColdJoin"))
    end
    self.pours = self.pours + 1
end

function TWAPourGame:updateGame(dt)
    local s = dt / 1000
    if self.dragging then
        self.tilt = math.min(1, self.tilt + s * 0.8 * self.pace)
    else
        self.tilt = math.max(0, self.tilt - s * 1.4)
    end
    -- The stream lags the crucible a little and grows with the tilt squared.
    local want = self.tilt > 0.25 and ((self.tilt - 0.25) / 0.75) ^ 2 or 0
    self.flow = self.flow + (want - self.flow) * math.min(1, s * 4)
    self.fill = self.fill + self.flow * s * 0.45
    if self.flow > 0.02 and ZombRand(2) == 0 then
        self:burst("spark", 330, 290 - self.fill * 110, 1, { speed = 0.15, ttl = 300 })
    end
    self.progress = math.min(1, self.fill / self.target)

    if self.fill > 1 then
        self:fail(getText("IGUI_TWA_MG_Pour_Spilled"))
        return
    end
    -- Settled: the pour is over once the crucible is upright and nothing runs.
    if not self.dragging and self.tilt <= 0 and self.flow < 0.003 and self.pours > 0 then
        local d = math.abs(self.fill - self.target)
        if d <= self.half then
            self.quality = self.quality * (1 - 0.3 * d / self.half)
            self:succeed(getText("IGUI_TWA_MG_Pour_Done"))
        elseif self.fill > self.target then
            self.quality = self.quality * 0.7
            self:succeed(getText("IGUI_TWA_MG_Pour_Over"))
        elseif not self.saidShort then
            self.saidShort = true
            self:flash(getText("IGUI_TWA_MG_Pour_Short"), false, 1200)
        end
    end
    if self.dragging then self.saidShort = false end
end

function TWAPourGame:onTimeout()
    if math.abs(self.fill - self.target) <= self.half * 2 then
        self.quality = self.quality * 0.7
        self:succeed(getText("IGUI_TWA_MG_Pour_Done"))
    else
        self:fail(getText("IGUI_TWA_MG_TimeUp"))
    end
end

-- Round 13 ("เส้นที่เทมันลงมาจากก้นถัง"): redrawn so it reads as what it is.
-- A clay crucible full of glowing metal tips about its POURING LIP, which
-- stays right over the mould; the stream falls straight down from that lip
-- onto the metal already in the mould. What's left in the crucible goes
-- down as the mould fills.
local CLAY = { r = 0.58, g = 0.40, b = 0.28 }
local LIP_X, LIP_Y = 330, 118
local MX, MY, MW, MH = 260, 180, 140, 110 -- the mould's cavity

function TWAPourGame:renderGame()
    local r, g, b = B.heatColor(0.95)
    local hot = { r = r, g = g, b = b }
    -- The mould: a clay block with a bar-shaped cavity.
    self:rect(MX - 30, MY - 14, MW + 60, MH + 34, 1, { r = CLAY.r * 0.55, g = CLAY.g * 0.55, b = CLAY.b * 0.55 })
    self:gradient(MX - 26, MY - 10, MW + 52, MH + 26, CLAY, { r = CLAY.r * 0.7, g = CLAY.g * 0.7, b = CLAY.b * 0.7 }, 8)
    self:rect(MX, MY, MW, MH, 1, { r = 0.12, g = 0.09, b = 0.07 })
    local fh = MH * math.min(1, self.fill)
    if fh > 0 then
        self:rectRGB(MX, MY + MH - fh, MW, fh, 1, r * 0.85, g * 0.8, b * 0.7)
        self:line(MX, MY + MH - fh, MX + MW, MY + MH - fh, 2, 1, { r = 1, g = 0.95, b = 0.7 })
        for i = 0, 5 do  -- a heat shimmer on the surface
            local x = MX + 10 + i * 24 + 6 * math.sin(self.elapsed * 0.004 + i)
            self:line(x, MY + MH - fh + 2, x + 10, MY + MH - fh + 2, 1, 0.5, { r = 1, g = 1, b = 0.85 })
        end
    end
    -- The line to fill to, and its tolerance.
    local ty = MY + MH - MH * self.target
    self:rect(MX - 26, ty - MH * self.half, 8, MH * self.half * 2, 1, C.good)
    self:line(MX - 30, ty, MX + MW + 30, ty, 2, 0.9, C.guide)

    -- The crucible, in its own frame: lip at the origin, opening along the
    -- top edge, body to the right and below. Tipping turns it about the lip.
    local a = -self.tilt * 1.9
    local ca, sa = math.cos(a), math.sin(a)
    local function rot(x, y) return LIP_X + x * ca - y * sa, LIP_Y + x * sa + y * ca end
    local function q(p1, p2, p3, p4, alpha, cr, cg, cb)
        local x1, y1 = rot(p1[1], p1[2]); local x2, y2 = rot(p2[1], p2[2])
        local x3, y3 = rot(p3[1], p3[2]); local x4, y4 = rot(p4[1], p4[2])
        self:quad(x1, y1, x2, y2, x3, y3, x4, y4, alpha, cr, cg, cb)
    end
    -- Body (tapering), darker outline, then the metal inside.
    q({ -3, -3 }, { 69, -3 }, { 59, 71 }, { 7, 71 }, 1, CLAY.r * 0.45, CLAY.g * 0.45, CLAY.b * 0.45)
    q({ 0, 0 }, { 66, 0 }, { 57, 68 }, { 9, 68 }, 1, CLAY.r, CLAY.g, CLAY.b)
    q({ 0, 0 }, { 20, 0 }, { 22, 68 }, { 9, 68 }, 1, CLAY.r * 1.2, CLAY.g * 1.2, CLAY.b * 1.2)
    local left = math.max(0, 1 - self.fill / 1.1)
    if left > 0.02 then
        local top = 64 - 58 * left
        q({ 6 + 3 * (1 - left), top }, { 60 - 3 * (1 - left), top }, { 55, 64 }, { 11, 64 }, 1, r, g, b)
        q({ 6 + 3 * (1 - left), top }, { 60 - 3 * (1 - left), top }, { 60 - 3 * (1 - left), top + 3 }, { 6 + 3 * (1 - left), top + 3 }, 1, 1, 0.95, 0.7)
    end
    -- Rim and the pouring spout at the lip.
    local x1, y1 = rot(0, 0)
    local x2, y2 = rot(66, 0)
    self:line(x1, y1, x2, y2, 4, 1, { r = CLAY.r * 0.7, g = CLAY.g * 0.7, b = CLAY.b * 0.7 })
    local sx, sy = rot(-8, 2)
    self:line(x1, y1, sx, sy, 5, 1, { r = CLAY.r * 0.8, g = CLAY.g * 0.8, b = CLAY.b * 0.8 })
    -- Tongs gripping it.
    local tx, ty2 = rot(66, 30)
    self:line(tx, ty2, tx + 90, ty2 - 40, 4, 1, { r = 0.3, g = 0.3, b = 0.33 })
    -- The stream: straight down from the lip onto the metal in the mould.
    if self.flow > 0.01 then
        local wdt = 2 + self.flow * 9
        local bottom = MY + MH - fh
        self:line(LIP_X - 4, LIP_Y, LIP_X - 4, bottom, wdt + 3, 0.35, { r = 1, g = 0.6, b = 0.2 })
        self:line(LIP_X - 4, LIP_Y, LIP_X - 4, bottom, wdt, 1, hot)
        self:line(LIP_X - 4, LIP_Y, LIP_X - 4, bottom, math.max(1, wdt * 0.35), 1, { r = 1, g = 0.97, b = 0.8 })
    end
    if self.workTex then self:tex(self.workTex, 540, 20, 60, 60, 0.55) end
end

function TWAPourGame:renderOverlay()
    if self.word then return end
    self:textC(string.format("%d%%", math.floor(self.fill * 100 + 0.5)), 330, 322, C.line, 0.9)
end

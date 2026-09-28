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
    self.fill = 0
    self.tilt = 0
    self.flow = 0
    self.target = 0.85
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
        self.tilt = math.min(1, self.tilt + s * 0.55 * self.pace)
    else
        self.tilt = math.max(0, self.tilt - s * 3.0)
    end
    -- The stream lags the crucible a little and grows with the tilt squared.
    local want = self.tilt > 0.25 and ((self.tilt - 0.25) / 0.75) ^ 2 or 0
    self.flow = self.flow + (want - self.flow) * math.min(1, s * 7)
    self.fill = self.fill + self.flow * s * 0.35
    if self.flow > 0.02 and ZombRand(2) == 0 then
        self:burst("spark", 330, 170 + (1 - self.fill) * 120, 1, { speed = 0.15, ttl = 300 })
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

function TWAPourGame:renderGame()
    -- The mold: a cavity that fills from the bottom.
    local mx, my, mw, mh = 250, 170, 160, 120
    self:rect(mx - 20, my - 10, mw + 40, mh + 30, 1, { r = 0.45, g = 0.36, b = 0.28 })
    self:rect(mx, my, mw, mh, 1, C.dark)
    local fh = mh * math.min(1, self.fill)
    local r, g, b = B.heatColor(0.95)
    self:rectRGB(mx, my + mh - fh, mw, fh, 1, r, g, b)
    -- The line to fill to, and its tolerance.
    local ty = my + mh - mh * self.target
    self:rect(mx - 26, ty - mh * self.half, 8, mh * self.half * 2, 1, C.good)
    self:line(mx - 26, ty, mx + mw + 26, ty, 2, 0.9, C.guide)

    -- The crucible, tipping about its lip.
    local px, py = 330, 90
    local a = -self.tilt * 1.9
    local ca, sa = math.cos(a), math.sin(a)
    local function rot(x, y) return px + x * ca - y * sa, py + x * sa + y * ca end
    local x1, y1 = rot(-10, -60)
    local x2, y2 = rot(70, -60)
    local x3, y3 = rot(60, 10)
    local x4, y4 = rot(0, 10)
    self:quad(x1, y1, x2, y2, x3, y3, x4, y4, 1, 0.35, 0.3, 0.27)
    self:polyline({ { x1, y1 }, { x2, y2 }, { x3, y3 }, { x4, y4 } }, 2, 1, C.line, true)
    -- The stream.
    if self.flow > 0.01 then
        self:line(px, py, 330, my + mh - fh, 2 + self.flow * 10, 1, { r = r, g = g, b = b })
    end
    if self.workTex then self:tex(self.workTex, 540, 20, 60, 60, 0.55) end
end

function TWAPourGame:renderOverlay()
    if self.word then return end
    self:textC(string.format("%d%%", math.floor(self.fill * 100 + 0.5)), 330, 320, C.line, 0.9)
end

--============================================================================
-- HARMONIE_TheWayToAttack -- HEAT minigame (client)
--
-- Controlling a temperature: lighting and feeding a fire, melting metal,
-- annealing, and (inverted) quenching/cooling a cast.
--
-- The thermometer on the left has a marked band. Hold the button to work
-- the bellows -- the heat climbs, with weight behind it, and keeps climbing a
-- moment after you let go; release and it falls away. Keep the needle inside
-- the band until the hold meter fills. Outside the band costs quality; well
-- over it overheats the work. On harder procedures the band drifts.
--
-- variant "cool": the other way round -- the work starts hot and holding
-- the button plunges it into the water. Cool it too fast (far under the
-- band) and it goes brittle.
--============================================================================

require "HARMONIE_TWA_MinigameBase"

TWAHeatGame = TWAMinigameBase:derive("TWAHeatGame")

local B = TWAMinigameBase
local C = B.COL

local CENTER = { fire = 0.45, melt = 0.78, anneal = 0.6, cool = 0.3 }

function TWAHeatGame:onStart()
    self.cool = self.variant == "cool"
    self.center0 = CENTER[self.variant] or 0.6
    self.half = 0.035 * self.tol -- halved (request 2026-09-28)
    self.temp = self.cool and 1.0 or 0.05
    self.vel = 0
    self.held = 0
    self.need = 4000 + 300 * self.req
    self.drift = self.req >= 4 and 0.08 or 0
    self.timeLimit = 30000 + self.need * 3
    self.toolSize = 44
    if self.cool and not self.realTool then
        self.toolTex = B.itemTex("BlacksmithTongs") or self.toolTex
    end
    self.hint = getText(self.cool and "IGUI_TWA_MG_Heat_Hint_cool" or "IGUI_TWA_MG_Heat_Hint")
    self.hint2 = getText("IGUI_TWA_MG_Heat_Hint2")
end

function TWAHeatGame:bandCenter()
    return self.center0 + self.drift * math.sin(self.elapsed / 1000 * 0.7)
end

function TWAHeatGame:updateGame(dt)
    local s = dt / 1000
    -- Holding pushes (heat up, or down for "cool"); letting go, it falls back
    -- towards ambient (or the forge's own heat for "cool").
    local push = self.dragging and 1.5 or 0
    local fall = 0.7
    local acc
    if self.cool then
        acc = self.dragging and -push or (0.35 - self.temp) * 0.6 + 0.1
    else
        acc = push - fall
    end
    self.vel = self.vel + acc * s * self.pace
    self.vel = self.vel * math.exp(-3.2 * s)
    self.temp = B.clamp(self.temp + self.vel * s, 0, 1.2)

    local c = self:bandCenter()
    local off = self.temp - c
    -- Bringing it up to temperature the first time (or down, for "cool") is
    -- just the warm-up: nothing is judged until the needle first reaches
    -- the band.
    if not self.reached then
        if math.abs(off) <= self.half then
            self.reached = true
        else
            self.progress = 0
            return
        end
    end
    if math.abs(off) <= self.half then
        self.held = self.held + dt
        if ZombRand(5) == 0 then self:burst(self.cool and "steam" or "ember", 330 + ZombRandFloat(-60, 60), 250, 1) end
    else
        local over = (math.abs(off) - self.half) / 0.1
        self:spend(dt * 0.00004 * over, nil, true)
        if not self.cool and off > self.half + 0.18 then
            self:spend(dt * 0.0002, getText("IGUI_TWA_MG_Heat_TooHot"), true)
        elseif self.cool and off < -(self.half + 0.18) then
            self:spend(dt * 0.0002, getText("IGUI_TWA_MG_Heat_Brittle"), true)
        elseif off > 0 then
            self:flash(getText(self.cool and "IGUI_TWA_MG_Heat_StillHot" or "IGUI_TWA_MG_Heat_High"), true, 300)
        else
            self:flash(getText(self.cool and "IGUI_TWA_MG_Heat_Low" or "IGUI_TWA_MG_Heat_Low"), true, 300)
        end
    end
    if self.dragging and ZombRand(3) == 0 then
        self:burst(self.cool and "steam" or "spark", 330 + ZombRandFloat(-80, 80), 260, 1, { speed = 0.12 })
    end
    self.progress = math.min(1, self.held / self.need)
    if self.held >= self.need then self:succeed(getText("IGUI_TWA_MG_Heat_Done")) end
end

function TWAHeatGame:onTimeout()
    if self.progress >= 0.6 then
        self.quality = self.quality * 0.8
        self:succeed(getText("IGUI_TWA_MG_Heat_Done"))
    else
        self:fail(getText("IGUI_TWA_MG_TimeUp"))
    end
end

function TWAHeatGame:renderGame()
    -- Thermometer.
    local gx, gy, gw, gh = 40, 30, 36, 290
    self:rect(gx, gy, gw, gh, 1, C.dark)
    local c = self:bandCenter()
    local function yOf(t) return gy + gh - B.clamp(t, 0, 1.2) / 1.2 * gh end
    self:rect(gx, yOf(c + self.half), gw, yOf(c - self.half) - yOf(c + self.half), 0.9, C.good)
    local r, g, b = B.heatColor(self.temp)
    local ty = yOf(self.temp)
    self:rectRGB(gx + 8, ty, gw - 16, gy + gh - ty, 1, r, g, b)
    self:line(gx - 8, ty, gx + gw + 8, ty, 3, 1, C.line)
    self:frame(gx, gy, gw, gh, 1, C.faint)

    -- The scene: coals and the work, or the water tub.
    if self.cool then
        self:rect(160, 230, 340, 90, 1, { r = 0.12, g = 0.2, b = 0.3 })
        self:line(160, 230, 500, 230, 2, 1, C.steam)
    else
        self:rect(160, 250, 340, 70, 1, C.dark)
        for i = 0, 10 do
            local glow = 0.2 + 0.6 * math.min(1, self.temp) * (0.7 + 0.3 * math.sin(self.elapsed * 0.005 + i * 1.7))
            self:disc(175 + i * 31, 280 + (i % 2) * 10, 14, glow, C.ember, 12)
        end
    end
    local workY = self.cool and (self.dragging and 215 or 150) or 190
    local wr, wg, wb = B.heatColor(self.temp)
    self:rectRGB(230, workY, 200, 36, 1, wr, wg, wb)
    self:frame(230, workY, 200, 36, 1, C.line)
    if self.workTex then self:tex(self.workTex, 300, workY - 70, 60, 60, 0.6) end

    -- Hold meter.
    self:rect(160, 20, 340, 10, 1, C.dark)
    self:rect(160, 20, 340 * self.progress, 10, 1, C.good)
    self:frame(160, 20, 340, 10, 1, C.faint)
end

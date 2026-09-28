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

local CENTER = { fire = 0.45, melt = 0.78, anneal = 0.6, cool = 0.3, bend = 0.7 }

function TWAHeatGame:onStart()
    self.cool = self.variant == "cool"
    -- variant "bend" (request 2026-09-28: breaking a branch must not be the
    -- bottle-smashing game): the same held-force control, themed as bending
    -- a branch over the knee -- bend it to the band and hold it there until
    -- it snaps cleanly; bend too far and it splinters.
    self.bend = self.variant == "bend"
    self.center0 = CENTER[self.variant] or 0.6
    -- Round 11 sound: bellows (hiss of the water for "cool", wood for "bend").
    self.loopSoundName = self.cool and "TWA_Quench" or (self.bend and "TWA_Carve" or "TWA_Bellows")
    self.half = TWAConfig.num("HeatZone", 0.001) * self.tol -- sandbox (round 9), default 0.035
    self.temp = self.cool and 1.0 or 0.05
    self.vel = 0
    self.held = 0
    self.need = self.bend and TWAConfig.num("BendHoldMs", 50) or (TWAConfig.num("HeatHoldMs", 50) + 300 * self.req)
    self.drift = (self.req >= 4 and not self.bend and TWAConfig.on("HeatDrift")) and 0.08 or 0
    if self.cool then
        -- Request 2026-09-28 ("มินิเกมจุ่มง่ายไป อยากให้อุณหภูมิขึ้นลงเร็วกว่า
        -- นี้ และโซนเล็กลง รวมถึงเกจคุณภาพลดลงเร็วขึ้น"): a faster plunge and a
        -- faster climb back, a narrower band, and slips cost 1.5x more.
        self.half = TWAConfig.num("CoolZone", 0.001) * self.tol
        self.drainMul = TWAConfig.num("CoolDrain", 0)
    end
    self.timeLimit = 30000 + self.need * 3
    self.toolSize = 44
    if self.cool and not self.realTool then
        self.toolTex = B.itemTex("BlacksmithTongs") or self.toolTex
    end
    self.hint = getText(self.cool and "IGUI_TWA_MG_Heat_Hint_cool"
        or (self.bend and "IGUI_TWA_MG_Heat_Hint_bend" or "IGUI_TWA_MG_Heat_Hint"))
    self.hint2 = getText(self.bend and "IGUI_TWA_MG_Heat_Hint2_bend" or "IGUI_TWA_MG_Heat_Hint2")
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
        acc = self.dragging and -2.6 or (0.35 - self.temp) * 1.1 + 0.28
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
        -- Round 7 ("หากเข้าไปในโซนแล้ว หากออกนอกโซนหลังจากนั้นจะลดคุณภาพ"):
        -- once the band has been reached, every moment outside it costs
        -- quality -- a real base rate, not just in proportion to how far out.
        local over = (math.abs(off) - self.half) / 0.1
        if TWAConfig.on("HeatOutsideCosts") then
            self:spend(dt * (0.00006 + 0.00004 * over), nil, true)
        else
            self:spend(dt * 0.00004 * over, nil, true)
        end
        if self.bend and off > self.half + 0.18 then
            self:spend(dt * 0.0002, getText("IGUI_TWA_MG_Heat_Splinter"), true)
        elseif self.bend then
            self:flash(getText(off > 0 and "IGUI_TWA_MG_Heat_BendHard" or "IGUI_TWA_MG_Heat_BendSoft"), true, 300)
        elseif not self.cool and off > self.half + 0.18 then
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
    if self.held >= self.need then
        if self.bend then self:burst("chip", 330, 200, 14, { col = C.wood, speed = 0.3 }) end
        self:succeed(getText(self.bend and "IGUI_TWA_MG_Heat_Snapped" or "IGUI_TWA_MG_Heat_Done"))
    end
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

    -- The scene: a branch over the knee, coals and the work, or the water tub.
    if self.bend then
        -- The branch bows more the harder you push.
        local sag = 110 * math.min(1.2, self.temp)
        local pts = {}
        for i = 0, 12 do
            local u = i / 12
            pts[#pts + 1] = { 150 + u * 360, 200 - sag * (1 - (2 * u - 1) ^ 2) }
        end
        -- Bark: a dark rim, the brown body, a lighter top edge and knots.
        self:polyline(pts, 14, 1, C.wood2)
        self:polyline(pts, 10, 1, C.wood)
        for i = 1, #pts - 1 do
            local a, b = pts[i], pts[i + 1]
            self:line(a[1], a[2] - 3, b[1], b[2] - 3, 2, 0.5, { r = 0.6, g = 0.44, b = 0.26 })
            if i % 3 == 0 then self:disc(a[1], a[2] + 1, 3, 0.8, C.wood2, 8) end
        end
        self:disc(330, 220 - sag * 0.02, 18, 1, C.dark, 14) -- the knee
        if self.workTex then self:tex(self.workTex, 540, 20, 60, 60, 0.55) end
        self:rect(160, 20, 340, 10, 1, C.dark)
        self:rect(160, 20, 340 * self.progress, 10, 1, C.good)
        self:frame(160, 20, 340, 10, 1, C.faint)
        return
    end
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
    self:hotMetal(230, workY, 200, 36, self.temp, 6)
    if self.workTex then self:tex(self.workTex, 300, workY - 70, 60, 60, 0.6) end

    -- Hold meter.
    self:rect(160, 20, 340, 10, 1, C.dark)
    self:rect(160, 20, 340 * self.progress, 10, 1, C.good)
    self:frame(160, 20, 340, 10, 1, C.faint)
end

-- Bellows at the hand for the fire variants (request 2026-09-28: "มินิเกม
-- การเป่าลม ตรงเมาส์อยากให้เป็นรูปที่เป่าลม") -- drawn, since there's no
-- vanilla bellows icon to borrow: two wooden boards hinged at a brass
-- nozzle, leather between them; they squeeze shut while you pump.
function TWAHeatGame:drawTool()
    if self.cool or self.bend then return B.drawTool(self) end
    if not self.hx then return end
    local x, y = self.hx, self.hy
    local open = self.dragging and (0.12 + 0.1 * math.abs(math.sin(self.elapsed * 0.012))) or 0.32
    local L = 58
    -- Nozzle points down-left at the contact point.
    local nx, ny = x, y
    local ax, ay = x + 18, y - 18                     -- hinge
    local function arm(a)
        local base = -0.78                            -- pointing up-right
        return ax + math.cos(base + a) * L, ay + math.sin(base + a) * L
    end
    local tx1, ty1 = arm(open)
    local tx2, ty2 = arm(-open)
    self:quad(ax, ay, tx1, ty1, tx2, ty2, ax, ay, 1, 0.45, 0.3, 0.16)        -- leather
    self:line(ax, ay, tx1, ty1, 7, 1, C.wood)                              -- top board
    self:line(ax, ay, tx2, ty2, 7, 1, C.wood)                              -- bottom board
    self:line(tx1, ty1, tx1 + 10, ty1 - 10, 4, 1, C.wood2)                 -- handles
    self:line(tx2, ty2, tx2 + 10, ty2 - 10, 4, 1, C.wood2)
    self:line(nx, ny, ax, ay, 5, 1, { r = 0.78, g = 0.62, b = 0.2 })       -- nozzle
    if self.dragging and ZombRand(2) == 0 then
        self:burst("steam", nx - 4, ny + 4, 1, { col = C.faint, grow = 0.01 })
    end
    self:disc(x, y, 2.5, 1, C.guide, 10)
end

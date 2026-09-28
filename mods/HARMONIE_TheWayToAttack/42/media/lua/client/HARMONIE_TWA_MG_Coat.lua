--============================================================================
-- HARMONIE_TheWayToAttack -- COAT minigame (client)
--
-- Covering the work with something: clay/mud, wax, a bleach wash -- and
-- fire-treating the surface.
--
-- Load the tool at the pot (click it), then hold and draw it over the
-- dashed area on the work: it goes on where you pass, until the tool is
-- empty -- back to the pot. Outside the area is wasted; scrubbing hard and
-- fast leaves it uneven. Done when the area is covered.
--
-- variant "fire": no pot -- the flame is held over the surface. Each spot
-- takes heat to char; hold it too long in one place and it burns black.
--============================================================================

require "HARMONIE_TWA_MinigameBase"

TWACoatGame = TWAMinigameBase:derive("TWACoatGame")

local B = TWAMinigameBase
local C = B.COL

local MATERIAL = {
    mud    = { r = 0.46, g = 0.33, b = 0.20 },
    wax    = { r = 0.95, g = 0.90, b = 0.62 },
    bleach = { r = 0.78, g = 0.90, b = 1.00 },
}

local COLS, ROWS = 14, 5
local DONE = 0.9 -- default; the sandbox "CoatCoverage" is used (round 9)
local LOAD = 12

function TWACoatGame:onStart()
    self.fire = self.variant == "fire"
    self.mat = MATERIAL[self.variant] or MATERIAL.mud
    -- The surface: a long ellipse over the blade.
    self.cx, self.cy, self.rx, self.ry = 330, 170, 230, 55
    self.cells = {}
    for i = 1, COLS do
        for j = 1, ROWS do
            local u = (i - 0.5) / COLS * 2 - 1
            local v = (j - 0.5) / ROWS * 2 - 1
            if u * u + v * v <= 1 then
                self.cells[#self.cells + 1] = { x = self.cx + u * self.rx, y = self.cy + v * self.ry,
                                                on = false, heat = 0, burnt = false }
            end
        end
    end
    self.cellR = math.max(self.rx / COLS, self.ry / ROWS) * 1.3
    self.load = self.fire and math.huge or 0
    self.pot = { x = 70, y = 290 }
    self.rubLimit = 0.9 * self.tol
    self.timeLimit = 55000
    self.toolSize = 44
    if self.fire and not self.realTool then self.toolTex = B.itemTex("BlowTorch") or self.toolTex end
    self.hint = getText(self.fire and "IGUI_TWA_MG_Coat_Hint_fire" or "IGUI_TWA_MG_Coat_Hint")
    self.hint2 = getText(self.fire and "IGUI_TWA_MG_Coat_Hint2_fire" or "IGUI_TWA_MG_Coat_Hint2")
end

function TWACoatGame:inPatch(x, y)
    local u, v = (x - self.cx) / self.rx, (y - self.cy) / self.ry
    return u * u + v * v <= 1.1
end

function TWACoatGame:coverage()
    local n = 0
    for _, c in ipairs(self.cells) do if c.on then n = n + 1 end end
    return n / math.max(1, #self.cells)
end

function TWACoatGame:onGrab(x, y)
    if not self.fire and B.dist(x, y, self.pot.x, self.pot.y) <= 45 then
        self.load = LOAD
        self.scooping = true
        self:flash(getText("IGUI_TWA_MG_Coat_Loaded"), false, 500)
        return
    end
    if not self.fire and self.load <= 0 then
        self:flash(getText("IGUI_TWA_MG_Coat_Empty"), false, 900)
    end
end

function TWACoatGame:onRelease()
    self.scooping = false
end

function TWACoatGame:onDrag(x, y, dt)
    if self.scooping then return end
    if self.fire then
        if ZombRand(2) == 0 then self:burst("ember", x, y, 1, { ttl = 400 }) end
        for _, c in ipairs(self.cells) do
            if not c.burnt and B.dist(x, y, c.x, c.y) <= self.cellR * 1.2 then
                c.heat = c.heat + dt / 700
                if c.heat >= 1 then c.on = true end
                if c.heat >= 2.2 then
                    c.burnt = true
                    self:spend(0.05, getText("IGUI_TWA_MG_Coat_Burnt"))
                    self:burst("steam", c.x, c.y, 3, { col = C.dark })
                end
            end
        end
        return
    end
    if self.load <= 0 then return end
    if not self:inPatch(x, y) then
        self.wasteT = (self.wasteT or 0) + dt
        if self.wasteT > 250 then
            self.wasteT = 0
            self.load = self.load - 1
            self:spend(0.015, getText("IGUI_TWA_MG_Coat_Outside"))
        end
        return
    end
    if (self.handSpeed or 0) > self.rubLimit then
        self:tooFast((self.handSpeed - self.rubLimit) * dt * 0.0004, getText("IGUI_TWA_MG_Coat_Uneven"), x, y)
    end
    for _, c in ipairs(self.cells) do
        if not c.on and self.load > 0 and B.dist(x, y, c.x, c.y) <= self.cellR then
            c.on = true
            self.load = self.load - 1
        end
    end
end

function TWACoatGame:updateGame(dt)
    local cov = self:coverage()
    local done = TWAConfig.num("CoatCoverage", 0.05)
    self.progress = math.min(1, cov / done)
    if cov >= done then
        self:succeed(getText("IGUI_TWA_MG_Coat_Done"))
    end
    if self.fire and not self.dragging then
        for _, c in ipairs(self.cells) do c.heat = math.max(c.on and 1 or 0, c.heat - dt / 3000) end
    end
end

function TWACoatGame:onTimeout()
    if self:coverage() >= 0.6 then
        self.quality = self.quality * 0.8
        self:succeed(getText("IGUI_TWA_MG_Coat_Patchy"))
    else
        self:fail(getText("IGUI_TWA_MG_TimeUp"))
    end
end

function TWACoatGame:renderGame()
    -- The blade under it.
    self:quad(80, 190, 580, 150, 560, 110, 100, 120, 1, 0.5, 0.52, 0.56)
    self:quad(80, 190, 580, 150, 570, 136, 90, 170, 1, 0.64, 0.66, 0.7)
    for k = 1, 5 do
        local u = k / 6
        self:line(100 - 20 * u, 120 + 70 * u, 560 + 20 * u, 110 + 40 * u, 1, 0.12, C.line)
    end
    self:line(100, 120, 560, 110, 2, 0.6, C.line)
    self:woodBoard(20, 125, 70, 50, { seed = 3, knots = 0 })
    if self.workTex then self:tex(self.workTex, 540, 230, 60, 60, 0.55) end

    for _, c in ipairs(self.cells) do
        if self.fire then
            if c.burnt then
                self:disc(c.x, c.y, self.cellR, 1, C.dark, 10)
            elseif c.heat > 0.05 then
                local k = math.min(1, c.heat)
                local r, g, b = B.heatColor(0.2 + 0.5 * math.min(1, c.heat / 1.4))
                self:disc(c.x, c.y, self.cellR * 0.9, 0.3 + 0.6 * k, { r = r * 0.6, g = g * 0.5, b = b * 0.4 }, 10)
            end
        elseif c.on then
            self:disc(c.x, c.y, self.cellR, 0.9, self.mat, 10)
        end
    end

    -- The area to cover, dashed.
    if not self.word then
        for i = 0, 47, 2 do
            local a0, a1 = i / 48 * 6.2832, (i + 1) / 48 * 6.2832
            self:line(self.cx + math.cos(a0) * self.rx, self.cy + math.sin(a0) * self.ry,
                      self.cx + math.cos(a1) * self.rx, self.cy + math.sin(a1) * self.ry, 2, 0.7, C.guide)
        end
    end

    if not self.fire then
        local p = self.pot
        self:disc(p.x, p.y + 6, 42, 1, C.dark, 20)
        self:disc(p.x, p.y, 36, 1, self.mat, 20)
        self:ring(p.x, p.y, 42, 2, 1, C.faint, 24)
        if self.load <= 0 and not self.word then
            local pulse = 1 + 0.1 * math.sin(self.elapsed * 0.007)
            self:ring(p.x, p.y, 48 * pulse, 2, 0.9, C.guide, 28)
        end
    end
end

function TWACoatGame:renderOverlay()
    if self.word then return end
    if not self.fire and self.hx and self.load > 0 then
        self:disc(self.hx, self.hy, 4 + self.load * 0.6, 0.95, self.mat, 12)
    end
    self:textC(string.format("%d%%", math.floor(self:coverage() * 100 + 0.5)), 330, 320, C.line, 0.9)
end

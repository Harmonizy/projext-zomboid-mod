--============================================================================
-- HARMONIE_TheWayToAttack -- PURIFY minigame (client): Gem Purification,
-- "การชำระมณี" -- the Gemology (อัญมณีศาสตร์) procedure's game.
--
-- Round 20 (request 2026-09-29): find the impurities -> learn what they are
-- -> choose how to treat each -> control the heat / force / agent -> keep
-- the gem whole -> check the purity.
--   1. ANALYSE. The gem (the faceting game's brilliant) turns: hold the
--      arrows at its sides or roll the wheel. A flaw only shows on the side
--      facing you, and clearly only under the microscope (the round view at
--      the top right, which magnifies what is under the cursor). Click a
--      flaw to identify it -- its kind, depth and size go on the list. A
--      click on clean stone costs quality.
--        kinds: inclusion, fracture, bubble, colour spot, foreign matter
--   2. METHOD. For each flaw pick a treatment: Heat, Cleaning, Oil, Laser or
--      Mechanical removal. The right one depends on the flaw (the guide at
--      the right says which); a wrong pick costs quality.
--   3. CONTROL. Hold the button and keep the needle (the mouse's height) in
--      the green band of the gauge until the treatment is done; the band
--      drifts. Far outside it strains the gem.
--   4. CHECK. The purity (what is left of the quality meter) is shown, and
--      the game ends.
-- All drawn with the minigame kit; nothing third-party.
--============================================================================

require "HARMONIE_TWA_MinigameBase"

TWAPurifyGame = TWAMinigameBase:derive("TWAPurifyGame")

local B = TWAMinigameBase
local C = B.COL

local GX, GY, GR = 230, 178, 118          -- the gem
local MX, MY, MR = 520, 92, 70            -- the microscope view
local GAUGE_X, GAUGE_Y, GAUGE_H = 470, 60, 230
local KINDS = { "Inclusion", "Fracture", "Bubble", "ColorSpot", "Foreign" }
local METHODS = { "Heat", "Cleaning", "Oil", "Laser", "Mechanical" }
local METHOD_COL = {
    Heat = { r = 1, g = 0.45, b = 0.15 }, Cleaning = { r = 0.35, g = 0.75, b = 1 }, Oil = { r = 0.85, g = 0.7, b = 0.2 },
    Laser = { r = 0.9, g = 0.25, b = 0.9 }, Mechanical = { r = 0.7, g = 0.72, b = 0.78 },
}

-- The right treatment for a flaw (the guide on screen says the same).
function TWAPurifyGame.methodFor(kind, deep)
    if kind == "Fracture" then return deep and "Oil" or "Mechanical" end
    if kind == "Inclusion" then return deep and "Heat" or "Laser" end
    if kind == "Bubble" then return "Laser" end
    if kind == "ColorSpot" then return "Heat" end
    return "Cleaning" -- foreign matter on the surface
end

function TWAPurifyGame:onStart()
    self.phase = "find"
    self.rot = 0
    self.toolSize = 36
    self.loopWhileDragging = false
    self.gemCol = ({ { r = 0.3, g = 0.55, b = 0.95 }, { r = 0.9, g = 0.2, b = 0.32 }, { r = 0.25, g = 0.8, b = 0.45 }, { r = 0.65, g = 0.35, b = 0.9 } })[ZombRand(4) + 1]
    local n = 3 + math.floor(self.req / 4)
    self.flaws = {}
    for i = 1, n do
        local kind = KINDS[ZombRand(#KINDS) + 1]
        local deep = kind ~= "Foreign" and ZombRand(2) == 0
        self.flaws[i] = {
            theta = ZombRandFloat(0, 6.2832), rr = ZombRandFloat(0.25, 0.8), phi = ZombRandFloat(-0.6, 0.6),
            kind = kind, deep = deep, size = ZombRand(3) + 1, found = false, treated = false,
        }
    end
    self.cur = nil          -- the flaw being treated
    self.chosen = nil       -- its chosen method
    self.hold = 0           -- control progress 0..1
    self.gaugeC = 0.5
    self.timeLimit = 45000 + n * 14000
    self.hint = getText("IGUI_TWA_MG_Purify_Hint_find")
    self.hint2 = getText("IGUI_TWA_MG_Purify_Hint2_find")
end

-- Where flaw `f` is on screen now, and whether it faces the viewer.
function TWAPurifyGame:flawPos(f)
    local a = f.theta + self.rot
    return GX + math.sin(a) * f.rr * GR, GY + f.phi * GR * 0.85, math.cos(a) > 0.25
end

function TWAPurifyGame:flawRadius(f) return 4 + f.size * 2.5 end

-- Round 21 ("เล็กกลางใหญ่หมายถึงอะไร"): a flaw's SIZE is how much there is to
-- treat -- a bigger one takes longer in the gauge (small 1x, medium 1.5x,
-- large 2x) -- and its DEPTH how delicate it is: a deep one has a narrower
-- band to hold.
function TWAPurifyGame:treatMs()
    local f = self.cur
    return 1300 * (f and (1 + (f.size - 1) * 0.5) or 1)
end

function TWAPurifyGame:bandHalf()
    local f = self.cur
    return (f and f.deep and 0.07 or 0.1) * self.tol
end

-- The arrows that turn the gem.
function TWAPurifyGame:arrowAt(x, y)
    if B.dist(x, y, GX - GR - 30, GY) < 20 then return -1 end
    if B.dist(x, y, GX + GR + 30, GY) < 20 then return 1 end
    return nil
end

function TWAPurifyGame:methodRect(i)
    local w, gap = 110, 8
    local x0 = (B.PW - (#METHODS * w + (#METHODS - 1) * gap)) / 2
    return x0 + (i - 1) * (w + gap), 304, w, 36
end

function TWAPurifyGame:onMouseWheel(del)
    if self.phase == "find" then self.rot = self.rot + (del > 0 and 0.25 or -0.25) end
    return true
end

function TWAPurifyGame:allFound()
    for _, f in ipairs(self.flaws) do if not f.found then return false end end
    return true
end

function TWAPurifyGame:nextToTreat()
    for _, f in ipairs(self.flaws) do if not f.treated then return f end end
    return nil
end

function TWAPurifyGame:onGrab(x, y)
    if self.phase == "find" then
        if self:arrowAt(x, y) then self.turning = self:arrowAt(x, y) return end
        for _, f in ipairs(self.flaws) do
            local fx, fy, front = self:flawPos(f)
            if not f.found and front and B.dist(x, y, fx, fy) <= self:flawRadius(f) + 6 then
                f.found = true
                self:burst("ring", fx, fy, 1, { size = 6, grow = 0.1, ttl = 400, col = C.good })
                self:uiSound("TWA_Tick")
                if self:allFound() then self:toMethod() end
                return
            end
        end
        if B.dist(x, y, GX, GY) <= GR then
            self:spend(0.06, getText("IGUI_TWA_MG_Purify_Clean"))
        end
    elseif self.phase == "control" then
        self.armed = true
        return
    elseif self.phase == "method" then
        for i, m in ipairs(METHODS) do
            local bx, by, bw, bh = self:methodRect(i)
            if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
                if m == TWAPurifyGame.methodFor(self.cur.kind, self.cur.deep) then
                    self.chosen = m
                    self.phase = "control"
                    -- Round 21 ("เลือกถูกแล้วมันลดตลอด"): the click that picked
                    -- the method is still held -- the needle would read the
                    -- button row, the bottom of the gauge, and drain. The gauge
                    -- only counts after a NEW press.
                    self.armed = false
                    self.hold = 0
                    self.hint = getText("IGUI_TWA_MG_Purify_Hint_control")
                    self.hint2 = getText("IGUI_TWA_MG_Purify_Hint2_control")
                    self:uiSound("TWA_Tick")
                else
                    self:spend(0.1, getText("IGUI_TWA_MG_Purify_WrongMethod"))
                end
                return
            end
        end
    end
end

function TWAPurifyGame:onRelease() self.turning = nil; self.armed = false end

function TWAPurifyGame:toMethod()
    self.cur = self:nextToTreat()
    if not self.cur then return self:toCheck() end
    self.phase = "method"
    self.chosen = nil
    self.hint = getText("IGUI_TWA_MG_Purify_Hint_method")
    self.hint2 = getText("IGUI_TWA_MG_Purify_Hint2_method")
end

function TWAPurifyGame:toCheck()
    self.phase = "check"
    self.checkAt = self.elapsed
    self.hint = getText("IGUI_TWA_MG_Purify_Hint_check")
    self.hint2 = ""
    self:uiSound("TWA_Shimmer")
end

function TWAPurifyGame:gaugeCentre()
    return self.gaugeC + self:drift(0.2, self.fine and 2600 or 3400)
end

function TWAPurifyGame:updateGame(dt)
    local total = #self.flaws * 3
    local done = 0
    for _, f in ipairs(self.flaws) do
        if f.found then done = done + 1 end
        if f.treated then done = done + 2 end
    end
    if self.phase == "find" then
        -- the arrows turn the gem while the button is held over them
        self.turning = (self.dragging and self.hx) and self:arrowAt(self.hx, self.hy) or nil
        if self.turning then self.rot = self.rot + self.turning * dt * 0.0022 end
    elseif self.phase == "control" then
        local half = self:bandHalf()
        if self.dragging and self.armed and self.hy then
            local v = B.clamp(1 - (self.hy - GAUGE_Y) / GAUGE_H, 0, 1)
            self.needle = v
            local off = math.abs(v - self:gaugeCentre())
            if off <= half then
                self.hold = self.hold + dt / (self:treatMs() / self.pace)
                if ZombRand(3) == 0 then
                    local fx, fy = self:flawPos(self.cur)
                    self:burst("spark", fx, fy, 1, { speed = 0.12, ttl = 300, col = METHOD_COL[self.chosen] })
                end
            elseif off > half * 3 then
                self:spend(dt * 0.0003, getText("IGUI_TWA_MG_Purify_Strain"), true)
                if ZombRand(8) == 0 then self:shake(3, 120) end
            else
                self:spend(dt * 0.0001, getText("IGUI_TWA_MG_Purify_Off"), true)
            end
        end
        done = done + math.min(1, self.hold) * 2
        if self.hold >= 1 then
            self.cur.treated = true
            local fx, fy = self:flawPos(self.cur)
            self:burst("ring", fx, fy, 1, { size = 8, grow = 0.15, ttl = 500, col = C.good })
            self:toMethod()
        end
    elseif self.phase == "check" then
        if self.elapsed - self.checkAt > 1600 then self:succeed(getText("IGUI_TWA_MG_Purify_Done")) end
    end
    self.progress = math.min(1, done / math.max(1, total))
end

-- Drawing --------------------------------------------------------------------

function TWAPurifyGame:textL(str, x, y, c, a, font)
    self:drawText(str, self:ox() + x + 1, self:oy() + y + 1, 0, 0, 0, (a or 1) * 0.8, font or UIFont.Small)
    self:drawText(str, self:ox() + x, self:oy() + y, c.r, c.g, c.b, a or 1, font or UIFont.Small)
end

function TWAPurifyGame:flawWord(f)
    return getText("IGUI_TWA_MG_Purify_Kind_" .. f.kind) .. " (" .. getText(f.deep and "IGUI_TWA_MG_Purify_Deep" or "IGUI_TWA_MG_Purify_Shallow")
        .. ", " .. getText("IGUI_TWA_MG_Purify_Size" .. f.size) .. ")"
end

-- A flaw drawn at (x, y), scale k.
function TWAPurifyGame:drawFlaw(f, x, y, k, a)
    local r = self:flawRadius(f) * k
    local dark = { r = 0.12, g = 0.1, b = 0.12 }
    if f.kind == "Fracture" then
        self:line(x - r, y - r * 0.4, x + r, y + r * 0.5, 1.5 * k, a, dark)
        self:line(x, y, x + r * 0.4, y - r, 1 * k, a, dark)
    elseif f.kind == "Bubble" then
        self:ring(x, y, r * 0.8, 1.2 * k, a, { r = 0.95, g = 0.95, b = 1 }, 12)
        self:disc(x - r * 0.25, y - r * 0.25, r * 0.2, a, { r = 1, g = 1, b = 1 }, 6)
    elseif f.kind == "ColorSpot" then
        self:disc(x, y, r * 0.8, a * 0.8, { r = 1 - self.gemCol.r * 0.6, g = 0.6, b = 1 - self.gemCol.b * 0.6 }, 12)
    elseif f.kind == "Foreign" then
        self:quad(x - r * 0.7, y - r * 0.3, x + r * 0.4, y - r * 0.7, x + r * 0.7, y + r * 0.4, x - r * 0.3, y + r * 0.6, a, 0.35, 0.25, 0.12)
    else
        self:disc(x, y, r * 0.6, a, dark, 10)
        self:disc(x + r * 0.3, y - r * 0.2, r * 0.25, a, dark, 6)
    end
    if f.found and not f.treated then self:ring(x, y, r + 4 * k, 1.5, a, C.guide, 14) end
    if f.treated then self:ring(x, y, r + 4 * k, 1.5, a * 0.6, C.good, 14) end
end

function TWAPurifyGame:renderGame()
    self:velvet(0, 0, B.PW, B.PH, { tint = { r = 0.06, g = 0.06, b = 0.1 } })
    -- the gem, turning (its facets shift with the rotation)
    self:gemBrilliant(GX, GY, GR, self.gemCol, { seed = 21, rot = self.rot * 0.4 })
    local mx, my = self.hx or -999, self.hy or -999
    for _, f in ipairs(self.flaws) do
        local fx, fy, front = self:flawPos(f)
        if front then
            -- faint to the eye; clear once found or near the cursor
            local near = B.dist(mx, my, fx, fy) < 40
            local a = (f.found or near) and 0.95 or 0.18
            self:drawFlaw(f, fx, fy, 1, a)
        end
    end
    if self.phase == "find" then
        -- the turning arrows
        for _, d in ipairs({ -1, 1 }) do
            local ax = GX + d * (GR + 30)
            local hot = self.turning == d
            self:disc(ax, GY, 18, 0.9, hot and C.guide or { r = 0.2, g = 0.2, b = 0.24 }, 18)
            self:quad(ax + d * 8, GY, ax - d * 6, GY - 9, ax - d * 6, GY + 9, ax + d * 8, GY, 1, 1, 1, 1)
        end
        self:drawMicroscope(mx, my)
        self:drawList()
    elseif self.phase == "method" then
        self:drawGuide()
        self:drawCurrent()
        for i, m in ipairs(METHODS) do
            local bx, by, bw, bh = self:methodRect(i)
            local c = METHOD_COL[m]
            local hover = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
            self:rectRGB(bx, by, bw, bh, 0.95, c.r * (hover and 0.45 or 0.25), c.g * (hover and 0.45 or 0.25), c.b * (hover and 0.45 or 0.25))
            self:frame(bx, by, bw, bh, 1, c)
            self:textC(getText("IGUI_TWA_MG_Purify_Method_" .. m), bx + bw / 2, by + 10, { r = 1, g = 1, b = 1 }, 1)
        end
    elseif self.phase == "control" then
        self:drawCurrent()
        self:drawGauge()
    elseif self.phase == "check" then
        local purity = math.floor(self.quality * 100 + 0.5)
        self:glow(GX, GY, GR, self.gemCol, 0.6)
        self:textC(getText("IGUI_TWA_MG_Purify_Purity", tostring(purity)), 470, 150, C.good, 1, UIFont.Medium)
    end
end

-- The microscope: what is under the cursor, magnified 2.5x.
function TWAPurifyGame:drawMicroscope(mx, my)
    local k = 2.5
    self:disc(MX, MY, MR + 5, 1, { r = 0.25, g = 0.22, b = 0.18 }, 36)
    local base = self.gemCol
    self:disc(MX, MY, MR, 1, { r = base.r * 0.55, g = base.g * 0.55, b = base.b * 0.55 }, 36)
    local inside = B.dist(mx, my, GX, GY) <= GR
    if inside then
        -- facet lines drifting past, then the flaws under the lens
        for i = 0, 5 do
            local a = i * 1.047 + self.rot * 0.4
            local ox, oy = (GX - mx) * k * 0.2, (GY - my) * k * 0.2
            self:line(MX + ox, MY + oy, MX + ox + math.cos(a) * MR, MY + oy + math.sin(a) * MR, 1, 0.25, { r = 1, g = 1, b = 1 })
        end
        for _, f in ipairs(self.flaws) do
            local fx, fy, front = self:flawPos(f)
            local dx, dy = (fx - mx) * k, (fy - my) * k
            if front and dx * dx + dy * dy < (MR - 8) * (MR - 8) then
                self:drawFlaw(f, MX + dx, MY + dy, k * 0.8, 1)
            end
        end
    end
    self:ring(MX, MY, MR, 3, 1, { r = 0.55, g = 0.45, b = 0.3 }, 36)
    self:line(MX - 6, MY, MX + 6, MY, 1, 0.6, C.line)
    self:line(MX, MY - 6, MX, MY + 6, 1, 0.6, C.line)
    self:textC(getText("IGUI_TWA_MG_Purify_Microscope"), MX, MY + MR + 6, C.faint, 1)
end

-- What has been found so far.
function TWAPurifyGame:drawList()
    local y = 190
    local found = 0
    for _, f in ipairs(self.flaws) do if f.found then found = found + 1 end end
    self:textL(getText("IGUI_TWA_MG_Purify_Found", tostring(found), tostring(#self.flaws)), 400, y, C.line, 1)
    y = y + 18
    for _, f in ipairs(self.flaws) do
        if f.found then
            self:textL("- " .. self:flawWord(f), 404, y, { r = 0.85, g = 0.85, b = 0.7 }, 1)
            y = y + 15
            if y > 330 then break end
        end
    end
end

-- The treatment guide (method phase).
function TWAPurifyGame:drawGuide()
    local y = 30
    self:textL(getText("IGUI_TWA_MG_Purify_Guide"), 380, y, C.guide, 1)
    y = y + 18
    for n = 1, 7 do
        self:textL(getText("IGUI_TWA_MG_Purify_Rule" .. n), 384, y, { r = 0.8, g = 0.8, b = 0.8 }, 1)
        y = y + 15
    end
end

-- The flaw in hand, highlighted on the gem with its card.
function TWAPurifyGame:drawCurrent()
    if not self.cur then return end
    local fx, fy = self:flawPos(self.cur)
    self:ring(fx, fy, 16 + 3 * math.sin(self.elapsed * 0.01), 2, 1, C.guide, 18)
    local y = self.phase == "method" and 170 or 4
    self:rectRGB(380, y, 230, 44, 0.85, 0.08, 0.08, 0.1)
    self:frame(380, y, 230, 44, 1, C.guide)
    self:textL(getText("IGUI_TWA_MG_Purify_Current"), 388, y + 4, C.guide, 1)
    self:textL(self:flawWord(self.cur), 388, y + 22, C.line, 1)
end

-- The heat / force / agent gauge (control phase).
function TWAPurifyGame:drawGauge()
    local c = METHOD_COL[self.chosen] or C.guide
    local half = self:bandHalf()
    local function yOf(v) return GAUGE_Y + GAUGE_H * (1 - v) end
    local cen = self:gaugeCentre()
    self:rect(GAUGE_X - 3, GAUGE_Y - 3, 36, GAUGE_H + 6, 1, { r = 0.3, g = 0.28, b = 0.24 })
    self:gradient(GAUGE_X, GAUGE_Y, 30, GAUGE_H, { r = c.r, g = c.g * 0.6, b = c.b * 0.6 }, { r = 0.08, g = 0.08, b = 0.1 }, 12, 1)
    self:rect(GAUGE_X, yOf(cen + half), 30, yOf(cen - half) - yOf(cen + half), 0.85, C.good)
    if self.needle then self:line(GAUGE_X - 10, yOf(self.needle), GAUGE_X + 40, yOf(self.needle), 3, 1, C.line) end
    self:textC(getText("IGUI_TWA_MG_Purify_Gauge_" .. self.chosen), GAUGE_X + 15, GAUGE_Y + GAUGE_H + 8, c, 1)
    -- treatment progress
    self:rect(380, 90, 70, 8, 1, C.dark)
    self:rect(380, 90, 70 * math.min(1, self.hold), 8, 1, C.good)
end

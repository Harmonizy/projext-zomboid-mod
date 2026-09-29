--============================================================================
-- HARMONIE_TheWayToAttack -- STROKE minigame (client)
--
-- Drawing a tool along a line: sharpening/stropping an edge, filing and
-- polishing, carving a handle, sawing, running a weld bead, engraving.
--
-- Pick the tool up at the marked start and draw it along the guide to the
-- end, inside the band. Wandering out of the band costs quality (far out
-- breaks the stroke); going too fast skids and throws sparks. Each finished
-- stroke counts; lift and start again at the start mark for the next one.
--
-- variant "saw": back and forth without lifting -- every pass cuts deeper.
-- variant "weld": one long slow pass -- too fast leaves gaps, too slow burns
-- through. variant "engrave": one pass along a zig-zag pattern, precise and
-- slow. variant "carve": shavings curl off a stick.
--============================================================================

require "HARMONIE_TWA_MinigameBase"

TWAStrokeGame = TWAMinigameBase:derive("TWAStrokeGame")

local B = TWAMinigameBase
local C = B.COL
local atan2 = math.atan2 or math.atan

-- Bands halved (request 2026-09-28: "มินิเกมมีโซนที่กว้างเกินไป ลดลงมาครึ่ง
-- นึง"). The start mark still accepts the tool within 2.5 bands.
local VARIANTS = {
    -- Request 2026-09-28 ("การลับหรือการขัดอยากให้ต้องทำเยอะกว่านี้ และทำช้า
    -- ไปไม่ส่งผล ต้องสะบัด"): twice the strokes, and they are FLICKS -- the
    -- stone only bites while it moves at least `vmin` (slower just doesn't
    -- progress), with a much higher ceiling before it skids.
    -- Round 7 ("หากทำช้าไปให้ลดคุณภาพด้วย และให้ต้องใช้ความเร็วมากกว่านี้
    -- ไม่มีการเร็วเกินไปแล้วลดความคืบหน้า ... ให้ทำการขัดซัก 10 ครั้ง"): 10
    -- flicks, a higher minimum speed (0.5 -> 0.8 px/ms), a too-slow flick
    -- costs quality, and there is no "too fast" at all (vmax = nil).
    sharpen = { strokes = function() return 10 end, vmin = 0.8, band = 12, tool = "Whetstone2", flick = true },
    polish  = { strokes = function() return 10 end, vmin = 0.8, band = 14, flick = true },
    carve   = { strokes = function(req) return 3 + req end, vmax = 0.8, band = 6, tool = "KnifeSushi" },
    saw     = { strokes = function() return 6 end, vmax = 1.4, band = 7, tool = "Handsaw", alternate = true },
    -- Round 15: sawing a gem -- fewer, slow and careful strokes.
    gemsaw  = { strokes = function(req) return 6 + math.floor(req / 2) end, vmax = 0.9, band = 12, tool = "Handsaw", alternate = true },
    -- Burning is harder (round 6: "ให้ไหม้ยากกว่าเดิม"): the too-slow limit
    -- halved (0.05 -> 0.025) and it burns at half the rate.
    -- Band 5 -> 8 (round 7: "มันออกนอกโซนทั้งๆที่ก็ยังอยู่") -- on the zig-zag
    -- a 5 px half-width was narrower than the torch picture's own wobble;
    -- the zone is now also drawn filled and the contact point marked.
    weld    = { strokes = function() return 1 end, vmax = 0.22, vmin = 0.025, burnRate = 0.000125, band = 8, tool = "BlowTorch" },
    engrave = { strokes = function() return 1 end, vmax = 0.35, band = 4.5, tool = "KnifeSushi" },
}

local function buildPath(variant)
    if variant == "saw" or variant == "gemsaw" then
        return { { 170, 210 }, { 450, 210 } }
    elseif variant == "weld" and not TWAConfig.on("WeldZigzag") then
        return { { 110, 200 }, { 510, 200 } } -- sandbox: straight seam
    elseif variant == "weld" then
        -- Zig-zag weave along the seam again (round 6: "ให้โซนกลับไปเป็น
        -- ฟันปลา"; round 5 had made it a straight line).
        local pts = {}
        for i = 0, 10 do
            pts[#pts + 1] = { 110 + i * 40, 200 + ((i % 2 == 0) and -22 or 22) } -- deeper teeth to go with the wider band (round 7)
        end
        pts[1][2], pts[#pts][2] = 200, 200
        return pts
    elseif variant == "engrave" then
        return { { 130, 230 }, { 200, 160 }, { 270, 230 }, { 340, 160 }, { 410, 230 }, { 480, 160 } }
    elseif variant == "carve" then
        return { { 110, 200 }, { 510, 200 } }
    end
    return { { 110, 260 }, { 520, 150 } } -- a blade edge, heel to tip
end

-- Lengths along the polyline, for projecting a point onto it.
local function measure(path)
    local seg, total = {}, 0
    for i = 1, #path - 1 do
        local a, b = path[i], path[i + 1]
        local len = B.dist(a[1], a[2], b[1], b[2])
        seg[i] = { a = a, b = b, len = len, start = total }
        total = total + len
    end
    return seg, total
end

-- Closest point on the path: returns (fraction 0..1 along it, distance).
function TWAStrokeGame:project(x, y)
    local bestT, bestD = 0, math.huge
    for _, s in ipairs(self.seg) do
        local ax, ay, bx, by = s.a[1], s.a[2], s.b[1], s.b[2]
        local dx, dy = bx - ax, by - ay
        local u = ((x - ax) * dx + (y - ay) * dy) / (s.len * s.len)
        u = B.clamp(u, 0, 1)
        local px, py = ax + dx * u, ay + dy * u
        local d = B.dist(x, y, px, py)
        if d < bestD then bestD, bestT = d, (s.start + u * s.len) / self.total end
    end
    return bestT, bestD
end

function TWAStrokeGame:pointAt(t)
    local target = t * self.total
    for _, s in ipairs(self.seg) do
        if target <= s.start + s.len or _ == #self.seg then
            local u = B.clamp((target - s.start) / s.len, 0, 1)
            return s.a[1] + (s.b[1] - s.a[1]) * u, s.a[2] + (s.b[2] - s.a[2]) * u
        end
    end
    return self.path[1][1], self.path[1][2]
end

function TWAStrokeGame:onStart()
    local v = VARIANTS[self.variant] or VARIANTS.sharpen
    self.v = v
    self.path = buildPath(self.variant)
    local SND = { gemsaw = "TWA_Saw", sharpen = "TWA_Whetstone", polish = "TWA_Whetstone", carve = "TWA_Carve", saw = "TWA_Saw", weld = "TWA_Weld", engrave = "TWA_Carve" }
    self.loopSoundName = SND[self.variant or "sharpen"] -- round 11
    self.gemCol = ({ { r = 0.3, g = 0.55, b = 0.95 }, { r = 0.9, g = 0.2, b = 0.32 }, { r = 0.25, g = 0.8, b = 0.45 }, { r = 0.65, g = 0.35, b = 0.9 } })[ZombRand(4) + 1]
    self.seg, self.total = measure(self.path)
    -- Round 9: the tunable values come from the sandbox.
    local vr = self.variant or "sharpen"
    if vr == "sharpen" or vr == "polish" then
        local isS = vr == "sharpen"
        v = { strokes = function() return TWAConfig.num(isS and "SharpenStrokes" or "PolishStrokes", 1) end,
              vmin = TWAConfig.num("FlickMinSpeed", 0.01), band = TWAConfig.num(isS and "SharpenZone" or "PolishZone", 1),
              tool = v.tool, flick = true }
    elseif vr == "saw" then
        -- Round 14 ("มินิเกมเลื่อยขยายโซนมากกว่านี้ 3 เท่า และทำซ้ำ 20 ครั้ง"):
        -- band 7 -> 21 and 20 strokes (sandbox SawZone / SawStrokes).
        v = { strokes = function() return TWAConfig.num("SawStrokes", 1) end, vmax = v.vmax, band = TWAConfig.num("SawZone", 1), tool = v.tool, alternate = true }
    elseif vr == "weld" then
        local burn = TWAConfig.num("WeldBurnSpeed", 0)
        v = { strokes = v.strokes, vmax = TWAConfig.num("WeldMaxSpeed", 0.01), vmin = burn > 0 and burn or nil,
              burnRate = v.burnRate, band = TWAConfig.num("WeldZone", 1), tool = v.tool }
    end
    self.v = v
    self.need = math.max(1, math.floor(v.strokes(self.req)))
    self.done = 0
    self.band = v.band * self.tol
    -- (Round 17 doubled GemPolishing's zone; round 18 put it back: "ปรับโซน
    -- ขัดมณีไปเท่าเดิม".)
    self.vmax = v.vmax and (v.vmax * self.tol / self.pace) or math.huge
    self.vmin = v.vmin
    self.dir = 1          -- saw: +1 left->right, -1 right->left
    self.along = 0        -- 0..1 progress of the current stroke, in `dir`
    self.active = false
    self.bead = {}        -- weld/engrave: fractions laid so far
    self.timeLimit = 20000 + self.need * 7000 + (self.variant == "weld" and 20000 or 0)
    if v.tool and not self.realTool then self.toolTex = B.itemTex(v.tool) or self.toolTex end
    self.toolSize = 48
    -- Round 16: sharpening/polishing happens ON the stone; the cursor is the
    -- workpiece (the recipe's own item picture), not the stone.
    self.onStone = self.variant == "sharpen" or self.variant == "polish" or self.variant == nil
    self.hint = getText("IGUI_TWA_MG_Stroke_Hint")
    self.hint2 = getText("IGUI_TWA_MG_Stroke_Hint_" .. (self.variant or "sharpen"))
end

-- Where the current stroke starts (its first end, in the current direction).
function TWAStrokeGame:startPoint()
    return self:pointAt(self.dir == 1 and 0 or 1)
end

function TWAStrokeGame:onGrab(x, y)
    local sx, sy = self:startPoint()
    if B.dist(x, y, sx, sy) > self.band * 2.5 then
        self:flash(getText("IGUI_TWA_MG_Stroke_StartHere"), false, 900)
        return
    end
    self.active = true
    self.along = 0
    self.strokeStart = self.elapsed
end

function TWAStrokeGame:onRelease()
    if self.active and self.along > 0.05 then
        self:spend(0.03, getText("IGUI_TWA_MG_Stroke_Lifted"))
    end
    self.active = false
end

function TWAStrokeGame:finishStroke(x, y)
    -- Sharpening/polishing are flicks: a stroke that took too long on average
    -- (slower than vmin over its whole length) simply doesn't bite -- no
    -- penalty, it just doesn't count (request 2026-09-28: "ทำช้าไปไม่ส่งผล
    -- ต้องสะบัด"). Judged over the whole stroke, not frame by frame, so the
    -- first frames of a flick starting from rest aren't held against it.
    if self.v.flick then
        local ms = math.max(1, self.elapsed - (self.strokeStart or self.elapsed))
        if (self.total * self.along) / ms < self.vmin then
            self:spend(0.04, getText("IGUI_TWA_MG_Stroke_Flick"))
            self.active = false
            return
        end
    end
    self.done = self.done + 1
    self:burst("ring", x, y, 1, { size = 6, grow = 0.1, ttl = 350, col = C.good })
    if self.done >= self.need then
        self:succeed(getText("IGUI_TWA_MG_Stroke_Done"))
        return
    end
    if self.v.alternate then
        self.dir = -self.dir     -- keep going the other way without lifting
        self.along = 0
    else
        self.active = false
        self:flash(getText("IGUI_TWA_MG_Stroke_Again"), false, 700)
    end
end

function TWAStrokeGame:onDrag(x, y, dt)
    if not self.active then return end
    local t, d = self:project(x, y)
    if self.dir == -1 then t = 1 - t end

    if d > self.band * 3 then
        self:spend(0.06, getText("IGUI_TWA_MG_Stroke_Slipped"))
        self.active = false
        return
    elseif d > self.band then
        self:spend(dt * 0.00035 * (d / self.band), getText("IGUI_TWA_MG_Stroke_OffLine"), true)
    end

    local speed = self.handSpeed or 0
    if speed > self.vmax then
        self:tooFast(dt * 0.0004 * (speed / self.vmax - 1), getText("IGUI_TWA_MG_Stroke_TooFast"), x, y)
    elseif self.vmin and not self.v.flick and speed < self.vmin and self.along > 0.02 then
        self:spend(dt * (self.v.burnRate or 0.00025), getText("IGUI_TWA_MG_Stroke_TooSlow"), true)
        if ZombRand(4) == 0 then self:burst("ember", x, y, 1) end
    end

    -- Forward only, and no skipping ahead across the work -- a swipe that
    -- jumps ahead is "too fast" and costs, instead of silently not counting.
    -- (A flick is fast by design, so it may cover ground quickly; it is
    -- judged on its average speed when it reaches the end instead.)
    if t - self.along >= 0.2 and not self.v.flick then
        self:tooFast(0.02, getText("IGUI_TWA_MG_Stroke_TooFast"), x, y)
    elseif t > self.along then
        self.along = t
        if self.variant == "weld" or self.variant == "engrave" then
            self.bead[#self.bead + 1] = { t = self.dir == 1 and t or 1 - t, hot = self.elapsed, off = d <= self.band }
        end
        -- Feedback while working.
        if self.variant == "carve" and ZombRand(4) == 0 then
            self:burst("chip", x, y, 1, { col = C.wood, size = 3 })
        elseif self.variant == "saw" and ZombRand(3) == 0 then
            self:burst("dust", x, y + 8, 2)
        elseif self.variant == "gemsaw" and ZombRand(3) == 0 then
            self:burst("chip", x, y + 6, 1, { col = self.gemCol, size = 2 })
        elseif (self.variant == "sharpen" or self.variant == "polish") and ZombRand(5) == 0 then
            self:burst("spark", x, y, 1, { speed = 0.15, ttl = 250 })
        elseif self.variant == "weld" then
            self:burst("spark", x, y, 2, { speed = 0.2, ttl = 300 })
        end
    end
    if self.along >= 0.97 then self:finishStroke(x, y) end
end

function TWAStrokeGame:updateGame(dt)
    -- A flick only fills the gauge once it has counted.
    local part = (self.active and not self.v.flick) and self.along or 0
    self.progress = math.min(1, (self.done + part) / self.need)
end

function TWAStrokeGame:renderGame()
    local vr = self.variant or "sharpen"
    local p1, p2 = self.path[1], self.path[#self.path]
    if vr == "gemsaw" then
        -- A rough stone in its clamp; the cut deepens with every pass.
        -- Round 16: a rough stone (crust, gem showing through) clamped in a
        -- vise; the kerf deepens and glitters with the gem's colour.
        self:velvet(0, 0, 620, 350, { tint = { r = 0.09, g = 0.1, b = 0.13 } })
        self:metalPlate(120, 292, 380, 26, { tint = { r = 0.35, g = 0.36, b = 0.4 }, seed = 40, bolts = true })
        self:metalPlate(120, 200, 40, 92, { seed = 41, brush = "v" })
        self:metalPlate(460, 200, 40, 92, { seed = 42, brush = "v" })
        local gc = self.gemCol
        if not self.gemPts then
            self.gemPts = {}
            for i = 0, 10 do
                local a = i / 11 * 6.2832
                local k = 0.82 + 0.22 * B.hash(i, 77)
                self.gemPts[#self.gemPts + 1] = { 310 + math.cos(a) * 150 * k, 222 + math.sin(a) * 78 * k }
            end
        end
        self:roughGem(self.gemPts, gc, { seed = 13, windows = 3 })
        local depth = 140 * self.done / self.need
        self:rect(305, 150, 10, depth, 1, C.dark)
        self:rectRGB(305, 150, 2, depth, 0.9, gc.r, gc.g, gc.b)
        self:rectRGB(313, 150, 2, depth, 0.9, gc.r * 0.7, gc.g * 0.7, gc.b * 0.7)
        if depth > 10 then self:sparkle(310, 150 + depth, 7, 0.5 + 0.5 * math.abs(math.sin(self.elapsed * 0.006))) end
    elseif vr == "saw" then
        -- A plank seen from the front; the cut deepens with every pass.
        self:woodBoard(120, 150, 380, 150, { seed = 4 })
        local depth = 140 * self.done / self.need
        self:rect(306, 150, 8, depth, 1, C.dark)
    elseif vr == "weld" then
        self:metalPlate(100, 150, 420, 48, { seed = 1 })
        self:metalPlate(100, 202, 420, 48, { seed = 2 })
        self:line(100, 200, 520, 200, 3, 1, C.dark)
        for _, bd in ipairs(self.bead) do
            local x, y = self:pointAt(bd.t)
            local age = math.min(1, (self.elapsed - bd.hot) / 2500)
            local r, g, b = B.heatColor(1 - age * 0.8)
            self:rectRGB(x - 4, y - 5, 8, 10, 1, r, g, b)
        end
    elseif vr == "engrave" then
        self:metalPlate(110, 130, 400, 130, { seed = 4 })
        for _, bd in ipairs(self.bead) do
            local x, y = self:pointAt(bd.t)
            self:rect(x - 1.5, y - 1.5, 3, 3, 1, C.dark)
        end
    elseif vr == "carve" then
        self:woodBoard(100, 186, 420, 28, { seed = 6, knots = 1 })
        local shaved = 420 * self.done / self.need
        if shaved > 1 then self:woodBoard(100, 186, shaved, 28, { tint = { r = 0.66, g = 0.5, b = 0.3 }, seed = 7, knots = 0 }) end
    elseif self.onStone then
        -- Round 16 ("มินิเกมลับคมให้เปลี่ยนพื้นหลังเป็นหินลับมีดแทนแล้วให้เมาส์
        -- เป็นวัตถุดิบ"): the scene IS the whetstone (a leather strop for
        -- StropLeather, a pale fine stone for polishing), lying along the
        -- stroke; the piece being worked rides the cursor (drawTool below).
        local wear = self.done / self.need
        if self.procId == "StropLeather" then
            local x0, y0 = p1[1] - 60, math.min(p1[2], p2[2]) - 40
            self:woodBoard(x0 - 20, y0 - 30, p2[1] - p1[1] + 160, p1[2] - p2[2] + 140, { seed = 12, knots = 1 })
            local function S(s0, t0) -- a point on the strop: s along, t across
                local dx, dy = p2[1] - p1[1], p2[2] - p1[2]
                local l = math.sqrt(dx * dx + dy * dy)
                return p1[1] + dx / l * s0 - dy / l * t0, p1[2] + dy / l * s0 + dx / l * t0
            end
            local l = B.dist(p1[1], p1[2], p2[1], p2[2])
            local ax, ay = S(-50, -34); local bx, by = S(l + 50, -34); local cx, cy = S(l + 50, 34); local dx, dy = S(-50, 34)
            self:quad(ax, ay, bx, by, cx, cy, dx, dy, 1, 0.42, 0.25, 0.13)
            ax, ay = S(-50, -10); bx, by = S(l + 50, -10); cx, cy = S(l + 50, 10); dx, dy = S(-50, 10)
            self:quad(ax, ay, bx, by, cx, cy, dx, dy, 0.15 + 0.25 * wear, 0.2, 0.2, 0.22)
            for i = 1, 60 do
                local x, y = S(-50 + (l + 100) * B.hash(i, 61), -34 + 68 * B.hash(i, 62))
                self:rectRGB(x, y, 2, 2, 0.3, 0.55, 0.34, 0.18)
            end
        else
            self:woodBoard(0, 0, 620, 350, { seed = 18, knots = 2, tint = { r = 0.3, g = 0.2, b = 0.12 } })
            self:whetstone(p1[1], p1[2], p2[1], p2[2], 96, { fine = vr == "polish", wear = wear })
        end
    end
    if self.workTex then self:tex(self.workTex, 540, 20, 60, 60, 0.55) end

    -- Guide band and the start mark. The zone is drawn FILLED -- a strip
    -- per segment and a disc at every joint -- which is exactly the set of
    -- points within `band` of the path that the game measures, so the
    -- corners of a zig-zag look the way they count. It turns red while the
    -- tool is outside it.
    local col = self.active and C.guide or C.faint
    local offNow = self.active and self.hx and select(2, self:project(self.hx, self.hy)) > self.band
    -- Round 8: the zone was gold at low alpha and read as white on the
    -- steel -- now a strong blue fill with solid edges, red when out.
    local ZONE = { r = 0.15, g = 0.55, b = 1.0 }
    local fill = offNow and C.bad or ZONE
    if self.variant == "weld" then col = fill end
    for i = 1, #self.path - 1 do
        local a, b = self.path[i], self.path[i + 1]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local len = math.sqrt(dx * dx + dy * dy)
        local nx, ny = -dy / len * self.band, dx / len * self.band
        self:quad(a[1] + nx, a[2] + ny, b[1] + nx, b[2] + ny, b[1] - nx, b[2] - ny, a[1] - nx, a[2] - ny, 0.35, fill.r, fill.g, fill.b)
        self:line(a[1] + nx, a[2] + ny, b[1] + nx, b[2] + ny, 2, 0.9, col)
        self:line(a[1] - nx, a[2] - ny, b[1] - nx, b[2] - ny, 2, 0.9, col)
    end
    for i = 2, #self.path - 1 do
        self:disc(self.path[i][1], self.path[i][2], self.band, 0.35, fill, 14)
    end
    local sx, sy = self:startPoint()
    local pulse = 1 + 0.15 * math.sin(self.elapsed * 0.008)
    self:ring(sx, sy, 10 * pulse, 2, self.active and 0.35 or 1, C.guide, 18)
    local ex, ey = self:pointAt(self.dir == 1 and 1 or 0)
    self:ring(ex, ey, 6, 2, 0.6, C.faint, 14)
end

function TWAStrokeGame:renderOverlay()
    if not self.active or self.word then return end
    local t = self.dir == 1 and self.along or 1 - self.along
    local x, y = self:pointAt(t)
    self:disc(x, y, 3, 1, C.good, 10)
    self:textC(string.format("%d / %d", self.done, self.need), 310, 320, C.line, 0.9)
end

-- Round 16: on the stone, the hand holds the WORKPIECE -- the recipe's item
-- picture turned to lie along the stroke with its edge on the contact point
-- (a drawn blade when the recipe has no picture, e.g. practice).
function TWAStrokeGame:drawTool()
    if not self.onStone then return B.drawTool(self) end
    if not self.hx then return end
    local p1, p2 = self.path[1], self.path[#self.path]
    local dx, dy = p2[1] - p1[1], p2[2] - p1[2]
    local l = math.sqrt(dx * dx + dy * dy)
    local ux, uy = dx / l, dy / l
    local upx, upy = uy, -ux                       -- away from the stone's far side
    if upy > 0 then upx, upy = -upx, -upy end
    local red = (self.fastUntil or 0) > self.elapsed
    local gb = red and 0.35 or 1
    local ang = atan2(dy, dx)
    if self.workTex then
        local size = 84
        local cx, cy = self.hx + upx * size * 0.22, self.hy + upy * size * 0.22
        -- icons are drawn blade up-right (-45 degrees): turn that onto the stroke
        self:texRot(self.workTex, cx + 5, cy + 8, size, ang + 0.785, 0.35, 0, 0, 0)
        self:texRot(self.workTex, cx, cy, size, ang + 0.785, 1, 1, gb, gb)
    else
        local L, Wd = 150, 30
        local function P(s0, t0) return self.hx + ux * s0 + upx * t0, self.hy + uy * s0 + upy * t0 end
        local ax, ay = P(-L * 0.55, 0); local bx, by = P(L * 0.45, 0); local cx, cy = P(L * 0.3, Wd); local ex, ey = P(-L * 0.55, Wd)
        self:quad(ax + 5, ay + 8, bx + 5, by + 8, cx + 5, cy + 8, ex + 5, ey + 8, 0.3, 0, 0, 0)
        self:quad(ax, ay, bx, by, cx, cy, ex, ey, 1, 0.62, 0.64 * gb, 0.7 * gb)
        local fx, fy = P(-L * 0.55, Wd * 0.3); local gx, gy = P(L * 0.38, Wd * 0.3)
        self:quad(ax, ay, bx, by, gx, gy, fx, fy, 1, 0.85, 0.87 * gb, 0.9 * gb)
        local h1x, h1y = P(-L * 0.55, Wd * 0.15); local h2x, h2y = P(-L * 1.05, Wd * 0.15)
        local h3x, h3y = P(-L * 1.05, Wd * 0.85); local h4x, h4y = P(-L * 0.55, Wd * 0.85)
        self:quad(h1x, h1y, h2x, h2y, h3x, h3y, h4x, h4y, 1, 0.36, 0.22, 0.1)
    end
    self:ring(self.hx, self.hy, 5, 1.5, 0.9, C.dark, 12)
    self:disc(self.hx, self.hy, 3, 1, C.guide, 10)
end

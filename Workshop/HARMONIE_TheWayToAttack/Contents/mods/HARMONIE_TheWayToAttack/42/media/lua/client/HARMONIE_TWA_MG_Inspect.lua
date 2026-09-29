--============================================================================
-- HARMONIE_TheWayToAttack -- INSPECT minigame (client), gem-cutting
--
-- Round 15 (new category การเจียระไน). Looking at stones through a loupe.
--   "select"  (Rough Gem Selection): five rough stones on a tray; their
--             flaws only show under the loupe. Pick the cleanest one (click
--             it). Two trays.
--   "analyze" (Gemological Analysis): one stone; find and click every
--             inclusion / crack under the loupe before time runs out. A click
--             on clean stone is a false call and costs.
--   "qc"      (Quality Control): the same on a finished gem, more and
--             smaller flaws, a smaller loupe, less time.
--   "plan"    (Cut Planning): a rough stone with its inclusions showing;
--             move the cut outline and click to place it -- all of it inside
--             the stone, as big a part of it clear of flaws as you can.
--============================================================================

require "HARMONIE_TWA_MinigameBase"

TWAInspectGame = TWAMinigameBase:derive("TWAInspectGame")

local B = TWAMinigameBase
local C = B.COL

local GEMCOL = {
    { r = 0.85, g = 0.2, b = 0.3 }, { r = 0.25, g = 0.45, b = 0.9 }, { r = 0.3, g = 0.75, b = 0.4 },
    { r = 0.9, g = 0.7, b = 0.25 }, { r = 0.6, g = 0.35, b = 0.8 },
}

local function blobPts(cx, cy, r, seed, n)
    local pts = {}
    n = n or 10
    for i = 0, n - 1 do
        local a = i / n * 6.2832
        local k = 0.8 + 0.25 * B.hash(i, seed)
        pts[#pts + 1] = { cx + math.cos(a) * r * k, cy + math.sin(a) * r * k * 0.85 }
    end
    return pts
end

local function inside(pts, x, y)
    local c = false
    local j = #pts
    for i = 1, #pts do
        local xi, yi, xj, yj = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then c = not c end
        j = i
    end
    return c
end

function TWAInspectGame:onStart()
    local vr = self.variant or "analyze"
    self.vr = vr
    self.loupe = (vr == "qc" and 34 or 46) * math.min(1.4, self.tol)
    self.toolSize = 40
    self.loopWhileDragging = false
    if vr == "select" then
        self.round, self.rounds = 1, 2
        self:newTray()
        self.timeLimit = 40000
    elseif vr == "plan" then
        self.stone = {}
        for i = 0, 23 do self.stone[#self.stone + 1] = { 310 + math.cos(i / 24 * 6.2832) * 118, 180 + math.sin(i / 24 * 6.2832) * 118 } end
        self.flaws = {}
        for i = 1, 3 + math.floor(self.req / 3) do
            local x, y
            repeat
                x, y = ZombRandFloat(200, 420), ZombRandFloat(90, 270)
            until inside(self.stone, x, y)
            self.flaws[i] = { x = x, y = y, r = ZombRandFloat(5, 9) }
        end
        self.cutR = 50 * math.min(1.2, self.tol)
        self.timeLimit = 30000
    else
        -- Round 20 ("ชอบ texture มณีในมินิเกมเจียระไน ... เอาไปใช้ในมินิเกมอื่น
        -- ด้วย"): every gem here is the faceting game's brilliant, so the
        -- stone is its round outline.
        self.stone = {}
        for i = 0, 23 do self.stone[#self.stone + 1] = { 310 + math.cos(i / 24 * 6.2832) * 110, 180 + math.sin(i / 24 * 6.2832) * 110 } end
        local n = (vr == "qc" and 7 or 4) + math.floor(self.req / 3)
        self.flaws = {}
        for i = 1, n do
            local x, y
            repeat
                x, y = ZombRandFloat(200, 420), ZombRandFloat(80, 280)
            until inside(self.stone, x, y)
            self.flaws[i] = { x = x, y = y, r = vr == "qc" and 4 or 6, found = false, kind = ZombRand(3) }
        end
        self.need = n
        self.timeLimit = (vr == "qc" and 26000 or 34000) + n * 2500
    end
    self.hint = getText("IGUI_TWA_MG_Inspect_Hint_" .. vr)
    self.hint2 = getText("IGUI_TWA_MG_Inspect_Hint2_" .. vr)
end

function TWAInspectGame:newTray()
    self.stones = {}
    for i = 1, 5 do
        local cx = 110 + (i - 1) * 100
        local flaws = {}
        local nf = ZombRand(6)
        for k = 1, nf do flaws[k] = { dx = ZombRandFloat(-22, 22), dy = ZombRandFloat(-18, 18) } end
        self.stones[i] = { x = cx, y = 180, pts = blobPts(cx, 180, 36, i * 7 + self.round, 9), col = GEMCOL[i], flaws = flaws }
    end
    -- make sure there's a single cleanest
    local best = math.huge
    for _, s in ipairs(self.stones) do best = math.min(best, #s.flaws) end
    local seen = false
    for _, s in ipairs(self.stones) do
        if #s.flaws == best then
            if seen then s.flaws[#s.flaws + 1] = { dx = 5, dy = -8 } end
            seen = true
        end
    end
end

function TWAInspectGame:onGrab(x, y)
    local vr = self.vr
    if vr == "select" then
        for _, s in ipairs(self.stones) do
            if inside(s.pts, x, y) then
                local best, rank = math.huge, 0
                for _, o in ipairs(self.stones) do best = math.min(best, #o.flaws) end
                for _, o in ipairs(self.stones) do if #o.flaws < #s.flaws then rank = rank + 1 end end
                if #s.flaws == best then
                    self:flash(getText("IGUI_TWA_MG_Inspect_Good"), false, 800)
                else
                    self:spend(0.08 * rank, getText("IGUI_TWA_MG_Inspect_NotBest"))
                end
                self:burst("ring", s.x, s.y, 1, { size = 20, grow = 0.2, ttl = 400, col = C.guide })
                self.round = self.round + 1
                if self.round > self.rounds then
                    self:succeed(getText("IGUI_TWA_MG_Inspect_Done"))
                else
                    self:newTray()
                end
                return
            end
        end
    elseif vr == "plan" then
        -- Place the cut: every rim point inside the stone, flaws inside it cost.
        local out, bad = 0, 0
        for i = 0, 15 do
            local a = i / 16 * 6.2832
            if not inside(self.stone, x + math.cos(a) * self.cutR, y + math.sin(a) * self.cutR * 0.85) then out = out + 1 end
        end
        for _, f in ipairs(self.flaws) do
            if B.dist(x, y, f.x, f.y) < self.cutR then bad = bad + 1 end
        end
        self.placed = { x = x, y = y }
        if out > 0 then self:spend(0.03 * out, getText("IGUI_TWA_MG_Inspect_OutOfStone")) end
        -- Round 20 ("หากโดนตำหนิ 1 อัน ให้ถือว่าแย่เลย"): one flaw in the cut
        -- and the plan is Bad.
        if bad > 0 then
            self:spend(0.07 * bad, getText("IGUI_TWA_MG_Inspect_FlawInCut"))
            self.maxWord = "Bad"
        end
        self:succeed(getText("IGUI_TWA_MG_Inspect_Planned"))
    else
        if B.dist(x, y, self.hx or x, self.hy or y) > 999 then return end
        for _, f in ipairs(self.flaws) do
            if not f.found and B.dist(x, y, f.x, f.y) <= f.r + 5 then
                f.found = true
                self:burst("ring", f.x, f.y, 1, { size = 6, grow = 0.08, ttl = 350, col = C.good })
                local left = 0
                for _, g in ipairs(self.flaws) do if not g.found then left = left + 1 end end
                if left == 0 then self:succeed(getText("IGUI_TWA_MG_Inspect_Done")) end
                return
            end
        end
        self:spend(0.07, getText("IGUI_TWA_MG_Inspect_FalseCall"))
    end
end

function TWAInspectGame:onTimeout()
    if self.vr == "analyze" or self.vr == "qc" then
        local found = 0
        for _, f in ipairs(self.flaws) do if f.found then found = found + 1 end end
        if found >= #self.flaws * 0.6 then
            self.quality = self.quality * (found / #self.flaws)
            self:succeed(getText("IGUI_TWA_MG_Inspect_Done"))
            return
        end
    end
    self:fail(getText("IGUI_TWA_MG_TimeUp"))
end

function TWAInspectGame:updateGame(dt)
    local vr = self.vr
    if vr == "select" then
        self.progress = (self.round - 1) / self.rounds
    elseif vr == "plan" then
        self.progress = 0
    else
        local found = 0
        for _, f in ipairs(self.flaws) do if f.found then found = found + 1 end end
        self.progress = found / #self.flaws
    end
end

-- Round 16: a see-through crystal (the inspection looks INTO the stone).
function TWAInspectGame:drawStone(pts, col, alpha)
    -- round 20: the faceting game's brilliant (centre and size from the outline)
    local cx, cy, r = 0, 0, 0
    for _, p in ipairs(pts) do cx, cy = cx + p[1], cy + p[2] end
    cx, cy = cx / #pts, cy / #pts
    for _, p in ipairs(pts) do r = math.max(r, B.dist(cx, cy, p[1], p[2])) end
    self:gemBrilliant(cx, cy, r * 1.05, col, { seed = 5, alpha = alpha })
end

local function drawFlaw(self, x, y, r, kind, a)
    if kind == 1 then
        self:line(x - r, y - r * 0.4, x + r, y + r * 0.5, 1.5, a, C.dark)          -- crack
        self:line(x, y, x + r * 0.4, y - r, 1, a, C.dark)
    elseif kind == 2 then
        self:ring(x, y, r * 0.8, 1.2, a, { r = 0.95, g = 0.95, b = 1 }, 10)       -- bubble
    else
        self:disc(x, y, r * 0.6, a, C.dark, 8)                                    -- dark inclusion
    end
end

function TWAInspectGame:renderGame()
    local vr = self.vr
    local mx, my = self.hx or -999, self.hy or -999
    if vr == "select" then
        -- Round 16: rough stones on jeweller's velvet, crust with the gem
        -- colour showing through where they broke.
        self:velvet(30, 95, 560, 170)
        for i, s in ipairs(self.stones) do
            self:gemBrilliant(s.x, s.y, 34, s.col, { seed = i * 3 + self.round, glow = false })
            for _, f in ipairs(s.flaws) do
                local fx, fy = s.x + f.dx, s.y + f.dy
                if B.dist(mx, my, fx, fy) < self.loupe then drawFlaw(self, fx, fy, 5, 0, 1) end
            end
        end
    elseif vr == "plan" then
        self:velvet(0, 0, 620, 350, { tint = { r = 0.08, g = 0.09, b = 0.14 } })
        self:drawStone(self.stone, { r = 0.55, g = 0.62, b = 0.9 })
        for _, f in ipairs(self.flaws) do drawFlaw(self, f.x, f.y, f.r, 0, 0.9) end
        local px, py = mx, my
        if self.placed then px, py = self.placed.x, self.placed.y end
        -- the cut outline (an oval brilliant) that follows the hand
        local pts = {}
        for i = 0, 15 do
            local a = i / 16 * 6.2832
            pts[#pts + 1] = { px + math.cos(a) * self.cutR, py + math.sin(a) * self.cutR * 0.85 }
        end
        self:polyline(pts, 2, 1, C.guide, true)
        for i = 1, 16, 2 do self:line(px, py, pts[i][1], pts[i][2], 1, 0.35, C.guide) end
    else
        self:velvet(0, 0, 620, 350, { tint = { r = 0.08, g = 0.09, b = 0.14 } })
        if vr == "qc" then
            -- the finished gem: a real brilliant (round 16)
            self:gemBrilliant(310, 180, 128, { r = 0.3, g = 0.62, b = 0.98 }, { seed = 3 })
        else
            self:drawStone(self.stone, { r = 0.8, g = 0.3, b = 0.55 })
        end
        for _, f in ipairs(self.flaws) do
            if f.found then
                self:ring(f.x, f.y, f.r + 4, 2, 1, C.good, 12)
                drawFlaw(self, f.x, f.y, f.r, f.kind, 1)
            elseif B.dist(mx, my, f.x, f.y) < self.loupe then
                drawFlaw(self, f.x, f.y, f.r, f.kind, 1)
            end
        end
        self:textC(string.format("%d / %d", math.floor(self.progress * #self.flaws + 0.5), #self.flaws), 310, 322, C.line, 0.9)
    end
    if self.workTex then self:tex(self.workTex, 540, 20, 60, 60, 0.55) end
end

-- The loupe at the hand.
function TWAInspectGame:drawTool()
    if not self.hx or self.vr == "plan" then
        if self.hx then self:disc(self.hx, self.hy, 2.5, 1, C.guide, 10) end
        return
    end
    self:disc(self.hx, self.hy, self.loupe, 0.08, { r = 0.7, g = 0.85, b = 1 }, 32)
    self:ring(self.hx, self.hy, self.loupe + 1, 5, 1, { r = 0.5, g = 0.38, b = 0.14 }, 36)
    self:ring(self.hx, self.hy, self.loupe - 1, 1.5, 0.9, { r = 0.95, g = 0.8, b = 0.45 }, 36)
    self:line(self.hx - self.loupe * 0.55, self.hy - self.loupe * 0.35, self.hx - self.loupe * 0.2, self.hy - self.loupe * 0.7, 3, 0.35, C.steam)
    self:line(self.hx + self.loupe * 0.7, self.hy + self.loupe * 0.7, self.hx + self.loupe * 1.3, self.hy + self.loupe * 1.3, 6, 1, C.wood2)
    self:disc(self.hx, self.hy, 2, 1, C.guide, 8)
end

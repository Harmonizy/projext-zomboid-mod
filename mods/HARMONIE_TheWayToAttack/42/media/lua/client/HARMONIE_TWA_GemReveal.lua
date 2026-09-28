--============================================================================
-- HARMONIE_TheWayToAttack -- the Gemstone recipe's reveal after Finish (client)
--
-- Round 16 (request 2026-09-28: "ตอน Finish ให้มีหน้าต่างเปิดของแบบใหม่ ...
-- อลังการ สวยงาม มีความลุ้น" for the new หินมณี recipe). Same window and
-- drawing kit as the minigames; nothing to play:
--   * the rough stone sits under a spotlight, trembling, cracks spreading
--     through it and the light of whatever is "inside" leaking out,
--   * below it a roulette strip of everything a stone can hold scrolls past
--     a gold marker, ticking, slowing down... teasing a diamond right next
--     to where it stops,
--   * it stops, the stone bursts -- a flash, flying chips, rays in the
--     find's colour -- and the find stands there: a gem shown as a cut
--     brilliant with glints (the diamond with rainbow rays and a fanfare),
--     a dud as its plain item picture on the broken halves.
--
-- WHAT is found is rolled on the server (TWA_FinishCraftAction ->
-- TWACraftState.rollGemstone). The window finds the new item by the token
-- Finish stamped on it (TWA_CraftToken) -- any type, so the inventory is
-- walked by hand -- and only then plans where the strip will stop.
--============================================================================

require "HARMONIE_TWA_MinigameBase"
require "HARMONIE_TWA_Sound"

TWAGemReveal = TWAMinigameBase:derive("TWAGemReveal")

local B = TWAMinigameBase
local C = B.COL
local PX, PY, PW, PH = 20, 84, 620, 350
local BIG = UIFont.Massive or UIFont.Large

local CELL = 78                 -- strip cell width (px)
local STRIP_Y, STRIP_H = 256, 76
local MID_X = 310               -- the marker
local SPEED = 1.25              -- px per ms while spinning free
local SPIN_MIN = 2400           -- spin at least this long before slowing
local SLOW_MS = 4600            -- how long the slow-down lasts
local GIVE_UP_AT = 12000        -- no item by then: stop on "?"
local SETTLE_MS = 450           -- stopped -> the stone bursts

-- Colours for the duds (by type) -- the gems' come from TWARecipeData.GemRoll.
local DUD_COL = {
    ["Base.Clay"] = { 0.62, 0.42, 0.3 }, ["Base.ScrapMetal"] = { 0.58, 0.6, 0.66 },
    ["Base.Limestone"] = { 0.86, 0.84, 0.74 }, ["Base.Charcoal"] = { 0.22, 0.21, 0.22 },
    ["Base.CharcoalCrafted"] = { 0.22, 0.21, 0.22 }, ["Base.Coke"] = { 0.3, 0.3, 0.34 },
}
local DUNG_COL = { 0.42, 0.3, 0.15 }

local function scriptOf(fullType)
    local sm = ScriptManager and ScriptManager.instance
    return sm and sm:getItem(fullType)
end

local function texFor(fullType)
    local sc = scriptOf(fullType)
    local icon = sc and sc:getIcon()
    if not icon then return nil end
    return B.itemTex(icon) or (getTexture and getTexture("Item_" .. icon))
end

-- One strip entry for a type: its picture, colour, name and kind.
local function entryFor(fullType)
    local pool = TWARecipeData.GemRoll
    local short = fullType:match("%.([^%.]+)$") or fullType
    local e = { type = fullType, tex = texFor(fullType), kind = "dud" }
    local gc = pool.colour[short]
    if fullType == pool.diamond then e.kind = "diamond"
    elseif gc then e.kind = "gem" end
    local c = gc or DUD_COL[fullType] or (short:find("^Dung") and DUNG_COL) or { 0.6, 0.55, 0.5 }
    e.col = { r = c[1], g = c[2], b = c[3] }
    local sc = scriptOf(fullType)
    e.name = sc and sc:getDisplayName() or short
    return e
end

function TWAGemReveal.open(player, recipe, token)
    if TWAMinigame and TWAMinigame.instance then return end
    local ui = TWAGemReveal:openFor(player, nil, recipe, nil, nil)
    ui.token = token
    return ui
end

function TWAGemReveal:onStart()
    self.title = getText("IGUI_TWA_GemReveal_Title")
    self.hint = getText("IGUI_TWA_GemReveal_Hint")
    self.hint2 = ""
    self.timeLimit = 1e12
    self.toolTex = nil
    self.nextLook = 0
    self.pos = 0                -- strip scroll (px); cell i is centred at i*CELL - pos + MID_X
    self.lastCell = 0
    self.lastTickAt = -1e9
    -- The candidates (only types this game has), for the strip.
    local pool = TWARecipeData.GemRoll
    self.duds, self.gems = {}, {}
    for _, slot in ipairs(pool.bad) do
        for _, t in ipairs(slot) do if scriptOf(t) then self.duds[#self.duds + 1] = t end end
    end
    for _, t in ipairs(pool.gems) do if scriptOf(t) then self.gems[#self.gems + 1] = t end end
    self.hasDiamond = scriptOf(pool.diamond) ~= nil
    self.cells = {}
    self.entryCache = {}
    -- The stone.
    self.stonePts = {}
    for i = 0, 12 do
        local a = i / 13 * 6.2832
        local k = 0.82 + 0.22 * B.hash(i, 55)
        self.stonePts[#self.stonePts + 1] = { 310 + math.cos(a) * 118 * k, 128 + math.sin(a) * 92 * k }
    end
    self.crackSeeds = {}
    for i = 1, 9 do
        self.crackSeeds[i] = { a = 6.2832 * B.hash(i, 71), bend = (B.hash(i, 72) - 0.5) * 0.9, at = 300 + i * 420 }
    end
    TWASound.play("TWA_Tension", "MinigameSounds")
end

function TWAGemReveal:entry(fullType)
    local e = self.entryCache[fullType]
    if not e then e = entryFor(fullType); self.entryCache[fullType] = e end
    return e
end

-- Strip cell i: made up on first sight (a dud more often than not, a
-- diamond now and then to tease), except the ones the plan fixed.
function TWAGemReveal:cell(i)
    local c = self.cells[i]
    if c then return c end
    local r = ZombRand(100)
    local t
    if r < 7 and self.hasDiamond then t = TWARecipeData.GemRoll.diamond
    elseif r < 50 and #self.gems > 0 then t = self.gems[ZombRand(#self.gems) + 1]
    elseif #self.duds > 0 then t = self.duds[ZombRand(#self.duds) + 1] end
    c = t and self:entry(t) or { kind = "none", col = { r = 0.5, g = 0.5, b = 0.5 }, name = "?" }
    self.cells[i] = c
    return c
end

-- The new item, found by its token anywhere in the inventory (any type).
local function findByToken(cont, token, depth)
    local items = cont and cont:getItems()
    if not items then return nil end
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it:getModData().TWA_CraftToken == token then return it end
        if depth < 3 and (not instanceof or instanceof(it, "InventoryContainer")) and it.getInventory then
            local r = findByToken(it:getInventory(), token, depth + 1)
            if r then return r end
        end
    end
    return nil
end

function TWAGemReveal:lookForItem()
    if self.found or self.elapsed < self.nextLook then return end
    self.nextLook = self.elapsed + 200
    local it = findByToken(self.player:getInventory(), self.token, 0)
    if it then
        self.found = it
        self.result = self:entry(it:getFullType())
    end
end

-- Plan the slow-down: land exactly on a cell far enough ahead that the
-- speed eases smoothly to zero (ease-out cubic; its start speed matches).
function TWAGemReveal:plan()
    local p0 = self.pos
    local n = math.floor(SPEED * SLOW_MS / 3 / CELL + 0.5)
    local land = math.floor(p0 / CELL) + n
    self.landCell = land
    self.p0, self.p1, self.slowAt = p0, land * CELL, self.elapsed
    self.slowMs = 3 * (self.p1 - p0) / SPEED
    self.cells[land] = self.result or { kind = "none", col = { r = 0.6, g = 0.6, b = 0.6 }, name = "?" }
    -- the tease: a diamond on one side, a gem on the other
    if self.hasDiamond and not (self.result and self.result.kind == "diamond") then
        self.cells[land + 1] = self:entry(TWARecipeData.GemRoll.diamond)
    end
    if #self.gems > 0 then self.cells[land - 1] = self:entry(self.gems[ZombRand(#self.gems) + 1]) end
end

function TWAGemReveal:currentCell()
    return math.floor((self.pos + CELL / 2) / CELL)
end

function TWAGemReveal:updateGame(dt)
    self:lookForItem()
    local t = self.elapsed
    self.flashA = math.max(0, (self.flashA or 0) - dt / 600)
    if self.revealAt then
        local col = self.result and self.result.col or C.faint
        if self.result and self.result.kind ~= "dud" and ZombRand(2) == 0 then
            self:burst("spark", ZombRandFloat(120, 500), ZombRandFloat(20, 200), 1, { col = col, speed = 0.05, ttl = 1200 })
        end
        return
    end
    -- scroll
    if self.slowAt then
        local u = math.min(1, (t - self.slowAt) / self.slowMs)
        self.pos = self.p0 + (self.p1 - self.p0) * (1 - (1 - u) ^ 3)
        if u >= 1 and not self.stoppedAt then
            self.stoppedAt = t
            TWASound.play("TWA_Crack", "MinigameSounds")
            self:shake(6, 300)
        end
    elseif t > 500 then
        self.pos = self.pos + SPEED * dt * math.min(1, (t - 500) / 600)
        if t >= SPIN_MIN and (self.found or t >= GIVE_UP_AT) then self:plan() end
    end
    -- a tick for every cell that passes the marker
    local cc = self:currentCell()
    if cc ~= self.lastCell then
        self.lastCell = cc
        if t - self.lastTickAt > 55 then
            self.lastTickAt = t
            TWASound.play("TWA_Tick", "MinigameSounds")
        end
        self.pulse = 1
    end
    self.pulse = math.max(0, (self.pulse or 0) - dt / 180)
    -- the stone trembles harder as it slows down
    if self.slowAt and ZombRand(5) == 0 then
        local u = math.min(1, (t - self.slowAt) / self.slowMs)
        self:shake(1 + 4 * u, 120)
    end
    if self.stoppedAt and t - self.stoppedAt >= SETTLE_MS then self:reveal() end
end

function TWAGemReveal:reveal()
    self.revealAt = self.elapsed
    local e = self.result
    local col = e and e.col or C.faint
    self.flashA = 1
    self:shake(16, 700)
    TWASound.play("TWA_BigHit", "MinigameSounds")
    -- the crust flies apart
    self:burst("chip", 310, 128, 40, { speed = 0.6, ttl = 1200, col = { r = 0.45, g = 0.42, b = 0.4 }, size = 5 })
    self:burst("ring", 310, 128, 1, { size = 30, grow = 0.6, ttl = 900, col = col })
    if e and e.kind ~= "dud" and e.kind ~= "none" then
        self:burst("spark", 310, 128, 70, { speed = 0.55, ttl = 1300, col = col })
        TWASound.play("TWA_Shimmer", "MinigameSounds")
        if e.kind == "diamond" then TWASound.play("TWA_Fanfare", "MinigameSounds") end
    else
        self:burst("dust", 310, 150, 30, { speed = 0.3, ttl = 1200 })
        TWASound.play("TWA_Fail", "MinigameSounds")
    end
end

-- The light leaking from inside: the colour of the cell under the marker
-- while it spins, the find's once it stops.
function TWAGemReveal:innerColour()
    if self.stoppedAt and self.result then return self.result.col end
    return self:cell(self:currentCell()).col
end

function TWAGemReveal:renderGame()
    local t = self.elapsed
    local cx, cy = 310, 128
    self:velvet(0, 0, PW, PH, { tint = { r = 0.07, g = 0.06, b = 0.12 } })
    local col = self:innerColour()
    local res = self.revealAt and self.result
    -- spotlight cone
    for i = 1, 4 do
        local w = 60 + i * 45
        self:quad(cx - 30, -10, cx + 30, -10, cx + w, 240, cx - w, 240, 0.035, 1, 0.95, 0.85)
    end
    if res then
        -- rays in the find's colour (rainbow for the diamond)
        local since = t - self.revealAt
        local rot = since * 0.0005
        local n = res.kind == "dud" and 8 or 16
        for i = 0, n - 1 do
            local a = rot + i * 6.2832 / n
            local a2 = a + (res.kind == "dud" and 0.1 or 0.14)
            local rc = res.col
            if res.kind == "diamond" then
                local h = i / n * 6.2832 + since * 0.002
                rc = { r = 0.6 + 0.4 * math.sin(h), g = 0.6 + 0.4 * math.sin(h + 2.1), b = 0.6 + 0.4 * math.sin(h + 4.2) }
            end
            self:quad(cx, cy, cx + math.cos(a) * 520, cy + math.sin(a) * 520, cx + math.cos(a2) * 520, cy + math.sin(a2) * 520, cx, cy,
                res.kind == "dud" and 0.06 or 0.16, rc.r, rc.g, rc.b)
        end
        self:glow(cx, cy, 120, res.col, res.kind == "dud" and 0.3 or 0.9)
        -- the broken halves
        local L, R = {}, {}
        for _, p in ipairs(self.stonePts) do
            if p[1] <= cx then L[#L + 1] = { p[1] - 70, p[2] + 40 } else R[#R + 1] = { p[1] + 70, p[2] + 40 } end
        end
        if #L > 2 then self:roughGem(L, res.col, { seed = 3, windows = 0, alpha = 0.9 }) end
        if #R > 2 then self:roughGem(R, res.col, { seed = 4, windows = 0, alpha = 0.9 }) end
        local rise = math.min(1, since / 600)
        local y = cy + 10 - 20 * rise
        if (res.kind == "gem" or res.kind == "diamond") and res.tex then
            -- round 17: the gem's own picture, big, breathing, glinting
            local sz = 104 + 8 * math.sin(since * 0.003)
            self:disc(cx, y, 58, 0.45, res.col, 32)
            self:tex(res.tex, cx - sz / 2, y - sz / 2, sz, sz, 1)
            for k = 1, 3 do
                local tw = math.sin(since * 0.004 + k * 2.1)
                self:sparkle(cx + 34 * math.cos(k * 2.2), y + 30 * math.sin(k * 2.2), 12, math.max(0, tw) ^ 2)
            end
        elseif res.kind == "gem" or res.kind == "diamond" then
            self:gemBrilliant(cx, y, 58 + 6 * math.sin(since * 0.003), res.col, { seed = 11, rot = since * 0.0004 })
        elseif res.tex then
            self:disc(cx, y, 44, 0.4, res.col, 28)
            self:tex(res.tex, cx - 40, y - 40, 80, 80, 1)
        end
    else
        -- the stone, cracking, the light coming through
        local build = math.min(1, t / 7000)
        if self.slowAt then build = math.max(build, 0.4 + 0.6 * math.min(1, (t - self.slowAt) / self.slowMs)) end
        self:glow(cx, cy, 130, col, 0.25 + 0.6 * build * (0.7 + 0.3 * math.sin(t * 0.01)))
        self:roughGem(self.stonePts, col, { seed = 9, windows = 0 })
        for i, cs in ipairs(self.crackSeeds) do
            if t > cs.at then
                local grow = math.min(1, (t - cs.at) / 900)
                local len = 95 * grow
                local x1, y1 = cx + math.cos(cs.a) * 10, cy + math.sin(cs.a) * 8
                local mx, my = cx + math.cos(cs.a + cs.bend) * len * 0.55, cy + math.sin(cs.a + cs.bend) * len * 0.45
                local x2, y2 = cx + math.cos(cs.a - cs.bend * 0.5) * len, cy + math.sin(cs.a - cs.bend * 0.5) * len * 0.75
                self:polyline({ { x1, y1 }, { mx, my }, { x2, y2 } }, 6, 0.3 + 0.4 * build, col)
                self:polyline({ { x1, y1 }, { mx, my }, { x2, y2 } }, 2, 0.95, { r = math.min(1, col.r + 0.4), g = math.min(1, col.g + 0.4), b = math.min(1, col.b + 0.4) })
            end
        end
        self:sparkle(cx, cy, 10 + 14 * build, 0.3 + 0.7 * build * math.abs(math.sin(t * 0.007)))
    end
    self:drawStrip()
end

-- The roulette strip and its marker.
function TWAGemReveal:drawStrip()
    local y, h = STRIP_Y, STRIP_H
    self:rect(0, y - 4, PW, h + 8, 1, { r = 0.1, g = 0.08, b = 0.05 })
    self:gradient(0, y, PW, h, { r = 0.16, g = 0.14, b = 0.2 }, { r = 0.06, g = 0.05, b = 0.08 }, 8, 1)
    local first = math.floor((self.pos - MID_X) / CELL) - 1
    local last = math.floor((self.pos + PW - MID_X) / CELL) + 1
    local win = self.revealAt and self.landCell
    for i = first, last do
        local x = i * CELL - self.pos + MID_X
        local c = self:cell(i)
        local isWin = win == i
        local kindCol = (c.kind == "diamond" and { r = 0.9, g = 0.95, b = 1 }) or (c.kind == "gem" and c.col) or { r = 0.35, g = 0.32, b = 0.3 }
        self:rectRGB(x - CELL / 2 + 3, y + 4, CELL - 6, h - 8, isWin and 0.55 or 0.3, kindCol.r * 0.5, kindCol.g * 0.5, kindCol.b * 0.5)
        self:rectRGB(x - CELL / 2 + 3, y + h - 8, CELL - 6, 4, 1, kindCol.r, kindCol.g, kindCol.b)
        -- Round 17 ("เปลี่ยนรูปอัญมณีเก่าเป็นรูปอัญมณีของม็อดเราทั้งหมด"): every gem
        -- is its own item picture (tools/gen_item_icons.py), on a soft glow.
        if (c.kind == "gem" or c.kind == "diamond") and c.tex then
            self:disc(x, y + h / 2 - 2, 22, 0.35, c.col, 20)
            self:tex(c.tex, x - 24, y + h / 2 - 26, 48, 48, 1)
            self:sparkle(x - 10, y + h / 2 - 14, 5, 0.4 + 0.6 * math.max(0, math.sin(self.elapsed * 0.006 + i)))
        elseif c.kind == "gem" or c.kind == "diamond" then
            self:gemBrilliant(x, y + h / 2 - 2, 20, c.col, { glow = false, seed = i })
        elseif c.tex then
            self:tex(c.tex, x - 24, y + h / 2 - 26, 48, 48, 1)
        else
            self:textC("?", x, y + h / 2 - 12, C.faint, 1, UIFont.Medium)
        end
        if isWin then
            local a = 0.6 + 0.4 * math.sin(self.elapsed * 0.01)
            self:frame(x - CELL / 2 + 2, y + 3, CELL - 4, h - 6, a, c.col)
            self:frame(x - CELL / 2 + 1, y + 2, CELL - 2, h - 4, a, c.col)
        end
    end
    -- fade the ends
    for k = 0, 5 do
        self:rect(k * 14, y, 14, h, 0.6 - k * 0.1, { r = 0.03, g = 0.03, b = 0.04 })
        self:rect(PW - (k + 1) * 14, y, 14, h, 0.6 - k * 0.1, { r = 0.03, g = 0.03, b = 0.04 })
    end
    -- the marker
    local gold = { r = 1, g = 0.8, b = 0.3 }
    local p = 1 + 0.25 * (self.pulse or 0)
    self:quad(MID_X - 10 * p, y - 12, MID_X + 10 * p, y - 12, MID_X, y + 6, MID_X, y + 6, 1, gold.r, gold.g, gold.b)
    self:quad(MID_X - 10 * p, y + h + 12, MID_X + 10 * p, y + h + 12, MID_X, y + h - 6, MID_X, y + h - 6, 1, gold.r, gold.g, gold.b)
    self:line(MID_X, y + 2, MID_X, y + h - 2, 1.5, 0.5, gold)
end

function TWAGemReveal:renderOverlay()
    if self.flashA and self.flashA > 0 then
        local c = (self.result and self.result.col) or { r = 1, g = 1, b = 1 }
        self:rectRGB(0, 0, PW, PH, self.flashA * 0.85, 0.6 + 0.4 * c.r, 0.6 + 0.4 * c.g, 0.6 + 0.4 * c.b)
    end
    if not self.revealAt then return end
    local res = self.result
    local since = self.elapsed - self.revealAt
    local cx = 310
    if not res then
        self:textC(getText("IGUI_TWA_GemReveal_Lost"), cx, 206, C.faint, 1, UIFont.Medium)
        return
    end
    local title = (res.kind == "diamond" and "IGUI_TWA_GemReveal_Diamond") or (res.kind == "gem" and "IGUI_TWA_GemReveal_Gem")
        or "IGUI_TWA_GemReveal_Dud"
    local tc = res.kind == "dud" and C.faint or res.col
    self:textC(getText(title), cx, 12, tc, 1, res.kind == "dud" and UIFont.Medium or BIG)
    self:textC(res.name, cx, 206, res.kind == "dud" and C.line or tc, 1, UIFont.Medium)
    if since > 900 then
        self:textC(getText("IGUI_TWA_Reveal_Close"), cx, 232, C.faint, 0.6 + 0.4 * math.sin(self.elapsed * 0.006), UIFont.Small)
    end
end

-- Its own frame: nothing to play, no meter, no cancel button.
function TWAGemReveal:draw()
    self:drawRect(-self.x, -self.y, getCore():getScreenWidth(), getCore():getScreenHeight(), 0.72, 0, 0, 0)
    self:drawRect(0, 0, self.width, self.height, 0.97, 0.03, 0.025, 0.05)
    local c = (self.revealAt and self.result and self.result.col) or { r = 0.8, g = 0.65, b = 0.3 }
    self:drawRectBorder(0, 0, self.width, self.height, 1, c.r * 0.8, c.g * 0.8, c.b * 0.8)
    self:drawTextCentre(self.title, self.width / 2, 10, 1, 0.88, 0.55, 1, UIFont.Medium)
    self:drawTextCentre(self.hint or "", self.width / 2, 40, 0.75, 0.75, 0.75, 1, UIFont.Small)
    self:drawRect(PX, PY, PW, PH, 1, 0.01, 0.01, 0.015)
    self:setStencilRect(PX, PY, PW, PH)
    self:renderGame()
    self:drawParticles()
    self:renderOverlay()
    self:clearStencilRect()
    self:drawRectBorder(PX, PY, PW, PH, 1, 0.35, 0.35, 0.37)
end

function TWAGemReveal:finish()
    if self.closed then return end
    self.onResult = nil
    self:teardown()
end

function TWAGemReveal:canClose()
    return self.revealAt ~= nil and (self.elapsed - self.revealAt) > 900
end

function TWAGemReveal:onMouseDown()
    if self:canClose() then self:finish() end
    return true
end
function TWAGemReveal:onMouseUp() return true end
function TWAGemReveal:onMouseUpOutside() return true end
function TWAGemReveal:onMouseDownOutside() return self:onMouseDown() end
function TWAGemReveal:onRightMouseUp() return self:onMouseDown() end
function TWAGemReveal:onRightMouseUpOutside() return self:onMouseDown() end
function TWAGemReveal:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE and self:canClose() then self:finish() end
end
function TWAGemReveal:onTimeout() end

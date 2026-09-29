--============================================================================
-- HARMONIE_TheWayToAttack -- weapon modification window: gem sockets (client)
--
-- Round 18 (request 2026-09-29, with a layout picture): right-click a weapon
-- that carries a grade from this mod's crafting -> "ดัดแปลงอาวุธ". Built
-- with the same drawing kit as the minigames (TWAMinigameBase: gradients,
-- glows, sparkles, the gem pictures) plus NeatUI buttons (TWANeatButton):
--   left   -- the weapon's picture, name, tier, type and grade, and its 13
--             stats read LIVE from the item (the crafting window's list),
--             with the change a picked gem would make shown in green;
--   centre -- the weapon large, its sockets (by grade: F 0, E 1, D 2, C 3,
--             B 4, A 5, S 5 + a special one), and the gems in your bags;
--   right  -- socket counts, what the socketed gems give, the two rules.
-- Pick a socket, pick a gem, press Modify. A normal socket keeps its gem for
-- good (a new one can be set over it; the old one is lost); the special
-- socket's gem can be taken out again. All of it is decided on the server
-- (TWAGemSocket).
--============================================================================

require "ISUI/ISPanel"
require "HARMONIE_TWA_MinigameBase"
require "HARMONIE_TWA_CraftUI"
require "HARMONIE_TWA_GemSocket"
require "HARMONIE_TWA_Sound"

TWAGemSocketUI = TWAMinigameBase:derive("TWAGemSocketUI")

local B = TWAMinigameBase
local G = TWAGemSocket
local W, H = 1000, 680
local LX, LW = 16, 320
local CX, CW = 348, 320
local RX, RW = 684, 300
local TOP = 56
local SOCKET_Y = 336
local PICK_Y = 424
local CELL, GAP, PER_ROW = 48, 6, 6
local BOTTOM_Y = 616

local GRADE_COLOR = {
    S = { r = 1.0, g = 0.85, b = 0.15 }, A = { r = 0.4, g = 0.9, b = 1.0 }, B = { r = 0.4, g = 0.9, b = 0.4 },
    C = { r = 0.75, g = 0.9, b = 0.4 }, D = { r = 0.9, g = 0.8, b = 0.4 }, E = { r = 0.95, g = 0.6, b = 0.3 },
    F = { r = 0.85, g = 0.35, b = 0.3 },
}
local WHITE = { r = 1, g = 1, b = 1 }
local GOLD = { r = 1, g = 0.8, b = 0.3 }

local function shadowText(panel, text, x, y, c, a, font)
    panel:drawText(text, x + 1, y + 1, 0, 0, 0, (a or 1) * 0.8, font or UIFont.Small)
    panel:drawText(text, x, y, c.r, c.g, c.b, a or 1, font or UIFont.Small)
end

local function textW(text, font) return getTextManager():MeasureStringX(font or UIFont.Small, text) end

-- Shorten `text` to `maxW` pixels by whole characters (Thai is 3 bytes a
-- letter in UTF-8 -- cutting bytes would leave a broken letter).
local function fitText(text, maxW, font)
    if textW(text, font) <= maxW then return text end
    local s = text
    while #s > 0 and textW(s .. "..", font) > maxW do
        local i = #s
        while i > 1 and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do i = i - 1 end
        s = s:sub(1, i - 1)
    end
    return s .. ".."
end

local function gemColour(fullType)
    local short = fullType and fullType:match("%.([^%.]+)$")
    local c = short and TWARecipeData.GemRoll.colour[short]
    return c and { r = c[1], g = c[2], b = c[3] } or { r = 0.7, g = 0.7, b = 0.7 }
end

local function scriptOf(fullType)
    local sm = ScriptManager and ScriptManager.instance
    return sm and sm:getItem(fullType)
end

local function gemTex(fullType)
    local sc = scriptOf(fullType)
    return sc and B.itemTex(sc:getIcon())
end

local function gemName(fullType)
    local sc = scriptOf(fullType)
    return sc and sc:getDisplayName() or (fullType:match("%.([^%.]+)$") or fullType)
end

-- Window ---------------------------------------------------------------------

function TWAGemSocketUI.open(player, weapon)
    if TWAGemSocketUI.instance then TWAGemSocketUI.instance:close() end
    local x = (getCore():getScreenWidth() - W) / 2
    local y = (getCore():getScreenHeight() - H) / 2
    local o = ISPanel:new(math.floor(x), math.floor(y), W, H)
    setmetatable(o, TWAGemSocketUI)
    TWAGemSocketUI.__index = TWAGemSocketUI
    o.player, o.weapon = player, weapon
    o.background = false
    o.moveWithMouse = true
    o.elapsed = 0
    o.particles, o.flashes = {}, {}
    o.shakeX, o.shakeY = 0, 0
    o.selKey = nil
    o.pick = nil          -- { type, state } of the gem picked in the picker
    o:initialise()
    o:instantiate()
    o:addToUIManager()
    o:setWantKeyEvents(true)
    o:bringToTop()
    TWAGemSocketUI.instance = o
    G.onSync = function() end
    return o
end

-- The minigame kit draws at the play-area offset; this window has none.
function TWAGemSocketUI:ox() return 0 end
function TWAGemSocketUI:oy() return 0 end

function TWAGemSocketUI:createChildren()
    ISPanel.createChildren(self)
    self.confirmBtn = TWANeatButton:new(W - 16 - 190 - 12 - 230, BOTTOM_Y, 230, 44, getText("IGUI_TWA_Socket_Confirm"), self, TWAGemSocketUI.onConfirm)
    self.confirmBtn.neatTint = { r = 1, g = 0.8, b = 0.4 }
    self.confirmBtn:initialise()
    self:addChild(self.confirmBtn)
    self.closeBtn = TWANeatButton:new(W - 16 - 190, BOTTOM_Y, 190, 44, getText("IGUI_TWA_Socket_Close"), self, TWAGemSocketUI.close)
    self.closeBtn:initialise()
    self:addChild(self.closeBtn)
end

function TWAGemSocketUI:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if TWAGemSocketUI.instance == self then TWAGemSocketUI.instance = nil end
end

-- The weapon must still be the player's and still take gems.
function TWAGemSocketUI:weaponOk()
    local wpn = self.weapon
    if not wpn or not G.canUse(wpn) then return false end
    local c = wpn.getContainer and wpn:getContainer()
    return c ~= nil and c:isInCharacterInventory(self.player)
end

-- Gems in the player's own bags (bags inside included), one entry per type
-- AND state (round 19): { type, state, count, item }. Bookmarked
-- (unfinished) gems are left out.
local STATE_ORDER = {}
for i, st in ipairs(TWACraftState.GEM_STATES) do STATE_ORDER[st] = i end
function TWAGemSocketUI:ownedGems()
    local groups, list = {}, {}
    local order = {}
    for i, t in ipairs(G.gemTypes()) do order[t] = i end
    local function walk(cont, depth)
        local items = cont and cont:getItems()
        if not items then return end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local t = it:getFullType()
            if order[t] and not TWACraftState.isBookmarked(it) then
                local st = TWACraftState.gemState(it) or "Raw"
                local k = t .. "|" .. st
                local g = groups[k]
                if not g then
                    g = { type = t, state = st, count = 0, item = it }
                    groups[k] = g
                    list[#list + 1] = g
                end
                g.count = g.count + 1
            elseif depth < 3 and it.getInventory and (not instanceof or instanceof(it, "InventoryContainer")) then
                walk(it:getInventory(), depth + 1)
            end
        end
    end
    walk(self.player:getInventory(), 0)
    table.sort(list, function(a, b)
        if order[a.type] ~= order[b.type] then return order[a.type] < order[b.type] end
        return (STATE_ORDER[a.state] or 0) > (STATE_ORDER[b.state] or 0)
    end)
    return list
end

-- Socket keys in drawing order: "1".."n", then "sp".
function TWAGemSocketUI:socketKeys()
    local keys = {}
    for i = 1, G.slotCount(self.weapon) do keys[#keys + 1] = tostring(i) end
    if G.hasSpecial(self.weapon) then keys[#keys + 1] = "sp" end
    return keys
end

function TWAGemSocketUI:socketPos(idx, n)
    local size, gap = 44, 8 -- six fit across the centre panel
    local total = n * size + (n - 1) * gap
    local x0 = CX + (CW - total) / 2
    return x0 + (idx - 1) * (size + gap) + size / 2, SOCKET_Y + size / 2, size / 2
end

function TWAGemSocketUI:pickCellPos(i)
    local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
    local total = PER_ROW * CELL + (PER_ROW - 1) * GAP
    return CX + (CW - total) / 2 + col * (CELL + GAP), PICK_Y + 22 + row * (CELL + GAP)
end

-- The gems' bonus now, and with the picked gem in the picked socket.
function TWAGemSocketUI:bonusNowAndPreview()
    local now = G.totalBonus(self.weapon)
    if not (self.selKey and self.pick) then return now, now end
    return now, G.totalBonus(self.weapon, { key = self.selKey, type = self.pick.type, state = self.pick.state })
end

-- Input ----------------------------------------------------------------------

function TWAGemSocketUI:onMouseDown(x, y)
    if not self:weaponOk() then return true end
    local keys = self:socketKeys()
    for i, k in ipairs(keys) do
        local sx, sy, r = self:socketPos(i, #keys)
        if B.dist(x, y, sx, sy) <= r then
            self.selKey = (self.selKey == k) and nil or k
            TWASound.play("TWA_Tick", "MinigameSounds")
            return true
        end
    end
    for i, g in ipairs(self:visibleGems()) do
        local gx, gy = self:pickCellPos(i)
        if x >= gx and x <= gx + CELL and y >= gy and y <= gy + CELL and g.count > 0 then
            local same = self.pick and self.pick.type == g.type and self.pick.state == g.state
            self.pick = (not same) and { type = g.type, state = g.state } or nil
            TWASound.play("TWA_Tick", "MinigameSounds")
            return true
        end
    end
    if x >= W - 44 and x <= W - 12 and y >= 10 and y <= 42 then self:close() return true end
    return ISPanel.onMouseDown(self, x, y)
end

-- The picker shows 3 rows; the wheel scrolls through more.
local PICK_ROWS = 3
function TWAGemSocketUI:visibleGems()
    local all = self:ownedGems()
    local maxOff = math.max(0, math.ceil(#all / PER_ROW) - PICK_ROWS)
    self.pickRow = math.max(0, math.min(self.pickRow or 0, maxOff))
    local out = {}
    for i = self.pickRow * PER_ROW + 1, math.min(#all, (self.pickRow + PICK_ROWS) * PER_ROW) do out[#out + 1] = all[i] end
    return out, maxOff
end

function TWAGemSocketUI:onMouseWheel(del)
    self.pickRow = (self.pickRow or 0) + (del > 0 and 1 or -1)
    return true
end

function TWAGemSocketUI:onMouseUp(x, y) return ISPanel.onMouseUp(self, x, y) end
function TWAGemSocketUI:onMouseMove(dx, dy) return ISPanel.onMouseMove(self, dx, dy) end
function TWAGemSocketUI:onMouseMoveOutside(dx, dy) return ISPanel.onMouseMoveOutside(self, dx, dy) end
function TWAGemSocketUI:onMouseUpOutside(x, y) return ISPanel.onMouseUpOutside(self, x, y) end
function TWAGemSocketUI:onMouseDownOutside() end
function TWAGemSocketUI:onRightMouseUp() end
function TWAGemSocketUI:onRightMouseUpOutside() end
function TWAGemSocketUI:isKeyConsumed(key) return key == Keyboard.KEY_ESCAPE end
function TWAGemSocketUI:onKeyRelease(key) if key == Keyboard.KEY_ESCAPE then self:close() end end

-- What the confirm button would do now: "insert", "remove" or nil.
function TWAGemSocketUI:pendingOp()
    if not self:weaponOk() or not self.selKey then return nil end
    if self.pick then return "insert" end
    if self.selKey == "sp" and G.gemIn(self.weapon, "sp") then return "remove" end
    return nil
end

function TWAGemSocketUI:onConfirm()
    local op = self:pendingOp()
    if op == "insert" then
        local gem
        for _, g in ipairs(self:ownedGems()) do
            if g.type == self.pick.type and g.state == self.pick.state then gem = g.item break end
        end
        if not gem then return end
        G.requestInsert(self.player, self.weapon, self.selKey, gem)
        local sx, sy = self:selectedSocketXY()
        local col = gemColour(self.pick.type)
        self:burst("spark", sx, sy, 40, { speed = 0.35, ttl = 900, col = col })
        self:burst("ring", sx, sy, 1, { size = 20, grow = 0.25, ttl = 700, col = col })
        TWASound.play("TWA_Shimmer", "MinigameSounds")
        self.pick = nil
    elseif op == "remove" then
        G.requestRemove(self.player, self.weapon)
        TWASound.play("TWA_Tick", "MinigameSounds")
    end
end

function TWAGemSocketUI:selectedSocketXY()
    local keys = self:socketKeys()
    for i, k in ipairs(keys) do
        if k == self.selKey then
            local x, y = self:socketPos(i, #keys)
            return x, y
        end
    end
    return CX + CW / 2, SOCKET_Y
end

-- Frame loop -----------------------------------------------------------------

function TWAGemSocketUI:prerender()
    local now = getTimestampMs()
    local dt = math.min(200, now - (self.lastTick or now))
    self.lastTick = now
    self.elapsed = self.elapsed + dt
    local keep = {}
    for _, p in ipairs(self.particles) do
        p.age = p.age + dt
        if p.age < p.ttl then
            p.vy = p.vy + p.grav * dt
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
            p.size = p.size + p.grow * dt
            keep[#keep + 1] = p
        end
    end
    self.particles = keep
    local op = self:pendingOp()
    self.confirmBtn.enable = op ~= nil
    self.confirmBtn:setTitle(getText(op == "remove" and "IGUI_TWA_Socket_Remove" or "IGUI_TWA_Socket_Confirm"))
    if op == "insert" and self.selKey ~= "sp" and G.gemIn(self.weapon, self.selKey) then
        self.confirmBtn:setTooltip(getText("IGUI_TWA_Socket_ReplaceWarn"))
    elseif op == "insert" and self.selKey ~= "sp" then
        self.confirmBtn:setTooltip(getText("IGUI_TWA_Socket_PermanentWarn"))
    else
        self.confirmBtn:setTooltip(nil)
    end
    -- Round 19 ("ปุ่มดัดแปลงอาวุธ และปุ่มปิดโดนบังอยู่หลังหน้าต่าง"): a panel's
    -- render() runs AFTER its children, so the window drawn there covered
    -- the buttons. Everything is drawn here, before the children.
    local ok, err = pcall(self.drawAll, self)
    if not ok then
        print("[HARMONIE_TheWayToAttack] gem socket window error: " .. tostring(err))
        self:close()
    end
end

-- Only the little name tag at the mouse goes over the buttons.
function TWAGemSocketUI:render()
    if self.hoverName then
        local mx2, my2 = self:getMouseX(), self:getMouseY()
        local w = textW(self.hoverName) + 12
        self:drawRect(mx2 + 12, my2 + 12, w, 20, 0.95, 0.05, 0.05, 0.06)
        self:drawRectBorder(mx2 + 12, my2 + 12, w, 20, 1, 0.5, 0.5, 0.5)
        shadowText(self, self.hoverName, mx2 + 18, my2 + 14, WHITE, 1)
        self.hoverName = nil
    end
end

function TWAGemSocketUI:drawAll()
    local wpn = self.weapon
    -- backdrop and frame
    self:drawRect(0, 0, W, H, 0.96, 0.035, 0.035, 0.045)
    self:gradient(0, 0, W, 50, { r = 0.1, g = 0.09, b = 0.12 }, { r = 0.05, g = 0.05, b = 0.06 }, 8, 1)
    self:drawRectBorder(0, 0, W, H, 1, 0.45, 0.42, 0.38)
    self:line(0, 50, W, 50, 1, 0.8, { r = 0.3, g = 0.28, b = 0.25 })
    -- title: a little hammer, the title, the close cross
    self:line(22, 36, 38, 20, 5, 1, { r = 0.55, g = 0.36, b = 0.18 })
    self:quad(32, 12, 46, 26, 40, 32, 26, 18, 1, 0.8, 0.82, 0.86)
    shadowText(self, getText("IGUI_TWA_Socket_Title"), 56, 13, WHITE, 1, UIFont.Medium)
    self:line(W - 38, 16, W - 18, 36, 2, 0.8, WHITE)
    self:line(W - 18, 16, W - 38, 36, 2, 0.8, WHITE)
    -- the three panels
    for _, p in ipairs({ { LX, LW }, { CX, CW }, { RX, RW } }) do
        self:drawRect(p[1], TOP, p[2], BOTTOM_Y - TOP - 12, 0.9, 0.055, 0.055, 0.065)
        self:drawRectBorder(p[1], TOP, p[2], BOTTOM_Y - TOP - 12, 0.7, 0.2, 0.2, 0.22)
    end
    if not self:weaponOk() then
        shadowText(self, getText("IGUI_TWA_Socket_Gone"), CX + 20, TOP + 20, { r = 1, g = 0.5, b = 0.4 }, 1, UIFont.Medium)
        return
    end
    local info = self:weaponInfo()
    self:drawLeft(info)
    self:drawCentre(info)
    self:drawRight(info)
    -- hint at the bottom left
    self:drawRect(LX + 4, BOTTOM_Y + 10, 16, 24, 0.8, 0.3, 0.3, 0.32)
    self:line(LX + 12, BOTTOM_Y + 10, LX + 12, BOTTOM_Y + 20, 1, 0.9, { r = 0.1, g = 0.1, b = 0.1 })
    shadowText(self, getText("IGUI_TWA_Socket_Hint1"), LX + 30, BOTTOM_Y + 4, { r = 0.85, g = 0.85, b = 0.85 }, 1, UIFont.Medium)
    shadowText(self, getText("IGUI_TWA_Socket_Hint2"), LX + 30, BOTTOM_Y + 26, { r = 0.6, g = 0.6, b = 0.6 }, 1)
    self:drawParticles()
end

-- Live stats, tier, type (the same numbers as the item tooltip).
function TWAGemSocketUI:weaponInfo()
    local wpn = self.weapon
    local T = TWATierInfo
    local lf = T and T.liveOrFallback or function(item, m, fb) return item[m] and item[m](item) or fb end
    local stats = TWARecipeData.Stats and TWARecipeData.Stats[wpn:getFullType()]
    local i = {}
    i.minD, i.maxD = wpn:getMinDamage(), wpn:getMaxDamage()
    i.speed = lf(wpn, "getBaseSpeed", (stats and stats.baseSpeed) or 1.0)
    i.dps = ((i.minD + i.maxD) / 2) * i.speed
    i.tier = T and T.tierFromDps(i.dps) or nil
    i.tierName = (T and i.tier and T.TIER_NAMES[i.tier]) or ""
    i.tierCol = (T and i.tier and T.TIER_COLOR[i.tier]) or WHITE
    i.type = T and T.weaponTypeText(wpn, stats) or ""
    i.grade = G.grade(wpn)
    i.gradeCol = GRADE_COLOR[i.grade] or WHITE
    local now, prev = self:bonusNowAndPreview()
    local function d(f) return (prev[f] or 0) - (now[f] or 0) end
    i.dMin, i.dMax, i.dCond = d("MinDamage"), d("MaxDamage"), d("ConditionMax")
    i.rows = {
        { "IGUI_TWA_Stat_DPS", string.format("%.2f", i.dps), (i.dMin ~= 0 or i.dMax ~= 0) and string.format("%.2f", ((i.minD + i.dMin + i.maxD + i.dMax) / 2) * i.speed) },
        { "IGUI_TWA_Stat_MinDamage", string.format("%.1f", i.minD), i.dMin ~= 0 and string.format("%.1f", i.minD + i.dMin) },
        { "IGUI_TWA_Stat_MaxDamage", string.format("%.1f", i.maxD), i.dMax ~= 0 and string.format("%.1f", i.maxD + i.dMax) },
        { "IGUI_TWA_Stat_Speed", string.format("%.2f", i.speed) },
        { "IGUI_TWA_StatWeight", string.format("%.1f", wpn:getActualWeight()) },
        { "IGUI_TWA_Stat_Range", string.format("%.2f", wpn:getMaxRange()) },
        { "IGUI_TWA_Stat_CritChance", string.format("%.0f", lf(wpn, "getCriticalChance", (stats and stats.critChance) or 0)) .. "%" },
        { "IGUI_TWA_Stat_Condition", string.format("%.0f", wpn:getConditionMax()), i.dCond ~= 0 and string.format("%.0f", wpn:getConditionMax() + i.dCond) },
        { "IGUI_TWA_Stat_Durability", "1:" .. string.format("%.0f", wpn:getConditionLowerChance()) },
        { "IGUI_TWA_Stat_Knockdown", string.format("%.1f", lf(wpn, "getKnockdownMod", (stats and stats.knockdownMod) or 0)) },
        { "IGUI_TWA_Stat_PushPower", string.format("%.2f", lf(wpn, "getPushBackMod", (stats and stats.pushBackMod) or 0)) },
        { "IGUI_TWA_Stat_Handedness", getText(wpn:isTwoHandWeapon() and "IGUI_TWA_Stat_TwoHanded" or "IGUI_TWA_Stat_OneHanded") },
        { "IGUI_TWA_Stat_AttackStyle", tostring(lf(wpn, "getSubCategory", stats and stats.subCategory) or "-") },
    }
    return i
end

function TWAGemSocketUI:gradeBadge(x, y, grade, col)
    local w = 26
    self:drawRect(x, y, w, 22, 1, col.r * 0.35, col.g * 0.35, col.b * 0.35)
    self:drawRectBorder(x, y, w, 22, 1, col.r, col.g, col.b)
    local t = grade or "-"
    shadowText(self, t, x + (w - textW(t, UIFont.Medium)) / 2, y + 1, col, 1, UIFont.Medium)
end

function TWAGemSocketUI:drawLeft(i)
    local wpn = self.weapon
    local x, y = LX + 14, TOP + 14
    self:drawRect(x, y, 84, 84, 1, 0.03, 0.03, 0.035)
    self:drawRectBorder(x, y, 84, 84, 0.8, 0.35, 0.35, 0.38)
    local tex = wpn:getTexture()
    if tex then self:drawTextureScaled(tex, x + 6, y + 6, 72, 72, 1, 1, 1, 1) end
    local nx = x + 98
    shadowText(self, wpn:getDisplayName(), nx, y + 2, WHITE, 1, UIFont.Medium)
    -- Round 19 ("ไม่อยากให้มี ? ในจุดแสดง tier"): no middle dot (the game
    -- font may not have it), the tier and the type drawn side by side.
    local tx2 = nx
    if i.tierName ~= "" then
        shadowText(self, i.tierName, tx2, y + 30, i.tierCol, 1)
        tx2 = tx2 + textW(i.tierName) + 12
    end
    if i.type ~= "" then shadowText(self, i.type, tx2, y + 30, { r = 0.55, g = 0.75, b = 1 }, 1) end
    shadowText(self, getText("IGUI_TWA_Socket_Grade"), nx, y + 56, { r = 0.85, g = 0.85, b = 0.85 }, 1)
    self:gradeBadge(nx + textW(getText("IGUI_TWA_Socket_Grade")) + 10, y + 53, i.grade, i.gradeCol)
    y = y + 104
    self:line(LX + 12, y, LX + LW - 12, y, 1, 0.7, { r = 0.25, g = 0.24, b = 0.24 })
    y = y + 10
    local vx = LX + 190
    for _, r in ipairs(i.rows) do
        shadowText(self, getText(r[1]), LX + 16, y, { r = 0.82, g = 0.82, b = 0.82 }, 1)
        shadowText(self, r[2], vx, y, WHITE, 1)
        if r[3] then
            local ax = vx + textW(r[2]) + 6
            shadowText(self, "> " .. r[3], ax, y, { r = 0.45, g = 1, b = 0.5 }, 1)
        end
        y = y + 25
    end
end

-- One socket: a dark setting, the gem's picture, a lock for a filled normal
-- socket, a bright rim and an open lock for the special one.
function TWAGemSocketUI:drawSocket(sx, sy, r, key)
    local gem, gemState = G.gemIn(self.weapon, key)
    local special = key == "sp"
    local sel = self.selKey == key
    local rim = special and { r = 0.95, g = 0.95, b = 1 } or { r = 0.4, g = 0.4, b = 0.44 }
    if sel then
        self:glow(sx, sy, r * 1.3, GOLD, 0.5 + 0.3 * math.sin(self.elapsed * 0.008))
    elseif gem then
        self:glow(sx, sy, r * 1.1, gemColour(gem), 0.35)
    end
    self:disc(sx, sy, r, 1, { r = 0.07, g = 0.07, b = 0.08 }, 28)
    self:disc(sx, sy, r - 5, 1, { r = 0.03, g = 0.03, b = 0.035 }, 28)
    self:ring(sx, sy, r, special and 2.5 or 2, 1, sel and GOLD or rim, 28)
    local show, showState = gem, gemState
    if sel and self.pick then show, showState = self.pick.type, self.pick.state end
    if show then
        local t = gemTex(show)
        local a = (sel and self.pick) and (0.55 + 0.35 * math.sin(self.elapsed * 0.01)) or 1
        if t then self:tex(t, sx - r * 0.72, sy - r * 0.72, r * 1.44, r * 1.44, a) end
        self:sparkle(sx - r * 0.3, sy - r * 0.35, 5, math.max(0, math.sin(self.elapsed * 0.004 + sx)) ^ 2)
        self:stateDot(sx - r * 0.7, sy + r * 0.5, showState)
    else
        -- an empty setting: a faint cross
        self:line(sx - 6, sy, sx + 6, sy, 1, 0.4, rim)
        self:line(sx, sy - 6, sx, sy + 6, 1, 0.4, rim)
    end
    -- the lock badge
    local lx, ly = sx + r * 0.62, sy + r * 0.62
    if special then
        self:drawRect(lx - 6, ly - 3, 12, 9, 1, 0.9, 0.9, 1)
        self:ring(lx - 3, ly - 5, 3.5, 1.5, 1, { r = 0.9, g = 0.9, b = 1 }, 10) -- open shackle
    elseif gem then
        self:drawRect(lx - 6, ly - 3, 12, 9, 1, 0.6, 0.6, 0.64)
        self:ring(lx, ly - 5, 3.5, 1.5, 1, { r = 0.6, g = 0.6, b = 0.64 }, 10)
    end
end

function TWAGemSocketUI:drawCentre(i)
    local wpn = self.weapon
    local cx, cy = CX + CW / 2, TOP + 130
    -- spotlight and the weapon, big
    self:velvet(CX + 1, TOP + 1, CW - 2, 262, { tint = { r = 0.06, g = 0.055, b = 0.09 } })
    self:glow(cx, cy, 110, i.gradeCol, 0.35 + 0.1 * math.sin(self.elapsed * 0.003))
    local tex = wpn:getTexture()
    if tex then self:drawTextureScaled(tex, cx - 110, cy - 110, 220, 220, 1, 1, 1, 1) end
    -- sockets
    local keys = self:socketKeys()
    if #keys == 0 then
        shadowText(self, getText("IGUI_TWA_Socket_NoSlots"), CX + 16, SOCKET_Y + 18, { r = 0.8, g = 0.6, b = 0.5 }, 1)
    end
    for idx, k in ipairs(keys) do
        local sx, sy, r = self:socketPos(idx, #keys)
        self:drawSocket(sx, sy, r, k)
    end
    -- the gem picker
    self:line(CX + 12, PICK_Y - 6, CX + CW - 12, PICK_Y - 6, 1, 0.7, { r = 0.25, g = 0.24, b = 0.24 })
    shadowText(self, getText("IGUI_TWA_Socket_PickGem"), CX + 16, PICK_Y, { r = 0.9, g = 0.9, b = 0.9 }, 1)
    local vis, maxOff = self:visibleGems()
    if #vis == 0 then
        shadowText(self, getText("IGUI_TWA_Socket_NoGems"), CX + 16, PICK_Y + 30, { r = 0.6, g = 0.6, b = 0.6 }, 1)
    end
    if maxOff > 0 then
        shadowText(self, string.format("%d / %d", self.pickRow + 1, maxOff + 1), CX + CW - 50, PICK_Y, { r = 0.6, g = 0.6, b = 0.6 }, 1)
    end
    for n, g in ipairs(vis) do
        local gx, gy = self:pickCellPos(n)
        local have = g.count > 0
        local sel = self.pick ~= nil and self.pick.type == g.type and self.pick.state == g.state
        local mx, my = self:getMouseX(), self:getMouseY()
        local hover = mx >= gx and mx <= gx + CELL and my >= gy and my <= gy + CELL
        self:drawRect(gx, gy, CELL, CELL, 1, sel and 0.25 or (hover and have and 0.14 or 0.08), sel and 0.18 or 0.08, sel and 0.04 or (hover and have and 0.14 or 0.08))
        self:drawRectBorder(gx, gy, CELL, CELL, 1, sel and 1 or 0.3, sel and 0.8 or 0.3, sel and 0.3 or 0.32)
        local t = gemTex(g.type)
        if t then self:tex(t, gx + 6, gy + 4, CELL - 12, CELL - 12, have and 1 or 0.25) end
        if have then
            local ct = "x" .. tostring(g.count)
            shadowText(self, ct, gx + CELL - textW(ct) - 3, gy + CELL - 15, WHITE, 1)
        end
        self:stateDot(gx + 5, gy + CELL - 9, g.state)
        if hover then
            self.hoverName = gemName(g.type) .. " (" .. getText("IGUI_TWA_GemState_" .. g.state) .. "): " .. G.describe(G.ability(g.type, g.state))
        end
    end
end

function TWAGemSocketUI:drawRight(i)
    local wpn = self.weapon
    local x, y = RX + 16, TOP + 12
    shadowText(self, getText("IGUI_TWA_Socket_InfoTitle"), x, y, WHITE, 1, UIFont.Medium)
    self:line(x, y + 26, x + 100, y + 26, 2, 0.7, GOLD)
    y = y + 38
    local vx = RX + 180
    local rows = {
        { "IGUI_TWA_Socket_WeaponName", wpn:getDisplayName() },
        { "IGUI_TWA_Stat_Type", i.type ~= "" and i.type or "-" },
        { "IGUI_TWA_Socket_Grade", nil },
    }
    for _, r in ipairs(rows) do
        shadowText(self, getText(r[1]), x, y, { r = 0.8, g = 0.8, b = 0.8 }, 1)
        if r[2] then
            local v = fitText(r[2], RX + RW - 12 - vx)
            shadowText(self, v, vx, y, WHITE, 1)
        else
            self:gradeBadge(vx, y - 3, i.grade, i.gradeCol)
        end
        y = y + 26
    end
    y = y + 6
    self:line(x, y, RX + RW - 16, y, 1, 0.7, { r = 0.25, g = 0.24, b = 0.24 })
    y = y + 10
    shadowText(self, getText("IGUI_TWA_Socket_Effects"), x, y, WHITE, 1)
    y = y + 24
    -- every socketed gem and what it gives (round 19: by gem and state)
    local list = G.list(wpn)
    if #list == 0 then
        shadowText(self, getText("IGUI_TWA_Socket_NoEffects"), x + 4, y, { r = 0.6, g = 0.6, b = 0.6 }, 1)
        y = y + 22
    end
    for _, g in ipairs(list) do
        local c = gemColour(g.type)
        self:quad(x + 6, y + 2, x + 12, y + 8, x + 6, y + 14, x, y + 8, 1, c.r, c.g, c.b)
        local nm = gemName(g.type) .. " (" .. getText("IGUI_TWA_GemState_" .. g.state) .. ")"
        shadowText(self, nm, x + 20, y, { r = 0.9, g = 0.9, b = 0.9 }, 1)
        local ax = x + 26 + textW(nm)
        shadowText(self, fitText(G.describe(G.ability(g.type, g.state)), RX + RW - 12 - ax), ax, y, { r = 0.6, g = 0.9, b = 0.65 }, 1)
        y = y + 19
    end
    local total = G.totalBonus(wpn)
    y = y + 4
    -- (Kahlua has no next(): an explicit loop -- round 19's error at open)
    local any = false
    for _ in pairs(total) do any = true break end
    if any then
        shadowText(self, fitText(getText("IGUI_TWA_Socket_EffectTotalAll", G.describe(total)), RW - 30), x, y, { r = 0.45, g = 1, b = 0.5 }, 1)
    end
    -- the two rules
    local by = BOTTOM_Y - 12 - 166
    self:notice(RX + 10, by, RW - 20, 76, { r = 1, g = 0.6, b = 0.2 }, "IGUI_TWA_Socket_RuleNormal", "IGUI_TWA_Socket_RuleNormal2", false)
    self:notice(RX + 10, by + 82, RW - 20, 76, { r = 0.35, g = 0.65, b = 1 }, "IGUI_TWA_Socket_RuleSpecial", "IGUI_TWA_Socket_RuleSpecial2", not G.hasSpecial(wpn))
end

-- A small coloured dot for a gem's state (its tier colour).
function TWAGemSocketUI:stateDot(x, y, state)
    local tier = TWACraftState.GEM_STATE_TIER[state or "Raw"] or 2
    local c = (TWATierInfo and TWATierInfo.TIER_COLOR[tier]) or WHITE
    self:disc(x, y, 4, 1, { r = 0, g = 0, b = 0 }, 10)
    self:disc(x, y, 3, 1, c, 10)
end

function TWAGemSocketUI:notice(x, y, w, h, c, k1, k2, dim)
    local a = dim and 0.4 or 1
    self:drawRect(x, y, w, h, 0.9, c.r * 0.12, c.g * 0.12, c.b * 0.12)
    self:drawRectBorder(x, y, w, h, a, c.r, c.g, c.b)
    self:disc(x + 20, y + 22, 11, a, c, 16)
    shadowText(self, "!", x + 17, y + 14, { r = 0.1, g = 0.1, b = 0.1 }, a, UIFont.Medium)
    shadowText(self, getText(k1), x + 40, y + 12, c, a)
    local lines = {}
    local cur = ""
    for word in getText(k2):gmatch("%S+") do
        local cand = cur == "" and word or (cur .. " " .. word)
        if textW(cand) > w - 50 and cur ~= "" then lines[#lines + 1] = cur; cur = word else cur = cand end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    for n, l in ipairs(lines) do
        if n <= 3 then shadowText(self, l, x + 40, y + 18 + n * 15, { r = 0.8, g = 0.8, b = 0.8 }, a) end
    end
end

-- Right-click menu -------------------------------------------------------------

if Events and Events.OnFillInventoryObjectContextMenu then
    Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
        local player = getSpecificPlayer(playerNum)
        if not player then return end
        local item = items and items[1]
        if item and type(item) == "table" and item.items then item = item.items[1] end
        if not item or not G.canUse(item) then return end
        local c = item.getContainer and item:getContainer()
        if not c or not c:isInCharacterInventory(player) then return end
        context:addOption(getText("IGUI_TWA_Socket_Menu"), player, TWAGemSocketUI.open, item)
    end)
end

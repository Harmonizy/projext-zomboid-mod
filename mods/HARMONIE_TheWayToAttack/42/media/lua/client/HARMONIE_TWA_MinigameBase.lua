--============================================================================
-- HARMONIE_TheWayToAttack -- base class for the per-category procedure
-- minigames (client)
--
-- Request 2026-09-28 (phase 2): "เริ่มทำ minigame เพิ่ม ให้แยบยลเหมือน
-- ม็อดอ้างอิง" -- games as elaborate as Casualties Undead's. Written from
-- scratch after studying how CU builds its own (workflow.txt 8.15): the same
-- IDEAS -- a modal panel that captures the mouse, a tool that trails the
-- cursor and trembles with pain/panic (everything reads the TOOL's position,
-- not the raw cursor, so the tremor is real difficulty), a running quality
-- score that slips cost, particles/screen shake/flash messages for feel, and
-- tolerances that grow with the player's own skill -- but none of CU's code
-- or art. Graphics are line art drawn in code plus vanilla item icons loaded
-- at runtime (nothing third-party is redistributed).
--
-- A game subclasses TWAMinigameBase and overrides only:
--   onStart()               set the scene up
--   updateGame(dt)          per-frame logic (dt in ms)
--   renderGame()            draw the scene (play-area coordinates)
--   renderOverlay()         drawn over the tool cursor
--   onGrab(x,y) / onDrag(x,y,dt) / onRelease(x,y) / onHover(x,y,dt)
--   onTimeout()             default: fail
-- and calls succeed(text) / fail(text) / spend(amount, text) / flash /
-- shake / burst. The word comes from the quality left at succeed():
-- >= 0.85 Excellent, >= 0.6 Good, otherwise Bad; fail() is always Miss.
--============================================================================

require "ISUI/ISPanel"

TWAMinigameBase = ISPanel:derive("TWAMinigameBase")

local W, H = 660, 540
-- Play area, panel-relative.
local PX, PY, PW, PH = 20, 84, 620, 350
local FOOT_Y = 448
local CANCEL_W, CANCEL_H = 150, 30
local RESULT_LINGER_MS = 1100
-- Request 2026-09-28 ("การขยับเมาส์ในมินิเกมเร็วไปยังไม่เห็นผล"): the tool
-- follows the mouse more tightly than the first version's 60 ms.
local HAND_LAG_MS = 35
-- Request 2026-09-28: "ทำให้เกจคุณภาพลดลงเร็วขึ้นกว่านี้สองเท่า" -- every
-- slip costs twice what it did.
local DRAIN = 2

TWAMinigameBase.W, TWAMinigameBase.H = W, H
TWAMinigameBase.PW, TWAMinigameBase.PH = PW, PH

TWAMinigameBase.COL = {
    line   = { r = 0.92, g = 0.92, b = 0.92 },
    faint  = { r = 0.55, g = 0.55, b = 0.58 },
    guide  = { r = 0.95, g = 0.78, b = 0.25 },
    good   = { r = 0.45, g = 0.90, b = 0.45 },
    bad    = { r = 0.90, g = 0.30, b = 0.28 },
    wood   = { r = 0.42, g = 0.28, b = 0.14 },
    wood2  = { r = 0.30, g = 0.19, b = 0.09 },
    metal  = { r = 0.62, g = 0.64, b = 0.68 },
    dark   = { r = 0.16, g = 0.16, b = 0.18 },
    spark  = { r = 1.00, g = 0.80, b = 0.30 },
    ember  = { r = 1.00, g = 0.45, b = 0.10 },
    dust   = { r = 0.60, g = 0.52, b = 0.40 },
    steam  = { r = 0.85, g = 0.88, b = 0.92 },
}

-- Heat colour ramp: cold steel -> dull red -> orange -> yellow-white.
function TWAMinigameBase.heatColor(t)
    t = math.max(0, math.min(1.2, t or 0))
    if t < 0.35 then
        local k = t / 0.35
        return 0.35 + 0.25 * k, 0.35 - 0.2 * k, 0.38 - 0.25 * k
    elseif t < 0.7 then
        local k = (t - 0.35) / 0.35
        return 0.6 + 0.4 * k, 0.15 + 0.3 * k, 0.13 - 0.08 * k
    end
    local k = math.min(1, (t - 0.7) / 0.5)
    return 1.0, 0.45 + 0.5 * k, 0.05 + 0.6 * k
end

function TWAMinigameBase.itemTex(icon)
    if not icon then return nil end
    return getTexture("media/textures/Item_" .. icon .. ".png")
end

local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
TWAMinigameBase.clamp = clamp

function TWAMinigameBase.dist(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Opening / closing -----------------------------------------------------------

--- Class method: `TWAStrikeGame:openFor(player, procId, recipe, onResult, variant)`.
function TWAMinigameBase:openFor(player, procId, recipe, onResult, variant)
    local playerNum = player:getPlayerNum()
    local x = getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - W) / 2
    local y = getPlayerScreenTop(playerNum) + (getPlayerScreenHeight(playerNum) - H) / 2
    local ui = self:new(math.floor(x), math.floor(y), player, procId, recipe, onResult, variant)
    TWAMinigame.instance = ui
    ui:initialise()
    ui:instantiate()
    ui:addToUIManager()
    ui:setAlwaysOnTop(true)
    ui:setWantKeyEvents(true)
    ui:setCapture(true)
    ui:bringToTop()
    ui:onStart()
    return ui
end

function TWAMinigameBase:new(x, y, player, procId, recipe, onResult, variant)
    local o = ISPanel:new(x, y, W, H)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.procId = procId
    o.proc = TWAProcedures.List[procId]
    o.recipe = recipe
    o.onResult = onResult
    o.variant = variant
    o.moveWithMouse = false
    o.background = false
    o.title = o.proc and getText(o.proc.nameKey) or tostring(procId)

    -- Skill: `req` is what the procedure asks for, `have` the player's own
    -- level in that perk. Every level above the requirement widens the
    -- tolerances a little (capped), a higher requirement speeds things up.
    local req, have = 0, 0
    if o.proc and o.proc.skill then
        local name, lvl = o.proc.skill:match("^(%a+):(%d+)$")
        req = tonumber(lvl) or 0
        local perk = name and Perks[name]
        have = perk and player:getPerkLevel(perk) or 0
    end
    o.req, o.have = req, have
    o.tol = math.min(1.6, 1 + 0.06 * math.max(0, have - req))
    o.pace = 1 + 0.04 * req

    o.quality = 1
    o.progress = 0
    o.elapsed = 0
    o.timeLimit = 60000
    o.dragging = false
    o.particles = {}
    o.flashes = {}
    o.shakeAmt, o.shakeUntil, o.shakeX, o.shakeY = 0, 0, 0, 0
    o.hurt = 0
    o.mx, o.my = 0, 0
    -- The cursor is the tool the player is REALLY using (request 2026-09-28:
    -- "ขันน็อตอยากให้ตรงเมาส์เป็นรูปประแจหรือไขควงตามที่อุปกรณ์ในกรรมวิธีนั้น
    -- ต้องการ") -- the actual inventory item that satisfies the procedure's
    -- tool requirement, drawn with that item's own texture. For welding the
    -- torch (tool2) is what's in the hand, not the mask. Games only fall back
    -- to their own stock icon when no real tool item was found.
    local toolItem
    if o.proc then
        local first, second = o.proc.tool, o.proc.tool2
        if first and first.kind == "tag" and first.value == "WELDING_MASK" then first, second = second, first end
        toolItem = TWAProcedures.FindToolItem(first, player) or TWAProcedures.FindToolItem(second, player)
    end
    o.realTool = toolItem ~= nil
    o.toolTex = (toolItem and toolItem:getTexture()) or TWAMinigameBase.itemTex(o.proc and o.proc.icon)
    local stats = recipe and TWARecipeData.Stats[recipe.result]
    o.workTex = TWAMinigameBase.itemTex(stats and stats.icon)
    o.hint = ""
    o.hint2 = ""
    return o
end

-- Result state ----------------------------------------------------------------

function TWAMinigameBase:wordFromQuality()
    if self.quality >= 0.85 then return "Excellent" end
    if self.quality >= 0.6 then return "Good" end
    return "Bad"
end

function TWAMinigameBase:succeed(text)
    if self.word then return end
    self.progress = 1
    self.word = self:wordFromQuality()
    self.resultText = text
    self.resultAt = self.elapsed
    self.dragging = false
    self:burst("ring", PW / 2, PH / 2, 1, { size = 10, grow = 0.35, ttl = 700 })
    getSoundManager():playUISound("UISelectListItem")
end

function TWAMinigameBase:fail(text)
    if self.word then return end
    self.word = "Miss"
    self.quality = 0
    self.resultText = text
    self.resultAt = self.elapsed
    self.dragging = false
    self:shake(8, 400)
    self.hurt = 1
    getSoundManager():playUISound("UISelectListItem")
end

--- A slip. `amount` is quality lost before skill forgiveness; `text` flashes.
function TWAMinigameBase:spend(amount, text, quiet)
    if self.word or not amount or amount <= 0 then return end
    self.quality = math.max(0, self.quality - amount * DRAIN / self.tol)
    self.hurt = math.min(1, self.hurt + amount * 3)
    if text then self:flash(text, true) end
    if not quiet and amount >= 0.03 then self:shake(2 + amount * 30, 220) end
end

--- Moving too fast: a real penalty AND something you can see -- the tool
--- flashes red, sparks fly, the scene jolts.
function TWAMinigameBase:tooFast(amount, text, x, y)
    self:spend(amount, text, true)
    self.fastUntil = self.elapsed + 220
    if x and ZombRand(2) == 0 then self:burst("spark", x, y, 3, { speed = 0.35, ttl = 300, col = TWAMinigameBase.COL.bad }) end
    self:shake(3, 120)
end

function TWAMinigameBase:flash(text, bad, ms)
    if not text or text == "" then return end
    -- The same message repeating every frame refreshes, not stacks.
    for _, f in ipairs(self.flashes) do
        if f.text == text then f.until_ = self.elapsed + (ms or 700) return end
    end
    table.insert(self.flashes, 1, { text = text, bad = bad, until_ = self.elapsed + (ms or 700) })
    while #self.flashes > 3 do table.remove(self.flashes) end
end

function TWAMinigameBase:shake(amount, ms)
    if amount > self.shakeAmt or self.elapsed > self.shakeUntil then
        self.shakeAmt = amount
        self.shakeUntil = self.elapsed + (ms or 250)
    end
end

-- Particles: "spark" (bright, gravity), "ember" (rises), "dust", "chip"
-- (heavy), "steam" (rises, grows), "drop" (liquid), "ring" (expanding circle).
function TWAMinigameBase:burst(kind, x, y, n, o)
    o = o or {}
    local C = TWAMinigameBase.COL
    for _ = 1, n or 1 do
        if #self.particles > 240 then return end
        local ang = ZombRandFloat(0, 6.283)
        local spd = ZombRandFloat(0.3, 1) * (o.speed or 0.25)
        local p = { kind = kind, x = x, y = y, vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
                    age = 0, ttl = o.ttl or ZombRandFloat(250, 650), size = o.size or 2,
                    grow = o.grow or 0, col = o.col, grav = 0 }
        if kind == "spark" then
            p.col = p.col or C.spark; p.grav = 0.0012; p.vy = p.vy - 0.12
        elseif kind == "ember" then
            p.col = p.col or C.ember; p.vy = -math.abs(p.vy) * 0.4 - 0.03; p.vx = p.vx * 0.3
        elseif kind == "dust" then
            p.col = p.col or C.dust; p.grav = 0.0003; p.vx = p.vx * 0.6
        elseif kind == "chip" then
            p.col = p.col or C.metal; p.grav = 0.0016; p.vy = p.vy - 0.2; p.size = o.size or 3
        elseif kind == "steam" then
            p.col = p.col or C.steam; p.vy = -0.05 - math.abs(p.vy) * 0.2; p.vx = p.vx * 0.3; p.grow = o.grow or 0.02
        elseif kind == "drop" then
            p.col = p.col or C.ember; p.grav = 0.0015; p.vx = p.vx * 0.2; p.vy = math.abs(p.vy) * 0.2
        elseif kind == "ring" then
            p.col = p.col or C.line; p.vx, p.vy = 0, 0
        end
        self.particles[#self.particles + 1] = p
    end
end

-- Frame loop ------------------------------------------------------------------

-- Pain, panic and drink shake the hand. B42 reads these through
-- player:getStats():get(CharacterStat.X), each 0-100 (confirmed from
-- Casualties Undead's own B42 source, CasualtiesUndead_Physio.lua). The old
-- MoodleType.Pain/Panic/Drunk names don't exist in B42 -- the first version
-- of this function used them inside a pcall, and the game's debugger stops
-- on every error even when pcall catches it (bug report 2026-09-28). So:
-- no pcall, and every constant is checked before use; a missing one just
-- counts as 0. Result is on the old 0..12 "moodle levels" scale.
local function statOf(stats, key)
    local id = CharacterStat and CharacterStat[key]
    if not id then return 0 end
    return stats:get(id) or 0
end

function TWAMinigameBase:tremor()
    local stats = self.player.getStats and self.player:getStats()
    if not stats or not stats.get then return 0 end
    return (statOf(stats, "PAIN") + statOf(stats, "PANIC") + statOf(stats, "INTOXICATION")) / 25
end

function TWAMinigameBase:updateHand(dt)
    local tx, ty = self.mx, self.my
    if not self.rawX then self.rawX, self.rawY = tx, ty end
    local k = 1 - math.exp(-dt / HAND_LAG_MS)
    local px, py = self.rawX, self.rawY
    self.rawX = px + (tx - px) * k
    self.rawY = py + (ty - py) * k
    if dt > 0 then
        self.handVX = (self.rawX - px) / dt
        self.handVY = (self.rawY - py) / dt
    else
        self.handVX, self.handVY = 0, 0
    end
    self.handSpeed = math.sqrt(self.handVX * self.handVX + self.handVY * self.handVY)
    -- Tremor moves the contact point, not just the picture.
    local amp = 0.8 * (self.tremorLevel or 0)
    local t = self.elapsed
    self.hx = self.rawX + amp * math.sin(t * 0.021) + amp * 0.5 * math.sin(t * 0.057)
    self.hy = self.rawY + amp * math.cos(t * 0.017) + amp * 0.5 * math.sin(t * 0.043)
end

function TWAMinigameBase:tick()
    local now = getTimestampMs()
    local dt = math.min(200, now - (self.lastTick or now))
    self.lastTick = now
    self.elapsed = self.elapsed + dt

    if self.player:isDead() then
        self.onResult = nil
        self:teardown()
        return
    end

    self.mx = self:getMouseX() - PX
    self.my = self:getMouseY() - PY
    if (self.lastTremorAt or -1e9) + 500 < self.elapsed then
        self.lastTremorAt = self.elapsed
        self.tremorLevel = self:tremor()
    end
    self:updateHand(dt)

    if self.word then
        if self.elapsed - self.resultAt >= RESULT_LINGER_MS then self:deliver() return end
    else
        if self.elapsed > self.timeLimit then
            self:onTimeout()
        elseif self.dragging then
            self:onDrag(self.hx, self.hy, dt)
        else
            self:onHover(self.hx, self.hy, dt)
        end
        if not self.word then self:updateGame(dt) end
    end

    -- Effects.
    self.hurt = math.max(0, self.hurt - dt / 700)
    if self.elapsed < self.shakeUntil then
        local a = self.shakeAmt * (self.shakeUntil - self.elapsed) / 300
        self.shakeX, self.shakeY = ZombRandFloat(-a, a), ZombRandFloat(-a, a)
    else
        self.shakeX, self.shakeY = 0, 0
    end
    local keep = {}
    for _, p in ipairs(self.particles) do
        p.age = p.age + dt
        if p.age < p.ttl then
            p.vy = p.vy + p.grav * dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.size = p.size + p.grow * dt
            keep[#keep + 1] = p
        end
    end
    self.particles = keep
    local fl = {}
    for _, f in ipairs(self.flashes) do if f.until_ > self.elapsed then fl[#fl + 1] = f end end
    self.flashes = fl
end

function TWAMinigameBase:prerender()
    if self.closed then return end
    local ok, err = pcall(self.tick, self)
    if not ok then self:crash(err) end
end

function TWAMinigameBase:render()
    if self.closed then return end
    local ok, err = pcall(self.draw, self)
    if not ok then self:crash(err) end
end

function TWAMinigameBase:deliver()
    local cb = self.onResult
    self.onResult = nil
    local word = self.word
    self:teardown()
    if cb then cb(word) end
end

function TWAMinigameBase:teardown()
    if self.closed then return end
    self.closed = true
    pcall(function() self:onCleanup() end)
    if self.javaObject then
        self:setCapture(false)
        self:setWantKeyEvents(false)
    end
    self:setVisible(false)
    self:removeFromUIManager()
    if TWAMinigame.instance == self then TWAMinigame.instance = nil end
end

function TWAMinigameBase:crash(err)
    print("[HARMONIE_TheWayToAttack] minigame error (" .. tostring(err) .. "), scoring Excellent")
    self.word = TWACraftState.FALLBACK_WORD
    self:deliver()
end

-- Drawing kit (play-area coordinates; the scene shakes, the chrome doesn't) ---

function TWAMinigameBase:ox() return PX + (self.shakeX or 0) end
function TWAMinigameBase:oy() return PY + (self.shakeY or 0) end

function TWAMinigameBase:rect(x, y, w, h, a, c)
    self:drawRect(self:ox() + x, self:oy() + y, w, h, a, c.r, c.g, c.b)
end

function TWAMinigameBase:rectRGB(x, y, w, h, a, r, g, b)
    self:drawRect(self:ox() + x, self:oy() + y, w, h, a, r, g, b)
end

function TWAMinigameBase:frame(x, y, w, h, a, c)
    self:drawRectBorder(self:ox() + x, self:oy() + y, w, h, a, c.r, c.g, c.b)
end

-- A solid quad through four points (screen space is added here). Every line,
-- disc and ring below is built from this one call, like vanilla's drawLine2.
function TWAMinigameBase:quad(x1, y1, x2, y2, x3, y3, x4, y4, a, r, g, b)
    local jo = self.javaObject
    if not jo then return end
    local ax, ay = self:getAbsoluteX() + self:ox(), self:getAbsoluteY() + self:oy()
    jo:DrawTexture(nil, ax + x1, ay + y1, ax + x2, ay + y2, ax + x3, ay + y3, ax + x4, ay + y4, r, g, b, a)
end

function TWAMinigameBase:line(x1, y1, x2, y2, th, a, c)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then return end
    local nx, ny = -dy / len * th / 2, dx / len * th / 2
    self:quad(x1 + nx, y1 + ny, x2 + nx, y2 + ny, x2 - nx, y2 - ny, x1 - nx, y1 - ny, a, c.r, c.g, c.b)
end

function TWAMinigameBase:ring(cx, cy, rad, th, a, c, seg)
    seg = seg or math.max(16, math.floor(rad / 2))
    local px, py = cx + rad, cy
    for i = 1, seg do
        local ang = i / seg * 6.2832
        local x, y = cx + math.cos(ang) * rad, cy + math.sin(ang) * rad
        self:line(px, py, x, y, th, a, c)
        px, py = x, y
    end
end

function TWAMinigameBase:disc(cx, cy, rad, a, c, seg)
    seg = seg or math.max(12, math.floor(rad / 2))
    local px, py = cx + rad, cy
    for i = 1, seg do
        local ang = i / seg * 6.2832
        local x, y = cx + math.cos(ang) * rad, cy + math.sin(ang) * rad
        self:quad(cx, cy, px, py, x, y, cx, cy, a, c.r, c.g, c.b)
        px, py = x, y
    end
end

function TWAMinigameBase:polyline(pts, th, a, c, closed)
    for i = 1, #pts - 1 do
        self:line(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], th, a, c)
    end
    if closed and #pts > 2 then
        self:line(pts[#pts][1], pts[#pts][2], pts[1][1], pts[1][2], th, a, c)
    end
end

function TWAMinigameBase:tex(t, x, y, w, h, a, r, g, b)
    if not t then return end
    self:drawTextureScaled(t, self:ox() + x, self:oy() + y, w, h, a or 1, r or 1, g or 1, b or 1)
end

function TWAMinigameBase:textC(str, x, y, c, a, font)
    self:drawTextCentre(str, self:ox() + x, self:oy() + y, c.r, c.g, c.b, a or 1, font or UIFont.Small)
end

-- The tool in the player's hand, drawn at the trailing hand position.
function TWAMinigameBase:drawTool()
    if not self.hx then return end
    local s = self.toolSize or 44
    local lift = self.toolLift or 0
    if self.toolTex then
        local red = (self.fastUntil or 0) > self.elapsed
        self:tex(self.toolTex, self.hx - s * 0.25, self.hy - s * 0.85 - lift, s, s, 1, 1, red and 0.35 or 1, red and 0.35 or 1)
    else
        self:ring(self.hx, self.hy, 6, 2, 1, TWAMinigameBase.COL.line)
    end
    -- The exact contact point.
    self:disc(self.hx, self.hy, 2.5, 1, TWAMinigameBase.COL.guide, 10)
end

function TWAMinigameBase:drawParticles()
    for _, p in ipairs(self.particles) do
        local a = 1 - p.age / p.ttl
        if p.kind == "ring" then
            self:ring(p.x, p.y, p.size + p.age * (p.grow or 0.3), 2, a * 0.8, p.col)
        elseif p.kind == "steam" then
            self:disc(p.x, p.y, p.size, a * 0.25, p.col, 10)
        else
            self:rectRGB(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size, a, p.col.r, p.col.g, p.col.b)
        end
    end
end

function TWAMinigameBase:cancelRect()
    return W - CANCEL_W - 20, FOOT_Y + 44, CANCEL_W, CANCEL_H
end

function TWAMinigameBase:inCancel(x, y)
    local cx, cy, cw, ch = self:cancelRect()
    return x >= cx and x <= cx + cw and y >= cy and y <= cy + ch
end

function TWAMinigameBase:draw()
    local S = TWACraftState
    local C = TWAMinigameBase.COL
    self:drawRect(-self.x, -self.y, getCore():getScreenWidth(), getCore():getScreenHeight(), 0.6, 0, 0, 0)
    self:drawRect(0, 0, W, H, 0.97, 0.04, 0.04, 0.05)
    self:drawRectBorder(0, 0, W, H, 1, 0.6, 0.6, 0.62)

    -- Header.
    self:drawTextCentre(self.title, W / 2, 10, 1, 0.88, 0.55, 1, UIFont.Medium)
    self:drawTextCentre(self.hint or "", W / 2, 38, 0.86, 0.86, 0.86, 1, UIFont.Small)
    self:drawTextCentre(self.hint2 or "", W / 2, 56, 0.62, 0.62, 0.62, 1, UIFont.Small)

    -- Play area: clipped, shaken.
    self:drawRect(PX, PY, PW, PH, 1, 0.015, 0.015, 0.02)
    self:setStencilRect(PX, PY, PW, PH)
    self:renderGame()
    self:drawParticles()
    self:drawTool()
    self:renderOverlay()
    -- A red pulse at the edges on a slip, like the reference mod's vignette.
    if self.hurt > 0.02 then
        local a = self.hurt * 0.5
        self:drawRect(PX, PY, PW, 10, a, 0.8, 0.05, 0.05)
        self:drawRect(PX, PY + PH - 10, PW, 10, a, 0.8, 0.05, 0.05)
        self:drawRect(PX, PY, 10, PH, a, 0.8, 0.05, 0.05)
        self:drawRect(PX + PW - 10, PY, 10, PH, a, 0.8, 0.05, 0.05)
    end
    self:clearStencilRect()
    self:drawRectBorder(PX, PY, PW, PH, 1, 0.35, 0.35, 0.37)

    -- Flash messages, top of the play area.
    for i, f in ipairs(self.flashes) do
        local c = f.bad and C.bad or C.good
        self:drawTextCentre(f.text, W / 2, PY + 8 + (i - 1) * 18, c.r, c.g, c.b, 1, UIFont.Small)
    end

    -- Footer: progress, live quality word, time left, cancel.
    -- Bug report 2026-09-28 ("ui เกจ ไปบังคำที่อยู่ข้างหน้า เพราะคำยาว"): the
    -- bars used to start at a fixed x, under a long (Thai) label. Now they
    -- start after the WIDEST label, measured, and the time readout sits
    -- after the bars.
    local fy = FOOT_Y
    local tm = getTextManager()
    local live = self.word or self:wordFromQuality()
    local wc = S.WORD_COLOR[live]
    local progLabel = getText("IGUI_TWA_MG_Progress")
    local qualLabel = getText("IGUI_TWA_TooltipQuality", S.wordText(live))
    local widest = math.max(tm:MeasureStringX(UIFont.Small, progLabel),
        tm:MeasureStringX(UIFont.Small, getText("IGUI_TWA_TooltipQuality", S.wordText("Excellent"))),
        tm:MeasureStringX(UIFont.Small, getText("IGUI_TWA_TooltipQuality", S.wordText("Miss"))))
    local bx = 20 + widest + 12
    local left = math.max(0, (self.timeLimit - self.elapsed) / 1000)
    local timeText = getText("IGUI_TWA_MG_TimeLeft", string.format("%.0f", left))
    local bw = math.max(80, W - 20 - tm:MeasureStringX(UIFont.Small, timeText) - 16 - bx)
    self:drawText(progLabel, 20, fy, 0.7, 0.7, 0.7, 1, UIFont.Small)
    self:drawRect(bx, fy + 3, bw, 12, 1, 0.12, 0.12, 0.13)
    self:drawRect(bx, fy + 3, bw * clamp(self.progress, 0, 1), 12, 1, 0.9, 0.65, 0.2)
    self:drawRectBorder(bx, fy + 3, bw, 12, 1, 0.45, 0.45, 0.45)
    self:drawText(qualLabel, 20, fy + 22, wc.r, wc.g, wc.b, 1, UIFont.Small)
    self:drawRect(bx, fy + 25, bw, 8, 1, 0.12, 0.12, 0.13)
    self:drawRect(bx, fy + 25, bw * clamp(self.quality, 0, 1), 8, 1, wc.r, wc.g, wc.b)
    self:drawText(timeText, bx + bw + 16, fy, 0.7, 0.7, 0.7, 1, UIFont.Small)

    if self.word then
        local c = S.WORD_COLOR[self.word]
        self:drawTextCentre(S.wordText(self.word), W / 2 - 80, fy + 44, c.r, c.g, c.b, 1, UIFont.Large)
        if self.resultText then
            self:drawTextCentre(self.resultText, W / 2 - 80, fy + 72, 0.8, 0.8, 0.8, 1, UIFont.Small)
        end
    else
        local cx, cy, cw, ch = self:cancelRect()
        local over = self:inCancel(self:getMouseX(), self:getMouseY())
        self:drawRect(cx, cy, cw, ch, 1, over and 0.45 or 0.3, 0.1, 0.1)
        self:drawRectBorder(cx, cy, cw, ch, 1, 0.8, 0.35, 0.35)
        self:drawTextCentre(getText("IGUI_TWA_MG_Cancel"), cx + cw / 2, cy + 7, 1, 1, 1, 1, UIFont.Small)
    end
end

-- Input -------------------------------------------------------------------------

function TWAMinigameBase:onMouseDown(x, y)
    if self.word or self.closed then return true end
    if self:inCancel(x, y) then
        self:fail(getText("IGUI_TWA_MG_Cancelled"))
        return true
    end
    self.dragging = true
    self:onGrab(self.hx or self.mx, self.hy or self.my)
    return true
end

function TWAMinigameBase:onMouseUp(x, y)
    if self.dragging then
        self.dragging = false
        if not self.word then self:onRelease(self.hx or self.mx, self.hy or self.my) end
    end
    return true
end

function TWAMinigameBase:onMouseUpOutside(x, y) return self:onMouseUp(x, y) end
function TWAMinigameBase:onMouseDownOutside(x, y) return self:onMouseDown(-1, -1) end

function TWAMinigameBase:onRightMouseUp()
    self:fail(getText("IGUI_TWA_MG_Cancelled"))
    return true
end
function TWAMinigameBase:onRightMouseUpOutside() return self:onRightMouseUp() end
function TWAMinigameBase:onMouseWheel() return true end
function TWAMinigameBase:isKeyConsumed(key) return key == Keyboard.KEY_ESCAPE end
function TWAMinigameBase:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:fail(getText("IGUI_TWA_MG_Cancelled")) end
end

-- Subclass hooks ----------------------------------------------------------------

function TWAMinigameBase:onStart() end
function TWAMinigameBase:updateGame(dt) end
function TWAMinigameBase:renderGame() end
function TWAMinigameBase:renderOverlay() end
function TWAMinigameBase:onGrab(x, y) end
function TWAMinigameBase:onDrag(x, y, dt) end
function TWAMinigameBase:onRelease(x, y) end
function TWAMinigameBase:onHover(x, y, dt) end
function TWAMinigameBase:onCleanup() end
function TWAMinigameBase:onTimeout() self:fail(getText("IGUI_TWA_MG_TimeUp")) end

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
require "HARMONIE_TWA_Config"
require "HARMONIE_TWA_Sound"

TWAMinigameBase = ISPanel:derive("TWAMinigameBase")

local W, H = 660, 540
-- Play area, panel-relative.
local PX, PY, PW, PH = 20, 84, 620, 350
local FOOT_Y = 448
local CANCEL_W, CANCEL_H = 150, 30
local RESULT_LINGER_MS = 1100
-- Request 2026-09-28 ("การขยับเมาส์ในมินิเกมเร็วไปยังไม่เห็นผล"): the tool
-- follows the mouse more tightly than the first version's 60 ms.
local HAND_LAG_MS = 35 -- default; the sandbox "HandLagMs" is what is used (round 9)
-- Request 2026-09-28: "ทำให้เกจคุณภาพลดลงเร็วขึ้นกว่านี้สองเท่า" -- every
-- slip costs twice what it did.
local DRAIN = 2 -- default; the sandbox "QualityDrain" is what is used (round 9)

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
    ui.timeLimit = ui.timeLimit * TWAConfig.num("TimeLimit", 0.05)
    TWALog("Minigame", "%s started (variant %s, time limit %.1f)", tostring(procId), tostring(variant), tonumber(ui.timeLimit) or -1)
    -- A procedure can ask for its OWN picture as the cursor instead of the
    -- tool found (round 14: the bone spike showed the knife -- "เป็นรูปดาบ").
    if ui.proc and ui.proc.cursorIcon then
        for _, name in ipairs(TWAProcedures.IconNames(ui.proc)) do
            local t = TWAMinigameBase.itemTex(name)
            if t then ui.toolTex = t break end
        end
    end
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
    -- Round 9: every factor from the sandbox. `skillTol` is the skill part
    -- alone (it also forgives quality loss); `tol` adds the zone-size
    -- multiplier and is what every game scales its zones by.
    o.skillTol = math.min(TWAConfig.num("SkillZoneMax", 1), 1 + TWAConfig.num("SkillZonePerLevel", 0) * math.max(0, have - req))
    o.tol = o.skillTol * TWAConfig.num("ZoneSize", 0.05)
    o.pace = (1 + TWAConfig.num("SpeedPerNeededLevel", 0) * req) * TWAConfig.num("GameSpeed", 0.05)

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
    o.toolTex = toolItem and toolItem:getTexture()
    if not o.toolTex and o.proc then
        for _, name in ipairs(TWAProcedures.IconNames(o.proc)) do
            o.toolTex = TWAMinigameBase.itemTex(name)
            if o.toolTex then break end
        end
    end
    local stats = recipe and TWARecipeData.Stats[recipe.result]
    o.workTex = TWAMinigameBase.itemTex(stats and stats.icon)
    o.hint = ""
    o.hint2 = ""
    return o
end

-- Sound ------------------------------------------------------------------------
--
-- Round 9 (request 2026-09-28: "การเล่นมินิเกมอยากให้มีเสียงประกอบการทำ
-- action ต่างๆ"): while the tool is working (the mouse held down), the
-- game's working sound plays (loopSoundName, else the procedure's own
-- proc.sound -- this mod's synthesized TWA_* sounds since round 11). A game
-- can set `self.loopWhileDragging = false` and play short bursts with
-- self:sfx() instead (the hammer, one blow at a time). Sandbox
-- "MinigameSounds" turns it all off.

-- (Round 12: every sound is a short UI one-shot replayed while working --
-- see shared/HARMONIE_TWA_Sound.lua for why.)

function TWAMinigameBase:loopName()
    return self.loopSoundName or (self.proc and self.proc.sound)
end

function TWAMinigameBase:updateSound()
    local want = self.dragging and not self.word and self.loopWhileDragging ~= false
    if want then
        TWASound.keepPlaying(self, self:loopName(), "MinigameSounds")
    else
        TWASound.stop(self)
    end
end

--- One sound, once (a hammer blow). `ms` is ignored now (kept for callers).
function TWAMinigameBase:sfx(name, ms)
    TWASound.play(name, "MinigameSounds")
end

-- A result sound.
function TWAMinigameBase:uiSound(name)
    TWASound.play(name, "MinigameSounds")
end

function TWAMinigameBase:stopSounds()
    TWASound.stop(self)
end

-- Moving zones (round 14: "ฉันชอบการที่โซนขยับได้เหมือน อบเย็น เอาไปทำใน
-- มินิเกมอื่นด้วย"): an offset that sways a band slowly back and forth.
-- `amp` in the band's own units, `periodMs` one full sway. Sandbox
-- "ZoneDrift" off = no sway.
function TWAMinigameBase:drift(amp, periodMs, phase)
    if not TWAConfig.on("ZoneDrift") then return 0 end
    return amp * math.sin(self.elapsed * 6.2832 / periodMs + (phase or 0))
end

-- Result state ----------------------------------------------------------------

function TWAMinigameBase:wordFromQuality()
    -- a game can cap its word whatever the meter says (round 20: a cut plan
    -- through a flaw is Bad outright)
    if self.maxWord == "Bad" then return "Bad" end
    if self.quality >= TWAConfig.num("MinigameExcellentAt") then return "Excellent" end
    if self.quality >= TWAConfig.num("MinigameGoodAt") then return "Good" end
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
    self:uiSound("TWA_Success")
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
    self:uiSound("TWA_Fail")
end

--- A slip. `amount` is quality lost before skill forgiveness; `text` flashes.
function TWAMinigameBase:spend(amount, text, quiet)
    if self.word or not amount or amount <= 0 then return end
    self.quality = math.max(0, self.quality - amount * TWAConfig.num("QualityDrain", 0) * (self.drainMul or 1) / (self.skillTol or 1))
    self.hurt = math.min(1, self.hurt + amount * 3)
    if text then self:flash(text, true) end
    if not quiet and amount >= 0.03 then self:shake(2 + amount * 30, 220) end
    -- Request 2026-09-28: "เกจคุณภาพถึง 0 ให้ถือว่าพลาดเลย และออกจากหน้า
    -- มินิเกม" -- an empty quality meter ends the game as a Miss at once.
    if self.quality <= 0 and TWAConfig.on("QualityZeroIsMiss") then
        self:fail(getText("IGUI_TWA_MG_QualityGone"))
    end
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
    if not TWAConfig.on("Tremor") then return 0 end
    local stats = self.player.getStats and self.player:getStats()
    if not stats or not stats.get then return 0 end
    return (statOf(stats, "PAIN") + statOf(stats, "PANIC") + statOf(stats, "INTOXICATION")) / 25
end

function TWAMinigameBase:updateHand(dt)
    local tx, ty = self.mx, self.my
    if not self.rawX then self.rawX, self.rawY = tx, ty end
    local lag = TWAConfig.num("HandLagMs", 0)
    local k = lag > 0 and (1 - math.exp(-dt / lag)) or 1
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
    self:updateSound()

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
    self:stopSounds()
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
    TWALog("Minigame", "%s error (%s), scoring Excellent", tostring(self.procId), tostring(err))
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

-- Materials ----------------------------------------------------------------
--
-- Round 6 (request 2026-09-28: "texture เหล็กในมินิเกมบางอันไม่เหมือนเหล็ก
-- ใส่ใจเรื่อง texture วัสดุต่างๆในมินิเกมมากกว่านี้"): flat single-colour
-- rectangles read as "a grey box", not steel or wood. These draw a surface
-- the way it catches light: a top-to-bottom shading gradient, the grain or
-- brushing of the material, a soft specular sheen, and a bevelled edge.
-- Everything is deterministic (no per-frame randomness), so nothing
-- flickers.

local function hash(i, k)
    local v = math.sin(i * 12.9898 + (k or 0) * 78.233) * 43758.5453
    return v - math.floor(v)
end
TWAMinigameBase.hash = hash

local function mixc(c, f) return { r = c.r * f, g = c.g * f, b = c.b * f } end

-- Vertical light-to-dark gradient in `n` strips.
function TWAMinigameBase:gradient(x, y, w, h, top, bottom, n, a)
    n = n or 10
    local sh = h / n
    for i = 0, n - 1 do
        local k = i / math.max(1, n - 1)
        self:rectRGB(x, y + i * sh, w, sh + 0.5, a or 1,
            top.r + (bottom.r - top.r) * k, top.g + (bottom.g - top.g) * k, top.b + (bottom.b - top.b) * k)
    end
end

local STEEL = { r = 0.60, g = 0.62, b = 0.66 }

-- A steel (or any metal) plate. o.tint = base colour (default steel),
-- o.brush = "h"/"v" brushing direction, o.bolts = corner bolt heads,
-- o.seed varies the streaks between plates.
function TWAMinigameBase:metalPlate(x, y, w, h, o)
    o = o or {}
    local base = o.tint or STEEL
    local seed = o.seed or 1
    -- Dark rim, then the body shaded lighter at the top.
    self:rect(x - 2, y - 2, w + 4, h + 4, 1, mixc(base, 0.35))
    self:gradient(x, y, w, h, mixc(base, 1.18), mixc(base, 0.72), math.max(6, math.floor(h / 8)))
    -- Brushed streaks: many thin lines of slightly varying brightness.
    if o.brush == "v" then
        for i = 1, math.floor(w / 3) do
            local xx = x + i * 3
            local f = 0.8 + 0.45 * hash(i, seed)
            self:line(xx, y + 2, xx, y + h - 2, 1, 0.22, mixc(base, f))
        end
    else
        for i = 1, math.floor(h / 3) do
            local yy = y + i * 3
            local f = 0.8 + 0.45 * hash(i, seed)
            local x0 = x + 2 + 30 * hash(i, seed + 3)
            local x1 = x + w - 2 - 30 * hash(i, seed + 7)
            self:line(x0, yy, x1, yy, 1, 0.22, mixc(base, f))
        end
    end
    -- A soft diagonal sheen across the face.
    local sw = math.min(w, h) * 0.5
    for k = 0, 3 do
        local off = w * 0.25 + k * sw * 0.18
        local a = 0.07 - k * 0.012
        local x1, x2 = x + off, x + off + sw * 0.35
        self:quad(math.min(x + w, x1), y, math.min(x + w, x2), y,
            math.max(x, math.min(x + w, x2 - h * 0.6)), y + h, math.max(x, math.min(x + w, x1 - h * 0.6)), y + h,
            a, 1, 1, 1)
    end
    -- Bevel: light top/left, dark bottom/right.
    self:line(x, y + 0.5, x + w, y + 0.5, 1.5, 0.7, mixc(base, 1.45))
    self:line(x + 0.5, y, x + 0.5, y + h, 1.5, 0.5, mixc(base, 1.3))
    self:line(x, y + h - 0.5, x + w, y + h - 0.5, 1.5, 0.8, mixc(base, 0.45))
    self:line(x + w - 0.5, y, x + w - 0.5, y + h, 1.5, 0.7, mixc(base, 0.5))
    if o.bolts then
        local m = math.min(14, math.min(w, h) * 0.2)
        for _, p in ipairs({ { x + m, y + m }, { x + w - m, y + m }, { x + m, y + h - m }, { x + w - m, y + h - m } }) do
            self:disc(p[1] + 1, p[2] + 1.5, 6, 0.6, mixc(base, 0.3), 12)
            self:disc(p[1], p[2], 6, 1, mixc(base, 0.8), 12)
            self:disc(p[1] - 1.5, p[2] - 1.5, 2.5, 0.6, mixc(base, 1.4), 8)
            self:line(p[1] - 4, p[2] + 1, p[1] + 4, p[2] - 1, 1.5, 0.9, mixc(base, 0.35))
        end
    end
end

-- Metal at a forging heat: the steel plate, its colour pulled toward the
-- heat ramp, plus a glow around it while it is hot.
function TWAMinigameBase:hotMetal(x, y, w, h, heat, seed)
    local r, g, b = TWAMinigameBase.heatColor(heat)
    local k = math.min(1, math.max(0, (heat - 0.2) / 0.6))
    local tint = { r = STEEL.r + (r - STEEL.r) * k, g = STEEL.g + (g - STEEL.g) * k, b = STEEL.b + (b - STEEL.b) * k }
    if heat > 0.35 then
        for i = 1, 3 do
            local e = i * 4
            self:rectRGB(x - e, y - e, w + 2 * e, h + 2 * e, 0.08 * (heat - 0.3), r, g * 0.8, b * 0.5)
        end
    end
    self:metalPlate(x, y, w, h, { tint = tint, seed = seed or 5 })
    -- Scale flecks on cooler metal.
    if heat < 0.6 then
        for i = 1, 14 do
            local fx = x + 6 + (w - 12) * hash(i, 11)
            local fy = y + 4 + (h - 8) * hash(i, 13)
            self:rectRGB(fx, fy, 3, 2, 0.35 * (1 - heat), 0.15, 0.13, 0.12)
        end
    end
end

local WOOD = { r = 0.47, g = 0.31, b = 0.16 }

-- A piece of wood. o.vertical = grain runs up/down, o.tint = wood colour,
-- o.seed varies the grain and knots.
function TWAMinigameBase:woodBoard(x, y, w, h, o)
    o = o or {}
    local base = o.tint or WOOD
    local seed = o.seed or 1
    self:rect(x - 2, y - 2, w + 4, h + 4, 1, mixc(base, 0.45))
    if o.vertical then
        -- Shade across the width (a rounded-ish face).
        local n = math.max(6, math.floor(w / 6))
        local sw = w / n
        for i = 0, n - 1 do
            local k = i / (n - 1)
            local f = 1.12 - 0.35 * math.abs(k - 0.35)
            self:rectRGB(x + i * sw, y, sw + 0.5, h, 1, base.r * f, base.g * f, base.b * f)
        end
    else
        self:gradient(x, y, w, h, mixc(base, 1.12), mixc(base, 0.82), math.max(6, math.floor(h / 8)))
    end
    -- Grain: long gently wavy lines, darker and lighter.
    local lines = o.vertical and math.floor(w / 5) or math.floor(h / 5)
    for i = 1, lines do
        local f = (hash(i, seed) < 0.5) and 0.72 or 1.2
        local amp = 1.5 + 3 * hash(i, seed + 1)
        local ph = 6.28 * hash(i, seed + 2)
        local pts = {}
        local steps = 8
        for j = 0, steps do
            local u = j / steps
            if o.vertical then
                pts[#pts + 1] = { x + i * 5 + math.sin(u * 5 + ph) * amp * 0.6, y + u * h }
            else
                pts[#pts + 1] = { x + u * w, y + i * 5 + math.sin(u * 5 + ph) * amp * 0.6 }
            end
        end
        self:polyline(pts, 1, 0.35, mixc(base, f))
    end
    -- A knot or two.
    for k = 1, (o.knots or 2) do
        local kx = x + w * (0.15 + 0.7 * hash(k, seed + 5))
        local ky = y + h * (0.2 + 0.6 * hash(k, seed + 6))
        local r = math.min(w, h) * (0.06 + 0.05 * hash(k, seed + 7))
        if r >= 2 then
            self:disc(kx, ky, r, 0.85, mixc(base, 0.6), 12)
            self:ring(kx, ky, r * 1.6, 1, 0.45, mixc(base, 0.7), 14)
            self:disc(kx - r * 0.3, ky - r * 0.3, r * 0.4, 0.8, mixc(base, 0.4), 8)
        end
    end
    self:line(x, y + 0.5, x + w, y + 0.5, 1.5, 0.5, mixc(base, 1.4))
    self:line(x, y + h - 0.5, x + w, y + h - 0.5, 1.5, 0.7, mixc(base, 0.5))
end

-- Leather: warm brown, a faint pebbled texture and stitched-looking edges.
function TWAMinigameBase:leather(x, y, w, h, o)
    o = o or {}
    local base = o.tint or { r = 0.45, g = 0.27, b = 0.14 }
    self:rect(x - 1, y - 1, w + 2, h + 2, 1, mixc(base, 0.5))
    self:gradient(x, y, w, h, mixc(base, 1.15), mixc(base, 0.8), 8)
    for i = 1, math.floor(w * h / 220) do
        local px = x + 2 + (w - 4) * hash(i, 21)
        local py = y + 2 + (h - 4) * hash(i, 23)
        local f = hash(i, 25) < 0.5 and 0.75 or 1.25
        self:rectRGB(px, py, 2, 2, 0.35, base.r * f, base.g * f, base.b * f)
    end
    -- Stitched border.
    for sx = x + 6, x + w - 10, 10 do
        self:line(sx, y + 4, sx + 5, y + 4, 1.2, 0.7, mixc(base, 1.7))
        self:line(sx, y + h - 4, sx + 5, y + h - 4, 1.2, 0.7, mixc(base, 1.7))
    end
end

-- Gems and stones -----------------------------------------------------------
--
-- Round 16 (request 2026-09-28: "มินิเกมให้ texure สวยกว่านี้ โดยเฉพาะมณี"):
-- a cut gem is drawn as a real brilliant seen from above -- table, star,
-- kite and girdle facets, each lit by its own angle to the light (with the
-- alternating light/dark pattern that makes a brilliant sparkle), an inner
-- reflection of the table, a glow and twinkling glints. A rough stone is a
-- chipped grey crust with the crystal's colour showing where it broke open.
-- All deterministic from a seed, animated only by `self.elapsed`.

local LIGHT_ANG = -2.3 -- light from the top-left
local atan2 = math.atan2 or math.atan -- Kahlua has atan2; newer Lua math.atan(y, x)
TWAMinigameBase.atan2 = atan2

-- A facet colour: k < 1 darkens, k > 1 blends toward white.
local function facetRGB(c, k)
    if k <= 1 then return c.r * k, c.g * k, c.b * k end
    local w = math.min(1, k - 1)
    return c.r + (1 - c.r) * w, c.g + (1 - c.g) * w, c.b + (1 - c.b) * w
end
TWAMinigameBase.facetRGB = facetRGB

-- A four-point star glint.
function TWAMinigameBase:sparkle(x, y, size, a)
    if a <= 0.02 then return end
    local s, t = size, size * 0.18
    self:quad(x - s, y, x, y - t, x + s, y, x, y + t, a, 1, 1, 1)
    self:quad(x, y - s, x + t, y, x, y + s, x - t, y, a, 1, 1, 1)
    self:disc(x, y, t * 1.4, a, { r = 1, g = 1, b = 1 }, 8)
end

-- A soft coloured glow: stacked discs, faint at the edge.
function TWAMinigameBase:glow(cx, cy, r, col, a)
    for i = 4, 1, -1 do
        self:disc(cx, cy, r * (0.6 + i * 0.18), (a or 0.5) * 0.12, col, 28)
    end
end

-- A round brilliant, top view. o.m = sides of the table (8), o.rot,
-- o.done / o.current / o.cut = facet progress for the faceting game (kites
-- past `done` are still frosted), o.alpha, o.glow, o.seed.
function TWAMinigameBase:gemBrilliant(cx, cy, r, col, o)
    o = o or {}
    local m = o.m or 8
    local rot = (o.rot or 0) - 1.5708
    local a = o.alpha or 1
    local t = self.elapsed or 0
    local seed = o.seed or 1
    local done = o.done or m
    if o.glow ~= false then self:glow(cx, cy, r * 1.15, col, 0.55 * a) end
    local step = 6.2832 / m
    local function P(rad, ang) return cx + math.cos(ang) * rad, cy + math.sin(ang) * rad end
    -- girdle rim (a thin darker band)
    self:disc(cx, cy, r + 2.5, a, { r = col.r * 0.3, g = col.g * 0.3, b = col.b * 0.35 }, m * 4)
    local frost = { r = 0.62 + col.r * 0.25, g = 0.64 + col.g * 0.25, b = 0.68 + col.b * 0.25 }
    for j = 0, m - 1 do
        local th = rot + j * step
        local th2 = th + step
        local mid = th + step / 2
        local tx1, ty1 = P(r * 0.5, th)
        local tx2, ty2 = P(r * 0.5, th2)
        local sx, sy = P(r * 0.78, mid)
        local sxp, syp = P(r * 0.78, mid - step)
        local gx, gy = P(r, th)
        local gmx, gmy = P(r, mid)
        local gx2, gy2 = P(r, th2)
        local idx = j + 1
        local cut = idx <= done
        local shimmer = 0.1 * math.sin(t * 0.0021 + j * 1.7 + seed)
        local function lit(ang, alt)
            local d = math.cos(ang - LIGHT_ANG)
            return 0.62 + 0.42 * d + (alt and 0.18 or -0.12) + shimmer
        end
        local base = cut and col or frost
        local pulse = 0
        if o.current == idx then pulse = 0.25 + 0.25 * math.abs(math.sin(t * 0.008)) + 0.3 * (o.cut or 0) end
        -- kite (bezel) facet
        local r1, g1, b1 = facetRGB(base, lit(th, j % 2 == 0) + pulse)
        self:quad(tx1, ty1, sxp, syp, gx, gy, sx, sy, a, r1, g1, b1)
        -- star facet
        local r2, g2, b2 = facetRGB(base, lit(mid, j % 2 == 1) * 1.08 + pulse)
        self:quad(tx1, ty1, tx2, ty2, sx, sy, sx, sy, a, r2, g2, b2)
        -- upper girdle facets (two per sector)
        local r3, g3, b3 = facetRGB(base, lit(mid - 0.3, j % 2 == 1) * 0.9 + pulse)
        self:quad(sx, sy, gx, gy, gmx, gmy, gmx, gmy, a, r3, g3, b3)
        local r4, g4, b4 = facetRGB(base, lit(mid + 0.3, j % 2 == 0) * 0.95 + pulse)
        self:quad(sx, sy, gmx, gmy, gx2, gy2, gx2, gy2, a, r4, g4, b4)
        -- facet edges
        local edge = { r = math.min(1, base.r * 1.6 + 0.2), g = math.min(1, base.g * 1.6 + 0.2), b = math.min(1, base.b * 1.6 + 0.2) }
        self:line(tx1, ty1, gx, gy, 1, 0.35 * a, edge)
        self:line(sx, sy, gmx, gmy, 1, 0.25 * a, edge)
        self:line(tx1, ty1, tx2, ty2, 1, 0.5 * a, edge)
    end
    -- table with the pavilion's reflection inside it
    local tbl = {}
    for j = 0, m - 1 do tbl[#tbl + 1] = { P(r * 0.5, rot + j * step) } end
    for j = 1, m do
        local p1, p2 = tbl[j], tbl[j % m + 1]
        local rr, gg, bb = facetRGB(col, 1.02 + 0.12 * math.sin(t * 0.0017 + j))
        self:quad(cx, cy, p1[1], p1[2], p2[1], p2[2], cx, cy, a, rr, gg, bb)
    end
    for j = 0, m - 1 do
        local ang = rot + (j + 0.5) * step
        local x1, y1 = P(r * 0.36, ang)
        local x2, y2 = P(r * 0.36, ang + step)
        local rr, gg, bb = facetRGB(col, (j % 2 == 0) and 0.7 or 1.25)
        self:quad(cx, cy, x1, y1, x2, y2, cx, cy, 0.55 * a, rr, gg, bb)
    end
    -- a broad highlight on the table, then twinkling glints
    local hx, hy = P(r * 0.22, LIGHT_ANG)
    self:disc(hx, hy, r * 0.13, 0.35 * a, { r = 1, g = 1, b = 1 }, 12)
    for i = 1, 4 do
        local ang = 6.2832 * TWAMinigameBase.hash(i, seed)
        local rad = r * (0.25 + 0.6 * TWAMinigameBase.hash(i, seed + 3))
        local tw = math.sin(t * 0.004 + i * 2.1 + seed)
        local gx, gy = P(rad, ang)
        self:sparkle(gx, gy, r * 0.16, a * math.max(0, tw) ^ 3)
    end
end

-- A rough stone: `pts` its outline. o.clear = a see-through crystal (the
-- inspection games look INTO it); otherwise a chipped grey crust with the
-- gem colour peeking out of broken patches.
function TWAMinigameBase:roughGem(pts, col, o)
    o = o or {}
    local seed = o.seed or 1
    local a = o.alpha or 1
    local t = self.elapsed or 0
    local cx, cy = 0, 0
    for _, p in ipairs(pts) do cx, cy = cx + p[1], cy + p[2] end
    cx, cy = cx / #pts, cy / #pts
    local rad = 0
    for _, p in ipairs(pts) do rad = math.max(rad, TWAMinigameBase.dist(cx, cy, p[1], p[2])) end
    local px, py = cx - rad * 0.12, cy - rad * 0.14 -- the ridge the faces meet at
    local crust = o.clear and col or { r = 0.42 + col.r * 0.12, g = 0.4 + col.g * 0.12, b = 0.38 + col.b * 0.12 }
    if o.clear then self:glow(cx, cy, rad, col, 0.4 * a) end
    for i = 1, #pts do -- shadow, the stone's own outline
        local p1, p2 = pts[i], pts[i % #pts + 1]
        self:quad(cx + 5, cy + 8, p1[1] + 5, p1[2] + 8, p2[1] + 5, p2[2] + 8, cx + 5, cy + 8, 0.35 * a, 0, 0, 0)
    end
    for i = 1, #pts do
        local p1, p2 = pts[i], pts[i % #pts + 1]
        local mx, my = (p1[1] + p2[1]) / 2 - cx, (p1[2] + p2[2]) / 2 - cy
        local d = math.cos(atan2(my, mx) - LIGHT_ANG)
        local k = 0.62 + 0.45 * d + 0.12 * (TWAMinigameBase.hash(i, seed) - 0.5)
        local rr, gg, bb = facetRGB(crust, k)
        self:quad(px, py, p1[1], p1[2], p2[1], p2[2], px, py, (o.clear and 0.88 or 1) * a, rr, gg, bb)
        self:line(px, py, p1[1], p1[2], 1.5, 0.35 * a, { r = math.min(1, crust.r * 1.6), g = math.min(1, crust.g * 1.6), b = math.min(1, crust.b * 1.6) })
    end
    if o.clear then
        -- light travelling through: a pale inner core and streaks
        for i = 1, 5 do
            local ang = 6.2832 * TWAMinigameBase.hash(i, seed + 9)
            local l = rad * (0.3 + 0.4 * TWAMinigameBase.hash(i, seed + 4))
            self:line(cx, cy, cx + math.cos(ang) * l, cy + math.sin(ang) * l, 3, 0.12 * a, { r = 1, g = 1, b = 1 })
        end
        local rr, gg, bb = facetRGB(col, 1.35)
        self:disc(cx - rad * 0.15, cy - rad * 0.18, rad * 0.3, 0.3 * a, { r = rr, g = gg, b = bb }, 18)
    else
        -- grain on the crust
        for i = 1, math.floor(rad * 0.7) do
            local ang = 6.2832 * TWAMinigameBase.hash(i, seed + 11)
            local l = rad * 0.85 * math.sqrt(TWAMinigameBase.hash(i, seed + 12))
            local f = TWAMinigameBase.hash(i, seed + 13) < 0.5 and 0.6 or 1.35
            local rr, gg, bb = facetRGB(crust, f)
            self:rectRGB(cx + math.cos(ang) * l, cy + math.sin(ang) * l * 0.85, 2, 2, 0.45 * a, rr, gg, bb)
        end
        -- broken windows showing the crystal
        for w = 1, (o.windows or 3) do
            local ang = 6.2832 * TWAMinigameBase.hash(w, seed + 20)
            local l = rad * (0.15 + 0.4 * TWAMinigameBase.hash(w, seed + 21))
            local wx, wy = cx + math.cos(ang) * l, cy + math.sin(ang) * l * 0.85
            local wr = rad * (0.3 - 0.06 * w)
            local rim = {}
            for k = 0, 6 do
                local aa = k / 7 * 6.2832 + TWAMinigameBase.hash(k, seed + w) * 0.5
                local rr2 = wr * (0.6 + 0.4 * TWAMinigameBase.hash(k, seed + w + 30))
                rim[#rim + 1] = { wx + math.cos(aa) * rr2, wy + math.sin(aa) * rr2 * 0.85 }
            end
            for k = 1, #rim do
                local q1, q2 = rim[k], rim[k % #rim + 1]
                self:quad(wx + 2, wy + 3, q1[1] + 2, q1[2] + 3, q2[1] + 2, q2[2] + 3, wx + 2, wy + 3, 0.6 * a, 0.08, 0.07, 0.07)
            end
            for k = 1, #rim do
                local q1, q2 = rim[k], rim[k % #rim + 1]
                local mx, my = (q1[1] + q2[1]) / 2 - wx, (q1[2] + q2[2]) / 2 - wy
                local d = math.cos(atan2(my, mx) - LIGHT_ANG)
                local rr, gg, bb = facetRGB(col, 0.75 + 0.55 * d + ((k % 2 == 0) and 0.2 or -0.1))
                self:quad(wx, wy, q1[1], q1[2], q2[1], q2[2], wx, wy, a, rr, gg, bb)
            end
            self:polyline(rim, 1.5, 0.8 * a, { r = 0.2, g = 0.19, b = 0.18 }, true)
            local tw = math.sin(t * 0.003 + w * 2.3 + seed)
            self:sparkle(wx - wr * 0.25, wy - wr * 0.3, wr * 0.35, a * (0.35 + 0.65 * math.max(0, tw)))
        end
    end
    self:polyline(pts, 2, a, { r = crust.r * 0.35, g = crust.g * 0.35, b = crust.b * 0.35 }, true)
end

-- Jeweller's velvet: deep cloth with a soft fold sheen.
function TWAMinigameBase:velvet(x, y, w, h, o)
    o = o or {}
    local base = o.tint or { r = 0.1, g = 0.12, b = 0.26 }
    self:rect(x - 3, y - 3, w + 6, h + 6, 1, mixc(base, 0.4))
    self:gradient(x, y, w, h, mixc(base, 1.25), mixc(base, 0.7), 12)
    for i = 1, 5 do
        local fx = x + w * (i / 6) + 20 * hash(i, 41)
        self:quad(fx - 30, y, fx + 10, y, fx - 10 - 40 * hash(i, 42), y + h, fx - 50 - 40 * hash(i, 42), y + h, 0.06, 1, 1, 1)
    end
    for i = 1, math.min(500, math.floor(w * h / 160)) do
        local px, py = x + w * hash(i, 43), y + h * hash(i, 44)
        self:rectRGB(px, py, 1.5, 1.5, 0.25, base.r * 1.6, base.g * 1.6, base.b * 1.6)
    end
end

-- A sharpening stone lying along the line (x1,y1)->(x2,y2), `wid` across.
-- o.fine = a pale fine-grit stone (polishing), else a grey-blue coarse one;
-- o.wear 0..1 darkens the slurry where the blade has worked it.
function TWAMinigameBase:whetstone(x1, y1, x2, y2, wid, o)
    o = o or {}
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    local ux, uy = dx / len, dy / len
    local nx, ny = -uy, ux
    local function P(s, t) return x1 + ux * s + nx * t, y1 + uy * s + ny * t end
    local function Q(s1, t1, s2, t2, a, r, g, b)
        local ax, ay = P(s1, t1); local bx, by = P(s2, t1); local cx2, cy2 = P(s2, t2); local ex, ey = P(s1, t2)
        self:quad(ax, ay, bx, by, cx2, cy2, ex, ey, a, r, g, b)
    end
    local h = wid / 2
    -- wooden holder under it, then the stone's front side
    local W0 = { r = 0.4, g = 0.26, b = 0.13 }
    Q(-70, -h - 26, len + 70, h + 30, 1, W0.r * 0.55, W0.g * 0.55, W0.b * 0.55)
    Q(-66, -h - 22, len + 66, h + 26, 1, W0.r, W0.g, W0.b)
    for i = 1, 9 do
        local tt = -h - 22 + i * (wid + 48) / 10
        Q(-66, tt, len + 66, tt + 1.2, 0.3, W0.r * 0.6, W0.g * 0.6, W0.b * 0.6)
    end
    local base = o.fine and { r = 0.86, g = 0.83, b = 0.76 } or { r = 0.36, g = 0.42, b = 0.5 }
    Q(-50, h, len + 50, h + 14, 1, base.r * 0.55, base.g * 0.55, base.b * 0.55)
    -- the face, shaded across its width
    local n = 12
    for i = 0, n - 1 do
        local k = i / (n - 1)
        local f = 1.12 - 0.3 * k
        Q(-50, -h + i * wid / n, len + 50, -h + (i + 1) * wid / n + 0.5, 1, base.r * f, base.g * f, base.b * f)
    end
    -- grit speckles
    for i = 1, math.floor(len * wid / 90) do
        local s = -50 + (len + 100) * hash(i, 51)
        local tt = -h + wid * hash(i, 52)
        local f = hash(i, 53) < 0.5 and 0.7 or 1.3
        local ax, ay = P(s, tt)
        self:rectRGB(ax, ay, 1.6, 1.6, 0.5, base.r * f, base.g * f, base.b * f)
    end
    -- worn slurry band where the edge runs, darkening with the work
    local wear = o.wear or 0
    Q(-20, -h * 0.35, len + 20, h * 0.35, 0.12 + 0.3 * wear, base.r * 0.4, base.g * 0.4, base.b * 0.45)
    -- wet sheen
    for k = 0, 2 do
        local s0 = len * (0.15 + 0.3 * k)
        Q(s0, -h + 4, s0 + len * 0.12, -h + wid * 0.4, 0.06, 1, 1, 1)
    end
    -- edges
    local ax, ay = P(-50, -h); local bx, by = P(len + 50, -h)
    self:line(ax, ay, bx, by, 2, 0.8, mixc(base, 1.45))
    ax, ay = P(-50, h); bx, by = P(len + 50, h)
    self:line(ax, ay, bx, by, 2, 0.8, mixc(base, 0.4))
end

-- A texture drawn rotated by `ang` (radians) about its centre (cx, cy).
function TWAMinigameBase:texRot(t, cx, cy, size, ang, a, r, g, b)
    local jo = self.javaObject
    if not t or not jo then return end
    local ax, ay = self:getAbsoluteX() + self:ox() + cx, self:getAbsoluteY() + self:oy() + cy
    local h = size / 2
    local c, s = math.cos(ang), math.sin(ang)
    local function R(x, y) return ax + x * c - y * s, ay + x * s + y * c end
    local x1, y1 = R(-h, -h); local x2, y2 = R(h, -h); local x3, y3 = R(h, h); local x4, y4 = R(-h, h)
    jo:DrawTexture(t, x1, y1, x2, y2, x3, y3, x4, y4, r or 1, g or 1, b or 1, a or 1)
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
    -- The exact contact point -- what every zone is measured from, not the
    -- picture (round 7: the weld looked "in" by the torch picture while the
    -- point was out). A dark outline keeps it visible on any surface.
    self:ring(self.hx, self.hy, 5, 1.5, 0.9, TWAMinigameBase.COL.dark, 12)
    self:disc(self.hx, self.hy, 3, 1, TWAMinigameBase.COL.guide, 10)
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

--============================================================================
-- HARMONIE_TheWayToAttack -- gem refining: the result, and the shatter show
-- (client)
--
-- Round 19 (request 2026-09-29: "คุณภาพรวมต่ำเมื่อกดเสร็จสิ้นมีโอกาส แตก50%
-- คุณภาพรวม ดี 5% เยี่ยม 0% และถ้าแตกให้ขึ้นหน้าต่างมินิเกมมณีแตกเป็นเสี่ยงๆ
-- เหมือนตอนสุ่มมณีที่ได้จากการทำสูตรหินมณี แต่ไม่ต้องนาน"). Finish of a gem-
-- refining recipe is decided where complete() runs (the server in
-- multiplayer), which reports back (TWACraftState.reportRefine ->
-- "gemRefine"). TWAGemBreak.watch waits for that report: a broken gem opens a
-- short window where the gem trembles, cracks and bursts into shards; a
-- refined one just chimes with a note over the player's head.
--============================================================================

require "HARMONIE_TWA_MinigameBase"
require "HARMONIE_TWA_Sound"

TWAGemBreak = TWAMinigameBase:derive("TWAGemBreak")

local B = TWAMinigameBase
local C = B.COL
local PX, PY, PW, PH = 20, 84, 620, 350
local CRACK_MS, BURST_AT = 900, 1100
local WAIT_MS = 15000

-- The server's report, kept for the client that pressed Finish.
if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= "HARMONIE_TWA" or command ~= "gemRefine" or not args or not args.token then return end
        TWACraftState.REFINE_RESULTS[args.token] = args
    end)
end

local function gemColour(fullType)
    local short = fullType and fullType:match("%.([^%.]+)$")
    local c = short and TWARecipeData.GemRoll.colour[short]
    return c and { r = c[1], g = c[2], b = c[3] } or { r = 0.8, g = 0.8, b = 0.85 }
end

local function gemName(fullType)
    local sm = ScriptManager and ScriptManager.instance
    local sc = fullType and sm and sm:getItem(fullType)
    return sc and sc:getDisplayName() or (fullType or "?")
end

-- Wait (a few seconds at most) for the report on `token`.
function TWAGemBreak.watch(player, token)
    if not token then return end
    local started = getTimestampMs()
    local tick
    tick = function()
        local res = TWACraftState.REFINE_RESULTS[token]
        if res or getTimestampMs() - started > WAIT_MS then
            Events.OnTick.Remove(tick)
            if res then
                TWACraftState.REFINE_RESULTS[token] = nil
                TWAGemBreak.show(player, res)
            end
        end
    end
    Events.OnTick.Add(tick)
end

function TWAGemBreak.show(player, res)
    if res.broken then
        if TWAMinigame and TWAMinigame.instance then return end
        local ui = TWAGemBreak:openFor(player, nil, nil, nil, nil)
        ui.gemType = res.type
        ui.gemCol = gemColour(res.type)
        return ui
    end
    -- refined: a chime and a note over the head
    TWASound.play("TWA_Shimmer", "MinigameSounds")
    local text = getText("IGUI_TWA_GemRefine_Done", gemName(res.type), getText("IGUI_TWA_GemState_" .. tostring(res.state)))
    if player and player.setHaloNote then player:setHaloNote(text, 120, 220, 255, 300) end
end

function TWAGemBreak:onStart()
    self.title = getText("IGUI_TWA_GemBreak_Title")
    self.hint = getText("IGUI_TWA_GemBreak_Hint")
    self.hint2 = ""
    self.timeLimit = 1e12
    self.toolTex = nil
    self.gemCol = self.gemCol or { r = 0.8, g = 0.8, b = 0.85 }
    self.cracks = {}
    for i = 1, 7 do
        self.cracks[i] = { a = 6.2832 * B.hash(i, 31), bend = (B.hash(i, 32) - 0.5) * 0.8, at = 120 * i }
    end
    TWASound.play("TWA_Tension", "MinigameSounds")
end

function TWAGemBreak:updateGame(dt)
    local t = self.elapsed
    self.flashA = math.max(0, (self.flashA or 0) - dt / 500)
    if not self.burstAt and t < BURST_AT then
        if ZombRand(3) == 0 then self:shake(1 + 4 * t / BURST_AT, 100) end
    end
    if not self.burstAt and t >= BURST_AT then
        self.burstAt = t
        self.flashA = 1
        self:shake(14, 500)
        local col = self.gemCol
        self:burst("chip", 310, 170, 60, { speed = 0.7, ttl = 1400, col = col, size = 6 })
        self:burst("spark", 310, 170, 40, { speed = 0.5, ttl = 900, col = col })
        self:burst("ring", 310, 170, 1, { size = 20, grow = 0.5, ttl = 700, col = col })
        TWASound.play("TWA_Crack", "MinigameSounds")
        TWASound.play("TWA_Smash", "MinigameSounds")
    end
    if self.burstAt and t - self.burstAt > 5000 then self:finish() end
end

function TWAGemBreak:renderGame()
    local t = self.elapsed
    local cx, cy = 310, 170
    self:velvet(0, 0, PW, PH, { tint = { r = 0.06, g = 0.05, b = 0.09 } })
    local col = self.gemCol
    if not self.burstAt then
        self:gemBrilliant(cx, cy, 70, col, { seed = 5 })
        -- cracks racing across it
        for _, cr in ipairs(self.cracks) do
            if t > cr.at then
                local grow = math.min(1, (t - cr.at) / 500)
                local len = 70 * grow
                local mx, my = cx + math.cos(cr.a + cr.bend) * len * 0.5, cy + math.sin(cr.a + cr.bend) * len * 0.5
                local x2, y2 = cx + math.cos(cr.a) * len, cy + math.sin(cr.a) * len
                self:polyline({ { cx, cy }, { mx, my }, { x2, y2 } }, 2.5, 0.95, { r = 1, g = 1, b = 1 })
            end
        end
    else
        -- what is left: a few shards on the cloth
        for i = 1, 9 do
            local a = 6.2832 * B.hash(i, 41)
            local d = 40 + 110 * B.hash(i, 42)
            local x, y = cx + math.cos(a) * d, cy + 60 + math.sin(a) * d * 0.35
            local s = 5 + 7 * B.hash(i, 43)
            self:quad(x - s, y, x, y - s * 0.7, x + s * 0.8, y + s * 0.2, x - s * 0.2, y + s * 0.6, 0.9, col.r, col.g, col.b)
            self:sparkle(x - s * 0.3, y - s * 0.3, s * 0.5, 0.4 * math.max(0, math.sin(t * 0.005 + i)))
        end
    end
end

function TWAGemBreak:renderOverlay()
    if self.flashA and self.flashA > 0 then
        local c = self.gemCol
        self:rectRGB(0, 0, PW, PH, self.flashA * 0.8, 0.6 + 0.4 * c.r, 0.6 + 0.4 * c.g, 0.6 + 0.4 * c.b)
    end
    if not self.burstAt then return end
    self:textC(getText("IGUI_TWA_GemBreak_Lost", gemName(self.gemType)), 310, 40, { r = 1, g = 0.55, b = 0.45 }, 1, UIFont.Medium)
    if self.elapsed - self.burstAt > 700 then
        self:textC(getText("IGUI_TWA_Reveal_Close"), 310, 320, C.faint, 0.6 + 0.4 * math.sin(self.elapsed * 0.006), UIFont.Small)
    end
end

-- Its own frame: nothing to play.
function TWAGemBreak:draw()
    self:drawRect(-self.x, -self.y, getCore():getScreenWidth(), getCore():getScreenHeight(), 0.6, 0, 0, 0)
    self:drawRect(0, 0, self.width, self.height, 0.97, 0.03, 0.025, 0.05)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.7, 0.35, 0.3)
    self:drawTextCentre(self.title, self.width / 2, 10, 1, 0.7, 0.55, 1, UIFont.Medium)
    self:drawTextCentre(self.hint or "", self.width / 2, 40, 0.75, 0.75, 0.75, 1, UIFont.Small)
    self:drawRect(PX, PY, PW, PH, 1, 0.01, 0.01, 0.015)
    self:setStencilRect(PX, PY, PW, PH)
    self:renderGame()
    self:drawParticles()
    self:renderOverlay()
    self:clearStencilRect()
    self:drawRectBorder(PX, PY, PW, PH, 1, 0.35, 0.35, 0.37)
end

function TWAGemBreak:finish()
    if self.closed then return end
    self.onResult = nil
    self:teardown()
end

function TWAGemBreak:canClose() return self.burstAt ~= nil and (self.elapsed - self.burstAt) > 700 end
function TWAGemBreak:onMouseDown() if self:canClose() then self:finish() end return true end
function TWAGemBreak:onMouseUp() return true end
function TWAGemBreak:onMouseUpOutside() return true end
function TWAGemBreak:onMouseDownOutside() return self:onMouseDown() end
function TWAGemBreak:onRightMouseUp() return self:onMouseDown() end
function TWAGemBreak:onRightMouseUpOutside() return self:onMouseDown() end
function TWAGemBreak:onKeyRelease(key) if key == Keyboard.KEY_ESCAPE and self:canClose() then self:finish() end end
function TWAGemBreak:onTimeout() end

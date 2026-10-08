--============================================================================
-- HARMONIE_TheWayToAttack -- grade reveal after Finish (client)
--
-- Round 12 (request 2026-09-28: "เวลาทำอาวุธเสร็จสิ้น ให้มีหน้าต่างมินิเกมขึ้นมา
-- แต่ไม่ต้องทำอะไร ให้เป็นรูปการค้อนทุบบนทั่งจนเกรดที่สุ่มได้ขึ้นมา ให้มีความ
-- อลังการ มีแสง มีสี มีความลุ้น ทำให้มันกลมกลืนไปกับโฟลว"). Same window and
-- drawing kit as the procedure minigames, nothing to play: the finished
-- piece glows on the anvil, the hammer falls faster and faster while the
-- grade letters spin above it, then one last big blow -- a flash, rays and a
-- shower of sparks in the grade's colour -- and the grade stands there.
--
-- The grade is rolled where Finish's complete() runs (the server in
-- multiplayer). The window finds the new item by the token Finish stamped on
-- it (TWA_CraftToken) and holds the last blow until it has arrived. Material
-- recipes have no grade: they get the same show ending on the item itself.
--============================================================================

require "HARMONIE_TWA_MinigameBase"
require "HARMONIE_TWA_Sound"

TWAGradeReveal = TWAMinigameBase:derive("TWAGradeReveal")

local B = TWAMinigameBase
local C = B.COL
local PX, PY, PW, PH = 20, 84, 620, 350

local GRADES = { "S", "A", "B", "C", "D", "E", "F" }
local GRADE_COLOR = {
    S = { r = 1.0, g = 0.82, b = 0.15 }, A = { r = 0.75, g = 0.45, b = 1.0 }, B = { r = 0.35, g = 0.7, b = 1.0 },
    C = { r = 0.4, g = 0.9, b = 0.45 }, D = { r = 0.9, g = 0.9, b = 0.9 }, E = { r = 0.7, g = 0.6, b = 0.5 },
    F = { r = 0.75, g = 0.3, b = 0.25 },
}
local NO_GRADE = { r = 1.0, g = 0.75, b = 0.3 }
local BIG = UIFont.Massive or UIFont.Large

-- Blow times (ms): slow, then faster and faster.
local BLOWS = { 700, 1200, 1650, 2050, 2400, 2700, 2950, 3170, 3360 }
local WINDUP_AT, FINAL_AT, GIVE_UP_AT = 3500, 4300, 9000

function TWAGradeReveal.open(player, recipe, token)
    if TWAMinigame and TWAMinigame.instance then TWALog("Reveal", "grade reveal skipped: a minigame window is open"); return end
    TWALog("Reveal", "grade reveal for %s", tostring(recipe and recipe.id))
    local ui = TWAGradeReveal:openFor(player, nil, recipe, nil, nil)
    ui.token = token
    return ui
end

function TWAGradeReveal:onStart()
    self.title = getText("IGUI_TWA_Reveal_Title")
    self.hint = getText("IGUI_TWA_Reveal_Hint")
    self.hint2 = ""
    self.timeLimit = 1e12
    self.blow = 0
    self.heat = 1
    self.found = nil
    self.revealAt = nil
    self.nextLook = 0
    self.letter = GRADES[ZombRand(#GRADES) + 1]
    self.nextLetter = 0
    self.toolTex = B.itemTex("SmithingHammer") or B.itemTex("BallPeenHammer_Forged")
    self.resultTex = self.workTex
    self.material = self.recipe and TWACraftState.isMaterialRecipe(self.recipe)
    local script = self.recipe and ScriptManager.instance:getItem(self.recipe.result)
    self.itemName = script and script:getDisplayName() or ""
    if not self.resultTex and script then self.resultTex = B.itemTex(script:getIcon()) end
end

-- The finished item, once it is in the inventory.
function TWAGradeReveal:lookForItem()
    if self.found or not self.recipe or self.elapsed < self.nextLook then return end
    self.nextLook = self.elapsed + 200
    local token = self.token
    local it = self.player:getInventory():getFirstTypeEvalRecurse(self.recipe.result, function(x)
        return x:getModData().TWA_CraftToken == token
    end)
    if it then
        self.found = it
        local md = it:getModData()
        self.grade = md.TWA_Grade
        self.qualityWord = md.TWA_Quality
        TWALog("Reveal", "finished item found: %s grade %s quality %s", TWALogType(it), tostring(self.grade), tostring(self.qualityWord))
    end
end

function TWAGradeReveal:gradeColor()
    if self.revealAt and self.grade then return GRADE_COLOR[self.grade] or NO_GRADE end
    if self.revealAt then return NO_GRADE end
    return GRADE_COLOR[self.letter] or NO_GRADE
end

function TWAGradeReveal:strike(big)
    local cx, cy = 310, 196
    self:shake(big and 14 or 5, big and 600 or 180)
    self:burst("spark", cx + ZombRandFloat(-40, 40), cy, big and 90 or 26, { speed = big and 0.7 or 0.4, ttl = big and 1100 or 600 })
    self:burst("ring", cx, cy, 1, { size = big and 20 or 10, grow = big and 0.5 or 0.18, ttl = big and 900 or 350, col = big and self:gradeColor() or C.spark })
    self.heat = math.min(1.2, self.heat + (big and 0.5 or 0.12))
    self.flashA = big and 1 or 0.25
    TWASound.play(big and "TWA_BigHit" or "TWA_Hammer", "MinigameSounds")
end

function TWAGradeReveal:updateGame(dt)
    self:lookForItem()
    local t = self.elapsed
    self.flashA = math.max(0, (self.flashA or 0) - dt / 450)
    self.heat = math.max(0.55, self.heat - dt / 5000)
    if self.revealAt then
        if ZombRand(3) == 0 then self:burst("ember", ZombRandFloat(PX, PX + PW) - PX, PH, 1, { col = self:gradeColor(), ttl = 1600 }) end
        if t - self.revealAt > 7000 then self:finish() end
        return
    end
    -- Blows.
    while self.blow < #BLOWS and t >= BLOWS[self.blow + 1] do
        self.blow = self.blow + 1
        self:strike(false)
    end
    if t >= WINDUP_AT and not self.windup then
        self.windup = true
        TWASound.play("TWA_Tension", "MinigameSounds")
    end
    -- The letters spin, faster as it builds.
    if not self.material and t >= self.nextLetter then
        local k = math.min(1, t / FINAL_AT)
        self.nextLetter = t + 260 - 200 * k
        local prev = self.letter
        repeat self.letter = GRADES[ZombRand(#GRADES) + 1] until self.letter ~= prev
    end
    -- The last blow waits for the item (multiplayer brings it a moment later).
    if t >= FINAL_AT and (self.found or t >= GIVE_UP_AT) then
        self.revealAt = t
        self:strike(true)
        if self.found and (self.grade == "S" or self.grade == "A") then
            TWASound.play("TWA_Fanfare", "MinigameSounds")
        else
            TWASound.play("TWA_Success", "MinigameSounds")
        end
        -- Round 18: a crowd -- applause for S, booing for F.
        if self.found and self.grade == "S" then TWASound.play("TWA_Applause", "MinigameSounds")
        elseif self.found and self.grade == "F" then TWASound.play("TWA_Boo", "MinigameSounds") end
    end
end

function TWAGradeReveal:hammerLift()
    local t = self.elapsed
    if self.revealAt then return 0 end
    if t >= WINDUP_AT then
        -- raised high for the last blow, trembling
        local k = math.min(1, (t - WINDUP_AT) / (FINAL_AT - WINDUP_AT))
        return 60 + 70 * k + ZombRandFloat(-2, 2) * k
    end
    local last = BLOWS[self.blow] or 0
    local nxt = BLOWS[self.blow + 1] or WINDUP_AT
    local u = math.min(1, math.max(0, (t - last) / math.max(1, nxt - last)))
    -- up quickly after a blow, hang, then drop
    return 60 * math.sin(math.min(1, u * 1.15) * math.pi) ^ 0.6
end

function TWAGradeReveal:renderGame()
    local cx, cy = 310, 196
    local gc = self:gradeColor()
    local t = self.elapsed
    -- Forge glow behind everything, pulsing, in the colour that is coming.
    local pulse = 0.5 + 0.5 * math.sin(t * 0.006)
    local glow = (self.revealAt and 0.5 or (0.12 + 0.18 * self.heat)) * (0.7 + 0.3 * pulse)
    for i = 6, 1, -1 do
        self:disc(cx, cy - 20, 40 + i * 32, glow * 0.18, gc, 40)
    end
    -- Light rays after the reveal.
    if self.revealAt then
        local rot = (t - self.revealAt) * 0.0006
        for i = 0, 11 do
            local a = rot + i * math.pi / 6
            local a2 = a + 0.12
            self:quad(cx, cy - 30, cx + math.cos(a) * 420, cy - 30 + math.sin(a) * 420,
                cx + math.cos(a2) * 420, cy - 30 + math.sin(a2) * 420, cx, cy - 30, 0.13, gc.r, gc.g, gc.b)
        end
    end
    -- The anvil: horn, face, waist, foot.
    local dark = { r = 0.26, g = 0.27, b = 0.3 }
    self:quad(170, 214, 230, 214, 230, 240, 200, 232, 1, dark.r, dark.g, dark.b)
    self:metalPlate(230, 214, 200, 26, { tint = { r = 0.34, g = 0.35, b = 0.39 }, seed = 21 })
    self:metalPlate(275, 240, 110, 40, { tint = dark, seed = 22 })
    self:metalPlate(245, 280, 170, 22, { tint = dark, seed = 23 })
    -- The piece on the anvil, glowing.
    self:hotMetal(250, 192, 160, 22, self.heat, 24)
    if self.resultTex and self.revealAt then
        local s = 64
        self:disc(cx, 120, 48, 0.35, gc, 30)
        self:tex(self.resultTex, cx - s / 2, 120 - s / 2, s, s, 1)
    end
    -- The hammer.
    if not self.revealAt then self:drawHammer(cx, self:hammerLift()) end
end

-- Round 13 ("มันเอาด้ามทุบทั่ง ไม่ใช่หัว"): the item icon drawn upright
-- put the handle's end on the anvil. The hammer is drawn instead: a handle
-- swinging about the smith's hand (upper right) and a steel head across its
-- end whose FACE lands on the piece.
function TWAGradeReveal:drawHammer(cx, lift)
    local px, py = cx + 150, 128              -- the hand (pivot)
    local faceX, faceY = cx, 190              -- where the face lands
    local half = 26                           -- half the head's length
    -- At the strike the head stands upright, face down.
    local sx, sy = faceX - px, (faceY - half) - py
    local a0 = math.atan2 and math.atan2(sy, sx) or math.atan(sy, sx)
    local L = math.sqrt(sx * sx + sy * sy)
    local a = a0 + math.min(1.3, lift / 100)  -- raised = turned up
    local ux, uy = math.cos(a), math.sin(a)   -- along the handle
    local vx, vy = -uy, ux                    -- along the head
    if vy > 0 then vx, vy = -vx, -vy end      -- keep "up" pointing up
    local hx, hy = px + ux * L, py + uy * L   -- head centre
    -- Handle: dark edge, wood, a highlight, a leather grip at the hand.
    self:line(px, py, hx, hy, 10, 1, { r = 0.22, g = 0.14, b = 0.07 })
    self:line(px, py, hx, hy, 7, 1, { r = 0.52, g = 0.35, b = 0.18 })
    self:line(px - vx * 1.5, py - vy * 1.5, hx - vx * 1.5, hy - vy * 1.5, 2, 0.6, { r = 0.75, g = 0.56, b = 0.33 })
    self:line(px, py, px + ux * 40, py + uy * 40, 11, 1, { r = 0.3, g = 0.18, b = 0.1 })
    -- Head: a steel block across the handle's end, face down.
    local w = 12
    local function corner(sv, su) return hx + vx * half * sv + ux * w * su, hy + vy * half * sv + uy * w * su end
    local x1, y1 = corner(1, -1)
    local x2, y2 = corner(1, 1)
    local x3, y3 = corner(-1, 1)
    local x4, y4 = corner(-1, -1)
    self:quad(x1, y1, x2, y2, x3, y3, x4, y4, 1, 0.42, 0.44, 0.48)
    -- lit top half, darker striking end, a bright rim on the face
    local mx1, my1 = corner(0.2, -1)
    local mx2, my2 = corner(0.2, 1)
    self:quad(x1, y1, x2, y2, mx2, my2, mx1, my1, 1, 0.58, 0.6, 0.65)
    self:line(x3, y3, x4, y4, 3, 1, { r = 0.85, g = 0.87, b = 0.9 })
    self:polyline({ { x1, y1 }, { x2, y2 }, { x3, y3 }, { x4, y4 } }, 1.5, 1, { r = 0.15, g = 0.15, b = 0.17 }, true)
    -- The wedge where the handle goes through.
    self:disc(hx, hy, 3, 1, { r = 0.3, g = 0.2, b = 0.1 }, 8)
end

function TWAGradeReveal:renderOverlay()
    local gc = self:gradeColor()
    local cx = 310
    if self.flashA and self.flashA > 0 then
        self:rectRGB(0, 0, PW, PH, self.flashA * 0.8, 1, 0.97, 0.9)
    end
    if not self.revealAt then
        if not self.material then
            -- The spinning letter, flickering.
            local a = 0.55 + 0.45 * math.sin(self.elapsed * 0.03)
            self:textC(self.letter, cx, 40, gc, a, BIG)
        end
        return
    end
    -- The result.
    local since = self.elapsed - self.revealAt
    if self.grade then
        for i = 3, 1, -1 do self:disc(cx, 58, 26 + i * 10, 0.12, gc, 30) end
        self:textC(self.grade, cx, 36, gc, 1, BIG)
        self:textC(getText("IGUI_TWA_Reveal_Grade", self.grade), cx, 176, gc, 1, UIFont.Medium)
    elseif not self.found then
        self:textC("?", cx, 36, C.faint, 1, BIG)
    end
    self:textC(self.itemName, cx, 262 - 60, C.line, 1, UIFont.Medium)
    if self.qualityWord and TWACraftState.isWord(self.qualityWord) then
        local wc = TWACraftState.WORD_COLOR[self.qualityWord]
        self:textC(getText("IGUI_TWA_TooltipQuality", TWACraftState.wordText(self.qualityWord)), cx, 312, wc, 1, UIFont.Small)
    elseif self.material then
        self:textC(getText("IGUI_TWA_Reveal_Material"), cx, 312, NO_GRADE, 1, UIFont.Small)
    end
    if since > 900 then
        self:textC(getText("IGUI_TWA_Reveal_Close"), cx, 330, C.faint, 0.6 + 0.4 * math.sin(self.elapsed * 0.006), UIFont.Small)
    end
end

-- Its own frame: no quality meter, no cancel button -- nothing to play.
function TWAGradeReveal:draw()
    self:drawRect(-self.x, -self.y, getCore():getScreenWidth(), getCore():getScreenHeight(), 0.7, 0, 0, 0)
    self:drawRect(0, 0, self.width, self.height, 0.97, 0.03, 0.03, 0.04)
    local gc = self:gradeColor()
    self:drawRectBorder(0, 0, self.width, self.height, 1, gc.r * 0.8, gc.g * 0.8, gc.b * 0.8)
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

function TWAGradeReveal:finish()
    if self.closed then return end
    self.onResult = nil
    self:teardown()
end

function TWAGradeReveal:canClose()
    return self.revealAt ~= nil and (self.elapsed - self.revealAt) > 900
end

function TWAGradeReveal:onMouseDown()
    if self:canClose() then self:finish() end
    return true
end
function TWAGradeReveal:onMouseUp() return true end
function TWAGradeReveal:onMouseUpOutside() return true end
function TWAGradeReveal:onMouseDownOutside() return self:onMouseDown() end
function TWAGradeReveal:onRightMouseUp() return self:onMouseDown() end
function TWAGradeReveal:onRightMouseUpOutside() return self:onMouseDown() end
function TWAGradeReveal:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE and self:canClose() then self:finish() end
end
function TWAGradeReveal:onTimeout() end

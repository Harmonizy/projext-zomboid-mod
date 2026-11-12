--[[
    HARMONIE - From Garden to Plate: cooking one dish, step by step (client).

    1.0.4 (owner, 2026-11-12: "ทำเสร็จหมดแล้วแต่หาของไม่เจอ ... เอาของไปตอนกดทำ
    แล้วเสกอันที่เสร็จตอนทำเสร็จสิ้น และหากกดยกเลิกให้คืนของที่ใช้ทำ ส่วนหากออกแท็บ
    ตอนกำลังทำให้บันทึกไว้ว่าทำอยู่แล้วทำต่อเมื่อไหร่ก็ได้"):
      1. Start: the authority (HARMONIE_CookServer: server / single player)
         TAKES every ingredient and the container (pot, pan, bowl...) --
         from the inventory, bags or boxes in the room. Nothing goes in
         through vanilla's evolved-recipe actions any more, so there is no
         dish item to look for.
      2. the preparation steps in the dish's order: each is a minigame (or a
         plain "Good" when the sandbox turns them off), then its timed
         action. A Miss is played again. Each finished step is saved on the
         authority (progress), so leaving the tab, the window or the game
         keeps the dish; it continues from there any time.
      3. Finish: the authority MAKES the dish (the recipe's result item)
         with the ingredients' nutrition and vitamins, sets the quality and
         gives the Cooking XP. Cancel gives everything taken back.
    The dish is then cooked like any other: stove, oven, campfire.
]]--

require "HARMONIEGardenToPlate/HARMONIE_CookCore"
require "TimedActions/HARMONIE_GTP_CookActions"
require "HARMONIEGardenToPlate/HARMONIE_CookFX"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.CookFlow = HARMONIE_GTP.CookFlow or {}
local F = HARMONIE_GTP.CookFlow
local K = HARMONIE_GTP.Cook
local log = K.log

local function nowMs() return getTimestampMs and getTimestampMs() or 0 end

local function call(o, m, ...) return K.call(o, m, ...) end
local function inv(player) return call(player, "getInventory") end

-- an item from a bag, a box across the room or the floor into the inventory:
-- the hub's HARMONIE_Reach.bring (walks to a far box first), else vanilla
function F.bring(player, item)
    if HARMONIE_Reach and HARMONIE_Reach.bring then return HARMONIE_Reach.bring(player, item) end
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then
        ISInventoryPaneContextMenu.transferIfNeeded(player, item)
        return true
    end
    return false
end

function F.busy() return F.run ~= nil and F.run.phase ~= "done" end

local function ingredientIcon(plan)
    for _, a in ipairs(plan.adds or {}) do
        if not a.spice then
            local t = call(a.item, "getTexture")
            if t then return t end
        end
    end
    return nil
end
local function spiceIcon(plan)
    for _, a in ipairs(plan.adds or {}) do
        if a.spice then return call(a.item, "getTexture") end
    end
    return nil
end

-- ----------------------------------------------------------------- start
local S = function() return HARMONIE_GTP.CookServer end

local function resultTypeOf(plan)
    local res = tostring(call(plan and plan.recipe, "getResultItem") or "")
    if res == "" or res == "nil" then return nil end
    return res:find("%.") and res or ("Base." .. res)
end

function F.start(player, dish)
    if F.busy() then log("start %s refused: %s is still being made", dish.id, F.run.dish.id); return false, "busy" end
    if not S() then log("start %s refused: the cooking server part is missing", dish.id); return false, "ingredients" end
    local plan = K.plan(player, dish, K.scan(player, true))
    if not plan.ready then
        log("start %s refused: %s", dish.id, table.concat(plan.reasons, ", "))
        return false, plan.reasons[1]
    end
    local result = resultTypeOf(plan)
    if not result then log("start %s refused: the recipe makes no item", dish.id); return false, "base" end
    -- the container and every ingredient (each item once); seasonings lose one use
    local items, seen = {}, {}
    local function add(it, spice)
        local id = call(it, "getID")
        if id and not seen[id] then seen[id] = true; items[#items + 1] = { id = id, spice = spice == true } end
    end
    if plan.base then add(plan.base, false) end
    for _, a in ipairs(plan.adds) do add(a.item, a.spice) end
    -- the pictures the minigames show, kept: the items themselves are taken now
    local icons = { ing = ingredientIcon(plan), spice = spiceIcon(plan), base = plan.base and call(plan.base, "getTexture"), cursor = {} }
    for i, pp in ipairs(plan.procs) do icons.cursor[i] = K.cursorTexture(plan, pp) end
    F.run = { player = player, dish = dish, step = 1, words = {}, phase = "taking", icons = icons, startedAt = nowMs() }
    log("cooking %s: %d steps; asking to take %d item(s) (container %s), makes %s", dish.id, #dish.procs, #items,
        K.typeOf(plan.base), result)
    S().request(player, "take", { dish = dish.id, result = result, items = items })
    return true
end

-- a dish the authority still has from before (relog, window closed, tab left)
function F.resumeFrom(player, p)
    local dish = p and K.DISH_BY_ID[tostring(p.dish)]
    if not dish then return false end
    F.run = { player = player, dish = dish, step = math.max(1, tonumber(p.step) or 1), words = type(p.words) == "table" and p.words or {},
        phase = "paused", icons = { cursor = {} }, resumed = true, startedAt = nowMs() }
    log("cooking %s: carried on from step %d (saved)", dish.id, F.run.step)
    return true
end

function F.cancel(why)
    local r = F.run
    if not r then return end
    log("cooking %s cancelled at %s (%s) -- asking for the ingredients back", r.dish.id, tostring(r.phase), tostring(why or "button"))
    if HARMONIE_GTP.CookGames and HARMONIE_GTP.CookGames.close then HARMONIE_GTP.CookGames.close() end
    if r.action then pcall(function() r.action:forceStop() end) end
    if r.phase == "failed" and r.failReason == "take" then F.run = nil; return end
    r.phase = "cancelling"
    if S() then S().request(r.player, "cancel", {}) else F.run = nil end
end

local function saveProgress(r)
    if S() then S().request(r.player, "progress", { step = r.step, words = r.words }) end
end

-- ----------------------------------------------------------------- steps
function F.nextStep()
    local r = F.run
    if not r then return end
    if r.step > #r.dish.procs then return F.finishCook() end
    local pid = r.dish.procs[r.step]
    local plan = K.plan(r.player, r.dish, K.scan(r.player, true))
    local pp = plan.procs[r.step]
    if not pp or not pp.ok then
        r.phase = "blocked"
        r.blockedBy = pp and (pp.noHeat and "heat" or "tools") or "?"
        log("step %s blocked: %s", pid, r.blockedBy)
        return
    end
    r.phase = "game"
    r.pp = pp
    local function onWord(word)
        if F.run ~= r then return end
        if word == nil then
            r.phase = "paused"
            log("step %s: minigame closed without a result", pid)
            return
        end
        if word == "Miss" then
            r.phase = "retry"
            r.lastMiss = pid
            log("step %s missed -- play it again", pid)
            return
        end
        F.queueStep(pid, word, pp, plan)
    end
    local Gm = HARMONIE_GTP.CookGames
    if K.minigamesOn() and Gm and Gm.play then
        local cur = K.cursorItem(plan, pp)
        local diff = K.difficulty(r.player, pp, r.dish)
        local ease = K.levelEase(K.level(r.player))
        local timeMul = ease.time * K.minigameTime()
        log("step %s: minigame with %s (%s), Cooking %d: difficulty %.2f, slips x%.2f, time x%.2f (level x%.2f, sandbox x%.2f)", pid, cur and K.typeOf(cur) or "bare hands",
            pp.tools[1] and tostring(pp.tools[1].grade) or "no tool", K.level(r.player), diff, ease.slip, timeMul, ease.time, K.minigameTime())
        local ic = r.icons or { cursor = {} }
        local ok = Gm.play(r.player, pid, { difficulty = diff, slipMul = ease.slip, timeMul = timeMul, icon = ic.ing,
            spice = ic.spice, base = ic.base,
            tool = pp.tools[1] and pp.tools[1].item and call(pp.tools[1].item, "getTexture"),
            cursor = (pp.proc and pp.proc.cursor == "tool") and K.cursorTexture(plan, pp) or ic.cursor[r.step], bare = pp.tools[1] and pp.tools[1].grade == "bare",
            toolIsGrater = not (pp.tools[1] and pp.tools[1].group == "grater" and pp.tools[1].grade ~= "best"),
            family = r.dish.family }, onWord)
        if not ok then r.phase = "paused"; log("step %s: minigame busy", pid) end
    else
        onWord("Good")
    end
end

function F.queueStep(pid, word, pp, plan)
    local r = F.run
    -- in the hands during the action: the tool, else the food or seasoning
    -- being worked (the same thing the minigame showed at the mouse)
    local tool = pp.tools[1] and pp.tools[1].item or (plan and K.cursorItem(plan, pp)) or nil
    local action = HARMONIE_GTP_CookStepAction:new(r.player, pid, word, tool)
    action.onEnd = function(done, w)
        if F.run ~= r then return end
        r.action = nil
        if done then
            r.words[pid] = w
            r.step = r.step + 1
            r.phase = "ready"
            saveProgress(r)
            F.nextStep()
        else
            r.phase = "paused"
        end
    end
    r.action = action
    r.phase = "action"
    ISTimedActionQueue.add(action)
end

-- the button under a missed / stopped / blocked step
function F.retry()
    local r = F.run
    if not r then return end
    log("step %s: again", tostring(r.dish.procs[r.step]))
    F.nextStep()
end

-- ----------------------------------------------------------------- finish
function F.finishCook()
    local r = F.run
    if not r then return end
    r.quality = K.qualityOf(r.words)
    r.phase = "finishing"
    log("%s: every step done (quality %.2f %s) -- asking for the dish", r.dish.id, r.quality, K.wordOf(r.quality))
    if S() then S().request(r.player, "finish", { q = r.quality }) end
end

-- a failed start / finish: try that part again
function F.retryFailed()
    local r = F.run
    if not r or r.phase ~= "failed" then return false end
    r.retries = (r.retries or 0) + 1
    log("%s: retry %d after %s", r.dish.id, r.retries, tostring(r.failReason))
    if r.failReason == "take" then
        local player, dish = r.player, r.dish
        F.run = nil
        return F.start(player, dish)
    end
    r.failReason, r.failWhy = nil, nil
    F.finishCook()
    return true
end

-- the authority's answers (MP: from the server; SP: at once)
local function onReply(command, args)
    local r = F.run
    local player = (r and r.player) or (getPlayer and getPlayer())
    local FX = HARMONIE_GTP.CookFX
    if command == "taken" then
        if not r then return end
        log("%s: ingredients and container taken -- the steps can start", r.dish.id)
        r.phase = "ready"
        F.nextStep()
    elseif command == "refused" then
        if args.why == "busy" and args.pending then
            log("start refused: a dish is already being made -- showing it")
            F.resumeFrom(player, args.pending)
            return
        end
        if not r then return end
        local stage = (r.phase == "finishing") and "make" or "take"
        r.phase, r.failReason, r.failWhy = "failed", stage, tostring(args.why or "?")
        if FX then FX.say(r.player, "Failed") end
        log("%s: the server refused (%s): %s", r.dish.id, stage, tostring(args.why))
    elseif command == "made" then
        if not r then return end
        r.phase, r.resultId, r.quality = "done", args.id, tonumber(args.q) or r.quality
        local item = K.findInInventory(r.player, tonumber(args.id))
        if item then
            if args.unhappy then pcall(function() item:setUnhappyChange(args.unhappy) end) end
            if args.boredom then pcall(function() item:setBoredomChange(args.boredom) end) end
            local md = call(item, "getModData")
            if md then md.HARMONIE_CookQuality = K.wordOf(r.quality); md.HARMONIE_CookDish = r.dish.id; md.HARMONIE_CookLevel = tonumber(args.level) end
        end
        log("%s finished: dish item id %s (%s)", r.dish.id, tostring(args.id), item and K.typeOf(item) or "arriving")
        if FX then FX.say(r.player, K.wordOf(r.quality) == "Excellent" and "DoneExcellent" or "Done") end
    elseif command == "returned" then
        log("cooking cancelled: %s item(s) given back", tostring(args.n))
        F.run = nil
    elseif command == "pending" then
        if args.pending and not F.run then F.resumeFrom(player, args.pending) end
    end
end

function F.ensureReplies()
    local Sv = S()
    if Sv and Sv.onReply ~= onReply then Sv.onReply = onReply end
end
F.ensureReplies()

-- a dish left half-made: ask once the game is on (MP: the server answers)
function F.askPending(player)
    F.ensureReplies()
    player = player or (getPlayer and getPlayer())
    if player and S() and not F.run then S().request(player, "pending", {}) end
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(function() F.askPending() end) end

function F.resultItem()
    local r = F.run
    if not r or not r.resultId then return nil end
    return K.findInInventory(r.player, tonumber(r.resultId))
end

function F.clear() F.run = nil end

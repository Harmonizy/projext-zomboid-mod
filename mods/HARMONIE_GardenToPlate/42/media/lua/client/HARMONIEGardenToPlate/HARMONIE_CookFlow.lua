--[[
    HARMONIE - From Garden to Plate: cooking one dish, step by step (client).

      1. preparation steps in the dish's order: each is a minigame (or a
         plain "Good" when the sandbox turns them off), then its timed
         action. A Miss is played again; nothing is used up yet.
      2. the ingredients go in one by one through vanilla's own
         ISAddItemInRecipe -- base and ingredient are first moved into the
         inventory the vanilla way (transferIfNeeded). After the first
         addition vanilla swaps the base (a pot of water) for the dish item
         (a pot of stew); the next addition looks that new item up, waiting
         a moment for it when it comes from the server.
      3. the steps' quality is sent to the authority (K.serveQuality) which
         changes the dish's boredom / unhappiness and gives Cooking XP.
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

F.MAX_WAITS = 25
-- Owner, 2026-10-24: stuck "putting the food in", and Cancel did not work.
-- Vanilla's ISTimedActionQueue clears the whole queue when one action turns
-- invalid (an ISAddItemInRecipe or a transfer the server refused): our wait
-- action behind it went too, so F.addNext was never called again. A watchdog
-- carries on when nothing happened for STALL_MS and the character is idle.
F.STALL_MS = 8000
F.MAX_STALLS = 3
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end

local function call(o, m, ...) return K.call(o, m, ...) end
local function inv(player) return call(player, "getInventory") end

function F.busy() return F.run ~= nil and F.run.phase ~= "done" and F.run.phase ~= "failed" end

-- ----------------------------------------------------------------- start
function F.start(player, dish)
    if F.busy() then log("start %s refused: %s is still being made", dish.id, F.run.dish.id); return false, "busy" end
    local plan = K.plan(player, dish, K.scan(player, true))
    if not plan.ready then
        log("start %s refused: %s", dish.id, table.concat(plan.reasons, ", "))
        return false, plan.reasons[1]
    end
    F.run = { player = player, dish = dish, step = 1, words = {}, phase = "ready", startedAt = getTimestampMs and getTimestampMs() or 0 }
    log("cooking %s: %d steps, %d vanilla additions into %s (recipe %s)", dish.id, #dish.procs, #plan.adds,
        K.typeOf(plan.base), K.recipeName(plan.recipe))
    F.nextStep()
    return true
end

function F.cancel(why)
    local r = F.run
    if not r then return end
    log("cooking %s cancelled at %s (%s)", r.dish.id, tostring(r.phase), tostring(why or "button"))
    if HARMONIE_GTP.CookGames and HARMONIE_GTP.CookGames.close then HARMONIE_GTP.CookGames.close() end
    if r.action then pcall(function() r.action:forceStop() end) end
    if r.phase == "adding" and ISTimedActionQueue and ISTimedActionQueue.clear then
        pcall(ISTimedActionQueue.clear, r.player)
        log("cooking %s: %d of %d ingredients were already in (they stay in the dish)", r.dish.id, r.addIdx or 0, #(r.adds or {}))
    end
    F.run = nil
end

-- ----------------------------------------------------------------- steps
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

function F.nextStep()
    local r = F.run
    if not r then return end
    if r.step > #r.dish.procs then return F.startAdding() end
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
        log("step %s: minigame with %s (%s), Cooking %d: difficulty %.2f, slips x%.2f, time x%.2f", pid, cur and K.typeOf(cur) or "bare hands",
            pp.tools[1] and tostring(pp.tools[1].grade) or "no tool", K.level(r.player), diff, ease.slip, ease.time)
        local ok = Gm.play(r.player, pid, { difficulty = diff, slipMul = ease.slip, timeMul = ease.time, icon = ingredientIcon(plan),
            spice = spiceIcon(plan), base = plan.base and call(plan.base, "getTexture"),
            tool = pp.tools[1] and pp.tools[1].item and call(pp.tools[1].item, "getTexture"),
            cursor = K.cursorTexture(plan, pp), bare = pp.tools[1] and pp.tools[1].grade == "bare",
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

-- --------------------------------------------------------------- adding
local function idsOfType(player, t)
    local set = {}
    local items = inv(player) and inv(player):getItems()
    for i = 0, (items and items:size() or 0) - 1 do
        local it = items:get(i)
        if K.typeOf(it) == t then set[call(it, "getID") or -1] = true end
    end
    return set
end

local function findById(player, id)
    return K.findInInventory(player, id)
end

function F.startAdding()
    local r = F.run
    local plan = K.plan(r.player, r.dish, K.scan(r.player, true))
    if not plan.ready then
        r.phase = "failed"
        -- nothing went in yet; the steps' results stay for Retry
        r.failReason = "ingredients"
        r.failWhy = plan.reasons[1]
        if HARMONIE_GTP.CookFX then HARMONIE_GTP.CookFX.say(r.player, "Failed") end
        log("%s: cannot add the ingredients any more (%s)", r.dish.id, table.concat(plan.reasons, ", "))
        return
    end
    r.phase = "adding"
    r.plan = plan
    r.recipe = plan.recipe
    r.adds = plan.adds
    r.addIdx = 0
    r.waits = 0
    r.stalls = 0
    r.progressAt = nowMs()
    local base = plan.base
    r.baseId = call(base, "getID")
    r.partial = plan.fam and plan.fam.partial == true
    local res = tostring(call(plan.recipe, "getResultItem") or "")
    r.resultType = res:find("%.") and res or ("Base." .. res)
    r.preIds = idsOfType(r.player, r.resultType)
    log("%s: adding %d ingredients with vanilla (base %s id %s, makes %s)", r.dish.id, #r.adds, K.typeOf(base), tostring(r.baseId), r.resultType)
    if call(base, "getContainer") ~= inv(r.player) and ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then
        ISInventoryPaneContextMenu.transferIfNeeded(r.player, base)
    end
    ISTimedActionQueue.add(HARMONIE_GTP_CookWaitAction:new(r.player, 2, F.addNext, r))
end

-- the dish item now: the base until the first addition, then vanilla's new
-- dish item (one of the result type that was not there before)
function F.currentBase(r)
    local b = r.baseId and findById(r.player, r.baseId)
    if b and (r.partial or r.addIdx == 0 or K.typeOf(b) == r.resultType) then return b end
    local items = inv(r.player) and inv(r.player):getItems()
    for i = 0, (items and items:size() or 0) - 1 do
        local it = items:get(i)
        local id = call(it, "getID")
        if K.typeOf(it) == r.resultType and not r.preIds[id] then
            r.baseId = id
            return it
        end
    end
    return b
end

local function stillUsable(r, item)
    if not item or not call(item, "getContainer") then return false end
    if K.isFood(item) and not K.isSpice(item) and K.hunger(item) <= 0 then return false end
    if K.isPoison(item) then return false end
    if K.needsCooking(r.dish.family, K.typeOf(item)) and not K.isCooked(item) then return false end
    return K.allowed(r.recipe, item) ~= false
end

-- another item for the same slot when the planned one was used up
local function another(r, entry)
    local scan = K.scan(r.player, true)
    for _, t in ipairs((K.slotTypesAt(scan, r.dish.slots[entry.slot]))) do
        for _, it in ipairs(scan.byType[t] or {}) do
            if stillUsable(r, it) and not K.isRotten(it) then return it end
        end
    end
    return nil
end

function F.addNext(character, r)
    if F.run ~= r or r.phase ~= "adding" then return end
    r.progressAt = nowMs()
    if r.addIdx >= #r.adds then return F.finish(r) end
    local base = F.currentBase(r)
    if not base or (r.addIdx > 0 and not r.partial and K.typeOf(base) ~= r.resultType) then
        r.waits = r.waits + 1
        if r.waits > F.MAX_WAITS then
            r.phase = "failed"; r.failReason = "base"
            if HARMONIE_GTP.CookFX then HARMONIE_GTP.CookFX.say(r.player, "Failed") end
            log("%s: the dish item never showed up after addition %d -- stopped", r.dish.id, r.addIdx)
            return
        end
        ISTimedActionQueue.add(HARMONIE_GTP_CookWaitAction:new(character, 10, F.addNext, r))
        return
    end
    r.waits = 0
    local maxItems = K.maxItems(r.recipe)
    local extra = call(base, "getExtraItems")
    local nExtra = extra and extra.size and extra:size() or 0
    local entry = r.adds[r.addIdx + 1]
    if maxItems and not entry.spice and nExtra >= maxItems then
        log("%s: the dish is full (%d of %d) -- the rest is left out", r.dish.id, nExtra, maxItems)
        return F.finish(r)
    end
    local item = entry.item
    if not stillUsable(r, item) then
        item = another(r, entry)
        if not item then
            log("%s: no %s left for addition %d -- skipped", r.dish.id, tostring(entry.type), r.addIdx + 1)
            r.addIdx = r.addIdx + 1
            ISTimedActionQueue.add(HARMONIE_GTP_CookWaitAction:new(character, 1, F.addNext, r))
            return
        end
    end
    r.addIdx = r.addIdx + 1
    if call(item, "getContainer") ~= inv(character) and ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then
        ISInventoryPaneContextMenu.transferIfNeeded(character, item)
    end
    log("%s: addition %d/%d -- %s into %s", r.dish.id, r.addIdx, #r.adds, K.typeOf(item), K.typeOf(base))
    ISTimedActionQueue.add(ISAddItemInRecipe:new(character, r.recipe, base, item))
    ISTimedActionQueue.add(HARMONIE_GTP_CookWaitAction:new(character, 3, F.addNext, r))
end

-- the watchdog (OnTick): the queue was cleared under us -> carry on
function F.watch()
    local r = F.run
    if not r or r.phase ~= "adding" then return end
    local t = nowMs()
    if t - (r.progressAt or t) < F.STALL_MS then return end
    local busy = false
    pcall(function() busy = ISTimedActionQueue.isPlayerDoingAction(r.player) end)
    if busy then r.progressAt = t; return end
    r.stalls = (r.stalls or 0) + 1
    if r.stalls > F.MAX_STALLS then
        r.phase = "failed"; r.failReason = "stuck"
        if HARMONIE_GTP.CookFX then HARMONIE_GTP.CookFX.say(r.player, "Failed") end
        log("%s: adding stalled %d times (addition %d of %d) -- stopped", r.dish.id, r.stalls - 1, r.addIdx or 0, #(r.adds or {}))
        return
    end
    log("%s: adding stalled at addition %d of %d (the action queue was cleared) -- carrying on (%d/%d)",
        r.dish.id, r.addIdx or 0, #(r.adds or {}), r.stalls, F.MAX_STALLS)
    r.progressAt = t
    F.addNext(r.player, r)
end
if Events and Events.OnTick and not F.watchAdded then
    F.watchAdded = true
    Events.OnTick.Add(function()
        local ok, err = pcall(F.watch)
        if not ok and not F.watchErr then F.watchErr = true; log("cooking watchdog FAILED: %s", tostring(err)) end
    end)
end

-- Owner, 2026-10-25: "บางครั้งตอนทำอาหารแล้วเกิดบัค เช่นหาจานไม่เจอ แล้วมันไม่ทำต่อ
-- ให้สามารถกดลองใหม่": a failed dish keeps its steps' results. Retry plans
-- the additions again when nothing went in yet, else carries on from the
-- addition it stopped at, with the dish item looked up again (also in the
-- containers nearby, then moved to the inventory).
local function findDishNearby(r)
    local scan = K.scan(r.player, true)
    if not scan then return nil end
    for _, list in pairs(scan.byType) do
        for _, it in ipairs(list) do
            if r.baseId and call(it, "getID") == r.baseId then return it end
        end
    end
    for _, it in ipairs(scan.byType[r.resultType or ""] or {}) do
        if not (r.preIds and r.preIds[call(it, "getID") or -1]) then return it end
    end
    return nil
end

function F.retryFailed()
    local r = F.run
    if not r or r.phase ~= "failed" then return false end
    r.retries = (r.retries or 0) + 1
    local why = r.failReason
    r.failReason, r.failWhy = nil, nil
    if not r.adds or (r.addIdx or 0) == 0 then
        log("%s: retry %d after %s -- planning the additions again (steps kept)", r.dish.id, r.retries, tostring(why))
        r.phase = "ready"
        F.startAdding()
        return true
    end
    r.phase = "adding"
    r.waits, r.stalls = 0, 0
    r.progressAt = nowMs()
    local dish = F.currentBase(r)
    if not dish then
        dish = findDishNearby(r)
        if dish then
            r.baseId = call(dish, "getID")
            if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then
                ISInventoryPaneContextMenu.transferIfNeeded(r.player, dish)
            end
        end
    end
    log("%s: retry %d after %s -- carrying on from addition %d of %d (dish item %s)", r.dish.id, r.retries, tostring(why),
        r.addIdx or 0, #r.adds, dish and K.typeOf(dish) or "not found yet")
    pcall(ISTimedActionQueue.clear, r.player)
    ISTimedActionQueue.add(HARMONIE_GTP_CookWaitAction:new(r.player, 2, F.addNext, r))
    return true
end

function F.finish(r)
    local dish = F.currentBase(r)
    local q = K.qualityOf(r.words)
    local xp = K.dishXp(r.dish, q)
    r.phase = "done"
    r.quality = q
    r.resultId = dish and call(dish, "getID")
    log("%s finished: %s id %s, quality %.2f (%s), calories %s, hunger %s", r.dish.id, K.typeOf(dish), tostring(r.resultId), q, K.wordOf(q),
        tostring(call(dish, "getCalories")), tostring(call(dish, "getHungerChange")))
    -- the cook says how it went (over their head, in the world)
    local FX = HARMONIE_GTP.CookFX
    if FX then FX.say(r.player, K.wordOf(q) == "Excellent" and "DoneExcellent" or "Done") end
    if not dish then return end
    local args = { id = r.resultId, q = q, dish = r.dish.id, xp = xp }
    if isClient and isClient() then
        sendClientCommand(r.player, K.NET, "quality", args)
    else
        K.serveQuality(r.player, args)
    end
end

function F.resultItem()
    local r = F.run
    if not r or not r.resultId then return nil end
    return findById(r.player, r.resultId)
end

function F.clear() F.run = nil end

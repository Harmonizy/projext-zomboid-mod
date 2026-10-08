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

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.CookFlow = HARMONIE_GTP.CookFlow or {}
local F = HARMONIE_GTP.CookFlow
local K = HARMONIE_GTP.Cook
local log = K.log

F.MAX_WAITS = 25

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
        r.blockedBy = pp and (pp.levelLow and "stepLevel" or "tools") or "?"
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
        log("step %s: minigame with %s (%s), difficulty %.2f", pid, cur and K.typeOf(cur) or "bare hands",
            pp.tools[1] and tostring(pp.tools[1].grade) or "no tool", K.difficulty(r.player, pp))
        local ok = Gm.play(r.player, pid, { difficulty = K.difficulty(r.player, pp), icon = ingredientIcon(plan),
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
        r.failReason = plan.reasons[1]
        log("%s: cannot add the ingredients any more (%s)", r.dish.id, table.concat(plan.reasons, ", "))
        return
    end
    r.phase = "adding"
    r.plan = plan
    r.recipe = plan.recipe
    r.adds = plan.adds
    r.addIdx = 0
    r.waits = 0
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
    if r.addIdx >= #r.adds then return F.finish(r) end
    local base = F.currentBase(r)
    if not base or (r.addIdx > 0 and not r.partial and K.typeOf(base) ~= r.resultType) then
        r.waits = r.waits + 1
        if r.waits > F.MAX_WAITS then
            r.phase = "failed"; r.failReason = "base"
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

function F.finish(r)
    local dish = F.currentBase(r)
    local q = K.qualityOf(r.words)
    local xp = K.dishXp(r.dish, q)
    r.phase = "done"
    r.quality = q
    r.resultId = dish and call(dish, "getID")
    log("%s finished: %s id %s, quality %.2f (%s), calories %s, hunger %s", r.dish.id, K.typeOf(dish), tostring(r.resultId), q, K.wordOf(q),
        tostring(call(dish, "getCalories")), tostring(call(dish, "getHungerChange")))
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

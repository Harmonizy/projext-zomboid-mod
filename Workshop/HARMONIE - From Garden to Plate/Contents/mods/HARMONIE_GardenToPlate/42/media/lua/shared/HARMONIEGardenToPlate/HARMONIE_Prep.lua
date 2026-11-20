--[[
    HARMONIE - From Garden to Plate: prepared ingredients and dish scores
    (GTP 1.1.0, owner 2026-11-19: "ไม่เอาเป็นการสร้างอาหารใหม่แล้ว อยากใช้เมนูเดิม
    ที่ vanilla มี").

    Cooking itself is vanilla's, untouched: evolved recipes (right-click a pot,
    pan, bread...) and the crafting window's Cooking recipes. This file adds
    one thing on top: a SCORE that rides on the items.

      ingredient  one minigame per item (Cooking tab, "Prepare"): Excellent
                  +2, Good +1, Bad / Miss -1; never prepared = 0. Which
                  minigames an item takes depends on what it is (vegetable,
                  meat, fish, egg, dough ...) -- R.gamesFor.
                  modData.HARMONIE_Prep = { w = word, p = minigame, s = score }
      dish        the average of the scores of every food that went in
                  (spices do not count; the base counts when it is a food,
                  a pot or bowl does not). A dish that goes into another
                  dish counts with its own average.
                  modData.HARMONIE_Dish = { sum, n, avg, fam, lvl }
      buff        eating a dish: average < 0 -> a little unhappier; 0 .. 0.49
                  nothing; 0.5 / 1.0 / 1.5 and up -> buff level 1 / 2 / 3
                  (HARMONIE_CookBuffs.lua).

    MULTIPLAYER (each rule below already broke this mod or another once):
      * scores are written ONLY where items are real: SP, or the MP server.
        The client asks ("prep" command); the server checks the item is in
        that player's inventory, is a food that takes that minigame and was
        never prepared, then writes it, gives the XP and SENDS the final
        values back ("set"), which the client copies (set, never added).
      * dish scores are written inside vanilla's own server-side steps:
        ISAddItemInRecipe:complete and ISHandcraftAction:performRecipe, only
        when not isClient() -- so never twice.
      * nothing here lives in the player's modData (the MP client's copy
        replaces the server's); no getPlayer() in shared checks.
      * a "set" that arrives before the item itself is retried for 10 s.
]]--

require "HARMONIEGardenToPlate/HARMONIE_CookCore"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.Prep = HARMONIE_GTP.Prep or {}
local R = HARMONIE_GTP.Prep
local K = HARMONIE_GTP.Cook

R.NET = "HARMONIE_GTP_Prep"
R.WORD_SCORE = { Excellent = 2, Good = 1, Bad = -1, Miss = -1 }
R.XP_MUL = { Excellent = 1.5, Good = 1.0, Bad = 0.5, Miss = 0.25 }
-- buff level from the dish average
R.TIERS = { { at = 1.5, tier = 3 }, { at = 1.0, tier = 2 }, { at = 0.5, tier = 1 } }

local function log(fmt, ...) if HARMONIE_GTP.Log then HARMONIE_GTP.Log("Prep", fmt, ...) end end
local function logOnce(key, fmt, ...) if HARMONIE_GTP.LogOnce then HARMONIE_GTP.LogOnce("Prep:" .. key, "Prep", fmt, ...) end end
R.log, R.logOnce = log, logOnce
-- GTP 1.2.0: one line per event only with sandbox CookDebugLog on; an
-- hourly summary always (owner's rule: log, but never flood a busy server)
function R.debugOn()
    local t = SandboxVars and SandboxVars.HARMONIE_GardenToPlate
    return t ~= nil and t.CookDebugLog == true
end
local function dlog(fmt, ...) if R.debugOn() then log(fmt, ...) end end
R.dlog = dlog
R.tally = R.tally or { prep = 0, add = 0, craft = 0, refused = 0 }
local function count(k) R.tally[k] = (R.tally[k] or 0) + 1 end

local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
local function isClientSide() return isClient and isClient() end
local function isServerSide() return isServer and isServer() end
local function nameOf(p) return tostring(call(p, "getUsername") or "?") end
local function typeOf(it) return tostring(call(it, "getFullType") or "?") end
local function isFood(it)
    local ok, v = pcall(function() return instanceof(it, "Food") end)
    return ok and v == true
end
R.isFood = isFood

-- ------------------------------------------------------------ what it is
-- vanilla FoodType -> the minigames that suit it (order = shown order)
R.KIND_GAMES = {
    veg      = { "wash", "peel", "chop", "slice", "core", "grate", "mash" },
    fruit    = { "wash", "peel", "core", "slice", "mash", "zest" },
    mushroom = { "wash", "slice", "chop" },
    herb     = { "wash", "chop", "grind" },
    meat     = { "trim", "mince", "pound", "slice" },
    poultry  = { "trim", "pound", "slice" },
    fish     = { "scale", "trim", "slice" },
    egg      = { "crack", "whisk" },
    bean     = { "wash", "mash", "grind" },
    cheese   = { "grate", "slice" },
    bread    = { "slice" },
    grain    = { "wash", "measure" },
    dough    = { "knead", "roll" },
    flour    = { "measure" },
}
R.FOODTYPE_KIND = {
    Vegetables = "veg", Vegetable = "veg", Greens = "veg",
    Fruits = "fruit", Citrus = "fruit", Berry = "fruit",
    Mushroom = "mushroom",
    Herb = "herb", HotPepper = "herb",
    Beef = "meat", Meat = "meat", Venison = "meat", Game = "meat", Sausage = "meat", Bacon = "meat",
    Poultry = "poultry",
    Fish = "fish", Seafood = "fish", Roe = "fish",
    Egg = "egg",
    Bean = "bean", Nut = "bean", Seed = "bean",
    Cheese = "cheese",
    Bread = "bread",
    Rice = "grain", Pasta = "grain",
    Thickener = "flour",
}
-- by name when the FoodType says nothing (vanilla's whole fish have none)
R.NAME_KIND = {
    { "Dough", "dough" }, { "Fish", "fish" }, { "Fillet", "fish" }, { "Salmon", "fish" }, { "Trout", "fish" }, { "Bass", "fish" },
    { "Catfish", "fish" }, { "Perch", "fish" }, { "Pike", "fish" }, { "Crappie", "fish" }, { "Gar", "fish" }, { "Flour", "flour" },
}

function R.kindOf(item)
    if not isFood(item) then return nil end
    local t = typeOf(item)
    local short = t:match("%.(.+)$") or t
    for _, e in ipairs(R.NAME_KIND) do
        if e[2] == "dough" and short:find(e[1], 1, true) then return "dough" end
    end
    local ft = call(item, "getFoodType")
    local k = ft and R.FOODTYPE_KIND[tostring(ft)]
    if k then return k end
    for _, e in ipairs(R.NAME_KIND) do
        if short:find(e[1], 1, true) then return e[2] end
    end
    return nil
end

-- why an item cannot be prepared now (nil = it can)
function R.whyNot(item)
    if not isFood(item) then return "notFood" end
    local md = call(item, "hasModData") and call(item, "getModData")
    if md and md.HARMONIE_Prep then return "done" end
    if md and md.HARMONIE_Dish then return "dish" end
    if call(item, "isSpice") == true then return "spice" end
    if call(item, "isCooked") == true then return "cooked" end
    if call(item, "isBurnt") == true then return "burnt" end
    if call(item, "isRotten") == true then return "rotten" end
    if call(item, "isFrozen") == true then return "frozen" end
    if not R.kindOf(item) then return "noGame" end
    return nil
end

function R.gamesFor(item)
    local k = R.kindOf(item)
    local list = k and R.KIND_GAMES[k] or {}
    local out = {}
    for _, pid in ipairs(list) do if K.PROCS[pid] then out[#out + 1] = pid end end
    return out, k
end

function R.allows(item, pid)
    for _, p in ipairs(R.gamesFor(item)) do if p == pid then return true end end
    return false
end

-- ------------------------------------------------------------ reading
local function mdOf(item)
    if not item or call(item, "hasModData") ~= true then return nil end
    return call(item, "getModData")
end

function R.prepOf(item)
    local md = mdOf(item)
    local p = md and md.HARMONIE_Prep
    return type(p) == "table" and p or nil
end

function R.dishOf(item)
    local md = mdOf(item)
    local d = md and md.HARMONIE_Dish
    return type(d) == "table" and d or nil
end

-- the score an item brings into a dish
function R.scoreOf(item)
    local d = R.dishOf(item)
    if d then return tonumber(d.avg) or 0 end
    local p = R.prepOf(item)
    if p then return tonumber(p.s) or 0 end
    return 0
end

-- does it count as one ingredient (a food that is not a spice)?
function R.counts(item)
    return isFood(item) and call(item, "isSpice") ~= true
end

function R.tierOf(avg)
    avg = tonumber(avg) or 0
    if avg < 0 then return -1 end
    for _, t in ipairs(R.TIERS) do if avg >= t.at then return t.tier end end
    return 0
end

-- ------------------------------------------------------------ writing (authority)
local function findById(player, id)
    id = tonumber(id)
    if not id then return nil end
    return K.findInInventory and K.findInInventory(player, id) or nil
end

-- the server tells this player's game the final values of an item
local function sendSet(player, item, what)
    if not isServerSide() or not sendServerCommand then return end
    local md = mdOf(item)
    local args = { id = call(item, "getID"), what = what, prep = md and md.HARMONIE_Prep, dish = md and md.HARMONIE_Dish }
    pcall(sendServerCommand, player, R.NET, "set", args)
    if syncItemModData then pcall(syncItemModData, player, item) end
end
R.sendSet = sendSet

R.lastPrep = {}   -- username -> ms (one prep per 800 ms)
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end

-- GTP 1.2.0 (anti-cheat): the client says "begin" when the minigame opens;
-- the result is taken only for that item and minigame, no sooner than
-- R.MIN_GAME_MS after it and no later than R.MAX_GAME_MS
R.MIN_GAME_MS, R.MAX_GAME_MS = 2500, 300000
R.begun = {}   -- username -> { id, pid, at }
function R.serveBegin(player, args)
    args = type(args) == "table" and args or {}
    R.begun[nameOf(player)] = { id = tonumber(args.id), pid = tostring(args.pid or ""), at = nowMs() }
    dlog("%s began minigame %s on item id %s", nameOf(player), tostring(args.pid), tostring(args.id))
    return true
end

-- one minigame result on one item (SP directly, MP server from "prep")
function R.servePrep(player, args)
    args = type(args) == "table" and args or {}
    local who = nameOf(player)
    local word = tostring(args.word or "")
    local pid = tostring(args.pid or "")
    if not R.WORD_SCORE[word] then log("prep from %s: unknown result %s -- rejected", who, word); return false, "word" end
    if not K.PROCS[pid] then log("prep from %s: unknown minigame %s -- rejected", who, pid); return false, "game" end
    local t = nowMs()
    if t - (R.lastPrep[who] or 0) < 800 then log("prep from %s: too fast -- rejected", who); count("refused"); return false, "fast" end
    local b = R.begun[who]
    if not b or b.id ~= tonumber(args.id) or b.pid ~= pid then
        log("prep from %s: no minigame was started for item id %s with %s -- rejected", who, tostring(args.id), pid); count("refused")
        return false, "noBegin"
    end
    -- no minimum when the sandbox turned the minigames off (only the short action is left)
    local minMs = (K.minigamesOn == nil or K.minigamesOn()) and R.MIN_GAME_MS or 0
    if t - b.at < minMs or t - b.at > R.MAX_GAME_MS then
        log("prep from %s: result %d ms after the minigame began (allowed %d - %d) -- rejected", who, t - b.at, minMs, R.MAX_GAME_MS); count("refused")
        R.begun[who] = nil
        return false, "timing"
    end
    R.begun[who] = nil
    local item = findById(player, args.id)
    if not item then log("prep from %s: item id %s not in their inventory -- rejected", who, tostring(args.id)); return false, "missing" end
    local why = R.whyNot(item)
    if why then log("prep from %s on %s: cannot be prepared (%s) -- rejected", who, typeOf(item), why); return false, why end
    if not R.allows(item, pid) then log("prep from %s: %s does not take minigame %s -- rejected", who, typeOf(item), pid); return false, "game" end
    R.lastPrep[who] = t
    local md = call(item, "getModData")
    if not md then log("prep from %s: %s has no modData -- nothing written", who, typeOf(item)); return false, "md" end
    md.HARMONIE_Prep = { w = word, p = pid, s = R.WORD_SCORE[word] }
    local xp = ((K.PROCS[pid] or {}).xp or 1) * (R.XP_MUL[word] or 1)
    if K.giveXp then K.giveXp(player, xp) end
    count("prep")
    dlog("%s prepared %s (id %s) with %s: %s (%+d)", who, typeOf(item), tostring(args.id), pid, word, R.WORD_SCORE[word])
    sendSet(player, item, "prep")
    return true
end

-- ------------------------------------------------------------ dish scores
-- the evolved-recipe family of a vanilla recipe object (for the buff kind)
local function famOfRecipe(recipe)
    if not recipe or not K.familyOf then return nil end
    local ok, f = pcall(K.familyOf, recipe)
    return ok and f or nil
end

-- 1) evolved recipes: one ingredient goes in (vanilla ISAddItemInRecipe)
function R.onEvolvedAdd(character, recipe, baseBefore, used, baseAfter)
    if not baseAfter then return end
    local d = R.dishOf(baseBefore)
    local sum, n
    if d then
        sum, n = tonumber(d.sum) or 0, tonumber(d.n) or 0
    else
        -- the first addition: the base counts when it is a food (bread
        -- slices, a pie crust), never when it is a pot, pan or bowl
        sum, n = 0, 0
        if R.counts(baseBefore) then sum, n = R.scoreOf(baseBefore), 1 end
    end
    local usedScore = 0
    if used and R.counts(used) then
        usedScore = R.scoreOf(used)
        sum, n = sum + usedScore, n + 1
    end
    local md = call(baseAfter, "getModData")
    if not md then logOnce("evonomd", "dish %s has no modData -- score not kept", typeOf(baseAfter)); return end
    local lvl = K.level and K.level(character) or 0
    local fam = famOfRecipe(recipe) or (d and d.fam)
    md.HARMONIE_Dish = { sum = sum, n = n, avg = n > 0 and (sum / n) or 0, fam = fam, lvl = math.max(lvl, tonumber(d and d.lvl) or 0) }
    count("add")
    dlog("%s added %s (%+.2f) to %s: dish score %.2f over %d (%s)", nameOf(character), used and typeOf(used) or "?", usedScore, typeOf(baseAfter),
        md.HARMONIE_Dish.avg, n, tostring(fam))
    sendSet(character, baseAfter, "dish")
end

-- 2) crafting-window recipes: what was used up -> what came out
function R.onCraft(character, recipeName, consumed, created)
    local sum, n, any, fam, lvl = 0, 0, false, nil, 0
    for i = 0, (consumed and consumed:size() or 0) - 1 do
        local it = consumed:get(i)
        if R.counts(it) then
            n = n + 1
            sum = sum + R.scoreOf(it)
            local d = R.dishOf(it)
            if d then fam = fam or d.fam; lvl = math.max(lvl, tonumber(d.lvl) or 0) end
            if d or R.prepOf(it) then any = true end
        end
    end
    -- nothing prepared went in: the result stays plain vanilla
    if not any or n == 0 then return end
    lvl = math.max(lvl, K.level and K.level(character) or 0)
    local avg = sum / n
    local wrote = 0
    for i = 0, (created and created:size() or 0) - 1 do
        local out = created:get(i)
        if isFood(out) then
            local md = call(out, "getModData")
            if md then
                md.HARMONIE_Dish = { sum = sum, n = n, avg = avg, fam = fam, lvl = lvl }
                wrote = wrote + 1
                sendSet(character, out, "dish")
            end
        end
    end
    count("craft")
    dlog("%s crafted %s: dish score %.2f over %d ingredients -> %d food result(s)", nameOf(character), tostring(recipeName), avg, n, wrote)
end

-- ------------------------------------------------------------ vanilla hooks
local function installHooks()
    if R.hooked then return end
    R.hooked = true
    if ISAddItemInRecipe == nil then pcall(require, "TimedActions/ISAddItemInRecipe") end
    if ISAddItemInRecipe and ISAddItemInRecipe.complete then
        local orig = ISAddItemInRecipe.complete
        function ISAddItemInRecipe:complete()
            local before, used, recipe = self.baseItem, self.usedItem, self.recipe
            local result = orig(self)
            if not isClientSide() then
                local ok, err = pcall(R.onEvolvedAdd, self.character, recipe, before, used, self.baseItem)
                if not ok then logOnce("evofail", "dish score on an evolved-recipe addition FAILED: %s", tostring(err)) end
            end
            return result
        end
        log("evolved-recipe additions wrapped for dish scores")
    else
        logOnce("noevo", "ISAddItemInRecipe not found -- evolved dishes get no score")
    end
    if ISHandcraftAction == nil then pcall(require, "Entity/TimedActions/ISHandcraftAction") end
    if ISHandcraftAction and ISHandcraftAction.performRecipe then
        local orig = ISHandcraftAction.performRecipe
        function ISHandcraftAction:performRecipe()
            local result = orig(self)
            if not isClientSide() and self.logic then
                local ok, err = pcall(function()
                    local data = self.logic:getRecipeData()
                    if not data then return end
                    local consumed = data:getAllConsumedItems()
                    local created = ArrayList.new()
                    self.logic:getCreatedOutputItems(created)
                    local name = self.craftRecipe and call(self.craftRecipe, "getName") or "?"
                    R.onCraft(self.character, name, consumed, created)
                end)
                if not ok then logOnce("craftfail", "dish score on a craft FAILED: %s", tostring(err)) end
            end
            return result
        end
        log("crafting-window recipes wrapped for dish scores")
    else
        logOnce("nocraft", "ISHandcraftAction not found -- crafted food gets no score")
    end
end
R.installHooks = installHooks
if Events and Events.OnGameBoot then Events.OnGameBoot.Add(installHooks) end
if Events and Events.OnServerStarted then Events.OnServerStarted.Add(installHooks) end
if Events and Events.OnGameStart then Events.OnGameStart.Add(installHooks) end

-- ------------------------------------------------------------ network
if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= R.NET or not player then return end
        if command == "begin" then
            R.serveBegin(player, args)
        elseif command == "prep" then
            local ok, why = R.servePrep(player, args)
            if not ok and sendServerCommand then
                pcall(sendServerCommand, player, R.NET, "refused", { id = type(args) == "table" and args.id or nil, why = why })
            end
        else
            log("%s sent unknown prep command %s -- dropped", nameOf(player), tostring(command))
        end
    end)
end

-- client: copy what the server wrote (retried while the item is on its way)
R.pendingSets = {}
local function applySet(args)
    local p = getPlayer and getPlayer()
    local item = p and findById(p, args.id)
    -- GTP 1.2.0: a pot put back on the stove, a result dropped on the floor
    -- box: look in the room's containers too (HARMONIE_Reach)
    if not item and p and HARMONIE_Reach and HARMONIE_Reach.findById then
        if HARMONIE_Reach.forget then HARMONIE_Reach.forget(p) end
        local ok, it = pcall(HARMONIE_Reach.findById, p, tonumber(args.id))
        if ok then item = it end
    end
    if not item then return false end
    local md = call(item, "getModData")
    if not md then return true end
    if args.prep then md.HARMONIE_Prep = args.prep end
    if args.dish then md.HARMONIE_Dish = args.dish end
    if R.onSet then pcall(R.onSet, args, item) end
    return true
end

if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= R.NET or type(args) ~= "table" then return end
        if command == "set" then
            if not applySet(args) then
                R.pendingSets[#R.pendingSets + 1] = { args = args, untilMs = nowMs() + 10000 }
                log("score for item id %s arrived before the item -- retrying", tostring(args.id))
            else
                log("server wrote the %s score of item id %s", tostring(args.what), tostring(args.id))
            end
        elseif command == "refused" then
            log("server refused the preparation of item id %s: %s", tostring(args.id), tostring(args.why))
            if R.onRefused then pcall(R.onRefused, args) end
        end
    end)
end

if Events and Events.OnTick then
    local n = 0
    Events.OnTick.Add(function()
        if #R.pendingSets == 0 then return end
        n = n + 1
        if n % 30 ~= 0 then return end
        local keep, t = {}, nowMs()
        for _, e in ipairs(R.pendingSets) do
            if applySet(e.args) then
                log("score for item id %s copied after waiting", tostring(e.args.id))
            elseif t < e.untilMs then
                keep[#keep + 1] = e
            else
                log("score for item id %s: the item never showed up on this client (it is still on the server's copy)", tostring(e.args.id))
            end
        end
        R.pendingSets = keep
    end)
end

-- client side: the minigame opens (SP: noted at once)
function R.begin(player, item, pid)
    local args = { id = call(item, "getID"), pid = pid }
    if isClientSide() then sendClientCommand(player, R.NET, "begin", args) else R.serveBegin(player, args) end
end

-- client side: ask for one preparation (SP: done at once)
function R.request(player, item, pid, word)
    local args = { id = call(item, "getID"), pid = pid, word = word }
    if isClientSide() then
        sendClientCommand(player, R.NET, "prep", args)
        log("asked the server to prepare %s (id %s) with %s: %s", typeOf(item), tostring(args.id), pid, word)
        return true
    end
    local ok, why = R.servePrep(player, args)
    if not ok and R.onRefused then pcall(R.onRefused, { id = args.id, why = why }) end
    return ok
end

if Events and Events.EveryHours then
    Events.EveryHours.Add(function()
        if isClientSide() then return end
        local c = R.tally
        if (c.prep + c.add + c.craft + c.refused) > 0 then
            log("last game hour: %d ingredient(s) prepared, %d scored addition(s), %d scored craft(s), %d request(s) refused (each one: sandbox CookDebugLog)",
                c.prep, c.add, c.craft, c.refused)
        end
        R.tally = { prep = 0, add = 0, craft = 0, refused = 0 }
    end)
end

log("loaded: %d food kinds, scores Excellent %+d / Good %+d / Bad %+d / Miss %+d", (function() local c = 0 for _ in pairs(R.KIND_GAMES) do c = c + 1 end return c end)(),
    R.WORD_SCORE.Excellent, R.WORD_SCORE.Good, R.WORD_SCORE.Bad, R.WORD_SCORE.Miss)

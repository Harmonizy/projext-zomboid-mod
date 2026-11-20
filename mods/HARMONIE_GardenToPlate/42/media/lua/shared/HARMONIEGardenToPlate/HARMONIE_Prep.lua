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
-- defaults; the live values come from the sandbox (R.wordScore / R.tierCut,
-- GTP 1.3.0 #42). "Off" = prepared while the sandbox had the minigames off.
R.WORD_SCORE = { Excellent = 2, Good = 1, Bad = -0.5, Miss = -1, Off = 0 }
R.XP_MUL = { Excellent = 1.5, Good = 1.0, Bad = 0.5, Miss = 0.25 }
-- buff level from the dish average
R.TIERS = { { at = 1.5, tier = 3 }, { at = 1.0, tier = 2 }, { at = 0.5, tier = 1 } }
R.SV_SCORE = { Excellent = "CookScoreExcellent", Good = "CookScoreGood", Bad = "CookScoreBad", Miss = "CookScoreMiss" }
R.SV_TIER = { "CookBuffTier1", "CookBuffTier2", "CookBuffTier3" }
function R.sv(key, default)
    local t = SandboxVars and SandboxVars.HARMONIE_GardenToPlate
    local v = t and tonumber(t[key])
    if v == nil then return default end
    return v
end
function R.wordScore(w)
    local def = R.WORD_SCORE[w]
    if def == nil then return 0 end
    local key = R.SV_SCORE[w]
    return key and R.sv(key, def) or def
end
function R.tierCut(i)
    local def = ({ 0.5, 1.0, 1.5 })[i]
    return R.sv(R.SV_TIER[i], def)
end
-- buff level 3 needs a cook of at least this Cooking level (#40)
function R.tier3Level() return R.sv("CookBuffTier3Level", 5) end

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
    -- every vanilla whole fish (tag base:uncutfish), whatever its name
    if R.WHOLE_FISH and R.WHOLE_FISH[t] then return "fish" end
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
    if not R.kindOf(item) or #R.gamesFor(item) == 0 then return "noGame" end
    return nil
end

-- GTP 1.4.0 (#11 / #12): finer than the kind -- what THIS food can really
-- take. First rule whose kind matches and whose words (lower-case parts of
-- the type name) hit wins; no rule = the kind's whole list.
-- Whole fish = vanilla tag base:uncutfish (from tags_index.txt).
R.WHOLE_FISH = { ["Base.AligatorGar"] = true, ["Base.BlackCrappie"] = true, ["Base.BlueCatfish"] = true, ["Base.Bluegill"] = true, ["Base.ChannelCatfish"] = true, ["Base.FlatheadCatfish"] = true, ["Base.FreshwaterDrum"] = true, ["Base.GreenSunfish"] = true, ["Base.LargemouthBass"] = true, ["Base.Muskellunge"] = true, ["Base.Paddlefish"] = true, ["Base.RedearSunfish"] = true, ["Base.Salmon"] = true, ["Base.Sauger"] = true, ["Base.SmallmouthBass"] = true, ["Base.SpottedBass"] = true, ["Base.StripedBass"] = true, ["Base.Walleye"] = true, ["Base.WhiteBass"] = true, ["Base.WhiteCrappie"] = true, ["Base.YellowPerch"] = true }
R.GAME_RULES = {
    { kind = "veg", words = { "lettuce", "cabbage", "kale", "spinach", "greens", "dandelion", "nettle", "chard", "brussel", "broccoli", "cauliflower" }, games = { "wash", "chop", "slice" } },
    { kind = "veg", words = { "potato", "carrot", "turnip", "radish", "daikon", "beet", "ginger", "parsnip" }, games = { "wash", "peel", "chop", "slice", "grate", "mash" } },
    { kind = "veg", words = { "onion", "garlic", "leek", "shallot", "chive" }, games = { "peel", "chop", "slice" } },
    { kind = "veg", words = { "tomato", "pepper", "cucumber", "zucchini", "eggplant", "pumpkin", "squash", "melon" }, games = { "wash", "core", "chop", "slice" } },
    { kind = "veg", words = { "corn" }, games = { "wash", "peel" } },
    { kind = "veg", words = { "pea", "bean", "soy" }, games = { "wash" } },
    { kind = "veg", games = { "wash", "chop", "slice" } },
    { kind = "fruit", words = { "orange", "lemon", "lime", "grapefruit", "tangerine", "citrus" }, games = { "peel", "slice", "zest" } },
    { kind = "fruit", words = { "banana" }, games = { "peel", "slice", "mash" } },
    { kind = "fruit", words = { "apple", "pear", "peach", "mango", "pineapple", "avocado", "apricot", "plum" }, games = { "wash", "peel", "core", "slice" } },
    { kind = "fruit", foodtype = "Berry", games = { "wash" } },
    { kind = "fruit", words = { "grape", "cherry", "strewberrie", "strawberr", "berry" }, games = { "wash" } },
    { kind = "fruit", games = { "wash", "slice" } },
    { kind = "herb", foodtype = "HotPepper", games = { "wash", "chop", "slice" } },
    { kind = "meat", words = { "minced" }, games = {} },
    { kind = "meat", words = { "sausage", "bacon", "ham", "salami", "baloney", "pepperoni" }, games = { "slice" } },
    { kind = "poultry", words = { "fillet", "breast", "wing", "leg" }, games = { "trim", "pound", "slice" } },
    { kind = "poultry", games = { "trim", "slice" } },
    { kind = "fish", whole = true, games = { "scale", "trim" } },
    { kind = "fish", words = { "shrimp", "crayfish", "lobster", "squid", "oyster", "mussel", "clam", "crab" }, games = { "wash", "trim" } },
    { kind = "fish", words = { "roe", "caviar" }, games = { "wash" } },
    { kind = "fish", games = { "trim", "slice" } },
    { kind = "bean", foodtype = "Nut", games = { "grind" } },
    { kind = "bean", foodtype = "Seed", games = { "grind" } },
    { kind = "bean", words = { "open", "refried", "tofu" }, games = { "mash" } },
    { kind = "grain", words = { "pasta", "noodle", "macaroni", "spaghetti" }, games = { "measure" } },
}

local function ruleFits(r, item, k, lowShort, ft)
    if r.kind ~= k then return false end
    if r.whole then return R.WHOLE_FISH[typeOf(item)] == true end
    if r.foodtype then return ft == r.foodtype end
    if not r.words then return true end
    for _, w in ipairs(r.words) do if lowShort:find(w, 1, true) then return true end end
    return false
end

function R.gamesFor(item)
    local k = R.kindOf(item)
    local list = k and R.KIND_GAMES[k] or {}
    if k then
        local t = typeOf(item)
        local lowShort = (t:match("%.(.+)$") or t):lower()
        local ft = tostring(call(item, "getFoodType") or "")
        for _, r in ipairs(R.GAME_RULES) do
            if ruleFits(r, item, k, lowShort, ft) then list = r.games break end
        end
    end
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
-- GTP 1.3.0 (#9): a rotten food brings nothing any more
function R.isRotten(item) return call(item, "isRotten") == true end
function R.scoreOf(item)
    if R.isRotten(item) then return 0 end
    local d = R.dishOf(item)
    if d then return tonumber(d.avg) or 0 end
    local p = R.prepOf(item)
    -- the word decides (so a sandbox change counts for food prepared before)
    if p then return R.wordScore(p.w) end
    return 0
end

-- GTP 1.3.0 (#5): oil, sauces, ketchup ... (vanilla MINOR_INGREDIENT) do not
-- count, like spices
function R.isMinor(item)
    if not (ItemTag and ItemTag.MINOR_INGREDIENT and item and item.hasTag) then return false end
    local ok, v = pcall(item.hasTag, item, ItemTag.MINOR_INGREDIENT)
    return ok and v == true
end
-- does it count as one ingredient (a food that is not a spice or a minor one)?
function R.counts(item)
    return isFood(item) and call(item, "isSpice") ~= true and not R.isMinor(item)
end

-- GTP 1.3.0 (#3 / #4): how much an item weighs in a dish = the hunger it
-- brings (x100); never below 1
function R.weightOf(item, hunger)
    local h = hunger or math.abs(tonumber(call(item, "getHungChange")) or 0)
    return math.max(1, h * 100)
end

function R.tierOf(avg)
    avg = tonumber(avg) or 0
    if avg < 0 then return -1 end
    for i = 3, 1, -1 do if avg >= R.tierCut(i) then return i end end
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
    if R.WORD_SCORE[word] == nil or word == "Off" then log("prep from %s: unknown result %s -- rejected", who, word); return false, "word" end
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
    -- GTP 1.3.0 (#6): with the minigames off in the sandbox it counts 0 ("Off")
    if K.minigamesOn and not K.minigamesOn() then word = "Off" end
    md.HARMONIE_Prep = { w = word, p = pid, s = R.wordScore(word) }
    local xp = ((K.PROCS[pid] or {}).xp or 1) * (R.XP_MUL[word] or 1)
    if K.giveXp then K.giveXp(player, xp) end
    count("prep")
    dlog("%s prepared %s (id %s) with %s: %s (%+.2f)", who, typeOf(item), tostring(args.id), pid, word, R.wordScore(word))
    sendSet(player, item, "prep")
    return true
end

-- GTP 1.4.0 (#14): a Poor or Missed preparation can be washed off ONCE
-- and prepared again
function R.canRedo(item)
    local p = R.prepOf(item)
    if not p or (p.w ~= "Bad" and p.w ~= "Miss") then return false end
    local md = mdOf(item)
    return not (md and md.HARMONIE_PrepRedo)
end
function R.serveRedo(player, args)
    args = type(args) == "table" and args or {}
    local who = nameOf(player)
    local t = nowMs()
    if t - (R.lastPrep[who] or 0) < 800 then log("redo from %s: too fast -- rejected", who); count("refused"); return false, "fast" end
    local item = findById(player, args.id)
    if not item then log("redo from %s: item id %s not in their inventory -- rejected", who, tostring(args.id)); count("refused"); return false, "missing" end
    if not R.canRedo(item) then log("redo from %s on %s: not a Poor / Missed preparation, or already redone -- rejected", who, typeOf(item)); count("refused"); return false, "noRedo" end
    R.lastPrep[who] = t
    local md = call(item, "getModData")
    md.HARMONIE_Prep = nil
    md.HARMONIE_PrepRedo = true
    dlog("%s washed off the preparation of %s (id %s) -- can prepare it again once", who, typeOf(item), tostring(args.id))
    sendSet(player, item, "redo")
    return true
end

-- GTP 1.4.0 (#16): some foods are harder to work than others (added to the
-- minigame difficulty, 0..1 scale)
function R.hardness(item)
    local k = R.kindOf(item)
    local h = 0
    if k == "meat" or k == "poultry" then h = h + 0.08 end
    if k == "fish" then h = h + (R.WHOLE_FISH[typeOf(item)] and 0.12 or 0.06) end
    if k == "herb" or k == "bean" or k == "grain" or k == "flour" then h = h - 0.05 end
    local okW, wgt = pcall(function() return item:getActualWeight() end)
    if okW and tonumber(wgt) and tonumber(wgt) > 1.0 then h = h + 0.05 end
    return h
end

-- ------------------------------------------------------------ dish scores
-- the evolved-recipe family of a vanilla recipe object (for the buff kind)
local function famOfRecipe(recipe)
    if not recipe or not K.familyOf then return nil end
    local ok, f = pcall(K.familyOf, recipe)
    return ok and f or nil
end

-- GTP 1.7.0 (#38): a dish with many kinds of food (vegetable, meat, herb...)
-- gets a bonus on top of its average: +1 step at 3 kinds, +2 steps at 4 or
-- more (step = sandbox CookVarietyBonus, default 0.25); never for a dish
-- whose own average is below 0
function R.varietyBonus(kinds)
    local n = 0
    for _ in pairs(kinds or {}) do n = n + 1 end
    local step = R.sv("CookVarietyBonus", 0.25)
    if n >= 4 then return step * 2, n end
    if n >= 3 then return step, n end
    return 0, n
end
local function addKind(kinds, item)
    local d = R.dishOf(item)
    if d and type(d.kinds) == "table" then
        for k in pairs(d.kinds) do kinds[k] = true end
        return
    end
    local k = R.kindOf(item)
    if k then kinds[k] = true end
end
local function finishDish(t)
    local base = t.w > 0 and (t.sum / t.w) or 0
    local bonus = 0
    if base >= 0 then bonus = R.varietyBonus(t.kinds) end
    t.base, t.bonus, t.avg = base, bonus, base + bonus
    return t
end
R.finishDish = finishDish

-- the dish score after one more ingredient (display only: the Cooking tab
-- and the right-click recipe menu). d = the base's dish record or nil; use
-- = vanilla's evolved use of the ingredient (hunger points) or nil
function R.previewDish(d, base, it, use)
    local sum, wt
    local kinds = {}
    local function add(x)
        local xd = R.dishOf(x)
        if xd and type(xd.kinds) == "table" then for k in pairs(xd.kinds) do kinds[k] = true end return end
        local k = R.kindOf(x)
        if k then kinds[k] = true end
    end
    if d then
        sum = tonumber(d.sum) or 0
        wt = tonumber(d.w) or tonumber(d.n) or 0
        for k in pairs(type(d.kinds) == "table" and d.kinds or {}) do kinds[k] = true end
    else
        sum, wt = 0, 0
        if R.counts(base) then local bw = R.weightOf(base); sum, wt = R.scoreOf(base) * bw, bw; add(base) end
    end
    if R.counts(it) then
        local iw = math.max(1, tonumber(use) or R.weightOf(it))
        sum, wt = sum + R.scoreOf(it) * iw, wt + iw
        add(it)
    end
    return finishDish({ sum = sum, w = wt, kinds = kinds }).avg
end

-- 1) evolved recipes: one ingredient goes in (vanilla ISAddItemInRecipe)
function R.onEvolvedAdd(character, recipe, baseBefore, used, baseAfter, usedHungerBefore)
    if not baseAfter then return end
    local d = R.dishOf(baseBefore)
    local sum, w, n
    local kinds = {}
    if d and type(d.kinds) == "table" then for k in pairs(d.kinds) do kinds[k] = true end end
    if d then
        -- (a dish from before 1.3.0 has no weight: one per ingredient)
        sum, n = tonumber(d.sum) or 0, tonumber(d.n) or 0
        w = tonumber(d.w) or n
    else
        -- the first addition: the base counts when it is a food (bread
        -- slices, a pie crust), never when it is a pot, pan or bowl
        sum, w, n = 0, 0, 0
        if R.counts(baseBefore) then
            local bw = R.weightOf(baseBefore)
            sum, w, n = R.scoreOf(baseBefore) * bw, bw, 1
            addKind(kinds, baseBefore)
        end
    end
    local usedScore, usedW = 0, 0
    if used and R.counts(used) then
        usedScore = R.scoreOf(used)
        -- the part vanilla really took: hunger before - after (all of it when the item is gone)
        local after = math.abs(tonumber(call(used, "getHungChange")) or 0)
        local before = tonumber(usedHungerBefore) or after
        local took = before - after
        usedW = R.weightOf(used, (took > 0.0005) and took or before)
        sum, w, n = sum + usedScore * usedW, w + usedW, n + 1
        addKind(kinds, used)
    end
    local md = call(baseAfter, "getModData")
    if not md then logOnce("evonomd", "dish %s has no modData -- score not kept", typeOf(baseAfter)); return end
    local lvl = K.level and K.level(character) or 0
    local fam = famOfRecipe(recipe) or (d and d.fam)
    -- #39: the cook (the last one who added) gets a little XP when others eat it
    -- GTP 1.8.0: the cook's note stays while the same cook goes on
    local note = (d and d.chef == nameOf(character) and type(d.note) == "table") and d.note or nil
    md.HARMONIE_Dish = finishDish({ sum = sum, w = w, n = n, kinds = kinds, fam = fam, lvl = math.max(lvl, tonumber(d and d.lvl) or 0),
        chef = nameOf(character), note = note })
    count("add")
    dlog("%s added %s (%+.2f x %.1f) to %s: dish score %.2f over %d (%s)", nameOf(character), used and typeOf(used) or "?", usedScore, usedW, typeOf(baseAfter),
        md.HARMONIE_Dish.avg, n, tostring(fam))
    sendSet(character, baseAfter, "dish")
end

-- 2) crafting-window recipes: what was used up -> what came out
function R.onCraft(character, recipeName, consumed, created)
    local sum, w, n, any, fam, lvl = 0, 0, 0, false, nil, 0
    local kinds, note = {}, nil
    for i = 0, (consumed and consumed:size() or 0) - 1 do
        local it = consumed:get(i)
        if R.counts(it) then
            local iw = R.weightOf(it)
            n, w = n + 1, w + iw
            sum = sum + R.scoreOf(it) * iw
            addKind(kinds, it)
            local d = R.dishOf(it)
            if d then fam = fam or d.fam; lvl = math.max(lvl, tonumber(d.lvl) or 0) end
            -- GTP 1.8.0: the crafter's own note on a dish that went in comes along
            if d and type(d.note) == "table" and d.note.by == nameOf(character) then note = note or d.note end
            if d or R.prepOf(it) then any = true end
        end
    end
    -- nothing prepared went in: the result stays plain vanilla
    if not any or n == 0 then return end
    lvl = math.max(lvl, K.level and K.level(character) or 0)
    local proto = finishDish({ sum = sum, w = w, n = n, kinds = kinds, fam = fam, lvl = 0 })
    local avg = proto.avg
    local wrote = 0
    for i = 0, (created and created:size() or 0) - 1 do
        local out = created:get(i)
        if isFood(out) then
            local md = call(out, "getModData")
            if md then
                md.HARMONIE_Dish = { sum = sum, w = w, n = n, base = proto.base, bonus = proto.bonus, avg = avg, kinds = kinds, fam = fam, lvl = lvl,
                    chef = nameOf(character), note = note }
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
            local hBefore = used and math.abs(tonumber(call(used, "getHungChange")) or 0) or 0
            local result = orig(self)
            if not isClientSide() then
                local ok, err = pcall(R.onEvolvedAdd, self.character, recipe, before, used, self.baseItem, hBefore)
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
        if command == "redo" then
            local ok, why = R.serveRedo(player, args)
            if not ok and sendServerCommand then
                pcall(sendServerCommand, player, R.NET, "refused", { id = type(args) == "table" and args.id or nil, why = why })
            end
        elseif command == "begin" then
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
    if args.what == "redo" then
        md.HARMONIE_Prep = nil
        md.HARMONIE_PrepRedo = true
    elseif args.prep then md.HARMONIE_Prep = args.prep end
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

-- client side: wash off a Poor / Missed preparation (SP: done at once)
function R.requestRedo(player, item)
    local args = { id = call(item, "getID") }
    if isClientSide() then
        sendClientCommand(player, R.NET, "redo", args)
        return true
    end
    local ok, why = R.serveRedo(player, args)
    if not ok and R.onRefused then pcall(R.onRefused, { id = args.id, why = why }) end
    if ok and R.onSet then pcall(R.onSet, { id = args.id, what = "redo" }, item) end
    return ok
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

-- GTP 1.7.0 (#37): admin test ops (the hub's flask button; the server runs
-- them only for an admin -- HARMONIE_AdminTest checks that)
local AT = HARMONIE_AdminTest
if AT and AT.serverOp then
    AT.serverOp("gtp_prepAll", function(player, args)
        local inv = call(player, "getInventory")
        local items = inv and call(inv, "getItems")
        local n = 0
        for i = 0, (items and items:size() or 0) - 1 do
            local it = items:get(i)
            if R.whyNot(it) == nil then
                local games = R.gamesFor(it)
                local md = call(it, "getModData")
                if md and games[1] then
                    md.HARMONIE_Prep = { w = "Excellent", p = games[1], s = R.wordScore("Excellent") }
                    sendSet(player, it, "prep")
                    n = n + 1
                end
            end
        end
        log("admin test: %d food(s) in %s's inventory set to Excellent", n, nameOf(player))
    end)
    AT.serverOp("gtp_buff", function(player, args)
        local tier = math.max(1, math.min(3, tonumber(type(args) == "table" and args.tier) or 3))
        local avg = ({ 0.6, 1.1, 2.0 })[tier]
        if K.grantDish then K.grantDish(player, { avg = avg, fam = "stew", lvl = 10 }, nil, 1) end
        log("admin test: %s given a level %d dish buff", nameOf(player), tier)
    end)
    AT.serverOp("gtp_clearBuff", function(player)
        if K.clearBuff then K.clearBuff(player, "admin test") end
    end)
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

log("loaded: %d food kinds, scores Excellent %+.1f / Good %+.1f / Bad %+.1f / Miss %+.1f (sandbox at load; read live)", (function() local c = 0 for _ in pairs(R.KIND_GAMES) do c = c + 1 end return c end)(),
    R.wordScore("Excellent"), R.wordScore("Good"), R.wordScore("Bad"), R.wordScore("Miss"))

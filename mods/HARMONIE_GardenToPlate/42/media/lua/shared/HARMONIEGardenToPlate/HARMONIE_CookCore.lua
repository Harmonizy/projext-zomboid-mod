--[[
    HARMONIE - From Garden to Plate: the Cooking tab's shared helpers.

    GTP 1.1.0 (owner 2026-11-19): our own dishes are gone -- cooking is
    vanilla's (evolved recipes, craftRecipes of category Cooking) and our
    minigames prepare ingredients (HARMONIE_Prep.lua: scores, dish averages,
    the MP-safe server writes). What is left here: what is at hand
    (K.containers / K.scan, room boxes through HARMONIE_Reach), the tools a
    minigame uses (K.findTool), heat sources, how hard a minigame is
    (K.difficulty / K.levelEase), vanilla Cooking XP (K.giveXp) and the
    evolved-recipe families (K.familyOf, for the buff kind).
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_FoodVitaminDatabase"
require "HARMONIEGardenToPlate/HARMONIE_CookData"
require "HARMONIEGardenToPlate/HARMONIE_CookVanilla"
require "HARMONIEGardenToPlate/HARMONIE_CookTagItems"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.Cook = HARMONIE_GTP.Cook or {}
local K = HARMONIE_GTP.Cook

K.NET = "HARMONIE_GTP_Cook"

local function log(...) if HARMONIE_GTP.Log then HARMONIE_GTP.Log("Cook", ...) end end
local function logOnce(key, ...) if HARMONIE_GTP.LogOnce then HARMONIE_GTP.LogOnce("Cook:" .. key, "Cook", ...) end end
K.log, K.logOnce = log, logOnce

local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
K.call = call

function K.typeOf(item) return tostring(call(item, "getFullType") or "?") end

-- -------------------------------------------------------------- sandbox
function K.sv(key, default)
    local t = SandboxVars and SandboxVars.HARMONIE_GardenToPlate
    local v = t and t[key]
    if v == nil then return default end
    return v
end
function K.minigamesOn() return K.sv("CookMinigames", true) ~= false end
function K.qualityScale() return math.max(0, tonumber(K.sv("CookQualityEffect", 1)) or 1) end
function K.xpScale() return math.max(0, tonumber(K.sv("CookXPMultiplier", 1)) or 1) end

function K.level(player)
    local ok, v = pcall(function() return player:getPerkLevel(Perks.Cooking) end)
    return ok and (tonumber(v) or 0) or 0
end

-- -------------------------------------------------------------- recipes
local function norm(s)
    return (tostring(s or ""):lower():gsub("[%s%-_]", ""))
end
K.norm = norm

function K.recipeName(recipe)
    for _, m in ipairs({ "getName", "getOriginalname", "getUntranslatedName" }) do
        local v = call(recipe, m)
        if v and v ~= "" then return tostring(v) end
    end
    return "?"
end

local function shortType(t)
    t = tostring(t or "")
    return t:match("%.([^%.]+)$") or t
end

-- which of our families a vanilla evolved recipe is (by name, else by the
-- dish item it makes)
function K.familyOf(recipe)
    if not recipe then return nil end
    local names = {}
    for _, m in ipairs({ "getName", "getOriginalname", "getUntranslatedName" }) do
        local v = call(recipe, m)
        if v then names[#names + 1] = norm(v) end
    end
    local result = norm(shortType(call(recipe, "getResultItem")))
    for fam, def in pairs(K.FAMILIES) do
        for _, n in ipairs(def.names) do
            for _, have in ipairs(names) do if have == norm(n) then return fam end end
        end
    end
    for fam, def in pairs(K.FAMILIES) do
        for _, r in ipairs(def.results) do if result == norm(r) then return fam end end
    end
    return nil
end

-- vanilla's script tables (HARMONIE_CookVanilla.lua, from evolvedrecipes.txt
-- and every item's EvolvedRecipe key), for when no recipe object is at hand
local function vanilla() return K.VANILLA or { templates = {}, cooked = {}, recipes = {} } end

-- does the item list this family's template at all? (nil when unknown)
function K.inTemplate(famId, fullType)
    local fam = K.FAMILIES[famId]
    local list = fam and vanilla().templates[fam.template]
    if not list then return nil end
    if list[fullType] ~= nil then return true end
    -- a modded food is not in vanilla's table: only the recipe object knows
    if tostring(fullType):sub(1, 5) ~= "Base." then return nil end
    return false
end

-- vanilla "|Cooked": the item only goes in once it is cooked
function K.needsCooking(famId, fullType)
    local fam = K.FAMILIES[famId]
    local list = fam and vanilla().cooked[fam.template]
    return list ~= nil and list[fullType] == true
end

-- the vanilla recipes of a family (from its names) -> list of rows
function K.vanillaRecipes(famId)
    local fam = K.FAMILIES[famId]
    local out = {}
    if not fam then return out end
    local rec = vanilla().recipes
    for _, n in ipairs(fam.names) do
        if rec[n] then out[#out + 1] = rec[n] end
    end
    return out
end

-- what a family starts from: the fresh bases (a pot, bread slices, ...),
-- or, for a dish vanilla starts with a craft (omelette, pizza, hotdog),
-- that started dish item -> { types = {...}, water = bool, max = n }
function K.baseNeed(famId)
    local fresh, started, seen = {}, {}, {}
    local water, max = false, nil
    for _, r in ipairs(K.vanillaRecipes(famId)) do
        local list = (r.base ~= r.result) and fresh or started
        if not seen[r.base] then seen[r.base] = true; list[#list + 1] = r.base end
        if r.water and r.base ~= r.result then water = true end
        if (r.max or 0) > 0 then max = math.max(max or 0, r.max) end
    end
    return { types = #fresh > 0 and fresh or started, water = water, max = max }
end

function K.maxItems(recipe)
    local v = tonumber(call(recipe, "getMaxItems"))
    if v and v > 0 then return v end
    return nil
end

-- vanilla: may this item go into this recipe? (nil when unknown)
function K.allowed(recipe, item)
    if not recipe or not item then return nil end
    local ok, ir = pcall(function() return recipe:getItemRecipe(item) end)
    if not ok then return nil end
    return ir ~= nil
end

-- the item's evolved-recipe use in hunger points (vanilla: /100 = hunger)
function K.useOf(recipe, item)
    if not recipe or not item then return nil end
    local ok, ir = pcall(function() return recipe:getItemRecipe(item) end)
    if not ok or not ir then return nil end
    local okU, u = pcall(function() return ir:getUse() end)
    u = okU and tonumber(u) or nil
    if u and u > 0 then return u end
    return nil
end

local function isFood(item)
    local ok, v = pcall(function() return instanceof(item, "Food") end)
    return ok and v == true
end
K.isFood = isFood

function K.isSpice(item) return call(item, "isSpice") == true end
function K.isRotten(item) return call(item, "isRotten") == true end
function K.isCooked(item) return call(item, "isCooked") == true end
function K.hunger(item) return math.abs(tonumber(call(item, "getHungerChange")) or 0) end

-- vanilla's own portion rule (see the header): hunger the dish gets from
-- one addition, and hunger the ingredient loses
function K.portion(recipe, item, level, remaining)
    remaining = remaining or K.hunger(item)
    local use = K.useOf(recipe, item)
    if not use or remaining <= 0 then return remaining, remaining, true end
    local nominal = use / 100
    local mult = math.max(0, 1 - 0.03 * (level or 0))
    if K.isCooked(item) then mult = mult / 1.3 end
    if remaining <= nominal or K.isRotten(item) then return math.min(nominal, remaining), remaining, true end
    local real = nominal * mult
    return nominal, real, remaining - real <= 0.02
end

-- how many additions one item can still give (vanilla rule, simulated)
function K.additionsFrom(recipe, item, level)
    if not isFood(item) or K.isSpice(item) then return 1 end
    local remaining = K.hunger(item)
    local use = K.useOf(recipe, item)
    if not use or remaining <= 0 then return 1 end
    local nominal = use / 100
    local mult = math.max(0, 1 - 0.03 * (level or 0))
    if K.isCooked(item) then mult = mult / 1.3 end
    if K.isRotten(item) then return 1 end
    local n = 0
    while n < 20 do
        n = n + 1
        if remaining < nominal then break end
        local real = nominal * mult
        remaining = remaining - real
        if remaining <= 0.0200001 or real <= 0 then break end
    end
    return math.max(1, n)
end

-- -------------------------------------------------------------- reach
-- the containers vanilla offers for crafting (client); the inventory only
-- where that helper is missing (server / tests)
-- 1.0.0 (owner, 2026-11-12: "หาของได้จากตัวเอง กระเป๋า และกล่องหรือตู้รอบตัว"):
-- plus every box / cupboard / floor bag in the same room (HARMONIE_Reach,
-- the hub's shared rule); items from there are walked to and moved in
-- before use (CookFlow F.bring)
local function addReach(player, list)
    if not (HARMONIE_Reach and HARMONIE_Reach.containers and list and list.add) then return list end
    local seen = {}
    for i = 0, list:size() - 1 do seen[list:get(i)] = true end
    local ok, err = pcall(function()
        for _, e in ipairs(HARMONIE_Reach.containers(player)) do
            if not seen[e.c] then seen[e.c] = true; list:add(e.c) end
        end
    end)
    if not ok then logOnce("reachfail", "room-wide containers FAILED: %s", tostring(err)) end
    return list
end

function K.containers(player)
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.getContainers then
        local ok, list = pcall(ISInventoryPaneContextMenu.getContainers, player)
        if ok and list then return addReach(player, list) end
        logOnce("nocont", "getContainers FAILED (%s) -- inventory only", tostring(list))
    end
    local inv = call(player, "getInventory")
    if ArrayList and ArrayList.new then
        local l = ArrayList.new()
        if inv then l:add(inv) end
        return l
    end
    return { inv, size = function() return 1 end, get = function(_, i) return inv end }
end

local function eachItem(containers, fn)
    local n = containers and containers.size and containers:size() or 0
    for i = 0, n - 1 do
        local c = containers:get(i)
        local items = call(c, "getItems")
        local m = items and items.size and items:size() or 0
        for j = 0, m - 1 do
            local it = items:get(j)
            if it and fn(it, c) == false then return end
        end
    end
end
K.eachItem = eachItem

K.SCAN_EVERY_MS = 1500
K.MAX_SCAN = 600
local scanCache = setmetatable({}, { __mode = "k" })

local function nowMs() return getTimestampMs and getTimestampMs() or 0 end

-- what is at hand: items by type, tools, and the vanilla recipes each
-- family can use right now (with their base item)
function K.scan(player, force)
    if not player then return nil end
    local c = scanCache[player]
    if c and not force and nowMs() - c.at < K.SCAN_EVERY_MS then return c end
    local containers = K.containers(player)
    local inv = call(player, "getInventory")
    local s = { at = nowMs(), containers = containers, byType = {}, byFood = {}, tagged = {}, families = {}, count = 0, recipesSeen = {} }
    eachItem(containers, function(it, cont)
        s.count = s.count + 1
        if s.count > K.MAX_SCAN then return false end
        local t = K.typeOf(it)
        local list = s.byType[t]
        if not list then list = {}; s.byType[t] = list end
        list[#list + 1] = it
        -- food kinds (vanilla FoodType) for the slots that take any of a kind
        if #list == 1 and isFood(it) then
            local ft = call(it, "getFoodType")
            if ft and ft ~= "" then
                ft = tostring(ft)
                s.byFood[ft] = s.byFood[ft] or {}
                s.byFood[ft][#s.byFood[ft] + 1] = t
            end
        end
        -- which evolved recipes can this item be the base of?
        if RecipeManager and RecipeManager.getEvolvedRecipe then
            local ok, recipes = pcall(RecipeManager.getEvolvedRecipe, it, player, containers, false)
            if ok and recipes and recipes.size then
                for i = 0, recipes:size() - 1 do
                    local r = recipes:get(i)
                    local fam = K.familyOf(r)
                    local rn = K.recipeName(r)
                    if not s.recipesSeen[rn] then s.recipesSeen[rn] = fam or "-" end
                    if fam then
                        local partial = shortType(call(r, "getResultItem")) == shortType(t)
                        local cur = s.families[fam]
                        local inMain = cont == inv
                        -- a fresh base beats a dish already started; the
                        -- player's own inventory beats a nearby crate
                        local better = not cur or (cur.partial and not partial)
                            or (cur.partial == partial and inMain and not cur.inMain)
                        if better then s.families[fam] = { recipe = r, base = it, partial = partial, inMain = inMain } end
                    end
                end
            end
        end
    end)
    if s.count > K.MAX_SCAN then logOnce("scancap", "more than %d items in reach -- only the first %d are looked at", K.MAX_SCAN, K.MAX_SCAN) end
    -- the first scan names every vanilla evolved recipe it met, and which
    -- of our families each one is ("-" = none of ours)
    local key = {}
    for rn, fam in pairs(s.recipesSeen) do key[#key + 1] = rn .. "=" .. fam end
    table.sort(key)
    local sig = table.concat(key, ", ")
    if sig ~= "" and sig ~= K.lastRecipesLog then
        K.lastRecipesLog = sig
        log("vanilla evolved recipes in reach: %s", sig)
    end
    local okH, heat = pcall(K.findHeat, player)
    if not okH then logOnce("heatfail", "heat source check FAILED: %s -- hot steps count as having no heat", tostring(heat)); heat = nil end
    s.heat = heat
    scanCache[player] = s
    return s
end

-- ---------------------------------------------------------------- heat
-- 0.13.2: a stove, oven, fireplace, grill, campfire or cooking pit within K.HEAT_RANGE
-- tiles on the player's floor (lit or not -- the step only needs it there).
-- Several checks, because a B42 campfire is not a class of its own: the
-- object's Java class, its container's type, its sprite name.
K.HEAT_RANGE = 2
K.HEAT_CLASSES = { "IsoStove", "IsoFireplace", "IsoBarbecue" }
K.HEAT_CONTAINERS = { stove = true, fireplace = true, barbecue = true, woodstove = true, campfire = true, grill = true }
-- sprite names: exact ones (camping_01 also holds tents, wells and
-- composters -- vanilla entity_campfire.txt is camping_01_6, its cooking
-- pits camping_03_16 / _19), then words in the name
K.HEAT_SPRITE_NAMES = { camping_01_4 = true, camping_01_5 = true, camping_01_6 = true, camping_01_7 = true,
    camping_03_16 = true, camping_03_19 = true }
K.HEAT_SPRITES = { "campfire", "fireplace", "stove", "oven", "barbecue", "bbq", "cooking_pit" }
K.NOT_HEAT_CONTAINERS = { microwave = true, fridge = true, freezer = true }

function K.heatKind(obj)
    if not obj then return nil end
    local cont = call(obj, "getContainer")
    local ct = cont and tostring(call(cont, "getType") or "") or ""
    if K.NOT_HEAT_CONTAINERS[ct] then return nil end
    if instanceof then
        for _, cls in ipairs(K.HEAT_CLASSES) do
            local ok, is = pcall(instanceof, obj, cls)
            if ok and is then return cls end
        end
    end
    if K.HEAT_CONTAINERS[ct] then return "container:" .. ct end
    local sp = call(obj, "getSprite")
    local name = sp and tostring(call(sp, "getName") or "") or ""
    name = name:lower()
    if K.HEAT_SPRITE_NAMES[name] then return "sprite:" .. name end
    for _, key in ipairs(K.HEAT_SPRITES) do
        if name:find(key, 1, true) then return "sprite:" .. name end
    end
    return nil
end

function K.findHeat(player)
    local sq = call(player, "getCurrentSquare")
    local cell = getCell and getCell()
    if not sq or not cell then return nil end
    local px, py, pz = call(sq, "getX"), call(sq, "getY"), call(sq, "getZ")
    if not px then return nil end
    for dx = -K.HEAT_RANGE, K.HEAT_RANGE do
        for dy = -K.HEAT_RANGE, K.HEAT_RANGE do
            local s2 = cell:getGridSquare(px + dx, py + dy, pz)
            local objs = s2 and call(s2, "getObjects")
            for i = 0, (objs and objs:size() or 0) - 1 do
                local obj = objs:get(i)
                local kind = K.heatKind(obj)
                if kind then
                    if kind ~= K.lastHeatKind then
                        K.lastHeatKind = kind
                        log("heat source in reach: %s", kind)
                    end
                    return obj
                end
            end
        end
    end
    if K.lastHeatKind ~= false then
        K.lastHeatKind = false
        log("no stove / fire / grill within %d tiles", K.HEAT_RANGE)
    end
    return nil
end
function K.forget(player) if player then scanCache[player] = nil else scanCache = setmetatable({}, { __mode = "k" }) end end

-- every item at hand with a vanilla tag (worked out once per scan).
-- 0.13.5: by the item TYPES that carry the tag (HARMONIE_CookTagItems.lua,
-- generated from vanilla's scripts) -- never item:hasTag("base:x"): in
-- B42 hasTag takes an ItemTag object, a string throws, and the game logs
-- that exception even inside pcall, every frame (console.txt 2026-10-09).
local function tagged(scan, tag)
    local list = scan.tagged[tag]
    if list then return list end
    list = {}
    local types = K.TAG_ITEMS and K.TAG_ITEMS[tag]
    if not types then
        logOnce("notag:" .. tostring(tag), "tag %s has no item list (HARMONIE_CookTagItems.lua) -- that tool kind is matched by type only", tostring(tag))
        types = {}
    end
    for _, t in ipairs(types) do
        for _, it in ipairs(scan.byType[t] or {}) do list[#list + 1] = it end
    end
    scan.tagged[tag] = list
    return list
end

local function usable(it) return it and call(it, "isBroken") ~= true end

-- the best item of a tool group at hand -> item, grade ("best" / "ok" /
-- "makeshift"), or nil, "bare" when hands will do, or nil
function K.findTool(scan, group)
    local def = K.TOOLS[group]
    if not def or not scan then return nil end
    for _, grade in ipairs(K.TOOL_GRADES) do
        local set = def[grade]
        if set then
            for _, t in ipairs(set.types or {}) do
                for _, it in ipairs(scan.byType[t] or {}) do
                    if usable(it) then return it, grade end
                end
            end
            for _, tag in ipairs(set.tags or {}) do
                for _, it in ipairs(tagged(scan, tag)) do
                    if usable(it) then return it, grade end
                end
            end
        end
    end
    if def.bare then return nil, "bare" end
    return nil
end

function K.isPoison(item)
    if call(item, "isPoison") == true then return true end
    return (tonumber(call(item, "getPoisonPower")) or 0) > 0
end

-- how hard a step is for this player: 0 (easy) .. 1 (hard)
-- 0.13.17 (owner: "การมีเลเวล cooking สูงให้มีผลกับความยากง่ายของเกมเพิ่มขึ้นอย่างมี
-- นัยยะ"): 0.85 at level 0 down to 0.15 at level 10; below the step's or the
-- dish's level 0.06 harder per level missing
function K.difficulty(player, pp, dish)
    local lvl = K.level(player)
    local d = 0.85 - lvl * 0.07
    local want = math.max((pp.proc and pp.proc.level) or 0, (dish and dish.level) or 0)
    local below = math.max(0, want - lvl)
    d = d + below * 0.06
    -- a good tool keeps it as it is, an ok one a little harder, a makeshift
    -- one or bare hands clearly harder
    for _, t in ipairs(pp.tools or {}) do d = d + (K.GRADE_COST[t.grade] or 0) end
    for _, h in ipairs(pp.help or {}) do if h.item then d = d - 0.1 end end
    return math.max(0.05, math.min(1, d))
end
K.GRADE_COST = { best = 0, ok = 0.06, makeshift = 0.15, bare = 0.2 }

-- 0.13.17: the Cooking level also makes a slip cost less quality (-6% per
-- level, down to 40% of it at 10) and gives more time (+6% per level)
-- 0.13.18 (owner, 2026-11-07: "เพิ่มเวลาทำอาหารให้นานขึ้น 2 เท่า มันหมดเวลาเร็วไป"):
-- every minigame's time limit, times this (sandbox CookMinigameTime, default 2)
function K.minigameTime() return math.max(0.5, math.min(5, tonumber(K.sv("CookMinigameTime", 2.0)) or 2.0)) end

function K.levelEase(lvl)
    lvl = math.max(0, math.min(10, tonumber(lvl) or 0))
    return { slip = math.max(0.4, 1 - 0.06 * lvl), time = 1 + 0.06 * lvl }
end

-- what the minigame draws at the mouse: the real item in use
local function firstAdd(plan, spice)
    for _, a in ipairs(plan and plan.adds or {}) do
        if (a.spice == true) == spice then return a.item end
    end
    return nil
end
function K.cursorItem(plan, pp)
    local c = pp and pp.proc and pp.proc.cursor
    if c == "tool" then return pp.tools[1] and pp.tools[1].item or nil end
    if c == "ingredient" then return firstAdd(plan, false) end
    if c == "spice" then return firstAdd(plan, true) or firstAdd(plan, false) end
    if c == "base" then return plan and plan.base end
    return nil
end
function K.cursorTexture(plan, pp)
    local it = K.cursorItem(plan, pp)
    return it and call(it, "getTexture") or nil
end

-- vanilla Cooking XP
function K.giveXp(player, amount)
    amount = (tonumber(amount) or 0) * K.xpScale()
    if amount <= 0 then return end
    if addXp then
        local ok, err = pcall(addXp, player, Perks.Cooking, amount)
        if ok then log("Cooking XP +%.1f (addXp)", amount); return end
        log("addXp FAILED: %s -- trying getXp():AddXP", tostring(err))
    end
    local ok2, err2 = pcall(function() player:getXp():AddXP(Perks.Cooking, amount) end)
    log("Cooking XP +%.1f (AddXP %s)", amount, ok2 and "ok" or ("FAILED: " .. tostring(err2)))
end

-- -------------------------------------------------------------- network
local function findInInventory(player, id)
    local inv = call(player, "getInventory")
    if not inv or not id then return nil end
    for _, m in ipairs({ "getItemWithIDRecursiv", "getItemById", "getItemWithID" }) do
        if inv[m] then
            local ok, it = pcall(inv[m], inv, id)
            if ok and it then return it end
        end
    end
    return nil
end
K.findInInventory = findInInventory

log("cooking core loaded: %d steps, %d dish kinds", #K.PROC_ORDER, (function() local n = 0 for _ in pairs(K.FAMILIES) do n = n + 1 end return n end)())

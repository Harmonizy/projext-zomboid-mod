--[[
    HARMONIE - The Way To Attack: the "Bags" tab (TWA 1.1.0, owner 2026-11-20).

    The 26 bags of Tomb's Wardrobe - Alternative (TombWardrobeALT, Workshop
    3616536783) never turn up in the world (HARMONIE_LWS_Tomb removes them
    from loot and zombies); they are crafted here instead, in 9 recipes -- one
    per bag, made as its "Loose" type: Tomb's own right-click switches it to
    tight / satchel / low-slung afterwards (its ClothingItemExtra).

      * start from raw materials (owner choice): leather hides, denim, leather
        strips, with a buckle (or a tarp) as the second item;
      * steps are tailoring ones, every one with its minigame (never skipped):
        the new "Sew the bag" (SewBag, the suture minigame, needle + thread,
        Tailoring 2) and the existing WrapCloth / WrapLeather / StringSinew;
      * the overall quality changes the bag's weight reduction (owner
        choice): Excellent +5, Good 0, Bad -5 (0..100), kept in
        modData.TWA_BagWR and put back on the item whenever its carrier is
        checked (an item's own weight reduction is not saved by the game);
      * an unfinished bag (Incomplete) holds nothing (capacity 0) until it is
        finished -- no free container from half a craft.
    Without Tomb's mod the recipes stay hidden (their result item does not
    exist) and the tab is not drawn.
]]--

require "HARMONIE_TWA_RecipeData"
require "HARMONIE_TWA_Procedures"

TWABags = TWABags or {}
local B = TWABags
local log = function(fmt, ...) if TWALog then TWALog("Bags", fmt, ...) end end

B.CATEGORY = "Bag"
local T = "TombAlternative."
local LEATHER_S, LEATHER_M, LEATHER_L = "Base.Leather_Crude_Small_Tan", "Base.Leather_Crude_Medium_Tan", "Base.Leather_Crude_Large_Tan"
local BUCKLE = "Base.Buckle"

-- ------------------------------------------------------------ the new step
-- time = skill level x 10 + 10 (the rule every TWA procedure follows)
TWAProcedures.List.SewBag = {
    category = "Tailoring", nameKey = "IGUI_TWA_Proc_SewBag", icon = "Needle",
    tool = { kind = "type", value = "Base.Needle" },
    consumes = { { itemTypes = { "Base.Thread", "Base.Thread_Sinew", "Base.Thread_Aramid" }, qty = 1 } },
    skill = "Tailoring:2", time = 30, sound = "TWA_Craft",
}
local hasCat = false
for _, c in ipairs(TWAProcedures.Categories) do if c.key == "Tailoring" then hasCat = true end end
if not hasCat then
    TWAProcedures.Categories[#TWAProcedures.Categories + 1] = { key = "Tailoring", nameKey = "IGUI_TWA_ProcCat_Tailoring", ids = { "SewBag" } }
    TWAProcedures.Order[#TWAProcedures.Order + 1] = "SewBag"
end

-- ------------------------------------------------------------ the recipes
local function bag(id, result, icon, tier, base, base2, procs)
    return { id = "Make_Tomb_" .. id, result = T .. result, base = base, base2 = base2, category = B.CATEGORY,
        stats = { icon = icon, tier = tier, dps = 0 }, procedures = procs, tombBag = true }
end
B.RECIPES = {
    bag("FannyPack",    "Goth_Fanny_Front_Loose",  "GothFannyPack",          1, "Base.DenimStripsBundle", BUCKLE, { "SewBag", "WrapCloth" }),
    bag("ChestRig",     "Goth_ChestRig_Loose",     "Goth_ChestRig",          2, "Base.LeatherStripsBundle", BUCKLE, { "SewBag", "WrapLeather" }),
    bag("ChestRigFull", "Goth_ChestRigFull_Loose", "Goth_ChestRigFull",      2, LEATHER_S, BUCKLE, { "SewBag", "WrapLeather", "StringSinew" }),
    bag("SmallBag",     "Bag_Small_Loose",         "SmallGothBag",           3, LEATHER_S, BUCKLE, { "SewBag", "WrapCloth" }),
    bag("CoffinBag",    "Bag_Coffin_Loose",        "CoffinBag",              3, LEATHER_M, BUCKLE, { "SewBag", "WrapLeather" }),
    bag("Duffel",       "Bag_Duffel_Loose",        "GothDuffel",             4, "Base.FabricRoll_DenimBlack", BUCKLE, { "SewBag", "WrapCloth", "StringSinew" }),
    bag("GothBag",      "Bag_Goth_Loose",          "GothBag",                4, LEATHER_M, BUCKLE, { "SewBag", "WrapLeather", "StringSinew" }),
    bag("LargeBag",     "Bag_L_Loose",             "LargeGothBag",           5, LEATHER_L, BUCKLE, { "SewBag", "WrapLeather", "StringSinew" }),
    bag("XLCoffin",     "Bag_XLCoffin_Loose",      "XLCoffinBag",            6, LEATHER_L, "Base.Tarp", { "SewBag", "WrapLeather", "StringSinew", "WrapCloth" }),
}
local have = {}
for _, r in ipairs(TWARecipeData.List) do have[r.id] = true end
for _, r in ipairs(B.RECIPES) do
    if not have[r.id] then TWARecipeData.List[#TWARecipeData.List + 1] = r end
end

-- the recipe's picture: the bag script's own icon (Tomb's names differ per bag)
local function scriptOf(t)
    local sm = ScriptManager and ScriptManager.instance
    if not sm then return nil end
    local ok, it = pcall(function() return sm:getItem(t) end)
    return ok and it or nil
end
local avail = {}
function B.isBagRecipe(recipe) return recipe ~= nil and recipe.category == B.CATEGORY end
-- the result exists in this game (Tomb's Wardrobe loaded)
function B.available(recipe)
    if not B.isBagRecipe(recipe) then return true end
    if avail[recipe.id] == nil then
        local it = scriptOf(recipe.result)
        avail[recipe.id] = it ~= nil
        if it and recipe.stats then
            local okI, icon = pcall(function() return it:getIcon() end)
            if okI and icon and tostring(icon) ~= "" then recipe.stats.icon = tostring(icon) end
        end
        if not it then log("recipe %s hidden: %s does not exist (Tomb's Wardrobe not loaded)", recipe.id, tostring(recipe.result)) end
    end
    return avail[recipe.id]
end
function B.anyAvailable()
    for _, r in ipairs(B.RECIPES) do if B.available(r) then return true end end
    return false
end

-- ------------------------------------------------------------ the finished bag
B.WR_DELTA = { Excellent = 5, Good = 0, Bad = -5 }
local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
-- authority side, right after the bag is made
function B.applyQuality(item, word)
    if not item then return end
    local md = item:getModData()
    md.TWA_Quality = word
    local base = tonumber(call(item, "getWeightReduction")) or 0
    local wr = math.max(0, math.min(100, base + (B.WR_DELTA[word] or 0)))
    md.TWA_BagWR = wr
    if item.setWeightReduction then call(item, "setWeightReduction", wr) end
    log("bag %s finished: quality %s, weight reduction %d -> %d", TWALogType and TWALogType(item) or "?", tostring(word), base, wr)
end
function B.applyIncomplete(item)
    if not item or not instanceof or not instanceof(item, "InventoryContainer") then return false end
    local md = item:getModData()
    md.TWA_BagEmpty = true
    if item.setCapacity then call(item, "setCapacity", 0) end
    log("unfinished bag %s: capacity 0 until it is finished", TWALogType and TWALogType(item) or "?")
    return true
end
-- put the stored values back (the game does not save an item's own capacity /
-- weight reduction); returns how many items it fixed
local function fix(item)
    local md = item:hasModData() and item:getModData() or nil
    if not md then return 0 end
    local n = 0
    if md.TWA_BagWR and tonumber(call(item, "getWeightReduction")) ~= tonumber(md.TWA_BagWR) then
        call(item, "setWeightReduction", tonumber(md.TWA_BagWR)); n = n + 1
    end
    if md.TWA_BagEmpty and md.TWA_Incomplete and (tonumber(call(item, "getCapacity")) or 0) ~= 0 then
        call(item, "setCapacity", 0); n = n + 1
    elseif md.TWA_BagEmpty and not md.TWA_Incomplete then
        md.TWA_BagEmpty = nil
    end
    return n
end
local function walk(inv, depth)
    if not inv or depth > 4 then return 0 end
    local items, n = call(inv, "getItems"), 0
    for i = 0, (items and items:size() or 0) - 1 do
        local it = items:get(i)
        if it and instanceof(it, "InventoryContainer") then
            n = n + fix(it)
            n = n + walk(call(it, "getInventory"), depth + 1)
        end
    end
    return n
end
function B.maintain(player)
    local n = walk(call(player, "getInventory"), 0)
    if n > 0 then log("%s: %d crafted bag value(s) put back", TWALogName and TWALogName(player) or "?", n) end
    return n
end

local nextAt = 0
if Events and Events.OnTick then
    Events.OnTick.Add(function()
        local t = getTimestampMs and getTimestampMs() or 0
        if t < nextAt then return end
        nextAt = t + 30000
        if not B.anyAvailable() then return end
        if isServer and isServer() then
            local list = getOnlinePlayers and getOnlinePlayers()
            for i = 0, (list and list:size() or 0) - 1 do pcall(B.maintain, list:get(i)) end
        else
            -- SP, and an MP client keeps its own copy in step for the tooltip
            for i = 0, (getNumActivePlayers and getNumActivePlayers() or 1) - 1 do
                local p = getSpecificPlayer and getSpecificPlayer(i)
                if p then pcall(B.maintain, p) end
            end
        end
    end)
end

log("bag recipes: %d (Tomb's Wardrobe bags), new step SewBag", #B.RECIPES)

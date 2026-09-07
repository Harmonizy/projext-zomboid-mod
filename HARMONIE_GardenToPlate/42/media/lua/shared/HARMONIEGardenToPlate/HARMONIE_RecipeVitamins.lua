--[[
    HARMONIE - From Garden to Plate
    Carries vitamin content from ingredients into whatever gets made from
    them -- pots/pans of stew, canned goods, jars, anything crafted through
    either of vanilla's two recipe systems. Covers the same ground vanilla
    itself covers for Calories/Carbs/Lipids/Protein, just for our own
    vitamin stat, which vanilla obviously knows nothing about.

    There are two separate vanilla systems, and they need two different
    techniques:

    1. Evolved recipes (pots/pans -- add ingredients one at a time, e.g.
       Stew, Soup). Driven by ISAddItemInRecipe.lua. Each time an
       ingredient goes in, :complete() does
           self.baseItem = self.recipe:addItem(self.baseItem, self.usedItem, self.character)
       `self.baseItem` is a field on the action, so it's still readable
       after the original function returns -- a plain WRAP is enough:
       read self.usedItem's vitamins before, call through, then add them
       onto the (possibly reassigned) self.baseItem afterward.

       IMPORTANT: this does NOT always consume the whole ingredient in
       one go -- confirmed from vanilla's own scripts (Beef, HungerChange
       -80, declares "Sandwich:5|Cooked" in its EvolvedRecipe list, so
       one raw Beef can season 16 separate Sandwiches before it's used
       up). See the comment above the wrap itself for how the actually-
       consumed fraction is measured and applied.

    2. Standard CraftRecipe (canning, jarring, etc). Driven by
       ISCraftAction.lua. :complete() does
           local list = RecipeManager.PerformMakeItem(self.recipe, self.item, self.character, self.containers)
       `list` (the newly created item(s)) is a LOCAL variable inside that
       function -- nothing outside can see it, so wrapping doesn't work
       here. This is a full override, copied from the current B42
       ISCraftAction.lua (shared/TimedActions/ISCraftAction.lua) with one
       addition (grabbing ingredient vitamins beforehand via
       RecipeManager.getAvailableItemsNeeded, the same call vanilla's own
       getDuration() uses, then applying the sum to each result item). If
       a future game update changes ISCraftAction:complete()'s body, this
       needs to be re-synced with it.

    SAFETY: ISCraftAction:complete() runs for EVERY standard craft recipe
    in the whole game -- carpentry, tailoring, metalworking, vehicle
    repair, other mods' recipes, all of it, not just ours. The extra
    ingredient-vitamin-summing work is gated behind a check of the
    recipe's own module name (recipe:getModule():getName() ==
    "HARMONIEGardenToPlate"), so for every recipe that isn't one of ours
    this override does exactly what vanilla's own complete() does and
    nothing more -- the item-placement logic below (fromFloor / AddItem /
    addOrDropItem) is an unmodified copy of vanilla's, and the vitamin
    summing itself never even runs for a non-HARMONIE recipe.

    Both paths above scale each ingredient's contribution by its own
    HARMONIE_GTP.GetItemCurrentHungerUnits (HARMONIE_FoodVitaminDatabase.lua)
    -- i.e. how much hunger it ACTUALLY has right now, which vanilla
    itself already reduces as food goes stale/rotten -- times its fixed
    vitamin-per-hunger rate. No separate rot/freshness tracking of our
    own: a rotten ingredient naturally contributes less because vanilla
    already reports less current hunger for it.

    RecipeManager.getAvailableItemsNeeded returns one entry per physical
    item instance, confirmed by vanilla's own use of it: ISCraftAction.lua
    itself calls it (line ~144) and sums per-item carried weight over the
    result, which only works if a recipe line like "item 4 [...]" yields 4
    separate entries -- multi-count ingredient recipes are common in
    vanilla, so this is relied on elsewhere already. That's what makes
    MakeHomeCannedProduce's "item 4 [...]" produce requirement sum all of
    its ingredients' vitamins correctly with no special-casing here, and
    no hardcoded count anywhere in this file -- change the recipe's
    required count again in the future and this still sums whatever it
    actually finds, no code change needed here.
]]--

require "TimedActions/ISAddItemInRecipe"
require "TimedActions/ISCraftAction"
require "HARMONIEGardenToPlate/HARMONIE_FoodVitaminDatabase"

HARMONIE_GTP = HARMONIE_GTP or {}

local OUR_MODULE_NAME = "HARMONIEGardenToPlate"

-- MakePillsVitamins (HARMONIE_Recipes.txt) lives in our module but its
-- output (Base.PillsVitamins) is a vanilla FirstAid item, not a food this
-- mod tracks vitamins on -- summing its ingredients' vitamins onto the
-- pill bottle would just be pointless orphaned ModData (and a wasted
-- pcall'd setBaseHunger/setHungChange attempt on a non-Food Drainable
-- item, harmless but sloppy). Excluded explicitly rather than relying on
-- GetVitaminProfileForItem returning nil for the output either way.
local NON_VITAMIN_RECIPES = { MakePillsVitamins = true }

--[[
    True only for recipes belonging to this mod (excluding the ones in
    NON_VITAMIN_RECIPES above). Used to skip all of the extra
    vitamin-summing work (and the extra RecipeManager call it makes) for
    every other recipe in the game -- see the SAFETY note above.
]]--
local function isOurRecipe(recipe)
    local ok, moduleName = pcall(function() return recipe:getModule():getName() end)
    if not (ok and moduleName == OUR_MODULE_NAME) then return false end
    local ok2, name = pcall(function() return recipe:getOriginalname() end)
    return not (ok2 and NON_VITAMIN_RECIPES[name])
end

--[[
    Sums the vitamin content AND the hunger-units of every ingredient a
    recipe is about to consume. Each ingredient contributes
    rate[vit] * currentHungerUnits -- its fixed vitamin-per-hunger rate
    (HARMONIE_GTP.GetVitaminRatePerHunger) times however much hunger it
    ACTUALLY has right now (HARMONIE_GTP.GetItemCurrentHungerUnits, which
    already reflects any rot -- vanilla's own getHungerChange() does that
    reduction for us, nothing extra to compute here). Keeping the
    vitamin sum and the hunger-units sum built from the exact same
    per-ingredient currentHungerUnits values is what keeps the crafted
    result's vitamin-per-hunger-point rate matching its ingredients' (see
    GetItemHungerUnits's comment for why that matters).
    Returns vitaminSum, hungerUnitsSum -- vitaminSum is nil if none of the
    ingredients carry any vitamin data.
]]--
function HARMONIE_GTP.SumRecipeIngredientVitamins(recipe, character, containers, item)
    if not isOurRecipe(recipe) then return nil, 0 end

    local ok, items = pcall(RecipeManager.getAvailableItemsNeeded, recipe, character, containers, item, nil)
    if not ok or not items then return nil, 0 end

    local sum, any, hungerUnitsSum = {}, false, 0
    for i = 0, items:size() - 1 do
        local ingredient = items:get(i)
        local rates = HARMONIE_GTP.GetVitaminRatePerHunger(ingredient)
        local currentHungerUnits = rates and HARMONIE_GTP.GetItemCurrentHungerUnits(ingredient)
        if rates and currentHungerUnits then
            any = true
            for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
                if rates[vit] then
                    sum[vit] = (sum[vit] or 0) + rates[vit] * currentHungerUnits
                end
            end
            hungerUnitsSum = hungerUnitsSum + currentHungerUnits
        end
    end
    return any and sum or nil, hungerUnitsSum
end

-- ============================================
-- 1. EVOLVED RECIPES (pots/pans) -- wrap, safe
-- ============================================

--[[
    Evolved recipes do NOT always consume a whole ingredient in one
    action. Confirmed straight from vanilla's own item scripts: Beef
    (HungerChange -80, i.e. an 80-point hunger pool) declares
    "EvolvedRecipe = ...Sandwich:5|Cooked;Salad:10|Cooked..." -- a single
    raw Beef can season 16 separate Sandwiches (5 points each) or 8
    Salads (10 points each) before it's used up; Carrots (HungerChange
    -8) is the same story at smaller scale (Soup/Stew need all 8 points,
    but Sandwich/Salad only need 4 -- half a carrot). Vanilla decrements
    the ingredient's own getHungerChange() by whatever it actually
    contributed and leaves the leftover item in inventory rather than
    deleting it whenever the recipe doesn't need the whole thing.

    Since recipe:addItem() is a native call, the only reliable way to
    know how much of THIS specific addition actually got consumed is to
    compare the ingredient's hunger before/after calling through --
    fully consumed if it's no longer in the character's inventory
    afterward, otherwise the fraction of its hunger that dropped.
    Without this, every addition would credit the dish with the
    ingredient's FULL vitamin content regardless of how much was really
    used, AND the leftover portion would still hand out its full
    original vitamin profile again whenever it's later eaten or cooked
    with -- double-counting.
]]--
local function getItemHunger(item)
    if not item then return nil end
    local ok, hunger = pcall(function() return item:getHungerChange() end)
    return ok and hunger or nil
end

local original_ISAddItemInRecipe_complete = ISAddItemInRecipe.complete
function ISAddItemInRecipe:complete()
    local usedItem = self.usedItem
    local usedRates = HARMONIE_GTP.GetVitaminRatePerHunger(usedItem)
    local hungerBefore = usedRates and getItemHunger(usedItem)

    local result = original_ISAddItemInRecipe_complete(self)

    if usedRates and hungerBefore then
        -- hungerUnitsUsed: how much hunger THIS action actually consumed,
        -- measured directly from before/after readings -- both already
        -- reflect any rot on their own (vanilla's own getHungerChange()),
        -- so multiplying by the fixed rate above is all that's needed;
        -- no separate freshness step. Defaults to the whole remaining
        -- amount (fully consumed) unless the ingredient is still present
        -- afterward with a lesser amount used.
        local hungerUnitsUsed = math.abs(hungerBefore * 100)
        local stillHere = usedItem and self.character:getInventory():contains(usedItem)
        if stillHere then
            local hungerAfter = getItemHunger(usedItem)
            if hungerAfter then
                hungerUnitsUsed = math.abs((hungerBefore - hungerAfter) * 100)
            end
        end

        local scaled = {}
        for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
            if usedRates[vit] then
                scaled[vit] = usedRates[vit] * hungerUnitsUsed
            end
        end
        HARMONIE_GTP.AddVitaminsToItem(self.baseItem, scaled, hungerUnitsUsed)
    end
    return result
end

-- ============================================
-- 2. STANDARD CRAFT RECIPES (canning/jars/etc)
--    full override -- see file header for why
-- ============================================

function ISCraftAction:complete()
    local vitaminSum, hungerUnitsSum = HARMONIE_GTP.SumRecipeIngredientVitamins(self.recipe, self.character, self.containers, self.item)

    local fromFloor = false
    if self.container:getType() == "floor" then
        fromFloor = true
    end

    local list = RecipeManager.PerformMakeItem(self.recipe, self.item, self.character, self.containers)

    if list then
        for i = 0, list:size() - 1 do
            local newItem = list:get(i)
            if vitaminSum then
                HARMONIE_GTP.AddVitaminsToItem(newItem, vitaminSum, hungerUnitsSum)
                -- Sealed/open home-canned items carry their own static
                -- reference HungerChange in HARMONIE_Items.txt (e.g.
                -- HomeCannedCarrots = -32.0, "4 fresh carrots"), needed
                -- as a fallback for a debug-spawned jar with no ModData.
                -- But GetItemCurrentHungerUnits (HARMONIE_FoodVitaminDatabase.lua)
                -- reads the item's own LIVE getHungerChange() first, which
                -- would otherwise always be that static fresh-reference
                -- number regardless of how stale the real ingredients
                -- were -- silently discarding the staleness reduction
                -- already correctly baked into hungerUnitsSum above (a
                -- jar canned from half-rotten produce would still eat
                -- back out as if it were made from fully fresh produce).
                -- Overwriting the newly-crafted item's OWN hunger to
                -- match what actually went into it keeps the two systems
                -- in agreement, and still lets vanilla's normal rot
                -- reduce it further from there once opened.
                if hungerUnitsSum and hungerUnitsSum > 0 then
                    local rawHunger = -hungerUnitsSum / 100
                    pcall(function() newItem:setBaseHunger(rawHunger) end)
                    pcall(function() newItem:setHungChange(rawHunger) end)
                end
            end
            if fromFloor then
                self.character:getCurrentSquare():AddWorldInventoryItem(newItem,
                        self.character:getX() - math.floor(self.character:getX()) + ZombRandFloat(0.1, 0.5),
                        self.character:getY() - math.floor(self.character:getY()) + ZombRandFloat(0.1, 0.5),
                        self.character:getZ() - math.floor(self.character:getZ()))
                self.container:AddItem(newItem)
            else
                Actions.addOrDropItem(self.character, newItem)
            end
        end
    end

    return true
end

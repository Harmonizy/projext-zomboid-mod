--[[
    HARMONIE - From Garden to Plate
    Carries vitamin content from ingredients into whatever gets made from
    them -- pots/pans of stew, canned goods, jars, anything crafted through
    either of vanilla's two recipe systems. Covers the same ground vanilla
    itself covers for Calories/Carbs/Lipids/Protein, just for our own
    vitamin stat, which vanilla obviously knows nothing about.

    There are two separate vanilla systems, and they're handled very
    differently on purpose:

    1. Evolved recipes (pots/pans -- add ingredients one at a time, e.g.
       Stew, Soup). Driven by ISAddItemInRecipe.lua. Each time an
       ingredient goes in, :complete() does
           self.baseItem = self.recipe:addItem(self.baseItem, self.usedItem, self.character)
       `self.baseItem` is a field on the action, so it's still readable
       after the original function returns -- a plain WRAP is enough:
       read self.usedItem's vitamins before, call through, then add them
       onto the (possibly reassigned) self.baseItem afterward. This is a
       genuinely DYNAMIC calculation -- it measures exactly how much of
       the real ingredient got used (see the comment above the wrap for
       why that matters) and writes the result onto the dish's own
       ModData, since there's no static "this exact combination of
       ingredients" table that could cover every possible pot of stew.

    2. Standard CraftRecipe (canning/jarring -- MakeHomeCannedProduce /
       OpenHomeCannedProduce). Driven by ISCraftAction.lua. This USED to
       be a full override of ISCraftAction:complete() (needed because the
       newly-created item list is a variable local to that function, so a
       plain wrap couldn't reach it) that dynamically summed the real
       ingredients' vitamins onto the new jar, the same way evolved
       recipes do. That was deliberately dropped in favor of a much
       simpler STATIC approach:
         - HARMONIE_CannedProduceVitamins.lua registers a fixed vitamin
           profile for every "Home-Canned <Produce>Open" item type,
           scaled by PRODUCE_PER_JAR (4, matching the recipe's "item 4
           [...]" requirement) from the raw ingredient's own DB entry.
         - HARMONIE_GardenToPlate_Items.txt gives that same Open item type a real,
           static, per-type HungerChange (also the produce's own hunger
           x4) directly in its script.
         - HARMONIE_FoodVitaminDatabase.lua's normal lookup chain
           (GetVitaminProfileForItem / GetItemHungerUnits) already checks
           an item's ModData FIRST and falls back to exactly this kind of
           static, by-type data when there's none -- so as long as a
           canned jar is NEVER given per-instance ModData, it automatically
           resolves through the static tables with the correct rate,
           with zero extra code needed in this file at all.
       The trade-off: a jar always counts as "made from 4 fully fresh
       units" no matter how stale the produce actually was at canning
       time (the old dynamic version correctly reduced this). Freshness
       lost to rot AFTER canning still works completely normally though --
       GetItemCurrentHungerUnits reads the jar's own live getHungerChange(),
       which vanilla itself keeps reducing as the OPEN jar sits around and
       ages per its own DaysFresh/DaysTotallyRotten, same as any other
       food. Only the "how fresh were the ingredients at the moment of
       canning" nuance is gone. In exchange, no full-function override is
       needed AT ALL for this mod anymore -- see the wrap at the bottom
       of this file, which now only exists to fire the in-character
       canning/opening flavor line, and is a plain, safe wrap like #1
       above, not a full-function copy. That removes a real compatibility
       risk this mod used to carry: a full override of a function called
       by EVERY craft recipe in the entire game (all mods, all players)
       would silently lose if any other mod also fully overrode it, and
       would silently go stale if a future game update ever changed
       vanilla's real implementation.

       IMPORTANT correction: that plain wrap was originally placed on
       ISCraftAction:complete(), following the (wrong) assumption that it
       was still the active class for craftRecipe-based crafting. It
       isn't in current Build 42 -- confirmed straight from vanilla's own
       ISHandcraftAction.lua, which is what HandcraftLogic/OnNewCraft
       actually drives now (self.craftRecipe holds the recipe there, not
       self.recipe). This was found because the flavor line never fired
       even after fixing an unrelated getName()/getOriginalname() bug in
       the same function -- 0% both before and after only made sense if
       the wrap was on a class that never runs for these recipes at all.
       The wrap below is now on ISHandcraftAction instead.

    Both paths scale a raw ingredient's contribution by its own
    HARMONIE_GTP.GetItemCurrentHungerUnits (HARMONIE_FoodVitaminDatabase.lua)
    -- i.e. how much hunger it ACTUALLY has right now, which vanilla
    itself already reduces as food goes stale/rotten -- times its fixed
    vitamin-per-hunger rate. No separate rot/freshness tracking of our
    own: a rotten ingredient naturally contributes less because vanilla
    already reports less current hunger for it.
]]--

require "TimedActions/ISAddItemInRecipe"
require "Entity/TimedActions/ISHandcraftAction"
require "HARMONIEGardenToPlate/HARMONIE_FoodVitaminDatabase"

HARMONIE_GTP = HARMONIE_GTP or {}

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
    with -- double-counting. (A flat "always credit half" shortcut was
    considered and rejected for exactly this reason: it would still
    over-credit anything that only needs a small fraction, like Beef in
    a Sandwich, while under-crediting anything that needs the whole
    ingredient, like Carrots in Soup -- there's no single fixed fraction
    that's correct across every EvolvedRecipe.)
]]--
-- item:getHungerChange() is a Food-specific getter -- calling it on a
-- FluidContainer-only ingredient (Milk, if ever used in an evolved
-- recipe) throws under the hood the same way item:getBaseHunger() did
-- for Milk's tooltip/eat path (see HARMONIE_FoodVitaminDatabase.lua's
-- GetItemBaseHunger/GetItemCurrentHungerUnits for the confirmed report).
-- Only attempted for genuine Food instances for the same reason.
local function getItemHunger(item)
    if not item then return nil end
    local okType, isFood = pcall(function() return instanceof(item, "Food") end)
    if not (okType and isFood) then return nil end
    local ok, hunger = pcall(function() return item:getHungerChange() end)
    return ok and hunger or nil
end

local function snapshotVitaminTotal(item)
    if not item then return nil, nil end
    local ok, modData = pcall(function() return item:getModData() end)
    if ok and modData and modData.HARMONIE_Vitamins then
        return modData.HARMONIE_Vitamins, modData.HARMONIE_HungerUnits
    end
    return nil, nil
end

local function hungerUnitsOf(item)
    local h = getItemHunger(item)
    return h and math.abs(h * 100) or 0
end

local function log(fmt, ...)
    if HARMONIE_GTP.Log then return HARMONIE_GTP.Log("Recipe", fmt, ...) end
    local ok, msg = pcall(string.format, fmt, ...)
    print("[HARMONIE_GTP][Recipe] " .. (ok and msg or tostring(fmt)))
end
local function typeName(item)
    local ok, t = pcall(function() return item:getFullType() end)
    return ok and tostring(t) or "?"
end

--[[
    0.13.0 (owner: "อย่าลืมเรื่องการส่งทอดวิตามิน แม้ว่าจะใส่วัตถุดิบไหนก็ตาม
    หากมี ต้องส่งไปยังอาหารตามความหิวที่อาหารให้ไป"):
      - every Food ingredient now counts, tracked or not: its share of the
        dish's hunger is added to HARMONIE_HungerUnits even when it has no
        vitamins, so the dish's vitamin-per-hunger rate is its real total
        vitamins / its real total hunger (this used to count only tracked
        ingredients, which over-credited a stew that also held untracked
        food -- the old "KNOWN LIMITATION" in the database file);
      - the vitamins an ingredient passes on follow the hunger it GAVE the
        dish (the dish's own hunger before / after this addition). A spice
        that adds no hunger passes on what it lost instead;
      - a base that is already food (bread slices, a pie crust, a hot dog,
        a pan of eggs) brings its own vitamins and hunger in with the
        first addition.
]]--
local original_ISAddItemInRecipe_complete = ISAddItemInRecipe.complete
function ISAddItemInRecipe:complete()
    local usedItem = self.usedItem
    local hungerBefore = getItemHunger(usedItem)
    local usedRates = hungerBefore and HARMONIE_GTP.GetVitaminRatePerHunger(usedItem)

    local oldBaseItem = self.baseItem
    local oldBaseId = oldBaseItem and oldBaseItem.getID and oldBaseItem:getID()
    local oldVitamins, oldHunger = snapshotVitaminTotal(oldBaseItem)
    local baseUnitsBefore = hungerUnitsOf(oldBaseItem)
    -- the base's own content, when the dish has no running total yet
    local seedProfile, seedUnits
    if hungerBefore and not oldVitamins and not oldHunger and baseUnitsBefore > 0 then
        seedUnits = baseUnitsBefore
        seedProfile = {}
        local baseRates = HARMONIE_GTP.GetVitaminRatePerHunger(oldBaseItem)
        for vit, r in pairs(baseRates or {}) do seedProfile[vit] = r * baseUnitsBefore end
    end

    local result = original_ISAddItemInRecipe_complete(self)

    if hungerBefore then
        -- hunger THIS addition took out of the ingredient (all of it when
        -- it is gone, else the drop vanilla made)
        local lost = math.abs(hungerBefore * 100)
        local stillHere = usedItem and self.character:getInventory():contains(usedItem)
        if stillHere then
            local hungerAfter = getItemHunger(usedItem)
            if hungerAfter then lost = math.abs((hungerBefore - hungerAfter) * 100) end
        end

        -- Defensive re-seed: self.recipe:addItem() is a native call, and
        -- there is no confirmed guarantee it always mutates baseItem in
        -- place rather than handing back a different item instance once
        -- the dish changes name/type (an empty pot becoming a named
        -- Stew). If that happens, the running total recorded on the OLD
        -- object is carried over here instead of being dropped.
        local newBaseId = self.baseItem and self.baseItem.getID and self.baseItem:getID()
        if oldVitamins and self.baseItem ~= oldBaseItem then
            local _, currentHunger = snapshotVitaminTotal(self.baseItem)
            if not currentHunger then
                log("baseItem identity changed while adding an ingredient (id %s -> %s) -- the running vitamin total is carried over",
                    tostring(oldBaseId), tostring(newBaseId))
                HARMONIE_GTP.AddVitaminsToItem(self.baseItem, oldVitamins, oldHunger)
            end
        end
        if seedUnits then HARMONIE_GTP.AddVitaminsToItem(self.baseItem, seedProfile, seedUnits) end

        -- hunger the dish GOT from this addition (vanilla gives the dish
        -- the full portion while a skilled cook uses less of the ingredient)
        local given = hungerUnitsOf(self.baseItem) - baseUnitsBefore
        if given < 0.001 then given = 0 end
        local vitUnits = given > 0 and given or lost
        local scaled = {}
        for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
            if usedRates and usedRates[vit] then scaled[vit] = usedRates[vit] * vitUnits end
        end
        HARMONIE_GTP.AddVitaminsToItem(self.baseItem, scaled, given)

        -- always on (one line per addition, the action's own pace):
        -- proves from console.txt alone that the total keeps adding up
        do
            local finalVitamins, finalUnits = snapshotVitaminTotal(self.baseItem)
            local parts = {}
            for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
                if finalVitamins and finalVitamins[vit] then
                    parts[#parts + 1] = string.format("%s=%.1f", vit, finalVitamins[vit])
                end
            end
            log("added %s into %s (id %s): gave %.1f hunger, used %.1f, %s; dish now %.1f hunger {%s}%s",
                typeName(usedItem), typeName(self.baseItem), tostring(newBaseId), given, lost,
                usedRates and "has vitamins" or "no vitamins", tonumber(finalUnits) or 0, table.concat(parts, ", "),
                seedUnits and string.format(" (base brought %.1f hunger)", seedUnits) or "")
        end

        -- Plain ModData changes on a contained item don't reach other
        -- clients on their own. sendItemStats (what vanilla's own complete()
        -- calls right after recipe:addItem) ran BEFORE our ModData was
        -- set, so it is sent again now, plus the ModData itself where the
        -- game has the call for it (B42 syncItemModData).
        if isServer() then
            sendItemStats(self.baseItem)
            if syncItemModData then
                local who, item = self.character, self.baseItem
                pcall(function() syncItemModData(who, item) end)
            end
        end
    end
    return result
end

-- ============================================
-- 2. STANDARD CRAFT RECIPES (canning/jars/etc)
--    plain wrap, just for the flavor line -- the
--    vitamin numbers themselves are pure static
--    lookups now (see file header), nothing to
--    compute or write here at all.
-- ============================================

--[[
    A small in-character remark on finishing one of our own craft
    recipes -- pure flavor, keyed by the recipe's own name so it never
    fires for anyone else's recipe (this wrap's original-function call
    happens for every craftRecipe in the whole game, ours included only
    incidentally). Chance-gated so it doesn't talk over itself on repeat
    crafts in a session.

    IMPORTANT: wrapped onto ISHandcraftAction, NOT ISCraftAction. An
    earlier version wrapped ISCraftAction:complete(), which turns out to
    never run for these recipes at all in current Build 42 -- confirmed
    straight from vanilla's own ISHandcraftAction.lua, which is what
    HandcraftLogic/OnNewCraft actually drives for craftRecipe-based
    crafting now (ISCraftAction appears to be legacy/unused for player
    crafting in this build). This was found because the flavor line
    never fired even after fixing the getName()/getOriginalname() bug
    below -- 0% both before and after, which only made sense if the wrap
    was on a class that never runs in the first place. self.craftRecipe
    (not self.recipe) is ISHandcraftAction's own field for this, per its
    own :new()/complete() -- confirmed via the same vanilla file.
]]--
local RECIPE_FLAVOR_CHANCE_PERCENT = 60
local RecipeFlavorLineKeys = {
    MakeHomeCannedProduce = {"IGUI_HARMONIE_CannedMade_1", "IGUI_HARMONIE_CannedMade_2", "IGUI_HARMONIE_CannedMade_3", "IGUI_HARMONIE_CannedMade_Funny"},
    OpenHomeCannedProduce = {"IGUI_HARMONIE_CannedOpened_1", "IGUI_HARMONIE_CannedOpened_2", "IGUI_HARMONIE_CannedOpened_3", "IGUI_HARMONIE_CannedOpened_Funny"},
}

local function maybeSayRecipeFlavor(character, recipe)
    if not character or not character.Say then return end
    -- getOriginalname() was never a real method on CraftRecipe (confirmed
    -- via CraftRecipe.class -- it only has getName()/getModName()/
    -- getTranslationName()/getIconName()), so this call always failed
    -- silently inside pcall, meaning this flavor line NEVER fired for
    -- either recipe, not "just rarely" -- getName() is the real accessor
    -- and returns the plain script-declared name (e.g.
    -- "MakeHomeCannedProduce"), no module prefix, matching the keys below.
    local ok, name = pcall(function() return recipe:getName() end)
    if not ok then return end
    local keys = RecipeFlavorLineKeys[name]
    if not keys then return end
    if ZombRand(100) >= RECIPE_FLAVOR_CHANCE_PERCENT then return end
    character:Say(getText(keys[ZombRand(#keys) + 1]))
end

local original_ISHandcraftAction_complete = ISHandcraftAction.complete
function ISHandcraftAction:complete()
    local result = original_ISHandcraftAction_complete(self)
    maybeSayRecipeFlavor(self.character, self.craftRecipe)
    return result
end

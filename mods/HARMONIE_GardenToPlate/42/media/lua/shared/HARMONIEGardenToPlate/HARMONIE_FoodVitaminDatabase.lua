--[[
    HARMONIE - From Garden to Plate
    Food -> vitamin content database.

    Each entry is the approximate vitamin content of eating 100% of that
    item, in the same unit as that vitamin's Daily Requirement
    (HARMONIE_VitaminConfig.lua): micrograms for A/D/K, milligrams for
    B/C/E. Values are rough real-world nutrition figures for a typical
    single portion of that food (one medium carrot, one egg, ~150g cooked
    meat, etc.) -- close enough for game balance, not a lab reference.

    Vitamin "B" represents the whole B-complex as one stat (see the note in
    HARMONIE_VitaminConfig.lua), so its mg values are a relative-richness
    approximation rather than a real measurement of any single B vitamin.

    Covers all vanilla food groups on purpose: restricting sources to
    vegetables alone would make Vitamin D and B (dairy/eggs/meat/fish
    territory in real nutrition) permanently unobtainable.

    Gameplay-reasonableness pass: every entry below is checked against the
    Reserve it actually produces (amount / DailyRequirement * 100 /
    reserveGainDivisor) and nudged up to at least ~1 Reserve per typical
    serving wherever a strict real-world figure would have rounded down to
    a fraction of a point (e.g. raw Capers' trace Vitamin K). Nobody should
    ever need to eat ten carrots for a single point of Reserve; foods that
    are secondary/minor sources of a vitamin stay noticeably weaker than
    the foods that are rich in it, they just aren't literally negligible.

    Solid Food items only, on purpose -- FluidContainer-based drinks (Milk
    and anything else consumed the same way) are deliberately NOT tracked
    here at all, per an explicit decision after a long debugging arc
    around them. See HARMONIE_EatHook.lua's header for the full reasoning.
]]--

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.FoodVitaminDB = {}
local DB = HARMONIE_GTP.FoodVitaminDB

local function addGroup(fullTypes, profile)
    for _, fullType in ipairs(fullTypes) do
        DB["Base." .. fullType] = profile
    end
end

-- ===== Vegetables (26 fresh vanilla types surveyed from food.txt) =====
addGroup({"Carrots", "CannedCarrots_Open", "CannedCarrotsOpen"}, {A = 509, K = 10})
addGroup({"SweetPotato"}, {A = 961, C = 20, E = 1.5})
addGroup({"Spinach"}, {A = 140, C = 12, K = 145, E = 1.5})
addGroup({"Kale"}, {A = 200, C = 50, K = 210})
addGroup({"Dandelions"}, {A = 180, C = 20, K = 200})
addGroup({"Lettuce"}, {A = 40, C = 3, K = 15})
addGroup({"Broccoli", "CannedBroccoli_Open"}, {A = 6, C = 81, K = 92})
addGroup({"Cabbage", "CannedCabbage_Open"}, {C = 30, K = 67})
addGroup({"BrusselSprouts"}, {C = 75, K = 137})
addGroup({"Cauliflower"}, {C = 46, K = 15})
addGroup({"BellPepper", "CannedBellPepper_Open"}, {A = 117, C = 152})
addGroup({"Tomato", "CannedTomatoOpen", "CannedTomato_Open"}, {A = 45, C = 17, K = 10})
addGroup({"Cucumber"}, {K = 19})
addGroup({"Zucchini"}, {A = 50, C = 22})
addGroup({"Eggplant", "CannedEggplant_Open"}, {B = 1})
addGroup({"Corn", "CornFrozen", "CannedCornOpen"}, {B = 1.5})
addGroup({"Greenpeas", "CannedPeasOpen", "Peas"}, {C = 58, K = 36, B = 2})
addGroup({"Potato", "CannedPotatoOpen", "CannedPotato_Open"}, {C = 17, B = 3})
addGroup({"FrenchFries", "TatoDots"}, {C = 5, B = 1})
addGroup({"Onion"}, {C = 12})
addGroup({"FriedOnionRings", "FriedOnionRingsCraft"}, {C = 3})
addGroup({"Leek", "CannedLeek_Open"}, {A = 70, C = 10, K = 47})
addGroup({"RedRadish", "CannedRedRadish_Open"}, {C = 17})
addGroup({"Turnip"}, {C = 27})
addGroup({"Daikon"}, {C = 17})
addGroup({"SugarBeet"}, {B = 1})
addGroup({"Avocado"}, {C = 12, E = 2.7, K = 28, B = 2})
addGroup({"Olives"}, {E = 1.7})
addGroup({"Capers"}, {K = 15})
addGroup({"GrapeLeaves"}, {A = 200, K = 150})
addGroup({"Edamame"}, {C = 10, K = 41, B = 2})
addGroup({"MixedVegetables"}, {A = 300, C = 10, K = 20})

-- ===== Fruits =====
addGroup({"Orange"}, {C = 70})
addGroup({"Grapefruit"}, {A = 90, C = 44})
addGroup({"Lemon"}, {C = 40})
addGroup({"Lime"}, {C = 25})
addGroup({"Apple", "Pear"}, {C = 12})
addGroup({"Banana"}, {C = 10, B = 1})
addGroup({"Grapes"}, {C = 10, K = 22})
addGroup({"Mango"}, {A = 90, C = 60})
addGroup({"Peach", "CannedPeachesOpen"}, {A = 40, C = 10})
addGroup({"Pineapple", "CannedPineappleOpen"}, {C = 79})
addGroup({"Watermelon", "WatermelonSliced", "WatermelonSmashed"}, {A = 55, C = 12})
addGroup({"Cherry"}, {C = 10})
addGroup({"DriedApricots"}, {A = 63})
addGroup({"CannedFruitCocktailOpen"}, {C = 15})
-- Wild-foraged berries -- generic real-world berry nutrition (moderate
-- Vitamin C, trace K); Rosehips are a genuine real-world outlier
-- (one of the richest natural Vitamin C sources) so kept separate.
addGroup({"BeautyBerry", "BerryBlack", "BerryBlue", "BerryGeneric1", "BerryGeneric2", "BerryGeneric3", "BerryGeneric4", "BerryGeneric5", "BerryPoisonIvy", "HollyBerry", "Strewberrie", "WinterBerry"}, {C = 12, K = 8})
addGroup({"Rosehips"}, {C = 60})

-- ===== Meat / poultry / game (B-complex focus) =====
addGroup({"Beef", "Steak", "MincedMeat", "MeatPatty", "BeefJerky", "CannedCornedBeefOpen"}, {B = 4.5})
addGroup({"Chicken", "ChickenFillet", "ChickenWhole", "ChickenWings", "ChickenNuggets"}, {B = 3})
addGroup({"Pork", "PorkChop", "MuttonChop", "Ham", "HamSlice", "Bacon", "BaconBits", "BaconRashers", "Sausage", "Salami", "SalamiSlice", "Pepperoni", "Baloney", "BaloneySlice", "Hotdog", "Hotdog_single", "MeatDumpling"}, {B = 2.5})
addGroup({"TurkeyFillet", "TurkeyLegs", "TurkeyWhole", "TurkeyWings"}, {B = 3})
addGroup({"Venison", "Rabbitmeat", "FrogMeat", "Smallanimalmeat", "Smallbirdmeat"}, {B = 2})
addGroup({"CannedBologneseOpen"}, {A = 20, C = 10, B = 2})
addGroup({"CannedChiliOpen"}, {A = 15, C = 15, B = 2.5})
addGroup({"TinnedSoupOpen"}, {A = 20, C = 10, B = 1})

-- ===== Fish / seafood (Vitamin D focus) =====
addGroup({"Salmon"}, {D = 19, B = 4})
addGroup({"FishFillet", "FishFried", "FishFingers", "CannedSardinesOpen", "TunaTinOpen"}, {D = 10, B = 3})
addGroup({"Shrimp", "ShrimpFried", "ShrimpDumpling", "ShrimpFriedCraft", "Crayfish", "Lobster", "Oysters", "OystersFried", "Squid", "SquidCalamari"}, {D = 3, B = 2})

-- ===== Mushrooms (some real Vitamin D from sun/UV exposure, plus B) =====
addGroup({"MushroomsButton", "MushroomGeneric1", "MushroomGeneric2", "MushroomGeneric3", "MushroomGeneric4", "MushroomGeneric5", "MushroomGeneric6", "MushroomGeneric7"}, {D = 1, B = 1})
addGroup({"CannedMushroomSoupOpen"}, {D = 0.5, B = 1})

-- ===== Dairy / eggs (Vitamin D and A focus) =====
-- Fresh/fluid Milk (Base.Milk, Milk_Personalsized, MilkChocolate_
-- Personalsized) is DELIBERATELY not tracked at all -- per the user's
-- explicit decision after a long debugging arc around FluidContainer
-- drinks (missing DB entries, progressive-draining hunger reads, etc):
-- no vitamins for milk or anything drunk from a container the same way,
-- full stop. See HARMONIE_EatHook.lua's header for why the entire
-- ISDrinkFluidAction hook was removed rather than just the DB rows --
-- CannedMilkOpen below is unaffected since it's sweetened condensed milk
-- in a solid Food item, not a FluidContainer drink -- a solid Food item
-- with its own native HungerChange = -10.0 (confirmed via generated/
-- items/food.txt), nutritionally concentrated/sweetened rather than
-- fresh, scaled off its own hunger (-10, a fifth of fresh Milk's -50)
-- applied to condensed milk's real approximate per-100g figures (A
-- ~18mcg, D ~0 unfortified, B ~1mg per typical whole can).
addGroup({"CannedMilkOpen"}, {A = 18, B = 1})
addGroup({"Cheese", "Processedcheese", "cheese_powdered"}, {D = 2, A = 75, B = 1})
addGroup({"Butter"}, {A = 150, D = 2})
addGroup({"Egg", "EggBoiled", "EggOmelette", "EggPoached", "EggScrambled", "OmeletteRecipe", "OmeletteRecipeForged", "TurkeyEgg", "WildEggs"}, {D = 1.5, A = 75, B = 1})

-- ===== Grains / legumes / nuts (B and E focus) =====
addGroup({"Bread", "BreadSlices", "Baguette", "BunsHamburger_single", "BunsHotdog_single"}, {B = 1.5})
addGroup({"Rice", "WaterPotRice", "WaterPotForgedRice", "WaterSaucepanRice", "WaterSaucepanRiceCopper"}, {B = 1})
addGroup({"Pasta", "Macaroni", "Ramen"}, {B = 1})
addGroup({"DriedLentils", "DriedSplitPeas", "Blackbeans", "DriedBlackBeans", "DriedChickpeas", "DriedKidneyBeans", "DriedWhiteBeans", "BeanBowl", "OpenBeans", "RefriedBeans", "Soybeans"}, {B = 3, E = 1.5})
addGroup({"Tofu", "TofuFried"}, {B = 2, E = 1})
addGroup({"Peanuts", "PeanutButter", "Acorn"}, {E = 2.5, B = 2})
addGroup({"OilOlive"}, {E = 8})
addGroup({"OilVegetable"}, {E = 4})

--[[
    HARMONIE_GTP.GetVitaminProfileForItem(item)
    Returns a {A=,B=,C=,D=,E=,K=} table describing 100% of the given ITEM
    INSTANCE's vitamin content, or nil if it has none.

    Checks the item's own ModData first (HARMONIE_Vitamins) before falling
    back to the static database keyed by full type. The ModData path is
    what makes vitamins carry over into cooked/crafted results: see
    HARMONIE_RecipeVitamins.lua, which sums a recipe's ingredient vitamins
    (recursing through this same function, so a stew made partly from
    canned vegetables still counts them) and writes the total onto the
    resulting Pot of Stew / canned jar / etc. -- a plain raw ingredient
    with no ModData set just resolves to its static database entry.
]]--
function HARMONIE_GTP.GetVitaminProfileForItem(item)
    if not item then return nil end
    local ok, modData = pcall(function() return item:getModData() end)
    if ok and modData and modData.HARMONIE_Vitamins then
        return modData.HARMONIE_Vitamins
    end
    local fullType = item.getFullType and item:getFullType()
    return fullType and DB[fullType] or nil
end

--[[
    HARMONIE_GTP.LogMissingProfile(item, context)
    Permanent (not a temporary debug print -- always left in) one-line
    warning to console.txt for a genuine Food item that resolves to NO
    vitamin profile at all (no ModData, and no static DB entry for its
    fullType), so it silently grants zero vitamins. Only called from
    HARMONIE_EatHook.lua's ISEatFoodAction wrap, which already gates on
    being a real eat action -- so this can never fire for the huge
    majority of non-food tooltips etc, only for something a character
    actually just ate with nothing to show for it. Cheap and rare enough
    (only fires on a genuine DB gap, not on every eat) to just always log
    rather than hiding behind a debug toggle.
]]--
function HARMONIE_GTP.LogMissingProfile(item, context)
    local ok, fullType = pcall(function() return item:getFullType() end)
    print(string.format("[HARMONIE] %s: no vitamin profile for %s -- either deliberately untracked (candy, herbs, seeds, etc), or a real DB gap worth adding to HARMONIE_FoodVitaminDatabase.lua",
        tostring(context), tostring(ok and fullType or "?")))
end

--[[
    HARMONIE_GTP.AddVitaminsToItem(item, profile, hungerUnits)
    Accumulates `profile` (a {A=,B=,...} table, as returned by
    GetVitaminProfileForItem) onto `item`'s own ModData, adding to
    whatever it already has. Used to build up a crafted/cooked result's
    vitamin content from its ingredients.

    Also accumulates `hungerUnits` (a plain number: how many "visible"
    hunger points -- the -8/-16/-80 style numbers straight from an item's
    own script, see GetItemHungerUnits below -- the ingredient(s) that
    produced `profile` were worth) alongside it, into
    modData.HARMONIE_HungerUnits. This is what lets
    GetVitaminRatePerHunger show the SAME "vitamin per hunger point"
    number for a raw carrot, a sealed jar of 5 carrots, and that same jar
    opened -- all three end up with profile/hungerUnits equal to a single
    fresh carrot's own ratio, because both numbers are summed together
    from the same ingredients using the same scaling (see
    HARMONIE_RecipeVitamins.lua), so the ratio between them can't drift
    no matter how many ingredients or recipe steps it's been through.
]]--
function HARMONIE_GTP.AddVitaminsToItem(item, profile, hungerUnits)
    if not item or not profile then return end
    local modData = item:getModData()
    modData.HARMONIE_Vitamins = modData.HARMONIE_Vitamins or {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if profile[vit] then
            modData.HARMONIE_Vitamins[vit] = (modData.HARMONIE_Vitamins[vit] or 0) + profile[vit]
        end
    end
    if hungerUnits and hungerUnits > 0 then
        modData.HARMONIE_HungerUnits = (modData.HARMONIE_HungerUnits or 0) + hungerUnits
    end
end

--[[
    HARMONIE_GTP.GetItemBaseHunger(item)
    Returns the fresh/baseline hunger-relief value to use for `item`, for
    genuine solid Food instances only (getBaseHunger()) -- FluidContainer
    -based drinks (Milk and anything consumed the same way) are
    deliberately NOT handled here at all, see HARMONIE_EatHook.lua's
    header for why fluid-container drinks were dropped from this mod
    entirely rather than supported. Returns nil for anything that isn't a
    genuine Food instance, INCLUDING fluid containers now -- the
    instanceof check is what keeps item:getBaseHunger() from ever being
    attempted on one (confirmed as a real reported bug: calling it on a
    non-Food item throws a native Java exception, not a harmless 0).
]]--
function HARMONIE_GTP.GetItemBaseHunger(item)
    if not item then return nil end

    local okType, isFood = pcall(function() return instanceof(item, "Food") end)
    if not (okType and isFood) then return nil end

    local ok, baseHunger = pcall(function() return item:getBaseHunger() end)
    if ok and baseHunger and baseHunger ~= 0 then
        return baseHunger
    end
    return nil
end

--[[
    HARMONIE_GTP.GetItemHungerUnits(item)
    Returns how many "visible" hunger points (the -8/-16/-80 style number
    straight from an item's own script, i.e. |GetItemBaseHunger()*100| --
    see that function's comment for why the *100 is needed) `item`
    represents, for use as the denominator in GetVitaminRatePerHunger.

    Checks ModData first (HARMONIE_HungerUnits, accumulated by
    AddVitaminsToItem alongside the vitamins themselves whenever
    something is crafted/cooked -- see HARMONIE_RecipeVitamins.lua)
    before falling back to the item's own static base hunger. This
    ModData path is what keeps the displayed rate identical across a raw
    carrot, a sealed jar of canned carrots, and that jar opened: all
    three carry a profile-to-hungerUnits ratio that traces back to the
    same original carrots, scaled together, so it can't drift no matter
    how many were combined or how many crafting steps it went through --
    unlike using the jar's OWN script-defined hunger (a separate, mostly
    arbitrary balancing number that has nothing to do with what went
    into it), which was the earlier design and gave inconsistent numbers
    between forms of the same food.
]]--
function HARMONIE_GTP.GetItemHungerUnits(item)
    if not item then return nil end
    local ok, modData = pcall(function() return item:getModData() end)
    if ok and modData and modData.HARMONIE_HungerUnits and modData.HARMONIE_HungerUnits > 0 then
        return modData.HARMONIE_HungerUnits
    end
    local baseHunger = HARMONIE_GTP.GetItemBaseHunger(item)
    if not baseHunger or baseHunger == 0 then return nil end
    return math.abs(baseHunger * 100)
end

--[[
    HARMONIE_GTP.GetItemCurrentHungerUnits(item)
    Returns how many "visible" hunger points (see GetItemHungerUnits)
    `item` relieves RIGHT NOW, using getHungerChange() -- the value
    vanilla itself already reduces as food goes stale/rotten -- instead
    of the fixed baseline. This is the only place rot matters at all: we
    don't track or display a separate "freshness" concept anywhere,
    we just read vanilla's own current hunger value and multiply by the
    item's fixed vitamin-per-hunger rate (GetVitaminRatePerHunger) to get
    however much vitamin that current amount is actually worth. A rotten
    carrot naturally gives less because vanilla already reports less
    hunger for it -- nothing extra to compute or show.
    Falls back to GetItemHungerUnits (the fixed reference) for anything
    without a live getHungerChange() of its own, e.g. FluidContainer
    drinks (Milk), which don't have a rot curve to read in the first
    place.

    KNOWN LIMITATION: for a crafted evolved-recipe result (a pot of stew,
    not a HARMONIE canned jar -- those get their own hunger forced to
    match exactly, see the ISCraftAction override in
    HARMONIE_RecipeVitamins.lua), this reads the WHOLE pot's real total
    hunger, which vanilla computes from every ingredient that went in,
    tracked or not. If a stew mixes a tracked ingredient (a carrot) with
    something not in HARMONIE_FoodVitaminDatabase.lua's DB that still
    adds real hunger (water, an untracked processed food), the rate
    (profile / GetItemHungerUnits, built only from tracked ingredients)
    gets multiplied by a bigger "current hunger" number than the
    vitamins it's actually based on, over-crediting the vitamin gained
    when eating that specific dish. Rare in practice (most everyday
    ingredients are covered) and not worth a second staleness-snapshot
    system to chase -- documented here rather than silently ignored.
]]--
function HARMONIE_GTP.GetItemCurrentHungerUnits(item)
    if not item then return nil end

    -- Same lesson as GetItemBaseHunger above: item:getHungerChange() is
    -- a Food-specific getter too. Calling it on Milk (a FluidContainer
    -- item, no rot curve to read anyway per the comment above) is
    -- exactly what threw the reported error right after finishing a
    -- drink -- confirmed as the same class of bug, not a new one. Only
    -- attempted for genuine Food instances; FluidContainer drinks fall
    -- straight through to the fixed reference below, same as the
    -- documented "no rot curve" behavior already intended for them.
    local okType, isFood = pcall(function() return instanceof(item, "Food") end)
    if okType and isFood then
        local ok, currentHunger = pcall(function() return item:getHungerChange() end)
        if ok and currentHunger and currentHunger ~= 0 then
            return math.abs(currentHunger * 100)
        end
    end

    return HARMONIE_GTP.GetItemHungerUnits(item)
end

--[[
    HARMONIE_GTP.GetVitaminGains(item, fraction)
    Returns a table {A=,B=,C=,D=,E=,K=} (only keys with a nonzero gain
    present) for eating `fraction` (0-1, vanilla's own "how much of this
    item's original amount was just eaten" -- ISEatFoodAction's
    self.percentage) of the given ITEM INSTANCE right now, or nil if it
    has no vitamin content or no resolvable hunger to work from. Computed
    as this item type's fixed vitamin-per-hunger rate
    (GetVitaminRatePerHunger) times however much hunger it ACTUALLY has
    right now (GetItemCurrentHungerUnits) times the fraction eaten -- a
    rotten item naturally gives less because vanilla already reports less
    current hunger for it, no separate rot/freshness calculation needed.
    Values are in the same unit as that vitamin's Daily Requirement.
]]--
function HARMONIE_GTP.GetVitaminGains(item, fraction)
    local rates = HARMONIE_GTP.GetVitaminRatePerHunger(item)
    if not rates then return nil end
    local currentHungerUnits = HARMONIE_GTP.GetItemCurrentHungerUnits(item)
    if not currentHungerUnits then return nil end
    fraction = fraction or 1
    local scale = fraction * currentHungerUnits
    local gains = {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if rates[vit] then
            gains[vit] = rates[vit] * scale
        end
    end
    return gains
end


--[[
    HARMONIE_GTP.GetVitaminRatePerHunger(item)
    Returns {A=,B=,C=,D=,E=,K=} expressing vitamin content PER 1 (visible,
    script-scale) POINT OF HUNGER this item represents (profile /
    GetItemHungerUnits()), for display purposes
    (HARMONIE_TooltipHook.lua) -- a stable, portion- and form-independent
    number so a player can compare a small item against a big one on
    equal footing, and so a raw carrot, a sealed jar of canned carrots,
    and that jar opened all show the identical number (both profile and
    hungerUnits are summed from the same original ingredients using the
    same scaling, so the ratio can't drift between forms -- see
    GetItemHungerUnits and HARMONIE_RecipeVitamins.lua). Returns nil if
    the item has no vitamin content or no resolvable hunger-unit value to
    divide by.
]]--
function HARMONIE_GTP.GetVitaminRatePerHunger(item)
    local profile = HARMONIE_GTP.GetVitaminProfileForItem(item)
    if not profile then return nil end

    local hungerUnits = HARMONIE_GTP.GetItemHungerUnits(item)
    if not hungerUnits or hungerUnits == 0 then return nil end

    local rates = {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if profile[vit] then
            rates[vit] = profile[vit] / hungerUnits
        end
    end
    return rates
end

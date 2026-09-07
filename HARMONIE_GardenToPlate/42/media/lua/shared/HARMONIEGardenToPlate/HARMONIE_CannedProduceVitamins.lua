--[[
    HARMONIE - From Garden to Plate
    Registers a vitamin profile for every "Home-Canned <Produce>" item
    (sealed and open) defined in HARMONIE_Items.txt / HARMONIE_Recipes.txt,
    one pair per vanilla vegetable/fruit that can go into the canning
    recipe (see HARMONIE_Recipes.txt's MakeHomeCannedProduce / mod.info).

    Derives its numbers from the SAME profile table already registered for
    the raw ingredient in HARMONIE_FoodVitaminDatabase.lua (looked up at
    runtime, not re-typed here) rather than duplicating the numbers -- if
    a raw ingredient's values ever get tuned there, every canned form of it
    updates automatically and can never drift out of sync. This also means
    the vitamin content is visible via HARMONIE_TooltipHook.lua on BOTH the
    sealed jar and the opened one, exactly like any other tracked food,
    since GetVitaminProfileForItem() just does a plain database lookup by
    full type for items with no per-instance ModData override.

    Scaled by PRODUCE_PER_JAR (4, matching MakeHomeCannedProduce's
    "item 4 [...]" produce requirement in HARMONIE_Recipes.txt) so this
    static fallback matches what an actually-crafted jar contains -- a jar
    is really 4 units of produce, and HARMONIE_RecipeVitamins.lua's
    ModData path already sums 4 real ingredients onto a freshly-crafted
    jar. This registry only matters as the fallback for a jar with no
    ModData (e.g. debug-spawned), so it needs to represent the same "4
    units" a legitimately-crafted jar would have, not a single unit's
    worth. A fresh copy of the table is scaled here rather than mutating
    the raw ingredient's own DB entry.

    Note: both the sealed AND open item definitions in HARMONIE_Items.txt
    now also carry a real, per-type HungerChange (4x that produce's own
    hunger, e.g. HomeCannedCarrots is -32.0 for 4x Carrots' -8.0) instead
    of relying only on ModData -- so GetVitaminRatePerHunger resolves
    correctly for a debug-spawned jar too, not just a legitimately-crafted
    one. This registry (the vitamin numerator) and HARMONIE_Items.txt's
    HungerChange (the denominator) must be kept in the same PRODUCE_PER_JAR
    proportion, or the two fallback paths would disagree.

    Every entry here has a matching pair of item definitions in
    HARMONIE_Items.txt and a matching pair of itemMapper lines (one in each
    direction) in HARMONIE_Recipes.txt -- the three files must be kept in
    sync if the produce list ever changes.
]]--

require "HARMONIEGardenToPlate/HARMONIE_FoodVitaminDatabase"

local DB = HARMONIE_GTP.FoodVitaminDB
local PRODUCE_PER_JAR = 4

-- Every vanilla vegetable/fruit full type (without the "Base." prefix)
-- that MakeHomeCannedProduce accepts.
local PRODUCE = {
    "Carrots", "SweetPotato", "Spinach", "Broccoli", "Cabbage", "BrusselSprouts",
    "Cauliflower", "BellPepper", "Tomato", "Cucumber", "Zucchini", "Eggplant",
    "Corn", "Greenpeas", "Potato", "Onion", "Leek", "RedRadish", "Turnip",
    "Daikon", "SugarBeet", "Avocado", "Olives", "Capers", "GrapeLeaves",
    "Edamame", "MixedVegetables",
    "Orange", "Grapefruit", "Apple", "Pear", "Banana", "Grapes", "Mango",
    "Peach", "Pineapple", "Watermelon", "Cherry", "DriedApricots",
}

for _, name in ipairs(PRODUCE) do
    local profile = DB["Base." .. name]
    if profile then
        local scaled = {}
        for vit, amount in pairs(profile) do
            scaled[vit] = amount * PRODUCE_PER_JAR
        end
        DB["HARMONIEGardenToPlate.HomeCanned" .. name] = scaled
        DB["HARMONIEGardenToPlate.HomeCanned" .. name .. "Open"] = scaled
    else
        -- Would mean HARMONIE_Items.txt/Recipes.txt and this list have
        -- drifted apart -- surface it instead of silently shipping a
        -- canned item with no vitamin data.
        print("HARMONIE_GardenToPlate: WARNING no base vitamin profile found for Base." .. name)
    end
end

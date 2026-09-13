--[[
    HARMONIE - From Garden to Plate
    Registers a vitamin profile for every "Home-Canned <Produce>" item's
    OPEN form (the only one that's ever actually eaten -- see below) that
    can come out of the canning recipe (see HARMONIE_GardenToPlate_Recipes.txt's
    MakeHomeCannedProduce / mod.info).

    Derives its numbers from the SAME profile table already registered for
    the raw ingredient in HARMONIE_FoodVitaminDatabase.lua (looked up at
    runtime, not re-typed here) rather than duplicating the numbers -- if
    a raw ingredient's values ever get tuned there, every canned form of it
    updates automatically and can never drift out of sync.

    Scaled by PRODUCE_PER_JAR (4, matching MakeHomeCannedProduce's
    "item 4 [...]" produce requirement in HARMONIE_GardenToPlate_Recipes.txt) so this
    static fallback matches what an actually-crafted jar contains -- a jar
    is really 4 units of produce, and HARMONIE_RecipeVitamins.lua's
    ModData path already sums 4 real ingredients onto a freshly-crafted
    jar. This registry only matters as the fallback for a jar with no
    ModData (e.g. debug-spawned), so it needs to represent the same "4
    units" a legitimately-crafted jar would have, not a single unit's
    worth. A fresh copy of the table is scaled here rather than mutating
    the raw ingredient's own DB entry.

    ONLY the Open item type is registered here, deliberately -- the SEALED
    item (CantEat=true) is never eaten directly (see HARMONIE_GardenToPlate_Items.txt: it
    carries no HungerChange of its own at all, matching vanilla's own real
    sealed cans like Base.CannedCarrots2, specifically so it can't be eaten
    around its own opening recipe/can-opener requirement) and so has no
    "per hunger point" rate to fall back to either -- GetVitaminRatePerHunger
    needs a nonzero hungerUnits denominator, which a CantEat item with no
    native hunger and no ModData will never have. A profile entry for the
    sealed type would just be dead weight. Its vitamin content still
    carries into the opened jar correctly via ModData (HARMONIE_
    RecipeVitamins.lua sums the sealed jar's own contents as an ingredient
    of the OpenHomeCannedProduce recipe), this static entry only matters
    as a fallback for an Open jar with no ModData of its own.

    Every entry here has a matching pair of item definitions in
    HARMONIE_GardenToPlate_Items.txt and a matching pair of itemMapper lines (one in each
    direction) in HARMONIE_GardenToPlate_Recipes.txt -- the three files must be kept in
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
        DB["HARMONIEGardenToPlate.HomeCanned" .. name .. "Open"] = scaled
    else
        -- Would mean HARMONIE_GardenToPlate_Items.txt/Recipes.txt and this list have
        -- drifted apart -- surface it instead of silently shipping a
        -- canned item with no vitamin data.
        print("HARMONIE_GardenToPlate: WARNING no base vitamin profile found for Base." .. name)
    end
end

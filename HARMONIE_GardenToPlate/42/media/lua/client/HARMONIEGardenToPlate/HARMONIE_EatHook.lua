--[[
    HARMONIE - From Garden to Plate
    Awards vitamins for every eat/drink action.

    Checked against vanilla's own scripts (media/scripts/generated/items/
    food.txt and normal.txt): solid food items (getBaseHunger/
    getHungerChange, everything ISEatFoodAction handles) and
    FluidContainer-based drinks (Milk carton, etc -- their hunger value
    lives on the FLUID definition, e.g. fluids.txt's CowMilk
    HungerChange = -50, not on the item itself) are two entirely separate
    vanilla systems driven by two different timed actions:
    ISEatFoodAction (media/lua/shared/TimedActions/ISEatFoodAction.lua)
    for solid food, ISDrinkFluidAction (.../ISDrinkFluidAction.lua) for
    anything drunk from a FluidContainer. An earlier version of this file
    assumed ISEatFoodAction alone covered both -- it doesn't, so Milk (the
    only current DB entry that's a FluidContainer item rather than a Food
    item) was silently never granting its vitamins. Both are wrapped here
    now. Fluid contents have no rot curve in vanilla's fluid data (unlike
    solid food, which does and is handled automatically -- see
    HARMONIE_GTP.GetVitaminGains), so a drink's current hunger is always
    just its fixed reference value.

    Also occasionally comments in-character on the taste of food rich in
    any one of the 6 vitamins when eaten -- see maybeSayTasteReaction
    below. Pure flavor, no mechanical effect. A character with Cooking 3+
    (the same threshold HARMONIE_TooltipHook.lua uses to let someone read
    a food's vitamin content) comments on the actual nutrition instead of
    just the taste, since they'd genuinely recognize it.
]]--

require "TimedActions/ISEatFoodAction"
require "TimedActions/ISDrinkFluidAction"
require "HARMONIEGardenToPlate/HARMONIE_FoodVitaminDatabase"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

local function awardVitamins(character, item, fraction)
    if not item then return end
    local gains = HARMONIE_GTP.GetVitaminGains(item, fraction)
    if gains then
        for vit, amount in pairs(gains) do
            HARMONIE_GTP.VitData.Add(character, vit, amount)
        end
    end
end

--[[
    A small, occasional in-character reaction to what's actually in the
    food -- not tied to the mechanical vitamin gain above, just flavor,
    one candidate reaction per vitamin plus one for home-canned texture:

      A -- the richest A sources here (Carrots, SweetPotato,
           MixedVegetables, GrapeLeaves) are the sweet, earthy root
           vegetables, so this reads as a mellow sweetness.
      B -- the richest B sources are meat, fish, and hearty
           starches/legumes (Beef, Salmon, Chicken/Turkey, Potato, Dried
           Lentils), so this reads as a savory, filling meal.
      C -- genuinely sour/tangy in real life (citrus, peppers, etc).
      D -- the richest D sources here are oily fish (Salmon, FishFillet),
           so this reads as a briny, oceanic taste.
      E -- the richest E sources are nuts/oils (Avocado, Peanuts), so
           this reads as nutty and a little oily.
      K -- the richest K sources are leafy greens/brassicas (Spinach,
           BrusselSprouts, GrapeLeaves), which really do taste "grassy".

    Gated on the item's profile (not the amount just eaten) so a single
    bite of something genuinely rich in one of these can trigger it, and
    on a flat chance so it doesn't fire on literally every relevant meal
    -- that got old fast in testing. If a food qualifies for more than
    one (rare, since the thresholds are set fairly high), only one line
    is said, picked at random among whichever qualify, so eating one
    thing never talks over itself with two comments back to back.
]]--
local TASTE_CHANCE_PERCENT = 100 -- TEMP: bumped from 35 for easy Thai-text testing, dial back down after
local TASTE_THRESHOLDS = {A = 200, B = 3, C = 30, D = 10, E = 2, K = 60}
local KNOWLEDGEABLE_COOKING_LEVEL = 3

-- Plain taste reaction -- what anyone would notice, no nutrition
-- knowledge required. One "funny" variant per vitamin mixed in with the
-- straight ones.
local TasteLineKeys = {
    A = {"IGUI_HARMONIE_TasteSweetA_1", "IGUI_HARMONIE_TasteSweetA_2", "IGUI_HARMONIE_TasteSweetA_Funny"},
    B = {"IGUI_HARMONIE_TasteHeartyB_1", "IGUI_HARMONIE_TasteHeartyB_2", "IGUI_HARMONIE_TasteHeartyB_Funny"},
    C = {"IGUI_HARMONIE_TasteSourC_1", "IGUI_HARMONIE_TasteSourC_2", "IGUI_HARMONIE_TasteSourC_3", "IGUI_HARMONIE_TasteSourC_Funny"},
    D = {"IGUI_HARMONIE_TasteBrinyD_1", "IGUI_HARMONIE_TasteBrinyD_2", "IGUI_HARMONIE_TasteBrinyD_Funny"},
    E = {"IGUI_HARMONIE_TasteNuttyE_1", "IGUI_HARMONIE_TasteNuttyE_2", "IGUI_HARMONIE_TasteNuttyE_Funny"},
    K = {"IGUI_HARMONIE_TasteGrassyK_1", "IGUI_HARMONIE_TasteGrassyK_2", "IGUI_HARMONIE_TasteGrassyK_3", "IGUI_HARMONIE_TasteGrassyK_Funny"},
}

-- Said instead of the plain reaction above when the character has
-- Cooking 3+ -- they recognize the actual nutritional value, not just
-- the taste, same threshold HARMONIE_TooltipHook.lua uses.
local KnowledgeableLineKeys = {
    A = {"IGUI_HARMONIE_KnowA_1", "IGUI_HARMONIE_KnowA_2"},
    B = {"IGUI_HARMONIE_KnowB_1", "IGUI_HARMONIE_KnowB_2"},
    C = {"IGUI_HARMONIE_KnowC_1", "IGUI_HARMONIE_KnowC_2"},
    D = {"IGUI_HARMONIE_KnowD_1", "IGUI_HARMONIE_KnowD_2"},
    E = {"IGUI_HARMONIE_KnowE_1", "IGUI_HARMONIE_KnowE_2"},
    K = {"IGUI_HARMONIE_KnowK_1", "IGUI_HARMONIE_KnowK_2"},
}

local CannedTasteLineKeys = {"IGUI_HARMONIE_TasteCanned_1", "IGUI_HARMONIE_TasteCanned_2", "IGUI_HARMONIE_TasteCanned_Funny"}
local HOME_CANNED_PREFIX = "HARMONIEGardenToPlate.HomeCanned"

local function maybeSayTasteReaction(character, item)
    if not item or not character.Say then return end
    local profile = HARMONIE_GTP.GetVitaminProfileForItem(item)
    if not profile then return end

    -- Candidates are stored as the vitamin letter itself (or "CANNED"
    -- for the texture reaction), NOT the resolved line list -- which
    -- pool to actually read from (plain taste vs knowledgeable) is only
    -- decided after picking a winner, based on Cooking skill.
    local candidates = {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if profile[vit] and profile[vit] >= TASTE_THRESHOLDS[vit] then
            table.insert(candidates, vit)
        end
    end
    local ok, fullType = pcall(function() return item:getFullType() end)
    if ok and fullType and fullType:find(HOME_CANNED_PREFIX, 1, true) == 1 then
        table.insert(candidates, "CANNED")
    end
    if #candidates == 0 then return end
    if ZombRand(100) >= TASTE_CHANCE_PERCENT then return end

    local picked = candidates[ZombRand(#candidates) + 1]
    local keys
    if picked == "CANNED" then
        keys = CannedTasteLineKeys
    elseif character:getPerkLevel(Perks.Cooking) >= KNOWLEDGEABLE_COOKING_LEVEL then
        keys = KnowledgeableLineKeys[picked]
    else
        keys = TasteLineKeys[picked]
    end
    character:Say(getText(keys[ZombRand(#keys) + 1]))
end

local original_ISEatFoodAction_complete = ISEatFoodAction.complete

function ISEatFoodAction:complete()
    local item = self.item
    local fraction = self.percentage or 1
    local result = original_ISEatFoodAction_complete(self)
    awardVitamins(self.character, item, fraction)
    maybeSayTasteReaction(self.character, item)
    return result
end

local original_ISDrinkFluidAction_complete = ISDrinkFluidAction.complete

function ISDrinkFluidAction:complete()
    local item = self.item
    local fraction = self.percentage or 1
    local result = original_ISDrinkFluidAction_complete(self)
    awardVitamins(self.character, item, fraction)
    return result
end

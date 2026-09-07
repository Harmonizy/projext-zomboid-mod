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

local original_ISEatFoodAction_complete = ISEatFoodAction.complete

function ISEatFoodAction:complete()
    local item = self.item
    local fraction = self.percentage or 1
    local result = original_ISEatFoodAction_complete(self)
    awardVitamins(self.character, item, fraction)
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

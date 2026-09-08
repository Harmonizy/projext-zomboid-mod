--[[
    HARMONIE - From Garden to Plate
    Taking this mod's own crafted Multivitamin pill
    (HARMONIEGardenToPlate.Multivitamin -- see HARMONIE_GardenToPlate_
    Items.txt / HARMONIE_GardenToPlate_Recipes.txt) grants exactly
    HARMONIE_GTP.DailyRequirement[vit] of Reserve for EVERY vitamin via
    VitData.Add -- the same real gain formula eating actual food uses.
    Taking one pill is therefore mechanically identical to eating a
    perfectly balanced day's worth of every tracked vitamin at once
    (+10 Reserve per vitamin at the default reserveGainDivisor, banking
    1 pause day per vitamin too, exactly like real food).

    This REPLACES the mod's earlier design, which hooked vanilla's own
    Base.PillsVitamins to grant +1 pause day per vitamin with NO Reserve
    gain -- symptom relief without ever fixing the underlying deficiency.
    Moved onto this mod's own crafted item instead, per explicit request
    ("move the effect here INSTEAD") -- vanilla Vitamin Pills go back to
    being flavor-only now (their original, un-modded behavior), and only
    this mod's own pill, made by combining one iconic real source of
    each vitamin (Carrots/Egg/Orange/Salmon/Peanuts/Kale -- see the
    recipe), actually delivers a full day's nutrition in one dose.

    Every pill/tablet item (painkillers, antibiotics, beta blockers,
    vanilla Vitamin Pills, this one, etc) goes through the same vanilla
    ISTakePillAction, so the wrap below checks the item's own full type
    before doing anything -- it's a no-op for every other pill in the
    game, vanilla Vitamin Pills included.

    Says one of two different in-character lines depending on whether any
    vitamin was ACTUALLY afflicted at the moment the pill was taken:
    genuine relief if so, a "just in case" remark if the pills were taken
    with nothing actually wrong.
]]--

require "TimedActions/ISTakePillAction"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

local MULTIVITAMIN_TYPE = "HARMONIEGardenToPlate.Multivitamin"

-- Said when at least one vitamin was actually afflicted at the moment of
-- taking the pill -- genuine relief.
local PillsTakenLineKeys = {
    "IGUI_HARMONIE_PillsTaken_1",
    "IGUI_HARMONIE_PillsTaken_2",
    "IGUI_HARMONIE_PillsTaken_3",
    "IGUI_HARMONIE_PillsTaken_Funny",
}
-- Said when nothing was actually wrong -- taken just in case.
local PillsTakenPrecautionLineKeys = {
    "IGUI_HARMONIE_PillsTakenPrecaution_1",
    "IGUI_HARMONIE_PillsTakenPrecaution_2",
    "IGUI_HARMONIE_PillsTakenPrecaution_Funny",
}

local function anyVitaminAfflicted(character)
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if HARMONIE_GTP.VitData.IsAfflicted(character, vit) then
            return true
        end
    end
    return false
end

local original_ISTakePillAction_complete = ISTakePillAction.complete

function ISTakePillAction:complete()
    local item = self.item
    local character = self.character
    local result = original_ISTakePillAction_complete(self)

    local ok, fullType = pcall(function() return item and item:getFullType() end)
    if ok and fullType == MULTIVITAMIN_TYPE and character then
        -- Checked BEFORE granting Reserve, since that's what decides
        -- whether this was genuine relief or just a precaution.
        local wasAfflicted = anyVitaminAfflicted(character)
        for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
            HARMONIE_GTP.VitData.Add(character, vit, HARMONIE_GTP.DailyRequirement[vit])
        end
        local keys = wasAfflicted and PillsTakenLineKeys or PillsTakenPrecautionLineKeys
        character:Say(getText(keys[ZombRand(#keys) + 1]))
    end

    return result
end

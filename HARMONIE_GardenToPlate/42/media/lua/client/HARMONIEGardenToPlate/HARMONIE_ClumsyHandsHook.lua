--[[
    HARMONIE - From Garden to Plate
    Reproduces the ONE real vanilla "All Thumbs" mechanic that was
    actually found exposed in Lua (see HARMONIE_VitaminConfig.lua's
    header for the full trait-by-trait research) -- without granting the
    real trait itself.

    ISHandcraftAction.lua's own constructor does:
        if character and (character:hasTrait(CharacterTrait.ALL_THUMBS)
                or character:isWearingAwkwardGloves()) then
            o.stopOnWalk = true;
        end
    i.e. a character with All Thumbs (or wearing bulky gloves) gets
    interrupted if they start walking mid-craft, since fiddly hand-work
    needs you to stand still. This wraps the same constructor to apply
    that exact behavior whenever Vitamin E is Critical (and not pause-day-
    shielded), on top of whatever the real trait/gloves check already
    decided -- so a genuinely All-Thumbs character or someone in bulky
    gloves is unaffected (already true), and a Vitamin-E-deficient
    character gets the same stand-still requirement without the trait
    ever touching their character sheet.
]]--

require "Entity/TimedActions/ISHandcraftAction"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

local original_ISHandcraftAction_new = ISHandcraftAction.new

function ISHandcraftAction:new(character, craftRecipe, containers, isoObject, craftBench, manualInputs, items, recipeItem, variableInputRatio, eatPercentage)
    local o = original_ISHandcraftAction_new(self, character, craftRecipe, containers, isoObject, craftBench, manualInputs, items, recipeItem, variableInputRatio, eatPercentage)

    if character and not o.stopOnWalk then
        local ok, afflicted = pcall(function()
            return HARMONIE_GTP.VitData.IsAfflicted(character, "E")
                    and HARMONIE_GTP.VitData.GetPauseDays(character, "E") < 1
        end)
        if ok and afflicted then
            o.stopOnWalk = true
        end
    end

    return o
end

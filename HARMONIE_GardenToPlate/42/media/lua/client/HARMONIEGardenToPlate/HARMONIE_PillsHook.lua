--[[
    HARMONIE - From Garden to Plate
    Taking vanilla's Base.PillsVitamins (a real vanilla item -- FirstAid
    category, Drainable, flavor-only in vanilla since the base game has no
    vitamin system of its own) suppresses this mod's critical-vitamin
    penalties for 24 in-game hours. See HARMONIE_VitaminData.lua's
    SuppressEffectsFor/IsEffectsSuppressed and HARMONIE_VitaminEffects.lua's
    ApplyCritical for the other half of this.

    Every pill/tablet item (painkillers, antibiotics, beta blockers, this
    one, etc) goes through the same vanilla ISTakePillAction, so the wrap
    below checks the item's own full type before doing anything -- it's a
    no-op for every other pill in the game.
]]--

require "TimedActions/ISTakePillAction"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

local SUPPRESS_HOURS = 24
local VITAMIN_PILLS_TYPE = "Base.PillsVitamins"

local original_ISTakePillAction_complete = ISTakePillAction.complete

function ISTakePillAction:complete()
    local item = self.item
    local character = self.character
    local result = original_ISTakePillAction_complete(self)

    local ok, fullType = pcall(function() return item and item:getFullType() end)
    if ok and fullType == VITAMIN_PILLS_TYPE and character then
        HARMONIE_GTP.VitData.SuppressEffectsFor(character, SUPPRESS_HOURS)
        character:Say(getText("IGUI_HARMONIE_PillsTaken"))
    end

    return result
end

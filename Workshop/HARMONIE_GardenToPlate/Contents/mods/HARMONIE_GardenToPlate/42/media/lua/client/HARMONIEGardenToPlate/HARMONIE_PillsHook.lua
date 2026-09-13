--[[
    HARMONIE - From Garden to Plate
    Taking vanilla's Base.PillsVitamins (a real vanilla item -- FirstAid
    category, Drainable, flavor-only in vanilla since the base game has no
    vitamin system of its own) grants every one of the 6 vitamins
    +PAUSE_DAYS_GRANTED banked pause day(s) via HARMONIE_VitaminData.lua's
    VitData.AddPauseDays -- and NOTHING else: Reserve itself is untouched,
    only the pause-day bank grows. Since GetPauseDays >= 1 already gates
    both daily decay (VitData.ApplyDailyTick) and the critical-band penalty
    itself (HARMONIE_VitaminChecker.lua / HARMONIE_VitaminEffects.lua's
    Maintain* functions), this is enough on its own to quiet an ongoing
    penalty for about a day without pretending the deficiency was ever fixed --
    symptom relief, not a cure, same as before, just implemented as a
    direct grant into the same pause-day bank real food already fills,
    instead of a separate suppression-timestamp system.

    Every pill/tablet item (painkillers, antibiotics, beta blockers, this
    one, etc) goes through the same vanilla ISTakePillAction, so the wrap
    below checks the item's own full type before doing anything -- it's a
    no-op for every other pill in the game.

    Says one of two different in-character lines depending on whether any
    vitamin was ACTUALLY afflicted at the moment the pill was taken:
    genuine relief if so, a "just in case" remark if the pills were taken
    with nothing actually wrong.
]]--

require "TimedActions/ISTakePillAction"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

local PAUSE_DAYS_GRANTED = 1
local VITAMIN_PILLS_TYPE = "Base.PillsVitamins"

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
    if ok and fullType == VITAMIN_PILLS_TYPE and character then
        -- Checked BEFORE granting the pause days, since that's what
        -- decides whether this was genuine relief or just a precaution.
        local wasAfflicted = anyVitaminAfflicted(character)
        for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
            HARMONIE_GTP.VitData.AddPauseDays(character, vit, PAUSE_DAYS_GRANTED)
        end
        local keys = wasAfflicted and PillsTakenLineKeys or PillsTakenPrecautionLineKeys
        character:Say(getText(keys[ZombRand(#keys) + 1]))
    end

    return result
end

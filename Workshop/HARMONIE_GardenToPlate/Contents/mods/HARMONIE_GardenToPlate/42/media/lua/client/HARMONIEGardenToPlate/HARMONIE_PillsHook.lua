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

-- MULTIPLAYER (2026-10-02 audit): complete() runs on the server in MP,
-- which never loads this client/ file; the client's copy ends through
-- perform(). The pill's type is read at start(), granted once (flag) from
-- complete() in single player or perform() on a multiplayer client. The
-- pause days live in the player's ModData, which VitData transmits.
local function grant(self, fullType)
    if self.gtpGranted then return end
    self.gtpGranted = true
    local character = self.character
    if fullType == VITAMIN_PILLS_TYPE and character then
        -- Checked BEFORE granting the pause days, since that's what
        -- decides whether this was genuine relief or just a precaution.
        local wasAfflicted = anyVitaminAfflicted(character)
        for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
            HARMONIE_GTP.VitData.AddPauseDays(character, vit, PAUSE_DAYS_GRANTED)
        end
        local keys = wasAfflicted and PillsTakenLineKeys or PillsTakenPrecautionLineKeys
        character:Say(getText(keys[ZombRand(#keys) + 1]))
    end
end

local function typeOf(self)
    local ok, t = pcall(function() return self.item and self.item:getFullType() end)
    return ok and t or nil
end

local original_ISTakePillAction_start = ISTakePillAction.start
function ISTakePillAction:start()
    self.gtpType = typeOf(self)
    return original_ISTakePillAction_start(self)
end

local original_ISTakePillAction_complete = ISTakePillAction.complete
function ISTakePillAction:complete()
    local t = self.gtpType or typeOf(self)
    local result = original_ISTakePillAction_complete(self)
    grant(self, t)
    return result
end

local original_ISTakePillAction_perform = ISTakePillAction.perform
function ISTakePillAction:perform()
    if isClient() and not self.gtpGranted then grant(self, self.gtpType or typeOf(self)) end
    return original_ISTakePillAction_perform(self)
end

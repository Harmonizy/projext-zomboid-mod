--[[
    Wraps the vanilla, shared TimedAction used by EVERY vehicle part
    install/uninstall in the game -- the same wrap-and-call-through
    idiom HARMONIE_GardenToPlate's HARMONIE_PillsHook.lua uses on
    ISTakePillAction. All 5 parts below are our own, defined entirely
    with vanilla vehicle-part APIs (see HARMONIE_MA_TuningTable.lua).
]]--

require "Vehicles/TimedActions/ISInstallVehiclePart"
require "Vehicles/TimedActions/ISUninstallVehiclePart"
require "HARMONIEMechanicalAdvanced/HARMONIE_MA_PartState"

local OUR_PART_IDS = {
    HARMONIE_MA_Bullbar = true,
    HARMONIE_MA_WindowArmorWindshield = true,
    HARMONIE_MA_WindowArmorDoorLeft = true,
    HARMONIE_MA_WindowArmorDoorRight = true,
    HARMONIE_MA_CargoRack = true,
    HARMONIE_MA_PerfExhaust = true,
}

local InstallLineKeys = {
    "IGUI_HARMONIEMA_Install_1",
    "IGUI_HARMONIEMA_Install_2",
    "IGUI_HARMONIEMA_Install_Funny",
}
local PerfExhaustInstallLineKeys = {
    "IGUI_HARMONIEMA_InstallPerfExhaust_1",
    "IGUI_HARMONIEMA_InstallPerfExhaust_Funny",
}
local UninstallLineKeys = {
    "IGUI_HARMONIEMA_Uninstall_1",
    "IGUI_HARMONIEMA_Uninstall_Funny",
}

local function sayRandom(character, keys)
    if not (character and character.Say) then return end
    character:Say(getText(keys[ZombRand(#keys) + 1]))
end

local original_install_complete = ISInstallVehiclePart.complete
function ISInstallVehiclePart:complete()
    local result = original_install_complete(self)
    if result and self.part and OUR_PART_IDS[self.part:getId()] then
        if not isServer() then
            -- self.item is still a valid reference here even though
            -- install already consumed it from the character's
            -- inventory (ISInstallVehiclePart.lua:72-73) -- only
            -- object removal, not gc, happens before complete()
            -- returns. The engine-tune slot now holds 3 alternative
            -- items (see HARMONIE_MA_MechanicTooltipHook.lua), so the
            -- part id alone can no longer tell us which was installed
            -- -- gate the Mechanics-flavor line on the specific item.
            local isPerfExhaust = self.item and self.item:getFullType() == "HARMONIEMechanicalAdvanced.PerformanceExhaustKit"
            local knowsMechanics = self.character and self.character.getPerkLevel
                and self.character:getPerkLevel(Perks.Mechanics) >= 4
            local keys = (isPerfExhaust and knowsMechanics) and PerfExhaustInstallLineKeys or InstallLineKeys
            sayRandom(self.character, keys)
        end
        HARMONIE_MA.PartState.RecordInstaller(self.vehicle, self.part, self.character)
    end
    return result
end

local original_uninstall_complete = ISUninstallVehiclePart.complete
function ISUninstallVehiclePart:complete()
    local result = original_uninstall_complete(self)
    if result and self.part and OUR_PART_IDS[self.part:getId()] and not isServer() then
        sayRandom(self.character, UninstallLineKeys)
    end
    return result
end

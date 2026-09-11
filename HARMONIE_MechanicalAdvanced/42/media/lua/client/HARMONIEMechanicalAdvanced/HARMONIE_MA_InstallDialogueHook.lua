--[[
    Wraps the vanilla, shared TimedAction used by EVERY vehicle part
    install/uninstall in the game -- not tsarslib-specific -- the same
    wrap-and-call-through idiom HARMONIE_GardenToPlate's
    HARMONIE_PillsHook.lua uses on ISTakePillAction. This means we never
    redefine any ATATuning2.* function ourselves (see the SVU3Core study).
]]--

require "TimedActions/ISInstallVehiclePart"
require "TimedActions/ISUninstallVehiclePart"
require "HARMONIEMechanicalAdvanced/HARMONIE_MA_PartState"

local OUR_PART_IDS = {
    ATA2Bullbar = true,
    ATA2ProtectionWindshield = true,
    ATA2ProtectionWindowFrontLeft = true,
    ATA2ProtectionWindowFrontRight = true,
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
            local isPerfExhaust = self.part:getId() == "HARMONIE_MA_PerfExhaust"
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

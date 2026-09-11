--[[
    Confirmed against vanilla: media/lua/server/Vehicles/Vehicles.lua and
    VehicleCommands.lua both write custom state into part:getModData()
    and sync it with vehicle:transmitPartModData(part) -- there is no
    bare vehicle:transmitModData() anywhere in vanilla or tsarslib.
    This is the vehicle-part analog of HARMONIE_GardenToPlate's
    character:getModData() + character:transmitModData() pattern.
]]--

HARMONIE_MA = HARMONIE_MA or {}
HARMONIE_MA.PartState = {}
local PartState = HARMONIE_MA.PartState

local function sync(vehicle, part)
    if isClient() then
        vehicle:transmitPartModData(part)
    end
end

function PartState.RecordInstaller(vehicle, part, character)
    if not (vehicle and part and character) then return end
    local data = part:getModData()
    data.HARMONIE_installedBy = character:getUsername() or character:getDisplayName()
    local calendar = getGameTime() and getGameTime():getCalender()
    data.HARMONIE_installedDay = calendar and calendar:getDayOfMonth() or nil
    sync(vehicle, part)
end

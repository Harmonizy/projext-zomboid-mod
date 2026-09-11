--[[
    Registers all 5 HARMONIE Mechanical Advanced upgrades on every
    vanilla vehicle confirmed (by reading each one's real Build 42
    vehicle script directly) to have every area our 4 templates need:
    Engine, TruckBed, GasTank, SeatFrontLeft, SeatFrontRight. Pure
    vanilla vehicle-part APIs, no third-party mod dependency (previously
    depended on tsarslib's Tuning2 system; dropped after tsarslib's
    Workshop upload was removed by Steam for a Content Guidelines
    violation -- confirmed on the Workshop page directly).

    getScriptManager():getVehicle(name):Load(name, "{template! = X,}")
    is the same native engine call tsarslib itself used internally to
    inject a template into an already-parsed vehicle script -- it's a
    vanilla ScriptManager/VehicleScript method, not something tsarslib
    implemented, so we can call it directly ourselves.

    Each part uses a real, specific item (itemType = ..., specificItem
    = true) instead of tsarslib's multi-model wildcard system --
    vanilla's own ISInstallVehiclePart/ISUninstallVehiclePart already
    handle the item/model swap natively via part:setInventoryItem(),
    with no "complete" hook required (confirmed against vanilla's own
    Seat*/GasTank/Muffler parts, which omit it entirely).
]]--

local function injectTemplate(vehicleName, templateName)
    local vehicleScript = getScriptManager():getVehicle(vehicleName)
    if not vehicleScript then
        -- A warning, not error() -- one bad/renamed vehicle id must not
        -- stop every other registerUpgrades() call after it from running.
        print("HARMONIE Mechanical Advanced WARNING: vehicle script not found, skipped: " .. tostring(vehicleName))
        return
    end
    vehicleScript:Load(vehicleName, "{template! = " .. templateName .. ",}")
end

local function registerUpgrades(vehicleName)
    injectTemplate(vehicleName, "HARMONIE_MA_Bullbar")
    injectTemplate(vehicleName, "HARMONIE_MA_WindowArmor")
    injectTemplate(vehicleName, "HARMONIE_MA_CargoRack")
    injectTemplate(vehicleName, "HARMONIE_MA_PerformanceExhaust")
end

-- Every vehicle id below was confirmed by reading its actual
-- media/scripts/generated/vehicles/*_template.txt (or the vehicle's own
-- .txt when it doesn't use a separate template file) directly -- all of
-- them declare Engine, TruckBed, GasTank, SeatFrontLeft and
-- SeatFrontRight. Profession/livery re-skins (mail vans, police
-- variants, ambulances, dozens of named business vans, etc.) each
-- declare their own separate vehicle id too and are NOT covered here --
-- add them individually the same way if wanted, rather than assumed.
local CONFIRMED_VEHICLES = {
    "PickUpTruck",
    "Van",
    "SUV",
    "OffRoad",
    "CarNormal",
    "PickUpVan",
    "StepVan",
    "ModernCar",
    "ModernCar02",
    "CarLuxury",
    "SmallCar",
    "SmallCar02",
    "CarStationWagon",
    "SportsCar",
}

for _, vehicleName in ipairs(CONFIRMED_VEHICLES) do
    registerUpgrades(vehicleName)
end

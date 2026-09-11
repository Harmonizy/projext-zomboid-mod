--[[
    Registers all 5 HARMONIE Mechanical Advanced upgrades on the vanilla
    Pick-up Truck -- pure vanilla Build 42 vehicle-part APIs, no
    third-party mod dependency (previously depended on tsarslib's
    Tuning2 system; dropped after tsarslib's Workshop upload was
    removed by Steam for a Content Guidelines violation -- confirmed on
    the Workshop page directly).

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
        error("HARMONIE Mechanical Advanced: vehicle script not found: " .. tostring(vehicleName))
    end
    vehicleScript:Load(vehicleName, "{template! = " .. templateName .. ",}")
end

local function registerPickUpTruck()
    injectTemplate("PickUpTruck", "HARMONIE_MA_Bullbar")
    injectTemplate("PickUpTruck", "HARMONIE_MA_WindowArmor")
    injectTemplate("PickUpTruck", "HARMONIE_MA_CargoRack")
    injectTemplate("PickUpTruck", "HARMONIE_MA_PerformanceExhaust")
end

registerPickUpTruck()

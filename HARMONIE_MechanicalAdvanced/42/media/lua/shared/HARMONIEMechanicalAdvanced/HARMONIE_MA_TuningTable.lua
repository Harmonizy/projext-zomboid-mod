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

--[[
    Every one of these 152 ids was individually confirmed (not
    pattern-guessed) to declare all 5 required areas -- either directly
    in its own vehicle script, or by inheriting from a `template! = X`
    that itself was opened and confirmed to declare them. Full research
    notes: every non-trailer, non-wreck vehicle declaration across the
    whole media/scripts/generated/vehicles/ tree (all subfolders) came
    back confirmed; none were ambiguous.

    Deliberately EXCLUDED:
    - vehicle_trailer*.txt (Trailer, TrailerAdvert, TrailerCover,
      Trailer_Horsebox, Trailer_Livestock) -- towed, not driven, no
      Engine/Seat areas at all, neverSpawnKey=true on most.
    - The whole burntAndSmashedVehicles/ folder (~98 declarations,
      including the *Smashed* variants that DO technically inherit
      full areas from one of these 14 base templates) -- these are
      non-drivable/decorative wreck props (neverSpawnKey=true, no real
      wheels, no seats), excluded as a deliberate scope choice, not an
      oversight. Add them by pattern later if ever wanted.
]]--
local CONFIRMED_VEHICLES = {
    -- The 14 base templates
    "PickUpTruck", "Van", "SUV", "OffRoad", "CarNormal", "PickUpVan",
    "StepVan", "ModernCar", "ModernCar02", "CarLuxury", "SmallCar",
    "SmallCar02", "CarStationWagon", "SportsCar",

    -- Pick-up Truck liveries/variants
    "PickUpTruck_Camo", "PickUpTruckJPLandscaping", "PickUpTruckLightsAirport",
    "PickUpTruckLightsAirportSecurity", "PickUpTruckLightsFire",
    "PickUpTruckLightsFossoil", "PickUpTruckLightsRanger", "PickUpTruckMccoy",

    -- Pick-up Van liveries/variants
    "PickUpVan_Camo", "PickUpVanBrickingIt", "PickUpVanBuilder",
    "PickUpVanCallowayLandscaping", "PickUpVanHeltonMetalWorking",
    "PickUpVanKimbleKonstruction", "PickUpVanLightsCarpenter",
    "PickUpVanLightsFire", "PickUpVanLightsFossoil",
    "PickUpVanLightsKentuckyLumber", "PickUpVanLightsLouisvilleCounty",
    "PickUpVanLightsPolice", "PickUpVanLightsRanger",
    "PickUpVanLightsStatePolice", "PickUpVanMarchRidgeConstruction",
    "PickUpVanMccoy", "PickUpVanMetalworker", "PickUpVanWeldingbyCamille",
    "PickUpVanYingsWood",

    -- StepVan liveries/variants
    "StepVanAirportCatering", "StepVanMail", "StepVan_Blacksmith",
    "StepVan_Butchers", "StepVan_Cereal", "StepVan_Citr8",
    "StepVan_CompleteRepairShop", "StepVan_Florist", "StepVan_Genuine_Beer",
    "StepVan_Glass", "StepVan_Heralds", "StepVan_HuangsLaundry",
    "StepVan_Jorgensen", "StepVan_LouisvilleMotorShop",
    "StepVan_LouisvilleSWAT", "StepVan_MarineBites", "StepVan_Masonry",
    "StepVan_Mechanic", "StepVan_MobileLibrary", "StepVan_Plonkies",
    "StepVan_Propane", "StepVan_RandisPlants", "StepVan_Scarlet",
    "StepVan_SmartKut", "StepVan_SouthEasternHosp", "StepVan_SouthEasternPaint",
    "StepVan_USL", "StepVan_Zippee",

    -- Van liveries/variants (dozens of named businesses + seat variants)
    "VanAmbulance", "VanBeckmans", "VanBrewsterHarbin", "VanBuilder",
    "VanCarpenter", "VanCoastToCoast", "VanDeerValley", "VanFossoil",
    "VanGardenGods", "VanGardener", "VanGreenes", "VanJohnMcCoy",
    "VanJonesFabrication", "VanKerrHomes", "VanKnobCreekGas", "VanKnoxCom",
    "VanKorshunovs", "VanLouisvilleLandscaping", "VanMail", "VanMccoy",
    "VanMechanic", "VanMeltingPointMetal", "VanMetalheads", "VanMetalworker",
    "VanMicheles", "VanMobileMechanics", "VanMooreMechanics", "VanOldMill",
    "VanOvoFarm", "VanPennSHam", "VanPlattAuto", "VanPluggedInElectrics",
    "VanRadio", "VanRadio_3N", "VanRiversideFabrication", "VanRosewoodworking",
    "VanSchwabSheetMetal", "VanSeats", "VanSeatsAirportShuttle",
    "VanSeats_Creature", "VanSeats_LadyDelighter", "VanSeats_Mural",
    "VanSeats_Prison", "VanSeats_Space", "VanSeats_Trippy", "VanSeats_Valkyrie",
    "VanSpiffo", "VanTreyBaines", "VanUncloggers", "VanUtility",
    "VanWPCarpentry", "Van_Blacksmith", "Van_BugWipers", "Van_Charlemange_Beer",
    "Van_CraftSupplies", "Van_Glass", "Van_HeritageTailors", "Van_KnoxDisti",
    "Van_Leather", "Van_LectroMax", "Van_Locksmith", "Van_Masonry",
    "Van_MassGenFac", "Van_Perfick_Potato", "Van_Transit", "Van_VoltMojo",

    -- Cars: sports/taxi/wagon/modern variants
    "SportsCar_ez", "CarTaxi", "CarTaxi2", "CarStationWagon2", "ModernCar_Martin",

    -- Police/fire/lights standalones (PickUpTruckLightsFire, PickUpVanLightsFire,
    -- PickUpVanLightsPolice already listed above in their family's variant group)
    "CarLightsPolice",

    -- Regional police (PickUpVanLightsLouisvilleCounty, PickUpVanLightsStatePolice
    -- already listed above in their family's variant group)
    "CarLightsBulletinSheriff", "CarLightsKST", "CarLightsLouisvilleCounty",
    "CarLightsMuldraughPolice", "ModernCarLightsCityLouisvillePD",
    "ModernCarLightsMeadeSheriff",

    -- One-hop-inherited liveries (CarLightsRanger, ModernCarLightsWestPoint,
    -- race cars)
    "CarLightsRanger", "ModernCarLightsWestPoint",
    "RaceCar12", "RaceCar34", "RaceCar58",
}

for _, vehicleName in ipairs(CONFIRMED_VEHICLES) do
    registerUpgrades(vehicleName)
end

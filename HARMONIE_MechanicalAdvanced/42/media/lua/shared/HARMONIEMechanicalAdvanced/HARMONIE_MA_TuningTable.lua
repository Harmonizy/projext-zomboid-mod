--[[
    Step 1 of the build order: register ONLY the bullbar on the vanilla
    Pick-up Truck, reusing tsarslib's own ATA2Bullbars template and
    ATA2.ATABullbar1Item -- zero new assets, zero new items. This is the
    riskiest unverified step (ATA2Tuning_AddNewCars is never actually
    called anywhere in tsarslib or StandardizedVehicleUpgrades3Core, so
    there is no known-working example to copy from -- this needs an
    in-game check before anything else gets built on top of it).
]]--

require "HARMONIEMechanicalAdvanced/HARMONIE_MA_Dependency"

local NewCarTuningTable = {}

NewCarTuningTable["PickUpTruck"] = {
    addPartsFromVehicleScript = {
        "ATA2Bullbars",
    },
    parts = {
        ATA2Bullbar = {
            HARMONIE_MA_Bullbar1 = {
                icon = "Item_ATABullbar1Item",
                category = "Bullbars",
                spawnChance = 15,
                install = {
                    area = "Engine",
                    use = {
                        ["ATA2__ATABullbar1Item"] = 1,
                    },
                    tools = {
                        both = "Base.Wrench",
                    },
                    skills = {
                        Mechanics = 2,
                    },
                    time = 80,
                    weight = 8,
                },
                uninstall = {
                    area = "Engine",
                    result = {
                        ["ATA2__ATABullbar1Item"] = 1,
                    },
                    time = 60,
                },
            },
        },
    },
}

ATA2Tuning_AddNewCars(NewCarTuningTable)

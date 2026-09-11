--[[
    Registers all 5 HARMONIE Mechanical Advanced upgrades on the vanilla
    Pick-up Truck via tsarslib's Tuning2 API. This is the piece
    StandardizedVehicleUpgrades3Core never actually did -- it defined a
    huge template table but never called ATA2Tuning_AddNewCars and never
    touched a vehicle script, so it added nothing playable by itself.

    2 parts reuse tsarslib's own templates + items (zero new assets):
      - ATA2Bullbar            (template ATA2Bullbars)
      - ATA2ProtectionWindshield / ATA2ProtectionWindowFrontLeft/Right
                                (template ATA2Protection)
    2 parts are our own new templates + new items:
      - HARMONIE_MA_CargoRack
      - HARMONIE_MA_PerfExhaust
]]--

require "HARMONIEMechanicalAdvanced/HARMONIE_MA_Dependency"

local NewCarTuningTable = {}

NewCarTuningTable["PickUpTruck"] = {
    addPartsFromVehicleScript = {
        "ATA2Bullbars",
        "ATA2Protection",
        "HARMONIE_MA_CargoRack",
        "HARMONIE_MA_PerformanceExhaust",
    },
    parts = {
        ATA2Bullbar = {
            HARMONIE_MA_Bullbar1 = {
                icon = "Item_ATABullbar1Item",
                category = "Bullbars",
                spawnChance = 15,
                install = {
                    area = "Engine",
                    use = { ["ATA2__ATABullbar1Item"] = 1 },
                    tools = { both = "Base.Wrench" },
                    skills = { Mechanics = 2 },
                    time = 80,
                    weight = 8,
                },
                uninstall = {
                    area = "Engine",
                    result = { ["ATA2__ATABullbar1Item"] = 1 },
                    time = 60,
                },
            },
        },

        ATA2ProtectionWindshield = {
            HARMONIE_MA_WindowArmor = {
                icon = "Item_HARMONIE_MA_WindowArmorPlate",
                category = "ProtectionWindow",
                spawnChance = 8,
                protection = { "Windshield" },
                install = {
                    area = "Engine",
                    use = { ["HARMONIEMechanicalAdvanced__WindowArmorPlate"] = 1 },
                    tools = { bodylocation = "Base.WeldingMask" },
                    skills = { MetalWelding = 2 },
                    time = 70,
                    weight = 6,
                },
                uninstall = {
                    area = "Engine",
                    result = { ["Base__SmallSheetMetal"] = 1 },
                    time = 40,
                },
            },
        },
        ATA2ProtectionWindowFrontLeft = {
            HARMONIE_MA_WindowArmor = {
                icon = "Item_HARMONIE_MA_WindowArmorPlate",
                category = "ProtectionWindow",
                spawnChance = 8,
                protection = { "WindowFrontLeft" },
                install = {
                    area = "SeatFrontLeft",
                    use = { ["HARMONIEMechanicalAdvanced__WindowArmorPlate"] = 1 },
                    tools = { bodylocation = "Base.WeldingMask" },
                    skills = { MetalWelding = 2 },
                    time = 70,
                    weight = 6,
                },
                uninstall = {
                    area = "SeatFrontLeft",
                    result = { ["Base__SmallSheetMetal"] = 1 },
                    time = 40,
                },
            },
        },
        ATA2ProtectionWindowFrontRight = {
            HARMONIE_MA_WindowArmor = {
                icon = "Item_HARMONIE_MA_WindowArmorPlate",
                category = "ProtectionWindow",
                spawnChance = 8,
                protection = { "WindowFrontRight" },
                install = {
                    area = "SeatFrontRight",
                    use = { ["HARMONIEMechanicalAdvanced__WindowArmorPlate"] = 1 },
                    tools = { bodylocation = "Base.WeldingMask" },
                    skills = { MetalWelding = 2 },
                    time = 70,
                    weight = 6,
                },
                uninstall = {
                    area = "SeatFrontRight",
                    result = { ["Base__SmallSheetMetal"] = 1 },
                    time = 40,
                },
            },
        },

        HARMONIE_MA_CargoRack = {
            HARMONIE_MA_CargoRackModel = {
                icon = "Item_HARMONIE_MA_CargoRackFrame",
                category = "Trunks",
                spawnChance = 10,
                install = {
                    area = "TruckBed",
                    use = { ["HARMONIEMechanicalAdvanced__CargoRackFrame"] = 1 },
                    tools = { bodylocation = "Base.WeldingMask" },
                    skills = { MetalWelding = 3 },
                    time = 100,
                    weight = 10,
                },
                uninstall = {
                    area = "TruckBed",
                    result = { ["Base__MetalBar"] = 1 },
                    time = 60,
                },
            },
        },

        HARMONIE_MA_PerfExhaust = {
            HARMONIE_MA_PerfExhaustModel = {
                icon = "Item_HARMONIE_MA_PerformanceExhaustKit",
                category = "Another",
                spawnChance = 5,
                install = {
                    area = "Engine",
                    use = { ["HARMONIEMechanicalAdvanced__PerformanceExhaustKit"] = 1 },
                    tools = { both = "Base.Wrench" },
                    skills = { Mechanics = 4 },
                    time = 120,
                    weight = 6,
                },
                uninstall = {
                    area = "Engine",
                    result = { ["Base__MetalPipe"] = 1 },
                    time = 70,
                },
            },
        },
    },
}

ATA2Tuning_AddNewCars(NewCarTuningTable)

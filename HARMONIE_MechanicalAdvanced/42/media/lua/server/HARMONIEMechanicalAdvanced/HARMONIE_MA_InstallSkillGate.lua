--[[
    Vehicles.InstallTest.Default's own skill check
    (VehicleUtils.testPerks) is commented out in this game version --
    confirmed by reading Vehicles.lua directly: skills only feed
    VehicleUtils.calculateInstallationSuccess (a success-CHANCE
    modifier), never gate whether the attempt is even allowed. That's
    why a player under the stated skill minimum could still install
    every part -- there was never a hard floor, only worse odds.

    These wrap Vehicles.InstallTest.Default/UninstallTest.Default (so
    all the normal tool/item checks still apply) and additionally
    require the real minimum skill(s) before returning true at all.
    Perks.FromString(name) and the ";"-separated multi-skill format are
    copied directly from vanilla's own
    VehicleUtils.getPerksTableForChr (Vehicles.lua) -- same parsing,
    not a guess.

    The "skills = ..." field in each part's install/uninstall table is
    kept alongside this -- once the hard floor here is met, it still
    drives calculateInstallationSuccess's pass/fail chance on top.
]]--

if not HARMONIE_MA then HARMONIE_MA = {} end
HARMONIE_MA.InstallTest = HARMONIE_MA.InstallTest or {}
HARMONIE_MA.UninstallTest = HARMONIE_MA.UninstallTest or {}

local function meetsSkillFloor(chr, skillSpec)
    for _, entry in ipairs(skillSpec:split(";")) do
        local name, levelStr = VehicleUtils.split(entry, ":")
        local perk = Perks.FromString(name)
        if not perk or chr:getPerkLevel(perk) < tonumber(levelStr) then
            return false
        end
    end
    return true
end

function HARMONIE_MA.InstallTest.Mechanics5(vehicle, part, chr)
    if not Vehicles.InstallTest.Default(vehicle, part, chr) then return false end
    return meetsSkillFloor(chr, "Mechanics:5")
end

function HARMONIE_MA.UninstallTest.Mechanics5(vehicle, part, chr)
    if not Vehicles.UninstallTest.Default(vehicle, part, chr) then return false end
    return meetsSkillFloor(chr, "Mechanics:5")
end

function HARMONIE_MA.InstallTest.MetalWelding3(vehicle, part, chr)
    if not Vehicles.InstallTest.Default(vehicle, part, chr) then return false end
    return meetsSkillFloor(chr, "MetalWelding:3")
end

function HARMONIE_MA.UninstallTest.MetalWelding3(vehicle, part, chr)
    if not Vehicles.UninstallTest.Default(vehicle, part, chr) then return false end
    return meetsSkillFloor(chr, "MetalWelding:3")
end

function HARMONIE_MA.InstallTest.Mechanics5MetalWelding3(vehicle, part, chr)
    if not Vehicles.InstallTest.Default(vehicle, part, chr) then return false end
    return meetsSkillFloor(chr, "Mechanics:5;MetalWelding:3")
end

function HARMONIE_MA.UninstallTest.Mechanics5MetalWelding3(vehicle, part, chr)
    if not Vehicles.UninstallTest.Default(vehicle, part, chr) then return false end
    return meetsSkillFloor(chr, "Mechanics:5;MetalWelding:3")
end

-- MFS B42 patch: automatic-fire RPM targets.
-- The original files use CyclicRateMultiplier. These values preserve that intent
-- against a 600 RPM B42 reference rate and provide one central place to tune guns.
-- A 600 entry records the engine-reference baseline where no legacy multiplier exists.
-- For creating a new weapon, you should only add the new guntype name here and the designd RPM number in this chart
-- Pistol is using different logic now, so set to global 930 to indicate current global RPM of 900
AWCWF_ExactRPM = AWCWF_ExactRPM or {
    ["AA12_cat"] = 360,
    ["AEK971_cat"] = 900,
    ["AK103_cat"] = 660,
    ["AK12_cat"] = 860,
    ["AKS74U_cat"] = 860,
    ["AMB17_cat"] = 1080,
    ["AN94_cat"] = 1140,
    ["ARX200_cat"] = 900,
    ["AS_VAL_MOD4_cat"] = 900,
    ["AS_VAL_cat"] = 900,
    ["AssaultRifle"] = 600,
    ["BAR_cat"] = 600,
    ["BerettaM93R_cat"] = 930,
    ["Christine45_cat"] = 960,
    ["EMP_cat"] = 1140,
    ["FAL_cat"] = 660,
    ["FN_Evolys_cat"] = 780,
    ["G18_cat"] = 930,
    ["G34_cat"] = 930,
    ["Groza_cat"] = 1080,
    ["HK416_cat"] = 860,
    ["HK51_cat"] = 1020,
    ["HoneyBadger_cat"] = 1020,
    ["KS1_KAC_cat"] = 930,
    ["KrissVector_cat"] = 1140,
    ["LWMMG_cat"] = 900,
    ["M1873_cat"] = 600,
    ["M1918_cat"] = 600,
    ["M1919a6_cat"] = 720,
    ["M240_cat"] = 780,
    ["M4A1S_cat"] = 860,
    ["M4Mk18_cat"] = 860,
    ["M7_cat"] = 900,
    ["M91_cat"] = 900,
    ["MCX_cat"] = 960,
    ["MK18_cat"] = 960,
    ["MP7_cat"] = 930,
    ["NoveskeN4_cat"] = 900,
    ["PKM_cat"] = 720,
    ["QBU191_cat"] = 600,
    ["QBZ191_cat"] = 960,
    ["QBZ192_cat"] = 1080,
    ["QJY201_cat"] = 960,
    ["REAPR_cat"] = 720,
    ["RPK16_cat"] = 900,
    ["SAI_GRY_cat"] = 960,
    ["SG553_cat"] = 900,
    ["SIGP226_cat"] = 930,
    ["SRM3_cat"] = 1020,
    ["Saiga12_cat"] = 360,
    ["ScarH_cat"] = 900,
    ["Striker12_cat"] = 360,
    ["Thompson_cat"] = 600,
    ["Type81_cat"] = 900,
    ["UMP45_cat"] = 1020,
    ["URG_S_cat"] = 1020,
    ["VSSM_cat"] = 900,
    ["lewis_cat"] = 600,
    ["mg338_cat"] = 660,
    ["minigun_cat"] = 1140,
    ["M134_cat"] = 1140,
    ["mk47_cat"] = 660,
    ["mp5_cat"] = 1080,
    ["origin12_cat"] = 360,
    ["uzi_cat"] = 930,
}

-- RC4-1: configured RPM remains the weapon-design source. The engine receives
-- only one of the calibrated cyclic values below; never derive cyclic by scaling
-- configured RPM. This whitelist bypasses the known 1.8-2.9 cyclic deadzone and
-- the cyclic 1.4 no-projectile alias.
-- This calibration table should not be changed at anytime unless new calibration test is being done
-- RC4-2 update find that this table is only for two-hand weapon, pistol need another calibration table
-- RC5: cyclic = 1.0 is for pistol as current research shows it can not be changed at all
AWCWF_RPMCalibration = {
    { maxRPM = 300,       displayRPM = 300,  cyclic = 1.0 },
    { maxRPM = 500,       displayRPM = 400,  cyclic = 1.6 },
    { maxRPM = 660,       displayRPM = 600,  cyclic = 3.0 },
    { maxRPM = 790,       displayRPM = 720,  cyclic = 4.0 },
    { maxRPM = 880,       displayRPM = 860,  cyclic = 4.5 },
    { maxRPM = 930,       displayRPM = 900,  cyclic = 5.5 },
    { maxRPM = 990,       displayRPM = 960,  cyclic = 6.2 },
    { maxRPM = 1075,      displayRPM = 1020, cyclic = 6.8 },
    { maxRPM = math.huge, displayRPM = 1130, cyclic = 8.0 },
}

AWCWF_RPMDeadzone = {
    minCyclic = 1.8,
    maxCyclic = 2.9,
    noProjectileAliases = { [1.4] = true },
}

local function getWeaponType(weaponOrType)
    return type(weaponOrType) == "string" and weaponOrType or
        (weaponOrType and weaponOrType.getType and weaponOrType:getType())
end

function AWCWF_GetConfiguredRPM(weaponOrType)
    local weaponType = getWeaponType(weaponOrType)
    return weaponType and AWCWF_ExactRPM[weaponType] or nil
end

function AWCWF_ResolveRPM(weaponOrRPM)
    local configuredRPM = type(weaponOrRPM) == "number" and weaponOrRPM or
        AWCWF_GetConfiguredRPM(weaponOrRPM)
    if type(configuredRPM) ~= "number" then return nil end

    for index, calibration in ipairs(AWCWF_RPMCalibration) do
        if configuredRPM <= calibration.maxRPM then
            return calibration, configuredRPM, index
        end
    end
    return nil
end

function AWCWF_IsCalibratedCyclic(cyclic)
    if type(cyclic) ~= "number" then return false end
    for _, calibration in ipairs(AWCWF_RPMCalibration) do
        if math.abs(cyclic - calibration.cyclic) < 0.0001 then return true end
    end
    return false
end

function AWCWF_GetDisplayRPM(weaponOrType)
    local calibration = AWCWF_ResolveRPM(weaponOrType)
    return calibration and calibration.displayRPM or nil
end

function AWCWF_GetCalibratedCyclic(weaponOrType)
    local calibration = AWCWF_ResolveRPM(weaponOrType)
    return calibration and calibration.cyclic or nil
end

-- Compatibility API: "applied RPM" now means the calibrated/display RPM.
-- Additional return values expose the engine cyclic and calibration index.
function AWCWF_GetAppliedRPM(weaponOrType)
    local calibration, configuredRPM, index = AWCWF_ResolveRPM(weaponOrType)
    if not calibration then return nil end
    return calibration.displayRPM, "CalibratedRPM", 1.0, 1.0,
        calibration.cyclic, index, configuredRPM
end

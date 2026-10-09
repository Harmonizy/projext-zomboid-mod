require "Gun_Vars/Weapon_Ability/AWCWF_Exact_RPM"

-- RC5A-Test2 production candidate.
--
-- The RC4 implementation resolved and wrote the complete calibration on equip
-- and again on every OnWeaponSwing. Reassigning the same eight ModData fields
-- cannot grow the table, but it needlessly dirties persistent state; changing
-- CyclicRateMultiplier during the swing is also a candidate trigger for the
-- reported local presentation-only ghost shot.
--
-- This version keeps the swing hook as a recovery guard, but a normal shot does
-- only one runtime cyclic read. Resolution is cached per weapon, ModData is
-- checked only when the weapon is first seen/equipped, and no setter or ModData
-- assignment occurs unless the current value differs from the expected value.

local CYCLIC_EPSILON = 0.0001
local warnedWeaponTypes = {}
local lastWeaponByPlayer = setmetatable({}, { __mode = "k" })
local calibrationByWeapon = setmetatable({}, { __mode = "k" })

MFSRPMOptimizationDiagnostics = {
    version = "RC5A-Test2",
    equipChecks = 0,
    swingChecks = 0,
    resolves = 0,
    cyclicWrites = 0,
    swingRecoveries = 0,
    metadataWrites = 0,
}

local OptDiag = MFSRPMOptimizationDiagnostics

local function warnOnce(weaponType, message)
    local key = tostring(weaponType) .. "|" .. tostring(message)
    if warnedWeaponTypes[key] then return end
    warnedWeaponTypes[key] = true
    print("[MFS RPM] weapon=" .. tostring(weaponType) .. " " .. tostring(message))
end

local function isRangedWeapon(weapon)
    return weapon and weapon.IsWeapon and weapon:IsWeapon() and weapon:isRanged()
end

local function readCurrentCyclic(weapon)
    if not weapon or not weapon.getCyclicRateMultiplier then return nil end
    local ok, value = pcall(function() return weapon:getCyclicRateMultiplier() end)
    if ok and type(value) == "number" then return value end
    return nil
end

local function cyclicMatches(current, expected)
    return type(current) == "number" and type(expected) == "number" and
        math.abs(current - expected) < CYCLIC_EPSILON
end

local function resolveCalibration(weapon)
    local weaponType = weapon:getType()
    local cached = calibrationByWeapon[weapon]
    if cached and cached.weaponType == weaponType then
        if cached.unavailable then return nil end
        return cached
    end

    local calibration, configuredRPM, calibrationIndex
    if AWCWF_ResolveRPM then
        calibration, configuredRPM, calibrationIndex = AWCWF_ResolveRPM(weapon)
    end
    if not calibration then
        calibrationByWeapon[weapon] = { weaponType = weaponType, unavailable = true }
        return nil
    end

    local cyclic = calibration.cyclic
    if not AWCWF_IsCalibratedCyclic or not AWCWF_IsCalibratedCyclic(cyclic) then
        warnOnce(weaponType, "rejected uncalibrated cyclic=" .. tostring(cyclic))
        calibrationByWeapon[weapon] = { weaponType = weaponType, unavailable = true }
        return nil
    end
    if not weapon.setCyclicRateMultiplier then
        warnOnce(weaponType, "cannot apply calibrated cyclic: setter unavailable")
        calibrationByWeapon[weapon] = { weaponType = weaponType, unavailable = true }
        return nil
    end

    cached = {
        weaponType = weaponType,
        cyclic = cyclic,
        configuredRPM = configuredRPM,
        displayRPM = calibration.displayRPM,
        calibrationIndex = calibrationIndex,
        metadataChecked = false,
        cyclicApplied = false,
    }
    calibrationByWeapon[weapon] = cached
    OptDiag.resolves = OptDiag.resolves + 1
    return cached
end

local function setDataIfChanged(data, key, value)
    if data[key] == value then return 0 end
    data[key] = value
    return 1
end

local function updateMetadataIfNeeded(weapon, cached)
    if cached.metadataChecked then return 0 end
    cached.metadataChecked = true

    local data = weapon:getModData()
    local writes = 0
    writes = writes + setDataIfChanged(data, "AWCWF_ConfiguredRPM", cached.configuredRPM)
    writes = writes + setDataIfChanged(data, "AWCWF_DisplayRPM", cached.displayRPM)
    writes = writes + setDataIfChanged(data, "AWCWF_AppliedRPM", cached.displayRPM)
    writes = writes + setDataIfChanged(data, "AWCWF_CalibratedCyclic", cached.cyclic)
    writes = writes + setDataIfChanged(data, "AWCWF_RPMCalibrationIndex", cached.calibrationIndex)
    writes = writes + setDataIfChanged(data, "AWCWF_RPMCategory", "CalibratedRPM")
    writes = writes + setDataIfChanged(data, "AWCWF_RPMCategoryScale", 1.0)
    writes = writes + setDataIfChanged(data, "AWCWF_RPMGlobalScale", 1.0)
    OptDiag.metadataWrites = OptDiag.metadataWrites + writes
    return writes
end

local function ensureCyclic(weapon, cached, reason)
    -- Fold any weapon-part cyclic bonus (written by AWCWF_ApplyPartStats) into
    -- the calibrated cyclic.  The bonus lives in ModData and can change on
    -- attach/detach, so it is read fresh on every check rather than cached.
    local partCyclicBonus = 0
    local modData = weapon:getModData()
    if modData and modData.AWCWF_PartCyclicBonus then
        partCyclicBonus = modData.AWCWF_PartCyclicBonus
    end
    local expectedCyclic = cached.cyclic + partCyclicBonus

    local current = readCurrentCyclic(weapon)
    if cyclicMatches(current, expectedCyclic) then
        cached.cyclicApplied = true
        return false
    end

    -- If this game build cannot read the runtime value, apply once when the
    -- weapon is first encountered, but never regress to a setter on every shot.
    if current == nil and cached.cyclicApplied then return false end

    weapon:setCyclicRateMultiplier(expectedCyclic)
    cached.cyclicApplied = true
    OptDiag.cyclicWrites = OptDiag.cyclicWrites + 1

    if reason == "swing" then
        OptDiag.swingRecoveries = OptDiag.swingRecoveries + 1
        print("[MFS RPM OPT] recovered weapon=" .. tostring(cached.weaponType)
            .. " previousCyclic=" .. tostring(current)
            .. " expectedCyclic=" .. tostring(expectedCyclic))
    end
    return true
end

local function applyExactRPM(weapon, reason)
    if not isRangedWeapon(weapon) then return end

    local cached = resolveCalibration(weapon)
    if not cached then return end

    if reason == "swing" then
        OptDiag.swingChecks = OptDiag.swingChecks + 1
    else
        OptDiag.equipChecks = OptDiag.equipChecks + 1
    end

    local cyclicWritten = ensureCyclic(weapon, cached, reason)
    local metadataWrites = updateMetadataIfNeeded(weapon, cached)

    -- One line per equip/first encounter, never one line per shot. An ordinary
    -- swing produces output only if another system changed the runtime cyclic.
    if reason ~= "swing" then
        print("[MFS RPM OPT] equip weapon=" .. tostring(cached.weaponType)
            .. " cyclic=" .. tostring(cached.cyclic)
            .. " cyclicWrite=" .. tostring(cyclicWritten)
            .. " metadataWrites=" .. tostring(metadataWrites))
    end
end

local function onPlayerUpdate(playerObj)
    if not playerObj then return end
    local weapon = playerObj:getPrimaryHandItem()
    local previous = lastWeaponByPlayer[playerObj]
    local marker = weapon or false
    if marker ~= previous then
        lastWeaponByPlayer[playerObj] = marker
        applyExactRPM(weapon, "equip")
    end
end

local function onWeaponSwing(_, weapon)
    applyExactRPM(weapon, "swing")
end

print("[MFS RPM OPT] RC5A-Test2 idempotent resolver loaded categories=" ..
    tostring(AWCWF_RPMCalibration and #AWCWF_RPMCalibration or 0))
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnWeaponSwing.Add(onWeaponSwing)

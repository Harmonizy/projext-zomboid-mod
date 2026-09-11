--[[
    Our own update hooks -- deliberately NOT touching ATATuning2.* or
    Vehicles.* by redefinition (see the SVU3Core study). Run from our
    own templates' lua { update = ... } instead.

    Every hook below prints a one-time "alive" confirmation to
    console.txt the first time it actually runs for a given part
    instance (tracked via part:getModData(), survives save/reload), so
    it's possible to verify from the log alone whether update = ... is
    firing at all for a given install -- open console.txt and search
    for "HARMONIE Mechanical Advanced:" after installing a part and
    driving/waiting a bit.
]]--

if not HARMONIE_MA then HARMONIE_MA = {} end
if not HARMONIE_MA.Update then HARMONIE_MA.Update = {} end

local function logAliveOnce(part, label)
    local data = part:getModData()
    if not data.HARMONIE_updateConfirmed then
        data.HARMONIE_updateConfirmed = true
        print("HARMONIE Mechanical Advanced: " .. label .. " update hook is running (part id " .. tostring(part:getId()) .. ").")
    end
end

local BONUS_POWER_MULT = 1.15 -- +15% engine force at full part condition
local STEALTH_LOUDNESS_MULT = 0.6 -- -40% engine loudness at full part condition
local FUEL_QUALITY_BONUS = 20 -- up to +20 engine quality at full part condition

-- The 3 items that can fill the (single, mutually-exclusive) engine
-- tune slot -- see itemType = A;B;C, specificItem = false on
-- HARMONIE_MA_PerfExhaust in the vehicle template, copied from
-- vanilla's own Radio part pattern.
local ENGINE_TUNE_ITEMS = {
    ["HARMONIEMechanicalAdvanced.PerformanceExhaustKit"] = true,
    ["HARMONIEMechanicalAdvanced.StealthExhaustKit"] = true,
    ["HARMONIEMechanicalAdvanced.FuelEfficientTuneKit"] = true,
}

--[[
    One part slot, three mutually-exclusive kits -- only one can ever
    be installed at a time, so exactly one branch below is live for a
    given vehicle. Each branch always recomputes its OWN stat from a
    stable base (the script's static force/loudness, verified real at
    Vehicles.lua:262-287) and leaves the other two parameters at their
    unmodified vanilla default, so calling this every tick is
    idempotent and switching kits (uninstall one, install another)
    can't leave a stacked bonus behind:

      - Performance: +engine force (script:getEngineForce() base).
      - Stealth: -engine loudness, which vanilla itself feeds straight
        into zombie attraction (engineLoudness * SandboxVars.
        ZombieAttractionMultiplier, Vehicles.lua:279-280) -- a real,
        verifiable effect, not a cosmetic one.
      - Fuel-Efficient: +engine quality, which vanilla's own GasTank
        update uses to reduce fuel burn (qualityMultiplier =
        ((100 - vehicle:getEngineQuality()) / 200) + 1, Vehicles.lua:
        466) -- higher quality means a smaller multiplier means less
        gas consumed per tick. Quality has no stable "script base" to
        recompute from like force/loudness do, so we capture the
        vehicle's current quality once (on first install) as our own
        base and add the bonus on top of THAT, not on top of whatever
        quality happens to be right now -- otherwise repeated calls
        would compound the bonus every tick.
]]--
function HARMONIE_MA.Update.EngineTune(vehicle, part, elapsedMinutes)
    local item = part:getInventoryItem()
    if not item then return end

    local script = vehicle:getScript()
    if not script then return end

    local fullType = item:getFullType()
    if not ENGINE_TUNE_ITEMS[fullType] then return end

    logAliveOnce(part, "EngineTune")

    -- Vehicle parts have no getConditionMax() (that's an InventoryItem
    -- method) -- vanilla itself always uses a hardcoded 100 for part
    -- condition (e.g. part:setCondition(100) in Vehicles.lua).
    local conditionRatio = part:getCondition() / 100
    local baseForce = script:getEngineForce()
    local baseLoudness = (script:getEngineLoudness() or 100) * (SandboxVars.ZombieAttractionMultiplier or 1)

    local newForce = baseForce
    local newLoudness = baseLoudness
    local newQuality = vehicle:getEngineQuality()

    local data = part:getModData()
    if fullType == "HARMONIEMechanicalAdvanced.PerformanceExhaustKit" then
        data.HARMONIE_baseQuality = nil
        newForce = baseForce * (1 + (BONUS_POWER_MULT - 1) * conditionRatio)
    elseif fullType == "HARMONIEMechanicalAdvanced.StealthExhaustKit" then
        data.HARMONIE_baseQuality = nil
        newLoudness = baseLoudness * (1 - (1 - STEALTH_LOUDNESS_MULT) * conditionRatio)
    elseif fullType == "HARMONIEMechanicalAdvanced.FuelEfficientTuneKit" then
        if not data.HARMONIE_baseQuality then
            data.HARMONIE_baseQuality = vehicle:getEngineQuality()
        end
        newQuality = math.min(100, data.HARMONIE_baseQuality + FUEL_QUALITY_BONUS * conditionRatio)
    end

    -- Only print (and only bother re-applying) when a value actually
    -- changes -- avoids spamming console.txt every tick while still
    -- proving, from the log, that the right bonus is really being
    -- computed and applied for the specific kit installed.
    local signature = string.format("%.0f|%.0f|%.0f", newForce, newLoudness, newQuality)
    if data.HARMONIE_lastTune ~= signature then
        data.HARMONIE_lastTune = signature
        vehicle:setEngineFeature(newQuality, newLoudness, newForce)
        print(string.format(
            "HARMONIE Mechanical Advanced: EngineTune (%s) set engine to quality %.0f, loudness %.0f, force %.0f (condition %d%%).",
            fullType, newQuality, newLoudness, newForce, part:getCondition()
        ))
    end
end

--[[
    A real, verified protective effect this time -- found by reading
    vanilla's own Vehicles.Update.Tire (confirmed running code, not
    decompiled bytecode): tires lose air (getContainerContentAmount)
    and condition while driving over 10 km/h with the engine running,
    and can blow out entirely if either gets too low. Every API used
    below (vehicle:isEngineRunning, vehicle:getCurrentSpeedKmHour,
    part:getContainerContentAmount/setContainerContentAmount,
    part:getInventoryItem():getMaxCapacity(), part:getCondition/
    setCondition) is copied directly from that real function, not
    guessed -- this is the lesson from the getFrontEndHealth() failure
    applied properly: only rely on APIs seen actually working in real
    Lua source.

    We never touch Vehicles.Update.Tire itself (per the
    don't-redefine-vanilla-functions rule) -- instead, while installed,
    the bullbar periodically tops up air and condition on BOTH front
    tires (TireFrontLeft/TireFrontRight -- real, universal part ids
    confirmed across every vehicle template read this whole session),
    partially offsetting vanilla's own wear instead of preventing it
    outright. Costs the bullbar's own condition each time it helps, so
    it still wears down from use, just for an actual reason now.
]]--
local BULLBAR_TIRE_SAVE_CHANCE = 0.05
local FRONT_TIRE_IDS = { "TireFrontLeft", "TireFrontRight" }

local function topUpTire(vehicle, tirePart)
    local tireItem = tirePart:getInventoryItem()
    if not tireItem then return false end

    local helped = false
    if tirePart:getContainerContentAmount() > 0 and tirePart:getContainerContentAmount() < tireItem:getMaxCapacity() then
        tirePart:setContainerContentAmount(tirePart:getContainerContentAmount() + 1, false, true)
        helped = true
    end
    if tirePart:getCondition() > 0 and tirePart:getCondition() < 100 then
        tirePart:setCondition(tirePart:getCondition() + 1)
        vehicle:transmitPartCondition(tirePart)
        helped = true
    end
    return helped
end

function HARMONIE_MA.Update.Bullbar(vehicle, part, elapsedMinutes)
    if not part:getInventoryItem() then return end

    logAliveOnce(part, "Bullbar")

    if part:getCondition() <= 0 then return end
    if not vehicle:isEngineRunning() then return end
    if vehicle:getCurrentSpeedKmHour() <= 10 then return end

    if ZombRandFloat(0, 1) < BULLBAR_TIRE_SAVE_CHANCE then
        local helpedAny = false
        for _, tireId in ipairs(FRONT_TIRE_IDS) do
            local tirePart = vehicle:getPartById(tireId)
            if tirePart and topUpTire(vehicle, tirePart) then
                helpedAny = true
            end
        end
        if helpedAny then
            part:setCondition(math.max(0, part:getCondition() - 1))
            vehicle:transmitPartCondition(part)
            print(string.format(
                "HARMONIE Mechanical Advanced: Bullbar deflected debris from the front tires (bullbar now %d%%).",
                part:getCondition()
            ))
        end
    end
end

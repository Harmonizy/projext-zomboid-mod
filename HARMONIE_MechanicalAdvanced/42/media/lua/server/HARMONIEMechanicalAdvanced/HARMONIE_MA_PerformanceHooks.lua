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

--[[
    Always recomputes force from the vehicle SCRIPT's static base force,
    not from whatever the vehicle's current force happens to be -- so
    calling this every tick (or a thousand times) is idempotent, never
    compounding. Simplification: this overwrites vanilla's own
    condition-based power derating (Vehicles.Create.Engine) while the
    part is installed, rather than composing with it -- acceptable for
    a first pass; quality is left as whatever the vehicle currently has.
]]--
function HARMONIE_MA.Update.PerfExhaust(vehicle, part, elapsedMinutes)
    local item = part:getInventoryItem()
    if not item then return end

    local script = vehicle:getScript()
    if not script then return end

    logAliveOnce(part, "PerfExhaust")

    -- Vehicle parts have no getConditionMax() (that's an InventoryItem
    -- method) -- vanilla itself always uses a hardcoded 100 for part
    -- condition (e.g. part:setCondition(100) in Vehicles.lua).
    local conditionRatio = part:getCondition() / 100
    local baseForce = script:getEngineForce()
    local loudness = script:getEngineLoudness() or 100
    local quality = vehicle:getEngineQuality()

    local newForce = baseForce * (1 + (BONUS_POWER_MULT - 1) * conditionRatio)

    -- Only print (and only bother re-applying) when the value actually
    -- changes -- avoids spamming console.txt every tick while still
    -- proving, from the log, that the bonus is really being computed
    -- and applied.
    local data = part:getModData()
    if data.HARMONIE_lastForce ~= newForce then
        data.HARMONIE_lastForce = newForce
        vehicle:setEngineFeature(quality, loudness, newForce)
        print(string.format(
            "HARMONIE Mechanical Advanced: PerfExhaust set engine force to %.0f (base %.0f, condition %d%%).",
            newForce, baseForce, part:getCondition()
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

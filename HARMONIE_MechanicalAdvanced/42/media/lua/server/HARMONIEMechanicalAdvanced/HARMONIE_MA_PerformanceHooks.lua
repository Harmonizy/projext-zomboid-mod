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
    vehicle:getFrontEndHealth() -- while the method genuinely exists in
    the game's own compiled BaseVehicle class (confirmed by extracting
    projectzomboid.jar and grepping the class file) -- is NOT actually
    exposed to Lua. Confirmed the hard way: console.txt showed
    "Tried to call nil" inside the pcall wrapping it, every single time,
    on every vehicle. This is an important lesson, not just for this
    part: a method existing in the decompiled bytecode does NOT mean
    PZ's Lua binding exposes it -- only an actual successful call from
    real Lua code proves that. Extensive searching turned up no
    Lua-exposed collision event or getter anywhere in vanilla, so
    there is no verified way to detect a specific real-world collision
    from Lua at all in this game version.

    Given that, Bullbar no longer tries to react to specific collisions
    -- it wears down slowly from ordinary use instead (only while the
    engine is actually running, using vehicle:isEngineRunning(), a real
    method confirmed already in vanilla's own
    Vehicles.UninstallTest.Battery), using nothing but APIs already
    proven working elsewhere in this exact mod: part:getCondition(),
    part:setCondition(), vehicle:transmitPartCondition(). Small random
    chance per update call, so it isn't a fixed metronome -- this
    guarantees it will NOT sit at 100% forever, which was the original
    complaint, without claiming a collision-specific effect that
    couldn't be verified.
]]--
local BULLBAR_WEAR_CHANCE = 0.01

function HARMONIE_MA.Update.Bullbar(vehicle, part, elapsedMinutes)
    if not part:getInventoryItem() then return end

    logAliveOnce(part, "Bullbar")

    if part:getCondition() <= 0 then return end
    if not vehicle:isEngineRunning() then return end

    if ZombRandFloat(0, 1) < BULLBAR_WEAR_CHANCE then
        part:setCondition(math.max(0, part:getCondition() - 1))
        vehicle:transmitPartCondition(part)
        print(string.format(
            "HARMONIE Mechanical Advanced: Bullbar wore down from use (now %d%%).",
            part:getCondition()
        ))
    end
end

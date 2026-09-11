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
    Reacts to REAL front-end collisions, verified against the game's
    own compiled BaseVehicle class (extracted projectzomboid.jar):
    confirmed real methods include getFrontEndHealth/getRearEndHealth,
    addDamageFrontHitAChr, addRandomDamageFromCrash -- collision damage
    hits the vehicle-level frontEndHealth/rearEndHealth stat, NOT any
    named part's own getCondition() (there is no Lua-exposed collision
    event/hook at all -- grepped every vanilla Lua file for
    frontEndHealth/collision-related names, zero hits, so this has to
    be detected by polling).

    Earlier version watched the "Engine" part's own condition instead,
    on the wrong assumption that collisions damaged it directly -- that
    was never actually connected to real impacts, which is why bullbar
    condition stayed at 100% even after hitting zombies/objects.

    No setter for frontEndHealth was found in the class either, so this
    cannot actually PREVENT or heal collision damage -- only detect it
    and visibly wear the bullbar's own condition down in response, so
    the part is honestly a "takes real hits so you can see it happening"
    accessory, not a damage-reduction one. wrapped in pcall since this
    is the first time this mod calls getFrontEndHealth().
]]--
function HARMONIE_MA.Update.Bullbar(vehicle, part, elapsedMinutes)
    if not part:getInventoryItem() then return end

    logAliveOnce(part, "Bullbar")

    if part:getCondition() <= 0 then return end

    local ok, frontEndHealth = pcall(function() return vehicle:getFrontEndHealth() end)
    if not ok or frontEndHealth == nil then
        local data = part:getModData()
        if not data.HARMONIE_frontEndHealthFailed then
            data.HARMONIE_frontEndHealthFailed = true
            print("HARMONIE Mechanical Advanced WARNING: vehicle:getFrontEndHealth() failed or returned nil -- Bullbar cannot detect collisions on this vehicle.")
        end
        return
    end

    local data = part:getModData()
    local lastHealth = data.HARMONIE_lastFrontEndHealth
    data.HARMONIE_lastFrontEndHealth = frontEndHealth

    if lastHealth and frontEndHealth < lastHealth then
        part:setCondition(math.max(0, part:getCondition() - 1))
        vehicle:transmitPartCondition(part)
        print(string.format(
            "HARMONIE Mechanical Advanced: Bullbar took a real front-end hit (frontEndHealth %d -> %d, bullbar now %d%%).",
            lastHealth, frontEndHealth, part:getCondition()
        ))
    end
end

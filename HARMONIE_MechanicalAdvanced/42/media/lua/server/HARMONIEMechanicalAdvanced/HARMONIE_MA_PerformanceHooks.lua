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
    A real protective effect, not just a decorative accessory: while
    installed and in decent shape, occasionally absorbs a point of wear
    that would otherwise go to the real "Engine" part (a confirmed real
    vanilla part id, used throughout Vehicles.lua), taking the damage
    onto its own condition instead. Small, randomized chance per call
    (not guaranteed every tick) so it reads as "soaking some hits," not
    a hard damage-immunity switch. Once the bullbar itself is worn out
    (condition 0) it stops protecting anything, same as a real bumper
    that's been battered to scrap.
]]--
local BULLBAR_ABSORB_CHANCE = 0.02

function HARMONIE_MA.Update.Bullbar(vehicle, part, elapsedMinutes)
    if not part:getInventoryItem() then return end

    logAliveOnce(part, "Bullbar")

    if part:getCondition() <= 0 then return end

    local enginePart = vehicle:getPartById("Engine")
    if not enginePart then return end
    -- Vehicle parts have no getConditionMax() (that's an InventoryItem
    -- method) -- vanilla itself always uses a hardcoded 100 for part
    -- condition (e.g. part:setCondition(100) in Vehicles.lua).
    local PART_CONDITION_MAX = 100
    if enginePart:getCondition() >= PART_CONDITION_MAX then return end

    if ZombRandFloat(0, 1) < BULLBAR_ABSORB_CHANCE then
        enginePart:setCondition(math.min(PART_CONDITION_MAX, enginePart:getCondition() + 1))
        vehicle:transmitPartCondition(enginePart)
        part:setCondition(part:getCondition() - 1)
        vehicle:transmitPartCondition(part)
        print(string.format(
            "HARMONIE Mechanical Advanced: Bullbar absorbed 1 wear (bullbar now %d%%, engine now %d%%).",
            part:getCondition(), enginePart:getCondition()
        ))
    end
end

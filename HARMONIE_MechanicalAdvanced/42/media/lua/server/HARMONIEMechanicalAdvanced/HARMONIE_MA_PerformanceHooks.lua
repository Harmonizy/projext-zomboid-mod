--[[
    Our own update hooks -- deliberately NOT touching ATATuning2.* or
    Vehicles.* by redefinition (see the SVU3Core study). Run from our
    own templates' lua { update = ... } instead.
]]--

if not HARMONIE_MA then HARMONIE_MA = {} end
if not HARMONIE_MA.Update then HARMONIE_MA.Update = {} end

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

    local conditionRatio = part:getCondition() / part:getConditionMax()
    local baseForce = script:getEngineForce()
    local loudness = script:getEngineLoudness() or 100
    local quality = vehicle:getEngineQuality()

    local newForce = baseForce * (1 + (BONUS_POWER_MULT - 1) * conditionRatio)
    vehicle:setEngineFeature(quality, loudness, newForce)
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
    if part:getCondition() <= 0 then return end

    local enginePart = vehicle:getPartById("Engine")
    if not enginePart then return end
    if enginePart:getCondition() >= enginePart:getConditionMax() then return end

    if ZombRandFloat(0, 1) < BULLBAR_ABSORB_CHANCE then
        enginePart:setCondition(math.min(enginePart:getConditionMax(), enginePart:getCondition() + 1))
        vehicle:transmitPartCondition(enginePart)
        part:setCondition(part:getCondition() - 1)
        vehicle:transmitPartCondition(part)
    end
end

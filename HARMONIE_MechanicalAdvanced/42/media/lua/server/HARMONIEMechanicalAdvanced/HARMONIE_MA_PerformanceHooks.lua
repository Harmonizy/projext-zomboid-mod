--[[
    Own update hook for the performance exhaust part -- deliberately NOT
    touching ATATuning2.* or Vehicles.* by redefinition (see the SVU3Core
    study). Runs from our own template's lua { update = ... } instead.

    Always recomputes force from the vehicle SCRIPT's static base force,
    not from whatever the vehicle's current force happens to be -- so
    calling this every tick (or a thousand times) is idempotent, never
    compounding. Simplification: this overwrites vanilla's own
    condition-based power derating (Vehicles.Create.Engine) while the
    part is installed, rather than composing with it -- acceptable for
    a first pass; quality is left as whatever the vehicle currently has.
]]--

if not HARMONIE_MA then HARMONIE_MA = {} end
if not HARMONIE_MA.Update then HARMONIE_MA.Update = {} end

local BONUS_POWER_MULT = 1.15 -- +15% engine force at full part condition

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

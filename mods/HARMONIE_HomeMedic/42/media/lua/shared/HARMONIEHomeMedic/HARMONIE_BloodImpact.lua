--[[
    HARMONIE - Home Medic : blood loss that you can feel (shared)

    Request 2026-09-30 ("ปรับปรุงระบบเลือดให้ impact มากกว่านี้").

    Why EHR's own blood stages felt like nothing: EHR.Blood.ApplyEffects
    lowers endurance with stats:getEndurance()/setEndurance(), guarded by
    `if stats.setEndurance`. Build 42 reads and writes stats through
    stats:get/set(CharacterStat.X) (confirmed for Garden to Plate from the
    game's own classes), so that branch never runs and low blood volume
    cost no stamina at all.

    What this adds (EHR's files untouched):
      * an ENDURANCE CEILING that falls smoothly with blood volume: full at
        the "healthy" threshold (sandbox BloodThresholdHealthy, 85), down
        to CAP_AT_FLOOR at FLOOR_PERCENT of blood -- running, fighting and
        carrying tire you out fast once you have bled;
      * the ceiling is applied about once a second on BOTH sides in
        multiplayer (server for every online player, client for its own
        player) -- a ceiling is a min(), so applying it twice is harmless
        and it holds whichever side owns the stat.
    The visual side (vignette) is client/HARMONIEHomeMedic/HARMONIE_BloodVision.lua.
]]--

require "ExtensiveHealth/EHR_Main"
require "ExtensiveHealth/EHR_Blood"

HARMONIE_HomeMedic_BloodImpact = HARMONIE_HomeMedic_BloodImpact or {}
local B = HARMONIE_HomeMedic_BloodImpact

B.FLOOR_PERCENT = 0.60   -- blood fraction where the ceiling bottoms out
B.CAP_AT_FLOOR = 0.25    -- endurance ceiling at (and below) FLOOR_PERCENT
B.INTERVAL_MS = 1000

-- Blood as a 0..1 fraction; nil when EHR has no blood data for the player.
function B.bloodFraction(player)
    if not player or not EHR or not EHR.GetPlayerData then return nil end
    local data = EHR.GetPlayerData(player)
    local blood = data and data.EHR_Blood
    local cur, max = blood and tonumber(blood.currentVolume), blood and tonumber(blood.maxVolume)
    if not cur or not max or max <= 0 then return nil end
    return math.max(0, math.min(1, cur / max))
end

function B.healthyFraction()
    local t = EHR and EHR.Blood and EHR.Blood.GetThresholds and EHR.Blood.GetThresholds()
    return (t and tonumber(t.healthy)) or 0.85
end

-- The endurance ceiling for a blood fraction (1 = no limit).
function B.enduranceCap(fraction)
    if not fraction then return 1 end
    local top = B.healthyFraction()
    if fraction >= top then return 1 end
    local bottom = math.min(B.FLOOR_PERCENT, top - 0.01)
    local t = (fraction - bottom) / (top - bottom)
    t = math.max(0, math.min(1, t))
    return B.CAP_AT_FLOOR + (1 - B.CAP_AT_FLOOR) * t
end

function B.apply(player)
    if not player or (player.isDead and player:isDead()) then return end
    if not CharacterStat or not CharacterStat.ENDURANCE then return end
    local stats = player.getStats and player:getStats()
    if not stats or not stats.get or not stats.set then return end
    local cap = B.enduranceCap(B.bloodFraction(player))
    if cap >= 1 then return end
    local current = tonumber(stats:get(CharacterStat.ENDURANCE)) or 1
    if current > cap then stats:set(CharacterStat.ENDURANCE, cap) end
end

local nextAt = 0
function B.onTick()
    local now = getTimestampMs and getTimestampMs() or 0
    if now < nextAt then return end
    nextAt = now + B.INTERVAL_MS
    if isServer and isServer() then
        local online = getOnlinePlayers and getOnlinePlayers()
        for i = 0, (online and online:size() or 0) - 1 do B.apply(online:get(i)) end
        return
    end
    local count = getNumActivePlayers and getNumActivePlayers() or 1
    for i = 0, count - 1 do
        local p = getSpecificPlayer and getSpecificPlayer(i)
        if p then B.apply(p) end
    end
end

if Events and Events.OnTick then Events.OnTick.Add(B.onTick) end

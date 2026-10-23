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
      * THIRST (owner, 2026-10-10: "การกระหายน้ำจากปริมาณเลือดที่ลดลงทำให้การกิน
        น้ำอัตโนมัติ...ทำงานตลอดเวลาจนหมด และความกระหายไม่เพิ่ม ปรับเป็นกระหายน้ำ
        เร็วขึ้นแทน"): with blood under the healthy threshold the game pushed
        thirst up in jumps, so the character auto-drank from any bottle in
        the bag again and again until it was empty and the thirst bar never
        moved. Now, while blood is low, thirst is allowed to rise only at a
        natural pace (THIRST_NATURAL_MAX per game hour) -- bigger jumps are
        cut back -- and that pace is multiplied by up to THIRST_MAX_MULT as
        blood falls: you get thirsty FASTER, and drink as often as that
        makes you, not continuously. Drinking (thirst going down) is never
        touched. Runs where the stat lives: the server in multiplayer, the
        game itself in single player (not on a multiplayer client).
    The visual side (vignette) is client/HARMONIEHomeMedic/HARMONIE_BloodVision.lua.
]]--

require "ExtensiveHealth/EHR_Main"
require "ExtensiveHealth/EHR_Blood"

HARMONIE_HomeMedic_BloodImpact = HARMONIE_HomeMedic_BloodImpact or {}
local B = HARMONIE_HomeMedic_BloodImpact

B.FLOOR_PERCENT = 0.60   -- blood fraction where the ceiling bottoms out
B.CAP_AT_FLOOR = 0.25    -- endurance ceiling at (and below) FLOOR_PERCENT
B.INTERVAL_MS = 1000
B.THIRST_NATURAL_MAX = 0.08  -- thirst per game hour still taken as "natural" (heat, running)
B.THIRST_MAX_MULT = 3.0      -- thirst rises this much faster at THIRST_FULL_AT blood
B.THIRST_FULL_AT = 0.50      -- blood fraction where the multiplier is at its maximum

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
    -- console.txt on a change of the cap only (this runs every few seconds)
    B.lastCap = B.lastCap or {}
    local who = HMLogName and HMLogName(player) or "?"
    local bucket = math.floor(cap * 20 + 0.5) / 20
    if B.lastCap[who] ~= bucket then
        B.lastCap[who] = bucket
        if HMLog then HMLog("Blood", "%s: blood %.0f%% -> endurance capped at %.0f%%", who, (B.bloodFraction(player) or 0) * 100, bucket * 100) end
    end
    if cap >= 1 then return end
    local current = tonumber(stats:get(CharacterStat.ENDURANCE)) or 1
    if current > cap then stats:set(CharacterStat.ENDURANCE, cap) end
end

-- how much faster thirst rises at this blood fraction (1 = normal)
function B.thirstMult(fraction)
    if not fraction then return 1 end
    local top = B.healthyFraction()
    if fraction >= top then return 1 end
    local d = (top - fraction) / math.max(0.01, top - B.THIRST_FULL_AT)
    d = math.max(0, math.min(1, d))
    return 1 + (B.THIRST_MAX_MULT - 1) * d
end

-- per player: the thirst value and game hour seen last time
B.thirstSeen = B.thirstSeen or {}
function B.thirst(player)
    if isClient and isClient() then return end          -- the server owns the stat
    if not player or (player.isDead and player:isDead()) then return end
    if not CharacterStat or not CharacterStat.THIRST then return end
    local stats = player.getStats and player:getStats()
    if not stats or not stats.get or not stats.set then return end
    local gt = getGameTime and getGameTime()
    local hour = gt and gt:getWorldAgeHours() or nil
    local cur = tonumber(stats:get(CharacterStat.THIRST))
    if not hour or not cur then return end
    local who = HMLogName and HMLogName(player) or "?"
    local seen = B.thirstSeen[who]
    local final = cur
    local mult = B.thirstMult(B.bloodFraction(player))
    if seen and mult > 1 then
        local dH = hour - seen.h
        local delta = cur - seen.v
        if dH > 0 and dH < 2 and delta > 0 then
            local natural = math.min(delta, B.THIRST_NATURAL_MAX * dH)
            final = math.max(0, math.min(1, seen.v + natural * mult))
            if math.abs(final - cur) > 0.0001 then stats:set(CharacterStat.THIRST, final) end
            -- console.txt: once per game hour while it is active (what the game
            -- tried to add vs what we allowed)
            local bucket = math.floor(hour)
            if seen.logged ~= bucket then
                seen.logged = bucket
                if HMLog then HMLog("Blood", "%s: low blood -> thirst x%.1f (game wanted +%.4f in %.3f h, allowed +%.4f)", who, mult, delta, dH, final - seen.v) end
            end
        end
    end
    B.thirstSeen[who] = { v = final, h = hour, logged = seen and seen.logged or nil }
end

local nextAt = 0
function B.onTick()
    local now = getTimestampMs and getTimestampMs() or 0
    if now < nextAt then return end
    nextAt = now + B.INTERVAL_MS
    if isServer and isServer() then
        local online = getOnlinePlayers and getOnlinePlayers()
        for i = 0, (online and online:size() or 0) - 1 do
            local p = online:get(i)
            B.apply(p)
            local ok, err = pcall(B.thirst, p)
            if not ok and HMLogOnce then HMLogOnce("bloodthirst", "Blood", "thirst rule failed: %s", tostring(err)) end
        end
        return
    end
    local count = getNumActivePlayers and getNumActivePlayers() or 1
    for i = 0, count - 1 do
        local p = getSpecificPlayer and getSpecificPlayer(i)
        if p then
            B.apply(p)
            local ok, err = pcall(B.thirst, p)
            if not ok and HMLogOnce then HMLogOnce("bloodthirst", "Blood", "thirst rule failed: %s", tostring(err)) end
        end
    end
end

if Events and Events.OnTick then Events.OnTick.Add(B.onTick) end

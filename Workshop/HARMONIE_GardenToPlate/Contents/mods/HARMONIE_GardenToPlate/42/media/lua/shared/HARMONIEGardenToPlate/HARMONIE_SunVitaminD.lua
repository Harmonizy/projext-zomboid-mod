--[[
    HARMONIE - From Garden to Plate
    Vitamin D from sunlight (2026-10-08, from the suggestions list: "วิตามิน D
    จากแสงแดด"). In real life the skin makes vitamin D in sunlight, and D is
    the hardest vitamin to get from food in this mod (fish, eggs, dairy,
    mushrooms only).

    Every 10 game minutes, a local survivor standing OUTSIDE in DAYLIGHT
    (game hour 9 to 16) gets a little D Reserve: SunVitaminDPerHour per game
    hour (sandbox, default 0.5), at most SunVitaminDMaxPerDay a day (default
    3 -- less than the daily decay of 5, so sunlight helps but food is still
    needed). Rain stops it; winter months (November to February) give half.
    Goes through VitData.Add like food, so it also banks pause days.

    Local players only (the same as the eating hooks): in multiplayer the
    client adds it to its own player and VitData sends the vitamin data to
    the server. The per-day total is kept in memory only (a relog in the
    same day starts the count again -- harmless, it is a cap, not a store).
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.SunD = HARMONIE_GTP.SunD or {}
local S = HARMONIE_GTP.SunD

S.FIRST_HOUR, S.LAST_HOUR = 9, 16
S.WINTER = { [11] = true, [12] = true, [1] = true, [2] = true }

local function sv(key, default)
    local t = SandboxVars and SandboxVars.HARMONIE_GardenToPlate
    local v = t and t[key]
    if v == nil then return default end
    return v
end

function S.enabled() return sv("SunVitaminD", true) ~= false end
function S.perHour() return math.max(0, tonumber(sv("SunVitaminDPerHour", 0.5)) or 0.5) end
function S.maxPerDay() return math.max(0, tonumber(sv("SunVitaminDMaxPerDay", 3)) or 3) end

local function raining()
    local climate = getClimateManager and getClimateManager() or nil
    if not climate then return false end
    for _, getter in ipairs({ "getPrecipitationIntensity", "getRainIntensity" }) do
        if climate[getter] then
            local ok, v = pcall(climate[getter], climate)
            if ok and tonumber(v) and tonumber(v) > 0.03 then return true end
        end
    end
    return false
end

-- Reserve this 10-minute step is worth for `player` right now (0 = none)
function S.stepReserve(player, hour, month, isRaining)
    if not S.enabled() or not player then return 0 end
    local okO, outside = pcall(function() return player:isOutside() end)
    if not (okO and outside) then return 0 end
    if hour < S.FIRST_HOUR or hour > S.LAST_HOUR then return 0 end
    if isRaining then return 0 end
    local r = S.perHour() / 6
    if S.WINTER[month] then r = r / 2 end
    return r
end

S.today = S.today or {}
function S.onTenMinutes()
    -- a dedicated server has no local player (getNumActivePlayers() is 0)
    if not getNumActivePlayers or getNumActivePlayers() == 0 then return end
    local gt = getGameTime()
    if not gt then return end
    local hour, month = gt:getHour(), gt:getMonth() + 1
    local day = math.floor(gt:getWorldAgeHours() / 24)
    local isRaining = raining()
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p and not p:isDead() then
            local rec = S.today[i]
            if not rec or rec.day ~= day then rec = { day = day, got = 0 }; S.today[i] = rec end
            local r = math.min(S.stepReserve(p, hour, month, isRaining), S.maxPerDay() - rec.got)
            if r > 0 then
                rec.got = rec.got + r
                -- VitData.Add takes the vitamin amount (mcg for D): Reserve back to amount
                local amount = r * (HARMONIE_GTP.DailyRequirement.D or 15) * (tonumber(HARMONIE_GTP.Config.reserveGainDivisor) or 10) / 100
                HARMONIE_GTP.VitData.Add(p, "D", amount)
            end
        end
    end
end

if Events and Events.EveryTenMinutes then Events.EveryTenMinutes.Add(S.onTenMinutes) end

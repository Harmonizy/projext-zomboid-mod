--[[
    HARMONIE - From Garden to Plate
    Daily tick: consumes a banked pause day for each vitamin, or decays it
    by Config.decayPerDay if none are banked, and refreshes the affliction
    hysteresis + how many consecutive days it's persisted (see
    HARMONIE_VitaminData.lua's ApplyDailyTick).

    Does NOT apply the critical-band penalty itself anymore -- that's
    HARMONIE_VitaminChecker.lua's job now, running every 10 real seconds
    instead of waiting for this once-a-day event, so a vitamin that just
    turned Critical (or whose Base.PillsVitamins suppression window just
    ran out) doesn't have to wait up to a full in-game day to actually
    start hurting again.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

local function onEveryDays()
    HARMONIE_GTP.RefreshFromSandbox()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
                HARMONIE_GTP.VitData.ApplyDailyTick(player, vit)
            end
        end
    end
end

Events.EveryDays.Add(onEveryDays)

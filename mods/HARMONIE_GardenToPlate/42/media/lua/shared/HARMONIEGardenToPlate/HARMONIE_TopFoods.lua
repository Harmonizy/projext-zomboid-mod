--[[
    HARMONIE - From Garden to Plate
    "Best foods for vitamin X" lookup, built on top of the already-merged
    HARMONIE_GTP.FoodVitaminDB (populated by HARMONIE_FoodVitaminDatabase.lua,
    HARMONIE_RecipeVitamins.lua's static fallback entries, and
    HARMONIE_CannedProduceVitamins.lua -- this file only reads it, load
    order with those three doesn't matter as long as this runs after all
    three, which `require` guarantees since every caller requires this
    module directly).

    Only ranks the STATIC per-fullType profiles in FoodVitaminDB, not the
    per-instance ModData vitamin totals HARMONIE_RecipeVitamins.lua stamps
    onto individual crafted/canned item instances -- those vary jar to jar
    (different ingredients each time) so there's no single stable number to
    rank a recipe-made item's fullType by. The static DB entries are exactly
    the "typical serving" figures meant for this kind of general
    recommendation.

    Excludes home-canned entries (fullType prefix "HARMONIEGardenToPlate.
    HomeCanned...", registered in HARMONIE_CannedProduceVitamins.lua) by
    request -- the recommendation is meant to point players at real food to
    go eat/grow, not back at this mod's own canning output, which would
    otherwise tend to dominate the list since a canned jar's profile is the
    raw ingredient's own numbers scaled up by PRODUCE_PER_JAR (4x).
]]--

require "HARMONIEGardenToPlate/HARMONIE_FoodVitaminDatabase"
require "HARMONIEGardenToPlate/HARMONIE_RecipeVitamins"
require "HARMONIEGardenToPlate/HARMONIE_CannedProduceVitamins"

HARMONIE_GTP = HARMONIE_GTP or {}

local CANNED_PREFIX = "HARMONIEGardenToPlate.HomeCanned"

--[[
    Returns up to `limit` {fullType, amount, displayName} entries, richest
    first, for the given vitamin letter ("A".."K"). displayName falls back
    to the raw fullType string if the item script can't be found (a mod
    that supplied one of these fullTypes got removed/renamed) so a stale
    DB entry can never crash the panel -- it just shows an ugly but honest
    name instead of erroring.
]]--
function HARMONIE_GTP.GetTopFoods(vit, limit)
    limit = limit or 10
    local DB = HARMONIE_GTP.FoodVitaminDB
    local results = {}

    for fullType, profile in pairs(DB) do
        local amount = profile[vit]
        if amount and amount > 0 and fullType:sub(1, #CANNED_PREFIX) ~= CANNED_PREFIX then
            table.insert(results, {fullType = fullType, amount = amount})
        end
    end

    table.sort(results, function(a, b) return a.amount > b.amount end)

    local topN = {}
    for i = 1, math.min(limit, #results) do
        local entry = results[i]
        local displayName = entry.fullType
        local scriptItem = getScriptManager() and getScriptManager():FindItem(entry.fullType)
        if scriptItem then
            local ok, name = pcall(function() return scriptItem:getDisplayName() end)
            if ok and name and name ~= "" then
                displayName = name
            end
        end
        table.insert(topN, {fullType = entry.fullType, amount = entry.amount, displayName = displayName})
    end

    return topN
end

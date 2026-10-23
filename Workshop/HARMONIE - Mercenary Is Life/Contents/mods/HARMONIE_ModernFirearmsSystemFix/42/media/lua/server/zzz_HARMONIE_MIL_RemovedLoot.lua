--[[
    HARMONIE - Mercenary Is Life : guns taken out of the world loot

    Owner, 2026-10-23: MTL30 (grenade launcher), the interceptor crossbow and
    the Flamethrower still use an ammo type of a mod (efk:cat_grenadeammo,
    efk:cat_crossbowbolt, flamethrower:flame_fuel). In B42.20 such a gun can
    crash the game on its first shot (no bullet tracer preset, see
    shared/HARMONIE_MIL_AmmoCheck.lua), so they never spawn in the world.
    The ammo only those guns take goes too. Base.GrenadeAmmo stays: the
    under-barrel launchers (GP25 / M203 / M28) fire it through MIL's Lua.

    Every MIL loot file adds its rows at load or on OnPreDistributionMerge;
    this pass runs last, on OnPostDistributionMerge, and removes the rows from
    every distribution table (procedural, suburbs, vehicles), whatever the
    sandbox says. Items already in a save are not touched.
]]--

require "Items/ProceduralDistributions"

local REMOVED = {
    ["Base.MTL30_cat"] = true,
    ["Base.MFS_MTL30_cat"] = true,
    ["Base.interceptor_cat"] = true,
    ["Base.CrossbowBolt"] = true,
    ["Base.CrossbowBoltBox"] = true,
    ["Base.CrossbowClip"] = true,
    ["Flamethrower.Flamethrower"] = true,
    ["Flamethrower.FlameFuel"] = true,
}

local function side()
    if isServer and isServer() then return "server" end
    if isClient and isClient() then return "client" end
    return "SP"
end
local function log(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    print("[HARMONIE_MFSFix][RemovedLoot][" .. side() .. "] " .. (ok and msg or tostring(fmt)))
end

local function isRemoved(name)
    if type(name) ~= "string" then return false end
    if REMOVED[name] then return true end
    -- rows may leave out the module ("MTL30_cat")
    return not name:find("%.") and REMOVED["Base." .. name] or false
end

-- items = { name, weight, name, weight, ... }
local function cleanItems(items, counts)
    if type(items) ~= "table" then return 0 end
    local out, removed, i = {}, 0, 1
    while items[i] ~= nil do
        local name, weight = items[i], items[i + 1]
        if isRemoved(name) then
            removed = removed + 1
            counts[name] = (counts[name] or 0) + 1
        else
            out[#out + 1] = name
            out[#out + 1] = weight
        end
        i = i + 2
    end
    if removed > 0 then
        for k = #items, 1, -1 do items[k] = nil end
        for k = 1, #out do items[k] = out[k] end
    end
    return removed
end

-- walks a distribution table: every "items" list, nested rooms / containers / junk
local function walk(t, counts, seen)
    if type(t) ~= "table" or seen[t] then return 0 end
    seen[t] = true
    local n = 0
    for k, v in pairs(t) do
        if k == "items" then
            n = n + cleanItems(v, counts)
        elseif type(v) == "table" then
            n = n + walk(v, counts, seen)
        end
    end
    return n
end

local function removeLoot(when)
    local counts, total, seen = {}, 0, {}
    local tables = {
        { "ProceduralDistributions", ProceduralDistributions and ProceduralDistributions.list },
        { "SuburbsDistributions", SuburbsDistributions },
        { "VehicleDistributions", VehicleDistributions },
        { "Distributions", Distributions },
    }
    local parts = {}
    for _, e in ipairs(tables) do
        local ok, n = pcall(walk, e[2], counts, seen)
        if not ok then
            log("%s: could not clean %s: %s", when, e[1], tostring(n))
        elseif e[2] then
            total = total + n
            parts[#parts + 1] = e[1] .. " " .. n
        end
    end
    local byItem = {}
    for name, c in pairs(counts) do byItem[#byItem + 1] = name .. " x" .. c end
    table.sort(byItem)
    log("%s: removed %d loot rows of MTL30 / interceptor crossbow / flamethrower (%s)%s",
        when, total, table.concat(parts, ", "),
        #byItem > 0 and (": " .. table.concat(byItem, ", ")) or "")
end

if Events and Events.OnPostDistributionMerge then
    Events.OnPostDistributionMerge.Add(function() removeLoot("OnPostDistributionMerge") end)
else
    log("OnPostDistributionMerge not available -- cleaning at load")
    removeLoot("load")
end

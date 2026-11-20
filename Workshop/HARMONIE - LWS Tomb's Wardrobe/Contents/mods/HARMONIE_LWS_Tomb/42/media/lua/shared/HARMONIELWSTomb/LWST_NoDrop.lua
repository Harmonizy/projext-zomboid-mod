--[[
    HARMONIE - LWS: Tomb's Wardrobe -- nothing of Tomb's Wardrobe turns up in
    the world (owner 2026-11-20: its clothes and bags are gacha fashion; real
    carrying is vanilla bags, upgraded in The Way To Attack).

    Tomb's mod puts its items in the world two ways; both are taken out here:
      * loot: TombWardrobe_ProceduralDistributions.lua adds TombAlternative.*
        rows to ~40 container lists -> removed on OnPostDistributionMerge
        (server / SP: loot is rolled where the world lives), every
        distribution table walked like MIL's RemovedLoot;
      * zombies: TombWardrobe_ZombieZoneDefinition.lua adds the outfits
        Tombwardrobe_Rocker / Goth / Pure / Assassin to the zones -> removed
        from ZombiesZoneDefinition at game boot (after every mod's file ran).
    Belt and braces: a zombie that still dies wearing or carrying a
    TombAlternative.* item (an old save, another mod's outfit) loses it before
    its corpse is made (server / SP). Every pass logs what it removed.
]]--

LWST = LWST or {}
local SRC = "TombAlternative."

local function side()
    if isServer and isServer() then return "server" end
    if isClient and isClient() then return "client" end
    return "SP"
end
local function log(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    print("[HARMONIE_LWS][Tomb][" .. side() .. "] " .. (ok and msg or tostring(fmt)))
end
LWST.log = log

local function isTomb(name)
    return type(name) == "string" and name:sub(1, #SRC) == SRC
end
LWST.isTomb = isTomb

-- ------------------------------------------------------------ loot
-- items = { name, weight, name, weight, ... }
local function cleanItems(items, counts)
    if type(items) ~= "table" then return 0 end
    local out, removed, i = {}, 0, 1
    while items[i] ~= nil do
        local name, weight = items[i], items[i + 1]
        if isTomb(name) then
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

function LWST.removeLoot(when)
    local counts, total, seen, parts = {}, 0, {}, {}
    local tables = {
        { "ProceduralDistributions", ProceduralDistributions and ProceduralDistributions.list },
        { "SuburbsDistributions", SuburbsDistributions },
        { "VehicleDistributions", VehicleDistributions },
        { "Distributions", Distributions },
    }
    for _, e in ipairs(tables) do
        local ok, n = pcall(walk, e[2], counts, seen)
        if not ok then
            log("%s: could not clean %s: %s", when, e[1], tostring(n))
        elseif e[2] then
            total = total + n
            parts[#parts + 1] = e[1] .. " " .. n
        end
    end
    local kinds = 0
    for _ in pairs(counts) do kinds = kinds + 1 end
    log("%s: removed %d loot rows of %d Tomb's Wardrobe items (%s)", when, total, kinds, table.concat(parts, ", "))
    return total
end

-- ------------------------------------------------------------ zombie outfits
function LWST.removeOutfits(when)
    local Z = ZombiesZoneDefinition
    if type(Z) ~= "table" then log("%s: no ZombiesZoneDefinition -- zombie outfits not checked", when); return 0 end
    local removed, zones = 0, 0
    for _, zone in pairs(Z) do
        if type(zone) == "table" then
            local keep, hit = {}, false
            for i = 1, #zone do
                local e = zone[i]
                if type(e) == "table" and type(e.name) == "string" and e.name:sub(1, 13) == "Tombwardrobe_" then
                    removed, hit = removed + 1, true
                else
                    keep[#keep + 1] = e
                end
            end
            if hit then
                zones = zones + 1
                for k = #zone, 1, -1 do zone[k] = nil end
                for k = 1, #keep do zone[k] = keep[k] end
            end
            -- some zones keep outfits by name too
            for k, v in pairs(zone) do
                if type(k) == "string" and k:sub(1, 13) == "Tombwardrobe_" then zone[k] = nil; removed = removed + 1 end
            end
        end
    end
    log("%s: removed %d Tomb's Wardrobe zombie outfits from %d zones", when, removed, zones)
    return removed
end

-- ------------------------------------------------------------ a zombie dies
function LWST.onZombieDead(zombie)
    if isClient and isClient() then return end
    if not zombie then return end
    local visuals, items = 0, 0
    pcall(function()
        local vis = zombie:getItemVisuals()
        local gone = {}
        for i = 0, vis:size() - 1 do
            local v = vis:get(i)
            local t = v and v.getItemType and v:getItemType()
            if t and isTomb(tostring(t)) then gone[#gone + 1] = v end
        end
        for _, v in ipairs(gone) do vis:remove(v); visuals = visuals + 1 end
    end)
    pcall(function()
        local inv = zombie:getInventory()
        local its, gone = inv:getItems(), {}
        for i = 0, its:size() - 1 do
            local it = its:get(i)
            local ok, t = pcall(function() return it:getFullType() end)
            if ok and isTomb(tostring(t)) then gone[#gone + 1] = it end
        end
        for _, it in ipairs(gone) do pcall(function() inv:Remove(it) end); items = items + 1 end
    end)
    if visuals > 0 or items > 0 then
        log("a zombie died with Tomb's Wardrobe items: %d clothes and %d items removed (not world loot)", visuals, items)
    end
end

if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(function() LWST.removeOutfits("OnGameBoot") end) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(function() LWST.removeOutfits("OnServerStarted") end) end
    if Events.OnPostDistributionMerge then
        Events.OnPostDistributionMerge.Add(function() LWST.removeLoot("OnPostDistributionMerge") end)
    else
        log("OnPostDistributionMerge not available -- loot cleaned at game boot")
        if Events.OnGameBoot then Events.OnGameBoot.Add(function() LWST.removeLoot("OnGameBoot") end) end
    end
    if Events.OnZombieDead then Events.OnZombieDead.Add(LWST.onZombieDead) end
end

-- Central sandbox pass for MFS firearm, attachment, and magazine loot rates.
--
-- MFS's many loot modules append item/weight pairs directly or from
-- OnPreDistributionMerge callbacks. This final OnPostDistributionMerge pass
-- adjusts the completed tables once, before any container rolls from them.
-- A gun rate of zero removes that gun at this stage so it never consumes a
-- loot result and leaves an empty slot.

require "Items/ProceduralDistributions"
require "MFSLootSandboxCatalog"
require "item/gun/MFS_CivilianOnlyLoot"

MFSLootSandbox = MFSLootSandbox or {}
local Loot = MFSLootSandbox

Loot.VERSION = "1.3.1"
Loot._processed = Loot._processed or setmetatable({}, { __mode = "k" })

-- Complete Build 42 generated/items/weaponpart.txt set. These are the vanilla
-- attachment item types, including the damaged compatibility parts retained by
-- MFS. The opt-in sandbox switch removes only their procedural-loot rows; it
-- does not touch MFS parts, existing inventory, attached parts, or recipes.
local VANILLA_WEAPON_PARTS = {
    ["Base.x2Scope"] = true,
    ["Base.x4Scope"] = true,
    ["Base.x8Scope"] = true,
    ["Base.AmmoStraps"] = true,
    ["Base.TritiumSights"] = true,
    ["Base.RecoilPad"] = true,
    ["Base.Laser"] = true,
    ["Base.RedDot"] = true,
    ["Base.GunLight"] = true,
    ["Base.ChokeTubeFull"] = true,
    ["Base.ChokeTubeImproved"] = true,
}

local CATEGORY_OPTIONS = {
    Scope = "ScopeMultiplier",
    R_Scope = "RightScopeMultiplier",
    L_Scope = "LeftScopeMultiplier",
    Canon = "MuzzleMultiplier",
    Stock = "StockMultiplier",
    Grip = "GripMultiplier",
    Light = "LightMultiplier",
    Laser = "LaserMultiplier",
    Sling = "SlingMultiplier",
    Recoilpad = "RecoilPadMultiplier",
    Barrel = "BarrelMultiplier",
    Stool = "UnderbarrelMultiplier",
}

local function boundedMultiplier(value, maximum)
    value = tonumber(value) or 1.0
    if value < 0 then return 0 end
    maximum = maximum or 100.0
    if value > maximum then return maximum end
    return value
end

local function readMultipliers()
    local configured = SandboxVars and SandboxVars.MFSCommunityFixLoot or {}
    local values = {}
    for partType, optionName in pairs(CATEGORY_OPTIONS) do
        values[partType] = boundedMultiplier(configured[optionName])
    end
    values.FunctionalMagazine = boundedMultiplier(configured.FunctionalMagazineMultiplier, 5.0)
    values.Firearm = boundedMultiplier(configured.FirearmMultiplier)
    return values
end

local function readGunRates()
    local disabled = {}
    local rates = {}
    local configured = SandboxVars and SandboxVars.MFSCommunityFixGunRates or {}
    local legacy = SandboxVars and SandboxVars.ModernFirearmsSystemSandboxGun or {}
    for fullType, rateName in pairs(MFSLootSandboxCatalog.gunRateOptions or {}) do
        local legacyName = MFSLootSandboxCatalog.gunLegacyOptions[fullType]
        local value = configured[rateName]
        if (legacyName and legacy[legacyName] == false) or tonumber(value) == 0 then
            disabled[fullType] = true
        elseif tonumber(value) then
            rates[fullType] = boundedMultiplier(value, 100.0)
        else
            -- Missing new settings retain the authored rate.
            rates[fullType] = 1.0
        end
    end
    return disabled, rates
end

local function transformItems(items, multipliers, disabled, gunRates, stats,
        removeVanillaWeaponParts)
    if type(items) ~= "table" or Loot._processed[items] then return end
    Loot._processed[items] = true

    local index = 1
    while index + 1 <= #items do
        local fullType = items[index]
        local catalogType = fullType
        if type(catalogType) == "string" and not string.find(catalogType, ".", 1, true) then
            catalogType = "Base." .. catalogType
        end
        local removeDisabledGun = type(catalogType) == "string"
            and disabled[catalogType] == true
        local removeVanillaPart = removeVanillaWeaponParts
            and type(catalogType) == "string"
            and VANILLA_WEAPON_PARTS[catalogType] == true
        local removePair = removeDisabledGun or removeVanillaPart
        local multiplier

        if not removePair and type(catalogType) == "string" then
            local partType = MFSLootSandboxCatalog.partCategories[catalogType]
            if partType then
                multiplier = multipliers[partType]
            elseif MFSLootSandboxCatalog.functionalMagazines[catalogType] then
                multiplier = multipliers.FunctionalMagazine
            elseif MFSLootSandboxCatalog.firearms[catalogType] then
                multiplier = multipliers.Firearm
            end
            local gunRate = gunRates[catalogType]
            if gunRate then
                multiplier = (multiplier or 1.0) * gunRate
            end
        end

        if removePair or multiplier == 0 then
            table.remove(items, index + 1)
            table.remove(items, index)
            if removeDisabledGun then
                stats.removedGunPairs = stats.removedGunPairs + 1
            elseif removeVanillaPart then
                stats.removedVanillaWeaponPartPairs =
                    stats.removedVanillaWeaponPartPairs + 1
            else
                stats.removedCategoryPairs = stats.removedCategoryPairs + 1
            end
        else
            if multiplier and multiplier ~= 1 then
                local authoredWeight = tonumber(items[index + 1])
                if authoredWeight then
                    items[index + 1] = authoredWeight * multiplier
                    stats.scaledPairs = stats.scaledPairs + 1
                end
            end
            index = index + 2
        end
    end
end

local function applySandboxLoot()
    local lists = ProceduralDistributions and ProceduralDistributions.list
    if type(lists) ~= "table" then return end

    local stats = {
        distributions = 0,
        itemTables = 0,
        scaledPairs = 0,
        removedCategoryPairs = 0,
        removedGunPairs = 0,
        removedVanillaWeaponPartPairs = 0,
    }
    local multipliers = readMultipliers()
    local disabled, gunRates = readGunRates()
    local configured = SandboxVars and SandboxVars.MFSCommunityFixLoot or {}
    local removeVanillaWeaponParts =
        configured.DisableVanillaWeaponParts == true

    for _, distribution in pairs(lists) do
        if type(distribution) == "table" then
            stats.distributions = stats.distributions + 1
            if type(distribution.items) == "table" then
                stats.itemTables = stats.itemTables + 1
                transformItems(distribution.items, multipliers, disabled, gunRates,
                    stats, removeVanillaWeaponParts)
            end
            if type(distribution.junk) == "table"
                    and type(distribution.junk.items) == "table" then
                stats.itemTables = stats.itemTables + 1
                transformItems(distribution.junk.items, multipliers, disabled, gunRates,
                    stats, removeVanillaWeaponParts)
            end
        end
    end

    Loot.lastRun = stats
    Loot.lastMultipliers = multipliers
end

-- Final safety net for loot sources that populate a container after the
-- distribution-merge pass, or that bypass ProceduralDistributions entirely.
-- This runs while the server is generating the container, so removed guns are
-- never exposed to clients and player/existing inventories are not touched.
local function forceRemoveDisabledGuns(...)
    -- Build 42 may also fire OnFillContainer with the distribution metadata
    -- object ItemPickerJava.ItemPickerContainer. Indexing RemoveAll on that
    -- Java object throws before a normal nil guard can run. Scan the payload
    -- in case the real inventory is supplied as an additional argument, and
    -- only post-process an actual ItemContainer. The normal distribution pass
    -- remains responsible for metadata-only calls.
    local container = nil
    if instanceof then
        for index = 3, select("#", ...) do
            local candidate = select(index, ...)
            if candidate and instanceof(candidate, "ItemContainer") then
                container = candidate
                break
            end
        end
    end
    if not container then return end
    local controls = SandboxVars and SandboxVars.MFSCommunityFixLoot
    if not controls or controls.ForceRemoveDisabledGuns ~= true then return end

    local disabled = readGunRates()
    local removedCount = 0

    for fullType in pairs(disabled) do
        local itemType = string.match(fullType, "^[^.]+%.(.+)$") or fullType
        local ok, removed = pcall(function()
            return container:RemoveAll(itemType)
        end)
        if ok and removed then
            local sizeOK, size = pcall(function()
                return removed:size()
            end)
            if sizeOK and size then
                removedCount = removedCount + size
            end
        end
    end

    if removedCount > 0 then
        Loot.forceRemovedGunCount = (Loot.forceRemovedGunCount or 0) + removedCount
    end
end

Loot.applySandboxLoot = applySandboxLoot
Loot.transformItems = transformItems
Loot.forceRemoveDisabledGuns = forceRemoveDisabledGuns

if Loot._callback then
    Events.OnPostDistributionMerge.Remove(Loot._callback)
end
Loot._callback = applySandboxLoot
Events.OnPostDistributionMerge.Add(Loot._callback)

if Loot._fillCallback then
    Events.OnFillContainer.Remove(Loot._fillCallback)
end
Loot._fillCallback = forceRemoveDisabledGuns
Events.OnFillContainer.Add(Loot._fillCallback)

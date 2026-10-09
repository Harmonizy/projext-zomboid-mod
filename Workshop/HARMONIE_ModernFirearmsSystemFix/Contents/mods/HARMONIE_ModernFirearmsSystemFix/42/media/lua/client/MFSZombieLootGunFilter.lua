-- Remove sandbox-disabled vanilla guns from zombie corpses only.
--
-- Ordinary procedural containers are filtered before loot generation by
-- server/zz_MFSLootSandbox.lua. This client-side fallback is retained for
-- guns added through zombie/outfit loot paths that do not use those tables.

require "ISUI/ISInventoryPane"
require "MFSLootSandboxCatalog"

MFSZombieLootGunFilter = MFSZombieLootGunFilter or {}
local Filter = MFSZombieLootGunFilter

Filter.VERSION = "1.0.0"

local function getDisabledGunTypes()
    local disabled = {}
    local controls = SandboxVars and SandboxVars.MFSCommunityFixLoot
    if not controls or controls.FilterZombieVanillaGuns ~= true then
        return disabled
    end
    local settings = SandboxVars and SandboxVars.ModernFirearmsSystemSandboxGun
    local rates = SandboxVars and SandboxVars.MFSCommunityFixGunRates

    if not settings and not rates then
        return disabled
    end

    for fullType, optionName in pairs(MFSLootSandboxCatalog.vanillaGunOptions or {}) do
        local value = settings and settings[optionName]
        local rateName = MFSLootSandboxCatalog.gunRateOptions[fullType]
        local rate = rates and rateName and rates[rateName]
        if value == false or tonumber(rate) == 0 then
            disabled[fullType] = true
        end
    end

    return disabled
end

local function isZombieCorpseInventory(inventory)
    if not inventory or not inventory.getParent then
        return false
    end

    local ok, parent = pcall(function()
        return inventory:getParent()
    end)
    if not ok or not parent or not instanceof(parent, "IsoDeadBody") then
        return false
    end

    if parent.isZombie then
        local zombieOK, wasZombie = pcall(function()
            return parent:isZombie()
        end)
        if zombieOK then
            return wasZombie == true
        end
    end

    if parent.getModData then
        local dataOK, data = pcall(function()
            return parent:getModData()
        end)
        return dataOK and type(data) == "table" and data.Zombie == true
    end

    return false
end

local function removeDisabledGuns(inventory)
    if not isZombieCorpseInventory(inventory) then
        return false
    end

    local removedAny = false
    for fullType in pairs(getDisabledGunTypes()) do
        local itemType = string.match(fullType, "^[^.]+%.(.+)$") or fullType
        local removed = inventory:RemoveAll(itemType)

        if removed and removed:size() > 0 then
            removedAny = true
            if isClient() then
                sendRemoveItemsFromContainer(inventory, removed)
            end
        end
    end

    return removedAny
end

Filter.getDisabledGunTypes = getDisabledGunTypes
Filter.isZombieCorpseInventory = isZombieCorpseInventory
Filter.removeDisabledGuns = removeDisabledGuns

if Filter._wrapper and ISInventoryPane.refreshContainer == Filter._wrapper then
    return
end

local previousRefreshContainer = ISInventoryPane.refreshContainer
Filter._wrapper = function(self)
    local inventory = self.inventory
    if removeDisabledGuns(inventory) and inventory then
        inventory:setDrawDirty(false)
    end
    return previousRefreshContainer(self)
end

ISInventoryPane.refreshContainer = Filter._wrapper

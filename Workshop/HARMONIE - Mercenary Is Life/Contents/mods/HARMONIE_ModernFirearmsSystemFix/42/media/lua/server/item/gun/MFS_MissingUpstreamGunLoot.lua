-- Restores procedural loot for current MFS firearm definitions whose upstream
-- release contains no server/item/gun registration file.

require "Items/ProceduralDistributions"
require "Items/ItemPicker"

local WEIGHT = 0.3

local COMMON_LISTS = {
    "GunStoreShelf",
    "PlankStashGun",
    "FirearmWeapons",
    "ArmyStorageGuns",
    "GunStoreCounter",
    "PoliceStorageGuns",
    "PawnShopGunsSpecial",
    "GunStoreDisplayCase",
    "GarageFirearms",
    "DrugLabGuns",
    "GunStoreAmmunition",
    "ArmyStorageAmmunition",
    "ArmySurplusCases",
    "LockerArmyBedroom",
    "LockerArmyBedroomHome",
    "ArmySurplusAmmoBoxes",
    "PoliceStorageAmmunition",
    "PrisonArmoryShotguns",
}

local GUNS = {
    {
        itemType = "Base.QBU203_cat",
        option = "_QBU203_cat_Spawn",
        activeGunShopList = "GunStoreRifles",
    },
    {
        itemType = "Base.nagant_m1895_cat",
        option = "_nagant_m1895_cat_Spawn",
        activeGunShopList = "GunStorePistols",
        schoolLocker = true,
    },
}

local function add(listName, itemType, weight)
    weight = weight or WEIGHT
    local distribution = ProceduralDistributions.list[listName]
    if not distribution or type(distribution.items) ~= "table" then return false end
    for index = 1, #distribution.items, 2 do
        if distribution.items[index] == itemType then return false end
    end
    table.insert(distribution.items, itemType)
    table.insert(distribution.items, weight)
    return true
end

local function registerMissingGuns()
    local settings = SandboxVars and SandboxVars.ModernFirearmsSystemSandboxGun or {}
    for _, gun in ipairs(GUNS) do
        if settings[gun.option] ~= false then
            for _, listName in ipairs(COMMON_LISTS) do
                add(listName, gun.itemType)
            end
            add(gun.activeGunShopList, gun.itemType)
            if gun.schoolLocker then
                add("SchoolLockersBad", gun.itemType, 0.01)
            end
        end
    end
end

if MFSMissingUpstreamGunLoot_callback then
    Events.OnPreDistributionMerge.Remove(MFSMissingUpstreamGunLoot_callback)
end
MFSMissingUpstreamGunLoot_callback = registerMissingGuns
Events.OnPreDistributionMerge.Add(MFSMissingUpstreamGunLoot_callback)

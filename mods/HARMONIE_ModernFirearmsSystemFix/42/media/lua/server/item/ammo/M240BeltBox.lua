require 'Items/ProceduralDistributions'
require "Items/ItemPicker"

-- Weight matched to upstream's 2026-09-07 loot rebalance (ammunition tier 0.1).
local distributions = {
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

for _, distribution in ipairs(distributions) do
    table.insert(ProceduralDistributions["list"][distribution].items, "Base.M240BeltBox")
    table.insert(ProceduralDistributions["list"][distribution].items, 0.1)
end

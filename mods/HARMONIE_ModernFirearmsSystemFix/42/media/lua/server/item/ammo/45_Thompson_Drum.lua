require 'Items/ProceduralDistributions'
require "Items/ItemPicker"

-- RC4F: rare 100-round Thompson drum. Weight matches other large MFS feeds.
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
    local entry = ProceduralDistributions
        and ProceduralDistributions.list
        and ProceduralDistributions.list[distribution]

    if entry and entry.items then
        table.insert(entry.items, "Base.45_Thompson")
        table.insert(entry.items, 0.1)
    end
end

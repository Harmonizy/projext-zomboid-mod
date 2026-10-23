require "Items/ProceduralDistributions"
require "Items/ItemPicker"

-- Usable 40 mm HE rounds for the beta MFS_M203 / MFS_GP25 / MFS_MTL30
-- launcher family.  AmmoGrenade40 teaches the recipe and GrenadeAmmoClip
-- is the empty five-round magazine; neither one supplies a playable round.
-- Keep loose rounds confined to firearm, police, military, and stash loot.

local grenadeAmmoLootLists = {
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

for _, listName in ipairs(grenadeAmmoLootLists) do
    table.insert(ProceduralDistributions.list[listName].items, "Base.GrenadeAmmo")
    table.insert(ProceduralDistributions.list[listName].items, 0.5)
end

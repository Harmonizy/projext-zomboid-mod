--[[
    HARMONIE - Mercenary Is Life : loot for the 7.62 machine-gun drum

    Base.762Drum_cat is the only magazine of PKM, QJY201, Lewis, FN Evolys
    and M1919A6, but the original mod never put it in a loot table and no
    recipe makes it: a gun found empty could never be reloaded (owner's
    flow check, 2026-10-23). Same lists and weight as the MG42 drum.
]]--

require "Items/ProceduralDistributions"

local ITEM, WEIGHT = "Base.762Drum_cat", 0.6
local LISTS = {
    "GunStoreShelf", "PlankStashGun", "FirearmWeapons", "ArmyStorageGuns",
    "GunStoreCounter", "PoliceStorageGuns", "PawnShopGunsSpecial",
    "GunStoreDisplayCase", "GarageFirearms", "DrugLabGuns", "GunStoreAmmunition",
    "ArmyStorageAmmunition", "ArmySurplusCases", "LockerArmyBedroom",
    "LockerArmyBedroomHome", "ArmySurplusAmmoBoxes", "PoliceStorageAmmunition",
}

local function side()
    if isServer and isServer() then return "server" end
    if isClient and isClient() then return "client" end
    return "SP"
end

local added, missing = 0, {}
local list = ProceduralDistributions and ProceduralDistributions.list
for _, name in ipairs(LISTS) do
    local l = list and list[name]
    if l and type(l.items) == "table" then
        table.insert(l.items, ITEM)
        table.insert(l.items, WEIGHT)
        added = added + 1
    else
        missing[#missing + 1] = name
    end
end
print("[HARMONIE_MFSFix][Loot762Drum][" .. side() .. "] " .. ITEM .. " added to " .. added .. " loot lists"
    .. (#missing > 0 and (" (lists not found: " .. table.concat(missing, ", ") .. ")") or ""))

-- Community-patch civilian loot plus the optional all-MFS civilian backfill.
--
-- WHY THIS FILE EXISTS
-- Before 2026-09-07 these five items were defined, mountable and named, but
-- reachable by no route at all: no loot entry and no craft recipe. They could
-- only be spawned in debug. This file gives them a home.
--
-- WHY CIVILIAN ONLY
-- Joe's call. Upstream intends to put its guns and parts into the firearm
-- procedural lists, including military, police and prison pools. The
-- community-patch additions are deliberately confined to the civilian side of
-- the table: gun shops, pawn shops, garages, house
-- stashes, drug labs, generic firearm containers, and army surplus stores,
-- which are civilian retail despite the name. Nothing here spawns in an active
-- Army, Police or Prison container.
--
-- NOT REGISTERED HERE, AND THAT IS DELIBERATE
-- Gunpart.Clip_MEGA_AR15_cat and Gunpart.Clip_NoveskeN4_cat are both
-- render-only magazine parts: they exist so a magazine draws on the model, not
-- so a player can carry one. MEGA_AR15_cat and NoveskeN4_cat both feed from
-- Base.556Clip like any other 5.56 rifle. Putting either render part into loot
-- would present it as a functional magazine. Leave them unspawnable.

require "Items/ProceduralDistributions"
require "Items/ItemPicker"
require "MFSLootSandboxCatalog"

-- The civilian eleven. The other seven upstream lists -- ArmyStorageGuns,
-- ArmyStorageAmmunition, LockerArmyBedroom, LockerArmyBedroomHome,
-- PoliceStorageGuns, PoliceStorageAmmunition, PrisonArmoryShotguns -- are
-- intentionally excluded.
--
-- ArmySurplusCases and ArmySurplusAmmoBoxes ARE included: an army surplus store
-- is a civilian shop that happens to sell military-pattern goods, which is
-- exactly where this equipment would turn up.
local CIVILIAN = {
    "GunStoreShelf",
    "GunStoreCounter",
    "GunStoreDisplayCase",
    "GunStoreAmmunition",
    "PlankStashGun",
    "FirearmWeapons",
    "PawnShopGunsSpecial",
    "GarageFirearms",
    "DrugLabGuns",
    "ArmySurplusCases",
    "ArmySurplusAmmoBoxes",
}

-- Ordinary residential storage does not use FirearmWeapons. These are the
-- wardrobe, crate and garage-storage pools that can belong to a civilian home.
-- Locker is the game's generic civilian locker pool; police and military use
-- their own named pools and remain excluded. Parts stay in firearm-oriented
-- pools and never enter this general storage route.
local RESIDENTIAL_STORAGE = {
    "WardrobeGeneric",
    "WardrobeClassy",
    "WardrobeRedneck",
    "CrateTools",
    "CrateToolsOld",
    "GarageTools",
    "GarageCarpentry",
    "GarageMechanics",
    "GarageMetalwork",
    "Locker",
}

-- Build 42 display cases select these active category lists. The old
-- GunStoreDisplayCase list still exists but is marked deprecated and is empty.
local ACTIVE_GUNSHOP_RIFLES = "GunStoreRifles"

-- The standard and drum-fed MEGA AR-15 are distinct usable weapons. Keep
-- their civilian availability and sandbox gate aligned.
local MEGA_AR15_VARIANTS = {
    "Base.MEGA_AR15_cat",
}

-- Weights follow upstream's 2026-09-07 rebalance: guns 0.3, parts 0.5.
local PARTS = {
    ["Gunpart.Leupold_Mk8_CQBSS"]   = 0.5,
    ["Gunpart.Romeo5_H_reddot"]     = 0.5,
    ["Gunpart.Romeo5_L_reddot"]     = 0.5,
    ["Gunpart.Magpul_MOE_stock_bk"] = 0.5,
}

local function add(listName, itemType, weight)
    local list = ProceduralDistributions.list[listName]
    if not list or type(list.items) ~= "table" then return false end
    -- Idempotence guard: distribution merge can fire more than once.
    for index = 1, #list.items, 2 do
        if list.items[index] == itemType then return false end
    end
    table.insert(list.items, itemType)
    table.insert(list.items, weight)
    return true
end

local function registerLoot()
    local added = 0

    -- The rifle honours its own sandbox toggle, matching how upstream gates
    -- every gun and how our MTL30 is gated.
    local gunEnabled = true
    local sandbox = SandboxVars and SandboxVars.ModernFirearmsSystemSandboxGun
    if sandbox and sandbox._MEGA_AR15_cat_Spawn == false then
        gunEnabled = false
    end

    for _, listName in ipairs(CIVILIAN) do
        if gunEnabled then
            for _, itemType in ipairs(MEGA_AR15_VARIANTS) do
                if add(listName, itemType, 0.2) then
                    added = added + 1
                end
            end
        end
        for itemType, weight in pairs(PARTS) do
            if add(listName, itemType, weight) then added = added + 1 end
        end
    end

    -- The MEGA AR-15 is a rifle, so make its glass-display route explicit in
    -- the active Build 42 list as well as the legacy compatibility lists.
    if gunEnabled then
        for _, itemType in ipairs(MEGA_AR15_VARIANTS) do
            if add(ACTIVE_GUNSHOP_RIFLES, itemType, 0.2) then added = added + 1 end
        end
    end

    -- Optional compatibility backfill. Some older/upstream gun files do not
    -- consistently register every firearm in every civilian firearm pool.
    -- Existing pairs keep their authored weight; only missing pairs use 0.3.
    local lootSandbox = SandboxVars and SandboxVars.MFSCommunityFixLoot
    if lootSandbox and lootSandbox.EnableMFSCivilianFirearms == true then
        for _, listName in ipairs(CIVILIAN) do
            for itemType in pairs(MFSLootSandboxCatalog.firearms or {}) do
                if add(listName, itemType, 0.3) then added = added + 1 end
            end
        end
        for itemType, listName in pairs(
                MFSLootSandboxCatalog.firearmShopCategories or {}) do
            if add(listName, itemType, 0.3) then added = added + 1 end
        end
    end

    -- Keep the civilian rifle findable in normal house wardrobes, storage
    -- crates, garage storage and generic large lockers. These lists are
    -- separate from FirearmWeapons in Build 42's procedural distributions.
    if gunEnabled then
        for _, listName in ipairs(RESIDENTIAL_STORAGE) do
            for _, itemType in ipairs(MEGA_AR15_VARIANTS) do
                if add(listName, itemType, 0.3) then
                    added = added + 1
                end
            end
            for itemType, weight in pairs(PARTS) do
                if add(listName, itemType, weight) then added = added + 1 end
            end
        end
    end

    print("[MFSCivilianLoot] registered pairs=" .. tostring(added)
        .. " lists=" .. tostring(#CIVILIAN)
        .. " residentialStorage=" .. tostring(#RESIDENTIAL_STORAGE)
        .. " MEGA_AR15Variants=" .. tostring(gunEnabled and #MEGA_AR15_VARIANTS or 0))
end

if MFSCivilianOnlyLoot_callback then
    Events.OnPreDistributionMerge.Remove(MFSCivilianOnlyLoot_callback)
end
MFSCivilianOnlyLoot_callback = registerLoot
Events.OnPreDistributionMerge.Add(MFSCivilianOnlyLoot_callback)

require "lua_timers"

local ItemsController = require("TOC/Controllers/ItemsController")
local StaticData = require("TOC/StaticData")
local CommandsData = require("TOC/CommandsData")
-------------------------------

---@param zombie IsoZombie|IsoGameCharacter|IsoMovingObject|IsoObject
---@return integer trueID
local function GetZombieID(zombie)
    -- Big love to Chuck and Sir Doggy Jvla for this code
    ---@diagnostic disable-next-line: param-type-mismatch
    local pID = zombie:getPersistentOutfitID()
    local bits = string.split(string.reverse(Long.toUnsignedString(pID, 2)), "")
    while #bits < 16 do bits[#bits + 1] = 0 end

    -- trueID
    bits[16] = 0
    local trueID = Long.parseUnsignedLong(string.reverse(table.concat(bits, "")), 2)

    return trueID
end

-------------------------------


---@param item InventoryItem
local function PredicateAmputationItems(item)
    return item:getType():contains("Amputation_")
end

---@param item InventoryItem
local function PredicateAmputationItemLeft(item)
    return item:getType():contains("Amputation_") and item:getType():contains("_L")
end

---@param item InventoryItem
local function PredicateAmputationItemRight(item)
    return item:getType():contains("Amputation_") and item:getType():contains("_R")
end

---@param zombie IsoZombie
local function SpawnAmputation(zombie, side)
    local index = ZombRand(1, #StaticData.PARTS_STR)
    local limb = StaticData.PARTS_STR[index] .. "_" .. side
    local amputationFullType = StaticData.AMPUTATION_CLOTHING_ITEM_BASE .. limb


    ItemsController.Zombie.SpawnAmputationItem(zombie, amputationFullType)


    -- Add reference and transmit it to server
    local pID = GetZombieID(zombie)
    local zombieKey = CommandsData.GetZombieKey()
    local zombiesMD = ModData.getOrCreate(zombieKey)
    if zombiesMD[pID] == nil then zombiesMD[pID] = {} end
    zombiesMD[pID][side] = amputationFullType
    ModData.add(zombieKey, zombiesMD)
    ModData.transmit(zombieKey)
end

-------------------------------

local bloodAmount = 10


---@param player IsoGameCharacter
---@param zombie IsoZombie
---@param handWeapon HandWeapon
local function HandleZombiesAmputations(player, zombie, handWeapon, damage)
    if not SandboxVars.TOC.EnableZombieAmputations then return end

    if not instanceof(zombie, "IsoZombie") or not instanceof(player, "IsoPlayer") then return end
    if player ~= getPlayer() then return end

    -- Check type of weapon. No hands, only knifes or such
    local weaponCategories = handWeapon:getScriptItem():getCategories()
    if not (weaponCategories:contains("Axe") or weaponCategories:contains("LongBlade")) then return end

    local isCrit = player:isCriticalHit()
    local randomChance = ZombRand(0, 100) > (100 - SandboxVars.TOC.ZombieAmputationDamageChance)
    if (damage > SandboxVars.TOC.ZombieAmputationDamageThreshold and randomChance) or isCrit then
        TOC_DEBUG.print("Amputating zombie limbs - damage: " .. tostring(damage))
        local zombieInv = zombie:getInventory()

        -- Check left or right
        local randSide = ZombRand(2)        -- Random side
        local preferredSide = randSide == 0 and "L" or "R"
        local alternateSide = preferredSide == "L" and "R" or "L"

        local predicatePreferred = preferredSide == "L" and PredicateAmputationItemLeft or PredicateAmputationItemRight
        local predicateAlternate = alternateSide == "L" and PredicateAmputationItemLeft or PredicateAmputationItemRight

        if not zombieInv:containsEval(predicatePreferred) then
            SpawnAmputation(zombie, preferredSide)
        elseif not zombieInv:containsEval(predicateAlternate) then
            SpawnAmputation(zombie, alternateSide)
        end

        TOC_DEBUG.print("Amputating zombie limbs - damage: " .. tostring(damage) .. ", preferred limb side: " .. preferredSide)

        -- add blood splat every couple of seconds for a while
        addBloodSplat(getCell():getGridSquare(zombie:getX(), zombie:getY(), zombie:getZ()), bloodAmount)
        local timerName = tostring(GetZombieID(zombie)) .. "_timer"
        timer:Create(timerName, 1, 10, function()
            addBloodSplat(getCell():getGridSquare(zombie:getX(), zombie:getY(), zombie:getZ()), bloodAmount)
        end)
    end
end

Events.OnWeaponHitCharacter.Add(HandleZombiesAmputations)

-----------------------------

local localOnlyZombiesMD

local function SetupZombiesModData()
    if not SandboxVars.TOC.EnableZombieAmputations then return end
    local zombieKey = CommandsData.GetZombieKey()
    localOnlyZombiesMD = ModData.getOrCreate(zombieKey)
end

Events.OnInitGlobalModData.Add(SetupZombiesModData)


-- HARMONIE 0.24.1 (lag with many zombies): OnZombieUpdate runs for EVERY
-- zombie EVERY frame. GetZombieID turns the outfit id into a 64-character
-- binary string, splits it into a table and parses it back -- per zombie
-- per frame, a heap of garbage with a big horde. Now: nothing at all while
-- no zombie has a stored amputation (the usual case), and the id is
-- worked out once per zombie (kept while its outfit id stays the same;
-- the game reuses zombie objects, so the outfit id is checked).
local idCache = setmetatable({}, { __mode = "k" })
local function cachedZombieID(zombie)
    local outfit = zombie:getPersistentOutfitID()
    local c = idCache[zombie]
    if c and c.outfit == outfit then return c.id end
    local id = GetZombieID(zombie)
    idCache[zombie] = { outfit = outfit, id = id }
    return id
end

---@param zombie IsoZombie
local function ReapplyAmputation(zombie)
    if not localOnlyZombiesMD or next(localOnlyZombiesMD) == nil then return end
    if not SandboxVars.TOC.EnableZombieAmputations then return end

    local pID = cachedZombieID(zombie)

    if localOnlyZombiesMD[pID] ~= nil then
        -- check if zombie has amputation
        local zombiesAmpData = localOnlyZombiesMD[pID]
        local zombieInv = zombie:getInventory()
        local foundItem = zombieInv:containsEvalRecurse(PredicateAmputationItems)

        if foundItem then
            return
        else
            local leftAmp = zombiesAmpData['L']
            if leftAmp then
                ItemsController.Zombie.SpawnAmputationItem(zombie, leftAmp)
            end

            local rightAmp = zombiesAmpData['R']
            if rightAmp then
                ItemsController.Zombie.SpawnAmputationItem(zombie, rightAmp)
            end

            -- Removes reference, local only
            localOnlyZombiesMD[pID] = nil
        end
    end
end

Events.OnZombieUpdate.Add(ReapplyAmputation)

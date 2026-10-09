MFSMagazineSyncServer = MFSMagazineSyncServer or {}

local Fix = MFSMagazineSyncServer

Fix.VERSION = "1.3.0"
Fix.MODULE = "ModernFirearmsSystemMPFix"
Fix.COMMAND = "SetMagazineTypeInPlace"
Fix.ACK_COMMAND = "MagazineStateConfirmed"

local function log(message)
    print("[MFSMagazineSyncServer] " .. tostring(message))
end

local function safeInstanceItem(fullType)
    if type(fullType) ~= "string" or fullType == "" then
        return nil
    end

    local ok, item = pcall(instanceItem, fullType)
    return ok and item or nil
end

local function getItemTag(resourceName)
    local ok, tag = pcall(function()
        return ItemTag.get(ResourceLocation.of(resourceName))
    end)
    return ok and tag or nil
end

local GUN_MAGAZINE_TAG = nil
local GUN_DRUM_TAG = nil

local function isMagazineItem(item)
    if not item or instanceof(item, "HandWeapon") or item:IsWeapon() then
        return false
    end

    GUN_MAGAZINE_TAG = GUN_MAGAZINE_TAG or getItemTag("base:gunmagazine")
    GUN_DRUM_TAG = GUN_DRUM_TAG or getItemTag("base:gundrum")
    local ok, tagged = pcall(function()
        return (GUN_MAGAZINE_TAG and item:hasTag(GUN_MAGAZINE_TAG))
            or (GUN_DRUM_TAG and item:hasTag(GUN_DRUM_TAG))
    end)
    if ok and tagged == true then
        return true
    end

    -- Fallback for magazines/drums that lack the base:gunmagazine/gundrum tag
    -- (e.g. 556Clip, AR57Drum_cat, JS14_Clip, M91Drum_cat): any non-weapon that
    -- carries a registered AmmoType and a positive magazine capacity.
    local fallbackOk, isMagazine = pcall(function()
        local maxAmmo = item:getMaxAmmo()
        return maxAmmo ~= nil and maxAmmo > 0 and item:getAmmoType() ~= nil
    end)
    return fallbackOk and isMagazine == true
end

local function getAmmoKey(item)
    if not item then
        return nil
    end

    local ok, ammoType = pcall(function()
        return item:getAmmoType()
    end)
    if not ok or not ammoType then
        return nil
    end

    local keyOk, itemKey = pcall(function()
        return ammoType:getItemKey()
    end)
    return keyOk and itemKey or nil
end

local function resolveMagazine(magazineType)
    local magazine = safeInstanceItem(magazineType)
    if not magazine then
        return nil, nil
    end
    if not isMagazineItem(magazine) then
        return nil, nil
    end

    local maxAmmoOk, maxAmmo = pcall(function()
        return magazine:getMaxAmmo()
    end)
    if not maxAmmoOk or not maxAmmo or maxAmmo <= 0 or not getAmmoKey(magazine) then
        return nil, nil
    end
    return magazine, magazine:getFullType()
end

local function canonicalMagazineType(magazineType)
    local _, canonicalType = resolveMagazine(magazineType)
    return canonicalType
end

local function isCompatibleMagazine(weapon, magazine)
    local weaponAmmoKey = getAmmoKey(weapon)
    local magazineAmmoKey = getAmmoKey(magazine)
    return weaponAmmoKey ~= nil and magazineAmmoKey ~= nil and weaponAmmoKey == magazineAmmoKey
end

local function findItemRecursive(container, itemID, depth)
    if not container or depth > 8 then
        return nil
    end

    local direct = container:getItemById(itemID)
    if direct then
        return direct
    end

    local items = container:getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item and item:getID() == itemID then
            return item
        end
        if item and instanceof(item, "InventoryContainer") then
            local nested = findItemRecursive(item:getInventory(), itemID, depth + 1)
            if nested then
                return nested
            end
        end
    end
    return nil
end

local function captureState(weapon)
    local modData = weapon:getModData()
    local hasPartTable = type(modData.weaponpart) == "table"
    return {
        magazineType = weapon:getMagazineType(),
        maxAmmo = weapon:getMaxAmmo(),
        savedMagazineType = modData.MagzineTypeNow,
        hasPartTable = hasPartTable,
        clipPart = hasPartTable and modData.weaponpart.Clip or nil,
        currentAmmoCount = weapon:getCurrentAmmoCount(),
        roundChambered = weapon:isRoundChambered(),
        containsClip = weapon:isContainsClip(),
        spentRoundCount = weapon:getSpentRoundCount(),
        spentRoundChambered = weapon:isSpentRoundChambered(),
        jammed = weapon:isJammed(),
        fireMode = weapon:getFireMode()
    }
end

local function restoreState(weapon, state)
    weapon:setMagazineType(state.magazineType)
    weapon:setMaxAmmo(state.maxAmmo)
    weapon:setCurrentAmmoCount(state.currentAmmoCount)
    weapon:setRoundChambered(state.roundChambered)
    weapon:setContainsClip(state.containsClip)
    weapon:setSpentRoundCount(state.spentRoundCount)
    weapon:setSpentRoundChambered(state.spentRoundChambered)
    weapon:setJammed(state.jammed)
    if state.fireMode then
        weapon:setFireMode(state.fireMode)
    end
    weapon:getModData().MagzineTypeNow = state.savedMagazineType
    if state.hasPartTable and type(weapon:getModData().weaponpart) == "table" then
        weapon:getModData().weaponpart.Clip = state.clipPart
    end
end

local function dynamicStateUnchanged(weapon, state)
    return weapon:getCurrentAmmoCount() == state.currentAmmoCount
        and weapon:isRoundChambered() == state.roundChambered
        and weapon:isContainsClip() == state.containsClip
        and weapon:getSpentRoundCount() == state.spentRoundCount
        and weapon:isSpentRoundChambered() == state.spentRoundChambered
        and weapon:isJammed() == state.jammed
        and weapon:getFireMode() == state.fireMode
end

local function sendConfirmation(player, weapon, accepted, reason, requestID)
    sendServerCommand(player, Fix.MODULE, Fix.ACK_COMMAND, {
        fixVersion = Fix.VERSION,
        accepted = accepted == true,
        reason = reason,
        requestID = requestID,
        itemID = weapon:getID(),
        weaponType = weapon:getFullType(),
        magazineType = weapon:getMagazineType(),
        maxAmmo = weapon:getMaxAmmo(),
        currentAmmoCount = weapon:getCurrentAmmoCount(),
        roundChambered = weapon:isRoundChambered(),
        containsClip = weapon:isContainsClip(),
        spentRoundCount = weapon:getSpentRoundCount(),
        spentRoundChambered = weapon:isSpentRoundChambered(),
        jammed = weapon:isJammed(),
        fireMode = weapon:getFireMode()
    })
end

local function savedTypeMatchesTransition(weapon, currentType, previousType, requestedType)
    local rawSavedType = weapon:getModData().MagzineTypeNow
    if rawSavedType == nil then
        return true
    end

    local savedType = canonicalMagazineType(rawSavedType)
    return savedType ~= nil
        and (savedType == currentType or savedType == previousType or savedType == requestedType)
end

local function getSavedMagazineType(weapon)
    return canonicalMagazineType(weapon:getModData().MagzineTypeNow)
end

local function applyMagazineInPlace(player, args)
    if not player or type(args) ~= "table" then
        return false, "invalid request"
    end
    if args.fixVersion ~= Fix.VERSION then
        return false, "client/server FIX version mismatch: client="
            .. tostring(args.fixVersion) .. " server=" .. Fix.VERSION
    end
    if type(args.repairOnly) ~= "boolean" then
        return false, "missing transition mode"
    end
    if not tonumber(args.requestID) then
        return false, "missing request ID"
    end

    local itemID = tonumber(args.itemID)
    local inventory = player:getInventory()
    local weapon = itemID and findItemRecursive(inventory, itemID, 0) or nil
    if not weapon then
        return false, "weapon ID is not in the player's root inventory"
    end
    if not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return false, "item is not a ranged weapon"
    end
    if args.weaponType and weapon:getFullType() ~= args.weaponType then
        return false, "weapon type mismatch"
    end

    local requestedMagazine, requestedType = resolveMagazine(args.magazineType)
    if not requestedMagazine then
        return false, "invalid requested magazine"
    end
    if not isCompatibleMagazine(weapon, requestedMagazine) then
        return false, "incompatible or unregistered AmmoType"
    end

    local currentType = canonicalMagazineType(weapon:getMagazineType())
    local previousType = canonicalMagazineType(args.previousMagazineType)
    local requestAlreadyApplied = currentType == requestedType
    if not requestAlreadyApplied and (not previousType or currentType ~= previousType) then
        return false, "stale or out-of-order magazine transition"
    end

    local previousMaxAmmo = tonumber(args.previousMaxAmmo)
    if not requestAlreadyApplied
        and (not previousMaxAmmo or weapon:getMaxAmmo() ~= previousMaxAmmo) then
        return false, "previous magazine capacity mismatch"
    end
    if not savedTypeMatchesTransition(weapon, currentType, previousType, requestedType) then
        return false, "magazine mod data does not match this transition"
    end
    if args.repairOnly and currentType ~= requestedType
        and getSavedMagazineType(weapon) ~= requestedType then
        return false, "repair request does not match the server-saved magazine type"
    end

    local requestedMaxAmmo = requestedMagazine:getMaxAmmo()
    if weapon:getCurrentAmmoCount() > requestedMaxAmmo then
        return false, "current ammunition exceeds requested capacity"
    end
    if not args.repairOnly
        and (weapon:isContainsClip() or weapon:getCurrentAmmoCount() > 0) then
        return false, "live magazine transition requires an empty/ejected magazine"
    end

    local previousState = captureState(weapon)
    local applyOk, applyError = pcall(function()
        weapon:setMagazineType(requestedType)
        weapon:setMaxAmmo(requestedMaxAmmo)
        weapon:getModData().MagzineTypeNow = requestedType

        local weaponParts = weapon:getModData().weaponpart
        if weapon:isContainsClip() and type(weaponParts) == "table" then
            weaponParts.Clip = requestedType
        end

        if weapon:getMagazineType() ~= requestedType
            or weapon:getMaxAmmo() ~= requestedMaxAmmo then
            error("post-change verification failed")
        end
        if not dynamicStateUnchanged(weapon, previousState) then
            error("dynamic weapon state changed unexpectedly")
        end
    end)

    if not applyOk then
        local rollbackOk, rollbackError = pcall(restoreState, weapon, previousState)
        if not rollbackOk then
            log("CRITICAL: server state rollback failed for id=" .. tostring(weapon:getID())
                .. ": " .. tostring(rollbackError))
        end
        return false, "in-place state apply failed: " .. tostring(applyError)
    end

    if syncHandWeaponFields then
        pcall(syncHandWeaponFields, player, weapon)
    end
    local confirmationOk, confirmationError = pcall(
        sendConfirmation, player, weapon, true, nil, args.requestID)
    if not confirmationOk then
        log("confirmation send failed for id=" .. tostring(weapon:getID())
            .. ": " .. tostring(confirmationError))
    end

    log("synchronized in place " .. weapon:getFullType()
        .. " id=" .. tostring(weapon:getID())
        .. " magazine=" .. requestedType
        .. " maxAmmo=" .. tostring(weapon:getMaxAmmo())
        .. " dynamic-state-preserved=true")
    return true
end

local function onClientCommand(module, command, player, args)
    if module ~= Fix.MODULE or command ~= Fix.COMMAND then
        return
    end

    local callOk, applied, reason = pcall(applyMagazineInPlace, player, args)
    if not callOk then
        log("protected server in-place error: " .. tostring(applied))
        return
    end
    if not applied then
        log("rejected magazine synchronization: " .. tostring(reason))
        local itemID = type(args) == "table" and tonumber(args.itemID) or nil
        local weapon = itemID and player
            and findItemRecursive(player:getInventory(), itemID, 0) or nil
        if weapon and instanceof(weapon, "HandWeapon") then
            local confirmationOk, confirmationError = pcall(
                sendConfirmation, player, weapon, false, tostring(reason),
                type(args) == "table" and args.requestID or nil)
            if not confirmationOk then
                log("rejection confirmation failed for id=" .. tostring(itemID)
                    .. ": " .. tostring(confirmationError))
            end
        end
    end
end

if not Fix._eventRegistered then
    Events.OnClientCommand.Add(onClientCommand)
    Fix._eventRegistered = true
end

log("version " .. Fix.VERSION .. " loaded; no inventory remove/add transaction is used")

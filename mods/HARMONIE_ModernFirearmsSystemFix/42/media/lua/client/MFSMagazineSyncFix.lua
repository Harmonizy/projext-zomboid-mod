MFSMagazineSyncFix = MFSMagazineSyncFix or {}

require "TimedActions/ISInventoryTransferAction"
require "TimedActions/ISDropWorldItemAction"

local Fix = MFSMagazineSyncFix

Fix.VERSION = "1.3.0"
Fix.MODULE = "ModernFirearmsSystemMPFix"
Fix.COMMAND = "SetMagazineTypeInPlace"
Fix.inProgress = Fix.inProgress or {}
Fix.pending = Fix.pending or {}
Fix.ACK_TIMEOUT_TICKS = 600
Fix.MAX_ACK_RETRIES = 6
Fix.nextRequestID = Fix.nextRequestID or 0

local function log(message)
    print("[MFSMagazineSyncFix] " .. tostring(message))
end

local function safeInstanceItem(fullType)
    if type(fullType) ~= "string" or fullType == "" then
        return nil
    end

    local ok, item = pcall(instanceItem, fullType)
    if not ok then
        log("could not create validation item " .. tostring(fullType) .. ": " .. tostring(item))
        return nil
    end
    return item
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
        return nil, nil, "invalid magazine item"
    end
    if not isMagazineItem(magazine) then
        return nil, nil, "requested item lacks an MFS magazine/drum tag"
    end

    local maxAmmoOk, maxAmmo = pcall(function()
        return magazine:getMaxAmmo()
    end)
    if not maxAmmoOk or not maxAmmo or maxAmmo <= 0 then
        return nil, nil, "item has no positive magazine capacity"
    end
    if not getAmmoKey(magazine) then
        return nil, nil, "magazine has no registered AmmoType"
    end

    return magazine, magazine:getFullType(), nil
end

local function isCompatibleMagazine(weapon, magazine)
    local weaponAmmoKey = getAmmoKey(weapon)
    local magazineAmmoKey = getAmmoKey(magazine)
    return weaponAmmoKey ~= nil and magazineAmmoKey ~= nil and weaponAmmoKey == magazineAmmoKey
end

local function resetEquippedModel(playerObj)
    local ok, err = pcall(function()
        playerObj:resetEquippedHandsModels()
    end)
    if not ok then
        log("equipped-model refresh failed: " .. tostring(err))
    end
end

local function notifyServer(playerObj, weapon, previousState, canonicalType, repairOnly, requestID)
    if not isClient() then
        return true
    end

    local ok, err = pcall(sendClientCommand, playerObj, Fix.MODULE, Fix.COMMAND, {
        fixVersion = Fix.VERSION,
        itemID = weapon:getID(),
        weaponType = weapon:getFullType(),
        previousMagazineType = previousState.magazineType,
        previousMaxAmmo = previousState.maxAmmo,
        magazineType = canonicalType,
        repairOnly = repairOnly == true,
        requestID = requestID
    })

    if not ok then
        log("server in-place request failed for id=" .. tostring(weapon:getID()) .. ": " .. tostring(err))
        return false
    end
    return true
end

local function captureStaticState(weapon)
    local modData = weapon:getModData()
    local hasPartTable = type(modData.weaponpart) == "table"
    return {
        itemID = weapon:getID(),
        magazineType = weapon:getMagazineType(),
        maxAmmo = weapon:getMaxAmmo(),
        savedMagazineType = modData.MagzineTypeNow,
        hasPartTable = hasPartTable,
        clipPart = hasPartTable and modData.weaponpart.Clip or nil
    }
end

local function restoreStaticState(playerObj, weapon, state)
    local ok, err = pcall(function()
        weapon:setMagazineType(state.magazineType)
        weapon:setMaxAmmo(state.maxAmmo)
        weapon:getModData().MagzineTypeNow = state.savedMagazineType
        if state.hasPartTable and type(weapon:getModData().weaponpart) == "table" then
            weapon:getModData().weaponpart.Clip = state.clipPart
        end
        resetEquippedModel(playerObj)
    end)

    if not ok then
        log("CRITICAL: in-place rollback failed for id=" .. tostring(state.itemID)
            .. ": " .. tostring(err))
        return false
    end
    return true
end

local function changeMagazineInPlace(
    playerObj, weapon, magazine, canonicalType, repairOnly)
    local previousState = captureStaticState(weapon)
    local requestedMaxAmmo = magazine:getMaxAmmo()

    -- Changing the magazine well while loose rounds are still recorded would
    -- silently clamp or create ammunition.  Leave the gun untouched instead.
    if weapon:getCurrentAmmoCount() > requestedMaxAmmo then
        log("in-place change rejected because ammo exceeds requested capacity id="
            .. tostring(weapon:getID()))
        return false, nil
    end
    if not repairOnly and (weapon:isContainsClip() or weapon:getCurrentAmmoCount() > 0) then
        log("in-place change rejected until the current magazine is empty/ejected id="
            .. tostring(weapon:getID()))
        return false, nil
    end

    local changed, changeError = pcall(function()
        weapon:setMagazineType(canonicalType)
        weapon:setMaxAmmo(requestedMaxAmmo)
        weapon:getModData().MagzineTypeNow = canonicalType

        local weaponParts = weapon:getModData().weaponpart
        if weapon:isContainsClip() and type(weaponParts) == "table" then
            weaponParts.Clip = canonicalType
        end

        if weapon:getID() ~= previousState.itemID
            or weapon:getMagazineType() ~= canonicalType
            or weapon:getMaxAmmo() ~= requestedMaxAmmo then
            error("post-change verification failed")
        end
        resetEquippedModel(playerObj)
    end)

    if not changed then
        restoreStaticState(playerObj, weapon, previousState)
        log("in-place magazine change failed; original fields restored id="
            .. tostring(previousState.itemID) .. ": " .. tostring(changeError))
        return false, nil
    end

    log("changed in place id=" .. tostring(weapon:getID())
        .. " magazine=" .. tostring(previousState.magazineType)
        .. " -> " .. canonicalType
        .. " maxAmmo=" .. tostring(previousState.maxAmmo)
        .. " -> " .. tostring(requestedMaxAmmo))
    return true, previousState
end

function Fix.acceptsConfirmation(itemID, requestID)
    itemID = tonumber(itemID)
    local pending = itemID and Fix.pending[itemID] or nil
    if not pending then
        return false
    end
    return tonumber(pending.requestID) == tonumber(requestID)
end

function Fix.completeRequest(itemID, requestID, accepted)
    itemID = tonumber(itemID)
    if not itemID then
        return
    end

    local pending = Fix.pending[itemID]
    if pending and tonumber(pending.requestID) ~= tonumber(requestID) then
        log("stale server confirmation ignored id=" .. tostring(itemID)
            .. " request=" .. tostring(requestID)
            .. " active=" .. tostring(pending.requestID))
        return
    end
    if pending then
        log("server request completed id=" .. tostring(itemID)
            .. " request=" .. tostring(requestID)
            .. " accepted=" .. tostring(accepted == true))
    end
    Fix.pending[itemID] = nil
    Fix.inProgress[itemID] = nil
end

function Fix.isPendingItem(item)
    if not item or not item.getID then
        return false
    end
    return Fix.pending[item:getID()] ~= nil
end

function Fix.clearPendingRequests()
    local count = 0
    for _ in pairs(Fix.pending) do
        count = count + 1
    end
    Fix.pending = {}
    Fix.inProgress = {}
    if count > 0 then
        log("cleared " .. tostring(count)
            .. " pending request lock(s) while leaving all weapon items untouched")
    end
end

local function logBlockedTransfer(item, action)
    local pending = item and Fix.pending[item:getID()] or nil
    if pending and not pending.transferBlockedLogged then
        pending.transferBlockedLogged = true
        log(action .. " blocked until server confirms magazine type id="
            .. tostring(item:getID()))
    end
end

function Fix.installPendingItemGuards()
    if ISInventoryTransferAction and ISInventoryTransferAction.isValid
        and not ISInventoryTransferAction.__MFSPendingMagazineGuard then
        local originalTransferIsValid = ISInventoryTransferAction.isValid
        ISInventoryTransferAction.isValid = function(action)
            if Fix.isPendingItem(action.item) then
                logBlockedTransfer(action.item, "inventory transfer")
                return false
            end
            return originalTransferIsValid(action)
        end
        ISInventoryTransferAction.__MFSPendingMagazineGuard = true
    end

    if ISDropWorldItemAction and ISDropWorldItemAction.isValid
        and not ISDropWorldItemAction.__MFSPendingMagazineGuard then
        local originalDropIsValid = ISDropWorldItemAction.isValid
        ISDropWorldItemAction.isValid = function(action)
            if Fix.isPendingItem(action.item) then
                logBlockedTransfer(action.item, "world drop")
                return false
            end
            return originalDropIsValid(action)
        end
        ISDropWorldItemAction.__MFSPendingMagazineGuard = true
    end
    return true
end

local function updatePendingRequests()
    for itemID, pending in pairs(Fix.pending) do
        if not pending.halted then
            pending.ticks = pending.ticks - 1
        end
        if pending.ticks <= 0 then
            pending.ticks = Fix.ACK_TIMEOUT_TICKS
            pending.retries = pending.retries + 1
            if pending.retries > Fix.MAX_ACK_RETRIES then
                pending.halted = true
                log("server confirmation failed after " .. tostring(Fix.MAX_ACK_RETRIES)
                    .. " retries; safety lock retained until ACK or reconnect id="
                    .. tostring(itemID))
            else
                local playerObj = pending.playerObj or (getPlayer and getPlayer() or nil)
                local weapon = pending.weapon
                if playerObj and weapon and weapon:getID() == itemID then
                    local resent = notifyServer(
                        playerObj,
                        weapon,
                        pending.previousState,
                        pending.canonicalType,
                        pending.repairOnly,
                        pending.requestID)
                    log("server confirmation timed out; request resent id="
                        .. tostring(itemID)
                        .. " request=" .. tostring(pending.requestID)
                        .. " retry=" .. tostring(pending.retries)
                        .. " queued=" .. tostring(resent))
                else
                    log("server confirmation timed out; weapon reference unavailable id="
                        .. tostring(itemID) .. " (lock retained)")
                end
            end
        end
    end
end

-- The original MFS function deletes the equipped gun and creates another copy
-- of the same item type merely to change mutable HandWeapon fields.  Doing the
-- change on the existing object preserves its ID, hotbar/attachment references,
-- mod data and every third-party field, and removes the MP remove/add loss window.
--
-- NOTE ON LOAD ORDER: this file is in lua/client/ alongside MFS*.lua, which the
-- engine loads BEFORE the WeaponAbility/ subdirectory. WeaponAbility/ChangeMagazineType.lua
-- redefines the global ChangeMagzine with the original remove/re-add implementation,
-- so a plain `function ChangeMagzine(...)` here would be overwritten and the whole
-- MP fix silently lost. Keep the implementation in a local and re-assert the global
-- once the world is up (see reassertChangeMagzine at the bottom of this file).
local function changeMagzineImpl(playerObj, MainGun, MagazineType, Tag, Need)
    if not playerObj or not MainGun or not MagazineType or not Need then
        return
    end
    if not instanceof(MainGun, "HandWeapon") or not MainGun:isRanged() then
        log("magazine change rejected: item is not a ranged HandWeapon")
        return
    end

    local inventory = playerObj:getInventory()
    local itemID = MainGun:getID()
    if Fix.inProgress[itemID] then
        log("duplicate magazine change ignored for id=" .. tostring(itemID))
        return
    end
    if MainGun:getContainer() ~= inventory or not inventory:containsID(itemID)
        or playerObj:getPrimaryHandItem() ~= MainGun then
        log("stale magazine change ignored for id=" .. tostring(itemID))
        return
    end

    if MainGun:isContainsClip() and Tag ~= "ReFresh" then
        if ISTimedActionQueue and ISEjectMagazine then
            ISTimedActionQueue.add(ISEjectMagazine:new(playerObj, MainGun))
        else
            log("magazine change rejected because the current magazine is still inserted")
        end
        return
    end

    local magazine, canonicalType, resolveError = resolveMagazine(MagazineType)
    if not magazine then
        log("magazine change rejected for " .. tostring(MagazineType)
            .. ": " .. tostring(resolveError))
        return
    end
    if not isCompatibleMagazine(MainGun, magazine) then
        log("magazine change rejected because AmmoType differs: weapon="
            .. tostring(MainGun:getFullType()) .. " magazine=" .. tostring(canonicalType))
        return
    end

    local _, currentCanonical = resolveMagazine(MainGun:getMagazineType())
    local repairOnly = Tag == "ReFresh" or currentCanonical == canonicalType
    Fix.nextRequestID = Fix.nextRequestID + 1
    local requestID = Fix.nextRequestID

    Fix.inProgress[itemID] = true
    local changed = false
    local previousState = nil
    local completed, changeError = pcall(function()
        changed, previousState = changeMagazineInPlace(
            playerObj, MainGun, magazine, canonicalType, repairOnly)
    end)

    if completed and changed and isClient() then
        Fix.inProgress[itemID] = "awaiting-server"
        Fix.pending[itemID] = {
            ticks = Fix.ACK_TIMEOUT_TICKS,
            requestID = requestID,
            retries = 0,
            playerObj = playerObj,
            weapon = MainGun,
            previousState = previousState,
            canonicalType = canonicalType,
            repairOnly = repairOnly
        }
        local commandOk = notifyServer(
            playerObj, MainGun, previousState, canonicalType, repairOnly, requestID)
        if not commandOk then
            restoreStaticState(playerObj, MainGun, previousState)
            Fix.inProgress[itemID] = nil
            Fix.pending[itemID] = nil
            changed = false
            log("in-place change cancelled because the server command could not be sent id="
                .. tostring(itemID))
        end
    else
        Fix.inProgress[itemID] = nil
        Fix.pending[itemID] = nil
    end

    if completed and changed and not repairOnly
        and riskyInspectAction and riskyInspectAction.new then
        local refreshOk, refreshError = pcall(function()
            ISTimedActionQueue.add(riskyInspectAction:new(playerObj, 1))
        end)
        if not refreshOk then
            log("inspection refresh could not be queued: " .. tostring(refreshError))
        end
    end

    if not completed then
        log("magazine change aborted by protected error; gun object was not removed id="
            .. tostring(itemID) .. ": " .. tostring(changeError))
    end
end

-- Publish immediately for anything that runs between file load and game start.
-- reassertChangeMagzine (below) re-applies it after the world is up, so the
-- original WeaponAbility/ChangeMagazineType.lua definition cannot win.
ChangeMagzine = changeMagzineImpl

local function normalizeLegacyEquippedWeapon()
    local playerObj = getPlayer and getPlayer() or nil
    local weapon = playerObj and playerObj:getPrimaryHandItem() or nil
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return
    end

    local savedType = weapon:getModData().MagzineTypeNow
    if type(savedType) ~= "string" or savedType == "" then
        return
    end

    local _, savedCanonical = resolveMagazine(savedType)
    local _, currentCanonical = resolveMagazine(weapon:getMagazineType())
    if savedCanonical and (savedType ~= savedCanonical or currentCanonical ~= savedCanonical) then
        changeMagzineImpl(playerObj, weapon, savedCanonical, "ReFresh", true)
    end
end

-- The original WeaponAbility/ChangeMagazineType.lua loads after this file and
-- overwrites the global ChangeMagzine. Re-assert our in-place implementation on
-- game start (before any OnEquipPrimary/OnGameStart recovery handler runs), so
-- the UI and the legacy NeedRefresh handler both end up calling this version.
local function reassertChangeMagzine()
    ChangeMagzine = changeMagzineImpl
end

if not Fix._eventsRegistered then
    Events.OnGameStart.Add(reassertChangeMagzine)
    if Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(reassertChangeMagzine)
    end
    Events.OnEquipPrimary.Add(normalizeLegacyEquippedWeapon)
    Events.OnGameStart.Add(normalizeLegacyEquippedWeapon)
    Events.OnGameStart.Add(Fix.installPendingItemGuards)
    Events.OnPlayerUpdate.Add(updatePendingRequests)
    if Events.OnDisconnect then
        Events.OnDisconnect.Add(Fix.clearPendingRequests)
    end
    if Events.OnMainMenuEnter then
        Events.OnMainMenuEnter.Add(Fix.clearPendingRequests)
    end
    if Events.OnPlayerDeath then
        Events.OnPlayerDeath.Add(Fix.clearPendingRequests)
    end
    Fix._eventsRegistered = true
end

Fix.installPendingItemGuards()

log("version " .. Fix.VERSION .. " loaded; all magazine-type changes preserve the weapon object")

require "TimedActions/ISReloadWeaponAction"
require "TimedActions/ISEjectMagazine"

MFSReloadGuard = MFSReloadGuard or {}

local Fix = MFSReloadGuard

Fix.VERSION = "1.3.0"

local function log(message)
    print("[MFSReloadGuard] " .. tostring(message))
end

local function getAmmoKey(item)
    if not item then
        return nil
    end

    local ok, itemKey = pcall(function()
        local ammoType = item:getAmmoType()
        return ammoType and ammoType:getItemKey() or nil
    end)
    return ok and itemKey or nil
end

local function getBestMagazine(playerObj, gun)
    local ok, magazine = pcall(function()
        return gun:getBestMagazine(playerObj)
    end)
    if not ok then
        log("getBestMagazine failed for " .. tostring(gun:getFullType()) .. ": " .. tostring(magazine))
        return nil, false
    end
    return magazine, true
end

local function callProtected(label, original, ...)
    local ok, result = pcall(original, ...)
    if not ok then
        log(label .. " cancelled by protected error: " .. tostring(result))
        return nil
    end
    return result
end

local function isMagazineSyncPending(gun)
    return gun and MFSMagazineSyncFix and MFSMagazineSyncFix.inProgress
        and MFSMagazineSyncFix.inProgress[gun:getID()] ~= nil
end

function Fix.install()
    if not ISReloadWeaponAction or not ISReloadWeaponAction.ReloadBestMagazine
        or not ISReloadWeaponAction.BeginAutomaticReload then
        return false
    end
    if ISReloadWeaponAction.__MFSReloadGuardPatched then
        return true
    end

    local originalReloadBestMagazine = ISReloadWeaponAction.ReloadBestMagazine
    local originalBeginAutomaticReload = ISReloadWeaponAction.BeginAutomaticReload

    ISReloadWeaponAction.ReloadBestMagazine = function(playerObj, gun)
        if not playerObj or not gun then
            return
        end
        if isMagazineSyncPending(gun) then
            log("reload blocked while magazine type awaits server confirmation id="
                .. tostring(gun:getID()))
            return
        end

        local magazine, lookupOk = getBestMagazine(playerObj, gun)
        if not lookupOk then
            return
        end
        if magazine and not getAmmoKey(magazine) then
            log("reload blocked: magazine has no registered AmmoType item="
                .. tostring(magazine:getFullType()))
            return
        end

        return callProtected("ReloadBestMagazine", originalReloadBestMagazine, playerObj, gun)
    end

    ISReloadWeaponAction.BeginAutomaticReload = function(playerObj, gun)
        if not playerObj or not gun then
            return
        end
        if isMagazineSyncPending(gun) then
            log("automatic reload blocked while magazine type awaits server confirmation id="
                .. tostring(gun:getID()))
            return
        end

        if gun:getMagazineType() then
            local magazine, lookupOk = getBestMagazine(playerObj, gun)
            if not lookupOk then
                return
            end
            if magazine and not getAmmoKey(magazine) then
                log("automatic reload blocked: magazine has no registered AmmoType item="
                    .. tostring(magazine:getFullType()))
                if gun:isContainsClip() then
                    ISTimedActionQueue.add(ISEjectMagazine:new(playerObj, gun))
                end
                return
            end
        elseif not getAmmoKey(gun) then
            log("automatic reload blocked: firearm has no registered AmmoType item="
                .. tostring(gun:getFullType()))
            return
        end

        return callProtected("BeginAutomaticReload", originalBeginAutomaticReload, playerObj, gun)
    end

    ISReloadWeaponAction.__MFSReloadGuardPatched = true
    log("version " .. Fix.VERSION .. " installed")
    return true
end

Fix.install()
Events.OnGameStart.Add(Fix.install)

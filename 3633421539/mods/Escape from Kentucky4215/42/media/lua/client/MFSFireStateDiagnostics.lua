require "TimedActions/ISReloadWeaponAction"

MFSFireStateDiagnostics = MFSFireStateDiagnostics or {}

local Diagnostics = MFSFireStateDiagnostics

Diagnostics.VERSION = "1.3.0"
Diagnostics.LOG_COOLDOWN_MS = 3000
Diagnostics.lastLog = Diagnostics.lastLog or {}

local function log(message)
    print("[MFSFireState] " .. tostring(message))
end

local function isMFSWeapon(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return false
    end

    local modData = weapon:getModData()
    if modData and modData.MagzineTypeNow ~= nil then
        return true
    end

    local weaponType = weapon:getType()
    if AWCWF_WeaponMagazineType and AWCWF_WeaponMagazineType[weaponType] then
        return true
    end
    if AWCWF_GunShotProfiles and AWCWF_GunShotProfiles[weaponType] then
        return true
    end

    return false
end

local function getFailureReason(player, weapon)
    if weapon:isSelectFire() and weapon:getFireMode() == "Safe" then
        return "safe-fire-mode"
    end
    if weapon:isJammed() then
        return "jammed"
    end
    if weapon:haveChamber() and not weapon:isRoundChambered() then
        return "empty-chamber"
    end
    if not weapon:haveChamber() and weapon:getCurrentAmmoCount() <= 0 then
        return "no-ammo"
    end
    if player and player:isUnlimitedAmmo() then
        return "unknown-unlimited-ammo"
    end
    return "unknown"
end

local function shouldLog(weapon, reason)
    local key = tostring(weapon:getID()) .. ":" .. reason
    local now = getTimestampMs()
    local previous = Diagnostics.lastLog[key] or 0
    if now - previous < Diagnostics.LOG_COOLDOWN_MS then
        return false
    end
    Diagnostics.lastLog[key] = now
    return true
end

local function describeWeapon(player, weapon, reason)
    local primary = player and player:getPrimaryHandItem() or nil
    return "blocked reason=" .. tostring(reason)
        .. " type=" .. tostring(weapon:getFullType())
        .. " id=" .. tostring(weapon:getID())
        .. " ammo=" .. tostring(weapon:getCurrentAmmoCount())
        .. "/" .. tostring(weapon:getMaxAmmo())
        .. " chambered=" .. tostring(weapon:isRoundChambered())
        .. " spentChambered=" .. tostring(weapon:isSpentRoundChambered())
        .. " containsClip=" .. tostring(weapon:isContainsClip())
        .. " jammed=" .. tostring(weapon:isJammed())
        .. " fireMode=" .. tostring(weapon:getFireMode())
        .. " primaryMatches=" .. tostring(primary == weapon)
end

function Diagnostics.install()
    if not ISReloadWeaponAction or not ISReloadWeaponAction.canShoot then
        return false
    end
    if ISReloadWeaponAction.__MFSFireStateDiagnosticsPatched then
        return true
    end

    local originalCanShoot = ISReloadWeaponAction.canShoot
    ISReloadWeaponAction.canShoot = function(player, weapon)
        local canShoot = originalCanShoot(player, weapon)
        if not canShoot and isMFSWeapon(weapon) then
            local reason = getFailureReason(player, weapon)
            if shouldLog(weapon, reason) then
                log(describeWeapon(player, weapon, reason))
            end
        end
        return canShoot
    end

    ISReloadWeaponAction.__MFSFireStateDiagnosticsPatched = true
    log("version " .. Diagnostics.VERSION .. " installed")
    return true
end

Diagnostics.install()
Events.OnGameStart.Add(Diagnostics.install)

MFSMagazineStateConfirmation = MFSMagazineStateConfirmation or {}

local Confirmation = MFSMagazineStateConfirmation

Confirmation.VERSION = "1.3.0"
Confirmation.MODULE = "ModernFirearmsSystemMPFix"
Confirmation.COMMAND = "MagazineStateConfirmed"

local function log(message)
    print("[MFSMagazineState] " .. tostring(message))
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

local function findWeapon(itemID)
    local player = getPlayer and getPlayer() or nil
    if not player or not itemID then
        return nil, nil
    end
    itemID = tonumber(itemID)
    local primary = player:getPrimaryHandItem()
    if primary and primary:getID() == itemID then
        return player, primary
    end
    return player, findItemRecursive(player:getInventory(), itemID, 0)
end

local function applyAuthoritativeStaticState(player, weapon, args)
    local magazineType = type(args.magazineType) == "string" and args.magazineType or nil
    local maxAmmo = tonumber(args.maxAmmo)
    if not magazineType or not maxAmmo or maxAmmo <= 0 then
        return false, "invalid authoritative magazine fields"
    end
    if args.weaponType and weapon:getFullType() ~= args.weaponType then
        return false, "weapon type mismatch"
    end
    if weapon:getCurrentAmmoCount() > maxAmmo then
        return false, "local ammunition exceeds authoritative capacity"
    end

    local ok, err = pcall(function()
        weapon:setMagazineType(magazineType)
        weapon:setMaxAmmo(maxAmmo)
        weapon:getModData().MagzineTypeNow = magazineType

        local weaponParts = weapon:getModData().weaponpart
        if weapon:isContainsClip() and type(weaponParts) == "table" then
            weaponParts.Clip = magazineType
        end

        player:resetEquippedHandsModels()
        if weapon:getMagazineType() ~= magazineType or weapon:getMaxAmmo() ~= maxAmmo then
            error("post-confirmation verification failed")
        end
    end)
    return ok, err
end

local function confirmationIsCurrent(itemID, requestID)
    if MFSMagazineSyncFix and MFSMagazineSyncFix.acceptsConfirmation then
        return MFSMagazineSyncFix.acceptsConfirmation(itemID, requestID)
    end
    return false
end

local function releaseRequest(itemID, requestID, accepted)
    if MFSMagazineSyncFix and MFSMagazineSyncFix.completeRequest then
        MFSMagazineSyncFix.completeRequest(itemID, requestID, accepted)
    end
end

local function onServerCommand(module, command, args)
    if module ~= Confirmation.MODULE or command ~= Confirmation.COMMAND
        or type(args) ~= "table" then
        return
    end

    local itemID = tonumber(args.itemID)
    if not itemID then
        return
    end
    if not confirmationIsCurrent(itemID, args.requestID) then
        log("stale server confirmation ignored id=" .. tostring(itemID)
            .. " request=" .. tostring(args.requestID))
        return
    end

    local player, weapon = findWeapon(itemID)
    if not weapon or not instanceof(weapon, "HandWeapon") then
        log("server confirmation references a missing local weapon id="
            .. tostring(itemID) .. " (request lock retained)")
        return
    end

    local applied, applyError = applyAuthoritativeStaticState(player, weapon, args)
    if not applied then
        log("authoritative field application failed id=" .. tostring(itemID)
            .. " accepted=" .. tostring(args.accepted == true)
            .. " reason=" .. tostring(args.reason)
            .. " error=" .. tostring(applyError)
            .. " (request lock retained)")
        return
    end

    if args.fixVersion ~= Confirmation.VERSION then
        log("FIX version mismatch confirmed by server: client=" .. Confirmation.VERSION
            .. " server=" .. tostring(args.fixVersion))
    end

    if args.accepted == false then
        log("server rejected transition and restored authoritative fields id="
            .. tostring(itemID)
            .. " magazine=" .. tostring(weapon:getMagazineType())
            .. " maxAmmo=" .. tostring(weapon:getMaxAmmo())
            .. " reason=" .. tostring(args.reason))
        releaseRequest(itemID, args.requestID, false)
        return
    end

    log("server confirmed state id=" .. tostring(weapon:getID())
        .. " magazine=" .. tostring(weapon:getMagazineType())
        .. " ammo=" .. tostring(weapon:getCurrentAmmoCount())
        .. "/" .. tostring(weapon:getMaxAmmo())
        .. " chambered=" .. tostring(weapon:isRoundChambered())
        .. " clip=" .. tostring(weapon:isContainsClip())
        .. " jammed=" .. tostring(weapon:isJammed())
        .. " fireMode=" .. tostring(weapon:getFireMode()))
    releaseRequest(itemID, args.requestID, true)
end

if not Confirmation._eventRegistered then
    Events.OnServerCommand.Add(onServerCommand)
    Confirmation._eventRegistered = true
end

log("version " .. Confirmation.VERSION .. " loaded")

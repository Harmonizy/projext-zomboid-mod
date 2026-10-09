MFSPartOffsetSyncServer = MFSPartOffsetSyncServer or {}

local Sync = MFSPartOffsetSyncServer

Sync.VERSION = "0.1.0-rc2"
Sync.MODULE = "MFSPartOffsetSync"
Sync.COMMAND = "StoreGunPos"
Sync.ACK_COMMAND = "GunPosStored"
Sync.DEBUG = false -- RC2 accepted; retain logging code for future troubleshooting.

local function log(message)
    if Sync.DEBUG then
        print("[MFSOffsetSyncServer] " .. tostring(message))
    end
end

local function isFiniteOffset(value)
    value = tonumber(value)
    return value and value == value and value ~= math.huge and value ~= -math.huge
        and math.abs(value) <= 10
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

local function isWeaponPartType(fullType)
    if type(fullType) ~= "string" or fullType == "" or #fullType > 160 then
        return false
    end
    local ok, item = pcall(instanceItem, fullType)
    return ok and item and instanceof(item, "WeaponPart")
end

local function decodeGunPos(args)
    local count = tonumber(args.entryCount)
    if not count or count < 0 or count > 64 or count ~= math.floor(count) then
        return nil, "invalid entry count"
    end
    local result = {}
    for index = 1, count do
        local fullType = args["part" .. index]
        local x = tonumber(args["x" .. index])
        local y = tonumber(args["y" .. index])
        local z = tonumber(args["z" .. index])
        if not isWeaponPartType(fullType) then
            return nil, "invalid weapon-part key at entry " .. index
        end
        if not isFiniteOffset(x) or not isFiniteOffset(y) or not isFiniteOffset(z) then
            return nil, "invalid offset at entry " .. index
        end
        if result[fullType] then
            return nil, "duplicate weapon-part key at entry " .. index
        end
        result[fullType] = { x = x, y = y, z = z }
    end
    return result, count
end

local function acknowledge(player, args, accepted, reason, entryCount)
    sendServerCommand(player, Sync.MODULE, Sync.ACK_COMMAND, {
        syncVersion = Sync.VERSION,
        requestID = args and args.requestID or nil,
        itemID = args and args.itemID or nil,
        accepted = accepted == true,
        reason = reason,
        entryCount = entryCount or 0
    })
end

local function applyGunPos(player, args)
    if not player or type(args) ~= "table" then
        return false, "invalid request"
    end
    if args.syncVersion ~= Sync.VERSION then
        return false, "client/server version mismatch"
    end
    if not tonumber(args.requestID) then
        return false, "missing request ID"
    end

    local itemID = tonumber(args.itemID)
    local weapon = itemID and findItemRecursive(player:getInventory(), itemID, 0) or nil
    if not weapon then
        return false, "weapon ID is not in the player's inventory"
    end
    if not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return false, "item is not a ranged weapon"
    end
    if type(args.weaponType) ~= "string" or weapon:getFullType() ~= args.weaponType then
        return false, "weapon type mismatch"
    end

    local gunPos, countOrReason = decodeGunPos(args)
    if not gunPos then
        return false, countOrReason
    end
    weapon:getModData().GunPos = gunPos
    return true, nil, countOrReason, weapon
end

local function onClientCommand(module, command, player, args)
    if module ~= Sync.MODULE or command ~= Sync.COMMAND then
        return
    end

    local ok, applied, reason, count, weapon = pcall(applyGunPos, player, args)
    if not ok then
        reason = tostring(applied)
        applied = false
    end
    local ackOk, ackError = pcall(acknowledge, player, args, applied, reason, count)
    if not ackOk then
        log("acknowledgement failed: " .. tostring(ackError))
    end
    if not applied then
        log("rejected request=" .. tostring(type(args) == "table" and args.requestID or nil)
            .. " reason=" .. tostring(reason))
        return
    end

    log("stored request=" .. tostring(args.requestID)
        .. " id=" .. tostring(weapon:getID())
        .. " type=" .. tostring(weapon:getFullType())
        .. " entries=" .. tostring(count))
end

if not Sync._eventRegistered then
    Events.OnClientCommand.Add(onClientCommand)
    Sync._eventRegistered = true
end

log("version " .. Sync.VERSION .. " loaded")

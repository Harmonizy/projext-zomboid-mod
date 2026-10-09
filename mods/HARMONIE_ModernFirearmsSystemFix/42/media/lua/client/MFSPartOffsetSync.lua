MFSPartOffsetSync = MFSPartOffsetSync or {}

local Sync = MFSPartOffsetSync

Sync.VERSION = "0.1.0-rc2"
Sync.MODULE = "MFSPartOffsetSync"
Sync.COMMAND = "StoreGunPos"
Sync.ACK_COMMAND = "GunPosStored"
Sync.DEBOUNCE_MS = 400
Sync.DEBUG = false -- RC2 accepted; retain logging code for future troubleshooting.
Sync.dirty = Sync.dirty or setmetatable({}, { __mode = "k" })
Sync.pending = Sync.pending or {}
Sync.nextRequestID = Sync.nextRequestID or 0

local function log(message)
    if Sync.DEBUG then
        print("[MFSOffsetSync] " .. tostring(message))
    end
end

local function isFinite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function captureGunPos(weapon)
    local gunPos = weapon and weapon:getModData().GunPos or nil
    if type(gunPos) ~= "table" then
        return nil, 0
    end

    local keys = {}
    for fullType, position in pairs(gunPos) do
        if type(fullType) == "string" and type(position) == "table"
            and isFinite(position.x) and isFinite(position.y) and isFinite(position.z) then
            table.insert(keys, fullType)
        end
    end
    table.sort(keys)

    local payload = {}
    local count = math.min(#keys, 64)
    for index = 1, count do
        local fullType = keys[index]
        local position = gunPos[fullType]
        payload["part" .. index] = fullType
        payload["x" .. index] = position.x
        payload["y" .. index] = position.y
        payload["z" .. index] = position.z
    end
    return payload, count
end

local function sendGunPos(weapon, reason)
    if not isClient() then
        Sync.dirty[weapon] = nil
        return true
    end
    local player = getPlayer and getPlayer() or nil
    if not player or not weapon or not instanceof(weapon, "HandWeapon")
        or not weapon:isRanged() then
        return false
    end

    local positions, count = captureGunPos(weapon)
    if not positions then
        Sync.dirty[weapon] = nil
        return true
    end

    Sync.nextRequestID = Sync.nextRequestID + 1
    local requestID = Sync.nextRequestID
    local args = {
        syncVersion = Sync.VERSION,
        requestID = requestID,
        itemID = weapon:getID(),
        weaponType = weapon:getFullType(),
        entryCount = count,
        reason = tostring(reason or "debounce")
    }
    for key, value in pairs(positions) do
        args[key] = value
    end

    local ok, err = pcall(sendClientCommand, player, Sync.MODULE, Sync.COMMAND, args)
    if not ok then
        log("send failed id=" .. tostring(weapon:getID()) .. " error=" .. tostring(err))
        return false
    end

    Sync.pending[requestID] = {
        itemID = weapon:getID(),
        sentAt = getTimestampMs(),
        entryCount = count
    }
    Sync.dirty[weapon] = nil
    log("sent request=" .. requestID .. " id=" .. tostring(weapon:getID())
        .. " entries=" .. count .. " reason=" .. tostring(reason or "debounce"))
    return true
end

function MFS_GunPosChanged(weapon)
    if not weapon then
        return
    end
    Sync.dirty[weapon] = getTimestampMs()
end

function MFS_FlushGunPos(weapon, reason)
    if not weapon or not Sync.dirty[weapon] then
        return true
    end
    return sendGunPos(weapon, reason or "flush")
end

local function onPlayerUpdate(player)
    if not isClient() or player ~= getPlayer() then
        return
    end
    local now = getTimestampMs()
    for weapon, changedAt in pairs(Sync.dirty) do
        if now - changedAt >= Sync.DEBOUNCE_MS then
            sendGunPos(weapon, "debounce")
        end
    end
end

local function onServerCommand(module, command, args)
    if module ~= Sync.MODULE or command ~= Sync.ACK_COMMAND or type(args) ~= "table" then
        return
    end
    local requestID = tonumber(args.requestID)
    local pending = requestID and Sync.pending[requestID] or nil
    if not pending then
        log("stale acknowledgement request=" .. tostring(requestID))
        return
    end
    Sync.pending[requestID] = nil
    log("server acknowledged request=" .. requestID
        .. " id=" .. tostring(args.itemID)
        .. " accepted=" .. tostring(args.accepted == true)
        .. " entries=" .. tostring(args.entryCount)
        .. " reason=" .. tostring(args.reason))
end

local function resetSession()
    Sync.dirty = setmetatable({}, { __mode = "k" })
    Sync.pending = {}
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnServerCommand.Add(onServerCommand)
Events.OnGameStart.Add(resetSession)

log("version " .. Sync.VERSION .. " loaded; debounce=" .. Sync.DEBOUNCE_MS .. "ms")

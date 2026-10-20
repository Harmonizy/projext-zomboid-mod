--[[
    HARMONIE - Life With Style : the wardrobe (server; single player too)

    Global ModData "HARMONIE_LWS":
      owners[key] = {
        name   = last known player name (for the admin list),
        nextId = next piece number,
        items  = { [uid] = { p = pieceId, at = world hour, by = who gave it } },
        worn   = { [slot] = uid },
        show   = { [slot] = true }   -- draw the real clothes too (_Over twin)
      }
    The pieces are entries, not items: nothing to drop, steal or lose.

    Worn pieces are made real only to be drawn (LWS.ensure): for every worn
    slot one weightless item "<module>.<piece>[_Over]" in the player's
    inventory, worn by the client. Anything of our module in a player's
    inventory that the wardrobe does not say should be there is deleted --
    a piece someone took off a corpse, a stale twin, a duplicate. On death
    the worn items are deleted before the body is made; the new character
    is dressed again when its client says hello.

    Commands (client -> server, module LWS.NET):
      Hello                      state + dress the character
      Wear { slot, uid }         TakeOff { slot }        Show { slot, on }
      Admin: AdminList, AdminView { owner }, AdminGrant { owner, piece },
             AdminRevoke { owner, uid }
    Replies: State, Dress { types }, Msg { key }, AdminData.
]]--

require "HARMONIELifeWithStyle/LWS_Core"

LWS.Server = LWS.Server or {}
local S = LWS.Server
local log = function(...) LWS.log("Server", ...) end

-- ------------------------------------------------------------- data
function S.db()
    local d = ModData.getOrCreate("HARMONIE_LWS")
    d.owners = d.owners or {}
    d.version = d.version or LWS.VERSION
    return d
end

function S.owner(key, create)
    if not key then return nil end
    local db = S.db()
    local o = db.owners[key]
    if not o and create then
        o = { nextId = 1, items = {}, worn = {}, show = {} }
        db.owners[key] = o
        log("new wardrobe for %s", tostring(key))
    end
    if o then
        o.items = o.items or {}; o.worn = o.worn or {}; o.show = o.show or {}; o.nextId = o.nextId or 1
    end
    return o
end

local function hour()
    local gt = getGameTime and getGameTime()
    return gt and math.floor(gt:getWorldAgeHours()) or 0
end

-- the worn slots must point at pieces the owner still has, for that slot
local function clean(o)
    for slot, uid in pairs(o.worn) do
        local e = o.items[uid]
        if not e or not LWS.PIECE[e.p] or LWS.PIECE[e.p].slot ~= slot then o.worn[slot] = nil end
    end
end

-- what the client shows
function S.stateOf(o)
    local items = {}
    for uid, e in pairs(o and o.items or {}) do
        if LWS.PIECE[e.p] then items[#items + 1] = { uid = uid, p = e.p, at = e.at } end
    end
    table.sort(items, function(a, b) return (tonumber(a.uid) or 0) < (tonumber(b.uid) or 0) end)
    local worn, show = {}, {}
    for k, v in pairs(o and o.worn or {}) do worn[k] = v end
    for k, v in pairs(o and o.show or {}) do show[k] = v and true or nil end
    return { items = items, worn = worn, show = show }
end

function S.sendState(player, o)
    LWS.toClient(player, "State", S.stateOf(o))
end

-- ------------------------------------------------------------- the worn items
local function removeItem(player, inv, item)
    pcall(function() player:removeWornItem(item) end)
    pcall(function() inv:Remove(item) end)
    if isServer and isServer() and sendRemoveItemFromContainer then pcall(sendRemoveItemFromContainer, inv, item) end
end

-- make the inventory match the wardrobe: one item per worn slot, nothing else of ours
function S.ensure(player, why)
    if not player or (player.isDead and player:isDead()) then return end
    local key = LWS.ownerKey(player)
    local o = S.owner(key, false)
    local want = {}
    if o then
        clean(o)
        for slot, uid in pairs(o.worn) do
            local e = o.items[uid]
            if e then want[LWS.carrierType(e.p, o.show[slot] == true)] = slot end
        end
    end
    local inv = player:getInventory()
    if not inv then return end
    local have, removed = {}, 0
    local items = inv:getItems()
    local list = {}
    for i = 0, items:size() - 1 do list[#list + 1] = items:get(i) end
    for _, item in ipairs(list) do
        if LWS.isFashion(item) then
            local t = LWS.typeOf(item)
            local mine = item:getModData().LWS_owner
            if want[t] and not have[t] and (mine == nil or mine == key) then
                have[t] = item
            else
                removeItem(player, inv, item)
                removed = removed + 1
                log("%s: removed %s (%s)", LWS.name(player), t, mine ~= key and "not theirs" or "not worn in the wardrobe")
            end
        end
    end
    local wearList, added = {}, 0
    for t, _ in pairs(want) do
        local item = have[t]
        if not item then
            item = inv:AddItem(t)
            if item then
                item:getModData().LWS_owner = key
                if isServer and isServer() and sendAddItemToContainer then pcall(sendAddItemToContainer, inv, item) end
                added = added + 1
            else
                log("%s: could not make %s (no such item?)", LWS.name(player), t)
            end
        end
        if item then wearList[#wearList + 1] = t end
    end
    if added > 0 or removed > 0 or why ~= "sweep" then
        log("%s: dressed (%s): %d worn, %d made, %d removed", LWS.name(player), tostring(why), #wearList, added, removed)
    end
    -- the sweep only speaks when it changed something (no packet every 10 s)
    if (#wearList > 0 or removed > 0) and (why ~= "sweep" or added > 0 or removed > 0) then
        if (isServer and isServer()) then
            LWS.toClient(player, "Dress", { types = wearList })
        else
            S.wearHere(player, wearList)
        end
    end
end

-- single player: wear them now (multiplayer: the client does it, LWS_Client)
function S.wearHere(player, types)
    local inv = player:getInventory()
    for _, t in ipairs(types or {}) do
        local item = inv:FindAndReturn(t)
        if item and not player:isEquippedClothing(item) then
            pcall(function() player:setWornItem(item:getBodyLocation(), item) end)
        end
    end
    pcall(function() player:resetModelNextFrame() end)
end

-- ------------------------------------------------------------- commands
local function admin(player, command)
    if LWS.isAdmin(player) then return true end
    log("REJECTED %s from %s: not an admin", tostring(command), LWS.name(player))
    LWS.toClient(player, "Msg", { key = "IGUI_LWS_Msg_NotAdmin" })
    return false
end

local function adminData(viewKey)
    local db = S.db()
    local owners, seen = {}, {}
    local online = getOnlinePlayers and getOnlinePlayers()
    for i = 0, (online and online:size() or 0) - 1 do
        local p = online:get(i)
        local k = LWS.ownerKey(p)
        if k and not seen[k] then
            seen[k] = true
            local o = db.owners[k]
            owners[#owners + 1] = { key = k, name = LWS.name(p), online = true, count = o and S.count(o) or 0 }
        end
    end
    if not (isServer and isServer()) then
        local p = getPlayer and getPlayer()
        local k = p and LWS.ownerKey(p)
        if k and not seen[k] then
            seen[k] = true
            local o = db.owners[k]
            owners[#owners + 1] = { key = k, name = LWS.name(p), online = true, count = o and S.count(o) or 0 }
        end
    end
    for k, o in pairs(db.owners) do
        if not seen[k] then owners[#owners + 1] = { key = k, name = o.name or k, online = false, count = S.count(o) } end
    end
    table.sort(owners, function(a, b)
        if a.online ~= b.online then return a.online end
        return tostring(a.name) < tostring(b.name)
    end)
    local view = viewKey and S.owner(viewKey, false)
    return { owners = owners, view = viewKey, state = view and S.stateOf(view) or nil }
end

function S.count(o)
    local n = 0
    for _, e in pairs(o.items or {}) do if LWS.PIECE[e.p] then n = n + 1 end end
    return n
end

local function onlineByKey(key)
    local online = getOnlinePlayers and getOnlinePlayers()
    for i = 0, (online and online:size() or 0) - 1 do
        local p = online:get(i)
        if LWS.ownerKey(p) == key then return p end
    end
    if not (isServer and isServer()) then
        local p = getPlayer and getPlayer()
        if p and LWS.ownerKey(p) == key then return p end
    end
    return nil
end

function S.handle(player, command, args)
    if not player then return end
    args = type(args) == "table" and args or {}
    local key = LWS.ownerKey(player)
    if not key then log("REJECTED %s: no owner key for %s", tostring(command), LWS.name(player)); return end

    if command == "Hello" then
        local o = S.owner(key, true)
        o.name = LWS.name(player)
        S.sendState(player, o)
        S.ensure(player, "hello")
    elseif command == "Wear" then
        local o = S.owner(key, true)
        local slot, uid = tostring(args.slot or ""), tostring(args.uid or "")
        local e = o.items[uid]
        if not LWS.SLOT[slot] or not e or not LWS.PIECE[e.p] or LWS.PIECE[e.p].slot ~= slot then
            log("REJECTED Wear from %s: slot %s, piece %s", LWS.name(player), slot, uid)
            S.sendState(player, o)
            return
        end
        o.worn[slot] = uid
        log("%s wears %s in %s", LWS.name(player), tostring(e.p), slot)
        S.sendState(player, o)
        S.ensure(player, "wear")
    elseif command == "TakeOff" then
        local o = S.owner(key, true)
        local slot = tostring(args.slot or "")
        if o.worn[slot] then log("%s takes off %s", LWS.name(player), slot) end
        o.worn[slot] = nil
        S.sendState(player, o)
        S.ensure(player, "take off")
    elseif command == "Show" then
        local o = S.owner(key, true)
        local slot = tostring(args.slot or "")
        if not LWS.SLOT[slot] then return end
        o.show[slot] = args.on == true or nil
        log("%s: %s -> %s real clothes", LWS.name(player), slot, o.show[slot] and "show" or "hide")
        S.sendState(player, o)
        S.ensure(player, "show")
    elseif command == "AdminList" then
        if not admin(player, command) then return end
        LWS.toClient(player, "AdminData", adminData(args.owner and tostring(args.owner) or nil))
    elseif command == "AdminGrant" then
        if not admin(player, command) then return end
        local ownerKey, piece = tostring(args.owner or ""), tostring(args.piece or "")
        if ownerKey == "" or not LWS.PIECE[piece] then log("REJECTED AdminGrant: owner %s, piece %s", ownerKey, piece); return end
        local o = S.owner(ownerKey, true)
        local uid = tostring(o.nextId)
        o.nextId = o.nextId + 1
        o.items[uid] = { p = piece, at = hour(), by = LWS.name(player) }
        log("%s GAVE %s to %s (piece #%s)", LWS.name(player), piece, ownerKey, uid)
        local target = onlineByKey(ownerKey)
        if target then
            S.sendState(target, o)
            LWS.toClient(target, "Msg", { key = "IGUI_LWS_Msg_Got", arg = piece })
        end
        LWS.toClient(player, "AdminData", adminData(ownerKey))
    elseif command == "AdminRevoke" then
        if not admin(player, command) then return end
        local ownerKey, uid = tostring(args.owner or ""), tostring(args.uid or "")
        local o = S.owner(ownerKey, false)
        if not o or not o.items[uid] then log("REJECTED AdminRevoke: owner %s, piece #%s", ownerKey, uid); return end
        log("%s TOOK %s (piece #%s) from %s", LWS.name(player), tostring(o.items[uid].p), uid, ownerKey)
        o.items[uid] = nil
        clean(o)
        local target = onlineByKey(ownerKey)
        if target then S.sendState(target, o); S.ensure(target, "revoked") end
        LWS.toClient(player, "AdminData", adminData(ownerKey))
    else
        log("REJECTED unknown command %s from %s", tostring(command), LWS.name(player))
    end
end

-- ------------------------------------------------------------- events
local function onClientCommand(module, command, player, args)
    if module ~= LWS.NET then return end
    local ok, err = pcall(S.handle, player, command, args)
    if not ok then log("command %s from %s FAILED: %s", tostring(command), LWS.name(player), tostring(err)) end
end

-- on death: no piece goes into the body (the wardrobe keeps them all)
local function onDeath(player)
    if not player or (isClient and isClient()) then return end
    local ok, err = pcall(function()
        local inv = player:getInventory()
        local items = inv:getItems()
        local list, n = {}, 0
        for i = 0, items:size() - 1 do list[#list + 1] = items:get(i) end
        for _, item in ipairs(list) do
            if LWS.isFashion(item) then removeItem(player, inv, item); n = n + 1 end
        end
        if n > 0 then log("%s died: %d worn fashion items removed (the wardrobe keeps them)", LWS.name(player), n) end
    end)
    if not ok then log("death clean-up FAILED: %s", tostring(err)) end
end

-- every 10 s: the sweep (a piece taken off a corpse, a stale twin)
S.SWEEP_MS = 10000
local nextSweep = 0
local function onTick()
    local now = getTimestampMs and getTimestampMs() or 0
    if now < nextSweep then return end
    nextSweep = now + S.SWEEP_MS
    if isServer and isServer() then
        local online = getOnlinePlayers and getOnlinePlayers()
        for i = 0, (online and online:size() or 0) - 1 do
            local ok, err = pcall(S.ensure, online:get(i), "sweep")
            if not ok then LWS.logOnce("sweeperr", "Server", "sweep FAILED: %s", tostring(err)) end
        end
    elseif not (isClient and isClient()) then
        local p = getPlayer and getPlayer()
        if p then
            local ok, err = pcall(S.ensure, p, "sweep")
            if not ok then LWS.logOnce("sweeperr", "Server", "sweep FAILED: %s", tostring(err)) end
        end
    end
end

if Events and not S.registered then
    S.registered = true
    if Events.OnClientCommand then Events.OnClientCommand.Add(onClientCommand) end
    if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(onDeath) end
    if Events.OnTick then Events.OnTick.Add(onTick) end
    if Events.OnInitGlobalModData then
        Events.OnInitGlobalModData.Add(function()
            local db = S.db()
            local n = 0
            for _ in pairs(db.owners) do n = n + 1 end
            log("wardrobes loaded: %d owners, %d pieces in the catalog", n, #LWS.CATALOG)
        end)
    end
end

return S

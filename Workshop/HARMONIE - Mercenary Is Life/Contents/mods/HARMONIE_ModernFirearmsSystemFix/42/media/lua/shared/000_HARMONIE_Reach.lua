--[[
    HARMONIE Hub: items are found on the body, in bags and in the boxes and
    cupboards around you -- the whole room (the same file in every HARMONIE
    mod; master copy mods/_HarmonieHub, install.sh).

    Owner, 2026-11-12 (How to Survive 0.33.12, then every mod for 1.0.0):
    "หาของได้จากตัวเอง กระเป๋า และกล่องหรือตู้รอบตัวกรณีที่ใช้".

    Where an item may come from:
      1. the player's inventory, bags inside it (any depth);
      2. every container (shelf, fridge, crate, cupboard, a bag on the
         floor...) on squares of the SAME ROOM as the player, same floor,
         up to ROOM_RANGE tiles away;
      3. outdoors (no room), or right next to the player indoors (a cabinet
         through a doorway): up to NEAR_RANGE tiles.
    Bags inside those boxes are searched too (BOX_DEPTH deep).

    MP: a box is a WORLD container -- only the server changes it. The server
    looks the item up with the same rule (+SERVER_SLACK tiles) and removes /
    drains / replicates it; an MP client never changes a box item itself
    (clientMustNotTouch) and is told when the server could not find it
    (serverMissing -> "Missing"). A client that needs an item in its hands
    first moves it with the vanilla transfer (bring).

    API (all take the player first):
      containers(p) -> { {c=ItemContainer, where="inv"|"box"|"floor"} }
      each(p, fn(item, container, where)) / findFirst(p, pred) /
      findFirstNearby(p, pred) / findById(p, id) / findType(p, types) /
      countType(p, types) / remove(item, container) / bring(p, item) /
      isCarried(p, item) / clientMustNotTouch(p, item) /
      notePending(id, what) / serverMissing(p, id, what) / forget(p)
    Not called from update/tick; the client keeps one answer for CACHE_MS.
    Logs as [HARMONIE_Hub][Reach].
]]--

if HARMONIE_Reach and HARMONIE_Reach.loaded then return end

HARMONIE_Reach = HARMONIE_Reach or {}
local R = HARMONIE_Reach
R.loaded = true
R.ROOM_RANGE = 12      -- tiles: containers in the player's room
R.NEAR_RANGE = 3       -- tiles: outdoors, or right next to the player
R.ADJACENT = 1         -- indoors: any container this close counts, room or not
R.BOX_DEPTH = 3        -- bags inside a box
R.CACHE_MS = 500
R.SERVER_SLACK = 2     -- the server looks 2 tiles further: its idea of where
                       -- the player stands can lag the client's by a step
R.MODULE = "HARMONIE_Reach"

local function log(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print("[HARMONIE_Hub][Reach] " .. (ok and s or tostring(fmt)))
end
local function nameOf(p)
    local ok, n = pcall(function() return p and p:getUsername() end)
    return (ok and n) and tostring(n) or "?"
end

local function call(o, m, ...)
    if not o then return nil end
    local f = o[m]
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, o, ...)
    if ok then return v end
    return nil
end

local function isServerSide() return isServer and isServer() end
local function nowMs()
    if getTimestampMs then
        local ok, v = pcall(getTimestampMs)
        if ok and tonumber(v) then return tonumber(v) end
    end
    return 0
end

-- a square's room as something comparable (nil = outdoors)
local function roomOf(sq)
    if not sq then return nil end
    local id = call(sq, "getRoomID")
    if id ~= nil and tonumber(id) and tonumber(id) ~= -1 then return "id:" .. tostring(id) end
    local room = call(sq, "getRoom")
    if room then
        local def = call(room, "getRoomDef")
        if def then
            local rid = call(def, "getID")
            if rid ~= nil then return "def:" .. tostring(rid) end
        end
        return room
    end
    return nil
end

local function addObjectContainers(sq, out, seen)
    local objs = call(sq, "getObjects")
    if not objs then return end
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        local n = o and call(o, "getContainerCount") or 0
        if n == 0 and o then
            local c = call(o, "getContainer")
            if c and not seen[c] then seen[c] = true; out[#out + 1] = { c = c, where = "box" } end
        end
        for k = 0, (n or 0) - 1 do
            local c = call(o, "getContainerByIndex", k)
            if c and not seen[c] then seen[c] = true; out[#out + 1] = { c = c, where = "box" } end
        end
    end
    -- a bag / box lying on the floor
    local w = call(sq, "getWorldObjects")
    if w then
        for i = 0, w:size() - 1 do
            local it = call(w:get(i), "getItem")
            if it and instanceof and instanceof(it, "InventoryContainer") then
                local c = call(it, "getInventory")
                if c and not seen[c] then seen[c] = true; out[#out + 1] = { c = c, where = "floor" } end
            end
        end
    end
end

local function collect(player)
    local out, seen = {}, {}
    local inv = call(player, "getInventory")
    if inv then seen[inv] = true; out[#out + 1] = { c = inv, where = "inv" } end
    local sq = call(player, "getCurrentSquare") or call(player, "getSquare")
    local cell = getCell and getCell()
    if not (sq and cell) then return out end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local room = roomOf(sq)
    local range = room and R.ROOM_RANGE or R.NEAR_RANGE
    local adjacent = R.ADJACENT
    if isServerSide() then range = range + R.SERVER_SLACK; adjacent = adjacent + R.SERVER_SLACK end
    for dx = -range, range do
        for dy = -range, range do
            local s = cell:getGridSquare(x + dx, y + dy, z)
            if s then
                local d = math.max(math.abs(dx), math.abs(dy))
                local ok
                if room then
                    ok = d <= adjacent or roomOf(s) == room
                else
                    ok = true
                end
                if ok then addObjectContainers(s, out, seen) end
            end
        end
    end
    return out
end

local cache = setmetatable({}, { __mode = "k" })
-- list of { c = ItemContainer, where = "inv" | "box" | "floor" }; inventory first
function R.containers(player)
    if not player then return {} end
    local client = not isServerSide()
    local t = nowMs()
    local c = client and cache[player]
    if c and t - c.at < R.CACHE_MS then return c.list end
    local list = collect(player)
    if client then cache[player] = { at = t, list = list } end
    return list
end
function R.forget(player) if player then cache[player] = nil else cache = setmetatable({}, { __mode = "k" }) end end

-- every item: fn(item, container, where); bags inside (inventory: any depth,
-- boxes: BOX_DEPTH); stops and returns what fn returned when it is truthy
function R.each(player, fn)
    local visited = {}
    local function walk(cont, where, depth, maxDepth)
        if not cont or visited[cont] then return nil end
        visited[cont] = true
        local items = call(cont, "getItems")
        if not items then return nil end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then
                local r = fn(it, cont, where)
                if r then return r end
                if depth < maxDepth and instanceof and instanceof(it, "InventoryContainer") then
                    local r2 = walk(call(it, "getInventory"), where, depth + 1, maxDepth)
                    if r2 then return r2 end
                end
            end
        end
        return nil
    end
    for _, e in ipairs(R.containers(player)) do
        local r = walk(e.c, e.where, 0, e.where == "inv" and 8 or R.BOX_DEPTH)
        if r then return r end
    end
    return nil
end

-- first item pred(item) accepts -> item, container, where
function R.findFirst(player, pred)
    local found = R.each(player, function(it, cont, where)
        local ok, yes = pcall(pred, it)
        if ok and yes then return { it, cont, where } end
    end)
    if found then return found[1], found[2], found[3] end
    return nil
end

-- outside the inventory only (the inventory was already searched by the caller)
function R.findFirstNearby(player, pred)
    local found = R.each(player, function(it, cont, where)
        if where == "inv" then return nil end
        local ok, yes = pcall(pred, it)
        if ok and yes then return { it, cont, where } end
    end)
    if found then return found[1], found[2], found[3] end
    return nil
end

function R.findById(player, id)
    if id == nil then return nil end
    local want = tostring(id)
    return R.findFirst(player, function(it)
        local iid = call(it, "getID")
        return iid ~= nil and tostring(iid) == want
    end)
end

-- fullTypes: a string or a list of strings
function R.findType(player, fullTypes)
    local set = {}
    if type(fullTypes) == "table" then for _, ft in ipairs(fullTypes) do set[ft] = true end
    elseif fullTypes then set[fullTypes] = true end
    return R.findFirst(player, function(it) return set[call(it, "getFullType") or ""] == true end)
end

-- how many items of these types are within reach
function R.countType(player, fullTypes)
    local set = {}
    if type(fullTypes) == "table" then for _, ft in ipairs(fullTypes) do set[ft] = true end
    elseif fullTypes then set[fullTypes] = true end
    local n = 0
    R.each(player, function(it) if set[call(it, "getFullType") or ""] then n = n + 1 end end)
    return n
end

-- remove an item from wherever it is, replicated from the server
function R.remove(item, container)
    if not item then return false end
    local cont = call(item, "getContainer") or container
    if not cont then return false end
    local ok = pcall(function() cont:Remove(item) end)
    if ok and isServerSide() and sendRemoveItemFromContainer then
        pcall(sendRemoveItemFromContainer, cont, item)
    end
    return ok
end

-- ------------------------------------------------------------ MP sync guards
-- Owner, 2026-11-12: "ระวังปัญหา server ไม่ซิงก์ หาวิธีรับมือไว้ด้วย".
-- A box is a WORLD container: in MP only the server may change it. What can
-- go wrong and what is done about it:
--   * the client's view is stale (another player took the item, the box was
--     emptied): the server looks the item up itself (findById) and refuses
--     what it cannot find -> R.serverMissing tells that client, which drops
--     its cached view and says so; nothing is consumed on either side;
--   * the client changes the item locally and the server does not follow
--     (ghost item / dupe): an item that is NOT carried is never changed on
--     an MP client (EHR ConsumeOneDose sends the request only, see
--     R.isCarried); the server changes it and replicates it to everyone
--     (sendRemoveItemFromContainer / sendItemStats);
--   * the server's idea of where the player stands lags a step: the server
--     searches SERVER_SLACK tiles further;
--   * a box whose loot was never rolled has nothing on the client: such
--     items are simply not offered.

-- is the item on the player's body / in a carried bag (not a world box)?
function R.isCarried(player, item)
    local inv = call(player, "getInventory")
    local cont = call(item, "getContainer")
    local guard = 0
    while cont and guard < 10 do
        if cont == inv then return true end
        local holder = call(cont, "getContainingItem")
        cont = holder and call(holder, "getContainer") or nil
        guard = guard + 1
    end
    return false
end

-- an MP client must leave world-box items to the server
function R.clientMustNotTouch(player, item)
    local pureClient = isClient and isClient() and not isServerSide()
    return pureClient and item ~= nil and not R.isCarried(player, item)
end

-- client: box items this client asked the server to change (id -> time)
local pending = {}
function R.notePending(itemID, what)
    if itemID == nil then return end
    pending[tostring(itemID)] = nowMs()
    log("asked the server to %s box item %s (an MP client never changes a world box itself)", tostring(what or "use"), tostring(itemID))
end

local missed = {}
-- server: a client asked for an item the server cannot find within reach
function R.serverMissing(player, itemID, what)
    local key = nameOf(player) .. ":" .. tostring(itemID)
    if not missed[key] then
        missed[key] = true
        log("%s: item %s for %s is not on them or in a box within reach on the SERVER -- refused, client told to refresh (client view was stale)",
            nameOf(player), tostring(itemID), tostring(what or "?"))
    end
    if sendServerCommand and player then
        pcall(sendServerCommand, player, R.MODULE, "Missing", { itemID = itemID, what = what })
    end
end

if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= R.MODULE then return end
        if command == "Missing" then
            R.forget()
            local id = tostring(args and args.itemID)
            local asked = pending[id]
            pending[id] = nil
            if not asked then
                log("server could not find item %s (%s) -- not a box request of ours, nothing said", id, tostring(args and args.what))
                return
            end
            local me = getPlayer and getPlayer()
            local text = getText and getText("IGUI_HUB_Reach_Missing") or "IGUI_HUB_Reach_Missing"
            if text == "IGUI_HUB_Reach_Missing" then text = "That item is not there any more (someone may have taken it). Try again." end
            if me and EHR and EHR.Locale and EHR.Locale.SayAction then pcall(EHR.Locale.SayAction, me, text)
            elseif me and me.Say then pcall(function() me:Say(text) end) end
            log("server could not find item %s (%s) -- local view refreshed", tostring(args and args.itemID), tostring(args and args.what))
        end
    end)
end

-- client: walk next to a world container that is not within arm's reach
-- (a cupboard across the room) -- vanilla's own walk action; true when queued
function R.walkTo(player, container)
    if not (player and container) or R.isCarried(player, { getContainer = function() return container end }) then return false end
    local parent = call(container, "getParent")
    local sq = parent and call(parent, "getSquare")
    if not sq then
        local holder = call(container, "getContainingItem")
        local w = holder and call(holder, "getWorldItem")
        sq = w and call(w, "getSquare")
    end
    local psq = call(player, "getCurrentSquare")
    if not (sq and psq) then return false end
    local dx, dy = math.abs(sq:getX() - psq:getX()), math.abs(sq:getY() - psq:getY())
    if dx <= 1 and dy <= 1 and sq:getZ() == psq:getZ() then return false end
    if luautils and luautils.walkToContainer then
        local ok, r = pcall(luautils.walkToContainer, container, call(player, "getPlayerNum") or 0)
        if ok and r ~= false then log("%s: walking to a container %d tile(s) away first", nameOf(player), math.max(dx, dy)); return true end
    end
    return false
end

-- client: queue the vanilla transfer of an item into the main inventory
-- (from a bag, a box or the floor) before an action that needs it there;
-- walks to a box across the room first
function R.bring(player, item)
    if not (player and item) then return false end
    local inv = call(player, "getInventory")
    local cont = call(item, "getContainer")
    if not inv or cont == inv then return false end
    if cont and not R.isCarried(player, item) then R.walkTo(player, cont) end
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then
        pcall(ISInventoryPaneContextMenu.transferIfNeeded, player, item)
        return true
    end
    return false
end

-- one line when an item came from a box, not the inventory (rare: on use)
function R.noteBox(player, item, where, what)
    if where and where ~= "inv" then
        log("%s: %s taken from a nearby %s (%s)", nameOf(player), tostring(call(item, "getFullType")), tostring(where), tostring(what or "use"))
    end
end

return R

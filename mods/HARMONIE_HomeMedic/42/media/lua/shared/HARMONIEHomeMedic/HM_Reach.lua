--[[
    HARMONIE - How to Survive : medical items are found on the body, in bags
    and in the boxes around you -- the whole room

    Owner, 2026-11-12: "เวลาเช็คของอะไรพวกนี้ ไม่ใช่แค่การจ่ายยา ลองดูให้ครอบคลุม
    ต้องดูทั้งในตัว ในกระเป๋า และในกล่องรอบๆ ขอระยะไกลๆให้ครอบคลุมทั้งห้อง".
    Before this every check (IV kit, syringe, empty blood bag, the medicine
    list a doctor gives from, the server's look-up by item id...) read the
    player's own inventory only; surgery read boxes 1 tile away.

    One place answers "where may a medical item come from":
      1. the player's inventory, bags inside it (any depth);
      2. every container (shelf, fridge, crate, medical cabinet, a bag on
         the floor...) on squares of the SAME ROOM as the player, same
         floor, up to ROOM_RANGE tiles away;
      3. outdoors (no room), or the squares right next to the player
         indoors (a cabinet through a doorway): up to NEAR_RANGE tiles.
    Bags inside those boxes are searched too (3 deep).

    The server answers with the same rule, so an item a client found in a
    box is found again (and removed / drained) by the server, which is the
    one that owns world containers in MP. Not called from update/tick: only
    when a panel opens, a list is built or an action checks its supplies;
    the client keeps one answer for CACHE_MS.
]]--

HM_Reach = HM_Reach or {}
local R = HM_Reach
R.ROOM_RANGE = 12      -- tiles: containers in the player's room
R.NEAR_RANGE = 3       -- tiles: outdoors, or right next to the player
R.ADJACENT = 1         -- indoors: any container this close counts, room or not
R.BOX_DEPTH = 3        -- bags inside a box
R.CACHE_MS = 500

local function log(fmt, ...) if HMLog then HMLog("Reach", fmt, ...) end end
local function nameOf(p) return HMLogName and HMLogName(p) or "?" end

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
    for dx = -range, range do
        for dy = -range, range do
            local s = cell:getGridSquare(x + dx, y + dy, z)
            if s then
                local d = math.max(math.abs(dx), math.abs(dy))
                local ok
                if room then
                    ok = d <= R.ADJACENT or roomOf(s) == room
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

-- client: queue the vanilla transfer of an item into the main inventory
-- (from a bag, a box or the floor) before an action that needs it there
function R.bring(player, item)
    if not (player and item) then return false end
    local inv = call(player, "getInventory")
    if not inv or call(item, "getContainer") == inv then return false end
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

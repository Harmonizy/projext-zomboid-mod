--============================================================================
-- HARMONIE_TheWayToAttack -- where crafting looks for items (shared)
--
-- Round 13 (request 2026-09-28: "การตรวจเช็คไอเท็มต่างๆสามารถให้เห็นในกล่อง
-- รอบๆหรือพื้นได้ไหม"): tools, materials and base items count not only
-- what the character carries (bags included) but also what lies in any
-- container, and on the floor, within the sandbox "NearbyRadius" tiles
-- (default 1, the same reach as vanilla crafting). R67 ("อะไรที่หาไอเท็มใน
-- ตัว ให้สามารถหาได้บนพื้นและในกล่องรอบตัวเสมอ"): never less than 1 tile.
--
-- TWASources.get(player) returns one object that answers the handful of
-- ItemContainer questions the crafting code asks (first item of a type,
-- count, has-tag, find by id) across all of those places at once, and
-- TWASources.remove(item) takes an item out of wherever it is -- a bag, a
-- crate, or the floor -- telling clients about it on a server.
--============================================================================

require "HARMONIE_TWA_Config"

TWASources = TWASources or {}
local Multi = {}
Multi.__index = Multi

local function any() return true end

local function nearby(player, r, conts, floor)
    local sq = player.getCurrentSquare and player:getCurrentSquare()
    if not sq or r <= 0 or not getCell then return end
    local cell = getCell()
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    for dx = -r, r do
        for dy = -r, r do
            local s = cell:getGridSquare(x + dx, y + dy, z)
            if s then
                local objs = s:getObjects()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    if o and o.getContainerCount and o.getContainerByIndex then
                        for k = 0, o:getContainerCount() - 1 do
                            local c = o:getContainerByIndex(k)
                            if c then conts[#conts + 1] = c end
                        end
                    elseif o and o.getContainer and o:getContainer() then
                        conts[#conts + 1] = o:getContainer()
                    end
                end
                local wobjs = s.getWorldObjects and s:getWorldObjects()
                if wobjs then
                    for i = 0, wobjs:size() - 1 do
                        local w = wobjs:get(i)
                        local it = w and w.getItem and w:getItem()
                        if it then floor[#floor + 1] = it end
                    end
                end
            end
        end
    end
end

local cache = {}
-- 1.0.8 (owner 2026-11-17: "opening the craft window makes every other UI
-- lag, for a long time"): every count / first-item question walked every
-- item of every box in the room in Lua -- per recipe row, per base card,
-- per frame, and for EVERY recipe when the list refreshed. A client now
-- keeps the scan CACHE_MS and walks the items ONCE per scan into an index
-- by full type (`Multi:index`); the questions read the index. The server
-- (no cache) keeps the plain container calls.
TWASources.CACHE_MS = 1000

function TWASources.get(player)
    -- The UI asks many times a frame: a client reuses the scan briefly.
    local client = not (isServer and isServer())
    local now = getTimestampMs and getTimestampMs() or 0
    local c = client and cache[player]
    if c and now - c.at < TWASources.CACHE_MS then return c.src end
    local conts, floor = { player:getInventory() }, {}
    nearby(player, math.max(1, math.floor(TWAConfig.num("NearbyRadius", 1))), conts, floor)
    -- 1.0.0 (owner, 2026-11-12: "หาของได้จากตัวเอง กระเป๋า และกล่องหรือตู้รอบตัว"):
    -- every box / cupboard / floor bag in the same room too (HARMONIE_Reach,
    -- the hub's shared rule: room <= 12 tiles, outdoors <= 3); loose floor
    -- items stay within NearbyRadius
    if HARMONIE_Reach and HARMONIE_Reach.containers then
        local seen = {}
        for _, c in ipairs(conts) do seen[c] = true end
        for _, e in ipairs(HARMONIE_Reach.containers(player)) do
            if not seen[e.c] then seen[e.c] = true; conts[#conts + 1] = e.c end
        end
    end
    local src = setmetatable({ conts = conts, floor = floor, inv = player:getInventory(), indexable = client }, Multi)
    if client then cache[player] = { at = now, src = src } end
    return src
end

function TWASources.forget(player) cache[player] = nil end

-- every item at hand, walked once: byType[fullType] = { items in reach
-- order (the character's inventory first) }, all = every item. Client only.
local function stillThere(it)
    if not it then return false end
    if it.getWorldItem and it:getWorldItem() then return true end
    return it.getContainer and it:getContainer() ~= nil
end
function Multi:index()
    if self.byType then return self.byType end
    local t0 = getTimestampMs and getTimestampMs() or 0
    local byType, all = {}, {}
    local function add(it)
        local ok, ft = pcall(it.getFullType, it)
        if ok and ft then
            local l = byType[ft]
            if not l then l = {}; byType[ft] = l end
            l[#l + 1] = it
            all[#all + 1] = it
        end
    end
    local function walk(container, depth)
        local items = container and container:getItems()
        if not items then return end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then
                add(it)
                if depth < 6 and instanceof(it, "InventoryContainer") then walk(it:getInventory(), depth + 1) end
            end
        end
    end
    for _, c in ipairs(self.conts) do walk(c, 0) end
    for _, it in ipairs(self.floor) do add(it) end
    self.byType, self.all = byType, all
    local ms = (getTimestampMs and getTimestampMs() or 0) - t0
    if ms >= 15 then
        if TWALogOnce then
            TWALogOnce("srcidx_" .. tostring(math.floor(#all / 500)), "Sources",
                "item index: %d items in %d containers took %d ms", #all, #self.conts, ms)
        end
    end
    return byType
end

function Multi:getFirstTypeEvalRecurse(t, pred)
    pred = pred or any
    if self.indexable then
        for _, it in ipairs(self:index()[t] or {}) do
            if stillThere(it) and pred(it) then return it end
        end
        return nil
    end
    for _, c in ipairs(self.conts) do
        local it = c:getFirstTypeEvalRecurse(t, pred)
        if it then return it end
    end
    for _, it in ipairs(self.floor) do
        if it:getFullType() == t and pred(it) then return it end
    end
    return nil
end

function Multi:getItemCountRecurse(t)
    if self.indexable then return #(self:index()[t] or {}) end
    local n = 0
    for _, c in ipairs(self.conts) do n = n + c:getItemCountRecurse(t) end
    for _, it in ipairs(self.floor) do if it:getFullType() == t then n = n + 1 end end
    return n
end

--- How many items of type `t` pass `pred`.
function Multi:countEval(t, pred)
    local n = 0
    if self.indexable then
        for _, it in ipairs(self:index()[t] or {}) do if pred(it) then n = n + 1 end end
        return n
    end
    local function walk(container)
        local items = container and container:getItems()
        if not items then return end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it:getFullType() == t and pred(it) then n = n + 1 end
            if instanceof(it, "InventoryContainer") then walk(it:getInventory()) end
        end
    end
    for _, c in ipairs(self.conts) do walk(c) end
    for _, it in ipairs(self.floor) do if it:getFullType() == t and pred(it) then n = n + 1 end end
    return n
end

function Multi:containsTagEvalRecurse(tag, pred)
    for _, c in ipairs(self.conts) do
        if c:containsTagEvalRecurse(tag, pred or any) then return true end
    end
    for _, it in ipairs(self.floor) do
        if it.hasTag and it:hasTag(tag) and (pred or any)(it) then return true end
    end
    return false
end

--- First item carrying `tag` (not broken), anywhere.
function Multi:findTagged(tag)
    local function walk(container)
        local items = container and container:getItems()
        if not items then return nil end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it and not it:isBroken() and it.hasTag and it:hasTag(tag) then return it end
            if it and instanceof(it, "InventoryContainer") then
                local inner = walk(it:getInventory())
                if inner then return inner end
            end
        end
        return nil
    end
    for _, c in ipairs(self.conts) do
        local it = walk(c)
        if it then return it end
    end
    for _, it in ipairs(self.floor) do
        if not it:isBroken() and it.hasTag and it:hasTag(tag) then return it end
    end
    return nil
end

-- Round 22: every item at hand (bags inside containers too, 3 deep), once.
function Multi:forEachItem(fn)
    if self.indexable then
        self:index()
        for _, it in ipairs(self.all) do fn(it) end
        return
    end
    local function walk(cont, depth)
        local items = cont and cont:getItems()
        if not items then return end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            fn(it)
            if depth < 3 and it.getInventory and (not instanceof or instanceof(it, "InventoryContainer")) then
                walk(it:getInventory(), depth + 1)
            end
        end
    end
    for _, c in ipairs(self.conts) do walk(c, 0) end
    for _, it in ipairs(self.floor) do fn(it) end
end

function Multi:findById(id)
    if not id then return nil end
    for _, c in ipairs(self.conts) do
        for _, m in ipairs({ "getItemWithIDRecursiv", "getItemById", "getItemWithID" }) do
            if c[m] then
                local it = c[m](c, id)
                if it then return it end
                break
            end
        end
    end
    for _, it in ipairs(self.floor) do if it:getID() == id then return it end end
    return nil
end

--- Take `it` out of wherever it is. `inv` is the fallback container.
function TWASources.remove(it, inv)
    if not it then return false end
    local wi = it.getWorldItem and it:getWorldItem()
    if wi then
        local sq = wi.getSquare and wi:getSquare()
        if sq and isServer() and sq.transmitRemoveItemFromSquare then sq:transmitRemoveItemFromSquare(wi) end
        if wi.removeFromWorld then wi:removeFromWorld() end
        if wi.removeFromSquare then wi:removeFromSquare() end
        if wi.setSquare then wi:setSquare(nil) end
        if it.setWorldItem then it:setWorldItem(nil) end
        cache = {}
        return true
    end
    local c = it:getContainer() or inv
    if not c then TWALog("Sources", "could not remove %s: no container", TWALogType(it)); return false end
    c:Remove(it)
    if isServer() and sendRemoveItemFromContainer then sendRemoveItemFromContainer(c, it) end
    cache = {}
    return true
end

--[[
    HARMONIE - LWS: Tomb's Wardrobe -- a real Tomb's Wardrobe CLOTHING item a
    player carries becomes the Life With Style piece made from it, in that
    player's wardrobe (owner 2026-11-20, choice "c"). Server / SP only, every
    10 s for each player: body, worn and bags (any depth). The colour it had
    (its texture choice) is kept. Tomb's bags are left alone: they are real
    containers, crafted in The Way To Attack. A Tomb item with no piece is left
    alone too (logged once per type).
]]--

require "HARMONIELWSTomb/LWST_Data"

LWST = LWST or {}
local log = function(fmt, ...) if LWST.log then LWST.log(fmt, ...) else print("[HARMONIE_LWS][Tomb] " .. tostring(fmt)) end end
local POLL_MS = 10000
local noPiece = {}

local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end

-- every Tomb clothing item this player carries (container, item)
local function collect(inv, out, depth)
    if not inv or depth > 4 then return end
    local items = call(inv, "getItems")
    for i = 0, (items and items:size() or 0) - 1 do
        local it = items:get(i)
        local t = tostring(call(it, "getFullType") or "")
        if LWST.isTomb and LWST.isTomb(t) and not (LWST.BAG and LWST.BAG[t]) then
            out[#out + 1] = { inv = inv, item = it, type = t }
        end
        local sub = call(it, "getInventory")
        if sub then collect(sub, out, depth + 1) end
    end
end

function LWST.convertPlayer(player)
    if not (player and LWS and LWS.Server and LWS.ownerKey) then return 0 end
    if call(player, "isDead") then return 0 end
    local found = {}
    collect(call(player, "getInventory"), found, 0)
    if #found == 0 then return 0 end
    local key = LWS.ownerKey(player)
    if not key then return 0 end
    local o = LWS.Server.owner(key, true)
    local n = 0
    for _, f in ipairs(found) do
        local pid = LWS.PIECE_BY_SRC and LWS.PIECE_BY_SRC[f.type]
        if not pid or not LWS.PIECE[pid] then
            if not noPiece[f.type] then noPiece[f.type] = true; log("%s has %s, which has no fashion piece -- left alone", LWS.name(player), f.type) end
        else
            local tex = 0
            pcall(function()
                local v = f.item:getVisual()
                if v and v.getTextureChoice then tex = math.max(0, tonumber(v:getTextureChoice()) or 0) end
            end)
            if tex >= LWS.texCount(pid) then tex = 0 end
            pcall(function() if player:isEquippedClothing(f.item) then player:removeWornItem(f.item) end end)
            pcall(function() f.inv:Remove(f.item) end)
            if isServer and isServer() and sendRemoveItemFromContainer then pcall(sendRemoveItemFromContainer, f.inv, f.item) end
            local uid = tostring(o.nextId)
            o.nextId = o.nextId + 1
            local gt = getGameTime and getGameTime()
            o.items[uid] = { p = pid, at = gt and math.floor(gt:getWorldAgeHours()) or 0, by = "Tomb's Wardrobe item", tex = tex > 0 and tex or nil }
            n = n + 1
            log("%s: real %s (colour %d) -> wardrobe piece %s #%s", LWS.name(player), f.type, tex + 1, pid, uid)
            LWS.toClient(player, "Msg", { key = "IGUI_LWST_Converted", arg = LWS.pieceName(pid), text = true })
        end
    end
    if n > 0 then
        LWS.Server.sendState(player, o)
        LWS.Server.ensure(player, "tomb convert")
    end
    return n
end

local nextAt = 0
local function onTick()
    local t = getTimestampMs and getTimestampMs() or 0
    if t < nextAt then return end
    nextAt = t + POLL_MS
    if isServer and isServer() then
        local list = getOnlinePlayers and getOnlinePlayers()
        for i = 0, (list and list:size() or 0) - 1 do
            local ok, err = pcall(LWST.convertPlayer, list:get(i))
            if not ok then LWS.logOnce("lwstconv", "Tomb", "converting Tomb items FAILED: %s", tostring(err)) end
        end
    elseif not (isClient and isClient()) then
        for i = 0, (getNumActivePlayers and getNumActivePlayers() or 1) - 1 do
            local ok, err = pcall(LWST.convertPlayer, getSpecificPlayer(i))
            if not ok then LWS.logOnce("lwstconv", "Tomb", "converting Tomb items FAILED: %s", tostring(err)) end
        end
    end
end

if Events and Events.OnTick and not (isClient and isClient()) then
    Events.OnTick.Add(onTick)
    log("real Tomb's Wardrobe clothes carried by a player become wardrobe pieces (every %d s)", POLL_MS / 1000)
end

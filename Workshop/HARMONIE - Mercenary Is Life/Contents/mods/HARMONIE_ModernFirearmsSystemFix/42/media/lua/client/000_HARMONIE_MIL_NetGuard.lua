--[[
    HARMONIE - Mercenary Is Life 1.0.10: a budget for the equip / attach calls
    our client code makes (owner 2026-11-20: a player was thrown out of the
    server while shoving zombies, "a bad packet from the server side").

    Every player:setAttachedItem / removeAttachedItem / setPrimaryHandItem /
    setSecondaryHandItem on an MP client is a packet to the server. The
    console of the kicked player shows ~110 "EquipPacket.set get invalid
    arguments" in 7 s (one every 2 frames). MIL draws gun parts and shields
    with fake items attached to the body (EFK_RenderPart, InitShield) -- items
    that are not in the inventory, so the server has nothing to match them
    with -- and those ran from OnPlayerUpdate:
      * InitShield attached a NEW fake item on EVERY update while a shield was
        held or worn, and also on every update of any other player nearby;
      * EFK_RenderPart removed / re-attached the part items whenever the held
        gun's model was missing for a frame (it flickers during a shove), with
        no limit.
    Now each of those only acts for the local player, only when something
    really changed, debounced, and through this budget: at most BUDGET calls
    a second, all of ours together (single player: no limit). What is held
    back is logged once a minute with counts by tag.
]]--

MILNetGuard = MILNetGuard or {}
local G = MILNetGuard

G.BUDGET = 6
G.win, G.n = 0, 0
G.dropped, G.droppedBy, G.lastReport = 0, {}, 0

local function now() return getTimestampMs and getTimestampMs() or 0 end
local function log(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    print("[HARMONIE_MFSFix][NetGuard] " .. (ok and msg or tostring(fmt)))
end
G.log = log

-- `n` calls of kind `tag` may go out now? (counts them when yes)
function G.allow(tag, n)
    n = n or 1
    if not (isClient and isClient()) then return true end
    local t = now()
    if t - G.win >= 1000 then G.win, G.n = t, 0 end
    -- one batch larger than the budget (a gun with many parts) may go as the
    -- first thing in a second; after it the second is full
    if G.n + n > G.BUDGET and not (G.n == 0 and n > G.BUDGET) then
        G.dropped = G.dropped + n
        G.droppedBy[tag or "?"] = (G.droppedBy[tag or "?"] or 0) + n
        if t - G.lastReport >= 60000 then
            G.lastReport = t
            local parts = {}
            for k, v in pairs(G.droppedBy) do parts[#parts + 1] = k .. " " .. v end
            log("held back %d equip / attach calls in the last minute (budget %d a second): %s", G.dropped, G.BUDGET, table.concat(parts, ", "))
            G.dropped, G.droppedBy = 0, {}
        end
        return false
    end
    G.n = G.n + n
    return true
end

-- is `player` the one this game controls? (OnPlayerUpdate can be another's)
function G.isLocal(player)
    if not player then return false end
    if player.isLocalPlayer then
        local ok, v = pcall(player.isLocalPlayer, player)
        if ok then return v == true end
    end
    return player == (getPlayer and getPlayer())
end

log("loaded: at most %d equip / attach calls a second from our code in MP", G.BUDGET)

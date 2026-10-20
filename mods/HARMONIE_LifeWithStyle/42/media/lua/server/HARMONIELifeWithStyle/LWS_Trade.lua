--[[
    HARMONIE - Life With Style : trading pieces between players (server)

    Owner, 2026-10-20: "ต่อไปจะมีการให้แลกเปลี่ยนของแฟชั่นนี้ระหว่างผู้เล่นได้" / "เฟส 2 เลย".

    A trade is a session on the server between two online players:
      1. A asks B (TradeAsk). B sees the request and answers (TradeAnswer);
         no answer in ASK_SECONDS = no.
      2. Both put pieces from their own wardrobe in (TradeOffer, add / remove).
         Every change unlocks both sides and bumps the session's revision.
      3. Both press "agree" (TradeLock) on the revision they see. When both
         agree on the same revision the server swaps the pieces at once.
    Only the server moves pieces, after checking again that each one is
    still in its giver's wardrobe -- nothing can be copied or lost. A worn
    piece that is given away is taken off. Each moved piece remembers who
    it came from (entry.from). A session ends when either cancels, either
    goes offline, or nobody touches it for IDLE_MINUTES.

    Sandbox (page HARMONIE_LifeWithStyle): LifeWithStyle.TradeEnabled,
    LifeWithStyle.TradeMaxDistance (tiles, 0 = anywhere on the server).

    Commands: TradeAsk { to = username }, TradeAnswer { from, yes },
              TradeOffer { uid, add }, TradeLock { on, rev }, TradeCancel
    Replies:  TradeAsked { from, name }, TradeState { ... }, TradeEnd { reason }, Msg
]]--

require "HARMONIELifeWithStyle/LWS_Core"
require "HARMONIELifeWithStyle/LWS_Server"

LWS.Trade = LWS.Trade or {}
local TR = LWS.Trade
local S = LWS.Server
local log = function(...) LWS.log("Trade", ...) end

TR.ASK_SECONDS = 60
TR.IDLE_MINUTES = 10
TR.MAX_OFFER = 50
TR.sessions = TR.sessions or {}   -- id -> session
TR.byKey = TR.byKey or {}         -- owner key -> session id
TR.asks = TR.asks or {}           -- [toKey][fromKey] = ms
TR.nextId = TR.nextId or 1

local function now() return getTimestampMs and getTimestampMs() or 0 end
local function sv() return SandboxVars and SandboxVars.LifeWithStyle or {} end
function TR.enabled() return sv().TradeEnabled ~= false end
function TR.maxDistance() return math.max(0, tonumber(sv().TradeMaxDistance) or 0) end

local function onlineByName(name)
    local online = getOnlinePlayers and getOnlinePlayers()
    for i = 0, (online and online:size() or 0) - 1 do
        local p = online:get(i)
        if p and LWS.name(p) == tostring(name) then return p end
    end
    return nil
end
local function onlineByKey(key)
    local online = getOnlinePlayers and getOnlinePlayers()
    for i = 0, (online and online:size() or 0) - 1 do
        local p = online:get(i)
        if p and LWS.ownerKey(p) == key then return p end
    end
    return nil
end

local function msg(player, key, arg)
    if player then LWS.toClient(player, "Msg", { key = key, arg = arg, text = true }) end
end

local function close(player, other)
    local d = TR.maxDistance()
    if d <= 0 then return true end
    local ok, dist = pcall(function() return player:DistTo(other) end)
    return ok and dist and dist <= d
end

-- ------------------------------------------------------------- views
local function pieceList(owner, set)
    local out = {}
    for uid in pairs(set or {}) do
        local e = owner and owner.items[uid]
        if e and LWS.PIECE[e.p] then out[#out + 1] = { uid = uid, p = e.p } end
    end
    table.sort(out, function(a, b) return (tonumber(a.uid) or 0) < (tonumber(b.uid) or 0) end)
    return out
end

function TR.viewFor(s, key)
    local other = s.a == key and s.b or s.a
    return {
        id = s.id, rev = s.rev,
        partner = s.names[other] or other,
        mine = pieceList(S.owner(key, false), s.offer[key]),
        theirs = pieceList(S.owner(other, false), s.offer[other]),
        myLock = s.lock[key] == true, theirLock = s.lock[other] == true,
    }
end

function TR.push(s)
    for _, key in ipairs({ s.a, s.b }) do
        local p = onlineByKey(key)
        if p then LWS.toClient(p, "TradeState", TR.viewFor(s, key)) end
    end
end

function TR.finish(s, reason)
    if not s or TR.sessions[s.id] ~= s then return end
    TR.sessions[s.id] = nil
    TR.byKey[s.a], TR.byKey[s.b] = nil, nil
    for _, key in ipairs({ s.a, s.b }) do
        local p = onlineByKey(key)
        if p then LWS.toClient(p, "TradeEnd", { reason = reason }) end
    end
    log("trade #%d %s <-> %s ended: %s", s.id, tostring(s.names[s.a]), tostring(s.names[s.b]), tostring(reason))
end

-- ------------------------------------------------------------- the swap
local function swap(s)
    local oa, ob = S.owner(s.a, true), S.owner(s.b, true)
    -- check again: every offered piece is still in its giver's wardrobe
    for _, side in ipairs({ { s.a, oa }, { s.b, ob } }) do
        for uid in pairs(s.offer[side[1]]) do
            local e = side[2].items[uid]
            if not e or not LWS.PIECE[e.p] then
                log("trade #%d: piece #%s of %s is gone -- not swapped, both unlocked", s.id, tostring(uid), tostring(side[1]))
                s.offer[side[1]][uid] = nil
                s.lock = {}
                s.rev = s.rev + 1
                return false
            end
        end
    end
    local moved = 0
    local function give(fromKey, from, toKey, to)
        for uid in pairs(s.offer[fromKey]) do
            local e = from.items[uid]
            from.items[uid] = nil
            for slot, wuid in pairs(from.worn) do if wuid == uid then from.worn[slot] = nil end end
            local newUid = tostring(to.nextId)
            to.nextId = to.nextId + 1
            to.items[newUid] = { p = e.p, at = e.at, by = e.by, from = s.names[fromKey] or fromKey }
            moved = moved + 1
            log("trade #%d: %s (%s #%s) -> %s #%s", s.id, tostring(e.p), tostring(s.names[fromKey]), tostring(uid), tostring(s.names[toKey]), newUid)
        end
    end
    give(s.a, oa, s.b, ob)
    give(s.b, ob, s.a, oa)
    log("trade #%d DONE: %d pieces moved", s.id, moved)
    for _, key in ipairs({ s.a, s.b }) do
        local p = onlineByKey(key)
        if p then
            S.sendState(p, S.owner(key, false))
            S.ensure(p, "trade")
            msg(p, "IGUI_LWS_Msg_TradeDone")
        end
    end
    TR.finish(s, "done")
    return true
end

-- ------------------------------------------------------------- commands
function TR.handle(player, command, args)
    local key = LWS.ownerKey(player)
    local me = LWS.name(player)
    if not key then return end
    if not (isServer and isServer()) then msg(player, "IGUI_LWS_Msg_TradeMPOnly"); return end
    if not TR.enabled() then msg(player, "IGUI_LWS_Msg_TradeOff"); log("REJECTED %s from %s: trading is off (sandbox)", command, me); return end

    if command == "TradeAsk" then
        local target = onlineByName(args.to)
        local tkey = target and LWS.ownerKey(target)
        if not target or not tkey or tkey == key then log("REJECTED TradeAsk %s -> %s: not online / self", me, tostring(args.to)); msg(player, "IGUI_LWS_Msg_TradeNoOne"); return end
        if TR.byKey[key] or TR.byKey[tkey] then msg(player, "IGUI_LWS_Msg_TradeBusy"); log("REJECTED TradeAsk %s -> %s: already trading", me, LWS.name(target)); return end
        if not close(player, target) then msg(player, "IGUI_LWS_Msg_TradeFar"); log("REJECTED TradeAsk %s -> %s: too far", me, LWS.name(target)); return end
        TR.asks[tkey] = TR.asks[tkey] or {}
        local last = TR.asks[tkey][key]
        if last and now() - last < 5000 then return end
        TR.asks[tkey][key] = now()
        LWS.toClient(target, "TradeAsked", { from = me, seconds = TR.ASK_SECONDS })
        msg(player, "IGUI_LWS_Msg_TradeAskSent", LWS.name(target))
        log("%s asks %s to trade", me, LWS.name(target))
    elseif command == "TradeAnswer" then
        local asker = onlineByName(args.from)
        local akey = asker and LWS.ownerKey(asker)
        local at = akey and TR.asks[key] and TR.asks[key][akey]
        if TR.asks[key] and akey then TR.asks[key][akey] = nil end
        if not asker or not at or now() - at > TR.ASK_SECONDS * 1000 then log("REJECTED TradeAnswer %s <- %s: no open request", me, tostring(args.from)); msg(player, "IGUI_LWS_Msg_TradeExpired"); return end
        if args.yes ~= true then
            msg(asker, "IGUI_LWS_Msg_TradeDeclined", me)
            log("%s declined %s's trade", me, LWS.name(asker))
            return
        end
        if TR.byKey[key] or TR.byKey[akey] then msg(player, "IGUI_LWS_Msg_TradeBusy"); return end
        if not close(player, asker) then msg(player, "IGUI_LWS_Msg_TradeFar"); return end
        local s = { id = TR.nextId, a = akey, b = key, rev = 1, offer = { [akey] = {}, [key] = {} }, lock = {},
                    names = { [akey] = LWS.name(asker), [key] = me }, touched = now() }
        TR.nextId = TR.nextId + 1
        TR.sessions[s.id] = s
        TR.byKey[akey], TR.byKey[key] = s.id, s.id
        log("trade #%d opened: %s <-> %s", s.id, LWS.name(asker), me)
        TR.push(s)
    else
        local s = TR.sessions[TR.byKey[key] or -1]
        if not s then log("REJECTED %s from %s: no open trade", command, me); LWS.toClient(player, "TradeEnd", { reason = "none" }); return end
        s.touched = now()
        if command == "TradeOffer" then
            local o = S.owner(key, true)
            local uid = tostring(args.uid or "")
            if args.add == true then
                local n = 0
                for _ in pairs(s.offer[key]) do n = n + 1 end
                if not o.items[uid] or not LWS.PIECE[o.items[uid].p] then log("REJECTED TradeOffer %s: piece #%s is not theirs", me, uid); return end
                if n >= TR.MAX_OFFER then msg(player, "IGUI_LWS_Msg_TradeFull"); return end
                s.offer[key][uid] = true
            else
                s.offer[key][uid] = nil
            end
            s.lock = {}
            s.rev = s.rev + 1
            TR.push(s)
        elseif command == "TradeLock" then
            if tonumber(args.rev) ~= s.rev then log("trade #%d: %s agreed on an old view (rev %s, now %d) -- ignored", s.id, me, tostring(args.rev), s.rev); TR.push(s); return end
            s.lock[key] = args.on == true or nil
            log("trade #%d: %s %s", s.id, me, s.lock[key] and "agrees" or "takes the agreement back")
            if s.lock[s.a] and s.lock[s.b] then
                if not swap(s) then TR.push(s) end
            else
                TR.push(s)
            end
        elseif command == "TradeCancel" then
            TR.finish(s, "cancelled")
        else
            log("REJECTED unknown trade command %s from %s", tostring(command), me)
        end
    end
end

-- ------------------------------------------------------------- upkeep
local nextAt = 0
function TR.tick()
    local t = now()
    if t < nextAt then return end
    nextAt = t + 1000
    for _, s in pairs(TR.sessions) do
        if not onlineByKey(s.a) or not onlineByKey(s.b) then TR.finish(s, "left")
        elseif t - (s.touched or t) > TR.IDLE_MINUTES * 60000 then TR.finish(s, "idle") end
    end
    for to, list in pairs(TR.asks) do
        for from, at in pairs(list) do if t - at > TR.ASK_SECONDS * 1000 then list[from] = nil end end
        if next(list) == nil then TR.asks[to] = nil end
    end
end

if Events and Events.OnTick and not TR.registered then
    TR.registered = true
    Events.OnTick.Add(function()
        local ok, err = pcall(TR.tick)
        if not ok then LWS.logOnce("tradetick", "Trade", "upkeep FAILED: %s", tostring(err)) end
    end)
end

return TR

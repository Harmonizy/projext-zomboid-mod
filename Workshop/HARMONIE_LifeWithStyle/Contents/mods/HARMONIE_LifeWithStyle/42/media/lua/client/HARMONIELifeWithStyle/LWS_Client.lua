--[[
    HARMONIE - Life With Style : client side

      * says hello to the server when the character is made (spawn, respawn)
        and keeps the wardrobe state it sends (LWS.Client.state);
      * wears the fashion items the server made ("Dress") -- the item may
        arrive a moment after the command, so it retries for a few seconds;
      * fashion items can not be dropped, moved, put in a container, traded
        or taken off the vanilla way (only from the wardrobe window), and
        they are not listed in the inventory window -- they are not things
        you own there, only the picture of what you wear;
      * the HARMONIE debug menu (admins): open the admin page, give a test set.
]]--

require "HARMONIELifeWithStyle/LWS_Core"

LWS.Client = LWS.Client or {}
local C = LWS.Client
local log = function(...) LWS.log("Client", ...) end

C.state = C.state or { items = {}, worn = {}, show = {} }
C.asks = C.asks or {}      -- trade requests to me: [from name] = deadline
C.trade = C.trade or nil   -- the open trade (the server's view for me)
C.admin = C.admin or nil

local function me() return getPlayer and getPlayer() or nil end

-- ------------------------------------------------------------- server -> client
C.pending = C.pending or {}   -- full types to wear, with a deadline
function C.handle(command, args)
    args = type(args) == "table" and args or {}
    if command == "State" then
        C.state = { items = args.items or {}, worn = args.worn or {}, show = args.show or {} }
        C.stateAt = getTimestampMs and getTimestampMs() or 0
        if LWSWindow and LWSWindow.refresh then LWSWindow.refresh() end
    elseif command == "Dress" then
        local now = getTimestampMs and getTimestampMs() or 0
        for _, t in ipairs(args.types or {}) do C.pending[t] = now + 8000 end
        C.dressNow()
    elseif command == "Msg" then
        local text
        if args.text then
            text = LWS.T(tostring(args.key or ""), tostring(args.arg or ""))
        else
            text = LWS.T(tostring(args.key or ""))
            if args.arg then text = text .. ": " .. LWS.pieceName(args.arg) end
        end
        C.say(text)
    elseif command == "AdminData" then
        C.admin = args
        if LWSWindow and LWSWindow.refresh then LWSWindow.refresh() end
    -- trading (LWS_Trade.lua on the server)
    elseif command == "TradeAsked" then
        local now = getTimestampMs and getTimestampMs() or 0
        C.asks[tostring(args.from)] = now + (tonumber(args.seconds) or 60) * 1000
        log("%s asks to trade", tostring(args.from))
        C.say(LWS.T("IGUI_LWS_Msg_TradeAsked", tostring(args.from)))
    elseif command == "TradeState" then
        if not C.trade then log("trade opened with %s", tostring(args.partner)) end
        C.trade = args
        C.asks[tostring(args.partner)] = nil
        if LWSWindow and LWSWindow.open and not (LWSWindow.isOpen and LWSWindow.isOpen()) then LWSWindow.open(me(), "trade") end
        if LWSWindow and LWSWindow.window then LWSWindow.window.tab = "trade" end
    elseif command == "TradeEnd" then
        if C.trade then
            log("trade ended: %s", tostring(args.reason))
            if args.reason ~= "done" and args.reason ~= "none" then C.say(LWS.T("IGUI_LWS_Msg_TradeEnd_" .. tostring(args.reason))) end
        end
        C.trade = nil
    end
end

function C.say(text)
    local p = me()
    if not p then return end
    if HaloTextHelper and HaloTextHelper.addText then
        pcall(HaloTextHelper.addText, p, text)
    else
        pcall(function() p:Say(text) end)
    end
end

-- wear what the server made (it is in the inventory, or will be in a moment)
function C.dressNow()
    local p = me()
    if not p then return end
    local inv = p:getInventory()
    local now = getTimestampMs and getTimestampMs() or 0
    local changed = false
    for t, deadline in pairs(C.pending) do
        local item = inv:FindAndReturn(t)
        if item then
            if not p:isEquippedClothing(item) then
                local ok, err = pcall(function() p:setWornItem(item:getBodyLocation(), item) end)
                if ok then changed = true else log("could not wear %s: %s", t, tostring(err)) end
            end
            C.pending[t] = nil
        elseif now > deadline then
            log("%s never arrived -- not worn (the server sweep will try again)", t)
            C.pending[t] = nil
        end
    end
    if changed then
        pcall(function() p:resetModelNextFrame() end)
        log("dressed: %s", (function() local n = 0; for _ in pairs(C.state.worn or {}) do n = n + 1 end; return n end)() .. " slots worn")
    end
end

local function onServerCommand(module, command, args)
    if module ~= LWS.NET then return end
    local ok, err = pcall(C.handle, command, args)
    if not ok then log("server command %s FAILED: %s", tostring(command), tostring(err)) end
end

-- ------------------------------------------------------------- client -> server
function C.send(command, args)
    local p = me()
    if not p then return end
    LWS.toServer(p, command, args)
end
function C.wear(slot, uid) log("wear %s in %s", tostring(uid), tostring(slot)); C.send("Wear", { slot = slot, uid = uid }) end
function C.takeOff(slot) log("take off %s", tostring(slot)); C.send("TakeOff", { slot = slot }) end
function C.setShow(slot, on) log("%s: show real clothes %s", tostring(slot), tostring(on)); C.send("Show", { slot = slot, on = on == true }) end

-- trading
function C.tradeAsk(name) log("ask %s to trade", tostring(name)); C.send("TradeAsk", { to = name }) end
function C.tradeAnswer(from, yes)
    log("%s the trade of %s", yes and "accept" or "decline", tostring(from))
    C.asks[tostring(from)] = nil
    C.send("TradeAnswer", { from = from, yes = yes == true })
end
function C.tradeOffer(uid, add) C.send("TradeOffer", { uid = uid, add = add == true }) end
function C.tradeLock(on)
    if not C.trade then return end
    log("trade: %s", on and "agree" or "take the agreement back")
    C.send("TradeLock", { on = on == true, rev = C.trade.rev })
end
function C.tradeCancel() log("trade: cancel"); C.send("TradeCancel", {}) end
function C.openAsks()
    local now = getTimestampMs and getTimestampMs() or 0
    local out = {}
    for from, deadline in pairs(C.asks) do
        if deadline > now then out[#out + 1] = { from = from, left = math.ceil((deadline - now) / 1000) } else C.asks[from] = nil end
    end
    table.sort(out, function(a, b) return a.from < b.from end)
    return out
end
-- the other players online (multiplayer)
function C.otherPlayers()
    local out = {}
    local mine = me()
    local online = getOnlinePlayers and getOnlinePlayers()
    for i = 0, (online and online:size() or 0) - 1 do
        local p = online:get(i)
        if p and p ~= mine and LWS.name(p) ~= LWS.name(mine) then out[#out + 1] = LWS.name(p) end
    end
    table.sort(out)
    return out
end

function C.hello(why)
    log("hello (%s)", tostring(why))
    C.send("Hello", {})
end

-- pieces the player has for a slot, and the one worn there
function C.piecesFor(slot)
    local out = {}
    for _, e in ipairs(C.state.items or {}) do
        local c = LWS.PIECE[e.p]
        if c and (slot == nil or c.slot == slot) then out[#out + 1] = e end
    end
    return out
end
function C.wornIn(slot)
    local uid = C.state.worn and C.state.worn[slot]
    if not uid then return nil end
    for _, e in ipairs(C.state.items or {}) do if e.uid == uid then return e end end
    return nil
end

-- ------------------------------------------------------------- guards
local function blocked(item, what)
    if not LWS.isFashion(item) then return false end
    LWS.logOnce("block:" .. what, "Client", "blocked %s of a fashion item (they only come off in the wardrobe window)", what)
    local now = getTimestampMs and getTimestampMs() or 0
    if not C.sayAt or now - C.sayAt > 3000 then
        C.sayAt = now
        C.say(LWS.T("IGUI_LWS_Msg_Locked"))
    end
    return true
end

local function guard(class, what, field)
    if not class or not class.isValid or class.__lwsGuarded then return false end
    class.__lwsGuarded = true
    local orig = class.isValid
    class.isValid = function(self, ...)
        if blocked(self[field or "item"], what) then return false end
        return orig(self, ...)
    end
    return true
end

-- the inventory window does not list them
local function hidePane()
    if not ISInventoryPane or not ISInventoryPane.refreshContainer or ISInventoryPane.__lwsHidden then return false end
    ISInventoryPane.__lwsHidden = true
    local orig = ISInventoryPane.refreshContainer
    ISInventoryPane.refreshContainer = function(self, ...)
        local r = orig(self, ...)
        local ok, err = pcall(function()
            local list = self.itemslist
            if type(list) ~= "table" then return end
            for i = #list, 1, -1 do
                local e = list[i]
                local first = e and e.items and e.items[1]
                if first and LWS.isFashion(first) then table.remove(list, i) end
            end
        end)
        if not ok then LWS.logOnce("panehide", "Client", "could not hide fashion items in the inventory window: %s", tostring(err)) end
        return r
    end
    return true
end

function C.installGuards()
    local n = 0
    for _, g in ipairs({
        { ISInventoryTransferAction, "transfer" }, { ISDropItemAction, "drop" }, { ISDropWorldItemAction, "drop" },
        { ISUnequipAction, "take off" }, { ISClothingExtraAction, "change" }, { ISWearClothing, "wear" },
    }) do
        if guard(g[1], g[2]) then n = n + 1 end
    end
    local pane = hidePane()
    log("guards installed: %d actions blocked for fashion items, inventory list %s", n, pane and "hides them" or "NOT hidden (no ISInventoryPane.refreshContainer)")
end

-- ------------------------------------------------------------- debug (admins)
local function debugMenu(add, player, target)
    if not LWS.isAdmin(player) then return end
    add(LWS.T("IGUI_LWS_Debug_Admin"), function()
        if LWSWindow and LWSWindow.open then LWSWindow.open(player, "admin") end
    end)
    local who = target or player
    local key = LWS.ownerKey(who)
    if key then
        add(LWS.T("IGUI_LWS_Debug_GiveSet", LWS.name(who)), function()
            for _, c in ipairs(LWS.CATALOG) do C.send("AdminGrant", { owner = key, piece = c.id }) end
            log("debug: gave the whole test set (%d pieces) to %s", #LWS.CATALOG, LWS.name(who))
        end)
    end
end

-- ------------------------------------------------------------- events
local function onCreatePlayer(index, player)
    if player and player.isLocalPlayer and player:isLocalPlayer() then C.hello("character made") end
end

local nextTick = 0
local function onTick()
    local now = getTimestampMs and getTimestampMs() or 0
    if now < nextTick then return end
    nextTick = now + 500
    if next(C.pending) ~= nil then
        local ok, err = pcall(C.dressNow)
        if not ok then LWS.logOnce("dresserr", "Client", "dressing FAILED: %s", tostring(err)) end
    end
end

if Events and not C.registered then
    C.registered = true
    if Events.OnServerCommand then Events.OnServerCommand.Add(onServerCommand) end
    if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(onCreatePlayer) end
    if Events.OnTick then Events.OnTick.Add(onTick) end
    if Events.OnGameStart then
        Events.OnGameStart.Add(function()
            C.installGuards()
            if HARMONIE_RegisterDebug then HARMONIE_RegisterDebug("LWS", debugMenu) end
            -- single player: OnCreatePlayer may have come before the server side was ready
            if not (isClient and isClient()) then C.hello("game start") end
        end)
    end
end

return C

-- ============================================================================
-- Server-side trade transaction handler.
--
-- The client only sends the itemType it wants to trade. The server re-derives
-- the current 12h-block list, the quantity and the price, then moves the
-- money/items itself. This keeps every transaction authoritative and
-- cheat-resistant (the client's displayed prices are cosmetic).
-- ============================================================================

local MODULE = MFSTrade.MODULE

local function log(message)
    print("[MFSTradeServer] " .. tostring(message))
end

local function findEntry(list, itemType)
    for _, entry in ipairs(list or {}) do
        if entry.itemType == itemType then
            return entry
        end
    end
    return nil
end

-- 收购: the player sells a vanilla item to the trader in exchange for money.
local function handleSell(player, itemType)
    local entry = findEntry(MFSTrade.BuildBuyList(), itemType)
    if not entry then
        return false, "item not offered"
    end
    if not MFSTrade.HasRadio(player) then
        return false, "no radio"
    end

    local count = entry.count or 1
    local price = entry.price or 0

    if player:getInventory():getItemCountRecurse(itemType) < count then
        return false, "not enough items"
    end
    if not MFSTrade.TakeItem(player, itemType, count) then
        return false, "could not remove items"
    end

    MFSTrade.GiveMoney(player, price)
    return true, nil
end

-- 贩卖: the player buys an item from the trader in exchange for money.
local function handleBuy(player, itemType)
    local entry = findEntry(MFSTrade.BuildSellList(), itemType)
    if not entry then
        return false, "item not offered"
    end
    if not MFSTrade.HasRadio(player) then
        return false, "no radio"
    end

    local count = entry.count or 1
    local unitPrice = entry.unitPrice or 0
    local total = count * unitPrice

    if MFSTrade.GetMoney(player) < total then
        return false, "not enough money"
    end
    if not MFSTrade.TakeMoney(player, total) then
        return false, "could not take money"
    end

    MFSTrade.GiveItem(player, itemType, count)
    return true, nil
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE then
        return
    end
    if not player then
        return
    end

    -- Make sure the per-world seed exists before any list/price is derived.
    MFSTrade.EnsureWorldSeed()

    -- Client asks for the current money (pure number, server-authoritative).
    if command == MFSTrade.CMD_MONEY then
        pcall(sendServerCommand, player, MODULE, MFSTrade.ACK, {
            money = MFSTrade.GetMoney(player),
        })
        return
    end

    -- Client asks for the per-world trade seed (server-authoritative).
    if command == MFSTrade.CMD_SEED then
        pcall(sendServerCommand, player, MODULE, MFSTrade.ACK, {
            seed = MFSTrade.GetWorldSeed(),
        })
        return
    end

    -- Buy/sell transactions always carry an itemType payload. The money/seed
    -- requests above take no payload, and the client sends them as an empty
    -- table that the network layer may collapse to nil, so they must be handled
    -- before this args-table validation.
    if type(args) ~= "table" then
        return
    end

    local itemType = args.itemType
    if type(itemType) ~= "string" or itemType == "" or #itemType > 160 then
        sendServerCommand(player, MODULE, MFSTrade.ACK, { accepted = false, reason = "invalid item" })
        return
    end

    -- Sandbox toggle: refuse all buy/sell when radio trading is disabled.
    if not MFSTrade.IsEnabled() then
        sendServerCommand(player, MODULE, MFSTrade.ACK, { accepted = false, reason = "trade disabled" })
        return
    end

    local handler
    if command == MFSTrade.CMD_SELL then
        handler = handleSell
    elseif command == MFSTrade.CMD_BUY then
        handler = handleBuy
    else
        return
    end

    local ok, accepted, reason = pcall(handler, player, itemType)
    if not ok then
        reason = tostring(accepted) -- pcall's error message
        accepted = false
    end

    local ackOk, ackErr = pcall(sendServerCommand, player, MODULE, MFSTrade.ACK, {
        accepted = accepted == true,
        reason = reason,
        money = MFSTrade.GetMoney(player),
    })
    if not ackOk then
        log("acknowledgement failed: " .. tostring(ackErr))
    end

    if accepted ~= true then
        log("rejected " .. tostring(command) .. " " .. itemType .. " reason=" .. tostring(reason))
    end
end

if not MFSTrade._serverRegistered then
    Events.OnClientCommand.Add(onClientCommand)
    Events.OnGameStart.Add(function() MFSTrade.EnsureWorldSeed() end)
    MFSTrade._serverRegistered = true
end

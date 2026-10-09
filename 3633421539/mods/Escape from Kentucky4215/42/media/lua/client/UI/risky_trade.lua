-- ============================================================================
-- Trade UI. Opens to the RIGHT of the inspect window. Two sections:
--   收购 (trader buys FROM the player)  - player sells vanilla 纪念品 (Memento) loot for money
--   贩卖 (trader sells TO the player)   - player buys mod guns/parts/ammo
-- Each section lists 5 entries. Click an entry to complete the transaction.
-- ============================================================================

require "ISUI/ISPanel"
require "ISUI/ISButton"

riskyTradeWindow = nil

-- Byte-safe truncation that never splits a UTF-8 character in half.
local function utf8Truncate(s, maxBytes)
    if #s <= maxBytes then return s end
    local sub = string.sub(s, 1, maxBytes)
    local b = string.byte(sub, #sub)
    while b and b >= 0x80 and b < 0xC0 do
        sub = string.sub(sub, 1, #sub - 1)
        b = string.byte(sub, #sub)
    end
    b = string.byte(sub, #sub)
    if b and b >= 0xC0 then
        sub = string.sub(sub, 1, #sub - 1)
    end
    return sub .. ".."
end

-- ----------------------------------------------------------------------------
-- Single trade entry button.
-- ----------------------------------------------------------------------------
tradeItemButton = ISButton:derive("tradeItemButton")

function tradeItemButton:new(x, y, w, h, entry, kind, onClick)
    local o = {}
    o = ISButton:new(x, y, w, h)

    setmetatable(o, self)
    self.__index = self

    o.entry = entry          -- { itemType, count, price|unitPrice, ... }
    o.kind = kind            -- "buy" (player buys) or "sell" (player sells)
    o.onClick = onClick

    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.6 }
    o.backgroundColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.6 }
    o.backgroundColorMouseOver = { r = 0.35, g = 0.35, b = 0.35, a = 0.8 }

    o.icon = nil
    o.name = entry.itemType
    local seed = ScriptManager.instance and ScriptManager.instance:getItem(entry.itemType)
    if seed then
        local okName, nm = pcall(function() return seed:getDisplayName() end)
        if okName and nm and nm ~= "" then o.name = nm end
        local okIcon, icon = pcall(function() return seed:getIcon() end)
        if okIcon and icon then o.icon = getTexture("media/textures/Item_" .. icon .. ".png") end
    end

    return o
end

function tradeItemButton:render()
    ISButton.render(self)

    if self.icon then
        self:drawTextureScaled(self.icon, 2, 2, self.height - 4, self.height - 4, 1, 1, 1, 1)
    end

    local name = self.name or ""
    name = utf8Truncate(name, 18)
    self:drawText(name, self.height + 4, 4, 1, 1, 1, 1, UIFont.Small)

    local qty = self.entry.count or 1
    if self.kind == "buy" then
        -- trader sells to player: show unit price and total.
        local unit = self.entry.unitPrice or 0
        self:drawText("x" .. qty .. "  $" .. unit .. "/个", self.height + 4, self.height - 18, 1, 0.9, 0.4, 1, UIFont.Small)
    else
        -- trader buys from player: show total payout for the whole batch.
        local total = self.entry.price or 0
        self:drawText("x" .. qty .. "  $" .. total, self.height + 4, self.height - 18, 0.4, 1, 0.5, 1, UIFont.Small)
    end
end

function tradeItemButton:onMouseUp(x, y)
    ISButton.onMouseUp(self, x, y)
    if self.onClick then
        self.onClick(self.entry, self.kind)
    end
end

-- ----------------------------------------------------------------------------
-- The trade window.
-- ----------------------------------------------------------------------------
riskyTradeUI = ISPanel:derive("riskyTradeUI")

function riskyTradeUI:new(x, y, width, height)
    local o = {}
    o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.moveWithMouse = true
    o.resizable = false

    o.borderColor = { r = 0.8, g = 0.7, b = 0.3, a = 0.9 }
    o.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.85 }

    o.buyButtons = {}
    o.sellButtons = {}

    return o
end

function riskyTradeUI:createChildren()
    ISPanel.createChildren(self)

    if not self.closebutton then
        local btnW = 20
        self.closebutton = ISButton:new(self.width - btnW - 6, 4, btnW, btnW, "", self, self.onOptionMouseDown)
        self.closebutton.internal = "close"
        self.closebutton:initialise()
        self.closebutton:instantiate()
        self.closebutton.borderColor = { r = 1, g = 1, b = 1, a = 0 }
        self.closebutton:setImage(getTexture("media/textures/UI/EFK_Close.png"))
        self:addChild(self.closebutton)
    end

    self:rebuildLists()
end

function riskyTradeUI:onOptionMouseDown(button)
    if button.internal == "close" then
        self:close()
    end
end

function riskyTradeUI:clearTradeButtons()
    for _, b in ipairs(self.buyButtons) do
        if b then self:removeChild(b) end
    end
    for _, b in ipairs(self.sellButtons) do
        if b then self:removeChild(b) end
    end
    self.buyButtons = {}
    self.sellButtons = {}
end

-- (Re)build the 5+5 entry buttons. Both lists are deterministic per effective
-- seed (world seed + 12h block) and built from getAllItems(), which is available
-- on the client, so they are generated locally (the server re-derives the same
-- lists to validate trades).
function riskyTradeUI:rebuildLists()
    self:clearTradeButtons()

    local seed = MFSTrade.GetEffectiveSeed()

    local buy
    if not self.buyCache or self.buyCacheSeed ~= seed then
        local okB, built = pcall(MFSTrade.BuildBuyList)
        self.buyCache = (okB and built) or {}
        self.buyCacheSeed = seed
    end
    buy = self.buyCache or {}

    local sell
    if not self.sellCache or self.sellCacheSeed ~= seed then
        local okS, built = pcall(MFSTrade.BuildSellList)
        self.sellCache = (okS and built) or {}
        self.sellCacheSeed = seed
    end
    sell = self.sellCache or {}

    self.lists = { seed = seed, buy = buy, sell = sell }
    print("[MFSTrade] rebuilt seed=" .. tostring(seed) .. " buy=" .. #buy .. " sell=" .. #sell)

    local margin = 8
    local rowH = 40
    local gap = 3
    local buyY = 66
    -- Lay the sell section out below however many buy entries were actually
    -- built, so a custom (longer/shorter) item list stays correctly spaced.
    local buyCount = #self.lists.buy
    local sellY = buyY + buyCount * (rowH + gap) + 42

    for i, entry in ipairs(self.lists.buy) do
        local y = buyY + (i - 1) * (rowH + gap)
        local btn = tradeItemButton:new(margin, y, self.width - margin * 2, rowH, entry, "sell",
            function(e, k) self:onTradeEntry(e, k) end)
        btn:initialise()
        btn:instantiate()
        self:addChild(btn)
        self.buyButtons[#self.buyButtons + 1] = btn
    end

    for i, entry in ipairs(self.lists.sell) do
        local y = sellY + (i - 1) * (rowH + gap)
        local btn = tradeItemButton:new(margin, y, self.width - margin * 2, rowH, entry, "buy",
            function(e, k) self:onTradeEntry(e, k) end)
        btn:initialise()
        btn:instantiate()
        self:addChild(btn)
        self.sellButtons[#self.sellButtons + 1] = btn
    end
end

function riskyTradeUI:onTradeEntry(entry, kind)
    local player = getPlayer()
    if not player then return end

    local cmd = (kind == "buy") and MFSTrade.CMD_BUY or MFSTrade.CMD_SELL
    local ok, err = pcall(sendClientCommand, player, MFSTrade.MODULE, cmd, { itemType = entry.itemType })
    if not ok then
        print("[MFSTrade] sendClientCommand failed: " .. tostring(err))
    end
    self:refresh()
end

-- Ask the server for the authoritative money value (no-op in SP, where modData
-- is shared; in MP it syncs the top-right display after (re)connecting).
function riskyTradeUI:requestMoney()
    local ok, err = pcall(sendClientCommand, getPlayer(), MFSTrade.MODULE, MFSTrade.CMD_MONEY, {})
    if not ok then
        print("[MFSTrade] request money failed: " .. tostring(err))
    end
end

-- Ask the server for the per-world trade seed (no-op in SP, where the global is
-- shared; in MP it keeps the client's list in sync with the server's).
function riskyTradeUI:requestSeed()
    local ok, err = pcall(sendClientCommand, getPlayer(), MFSTrade.MODULE, MFSTrade.CMD_SEED, {})
    if not ok then
        print("[MFSTrade] request seed failed: " .. tostring(err))
    end
end

-- Refresh money display and regenerate the lists if the 12h block rolled over.
function riskyTradeUI:update()
    ISPanel.update(self)

    if not self:getIsVisible() then return end

    if not self.lists or self.lists.seed ~= MFSTrade.GetEffectiveSeed() then
        self:rebuildLists()
    end

    local player = getPlayer()
    self.money = player and MFSTrade.GetMoney(player) or 0
end

function riskyTradeUI:refresh()
    local player = getPlayer()
    self.money = player and MFSTrade.GetMoney(player) or 0
end

function riskyTradeUI:prerender()
    ISPanel.prerender(self)

    self:drawText(getText("IGUI_MFSTrade_Title"), 8, 6, 1, 1, 1, 1, UIFont.Small)

    local remain = MFSTrade.GetRefreshRemainingHours()
    local h = math.floor(remain)
    local m = math.floor((remain - h) * 60 + 0.5)
    if m >= 60 then m = 0; h = h + 1 end
    self:drawText(getText("IGUI_MFSTrade_Refresh") .. " " .. string.format("%d:%02d", h, m),
        8, 26, 1, 0.9, 0.4, 1, UIFont.Small)

    self:drawTextRight(getText("IGUI_MFSTrade_Money") .. ": $" .. tostring(self.money or 0),
        self.width - 26, 8, 0.4, 1, 0.5, 1, UIFont.Small)

    self:drawText(getText("IGUI_MFSTrade_Buy") .. " (" .. getText("IGUI_MFSTrade_BuyHint") .. ")",
        8, 44, 0.4, 1, 0.5, 1, UIFont.Small)

    local buyCount = (self.lists and #self.lists.buy) or 5
    local sellLabelY = 44 + buyCount * (40 + 3) + 42
    self:drawText(getText("IGUI_MFSTrade_Sell") .. " (" .. getText("IGUI_MFSTrade_SellHint") .. ")",
        8, sellLabelY, 1, 0.9, 0.4, 1, UIFont.Small)
end

function riskyTradeUI:close()
    self:setVisible(false)
    self:removeFromUIManager()
    riskyTradeWindow = nil
end

-- ----------------------------------------------------------------------------
-- Open / toggle the trade window anchored to the right of the inspect window.
-- ----------------------------------------------------------------------------
function riskyTradeUI.open(parentWindow)
    if not MFSTrade.IsEnabled() then
        return
    end
    if riskyTradeWindow and riskyTradeWindow:getIsVisible() then
        riskyTradeWindow:close()
        return
    end

    local x = parentWindow:getX() + parentWindow:getWidth()
    local y = parentWindow:getY()
    local w = 280
    local h = parentWindow:getHeight()

    riskyTradeWindow = riskyTradeUI:new(x, y, w, h)
    riskyTradeWindow:initialise()
    riskyTradeWindow:addToUIManager()
    riskyTradeWindow:requestMoney()
    riskyTradeWindow:requestSeed()
end

-- Server -> client: update money (pure number) after a transaction or a money
-- request, then refresh the top-right display.
local function onServerCommand(module, command, args)
    if module ~= MFSTrade.MODULE then return end

    if command == MFSTrade.ACK then
        local seed = tonumber(args.seed)
        if seed and seed > 0 then
            MFSTrade.WorldSeed = seed
            if riskyTradeWindow and riskyTradeWindow:getIsVisible() then
                riskyTradeWindow:rebuildLists()
            end
        end
        local m = tonumber(args.money)
        if m ~= nil then
            local p = getPlayer()
            if p then p:getModData()[MFSTrade.MoneyKey] = m end
        end
        if riskyTradeWindow and riskyTradeWindow:getIsVisible() then
            riskyTradeWindow:refresh()
        end
    end
end
Events.OnServerCommand.Add(onServerCommand)

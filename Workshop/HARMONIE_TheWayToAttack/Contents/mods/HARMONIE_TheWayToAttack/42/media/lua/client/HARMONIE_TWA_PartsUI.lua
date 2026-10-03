--============================================================================
-- HARMONIE_TheWayToAttack -- melee weapon part UI (client)
--
-- A simplified 2D version of BladesmithSystem's melee weapon UI (Workshop
-- 3633421539): 4 slot buttons (Grip/Head/Tactical/Weight) + a live stat
-- block. No 3D weapon preview and no position-offset sliders -- those were
-- deliberately dropped for this first pass (see mods/workflow.txt). Click an
-- empty slot to pick a part from nearby containers; double-click an
-- installed slot to remove it. Parts install/remove through the vanilla
-- timed actions (ISUpgradeWeapon / ISRemoveWeaponUpgrade), overridden for
-- melee in HARMONIE_TWA_UpgradeAction.lua.
--============================================================================

require "HARMONIE_TWA_Font"
require "ISUI/ISPanel"
require "HARMONIE_TWA_Display"
require "HARMONIE_TWA_Sources"
require "ISUI/ISButton"
require "ISUI/ISCollapsableWindow"
require "TimedActions/ISInventoryTransferAction"
require "TimedActions/ISGrabItemAction"
require "TimedActions/ISUpgradeWeapon"
require "TimedActions/ISRemoveWeaponUpgrade"

TWAPartsUI = TWAPartsUI or {}

local WINDOW_W = 420
local WINDOW_H = 400
local SLOT_X   = 20
local SLOT_W   = 180
local SLOT_H   = 50
local SLOT_Y0  = 56
local SLOT_GAP = 58
local STAT_Y0  = 300

local STAT_LINES = {
    { label = "IGUI_TWA_Stat_MinDamage",  get = "getMinDamage",      fmt = "%s", scale = true },
    { label = "IGUI_TWA_Stat_MaxDamage",  get = "getMaxDamage",      fmt = "%s", scale = true },
    { label = "IGUI_TWA_Stat_CritChance", get = "getCriticalChance", fmt = "%.1f" },
    { label = "IGUI_TWA_Stat_Speed",      get = "getBaseSpeed",      fmt = "%.1f" },
    { label = "IGUI_TWA_Stat_Range",      get = "getMaxRange",       fmt = "%.1f" },
    { label = "IGUI_TWA_Stat_Endurance",  get = "getEnduranceMod",   fmt = "%.2f" },
    { label = "IGUI_TWA_Stat_PushBack",   get = "getPushBackMod",    fmt = "%.2f" },
    { label = "IGUI_TWA_Stat_Knockdown",  get = "getKnockdownMod",   fmt = "%.2f" },
    { label = "IGUI_TWA_Stat_Condition",  get = "getConditionMax",   fmt = "%.1f" },
}

-- Helpers ---------------------------------------------------------------------

local function partFits(item, player, weapon, slot)
    local isWeaponPart = instanceof(item, "WeaponPart")
    if not isWeaponPart then
        local okCategory, category = pcall(function() return item:getCategory() end)
        isWeaponPart = okCategory and category == "WeaponPart"
    end
    if isWeaponPart and item:getPartType() == slot and not item:isBroken() then
        local ok, allowed = pcall(function() return item:canAttach(player, weapon) end)
        return ok and allowed
    end
    return false
end

local function scanParts(container, player, weapon, slot, result, visited)
    if not container or visited[tostring(container)] then return end
    visited[tostring(container)] = true
    local items = container:getItems()
    if not items then return end
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item then
            if partFits(item, player, weapon, slot) then result[#result + 1] = item end
            if instanceof(item, "InventoryContainer") then
                scanParts(item:getInventory(), player, weapon, slot, result, visited)
            end
        end
    end
end

-- R67 ("อะไรที่หาไอเท็มในตัว ให้สามารถหาได้บนพื้นและในกล่องรอบตัวเสมอ"):
-- the same places crafting looks (TWASources: carried, containers and the
-- floor around you) -- loose parts on the floor included now.
local function scanAllParts(player, weapon, slot)
    local result, visited = {}, {}
    local src = TWASources.get(player)
    for _, container in ipairs(src.conts) do
        scanParts(container, player, weapon, slot, result, visited)
    end
    for _, item in ipairs(src.floor) do
        if partFits(item, player, weapon, slot) then result[#result + 1] = item end
        if instanceof(item, "InventoryContainer") then
            scanParts(item:getInventory(), player, weapon, slot, result, visited)
        end
    end
    return result
end

-- Slot button -------------------------------------------------------------

TWASlotButton = ISButton:derive("TWASlotButton")

function TWASlotButton:new(x, y, w, h, slotItem, weapon, slotKey, label, ui)
    local o = ISButton:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.slotItem = slotItem
    o.weapon = weapon
    o.slotKey = slotKey
    o.label = label
    o.ui = ui
    o.backgroundColor = { r = 0.5, g = 0.5, b = 0.5, a = 0.3 }
    o.backgroundColorMouseOver = { r = 0.5, g = 0.5, b = 0.5, a = 0.8 }
    o.itemTexture = nil
    if slotItem then
        o.itemTexture = slotItem:getTexture()
        if not o.itemTexture then
            local icon = slotItem:getIcon()
            if icon then o.itemTexture = getTexture("media/textures/Item_" .. icon .. ".png") end
        end
    end
    return o
end

function TWASlotButton:render()
    ISButton.render(self)
    if self.slotItem then
        self.borderColor = { r = 0, g = 0.8, b = 0, a = 0.6 }
    else
        self.borderColor = { r = 0.8, g = 0, b = 0, a = 0.5 }
    end
    if self.itemTexture then
        self:drawTextureScaled(self.itemTexture, 6, 6, self.height - 12, self.height - 12, 1, 1, 1, 1)
    else
        self:drawRectBorder(6, 6, self.height - 12, self.height - 12, 0.3, 1, 1, 1)
    end
    self:drawText(self.label, self.height, 12, 1, 1, 1, 1, TWAFont.small())
end

function TWASlotButton:onMouseUp(x, y)
    if self.slotItem == nil then
        local pane = TWASelectPane:new(self.ui:getAbsoluteX() + self:getX() + self.width + 4,
            self.ui:getAbsoluteY() + self:getY(), self.slotKey, self.weapon)
        pane:initialise()
        pane:instantiate()
        pane:addToUIManager()
        pane:renderInventory()
        pane:bringToTop()
    end
end

function TWASlotButton:onMouseDoubleClick()
    if self.slotItem then
        ISTimedActionQueue.add(ISRemoveWeaponUpgrade:new(getPlayer(), self.weapon, self.slotKey, 1))
    end
end

-- Add-part button (inside the selection pane) ------------------------------

TWAAddPartButton = ISButton:derive("TWAAddPartButton")

function TWAAddPartButton:new(x, y, w, h, part, weapon)
    local o = ISButton:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.part = part
    o.weapon = weapon
    o.backgroundColor = { r = 0.5, g = 0.5, b = 0.5, a = 0.3 }
    o.backgroundColorMouseOver = { r = 0.5, g = 0.5, b = 0.5, a = 0.8 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.toolTip = ISToolTipInv:new(part)
    o.toolTip:setOwner(o)
    o.toolTip:setVisible(false)
    o.toolTip:addToUIManager()
    local tex = part:getTexture()
    if not tex then
        local icon = part:getIcon()
        if icon then tex = getTexture("media/textures/Item_" .. icon .. ".png") end
    end
    if tex then o:setImage(tex) end
    return o
end

function TWAAddPartButton:render()
    ISButton.render(self)
    if self.toolTip then
        if self:isMouseOver() then
            self.toolTip:setVisible(true)
            self.toolTip:bringToTop()
        else
            self.toolTip:setVisible(false)
        end
    end
end

function TWAAddPartButton:onMouseDown()
    if not self.part then return end
    local player = getPlayer()
    local part = self.part
    local srcContainer = part:getContainer()
    local worldItem = part.getWorldItem and part:getWorldItem()
    if worldItem and ISGrabItemAction then
        -- a loose part on the floor: pick it up first
        ISTimedActionQueue.add(ISGrabItemAction:new(player, worldItem, 50))
    elseif srcContainer and srcContainer ~= player:getInventory() then
        ISTimedActionQueue.add(ISInventoryTransferAction:new(player, part, srcContainer, player:getInventory()))
    end
    ISTimedActionQueue.add(ISUpgradeWeapon:new(player, self.weapon, part, 1))
end

-- Part selection pane -------------------------------------------------------

TWASelectPane = ISPanel:derive("TWASelectPane")

function TWASelectPane:new(x, y, slotKey, weapon)
    if TWAPartsUI.selectPane then
        TWAPartsUI.selectPane:close()
    end
    local o = ISPanel:new(x, y, 40 * 5 + 20, 126)
    setmetatable(o, self)
    self.__index = self
    o.slotKey = slotKey
    o.weapon = weapon
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }
    o.borderColor = { r = 0.9, g = 0.9, b = 0.9, a = 0.7 }
    TWAPartsUI.selectPane = o
    return o
end

function TWASelectPane:prerender()
    self:setStencilRect(0, 0, self.width, self.height)
    self:drawRect(-self:getXScroll(), -self:getYScroll(), self.width, self.height, self.backgroundColor.a,
        self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
end

function TWASelectPane:render()
    self:clearStencilRect()
    self:drawRectBorder(-self:getXScroll(), -self:getYScroll(), self.width, self.height, self.borderColor.a,
        self.borderColor.r, self.borderColor.g, self.borderColor.b)
end

function TWASelectPane:createChildren()
    self:addScrollBars(false)
    self:setScrollWithParent(false)
    self:setScrollChildren(true)
end

function TWASelectPane:onMouseWheel(del)
    self:setYScroll(self:getYScroll() - (del * 42))
    return true
end

function TWASelectPane:update()
    if self:getIsVisible() then
        local weapon = getPlayer():getPrimaryHandItem()
        if not weapon or not TWAPartSystem.IsMeleeWeapon(weapon) or not TWAPartsUI.window
            or not TWAPartsUI.window:getIsVisible() then
            self:close()
        end
    end
end

function TWASelectPane:renderInventory()
    for _, child in ipairs(self:getChildrenInOrder() or {}) do
        if child and child.toolTip then
            child.toolTip:setVisible(false)
            child.toolTip:removeFromUIManager()
            child.toolTip = nil
        end
    end
    self:clearChildren()

    local player = getPlayer()
    local weapon = player:getPrimaryHandItem()
    if not weapon or not weapon.IsWeapon or not weapon:IsWeapon() then return end

    local alreadyDone = {}
    local itemNum = 0
    local rowCount = -1
    local partResult = scanAllParts(player, weapon, self.slotKey)

    for _, part in ipairs(partResult) do
        if not alreadyDone[part:getFullType()] then
            alreadyDone[part:getFullType()] = true
            if math.fmod(itemNum, 5) == 0 then
                rowCount = rowCount + 1
            end
            local x = 2 + 41 * math.fmod(itemNum, 5)
            local y = 2 + 41 * rowCount
            local btn = TWAAddPartButton:new(x, y, 40, 40, part, weapon)
            btn:initialise()
            btn:instantiate()
            btn:bringToTop()
            self:addChild(btn)
            itemNum = itemNum + 1
        end
    end
    self:setScrollHeight(42 * (rowCount + 1))
    if self:getHeight() >= self:getScrollHeight() then
        self:setWidth(40 * 5 + 8)
    end
end

function TWASelectPane:close()
    for _, child in ipairs(self:getChildrenInOrder() or {}) do
        if child and child.toolTip then
            child.toolTip:setVisible(false)
            child.toolTip:removeFromUIManager()
            child.toolTip = nil
        end
    end
    self:clearChildren()
    self:setVisible(false)
    self:removeFromUIManager()
    if TWAPartsUI.selectPane == self then
        TWAPartsUI.selectPane = nil
    end
end

function TWASelectPane:onMouseDownOutside(x, y)
    if self:getIsVisible() and not self.vscroll:isMouseOver() then
        self:close()
    end
end

-- Main window ---------------------------------------------------------------

TWAPartsWindow = ISCollapsableWindow:derive("TWAPartsWindow")

function TWAPartsWindow:new(x, y, player)
    local o = ISCollapsableWindow:new(x, y, WINDOW_W, WINDOW_H)
    setmetatable(o, self)
    self.__index = self
    o.player = player or getPlayer()
    o.weapon = nil
    o.lastSig = nil
    o.resizable = false
    o.title = getText("IGUI_TWA_WindowTitle")
    return o
end

function TWAPartsWindow:partsSig(weapon)
    if not weapon or not TWAPartSystem.IsMeleeWeapon(weapon) then return "none" end
    local s = ""
    for _, sl in ipairs(TWAPartSystem.Slots) do
        local part = TWAPartSystem.GetPart(weapon, sl.key)
        s = s .. tostring(part and part:getFullType() or "") .. "|"
    end
    return s
end

function TWAPartsWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
end

function TWAPartsWindow:renderInventory()
    if not self.javaObject then return end

    -- Only remove OUR OWN slot buttons (tracked separately), never touch the
    -- window's own built-in children (close/pin/collapse/resize widgets).
    for _, btn in ipairs(self.slotButtons or {}) do
        self:removeChild(btn)
    end
    self.slotButtons = {}

    local weapon = self.player:getPrimaryHandItem()
    self.weapon = weapon

    if weapon and TWAPartSystem.IsMeleeWeapon(weapon) then
        for i, s in ipairs(TWAPartSystem.Slots) do
            local part = TWAPartSystem.GetPart(weapon, s.key)
            local y = SLOT_Y0 + (i - 1) * SLOT_GAP
            local btn = TWASlotButton:new(SLOT_X, y, SLOT_W, SLOT_H, part, weapon, s.key, getText(s.label), self)
            btn:initialise()
            btn:instantiate()
            self:addChild(btn)
            self.slotButtons[#self.slotButtons + 1] = btn
        end
    end

    self.lastSig = self:partsSig(weapon)
end

function TWAPartsWindow:prerender()
    ISCollapsableWindow.prerender(self)
    local weapon = self.weapon
    if weapon and TWAPartSystem.IsMeleeWeapon(weapon) then
        local tex = weapon:getTexture()
        local titleY = self:titleBarHeight()
        if tex then
            self:drawTextureScaled(tex, 16, titleY + 8, 32, 32, 1, 1, 1, 1)
        end
        self:drawText(weapon:getDisplayName(), 56, titleY + 16, 1, 1, 1, 1, TWAFont.medium())
    end
end

function TWAPartsWindow:render()
    ISCollapsableWindow.render(self)
    local weapon = self.weapon
    if not weapon or not TWAPartSystem.IsMeleeWeapon(weapon) then return end

    local sy = STAT_Y0
    for i, st in ipairs(STAT_LINES) do
        local v = weapon[st.get] and weapon[st.get](weapon) or nil
        if v ~= nil and st.scale then v = TWADisplay.fmt(v) end   -- shown multiplied (TWADisplay)
        if v ~= nil then
            self:drawText(getText(st.label) .. ": " .. string.format(st.fmt, v), SLOT_X, sy + (i - 1) * 20, 1, 1, 1, 1,
                TWAFont.small())
        end
    end
end

function TWAPartsWindow:update()
    ISCollapsableWindow.update(self)
    if not self:getIsVisible() then return end
    local weapon = self.player:getPrimaryHandItem()
    if not TWAPartSystem.IsMeleeWeapon(weapon) then
        self:close()
        return
    end
    local sig = self:partsSig(weapon)
    if weapon ~= self.weapon or sig ~= self.lastSig then
        self:renderInventory()
    end
end

function TWAPartsWindow:close()
    TWAPartsUI.close()
end

-- Open / close / toggle / refresh --------------------------------------------

function TWAPartsUI.open(player)
    player = player or getPlayer()
    if not player then return end
    if TWAPartsUI.window and TWAPartsUI.window:getIsVisible() then
        return
    end

    local x, y = 100, 100
    local pos = player:getModData().TWAPartsWindowPos
    if pos and pos[1] and pos[2] then
        x, y = pos[1], pos[2]
    end
    local core = getCore()
    if core then
        x = math.max(0, math.min(x, core:getScreenWidth() - 200))
        y = math.max(0, math.min(y, core:getScreenHeight() - 80))
    end

    local win = TWAPartsWindow:new(x, y, player)
    TWAPartsUI.window = win
    win:initialise()
    win:addToUIManager()
    win:renderInventory()
    win:bringToTop()
end

function TWAPartsUI.close()
    local win = TWAPartsUI.window
    if not win then return end
    local player = win.player or getPlayer()
    if player then
        player:getModData().TWAPartsWindowPos = { win:getX(), win:getY() }
    end
    if TWAPartsUI.selectPane then
        TWAPartsUI.selectPane:close()
        TWAPartsUI.selectPane = nil
    end
    win:setVisible(false)
    win:removeFromUIManager()
    TWAPartsUI.window = nil
end

function TWAPartsUI.toggle()
    if TWAPartsUI.window and TWAPartsUI.window:getIsVisible() then
        TWAPartsUI.close()
    else
        TWAPartsUI.open()
    end
end

function TWAPartsUI.refresh()
    local win = TWAPartsUI.window
    if win and win:getIsVisible() then
        win:renderInventory()
    end
end

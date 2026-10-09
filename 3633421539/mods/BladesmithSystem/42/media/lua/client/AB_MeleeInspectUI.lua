--============================================================================
-- BladesmithSystem — melee weapon modification UI (client)
--
-- A full 3D replica of MFS's gun UI: ISUI3DScene weapon preview + native
-- WeaponPart attach/detach + MFS's textures. Four slots (Grip/Head/Tactical/
-- Weight). Click an empty slot to pick a part from nearby containers;
-- double-click an installed slot to remove it; the wrench button opens the
-- position sliders. Parts install/remove through the vanilla timed actions.
--============================================================================

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISSliderPanel"
require "TimedActions/ISInventoryTransferAction"
require "TimedActions/ISUpgradeWeapon"
require "TimedActions/ISRemoveWeaponUpgrade"

ABMeleeInspect = ABMeleeInspect or {}

local WINDOW_W = 940
local WINDOW_H = 720
local SCENE_X  = 70
local SCENE_Y  = 60
local SCENE_W  = 800
local SCENE_H  = 450
local SLOT_W   = 165
local SLOT_H   = 56
local SLOT_Y   = 622
local SLOT_XS  = { 70, 250, 430, 610 }

local STAT_LINES = {
    { label = "最小伤害", get = "getMinDamage",      fmt = "%.1f" },
    { label = "最大伤害", get = "getMaxDamage",      fmt = "%.1f" },
    { label = "暴击率",   get = "getCriticalChance", fmt = "%.1f" },
    { label = "攻击速度", get = "getBaseSpeed",      fmt = "%.1f" },
    { label = "攻击距离", get = "getMaxRange",       fmt = "%.1f" },
    { label = "体力消耗", get = "getEnduranceMod",   fmt = "%.2f" },
    { label = "击退",     get = "getPushBackMod",    fmt = "%.2f" },
    { label = "击倒",     get = "getKnockdownMod",   fmt = "%.2f" },
    { label = "耐久",     get = "getConditionMax",   fmt = "%.1f" },
}

-- Helpers ---------------------------------------------------------------------

local function isUsableWorldModel(worldmodel)
    if not worldmodel or worldmodel == "" then return false end
    if string.find(worldmodel, "nil") then return false end
    if string.find(worldmodel, "null") then return false end
    return true
end

local function getOrCreateAttachment(model, partType)
    local attachment = model:getAttachmentById(partType)
    if not attachment then
        attachment = ModelAttachment.new(partType)
        model:addAttachment(attachment)
    end
    return attachment
end

function scanParts(container, player, weapon, slot, result, visited)
    if not container or visited[tostring(container)] then return end
    visited[tostring(container)] = true
    local items = container:getItems()
    if not items then return end
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item then
            local isWeaponPart = instanceof(item, "WeaponPart")
            if not isWeaponPart then
                local okCategory, category = pcall(function() return item:getCategory() end)
                isWeaponPart = okCategory and category == "WeaponPart"
            end
            if isWeaponPart and item:getPartType() == slot and not item:isBroken() then
                local ok, allowed = pcall(function() return item:canAttach(player, weapon) end)
                if ok and allowed then result[#result + 1] = item end
            end
            if instanceof(item, "InventoryContainer") then
                scanParts(item:getInventory(), player, weapon, slot, result, visited)
            end
        end
    end
end

function getReachableContainers(player)
    local containers = {}
    local seen = {}
    local function addContainer(container)
        if container and not seen[tostring(container)] then
            seen[tostring(container)] = true
            containers[#containers + 1] = container
        end
    end

    addContainer(player:getInventory())

    local square = player:getCurrentSquare()
    if not square then return containers end
    local cx, cy, cz = square:getX(), square:getY(), square:getZ()

    for dx = -1, 1 do
        for dy = -1, 1 do
            local gridSquare = getCell():getGridSquare(cx + dx, cy + dy, cz)
            if gridSquare then
                local objects = gridSquare:getObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj then
                            local ok, container = pcall(function() return obj:getContainer() end)
                            if ok then addContainer(container) end
                        end
                    end
                end
                local worldObjects = gridSquare:getWorldObjects()
                if worldObjects then
                    for i = 0, worldObjects:size() - 1 do
                        local worldObject = worldObjects:get(i)
                        if worldObject then
                            local ok, item = pcall(function() return worldObject:getItem() end)
                            if ok and item and instanceof(item, "InventoryContainer") then
                                addContainer(item:getInventory())
                            end
                        end
                    end
                end
            end
        end
    end
    return containers
end

local function roundOffset(value)
    return math.floor(value * 10000 + 0.5) / 10000
end

local function formatAxisValue(value, axis)
    local center = axis == 2 and 300 or 100
    return roundOffset((value - center) * 0.001)
end

-- Slot button -----------------------------------------------------------------

ABSlotButton = ISButton:derive("ABSlotButton")

function ABSlotButton:new(x, y, w, h, slotItem, weapon, slotKey, label, ui)
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

function ABSlotButton:render()
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
    self:drawText(self.label, self.height, 12, 1, 1, 1, 1, UIFont.Small)
end

function ABSlotButton:onMouseUp(x, y)
    if self.slotItem == nil then
        local pane = ABSelectPane:new(self.ui:getAbsoluteX() + self:getX() + self.width + 4,
            self.ui:getAbsoluteY() + self:getY(), self.slotKey, self.weapon)
        pane:initialise()
        pane:instantiate()
        pane:addToUIManager()
        pane:renderInventory()
        pane:bringToTop()
    end
end

function ABSlotButton:onMouseDoubleClick()
    if self.slotItem then
        ISTimedActionQueue.add(ISRemoveWeaponUpgrade:new(getPlayer(), self.weapon, self.slotKey, 1))
        getSoundManager():PlayWorldSound("WeaponPartInsertSound", getPlayer():getSquare(), 0, 0, 0, false)
    end
end

function ABSlotButton:onMouseDown(x, y)
    ISButton.onMouseDown(self, x, y)
    local slider = self.ui.settingpanel
    if not slider or not self.slotItem then return end

    local item = ScriptManager.instance:getItem(self.slotItem:getFullType())
    if not item then return end
    local worldmodel = item:getWorldStaticModel()
    local held = getPlayer():getPrimaryHandItem()
    if not held or not held.getWeaponSprite then return end
    local model = ScriptManager.instance:getModelScript("Base." .. held:getWeaponSprite())
    if not model or not isUsableWorldModel(worldmodel) then return end

    local attachment = getOrCreateAttachment(model, self.slotKey)

    slider.itempart = self.slotItem:getFullType()
    slider.worldmodel = worldmodel
    slider.itempartoffsetment = attachment
    slider.itempartoffset = attachment and attachment:getOffset() or nil

    local md = held:getModData()
    if not md.GunPos then md.GunPos = {} end
    if not md.GunPos[slider.itempart] then
        md.GunPos[slider.itempart] = { x = 0, y = 0, z = 0 }
    end
    local gp = md.GunPos[slider.itempart]
    slider.slider1.currentValue = gp.x / 0.001 + 100
    slider.slider2.currentValue = gp.y / 0.001 + 300
    slider.slider3.currentValue = gp.z / 0.001 + 100

    -- Sync the saved offset to the attachment and the scene immediately, so the
    -- preview matches the sliders on first bind.
    if attachment then
        pcall(function() attachment:getOffset():set(gp.x, gp.y, gp.z) end)
    end
    if slider.parenta and slider.parenta.scene and slider.parenta.scene.javaObject and isUsableWorldModel(worldmodel) then
        pcall(function()
            slider.parenta.scene.javaObject:fromLua4("setObjectPosition", worldmodel, gp.x, gp.y, gp.z)
        end)
    end
end

-- Add-part button (inside the selection pane) ---------------------------------

ABAddPartButton = ISButton:derive("ABAddPartButton")

function ABAddPartButton:new(x, y, w, h, part, weapon)
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

function ABAddPartButton:render()
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

function ABAddPartButton:onMouseDown()
    if not self.part then return end
    local player = getPlayer()
    local part = self.part
    local srcContainer = part:getContainer()
    if srcContainer and srcContainer ~= player:getInventory() then
        ISTimedActionQueue.add(ISInventoryTransferAction:new(player, part, srcContainer, player:getInventory()))
    end
    ISTimedActionQueue.add(ISUpgradeWeapon:new(player, self.weapon, part, 1))
    getSoundManager():PlayWorldSound("WeaponPartInsertSound", player:getSquare(), 0, 0, 0, false)
end

-- Part selection pane ---------------------------------------------------------

ABSelectPane = ISPanel:derive("ABSelectPane")

function ABSelectPane:new(x, y, slotKey, weapon)
    if ABMeleeInspect.selectPane then
        ABMeleeInspect.selectPane:close()
    end
    local o = ISPanel:new(x, y, 40 * 5 + 20, 126)
    setmetatable(o, self)
    self.__index = self
    o.slotKey = slotKey
    o.weapon = weapon
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }
    o.borderColor = { r = 0.9, g = 0.9, b = 0.9, a = 0.7 }
    ABMeleeInspect.selectPane = o
    return o
end

function ABSelectPane:prerender()
    self:setStencilRect(0, 0, self.width, self.height)
    self:drawRect(-self:getXScroll(), -self:getYScroll(), self.width, self.height, self.backgroundColor.a,
        self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
end

function ABSelectPane:render()
    self:clearStencilRect()
    self:drawRectBorder(-self:getXScroll(), -self:getYScroll(), self.width, self.height, self.borderColor.a,
        self.borderColor.r, self.borderColor.g, self.borderColor.b)
end

function ABSelectPane:createChildren()
    self:addScrollBars(false)
    self:setScrollWithParent(false)
    self:setScrollChildren(true)
end

function ABSelectPane:onMouseWheel(del)
    self:setYScroll(self:getYScroll() - (del * 42))
    return true
end

function ABSelectPane:update()
    if self:getIsVisible() then
        local weapon = getPlayer():getPrimaryHandItem()
        if not weapon or not ABMeleePartSystem.IsMeleeWeapon(weapon) or not ABMeleeInspect.window
            or not ABMeleeInspect.window:getIsVisible() then
            self:close()
        end
    end
end

function ABSelectPane:renderInventory()
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
    if not weapon or not weapon:IsWeapon() then return end

    local alreadyDone = {}
    local itemNum = 0
    local rowCount = -1
    local partResult = {}
    local visited = {}
    for _, container in ipairs(getReachableContainers(player)) do
        scanParts(container, player, weapon, self.slotKey, partResult, visited)
    end

    for _, part in ipairs(partResult) do
        if not alreadyDone[part:getFullType()] then
            alreadyDone[part:getFullType()] = true
            if math.fmod(itemNum, 5) == 0 then
                rowCount = rowCount + 1
            end
            local x = 2 + 41 * math.fmod(itemNum, 5)
            local y = 2 + 41 * rowCount
            local btn = ABAddPartButton:new(x, y, 40, 40, part, weapon)
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

function ABSelectPane:close()
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
    if ABMeleeInspect.selectPane == self then
        ABMeleeInspect.selectPane = nil
    end
end

function ABSelectPane:onMouseDownOutside(x, y)
    if self:getIsVisible() and not self.vscroll:isMouseOver() then
        self:close()
    end
end

-- Position slider window ------------------------------------------------------

ABMeleeSlider = ISCollapsableWindow:derive("ABMeleeSlider")

function ABMeleeSlider:new(x, y, width, height, parent)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o:setResizable(true)
    o.title = "part"
    o.parenta = parent
    o.baselenth = width / 20
    return o
end

function ABMeleeSlider:callback(value, slider)
    if not self.worldmodel then return end

    local list = { formatAxisValue(self.slider1.currentValue, 1), formatAxisValue(self.slider2.currentValue, 2),
                   formatAxisValue(self.slider3.currentValue, 3) }

    local weapon = getPlayer():getPrimaryHandItem()
    if weapon then
        local md = weapon:getModData()
        if not md.GunPos then md.GunPos = {} end
        if not md.GunPos[self.itempart] then md.GunPos[self.itempart] = { x = 0, y = 0, z = 0 } end
        md.GunPos[self.itempart].x = list[1]
        md.GunPos[self.itempart].y = list[2]
        md.GunPos[self.itempart].z = list[3]
    end

    -- Write the model-script attachment offset so the part sits correctly on the
    -- HELD weapon in the world (not just in the inspection scene).
    if self.itempartoffsetment then
        pcall(function() self.itempartoffsetment:getOffset():set(list[1], list[2], list[3]) end)
    end

    if self.parenta and self.parenta.scene and self.parenta.scene.javaObject and isUsableWorldModel(self.worldmodel) then
        self.parenta.scene.javaObject:fromLua4("setObjectPosition", self.worldmodel, list[1], list[2], list[3])
    end
end

function ABMeleeSlider:onReset()
    if not self.itempart then return end
    self.slider1.currentValue = 100
    self.slider2.currentValue = 300
    self.slider3.currentValue = 100
    self:callback(100, self.slider1)
end

function ABMeleeSlider:render()
    ISCollapsableWindow.render(self)
    local itemname = "None"
    local itemtexture = nil
    if self.itempart then
        local itemseed = ScriptManager.instance:getItem(self.itempart)
        if itemseed then
            local icon = itemseed:getIcon()
            itemtexture = getTexture("media/textures/Item_" .. icon .. ".png")
            itemname = itemseed:getDisplayName()
        end
    end
    if itemtexture then
        self:drawTextureScaled(itemtexture, self.baselenth * 3, self.baselenth * 3, self.width - self.baselenth * 12,
            self.width - self.baselenth * 12, 1.0, 1.0, 1.0, 1.0)
    end
    self:drawText(itemname, self.baselenth * 4, self.width - self.baselenth * 8, 1, 1, 1, 0.9, UIFont.Medium)
    local sliders = { self.slider1, self.slider2, self.slider3 }
    local offsets = { self.offsetX, self.offsetY, self.offsetZ }
    local labels = { "X", "Y", "Z" }
    for i, slider in ipairs(sliders) do
        local value = formatAxisValue(slider.currentValue, i)
        self:drawText(labels[i] .. ": " .. value, self.baselenth * 4, offsets[i], 1, 1, 1, 0.9, UIFont.Medium)
    end
end

function ABMeleeSlider:createChildren()
    ISCollapsableWindow.createChildren(self)
    local y = self.height / 2
    local x = self.baselenth
    local width = self.width - 2 * self.baselenth
    local height = 1.5 * self.baselenth

    local sliders = {}
    local offsets = {}
    for i = 1, 3 do
        local slider = ISSliderPanel:new(x, y, width, height, self, self.callback)
        slider:initialise()
        slider:instantiate()
        if i == 2 then
            slider:setValues(0, 600, 1, 10)
            slider.currentValue = 300
        else
            slider:setValues(0, 200, 1, 10)
            slider.currentValue = 100
        end
        self:addChild(slider)
        sliders[i] = slider
        offsets[i] = y + self.baselenth + height
        y = y + self.baselenth * 3 + height
    end
    self.slider1, self.slider2, self.slider3 = sliders[1], sliders[2], sliders[3]
    self.offsetX, self.offsetY, self.offsetZ = offsets[1], offsets[2], offsets[3]

    self.resetButton = ISButton:new(self.baselenth, self.height - self.baselenth * 3, self.width - self.baselenth * 2,
        self.baselenth * 2, "重置位置", self, self.onReset)
    self.resetButton:initialise()
    self.resetButton:instantiate()
    self:addChild(self.resetButton)
end

-- Main window -----------------------------------------------------------------

ABMeleeUI = ISPanel:derive("ABMeleeUI")

function ABMeleeUI:new(x, y, player)
    local o = ISPanel:new(x, y, WINDOW_W, WINDOW_H)
    setmetatable(o, self)
    self.__index = self
    o.player = player or getPlayer()
    o.weapon = nil
    o.lastSig = nil
    o.settingpanel = nil
    o.gunmodelCreated = false
    o.scene = nil
    o.backgroundColor = { r = 0.05, g = 0.05, b = 0.07, a = 1 }
    o.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 1 }
    o.resizable = false
    o.collapsable = false
    return o
end

function ABMeleeUI:partsSig(weapon)
    if not weapon or not ABMeleePartSystem.IsMeleeWeapon(weapon) then return "none" end
    local s = ""
    for _, sl in ipairs(ABMeleePartSystem.Slots) do
        local part = ABMeleePartSystem.GetPart(weapon, sl.key)
        s = s .. tostring(part and part:getFullType() or "") .. "|"
    end
    return s
end

function ABMeleeUI:createChildren()
    ISPanel.createChildren(self)

    self.scene = ABMeleeScene:new(SCENE_X, SCENE_Y, SCENE_W, SCENE_H)
    self.scene:initialise()
    self.scene:instantiate()
    self:addChild(self.scene)
    self.scene.javaObject:fromLua1("setDrawGrid", false)
    self.scene.javaObject:fromLua1("setDrawGridAxes", false)
    self.scene.javaObject:fromLua1("setMaxZoom", 100)
    self.scene.javaObject:fromLua1("setZoom", 15)
    self.scene.javaObject:fromLua2("dragView", -30, 30)
    self.scene:setView("UserDefined")

    local weapon = self.player:getPrimaryHandItem()
    self.gunmodelCreated = false
    local sprite = weapon and weapon:getWeaponSprite() or nil
    if sprite and sprite ~= "nil" and not string.find(sprite, "_0") then
        local model = ScriptManager.instance:getItem(weapon:getFullType()):getModuleName() .. "." .. sprite
        self.gunmodelCreated = pcall(function()
            self.scene.javaObject:fromLua2("createModel", "Gunmodel", model)
        end)
    end

    -- Wrench button -> position sliders.
    self.settingbutton = ISButton:new(12, 10, 40, 40, "", self, self.openSettingPanel)
    self.settingbutton:initialise()
    self.settingbutton:instantiate()
    self.settingbutton.borderColor = { r = 1, g = 1, b = 1, a = 0 }
    self:addChild(self.settingbutton)
    local itemseed = ScriptManager.instance:getItem("Base.Wrench") or ScriptManager.instance:getItem("Wrench")
    local icon = itemseed and itemseed:getIcon()
    local itemtexture = icon and getTexture("media/textures/Item_" .. icon .. ".png")
    if itemtexture then self.settingbutton:setImage(itemtexture) end

    -- Close button (MFS texture).
    self.closebutton = ISButton:new(self.width - 30, 6, 22, 22, "", self, self.onOptionMouseDown)
    self.closebutton.internal = "close"
    self.closebutton:initialise()
    self.closebutton:instantiate()
    self.closebutton.borderColor = { r = 1, g = 1, b = 1, a = 0 }
    self.closebutton:setImage(getTexture("media/textures/UI/EFK_Close.png"))
    self:addChild(self.closebutton)
end

function ABMeleeUI:onOptionMouseDown(button)
    if button.internal == "close" then
        self:close()
    end
end

function ABMeleeUI:openSettingPanel()
    if ABMeleeInspect.slider then
        ABMeleeInspect.slider:close()
        ABMeleeInspect.slider = nil
    end
    local width = 240
    self.settingpanel = ABMeleeSlider:new(self.x - width, self.y, width, self.height, self)
    self.settingpanel:initialise()
    self.settingpanel:addToUIManager()
    ABMeleeInspect.slider = self.settingpanel
end

function ABMeleeUI:positionPartModel(weapon, worldmodel, part, slotKey)
    local model = ScriptManager.instance:getModelScript("Base." .. weapon:getWeaponSprite())
    if not model then return end
    local attachment = getOrCreateAttachment(model, slotKey)
    local list = { 0, 0, 0 }
    if attachment and attachment:getOffset() then
        local offset = attachment:getOffset()
        list = { offset:x(), offset:y(), offset:z() }
    end
    local md = weapon:getModData()
    local gunPos = md.GunPos
    local saved = part and type(gunPos) == "table" and gunPos[part:getFullType()] or nil
    if type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number" and type(saved.z) == "number" then
        list[1] = saved.x
        list[2] = saved.y
        list[3] = saved.z
    end
    pcall(function()
        self.scene.javaObject:fromLua4("setObjectPosition", worldmodel, list[1], list[2], list[3])
    end)
end

function ABMeleeUI:updatePartModels(weapon)
    if not self.scene or not self.scene.javaObject then return end
    self.scene.partlist = self.scene.partlist or {}

    local wanted = {}
    for _, s in ipairs(ABMeleePartSystem.Slots) do
        local part = ABMeleePartSystem.GetPart(weapon, s.key)
        if part then
            local item = ScriptManager.instance:getItem(part:getFullType())
            if item then
                local worldmodel = item:getWorldStaticModel()
                if isUsableWorldModel(worldmodel) then
                    wanted[worldmodel] = { part = part, slot = s.key }
                end
            end
        end
    end

    for wm in pairs(self.scene.partlist) do
        if not wanted[wm] then
            self.scene.partlist[wm] = nil
            pcall(function() self.scene.javaObject:fromLua1("removeModel", wm) end)
        end
    end

    for wm, info in pairs(wanted) do
        if not self.scene.partlist[wm] then
            local ok = pcall(function() self.scene.javaObject:fromLua2("createModel", wm, wm) end)
            if ok then self.scene.partlist[wm] = true end
        end
        self:positionPartModel(weapon, wm, info.part, info.slot)
    end
end

function ABMeleeUI:renderInventory()
    if not self.javaObject then return end

    for _, child in ipairs(self:getChildrenInOrder() or {}) do
        if child and child.toolTip then
            child.toolTip:setVisible(false)
            child.toolTip:removeFromUIManager()
            child.toolTip = nil
        end
    end
    self:clearChildren()

    if self.settingpanel then
        self.settingpanel:close()
        self.settingpanel = nil
        ABMeleeInspect.slider = nil
    end

    local weapon = self.player:getPrimaryHandItem()
    self.weapon = weapon

    if not self.scene then
        self:createChildren()
    else
        self:addChild(self.scene)
        if self.settingbutton then self:addChild(self.settingbutton) end
        if self.closebutton then self:addChild(self.closebutton) end
    end

    self:updatePartModels(weapon)

    if weapon and ABMeleePartSystem.IsMeleeWeapon(weapon) then
        for i, s in ipairs(ABMeleePartSystem.Slots) do
            local part = ABMeleePartSystem.GetPart(weapon, s.key)
            local btn = ABSlotButton:new(SLOT_XS[i], SLOT_Y, SLOT_W, SLOT_H, part, weapon, s.key, s.label, self)
            btn:initialise()
            btn:instantiate()
            self:addChild(btn)
        end
    end

    self.lastSig = self:partsSig(weapon)
end

function ABMeleeUI:prerender()
    ISPanel.prerender(self)
    local bg = getTexture("media/textures/UI/EFK_BackGround.png")
    if bg then
        self:drawTextureScaled(bg, 0, 0, self.width, self.height, 1, 0.5, 0.5, 0.5)
    end
    local weapon = self.weapon
    if weapon and ABMeleePartSystem.IsMeleeWeapon(weapon) then
        local tex = weapon:getTexture()
        if tex then
            self:drawTextureScaled(tex, 16, 12, 56, 56, 1, 1, 1, 1)
        end
        self:drawText(weapon:getDisplayName(), 80, 20, 1, 1, 1, 1, UIFont.Medium)
    end
end

function ABMeleeUI:render()
    ISPanel.render(self)
    local weapon = self.weapon
    if not weapon or not ABMeleePartSystem.IsMeleeWeapon(weapon) then return end

    local sy = SCENE_Y + SCENE_H + 12
    for i, st in ipairs(STAT_LINES) do
        local col = i <= 5 and 0 or 1
        local row = (i - 1) % 5
        local v = weapon[st.get](weapon)
        if v ~= nil then
            self:drawText(st.label .. ": " .. string.format(st.fmt, v), SCENE_X + col * 400, sy + row * 20, 1, 1, 1, 1,
                UIFont.Small)
        end
    end
end

function ABMeleeUI:update()
    if not self:getIsVisible() then return end
    local weapon = self.player:getPrimaryHandItem()
    if not ABMeleePartSystem.IsMeleeWeapon(weapon) then
        self:close()
        return
    end
    local sig = self:partsSig(weapon)
    if weapon ~= self.weapon or sig ~= self.lastSig then
        self:renderInventory()
    end
end

function ABMeleeUI:close()
    ABMeleeInspect.close()
end

-- Open / close / toggle / refresh --------------------------------------------

function ABMeleeInspect.open(player)
    player = player or getPlayer()
    if not player then return end
    if ABMeleeInspect.window and ABMeleeInspect.window:getIsVisible() then
        return
    end

    local x, y = 100, 100
    local pos = player:getModData().ABInspectWindowPos
    if pos and pos[1] and pos[2] then
        x, y = pos[1], pos[2]
    end
    local core = getCore()
    if core then
        x = math.max(0, math.min(x, core:getScreenWidth() - 200))
        y = math.max(0, math.min(y, core:getScreenHeight() - 80))
    end

    local win = ABMeleeUI:new(x, y, player)
    ABMeleeInspect.window = win
    win:addToUIManager()
    win:renderInventory()
    win:bringToTop()
end

function ABMeleeInspect.close()
    local win = ABMeleeInspect.window
    if not win then return end
    local player = win.player or getPlayer()
    if player then
        player:getModData().ABInspectWindowPos = { win:getX(), win:getY() }
    end
    if ABMeleeInspect.selectPane then
        ABMeleeInspect.selectPane:close()
        ABMeleeInspect.selectPane = nil
    end
    if ABMeleeInspect.slider then
        ABMeleeInspect.slider:close()
        ABMeleeInspect.slider = nil
    end
    win:setVisible(false)
    win:removeFromUIManager()
    ABMeleeInspect.window = nil
end

function ABMeleeInspect.toggle()
    if ABMeleeInspect.window and ABMeleeInspect.window:getIsVisible() then
        ABMeleeInspect.close()
    else
        ABMeleeInspect.open()
    end
end

function ABMeleeInspect.refresh()
    local win = ABMeleeInspect.window
    if win and win:getIsVisible() then
        win:renderInventory()
    end
end

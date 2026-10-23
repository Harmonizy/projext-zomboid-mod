-- @author Risky
-- Custom buttons for UI on windows/panels
require "ISUI/ISButton"
require "ISUI/ISPanel"
require "TimedActions/ISInventoryTransferAction"

-- Ammo boxing/unboxing. Clicking the loose-ammo slot boxes loose bullets
-- (loose -> box); clicking the boxed-ammo slot opens the box (box -> loose).
-- Recipes are located by scanning (source -> result) item types and cached, so
-- every calibre works without hardcoding recipe names or box sizes.

local ammoRecipeCache = {}

local function findAmmoRecipe(playerObj, srcType, resultType)
    if not playerObj or not srcType or not resultType then return nil end
    local key = tostring(srcType) .. ">" .. tostring(resultType)
    local cached = ammoRecipeCache[key]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local found = nil
    local srcItem = instanceItem(srcType)
    local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
    if srcItem and containers then
        local recipes = RecipeManager.getUniqueRecipeItems(srcItem, playerObj, containers)
        if recipes then
            for i = 1, recipes:size() do
                local recipe = recipes:get(i - 1)
                if recipe and recipe:getResult() and recipe:getResult():getFullType() == resultType then
                    if recipe:findSource(srcType) then
                        found = recipe
                        break
                    end
                end
            end
        end
    end

    ammoRecipeCache[key] = found or false
    return found
end

local function findActualItemByType(playerObj, fullType)
    if not playerObj or not fullType then return nil end
    local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
    if not containers then return nil end
    for i = 0, containers:size() - 1 do
        local container = containers:get(i)
        if container then
            local items = container:getItems()
            for j = 0, items:size() - 1 do
                local item = items:get(j)
                if item and item:getFullType() == fullType then
                    return item
                end
            end
        end
    end
    return nil
end

function predicateNotBroken(item)
    return not item:isBroken()
end

ammoButton = ISButton:derive("ammoButton")

function ammoButton:new(x, y, w, h, slotItem, stackAmount, role, looseType, boxType)
    local o = {}
    o = ISButton:new(x, y, w, h)

    setmetatable(o, self)
    self.__index = self

    o.stackAmount = stackAmount
    o.role = role
    o.looseType = looseType
    o.boxType = boxType

    o.currentTint = ImmutableColor.new(1.0, 1.0, 1.0, 1.0)

    o.borderColor.r = 1
    o.borderColor.g = 1
    o.borderColor.b = 0.0
    o.borderColor.a = 0.5

    o.backgroundColor.r = 0.5
    o.backgroundColor.g = 0.5
    o.backgroundColor.b = 0.5
    o.backgroundColor.a = 0.3

    o.backgroundColorMouseOver.r = 0.5
    o.backgroundColorMouseOver.g = 0.5
    o.backgroundColorMouseOver.b = 0.5
    o.backgroundColorMouseOver.a = 0.3

    if slotItem then
        o.backgroundColorMouseOver.a = 0.8
        o.toolTip = ISToolTipInv:new(slotItem)
        o.toolTip:setOwner(o)
        o.toolTip:setVisible(false)
        o.toolTip:addToUIManager()

        -- Texture related
        o:setImage(slotItem:getTexture())

        local visual = slotItem:getVisual()
        o.tint = nil
        if visual then
            o.tint = visual:getTint(slotItem:getClothingItem())
            o.currentTint = visual:getTint(slotItem:getClothingItem())
        end

        if o.tint ~= nil then
            o:setTextureRGBA(o.tint:getRedFloat(), o.tint:getGreenFloat(), o.tint:getBlueFloat(), 1.0)
        end

        o.slotItem = slotItem
    end

    o:bringToTop();

    return o
end

function ammoButton:render()
    ISButton.render(self)

    if self.slotItem then
        self:drawText(tostring(self.stackAmount), 4, 0, 1.0, 1.0, 1.0, 1.0)

        -- Texture related
        self:setImage(self.slotItem:getTexture())

        if self.currentTint ~= nil then
            self:setTextureRGBA(self.currentTint:getRedFloat(), self.currentTint:getGreenFloat(),
                self.currentTint:getBlueFloat(), self.currentTint:getAlphaFloat())
        end

        -- if self:isMouseOver() then
        --     self.toolTip:setVisible(true)
        --     self.toolTip:bringToTop()
        -- else
        --     self.toolTip:setVisible(false)
        -- end
    end
end

function ammoButton:close()
    if self.toolTip then
        self.toolTip:setVisible(false)
        self.toolTip:removeFromUIManager()
        self.toolTip = nil
    end
    ISButton.close(self)
end

function ammoButton:onMouseDown(x, y)
    ISButton.onMouseDown(self, x, y)
    if not self.role then return end

    local playerObj = getPlayer()
    if not playerObj then return end

    local recipe = nil
    local item = nil
    if self.role == "loose" then
        -- Box the loose bullets (loose -> box).
        recipe = findAmmoRecipe(playerObj, self.looseType, self.boxType) or
            getScriptManager():getCraftRecipe("place_ammo_in_box")
        item = findActualItemByType(playerObj, self.looseType)
    elseif self.role == "box" then
        -- Open the box of bullets (box -> loose). Vanilla boxes carry a
        -- DoubleClickRecipe; custom calibres are located by scanning.
        local recipeName = self.slotItem and self.slotItem:getDoubleClickRecipe() or nil
        recipe = recipeName and getScriptManager():getCraftRecipe(recipeName) or nil
        if not recipe then
            recipe = findAmmoRecipe(playerObj, self.boxType, self.looseType)
        end
        item = findActualItemByType(playerObj, self.boxType)
    end

    if recipe and item and ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.OnNewCraft then
        ISInventoryPaneContextMenu.OnNewCraft(item, recipe, playerObj:getPlayerNum())
    end
end

-- Repair Button (repairs the held weapon back to full condition)

repairButton = ISButton:derive("repairButton")

function repairButton:new(x, y, w, h, slotItem, weapon)
    local o = {}
    o = ISButton:new(x, y, w, h)

    setmetatable(o, self)
    self.__index = self

    o.weapon = weapon
    o.currentTint = ImmutableColor.new(1.0, 1.0, 1.0, 1.0)

    -- Same frame as ammoButton (boxAmmo) so the repair slot lines up with the ammo slots.
    o.borderColor.r = 1
    o.borderColor.g = 1
    o.borderColor.b = 0.0
    o.borderColor.a = 0.5

    o.backgroundColor.r = 0.5
    o.backgroundColor.g = 0.5
    o.backgroundColor.b = 0.5
    o.backgroundColor.a = 0.3

    o.backgroundColorMouseOver.r = 0.5
    o.backgroundColorMouseOver.g = 0.5
    o.backgroundColorMouseOver.b = 0.5
    o.backgroundColorMouseOver.a = 0.8

    if slotItem then
        o.toolTip = ISToolTipInv:new(slotItem)
        o.toolTip:setOwner(o)
        o.toolTip:setVisible(false)
        o.toolTip:addToUIManager()

        o.itemTexture = slotItem:getTexture()
        if not o.itemTexture then
            local icon = slotItem:getIcon()
            if icon then o.itemTexture = getTexture("media/textures/Item_" .. icon .. ".png") end
        end
        if o.itemTexture then o:setImage(o.itemTexture) end

        o.slotItem = slotItem
    end

    o:bringToTop()

    return o
end

function repairButton:render()
    ISButton.render(self)

    if self.itemTexture then
        self:setImage(self.itemTexture)
    end
end

function repairButton:onMouseDown(x, y)
    ISButton.onMouseDown(self, x, y)

    if self.weapon and self.weapon.getConditionMax then
        self.weapon:setCondition(self.weapon:getConditionMax())
        getSoundManager():PlayWorldSound("WeaponPartInsertSound", getPlayer():getSquare(), 0, 0, 0, false)
        if riskyInspectWindow and riskyInspectWindow:getIsVisible() then
            riskyInspectWindow:renderInventory()
        end
    end
end

-- Repair Kit Button (restores the held gun to full condition and consumes one
-- Base.gongjvxiuli_cat from the player's main backpack).

repairKitButton = ISButton:derive("repairKitButton")

function repairKitButton:new(x, y, w, h, slotItem, weapon)
    local o = {}
    o = ISButton:new(x, y, w, h)

    setmetatable(o, self)
    self.__index = self

    o.weapon = weapon
    o.currentTint = ImmutableColor.new(1.0, 1.0, 1.0, 1.0)

    -- Same gold frame as the ammo buttons.
    o.borderColor.r = 1
    o.borderColor.g = 1
    o.borderColor.b = 0.0
    o.borderColor.a = 0.5

    o.backgroundColor.r = 0.5
    o.backgroundColor.g = 0.5
    o.backgroundColor.b = 0.5
    o.backgroundColor.a = 0.3

    o.backgroundColorMouseOver.r = 0.5
    o.backgroundColorMouseOver.g = 0.5
    o.backgroundColorMouseOver.b = 0.5
    o.backgroundColorMouseOver.a = 0.8

    if slotItem then
        o.itemTexture = slotItem:getTexture()
        if not o.itemTexture then
            local icon = slotItem:getIcon()
            if icon then o.itemTexture = getTexture("media/textures/Item_" .. icon .. ".png") end
        end
        if o.itemTexture then o:setImage(o.itemTexture) end
        o.slotItem = slotItem
    end

    o:bringToTop()
    return o
end

function repairKitButton:getRepairKitCount()
    local inv = getPlayer() and getPlayer():getInventory()
    if not inv then return 0 end
    return inv:getItemCount("Base.gongjvxiuli_cat")
end

function repairKitButton:render()
    ISButton.render(self)

    if self.itemTexture then
        self:setImage(self.itemTexture)
    end

    local count = self:getRepairKitCount()
    if count > 0 then
        self:drawText(tostring(count), 4, 0, 1.0, 1.0, 1.0, 1.0)
    end
end

function repairKitButton:onMouseDown(x, y)
    ISButton.onMouseDown(self, x, y)

    if not self.weapon or not self.weapon.getConditionMax then return end
    if self.weapon:getCondition() >= self.weapon:getConditionMax() then return end

    local player = getPlayer()
    local inv = player:getInventory()
    local items = inv:getItems()
    local kit = nil
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it:getFullType() == "Base.gongjvxiuli_cat" then
            kit = it
            break
        end
    end
    if not kit then return end

    -- Timed action so the condition restore + kit consumption are synced to
    -- the server in multiplayer. The UI count refreshes automatically when the
    -- action completes and the inventory/condition change is detected.
    ISTimedActionQueue.add(RepairKitAction:new(player, self.weapon, kit, 50))
end

-- Attachment Button

attachmentButton = ISButton:derive("attachmentButton")

function attachmentButton:new(x, y, w, h, slotItem, attachingTo, attachmentType)
    local o = {}
    o = ISButton:new(x, y, w, h)

    setmetatable(o, self)
    self.__index = self

    o.currentTint = ImmutableColor.new(1.0, 1.0, 1.0, 1.0)

    o.borderColor.r = 0.0
    o.borderColor.g = 1
    o.borderColor.b = 0.0
    o.borderColor.a = 0.5

    o.backgroundColor.r = 0.5
    o.backgroundColor.g = 0.5
    o.backgroundColor.b = 0.5
    o.backgroundColor.a = 0.3

    o.backgroundColorMouseOver.r = 0.5
    o.backgroundColorMouseOver.g = 0.5
    o.backgroundColorMouseOver.b = 0.5
    o.backgroundColorMouseOver.a = 0.8

    o.attachingTo = attachingTo
    o.attachmentType = attachmentType
    if attachmentType == "ClipType" then
        o.ClipType = "ClipType"
    elseif attachmentType == "WeaponAttackType" then
        o.AttackModeType = "WeaponAttackType"
    elseif attachmentType == "Skin" then
        o.SkinType = "Skin"
    else
        o.attachmentType = attachmentType
    end

    if slotItem then
        -- o.toolTip = ISToolTip:new();
        -- o.toolTip.description = getText("Tooltip_DoubleClickToRemove")
        -- o.toolTip:setVisible(false)
        -- o.toolTip:addToUIManager()

        -- Texture related
        o:setImage(slotItem:getTexture())

        local visual = slotItem:getVisual()
        o.tint = nil
        if visual then
            o.tint = visual:getTint(slotItem:getClothingItem())
            o.currentTint = visual:getTint(slotItem:getClothingItem())
        end

        if o.tint ~= nil then
            o:setTextureRGBA(o.tint:getRedFloat(), o.tint:getGreenFloat(), o.tint:getBlueFloat(), 1.0)
        end

        o.slotItem = slotItem
    end

    o:bringToTop();

    return o
end

function attachmentButton:render()
    ISButton.render(self)

    if self.slotItem then
        -- Texture related
        self:setImage(self.slotItem:getTexture())

        if self.currentTint ~= nil then
            self:setTextureRGBA(self.currentTint:getRedFloat(), self.currentTint:getGreenFloat(),
                self.currentTint:getBlueFloat(), self.currentTint:getAlphaFloat())
        end

        -- if self:isMouseOver() then
        --     self.toolTip:setVisible(true)
        --     self.toolTip:bringToTop()
        -- else
        --     self.toolTip:setVisible(false)
        -- end
        self.borderColor.r = 0
        self.borderColor.g = 0.8
        self.borderColor.b = 0
        self.borderColor.a = 0.5
    else
        self.borderColor.r = 0.8
        self.borderColor.g = 0
        self.borderColor.b = 0
        self.borderColor.a = 0.5
    end
end

function attachmentButton:onMouseDoubleClick()
    if self.slotItem and self.ClipType ~= "ClipType" and self.AttackModeType ~= "WeaponAttackType" and self.SkinType ~=
        "Skin" then
        -- self.attachingTo:getModData().weaponpart[self.attachmentType] = nil
        ISTimedActionQueue.add(ISRemoveWeaponUpgrade:new(getPlayer(), self.attachingTo, self.slotItem:getPartType(), 1))
        getSoundManager():PlayWorldSound("WeaponPartInsertSound", getPlayer():getSquare(), 0, 0, 0, false);
        -- addSound(getPlayer(), getPlayer():getX(), getPlayer():getY(), getPlayer():getZ(), 0, 0);
        -- AWCWF_Attach.Apply_Effect(getPlayer(), self.attachingTo)
        -- self.toolTip:setVisible(false)
        -- self.toolTip:removeFromUIManager()
    end

end

function attachmentButton:onMouseUp()
    if self.slotItem == nil then

        local pane = selectAttachmentPane:new(riskyInspectWindow:getX() + self:getX() + 43,
            riskyInspectWindow:getY() + self:getY() - 3, self.attachmentType)
        pane:addToUIManager()
        pane:bringToTop()

    elseif self.ClipType == "ClipType" then
        local pane = selectAttachmentPane:new(riskyInspectWindow:getX() + self:getX() + 43,
            riskyInspectWindow:getY() + self:getY() - 3, self.attachmentType, self.ClipType, self.AttackModeType,
            self.SkinType)
        pane:addToUIManager()
        pane:bringToTop()
    elseif self.AttackModeType == "WeaponAttackType" then
        local pane = selectAttachmentPane:new(riskyInspectWindow:getX() + self:getX() + 43,
            riskyInspectWindow:getY() + self:getY() - 3, self.attachmentType, self.ClipType, self.AttackModeType,
            self.SkinType)
        pane:addToUIManager()
        pane:bringToTop()
    elseif self.SkinType == "Skin" then
        local pane = selectAttachmentPane:new(riskyInspectWindow:getX() + self:getX() + 43,
            riskyInspectWindow:getY() + self:getY() - 3, self.attachmentType, self.ClipType, self.AttackModeType,
            self.SkinType)
        pane:addToUIManager()
        pane:bringToTop()
    end
end
-- MFS Patch 5: the original getJavaFieldNum() helper was removed.
-- It used getNumClassFields()/getClassField()/getClassFieldVal() to read the
-- private "worldStaticModel" field of the item script by reflection. In B42.20
-- those three functions are DEBUG-ONLY: LuaManager.validateReflectionAccess()
-- throws IllegalStateException("Not in debug") outside debug mode, so
-- getNumClassFields() returns nothing, "nil - 1" then throws
--     "__sub not defined for operands in getJavaFieldNum"
-- and onMouseDown aborts BEFORE extrapanel.itempart is assigned. Result: the
-- wrench panel opens but clicking a part shows a red error and the sliders
-- never bind to anything.
-- ScriptItem exposes the same value through the public getter
-- item:getWorldStaticModel(), already used by risky_inspect_core.lua (lines
-- 423/439/586/596) and Weapon_Inspect_Render.lua:168 on the identical object.
-- Same value, no reflection, works outside debug.
function attachmentButton:onMouseDown(x, y)
    ISButton.onMouseDown(self, x, y)

    -- print(self.slotItem:getFullType())

    local extrapanel = self.parent.settingpanel
    if extrapanel and self.slotItem then

        local item = ScriptManager.instance:getItem(self.slotItem:getFullType())
        if item then
            -- MFS Patch 5: public getter instead of debug-only reflection. See note above.
            local worldmodel = item:getWorldStaticModel()

            local held = getPlayer():getPrimaryHandItem()
            if not held or not held.getWeaponSprite then return end
            local modelscript = "Base." .. held:getWeaponSprite()
            local model = ScriptManager.instance:getModelScript(modelscript)

            -- print(self.slotItem:getPartType())
            -- print(model)
            if model and worldmodel and instanceof(self.slotItem, "WeaponPart") then
                local attachment0 = model:getAttachmentById(self.slotItem:getPartType())

                if not attachment0 then
                    attachment0 = ModelAttachment.new(self.slotItem:getPartType())
                    model:addAttachment(attachment0)
                end

                if attachment0 then
                    local offset = attachment0:getOffset()

                    extrapanel.itempart = self.slotItem:getFullType()

                    -- print(extrapanel.itempart)
                    extrapanel.worldmodel = worldmodel
                    -- local list = offset

                    extrapanel.itempartoffset = offset
                    extrapanel.itempartoffsetment = attachment0
                    extrapanel.modelscript = model
                    extrapanel.modelscriptd = held:getWeaponSprite()
                    local Gun = held
                    local ModData = Gun:getModData().GunPos
                    if not ModData then
                        ModData = {}
                        Gun:getModData().GunPos = ModData
                    end
                    if not ModData[extrapanel.itempart] then
                        ModData[extrapanel.itempart] = {}
                        ModData[extrapanel.itempart].x = 0
                        ModData[extrapanel.itempart].y = 0
                        ModData[extrapanel.itempart].z = 0
                        if MFS_GunPosChanged then
                            MFS_GunPosChanged(Gun)
                        end
                    end
                    extrapanel.slider1.currentValue = ModData[extrapanel.itempart].x / 0.001 + 100
                    extrapanel.slider2.currentValue = ModData[extrapanel.itempart].y / 0.001 + 300
                    extrapanel.slider3.currentValue = ModData[extrapanel.itempart].z / 0.001 + 100
                    -- MFS RC6: match the handgun Z convention used in riskyUI_slider:callback.
                    local heldZ = ModData[extrapanel.itempart].z
                    if Gun and Gun:getSwingAnim() == "Handgun" then
                        heldZ = -heldZ
                    end
                    attachment0:getOffset():set(ModData[extrapanel.itempart].x, ModData[extrapanel.itempart].y,
                        heldZ)

                    -- MFS RC6: also place the part in the inspection scene. Without this the
                    -- sliders show the saved value while the 3D preview still shows the
                    -- model-script default, because only the slider callback ever set the
                    -- scene position. The scene uses the RAW z (no handgun negation).
                    -- MFS Patch 5: javaObject is only present once the scene has been
                    -- created by the renderer; guard it so a click during window
                    -- setup cannot abort this handler.
                    if extrapanel.parenta and extrapanel.parenta.scene and
                        extrapanel.parenta.scene.javaObject and worldmodel and
                        not string.find(worldmodel, "nil") and worldmodel ~= "Base.Gun_Magazine_Ground" then
                        extrapanel.parenta.scene.javaObject:fromLua4("setObjectPosition", worldmodel,
                            ModData[extrapanel.itempart].x, ModData[extrapanel.itempart].y,
                            ModData[extrapanel.itempart].z)
                    end
                    -- local vector = self.scene.javaObject:fromLua4("setObjectPosition", worldmodel,list[1],list[2],list[3])

                end
            end
        end

    end

end

function attachmentButton:close()
    self.toolTip:setVisible(false)
    self.toolTip:removeFromUIManager()
    ISButton.close(self)
end

-- Add Attachment Button

addAttachmentButton = ISButton:derive("addAttachmentButton")

function addAttachmentButton:new(x, y, w, h, slotItem, attachingTo, enabled, type)
    local o = {}
    o = ISButton:new(x, y, w, h)

    setmetatable(o, self)
    self.__index = self

    o.enabled = enabled
    o.type = type
    o.borderColor.r = 0.0
    o.borderColor.g = 0.0
    o.borderColor.b = 0.0
    o.borderColor.a = 0.0

    o.backgroundColor.r = 0.5
    o.backgroundColor.g = 0.5
    o.backgroundColor.b = 0.5
    o.backgroundColor.a = 0.3

    o.backgroundColorMouseOver.r = 0.5
    o.backgroundColorMouseOver.g = 0.5
    o.backgroundColorMouseOver.b = 0.5

    if enabled then
        o.backgroundColorMouseOver.a = 0.8
        o.currentTint = ImmutableColor.new(1.0, 1.0, 1.0, 1.0)
    else
        o.backgroundColorMouseOver.a = 0.3
        o.currentTint = ImmutableColor.new(1.0, 1.0, 1.0, 0.3)
    end

    o.attachingTo = attachingTo

    if slotItem then
        o.toolTip = ISToolTipInv:new(slotItem)
        o.toolTip:setOwner(o)
        o.toolTip:setVisible(false)
        o.toolTip:addToUIManager()

        -- Texture related
        o:setImage(slotItem:getTexture())

        local visual = slotItem:getVisual()
        o.tint = nil
        if visual then
            o.tint = visual:getTint(slotItem:getClothingItem())
            o.currentTint = visual:getTint(slotItem:getClothingItem())

            if not enabled then
                o.currentTint.a = 0.3
            end
        end

        if o.tint ~= nil then
            if enabled then
                o:setTextureRGBA(o.tint:getRedFloat(), o.tint:getGreenFloat(), o.tint:getBlueFloat(), 1.0)
            else
                o:setTextureRGBA(o.tint:getRedFloat(), o.tint:getGreenFloat(), o.tint:getBlueFloat(), 0.3)
            end
        end

        o.slotItem = slotItem
    end

    o:bringToTop();

    return o
end

function addAttachmentButton:render()
    ISButton.render(self)

    if self.slotItem then
        -- Texture related
        self:setImage(self.slotItem:getTexture())

        if self.currentTint ~= nil then
            self:setTextureRGBA(self.currentTint:getRedFloat(), self.currentTint:getGreenFloat(),
                self.currentTint:getBlueFloat(), self.currentTint:getAlphaFloat())
        end

        if self:isMouseOver() then
            self.toolTip:setVisible(true)
            self.toolTip:bringToTop()
        else
            self.toolTip:setVisible(false)
        end
    end
end

function addAttachmentButton:onMouseDown()
    if self.slotItem and self.enabled then
        if self.type == "WeaponPart" then
            -- A part scanned from a nearby container (crate, floor bag, ...) is not
            -- yet in the player's inventory, and ISUpgradeWeapon:isValid() requires
            -- it there. Transfer it in first, then attach.
            local player = getPlayer()
            local part = self.slotItem
            local srcContainer = part:getContainer()
            if srcContainer and srcContainer ~= player:getInventory() then
                ISTimedActionQueue.add(ISInventoryTransferAction:new(player, part, srcContainer,
                    player:getInventory()))
            end
            ISTimedActionQueue.add(ISUpgradeWeapon:new(player, self.attachingTo, part, 1));
            ISTimedActionQueue.add(ISEquipWeaponAction:new(player, self.attachingTo, 1, true,
                self.attachingTo:isTwoHandWeapon()))

        elseif self.type == "ClipType" then
            ChangeMagzine(getPlayer(), self.attachingTo, self.slotItem:getType(), nil, true)
        elseif self.type == "WeaponAttackType" then
            -- print(self.slotItem:getType())
            SetWeaponAttackType(self.attachingTo, self.slotItem:getType())
            riskyInspectWindow:renderInventory()
        elseif self.type == "Skin" then
            ChangeWeaponSkin(getPlayer(), self.attachingTo, self.slotItem)
            riskyInspectWindow:renderInventory()
        end
        getSoundManager():PlayWorldSound("WeaponPartInsertSound", getPlayer():getSquare(), 0, 0, 0, false);
    end
end

function addAttachmentButton:close()
    ISButton.close(self)
    self.toolTip:setVisible(false)
    self.toolTip:removeFromUIManager()
end

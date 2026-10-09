-- SELECT ATTACHMENT PANE
selectAttachmentPane = ISPanel:derive("selectAttachmentPane")
function selectAttachmentPane:new(x, y, category, ClipType, AttackModeType, SkinType)
    -- Replace any previously-open selection pane instead of stacking invisible
    -- panes (and their tooltips) in the global UI manager.
    if selectAttachmentPane.current then
        selectAttachmentPane.current:close()
    end

    local o = {}
    o = ISPanel:new(x, y, 40 * 5 + 20, 126);
    setmetatable(o, self)
    self.__index = self
    o.ClipType = ClipType
    o.AttackModeType = AttackModeType
    o.SkinType = SkinType
    o.category = category
    o.backgroundColor = {
        r = 0,
        g = 0,
        b = 0,
        a = 1
    };
    o.borderColor = {
        r = 0.9,
        g = 0.9,
        b = 0.9,
        a = 0.7
    };
    o.currentPrimaryItem = getPlayer():getPrimaryHandItem()
    o.elements = {}
    if (riskyShowPotentialAttachment) then
        o.potentialAttachment = {}
        local items = getAllItems();
        for i = 0, items:size() - 1 do
            local item = items:get(i);
            if item and not item:getObsolete() and not item:isHidden() and item:getItemType() and item:getItemType():toString() == "base:weaponpart" then
                o.potentialAttachment[item:getFullName()] = 1
            end
        end
    end
    selectAttachmentPane.current = o
    return o
end
function selectAttachmentPane:prerender()
    self:setStencilRect(0, 0, self.width, self.height);
    self:drawRect(-self:getXScroll(), -self:getYScroll(), self.width, self.height, self.backgroundColor.a,
        self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
end
function selectAttachmentPane:render()
    self:clearStencilRect();
    self:drawRectBorder(-self:getXScroll(), -self:getYScroll(), self.width, self.height, self.borderColor.a,
        self.borderColor.r, self.borderColor.g, self.borderColor.b);
end
function selectAttachmentPane:createChildren()
    self:addScrollBars(false)
    self:setScrollWithParent(false)
    self:setScrollChildren(true)
end
function selectAttachmentPane:onMouseWheel(del)
    self:setYScroll(self:getYScroll() - (del * 42))
    return true;
end
function selectAttachmentPane:update()
    if self and self:getIsVisible() then
        if (self.currentPrimaryItem ~= getPlayer():getPrimaryHandItem() or riskyInspectWindow == nil) then
            self:close()
        end
        if self.itemCap ~= getPlayer():getInventory():getItems():size() or self.itemWeight ~=
            getPlayer():getInventory():getCapacityWeight() then
            self.itemCap = getPlayer():getInventory():getItems():size()
            self.itemWeight = getPlayer():getInventory():getCapacityWeight()
            self:renderInventory()
        end
    end
end
local magazineTypeCache = {}

local function getItemTag(resourceName)
    local ok, tag = pcall(function()
        return ItemTag.get(ResourceLocation.of(resourceName))
    end)
    return ok and tag or nil
end

local GUN_MAGAZINE_TAG
local GUN_DRUM_TAG

local function isMagazineItem(item)
    if not item or instanceof(item, "HandWeapon") or item:IsWeapon() then
        return false
    end
    GUN_MAGAZINE_TAG = GUN_MAGAZINE_TAG or getItemTag("base:gunmagazine")
    GUN_DRUM_TAG = GUN_DRUM_TAG or getItemTag("base:gundrum")
    if (GUN_MAGAZINE_TAG and item:hasTag(GUN_MAGAZINE_TAG))
        or (GUN_DRUM_TAG and item:hasTag(GUN_DRUM_TAG)) then
        return true
    end
    -- Fallback for magazines that lack the MFS tag: any non-weapon that carries
    -- an AmmoType and a positive magazine capacity is a magazine.
    local maxAmmo = item:getMaxAmmo()
    return maxAmmo ~= nil and maxAmmo > 0 and item:getAmmoType() ~= nil
end

-- Collect every magazine item that fires the same ammunition as the weapon, so
-- a gun can mount any magazine/drum of its calibre (e.g. a 9mm gun accepts the
-- 17-round mag, the 30-round mag and the 50-round drum) instead of only its
-- default magazine type.
local function getSameAmmoMagazineTypes(weapon)
    local ammoType = weapon:getAmmoType()
    if not ammoType then
        return {}
    end
    local ammoKey = ammoType:getItemKey()
    if not ammoKey then
        return {}
    end

    local cached = magazineTypeCache[ammoKey]
    if cached then
        return cached
    end

    local list = {}
    local seen = {}
    local items = getAllItems()
    if items then
        for i = 0, items:size() - 1 do
            local script = items:get(i)
            if script and not script:getObsolete() and not script:isHidden() then
                local ok, mag = pcall(instanceItem, script:getFullName())
                if ok and mag and isMagazineItem(mag) then
                    local mAmt = mag:getAmmoType()
                    if mAmt and mAmt:getItemKey() == ammoKey then
                        local fullType = mag:getFullType()
                        if fullType and not seen[fullType] then
                            seen[fullType] = true
                            list[#list + 1] = fullType
                        end
                    end
                end
            end
        end
    end

    magazineTypeCache[ammoKey] = list
    return list
end

function selectAttachmentPane:renderInventory()
    -- clearChildren() detaches the buttons but leaves each addAttachmentButton's
    -- top-level ISToolTipInv in the global UI manager. Remove those first so the
    -- pane does not accumulate tooltips across inventory-driven redraws.
    for _, child in ipairs(self:getChildrenInOrder() or {}) do
        if child and child.toolTip then
            child.toolTip:setVisible(false)
            child.toolTip:removeFromUIManager()
            child.toolTip = nil
        end
    end
    self:clearChildren()
    self.elements = {}

    local weapon = getPlayer():getPrimaryHandItem()
    if getPlayer():getPrimaryHandItem() ~= nil and getPlayer():getPrimaryHandItem():IsWeapon() then
        local alreadyDoneList = {};
        local itemNum = 0
        local rowCount = -1
        -- B42.20: scanParts recurses into equipped containers so parts stored in
        -- backpacks/vests are listed too, not just the top-level inventory.
        -- Parts inside every reachable container (crates, floor bags, ...) are
        -- scanned too, so attachments can be pulled from storage around the player.
        local partResult = {}
        local visited = {}
        for _, container in ipairs(getReachableContainers(getPlayer())) do
            scanParts(container, getPlayer(), weapon, self.category, partResult, visited)
        end
        for _, part in ipairs(partResult) do
            if not alreadyDoneList[part:getName()] then
                alreadyDoneList[part:getName()] = true;
                if (math.fmod(itemNum, 5) == 0) then
                    rowCount = rowCount + 1
                end
                local x = 2 + 41 * math.fmod(itemNum, 5)
                local y = 2 + 41 * rowCount
                if riskyShowPotentialAttachment then
                    self.potentialAttachment[part:getFullType()] = nil
                end
                local item = addAttachmentButton:new(x, y, 40, 40, part, weapon, true, "WeaponPart")
                table.insert(self.elements, item)
                item:bringToTop()
                self:addChild(item)
                itemNum = itemNum + 1
            end
        end
        if self.ClipType == "ClipType" then
            local magazineTypes = getSameAmmoMagazineTypes(weapon)
            for j = 1, #magazineTypes do
                local TempPart = instanceItem(magazineTypes[j])
                if TempPart and not alreadyDoneList[TempPart:getFullType()] then
                    alreadyDoneList[TempPart:getFullType()] = true
                    if (math.fmod(itemNum, 5) == 0) then
                        rowCount = rowCount + 1
                    end
                    local x = 2 + 41 * math.fmod(itemNum, 5)
                    local y = 2 + 41 * rowCount
                    local magazineButton = addAttachmentButton:new(x, y, 40, 40, TempPart, weapon, true, "ClipType")
                    magazineButton:bringToTop()
                    self:addChild(magazineButton)
                    itemNum = itemNum + 1
                end
            end
        end
        if self.SkinType == "Skin" then
            if CatWeaponSkin[weapon:getType()] then
                local SkinTableNow = CatWeaponSkin[weapon:getType()]
                for j = 1, #SkinTableNow do
                    if (math.fmod(itemNum, 5) == 0) then
                        rowCount = rowCount + 1
                    end
                    local x = 2 + 41 * math.fmod(itemNum, 5)
                    local y = 2 + 41 * rowCount
                    local SkinItem = instanceItem("Gunpart." .. SkinTableNow[j]);
                    if getPlayer():isRecipeKnown(SkinTableNow[j]) or j == 1 then
                        item = addAttachmentButton:new(x, y, 40, 40, SkinItem, weapon, true, "Skin")
                    else
                        item = addAttachmentButton:new(x, y, 40, 40, SkinItem, weapon, false, "Skin")
                    end
                    item:bringToTop()
                    self:addChild(item)
                    x = x + 41
                end
            end
        end
        if self.AttackModeType == "WeaponAttackType" then
            if AWCWF_WeaponAttackType[weapon:getType()] then
                local AttackTableNow = AWCWF_WeaponAttackType[weapon:getType()]
                for j = 1, #AttackTableNow do
                    local AttackTypeItem = instanceItem(AttackTableNow[j]);
                    local needflag = false
                    local CreatFlag = true
                    if string.find(weapon:getType(), "Brynhild") then
                        needflag = true
                    end
                    if needflag then
                        if not getPlayer():getInventory():contains(AttackTableNow[j]) then
                            CreatFlag = false
                        end
                    end
                    if (math.fmod(itemNum, 5) == 0) then
                        rowCount = rowCount + 1
                    end
                    local x = 2 + 41 * math.fmod(itemNum, 5)
                    local y = 2 + 41 * rowCount
                    if AttackTypeItem and CreatFlag then
                        item = addAttachmentButton:new(x, y, 40, 40, AttackTypeItem, weapon, true, "WeaponAttackType")
                        item:bringToTop()
                        self:addChild(item)
                        x = x + 41
                    end
                end
            end
        end
        if riskyShowPotentialAttachment then
            for k, v in pairs(self.potentialAttachment) do
                local potentialPart = instanceItem(k)
                if potentialPart:getMountOn():contains(weapon:getFullType()) and potentialPart:getPartType() ==
                    self.category then
                    if (math.fmod(itemNum, 5) == 0) then
                        rowCount = rowCount + 1
                    end
                    local x = 2 + 41 * math.fmod(itemNum, 5)
                    local y = 2 + 41 * rowCount
                    local item = addAttachmentButton:new(x, y, 40, 40, potentialPart, weapon, false, "WeaponPart")
                    table.insert(self.elements, item)
                    item:bringToTop()
                    self:addChild(item)
                    itemNum = itemNum + 1
                end
            end
        end
        self:setScrollHeight(42 * (rowCount + 1))
        if (self:getHeight() >= self:getScrollHeight()) then
            self:setWidth(40 * 5 + 8)
        end
    end
end
function selectAttachmentPane:close()
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
    if selectAttachmentPane.current == self then
        selectAttachmentPane.current = nil
    end
end
function selectAttachmentPane:onMouseDownOutside(x, y)
    if self:getIsVisible() and not self.vscroll:isMouseOver() then
        self:close()
    end
end
-- SELECT MAGAZINE PANE

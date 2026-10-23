function ISRemoveWeaponUpgrade:isValid()
    if isClient() and self.weapon then
        return self.character:getInventory():containsID(self.weapon:getID()) or self.partType == "Hide_Beam"
    else
        if not self.character:getInventory():contains(self.weapon) then
            if self.partType == "Hide_Beam" then
                return true
            else
                return false
            end
        end
    end
    return self.weapon:getWeaponPart(self.partType) ~= nil
end

local old_ISRemoveWeaponUpgrade_perform = ISRemoveWeaponUpgrade.perform
function ISRemoveWeaponUpgrade:perform()
    old_ISRemoveWeaponUpgrade_perform(self)
    local part = self.weapon:getWeaponPart(self.partType)

    self.character:resetEquippedHandsModels()

    if part and AWCWF_LaserAndGunLightSet[part:getType()] then
        if self.weapon:getWeaponPart("Hide_Beam") then
            self.weapon:setWeaponPart("Hide_Beam", nil)
        end
    end
    if MFS_RefreshWeaponAttachmentState then
        MFS_RefreshWeaponAttachmentState(self.character, self.weapon)
    elseif MFS_SyncEquippedWeaponState then
        MFS_SyncEquippedWeaponState(self.character, self.weapon, true)
    end

    if riskyInspectWindow and riskyInspectWindow:getIsVisible() then
        riskyInspectWindow:renderInventory()
    end
end

function ISRemoveWeaponUpgrade:complete()
    local part = self.weapon:getWeaponPart(self.partType)
    -- self.weapon:setWeaponPart(self.partType, nil)
    self.weapon:detachWeaponPart(self.character, part)
    syncHandWeaponFields(self.character, self.weapon)
    local part = self.character:getInventory():AddItem(part);
    if self.partType == "Laser" then
        part:getModData().LaserBatteryReamin = self.weapon:getModData().LaserBatteryReamin
        self.weapon:getModData().LaserBatteryReamin = nil
    end
    if self.partType == "Light" then
        part:getModData().LightBatteryReamin = self.weapon:getModData().LightBatteryReamin
        self.weapon:getModData().LightBatteryReamin = nil
    end
    sendAddItemToContainer(self.character:getInventory(), part);
    if MFS_RefreshWeaponAttachmentState then
        MFS_RefreshWeaponAttachmentState(self.character, self.weapon)
    elseif MFS_SyncEquippedWeaponState then
        MFS_SyncEquippedWeaponState(self.character, self.weapon, true)
    end

    -- 拆卸配件后即时刷新检视 UI 的 3D 预览。
    if riskyInspectWindow and riskyInspectWindow:getIsVisible() then
        riskyInspectWindow:renderInventory()
    end
    return true
end

function ISRemoveWeaponUpgrade:new(character, weapon, partType, maxTime)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon = weapon;
    o.partType = partType;
    o.maxTime = maxTime or o:getDuration();
    o.character = character;
    return o;
end


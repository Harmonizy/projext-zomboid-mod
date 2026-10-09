function ISUpgradeWeapon:isValid()

    if self.weapon:getWeaponPart(self.part:getPartType()) then
        return false
    end
    if isClient() and self.part and self.weapon then
        return (self.character:getInventory():containsID(self.part:getID()) and
                   self.character:getInventory():containsID(self.weapon:getID())) or self.part:getPartType() ==
                   "Hide_Beam";
    else
        return self.character:getInventory():contains(self.part) or self.part:getPartType() == "Hide_Beam";
    end
end

local old_ISUpgradeWeapon_perform = ISUpgradeWeapon.perform
function ISUpgradeWeapon:perform()
    old_ISUpgradeWeapon_perform(self)
    local partType = self.part:getPartType()
    if partType == "Laser" then
        local modData = self.part:getModData()
        if modData.LaserBatteryReamin then
            self.weapon:getModData().LaserBatteryReamin = modData.LaserBatteryReamin
        else
            self.weapon:getModData().LaserBatteryReamin = 100
        end
    end
    if partType == "Light" then
        local modData = self.part:getModData()
        if modData.LightBatteryReamin then
            self.weapon:getModData().LightBatteryReamin = modData.LightBatteryReamin
        else
            self.weapon:getModData().LightBatteryReamin = 100
        end
    end
    if MFS_RefreshWeaponAttachmentState then
        MFS_RefreshWeaponAttachmentState(self.character, self.weapon)
    else
        self.character:resetEquippedHandsModels()
        if MFS_SyncEquippedWeaponState then
            MFS_SyncEquippedWeaponState(self.character, self.weapon, true)
        end
    end

    -- 安装配件后即时刷新检视 UI 的 3D 预览，否则要关闭再打开才会显示新配件。
    if riskyInspectWindow and riskyInspectWindow:getIsVisible() then
        riskyInspectWindow:renderInventory()
    end
end

-- function ISUpgradeWeapon:perfom()
--     self.weapon:attachWeaponPart(self.character, self.part)
--     -- self.weapon:setWeaponPart(self.part:getPartType(), self.part)
--     syncHandWeaponFields(self.character, self.weapon)
--     self.character:getInventory():Remove(self.part);
--     sendRemoveItemFromContainer(self.character:getInventory(), self.part);
--     self.character:setSecondaryHandItem(nil);
--     return true
-- end
function ISUpgradeWeapon:new(character, weapon, part, maxtime)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon = weapon;
    o.part = part;
    o.maxTime = maxtime or o:getDuration();

    return o;
end

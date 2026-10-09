require "TimedActions/ISBaseTimedAction"
ISGunAddBatteryAction = ISBaseTimedAction:derive("ISGunAddBatteryAction");

function ISGunAddBatteryAction:isValid()

    return true
end

function ISGunAddBatteryAction:update()
end

function ISGunAddBatteryAction:start()

    -- self:setActionAnim("RemoveGrass")
    self:setOverrideHandModels(nil, nil)
end

function ISGunAddBatteryAction:stop()
    ISBaseTimedAction.stop(self);
end

function ISGunAddBatteryAction:perform()
    ISBaseTimedAction.perform(self);
    if self.PartType == "Laser" then
        self.Weapon:getModData().LaserBatteryReamin = self.BatteryItem:getCurrentUsesFloat() * 100
    elseif self.PartType == "Light" then
        self.Weapon:getModData().LightBatteryReamin = self.BatteryItem:getCurrentUsesFloat() * 100
    end
    self.character:getInventory():Remove(self.BatteryItem)
end

function ISGunAddBatteryAction:new(character, time, Weapon, PartType, BatteryItem)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
    o.Weapon = Weapon
    o.PartType = PartType
    o.BatteryItem = BatteryItem
    o.stopOnWalk = false;
    o.stopOnRun = true;
    o.maxTime = time;

    return o;
end

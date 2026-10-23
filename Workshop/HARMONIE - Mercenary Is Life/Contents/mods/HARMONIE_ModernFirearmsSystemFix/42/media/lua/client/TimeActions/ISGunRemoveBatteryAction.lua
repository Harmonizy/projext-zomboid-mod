require "TimedActions/ISBaseTimedAction"
ISGunRemoveBatteryAction = ISBaseTimedAction:derive("ISGunRemoveBatteryAction");

function ISGunRemoveBatteryAction:isValid()

    return true
end

function ISGunRemoveBatteryAction:update()
end

function ISGunRemoveBatteryAction:start()

    -- self:setActionAnim("RemoveGrass")
    self:setOverrideHandModels(nil, nil)
end

function ISGunRemoveBatteryAction:stop()
    ISBaseTimedAction.stop(self);
end

function ISGunRemoveBatteryAction:perform()
    ISBaseTimedAction.perform(self);
    local BatterReamin = 0
    if self.PartType == "Laser" then
        BatterReamin = self.Weapon:getModData().LaserBatteryReamin
        self.Weapon:getModData().LaserBatteryReamin = 0
    elseif self.PartType == "Light" then
        BatterReamin = self.Weapon:getModData().LightBatteryReamin
        self.Weapon:getModData().LightBatteryReamin = 0
    end
    BatterReamin = BatterReamin / 100
    local BatteryItem = self.character:getInventory():AddItem("Base.Battery")
    BatteryItem:setCurrentUsesFloat(BatterReamin)
end

function ISGunRemoveBatteryAction:new(character, time, Weapon, PartType)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
    o.Weapon = Weapon
    o.PartType = PartType
    o.stopOnWalk = false;
    o.stopOnRun = true;
    o.maxTime = time;

    return o;
end

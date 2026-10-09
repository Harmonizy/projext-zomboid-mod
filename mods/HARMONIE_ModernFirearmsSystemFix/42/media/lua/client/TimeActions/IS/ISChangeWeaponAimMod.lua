require "TimedActions/ISBaseTimedAction"
ISChangeWeaponAimMod = ISBaseTimedAction:derive("ISChangeWeaponAimMod");
function ISChangeWeaponAimMod:isValid()
    return true
end
function ISChangeWeaponAimMod:update()
end
function ISChangeWeaponAimMod:start()
end
function ISChangeWeaponAimMod:stop()
    ISBaseTimedAction.stop(self);
end
function ISChangeWeaponAimMod:perform()
    ISBaseTimedAction.perform(self);
    self.character:setVariable(self.type, "true");
    ISTimedActionQueue.add(ISForceSetAimType:new(self.character, self.type))

end
function ISChangeWeaponAimMod:new(character, type)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.type = type
    o.character = character;
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.maxTime = 1;
    return o;
end

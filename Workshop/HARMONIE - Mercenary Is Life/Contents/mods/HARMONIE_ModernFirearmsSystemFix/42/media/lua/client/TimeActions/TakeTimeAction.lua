require "TimedActions/ISBaseTimedAction"
TakeTimeAction = ISBaseTimedAction:derive("TakeTimeAction");

function TakeTimeAction:isValid()
    return true
end

function TakeTimeAction:update()
end

function TakeTimeAction:start()

end

function TakeTimeAction:stop()
    ISBaseTimedAction.stop(self);
end

function TakeTimeAction:perform()
    ISBaseTimedAction.perform(self);
    ChangeWeaponMode(self.character, self.weapon, self.type)
    -- ChangeWeaponMode changes the fire mode on the client only; sync the
    -- weapon to the server so the new fire mode persists in multiplayer.
    syncHandWeaponFields(self.character, self.weapon)
end

function TakeTimeAction:new(character, type, weapon)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.weapon = weapon
    o.type = type
    o.character = character;
    o.stopOnWalk = false;
    o.stopOnRun = false;
    o.maxTime = 50;

    return o;
end


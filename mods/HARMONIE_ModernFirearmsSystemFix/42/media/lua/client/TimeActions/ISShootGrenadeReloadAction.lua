require "TimedActions/ISBaseTimedAction"
require "Grenade_Tajectory_core"
ISShootGrenadeReload = ISBaseTimedAction:derive("ISShootGrenadeReload");

local LoadedKey = "GrenadeLauncherLoaded"

function ISShootGrenadeReload:isValid()
    if not self.weaopon then return false end
    if not self.weaopon:getWeaponPart("Stool") then return false end
    if self.weaopon:getModData()[LoadedKey] == true then return false end
    return true
end

function ISShootGrenadeReload:start()
    self.character:playSound(self.GrenadelauncherType.LoadSound)
end

function ISShootGrenadeReload:stop()
    ISBaseTimedAction.stop(self);
end

function ISShootGrenadeReload:perform()
    ISBaseTimedAction.perform(self);
    -- 消耗一枚 Base.GrenadeAmmo，标记为已装填；不替换发射器物品
    local inv = self.character:getInventory()
    inv:RemoveOneOf(self.GrenadelauncherType.AmmoType)
    self.weaopon:getModData()[LoadedKey] = true
end

function ISShootGrenadeReload:new(character, time, weapon, GrenadelauncherType)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.weaopon = weapon
    o.GrenadelauncherType = GrenadelauncherType
    o.character = character;
    o.stopOnWalk = false;
    o.stopOnRun = true;
    o.maxTime = time;

    return o;
end

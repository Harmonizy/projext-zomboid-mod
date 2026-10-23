require "TimedActions/ISBaseTimedAction"
require "Advanced_trajectory_core"
ShootGrenadeReload = ISBaseTimedAction:derive("ShootGrenadeReload");

function ShootGrenadeReload:isValid()
    return true
end

function ShootGrenadeReload:update()
end

function ShootGrenadeReload:start()
    if self.type == "grenade" then
        self.character:playSound("LauncherReload")
    end
    if self.type == "ShotGun" then
        self.character:playSound("MagnumInsertAmmo")
    end
    if self.type == "RPG" then
        self.character:playSound("LauncherReload")
    end
end

function ShootGrenadeReload:stop()
    ISBaseTimedAction.stop(self);
end

function ShootGrenadeReload:perform()
    ISBaseTimedAction.perform(self);
    if self.type == "grenade" then
        local MagPart = instanceItem("Gunpart.M203_cat")
        self.weaopon:setWeaponPart("Stool", MagPart)
        local inv = self.character:getInventory()
        local AmmoCanno = inv:FindAndReturn("Base.GrenadeAmmo")
        inv:Remove(AmmoCanno)
    end
    if self.type == "ShotGun" then
        local MagPart = instanceItem("Gunpart.M26_cat")
        self.weaopon:setWeaponPart("Stool", MagPart)
        local inv = self.character:getInventory()
        local AmmoCanno = inv:FindAndReturn("Base.ShotgunShells")
        inv:Remove(AmmoCanno)
    end
    if self.type == "RPG" then
        local MagPart = instanceItem("Gunpart.RPGLauncher_cat")
        self.weaopon:setWeaponPart("Stool", MagPart)
        local inv = self.character:getInventory()
        local AmmoCanno = inv:FindAndReturn("Base.RPGRocket")
        inv:Remove(AmmoCanno)
    end
end

function ShootGrenadeReload:new(character, time, weapon, type)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.weaopon = weapon
    o.type = type
    o.character = character;
    o.stopOnWalk = false;
    o.stopOnRun = true;
    o.maxTime = time;

    return o;
end

-- WeaponLightgun.lua
--
-- 下挂手电筒 (underbarrel flashlight = the "Light" weapon part, e.g. the
-- ArmytekPredator 战术手电 / 手枪战术灯): the light only emits while the player is
-- aiming down sights. When aiming, the weapon copies the part's own light values
-- (LightDistance 15 / LightStrength 1.3 / TorchCone true = vanilla GunLight), so
-- it renders exactly like the base game's mounted flashlight. Releasing aim — or
-- holding a weapon with no light part attached — turns it back off.

local function WeaponLightBeam()
    local attacker = getSpecificPlayer(0)
    if not attacker then return end

    local weapon = attacker:getPrimaryHandItem()
    if not weapon or not weapon:IsWeapon() or not weapon:isRanged() then return end

    local light = weapon:getWeaponPart("Light")

    if attacker:isAiming() and light then
        weapon:setTorchCone(light:isTorchCone())
        weapon:setLightDistance(light:getLightDistance())
        weapon:setLightStrength(light:getLightStrength())
    else
        weapon:setTorchCone(false)
        weapon:setLightDistance(0)
        weapon:setLightStrength(0.0)
    end
end

Events.OnPlayerUpdate.Add(WeaponLightBeam)

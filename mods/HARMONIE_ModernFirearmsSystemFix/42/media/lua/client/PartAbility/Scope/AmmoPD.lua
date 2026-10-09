-- 弹药编程装置 AmmoPD（L_Scope 槽位）
-- 当枪械安装 AmmoPD 后，正常开火命中（Events.OnWeaponHitCharacter）时，在命中的
-- 僵尸所在格子触发一个 1×1 格的小型爆炸，固定伤害 0.2。特效仅使用 ft_glow.png
-- （闪光）+ ft_smoke_1..6（烟雾），并播放自制鞭炮（Base.Firecracker_Crafted）的
-- 爆炸音效（FireCrackerSingleExplode）10% 音量。
-- 事件签名与 Bayonet.lua 一致：(attacker, target, weapon, damage)。

local EXPLOSION_DAMAGE = 0.5

local function ApplyAmmoPDExplosion(target)
    local sq = target and target:getCurrentSquare()
    if not sq then return end

    -- 1×1：仅命中格内的僵尸受到完整伤害
    local zombies = sq:getMovingObjects()
    for i = 0, zombies:size() - 1 do
        local z = zombies:get(i)
        if instanceof(z, "IsoZombie") then
            local newHealth = z:getHealth() - EXPLOSION_DAMAGE
            if newHealth < 0 then newHealth = 0 end
            z:setHealth(newHealth)
        end
    end

    -- 特效：闪光 + 烟雾（无爆炸火球）
    if GrenadeLauncherFX and GrenadeLauncherFX.spawnAmmoPDExplosion then
        GrenadeLauncherFX.spawnAmmoPDExplosion(sq:getX() + 0.5, sq:getY() + 0.5, sq:getZ() + 0.15)
    end

    -- 音效：自制鞭炮爆炸音，10% 音量
    local sound = getSoundManager():PlayWorldSound("FireCrackerSingleExplode", sq, 0, 4, 0.1, false)
    if sound then
        sound:setVolume(0.1)
    end
end

local function AmmoPDHitZombie(attacker, target, weapon, damage)
    if not (weapon and weapon:IsWeapon() and weapon:isRanged()) then return end
    if not (target and instanceof(target, "IsoZombie")) then return end

    local part = weapon:getWeaponPart("L_Scope")
    if not part or part:getType() ~= "AmmoPD" then return end

    ApplyAmmoPDExplosion(target)
end

Events.OnWeaponHitCharacter.Add(AmmoPDHitZombie)

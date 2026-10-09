local function BayonetAttackZombie(playerObj, zombieObj, MainGun)

    if playerObj:getVariableBoolean("Bob_BayonetAttack") then
        -- 沙盒：下挂刺刀伤害倍率（0.1~2，默认 1）与体力消耗（0~2，默认 0 = 关闭）
        local sandbox = (SandboxVars and SandboxVars.MFSSandbox) or {}
        local damageMult = tonumber(sandbox.BayonetDamage) or 1.0
        local MaxDamage = 3 * damageMult
        local DamageKnife = ZombRandFloat(MaxDamage / 10, MaxDamage)
        zombieObj:setHealth(zombieObj:getHealth() - DamageKnife)
        playerObj:getEmitter():playSound("SpearCraftedHit")

        local stamina = tonumber(sandbox.BayonetStamina) or 0
        if stamina > 0 then
            local stats = playerObj:getStats()
            if stats then
                stats:remove(CharacterStat.ENDURANCE, stamina * 0.015)
            end
        end
        --zombieObj:playHurtSound()
        --zombieObj:addBlood(10)
        -- playerObj:Say(tostring(math.floor(DamageKnife * 10) / 10))
    end

end

Events.OnWeaponHitCharacter.Add(BayonetAttackZombie)

local function HasPart(weapon)
    for k, v in pairs(AWCWF_BayonetSet.Parts.Stool) do
        local part = weapon:getWeaponPart("Stool")
        if part ~= nil and k == part:getType() then
            return true
        end
    end
    return false
end

-- Made by SportXAI
local function DetectBayonet()
    if not isIngameState() then return end
    local playerObj = getSpecificPlayer(0)
    if playerObj == nil then return end
    
    local weapon = playerObj:getPrimaryHandItem()
    if weapon == nil then return end
    
    if weapon and weapon:IsWeapon() and weapon:isRanged() then
        if HasPart(weapon) then
            if not playerObj:getVariableBoolean("Bob_BayonetAttack") then
                playerObj:setVariable("Bob_BayonetAttack", true)
            end
            
            return
        end
    end
    playerObj:clearVariable("Bob_BayonetAttack")
end

Events.OnTick.Add(DetectBayonet)

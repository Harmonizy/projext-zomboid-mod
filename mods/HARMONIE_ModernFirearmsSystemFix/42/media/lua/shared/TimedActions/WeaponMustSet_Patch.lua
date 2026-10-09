if isServer() then
    return
end

local function OnEquipWeapon(player, weapon)
    if not player then
        player = getPlayer()
    end
    if not player then
        return
    end
    if not weapon then
        weapon = player:getPrimaryHandItem()
    end
    if not weapon then
        return
    end
    if not weapon:IsWeapon() then
        return
    end
    if AWCWF_WeaponMustPartList[weapon:getType()] then
        local find = true
        for k, v in pairs(AWCWF_WeaponMustPartList[weapon:getType()]) do
            if v.MustInstall then
                local part = weapon:getWeaponPart(k)
                if part then
                    local Type = part:getType()
                    if not v[Type] then
                        find = false
                        break
                    end
                else
                    find = false
                    break
                end
            end
        end
        if not find then
            weapon:setJammed(true)
        else
            weapon:setJammed(false)
        end
    end
end

Events.OnEquipPrimary.Add(OnEquipWeapon)
Events.OnGameStart.Add(OnEquipWeapon)

local old_ISRackFirearm_rackBullet = ISRackFirearm.rackBullet
function ISRackFirearm:rackBullet()
    old_ISRackFirearm_rackBullet(self)
    OnEquipWeapon(self.character, self.gun)
end
SpawnInitPart = {}

SpawnInitPart.OnCreatePart = function(item)
    if not item then
        return;
    end
    for k, v in pairs(AWCWF_WeaponMustPartList[item:getType()]) do
        for i, j in pairs(v) do
            if i ~= "MustInstall" and ZombRand(1, 100) <= j.Chance then
                local part = instanceItem(j.FullType)
                item:setWeaponPart(k, part)
                break
            end
        end
    end
end

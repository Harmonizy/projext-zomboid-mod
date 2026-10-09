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
        local find = false
        for k, v in pairs(AWCWF_WeaponMustPartList[weapon:getType()]) do
            local part = weapon:getWeaponPart(k)
            if part then
                local Type = part:getType()
                if AWCWF_WeaponMustPartList[weapon:getType()][Type] then
                    find = true
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

-- Events.OnEquipWeapon.Add(OnEquipWeapon)
Events.OnGameStart.Add(OnEquipWeapon)

SpawnInitPart.OnCreatePart = function(item)
    if not item then
        return;
    end
    for k, v in pairs(AWCWF_WeaponMustPartList[item:getType()]) do
        for i, j in pairs(v) do

            if type(j) == "table" and j.chance then
                if ZombRand(1, 100) <= j.chance then
                    local part = instanceItem(i)
                    item:setWeaponPart(k, part)
                    break
                end
                
            end
            
        end
    end
end

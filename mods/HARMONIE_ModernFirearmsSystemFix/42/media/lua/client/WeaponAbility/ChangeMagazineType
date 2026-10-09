function ChangeMagzine(playerObj, MainGun, MagazineType, Tag, Need)
    if not MagazineType or not Need then
        return
    end
    local result = instanceItem(MainGun:getType());
    if MainGun:isContainsClip() and Tag ~= "ReFresh" then
        ISTimedActionQueue.add(ISEjectMagazine:new(playerObj, MainGun))
        return
    end
    result:setCondition(MainGun:getCondition());
    result:setFireMode(MainGun:getFireMode());
    if MagazineType then
        local TempPart = instanceItem(MagazineType);
        result:setMagazineType(MagazineType)
        result:setMaxAmmo(TempPart:getMaxAmmo())
    end
    result:setCurrentAmmoCount(MainGun:getCurrentAmmoCount());
    result:setRoundChambered(MainGun:isRoundChambered());

    -- if MainGun:getAttachedSlot() then
    --     playerObj:setAttachedItem(MainGun:getAttachedToModel(), result);
    --     result:setAttachedSlot(MainGun:getAttachedSlot())
    --     result:setAttachedSlotType(MainGun:getAttachedSlotType())
    --     result:setAttachedToModel(MainGun:getAttachedToModel());
    -- end

    local inv = playerObj:getInventory()
    local OldModData = MainGun:getModData()
    local NewModData = result:getModData()
    if OldModData then
        for k, v in pairs(OldModData) do
            if AWCWF_AllowModDataTable[k] then
                NewModData[k] = v
            end
        end
    end

    local parts = MainGun:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        result:setWeaponPart(part)
    end

    

    




    inv:DoRemoveItem(MainGun);
    playerObj:getInventory():AddItem(result);
    if Tag == "ReFresh" and MainGun:isContainsClip() then
        result:setContainsClip(true)
    end

    playerObj:setSecondaryHandItem(nil)
    playerObj:setPrimaryHandItem(nil)
    result:getModData().MagzineTypeNow = MagazineType

    if instanceof(result, "HandWeapon") then
        playerObj:setPrimaryHandItem(result)
        if result:isRequiresEquippedBothHands() or result:isTwoHandWeapon() then
            playerObj:setSecondaryHandItem(result)
        end
    end

    playerObj:resetEquippedHandsModels()
    if Tag ~= "ReFresh" then
        ISTimedActionQueue.add(riskyInspectAction:new(getPlayer(), 1));
    end
end

local function NeedRefresh()
    local MainGun = getPlayer():getPrimaryHandItem()
    local inv = getPlayer():getInventory()
    if MainGun then
        if MainGun:IsWeapon() then
            if MainGun:isRanged() then
                if MainGun:getModData().MagzineTypeNow == nil then
                    MainGun:getModData().MagzineTypeNow = MainGun:getMagazineType()
                end
                if MainGun:getModData().MagzineTypeNow ~= MainGun:getMagazineType() then
                    ChangeMagzine(getPlayer(), MainGun, MainGun:getModData().MagzineTypeNow, "ReFresh", true)
                    return
                end

            end
        end
    end
end
Events.OnEquipPrimary.Add(NeedRefresh)

Events.OnGameStart.Add(NeedRefresh)

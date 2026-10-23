local function SoundChange(playerObj, weapon)
    if MFS_SyncEquippedWeaponState then
        MFS_SyncEquippedWeaponState(playerObj, weapon, true)
        return
    end
    if weapon == nil then
        if not playerObj then
            playerObj = getPlayer()
        end
        if not playerObj then
            return
        end
        if playerObj:getPrimaryHandItem() then
            weapon = playerObj:getPrimaryHandItem()
        else
            return
        end
    end
    if not weapon:IsWeapon() then
        return;
    end
    local scriptItem = weapon:getScriptItem()
    local soundVolume = scriptItem:getSoundVolume()
    local soundRadius = scriptItem:getSoundRadius()
    if weapon:isRanged() then
        for k, v in pairs(AWCWF_SilencerSet) do
            local part = weapon:getWeaponPart(k)
            if part and v[part:getType()] then
                local TableNow = v[part:getType()]
                soundVolume = soundVolume * TableNow.SoundVolumeModifier
                soundRadius = soundRadius * TableNow.SoundRadiusModifier
            end
        end
    end
    weapon:setSoundVolume(soundVolume)
    weapon:setSoundRadius(soundRadius)
end

Events.OnEquipPrimary.Add(SoundChange);

Events.OnGameStart.Add(SoundChange)

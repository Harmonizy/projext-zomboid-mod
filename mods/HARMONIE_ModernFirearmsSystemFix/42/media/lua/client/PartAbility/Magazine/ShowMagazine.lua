MFSPerformanceSafety = MFSPerformanceSafety or {}
MFSPerformanceSafety.showMagazineOverride = "1.3.1"
if MFSPerformanceSafety.showMagazineCallback then
    Events.OnPlayerUpdate.Remove(MFSPerformanceSafety.showMagazineCallback)
end

local playerState = setmetatable({}, { __mode = "k" })

local function rememberState(playerObj, weapon)
    local clip = weapon:getWeaponPart("Clip")
    playerState[playerObj] = {
        weapon = weapon,
        loaded = weapon:isContainsClip(),
        magazineType = weapon:getMagazineType(),
        clip = clip,
        clipType = clip and clip:getFullType() or false
    }
end

local function isStateUnchanged(playerObj, weapon, loaded, magazineType, clip)
    local previous = playerState[playerObj]
    if not previous then
        return false
    end

    return previous.weapon == weapon
        and previous.loaded == loaded
        and previous.magazineType == magazineType
        and previous.clip == clip
        and previous.clipType == (clip and clip:getFullType() or false)
end

local function showMagazine(playerObj)
    if not playerObj then
        return
    end

    local weapon = playerObj:getPrimaryHandItem()
    if not weapon or not weapon:IsWeapon() or not weapon:isRanged() then
        playerState[playerObj] = nil
        return
    end

    local loaded = weapon:isContainsClip()
    local magazineType = weapon:getMagazineType()
    local clip = weapon:getWeaponPart("Clip")
    if isStateUnchanged(playerObj, weapon, loaded, magazineType, clip) then
        return
    end

    local partMap = AWCWF_MagazineTypeToPart
    if type(partMap) ~= "table" then
        return
    end

    local targetFullType
    local targetScript
    local mappedPart = partMap[magazineType]
    if mappedPart then
        targetFullType = mappedPart
        targetScript = ScriptManager.instance:getItem(targetFullType)
    else
        targetFullType = "Gunpart.Clip_" .. weapon:getType()
        targetScript = ScriptManager.instance:getItem(targetFullType)
        if not targetScript then
            targetFullType = "Base.Clip_" .. weapon:getType()
            targetScript = ScriptManager.instance:getItem(targetFullType)
        end
    end

    -- Preserve the original behavior when no cosmetic magazine part exists.
    if not targetScript then
        return
    end

    if loaded then
        -- The original created this item every player update. Create it only
        -- when the visible Clip part actually needs to change.
        if not clip or clip:getFullType() ~= targetFullType then
            local magazinePart = instanceItem(targetScript)
            if magazinePart then
                weapon:setWeaponPart("Clip", magazinePart)
            end
        end
    elseif clip then
        weapon:clearWeaponPart("Clip")
    end

    rememberState(playerObj, weapon)
end

MFSPerformanceSafety.showMagazineCallback = showMagazine
Events.OnPlayerUpdate.Remove(MFSPerformanceSafety.showMagazineCallback)
Events.OnPlayerUpdate.Add(MFSPerformanceSafety.showMagazineCallback)

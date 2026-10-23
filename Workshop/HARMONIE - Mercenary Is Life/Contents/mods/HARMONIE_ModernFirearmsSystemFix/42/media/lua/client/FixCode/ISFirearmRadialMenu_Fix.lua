local Old_ISFirearmRadialMenu_checkKey = ISFirearmRadialMenu.checkKey

function ISFirearmRadialMenu.checkKey(key)
    if not getCore():isKey("ReloadWeapon", key) then
        return false
    end
    if UIManager.getSpeedControls() and (UIManager.getSpeedControls():getCurrentGameSpeed() == 0) then
        return false
    end
    local playerObj = getSpecificPlayer(0)
    if not playerObj or playerObj:isDead() then
        return false
    end
    local queue = ISTimedActionQueue.queues[playerObj]
    if not (queue and #queue.queue > 0 and not queue.queue[1].AnimType) then
        return true
    end
    if getCell():getDrag(0) then
        return false
    end
    Old_ISFirearmRadialMenu_checkKey(key)
end

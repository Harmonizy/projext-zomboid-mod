BombCursor = {}

function BombCursor.OnPlayerUpdate(player)
    if not player then
        return
    end
    local weaitem = player:getPrimaryHandItem()

    if player:isAiming() and instanceof(weaitem, "HandWeapon") and (((weaitem:getSwingAnim() == "Throw"))) then
        Mouse.setCursorVisible(false)
        local level = 11 - player:getPerkLevel(Perks.Aiming)
        BombCursor.aimnum = 0
        if not BombCursor.aimcursor then
            BombCursor.aimcursor = ISThorowitemToCursor:new("", "", player, weaitem)
            BombCursor.Range = weaitem:getMaxRange()
            getCell():setDrag(BombCursor.aimcursor, 0)
        end
    else
        if BombCursor.aimcursor then
            getCell():setDrag(nil, 0);
            BombCursor.aimcursor = nil
            BombCursor.thorwerinfo = {}
        end
    end
end

Events.OnPlayerUpdate.Add(BombCursor.OnPlayerUpdate)


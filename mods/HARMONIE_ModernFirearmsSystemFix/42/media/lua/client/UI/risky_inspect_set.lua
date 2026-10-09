riskyUI.createInventoryMenuEntry = function(_player, _context, _items)
    local container = nil
    local resItems = {}
    for i, v in ipairs(_items) do
        if not instanceof(v, "InventoryItem") then
            for _, it in ipairs(v.items) do
                resItems[it] = true
            end
            container = v.items[1]:getContainer()
        else
            resItems[v] = true
            container = v:getContainer()
        end
    end
    local inspectSubMenu = _context:getNew(_context)
    local entryCount = 0
    for v, _ in pairs(resItems) do
        if v:IsWeapon() then
            inspectSubMenu:addOption(v:getName(), v, function()
                ISTimedActionQueue.add(ISInventoryTransferAction:new(getPlayer(), v, v:getContainer(),
                    getPlayer():getInventory()))
                ISTimedActionQueue.add(ISEquipWeaponAction:new(getPlayer(), v, 50, true, v:isTwoHandWeapon()));
                ISTimedActionQueue.add(riskyInspectAction:new(getPlayer(), 1));
            end)
            entryCount = entryCount + 1
        end
    end
    if entryCount ~= 0 then
        local option = _context:addOption(getText('IGUI_RISKY_INSPECT_WEAPON'))
        _context:addSubMenu(option, inspectSubMenu)
    end
end
Events.OnFillInventoryObjectContextMenu.Add(riskyUI.createInventoryMenuEntry)
riskyUI.onAttack = function(_character, _weapon)
    if riskyInspectWindow ~= nil and riskyInspectWindow:getIsVisible() then
        riskyInspectWindow:close()
        riskyInspectWindow = nil
    end
end
Events.OnWeaponSwing.Add(riskyUI.onAttack)
-- Windows position
riskyUI.onGameStart = function()
    if (getPlayer():getModData().inspectWindowPos == nil) then
        getPlayer():getModData().inspectWindowPos = {100, 100}
    end
end
Events.OnGameStart.Add(riskyUI.onGameStart)
riskyUI.onCreatePlayer = function(playerIndex, player)
    if (player:getModData().inspectWindowPos == nil) then
        player:getModData().inspectWindowPos = {100, 100}
    end
end
Events.OnCreatePlayer.Add(riskyUI.onCreatePlayer)

riskyUI.inspectOnKey = function(_keyPressed)
    if _keyPressed == getCore():getKey("OpenWindownCat") then
        local weapon = getPlayer():getPrimaryHandItem()
        if (weapon ~= nil and weapon:IsWeapon()) then
            if riskyInspectWindow == nil or not riskyInspectWindow:getIsVisible() then
                riskyInspectWindow = riskyUI:new(getPlayer():getModData().inspectWindowPos[1],
                    getPlayer():getModData().inspectWindowPos[2], 0, 0)
                riskyInspectWindow:addToUIManager()
                riskyInspectWindow.resizable = false
                riskyInspectWindow.collapsable = false
                riskyInspectWindow:renderInventory()
            else
                riskyInspectWindow:close()
                riskyInspectWindow = nil
            end
        end
    end
end
local function Check()
    Events.OnKeyPressed.Add(riskyUI.inspectOnKey)
end
Events.OnGameStart.Add(Check)

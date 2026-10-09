local function RemoveBattery(player, item, PartType)
    ISTimedActionQueue.add(ISInventoryTransferAction:new(getPlayer(), item, item:getContainer(),
        getPlayer():getInventory()))
    ISInventoryPaneContextMenu.equipWeapon(item, true, item:isRequiresEquippedBothHands(), 0)
    ISTimedActionQueue.add(ISGunRemoveBatteryAction:new(player, 20, item, PartType))

end

local function AddBattery(player, item, PartType, Battery)
    ISTimedActionQueue.add(ISInventoryTransferAction:new(getPlayer(), item, item:getContainer(),
        getPlayer():getInventory()))
    ISInventoryPaneContextMenu.equipWeapon(item, true, item:isRequiresEquippedBothHands(), 0)
    ISTimedActionQueue.add(ISGunAddBatteryAction:new(player, 20, item, PartType, Battery))

end

local function GetMaxBattery()
    local inventory = getPlayer():getInventory();
    local list = inventory:FindAll("Base.Battery");
    local Max
    for i = 0, list:size() - 1 do
        local TempItem = list:get(i)
        if not Max or TempItem:getCurrentUsesFloat() > Max:getCurrentUsesFloat() then
            Max = TempItem
        end
    end
    return Max
end

local function SendItem(_player, _context, _items)
    local resItems = {}
    local container
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
    for v, _ in pairs(resItems) do
        if instanceof(v, "HandWeapon") and v:IsWeapon() and v:isRanged() then
            local Laser = v:getWeaponPart("Laser")
            if Laser then
                local Battery = v:getModData().LaserBatteryReamin
                if Battery and Battery > 0 then
                    _context:addOption(getText("ContextMenu_Remove_Battery_To_Laser"), getPlayer(), RemoveBattery, v,
                        "Laser")
                end
                if Battery == 0 then
                    local BatteryItem = GetMaxBattery()
                    if BatteryItem then
                        _context:addOption(getText("ContextMenu_ADD_Battery_To_Laser"), getPlayer(), AddBattery, v,
                            "Laser", BatteryItem)
                    end
                end
            end
            local Light = v:getWeaponPart("Light")
            if Light then
                local Battery = v:getModData().LightBatteryReamin
                if Battery and Battery > 0 then
                    _context:addOption(getText("ContextMenu_Remove_Battery_To_Light"), getPlayer(), RemoveBattery, v,
                        "Light")
                    return
                end
                if Battery == 0 then
                    local BatteryItem = GetMaxBattery()
                    if BatteryItem then
                        _context:addOption(getText("ContextMenu_ADD_Battery_To_Light"), getPlayer(), AddBattery, v,
                            "Light", BatteryItem)
                    end
                end
            end
            return
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(SendItem)

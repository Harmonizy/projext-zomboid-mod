AmmoBagFunction = {}

local function GetWeightModify()
    return 0
end

local function GetOrCreatModData(item)

    local modData = item:getModData();
    if modData.IO == nil then
        modData.IO = {};
        modData.IO.ItemType = nil
        modData.IO.ItemName = nil
        modData.IO.Count = 0
        modData.IO.Weight = 0
        modData.IO.UsedDelta = 0
        modData.IO.UsedDeltaTotal = 0
    end
    return modData;
end
function AmmoBagFunction.RefreshItem(item)
    local ModData = GetOrCreatModData(item)
    if ModData.IO.ItemType ~= nil then
        item:setName(ModData.IO.ItemName .. " " .. ModData.IO.Count .. " " .. getText("IGUI_Unit"));
        local OriginItem = instanceItem(ModData.IO.ItemType)
        item:setActualWeight(ModData.IO.Weight * ModData.IO.Count * GetWeightModify())
    end
end

function AmmoBagFunction.GetLoadType(item)
    local ModData = GetOrCreatModData(item)
    return ModData.IO.ItemType
end
function AmmoBagFunction.ItemOut(item, num)
    local modData = GetOrCreatModData(item);
    if num == -1 then
        num = modData.IO.Count
    end
    local tempItem = instanceItem(modData.IO.ItemType)
    if tempItem:IsDrainable() then
        modData.IO.Count = modData.IO.Count - num
        modData.IO.UsedDeltaTotal = modData.IO.UsedDeltaTotal - (num * tempItem:getUsedDelta())
    elseif tempItem:IsWeapon() then
        modData.IO.Count = modData.IO.Count - num
        modData.IO.UsedDeltaTotal = modData.IO.UsedDeltaTotal - (num * tempItem:getConditionMax())
    else
        modData.IO.Count = modData.IO.Count - num
    end
    for i = 1, num do
        local item = instanceItem(modData.IO.ItemType);
        getPlayer():getInventory():AddItem(item);
    end
    item:setActualWeight(modData.IO.Weight * modData.IO.Count * GetWeightModify())
    item:setName(modData.IO.ItemName .. " " .. modData.IO.Count .. " " .. getText("IGUI_Unit"));
end

function AmmoBagFunction.SetItem(IOBox, item)
    local modData = GetOrCreatModData(IOBox);
    if modData.IO.ItemType ~= nil then
        if modData.IO.Count ~= 0 then
            getPlayer():Say(getText("IGUI_ClearIOBox"))
            return
        end
    end
    local tempItem = instanceItem(item:getFullType())
    if tempItem:IsDrainable() then
        modData.IO.UsedDelta = tempItem:getUsedDelta()
        modData.IO.UsedDeltaTotal = 0
    end
    if tempItem:IsWeapon() then
        modData.IO.UsedDelta = tempItem:getConditionMax()
        modData.IO.UsedDeltaTotal = 0
    end

    modData.IO.ItemType = item:getFullType();
    modData.IO.ItemName = item:getDisplayName();
    modData.IO.Count = 0
    modData.IO.Weight = item:getWeight()
    IOBox:setName(modData.IO.ItemName .. " " .. modData.IO.Count .. " " .. getText("IGUI_Unit"));

end

function AmmoBagFunction.AddNum(IOBox, num)
    local modData = GetOrCreatModData(IOBox);
    modData.IO.Count = modData.IO.Count + num
    IOBox:setActualWeight(modData.IO.Weight * modData.IO.Count * GetWeightModify())
    IOBox:setName(modData.IO.ItemName .. " " .. modData.IO.Count .. " " .. getText("IGUI_Unit"));
end

function AmmoBagFunction.SetNum(IOBox, num)
    local modData = GetOrCreatModData(IOBox);
    modData.IO.Count = num
    IOBox:setActualWeight(modData.IO.Weight * modData.IO.Count * GetWeightModify())
    IOBox:setName(modData.IO.ItemName .. " " .. modData.IO.Count .. " " .. getText("IGUI_Unit"));
end

function AmmoBagFunction.GetNum(IOBox)
    local modData = GetOrCreatModData(IOBox);
    return modData.IO.Count
end

function AmmoBagFunction.GetItemType(IOBox)
    local modData = GetOrCreatModData(IOBox);
    return modData.IO.ItemType
end

function AmmoBagFunction.InitItem(IOBox)
    local modData = GetOrCreatModData(IOBox);
    if modData.IO.ItemType == nil then
        getPlayer():Say(getText("IGUI_EmptyIOBox"))
        return
    end
    local ItemFullType = modData.IO.ItemType
    local tempItem = instanceItem(ItemFullType)
    local Inv = IOBox:getContainer()
    local itemlist = Inv:getItems()
    local ItemTable = {}
    for i = 0, itemlist:size() - 1 do
        if itemlist:get(i):getFullType() == ItemFullType then
            table.insert(ItemTable, itemlist:get(i))
        end
    end
    if #ItemTable == 0 then
        return
    end
    AmmoBagFunction.AddNum(IOBox, #ItemTable)
    for i = 1, #ItemTable do
        Inv:DoRemoveItem(ItemTable[i])
    end
end

local function createInventoryMenuEntry(_player, _context, _items)
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
    for v, _ in pairs(resItems) do
        local MainItem = getPlayer():getPrimaryHandItem()
        if MainItem and MainItem:IsWeapon() and MainItem:isRanged() then

            if v:getType() == "AmmoBag" and container:getType() ~= "floor" then
                local AmmoItem = instanceItem(MainItem:getAmmoType():getItemKey())
                local modData = GetOrCreatModData(v);
                if not modData.IO.ItemType then

                    _context:addOption(getText('IGUI_MarkItem') .. " " .. AmmoItem:getDisplayName(), v,
                        AmmoBagFunction.SetItem, AmmoItem)
                else

                    _context:addOption(getText('IGUI_LoadItem'), v, AmmoBagFunction.InitItem)

                    local ItemNum = AmmoBagFunction.GetNum(v)
                    if ItemNum >= 1 then
                        _context:addOption(getText('IGUI_UnloadItem1'), v, AmmoBagFunction.ItemOut, 1)
                        _context:addOption(getText('IGUI_UnloadItemAll'), v, AmmoBagFunction.ItemOut, -1)
                    end
                    if ItemNum >= 10 then
                        _context:addOption(getText('IGUI_UnloadItem10'), v, AmmoBagFunction.ItemOut, 10)
                    end
                    if ItemNum >= 50 then
                        _context:addOption(getText('IGUI_UnloadItem50'), v, AmmoBagFunction.ItemOut, 50)
                    end
                    if ItemNum >= 100 then
                        _context:addOption(getText('IGUI_UnloadItem100'), v, AmmoBagFunction.ItemOut, 100)
                    end
                    if ItemNum == 0 then
                        _context:addOption(getText('IGUI_MarkItem') .. AmmoItem:getDisplayName(), v,
                            AmmoBagFunction.SetItem, AmmoItem)
                    end
                    return
                end

            end
        end

    end
end

Events.OnFillInventoryObjectContextMenu.Add(createInventoryMenuEntry)

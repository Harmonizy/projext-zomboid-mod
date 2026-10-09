require "TimedActions/ISBaseTimedAction"
RepairWeaponAction = ISBaseTimedAction:derive("RepairWeaponAction");

function RepairWeaponAction:isValid()
    return true
end

function RepairWeaponAction:update()
end

function RepairWeaponAction:start()
    self.character:playSound("FlushingToilet")
    self:setActionAnim("RemoveGrass")
    self:setOverrideHandModels(nil, nil)
end

function RepairWeaponAction:stop()
    ISBaseTimedAction.stop(self);
end

function RepairWeaponAction:perform()
    ISBaseTimedAction.perform(self);
    ISTimedActionQueue.add(ISInventoryTransferAction:new(getPlayer(), self.Item, self.Item:getContainer(),
        getPlayer():getInventory()))
    self.Item:setCondition(self.Item:getConditionMax())
    local inv = getPlayer():getInventory()
    inv:Remove(self.MainItem)
    ISTimedActionQueue.add(ISEquipWeaponAction:new(getPlayer(), self.Item, 0, true, self.Item:isTwoHandWeapon()));
end

function RepairWeaponAction:new(character, Item, MainItem)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
    o.Item = Item;
    o.MainItem = MainItem;
    o.stopOnWalk = false;
    o.stopOnRun = true;
    o.maxTime = 350;

    return o;
end

local function FixItem(MainItem, Item)
    ISTimedActionQueue.add(RepairWeaponAction:new(getPlayer(), Item, MainItem))
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
        if MainItem ~= nil and MainItem:getType() == "gongjvxiuli_cat" and v:IsWeapon() and v:getCondition() and
            v:isRanged() then
            _context:addOption(getText('IGUI_FixItem'), MainItem, FixItem, v)
            return
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(createInventoryMenuEntry)

require "TimedActions/ISBaseTimedAction"

-- Repair the held weapon to full condition and consume one Base.gongjvxiuli_cat
-- from the player's inventory. Runs as a timed action so the condition restore
-- and item consumption are synced to the server in multiplayer.

RepairKitAction = ISBaseTimedAction:derive("RepairKitAction")

function RepairKitAction:isValid()
    if not self.weapon or not self.kit then return false end
    if not self.weapon.getConditionMax then return false end
    if self.weapon:getCondition() >= self.weapon:getConditionMax() then return false end
    return self.character:getInventory():contains(self.kit)
end

function RepairKitAction:update()
end

function RepairKitAction:start()
    self.character:playSound("FlushingToilet")
    self:setActionAnim("RemoveGrass")
    self:setOverrideHandModels(nil, nil)
end

function RepairKitAction:stop()
    ISBaseTimedAction.stop(self)
end

function RepairKitAction:perform()
    local inv = self.character:getInventory()
    if inv:contains(self.kit) then
        inv:Remove(self.kit)
        sendRemoveItemFromContainer(inv, self.kit)
    end
    self.weapon:setCondition(self.weapon:getConditionMax())
    syncHandWeaponFields(self.character, self.weapon)
    ISBaseTimedAction.perform(self)
end

function RepairKitAction:new(character, weapon, kit, maxTime)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon = weapon
    o.kit = kit
    o.maxTime = maxTime or 50
    o.stopOnWalk = false
    o.stopOnRun = true
    return o
end

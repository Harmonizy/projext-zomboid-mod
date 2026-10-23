require "TimedActions/ISBaseTimedAction"
ISForceSetAimType = ISBaseTimedAction:derive("ISForceSetAimType");

function ISForceSetAimType:isValid()
    if self.character:getVariableString(self.AnimType) ~= "true" then
        return false
    end
    if not self.character:isAiming() then
        return false
    end
    return true
end

function ISForceSetAimType:update()

end

function ISForceSetAimType:start()
    self:setAnimVariable("WeaponAimType", self.AnimType)
    self:setActionAnim("Aiming")
end

function ISForceSetAimType:stop()
    self.character:clearVariable("WeaponAimType")
    ISBaseTimedAction.stop(self);
end

function ISForceSetAimType:perform()
    ISBaseTimedAction.perform(self);
end

function ISForceSetAimType:new(character, AnimType)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
    o.AnimType = AnimType;
    o.useProgressBar = false
    o.maxTime = -1;
    o.stopOnWalk = false
    o.stopOnRun = true
    o.stopOnAim = false
    return o;
end

local function CheckTimeActionLists(playerObj)
    local TimeActionsListNow = ISTimedActionQueue.getTimedActionQueue(playerObj)
    local currentTable = TimeActionsListNow.current
    local queueTable = TimeActionsListNow.queue
    if currentTable then
        if currentTable.AnimType then
            if #queueTable > 1 then
                currentTable:forceComplete()
                print("Force complete current table")
            end
        end
        if not currentTable.AnimType then
            return false
        end
    end
    return true
    -- end
end

local AimList = {"Lean_Right"}

local function CheckLocalAimSet(key)
    -- local player = getPlayer()
    -- if not CheckTimeActionLists(player) then
    --     return
    -- end
    -- for i, v in ipairs(AimList) do
    --     if player:getVariableString(v) == "true" then
    --         if player:getVariableString("WeaponAimType") ~= v and player:isAiming() then
    --             ISTimedActionQueue.add(ISForceSetAimType:new(player, v))
    --         end
    --     end
    -- end

end

local function init()
    Events.OnKeyPressed.Add(CheckLocalAimSet)
end
Events.OnGameStart.Add(init)

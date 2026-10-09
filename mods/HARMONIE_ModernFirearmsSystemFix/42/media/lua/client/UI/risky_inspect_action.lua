-- @author Risky
-- Custom timed actions
require "TimedActions/ISBaseTimedAction"

riskyInspectAction = ISBaseTimedAction:derive("riskyInspectAction");

function riskyInspectAction:isValid()
    return true
end

function riskyInspectAction:update()
end

function riskyInspectAction:start()
end

function riskyInspectAction:stop()
    ISBaseTimedAction.stop(self);
end

function riskyInspectAction:perform()
    -- Init main window
    if riskyInspectWindow == nil or not riskyInspectWindow:getIsVisible() then
        riskyInspectWindow = riskyUI:new(getPlayer():getModData().inspectWindowPos[1],
            getPlayer():getModData().inspectWindowPos[2], 0, 0)
        riskyInspectWindow:addToUIManager()
        riskyInspectWindow.resizable = false
        riskyInspectWindow.collapsable = false

        riskyInspectWindow:renderInventory()
    end

    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self);
end

function riskyInspectAction:new(character, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.maxTime = time;
    return o;
end

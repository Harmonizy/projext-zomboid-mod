--[[
    HARMONIE - From Garden to Plate: the Cooking tab's timed actions.

    HARMONIE_GTP_CookStepAction -- one preparation step (wash, chop, stir...)
        after its minigame. Nothing is used up and nothing in the world
        changes (the ingredients go in later through vanilla's own
        ISAddItemInRecipe), so complete() does nothing on either side; the
        time is the step's own, 4 percent quicker per Cooking level.
    HARMONIE_GTP_CookWaitAction -- a short pause between two vanilla
        additions, while the server's new dish item reaches this client.
]]--

require "TimedActions/ISBaseTimedAction"
require "HARMONIEGardenToPlate/HARMONIE_CookCore"

local K = HARMONIE_GTP.Cook
local TICKS_PER_SECOND = 50

HARMONIE_GTP_CookStepAction = ISBaseTimedAction:derive("HARMONIE_GTP_CookStepAction")
local A = HARMONIE_GTP_CookStepAction

function A:isValid()
    return self.character ~= nil and self.proc ~= nil
end

function A:update()
    if Metabolics and Metabolics.UsingTools then self.character:setMetabolicTarget(Metabolics.UsingTools) end
end

function A:start()
    local anim = CharacterActionAnims and CharacterActionAnims.Craft or "Craft"
    pcall(function() self:setActionAnim(anim) end)
    if self.tool then pcall(function() self:setOverrideHandModels(self.tool, nil) end) end
    K.log("step %s started (%s, %.1f s)", tostring(self.procId), tostring(self.word), self.maxTime / TICKS_PER_SECOND)
end

function A:forceCancel()
    K.log("step %s cancelled before it started", tostring(self.procId))
    if self.onEnd then self.onEnd(false) end
end

function A:stop()
    K.log("step %s stopped", tostring(self.procId))
    if self.onEnd then self.onEnd(false) end
    ISBaseTimedAction.stop(self)
end

function A:perform()
    K.log("step %s done: %s", tostring(self.procId), tostring(self.word))
    if self.onEnd then self.onEnd(true, self.word) end
    ISBaseTimedAction.perform(self)
end

function A:complete()
    return true
end

function A:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return self.maxTime
end

function A:new(character, procId, word, tool)
    local o = ISBaseTimedAction.new(self, character)
    o.procId = procId
    o.proc = K.PROCS[procId]
    o.word = word
    o.tool = tool
    local secs = (o.proc and o.proc.time or 3) * math.max(0.4, 1 - 0.04 * K.level(character))
    o.maxTime = math.max(1, math.floor(secs * TICKS_PER_SECOND + 0.5))
    o.forceProgressBar = true
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

HARMONIE_GTP_CookWaitAction = ISBaseTimedAction:derive("HARMONIE_GTP_CookWaitAction")
local Wt = HARMONIE_GTP_CookWaitAction
function Wt:isValid() return self.character ~= nil end
function Wt:update() end
function Wt:start() end
function Wt:stop() ISBaseTimedAction.stop(self) end
-- onDone(character, arg): queue the next thing from inside this one
function Wt:perform()
    ISBaseTimedAction.perform(self)
    if self.onDone then
        local ok, err = pcall(self.onDone, self.character, self.arg)
        if not ok then K.log("next cooking step FAILED: %s", tostring(err)) end
    end
end
function Wt:complete() return true end
function Wt:getDuration() return self.maxTime end
function Wt:new(character, ticks, onDone, arg)
    local o = ISBaseTimedAction.new(self, character)
    o.onDone, o.arg = onDone, arg
    o.maxTime = ticks or 12
    o.stopOnWalk = false
    o.stopOnRun = false
    return o
end

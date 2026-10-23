--============================================================================
-- HARMONIE_TheWayToAttack -- practice timed action (shared)
--
-- Round 20 (request 2026-09-29: "การกดทำซ้ำให้มี action time และสามารถกด
-- หยุดได้"): practising a procedure now ends with the same action time as
-- the real thing (sandbox ProcedureSeconds), stoppable from the crafting
-- window's main procedure button. Nothing is used up, nothing is recorded,
-- no XP -- complete() does nothing on either side.
--============================================================================

require "TimedActions/ISBaseTimedAction"
require "HARMONIE_TWA_Procedures"
require "HARMONIE_TWA_Config"
require "HARMONIE_TWA_Sound"

TWA_PracticeAction = ISBaseTimedAction:derive("TWA_PracticeAction")

function TWA_PracticeAction:isValid()
    return self.character ~= nil and self.proc ~= nil
end

function TWA_PracticeAction:update()
    self.character:setMetabolicTarget(Metabolics.UsingTools)
    if self.proc.sound and not isServer() then TWASound.keepPlaying(self, self.proc.sound, "ActionSounds") end
end

function TWA_PracticeAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
    if self.proc.sound and not isServer() then TWASound.keepPlaying(self, self.proc.sound, "ActionSounds") end
end

-- 2026-10-02: an action taken off the queue before it ever started (the
-- one ahead of it was cancelled, the player moved...) gets forceCancel(),
-- not stop() -- free the crafting window's one-at-a-time lock here too, or
-- the window stays "running" with no action behind it.
function TWA_PracticeAction:forceCancel()
    if self.onEnd then self.onEnd() end
end

function TWA_PracticeAction:stop()
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.stop(self)
end

function TWA_PracticeAction:perform()
    if self.onComplete then self.onComplete() end
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.perform(self)
end

function TWA_PracticeAction:complete()
    return true
end

function TWA_PracticeAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return self.maxTime
end

function TWA_PracticeAction:new(character, procId)
    local o = ISBaseTimedAction.new(self, character)
    o.procId = procId
    o.proc = TWAProcedures.List[procId]
    o.maxTime = TWAConfig.secondsToTicks(TWAConfig.num("ProcedureSeconds", 0.1))
    o.forceProgressBar = true
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

if TWALogAction then TWALogAction(TWA_PracticeAction, "Practice") end

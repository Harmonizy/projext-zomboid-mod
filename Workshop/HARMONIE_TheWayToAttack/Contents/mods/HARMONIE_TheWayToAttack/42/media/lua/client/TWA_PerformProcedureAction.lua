--============================================================================
-- HARMONIE_TheWayToAttack -- perform-procedure timed action (client)
--
-- Queued when the player clicks an eligible procedure in the crafting UI's
-- right-panel grid (request 2026-09-26: "give it a button + a real duration
-- + sound effect + XP, like vanilla crafting -- whatever vanilla gives,
-- give the same"). Modeled directly on vanilla's own real ISCraftAction.lua
-- (media/lua/shared/TimedActions/ISCraftAction.lua): same
-- playSound/stopOrTriggerSound/setActionAnim/forceProgressBar pattern, just
-- driving our own procedure data instead of a real RecipeManager recipe.
-- Only isValid/start/stop/perform/new are overridden; every other method
-- (update/getDuration/getJobDelta/...) uses ISBaseTimedAction's own real
-- default implementation.
--============================================================================

require "TimedActions/ISBaseTimedAction"

TWA_PerformProcedureAction = ISBaseTimedAction:derive("TWA_PerformProcedureAction")

function TWA_PerformProcedureAction:isValid()
    if not self.character or not self.proc then return false end
    -- Re-checked every tick, same as ownsSlot/doneProcedures elsewhere in
    -- this mod -- if the light drops mid-action (torch runs out, etc.) the
    -- action stops, matching vanilla's own tooDarkToRead() gate.
    if self.character:tooDarkToRead() then return false end
    return TWAProcedures.CheckEligibility(self.proc, self.character)
end

function TWA_PerformProcedureAction:update()
    self.character:setMetabolicTarget(Metabolics.UsingTools)
end

function TWA_PerformProcedureAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
    if self.proc.sound then
        self.actionSound = self.character:playSound(self.proc.sound)
    end
end

function TWA_PerformProcedureAction:stop()
    if self.actionSound and self.character:getEmitter():isPlaying(self.actionSound) then
        self.character:stopOrTriggerSound(self.actionSound)
    end
    -- `onEnd` clears the crafting window's "one procedure at a time" lock
    -- whether this action finished OR was cancelled/interrupted (walking
    -- away, etc.) -- called from both stop() and perform() defensively
    -- (mirrors vanilla's own real ISCraftAction.lua, which duplicates its
    -- sound-stopping cleanup in both hooks the same way); the window-side
    -- callback is idempotent so calling it twice is harmless.
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.stop(self)
end

function TWA_PerformProcedureAction:perform()
    if self.actionSound and self.character:getEmitter():isPlaying(self.actionSound) then
        self.character:stopOrTriggerSound(self.actionSound)
    end
    TWAProcedures.Consume(self.proc, self.character)
    TWAProcedures.AwardXP(self.proc, self.character)
    if self.onComplete then self.onComplete() end
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.perform(self)
end

function TWA_PerformProcedureAction:new(character, proc, onComplete, onEnd)
    local o = ISBaseTimedAction.new(self, character)
    o.proc = proc
    o.onComplete = onComplete
    o.onEnd = onEnd
    o.maxTime = proc.time or 150
    o.forceProgressBar = true
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

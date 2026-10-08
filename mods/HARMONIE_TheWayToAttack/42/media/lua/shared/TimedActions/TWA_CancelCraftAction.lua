--============================================================================
-- HARMONIE_TheWayToAttack -- cancel-recipe timed action (shared)
--
-- Request 2026-09-28: "ปุ่มยกเลิกมีไว้ให้ยกเลิกการทำกรรมวิธีทั้งหมดที่ทำมา
-- ของไอเท็มนั้นๆ" -- wipes every procedure already done (and, since the
-- procedure minigame, every recorded quality word) for the current recipe.
-- Materials already used by those procedures are NOT refunded. A real timed
-- action with a gauge; aborting it before it finishes changes nothing
-- (perform()/complete() only run on a natural finish).
--
-- When the recipe was resumed from a bookmarked base item (`resumeItem`),
-- the bookmark itself is removed from that item in complete() -- it goes back
-- to being a plain base item, instead of keeping a recipe id with an empty
-- checklist the way it used to. A fresh (not resumed) craft only lives in
-- the crafting window's own session tables, which the window clears through
-- onComplete -- nothing in the world to change for it.
--
-- MULTIPLAYER: see TWA_PerformProcedureAction.lua's header.
--
-- ONE CRAFT AT A TIME (request 2026-09-28, later round): the base item and
-- the supplementary item were taken at Start; Cancel hands both back plain
-- (TWACraftState.giveBack) and drops the progress. Materials already used
-- by procedures stay used.
--============================================================================

require "TimedActions/ISBaseTimedAction"
require "HARMONIE_TWA_Procedures"
require "HARMONIE_TWA_Config"
require "HARMONIE_TWA_Sound"
require "HARMONIE_TWA_CraftState"

TWA_CancelCraftAction = ISBaseTimedAction:derive("TWA_CancelCraftAction")

function TWA_CancelCraftAction:isValid()
    if not self.character or not self.recipeId then return false end
    if isServer() or not isClient() then
        local act = TWACraftState.getActive(self.character)
        return act ~= nil and act.recipeId == self.recipeId
    end
    return true
end

-- Round 12: the workshop sound, replayed while the bar runs (client only).
function TWA_CancelCraftAction:update()
    if not isServer() then TWASound.keepPlaying(self, "TWA_Craft", "ActionSounds") end
end

function TWA_CancelCraftAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
    if not isServer() then TWASound.keepPlaying(self, "TWA_Craft", "ActionSounds") end
end

function TWA_CancelCraftAction:stopSound()
    if self.actionSound and self.actionSound ~= 0 then
        self.character:stopOrTriggerSound(self.actionSound)
    end
    self.actionSound = nil
end

-- 2026-10-02: an action taken off the queue before it ever started (the
-- one ahead of it was cancelled, the player moved...) gets forceCancel(),
-- not stop() -- free the crafting window's one-at-a-time lock here too, or
-- the window stays "running" with no action behind it.
function TWA_CancelCraftAction:forceCancel()
    if self.onEnd then self.onEnd() end
end

function TWA_CancelCraftAction:stop()
    self:stopSound()
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.stop(self)
end

function TWA_CancelCraftAction:perform()
    self:stopSound()
    if self.onComplete then self.onComplete() end
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.perform(self)
end

function TWA_CancelCraftAction:complete()
    -- Pays out only against the active-craft record, and ends it.
    return TWACraftState.giveBack(self.character, "cancel", self.recipeId)
end

function TWA_CancelCraftAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return self.maxTime
end

-- `recipeId` -- TWARecipeData id of the active craft.
function TWA_CancelCraftAction:new(character, recipeId)
    local o = ISBaseTimedAction.new(self, character)
    o.recipeId = recipeId
    -- Round 6: same time as the recipe's procedures (was a flat 300).
    -- Round 9: always the sandbox "CraftButtonSeconds" (default 5 s; "action
    -- time เป็น 5วิเสมอ").
    -- Round 17: Finish/Incomplete/Cancel 40 percent shorter than Start
    -- (sandbox "EndButtonSeconds", default 1.8 s).
    o.maxTime = TWAConfig.secondsToTicks(TWAConfig.num("EndButtonSeconds", 0.1))
    o.forceProgressBar = true
    return o
end

if TWALogAction then TWALogAction(TWA_CancelCraftAction, "CancelCraft") end

--============================================================================
-- HARMONIE_TheWayToAttack -- bookmark-progress timed action (shared)
--
-- Request 2026-09-27/28, multiplayer collaborative crafting: bookmarks the
-- current recipe's progress straight onto one of its base items -- nothing
-- is consumed or spawned. Right-clicking that exact item later (by anyone)
-- resumes it.
--
-- Request 2026-09-28 (procedure minigame): the bookmark now carries every
-- procedure's quality WORD too (TWA_ProcQuality, Miss included), so the
-- item's tooltip can list them and a resumed craft keeps its scores --
-- written through TWACraftState.writeBookmark, the one layout both the
-- server and the client use.
--
-- `baseItem` is chosen by the UI as a copy WITHOUT a bookmark already on it
-- (TWACraftState.pickFreshItem), so bookmarking never overwrites somebody
-- else's saved progress on another copy of the same item.
--
-- MULTIPLAYER: the ModData write happens in complete() (server in
-- multiplayer, local in single player); the client writes the identical
-- values into its own copy of the item through the window's onComplete.
-- See TWA_PerformProcedureAction.lua's header for the constructor rules.
--
-- ONE CRAFT AT A TIME (request 2026-09-28, later round): the base item was
-- taken at Start; Incomplete hands it back carrying the progress as a
-- bookmark, plus the supplementary item (TWACraftState.giveBack). Closing
-- the crafting window mid-craft does the same thing.
--============================================================================

require "TimedActions/ISBaseTimedAction"
require "HARMONIE_TWA_Procedures"
require "HARMONIE_TWA_CraftState"

TWA_IncompleteCraftAction = ISBaseTimedAction:derive("TWA_IncompleteCraftAction")

function TWA_IncompleteCraftAction:isValid()
    if not self.character or not self.recipeId then return false end
    if isServer() or not isClient() then
        local act = TWACraftState.getActive(self.character)
        return act ~= nil and act.recipeId == self.recipeId
    end
    return true
end

function TWA_IncompleteCraftAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
    if not isServer() then
        self.actionSound = self.character:playSound("CraftFixWeapon")
    end
end

function TWA_IncompleteCraftAction:stopSound()
    if self.actionSound and self.actionSound ~= 0 then
        self.character:stopOrTriggerSound(self.actionSound)
    end
    self.actionSound = nil
end

function TWA_IncompleteCraftAction:stop()
    self:stopSound()
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.stop(self)
end

function TWA_IncompleteCraftAction:perform()
    self:stopSound()
    if self.onComplete then self.onComplete() end
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.perform(self)
end

function TWA_IncompleteCraftAction:complete()
    -- Pays out only against the active-craft record, and ends it.
    return TWACraftState.giveBack(self.character, "incomplete", self.recipeId)
end

function TWA_IncompleteCraftAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return self.maxTime
end

-- `recipeId` -- TWARecipeData id of the active craft.
function TWA_IncompleteCraftAction:new(character, recipeId)
    local o = ISBaseTimedAction.new(self, character)
    o.recipeId = recipeId
    -- Round 6: same time as the recipe's procedures (was a flat 300).
    o.maxTime = TWACraftState.recipeActionTime(TWACraftState.getRecipeById(recipeId))
    o.forceProgressBar = true
    return o
end

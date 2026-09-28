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
--============================================================================

require "TimedActions/ISBaseTimedAction"
require "HARMONIE_TWA_CraftState"

TWA_CancelCraftAction = ISBaseTimedAction:derive("TWA_CancelCraftAction")

function TWA_CancelCraftAction:isValid()
    return self.character ~= nil
end

function TWA_CancelCraftAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function TWA_CancelCraftAction:stop()
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.stop(self)
end

function TWA_CancelCraftAction:perform()
    if self.onComplete then self.onComplete() end
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.perform(self)
end

function TWA_CancelCraftAction:complete()
    if self.resumeItem then
        local item = TWACraftState.findItem(self.character, self.resumeItem)
        if item then TWACraftState.clearBookmark(item) end
    end
    return true
end

function TWA_CancelCraftAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return self.maxTime
end

-- `recipeId` -- TWARecipeData id; `resumeItem` -- the bookmarked item being
-- resumed, or nil for a fresh craft.
function TWA_CancelCraftAction:new(character, recipeId, resumeItem)
    local o = ISBaseTimedAction.new(self, character)
    o.recipeId = recipeId
    o.resumeItem = resumeItem
    o.maxTime = 300
    o.forceProgressBar = true
    return o
end

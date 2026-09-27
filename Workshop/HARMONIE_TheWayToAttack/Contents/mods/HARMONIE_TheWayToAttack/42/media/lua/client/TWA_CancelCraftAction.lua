--============================================================================
-- HARMONIE_TheWayToAttack -- cancel-recipe timed action (client)
--
-- Request 2026-09-28: "ปุ่มยกเลิกมีไว้ให้ยกเลิกการทำกรรมวิธีทั้งหมดที่ทำมา
-- ของไอเท็มนั้นๆ" -- reverses an earlier round's design (which deliberately
-- kept done procedures marked done across Cancel, since their materials
-- were already spent either way) -- Cancel now genuinely WIPES every
-- procedure already marked done for the current recipe/item. Materials
-- already consumed by those procedures are still NOT refunded (Consume()
-- runs at procedure completion, this action never touches inventory) --
-- only their DONE STATUS resets, so finishing this recipe later means
-- redoing (and re-supplying fresh materials for) every one of them again.
--
-- Request 2026-09-28 (same batch): "การกดเสร็จสิ้น หรือไม่สมบูรณ์ และยกเลิก
-- ให้มีเกจการทำงานเหมือนตอนทำกรรมวิธี และสามารถกดยกเลิกก่อนที่จะเสร็จได้ด้วย
-- เหมือนกัน" -- Cancel is therefore now a REAL queued timed action (progress
-- bar, real duration) rather than an instant click, and -- since
-- ISBaseTimedAction's own real contract only calls perform() on NATURAL
-- completion, never on an interrupted/force-stopped one -- force-stopping
-- it before it finishes leaves the done-table completely untouched, giving
-- exactly the "changed your mind mid-cancel" behavior asked for with no
-- extra logic needed.
--============================================================================

require "TimedActions/ISBaseTimedAction"

TWA_CancelCraftAction = ISBaseTimedAction:derive("TWA_CancelCraftAction")

function TWA_CancelCraftAction:isValid()
    return self.character ~= nil and self.doneTable ~= nil
end

function TWA_CancelCraftAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function TWA_CancelCraftAction:stop()
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.stop(self)
end

-- Clears every entry in place -- `self.doneTable` is a direct reference to
-- whichever real table currently backs TWACraftWindow:currentDone() (either
-- self.progress[recipe.id], or a bookmarked base item's own
-- TWA_DoneProcedures ModData table) -- mutating it here is exactly
-- equivalent to the window clearing its own progress, works identically
-- for either backing store with no branching needed.
function TWA_CancelCraftAction:perform()
    for procId in pairs(self.doneTable) do
        self.doneTable[procId] = nil
    end
    if self.onComplete then self.onComplete() end
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.perform(self)
end

function TWA_CancelCraftAction:new(character, doneTable, onComplete, onEnd)
    local o = ISBaseTimedAction.new(self, character)
    o.doneTable = doneTable
    o.onComplete = onComplete
    o.onEnd = onEnd
    o.maxTime = 100
    o.forceProgressBar = true
    return o
end

--============================================================================
-- HARMONIE_TheWayToAttack -- bookmark-progress timed action (client)
--
-- Request 2026-09-27/28, multiplayer collaborative crafting: a player can
-- bookmark their current procedure progress on an in-progress recipe
-- straight onto that recipe's own base item -- writes TWA_RecipeId + a
-- TWA_DoneProcedures snapshot into the base item's own ModData. Nothing is
-- consumed or spawned; the base item itself is untouched otherwise. Right-
-- clicking that exact base item later (by anyone) resumes it directly (see
-- HARMONIE_TWA_CraftUI.lua's resumeFromItem/TWACraftUI.autoSearchNameFor).
--
-- Request 2026-09-28: "การกดเสร็จสิ้น หรือไม่สมบูรณ์ และยกเลิกให้มีเกจการ
-- ทำงานเหมือนตอนทำกรรมวิธี และสามารถกดยกเลิกก่อนที่จะเสร็จได้ด้วยเหมือนกัน"
-- -- this used to be an instant metadata write (nothing physically changes,
-- so there was nothing to animate); now a real queued timed action instead,
-- with a progress bar and real cancelability -- ISBaseTimedAction's own
-- contract only calls perform() on natural completion, so force-stopping
-- this before it finishes correctly leaves the base item's ModData
-- completely untouched (no bookmark written at all).
--============================================================================

require "TimedActions/ISBaseTimedAction"

TWA_IncompleteCraftAction = ISBaseTimedAction:derive("TWA_IncompleteCraftAction")

local function ownsSlot(character, fullType, altType)
    if not fullType then return true end
    local inv = character:getInventory()
    if inv:getItemCountRecurse(fullType) >= 1 then return true end
    return altType ~= nil and inv:getItemCountRecurse(altType) >= 1
end

function TWA_IncompleteCraftAction:isValid()
    if not self.character or not self.recipe then return false end
    return ownsSlot(self.character, self.recipe.base, self.recipe.baseAlt)
end

function TWA_IncompleteCraftAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
    self.actionSound = self.character:playSound("CraftFixWeapon")
end

function TWA_IncompleteCraftAction:stop()
    if self.actionSound and self.character:getEmitter():isPlaying(self.actionSound) then
        self.character:stopOrTriggerSound(self.actionSound)
    end
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.stop(self)
end

function TWA_IncompleteCraftAction:perform()
    if self.actionSound and self.character:getEmitter():isPlaying(self.actionSound) then
        self.character:stopOrTriggerSound(self.actionSound)
    end
    local inv = self.character:getInventory()
    local baseItem = inv:getFirstTypeEvalRecurse(self.recipe.base, function() return true end)
    if baseItem then
        local snapshot = {}
        for procId, done in pairs(self.doneProcedures or {}) do
            if done then snapshot[procId] = true end
        end
        local md = baseItem:getModData()
        md.TWA_RecipeId = self.recipe.id
        md.TWA_DoneProcedures = snapshot
    end
    if self.onComplete then self.onComplete() end
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.perform(self)
end

function TWA_IncompleteCraftAction:new(character, recipe, doneProcedures, onComplete, onEnd)
    local o = ISBaseTimedAction.new(self, character)
    o.recipe = recipe
    o.doneProcedures = doneProcedures
    o.onComplete = onComplete
    o.onEnd = onEnd
    o.maxTime = 100
    o.forceProgressBar = true
    return o
end

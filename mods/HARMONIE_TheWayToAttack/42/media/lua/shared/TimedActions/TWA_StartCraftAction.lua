--============================================================================
-- HARMONIE_TheWayToAttack -- start-craft timed action (shared)
--
-- Request 2026-09-28: "ทำให้ไม่สามารถทำได้หลายสูตรพร้อมกัน เมื่อเลือกสูตรใด
-- ไปแล้ว ให้หักวัตถุดิบตั้งต้นและชิ้นงานเสริมไปทันที". Queued by the crafting
-- window's Start button. Takes the base item and the supplementary item
-- (base2) out of the inventory (round 6: or the unfinished item Incomplete
-- handed out, when resuming) and makes the recipe the character's one
-- active craft (TWACraftState.beginActive). A bookmarked base item brings
-- its saved progress into the active craft. The items are snapshotted
-- (type, condition, ModData) so Cancel/Incomplete can hand them back as
-- they were.
--
-- MULTIPLAYER: see TWA_PerformProcedureAction.lua's header -- every world
-- change is in complete(); constructor parameters are strings or game
-- objects only.
--============================================================================

require "TimedActions/ISBaseTimedAction"
require "HARMONIE_TWA_Config"
require "HARMONIE_TWA_Sound"
require "HARMONIE_TWA_CraftState"

TWA_StartCraftAction = ISBaseTimedAction:derive("TWA_StartCraftAction")

-- A multiplayer client after start(): the server owns the items and checks
-- them itself; its complete() takes them out of the inventory, and that can
-- reach this client while its own bar is still on the last tick -- the old
-- client-side re-check then stopped the action here (no perform, the window
-- never learned the craft had started; the items were already gone and
-- Start had to be pressed again). Round 29 fix.
local function mpClient() return isClient() and not isServer() end

function TWA_StartCraftAction:isValid()
    local S = TWACraftState
    if not self.character or not self.recipe then return false end
    if mpClient() and self.twaStarted then return true end
    -- Only one craft at a time. (The server holds the record in MP; the
    -- client window enforces the same thing on its side.)
    if (isServer() or not isClient()) and S.getActive(self.character) then return false end
    -- The base slot also carries an unfinished item being resumed, which a
    -- recipe without a base item can have too.
    if (self.recipe.base or self.baseItem) and not S.resolveItem(self.character, self.baseItem) then return false end
    if self.recipe.base2 and not S.resolveItem(self.character, self.base2Item) then return false end
    return true
end

-- Round 12: the workshop sound, replayed while the bar runs (client only).
function TWA_StartCraftAction:update()
    if not isServer() then TWASound.keepPlaying(self, "TWA_Craft", "ActionSounds") end
end

function TWA_StartCraftAction:start()
    self.twaStarted = true
    self:setActionAnim(CharacterActionAnims.Craft)
    if not isServer() then TWASound.keepPlaying(self, "TWA_Craft", "ActionSounds") end
end

function TWA_StartCraftAction:stopSound()
    if self.actionSound and self.actionSound ~= 0 then
        self.character:stopOrTriggerSound(self.actionSound)
    end
    self.actionSound = nil
end

-- 2026-10-02: an action taken off the queue before it ever started (the
-- one ahead of it was cancelled, the player moved...) gets forceCancel(),
-- not stop() -- free the crafting window's one-at-a-time lock here too, or
-- the window stays "running" with no action behind it.
function TWA_StartCraftAction:forceCancel()
    if self.onEnd then self.onEnd() end
end

function TWA_StartCraftAction:stop()
    self:stopSound()
    -- Round 29: stopped on a multiplayer client after the server already
    -- took the base item (it finished first) -> the craft HAS started.
    if mpClient() and self.twaStarted and self.onComplete and (self.recipe.base or self.baseItem) then
        if TWASources and TWASources.forget then TWASources.forget(self.character) end
        if not TWACraftState.resolveItem(self.character, self.baseItem) then self.onComplete() end
    end
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.stop(self)
end

function TWA_StartCraftAction:perform()
    self:stopSound()
    if self.onComplete then self.onComplete() end
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.perform(self)
end

-- Server in multiplayer, local in single player.
function TWA_StartCraftAction:complete()
    local S = TWACraftState
    local recipe = self.recipe
    if not recipe or S.getActive(self.character) then return false end
    local base = (recipe.base or self.baseItem) and S.resolveItem(self.character, self.baseItem)
    local base2 = recipe.base2 and S.resolveItem(self.character, self.base2Item)
    if ((recipe.base or self.baseItem) and not base) or (recipe.base2 and not base2) then return false end
    -- Only a bookmark for THIS recipe may be resumed through the base slot.
    if not recipe.base and base and base:getModData().TWA_RecipeId ~= recipe.id then return false end
    -- Round 19: a fresh base must really fit the recipe (its type, and for
    -- gem refining the gem's state) -- the client's choice is checked here.
    if recipe.base and base and base:getModData().TWA_RecipeId ~= recipe.id and not S.baseOk(recipe, base) then return false end
    local map = S.bookmarkMap(base, recipe.id)
    local baseSnap, base2Snap = S.snapshotItem(base), S.snapshotItem(base2)
    if base then S.removeItem(self.character, base) end
    if base2 then S.removeItem(self.character, base2) end
    S.beginActive(self.character, recipe.id, map, baseSnap, base2Snap)
    return true
end

function TWA_StartCraftAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return self.maxTime
end

-- `recipeId` -- TWARecipeData id; `baseItem`/`base2Item` -- the exact items
-- to take, as the item or (round 13, what the UI sends) its id number, so
-- one lying in a crate or on the floor nearby also reaches the server.
function TWA_StartCraftAction:new(character, recipeId, baseItem, base2Item)
    local o = ISBaseTimedAction.new(self, character)
    o.recipeId = recipeId
    o.baseItem = baseItem
    o.base2Item = base2Item
    o.recipe = TWACraftState.getRecipeById(recipeId)
    -- Round 9: always the sandbox "CraftButtonSeconds" (default 5 s; "action
    -- time เป็น 5วิเสมอ").
    o.maxTime = TWAConfig.secondsToTicks(TWAConfig.num("CraftButtonSeconds", 0.1))
    o.forceProgressBar = true
    return o
end

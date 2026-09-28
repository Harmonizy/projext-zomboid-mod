--============================================================================
-- HARMONIE_TheWayToAttack -- finish-craft timed action (shared)
--
-- Queued by the crafting UI's Finish button once every procedure of the
-- recipe is done (none left at Miss). Consumes the recipe's base item(s)
-- and produces the result.
--
-- Request 2026-09-28: the finished item's grade is no longer a flat random
-- roll. The procedure words handed in (`qualities`, one per procedure) are
-- averaged into an overall quality (TWACraftState.overall) and the grade is
-- rolled from THAT quality's own pool (TWACraftState.rollGrade). Both are
-- stamped as ModData (TWA_Quality / TWA_Grade) next to TWA_CraftedBy. The 6
-- Material recipes get neither a quality nor a grade.
--
-- Still never renames the item (request 2026-09-28: "ไม่ว่าจะผ่าน
-- กระบวนการไหน ไม่ต้องเปลี่ยนชื่อไอเท็มเลย").
--
-- ONE CRAFT AT A TIME (request 2026-09-28, later round): the base items
-- are now taken by TWA_StartCraftAction when the craft starts, and Finish
-- pays out against the character's active-craft record. The paragraph
-- below describes the earlier fix, kept for the history.
--
-- EXACT-ITEM FIX (request 2026-09-28): `baseItem` is the specific item
-- instance to consume -- the bookmarked item itself when resuming, otherwise
-- a copy WITHOUT a bookmark (TWACraftState.pickFreshItem) -- instead of
-- "the first one of that type in the bag". Before, carrying two copies let
-- the bookmarked one survive a Finish while its unbookmarked twin was eaten.
--
-- MULTIPLAYER: see TWA_PerformProcedureAction.lua's header -- every world
-- change is in complete(); constructor parameters are strings or game
-- objects only.
--============================================================================

require "TimedActions/ISBaseTimedAction"
require "HARMONIE_TWA_Procedures"
require "HARMONIE_TWA_Config"
require "HARMONIE_TWA_CraftState"

TWA_FinishCraftAction = ISBaseTimedAction:derive("TWA_FinishCraftAction")

function TWA_FinishCraftAction:isValid()
    if not self.character or not self.recipe then return false end
    local S = TWACraftState
    -- Where the active-craft record lives (server in MP, here in SP), judge
    -- by it; a multiplayer client only has the words it was handed.
    if isServer() or not isClient() then
        local act = S.getActive(self.character)
        return act ~= nil and act.recipeId == self.recipeId and (S.canFinish(self.recipe, act.map))
    end
    return (S.canFinish(self.recipe, self.qmap))
end

function TWA_FinishCraftAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
    if not isServer() then
        self.finishSound = self.character:playSound("TWA_Craft")
    end
end

function TWA_FinishCraftAction:stopSound()
    if self.finishSound and self.finishSound ~= 0 then
        self.character:stopOrTriggerSound(self.finishSound)
    end
    self.finishSound = nil
end

function TWA_FinishCraftAction:stop()
    self:stopSound()
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.stop(self)
end

function TWA_FinishCraftAction:perform()
    self:stopSound()
    if self.onComplete then self.onComplete() end
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.perform(self)
end

-- Round 7 (request 2026-09-28: "สร้างโดย สามารถแสดงชื่อไอดีแทนชื่อตัวละคร
-- ได้ไหม"): the player's account name (getUsername(), what the server knows
-- them by) when there is one -- multiplayer. Single player has no account
-- name, so it falls back to the character's forename+surname as before.
local function crafterName(character)
    local user = character.getUsername and character:getUsername()
    if (isServer() or isClient()) and user and user ~= "" then return user end
    local desc = character:getDescriptor()
    return desc and (desc:getForename() .. " " .. desc:getSurname()) or (user or "")
end

-- Server in multiplayer, local in single player.
function TWA_FinishCraftAction:complete()
    local S = TWACraftState
    local recipe = self.recipe
    if not recipe then return false end
    -- The base items were already taken at Start; the words come from the
    -- authoritative active-craft record, never from the client.
    local act = S.getActive(self.character)
    if not act or act.recipeId ~= self.recipeId or not S.canFinish(recipe, act.map) then return false end
    local map = act.map
    S.clearActive(self.character)

    local inv = self.character:getInventory()
    local newItem = inv:AddItem(recipe.result)
    if newItem then
        -- Stamped BEFORE the item is sent to the client, so it arrives with
        -- its ModData already on it.
        local md = newItem:getModData()
        md.TWA_CraftedBy = crafterName(self.character)
        if not S.isMaterialRecipe(recipe) then
            local word = S.overall(recipe, map) or S.LEGACY_WORD
            md.TWA_Quality = word
            md.TWA_Grade = S.rollGrade(word)
        end
        if isServer() and sendAddItemToContainer then
            sendAddItemToContainer(inv, newItem)
        end
    end
    return true
end

function TWA_FinishCraftAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return self.maxTime
end

-- `recipeId` -- TWARecipeData id; `qualities` -- TWACraftState.serializeMap()
-- of every procedure's word (only the multiplayer client's isValid reads
-- it; the result is always judged from the active-craft record).
function TWA_FinishCraftAction:new(character, recipeId, qualities)
    local o = ISBaseTimedAction.new(self, character)
    o.recipeId = recipeId
    o.qualities = qualities
    o.recipe = TWACraftState.getRecipeById(recipeId)
    o.qmap = TWACraftState.parseMap(qualities)
    -- maxTime raised 100->300 (request 2026-09-28: "เพิ่มเวลา Actiontime
    -- ตอนกดปุ่ม เสร็จสิ้น ไม่สมบูรณ์ ยกเลิก" -- same for Incomplete/Cancel).
    -- Round 6: same time as the recipe's procedures (was a flat 300).
    -- Round 9: always the sandbox "CraftButtonSeconds" (default 5 s; "action
    -- time เป็น 5วิเสมอ").
    o.maxTime = TWAConfig.secondsToTicks(TWAConfig.num("CraftButtonSeconds", 0.1))
    o.forceProgressBar = true
    return o
end

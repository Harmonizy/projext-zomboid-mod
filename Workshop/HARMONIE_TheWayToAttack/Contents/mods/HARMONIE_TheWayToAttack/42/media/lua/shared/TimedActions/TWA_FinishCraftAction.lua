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
require "HARMONIE_TWA_CraftState"

TWA_FinishCraftAction = ISBaseTimedAction:derive("TWA_FinishCraftAction")

function TWA_FinishCraftAction:isValid()
    if not self.character or not self.recipe then return false end
    local S = TWACraftState
    if self.recipe.base and not S.findItem(self.character, self.baseItem) then return false end
    if self.recipe.base2 and not S.findItem(self.character, self.base2Item) then return false end
    return S.allDone(self.recipe, self.qmap)
end

function TWA_FinishCraftAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
    if not isServer() then
        self.finishSound = self.character:playSound("CraftFixWeapon")
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

-- The in-character forename+surname (not getUsername(), which is MP-account
-- specific and can be blank in single player).
local function crafterName(character)
    local desc = character:getDescriptor()
    return desc and (desc:getForename() .. " " .. desc:getSurname()) or ""
end

-- Server in multiplayer, local in single player.
function TWA_FinishCraftAction:complete()
    local S = TWACraftState
    local recipe = self.recipe
    if not recipe then return false end
    if recipe.base and not S.removeItem(self.character, self.baseItem) then return false end
    if recipe.base2 then S.removeItem(self.character, self.base2Item) end

    local inv = self.character:getInventory()
    local newItem = inv:AddItem(recipe.result)
    if newItem then
        -- Stamped BEFORE the item is sent to the client, so it arrives with
        -- its ModData already on it.
        local md = newItem:getModData()
        md.TWA_CraftedBy = crafterName(self.character)
        if not S.isMaterialRecipe(recipe) then
            local word = S.overall(recipe, self.qmap) or S.LEGACY_WORD
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

-- `recipeId` -- TWARecipeData id; `baseItem`/`base2Item` -- the exact item
-- instances to consume (nil when the recipe has no such slot);
-- `qualities` -- TWACraftState.serializeMap() of every procedure's word.
function TWA_FinishCraftAction:new(character, recipeId, baseItem, base2Item, qualities)
    local o = ISBaseTimedAction.new(self, character)
    o.recipeId = recipeId
    o.baseItem = baseItem
    o.base2Item = base2Item
    o.qualities = qualities
    o.recipe = TWACraftState.getRecipeById(recipeId)
    o.qmap = TWACraftState.parseMap(qualities)
    -- maxTime raised 100->300 (request 2026-09-28: "เพิ่มเวลา Actiontime
    -- ตอนกดปุ่ม เสร็จสิ้น ไม่สมบูรณ์ ยกเลิก" -- same for Incomplete/Cancel).
    o.maxTime = 300
    o.forceProgressBar = true
    return o
end

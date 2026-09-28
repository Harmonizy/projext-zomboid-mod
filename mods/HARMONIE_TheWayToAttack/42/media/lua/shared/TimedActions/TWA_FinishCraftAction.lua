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
-- Round 16: the Gemstone recipe (recipe.roll) ROLLS the item it gives --
-- TWACraftState.rollGemstone, here on the server -- and stamps no grade;
-- the client's TWAGemReveal finds it by the same token.
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
require "HARMONIE_TWA_Sound"
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

-- Round 12: the workshop sound, replayed while the bar runs (client only).
function TWA_FinishCraftAction:update()
    if not isServer() then TWASound.keepPlaying(self, "TWA_Craft", "ActionSounds") end
end

function TWA_FinishCraftAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
    if not isServer() then
        TWASound.keepPlaying(self, "TWA_Craft", "ActionSounds")
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
    -- Round 16: a rolling recipe (Gemstone) gives what the roll picked.
    local rolled = S.isRollRecipe(recipe)
    -- Round 17: the better the overall quality, the likelier a gem.
    local newItem = inv:AddItem(rolled and S.rollGemstone(recipe, nil, S.overall(recipe, map) or "Bad") or recipe.result)
    if newItem then
        -- Stamped BEFORE the item is sent to the client, so it arrives with
        -- its ModData already on it.
        local md = newItem:getModData()
        md.TWA_CraftedBy = crafterName(self.character)
        -- Round 12: lets the client's grade-reveal window find THIS item
        -- once it arrives (multiplayer adds it a moment later).
        if self.token and self.token ~= "" then md.TWA_CraftToken = self.token end
        -- Round 17 ("อัญมณีทีได้มาจากสูตรหินมณีให้ขึ้นคำในtooltip ... สถานะ:
        -- ดิบ"): a gem from the stone is RAW -- kept for later gem cutting.
        if rolled and S.isRolledGem(newItem:getFullType()) then md.TWA_GemState = "Raw" end
        if not S.isMaterialRecipe(recipe) and not rolled then
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
-- `token` (round 12): a string the client picks; stamped on the new item so
-- the grade-reveal window can find it.
function TWA_FinishCraftAction:new(character, recipeId, qualities, token)
    local o = ISBaseTimedAction.new(self, character)
    o.recipeId = recipeId
    o.qualities = qualities
    o.token = token
    o.recipe = TWACraftState.getRecipeById(recipeId)
    o.qmap = TWACraftState.parseMap(qualities)
    -- maxTime raised 100->300 (request 2026-09-28: "เพิ่มเวลา Actiontime
    -- ตอนกดปุ่ม เสร็จสิ้น ไม่สมบูรณ์ ยกเลิก" -- same for Incomplete/Cancel).
    -- Round 6: same time as the recipe's procedures (was a flat 300).
    -- Round 9: always the sandbox "CraftButtonSeconds" (default 5 s; "action
    -- time เป็น 5วิเสมอ").
    -- Round 17: Finish/Incomplete/Cancel 40 percent shorter than Start
    -- (sandbox "EndButtonSeconds", default 1.8 s).
    o.maxTime = TWAConfig.secondsToTicks(TWAConfig.num("EndButtonSeconds", 0.1))
    o.forceProgressBar = true
    return o
end

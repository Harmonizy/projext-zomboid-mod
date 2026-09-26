--============================================================================
-- HARMONIE_TheWayToAttack -- finish-craft timed action (client)
--
-- Queued by HARMONIE_TWA_CraftUI.lua's Finish button once every procedure a
-- recipe requires has been performed (and its materials already consumed
-- procedure-by-procedure, not here). This action just does the final step:
-- consume the base item (if the recipe has one) and produce the result item,
-- through the same ISBaseTimedAction/ISTimedActionQueue path every other
-- crafting action in the game uses (isValid/perform only overridden; every
-- other method -- update/start/stop/getDuration -- uses ISBaseTimedAction's
-- own real default implementation, confirmed from its own source rather than
-- guessed, matching this mod's usual verification discipline).
--============================================================================

require "TimedActions/ISBaseTimedAction"

TWA_FinishCraftAction = ISBaseTimedAction:derive("TWA_FinishCraftAction")

-- `recipe.base`/`recipe.base2` may each be nil, a single fullType string, or
-- a LIST of interchangeable fullTypes (e.g. the universal "Metal Ingot" base
-- is really any of vanilla's own 4 real base:ingot items -- request
-- 2026-09-26: "materials aren't flexible"). `base2` is a SEPARATE required
-- slot, not an alternative to `base` (request 2026-09-26: "let the base item
-- be two items" -- e.g. a spear's shaft AND its head component).
local function baseList(base)
    if base == nil then return {} end
    if type(base) == "table" then return base end
    return { base }
end

local function ownsSlot(character, spec)
    if not spec then return true end
    local inv = character:getInventory()
    for _, t in ipairs(baseList(spec)) do
        if inv:getItemCountRecurse(t) >= 1 then return true end
    end
    return false
end

local function removeOneOf(character, spec)
    if not spec then return end
    local inv = character:getInventory()
    for _, t in ipairs(baseList(spec)) do
        local it = inv:getFirstTypeEvalRecurse(t, function() return true end)
        if it then
            inv:Remove(it)
            return
        end
    end
end

function TWA_FinishCraftAction:isValid()
    if not self.character or not self.recipe then return false end
    if not ownsSlot(self.character, self.recipe.base) then return false end
    if not ownsSlot(self.character, self.recipe.base2) then return false end
    for _, procId in ipairs(self.recipe.procedures) do
        if not self.doneProcedures[procId] then return false end
    end
    return true
end

function TWA_FinishCraftAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
    self.finishSound = self.character:playSound("CraftFixWeapon")
end

function TWA_FinishCraftAction:stop()
    if self.finishSound and self.character:getEmitter():isPlaying(self.finishSound) then
        self.character:stopOrTriggerSound(self.finishSound)
    end
    ISBaseTimedAction.stop(self)
end

-- Rarity tier labeling (request 2026-09-26; corrected same day -- "I didn't
-- ask to recolor the weapon, just the name").
--
-- *** REAL LIMITATION FOUND (not guessed): the item-hover tooltip's NAME
-- line is HARDCODED white by the engine itself --
-- media/lua/client/ISUI/ISToolTip.lua:112,
-- `self:drawText(self.name, 8, 5, 1, 1, 1, 1, UIFont.Medium)` -- a literal
-- (1,1,1,1) with no per-item color read anywhere in that file. There is no
-- confirmed Lua API to override that specific line's color for an arbitrary
-- item; `item:setColorRed/Green/Blue()` (tried last round) doesn't reach it
-- either -- confirmed by checking ISInventoryPane.lua's own real item-list
-- rendering, which never reads getColorRed/Green/Blue() when drawing a
-- name. That's also why it was dropped here: it wasn't recoloring the name
-- (nothing does), it was only ever going to tint the weapon's own icon/
-- sprite -- which is explicitly NOT what was asked for, so it's removed
-- rather than left in as dead/wrong-purpose code. ***
--
-- What IS real and used here instead: `item:setName(...)` (confirmed real
-- rename API, from ISInventoryPaneContextMenu.lua's own "rename item"
-- feature) appends the tier name in brackets to the item's name -- shown in
-- plain white like the rest of the name (the engine limitation above means
-- there's no colored-text version of this), but it's real text on the real
-- item, not just this mod's own crafting-window UI. The crafting window
-- itself (HARMONIE_TWA_CraftUI.lua) remains the one place tier is actually
-- shown in real color, since that's our own custom-drawn UI with no such
-- limitation.
-- Tier names are NOT translated (request 2026-09-26: "ไม่ต้องแปลชื่อ tier")
-- -- shown as the plain English label directly, same as the tooltip hook.
local TIER_NAMES = {
    [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic", [5] = "Qualificated",
}

local function applyTier(item, fullType)
    local stats = TWARecipeData.Stats[fullType]
    local tier = stats and stats.tier
    if not tier or not TIER_NAMES[tier] then return end
    local baseName = item:getDisplayName()
    item:setName(baseName .. " [" .. TIER_NAMES[tier] .. "]")
    -- Tagged on the actual item instance (ModData, real per-item store --
    -- see workflow.txt 7.2) so HARMONIE_TWA_TierTooltip.lua's real tooltip
    -- hook can show it when this exact item is hovered later (request
    -- 2026-09-26: "the vanilla tooltip doesn't show the item's tier").
    item:getModData().TWA_Tier = tier
end

function TWA_FinishCraftAction:perform()
    if self.finishSound and self.character:getEmitter():isPlaying(self.finishSound) then
        self.character:stopOrTriggerSound(self.finishSound)
    end
    local inv = self.character:getInventory()
    removeOneOf(self.character, self.recipe.base)
    removeOneOf(self.character, self.recipe.base2)
    local newItem = inv:AddItem(self.recipe.result)
    if newItem then applyTier(newItem, self.recipe.result) end
    ISBaseTimedAction.perform(self)
end

function TWA_FinishCraftAction:new(character, recipe, doneProcedures)
    local o = ISBaseTimedAction.new(self, character)
    o.recipe = recipe
    o.doneProcedures = doneProcedures
    o.maxTime = 100
    o.forceProgressBar = true
    return o
end

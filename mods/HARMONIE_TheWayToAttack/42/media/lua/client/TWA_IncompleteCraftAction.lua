--============================================================================
-- HARMONIE_TheWayToAttack -- take-out-early timed action (client)
--
-- Request 2026-09-27, multiplayer collaborative crafting: "ui ตรงกลาง เพิ่ม
-- ปุ่ม ไม่สมบูรณ์ เป็นการเอาไอเท็มออกมาก่อนกำหนด จะเก็บข้อมูลไว้ใน tooltip
-- แล้วเวลาเปิด ui ผ่านอาวุธนี้อีกครั้ง ให้อ่านข้อมูล tooltip และจะเอามาเป็น
-- ตัวกำหนดกรรมวิธีที่ทำไปแล้ว หรือยังไม่ได้ทำ ทำให้สามารถสร้างอาวุธร่วมกับ
-- คนอื่นได้" -- a player can pull a recipe's result item out of the crafting
-- UI EARLY, before every procedure is done, as a real physical item tagged
-- with whatever progress has been made so far, so someone else (or the same
-- player later) can pick it up and keep going -- right-clicking that exact
-- item auto-resumes it (see HARMONIE_TWA_CraftUI.lua's resumeFromItem/
-- currentDone and HARMONIE_TWA_CraftTrigger.lua's context-menu check).
--
-- MP-safety note: this queues as a real ISBaseTimedAction the same way every
-- other crafting action in this codebase does (TWA_FinishCraftAction.lua,
-- TWA_PerformProcedureAction.lua), matching vanilla's own crafting-action
-- pattern -- not a new architecture. The one new piece is per-item ModData
-- (TWA_Incomplete/TWA_RecipeId/TWA_DoneProcedures) needing to be visible to
-- OTHER players who later pick this item up -- per-item ModData is already
-- relied on for exactly that in this mod (TWA_Tier, read by ANY player's
-- client via HARMONIE_TWA_TierTooltip.lua's hover hook, not just the
-- crafter's own), so no new sync assumption is being made here.
--============================================================================

require "TimedActions/ISBaseTimedAction"

TWA_IncompleteCraftAction = ISBaseTimedAction:derive("TWA_IncompleteCraftAction")

-- Same real ownsSlot/removeOneOf shape as TWA_FinishCraftAction.lua's own
-- (not imported from there -- both files are plain globals with no
-- guaranteed load order relative to each other, so each keeps its own local
-- copy of this small, stable helper rather than risking a load-order bug).
local function ownsSlot(character, fullType, altType)
    if not fullType then return true end
    local inv = character:getInventory()
    if inv:getItemCountRecurse(fullType) >= 1 then return true end
    return altType ~= nil and inv:getItemCountRecurse(altType) >= 1
end

local function removeOneOf(character, fullType, altType)
    if not fullType then return end
    local inv = character:getInventory()
    local it = inv:getFirstTypeEvalRecurse(fullType, function() return true end)
    if not it and altType then
        it = inv:getFirstTypeEvalRecurse(altType, function() return true end)
    end
    if it then inv:Remove(it) end
end

function TWA_IncompleteCraftAction:isValid()
    if not self.character or not self.recipe then return false end
    if not ownsSlot(self.character, self.recipe.base, self.recipe.baseAlt) then return false end
    if not ownsSlot(self.character, self.recipe.base2, nil) then return false end
    return true
end

function TWA_IncompleteCraftAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
    self.finishSound = self.character:playSound("CraftFixWeapon")
end

function TWA_IncompleteCraftAction:stop()
    if self.finishSound and self.character:getEmitter():isPlaying(self.finishSound) then
        self.character:stopOrTriggerSound(self.finishSound)
    end
    ISBaseTimedAction.stop(self)
end

function TWA_IncompleteCraftAction:perform()
    if self.finishSound and self.character:getEmitter():isPlaying(self.finishSound) then
        self.character:stopOrTriggerSound(self.finishSound)
    end
    local inv = self.character:getInventory()
    removeOneOf(self.character, self.recipe.base, self.recipe.baseAlt)
    removeOneOf(self.character, self.recipe.base2, nil)
    local newItem = inv:AddItem(self.recipe.result)
    if newItem then
        -- Tier is intrinsic to the fullType (never random), so it's tagged/
        -- named now via TWA_FinishCraftAction.lua's own real applyTier
        -- (exported specifically so this file doesn't duplicate it) rather
        -- than waiting for the real Finish -- that function's own guard
        -- means a later real Finish on this same item never re-applies it.
        TWA_FinishCraftAction.applyTier(newItem, self.recipe.result)
        local md = newItem:getModData()
        -- Captured BEFORE appending the "[Incomplete]" suffix below, so the
        -- real Finish later can restore exactly this (tier-suffixed, but
        -- not yet Incomplete-suffixed) name regardless of which language
        -- IGUI_TWA_IncompleteSuffix is shown in -- see
        -- TWA_FinishCraftAction.lua's finalizeResumedItem.
        md.TWA_BaseName = newItem:getDisplayName()
        newItem:setName(md.TWA_BaseName .. " " .. getText("IGUI_TWA_IncompleteSuffix"))
        md.TWA_Incomplete = true
        md.TWA_RecipeId = self.recipe.id
        local saved = {}
        for procId, v in pairs(self.doneProcedures or {}) do
            if v then saved[procId] = true end
        end
        md.TWA_DoneProcedures = saved
    end
    ISBaseTimedAction.perform(self)
end

function TWA_IncompleteCraftAction:new(character, recipe, doneProcedures)
    local o = ISBaseTimedAction.new(self, character)
    o.recipe = recipe
    o.doneProcedures = doneProcedures
    o.maxTime = 50
    o.forceProgressBar = true
    return o
end

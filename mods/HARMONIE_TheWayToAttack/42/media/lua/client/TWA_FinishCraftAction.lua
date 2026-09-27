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

-- `recipe.base` is either nil (no starting item needed at all) or a SINGLE
-- real fullType string. `recipe.baseAlt`, when present, is a single OPTIONAL
-- substitute for that SAME slot (dead data-side since a later round removed
-- it, but harmless to keep supporting) -- ownsSlot checks base OR baseAlt,
-- removeOneOf consumes whichever the character actually has (base
-- preferred). `recipe.base2`, when present, is a SEPARATE, REQUIRED second
-- slot (request 2026-09-27: "ทำให้สูตรไอเท็ม uncommon ทุกชิ้นใช้ชิ้นส่วน
-- ตั้งต้นชิ้นที่ 2 (ไม่ใช่ optional) เป็น แท่งวัตถุดิบ...ของ tier ตัวเอง" --
-- a tier-matched MaterialBar) -- both base and base2 must be owned, and
-- both get consumed on Finish; base2 has no altType of its own.
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

-- `self.resumeItem` (request 2026-09-27, multiplayer collaborative
-- crafting): set when Finish is clicked while resuming a physical item that
-- was already taken out early via TWA_IncompleteCraftAction.lua -- its base
-- item(s) were consumed back then, not now, so the usual ownsSlot re-checks
-- are skipped in favor of re-confirming the character still actually has
-- THAT SPECIFIC item (it could have been dropped, traded away, or put in a
-- container mid-action since the button was clicked) via getContainer():
-- isInCharacterInventory(), the same real API vanilla's own
-- ISInventoryPaneContextMenu.lua uses for this exact kind of check.
function TWA_FinishCraftAction:isValid()
    if not self.character or not self.recipe then return false end
    if self.resumeItem then
        local container = self.resumeItem:getContainer()
        if not container or not container:isInCharacterInventory(self.character) then return false end
    else
        if not ownsSlot(self.character, self.recipe.base, self.recipe.baseAlt) then return false end
        if not ownsSlot(self.character, self.recipe.base2, nil) then return false end
    end
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
-- Full 8-tier fixed-DPS scale. Legendary and Prototype swapped positions
-- (request 2026-09-26, full explicit table): Legendary is now DPS < 10,
-- Prototype is now the unbounded top tier DPS >= 10.
local TIER_NAMES = {
    [1] = "Junk", [2] = "Common", [3] = "Uncommon", [4] = "Rare", [5] = "Epic",
    [6] = "Elite", [7] = "Legendary", [8] = "Prototype",
}

-- Guarded by TWA_Tier already being set (request 2026-09-27) -- an
-- Incomplete item (TWA_IncompleteCraftAction.lua) gets tagged/renamed by
-- THIS same function when it's first taken out early, since its tier is
-- intrinsic to its fullType and never random; without the guard, later
-- finishing that same item here would re-append "[Tier]" a second time.
local function applyTier(item, fullType)
    if item:getModData().TWA_Tier then return end
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
-- Exported (request 2026-09-27) so TWA_IncompleteCraftAction.lua can reuse
-- this exact same tagging/renaming logic instead of duplicating it -- both
-- files need to agree on the identical format for the resume/strip step
-- below to work.
TWA_FinishCraftAction.applyTier = applyTier

-- Rarity GRADE roll (request 2026-09-27, verbatim odds): "การกดเสร็จสิ้นจะมี
-- การเก็บความแรร์ไว้ใน tooltip ความแรร์มีได้แก่ S A B C D E F โดยมีโอกาสสุ่ม
-- ได้ตามลำดับนี้ 0,1,3,6,15,25,50" -- purely stored for now, not read by
-- anything else yet (the request itself defers that: "ในอนาคตจะมีการให้อ่าน
-- ค่า tooltip นี้ไปทำอย่างอื่นในภายหลัง"). S's own stated odds are exactly
-- 0 -- kept literally as given rather than "rounded up" to something
-- reachable, since 0% for the top grade reads like it's meant to require
-- some other, not-yet-specified condition later, not plain chance.
local GRADE_TABLE = {
    { grade = "S", chance = 0 }, { grade = "A", chance = 1 }, { grade = "B", chance = 3 },
    { grade = "C", chance = 6 }, { grade = "D", chance = 15 }, { grade = "E", chance = 25 },
    { grade = "F", chance = 50 },
}
local function rollGrade()
    local roll = ZombRand(100)
    local cumulative = 0
    for _, g in ipairs(GRADE_TABLE) do
        cumulative = cumulative + g.chance
        if roll < cumulative then return g.grade end
    end
    return "F"
end

-- Stamps who actually finished this item (request 2026-09-27: "tooltip มีการ
-- สลักชื่อของผู้กดเสร็จสิ้น") and rolls its grade -- both only happen once,
-- at the REAL finish, whether that's a fresh craft or completing a resumed
-- Incomplete item; the in-character forename+surname is used (not
-- getUsername(), which is MP-account-specific and can be blank/meaningless
-- in singleplayer) -- same real identity vanilla itself already uses for
-- signing things by player (e.g. LastStandSetup.lua, ISCharacterScreen.lua).
local function stampFinisher(item, character)
    local md = item:getModData()
    local desc = character:getDescriptor()
    md.TWA_CraftedBy = desc and (desc:getForename() .. " " .. desc:getSurname()) or ""
    md.TWA_Grade = rollGrade()
end

-- Request 2026-09-27: finishing a RESUMED Incomplete item (self.resumeItem
-- set) doesn't spawn a new item or consume base/base2 again -- that item
-- already physically exists and its materials were already spent when it
-- was first taken out early. This just clears its "unfinished" state and
-- restores its pre-Incomplete-suffix name from TWA_BaseName (captured back
-- when TWA_IncompleteCraftAction.lua first tagged it) -- restoring by saved
-- name rather than string-stripping a suffix off the CURRENT name, since
-- that suffix's own text is a translated string and would silently fail to
-- strip for any language other than the one it was created in.
local function finalizeResumedItem(item, character)
    local md = item:getModData()
    if md.TWA_BaseName then
        item:setName(md.TWA_BaseName)
    end
    md.TWA_Incomplete = nil
    md.TWA_DoneProcedures = nil
    md.TWA_RecipeId = nil
    md.TWA_BaseName = nil
    stampFinisher(item, character)
end

function TWA_FinishCraftAction:perform()
    if self.finishSound and self.character:getEmitter():isPlaying(self.finishSound) then
        self.character:stopOrTriggerSound(self.finishSound)
    end
    if self.resumeItem then
        finalizeResumedItem(self.resumeItem, self.character)
    else
        local inv = self.character:getInventory()
        removeOneOf(self.character, self.recipe.base, self.recipe.baseAlt)
        removeOneOf(self.character, self.recipe.base2, nil)
        local newItem = inv:AddItem(self.recipe.result)
        if newItem then
            applyTier(newItem, self.recipe.result)
            stampFinisher(newItem, self.character)
        end
    end
    ISBaseTimedAction.perform(self)
end

function TWA_FinishCraftAction:new(character, recipe, doneProcedures, resumeItem)
    local o = ISBaseTimedAction.new(self, character)
    o.recipe = recipe
    o.doneProcedures = doneProcedures
    o.resumeItem = resumeItem
    o.maxTime = 100
    o.forceProgressBar = true
    return o
end

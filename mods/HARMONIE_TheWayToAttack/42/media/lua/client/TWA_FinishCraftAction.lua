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
--
-- Request 2026-09-28: "ไม่ว่าจะผ่านกระบวนการไหน ไม่ต้องเปลี่ยนชื่อไอเท็มเลย
-- กันความสับสน" -- this action (and every other one in this mod) must NEVER
-- call item:setName(...) any more, full stop -- an earlier round tagged the
-- rarity tier into the item's own display name (bracket suffix); that's
-- removed entirely now. Tier is still shown to the player, just LIVE off the
-- real item's own current stats in HARMONIE_TWA_TierTooltip.lua's hover hook
-- instead of a name suffix or baked per-instance ModData -- see that file.
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
-- both get consumed on Finish; base2 has no altType of its own. Neither slot
-- is ever pre-consumed by the Incomplete button (HARMONIE_TWA_CraftUI.lua's
-- onIncomplete only bookmarks progress into the base item's own ModData,
-- touching nothing physically) -- so this Finish action always runs the
-- exact same consume-then-spawn steps below, whether or not the recipe being
-- finished was resumed from a bookmarked base item first.
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

function TWA_FinishCraftAction:isValid()
    if not self.character or not self.recipe then return false end
    if not ownsSlot(self.character, self.recipe.base, self.recipe.baseAlt) then return false end
    if not ownsSlot(self.character, self.recipe.base2, nil) then return false end
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
-- สลักชื่อของผู้กดเสร็จสิ้น") and rolls its grade, BOTH as ModData only --
-- never the item's name (request 2026-09-28). The in-character forename+
-- surname is used (not getUsername(), which is MP-account-specific and can
-- be blank/meaningless in singleplayer) -- same real identity vanilla itself
-- already uses for signing things by player (e.g. LastStandSetup.lua,
-- ISCharacterScreen.lua).
local function stampFinisher(item, character)
    local md = item:getModData()
    local desc = character:getDescriptor()
    md.TWA_CraftedBy = desc and (desc:getForename() .. " " .. desc:getSurname()) or ""
    md.TWA_Grade = rollGrade()
end

function TWA_FinishCraftAction:perform()
    if self.finishSound and self.character:getEmitter():isPlaying(self.finishSound) then
        self.character:stopOrTriggerSound(self.finishSound)
    end
    local inv = self.character:getInventory()
    removeOneOf(self.character, self.recipe.base, self.recipe.baseAlt)
    removeOneOf(self.character, self.recipe.base2, nil)
    local newItem = inv:AddItem(self.recipe.result)
    if newItem then stampFinisher(newItem, self.character) end
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

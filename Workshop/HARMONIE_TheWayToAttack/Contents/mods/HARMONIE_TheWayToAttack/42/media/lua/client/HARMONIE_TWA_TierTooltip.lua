--============================================================================
-- HARMONIE_TheWayToAttack -- rarity tier + crafting-progress info on the real
-- item tooltip (client)
--
-- Request 2026-09-26: "the vanilla tooltip doesn't show the item's tier."
--
-- *** REAL LIMITATION (see TWA_FinishCraftAction.lua's own note): the item
-- tooltip's actual content (name + full stat breakdown) is built entirely by
-- `item:DoTooltip(tooltip)`, a JAVA method with no confirmed Lua hook to
-- inject an extra line INSIDE it, and the name line specifically is
-- hardcoded white with no per-item color override at all. Rather than
-- patch that internal sizing/content (`ISToolTipInv:render()` measures itself
-- via `self.item:DoTooltip(self.tooltip)` BEFORE this mod ever sees it --
-- editing that is real vanilla-UI-risk territory, and a mistake there would
-- break tooltips for every item in the game, not just this mod's own), this
-- draws the extra info as SEPARATE small strips directly below the real
-- tooltip instead: `ISToolTipInv.render` is wrapped (call the original
-- first, then draw the extra strips using the box's own already-computed
-- self.x/self.y/self.width/self.height) so the real tooltip's own layout is
-- never touched. Scope: this only covers the inventory-list hover tooltip
-- (`ISToolTipInv`, confirmed the one `ISInventoryPane.lua` creates) -- other
-- tooltip contexts (hotbar, equipped-slot icons) are not covered, to keep
-- this hook small and low-risk rather than chasing every tooltip variant.
--
-- Request 2026-09-28: "tooltip stats อาวุธ ให้แสดง DPS และทุก stats ของ
-- ไอเท็มชิ้นนั้นจริงๆ และต้องไม่ใช่ stats ตายตัว ต้องเป็นแบบ dynamic จากการ
-- คำนวน stats ของอาวุธนั้นจริงๆ กรณีที่อยากปรับดาเมจอาวุธด้วยดีบัก ทำแบบนี้
-- กับระบบ tier ใน tooltip ด้วย" -- for any REAL weapon (instanceof
-- HandWeapon, checked via TWAPartSystem.IsMeleeWeapon -- same real check
-- this mod's own weapon-modification UI already uses), every stat AND the
-- tier/DPS shown here is now computed LIVE off the item's own current
-- getters every single render, not looked up from the generated
-- TWARecipeData.Stats table -- so a debug/admin edit to an item's damage (or
-- any other live-gettable field) is reflected immediately, and this also now
-- covers ANY real weapon at all, including ones this mod's own generator
-- never scanned (other mods' weapons, anything vanilla). See the confirmed-
-- vs-unconfirmed getter table below -- NOT every stat has a confirmed live
-- Lua getter anywhere in vanilla's own codebase; those fall back to the
-- baked value defensively rather than guessing a method name that might not
-- exist and crash every tooltip in the game.
--
-- Non-weapon items (this mod's own Metallurgy materials, hand-assigned a
-- tier since they have no combat stats at all) still use the OLD static
-- fullType-keyed lookup unchanged -- there's no live weapon stat to read on
-- a Normal-type item, so dynamic computation doesn't apply to them.
--
-- Request 2026-09-27/28 (multiplayer collaborative crafting): a base item
-- bookmarked via the Incomplete button (HARMONIE_TWA_CraftUI.lua's
-- onIncomplete) carries TWA_RecipeId/TWA_DoneProcedures in its own ModData
-- -- shown here as a real procedure checklist (done/not-done, same
-- translated names as the crafting UI itself), independent of the tier/stat
-- strips above (a bookmarked base item is very often NOT itself a weapon).
-- A truly finished item instead carries TWA_CraftedBy/TWA_Grade (stamped
-- once, at the real Finish, by TWA_FinishCraftAction.lua) -- shown as a
-- separate small strip. The two are mutually exclusive per item (a
-- bookmarked base item is never also a finished result, and vice versa).
--============================================================================

require "ISUI/ISToolTipInv"

-- Full 8-tier fixed-DPS scale -- SAME thresholds gen_craftdata.js bakes for
-- non-weapon items, ported to Lua so weapon tier can be computed live here
-- too (see tierFromDps below). Legendary and Prototype swapped positions
-- (request 2026-09-26, full explicit table): Legendary is now DPS < 10,
-- Prototype is now the unbounded top tier DPS >= 10.
local TIER_NAMES = {
    [1] = "Junk", [2] = "Common", [3] = "Uncommon", [4] = "Rare", [5] = "Epic",
    [6] = "Elite", [7] = "Legendary", [8] = "Prototype",
}
local TIER_COLOR = {
    [1] = { r = 1.0, g = 1.0, b = 1.0 }, [2] = { r = 0.3, g = 0.7, b = 1.0 }, [3] = { r = 0.25, g = 0.85, b = 0.3 },
    [4] = { r = 1.0, g = 0.45, b = 0.75 }, [5] = { r = 0.65, g = 0.3, b = 0.95 }, [6] = { r = 1.0, g = 0.55, b = 0.15 },
    [7] = { r = 1.0, g = 0.85, b = 0.15 }, [8] = { r = 0.85, g = 0.2, b = 0.15 },
}
local DPS_TIER_THRESHOLDS = { 0.25, 0.5, 1, 2, 4, 8, 10 }
local function tierFromDps(dps)
    for i, threshold in ipairs(DPS_TIER_THRESHOLDS) do
        if dps < threshold then return i end
    end
    return #DPS_TIER_THRESHOLDS + 1
end

-- Full weapon stat grid for the NON-weapon (static, fullType-keyed) path
-- only -- same 2-column layout and same translation keys HARMONIE_TWA_
-- CraftUI.lua's own STAT_GRID already uses.
local STATIC_STAT_GRID = {
    { { key = "minDamage", labelKey = "IGUI_TWA_Stat_MinDamage", fmt = "%.1f" },
      { key = "maxDamage", labelKey = "IGUI_TWA_Stat_MaxDamage", fmt = "%.1f" } },
    { { key = "critChance", labelKey = "IGUI_TWA_Stat_CritChance", fmt = "%.0f%%" },
      { key = "maxRange", labelKey = "IGUI_TWA_Stat_Range", fmt = "%.2f" } },
    { { key = "baseSpeed", labelKey = "IGUI_TWA_Stat_Speed", fmt = "%.2f", default = 1.0 },
      { key = "knockdownMod", labelKey = "IGUI_TWA_Stat_Knockdown", fmt = "%.1f" } },
    { { key = "conditionMax", labelKey = "IGUI_TWA_Stat_Condition", fmt = "%.0f" },
      { key = "weight", labelKey = "IGUI_TWA_StatWeight", fmt = "%.1f" } },
}

-- Confirmed-real live Lua getters (grep-verified against the actual game
-- install's own lua, primarily client/ISUI/AdminPanel/ISItemEditPanel.lua --
-- the real debug item-stat editor -- which reads every one of these cold,
-- with no prior setter call needed, confirming each always reflects the
-- item's live effective value): getMinDamage, getMaxDamage, getMaxRange,
-- getConditionMax, getActualWeight. NOT confirmed anywhere in vanilla's own
-- lua (no call site exists on an item/weapon instance at all, for
-- BaseSpeed/CriticalChance/KnockdownMod specifically) -- attempted
-- defensively via pcall with a safe fallback to the baked script value
-- rather than assumed real, so a missing/renamed method degrades gracefully
-- instead of erroring every tooltip in the game.
-- Checks the method exists BEFORE calling it (indexing a missing method on
-- a Java object just gives nil) instead of calling it blind inside pcall:
-- the game's debugger stops on every Lua error even when pcall catches it,
-- and this runs on every tooltip render (bug report 2026-09-28).
local function liveOrFallback(item, methodName, fallback)
    local m = item[methodName]
    if not m then return fallback end
    local ok, v = pcall(m, item)
    if ok and v ~= nil then return v end
    return fallback
end

local function drawStatStrip(panel, x, y, w, label, color, font)
    local textH = getTextManager():getFontHeight(font)
    local stripH = textH + 6
    panel:drawRect(x, y, w, stripH - 2, 0.85, 0.05, 0.05, 0.05)
    panel:drawRectBorder(x, y, w, stripH - 2, 0.7, color.r, color.g, color.b)
    panel:drawText(label, x + 5, y + 3, 0, 0, 0, 0.8, font)
    panel:drawText(label, x + 4, y + 2, color.r, color.g, color.b, 1, font)
    return stripH
end

-- `gridDef` is a flat list of {value, labelKey, fmt} triples, 2 per visual
-- row (ceil(#gridDef/2) rows).
local function drawGrid(panel, x, y, w, gridDef, font, rowH)
    local gridH = rowH * math.ceil(#gridDef / 2) + 4
    panel:drawRect(x, y, w, gridH - 2, 0.85, 0.05, 0.05, 0.05)
    panel:drawRectBorder(x, y, w, gridH - 2, 0.6, 0.4, 0.4, 0.4)
    local colW = (w - 4) / 2
    local ry = y + 3
    for i, cell in ipairs(gridDef) do
        local col = (i - 1) % 2
        local cx = x + 4 + col * colW
        local valueText = string.format(cell[3], cell[1])
        panel:drawText(getText(cell[2]) .. ": " .. valueText, cx, ry, 0.85, 0.85, 0.85, 1, font)
        if col == 1 then ry = ry + rowH end
    end
    if #gridDef % 2 == 1 then ry = ry + rowH end
    return gridH
end

-- Grows the panel's own real height to fit each extra strip BEFORE drawing
-- it (rather than drawing past the original self.height and hoping nothing
-- clips it) -- ISScrollingListBox's own real source (read earlier this
-- session while fixing a real missing-scrollbar bug) confirmed PZ UI panels
-- manage their own clip/stencil around their declared width/height, so
-- drawing beyond it is not safe to assume works.
local origRender = ISToolTipInv.render
-- Round 6 (request 2026-09-28: "ให้ stats ใน tooltip อาวุธ ให้มี ประเภท อีก 1
-- ค่า แสดงอยู่ก่อน dps"): the weapon's category, in plain English like the
-- crafting window's category tabs ("SmallBlade" -> "Small Blade").
local function weaponTypeText(item, stats)
    local cat = stats and stats.categories
    if (not cat or cat == "") and item.getCategories then
        local list = item:getCategories()
        if list and list:size() > 0 then cat = tostring(list:get(0)) end
    end
    if not cat or cat == "" then return nil end
    cat = cat:match("^[^,;%s]+") or cat
    return (cat:gsub("(%l)(%u)", "%1 %2"))
end

function ISToolTipInv:render()
    origRender(self)
    if not self.item then return end
    local item = self.item
    local ok, fullType = pcall(function() return item:getFullType() end)
    if not ok or not fullType then return end

    local font = UIFont.Small
    local textH = getTextManager():getFontHeight(font)
    local rowH = textH + 3
    local y = self.height

    if TWAPartSystem.IsMeleeWeapon(item) then
        -- Fully live: computed fresh from the real item instance every
        -- render, not from the generated Stats table (request 2026-09-28).
        -- Request 2026-09-28 (follow-up): "อาวุธโชว์ให้ครบทุก stats นะ ตาม
        -- จำนวนที่แสดงใน ui เลย" -- show every one of the SAME 13 stats
        -- HARMONIE_TWA_CraftUI.lua's own center-panel STAT_GRID shows (DPS +
        -- 12), not just the 8 this file originally covered. The 4 added
        -- here (ConditionLowerChance/PushBackMod/Handedness/AttackStyle)
        -- use the same confirmed-vs-best-effort split as before:
        -- getConditionLowerChance()/isTwoHandWeapon() are confirmed real
        -- (see 8.12); PushBackMod/SubCategory have no confirmed live getter
        -- anywhere in vanilla's own lua, so they go through the same
        -- pcall+fallback path as BaseSpeed/CriticalChance/KnockdownMod.
        local stats = TWARecipeData and TWARecipeData.Stats and TWARecipeData.Stats[fullType]
        local minD, maxD = item:getMinDamage(), item:getMaxDamage()
        local maxRange = item:getMaxRange()
        local condMax = item:getConditionMax()
        local condLower = item:getConditionLowerChance()
        local weight = item:getActualWeight()
        local twoHanded = item:isTwoHandWeapon()
        local baseSpeed = liveOrFallback(item, "getBaseSpeed", (stats and stats.baseSpeed) or 1.0)
        local critChance = liveOrFallback(item, "getCriticalChance", (stats and stats.critChance) or 0)
        local knockdownMod = liveOrFallback(item, "getKnockdownMod", (stats and stats.knockdownMod) or 0)
        local pushBackMod = liveOrFallback(item, "getPushBackMod", (stats and stats.pushBackMod) or 0)
        local subCategory = liveOrFallback(item, "getSubCategory", stats and stats.subCategory)
        local dps = ((minD + maxD) / 2) * baseSpeed
        local tier = tierFromDps(dps)
        local c = TIER_COLOR[tier] or { r = 1, g = 1, b = 1 }
        local label = TIER_NAMES[tier] .. " (DPS " .. string.format("%.2f", dps) .. ")"

        self:setHeight(self.height + (textH + 6))
        y = y + drawStatStrip(self, 2, y, self.width - 4, label, c, font)

        local gridDef = {}
        local typeText = weaponTypeText(item, stats)
        if typeText then gridDef[1] = { typeText, "IGUI_TWA_Stat_Type", "%s" } end
        for _, cellDef in ipairs({
            { dps, "IGUI_TWA_Stat_DPS", "%.2f" },
            { minD, "IGUI_TWA_Stat_MinDamage", "%.1f" }, { maxD, "IGUI_TWA_Stat_MaxDamage", "%.1f" },
            { baseSpeed, "IGUI_TWA_Stat_Speed", "%.2f" }, { weight, "IGUI_TWA_StatWeight", "%.1f" },
            { maxRange, "IGUI_TWA_Stat_Range", "%.2f" }, { critChance, "IGUI_TWA_Stat_CritChance", "%.0f%%" },
            { condMax, "IGUI_TWA_Stat_Condition", "%.0f" }, { condLower, "IGUI_TWA_Stat_Durability", "1:%.0f" },
            { knockdownMod, "IGUI_TWA_Stat_Knockdown", "%.1f" }, { pushBackMod, "IGUI_TWA_Stat_PushPower", "%.2f" },
        }) do gridDef[#gridDef + 1] = cellDef end
        local handednessKey = twoHanded and "IGUI_TWA_Stat_TwoHanded" or "IGUI_TWA_Stat_OneHanded"
        gridDef[#gridDef + 1] = { getText(handednessKey), "IGUI_TWA_Stat_Handedness", "%s" }
        if subCategory and subCategory ~= "" then
            gridDef[#gridDef + 1] = { subCategory, "IGUI_TWA_Stat_AttackStyle", "%s" }
        end
        local gridH = rowH * math.ceil(#gridDef / 2) + 4
        self:setHeight(self.height + gridH)
        drawGrid(self, 2, y, self.width - 4, gridDef, font, rowH)
        y = y + gridH
    else
        -- Non-weapon path -- unchanged static fullType-keyed lookup (this
        -- mod's own Metallurgy materials, hand-assigned a tier since they
        -- have no combat stats to derive one from).
        local stats = TWARecipeData and TWARecipeData.Stats and TWARecipeData.Stats[fullType]
        local tier = stats and stats.tier
        if tier and TIER_NAMES[tier] then
            local c = TIER_COLOR[tier] or { r = 1, g = 1, b = 1 }
            local label = TIER_NAMES[tier]
            if stats.dps then
                label = label .. " (DPS " .. string.format("%.2f", stats.dps) .. ")"
            end
            self:setHeight(self.height + (textH + 6))
            y = y + drawStatStrip(self, 2, y, self.width - 4, label, c, font)

            local gridDef = {}
            for _, row in ipairs(STATIC_STAT_GRID) do
                for _, cellDef in ipairs(row) do
                    local v = stats[cellDef.key]
                    if v == nil then v = cellDef.default end
                    if v ~= nil then
                        gridDef[#gridDef + 1] = { v, cellDef.labelKey, cellDef.fmt }
                    end
                end
            end
            if #gridDef > 0 then
                local gridH = rowH * math.ceil(#gridDef / 2) + 4
                self:setHeight(self.height + gridH)
                drawGrid(self, 2, y, self.width - 4, gridDef, font, rowH)
                y = y + gridH
            end
        end
    end

    -- Request 2026-09-27/28: a bookmarked base item's real procedure
    -- checklist (which of its recipe's procedures are done vs not), read
    -- straight off ITS OWN ModData -- see HARMONIE_TWA_CraftUI.lua's
    -- onIncomplete/TWACraftUI.getRecipeById.
    local recipeId = item:getModData().TWA_RecipeId
    local recipe = recipeId and TWACraftState.getRecipeById(recipeId)
    if recipe then
        local doneTable = item:getModData().TWA_DoneProcedures or {}
        -- Request 2026-09-28: each procedure's quality WORD (not a number)
        -- next to it; a done procedure from a bookmark made before this
        -- update has no word and reads as Good (TWACraftState.wordFor).
        local qualityTable = item:getModData().TWA_ProcQuality or {}
        local showWords = true
        local resultItem = ScriptManager.instance:getItem(recipe.result)
        local header = getText("IGUI_TWA_ResumingItem") .. " (" ..
            (resultItem and resultItem:getDisplayName() or recipe.result) .. ")"
        local lines = { { text = header, color = { r = 0.6, g = 0.8, b = 1 } } }
        if item:getModData().TWA_Incomplete then
            lines[#lines + 1] = { text = getText("IGUI_TWA_Tooltip_Unfinished"), color = { r = 1, g = 0.45, b = 0.35 } }
        end
        for _, procId in ipairs(recipe.procedures) do
            local proc = TWAProcedures.List[procId]
            if proc then
                local done = doneTable[procId] == true
                local mark = done and "+" or "-"
                local color = done and { r = 0.5, g = 0.9, b = 0.5 } or { r = 0.9, g = 0.5, b = 0.5 }
                local text = mark .. " " .. getText(proc.nameKey)
                local word = showWords and TWACraftState.wordFor(procId, doneTable, qualityTable)
                if word then
                    text = text .. ": " .. TWACraftState.wordText(word)
                    color = TWACraftState.WORD_COLOR[word]
                end
                lines[#lines + 1] = { text = text, color = color }
            end
        end
        local xh = rowH * #lines + 4
        self:setHeight(self.height + xh)
        self:drawRect(2, y, self.width - 4, xh - 2, 0.85, 0.05, 0.05, 0.05)
        self:drawRectBorder(2, y, self.width - 4, xh - 2, 0.6, 0.5, 0.7, 0.95)
        local xry = y + 3
        for _, l in ipairs(lines) do
            self:drawText(l.text, 6, xry, l.color.r, l.color.g, l.color.b, 1, font)
            xry = xry + rowH
        end
        y = y + xh
    end

    -- Crafted-by / grade -- stamped once, at the real Finish
    -- (TWA_FinishCraftAction.lua's stampFinisher), mutually exclusive with
    -- the checklist above (a finished item never carries TWA_RecipeId).
    -- Request 2026-09-28: the overall quality word (TWA_Quality) above the
    -- grade; the grade is now rolled from that quality's pool at Finish
    -- (TWACraftState.rollGrade), replacing the old flat rarity roll, and
    -- still shows on the same line it always did.
    local craftedBy = item:getModData().TWA_CraftedBy
    local grade = item:getModData().TWA_Grade
    local quality = item:getModData().TWA_Quality
    local gemState = item:getModData().TWA_GemState -- round 17: "Raw" from the Gemstone recipe
    if craftedBy or grade or quality or gemState then
        local lines = {}
        if craftedBy and craftedBy ~= "" then
            lines[#lines + 1] = { text = getText("IGUI_TWA_TooltipCraftedBy", craftedBy), color = { r = 0.85, g = 0.85, b = 0.85 } }
        end
        if gemState then
            lines[#lines + 1] = { text = getText("IGUI_TWA_TooltipGemState", getText("IGUI_TWA_GemState_" .. gemState)), color = { r = 0.7, g = 0.85, b = 1 } }
        end
        if quality and TWACraftState.isWord(quality) then
            lines[#lines + 1] = { text = getText("IGUI_TWA_TooltipQuality", TWACraftState.wordText(quality)), color = TWACraftState.WORD_COLOR[quality] }
        end
        if grade then
            local GRADE_COLOR = {
                S = { r = 1.0, g = 0.85, b = 0.15 }, A = { r = 0.4, g = 0.9, b = 1.0 }, B = { r = 0.4, g = 0.9, b = 0.4 },
                C = { r = 0.75, g = 0.9, b = 0.4 }, D = { r = 0.9, g = 0.8, b = 0.4 }, E = { r = 0.95, g = 0.6, b = 0.3 },
                F = { r = 0.85, g = 0.35, b = 0.3 },
            }
            local gc = GRADE_COLOR[grade] or { r = 1, g = 1, b = 1 }
            lines[#lines + 1] = { text = getText("IGUI_TWA_TooltipGrade", grade), color = gc }
        end
        local xh = rowH * #lines + 4
        self:setHeight(self.height + xh)
        self:drawRect(2, y, self.width - 4, xh - 2, 0.85, 0.05, 0.05, 0.05)
        self:drawRectBorder(2, y, self.width - 4, xh - 2, 0.6, 0.4, 0.4, 0.4)
        local xry = y + 3
        for _, l in ipairs(lines) do
            self:drawText(l.text, 6, xry, l.color.r, l.color.g, l.color.b, 1, font)
            xry = xry + rowH
        end
    end
end

--============================================================================
-- HARMONIE_TheWayToAttack -- rarity tier label on the real item tooltip (client)
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
-- draws the tier as a SEPARATE small label directly below the real tooltip
-- instead: `ISToolTipInv.render` is wrapped (call the original first, then
-- draw one extra line using the box's own already-computed
-- self.x/self.y/self.width/self.height) so the real tooltip's own layout is
-- never touched. Scope: this only covers the inventory-list hover tooltip
-- (`ISToolTipInv`, confirmed the one `ISInventoryPane.lua` creates) -- other
-- tooltip contexts (hotbar, equipped-slot icons) are not covered, to keep
-- this hook small and low-risk rather than chasing every tooltip variant.
--
-- Lookup is BY FULLTYPE in `TWARecipeData.Stats` (not per-instance ModData
-- any more) -- request 2026-09-26: "items not crafted by the mod should
-- also be included in the count, and show a tier when hovered too". The
-- Stats table now bakes a tier for every real vanilla melee weapon (found/
-- looted, not just ones this mod actually crafts) plus all 137 HARMONIE
-- items, so any hovered weapon in either pool resolves a tier here, whether
-- or not this exact item instance ever passed through our crafting UI.
-- Tier names are NOT translated (request 2026-09-26: "ไม่ต้องแปลชื่อ tier")
-- -- shown as the plain English label directly. A second strip below the
-- tier line shows the full weapon stat grid too (request 2026-09-26:
-- "stats อาวุธเอาไปแสดงใน tooltip ด้วย เรียงให้ดูดี").
--============================================================================

require "ISUI/ISToolTipInv"

-- Full 8-tier fixed-DPS scale (Junk/Common/Uncommon/Rare/Epic/Elite/
-- Prototype/Legendary) -- restored after a brief Prototype-removal turned
-- out to be a misread; both Junk and Prototype are only hidden from the
-- CraftUI filter row, not removed here -- any hovered Junk/Prototype item
-- still shows its real tier in this tooltip.
local TIER_NAMES = {
    [1] = "Junk", [2] = "Common", [3] = "Uncommon", [4] = "Rare", [5] = "Epic",
    [6] = "Elite", [7] = "Prototype", [8] = "Legendary",
}
local TIER_COLOR = {
    [1] = { r = 1.0, g = 1.0, b = 1.0 }, [2] = { r = 0.3, g = 0.7, b = 1.0 }, [3] = { r = 0.25, g = 0.85, b = 0.3 },
    [4] = { r = 1.0, g = 0.45, b = 0.75 }, [5] = { r = 0.65, g = 0.3, b = 0.95 }, [6] = { r = 1.0, g = 0.55, b = 0.15 },
    [7] = { r = 0.85, g = 0.2, b = 0.15 }, [8] = { r = 1.0, g = 0.85, b = 0.15 },
}

-- Full weapon stat grid (request 2026-09-26: "stats อาวุธเอาไปแสดงใน
-- tooltip ด้วย เรียงให้ดูดี" -- show the weapon's stats in the tooltip too,
-- arranged nicely) -- same 2-column layout and same translation keys
-- HARMONIE_TWA_CraftUI.lua's own STAT_GRID already uses, so the crafting
-- window and the real-item tooltip present stats identically.
local STAT_GRID = {
    { { key = "minDamage", labelKey = "IGUI_TWA_Stat_MinDamage", fmt = "%.1f" },
      { key = "maxDamage", labelKey = "IGUI_TWA_Stat_MaxDamage", fmt = "%.1f" } },
    { { key = "critChance", labelKey = "IGUI_TWA_Stat_CritChance", fmt = "%.0f%%" },
      { key = "maxRange", labelKey = "IGUI_TWA_Stat_Range", fmt = "%.2f" } },
    { { key = "baseSpeed", labelKey = "IGUI_TWA_Stat_Speed", fmt = "%.2f", default = 1.0 },
      { key = "knockdownMod", labelKey = "IGUI_TWA_Stat_Knockdown", fmt = "%.1f" } },
    { { key = "conditionMax", labelKey = "IGUI_TWA_Stat_Condition", fmt = "%.0f" },
      { key = "weight", labelKey = "IGUI_TWA_StatWeight", fmt = "%.1f" } },
}

-- Grows the panel's own real height to fit the extra line BEFORE drawing it
-- (rather than drawing past the original self.height and hoping nothing
-- clips it) -- ISScrollingListBox's own real source (read earlier this
-- session while fixing a real missing-scrollbar bug) confirmed PZ UI panels
-- manage their own clip/stencil around their declared width/height, so
-- drawing beyond it is not safe to assume works. If the clip region for
-- THIS specific widget instance turns out to be locked once per frame
-- before render() runs (rather than re-checked per draw call), growing
-- self.height here still self-corrects within one frame, since the same
-- ISToolTipInv instance persists for as long as the mouse keeps hovering
-- the item (ISInventoryPane.lua creates it once per hover, not every
-- frame) -- worst case is a single invisible frame, not a lasting bug.
local origRender = ISToolTipInv.render
function ISToolTipInv:render()
    origRender(self)
    if not self.item then return end
    local ok, fullType = pcall(function() return self.item:getFullType() end)
    if not ok or not fullType then return end
    local stats = TWARecipeData and TWARecipeData.Stats and TWARecipeData.Stats[fullType]
    local tier = stats and stats.tier
    if not tier or not TIER_NAMES[tier] then return end
    local c = TIER_COLOR[tier] or { r = 1, g = 1, b = 1 }
    -- Base DPS shown alongside the tier name (request 2026-09-26: "tooltip
    -- ก็ให้ขึ้นเหมือนกัน ตรงที่แสดงระดับอาวุธ" -- same spot that shows the
    -- tier) -- the exact real number that tier was ranked by.
    local label = TIER_NAMES[tier]
    if stats.dps then
        label = label .. " (DPS " .. string.format("%.2f", stats.dps) .. ")"
    end
    local font = UIFont.Small
    local textH = getTextManager():getFontHeight(font)
    local stripH = textH + 6
    local rowH = textH + 3
    local gridH = rowH * #STAT_GRID + 4
    local baseH = self.height
    self:setHeight(baseH + stripH + gridH)

    local ly = baseH + 2
    self:drawRect(2, ly, self.width - 4, stripH - 2, 0.85, 0.05, 0.05, 0.05)
    self:drawRectBorder(2, ly, self.width - 4, stripH - 2, 0.7, c.r, c.g, c.b)
    self:drawText(label, 7, ly + 3, 0, 0, 0, 0.8, font)
    self:drawText(label, 6, ly + 2, c.r, c.g, c.b, 1, font)

    local gy = baseH + stripH
    self:drawRect(2, gy, self.width - 4, gridH - 2, 0.85, 0.05, 0.05, 0.05)
    self:drawRectBorder(2, gy, self.width - 4, gridH - 2, 0.6, 0.4, 0.4, 0.4)
    local colW = (self.width - 8) / 2
    local ry = gy + 3
    for _, row in ipairs(STAT_GRID) do
        for col, cellDef in ipairs(row) do
            local v = stats[cellDef.key]
            if v == nil then v = cellDef.default end
            if v ~= nil then
                local cx = 6 + (col - 1) * colW
                local valueText = string.format(cellDef.fmt, v)
                self:drawText(getText(cellDef.labelKey) .. ": " .. valueText, cx, ry, 0.85, 0.85, 0.85, 1, font)
            end
        end
        ry = ry + rowH
    end
end

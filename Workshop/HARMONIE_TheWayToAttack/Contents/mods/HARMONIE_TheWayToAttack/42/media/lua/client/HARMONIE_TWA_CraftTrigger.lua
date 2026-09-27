--============================================================================
-- HARMONIE_TheWayToAttack -- crafting UI trigger (client)
--
-- Registers a hotkey (default L) and a right-click inventory context menu
-- entry to open the procedural weapon-crafting window. Unlike the weapon
-- *modification* UI (HARMONIE_TWA_PartsTrigger.lua), this isn't gated on
-- holding any particular item -- crafting starts from raw materials, so the
-- option is always available.
--
-- Request 2026-09-27 (multiplayer collaborative crafting), verbatim:
-- "คลิกขวาเปิด ui ผ่านอาวุธจะค้นหาชื่ออาวุธนั้นโดยอัตโนมัติ / คลิกขวาเปิด ui
-- ผ่านชิ้นส่วนตั้งต้นจะค้นหาด้วยชื่อของชิ้นส่วนโดยอัตโนมัติ / คลิกขวาเปิด ui
-- ผ่านไอเท็มอื่น พื้น หรือโต๊ะต่างๆ จะเปิดขึ้นมาโดยไม่มีการค้นหาอัติโนมัติ" --
-- right-clicking a weapon or a base/material item should prefill the
-- crafting UI's search with that item's own name; right-clicking anything
-- else, the floor, or a table should open it blank. Implemented with real
-- vanilla's own architecture split rather than one combined check:
-- OnFillInventoryObjectContextMenu (right-clicking a specific item you're
-- carrying) is the only one that ever hands over a real item instance to
-- classify, so it's the only place auto-search applies;
-- OnFillWorldObjectContextMenu (right-clicking the ground / a workbench /
-- any other world object) covers "floor or tables" and always opens blank,
-- unchanged from before.
--============================================================================

require "ISUI/ISInventoryPane"

local bind = {}
bind.value = "[KeySetting_TWACraft]"
table.insert(keyBinding, bind)

bind = {}
bind.value = "TWA_OpenCraftUI"
bind.key = Keyboard.KEY_L
table.insert(keyBinding, bind)

Events.OnKeyPressed.Add(function(key)
    local wanted = getCore():getKey("TWA_OpenCraftUI")
    if not wanted or key ~= wanted then return end
    local player = getPlayer()
    if not player then return end
    TWACraftUI.toggle()
end)

-- B42 passes playerNum (integer) as the first argument, not the player object.
--
-- `items` is the RAW list ISInventoryPaneContextMenu.createMenu hands to
-- this event -- its own real source comment (line 38-39 of that file):
-- "items is a list that could contain either InventoryItem objects, OR a
-- table with a list of InventoryItem objects in .items. Also there is a
-- duplicate entry first in the list, so ignore that." ISInventoryPane.
-- getActualUniqueItems is vanilla's own real normalizer for exactly this
-- (confirmed from ISInventoryPane.lua's own source) -- collapses that down
-- to one representative real InventoryItem per selected stack/type, which is
-- all that's needed here since a right-click only ever needs to classify
-- ONE item (the one the menu was opened on).
Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local actual = ISInventoryPane.getActualUniqueItems(items)
    local target = actual[1]
    local searchName, resumeItem
    if target then
        -- Request 2026-09-27/28: a base item previously bookmarked via the
        -- Incomplete button carries its own saved progress in ModData (see
        -- HARMONIE_TWA_CraftUI.lua's onIncomplete) -- right-clicking THAT
        -- exact item resumes it directly instead of just prefilling a
        -- search.
        if target:getModData().TWA_RecipeId then
            resumeItem = target
        end
        searchName = TWACraftUI.autoSearchNameFor(target:getFullType())
    end

    context:addOption(getText("IGUI_TWA_ContextMenu_OpenCraftUI"), player, function()
        TWACraftUI.open(player, searchName, resumeItem)
    end)
end)

-- Request 2026-09-27: right-clicking the ground/a workbench/any other world
-- object should also offer to open the crafting UI, always blank (no auto-
-- search -- there's no single carried item to classify here, and the
-- request explicitly separates this case from the inventory one above). Not
-- gated on `worldobjects` at all -- same "always available" philosophy this
-- trigger already uses for the hotkey and the inventory option.
Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldobjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    context:addOption(getText("IGUI_TWA_ContextMenu_OpenCraftUI"), player, function()
        TWACraftUI.open(player)
    end)
end)

--============================================================================
-- HARMONIE_TheWayToAttack -- crafting UI trigger (client)
--
-- Registers a hotkey (default L) and a right-click inventory context menu
-- entry to open the procedural weapon-crafting window. Unlike the weapon
-- *modification* UI (HARMONIE_TWA_PartsTrigger.lua), this isn't gated on
-- holding any particular item -- crafting starts from raw materials, so the
-- option is always available.
--============================================================================

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
Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    context:addOption(getText("IGUI_TWA_ContextMenu_OpenCraftUI"), player, function()
        TWACraftUI.open(player)
    end)
end)

--============================================================================
-- HARMONIE_TheWayToAttack -- weapon parts UI trigger (client)
--
-- Registers a hotkey (default K) and a right-click context menu entry to
-- open the melee weapon modification panel, only when a melee weapon is
-- held. Applies to ANY melee weapon (vanilla, other mods, or ours).
--============================================================================

-- Key binding: category + hotkey
local bind = {}
bind.value = "[KeySetting_TWAParts]"
table.insert(keyBinding, bind)

bind = {}
bind.value = "TWA_OpenPartsUI"
bind.key = Keyboard.KEY_K
table.insert(keyBinding, bind)

-- Hotkey handler
Events.OnKeyPressed.Add(function(key)
    local wanted = getCore():getKey("TWA_OpenPartsUI")
    if not wanted or key ~= wanted then return end
    local player = getPlayer()
    if not player then return end
    local weapon = player:getPrimaryHandItem()
    if weapon and TWAPartSystem.IsMeleeWeapon(weapon) then
        TWAPartsUI.toggle()
    end
end)

-- Context menu handler
-- B42 passes playerNum (integer) as the first argument, not the player object.
Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local weapon = player:getPrimaryHandItem()
    if not TWAPartSystem.IsMeleeWeapon(weapon) then return end
    context:addOption(getText("IGUI_TWA_ContextMenu_ModifyWeapon"), weapon, function()
        TWAPartsUI.open(player)
    end)
end)

--============================================================================
-- BladesmithSystem — melee inspection trigger (client)
--
-- Registers the hotkey (default B) and a right-click context menu entry to
-- open the melee weapon modification panel, only when a melee weapon is held.
--============================================================================

-- Key binding: category + hotkey
local bind = {}
bind.value = "[KeySetting_Bladesmith]"
table.insert(keyBinding, bind)

bind = {}
bind.value = "OpenBladeSmith"
bind.key = Keyboard.KEY_B
table.insert(keyBinding, bind)

-- Hotkey handler
Events.OnKeyPressed.Add(function(key)
    local wanted = getCore():getKey("OpenBladeSmith")
    if not wanted or key ~= wanted then return end
    local player = getPlayer()
    if not player then return end
    local weapon = player:getPrimaryHandItem()
    if weapon and ABMeleePartSystem.IsMeleeWeapon(weapon) then
        ABMeleeInspect.toggle()
    end
end)

-- Context menu handler
-- B42 passes playerNum (integer) as the first argument, not the player object.
Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local weapon = player:getPrimaryHandItem()
    if not ABMeleePartSystem.IsMeleeWeapon(weapon) then return end
    context:addOption("改造武器", weapon, function()
        ABMeleeInspect.open(player)
    end)
end)

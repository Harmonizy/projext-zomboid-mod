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
        TWALog("Trigger", "parts window key: %s", TWALogType(weapon))
        TWAPartsUI.toggle()
    else
        TWALog("Trigger", "parts window key: no melee weapon in hand -- not opened")
    end
end)

-- Context menu handler
-- Switched OFF for now (request 2026-09-28: "ปิดการคลิกขวาดัดแปลงอาวุธไป
-- ก่อน เดี๋ยวค่อยพัฒนาต่อ") -- flip this back to true to bring the
-- right-click "Modify Weapon" option back. The hotkey above is untouched.
local CONTEXT_MENU_ENABLED = false

-- B42 passes playerNum (integer) as the first argument, not the player object.
Events.OnFillInventoryObjectContextMenu.Add((HARMONIE_Ours or function(f) return f end)(function(playerNum, context, items)
    if not CONTEXT_MENU_ENABLED then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local weapon = player:getPrimaryHandItem()
    if not TWAPartSystem.IsMeleeWeapon(weapon) then return end
    context:addOption(getText("IGUI_TWA_ContextMenu_ModifyWeapon"), weapon, function()
        TWAPartsUI.open(player)
    end)
end, "TWA"))

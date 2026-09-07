--[[
    Right-click "Drink Herbal Remedy" option, added to any HerbalRemedy item
    the player is holding. This is the standard vanilla pattern for attaching
    a custom action to a plain item without a full ISBaseTimedAction.
]]--

require "CampFeverMod/CampFever_Disease"

local function onFillInventoryObjectContextMenu(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    for _, v in ipairs(items) do
        -- `items` entries are sometimes the item itself, sometimes {items={item, ...}}
        local item = v.items and v.items[1] or v
        if instanceof(item, "InventoryItem") and item:getFullType() == "CampFeverMod.HerbalRemedy" then
            context:addOption("Drink Herbal Remedy", player, function()
                local inventory = player:getInventory()
                if inventory then
                    inventory:Remove(item)
                end
                CampFeverMod.Disease.Cure(player)
            end)
            break
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)

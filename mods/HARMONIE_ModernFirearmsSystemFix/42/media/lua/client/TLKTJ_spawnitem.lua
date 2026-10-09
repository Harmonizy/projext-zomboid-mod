local function initruinsItems(_player)
    local inv = _player:getInventory()
    inv:AddItem("XY_OF")
end

Events.OnNewGame.Add(initruinsItems)


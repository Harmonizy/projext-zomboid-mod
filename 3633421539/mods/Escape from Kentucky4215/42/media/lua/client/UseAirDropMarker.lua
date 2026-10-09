AirDropFunction = AirDropFunction or {}

function AirDropFunction.checksqisright(sq)
    if not sq then
        return false
    end
    if sq:getBuilding() then
        return false
    end
    if sq:getObjects() then
        for i = 1, sq:getObjects():size() do
            local sprite = sq:getObjects():get(i - 1):getSprite()
            if sprite then
                local Properties = sprite:getProperties()
                if Properties then
                    if Properties:Is(IsoFlagType.solid) or Properties:Is(IsoFlagType.solidtrans) then
                        return false
                    end
                end
            end
        end
    end
    return true
end

function AirDropFunction.AddSoundPluse()
    local player = getPlayer()
    if not player then
        return
    end
    getWorldSoundManager():addSound(player, player:getX(), player:getY(), player:getZ(), 200, 200);
end

AirDropFunction.AirDropActionList = {}
local MaxDistance = 50
local function tablesize(t)
    local count = 0
    for _, _ in pairs(t) do
        count = count + 1
    end
    return count
end
function AirDropFunction.UpdateAirDropAction()
    for Time, Action in pairs(AirDropFunction.AirDropActionList) do
        if Time ~= "BGMInt" then
            AirDropFunction.AddSoundPluse()
            if Action.ZombieCount <= 0 then
                local item = Action.Square:AddWorldInventoryItem("Base.AirDrop", 0.0, 0.0, 0.0);
                if Action.dirarrow then
                    Action.dirarrow:remove()
                end
                AirDropFunction.AirDropActionList[Time] = nil
            else
                Action.ZombieCount = Action.ZombieCount - 5
                local SpawnPos = {}
                for un = 1, 100 do
                    local dir = ZombRandFloat(-math.pi, math.pi)
                    local deltX = math.cos(dir)
                    local deltY = math.sin(dir)
                    local spawnpos = {Action.Player:getX() + MaxDistance * deltX,
                                      Action.Player:getY() + MaxDistance * deltY, 0}
                    local sq = getCell():getGridSquare(spawnpos[1], spawnpos[2], 0)
                    if AirDropFunction.checksqisright(sq) then
                        SpawnPos.x = math.floor(spawnpos[1])
                        SpawnPos.y = math.floor(spawnpos[2])
                        SpawnPos.z = math.floor(spawnpos[3])
                        break
                    end
                end

                addZombiesInOutfit(SpawnPos.x, SpawnPos.y, SpawnPos.z, 5, nil, nil);
                if Action.dirarrow then
                    Action.dirarrow:remove()
                end
                Action.dirarrow = getWorldMarkers():addDirectionArrow(Action.Player, SpawnPos.x, SpawnPos.y, SpawnPos.z,
                    nil, 1.0, 0.2, 0.2, 1.0);
            end
        end
    end

end

function AirDropFunction.LaunchNewAction(playerObj, item, type)

    item:getContainer():Remove(item)
    local square = playerObj:getCurrentSquare()
    -- local marker = getWorldMarkers():addGridSquareMarker(square, 1, 1, 0.0, true, 4);
    -- marker:setScaleCircleTexture(true);
    playerObj:Say(getText("IGUI_ZombiesInComing"))
    local Time = tostring(getTimeInMillis())
    AirDropFunction.AirDropActionList[Time] = {}
    -- AirDropFunction.AirDropActionList[Time].Marker = marker
    AirDropFunction.AirDropActionList[Time].ZombieCount = 200
    AirDropFunction.AirDropActionList[Time].Player = playerObj
    AirDropFunction.AirDropActionList[Time].Square = square
    if getSandboxOptions():getOptionByName("AirdropWithBGM"):getValue() then
        if not AirDropFunction.AirDropActionList.BGMInt then
            AirDropFunction.AirDropActionList.BGMInt = playerObj:getEmitter():playSound("AirDropBGM", true)
        else
            if not playerObj:getEmitter():isPlaying(AirDropFunction.AirDropActionList.BGMInt) then
                AirDropFunction.AirDropActionList.BGMInt = playerObj:getEmitter():playSound("AirDropBGM")
            end
        end
        playerObj:getEmitter():setVolume(AirDropFunction.AirDropActionList.BGMInt,
            getSandboxOptions():getOptionByName("AirdropVolume"):getValue())
    end
    if not ISAirDropInComing.instance then
        local ISAirDropInComing = ISAirDropInComing:new(0, 0, 0, 0, getPlayer(), nil, true);
        ISAirDropInComing:initialise();
        ISAirDropInComing:addToUIManager();
    end
end

Events.EveryOneMinute.Add(AirDropFunction.UpdateAirDropAction)

function AirDropFunction.OpenAirDrop(playerObj, item, type)
    local square = playerObj:getCurrentSquare()
    local marker = getWorldMarkers():addGridSquareMarker(square, 1, 1, 0.0, true, 4);
    marker:setScaleCircleTexture(true);
end

function AirDropFunction.Open_AirDrop(BoxItem, _player)
    local MaxSpawnNum = getSandboxOptions():getOptionByName("AirDropDefaultItemAmount"):getValue()
    local ItemSpawnList = getSandboxOptions():getOptionByName("AirDropDefaultItemList"):getValue()
    local player = getPlayer()

    local ItemList = {}
    for item in string.gmatch(ItemSpawnList, "[^;]+") do
        table.insert(ItemList, item)
    end
    local NowSpawnNum = 0
    while NowSpawnNum < MaxSpawnNum do
        local Item = ItemList[ZombRand(1, #ItemList)]
        if Item then
            player:getInventory():AddItems(Item, 1)
            NowSpawnNum = NowSpawnNum + 1
        end
    end
    ISRemoveItemTool.removeItem(BoxItem, _player)
end

function AirDropFunction.CallAirDrop(_player, _context, _items) -- 设置你的物品的右键菜单来打开窗口
    local container = nil
    local resItems = {}
    for i, v in ipairs(_items) do
        if not instanceof(v, "InventoryItem") then
            for _, it in ipairs(v.items) do
                resItems[it] = true
            end
            container = v.items[1]:getContainer()
        else
            resItems[v] = true
            container = v:getContainer()
        end
    end
    for v, _ in pairs(resItems) do
        if v:getType() == "AirDropMarker" and container:getType() ~= "floor" then
            if getPlayer():isInARoom() then
                return
            end
            _context:addOption(getText("ContextMenu_AirDropMarker"), getPlayer(), AirDropFunction.LaunchNewAction, v,
                "AirDropMarker")
            return
        end
        if v:getType() == "AirDrop" and container:getType() == "floor" then
            _context:addOption(getText("ContextMenu_AirDrop"), v, AirDropFunction.Open_AirDrop, _player)
            return
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(AirDropFunction.CallAirDrop)

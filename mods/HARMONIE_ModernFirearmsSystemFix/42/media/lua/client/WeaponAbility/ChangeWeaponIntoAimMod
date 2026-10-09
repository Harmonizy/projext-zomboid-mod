local AimPositionTable = {"Lean_Left", "Lean_Right", "nil"}
local NowIndex = 1
local LastIndex = 0
local function ActiveAimMod(playerObj)

    -- if playerObj:getVariableString("Lean_Left") == "false" then
    --     ISTimedActionQueue.add(ISChangeWeaponAimMod:new(playerObj, "Lean_Left"))
    -- else
    --     playerObj:setVariable("Lean_Left", "false");
    -- end

    if AimPositionTable[NowIndex] == "nil" then
        for i = 1, #AimPositionTable do
            if playerObj:getVariableString(AimPositionTable[i]) == "true" then
                playerObj:clearVariable(AimPositionTable[i]);
            end
        end
        NowIndex = 1
        LastIndex = 0
        return
    end
    if LastIndex ~= NowIndex and LastIndex ~= 0 then
        playerObj:clearVariable(AimPositionTable[LastIndex]);
        print("Clear " .. AimPositionTable[LastIndex])
    end
    if playerObj:getVariableString(AimPositionTable[NowIndex]) ~= "true" then
        ISTimedActionQueue.add(ISChangeWeaponAimMod:new(playerObj, AimPositionTable[NowIndex]))
        print("ActiveAimMod  ", AimPositionTable[NowIndex])
    end
    NowIndex = NowIndex + 1
    if NowIndex > #AimPositionTable then
        NowIndex = 1
    end
    LastIndex = LastIndex + 1
    if LastIndex > #AimPositionTable then
        LastIndex = 1
    end

end
local function OpenWindowCheck(_key)
    if _key == getCore():getKey("GunLineDown") then
        local player = getPlayer()
        if player and player:getPrimaryHandItem() ~= nil then
            local MainGun = player:getPrimaryHandItem()
            if (MainGun and MainGun:IsWeapon() and MainGun:isRanged()) then
                ActiveAimMod(player)
                return
            end
        end
    end
end
local function init()
    Events.OnKeyPressed.Add(OpenWindowCheck)
end
Events.OnGameStart.Add(init)

local function CheckZombieTrack()
    local player = getPlayer()
    local MainGun = player:getPrimaryHandItem()
    local HasFlag = false
    local L_Scope = nil
    if MainGun and MainGun:IsWeapon() and MainGun:isRanged() then
        L_Scope = MainGun:getWeaponPart("L_Scope")
        if L_Scope and string.find(L_Scope:getType(), "HeartbeatSensor") then
            HasFlag = true
        end
    end
    if HasFlag and L_Scope then
        local isPlus = false
        if L_Scope:getType() == "HeartbeatSensorPlus" then
            isPlus = true
        end
        if L_Scope:getType() == "HeartbeatSensor" then
            isPlus = false
        end
        if not HeartbeatSensor.instance then
            if not HeartbeatSensor.instance then
                local maxY = getCore():getScreenHeight()
                local maxX = getCore():getScreenWidth()
                local scale = 2
                local HeartbeatSensor = HeartbeatSensor:new(0, (maxY - 183 * scale) - 100,
                    253 * scale, 183 * scale, player, scale, isPlus)
                HeartbeatSensor:initialise();
                HeartbeatSensor:addToUIManager();
            end
        end
    else
        if HeartbeatSensor.instance then
            HeartbeatSensor.instance:destroy()
            HeartbeatSensor.instance = nil
        end
    end
end
Events.EveryOneMinute.Add(CheckZombieTrack)

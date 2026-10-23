require "Grenade_Tajectory_core"
-- 下挂榴弹发射器：与下挂火焰喷射器一致，发射或装填后不替换发射器物品，
-- 始终保持同一个物品，仅通过 modData 记录是否已装填（单发）。
-- 装填时消耗一枚 Base.GrenadeAmmo；带 _empty 的发射器不参与使用（未登记到下方表中）。
local AWCWF_Stool_Grenadelauncher = {
    ["GP25_cat"] = {LaunchSound = "LauncherFire", AmmoType = "Base.GrenadeAmmo", LoadSound = "LauncherReload", ExplosionRange = 3, ExplosionDamage = 3, ExplosionSound = "AerosolBombExplode"},
    ["M203_cat"] = {LaunchSound = "LauncherFire", AmmoType = "Base.GrenadeAmmo", LoadSound = "LauncherReload", ExplosionRange = 3, ExplosionDamage = 3, ExplosionSound = "AerosolBombExplode"},
    ["M28_cat"] = {LaunchSound = "LauncherFire", AmmoType = "Base.GrenadeAmmo", LoadSound = "LauncherReload", ExplosionRange = 3, ExplosionDamage = 3, ExplosionSound = "AerosolBombExplode"},
}

local LoadedKey = "GrenadeLauncherLoaded"

local function IsLoaded(MainGun)
    return MainGun:getModData()[LoadedKey] == true
end

local function SetLoaded(MainGun, loaded)
    MainGun:getModData()[LoadedKey] = loaded or nil
end

local HasEnterFireModeFlag = HasEnterFireModeFlag or false
local function HasGrenadelauncher(playerObj)
    local MainGun = playerObj:getPrimaryHandItem()
    if not MainGun then
        return {false, false}
    end
    if MainGun:IsWeapon() and MainGun:isRanged() then
        local part = MainGun:getWeaponPart("Stool")
        if part and AWCWF_Stool_Grenadelauncher[part:getType()] then
            if IsLoaded(MainGun) then
                return {true, true}
            else
                return {true, false}
            end
        end
    end
    return {false, false}
end

local function GetGrenadelauncher(playerObj)
    local MainGun = playerObj and playerObj:getPrimaryHandItem()
    if not MainGun then return nil end
    local part = MainGun:getWeaponPart("Stool")
    if not part then return nil end
    local cfg = AWCWF_Stool_Grenadelauncher[part:getType()]
    if not cfg then return nil end
    return MainGun, cfg
end

local function CheckGrenadelauncher(playerObj)
    local FlagNow = HasGrenadelauncher(playerObj)
    if FlagNow[1] and playerObj:isAiming() then
        local weaitem = instanceItem("Base.PipeBomb")
        if Grenade_Tajectory.GrenadeAimCursor == nil then
            Grenade_Tajectory.GrenadeAimCursor = ISShootGrenade:new("", "", playerObj, weaitem)
            getCell():setDrag(Grenade_Tajectory.GrenadeAimCursor, 0)
        end
        HasEnterFireModeFlag = true
        return
    end
    if HasEnterFireModeFlag and not playerObj:isAiming() then
        local DragNow = getCell():getDrag(0)
        if DragNow and DragNow.Type == "ISShootGrenade" then
            getCell():setDrag(nil, 0)
        end
        Grenade_Tajectory.GrenadeAimCursor = nil
        HasEnterFireModeFlag = false
    end
end
local function LaunchGrenadeLauncher(_key)
    if _key ~= getCore():getKey("LauchGrenadelauncherat") then
        return
    end
    local playerObj = getPlayer()
    if not playerObj then return end
    local FlagNow = HasGrenadelauncher(playerObj)
    if not (FlagNow[1] and playerObj:isAiming()) then return end

    local MainGun, GrenadelauncherType = GetGrenadelauncher(playerObj)
    if not GrenadelauncherType then return end

    if FlagNow[2] then
        -- 已装填：发射榴弹并清空装填状态，物品不替换
        local cell = getCell():getDrag(0)
        if cell == nil then return end
        playerObj:getEmitter():playSound(GrenadelauncherType.LaunchSound)
        local TargetSquare = Grenade_Tajectory.aimcursorsq
        if TargetSquare then
            Grenade_Tajectory.ShootGrenade(playerObj, MainGun, GrenadelauncherType)
            SetLoaded(MainGun, false)
            -- 射击特效：枪口向前喷出一团烟雾
            if GrenadeLauncherFX and GrenadeLauncherFX.spawnMuzzleSmoke then
                local fwd = playerObj:getForwardDirection()
                if fwd then
                    local dir = fwd:getDirection()
                    GrenadeLauncherFX.spawnMuzzleSmoke(
                        playerObj:getX() + math.cos(dir) * 0.7,
                        playerObj:getY() + math.sin(dir) * 0.7,
                        playerObj:getZ() + 0.42,
                        dir)
                end
            end
        end
    else
        -- 未装填：装填并消耗一枚 Base.GrenadeAmmo，物品不替换
        local inv = playerObj:getInventory()
        local AmmoCanno = inv:FindAndReturn(GrenadelauncherType.AmmoType)
        if AmmoCanno then
            ISTimedActionQueue.add(ISShootGrenadeReload:new(playerObj, 100, MainGun, GrenadelauncherType))
        end
    end
end
local function Check()
    Events.OnKeyPressed.Add(LaunchGrenadeLauncher)
end
local function OnGameStartCheckModinfo()
    Events.OnGameStart.Add(Check)
    Events.OnPlayerUpdate.Add(CheckGrenadelauncher)
end
Events.OnGameStart.Add(OnGameStartCheckModinfo)

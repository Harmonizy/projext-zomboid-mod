require "TimedActions/ISBaseTimedAction"

-- 下挂喷火器 (Flamethrower) underbarrel ability.
-- 手持安装了 Gunpart.Flamethrower 的枪械，瞄准后按住 G (LauchGrenadelauncherat)
-- 会朝瞄准方向持续喷射火焰：按 HitInterval 周期性地击倒 MinAngle=0.94、MaxRange=11
-- 范围内的僵尸，使其起火并小幅击退。火焰射流动画复用 Base.Flamethrower 的粒子引擎
-- (FlamethrowerFX.spawnPulse)，按住期间逐帧喷射，视觉与 Base.Flamethrower 一致。
-- 持续喷射约 BurnCorpseTime 秒（默认 3 秒）后会把锥形范围内的尸体点燃并烧掉。
-- 一次装入 5 升汽油 (Fluid.Petrol) 可连续喷射约 5 秒，装填时间与下挂榴弹发射器一致 (time=100)。

local AWCWF_Stool_Flamethrower = {
    ["Flamethrower"] = {
        LaunchSound = "Flamethrower",
        LoadSound = "LauncherReload",
        MinAngle = 0.94,
        MaxRange = 6,
        KnockBack = 0.05,   -- 每次判定沿远离玩家方向击退的距离（格）
        MinDamage = 0.03,   -- 每次判定随机伤害下限（生命）
        MaxDamage = 0.07,    -- 每次判定随机伤害上限（生命）
        FuelLiters = 5.0,   -- 一次装入 5 升汽油
        MaxShots = 5,       -- 装满后可开火 5 发 
        ShotDuration = 1.2, -- 每“发”燃料可连续喷射的秒数（5 发 ≈ 5 秒）
        EmitInterval = 0.03,-- 火焰粒子脉冲间隔（秒），与 Base.Flamethrower 一致
        HitInterval = 0.12, -- 击倒/击退/点燃判定间隔（秒）
        BurnCorpseTime = 3.0, -- 持续喷射约 3 秒后把锥形范围内的尸体烧掉
    },
}

local FuelKey = "FlamethrowerShots"

-- 返回 (MainGun, config)，若当前手持枪械的 Stool 槽安装了喷火器；否则返回 nil。
local function GetFlamethrower(playerObj)
    local MainGun = playerObj and playerObj:getPrimaryHandItem()
    if not MainGun then return nil end
    if not (MainGun:IsWeapon() and MainGun:isRanged()) then return nil end
    local part = MainGun:getWeaponPart("Stool")
    if not part then return nil end
    local cfg = AWCWF_Stool_Flamethrower[part:getType()]
    if not cfg then return nil end
    return MainGun, cfg
end

-- 剩余可开火次数（0 = 未装填）。
local function GetShotsLeft(MainGun)
    local n = MainGun:getModData()[FuelKey]
    if type(n) == "number" then return n end
    return 0
end

local function SetShotsLeft(MainGun, n)
    if n <= 0 then
        MainGun:getModData()[FuelKey] = nil
    else
        MainGun:getModData()[FuelKey] = n
    end
end

-- 在玩家背包中寻找装有不少于 liters 升汽油的容器。
local function FindPetrolContainer(playerObj, liters)
    local inv = playerObj:getInventory()
    if not inv then return nil end
    local items = inv:getItems()
    if not items then return nil end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fc = item and item:getFluidContainer()
        if fc and fc:contains(Fluid.Petrol) and fc:getAmount() >= liters then
            return item
        end
    end
    return nil
end

-- 归一化的朝向向量。
local function GetForwardDir(playerObj)
    local fwd = playerObj:getForwardDirection()
    local fx, fy = 0, -1
    if fwd then
        fx = fwd:getX()
        fy = fwd:getY()
    end
    local flen = math.sqrt(fx * fx + fy * fy)
    if flen < 0.0001 then
        fx, fy = 0, -1
        flen = 1
    end
    return fx / flen, fy / flen
end

-- 击倒/点燃/击退锥形范围内的僵尸（持续喷射时按 HitInterval 周期性调用）。
local function ApplyFlamethrowerHit(playerObj, cfg)
    local px = playerObj:getX()
    local py = playerObj:getY()
    local pz = playerObj:getZ()
    local fx, fy = GetForwardDir(playerObj)

    local cell = getCell()
    if not cell then return end

    local range = cfg.MaxRange
    for dy = -range, range do
        for dx = -range, range do
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= range and dist > 0.0001 then
                local vx = dx / dist
                local vy = dy / dist
                if fx * vx + fy * vy >= cfg.MinAngle then
                    local sq = cell:getGridSquare(px + dx, py + dy, pz)
                    if sq then
                        local zombies = sq:getMovingObjects()
                        for i = 0, zombies:size() - 1 do
                            local zombie = zombies:get(i)
                            if instanceof(zombie, "IsoZombie") then
                                zombie:knockDown(false)
                                zombie:SetOnFire()
                                -- 持续灼烧：每次判定随机扣除 MinDamage~MaxDamage 生命。
                                local dmg = cfg.MinDamage + ZombRand(1000) / 1000 * (cfg.MaxDamage - cfg.MinDamage)
                                zombie:setHealth(math.max(0, zombie:getHealth() - dmg))
                                -- 小幅击退：把僵尸沿远离玩家的方向推开一小段。
                                zombie:setX(zombie:getX() + vx * cfg.KnockBack)
                                zombie:setY(zombie:getY() + vy * cfg.KnockBack)
                            end
                        end
                    end
                end
            end
        end
    end
end

local BurnKey = "FlamethrowerBurn"

-- 烧尸体：持续喷射时累计每具尸体的暴露时间，首次接触即点燃（烧起火焰），
-- 累计满 cfg.BurnCorpseTime 秒后把尸体彻底烧掉（移除）。
local function ApplyCorpseBurn(playerObj, cfg, dt)
    local px = playerObj:getX()
    local py = playerObj:getY()
    local pz = playerObj:getZ()
    local fx, fy = GetForwardDir(playerObj)

    local cell = getCell()
    if not cell then return end

    local range = cfg.MaxRange
    local toRemove = {}
    for dy = -range, range do
        for dx = -range, range do
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= range and dist > 0.0001 then
                local vx = dx / dist
                local vy = dy / dist
                if fx * vx + fy * vy >= cfg.MinAngle then
                    local sq = cell:getGridSquare(px + dx, py + dy, pz)
                    if sq then
                        local bodies = sq:getDeadBodys()
                        if bodies then
                            for i = 0, bodies:size() - 1 do
                                local body = bodies:get(i)
                                if body and body:getSquare() and not body:isAnimal() then
                                    local md = body:getModData()
                                    local burn = (md[BurnKey] or 0) + dt
                                    md[BurnKey] = burn
                                    if not md[BurnKey .. "Ignited"] then
                                        md[BurnKey .. "Ignited"] = true
                                        playerObj:burnCorpse(body)
                                    end
                                    if burn >= cfg.BurnCorpseTime then
                                        table.insert(toRemove, body)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 延迟移除，避免在遍历尸体列表的同时删改它。
    for _, body in ipairs(toRemove) do
        local sq = body:getSquare()
        if sq then
            sq:removeCorpse(body, false)
        end
    end
end

-- ---------------------------------------------------------------------------
-- 持续喷射：瞄准 + 按住 G 时逐帧推进（与 Base.Flamethrower 按住 F 的机制一致）。
-- ---------------------------------------------------------------------------
local spraying = false
local emitAcc, hitAcc, fuelAcc = 0, 0, 0

local function OnPostRender()
    local player = getPlayer()
    if not player then
        spraying = false
        return
    end

    local MainGun, cfg = GetFlamethrower(player)
    local wantSpray = false
    if MainGun and player:isAiming() then
        wantSpray = isKeyDown(getCore():getKey("LauchGrenadelauncherat")) and GetShotsLeft(MainGun) > 0
    end

    if not wantSpray then
        spraying = false
        emitAcc, hitAcc, fuelAcc = 0, 0, 0
        return
    end

    if not spraying then
        spraying = true
        player:getEmitter():playSound(cfg.LaunchSound)
    end

    local dt = (getGameTime():getMultiplier() or 0) / 60
    if dt > 0.1 then dt = 0.1 end

    local fx, fy = GetForwardDir(player)
    local dir = math.atan2(fy, fx)
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local mx = px + fx * 0.7
    local my = py + fy * 0.7
    local mz = pz + 0.42

    -- 火焰粒子脉冲（复用 Base.Flamethrower 的粒子引擎）
    emitAcc = emitAcc + dt
    while emitAcc >= cfg.EmitInterval do
        emitAcc = emitAcc - cfg.EmitInterval
        if FlamethrowerFX and FlamethrowerFX.spawnPulse then
            FlamethrowerFX.spawnPulse(mx, my, mz, dir)
        end
    end

    -- 击倒/击退/点燃 + 烧尸体
    hitAcc = hitAcc + dt
    if hitAcc >= cfg.HitInterval then
        hitAcc = hitAcc - cfg.HitInterval
        ApplyFlamethrowerHit(player, cfg)
        ApplyCorpseBurn(player, cfg, cfg.HitInterval)
    end

    -- 消耗燃料：每 ShotDuration 秒消耗 1 发，耗尽后停止喷射。
    fuelAcc = fuelAcc + dt
    while fuelAcc >= cfg.ShotDuration do
        fuelAcc = fuelAcc - cfg.ShotDuration
        SetShotsLeft(MainGun, GetShotsLeft(MainGun) - 1)
    end
end
Events.OnPostRender.Add(OnPostRender)

-- 装填定时动作：与下挂榴弹发射器相同的时间 (time=100)，完成后消耗 5 升汽油并装满 5 发。
ISFlamethrowerReload = ISBaseTimedAction:derive("ISFlamethrowerReload")

function ISFlamethrowerReload:isValid()
    if not self.weapon then return false end
    local part = self.weapon:getWeaponPart("Stool")
    if not part then return false end
    if AWCWF_Stool_Flamethrower[part:getType()] == nil then return false end
    if GetShotsLeft(self.weapon) > 0 then return false end
    return true
end

function ISFlamethrowerReload:start()
    self.character:playSound(self.cfg.LoadSound)
end

function ISFlamethrowerReload:stop()
    ISBaseTimedAction.stop(self)
end

function ISFlamethrowerReload:perform()
    ISBaseTimedAction.perform(self)
    local fuel = FindPetrolContainer(self.character, self.cfg.FuelLiters)
    if fuel then
        local fc = fuel:getFluidContainer()
        local newAmount = fc:getAmount() - self.cfg.FuelLiters
        if newAmount < 0 then newAmount = 0 end
        fc:adjustAmount(newAmount)
        SetShotsLeft(self.weapon, self.cfg.MaxShots)
    end
end

function ISFlamethrowerReload:new(character, time, weapon, cfg)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.weapon = weapon
    o.cfg = cfg
    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = time
    return o
end

-- 按 G：仅在空枪且背包有汽油时触发装填；喷射本身由 OnPostRender 的按住状态驱动。
local function OnKeyPressed(_key)
    if _key ~= getCore():getKey("LauchGrenadelauncherat") then
        return
    end
    local playerObj = getPlayer()
    if not playerObj then return end
    local MainGun, cfg = GetFlamethrower(playerObj)
    if not MainGun then return end
    if not playerObj:isAiming() then return end

    if GetShotsLeft(MainGun) <= 0 then
        if FindPetrolContainer(playerObj, cfg.FuelLiters) then
            ISTimedActionQueue.add(ISFlamethrowerReload:new(playerObj, 100, MainGun, cfg))
        end
    end
end

local function Check()
    Events.OnKeyPressed.Add(OnKeyPressed)
end

local function OnGameStartCheckModinfo()
    Events.OnGameStart.Add(Check)
end
Events.OnGameStart.Add(OnGameStartCheckModinfo)

-- Flamethrower 客户端脚本
-- 核心思路参考 Ballistic_lite.lua：在 OnPostRender 中用 renderer:renderPoly
-- 把火焰/烟雾贴图按世界坐标投影到屏幕上，形成连续的火焰射流特效。
-- 触发方式：手持喷火器瞄准（右键）时按住 F 键持续喷射，燃料随时间消耗；
-- 通过 IsoFireManager.StartFire / IsoGameCharacter.SetOnFire 让火焰真实地点燃
-- 地面、物块与僵尸（单机/主机端生效）。

local FT = Flamethrower or {}
Flamethrower = FT

-- 若 shared 未加载则使用默认值兜底
FT.WEAPON_TYPE          = FT.WEAPON_TYPE          or "Flamethrower.Flamethrower"
FT.RANGE                = FT.RANGE                or 7.5
FT.CONE_HALF_ANGLE      = FT.CONE_HALF_ANGLE      or math.rad(15)
FT.MIN_IGNITE_DIST      = FT.MIN_IGNITE_DIST      or 1.3
FT.SQUARE_IGNITE_NEAR   = FT.SQUARE_IGNITE_NEAR   or 0.28
FT.SQUARE_IGNITE_FAR    = FT.SQUARE_IGNITE_FAR    or 0.04
FT.SQUARE_SAMPLES       = FT.SQUARE_SAMPLES       or 3
FT.ZOMBIE_IGNITE_NEAR   = FT.ZOMBIE_IGNITE_NEAR   or 0.95
FT.ZOMBIE_IGNITE_FAR    = FT.ZOMBIE_IGNITE_FAR    or 0.45
FT.DAMAGE_MIN           = FT.DAMAGE_MIN           or 0.2
FT.DAMAGE_MAX           = FT.DAMAGE_MAX           or 0.05
FT.PUSH_NEAR            = FT.PUSH_NEAR            or 0.05  -- 射流冲击力：近处每判定周期的后推距离(格)
FT.PUSH_FAR             = FT.PUSH_FAR             or 0.015 -- 远处后推距离(格)
FT.HIT_REACTION_CHANCE  = FT.HIT_REACTION_CHANCE  or 12    -- 每周期触发踉跄动画的概率(%)
FT.FLAME_FRAMES         = FT.FLAME_FRAMES         or 16
FT.SMOKE_FRAMES         = FT.SMOKE_FRAMES         or 8
FT.PARTICLES_PER_SHOT   = FT.PARTICLES_PER_SHOT   or 4    -- 每个喷射脉冲的火焰粒子数
FT.EMBER_CHANCE         = FT.EMBER_CHANCE         or 45   -- 每个脉冲产生火星的概率(%)
FT.EMIT_INTERVAL        = FT.EMIT_INTERVAL        or 0.03 -- 喷射脉冲间隔(秒)
FT.IGNITE_INTERVAL      = FT.IGNITE_INTERVAL      or 0.12 -- 点燃判定间隔(秒)
FT.FUEL_INTERVAL        = FT.FUEL_INTERVAL        or 0.15 -- 燃料消耗间隔(秒)
FT.TRIGGER_KEY          = FT.TRIGGER_KEY          or (Keyboard and Keyboard.KEY_F) or 33

-- ==================== 火焰外形可调参数 ====================
-- 半径：起点(喷口) -> 终点(末端火团)，飞行途中按膨胀曲线过渡
FT.SPAWN_R0_MIN         = FT.SPAWN_R0_MIN         or 0.05 -- 起点半径最小值(格)：喷口细度
FT.SPAWN_R0_RAND        = FT.SPAWN_R0_RAND        or 0.05 -- 起点半径随机幅度
FT.END_R1_MIN           = FT.END_R1_MIN           or 99 -- 终点半径最小值(格)：末端火团大小
FT.END_R1_RAND          = FT.END_R1_RAND          or 0.20 -- 终点半径随机幅度
FT.GROW_CURVE           = FT.GROW_CURVE           or 0.2 -- 膨胀曲线指数：=1 匀速变粗；
                                                        --   <1 离开喷口后迅速变粗(推荐0.5~0.8)；
                                                        --   >1 前段保持纤细、末段才膨开
-- 非等比拉伸（相对半径的系数，随生命周期从起点渐变到终点）
FT.WIDTH_START          = FT.WIDTH_START          or 0.60 -- 近端横向宽度系数：越小喷口越窄
FT.WIDTH_END            = FT.WIDTH_END            or 99 -- 1.15末端横向宽度系数：越大火团越宽
FT.LENGTH_START         = FT.LENGTH_START         or 2.2  -- 近端纵向拉伸系数：沿飞行方向拉长
FT.LENGTH_END           = FT.LENGTH_END           or 1.1  -- 末端纵向拉伸系数：=1为正圆
-- ==========================================================

-- ---------------------------------------------------------------------------
-- 贴图（延迟加载，避免进入游戏前 getTexture 返回空）
-- ---------------------------------------------------------------------------
local flameTex, smokeTex, glowTex = nil, nil, nil
local function ensureTextures()
    if flameTex then return true end
    flameTex, smokeTex = {}, {}
    for i = 1, FT.FLAME_FRAMES do
        flameTex[i] = getTexture("media/textures/ft_flame_" .. i .. ".png")
    end
    for i = 1, FT.SMOKE_FRAMES do
        smokeTex[i] = getTexture("media/textures/ft_smoke_" .. i .. ".png")
    end
    glowTex = getTexture("media/textures/ft_glow.png")
    return flameTex[1] ~= nil
end

-- ---------------------------------------------------------------------------
-- 工具函数
-- ---------------------------------------------------------------------------
local function isFlamethrower(item)
    return instanceof(item, "HandWeapon") and item:getFullType() == FT.WEAPON_TYPE
end

local function angleDiff(a, b)
    local d = (a - b) % (2 * math.pi)
    if d > math.pi then d = d - 2 * math.pi end
    return math.abs(d)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

-- 视线检测：火焰能否从射手到达目标格（被墙挡住则返回 false）
local function losClear(cell, x0, y0, z0, x1, y1, z1)
    local ok, res = pcall(function()
        return LosUtil.lineClear(cell,
            math.floor(x0), math.floor(y0), math.floor(z0),
            math.floor(x1), math.floor(y1), math.floor(z1), false)
    end)
    if not ok then return true end
    return tostring(res) ~= "Blocked"
end

local function getMuzzle(player)
    local fwd = player:getForwardDirection()
    if not fwd then return nil end
    local dir = fwd:getDirection()
    local mx = player:getX() + math.cos(dir) * 0.7
    local my = player:getY() + math.sin(dir) * 0.7
    local mz = player:getZ() + 0.42
    return mx, my, mz, dir
end

-- ---------------------------------------------------------------------------
-- 粒子系统
-- ---------------------------------------------------------------------------
local particles = {}
local MAX_PARTICLES = 800

local function countParticles()
    local n = 0
    for _ in pairs(particles) do n = n + 1 end
    return n
end

local function spawnParticle(p)
    if countParticles() >= MAX_PARTICLES then return end
    table.insert(particles, p)
end

-- 连续喷射的一个脉冲：少量但高频，形成连贯射流
local function spawnFlamePulse(mx, my, mz, dir)
    -- 枪口亮点
    spawnParticle({
        kind = "glow",
        x = mx, y = my, z = mz,
        vx = 0, vy = 0, vz = 0,
        age = 0, life = 0.08,
        r0 = 0.12, r1 = 0.20,
        rot = 0, spin = 0,
        cr = 1.0, cg = 0.85, cb = 0.45, alpha = 0.55,
    })
    -- 火焰射流：出生点极细的紧密流束，下游才膨胀成火团
    for _ = 1, FT.PARTICLES_PER_SHOT do
        local a = dir + (ZombRand(200) - 100) / 100 * math.rad(2)
        local speed = 8.5 + ZombRand(25) / 10
        -- 沿射流方向错开出生点，避免堆叠成一团
        local ahead = ZombRand(15) / 100
        spawnParticle({
            kind = "flame",
            x = mx + math.cos(a) * ahead + (ZombRand(8) - 4) / 100,
            y = my + math.sin(a) * ahead + (ZombRand(8) - 4) / 100,
            z = mz,
            vx = math.cos(a) * speed,
            vy = math.sin(a) * speed,
            vz = 0.05 + ZombRand(15) / 100,
            age = 0,
            life = 0.50 + ZombRand(30) / 100,
            r0 = FT.SPAWN_R0_MIN + ZombRand(math.floor(FT.SPAWN_R0_RAND * 100)) / 100,
            r1 = FT.END_R1_MIN + ZombRand(math.floor(FT.END_R1_RAND * 100)) / 100,
            rot = 0, spin = 0,
        })
    end
    -- 火星余烬：偶发高速亮点，飞得更远后坠落熄灭
    if ZombRand(100) < FT.EMBER_CHANCE then
        local a = dir + (ZombRand(200) - 100) / 100 * math.rad(10)
        local speed = 12 + ZombRand(40) / 10
        spawnParticle({
            kind = "ember",
            x = mx, y = my, z = mz,
            vx = math.cos(a) * speed,
            vy = math.sin(a) * speed,
            vz = 0.25 + ZombRand(20) / 100,
            age = 0,
            life = 0.35 + ZombRand(25) / 100,
            r0 = 0.035, r1 = 0.012,
            rot = 0, spin = 0,
        })
    end
end

local function updateParticles(dt)
    for i, p in pairs(particles) do
        p.age = p.age + dt
        if p.age >= p.life then
            if p.kind == "flame" and ZombRand(100) < 65 then
                -- 火焰燃尽后转化为缓慢上升的黑烟
                particles[i] = {
                    kind = "smoke",
                    x = p.x, y = p.y, z = p.z,
                    vx = p.vx * 0.08, vy = p.vy * 0.08, vz = 0.3 + ZombRand(20) / 100,
                    age = 0, life = 1.2 + ZombRand(70) / 100,
                    r0 = p.r1 * 0.9, r1 = p.r1 * 1.7,
                    rot = p.rot, spin = p.spin * 0.3,
                }
            else
                particles[i] = nil
            end
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.z = p.z + p.vz * dt
            if p.kind == "flame" then
                local t = p.age / p.life
                -- 射流轻微减速；后段受浮力缓慢上飘
                local drag = math.max(0, 1 - 1.0 * dt)
                p.vx = p.vx * drag
                p.vy = p.vy * drag
                p.vz = p.vz + t * 0.8 * dt
                -- 湍流游走：下游越来越紊乱（真实火焰的湍流破碎）
                local turb = (0.4 + t * 2.5) * dt
                p.vx = p.vx + (ZombRand(200) - 100) / 100 * turb
                p.vy = p.vy + (ZombRand(200) - 100) / 100 * turb
            elseif p.kind == "ember" then
                -- 火星受重力坠落
                local drag = math.max(0, 1 - 0.6 * dt)
                p.vx = p.vx * drag
                p.vy = p.vy * drag
                p.vz = p.vz - 1.6 * dt
            elseif p.kind == "smoke" then
                local drag = math.max(0, 1 - 0.4 * dt)
                p.vx = p.vx * drag
                p.vy = p.vy * drag
            end
        end
    end
end

local function renderParticles(renderer, player)
    if not ensureTextures() then return end
    -- 以玩家为中心估算“每世界单位对应的屏幕像素”，自动适应缩放
    local x0, y0 = ISCoordConversion.ToScreen(player:getX(), player:getY(), player:getZ(), 0)
    local x1, y1 = ISCoordConversion.ToScreen(player:getX() + 1, player:getY(), player:getZ(), 0)
    local ppu = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
    if ppu < 4 then ppu = 4 end

    for _, p in pairs(particles) do
        local t = p.age / p.life
        local sx, sy = ISCoordConversion.ToScreen(p.x, p.y, p.z, 0)
        -- 半径膨胀曲线：GROW_CURVE < 1 时离开喷口后迅速变粗，> 1 时末段才膨开
        local r = lerp(p.r0, p.r1, t ^ FT.GROW_CURVE) * ppu
        local tex, cr, cg, cb, alpha
        if p.kind == "flame" then
            local fi = math.min(FT.FLAME_FRAMES, math.floor(t * FT.FLAME_FRAMES) + 1)
            tex = flameTex[fi]
            -- 颜色衰减：白热 -> 橙 -> 暗红
            cr = 1.0
            cg = 1.0 - 0.55 * t
            cb = 1.0 - 0.85 * t
            alpha = 0.95 * (1 - t ^ 1.6)
        elseif p.kind == "smoke" then
            local si = math.min(FT.SMOKE_FRAMES, math.floor(t * FT.SMOKE_FRAMES) + 1)
            tex = smokeTex[si]
            cr, cg, cb = 1.0, 1.0, 1.0
            alpha = 0.50 * (1 - t)
        elseif p.kind == "ember" then
            tex = glowTex
            cr, cg, cb = 1.0, 0.72, 0.30
            alpha = 0.9 * (1 - t)
        else -- glow
            tex = glowTex
            cr, cg, cb = p.cr or 1, p.cg or 1, p.cb or 1
            alpha = (p.alpha or 0.8) * (1 - t)
        end
        -- 火舌贴图舌尖朝上：把四边形旋转到屏幕空间的速度方向
        local rot = 0
        if p.kind ~= "glow" then
            local sp2 = p.vx * p.vx + p.vy * p.vy + p.vz * p.vz
            if sp2 > 0.02 then
                local wx, wy = ISCoordConversion.ToScreen(p.x + p.vx * 0.1, p.y + p.vy * 0.1, p.z + p.vz * 0.1, 0)
                rot = math.atan2(wx - sx, -(wy - sy))
            end
        end
        -- 非等比拉伸：火焰近端是细长射流（横向收窄、纵向拉长），远端膨成适度火团
        -- 系数可在文件顶部"火焰外形可调参数"区调整
        local rw, rl = r, r
        if p.kind == "flame" then
            rw = r * lerp(FT.WIDTH_START, FT.WIDTH_END, t)
            rl = r * lerp(FT.LENGTH_START, FT.LENGTH_END, t)
        end
        if tex and alpha > 0.01 then
            local ca, sa = math.cos(rot), math.sin(rot)
            -- 四角 (-1,-1) (1,-1) (1,1) (-1,1)，先按 (rw,rl) 缩放再旋转
            renderer:renderPoly(tex,
                sx - rw * ca + rl * sa, sy - rw * sa - rl * ca,
                sx + rw * ca + rl * sa, sy + rw * sa - rl * ca,
                sx + rw * ca - rl * sa, sy + rw * sa + rl * ca,
                sx - rw * ca - rl * sa, sy - rw * sa + rl * ca,
                cr, cg, cb, alpha)
        end
    end
end

-- ---------------------------------------------------------------------------
-- 声音（循环火焰咆哮 + 瞄准时的燃气嘶嘶声）
-- 注意：角色音效发射器(BaseCharacterSoundEmitter)没有 playSoundLooped，
-- 这里用无缝 WAV + isPlaying 检测播完重播的方式实现循环。
-- ---------------------------------------------------------------------------
local roarHandle, roarKeepAlive = nil, 0
local pilotHandle = nil

local function getPlayerEmitter(player)
    local ok, emitter = pcall(function() return player:getEmitter() end)
    if ok then return emitter end
    return nil
end

local function updateSounds(player, dt, aimingFT, spraying)
    local emitter = getPlayerEmitter(player)
    if not emitter then return end
    -- 火焰咆哮：喷射期间保持播放（2.6s 无缝音频，播完立即重播）
    if spraying then
        roarKeepAlive = 0.45
    end
    if roarKeepAlive > 0 then
        roarKeepAlive = roarKeepAlive - dt
        if roarKeepAlive <= 0 then
            if roarHandle then
                emitter:stopSound(roarHandle)
                roarHandle = nil
            end
        elseif not roarHandle or not emitter:isPlaying(roarHandle) then
            roarHandle = emitter:playSound("FlameThrowerLoop")
        end
    end
    -- 燃气嘶嘶声：瞄准期间保持播放（2.0s 无缝音频，播完立即重播）
    if aimingFT then
        if not pilotHandle or not emitter:isPlaying(pilotHandle) then
            pilotHandle = emitter:playSound("FlamePilot")
        end
    elseif pilotHandle then
        emitter:stopSound(pilotHandle)
        pilotHandle = nil
    end
end

-- ---------------------------------------------------------------------------
-- 点燃逻辑（单机/主机端；联机客户端跳过，仅保留视觉特效）
-- ---------------------------------------------------------------------------
local function igniteZombies(player, dir)
    local cell = getCell()
    if not cell then return end
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local list = cell:getZombieList()
    if not list then return end
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z and not z:isDead() and math.abs(z:getZ() - pz) < 1 then
            local dx, dy = z:getX() - px, z:getY() - py
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= FT.RANGE and dist > 0.4 then
                -- 锥形判定，近距离放宽（僵尸有体积）
                local ang = angleDiff(math.atan2(dy, dx), dir)
                local tolerance = FT.CONE_HALF_ANGLE + math.atan2(0.55, dist)
                if ang <= tolerance and losClear(cell, px, py, pz, z:getX(), z:getY(), z:getZ()) then
                    local dmg = FT.DAMAGE_MIN + ZombRand(1000) / 1000 * (FT.DAMAGE_MAX - FT.DAMAGE_MIN)
                    z:setHealth(math.max(0, z:getHealth() - dmg))
                    local chance = lerp(FT.ZOMBIE_IGNITE_NEAR, FT.ZOMBIE_IGNITE_FAR, dist / FT.RANGE)
                    if ZombRand(1000) < chance * 1000 then
                        z:SetOnFire()
                    end
                    -- 射流冲击力：把僵尸沿射流方向往后推（近强远弱），倒地的不推
                    if not z:isProne() then
                        local inv = 1 / math.max(dist, 0.001)
                        local push = lerp(FT.PUSH_NEAR, FT.PUSH_FAR, dist / FT.RANGE)
                        z:setX(z:getX() + dx * inv * push)
                        z:setY(z:getY() + dy * inv * push)
                        -- 偶发踉跄动画，看起来像被火流压得住不住脚
                        if ZombRand(100) < FT.HIT_REACTION_CHANCE then
                            z:setHitReaction("ShotChest")
                        end
                    end
                end
            end
        end
    end
end

local function igniteSquares(player, dir)
    local cell = getCell()
    if not cell then return end
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local pzi = math.floor(pz)
    for _ = 1, FT.SQUARE_SAMPLES do
        -- 距离偏向近端（sqrt 分布），角度在锥形内随机
        local d = FT.MIN_IGNITE_DIST + (FT.RANGE - FT.MIN_IGNITE_DIST) * math.sqrt(ZombRand(1000) / 1000)
        local a = dir + (ZombRand(2000) - 1000) / 1000 * FT.CONE_HALF_ANGLE
        local x = math.floor(px + math.cos(a) * d)
        local y = math.floor(py + math.sin(a) * d)
        local chance = lerp(FT.SQUARE_IGNITE_NEAR, FT.SQUARE_IGNITE_FAR, d / FT.RANGE)
        -- print(chance)
        if ZombRand(300) < chance * 1000 and losClear(cell, px, py, pz, x + 0.5, y + 0.5, pz) then
            local sq = cell:getGridSquare(x, y, pzi)
            if sq then
                -- igniteOnAny=false：只点燃可燃格；能量越高越容易引燃格上物体
                pcall(function()
                    IsoFireManager.StartFire(cell, sq, false, 80 + ZombRand(60), 0)
                end)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- 每帧渲染：连续喷射（瞄准+F）、粒子推进与绘制、引燃小火苗、动态光源
-- ---------------------------------------------------------------------------
local pilotTimer = 0
local emitAcc, igniteAcc, fuelAcc = 0, 0, 0
local dryFireCooldown = 0

local function OnPostRender()
    local player = getPlayer()
    if not player then return end
    local renderer = getRenderer()
    if not renderer then return end

    local dt = (getGameTime():getMultiplier() or 0) / 60
    if dt > 0.1 then dt = 0.1 end

    updateParticles(dt)
    renderParticles(renderer, player)

    local weapon = player:getPrimaryHandItem()
    local aimingFT = player:isAiming() and isFlamethrower(weapon)
    local spraying = false

    -- 瞄准 + 按住 F：持续喷射火焰射流
    if aimingFT and isKeyDown(FT.TRIGGER_KEY) then
        if true or  weapon:getCurrentAmmoCount() > 0 then
            spraying = true
            local mx, my, mz, dir = getMuzzle(player)
            if mx then
                -- 高频脉冲喷射，形成连续射流
                emitAcc = emitAcc + dt
                while emitAcc >= FT.EMIT_INTERVAL do
                    emitAcc = emitAcc - FT.EMIT_INTERVAL
                    spawnFlamePulse(mx, my, mz, dir)
                end
                -- 定时点燃僵尸与地面
                igniteAcc = igniteAcc + dt
                if igniteAcc >= FT.IGNITE_INTERVAL then
                    igniteAcc = 0
                    if not isClient() then
                        igniteZombies(player, dir)
                        igniteSquares(player, dir)
                    end
                end
                -- 定时消耗燃料
                fuelAcc = fuelAcc + dt
                if fuelAcc >= FT.FUEL_INTERVAL then
                    fuelAcc = 0
                    -- 消耗燃料注释weapon:setCurrentAmmoCount(math.max(0, weapon:getCurrentAmmoCount() - 1))
                end
            end
        else
            -- 没有燃料：咔哒一声提示
            if dryFireCooldown <= 0 then
                dryFireCooldown = 0.6
                local emitter = getPlayerEmitter(player)
                if emitter then emitter:playSound("M16Jam") end
            end
        end
    else
        emitAcc = 0
    end
    if dryFireCooldown > 0 then
        dryFireCooldown = dryFireCooldown - dt
    end

    -- 瞄准但未喷射时的引燃小火苗（蓝色燃气火）+ 枪口暖光
    if aimingFT and not spraying then
        local mx, my, mz = getMuzzle(player)
        if mx then
            pilotTimer = pilotTimer - dt
            if pilotTimer <= 0 then
                pilotTimer = 0.05
                spawnParticle({
                    kind = "glow",
                    x = mx, y = my, z = mz + 0.02,
                    vx = 0, vy = 0, vz = 0.35,
                    age = 0, life = 0.14 + ZombRand(8) / 100,
                    r0 = 0.06, r1 = 0.11,
                    rot = 0, spin = 0,
                    cr = 0.45, cg = 0.65, cb = 1.0, alpha = 0.85,
                })
            end
            local cell = getCell()
            if cell then
                cell:addLamppost(IsoLightSource.new(math.floor(mx), math.floor(my), math.floor(mz), 1.0, 0.6, 0.2, 6))
            end
        end
    end

    -- 有火焰粒子存活时，在射流位置补充橙色光源
    if dt > 0 then
        local cell = getCell()
        if cell then
            local lx, ly, lz, n = 0, 0, 0, 0
            for _, p in pairs(particles) do
                if p.kind == "flame" then
                    lx, ly, lz = lx + p.x, ly + p.y, lz + p.z
                    n = n + 1
                    if n >= 6 then break end
                end
            end
            if n > 0 then
                cell:addLamppost(IsoLightSource.new(
                    math.floor(lx / n), math.floor(ly / n), math.floor(lz / n),
                    1.0, 0.55, 0.15, 8))
            end
        end
    end

    updateSounds(player, dt, aimingFT, spraying)
end
Events.OnPostRender.Add(OnPostRender)

-- ---------------------------------------------------------------------------
-- 暴露粒子引擎给下挂喷火器等其它客户端脚本复用：
-- 共享同一粒子列表与每帧 update/render（本文件已无条件推进与绘制），
-- 从而保证下挂喷火器的喷射动画与 Base.Flamethrower 完全一致。
-- ---------------------------------------------------------------------------
FlamethrowerFX = FlamethrowerFX or {}

-- 单脉冲火焰射流（与 Base.Flamethrower 喷射时使用的完全一致）
FlamethrowerFX.spawnPulse = spawnFlamePulse

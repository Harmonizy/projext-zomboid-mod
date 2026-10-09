-- Muzzle smoke：射击时枪口先闪一道锥形火光，随后一束烟雾急速冲出并消散。
-- 复用 Flamethrower_client.lua 的 renderPoly 绘制技术：
-- 火光 = gun_glow.png 拉伸成沿射击方向收敛的锥形（底宽尖窄）+ 枪口明亮核心；
-- 烟雾 = gun_smoke_1..3.png 面向屏幕的公告板粒子。
-- 触发：本地玩家射击（Events.OnWeaponSwing），模拟真实枪械的枪口火焰与烟雾。

local MS = {}
MuzzleSmoke = MS

MS.SMOKE_FRAMES   = 3    -- 使用 gun_smoke_1..3.png
MS.MAX_PARTICLES  = 240
MS.HEIGHT_OFFSET  = 0.43 -- 枪口相对玩家脚底的基础高度(格)
MS.HANDGUN_HEIGHT_OFFSET = 0.54 -- 手枪枪口高度(格)，比通用高 0.2
MS.SIDE_OFFSET    = 0.1  -- 枪口相对身体中心的右移偏移(格)
-- 握把(手)相对身体中心的前伸距离：步枪抵肩较近，手枪手臂伸直较远
MS.GRIP_FORWARD_RIFLE   = 0.5
MS.GRIP_FORWARD_HANDGUN = 0.40
-- 找不到 muzzle 附件时回退用的整体前伸偏移(保持旧行为)
MS.FALLBACK_FORWARD_RIFLE   = 0.55
MS.FALLBACK_FORWARD_HANDGUN = 0.52

-- ---------------------------------------------------------------------------
-- 贴图（延迟加载，避免进入游戏前 getTexture 返回空）
-- ---------------------------------------------------------------------------
local glowTex, smokeTex = nil, nil
local function ensureTextures()
    if smokeTex then return true end
    smokeTex = {}
    for i = 1, MS.SMOKE_FRAMES do
        smokeTex[i] = getTexture("media/textures/gun_smoke_" .. i .. ".png")
    end
    glowTex = getTexture("media/textures/gun_glow.png")
    return smokeTex[1] ~= nil
end

-- ---------------------------------------------------------------------------
-- 粒子系统
-- ---------------------------------------------------------------------------
local particles = {}

local function spawn(p)
    if #particles >= MS.MAX_PARTICLES then
        table.remove(particles, 1)
    end
    table.insert(particles, p)
end

-- ---------------------------------------------------------------------------
-- 读取枪械模型里 `attachment muzzle` 的偏移（X 左右 / Y 沿枪管前伸 / Z 上下）。
-- 模型原点在握把处，`attachment world` 是握把相对模型原点的位置，
-- 因此枪口相对握把的前伸距离 = muzzleY - worldY。
-- 这样每把枪的枪口位置都能和它自己的 attachment muzzle 对应。
-- ---------------------------------------------------------------------------
local function getMuzzleAttachment(weapon)
    if not weapon then return nil end
    local model = ScriptManager.instance:getModelScript("Base." .. weapon:getWeaponSprite())
    if not model then return nil end
    local muzzle = model:getAttachmentById("muzzle")
    if not muzzle then return nil end
    local off = muzzle:getOffset()
    local m = { x = off:x(), y = off:y(), z = off:z() }
    local world = model:getAttachmentById("world")
    if world then
        local wo = world:getOffset()
        m.wx, m.wy, m.wz = wo:x(), wo:y(), wo:z()
    end
    return m
end

local function getMuzzle(player, weapon)
    local fwd = player:getForwardDirection()
    if not fwd then return nil end
    local dir = fwd:getDirection()

    -- 握把相对身体中心的前伸距离
    local isHandgun = weapon and weapon:getWeaponReloadType() == WeaponReloadType.HANDGUN
    local gripForward = isHandgun and MS.GRIP_FORWARD_HANDGUN or MS.GRIP_FORWARD_RIFLE
    -- 手枪单独设置枪口高度
    local heightOffset = isHandgun and MS.HANDGUN_HEIGHT_OFFSET or MS.HEIGHT_OFFSET

    local m = getMuzzleAttachment(weapon)
    local forward, side, height
    if m then
        local wy = m.wy or 0.13
        forward = gripForward + (m.y - wy)  -- 握把 → 枪口，沿枪管
        side    = (m.x - (m.wx or 0)) + MS.SIDE_OFFSET   -- 左右(通常为 0) + 手动右移
        height  = m.z                       -- 枪口相对握把的上下偏移
    else
        -- 无 muzzle 附件：回退到旧的整体前伸偏移
        forward = isHandgun and MS.FALLBACK_FORWARD_HANDGUN or MS.FALLBACK_FORWARD_RIFLE
        side, height = MS.SIDE_OFFSET, 0
    end

    local fx, fy = math.cos(dir), math.sin(dir)
    local rx, ry = math.cos(dir + math.pi / 2), math.sin(dir + math.pi / 2)
    local mx = player:getX() + fx * forward + rx * side
    local my = player:getY() + fy * forward + ry * side
    local mz = player:getZ() + heightOffset + height
    return mx, my, mz, dir
end

-- 射击瞬间：先闪一道锥形火光，随后一束烟雾急速冲出并消散
local function onWeaponSwing(player, weapon)
    if not player or not weapon then return end
    if not player:isLocalPlayer() then return end
    if AWCWF_Options and AWCWF_Options.isMuzzleSmokeEnabled and not AWCWF_Options.isMuzzleSmokeEnabled() then return end
    if weapon:isMelee() or not weapon:isRanged() then return end
    if not ISReloadWeaponAction.canShoot(player, weapon) then return end

    local mx, my, mz, dir = getMuzzle(player, weapon)
    if not mx then return end

    -- 锥形火光：底在枪口、尖端沿射击方向伸出，极短促
    spawn({
        kind = "flash",
        x = mx, y = my, z = mz,
        vx = 0, vy = 0, vz = 0,
        dir = dir,
        age = 0, life = 0.06,
        len = 0.5, baseHalf = 0.14,
        cr = 1.0, cg = 0.85, cb = 0.45, alpha = 0.95,
    })

    -- 烟雾：一束急速向前冲出的烟雾，随后快速扩散消散
    for _ = 1, 10 do
        spawn({
            kind = "smoke",
            x = mx + (ZombRand(10) - 5) / 100,
            y = my + (ZombRand(10) - 5) / 100,
            z = mz + ZombRand(4) / 100,
            vx = math.cos(dir) * (1.6 + ZombRand(80) / 100) + (ZombRand(20) - 10) / 100,
            vy = math.sin(dir) * (1.6 + ZombRand(80) / 100) + (ZombRand(20) - 10) / 100,
            vz = (ZombRand(10) - 5) / 100,
            age = 0,
            life = 0.28 + ZombRand(15) / 100,
            r0 = 0.05 + ZombRand(4) / 100,
            r1 = 0.30 + ZombRand(12) / 100,
            rot = math.rad(ZombRand(360)),
            spin = math.rad((ZombRand(200) - 100) / 100),
        })
    end
end

local function updateParticles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.age = p.age + dt
        if p.age >= p.life then
            table.remove(particles, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.z = p.z + p.vz * dt
            if p.kind == "smoke" then
                -- 急速冲出的烟雾：强阻力快速衰减，扩散消散
                local drag = math.max(0, 1 - 2.5 * dt)
                p.vx = p.vx * drag
                p.vy = p.vy * drag
                p.rot = p.rot + p.spin * dt
            end
        end
    end
end

local function renderParticles(renderer, player)
    if not ensureTextures() then return end
    if #particles == 0 then return end

    -- 以玩家为中心估算“每世界单位对应的屏幕像素”，自动适应缩放
    local x0, y0 = ISCoordConversion.ToScreen(player:getX(), player:getY(), player:getZ(), 0)
    local x1, y1 = ISCoordConversion.ToScreen(player:getX() + 1, player:getY(), player:getZ(), 0)
    local ppu = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
    if ppu < 4 then ppu = 4 end

    for _, p in ipairs(particles) do
        local t = p.age / p.life

        if p.kind == "flash" then
            -- 锥形火光：gun_glow.png 拉伸成底宽尖窄的锥形，底在枪口、尖向前
            local alpha = (p.alpha or 0.95) * (1 - t)
            if alpha > 0.01 and glowTex then
                local fx, fy = math.cos(p.dir), math.sin(p.dir)
                local sx0, sy0 = ISCoordConversion.ToScreen(p.x, p.y, p.z, 0)
                local sx1, sy1 = ISCoordConversion.ToScreen(p.x + fx * p.len, p.y + fy * p.len, p.z, 0)
                local ddx, ddy = sx1 - sx0, sy1 - sy0
                local dlen = math.sqrt(ddx * ddx + ddy * ddy)
                if dlen > 0.01 then
                    ddx, ddy = ddx / dlen, ddy / dlen
                end
                local px, py = -ddy, ddx
                local bw = p.baseHalf * ppu -- 底(枪口)半宽
                local tw = bw * 0.25        -- 尖(前方)半宽，收敛成锥
                renderer:renderPoly(glowTex,
                    sx0 - px * bw, sy0 - py * bw,
                    sx0 + px * bw, sy0 + py * bw,
                    sx1 + px * tw, sy1 + py * tw,
                    sx1 - px * tw, sy1 - py * tw,
                    p.cr or 1, p.cg or 1, p.cb or 1, alpha)
                -- 枪口明亮核心
                local br = bw * 0.9
                renderer:renderPoly(glowTex,
                    sx0 - br, sy0 - br, sx0 + br, sy0 - br,
                    sx0 + br, sy0 + br, sx0 - br, sy0 + br,
                    1.0, 0.95, 0.75, alpha)
            end
        else
            -- 烟雾：面向屏幕的公告板
            local sx, sy = ISCoordConversion.ToScreen(p.x, p.y, p.z, 0)
            local r = (p.r0 + (p.r1 - p.r0) * t) * ppu
            local si = math.min(MS.SMOKE_FRAMES, math.floor(t * MS.SMOKE_FRAMES) + 1)
            local tex = smokeTex[si]
            local alpha = 0.7 * (1 - t)
            if tex and alpha > 0.01 then
                local ca, sa = math.cos(p.rot or 0), math.sin(p.rot or 0)
                renderer:renderPoly(tex,
                    sx - r * ca + r * sa, sy - r * sa - r * ca,
                    sx + r * ca + r * sa, sy + r * sa - r * ca,
                    sx + r * ca - r * sa, sy + r * sa + r * ca,
                    sx - r * ca - r * sa, sy - r * sa + r * ca,
                    1.0, 1.0, 1.0, alpha)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- 每帧：推进并绘制粒子
-- ---------------------------------------------------------------------------
local function OnPostRender()
    local player = getPlayer()
    if not player then return end
    local renderer = getRenderer()
    if not renderer then return end

    local dt = (getGameTime():getMultiplier() or 0) / 60
    if dt > 0.1 then dt = 0.1 end

    updateParticles(dt)
    renderParticles(renderer, player)
end

Events.OnWeaponSwing.Add(onWeaponSwing)
Events.OnPostRender.Add(OnPostRender)

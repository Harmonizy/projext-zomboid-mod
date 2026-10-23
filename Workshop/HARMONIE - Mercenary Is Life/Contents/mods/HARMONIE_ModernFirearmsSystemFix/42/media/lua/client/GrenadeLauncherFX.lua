-- 下挂榴弹发射器特效（客户端）
-- 射击特效：扣动扳机时枪口向前喷出一团烟雾（ft_smoke_1..8.png）。
-- 爆炸特效：榴弹落点播放 Item_boomboom1..12.png 火球动画，叠加一帧高亮闪光
--  （ft_glow.png）与缓慢上升的余烟，并用 IsoLightSource 短暂照亮周围。
-- 实现参考 Flamethrower_client.lua / MuzzleSmoke.lua：在 OnPostRender 中推进
-- 粒子并用 renderer:renderPoly 把贴图按世界坐标投影到屏幕，构成粒子特效。

local FX = {}
GrenadeLauncherFX = FX

FX.SMOKE_FRAMES  = 8    -- ft_smoke_1..8.png
FX.BOOM_FRAMES   = 12   -- Item_boomboom1..12.png
FX.MAX_PARTICLES = 400

-- ---------------------------------------------------------------------------
-- 贴图（延迟加载，避免进入游戏前 getTexture 返回空）
-- ---------------------------------------------------------------------------
local smokeTex, boomTex, glowTex = nil, nil, nil
local function ensureTextures()
    if boomTex then return true end
    smokeTex = {}
    for i = 1, FX.SMOKE_FRAMES do
        smokeTex[i] = getTexture("media/textures/ft_smoke_" .. i .. ".png")
    end
    boomTex = {}
    for i = 1, FX.BOOM_FRAMES do
        boomTex[i] = getTexture("media/textures/Item_boomboom" .. i .. ".png")
    end
    glowTex = getTexture("media/textures/ft_glow.png")
    return boomTex[1] ~= nil
end

-- ---------------------------------------------------------------------------
-- 粒子系统
-- ---------------------------------------------------------------------------
local particles = {}

local function spawn(p)
    if #particles >= FX.MAX_PARTICLES then
        table.remove(particles, 1)
    end
    table.insert(particles, p)
end

-- 射击特效：枪口向前喷出一团烟雾，沿射击方向扩散消散。
function FX.spawnMuzzleSmoke(mx, my, mz, dir)
    for _ = 1, 12 do
        local a = dir + (ZombRand(200) - 100) / 100 * math.rad(8)
        local speed = 1.8 + ZombRand(120) / 100
        spawn({
            kind = "smoke",
            x = mx + (ZombRand(10) - 5) / 100,
            y = my + (ZombRand(10) - 5) / 100,
            z = mz + ZombRand(6) / 100,
            vx = math.cos(a) * speed,
            vy = math.sin(a) * speed,
            vz = 0.05 + ZombRand(12) / 100,
            age = 0,
            life = 0.55 + ZombRand(35) / 100,
            r0 = 0.08 + ZombRand(5) / 100,
            r1 = 0.50 + ZombRand(25) / 100,
            rot = math.rad(ZombRand(360)),
            spin = math.rad((ZombRand(200) - 100) / 100),
        })
    end
end

-- 弹道尾迹：榴弹飞行时在其当前位置留下两小团烟。
function FX.spawnTrailSmoke(x, y, z)
    for _ = 1, 2 do
        spawn({
            kind = "smoke",
            x = x + (ZombRand(12) - 6) / 100,
            y = y + (ZombRand(12) - 6) / 100,
            z = z + ZombRand(6) / 100,
            vx = (ZombRand(20) - 10) / 100,
            vy = (ZombRand(20) - 10) / 100,
            vz = 0.10 + ZombRand(10) / 100,
            age = 0,
            life = 0.45 + ZombRand(25) / 100,
            r0 = 0.05 + ZombRand(3) / 100,
            r1 = 0.30 + ZombRand(15) / 100,
            rot = math.rad(ZombRand(360)),
            spin = math.rad((ZombRand(200) - 100) / 100),
        })
    end
end

-- 爆炸特效：火球动画 + 高亮闪光 + 上升余烟。
function FX.spawnExplosion(x, y, z)
    -- 高亮闪光：一帧极亮的亮点，极短促
    spawn({
        kind = "flash",
        x = x, y = y, z = z,
        vx = 0, vy = 0, vz = 0,
        age = 0, life = 0.12,
        r0 = 1.6, r1 = 2.2,
        rot = 0, spin = 0,
    })
    -- 火球：Item_boomboom1..12 帧动画，膨胀后淡出
    spawn({
        kind = "boom",
        x = x, y = y, z = z,
        vx = 0, vy = 0, vz = 0,
        age = 0, life = 0.52,
        r0 = 0.55, r1 = 2.4,
        rot = math.rad(ZombRand(360)),
    })
    -- 余烟：缓慢上升并扩散的黑烟
    for _ = 1, 8 do
        spawn({
            kind = "smoke",
            x = x + (ZombRand(60) - 30) / 100,
            y = y + (ZombRand(60) - 30) / 100,
            z = z + 0.1,
            vx = (ZombRand(40) - 20) / 100,
            vy = (ZombRand(40) - 20) / 100,
            vz = 0.35 + ZombRand(25) / 100,
            age = 0,
            life = 1.1 + ZombRand(60) / 100,
            r0 = 0.20 + ZombRand(10) / 100,
            r1 = 0.85 + ZombRand(35) / 100,
            rot = math.rad(ZombRand(360)),
            spin = math.rad((ZombRand(160) - 80) / 100),
        })
    end
    -- 爆炸闪光：短暂照亮周围
    local cell = getCell()
    if cell then
        cell:addLamppost(IsoLightSource.new(
            math.floor(x), math.floor(y), math.floor(z + 0.5),
            1.0, 0.65, 0.25, 14))
    end
end

-- 弹药编程装置命中爆炸：仅一帧高亮闪光（ft_glow.png）+ 少量烟雾（ft_smoke_1..6），
-- 不使用火球动画，也不使用爆炸音效。
function FX.spawnAmmoPDExplosion(x, y, z)
    spawn({
        kind = "flash",
        x = x, y = y, z = z + 0.25,
        vx = 0, vy = 0, vz = 0,
        age = 0, life = 0.18,
        r0 = 0.9, r1 = 1.4,
        rot = 0, spin = 0,
    })
    for _ = 1, 6 do
        spawn({
            kind = "smoke",
            frames = 6,
            x = x + (ZombRand(40) - 20) / 100,
            y = y + (ZombRand(40) - 20) / 100,
            z = z + 0.05,
            vx = (ZombRand(30) - 15) / 100,
            vy = (ZombRand(30) - 15) / 100,
            vz = 0.25 + ZombRand(20) / 100,
            age = 0,
            life = 0.8 + ZombRand(40) / 100,
            r0 = 0.15 + ZombRand(8) / 100,
            r1 = 0.6 + ZombRand(25) / 100,
            rot = math.rad(ZombRand(360)),
            spin = math.rad((ZombRand(140) - 70) / 100),
        })
    end
end

-- ---------------------------------------------------------------------------
-- 每帧推进
-- ---------------------------------------------------------------------------
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
                -- 烟雾受强阻力减速，随自转缓慢扩散
                local drag = math.max(0, 1 - 1.6 * dt)
                p.vx = p.vx * drag
                p.vy = p.vy * drag
                p.rot = p.rot + p.spin * dt
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- 每帧绘制
-- ---------------------------------------------------------------------------
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
        local sx, sy = ISCoordConversion.ToScreen(p.x, p.y, p.z, 0)
        local tex, cr, cg, cb, alpha, r

        if p.kind == "boom" then
            local bi = math.min(FX.BOOM_FRAMES, math.floor(t * FX.BOOM_FRAMES) + 1)
            tex = boomTex[bi]
            r = (p.r0 + (p.r1 - p.r0) * t) * ppu
            cr, cg, cb = 1.0, 1.0, 1.0
            -- 前半段保持不透明，后半段淡出，避免最后一帧突然消失
            if t < 0.7 then
                alpha = 1.0
            else
                alpha = 1.0 - (t - 0.7) / 0.3
            end
        elseif p.kind == "flash" then
            tex = glowTex
            r = (p.r0 + (p.r1 - p.r0) * t) * ppu
            cr, cg, cb = 1.0, 0.9, 0.6
            alpha = 0.95 * (1 - t)
        else -- smoke
            local frames = p.frames or FX.SMOKE_FRAMES
            local si = math.min(frames, math.floor(t * frames) + 1)
            tex = smokeTex[si]
            r = (p.r0 + (p.r1 - p.r0) * t) * ppu
            cr, cg, cb = 1.0, 1.0, 1.0
            alpha = 0.55 * (1 - t)
        end

        if tex and alpha > 0.01 then
            local ca, sa = math.cos(p.rot or 0), math.sin(p.rot or 0)
            renderer:renderPoly(tex,
                sx - r * ca + r * sa, sy - r * sa - r * ca,
                sx + r * ca + r * sa, sy + r * sa - r * ca,
                sx + r * ca - r * sa, sy + r * sa + r * ca,
                sx - r * ca - r * sa, sy - r * sa + r * ca,
                cr, cg, cb, alpha)
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

Events.OnPostRender.Add(OnPostRender)

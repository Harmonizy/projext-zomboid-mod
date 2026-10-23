-- 热成像瞄具 ThermalImaging_cat（L_Scope 槽位）
-- 当枪械安装 ThermalImaging_cat 并瞄准（isAiming）时，在视野内（前方锥形范围、
-- 40 格内且无遮挡）的僵尸身上绘制热源光斑（ft_glow.png 叠加粉红色）。一旦进入
-- 视野即保持高亮，直到僵尸死亡、停止瞄准或换掉热成像瞄具为止。
-- 不依赖 PZ 内置 setOutlineHighlight（其同时高亮数量有限），改用 OnPostRender
-- 自绘光斑，因此可高亮任意数量的目标。

local MAX_DISTANCE = 40     -- 探测距离（格）
local HALF_ANGLE   = 0.7    -- 视场半角（弧度，约 40°）
local SCAN_INTERVAL = 1     -- 每 N 帧重新扫描一次
local COLOR_R, COLOR_G, COLOR_B = 1.0, 0.35, 0.65
local GLOW_ALPHA  = 0.4     -- 光斑透明度
local GLOW_RADIUS = 0.5     -- 光斑半径（世界单位，约半格）
local GLOW_HEIGHT = 0.3     -- 光斑中心高度（僵尸身体中部）
local CLEAR_DELAY_FRAMES = 300 -- 瞄准条件失效后保留高亮的帧数（约 0.5 秒），避免瞄准短暂中断就清空

local highlighted = {}      -- 当前处于高亮状态的僵尸集合
local tick = 0
local aimLostFrames = 20     -- 瞄准条件已失效的连续帧数
local glowTex = nil

local function ensureTexture()
    if glowTex then return true end
    glowTex = getTexture("media/textures/ft_glow.png")
    return glowTex ~= nil
end

local function NormalizeAngle(a)
    while a > math.pi do a = a - 2 * math.pi end
    while a < -math.pi do a = a + 2 * math.pi end
    return a
end

local function HasThermalScope(player)
    local weapon = player:getPrimaryHandItem()
    if not (weapon and weapon:IsWeapon() and weapon:isRanged()) then return false end
    local part = weapon:getWeaponPart("L_Scope")
    return part ~= nil and part:getType() == "ThermalImaging_cat"
end

local function ScanZombiesInView(player)
    local result = {}
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local forward = player:getForwardDirection()
    local facing = (forward and forward:getDirection()) or player:getDirectionAngle()

    local cell = getCell()
    if not cell then return result end

    local r = MAX_DISTANCE
    local r2 = r * r
    local minX, maxX = math.floor(px - r), math.floor(px + r)
    local minY, maxY = math.floor(py - r), math.floor(py + r)

    for x = minX, maxX do
        for y = minY, maxY do
            local sdx, sdy = (x + 0.5) - px, (y + 0.5) - py
            if sdx * sdx + sdy * sdy <= r2 then
                local sq = cell:getGridSquare(x, y, pz)
                if sq and sq:isCanSee(player:getPlayerNum()) then
                    local zombies = sq:getMovingObjects()
                    for i = 0, zombies:size() - 1 do
                        local z = zombies:get(i)
                        if instanceof(z, "IsoZombie") and not z:isDead() then
                            local dx, dy = z:getX() - px, z:getY() - py
                            if dx * dx + dy * dy <= r2 then
                                local ang = math.atan2(dy, dx)
                                if math.abs(NormalizeAngle(ang - facing)) <= HALF_ANGLE then
                                    table.insert(result, z)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return result
end

local function UpdateThermalHighlight()
    local player = getPlayer()
    if not player then
        highlighted = {}
        aimLostFrames = 0
        return
    end

    if player:isAiming() and HasThermalScope(player) then
        aimLostFrames = 0

        -- 扫描视野内新进入的僵尸并累积加入高亮集合
        tick = tick + 1
        if tick % SCAN_INTERVAL == 0 then
            for _, z in ipairs(ScanZombiesInView(player)) do
                highlighted[z] = true
            end
        end
    else
        -- 瞄准条件失效：短暂中断不清空，持续失效一段时间后才清空
        aimLostFrames = aimLostFrames + 1
        if aimLostFrames >= CLEAR_DELAY_FRAMES then
            highlighted = {}
            aimLostFrames = 0
            return
        end
    end

    -- 清除已死亡的僵尸
    for z in pairs(highlighted) do
        if not (z and instanceof(z, "IsoZombie") and not z:isDead()) then
            highlighted[z] = nil
        end
    end
end

local function RenderThermalHighlight()
    local player = getPlayer()
    if not player then return end
    local renderer = getRenderer()
    if not renderer then return end
    if not ensureTexture() then return end

    -- 以玩家为中心估算“每世界单位对应的屏幕像素”，自动适应缩放
    local x0, y0 = ISCoordConversion.ToScreen(player:getX(), player:getY(), player:getZ(), 0)
    local x1, y1 = ISCoordConversion.ToScreen(player:getX() + 1, player:getY(), player:getZ(), 0)
    local ppu = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
    if ppu < 4 then ppu = 4 end

    local r = GLOW_RADIUS * ppu

    for z in pairs(highlighted) do
        if z and instanceof(z, "IsoZombie") and not z:isDead() then
            local sx, sy = ISCoordConversion.ToScreen(z:getX(), z:getY(), z:getZ() + GLOW_HEIGHT, 0)
            renderer:renderPoly(glowTex,
                sx - r, sy - r,
                sx + r, sy - r,
                sx + r, sy + r,
                sx - r, sy + r,
                COLOR_R, COLOR_G, COLOR_B, GLOW_ALPHA)
        end
    end
end

Events.OnTick.Add(UpdateThermalHighlight)
Events.OnPostRender.Add(RenderThermalHighlight)

local weaponitemname = "Base.MTL30_cat"


local isdisplay = false

local radius = 200
local angle = 0
local tex = getTexture("media/textures/Ballistic.png")
local iscanshoot = false

local function pickSquare(x, y)
    local zoom = getCore():getZoom(0)
    local z = getSpecificPlayer(0):getSquare():getZ()
    local worldX = IsoUtils.XToIso(x * zoom, y * zoom, z)
    local worldY = IsoUtils.YToIso(x * zoom, y * zoom, z)
    return worldX, worldY, z
end

local function fxmanager(weapon, player, renderer, gametime)

    local x = getMouseX()
    local y = getMouseY()
    -- local sqX, sqY, sqZ = pickSquare(x, y)

    local range = weapon:getMaxRange(player)
    local sq = DebugContextMenu.pickSquare(x, y)

    local zoom = getCore():getZoom(0)
    x = x * zoom
    y = y * zoom

    local x1 = x - radius
    local y1 = y - radius
    local x2 = x + radius
    local y2 = y - radius
    local x3 = x + radius
    local y3 = y + radius
    local x4 = x - radius
    local y4 = y + radius
    angle = angle - 5 * gametime
    local angle2 = math.rad(angle)

    local dx1, dy1 = x1 - x, y1 - y
    local dx2, dy2 = x2 - x, y2 - y
    local dx3, dy3 = x3 - x, y3 - y
    local dx4, dy4 = x4 - x, y4 - y

    -- 先旋转四个点
    local rx1 = dx1 * math.cos(angle2) - dy1 * math.sin(angle2) + x
    local ry1 = dx1 * math.sin(angle2) + dy1 * math.cos(angle2) + y
    local rx2 = dx2 * math.cos(angle2) - dy2 * math.sin(angle2) + x
    local ry2 = dx2 * math.sin(angle2) + dy2 * math.cos(angle2) + y
    local rx3 = dx3 * math.cos(angle2) - dy3 * math.sin(angle2) + x
    local ry3 = dx3 * math.sin(angle2) + dy3 * math.cos(angle2) + y
    local rx4 = dx4 * math.cos(angle2) - dy4 * math.sin(angle2) + x
    local ry4 = dx4 * math.sin(angle2) + dy4 * math.cos(angle2) + y

    local centerX = (rx1 + rx3) / 2
    local centerY = (ry1 + ry3) / 2

    local function iso(xp, yp)
        return centerX + (xp - centerX), centerY + (yp - centerY) * 0.5
    end

    x1, y1 = iso(rx1, ry1)
    x2, y2 = iso(rx2, ry2)
    x3, y3 = iso(rx3, ry3)
    x4, y4 = iso(rx4, ry4)

    local psq = player:getCurrentSquare()

    if sq and psq and sq:DistToProper(psq) <= range then
        renderer:renderPoly(tex, x1, y1, x2, y2, x3, y3, x4, y4, 0.1, 1, 0.1, 1)
        iscanshoot = sq

    else
        renderer:renderPoly(tex, x1, y1, x2, y2, x3, y3, x4, y4, 1, 0.1, 0.1, 1)
        iscanshoot = false

    end

end
local function OnPostRender()

    local player = getPlayer()
    if not player then
        return
    end

    local renderer = getRenderer();
    local gametime = getGameTime():getMultiplier()

    local weaitem = player:getPrimaryHandItem()
    if player:isAiming() and instanceof(weaitem, "HandWeapon") and weaitem:getFullType() == weaponitemname then

        fxmanager(weaitem, player, renderer, gametime)

    else
        iscanshoot = false
    end
end

Events.OnPostRender.Add(OnPostRender)

local function KillZombiesAtSquare(sq, range)
    if not sq then
        return
    end
    local player = getPlayer()
    local cx, cy, cz = sq:getX(), sq:getY(), sq:getZ()
    for dy = -range, range do
        for dx = -range, range do
            local s = getCell():getGridSquare(cx + dx, cy + dy, cz)
            if s then
                local zombies = s:getMovingObjects()
                for i = 0, zombies:size() - 1 do
                    local zombie = zombies:get(i)
                    if instanceof(zombie, "IsoZombie") and not zombie:isDead() then
                        if player then
                            zombie:Kill(player)
                        else
                            zombie:setHealth(0)
                        end
                    end
                end
            end
        end
    end
end

local function OnWeaponSwingHitPoint()
    if iscanshoot then
        KillZombiesAtSquare(iscanshoot, 3)
        getSoundManager():PlayWorldSound("AerosolBombExplode", iscanshoot, 0, 4, 1.0, false)
    end
end

Events.OnWeaponSwingHitPoint.Add(OnWeaponSwingHitPoint)

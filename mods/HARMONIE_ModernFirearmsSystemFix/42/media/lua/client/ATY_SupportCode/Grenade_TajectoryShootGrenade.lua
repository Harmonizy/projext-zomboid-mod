Grenade_Tajectory = Grenade_Tajectory or {}
local TickTable = {}

function Grenade_Tajectory.ShootGrenade(character, handWeapon, GrenadeTypeInfo)

    local DirectSquare = Grenade_Tajectory.aimcursorsq
    local Distance = Grenade_Tajectory.aimtexdistance
    -- 记录发射起点与总距离，供弹道烟雾尾迹沿线插值使用
    local startX = character and character:getX() or nil
    local startY = character and character:getY() or nil
    local startZ = character and (character:getZ() + 0.4) or 0.4
    table.insert(TickTable, {
        DirectSquare = DirectSquare,
        Distance = Distance,
        InitialDistance = Distance,
        GrenadeTypeInfo = GrenadeTypeInfo,
        StartX = startX,
        StartY = startY,
        StartZ = startZ,
    })

end

function Grenade_Tajectory.ShootGrenadeTick()
    for i, v in pairs(TickTable) do
        if v.Distance > 0 then
            v.Distance = v.Distance - 1
            -- 弹道烟雾尾迹：沿飞行路径插值出当前榴弹位置，喷一小团烟
            if GrenadeLauncherFX and GrenadeLauncherFX.spawnTrailSmoke and v.DirectSquare and v.StartX then
                local progress = 1 - v.Distance / math.max(v.InitialDistance or v.Distance + 1, 1)
                local tx = v.DirectSquare:getX() + 0.5
                local ty = v.DirectSquare:getY() + 0.5
                local tz = v.DirectSquare:getZ() + 0.15
                local sx, sy, sz = v.StartX, v.StartY, v.StartZ
                local gx = sx + (tx - sx) * progress
                local gy = sy + (ty - sy) * progress
                -- 抛物线弧高：飞行中段最高，落地时贴地
                local gz = sz + (tz - sz) * progress + math.sin(progress * math.pi) * 1.5
                GrenadeLauncherFX.spawnTrailSmoke(gx, gy, gz)
            end
        else
            Grenade_Tajectory.Boom(v.DirectSquare, v.GrenadeTypeInfo)
            table.remove(TickTable, i)
        end
    end
end

Events.OnTick.Add(Grenade_Tajectory.ShootGrenadeTick)

local MFSEject = require("MFSEject/Init")

MFSEject.activeCasings           = {}
MFSEject.RANDOM                  = newrandom()
MFSEject.GRAVITY                 = 0.020
MFSEject.XY_STEP                 = 0.10
MFSEject.Z_STEP                  = 0.05
MFSEject.GRAVITY_SCALE           = 1.0
MFSEject.DRAG_XY                 = 0.97
MFSEject.DRAG_Z                  = 0.995
MFSEject.SETTLE_THRESHOLD        = 0.001
MFSEject.BOUNCE_RESTITUTION      = 0.60
MFSEject.BOUNCE_POSITION_CORRECT = 0.12
MFSEject.BOUNCE_MIN_VELOCITY     = 0.004
MFSEject.LOW_WALL_Z_THRESHOLD    = 0.25

MFSEject.SurfaceType = {
    Concrete = "Concrete",
    Dirt     = "Dirt",
    Grass    = "Grass",
    Puddles  = "Puddles",
    Snow     = "Snow",
    Wood     = "Wood",
}

MFSEject.FOOTSTEP_TO_SURFACE = {
    Concrete = MFSEject.SurfaceType.Concrete,
    Brick    = MFSEject.SurfaceType.Concrete,

    Dirt     = MFSEject.SurfaceType.Dirt,
    Gravel   = MFSEject.SurfaceType.Dirt,
    Sand     = MFSEject.SurfaceType.Dirt,
    Carpet   = MFSEject.SurfaceType.Dirt,

    Grass    = MFSEject.SurfaceType.Grass,

    Water    = MFSEject.SurfaceType.Puddles,

    Snow     = MFSEject.SurfaceType.Snow,

    Wood     = MFSEject.SurfaceType.Wood,
}

MFSEject.CasingImpactSoundParams = {
    Bullet = {
        Concrete = { prefix = "Bullet_Concrete_", variations = 6 },
        Dirt     = { prefix = "Bullet_Dirt_", variations = 6 },
        Grass    = { prefix = "Bullet_Grass_", variations = 6 },
        Puddles  = { prefix = "Bullet_Puddles_", variations = 6 },
        Snow     = { prefix = "Bullet_Snow_", variations = 6 },
        Wood     = { prefix = "Bullet_Wood_", variations = 6 },
    },
    Shells = {
        Concrete = { prefix = "Shells_Concrete_", variations = 6 },
        Dirt     = { prefix = "Shells_Dirt_", variations = 6 },
        Grass    = { prefix = "Shells_Grass_", variations = 6 },
        Puddles  = { prefix = "Shells_Puddles_", variations = 6 },
        Snow     = { prefix = "Shells_Snow_", variations = 6 },
        Wood     = { prefix = "Shells_Wood_", variations = 6 },
    },
}

function MFSEject.isLowWall(wall)
    if not wall then return false end
    local props = wall.getProperties and wall:getProperties() or nil
    if not props then return false end

    if props:has(IsoFlagType.transparentW)
        or props:has(IsoFlagType.transparentN)
        or props:has(IsoFlagType.HoppableW)
        or props:has(IsoFlagType.HoppableN)
    then
        return true
    end
    return false
end

function MFSEject.isBlockedBetweenSquares(fromSq, toSq, dir, casingZ)
    if not fromSq or not toSq or not dir then return false end

    local barrier = fromSq:getDoorOrWindowOrWindowFrame(dir, true)
    if not barrier then
        local revDir = dir:Rot180()
        barrier = toSq:getDoorOrWindowOrWindowFrame(revDir, true)
    end

    if barrier and (instanceof(barrier, "IsoDoor") or instanceof(barrier, "IsoWindow")) then
        local destroyed = barrier.isDestroyed and barrier:isDestroyed() or false
        if not barrier:IsOpen() and not destroyed then
            return true
        end
        return false
    end

    if fromSq:isWallTo(toSq) then
        local wall1 = fromSq:getWall()
        local wall2 = toSq:getWall()

        local isLow = (wall1 and MFSEject.isLowWall(wall1)) or
            (wall2 and MFSEject.isLowWall(wall2))

        if isLow then
            return (casingZ or 0) < MFSEject.LOW_WALL_Z_THRESHOLD
        end

        return true
    end

    return false
end

function MFSEject.isWaterFloor(floor)
    if not floor then return false end
    local props = floor.getProperties and floor:getProperties() or nil
    if not props then return false end

    if props:has(IsoFlagType.water) then
        return true
    end
    return false
end

function MFSEject.isSoftFloor(floor)
    if not floor then return false end

    local sq = floor.getSquare and floor:getSquare() or nil
    if sq then
        local cell = getCell()
        if cell and cell:gridSquareIsSnow(sq:getX(), sq:getY(), sq:getZ()) then
            return true
        end
    end

    local props = floor.getProperties and floor:getProperties() or nil
    if not props then return false end

    local mat = props:get("FootstepMaterial")
    if mat == "Grass" or mat == "Sand" or mat == "Snow" then
        return true
    end

    return false
end

function MFSEject.getTileTopZ(square)
    if not square then return nil end

    local objects = square:getObjects()
    if not objects then return nil end

    local topZ = nil

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            local surfOff = nil

            if obj.getSurfaceOffsetNoTable then
                surfOff = obj:getSurfaceOffsetNoTable()
            end

            if (not surfOff or surfOff <= 0) and obj.getSurfaceOffset then
                local so = obj:getSurfaceOffset()
                if so and so > 0 then
                    surfOff = so
                end
            end

            if surfOff and surfOff > 0 then
                local z = surfOff / 96.0
                if not topZ or z > topZ then
                    topZ = z
                end
            end
        end
    end

    return topZ
end

function MFSEject.getSurfaceTypeFromSquare(square)
    if not square then
        return MFSEject.SurfaceType.Concrete
    end

    local floor = square:getFloor()
    if not floor then
        return MFSEject.SurfaceType.Concrete
    end

    if MFSEject.isWaterFloor(floor) then
        return MFSEject.SurfaceType.Puddles
    end

    local cell = getCell()
    if cell and cell.gridSquareIsSnow and cell:gridSquareIsSnow(square:getX(), square:getY(), square:getZ()) then
        return MFSEject.SurfaceType.Snow
    end

    local props = floor.getProperties and floor:getProperties() or nil
    if not props then
        return MFSEject.SurfaceType.Concrete
    end

    local mat = props:get("FootstepMaterial")
    local surface = MFSEject.FOOTSTEP_TO_SURFACE[mat]

    return surface or MFSEject.SurfaceType.Concrete
end

function MFSEject.getCasingSoundFamily(casing)
    if not casing then
        return "Bullet"
    end

    local weapon = casing.weapon

    if weapon and weapon.getAmmoType then
        local ammoType = weapon:getAmmoType():getItemKey()
        if ammoType and (
                ammoType == "Base.ShotgunShells"
            ) then
            return "Shells"
        end
    end

    if weapon and weapon.getShellFallSound then
        local shellSound = weapon:getShellFallSound()
        if shellSound and (
                shellSound == "DoubleBarrelShotgunCartridgeFall" or
                shellSound == "SawnOffDoubleBarrelShotgunCartridgeFall" or
                shellSound == "JS2000ShotgunCartridgeFall" or
                shellSound == "SawnOffJS2000ShotgunCartridgeFall")
        then
            return "Shells"
        end
    end

    return "Bullet"
end

function MFSEject.playCasingImpactSound(casing, square)
    if not casing or not casing.repeatCasingSound then return end

    if casing.customSound then
        if isServer() then
            if casing.player then
                sendServerCommand(casing.player, "MFSEject", "playCasingImpactSound", { sound = casing.customSound })
            else
                sendServerCommand("MFSEject", "playCasingImpactSound", { sound = casing.customSound })
            end
            return
        end

        if casing.player then
            casing.player:getEmitter():playSound(casing.customSound)
        end
        casing.repeatCasingSound = false
        return
    end

    local family = MFSEject.getCasingSoundFamily(casing)
    local surfaceTypeName = MFSEject.getSurfaceTypeFromSquare(square)

    local familyParams = MFSEject.CasingImpactSoundParams[family]
    if not familyParams then return end

    local params = familyParams[surfaceTypeName] or familyParams.Concrete
    if not params then return end

    local count = params.variations or 1
    local idx = (count > 1) and MFSEject.RANDOM:random(1, count) or 1
    local soundName = params.prefix .. tostring(idx)

    if isServer() then
        if casing.player then
            sendServerCommand(casing.player, "MFSEject", "playCasingImpactSound", { sound = soundName })
        else
            sendServerCommand("MFSEject", "playCasingImpactSound", { sound = soundName })
        end
        return
    end

    if casing.player then
        casing.player:getEmitter():playSound(soundName)
    end
end

function MFSEject.GT()
    return GameTime.getInstance()
end

function MFSEject.addCasing(
    player,
    weapon,
    square,
    casingType,
    startX,
    startY,
    startZ,
    velocityX,
    velocityY,
    velocityZ,
    customSound,
    floorBounces,
    ignoreDespawn)
    if not square then return end

    local casingData = {
        player = player,
        weapon = weapon,
        square = square,
        casingType = casingType,
        x = startX,
        y = startY,
        z = startZ,
        velocityX = velocityX or 0,
        velocityY = velocityY or 0,
        velocityZ = velocityZ or 0.1,
        active = true,
        currentWorldItem = nil,
        floorBounces = floorBounces or MFSEject.RANDOM:random(1, 2),
        hasHitFloor = false,
        repeatCasingSound = true,
        customSound = customSound,
        ignoreDespawn = ignoreDespawn,
    }

    casingData.currentWorldItem = square:AddWorldInventoryItem(casingType, startX, startY, startZ)

    local casings = MFSEject.activeCasings
    casings[#casings + 1] = casingData
end

function MFSEject.removeWorldItem(casing)
    if not casing.currentWorldItem then return end
    local wobj = casing.currentWorldItem:getWorldItem()
    if wobj then
        local wSquare = wobj:getSquare()
        if wSquare then
            if isServer() then
                wSquare:transmitRemoveItemFromSquare(wobj)
            end
            wSquare:removeWorldObject(wobj)
        end
    end
    casing.currentWorldItem = nil
end

function MFSEject.update()
    local dt = MFSEject.GT():getTimeDelta()
    local scale = dt * 60

    local casings = MFSEject.activeCasings
    local n = #casings
    local i = 1

    while i <= n do
        local casing = casings[i]
        local removed = false

        if not casing or not casing.square or not casing.active then
            casings[i] = casings[n]
            casings[n] = nil
            n = n - 1
            removed = true
        else
            local prevZ = casing.z or 0
            local oldEdgeX = casing.x
            local oldEdgeY = casing.y
            casing.velocityZ = casing.velocityZ -
                (MFSEject.GRAVITY * MFSEject.GRAVITY_SCALE * scale)

            casing.x = casing.x + (casing.velocityX * MFSEject.XY_STEP * scale)
            casing.y = casing.y + (casing.velocityY * MFSEject.XY_STEP * scale)
            casing.z = casing.z + (casing.velocityZ * MFSEject.Z_STEP * scale)

            casing.z = math.max(0, casing.z)

            local worldX = casing.square:getX() + casing.x
            local worldY = casing.square:getY() + casing.y
            local worldZ = casing.square:getZ()

            local dragXY = math.pow(MFSEject.DRAG_XY, scale)
            local dragZ = math.pow(MFSEject.DRAG_Z, scale)
            casing.velocityX = casing.velocityX * dragXY
            casing.velocityY = casing.velocityY * dragXY
            casing.velocityZ = casing.velocityZ * dragZ

            local localX = worldX - casing.square:getX()
            local localY = worldY - casing.square:getY()
            local edgeX = localX
            local edgeY = localY

            local EDGE_TOL = 0.15

            local sx = casing.square:getX()
            local sy = casing.square:getY()
            local sz = casing.square:getZ()

            local blockX = false
            local blockY = false

            if casing.velocityX > 0 and oldEdgeX < (1.0 - EDGE_TOL) and edgeX >= (1.0 - EDGE_TOL) then
                local neighbor = getCell():getGridSquare(sx + 1, sy, sz)
                if neighbor and MFSEject.isBlockedBetweenSquares(casing.square, neighbor, IsoDirections.E, casing.z) then
                    blockX = true
                end
            elseif casing.velocityX < 0 and oldEdgeX > EDGE_TOL and edgeX <= EDGE_TOL then
                local neighbor = getCell():getGridSquare(sx - 1, sy, sz)
                if neighbor and MFSEject.isBlockedBetweenSquares(casing.square, neighbor, IsoDirections.W, casing.z) then
                    blockX = true
                end
            end

            if casing.velocityY > 0 and oldEdgeY < (1.0 - EDGE_TOL) and edgeY >= (1.0 - EDGE_TOL) then
                local neighbor = getCell():getGridSquare(sx, sy + 1, sz)
                if neighbor and MFSEject.isBlockedBetweenSquares(casing.square, neighbor, IsoDirections.S, casing.z) then
                    blockY = true
                end
            elseif casing.velocityY < 0 and oldEdgeY > EDGE_TOL and edgeY <= EDGE_TOL then
                local neighbor = getCell():getGridSquare(sx, sy - 1, sz)
                if neighbor and MFSEject.isBlockedBetweenSquares(casing.square, neighbor, IsoDirections.N, casing.z) then
                    blockY = true
                end
            end

            if blockX then
                casing.velocityX = -casing.velocityX * MFSEject.BOUNCE_RESTITUTION
                casing.x = casing.x + (casing.velocityX * MFSEject.BOUNCE_POSITION_CORRECT)
                if math.abs(casing.velocityX) < MFSEject.BOUNCE_MIN_VELOCITY then
                    casing.velocityX = 0
                end
            end

            if blockY then
                casing.velocityY = -casing.velocityY * MFSEject.BOUNCE_RESTITUTION
                casing.y = casing.y + (casing.velocityY * MFSEject.BOUNCE_POSITION_CORRECT)
                if math.abs(casing.velocityY) < MFSEject.BOUNCE_MIN_VELOCITY then
                    casing.velocityY = 0
                end
            end

            if blockX or blockY then
                worldX = casing.square:getX() + casing.x
                worldY = casing.square:getY() + casing.y
            end

            local targetTileX = math.floor(worldX)
            local targetTileY = math.floor(worldY)

            local MIN_Z = -32
            local checkZ = worldZ
            local targetSquare = nil
            local drops = 0

            while checkZ >= MIN_Z do
                local sq = getCell():getGridSquare(targetTileX, targetTileY, checkZ)

                if not sq then
                    break
                end

                if sq:getFloor() then
                    targetSquare = sq
                    break
                end

                checkZ = checkZ - 1
                drops = drops + 1
            end

            if not targetSquare then
                targetSquare = casing.square
            else
                if drops > 0 then
                    casing.z = casing.z + drops
                end
            end

            local localX2 = worldX - targetSquare:getX()
            local localY2 = worldY - targetSquare:getY()

            localX2 = PZMath.clamp_01(localX2)
            localY2 = PZMath.clamp_01(localY2)

            MFSEject.removeWorldItem(casing)

            local falling = (casing.velocityZ <= 0)

            local tileTopZ = nil
            if not casing.hasHitFloor and falling then
                tileTopZ = MFSEject.getTileTopZ(targetSquare)
            end

            local surfaceZ = 0.0

            if tileTopZ then
                if prevZ >= tileTopZ and casing.z <= tileTopZ then
                    surfaceZ = tileTopZ
                end
            end

            if casing.z > surfaceZ then
                casing.currentWorldItem = targetSquare:AddWorldInventoryItem(
                    casing.casingType,
                    localX2,
                    localY2,
                    casing.z
                )
            else
                local floor = targetSquare and targetSquare:getFloor() or nil

                if surfaceZ == 0.0 then
                    casing.hasHitFloor = true
                end

                if surfaceZ == 0.0 and MFSEject.isWaterFloor(floor) then
                    MFSEject.removeWorldItem(casing)
                    casing.active = false
                    casings[i] = casings[n]
                    casings[n] = nil
                    n = n - 1
                    removed = true
                    MFSEject.playCasingImpactSound(casing, targetSquare)
                else
                    local speedXY = math.sqrt(
                        casing.velocityX * casing.velocityX +
                        casing.velocityY * casing.velocityY
                    )

                    local canBounceHere =
                        casing.floorBounces and casing.floorBounces > 0 and
                        speedXY > MFSEject.SETTLE_THRESHOLD
                    if surfaceZ == 0.0 and floor and MFSEject.isSoftFloor(floor) then
                        canBounceHere = false
                    end

                    if canBounceHere then
                        casing.floorBounces = casing.floorBounces - 1
                        casing.z            = surfaceZ + 0.05
                        casing.velocityZ    = math.abs(casing.velocityZ) * MFSEject.BOUNCE_RESTITUTION
                        casing.velocityX    = casing.velocityX * 0.5
                        casing.velocityY    = casing.velocityY * 0.5

                        MFSEject.removeWorldItem(casing)
                        casing.currentWorldItem = targetSquare:AddWorldInventoryItem(
                            casing.casingType,
                            localX2,
                            localY2,
                            casing.z
                        )
                        MFSEject.playCasingImpactSound(casing, targetSquare)
                    else
                        -- The casing has settled. Remove the transient world item
                        -- and never persist a casing item on the ground.
                        MFSEject.removeWorldItem(casing)
                        MFSEject.playCasingImpactSound(casing, targetSquare)
                        casing.active = false
                        casings[i] = casings[n]
                        casings[n] = nil
                        n = n - 1
                        removed = true
                    end
                end
            end

            if not removed then
                if targetSquare ~= casing.square then
                    casing.square = targetSquare
                end

                casing.x = PZMath.clamp_01(localX2)
                casing.y = PZMath.clamp_01(localY2)
            end
        end

        if not removed then
            i = i + 1
        end
    end
end

function MFSEject.getItemToEject(ammoType)
    return MFSEject.AMMO_TO_CASING[ammoType]
end

function MFSEject.doSpawnCasing(player, weapon, params, racking, optionalItem, ignoreDespawn)
    if not MFSEject.IsEnabled() then return end
    local forwardOffset = params and params.forwardOffset or 0.10
    local sideOffset    = params and params.sideOffset or 0.10
    local heightOffset  = params and params.heightOffset or 0.5
    local shellForce    = params and params.shellForce or 0.20
    local sideSpread    = params and params.sideSpread or 10
    local heightSpread  = params and params.heightSpread or 10
    local ejectAngle    = params and params.ejectAngle
    local verticalForce = params and params.verticalForce or 0
    local customSound   = params and params.customSound or nil
    local floorBounces  = params and params.floorBounces
    local ammoType      = weapon:getAmmoType():getItemKey()
    if not ammoType then return end

    local itemToEject = MFSEject.getItemToEject(ammoType)
    if racking then
        itemToEject = ammoType
    end
    if optionalItem then
        itemToEject = optionalItem
    end
    if not itemToEject then return end

    local px, py, pz = player:getX(), player:getY(), player:getZ()

    local angleDeg = player:getDirectionAngle() or 0
    local angleRad = math.rad(angleDeg)

    local fx = math.cos(angleRad)
    local fy = math.sin(angleRad)
    local rx = math.cos(angleRad + math.pi / 2)
    local ry = math.sin(angleRad + math.pi / 2)

    local spawnWorldX = px + fx * forwardOffset + rx * sideOffset
    local spawnWorldY = py + fy * forwardOffset + ry * sideOffset
    local targetSquare = player:getCurrentSquare()
    if not targetSquare then return end

    local startX = spawnWorldX - targetSquare:getX()
    local startY = spawnWorldY - targetSquare:getY()

    local stairFrac = pz - targetSquare:getZ()
    local startZ = stairFrac + heightOffset

    local velX = (MFSEject.RANDOM:random(sideSpread) - 5) / 200.0
    local velY = (MFSEject.RANDOM:random(sideSpread) - 5) / 200.0

    local velZ
    if type(heightSpread) == "table" then
        local minH = tonumber(heightSpread[1]) or 0
        local maxH = tonumber(heightSpread[2]) or minH
        if maxH < minH then
            minH, maxH = maxH, minH
        end
        local rawH = MFSEject.RANDOM:random(minH, maxH)
        velZ = rawH / 200.0
    else
        velZ = (MFSEject.RANDOM:random(heightSpread) + 25) / 200.0
    end

    velZ = velZ + verticalForce

    if shellForce ~= 0 then
        local dirX, dirY
        if ejectAngle ~= nil then
            local totalDeg = angleDeg + ejectAngle
            local totalRad = math.rad(totalDeg)
            dirX = math.cos(totalRad)
            dirY = math.sin(totalRad)
        else
            dirX = rx
            dirY = ry
        end

        velX = velX + dirX * shellForce
        velY = velY + dirY * shellForce
    end

    MFSEject.addCasing(
        player,
        weapon,
        targetSquare,
        itemToEject,
        startX,
        startY,
        startZ,
        velX,
        velY,
        velZ,
        customSound,
        floorBounces,
        ignoreDespawn
    )
end

function MFSEject.spawnCasing(player, weapon)
    if not player or player:isDead() then return end
    if not weapon or not weapon:isRanged() or weapon:isMelee() then return end
    if weapon:isRackAfterShoot()
        or weapon:isManuallyRemoveSpentRounds() then
        return
    end

    local params = MFSEject.WeaponEjectionPortParams[weapon:getFullType()] or
        MFSEject.DefaultEjectionPortParams[weapon:getWeaponReloadType()]

    if weapon:isRoundChambered() and not weapon:isJammed() and weapon:haveChamber() then
        MFSEject.doSpawnCasing(player, weapon, params)
    end
end

function MFSEject.rackCasing(player, weapon, racking)
    if not player or player:isDead() then return end
    if not weapon or not weapon:isRanged() or weapon:isMelee() then return end

    local params = MFSEject.WeaponEjectionPortParams[weapon:getFullType()] or
        MFSEject.DefaultEjectionPortParams[weapon:getWeaponReloadType()]

    if racking then
        MFSEject.doSpawnCasing(player, weapon, params, racking)
    end

    if not racking then
        MFSEject.doSpawnCasing(player, weapon, params, racking)
    end
end

function MFSEject.getWeaponFromArgs(player, args)
    if not player or not args then return nil end
    if args.weaponId and player:getInventory() and player:getInventory().getItemById then
        local item = player:getInventory():getItemById(args.weaponId)
        if item then return item end
    end

    return player:getPrimaryHandItem()
end

function MFSEject.onClientCommand(module, command, player, args)
    if module ~= "MFSEject" then return end
    if not player then return end

    if command == "spawnCasing" then
        local weapon = MFSEject.getWeaponFromArgs(player, args)
        if weapon then
            MFSEject.spawnCasing(player, weapon)
        end
    elseif command == "rackCasing" then
        local weapon = MFSEject.getWeaponFromArgs(player, args)
        if weapon then
            MFSEject.rackCasing(player, weapon, args and args.racking)
        end
    end
end

Events.OnClientCommand.Add(MFSEject.onClientCommand)
Events.OnTick.Add(MFSEject.update)

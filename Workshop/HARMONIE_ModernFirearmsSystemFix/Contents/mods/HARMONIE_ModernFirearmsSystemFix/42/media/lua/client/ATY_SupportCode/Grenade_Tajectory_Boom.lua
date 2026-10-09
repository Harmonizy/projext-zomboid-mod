Grenade_Tajectory = Grenade_Tajectory or {}
Grenade_Tajectory = Grenade_Tajectory or {}
MFSPerformanceSafety = MFSPerformanceSafety or {}
local previousGrenadeCheck = Grenade_Tajectory.checkontick
if type(previousGrenadeCheck) == "function" then
    Events.OnTick.Remove(previousGrenadeCheck)
end
if MFSPerformanceSafety.grenadeCheckOnTick then
    Events.OnTick.Remove(MFSPerformanceSafety.grenadeCheckOnTick)
end
if MFSPerformanceSafety.grenadeKillOnTick then
    Events.OnTick.Remove(MFSPerformanceSafety.grenadeKillOnTick)
end
Grenade_Tajectory.table = {}
Grenade_Tajectory.boomtable = {}
Grenade_Tajectory.aimcursor = nil

local sampleBomb = nil

function Grenade_Tajectory.itemremove(worlditem)
    if worlditem == nil then
        return
    end
    -- worlditem:getWorldItem():getSquare():transmitRemoveItemFromSquare(worlditem:getWorldItem())
    worlditem:getWorldItem():removeFromSquare()
end
function Grenade_Tajectory.mathfloor(number)
    return number - math.floor(number)
end
function Grenade_Tajectory.additemsfx(square, itemname, x, y, z)
    if square:getZ() > 7 then
        return
    end
    local iteminv = instanceItem(itemname)
    local itemin = IsoWorldInventoryObject.new(iteminv, square, Grenade_Tajectory.mathfloor(x),
        Grenade_Tajectory.mathfloor(y), Grenade_Tajectory.mathfloor(z));
    iteminv:setWorldItem(itemin)
    square:getWorldObjects():add(itemin)
    square:getObjects():add(itemin)
    local chunk = square:getChunk()
    if chunk then
        square:getChunk():recalcHashCodeObjects()
    else
        return
    end
    return iteminv
end
function Grenade_Tajectory.twotable(table2)
    local table1 = {}
    for i, k in pairs(table2) do
        table1[i] = table2[i]
    end
    -- print(table1)
    return table1
end
function Grenade_Tajectory.checkiswallordoor(square, angle, postion, postion2, nosfx)
    local objects = square:getObjects()
    if objects then
        for i = 1, objects:size() do
            local locobject = objects:get(i - 1)
            local sprite = locobject:getSprite()
            if sprite then
                local Properties = sprite:getProperties()
                if Properties then
                    if instanceof(locobject, "IsoWindow") and not locobject:isSmashed() then
                        if nosfx then
                            return true
                        end
                        locobject:setSmashed(true)
                        getSoundManager():PlayWorldSoundWav("SmashWindow", square, 0.5, 2, 0.5, true);
                        return true
                    end
                    local intdel = 0.25
                    if Properties:Is(IsoFlagType.WallNW) then
                        if postion[2] < square:getY() + intdel and postion[1] < square:getX() + intdel then
                            if nosfx then
                                return true
                            end
                            getSoundManager():PlayWorldSoundWav("BreakObject", square, 0.5, 2, 0.5, true);
                            return true
                        end
                    elseif Properties:Is(IsoFlagType.WallN) or
                        (Properties:Is(IsoFlagType.doorN) and not locobject:IsOpen()) then
                        if postion[2] < square:getY() + intdel then
                            if nosfx then
                                return true
                            end
                            getSoundManager():PlayWorldSoundWav("BreakObject", square, 0.5, 2, 0.5, true);
                            return true
                        end
                    elseif Properties:Is(IsoFlagType.WallW) or
                        (Properties:Is(IsoFlagType.doorW) and not locobject:IsOpen()) then
                        if postion[1] < square:getX() + intdel then
                            if nosfx then
                                return true
                            end
                            getSoundManager():PlayWorldSoundWav("BreakObject", square, 0.5, 2, 0.5, true);
                            return true
                        end
                    end
                end
            end
        end
    end
end
function Grenade_Tajectory.boomontick()
    local tablenow = Grenade_Tajectory.boomtable
    for kt, vt in pairs(tablenow) do
        -- The original loop removed the same FX object once for every entry
        -- in vt[12]. Remove the selected expired object exactly once.
        Grenade_Tajectory.itemremove(vt[12][vt[3] - vt[13]])
        if vt[3] > vt[2] + vt[13] then
            tablenow[kt] = nil
            break
        end
        if vt[3] == 1 and vt[7] == 0 then
            local itemornone = Grenade_Tajectory.additemsfx(vt[5], vt[1] .. tostring(vt[3]), vt[4][1], vt[4][2],
                vt[4][3])
            table.insert(vt[12], itemornone)
            vt[3] = vt[3] + 1
        elseif vt[7] > vt[6] and vt[3] <= vt[2] then
            vt[7] = 0
            local itemornone = Grenade_Tajectory.additemsfx(vt[5], vt[1] .. tostring(vt[3]), vt[4][1], vt[4][2],
                vt[4][3])
            table.insert(vt[12], itemornone)
            vt[3] = vt[3] + 1
        elseif vt[7] > vt[6] then
            vt[7] = 0
            vt[3] = vt[3] + 1
        end
        vt[7] = vt[7] + getGameTime():getMultiplier()

    end
end
function Grenade_Tajectory.boomsfx(sq, sfxName, sfxNum, ticktime)
    -- print(sq)
    local sfxname = sfxName or "Base.theMH_MkII_SFX"
    local sfxnum = sfxNum or 12
    local nowsfxnum = 1
    local sfxcount = 0
    local pos = {sq:getX(), sq:getY(), sq:getZ()}
    local square = sq
    local ticktime = ticktime or 3.5
    local func = function()
        return
    end
    local varz1, varz2, varz3
    local item = {}
    local offset = 3
    local tablesfx = {sfxname, ---1
    sfxnum, ---2
    nowsfxnum, ---3
    pos, ---4
    square, ---5
    ticktime, ---6
    sfxcount, ---7
    func, ---8
    varz1, ---9
    varz2, ---10
    varz3, ---11
    item, ---12
    offset ---13滞后
    }

    table.insert(Grenade_Tajectory.boomtable, tablesfx)
end
Grenade_Tajectory.damagedisplayer = {}
function Grenade_Tajectory.checkontick()
    Grenade_Tajectory.boomontick()
end
MFSPerformanceSafety.grenadeCheckOnTick = Grenade_Tajectory.checkontick
Events.OnTick.Remove(MFSPerformanceSafety.grenadeCheckOnTick)
Events.OnTick.Add(MFSPerformanceSafety.grenadeCheckOnTick)

local list = {}
local DEAD_CONFIRM_MS = 5000

local function KillReachableSquaresZombie(square, range, Damage, ExplosionSound)
    if not square then
        return
    end
    if range == nil then
        range = 1
    end
    local cx = square:getX()
    local cy = square:getY()
    local cz = square:getZ()
    local dx, dy = 0, 0
    local currentSq = square
    for dy = 0 - range, range do
        for dx = 0 - range, range do
            local square = getCell():getGridSquare(cx + dx, cy + dy, cz)
            if square ~= currentSq and currentSq and currentSq:isBlockedTo(square) then
                square = nil -- 不读取被隔开的区块
            end
            if square then
                local Zombies = square:getMovingObjects()
                for i = 0, Zombies:size() - 1 do
                    local zombie = Zombies:get(i)
                    if instanceof(zombie, "IsoZombie") then
                        local distance = math.sqrt((dx * dx) + (dy * dy))
                        local falloff = 1
                        if range and range > 0 then
                            falloff = math.abs((range - distance)) / range
                        end
                        local scaledDamage = Damage * falloff * 2
                        local newHealth = zombie:getHealth() - scaledDamage
                        if newHealth < 0 then
                            newHealth = 0
                        end
                        zombie:setHealth(newHealth)
                        if newHealth <= 0 then
                            table.insert(list, {
                                zombie = zombie,
                                deadSince = nil
                            })
                        end


                    end
                end
            end
        end
    end
    local sound = getSoundManager():PlayWorldSound(ExplosionSound, square, 0, 4, 1.0, false);
    sound:setVolume(0.7);
end


function Grenade_Tajectory.Boom(sq, GrenadeTypeInfo)
    local range = GrenadeTypeInfo and GrenadeTypeInfo.ExplosionRange or 3
    local damage = GrenadeTypeInfo and GrenadeTypeInfo.ExplosionDamage or 3

    -- 沙盒：枪榴弹伤害（0.1~3）与爆炸半径/射程（0~60）
    local sandbox = (SandboxVars and SandboxVars.MFSSandbox) or {}
    local sbRange = tonumber(sandbox.GrenadeRange)
    local sbDamage = tonumber(sandbox.GrenadeDamage)
    if sbRange ~= nil then range = sbRange end
    if sbDamage ~= nil then damage = sbDamage end

    KillReachableSquaresZombie(sq, range, damage, GrenadeTypeInfo and GrenadeTypeInfo.ExplosionSound)
    --Grenade_Tajectory.boomsfx(sq)

    -- 爆炸特效：Item_boomboom1..12 火球动画 + 闪光 + 余烟
    if GrenadeLauncherFX and GrenadeLauncherFX.spawnExplosion and sq then
        GrenadeLauncherFX.spawnExplosion(sq:getX() + 0.5, sq:getY() + 0.5, sq:getZ() + 0.15)
    end

    triggerEvent("OnThrowableExplode", nil, sq)
end

local function OnKillingZombieRagdoll()
    -- Entries were previously retained forever and scanned on every tick.
    -- Keep the original retry behavior during a bounded confirmation window.
    -- This allows delayed server ownership correction to revive a zombie and
    -- trigger another Kill call, without retaining every zombie forever.
    for i = #list, 1, -1 do
        local entry = list[i]
        local v = entry and entry.zombie or nil
        if v then
            if v:getModData()["RagdollTimer"] == nil then
                v:getModData()["RagdollTimer"] = 0
            else
                v:getModData()["RagdollTimer"] =
                    v:getModData()["RagdollTimer"] + getGameTime():getTimeDelta()
            end

            --v:setSitAgainstWall(true)
            --v:setVariable("bMoving", false)
            --v:setMoving(false)

            if not v:isDead() then
                entry.deadSince = nil
                --v:setRagdoll(true)
                --if v:isSitAgainstWall() and not v:getVariableBoolean("bMoving", true) and v:getVariableBoolean("issitting", true) then
                v:Kill(getPlayer())
                --elseif v:getModData()["RagdollTimer"] > 3 then
                --v:becomeCorpse()
            end
            if v:isDead() then
                entry.deadSince = entry.deadSince or getTimestampMs()
            end
        end
        if not v or (entry.deadSince and getTimestampMs() - entry.deadSince >= DEAD_CONFIRM_MS) then
            table.remove(list, i)
        end
    end
end

MFSPerformanceSafety.grenadeKillOnTick = OnKillingZombieRagdoll
Events.OnTick.Remove(MFSPerformanceSafety.grenadeKillOnTick)
Events.OnTick.Add(MFSPerformanceSafety.grenadeKillOnTick)
MFSPerformanceSafety.grenadeOverride = "1.3.1"

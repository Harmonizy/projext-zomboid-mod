--[[
    HARMONIE - Life With Style : pets (server; single player too)

    Owner, 2026-10-23: "เราจะต้องให้สัตว์เลี้ยงมาเดินตามผู้เล่นเจ้าของ อาจจะมีการให้
    อาหาร หรือสั่งทำสิ่งต่างๆได้ แต่ไม่อยากให้โจมตีได้ อาจจะเปิดปิดได้ใน sandbox".

    A pet is a wardrobe piece of the "pet" slot (LWS.PIECE[id].pet, made by
    tools/gen_lws.py; the dogs are Companion Dogs' art, used with its author's
    permission). Wearing it = the pet is out: the server makes one animal of
    our own type (lwspet_<breed>, shared/Definitions/animal/LWS_PetDefinitions.lua)
    next to the owner. The animal is only a picture of the wardrobe entry:
      * it never attacks (attackBack = false, no combat code at all) and can
        not be hurt (invincible, health kept full), picked up or butchered;
      * it goes away when the owner takes it off, dies, leaves, or the
        sandbox switches pets off -- and comes back when the owner does;
      * a copy left in a saved chunk (a crash, a server stop) is deleted when
        it loads: every lwspet_ animal that is not the out pet of an online
        owner goes (P.sweep).

    Pet data in the owner's wardrobe record: o.pets[uid] = { hunger = 0..1,
    hourAt = last world hour counted, mode = "follow" | "stay", warnedAt }.

    Commands (LWS.Server.handle forwards "Pet*"):
      PetMode { mode }   PetCome   PetSpeak   PetFeed { type? }
    Replies: PetState (owner), PetSound { id, s } and PetGone { id } (everyone).

    Sandbox (page HARMONIE_LifeWithStyle): LifeWithStyle.PetsEnabled,
    PetCommands, PetFeeding, PetHunger, PetHungerHours, PetSounds,
    PetTeleportDistance.
]]--

require "HARMONIELifeWithStyle/LWS_Core"

LWS.Pets = LWS.Pets or {}
local P = LWS.Pets
local log = function(...) LWS.log("Pets", ...) end

P.active = P.active or {}       -- [owner key] = { animal, id, uid, piece, pathAt, ox, oy, respawnAt }
P.TICK_MS = 500
P.SWEEP_MS = 10000
P.FOLLOW_NEAR = 2.5             -- (old; see P.REST_NEAR / P.FOLLOW_FROM)
P.REPATH_MS = 2500              -- a new path at most this often (A* is not free)
P.RESPAWN_MS = 3000             -- a lost pet is made again at most this often
P.STAY_LEASH = 2                -- a staying pet farther than teleport x this comes back
P.RUN_FROM = 6                  -- runs when farther than this (or when the owner runs) ...
P.WALK_UNDER = 3.5              -- ... and walks again under this
P.REST_AFTER_MS = 20000         -- a staying pet lies down after this
P.IDLE_MIN_MS, P.IDLE_MAX_MS = 12000, 25000   -- a standing pet does something now and then

-- ------------------------------------------------------------- sandbox
local DEFAULTS = {
    PetsEnabled = true, PetCommands = true, PetFeeding = true, PetHunger = true,
    PetHungerHours = 72, PetSounds = true, PetTeleportDistance = 25,
}
function P.sv(name)
    local sv = SandboxVars and SandboxVars.LifeWithStyle
    local v = sv and sv[name]
    if v == nil then return DEFAULTS[name] end
    return v
end

local function isMP() return (isServer and isServer()) or (isClient and isClient()) end
local function now() return getTimestampMs and getTimestampMs() or 0 end
local function hour()
    local gt = getGameTime and getGameTime()
    return gt and gt:getWorldAgeHours() or 0
end

-- ------------------------------------------------------------- data
function P.data(o, uid)
    o.pets = o.pets or {}
    local d = o.pets[uid]
    if not d then
        d = { hunger = 1, hourAt = hour(), mode = "follow" }
        o.pets[uid] = d
    end
    d.hunger = tonumber(d.hunger) or 1
    d.mode = d.mode == "stay" and "stay" or "follow"
    return d
end

-- the pet the owner has out (wardrobe), or nil
function P.wanted(player)
    if not P.sv("PetsEnabled") then return nil end
    local key = LWS.ownerKey(player)
    local o = key and LWS.Server and LWS.Server.owner(key, false)
    local uid = o and o.worn and o.worn.pet
    local e = uid and o.items[uid]
    local c = e and LWS.PIECE[e.p]
    if not c or not c.pet then return nil end
    return { key = key, o = o, uid = uid, piece = e.p, pet = c.pet }
end

local function valid(animal)
    if not animal then return false end
    local ok, v = pcall(function() return animal:isExistInTheWorld() and not animal:isDead() end)
    return ok and v == true
end

local function idOf(animal)
    local ok, id = pcall(function() return animal:getOnlineID() end)
    return ok and id or nil
end

-- ------------------------------------------------------------- sounds
-- the pet's own emitter, on every client (no world sound: zombies never hear a pet)
function P.sound(animal, name)
    if not P.sv("PetSounds") or not animal then return end
    if isServer and isServer() then
        local id = idOf(animal)
        if id then sendServerCommand(LWS.NET, "PetSound", { id = id, s = name }) end
    else
        pcall(function() animal:getEmitter():playSoundImpl(name, nil) end)
    end
end

-- the pet's own voice for this moment (a dog barks, a cat meows -- LWS.PET_VOICE)
function P.voice(rec, what)
    local v = LWS.PET_VOICE[rec.kind or "dog"] or LWS.PET_VOICE.dog
    P.sound(rec.animal, v[what])
end

-- ------------------------------------------------------------- spawn / despawn
local function makeAt(x, y, z, want)
    local def = AnimalDefinitions and AnimalDefinitions.getDef and AnimalDefinitions.getDef(want.pet.type)
    if not def then LWS.logOnce("nodef:" .. want.pet.type, "Pets", "no animal definition %s -- the pet can NOT come out", want.pet.type); return nil end
    local breed = def:getBreedByName(want.pet.breed) or def:getRandomBreed()
    local cell = getCell()
    local sq = cell and cell:getGridSquare(x, y, z)
    if not sq or sq:isWaterSquare() then return nil end
    local a = addAnimal(cell, x, y, z, want.pet.type, breed, false)
    if not a then return nil end
    -- the engine can hand back a half-made animal (Companion Dogs' note): check before use
    if not (a:getSquare() and a:getAnimalType() and a:getData()) then
        pcall(function() a:removeFromWorld(); a:delete() end)
        return nil
    end
    return a
end

function P.spawn(player, want, why)
    local sq = player:getCurrentSquare()
    if not sq then return nil end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local a
    for _, d in ipairs({ { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 }, { 0, 0 } }) do
        local ok, made = pcall(makeAt, x + d[1], y + d[2], z, want)
        if not ok then LWS.logOnce("spawnerr", "Pets", "making the pet FAILED: %s", tostring(made)) end
        a = ok and made or nil
        if a then break end
    end
    if not a then
        log("%s: %s could not come out at %d,%d,%d (no dry square)", LWS.name(player), want.piece, x, y, z)
        return nil
    end
    pcall(function() a:setWild(false) end)
    pcall(function() a:addToWorld() end)
    pcall(function() a:setCustomName(LWS.pieceName(want.piece)) end)
    LWS.petBaseVars(a)
    pcall(function()
        local md = a:getModData()
        md.LWS_pet = { owner = want.key, uid = want.uid }
    end)
    local rec = { animal = a, id = idOf(a), uid = want.uid, piece = want.piece, pathAt = 0, kind = want.pet.kind or "dog" }
    P.active[want.key] = rec
    log("%s: %s came out (%s, animal id %s)", LWS.name(player), want.piece, tostring(why), tostring(rec.id))
    return rec
end

local function deleteAnimal(animal)
    local id = idOf(animal)
    pcall(function() animal:delete() end)
    -- the engine tells the clients once, unreliably: say it again (reliable)
    if id and isServer and isServer() then sendServerCommand(LWS.NET, "PetGone", { id = id }) end
end

function P.despawn(key, why)
    local rec = P.active[key]
    if not rec then return end
    P.active[key] = nil
    if valid(rec.animal) then deleteAnimal(rec.animal) end
    log("%s: %s went back to the wardrobe (%s)", tostring(key), tostring(rec.piece), tostring(why))
end

-- ------------------------------------------------------------- animation
-- a short animation (ms) or one that stays until turned off (ms = nil): set
-- here and on every client (an animation variable does not travel by itself)
function P.anim(rec, var, on, ms)
    if not rec or not valid(rec.animal) then return end
    rec.anims = rec.anims or {}
    if rec.anims[var] and rec.anims[var].on == on then return end
    pcall(function() rec.animal:setVariable(var, on) end)
    rec.anims[var] = on and { on = true, untilMs = ms and (now() + ms) or nil } or nil
    if isServer and isServer() and rec.id then
        sendServerCommand(LWS.NET, "PetAnim", { id = rec.id, v = var, on = on, ms = ms })
    end
end

-- turn off the short ones that are over; everything off when it moves
function P.animTick(rec, moving)
    local t = now()
    for var, a in pairs(rec.anims or {}) do
        if moving or (a.untilMs and t >= a.untilMs) then P.anim(rec, var, false) end
    end
end

-- a cat sits down (the sit-down clip, then the sitting loop) and grooms now and then
P.SIT_AFTER_MS = 5000
function P.catSit(rec)
    if rec.anims and (rec.anims.lwsSit or rec.anims.lwsRest) then return end
    P.anim(rec, "lwsSitIn", true, 1200)
    P.anim(rec, "lwsSit", true)
    log("%s sits down", tostring(rec.piece))
end

function P.catIdleTick(rec, d)
    local t = now()
    local sitting = rec.anims and rec.anims.lwsSit
    if d.mode == "stay" then
        rec.stillSince = rec.stillSince or t
        local still = t - rec.stillSince
        if still >= P.REST_AFTER_MS * 2 and not (rec.anims and rec.anims.lwsRest) then
            P.anim(rec, "lwsSit", false)
            P.anim(rec, "lwsRest", true)
            log("%s curls up", tostring(rec.piece))
            return
        elseif still >= P.SIT_AFTER_MS and not sitting and not (rec.anims and rec.anims.lwsRest) then
            P.catSit(rec)
            return
        end
        if rec.anims and rec.anims.lwsRest then return end
    end
    if not rec.idleAt then rec.idleAt = t + ZombRand(P.IDLE_MIN_MS, P.IDLE_MAX_MS) end
    if t < rec.idleAt then return end
    rec.idleAt = t + ZombRand(P.IDLE_MIN_MS, P.IDLE_MAX_MS)
    if sitting then
        local g = LWS.CAT_GROOM_VARS[ZombRand(1, #LWS.CAT_GROOM_VARS + 1)]
        if not (rec.anims.lwsSitGroom or rec.anims.lwsSitGroom2) then P.anim(rec, g, true, 3500) end
        return
    end
    for _ in pairs(rec.anims or {}) do return end
    -- standing by the owner: sit down, or one of the idle variations
    if ZombRand(0, 3) == 0 then P.catSit(rec) return end
    local var = LWS.PET_IDLE_VARS[ZombRand(1, #LWS.PET_IDLE_VARS + 1)]
    P.anim(rec, var, true, var == "lwsSniff" and 4000 or 3000)
end

function P.idleTick(rec, d)
    if rec.kind == "cat" then return P.catIdleTick(rec, d) end
    local t = now()
    if d.mode == "stay" then
        rec.stillSince = rec.stillSince or t
        if t - rec.stillSince >= P.REST_AFTER_MS and not (rec.anims and rec.anims.lwsRest) then
            P.anim(rec, "lwsRest", true)
            log("%s lies down", tostring(rec.piece))
        end
        if rec.anims and rec.anims.lwsRest then return end
    end
    if not rec.idleAt then rec.idleAt = t + ZombRand(P.IDLE_MIN_MS, P.IDLE_MAX_MS) end
    if t >= rec.idleAt then
        rec.idleAt = t + ZombRand(P.IDLE_MIN_MS, P.IDLE_MAX_MS)
        local busy = false
        for _ in pairs(rec.anims or {}) do busy = true end
        if not busy then
            local var = LWS.PET_IDLE_VARS[ZombRand(1, #LWS.PET_IDLE_VARS + 1)]
            P.anim(rec, var, true, var == "lwsSniff" and 4000 or 3000)
        end
    end
end

-- walk or run (with a gap so it does not flip at one distance)
local function setGait(rec, owner, dd)
    local ownerRuns = false
    pcall(function() ownerRuns = owner:isRunning() or owner:isSprinting() end)
    local run = rec.run == true
    if dd > P.RUN_FROM or ownerRuns then run = true elseif dd < P.WALK_UNDER then run = false end
    if run ~= rec.run then rec.run = run end
    pcall(function()
        rec.animal:setVariable("animalRunning", run)
        rec.animal:setVariable("animalSpeed", run and LWS.PET_RUN_SPEED or LWS.PET_WALK_SPEED)
    end)
end

-- ------------------------------------------------------------- state
function P.stateFor(player)
    local want = P.wanted(player)
    local rec = want and P.active[want.key]
    local st = {
        enabled = P.sv("PetsEnabled") == true, commands = P.sv("PetCommands") == true,
        feeding = P.sv("PetFeeding") == true, hungerOn = P.sv("PetHunger") == true,
    }
    if want then
        local d = P.data(want.o, want.uid)
        st.piece, st.uid, st.mode, st.hunger = want.piece, want.uid, d.mode, d.hunger
        st.out = rec ~= nil and valid(rec.animal)
        st.id = rec and rec.id or nil
    end
    return st
end

function P.sendState(player)
    LWS.toClient(player, "PetState", P.stateFor(player))
end

-- the pet out = the wardrobe (called from LWS.Server.ensure and the commands)
function P.sync(player, why)
    if not player or (player.isDead and player:isDead()) then return end
    local key = LWS.ownerKey(player)
    if not key then return end
    local want = P.wanted(player)
    local rec = P.active[key]
    local changed = false
    if rec and (not want or want.uid ~= rec.uid) then
        P.despawn(key, want and "another pet" or (P.sv("PetsEnabled") and "taken off" or "pets are off in sandbox"))
        rec, changed = nil, true
        -- the owner chose: the new pet comes now (the wait is only for a lost one)
        if P.respawnAt then P.respawnAt[key] = nil end
    end
    if want and not rec then
        local t = now()
        P.respawnAt = P.respawnAt or {}
        if not P.respawnAt[key] or t >= P.respawnAt[key] then
            P.respawnAt[key] = t + P.RESPAWN_MS
            if P.spawn(player, want, why) then changed = true end
        end
    end
    if changed or why ~= "sweep" then P.sendState(player) end
end

-- ------------------------------------------------------------- hunger
function P.hungerTick(player, rec, o)
    local d = P.data(o, rec.uid)
    local h = hour()
    local dt = h - (tonumber(d.hourAt) or h)
    d.hourAt = h
    if not P.sv("PetHunger") or dt <= 0 then return d end
    local hours = math.max(1, tonumber(P.sv("PetHungerHours")) or 72)
    local before = d.hunger
    d.hunger = math.max(0, d.hunger - dt / hours)
    -- the owner hears about it at 25 % and when it reaches 0 (once each, until fed)
    if before >= 0.25 and d.hunger < 0.25 then
        log("%s: %s is hungry (%.0f%%)", LWS.name(player), rec.piece, d.hunger * 100)
        LWS.toClient(player, "Msg", { key = "IGUI_LWS_Msg_PetHungry", arg = LWS.pieceName(rec.piece), text = true })
        P.voice(rec, "hungry")
        P.sendState(player)
    elseif before > 0 and d.hunger <= 0 then
        log("%s: %s is starving -- it will not take orders until fed", LWS.name(player), rec.piece)
        LWS.toClient(player, "Msg", { key = "IGUI_LWS_Msg_PetStarving", arg = LWS.pieceName(rec.piece), text = true })
        P.voice(rec, "hungry")
        P.sendState(player)
    end
    return d
end

-- ------------------------------------------------------------- following
local function dist(a, b)
    local dx, dy = a:getX() - b:getX(), a:getY() - b:getY()
    return math.sqrt(dx * dx + dy * dy)
end

local function pathTo(animal, owner)
    pcall(function()
        local b = animal:getBehavior()
        if b then b:setBlockMovement(false) end
    end)
    animal:pathToCharacter(owner)
    pcall(function() animal:setVariable("bPathfind", true) end)
end

-- 0.7.7: waiting by the owner / following (see P.step)
P.REST_NEAR = 2.5          -- a follower this close stops and waits
P.FOLLOW_FROM = 5          -- a waiting pet follows when the owner is farther than this
P.STUCK_MS = 2000          -- a follower is checked for progress this often ...
P.STUCK_MOVE = 0.35        -- ... and is stuck when it moved less than this (tiles)
P.STUCK_TRIES = 3          -- stuck this many checks in a row (and not close): brought over
P.WAITING = { mode = "stay" }   -- a waiting pet idles like a staying one (sits, lies down)

function P.stop(rec)
    local a = rec.animal
    pcall(function() a:stopAllMovementNow() end)
    pcall(function() a:setVariable("bPathfind", false) end)
    pcall(function() a:setVariable("animalRunning", false) end)
    pcall(function() local b = a:getBehavior(); if b then b:setBlockMovement(true) end end)
    rec.run = false
end
function P.unblock(rec)
    pcall(function() local b = rec.animal:getBehavior(); if b then b:setBlockMovement(false) end end)
end
function P.startFollow(rec)
    local a = rec.animal
    rec.following = true
    rec.waitFrom = nil
    rec.stillSince, rec.idleAt = nil, nil
    rec.progX, rec.progY, rec.progAt, rec.stuck = a:getX(), a:getY(), now(), 0
    P.unblock(rec)
end
function P.arrive(rec, owner, dd, why)
    rec.following = false
    rec.stuck = 0
    -- it stopped farther out than usual (stuck): it follows again only when
    -- the owner gets 2 tiles farther than that, never at once
    rec.waitFrom = math.max(P.FOLLOW_FROM, dd + 2)
    rec.waitX, rec.waitY = rec.animal:getX(), rec.animal:getY()
    rec.stillSince, rec.idleAt = now(), nil
    P.stop(rec)
    log("%s: %s waits by its owner (%.1f tiles, %s)", LWS.name(owner), rec.piece, dd, why)
end

function P.step(key, rec, owner)
    local animal = rec.animal
    -- nothing hurts it (zombies, players, falls, shots): health stays full,
    -- and a gunshot or a zombie does not scare it off (owner, 2026-10-24)
    pcall(function() if animal:getHealth() < 1 then animal:setHealth(1) end end)
    LWS.petCalm(animal)
    rec.protectAt = rec.protectAt or 0
    if now() - rec.protectAt > 2000 then rec.protectAt = now(); LWS.petProtect(animal) end
    local o = LWS.Server.owner(key, false)
    if not o then return end
    local d = P.hungerTick(owner, rec, o)
    local far = math.max(6, tonumber(P.sv("PetTeleportDistance")) or 25)
    local dd = dist(animal, owner)
    local dz = math.abs(math.floor(animal:getZ()) - math.floor(owner:getZ()))
    if d.mode == "stay" then
        P.animTick(rec, false)
        P.idleTick(rec, d)
        -- it ran from where it was told to stay (a shot, a zombie): stop it there
        if not rec.stayX then rec.stayX, rec.stayY = animal:getX(), animal:getY() end
        local sx, sy = animal:getX() - rec.stayX, animal:getY() - rec.stayY
        if sx * sx + sy * sy > 4 then
            LWS.logOnce("petfled:" .. key .. ":" .. tostring(rec.stayX), "Pets", "%s: %s moved off its stay spot -- stopped there", LWS.name(owner), rec.piece)
            pcall(function() animal:stopAllMovementNow() end)
            pcall(function() local b = animal:getBehavior(); if b then b:setBlockMovement(true) end end)
            rec.stayX, rec.stayY = animal:getX(), animal:getY()
        end
        if dd > far * P.STAY_LEASH then
            d.mode = "follow"
            log("%s: %s was left too far away (%.0f tiles) -- it comes back and follows", LWS.name(owner), rec.piece, dd)
            P.despawn(key, "left too far")
            P.sync(owner, "came back")
            LWS.toClient(owner, "Msg", { key = "IGUI_LWS_Msg_PetCameBack", arg = LWS.pieceName(rec.piece), text = true })
        end
        return
    end
    -- too far, or another floor: it comes to the owner (a new animal beside them)
    if dd > far or (dz > 0 and dd > 4) then
        log("%s: %s is %.0f tiles away%s -- brought to the owner", LWS.name(owner), rec.piece, dd, dz > 0 and " on another floor" or "")
        P.despawn(key, "teleport")
        P.respawnAt = P.respawnAt or {}
        P.respawnAt[key] = nil
        P.sync(owner, "teleport")
        return
    end
    rec.stayX, rec.stayY = nil, nil
    -- being petted: it stays where it is a moment
    if rec.holdUntil and now() < rec.holdUntil then return end
    local t = now()
    -- 0.7.7 (owner, 2026-10-25: "ไม่ต้องพยายามให้สัตว์เลี้ยงเดินตลอดเวลา ตอนนี้มันติดที่
    -- อนิเมชั่นเดินหรือวิ่งอยู่กับที่บ่อยมาก ... นั่ง หรือทำอนิเมชั่นอื่นรอ จนกว่าผู้เล่นจะ
    -- ออกจากระยะแล้วค่อยเดินตาม"): two states with a gap between them --
    -- WAITING by the owner (stopped, no path, sits / lies down / idles like a
    -- staying pet) until the owner is farther than FOLLOW_FROM, then
    -- FOLLOWING (paths) until it is within REST_NEAR again. A follower that
    -- does not get anywhere (walking on the spot) waits instead when it is
    -- close, and is brought to the owner when it is not.
    if not rec.following then
        if dd > (rec.waitFrom or P.FOLLOW_FROM) then
            P.startFollow(rec)
            log("%s: %s follows (owner %.1f tiles away)", LWS.name(owner), rec.piece, dd)
        else
            -- it moved off its waiting spot by itself (scared, pushed): stop it there
            if not rec.waitX then rec.waitX, rec.waitY = animal:getX(), animal:getY() end
            local wx, wy = animal:getX() - rec.waitX, animal:getY() - rec.waitY
            if wx * wx + wy * wy > 2.25 then
                LWS.logOnce("petdrift:" .. key .. ":" .. tostring(math.floor(t / 60000)), "Pets", "%s: %s wandered off while waiting -- stopped", LWS.name(owner), rec.piece)
                P.stop(rec)
                rec.waitX, rec.waitY = animal:getX(), animal:getY()
            end
            P.animTick(rec, false)
            P.idleTick(rec, P.WAITING)
            return
        end
    end
    -- following
    if dd <= P.REST_NEAR then
        P.arrive(rec, owner, dd, "reached the owner")
        return
    end
    -- getting anywhere? (checked every STUCK_MS)
    if t - (rec.progAt or t) >= P.STUCK_MS then
        local mx, my = animal:getX() - (rec.progX or animal:getX()), animal:getY() - (rec.progY or animal:getY())
        if mx * mx + my * my < P.STUCK_MOVE * P.STUCK_MOVE then
            rec.stuck = (rec.stuck or 0) + 1
            if dd <= P.FOLLOW_FROM + 1 then
                P.arrive(rec, owner, dd, "stuck close by")
                return
            end
            if rec.stuck >= P.STUCK_TRIES then
                log("%s: %s is stuck %.0f tiles away (%d checks) -- brought to the owner", LWS.name(owner), rec.piece, dd, rec.stuck)
                P.despawn(key, "stuck")
                P.respawnAt = P.respawnAt or {}
                P.respawnAt[key] = nil
                P.sync(owner, "stuck")
                return
            end
            rec.pathAt = 0
        else
            rec.stuck = 0
        end
        rec.progX, rec.progY, rec.progAt = animal:getX(), animal:getY(), t
    end
    LWS.petCalm(animal)
    P.animTick(rec, true)
    rec.idleAt = nil
    setGait(rec, owner, dd)
    local moved = not rec.ox or math.abs(owner:getX() - rec.ox) + math.abs(owner:getY() - rec.oy) > 1.5
    if t - (rec.pathAt or 0) >= P.REPATH_MS or (moved and t - (rec.pathAt or 0) >= 800) then
        rec.pathAt, rec.ox, rec.oy = t, owner:getX(), owner:getY()
        local ok, err = pcall(pathTo, animal, owner)
        if not ok then LWS.logOnce("patherr", "Pets", "path to the owner FAILED: %s", tostring(err)) end
    end
end

-- ------------------------------------------------------------- commands
local function petOf(player)
    local key = LWS.ownerKey(player)
    local rec = key and P.active[key]
    if not rec or not valid(rec.animal) then
        LWS.toClient(player, "Msg", { key = "IGUI_LWS_Msg_PetNotOut" })
        return nil
    end
    local o = LWS.Server.owner(key, false)
    return rec, o and P.data(o, rec.uid), key
end

-- the best food the player carries: dog food first, then the most filling (LWS.petFoodValue)
local foodValue = function(item) return LWS.petFoodValue(item) end

function P.findFood(player, wantType)
    local inv = player:getInventory()
    local items = inv:getItems()
    local best, bestV
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if not wantType or LWS.typeOf(it) == wantType then
            local v = foodValue(it)
            if v > 0 and (not bestV or v > bestV) then best, bestV = it, v end
        end
    end
    return best, bestV
end

-- a pet by its animal id (anyone may pet anyone's pet)
local function recById(id)
    for key, rec in pairs(P.active) do
        if rec.id ~= nil and rec.id == id and valid(rec.animal) then return rec, key end
    end
    -- single player: the ids may all be the same -- the one pet there is
    if not isMP() then for key, rec in pairs(P.active) do if valid(rec.animal) then return rec, key end end end
    return nil
end

P.PET_HOLD_MS = 6000
function P.handle(player, command, args)
    if command == "PetPet" then
        local rec = recById(tonumber(args.id))
        if not rec then log("REJECTED PetPet from %s: no such pet out (%s)", LWS.name(player), tostring(args.id)); return end
        -- it stays still to be stroked, and is happy about it
        rec.holdUntil = now() + P.PET_HOLD_MS
        pcall(function() rec.animal:stopAllMovementNow() end)
        pcall(function() rec.animal:faceThisObject(player) end)
        P.voice(rec, "happy")
        log("%s pets %s", LWS.name(player), tostring(rec.piece))
        return
    elseif command == "PetFeed" then
        if not P.sv("PetFeeding") then log("REJECTED PetFeed from %s: feeding is off in sandbox", LWS.name(player)); return end
        local rec, d = petOf(player)
        if not rec or not d then return end
        local item, v = P.findFood(player, args.type and tostring(args.type) or nil)
        if not item then
            log("%s: no food the pet can eat%s", LWS.name(player), args.type and (" (" .. tostring(args.type) .. ")") or "")
            LWS.toClient(player, "Msg", { key = "IGUI_LWS_Msg_PetNoFood" })
            return
        end
        local t = LWS.typeOf(item)
        local inv = player:getInventory()
        pcall(function() inv:Remove(item) end)
        if isServer and isServer() and sendRemoveItemFromContainer then pcall(sendRemoveItemFromContainer, inv, item) end
        local before = d.hunger
        d.hunger = math.min(1, d.hunger + v)
        d.hourAt = hour()
        log("%s fed %s with %s: %.0f%% -> %.0f%%", LWS.name(player), rec.piece, t, before * 100, d.hunger * 100)
        P.voice(rec, "eat")
        P.anim(rec, "lwsEat", true, 4000)
        LWS.toClient(player, "Msg", { key = "IGUI_LWS_Msg_PetFed", arg = LWS.pieceName(rec.piece), text = true })
        P.sendState(player)
    elseif command == "PetMode" or command == "PetCome" or command == "PetSpeak" then
        if not P.sv("PetCommands") then log("REJECTED %s from %s: commands are off in sandbox", command, LWS.name(player)); return end
        local rec, d = petOf(player)
        if not rec or not d then return end
        -- a starving pet only follows (feeding it brings the tricks back)
        if P.sv("PetHunger") and d.hunger <= 0 and command ~= "PetCome" then
            log("%s: %s is starving and ignores %s", LWS.name(player), rec.piece, command)
            P.voice(rec, "hungry")
            LWS.toClient(player, "Msg", { key = "IGUI_LWS_Msg_PetStarving", arg = LWS.pieceName(rec.piece), text = true })
            return
        end
        if command == "PetMode" then
            d.mode = args.mode == "stay" and "stay" or "follow"
            if d.mode == "stay" then
                rec.stillSince = now()
                pcall(function() rec.animal:stopAllMovementNow() end)
                pcall(function() local b = rec.animal:getBehavior(); if b then b:setBlockMovement(true) end end)
            else
                rec.pathAt = 0
                P.startFollow(rec)
                pcall(pathTo, rec.animal, player)
            end
            log("%s: %s -> %s", LWS.name(player), rec.piece, d.mode)
        elseif command == "PetCome" then
            d.mode = "follow"
            rec.pathAt = now()
            P.startFollow(rec)   -- comes over even when the owner is close
            local ok, err = pcall(pathTo, rec.animal, player)
            log("%s calls %s%s", LWS.name(player), rec.piece, ok and "" or (" -- path FAILED: " .. tostring(err)))
        else
            P.voice(rec, "speak")
            log("%s: %s barks", LWS.name(player), rec.piece)
        end
        P.sendState(player)
    else
        log("REJECTED unknown pet command %s from %s", tostring(command), LWS.name(player))
    end
end

-- ------------------------------------------------------------- the loops
local function isPetType(animal)
    return LWS.isPetAnimal(animal)
end

-- every lwspet_ animal that is not an out pet goes (a saved copy, a lost one)
function P.sweep()
    local cell = getCell and getCell()
    local list = cell and cell:getAnimals()
    if not list then return end
    -- compared object by object: in single player the online ids may all be the same
    local mine = {}
    for _, rec in pairs(P.active) do mine[#mine + 1] = rec.animal end
    local stray = {}
    for i = 0, list:size() - 1 do
        local a = list:get(i)
        if a and isPetType(a) then
            local out = false
            for _, m in ipairs(mine) do if m == a then out = true end end
            if not out then stray[#stray + 1] = a end
        end
    end
    for _, a in ipairs(stray) do
        local md
        pcall(function() md = a:getModData().LWS_pet end)
        log("removed a stray pet copy (%s, animal id %s, owner %s)", tostring(a:getAnimalType()), tostring(idOf(a)), md and tostring(md.owner) or "?")
        deleteAnimal(a)
    end
end

-- a pet must never sit in an inventory (vanilla's pick-up, or any other way in):
-- the item goes, the pet comes back out beside its owner
function P.cleanInventory(player)
    local inv = player and player:getInventory()
    if not inv then return 0 end
    local items, gone = inv:getItems(), {}
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local okA, isAnimal = pcall(function() return instanceof(it, "AnimalInventoryItem") end)
        if okA and isAnimal then
            local a
            pcall(function() a = it:getAnimal() end)
            if a and LWS.isPetAnimal(a) then gone[#gone + 1] = it end
        end
    end
    for _, it in ipairs(gone) do
        pcall(function() inv:Remove(it) end)
        if isServer and isServer() and sendRemoveItemFromContainer then pcall(sendRemoveItemFromContainer, inv, it) end
        log("%s: a pet was in the inventory -- removed (it walks beside its owner instead)", LWS.name(player))
    end
    return #gone
end

local function ownerOnline(key)
    return LWS.Server and LWS.Server.onlineByKey and LWS.Server.onlineByKey(key) or nil
end

local nextTick, nextSweep = 0, 0
function P.onTick()
    if isClient and isClient() then return end
    local t = now()
    if t < nextTick then return end
    nextTick = t + P.TICK_MS
    local keys = {}
    for key in pairs(P.active) do keys[#keys + 1] = key end
    for _, key in ipairs(keys) do
        local rec = P.active[key]
        local owner = ownerOnline(key)
        if not owner or (owner.isDead and owner:isDead()) then
            P.despawn(key, owner and "owner died" or "owner left")
        elseif not P.sv("PetsEnabled") then
            P.despawn(key, "pets are off in sandbox")
            P.sendState(owner)
        elseif not valid(rec.animal) then
            P.active[key] = nil
            log("%s: %s was lost (unloaded or removed) -- it comes back", LWS.name(owner), tostring(rec.piece))
            P.sync(owner, "lost")
        else
            local ok, err = pcall(P.step, key, rec, owner)
            if not ok then LWS.logOnce("steperr:" .. key, "Pets", "%s: pet step FAILED: %s", tostring(key), tostring(err)) end
        end
    end
    if t >= nextSweep then
        nextSweep = t + P.SWEEP_MS
        local online = (isServer and isServer()) and getOnlinePlayers and getOnlinePlayers()
        if online then
            for i = 0, online:size() - 1 do pcall(P.cleanInventory, online:get(i)) end
        elseif getPlayer and getPlayer() then
            pcall(P.cleanInventory, getPlayer())
        end
        local ok, err = pcall(P.sweep)
        if not ok then LWS.logOnce("sweeperr", "Pets", "stray pet sweep FAILED: %s", tostring(err)) end
    end
end

local function onDeath(player)
    if not player or (isClient and isClient()) then return end
    local key = LWS.ownerKey(player)
    if key and P.active[key] then P.despawn(key, "owner died") end
end

if Events and not P.registered then
    P.registered = true
    if Events.OnTick then Events.OnTick.Add(P.onTick) end
    if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(onDeath) end
    -- a hit on a pet (a shot, a swing): health back at once, logged
    if Events.OnWeaponHitCharacter then
        Events.OnWeaponHitCharacter.Add(function(attacker, target, weapon, damage)
            -- fires for every hit (zombies, players): animals only (0.7.6)
            if not LWS.isPetAnimal(target) then return end
            pcall(function() target:setHealth(1) end)
            LWS.petProtect(target)
            LWS.petCalm(target)
            LWS.logOnce("pethit:" .. LWS.name(attacker) .. ":" .. tostring(math.floor((getTimestampMs and getTimestampMs() or 0) / 60000)),
                "Pets", "a pet was hit by %s (%s) -- no harm done", LWS.name(attacker), tostring(damage))
        end)
    end
    if Events.OnGameStart then
        Events.OnGameStart.Add(function()
            log("pets: %s, commands %s, feeding %s, hunger %s (%s h), sounds %s, bring-back distance %s",
                tostring(P.sv("PetsEnabled")), tostring(P.sv("PetCommands")), tostring(P.sv("PetFeeding")),
                tostring(P.sv("PetHunger")), tostring(P.sv("PetHungerHours")), tostring(P.sv("PetSounds")), tostring(P.sv("PetTeleportDistance")))
        end)
    end
    if Events.OnServerStarted then
        Events.OnServerStarted.Add(function() log("server started: pets come out when their owners join") end)
    end
end

return P

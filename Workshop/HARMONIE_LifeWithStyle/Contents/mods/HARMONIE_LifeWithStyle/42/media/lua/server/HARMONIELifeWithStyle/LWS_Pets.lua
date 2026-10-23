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
P.FOLLOW_NEAR = 2.5             -- closer than this: no new path
P.REPATH_MS = 2500              -- a new path at most this often (A* is not free)
P.RESPAWN_MS = 3000             -- a lost pet is made again at most this often
P.STAY_LEASH = 2                -- a staying pet farther than teleport x this comes back

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
    pcall(function() a:setIsInvincible(true) end)
    pcall(function() a:setInvulnerable(true) end)
    pcall(function() a:setCustomName(LWS.pieceName(want.piece)) end)
    pcall(function()
        local md = a:getModData()
        md.LWS_pet = { owner = want.key, uid = want.uid }
    end)
    local rec = { animal = a, id = idOf(a), uid = want.uid, piece = want.piece, pathAt = 0 }
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
        P.sound(rec.animal, "LWSPetWhine")
        P.sendState(player)
    elseif before > 0 and d.hunger <= 0 then
        log("%s: %s is starving -- it will not take orders until fed", LWS.name(player), rec.piece)
        LWS.toClient(player, "Msg", { key = "IGUI_LWS_Msg_PetStarving", arg = LWS.pieceName(rec.piece), text = true })
        P.sound(rec.animal, "LWSPetWhine")
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

function P.step(key, rec, owner)
    local animal = rec.animal
    -- nothing hurts it (zombies, players, falls): health stays full
    pcall(function() if animal:getHealth() < 1 then animal:setHealth(1) end end)
    local o = LWS.Server.owner(key, false)
    if not o then return end
    local d = P.hungerTick(owner, rec, o)
    local far = math.max(6, tonumber(P.sv("PetTeleportDistance")) or 25)
    local dd = dist(animal, owner)
    local dz = math.abs(math.floor(animal:getZ()) - math.floor(owner:getZ()))
    if d.mode == "stay" then
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
    if dd <= P.FOLLOW_NEAR then return end
    local t = now()
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

function P.handle(player, command, args)
    if command == "PetFeed" then
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
        P.sound(rec.animal, "LWSPetEat")
        LWS.toClient(player, "Msg", { key = "IGUI_LWS_Msg_PetFed", arg = LWS.pieceName(rec.piece), text = true })
        P.sendState(player)
    elseif command == "PetMode" or command == "PetCome" or command == "PetSpeak" then
        if not P.sv("PetCommands") then log("REJECTED %s from %s: commands are off in sandbox", command, LWS.name(player)); return end
        local rec, d = petOf(player)
        if not rec or not d then return end
        -- a starving pet only follows (feeding it brings the tricks back)
        if P.sv("PetHunger") and d.hunger <= 0 and command ~= "PetCome" then
            log("%s: %s is starving and ignores %s", LWS.name(player), rec.piece, command)
            P.sound(rec.animal, "LWSPetWhine")
            LWS.toClient(player, "Msg", { key = "IGUI_LWS_Msg_PetStarving", arg = LWS.pieceName(rec.piece), text = true })
            return
        end
        if command == "PetMode" then
            d.mode = args.mode == "stay" and "stay" or "follow"
            if d.mode == "stay" then
                pcall(function() rec.animal:stopAllMovementNow() end)
                pcall(function() local b = rec.animal:getBehavior(); if b then b:setBlockMovement(true) end end)
            else
                rec.pathAt = 0
                pcall(pathTo, rec.animal, player)
            end
            log("%s: %s -> %s", LWS.name(player), rec.piece, d.mode)
        elseif command == "PetCome" then
            d.mode = "follow"
            rec.pathAt = now()
            local ok, err = pcall(pathTo, rec.animal, player)
            log("%s calls %s%s", LWS.name(player), rec.piece, ok and "" or (" -- path FAILED: " .. tostring(err)))
        else
            P.sound(rec.animal, "LWSPetBark")
            log("%s: %s barks", LWS.name(player), rec.piece)
        end
        P.sendState(player)
    else
        log("REJECTED unknown pet command %s from %s", tostring(command), LWS.name(player))
    end
end

-- ------------------------------------------------------------- the loops
local function isPetType(animal)
    local ok, t = pcall(function() return animal:getAnimalType() end)
    return ok and t and tostring(t):sub(1, 7) == "lwspet_"
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

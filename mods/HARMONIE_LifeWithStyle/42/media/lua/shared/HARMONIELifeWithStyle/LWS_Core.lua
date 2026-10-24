--[[
    HARMONIE - Life With Style : shared core

    Owner, 2026-10-20: a fashion mod for the server. Pieces never spawn in
    the world; an admin gives them. They belong to the PLAYER (the account,
    later a Discord account), never drop, never leave the player, and stay
    after death. A separate wardrobe window holds them and a separate set of
    fashion slots wears them; the picture replaces the vanilla clothes of
    that slot.

    How (see LWS_Server.lua):
      * the wardrobe is a list kept on the server (global ModData), by owner
        key -- the pieces in it are not items at all;
      * a piece being WORN is a weightless, protectionless clothing item in
        the mod's own body location lws:<slot> (registries.lua), made by the
        server and worn by the client (The Only Cure's pattern). lws:<slot>
        hides the vanilla body locations of that slot (setHideModel,
        LWS_BodyLocations.lua): the real clothes keep protecting and warming,
        they are just not drawn -- nothing pokes through;
      * the _Over twin (lws:<slot>_over) hides nothing: "show my real
        clothes" for that slot.

    Here: logging, the owner key, catalog / slot lookups, the network helpers
    (the same code runs in single player, where client and server are one).
]]--

require "HARMONIELifeWithStyle/LWS_Data"

LWS = LWS or {}
LWS.NET = "HARMONIE_LWS"
LWS.VERSION = 1

-- ------------------------------------------------------------- logging
local function side()
    if isServer and isServer() then return "server" end
    if isClient and isClient() then return "client" end
    return "SP"
end
function LWS.log(tag, fmt, ...)
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    print("[HARMONIE_LWS][" .. tostring(tag) .. "][" .. side() .. "] " .. (ok and msg or tostring(fmt)))
end
LWS.logSeen = LWS.logSeen or {}
function LWS.logOnce(key, tag, fmt, ...)
    if LWS.logSeen[key] then return end
    LWS.logSeen[key] = true
    LWS.log(tag, fmt, ...)
end
function LWS.name(p)
    if not p then return "?" end
    local ok, n = pcall(function() return p:getUsername() end)
    if ok and n and n ~= "" then return tostring(n) end
    ok, n = pcall(function() return p:getDisplayName() end)
    return ok and tostring(n) or "?"
end
function LWS.typeOf(item)
    local ok, t = pcall(function() return item:getFullType() end)
    return ok and tostring(t) or "?"
end

-- ------------------------------------------------------------- lookups
LWS.SLOT = {}
for i, s in ipairs(LWS.SLOTS) do s.order = i; LWS.SLOT[s.id] = s end
LWS.PIECE = {}
for _, c in ipairs(LWS.CATALOG) do LWS.PIECE[c.id] = c end

-- the worn item of a piece: <module>.<id> hides the vanilla clothes, <id>_Over shows them
function LWS.carrierType(pieceId, showReal)
    return LWS.MODULE .. "." .. tostring(pieceId) .. (showReal and "_Over" or "")
end

-- full type "HARMONIE_LWS.<id>[_Over]" -> id, over?
function LWS.parseType(fullType)
    local id = tostring(fullType or ""):match("^" .. LWS.MODULE .. "%.(.+)$")
    if not id then return nil end
    local base = id:match("^(.-)_Over$")
    if base and LWS.PIECE[base] then return base, true end
    if LWS.PIECE[id] then return id, false end
    return nil
end

-- a piece of OUR catalog whose item script is in OUR module -- nothing of
-- another mod ever goes into the wardrobe (owner, 2026-10-20)
function LWS.isOurPiece(pieceId)
    pieceId = tostring(pieceId or "")
    if not LWS.PIECE[pieceId] then return false end
    -- a pet has no item script: our catalog is the whole check
    if LWS.PIECE[pieceId].pet then return true end
    if not getScriptManager then return true end
    local ok, it = pcall(function() return getScriptManager():FindItem(LWS.MODULE .. "." .. pieceId) end)
    if not ok then return true end
    if not it then return false end
    local okM, m = pcall(function() return it:getModuleName() end)
    if okM and m then return tostring(m) == LWS.MODULE end
    return true
end

function LWS.isFashion(item)
    if not item then return false end
    local ok, m = pcall(function() return item:getModule() end)
    if ok and m then return tostring(m) == LWS.MODULE end
    return LWS.typeOf(item):sub(1, #LWS.MODULE + 1) == LWS.MODULE .. "."
end

-- A gacha item as an item (module HARMONIE_LWSG, 0.7.3): it lives in the
-- wardrobe record, never in an inventory -- the server sweep deletes one. The
-- Guardian armour layer of the same module is the one exception.
LWS.GACHA_MODULE = "HARMONIE_LWSG"
LWS.GACHA_PROXY = "HARMONIE_LWSG.GuardianProtectionProxy"
function LWS.isGachaItem(item)
    if not item then return false end
    local t = LWS.typeOf(item)
    return t:sub(1, #LWS.GACHA_MODULE + 1) == LWS.GACHA_MODULE .. "." and t ~= LWS.GACHA_PROXY
end

-- ------------------------------------------------------------- pet food
-- how much of a pet's hunger (0..1) one item fills: dog food all of it, other
-- food by how filling it is; rotten, poisoned or not food = 0 (cannot be fed)
LWS.DOG_FOOD = { ["Base.Dogfood"] = true, ["Base.DogfoodOpen"] = true, ["Base.DogFoodBag"] = true, ["Base.CatFoodBag"] = true }
function LWS.petFoodValue(item)
    if not item then return 0 end
    local okF, isFood = pcall(function() return instanceof(item, "Food") end)
    if not okF or not isFood then return 0 end
    local okR, rotten = pcall(function() return item:isRotten() end)
    if okR and rotten then return 0 end
    local okP, poison = pcall(function() return item:getPoisonPower() end)
    if okP and tonumber(poison) and poison > 0 then return 0 end
    if LWS.DOG_FOOD[LWS.typeOf(item)] then return 1 end
    local ok, hc = pcall(function() return item:getHungChange() end)
    hc = ok and tonumber(hc) or 0
    if hc >= 0 then return 0 end
    return math.min(1, 0.15 + (-hc) * 2)
end

-- ------------------------------------------------------------- pet animation
-- Companion Dogs' animation nodes, renamed (AnimSets/raccoon/*/lws*.xml, made by
-- tools/import_pets.py). Each needs a variable only our pets have. Their
-- measured gait scales: the walk clip at 0.939 matches the body's speed (the
-- vanilla 1.20 slid the feet), the run clip at 1.0.
LWS.PET_WALK_SCALE, LWS.PET_RUN_SCALE = 0.939, 1.0
LWS.PET_WALK_SPEED, LWS.PET_RUN_SPEED = 6.03, 3.82   -- animalSpeed while walking / running
LWS.PET_IDLE_VARS = { "lwsIdle2", "lwsIdle3", "lwsSniff" }
-- cats only (the clips are only in the cat model): sit down, sit, groom while sitting
LWS.CAT_GROOM_VARS = { "lwsSitGroom", "lwsSitGroom2" }
-- what a pet says, by kind (sounds: tools/import_pets.py)
LWS.PET_VOICE = {
    dog = { speak = "LWSPetBark", hungry = "LWSPetWhine", eat = "LWSPetEat", happy = "LWSPetHappy" },
    cat = { speak = "LWSPetMeow", hungry = "LWSPetMeow", eat = "LWSPetPurr", happy = "LWSPetPurr" },
}
function LWS.petKind(pieceId)
    local c = LWS.PIECE[tostring(pieceId)]
    return c and c.pet and c.pet.kind or "dog"
end
function LWS.isPetAnimal(animal)
    local ok, t = pcall(function() return animal:getAnimalType() end)
    return ok and t ~= nil and tostring(t):sub(1, 7) == "lwspet_"
end
-- the variables every copy of a pet needs (server, single player and each client)
function LWS.petBaseVars(animal)
    pcall(function()
        animal:setVariable("lwsPet", true)
        animal:setVariable("lwsWalkScale", LWS.PET_WALK_SCALE)
        animal:setVariable("lwsRunScale", LWS.PET_RUN_SCALE)
    end)
    LWS.petProtect(animal)
end

-- Owner, 2026-10-24: pets ran off when someone fired a gun, and could be shot.
-- Every copy of a pet (the server's AND each client's -- in multiplayer the
-- shooter's own game decides a hit) is made unhurtable, and its fear is reset
-- (LWS_Pets.lua calls LWS.petCalm every tick). The B42 animal API is not
-- documented: only methods the animal really has are called (a missing one
-- logs "Object tried to call nil" even inside pcall), and which ones exist is
-- written to console.txt once.
LWS.PET_PROTECT = { "setIsInvincible", "setInvulnerable", "setGodMod", "setAvoidDamage", "setNoDamage" }
LWS.PET_CALM = { { "setStress", 0 }, { "setStressLevel", 0 }, { "setFear", 0 },
                 { "setAlerted", false }, { "setIsAlerted", false }, { "setPanic", false } }
LWS.PET_CALM_BEHAVIOR = { { "setFleeing", false }, { "setIsFleeing", false }, { "setPanic", false } }
local apiLogged = false
local function logApi(animal)
    if apiLogged then return end
    apiLogged = true
    local have = {}
    for _, m in ipairs(LWS.PET_PROTECT) do if animal[m] then have[#have + 1] = m end end
    for _, c in ipairs(LWS.PET_CALM) do if animal[c[1]] then have[#have + 1] = c[1] end end
    local b
    if animal.getBehavior then pcall(function() b = animal:getBehavior() end) end
    for _, c in ipairs(LWS.PET_CALM_BEHAVIOR) do if b and b[c[1]] then have[#have + 1] = "behavior:" .. c[1] end end
    LWS.log("Pets", "pet protection / calm methods found on the animal: %s", #have > 0 and table.concat(have, ", ") or "NONE")
end
function LWS.petProtect(animal)
    if not animal then return end
    logApi(animal)
    for _, m in ipairs(LWS.PET_PROTECT) do
        local f = animal[m]
        if f then pcall(f, animal, true) end
    end
end
function LWS.petCalm(animal)
    if not animal then return end
    for _, c in ipairs(LWS.PET_CALM) do
        local f = animal[c[1]]
        if f then pcall(f, animal, c[2]) end
    end
    local b
    if animal.getBehavior then pcall(function() b = animal:getBehavior() end) end
    if b then
        for _, c in ipairs(LWS.PET_CALM_BEHAVIOR) do
            local f = b[c[1]]
            if f then pcall(f, b, c[2]) end
        end
    end
end

-- ------------------------------------------------------------- owner
-- One key per owner. Now: the account name in multiplayer, the save itself
-- in single player (a new character in the same save gets the wardrobe
-- back). Later: a Discord account -- LWS.ownerKey is the only place that
-- will change (owner, 2026-10-20: "ในอนาคตจะเป็นบัญชีดิสคอร์ด").
function LWS.ownerKey(player)
    if not player then return nil end
    if (isServer and isServer()) or (isClient and isClient()) then
        local ok, u = pcall(function() return player:getUsername() end)
        if ok and u and u ~= "" then return "u:" .. tostring(u) end
        return nil
    end
    return "sp:local"
end

-- The game's access level only (never -debug): what a multiplayer server trusts.
function LWS.hasAdminAccess(player)
    if not player then return false end
    local ok, a = pcall(function() return player:isAccessLevel("admin") end)
    if ok and a then return true end
    local ok2, lvl = pcall(function() return player:getAccessLevel() end)
    lvl = ok2 and lvl and tostring(lvl):lower() or "none"
    if lvl == "admin" or lvl == "moderator" or lvl == "overseer" then return true end
    if isClient and isClient() and isAdmin then
        local ok3, me = pcall(isAdmin)
        if ok3 and me then return true end
    end
    return false
end

-- Admin tools (the Give tab, the debug menu, Admin* commands): admins, and a game
-- started with -debug (owner, 2026-10-24: "เห็นเฉพาะแอดมินหรือคนเปิด -debug").
-- Single player without -debug is no longer an admin. On a multiplayer server
-- isDebugEnabled() is the SERVER's -debug: a client's own -debug shows the tab on
-- that client, but the server still asks for the access level.
function LWS.isAdmin(player)
    if not player then return false end
    if isDebugEnabled and isDebugEnabled() then return true end
    return LWS.hasAdminAccess(player)
end

-- ------------------------------------------------------------- texts
function LWS.T(key, ...)
    local ok, s = pcall(getText, key, ...)
    if ok and s and s ~= key then return s end
    return key
end
function LWS.slotName(slot) return LWS.T("IGUI_LWS_Slot_" .. tostring(slot)) end
function LWS.pieceName(pieceId)
    local c = LWS.PIECE[tostring(pieceId)]
    if c and c.pet then return LWS.T("IGUI_LWS_PetName_" .. tostring(pieceId)) end
    local key = LWS.MODULE .. "." .. tostring(pieceId)
    local ok, it = pcall(function() return getScriptManager():FindItem(key) end)
    if ok and it then
        local ok2, n = pcall(function() return it:getDisplayName() end)
        if ok2 and n and n ~= "" then return tostring(n) end
    end
    return tostring(pieceId)
end

-- ------------------------------------------------------------- network
-- In single player the client and the server are the same Lua state: the
-- calls go straight to the other side (no network).
local function mp() return (isServer and isServer()) or (isClient and isClient()) end
function LWS.toServer(player, command, args)
    args = args or {}
    if isClient and isClient() then
        sendClientCommand(player, LWS.NET, command, args)
    elseif LWS.Server and LWS.Server.handle then
        LWS.Server.handle(player, command, args)
    else
        LWS.logOnce("noserver", "Net", "no server side loaded: %s dropped", tostring(command))
    end
end
function LWS.toClient(player, command, args)
    args = args or {}
    if isServer and isServer() then
        sendServerCommand(player, LWS.NET, command, args)
    elseif not mp() and LWS.Client and LWS.Client.handle then
        LWS.Client.handle(command, args)
    end
end

return LWS

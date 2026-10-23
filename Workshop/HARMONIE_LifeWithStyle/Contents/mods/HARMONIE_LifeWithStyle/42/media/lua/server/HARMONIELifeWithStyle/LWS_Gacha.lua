--[[
    HARMONIE - Life With Style : gacha items (server; single player too)

    Owner, 2026-10-23: the items of "RWZ Retention Items" v0.4.2 (the owner's
    own mod) live here now. Like fashion they are given by admins and are NOT
    items: a count per item in the wardrobe record, used from the window's
    "Gacha items" tab -- nothing to drop, steal or find in the vanilla
    inventory. The effects, numbers and the XP formula are RWZ's (only moved):

      medical / body   effect at once (bandage, medkit, stim, endurance,
                       tiredness, stress, hunger, thirst)
      guides, manuals  an XP buff for real minutes; one "training" family
                       buff at a time (Training I / II / Master)
      capsules         one capsule at a time, 30 real minutes; Guardian and
                       Mini Compound-V also wear the invisible armour layer
                       HARMONIE_LWSG.GuardianProtectionProxy (+5 scratch /
                       bite / bullet in the engine's own protection roll)
      journeys         flat XP at once (no book or buff multiplies it)
      New Dawn set     equip / unequip (not used up): XP multiplier last

    Wardrobe record (LWS_Server.lua):
      o.gacha      = { [itemId] = count }
      o.gachaSet   = { [itemId] = true }               -- New Dawn pieces on
      o.gachaBuffs = { [buffKey] = { u = until ms, s = start ms } }  -- real time
    Buffs end when the character dies (RWZ kept them on the character).

    Commands: GachaUse { id }, GachaEquip { id, on }; admins: AdminGachaGrant
    { owner, id, n }, AdminGachaRevoke { owner, id, n }. Reply: GachaState.
]]--

require "HARMONIELifeWithStyle/LWS_Core"
require "HARMONIELifeWithStyle/LWS_GachaData"

LWS.Gacha = LWS.Gacha or {}
local G = LWS.Gacha
local log = function(...) LWS.log("Gacha", ...) end

G.PROXY = "HARMONIE_LWSG.GuardianProtectionProxy"

local function now() return getTimestampMs and getTimestampMs() or 0 end
local function server() return isServer and isServer() end

-- ------------------------------------------------------------- data
local function rec(o)
    o.gacha = o.gacha or {}
    o.gachaSet = o.gachaSet or {}
    o.gachaBuffs = o.gachaBuffs or {}
    return o
end

function G.ownerOf(player)
    local key = LWS.ownerKey(player)
    return key and LWS.Server and rec(LWS.Server.owner(key, true)), key
end

function G.stateOf(o)
    rec(o)
    local items, set, buffs = {}, {}, {}
    for id, n in pairs(o.gacha) do
        if LWS.GACHA_ITEM[id] and (tonumber(n) or 0) > 0 then items[id] = n end
    end
    for id, on in pairs(o.gachaSet) do if on and (o.gacha[id] or 0) > 0 then set[id] = true end end
    local t = now()
    for key, b in pairs(o.gachaBuffs) do
        if type(b) == "table" and (tonumber(b.u) or 0) > t then buffs[key] = { rem = b.u - t, s = b.s } end
    end
    return { items = items, set = set, buffs = buffs }
end

function G.sendState(player)
    local o = G.ownerOf(player)
    if o then LWS.toClient(player, "GachaState", G.stateOf(o)) end
end

-- the capsule active now (one at most), and its buff definition
function G.activeCapsule(o)
    local t = now()
    for key, b in pairs(o and o.gachaBuffs or {}) do
        local def = LWS.GACHA_BUFFS[key]
        if def and def.family == "capsule" and type(b) == "table" and (tonumber(b.u) or 0) > t then return key, def end
    end
    return nil
end

-- ------------------------------------------------------------- the Guardian armour layer
local function proxyOf(player)
    local found
    pcall(function()
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local it = worn:getItemByIndex(i)
            if it and LWS.typeOf(it) == G.PROXY then found = it end
        end
    end)
    if found then return found end
    pcall(function()
        local list = player:getInventory():getAllTypeRecurse(G.PROXY)
        if list and list:size() > 0 then found = list:get(0) end
    end)
    return found
end

local function syncClothing(player, location, item)
    if not server() then pcall(function() player:resetModelNextFrame() end); return end
    pcall(function() sendClothing(player, location, item) end)
    pcall(function() syncVisuals(player) end)
end

function G.ensureProxy(player)
    if not player or player:isDead() then return end
    local item = proxyOf(player)
    local inv = player:getInventory()
    if not item then
        item = inv:AddItem(G.PROXY)
        if not item then LWS.logOnce("noproxy", "Gacha", "could NOT make %s -- Guardian armour off", G.PROXY); return end
        if server() and sendAddItemToContainer then pcall(sendAddItemToContainer, inv, item) end
    end
    if not player:isEquippedClothing(item) then
        local location = item:getBodyLocation()
        if not location then LWS.logOnce("proxyloc", "Gacha", "%s has no body location -- Guardian armour off", G.PROXY); return end
        player:setWornItem(location, item)
        syncClothing(player, location, item)
        log("%s: Guardian armour layer on", LWS.name(player))
    end
end

function G.clearProxy(player)
    local item = player and proxyOf(player)
    if not item then return end
    local location = item:getBodyLocation()
    if player:isEquippedClothing(item) then
        player:removeWornItem(item)
        syncClothing(player, location, nil)
    end
    local c = item:getContainer()
    if c then
        c:Remove(item)
        if server() and sendRemoveItemFromContainer then pcall(sendRemoveItemFromContainer, c, item) end
    end
    log("%s: Guardian armour layer off", LWS.name(player))
end

function G.reconcileProxy(player, o)
    local _, def = G.activeCapsule(o)
    if def and def.effects and (tonumber(def.effects.armorProtection) or 0) > 0 then G.ensureProxy(player) else G.clearProxy(player) end
end

-- ------------------------------------------------------------- effects (RWZ's, unchanged)
local function clamp01(v) if v < 0 then return 0 elseif v > 1 then return 1 end return v end
local function syncStat(player, stat) if server() then pcall(function() sendPlayerStat(player, stat) end) end end
local function syncHealth(player)
    if not server() then return end
    pcall(function() sendDamage(player) end)
    pcall(function() sendPlayerEffects(player) end)
end
local function changeStat(player, stat, delta)
    local st = player:getStats()
    st:set(stat, clamp01(st:get(stat) + delta))
    syncStat(player, stat)
end
local function setStat(player, stat, value)
    player:getStats():set(stat, clamp01(value))
    syncStat(player, stat)
end
local function needsBandage(part)
    if not part or part:bandaged() then return false end
    return part:bleeding() or part:scratched() or part:isCut() or part:bitten() or part:deepWounded() or part:isBurnt()
end

G.ACTIONS = {
    AdvancedBandage = function(player)
        local bd = player:getBodyDamage()
        if not bd:UseBandageOnMostNeededPart() then return false, "IGUI_LWSG_Msg_NoWound" end
        bd:AddGeneralHealth(5.0)
        syncHealth(player)
        return true
    end,
    AdvancedMedkit = function(player)
        local bd = player:getBodyDamage()
        local parts = bd:getBodyParts()
        local did = false
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            if needsBandage(part) then part:setBandaged(true, 12.0, false, "Base.AlcoholBandage"); did = true end
        end
        local before = bd:getOverallBodyHealth()
        bd:AddGeneralHealth(20.0)
        syncHealth(player)
        if not did and before >= 100.0 then return false, "IGUI_LWSG_Msg_NoNeed" end
        return true
    end,
    StimHealthBooster = function(player)
        player:getBodyDamage():AddGeneralHealth(30.0)
        syncHealth(player)
        return true
    end,
    ViagraPill = function(player) changeStat(player, CharacterStat.ENDURANCE, 0.10); return true end,
    GodOfCoffee = function(player) changeStat(player, CharacterStat.FATIGUE, -0.35); return true end,
    WakeUpShot = function(player)
        changeStat(player, CharacterStat.FATIGUE, -0.50)
        setStat(player, CharacterStat.STRESS, 1.0)
        return true
    end,
    FieldRationPlus = function(player)
        changeStat(player, CharacterStat.HUNGER, -0.20)
        changeStat(player, CharacterStat.THIRST, -0.20)
        return true
    end,
}

function G.activateBuff(player, o, key)
    local def = LWS.GACHA_BUFFS[key]
    if not def then return false, "IGUI_LWSG_Msg_NoEffect" end
    local t = now()
    if def.family then
        for other, odef in pairs(LWS.GACHA_BUFFS) do
            if odef.family == def.family and other ~= key and o.gachaBuffs[other] then
                o.gachaBuffs[other] = nil
                log("%s: %s replaced by %s (one %s at a time)", LWS.name(player), other, key, def.family)
            end
        end
    end
    o.gachaBuffs[key] = { u = t + def.ms, s = t }
    if def.family == "capsule" then G.reconcileProxy(player, o) end
    return true
end

function G.journeyXP(player, perkId, amount)
    local perk
    pcall(function() perk = Perks.FromString(perkId) end)
    amount = tonumber(amount)
    if not perk then return false, "IGUI_LWSG_Msg_NoEffect" end
    if not amount or amount <= 0 then return false, "IGUI_LWSG_Msg_NoEffect" end
    -- flat XP, no book / trait multiplier; GameServer.addXp replicates it in multiplayer
    local ok = server() and pcall(function() GameServer.addXp(player, perk, amount, true, true) end)
    if not ok then
        local okXp = pcall(function() player:getXp():AddXPNoMultiplier(perk, amount) end)
        if not okXp then return false, "IGUI_LWSG_Msg_NoEffect" end
    end
    return true
end

-- ------------------------------------------------------------- commands
local function msg(player, key, arg)
    LWS.toClient(player, "Msg", { key = key, arg = arg, text = arg ~= nil })
end

function G.use(player, id)
    local o = G.ownerOf(player)
    local g = LWS.GACHA_ITEM[id]
    if not o or not g then log("REJECTED GachaUse from %s: %s is not a gacha item", LWS.name(player), tostring(id)); return end
    if (o.gacha[id] or 0) <= 0 then log("REJECTED GachaUse from %s: has no %s", LWS.name(player), id); G.sendState(player); return end
    if player:isDead() then return end
    local u = g.use or {}
    if u.set then log("REJECTED GachaUse from %s: %s is equipped, not used", LWS.name(player), id); return end
    local ok, why
    local okCall, err = pcall(function()
        if u.buff then ok, why = G.activateBuff(player, o, u.buff)
        elseif u.perk then ok, why = G.journeyXP(player, u.perk, u.flatXP)
        elseif u.action and G.ACTIONS[u.action] then ok, why = G.ACTIONS[u.action](player)
        else ok, why = false, "IGUI_LWSG_Msg_NoEffect" end
    end)
    if not okCall then ok, why = false, "IGUI_LWSG_Msg_NoEffect"; log("%s: using %s FAILED: %s", LWS.name(player), id, tostring(err)) end
    if not ok then
        log("%s: %s not used (%s) -- the item is kept", LWS.name(player), id, tostring(why))
        msg(player, why or "IGUI_LWSG_Msg_NoEffect")
        return
    end
    o.gacha[id] = o.gacha[id] - 1
    if o.gacha[id] <= 0 then o.gacha[id] = nil end
    log("%s used %s (%d left)%s", LWS.name(player), id, o.gacha[id] or 0, u.perk and (" -- +" .. tostring(u.flatXP) .. " " .. u.perk .. " XP") or "")
    if u.perk then LWS.toClient(player, "GachaJourney", { perk = u.perk, amount = u.flatXP }) end
    msg(player, "IGUI_LWSG_Msg_Used", LWS.T("IGUI_LWSG_Name_" .. id))
    G.sendState(player)
end

function G.handle(player, command, args)
    args = type(args) == "table" and args or {}
    if command == "GachaUse" then
        G.use(player, tostring(args.id or ""))
    elseif command == "GachaEquip" then
        local o = G.ownerOf(player)
        local id = tostring(args.id or "")
        local g = LWS.GACHA_ITEM[id]
        if not o or not g or not (g.use and g.use.set) or (o.gacha[id] or 0) <= 0 then
            log("REJECTED GachaEquip from %s: %s", LWS.name(player), id); return
        end
        o.gachaSet[id] = args.on == true or nil
        log("%s %s %s", LWS.name(player), o.gachaSet[id] and "equips" or "takes off", id)
        G.sendState(player)
    elseif command == "GachaHello" then
        local o = G.ownerOf(player)
        if o then G.reconcileProxy(player, o) end
        G.sendState(player)
    elseif command == "AdminGachaGrant" or command == "AdminGachaRevoke" then
        if not LWS.isAdmin(player) then log("REJECTED %s from %s: not an admin", command, LWS.name(player)); return end
        local key, id = tostring(args.owner or ""), tostring(args.id or "")
        local n = math.max(1, math.min(99, math.floor(tonumber(args.n) or 1)))
        if key == "" or not LWS.GACHA_ITEM[id] then log("REJECTED %s: owner %s, item %s (not a gacha item)", command, key, id); return end
        local o = rec(LWS.Server.owner(key, true))
        if command == "AdminGachaGrant" then
            o.gacha[id] = (o.gacha[id] or 0) + n
        else
            o.gacha[id] = math.max(0, (o.gacha[id] or 0) - n)
            if o.gacha[id] == 0 then o.gacha[id] = nil; o.gachaSet[id] = nil end
        end
        log("%s %s %d x %s %s %s (now %d)", LWS.name(player), command == "AdminGachaGrant" and "GAVE" or "TOOK", n, id,
            command == "AdminGachaGrant" and "to" or "from", key, o.gacha[id] or 0)
        local target = LWS.Server.onlineByKey(key)
        if target then
            LWS.toClient(target, "GachaState", G.stateOf(o))
            if command == "AdminGachaGrant" then msg(target, "IGUI_LWSG_Msg_Got", LWS.T("IGUI_LWSG_Name_" .. id)) end
        end
        LWS.toClient(player, "AdminGacha", { owner = key, state = G.stateOf(o) })
    elseif command == "AdminGachaView" then
        if not LWS.isAdmin(player) then return end
        local key = tostring(args.owner or "")
        local o = key ~= "" and LWS.Server.owner(key, false)
        LWS.toClient(player, "AdminGacha", { owner = key, state = o and G.stateOf(o) or { items = {}, set = {}, buffs = {} } })
    else
        log("REJECTED unknown gacha command %s from %s", tostring(command), LWS.name(player))
    end
end

-- ------------------------------------------------------------- the loop: expiry, armour, death
local function each(f)
    if server() then
        local online = getOnlinePlayers and getOnlinePlayers()
        for i = 0, (online and online:size() or 0) - 1 do f(online:get(i)) end
    elseif not (isClient and isClient()) then
        local p = getPlayer and getPlayer()
        if p then f(p) end
    end
end

local nextTick = 0
function G.onTick()
    local t = now()
    if t < nextTick then return end
    nextTick = t + 1000
    each(function(player)
        if player:isDead() then return end
        local key = LWS.ownerKey(player)
        local o = key and LWS.Server.owner(key, false)
        if not o then return end
        rec(o)
        local expired = false
        for k, b in pairs(o.gachaBuffs) do
            if type(b) ~= "table" or (tonumber(b.u) or 0) <= t then
                o.gachaBuffs[k] = nil
                expired = true
                log("%s: %s ran out", LWS.name(player), tostring(k))
            end
        end
        local ok, err = pcall(G.reconcileProxy, player, o)
        if not ok then LWS.logOnce("proxyerr", "Gacha", "Guardian armour check FAILED: %s", tostring(err)) end
        if expired then G.sendState(player) end
    end)
end

local function onDeath(player)
    if not player or (isClient and isClient()) then return end
    local key = LWS.ownerKey(player)
    local o = key and LWS.Server.owner(key, false)
    if o and o.gachaBuffs then
        local n = 0
        for k in pairs(o.gachaBuffs) do o.gachaBuffs[k] = nil; n = n + 1 end
        if n > 0 then log("%s died: %d gacha buffs ended", LWS.name(player), n) end
    end
    pcall(G.clearProxy, player)
end

if Events and not G.registered then
    G.registered = true
    if Events.OnTick then Events.OnTick.Add(G.onTick) end
    if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(onDeath) end
    if Events.OnInitGlobalModData then
        Events.OnInitGlobalModData.Add(function()
            local db = LWS.Server.db()
            local owners, items, pruned = 0, 0, 0
            for _, o in pairs(db.owners) do
                if o.gacha then
                    owners = owners + 1
                    for id, n in pairs(o.gacha) do
                        if LWS.GACHA_ITEM[id] and (tonumber(n) or 0) > 0 then items = items + n else o.gacha[id] = nil; pruned = pruned + 1 end
                    end
                end
            end
            log("gacha items loaded: %d owners hold %d items (%d kinds in the catalog), %d unknown entries removed", owners, items, #LWS.GACHA_ITEMS, pruned)
        end)
    end
end

return G

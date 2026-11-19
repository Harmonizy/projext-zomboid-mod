--[[
    HARMONIE - From Garden to Plate: give back the ingredients of a dish left
    half-made by the OLD Cooking tab (GTP 1.0.4 - 1.0.8 took every planned
    ingredient at the start and kept them in a "pending" record until the
    dish was finished or cancelled). GTP 1.1.0 removed that flow, so a
    record still in a save would hold its ingredients forever: here the
    authority (SP / MP server) recreates them once, in the player's
    inventory, and forgets the record.

    MP rules kept: the server does it (never the client); the record is read
    from the world's global ModData ("HARMONIE_GTP_CookPending", 1.0.8) and
    from the player's modData (older saves); a refund is marked per player
    in the world's data, so a client that sends its old modData again never
    gets it twice.
]]--

HARMONIE_GTP = HARMONIE_GTP or {}
local F = {}
HARMONIE_GTP.CookRefund = F
F.STORE = "HARMONIE_GTP_CookPending"
F.OLD_KEY = "HARMONIE_CookPending"
F.NET = "HARMONIE_GTP_Refund"

local function log(fmt, ...) if HARMONIE_GTP.Log then HARMONIE_GTP.Log("CookRefund", fmt, ...) end end
local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
local function isServerSide() return isServer and isServer() end
local function authority() return not (isClient and isClient()) end
local function nameOf(p) return tostring(call(p, "getUsername") or "?") end
local function store()
    if not (ModData and ModData.getOrCreate) then return nil end
    local ok, t = pcall(ModData.getOrCreate, F.STORE)
    return ok and t or nil
end

local function restore(player, s)
    if type(s) ~= "table" or not s.t or s.usedFrom then return false end
    local inv = call(player, "getInventory")
    local it = inv and call(inv, "AddItem", s.t)
    if not it then return false end
    if s.age then pcall(function() it:setAge(s.age) end) end
    if s.food then
        if s.cooked then pcall(function() it:setCooked(true) end) end
        if s.burnt then pcall(function() it:setBurnt(true) end) end
        if s.baseHunger then pcall(function() it:setBaseHunger(s.baseHunger) end) end
        if s.hunger then pcall(function() it:setHungChange(s.hunger) end) end
    end
    if s.cond then pcall(function() it:setCondition(s.cond) end) end
    if type(s.vit) == "table" then
        local md = call(it, "getModData")
        if md then md.HARMONIE_Vitamins, md.HARMONIE_HungerUnits = s.vit, s.units end
    end
    if s.fluidAmount and s.fluidAmount > 0 then
        local fc = call(it, "getFluidContainer")
        local fluid = Fluid and Fluid.Water
        if fc and fluid then pcall(function() fc:addFluid(fluid, s.fluidAmount) end) end
    end
    if isServerSide() then
        if sendAddItemToContainer then pcall(sendAddItemToContainer, inv, it) end
        if sendItemStats then pcall(sendItemStats, it) end
    end
    return true
end

function F.check(player)
    if not player or not authority() then return end
    local st = store()
    if not st then return end
    local key = "u:" .. nameOf(player)
    if st["refunded:" .. key] then
        -- an old copy the client sent again: drop it, never pay twice
        local md = call(player, "getModData")
        if md and md[F.OLD_KEY] ~= nil then md[F.OLD_KEY] = nil end
        return
    end
    local p = st[key]
    local md = call(player, "getModData")
    if type(p) ~= "table" or not p.dish then
        p = md and md[F.OLD_KEY]
        if type(p) ~= "table" or not p.dish then return end
    end
    local n = 0
    for _, s in ipairs(p.items or {}) do if restore(player, s) then n = n + 1 end end
    st[key] = nil
    st["refunded:" .. key] = true
    if md then md[F.OLD_KEY] = nil end
    log("%s: the old Cooking tab had %s half-made -- %d ingredient(s) given back (the dish flow was removed in GTP 1.1.0)", nameOf(player), tostring(p.dish), n)
    if isServerSide() and sendServerCommand then
        pcall(sendServerCommand, player, F.NET, "refunded", { n = n })
    elseif F.onRefunded then
        pcall(F.onRefunded, { n = n })
    end
end

local function everyMinute()
    if not authority() then return end
    if isServerSide() then
        local online = getOnlinePlayers and getOnlinePlayers()
        for i = 0, (online and online:size() or 0) - 1 do
            local p = online:get(i)
            if p then pcall(F.check, p) end
        end
    else
        local p = getSpecificPlayer and getSpecificPlayer(0)
        if p then pcall(F.check, p) end
    end
end

if Events then
    if Events.EveryOneMinute then Events.EveryOneMinute.Add(everyMinute) end
    if Events.OnGameStart then Events.OnGameStart.Add(everyMinute) end
    if Events.OnServerCommand then
        Events.OnServerCommand.Add(function(module, command, args)
            if module ~= F.NET or command ~= "refunded" then return end
            local p = getPlayer and getPlayer()
            local md = call(p, "getModData")
            if md then md[F.OLD_KEY] = nil end
            log("the server gave back %s ingredient(s) of an old half-made dish", tostring(args and args.n))
            if F.onRefunded then pcall(F.onRefunded, args or {}) end
        end)
    end
end

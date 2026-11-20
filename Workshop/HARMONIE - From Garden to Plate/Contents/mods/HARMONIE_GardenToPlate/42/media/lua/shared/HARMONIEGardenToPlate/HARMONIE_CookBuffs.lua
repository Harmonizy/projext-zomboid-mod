--[[
    HARMONIE - From Garden to Plate: dish buffs (GTP 1.1.0, owner
    2026-11-19). A vanilla dish carries a score (HARMONIE_Prep.lua: the
    average of its prepared ingredients). Eating it:
      score < 0       a little unhappier (K.BAD_DISH_UNHAPPY x share eaten)
      0 .. 0.49       nothing
      0.5 / 1.0 / 1.5 buff level 1 / 2 / 3: x1 / x1.5 / x2 as strong, and
                      x0.5 / x1 / x1.5 of K.buffHours(cook level) long
    Kind = the dish's evolved-recipe family (stew -> hearty, salad ->
    fresh ...), else its food type, else hearty:
      hearty    tire more slowly, a little endurance back
      energized endurance comes back faster
      comfort   unhappiness and boredom melt away
      calm      stress and panic ease off
      fresh     a bit of endurance and good mood
    Eating more of the same kind and level adds time, never past one whole
    dish's worth; another buff replaces it.

    Where it runs: the eating (ISEatFoodAction:complete) and the effects
    (once per game minute) run where stats really live -- this machine in
    SP, the server in MP. The buff is kept in GLOBAL ModData by username
    (never the player's modData: the MP client's copy replaces it). The
    client only shows it (speech line, halo text, the Cooking tab).
]]--

require "HARMONIEGardenToPlate/HARMONIE_CookCore"

HARMONIE_GTP = HARMONIE_GTP or {}
local K = HARMONIE_GTP.Cook
local log = function(fmt, ...) if HARMONIE_GTP.Log then HARMONIE_GTP.Log("CookBuff", fmt, ...) end end
local logOnce = function(key, fmt, ...) if HARMONIE_GTP.LogOnce then HARMONIE_GTP.LogOnce("CookBuff:" .. key, "CookBuff", fmt, ...) end end

-- per game minute; stat scales: Endurance / Fatigue / Stress 0-1,
-- Unhappiness / Boredom / Panic 0-100
K.BUFFS = {
    hearty    = { { "FATIGUE", -0.00025 }, { "ENDURANCE", 0.0005 } },
    energized = { { "ENDURANCE", 0.002 } },
    comfort   = { { "UNHAPPINESS", -0.25 }, { "BOREDOM", -0.25 } },
    calm      = { { "STRESS", -0.002 }, { "PANIC", -0.5 } },
    fresh     = { { "ENDURANCE", 0.001 }, { "UNHAPPINESS", -0.1 }, { "BOREDOM", -0.1 } },
}
K.BUFF_OF_FAMILY = {
    stew = "hearty", roast = "hearty", pie = "hearty", burger = "hearty", pizza = "hearty", burrito = "hearty",
    taco = "hearty", hotdog = "hearty", bread = "hearty",
    stirfry = "energized", pasta = "energized", rice = "energized", omelette = "energized", sandwich = "energized", oatmeal = "energized",
    cake = "comfort", sweetpie = "comfort", muffin = "comfort", pancakes = "comfort", icecream = "comfort", toast = "comfort",
    soup = "calm", drink = "calm",
    salad = "fresh", fruitsalad = "fresh",
}
K.BUFF_NET = "HARMONIE_GTP_CookBuff"

function K.buffsOn() return K.sv("CookBuffs", true) ~= false end
function K.buffHours(level)
    return (2 + math.max(0, tonumber(level) or 0)) * math.max(0.1, tonumber(K.sv("CookBuffHours", 1)) or 1)
end
-- GTP 1.1.0: the buff kind of a vanilla dish -- the evolved-recipe family
-- kept on it (HARMONIE_Dish.fam), else what kind of food it is
K.BUFF_OF_FOODTYPE = { Bread = "hearty", Pasta = "energized", Rice = "energized", Egg = "energized", Candy = "comfort", Sugar = "comfort",
    Chocolate = "comfort", Fruits = "fresh", Berry = "fresh", Vegetables = "fresh", Greens = "fresh", Tea = "calm", Coffee = "calm", Cocoa = "calm",
    Stock = "calm" }
function K.buffKindOf(item, fam)
    if fam and K.BUFF_OF_FAMILY[fam] then return K.BUFF_OF_FAMILY[fam] end
    local ok, ft = pcall(function() return item:getFoodType() end)
    if ok and ft and K.BUFF_OF_FOODTYPE[tostring(ft)] then return K.BUFF_OF_FOODTYPE[tostring(ft)] end
    return "hearty"
end
-- buff level 1 / 2 / 3: how strong (x) and how long (x of K.buffHours)
K.TIER_STRENGTH = { 1.0, 1.5, 2.0 }
K.TIER_HOURS = { 0.5, 1.0, 1.5 }
K.BAD_DISH_UNHAPPY = 10   -- a dish scored below 0: this much unhappier (whole dish)

local function worldHours()
    local ok, h = pcall(function() return getGameTime():getWorldAgeHours() end)
    return ok and tonumber(h) or 0
end
local function nameOf(p)
    local ok, n = pcall(function() return p:getUsername() end)
    return ok and tostring(n) or "?"
end
local function authority() return not (isClient and isClient()) end

-- GTP 1.1.0: the buffs live in GLOBAL ModData by username, never in the
-- player's modData (in MP the client's copy of that replaces the server's --
-- the same trap as the cooking "pending" record, GTP 1.0.8)
K.BUFF_STORE = "HARMONIE_GTP_CookBuff"
local function store()
    if not ModData or not ModData.getOrCreate then return nil end
    local ok, t = pcall(ModData.getOrCreate, K.BUFF_STORE)
    return ok and t or nil
end
local function keyOf(player) return "u:" .. nameOf(player) end
-- GTP 1.2.0: hours this CHARACTER has lived -- a buff kept for the same
-- username but written before a newer character was born is not theirs
local function lived(player)
    local ok, h = pcall(function() return player:getHoursSurvived() end)
    return ok and tonumber(h) or nil
end
K.livedHours = lived
local function getRec(player)
    local t = store()
    local b = t and t[keyOf(player)]
    -- once per character ever (the MP client may send its old copy again)
    if b == nil and t and not t["m:" .. keyOf(player)] then
        t["m:" .. keyOf(player)] = true
        -- an old buff in the player's modData moves over once
        local ok, md = pcall(function() return player:getModData() end)
        local old = ok and md and md.HARMONIE_CookBuff
        if type(old) == "table" and t then
            t[keyOf(player)] = old
            md.HARMONIE_CookBuff = nil
            log("%s: old dish buff moved from the player's data to the world's", nameOf(player))
            b = old
        end
    end
    if type(b) ~= "table" then return nil end
    local hs = lived(player)
    if b.hs and hs and hs + 0.1 < b.hs then
        -- the record was written later in a life than this character has lived: a new character
        if t then t[keyOf(player)] = nil end
        log("%s: a dish buff of an earlier character was found -- removed (new character)", nameOf(player))
        return nil
    end
    return b
end
local function setRec(player, b)
    local t = store()
    if t then t[keyOf(player)] = b end
end

-- the buff now on a character (authority side), or nil
function K.activeBuff(player)
    local b = getRec(player)
    if not b or not K.BUFFS[b.kind] then return nil end
    if worldHours() >= (tonumber(b.untilH) or 0) then return nil end
    return b
end

-- tell the player (SP: straight to the client side; MP: a server command)
local function notify(player, what, b, extra)
    local args = { what = what, kind = b and b.kind, tier = b and b.tier, hoursLeft = b and math.max(0, (b.untilH or 0) - worldHours()),
        level = b and b.level, avg = extra }
    if isServer and isServer() then
        if sendServerCommand then sendServerCommand(player, K.BUFF_NET, "buff", args) end
    elseif K.onBuffNotice then
        pcall(K.onBuffNotice, player, args)
    end
end
K.notifyBuff = notify

-- a scored dish was eaten (authority side)
function K.grantDish(player, dish, item, fraction)
    if not player or type(dish) ~= "table" then return nil end
    local avg = tonumber(dish.avg) or 0
    local R = HARMONIE_GTP.Prep
    local tier = R and R.tierOf(avg) or 0
    local frac = math.max(0.25, math.min(1, tonumber(fraction) or 1))
    if tier < 0 then
        local okS, stats = pcall(function() return player:getStats() end)
        local stat = CharacterStat and CharacterStat.UNHAPPINESS
        if okS and stats and stat then
            pcall(function() stats:set(stat, math.min(100, stats:get(stat) + K.BAD_DISH_UNHAPPY * frac)) end)
        end
        log("%s ate a badly prepared dish (score %.2f): +%.1f unhappiness", nameOf(player), avg, K.BAD_DISH_UNHAPPY * frac)
        notify(player, "bad", nil, avg)
        return nil
    end
    if tier == 0 then log("%s ate a dish scored %.2f: no buff (needs 0.5)", nameOf(player), avg); return nil end
    if not K.buffsOn() then log("%s ate a dish scored %.2f: buffs are off in the sandbox", nameOf(player), avg); return nil end
    local kind = K.buffKindOf(item, dish.fam)
    local full = K.buffHours(dish.lvl) * (K.TIER_HOURS[tier] or 1)
    local add = full * frac
    local now = worldHours()
    local b = K.activeBuff(player)
    if b and b.kind == kind and (b.tier or 1) == tier then
        -- more of the same: longer, never past one whole dish's worth
        b.untilH = math.min(math.max(b.untilH, now) + add, now + full)
        b.level = dish.lvl
    else
        if b then log("%s: buff %s (level %s) replaced by %s (level %d)", nameOf(player), b.kind, tostring(b.tier), kind, tier) end
        b = { kind = kind, tier = tier, level = dish.lvl, untilH = now + add }
    end
    b.hs = lived(player)
    setRec(player, b)
    log("%s ate a dish scored %.2f (%.0f%% of it, cook level %s): %s level %d for %.1f h", nameOf(player), avg, frac * 100, tostring(dish.lvl), kind, tier, b.untilH - now)
    notify(player, "on", b, avg)
    return b
end

-- one game minute of the buff (authority side)
local statWarned = {}
local function applyBuff(player, b)
    local okS, stats = pcall(function() return player:getStats() end)
    if not okS or not stats then return end
    for _, e in ipairs(K.BUFFS[b.kind]) do
        local stat = CharacterStat and CharacterStat[e[1]]
        if stat then
            local ok, err = pcall(function()
                local v = stats:get(stat)
                local hi = (e[1] == "UNHAPPINESS" or e[1] == "BOREDOM" or e[1] == "PANIC") and 100 or 1
                local nv = math.max(0, math.min(hi, v + e[2] * (K.TIER_STRENGTH[b.tier or 1] or 1)))
                if nv ~= v then stats:set(stat, nv) end
            end)
            if not ok and not statWarned[e[1]] then statWarned[e[1]] = true; log("buff %s: could not change %s (%s)", b.kind, e[1], tostring(err)) end
        elseif not statWarned[e[1]] then
            statWarned[e[1]] = true
            log("buff %s: CharacterStat.%s does not exist in this game version -- that part is skipped", b.kind, e[1])
        end
    end
end

local function tickOne(player)
    local b = getRec(player)
    if not b then return end
    if not K.BUFFS[b.kind] or worldHours() >= (tonumber(b.untilH) or 0) then
        setRec(player, nil)
        log("%s: buff %s wore off", nameOf(player), tostring(b.kind))
        notify(player, "off", b)
        return
    end
    applyBuff(player, b)
end

local function everyMinute()
    if not authority() then return end
    if isServer and isServer() then
        local online = getOnlinePlayers and getOnlinePlayers()
        for i = 0, (online and online:size() or 0) - 1 do
            local p = online:get(i)
            if p and not p:isDead() then tickOne(p) end
        end
    else
        for i = 0, (getNumActivePlayers and getNumActivePlayers() or 1) - 1 do
            local p = getSpecificPlayer and getSpecificPlayer(i)
            if p and not p:isDead() then tickOne(p) end
        end
    end
end
K.tickBuffs = everyMinute

-- GTP 1.2.0: a character's death ends its buff (authority side)
function K.clearBuff(player, why)
    if not player or not authority() then return end
    local t = store()
    if t and t[keyOf(player)] then
        t[keyOf(player)] = nil
        log("%s: dish buff removed (%s)", nameOf(player), tostring(why))
    end
end
if Events and Events.OnPlayerDeath then
    Events.OnPlayerDeath.Add(function(player) pcall(K.clearBuff, player, "death") end)
end

-- GTP 1.2.0: records of buffs that ended more than a week (game time) ago
-- are removed once a game day (players who never came back)
K.BUFF_KEEP_HOURS = 24 * 7
function K.pruneBuffs()
    if not authority() then return 0 end
    local t = store()
    if not t then return 0 end
    local now, gone = worldHours(), {}
    for k, b in pairs(t) do
        if type(b) == "table" and k:sub(1, 2) == "u:" and (tonumber(b.untilH) or 0) < now - K.BUFF_KEEP_HOURS then gone[#gone + 1] = k end
    end
    for _, k in ipairs(gone) do t[k] = nil end
    if #gone > 0 then log("removed %d old dish-buff record(s) (ended over %d game hours ago)", #gone, K.BUFF_KEEP_HOURS) end
    return #gone
end
if Events and Events.EveryDays then Events.EveryDays.Add(function() pcall(K.pruneBuffs) end) end
if Events and Events.EveryOneMinute then Events.EveryOneMinute.Add(everyMinute) end

-- the eating, where it really happens (SP, or the MP server)
if ISEatFoodAction == nil then pcall(require, "TimedActions/ISEatFoodAction") end
if ISEatFoodAction and ISEatFoodAction.complete then
    local original_complete = ISEatFoodAction.complete
    function ISEatFoodAction:complete()
        local info
        if authority() then
            pcall(function()
                local R = HARMONIE_GTP.Prep
                local d = R and R.dishOf(self.item)
                if d then info = { dish = d, item = self.item, frac = self.percentage } end
            end)
        end
        local result = original_complete(self)
        if info then
            local ok, err = pcall(K.grantDish, self.character, info.dish, info.item, info.frac)
            if not ok then log("granting the dish buff FAILED: %s", tostring(err)) end
        end
        return result
    end
    log("eating wrapped for dish buffs (%s)", (isServer and isServer()) and "server" or "this machine")
else
    logOnce("noeat", "ISEatFoodAction not found -- dish buffs cannot be given here")
end

-- server: a client asks what buff it has (login, opening the tab)
if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= K.BUFF_NET or not player then return end
        if command == "get" then
            local b = K.activeBuff(player)
            notify(player, b and "now" or "none", b)
        else
            log("%s sent unknown buff command %s -- dropped", nameOf(player), tostring(command))
        end
    end)
end

--[[
    HARMONIE - From Garden to Plate: buffs from dishes made at the best
    quality (0.13.1, owner: "อยากให้อาหารให้บัฟต่างๆหากทำมาคุณภาพสูงสุด โดยบัฟอยู่
    นานตามระดับสกิลในการทำสูตร").

    A Cooking-tab dish whose preparation came out Excellent carries the cook's
    Cooking level (HARMONIE_CookLevel, set with its quality). Eating it gives
    the dish family's buff for (2 + that level) game hours x the sandbox
    multiplier, times the share of the dish eaten (at least a quarter), so a
    level 10 cook's stew lasts six times as long as a beginner's. Eating more
    of the same buff adds time, never past one whole dish's worth; another
    buff replaces it.

      hearty    stews, roasts, pies, burgers, pizza, burritos, tacos, bread:
                tire more slowly, a little endurance back
      energized stir fries, pasta, rice, omelettes, sandwiches, oatmeal:
                endurance comes back faster
      comfort   cakes, sweet pies, muffins, pancakes, ice cream, toast:
                unhappiness and boredom melt away
      calm      soups and hot drinks: stress and panic ease off
      fresh     salads and fruit salads: a bit of endurance and good mood

    Where it runs: the eating (ISEatFoodAction:complete) and the effects (once
    per game minute) run where the character's stats really live -- on this
    machine in single player, on the server in multiplayer (the same reason
    the vitamin effects moved there, see HARMONIE_VitaminChecker.lua). The
    server reads the dish's quality from its own copy of the item (it wrote
    it, K.serveQuality), so a client cannot fake a buff. The client only
    shows it (speech line, halo text, the Cooking tab).
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
function K.buffOfDish(dishId)
    local d = K.DISH_BY_ID[tostring(dishId)]
    return d and K.BUFF_OF_FAMILY[d.family] or nil
end

local function worldHours()
    local ok, h = pcall(function() return getGameTime():getWorldAgeHours() end)
    return ok and tonumber(h) or 0
end
local function nameOf(p)
    local ok, n = pcall(function() return p:getUsername() end)
    return ok and tostring(n) or "?"
end
local function authority() return not (isClient and isClient()) end

-- the buff now on a character (authority side), or nil
function K.activeBuff(player)
    local ok, md = pcall(function() return player:getModData() end)
    local b = ok and md and md.HARMONIE_CookBuff
    if type(b) ~= "table" or not K.BUFFS[b.kind] then return nil end
    if worldHours() >= (tonumber(b.untilH) or 0) then return nil end
    return b
end

-- tell the player (SP: straight to the client side; MP: a server command)
local function notify(player, what, b)
    local args = { what = what, kind = b and b.kind, dish = b and b.dish, hoursLeft = b and math.max(0, (b.untilH or 0) - worldHours()),
        level = b and b.level }
    if isServer and isServer() then
        if sendServerCommand then sendServerCommand(player, K.BUFF_NET, "buff", args) end
    elseif K.onBuffNotice then
        pcall(K.onBuffNotice, player, args)
    end
end
K.notifyBuff = notify

-- an Excellent dish was eaten (authority side)
function K.grantBuff(player, dishId, quality, cookLevel, fraction)
    if not player or quality ~= "Excellent" then return nil end
    if not K.buffsOn() then log("%s ate an Excellent %s: buffs are off in the sandbox", nameOf(player), tostring(dishId)); return nil end
    local kind = K.buffOfDish(dishId)
    if not kind then log("%s ate an Excellent %s: no buff for that dish", nameOf(player), tostring(dishId)); return nil end
    local full = K.buffHours(cookLevel)
    local add = full * math.max(0.25, math.min(1, tonumber(fraction) or 1))
    local now = worldHours()
    local md = player:getModData()
    local b = K.activeBuff(player)
    if b and b.kind == kind then
        -- more of the same: longer, never past one whole dish's worth
        b.untilH = math.min(math.max(b.untilH, now) + add, now + full)
        b.dish, b.level = dishId, cookLevel
    else
        if b then log("%s: buff %s replaced by %s", nameOf(player), b.kind, kind) end
        b = { kind = kind, dish = dishId, level = cookLevel, untilH = now + add }
        md.HARMONIE_CookBuff = b
    end
    log("%s ate an Excellent %s (cook level %s, %.0f%% of it): %s for %.1f h (until hour %.1f)",
        nameOf(player), tostring(dishId), tostring(cookLevel), (tonumber(fraction) or 1) * 100, kind, b.untilH - now, b.untilH)
    notify(player, "on", b)
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
                local nv = math.max(0, math.min(hi, v + e[2]))
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
    local ok, md = pcall(function() return player:getModData() end)
    local b = ok and md and md.HARMONIE_CookBuff
    if type(b) ~= "table" then return end
    if not K.BUFFS[b.kind] or worldHours() >= (tonumber(b.untilH) or 0) then
        md.HARMONIE_CookBuff = nil
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
if Events and Events.EveryOneMinute then Events.EveryOneMinute.Add(everyMinute) end

-- the eating, where it really happens (SP, or the MP server)
if ISEatFoodAction == nil then pcall(require, "TimedActions/ISEatFoodAction") end
if ISEatFoodAction and ISEatFoodAction.complete then
    local original_complete = ISEatFoodAction.complete
    function ISEatFoodAction:complete()
        local info
        if authority() then
            pcall(function()
                local md = self.item and self.item:getModData()
                if md and md.HARMONIE_CookQuality then
                    info = { q = md.HARMONIE_CookQuality, dish = md.HARMONIE_CookDish, level = md.HARMONIE_CookLevel, frac = self.percentage }
                end
            end)
        end
        local result = original_complete(self)
        if info then
            local ok, err = pcall(K.grantBuff, self.character, info.dish, info.q, info.level, info.frac)
            if not ok then log("granting the buff FAILED: %s", tostring(err)) end
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

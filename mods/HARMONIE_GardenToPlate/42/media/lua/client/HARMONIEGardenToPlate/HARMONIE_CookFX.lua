--[[
    HARMONIE - From Garden to Plate: the cooking tab's sounds, speech lines
    and buff notices (client, 0.13.1).

    Sounds (owner: "เสียงมินิเกมมีไหม"): this mod's own synthesized sounds
    (tools/gen_cook_sounds.py), played the way The Way To Attack's are heard:
    short UI one-shots, a working sound played again whenever the last one
    ends. Loudness is picked by file (GTPC_X_v25 .. _v150) from the guide's
    settings (Cooking sounds), 0 = off.

    Speech (owner: "เวลาเกิดอะไรขึ้น หรือมีคำอธิบาย อยากให้เปลี่ยนเป็นบทพูด ... เหมือน
    ตัวละครพูด แนะนำ หรืออุทาน"): a line is picked at random from
    IGUI_GTPC_Say_<key>_1, _2, ... (as many as the translation has).

    Buffs: the authority (SP, or the MP server -- HARMONIE_CookBuffs.lua)
    says when one starts or wears off; the character says so too.
]]--

require "HARMONIEGardenToPlate/HARMONIE_CookCore"
require "HARMONIEGardenToPlate/HARMONIE_CookBuffs"
require "HARMONIEGardenToPlate/HARMONIE_CookSoundLengths"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.CookFX = HARMONIE_GTP.CookFX or {}
local FX = HARMONIE_GTP.CookFX
local K = HARMONIE_GTP.Cook
local log = function(fmt, ...) K.log(fmt, ...) end

local function T(key, ...)
    local ok, s = pcall(getText, key, ...)
    return ok and s or key
end

-- ------------------------------------------------------------------ sound
FX.volume = FX.volume or (GTPGuide and GTPGuide.soundPct) or 100   -- percent; the guide's prefs (sound=)

function FX.play(name)
    if not name or (isServer and isServer()) then return end
    local v = tonumber(FX.volume) or 100
    if v <= 0 then return end
    local best, bestD = 100, math.huge
    for _, lvl in ipairs(HARMONIE_GTP.CookSoundLevels or { 100 }) do
        local d = math.abs(lvl - v)
        if d < bestD then best, bestD = lvl, d end
    end
    local full = "GTPC_" .. name .. (best ~= 100 and ("_v" .. best) or "")
    local sm = getSoundManager and getSoundManager()
    if sm and sm.playUISound then
        local ok, err = pcall(sm.playUISound, sm, full)
        if not ok then K.logOnce("snd:" .. full, "could not play sound %s: %s", full, tostring(err)) end
    end
    K.logOnce("sndfirst:" .. name, "first cooking sound %s (volume %d%%, repeats not logged)", name, v)
end

-- call every frame while the work goes on: plays again when the last ends
function FX.keep(state, name)
    if not name then return end
    local now = getTimestampMs and getTimestampMs() or 0
    state.fxNext = state.fxNext or {}
    if now >= (state.fxNext[name] or 0) then
        FX.play(name)
        local len = (HARMONIE_GTP.CookSoundLength or {})["GTPC_" .. name] or 400
        state.fxNext[name] = now + math.max(120, len - 30)
    end
end

-- ------------------------------------------------------------------ speech
local counts = {}
-- how many lines a key has in this language (IGUI_GTPC_Say_<key>_1..n)
local function lineCount(key)
    if counts[key] then return counts[key] end
    local n = 0
    for i = 1, 12 do
        local k = "IGUI_GTPC_Say_" .. key .. "_" .. i
        if T(k) == k then break end
        n = i
    end
    counts[key] = n
    if n == 0 then K.logOnce("noline:" .. key, "no speech lines for %s", key) end
    return n
end

local last = {}
-- a random line (never the same twice in a row), or nil
function FX.line(key, ...)
    local n = lineCount(key)
    if n == 0 then return nil end
    local i = ZombRand(n) + 1
    if n > 1 and i == last[key] then i = i % n + 1 end
    last[key] = i
    return T("IGUI_GTPC_Say_" .. key .. "_" .. i, ...)
end

-- the character says it over their head (the world, not a window)
function FX.say(player, key, ...)
    local s = FX.line(key, ...)
    if s and player and player.Say then pcall(player.Say, player, s) end
    return s
end

-- ------------------------------------------------------------------ buffs
K.myBuff = nil   -- what this client knows: { kind, dish, untilH (game hours) }

local function gameHours()
    local ok, h = pcall(function() return getGameTime():getWorldAgeHours() end)
    return ok and tonumber(h) or 0
end

-- the buff now (SP: the real one; MP: what the server last said)
function K.myBuffNow(player)
    if not (isClient and isClient()) then
        local b = player and K.activeBuff(player)
        if b then return { kind = b.kind, dish = b.dish, hoursLeft = b.untilH - gameHours() } end
        return nil
    end
    local b = K.myBuff
    if not b then return nil end
    local left = b.untilH - gameHours()
    if left <= 0 then return nil end
    return { kind = b.kind, dish = b.dish, hoursLeft = left }
end

function K.onBuffNotice(player, args)
    player = player or (getPlayer and getPlayer())
    if type(args) ~= "table" then return end
    if args.what == "on" or args.what == "now" then
        K.myBuff = { kind = args.kind, dish = args.dish, untilH = gameHours() + (tonumber(args.hoursLeft) or 0) }
    elseif args.what == "off" or args.what == "none" then
        K.myBuff = nil
    end
    log("buff notice: %s %s (%.1f h left)", tostring(args.what), tostring(args.kind), tonumber(args.hoursLeft) or 0)
    if args.what == "on" and player then
        local name = T("IGUI_GTPC_Buff_" .. tostring(args.kind))
        FX.say(player, "Buff_" .. tostring(args.kind))
        if HaloTextHelper then
            local fn = HaloTextHelper.addGoodText or HaloTextHelper.addText
            if fn then pcall(fn, player, T("IGUI_GTPC_BuffHalo", name, string.format("%.1f", tonumber(args.hoursLeft) or 0))) end
        end
        FX.play("Excellent")
    elseif args.what == "off" and player then
        FX.say(player, "BuffOff")
    end
end

if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= K.BUFF_NET or command ~= "buff" then return end
        K.onBuffNotice(getPlayer and getPlayer(), args)
    end)
end

-- MP: ask the server once what buff this character already has
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        if isClient and isClient() and sendClientCommand and getPlayer and getPlayer() then
            sendClientCommand(getPlayer(), K.BUFF_NET, "get", {})
            log("asked the server for this character's dish buff")
        end
    end)
end

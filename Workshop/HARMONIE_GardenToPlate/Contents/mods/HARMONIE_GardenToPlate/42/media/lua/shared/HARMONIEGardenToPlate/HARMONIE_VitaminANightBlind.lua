--[[
    HARMONIE - From Garden to Plate: vitamin A deficiency = night blindness
    (0.13.2). While A is Critical (and not pause-day shielded), a zombie hit
    by this character keeps part of its health: 30 percent of the damage by
    day, 50 percent at night (20:00-05:59).

    How: vanilla raises OnHitZombie BEFORE the damage is applied (the same
    order The Way To Attack's damage numbers rely on). The zombie's health is
    noted there; one tick later the difference is the real damage, and the
    share is given back with setHealth. A killed zombie stays dead.

    Where: wherever the hit is worked out -- single player here; in
    multiplayer on the server (it owns zombie health) when the event fires
    there. A multiplayer client never changes zombie health itself.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminEffects"

HARMONIE_GTP = HARMONIE_GTP or {}
local NB = {}
HARMONIE_GTP.NightBlind = NB
NB.DAY_CUT, NB.NIGHT_CUT = 0.30, 0.50
NB.pending = {}

local function log(fmt, ...) if HARMONIE_GTP.Log then HARMONIE_GTP.Log("VitA", fmt, ...) end end
local function logOnce(key, fmt, ...) if HARMONIE_GTP.LogOnce then HARMONIE_GTP.LogOnce("VitA:" .. key, "VitA", fmt, ...) end end

function NB.isNight()
    local ok, h = pcall(function() return getGameTime():getHour() end)
    h = ok and tonumber(h) or 12
    return h >= 20 or h < 6
end

function NB.cutFor(attacker)
    if not HARMONIE_GTP.Config or not HARMONIE_GTP.Config.effectsEnabled then return 0 end
    local ok, on = pcall(HARMONIE_GTP.VitEffects.IsActive, attacker, "A")
    if not ok or not on then return 0 end
    return NB.isNight() and NB.NIGHT_CUT or NB.DAY_CUT
end

function NB.onHit(zed, attacker, bodyPart, weapon)
    if isClient and isClient() then return end
    if not zed or not attacker then return end
    local okP, isP = pcall(function() return instanceof(attacker, "IsoPlayer") end)
    if not (okP and isP) then return end
    local cut = NB.cutFor(attacker)
    if cut <= 0 then return end
    local okH, before = pcall(function() return zed:getHealth() end)
    if not okH or not before then return end
    NB.pending[#NB.pending + 1] = { zed = zed, before = before, cut = cut, who = attacker }
end

function NB.tick()
    if #NB.pending == 0 then return end
    local list = NB.pending
    NB.pending = {}
    for _, p in ipairs(list) do
        pcall(function()
            local after = p.zed:getHealth()
            if p.zed:isDead() or after <= 0 then return end
            local dealt = p.before - after
            if dealt <= 0 then return end
            p.zed:setHealth(after + dealt * p.cut)
            logOnce("first:" .. tostring(p.who), "night blindness: a hit of %.3f lost %.0f%% (zombie %.3f -> %.3f)",
                dealt, p.cut * 100, after, after + dealt * p.cut)
        end)
    end
end

if Events and Events.OnHitZombie then Events.OnHitZombie.Add(NB.onHit) else logOnce("noevent", "OnHitZombie missing -- vitamin A night blindness cannot work here") end
if Events and Events.OnTick then Events.OnTick.Add(NB.tick) end
log("vitamin A night blindness ready (%s)", (isServer and isServer()) and "server" or ((isClient and isClient()) and "MP client: server decides" or "single player"))

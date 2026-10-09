--[[
    HARMONIE - From Garden to Plate: vitamin A deficiency = night blindness
    (0.13.2). While A is Critical (and not pause-day shielded), a zombie hit
    by this character keeps part of its health: 30 percent of the damage by
    day, 50 percent at night (20:00-05:59).

    How: vanilla raises OnHitZombie BEFORE the damage is applied (the same
    order The Way To Attack's damage numbers rely on). The zombie's health is
    noted there; on a later tick the difference is the real damage, and the
    share is given back with setHealth. A killed zombie stays dead.

    Where (0.13.2 MP pass -- B42 MP applies zombie hits on the server and
    pushes them to the clients, and which machine raises OnHitZombie is not
    something to bet on, so both are covered):
      * single player: all here.
      * MP server: if OnHitZombie fires there, the server measures and gives
        back itself (it owns zombie health), and notes the zombie (seenAt).
      * MP client: OnHitZombie on the hitter's own client (the event The Way
        To Attack's damage numbers already use in MP) -- the client only
        MEASURES the hit (waiting up to WAIT_TICKS for the server's damage to
        arrive) and sends { zombie online id, position, damage } to the
        server. The client never changes zombie health.
      * the server decides everything from its own data: the sender alive,
        their OWN vitamin A on the server (not the client's word), the
        zombie found by online id within REACH tiles of the sender, a sane
        damage (0 < d <= MAX_DEALT), at most RATE_PER_SEC a second. A zombie
        the server already handled itself in the last DEDUPE_MS is skipped,
        so a hit is never given back twice.
    Nothing touches ModData; no transmitModData.

    console.txt: which path runs (once), the first reduced hit per player,
    and every dropped report (once per reason and player).
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminEffects"

HARMONIE_GTP = HARMONIE_GTP or {}
local NB = HARMONIE_GTP.NightBlind or {}
HARMONIE_GTP.NightBlind = NB
NB.DAY_CUT, NB.NIGHT_CUT = 0.30, 0.50
NB.NET, NB.CMD = "HARMONIE_GTP_VitA", "hit"
NB.WAIT_TICKS = 15       -- client: ticks to wait for the server's damage to show
NB.REACH = 4             -- tiles between the hitter and the zombie
NB.MAX_DEALT = 50        -- game damage units (a hit is ~0.1-5)
NB.RATE_PER_SEC = 8
NB.DEDUPE_MS = 1500
NB.pending = {}
NB.seenAt = setmetatable({}, { __mode = "k" })   -- server: zombie -> ms its own OnHitZombie saw a hit
NB.recent = {}

local function log(fmt, ...) if HARMONIE_GTP.Log then HARMONIE_GTP.Log("VitA", fmt, ...) end end
local function logOnce(key, fmt, ...) if HARMONIE_GTP.LogOnce then HARMONIE_GTP.LogOnce("VitA:" .. key, "VitA", fmt, ...) end end

local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
local function finite(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end
local function nameOf(p)
    local n = call(p, "getUsername")
    return n and tostring(n) or "?"
end
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end
local function mpClient() return isClient and isClient() end
local function mpServer() return isServer and isServer() end

function NB.isNight()
    local ok, h = pcall(function() return getGameTime():getHour() end)
    h = ok and tonumber(h) or 12
    return h >= 20 or h < 6
end

-- the share of a hit given back for this attacker (0 = none), from the data
-- of the machine asking (the server's own copy in MP)
function NB.cutFor(attacker)
    if not HARMONIE_GTP.Config or not HARMONIE_GTP.Config.effectsEnabled then return 0 end
    local ok, on = pcall(HARMONIE_GTP.VitEffects.IsActive, attacker, "A")
    if not ok or not on then return 0 end
    return NB.isNight() and NB.NIGHT_CUT or NB.DAY_CUT
end

local function isPlayer(o)
    local ok, is = pcall(function() return instanceof(o, "IsoPlayer") end)
    return ok and is == true
end
local function isLocal(p)
    local v = call(p, "isLocalPlayer")
    if v ~= nil then return v == true end
    return getSpecificPlayer and p == getSpecificPlayer(0)
end

-- give `dealt * cut` back to a living zombie (SP / server only)
local function giveBack(zed, dealt, cut, who, how)
    if call(zed, "isDead") then return false end
    local now = finite(call(zed, "getHealth"))
    if not now or now <= 0 then return false end
    local back = dealt * cut
    local ok = pcall(function() zed:setHealth(now + back) end)
    if not ok then logOnce("setfail", "could not give health back to a zombie (setHealth failed)"); return false end
    logOnce("first:" .. how .. ":" .. nameOf(who), "night blindness (%s): %s's hit of %.3f lost %.0f%% (zombie %.3f -> %.3f) -- later hits not logged",
        how, nameOf(who), dealt, cut * 100, now, now + back)
    return true
end

function NB.onHit(zed, attacker, bodyPart, weapon)
    if not zed or not attacker or not isPlayer(attacker) then return end
    if mpClient() then
        -- only my own hits, and only while my own copy says A is short (the
        -- server checks again with its own copy)
        if not isLocal(attacker) or NB.cutFor(attacker) <= 0 then return end
        local before = finite(call(zed, "getHealth"))
        if not before then return end
        NB.pending[#NB.pending + 1] = { zed = zed, before = before, who = attacker, client = true, ticks = 0 }
        logOnce("clientpath", "night blindness: OnHitZombie fires on this MP client -- hits are measured here and sent to the server")
        return
    end
    local cut = NB.cutFor(attacker)
    if mpServer() then
        NB.seenAt[zed] = nowMs()
        logOnce("serverpath", "night blindness: OnHitZombie fires on the server -- the server measures hits itself (client reports for the same zombie are skipped)")
    end
    if cut <= 0 then return end
    local before = finite(call(zed, "getHealth"))
    if not before then return end
    NB.pending[#NB.pending + 1] = { zed = zed, before = before, cut = cut, who = attacker, ticks = 0 }
end

function NB.tick()
    if #NB.pending == 0 then return end
    local list = NB.pending
    NB.pending = {}
    for _, p in ipairs(list) do
        local ok, err = pcall(function()
            local after = finite(call(p.zed, "getHealth")) or 0
            local dead = call(p.zed, "isDead") == true or after <= 0
            local dealt = p.before - after
            if dealt <= 0 and not dead then
                -- in MP the server's damage reaches the client a little later
                p.ticks = p.ticks + 1
                if p.ticks < NB.WAIT_TICKS then NB.pending[#NB.pending + 1] = p end
                return
            end
            if dead then return end
            if p.client then
                local me = p.who
                sendClientCommand(me, NB.NET, NB.CMD, { id = call(p.zed, "getOnlineID"),
                    x = call(p.zed, "getX"), y = call(p.zed, "getY"), z = call(p.zed, "getZ"), d = dealt })
                logOnce("sent", "night blindness: sent the first measured hit (%.3f) to the server -- later ones not logged", dealt)
            else
                giveBack(p.zed, dealt, p.cut, p.who, mpServer() and "server" or "SP")
            end
        end)
        if not ok then logOnce("tickfail", "night blindness tick FAILED: %s", tostring(err)) end
    end
end

-- server: per-sender rate limit
local function allowed(player)
    local key = nameOf(player)
    local now = nowMs()
    local r = NB.recent[key]
    if not r or now - r.start >= 1000 then r = { start = now, n = 0 }; NB.recent[key] = r end
    r.n = r.n + 1
    return r.n <= NB.RATE_PER_SEC
end

local function findZombie(id, x, y, player)
    local cell = getCell and getCell()
    local list = cell and call(cell, "getZombieList")
    if not list then return nil end
    local px, py = finite(call(player, "getX")), finite(call(player, "getY"))
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z and call(z, "getOnlineID") == id then
            local zx, zy = finite(call(z, "getX")), finite(call(z, "getY"))
            if zx and px and (zx - px) ^ 2 + (zy - py) ^ 2 <= NB.REACH * NB.REACH then return z end
            return nil, "far"
        end
    end
    return nil, "gone"
end

-- server: one hit a client measured -> true when health was given back
function NB.serve(player, args)
    if not player or call(player, "isDead") or type(args) ~= "table" then return false end
    local who = nameOf(player)
    local d, id, x, y = finite(args.d), finite(args.id), finite(args.x), finite(args.y)
    if not (d and id and x and y) or d <= 0 or d > NB.MAX_DEALT then
        logOnce("bad:" .. who, "dropped a hit report from %s: bad numbers (d=%s) -- repeats not logged", who, tostring(args.d))
        return false
    end
    if not allowed(player) then
        logOnce("rate:" .. who, "dropped hit reports from %s: over %d a second -- repeats not logged", who, NB.RATE_PER_SEC)
        return false
    end
    local cut = NB.cutFor(player)
    if cut <= 0 then
        logOnce("notshort:" .. who, "dropped a hit report from %s: their vitamin A is not short on the server -- repeats not logged", who)
        return false
    end
    local zed, why = findZombie(id, x, y, player)
    if not zed then
        logOnce("nozed:" .. who .. ":" .. tostring(why), "dropped a hit report from %s: zombie %s (%s) -- repeats not logged", who, tostring(id),
            why == "far" and "too far from them" or "not found")
        return false
    end
    local seen = NB.seenAt[zed]
    if seen and nowMs() - seen < NB.DEDUPE_MS then
        logOnce("dedupe", "a client hit report was skipped: the server already handled that hit itself")
        return false
    end
    return giveBack(zed, d, cut, player, "MP client report")
end

if Events then
    if Events.OnHitZombie then Events.OnHitZombie.Add(NB.onHit) else logOnce("noevent", "OnHitZombie missing -- vitamin A night blindness cannot work here") end
    if Events.OnTick then Events.OnTick.Add(NB.tick) end
    if Events.OnClientCommand then
        Events.OnClientCommand.Add(function(module, command, player, args)
            if module ~= NB.NET then return end
            if not mpServer() then return end
            if command == NB.CMD then
                local ok, err = pcall(NB.serve, player, args)
                if not ok then logOnce("servefail", "hit report FAILED: %s", tostring(err)) end
            else
                logOnce("unknown:" .. tostring(command), "%s sent unknown command %s -- dropped", nameOf(player), tostring(command))
            end
        end)
    end
end
log("vitamin A night blindness ready (%s)", mpServer() and "server" or (mpClient() and "MP client: measures, the server decides" or "single player"))

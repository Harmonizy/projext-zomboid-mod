--============================================================================
-- HARMONIE_TheWayToAttack -- share damage numbers with nearby players (MP)
--
-- Request 2026-10-03: "ทำให้คนอื่นเห็นเลขดาเมจด้วย". The hitting player's
-- client measures the damage (HARMONIE_TWA_ZombieHP) and sends it here; the
-- server checks it and passes it to the players near the hitter, whose
-- clients show the number (TWAZombieHP.onRemote).
--
-- Kept to the multiplayer rules of mods/workflow.txt (8.7 / 8.15):
--   * nothing touches any ModData, player or global (no transmitModData)
--   * events registered at file load, server work only when isServer()
--   * the server trusts nothing: the sender must be alive, the zombie
--     position within REACH tiles of the sender, the amount a sane number;
--     at most RATE_PER_SEC numbers per player per second
--   * only players within the sandbox DamageNumberRange get it, and not the
--     sender (who already shows it); tiny payload { id, x, y, z, a, c }
--   * single player: nothing is sent at all
--============================================================================

require "HARMONIE_TWA_Config"

TWADamageShare = TWADamageShare or {}
local S = TWADamageShare

S.NET = "HARMONIE_TWA"
S.CMD = "dmgPop"
S.REACH = 6            -- tiles between the hitter and the zombie
S.MAX_AMOUNT = 100     -- game damage units (a hit is ~0.1-5)
S.RATE_PER_SEC = 8

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

-- client: send one of my hits (only in multiplayer, only when sharing is on)
function S.send(zed, amount, crit)
    if not (isClient and isClient()) or not TWAConfig.on("ShareDamageNumbers") or not TWAConfig.on("DamageNumbers") then return end
    local me = getSpecificPlayer and getSpecificPlayer(0)
    if not me or not zed then return end
    sendClientCommand(me, S.NET, S.CMD, {
        id = call(zed, "getOnlineID"),
        x = call(zed, "getX"), y = call(zed, "getY"), z = call(zed, "getZ"),
        a = amount, c = crit and true or false,
    })
end

-- server: per-sender rate limit
S.recent = S.recent or {}
local function allowed(player)
    local key = tostring(call(player, "getOnlineID") or call(player, "getUsername") or player)
    local now = getTimestampMs and getTimestampMs() or 0
    local r = S.recent[key]
    if not r or now - r.start >= 1000 then r = { start = now, n = 0 }; S.recent[key] = r end
    r.n = r.n + 1
    return r.n <= S.RATE_PER_SEC
end

-- server: check one number and pass it on -> how many players got it
function S.relay(sender, args)
    if not TWAConfig.on("ShareDamageNumbers") or not TWAConfig.on("DamageNumbers") then return 0 end
    if not sender or call(sender, "isDead") or type(args) ~= "table" then return 0 end
    local a, x, y, z = finite(args.a), finite(args.x), finite(args.y), finite(args.z)
    if not (a and x and y and z) or a <= 0 or a > S.MAX_AMOUNT then return 0 end
    local px, py, pz = finite(call(sender, "getX")), finite(call(sender, "getY")), finite(call(sender, "getZ"))
    if not (px and py and pz) then return 0 end
    if math.abs(z - pz) > 1 or (x - px) ^ 2 + (y - py) ^ 2 > S.REACH * S.REACH then return 0 end
    if not allowed(sender) then return 0 end
    local out = { id = tonumber(args.id), x = x, y = y, z = z, a = a, c = args.c == true }
    local range = TWAConfig.num("DamageNumberRange", 1)
    local online = getOnlinePlayers and getOnlinePlayers()
    local sent = 0
    for i = 0, (online and online:size() or 0) - 1 do
        local p = online:get(i)
        if p and p ~= sender then
            local qx, qy = finite(call(p, "getX")), finite(call(p, "getY"))
            if qx and qy and (qx - x) ^ 2 + (qy - y) ^ 2 <= range * range then
                sendServerCommand(p, S.NET, S.CMD, out)
                sent = sent + 1
            end
        end
    end
    return sent
end

if Events and not S.registered then
    S.registered = true
    if Events.OnClientCommand then
        Events.OnClientCommand.Add(function(module, command, player, args)
            if module == S.NET and command == S.CMD and isServer and isServer() then S.relay(player, args) end
        end)
    end
    if Events.OnServerCommand then
        Events.OnServerCommand.Add(function(module, command, args)
            if module == S.NET and command == S.CMD and TWAZombieHP and TWAZombieHP.onRemote then
                TWAZombieHP.onRemote(args)
            end
        end)
    end
end

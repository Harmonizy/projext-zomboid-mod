--============================================================================
-- HARMONIE - Perf Probe (diagnostic, 2026-10-03)
--
-- Request: "เล่นบน server แล้ว lag มาก ... หน่วงตลอดเวลา แม้แต่ตอนกด esc และมี
-- ฉัน 1 คนในเซิฟ" -- reading the code was not enough to be sure, so this
-- measures it. The file name starts with 000_ so it loads before the other
-- mods' files and sees every handler they add afterwards.
--
-- It wraps Events.<name>.Add for the frequent events: every handler added
-- later is timed (getTimestampMs around the call). The clock only has 1 ms
-- steps, but summed over thousands of calls the total is a fair estimate:
-- a handler that costs 0.3 ms reads 1 ms about one call in three. It also
-- counts sendClientCommand / sendServerCommand per module.command.
-- Every 10 s (real time) it prints to console.txt:
--   [PerfProbe client|server] frames=..  (frames = OnTick calls in 10 s)
--   top handlers by total ms:  ms  calls  event  file:line
--   network sent:  count  module.command
-- Nothing in the game changes; remove the mod when done.
--============================================================================

if HARMONIE_PerfProbe then return end
HARMONIE_PerfProbe = {}
local P = HARMONIE_PerfProbe
P.WINDOW_MS = 10000
P.TOP = 15
P.EVENTS = { "OnTick", "OnTickEvenPaused", "OnPlayerUpdate", "OnRenderTick", "OnPreUIDraw",
    "OnPostUIDraw", "OnZombieUpdate", "OnPlayerMove", "OnServerCommand", "OnClientCommand",
    "OnFETick", "EveryOneMinute", "OnObjectAdded", "OnContainerUpdate", "OnRefreshInventoryWindowContainers" }

local now = getTimestampMs or function() return 0 end
local stats, net = {}, {}
local frames, windowStart = 0, now()

local function where(fn)
    local f = getFilenameOfClosure and getFilenameOfClosure(fn) or "?"
    local l = getFirstLineOfClosure and getFirstLineOfClosure(fn) or 0
    f = tostring(f):gsub("\\", "/")
    local mod = f:match("/mods/([^/]+)/") or f:match("/workshop/content/108600/(%d+)/") or "vanilla"
    local short = f:match("([^/]+/[^/]+)$") or f
    return mod .. " " .. short .. ":" .. tostring(l)
end

local function wrapEvent(name)
    local ev = Events and Events[name]
    if type(ev) ~= "table" or not ev.Add then return end
    local add, remove = ev.Add, ev.Remove
    local wrapped = setmetatable({}, { __mode = "k" })
    ev.Add = function(fn)
        if type(fn) ~= "function" then return add(fn) end
        local key = name .. "  " .. where(fn)
        local w = function(...)
            local t0 = now()
            local a, b, c, d = fn(...)
            local s = stats[key]
            if not s then s = { ms = 0, n = 0 }; stats[key] = s end
            s.ms = s.ms + (now() - t0)
            s.n = s.n + 1
            return a, b, c, d
        end
        wrapped[fn] = w
        return add(w)
    end
    if remove then
        ev.Remove = function(fn) return remove(wrapped[fn] or fn) end
    end
end

-- the probe's own frame counter goes in through the original Add
local rawTickAdd = Events and Events.OnTick and Events.OnTick.Add
local rawPausedAdd = Events and Events.OnTickEvenPaused and Events.OnTickEvenPaused.Add
for _, name in ipairs(P.EVENTS) do pcall(wrapEvent, name) end

local function wrapSend(globalName)
    local orig = _G[globalName]
    if type(orig) ~= "function" then return end
    _G[globalName] = function(...)
        local args = { ... }
        -- sendClientCommand(player, module, command, args) or (module, command, args)
        local m, c = args[2], args[3]
        if type(args[1]) == "string" then m, c = args[1], args[2] end
        local key = globalName .. " " .. tostring(m) .. "." .. tostring(c)
        net[key] = (net[key] or 0) + 1
        return orig(...)
    end
end
wrapSend("sendClientCommand")
wrapSend("sendServerCommand")

local function side()
    if isServer and isServer() then return "server" end
    if isClient and isClient() then return "client" end
    return "singleplayer"
end

function P.report()
    local t = now()
    local secs = math.max(1, (t - windowStart) / 1000)
    local rows = {}
    for k, s in pairs(stats) do rows[#rows + 1] = { k = k, ms = s.ms, n = s.n } end
    table.sort(rows, function(a, b) return a.ms > b.ms end)
    local total = 0
    for _, r in ipairs(rows) do total = total + r.ms end
    print(string.format("[PerfProbe %s] %.0f s: frames=%d (%.1f/s), mod handlers %d ms total (%.1f ms per frame)",
        side(), secs, frames, frames / secs, total, frames > 0 and total / frames or 0))
    for i = 1, math.min(P.TOP, #rows) do
        local r = rows[i]
        if r.ms <= 0 and i > 5 then break end
        print(string.format("[PerfProbe %s]   %6d ms %8d calls  %s", side(), r.ms, r.n, r.k))
    end
    local nrows = {}
    for k, n in pairs(net) do nrows[#nrows + 1] = { k = k, n = n } end
    table.sort(nrows, function(a, b) return a.n > b.n end)
    for i = 1, math.min(10, #nrows) do
        print(string.format("[PerfProbe %s]   net %6d  %s", side(), nrows[i].n, nrows[i].k))
    end
    stats, net, frames, windowStart = {}, {}, 0, t
end

local function onFrame()
    frames = frames + 1
    if now() - windowStart >= P.WINDOW_MS then P.report() end
end
if rawTickAdd then rawTickAdd(onFrame) end
if rawPausedAdd and not (isServer and isServer()) then
    -- the pause menu in single player stops OnTick; keep reporting there
    rawPausedAdd(function() if now() - windowStart >= P.WINDOW_MS * 2 then P.report() end end)
end
print("[PerfProbe] loaded (" .. side() .. ") -- reports every 10 s; remove the mod when done")

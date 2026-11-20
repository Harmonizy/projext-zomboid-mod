--[[
    HARMONIE Hub 5: a packet meter for every mod (owner 2026-11-20: "check
    every mod for anything that sends too fast or can loop and send fast --
    players get kicked from the server").

    sendClientCommand (client) and sendServerCommand (server) are wrapped
    ONCE (the copy in each mod checks a global flag). Every call is counted
    by module/command; nothing is changed or dropped. When one module/command
    goes over WARN_PER_SEC in a second, console.txt gets
        [HARMONIE_Hub][NetMeter] client: EHR/RequestSync 30 in 1 s
    (at most once per 30 s per command), and every 10 minutes the busiest
    commands of that span, when anything went over SUMMARY_MIN. This covers
    other people's mods too, so the next kick can be traced to its sender.
]]--

HARMONIE_NetMeter = HARMONIE_NetMeter or {}
local N = HARMONIE_NetMeter
N.WARN_PER_SEC = 20
N.SUMMARY_MS = 600000
N.SUMMARY_MIN = 300

local function now() return getTimestampMs and getTimestampMs() or 0 end
local function side()
    if isServer and isServer() then return "server" end
    if isClient and isClient() then return "client" end
    return "SP"
end
local function log(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print("[HARMONIE_Hub][NetMeter] " .. (ok and s or tostring(fmt)))
end

N.win = N.win or {}
N.total = N.total or {}
N.warned = N.warned or {}
N.summaryAt = N.summaryAt or 0

function N.count(a1, a2, a3)
    local module, command
    if type(a1) == "string" then module, command = a1, a2 else module, command = a2, a3 end
    local key = tostring(module) .. "/" .. tostring(command)
    local t = now()
    local w = N.win[key]
    if not w or t - w.start >= 1000 then w = { start = t, n = 0 }; N.win[key] = w end
    w.n = w.n + 1
    N.total[key] = (N.total[key] or 0) + 1
    if w.n == N.WARN_PER_SEC and t - (N.warned[key] or -1e12) >= 30000 then
        N.warned[key] = t
        log("%s: %s sent %d times within 1 s", side(), key, w.n)
    end
    if t - N.summaryAt >= N.SUMMARY_MS then
        local list = {}
        for k, n in pairs(N.total) do list[#list + 1] = { k = k, n = n } end
        table.sort(list, function(x, y) return x.n > y.n end)
        if N.summaryAt > 0 and list[1] and list[1].n >= N.SUMMARY_MIN then
            local parts = {}
            for i = 1, math.min(5, #list) do parts[#parts + 1] = list[i].k .. " " .. list[i].n end
            log("%s: busiest in the last %d min: %s", side(), math.floor(N.SUMMARY_MS / 60000), table.concat(parts, ", "))
        end
        N.summaryAt = t
        N.total = {}
    end
end

if not HARMONIE_NetMeterInstalled then
    HARMONIE_NetMeterInstalled = true
    local wrapped = {}
    if type(sendClientCommand) == "function" then
        local orig = sendClientCommand
        sendClientCommand = function(a1, a2, a3, a4)
            pcall(N.count, a1, a2, a3)
            return orig(a1, a2, a3, a4)
        end
        wrapped[#wrapped + 1] = "sendClientCommand"
    end
    if type(sendServerCommand) == "function" then
        local orig = sendServerCommand
        sendServerCommand = function(a1, a2, a3, a4)
            pcall(N.count, a1, a2, a3)
            return orig(a1, a2, a3, a4)
        end
        wrapped[#wrapped + 1] = "sendServerCommand"
    end
    log("%s: counting %s (warns over %d of one command a second)", side(), #wrapped > 0 and table.concat(wrapped, " + ") or "NOTHING (functions missing)", N.WARN_PER_SEC)
end

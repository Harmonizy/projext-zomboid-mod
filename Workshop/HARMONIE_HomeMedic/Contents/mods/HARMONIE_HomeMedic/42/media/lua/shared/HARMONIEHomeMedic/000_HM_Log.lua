--[[
    HARMONIE - Home Medic (its own HM code): console.txt log.
    Every line starts with "[HARMONIE_HM][tag][SP|client|server]" -- search
    console.txt for "[HARMONIE_HM]" in a bug report. Named 000_ so it loads
    before the other HARMONIEHomeMedic files; they call HMLog at run time.
    (EHR and TOC, bundled in this mod, keep their own "[EHR" / "[TOC" lines.)

    HMLog(tag, fmt, ...)           always prints
    HMLogOnce(key, tag, fmt, ...)  only the first time for that key (for
                                    things that repeat every tick or frame)
    HMLogErr(tag, what, ok, err)   prints when a pcall failed, returns ok
]]--

local function side()
    if isServer and isServer() then return "server" end
    if isClient and isClient() then return "client" end
    return "SP"
end

function HMLog(tag, fmt, ...)
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    if not ok then
        local parts = { tostring(fmt) }
        for _, v in ipairs({ ... }) do parts[#parts + 1] = tostring(v) end
        msg = table.concat(parts, " ")
    end
    print("[HARMONIE_HM][" .. tostring(tag) .. "][" .. side() .. "] " .. msg)
end

HMLogSeen = HMLogSeen or {}
function HMLogOnce(key, tag, fmt, ...)
    if HMLogSeen[key] then return end
    HMLogSeen[key] = true
    HMLog(tag, fmt, ...)
end

function HMLogErr(tag, what, ok, err)
    if not ok then HMLog(tag, "%s FAILED: %s", tostring(what), tostring(err)) end
    return ok
end

-- an item's full type for log lines (never errors)
function HMLogType(it)
    if not it then return "nil" end
    local ok, t = pcall(function() return it:getFullType() end)
    if ok and t then return tostring(t) end
    return "?"
end

-- a player's name for log lines
function HMLogName(p)
    if not p then return "nil" end
    local ok, n = pcall(function() return p:getUsername() end)
    if ok and n and n ~= "" then return tostring(n) end
    return "?"
end

-- Logs each call of the named methods (user actions in our windows):
-- "Window.method(arg1, arg2)". Plain values only; tables/objects show as
-- their type. Call-through: the method itself is unchanged.
local function short(v)
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" or t == "nil" then return tostring(v) end
    if t == "table" and v.id then return "{" .. tostring(v.id) .. "}" end
    return t
end
function HMLogMethods(cls, tag, names)
    if not cls then return end
    cls.__twaLoggedMethods = cls.__twaLoggedMethods or {}
    for _, m in ipairs(names) do
        local orig = cls[m]
        if orig and not cls.__twaLoggedMethods[m] then
            cls.__twaLoggedMethods[m] = true
            cls[m] = function(self, ...)
                local parts = {}
                local args = { ... }
                for i = 1, select("#", ...) do parts[#parts + 1] = short(args[i]) end
                HMLog(tag, "%s(%s)", m, table.concat(parts, ", "))
                return orig(self, ...)
            end
        end
    end
end

HMLog("Log", "Home Medic log ready")

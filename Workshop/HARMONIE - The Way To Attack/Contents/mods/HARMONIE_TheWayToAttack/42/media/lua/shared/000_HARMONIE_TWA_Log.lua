--[[
    HARMONIE - The Way To Attack: console.txt log.
    Every line starts with "[HARMONIE_TWA][tag][SP|client|server]" -- search
    console.txt for "[HARMONIE_TWA]" in a bug report. Named 000_ so it loads
    before every other shared file; the other files call TWALog at run time.

    TWALog(tag, fmt, ...)           always prints
    TWALogOnce(key, tag, fmt, ...)  only the first time for that key (for
                                    things that repeat every tick or frame)
    TWALogErr(tag, what, ok, err)   prints when a pcall failed, returns ok
]]--

local function side()
    if isServer and isServer() then return "server" end
    if isClient and isClient() then return "client" end
    return "SP"
end

function TWALog(tag, fmt, ...)
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    if not ok then
        local parts = { tostring(fmt) }
        for _, v in ipairs({ ... }) do parts[#parts + 1] = tostring(v) end
        msg = table.concat(parts, " ")
    end
    print("[HARMONIE_TWA][" .. tostring(tag) .. "][" .. side() .. "] " .. msg)
end

TWALogSeen = TWALogSeen or {}
function TWALogOnce(key, tag, fmt, ...)
    if TWALogSeen[key] then return end
    TWALogSeen[key] = true
    TWALog(tag, fmt, ...)
end

function TWALogErr(tag, what, ok, err)
    if not ok then TWALog(tag, "%s FAILED: %s", tostring(what), tostring(err)) end
    return ok
end

-- an item's full type for log lines (never errors)
function TWALogType(it)
    if not it then return "nil" end
    local ok, t = pcall(function() return it:getFullType() end)
    if ok and t then return tostring(t) end
    return "?"
end

-- a player's name for log lines
function TWALogName(p)
    if not p then return "nil" end
    local ok, n = pcall(function() return p:getUsername() end)
    if ok and n and n ~= "" then return tostring(n) end
    return "?"
end

-- Logs a timed action's life: start, stop (cancelled), perform (client
-- side done), complete (server / SP: did it really happen?) and the first
-- time isValid turns false (it runs every tick, so only once per action).
-- Call-through wrappers: the action's own code is unchanged.
local function describe(self)
    local what = self.recipeId or (self.recipe and self.recipe.id) or self.procId or (self.proc and self.proc.id)
    return TWALogName(self.character) .. ", " .. tostring(what)
end
function TWALogAction(cls, name)
    if not cls or cls.__twaLogged then return end
    cls.__twaLogged = true
    for _, m in ipairs({ "start", "stop", "perform" }) do
        local orig = cls[m]
        if orig then
            cls[m] = function(self, ...)
                TWALog("Action", "%s %s (%s)", name, m, describe(self))
                return orig(self, ...)
            end
        end
    end
    local complete = cls.complete
    if complete then
        cls.complete = function(self, ...)
            local ok, r = pcall(complete, self, ...)
            if not ok then
                TWALog("Action", "%s complete ERROR (%s): %s", name, describe(self), tostring(r))
                error(r, 0)
            end
            TWALog("Action", "%s complete -> %s (%s)", name, r == false and "REFUSED (nothing changed)" or "done", describe(self))
            return r
        end
    end
    local isValid = cls.isValid
    if isValid then
        cls.isValid = function(self, ...)
            local r = isValid(self, ...)
            if not r and not self.__twaInvalidLogged then
                self.__twaInvalidLogged = true
                TWALog("Action", "%s no longer valid -- the game will stop it (%s)", name, describe(self))
            end
            return r
        end
    end
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
function TWALogMethods(cls, tag, names)
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
                TWALog(tag, "%s(%s)", m, table.concat(parts, ", "))
                return orig(self, ...)
            end
        end
    end
end

TWALog("Log", "The Way To Attack log ready")

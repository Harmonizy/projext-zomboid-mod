--[[
    HARMONIE - How to Survive : illnesses that make life hard, not end it

    Owner, 2026-10-12: "อะไรที่ทำให้ตาย ปรับให้หมดเลย ฉันอยากให้โรคมีผลแค่ทำให้
    ผู้เล่นใช้ชีวิตลำบากพอ".

    Sandbox HomeMedic.LethalConditions (default false): when off, nothing of
    this mod kills -- no disease, sepsis, hypothermia / heat stroke, blood
    loss (cardiac arrest), overdose, epinephrine or gene-therapy roll.
    Instead the character COLLAPSES: overall health is held at
    HomeMedic.NonLethalHealthFloor (default 15 of 100), endurance drops to
    nothing and tiredness jumps up -- the illness keeps every other effect
    until it is treated.

      EHR.Lethal.allowed()             -> true when the sandbox lets it kill
      EHR.Lethal.floor()               -> lowest overall health our code may cause
      EHR.Lethal.spare(player, cause)  -> true = the death was prevented
                                          (call it where the kill would happen)
      EHR.Lethal.clampHealth(player, target) -> the target, raised to the floor

    Safety net (server in MP, the game itself in SP, once a second): while
    the character is ill (an active illness, food sickness, poison or low
    blood) and NOT carrying the zombie infection, a SLOW slide under the
    floor is stopped there. A sudden drop (a fight) is left alone, and the
    zombie infection (Knox, vanilla) still kills as in the base game.
]]--

EHR = EHR or {}
EHR.Lethal = EHR.Lethal or {}
local N = EHR.Lethal

N.DEFAULT_FLOOR = 15
N.SUDDEN_DROP = 4          -- overall health lost in one second that counts as a fight
N.INTERVAL_MS = 1000

local function log(fmt, ...)
    if HMLog then HMLog("NonLethal", fmt, ...) else print("[HARMONIE_HM][NonLethal] " .. string.format(fmt, ...)) end
end
local function logOnce(key, fmt, ...)
    if HMLogOnce then HMLogOnce(key, "NonLethal", fmt, ...) else log(fmt, ...) end
end
local function nameOf(p)
    if HMLogName then return HMLogName(p) end
    local ok, n = pcall(function() return p:getUsername() end)
    return ok and tostring(n) or "?"
end

local function sandbox()
    return SandboxVars and SandboxVars.HomeMedic or nil
end

function N.allowed()
    local sv = sandbox()
    return sv ~= nil and sv.LethalConditions == true
end

function N.floor()
    if N.allowed() then return 0 end
    local sv = sandbox()
    local f = sv and tonumber(sv.NonLethalHealthFloor) or N.DEFAULT_FLOOR
    return math.max(1, math.min(60, f))
end

local function overall(player)
    local ok, v = pcall(function() return player:getBodyDamage():getOverallBodyHealth() end)
    return ok and tonumber(v) or nil
end

local function setOverall(player, v)
    pcall(function() player:getBodyDamage():setOverallBodyHealth(v) end)
end

-- what a collapse costs instead of the life
local function collapse(player)
    if not CharacterStat then return end
    pcall(function()
        local st = player:getStats()
        if CharacterStat.ENDURANCE then st:set(CharacterStat.ENDURANCE, 0) end
        if CharacterStat.FATIGUE and (tonumber(st:get(CharacterStat.FATIGUE)) or 0) < 0.8 then st:set(CharacterStat.FATIGUE, 0.8) end
    end)
end

function N.clampHealth(player, target)
    local f = N.floor()
    target = tonumber(target) or f
    if target < f then return f end
    return target
end

-- the kill sites call this first; true = do NOT kill
N.lastSpare = N.lastSpare or {}
function N.spare(player, cause)
    if not player or N.allowed() then return false end
    local f = N.floor()
    local cur = overall(player)
    if cur == nil or cur < f then setOverall(player, f) end
    pcall(function() if player:getHealth() < 0.05 then player:setHealth(0.05) end end)
    collapse(player)
    local who = nameOf(player)
    local now = getTimestampMs and getTimestampMs() or 0
    local key = who .. "|" .. tostring(cause)
    -- console.txt: once a minute per cause and player (the kill sites can run every tick)
    if not N.lastSpare[key] or now - N.lastSpare[key] > 60000 then
        N.lastSpare[key] = now
        print("[EHR DEATH PREVENTED] Player: " .. who .. " | Cause: " .. tostring(cause) .. " | health held at " .. tostring(f))
        if player.Say and player.isLocalPlayer and player:isLocalPlayer() then pcall(function() player:Say("*collapses*") end) end
    end
    return true
end

-- ------------------------------------------------------------- safety net
local function isZombieInfected(player)
    local ok, v = pcall(function() return player:getBodyDamage():IsInfected() end)
    return ok and v == true
end

local function isIll(player)
    local md = player.getModData and player:getModData()
    if md then
        local d = md.EHR_Disease and md.EHR_Disease.active
        if type(d) == "table" and next(d) ~= nil then return true end
        local b = md.EHR_Blood
        if type(b) == "table" and tonumber(b.maxVolume) and tonumber(b.currentVolume)
                and b.currentVolume < b.maxVolume * 0.6 then return true end
        if type(md.EHR_Sepsis) == "table" and (tonumber(md.EHR_Sepsis.stage) or 0) > 0 then return true end
    end
    if CharacterStat then
        local ok, ill = pcall(function()
            local st = player:getStats()
            local s = CharacterStat.FOOD_SICKNESS and tonumber(st:get(CharacterStat.FOOD_SICKNESS)) or 0
            local p = CharacterStat.POISON and tonumber(st:get(CharacterStat.POISON)) or 0
            return s > 0.05 or p > 0.05
        end)
        if ok and ill then return true end
    end
    return false
end

N.seen = N.seen or {}
function N.guard(player)
    if not player or N.allowed() then return end
    if player.isDead and player:isDead() then return end
    local who = nameOf(player)
    local cur = overall(player)
    if not cur then return end
    local last = N.seen[who]
    N.seen[who] = cur
    local f = N.floor()
    if cur >= f or not last then return end
    if last - cur > N.SUDDEN_DROP then
        logOnce("sudden:" .. who, "%s: health fell fast (%.1f -> %.1f) -- a fight, not an illness: left alone", who, last, cur)
        return
    end
    if isZombieInfected(player) then
        logOnce("zinf:" .. who, "%s: carries the zombie infection -- it still kills as in the base game", who)
        return
    end
    if not isIll(player) then return end
    setOverall(player, f)
    N.seen[who] = f
    collapse(player)
    logOnce("held:" .. who, "%s: illness took health under %d -- held there (sandbox LethalConditions is off)", who, f)
end

local nextAt = 0
function N.onTick()
    local now = getTimestampMs and getTimestampMs() or 0
    if now < nextAt then return end
    nextAt = now + N.INTERVAL_MS
    if isClient and isClient() then return end   -- the server owns health in MP
    if isServer and isServer() then
        local online = getOnlinePlayers and getOnlinePlayers()
        for i = 0, (online and online:size() or 0) - 1 do
            local ok, err = pcall(N.guard, online:get(i))
            if not ok then logOnce("guarderr", "guard failed: %s", tostring(err)) end
        end
        return
    end
    local count = getNumActivePlayers and getNumActivePlayers() or 1
    for i = 0, count - 1 do
        local p = getSpecificPlayer and getSpecificPlayer(i)
        if p then
            local ok, err = pcall(N.guard, p)
            if not ok then logOnce("guarderr", "guard failed: %s", tostring(err)) end
        end
    end
end

if Events and Events.OnTick and not N.registered then
    N.registered = true
    Events.OnTick.Add(N.onTick)
end
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        log("illnesses can kill: %s (health floor %d)", tostring(N.allowed()), N.floor())
    end)
end

return N

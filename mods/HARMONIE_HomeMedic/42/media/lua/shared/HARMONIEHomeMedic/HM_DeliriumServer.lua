--[[
    HARMONIE - How to Survive : delirium starts on the SERVER in multiplayer

    Owner, 2026-11-11: "delirium ต้องรักษาด้วยอะไร ... ทำไมกินยาแล้วไม่ขึ้น".
    EHR's delirium trigger (12 game hours at >= 98% stress) lives in
    client/ExtensiveHealth/EHR_Delirium.lua. In MP that file runs only on the
    patient's own game, so the illness was written into the client's copy of
    the modData: the server never had it, so
      * Antipsychotics (taken through the server) found nothing to treat --
        no course, no TREATING, never cured;
      * the server's next sync replaced the client's EHR_Disease and the
        illness could vanish by itself;
      * the server-side sign effects (HM_SignEffects) never saw it.
    Here the same rule runs where EHR's illnesses live: a dedicated / hosting
    server, for every online player. The client's own trigger is off on an MP
    client (EHR_Delirium.UpdateStressTrigger), single player is unchanged.
    The episodes (sounds, lines, impulses) stay on the client: they read the
    synced illness.
]]--

HM_DeliriumServer = HM_DeliriumServer or {}
local DS = HM_DeliriumServer
DS.STRESS_THRESHOLD = 0.98
DS.HOURS_AT_MAX_STRESS = 12
DS.CHECK_MS = 5000

local function log(fmt, ...) if HMLog then HMLog("Delirium", fmt, ...) end end
local function nameOf(p) return HMLogName and HMLogName(p) or "?" end
local function hours() return getGameTime and getGameTime():getWorldAgeHours() or 0 end
local function nowMs()
    if getTimestampMs then
        local ok, v = pcall(getTimestampMs)
        if ok and tonumber(v) then return tonumber(v) end
    end
    return (os and os.time and os.time() or 0) * 1000
end

local function stress(p)
    local st = p and p.getStats and p:getStats()
    if not st or not CharacterStat or not CharacterStat.STRESS then return 0 end
    local ok, v = pcall(function() return st:get(CharacterStat.STRESS) end)
    return ok and tonumber(v) or 0
end

local function hasDelirium(p)
    local md = p:getModData()
    local d = md and md.EHR_Disease
    return type(d) == "table" and type(d.active) == "table" and type(d.active.delirium) == "table"
end

-- the same fields EHR_Delirium.Contract writes
function DS.contract(p, now)
    if not (EHR and EHR.Disease and EHR.Disease.Contract) then
        log("EHR.Disease.Contract missing -- %s cannot get delirium", nameOf(p)); return false
    end
    pcall(EHR.Disease.Contract, p, "delirium")
    local md = p:getModData()
    local d = md.EHR_Disease and md.EHR_Disease.active and md.EHR_Disease.active.delirium
    if type(d) ~= "table" then
        log("%s: delirium not contracted (sandbox off or no disease data)", nameOf(p)); return false
    end
    d.startTime, d.incubationEnd, d.peakTime, d.endTime = now, now, now, now + 999999
    d.stage, d.stageCount, d.progress = 1, 1, 0
    d.severity = tonumber(d.severity) or 0.85
    d.permanent, d.noCure, d.mental = true, false, true
    md.EHR_Delirium = md.EHR_Delirium or {}
    md.EHR_Delirium.highStressSince = nil
    md.EHR_Delirium.triggeredAt = now
    md.EHR_Delirium.nextEpisodeHour = nil
    md.EHR_Delirium.nextEpisodeAntipsychoticActive = nil
    if EHR.SafeTransmitModData then pcall(EHR.SafeTransmitModData, p) end
    log("%s: delirium started on the server (%d game hours at maximum stress) -- treated with Antipsychotics, 8 doses every 12 h",
        nameOf(p), DS.HOURS_AT_MAX_STRESS)
    return true
end

function DS.checkPlayer(p, now)
    if not p or (p.isDead and p:isDead()) then return end
    local md = p:getModData()
    if not md then return end
    md.HM_DeliriumServer = type(md.HM_DeliriumServer) == "table" and md.HM_DeliriumServer or {}
    local s = md.HM_DeliriumServer
    if hasDelirium(p) then s.since = nil; return end
    if stress(p) >= DS.STRESS_THRESHOLD then
        if not s.since then
            s.since = now
            log("%s: stress at maximum -- delirium in %d game hours if it stays there", nameOf(p), DS.HOURS_AT_MAX_STRESS)
        elseif now - s.since >= DS.HOURS_AT_MAX_STRESS then
            s.since = nil
            DS.contract(p, now)
        end
    elseif s.since then
        log("%s: stress fell after %.1f game hours at maximum -- delirium clock reset", nameOf(p), now - s.since)
        s.since = nil
    end
end

local last = 0
function DS.tick()
    if not (isServer and isServer()) then return end
    local ms = nowMs()
    if ms - last < DS.CHECK_MS then return end
    last = ms
    if not getOnlinePlayers then return end
    local online = getOnlinePlayers()
    local now = hours()
    for i = 0, online:size() - 1 do
        local ok, err = pcall(DS.checkPlayer, online:get(i), now)
        if not ok and HMLogOnce then HMLogOnce("deliriumsrv", "Delirium", "server check FAILED: %s", tostring(err)) end
    end
end

if Events and Events.OnTick then Events.OnTick.Add(DS.tick) end
if Events and Events.OnServerStarted then
    Events.OnServerStarted.Add(function() log("server delirium trigger ready (MP: %d h at >= %d%% stress)", DS.HOURS_AT_MAX_STRESS, math.floor(DS.STRESS_THRESHOLD * 100)) end)
end

return DS

--[[
    HARMONIE - Home Medic : treatment rules around surgery (shared; acts
    only where EHR's medicine is authoritative -- the server in MP, the
    game in single player)

    * treat(patient, disease, hours, operation)
        A successful operation gives the disease EHR's "treating" state: an
        entry in EHR_Medication.activeTreatments without a dose course, so
        EHR's own medication loop stops it getting worse and cures it when
        the hours are up (EHR.Medication.Update -> EHR.Disease.Cure /
        CureModuleDisease). Shows as TREATING in the medical window.
    * Awaiting surgery (hold)
        For a disease in HM_Surgery.SURGICAL, taking its MEDICINE no longer
        cures it (owner, 2026-10-09): as soon as a medicine course for it
        starts, the course is taken off and the disease is put on hold --
        its clock is frozen every game minute so the stage cannot rise --
        and the patient is told it needs surgery. The operation's treatment
        then releases the hold (TREATING).
]]--

require "HARMONIEHomeMedic/Surgery/HM_Surgery"

local S = HM_Surgery
S.Rules = S.Rules or {}
local R = S.Rules

local function hours() return getGameTime and getGameTime():getWorldAgeHours() or 0 end
local function authoritative() return (isServer and isServer()) or not (isClient and isClient()) end
local function sync(player)
    if EHR and EHR.SafeTransmitModData then pcall(EHR.SafeTransmitModData, player) end
end

function R.hold(player, id)
    local e = S.diseaseEntry(player, id)
    if not e then return false end
    local now = hours()
    e.harmonieHold = e.harmonieHold or now
    e.harmonieHoldAt = now
    return true
end

function R.release(player, id)
    local e = S.diseaseEntry(player, id)
    if not e then return end
    e.harmonieHold = nil
    e.harmonieHoldAt = nil
end

function R.treat(player, id, treatHours, sid)
    local M = EHR and EHR.Medication
    if not M or not M.GetMedicationData then return false end
    local md = M.GetMedicationData(player)
    if not md then return false end
    md.activeTreatments = md.activeTreatments or {}
    local now = hours()
    local cur = md.activeTreatments[id]
    -- keep a running treatment that already ends sooner
    if type(cur) == "table" and cur.source == S.TREATMENT_SOURCE and tonumber(cur.startTime) and tonumber(cur.cureTimeHours)
            and (cur.startTime + cur.cureTimeHours - now) <= treatHours then
        R.release(player, id)
        return true
    end
    md.activeTreatments[id] = {
        tier = 3, startTime = now, cureTimeHours = treatHours,
        medicationName = sid, source = S.TREATMENT_SOURCE, surgery = sid, diseaseId = id,
    }
    R.release(player, id)
    return true
end

-- Before EHR checks its courses: a medicine course on a disease that needs
-- surgery becomes a hold at once instead of a cure.
function R.checkCourses(player)
    if not player or not authoritative() then return end
    local M = EHR and EHR.Medication
    local md = player.getModData and player:getModData()
    local med = md and md.EHR_Medication
    if not M or not med or type(med.activeTreatments) ~= "table" then return end
    local now = hours()
    local changed = false
    for id, t in pairs(med.activeTreatments) do
        if type(t) == "table" and t.source ~= S.TREATMENT_SOURCE and S.needsSurgery(player, id) then
            do
                med.activeTreatments[id] = nil
                if R.hold(player, id) then
                    changed = true
                    if HMLog then HMLog("Surgery", "%s: medicine for %s -> awaiting surgery", HMLogName and HMLogName(player) or "?", tostring(id)) end
                    if EHR.Locale and EHR.Locale.Say then
                        pcall(EHR.Locale.Say, player, S.T("Say_Held", "The medicine held it back... but this needs surgery now."))
                    end
                end
            end
        end
    end
    if changed then sync(player) end
end

-- Keep held diseases where they are (called every game minute).
local SHIFT = { "startTime", "endTime", "peakTime", "incubationEnd", "stageStartTime", "lastStageTime" }
function R.freeze(player)
    local md = player and player.getModData and player:getModData()
    if not md then return end
    local now = hours()
    local function shift(e, fields)
        local last = tonumber(e.harmonieHoldAt) or now
        local d = now - last
        e.harmonieHoldAt = now
        if d <= 0 or d > 48 then return end
        for _, f in ipairs(fields) do
            if tonumber(e[f]) then e[f] = e[f] + d end
        end
    end
    local active = md.EHR_Disease and md.EHR_Disease.active
    if type(active) == "table" then
        for _, e in pairs(active) do
            if type(e) == "table" and e.harmonieHold then shift(e, SHIFT) end
        end
    end
    local sep = md.EHR_Sepsis
    if type(sep) == "table" and sep.harmonieHold then
        if (tonumber(sep.stage) or 0) <= 0 then sep.harmonieHold, sep.harmonieHoldAt = nil, nil
        else shift(sep, { "stageStartTime", "lastHealthDamageHour" }) end
    end
end

local function eachPlayer(fn)
    if isServer and isServer() then
        local online = getOnlinePlayers and getOnlinePlayers()
        if online then for i = 0, online:size() - 1 do fn(online:get(i)) end end
    else
        for i = 0, 3 do
            local p = getSpecificPlayer and getSpecificPlayer(i)
            if p then fn(p) end
        end
    end
end

function R.everyMinute()
    if not authoritative() then return end
    eachPlayer(function(p) if p and not p:isDead() then R.freeze(p) end end)
end

function R.install()
    if R.installed or not (EHR and EHR.Medication and EHR.Medication.Update) then return end
    R.installed = true
    local orig = EHR.Medication.Update
    EHR.Medication.Update = function(player, ...)
        pcall(R.checkCourses, player)
        return orig(player, ...)
    end
end

R.install()
if Events then
    if Events.OnGameStart then Events.OnGameStart.Add(R.install) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(R.install) end
    if Events.EveryOneMinute and not R.minuteHooked then
        R.minuteHooked = true
        Events.EveryOneMinute.Add(R.everyMinute)
    end
end

return R

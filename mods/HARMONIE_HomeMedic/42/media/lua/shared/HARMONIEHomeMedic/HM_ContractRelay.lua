--[[
    HARMONIE - How to Survive : illnesses a CLIENT detects are started by the server

    Owner, 2026-11-11: "ปัญหา delirium จะเกิดขึ้นกับโรคอื่นๆไหม". The delirium bug
    (0.33.8) was an illness contracted on an MP client: it lived only in that
    client's copy of the modData, the server never had it, medicine treated
    nothing and the next sync wiped it. Audit of every place that contracts an
    illness:
      * server-side or guarded already: EHR_Disease food / environment /
        corpse sickness / wound infection / sepsis / concussion (the client
        nominates, the server rolls) / painkiller addiction / AHTR (the MP
        transfusion runs on the server) / cellulitis from stitching (MP sends
        StitchCellulitisRisk) / body temperature;
      * NOT guarded: insomnia (EHR.Insomnia.Contract, from OnPlayerUpdate /
        OnTick) and hyperkeratotic scabies (EHR.HyperkeratoticScabies.Start,
        sitting on the ground). Both also run on the server, but if the
        server does not see the cause (sitting state, sleep) only the client
        had the illness.
    On an MP client those two now send a request instead of writing a local
    copy; the server (where EHR is authoritative) starts the illness with the
    same function, for the sender only, at most once per RELAY_CD_MS per
    illness and player, and syncs it back. Single player and the server's own
    detection are unchanged.
]]--

HM_ContractRelay = HM_ContractRelay or {}
local R = HM_ContractRelay
R.MODULE = "HARMONIE_HM_Contract"
R.RELAY_CD_MS = 60 * 1000

local function log(fmt, ...) if HMLog then HMLog("ContractRelay", fmt, ...) end end
local function logOnce(key, fmt, ...) if HMLogOnce then HMLogOnce("relay:" .. key, "ContractRelay", fmt, ...) end end
local function nameOf(p) return HMLogName and HMLogName(p) or "?" end
local function nowMs()
    if getTimestampMs then
        local ok, v = pcall(getTimestampMs)
        if ok and tonumber(v) then return tonumber(v) end
    end
    return (os and os.time and os.time() or 0) * 1000
end
local function pureClient() return isClient and isClient() and not (isServer and isServer()) end

local function hasIllness(p, id)
    local md = p and p.getModData and p:getModData()
    local d = md and md.EHR_Disease
    return type(d) == "table" and type(d.active) == "table" and type(d.active[id]) == "table"
end

-- illness id -> how the server starts it
R.START = {
    insomnia = function(p, source)
        if EHR and EHR.Insomnia and EHR.Insomnia.Contract then return R.original.insomnia(p, source) end
    end,
    hyperkeratotic_scabies = function(p, source)
        if EHR and EHR.HyperkeratoticScabies and EHR.HyperkeratoticScabies.Start then return R.original.scabies(p, source) end
    end,
}
R.original = R.original or {}

-- ------------------------------------------------------------- client
local sent = {}
local function request(p, id, source)
    if not p or (p.isLocalPlayer and not p:isLocalPlayer()) then return false end
    if hasIllness(p, id) then return false end
    local now = nowMs()
    if sent[id] and now - sent[id] < R.RELAY_CD_MS then return false end
    sent[id] = now
    sendClientCommand(p, R.MODULE, "Request", { id = id, source = tostring(source or "client") })
    log("%s detected here (%s) -- asked the server to start it (an MP client never writes an illness itself)",
        id, tostring(source or "client"))
    return false
end

function R.installClient()
    if R.clientInstalled or not pureClient() then return end
    local I = EHR and EHR.Insomnia
    local Sc = EHR and EHR.HyperkeratoticScabies
    if I and type(I.Contract) == "function" then
        R.original.insomnia = I.Contract
        I.Contract = function(p, source) return request(p, "insomnia", source) end
    end
    if Sc and type(Sc.Start) == "function" then
        R.original.scabies = Sc.Start
        Sc.Start = function(p, source) return request(p, "hyperkeratotic_scabies", source) end
    end
    R.clientInstalled = true
    log("MP client: insomnia %s, scabies %s now ask the server to start them",
        R.original.insomnia and "relayed" or "MISSING", R.original.scabies and "relayed" or "MISSING")
end

-- ------------------------------------------------------------- server
local last = {}
function R.serverRequest(p, args)
    args = type(args) == "table" and args or {}
    local id = tostring(args.id or "")
    local start = R.START[id]
    if not start then
        logOnce("bad:" .. id, "%s asked to start '%s' -- not a relayed illness, dropped", nameOf(p), id); return
    end
    if not R.original.insomnia and EHR and EHR.Insomnia then R.original.insomnia = EHR.Insomnia.Contract end
    if not R.original.scabies and EHR and EHR.HyperkeratoticScabies then R.original.scabies = EHR.HyperkeratoticScabies.Start end
    if not p or (p.isDead and p:isDead()) then return end
    if hasIllness(p, id) then return end
    local key = nameOf(p) .. ":" .. id
    local now = nowMs()
    if last[key] and now - last[key] < R.RELAY_CD_MS then
        logOnce("cd:" .. key, "%s asked for %s again within a minute -- dropped (logged once)", nameOf(p), id); return
    end
    last[key] = now
    local ok, err = pcall(start, p, "client:" .. tostring(args.source or "?"))
    if not ok then log("%s: starting %s FAILED: %s", nameOf(p), id, tostring(err)); return end
    if hasIllness(p, id) then
        if EHR and EHR.SafeTransmitModData then pcall(EHR.SafeTransmitModData, p) end
        log("%s: %s started on the server from the client's detection (%s)", nameOf(p), id, tostring(args.source))
    else
        log("%s: %s requested but not started (sandbox off or the server's own checks said no)", nameOf(p), id)
    end
end

if Events then
    if Events.OnGameStart then Events.OnGameStart.Add(R.installClient) end
    if Events.OnClientCommand then
        Events.OnClientCommand.Add(function(module, command, player, args)
            if module ~= R.MODULE then return end
            if command == "Request" then R.serverRequest(player, args)
            else logOnce("cmd:" .. tostring(command), "unknown command %s from %s", tostring(command), nameOf(player)) end
        end)
    end
end

return R

-- Complete EHR snapshots must distinguish an absent section from a partial
-- update. Lua nil values are omitted by the network table serializer.
EHR = EHR or {}
EHR.MedicalStateSync = EHR.MedicalStateSync or {}

local fields = {
    EHR_Sepsis = { "EHR_Sepsis_Initialized" },
    EHR_Disease = { "EHR_Disease_Initialized" },
    EHR_Blood = { "EHR_Blood_Initialized" },
    EHR_WoundInfection = { "EHR_WoundInfection_V2_Initialized", "EHR_WoundInfection_V2_Migrated" },
    EHR_WoundInfections = { "EHR_WoundInfections_Initialized" },
    EHR_Medication = { "EHR_Medication_Initialized" },
    EHR_MedicalJournal = false,
    EHR_Temperature = {},
    EHR_KnownDiseases = false,
    EHR_KnoxHeraldRead = false,
    EHR_KnoxKnowledgeSource = false,
    EHR_CorpseSickness = {},
    EHR_KnoxCure = {},
    EHR_Immunity = {},
    EHR_OfflineProgression = {},
}

-- HARMONIE 0.24.0 (server lag, 2026-10-03): the periodic snapshot went to
-- every player several times every 10 s, the 100-entry medical journal
-- included each time. A periodic Build (opts.periodic) now leaves out the
-- sections that only change on an event (journal, known diseases) when
-- they are the same as the last packet this player got; event syncs still
-- send everything. Left-out sections are not in EHR_ClearedFields, so the
-- client keeps its copy.
local RARE = { EHR_MedicalJournal = true, EHR_KnownDiseases = true }
local lastSig = setmetatable({}, { __mode = "k" })

local function signature(key, v)
    if type(v) ~= "table" then return tostring(v) end
    if key == "EHR_MedicalJournal" then
        local e, t = v.entries, v.treatments
        return table.concat({ tostring(v.lastUpdated), type(e) == "table" and #e or 0,
            type(t) == "table" and #t or 0 }, "|")
    end
    local n, keys = 0, {}
    for k, x in pairs(v) do n = n + 1; if x == true then keys[#keys + 1] = tostring(k) end end
    table.sort(keys)
    return n .. ":" .. table.concat(keys, ",")
end

function EHR.MedicalStateSync.Build(data, player, opts)
    if type(data) ~= "table" then return nil end
    -- RequestSync can arrive before server initialization. An empty joining
    -- player's table must not clear the client's save or acknowledge its init.
    if player and data.EHR_Initialized ~= true then return nil end
    if player and isServer and isServer() and EHR.OfflineProgression then
        if EHR.OfflineProgression.EnsureSessionPrepared
                and not EHR.OfflineProgression.EnsureSessionPrepared(player) then return nil end
        if EHR.OfflineProgression.TouchPlayer then
            EHR.OfflineProgression.TouchPlayer(player)
        end
    end
    local packet = { EHR_FullSnapshot = true, EHR_ClearedFields = {} }
    local periodic = type(opts) == "table" and opts.periodic == true
    local sigs = player and lastSig[player]
    if player and not sigs then sigs = {}; lastSig[player] = sigs end
    for key in pairs(fields) do
        if data[key] ~= nil then
            if RARE[key] and sigs then
                local sig = signature(key, data[key])
                if not (periodic and sigs[key] == sig) then
                    packet[key] = data[key]
                    sigs[key] = sig
                end
            else
                packet[key] = data[key]
            end
        elseif fields[key] then
            packet.EHR_ClearedFields[#packet.EHR_ClearedFields + 1] = key
        end
    end
    return packet
end

function EHR.MedicalStateSync.ApplyClearedFields(data, packet, inDebugGrace)
    if type(data) ~= "table" or type(packet) ~= "table"
            or type(packet.EHR_ClearedFields) ~= "table" then return end
    for _, key in ipairs(packet.EHR_ClearedFields) do
        local flags = fields[key]
        local preserveDebug = inDebugGrace and
            (key == "EHR_Disease" or key == "EHR_WoundInfection" or key == "EHR_Sepsis")
        if flags and packet[key] == nil and not preserveDebug then
            data[key] = nil
            for _, flag in ipairs(flags) do data[flag] = nil end
        end
    end
end

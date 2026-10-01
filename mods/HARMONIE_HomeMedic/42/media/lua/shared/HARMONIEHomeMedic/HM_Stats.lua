--[[
    HARMONIE - Home Medic : body stats snapshot (shared)

    Request 2026-10-01: a tab that reads every stat of a player -- yourself
    or someone you examine -- including stats other mods add (like the
    vitamins GardenToPlate shows through Modern Status). One snapshot when
    the tab opens (and on Refresh), no live stream between server and
    clients.

    HM_Stats.collect(player) -> list of rows
        { g = group id, k = label key or nil, t = label text, v = number,
          f = 0..1 for a bar or nil, s = display text }
    Rows are plain tables (they travel in a server command).

    Other mods add rows with
        HM_Stats.Register({ id = "MyMod_Thing", group = "mods",
            label = "My thing" or labelKey = "UI_...",
            get = function(player) return value, fraction, text end })
    -- get may return only a value (0..1 shows as a percentage bar).
    Indicators registered with Modern Status (MS_IndicatorSettingsPanel)
    are read too, on the client, for your own character.

    Remote: the doctor's client asks the server (module HARMONIE_HM_Stats,
    "Snapshot"); the server collects and replies once.
]]--

HM_Stats = HM_Stats or {}
local St = HM_Stats
St.MODULE = "HARMONIE_HM_Stats"
St.registry = St.registry or {}
St.GROUPS = { "signs", "moodles", "vitals", "needs", "mood", "body", "nutrition", "illness", "mods" }

local function call(obj, method, ...)
    if not obj or not obj[method] then return nil end
    local ok, v = pcall(obj[method], obj, ...)
    if ok then return v end
    return nil
end
local function clamp01(v) return math.max(0, math.min(1, v)) end
local function round(v, n) local m = 10 ^ (n or 0); return math.floor(v * m + 0.5) / m end

function St.Register(def)
    if type(def) ~= "table" or not def.id or type(def.get) ~= "function" then return false end
    for i, d in ipairs(St.registry) do
        if d.id == def.id then St.registry[i] = def; return true end
    end
    St.registry[#St.registry + 1] = def
    return true
end

-- ------------------------------------------------------------- vanilla stats
-- CharacterStat names known in B42 (a name the game lacks is skipped).
-- Never call CharacterStat.values(): Kahlua does not expose it (error).
local STAT_GROUP = {
    ENDURANCE = "needs", FATIGUE = "needs", HUNGER = "needs", THIRST = "needs",
    PAIN = "body", SICKNESS = "illness", FOOD_SICKNESS = "illness", POISON = "illness",
    ZOMBIE_INFECTION = "illness", ZOMBIE_FEVER = "illness", TEMPERATURE = "vitals",
    STRESS = "mood", PANIC = "mood", UNHAPPINESS = "mood", BOREDOM = "mood", ANGER = "mood",
    DISCOMFORT = "mood", IDLENESS = "mood", SANITY = "mood", MORALE = "mood",
    NICOTINE_WITHDRAWAL = "mood", INTOXICATION = "body", WETNESS = "body", FITNESS = "body",
}
local STAT_ORDER = {
    "ENDURANCE", "FATIGUE", "HUNGER", "THIRST", "PAIN", "WETNESS", "INTOXICATION", "TEMPERATURE",
    "STRESS", "PANIC", "UNHAPPINESS", "BOREDOM", "ANGER", "DISCOMFORT", "IDLENESS", "SANITY", "MORALE",
    "NICOTINE_WITHDRAWAL", "SICKNESS", "FOOD_SICKNESS", "POISON", "ZOMBIE_INFECTION", "ZOMBIE_FEVER", "FITNESS",
}

local function statRow(name, v)
    if type(v) ~= "number" then return nil end
    local row = { g = STAT_GROUP[name] or "body", k = "UI_HomeMedic_Stat_" .. name, t = name, v = v }
    if name == "TEMPERATURE" then
        row.s = string.format("%.1f C", v)
        row.f = clamp01((v - 34) / 8)
    elseif v >= 0 and v <= 1 then
        row.f = v
        row.s = tostring(round(v * 100)) .. "%"
    else
        row.s = tostring(round(v, 2))
    end
    return row
end

local function vanillaStats(player, out)
    local stats = call(player, "getStats")
    if not stats or not CharacterStat then return end
    local done = {}
    local function add(name, stat)
        if not stat or done[name] or done[stat] then return end
        done[name] = true
        done[stat] = true
        local ok, v = pcall(function() return stats:get(stat) end)
        if ok then
            local row = statRow(name, tonumber(v))
            if row then out[#out + 1] = row end
        end
    end
    for _, name in ipairs(STAT_ORDER) do
        local ok, stat = pcall(function() return CharacterStat[name] end)
        if ok then add(name, stat) end
    end
end

-- ------------------------------------------------------------- body, nutrition
local function bodyRows(player, out)
    local bd = call(player, "getBodyDamage")
    local health = bd and call(bd, "getOverallBodyHealth")
    if health then
        out[#out + 1] = { g = "vitals", k = "UI_HomeMedic_Stat_Health", t = "Health", v = health,
            f = clamp01(health / 100), s = tostring(round(health)) }
    end
    local temp = bd and call(bd, "getTemperature")
    if temp then
        out[#out + 1] = { g = "vitals", k = "UI_HomeMedic_Stat_BodyTemp", t = "Body temperature", v = temp,
            f = clamp01((temp - 34) / 8), s = string.format("%.1f C", temp) }
    end
    local md = call(player, "getModData") or {}
    local blood = md.EHR_Blood
    if type(blood) == "table" and tonumber(blood.currentVolume) and tonumber(blood.maxVolume) and blood.maxVolume > 0 then
        local f = blood.currentVolume / blood.maxVolume
        out[#out + 1] = { g = "vitals", k = "UI_HomeMedic_Stat_Blood", t = "Blood volume", v = blood.currentVolume,
            f = clamp01(f), s = string.format("%d mL (%d%%)", math.floor(blood.currentVolume), round(f * 100)) }
    end
    local I = EHR and EHR.Immunity
    if I and I.GetScore then
        local ok, score = pcall(I.GetScore, player)
        if ok and tonumber(score) then
            out[#out + 1] = { g = "vitals", k = "UI_HomeMedic_Stat_Immunity", t = "Immunity", v = score,
                f = clamp01(score / 100), s = tostring(round(score)) }
        end
    end
    local infection = bd and call(bd, "getInfectionLevel")
    if infection and infection > 0 then
        out[#out + 1] = { g = "illness", k = "UI_HomeMedic_Stat_InfectionLevel", t = "Infection level", v = infection,
            f = clamp01(infection / 100), s = tostring(round(infection, 1)) }
    end
    local n = call(player, "getNutrition")
    if n then
        local function add(key, label, method, unit, digits)
            local v = call(n, method)
            if type(v) == "number" then
                out[#out + 1] = { g = "nutrition", k = "UI_HomeMedic_Stat_" .. key, t = label, v = v,
                    s = tostring(round(v, digits or 0)) .. (unit or "") }
            end
        end
        add("Weight", "Weight", "getWeight", " kg", 1)
        add("Calories", "Calories", "getCalories", " kcal")
        add("Carbs", "Carbohydrates", "getCarbohydrates", " g")
        add("Proteins", "Proteins", "getProteins", " g")
        add("Lipids", "Fats", "getLipids", " g")
    end
end

-- ------------------------------------------------------------- mods
local function registryRows(player, out)
    for _, def in ipairs(St.registry) do
        local ok, v, f, s = pcall(def.get, player)
        if ok and v ~= nil then
            local row = { g = def.group or "mods", k = def.labelKey, t = def.label or def.id, v = tonumber(v) }
            if f == nil and row.v and row.v >= 0 and row.v <= 1 then f = row.v end
            row.f = f and clamp01(f) or nil
            row.s = s or (row.f and f == row.v and (tostring(round(row.v * 100)) .. "%")) or tostring(v)
            out[#out + 1] = row
        end
    end
end

-- Modern Status indicators other mods added (client, own character)
local function modernStatusRows(player, out)
    if isServer and isServer() then return end
    local panel = MS_IndicatorSettingsPanel
    local names = panel and panel.IndicatorNames
    if type(names) ~= "table" then return end
    local keys = {}
    for className in pairs(names) do
        if type(className) == "string" and className:sub(1, 3) ~= "MS_" then keys[#keys + 1] = className end
    end
    table.sort(keys)
    for _, className in ipairs(keys) do
        local cls = _G[className]
        if type(cls) == "table" and type(cls.getValue) == "function" then
            local fake = setmetatable({ player = player }, { __index = cls })
            local ok, v = pcall(cls.getValue, fake)
            if ok and tonumber(v) then
                v = tonumber(v)
                local label = names[className]
                local t = getText and getText(label)
                out[#out + 1] = { g = "mods", t = (t and t ~= label) and t or className, v = v,
                    f = clamp01(v), s = tostring(round(clamp01(v) * 100)) .. "%" }
            end
        end
    end
end

-- ------------------------------------------------------------- vitals (pulse, signs)
-- A small live read for the pulse monitor and the signs list:
-- { dead, health 0..100, blood 0..1, temp C, and CharacterStat values 0..1 }
local VITAL_STATS = { "PANIC", "PAIN", "STRESS", "ENDURANCE", "FATIGUE", "HUNGER", "THIRST",
    "SICKNESS", "FOOD_SICKNESS", "POISON", "INTOXICATION", "ZOMBIE_INFECTION", "ZOMBIE_FEVER" }
function St.vitals(player)
    local v = {}
    if not player then return v end
    v.dead = call(player, "isDead") == true
    local bd = call(player, "getBodyDamage")
    v.health = bd and tonumber(call(bd, "getOverallBodyHealth")) or nil
    v.temp = bd and tonumber(call(bd, "getTemperature")) or nil
    v.infection = bd and tonumber(call(bd, "getInfectionLevel")) or nil
    local md = call(player, "getModData") or {}
    local blood = md.EHR_Blood
    if type(blood) == "table" and tonumber(blood.currentVolume) and tonumber(blood.maxVolume) and blood.maxVolume > 0 then
        v.blood = clamp01(blood.currentVolume / blood.maxVolume)
    end
    -- per body part: pain (EHR puts illness pain there), stiffness, infected wound
    v.parts = {}
    if bd and BodyPartType and BodyPartType.FromIndex and BodyPartType.ToIndex then
        local okN, n = pcall(function() return BodyPartType.ToIndex(BodyPartType.MAX) end)
        for i = 0, (okN and tonumber(n) or 0) - 1 do
            local okP, part = pcall(function() return bd:getBodyPart(BodyPartType.FromIndex(i)) end)
            if okP and part then
                local name = tostring(call(part, "getType") or i)
                v.parts[name] = {
                    pain = tonumber(call(part, "getAdditionalPain")) or 0,
                    stiff = tonumber(call(part, "getStiffness")) or 0,
                    infected = call(part, "isInfectedWound") == true,
                }
            end
        end
    end
    local stats = call(player, "getStats")
    if stats and CharacterStat then
        for _, name in ipairs(VITAL_STATS) do
            local okS, stat = pcall(function() return CharacterStat[name] end)
            if okS and stat then
                local ok, val = pcall(function() return stats:get(stat) end)
                if ok and tonumber(val) then v[name] = tonumber(val) end
            end
        end
    end
    return v
end

-- ------------------------------------------------------------- moodles
-- the vanilla moodles the player shows now: row.mt = moodle type name
-- (icon lookup on the client), row.lv = level 1..4, row.gb = 1 good / 2 bad
local function moodleRows(player, out)
    local m = call(player, "getMoodles")
    local n = m and tonumber(call(m, "getNumMoodles")) or 0
    for i = 0, n - 1 do
        local lv = tonumber(call(m, "getMoodleLevel", i)) or 0
        if lv > 0 then
            local mt = call(m, "getMoodleType", i)
            local name = call(m, "getMoodleDisplayString", i)
            out[#out + 1] = { g = "moodles", t = tostring(name or mt or "?"), mt = mt and tostring(mt) or nil,
                lv = lv, gb = tonumber(call(m, "getGoodBadNeutral", i)) or 0, v = lv,
                s = string.rep("|", lv) }
        end
    end
end

-- ------------------------------------------------------------- signs
-- the illness signs that can be read off the body right now (HM_Diagnosis.SIGNS)
local function signRows(player, out)
    local D = HM_Diagnosis
    if not (D and D.readSigns) then return end
    local any = false
    for _, r in ipairs(D.readSigns(St.vitals(player))) do
        out[#out + 1] = { g = "signs", k = "UI_HomeMedic_Diag_Tag_" .. r.tag, t = r.tag, tag = r.tag, s = r.reading }
        any = true
    end
    if not any then out[#out + 1] = { g = "signs", k = "UI_HomeMedic_Stats_NoSigns", t = "No measurable signs", s = "" } end
end

function St.collect(player)
    local out = {}
    if not player then return out end
    pcall(signRows, player, out)
    pcall(moodleRows, player, out)
    pcall(bodyRows, player, out)
    pcall(vanillaStats, player, out)
    pcall(registryRows, player, out)
    pcall(modernStatusRows, player, out)
    return out
end

-- ------------------------------------------------------------- built-in extensions
-- HARMONIE - From Garden to Plate: vitamins (shared data, works on the server)
local function registerGardenToPlate()
    local G = HARMONIE_GTP
    if not (G and G.Vitamins and G.VitData and G.VitData.Get) then return end
    for _, vit in ipairs(G.Vitamins) do
        St.Register({
            id = "GTP_Vitamin" .. vit, group = "mods", labelKey = "IGUI_HARMONIE_ModernStatus_Vitamin" .. vit,
            label = "Vitamin " .. vit,
            get = function(player)
                local v = G.VitData.Get(player, vit)
                local max = G.Config and G.Config.maxValue or 100
                if type(v) ~= "number" then return nil end
                return v, v / max, tostring(round(v, 1)) .. " / " .. tostring(max)
            end,
        })
    end
end
St.registerGardenToPlate = registerGardenToPlate

-- ------------------------------------------------------------- server
-- Remote: the server answers at once with its own view, and asks the
-- patient's client for theirs (stats and other mods' data live there in
-- MP); that answer is forwarded and replaces the first one.
St.Server = St.Server or {}
local lastAsk = {}

local function byOnline(id)
    id = tonumber(id)
    if not id or not getOnlinePlayers then return nil end
    local online = getOnlinePlayers()
    for i = 0, online:size() - 1 do
        local p = online:get(i)
        if p and call(p, "getOnlineID") == id then return p end
    end
    return nil
end

function St.Server.Snapshot(doctor, args)
    args = type(args) == "table" and args or {}
    local patient = args.patientOnline and byOnline(args.patientOnline) or doctor
    local key = tostring(call(doctor, "getOnlineID") or "sp")
    local now = getTimestampMs and getTimestampMs() or 0
    if lastAsk[key] and now - lastAsk[key] < 1500 then return end
    lastAsk[key] = now
    local rows = patient and St.collect(patient) or {}
    if isServer and isServer() then
        sendServerCommand(doctor, St.MODULE, "Snapshot", { patientOnline = args.patientOnline, rows = rows,
            ok = patient ~= nil, source = "server" })
        if patient and patient ~= doctor then
            sendServerCommand(patient, St.MODULE, "Collect", { doctorOnline = call(doctor, "getOnlineID") })
        end
    end
    return rows
end

-- the patient's client answered
function St.Server.Collected(patient, args)
    args = type(args) == "table" and args or {}
    local doctor = byOnline(args.doctorOnline)
    if not doctor or type(args.rows) ~= "table" then return end
    sendServerCommand(doctor, St.MODULE, "Snapshot", { patientOnline = call(patient, "getOnlineID"),
        rows = args.rows, ok = true, source = "patient" })
end

if Events and not St.registered then
    St.registered = true
    if Events.OnGameBoot then Events.OnGameBoot.Add(registerGardenToPlate) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(registerGardenToPlate) end
    if Events.OnGameStart then Events.OnGameStart.Add(registerGardenToPlate) end
    if Events.OnClientCommand then
        Events.OnClientCommand.Add(function(module, command, player, args)
            if module ~= St.MODULE then return end
            if command == "Snapshot" then St.Server.Snapshot(player, args)
            elseif command == "Collected" then St.Server.Collected(player, args) end
        end)
    end
end

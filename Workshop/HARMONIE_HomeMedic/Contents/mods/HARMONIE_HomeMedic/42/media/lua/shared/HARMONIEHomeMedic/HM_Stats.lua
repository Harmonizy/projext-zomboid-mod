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
St.GROUPS = { "signs", "moodles", "vitals", "needs", "mood", "body", "nutrition", "vitamins", "illness", "mods" }

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

-- ------------------------------------------------------------- From Garden to Plate
-- Our vitamin mod (HARMONIE_GardenToPlate), when it is loaded: read its
-- per-player store straight from modData (HARMONIE_Vitamins) -- read only,
-- so nothing is created or synced from here (VitData.Get would create the
-- store). -> { [vit] = { value, band, afflicted, active } } or nil
function St.gtp(player)
    local G = HARMONIE_GTP
    if not (G and G.Vitamins) then return nil end
    local store
    if G.VitData and G.VitData.Peek then
        -- GTP 0.11.1+: also another player's vitamins in MP (from the server)
        local ok, st = pcall(G.VitData.Peek, player)
        store = ok and st or nil
        if not ok and G.LogOnce then G.LogOnce("HM_Stats:peekfail", "HomeMedic", "Home Medic stats: VitData.Peek FAILED: %s", tostring(st)) end
        if G.LogOnce then G.LogOnce("HM_Stats:peek", "HomeMedic", "Home Medic stats read vitamins through VitData.Peek (MP-safe)") end
    else
        local md = call(player, "getModData")
        store = md and md.HARMONIE_Vitamins
    end
    if type(store) ~= "table" then return nil end
    local cfg = G.Config or {}
    local out = {}
    for _, vit in ipairs(G.Vitamins) do
        local e = store[vit]
        local v = type(e) == "table" and tonumber(e.value) or nil
        if v then
            local band = (G.GetBand and G.GetBand(v)) or (v < (cfg.criticalThreshold or 20) and "critical")
                or (v < (cfg.sufficientThreshold or 50) and "low") or "sufficient"
            -- GTP applies a deficiency effect while afflicted and not shielded
            -- by a banked pause day (VitEffects isActive)
            local active = e.afflicted == true and (tonumber(e.pauseDays) or 0) < 1 and cfg.effectsEnabled ~= false
            out[vit] = { value = v, band = band, afflicted = e.afflicted == true, active = active,
                max = cfg.maxValue or 100, pauseDays = tonumber(e.pauseDays) or 0,
                need = G.DailyRequirement and G.DailyRequirement[vit] }
        end
    end
    return out
end

-- Request 2026-10-02: what GTP's own vitamin window shows, per vitamin --
-- its band (Critical / Low / Sufficient), whether the penalty is biting,
-- the daily need and the banked rest days; the tooltip carries GTP's own
-- status text. (The reserve values themselves already show under "From
-- other mods".) The status text uses GTP's own keys so it matches its UI.
local UNIT = { A = "mcg", B = "mg", C = "mg", D = "mcg", E = "mg", K = "mcg" }
local function gtpText(key, fallback, ...)
    if getText then
        local ok, t
        if select("#", ...) > 0 then ok, t = pcall(getText, key, ...) else ok, t = pcall(getText, key) end
        if ok and t and t ~= key then return t end
    end
    local t = fallback
    for i = 1, select("#", ...) do t = t:gsub("%%" .. i, tostring((select(i, ...)))) end
    return t
end
local BAND = { critical = "Critical", low = "Low", sufficient = "Sufficient" }

local function vitaminRows(player, out)
    local gtp = St.gtp(player)
    local G = HARMONIE_GTP
    if not gtp then return end
    for _, vit in ipairs(G.Vitamins) do
        local e = gtp[vit]
        if e then
            local bandWord = BAND[e.band] or "Sufficient"
            local downside = gtpText("IGUI_HARMONIE_Downside_" .. vit, "")
            local status
            if e.band == "critical" then status = downside
            elseif e.band == "low" then status = gtpText("IGUI_HARMONIE_LowWarning", "If this keeps dropping: %1", downside)
            else status = gtpText("IGUI_HARMONIE_SufficientNote", "Reserve is healthy. No penalty active.") end
            local yes = e.active and gtpText("UI_HomeMedic_Stat_VitYes", "Yes") or gtpText("UI_HomeMedic_Stat_VitNo", "No")
            out[#out + 1] = { g = "vitamins", k = "UI_HomeMedic_Stat_Vitamin" .. vit, t = "Vitamin " .. vit, vit = vit,
                band = e.band, active = e.active or nil, bad = e.band ~= "sufficient" or nil,
                s = gtpText("UI_HomeMedic_Stat_VitBand_" .. (e.band or "sufficient"), bandWord), tip = status }
            out[#out + 1] = { g = "vitamins", k = "UI_HomeMedic_Stat_VitPenalty", t = "Penalty active", indent = 1,
                bad = e.active or nil, s = yes, tip = e.active and downside or nil }
            if e.need then
                out[#out + 1] = { g = "vitamins", k = "UI_HomeMedic_Stat_VitNeed", t = "Daily need", indent = 1,
                    s = tostring(e.need) .. " " .. (UNIT[vit] or "") }
            end
            out[#out + 1] = { g = "vitamins", k = "UI_HomeMedic_Stat_VitPause", t = "Rest days banked", indent = 1,
                s = tostring(math.floor(e.pauseDays or 0)), tip = gtpText("IGUI_HARMONIE_PauseDaysTooltip", "") }
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
    -- GTP vitamin D deficiency holds every body part at stiffness 20:
    -- the stiffness signs then count only what is above that floor
    v.gtp = St.gtp(player)
    v.stiffFloor = (v.gtp and v.gtp.D and v.gtp.D.active) and 20 or 0
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
    -- From Garden to Plate: a vitamin deficiency that is acting on the body
    local gtp = St.gtp(player)
    for _, vit in ipairs(HARMONIE_GTP and HARMONIE_GTP.Vitamins or {}) do
        local e = gtp and gtp[vit]
        if e and e.active then
            out[#out + 1] = { g = "signs", k = "UI_HomeMedic_Sign_Vit" .. vit, t = "Vitamin " .. vit .. " deficiency",
                vit = vit, bad = true, s = tostring(round(e.value, 1)) .. " / " .. tostring(e.max) }
            any = true
        end
    end
    if not any then out[#out + 1] = { g = "signs", k = "UI_HomeMedic_Stats_NoSigns", t = "No measurable signs", s = "" } end
end

-- ------------------------------------------------------------- abnormal values
-- row.bad = true when a value is clearly outside the healthy range; the
-- Body Stats tab draws it red. Ranges by row key (vanilla moodle-ish limits).
local function above(lim) return function(v) return v > lim end end
local function below(lim) return function(v) return v < lim end end
local function outside(lo, hi) return function(v) return v < lo or v > hi end end
St.ABNORMAL = {
    UI_HomeMedic_Stat_Health = below(60),
    UI_HomeMedic_Stat_BodyTemp = outside(36.0, 37.5),
    UI_HomeMedic_Stat_TEMPERATURE = outside(36.0, 37.5),
    UI_HomeMedic_Stat_Immunity = below(40),
    UI_HomeMedic_Stat_InfectionLevel = above(0),
    UI_HomeMedic_Stat_ENDURANCE = below(0.3),
    UI_HomeMedic_Stat_FATIGUE = above(0.6),
    UI_HomeMedic_Stat_HUNGER = above(0.5),
    UI_HomeMedic_Stat_THIRST = above(0.5),
    UI_HomeMedic_Stat_PAIN = above(0.3),
    UI_HomeMedic_Stat_INTOXICATION = above(0.5),
    UI_HomeMedic_Stat_STRESS = above(0.6),
    UI_HomeMedic_Stat_PANIC = above(0.5),
    UI_HomeMedic_Stat_UNHAPPINESS = above(0.6),
    UI_HomeMedic_Stat_BOREDOM = above(0.7),
    UI_HomeMedic_Stat_ANGER = above(0.6),
    UI_HomeMedic_Stat_DISCOMFORT = above(0.6),
    UI_HomeMedic_Stat_SANITY = below(0.6),
    UI_HomeMedic_Stat_MORALE = below(0.3),
    UI_HomeMedic_Stat_NICOTINE_WITHDRAWAL = above(0.5),
    UI_HomeMedic_Stat_SICKNESS = above(0.25),
    UI_HomeMedic_Stat_FOOD_SICKNESS = above(0.25),
    UI_HomeMedic_Stat_POISON = above(0.1),
    UI_HomeMedic_Stat_ZOMBIE_INFECTION = above(0),
    UI_HomeMedic_Stat_ZOMBIE_FEVER = above(0),
    UI_HomeMedic_Stat_Weight = outside(65, 100),
}
local function markAbnormal(out)
    for _, row in ipairs(out) do
        if row.g == "signs" then
            row.bad = row.bad or row.tag ~= nil
        elseif row.g == "vitamins" then
            -- band row: not sufficient; "penalty active" row: yes (set by vitaminRows)
            if row.band then row.bad = row.band ~= "sufficient" end
        elseif row.g == "moodles" then
            row.bad = row.gb == 2 and (row.lv or 0) >= 2
        elseif row.k == "UI_HomeMedic_Stat_Blood" then
            row.bad = (row.f or 1) < 0.85
        else
            local test = row.k and St.ABNORMAL[row.k]
            if test and type(row.v) == "number" then row.bad = test(row.v) or nil end
        end
        if not row.bad then row.bad = nil end
    end
end
St.markAbnormal = markAbnormal

function St.collect(player)
    local out = {}
    if not player then return out end
    pcall(signRows, player, out)
    pcall(moodleRows, player, out)
    pcall(bodyRows, player, out)
    pcall(vitaminRows, player, out)
    pcall(vanillaStats, player, out)
    pcall(registryRows, player, out)
    pcall(modernStatusRows, player, out)
    pcall(markAbnormal, out)
    return out
end

-- ------------------------------------------------------------- built-in extensions
-- HARMONIE - From Garden to Plate: vitamins have their own group now
-- (vitaminRows above); kept as a no-op for callers.
local function registerGardenToPlate() end
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
    if args.patientOnline and not byOnline(args.patientOnline) then
        HMLogOnce("statsgone:" .. tostring(args.patientOnline), "Stats", "%s asked for stats of player id %s: not online", HMLogName(doctor), tostring(args.patientOnline))
    end
    HMLogOnce("stats:" .. HMLogName(doctor) .. ">" .. HMLogName(patient), "Stats", "%s is reading %s's stats (repeats not logged)", HMLogName(doctor), HMLogName(patient))
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
    if not doctor or type(args.rows) ~= "table" then
        HMLogOnce("collectbad:" .. HMLogName(patient), "Stats", "%s's stats answer dropped: %s", HMLogName(patient), doctor and "no rows" or "doctor not online")
        return
    end
    HMLogOnce("collected:" .. HMLogName(patient), "Stats", "%s's own client answered with %d stat rows (repeats not logged)", HMLogName(patient), #args.rows)
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
            elseif command == "Collected" then St.Server.Collected(player, args)
            else HMLog("Stats", "%s sent unknown command %s", HMLogName(player), tostring(command)) end
        end)
    end
end

--[[
    Extensive Health Rework
    Shared localization helpers.

    Use this for EHR-owned UI and dialogue strings that need a safe English
    fallback when translators have not provided a value yet.
]]--

EHR = EHR or {}
EHR.Locale = EHR.Locale or {}

local function missing(value, key)
    return value == nil or value == "" or value == "?" or value == key
end

function EHR.Locale.Text(key, fallback)
    if not key or key == "" then
        return fallback or ""
    end

    local value = nil
    if getText then
        local ok, result = pcall(getText, key)
        if ok then
            value = result
        end
    end

    if missing(value, key) then
        return fallback or key
    end
    return value
end

function EHR.Locale.Format(key, fallback, ...)
    local values = { ... }
    local text = nil

    -- Formatted translations must receive their arguments in the getText()
    -- call itself. Since 42.20.1 the Translator validates placeholders such
    -- as %1 immediately; fetching the value first through Locale.Text() made
    -- it report a MissingFormatArgumentException before the Lua replacement
    -- below had a chance to run.
    if key and key ~= "" and getText then
        local ok, result = pcall(getText, key, ...)
        if ok then
            text = result
        end
    end

    if missing(text, key) then
        text = fallback or key or ""
    end

    for i, value in ipairs(values) do
        local replacement = tostring(value)
        text = string.gsub(text, "%%" .. tostring(i) .. "%$[%a]", function() return replacement end)
        text = string.gsub(text, "%%" .. tostring(i), function() return replacement end)
    end

    if string.find(text, "%%[cdeEfgGiouqsxX]") then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then
            return formatted
        end
    end

    return text
end

function EHR.Locale.RawKey(text)
    text = tostring(text or "")
    local hash = 5381
    for i = 1, #text do
        hash = (hash * 33 + string.byte(text, i)) % 4294967296
    end
    return string.format("UI_EHR_Line_%08X", hash)
end

function EHR.Locale.TextForLine(text)
    if not text or text == "" then
        return text
    end

    text = tostring(text)

    -- Antibody-test results contain runtime values, so hashing the completed
    -- English sentence would create a different, untranslatable key for every
    -- blood type/rating/chance combination. Localize the stable template and
    -- rating before falling back to the regular raw-line hash system.
    local bloodType, rating, chance = string.match(
        text,
        "^Test complete%.%.%. Blood type (.-)%. (.-) %- (%d+)%% survival chance%.$"
    )
    if bloodType and rating and chance then
        local ratingKeys = {
            ["High Compatibility"] = "UI_EHR_KnoxCure_Rating_High",
            ["Moderate Compatibility"] = "UI_EHR_KnoxCure_Rating_Moderate",
            ["Low Compatibility"] = "UI_EHR_KnoxCure_Rating_Low",
            ["Critical Risk"] = "UI_EHR_KnoxCure_Rating_Critical",
        }
        local ratingKey = ratingKeys[rating]
        local localizedRating = ratingKey and EHR.Locale.Text(ratingKey, rating) or rating
        return EHR.Locale.Format(
            "UI_EHR_KnoxCure_TestResult",
            "Test complete... Blood type %1. %2 - %3 survival chance.",
            bloodType,
            localizedRating,
            tostring(chance) .. "%"
        )
    end

    if string.match(text, "^[A-Za-z0-9_]+$") then
        local byKey = EHR.Locale.Text(text, nil)
        if byKey and byKey ~= text then
            return byKey
        end
    end

    local rawKey = EHR.Locale.RawKey(text)
    return EHR.Locale.Text(rawKey, text)
end

-- HARMONIE 0.33.2 (owner, 2026-11-10): "ควรพูดทุก 1 นาทีโลกจริง แต่แค่ไม่พูดซ้ำ
-- แต่ละบทพูดมีคูลดาวน์ของตัวเอง 10 นาที". Every line the character says by
-- itself (illness stages, symptoms, warnings) goes through here:
--   * a player says at most one line per SAY_GAP_MS (1 min, real time);
--   * each line has its own LINE_COOLDOWN_MS (10 min, real time).
-- A line that does not pass is dropped (not queued). An answer to something
-- the player just did (took a pill, used an item) goes through SayAction:
-- never dropped, but it counts as the last line for the 1-minute gap.
-- Runs where the line is decided (the server in MP, the game in SP).
EHR.Locale.SAY_GAP_MS = 60 * 1000
EHR.Locale.LINE_COOLDOWN_MS = 10 * 60 * 1000
local sayLast = {}       -- player -> ms of the last line
local lineLast = {}      -- player|line -> ms
local dropLog = {}       -- player -> { n = dropped since last log, at = ms of last log }
local lineDropLogged = {}

local function sayNowMs()
    if getTimestampMs then
        local ok, v = pcall(getTimestampMs)
        if ok and tonumber(v) then return tonumber(v) end
    end
    return (os and os.time and os.time() or 0) * 1000
end

local function sayWho(player)
    local key
    pcall(function() key = player:getUsername() end)
    if not key or key == "" then pcall(function() key = "id" .. tostring(player:getOnlineID()) end) end
    return tostring(key or "?")
end

local function sayLog(fmt, ...)
    local msg = string.format(fmt, ...)
    if HMLog then HMLog("Dialogue", "%s", msg) else print("[HARMONIE_HM][Dialogue] " .. msg) end
end

local function sayDropped(who, now, why, text)
    local d = dropLog[who]
    if not d then d = { n = 0, at = -1e15 }; dropLog[who] = d end
    d.n = d.n + 1
    local lk = who .. "|" .. tostring(text)
    if why == "line" and not lineDropLogged[lk] then
        lineDropLogged[lk] = true
        sayLog("%s: line on its 10-minute cooldown, dropped (logged once per line): %s", who, tostring(text))
    end
    if now - d.at >= 10 * 60 * 1000 then
        sayLog("%s: %d line(s) dropped in the last 10 min (1 line a minute, 10 min per line) -- last: %s", who, d.n, tostring(text))
        d.n = 0
        d.at = now
    end
end

-- true when this player may say this line now (and stamps it)
function EHR.Locale.MaySay(player, text)
    local who = sayWho(player)
    local now = sayNowMs()
    local last = sayLast[who]
    if last and now >= last and now - last < (EHR.Locale.SAY_GAP_MS or 60000) then
        sayDropped(who, now, "gap", text)
        return false
    end
    local lk = who .. "|" .. tostring(text)
    local ll = lineLast[lk]
    if ll and now >= ll and now - ll < (EHR.Locale.LINE_COOLDOWN_MS or 600000) then
        sayDropped(who, now, "line", text)
        return false
    end
    sayLast[who] = now
    lineLast[lk] = now
    return true
end

local function sayOut(player, text)
    local line = EHR.Locale.TextForLine(text)
    if isServer and isServer() and not (isClient and isClient()) and sendServerCommand then
        sendServerCommand(player, "EHR_Dialogue", "Say", { text = line })
        return true
    end
    if not player.Say then
        return false
    end
    player:Say(line)
    return true
end

-- the answer to something the player just did: always said
function EHR.Locale.SayAction(player, text)
    if not player or not text or text == "" then return false end
    sayLast[sayWho(player)] = sayNowMs()
    return sayOut(player, text)
end

function EHR.Locale.Say(player, text)
    if not player then
        return false
    end
    if not text or text == "" then
        return false
    end
    if not EHR.Locale.MaySay(player, text) then
        return false
    end
    return sayOut(player, text)
end

function EHR.Locale.SideEffectName(name)
    if not name or name == "" then
        return ""
    end
    local key = "UI_SideEffect_" .. tostring(name):gsub("%s+", ""):gsub("[^A-Za-z0-9_]", "")
    return EHR.Locale.Text(key, tostring(name))
end

-- Keep the canonical English level in simulation/network data; translate only
-- where it is displayed so localized words never enter threshold comparisons.
function EHR.Locale.ExposureLevel(level)
    level = tostring(level or "None")
    return EHR.Locale.Text("UI_EHR_ExposureLevel_" .. level, level)
end

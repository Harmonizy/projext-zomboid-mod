--[[
    HARMONIE - Home Medic : the pulse monitor on the medical window's tab 1 (client)

    Request 2026-10-01: blood composition moves to tab 3; tab 1 shows a
    moving pulse trace instead, that turns good / fair / poor / critical /
    no pulse with the patient's health, blood volume, panic, pain, fever and
    the like.

    HM_Pulse.assess(v) -> { level 0..4, key, bpm, irregular, weak, reasons }
        v = HM_Stats.vitals(player) (+ blood 0..1 from the window)
        level 0 good, 1 fair, 2 poor, 3 critical, 4 no pulse
    The trace is a sweep monitor: a cursor writes left to right over the
    old trace, like a bedside monitor. Drawn with 2 px columns.

    Remote patients: their stats live on their own client, so the trace
    uses the stats snapshot (HM_Stats, the same one tab 3 uses), refreshed
    every 15 s while the tab is open; blood comes from the exam data.
]]--

require "HARMONIEHomeMedic/HM_Text"
require "ExtensiveHealth/EHR_HealthPanelUI"
require "HARMONIEHomeMedic/HM_Stats"

HM_Pulse = HM_Pulse or {}
local P = HM_Pulse
local St = HM_Stats

local FONT, FONT_M, FONT_L = UIFont.Small, UIFont.Medium, UIFont.Large
local function fh(f) return getTextManager():getFontHeight(f or FONT) end
local function tw(t, f) return getTextManager():MeasureStringX(f or FONT, t or "") end
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end
local function L(key, fallback, ...) return HM_Text("UI_HomeMedic_Pulse_" .. key, fallback or key, ...) end
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

P.LEVELS = { [0] = "Good", "Fair", "Poor", "Critical", "None" }

-- ------------------------------------------------------------- assessment
-- each check: reason key, severity 1..3 (or nil when fine)
local function sev(v, s1, s2, s3)  -- higher is worse
    if not v then return nil end
    if v >= s3 then return 3 elseif v >= s2 then return 2 elseif v >= s1 then return 1 end
    return nil
end
local function sevLow(v, s1, s2, s3)  -- lower is worse
    if not v then return nil end
    if v <= s3 then return 3 elseif v <= s2 then return 2 elseif v <= s1 then return 1 end
    return nil
end

function P.assess(v)
    v = v or {}
    local out = { level = 0, bpm = 72, reasons = {} }
    if v.dead or (v.health and v.health <= 0) then
        out.level, out.bpm, out.key = 4, 0, P.LEVELS[4]
        return out
    end
    local function add(key, s)
        if not s then return end
        out.reasons[#out.reasons + 1] = { key = key, s = s }
        if s > out.level then out.level = s end
    end
    local temp = v.temp
    add("Health", sevLow(v.health, 70, 35, 15))
    add("BloodLoss", sevLow(v.blood, 0.85, 0.65, 0.45))
    if temp and temp >= 37.6 then add("Fever", sev(temp, 37.6, 39.0, 40.5)) end
    if temp and temp <= 36.0 then add("Cold", sevLow(temp, 36.0, 35.0, 33.0)) end
    add("Panic", sev(v.PANIC, 0.3, 0.75, 2))
    add("Pain", sev(v.PAIN, 0.4, 0.75, 2))
    add("Poison", sev(v.POISON, 0.2, 0.5, 0.85))
    add("Sickness", sev(math.max(v.SICKNESS or 0, v.FOOD_SICKNESS or 0), 0.3, 0.6, 2))
    add("Exhausted", sevLow(v.ENDURANCE, 0.25, -1, -1))
    -- two serious problems together are critical
    local serious = 0
    for _, r in ipairs(out.reasons) do if r.s >= 2 then serious = serious + 1 end end
    if serious >= 3 and out.level < 3 then out.level = 3 end
    table.sort(out.reasons, function(a, b) return a.s > b.s end)

    local blood = v.blood or 1
    local bpm = 72
        + (v.PANIC or 0) * 55
        + (v.PAIN or 0) * 22
        + math.max(0, (temp or 37) - 37) * 10
        + (1 - blood) * 95
        + (1 - (v.ENDURANCE or 1)) * 35
        + (v.STRESS or 0) * 10
    -- a failing heart slows down
    if v.health and v.health < 15 then bpm = 34 + v.health * 2 end
    if temp and temp < 35 then bpm = bpm - (35 - temp) * 12 end
    out.bpm = math.floor(clamp(bpm, 28, 195) + 0.5)
    out.irregular = out.level >= 3 or (v.POISON or 0) > 0.5
    out.weak = out.level >= 2 or blood < 0.7
    out.key = P.LEVELS[out.level]
    return out
end

-- ------------------------------------------------------------- data source
local function rowsToVitals(rows)
    local v = {}
    for _, row in ipairs(rows or {}) do
        local k = row.k or ""
        local name = k:match("^UI_HomeMedic_Stat_(.+)$")
        if name == "Health" then v.health = tonumber(row.v)
        elseif name == "BodyTemp" then v.temp = tonumber(row.v)
        elseif name == "Blood" then v.blood = tonumber(row.f)
        elseif name and name:match("^[A-Z_]+$") then v[name] = tonumber(row.v) end
    end
    return v
end

function P.vitalsFor(panel)
    local v
    if panel.isRemoteHealthPanel and isClient and isClient() then
        local st = panel.hmStats
        local t = nowMs()
        panel.hmPulseAsk = panel.hmPulseAsk or 0
        if (not st or st.patient ~= panel.player or t - panel.hmPulseAsk > 15000) and panel.hmStatsRequest then
            panel.hmPulseAsk = t
            panel:hmStatsRequest()
            st = panel.hmStats
        end
        v = rowsToVitals(st and st.rows)
        if panel.player and panel.player.isDead and panel.player:isDead() then v.dead = true end
    else
        -- read the body a few times a second, not every frame
        local t = nowMs()
        if not panel.hmPulseV or panel.hmPulseVPlayer ~= panel.player or t - (panel.hmPulseVAt or 0) > 300 then
            panel.hmPulseV, panel.hmPulseVPlayer, panel.hmPulseVAt = St.vitals(panel.player), panel.player, t
        end
        v = {}
        for k, x in pairs(panel.hmPulseV) do v[k] = x end
    end
    -- the window's own blood numbers (remote exam data included)
    local ok, summary = pcall(function() return panel:getBloodSummary() end)
    if ok and summary and tonumber(summary.bloodPct) then v.blood = summary.bloodPct / 100 end
    return v
end

-- ------------------------------------------------------------- trace
-- one heartbeat, phase 0..1 -> -1..1 (P, QRS, T)
local function g(p, c, w) local d = (p - c) / w; return math.exp(-d * d) end
local function beat(p)
    return 0.10 * g(p, 0.12, 0.035)
        - 0.12 * g(p, 0.235, 0.010)
        + 1.00 * g(p, 0.26, 0.013)
        - 0.25 * g(p, 0.287, 0.012)
        + 0.24 * g(p, 0.48, 0.055)
end

local SPEED = 110          -- px per second
local COL = 2              -- px per column
local SUB = 6              -- sub-samples per column (keeps the R spike)

local function advance(st, a, cols)
    local now = nowMs()
    local dt = st.last and math.min(0.25, (now - st.last) / 1000) or 0
    st.last = now
    st.acc = (st.acc or 0) + dt * SPEED / COL
    local n = math.floor(st.acc)
    st.acc = st.acc - n
    local amp = a.level >= 4 and 0 or (a.weak and (a.level >= 3 and 0.42 or 0.62) or 1)
    local perCol = (a.bpm / 60) / (SPEED / COL)
    for _ = 1, math.min(n, cols) do
        local best = 0
        for s = 1, SUB do
            st.phase = (st.phase or 0) + perCol / SUB
            if st.phase >= (st.rr or 1) then
                st.phase = st.phase - (st.rr or 1)
                st.beatAt = now
                st.rr = a.irregular and (0.7 + ZombRandFloat(0, 0.6)) or 1
            end
            local y = beat(math.min(1, st.phase)) * amp
            if math.abs(y) > math.abs(best) then best = y end
        end
        local noise = a.level >= 4 and ZombRandFloat(-0.02, 0.02) or (a.level >= 3 and ZombRandFloat(-0.05, 0.05) or 0)
        st.cursor = ((st.cursor or 0) % cols) + 1
        st.buf[st.cursor] = best + noise
    end
end

function EHR_HealthPanelUI:hmDrawPulsePanel(atY)
    local c = EHR_HealthPanelUI.Colors
    local x, y = 12, atY or self:getContentTop()
    local w, h = self.width - 24, self.BLOOD_PANEL_HEIGHT
    local a = P.assess(P.vitalsFor(self))
    local col = ({ [0] = c.green, c.yellow, c.orange or c.red, c.red, c.textDim })[a.level] or c.text
    local title = L("Title", "PULSE")
    self:drawPanelFrame(x, y, w, h, title, nil)

    -- state after the heading, then the reasons
    local hx = x + 12 + tw(title, FONT_M) + 14
    local state = L("State_" .. a.key, a.key)
    self:drawText(state, hx, y + 8 + math.floor((28 - fh(FONT_M)) / 2), col.r, col.g, col.b, 1, FONT_M)
    local rx = hx + tw(state, FONT_M) + 14
    if #a.reasons > 0 then
        local parts = {}
        for _, r in ipairs(a.reasons) do parts[#parts + 1] = L("Why_" .. r.key, r.key) end
        local txt = table.concat(parts, ", ")
        local room = x + w - 14 - rx
        if room > 40 then
            while #parts > 1 and tw(txt) > room do
                parts[#parts] = nil
                txt = table.concat(parts, ", ") .. " ..."
            end
            if tw(txt) <= room then
                self:drawText(txt, rx, y + 8 + math.floor((28 - fh()) / 2), c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT)
            end
        end
    end

    -- left: rate and rhythm
    local top, bottom = y + 46, y + h - 8
    local st = self.hmPulse or { buf = {} }
    self.hmPulse = st
    local flash = st.beatAt and (nowMs() - st.beatAt) < 140 and a.level < 4
    local infoW = 150
    local bpmText = a.level >= 4 and "--" or tostring(a.bpm)
    local bf = flash and 1 or 0.82
    self:drawText(bpmText, x + 16, top, col.r * bf + (flash and 0.15 or 0), col.g * bf + (flash and 0.15 or 0), col.b * bf + (flash and 0.15 or 0), 1, FONT_L)
    self:drawText(L("Bpm", "bpm"), x + 20 + tw(bpmText, FONT_L), top + fh(FONT_L) - fh() - 2, c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT)
    local rhythm
    if a.level >= 4 then rhythm = L("Rhythm_None", "No pulse")
    elseif a.irregular then rhythm = L("Rhythm_Irregular", "Irregular")
    elseif a.weak then rhythm = L("Rhythm_Weak", "Weak, thready")
    else rhythm = L("Rhythm_Regular", "Regular") end
    self:drawText(rhythm, x + 16, bottom - fh(), c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT)

    -- right: the trace
    local gx, gy = x + infoW + 10, top - 2
    local gw, gh = x + w - 14 - gx, bottom - gy
    if gw < 60 then return end
    self:drawRect(gx, gy, gw, gh, 0.9, 0.01, 0.03, 0.03)
    for lx = gx + 20, gx + gw - 1, 20 do self:drawRect(lx, gy, 1, gh, 0.10, 0.2, 0.7, 0.5) end
    for ly = gy + 10, gy + gh - 1, 10 do self:drawRect(gx, ly, gw, 1, 0.08, 0.2, 0.7, 0.5) end
    self:drawRectBorder(gx, gy, gw, gh, 0.7, c.borderDim.r, c.borderDim.g, c.borderDim.b)

    local cols = math.floor(gw / COL)
    if st.cols ~= cols then st.cols, st.buf, st.cursor = cols, {}, 0 end
    advance(st, a, cols)
    local mid = gy + math.floor(gh * 0.6)
    local scale = gh * 0.52
    local cur = st.cursor or 0
    local prevY
    for i = 1, cols do
        local behind = (cur - i) % cols          -- 0 at the cursor
        if behind > 0 and behind < cols - 5 or i == cur then
            local val = st.buf[i]
            if val then
                local yy = clamp(math.floor(mid - val * scale), gy + 1, gy + gh - 2)
                local py = prevY or yy
                local y1, y2 = math.min(py, yy), math.max(py, yy)
                local alpha = 1 - 0.65 * (behind / cols)
                self:drawRect(gx + (i - 1) * COL, y1, COL, math.max(2, y2 - y1 + 1), alpha, col.r, col.g, col.b)
                prevY = yy
            else
                prevY = nil
            end
        else
            prevY = nil
        end
    end
    -- the sweep cursor
    if cur > 0 then self:drawRect(gx + (cur - 1) * COL + COL, gy + 1, 2, gh - 2, 0.35, col.r, col.g, col.b) end
end

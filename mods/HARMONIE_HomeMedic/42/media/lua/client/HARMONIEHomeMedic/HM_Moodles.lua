--[[
    HARMONIE - How to Survive : our moodles (client only)

    Owner 2026-11-27: "when blood volume is low show a moodle, and say what
    each stage does -- like GTP's moodles", then "any other moodle we should
    have? do them all".

    Built on MoodleFramework like GTP's vitamin moodles, but SOFT: HTS does
    not require MoodleFramework, so without it this file does nothing.
    Read only: shows state, never changes it. Every 2 s per local player.

    HM_BloodLoss  EHR blood volume (sandbox thresholds):
        1 healthy > b >= mild, 2 >= moderate, 3 >= 20 %, 4 below
    HM_Saline     saline share of the blood (EHR hemodilution):
        1 >= 20 %, 2 >= 30 %, 3 >= 40 % (EHR warning effects),
        4 >= 60 % (EHR "death" effects)
    HM_Stump      an amputation stump not healed yet (TOC, own data):
        1 healing, 2 dirt >= 30 %, 3 dirt >= 60 %,
        4 a prosthesis worn on it (it can bleed)
    Title + description per level (UI_HomeMedic_Moodle_*): the reading now,
    what this level does, what the next one adds, how to fix it.
    The texts follow the real code (EHR_Blood, HARMONIE_BloodImpact,
    HARMONIE_BloodVision, TOC) and the sandbox; change them with it.
    Icons media/ui/<name>.png + Moodles/128 (tools/gen_moodle_icons.py).
    EHR's own disease / exposure moodles stay off (owner 2026-10-02).
]]--

pcall(function() require "MF_ISMoodle" end)
require "HARMONIEHomeMedic/HARMONIE_BloodImpact"

HM_Moodles = HM_Moodles or {}
local M = HM_Moodles

M.INTERVAL_MS = 2000
M.LETHAL_BLOOD = 0.20

local BAD = 2
local NEUTRAL = 0.5
local NO_GOOD = 2.0
-- one value inside each bad band (thresholds 0.05 / 0.15 / 0.25 / 0.35)
local LEVEL_VALUE = { [1] = 0.30, [2] = 0.20, [3] = 0.10, [4] = 0.02 }

local function log(fmt, ...) print(string.format("[HARMONIE_HM][Moodles] " .. fmt, ...)) end

local function mfReady()
    return type(MF) == "table" and type(MF.createMoodle) == "function" and type(MF.getMoodle) == "function"
end

local function pct(f) return math.floor((tonumber(f) or 0) * 100 + 0.5) end

local function T(key, ...)
    local full = "UI_HomeMedic_Moodle_" .. key
    local ok, s = pcall(getText, full, ...)
    if ok and s and s ~= full then return s end
    return full
end

local function lethalOn()
    return EHR and EHR.Lethal and EHR.Lethal.allowed and EHR.Lethal.allowed() == true
end

local function bloodData(player)
    local data = EHR and EHR.GetPlayerData and EHR.GetPlayerData(player)
    return data and data.EHR_Blood
end

-- ------------------------------------------------------------ blood loss
local function thresholds()
    local t = EHR and EHR.Blood and EHR.Blood.GetThresholds and EHR.Blood.GetThresholds() or {}
    return tonumber(t.healthy) or 0.85, tonumber(t.mild) or 0.80, tonumber(t.moderate) or 0.70
end

local function bloodLevel(f)
    if not f then return 0 end
    local healthy, mild, moderate = thresholds()
    if f >= healthy then return 0 end
    if f >= mild then return 1 end
    if f >= moderate then return 2 end
    if f >= M.LETHAL_BLOOD then return 3 end
    return 4
end

local function regenLine()
    local B = EHR and EHR.Blood
    if not B or (B.IsRegenEnabled and not B.IsRegenEnabled()) then return T("Blood_RegenOff") end
    local delay = B.GetRegenDelayHours and tonumber(B.GetRegenDelayHours()) or 2
    local rate = B.GetRegenRatePerHour and tonumber(B.GetRegenRatePerHour()) or 50
    local minP = B.GetRegenMinimumPercent and tonumber(B.GetRegenMinimumPercent()) or 30
    return T("Blood_Regen", tostring(delay), tostring(math.floor(rate)), tostring(math.floor(minP)))
end

function M.blood(player)
    local f = HARMONIE_HomeMedic_BloodImpact and HARMONIE_HomeMedic_BloodImpact.bloodFraction(player)
    local level = bloodLevel(f)
    if level == 0 then return 0 end
    local healthy, mild, moderate = thresholds()
    local L = { T("Blood_Now", tostring(pct(f)), tostring(pct(healthy))), "", T("Effects") }
    if level == 1 then
        L[#L + 1] = T("Blood_L1")
        L[#L + 1] = T("Next", tostring(pct(mild))) .. " " .. T("Blood_N1")
    elseif level == 2 then
        L[#L + 1] = T("Blood_L2")
        L[#L + 1] = T("Next", tostring(pct(moderate))) .. " " .. T("Blood_N2")
    elseif level == 3 then
        local blackout = EHR and EHR.Blood and EHR.Blood.IsBlackoutEnabled and EHR.Blood.IsBlackoutEnabled() ~= false
        L[#L + 1] = T("Blood_L3")
        L[#L + 1] = blackout and T("Blood_L3Blackout") or T("Blood_L3NoBlackout")
        L[#L + 1] = T("Next", tostring(pct(M.LETHAL_BLOOD))) .. " " .. (lethalOn() and T("Blood_N3Lethal") or T("Blood_N3Safe"))
    else
        L[#L + 1] = lethalOn() and T("Blood_L4Lethal") or T("Blood_L4Safe")
    end
    L[#L + 1] = ""
    L[#L + 1] = T("Blood_Fix")
    L[#L + 1] = regenLine()
    return level, T("Blood_Title" .. level), table.concat(L, "\n"), pct(f)
end

-- ------------------------------------------------------------ saline
local function salineRatio(player)
    local b = bloodData(player)
    if not b then return 0 end
    local cur, sal = tonumber(b.currentVolume) or 0, tonumber(b.transfusedSaline) or 0
    if cur <= 0 or sal <= 0 then return 0 end
    return sal / cur
end

function M.saline(player)
    local r = salineRatio(player)
    local warn = EHR and EHR.Blood and tonumber(EHR.Blood.HEMODILUTION_WARNING) or 0.40
    local death = EHR and EHR.Blood and tonumber(EHR.Blood.HEMODILUTION_THRESHOLD) or 0.60
    local level = 0
    if r >= death then level = 4 elseif r >= warn then level = 3 elseif r >= 0.30 then level = 2 elseif r >= 0.20 then level = 1 end
    if level == 0 then return 0 end
    local L = { T("Saline_Now", tostring(pct(r)), tostring(pct(warn)), tostring(pct(death))), "", T("Effects") }
    if level <= 2 then
        L[#L + 1] = T("Saline_L12")
        L[#L + 1] = T("NextUp", tostring(pct(warn))) .. " " .. T("Saline_N2")
    elseif level == 3 then
        L[#L + 1] = T("Saline_L3")
        L[#L + 1] = T("NextUp", tostring(pct(death))) .. " " .. (lethalOn() and T("Saline_N3Lethal") or T("Saline_N3Safe"))
    else
        L[#L + 1] = lethalOn() and T("Saline_L4Lethal") or T("Saline_L4Safe")
    end
    L[#L + 1] = ""
    L[#L + 1] = T("Saline_Fix")
    return level, T("Saline_Title" .. level), table.concat(L, "\n"), pct(r)
end

-- ------------------------------------------------------------ stump
local function tocMods()
    local okS, SD = pcall(require, "TOC/StaticData")
    local okD, DC = pcall(require, "TOC/Controllers/DataController")
    if okS and okD and type(SD) == "table" and type(DC) == "table" then return SD, DC end
    return nil
end

local function limbName(limb)
    local k = "ContextMenu_Limb_" .. tostring(limb)
    local ok, s = pcall(getText, k)
    return (ok and s and s ~= k) and s or tostring(limb)
end

function M.stump(player)
    local SD, DC = tocMods()
    if not SD or not DC.GetInstance then return 0 end
    local dc = DC.GetInstance(player:getUsername())
    if not dc or not dc.tocData or not dc.tocData.limbs or (dc.getIsDataReady and not dc:getIsDataReady()) then return 0 end
    local level, rows, key = 0, {}, ""
    for _, limb in ipairs(SD.LIMBS_STR or {}) do
        local ld = dc.tocData.limbs[limb]
        if ld and ld.isCut and ld.isVisible and not ld.isCicatrized then
            local total = tonumber(SD.LIMBS_CICATRIZATION_TIME_IND_NUM and SD.LIMBS_CICATRIZATION_TIME_IND_NUM[limb]) or 120
            local healed = math.max(0, math.min(1, 1 - (tonumber(ld.cicatrizationTime) or total) / total))
            local dirt = math.max(0, math.min(1, tonumber(ld.woundDirtyness) or 0))
            local prost = false
            pcall(function() prost = dc:getIsProstEquipped(limb) == true end)
            local lv = 1
            if prost then lv = 4 elseif dirt >= 0.6 then lv = 3 elseif dirt >= 0.3 then lv = 2 end
            if lv > level then level = lv end
            rows[#rows + 1] = T(prost and "Stump_RowProst" or "Stump_Row", limbName(limb), tostring(pct(healed)), tostring(pct(dirt)))
            key = key .. limb .. pct(healed) .. ":" .. pct(dirt) .. (prost and "p" or "") .. ";"
        end
    end
    if level == 0 then return 0 end
    local L = { T("Stump_Head") }
    for i = 1, #rows do L[#L + 1] = rows[i] end
    L[#L + 1] = ""
    L[#L + 1] = T("Effects")
    L[#L + 1] = T("Stump_L" .. level)
    if level < 3 then L[#L + 1] = T("Stump_Next") end
    L[#L + 1] = ""
    L[#L + 1] = T("Stump_Fix")
    return level, T("Stump_Title" .. level), table.concat(L, "\n"), key
end

-- ------------------------------------------------------------ framework
M.DEFS = {
    { name = "HM_BloodLoss", fn = M.blood },
    { name = "HM_Saline", fn = M.saline },
    { name = "HM_Stump", fn = M.stump },
}

local state = setmetatable({}, { __mode = "k" })

local function update(player, def)
    local ok, m = pcall(MF.getMoodle, def.name, player:getPlayerNum())
    if not ok or not m then return end
    local st = state[m]
    if not st then
        pcall(function() m:setThresholds(0.05, 0.15, 0.25, 0.35, NO_GOOD, NO_GOOD, NO_GOOD, NO_GOOD) end)
        st = { level = -1 }
        state[m] = st
    end
    local okF, level, title, desc, sig = pcall(def.fn, player)
    if not okF then
        if not st.err then st.err = true; log("%s failed: %s", def.name, tostring(level)) end
        return
    end
    level = tonumber(level) or 0
    if level == 0 then
        if st.level ~= 0 then
            pcall(function() m:setValue(NEUTRAL) end)
            if st.level > 0 then log("%s: %s gone", tostring(player:getUsername()), def.name) end
        end
        st.level = 0
        return
    end
    if st.level ~= level or st.sig ~= sig then
        pcall(function()
            m:setTitle(BAD, level, title)
            m:setDescription(BAD, level, desc)
        end)
        if st.level ~= level then log("%s: %s level %d (%s)", tostring(player:getUsername()), def.name, level, tostring(sig)) end
        st.level, st.sig = level, sig
    end
    pcall(function() m:setValue(LEVEL_VALUE[level]) end)
end

function M.updatePlayer(player)
    if not player or player:isDead() then return end
    for _, def in ipairs(M.DEFS) do update(player, def) end
end

local last = 0
local function onTick()
    local now = getTimestampMs and getTimestampMs() or 0
    if now - last < M.INTERVAL_MS then return end
    last = now
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p then pcall(M.updatePlayer, p) end
    end
end

if not mfReady() then
    log("MoodleFramework not active -- no How to Survive moodles")
    return M
end

local made = 0
for _, def in ipairs(M.DEFS) do
    local okC, errC = pcall(MF.createMoodle, def.name)
    if okC then made = made + 1 else log("createMoodle %s failed: %s", def.name, tostring(errC)) end
end
if made == 0 then return M end
Events.OnTick.Add(onTick)
-- a new character gets new moodle objects: set them up at once
Events.OnCreatePlayer.Add(function(playerNum, player)
    last = 0
    if player then pcall(M.updatePlayer, player) end
end)
log("installed %d moodles (MoodleFramework)", made)

return M

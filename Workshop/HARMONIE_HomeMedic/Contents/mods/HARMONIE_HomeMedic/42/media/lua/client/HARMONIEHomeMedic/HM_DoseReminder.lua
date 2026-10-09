--[[
    HARMONIE - Home Medic : "time for your next dose" reminder (client)

    Request 2026-10-02: when the next dose of a medicine COURSE is due
    (EHR.Medication.GetDoseStatus: the interval has passed, the course is
    not complete yet), a small window pops up saying so: the medicine with
    its picture, which dose of how many, how long is left before the course
    is lost, and whether the medicine is in the inventory.

    Checked every game minute for the local players. One window per dose
    ("Later" asks again in an hour); not while asleep. Single doses and
    symptom-only medicines (painkillers...) never pop up.
]]--

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "HARMONIEHomeMedic/HM_Text"

HM_DoseReminder = ISPanel:derive("HM_DoseReminder")
local R = HM_DoseReminder

local FONT, FONT_M = UIFont.Small, UIFont.Medium
local function fh(f) return getTextManager():getFontHeight(f or FONT) end
local function tw(t, f) return getTextManager():MeasureStringX(f or FONT, t or "") end
local function L(key, fallback, ...) return HM_Text("UI_HomeMedic_Dose_" .. key, fallback, ...) end
local function hours() return getGameTime and getGameTime():getWorldAgeHours() or 0 end
local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end

R.SNOOZE_HOURS = 1
R.state = R.state or {}      -- [playerNum] = { [medKey] = { dose = n, untilHour = h } }
R.open = R.open or {}        -- [playerNum] = window

-- ------------------------------------------------------------- what is due
-- a course dose that is due now -> the EHR status, else nil
function R.isDue(status)
    if type(status) ~= "table" then return false end
    if status.treatmentComplete or status.isStaleOverdue then return false end
    if (tonumber(status.totalDosesNeeded) or 1) <= 1 then return false end
    if status.symptomOnly and not status.requiresDoseCourse then return false end
    if (tonumber(status.doseCount) or 0) < 1 then return false end
    return status.isOverdue == true or (tonumber(status.hoursUntilNextDose) or 1) <= 0
end

function R.dueList(player)
    local M = EHR and EHR.Medication
    if not (M and M.GetAllDoseStatuses) then return {} end
    local ok, list = pcall(M.GetAllDoseStatuses, player)
    if not ok then HMLogOnce("dosefail:" .. tostring(list), "Dose", "EHR GetAllDoseStatuses FAILED: %s", tostring(list)) end
    local out = {}
    for _, st in ipairs(ok and type(list) == "table" and list or {}) do
        if R.isDue(st) then out[#out + 1] = st end
    end
    return out
end

local function itemName(fullType, fallback)
    if getItemNameFromFullType then
        local ok, n = pcall(getItemNameFromFullType, fullType)
        if ok and n and n ~= "" and n ~= fullType then return n end
    end
    return fallback or fullType
end

local function itemIcon(fullType)
    local sm = getScriptManager and getScriptManager()
    local it = sm and call(sm, "FindItem", fullType)
    local icon = it and call(it, "getIcon")
    if not icon or icon == "" then return nil end
    for _, path in ipairs({ "Item_" .. icon, "media/textures/Item_" .. icon .. ".png" }) do
        local ok, t = pcall(getTexture, path)
        if ok and t then return t end
    end
    return nil
end

local function hasItem(player, fullType)
    local inv = call(player, "getInventory")
    return inv and (call(inv, "getFirstTypeRecurse", fullType) ~= nil) or false
end

-- the illness it treats -- by name only once diagnosed
local function treatingText(player, status)
    local id = status.treatingDisease
    if not id then return nil end
    local D = HM_Diagnosis
    if D and D.isDiagnosed and not D.isDiagnosed(player, id, nil) then
        return L("TreatingUnknown", "For an illness not yet diagnosed")
    end
    local name = D and D.Client and D.Client.diseaseName and D.Client.diseaseName(D.normalize(id)) or tostring(id)
    return L("Treating", "For: %1", name)
end

-- ------------------------------------------------------------- the window
local W, H = 400, 214

function R.show(player, status)
    local num = call(player, "getPlayerNum") or 0
    HMLog("Dose", "reminder: %s dose due (%s)", tostring(status and status.medKey), tostring(status and status.medicationName))
    if R.open[num] then R.open[num]:close() end
    local sw = getCore and getCore():getScreenWidth() or 1280
    local o = ISPanel.new(R, math.floor((sw - W) / 2), 90 + num * 24, W, H)
    o.player, o.num, o.status = player, num, status
    o.name = itemName(status.medKey, status.medicationName)
    o.icon = itemIcon(status.medKey)
    o.backgroundColor = { r = 0.012, g = 0.05, b = 0.068, a = 0.96 }
    o.borderColor = { r = 0.3, g = 0.84, b = 1.0, a = 1 }
    o.moveWithMouse = true
    o:initialise()
    o:instantiate()
    o:addToUIManager()
    if o.setAlwaysOnTop then o:setAlwaysOnTop(true) end
    R.open[num] = o
    if getSoundManager then pcall(function() getSoundManager():playUISound("HM_Surg_Beep") end) end
    return o
end

function R:createChildren()
    ISPanel.createChildren(self)
    self.buttons = {}
    local bh = fh() + 12
    local function add(label, fn)
        local b = ISButton:new(0, self.height - bh - 12, tw(label) + 30, bh, label, self, fn)
        b:initialise()
        b:instantiate()
        b.borderColor = { r = 0.3, g = 0.84, b = 1.0, a = 1 }
        b.backgroundColor = { r = 0.03, g = 0.24, b = 0.34, a = 0.9 }
        b.backgroundColorMouseOver = { r = 0.10, g = 0.28, b = 0.50, a = 1 }
        self:addChild(b)
        self.buttons[#self.buttons + 1] = b
    end
    add(L("Btn_Ok", "Got it"), R.onOk)
    add(L("Btn_Later", "Remind me in an hour"), R.onLater)
    local total = 0
    for _, b in ipairs(self.buttons) do total = total + b.width + 10 end
    local x = math.floor((self.width - total + 10) / 2)
    for _, b in ipairs(self.buttons) do b:setX(x); x = x + b.width + 10 end
end

local function remember(self, untilHour)
    local st = R.state[self.num] or {}
    R.state[self.num] = st
    st[self.status.medKey] = { dose = tonumber(self.status.doseCount) or 0, untilHour = untilHour }
end

function R:onOk() HMLog("Dose", "reminder OK for %s", tostring(self.status.medKey)); remember(self, nil); self:close() end
function R:onLater() HMLog("Dose", "reminder snoozed %s h for %s", tostring(R.SNOOZE_HOURS), tostring(self.status.medKey)); remember(self, hours() + R.SNOOZE_HOURS); self:close() end

function R:close()
    if R.open[self.num] == self then R.open[self.num] = nil end
    self:setVisible(false)
    self:removeFromUIManager()
end

function R:prerender()
    ISPanel.prerender(self)
    local w = self.width
    local st = self.status
    self:drawRect(0, 0, w, 32, 0.95, 0.03, 0.052, 0.08)
    self:drawRect(10, 31, w - 20, 1, 0.8, 0.22, 0.72, 0.95)
    self:drawText(L("Title", "TIME FOR THE NEXT DOSE"), 12, math.floor((32 - fh(FONT_M)) / 2), 0.3, 0.84, 1.0, 1, FONT_M)

    local x, y = 14, 44
    if self.icon then
        self:drawTextureScaled(self.icon, x, y, 48, 48, 1, 1, 1, 1)
    else
        self:drawRectBorder(x, y, 48, 48, 0.6, 0.1, 0.34, 0.46)
    end
    local tx = x + 60
    local maxW = w - tx - 12
    local fit = HM_Surgery and HM_Surgery.fitText
    local function line(text, font, r, g, b)
        if fit then text = fit(text, maxW, function(s) return tw(s, font) end) end
        self:drawText(text, tx, y, r, g, b, 1, font)
        y = y + fh(font) + 2
    end
    line(self.name, FONT_M, 0.9, 0.93, 0.97)
    local nextDose = (tonumber(st.doseCount) or 0) + 1
    line(L("DoseOf", "Dose %1 of %2", nextDose, tonumber(st.totalDosesNeeded) or nextDose), FONT, 0.6, 0.67, 0.74)
    local treating = treatingText(self.player, st)
    if treating then line(treating, FONT, 0.6, 0.67, 0.74) end
    y = math.max(y, 44 + 52) + 4
    local left = (tonumber(st.maxOverdueHours) or 0) - (tonumber(st.hoursOverdue) or 0)
    if (tonumber(st.maxOverdueHours) or 0) > 0 then
        local hrs = left >= 1 and tostring(math.floor(left)) or "<1"
        local msg = L("Deadline", "Take it within %1 h, or the course is dropped and must start over.", hrs)
        self:drawText(fit and fit(msg, w - 28, function(s) return tw(s) end) or msg, 14, y, 1.0, 0.78, 0.12, 1, FONT)
        y = y + fh() + 4
    end
    local have = hasItem(self.player, st.medKey)
    local hm = have and L("HaveIt", "You have it with you.") or L("NoItem", "You do not have it with you!")
    self:drawText(hm, 14, y, have and 0.35 or 0.95, have and 0.9 or 0.32, have and 0.45 or 0.28, 1, FONT)
end

-- ------------------------------------------------------------- checking
function R.check()
    if not getSpecificPlayer then return end
    local now = hours()
    for num = 0, 3 do
        local player = getSpecificPlayer(num)
        if player and not call(player, "isDead") and not call(player, "isAsleep") and not R.open[num] then
            local seen = R.state[num] or {}
            R.state[num] = seen
            for _, st in ipairs(R.dueList(player)) do
                local s = seen[st.medKey]
                local dose = tonumber(st.doseCount) or 0
                local shown = s and s.dose == dose and (s.untilHour == nil or now < s.untilHour)
                if not shown then
                    R.show(player, st)
                    break
                end
            end
        end
    end
end

if Events and Events.EveryOneMinute and not R.registered then
    R.registered = true
    Events.EveryOneMinute.Add(R.check)
end

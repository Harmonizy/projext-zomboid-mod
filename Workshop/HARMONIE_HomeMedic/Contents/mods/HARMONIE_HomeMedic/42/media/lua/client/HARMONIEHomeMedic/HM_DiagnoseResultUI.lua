--[[
    HARMONIE - Home Medic : the diagnosis "moment" (client)

    Request 2026-10-01: picking an illness in the Diagnosis tab opens a small
    window over the medical window -- nothing to play, just a few seconds of
    suspense while the signs are checked one by one -- then the verdict:
      success -> Home / Keep diagnosing / Handbook / Surgery buttons
      failure -> only Keep diagnosing
    The server's answer (HM_Diagnosis "Result") arrives at any time; the
    verdict shows when both the answer is in and the suspense is over.
]]--

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "HARMONIEHomeMedic/HM_Text"

HM_DiagnoseResultUI = ISPanel:derive("HM_DiagnoseResultUI")
local R = HM_DiagnoseResultUI

local FONT, FONT_M, FONT_L = UIFont.Small, UIFont.Medium, UIFont.Large
local function fh(f) return getTextManager():getFontHeight(f or FONT) end
local function tw(t, f) return getTextManager():MeasureStringX(f or FONT, t or "") end
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end
local function L(key, fallback, ...) return HM_Text("UI_HomeMedic_Diag_" .. key, fallback, ...) end
local function sfx(name) if getSoundManager then pcall(function() getSoundManager():playUISound("HM_Surg_" .. name) end) end end

R.SUSPENSE_MS = 2800
R.TIMEOUT_MS = 9000
local W, H = 460, 300

-- panel: the medical window; id: the illness picked; tags: the signs ticked
function R.open(panel, id, tags)
    if panel.hmDxResult then panel.hmDxResult:close() end
    HMLog("DiagnoseUI", "result window for %s", tostring(id))
    local x = math.floor((panel.width - W) / 2)
    local y = math.floor((panel.height - H) / 2)
    local o = ISPanel.new(R, x, y, W, H)
    o.panel, o.id, o.tags, o.started = panel, id, tags or {}, nowMs()
    o.buttons = {}
    o.backgroundColor = { r = 0.02, g = 0.035, b = 0.06, a = 0.97 }
    o.borderColor = { r = 0.32, g = 0.7, b = 1.0, a = 1 }
    o.moveWithMouse = false
    o:initialise()
    o:instantiate()
    panel:addChild(o)
    panel.hmDxResult = o
    return o
end

function R:createChildren()
    ISPanel.createChildren(self)
    self.buttons = self.buttons or {}
end

local function diseaseName(id)
    local c = HM_Diagnosis and HM_Diagnosis.Client
    if c and c.diseaseName then return c.diseaseName(id) end
    return tostring(id)
end

-- the server answered
function R:setResult(ok, reason, name)
    self.result = { ok = ok == true, reason = reason, name = name or diseaseName(self.id) }
end

function R:addButton(label, fn, enabled, tip)
    local bh = fh() + 12
    local b = ISButton:new(0, 0, tw(label) + 28, bh, label, self, function() fn(self) end)
    b:initialise()
    b:instantiate()
    b.borderColor = { r = 0.32, g = 0.7, b = 1.0, a = 1 }
    b.backgroundColor = { r = 0.05, g = 0.16, b = 0.32, a = 0.9 }
    b.backgroundColorMouseOver = { r = 0.10, g = 0.28, b = 0.50, a = 1 }
    if enabled == false then b:setEnable(false) end
    if tip and b.setTooltip then b:setTooltip(tip) end
    self:addChild(b)
    self.buttons[#self.buttons + 1] = b
end

function R:layoutButtons()
    local gap = 8
    local total = 0
    for _, b in ipairs(self.buttons) do total = total + b.width + gap end
    total = total - gap
    if total > self.width - 24 then
        self:setWidth(math.min(self.panel.width - 20, total + 24))
        self:setX(math.floor((self.panel.width - self.width) / 2))
    end
    local x = math.floor((self.width - total) / 2)
    for _, b in ipairs(self.buttons) do
        b:setX(x); b:setY(self.height - b.height - 14)
        x = x + b.width + gap
    end
end

function R:reveal()
    self.revealed = true
    local r = self.result or { ok = false, reason = "NoAnswer" }
    local panel = self.panel
    if r.ok then
        sfx("Good")
        self:addButton(L("Btn_Home", "Home"), function(ui) ui:close(); panel:setActiveTab("ehr") end)
        self:addButton(L("Btn_Continue", "Keep diagnosing"), function(ui) ui:close() end)
        self:addButton(L("Btn_Handbook", "Handbook"), function(ui)
            ui:close()
            panel.hmBookSelect = panel.hmBookSelect or {}
            panel.hmBookSelect.hmJournal = ui.id
            panel:setActiveTab("handbook")
        end)
        local S = HM_Surgery
        local list = S and S.surgeriesFor and S.surgeriesFor(self.id) or {}
        self:addButton(L("Btn_Surgery", "Surgery"), function(ui)
            ui:close()
            panel.hmSurgerySelect = { sid = list[1] }
            panel:setActiveTab("surgery")
        end, #list > 0, #list == 0 and L("Btn_SurgeryNone", "No operation treats this illness.") or nil)
    else
        sfx("Bad")
        self:addButton(L("Btn_Continue", "Keep diagnosing"), function(ui) ui:close() end)
    end
    self:layoutButtons()
end

function R:close()
    if self.panel and self.panel.hmDxResult == self then self.panel.hmDxResult = nil end
    self:setVisible(false)
    if self.panel then self.panel:removeChild(self) end
end

function R:update()
    ISPanel.update(self)
    if self.revealed then return end
    local t = nowMs() - self.started
    -- a soft beep for each sign checked
    local n = math.max(1, #self.tags)
    local step = math.floor(t / (R.SUSPENSE_MS / (n + 1)))
    if step ~= self.beepStep and step <= n then self.beepStep = step; sfx("Beep") end
    if (self.result and t >= R.SUSPENSE_MS) or t >= R.TIMEOUT_MS then self:reveal() end
end

function R:onMouseDown(x, y) return true end
function R:onMouseUp(x, y) return true end
function R:onMouseWheel(del) return true end

function R:prerender()
    ISPanel.prerender(self)
    local w = self.width
    local t = nowMs() - self.started
    local name = diseaseName(self.id)
    -- heading
    self:drawRect(0, 0, w, 34, 0.95, 0.03, 0.052, 0.08)
    self:drawRect(10, 33, w - 20, 1, 0.8, 0.22, 0.5, 0.85)
    local title = self.revealed and L("ResultTitle", "DIAGNOSIS") or L("CheckingTitle", "DIAGNOSING...")
    self:drawText(title, 12, math.floor((34 - fh(FONT_M)) / 2), 0.32, 0.7, 1.0, 1, FONT_M)
    local sub = HM_Surgery and HM_Surgery.fitText(name, w - 40 - tw(title, FONT_M), function(s) return tw(s, FONT) end) or name
    self:drawText(sub, w - 12 - tw(sub), math.floor((34 - fh()) / 2), 0.6, 0.67, 0.74, 1, FONT)

    if not self.revealed then
        -- the signs, checked one by one
        local tags = self.tags
        local n = math.max(1, #tags)
        local per = R.SUSPENSE_MS / (n + 1)
        local y = 46
        local cx = 22
        for i, tag in ipairs(tags) do
            local label = L("Tag_" .. tag, tag)
            local cw = tw(label) + 18
            if cx + cw > w - 16 then cx = 22; y = y + fh() + 14 end
            local lit = t >= per * i
            local active = t >= per * (i - 1) and not lit
            local a = lit and 0.9 or (active and 0.6 + 0.3 * math.sin(t / 60) or 0.3)
            self:drawRect(cx, y, cw, fh() + 8, a * 0.5, 0.05, 0.16, 0.32)
            self:drawRectBorder(cx, y, cw, fh() + 8, a, 0.32, 0.7, 1.0)
            self:drawText(label, cx + 9, y + 4, 0.9, 0.93, 0.97, lit and 1 or 0.55, FONT)
            cx = cx + cw + 8
        end
        -- a scanning trace + progress
        local gy = math.max(y + fh() + 26, 120)
        local gh = 60
        self:drawRect(20, gy, w - 40, gh, 0.9, 0.01, 0.03, 0.03)
        self:drawRectBorder(20, gy, w - 40, gh, 0.7, 0.11, 0.24, 0.42)
        local sweep = (t / 900) % 1
        for x = 0, w - 44, 2 do
            local ph = ((x / (w - 44)) * 3 + t / 700) % 1
            local v = math.exp(-((ph - 0.3) / 0.03) ^ 2) - 0.25 * math.exp(-((ph - 0.33) / 0.02) ^ 2)
            local yy = gy + gh * 0.6 - v * gh * 0.45
            local near = math.abs(x / (w - 44) - sweep)
            self:drawRect(22 + x, yy, 2, 2, math.max(0.25, 1 - near * 3), 0.3, 1.0, 0.45)
        end
        local f = math.min(1, t / R.SUSPENSE_MS)
        self:drawRect(20, gy + gh + 12, w - 40, 6, 0.6, 0.1, 0.1, 0.12)
        self:drawRect(20, gy + gh + 12, (w - 40) * f, 6, 1, 0.32, 0.7, 1.0)
        local dots = string.rep(".", 1 + math.floor(t / 350) % 3)
        local msg = (self.result or t < R.SUSPENSE_MS) and L("Checking", "Comparing the signs with %1", name) .. dots
            or L("WaitingAnswer", "Waiting for the answer") .. dots
        self:drawTextCentre(HM_Surgery and HM_Surgery.fitText(msg, w - 30, function(s) return tw(s) end) or msg, w / 2, gy + gh + 26, 0.6, 0.67, 0.74, 1, FONT)
        return
    end

    -- verdict
    local r = self.result or { ok = false, reason = "NoAnswer" }
    local ok = r.ok
    local pulse = 0.5 + 0.5 * math.sin(t / 180)
    local cr, cg, cb = 0.25, 0.92, 0.4
    if not ok then cr, cg, cb = 0.95, 0.32, 0.28 end
    self:drawRect(20, 50, w - 40, 70, 0.18 + 0.1 * pulse, cr * 0.4, cg * 0.4, cb * 0.4)
    self:drawRectBorder(20, 50, w - 40, 70, 1, cr, cg, cb)
    local big = ok and L("Success", "DIAGNOSIS CONFIRMED") or L("Fail", "DOES NOT FIT")
    self:drawTextCentre(big, w / 2, 58, cr, cg, cb, 1, FONT_L)
    local line = ok and name or L("Denied_" .. tostring(r.reason), "%1 does not fit this patient.", name)
    if r.reason == "NoAnswer" then line = L("NoAnswer", "No answer from the server. Try again.") end
    local lines = HM_Surgery and HM_Surgery.wrap(line, w - 60, FONT_M) or { line }
    local y = 58 + fh(FONT_L) + 4
    for _, l in ipairs(lines) do
        self:drawTextCentre(l, w / 2, y, 0.9, 0.93, 0.97, 1, FONT_M)
        y = y + fh(FONT_M)
    end
    local hint = ok and L("SuccessHint", "The illness now shows by name, with its stage and what it does.")
        or (r.reason == "Wrong" and L("FailHint", "Wrong guesses make you wait a moment before the next try.") or "")
    y = 140
    for _, l in ipairs(HM_Surgery and HM_Surgery.wrap(hint, w - 50, FONT) or { hint }) do
        self:drawTextCentre(l, w / 2, y, 0.6, 0.67, 0.74, 1, FONT)
        y = y + fh() + 2
    end
end

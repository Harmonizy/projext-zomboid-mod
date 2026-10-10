--[[
    HARMONIE - How to Survive : surgical consent form (client)

    Owner, 2026-10-10: "หากการกระทำไหนมีความเสี่ยง ต้องได้รับการอนุมัติจากผู้ถูก
    ทำเสมอ พร้อมบอกด้วยว่าเสี่ยงยังไง เพราะอะไร ขนาดไหน".

    Shown to the PATIENT before every operation: who operates, what, where,
    and one row per risk (HM_Surgery.risks) -- what can happen and how much
    (Risk_<k>), why (RiskWhy_<k>), and how bad (level chip: low / moderate /
    high / life-threatening). Agree or Decline; no answer within the time
    limit = Decline. The risks arrive as keys and numbers, so the text is
    in the patient's own language.

    C.openConsent(info, onAnswer)
      info = { sid, part, risks, doctor (name), self (bool), seconds, player }
      onAnswer(yes) -- called exactly once
]]--

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "HARMONIEHomeMedic/Surgery/HM_Surgery"

local S = HM_Surgery
S.Client = S.Client or {}
local C = S.Client
local FONT, FONT_M = UIFont.Small, UIFont.Medium

local function fh(f) return getTextManager():getFontHeight(f or FONT) end
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end

local LV_COL = {
    [1] = { 0.45, 0.70, 1.0 },  -- low
    [2] = { 0.95, 0.75, 0.25 }, -- moderate
    [3] = { 1.0, 0.50, 0.20 },  -- high
    [4] = { 0.95, 0.22, 0.22 }, -- life-threatening
}

HM_SurgeryConsentUI = ISPanel:derive("HM_SurgeryConsentUI")
local UI = HM_SurgeryConsentUI

function UI:new(info, onAnswer)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w = math.min(620, sw - 40)
    local h = math.min(560, sh - 40)
    local o = ISPanel.new(self, (sw - w) / 2, (sh - h) / 2, w, h)
    o.info, o.onAnswer = info or {}, onAnswer
    o.risks = type(o.info.risks) == "table" and o.info.risks or {}
    o.deadline = nowMs() + (tonumber(o.info.seconds) or S.CONSENT_SECONDS) * 1000
    o.scroll = 0
    o.moveWithMouse = true
    o.backgroundColor = { r = 0.012, g = 0.05, b = 0.068, a = 0.98 }
    o.borderColor = { r = 0.95, g = 0.30, b = 0.28, a = 1 }
    return o
end

function UI:createChildren()
    ISPanel.createChildren(self)
    local bh = fh() + 14
    self.yesBtn = ISButton:new(14, self.height - bh - 12, 170, bh, S.T("Consent_Yes", "I agree"), self, UI.onYes)
    self.yesBtn:initialise(); self:addChild(self.yesBtn)
    self.yesBtn.backgroundColor = { r = 0.10, g = 0.35, b = 0.15, a = 1 }
    self.noBtn = ISButton:new(self.width - 184, self.height - bh - 12, 170, bh, S.T("Consent_No", "Decline"), self, UI.onNo)
    self.noBtn:initialise(); self:addChild(self.noBtn)
    self.noBtn.backgroundColor = { r = 0.40, g = 0.10, b = 0.10, a = 1 }
end

function UI:answer(yes, why)
    if self.answered then return end
    self.answered = true
    HMLog("SurgeryUI", "consent form for %s: %s (%s)", tostring(self.info.sid), yes and "agreed" or "declined", tostring(why or "button"))
    self:setVisible(false)
    self:removeFromUIManager()
    if C.consentUI == self then C.consentUI = nil end
    if self.onAnswer then
        local ok, err = pcall(self.onAnswer, yes == true)
        if not ok then HMLog("SurgeryUI", "consent callback error: %s", tostring(err)) end
    end
end
function UI:onYes() self:answer(true) end
function UI:onNo() self:answer(false) end
function UI:close() self:answer(false, "closed") end

function UI:update()
    ISPanel.update(self)
    if not self.answered and nowMs() > self.deadline then self:answer(false, "timeout") end
end

-- the rows, wrapped to the window (measured each frame: fonts differ)
function UI:rows(width)
    local out, total = {}, 0
    local lineH = fh() + 2
    for _, r in ipairs(self.risks) do
        local a = type(r.a) == "table" and r.a or {}
        local k = tostring(r.k)
        local what = S.T("Risk_" .. k, k, a[1] or 0, a[2] or 0, a[3] or 0)
        local why = S.T("RiskWhy_" .. k, "", a[1] or 0, a[2] or 0, a[3] or 0)
        local wl = S.wrap(what, width, FONT)
        local yl = why ~= "" and S.wrap(why, width, FONT) or {}
        local h = (#wl + #yl) * lineH + 12
        out[#out + 1] = { lv = math.max(1, math.min(4, tonumber(r.lv) or 1)), what = wl, why = yl, y = total, h = h }
        total = total + h + 4
    end
    return out, total
end

function UI:prerender()
    ISPanel.prerender(self)
    local pad = 14
    local y = pad
    local worst = S.riskLevel(self.risks)
    self:drawText(S.T("Consent_Title", "Consent to surgery"), pad, y, 1, 1, 1, 1, FONT_M)
    y = y + fh(FONT_M) + 4
    local op = S.T("Name_" .. tostring(self.info.sid), tostring(self.info.sid))
    local part = tostring(self.info.part or "")
    if BodyPartType and BodyPartType.FromString and BodyPartType.getDisplayName then
        local ok, n = pcall(function() return BodyPartType.getDisplayName(BodyPartType.FromString(part)) end)
        if ok and n then part = n end
    end
    local who = self.info.self and S.T("Consent_WhoSelf", "You will operate on yourself: %1 (%2).", op, part)
        or S.T("Consent_Who", "%1 wants to operate on you: %2 (%3).", tostring(self.info.doctor or "?"), op, part)
    for _, l in ipairs(S.wrap(who, self.width - 2 * pad, FONT)) do
        self:drawText(l, pad, y, 0.9, 0.93, 0.97, 1, FONT); y = y + fh() + 2
    end
    local wc = LV_COL[worst]
    local overall = S.T("Consent_Overall", "Overall risk: %1", S.T("RiskLv_" .. worst, tostring(worst)))
    self:drawText(overall, pad, y + 2, wc[1], wc[2], wc[3], 1, FONT_M)
    y = y + fh(FONT_M) + 10

    -- the risk list (scrolls with the wheel)
    local listTop = y
    local listH = self.height - listTop - (fh() + 14) - 24 - fh() - 6
    local chipW = 120
    local textW = self.width - 2 * pad - chipW - 16
    local rows, total = self:rows(textW)
    self.maxScroll = math.max(0, total - listH)
    self.scroll = math.min(self.scroll, self.maxScroll)
    self:setStencilRect(0, listTop, self.width, listH)
    local lineH = fh() + 2
    for _, r in ipairs(rows) do
        local ry = listTop + r.y - self.scroll
        if ry + r.h >= listTop and ry <= listTop + listH then
            local c = LV_COL[r.lv]
            self:drawRect(pad, ry, self.width - 2 * pad, r.h, 0.35, 0.025, 0.085, 0.115)
            self:drawRect(pad, ry, 4, r.h, 1, c[1], c[2], c[3])
            self:drawRect(pad + 10, ry + 6, chipW - 4, fh() + 4, 0.85, c[1] * 0.5, c[2] * 0.5, c[3] * 0.5)
            self:drawTextCentre(S.T("RiskLv_" .. r.lv, tostring(r.lv)), pad + 8 + chipW / 2, ry + 8, 1, 1, 1, 1, FONT)
            local ty = ry + 6
            for _, l in ipairs(r.what) do self:drawText(l, pad + chipW + 12, ty, 0.95, 0.95, 0.95, 1, FONT); ty = ty + lineH end
            for _, l in ipairs(r.why) do self:drawText(l, pad + chipW + 12, ty, 0.62, 0.68, 0.75, 1, FONT); ty = ty + lineH end
        end
    end
    self:clearStencilRect()
    if self.maxScroll > 0 then
        local barH = math.max(20, listH * listH / (listH + self.maxScroll))
        local barY = listTop + (listH - barH) * (self.scroll / self.maxScroll)
        self:drawRect(self.width - 6, barY, 3, barH, 0.8, 0.3, 0.84, 1.0)
    end
    -- countdown
    local left = math.max(0, math.ceil((self.deadline - nowMs()) / 1000))
    local note = S.T("Consent_Time", "No answer in %1 s = declined.", left)
    self:drawText(note, pad, self.height - (fh() + 14) - 12 - fh() - 4, 0.6, 0.67, 0.74, 1, FONT)
end

function UI:onMouseWheel(del)
    if (self.maxScroll or 0) <= 0 then return false end
    self.scroll = math.max(0, math.min(self.maxScroll, self.scroll + del * (fh() + 2) * 3))
    return true
end

function C.openConsent(info, onAnswer)
    if C.consentUI and not C.consentUI.answered then C.consentUI:answer(false, "replaced") end
    local ui = UI:new(info, onAnswer)
    ui:initialise()
    ui:addToUIManager()
    ui:bringToTop()
    C.consentUI = ui
    HMLog("SurgeryUI", "consent form opened: %s, %d risks, worst level %d", tostring(info and info.sid), #ui.risks, S.riskLevel(ui.risks))
    return ui
end

return UI

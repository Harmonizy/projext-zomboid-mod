--[[
    HARMONIE - Home Medic : surgery windows (client)

    Body-part menu (vanilla health window, the EHR medical window, and the
    EHR window for another player) -> "Surgery" -> the PRE-OP window: one
    row per check with a short value; the explanation is a tooltip on hover
    (request: "คำอธิบายต่างๆปรากฏขึ้นเป็น tooltip เมื่อชี้ จะได้มีคำน้อยๆ").
    Start -> the server re-checks and uses up the consumables -> the
    OPERATING window plays the procedures one after another while the
    doctor works (HM_SurgeryAction), sends the step scores, and shows the
    server's result.
]]--

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "TimedActions/ISBaseTimedAction"
require "HARMONIEHomeMedic/Surgery/HM_Surgery"
require "HARMONIEHomeMedic/Surgery/HM_SurgeryGames"

local S = HM_Surgery
local G = HM_SurgeryGames
S.Client = S.Client or {}
local C = S.Client
local MODULE = "HARMONIE_HM_Surgery"
local FONT = UIFont.Small
local FONT_M = UIFont.Medium

local COL = {
    bg = { 0.020, 0.032, 0.050 }, panel = { 0.040, 0.062, 0.090 }, border = { 0.22, 0.50, 0.85 },  -- HM_Theme blue
    text = { 0.90, 0.93, 0.97 }, dim = { 0.60, 0.67, 0.74 },
    ok = { 0.35, 0.85, 0.45 }, warn = { 0.95, 0.75, 0.25 }, fail = { 0.95, 0.30, 0.28 }, info = { 0.45, 0.70, 1.0 },
    accent = { 0.32, 0.70, 1.00 },
}
local STATE_MARK = { ok = "+", warn = "!", fail = "x", info = "i" }

local function nowMs() return getTimestampMs and getTimestampMs() or 0 end
local function fh(font) return getTextManager():getFontHeight(font or FONT) end
local function tw(text, font) return getTextManager():MeasureStringX(font or FONT, text or "") end

local function fit(text, maxW, font)
    return S.fitText(text, maxW, function(t) return tw(t, font) end)
end
C.fit = fit

local function send(command, args)
    if isClient and isClient() then
        sendClientCommand(C.doctor or getPlayer(), MODULE, command, args)
    elseif S.Server and S.Server[command] then
        S.Server[command](C.doctor or getPlayer(), args)
    end
end

-- ------------------------------------------------------------- tooltip
local function wrap(text, width) return S.wrap(text, width, FONT) end

local function drawTooltip(ui, text)
    if not text or text == "" then return end
    local lines = wrap(text, 300)
    if #lines == 0 then return end
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, tw(l)) end
    w = w + 16
    local h = #lines * fh() + 12
    local mx, my = ui:getMouseX() + 16, ui:getMouseY() + 16
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    if ui:getAbsoluteX() + mx + w > sw then mx = mx - w - 24 end
    if ui:getAbsoluteY() + my + h > sh then my = my - h - 24 end
    ui:drawRect(mx, my, w, h, 0.96, 0.03, 0.03, 0.04)
    ui:drawRectBorder(mx, my, w, h, 1, COL.accent[1], COL.accent[2], COL.accent[3])
    for i, l in ipairs(lines) do
        ui:drawText(l, mx + 8, my + 6 + (i - 1) * fh(), COL.text[1], COL.text[2], COL.text[3], 1, FONT)
    end
end

-- ============================================================= PRE-OP
-- Layout is measured from the fonts (Thai lines are taller), the row list
-- scrolls with the wheel when it does not fit, and every hover test uses the
-- same scrolled coordinates as the drawing -- the tooltip always sits at the
-- mouse, scrolled or not.
HM_SurgeryPrepUI = ISPanel:derive("HM_SurgeryPrepUI")
local Prep = HM_SurgeryPrepUI

-- operations worth offering for this part: those with an indication (or
-- all of them for a patient whose data only the server can see)
function C.surgeriesFor(doctor, patient, bodyPart, exam)
    local list = {}
    local remote = not exam and S.isRemote(doctor, patient)
    for _, sid in ipairs(S.SURGERY_ORDER) do
        local sd = S.Surgeries[sid]
        local partOk = not sd.parts
        if sd.parts then
            local pn = S.partName(bodyPart)
            for _, n in ipairs(sd.parts) do if n == pn then partOk = true end end
        end
        if sd.needsTOC and not S.tocAvailable() then partOk = false end
        if partOk and (#S.indications(patient, bodyPart, sid, exam) > 0 or (remote and S.hasWound(bodyPart))) then
            list[#list + 1] = sid
        end
    end
    return list
end

function Prep:new(doctor, patient, bodyPart, sid, exam, list)
    local w = 620
    local o = ISPanel.new(self, 0, 0, w, 300)
    o.doctor, o.patient, o.bodyPart, o.exam = doctor, patient, bodyPart, exam
    o.partName = S.partName(bodyPart)
    o.list = list or { sid }
    o.sid = sid or o.list[1]
    o.moveWithMouse = true
    o.backgroundColor = { r = COL.bg[1], g = COL.bg[2], b = COL.bg[3], a = 0.97 }
    o.borderColor = { r = COL.border[1], g = COL.border[2], b = COL.border[3], a = 1 }
    o.lastEval, o.scroll = 0, 0
    return o
end

function Prep:createChildren()
    ISPanel.createChildren(self)
    local bh = fh() + 12
    self.startBtn = ISButton:new(0, 0, 120, bh, S.T("Start", "Start"), self, Prep.onStart)
    self.startBtn:initialise(); self:addChild(self.startBtn)
    self.closeBtn = ISButton:new(0, 0, 100, bh, S.T("Close", "Close"), self, Prep.close)
    self.closeBtn:initialise(); self:addChild(self.closeBtn)
end

-- vertical metrics
function Prep:metrics()
    local m = {}
    m.pad = 14
    m.title = m.pad
    m.sub = m.title + fh(FONT_M) + 4
    m.tabsTop = m.sub + fh() + 10
    m.tabH = fh() + 10
    local rects, x, y = {}, m.pad, m.tabsTop
    for _, sid in ipairs(self.list) do
        local label = S.T("Name_" .. sid, sid)
        local w = math.min(self.width - m.pad * 2, tw(label) + 28)
        if x + w > self.width - m.pad and x > m.pad then x = m.pad; y = y + m.tabH + 6 end
        rects[#rects + 1] = { sid = sid, x = x, y = y, w = w, h = m.tabH, label = label }
        x = x + w + 6
    end
    m.tabs = rects
    m.listTop = y + m.tabH + 12
    m.rowH = fh() + 10
    m.footerH = fh() * 2 + 30
    return m
end

function Prep:layout()
    local m = self:metrics()
    local rows = self.eval and #self.eval.rows or 12
    local want = m.listTop + rows * m.rowH + m.footerH + 8
    local maxH = getCore():getScreenHeight() - 40
    local h = math.min(want, maxH)
    if h ~= self.height then self:setHeight(h) end
    if not self.placed then
        self.placed = true
        self:setX((getCore():getScreenWidth() - self.width) / 2)
        self:setY(math.max(10, (getCore():getScreenHeight() - h) / 2))
    end
    self.listH = self.height - m.listTop - m.footerH
    self.maxScroll = math.max(0, rows * m.rowH - self.listH)
    if self.scroll > self.maxScroll then self.scroll = self.maxScroll end
    local by = self.height - self.startBtn.height - 10
    self.startBtn:setX(self.width - 238); self.startBtn:setY(by)
    self.closeBtn:setX(self.width - 112); self.closeBtn:setY(by)
    self.m = m
end

function Prep:reevaluate(force)
    local t = nowMs()
    if not force and t - self.lastEval < 800 then return end
    self.lastEval = t
    self.eval = S.evaluate(self.doctor, self.patient, self.bodyPart, self.sid, self.exam)
    self:layout()
    local unlocked = S.surgeryUnlocked(self.doctor, self.sid)
    self.startBtn:setEnable(self.eval.canStart and unlocked and not self.waiting)
end

function Prep:prerender()
    ISPanel.prerender(self)
    self:reevaluate(false)
    local m = self.m or self:metrics()
    self:drawText(fit(S.T("Title_Prep", "Pre-op checklist"), self.width - 2 * m.pad, FONT_M), m.pad, m.title, COL.text[1], COL.text[2], COL.text[3], 1, FONT_M)
    local who = self.doctor == self.patient and S.T("Self", "Yourself")
        or (self.patient.getDisplayName and self.patient:getDisplayName() or "?")
    local part = BodyPartType and BodyPartType.getDisplayName and self.bodyPart and BodyPartType.getDisplayName(self.bodyPart:getType()) or tostring(self.partName)
    self:drawText(fit(who .. "  ·  " .. part, self.width - 2 * m.pad), m.pad, m.sub, COL.dim[1], COL.dim[2], COL.dim[3], 1, FONT)

    self.hoverTip = nil
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, r in ipairs(m.tabs) do
        local active = r.sid == self.sid
        local unlocked = S.surgeryUnlocked(self.doctor, r.sid)
        local c = active and COL.accent or COL.border
        self:drawRect(r.x, r.y, r.w, r.h, active and 0.35 or 0.15, c[1], c[2], c[3])
        self:drawRectBorder(r.x, r.y, r.w, r.h, 1, c[1], c[2], c[3])
        local tc = unlocked and COL.text or COL.dim
        self:drawText(fit((unlocked and "" or "# ") .. r.label, r.w - 16), r.x + 8, r.y + 5, tc[1], tc[2], tc[3], 1, FONT)
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            local sd = S.Surgeries[r.sid]
            self.hoverTip = S.T("Tip_Surgery_" .. r.sid, "") .. "\n\n" .. S.targetsTip(r.sid)
                .. "\n\n" .. S.T("Tier_" .. sd.tier, sd.tier)
                .. (unlocked and "" or ("\n" .. S.T("Tip_LockedSurgery", "Locked.")))
        end
    end

    -- rows (scrolled, clipped to the list area)
    local top, rowH = m.listTop, m.rowH
    local labelW = math.floor((self.width - 60) * 0.5)
    local valueW = self.width - 60 - labelW - 16
    self:setStencilRect(0, top, self.width, self.listH)
    local y = top - self.scroll
    for i, row in ipairs(self.eval and self.eval.rows or {}) do
        if y + rowH >= top and y <= top + self.listH then
            local c = COL[row.state] or COL.dim
            local hovered = my >= math.max(y, top) and my < math.min(y + rowH, top + self.listH) and mx >= 8 and mx <= self.width - 8
            if hovered then
                self:drawRect(8, y, self.width - 16, rowH, 0.25, COL.accent[1], COL.accent[2], COL.accent[3])
                self.hoverTip = row.tip
            elseif (i % 2) == 0 then
                self:drawRect(8, y, self.width - 16, rowH, 0.35, COL.panel[1], COL.panel[2], COL.panel[3])
            end
            self:drawRect(16, y + 4, 14, rowH - 8, 0.9, c[1], c[2], c[3])
            self:drawTextCentre(STATE_MARK[row.state] or "?", 23, y + (rowH - fh()) / 2, 0, 0, 0, 1, FONT)
            local label = row.label .. (row.required and "" or ("  (" .. S.T("Optional", "optional") .. ")"))
            self:drawText(fit(label, labelW), 40, y + (rowH - fh()) / 2, COL.text[1], COL.text[2], COL.text[3], 1, FONT)
            local v = fit(row.value, valueW)
            self:drawText(v, self.width - 20 - tw(v), y + (rowH - fh()) / 2, c[1], c[2], c[3], 1, FONT)
        end
        y = y + rowH
    end
    self:clearStencilRect()
    if self.maxScroll > 0 then
        local barH = math.max(20, self.listH * self.listH / (self.listH + self.maxScroll))
        local barY = top + (self.listH - barH) * (self.scroll / self.maxScroll)
        self:drawRect(self.width - 6, barY, 3, barH, 0.8, COL.accent[1], COL.accent[2], COL.accent[3])
    end

    local status = self.status
    if not status and self.eval and not self.eval.canStart then status = S.T("NotReady", "Fix the red rows to start.") end
    local fy = self.height - m.footerH + 6
    self:drawText(fit(S.T("HoverHint", "Point at a row for details."), self.width - 260), m.pad, fy, COL.dim[1], COL.dim[2], COL.dim[3], 0.8, FONT)
    if status then self:drawText(fit(status, self.width - 260), m.pad, fy + fh() + 4, COL.warn[1], COL.warn[2], COL.warn[3], 1, FONT) end
end

function Prep:render()
    ISPanel.render(self)
    drawTooltip(self, self.hoverTip)
end

function Prep:onMouseWheel(del)
    if (self.maxScroll or 0) <= 0 then return false end
    self.scroll = math.max(0, math.min(self.maxScroll, self.scroll + del * (self.m and self.m.rowH or 20) * 2))
    return true
end

function Prep:onMouseDown(x, y)
    for _, r in ipairs(self.m and self.m.tabs or {}) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            self.sid = r.sid; self.status = nil; self.scroll = 0
            self:reevaluate(true)
            return true
        end
    end
    return ISPanel.onMouseDown(self, x, y)
end

function Prep:onStart()
    self:reevaluate(true)
    if not self.eval.canStart then return end
    self.waiting = true
    self.status = S.T("Preparing", "Preparing...")
    C.request(self.doctor, self.patient, self.partName, self.sid)
end

function Prep:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if C.prep == self then C.prep = nil end
end

function C.openPrep(doctor, patient, bodyPart, sid, exam)
    if C.prep then C.prep:close() end
    local list = C.surgeriesFor(doctor, patient, bodyPart, exam)
    if #list == 0 then list = { sid } end
    local ui = Prep:new(doctor, patient, bodyPart, sid or list[1], exam, list)
    ui:initialise()
    ui:addToUIManager()
    ui:reevaluate(true)
    C.prep = ui
end

-- ============================================================= OPERATING
HM_SurgeryOpUI = ISPanel:derive("HM_SurgeryOpUI")
local Op = HM_SurgeryOpUI

function Op:new(doctor, info)
    local w = 680
    local h = math.min(560, getCore():getScreenHeight() - 40)
    local x = (getCore():getScreenWidth() - w) / 2
    local y = (getCore():getScreenHeight() - h) / 2
    local o = ISPanel.new(self, x, y, w, h)
    o.doctor, o.info = doctor, info
    o.sid = info.sid
    o.steps = S.Surgeries[info.sid].steps
    o.stepIndex, o.scores = 0, {}
    o.params = { skill = tonumber(info.skill) or 0, shake = tonumber(info.shake) or 0, tool = tonumber(info.tool) or 1 }
    o.backgroundColor = { r = COL.bg[1], g = COL.bg[2], b = COL.bg[3], a = 0.97 }
    o.borderColor = { r = COL.border[1], g = COL.border[2], b = COL.border[3], a = 1 }
    o.moveWithMouse = true   -- drag by the title bar / edges (not the board)
    o.last = nowMs()
    -- measured layout: title, chips, instruction, board, timer, footer
    local top = 10 + fh(FONT_M) + 8
    o.chipY, o.chipH = top, fh() + 8
    o.instrY = top + o.chipH + 8
    local boardY = o.instrY + fh() + 8
    local footer = fh() + 14 + 28 + 10
    o.board = { x = 20, y = boardY, w = w - 40, h = h - boardY - footer - 16 }
    return o
end

function Op:createChildren()
    ISPanel.createChildren(self)
    local bh = fh() + 12
    self.abortBtn = ISButton:new(self.width - 112, self.height - bh - 10, 100, bh, S.T("Abort", "Abort"), self, Op.onAbort)
    self.abortBtn:initialise(); self:addChild(self.abortBtn)
    self:nextStep()
end

function Op:nextStep()
    self.stepIndex = self.stepIndex + 1
    if self.stepIndex > #self.steps then self:finish(false); return end
    local proc = S.Procedures[self.steps[self.stepIndex]]
    local p = { variant = proc.variant, tier = S.TIERS[proc.tier].order }
    for k, v in pairs(self.params) do p[k] = v end
    self.game = G.new(proc.game, p)
    self.pause = 0
end

-- chip labels: full names if they fit, else English names only, else numbers
function Op:chips()
    local avail = self.width - 32
    local function build(mode)
        local out, total = {}, 0
        for n, pid in ipairs(self.steps) do
            local label
            if mode == 1 then label = n .. ". " .. S.T("Proc_" .. pid, pid)
            elseif mode == 2 then label = n .. ". " .. S.T("ProcShort_" .. pid, pid)
            else label = tostring(n) end
            local w = tw(label) + 16
            out[n] = { label = label, w = w }
            total = total + w + 4
        end
        return out, total
    end
    for mode = 1, 3 do
        local out, total = build(mode)
        if total <= avail or mode == 3 then return out end
    end
end

function Op:finish(aborted)
    if self.sent then return end
    self.sent = true
    self.game = nil
    self.waiting = true
    self.waitSince = nowMs()
    -- button first: in single player the result arrives inside send()
    -- (and enables it again); disabling it afterwards locked the window
    self.abortBtn:setTitle(S.T("Close", "Close"))
    self.abortBtn:setEnable(false)
    local args = { permit = self.info.permit, scores = self.scores, aborted = aborted == true }
    send(aborted and "Abort" or "Finish", args)
end

function Op:onAbort()
    if self.result or (self.sent and not self.waiting) then self:close(); return end
    self:finish(true)
end

function Op:showResult(args)
    self.waiting = false
    self.result = args
    self.abortBtn:setEnable(true)
    self.done = true
end

function Op:update()
    ISPanel.update(self)
    local t = nowMs()
    local dt = math.min(100, t - self.last)
    self.last = t
    -- no answer from the server: let the player close the window anyway
    if self.waiting and self.waitSince and t - self.waitSince > 6000 then
        self.waiting = false
        self.abortBtn:setEnable(true)
    end
    if self.game then
        if self.pause > 0 then
            self.pause = self.pause - dt
            if self.pause <= 0 then self:nextStep() end
        else
            self.game:update(dt)
            if self.game.done then
                self.scores[self.stepIndex] = self.game:score()
                self.pause = 700
            end
        end
    end
end

local GRADE_COL = { Excellent = COL.ok, Success = COL.ok, Failed = COL.fail, Aborted = COL.warn }

function Op:prerender()
    ISPanel.prerender(self)
    self:drawText(fit(S.T("Name_" .. self.sid, self.sid), self.width - 32, FONT_M), 16, 10, COL.text[1], COL.text[2], COL.text[3], 1, FONT_M)
    self.hoverTip = nil
    local mx, my = self:getMouseX(), self:getMouseY()
    local x = 16
    for n, chip in ipairs(self:chips()) do
        local pid = self.steps[n]
        local c = n < self.stepIndex and COL.ok or (n == self.stepIndex and COL.accent or COL.border)
        self:drawRect(x, self.chipY, chip.w, self.chipH, n == self.stepIndex and 0.35 or 0.15, c[1], c[2], c[3])
        self:drawRectBorder(x, self.chipY, chip.w, self.chipH, 1, c[1], c[2], c[3])
        self:drawText(chip.label, x + 8, self.chipY + 4, COL.text[1], COL.text[2], COL.text[3], 1, FONT)
        if mx >= x and mx <= x + chip.w and my >= self.chipY and my <= self.chipY + self.chipH then
            self.hoverTip = S.T("Proc_" .. pid, pid) .. "\n" .. S.T("Tip_" .. pid, "")
        end
        x = x + chip.w + 4
    end
    local b = self.board
    if self.result then
        self:drawResult(b)
    elseif self.waiting then
        self:drawTextCentre(S.T("Waiting", "Waiting for the result..."), self.width / 2, b.y + b.h / 2, COL.dim[1], COL.dim[2], COL.dim[3], 1, FONT_M)
    elseif self.game then
        local proc = S.Procedures[self.steps[self.stepIndex]]
        local key = "Game_" .. proc.game .. (proc.variant and ("_" .. proc.variant) or "")
        self:drawText(fit(S.T(key, S.T("Game_" .. proc.game, "")), self.width - 32), 16, self.instrY, COL.warn[1], COL.warn[2], COL.warn[3], 1, FONT)
        self.game:render(self, b.x, b.y, b.w, b.h)
        if self.pause > 0 then
            local sc = math.floor((self.scores[self.stepIndex] or 0) * 100 + 0.5)
            local bandH = fh(FONT_M) + 16
            self:drawRect(b.x, b.y + b.h / 2 - bandH / 2, b.w, bandH, 0.75, 0, 0, 0)
            self:drawTextCentre(S.T("StepScore", "Step score: %1%", sc), self.width / 2, b.y + b.h / 2 - fh(FONT_M) / 2, COL.text[1], COL.text[2], COL.text[3], 1, FONT_M)
        end
        if self.game.limit then
            local f = self.game:timeLeft() / self.game.limit
            self:drawRect(b.x, b.y + b.h + 6, b.w, 8, 0.6, 0.15, 0.15, 0.15)
            local c = f > 0.3 and COL.accent or COL.fail
            self:drawRect(b.x, b.y + b.h + 6, b.w * f, 8, 1, c[1], c[2], c[3])
        end
    end
    local sx = 16
    local sy = self.height - fh() - 18
    for n = 1, #self.steps do
        local v = self.scores[n]
        if v then
            local c = v >= 0.75 and COL.ok or (v >= 0.45 and COL.warn or COL.fail)
            local txt = n .. ": " .. math.floor(v * 100 + 0.5) .. "%"
            if sx + tw(txt) < self.width - 130 then self:drawText(txt, sx, sy, c[1], c[2], c[3], 1, FONT) end
            sx = sx + tw(txt) + 14
        end
    end
end

function Op:drawResult(b)
    local r = self.result
    local c = GRADE_COL[r.grade] or COL.text
    local y = b.y + 10
    local maxW = b.w - 20
    self:drawText(S.T("Grade_" .. tostring(r.grade), tostring(r.grade)) .. "  (" .. math.floor((tonumber(r.quality) or 0) * 100 + 0.5) .. "%)",
        b.x + 10, y, c[1], c[2], c[3], 1, FONT_M)
    y = y + fh(FONT_M) + 10
    local function line(text, col)
        col = col or COL.text
        for _, l in ipairs(wrap(text, maxW)) do
            if y + fh() > b.y + b.h then return end
            self:drawText(l, b.x + 10, y, col[1], col[2], col[3], 1, FONT)
            y = y + fh() + 2
        end
        y = y + 2
    end
    if r.changes and #r.changes > 0 then
        for _, ch in ipairs(r.changes) do
            local name = S.T("Cond_" .. tostring(ch.id), tostring(ch.id))
            local kind = tostring(ch.kind)
            if kind == "treat" then line(S.T("Res_Treat", "%1: treated, clears in ~%2h", name, ch.hours or "?"), COL.ok)
            elseif kind == "rejected" then line(S.T("Res_rejected", "%1: rejected", name), COL.fail)
            elseif kind == "failed" then line(S.T("Res_failed", "%1: no effect", name), COL.warn)
            else line(S.T("Res_" .. kind, "%1: " .. kind, name), COL.ok) end
        end
    else
        line(S.T("Res_NoChange", "Nothing improved."), COL.warn)
    end
    line(S.T("Res_Blood", "Blood lost: %1 mL", r.blood or 0), COL.dim)
    line(S.T("Res_Pain", "Pain: +%1", r.pain or 0), COL.dim)
    if r.infected then line(S.T("Res_Infected", "Surgical-site infection: Cellulitis!"), COL.fail) end
    if r.aspirated then line(S.T("Res_Aspirated", "The patient vomited and breathed it in: aspiration pneumonia!"), COL.fail) end
    line(S.T("Res_XP", "First Aid XP +%1", r.xp or 0), COL.info)
    line(S.T("Res_Aftercare", "Keep the wound dressed."), COL.dim)
end

function Op:render()
    ISPanel.render(self)
    drawTooltip(self, self.hoverTip)
end

local function inBoard(self, x, y)
    local b = self.board
    return x >= b.x and y >= b.y and x <= b.x + b.w and y <= b.y + b.h
end
function Op:onMouseDown(x, y)
    if self.game and self.pause <= 0 and inBoard(self, x, y) then self.game:mouseDown(x, y); return true end
    return ISPanel.onMouseDown(self, x, y)
end
function Op:onMouseUp(x, y)
    if self.game then self.game:mouseUp(x, y) end
    return ISPanel.onMouseUp(self, x, y)
end
function Op:onMouseUpOutside(x, y)
    if self.game then self.game:mouseUp(x, y) end
    return ISPanel.onMouseUpOutside(self, x, y)
end
function Op:onMouseMove(dx, dy)
    if self.moving then return ISPanel.onMouseMove(self, dx, dy) end
    if self.game and self.pause <= 0 then self.game:mouseMove(self:getMouseX(), self:getMouseY()) end
end
function Op:onMouseMoveOutside(dx, dy)
    if self.moving then return ISPanel.onMouseMoveOutside(self, dx, dy) end
    if self.game and self.pause <= 0 then self.game:mouseMove(self:getMouseX(), self:getMouseY()) end
end

function Op:close()
    if not self.sent then self:finish(true) end
    self:setVisible(false)
    self:removeFromUIManager()
    if C.op == self then C.op = nil end
end

-- ============================================================= ACTION
HM_SurgeryAction = ISBaseTimedAction:derive("HM_SurgeryAction")

function HM_SurgeryAction:new(doctor, patient, info)
    local o = ISBaseTimedAction.new(self, doctor)
    o.patient, o.info = patient, info
    o.maxTime = -1
    o.stopOnWalk, o.stopOnRun, o.stopOnAim = true, true, true
    return o
end
function HM_SurgeryAction:isValid()
    return self.patient ~= nil and S.distance(self.character, self.patient) <= S.MAX_DISTANCE + 0.5
end
function HM_SurgeryAction:waitToStart()
    if self.patient ~= self.character then self.character:faceThisObject(self.patient) end
    return self.character:shouldBeTurning()
end
function HM_SurgeryAction:start()
    pcall(function()
        self:setActionAnim(CharacterActionAnims and CharacterActionAnims.Bandage or "Loot")
        self:setAnimVariable("BandageType", "UpperBody")
    end)
    if C.op then C.op:close() end
    local ui = Op:new(self.character, self.info)
    ui:initialise()
    ui:addToUIManager()
    C.op = ui
    self.ui = ui
end
function HM_SurgeryAction:update()
    if self.patient ~= self.character then self.character:faceThisObject(self.patient) end
    if self.ui and (self.ui.sent or not self.ui:isVisible()) then self:forceComplete() end
end
function HM_SurgeryAction:stop()
    if self.ui and not self.ui.sent then self.ui:finish(true) end
    ISBaseTimedAction.stop(self)
end
function HM_SurgeryAction:perform()
    ISBaseTimedAction.perform(self)
end

-- ============================================================= requests
function C.request(doctor, patient, partName, sid)
    C.doctor = doctor
    C.pending = { patient = patient, sid = sid, part = partName }
    local args = { sid = sid, part = partName }
    if isClient and isClient() then
        if patient ~= doctor then args.patientOnline = patient:getOnlineID() end
    else
        args.patientNum = patient:getPlayerNum()
    end
    send("Begin", args)
end

function C.onServerCommand(module, command, args)
    if module ~= MODULE then return end
    args = args or {}
    if command == "Denied" then
        local text = S.T("Denied_" .. tostring(args.reason), S.T("Denied_NotReady", "Not ready."))
        if C.prep then C.prep.waiting = false; C.prep.status = text; C.prep:reevaluate(true) end
        local d = C.doctor or getPlayer()
        if d and d.setHaloNote then d:setHaloNote(text, 255, 90, 90, 250) end
    elseif command == "Begin" then
        local p = C.pending
        if not p then return end
        if C.prep then C.prep:close() end
        S.Sources.forget()
        ISTimedActionQueue.add(HM_SurgeryAction:new(C.doctor or getPlayer(), p.patient, args))
    elseif command == "Result" then
        if C.op and C.op.info and C.op.info.permit == args.permit then C.op:showResult(args) end
        S.Sources.forget()
    end
end

if Events and Events.OnServerCommand and not C.registered then
    C.registered = true
    Events.OnServerCommand.Add(C.onServerCommand)
end

-- ============================================================= menus
local function menuFor(context, doctor, patient, bodyPart, exam)
    if not context or not doctor or not patient or not bodyPart then return false end
    if SandboxVars and SandboxVars.HomeMedic and SandboxVars.HomeMedic.SurgeryEnabled == false then return false end
    local list = C.surgeriesFor(doctor, patient, bodyPart, exam)
    local first = list[1]
    if not first then return false end
    local opt = context:addOption(S.T("Menu", "Surgery"), doctor, C.openPrep, patient, bodyPart, first, exam)
    if ISToolTip then
        local tip = ISToolTip:new()
        tip:initialise()
        tip:setVisible(false)
        tip.description = S.T("MenuTip", "Open the pre-op checklist.")
        opt.toolTip = tip
    end
    return true
end
C.menuFor = menuFor

function C.install()
    if C.installed then return end
    C.installed = true
    if ISHealthPanel and ISHealthPanel.doBodyPartContextMenu then
        local orig = ISHealthPanel.doBodyPartContextMenu
        ISHealthPanel.doBodyPartContextMenu = function(self, bodyPart, x, y, ...)
            local r = orig(self, bodyPart, x, y, ...)
            local patient = self.character
            local doctor = self.otherPlayer or self.character
            local pn = doctor and doctor.getPlayerNum and doctor:getPlayerNum() or 0
            local context = getPlayerContextMenu and getPlayerContextMenu(pn)
            if context and menuFor(context, doctor, patient, bodyPart, nil) then
                context:setVisible(true)
                context:bringToTop()
            end
            return r
        end
    end
    if EHR_HealthPanelUI and EHR_HealthPanelUI.openRemoteBodyPartContextMenu then
        local orig = EHR_HealthPanelUI.openRemoteBodyPartContextMenu
        function EHR_HealthPanelUI:openRemoteBodyPartContextMenu(bodyPart, x, y, bodyPartType)
            local shown = orig(self, bodyPart, x, y, bodyPartType)
            if not self.isRemoteHealthPanel or not bodyPart then return shown end
            local doctor = self.remoteDoctor
            local pn = self.playerNum or (doctor and doctor:getPlayerNum()) or 0
            local context
            if shown then context = getPlayerContextMenu(pn)
            else
                context = ISContextMenu.get(pn, x + self:getAbsoluteX(), y + self:getAbsoluteY())
                context.origin = self.bodyPartPanel or self
            end
            if context and menuFor(context, doctor, self.player, bodyPart, self.remoteExamData) then
                context:setVisible(true)
                context:bringToTop()
                return true
            end
            if not shown and context then context:setVisible(false) end
            return shown
        end
    end
end

if Events and Events.OnGameStart then Events.OnGameStart.Add(C.install) end

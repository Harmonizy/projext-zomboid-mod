--[[
    HARMONIE - Home Medic : the medical window's 6th tab, "Surgery" (client)

    Left: every operation (S.SURGERY_ORDER). One is open (clickable) when the
    patient needs it -- some body part has an indication for it right now.
    Right: the pre-op checklist of the picked operation (HM_SurgeryPrepUI in
    embedded mode), with the body parts it can be done on as chips. Start ->
    the server checks again -> the operating window (minigames) pops up and
    stays until the operation is done.

    The body-part menu's "Surgery" opens this tab with that operation and
    part selected (panel.hmSurgerySelect = { sid, part }); the first tab's
    "Surgery" button does the same (panel.hmSurgerySelect = { sid, id }).
]]--

require "ExtensiveHealth/EHR_HealthPanelUI"
require "HARMONIEHomeMedic/Surgery/HM_Surgery"
require "HARMONIEHomeMedic/Surgery/HM_SurgeryUI"

local S = HM_Surgery
local C = S.Client
local FONT, FONT_M = UIFont.Small, UIFont.Medium
local function fh(f) return getTextManager():getFontHeight(f or FONT) end
local function tw(t, f) return getTextManager():MeasureStringX(f or FONT, t or "") end
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end
local function inside(mx, my, x, y, w, h) return mx >= x and mx <= x + w and my >= y and my <= y + h end

local PARTS = {
    "Head", "Neck", "Torso_Upper", "Torso_Lower", "Groin",
    "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Hand_L", "Hand_R",
    "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R", "Foot_L", "Foot_R",
}

local function parties(panel)
    local exam = panel.isRemoteHealthPanel and panel.remoteExamData or nil
    local doctor = panel.isRemoteHealthPanel and panel.remoteDoctor or panel.player
    return doctor, panel.player, exam
end

local function partLabel(part, name)
    if BodyPartType and BodyPartType.getDisplayName and part and part.getType then
        local ok, n = pcall(function() return BodyPartType.getDisplayName(part:getType()) end)
        if ok and n then return n end
    end
    return name
end

-- sid -> { parts = { {part, name} }, unlocked, why } (cached 1 s)
local function scan(panel)
    local st = panel.hmSurg
    if st.scanAt and nowMs() - st.scanAt < 1000 then return st.scan end
    local doctor, patient, exam = parties(panel)
    local out = {}
    for _, sid in ipairs(S.SURGERY_ORDER) do
        local sd = S.Surgeries[sid]
        local e = { parts = {} }
        e.unlocked, e.why = S.surgeryUnlocked(doctor, sid)
        if not (sd.needsTOC and not S.tocAvailable()) and not sd.planned then
            for _, name in ipairs(sd.parts or PARTS) do
                local part = S.partByName(patient, name)
                if part then
                    local ok, ind = pcall(S.indications, patient, part, sid, exam)
                    local usable = false
                    for _, i in ipairs(ok and ind or {}) do if not i.cool and not i.undiagnosed then usable = true end end
                    if usable then e.parts[#e.parts + 1] = { part = part, name = partLabel(part, name), key = name } end
                end
            end
        end
        out[sid] = e
    end
    st.scan, st.scanAt = out, nowMs()
    return out
end

local function bounds(panel)
    local b = panel:getTabContentBounds()
    local listW = math.max(220, math.min(320, math.floor(b.w * 0.32)))
    return b, listW
end

local function dropPrep(panel)
    local st = panel.hmSurg
    if st.prep then
        if C.prep == st.prep then C.prep = nil end
        panel:removeChild(st.prep)
        st.prep = nil
    end
end

local function select(panel, sid, partKey)
    local st = panel.hmSurg
    local info = scan(panel)[sid]
    if not info or #info.parts == 0 then return false end
    local chosen = info.parts[1]
    for _, p in ipairs(info.parts) do if p.key == partKey then chosen = p end end
    dropPrep(panel)
    local doctor, patient, exam = parties(panel)
    local b, listW = bounds(panel)
    local px, py = b.x + listW + 14, b.y + 48
    local prep = HM_SurgeryPrepUI:new(doctor, patient, chosen.part, sid, exam, { sid },
        { embedded = true, parts = info.parts, x = px, y = py, w = b.x + b.w - 8 - px, h = b.h - 56 })
    prep:initialise()
    prep:instantiate()
    panel:addChild(prep)
    prep:reevaluate(true)
    st.prep, st.sid = prep, sid
    return true
end

local function draw(panel)
    local st = panel.hmSurg
    local c = EHR_HealthPanelUI.Colors
    local b, listW = bounds(panel)
    panel:drawPanelFrame(b.x, b.y, b.w, b.h, S.T("Tab_Title", "SURGERY"), nil)
    local info = scan(panel)
    local top = b.y + 48
    local x, w = b.x + 12, listW
    local rowH = fh(FONT_M) + fh() + 14
    local mx, my = panel:getLocalMousePosition()
    st.rows, st.tip = {}, nil
    local y = top
    for _, sid in ipairs(S.SURGERY_ORDER) do
        local e = info[sid] or { parts = {} }
        local needed = #e.parts > 0
        local active = st.sid == sid
        local hov = needed and inside(mx, my, x, y, w, rowH - 4)
        local bg = active and c.accentDark or c.panelSoft
        panel:drawRect(x, y, w, rowH - 4, active and 0.95 or (hov and 0.7 or 0.4), bg.r, bg.g, bg.b)
        local bd = active and c.accent or c.borderDim
        panel:drawRectBorder(x, y, w, rowH - 4, 1, bd.r, bd.g, bd.b)
        local tc = needed and c.text or c.textDim
        -- the operation's picture on the left of the row
        local tx = x + 8
        local tex = C.cardTexture and C.cardTexture(sid)
        if tex then
            local th = rowH - 12
            local twd = math.floor(th * 16 / 9)
            panel:drawTextureScaled(tex, x + 4, y + 4, twd, th, needed and 1 or 0.45, 1, 1, 1)
            tx = x + 4 + twd + 8
        end
        panel:drawText(S.fitText(S.T("Name_" .. sid, sid), x + w - 8 - tx, function(t) return tw(t, FONT_M) end), tx, y + 4, tc.r, tc.g, tc.b, 1, FONT_M)
        local state, sc
        if needed and e.unlocked then state, sc = S.T("Tab_Needed", "Needed: %1", #e.parts), c.green
        elseif needed then state, sc = S.T("Tab_NeededLocked", "Needed - locked"), c.yellow
        else state, sc = S.T("Tab_NotNeeded", "Not needed now"), c.textDim end
        panel:drawText(S.fitText(state, x + w - 8 - tx, function(t) return tw(t) end), tx, y + 6 + fh(FONT_M), sc.r, sc.g, sc.b, 1, FONT)
        if inside(mx, my, x, y, w, rowH - 4) then
            st.tip = S.T("Tip_Surgery_" .. sid, "") .. "\n\n" .. S.targetsTip(sid)
        end
        st.rows[#st.rows + 1] = { x = x, y = y, w = w, h = rowH - 4, sid = sid, needed = needed }
        y = y + rowH
    end
    if not st.prep then
        local hint = S.T("Tab_Pick", "Pick an operation on the left. It opens when the patient needs it.")
        local hx = b.x + listW + 26
        for i, l in ipairs(S.wrap(hint, b.x + b.w - hx - 20, FONT)) do
            panel:drawText(l, hx, top + 8 + (i - 1) * (fh() + 2), c.textDim.r, c.textDim.g, c.textDim.b, 1, FONT)
        end
    end
end

local function tooltip(panel)
    local text = panel.hmSurg and panel.hmSurg.tip
    if not text or text == "" or not panel.drawDiagnosisTooltip then return end
    local keep = panel.dxState
    panel.dxState = { tip = text }
    panel:drawDiagnosisTooltip()
    panel.dxState = keep
end

EHR_HealthPanelUI.ExtraTabs = EHR_HealthPanelUI.ExtraTabs or {}
EHR_HealthPanelUI.ExtraTabs.surgery = {
    open = function(panel)
        panel.hmSurg = panel.hmSurg or {}
        panel.hmSurg.scanAt = nil
        local want = panel.hmSurgerySelect
        panel.hmSurgerySelect = nil
        if want and want.sid then
            select(panel, want.sid, want.part)
        elseif panel.hmSurg.sid and not panel.hmSurg.prep then
            select(panel, panel.hmSurg.sid)
        end
    end,
    draw = function(panel)
        panel.hmSurg = panel.hmSurg or {}
        draw(panel)
    end,
    render = tooltip,
    mouseDown = function(panel, x, y)
        local st = panel.hmSurg
        for _, r in ipairs(st and st.rows or {}) do
            if inside(x, y, r.x, r.y, r.w, r.h) then
                if r.needed then select(panel, r.sid) end
                return true
            end
        end
        return false
    end,
    sync = function(panel, shown)
        local st = panel.hmSurg
        local prep = st and st.prep
        if not prep then return end
        if shown then
            local b, listW = bounds(panel)
            local px, py = b.x + listW + 14, b.y + 48
            local pw, ph = b.x + b.w - 8 - px, b.h - 56
            if prep:getX() ~= px or prep:getY() ~= py then prep:setX(px); prep:setY(py) end
            if prep:getWidth() ~= pw or prep:getHeight() ~= ph then
                prep:setWidth(pw); prep:setHeight(ph); prep:layout()
            end
        end
        if prep:isVisible() ~= shown then prep:setVisible(shown) end
    end,
}

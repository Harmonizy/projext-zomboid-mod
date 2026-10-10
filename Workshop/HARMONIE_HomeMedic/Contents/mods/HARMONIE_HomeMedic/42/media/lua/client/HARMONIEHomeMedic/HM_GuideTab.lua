--[[
    HARMONIE - How to Survive : the medical window's "Medical Guide" tab (client)

    Owner, 2026-10-11: "เพิ่มแท็บ คู่มือการแพทย์ ใน HTS". How the medical
    systems of this mod work, in plain words: left a list of chapters,
    right the chapter (wrapped to the width, scrolls with the wheel or by
    dragging the shared scroll bar).

    Texts: UI_HomeMedic_Guide_<chapter>_Title and _P1, _P2, ... (one key per
    paragraph, read until the first missing one).
]]--

require "HARMONIEHomeMedic/HM_Text"
require "ExtensiveHealth/EHR_HealthPanelUI"
require "HARMONIEHomeMedic/Surgery/HM_Surgery"
pcall(require, "HARMONIE_UIKit")

local S = HM_Surgery
local FONT, FONT_M = UIFont.Small, UIFont.Medium
local function fh(f) return getTextManager():getFontHeight(f or FONT) end
local function tw(t, f) return getTextManager():MeasureStringX(f or FONT, t or "") end
local function inside(mx, my, x, y, w, h) return mx >= x and mx <= x + w and my >= y and my <= y + h end
local function L(key, fallback) return HM_Text("UI_HomeMedic_Guide_" .. key, fallback or "") end

local CHAPTERS = { "start", "blood", "diagnosis", "meds", "surgery", "stats", "toc", "window" }
local MAX_P = 12

local function paragraphs(id)
    local out = {}
    for i = 1, MAX_P do
        local t = L(id .. "_P" .. i, "")
        if t == "" or t == "UI_HomeMedic_Guide_" .. id .. "_P" .. i then break end
        out[#out + 1] = t
    end
    return out
end

local function layout(panel)
    local b = panel:getTabContentBounds()
    local listW = math.max(180, math.min(260, math.floor(b.w * 0.26)))
    return b, listW
end

local function draw(panel)
    local st = panel.hmGuide
    local c = EHR_HealthPanelUI.Colors
    local b, listW = layout(panel)
    panel:drawPanelFrame(b.x, b.y, b.w, b.h, L("Title", "MEDICAL GUIDE"), nil)
    local top = b.y + 48
    local mx, my = panel:getLocalMousePosition()

    -- the chapters
    local x, y = b.x + 12, top
    local rowH = fh(FONT_M) + 12
    st.rows = {}
    for _, id in ipairs(CHAPTERS) do
        local active = st.id == id
        local hov = inside(mx, my, x, y, listW, rowH - 4)
        local bg = active and c.accentDark or c.panelSoft
        panel:drawRect(x, y, listW, rowH - 4, active and 0.95 or (hov and 0.7 or 0.4), bg.r, bg.g, bg.b)
        local bd = active and c.accent or c.borderDim
        panel:drawRectBorder(x, y, listW, rowH - 4, 1, bd.r, bd.g, bd.b)
        local title = S.fitText(L(id .. "_Title", id), listW - 16, function(t) return tw(t, FONT_M) end)
        panel:drawText(title, x + 8, y + 4, c.text.r, c.text.g, c.text.b, 1, FONT_M)
        st.rows[#st.rows + 1] = { x = x, y = y, w = listW, h = rowH - 4, id = id }
        y = y + rowH
    end

    -- the chapter
    local px = b.x + listW + 26
    local pw = b.x + b.w - px - 22
    local ph = b.y + b.h - top - 12
    if pw < 80 or ph < 40 then return end
    if st.wrapW ~= pw or st.wrapId ~= st.id then
        st.lines, st.wrapW, st.wrapId = {}, pw, st.id
        local lineH = fh() + 2
        st.lines[#st.lines + 1] = { t = L(st.id .. "_Title", st.id), font = FONT_M, h = fh(FONT_M) + 8, title = true }
        for _, p in ipairs(paragraphs(st.id)) do
            for _, l in ipairs(S.wrap(p, pw, FONT)) do st.lines[#st.lines + 1] = { t = l, font = FONT, h = lineH } end
            st.lines[#st.lines + 1] = { t = "", font = FONT, h = math.floor(lineH / 2) }
        end
        local total = 0
        for _, l in ipairs(st.lines) do total = total + l.h end
        st.total = total
    end
    st.view = { x = px, y = top, w = pw, h = ph }
    st.maxScroll = math.max(0, (st.total or 0) - ph)
    st.scroll = math.max(0, math.min(st.maxScroll, st.scroll or 0))
    panel:setStencilRect(px, top, pw, ph)
    local ty = top - st.scroll
    for _, l in ipairs(st.lines) do
        if ty + l.h >= top and ty <= top + ph and l.t ~= "" then
            local col = l.title and c.accent or c.text
            panel:drawText(l.t, px, ty, col.r, col.g, col.b, 1, l.font)
        end
        ty = ty + l.h
    end
    panel:clearStencilRect()
    if HARMONIE_Scroll then
        HARMONIE_Scroll.bar(panel, "guide", px + pw + 8, top, 6, ph, st.scroll, st.maxScroll,
            function(v) st.scroll = v end, { c.accent.r, c.accent.g, c.accent.b }, { c.borderDim.r, c.borderDim.g, c.borderDim.b })
    end
end

EHR_HealthPanelUI.ExtraTabs = EHR_HealthPanelUI.ExtraTabs or {}
EHR_HealthPanelUI.ExtraTabs.guide = {
    open = function(panel)
        panel.hmGuide = panel.hmGuide or { id = CHAPTERS[1], scroll = 0 }
        HMLog("Guide", "medical guide opened on %s", tostring(panel.hmGuide.id))
    end,
    draw = function(panel)
        panel.hmGuide = panel.hmGuide or { id = CHAPTERS[1], scroll = 0 }
        draw(panel)
    end,
    wheel = function(panel, del)
        local st = panel.hmGuide
        if not st or (st.maxScroll or 0) <= 0 then return false end
        st.scroll = math.max(0, math.min(st.maxScroll, st.scroll + del * (fh() + 2) * 3))
        return true
    end,
    mouseDown = function(panel, x, y)
        local st = panel.hmGuide
        for _, r in ipairs(st and st.rows or {}) do
            if inside(x, y, r.x, r.y, r.w, r.h) then
                if st.id ~= r.id then
                    st.id, st.scroll, st.wrapId = r.id, 0, nil
                    HMLog("Guide", "chapter %s", tostring(r.id))
                end
                return true
            end
        end
        return false
    end,
}

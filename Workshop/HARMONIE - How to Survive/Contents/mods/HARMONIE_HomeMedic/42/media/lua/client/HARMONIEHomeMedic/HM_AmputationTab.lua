--[[
    HARMONIE - How to Survive : the medical window's "Amputation" tab (client)

    Owner, 2026-11-10: "เพิ่มแท็บการตัดอวัยวะ เอาไว้ดูสถานะต่างๆของการตัดอวัยวะ
    หากมีการตัดไปแล้ว". Everything The Only Cure keeps about the patient's
    arms, one column per side:
      * where the arm was cut (the highest cut part) and what it means
        (action time multiplier, prosthesis possible or not);
      * the stump: healed or hours left, cauterized, dirtiness, bite;
      * the prosthesis worn on that side;
      * the amputation skills: Left Side, Right Side, Prosthesis
        Familiarity (level and XP to the next level).
    Read from TOC's DataController (the patient's own copy on this client;
    for another player it is requested once, as the TOC bridge does) and the
    patient's perks. Read only: the actions stay in the body part's
    right-click (here and in vanilla's health window).

    0.33.3 (owner: "ยังไม่มีรูปเลย" / "วงเล็บ ชม. ... เวลาในเกมหรือชีวิตจริง"):
      * each arm has a picture (tools/gen_amputation_art.py): whole, cut at
        hand / forearm / upper arm, or with a prosthesis;
      * TOC's "cicatrization time" is not hours: it goes down once per
        IN-GAME hour by CicatrizationSpeed - dirtiness (at least 0.1), so a
        dirty stump heals up to 10x slower. The tab shows the in-game time
        left if the stump stays as clean as it is now.
]]--

require "HARMONIEHomeMedic/HM_Text"
require "ExtensiveHealth/EHR_HealthPanelUI"
pcall(require, "HARMONIE_UIKit")

local FONT, FONT_M = UIFont.Small, UIFont.Medium
local function fh(f) return getTextManager():getFontHeight(f or FONT) end
local function L(key, fallback, ...) return HM_Text("UI_HomeMedic_Amp_" .. key, fallback or key, ...) end
local function log(fmt, ...) if HMLog then HMLog("AmputationTab", fmt, ...) end end

local SIDES = { "L", "R" }
local PARTS = { "UpperArm", "ForeArm", "Hand" }   -- highest first
-- TOC StaticData: hand x2 / forearm x3 / upper arm x4, stump 120 / 144 / 192 h
local TIME_MUL = { Hand = 2, ForeArm = 3, UpperArm = 4 }
local CIC_BASE = { Hand = 120, ForeArm = 144, UpperArm = 192 }
local PERKS = { "Side_L", "Side_R", "ProstFamiliarity" }

local requested = {}

-- the arm pictures (amp/arm_<side>_<state>.png), cached per path
local texCache = {}
local function armTexture(side, st)
    local state = "none"
    if st then
        state = st.part
        if st.prost and st.part ~= "UpperArm" then state = state .. "_prost" end
    end
    local path = "media/textures/HARMONIE_HomeMedic/amp/arm_" .. side .. "_" .. state .. ".png"
    if texCache[path] == nil then
        texCache[path] = (getTexture and getTexture(path)) or false
        if not texCache[path] then log("arm picture missing: %s", path) end
    end
    return texCache[path] or nil
end

-- in-game hours until the stump heals, as TOC counts it (LocalPlayerController
-- .UpdateAmputations, every in-game hour): dirtiness += 0.01 x
-- WoundDirtynessMultiplier, time -= max(0.1, CicatrizationSpeed - dirtiness).
-- Assumes no new dirt or blood on that arm, so it is the best case.
local function hoursToHeal(cicTime, dirt)
    local sv = SandboxVars and SandboxVars.TOC or {}
    local speed = tonumber(sv.CicatrizationSpeed) or 1
    local grow = 0.01 * (tonumber(sv.WoundDirtynessMultiplier) or 1)
    local t, d, h = tonumber(cicTime) or 0, math.min(1, tonumber(dirt) or 0), 0
    while t > 0 and h < 5000 do
        d = math.min(1, d + grow)
        local dec = speed - d
        if dec <= 0 then dec = 0.1 end
        t = t - dec
        h = h + 1
    end
    return h
end

local function gameTime(h)
    if h >= 24 then return L("DaysHours", "%1 d %2 h", math.floor(h / 24), h % 24) end
    return L("Hours", "%1 h", h)
end

local function tocData(patient)
    local okD, DC = pcall(require, "TOC/Controllers/DataController")
    if not okD or type(DC) ~= "table" or not DC.GetInstance then return nil, "noTOC" end
    local user
    pcall(function() user = patient:getUsername() end)
    if not user then return nil, "noData" end
    local dc = DC.GetInstance(user)
    if not dc then
        if not requested[user] then
            requested[user] = true
            pcall(function() require("TOC/Controllers/ClientDataController").Request(user, false) end)
            log("asked TOC for %s's limb data", tostring(user))
        end
        return nil, "noData"
    end
    return dc
end

local function call(dc, m, ...)
    if not dc or not dc[m] then return nil end
    local ok, v = pcall(dc[m], dc, ...)
    return ok and v or nil
end

-- one side: the highest cut part and its state
local function sideState(dc, side)
    for _, part in ipairs(PARTS) do
        local limb = part .. "_" .. side
        if call(dc, "getIsCut", limb) and call(dc, "getIsVisible", limb) ~= false then
            return {
                limb = limb, part = part,
                cicatrized = call(dc, "getIsCicatrized", limb) == true,
                cicTime = tonumber(call(dc, "getCicatrizationTime", limb)) or 0,
                cauterized = call(dc, "getIsCauterized", limb) == true,
                dirt = tonumber(call(dc, "getWoundDirtyness", limb)) or 0,
                infected = call(dc, "getIsInfected", limb) == true,
                prost = call(dc, "getIsProstEquipped", limb) == true,
            }
        end
    end
    return nil
end

local function perk(patient, name)
    local p = Perks and Perks[name]
    if not p then return nil end
    local lvl, xp, need
    if patient.getPerkLevel then pcall(function() lvl = patient:getPerkLevel(p) end) end
    pcall(function()
        local x = patient.getXp and patient:getXp()
        if x and x.getXP then xp = x:getXP(p) end
    end)
    -- test each method first: a missing Java method logs even inside pcall
    pcall(function()
        local pf = PerkFactory and PerkFactory.getPerk and PerkFactory.getPerk(p)
        if lvl and lvl < 10 and pf and pf.getTotalXpForLevel then need = pf:getTotalXpForLevel(lvl + 1) end
    end)
    return tonumber(lvl), tonumber(xp), tonumber(need)
end

local function draw(panel)
    local c = EHR_HealthPanelUI.Colors
    local b = panel:getTabContentBounds()
    panel:drawPanelFrame(b.x, b.y, b.w, b.h, L("Title", "AMPUTATION"), nil)
    local patient = panel.player or (getPlayer and getPlayer())
    local x0, y = b.x + 14, b.y + 48
    local lineH = fh() + 4
    local function text(t, x, yy, col, font)
        col = col or c.text
        panel:drawText(tostring(t), x, yy, col.r, col.g, col.b, 1, font or FONT)
    end
    if not patient then return end
    local dc, why = tocData(patient)
    if not dc then
        text(why == "noTOC" and L("NoTOC", "The Only Cure is not loaded.") or L("Waiting", "Waiting for the limb data..."), x0, y, c.textDim)
        return
    end

    local colW = math.floor((b.w - 42) / 2)
    local any = false
    for i, side in ipairs(SIDES) do
        local x = x0 + (i - 1) * (colW + 14)
        local yy = y
        local st = sideState(dc, side)
        local bd = st and c.red or c.borderDim
        local boxH = lineH * 9 + 16
        panel:drawRect(x, yy, colW, boxH, 0.45, c.panelSoft.r, c.panelSoft.g, c.panelSoft.b)
        panel:drawRectBorder(x, yy, colW, boxH, 1, bd.r, bd.g, bd.b)
        local picH = boxH - 16
        local picW = math.floor(picH * 96 / 224)
        local tex = armTexture(side, st)
        if tex then panel:drawTextureScaled(tex, x + 8, yy + 8, picW, picH, 1, 1, 1, 1) end
        local px = x + 16 + picW
        local innerW = colW - (px - x) - 8
        yy = yy + 8
        text(L("Side_" .. side, side == "L" and "LEFT ARM" or "RIGHT ARM"), px, yy, c.accent, FONT_M)
        yy = yy + fh(FONT_M) + 6
        if not st then
            text(L("NotCut", "Not amputated"), px, yy, c.green)
        else
            any = true
            local function row(label, value, col)
                text(label, px, yy, c.textDim)
                text(value, px + math.floor(innerW * 0.42), yy, col)
                yy = yy + lineH
            end
            row(L("CutAt", "Cut at"), L("Part_" .. st.part, st.part), c.red)
            if st.cicatrized then
                row(L("Stump", "Stump"), L("Healed", "Healed"), c.green)
            else
                local base = CIC_BASE[st.part] or 1
                local pct = math.max(0, math.min(100, math.floor((1 - st.cicTime / base) * 100 + 0.5)))
                local hrs = hoursToHeal(st.cicTime, st.dirt)
                row(L("Stump", "Stump"), L("Healing", "Healing %1%% (~%2 in game)", pct, gameTime(hrs)), c.yellow)
                panel.hmAmpHealLog = panel.hmAmpHealLog or {}
                if panel.hmAmpHealLog[st.limb] ~= hrs then
                    panel.hmAmpHealLog[st.limb] = hrs
                    log("%s: stump %d%%, TOC time %.1f, dirt %.2f -> about %d in-game hours left", st.limb, pct, st.cicTime, st.dirt, hrs)
                end
            end
            row(L("Cauterized", "Cauterized"), st.cauterized and L("Yes", "Yes") or L("No", "No"), st.cauterized and c.green or c.textDim)
            local dirt = math.floor(st.dirt * 100 + 0.5)
            row(L("Dirt", "Dirtiness"), tostring(dirt) .. "%", dirt >= 50 and c.red or (dirt > 0 and c.yellow or c.green))
            row(L("Bite", "Zombie bite"), st.infected and L("Yes", "Yes") or L("No", "No"), st.infected and c.red or c.green)
            local canProst = st.part ~= "UpperArm"
            local pv = st.prost and L("ProstOn", "Worn") or (canProst and L("ProstCan", "Not worn (can wear)") or L("ProstNo", "Cannot wear (upper arm)"))
            row(L("Prost", "Prosthesis"), pv, st.prost and c.green or (canProst and c.text or c.textDim))
            -- action time: TOC's multiplier minus 0.1 per skill level, never under 1
            local sideLvl = perk(patient, "Side_" .. side) or 0
            local prostLvl = st.prost and (perk(patient, "ProstFamiliarity") or 0) or 0
            local mul = math.max(1, (TIME_MUL[st.part] or 1) - (sideLvl + prostLvl) / 10)
            row(L("Speed", "Actions take"), L("Times", "x%1 the time", string.format("%.1f", mul)), mul > 2 and c.orange or c.text)
            if st.prost and not st.cicatrized then
                text(L("BleedWarn", "Prosthesis on an unhealed stump: may bleed on every action"), px, yy, c.red)
            end
        end
    end
    y = y + lineH * 9 + 30

    -- the skills
    text(L("Skills", "AMPUTATION SKILLS"), x0, y, c.accent, FONT_M)
    y = y + fh(FONT_M) + 6
    for _, name in ipairs(PERKS) do
        local lvl, xp, need = perk(patient, name)
        local label = getText and getText("IGUI_perks_" .. name) or name
        local v
        if lvl == nil then v = "-"
        elseif lvl >= 10 then v = L("LvlMax", "Level %1 (max)", lvl)
        else v = L("Lvl", "Level %1  (%2 / %3 XP)", lvl, math.floor(xp or 0), math.floor(need or 0)) end
        text(label, x0, y, c.textDim)
        text(v, x0 + 220, y, c.text)
        y = y + lineH
    end
    y = y + 6
    for _, k in ipairs({ "Note4", "Note1", "Note2", "Note3" }) do
        local t = L(k, "")
        if t ~= "" and t ~= "UI_HomeMedic_Amp_" .. k then
            local lines = (HM_Surgery and HM_Surgery.wrap) and HM_Surgery.wrap(t, b.w - 30, FONT) or { t }
            for _, l in ipairs(lines) do
                if y + lineH > b.y + b.h - 6 then return end
                text(l, x0, y, c.textDim)
                y = y + lineH
            end
        end
    end
    if not any and panel.hmAmpLogged ~= "none" then panel.hmAmpLogged = "none" end
end

EHR_HealthPanelUI.ExtraTabs = EHR_HealthPanelUI.ExtraTabs or {}
EHR_HealthPanelUI.ExtraTabs.amputation = {
    open = function(panel)
        local p = panel.player
        local who = "?"
        pcall(function() who = tostring(p:getUsername()) end)
        log("amputation tab opened for %s", who)
    end,
    draw = function(panel)
        local ok, err = pcall(draw, panel)
        if not ok and HMLogOnce then HMLogOnce("amptab_draw", "AmputationTab", "draw FAILED: %s", tostring(err)) end
    end,
}

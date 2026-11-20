--[[
    HARMONIE - From Garden to Plate
    Shows a vitamin-content breakdown next to a food item's tooltip, for
    anyone with Cooking 3+ or vanilla's own "Nutritionist" trait
    (base:nutritionist -- its vanilla description is literally "Can see the
    nutritional values of any food", it just never had any actual
    Lua/Java hook doing that until now). 2026-10-25: everyone else sees the
    same box with "Yes" instead of the amounts.

    Technique note: an earlier version tried to hook ISToolTip:setDescription
    to append text into the vanilla tooltip's own description string. That
    silently did nothing -- checking how Extensive Health Rework B42
    (Workshop 3726328119, EHR_TooltipSystem.lua) does custom tooltips shows
    real mods don't touch setDescription at all; they fully override
    ISToolTipInv:render() and either draw a whole custom box themselves or
    fall through to the original vanilla render. Fighting vanilla's own
    tooltip sizing to inject extra lines into it isn't the supported path.

    So instead: let the vanilla tooltip render completely untouched, then
    draw our OWN small box next to it with a second, independent panel
    that is never added to UIManager -- keeping it out of UIManager means
    it can never end up in the mouse click hit-test stack (an earlier,
    since-removed full-screen overlay panel got this wrong and ended up
    silently eating every mouse click game-wide).
]]--

require "ISUI/ISPanel"
require "ISUI/ISToolTipInv"
require "HARMONIEGardenToPlate/HARMONIE_FoodVitaminDatabase"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"

HARMONIE_GTP = HARMONIE_GTP or {}

local VitaminLabel = {
    A = "IGUI_HARMONIE_Vitamin_A",
    B = "IGUI_HARMONIE_Vitamin_B",
    C = "IGUI_HARMONIE_Vitamin_C",
    D = "IGUI_HARMONIE_Vitamin_D",
    E = "IGUI_HARMONIE_Vitamin_E",
    K = "IGUI_HARMONIE_Vitamin_K",
}
local VitaminUnit = { A = "mcg", B = "mg", C = "mg", D = "mcg", E = "mg", K = "mcg" }
local REQUIRED_COOKING_LEVEL = 3

local function playerCanSeeVitamins(playerObj)
    if playerObj:getPerkLevel(Perks.Cooking) >= REQUIRED_COOKING_LEVEL then
        return true
    end
    return playerObj:hasTrait(CharacterTrait.NUTRITIONIST)
end

-- ============================================
-- STANDALONE VITAMIN BOX (never added to UIManager)
-- ============================================

HARMONIE_VitaminTooltip = ISPanel:derive("HARMONIE_VitaminTooltip")

-- GTP 1.5.0 (#24): the size only (so the box can be placed BEFORE it is
-- drawn -- drawing first and moving after showed it one frame late)
function HARMONIE_VitaminTooltip:measureLines(lines)
    local font = UIFont.Small
    local tm = getTextManager()
    local fontHeight = tm:getFontHeight(font)
    local maxWidth = 0
    for _, line in ipairs(lines) do maxWidth = math.max(maxWidth, tm:MeasureStringX(font, line.text)) end
    self:setWidth(maxWidth + 16)
    self:setHeight(#lines * (fontHeight + 4) + 16)
end

function HARMONIE_VitaminTooltip:renderLines(lines)
    local font = UIFont.Small
    local textManager = getTextManager()
    local fontHeight = textManager:getFontHeight(font)
    local lineGap = 4
    local padding = 8

    local maxWidth = 0
    for _, line in ipairs(lines) do
        maxWidth = math.max(maxWidth, textManager:MeasureStringX(font, line.text))
    end
    local boxWidth = maxWidth + padding * 2
    local boxHeight = (#lines * (fontHeight + lineGap)) + padding * 2

    self:setWidth(boxWidth)
    self:setHeight(boxHeight)

    self:drawRect(0, 0, boxWidth, boxHeight, 0.95, 0.08, 0.08, 0.10)
    self:drawRectBorder(0, 0, boxWidth, boxHeight, 1, 0.30, 0.62, 0.35)

    local y = padding
    for _, line in ipairs(lines) do
        self:drawText(line.text, padding, y, line.r, line.g, line.b, 1, font)
        y = y + fontHeight + lineGap
    end
end

local function newBox()
    local b = HARMONIE_VitaminTooltip:new(0, 0, 10, 10)
    b:initialise()
    b:noBackground()
    b:instantiate()
    return b
end
local function createVitaminTooltip()
    HARMONIE_VitaminTooltip.instance = newBox()
    -- GTP 1.1.0: the preparation / dish score box, above the vitamins
    HARMONIE_VitaminTooltip.prepInstance = newBox()
end

-- ============================================
-- GTP 1.1.0: preparation score (ingredient) / cooking score (dish)
-- (owner: "ให้ขึ้นเหมือนหน้าต่างวิตามิน ... เป็นอีกหน้าต่างนึงที่อยู่ด้านบนวิตามิน")
-- ============================================
local WORD_COL = { Excellent = { 0.45, 0.92, 0.48 }, Good = { 0.62, 0.86, 1.0 }, Bad = { 1.0, 0.55, 0.35 }, Miss = { 1.0, 0.42, 0.38 } }
local function txt(key, ...)
    local ok, v = pcall(getText, key, ...)
    return ok and v or key
end
local function buildPrepLines(item)
    local R = HARMONIE_GTP.Prep
    -- 1.1.1: R.isFood (a safe instanceof); isPossiblyFood is a local defined
    -- further down this file, so here it was a nil global -> "Object tried
    -- to call nil" on every tooltip frame (owner's MP console 2026-11-19)
    if not R or not item or not R.isFood or not R.isFood(item) then return nil end
    local d = R.dishOf(item)
    if d then
        local avg = tonumber(d.avg) or 0
        local Kc = HARMONIE_GTP.Cook
        local tier, held = R.tierOf(avg), nil
        if Kc and Kc.dishTier then tier, held = Kc.dishTier(d, item) end
        local lines = { { text = txt("IGUI_GTPP_TipDish"), r = 1, g = 1, b = 1 } }
        lines[#lines + 1] = { text = txt("IGUI_GTPP_TipScore", string.format("%.2f", avg), tostring(tonumber(d.n) or 0)), r = 0.85, g = 0.9, b = 0.85 }
        -- GTP 1.7.0 (#38): many kinds of food in one dish
        if (tonumber(d.bonus) or 0) > 0 then
            local nk = 0
            for _ in pairs(type(d.kinds) == "table" and d.kinds or {}) do nk = nk + 1 end
            lines[#lines + 1] = { text = txt("IGUI_GTPP_TipVariety", string.format("%+.2f", d.bonus), tostring(nk)), r = 0.62, g = 0.86, b = 1.0 }
        end
        -- GTP 1.8.0: who cooked it, and whether the cook left a note
        if d.chef then
            local hasNote = type(d.note) == "table" and type(d.note.t) == "string" and d.note.t ~= ""
            local text
            if hasNote and d.note.by and d.note.by ~= d.chef then
                -- someone else added last: the note is still its writer's
                text = txt("IGUI_GTPN_TipChefNoteBy", tostring(d.chef), tostring(d.note.by))
            else
                text = txt(hasNote and "IGUI_GTPN_TipChefNote" or "IGUI_GTPN_TipChef", tostring(d.chef))
            end
            lines[#lines + 1] = { text = text, r = 0.95, g = 0.88, b = 0.7 }
        end
        if tier < 0 then
            lines[#lines + 1] = { text = txt("IGUI_GTPP_TipBad"), r = 1.0, g = 0.45, b = 0.4 }
        elseif tier == 0 then
            lines[#lines + 1] = { text = held == "rotten" and txt("IGUI_GTPP_TipRotten") or txt("IGUI_GTPP_TipNoBuff", string.format("%.1f", R.tierCut(1))), r = 0.7, g = 0.75, b = 0.7 }
        else
            local kind = HARMONIE_GTP.Cook and HARMONIE_GTP.Cook.buffKindOf and HARMONIE_GTP.Cook.buffKindOf(item, d.fam) or "hearty"
            lines[#lines + 1] = { text = txt("IGUI_GTPP_TipBuff", txt("IGUI_GTPC_Buff_" .. kind), tostring(tier)), r = 0.45, g = 0.92, b = 0.48 }
            if held == "level" then
                lines[#lines + 1] = { text = txt("IGUI_GTPP_TipTier3Level", tostring(R.tier3Level())), r = 1.0, g = 0.82, b = 0.32 }
            end
        end
        return lines
    end
    local p = R.prepOf(item)
    if p then
        local c = WORD_COL[p.w] or { 0.9, 0.9, 0.9 }
        return { { text = txt("IGUI_GTPP_TipPrep"), r = 1, g = 1, b = 1 },
            { text = txt("IGUI_GTPP_TipPrepLine", txt("IGUI_GTPC_Proc_" .. tostring(p.p)), txt("IGUI_GTPC_Word_" .. tostring(p.w)),
                R.isRotten(item) and txt("IGUI_GTPP_RottenZero") or string.format("%+.1f", R.scoreOf(item))), r = c[1], g = c[2], b = c[3] } }
    end
    -- GTP 1.7.0 (#25): the player can switch this box off (Settings)
    if GTPGuide and GTPGuide.ensurePrefs then GTPGuide.ensurePrefs() end
    if GTPGuide and GTPGuide.tipUnprepared == false then return nil end
    if R.whyNot(item) == nil then
        local games = R.gamesFor(item)
        if #games == 0 then return nil end
        local names = {}
        for i, pid in ipairs(games) do if i <= 4 then names[#names + 1] = txt("IGUI_GTPC_Proc_" .. pid) end end
        return { { text = txt("IGUI_GTPP_TipPrep"), r = 1, g = 1, b = 1 },
            { text = txt("IGUI_GTPP_TipNotYet"), r = 0.75, g = 0.78, b = 0.75 },
            { text = txt("IGUI_GTPP_TipCan", table.concat(names, ", ")), r = 0.6, g = 0.8, b = 0.65 } }
    end
    return nil
end

--[[
    True only for something worth even TRYING to look up a vitamin
    profile for -- a real solid Food item. FluidContainer-based drinks
    (Milk and anything consumed the same way) are deliberately NOT
    tracked at all in this mod (see HARMONIE_EatHook.lua's header), so
    they're excluded here too rather than checked for and always coming
    up empty. ISToolTipInv:render() is overridden below for EVERY tooltip
    shown anywhere in the game, not just food -- weapons, clothing, tools,
    light sources (a lit torch/lamp previewed in
    ISLightSourceRadialMenu.lua), dead-animal/bird-related items, all of
    it. Without this check, buildVitaminLines would still try
    item:getBaseHunger() on all of those (GetItemBaseHunger's own pcall
    keeps that from actually crashing anything, but the underlying native
    call still throws and gets logged as a console error on every single
    non-food tooltip in the game -- confirmed as the actual cause of
    reported errors in both HARMONIE_FoodVitaminDatabase.lua and vanilla's
    own ISLightSourceRadialMenu.lua, since that radial menu previews light
    source items -- torches, lamps -- through this exact same tooltip
    class). Checking the item's real category FIRST means we never even
    attempt the call for the overwhelming majority of tooltips, instead
    of attempting-then-catching every time.
]]--
local function isPossiblyFood(item)
    local ok, isFood = pcall(function() return instanceof(item, "Food") end)
    return ok and isFood
end

local function buildVitaminLines(item, knows)
    if not item or not isPossiblyFood(item) then return nil end

    -- A legitimately-crafted sealed jar carries its real vitamin content
    -- as ModData (see HARMONIE_RecipeVitamins.lua), so this resolves for
    -- it exactly like any other tracked food. A sealed jar carries NO
    -- native HungerChange of its own though (see HARMONIE_GardenToPlate_Items.txt --
    -- deliberately, matching vanilla's own real sealed cans like
    -- Base.CannedCarrots2, so it can't be eaten around the can-opener
    -- requirement), so a debug-spawned one with no ModData at all won't
    -- show anything here until actually opened -- acceptable, since it
    -- was never eatable in that state either.
    local rates = HARMONIE_GTP.GetVitaminRatePerHunger(item)
    if not rates then return nil end

    -- 2026-10-25: everyone sees the vitamins; without the knowledge
    -- (Cooking 3 / Nutritionist) only "Yes", with it the amount and
    -- "(High)" / "(Low)" (the item's amount against the median food)
    local header = knows and getText("IGUI_HARMONIE_TooltipHeader")
        or getText("IGUI_HARMONIE_TooltipHeaderWords", tostring(REQUIRED_COOKING_LEVEL))
    local lines = {{ text = header, r = 1, g = 1, b = 1 }}
    local profile = HARMONIE_GTP.GetVitaminProfileForItem(item) or {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if rates[vit] then
            if knows then
                table.insert(lines, {
                    text = getText(VitaminLabel[vit]) .. ": " .. string.format("%.1f", rates[vit]) .. " " .. VitaminUnit[vit]
                        .. (HARMONIE_GTP.VitaminTag and HARMONIE_GTP.VitaminTag(vit, profile[vit]) or ""),
                    r = 0.55, g = 0.85, b = 0.6,
                })
            else
                if (profile[vit] or 0) > 0 then
                    table.insert(lines, {
                        text = getText(VitaminLabel[vit]) .. ": " .. HARMONIE_GTP.VitaminHasText(),
                        r = 0.55, g = 0.85, b = 0.6,
                    })
                end
            end
        end
    end
    if #lines == 1 then return nil end

    -- No separate freshness/rot line: vanilla already tracks how stale
    -- an item is on its own (Fresh/Stale/Rotten, visible on the item
    -- itself), and GetVitaminGains already pulls the ACTUAL current
    -- vitamin amount from that when you eat or cook with it -- this rate
    -- is deliberately the fixed "per hunger point" reference number
    -- (comparable between food types), not a live reading, so there's
    -- nothing further to display here.
    return lines
end

-- ============================================
-- HOOK: draw the box under the vanilla tooltip
-- ============================================

local original_ISToolTipInv_render = ISToolTipInv.render
function ISToolTipInv:render()
    original_ISToolTipInv_render(self)

    if not HARMONIE_VitaminTooltip.instance then return end

    local playerObj = getSpecificPlayer(0)
    if not self.item or not playerObj then
        return
    end

    local okP, prepLines = pcall(buildPrepLines, self.item)
    if not okP then
        if HARMONIE_GTP.LogOnce then HARMONIE_GTP.LogOnce("preptip", "Prep", "score tooltip FAILED: %s", tostring(prepLines)) end
        prepLines = nil
    end
    local lines = buildVitaminLines(self.item, playerCanSeeVitamins(playerObj))
    if not lines and not prepLines then return end

    local box = HARMONIE_VitaminTooltip.instance
    local pbox = HARMONIE_VitaminTooltip.prepInstance
    if lines then box:measureLines(lines) end
    if prepLines and pbox then pbox:measureLines(prepLines) else prepLines = nil end

    -- 1.0.3 (owner, 2026-11-12: "หน้าต่างวิตามินตอนชี้ให้ขึ้นข้างล่างแทนทางขวาของ
    -- tooltips"): under the item tooltip, its left edges lined up; above it
    -- when there is no room below. 1.1.0: the score box sits on top of the
    -- vitamin box (score, then vitamins), the two moving together.
    local core = getCore()
    local sw, sh = core:getScreenWidth(), core:getScreenHeight()
    local ph = prepLines and (pbox:getHeight() + 4) or 0
    local vh = lines and (box:getHeight() + 4) or 0
    local total = ph + vh
    local x = self:getX()
    local y = self:getY() + self:getHeight() + 4
    if y + total > sh then
        y = self:getY() - total
        if y < 0 then y = math.max(0, sh - total - 5) end
    end
    if prepLines then
        pbox:setX(math.max(0, math.min(x, sw - pbox:getWidth() - 5)))
        pbox:setY(y)
    end
    if lines then
        box:setX(math.max(0, math.min(x, sw - box:getWidth() - 5)))
        box:setY(y + ph)
    end
    -- placed: now draw them where they are
    if prepLines then pbox:renderLines(prepLines) end
    if lines then box:renderLines(lines) end
end

Events.OnGameStart.Add(createVitaminTooltip)

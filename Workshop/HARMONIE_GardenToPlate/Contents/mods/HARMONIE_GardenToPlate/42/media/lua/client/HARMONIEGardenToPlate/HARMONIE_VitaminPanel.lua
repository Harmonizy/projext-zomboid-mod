--[[
    HARMONIE - From Garden to Plate
    Self-view vitamin panel, added as a new tab in the vanilla character info
    window (see HARMONIE_VitaminPanelHook.lua) -- unlike HARMONIE_NutritionUI.lua
    (the "N" hotkey window, which assesses ANY target survivor and gates behind
    the ASSESSOR's own First Aid), this panel always shows the viewing player's
    own character and gates its own richer detail behind THAT SAME character's
    own skills:
      - No skill required: band word (Critical/Low/Sufficient), what goes wrong
        at Critical, banked pause-days, and a tooltip explaining what pause days
        do and exactly how to clear an affliction.
      - First Aid (Perks.Doctor, B42's renamed internal id -- see
        HARMONIE_NutritionUI.lua's own isLocked() for the same renaming note)
        level 3+: adds the exact Reserve number (0-100) and this vitamin's Daily
        Requirement.
      - Cooking level 3+: adds the top 10 foods richest in this vitamin
        (HARMONIE_GTP.GetTopFoods, see HARMONIE_TopFoods.lua).

    BandTextKey is intentionally duplicated from HARMONIE_NutritionUI.lua
    rather than shared, per this feature's own plan: that file is explicitly
    left unmodified (it's a separate, still-existing feature), and it's one
    tiny constant table, not worth changing an unrelated file's contract
    just to avoid a few duplicated lines. Its own band->color table isn't
    reused here at all -- see getStatusColor below for this tab's own
    4-tier palette.

    Built on ISScrollingListBox (not a plain ISPanel) so that:
      - each row's own height grows to fit however many lines its wrapped text
        actually needs (fixes rows silently clipping/overflowing content), and
      - the whole tab scrolls with a real scrollbar once total content is
        taller than the tab area (fixes content being cut off with no way to
        reach it), same widget vanilla uses for its own Skills/Traits lists.

    Visual style borrowed from Extensive Health Rework Evolved's own debug
    menu (EHR_DebugMenuV2.lua, Workshop 3726328119 -- the user pointed at
    this file specifically as a UI worth studying): dark background, a
    muted green border/accent, and a 4-tier semantic status palette (safe/
    warning/danger/critical) instead of this tab's earlier flat 3-color
    band scheme. Reused real drawing techniques from that file, not just
    its colors -- a colored left accent stripe per row, a small background
    "badge" chip behind the band word, a horizontal fill bar for the exact
    Reserve number (its own drawRect-background + drawRect-fill +
    drawRectBorder pattern, same one EHR uses for its blood-volume bar),
    and a thin 1px divider between rows instead of a full alternating
    background block.

    The status color now has 4 tiers, not 3, mapped onto the SAME
    band+penaltyActive data this tab already computed (see
    HARMONIE_ModernStatusBridge.lua-adjacent VitData.IsAfflicted/
    GetPauseDays -- no new data source, just a richer color mapping):
      Sufficient                              -> safe (green)
      Low                                      -> warning (yellow)
      Critical, still pause-day-shielded       -> danger (orange)
      Critical, penalty genuinely active now   -> critical (bright red)
    This visually answers "is it actually hurting me right now" at a
    glance, the exact distinction the Penalty-active line already spelled
    out in text but that previously had no visual weight of its own.
]]--

require "ISUI/ISScrollingListBox"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"
require "HARMONIEGardenToPlate/HARMONIE_VitaminEffects"
require "HARMONIEGardenToPlate/HARMONIE_TopFoods"

HARMONIE_VitaminPanel = ISScrollingListBox:derive("HARMONIE_VitaminPanel")

local PADDING = 10
local ICON_SIZE = 28
local ROW_GAP = 10
local LINE_GAP = 3
local STRIPE_WIDTH = 3
local BAR_HEIGHT = 12

-- EHR_DebugMenuV2.lua's own palette (Colors table, ExtensiveHealthReworkB42)
-- -- reused directly so this tab visually matches the mod the user pointed
-- at, not just approximated.
local Colors = {
    border   = {r = 0.30, g = 0.50, b = 0.40},
    text     = {r = 0.90, g = 0.90, b = 0.90},
    textDim  = {r = 0.60, g = 0.60, b = 0.60},
    safe     = {r = 0.20, g = 0.80, b = 0.30},
    warning  = {r = 0.90, g = 0.70, b = 0.20},
    danger   = {r = 0.90, g = 0.35, b = 0.10},
    critical = {r = 1.00, g = 0.15, b = 0.15},
}

local BandTextKey = {
    critical   = "IGUI_HARMONIE_Band_Critical",
    low        = "IGUI_HARMONIE_Band_Low",
    sufficient = "IGUI_HARMONIE_Band_Sufficient",
}

--[[
    4-tier status color for a row, given its band AND whether the penalty
    is genuinely active right now -- see this file's header for why
    Critical splits into two distinct colors (danger vs critical) instead
    of one, unlike the old 3-color BandColor table this replaces.
]]--
local function getStatusColor(band, penaltyActive)
    if band == "sufficient" then return Colors.safe end
    if band == "low" then return Colors.warning end
    if penaltyActive then return Colors.critical end
    return Colors.danger
end

local VitaminNameKey = {
    A = "IGUI_HARMONIE_Vitamin_A",
    B = "IGUI_HARMONIE_Vitamin_B",
    C = "IGUI_HARMONIE_Vitamin_C",
    D = "IGUI_HARMONIE_Vitamin_D",
    E = "IGUI_HARMONIE_Vitamin_E",
    K = "IGUI_HARMONIE_Vitamin_K",
}

-- ISUIElement:drawTextureScaled ultimately hands its texture argument to a
-- native Java call that requires an actual Texture object -- unlike some
-- other draw* wrappers, ISUITextureGetter.checkGetTexture() does NOT resolve
-- a plain path string for it (confirmed via a real crash: "expected argument
-- of type Texture, got String", console.txt stack trace through
-- HARMONIE_VitaminPanel.lua:doDrawItem). Resolve each icon once via
-- getTexture() at file-load time instead of passing the path every frame.
local VitaminIcon = {
    A = getTexture("media/ui/VitaminA.png"),
    B = getTexture("media/ui/VitaminB.png"),
    C = getTexture("media/ui/VitaminC.png"),
    D = getTexture("media/ui/VitaminD.png"),
    E = getTexture("media/ui/VitaminE.png"),
    K = getTexture("media/ui/VitaminK.png"),
}

-- What goes wrong at Critical, in plain player-facing language -- same real
-- trait/effect this mod actually grants (HARMONIE_VitaminEffects.lua), just
-- worded for the always-visible base tier rather than buried in a tooltip.
local VitaminDownsideKey = {
    A = "IGUI_HARMONIE_Downside_A",
    B = "IGUI_HARMONIE_Downside_B",
    C = "IGUI_HARMONIE_Downside_C",
    D = "IGUI_HARMONIE_Downside_D",
    E = "IGUI_HARMONIE_Downside_E",
    K = "IGUI_HARMONIE_Downside_K",
}

-- Same unit-per-vitamin convention HARMONIE_TooltipHook.lua's own item-tooltip
-- vitamin breakdown already uses (VitaminUnit table there) -- kept in sync by
-- hand since it's a tiny constant table, not worth sharing across an
-- unrelated file just to avoid duplicating 6 lines.
local VitaminUnit = { A = "mcg", B = "mg", C = "mg", D = "mcg", E = "mg", K = "mcg" }

local FIRST_AID_DETAIL_LEVEL = 3
local COOKING_FOOD_LEVEL = 3

function HARMONIE_VitaminPanel:getPlayer()
    return getSpecificPlayer(self.playerNum)
end

--[[
    Small floating tooltip box near the mouse -- same manual-draw technique
    MoodleFramework's own MF_ISMoodle.lua uses for its per-moodle tooltip
    (drawRect + drawTextRight near the cursor), reimplemented directly here
    rather than pulled in as a dependency: this panel has no other reason to
    require MoodleFramework, which is itself only a soft/optional dependency
    for the separate moodle feature, not something this tab should ever
    require just for a tooltip box.
]]--
function HARMONIE_VitaminPanel:wrapText(text, maxWidth, font)
    local lines = {}
    for rawLine in (text .. "\n"):gmatch("([^\n]*)\n") do
        local currentLine = ""
        for word in rawLine:gmatch("%S+") do
            local candidate = currentLine == "" and word or (currentLine .. " " .. word)
            if getTextManager():MeasureStringX(font, candidate) > maxWidth and currentLine ~= "" then
                table.insert(lines, currentLine)
                currentLine = word
            else
                currentLine = candidate
            end
        end
        table.insert(lines, currentLine)
    end
    return lines
end

function HARMONIE_VitaminPanel:drawTooltip(text, mouseX, mouseY)
    if not text or text == "" then return end

    local font = UIFont.Small
    local maxWidth = 260
    local lines = self:wrapText(text, maxWidth, font)

    local lineHeight = getTextManager():getFontHeight(font) + 2
    local boxHeight = #lines * lineHeight + 10
    local boxWidth = maxWidth + 10

    -- mouseX/mouseY are already in this element's own content-space (same
    -- space self:getMouseX()/getMouseY() and doDrawItem's own y use, which
    -- the engine auto-adjusts for scroll at render time) -- do not re-offset
    -- by getAbsoluteX/Y here, that would double-transform it.
    local x = mouseX + 16
    local y = mouseY + 16
    if x + boxWidth > self:getWidth() then x = self:getWidth() - boxWidth end

    -- Real regression found via user report after v0.5.4's auto-height fit:
    -- before that fix this panel's height was always inherited from the
    -- whole (usually much taller) character window, so a tooltip drawn this
    -- far below the cursor never had anywhere to actually clip against. Now
    -- that the panel genuinely shrinks to fit content, ISScrollingListBox's
    -- own stencil rect (see vanilla's :prerender()) clips anything drawn
    -- past the panel's own visible content-space window -- which is
    -- [-getYScroll(), -getYScroll() + getHeight()], NOT [0, getHeight()],
    -- since content-space is scroll-invariant while the viewport moves.
    -- Without this clamp, hovering any row below the first one silently drew
    -- the tooltip past the bottom of that window -- invisible, no error.
    local visibleTop = -self:getYScroll()
    local visibleBottom = visibleTop + self:getHeight()
    if y + boxHeight > visibleBottom then y = visibleBottom - boxHeight end
    if y < visibleTop then y = visibleTop end

    self:drawRect(x, y, boxWidth, boxHeight, 0.92, 0.05, 0.05, 0.05)
    self:drawRectBorder(x, y, boxWidth, boxHeight, 1, 0.4, 0.4, 0.4)
    for i, line in ipairs(lines) do
        self:drawText(line, x + 5, y + 5 + (i - 1) * lineHeight, 1, 1, 1, 1, font)
    end
end

-- Same wording for every vitamin on purpose -- pause days work identically
-- regardless of which vitamin they're banked against.
function HARMONIE_VitaminPanel:getPauseDaysTooltip()
    return getText("IGUI_HARMONIE_PauseDaysTooltip")
end

--[[
    Builds the wrapped text lines for one row given the current skill gates,
    so both :doDrawItem (drawing) and :refreshLayout (row-height sizing) stay
    in perfect sync -- always computed from the same function instead of two
    copies that could drift apart.
]]--
function HARMONIE_VitaminPanel:buildRowLines(vit, player, textWidth, hasFirstAidDetail, hasCookingFoodList)
    local value = HARMONIE_GTP.VitData.Get(player, vit)
    local band = HARMONIE_GTP.GetBand(value)
    local pauseDays = HARMONIE_GTP.VitData.GetPauseDays(player, vit)

    local statusText
    if band == "critical" then
        statusText = getText(VitaminDownsideKey[vit])
    elseif band == "low" then
        statusText = getText("IGUI_HARMONIE_LowWarning", getText(VitaminDownsideKey[vit]))
    else
        statusText = getText("IGUI_HARMONIE_SufficientNote")
    end
    local statusLines = self:wrapText(statusText, textWidth, UIFont.Small)

    local pauseDaysLabel = getText("IGUI_HARMONIE_PauseDays", math.floor(pauseDays))

    -- Same penaltyActive condition HARMONIE_AdminPanel.lua already uses:
    -- afflicted (Critical was hit) AND not currently pause-day-shielded --
    -- distinct from the band itself, since Critical + banked pause days
    -- means the penalty is NOT actually biting right now.
    -- Uses HARMONIE's own Yes/No keys rather than vanilla's shared UI_Yes/
    -- UI_No (which HARMONIE_AdminPanel.lua uses) -- translating those would
    -- affect "Yes"/"No" text everywhere in the whole game, not just this
    -- mod's own UI, which is outside HARMONIE_TooManyModThaiTranslate's
    -- stated scope of translating specific mods' own content.
    local penaltyActive = HARMONIE_GTP.VitData.IsAfflicted(player, vit) and pauseDays < 1
    local penaltyActiveLabel = getText("IGUI_HARMONIE_PenaltyActive",
        penaltyActive and getText("IGUI_HARMONIE_Yes") or getText("IGUI_HARMONIE_No"))

    local numbersText = nil
    if hasFirstAidDetail then
        local requirement = HARMONIE_GTP.DailyRequirement[vit]
        numbersText = getText("IGUI_HARMONIE_ExactNumbers", string.format("%.1f", value), requirement)
    end

    local foodLine = nil
    local topFoods = nil
    if hasCookingFoodList then
        topFoods = HARMONIE_GTP.GetTopFoods(vit, 10)
        if #topFoods > 0 then
            foodLine = getText("IGUI_HARMONIE_TopFoodsInline", topFoods[1].displayName)
        else
            foodLine = getText("IGUI_HARMONIE_TopFoodsNone")
        end
    end

    return {
        value = value,
        band = band,
        statusColor = getStatusColor(band, penaltyActive),
        pauseDays = pauseDays,
        statusLines = statusLines,
        pauseDaysLabel = pauseDaysLabel,
        penaltyActive = penaltyActive,
        penaltyActiveLabel = penaltyActiveLabel,
        numbersText = numbersText,
        foodLine = foodLine,
        topFoods = topFoods,
    }
end

--[[
    Recomputes every row's height from its actual wrapped content and skill
    gates, then updates the listbox's own scroll height -- called on
    initialise and re-checked periodically (skills/thresholds can change
    mid-session) rather than assuming a fixed row size.
]]--
function HARMONIE_VitaminPanel:refreshLayout()
    local player = self:getPlayer()
    if not player then return end

    local hasFirstAidDetail = player:getPerkLevel(Perks.Doctor) >= FIRST_AID_DETAIL_LEVEL
    local hasCookingFoodList = player:getPerkLevel(Perks.Cooking) >= COOKING_FOOD_LEVEL
    -- Must match doDrawItem's own textX exactly (PADDING + STRIPE_WIDTH +
    -- ICON_SIZE + 14) or wrapped lines can overflow the row by a few px.
    local textWidth = self:getWidth() - (PADDING + STRIPE_WIDTH + ICON_SIZE + 14) - PADDING

    local lineHeight = getTextManager():getFontHeight(UIFont.Small) + LINE_GAP
    local headerHeight = getTextManager():getFontHeight(UIFont.Medium) + LINE_GAP

    local totalHeight = 0
    for _, item in ipairs(self.items) do
        local vit = item.item
        local data = self:buildRowLines(vit, player, textWidth, hasFirstAidDetail, hasCookingFoodList)
        item.data = data
        item.hasFirstAidDetail = hasFirstAidDetail
        item.hasCookingFoodList = hasCookingFoodList

        local contentHeight = headerHeight + (#data.statusLines * lineHeight) + lineHeight * 2 -- pause days + penalty active lines
        if data.numbersText then contentHeight = contentHeight + BAR_HEIGHT + 4 + lineHeight end
        if data.foodLine then contentHeight = contentHeight + lineHeight end

        item.height = math.max(ICON_SIZE, contentHeight) + ROW_GAP
        totalHeight = totalHeight + item.height
    end
    self:setScrollHeight(totalHeight)
end

function HARMONIE_VitaminPanel:doDrawItem(y, item, _alt)
    local vit = item.item
    local data = item.data
    if not data then return y + item.height end

    local color = data.statusColor
    local textX = PADDING + STRIPE_WIDTH + ICON_SIZE + 14
    local lineHeight = getTextManager():getFontHeight(UIFont.Small) + LINE_GAP
    local rowTop = y + 2
    local rowHeight = item.height - ROW_GAP

    -- Card background + colored left accent stripe (EHR_DebugMenuV2.lua's
    -- own per-row status-stripe technique) instead of a flat block -- the
    -- stripe alone carries the 4-tier status color, so nothing here needs
    -- its own background tint.
    self:drawRect(0, y, self:getWidth(), rowHeight, 1, 0.13, 0.14, 0.15)
    self:drawRect(0, y, STRIPE_WIDTH, rowHeight, 1, color.r, color.g, color.b)

    -- Icon with a thin ring in the same status color, tying the icon back
    -- to the stripe without needing separate per-status icon art.
    local iconX = PADDING + STRIPE_WIDTH + 6
    self:drawRectBorder(iconX - 2, rowTop - 2, ICON_SIZE + 4, ICON_SIZE + 4, 1, color.r, color.g, color.b)
    self:drawTextureScaled(VitaminIcon[vit], iconX, rowTop, ICON_SIZE, ICON_SIZE, 1, 1, 1, 1)

    local lineY = rowTop
    self:drawText(getText(VitaminNameKey[vit]), textX, lineY, Colors.text.r, Colors.text.g, Colors.text.b, 1, UIFont.Medium)
    local nameWidth = getTextManager():MeasureStringX(UIFont.Medium, getText(VitaminNameKey[vit]))

    -- Band badge -- a small tinted background chip behind the band word,
    -- same "status pill" look EHR's own stage/severity labels use.
    local bandText = getText(BandTextKey[data.band])
    local badgeX = textX + nameWidth + 12
    local badgeTextWidth = getTextManager():MeasureStringX(UIFont.Small, bandText)
    local badgeHeight = getTextManager():getFontHeight(UIFont.Small) + 4
    local badgeY = lineY + 2
    self:drawRect(badgeX, badgeY, badgeTextWidth + 10, badgeHeight, 0.35, color.r, color.g, color.b)
    self:drawRectBorder(badgeX, badgeY, badgeTextWidth + 10, badgeHeight, 1, color.r, color.g, color.b)
    self:drawText(bandText, badgeX + 5, badgeY + 2, color.r, color.g, color.b, 1, UIFont.Small)
    lineY = lineY + getTextManager():getFontHeight(UIFont.Medium) + LINE_GAP

    for _, line in ipairs(data.statusLines) do
        self:drawText(line, textX, lineY, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 1, UIFont.Small)
        lineY = lineY + lineHeight
    end

    -- Pause-days ("rest days banked") -- always visible, no skill gate.
    local pauseDaysColor = data.pauseDays >= 1 and Colors.safe or Colors.textDim
    local pauseDaysY = lineY
    self:drawText(data.pauseDaysLabel, textX, pauseDaysY, pauseDaysColor.r, pauseDaysColor.g, pauseDaysColor.b, 1, UIFont.Small)

    local mouseX, mouseY = self:getMouseX(), self:getMouseY()
    local labelWidth = getTextManager():MeasureStringX(UIFont.Small, data.pauseDaysLabel)
    local hoveredTooltip = nil
    if mouseX >= textX and mouseX <= textX + labelWidth and mouseY >= pauseDaysY and mouseY <= pauseDaysY + lineHeight then
        hoveredTooltip = self:getPauseDaysTooltip()
    end
    lineY = lineY + lineHeight

    -- Whether the deficiency penalty is actually biting right now -- always
    -- visible, no skill gate. Distinct from the band: Critical + banked
    -- pause days means the penalty is currently shielded off, not active.
    local penaltyColor = data.penaltyActive and Colors.critical or Colors.textDim
    self:drawText(data.penaltyActiveLabel, textX, lineY, penaltyColor.r, penaltyColor.g, penaltyColor.b, 1, UIFont.Small)
    lineY = lineY + lineHeight

    -- First Aid-gated exact numbers, now with a fill bar underneath --
    -- same drawRect-background + drawRect-fill + drawRectBorder pattern
    -- EHR_DebugMenuV2.lua uses for its own blood-volume bar.
    if data.numbersText then
        self:drawText(data.numbersText, textX, lineY, Colors.text.r, Colors.text.g, Colors.text.b, 1, UIFont.Small)
        lineY = lineY + lineHeight

        local barWidth = self:getWidth() - textX - PADDING
        local fillWidth = math.floor(barWidth * math.max(0, math.min(1, data.value / HARMONIE_GTP.Config.maxValue)))
        self:drawRect(textX, lineY, barWidth, BAR_HEIGHT, 1, 0.08, 0.08, 0.08)
        if fillWidth > 0 then
            self:drawRect(textX, lineY, fillWidth, BAR_HEIGHT, 1, color.r, color.g, color.b)
        end
        self:drawRectBorder(textX, lineY, barWidth, BAR_HEIGHT, 1, Colors.border.r, Colors.border.g, Colors.border.b)
        lineY = lineY + BAR_HEIGHT + 4
    end

    -- Cooking-gated top foods, drawn as a compact single line (hover for the
    -- full list) so the row height still only grows by one line, not ten.
    if data.foodLine then
        self:drawText(data.foodLine, textX, lineY, Colors.safe.r, Colors.safe.g, Colors.safe.b, 1, UIFont.Small)
        local foodLineWidth = getTextManager():MeasureStringX(UIFont.Small, data.foodLine)
        if mouseX >= textX and mouseX <= textX + foodLineWidth and mouseY >= lineY and mouseY <= lineY + lineHeight then
            local unit = VitaminUnit[vit] or ""
            local lines = {}
            for i, food in ipairs(data.topFoods) do
                table.insert(lines, string.format("%d. %s (%.1f %s)", i, food.displayName, food.amount, unit))
            end
            hoveredTooltip = table.concat(lines, "\n")
        end
        lineY = lineY + lineHeight
    end

    if hoveredTooltip then
        self.pendingTooltip = hoveredTooltip
        self.pendingTooltipX = mouseX
        self.pendingTooltipY = mouseY
    end

    -- Thin divider between rows instead of a full alternating background
    -- block (matches EHR_DebugMenuV2.lua's own section-divider technique).
    self:drawRect(0, y + rowHeight, self:getWidth(), 1, 1, Colors.border.r, Colors.border.g, Colors.border.b)

    return y + item.height
end

local LAYOUT_REFRESH_INTERVAL_MS = 2000

-- Comfortable width for the text this tab shows (Thai translations in
-- particular need more room than English) -- vanilla's own Skills tab
-- (ISCharacterInfo:render(), the "BIG CHEAT" it comments on itself) grows
-- the whole window every frame via self:setWidthAndParentWidth(math.max(
-- self.width, ...)), never shrinking it; this mirrors that same trick so
-- our tab isn't stuck at the narrow ~300px starting width every other
-- non-Skills tab uses (see HARMONIE_VitaminPanelHook.lua's header for the
-- full explanation of why that starting width is too narrow here).
local PANEL_DESIRED_WIDTH = 480

-- Real user report: the panel was stretched to whatever height the OUTER
-- character info window already happened to be (inherited via
-- HARMONIE_VitaminPanelHook.lua's `self.height - 8`, matching the Skills
-- tab's own initial sizing), leaving a big dead black area below our actual
-- content whenever the window was already tall (e.g. from a character with
-- many perks on the Skills tab). Fix: mirror vanilla's OWN Skills tab
-- pattern for HEIGHT too, not just width -- ISCharacterInfo:render() ends
-- with `self:setHeightAndParentHeight(math.min(y, 800))`, i.e. height
-- always shrinks/grows to match actual content (capped, not maxed against
-- the current height the way width is). PANEL_MAX_HEIGHT is much smaller
-- than vanilla's 800 since our content is inherently shorter -- content
-- taller than this still scrolls normally via the existing scrollbar.
local PANEL_MAX_HEIGHT = 650
local PANEL_MIN_HEIGHT = 200

function HARMONIE_VitaminPanel:prerender()
    self.pendingTooltip = nil

    self:setWidthAndParentWidth(math.max(self:getWidth(), PANEL_DESIRED_WIDTH))

    local now = getTimestampMs and getTimestampMs() or 0
    if not self.lastLayoutRefreshMs or now - self.lastLayoutRefreshMs >= LAYOUT_REFRESH_INTERVAL_MS then
        self.lastLayoutRefreshMs = now
        self:refreshLayout()
    end

    local desiredHeight = math.min(self:getScrollHeight() + PADDING * 2, PANEL_MAX_HEIGHT)
    self:setHeightAndParentHeight(math.max(desiredHeight, PANEL_MIN_HEIGHT))

    ISScrollingListBox.prerender(self)

    if self.pendingTooltip then
        self:drawTooltip(self.pendingTooltip, self.pendingTooltipX, self.pendingTooltipY)
    end
end

function HARMONIE_VitaminPanel:initialise()
    ISScrollingListBox.initialise(self)
    self:clear()
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        self:addItem(vit, vit)
    end
    self:refreshLayout()
end

function HARMONIE_VitaminPanel:new(x, y, width, height, playerNum)
    local o = ISScrollingListBox:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.backgroundColor = {r = 0, g = 0, b = 0, a = 0}
    o.borderColor = {r = 0, g = 0, b = 0, a = 0}
    o.drawBorder = false
    return o
end

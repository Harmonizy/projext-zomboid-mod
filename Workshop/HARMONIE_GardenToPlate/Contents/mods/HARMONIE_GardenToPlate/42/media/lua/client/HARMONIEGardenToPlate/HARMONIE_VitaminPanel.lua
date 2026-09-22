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

    BandTextKey/BandColor are intentionally duplicated from
    HARMONIE_NutritionUI.lua rather than shared, per this feature's own plan:
    that file is explicitly left unmodified (it's a separate, still-existing
    feature), and these are two tiny constant tables, not worth changing an
    unrelated file's contract just to avoid a few duplicated lines.

    Built on ISScrollingListBox (not a plain ISPanel) so that:
      - each row's own height grows to fit however many lines its wrapped text
        actually needs (fixes rows silently clipping/overflowing content), and
      - the whole tab scrolls with a real scrollbar once total content is
        taller than the tab area (fixes content being cut off with no way to
        reach it), same widget vanilla uses for its own Skills/Traits lists.
]]--

require "ISUI/ISScrollingListBox"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"
require "HARMONIEGardenToPlate/HARMONIE_VitaminEffects"
require "HARMONIEGardenToPlate/HARMONIE_TopFoods"

HARMONIE_VitaminPanel = ISScrollingListBox:derive("HARMONIE_VitaminPanel")

local PADDING = 10
local ICON_SIZE = 28
local ROW_GAP = 8
local LINE_GAP = 3

local BandColor = {
    critical   = {r = 0.85, g = 0.25, b = 0.25},
    low        = {r = 0.85, g = 0.75, b = 0.25},
    sufficient = {r = 0.30, g = 0.80, b = 0.35},
}

local BandTextKey = {
    critical   = "IGUI_HARMONIE_Band_Critical",
    low        = "IGUI_HARMONIE_Band_Low",
    sufficient = "IGUI_HARMONIE_Band_Sufficient",
}

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
    -- by getAbsoluteX/Y or getYScroll here, that would double-transform it.
    local x = mouseX + 16
    local y = mouseY + 16
    if x + boxWidth > self:getWidth() then x = self:getWidth() - boxWidth end

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
        band = band,
        pauseDays = pauseDays,
        statusLines = statusLines,
        pauseDaysLabel = pauseDaysLabel,
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
    local textWidth = self:getWidth() - PADDING * 2 - ICON_SIZE - 12

    local lineHeight = getTextManager():getFontHeight(UIFont.Small) + LINE_GAP
    local headerHeight = getTextManager():getFontHeight(UIFont.Medium) + LINE_GAP

    local totalHeight = 0
    for _, item in ipairs(self.items) do
        local vit = item.item
        local data = self:buildRowLines(vit, player, textWidth, hasFirstAidDetail, hasCookingFoodList)
        item.data = data
        item.hasFirstAidDetail = hasFirstAidDetail
        item.hasCookingFoodList = hasCookingFoodList

        local contentHeight = headerHeight + (#data.statusLines * lineHeight) + lineHeight -- pause days line
        if data.numbersText then contentHeight = contentHeight + lineHeight end
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

    local color = BandColor[data.band]
    local textX = PADDING + ICON_SIZE + 10
    local lineHeight = getTextManager():getFontHeight(UIFont.Small) + LINE_GAP
    local rowTop = y + 2

    self:drawRect(0, y, self:getWidth(), item.height - 3, 0.18, 0.1, 0.1, 0.1)
    self:drawTextureScaled(VitaminIcon[vit], PADDING, rowTop, ICON_SIZE, ICON_SIZE, 1, 1, 1, 1)

    local lineY = rowTop
    self:drawText(getText(VitaminNameKey[vit]), textX, lineY, 1, 1, 1, 1, UIFont.Medium)
    local nameWidth = getTextManager():MeasureStringX(UIFont.Medium, getText(VitaminNameKey[vit]))
    self:drawText(getText(BandTextKey[data.band]), textX + nameWidth + 14, lineY, color.r, color.g, color.b, 1, UIFont.Medium)
    lineY = lineY + getTextManager():getFontHeight(UIFont.Medium) + LINE_GAP

    local statusColor = (data.band == "critical") and {r = 0.95, g = 0.75, b = 0.75}
        or (data.band == "low") and {r = 0.85, g = 0.85, b = 0.85}
        or {r = 0.65, g = 0.9, b = 0.65}
    for _, line in ipairs(data.statusLines) do
        self:drawText(line, textX, lineY, statusColor.r, statusColor.g, statusColor.b, 1, UIFont.Small)
        lineY = lineY + lineHeight
    end

    -- Pause-days ("rest days banked") -- always visible, no skill gate.
    local pauseDaysColor = data.pauseDays >= 1 and {r = 0.3, g = 0.8, b = 0.35} or {r = 0.6, g = 0.6, b = 0.6}
    local pauseDaysY = lineY
    self:drawText(data.pauseDaysLabel, textX, pauseDaysY, pauseDaysColor.r, pauseDaysColor.g, pauseDaysColor.b, 1, UIFont.Small)

    local mouseX, mouseY = self:getMouseX(), self:getMouseY()
    local labelWidth = getTextManager():MeasureStringX(UIFont.Small, data.pauseDaysLabel)
    local hoveredTooltip = nil
    if mouseX >= textX and mouseX <= textX + labelWidth and mouseY >= pauseDaysY and mouseY <= pauseDaysY + lineHeight then
        hoveredTooltip = self:getPauseDaysTooltip()
    end
    lineY = lineY + lineHeight

    -- First Aid-gated exact numbers.
    if data.numbersText then
        self:drawText(data.numbersText, textX, lineY, 0.8, 0.9, 1, 1, UIFont.Small)
        lineY = lineY + lineHeight
    end

    -- Cooking-gated top foods, drawn as a compact single line (hover for the
    -- full list) so the row height still only grows by one line, not ten.
    if data.foodLine then
        self:drawText(data.foodLine, textX, lineY, 0.8, 1, 0.8, 1, UIFont.Small)
        local foodLineWidth = getTextManager():MeasureStringX(UIFont.Small, data.foodLine)
        if mouseX >= textX and mouseX <= textX + foodLineWidth and mouseY >= lineY and mouseY <= lineY + lineHeight then
            local lines = {}
            for i, food in ipairs(data.topFoods) do
                table.insert(lines, i .. ". " .. food.displayName)
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

function HARMONIE_VitaminPanel:prerender()
    self.pendingTooltip = nil

    self:setWidthAndParentWidth(math.max(self:getWidth(), PANEL_DESIRED_WIDTH))

    local now = getTimestampMs and getTimestampMs() or 0
    if not self.lastLayoutRefreshMs or now - self.lastLayoutRefreshMs >= LAYOUT_REFRESH_INTERVAL_MS then
        self.lastLayoutRefreshMs = now
        self:refreshLayout()
    end

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

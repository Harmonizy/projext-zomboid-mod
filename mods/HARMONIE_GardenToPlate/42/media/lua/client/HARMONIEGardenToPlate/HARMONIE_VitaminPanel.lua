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
]]--

require "ISUI/ISPanel"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"
require "HARMONIEGardenToPlate/HARMONIE_VitaminEffects"
require "HARMONIEGardenToPlate/HARMONIE_TopFoods"

HARMONIE_VitaminPanel = ISPanel:derive("HARMONIE_VitaminPanel")

local PADDING = 10
local ROW_HEIGHT = 70
local NAME_COL_WIDTH = 70
local BAND_COL_WIDTH = 80

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
function HARMONIE_VitaminPanel:drawTooltip(text, mouseX, mouseY)
    if not text or text == "" then return end

    local font = UIFont.Small
    local maxWidth = 260
    local lines = {}
    -- Split on explicit newlines first (the food list passes one food per
    -- line) then word-wrap each resulting line independently, so a caller's
    -- intentional line breaks are never merged back into one paragraph.
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

    local lineHeight = getTextManager():getFontHeight(font) + 2
    local boxHeight = #lines * lineHeight + 10
    local boxWidth = maxWidth + 10

    local x = mouseX + 16
    local y = mouseY + 16
    if x + boxWidth > self:getWidth() then x = self:getWidth() - boxWidth end
    if y + boxHeight > self:getHeight() then y = self:getHeight() - boxHeight end

    self:drawRect(x, y, boxWidth, boxHeight, 0.9, 0.05, 0.05, 0.05)
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

function HARMONIE_VitaminPanel:prerender()
    ISPanel.prerender(self)

    local player = self:getPlayer()
    if not player then return end

    local hasFirstAidDetail = player:getPerkLevel(Perks.Doctor) >= FIRST_AID_DETAIL_LEVEL
    local hasCookingFoodList = player:getPerkLevel(Perks.Cooking) >= COOKING_FOOD_LEVEL

    local y = PADDING
    local mouseX, mouseY = self:getMouseX(), self:getMouseY()
    local hoveredTooltip = nil

    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        local value = HARMONIE_GTP.VitData.Get(player, vit)
        local band = HARMONIE_GTP.GetBand(value)
        local color = BandColor[band]
        local pauseDays = HARMONIE_GTP.VitData.GetPauseDays(player, vit)

        local rowTop = y
        local rowBottom = y + ROW_HEIGHT

        -- Row background, alternating slightly for readability across 6 rows.
        self:drawRect(PADDING, rowTop, self:getWidth() - PADDING * 2, ROW_HEIGHT - 6, 0.15, 0.1, 0.1, 0.1)

        local textX = PADDING + 8
        self:drawText(getText(VitaminNameKey[vit]), textX, rowTop + 6, 1, 1, 1, 1, UIFont.Medium)
        self:drawText(getText(BandTextKey[band]), textX + NAME_COL_WIDTH, rowTop + 6, color.r, color.g, color.b, 1, UIFont.Medium)

        if band == "critical" then
            self:drawText(getText(VitaminDownsideKey[vit]), textX, rowTop + 26, 0.9, 0.9, 0.9, 1, UIFont.Small)
        elseif band == "low" then
            self:drawText(getText("IGUI_HARMONIE_LowWarning", getText(VitaminDownsideKey[vit])), textX, rowTop + 26, 0.75, 0.75, 0.75, 1, UIFont.Small)
        else
            self:drawText(getText("IGUI_HARMONIE_SufficientNote"), textX, rowTop + 26, 0.6, 0.85, 0.6, 1, UIFont.Small)
        end

        -- Pause-days ("rest days banked") -- always visible, no skill gate.
        local pauseDaysLabel = getText("IGUI_HARMONIE_PauseDays", math.floor(pauseDays))
        local pauseDaysColor = pauseDays >= 1 and {r = 0.3, g = 0.8, b = 0.35} or {r = 0.7, g = 0.7, b = 0.7}
        local pauseDaysX = textX
        local pauseDaysY = rowTop + 44
        self:drawText(pauseDaysLabel, pauseDaysX, pauseDaysY, pauseDaysColor.r, pauseDaysColor.g, pauseDaysColor.b, 1, UIFont.Small)

        local labelWidth = getTextManager():MeasureStringX(UIFont.Small, pauseDaysLabel)
        if mouseX >= pauseDaysX and mouseX <= pauseDaysX + labelWidth and mouseY >= pauseDaysY and mouseY <= pauseDaysY + 14 then
            hoveredTooltip = self:getPauseDaysTooltip()
        end

        -- First Aid-gated exact numbers.
        if hasFirstAidDetail then
            local requirement = HARMONIE_GTP.DailyRequirement[vit]
            local numbersText = getText("IGUI_HARMONIE_ExactNumbers", string.format("%.1f", value), requirement)
            self:drawText(numbersText, textX + BAND_COL_WIDTH + NAME_COL_WIDTH, rowTop + 6, 0.8, 0.9, 1, 1, UIFont.Small)
        end

        -- Cooking-gated top foods, drawn as a compact single line (hover for
        -- the full list) to keep every row a fixed, predictable height.
        if hasCookingFoodList then
            local topFoods = HARMONIE_GTP.GetTopFoods(vit, 10)
            local foodLine
            if #topFoods > 0 then
                foodLine = getText("IGUI_HARMONIE_TopFoodsInline", topFoods[1].displayName)
            else
                foodLine = getText("IGUI_HARMONIE_TopFoodsNone")
            end
            local foodY = rowTop + 44
            local foodX = textX + BAND_COL_WIDTH + NAME_COL_WIDTH
            self:drawText(foodLine, foodX, foodY, 0.8, 1, 0.8, 1, UIFont.Small)

            local foodLineWidth = getTextManager():MeasureStringX(UIFont.Small, foodLine)
            if mouseX >= foodX and mouseX <= foodX + foodLineWidth and mouseY >= foodY and mouseY <= foodY + 14 then
                local lines = {}
                for i, food in ipairs(topFoods) do
                    table.insert(lines, i .. ". " .. food.displayName)
                end
                hoveredTooltip = table.concat(lines, "\n")
            end
        end

        y = rowBottom
    end

    if hoveredTooltip then
        self:drawTooltip(hoveredTooltip, mouseX, mouseY)
    end
end

function HARMONIE_VitaminPanel:createChildren()
    ISPanel.createChildren(self)
end

function HARMONIE_VitaminPanel:new(x, y, width, height, playerNum)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.backgroundColor = {r = 0, g = 0, b = 0, a = 0}
    o.borderColor = {r = 0, g = 0, b = 0, a = 0}
    return o
end

--[[
    HARMONIE - From Garden to Plate
    Nutrition Assessment window, opened via right-click on self or another
    survivor. Shows Critical/Low/Sufficient bands for all 6 vitamins.
    Locked (red overlay, no real values shown) unless the assessor's First
    Aid perk is >= HARMONIE_GTP.Config.assessmentRequiredFirstAid.

    Text-only display -- no gauge/bar. Each row also shows a "+" (green)
    if the vitamin still has banked pause days (decay is being held off)
    or a "-" (red) if none are left (actively decaying that day) -- see
    HARMONIE_VitaminData.lua's pauseDays.
]]--

require "ISUI/ISCollapsableWindow"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

HARMONIE_NutritionUI = ISCollapsableWindow:derive("HARMONIE_NutritionUI")

local ROW_HEIGHT = 26
local PADDING = 10
local NAME_COL_WIDTH = 90
local BAND_COL_WIDTH = 90
local WINDOW_WIDTH = PADDING * 2 + NAME_COL_WIDTH + BAND_COL_WIDTH + 30

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

function HARMONIE_NutritionUI:isLocked()
    -- B42 renamed the First Aid perk's internal id to "Doctor" (the skill
    -- book / UI still call it First Aid, but Perks.FirstAid doesn't exist
    -- and getPerkLevel(nil) silently behaved as "always locked")
    return self.assessor:getPerkLevel(Perks.Doctor) < HARMONIE_GTP.Config.assessmentRequiredFirstAid
end

function HARMONIE_NutritionUI:createChildren()
    ISCollapsableWindow.createChildren(self)
end

function HARMONIE_NutritionUI:prerender()
    ISCollapsableWindow.prerender(self)

    local y = self:titleBarHeight() + PADDING
    local locked = self:isLocked()

    if locked then
        self:drawText(getText("IGUI_HARMONIE_AssessmentLocked", HARMONIE_GTP.Config.assessmentRequiredFirstAid),
            PADDING, y, 1, 0.4, 0.4, 1, UIFont.Small)
        y = y + ROW_HEIGHT
        self:drawRect(PADDING, y, self.width - PADDING * 2, self.height - y - PADDING, 0.35, 0.6, 0.1, 0.1)
        self:drawRectBorder(PADDING, y, self.width - PADDING * 2, self.height - y - PADDING, 1, 0.6, 0.15, 0.15)
        return
    end

    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        local value = HARMONIE_GTP.VitData.Get(self.target, vit)
        local band = HARMONIE_GTP.GetBand(value)
        local color = BandColor[band]
        local hasPauseDays = HARMONIE_GTP.VitData.GetPauseDays(self.target, vit) >= 1

        self:drawText(getText(VitaminNameKey[vit]), PADDING, y, 1, 1, 1, 1, UIFont.Small)
        self:drawText(getText(BandTextKey[band]), PADDING + NAME_COL_WIDTH, y, color.r, color.g, color.b, 1, UIFont.Small)

        if hasPauseDays then
            self:drawText("+", PADDING + NAME_COL_WIDTH + BAND_COL_WIDTH, y, 0.3, 0.8, 0.35, 1, UIFont.Small)
        else
            self:drawText("-", PADDING + NAME_COL_WIDTH + BAND_COL_WIDTH, y, 0.85, 0.25, 0.25, 1, UIFont.Small)
        end

        y = y + ROW_HEIGHT
    end
end

--[[
    target: IsoPlayer whose vitamins are being read
    assessor: IsoPlayer performing the check -- their First Aid skill gates
        whether the window shows real values or a locked placeholder
]]--
function HARMONIE_NutritionUI:new(x, y, target, assessor)
    local rowCount = #HARMONIE_GTP.Vitamins
    local height = 40 + rowCount * ROW_HEIGHT + PADDING
    local o = ISCollapsableWindow:new(x, y, WINDOW_WIDTH, height)
    setmetatable(o, self)
    self.__index = self
    o.target = target
    o.assessor = assessor
    o:setTitle(getText("IGUI_HARMONIE_AssessmentTitle"))
    o.resizable = false
    return o
end

-- Clears the tracked instance on close (title bar X, Escape, etc.), same
-- as pressing the hotkey a second time does below, so either way of
-- closing it leaves HARMONIE_NutritionUI.instance accurately reflecting
-- whether a window is actually open.
function HARMONIE_NutritionUI:close()
    ISCollapsableWindow.close(self)
    if HARMONIE_NutritionUI.instance == self then
        HARMONIE_NutritionUI.instance = nil
    end
end

--[[
    Pressing the assess hotkey repeatedly used to stack a fresh window on
    top of the last one every time, since this used to just always
    create+open a new one. Now it toggles: if a window from this mod is
    already open, close THAT one and stop (don't also open a new one) --
    only opens a new window when none is currently up.
]]--
function HARMONIE_NutritionUI.Open(target, assessor)
    if HARMONIE_NutritionUI.instance then
        HARMONIE_NutritionUI.instance:close()
        return nil
    end

    local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
    local height = 40 + #HARMONIE_GTP.Vitamins * ROW_HEIGHT + PADDING
    local window = HARMONIE_NutritionUI:new(screenW / 2 - WINDOW_WIDTH / 2, screenH / 2 - height / 2, target, assessor)
    window:initialise()
    window:addToUIManager()
    HARMONIE_NutritionUI.instance = window
    return window
end

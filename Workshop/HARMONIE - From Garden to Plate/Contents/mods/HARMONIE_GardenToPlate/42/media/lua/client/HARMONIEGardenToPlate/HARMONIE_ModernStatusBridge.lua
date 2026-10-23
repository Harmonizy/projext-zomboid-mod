--[[
    HARMONIE - From Garden to Plate
    Adds one Modern Status HUD indicator per vitamin (Workshop 3451167732,
    id=ModernStatus), so players can put a vitamin bar right on their HUD
    instead of only seeing it via a moodle or the character-panel tab.

    Hard dependency via require=ModernStatus in mod.info. Pattern lifted
    directly from Modern Status's own media/lua/client/MS/Patch/
    LifestyleHobbiesSupport.lua (a real file shipped inside the published
    mod, showing a third-party mod can add its own indicators without Modern
    Status's author needing to add explicit support) -- confirmed against
    that actual source, not guessed; see mods/workflow.txt section 8.4 for
    how Modern Status itself reads stats, and this file for how another mod
    plugs into its indicator list.

    Read-only presentation on top of the existing, unmodified vitamin system,
    same as HARMONIE_VitaminMoodles.lua -- never writes to VitData.

    require=ModernStatus orders the WHOLE requiring mod's Lua after the
    required mod's (confirmed real/tested in this repo, workflow.txt section
    1), so by the time this file's top level runs, ModernStatus's own files
    (StatusWidget, MSConfig, MS_StatusIndicator, MS_IndicatorSettingsPanel)
    have already executed -- this file used to defer everything to
    Events.OnGameBoot to work around a load-order bug from when this
    dependency was still soft/optional (no require=); confirmed via
    console.txt on a real save that `require "MS/MS_StatusIndicator"` failed
    when GardenToPlate loaded before ModernStatus. Now that require= forces
    the correct order, straight top-level code is enough, matching every
    other HARMONIE mod's hard-require= files.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"
require "MS/MS_StatusIndicator"

local VITAMIN_INDICATOR_COLOR = {
    A = {r = 0.90, g = 0.50, b = 0.14},
    B = {r = 0.95, g = 0.77, b = 0.06},
    C = {r = 1.00, g = 0.81, b = 0.33},
    D = {r = 0.20, g = 0.60, b = 0.86},
    E = {r = 0.15, g = 0.68, b = 0.38},
    K = {r = 0.61, g = 0.35, b = 0.71},
}

-- One MS_StatusIndicator subclass per vitamin. baseIconName reuses the same
-- 30x30 moodle icon (media/ui/Vitamin<X>.png) already added for
-- HARMONIE_VitaminMoodles.lua rather than shipping a second copy of the art.
local IndicatorClasses = {}
for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
    local className = "HARMONIE_Vitamin" .. vit .. "StatusIndicator"
    local indicatorClass = MS_StatusIndicator:derive(className)

    indicatorClass.new = function(self, x, y, width, height, player)
        local o = MS_StatusIndicator.new(self, x, y, width, height, player)
        o.baseIconName = "Vitamin" .. vit
        o.__type = className
        o.indicatorColor = VITAMIN_INDICATOR_COLOR[vit]
        return o
    end

    -- 0.13.2: the one rule of every vitamin window (HARMONIE_GTP.VitaminView):
    -- below First Aid 2 the bar shows only the state -- a fixed height per
    -- band -- not the real Reserve
    indicatorClass.getValue = function(self)
        if not self.player or self.player:isDead() then return 0 end
        local value = HARMONIE_GTP.VitData.Get(self.player, vit)
        local view = HARMONIE_GTP.VitaminView and HARMONIE_GTP.VitaminView(self.player) or "numbers"
        if HARMONIE_GTP.LogOnce then
            HARMONIE_GTP.LogOnce("msview:" .. vit .. ":" .. view, "ModernStatus", "vitamin %s HUD bar shows %s (First Aid rule)", vit, view == "name" and "only its state" or "the real Reserve")
        end
        if view == "name" then
            local band = HARMONIE_GTP.GetBand(value)
            return (band == "critical" and 0.1) or (band == "low" and 0.35) or 1
        end
        return value / HARMONIE_GTP.Config.maxValue
    end

    _G[className] = indicatorClass
    IndicatorClasses[vit] = indicatorClass

    if MS_IndicatorSettingsPanel and MS_IndicatorSettingsPanel.IndicatorNames then
        MS_IndicatorSettingsPanel.IndicatorNames[className] = "IGUI_HARMONIE_ModernStatus_Vitamin" .. vit
    end
end

local originalCreateUI = StatusWidget.createUI
StatusWidget.createUI = function(playerIndex, player)
    originalCreateUI(playerIndex, player)

    if not StatusWidget.indicators[playerIndex] then
        StatusWidget.indicators[playerIndex] = {}
    end

    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        local className = "HARMONIE_Vitamin" .. vit .. "StatusIndicator"
        if not StatusWidget.indicators[playerIndex][className] then
            local config = MSConfig.getIndicatorConfig(playerIndex, className)
            local width, height
            if config.style == "bar" then
                width, height = config.barSize.width, config.barSize.height
            else
                width, height = config.circularSize, config.circularSize
            end

            local indicator = IndicatorClasses[vit]:new(config.position.x, config.position.y, width, height, player)
            indicator:initialise()
            indicator:addToUIManager()
            StatusWidget.indicators[playerIndex][className] = indicator
        end
    end
end

local originalCreateDefaultConfig = MSConfig.createDefaultConfig
MSConfig.createDefaultConfig = function(playerNum)
    local config = originalCreateDefaultConfig(playerNum)

    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        local className = "HARMONIE_Vitamin" .. vit .. "StatusIndicator"
        if not config.indicators[className] then
            config.indicators[className] = MSConfig.getDefaultIndicatorConfig(className)
            config.indicators[className].color = VITAMIN_INDICATOR_COLOR[vit]
        end
    end

    return config
end

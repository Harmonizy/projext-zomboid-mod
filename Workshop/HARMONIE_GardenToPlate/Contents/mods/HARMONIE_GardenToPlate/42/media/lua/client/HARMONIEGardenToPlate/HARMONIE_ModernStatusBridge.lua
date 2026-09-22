--[[
    HARMONIE - From Garden to Plate
    Adds one Modern Status HUD indicator per vitamin (Workshop 3451167732,
    id=ModernStatus), so players who use that mod can put a vitamin bar
    right on their HUD instead of only seeing it via a moodle or the
    character-panel tab.

    Soft dependency, no require= on ModernStatus at all -- this whole file
    is a no-op if Modern Status isn't active. Pattern lifted directly from
    Modern Status's own media/lua/client/MS/Patch/LifestyleHobbiesSupport.lua
    (a real file shipped inside the published mod, showing a third-party mod
    can add its own indicators without Modern Status's author needing to add
    explicit support) -- confirmed against that actual source, not guessed;
    see mods/workflow.txt section 8.4 for how Modern Status itself reads
    stats, and this file for how another mod plugs into its indicator list.

    Read-only presentation on top of the existing, unmodified vitamin system,
    same as HARMONIE_VitaminMoodles.lua -- never writes to VitData.

    Everything (the require of MS_StatusIndicator included) is deferred to
    Events.OnGameBoot, not run at file-load time. GardenToPlate has no
    require=ModernStatus in mod.info (soft dependency, by design), so PZ's
    own mod load order does NOT guarantee ModernStatus's own Lua has already
    executed by the time this file's top level runs -- confirmed via
    console.txt on a real save: HARMONIE_GardenToPlate loaded before
    ModernStatus, and `require "MS/MS_StatusIndicator"` failed because that
    chain (MS_MatrixManager/MS_GridManager/MS_IndicatorVisualConfig/etc.)
    relies on state ModernStatus's own files set up as THEY load in order.
    OnGameBoot fires once, after every active mod's Lua has fully loaded, so
    by then that chain is safe to require regardless of our own load
    position.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

local isInitialized = false

local function isModernStatusActive()
    local activatedMods = getActivatedMods()
    for i = 0, activatedMods:size() - 1 do
        if activatedMods:get(i) == "ModernStatus" then
            return true
        end
    end
    return false
end

local VITAMIN_INDICATOR_COLOR = {
    A = {r = 0.90, g = 0.50, b = 0.14},
    B = {r = 0.95, g = 0.77, b = 0.06},
    C = {r = 1.00, g = 0.81, b = 0.33},
    D = {r = 0.20, g = 0.60, b = 0.86},
    E = {r = 0.15, g = 0.68, b = 0.38},
    K = {r = 0.61, g = 0.35, b = 0.71},
}

local function integrateToModernStatus()
    if isInitialized then return end
    if not isModernStatusActive() then return end

    local status, MS_StatusIndicator = pcall(require, "MS/MS_StatusIndicator")
    if not status or not MS_StatusIndicator then
        print("HARMONIE_GardenToPlate: ModernStatus detected but MS_StatusIndicator failed to load, skipping vitamin indicators.")
        return
    end

    -- One MS_StatusIndicator subclass per vitamin. baseIconName reuses the
    -- same 30x30 moodle icon (media/ui/Vitamin<X>.png) already added for
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

        indicatorClass.getValue = function(self)
            if not self.player or self.player:isDead() then return 0 end
            return HARMONIE_GTP.VitData.Get(self.player, vit) / HARMONIE_GTP.Config.maxValue
        end

        _G[className] = indicatorClass
        IndicatorClasses[vit] = indicatorClass
    end

    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        local className = "HARMONIE_Vitamin" .. vit .. "StatusIndicator"
        if MS_IndicatorSettingsPanel and MS_IndicatorSettingsPanel.IndicatorNames then
            MS_IndicatorSettingsPanel.IndicatorNames[className] = "IGUI_HARMONIE_ModernStatus_Vitamin" .. vit
        end
    end

    if not StatusWidget._originalCreateUI_HARMONIE_GTP then
        StatusWidget._originalCreateUI_HARMONIE_GTP = StatusWidget.createUI
    end

    StatusWidget.createUI = function(playerIndex, player)
        StatusWidget._originalCreateUI_HARMONIE_GTP(playerIndex, player)

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

    if not MSConfig._originalCreateDefaultConfig_HARMONIE_GTP then
        MSConfig._originalCreateDefaultConfig_HARMONIE_GTP = MSConfig.createDefaultConfig

        MSConfig.createDefaultConfig = function(playerNum)
            local config = MSConfig._originalCreateDefaultConfig_HARMONIE_GTP(playerNum)

            for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
                local className = "HARMONIE_Vitamin" .. vit .. "StatusIndicator"
                if not config.indicators[className] then
                    config.indicators[className] = MSConfig.getDefaultIndicatorConfig(className)
                    config.indicators[className].color = VITAMIN_INDICATOR_COLOR[vit]
                end
            end

            return config
        end
    end

    isInitialized = true
end

Events.OnGameBoot.Add(integrateToModernStatus)

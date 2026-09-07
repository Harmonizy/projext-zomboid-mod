--[[
    HARMONIE - From Garden to Plate
    Admin-only debug panel: live sliders for a target character's 6 vitamin
    Reserve gauges, plus live sandbox tuning for this mod (decay rate,
    thresholds, effect severity) written straight into SandboxVars so
    changes apply immediately without a world restart.

    Gate: only reachable via its hotkey (default "/", rebindable under
    Options -> Mods) when isAdmin() or getDebug() is true (see
    HARMONIE_Hotkeys.lua / HARMONIE_KeybindManager.lua). This is a
    single-player/host convenience -- in multiplayer the values it writes
    are local to the host; use the proper Sandbox Options screen
    (sandbox-options.txt in this mod) if you need them to sync to clients.
]]--

require "ISUI/ISCollapsableWindow"
require "RadioCom/ISUIRadio/ISSliderPanel"
require "ISUI/ISTickBox"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

HARMONIE_AdminPanel = ISCollapsableWindow:derive("HARMONIE_AdminPanel")

local ROW_H = 30
local PAD = 12
local LABEL_W = 130
local SLIDER_W = 180
local VALUE_W = 50

local VitaminLabel = {
    A = "IGUI_HARMONIE_Vitamin_A", B = "IGUI_HARMONIE_Vitamin_B", C = "IGUI_HARMONIE_Vitamin_C",
    D = "IGUI_HARMONIE_Vitamin_D", E = "IGUI_HARMONIE_Vitamin_E", K = "IGUI_HARMONIE_Vitamin_K",
}

local function ensureSandbox()
    SandboxVars.HARMONIE_GardenToPlate = SandboxVars.HARMONIE_GardenToPlate or {}
    return SandboxVars.HARMONIE_GardenToPlate
end

function HARMONIE_AdminPanel:addRow(y, titleKey, min, max, step, getValue, onChange, isInt)
    local label = ISLabel:new(PAD, y + 6, ROW_H, getText(titleKey), 1, 1, 1, 1, UIFont.Small, true)
    label:initialise()
    self:addChild(label)

    local slider = ISSliderPanel:new(PAD + LABEL_W, y, SLIDER_W, ROW_H, self, HARMONIE_AdminPanel.onSliderChange)
    slider:initialise()
    slider.harmonieOnChange = onChange
    slider.harmonieIsInt = isInt
    -- the trailing `true` (ignoreCurVal) stops setValues from immediately
    -- firing onValueChange with the slider's placeholder default (50) --
    -- without it, opening the panel would instantly overwrite every real
    -- value (e.g. DecayPerDay) with 50, and would also crash the first
    -- time since harmonieOnChange/harmonieIsInt weren't set until after
    -- this call
    slider:setValues(min, max, step, step * 5, true)
    slider.currentValue = getValue()
    self:addChild(slider)

    local valueLabel = ISLabel:new(PAD + LABEL_W + SLIDER_W + 8, y + 6, ROW_H, "", 1, 1, 1, 1, UIFont.Small, true)
    valueLabel:initialise()
    self:addChild(valueLabel)
    slider.harmonieValueLabel = valueLabel

    return y + ROW_H + 4
end

function HARMONIE_AdminPanel:onSliderChange(newValue, slider)
    if slider.harmonieIsInt then newValue = math.floor(newValue + 0.5) end
    slider.harmonieOnChange(newValue)
end

function HARMONIE_AdminPanel:createChildren()
    ISCollapsableWindow.createChildren(self)

    local y = self:titleBarHeight() + PAD

    local header = ISLabel:new(PAD, y, ROW_H, getText("IGUI_HARMONIE_AdminVitaminsHeader", self.target:getDisplayName()), 1, 1, 1, 1, UIFont.Small, true)
    header:initialise()
    self:addChild(header)
    y = y + ROW_H

    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        y = self:addRow(y, VitaminLabel[vit], 0, 100, 1,
            function() return HARMONIE_GTP.VitData.Get(self.target, vit) end,
            function(v) HARMONIE_GTP.VitData.Set(self.target, vit, v) end,
            true)
    end

    y = y + 10
    local sbHeader = ISLabel:new(PAD, y, ROW_H, getText("IGUI_HARMONIE_AdminSandboxHeader"), 1, 1, 1, 1, UIFont.Small, true)
    sbHeader:initialise()
    self:addChild(sbHeader)
    y = y + ROW_H

    local sb = ensureSandbox()

    y = self:addRow(y, "IGUI_HARMONIE_AdminDecayPerDay", 0, 20, 0.5,
        function() return HARMONIE_GTP.Config.decayPerDay end,
        function(v) sb.DecayPerDay = v; HARMONIE_GTP.RefreshFromSandbox() end)

    y = self:addRow(y, "IGUI_HARMONIE_AdminReserveGainDivisor", 1, 50, 1,
        function() return HARMONIE_GTP.Config.reserveGainDivisor end,
        function(v) sb.ReserveGainDivisor = v; HARMONIE_GTP.RefreshFromSandbox() end,
        true)

    y = self:addRow(y, "IGUI_HARMONIE_AdminCriticalThreshold", 0, 99, 1,
        function() return HARMONIE_GTP.Config.criticalThreshold end,
        function(v) sb.CriticalThreshold = v; HARMONIE_GTP.RefreshFromSandbox() end,
        true)

    y = self:addRow(y, "IGUI_HARMONIE_AdminSufficientThreshold", 1, 100, 1,
        function() return HARMONIE_GTP.Config.sufficientThreshold end,
        function(v) sb.SufficientThreshold = v; HARMONIE_GTP.RefreshFromSandbox() end,
        true)

    y = self:addRow(y, "IGUI_HARMONIE_AdminEffectMultiplier", 0, 5, 0.1,
        function() return HARMONIE_GTP.Config.effectMultiplier end,
        function(v) sb.EffectMultiplier = v; HARMONIE_GTP.RefreshFromSandbox() end)

    self.effectsTickBox = ISTickBox:new(PAD, y, SLIDER_W, ROW_H, "", self, HARMONIE_AdminPanel.onEffectsToggle)
    self.effectsTickBox:initialise()
    self.effectsTickBox.selected[1] = HARMONIE_GTP.Config.effectsEnabled
    self:addChild(self.effectsTickBox)
    self.effectsTickBox:addOption(getText("IGUI_HARMONIE_AdminEnableEffects"))
    y = y + ROW_H + PAD

    self:setHeight(y)
end

function HARMONIE_AdminPanel:onEffectsToggle(optionIndex, selected)
    local sb = ensureSandbox()
    sb.EnableCriticalEffects = selected
    HARMONIE_GTP.RefreshFromSandbox()
end

function HARMONIE_AdminPanel:prerender()
    ISCollapsableWindow.prerender(self)
    for _, child in ipairs(self.children or {}) do
        if child.isSliderPanel and child.harmonieValueLabel then
            local v = child.currentValue
            local text = child.harmonieIsInt and tostring(math.floor(v + 0.5)) or string.format("%.1f", v)
            child.harmonieValueLabel:setName(text)
        end
    end
end

function HARMONIE_AdminPanel:new(x, y, target)
    local width = PAD * 2 + LABEL_W + SLIDER_W + VALUE_W + 20
    local o = ISCollapsableWindow:new(x, y, width, 400)
    setmetatable(o, self)
    self.__index = self
    o.target = target
    o:setTitle(getText("IGUI_HARMONIE_AdminTitle"))
    o.resizable = false
    return o
end

function HARMONIE_AdminPanel.Open(target)
    local width = PAD * 2 + LABEL_W + SLIDER_W + VALUE_W + 20
    local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
    local window = HARMONIE_AdminPanel:new(screenW / 2 - width / 2, screenH / 2 - 250, target)
    window:initialise()
    window:addToUIManager()
    return window
end

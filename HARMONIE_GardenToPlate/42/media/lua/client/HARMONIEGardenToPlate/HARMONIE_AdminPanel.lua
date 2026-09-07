--[[
    HARMONIE - From Garden to Plate
    Admin-only debug panel: type exact numbers into a target character's 6
    vitamin Reserve/Pause Days fields (plus a live read-only Critical/Low/
    Sufficient status line per vitamin), and live sandbox tuning for this
    mod (decay rate, thresholds, effect severity) written straight into
    SandboxVars so changes apply immediately without a world restart.

    Every editable field is a plain numeric ISTextEntryBox (no sliders --
    typing an exact value, including fractions like Reserve=42.5, is more
    useful for testing than dragging a slider ever was) with its own
    getText()-driven tooltip explaining what it does; a value commits when
    Enter is pressed or the field loses focus (matches vanilla's own
    Sandbox Options screen -- committing on every keystroke would fight
    the player mid-type on things like "-" or a bare ".").

    Gate: only reachable via its hotkey (default "/", rebindable under
    Options -> Mods) when isAdmin() or getDebug() is true (see
    HARMONIE_Hotkeys.lua / HARMONIE_KeybindManager.lua). This is a
    single-player/host convenience -- in multiplayer the values it writes
    are local to the host; use the proper Sandbox Options screen
    (sandbox-options.txt in this mod) if you need them to sync to clients.
]]--

require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextEntryBox"
require "ISUI/ISTickBox"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

HARMONIE_AdminPanel = ISCollapsableWindow:derive("HARMONIE_AdminPanel")

local ROW_H = 24
local ROW_GAP = 4
local SECTION_GAP = 10
local PAD = 12
local LABEL_W = 150
local ENTRY_W = 100

-- Narrower pair used for the per-vitamin Reserve + Pause Days row, which
-- packs two labeled fields side by side instead of one label/field per row.
local PAIR_LABEL_W = 70
local PAIR_ENTRY_W = 80
local PAIR_GAP = 14

-- The vitamin row (label+entry, twice, side by side) is wider than a
-- single sandbox label+entry row, so the window has to be sized to fit
-- the wider of the two rather than just the sandbox section's own width.
local VITAMIN_ROW_WIDTH = PAD + (PAIR_LABEL_W + PAIR_ENTRY_W) * 2 + PAIR_GAP + PAD
local SANDBOX_ROW_WIDTH = PAD + LABEL_W + ENTRY_W + PAD
local WINDOW_WIDTH = math.max(VITAMIN_ROW_WIDTH, SANDBOX_ROW_WIDTH)

local VitaminLabel = {
    A = "IGUI_HARMONIE_Vitamin_A", B = "IGUI_HARMONIE_Vitamin_B", C = "IGUI_HARMONIE_Vitamin_C",
    D = "IGUI_HARMONIE_Vitamin_D", E = "IGUI_HARMONIE_Vitamin_E", K = "IGUI_HARMONIE_Vitamin_K",
}

local BandTextKey = {
    critical   = "IGUI_HARMONIE_Band_Critical",
    low        = "IGUI_HARMONIE_Band_Low",
    sufficient = "IGUI_HARMONIE_Band_Sufficient",
}

local function ensureSandbox()
    SandboxVars.HARMONIE_GardenToPlate = SandboxVars.HARMONIE_GardenToPlate or {}
    return SandboxVars.HARMONIE_GardenToPlate
end

--[[
    Parses `entry`'s current text as a number, clamps it into
    [entry.harmonieMin, entry.harmonieMax] (rounding to a whole number
    first if entry.harmonieIsInt), writes the clamped value back into the
    box (so what's displayed always matches what's actually stored -- e.g.
    typing 500 into a 0-100 field snaps back to "100"), calls
    entry.harmonieOnChange(value). If the text doesn't parse as a number
    at all (e.g. left empty, or just "-"), colors the field invalid (red
    border via ISTextEntryBox:setValid) and leaves the stored value alone
    instead of guessing. Shared by both onCommandEntered (Enter key) and
    onLostFocus (click/tab away) so a value applies however the player
    finishes editing it.
]]--
local function commitEntry(entry)
    local num = tonumber(entry:getInternalText())
    if not num then
        entry:setValid(false)
        return
    end
    num = math.max(entry.harmonieMin, math.min(entry.harmonieMax, num))
    if entry.harmonieIsInt then num = math.floor(num + 0.5) end
    entry:setValid(true)
    entry:setText(entry.harmonieIsInt and tostring(num) or string.format("%.2f", num))
    entry.harmonieOnChange(num)
end

--[[
    One label + one numeric entry field, with a getText(tooltipKey)
    tooltip attached to the field itself (hover it to read what it does
    and what range it accepts). Returns the y position for the next row.
]]--
function HARMONIE_AdminPanel:addNumberRow(y, titleKey, tooltipKey, min, max, isInt, getValue)
    local label = ISLabel:new(PAD, y + 4, ROW_H, getText(titleKey), 1, 1, 1, 1, UIFont.Small, true)
    label:initialise()
    self:addChild(label)

    local entry = ISTextEntryBox:new(tostring(getValue()), PAD + LABEL_W, y, ENTRY_W, ROW_H)
    entry.font = UIFont.Small
    entry:initialise()
    entry:instantiate()
    entry:setOnlyNumbers(true)
    entry:setTooltip(getText(tooltipKey))
    entry.harmonieMin = min
    entry.harmonieMax = max
    entry.harmonieIsInt = isInt
    entry.onCommandEntered = commitEntry
    entry.onLostFocus = commitEntry
    self:addChild(entry)

    return entry, y + ROW_H + ROW_GAP
end

--[[
    Reserve + Pause Days side by side for one vitamin, with a live status
    label above them (Band + whether the critical penalty is currently
    active + how many consecutive days it's persisted -- refreshed every
    prerender, same as the rest of this panel). Reserve is deliberately
    NOT rounded to a whole number here (unlike the old slider version):
    Reserve is a real float internally (see HARMONIE_VitaminData.lua), so
    typing e.g. 19.99 to test right at a threshold is now possible and
    genuinely useful, not just cosmetic.
]]--
function HARMONIE_AdminPanel:addVitaminRow(y, vit)
    local statusLabel = ISLabel:new(PAD, y, ROW_H, "", 1, 1, 1, 1, UIFont.Small, true)
    statusLabel:initialise()
    self:addChild(statusLabel)
    self.harmonieStatusLabels[vit] = statusLabel
    y = y + ROW_H

    local reserveLabel = ISLabel:new(PAD, y + 4, ROW_H, getText("IGUI_HARMONIE_AdminReserveLabel"), 1, 1, 1, 1, UIFont.Small, true)
    reserveLabel:initialise()
    self:addChild(reserveLabel)

    local reserveEntry = ISTextEntryBox:new(string.format("%.2f", HARMONIE_GTP.VitData.Get(self.target, vit)),
        PAD + PAIR_LABEL_W, y, PAIR_ENTRY_W, ROW_H)
    reserveEntry.font = UIFont.Small
    reserveEntry:initialise()
    reserveEntry:instantiate()
    reserveEntry:setOnlyNumbers(true)
    reserveEntry:setTooltip(getText("IGUI_HARMONIE_AdminReserveTooltip"))
    reserveEntry.harmonieMin = 0
    reserveEntry.harmonieMax = HARMONIE_GTP.Config.maxValue
    reserveEntry.harmonieIsInt = false
    reserveEntry.harmonieOnChange = function(v)
        HARMONIE_GTP.VitData.Set(self.target, vit, v)
        -- Immediate feedback instead of waiting up to 10 real seconds for
        -- HARMONIE_VitaminChecker.lua's own poll to catch up, so the
        -- status line above reacts to a typed-in value right away.
        HARMONIE_GTP.VitData.RefreshAffliction(self.target, vit)
    end
    reserveEntry.onCommandEntered = commitEntry
    reserveEntry.onLostFocus = commitEntry
    self:addChild(reserveEntry)

    local pauseX = PAD + PAIR_LABEL_W + PAIR_ENTRY_W + PAIR_GAP
    local pauseLabel = ISLabel:new(pauseX, y + 4, ROW_H, getText("IGUI_HARMONIE_AdminPauseDaysLabel"), 1, 1, 1, 1, UIFont.Small, true)
    pauseLabel:initialise()
    self:addChild(pauseLabel)

    local pauseEntry = ISTextEntryBox:new(string.format("%.2f", HARMONIE_GTP.VitData.GetPauseDays(self.target, vit)),
        pauseX + PAIR_LABEL_W, y, PAIR_ENTRY_W, ROW_H)
    pauseEntry.font = UIFont.Small
    pauseEntry:initialise()
    pauseEntry:instantiate()
    pauseEntry:setOnlyNumbers(true)
    pauseEntry:setTooltip(getText("IGUI_HARMONIE_AdminPauseDaysTooltip"))
    pauseEntry.harmonieMin = 0
    pauseEntry.harmonieMax = 999999
    pauseEntry.harmonieIsInt = false
    pauseEntry.harmonieOnChange = function(v)
        HARMONIE_GTP.VitData.AddPauseDays(self.target, vit, v - HARMONIE_GTP.VitData.GetPauseDays(self.target, vit))
    end
    pauseEntry.onCommandEntered = commitEntry
    pauseEntry.onLostFocus = commitEntry
    self:addChild(pauseEntry)

    return y + ROW_H + SECTION_GAP
end

function HARMONIE_AdminPanel:createChildren()
    ISCollapsableWindow.createChildren(self)

    local y = self:titleBarHeight() + PAD

    local header = ISLabel:new(PAD, y, ROW_H, getText("IGUI_HARMONIE_AdminVitaminsHeader", self.target:getDisplayName()), 1, 1, 1, 1, UIFont.Small, true)
    header:initialise()
    self:addChild(header)
    y = y + ROW_H

    local hint = ISLabel:new(PAD, y, ROW_H, getText("IGUI_HARMONIE_AdminHint"), 0.7, 0.7, 0.7, 1, UIFont.Small, true)
    hint:initialise()
    self:addChild(hint)
    y = y + ROW_H + ROW_GAP

    self.harmonieStatusLabels = {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        y = self:addVitaminRow(y, vit)
    end

    y = y + SECTION_GAP - ROW_GAP
    local sbHeader = ISLabel:new(PAD, y, ROW_H, getText("IGUI_HARMONIE_AdminSandboxHeader"), 1, 1, 1, 1, UIFont.Small, true)
    sbHeader:initialise()
    self:addChild(sbHeader)
    y = y + ROW_H

    local sb = ensureSandbox()
    local entry

    entry, y = self:addNumberRow(y, "IGUI_HARMONIE_AdminDecayPerDay", "Sandbox_HARMONIE_DecayPerDay_tooltip", 0, 20, false,
        function() return HARMONIE_GTP.Config.decayPerDay end)
    entry.harmonieOnChange = function(v) sb.DecayPerDay = v; HARMONIE_GTP.RefreshFromSandbox() end

    entry, y = self:addNumberRow(y, "IGUI_HARMONIE_AdminReserveGainDivisor", "Sandbox_HARMONIE_ReserveGainDivisor_tooltip", 1, 50, true,
        function() return HARMONIE_GTP.Config.reserveGainDivisor end)
    entry.harmonieOnChange = function(v) sb.ReserveGainDivisor = v; HARMONIE_GTP.RefreshFromSandbox() end

    entry, y = self:addNumberRow(y, "IGUI_HARMONIE_AdminCriticalThreshold", "Sandbox_HARMONIE_CriticalThreshold_tooltip", 0, 99, true,
        function() return HARMONIE_GTP.Config.criticalThreshold end)
    entry.harmonieOnChange = function(v) sb.CriticalThreshold = v; HARMONIE_GTP.RefreshFromSandbox() end

    entry, y = self:addNumberRow(y, "IGUI_HARMONIE_AdminSufficientThreshold", "Sandbox_HARMONIE_SufficientThreshold_tooltip", 1, 100, true,
        function() return HARMONIE_GTP.Config.sufficientThreshold end)
    entry.harmonieOnChange = function(v) sb.SufficientThreshold = v; HARMONIE_GTP.RefreshFromSandbox() end

    entry, y = self:addNumberRow(y, "IGUI_HARMONIE_AdminEffectMultiplier", "Sandbox_HARMONIE_EffectMultiplier_tooltip", 0, 5, false,
        function() return HARMONIE_GTP.Config.effectMultiplier end)
    entry.harmonieOnChange = function(v) sb.EffectMultiplier = v; HARMONIE_GTP.RefreshFromSandbox() end

    self.effectsTickBox = ISTickBox:new(PAD, y, LABEL_W + ENTRY_W, ROW_H, "", self, HARMONIE_AdminPanel.onEffectsToggle)
    self.effectsTickBox:initialise()
    self.effectsTickBox.selected[1] = HARMONIE_GTP.Config.effectsEnabled
    self:addChild(self.effectsTickBox)
    self.effectsTickBox:addOption(getText("IGUI_HARMONIE_AdminEnableEffects"))
    self.effectsTickBox.tooltip = getText("Sandbox_HARMONIE_EnableCriticalEffects_tooltip")
    y = y + ROW_H + PAD

    self:setHeight(y)
end

function HARMONIE_AdminPanel:onEffectsToggle(optionIndex, selected)
    local sb = ensureSandbox()
    sb.EnableCriticalEffects = selected
    HARMONIE_GTP.RefreshFromSandbox()
end

--[[
    Refreshes every vitamin's status line each frame: Band (Critical/Low/
    Sufficient, colored the same as HARMONIE_NutritionUI.lua) + whether
    the critical penalty is actively firing right now (afflicted AND no
    banked pause days left -- mirrors the exact gate HARMONIE_
    VitaminChecker.lua / VitEffects.ApplyCritical use) + consecutive days
    afflicted. Doesn't touch any text entry field -- those only change via
    commitEntry, so the admin can freely type without the field fighting
    back mid-edit.
]]--
function HARMONIE_AdminPanel:prerender()
    ISCollapsableWindow.prerender(self)

    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        local label = self.harmonieStatusLabels[vit]
        if label then
            local band = HARMONIE_GTP.VitData.GetBand(self.target, vit)
            local penaltyActive = HARMONIE_GTP.VitData.IsAfflicted(self.target, vit)
                    and HARMONIE_GTP.VitData.GetPauseDays(self.target, vit) <= 0
            local text = getText("IGUI_HARMONIE_AdminStatusLine",
                getText(VitaminLabel[vit]),
                getText(BandTextKey[band]),
                penaltyActive and getText("UI_Yes") or getText("UI_No"),
                HARMONIE_GTP.VitData.GetAfflictedDays(self.target, vit))
            label:setName(text)
        end
    end
end

function HARMONIE_AdminPanel:new(x, y, target)
    local o = ISCollapsableWindow:new(x, y, WINDOW_WIDTH, 400)
    setmetatable(o, self)
    self.__index = self
    o.target = target
    o:setTitle(getText("IGUI_HARMONIE_AdminTitle"))
    o.resizable = false
    return o
end

function HARMONIE_AdminPanel.Open(target)
    local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
    local window = HARMONIE_AdminPanel:new(screenW / 2 - WINDOW_WIDTH / 2, screenH / 2 - 350, target)
    window:initialise()
    window:addToUIManager()
    return window
end

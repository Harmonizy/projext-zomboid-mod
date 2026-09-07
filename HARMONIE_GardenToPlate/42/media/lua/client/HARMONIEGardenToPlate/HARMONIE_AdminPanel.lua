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
    getText()-driven tooltip explaining what it does. Typing and pressing
    Enter (or clicking away) only VALIDATES and reformats what's in the
    box -- it does NOT apply anything by itself. Nothing actually changes
    until the Save button at the bottom is pressed, which then applies
    every field (and the tickbox) at once. This is deliberate: with the
    old "applies the instant you leave the field" behavior, tabbing
    through several fields to review them could silently overwrite values
    you only meant to look at.

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
require "ISUI/ISButton"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

HARMONIE_AdminPanel = ISCollapsableWindow:derive("HARMONIE_AdminPanel")

local ROW_H = 24
local ROW_GAP = 4
local SECTION_GAP = 10
local PAD = 12
local LABEL_W = 150
local ENTRY_W = 100
local SAVE_BUTTON_H = 28

-- Narrower pair used for the per-vitamin Reserve + Pause Days row, which
-- packs two labeled fields side by side instead of one label/field per
-- row. Widened with extra breathing room on both the label and the gap
-- so neither column ever sits flush against the window's edge.
local PAIR_LABEL_W = 90
local PAIR_ENTRY_W = 80
local PAIR_GAP = 20

-- The vitamin row (label+entry, twice, side by side) is wider than a
-- single sandbox label+entry row, so the window has to be sized to fit
-- the wider of the two rather than just the sandbox section's own width.
-- The extra +20 is slack so the second column's entry box never ends up
-- flush against (or clipped by) the window's right edge.
local VITAMIN_ROW_WIDTH = PAD + (PAIR_LABEL_W + PAIR_ENTRY_W) * 2 + PAIR_GAP + PAD + 20
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
    Parses `entry`'s current text as a number and clamps it into
    [entry.harmonieMin, entry.harmonieMax] (rounding to a whole number
    first if entry.harmonieIsInt), writing the clamped value back into the
    box (so what's displayed always matches what would actually be saved
    -- e.g. typing 500 into a 0-100 field snaps back to "100"). Returns
    the parsed number, or nil (and marks the field invalid via
    ISTextEntryBox:setValid) if the text doesn't parse as a number at all
    (e.g. left empty, or just "-"). Does NOT call harmonieOnChange --
    saving is a separate, explicit step now (see the Save button), so
    this only ever validates/reformats, whether called from
    onCommandEntered, onLostFocus, or the Save button itself.
]]--
local function validateEntry(entry)
    local num = tonumber(entry:getInternalText())
    if not num then
        entry:setValid(false)
        return nil
    end
    num = math.max(entry.harmonieMin, math.min(entry.harmonieMax, num))
    if entry.harmonieIsInt then num = math.floor(num + 0.5) end
    entry:setValid(true)
    entry:setText(entry.harmonieIsInt and tostring(num) or string.format("%.2f", num))
    return num
end

--[[
    One label + one numeric entry field, with a getText(tooltipKey)
    tooltip attached to the field itself (hover it to read what it does
    and what range it accepts). Registers the entry in self.harmonieEntries
    so the Save button can find and apply it later. Returns the y position
    for the next row.
]]--
function HARMONIE_AdminPanel:addNumberRow(y, titleKey, tooltipKey, min, max, isInt, getValue, onChange)
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
    entry.harmonieOnChange = onChange
    entry.onCommandEntered = validateEntry
    entry.onLostFocus = validateEntry
    self:addChild(entry)
    table.insert(self.harmonieEntries, entry)

    return y + ROW_H + ROW_GAP
end

--[[
    Reserve + Pause Days side by side for one vitamin, with a live status
    label above them (Band + whether the critical penalty is currently
    active + how many consecutive days it's persisted -- refreshed every
    prerender, same as the rest of this panel). Reserve is deliberately
    NOT rounded to a whole number here: Reserve is a real float internally
    (see HARMONIE_VitaminData.lua), so typing e.g. 19.99 to test right at
    a threshold is genuinely useful, not just cosmetic.
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
        -- status line above reacts to a saved value right away.
        HARMONIE_GTP.VitData.RefreshAffliction(self.target, vit)
    end
    reserveEntry.onCommandEntered = validateEntry
    reserveEntry.onLostFocus = validateEntry
    self:addChild(reserveEntry)
    table.insert(self.harmonieEntries, reserveEntry)

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
    pauseEntry.onCommandEntered = validateEntry
    pauseEntry.onLostFocus = validateEntry
    self:addChild(pauseEntry)
    table.insert(self.harmonieEntries, pauseEntry)

    return y + ROW_H + SECTION_GAP
end

function HARMONIE_AdminPanel:createChildren()
    ISCollapsableWindow.createChildren(self)

    self.harmonieEntries = {}

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

    y = self:addNumberRow(y, "IGUI_HARMONIE_AdminDecayPerDay", "Sandbox_HARMONIE_DecayPerDay_tooltip", 0, 20, false,
        function() return HARMONIE_GTP.Config.decayPerDay end,
        function(v) sb.DecayPerDay = v; HARMONIE_GTP.RefreshFromSandbox() end)

    y = self:addNumberRow(y, "IGUI_HARMONIE_AdminReserveGainDivisor", "Sandbox_HARMONIE_ReserveGainDivisor_tooltip", 1, 50, true,
        function() return HARMONIE_GTP.Config.reserveGainDivisor end,
        function(v) sb.ReserveGainDivisor = v; HARMONIE_GTP.RefreshFromSandbox() end)

    y = self:addNumberRow(y, "IGUI_HARMONIE_AdminCriticalThreshold", "Sandbox_HARMONIE_CriticalThreshold_tooltip", 0, 99, true,
        function() return HARMONIE_GTP.Config.criticalThreshold end,
        function(v) sb.CriticalThreshold = v; HARMONIE_GTP.RefreshFromSandbox() end)

    y = self:addNumberRow(y, "IGUI_HARMONIE_AdminSufficientThreshold", "Sandbox_HARMONIE_SufficientThreshold_tooltip", 1, 100, true,
        function() return HARMONIE_GTP.Config.sufficientThreshold end,
        function(v) sb.SufficientThreshold = v; HARMONIE_GTP.RefreshFromSandbox() end)

    y = self:addNumberRow(y, "IGUI_HARMONIE_AdminEffectMultiplier", "Sandbox_HARMONIE_EffectMultiplier_tooltip", 0, 5, false,
        function() return HARMONIE_GTP.Config.effectMultiplier end,
        function(v) sb.EffectMultiplier = v; HARMONIE_GTP.RefreshFromSandbox() end)

    self.effectsTickBox = ISTickBox:new(PAD, y, LABEL_W + ENTRY_W, ROW_H, "", self, HARMONIE_AdminPanel.onEffectsToggle)
    self.effectsTickBox:initialise()
    self.effectsTickBox.selected[1] = HARMONIE_GTP.Config.effectsEnabled
    self:addChild(self.effectsTickBox)
    self.effectsTickBox:addOption(getText("IGUI_HARMONIE_AdminEnableEffects"))
    self.effectsTickBox.tooltip = getText("Sandbox_HARMONIE_EnableCriticalEffects_tooltip")
    -- The tickbox visually toggles immediately (that's just how ISTickBox
    -- works), but its EFFECT is deferred like everything else here --
    -- onEffectsToggle below only remembers the intended state, and Save
    -- is what actually writes it to SandboxVars.
    self.harmoniePendingEffectsEnabled = HARMONIE_GTP.Config.effectsEnabled
    y = y + ROW_H + PAD

    self.saveButton = ISButton:new(PAD, y, WINDOW_WIDTH - PAD * 2, SAVE_BUTTON_H, getText("IGUI_HARMONIE_AdminSave"), self, HARMONIE_AdminPanel.onSaveClick)
    self.saveButton:initialise()
    self.saveButton:instantiate()
    self:addChild(self.saveButton)
    y = y + SAVE_BUTTON_H + PAD

    self:setHeight(y)
end

function HARMONIE_AdminPanel:onEffectsToggle(optionIndex, selected)
    self.harmoniePendingEffectsEnabled = selected
end

--[[
    Applies every field on the panel at once: validates/clamps whatever
    is currently typed into each registered entry (skipping any left in
    an invalid, unparseable state rather than guessing) and calls its
    harmonieOnChange with the result, then writes the tickbox's
    (possibly since-changed) state to SandboxVars. Nothing above this
    point in the file changes any real value by itself -- this is the
    only place that does.
]]--
function HARMONIE_AdminPanel:onSaveClick()
    for _, entry in ipairs(self.harmonieEntries) do
        local value = validateEntry(entry)
        if value and entry.harmonieOnChange then
            entry.harmonieOnChange(value)
        end
    end

    local sb = ensureSandbox()
    sb.EnableCriticalEffects = self.harmoniePendingEffectsEnabled
    HARMONIE_GTP.RefreshFromSandbox()
end

--[[
    Refreshes every vitamin's status line each frame: Band (Critical/Low/
    Sufficient, colored the same as HARMONIE_NutritionUI.lua) + whether
    the critical penalty is actively firing right now (afflicted AND no
    banked pause days left -- mirrors the exact gate HARMONIE_
    VitaminChecker.lua / VitEffects.ApplyCritical use) + consecutive days
    afflicted. Doesn't touch any text entry field -- those only ever
    change via Save, so the admin can freely type without the field
    fighting back mid-edit.
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

-- See HARMONIE_NutritionUI.lua's close/Open for why: keeps
-- HARMONIE_AdminPanel.instance accurate no matter how the window closes.
function HARMONIE_AdminPanel:close()
    ISCollapsableWindow.close(self)
    if HARMONIE_AdminPanel.instance == self then
        HARMONIE_AdminPanel.instance = nil
    end
end

-- Toggles like the Nutrition Assessment window does: pressing the admin
-- hotkey again while the panel is already open closes it instead of
-- stacking a second one on top.
function HARMONIE_AdminPanel.Open(target)
    if HARMONIE_AdminPanel.instance then
        HARMONIE_AdminPanel.instance:close()
        return nil
    end

    local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
    local window = HARMONIE_AdminPanel:new(screenW / 2 - WINDOW_WIDTH / 2, screenH / 2 - 350, target)
    window:initialise()
    window:addToUIManager()
    HARMONIE_AdminPanel.instance = window
    return window
end

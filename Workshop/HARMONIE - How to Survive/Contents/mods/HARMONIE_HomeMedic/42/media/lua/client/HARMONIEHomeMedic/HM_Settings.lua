--[[
    HARMONIE - Home Medic : the settings window (client)

    R71 ("เพิ่มปุ่มตั้งค่า เพื่อกดเปิดหน้าต่างตั้งค่าให้ทั้ง ehr และ คราฟอาวุธ"): the
    gear in the medical window's header opens this window (HM_Settings
    rows below the class): the window (open compact, follow the character
    window, pin, size reset), sounds and the blood-loss vision. Every row
    changes the setting at once and saves it (the same values as Options >
    Mods > Home Medic). The same window as The Way To Attack's settings, in
    Home Medic's blue (our own code in both mods).

      HMSettingsUI.open(title, buildRows, theme)  (opening again closes it)
      rows: section / tick / slider / choice / step / button / note -- see
      the kinds in drawRow below.
]]--

require "ISUI/ISPanel"
-- 2026-10-11: the window itself is now the HARMONIE Hub's shared settings
-- window (client/HARMONIE_UIKit.lua) -- the same in all our mods; this file
-- keeps How to Survive's rows and colours.
require "HARMONIE_UIKit"

HMSettingsUI = HMSettingsUI or {}
-- Home Medic's blue (HM_Theme)
HMSettingsUI.THEME = {
    bg = { 0.012, 0.05, 0.068, 0.97 }
function HMSettingsUI.open(title, buildRows, theme, opts)
    return HARMONIE_SettingsUI.open(title, buildRows, theme or HMSettingsUI.THEME, opts)
end

-- ----------------------------------------------------------- Home Medic's rows
local function text(key, fallback)
    local t = getText and getText(key)
    if not t or t == key then return fallback or key end
    return t
end

local function optGet(opt, default)
    if opt and opt.getValue then
        local ok, v = pcall(opt.getValue, opt)
        if ok and v ~= nil then return v end
    end
    return default
end

local function optSet(opt, v)
    if not opt then return end
    if opt.setValue then pcall(opt.setValue, opt, v) end
    if opt.onChangeApply then pcall(opt.onChangeApply, opt, v) end
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then pcall(PZAPI.ModOptions.save, PZAPI.ModOptions) end
end

local function pct(v) return tostring(math.floor((tonumber(v) or 0) * 100 + 0.5)) .. "%" end

function HMSettingsUI.homeMedicRows()
    local O = HARMONIE_HomeMedic_Options or {}
    local K = EHR and EHR.Keybinds
    local page = K and K.modOptions
    local compact = page and page.getOption and K.IDs and page:getOption(K.IDs.OPEN_HEALTH_PANEL_COMPACT) or nil
    local function T(k) return text("UI_options_HARMONIE_HomeMedic_" .. k) end
    local function panel() return EHR and EHR.UI and EHR.UI.HealthPanelInstance end
    local rows = {
        { kind = "section", label = text("UI_HomeMedic_Set_Window", "Window") },
    }
    if compact then
        rows[#rows + 1] = { kind = "tick", label = text("UI_EHR_OpenHealthPanelCompact"), tip = text("UI_EHR_OpenHealthPanelCompact_tt"),
            get = function() return optGet(compact, false) == true end, set = function(v) optSet(compact, v) end }
    end
    if O.followCharWindow then
        rows[#rows + 1] = { kind = "tick", label = T("followCharWindow"), tip = T("followCharWindow_tooltip"),
            get = function() return optGet(O.followCharWindow, true) == true end, set = function(v) optSet(O.followCharWindow, v) end }
    end
    rows[#rows + 1] = { kind = "tick", label = text("UI_HomeMedic_Set_Pin", "Keep the medical window open (pin)"),
        tip = text("UI_HomeMedic_Set_Pin_Tip"),
        get = function() local p = panel(); return not p or p.hmPinned ~= false end,
        set = function(v)
            local p = panel()
            if p and HM_Pin and (p.hmPinned ~= false) ~= v then HM_Pin.toggle(p) end
        end }
    rows[#rows + 1] = { kind = "button", label = text("UI_HomeMedic_Set_ResetSize", "Window size and place"),
        tip = text("UI_HomeMedic_Set_ResetSize_Tip"), text = text("UI_HomeMedic_Set_Reset", "Reset"),
        run = function()
            local p = panel()
            if not p then return end
            if p.applyDefaultOpenMode then p:applyDefaultOpenMode() end
            if EHR_HealthPanelUI and EHR_HealthPanelUI.GetFitHeight then p:setHeight(EHR_HealthPanelUI.GetFitHeight()) end
            local core = getCore()
            if core then
                p:setX(math.max(0, math.floor((core:getScreenWidth() - p.width) / 2)))
                p:setY(math.max(0, math.floor((core:getScreenHeight() - p.height) / 2)))
            end
            if p.repositionControls then p:repositionControls() end
            if p.keepOnScreen then p:keepOnScreen() end
        end }
    rows[#rows + 1] = { kind = "section", label = text("UI_HomeMedic_Set_Sound", "Sound") }
    if O.deliriumVolume then
        rows[#rows + 1] = { kind = "slider", label = T("deliriumVolume"), tip = T("deliriumVolume_tooltip"), min = 0, max = 1.5, step = 0.25,
            get = function() return tonumber(optGet(O.deliriumVolume, 1)) or 1 end, set = function(v) optSet(O.deliriumVolume, v) end, fmt = pct }
    end
    if O.deliriumMuted then
        rows[#rows + 1] = { kind = "tick", label = T("deliriumMute"), tip = T("deliriumMute_tooltip"),
            get = function() return optGet(O.deliriumMuted, false) == true end, set = function(v) optSet(O.deliriumMuted, v) end }
    end
    rows[#rows + 1] = { kind = "section", label = text("UI_HomeMedic_Set_Vision", "Vision") }
    if O.bloodVision then
        rows[#rows + 1] = { kind = "tick", label = T("bloodVision"), tip = T("bloodVision_tooltip"),
            get = function() return optGet(O.bloodVision, true) == true end, set = function(v) optSet(O.bloodVision, v) end }
    end
    if O.bloodVisionStrength then
        rows[#rows + 1] = { kind = "slider", label = T("bloodVisionStrength"), tip = T("bloodVisionStrength_tooltip"), min = 0.25, max = 1.5, step = 0.25,
            get = function() return tonumber(optGet(O.bloodVisionStrength, 1)) or 1 end, set = function(v) optSet(O.bloodVisionStrength, v) end, fmt = pct }
    end
    rows[#rows + 1] = { kind = "note", label = text("UI_HomeMedic_Set_KeysNote") }
    return rows
end

function HMSettingsUI.openHomeMedic()
    HMSettingsUI.open(text("UI_HomeMedic_Set_Title", "Settings - How to Survive"), HMSettingsUI.homeMedicRows)
end

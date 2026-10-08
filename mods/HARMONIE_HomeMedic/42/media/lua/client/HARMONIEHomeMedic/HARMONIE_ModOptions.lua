--[[
    HARMONIE - Home Medic : the one Options -> Mods page for everything the
    player sets for themselves (saved on their own machine only):
      * the health-panel keys and switches (EHR_KeybindManager.lua)
      * delirium sound volume + mute   (HARMONIE_DeliriumAudio.lua)
      * blood-loss vision on/off + strength (HARMONIE_BloodVision.lua)
    Since 0.5.0 these share the keybind page (id "ExtensiveHealthRework", so
    saved keys carry over) instead of a second page of their own; the four
    options below start from their defaults once.
]]--

require "ExtensiveHealth/EHR_KeybindManager"
require "HARMONIEHomeMedic/HARMONIE_DeliriumAudio"
require "HARMONIEHomeMedic/HARMONIE_BloodVision"

HARMONIE_HomeMedic_Options = HARMONIE_HomeMedic_Options or {}
local O = HARMONIE_HomeMedic_Options
local A = HARMONIE_HomeMedic_DeliriumAudio
local V = HARMONIE_HomeMedic_BloodVision

local function hook(opt, fn)
    opt.onChange = function(_, value) fn(value) end
    -- logged on Apply only (a slider's onChange fires every step)
    opt.onChangeApply = function(_, value)
        HMLog("Options", "%s applied: %s", tostring(opt.id or opt.name or "?"), tostring(value))
        fn(value)
    end
end

if PZAPI and PZAPI.ModOptions and not O.page then
    local T = function(k) return getText("UI_options_HARMONIE_HomeMedic_" .. k) end
    local id = (EHR and EHR.Keybinds and EHR.Keybinds.MOD_OPTIONS_ID) or "ExtensiveHealthRework"
    O.page = PZAPI.ModOptions:getOptions(id) or PZAPI.ModOptions:create(id, T("title"))
    local function add(kind, optId, ...)
        return O.page:getOption(optId) or O.page[kind](O.page, optId, ...)
    end
    O.deliriumVolume = add("addSlider", "deliriumVolume", T("deliriumVolume"), 0, 1.5, 0.25, 1, T("deliriumVolume_tooltip"))
    hook(O.deliriumVolume, A.setVolume)
    O.deliriumMuted = add("addTickBox", "deliriumMuted", T("deliriumMute"), false, T("deliriumMute_tooltip"))
    hook(O.deliriumMuted, A.setMuted)
    O.bloodVision = add("addTickBox", "bloodVision", T("bloodVision"), true, T("bloodVision_tooltip"))
    hook(O.bloodVision, function(v) V.enabled = v == true end)
    O.bloodVisionStrength = add("addSlider", "bloodVisionStrength", T("bloodVisionStrength"), 0.25, 1.5, 0.25, 1, T("bloodVisionStrength_tooltip"))
    hook(O.bloodVisionStrength, function(v) V.strength = tonumber(v) or 1 end)
    -- 2026-10-02: the medical window opens / closes with the character
    -- window (HM_FollowCharacterWindow reads this tick box itself)
    O.followCharWindow = add("addTickBox", "followCharWindow", T("followCharWindow"), true, T("followCharWindow_tooltip"))
    if PZAPI.ModOptions.load then PZAPI.ModOptions:load() end
end

function O.readSaved()
    local function val(opt) return opt and opt.getValue and opt:getValue() end
    if O.deliriumVolume then A.volume = tonumber(val(O.deliriumVolume)) or 1 end
    if O.deliriumMuted then A.muted = val(O.deliriumMuted) == true end
    A.apply()
    if O.bloodVision then V.enabled = val(O.bloodVision) ~= false end
    if O.bloodVisionStrength then V.strength = tonumber(val(O.bloodVisionStrength)) or 1 end
    HMLog("Options", "saved options: delirium volume %s muted %s, blood vision %s strength %s, page %s",
        tostring(A.volume), tostring(A.muted), tostring(V.enabled), tostring(V.strength), O.page and "made" or "MISSING")
end
O.readSaved()
if Events and Events.OnGameStart then Events.OnGameStart.Add(O.readSaved) end

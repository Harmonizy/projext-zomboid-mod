--[[
    HARMONIE - Home Medic : the one Options -> Mods page for everything the
    player sets for themselves (saved on their own machine only):
      * delirium sound volume + mute   (HARMONIE_DeliriumAudio.lua)
      * blood-loss vision on/off + strength (HARMONIE_BloodVision.lua)
    Option ids "deliriumVolume" / "deliriumMuted" are kept from 0.3.1 so
    saved values carry over.
]]--

require "HARMONIEHomeMedic/HARMONIE_DeliriumAudio"
require "HARMONIEHomeMedic/HARMONIE_BloodVision"

HARMONIE_HomeMedic_Options = HARMONIE_HomeMedic_Options or {}
local O = HARMONIE_HomeMedic_Options
local A = HARMONIE_HomeMedic_DeliriumAudio
local V = HARMONIE_HomeMedic_BloodVision

local function hook(opt, fn)
    opt.onChange = function(_, value) fn(value) end
    opt.onChangeApply = function(_, value) fn(value) end
end

if PZAPI and PZAPI.ModOptions and not O.page then
    local T = function(k) return getText("UI_options_HARMONIE_HomeMedic_" .. k) end
    O.page = PZAPI.ModOptions:create("HARMONIE_HomeMedic", T("title"))
    O.deliriumVolume = O.page:addSlider("deliriumVolume", T("deliriumVolume"), 0, 1.5, 0.25, 1, T("deliriumVolume_tooltip"))
    hook(O.deliriumVolume, A.setVolume)
    O.deliriumMuted = O.page:addTickBox("deliriumMuted", T("deliriumMute"), false, T("deliriumMute_tooltip"))
    hook(O.deliriumMuted, A.setMuted)
    O.bloodVision = O.page:addTickBox("bloodVision", T("bloodVision"), true, T("bloodVision_tooltip"))
    hook(O.bloodVision, function(v) V.enabled = v == true end)
    O.bloodVisionStrength = O.page:addSlider("bloodVisionStrength", T("bloodVisionStrength"), 0.25, 1.5, 0.25, 1, T("bloodVisionStrength_tooltip"))
    hook(O.bloodVisionStrength, function(v) V.strength = tonumber(v) or 1 end)
    if PZAPI.ModOptions.load then PZAPI.ModOptions:load() end
end

function O.readSaved()
    local function val(opt) return opt and opt.getValue and opt:getValue() end
    if O.deliriumVolume then A.volume = tonumber(val(O.deliriumVolume)) or 1 end
    if O.deliriumMuted then A.muted = val(O.deliriumMuted) == true end
    A.apply()
    if O.bloodVision then V.enabled = val(O.bloodVision) ~= false end
    if O.bloodVisionStrength then V.strength = tonumber(val(O.bloodVisionStrength)) or 1 end
end
O.readSaved()
if Events and Events.OnGameStart then Events.OnGameStart.Add(O.readSaved) end

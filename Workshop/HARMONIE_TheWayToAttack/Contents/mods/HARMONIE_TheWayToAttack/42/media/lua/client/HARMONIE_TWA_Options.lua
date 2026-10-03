--============================================================================
-- HARMONIE_TheWayToAttack -- per-player options (Options > Mods)
--
-- Round 13/14: this mod's sound volume and a mute switch, per player.
-- The volume picks which pre-made loudness file plays (TWASound.play; the
-- game's own per-sound user volume did not change our UI sounds -- round
-- 14 bug report "เสียงตอนนี้เหมือนมีแค่เปิดกับปิด"). The craft window's
-- megaphone button flips the same mute switch.
--============================================================================

require "HARMONIE_TWA_Sound"

TWAOptions = TWAOptions or {}
local O = TWAOptions

function O.applyVolume(v)
    TWASound.volume = tonumber(v) or 1
end

function O.setMuted(on)
    TWASound.muted = on and true or false
    if O.mute and O.mute.setValue then O.mute:setValue(TWASound.muted) end
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then PZAPI.ModOptions:save() end
end

function O.toggleMute()
    O.setMuted(not TWASound.muted)
end

if PZAPI and PZAPI.ModOptions and not O.options then
    O.options = PZAPI.ModOptions:create("HARMONIE_TheWayToAttack", getText("UI_options_HARMONIE_TWA_title"))
    O.volume = O.options:addSlider("soundVolume", getText("UI_options_HARMONIE_TWA_volume"), 0, 2, 0.25, 1,
        getText("UI_options_HARMONIE_TWA_volume_tooltip"))
    O.volume.onChange = function(_, value) O.applyVolume(value) end
    O.volume.onChangeApply = function(_, value) O.applyVolume(value) end
    O.mute = O.options:addTickBox("soundMuted", getText("UI_options_HARMONIE_TWA_mute"), false,
        getText("UI_options_HARMONIE_TWA_mute_tooltip"))
    O.mute.onChange = function(_, value) TWASound.muted = value and true or false end
    O.mute.onChangeApply = function(_, value) TWASound.muted = value and true or false end
    -- 2026-10-03: zombie health bars / HP numbers / damage numbers
    -- (HARMONIE_TWA_ZombieHP reads these tick boxes itself)
    O.zhpBar = O.options:addTickBox("zhpBar", getText("UI_options_HARMONIE_TWA_zhpBar"), true,
        getText("UI_options_HARMONIE_TWA_zhpBar_tooltip"))
    O.zhpText = O.options:addTickBox("zhpText", getText("UI_options_HARMONIE_TWA_zhpText"), true,
        getText("UI_options_HARMONIE_TWA_zhpText_tooltip"))
    O.zhpDamage = O.options:addTickBox("zhpDamage", getText("UI_options_HARMONIE_TWA_zhpDamage"), true,
        getText("UI_options_HARMONIE_TWA_zhpDamage_tooltip"))
    O.zhpHeight = O.options:addSlider("zhpHeight", getText("UI_options_HARMONIE_TWA_zhpHeight"), 0, 10, 1, 0,
        getText("UI_options_HARMONIE_TWA_zhpHeight_tooltip"))
    if PZAPI.ModOptions.load then PZAPI.ModOptions:load() end
    local function readSaved()
        if O.volume.getValue then O.applyVolume(O.volume:getValue()) end
        if O.mute.getValue then TWASound.muted = O.mute:getValue() == true end
    end
    readSaved()
    if Events and Events.OnGameStart then Events.OnGameStart.Add(readSaved) end
end

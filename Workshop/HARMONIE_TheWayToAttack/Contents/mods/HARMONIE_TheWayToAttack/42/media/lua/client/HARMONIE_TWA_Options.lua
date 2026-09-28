--============================================================================
-- HARMONIE_TheWayToAttack -- per-player options (Options > Mods)
--
-- Round 13 (request 2026-09-28: "สามารถปรับเสียงม็อดได้ใน client"): a volume
-- slider for this mod's own sounds, per player, applied live. Same mechanism
-- as HARMONIE_LifestyleAudioTune's slider (PZAPI.ModOptions +
-- GameSound:setUserVolume + GameSounds.saveINI), applied to our TWA_*
-- sounds only -- every name in TWASound.LENGTH. At 0 the sounds are not
-- played at all (TWASound.play checks TWASound.volume).
--============================================================================

require "HARMONIE_TWA_Sound"

TWAOptions = TWAOptions or {}
local O = TWAOptions

local function eachOurSound(fn)
    if not GameSounds then return end
    local byName = {}
    for name in pairs(TWASound.LENGTH or {}) do byName[name] = true end
    if GameSounds.getSound then
        for name in pairs(byName) do
            local snd = GameSounds.getSound(name)
            if snd then fn(snd) end
        end
        return
    end
    -- No direct lookup: go through the UI category and pick ours by name.
    local list = GameSounds.getSoundsInCategory and GameSounds.getSoundsInCategory("UI")
    if not list then return end
    for i = 0, list:size() - 1 do
        local snd = list:get(i)
        local name = snd and snd.getName and snd:getName()
        if name and byName[name] then fn(snd) end
    end
end

function O.applyVolume(v)
    v = tonumber(v) or 1
    TWASound.volume = v
    eachOurSound(function(snd) if snd.setUserVolume then snd:setUserVolume(v) end end)
    if GameSounds and GameSounds.saveINI then GameSounds.saveINI() end
end

if PZAPI and PZAPI.ModOptions and not O.options then
    O.options = PZAPI.ModOptions:create("HARMONIE_TheWayToAttack", getText("UI_options_HARMONIE_TWA_title"))
    O.volume = O.options:addSlider("soundVolume", getText("UI_options_HARMONIE_TWA_volume"), 0, 2, 0.05, 1,
        getText("UI_options_HARMONIE_TWA_volume_tooltip"))
    O.volume.onChange = function(_, value) O.applyVolume(value) end
    O.volume.onChangeApply = function(_, value) O.applyVolume(value) end
    if PZAPI.ModOptions.load then PZAPI.ModOptions:load() end
    if Events and Events.OnGameStart then
        Events.OnGameStart.Add(function()
            if O.volume and O.volume.getValue then O.applyVolume(O.volume:getValue()) end
        end)
    end
end

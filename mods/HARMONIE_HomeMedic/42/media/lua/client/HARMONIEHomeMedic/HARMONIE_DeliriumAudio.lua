--[[
    HARMONIE - Home Medic : delirium sound volume, per player (client only)

    Request 2026-09-30 ("ทำให้สามารถปรับเสียงฝั่ง client ที่เกิดมาจากการเป็นโรค
    delirium อันนี้สำคัญมาก"): a page under Options -> Mods with a volume
    slider and a mute switch for the delirium hallucination sounds. Saved
    per player on their own machine; other players are not affected.

    How: EHR's delirium episode (EHR_Delirium.lua, playRandomSound) picks a
    name from the table EHR.Delirium.Sounds every time it plays one and plays
    it with getSoundManager():playUISound(). This file only REPLACES that
    table -- with nothing (muted / 0) or with the loudness copies made by
    tools/gen_delirium_volumes.py (NAME_v25 .. NAME_v150; 100 = EHR's own
    file). No EHR file is changed, so merging a newer EHR keeps this working.
    The game's own per-sound user volume does not reach UI sounds (learned in
    The Way To Attack), hence the pre-made loudness files. Hallucination
    visuals, lines and impulses are unchanged.
]]--

require "ExtensiveHealth/EHR_Delirium"
require "HARMONIEHomeMedic/HARMONIE_DeliriumLevels"

HARMONIE_HomeMedic_DeliriumAudio = HARMONIE_HomeMedic_DeliriumAudio or {}
local A = HARMONIE_HomeMedic_DeliriumAudio

A.volume = A.volume or 1
A.muted = A.muted or false

-- EHR's own list, remembered once before we ever replace it.
local function originalSounds()
    if not A.original then
        local list = {}
        for i, name in ipairs((EHR and EHR.Delirium and EHR.Delirium.Sounds) or {}) do list[i] = name end
        A.original = list
    end
    return A.original
end

-- The loudness copy nearest to `volume` (1 = 100 percent); nil = silent.
function A.levelFor(volume)
    volume = tonumber(volume) or 1
    if volume <= 0.001 then return nil end
    local pct, best, bestD = volume * 100, 100, math.abs(volume * 100 - 100)
    for _, lvl in ipairs(HARMONIE_HomeMedic_DeliriumLevels or {}) do
        local d = math.abs(lvl - pct)
        if d < bestD then best, bestD = lvl, d end
    end
    return best
end

function A.apply()
    if not (EHR and EHR.Delirium) then return end
    local base = originalSounds()
    local level = (not A.muted) and A.levelFor(A.volume) or nil
    local list = {}
    if level then
        for i, name in ipairs(base) do
            list[i] = (level == 100) and name or (name .. "_v" .. level)
        end
    end
    EHR.Delirium.Sounds = list
end

function A.setVolume(v)
    A.volume = tonumber(v) or 1
    A.apply()
end

function A.setMuted(on)
    A.muted = on and true or false
    A.apply()
end

if PZAPI and PZAPI.ModOptions and not A.options then
    A.options = PZAPI.ModOptions:create("HARMONIE_HomeMedic", getText("UI_options_HARMONIE_HomeMedic_title"))
    A.volumeOpt = A.options:addSlider("deliriumVolume", getText("UI_options_HARMONIE_HomeMedic_deliriumVolume"),
        0, 1.5, 0.25, 1, getText("UI_options_HARMONIE_HomeMedic_deliriumVolume_tooltip"))
    A.volumeOpt.onChange = function(_, value) A.setVolume(value) end
    A.volumeOpt.onChangeApply = function(_, value) A.setVolume(value) end
    A.muteOpt = A.options:addTickBox("deliriumMuted", getText("UI_options_HARMONIE_HomeMedic_deliriumMute"), false,
        getText("UI_options_HARMONIE_HomeMedic_deliriumMute_tooltip"))
    A.muteOpt.onChange = function(_, value) A.setMuted(value) end
    A.muteOpt.onChangeApply = function(_, value) A.setMuted(value) end
    if PZAPI.ModOptions.load then PZAPI.ModOptions:load() end
end

local function readSaved()
    if A.volumeOpt and A.volumeOpt.getValue then A.volume = tonumber(A.volumeOpt:getValue()) or 1 end
    if A.muteOpt and A.muteOpt.getValue then A.muted = A.muteOpt:getValue() == true end
    A.apply()
end
readSaved()
if Events and Events.OnGameStart then Events.OnGameStart.Add(readSaved) end

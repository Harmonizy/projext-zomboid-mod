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
    if not (EHR and EHR.Delirium) then HMLogOnce("nodelirium", "Delirium", "EHR.Delirium missing -- delirium sound volume not applied"); return end
    local base = originalSounds()
    local level = (not A.muted) and A.levelFor(A.volume) or nil
    local list = {}
    if level then
        for i, name in ipairs(base) do
            list[i] = (level == 100) and name or (name .. "_v" .. level)
        end
    end
    EHR.Delirium.Sounds = list
    if A.lastLogged ~= tostring(level) then
        A.lastLogged = tostring(level)
        HMLog("Delirium", "delirium sounds: %s (%d files)", level and (tostring(level) .. "%") or "muted", #list)
    end
end

function A.setVolume(v)
    A.volume = tonumber(v) or 1
    A.apply()
end

function A.setMuted(on)
    A.muted = on and true or false
    A.apply()
end

-- The Options -> Mods page (volume slider, mute) is HARMONIE_ModOptions.lua;
-- it calls A.setVolume / A.setMuted.
A.apply()

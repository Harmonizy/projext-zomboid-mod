--[[
    Live volume hook for Lifestyle: Hobbies' instrument-note and
    instrument-training sounds only.

    These play via plain character:getEmitter():playSound(name) with no
    volume override, so they'd otherwise just use the halved value baked
    into this mod's static sound-script override. This wraps Lifestyle's
    own methods (call-through, not a reimplementation) to also apply
    HARMONIE_LifestyleAudioTune_LiveMultiplier (set live by
    HARMONIE_LifestyleAudioTune_ModOptions.lua's slider) via
    emitter:setVolume(handle, ...) every time a note/song starts -- the
    same mechanism Lifestyle's own native "Jukebox Volume" right-click
    menu already uses (confirmed by reading JukeboxContextMenu.lua).

    Instruments specifically need this per-call hook rather than the
    simpler GameSounds.getSoundsInCategory("...") approach
    HARMONIE_LifestyleAudioTune_ModOptions.lua uses for DJ/Oldies/SFX,
    because instrument sound scripts share the vanilla "Item" category
    (1521 other vanilla sounds also use it) -- scaling that category
    globally would affect the whole game, not just Lifestyle.

    Scope: PlayInstrumentActionNew, PlayInstrumentTraining,
    PlayInstrumentVocal. Each hook only reads instance fields
    (self.gameSound, self.soundFile/self.lastSound) that Lifestyle's own
    code already sets on itself -- confirmed by reading each file
    directly, not guessed. Wrapped from Events.OnGameStart so Lifestyle's
    real classes are guaranteed to already be defined, regardless of
    which mod's Lua files execute first.
]]--

-- console.txt: "[HARMONIE_LAT][Hooks][SP|client|server]" lines
local function log(fmt, ...)
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    local side = (isServer and isServer()) and "server" or ((isClient and isClient()) and "client" or "SP")
    print("[HARMONIE_LAT][Hooks][" .. side .. "] " .. (ok and msg or tostring(fmt)))
end
local logSeen = {}
local function logOnce(key, fmt, ...)
    if logSeen[key] then return end
    logSeen[key] = true
    log(fmt, ...)
end

local function wrapInstrumentUpdate(className)
    local class = _G[className]
    if not class or not class.update then
        log("%s:update not found -- is Lifestyle: Hobbies installed and enabled? (not hooked)", className)
        return
    end

    local original_update = class.update
    log("hooked %s:update", className)
    class.update = function(self, ...)
        original_update(self, ...)
        if self.gameSound and self.gameSound ~= 0 and self.soundFile then
            local vol = HARMONIE_LifestyleAudioTune_ScaledVolume(self.soundFile, nil)
            if vol then self.character:getEmitter():setVolume(self.gameSound, vol); end
        end
    end
end

local function wrapInstrumentTrainingPlaySong()
    if not PlayInstrumentTraining or not PlayInstrumentTraining.playSong then
        log("PlayInstrumentTraining:playSong not found -- is Lifestyle: Hobbies installed and enabled? (not hooked)")
        return
    end

    local original_playSong = PlayInstrumentTraining.playSong
    PlayInstrumentTraining.playSong = function(self, ...)
        original_playSong(self, ...)
        log("training song started: %s", tostring(self.lastSound))
        if self.gameSound and self.gameSound ~= 0 and self.lastSound then
            local vol = HARMONIE_LifestyleAudioTune_ScaledVolume(self.lastSound, nil)
            if vol then self.character:getEmitter():setVolume(self.gameSound, vol); end
        end
    end
end

local function HARMONIE_LifestyleAudioTune_InstallHooks()
    wrapInstrumentUpdate("PlayInstrumentActionNew")
    wrapInstrumentUpdate("PlayInstrumentVocal")
    wrapInstrumentTrainingPlaySong()
    log("instrument live volume hooks done (live multiplier %.2f)", tonumber(HARMONIE_LifestyleAudioTune_LiveMultiplier) or -1)
end

Events.OnGameStart.Add(HARMONIE_LifestyleAudioTune_InstallHooks)

--[[
    Lifestyle: Hobbies plays its DJ Booth song, instrument-training song and
    instrument-playing notes via plain character:getEmitter():playSound(name)
    calls with no volume override, so they normally just use the volume baked
    into the sound script (already halved by HARMONIE's static sound-script
    override in this same mod). This file adds a SECOND, LIVE layer on top:
    a sandbox-configurable multiplier (HARMONIE_LifestyleAudioTune.VolumeMultiplier)
    that is re-applied every time one of these sounds starts, via
    emitter:setVolume(handle, ...) -- confirmed to be a real, safe Lua API by
    reading Lifestyle's own JukeboxContextMenu.lua, which already uses this
    exact mechanism for its native "Jukebox Volume" right-click menu.

    Scope: PlayDJBoothAction (DJ Booth song) and the three instrument-note
    classes (PlayInstrumentActionNew, PlayInstrumentTraining, PlayInstrumentVocal).
    NOT the Jukebox song itself -- that already has its own native, working
    per-player volume menu (right-click Jukebox -> Jukebox Volume), independent
    of this mod. NOT the Disco Ball or misc equipment SFX -- those sounds are
    triggered through global functions that re-look-up their game object
    internally, with no instance field exposed to hook into safely from
    outside; they stay at the static halved-volume value only.

    Each hook wraps the ORIGINAL Lifestyle method (call-through, not a full
    reimplementation) and only reads instance fields (self.gameSound,
    self.soundFile/self.audio/self.lastSound) that Lifestyle's own code already
    sets on itself -- confirmed by reading each file directly, not guessed.
    Wrapped from Events.OnGameStart so Lifestyle's real classes are guaranteed
    to already be defined, regardless of which mod's Lua files execute first.
]]--

local function wrapInstrumentUpdate(className)
    local class = _G[className]
    if not class or not class.update then
        print("HARMONIE Lifestyle Audio Tune: "..className..":update not found -- is Lifestyle: Hobbies installed and enabled?")
        return
    end

    local original_update = class.update
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
        print("HARMONIE Lifestyle Audio Tune: PlayInstrumentTraining:playSong not found -- is Lifestyle: Hobbies installed and enabled?")
        return
    end

    local original_playSong = PlayInstrumentTraining.playSong
    PlayInstrumentTraining.playSong = function(self, ...)
        original_playSong(self, ...)
        if self.gameSound and self.gameSound ~= 0 and self.lastSound then
            local vol = HARMONIE_LifestyleAudioTune_ScaledVolume(self.lastSound, nil)
            if vol then self.character:getEmitter():setVolume(self.gameSound, vol); end
        end
    end
end

local function wrapDJBoothUpdate()
    if not PlayDJBoothAction or not PlayDJBoothAction.update then
        print("HARMONIE Lifestyle Audio Tune: PlayDJBoothAction:update not found -- is Lifestyle: Hobbies installed and enabled?")
        return
    end

    local original_update = PlayDJBoothAction.update
    PlayDJBoothAction.update = function(self, ...)
        original_update(self, ...)
        if self.gameSound and self.gameSound ~= 0 and self.audio then
            local vol = HARMONIE_LifestyleAudioTune_ScaledVolume(self.audio, nil)
            if vol then self.character:getEmitter():setVolume(self.gameSound, vol); end
        end
    end
end

local function HARMONIE_LifestyleAudioTune_InstallHooks()
    wrapInstrumentUpdate("PlayInstrumentActionNew")
    wrapInstrumentUpdate("PlayInstrumentVocal")
    wrapInstrumentTrainingPlaySong()
    wrapDJBoothUpdate()
    print("HARMONIE Lifestyle Audio Tune: live volume hooks installed.")
end

Events.OnGameStart.Add(HARMONIE_LifestyleAudioTune_InstallHooks)

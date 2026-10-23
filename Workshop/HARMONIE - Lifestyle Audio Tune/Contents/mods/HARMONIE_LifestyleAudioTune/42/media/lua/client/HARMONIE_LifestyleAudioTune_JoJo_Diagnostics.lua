--[[
    TEMPORARY diagnostic logging for the JoJo silent-track investigation.
    Delete this whole file once the mystery is solved -- it's not meant to
    ship, just to print() enough of PlayInstrumentActionNew's own state at
    each lifecycle stage (start/update/stop/perform) that a native Lifestyle
    song and a JoJo song can be compared side by side in the DebugLog.

    Every print is prefixed "HARMONIE JOJO DIAG:" so it's easy to grep out.
    Fires for EVERY instrument play (native songs included on purpose --
    that's the baseline to diff against).

    Wrapped the same call-through way as HARMONIE_LifestyleAudioTune_Hooks.lua
    (call original first, then inspect the resulting self.* fields) --
    doesn't change any behavior, only observes it.
]]--

local function safe(v)
    if v == nil then return "nil" end
    return tostring(v)
end

local function wrapStart()
    if not PlayInstrumentActionNew or not PlayInstrumentActionNew.start then
        print("HARMONIE JOJO DIAG: PlayInstrumentActionNew:start not found.")
        return
    end
    local original_start = PlayInstrumentActionNew.start
    PlayInstrumentActionNew.start = function(self, ...)
        local hasHandItem = self.character and self.character:getPrimaryHandItem() ~= nil
        print("HARMONIE JOJO DIAG: START soundFile=" .. safe(self.soundFile)
            .. " instrumentType=" .. safe(self.instrumentType)
            .. " length=" .. safe(self.length)
            .. " trackLevel=" .. safe(self.trackLevel)
            .. " isTraining=" .. safe(self.isTraining)
            .. " isDuet=" .. safe(self.isDuet)
            .. " hasPrimaryHandItem=" .. safe(hasHandItem)
            .. " instrumentRef=" .. safe(self.instrument))
        original_start(self, ...)
    end
end

local function wrapUpdate()
    if not PlayInstrumentActionNew or not PlayInstrumentActionNew.update then
        print("HARMONIE JOJO DIAG: PlayInstrumentActionNew:update not found.")
        return
    end
    local original_update = PlayInstrumentActionNew.update
    PlayInstrumentActionNew.update = function(self, ...)
        local hadGameSoundBefore = self.gameSound and self.gameSound ~= 0

        -- log the exact forceStop condition set, once, right before Lifestyle's own
        -- code evaluates it (mirrors PlayInstrumentActionNew.lua line 249 exactly)
        if not self.HARMONIE_diag_checkedForceStop then
            local hasHandItem = self.character and self.character:getPrimaryHandItem() ~= nil
            print("HARMONIE JOJO DIAG: PRE-UPDATE-CHECK soundFile=" .. safe(self.soundFile)
                .. " isFailState=" .. safe(self.isFailState)
                .. " instrumentRef=" .. safe(self.instrument)
                .. " isSneaking=" .. safe(self.character and self.character:isSneaking())
                .. " hasPrimaryHandItem=" .. safe(hasHandItem)
                .. " instrumentType=" .. safe(self.instrumentType))
            self.HARMONIE_diag_checkedForceStop = true
        end

        original_update(self, ...)

        if (not hadGameSoundBefore) and self.gameSound and self.gameSound ~= 0 then
            local isPlayingNow = self.character:getEmitter():isPlaying(self.gameSound)
            print("HARMONIE JOJO DIAG: GAMESOUND-SET soundFile=" .. safe(self.soundFile)
                .. " gameSoundHandle=" .. safe(self.gameSound)
                .. " isPlayingImmediatelyAfter=" .. safe(isPlayingNow))
        end

        if self.isFailState and not self.HARMONIE_diag_loggedFail then
            print("HARMONIE JOJO DIAG: FAILSTATE-TRUE soundFile=" .. safe(self.soundFile))
            self.HARMONIE_diag_loggedFail = true
        end
    end
end

local function wrapStop()
    if not PlayInstrumentActionNew or not PlayInstrumentActionNew.stop then
        print("HARMONIE JOJO DIAG: PlayInstrumentActionNew:stop not found.")
        return
    end
    local original_stop = PlayInstrumentActionNew.stop
    PlayInstrumentActionNew.stop = function(self, ...)
        local wasPlaying = self.gameSound and self.gameSound ~= 0 and self.character:getEmitter():isPlaying(self.gameSound)
        print("HARMONIE JOJO DIAG: STOP soundFile=" .. safe(self.soundFile)
            .. " gameSoundHandle=" .. safe(self.gameSound)
            .. " wasPlayingAtStop=" .. safe(wasPlaying)
            .. " isFailState=" .. safe(self.isFailState)
            .. " playSoundFlag=" .. safe(self.playSound))
        original_stop(self, ...)
    end
end

local function wrapPerform()
    if not PlayInstrumentActionNew or not PlayInstrumentActionNew.perform then
        print("HARMONIE JOJO DIAG: PlayInstrumentActionNew:perform not found.")
        return
    end
    local original_perform = PlayInstrumentActionNew.perform
    PlayInstrumentActionNew.perform = function(self, ...)
        print("HARMONIE JOJO DIAG: PERFORM (natural completion) soundFile=" .. safe(self.soundFile)
            .. " gameSoundHandle=" .. safe(self.gameSound))
        original_perform(self, ...)
    end
end

local function HARMONIE_JoJo_InstallDiagnostics()
    wrapStart()
    wrapUpdate()
    wrapStop()
    wrapPerform()
    print("HARMONIE JOJO DIAG: diagnostic hooks installed.")
end

Events.OnGameStart.Add(HARMONIE_JoJo_InstallDiagnostics)

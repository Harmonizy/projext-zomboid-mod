--============================================================================
-- HARMONIE_TheWayToAttack -- perform-procedure timed action (shared)
--
-- Queued by the crafting UI once the procedure's minigame has been played
-- (HARMONIE_TWA_Minigame.lua) -- the minigame's result word arrives here as
-- the `quality` constructor argument (request 2026-09-28): Excellent/Good/
-- Bad mark the procedure done with that word; Miss records the word but
-- leaves the procedure NOT done so it can be performed again. Materials are
-- used up either way, Miss included (same request); XP is only given for a
-- procedure that actually got done.
--
-- MULTIPLAYER (request 2026-09-28, "แก้บัค Multiplayer"): this file moved
-- from client/ to shared/TimedActions/ so the server has the class too, and
-- every world change (materials, XP, a bookmarked item's ModData) now
-- happens in complete() -- which B42 runs on the server in multiplayer and
-- locally in single player -- instead of in perform(), which only ever ran
-- on the client and is why materials/progress could silently not stick on
-- a server. Multiplayer rebuilds the action on the server by calling new()
-- with the fields named like new()'s own parameters (the pattern
-- Casualties Undead documents in its CUMedicalAction.lua), so every
-- parameter is stored under exactly its own name and is a plain string or
-- a real game object -- never a Lua table or a function. The UI's own
-- callbacks (onComplete/onEnd) are attached AFTER construction, client-side
-- only, and are simply absent on the server copy.
--============================================================================

require "TimedActions/ISBaseTimedAction"
require "HARMONIE_TWA_Procedures"
require "HARMONIE_TWA_Config"
require "HARMONIE_TWA_Sound"
require "HARMONIE_TWA_CraftState"

TWA_PerformProcedureAction = ISBaseTimedAction:derive("TWA_PerformProcedureAction")

function TWA_PerformProcedureAction:isValid()
    if not self.character or not self.proc then return false end
    -- Round 25 (server load): isValid runs every tick while the bar fills,
    -- and the eligibility check walks the bags and the containers nearby.
    -- Re-check at most every 0.5 s; the last answer holds in between.
    local now = getTimestampMs and getTimestampMs() or 0
    if self.validAt and now - self.validAt < 500 then return self.validOk end
    self.validAt = now
    self.validOk = self:checkValid()
    return self.validOk
end

function TWA_PerformProcedureAction:checkValid()
    -- The server only re-checks what it owns (tools/materials/skill); light
    -- and a nearby forge were checked client-side before queueing, and the
    -- client keeps re-checking them every tick below.
    if isServer() then
        return TWAProcedures.CheckEligibility(self.proc, self.character, true)
    end
    if TWAConfig.on("RequireLight") and self.character:tooDarkToRead() then return false end
    -- Round 29: a multiplayer client stops re-checking tools/materials once
    -- the bar runs -- the server owns (and re-checks) them, and its
    -- complete() may consume them before this client's last tick.
    if isClient() and self.twaStarted then return true end
    return TWAProcedures.CheckEligibility(self.proc, self.character)
end

function TWA_PerformProcedureAction:update()
    self.character:setMetabolicTarget(Metabolics.UsingTools)
    -- Round 12: the working sound, replayed while the bar runs (client only).
    if self.proc.sound and not isServer() then TWASound.keepPlaying(self, self.proc.sound, "ActionSounds") end
end

function TWA_PerformProcedureAction:start()
    self.twaStarted = true
    self:setActionAnim(CharacterActionAnims.Craft)
    if self.proc.sound and not isServer() then TWASound.keepPlaying(self, self.proc.sound, "ActionSounds") end
end

function TWA_PerformProcedureAction:stopSound()
    if self.actionSound and self.actionSound ~= 0 then
        self.character:stopOrTriggerSound(self.actionSound)
    end
    self.actionSound = nil
end

-- 2026-10-02: an action taken off the queue before it ever started (the
-- one ahead of it was cancelled, the player moved...) gets forceCancel(),
-- not stop() -- free the crafting window's one-at-a-time lock here too, or
-- the window stays "running" with no action behind it.
function TWA_PerformProcedureAction:forceCancel()
    if self.onEnd then self.onEnd() end
end

function TWA_PerformProcedureAction:stop()
    self:stopSound()
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.stop(self)
end

-- Client side, after a natural finish: the crafting window's own session
-- bookkeeping only. Nothing in the world changes here any more.
function TWA_PerformProcedureAction:perform()
    self:stopSound()
    TWACraftState.markTried(self.character, self.procId) -- round 18: unlocks Practice
    if self.onComplete then self.onComplete(self.quality) end
    if self.onEnd then self.onEnd() end
    ISBaseTimedAction.perform(self)
end

-- Server in multiplayer, local in single player.
function TWA_PerformProcedureAction:complete()
    -- Round 25: isValid is throttled -- make sure the tools and materials
    -- are still there at the moment they are used.
    if not self:checkValid() then return false end
    if self.quality ~= "Miss" or TWAConfig.on("MissUsesMaterials") then
        TWAProcedures.Consume(self.proc, self.character)
    end
    if self.quality ~= "Miss" then
        TWAProcedures.AwardXP(self.proc, self.character)
    end
    -- The word goes into the character's active craft (request 2026-09-28:
    -- one craft at a time, started with TWA_StartCraftAction), held here
    -- where the authoritative record lives. A redo simply replaces the
    -- procedure's earlier word.
    TWACraftState.recordActive(self.character, self.procId, self.quality)
    TWACraftState.markTried(self.character, self.procId)
    return true
end

function TWA_PerformProcedureAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return self.maxTime
end

-- `procId` -- a TWAProcedures.List key; `quality` -- the minigame's word.
function TWA_PerformProcedureAction:new(character, procId, quality)
    local o = ISBaseTimedAction.new(self, character)
    o.procId = procId
    o.quality = TWACraftState.isWord(quality) and quality or TWACraftState.FALLBACK_WORD
    o.proc = TWAProcedures.List[procId]
    -- Round 13 ("Action time ทุกอย่างเป็น 3 วินาที"): every procedure takes the
    -- sandbox "ProcedureSeconds" (default 3 s); proc.time is no longer used.
    o.maxTime = TWAConfig.secondsToTicks(TWAConfig.num("ProcedureSeconds", 0.1))
    o.forceProgressBar = true
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

if TWALogAction then TWALogAction(TWA_PerformProcedureAction, "PerformProcedure") end

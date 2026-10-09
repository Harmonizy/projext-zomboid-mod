require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISReloadWeaponAction"
require "MFSUnderbarrelRegistry"

-- Shared class definition: B42 multiplayer resolves a networked timed action's
-- <Class>.new function on the server. Keep cosmetic queue/event registration in
-- client/MFSM203CycleAction.lua, but keep this class available to both peers.
-- The historical public class name is retained for compatibility and remains
-- generic for every pseudo registered in MFSUnderbarrelRegistry.

-- Cosmetic underbarrel breech/case cycle. Vanilla RackAfterShoot is deliberately not
-- used: on a chamberless one-round weapon ISRackFirearm can return the fired
-- live grenade to inventory. Vanilla still owns and synchronizes ammunition;
-- this action only supplies the required post-shot handling time and motion.

MFSM203CycleAction = ISBaseTimedAction:derive("MFSM203CycleAction")

local CYCLE_WATCHDOG_MS = 4000
local CYCLE_DEBUG = false -- RC2 accepted; retain the probe for opt-in diagnosis only.

local function cycleLog(action, stage)
    if not CYCLE_DEBUG then return end
    local gun = action and action.gun or nil
    print("[MFSUnderbarrelCycleProbe] stage=" .. tostring(stage)
        .. " clockMs=" .. tostring(getTimestampMs())
        .. " player=" .. tostring(action and action.character
            and action.character:getUsername() or "nil")
        .. " weapon=" .. tostring(gun and gun:getFullType() or "nil")
        .. " itemId=" .. tostring(gun and gun:getID() or "nil")
        .. " ammo=" .. tostring(gun and gun:getCurrentAmmoCount() or "nil"))
end

function MFSM203CycleAction:isValid()
    local valid = self.gun
        and MFSUnderbarrelRegistry.getForPseudo(self.gun) == self.definition
        and self.character:getInventory():contains(self.gun)
        and self.character:getPrimaryHandItem() == self.gun
    if not valid and self.gun then
        self.gun:getModData().MFSUnderbarrelCycleQueued = nil
    end
    return valid
end

function MFSM203CycleAction:start()
    self._mfsCycleStartedAt = getTimestampMs()
    self._mfsRackingFinished = false
    cycleLog(self, "START")
    self.gun:getModData().MFSUnderbarrelCycleQueued = true
    self:setAnimVariable("WeaponReloadType", "boltactionnomag")
    self:setAnimVariable("isRacking", true)
    self:setAnimVariable("RackAiming", false)
    self:setOverrideHandModels(self.gun, nil)
    self:setActionAnim(CharacterActionAnims.Reload)
    ISReloadWeaponAction.setReloadSpeed(self.character, true)
    self.character:reportEvent("EventReloading")
    self.character:getEmitter():playSound(self.definition.cycleSound)
end

function MFSM203CycleAction:update()
    local elapsedMs = self._mfsCycleStartedAt
        and (getTimestampMs() - self._mfsCycleStartedAt) or 0
    local normalFallbackMs = tonumber(self.definition.cycleFallbackMs) or 2615

    -- B42 firearm actions are animation-event driven, so the old positive
    -- maxTime=75 never completed this custom action. If the animation omits its
    -- event, finish by the measured 2.615-second insertion-sound ceiling so the
    -- cosmetic cycle cannot hold the real reload behind it.
    if not self._mfsNormalCompleteRequested and elapsedMs >= normalFallbackMs then
        self._mfsNormalCompleteRequested = true
        cycleLog(self, "NORMAL_COMPLETE_TIME_FALLBACK")
        self:forceComplete()
        return
    end

    -- This action is cosmetic only. Never let an unexpected failure of the
    -- normal completion path hold the queue and block vanilla reload behind it.
    if not self._mfsWatchdogForced and self._mfsCycleStartedAt
        and elapsedMs >= CYCLE_WATCHDOG_MS then
        self._mfsWatchdogForced = true
        cycleLog(self, "WATCHDOG_FORCE_COMPLETE")
        self:forceComplete()
    end
end

function MFSM203CycleAction:animEvent(event, parameter)
    if event ~= "rackingFinished" then return end

    self._mfsRackingFinished = true
    cycleLog(self, "ANIM_EVENT_RACKING_FINISHED")

    -- This is the vanilla B42 completion contract. The 2.615-second value in
    -- update() is only a missing-event fallback, not a minimum extra delay.
    if not self._mfsNormalCompleteRequested then
        self._mfsNormalCompleteRequested = true
        cycleLog(self, "NORMAL_COMPLETE_ANIM_EVENT")
        self:forceComplete()
    end
end

function MFSM203CycleAction:clearState()
    if self.gun then
        self.gun:getModData().MFSUnderbarrelCycleQueued = nil
    end
    self.character:clearVariable("isLoading")
    self.character:clearVariable("isRacking")
    self.character:clearVariable("isUnloading")
    self.character:clearVariable("WeaponReloadType")
    self.character:clearVariable("RackAiming")
end

function MFSM203CycleAction:stop()
    cycleLog(self, "STOP")
    self:clearState()
    ISBaseTimedAction.stop(self)
end

function MFSM203CycleAction:perform()
    cycleLog(self, "PERFORM")
    self:clearState()
    ISBaseTimedAction.perform(self)
end

function MFSM203CycleAction:complete()
    return true
end

function MFSM203CycleAction:getDuration()
    -- B42 reload/rack actions are completed by animation events. Our update
    -- method supplies the sound-aligned normal completion and watchdog.
    return -1
end

function MFSM203CycleAction:new(character, gun, definition)
    local action = ISBaseTimedAction.new(self, character)
    action.gun = gun
    action.definition = definition or MFSUnderbarrelRegistry.getForPseudo(gun)
    action.stopOnWalk = false
    action.stopOnRun = true
    action.stopOnAim = false
    action.useProgressBar = false
    action.maxTime = action:getDuration()
    return action
end

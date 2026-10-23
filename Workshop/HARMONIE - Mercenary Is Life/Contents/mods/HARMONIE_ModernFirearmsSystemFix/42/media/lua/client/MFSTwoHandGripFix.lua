-- MFS Patch 5 - TWO-HANDED GRIP FIX  (issues 1 / 2 / 6)
--
-- THE BUG, AS PROVEN BY THE BUILD 2 MULTIPLAYER LOG
--   Attaching a part through the MFS inspection GUI left the rifle in the
--   PRIMARY hand with the OFF-HAND EMPTY. A weapon declared TwoHandWeapon is
--   held by putting the SAME item in BOTH hands, so an empty off-hand renders
--   in the wrong pose - which is exactly what players reported.
--
--   Reproduced twice in one session, different weapons and parts:
--
--     f:83785  HANDS-CHANGED  parts gained Grip   sec=M4A1S_cat   act=2
--     f:83785  ISUpgradeWeapon:isValid REJECTED   part=Grip/ASh-12_Grip
--     f:83790  HANDS-CHANGED                      sec=nil         act=0
--
--   THE CHAIN
--     1. risky_inspect_button.lua:438-443 queues TWO actions on a part click:
--            ISUpgradeWeapon        (do the attach)
--            ISEquipWeaponAction    (re-equip, twoHands = isTwoHandWeapon())
--        The SECOND one is what restores the two-handed grip.
--     2. In multiplayer the part is already attached by the time the queue is
--        validated, so ISUpgradeWeapon:isValid() hits its first statement,
--            if self.weapon:getWeaponPart(self.part:getPartType()) then return false end
--        and rejects itself as redundant.
--     3. The queue is then discarded WHOLESALE - act goes 2 -> 0 and
--        ISEquipWeaponAction never starts. It is collateral damage.
--     4. Nothing refills the off-hand. Wrong pose until the player re-equips.
--
--   CONTROL, from the same log: every time ISEquipWeaponAction DID run
--   (#10->#12, #14->#16, #25->#27) the off-hand came back correctly. Runs =
--   right grip, discarded = sec=nil.
--
--   SINGLE PLAYER never reproduced it because there ISUpgradeWeapon:perform is
--   what attaches the part, so isValid still passes and the equip survives.
--
-- WHAT THIS FILE DOES - one primitive, two triggers
--   SAFETY NET: a watchdog restores the grip whenever a two-handed weapon is
--              left with an EMPTY off-hand and no action queued. This is what
--              actually does the work - the verification log shows all three
--              restores coming from here.
--   ARMING   : a redundant ISUpgradeWeapon rejection ARMS the watchdog, which
--              then acts on the first bad frame instead of waiting for
--              STABLE_TICKS. See the v1.1 note further down for why the
--              original "restore immediately on rejection" version was wrong.
--   The restore itself is one line: player:setSecondaryHandItem(weapon).
--   No queue manipulation anywhere.
--
-- DELIBERATELY CONSERVATIVE
--   * Only ever acts when the off-hand is NIL. It will never displace an item
--     the player is actually holding.
--   * Only acts when the timed-action queue is EMPTY, so it cannot fight a
--     reload, an equip, or any action that legitimately frees a hand.
--   * Requires the bad state to persist for STABLE_TICKS, so normal one-frame
--     transitions are not touched.
--   * Local player only.

MFSTwoHandGripFix = MFSTwoHandGripFix or {}
local Fix = MFSTwoHandGripFix

Fix.VERSION = "1.1.0"
Fix.ENABLED = true
-- Set true to print one line each time the grip is restored.
Fix.DEBUG = false
-- Frames the broken state must persist before the watchdog acts, in the normal
-- case. Ignores one-frame transitions during equips and reloads.
Fix.STABLE_TICKS = 3
-- How long a redundant-attach rejection keeps the watchdog "armed". While
-- armed the watchdog acts on the FIRST bad frame instead of waiting for
-- STABLE_TICKS, because a break is already known to be coming. The measured
-- rejection-to-break gap was ~6 frames, so this only has to outlive that.
Fix.ARM_WINDOW_MS = 600
Fix.armUntil = 0

local badTicks = 0

local function safe(fn, fallback)
    local ok, v = pcall(fn)
    if ok and v ~= nil then
        return v
    end
    return fallback
end

local function queueEmpty(player)
    return safe(function()
        local q = ISTimedActionQueue.queues and ISTimedActionQueue.queues[player]
        if not q or not q.queue then
            return true
        end
        return #q.queue == 0
    end, true)
end

-- Returns the weapon when the two-handed grip is broken, otherwise nil.
function Fix.brokenGrip(player)
    if not player then
        return nil
    end
    local weapon = safe(function() return player:getPrimaryHandItem() end, nil)
    if not weapon or not instanceof(weapon, "HandWeapon") then
        return nil
    end
    if not safe(function() return weapon:isTwoHandWeapon() end, false) then
        return nil
    end
    -- ONLY when the off-hand is genuinely empty. If the player is holding
    -- something else we leave it alone - that is their business, not ours.
    if safe(function() return player:getSecondaryHandItem() end, nil) ~= nil then
        return nil
    end
    return weapon
end

function Fix.restore(player, why)
    if not Fix.ENABLED then
        return false
    end
    local weapon = Fix.brokenGrip(player)
    if not weapon then
        return false
    end
    local ok = pcall(function()
        -- Exactly what ISEquipWeaponAction with twoHands=true does: the SAME
        -- item occupies both hands.
        player:setSecondaryHandItem(weapon)
    end)
    if ok and Fix.DEBUG then
        print("[MFS] TwoHandGripFix restored two-handed grip (" .. tostring(why) .. ") on "
              .. tostring(weapon:getType()))
    end
    badTicks = 0
    return ok
end

-- ---------------------------------------------------------------------------
-- SAFETY NET
-- ---------------------------------------------------------------------------
local function watchdog(playerObj)
    if not Fix.ENABLED then
        return
    end
    local me = safe(function() return getPlayer() end, nil)
    if not me or (playerObj and playerObj ~= me) then
        return
    end
    if not Fix.brokenGrip(me) then
        badTicks = 0
        return
    end
    -- Do not interfere while anything is queued; an action may be mid-flight
    -- and about to set the hands itself.
    if not queueEmpty(me) then
        badTicks = 0
        return
    end
    badTicks = badTicks + 1
    local armed = safe(function() return getTimestampMs() end, 0) < (Fix.armUntil or 0)
    if armed then
        Fix.armUntil = 0
        Fix.restore(me, "armed-redundant-attach")
    elseif badTicks >= Fix.STABLE_TICKS then
        Fix.restore(me, "watchdog")
    end
end
Events.OnPlayerUpdate.Add(watchdog)

-- ---------------------------------------------------------------------------
-- TARGETED  (v1.1 - CORRECTED, see below)
--
--   v1.0 called Fix.restore() the instant ISUpgradeWeapon rejected itself.
--   THAT WAS WRONG AND THE VERIFICATION LOG PROVED IT. The off-hand is still
--   populated at the moment of rejection; it does not empty until about six
--   frames later:
--
--       f:8993  ISUpgradeWeapon:isValid REJECTED     sec=M4A1S_cat   <- still fine
--       f:8999  HANDS-CHANGED                        sec=nil         <- breaks here
--       f:9001  GripFix.restore watchdog             sec=M4A1S_cat   <- watchdog caught it
--
--   So v1.0's targeted layer looked, found nothing broken, set its
--   "handled" flag and never tried again. It was dead code - all three
--   restores in the verification run came from the watchdog.
--
--   v1.1 does the right thing: a rejection ARMS the watchdog rather than
--   acting immediately. While armed, the watchdog skips its STABLE_TICKS delay,
--   because we already know a break is coming and do not need to wait to be
--   sure. Latency drops from 3 frames to 1, which matters on a low-FPS client
--   where 3 frames can be a visible flicker.
-- ---------------------------------------------------------------------------
local function hookUpgradeAction()
    if not ISUpgradeWeapon or ISUpgradeWeapon.__MFSGripFixHooked then
        return
    end
    local previousIsValid = ISUpgradeWeapon.isValid
    function ISUpgradeWeapon:isValid()
        local result = previousIsValid and previousIsValid(self) or false
        if not result and not self.__MFSGripFixHandled then
            self.__MFSGripFixHandled = true
            local redundant = safe(function()
                return self.weapon and self.part
                   and self.weapon:getWeaponPart(self.part:getPartType()) ~= nil
            end, false)
            if redundant then
                -- Do NOT restore here - nothing is broken yet.
                Fix.armUntil = safe(function() return getTimestampMs() end, 0) + Fix.ARM_WINDOW_MS
            end
        end
        return result
    end
    ISUpgradeWeapon.__MFSGripFixHooked = true
end

Events.OnGameStart.Add(function()
    hookUpgradeAction()
    print("[MFS] TwoHandGripFix " .. Fix.VERSION .. " active")
end)
Events.OnCreatePlayer.Add(hookUpgradeAction)

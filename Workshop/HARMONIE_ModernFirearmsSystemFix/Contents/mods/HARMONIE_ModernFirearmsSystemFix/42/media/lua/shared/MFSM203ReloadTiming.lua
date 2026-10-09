require "TimedActions/ISReloadWeaponAction"
require "MFSUnderbarrelRegistry"

-- B42 assigns boltactionnomag a very short 590 ms MP base load event. Keep its
-- mesh-safe animation, but slow only registered underbarrel pseudo launchers.
-- The multiplier preserves skill, panic, vehicle and equipment modifiers while
-- the cap prevents high skill from collapsing the motion back to rifle speed.

MFSUnderbarrelReloadTiming = MFSUnderbarrelReloadTiming or MFSM203ReloadTiming or {}
MFSM203ReloadTiming = MFSUnderbarrelReloadTiming -- legacy public alias
local Timing = MFSUnderbarrelReloadTiming
Timing.VERSION = "1.1.3-rc5-live-reload-probe"
-- Controlled two-client MP build: lifecycle wrappers still return immediately
-- for every non-pseudo weapon, so only underbarrel reloads produce probe lines.
-- Disable again before public release.
Timing.DEBUG = false
Timing.probeSequence = Timing.probeSequence or 0

local function probeSide()
    if isServer() then return "SERVER" end
    if isClient() then return "CLIENT" end
    return "SP"
end

local function probeElapsed(action)
    if not action or not action._mfsReloadProbeStartedAt then return "n/a" end
    return tostring(getTimestampMs() - action._mfsReloadProbeStartedAt)
end

local function probeDefinition(action)
    local weapon = action and action.gun or nil
    return weapon and MFSUnderbarrelRegistry.getForPseudo(weapon) or nil
end

local function probeAction(action, stage, extra)
    if not Timing.DEBUG or not probeDefinition(action) then return end
    local character = action.character
    local weapon = action.gun
    local username = "n/a"
    if character then
        local ok, value = pcall(function() return character:getUsername() end)
        if ok and value then username = tostring(value) end
    end
    local ammo = weapon and (tostring(weapon:getCurrentAmmoCount())
        .. "/" .. tostring(weapon:getMaxAmmo())) or "n/a"
    local speed = character and character:getVariableFloat("ReloadSpeed", -1) or -1
    print("[MFSUnderbarrelReloadProbe][" .. probeSide() .. "] seq="
        .. tostring(action._mfsReloadProbeSequence or "n/a")
        .. " stage=" .. tostring(stage)
        .. " clockMs=" .. tostring(getTimestampMs())
        .. " elapsedMs=" .. probeElapsed(action)
        .. " player=" .. username
        .. " weapon=" .. tostring(weapon and weapon:getFullType() or "nil")
        .. " itemId=" .. tostring(weapon and weapon:getID() or "nil")
        .. " ammo=" .. ammo
        .. " reloadSpeed=" .. tostring(speed)
        .. (extra and (" " .. tostring(extra)) or ""))
end

local function beginProbe(action, stage)
    if not Timing.DEBUG or not probeDefinition(action) then return end
    Timing.probeSequence = Timing.probeSequence + 1
    action._mfsReloadProbeSequence = Timing.probeSequence
    action._mfsReloadProbeStartedAt = getTimestampMs()
    local character = action.character
    local perk = character and character:getPerkLevel(Perks.Reloading) or -1
    local panic = character and character:getMoodles():getMoodleLevel(MoodleType.PANIC) or -1
    probeAction(action, stage, "perk=" .. tostring(perk)
        .. " panic=" .. tostring(panic)
        .. " reloadType=" .. tostring(action.gun:getWeaponReloadType()))
end

if not Timing.originalSetReloadSpeed then
    Timing.originalSetReloadSpeed = ISReloadWeaponAction.setReloadSpeed
end

if not Timing.originalGetReloadTime then
    Timing.originalGetReloadTime = ISReloadWeaponAction.getReloadTime
end

if not Timing.originalInitVars then
    Timing.originalInitVars = ISReloadWeaponAction.initVars
end

if not Timing.originalStart then
    Timing.originalStart = ISReloadWeaponAction.start
end

if not Timing.originalServerStart then
    Timing.originalServerStart = ISReloadWeaponAction.serverStart
end

if not Timing.originalAnimEvent then
    Timing.originalAnimEvent = ISReloadWeaponAction.animEvent
end

if not Timing.originalStop then
    Timing.originalStop = ISReloadWeaponAction.stop
end

if not Timing.originalPerform then
    Timing.originalPerform = ISReloadWeaponAction.perform
end

-- Reload timing must be selected from the action's gun, not the character's
-- primary hand. In Host/MP the authoritative server action resolves the pseudo
-- by item ID while its IsoPlayer primary hand can still be the physical host.
-- The former character-only setReloadSpeed hook therefore missed the launcher
-- server-side and left ReloadSpeed at ordinary-rifle speed.
ISReloadWeaponAction.setReloadSpeed = Timing.originalSetReloadSpeed

ISReloadWeaponAction.initVars = function(self)
    Timing.originalInitVars(self)
    local weapon = self and self.gun or nil
    local definition = weapon and MFSUnderbarrelRegistry.getForPseudo(weapon) or nil
    if not definition then return end

    local character = self.character
    local vanillaSpeed = character:getVariableFloat("ReloadSpeed", 1.0)
    local launcherSpeed = math.min(vanillaSpeed * definition.reloadSpeedMultiplier,
        definition.reloadSpeedCap)
    character:setVariable("ReloadSpeed", launcherSpeed)
    if Timing.DEBUG then
        local expectedAnimationMs = definition.serverReloadBaseMs / launcherSpeed
        print("[MFSUnderbarrelReloadProbe][" .. probeSide() .. "] stage=SPEED"
            .. " clockMs=" .. tostring(getTimestampMs())
            .. " weapon=" .. tostring(weapon:getFullType())
            .. " itemId=" .. tostring(weapon:getID())
            .. " vanillaSpeed=" .. tostring(vanillaSpeed)
            .. " multiplier=" .. tostring(definition.reloadSpeedMultiplier)
            .. " cap=" .. tostring(definition.reloadSpeedCap)
            .. " launcherSpeed=" .. tostring(launcherSpeed)
            .. " expectedAnimationMs=" .. tostring(expectedAnimationMs))
    end
end

-- SP finishes LoadRifleNoMag from the animation's End event. MP cannot wait for
-- that client event and ISReloadWeaponAction:serverStart() emulates it from a
-- hardcoded 590 ms baseline instead. Bob_Reload_Shotgun_Load is actually 700 ms
-- long (3360 ticks / 4800 ticks per second), which made MP cut this animation
-- and its action roughly 16% early. Substitute the real baseline only for the
-- exact vanilla boltactionnomag server calculation on a registered pseudo gun.
-- Normal firearms, other reload phases, SP animation speed and audio are not
-- changed by this guard.
ISReloadWeaponAction.getReloadTime = function(character, baseTime)
    local activeAction = Timing.activeServerAction
    local actionWeapon = activeAction and activeAction.character == character
        and activeAction.gun or nil
    local weapon = actionWeapon or (character and character:getPrimaryHandItem() or nil)
    local definition = weapon and MFSUnderbarrelRegistry.getForPseudo(weapon) or nil
    local requestedBaseTime = baseTime
    if definition and baseTime == 590 then
        baseTime = definition.serverReloadBaseMs
    end
    local unadjustedResult = Timing.originalGetReloadTime(character, requestedBaseTime)
    local result = Timing.originalGetReloadTime(character, baseTime)
    if Timing.DEBUG and definition then
        print("[MFSUnderbarrelReloadProbe][" .. probeSide() .. "] stage=GET_RELOAD_TIME"
            .. " clockMs=" .. tostring(getTimestampMs())
            .. " weapon=" .. tostring(weapon:getFullType())
            .. " itemId=" .. tostring(weapon:getID())
            .. " requestedBaseMs=" .. tostring(requestedBaseTime)
            .. " usedBaseMs=" .. tostring(baseTime)
            .. " reloadSpeed=" .. tostring(character:getVariableFloat("ReloadSpeed", -1))
            .. " unadjustedResultMs=" .. tostring(unadjustedResult)
            .. " resultMs=" .. tostring(result))
    end
    return result
end


-- Give getReloadTime the server action context during vanilla serverStart.
-- Project Zomboid executes this synchronously on its Lua thread; no state is
-- retained after the call and no packet or polling path is introduced.
ISReloadWeaponAction.serverStart = function(self)
    local definition = probeDefinition(self)
    if definition then Timing.activeServerAction = self end
    beginProbe(self, "SERVER_START_BEGIN")
    Timing.originalServerStart(self)
    probeAction(self, "SERVER_START_END")
    if Timing.activeServerAction == self then Timing.activeServerAction = nil end
end


-- Debug-build timing probe. These wrappers only observe registered pseudo
-- launchers and call the untouched vanilla methods in their original order.
-- Do not install the lifecycle wrappers at all in a non-debug game.
if Timing.DEBUG then
    ISReloadWeaponAction.start = function(self)
        beginProbe(self, "LOCAL_START_BEGIN")
        Timing.originalStart(self)
        probeAction(self, "LOCAL_START_END")
    end

    ISReloadWeaponAction.animEvent = function(self, event, parameter)
        probeAction(self, "ANIM_EVENT_BEGIN",
            "event=" .. tostring(event) .. " parameter=" .. tostring(parameter))
        Timing.originalAnimEvent(self, event, parameter)
        probeAction(self, "ANIM_EVENT_END",
            "event=" .. tostring(event) .. " parameter=" .. tostring(parameter))
    end

    ISReloadWeaponAction.stop = function(self)
        probeAction(self, "STOP")
        Timing.originalStop(self)
    end

    ISReloadWeaponAction.perform = function(self)
        probeAction(self, "PERFORM")
        Timing.originalPerform(self)
    end
end

print("[MFSUnderbarrelReloadTiming] version " .. Timing.VERSION
    .. " loaded; debugProbe=" .. tostring(Timing.DEBUG))

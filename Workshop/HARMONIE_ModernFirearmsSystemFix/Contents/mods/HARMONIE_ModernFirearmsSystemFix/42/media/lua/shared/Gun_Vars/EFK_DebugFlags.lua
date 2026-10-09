-- COMMUNITY PATCH 2026-09-08 - shared console-logging switchboard.
--
-- Purpose
-- -------
-- Several modules print diagnostic lines to the console on ordinary player
-- actions.  They were useful while a defect was being chased and are pure noise
-- afterwards, and each one was written with its own ad-hoc guard (or none), so
-- there was no single place to turn them off before a release.
--
-- This file is that single place.  Every flag defaults to FALSE, so a normal
-- install is silent.  Turning one on is a one-line edit here, or a console call
-- at runtime.
--
-- Usage from a module
-- -------------------
--     EFK_Debug.log("inspect", "some message")     -- prints only if enabled
--
--     if EFK_Debug.isOn("inspect") then            -- for expensive messages
--         EFK_Debug.log("inspect", buildBigString())
--     end
--
-- The caller keeps its own "[Tag]" prefix; this file does not add one, so
-- existing log formats are unchanged when a flag is switched on.
--
-- Usage at runtime (debug console / another mod)
-- ----------------------------------------------
--     EFK_Debug.set("inspect", true)
--     EFK_Debug.setAll(true)
--     EFK_Debug.list()                              -- prints current state
--
-- Adding a flag
-- -------------
-- Add one line to DEFAULTS below and use its name in EFK_Debug.log().  An
-- unknown name is treated as OFF rather than erroring, so a module can call
-- EFK_Debug.log() before this file is edited without breaking anything.
--
-- Load order: this lives under media/lua/shared, which the game loads before
-- client and server, so EFK_Debug exists by the time any consumer runs.  Every
-- consumer still nil-guards the call, so removing this file degrades to silence
-- rather than to an error.

EFK_Debug = EFK_Debug or {}

-- All release defaults are false.  Do not commit a true value.
local DEFAULTS = {
    -- risky_inspect_core.lua: inspection window chatter, and the one-shot
    -- "skipped part" report for a part whose WorldStaticModel does not resolve.
    inspect = false,

    -- MFSFireStateDiagnostics.lua: per-weapon fire-state reports, rate limited
    -- by Diagnostics.LOG_COOLDOWN_MS.
    firestate = false,

    -- MFSPartStatApply.lua: one line each time the table-backed part stats are
    -- recomputed on a weapon, reporting the installed parts and the resulting
    -- live crit chance / crit damage / cyclic bonus.  Fires on equip and on
    -- attach or detach, not per shot and not per tick.
    partstat = false,
}

EFK_Debug.flags = EFK_Debug.flags or {}
for name, value in pairs(DEFAULTS) do
    if EFK_Debug.flags[name] == nil then
        EFK_Debug.flags[name] = value
    end
end

function EFK_Debug.isOn(name)
    return EFK_Debug.flags[name] == true
end

function EFK_Debug.set(name, on)
    if DEFAULTS[name] == nil then
        print("[EFK_Debug] unknown flag: " .. tostring(name))
        return false
    end
    EFK_Debug.flags[name] = (on == true)
    print("[EFK_Debug] " .. tostring(name) .. " = " .. tostring(EFK_Debug.flags[name]))
    return true
end

function EFK_Debug.setAll(on)
    for name, _ in pairs(DEFAULTS) do
        EFK_Debug.flags[name] = (on == true)
    end
    print("[EFK_Debug] all flags = " .. tostring(on == true))
end

function EFK_Debug.list()
    for name, _ in pairs(DEFAULTS) do
        print("[EFK_Debug] " .. tostring(name) .. " = " .. tostring(EFK_Debug.flags[name]))
    end
end

function EFK_Debug.log(name, message)
    if EFK_Debug.flags[name] == true then
        print(tostring(message))
    end
end

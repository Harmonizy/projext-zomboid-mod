--[[
    Standardized Vehicle Upgrades 3 (StandardizedVehicleUpgrades3Core,
    requiring tsarslib) implements its protection/armor parts (bullbars,
    window/door/trunk armor, wheel chains) with a single mechanic in
    ATATuning2.Update.Protection: whenever the part it protects would
    drop below a health threshold, the protection part "absorbs" that
    hit -- it loses a fixed amount of its own condition (healthDelta)
    and resets the protected part back to 100. That healthDelta is
    computed once, at install time, in ATATuning2.InstallComplete.Tuning
    (tsarslib/common/media/lua/server/Tuning2/ATATuning2.lua:543, fully
    re-implemented rather than wrapped by StandardizedVehicleUpgrades3Core
    in SVUC_ATATuning2.lua:60) from SVUC's own fixed, sandbox-configured
    per-tier values (protectionLightHealthDelta etc, 1-10 each, no
    overall multiplier) and stored permanently in
    part:getModData().tuning2.protectionHealthDelta -- confirmed by
    reading both files directly, not guessed.

    This mod does not touch that mechanism directly (per the same
    don't-redefine-vanilla/other-mods'-functions rule other HARMONIE
    mods follow) -- instead it wraps ATATuning2.InstallComplete.Tuning
    with a call-through and multiplies the stored protectionHealthDelta
    right after the real install logic sets it, once per genuine install
    event (confirmed by grepping every call site of InstallComplete.Tuning
    across tsarslib and both SVU3 mods -- all 3 are install/spawn-time
    completion callbacks, never a per-tick or per-load call, so this
    can't compound).

    Wrapped from Events.OnGameStart rather than at file-load time: this
    mod's own lua files could load before OR after
    StandardizedVehicleUpgrades3Core's, and there's no guarantee which
    mod's lua runs first -- but by OnGameStart every mod's lua has
    definitely already executed, so ATATuning2.InstallComplete.Tuning
    is guaranteed to already be SVU3's real, final definition before we
    wrap it.
]]--

-- console.txt: "[HARMONIE_SVU3][PartWear][SP|client|server]" lines
local function log(fmt, ...)
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    local side = (isServer and isServer()) and "server" or ((isClient and isClient()) and "client" or "SP")
    print("[HARMONIE_SVU3][PartWear][" .. side .. "] " .. (ok and msg or tostring(fmt)))
end
local logSeen = {}
local function logOnce(key, fmt, ...)
    if logSeen[key] then return end
    logSeen[key] = true
    log(fmt, ...)
end

local function getMultiplier()
    if SandboxVars.HARMONIE_SVU3PartWear and SandboxVars.HARMONIE_SVU3PartWear.ProtectionDamageMultiplier then
        return SandboxVars.HARMONIE_SVU3PartWear.ProtectionDamageMultiplier
    end
    return 1.0
end

local wrapped = false
local function wrapInstallComplete()
    if wrapped then return end
    if not (ATATuning2 and ATATuning2.InstallComplete and ATATuning2.InstallComplete.Tuning) then
        log("ATATuning2.InstallComplete.Tuning not found -- is Standardized Vehicle Upgrades 3 (Core) installed and enabled?")
        return
    end

    wrapped = true
    local original_InstallComplete_Tuning = ATATuning2.InstallComplete.Tuning
    function ATATuning2.InstallComplete.Tuning(vehicle, part)
        original_InstallComplete_Tuning(vehicle, part)

        local data = part:getModData()
        if not (data.tuning2 and data.tuning2.protectionHealthDelta) then
            log("%s installed: no protection value, nothing to scale", tostring(part:getId()))
            return
        end

        local multiplier = getMultiplier()
        if multiplier == 1.0 then log("%s installed: multiplier x1.0, protection left as is", tostring(part:getId())); return end

        local newDelta = data.tuning2.protectionHealthDelta * multiplier
        data.tuning2.protectionHealthDelta = newDelta
        vehicle:transmitPartModData(part)

        log("%s protection damage scaled to %.1f (x%.1f multiplier)", tostring(part:getId()), newDelta, multiplier)
    end

    log("wrapped ATATuning2.InstallComplete.Tuning (multiplier now x%.2f)", getMultiplier())
end

-- 2026-10-02 (MP audit): a dedicated server never fires OnGameStart, so
-- the wrap was never installed where parts are really installed.
-- OnServerStarted covers it; `wrapped` stops a second wrap on a host.
Events.OnGameStart.Add(wrapInstallComplete)
if Events.OnServerStarted then Events.OnServerStarted.Add(wrapInstallComplete) end

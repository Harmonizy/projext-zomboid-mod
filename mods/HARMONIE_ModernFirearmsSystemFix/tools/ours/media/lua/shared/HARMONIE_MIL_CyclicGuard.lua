--============================================================================
-- HARMONIE - Mercenary Is Life: automatic guns that fired one bullet per press
--
-- Owner 2026-11-17: "MP5: the sound is full-auto, but it really fires one
-- round; holding the trigger shoots nothing (the sound still plays); you have
-- to click again and again -- look at the other guns too."
--
-- Cause: the engine swings again while the trigger is held (OnWeaponSwing ->
-- CustomGunShotSound plays a shot sound while the magazine has rounds), but
-- no bullet leaves. Upstream's own RPM notes (EFK_Exact_RPM.lua) list a
-- cyclic "deadzone" 1.8 - 2.9 and a "no-projectile" value 1.4. Exactly seven
-- automatic guns had a script CyclicRateMultiplier of 1.8 / 1.9 -- and they
-- were also the only guns in the top RPM band (cyclic 8.0): MP5, Kriss
-- Vector, AN-94, EMP, Groza, QBZ-192, Minigun. Every other automatic gun is
-- below 1.8 and fires full-auto.
--
-- Fix (MIL 1.0.5): the scripts say 1.75 now (KS1 KAC fires full-auto at
-- 1.75), and the client RPM table puts the seven in the 1020 RPM band
-- (cyclic 6.8, used by UMP45 / HK51 / Honey Badger ...). This file:
--   * puts 1.75 back on the item scripts (DoParam) when another mod that
--     loads later (the original Modern Firearms System) brought 1.8 / 1.9
--     back -- the same trap as the ammo types (HARMONIE_MIL_AmmoCheck.lua);
--   * a gun of these types already in the world that still carries a
--     deadzone value gets 1.75 when it is held or swung (logged once per
--     gun). It never touches a value outside the deadzone, so it does not
--     fight the client's calibrated cyclic (ExactAutomaticRPM.lua).
--============================================================================

HARMONIE_MIL_CyclicGuard = HARMONIE_MIL_CyclicGuard or {}
local CG = HARMONIE_MIL_CyclicGuard

CG.SAFE = 1.75
CG.TYPES = {
    ["Base.mp5_cat"] = true, ["Base.KrissVector_cat"] = true, ["Base.AN94_cat"] = true, ["Base.EMP_cat"] = true,
    ["Base.Groza_cat"] = true, ["Base.QBZ192_cat"] = true, ["Base.minigun_cat"] = true,
}

local function side()
    if isServer and isServer() then return "server" end
    if isClient and isClient() then return "client" end
    return "SP"
end
local function log(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print("[HARMONIE_MFSFix][CyclicGuard][" .. side() .. "] " .. (ok and s or tostring(fmt)))
end

function CG.isDead(v)
    if type(v) ~= "number" then return false end
    return (v >= 1.8 - 1e-4 and v <= 2.9 + 1e-4) or math.abs(v - 1.4) < 1e-4
end

-- the item scripts (another mod may have replaced ours)
function CG.enforceScripts(when)
    local sm = ScriptManager and ScriptManager.instance
    if not sm then return end
    local n = 0
    for fullType in pairs(CG.TYPES) do
        local it
        pcall(function() it = sm:getItem(fullType) end)
        if it and it.DoParam then
            local ok = pcall(function() it:DoParam("CyclicRateMultiplier = " .. tostring(CG.SAFE)) end)
            if ok then n = n + 1 end
        end
    end
    log("%s: CyclicRateMultiplier %s set on %d gun script(s)", tostring(when), tostring(CG.SAFE), n)
end

-- a gun already in the world with a deadzone value
local fixed = setmetatable({}, { __mode = "k" })
function CG.fixWeapon(weapon, why)
    if not weapon or fixed[weapon] then return end
    if not (weapon.getFullType and weapon.getCyclicRateMultiplier and weapon.setCyclicRateMultiplier) then return end
    local okT, ft = pcall(weapon.getFullType, weapon)
    if not okT or not CG.TYPES[ft] then return end
    local okV, v = pcall(weapon.getCyclicRateMultiplier, weapon)
    if not okV then return end
    fixed[weapon] = true
    if CG.isDead(v) then
        pcall(weapon.setCyclicRateMultiplier, weapon, CG.SAFE)
        log("%s %s: cyclic %s was in the no-bullet zone -> %s (%s)", tostring(ft), tostring(weapon.getID and weapon:getID() or "?"),
            tostring(v), tostring(CG.SAFE), tostring(why))
    end
end

local lastHeld = setmetatable({}, { __mode = "k" })
local function onPlayerUpdate(player)
    if not player or not player.getPrimaryHandItem then return end
    local w = player:getPrimaryHandItem()
    if w == lastHeld[player] then return end
    lastHeld[player] = w or false
    if w then CG.fixWeapon(w, "held") end
end
local function onSwing(_, weapon)
    if weapon then CG.fixWeapon(weapon, "swing") end
end

if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(function() CG.enforceScripts("OnGameBoot") end) end
    if Events.OnGameStart then Events.OnGameStart.Add(function() CG.enforceScripts("OnGameStart") end) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(function() CG.enforceScripts("OnServerStarted") end) end
    if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(onPlayerUpdate) end
    if Events.OnWeaponSwing then Events.OnWeaponSwing.Add(onSwing) end
end

return CG

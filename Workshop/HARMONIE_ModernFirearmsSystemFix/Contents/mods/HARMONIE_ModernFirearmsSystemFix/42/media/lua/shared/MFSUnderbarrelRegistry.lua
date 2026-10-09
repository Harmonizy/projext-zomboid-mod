-- Central registry for the rebuilt pseudo-weapon underbarrel launchers.
--
-- MAINTENANCE ENTRY POINT:
-- Add one convention name below (for example ["MFS_GP25"] = {}) after its
-- Gunpart.MFS_GP25 and Base.MFS_GP25 script items/assets exist. The registry
-- derives those full types and connects switching, capability checks, MP server
-- validation, ballistics, ATRO filtering, reload timing and post-shot cycling.
-- Override only values that genuinely differ from the shared 40 mm defaults.

MFSUnderbarrelRegistry = MFSUnderbarrelRegistry or {}
local Registry = MFSUnderbarrelRegistry

Registry.VERSION = "1.1.3-rc6-cycle-timing"

-- Shared wire contract. Keep these values in one shared file so a future
-- protocol edit cannot silently leave a client or server consumer behind.
-- RC4 adds the exact server-owned launcher item ID to Launch authorization.
Registry.MP = {
    VERSION = "0.3.0-rc5-upstream-stool-fx",
    MODULE = "MFSGrenade",
    LAUNCH = "Launch",
    TRIGGER_EXPLOSION = "TriggerExplosion",
    EXPLOSION = "Explosion",
    EXPLOSION_FX = "ExplosionFX",
    CREATE_UNDERBARREL = "CreateUnderbarrelPseudo",
    CREATE_UNDERBARREL_ACK = "CreateUnderbarrelPseudoAck",
    REMOVE_UNDERBARREL = "RemoveUnderbarrelPseudo",
}

-- Upstream's three 40 mm stool parts call Grenade_Trajectory.Boom with this
-- same anonymous configuration table.  Boom therefore cannot reliably recover
-- M203 vs GP25 vs M28 without overriding their fast-moving launcher file.
-- Keep one explicit family key and the server-owned cosmetic configuration
-- instead.  This command never applies damage; it only makes observers draw
-- the same visual/audio effect the firing client already receives upstream.
Registry.UPSTREAM_STOOL_FX = {
    key = "upstream_stool_40mm",
    fxPrefix = "explosion_",
    fxFrames = 12,
    fxSize = 140, -- upstream ExplosionRange 3; our range-10 launcher uses 314
    fxDuration = 40,
    explosionSound = "AerosolBombExplode",
    explosionVolume = 0.7,
}

Registry.LAUNCHERS = {
    ["MFS_M203"] = {},
    ["MFS_GP25"] = {},
}

local DEFAULT_BALLISTICS = {
    speed = 18,
    maxRange = 30,
    arcHeightFactor = 0.03,
    projectileType = "Base.GrenadeAmmo",
    payloadType = "MFS_Explosives.40mmExplosives",
    explosionSound = "PipeBombExplode",
    explosionVolume = 0.7,
    muzzleForwardOffset = 0.59,
    muzzleHeight = 0.5,
    fxPrefix = "explosion_",
    fxFrames = 12,
    fxSize = 314,
    fxDuration = 40,
}

local function mergedCopy(defaults, overrides)
    local result = {}
    for key, value in pairs(defaults) do result[key] = value end
    if type(overrides) == "table" then
        for key, value in pairs(overrides) do result[key] = value end
    end
    return result
end

Registry.byPartType = {}
Registry.byPseudoType = {}
local launcherCount = 0

for name, settings in pairs(Registry.LAUNCHERS) do
    launcherCount = launcherCount + 1
    settings.name = name
    settings.slot = settings.slot or "Stool"
    settings.partType = settings.partType or ("Gunpart." .. name)
    settings.pseudoType = settings.pseudoType or ("Base." .. name)
    settings.reloadSpeedMultiplier = settings.reloadSpeedMultiplier or 0.30
    settings.reloadSpeedCap = settings.reloadSpeedCap or 0.40
    -- Bob_Reload_Shotgun_Load is 3360 ticks at 4800 ticks/second (700 ms).
    -- Vanilla MP instead synthesizes boltactionnomag loadFinished from 590 ms,
    -- so registered launchers use the real animation baseline on the server.
    settings.serverReloadBaseMs = settings.serverReloadBaseMs or 700
    -- M203_reload.wav is 2,614.92 ms. Use that as the normal fallback ceiling
    -- for the preceding cosmetic cycle if B42 does not emit rackingFinished;
    -- never let the cycle delay the real reload beyond the authored sound.
    settings.cycleFallbackMs = settings.cycleFallbackMs or 2615
    settings.cycleDuration = settings.cycleDuration or 75
    settings.cycleSound = settings.cycleSound or "MSR700EjectAmmo"
    settings.ballistics = mergedCopy(DEFAULT_BALLISTICS, settings.ballistics)
    Registry.byPartType[settings.partType] = settings
    Registry.byPseudoType[settings.pseudoType] = settings
end

function Registry.getInstalledPartType(weapon, slot)
    if not weapon or not instanceof(weapon, "HandWeapon") then return nil end
    slot = slot or "Stool"
    local data = weapon:getModData()
    if type(data.weaponpart) == "table" and type(data.weaponpart[slot]) == "string" then
        return data.weaponpart[slot]
    end
    local part = weapon:getWeaponPart(slot)
    return part and part:getFullType() or nil
end

function Registry.getForHost(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return nil end
    for _, definition in pairs(Registry.LAUNCHERS) do
        if Registry.getInstalledPartType(weapon, definition.slot) == definition.partType then
            return definition
        end
    end
    return nil
end

function Registry.getForPseudo(itemOrFullType)
    local fullType = type(itemOrFullType) == "string" and itemOrFullType
        or itemOrFullType and itemOrFullType:getFullType() or nil
    return fullType and Registry.byPseudoType[fullType] or nil
end

function Registry.isPseudo(itemOrFullType)
    return Registry.getForPseudo(itemOrFullType) ~= nil
end

print("[MFSUnderbarrelRegistry] version " .. Registry.VERSION
    .. " loaded; launchers=" .. tostring(launcherCount))

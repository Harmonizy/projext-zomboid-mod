local MFSEject = {}

--------------------------------------------------------------------
--- Sandbox toggle: whether shell ejection (抛壳) is enabled.
--- Defaults to on when the sandbox option is absent (older saves).
--------------------------------------------------------------------
function MFSEject.IsEnabled()
    -- ModOptions override: the client settings page writes MFSEject._enabled.
    -- In single-player the client and server share one Lua state, so the
    -- server-side ejection gate sees the same value.
    if MFSEject._enabled ~= nil then
        return MFSEject._enabled
    end
    return not (SandboxVars and SandboxVars.MFSEject and SandboxVars.MFSEject.Enabled == false)
end

--------------------------------------------------------------------
--- Per-weapon ejection port overrides (empty by default; the
--- fallback DefaultEjectionPortParams below covers all MFS guns
--- through their WeaponReloadType).
--------------------------------------------------------------------
MFSEject.WeaponEjectionPortParams = {}

--------------------------------------------------------------------
--- Fallback defaults keyed by WeaponReloadType (covers every
--- reload type used by Modern Firearms System).
--------------------------------------------------------------------
MFSEject.DefaultEjectionPortParams = {
    [WeaponReloadType.BOLT_ACTION_NO_MAG] = {
        forwardOffset = 0.30,
        sideOffset    = 0.10,
        heightOffset  = 0.45,
        shellForce    = 0.45,
        sideSpread    = 30,
        heightSpread  = 30,
    },

    [WeaponReloadType.BOLT_ACTION] = {
        forwardOffset = 0.30,
        sideOffset    = 0.10,
        heightOffset  = 0.45,
        shellForce    = 0.75,
        sideSpread    = 60,
        heightSpread  = 30,
        ejectAngle    = 75,
    },

    [WeaponReloadType.SHOTGUN] = {
        forwardOffset = 0.27,
        sideOffset    = 0.10,
        heightOffset  = 0.45,
        shellForce    = 0.25,
        sideSpread    = 30,
        heightSpread  = 30,
        ejectAngle    = 75,
    },

    [WeaponReloadType.DOUBLE_BARREL_SHOTGUN] = {
        forwardOffset = 0.27,
        sideOffset    = 0.0,
        heightOffset  = 0.45,
        shellForce    = 0.15,
        sideSpread    = 30,
        heightSpread  = { 80, 100 },
        ejectAngle    = 180,
    },

    [WeaponReloadType.DOUBLE_BARREL_SHOTGUN_SAWN] = {
        forwardOffset = 0.27,
        sideOffset    = 0.0,
        heightOffset  = 0.45,
        shellForce    = 0.15,
        sideSpread    = 30,
        heightSpread  = { 80, 100 },
        ejectAngle    = 180,
    },

    [WeaponReloadType.HANDGUN] = {
        forwardOffset = 0.40,
        sideOffset    = 0.0,
        heightOffset  = 0.50,
        shellForce    = 0.60,
        sideSpread    = 45,
        heightSpread  = 90,
    },

    [WeaponReloadType.REVOLVER] = {
        forwardOffset = 0.10,
        sideOffset    = 0.0,
        heightOffset  = 0.30,
        shellForce    = 0.10,
        sideSpread    = 30,
        heightSpread  = 30,
    },

    [WeaponReloadType.LEVER_ACTION] = {
        forwardOffset = 0.10,
        sideOffset    = 0.0,
        heightOffset  = 0.32,
        shellForce    = 0.45,
        sideSpread    = 30,
        heightSpread  = 30,
    },
}

--------------------------------------------------------------------
--- Ammo item full type -> casing item type mapping.
--- Keys are the values returned by weapon:getAmmoType():getItemKey().
--- MFS keeps all of its ammo items in module Base, so the full types
--- are "Base.X" even for its custom calibres.
--------------------------------------------------------------------
MFSEject.AMMO_TO_CASING = {
    -- Vanilla calibres reused by MFS
    ["Base.Bullets9mm"]    = "MFSEject.9x19_Casing",
    ["Base.Bullets45"]     = "MFSEject.45_Casing",
    ["Base.Bullets44"]     = "MFSEject.44_Casing",
    ["Base.Bullets38"]     = "MFSEject.3006_Casing", -- MFS redefines .38 as 6.8mm
    ["Base.308Bullets"]    = "MFSEject.762x51_Casing",
    ["Base.556Bullets"]    = "MFSEject.556x45_Casing",
    ["Base.ShotgunShells"] = "MFSEject.12Gauge_Hull_Red",

    -- MFS custom calibres
    ["Base.Bullets50"]     = "MFSEject.50BMG_Casing",   -- 12.7mm (.50)
    ["Base.Bullets145"]    = "MFSEject.50BMG_Casing",   -- 14.5mm -> reuse .50 casing
    ["Base.545Bullets"]    = "MFSEject.545x39_Casing",  -- 5.45x39
    ["Base.Bullets86"]     = "MFSEject.3006_Casing",    -- 8.6mm -> reuse 30-06 casing
    ["Base.A_58bullets"]   = "MFSEject.556x45_Casing",  -- 5.8mm -> reuse 5.56 casing
    ["Base.GrenadeAmmo"]   = "MFSEject.40mm_Casing",    -- 40mm grenade

    -- Crossbow bolts deliberately unmapped: crossbows eject no casing.
}

--------------------------------------------------------------------
--- Register helpers (kept for future per-mod tuning).
--------------------------------------------------------------------
function MFSEject.RegisterCasingToAmmo(entries, casingType)
    if type(entries) == "table" then
        for ammoType, itemType in pairs(entries) do
            if type(ammoType) == "string" and type(itemType) == "string" then
                MFSEject.AMMO_TO_CASING[ammoType] = itemType
            end
        end
        return
    end

    if type(entries) == "string" and type(casingType) == "string" then
        MFSEject.AMMO_TO_CASING[entries] = casingType
    end
end

function MFSEject.RegisterWeaponParams(
    weapon,
    forwardOffset,
    sideOffset,
    heightOffset,
    shellForce,
    sideSpread,
    heightSpread,
    ejectAngle,
    verticalForce)
    MFSEject.WeaponEjectionPortParams[weapon] = {
        forwardOffset = forwardOffset or 0,
        sideOffset    = sideOffset or 0,
        heightOffset  = heightOffset or 0,
        shellForce    = shellForce or 0,
        sideSpread    = sideSpread or 10,
        heightSpread  = heightSpread or 10,
        ejectAngle    = ejectAngle,
        verticalForce = verticalForce,
    }
end

return MFSEject

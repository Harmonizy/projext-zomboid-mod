--[[
    Defensive fix for a theorized (not yet confirmed by the user) cause of
    "ammo doesn't deplete" reports against ModernFirearmsSystem.

    media/lua/client/WeaponAbility/ChangeMagazineType.lua defines a LOCAL
    function NeedRefresh(), added to Events.OnEquipPrimary and
    Events.OnGameStart, which -- whenever a held ranged weapon's cached
    modData().MagzineTypeNow differs from its live getMagazineType() --
    calls the GLOBAL function ChangeMagzine(player, gun, cachedType,
    "ReFresh", true). That function creates a brand-new item instance via
    instanceItem(), copies getCurrentAmmoCount()/getMaxAmmo() across from
    the old instance, then removes the old item and adds the new one as
    the equipped weapon (confirmed by reading that file directly:
    NeedRefresh at line 74, the mismatch check at line 83, ChangeMagzine
    itself at line 1, the item swap at lines 51-52).

    NeedRefresh is a `local function`, invisible outside its own file --
    it cannot be wrapped or removed from another mod. ChangeMagzine,
    however, is a plain global function (no `local` keyword), so it CAN be
    wrapped the same way HARMONIE_SVU3PW_Hooks.lua wraps
    ATATuning2.InstallComplete.Tuning: call through to the original,
    unchanged, in the normal case.

    The guard added here: if OnEquipPrimary fires this automatic "ReFresh"
    resync while the player already has a timed action queued (e.g.
    mid-fire, mid-reload -- checked via ISTimedActionQueue.getTimedActionQueue,
    the same #queue.queue > 0 idiom vanilla itself uses in
    server/BuildingObjects/ISMoveableCursor.lua and elsewhere), the swap is
    skipped for that call. The cached MagzineTypeNow is left mismatched, so
    the next OnEquipPrimary (once the player is no longer mid-action) will
    re-check and perform the resync then, once it's safe. This only touches
    the Tag == "ReFresh" automatic-resync path; a player's own deliberate
    magazine change (any other Tag) is never delayed.

    This is a mitigation for a plausible race, not a confirmed fix -- ask
    the user to confirm whether the original "ammo doesn't deplete" report
    persists with this installed, and separately whether Project Zomboid's
    own Unlimited Ammo debug/admin flag (player:isUnlimitedAmmo(), which
    this mod's own MFSFireStateDiagnostics.lua and CustomGunShotSound.lua
    already special-case) was active during testing -- that flag alone
    fully explains the reported symptom with no mod bug involved.
]]--

local function installGuard()
    if not ChangeMagzine then
        print("HARMONIE ModernFirearmsSystem Fix: global ChangeMagzine not found -- is ModernFirearmsSystem installed and enabled?")
        return
    end

    local original_ChangeMagzine = ChangeMagzine
    ChangeMagzine = function(playerObj, MainGun, MagazineType, Tag, Need)
        if Tag == "ReFresh" and playerObj then
            local actionQueue = ISTimedActionQueue.getTimedActionQueue(playerObj)
            if actionQueue and actionQueue.queue and #actionQueue.queue > 0 then
                return -- player is mid-action; defer the resync to the next safe OnEquipPrimary
            end
        end
        return original_ChangeMagzine(playerObj, MainGun, MagazineType, Tag, Need)
    end

    print("HARMONIE ModernFirearmsSystem Fix: ChangeMagzine mid-action guard installed.")
end

Events.OnGameStart.Add(installGuard)

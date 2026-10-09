require "Gun_Vars/Weapon_Ability/AWCWF_Gun_Shot_Profiles"
require "Gun_Vars/AWCWF_Part_Stat_Set"
require "AWCWF_Mod_Options"

MFSGunshotDiagnostics = MFSGunshotDiagnostics or {}

local GunDiag = MFSGunshotDiagnostics
GunDiag.VERSION = "0.2.2-rc2"
GunDiag.ENABLED = false -- RC2 accepted; retain instrumentation for future troubleshooting.
GunDiag.pendingSounds = GunDiag.pendingSounds or {}
GunDiag.lastState = GunDiag.lastState or setmetatable({}, { __mode = "k" })

local function diag(message)
    if GunDiag.ENABLED then
        print("[MFSGunshotDiag] " .. tostring(message))
    end
end

local function safeCall(default, callback)
    local ok, result = pcall(callback)
    if ok then
        return result
    end
    return default
end

local function playerState(playerObj)
    if not playerObj then
        return "player=nil"
    end
    return "invisible=" .. tostring(safeCall("ERR", function() return playerObj:isInvisible() end))
        .. " god=" .. tostring(safeCall("ERR", function() return playerObj:isGodMod() end))
        .. " unlimited=" .. tostring(safeCall("ERR", function() return playerObj:isUnlimitedAmmo() end))
        .. " access=" .. tostring(safeCall("ERR", function() return playerObj:getAccessLevel() end))
        .. " local=" .. tostring(playerObj == getPlayer())
end

local function diagnoseState(playerObj, weapon, newGunshotEnabled, hasProfile)
    if not GunDiag.ENABLED or not playerObj or playerObj ~= getPlayer() then
        return
    end
    local state = playerState(playerObj)
        .. " newGunshot=" .. tostring(newGunshotEnabled)
        .. " profile=" .. tostring(hasProfile)
        .. " weapon=" .. tostring(weapon:getFullType())
        .. " swingSound=" .. tostring(weapon:getSwingSound())
    if GunDiag.lastState[playerObj] ~= state then
        GunDiag.lastState[playerObj] = state
        diag("STATE " .. state)
    end
end

local function queueSoundCheck(emitter, handle, soundName, phase)
    if not GunDiag.ENABLED or not handle or handle == 0 then
        return
    end
    table.insert(GunDiag.pendingSounds, {
        emitter = emitter,
        handle = handle,
        soundName = soundName,
        phase = phase,
        ticks = 1
    })
end

local function checkPendingSounds()
    if not GunDiag.ENABLED then
        GunDiag.pendingSounds = {}
        return
    end
    for index = #GunDiag.pendingSounds, 1, -1 do
        local check = GunDiag.pendingSounds[index]
        check.ticks = check.ticks - 1
        if check.ticks <= 0 then
            local playing = safeCall("ERR", function()
                return check.emitter:isPlaying(check.handle)
            end)
            diag("LAYER-NEXT phase=" .. tostring(check.phase)
                .. " sound=" .. tostring(check.soundName)
                .. " handle=" .. tostring(check.handle)
                .. " playing=" .. tostring(playing))
            table.remove(GunDiag.pendingSounds, index)
        end
    end
end

local function getGunshotProfile(weapon)
    if AWCWF_GunShotProfiles[weapon:getType()] then
        return AWCWF_GunShotProfiles[weapon:getType()]
    end
end

local function getSuppressorConfig(weapon)
    if not AWCWF_SilencerSet then
        return nil
    end

    for partType, silencerSet in pairs(AWCWF_SilencerSet) do
        local part = weapon:getWeaponPart(partType)
        if part and silencerSet[part:getType()] then
            return silencerSet[part:getType()], part:getFullType()
        end
    end

    return nil
end

local function hasSuppressor(weapon)
    return getSuppressorConfig(weapon) ~= nil
end

local function getFallbackSuppressorLayers(weapon)
    local ammoType = ""
    if weapon.getAmmoType and weapon:getAmmoType() then
        ammoType = string.lower(tostring(weapon:getAmmoType()))
    end

    if string.find(ammoType, "shotgun", 1, true) then
        return {"AW_LOCKWOOD780_Fire_Sup"}
    elseif string.find(ammoType, "bullets_45", 1, true) then
        return {"AW_FSSHURRICANE_Fire_Sup"}
    elseif string.find(ammoType, "bullets_44", 1, true) then
        return {"AW_BASILISK_Fire_Sup"}
    elseif string.find(ammoType, "bullets_545", 1, true) then
        return {"AW_KASTOV545_Fire_Sup"}
    elseif string.find(ammoType, "bullets_762", 1, true) or
        string.find(ammoType, "bullets_308", 1, true) or
        string.find(ammoType, "bullets_68", 1, true) then
        return {"AW_KASTOV762_Fire_Sup"}
    elseif string.find(ammoType, "bullets_50", 1, true) or
        string.find(ammoType, "bullets_338", 1, true) or
        string.find(ammoType, "bullets_86", 1, true) or
        string.find(ammoType, "bullets_145", 1, true) then
        return {"AW_SIGNAL50_Fire_Sup"}
    elseif string.find(ammoType, "bullets_556", 1, true) or
        string.find(ammoType, "bullets_223", 1, true) or
        string.find(ammoType, "bullets_58", 1, true) then
        return {"AW_M4A1_Fire_Sup"}
    end

    return {"AW_P890_Fire_Sup"}
end

local function rememberOriginalSwingSound(weapon)
    local modData = weapon:getModData()
    -- Existing HuntingRifle instances may have serialized the invalid sound
    -- used by the old MFS item definition. Migrate that cached value in place.
    if weapon:getType() == "HuntingRifle" and
        (modData.MFSOriginalSwingSound == "M82_cat_s" or
         modData.MFSOriginalSwingSound == "MSR700Shoot") then
        modData.MFSOriginalSwingSound = "MSR788Shoot"
    end
    if modData.MFSOriginalSwingSound then
        return
    end

    local swingSound = weapon:getSwingSound()
    if weapon:getType() == "HuntingRifle" and
        (swingSound == "M82_cat_s" or swingSound == "MSR700Shoot") then
        swingSound = "MSR788Shoot"
        weapon:setSwingSound(swingSound)
    end
    if not swingSound or swingSound == "" or swingSound == "nil" then
        local scriptItem = weapon:getScriptItem()
        if scriptItem then
            local ok, scriptSwingSound = pcall(function()
                return scriptItem:getSwingSound()
            end)
            if ok then
                swingSound = scriptSwingSound
            end
        end
    end
    if swingSound and swingSound ~= "" and swingSound ~= "nil" then
        modData.MFSOriginalSwingSound = swingSound
    end
end

local function restoreOriginalSwingSound(weapon)
    local modData = weapon:getModData()
    if modData.MFSOriginalSwingSound then
        weapon:setSwingSound(modData.MFSOriginalSwingSound)
    end
end

-- Keep the effective zombie-hearing radius and the vanilla SwingSound in sync
-- before an attack begins.  Doing this only in OnWeaponSwing is too late for
-- the first shot because the engine may already have queued SwingSound.
local syncedWeaponState = setmetatable({}, { __mode = "k" })

function MFS_SyncEquippedWeaponState(playerObj, weapon, force)
    if not playerObj then
        playerObj = getPlayer()
    end
    if not weapon and playerObj then
        weapon = playerObj:getPrimaryHandItem()
    end
    if not weapon or not weapon:IsWeapon() or not weapon:isRanged() then
        return
    end

    local suppressorConfig, suppressorType = getSuppressorConfig(weapon)
    local newGunshotEnabled = AWCWF_Options and AWCWF_Options.isNewGunshotEnabled
        and AWCWF_Options.isNewGunshotEnabled() or false
    diagnoseState(playerObj, weapon, newGunshotEnabled, getGunshotProfile(weapon) ~= nil)
    local signature = table.concat({
        tostring(suppressorType or "-"),
        tostring(newGunshotEnabled),
        tostring(weapon:getType())
    }, "\31")

    if not force and syncedWeaponState[weapon] == signature then
        return
    end

    local scriptItem = weapon:getScriptItem()
    if scriptItem then
        local soundVolume = scriptItem:getSoundVolume()
        local soundRadius = scriptItem:getSoundRadius()
        if suppressorConfig then
            soundVolume = soundVolume * suppressorConfig.SoundVolumeModifier
            soundRadius = soundRadius * suppressorConfig.SoundRadiusModifier
        end
        weapon:setSoundVolume(soundVolume)
        weapon:setSoundRadius(soundRadius)
    end

    -- Weapon-part stat bonuses (CriticalChance / CritDmgMultiplier /
    -- CyclicRateMultiplier). Recomputed from the script base plus installed
    -- parts so it stays idempotent across equip and attach/detach passes.
    if AWCWF_ApplyPartStats then
        AWCWF_ApplyPartStats(playerObj, weapon)
    end

    if newGunshotEnabled and (getGunshotProfile(weapon) or suppressorConfig) then
        rememberOriginalSwingSound(weapon)
        weapon:setSwingSound("nil")
    else
        restoreOriginalSwingSound(weapon)
    end

    syncedWeaponState[weapon] = signature
end

local function hasShootableRound(weapon, playerObj)
    -- Match vanilla ISReloadWeaponAction.canShoot: unlimited-ammo players can
    -- fire even when the weapon reports zero magazine and chambered rounds.
    -- Without this check the custom gunshot path incorrectly plays only the
    -- dry-trigger layer once the displayed ammo reaches zero.
    if playerObj and safeCall(false, function() return playerObj:isUnlimitedAmmo() end) then
        return true
    end

    if weapon:getCurrentAmmoCount() and weapon:getCurrentAmmoCount() > 0 then
        return true
    end

    if weapon.isRoundChambered and weapon:isRoundChambered() then
        return true
    end

    return false
end

local function getRemainingAmmoAfterShot(weapon)
    local currentAmmo = 0
    if weapon.getCurrentAmmoCount and weapon:getCurrentAmmoCount() then
        currentAmmo = weapon:getCurrentAmmoCount()
    end

    if currentAmmo > 0 then
        return currentAmmo - 1
    end

    if weapon.isRoundChambered and weapon:isRoundChambered() then
        return 0
    end

    return currentAmmo
end

local function getMaxAmmo(weapon)
    if weapon.getMaxAmmo and weapon:getMaxAmmo() then
        return weapon:getMaxAmmo()
    end

    return 0
end

local function getLowAmmoWarning(profile, weapon)
    local lowAmmo = profile.lowAmmo
    if not lowAmmo then
        return nil
    end

    local maxAmmo = getMaxAmmo(weapon)
    if maxAmmo <= 0 then
        return nil
    end

    local remainingAmmo = getRemainingAmmoAfterShot(weapon)
    local warningLimit = math.max(1, math.floor(maxAmmo * lowAmmo.lastRoundsPercent))
    if remainingAmmo > warningLimit then
        return nil
    end

    for _, warning in ipairs(lowAmmo.sounds) do
        local threshold = math.floor(maxAmmo * warning.maxRemainingPercent)
        if remainingAmmo <= threshold then
            return warning
        end
    end

    return nil
end

local function playLowAmmoWarning(emitter, profile, weapon)
    local warning = getLowAmmoWarning(profile, weapon)
    if warning then
        local sound = emitter:playSound(warning.soundName)
        if warning.volume and sound then
            emitter:setVolume(sound, warning.volume)
        end
    end
end

-- The original profile table references optional layers that are not defined by
-- any loaded MFS sound script. Skip them instead of asking the emitter to play
-- invalid event IDs; all valid core/distant/suppressed layers remain unchanged.
local unavailableGunshotLayers = {
    ["AW_0000_Fire_Core"] = true,
    ["AW_0000_Fire_Dist"] = true,
    ["AW_0000_Fire_FCG"] = true,
    ["AW_0000_Fire_Far"] = true,
    ["AW_0000_Fire_Mech"] = true,
    ["AW_0000_Fire_Sup"] = true,
    ["AW_50GS_Fire_FCG"] = true,
    ["AW_BASILISK_Fire_FCG"] = true,
    ["AW_BRYSON800_Fire_Mech"] = true,
    ["AW_CHIMERA_Fire_FCG"] = true,
    ["AW_EBR14_Fire_FCG"] = true,
    ["AW_FENNEC_Fire_FCG"] = true,
    ["AW_FTACRECON_Fire_FCG"] = true,
    ["AW_FTACSIEGE_Fire_FCG"] = true,
    ["AW_HCR56_Fire_FCG"] = true,
    ["AW_KILO53_Fire_FCG"] = true,
    ["AW_KVBROADSIDE_Fire_FCG"] = true,
    ["AW_LA_B330_Fire_FCG"] = true,
    ["AW_LMS_Fire_FCG"] = true,
    ["AW_LMS_Fire_Mech"] = true,
    ["AW_LOCKWOOD300_Fire_Dist"] = true,
    ["AW_LOCKWOOD300_Fire_FCG"] = true,
    ["AW_LOCKWOOD300_Fire_Far"] = true,
    ["AW_LOCKWOOD300_Fire_Mech"] = true,
    ["AW_LOCKWOOD780_Fire_FCG"] = true,
    ["AW_M16A4_Fire_Dist"] = true,
    ["AW_M16A4_Fire_Far"] = true,
    ["AW_M16A4_Fire_Mech"] = true,
    ["AW_M4A1_Fire_Core"] = true,
    ["AW_M4A1_Fire_FCG"] = true,
    ["AW_MCPR300_Fire_FCG"] = true,
    ["AW_MINIBAK_Fire_FCG"] = true,
    ["AW_P890_Fire_FCG"] = true,
    ["AW_PDSW528_Fire_FCG"] = true,
    ["AW_RAALMG_Fire_FCG"] = true,
    ["AW_RAM7_Fire_Dist"] = true,
    ["AW_RAM7_Fire_FCG"] = true,
    ["AW_RAM7_Fire_Far"] = true,
    ["AW_RAM7_Fire_Mech"] = true,
    ["AW_RAPP_H_Fire_FCG"] = true,
    ["AW_RPK_Fire_FCG"] = true,
    ["AW_SIGNAL50_Fire_FCG"] = true,
    ["AW_SO14_Fire_FCG"] = true,
    ["AW_SPX80_Fire_FCG"] = true,
    ["AW_SPX80_Fire_Mech"] = true,
    ["AW_TAQV_Fire_FCG"] = true,
    ["AW_TR76GEIST_Fire_FCG"] = true,
    ["AW_VICTUSXMR_Fire_FCG"] = true,
    ["AW_X12_Fire_FCG"] = true,
}

local function playLayers(emitter, layers, playerObj, weapon, phase)
    for _, soundName in ipairs(layers) do
        if not unavailableGunshotLayers[soundName] then
            local handle = emitter:playSound(soundName)
            local playbackEmitter = emitter
            local route = "character"

            -- RC2-3: B42 rejects character-emitter playback while an admin is
            -- invisible (playSound returns handle 0), although the weapon-swing
            -- callbacks still run. Retry only that rejected case on a local
            -- world emitter positioned at the shooter. playSoundImpl avoids
            -- transmitting another sound event; weapon/zombie-hearing noise is
            -- handled separately and is therefore unchanged by this fallback.
            local invisible = playerObj and safeCall(false, function()
                return playerObj:isInvisible()
            end) or false
            if (not handle or handle == 0) and invisible then
                local square = playerObj:getSquare()
                local world = getWorld and getWorld() or nil
                if square and world then
                    local fallbackEmitter = world:getFreeEmitter(
                        playerObj:getX(), playerObj:getY(), playerObj:getZ())
                    if fallbackEmitter then
                        local ok, retryHandle = pcall(function()
                            fallbackEmitter:setPos(playerObj:getX(), playerObj:getY(), playerObj:getZ())
                            return fallbackEmitter:playSoundImpl(soundName, square)
                        end)
                        if ok then
                            playbackEmitter = fallbackEmitter
                            handle = retryHandle
                            route = "invisible-world-fallback"
                        else
                            diag("FALLBACK-ERROR phase=" .. tostring(phase)
                                .. " sound=" .. tostring(soundName)
                                .. " error=" .. tostring(retryHandle))
                        end
                    end
                end
            end
            local playing = handle and handle ~= 0 and safeCall("ERR", function()
                return playbackEmitter:isPlaying(handle)
            end) or false
            diag("LAYER phase=" .. tostring(phase)
                .. " sound=" .. tostring(soundName)
                .. " handle=" .. tostring(handle)
                .. " playingNow=" .. tostring(playing)
                .. " route=" .. tostring(route)
                .. " weapon=" .. tostring(weapon and weapon:getFullType())
                .. " " .. playerState(playerObj))
            queueSoundCheck(playbackEmitter, handle, soundName, phase .. "/" .. route)
        end
    end
end

local function TriggerGunShot(playerObj, weapon)
    if not weapon or not weapon:IsWeapon() or not weapon:isRanged() then
        return
    end

    diag("SWING weapon=" .. tostring(weapon:getFullType())
        .. " ammo=" .. tostring(weapon:getCurrentAmmoCount())
        .. " chambered=" .. tostring(weapon:isRoundChambered())
        .. " swingSound=" .. tostring(weapon:getSwingSound())
        .. " " .. playerState(playerObj))

    if not AWCWF_Options.isNewGunshotEnabled() then
        restoreOriginalSwingSound(weapon)
        return
    end

    local profile = getGunshotProfile(weapon)
    if not profile then
        if not hasShootableRound(weapon, playerObj) then
            return
        end

        if hasSuppressor(weapon) then
            rememberOriginalSwingSound(weapon)
            weapon:setSwingSound("nil")
            playLayers(playerObj:getEmitter(), getFallbackSuppressorLayers(weapon),
                playerObj, weapon, "fallback-suppressed")
        else
            restoreOriginalSwingSound(weapon)
        end
        return
    end

    weapon:setSwingSound("nil")

    local emitter = playerObj:getEmitter()
    if not hasShootableRound(weapon, playerObj) then
        playLayers(emitter, profile.triggerLayers, playerObj, weapon, "trigger")
        return
    end

    if hasSuppressor(weapon) then
        playLayers(emitter, profile.suppressorLayers, playerObj, weapon, "suppressed")
    else
        playLayers(emitter, profile.normalLayers, playerObj, weapon, "normal")
    end

    -- if weapon.isAutomatic and weapon:isAutomatic() then
    playLowAmmoWarning(emitter, profile, weapon)
    -- end
end

Events.OnWeaponSwing.Add(TriggerGunShot)

local function diagnoseShotCompletion(playerObj, weapon)
    if weapon and weapon:IsWeapon() and weapon:isRanged() then
        diag("HITPOINT weapon=" .. tostring(weapon:getFullType())
            .. " ammo=" .. tostring(weapon:getCurrentAmmoCount())
            .. " chambered=" .. tostring(weapon:isRoundChambered())
            .. " " .. playerState(playerObj))
    end
end

Events.OnWeaponSwingHitPoint.Add(diagnoseShotCompletion)
Events.OnTick.Add(checkPendingSounds)

local function syncEquippedWeapon(playerObj, weapon)
    MFS_SyncEquippedWeaponState(playerObj, weapon, true)
end

local function syncEquippedWeaponOnUpdate(playerObj)
    MFS_SyncEquippedWeaponState(playerObj, nil, false)
end

local function syncEquippedWeaponOnCreate(_, playerObj)
    MFS_SyncEquippedWeaponState(playerObj, nil, true)
end

Events.OnEquipPrimary.Add(syncEquippedWeapon)
Events.OnPlayerUpdate.Add(syncEquippedWeaponOnUpdate)
Events.OnCreatePlayer.Add(syncEquippedWeaponOnCreate)
Events.OnGameStart.Add(syncEquippedWeapon)

diag("version " .. GunDiag.VERSION .. " loaded")

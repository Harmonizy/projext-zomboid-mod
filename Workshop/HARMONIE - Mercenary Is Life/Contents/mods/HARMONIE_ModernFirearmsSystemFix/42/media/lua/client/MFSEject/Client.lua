local MFSEject = require("MFSEject/Init")

function MFSEject.onWeaponSwing(player, weapon)
    if not player or not weapon then return end
    if not MFSEject.IsEnabled() then return end
    if not ISReloadWeaponAction.canShoot(player, weapon) then return end
    if player:isDoShove() then return end
    if weapon:isRackAfterShoot()
        or weapon:isManuallyRemoveSpentRounds()
        or weapon:isMelee() then
        return
    end

    if isClient() and player.isLocalPlayer and not player:isLocalPlayer() then
        return
    end

    if isClient() then
        sendClientCommand("MFSEject", "spawnCasing", {
            weaponId = weapon:getID(),
        })
    else
        if MFSEject.spawnCasing then
            MFSEject.spawnCasing(player, weapon)
        end
    end
end

function MFSEject.onServerCommand(module, command, args)
    if module ~= "MFSEject" then return end
    if command ~= "playCasingImpactSound" then return end
    if not args or not args.sound then return end

    local player = getPlayer()
    if not player then return end

    player:getEmitter():playSound(args.sound)
end

Events.OnWeaponSwing.Add(MFSEject.onWeaponSwing)
Events.OnServerCommand.Add(MFSEject.onServerCommand)

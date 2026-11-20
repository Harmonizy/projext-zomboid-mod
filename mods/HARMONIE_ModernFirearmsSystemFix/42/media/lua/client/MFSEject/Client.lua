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
        -- MIL 1.0.11: at most 4 casing requests a second (full auto sent one
        -- per shot; the server limits too)
        local t = getTimestampMs and getTimestampMs() or 0
        MFSEject.sendWin = MFSEject.sendWin or { start = 0, n = 0 }
        local w = MFSEject.sendWin
        if t - w.start >= 1000 then w.start, w.n = t, 0 end
        if w.n >= 4 then return end
        w.n = w.n + 1
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

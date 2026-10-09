require("TimedActions/ISReloadWeaponAction")
require("TimedActions/ISRackFirearm")

local MFSEject = require("MFSEject/Init")

-- Spawns a casing for the spent round(s) that are ejected while racking a
-- bolt-action / pump shotgun, and while reloading a revolver / lever-action /
-- break-open firearm. This is the vanilla-only path (MFS guns use the vanilla
-- ammo system), so it mirrors zHBVCEF's non-mod-integration branches.
local function applyTimedActionHooks()
    ------- Racking -------------
    local ISRackFirearm_ejectSpentRounds = ISRackFirearm.ejectSpentRounds
    function ISRackFirearm:ejectSpentRounds()
        if self.gun:getSpentRoundCount() > 0 then
            if not isClient() then
                for i = 1, self.gun:getSpentRoundCount() do
                    MFSEject.rackCasing(self.character, self.gun, false)
                end
            end
            self.gun:setSpentRoundCount(0)
            syncHandWeaponFields(self.character, self.gun)
        elseif self.gun:isSpentRoundChambered() then
            self.gun:setSpentRoundChambered(false)
            self.ejectingSpentRound = true
            self.racking = false
            syncHandWeaponFields(self.character, self.gun)
        else
            return
        end
    end

    local ISRackFirearm_animEvent = ISRackFirearm.animEvent
    function ISRackFirearm:animEvent(event, parameter)
        if event == "ejectCasing" then
            if self.ejectingSpentRound then
                if isClient() then
                    sendClientCommand("MFSEject", "rackCasing", {
                        weaponId = self.gun:getID(),
                        racking  = false,
                    })
                else
                    MFSEject.rackCasing(self.character, self.gun, false)
                end
            end
            local hasRoundToEject = not self.emptyRack
            if not hasRoundToEject
                and isClient()
                and not self.gun:isManuallyRemoveSpentRounds()
                and not self.gun:isJammed() then
                hasRoundToEject = self.hadRoundChambered
            end
            if self.racking and hasRoundToEject then
                if isClient() then
                    sendClientCommand("MFSEject", "rackCasing", {
                        weaponId = self.gun:getID(),
                        racking  = true,
                    })
                else
                    MFSEject.rackCasing(self.character, self.gun, true)
                end
            end
        end
        return ISRackFirearm_animEvent(self, event, parameter)
    end

    local ISRackFirearm_new = ISRackFirearm.new
    function ISRackFirearm:new(character, gun)
        local o = ISRackFirearm_new(self, character, gun)
        o.ejectingSpentRound = false
        o.racking = true
        o.emptyRack = true
        o.hadRoundChambered = gun:isRoundChambered()
        return o
    end

    ------- Reloading -------------
    local ISReloadWeaponAction_ejectSpentRounds = ISReloadWeaponAction.ejectSpentRounds
    function ISReloadWeaponAction:ejectSpentRounds()
        if self.gun:getSpentRoundCount() > 0 then
            if not isClient() then
                for i = 1, self.gun:getSpentRoundCount() do
                    MFSEject.rackCasing(self.character, self.gun, false)
                end
            end
            self.gun:setSpentRoundCount(0)
            syncHandWeaponFields(self.character, self.gun)
        elseif self.gun:isSpentRoundChambered() then
            self.gun:setSpentRoundChambered(false)
            if not isClient() then
                MFSEject.rackCasing(self.character, self.gun, false)
            end
            syncHandWeaponFields(self.character, self.gun)
        else
            return
        end
    end
end

Events.OnInitGlobalModData.Add(applyTimedActionHooks)

-- RC3: keep the upstream relative path so this separate patch mod overrides
-- MFS's copy, but do not try to construct client UI on a dedicated server.
if isServer() then
    return
end

require "ISUI/ISInventoryPane"

local VanillaGunOptions = {
    AssaultRifle = "_AssaultRifle_Spawn",
    AssaultRifle2 = "_AssaultRifle2_Spawn",
    HuntingRifle = "_HuntingRifle_Spawn",
    VarmintRifle = "_VarmintRifle_Spawn",
    JS14_Rifle = "_JS14_Rifle_Spawn",
    JS3T_Shotgun = "_JS3T_Shotgun_Spawn",
    L92_Carbine = "_L92_Carbine_Spawn",
    L94_Rifle = "_L94_Rifle_Spawn",
    MSR7T_Rifle = "_MSR7T_Rifle_Spawn",
    TrapperCarbine = "_TrapperCarbine_Spawn",
    Pistol = "_Pistol_Spawn",
    Pistol2 = "_Pistol2_Spawn",
    Pistol3 = "_Pistol3_Spawn",
    Revolver = "_Revolver_Spawn",
    Revolver_Long = "_Revolver_Long_Spawn",
    Shotgun = "_Shotgun_Spawn",
    ShotgunSawnoff = "_ShotgunSawnoff_Spawn",
    DoubleBarrelShotgun = "_DoubleBarrelShotgun_Spawn",
}

local previousRefreshContainer = ISInventoryPane.refreshContainer

function ISInventoryPane:refreshContainer()
    local inventory = self.inventory
    local sandbox = SandboxVars and SandboxVars.ModernFirearmsSystemSandboxGun

    if inventory and sandbox then
        local removedAny = false

        for itemType, optionName in pairs(VanillaGunOptions) do
            if sandbox[optionName] == false then
                local removed = inventory:RemoveAll(itemType)
                if removed and removed:size() > 0 then
                    removedAny = true
                    if isClient() then
                        sendRemoveItemsFromContainer(inventory, removed)
                    end
                end
            end
        end

        if removedAny then
            inventory:setDrawDirty(false)
        end
    end

    return previousRefreshContainer(self)
end

local old_perform = ISDropWorldItemAction.perform

function ISDropWorldItemAction:perform()
    if self.item:getModData().weaponpart then
        local modData = self.item:getModData().weaponpart
        for k, v in pairs(modData) do
            local RealPart = self.item:getWeaponPart(k, true)
            if not RealPart then
                local Part = instanceItem(v)
                if Part and instanceof(Part, "WeaponPart") then
                    self.item:setWeaponPart(k, Part, true, true)
                end
            end

        end
    end
    old_perform(self)
end

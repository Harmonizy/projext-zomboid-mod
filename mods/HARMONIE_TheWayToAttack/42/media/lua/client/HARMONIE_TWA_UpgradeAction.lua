--============================================================================
-- HARMONIE_TheWayToAttack -- melee attach/detach timed-action overrides (client)
--
-- Reuses the vanilla ISUpgradeWeapon / ISRemoveWeaponUpgrade actions so the
-- native HandWeapon:attachWeaponPart / detachWeaponPart path is identical to
-- vanilla gun attachments. Only two light touches:
--   * ISUpgradeWeapon:isValid -- enforce melee-only + slot-empty + part-in-hand
--     (empty MountOn makes canAttach always true, so the melee check is here).
--   * perform -- refresh the parts UI after the vanilla work completes.
-- Non-melee weapons fall through to the original implementation unchanged.
--============================================================================

require "TimedActions/ISUpgradeWeapon"
require "TimedActions/ISRemoveWeaponUpgrade"

local oldUpgradeIsValid = ISUpgradeWeapon.isValid
local oldUpgradePerform  = ISUpgradeWeapon.perform
local oldRemovePerform   = ISRemoveWeaponUpgrade.perform

function ISUpgradeWeapon:isValid()
    if self.weapon and self.part and TWAPartSystem.IsMeleeWeapon(self.weapon) then
        if self.weapon:getWeaponPart(self.part:getPartType()) then
            return false
        end
        local inv = self.character:getInventory()
        if inv:contains(self.part) then return true end
        -- R68 (MP): a part just picked up off the floor can reach this
        -- client's inventory as a new copy of the item -- find it by id
        local id = self.part.getID and self.part:getID()
        for _, m in ipairs({ "getItemWithIDRecursiv", "getItemById", "getItemWithID" }) do
            if id and inv[m] then
                local ok, found = pcall(inv[m], inv, id)
                if ok and found then self.part = found return true end
            end
        end
        return false
    end
    return oldUpgradeIsValid(self)
end

function ISUpgradeWeapon:perform()
    oldUpgradePerform(self)
    if TWAPartsUI and TWAPartsUI.refresh then
        TWAPartsUI.refresh()
    end
end

function ISRemoveWeaponUpgrade:perform()
    oldRemovePerform(self)
    if TWAPartsUI and TWAPartsUI.refresh then
        TWAPartsUI.refresh()
    end
end

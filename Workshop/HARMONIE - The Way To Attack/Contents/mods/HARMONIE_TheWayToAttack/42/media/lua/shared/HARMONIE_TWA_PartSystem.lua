--============================================================================
-- HARMONIE_TheWayToAttack -- melee weapon part system (shared)
--
-- B42 stores melee and ranged weapons in the same Java class (HandWeapon), so
-- the engine's native WeaponPart storage works for melee too. Parts are real
-- `base:weaponpart` items attached via HandWeapon:attachWeaponPart and read
-- back with getWeaponPart. This applies to ANY melee weapon in the game
-- (vanilla, other mods, or ours) -- not just this mod's own 137 items.
--
-- Native WeaponPart modifiers (WeightModifier / MaxRangeModifier, declared on
-- the item script) are applied and persisted by the engine itself. Melee-only
-- stats the native system does not expose are provided by overriding the
-- HandWeapon getters below, which sum PartDefs bonuses from attached parts.
-- Untouched weapons (guns, vanilla melee, other mods) return the original
-- value unchanged.
--============================================================================

TWAPartSystem = TWAPartSystem or {}

TWAPartSystem.Slots = {
    { key = "Grip",     label = "IGUI_TWA_Slot_Grip" },
    { key = "Head",     label = "IGUI_TWA_Slot_Head" },
    { key = "Tactical", label = "IGUI_TWA_Slot_Tactical" },
    { key = "Weight",   label = "IGUI_TWA_Slot_Weight" },
}

TWAPartSystem.SlotLabels = {}
for _, s in ipairs(TWAPartSystem.Slots) do
    TWAPartSystem.SlotLabels[s.key] = s.label
end

-- Melee detection: HandWeapon (the only weapon class in B42) but not ranged.
function TWAPartSystem.IsMeleeWeapon(item)
    if not item then return false end
    if not instanceof(item, "HandWeapon") then return false end
    if item:isRanged() then return false end
    return true
end

-- Part definitions (single source of truth): fullType -> slot / label / bonuses.
--   bonuses: melee-only stats applied via the getter overrides below.
--   WeightModifier / MaxRangeModifier are native WeaponPart fields declared in
--   the item script and applied by the engine -- do NOT also list them here.
TWAPartSystem.PartDefs = {
    ["HARMONIE_TheWayToAttack.TWA_Grip_LeatherWrap"] = {
        slot = "Grip", label = "IGUI_TWA_Part_Grip",
        bonuses = { baseSpeed = 2, enduranceMod = -0.1 },
    },
    ["HARMONIE_TheWayToAttack.TWA_Head_SpikedTip"] = {
        slot = "Head", label = "IGUI_TWA_Part_Head",
        bonuses = { minDamage = 1, maxDamage = 2, criticalChance = 10 },
    },
    ["HARMONIE_TheWayToAttack.TWA_Tactical_HandGuard"] = {
        slot = "Tactical", label = "IGUI_TWA_Part_Tactical",
        bonuses = { pushBackMod = 0.2 },
    },
    ["HARMONIE_TheWayToAttack.TWA_Weight_Counterweight"] = {
        slot = "Weight", label = "IGUI_TWA_Part_Weight",
        bonuses = { conditionMax = 10, knockdownMod = 0.5 },
    },
}

-- The installed WeaponPart for a slot (or nil).
function TWAPartSystem.GetPart(weapon, slot)
    if not weapon then return nil end
    return weapon:getWeaponPart(slot)
end

-- Sum the PartDefs bonus for `field` across all currently attached parts.
function TWAPartSystem.GetBonus(weapon, field)
    local total = 0
    for _, s in ipairs(TWAPartSystem.Slots) do
        local part = weapon:getWeaponPart(s.key)
        if part then
            local def = TWAPartSystem.PartDefs[part:getFullType()]
            if def and def.bonuses and def.bonuses[field] then
                total = total + def.bonuses[field]
            end
        end
    end
    return total
end

-- Getter overrides ------------------------------------------------------------
-- Only melee weapons carrying one of our parts get a bonus; every other item
-- (guns, vanilla weapons, other mods) returns the original value unchanged.
local HandWeapon = zombie.inventory.types.HandWeapon

local GETTER_PATCHES = {
    minDamage      = "getMinDamage",
    maxDamage      = "getMaxDamage",
    criticalChance = "getCriticalChance",
    baseSpeed      = "getBaseSpeed",
    enduranceMod   = "getEnduranceMod",
    pushBackMod    = "getPushBackMod",
    knockdownMod   = "getKnockdownMod",
    conditionMax   = "getConditionMax",
}

for field, getter in pairs(GETTER_PATCHES) do
    local ok, orig = pcall(function() return HandWeapon[getter] end)
    if ok and orig then
        HandWeapon[getter] = function(self)
            local base = orig(self)
            if not TWAPartSystem.IsMeleeWeapon(self) then
                return base
            end
            local ok2, bonus = pcall(TWAPartSystem.GetBonus, self, field)
            if not ok2 or bonus == 0 then return base end
            return base + bonus
        end
    end
end

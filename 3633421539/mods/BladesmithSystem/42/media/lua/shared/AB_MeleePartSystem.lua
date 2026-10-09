--============================================================================
-- BladesmithSystem — melee weapon part system (shared)
--
-- B42 stores melee and ranged weapons in the same Java class (HandWeapon), so
-- the engine's native WeaponPart storage works for melee too. Parts are real
-- `base:weaponpart` items attached via HandWeapon:attachWeaponPart and read back
-- with getWeaponPart. Installation / removal use the vanilla timed actions
-- ISUpgradeWeapon / ISRemoveWeaponUpgrade (see AB_MeleeUpgradeAction.lua).
--
-- Native WeaponPart modifiers (WeightModifier / MaxRangeModifier, declared in
-- the item script) are applied and persisted by the engine itself. Melee-only
-- stats that the native system does not expose are provided by overriding the
-- HandWeapon getters below, which sum PartDefs bonuses from the attached parts.
-- This is idempotent and correct across save/load; untouched weapons (guns,
-- vanilla melee, other mods) return the original value unchanged.
--============================================================================

ABMeleePartSystem = ABMeleePartSystem or {}

ABMeleePartSystem.Slots = {
    { key = "Grip",     label = "握柄改装" },
    { key = "Head",     label = "打击端头改装" },
    { key = "Tactical", label = "战术外挂" },
    { key = "Weight",   label = "配重/结构加固" },
}

ABMeleePartSystem.SlotLabels = {}
for _, s in ipairs(ABMeleePartSystem.Slots) do
    ABMeleePartSystem.SlotLabels[s.key] = s.label
end

-- Melee detection: HandWeapon (the only weapon class in B42) but not ranged.
function ABMeleePartSystem.IsMeleeWeapon(item)
    if not item then return false end
    if not instanceof(item, "HandWeapon") then return false end
    if item:isRanged() then return false end
    return true
end

-- Part definitions (single source of truth): fullType -> slot / label / bonuses.
--   bonuses: melee-only stats applied via the getter overrides below.
--   WeightModifier / MaxRangeModifier are native WeaponPart fields declared in
--   the item script and applied by the engine — do NOT also list them here.
ABMeleePartSystem.PartDefs = {
    ["Base.ABGrip_LeatherWrap"] = {
        slot = "Grip", label = "皮革缠柄",
        bonuses = { baseSpeed = 2, enduranceMod = -0.1 },
    },
    ["Base.ABHead_SpikedTip"] = {
        slot = "Head", label = "尖刺打击端头",
        bonuses = { minDamage = 1, maxDamage = 2, criticalChance = 10 },
    },
    ["Base.ABTactical_HandGuard"] = {
        slot = "Tactical", label = "战术护手",
        bonuses = { pushBackMod = 0.2 },
    },
    ["Base.ABWeight_Counterweight"] = {
        slot = "Weight", label = "平衡配重块",
        bonuses = { conditionMax = 10, knockdownMod = 0.5 },
    },
}

-- The installed WeaponPart for a slot (or nil).
function ABMeleePartSystem.GetPart(weapon, slot)
    if not weapon then return nil end
    return weapon:getWeaponPart(slot)
end

-- Sum the PartDefs bonus for `field` across all currently attached parts.
function ABMeleePartSystem.GetBonus(weapon, field)
    local total = 0
    for _, s in ipairs(ABMeleePartSystem.Slots) do
        local part = weapon:getWeaponPart(s.key)
        if part then
            local def = ABMeleePartSystem.PartDefs[part:getFullType()]
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
            if not ABMeleePartSystem.IsMeleeWeapon(self) then
                return base
            end
            local ok2, bonus = pcall(ABMeleePartSystem.GetBonus, self, field)
            if not ok2 or bonus == 0 then return base end
            return base + bonus
        end
    end
end

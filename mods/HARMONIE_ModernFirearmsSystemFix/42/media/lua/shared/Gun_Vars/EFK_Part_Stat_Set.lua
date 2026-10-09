-- MFS B42: weapon-part stat bonuses for CriticalChance / CritDmgMultiplier /
-- CyclicRateMultiplier.
--
-- WeaponPart has no native fields for these three stats, so their values live
-- here in a Lua config table keyed by the part's script type (getType(), e.g.
-- "silencer_cat"), mirroring the AWCWF_SilencerSet pattern.  A part entry may
-- set any combination of three additive deltas:
--   CriticalChance       - percentage points added to the weapon's crit chance
--   CritDmgMultiplier    - multiplier delta added to crit damage (0.5 => +50%)
--   CyclicRateMultiplier - delta added to the calibrated cyclic fire-rate value
--
-- Values are additive: each part's value is summed over all installed parts and
-- added to the weapon's base (script) value.  Omit a key (or set 0) to leave
-- that stat unchanged.  The recompute reads the base from a fresh instance of
-- the weapon's script type every time, so the result is idempotent no matter
-- how many attach / detach / equip passes run.
-- 0908 add Romeo5_H/L and Leupold CQBSS
AWCWF_PartStatSet = AWCWF_PartStatSet or {
    -- Scope (PartType = Scope) crit / crit-damage bonuses, tiered by zoom.
    --   CriticalChance    - percentage points added to crit chance
    --   CritDmgMultiplier - multiplier delta added to crit damage (0.5 => +50%)

    -- Low magnification (red dot / holo / iron sights):
    ["VortexSight"]   = { CriticalChance = 5,  CritDmgMultiplier = 0.25 },
    ["Carryhandle"]   = { CriticalChance = 1,  CritDmgMultiplier = 0.15 },
    ["WaltherMRS_1"]  = { CriticalChance = 3,  CritDmgMultiplier = 0.35 },
    ["MZ_UH1"]        = { CriticalChance = 5,  CritDmgMultiplier = 0.25 },
    ["WaltherMRS_2"]  = { CriticalChance = 4,  CritDmgMultiplier = 0.25 },
    ["HD511a_cat"]    = { CriticalChance = 5,  CritDmgMultiplier = 0.25 },
    ["MZ_LTHY"]       = { CriticalChance = 5,  CritDmgMultiplier = 0.25 },
    ["558holo"]       = { CriticalChance = 3,  CritDmgMultiplier = 0.35 },
    ["MZ_HCO"]        = { CriticalChance = 5,  CritDmgMultiplier = 0.25 },
    ["Romeo5_H_reddot"]  = { CriticalChance = 5,  CritDmgMultiplier = 0.25 },
    ["Romeo5_L_reddot"]  = { CriticalChance = 5,  CritDmgMultiplier = 0.25 },

    -- Mid magnification (4x fixed / ACOG):
    ["PEScope_cat"]   = { CriticalChance = 10, CritDmgMultiplier = 0.5 },
    ["PSO_1_cat"]     = { CriticalChance = 10, CritDmgMultiplier = 0.5 },
    ["Unertl8X_cat"]  = { CriticalChance = 10, CritDmgMultiplier = 0.5 },
    ["HAMR_cat"]      = { CriticalChance = 13, CritDmgMultiplier = 0.4 },
    ["TA11_4X_Scope"] = { CriticalChance = 15, CritDmgMultiplier = 0.5 },
    ["COMPM4"]        = { CriticalChance = 14, CritDmgMultiplier = 0.55 },
    ["CQBR_ACOG_RU"]  = { CriticalChance = 10, CritDmgMultiplier = 0.6 },

    -- High magnification (sniper / variable long-range):
    ["MZ_paoduijing"] = { CriticalChance = 25, CritDmgMultiplier = 0.65 },
    ["Snipex24"]      = { CriticalChance = 35, CritDmgMultiplier = 0.15 },
    ["ATACR"]         = { CriticalChance = 19, CritDmgMultiplier = 0.75 },
    ["XM157_cat"]     = { CriticalChance = 27, CritDmgMultiplier = 0.65 },
    ["MZ_M6D"]     = { CriticalChance = 11, CritDmgMultiplier = 0.65 },
    ["lee_enfield_scope"]     = { CriticalChance = 17, CritDmgMultiplier = 0.75 },
    ["MagpulStock"]     = { CriticalChance = 8},
    ["leupold"]     = { CriticalChance = 5},
    ["G33_cat"]     = { CritDmgMultiplier = 0.1},
    ["Leupold_Mk8_CQBSS"] = { CriticalChance = 19, CritDmgMultiplier = 0.75 },
}

-- Resolve the stat bonus for a single part.  Accepts a WeaponPart instance or a
-- bare part type string.  Returns the configured bonus table, or nil if none.
function AWCWF_GetPartStatBonus(part)
    if not AWCWF_PartStatSet then return nil end
    local partType
    if type(part) == "string" then
        partType = part
    elseif part and part.getType then
        partType = part:getType()
    end
    if not partType then return nil end
    return AWCWF_PartStatSet[partType]
end

-- Enumerate the parts installed on a weapon without relying on the (disabled)
-- AWCWF_AdditionalParts metatable patches.  The base HandWeapon.getAllWeaponParts()
-- returns the real installed WeaponPart list; fall back to the mod's known slot
-- list only if that accessor is unavailable.
local function getInstalledParts(weapon)
    local parts = {}
    if weapon.getAllWeaponParts then
        local ok, list = pcall(function() return weapon:getAllWeaponParts() end)
        if ok and list and list.size then
            for i = 0, list:size() - 1 do
                local part = list:get(i)
                if part then parts[#parts + 1] = part end
            end
            return parts
        end
    end
    local partlist = AWCWF_AdditionalParts and AWCWF_AdditionalParts.partlist
    if partlist then
        for _, slot in ipairs(partlist) do
            local part = weapon:getWeaponPart(slot)
            if part then parts[#parts + 1] = part end
        end
    end
    return parts
end

-- Recompute the weapon's crit / crit-damage / cyclic-part-bonus state from its
-- script base plus all installed parts.  Idempotent; safe to call repeatedly.
-- The cyclic fire-rate value itself is owned by the RPM calibration system
-- (client/WeaponAbility/ExactAutomaticRPM.lua); here we only store the summed
-- part bonus into ModData for that system to fold into the calibrated cyclic.
function AWCWF_ApplyPartStats(playerObj, weapon)
    if not weapon or not weapon:IsWeapon() or not weapon:isRanged() then
        return
    end

    local fullType = weapon:getFullType()
    if not fullType or fullType == "" then return end

    -- The script Item has no getters for criticalChance / critDmgMultiplier, so
    -- read the base values from a fresh instance of the weapon's script type.
    local origin = instanceItem(fullType)
    if not origin then return end

    local baseCrit = origin.getCriticalChance and origin:getCriticalChance() or 0
    local baseCritDmg = origin.getCriticalDamageMultiplier and origin:getCriticalDamageMultiplier() or 0

    local critBonus = 0
    local critDmgBonus = 0
    local cyclicBonus = 0

    for _, part in ipairs(getInstalledParts(weapon)) do
        local bonus = AWCWF_GetPartStatBonus(part)
        if bonus then
            critBonus = critBonus + (bonus.CriticalChance or 0)
            critDmgBonus = critDmgBonus + (bonus.CritDmgMultiplier or 0)
            cyclicBonus = cyclicBonus + (bonus.CyclicRateMultiplier or 0)
        end
    end

    if weapon.setCriticalChance then
        weapon:setCriticalChance(baseCrit + critBonus)
    end
    if weapon.setCriticalDamageMultiplier then
        weapon:setCriticalDamageMultiplier(baseCritDmg + critDmgBonus)
    end

    local modData = weapon:getModData()
    if cyclicBonus ~= 0 then
        modData.AWCWF_PartCyclicBonus = cyclicBonus
    else
        modData.AWCWF_PartCyclicBonus = nil
    end
end

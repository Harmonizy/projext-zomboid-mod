--[[
    HARMONIE - From Garden to Plate
    Applies each vitamin's deficiency penalty while currently afflicted
    (see the hysteresis note in HARMONIE_VitaminConfig.lua). Every handler
    is a custom Lua effect themed after a real vanilla Trait's behavior --
    deliberately NOT granting the real trait itself (character:
    getCharacterTraits():add/remove is a real, confirmed-working
    mechanism, same one vanilla's own XpUpdate.lua uses to swap WEAK/
    FEEBLE/STOUT/STRONG in and out live as Strength levels up -- but
    intentionally not used here to keep the vitamin system fully separate
    from the actual trait system). See HARMONIE_VitaminConfig.lua for the
    full reasoning behind each one's specific mechanism and how closely it
    could match the real trait given what's actually reachable from Lua --
    summary:
      A (Short Sighted)  -- CharacterStat.PANIC kept at a floor, every
                             10 seconds (ApplyCritical below is NOT used
                             for this one -- see MaintainStatEffect)
      B (Disorganized)   -- Arm+Back muscle strain, once/day, stacking
                             (its real effect, reduced bag/container
                             capacity, has NO Lua hook at all -- see
                             HARMONIE_VitaminConfig.lua)
      C (Thin-Skinned)   -- extends BleedingTime on active wounds,
                             once/day, stacking
      D (Asthmatic)      -- CharacterStat.ENDURANCE kept at a ceiling,
                             every 10 seconds (see MaintainStatEffect)
      E (All Thumbs)     -- CharacterStat.STRESS kept at a floor, every
                             10 seconds (see MaintainStatEffect), PLUS the
                             one real mechanic that WAS found in Lua:
                             HARMONIE_ClumsyHandsHook.lua forces
                             stopOnWalk=true during crafting while
                             afflicted, exactly mirroring ISHandcraftAction
                             .lua's own character:hasTrait(CharacterTrait.
                             ALL_THUMBS) check, without touching the trait
      K (Slow Healer)    -- extends DeepWoundTime/FractureTime/BurnTime
                             on active wounds, once/day, stacking

    B/C/K use ApplyCritical, a flat per-day dose that stacks without limit
    for as long as the deficiency persists. A/D/E use MaintainStatEffect
    instead, continuously re-enforced every 10 seconds rather than dosed
    once per day -- see that function's own comment for why: PANIC,
    ENDURANCE, and STRESS all naturally regenerate/decay back toward their
    own baseline on their own, so a single daily nudge would likely be
    erased before anyone noticed it.

    Both are no-ops while the vitamin has banked pause days (HARMONIE_GTP.
    VitData.GetPauseDays > 0) -- gained from eating well, or +1 per
    vitamin from taking Base.PillsVitamins with no Reserve gain (see
    HARMONIE_PillsHook.lua). That only silences the SYMPTOM -- Reserve and
    the affliction flag itself are untouched, so the penalty comes right
    back the moment the banked day(s) run out if the underlying deficiency
    was never actually fixed by eating.

    Dialogue is entirely separate -- handled by MaybeSaySymptomReminder
    below, checked every 6 GAME hours, picking ONE random currently-
    afflicted vitamin to comment on each time, so a character with several
    vitamins critical at once never says several symptom lines back to
    back. Worded as something a real person would notice about THEMSELVES
    (dry eyes, sore gums, out of breath...), never naming the vitamin,
    since a survivor has no lab to tell them that's the cause.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.VitEffects = {}
local VitEffects = HARMONIE_GTP.VitEffects

-- Each accessor is an explicit {get, set} pair of real bodyPart method
-- calls -- NOT built from a string ("get" .. name) and dynamically
-- indexed, since that dynamic-dispatch pattern has zero precedent
-- anywhere in vanilla's own Lua (grepped across the whole game) and
-- isn't a risk worth taking on a Java-bridged object.
local BleedingTimeAccessor = {
    get = function(bp) return bp:getBleedingTime() end,
    set = function(bp, v) bp:setBleedingTime(v) end,
}
local DeepWoundTimeAccessor = {
    get = function(bp) return bp:getDeepWoundTime() end,
    set = function(bp, v) bp:setDeepWoundTime(v) end,
}
local FractureTimeAccessor = {
    get = function(bp) return bp:getFractureTime() end,
    set = function(bp, v) bp:setFractureTime(v) end,
}
local BurnTimeAccessor = {
    get = function(bp) return bp:getBurnTime() end,
    set = function(bp, v) bp:setBurnTime(v) end,
}

-- Extends each accessor's current value by `amount` on every body part
-- where it's already active (> 0) -- a no-op for body parts with nothing
-- of that kind going on. Shared by the C (BleedingTime) and K
-- (DeepWoundTime/FractureTime/BurnTime) handlers.
local function extendActiveWoundTimers(character, amount, accessors)
    local bodyParts = character:getBodyDamage():getBodyParts()
    for i = 0, bodyParts:size() - 1 do
        local bodyPart = bodyParts:get(i)
        for _, accessor in ipairs(accessors) do
            local current = accessor.get(bodyPart)
            if current and current > 0 then
                accessor.set(bodyPart, current + amount)
            end
        end
    end
end

--[[
    Flavor lines the character says to themselves the day a vitamin's
    penalty actually applies. Two different pools depending on whether
    the character actually has the medical knowledge to know what's
    wrong:

      - Below Doctor level (assessmentRequiredFirstAid + 1): worded as a
        real-world symptom the character just NOTICES (dry eyes, sore
        gums, aching bones...), never naming the vitamin, since an
        ordinary survivor has no lab to tell them that's the cause. One
        of the variants in each list leans a little wry/darkly funny --
        not every line needs to be grim.
      - Above that Doctor level (the same threshold that unlocks reading
        the Nutrition Assessment window, see HARMONIE_VitaminConfig.lua's
        assessmentRequiredFirstAid): the character has enough medical
        training to actually recognize and name the deficiency, so these
        lines say so directly.

    Each list has a few variants so it doesn't feel like the same canned
    line every time; sayRandomSymptom below picks one at random each
    time.
]]--
local SymptomLineKeys = {
    A = {"IGUI_HARMONIE_Symptom_A_1", "IGUI_HARMONIE_Symptom_A_2", "IGUI_HARMONIE_Symptom_A_Funny"},
    B = {"IGUI_HARMONIE_Symptom_B_1", "IGUI_HARMONIE_Symptom_B_2", "IGUI_HARMONIE_Symptom_B_Funny"},
    C = {"IGUI_HARMONIE_Symptom_C_1", "IGUI_HARMONIE_Symptom_C_2", "IGUI_HARMONIE_Symptom_C_Funny"},
    D = {"IGUI_HARMONIE_Symptom_D_1", "IGUI_HARMONIE_Symptom_D_2", "IGUI_HARMONIE_Symptom_D_Funny"},
    E = {"IGUI_HARMONIE_Symptom_E_1", "IGUI_HARMONIE_Symptom_E_2", "IGUI_HARMONIE_Symptom_E_Funny"},
    K = {"IGUI_HARMONIE_Symptom_K_1", "IGUI_HARMONIE_Symptom_K_2", "IGUI_HARMONIE_Symptom_K_Funny"},
}

local DoctorSymptomLineKeys = {
    A = {"IGUI_HARMONIE_DoctorSymptom_A_1", "IGUI_HARMONIE_DoctorSymptom_A_2"},
    B = {"IGUI_HARMONIE_DoctorSymptom_B_1", "IGUI_HARMONIE_DoctorSymptom_B_2"},
    C = {"IGUI_HARMONIE_DoctorSymptom_C_1", "IGUI_HARMONIE_DoctorSymptom_C_2"},
    D = {"IGUI_HARMONIE_DoctorSymptom_D_1", "IGUI_HARMONIE_DoctorSymptom_D_2"},
    E = {"IGUI_HARMONIE_DoctorSymptom_E_1", "IGUI_HARMONIE_DoctorSymptom_E_2"},
    K = {"IGUI_HARMONIE_DoctorSymptom_K_1", "IGUI_HARMONIE_DoctorSymptom_K_2"},
}

local function sayRandomSymptom(character, vit)
    if not character.Say then return end
    local isDoctor = character:getPerkLevel(Perks.Doctor) > HARMONIE_GTP.Config.assessmentRequiredFirstAid
    local pool = isDoctor and DoctorSymptomLineKeys or SymptomLineKeys
    local keys = pool[vit]
    if not keys then return end
    character:Say(getText(keys[ZombRand(#keys) + 1]))
end

--[[
    The relief-side counterpart to the symptom lines above -- said once
    when a vitamin's Reserve climbs back up to Sufficient after having
    been afflicted (see VitData.RefreshAffliction's return value and
    HARMONIE_VitaminChecker.lua, which calls this at most once per check
    even if several vitamins recover in the same 10-second tick, so
    eating one big varied meal doesn't make the character say three
    different "feeling better" lines back to back).
]]--
local RECOVERY_CHANCE_PERCENT = 80
local RecoveryLineKeys = {
    "IGUI_HARMONIE_Recovered_1",
    "IGUI_HARMONIE_Recovered_2",
    "IGUI_HARMONIE_Recovered_3",
    "IGUI_HARMONIE_Recovered_Funny",
}

function VitEffects.SayRecovered(character)
    if not character or not character.Say then return end
    if ZombRand(100) >= RECOVERY_CHANCE_PERCENT then return end
    character:Say(getText(RecoveryLineKeys[ZombRand(#RecoveryLineKeys) + 1]))
end

-- effect handlers keyed by vitamin letter for the DAILY-STACKING vitamins
-- only (B, C, K) -- see the file header and HARMONIE_VitaminConfig.lua
-- for what real trait each one is themed after and why. A/D/E are NOT
-- here: they're maintained continuously by MaintainStatEffect below
-- instead of dosed once per day, since PANIC/ENDURANCE/STRESS all
-- naturally regenerate/decay on their own and a one-shot daily add would
-- likely get erased before it was ever noticed (see HARMONIE_
-- VitaminConfig.lua's Affliction model note for the full reasoning).
local Handlers = {
    B = function(character, cfg)
        local amount = cfg.amount * HARMONIE_GTP.Config.effectMultiplier
        character:addArmMuscleStrain(amount)
        character:addBackMuscleStrain(amount)
    end,

    C = function(character, cfg)
        extendActiveWoundTimers(character, cfg.amount * HARMONIE_GTP.Config.effectMultiplier, {BleedingTimeAccessor})
    end,

    K = function(character, cfg)
        extendActiveWoundTimers(character, cfg.amount * HARMONIE_GTP.Config.effectMultiplier,
            {DeepWoundTimeAccessor, FractureTimeAccessor, BurnTimeAccessor})
    end,
}

function VitEffects.ApplyCritical(character, vit)
    if not HARMONIE_GTP.Config.effectsEnabled then return end
    if HARMONIE_GTP.VitData.GetPauseDays(character, vit) > 0 then return end
    local cfg = HARMONIE_GTP.Config.effects[vit]
    local handler = Handlers[vit]
    if cfg and handler then
        handler(character, cfg)
    end
end

-- A/D/E's CharacterStat mapping for MaintainStatEffect below -- `kind`
-- says whether cfg.floor or cfg.ceiling applies to that stat.
local StatEffects = {
    A = { stat = "PANIC",     kind = "floor" },
    D = { stat = "ENDURANCE", kind = "ceiling" },
    E = { stat = "STRESS",    kind = "floor" },
}

--[[
    Checked every 10 seconds by HARMONIE_VitaminChecker.lua for A/D/E
    specifically -- CONTINUOUSLY re-enforces a floor or ceiling on the
    mapped CharacterStat while afflicted-and-not-pause-shielded, instead
    of ApplyCritical's once-a-day dose. This exists because PANIC,
    ENDURANCE, and STRESS all naturally regenerate/decay back toward
    their own baseline on their own -- a single daily nudge to any of
    these would very likely be completely erased by vanilla's own regen
    within the same day (confirmed the hard way with Vitamin B, which
    used to drain ENDURANCE the same one-shot way and the -0.2 hit was
    imperceptible against ordinary rest regen -- that's why B switched to
    muscle strain instead, which doesn't self-heal from idling).
    Maintaining the floor/ceiling every tick means the effect is always
    genuinely present for as long as the deficiency lasts, and stops
    touching the stat entirely -- letting vanilla fully take back over --
    the instant it's no longer needed. Idempotent and cheap: only calls
    :set() when the stat has actually drifted past the line.
]]--
function VitEffects.MaintainStatEffect(character, vit)
    if not HARMONIE_GTP.Config.effectsEnabled then return end

    local mapping = StatEffects[vit]
    local cfg = HARMONIE_GTP.Config.effects[vit]
    if not mapping or not cfg then return end

    local afflicted = HARMONIE_GTP.VitData.IsAfflicted(character, vit)
            and HARMONIE_GTP.VitData.GetPauseDays(character, vit) <= 0
    if not afflicted then return end

    local stat = CharacterStat[mapping.stat]
    local stats = character:getStats()
    local current = stats:get(stat)

    if mapping.kind == "floor" then
        local floor = cfg.floor * HARMONIE_GTP.Config.effectMultiplier
        if current < floor then
            stats:set(stat, floor)
        end
    else
        local ceiling = 1 - (1 - cfg.ceiling) * HARMONIE_GTP.Config.effectMultiplier
        if current > ceiling then
            stats:set(stat, ceiling)
        end
    end
end

--[[
    Checked every 6 GAME hours (see HARMONIE_VitaminChecker.lua's
    getSixHourBlockIndex) -- completely decoupled from ApplyCritical's own
    once-a-day timing, since that's what caused several symptom lines to
    fire back to back the moment more than one vitamin crossed into
    Critical on the same day. Instead: gather every vitamin CURRENTLY
    afflicted and not pause-day-shielded, pick exactly ONE at random, and
    say only that one's line -- so a character with three vitamins
    critical at once still only ever says one thing per 6-hour block, and
    which one comes up is random rather than always the same vitamin
    first.
]]--
function VitEffects.MaybeSaySymptomReminder(character, block)
    if not character or not character.Say then return end
    if HARMONIE_GTP.VitData.GetLastSymptomBlock(character) == block then return end

    local candidates = {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if HARMONIE_GTP.VitData.IsAfflicted(character, vit)
                and HARMONIE_GTP.VitData.GetPauseDays(character, vit) <= 0 then
            table.insert(candidates, vit)
        end
    end
    if #candidates == 0 then return end

    HARMONIE_GTP.VitData.SetLastSymptomBlock(character, block)
    sayRandomSymptom(character, candidates[ZombRand(#candidates) + 1])
end

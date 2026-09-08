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
    summary (ALL SIX are now continuously re-enforced every 10 seconds by
    HARMONIE_VitaminChecker.lua rather than dosed once per day -- see the
    note below for why the once-a-day approach was retired entirely):
      A -- CharacterStat.UNHAPPINESS kept at a floor (MaintainStatEffect)
      B (Disorganized)   -- Arm+Back+Torso Stiffness kept at a floor
                             (MaintainStiffnessFloor) -- its real effect,
                             reduced bag/container capacity, has NO Lua
                             hook at all, see HARMONIE_VitaminConfig.lua
      C -- CharacterStat.SICKNESS kept at a floor (MaintainStatEffect)
      D (Asthmatic)      -- CharacterStat.ENDURANCE kept at a ceiling
                             (MaintainStatEffect)
      E (All Thumbs)     -- CharacterStat.STRESS kept at a floor
                             (MaintainStatEffect), PLUS the one real
                             mechanic that WAS found in Lua:
                             HARMONIE_ClumsyHandsHook.lua forces
                             stopOnWalk=true during crafting while
                             afflicted, exactly mirroring ISHandcraftAction
                             .lua's own character:hasTrait(CharacterTrait.
                             ALL_THUMBS) check, without touching the trait
      K -- BleedingTime on active wounds kept at a floor
           (MaintainBleedingFloor) -- a wound never fully closes while
           afflicted, bandaged or not (this was C's original mechanic;
           swapped onto K since impaired blood clotting is Vitamin K's
           actual real-world deficiency symptom, not slow-healing
           fractures/burns -- see HARMONIE_VitaminConfig.lua), PLUS
           occasional spontaneous nosebleeds/gum bleeding with no wound
           required at all (MaybeTriggerNosebleed, checked every 6 game
           hours) -- added because MaintainBleedingFloor alone only ever
           prolongs an EXISTING wound, so a character who simply never
           gets hit would otherwise feel nothing from Critical Vitamin K

    Every vitamin used to split into two families: B/C/K got a flat daily
    `amount` added once per Critical day via ApplyCritical, stacking
    without limit; A/D/E got a continuous floor/ceiling instead. That
    split was retired -- B and C's daily doses turned out to have the
    exact same "erased before anyone felt it" problem A/D/E were already
    designed around: B's muscle-strain/Stiffness naturally decays on its
    own when not exercising, and C's old BleedingTime target drains 10x
    faster while bandaged (confirmed straight from BodyPart.class), so a
    bandaged character could heal off an entire day's dose within a
    couple of real-time hours. Every vitamin now uses the same
    continuously-re-enforced floor/ceiling pattern: MaintainStatEffect for
    A/C/D/E's CharacterStat, MaintainStiffnessFloor for B's per-body-part
    Stiffness, MaintainBleedingFloor for K's per-body-part BleedingTime --
    see each function's own comment for specifics.

    All of them are no-ops while the vitamin has at least 1 WHOLE banked
    pause day (HARMONIE_GTP.VitData.GetPauseDays >= 1 -- a leftover
    fraction below 1 doesn't shield anything yet, just keeps accumulating,
    see VitData.ApplyDailyTick) -- gained from eating well, or +1 per
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

-- A/C/D/E's CharacterStat mapping for MaintainStatEffect below -- `kind`
-- says whether cfg.floor or cfg.ceiling applies to that stat.
local StatEffects = {
    A = { stat = "UNHAPPINESS", kind = "floor" },
    C = { stat = "SICKNESS",  kind = "floor" },
    D = { stat = "ENDURANCE", kind = "ceiling" },
    E = { stat = "STRESS",    kind = "floor" },
}

--[[
    Checked every 10 seconds by HARMONIE_VitaminChecker.lua for A/C/D/E
    specifically -- CONTINUOUSLY re-enforces a floor or ceiling on the
    mapped CharacterStat while afflicted-and-not-pause-shielded, instead
    of a once-a-day dose. This exists because UNHAPPINESS, SICKNESS,
    ENDURANCE, and STRESS all naturally regenerate/decay back toward
    their own baseline on their own -- a single daily nudge to any of
    these would
    very likely be completely erased by vanilla's own regen within the
    same day (confirmed the hard way with Vitamin B, which used to drain
    ENDURANCE the same one-shot way and the -0.2 hit was imperceptible
    against ordinary rest regen -- that's why B switched to muscle
    strain/Stiffness instead, which is maintained the same continuous way
    below in MaintainStiffnessFloor since it turned out to have the exact
    same problem).
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

    -- >= 1, not > 0: a banked pause day only actually shields anything
    -- once a WHOLE day is banked (see VitData.ApplyDailyTick, which only
    -- ever consumes exactly 1 at a time) -- a leftover fraction like 0.3
    -- from a single snack shouldn't cancel the penalty outright, just
    -- keep accumulating toward the next whole day.
    local afflicted = HARMONIE_GTP.VitData.IsAfflicted(character, vit)
            and HARMONIE_GTP.VitData.GetPauseDays(character, vit) < 1
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
    Checked every 10 seconds by HARMONIE_VitaminChecker.lua for K
    specifically (this was C's original mechanic -- swapped onto K, whose
    real deficiency is impaired blood clotting, a much closer match than
    K's previous DeepWoundTime/FractureTime/BurnTime theming) -- same
    continuous-enforcement family as MaintainStatEffect above, just on a
    per-body-part wound timer instead of a CharacterStat. While
    afflicted-and-not-pause-shielded, any body part that is CURRENTLY
    bleeding (BleedingTime > 0) gets its BleedingTime pushed back up to
    cfg.floor whenever it drops below that -- so the wound never actually
    finishes closing (vanilla clears it and grants Bandage/Stitch XP once
    BleedingTime reaches 0) for as long as the deficiency lasts,
    REGARDLESS of bandaging: confirmed from BodyPart.class that a bandage
    only makes BleedingTime drain 10x faster, it doesn't stop the drain
    outright, so re-flooring it every 10 real seconds defeats that
    speed-up the same way it would defeat any decay rate. Never STARTS a
    bleed on a part that isn't already bleeding on its own (guarded by the
    "> 0" check) -- that's MaybeTriggerNosebleed's job below, the only
    place this file ever starts a NEW bleed rather than prolonging an
    existing one.
]]--
function VitEffects.MaintainBleedingFloor(character)
    if not HARMONIE_GTP.Config.effectsEnabled then return end

    local cfg = HARMONIE_GTP.Config.effects.K
    if not cfg or not cfg.floor then return end

    local afflicted = HARMONIE_GTP.VitData.IsAfflicted(character, "K")
            and HARMONIE_GTP.VitData.GetPauseDays(character, "K") < 1
    if not afflicted then return end

    local floor = cfg.floor * HARMONIE_GTP.Config.effectMultiplier
    local bodyParts = character:getBodyDamage():getBodyParts()
    for i = 0, bodyParts:size() - 1 do
        local bodyPart = bodyParts:get(i)
        local current = bodyPart:getBleedingTime()
        if current and current > 0 and current < floor then
            bodyPart:setBleedingTime(floor)
        end
    end
end

--[[
    Checked every 6 GAME hours (same block granularity as
    MaybeSaySymptomReminder, tracked separately via VitData.
    GetLastNosebleedBlock so the two don't interfere with each other's
    once-per-block gating) -- addresses a real gap in K's original design:
    MaintainBleedingFloor above only ever PROLONGS a wound that's already
    bleeding from combat/an accident, so a careful character who simply
    never gets hit would feel literally nothing from a Critical Vitamin K
    deficiency. Real Vitamin K deficiency's hallmark symptoms include
    spontaneous bleeding with no injury at all -- easy bruising, bleeding
    gums, nosebleeds -- so this occasionally starts a small bleed on the
    Head body part (nosebleed/gum bleed) purely from the deficiency
    itself, no wound required. NOSEBLEED_CHANCE_PERCENT keeps it from firing
    literally every single eligible block (feels more like a random
    "it happens sometimes" symptom, not a metronome); skipped entirely if
    the Head is already bleeding for any reason, so it never doubles up
    with a real combat wound MaintainBleedingFloor is already prolonging.

    IMPORTANT (confirmed the hard way -- an earlier version called
    bodyPart:setBleedingTime() directly, which a real in-game test showed
    has NO visible effect at all): setBleedingTime() only sets the raw
    internal timer -- it does NOT mark the body part as an actual wound
    (scratched()/isCut()/etc all stay false), so nothing shows up on the
    character model, the Health panel, or the Injured moodle; vanilla's
    UI has nothing to recognize as "there's a wound here." The correct
    two-step sequence, confirmed straight from BodyPart.class (this is
    the exact same path vanilla itself uses when a zombie scratches a
    player): bodyPart:setScratched(true, true) creates a REAL, visible
    Scratch wound (rolls a random ScratchTime, clears any stale bandage/
    stitch state) -- the second `true` skips setScratched's own
    zombie-infection roll, since a spontaneous nosebleed obviously
    shouldn't ever be able to infect someone. Then bodyPart:
    generateBleeding() is vanilla's own real function for deriving a
    realistic BleedingTime FROM whatever wounds are currently present
    (scratched, cut, burnt, etc, each contributing their own random
    range) -- since scratched() is now true, this rolls a genuine
    bleeding amount off the ScratchTime just set, the same way a real
    combat scratch would. Once BleedingTime is real and > 0,
    MaintainBleedingFloor above takes over keeping it going every 10
    seconds exactly like any other wound.
]]--
local NOSEBLEED_CHANCE_PERCENT = 40
local NosebleedLineKeys = {
    "IGUI_HARMONIE_NosebleedK_1",
    "IGUI_HARMONIE_NosebleedK_2",
}

function VitEffects.MaybeTriggerNosebleed(character, block)
    if not HARMONIE_GTP.Config.effectsEnabled then return end

    local afflicted = HARMONIE_GTP.VitData.IsAfflicted(character, "K")
            and HARMONIE_GTP.VitData.GetPauseDays(character, "K") < 1
    if not afflicted then return end

    if HARMONIE_GTP.VitData.GetLastNosebleedBlock(character) == block then return end
    HARMONIE_GTP.VitData.SetLastNosebleedBlock(character, block)

    if ZombRand(100) >= NOSEBLEED_CHANCE_PERCENT then return end

    local headPart = character:getBodyDamage():getBodyPart(BodyPartType.Head)
    if not headPart or headPart:getBleedingTime() > 0 then return end

    headPart:setScratched(true, true)
    headPart:generateBleeding()

    if character.Say then
        character:Say(getText(NosebleedLineKeys[ZombRand(#NosebleedLineKeys) + 1]))
    end
end

--[[
    Checked every 10 seconds by HARMONIE_VitaminChecker.lua for B
    specifically -- same continuous-enforcement family as the two
    functions above, on the specific body parts vanilla's own
    addArmMuscleStrain/addBackMuscleStrain/addLeftArmMuscleStrain target
    (confirmed straight from IsoGameCharacter.class's bytecode: Hand_R/
    ForeArm_R/UpperArm_R, Hand_L/ForeArm_L/UpperArm_L, and Torso_Upper/
    Torso_Lower) -- while afflicted-and-not-pause-shielded, any of those
    parts below cfg.floor gets its Stiffness (0-100 scale, confirmed via
    BodyPart.class) pushed back up to it. Stiffness decays on its own
    whenever the character isn't actively exercising (see BodyPart
    .class's own Update loop), which is exactly the "erased before it's
    felt" problem this file's header describes -- re-flooring it
    continuously is what keeps it actually present.
]]--
local StiffnessBodyParts = {
    "Hand_R", "ForeArm_R", "UpperArm_R",
    "Hand_L", "ForeArm_L", "UpperArm_L",
    "Torso_Upper", "Torso_Lower",
}

function VitEffects.MaintainStiffnessFloor(character)
    if not HARMONIE_GTP.Config.effectsEnabled then return end

    local cfg = HARMONIE_GTP.Config.effects.B
    if not cfg or not cfg.floor then return end

    local afflicted = HARMONIE_GTP.VitData.IsAfflicted(character, "B")
            and HARMONIE_GTP.VitData.GetPauseDays(character, "B") < 1
    if not afflicted then return end

    local floor = cfg.floor * HARMONIE_GTP.Config.effectMultiplier
    local bodyDamage = character:getBodyDamage()
    for _, partName in ipairs(StiffnessBodyParts) do
        local bodyPart = bodyDamage:getBodyPart(BodyPartType[partName])
        if bodyPart and bodyPart:getStiffness() < floor then
            bodyPart:setStiffness(floor)
        end
    end
end

--[[
    Checked every 6 GAME hours (see HARMONIE_VitaminChecker.lua's
    getSixHourBlockIndex) -- completely decoupled from the continuous
    effect maintenance above, since firing dialogue on the same schedule
    as the penalty itself is what used to cause several symptom lines to
    fire back to back the moment more than one vitamin crossed into
    Critical at once. Instead: gather every vitamin CURRENTLY
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
                and HARMONIE_GTP.VitData.GetPauseDays(character, vit) < 1 then
            table.insert(candidates, vit)
        end
    end
    if #candidates == 0 then return end

    HARMONIE_GTP.VitData.SetLastSymptomBlock(character, block)
    sayRandomSymptom(character, candidates[ZombRand(#candidates) + 1])
end

--[[
    HARMONIE - From Garden to Plate
    Core tuning constants for the vitamin system.

    Reserve/decay model:
      - Every vitamin has a real-world-approximate Daily Requirement.
      - Eating food grants Reserve = (amount eaten / Daily Requirement * 100) / reserveGainDivisor,
        i.e. hitting 100% of a vitamin's daily requirement in one day is worth
        +10 Reserve (out of the 0-100 scale) at the default divisor.
      - Reserve decays by decayPerDay once per in-game day.
      - Every reservePerPauseDay points of Reserve gained banks 1 "pause
        day": while a vitamin has banked pause days, that day's decay is
        skipped instead (1 pause day consumed per day). Eating regularly
        keeps you permanently ahead of the decay; stopping lets the bank
        drain and decay resume.

    Affliction model (hysteresis):
      - Crossing below criticalThreshold marks that vitamin "afflicted".
      - Once afflicted, the critical-band penalty keeps applying even if
        Reserve ticks back above criticalThreshold, right up until it
        reaches sufficientThreshold ("Sufficient" band) -- not just out of
        "Critical". This matches a real deficiency: you don't feel better
        the moment you're technically no longer in the red.
      - EVERY vitamin's penalty is a `floor`/`ceiling` maintained
        CONTINUOUSLY every 10 seconds by HARMONIE_VitaminChecker.lua --
        VitEffects.MaintainStatEffect for A/C/D/E's CharacterStat,
        VitEffects.MaintainStiffnessFloor for B's per-body-part Stiffness,
        VitEffects.MaintainBleedingFloor for K's per-body-part
        BleedingTime -- rather than applied once per day. This used to be
        split: B/C/K got a flat `amount` added once per Critical day,
        stacking without limit. That was retired -- confirmed the hard
        way that a one-shot daily dose gets erased before anyone notices
        it whenever the target naturally regenerates/decays on its own:
        Vitamin B originally drained ENDURANCE the same one-shot way A/D/E
        did, and a once-a-day -0.2 hit was invisible against ordinary rest
        regen; B's later Stiffness-based version had the same problem
        (Stiffness decays on its own whenever not exercising); C's
        original BleedingTime-once/day version was erased even faster,
        since BodyPart.class confirms a bandage drains BleedingTime 10x
        faster than nothing does, healing off an entire day's dose within
        a couple of real-time hours. Maintaining a floor (the stat/timer
        can't drop below X while afflicted) or a ceiling (can't rise above
        X while afflicted) instead means the effect is always genuinely
        present for as long as the deficiency lasts, and correctly stops
        fighting the stat/timer the instant the vitamin is no longer
        afflicted or gets pause-day-shielded (no lingering artificial
        floor/ceiling after recovery).

      - A/C/D/E's floor/ceiling values are checked against the vanilla
        Moodle system's own real thresholds (decompiled straight from
        zombie/characters/Moodles/MoodleStat.class's bytecode, not
        guessed) so the number picked actually crosses into a visible
        moodle level instead of sitting under the radar:
          UNHAPPINESS/"Sad" moodle (0-100 scale): >20=Low, >45=Moderate,
              >60=High, >80=Max
          ENDURANCE/"Tired" moodle (0-1 scale, LOWER is worse): <=0.75=Low,
              <=0.5=Moderate, <=0.25=High, <=0.1=Max
          STRESS/SICKNESS moodles (0-1 scale, same breakpoints for both):
              >0.25=Low, >0.5=Moderate, >0.75=High, >0.9=Max
        Per the user's explicit request, every one of these is now picked
        to sit comfortably in the MIDDLE of its Low band specifically --
        annoying enough to always actually show the Low moodle icon, but
        with margin on both sides so it never edges into Moderate, and
        isn't sitting exactly on a boundary where it could read as "no
        moodle at all" depending on float rounding or a stat ticking by a
        hair from vanilla's own regen: A's floor of 30 (Low band 20-45),
        D's ceiling of 0.65 (Low band 0.5-0.75, i.e. >0.5 and <=0.75), and
        C/E's floors of 0.35 (Low band 0.25-0.5) all land solidly in the
        middle third of their respective Low bands. (Earlier drafts used
        boundary values -- D=0.75, E/C=0.5 -- that technically land in Low
        per the exact cutoffs above, but sitting exactly on the line to
        Moderate/None felt too fragile for "reliably just annoying". A's
        old floor of 20 was fine for its ORIGINAL mechanism, CharacterStat
        .PANIC -- but PANIC and UNHAPPINESS have different Low bands
        (6-30 vs 20-45), so switching A onto UNHAPPINESS meant 20 needed
        recalculating too, not reused as-is -- it would have sat right at
        UNHAPPINESS's None/Low edge instead of comfortably inside it.)

    Per-vitamin mechanisms are custom Lua effects THEMED after a real
    vanilla Trait's or deficiency's well-known behavior, picked to match
    how that deficiency actually presents -- but explicitly NOT the real
    Trait itself (character:getCharacterTraits():add/remove(CharacterTrait
    .X) is a real, confirmed-working, vanilla-used mechanism -- see
    XpUpdate.lua's live WEAK/FEEBLE/STOUT/STRONG swaps as the Strength
    skill levels up -- but was deliberately ruled out here to avoid
    touching the real trait system at all, e.g. traits showing up in the
    character's own trait list). See HARMONIE_VitaminEffects.lua's header
    for exactly what each one does and how closely it was possible to
    match the real trait/deficiency, given what's actually reachable from
    Lua:
      A: CharacterStat.UNHAPPINESS as a stand-in for persistent low mood
          -- moved off its original Short Sighted/PANIC theming (vision
          narrowing was never a great match to begin with: the REAL
          Short Sighted blur effect, confirmed in IsoGameCharacter
          .class's updateVisionEffects() as blurFactorTarget = 1 whenever
          hasTrait(SHORT_SIGHTED) XOR isWearingGlasses() differ, lives on
          PRIVATE fields with no exposed Lua setter and no findable render
          consumer either -- reproducing it for real would mean drawing
          an entirely independent full-screen overlay, the same category
          of thing that caused a real problem earlier in this mod, a
          since-removed full-screen panel that silently ate every mouse
          click game-wide). UNHAPPINESS/"Sad" is simpler and already
          fully verified working -- no real vitamin A deficiency symptom
          it maps to, purely a reliable, felt in-game effect.
      B (Disorganized): COULD NOT be replicated at all -- its real effect
          (reduced bag/world-container capacity, NOT main inventory,
          confirmed via UI_trait_DisorganizedDesc) has zero Lua exposure;
          grepped every script for setMaxWeight/setCapacity on a container
          object and found no usable pattern for a player-worn bag. Kept
          on the previously-working Arm/Back/Torso Stiffness mechanic
          instead as the least-bad available option -- see effects.B below.
      C: CharacterStat.SICKNESS as a stand-in for the general fatigue/
          malaise real scurvy causes -- moved off its original
          Thin-Skinned/BleedingTime theming, which was reassigned to K
          below (impaired blood clotting is Vitamin K's real deficiency
          symptom, a much closer match than C's old theme ever was to
          either vitamin).
      D (Asthmatic / "Short of Breath"): drains CharacterStat.ENDURANCE --
          the real trait triggers periodic panic-driven asthma attacks
          cured by an Inhaler, which isn't a Lua-triggerable event.
      E (All Thumbs): CharacterStat.STRESS, PLUS the one case where the
          real mechanic WAS found in Lua -- ISHandcraftAction.lua checks
          character:hasTrait(CharacterTrait.ALL_THUMBS) to force
          stopOnWalk=true during crafting (walking cancels the action).
          HARMONIE_ClumsyHandsHook.lua reproduces that exact behavior for
          an afflicted character without touching the trait itself.
      K: keeps BleedingTime on active wounds from ever fully closing (see
          effects.K's floor + VitEffects.MaintainBleedingFloor) -- this
          was C's original mechanic, moved here since real Vitamin K
          deficiency is specifically about blood not clotting properly,
          not slow-healing fractures/burns (K's own previous theme, which
          had no direct real-trait match either). Also occasionally
          starts a spontaneous nosebleed/gum bleed with NO wound required
          (VitEffects.MaybeTriggerNosebleed) -- a genuine real symptom of
          Vitamin K deficiency, and the only way a character who never
          gets hit would ever feel this deficiency at all otherwise. Uses
          bodyPart:setScratched(true, true) + bodyPart:generateBleeding()
          -- vanilla's own real two-step wound-creation sequence (the
          exact same one a zombie scratch uses), confirmed necessary
          after an in-game test showed directly forcing BleedingTime
          alone creates no visible wound at all (no Scratch icon, nothing
          in the Health panel) since it never sets scratched()/isCut()
          true, the flags the game's own UI actually checks for.

    All values here are rough real-world-approximate game-balance figures,
    not medical reference data. Vitamin "B" is a single stat standing in for
    the whole B-complex (B1/B2/B3/B6/B9/B12, which each have very different
    real RDAs); its daily requirement below is a simplified composite
    figure, not an official value for any one B vitamin. These defaults can
    be overridden live per-server through Sandbox Options or the in-game
    admin panel (see HARMONIE_AdminPanel.lua).
]]--

HARMONIE_GTP = HARMONIE_GTP or {}

HARMONIE_GTP.Vitamins = {"A", "B", "C", "D", "E", "K"}

-- Approximate adult daily requirements. Units match the food database
-- entries for the same vitamin (A/D/K in micrograms, B/C/E in milligrams).
HARMONIE_GTP.DailyRequirement = {
    A = 900,  -- mcg RAE
    B = 10,   -- mg (simplified B-complex composite, see note above)
    C = 90,   -- mg
    D = 15,   -- mcg (~600 IU)
    E = 15,   -- mg
    K = 90,   -- mcg
}

local function readSandbox(key, fallback)
    if SandboxVars and SandboxVars.HARMONIE_GardenToPlate and SandboxVars.HARMONIE_GardenToPlate[key] ~= nil then
        return SandboxVars.HARMONIE_GardenToPlate[key]
    end
    return fallback
end

HARMONIE_GTP.Config = {
    maxValue = 100,
    startValue = 100,

    -- band thresholds (value strictly below the threshold falls in that band)
    criticalThreshold = 20,
    sufficientThreshold = 50,

    -- Reserve lost per in-game day once a vitamin's banked pause days run out
    decayPerDay = 5,
    -- Reserve gained = (percent of daily requirement eaten) / reserveGainDivisor
    reserveGainDivisor = 10,
    -- Reserve points needed to bank 1 pause day (10 Reserve = 1 pause day)
    reservePerPauseDay = 10,

    -- First Aid perk level required to interpret the manual assessment UI
    assessmentRequiredFirstAid = 5,

    -- master switch and severity scale for critical-band penalties
    effectsEnabled = true,
    effectMultiplier = 1,

    -- A/C/D/E: CharacterStat floor/ceiling maintained continuously (see
    -- the Affliction model note above and VitEffects.MaintainStatEffect),
    -- each picked to sit in the MIDDLE of that stat's own real Moodle Low
    -- band (decompiled from MoodleStat.class, see above) -- reliably
    -- "annoying" (the Low icon always actually shows) without ever
    -- reaching Moderate.
    --
    -- B: per-body-part Stiffness floor (VitEffects.MaintainStiffnessFloor)
    -- on the same Hand/ForeArm/UpperArm/Torso parts vanilla's own
    -- addArmMuscleStrain/addBackMuscleStrain target -- confirmed via
    -- BodyPart.class that Stiffness is a real, clamped 0-100 field with no
    -- documented Moodle tie-in of its own, so there's no exact band to aim
    -- for here; kept modest (20, a fifth of the scale) to match the same
    -- "low and annoying, not severe" spirit as the Moodle-linked ones.
    --
    -- K: per-body-part BleedingTime floor (VitEffects.
    -- MaintainBleedingFloor) on whichever body parts are already
    -- bleeding -- also has no Moodle of its own. Confirmed from
    -- BodyPart.class that nothing else reads BleedingTime's exact
    -- magnitude (only whether it's > 0, which gates IsBleeding/
    -- setBleeding) -- so once MaintainBleedingFloor is re-flooring it
    -- every 10 seconds anyway, a bigger floor doesn't make the wound any
    -- "worse", just gives it more numeric cushion between checks. Kept at
    -- 3 (vanilla's own lowest real reference for this field -- embedded
    -- glass in a wound forces a minimum of 3) to match the same minimal
    -- "just annoying" spirit as everything else, rather than 10
    -- (vanilla's debug-tool idea of "some bleeding", which reads as more
    -- severe for no actual functional difference here).
    effects = {
        A = { floor = 30 },     -- CharacterStat.UNHAPPINESS maintained >= this (0-100 scale)
        B = { floor = 20 },     -- Arm/Back/Torso Stiffness maintained >= this (0-100 scale)
        C = { floor = 0.35 },   -- CharacterStat.SICKNESS maintained >= this (0-1 scale)
        D = { ceiling = 0.65 }, -- CharacterStat.ENDURANCE maintained <= this (0-1 scale)
        E = { floor = 0.35 },   -- CharacterStat.STRESS maintained >= this (0-1 scale)
        K = { floor = 3 },      -- BleedingTime on active wounds maintained >= this (never fully closes)
    },
}

--[[
    Re-reads the tunable fields from SandboxVars (falling back to the
    defaults above if unset, e.g. before a world is loaded). Call this once
    on load and again whenever the admin panel changes a live value, so
    everything stays in sync without needing a restart.
]]--
function HARMONIE_GTP.RefreshFromSandbox()
    local c = HARMONIE_GTP.Config
    c.decayPerDay = readSandbox("DecayPerDay", c.decayPerDay)
    c.reserveGainDivisor = readSandbox("ReserveGainDivisor", c.reserveGainDivisor)
    c.criticalThreshold = readSandbox("CriticalThreshold", c.criticalThreshold)
    c.sufficientThreshold = readSandbox("SufficientThreshold", c.sufficientThreshold)
    c.effectsEnabled = readSandbox("EnableCriticalEffects", c.effectsEnabled)
    c.effectMultiplier = readSandbox("EffectMultiplier", c.effectMultiplier)
end

HARMONIE_GTP.RefreshFromSandbox()

function HARMONIE_GTP.GetBand(value)
    if value < HARMONIE_GTP.Config.criticalThreshold then
        return "critical"
    elseif value < HARMONIE_GTP.Config.sufficientThreshold then
        return "low"
    end
    return "sufficient"
end

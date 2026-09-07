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
      - B, C, and K's penalty is a flat `amount` (scaled only by
        effectMultiplier) applied once per day it's Critical, stacking
        without limit for as long as the deficiency persists (no ramp, no
        cap) -- deliberately, to discourage ignoring it.
      - A, D, and E's penalty is instead a `floor`/`ceiling` on a vanilla
        CharacterStat, CONTINUOUSLY enforced every 10 seconds by
        HARMONIE_VitaminChecker.lua (VitEffects.MaintainStatEffect) rather
        than applied once per day -- because PANIC, ENDURANCE, and STRESS
        all naturally regenerate/decay back toward their own baseline on
        their own (confirmed the hard way: Vitamin B originally used
        ENDURANCE the same one-shot way A/D/E do now, and a once-a-day
        -0.2 hit was completely invisible in practice because ordinary
        rest regenerates Endurance faster than that). A single daily dose
        to any of these three would very likely get fully erased by
        vanilla's own regen within the same day, making the "penalty"
        silently do nothing. Maintaining a floor (PANIC/STRESS can't drop
        below X while afflicted) or a ceiling (ENDURANCE can't rise above
        X while afflicted) instead means the effect is always genuinely
        present for as long as the deficiency lasts, and correctly stops
        fighting the stat the instant the vitamin is no longer afflicted
        or gets pause-day-shielded (no lingering artificial floor/ceiling
        after recovery).

    Per-vitamin mechanisms are custom Lua effects THEMED after a real
    vanilla Trait's well-known behavior, picked to match how that
    deficiency actually presents -- but explicitly NOT the real Trait
    itself (character:getCharacterTraits():add/remove(CharacterTrait.X) is
    a real, confirmed-working, vanilla-used mechanism -- see XpUpdate.lua's
    live WEAK/FEEBLE/STOUT/STRONG swaps as the Strength skill levels up --
    but was deliberately ruled out here to avoid touching the real trait
    system at all, e.g. traits showing up in the character's own trait
    list). See HARMONIE_VitaminEffects.lua's header for exactly what each
    one does and how closely it was possible to match the real trait,
    given what's actually reachable from Lua:
      A (Short Sighted): CharacterStat.PANIC (vision narrowing) -- no
          accessible way to shrink sight radius directly from Lua.
      B (Disorganized): COULD NOT be replicated at all -- its real effect
          (reduced bag/world-container capacity, NOT main inventory,
          confirmed via UI_trait_DisorganizedDesc) has zero Lua exposure;
          grepped every script for setMaxWeight/setCapacity on a container
          object and found no usable pattern for a player-worn bag. Kept
          on the previously-working Arm/Back muscle strain mechanic
          instead as the least-bad available option -- see effects.B below.
      C (Thin-Skinned): extends BleedingTime on active wounds -- the real
          trait raises the CHANCE of being cut/scratched in combat, not a
          once-a-day stat.
      D (Asthmatic / "Short of Breath"): drains CharacterStat.ENDURANCE --
          the real trait triggers periodic panic-driven asthma attacks
          cured by an Inhaler, which isn't a Lua-triggerable event.
      E (All Thumbs): CharacterStat.STRESS, PLUS the one case where the
          real mechanic WAS found in Lua -- ISHandcraftAction.lua checks
          character:hasTrait(CharacterTrait.ALL_THUMBS) to force
          stopOnWalk=true during crafting (walking cancels the action).
          HARMONIE_ClumsyHandsHook.lua reproduces that exact behavior for
          an afflicted character without touching the trait itself.
      K (Slow Healer): extends DeepWoundTime/FractureTime/BurnTime on
          active wounds -- the real trait slows overall healing rate, not
          something with a direct multiplier exposed to Lua.

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

    -- A/D/E: floor/ceiling maintained continuously (see the Affliction
    -- model note above and VitEffects.MaintainStatEffect) -- sized as
    -- "20% of that vanilla CharacterStat's own min-max range" uniformly:
    -- confirmed straight from the game's own zombie/characters/
    -- CharacterStat.class (register(id, min, max, default)) that these
    -- stats do NOT all share one 0-100 scale -- PANIC is 0-100, ENDURANCE
    -- and STRESS are 0-1. So PANIC's floor is 20 (out of 100) and
    -- STRESS's floor is 0.2 (out of 1), both "at least 20% of the stat's
    -- own range, always, while afflicted". ENDURANCE gets a CEILING
    -- instead (since the goal is draining it, not raising it) at 1 minus
    -- that same 20% -- i.e. capped at 0.8, never allowed to fully recover
    -- to 1.0 while afflicted.
    --
    -- B, C, K: flat per-day amount (see HARMONIE_VitaminEffects.lua and
    -- the big themed-per-trait note above). B (0.2, Arm+Back muscle
    -- strain) matches the same magnitude as one farming/chopping action
    -- -- no Lua-exposed getter for current muscle strain exists anywhere
    -- in vanilla, so there's no reliable way to enforce a hard floor on
    -- it directly; the daily stacking is what keeps it persistent
    -- instead. C and K are on their own different scale entirely (neither
    -- touches a CharacterStat) -- BleedingTime added on already-bleeding
    -- body parts for C (vanilla's own debug tools toggle this timer to 10
    -- as "some bleeding", so a couple units/day is meaningful without
    -- ending a fight-worthy wound instantly), DeepWoundTime/FractureTime/
    -- BurnTime added on whichever is already active for K (vanilla's real
    -- Fracture takes 21 days to heal, so a couple units/day is a
    -- meaningful delay without being an automatic never-heals wall).
    effects = {
        A = { floor = 20 },     -- CharacterStat.PANIC maintained >= this (0-100 scale)
        B = { amount = 0.2 },   -- Arm + Back muscle strain added per day (0-1-ish scale)
        C = { amount = 2 },     -- BleedingTime added to active wounds per day
        D = { ceiling = 0.8 },  -- CharacterStat.ENDURANCE maintained <= this (0-1 scale)
        E = { floor = 0.2 },    -- CharacterStat.STRESS maintained >= this (0-1 scale)
        K = { amount = 2 },     -- DeepWoundTime/FractureTime/BurnTime added to active wounds per day
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

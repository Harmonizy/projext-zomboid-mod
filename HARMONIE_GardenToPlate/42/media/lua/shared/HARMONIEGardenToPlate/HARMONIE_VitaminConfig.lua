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
      - Once afflicted, the critical-band penalty keeps applying every day
        even if Reserve ticks back above criticalThreshold, right up until
        it reaches sufficientThreshold ("Sufficient" band) -- not just out
        of "Critical". This matches a real deficiency: you don't feel better
        the moment you're technically no longer in the red.
      - Every vitamin's penalty is the SAME flat `amount` (scaled only by
        effectMultiplier) whether it's the first day of affliction or the
        hundredth -- applied once immediately on the day it becomes
        Critical, then again every subsequent day it stays that way,
        stacking without limit for as long as the deficiency persists (no
        ramp curve, no cap -- staying Critical a long time keeps getting
        worse forever, deliberately, to discourage ignoring it).

    Vitamin A ("Vision Impaired") reuses vanilla's own Panic-driven tunnel
    vision/screen narrowing rather than any custom overlay -- there's no
    accessible Lua API to shrink a character's actual sight radius, but
    pushing CharacterStat.PANIC up triggers the game's real, native panic
    vision effect, which is exactly the "narrowed field of vision" look
    without inventing a new rendering hack (an earlier full-screen overlay
    panel approach was scrapped after it silently ate every mouse click).

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

    -- Flat per-day-of-affliction penalty applied while a vitamin is
    -- afflicted -- same amount every day, no ramp, no cap (see the
    -- Affliction model note above). A/B/C/D/E are sized as "20% of that
    -- vanilla stat's own min-max range per day" uniformly, NOT a flat 20
    -- in every case: confirmed straight from the game's own
    -- zombie/characters/CharacterStat.class (register(id, min, max,
    -- default)) that these stats do NOT all share one 0-100 scale --
    --   PANIC: 0-100, PAIN: 0-100
    --   ENDURANCE: 0-1, SICKNESS: 0-1, STRESS: 0-1
    -- so 20% works out to 20 for the 0-100 stats and 0.2 for the 0-1
    -- stats -- both are "20 out of the stat's own 100%", just expressed in
    -- that stat's native units. (The previous flat numbers here -- 0.6 for
    -- PAIN, 0.08 for ENDURANCE -- had drifted from this: 0.6/100 for PAIN
    -- was nearly a no-op, while 0.6/1.0 for SICKNESS was already a huge
    -- 60% jump every single day.)
    --
    -- K is a deliberate exception, kept lower at 5 (not the 20 that 20%-
    -- of-0-100 would suggest): confirmed by decompiling BodyDamage.class /
    -- IsoGameCharacter.class that wound body-part health (0-100 scale)
    -- isn't just cosmetic -- it feeds Overall Body Health
    -- (BodyDamage.calculateOverallHealth, a weighted average across every
    -- body part), and IsoGameCharacter.isDead() returns true once that
    -- reaches 0. So unlike A/B/C/D/E (moodle-level discomfort with no
    -- death path), an uncapped K penalty across several already-injured
    -- body parts at once compounds into an actual death spiral -- 5/day
    -- keeps that possible under sustained neglect without making it a
    -- near-automatic death sentence the moment Vitamin K goes critical.
    -- B switched from CharacterStat.ENDURANCE to vanilla's own
    -- Arm/Back muscle strain (character:addArmMuscleStrain /
    -- addBackMuscleStrain, the same calls farming/chopping/digging use)
    -- because Endurance regenerates from ordinary rest/idle time fast
    -- enough that a once-a-day -0.2 hit was barely noticeable in
    -- practice. Muscle strain isn't erased by just standing around the
    -- same way, so it should actually stick. No Lua-exposed getter for
    -- current muscle strain was found anywhere in vanilla's own scripts
    -- (only the various add*MuscleStrain writers), so there's no
    -- reliable way from Lua to enforce a hard floor/minimum on it --
    -- this relies on the same "flat amount, no cap, applied again every
    -- day it stays Critical" stacking every other vitamin already uses
    -- for persistence instead.
    effects = {
        A = { amount = 20 },   -- CharacterStat.PANIC added (0-100 scale)
        B = { amount = 0.2 },  -- Arm + Back muscle strain added (0-1-ish scale, same magnitude as one farming/chopping action)
        C = { amount = 0.2 },  -- CharacterStat.SICKNESS added (0-1 scale)
        D = { amount = 20 },   -- CharacterStat.PAIN added (0-100 scale)
        E = { amount = 0.2 },  -- CharacterStat.STRESS added (0-1 scale)
        K = { amount = 5 },    -- wound body-part health removed (0-100 scale, deliberately gentler -- see above)
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

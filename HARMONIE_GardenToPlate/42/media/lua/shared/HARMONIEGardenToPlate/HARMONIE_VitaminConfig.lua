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
      - The critical-band penalty is a real vanilla CharacterTrait,
        genuinely granted/revoked by HARMONIE_VitaminChecker.lua every 10
        seconds (VitEffects.MaintainRealTrait) -- NOT a custom stat/timer
        effect. Earlier versions of this mod tried several custom proxy
        mechanics on top of (or instead of) a real trait -- a
        CharacterStat floor/ceiling to force a vanilla Moodle icon to
        show, a per-body-part Stiffness/BleedingTime floor, a hand-
        written stopOnWalk hook, and even a set of brand-new mod-
        registered traits -- ALL of these were explicitly removed per
        request: harder to tune/control than they were worth, compared to
        just reusing a real trait's own already-balanced, already-tested
        vanilla behavior. See HARMONIE_VitaminEffects.lua's header for
        the full current design and per-vitamin trait mapping.

    Per-vitamin trait mapping (all six are real, already-compiled,
    normally player-selectable CharacterTrait values -- confirmed via
    decompiling CharacterTrait.class -- reused here rather than
    registering anything new):
      A -> Short Sighted (vision blur)
      B -> Disorganized (reduced bag/world-container capacity; skips
           auto-returning leftover crafting items to their container)
      C -> Thin-Skinned (more easily cut/scratched)
      D -> Short of Breath (in-game display name -- internal id/enum is
           Asthmatic/base:asthmatic; real effect confirmed via
           decompiling CharacterTraits.class is 1.2x faster ENDURANCE
           loss, NOT panic-driven asthma attacks)
      E -> All Thumbs (forces stopOnWalk during crafting; fumbles
           dropped items and inventory transfers)
      K -> Slow Healer (wounds take longer to heal)
    See HARMONIE_VitaminEffects.lua's header for the full citations
    behind each of these (which are Java-only vs which have a confirmed
    Lua-visible hook) and for MaintainRealTrait's safety logic that
    guarantees a character's own genuinely-chosen starting trait is never
    stripped by this mod.

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

    -- master switch for critical-band penalties (MaintainRealTrait no-ops
    -- entirely while this is false)
    effectsEnabled = true,

    -- How often (in GAME hours) a character with at least one Critical,
    -- non-pause-shielded vitamin re-rolls its in-character symptom
    -- comment -- see HARMONIE_VitaminChecker.lua's getSymptomBlockIndex /
    -- VitEffects.MaybeSaySymptomReminder. Lower = comments more often.
    symptomReminderHours = 6,
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

    -- Permanent (not a temporary debug print) console.txt confirmation
    -- of the exact moment this value actually changes -- added after a
    -- report that the admin panel's frequency slider didn't seem to be
    -- taking effect. Lets anyone grep console.txt for "[HARMONIE]
    -- SymptomReminderHours" to see the real, currently-live value
    -- instead of having to guess whether a Save actually reached here.
    local newSymptomReminderHours = readSandbox("SymptomReminderHours", c.symptomReminderHours)
    if newSymptomReminderHours ~= c.symptomReminderHours then
        print(string.format("[HARMONIE] SymptomReminderHours changed: %s -> %s",
            tostring(c.symptomReminderHours), tostring(newSymptomReminderHours)))
    end
    c.symptomReminderHours = newSymptomReminderHours
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

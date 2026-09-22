--[[
    HARMONIE - From Garden to Plate
    Applies each vitamin's deficiency penalty while currently afflicted
    (see the hysteresis note in HARMONIE_VitaminConfig.lua).

    THIRD DESIGN (per explicit request, replacing the real-vanilla-trait
    system this mod used before): each vitamin applies a DIRECT game-stat
    penalty instead of granting a real CharacterTrait. This is the mod's
    OWN third attempt at this problem, and the second time trying stat-
    based effects specifically -- full history preserved here so the same
    mistakes aren't relearned the hard way a third time (found via git log
    -S on this mod's own history, commits 06944a6 and 4068598):

      1st design: once-a-day flat dose to a CharacterStat/timer (e.g.
        ENDURANCE -0.2 for D, BleedingTime +amount for C). CONFIRMED
        BROKEN the hard way: every one of these targets naturally
        regenerates/decays back toward its own baseline continuously, so
        a once-a-day nudge was completely erased before the player could
        ever notice it (ENDURANCE regenerates from rest; Stiffness decays
        when not exercising; a bandage drains BleedingTime 10x faster
        than nothing does).
      2nd design: fixed the above by RE-ENFORCING a floor/ceiling every 10
        seconds instead of once a day (this file keeps that fix -- see
        every Maintain* function below). Worked mechanically, but was
        still abandoned for two other reasons: (a) some real trait effects
        have literally NO Lua exposure at all (B's real Disorganized
        effect, reduced bag capacity, has zero findable Lua hook -- grepped
        every script for setMaxWeight/setCapacity on a worn container and
        found nothing usable), and (b) a naive attempt at K's bleeding
        effect (directly calling bodyPart:setBleedingTime()) was CONFIRMED
        to have literally no visible effect in-game at all -- it sets the
        raw internal timer but never marks the part as an actual wound
        (scratched()/isCut() stay false), so nothing shows on the
        character model, Health panel, or Injured moodle. The fix,
        confirmed straight from BodyPart.class (the exact same path a
        zombie scratch uses): bodyPart:setScratched(true, true) creates a
        REAL wound first, then bodyPart:generateBleeding() derives a
        genuine BleedingTime from it. Reused verbatim in MaybeTriggerScratch
        below.
      3rd design (this file, current): reassigns those SAME proven
        mechanisms onto NEW vitamins per explicit request, with new
        specific values, plus a brand new universal effect (health cap)
        that didn't exist in either earlier design. Real trait mapping is
        retired entirely -- HARMONIE_VitaminData.lua's traitGranted field
        is now unused dead storage, kept only so old save data doesn't
        error on load.

    Every mechanism below uses a REAL, CONFIRMED PZ API -- verified this
    session by grepping vanilla's own Lua source for actual working
    examples before writing anything (not guessed):
      - character:getStats():set(CharacterStat.X, value) -- confirmed real
        via forageSystem.lua (ENDURANCE/FATIGUE), Tutorial/Steps.lua
        (UNHAPPINESS), and multiple other vanilla files.
      - bodyPart:getStiffness()/:setStiffness() -- confirmed real via this
        mod's own earlier (now-reverted) MaintainStiffnessFloor, itself
        confirmed against BodyPart.class.
      - bodyPart:setScratched(true, true) + bodyPart:generateBleeding() --
        confirmed real, see the 2nd-design paragraph above.
      - bodyDamage:getOverallBodyHealth() / bodyDamage:ReduceGeneralHealth()
        -- confirmed real from a mature, actively-used mod (Extensive
        Health Rework Evolved, Workshop 3726328119, already a soft
        dependency of HARMONIE_HomeMedic in this same repo) -- its own
        EHR_EnvironmentalClampBodyHealth function in
        EHR_EnvironmentalDiseases.lua does exactly this same "reduce
        current health down to a cap" pattern, reused here for the
        universal per-affliction health cap.

    Per-vitamin mapping (user's own real-world reasoning behind each,
    given verbatim):
      A -> CharacterStat.STRESS floor 0.30 (0-1 scale). "stressed ส่งผลให้
           ตีเบาลงและใช้อาวุธไกลยากขึ้น เหมือนกับอาการที่คนตาพร่าเลย
           โจมตียากขึ้น" -- persistent stress standing in for how blurred
           vision would make combat harder.
      B -> CharacterStat.ENDURANCE ceiling 0.80 (0-1 scale, capped
           stamina). "กล้ามเนื้ออ่อนแรง โลหิตจาง และอื่นๆ เลยทำให้ใช้แรงได้
           น้อยลง" -- muscle weakness/anemia meaning less usable strength.
      C -> random spontaneous Head scratch (bleeding gums/nosebleed),
           checked every 1 GAME hour, 5% chance per check.
           "จำลองการเลือดกำเดาไหลหรือเลือดออกตามไรฟัน"
      D -> per-body-part Stiffness floor 20 (0-100 scale), ALL body parts
           (every part returned by getBodyDamage():getBodyParts(), not
           just a subset). "จำลองการปวดกระดูก ปวดกล้ามเนื้อ กล้ามเนื้อ
           อ่อนแรง"
      E -> CharacterStat.UNHAPPINESS floor 30 (0-100 scale -- confirmed a
           DIFFERENT scale than Stress/Endurance/Sickness, see this mod's
           own earlier VitaminConfig.lua research citing MoodleStat.class).
           "unhappy ทำให้ย้ายของหรือทำอะไรช้าลง จำลองการทำงานผิดปกติของ
           ระบบประสาทและกล้ามเนื้ออ่อนแรง"
      K -> CharacterStat.SICKNESS floor 0.55 (0-1 scale, guarantees at
           least the "Nauseous" tier of vanilla's real Sick moodle --
           confirmed by decompiling Moodle.class/MoodleStat.class, see
           MaintainSicknessFloor below). "อาการของ sick ทำให้การรักษาช้าลง
           เลยเหมือนอาการเลือดแข็งตัวยาก"

    Universal effect (new this design, independent of which specific
    vitamins): every vitamin currently afflicted-and-not-pause-shielded
    caps overall body health 5 percentage points lower each, stacking --
    see VitEffects.MaintainHealthCap below.

    All of this is a no-op while the vitamin has at least 1 WHOLE banked
    pause day (HARMONIE_GTP.VitData.GetPauseDays >= 1), same as every
    earlier design -- gained from eating well, or from taking this mod's
    own crafted Multivitamin pill (see HARMONIE_PillsHook.lua). Recovery
    (Reserve climbing back to Sufficient) reverses everything automatically
    -- each Maintain* function below simply stops touching its target the
    moment the vitamin is no longer afflicted, letting vanilla fully take
    back over (no lingering artificial floor/ceiling after recovery).

    Dialogue is entirely separate -- handled by MaybeSaySymptomReminder
    below, checked every 6 GAME hours, picking ONE random currently-
    afflicted vitamin to comment on each time. Rewritten this design to
    match each vitamin's NEW effect rather than the old trait-based
    symptoms (see the translation files themselves for the actual lines).
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
    wrong -- see HARMONIE_VitaminConfig.lua's assessmentRequiredFirstAid.
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
    been afflicted. See HARMONIE_VitaminChecker.lua, which calls this at
    most once per check even if several vitamins recover in the same
    10-second tick.
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

-- Shared afflicted-and-not-shielded check every Maintain*/MaybeTrigger*
-- function below gates on -- a banked pause day (>= 1 WHOLE day) quiets
-- every effect the same way, consistent with it being framed as symptom
-- relief rather than a cure.
local function isActive(character, vit)
    return HARMONIE_GTP.VitData.IsAfflicted(character, vit)
        and HARMONIE_GTP.VitData.GetPauseDays(character, vit) < 1
end

-- Only used by MigrateAwayFromRealTraits below, for revoking a real trait
-- an EARLIER version of this mod may have granted (see VitData.lua's
-- traitGranted field comment) -- not used by any current effect.
local LegacyRealTraits = {
    A = CharacterTrait.SHORT_SIGHTED,
    B = CharacterTrait.DISORGANIZED,
    C = CharacterTrait.THIN_SKINNED,
    D = CharacterTrait.ASTHMATIC,
    E = CharacterTrait.ALL_THUMBS,
    K = CharacterTrait.SLOW_HEALER,
}

--[[
    One-time-per-vitamin cleanup for a save upgrading from this mod's
    earlier real-vanilla-trait design (see HARMONIE_VitaminData.lua's
    traitGranted field comment). Safe to call every tick for every
    character -- IsTraitGrantedByUs is false for anyone who never had the
    old design apply to begin with (a fresh character, or one who already
    got migrated), making this an idempotent no-op after the first pass.
    Only ever removes a trait THIS mod granted (traitGranted tracks that
    distinction) -- a character's own genuinely-chosen starting trait is
    never touched, exact same safety logic the old MaintainRealTrait used.
]]--
function VitEffects.MigrateAwayFromRealTraits(character)
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if HARMONIE_GTP.VitData.IsTraitGrantedByUs(character, vit) then
            local trait = LegacyRealTraits[vit]
            if trait and character:hasTrait(trait) then
                character:getCharacterTraits():remove(trait)
                character:updateVisionEffects()
            end
            HARMONIE_GTP.VitData.SetTraitGrantedByUs(character, vit, false)
        end
    end
end

-- ---------------------------------------------------------------------
-- A: CharacterStat.STRESS floor 0.30
-- ---------------------------------------------------------------------
local STRESS_FLOOR = 0.30

function VitEffects.MaintainStressFloor(character)
    if not HARMONIE_GTP.Config.effectsEnabled then return end
    if not isActive(character, "A") then return end

    local stats = character:getStats()
    local current = stats:get(CharacterStat.STRESS)
    if current < STRESS_FLOOR then
        stats:set(CharacterStat.STRESS, STRESS_FLOOR)
    end
end

-- ---------------------------------------------------------------------
-- B: CharacterStat.ENDURANCE ceiling 0.80 (capped stamina)
-- ---------------------------------------------------------------------
local ENDURANCE_CEILING = 0.80

function VitEffects.MaintainEnduranceCeiling(character)
    if not HARMONIE_GTP.Config.effectsEnabled then return end
    if not isActive(character, "B") then return end

    local stats = character:getStats()
    local current = stats:get(CharacterStat.ENDURANCE)
    if current > ENDURANCE_CEILING then
        stats:set(CharacterStat.ENDURANCE, ENDURANCE_CEILING)
    end
end

-- ---------------------------------------------------------------------
-- C: random spontaneous Head scratch (nosebleed/bleeding gums), every 1
-- game hour, 5% chance per check. Uses the confirmed-necessary two-step
-- wound sequence from this mod's own earlier design (see header) --
-- directly forcing BleedingTime alone was confirmed to have no visible
-- effect in-game.
-- ---------------------------------------------------------------------
-- Block granularity (1 game hour) lives in HARMONIE_VitaminChecker.lua's
-- getScratchBlockIndex, which computes the `block` argument passed in here.
local SCRATCH_CHANCE_PERCENT = 5
local ScratchLineKeys = {
    "IGUI_HARMONIE_ScratchC_1",
    "IGUI_HARMONIE_ScratchC_2",
}

function VitEffects.MaybeTriggerScratch(character, block)
    if not HARMONIE_GTP.Config.effectsEnabled then return end
    if not isActive(character, "C") then return end

    if HARMONIE_GTP.VitData.GetLastScratchBlock(character) == block then return end
    HARMONIE_GTP.VitData.SetLastScratchBlock(character, block)

    if ZombRand(100) >= SCRATCH_CHANCE_PERCENT then return end

    local headPart = character:getBodyDamage():getBodyPart(BodyPartType.Head)
    if not headPart or headPart:getBleedingTime() > 0 then return end

    headPart:setScratched(true, true)
    headPart:generateBleeding()

    if character.Say then
        character:Say(getText(ScratchLineKeys[ZombRand(#ScratchLineKeys) + 1]))
    end
end

-- ---------------------------------------------------------------------
-- D: per-body-part Stiffness floor 20, ALL body parts (bone/muscle
-- ache and weakness) -- iterates getBodyParts() directly rather than a
-- fixed name list, so "all body parts" is literal.
-- ---------------------------------------------------------------------
local STIFFNESS_FLOOR = 20

function VitEffects.MaintainMuscleStrain(character)
    if not HARMONIE_GTP.Config.effectsEnabled then return end
    if not isActive(character, "D") then return end

    local bodyParts = character:getBodyDamage():getBodyParts()
    for i = 0, bodyParts:size() - 1 do
        local bodyPart = bodyParts:get(i)
        if bodyPart and bodyPart:getStiffness() < STIFFNESS_FLOOR then
            bodyPart:setStiffness(STIFFNESS_FLOOR)
        end
    end
end

-- ---------------------------------------------------------------------
-- E: CharacterStat.UNHAPPINESS floor 30 -- NOTE this stat's scale is
-- 0-100, NOT 0-1 like Stress/Endurance/Sickness (confirmed via this
-- mod's own earlier research decompiling MoodleStat.class).
-- ---------------------------------------------------------------------
local UNHAPPINESS_FLOOR = 30

function VitEffects.MaintainUnhappinessFloor(character)
    if not HARMONIE_GTP.Config.effectsEnabled then return end
    if not isActive(character, "E") then return end

    local stats = character:getStats()
    local current = stats:get(CharacterStat.UNHAPPINESS)
    if current < UNHAPPINESS_FLOOR then
        stats:set(CharacterStat.UNHAPPINESS, UNHAPPINESS_FLOOR)
    end
end

-- ---------------------------------------------------------------------
-- K: CharacterStat.SICKNESS floor 0.55 (0-1 scale). CONFIRMED via
-- decompiling vanilla's own Moodle.class + MoodleStat.class (javap -p -c
-- on projectzomboid.jar, 2026-09-22 -- see workflow.txt section 8.4 for
-- the full bytecode trail): the real "Sick" moodle (Queasy/Nauseous/Sick/
-- Fever) is computed as
-- `getBodyDamage():getApparentInfectionLevel()/100 + getStats():get(SICKNESS)`,
-- compared (strictly >) against MoodleStat.SICK's own registered
-- thresholds 0.25/0.5/0.75/0.9 for Queasy/Nauseous/Sick/Fever. So
-- CharacterStat.SICKNESS genuinely IS the right stat (an earlier version
-- of this function switched to FOOD_SICKNESS based on a red herring in
-- Tutorial/Steps.lua and was WRONG -- reverted). The real bug was the
-- floor VALUE: 0.30 only barely clears the lowest (Queasy) threshold,
-- easy to miss entirely. 0.55 comfortably clears the Nauseous threshold
-- (0.5) with margin for float precision, matching what the user actually
-- wants visible ("the Nauseous status").
-- ---------------------------------------------------------------------
local SICKNESS_FLOOR = 0.55

function VitEffects.MaintainSicknessFloor(character)
    if not HARMONIE_GTP.Config.effectsEnabled then return end
    if not isActive(character, "K") then return end

    local stats = character:getStats()
    local current = stats:get(CharacterStat.SICKNESS)
    if current < SICKNESS_FLOOR then
        stats:set(CharacterStat.SICKNESS, SICKNESS_FLOOR)
    end
end

--[[
    Universal effect, independent of which specific vitamins are
    afflicted: every currently afflicted-and-not-pause-shielded vitamin
    caps overall body health (bodyDamage:getOverallBodyHealth(), 0-100)
    5 percentage points lower, stacking -- 3 vitamins afflicted at once
    means health can never read above 85. New this design (didn't exist
    in either earlier attempt).

    Uses bodyDamage:ReduceGeneralHealth(amount), NOT setOverallBodyHealth
    directly -- confirmed real pattern from Extensive Health Rework
    Evolved's own EHR_EnvironmentalClampBodyHealth (EHR_EnvironmentalDiseases
    .lua), a mature, actively-used mod already a soft dependency of
    HARMONIE_HomeMedic in this same repo. Only ever reduces (never
    increases) health -- a no-op once actual health is already at or below
    the cap, letting vanilla's own healing fully take back over the moment
    fewer vitamins are afflicted.
]]--
local HEALTH_CAP_PERCENT_PER_AFFLICTION = 5

function VitEffects.MaintainHealthCap(character)
    if not HARMONIE_GTP.Config.effectsEnabled then return end

    local afflictedCount = 0
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if isActive(character, vit) then
            afflictedCount = afflictedCount + 1
        end
    end
    if afflictedCount == 0 then return end

    local bodyDamage = character:getBodyDamage()
    if not bodyDamage or not bodyDamage.getOverallBodyHealth or not bodyDamage.ReduceGeneralHealth then return end

    local healthCap = 100 - (HEALTH_CAP_PERCENT_PER_AFFLICTION * afflictedCount)
    healthCap = math.max(0, healthCap)

    local currentHealth = bodyDamage:getOverallBodyHealth()
    if currentHealth > healthCap then
        bodyDamage:ReduceGeneralHealth(currentHealth - healthCap)
    end
end

-- Human-readable summary of what actually applies for each vitamin --
-- used only by LogEffectStateChange below, purely for the console
-- message text.
local EffectDescription = {
    A = "CharacterStat.STRESS floor 0.30 (weaker hits/harder ranged aim)",
    B = "CharacterStat.ENDURANCE ceiling 0.80 (capped stamina)",
    C = "random Head scratch, 1 game hour / 5% chance (nosebleed/bleeding gums)",
    D = "per-body-part Stiffness floor 20, all body parts (muscle strain)",
    E = "CharacterStat.UNHAPPINESS floor 30 (slower item handling)",
    K = "CharacterStat.SICKNESS floor 0.55 -- at least Nauseous (slower recovery)",
}

--[[
    Permanent (not a temporary debug print) console.txt confirmation of
    exactly when a vitamin's Critical-band effect genuinely starts/stops
    being enforced -- same philosophy as HARMONIE_GTP.LogMissingProfile in
    HARMONIE_FoodVitaminDatabase.lua. Fires exactly ONCE per transition,
    not every 10-second tick -- an in-memory (deliberately NOT ModData;
    this is a log aid only) weak-keyed table remembers the last known
    state per character+vitamin and only prints when it actually changes.
]]--
local lastEffectActive = setmetatable({}, { __mode = "k" })

function VitEffects.LogEffectStateChange(character, vit)
    local afflicted = isActive(character, vit)

    lastEffectActive[character] = lastEffectActive[character] or {}
    local was = lastEffectActive[character][vit]
    if was == afflicted then return end
    lastEffectActive[character][vit] = afflicted

    local ok, name = pcall(function() return character:getDisplayName() end)
    name = (ok and name) or "?"

    if afflicted then
        print(string.format("[HARMONIE] %s: Vitamin %s hit Critical -- effect ACTIVE (%s).",
            name, vit, EffectDescription[vit] or "?"))
    else
        print(string.format("[HARMONIE] %s: Vitamin %s no longer Critical (or now pause-day-shielded) -- effect CLEARED (%s).",
            name, vit, EffectDescription[vit] or "?"))
    end
end

--[[
    Checked every 6 GAME hours (see HARMONIE_VitaminChecker.lua's
    getSixHourBlockIndex) -- completely decoupled from the effect
    maintenance above, since firing dialogue on the same schedule as the
    effect itself is what used to cause several symptom lines to fire back
    to back the moment more than one vitamin crossed into Critical at
    once. Instead: gather every vitamin CURRENTLY afflicted and not
    pause-day-shielded, pick exactly ONE at random, and say only that
    one's line.
]]--
function VitEffects.MaybeSaySymptomReminder(character, block)
    if not character or not character.Say then return end
    if HARMONIE_GTP.VitData.GetLastSymptomBlock(character) == block then return end

    local candidates = {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if isActive(character, vit) then
            table.insert(candidates, vit)
        end
    end
    if #candidates == 0 then return end

    HARMONIE_GTP.VitData.SetLastSymptomBlock(character, block)
    sayRandomSymptom(character, candidates[ZombRand(#candidates) + 1])
end

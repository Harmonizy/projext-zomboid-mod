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
    given verbatim). UPDATED 2026-09-22, per a further explicit request
    reassigning A/B/K -- see each entry below for what changed and why:
      A -> (until 0.13.1; now NIGHT BLINDNESS, see HARMONIE_VitaminANightBlind.lua) CharacterStat.INTOXICATION floor 30 (0-100 scale, drives
           vanilla's real "Drunk" moodle -- confirmed by decompiling
           Moodle.class: that moodle reads getStats():get(INTOXICATION)
           alone). "มันให้อาการตาพร่า" -- reused purely for Intoxication's
           real blurred-vision side effect; deliberately NO drunk-themed
           dialogue or description anywhere in this mod's own text (Symptom/
           DoctorSymptom/Downside/Moodle copy all stay framed around
           blurred vision only) -- vanilla's own native "Drunk" moodle icon
           will still show regardless (same as every other vitamin's native
           side-moodle; not something this mod can rename). Previously used
           CharacterStat.STRESS floor 0.30 -- freed up and reassigned to B
           below.
      B -> CharacterStat.STRESS floor 0.30 (0-1 scale) -- the exact
           mechanism A used through v0.6.5, reassigned here per explicit
           request. "เหน็บชาเกิดขึ้นบ่อย โลหิตจางจนปวดหัว และอ่อนล้า
           เล็กๆน้อยๆ ทำให้เครียด" -- frequent tingling/numbness, anemia-
           driven headaches, and mild fatigue combining into stress.
           Previously used CharacterStat.ENDURANCE ceiling 0.80 -- freed up
           and folded into the universal effect below instead.
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
      K -> flat overall-health ceiling, -10 points (same
           bodyDamage:ReduceGeneralHealth ceiling technique as the
           universal effect below, just scoped to K alone and stacking
           with it). "อาการของ sick ทำให้การรักษาช้าลง เลยเหมือนอาการ
           เลือดแข็งตัวยาก" -- weakened overall condition standing in for
           poor clotting/slow healing. Previously used CharacterStat.
           DISCOMFORT floor 45 (itself already a replacement for the
           EHR-contested CharacterStat.SICKNESS, see the long comment still
           kept on MaintainKHealthCap below for that full saga) -- not
           broken, just superseded by this further explicit request.

    Universal effect (independent of which specific vitamins): every
    vitamin currently afflicted-and-not-pause-shielded caps ENDURANCE 10
    percentage points lower each, stacking -- see
    VitEffects.MaintainEnduranceCap below. CHANGED 2026-09-22 from the
    original "-5% overall health per affliction" (health is now K's own
    individual job instead, see above -- this avoids double-counting health
    from two different mechanisms at once). Reuses the ENDURANCE stat B's
    old ceiling effect freed up.

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
    -- 0.13.2: the same rule as every vitamin window (HARMONIE_GTP.VitaminView)
    local isDoctor = HARMONIE_GTP.VitaminView(character) == "full"
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
-- A (0.13.2, owner: "วิตามิน A ไม่อยากให้ผลเสียเป็นภาพเบลอ ... ลดดาเมจ ตีไม่โดน
-- มองใกล้ขึ้น หรืออะไรก็ได้"): NIGHT BLINDNESS -- the real first sign of
-- vitamin A deficiency. No more forced blurred vision (the old Intoxication
-- floor 30, which also showed vanilla's Drunk moodle). Instead the hits land
-- badly: a share of the damage a zombie takes from this character is given
-- back to it on the next tick -- 30 percent by day, 50 percent at night
-- (20:00-05:59), when poor eyes see least. Done in
-- HARMONIE_VitaminANightBlind.lua, on the side that owns zombie health.
-- This function stays (it is in the checker's list) but sets nothing now.
-- ---------------------------------------------------------------------
function VitEffects.MaintainDrunkFloor(character)
    if HARMONIE_GTP.LogOnce then
        HARMONIE_GTP.LogOnce("vitA:nightblind", "Effects", "vitamin A: night blindness (weaker hits) replaces the old blurred-vision floor")
    end
end

function VitEffects.IsActive(character, vit) return isActive(character, vit) end

-- ---------------------------------------------------------------------
-- B: CharacterStat.STRESS floor 0.30 (0-1 scale). The exact mechanism A
-- used through v0.6.5, reassigned to B per explicit request -- see the
-- header comment above.
-- ---------------------------------------------------------------------
local STRESS_FLOOR = 0.30

function VitEffects.MaintainStressFloor(character)
    if not HARMONIE_GTP.Config.effectsEnabled then return end
    if not isActive(character, "B") then return end

    local stats = character:getStats()
    local current = stats:get(CharacterStat.STRESS)
    if current < STRESS_FLOOR then
        stats:set(CharacterStat.STRESS, STRESS_FLOOR)
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
-- K: flat overall-health ceiling, -10 points (0-100 scale). CHANGED
-- 2026-09-22, per further explicit request, from the CharacterStat.
-- DISCOMFORT floor 45 this function used through v0.6.5 -- DISCOMFORT
-- itself was NOT broken (kept here as history, not deleted, per this
-- file's own policy):
--
-- K: CharacterStat.DISCOMFORT floor 45 (0-100 scale, drives vanilla's
-- real "Uncomfortable" moodle -- confirmed via decompiling Moodle.class:
-- that moodle reads `getStats():get(CharacterStat.DISCOMFORT)` alone, no
-- combination with anything else, compared against MoodleStat.
-- UNCOMFORTABLE's own registered thresholds 20/40/60/80 for A Little
-- Uncomfortable / Uncomfortable / Very Uncomfortable / Extremely
-- Uncomfortable -- 45 comfortably clears the 2nd tier).
--
-- NOT the first choice EITHER. CharacterStat.SICKNESS (the obviously
-- "correct"-sounding stat, and the mod's own target through v0.6.4) was
-- CONFIRMED, via a real user report ("resets to 0 constantly") plus a
-- read-back diagnostic print left in this function for one test session,
-- to get wiped every single ~10-second re-enforcement cycle. Root cause:
-- this had NOTHING to do with our own code -- it's a genuine conflict
-- with the "Extensive Health Rework Evolved" mod (Workshop 3726328119, a
-- soft dependency of this repo's own HARMONIE_HomeMedic), whose
-- EHR_Disease.lua runs an every-single-game-tick "vanilla sickness sync"
-- that explicitly zeroes CharacterStat.SICKNESS (and FOOD_SICKNESS,
-- POISON) whenever EHR's OWN disease system has nothing active for that
-- character, on the assumption any nonzero value must be leftover
-- residue from a cured illness. EHR's every-tick check always wins the
-- race against our slower 10-second one. Grepping EHR's entire Lua
-- source for every `stats:set(CharacterStat.X` confirms it also writes
-- (less aggressively, only under specific disease conditions rather than
-- an unconditional per-tick sweep) to BOREDOM/ENDURANCE/FATIGUE/HUNGER/
-- PAIN/PANIC/STRESS/TEMPERATURE/THIRST/UNHAPPINESS/WETNESS/ZOMBIE_FEVER/
-- ZOMBIE_INFECTION too -- DISCOMFORT was one of the few CharacterStat
-- values EHR's codebase never writes to at all, hence that switch. Same
-- general lesson as this file's own BleedingTime/FOOD_SICKNESS traps, one
-- level up: confirming a write persists in isolation isn't enough when
-- another active mod also claims the same stat -- check what ELSE is
-- installed before trusting a "correct-looking" stat long-term.
--
-- The NEW mechanism below sidesteps needing to re-litigate any of that:
-- it uses the exact same bodyDamage:ReduceGeneralHealth() ceiling pattern
-- as MaintainEnduranceCap's health-cap predecessor did (see that
-- function's own header-block history) -- health isn't claimed by EHR the
-- way SICKNESS/FOOD_SICKNESS/POISON are (EHR only reduces health as a
-- SYMPTOM of its own tracked diseases, never as an unconditional per-tick
-- reset of an idle value), and a real vanilla wound/health system has no
-- equivalent "residue cleanup" sweep the way the disease-stat cluster
-- does.
-- ---------------------------------------------------------------------
local K_HEALTH_REDUCTION = 10

function VitEffects.MaintainKHealthCap(character)
    if not HARMONIE_GTP.Config.effectsEnabled then return end
    if not isActive(character, "K") then return end

    local bodyDamage = character:getBodyDamage()
    if not bodyDamage or not bodyDamage.getOverallBodyHealth or not bodyDamage.ReduceGeneralHealth then return end

    local healthCap = 100 - K_HEALTH_REDUCTION
    local currentHealth = bodyDamage:getOverallBodyHealth()
    if currentHealth > healthCap then
        bodyDamage:ReduceGeneralHealth(currentHealth - healthCap)
    end
end

--[[
    Universal effect, independent of which specific vitamins are
    afflicted: every currently afflicted-and-not-pause-shielded vitamin
    caps CharacterStat.ENDURANCE (0-1 scale) 10 percentage points lower
    each, stacking -- 3 vitamins afflicted at once means Endurance can
    never recover above 0.70. CHANGED 2026-09-22, per explicit request,
    from the original "-5% overall health per affliction" (kept as history
    below, not deleted): health duty moved to K's own individual
    MaintainKHealthCap instead, freeing this universal slot up for
    Endurance, which itself was freed up when B moved off its old fixed
    0.80 Endurance ceiling onto Stress (see this file's header). Avoids
    double-counting health from two different mechanisms firing at once.

    ORIGINAL (v0.5.0-v0.6.5) health-cap version, preserved for the
    technique it proved rather than deleted: capped overall body health
    (bodyDamage:getOverallBodyHealth(), 0-100) 5 percentage points lower
    per affliction, via bodyDamage:ReduceGeneralHealth(amount), NOT
    setOverallBodyHealth directly -- confirmed real pattern from Extensive
    Health Rework Evolved's own EHR_EnvironmentalClampBodyHealth
    (EHR_EnvironmentalDiseases.lua), a mature, actively-used mod already a
    soft dependency of HARMONIE_HomeMedic in this same repo. The NEW
    Endurance version below reuses the exact same "only ever reduce
    toward a cap, never below it, no-op once already under the cap"
    ceiling shape -- via stats:set instead of ReduceGeneralHealth since
    Endurance is a plain CharacterStat, not a BodyDamage value -- so
    vanilla's own regen fully takes back over the moment fewer vitamins
    are afflicted, same as every other floor/ceiling in this file.
]]--
local ENDURANCE_CAP_PERCENT_PER_AFFLICTION = 0.10

function VitEffects.MaintainEnduranceCap(character)
    if not HARMONIE_GTP.Config.effectsEnabled then return end

    local afflictedCount = 0
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if isActive(character, vit) then
            afflictedCount = afflictedCount + 1
        end
    end
    if afflictedCount == 0 then return end

    local stats = character:getStats()
    local enduranceCap = 1.0 - (ENDURANCE_CAP_PERCENT_PER_AFFLICTION * afflictedCount)
    enduranceCap = math.max(0, enduranceCap)

    local current = stats:get(CharacterStat.ENDURANCE)
    if current > enduranceCap then
        stats:set(CharacterStat.ENDURANCE, enduranceCap)
    end
end

-- Human-readable summary of what actually applies for each vitamin --
-- used only by LogEffectStateChange below, purely for the console
-- message text.
local EffectDescription = {
    A = "night blindness: 30% of hit damage taken back (50% at night)",
    B = "CharacterStat.STRESS floor 0.30 (tingling/headaches/fatigue -> stress)",
    C = "random Head scratch, 1 game hour / 5% chance (nosebleed/bleeding gums)",
    D = "per-body-part Stiffness floor 20, all body parts (muscle strain)",
    E = "CharacterStat.UNHAPPINESS floor 30 (slower item handling)",
    K = "flat overall-health ceiling -10 (weakened condition -- slower recovery)",
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

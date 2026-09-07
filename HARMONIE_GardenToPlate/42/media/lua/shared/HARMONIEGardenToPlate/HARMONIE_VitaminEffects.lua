--[[
    HARMONIE - From Garden to Plate
    Applies the per-day penalty for each vitamin currently afflicted (see
    the hysteresis note in HARMONIE_VitaminConfig.lua). Called once per
    in-game day (via HARMONIE_VitaminChecker.lua's 10-second responsive
    check, guarded by lastEffectDay so it still only actually fires once
    per day) for every vitamin where
    HARMONIE_GTP.VitData.IsAfflicted(character, vit) is true.

    Every vitamin's penalty is the SAME flat Config.effects[vit].amount
    every time it fires -- applied once immediately on the day it becomes
    Critical, then again every subsequent day it stays Critical, with no
    ramp-up curve and no cap. Staying Critical a long time keeps making it
    worse, deliberately and indefinitely.

    A (Vision Impaired) pushes CharacterStat.PANIC up to trigger vanilla's
    own native panic-driven tunnel vision / narrowed screen effect -- no
    custom rendering, just leaning on an existing vanilla visual cue.

    ApplyCritical is a no-op while the vitamin has banked pause days
    (HARMONIE_GTP.VitData.GetPauseDays > 0) -- gained from eating well, or
    +1 per vitamin from taking Base.PillsVitamins with no Reserve gain (see
    HARMONIE_PillsHook.lua). That only silences the SYMPTOM -- Reserve and
    the affliction flag itself are untouched, so the penalty comes right
    back once the banked day(s) are consumed by the next daily tick(s) if
    the underlying deficiency was never actually fixed by eating.

    Each time the penalty actually fires, the character also says one of a
    few in-character symptom lines (SymptomLineKeys below) -- worded as
    something a real person would notice and say about THEMSELVES (dry
    eyes, sore gums, aching bones...), never naming the vitamin, since a
    survivor has no lab to tell them that's the actual cause.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.VitEffects = {}
local VitEffects = HARMONIE_GTP.VitEffects

local function reduceHealingOnWounds(character, amount)
    local bodyParts = character:getBodyDamage():getBodyParts()
    for i = 0, bodyParts:size() - 1 do
        local bodyPart = bodyParts:get(i)
        if bodyPart:getHealth() < 100 then
            bodyPart:setHealth(math.max(0, bodyPart:getHealth() - amount))
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
local RECOVERY_CHANCE_PERCENT = 100 -- TEMP: bumped from 80 for easy Thai-text testing, dial back down after
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

-- effect handlers keyed by vitamin letter; each receives (character, effectCfg)
local Handlers = {
    A = function(character, cfg)
        character:getStats():add(CharacterStat.PANIC, cfg.amount * HARMONIE_GTP.Config.effectMultiplier)
    end,

    B = function(character, cfg)
        local amount = cfg.amount * HARMONIE_GTP.Config.effectMultiplier
        character:addArmMuscleStrain(amount)
        character:addBackMuscleStrain(amount)
    end,

    C = function(character, cfg)
        character:getStats():add(CharacterStat.SICKNESS, cfg.amount * HARMONIE_GTP.Config.effectMultiplier)
    end,

    D = function(character, cfg)
        character:getStats():add(CharacterStat.PAIN, cfg.amount * HARMONIE_GTP.Config.effectMultiplier)
    end,

    E = function(character, cfg)
        character:getStats():add(CharacterStat.STRESS, cfg.amount * HARMONIE_GTP.Config.effectMultiplier)
    end,

    K = function(character, cfg)
        reduceHealingOnWounds(character, cfg.amount * HARMONIE_GTP.Config.effectMultiplier)
    end,
}

function VitEffects.ApplyCritical(character, vit)
    if not HARMONIE_GTP.Config.effectsEnabled then return end
    if HARMONIE_GTP.VitData.GetPauseDays(character, vit) > 0 then return end
    local cfg = HARMONIE_GTP.Config.effects[vit]
    local handler = Handlers[vit]
    if cfg and handler then
        handler(character, cfg)
        sayRandomSymptom(character, vit)
    end
end

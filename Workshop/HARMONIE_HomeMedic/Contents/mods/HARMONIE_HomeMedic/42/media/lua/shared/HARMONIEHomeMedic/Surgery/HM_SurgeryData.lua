--[[
    HARMONIE - Home Medic : surgery system data (shared)

    Surgery TYPES are built from reusable PROCEDURES (P01..P15), each
    procedure being one minigame, so a new operation is just a new list of
    steps (request 2026-09-30).

    Outcome (request 2026-09-30, round 2): a successful operation puts the
    condition on TREATMENT (EHR's "treating" state: it stops getting worse
    and clears after `treat` hours -- shorter after an excellent operation).
    Diseases listed in S.SURGICAL need surgery once they reach that stage:
    a finished medicine course then only HOLDS them ("awaiting surgery",
    the stage no longer rises) instead of curing them. Everything else is
    still cured by medicine alone, as in EHR.

    Unlocks: a procedure needs First Aid at its tier; an operation may also
    need knowledge of one of its diseases the EHR way (flyer, or First Aid 8).
]]--

HM_Surgery = HM_Surgery or {}
local S = HM_Surgery

S.TIERS = {
    field    = { order = 1, firstAid = 2 },
    clinical = { order = 2, firstAid = 4 },
    advanced = { order = 3, firstAid = 6 },
    master   = { order = 4, firstAid = 8 },
}
S.TIER_ORDER = { "field", "clinical", "advanced", "master" }

-- Procedures: `game` + `variant` pick the minigame (HM_SurgeryGames.lua).
S.Procedures = {
    P01 = { game = "trace",    tier = "field",    weight = 1.0 },                                      -- Incision
    P02 = { game = "pulse",    tier = "field",    weight = 1.0 },                                      -- Hemostasis
    P03 = { game = "clean",    tier = "clinical", weight = 1.0, knowledge = { "wound_infection", "cellulitis", "sepsis", "hyperkeratotic_scabies", "trichinosis", "toxin_poisoning" } }, -- Irrigation
    P04 = { game = "necro",    tier = "clinical", weight = 1.5, knowledge = { "cellulitis", "sepsis", "tetanus", "wound_infection", "hyperkeratotic_scabies" } }, -- Necrectomy
    P05 = { game = "gauge",    tier = "clinical", weight = 1.5, knowledge = { "cellulitis", "wound_infection" } }, -- Aspiration
    P06 = { game = "extract",  tier = "clinical", weight = 1.5 },                                      -- Extraction
    P07 = { game = "gauge",    variant = "saw",   tier = "advanced", weight = 1.5 },                   -- Bone cut
    P08 = { game = "suture",   tier = "field",    weight = 1.0 },                                      -- Closure
    P09 = { game = "gauge",    variant = "valve", tier = "advanced", weight = 1.0 },                   -- Drainage
    P10 = { game = "trace",    variant = "catheter", tier = "master", weight = 1.0 },                  -- Catheterization
    P11 = { game = "dialysis", tier = "master",   weight = 1.5 },                                      -- Blood purification
    P12 = { game = "cells",    tier = "master",   weight = 1.5 },                                      -- Cell graft
    P13 = { game = "gauge",    variant = "drill", tier = "master", weight = 1.5 },                     -- Craniotomy
    P14 = { game = "extract",  variant = "clot",  tier = "master", weight = 1.5 },                     -- Hematoma evacuation
    P15 = { game = "necro",    variant = "organ", tier = "advanced", weight = 1.5 },                   -- Organ repair
}

-- Supplies: first option found wins (inventory incl. bags, floor, containers within reach).
S.Supplies = {
    blade = { kind = "tool", required = true, options = {
        { type = "Base.Scalpel", q = 1.0 }, { match = "scalpel", q = 1.0 }, { match = "knife", q = 0.55 },
        { match = "razor", q = 0.6 }, { match = "blade", q = 0.4 } } },
    forceps = { kind = "tool", required = true, options = {
        { type = "Base.SutureNeedleHolder", q = 1.0 }, { type = "Base.Tweezers", q = 0.8 }, { match = "tweezers", q = 0.8 },
        { match = "pliers", q = 0.45 } } },
    suture = { kind = "use", required = true, options = {
        { type = "Base.SutureNeedle", q = 1.0 }, { match = "suture", q = 1.0 },
        { type = "Base.Thread", q = 0.55, needs = "Base.Needle" }, { match = "thread", q = 0.5, needs = "Base.Needle" },
        { type = "Base.Twine", q = 0.35, needs = "Base.Needle" } } },
    dressing = { kind = "use", required = true, options = {
        { type = "ExtensiveHealth.SterilizedBandages", q = 1.0 }, { type = "Base.AlcoholBandage", q = 1.0 },
        { type = "ExtensiveHealth.AlchoholicBandage", q = 1.0 }, { type = "Base.Bandage", q = 0.8 },
        { match = "bandage", q = 0.6 }, { match = "rag", q = 0.35 } } },
    syringe = { kind = "use", required = true, options = {
        { type = "ExtensiveHealth.Syringe", q = 1.0 }, { match = "syringe", q = 0.8 }, { type = "ExtensiveHealth.HomemadeSyringe", q = 0.6 } } },
    antiseptic = { kind = "use", required = false, options = {
        { type = "Base.AlcoholWipes", q = 1.0 }, { match = "disinfectant", q = 1.0 },
        { type = "ExtensiveHealth.AntisepticCream", q = 0.8 }, { type = "ExtensiveHealth.HomemadeAntisepticCream", q = 0.6 } } },
    saw = { kind = "tool", required = true, options = {
        { type = "Base.Saw", q = 1.0 }, { type = "Base.GardenSaw", q = 0.9 }, { match = "saw", q = 0.7 } } },
    drill = { kind = "tool", required = true, options = {
        { match = "drill", q = 1.0 }, { type = "Base.HandDrill", q = 0.9 }, { type = "Base.Screwdriver", q = 0.4 } } },
    ivkit = { kind = "use", required = true, options = {
        { type = "ExtensiveHealth.IVKit", q = 1.0 }, { type = "ExtensiveHealth.HomemadeIVKit", q = 0.6 } } },
    fluids = { kind = "use", required = true, options = {
        { type = "ExtensiveHealth.IVFluids", q = 1.0 }, { type = "ExtensiveHealth.SalineBag", q = 0.8 }, { match = "saline", q = 0.8 } } },
    genekit = { kind = "use", required = true, options = {
        { type = "ExtensiveHealth.GeneTherapyKit", q = 1.0 } } },
    -- transfusion during the operation (S.evaluate makes one of them required
    -- when the operation would leave the patient below S.TRANSFUSE_BELOW)
    blood = { kind = "use", required = false, transfusion = "blood", options = { { match = "bloodbag", q = 1.0 } } },
    saline = { kind = "use", required = false, transfusion = "saline", options = {
        { type = "ExtensiveHealth.SalineBag", q = 1.0 }, { match = "saline", q = 1.0 } } },
}

-- blood left after the operation below this (fraction of full) -> a blood
-- bag or saline is required; a compatible bag gives blood back, the wrong
-- type causes a transfusion reaction (AHTR), saline adds volume but dilutes.
S.TRANSFUSE_BELOW = 0.62

-- Request 2026-10-02: an operation leaves the patient weak for a while --
-- blood volume ends at POSTOP_MAX at most (just inside EHR's "moderate"
-- band: tired, slower), lower when the bleeding was badly controlled, down
-- to POSTOP_MIN (EHR's "critical" band: no endurance, blackouts).
S.POSTOP_MAX = 0.704
S.POSTOP_MIN = 0.555
-- hemostasis (P02) / incision (P01) scores 0..1 -> the most blood left
function S.postOpCap(hemo, incision)
    local q = 0.65 * (tonumber(hemo) or 0.5) + 0.35 * (tonumber(incision) or 0.5)
    q = math.max(0, math.min(1, q))
    return S.POSTOP_MIN + (S.POSTOP_MAX - S.POSTOP_MIN) * q
end

-- Body-part groups
local LIMBS = { "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }
local ARMS  = { "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R" }
local TOC_ARMS = { "Hand_L", "Hand_R", "ForeArm_L", "ForeArm_R", "UpperArm_L", "UpperArm_R" }

-- Operations.
--   targets[id] = { treat = hours }  -> EHR treatment on success (x0.6 if excellent)
--   special targets: wound_infection (clears the part), foreign_body, knox, knox_bite, necrosis
--   parts = allowed body parts (nil = any part with a wound)
--   knowledge = one of these diseases must be known (EHR flyers / First Aid 8)
S.Surgeries = {
    debridement = { tier = "clinical",
        steps = { "P01", "P04", "P03", "P02", "P08" },
        supplies = { "blade", "forceps", "suture", "dressing", "antiseptic", "blood", "saline" },
        bloodLoss = 250, pain = 55,
        targets = { wound_infection = {}, cellulitis = { treat = 24 }, tetanus = { treat = 48 },
                    sepsis = { treat = 36 }, hyperkeratotic_scabies = { treat = 24, anyPart = true } } },
    abscess_drainage = { tier = "clinical",
        steps = { "P01", "P05", "P03", "P08" },
        supplies = { "blade", "syringe", "suture", "dressing", "antiseptic", "blood", "saline" },
        bloodLoss = 120, pain = 40,
        targets = { wound_infection = {}, cellulitis = { treat = 24 } } },
    foreign_body = { tier = "clinical",
        steps = { "P01", "P06", "P02", "P08" },
        supplies = { "blade", "forceps", "suture", "dressing", "antiseptic", "blood", "saline" },
        bloodLoss = 150, pain = 45,
        targets = { foreign_body = {} } },
    parasite_extraction = { tier = "advanced", parts = LIMBS, knowledge = { "trichinosis" },
        steps = { "P01", "P06", "P03", "P08" },
        supplies = { "blade", "forceps", "suture", "dressing", "antiseptic", "blood", "saline" },
        bloodLoss = 200, pain = 50,
        targets = { trichinosis = { treat = 48, anyPart = true } } },
    thoracic = { tier = "advanced", parts = { "Torso_Upper" }, knowledge = { "pneumonia", "cadaveric_aspergillosis" },
        steps = { "P01", "P15", "P09", "P08" },
        supplies = { "blade", "forceps", "syringe", "suture", "dressing", "antiseptic", "blood", "saline" },
        bloodLoss = 450, pain = 70,
        targets = { pneumonia = { treat = 48, anyPart = true }, cadaveric_aspergillosis = { treat = 72, anyPart = true } } },
    organ_salvage = { tier = "advanced", parts = { "Torso_Lower" }, knowledge = { "sepsis", "toxin_poisoning" },
        steps = { "P01", "P15", "P03", "P08" },
        supplies = { "blade", "forceps", "suture", "dressing", "antiseptic", "blood", "saline" },
        bloodLoss = 500, pain = 70,
        targets = { sepsis = { treat = 24, anyPart = true }, toxin_poisoning = { treat = 24, anyPart = true } } },
    neurosurgery = { tier = "master", parts = { "Head" }, knowledge = { "concussion" },
        steps = { "P13", "P14", "P02", "P08" },
        supplies = { "drill", "forceps", "suture", "dressing", "antiseptic", "blood", "saline" },
        bloodLoss = 300, pain = 60,
        -- concussion heals by itself; the operation (hematoma evacuation)
        -- ends it at once, with all its symptoms
        targets = { concussion = { cure = true, anyPart = true } } },
    blood_purification = { tier = "master", parts = ARMS, knowledge = { "ahtr" },
        steps = { "P10", "P11", "P02" },
        supplies = { "ivkit", "fluids", "antiseptic" },
        bloodLoss = 60, pain = 15,
        targets = { ahtr = { treat = 24, anyPart = true } } },
    amputation = { tier = "master", parts = TOC_ARMS, needsTOC = true,
        steps = { "P01", "P07", "P02", "P08" },
        supplies = { "blade", "saw", "suture", "dressing", "antiseptic", "blood", "saline" },
        bloodLoss = 700, pain = 90,
        targets = { knox_bite = {}, necrosis = {} } },
    experimental = { tier = "master", parts = ARMS, knowledge = { "knox_infection" },
        steps = { "P10", "P12", "P11" },
        supplies = { "ivkit", "genekit", "fluids", "antiseptic" },
        bloodLoss = 80, pain = 30,
        targets = { knox = {} } },
}
-- Operations nobody can do on themselves (chest, abdomen, skull, dialysis,
-- gene therapy). A -debug game or a server admin may anyway (S.privileged).
S.NO_SELF = { thoracic = true, organ_salvage = true, neurosurgery = true, blood_purification = true, experimental = true }

-- Aspiration: operating on someone who has just eaten. HUNGER below this
-- = a full stomach; the chance (%) is raised when the patient is asleep or
-- sedated (no swallowing reflex). Outcome: aspiration pneumonia.
S.FULL_STOMACH_HUNGER = 0.12
S.ASPIRATION_CHANCE = 15
S.ASPIRATION_CHANCE_SEDATED = 35

S.SURGERY_ORDER = { "debridement", "abscess_drainage", "foreign_body", "parasite_extraction", "thoracic",
    "organ_salvage", "neurosurgery", "blood_purification", "amputation", "experimental" }

-- Diseases that need surgery from this stage on: medicine alone only holds them.
S.SURGICAL = {
    cellulitis = 3, sepsis = 3, tetanus = 3, trichinosis = 3, pneumonia = 3,
    cadaveric_aspergillosis = 3, toxin_poisoning = 3, hyperkeratotic_scabies = 3, ahtr = 3,
}

S.SUCCESS = 0.45            -- quality needed for the operation to help
S.EXCELLENT = 0.80          -- faster recovery (treat hours x 0.6)
S.EXCELLENT_TREAT = 0.6
S.COOLDOWN_HOURS = 24       -- one operation per condition per day
S.REACH = 1                 -- tiles around the doctor searched for supplies
S.MAX_DISTANCE = 2.2
S.PERMIT_MS = 20 * 60 * 1000
S.TREATMENT_SOURCE = "HARMONIE_Surgery"

S.WOUND_METHODS = { "isInfectedWound", "deepWounded", "isCut", "scratched", "bitten", "stitched", "bandaged", "HasInjury", "haveBullet", "haveGlass" }

-- Which operations treat a disease (for the handbook / hold hints).
function S.surgeriesFor(id)
    local out = {}
    for _, sid in ipairs(S.SURGERY_ORDER) do
        local s = S.Surgeries[sid]
        if s and s.targets[id] then out[#out + 1] = sid end
    end
    return out
end

return S

--[[
    HARMONIE - Home Medic : surgery system data (shared)

    Request 2026-09-30: surgery TYPES are built from reusable PROCEDURES
    (P01..P15), each procedure being one minigame, so a new operation is
    just a new list of steps. Phase 1 turns on the Field + Clinical
    procedures (P01 P02 P03 P04 P05 P08) and two operations (Debridement,
    Abscess Drainage); everything marked `planned` is here so the whole
    plan lives in one place, but is not offered in game yet.

    Procedure unlock (request: "สกิลที่ต้องใช้ในแต่ละกรรมวิธีให้ปลดตามการปลด
    ความรู้เรื่องโรคที่มีอยู่ใน ehr"): First Aid at the tier's level AND, when a
    procedure lists `knowledge`, knowing one of those diseases the EHR way
    (a disease flyer read, or First Aid 8 -- EHR.DiseaseFlyers.HasMedicalKnowledge).

    Text: every name / tooltip is a translation key UI_HomeMedic_Surg_* (EN + TH).
]]--

HM_Surgery = HM_Surgery or {}
local S = HM_Surgery

-- Tiers: Field (basic) -> Clinical -> Advanced -> Master.
S.TIERS = {
    field    = { order = 1, firstAid = 2 },
    clinical = { order = 2, firstAid = 4 },
    advanced = { order = 3, firstAid = 6 },
    master   = { order = 4, firstAid = 8 },
}
S.TIER_ORDER = { "field", "clinical", "advanced", "master" }

-- Reusable procedures. `game` = minigame type (client/HARMONIEHomeMedic/Surgery/HM_SurgeryGames.lua).
-- `weight` = share of the operation's quality. `knowledge` = EHR disease ids (any one unlocks).
S.Procedures = {
    P01 = { game = "trace",  tier = "field",    weight = 1.0 },                                            -- Incision
    P02 = { game = "pulse",  tier = "field",    weight = 1.0 },                                            -- Hemostasis
    P03 = { game = "clean",  tier = "clinical", weight = 1.0, knowledge = { "wound_infection", "cellulitis" } },  -- Irrigation
    P04 = { game = "necro",  tier = "clinical", weight = 1.5, knowledge = { "cellulitis", "sepsis", "tetanus", "wound_infection" } }, -- Necrotic excision
    P05 = { game = "gauge",  tier = "clinical", weight = 1.5, knowledge = { "cellulitis", "wound_infection" } },  -- Pus aspiration
    P08 = { game = "suture", tier = "field",    weight = 1.0 },                                            -- Wound closure
    -- Later phases (data only, not offered yet)
    P06 = { planned = true, tier = "clinical" },   -- Foreign body extraction
    P07 = { planned = true, tier = "master" },     -- Bone cut (The Only Cure's saw)
    P09 = { planned = true, tier = "advanced" },   -- Fluid drainage
    P10 = { planned = true, tier = "master" },     -- Catheterization
    P11 = { planned = true, tier = "master" },     -- Blood purification
    P12 = { planned = true, tier = "master" },     -- Cell graft
    P13 = { planned = true, tier = "master" },     -- Craniotomy drill
    P14 = { planned = true, tier = "master" },     -- Hematoma evacuation
    P15 = { planned = true, tier = "advanced" },   -- Organ work
}

-- Supplies. Each slot is filled by the best option found on the doctor,
-- on the floor or in a container within reach (HM_Surgery.Sources).
--   kind = "tool" (kept) or "use" (consumed when the operation starts)
--   options: { type = full type | match = predicate name, q = quality 0..1, uses = n }
--   needs = another full type that must also be at hand (kept)
S.Supplies = {
    blade = { kind = "tool", required = true, options = {
        { type = "Base.Scalpel", q = 1.0 },
        { match = "knife", q = 0.55 },
    } },
    forceps = { kind = "tool", required = true, options = {
        { type = "Base.SutureNeedleHolder", q = 1.0 },
        { type = "Base.Tweezers", q = 0.8 },
    } },
    suture = { kind = "use", required = true, options = {
        { type = "Base.SutureNeedle", q = 1.0 },
        { type = "Base.Thread", q = 0.55, needs = "Base.Needle" },
    } },
    dressing = { kind = "use", required = true, options = {
        { type = "ExtensiveHealth.SterilizedBandages", q = 1.0 },
        { type = "Base.AlcoholBandage", q = 1.0 },
        { type = "ExtensiveHealth.AlchoholicBandage", q = 1.0 },
        { type = "Base.Bandage", q = 0.8 },
        { match = "bandage", q = 0.6 },
    } },
    syringe = { kind = "use", required = true, options = {
        { type = "ExtensiveHealth.Syringe", q = 1.0 },
        { type = "ExtensiveHealth.HomemadeSyringe", q = 0.6 },
    } },
    antiseptic = { kind = "use", required = false, options = {
        { type = "Base.AlcoholWipes", q = 1.0 },
        { match = "disinfectant", q = 1.0 },
        { type = "ExtensiveHealth.AntisepticCream", q = 0.8 },
        { type = "ExtensiveHealth.HomemadeAntisepticCream", q = 0.6 },
    } },
}

-- Operations. `targets`: what it does to each condition it treats.
--   reduce   = stages removed on success (quality >= S.SUCCESS)
--   bonus    = one more stage removed on an excellent result (>= S.EXCELLENT)
--   floor    = lowest stage it can bring the disease to (1 = never a cure on its own)
S.Surgeries = {
    debridement = {
        tier = "clinical", icon = "D",
        steps = { "P01", "P04", "P03", "P02", "P08" },
        supplies = { "blade", "forceps", "suture", "dressing", "antiseptic" },
        bloodLoss = 250, pain = 55,
        targets = {
            wound_infection = { reduce = 1, bonus = 1, floor = 0 },
            cellulitis      = { reduce = 1, bonus = 1, floor = 0 },
            tetanus         = { reduce = 1, floor = 1 },
            sepsis          = { reduce = 1, floor = 1 },
        },
    },
    abscess_drainage = {
        tier = "clinical", icon = "A",
        steps = { "P01", "P05", "P03", "P08" },
        supplies = { "blade", "syringe", "suture", "dressing", "antiseptic" },
        bloodLoss = 120, pain = 40,
        targets = {
            wound_infection = { reduce = 1, bonus = 1, floor = 0 },
            cellulitis      = { reduce = 1, floor = 0 },
        },
    },
    -- Later phases (data only)
    parasite_extraction = { planned = true, tier = "advanced", steps = { "P01", "P06", "P08" } },
    thoracic            = { planned = true, tier = "advanced", steps = { "P01", "P15", "P09", "P08" } },
    neurosurgery        = { planned = true, tier = "master",   steps = { "P13", "P14", "P02", "P08" } },
    organ_salvage       = { planned = true, tier = "advanced", steps = { "P01", "P15", "P03", "P08" } },
    amputation          = { planned = true, tier = "master",   steps = { "P01", "P07", "P02", "P08" } },
    experimental        = { planned = true, tier = "master",   steps = { "P10", "P12", "P11" } },
}
S.SURGERY_ORDER = { "debridement", "abscess_drainage" }

S.SUCCESS = 0.45            -- quality needed for the operation to help
S.EXCELLENT = 0.80          -- quality for the bonus stage
S.COOLDOWN_HOURS = 24       -- the same condition can be operated on once a day
S.REACH = 1                 -- tiles around the doctor searched for supplies
S.MAX_DISTANCE = 2.2        -- doctor <-> patient
S.PERMIT_MS = 20 * 60 * 1000

-- Which vanilla wound flags count as "a wound to operate through".
S.WOUND_METHODS = { "isInfectedWound", "deepWounded", "isCut", "scratched", "bitten", "stitched", "bandaged", "HasInjury" }

return S

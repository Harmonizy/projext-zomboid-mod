--[[
    HARMONIE - Home Medic : surgery system data (shared)

    Surgery TYPES are built from reusable PROCEDURES (P01..P15), each
    procedure being one minigame, so a new operation is just a new list of
    steps (request 2026-09-30).

    Outcome (request 2026-09-30, round 2): a successful operation puts the
    condition on TREATMENT (EHR's "treating" state: it stops getting worse
    and clears after `treat` hours -- shorter after an excellent operation).
    Diseases listed in S.SURGICAL need surgery: their medicine only HOLDS
    them ("awaiting surgery", the stage no longer rises) instead of curing
    them, and the operation then starts the treatment. Everything else is
    still cured by medicine alone, as in EHR.

    Skill (2026-10-10): nothing is locked by First Aid or disease knowledge
    any more. Each tier has a RECOMMENDED First Aid level; below it (or
    without knowing the disease) the games are much harder and the pre-op
    list and the consent form warn that it is life-threatening, above it
    they get easier. Only The Only Cure (amputation) and "not on yourself"
    still block.
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
-- `tier` = the RECOMMENDED First Aid level (owner, 2026-10-10: "ทุกคนสามารถ
-- ผ่าตัดได้ทุกประเภท แต่ยากขึ้นหากไม่ถึงเกณฑ์"): nothing is locked by skill any
-- more, below it every game is much harder (S.difficulty), above it easier.
-- `tool` = the supply slot whose quality changes how this step handles
-- (a kitchen knife cuts less precisely than a scalpel, a screwdriver
-- drills worse than a drill); nil = the step uses no specific instrument.
-- `effects` = what the step reports besides its score (S.EFFECT_KEYS),
-- each 0..1, used by the server for the outcome.
S.Procedures = {
    P01 = { game = "trace",    tier = "field",    weight = 1.0, tool = "blade" },                       -- Incision
    P02 = { game = "pulse",    tier = "field",    weight = 1.0, tool = "forceps" },                     -- Hemostasis
    P03 = { game = "clean",    tier = "clinical", weight = 1.0, tool = "syringe", knowledge = { "wound_infection", "cellulitis", "sepsis", "hyperkeratotic_scabies", "trichinosis", "toxin_poisoning" } }, -- Irrigation
    P04 = { game = "necro",    tier = "clinical", weight = 1.5, tool = "blade", knowledge = { "cellulitis", "sepsis", "tetanus", "wound_infection", "hyperkeratotic_scabies" } }, -- Necrectomy
    P05 = { game = "gauge",    tier = "clinical", weight = 1.5, tool = "syringe", knowledge = { "cellulitis", "wound_infection" } }, -- Aspiration
    P06 = { game = "extract",  tier = "clinical", weight = 1.5, tool = "forceps" },                     -- Extraction
    P07 = { game = "gauge",    variant = "saw",   tier = "advanced", weight = 1.5, tool = "saw" },      -- Bone cut
    P08 = { game = "suture",   tier = "field",    weight = 1.0, tool = "suture" },                      -- Closure
    P09 = { game = "gauge",    variant = "valve", tier = "advanced", weight = 1.0, tool = "syringe" },  -- Drainage
    P10 = { game = "trace",    variant = "catheter", tier = "master", weight = 1.0, tool = "ivkit" },   -- Catheterization
    P11 = { game = "dialysis", tier = "master",   weight = 1.5, tool = "fluids" },                      -- Blood purification
    P12 = { game = "cells",    tier = "master",   weight = 1.5, tool = "genekit" },                     -- Cell graft
    P13 = { game = "gauge",    variant = "drill", tier = "master", weight = 1.5, tool = "drill" },      -- Craniotomy
    P14 = { game = "extract",  variant = "clot",  tier = "master", weight = 1.5, tool = "forceps" },    -- Hematoma evacuation
    P15 = { game = "necro",    variant = "organ", tier = "advanced", weight = 1.5, tool = "blade" },    -- Organ repair
}

-- Side effects a step can report (0..1 each; HM_SurgeryGames :effects()).
-- The server takes only these keys and clamps them.
--   tissue   -- healthy tissue hurt (slips, wrong cuts, crushing, overpressure)
--   bleed    -- bleeding left uncontrolled at the end of the step
--   dirt     -- contamination left in the wound
--   residual -- what should have come out and did not (pus, a bullet, a clot, necrosis)
--   misplace -- the catheter is not where it should be
--   neuro    -- injury to the brain (drill plunge, suction on healthy brain)
--   organ    -- organ function lost (unrepaired damage, healthy tissue resected)
--   tension  -- stitches tied too tight (skin edges blanch and may tear)
--   gap      -- wound edges left apart between stitches
S.EFFECT_KEYS = { "tissue", "bleed", "dirt", "residual", "misplace", "neuro", "organ", "tension", "gap" }

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
    -- transfusion slots: no longer part of any operation (request
    -- 2026-10-02: the operation itself leaves the patient low on blood, see
    -- S.postOpBlood); kept so old references still resolve
    blood = { kind = "use", required = false, transfusion = "blood", options = { { match = "bloodbag", q = 1.0 } } },
    saline = { kind = "use", required = false, transfusion = "saline", options = {
        { type = "ExtensiveHealth.SalineBag", q = 1.0 }, { match = "saline", q = 1.0 } } },
}

-- blood left after the operation below this (fraction of full) -> a blood
-- bag or saline is required; a compatible bag gives blood back, the wrong
-- type causes a transfusion reaction (AHTR), saline adds volume but dilutes.
S.TRANSFUSE_BELOW = 0.62

-- Request 2026-10-02: proper instruments start the operation at 100%;
-- each improvised one (supply option q < 1: a kitchen knife for a scalpel,
-- thread for suture, a rag for a dressing...) lowers the STARTING quality,
-- one factor per kind of supply, multiplied: 1 - (1 - q) * IMPROVISED_COST.
-- Round 2026-10-10: the instrument also changes how its own step handles
-- (Procedures[].tool), so the starting penalty is halved.
S.IMPROVISED_COST = 0.15

-- Blood after the operation (owner, 2026-10-10: "penalty จากการผ่าตัดที่พลาด
-- ทำให้ปริมาณเลือดลดลงอย่างมาก เสี่ยงตาย เกณฑ์ผ่าตัดยอดเยี่ยมให้ลดปริมาณเลือด
-- 90% แทน และลดลงตามลำดับที่ต่ำลง"): the patient ends at most at
--   excellent (quality >= S.EXCELLENT)  POSTOP_EXCELLENT  90%
--   just successful (S.SUCCESS)          POSTOP_SUCCESS    72%  (EHR "moderate")
--   a complete failure (quality 0)       POSTOP_FLOOR      20%  (EHR: under 20%
--                                                              the heart can stop)
-- linear in between; uncontrolled bleeding (P02 `bleed`) takes up to
-- POSTOP_BLEED more. Someone who comes in already low ends lower still.
S.POSTOP_EXCELLENT = 0.90
S.POSTOP_SUCCESS = 0.72
S.POSTOP_FLOOR = 0.20
S.POSTOP_BLEED = 0.08
function S.postOpBlood(q, bleed)
    q = math.max(0, math.min(1, tonumber(q) or 0))
    local f
    if q >= S.EXCELLENT then
        f = S.POSTOP_EXCELLENT
    elseif q >= S.SUCCESS then
        f = S.POSTOP_SUCCESS + (S.POSTOP_EXCELLENT - S.POSTOP_SUCCESS) * (q - S.SUCCESS) / (S.EXCELLENT - S.SUCCESS)
    else
        f = S.POSTOP_FLOOR + (S.POSTOP_SUCCESS - S.POSTOP_FLOOR) * q / S.SUCCESS
    end
    f = f - S.POSTOP_BLEED * math.max(0, math.min(1, tonumber(bleed) or 0))
    return math.max(0.05, f)
end

-- A serious complication can happen to anyone (owner's design doc: "ต้องมี
-- โอกาสล้มเหลว แม้ผู้เล่นมี Skill สูง"): % chance per operation, from the gap
-- between the surgeon's First Aid and the recommended level (S.skillGap).
-- It costs COMPLICATION_COST quality (an unexpected bleeder, a torn vessel).
S.COMPLICATION_BASE = 4
S.COMPLICATION_MIN = 1.5
S.COMPLICATION_PER_LEVEL_BELOW = 6
S.COMPLICATION_MAX = 35
S.COMPLICATION_COST = 0.25
function S.complicationChance(gap)
    gap = tonumber(gap) or 0
    local c
    if gap >= 0 then c = S.COMPLICATION_BASE - 0.6 * gap
    else c = S.COMPLICATION_BASE + S.COMPLICATION_PER_LEVEL_BELOW * (-gap) end
    return math.max(S.COMPLICATION_MIN, math.min(S.COMPLICATION_MAX, c))
end

-- Consent (owner, 2026-10-10: "หากการกระทำไหนมีความเสี่ยง ต้องได้รับการอนุมัติ
-- จากผู้ถูกทำเสมอ พร้อมบอกด้วยว่าเสี่ยงยังไง เพราะอะไร ขนาดไหน"): every
-- operation waits for the patient's answer, this long at most.
S.CONSENT_SECONDS = 60
-- a missing disease knowledge counts as this many First Aid levels below
S.KNOWLEDGE_GAP = 2

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
        supplies = { "blade", "forceps", "suture", "dressing", "antiseptic" },
        bloodLoss = 250, pain = 55,
        -- one operation per disease (owner, 2026-10-09): cellulitis is drained,
        -- sepsis goes to organ salvage
        targets = { wound_infection = {}, tetanus = { treat = 48 },
                    hyperkeratotic_scabies = { treat = 24, anyPart = true } } },
    abscess_drainage = { tier = "clinical",
        steps = { "P01", "P05", "P03", "P08" },
        supplies = { "blade", "syringe", "suture", "dressing", "antiseptic" },
        bloodLoss = 120, pain = 40,
        targets = { wound_infection = {}, cellulitis = { treat = 24 } } },
    foreign_body = { tier = "clinical",
        steps = { "P01", "P06", "P02", "P08" },
        supplies = { "blade", "forceps", "suture", "dressing", "antiseptic" },
        bloodLoss = 150, pain = 45,
        targets = { foreign_body = {} } },
    parasite_extraction = { tier = "advanced", parts = LIMBS, knowledge = { "trichinosis" },
        steps = { "P01", "P06", "P03", "P08" },
        supplies = { "blade", "forceps", "suture", "dressing", "antiseptic" },
        bloodLoss = 200, pain = 50,
        targets = { trichinosis = { treat = 48, anyPart = true } } },
    thoracic = { tier = "advanced", parts = { "Torso_Upper" }, knowledge = { "pneumonia", "cadaveric_aspergillosis" },
        steps = { "P01", "P15", "P09", "P08" },
        supplies = { "blade", "forceps", "syringe", "suture", "dressing", "antiseptic" },
        bloodLoss = 450, pain = 70,
        targets = { pneumonia = { treat = 48, anyPart = true }, cadaveric_aspergillosis = { treat = 72, anyPart = true } } },
    organ_salvage = { tier = "advanced", parts = { "Torso_Lower" }, knowledge = { "sepsis", "toxin_poisoning" },
        steps = { "P01", "P15", "P03", "P08" },
        supplies = { "blade", "forceps", "suture", "dressing", "antiseptic" },
        bloodLoss = 500, pain = 70,
        targets = { sepsis = { treat = 24, anyPart = true }, toxin_poisoning = { treat = 24, anyPart = true } } },
    neurosurgery = { tier = "master", parts = { "Head" }, knowledge = { "concussion" },
        steps = { "P13", "P14", "P02", "P08" },
        supplies = { "drill", "forceps", "suture", "dressing", "antiseptic" },
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
        supplies = { "blade", "saw", "suture", "dressing", "antiseptic" },
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

-- Diseases that need surgery (owner, 2026-10-09: "โรคที่มีการผ่าตัด อยากให้การกิน
-- ยาในการรักษาของโรคนั้นทำให้โรคเข้าสถานะ รอการผ่าตัด แล้วเมื่อผ่าตัดเสร็จค่อยเข้า
-- สถานะ กำลังรักษา"): from stage 1 -- taking their medicine puts them on
-- hold (AWAITING SURGERY) at once, the operation then starts TREATING.
-- Each has exactly one operation (S.surgeriesFor).
S.SURGICAL = {
    cellulitis = 1, sepsis = 1, tetanus = 1, trichinosis = 1, pneumonia = 1,
    cadaveric_aspergillosis = 1, toxin_poisoning = 1, hyperkeratotic_scabies = 1, ahtr = 1,
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

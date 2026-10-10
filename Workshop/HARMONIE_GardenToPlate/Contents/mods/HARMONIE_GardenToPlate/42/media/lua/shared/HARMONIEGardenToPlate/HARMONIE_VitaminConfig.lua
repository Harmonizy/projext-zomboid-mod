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
      - THIRD DESIGN (per explicit request, replacing the real-vanilla-
        trait system this mod used before): each vitamin now applies a
        DIRECT game-stat penalty instead of granting a real CharacterTrait
        -- see HARMONIE_VitaminEffects.lua's header for the full mapping
        and the real, confirmed-working PZ APIs each one uses
        (getStats():set(CharacterStat.X, ...), per-body-part Stiffness,
        and a real wound-creation sequence for the scratch effect).
        History, so this isn't tried blind a third time the same way
        twice: an EARLIER version of this mod (before the real-trait
        system) already tried continuous CharacterStat floor/ceiling
        effects and hit real, confirmed problems -- a one-shot daily dose
        gets erased by the stat's own natural regen before it's ever
        felt (fixed by re-enforcing the floor/ceiling every 10 seconds
        instead, not once a day -- this design keeps that fix), B's
        original real trait (Disorganized/bag capacity) has zero Lua
        exposure at all, and K's wound effect needs the exact two-step
        setScratched()+generateBleeding() sequence or nothing visible
        happens in-game. All of that history is preserved in git
        (commits 06944a6/4068598) and repeated here in
        HARMONIE_VitaminEffects.lua's header so the same mistakes aren't
        relearned the hard way a third time.

    Per-vitamin stat-penalty mapping (each vitamin's real-world deficiency
    symptom mapped to the closest PZ mechanic that's actually confirmed
    settable from Lua -- see HARMONIE_VitaminEffects.lua's header for the
    exact API calls and the full user-provided reasoning behind each):
      A -> (until 0.13.1; now night blindness: weaker hits) CharacterStat.INTOXICATION floor 30 (blurred vision -- weaker
           hits and harder ranged aim; deliberately no drunk-themed text
           anywhere, reused purely for the real vision-blur side effect)
      B -> CharacterStat.STRESS floor 0.30 (frequent tingling/numbness,
           anemia-driven headaches, and mild fatigue combining into stress)
      C -> random spontaneous Head scratch (bleeding gums/nosebleed),
           checked every 1 game hour, 5% chance per check
      D -> per-body-part Stiffness floor 20, ALL body parts (bone/muscle
           ache and weakness)
      E -> CharacterStat.UNHAPPINESS floor 30 (persistent unhappiness --
           slows down handling/moving items, standing in for impaired
           nerve/muscle coordination)
      K -> flat overall-health ceiling, -10 points (weakened overall
           condition, standing in for blood not clotting properly -- NOT
           a CharacterStat floor at all anymore; see
           HARMONIE_VitaminEffects.lua's MaintainKHealthCap for why, and
           for the still-preserved SICKNESS/DISCOMFORT history)
    PLUS a universal effect independent of which specific vitamins:
      every vitamin currently afflicted-and-not-pause-shielded caps
      CharacterStat.ENDURANCE (0-1 scale) 10 percentage points lower,
      stacking -- 3 vitamins afflicted at once means Endurance can never
      recover above 0.70.
    See HARMONIE_VitaminEffects.lua's header for the full citations
    behind each of these and VitEffects.MaintainEnduranceCap's own comment
    for the universal Endurance-cap mechanic (and its preserved health-cap
    history).

    All values here are rough real-world-approximate game-balance figures,
    not medical reference data. Vitamin "B" is a single stat standing in for
    the whole B-complex (B1/B2/B3/B6/B9/B12, which each have very different
    real RDAs); its daily requirement below is a simplified composite
    figure, not an official value for any one B vitamin. These defaults can
    be overridden live per-server through Sandbox Options or the in-game
    admin panel (see HARMONIE_AdminPanel.lua).
]]--

HARMONIE_GTP = HARMONIE_GTP or {}

--[[
    console.txt log (0.11.2). Every line starts with "[HARMONIE_GTP][tag]"
    and the side it ran on (SP / client / server), so a bug report's
    console.txt shows what this mod did and where. Search console.txt for
    "[HARMONIE_GTP]". Log(tag, fmt, ...) always prints; LogOnce(key, ...)
    prints the first time for that key only (for things that repeat every
    tick, so the log shows they happen without flooding it).
]]--
local function side()
    if isServer and isServer() then return "server" end
    if isClient and isClient() then return "client" end
    return "SP"
end
function HARMONIE_GTP.Log(tag, fmt, ...)
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    if not ok then
        local parts = { tostring(fmt) }
        for _, v in ipairs({ ... }) do parts[#parts + 1] = tostring(v) end
        msg = table.concat(parts, " ")
    end
    print("[HARMONIE_GTP][" .. tostring(tag) .. "][" .. side() .. "] " .. msg)
end
HARMONIE_GTP.LogSeen = HARMONIE_GTP.LogSeen or {}
function HARMONIE_GTP.LogOnce(key, tag, fmt, ...)
    if HARMONIE_GTP.LogSeen[key] then return end
    HARMONIE_GTP.LogSeen[key] = true
    HARMONIE_GTP.Log(tag, fmt, ...)
end

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
    decayPerDay = 2,
    -- Reserve gained = (percent of daily requirement eaten) / reserveGainDivisor
    reserveGainDivisor = 10,
    -- 0.13.10 (owner, 2026-10-11: "เพิ่ม sandbox setting ตัวคูณวิตามินที่ได้รับจาก
    -- อาหาร โดย default อยู่ที่ 5.0"): every vitamin gained by EATING is
    -- multiplied by this (sunlight and pills are not)
    foodVitaminMultiplier = 5.0,
    -- Reserve points needed to bank 1 pause day (10 Reserve = 1 pause day)
    reservePerPauseDay = 10,

    -- 0.13.2 (owner: "เงื่อนไขการเห็นวิตามินทั้งตัวเองและคนอื่นอยากให้ทุกหน้าต่าง
    -- ที่เห็นค่าวิตามินใช้เงื่อนไขเหมือนกัน"): what any window shows of a
    -- character's vitamins -- yourself or someone else, the same rule --
    -- grows with the viewer's First Aid (HARMONIE_GTP.VitaminView):
    --   below viewNumbersFirstAid   each vitamin's state name (Critical / Low / Sufficient)
    --   viewNumbersFirstAid (2)     + the Reserve number
    --   assessmentRequiredFirstAid (5) + pause days and everything else
    viewNumbersFirstAid = 2,
    assessmentRequiredFirstAid = 5,

    -- master switch for critical-band penalties (every VitEffects.Maintain*/
    -- MaybeTrigger* function no-ops entirely while this is false)
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
    c.foodVitaminMultiplier = readSandbox("FoodVitaminMultiplier", c.foodVitaminMultiplier)
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

-- the viewer's First Aid level (B42's internal id is Perks.Doctor)
function HARMONIE_GTP.FirstAidOf(player)
    if not player then return 0 end
    local ok, v = pcall(function() return player:getPerkLevel(Perks.Doctor) end)
    return ok and (tonumber(v) or 0) or 0
end

-- How much of a character's vitamins `viewer` may see, in every window
-- (see viewNumbersFirstAid above): "name", "numbers" or "full".
function HARMONIE_GTP.VitaminView(viewer)
    local fa = HARMONIE_GTP.FirstAidOf(viewer)
    local c = HARMONIE_GTP.Config
    if fa >= (tonumber(c.assessmentRequiredFirstAid) or 5) then return "full", fa end
    if fa >= (tonumber(c.viewNumbersFirstAid) or 2) then return "numbers", fa end
    return "name", fa
end
function HARMONIE_GTP.VitaminViewLevels()
    local c = HARMONIE_GTP.Config
    return tonumber(c.viewNumbersFirstAid) or 2, tonumber(c.assessmentRequiredFirstAid) or 5
end

-- 0.13.4: who may edit someone else's vitamins -- ONE check, used by the
-- right-click menu / hotkey (client) and by the server that applies the
-- edit (HARMONIE_VitaminData.lua). B42 roles: an ordinary player is
-- "user"/"None"; staff is admin / moderator / overseer / gm. Single player:
-- isAdmin() or -debug, as before.
HARMONIE_GTP.STAFF_LEVELS = { admin = true, moderator = true, overseer = true, gm = true }
function HARMONIE_GTP.IsStaff(player)
    local mp = (isClient and isClient()) or (isServer and isServer())
    if not mp then
        return ((isAdmin and isAdmin()) or (getDebug and getDebug())) and true or false, "singleplayer"
    end
    if not player then return false, "no player" end
    local ok, lvl = pcall(function() return player:getAccessLevel() end)
    if not ok or lvl == nil then return false, "unknown" end
    return HARMONIE_GTP.STAFF_LEVELS[string.lower(tostring(lvl))] == true, tostring(lvl)
end

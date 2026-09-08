--[[
    HARMONIE - From Garden to Plate
    Periodic self-check, every 10 REAL seconds (getTimestampMs-based, so
    it's not affected by game-speed multipliers or pause), that keeps the
    critical-effect system honest without waiting for the next in-game
    day. Specifically corrects:

      1. A vitamin that just crossed into Critical gets its penalty
         applied within seconds, instead of whenever the next calendar
         day happens to roll over (which could be a long real-world wait
         at a high game-speed multiplier, or short at 1x -- either way,
         not responsive).
      2. A vitamin whose banked pause days (HARMONIE_VitaminData.lua's
         GetPauseDays -- gained from eating, or from Base.PillsVitamins via
         HARMONIE_PillsHook.lua) just ran out resumes its penalty right
         away if still afflicted, instead of silently staying quiet until
         the next day tick.
      3. The "afflicted" flag itself catches up to Reserve climbing back
         above Sufficient just as quickly (VitData.RefreshAffliction),
         instead of lagging up to a full day behind the real Reserve
         value -- and the character says an in-character "feeling
         better" line the moment that happens (VitEffects.SayRecovered),
         capped at one per character per tick.
      4. Once every 6 game hours, if the character has at least one
         vitamin currently Critical (and not pause-day-shielded), says
         ONE random one of their symptom lines (VitEffects.
         MaybeSaySymptomReminder) -- entirely decoupled from the effect
         maintenance below, specifically so several vitamins crossing
         into Critical on the same day don't all say their line back to
         back.
      5. Every vitamin's penalty is continuously re-enforced here instead
         of dosed once per day -- VitEffects.MaintainStatEffect for
         A/C/D/E's CharacterStat (UNHAPPINESS/SICKNESS/ENDURANCE/STRESS all
         naturally regenerate/decay on their own), VitEffects.
         MaintainStiffnessFloor for B's per-body-part Stiffness, VitEffects
         .MaintainBleedingFloor for K's per-body-part BleedingTime (a
         bandage drains BleedingTime 10x faster than nothing does) --
         a once-a-day nudge to any of these would likely get erased
         before it was ever felt. Checked every tick, same as everything
         else here.
      6. Once every 6 game hours (same block granularity as point 4, but
         tracked separately), K specifically also gets a chance to start a
         spontaneous nosebleed with no wound required at all (VitEffects.
         MaybeTriggerNosebleed) -- MaintainBleedingFloor in point 5 only
         ever prolongs a wound that's already bleeding, so without this a
         character who never gets hit would feel nothing from a Critical
         Vitamin K deficiency, unlike every other vitamin here.

    Effect APPLICATION timing lives here now, not in
    HARMONIE_VitaminDecay.lua's daily tick -- that file only owns the
    day-based Reserve decay / pauseDays / afflictedDays bookkeeping.
    Every vitamin's penalty is a continuous, idempotent re-enforcement now
    (no once-per-day dose left at all, see HARMONIE_VitaminEffects.lua's
    header for why the old daily-stacking half of the system was
    retired), so there's no "already applied today" state to track here
    anymore -- each Maintain* function is safe to call every single tick.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"
require "HARMONIEGardenToPlate/HARMONIE_VitaminEffects"

local CHECK_INTERVAL_MS = 10000
local lastCheckMs = 0

-- worldAgeHours is a continuously-running hour count since world start;
-- dividing by 6 gives a number that increments exactly once per 6 game
-- hours, for the symptom-reminder dialogue (VitEffects.
-- MaybeSaySymptomReminder) -- lets the character comment on an ongoing
-- deficiency up to 4x/day instead of once, without ever saying more than
-- one line in the same block.
local function getSixHourBlockIndex()
    return math.floor(getGameTime():getWorldAgeHours() / 6)
end

local function checkCharacter(character, sixHourBlock)
    -- At most one "feeling better" line per character per tick, even if
    -- several vitamins recover in the same 10 seconds (e.g. right after
    -- a big varied meal) -- see VitEffects.SayRecovered.
    local recoveredAlready = false

    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        local justRecovered = HARMONIE_GTP.VitData.RefreshAffliction(character, vit)
        if justRecovered and not recoveredAlready then
            HARMONIE_GTP.VitEffects.SayRecovered(character)
            recoveredAlready = true
        end

        HARMONIE_GTP.VitEffects.MaintainStatEffect(character, vit)
    end

    HARMONIE_GTP.VitEffects.MaintainStiffnessFloor(character)
    HARMONIE_GTP.VitEffects.MaintainBleedingFloor(character)
    HARMONIE_GTP.VitEffects.MaybeTriggerNosebleed(character, sixHourBlock)
    HARMONIE_GTP.VitEffects.MaybeSaySymptomReminder(character, sixHourBlock)
end

local function onCheckerTick()
    local now = getTimestampMs and getTimestampMs() or 0
    if now - lastCheckMs < CHECK_INTERVAL_MS then return end
    lastCheckMs = now

    HARMONIE_GTP.RefreshFromSandbox()
    local sixHourBlock = getSixHourBlockIndex()

    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            checkCharacter(player, sixHourBlock)
        end
    end
end

Events.OnTick.Add(onCheckerTick)

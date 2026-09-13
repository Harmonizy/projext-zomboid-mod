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
         GetPauseDays -- gained from eating, or from this mod's own
         crafted Multivitamin pill via HARMONIE_PillsHook.lua) just ran
         out resumes its penalty right away if still afflicted, instead
         of silently staying quiet until the next day tick.
      3. The "afflicted" flag itself catches up to Reserve climbing back
         above Sufficient just as quickly (VitData.RefreshAffliction),
         instead of lagging up to a full day behind the real Reserve
         value -- and the character says an in-character "feeling
         better" line the moment that happens (VitEffects.SayRecovered),
         capped at one per character per tick.
      4. Once every Config.symptomReminderHours game hours (default 6,
         sandbox/admin-adjustable), if the character has at least one
         vitamin currently Critical (and not pause-day-shielded), says
         ONE random one of their symptom lines (VitEffects.
         MaybeSaySymptomReminder) -- entirely decoupled from the effect
         maintenance below, specifically so several vitamins crossing
         into Critical on the same day don't all say their line back to
         back.
      5. Every vitamin genuinely grants/revokes its own themed real
         vanilla CharacterTrait (VitEffects.MaintainRealTrait -- Short
         Sighted/Disorganized/Thin-Skinned/Short of Breath/All Thumbs/
         Slow Healer) -- see that function's own comment in
         HARMONIE_VitaminEffects.lua for the safety logic that keeps this
         from ever stripping a trait the character actually chose at
         creation. This is the ONLY mechanism now -- earlier versions of
         this mod also layered custom proxy effects (CharacterStat
         floors, body-part Stiffness, BleedingTime/nosebleeds, a hand-
         written stopOnWalk hook) and even a set of brand-new mod-
         registered traits on top of the real ones; both were explicitly
         removed in favor of this simpler, single-trait design.
      6. Every vitamin also gets a permanent console.txt confirmation
         (VitEffects.LogEffectStateChange) the moment its Critical-band
         trait actually gets granted/removed -- fires once per
         transition, not every tick, so console.txt can be used to verify
         "did it actually kick in" without digging through the Traits
         list in-game.

    Effect APPLICATION timing lives here now, not in
    HARMONIE_VitaminDecay.lua's daily tick -- that file only owns the
    day-based Reserve decay / pauseDays / afflictedDays bookkeeping.
    Every vitamin's trait grant/revoke is a continuous, idempotent
    re-enforcement now (no once-per-day dose left at all), so there's no
    "already applied today" state to track here anymore -- MaintainRealTrait
    is safe to call every single tick.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"
require "HARMONIEGardenToPlate/HARMONIE_VitaminEffects"

local CHECK_INTERVAL_MS = 10000
local lastCheckMs = 0

-- worldAgeHours is a continuously-running hour count since world start;
-- dividing by Config.symptomReminderHours (sandbox/admin-adjustable, see
-- HARMONIE_VitaminConfig.lua) gives a number that increments exactly
-- once per that many game hours, for the symptom-reminder dialogue
-- (VitEffects.MaybeSaySymptomReminder) -- lets the character comment on
-- an ongoing deficiency multiple times a day instead of once, without
-- ever saying more than one line in the same block. Read fresh every
-- call (not cached) so an admin changing the interval live takes effect
-- immediately, same as every other sandbox-backed value here.
local function getSymptomBlockIndex()
    local hours = HARMONIE_GTP.Config.symptomReminderHours
    if not hours or hours <= 0 then hours = 6 end
    return math.floor(getGameTime():getWorldAgeHours() / hours)
end

local function checkCharacter(character, symptomBlock)
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

        HARMONIE_GTP.VitEffects.LogEffectStateChange(character, vit)
        HARMONIE_GTP.VitEffects.MaintainRealTrait(character, vit)
    end

    HARMONIE_GTP.VitEffects.MaybeSaySymptomReminder(character, symptomBlock)
end

local function onCheckerTick()
    local now = getTimestampMs and getTimestampMs() or 0
    if now - lastCheckMs < CHECK_INTERVAL_MS then return end
    lastCheckMs = now

    HARMONIE_GTP.RefreshFromSandbox()
    local symptomBlock = getSymptomBlockIndex()

    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            checkCharacter(player, symptomBlock)
        end
    end
end

Events.OnTick.Add(onCheckerTick)

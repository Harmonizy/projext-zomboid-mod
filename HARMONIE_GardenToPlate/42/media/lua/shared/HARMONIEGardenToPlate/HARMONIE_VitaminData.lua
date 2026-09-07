--[[
    HARMONIE - From Garden to Plate
    Per-character vitamin reserve storage (ModData-backed, persists in save).

    Each vitamin tracks:
      value        - the 0-100 Reserve shown in the UI
      pauseDays    - banked days of decay AND critical-penalty immunity.
                     Gained at reservePerPauseDay Reserve per day (10
                     Reserve = 1 pause day at the default -- see
                     HARMONIE_VitaminConfig.lua) from eating, or +1 per
                     vitamin from taking Base.PillsVitamins (see
                     VitData.AddPauseDays below / HARMONIE_PillsHook.lua)
                     without any Reserve gain. While banked, both the daily
                     decay (ApplyDailyTick) and the critical-band penalty
                     itself (HARMONIE_VitaminChecker.lua / VitEffects.
                     ApplyCritical) are held off; one day is consumed per
                     in-game day regardless of which of the two purposes
                     it ends up serving
      afflicted    - true once Reserve has dropped below the critical
                     threshold; stays true (and keeps taking the critical
                     penalty) until Reserve climbs back up to the
                     "Sufficient" threshold, not merely out of "Critical"
      afflictedDays - consecutive days spent afflicted. Purely informational
                     bookkeeping now (the penalty itself is a flat constant
                     regardless of how long it's persisted -- see
                     HARMONIE_VitaminEffects.lua); kept in case something
                     wants to show/use it later
      lastEffectDay - the game-day index (see HARMONIE_VitaminChecker.lua)
                     this vitamin's critical penalty was last actually
                     applied on, so the 10-second checker doesn't apply it
                     more than once for the same day
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.VitData = {}
local VitData = HARMONIE_GTP.VitData

--[[
    Writing to character:getModData() only changes the LOCAL copy -- it
    does NOT get sent to the server/other clients by itself. Confirmed
    against vanilla's own real-world usage: ISWidgetTitleHeader.lua sets
    a favourite-recipe flag via self.player:getModData()[...] = ... then
    explicitly calls self.player:transmitModData() right after, the only
    place in all of vanilla Lua that writes to a PLAYER's own ModData (as
    opposed to a world object's). Without this, every VitData write in
    this file would only ever exist on whichever single client made it --
    fine in singleplayer (isClient() is false there, nothing to sync),
    but in real multiplayer it means Reserve/pauseDays/etc would never
    reach the server to be saved correctly, and an admin editing another
    player's values (HARMONIE_AdminPanel.lua) would silently do nothing
    beyond the admin's own client. Guarded by isClient() since this file
    is shared and its write functions are only ever actually invoked from
    client-side contexts here (the eat/pills hooks and the checker/decay
    loops are all client-only or only ever see local players -- see
    HARMONIE_VitaminChecker.lua's header) -- calling transmitModData() in
    singleplayer would be a harmless no-op either way, but being explicit
    keeps intent clear.
]]--
local function sync(character)
    if isClient() then
        character:transmitModData()
    end
end

local function ensureStore(character)
    local modData = character:getModData()
    if not modData.HARMONIE_Vitamins then
        modData.HARMONIE_Vitamins = {}
        for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
            modData.HARMONIE_Vitamins[vit] = {
                value = HARMONIE_GTP.Config.startValue,
                pauseDays = 0,
                afflicted = false,
                afflictedDays = 0,
                lastEffectDay = -1,
            }
        end
        sync(character)
    end
    return modData.HARMONIE_Vitamins
end

function VitData.Get(character, vit)
    local store = ensureStore(character)
    return store[vit].value
end

function VitData.GetPauseDays(character, vit)
    local store = ensureStore(character)
    return store[vit].pauseDays
end

function VitData.GetBand(character, vit)
    return HARMONIE_GTP.GetBand(VitData.Get(character, vit))
end

function VitData.IsAfflicted(character, vit)
    local store = ensureStore(character)
    return store[vit].afflicted
end

function VitData.GetAfflictedDays(character, vit)
    local store = ensureStore(character)
    return store[vit].afflictedDays
end

function VitData.GetLastEffectDay(character, vit)
    local store = ensureStore(character)
    return store[vit].lastEffectDay
end

function VitData.SetLastEffectDay(character, vit, day)
    local store = ensureStore(character)
    store[vit].lastEffectDay = day
    sync(character)
end

--[[
    Character-level (not per-vitamin) gate for the symptom-reminder line
    -- see HARMONIE_VitaminEffects.lua's MaybeSaySymptomReminder and
    HARMONIE_VitaminChecker.lua, which check this once per 6-game-hour
    block so a character with several vitamins critical at once only
    ever says ONE random symptom line per block, instead of every
    afflicted vitamin's line firing back to back the moment a new day
    (or several at once) crosses the critical threshold. Lives directly
    on the character's own ModData rather than inside the per-vitamin
    store above, since it isn't about any one vitamin.
]]--
function VitData.GetLastSymptomBlock(character)
    return character:getModData().HARMONIE_LastSymptomBlock or -1
end

function VitData.SetLastSymptomBlock(character, block)
    character:getModData().HARMONIE_LastSymptomBlock = block
    sync(character)
end

--[[
    Re-evaluates JUST the "afflicted" hysteresis flag against current
    Reserve (set on dropping under Critical, cleared on reaching
    Sufficient, left alone in between -- see the note at the top of this
    file). Doesn't touch decay, pauseDays, or afflictedDays, so unlike
    ApplyDailyTick this is idempotent and safe to call as often as
    wanted -- HARMONIE_VitaminChecker.lua calls it every 10 real seconds
    so a Reserve recovering back to Sufficient mid-day doesn't have to
    wait for the next day's tick to stop being treated as afflicted.

    Returns true only on the exact call where it transitions from
    afflicted to not (i.e. "just recovered"), so a caller can react to
    that moment once -- see HARMONIE_VitaminChecker.lua /
    HARMONIE_VitaminEffects.lua's SayRecovered.
]]--
function VitData.RefreshAffliction(character, vit)
    local store = ensureStore(character)
    local wasAfflicted = store[vit].afflicted
    local band = VitData.GetBand(character, vit)
    if band == "critical" then
        store[vit].afflicted = true
    elseif band == "sufficient" then
        store[vit].afflicted = false
    end
    -- Only sync on an ACTUAL change -- this is called every 10 seconds
    -- per vitamin per player by HARMONIE_VitaminChecker.lua, so syncing
    -- unconditionally would transmit ModData constantly for no reason.
    if store[vit].afflicted ~= wasAfflicted then
        sync(character)
    end
    return wasAfflicted and not store[vit].afflicted
end

-- Rejects NaN/Infinity outright rather than trusting math.min/max to
-- clamp them into range -- comparisons against NaN are always false, so
-- depending on argument order that can return the NaN itself instead of
-- a bound, silently corrupting store[vit].value permanently (every later
-- +/- on a NaN stays NaN forever, including across saves). See
-- AddPauseDays below for the same guard on Pause Days, which had no
-- clamping at all and is where this was actually observed.
local function isFiniteNumber(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function VitData.Set(character, vit, value)
    if not isFiniteNumber(value) then return end
    local store = ensureStore(character)
    value = math.max(0, math.min(HARMONIE_GTP.Config.maxValue, value))
    store[vit].value = value
    sync(character)
end

--[[
    Awards Reserve for eating `amount` (in the same unit as that vitamin's
    Daily Requirement -- mcg for A/D/K, mg for B/C/E) of a vitamin, and banks
    pause days against future decay at reservePerPauseDay Reserve per day
    (10 Reserve = 1 pause day at the default).
]]--
function VitData.Add(character, vit, amount)
    if not isFiniteNumber(amount) or amount == 0 then return end
    local store = ensureStore(character)
    local requirement = HARMONIE_GTP.DailyRequirement[vit]
    local percentOfDaily = (amount / requirement) * 100
    local gain = percentOfDaily / HARMONIE_GTP.Config.reserveGainDivisor
    if not isFiniteNumber(gain) then return end

    VitData.Set(character, vit, store[vit].value + gain)
    store[vit].pauseDays = math.max(0, store[vit].pauseDays + (gain / HARMONIE_GTP.Config.reservePerPauseDay))
    sync(character)
end

-- Called once per in-game day. Consumes a banked pause day if any are left,
-- otherwise applies the flat daily decay. Then refreshes the affliction
-- hysteresis and tracks how many consecutive days it has persisted (this
-- part IS strictly once-per-day, unlike RefreshAffliction itself).
function VitData.ApplyDailyTick(character, vit)
    local store = ensureStore(character)
    if store[vit].pauseDays > 0 then
        store[vit].pauseDays = math.max(0, store[vit].pauseDays - 1)
    else
        VitData.Set(character, vit, store[vit].value - HARMONIE_GTP.Config.decayPerDay)
    end

    VitData.RefreshAffliction(character, vit)

    if store[vit].afflicted then
        store[vit].afflictedDays = store[vit].afflictedDays + 1
    else
        store[vit].afflictedDays = 0
    end
    sync(character)
end

function VitData.GetAll(character)
    local store = ensureStore(character)
    local result = {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        result[vit] = store[vit].value
    end
    return result
end

--[[
    Grants `days` extra banked pause days to ONE vitamin, directly --
    unlike VitData.Add(), this never touches Reserve at all (see
    HARMONIE_PillsHook.lua: Base.PillsVitamins is meant to buy relief from
    the SYMPTOM, not fix the underlying deficiency, so it must not raise
    Reserve). Because pauseDays already gates both decay (ApplyDailyTick)
    and the critical-band penalty itself (see VitData.GetPauseDays's use in
    HARMONIE_VitaminChecker.lua / HARMONIE_VitaminEffects.lua), a vitamin
    that's currently Critical stays exactly as low as it was, but its
    penalty goes quiet until the banked day(s) are consumed by the next
    daily tick(s) -- symptom relief, not a cure, matching how real vitamin
    supplements don't retroactively fix a diet.
]]--
function VitData.AddPauseDays(character, vit, days)
    if not isFiniteNumber(days) then return end
    local store = ensureStore(character)
    store[vit].pauseDays = math.max(0, store[vit].pauseDays + days)
    sync(character)
end

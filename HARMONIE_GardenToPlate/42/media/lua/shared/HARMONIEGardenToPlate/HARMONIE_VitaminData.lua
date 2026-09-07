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
    return wasAfflicted and not store[vit].afflicted
end

function VitData.Set(character, vit, value)
    local store = ensureStore(character)
    value = math.max(0, math.min(HARMONIE_GTP.Config.maxValue, value))
    store[vit].value = value
end

--[[
    Awards Reserve for eating `amount` (in the same unit as that vitamin's
    Daily Requirement -- mcg for A/D/K, mg for B/C/E) of a vitamin, and banks
    pause days against future decay at reservePerPauseDay Reserve per day
    (10 Reserve = 1 pause day at the default).
]]--
function VitData.Add(character, vit, amount)
    if not amount or amount == 0 then return end
    local store = ensureStore(character)
    local requirement = HARMONIE_GTP.DailyRequirement[vit]
    local percentOfDaily = (amount / requirement) * 100
    local gain = percentOfDaily / HARMONIE_GTP.Config.reserveGainDivisor

    VitData.Set(character, vit, store[vit].value + gain)
    store[vit].pauseDays = store[vit].pauseDays + (gain / HARMONIE_GTP.Config.reservePerPauseDay)
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
    local store = ensureStore(character)
    store[vit].pauseDays = store[vit].pauseDays + days
end

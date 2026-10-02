--[[
    HARMONIE - From Garden to Plate
    Per-character vitamin reserve storage (ModData-backed, persists in save).

    Each vitamin tracks:
      value        - the 0-100 Reserve shown in the UI
      pauseDays    - banked days of decay AND critical-penalty immunity.
                     Gained at reservePerPauseDay Reserve per day (10
                     Reserve = 1 pause day at the default -- see
                     HARMONIE_VitaminConfig.lua) from eating -- or from
                     taking this mod's own crafted Multivitamin pill (see
                     HARMONIE_PillsHook.lua), which grants a full day's
                     worth of REAL Reserve via VitData.Add for every
                     vitamin at once (banking roughly 1 pause day per
                     vitamin as a side effect of that Reserve gain, same
                     as eating an equally well-rounded meal would). While
                     banked, both the daily decay (ApplyDailyTick) and the
                     critical-band penalty itself (HARMONIE_VitaminChecker
                     .lua's Maintain* functions) are held off; one day is
                     consumed per in-game day regardless of which of the
                     two purposes it ends up serving. VitData.AddPauseDays
                     below is a separate, still-available utility for
                     granting bare pause days with NO Reserve gain at all,
                     but nothing in this mod currently calls it
      afflicted    - true once Reserve has dropped below the critical
                     threshold; stays true (and keeps taking the critical
                     penalty) until Reserve climbs back up to the
                     "Sufficient" threshold, not merely out of "Critical"
      afflictedDays - consecutive days spent afflicted. Purely informational
                     bookkeeping now (the penalty itself is a flat constant
                     regardless of how long it's persisted -- see
                     HARMONIE_VitaminEffects.lua); kept in case something
                     wants to show/use it later
      traitGranted - LEGACY field from this mod's earlier real-vanilla-
                     trait design (Short Sighted/Disorganized/Thin-Skinned/
                     Short of Breath/All Thumbs/Slow Healer), now retired
                     in favor of direct stat penalties (see
                     HARMONIE_VitaminEffects.lua's header for the full
                     history). Kept in the data model, still read once, so
                     an existing save upgrading from that version doesn't
                     end up with a real trait permanently stuck on the
                     character forever -- see VitEffects.
                     MigrateAwayFromRealTraits, which revokes any
                     mod-granted trait it finds still set and clears this
                     flag. Once cleared it stays false and this field does
                     nothing further.
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
--[[
    0.7.3 (2026-10-02, real server bug): transmitModData() sends this
    client's copy of the WHOLE player ModData, which replaces the server's.
    Everything other mods keep server-side on the player was rolled back
    every time this ran (every 10 s from the checker): TheWayToAttack's
    active craft vanished (closing the crafting window lost the items,
    Finish gave nothing), and EHR / Home Medic state written by the server
    could be undone. Now only HARMONIE_Vitamins goes to the server, as a
    client command; the server writes that one key (and, for an admin
    editing another player, forwards it to that player's own client).
]]--
VitData.NET = "HARMONIE_GTP"

local function plainCopy(store)
    local out = {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins or {}) do
        local e = type(store) == "table" and store[vit]
        if type(e) == "table" then
            out[vit] = { value = tonumber(e.value) or 0, pauseDays = tonumber(e.pauseDays) or 0,
                afflicted = e.afflicted == true, afflictedDays = tonumber(e.afflictedDays) or 0,
                traitGranted = e.traitGranted == true }
        end
    end
    return out
end
VitData.plainCopy = plainCopy

local function sync(character)
    if not (isClient() and sendClientCommand) then return end
    local md = character and character:getModData()
    if not md or type(md.HARMONIE_Vitamins) ~= "table" then return end
    local me = getPlayer and getPlayer() or character
    local args = { data = plainCopy(md.HARMONIE_Vitamins) }
    if character ~= me then
        -- an admin editing another player (HARMONIE_AdminPanel)
        local ok, id = pcall(function() return character:getOnlineID() end)
        if not ok or id == nil then return end
        args.target = id
    end
    sendClientCommand(me, VitData.NET, "sync", args)
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
                traitGranted = false,
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

-- See the field comment at the top of this file -- true only while this
-- mod is the one currently holding the real trait for this vitamin.
function VitData.IsTraitGrantedByUs(character, vit)
    local store = ensureStore(character)
    return store[vit].traitGranted
end

function VitData.SetTraitGrantedByUs(character, vit, granted)
    local store = ensureStore(character)
    store[vit].traitGranted = granted
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
    Same once-per-block gating as GetLastSymptomBlock above, but tracked
    separately (its own ModData field, its own 1-game-hour block
    granularity) so it never interferes with the 6-hour symptom-dialogue
    block -- see HARMONIE_VitaminEffects.lua's MaybeTriggerScratch and
    HARMONIE_VitaminChecker.lua's getScratchBlockIndex.
]]--
function VitData.GetLastScratchBlock(character)
    return character:getModData().HARMONIE_LastScratchBlock or -1
end

function VitData.SetLastScratchBlock(character, block)
    character:getModData().HARMONIE_LastScratchBlock = block
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
    -- >= 1, not > 0: a day is only actually "banked" once a WHOLE day's
    -- worth is saved up -- otherwise a leftover fraction (say 0.3, from a
    -- single small snack) would both cancel today's decay outright AND
    -- get wiped to 0 by the -1 below, spending 0.3 to buy a full free
    -- day. With this threshold, a sub-1 balance just sits there
    -- accumulating (more snacks/pills can still add to it) until it
    -- crosses 1 and actually pays for a day.
    if store[vit].pauseDays >= 1 then
        store[vit].pauseDays = store[vit].pauseDays - 1
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
    unlike VitData.Add(), this never touches Reserve at all. Not
    currently called anywhere in this mod (HARMONIE_PillsHook.lua's
    Multivitamin pill uses VitData.Add instead, since it's meant to
    deliver a real day's nutrition, not just quiet the symptom) -- kept
    as a general-purpose utility for any future feature that wants
    "symptom relief without fixing the underlying deficiency" (matching
    how, say, a real-world quick-fix supplement might ease a symptom
    without actually correcting a poor diet). Because pauseDays already
    gates both decay (ApplyDailyTick) and the critical-band penalty
    itself (see VitData.GetPauseDays's use in HARMONIE_VitaminChecker.lua
    / HARMONIE_VitaminEffects.lua), a vitamin that's currently Critical
    would stay exactly as low as it was, but its penalty would go quiet
    until the banked day(s) are consumed by the next daily tick(s).
]]--
function VitData.AddPauseDays(character, vit, days)
    if not isFiniteNumber(days) then return end
    local store = ensureStore(character)
    store[vit].pauseDays = math.max(0, store[vit].pauseDays + days)
    sync(character)
end

-- ---------------------------------------------------------------- network
-- server: a client's vitamins (or an admin's edit of another player's)
if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= VitData.NET or command ~= "sync" or not player or type(args) ~= "table"
                or type(args.data) ~= "table" then return end
        local target = player
        if args.target ~= nil then
            local ok, lvl = pcall(function() return player:getAccessLevel() end)
            if not ok or not lvl or lvl == "" or string.lower(tostring(lvl)) == "none" then return end
            target = nil
            local online = getOnlinePlayers and getOnlinePlayers()
            for i = 0, (online and online:size() or 0) - 1 do
                local p = online:get(i)
                if p and p:getOnlineID() == tonumber(args.target) then target = p end
            end
            if not target then return end
        end
        local data = plainCopy(args.data)
        target:getModData().HARMONIE_Vitamins = data
        if target ~= player and sendServerCommand then
            sendServerCommand(target, VitData.NET, "set", { data = data })
        end
    end)
end

-- client: an admin changed this player's vitamins
if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= VitData.NET or command ~= "set" or type(args) ~= "table" or type(args.data) ~= "table" then return end
        local p = getPlayer and getPlayer()
        if p then p:getModData().HARMONIE_Vitamins = plainCopy(args.data) end
    end)
end

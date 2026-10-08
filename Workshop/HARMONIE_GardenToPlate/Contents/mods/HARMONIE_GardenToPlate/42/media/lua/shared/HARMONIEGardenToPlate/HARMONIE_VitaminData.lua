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

local function log(...) if HARMONIE_GTP.Log then HARMONIE_GTP.Log("VitData", ...) end end
local function logOnce(key, ...) if HARMONIE_GTP.LogOnce then HARMONIE_GTP.LogOnce("VitData:" .. key, "VitData", ...) end end
local function nameOf(p)
    local ok, n = pcall(function() return p:getUsername() end)
    return ok and n and tostring(n) or "?"
end

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

--[[
    0.11.1 (MP bug): another player's vitamins live on THEIR client and the
    server -- this client's copy of their ModData never has them. Reading
    them with VitData.Get used to create a fresh default store here, and for
    an admin the sync below then sent those defaults to the server: opening
    the old assessment or the admin panel on someone wiped their real
    vitamins. Now another (remote) player's store comes from the server on
    request ("get" -> "data"), is cached in VitData.Remote by online id, and
    is never synced until a real copy has arrived.
]]--
VitData.Remote = {}
local placeholder = setmetatable({}, { __mode = "k" })
local asked = {}
local ASK_EVERY_MS = 3000

local function onlineId(character)
    local ok, id = pcall(function() return character:getOnlineID() end)
    return ok and id ~= nil and tonumber(id) or nil
end

-- true on a MP client for anyone who is not one of this machine's players
local function isRemote(character)
    if not (isClient and isClient()) or not character then return false end
    local ok, loc = pcall(function() return character:isLocalPlayer() end)
    if ok and loc ~= nil then return not loc end
    logOnce("noIsLocal", "isLocalPlayer() unavailable (%s) -- comparing with this machine's players instead", tostring(loc))
    if getPlayer and getPlayer() == character then return false end
    for i = 0, 3 do
        local p = getSpecificPlayer and getSpecificPlayer(i)
        if p and p == character then return false end
    end
    return true
end
VitData.IsRemote = isRemote

local function nowMs()
    return getTimestampMs and getTimestampMs() or (os.time() * 1000)
end

-- ask the server for a remote player's store (at most every few seconds)
function VitData.RequestRemote(character)
    local id = onlineId(character)
    local me = getPlayer and getPlayer()
    if not id or not me or not sendClientCommand then return end
    local t = nowMs()
    if asked[id] and t - asked[id] < ASK_EVERY_MS then return end
    if not VitData.Remote[id] then log("asking the server for player id %s's vitamins (not here yet)", tostring(id)) end
    asked[id] = t
    sendClientCommand(me, VitData.NET, "get", { target = id })
end

-- read only: the character's store, or nil when there is none yet (a
-- remote one is requested and shows up a moment later)
function VitData.Peek(character)
    if not character then return nil end
    if isRemote(character) then
        VitData.RequestRemote(character)
        local id = onlineId(character)
        return id and VitData.Remote[id] or nil
    end
    local ok, md = pcall(function() return character:getModData() end)
    local st = ok and md and md.HARMONIE_Vitamins
    return type(st) == "table" and st or nil
end

local function defaults()
    local out = {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        out[vit] = { value = HARMONIE_GTP.Config.startValue, pauseDays = 0, afflicted = false,
            afflictedDays = 0, traitGranted = false }
    end
    return out
end

local function sync(character)
    if not (isClient() and sendClientCommand) then return end
    local me = getPlayer and getPlayer() or character
    local store
    local args = {}
    if isRemote(character) then
        -- an admin editing another player (HARMONIE_AdminPanel): only once
        -- their real store is here, never the stand-in defaults
        local id = onlineId(character)
        store = id and VitData.Remote[id]
        if type(store) ~= "table" or placeholder[store] then
            log("NOT syncing player id %s: their real vitamins have not arrived yet (edit dropped so it cannot overwrite them)", tostring(id))
            return
        end
        args.target = id
        log("admin edit: sending player id %s's vitamins to the server", tostring(id))
    else
        local md = character and character:getModData()
        store = md and md.HARMONIE_Vitamins
        if type(store) ~= "table" then return end
        logOnce("ownSync:" .. nameOf(character), "first vitamin sync this session for %s (later ones are not logged)", nameOf(character))
        -- sent AS this character (split screen player 2 included), so the
        -- server writes it to them without any staff check
        me = character
    end
    args.data = plainCopy(store)
    sendClientCommand(me, VitData.NET, "sync", args)
end

local function ensureStore(character)
    if isRemote(character) then
        local st = VitData.Peek(character)
        if type(st) == "table" then
            -- fill any vitamin the server copy lacks, without syncing
            for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
                if type(st[vit]) ~= "table" then st[vit] = defaults()[vit] end
            end
            return st
        end
        local tmp = defaults()
        placeholder[tmp] = true
        logOnce("placeholder:" .. tostring(onlineId(character)), "player id %s: showing defaults until the server sends their vitamins", tostring(onlineId(character)))
        return tmp
    end
    local modData = character:getModData()
    if not modData.HARMONIE_Vitamins then
        log("new vitamin store for %s (start value %s)", nameOf(character), tostring(HARMONIE_GTP.Config.startValue))
        modData.HARMONIE_Vitamins = defaults()
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
        if module ~= VitData.NET or not player or type(args) ~= "table" then return end
        if command == "get" then
            -- someone's assessment / check / admin panel wants a player's
            -- vitamins: read only, sent back to the asker alone
            local want = tonumber(args.target)
            local online = getOnlinePlayers and getOnlinePlayers()
            for i = 0, (online and online:size() or 0) - 1 do
                local p = online:get(i)
                if p and p:getOnlineID() == want then
                    local st = p:getModData().HARMONIE_Vitamins
                    logOnce("get:" .. nameOf(player) .. ">" .. tostring(want), "%s asked for %s's vitamins: %s (repeats not logged)",
                        nameOf(player), nameOf(p), type(st) == "table" and "sent" or "none on the server yet")
                    if sendServerCommand then
                        sendServerCommand(player, VitData.NET, "data",
                            { id = want, data = type(st) == "table" and plainCopy(st) or nil })
                    end
                    return
                end
            end
            log("%s asked for player id %s: not online", nameOf(player), tostring(want))
            return
        end
        if command ~= "sync" or type(args.data) ~= "table" then return end
        local target = player
        if args.target ~= nil then
            -- 0.7.7: staff roles only -- in B42 an ordinary player is
            -- "user", not "None", so the old check let anyone edit others
            local ok, lvl = pcall(function() return player:getAccessLevel() end)
            local STAFF = { admin = true, moderator = true, overseer = true, gm = true }
            if not ok or not lvl or not STAFF[string.lower(tostring(lvl))] then
                log("REJECTED: %s (access %s) tried to edit player id %s's vitamins", nameOf(player), tostring(lvl), tostring(args.target))
                return
            end
            target = nil
            local online = getOnlinePlayers and getOnlinePlayers()
            for i = 0, (online and online:size() or 0) - 1 do
                local p = online:get(i)
                if p and p:getOnlineID() == tonumber(args.target) then target = p end
            end
            if not target then
                log("admin edit by %s: player id %s not online", nameOf(player), tostring(args.target))
                return
            end
            log("admin edit by %s applied to %s", nameOf(player), nameOf(target))
        end
        local data = plainCopy(args.data)
        if target == player then
            logOnce("srvSync:" .. nameOf(player), "receiving %s's vitamins (first this session, later ones not logged)", nameOf(player))
        end
        target:getModData().HARMONIE_Vitamins = data
        if target ~= player and sendServerCommand then
            sendServerCommand(target, VitData.NET, "set", { data = data, id = target:getOnlineID() })
        end
    end)
end

-- client: an admin changed this player's vitamins
if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= VitData.NET or type(args) ~= "table" then return end
        if command == "data" then
            -- another player's vitamins, asked for by VitData.RequestRemote
            local id = tonumber(args.id)
            if id and type(args.data) == "table" then
                if not VitData.Remote[id] then log("player id %s's vitamins arrived from the server", tostring(id)) end
                VitData.Remote[id] = plainCopy(args.data)
            else
                logOnce("nodata:" .. tostring(id), "server has no vitamins for player id %s yet", tostring(id))
            end
            return
        end
        if command ~= "set" or type(args.data) ~= "table" then return end
        -- the edited player may be split screen player 2: match the id
        local p = getPlayer and getPlayer()
        local want = tonumber(args.id)
        for i = 0, 3 do
            local q = want and getSpecificPlayer and getSpecificPlayer(i)
            if q and onlineId(q) == want then p = q end
        end
        if p then
            p:getModData().HARMONIE_Vitamins = plainCopy(args.data)
            log("an admin changed %s's vitamins (from the server)", nameOf(p))
        else
            log("an admin edit arrived but no local player matches id %s", tostring(args.id))
        end
    end)
end

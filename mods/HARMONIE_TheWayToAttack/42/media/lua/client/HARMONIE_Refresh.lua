--[[
    HARMONIE Hub: lists refresh by button, not by themselves (owner
    2026-11-21: "the recipes keep refreshing as if searching for what can be
    made -- give it a refresh button, nothing automatic, in every mod").

    Every list that looks through what is at hand (inventory, bags, boxes
    nearby) keeps its result until the "generation" of its scope changes:
        HARMONIE_Refresh.gen(scope)        -- the current number (starts at 1)
        HARMONIE_Refresh.bump(scope, why)  -- look again (logged)
    A scope's generation goes up only when
        * the player presses that window's Refresh button, or
        * one of OUR actions in that window finished (an item was made,
          fitted, used up...), so the list never shows what just went away.
    A list that was never scanned scans once when it is first shown.
    Scopes in use: "GTP", "TWA", "MIL", "SVU", "HM".
]]--

HARMONIE_Refresh = HARMONIE_Refresh or {}
local R = HARMONIE_Refresh
R.gens = R.gens or {}

function R.gen(scope)
    return R.gens[scope or "?"] or 1
end

-- Hub 5.4 (owner 2026-11-27: "the bag could not be picked because I had not
-- pressed Refresh -- people will think it is a bug"; choice: make the Refresh
-- button glow): lists still never rescan by themselves, but when the
-- player's items change after a scope last looked, that scope is STALE and
-- its Refresh button glows (R.glow) with a tooltip saying why (R.tip(scope)).
-- A change = the player's own inventory / worn / hotbar signature changed
-- (checked every R.SIG_MS, only while one of our windows is open) or the
-- game's OnClothingUpdated fired. OnContainerUpdate is NOT used: it fires
-- for any container in the world (stoves cooking...) and would glow always.
R.serial = R.serial or 0
R.seen = R.seen or {}
R.SIG_MS = 750
function R.markChanged(why)
    R.serial = R.serial + 1
    if not R.loggedChange or (getTimestampMs and getTimestampMs() - R.loggedChange > 30000) then
        R.loggedChange = getTimestampMs and getTimestampMs() or 0
        print(string.format("[HARMONIE_Hub][Refresh] items changed (%s) -- open lists' Refresh buttons glow", tostring(why or "?")))
    end
end
function R.stale(scope)
    return R.serial > (R.seen[scope or "?"] or 0)
end

function R.bump(scope, why)
    scope = scope or "?"
    R.seen[scope] = R.serial
    R.gens[scope] = R.gen(scope) + 1
    print(string.format("[HARMONIE_Hub][Refresh] %s: look again (%s) -> #%d", tostring(scope), tostring(why or "?"), R.gens[scope]))
    return R.gens[scope]
end

function R.label()
    local ok, s = pcall(getText, "IGUI_HUB_Refresh")
    return ok and s or "Refresh"
end

function R.tip(scope)
    local ok, s = pcall(getText, "IGUI_HUB_Refresh_Tip")
    s = ok and s or ""
    if scope and R.stale(scope) then
        local ok2, s2 = pcall(getText, "IGUI_HUB_Refresh_Stale")
        if ok2 and s2 then s = s2 .. "\n" .. s end
    end
    return s
end

-- a pulsing gold frame around a Refresh button while its scope is stale;
-- call it after the button is drawn (ui = the element it is drawn on)
function R.glow(ui, x, y, w, h, scope)
    if not ui or not R.stale(scope) then return false end
    local t = getTimestampMs and getTimestampMs() or 0
    local a = 0.55 + 0.45 * math.sin(t / 180)
    pcall(function()
        ui:drawRectBorder(x, y, w, h, a, 1.0, 0.82, 0.25)
        ui:drawRectBorder(x + 1, y + 1, w - 2, h - 2, a * 0.7, 1.0, 0.82, 0.25)
        ui:drawRect(x + w - 8, y + 3, 5, 5, a, 1.0, 0.82, 0.25)
    end)
    return true
end

-- the player's own items: a cheap signature (counts + weight), no item walk
local function sigOf(p)
    local s = ""
    pcall(function()
        local inv = p:getInventory()
        s = tostring(inv:getItems():size()) .. ":" .. string.format("%.2f", inv:getCapacityWeight())
        local w = p:getWornItems()
        s = s .. ":" .. tostring(w and w:size() or 0)
        local ai = p.getAttachedItems and p:getAttachedItems()
        s = s .. ":" .. tostring(ai and ai.size and ai:size() or 0)
        local pr, sc = p:getPrimaryHandItem(), p:getSecondaryHandItem()
        s = s .. ":" .. tostring(pr and pr:getID() or 0) .. ":" .. tostring(sc and sc:getID() or 0)
    end)
    return s
end
R.lastSig = R.lastSig or nil
local nextSig = 0
local function watch()
    local t = getTimestampMs and getTimestampMs() or 0
    if t < nextSig then return end
    nextSig = t + R.SIG_MS
    if HARMONIE_ActionBar and HARMONIE_ActionBar.anyOpen and not HARMONIE_ActionBar.anyOpen() then return end
    local p = getSpecificPlayer and getSpecificPlayer(0)
    if not p then return end
    local s = sigOf(p)
    if R.lastSig and s ~= R.lastSig then R.markChanged("inventory") end
    R.lastSig = s
end
if not R.watchAdded and Events then
    R.watchAdded = true
    if Events.OnTick then Events.OnTick.Add(watch) end
    if Events.OnClothingUpdated then Events.OnClothingUpdated.Add(function() R.markChanged("clothing") end) end
end

-- after one of OUR timed actions was queued: look again ONCE, when the
-- player's action queue has been empty for SETTLE_MS (the action finished,
-- was cancelled or failed; in MP the server's item changes arrive a moment
-- after the action ends). Nothing runs while no one waits.
R.waiting = R.waiting or {}
R.WAIT_MAX_MS = 300000
R.SETTLE_MS = 1000
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end
local function queueEmpty(player)
    if not (ISTimedActionQueue and ISTimedActionQueue.getTimedActionQueue) then return true end
    local ok, q = pcall(ISTimedActionQueue.getTimedActionQueue, player)
    return not ok or not q or not q.queue or #q.queue == 0
end
function R.afterActions(scope, player, why)
    if not player then return R.bump(scope, why) end
    for _, w in ipairs(R.waiting) do
        -- one wait per scope + player is enough: the latest reason wins
        if w.scope == scope and w.player == player then w.why, w.since, w.ticks, w.emptyAt = why, nowMs(), 0, nil; return end
    end
    R.waiting[#R.waiting + 1] = { scope = scope, player = player, why = why, since = nowMs(), ticks = 0 }
end
local function tick()
    if #R.waiting == 0 then return end
    local t, keep = nowMs(), {}
    for _, w in ipairs(R.waiting) do
        w.ticks = w.ticks + 1
        local done = false
        -- 2 ticks first: the action may only reach the queue on the next one
        if w.ticks > 2 then
            if queueEmpty(w.player) then
                w.emptyAt = w.emptyAt or t
                done = t - w.emptyAt >= R.SETTLE_MS
            else
                w.emptyAt = nil
            end
            done = done or t - w.since > R.WAIT_MAX_MS
        end
        if done then R.bump(w.scope, tostring(w.why) .. ", actions done") else keep[#keep + 1] = w end
    end
    R.waiting = keep
end
if not R.tickAdded and Events and Events.OnTick then
    R.tickAdded = true
    Events.OnTick.Add(tick)
end

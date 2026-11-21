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

function R.bump(scope, why)
    scope = scope or "?"
    R.gens[scope] = R.gen(scope) + 1
    print(string.format("[HARMONIE_Hub][Refresh] %s: look again (%s) -> #%d", tostring(scope), tostring(why or "?"), R.gens[scope]))
    return R.gens[scope]
end

function R.label()
    local ok, s = pcall(getText, "IGUI_HUB_Refresh")
    return ok and s or "Refresh"
end

function R.tip()
    local ok, s = pcall(getText, "IGUI_HUB_Refresh_Tip")
    return ok and s or ""
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

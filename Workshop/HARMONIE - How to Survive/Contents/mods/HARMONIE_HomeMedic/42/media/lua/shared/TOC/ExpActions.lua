local DataController = require("TOC/Controllers/DataController")
local CachedDataHandler = require("TOC/Handlers/CachedDataHandler")
local CommonMethods = require("TOC/CommonMethods")
local CommandsData = require("TOC/CommandsData")

local XP_PER_TICK = 0.01

---Iterates all valid amputated limbs and calls applyXp(character, perkName) for each.
---Shared logic — no XP mechanism assumed.
---@param action ISBaseTimedAction
---@param applyXp fun(character: IsoPlayer, perkName: string)
local function IterateTOCXp(action, applyXp)
    ---@diagnostic disable-next-line: undefined-field
    if action.skipTOC or action.noExp then return end

    local character = action.character
    local username = character:getUsername()
    local dcInst = DataController.GetInstance(username)
    if not dcInst or not dcInst:getIsAnyLimbCut() then return end

    local amputatedLimbs = CachedDataHandler.GetAmputatedLimbs(username)
    if not amputatedLimbs then return end

    for limbName, _ in pairs(amputatedLimbs) do
        if dcInst:getIsCut(limbName) and dcInst:getIsVisible(limbName) then
            local perkName = "Side_" .. CommonMethods.GetSide(limbName)
            if character:getPerkLevel(Perks[perkName]) < 10 then
                --TOC_DEBUG.print("IterateTOCXp | " .. perkName)
                applyXp(character, perkName)
            end
            if dcInst:getIsProstEquipped(limbName) and character:getPerkLevel(Perks["ProstFamiliarity"]) < 10 then
                --TOC_DEBUG.print("IterateTOCXp | ProstFamiliarity")
                applyXp(character, "ProstFamiliarity")
            end
        end
    end
end

-- HARMONIE 1.0.4 (owner, 2026-11-12: "ได้ xp จากทุก action"): TOC XP comes
-- from EVERY timed action now, not a list of ~25 classes. The original wrapped
-- each class's update(); most actions override update() without calling the
-- base, so a list was the only way there. Instead the player's own queue is
-- watched once per update of each local player: while a timed action is
-- running (ISTimedActionQueue current + the character's running actions), the
-- amputated sides (and prosthesis) earn XP_PER_TICK each tick, as before.
-- Single player adds it at once (HM_TOCXp.add: TOC multiplier on top of the
-- global one). An MP client sums it and sends it to the server (RelayAddXp)
-- when the action ends or changes, and every FLUSH_TICKS during a long one.
-- Actions with skipTOC / noExp still give nothing.

local FLUSH_TICKS = 300
local recs = {}

local function hmlog(fmt, ...) if HMLog then HMLog("TOCXp", fmt, ...) end end

local function relay(rec)
    for perkName, xp in pairs(rec.xp) do
        if xp > 0 then
            sendClientCommand(CommandsData.modules.TOC_RELAY, CommandsData.server.Relay.RelayAddXp,
                {perkName = perkName, xp = xp})
        end
    end
    rec.xp = {}
    rec.ticks = 0
end

local function currentAction(pl)
    local Q = ISTimedActionQueue
    local q = Q and Q.queues and Q.queues[pl]
    if not q then return nil end
    local cur = q.current or (q.queue and q.queue[1])
    if not cur then return nil end
    -- running = the character really has an action going (not just queued)
    if pl.getCharacterActions then
        local ok, list = pcall(function() return pl:getCharacterActions() end)
        if ok and list and list.isEmpty and list:isEmpty() then return nil end
    end
    return cur
end

local function onPlayerUpdate(pl)
    if not pl or not pl.isLocalPlayer or not pl:isLocalPlayer() then return end
    local key = pl:getUsername()
    local cur = currentAction(pl)
    local rec = recs[key]
    if rec and rec.action ~= cur then
        if isClient() then relay(rec) end
        recs[key] = nil
        rec = nil
    end
    if not cur or cur.skipTOC or cur.noExp then return end
    if not rec then
        rec = { action = cur, xp = {}, ticks = 0 }
        recs[key] = rec
        if HMLogOnce then HMLogOnce("tocxp_any_" .. tostring(cur.Type), "TOCXp", "TOC XP counted for action %s", tostring(cur.Type or "?")) end
    end
    local shim = { character = pl, skipTOC = cur.skipTOC, noExp = cur.noExp }
    IterateTOCXp(shim, function(character, perkName)
        if isClient() then
            rec.xp[perkName] = (rec.xp[perkName] or 0) + XP_PER_TICK
        elseif HM_TOCXp then
            HM_TOCXp.add(character, perkName, XP_PER_TICK)
        else
            addXp(character, Perks[perkName], XP_PER_TICK)
        end
    end)
    if isClient() then
        rec.ticks = rec.ticks + 1
        if rec.ticks >= FLUSH_TICKS then relay(rec) end
    end
end

if not isServer() and Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
    hmlog("TOC XP from every timed action (queue watch, %s XP a tick)", tostring(XP_PER_TICK))
end

---Kept for callers of the old API; classes are no longer wrapped one by one.
local function WrapUpdate(actionClass) end

return { IterateTOCXp = IterateTOCXp, WrapUpdate = WrapUpdate }

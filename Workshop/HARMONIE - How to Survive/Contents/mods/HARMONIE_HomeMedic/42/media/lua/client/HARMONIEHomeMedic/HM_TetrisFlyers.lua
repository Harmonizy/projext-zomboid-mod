--[[
    HARMONIE - How to Survive : EHR flyers and Inventory Tetris Grand Master

    Owner 2026-11-28: "EHR flyers stack together with business cards -- fix".
    Grand Master (TetrisGMT, Workshop 3808187767) sizes every literature item
    by name: anything with "flyer", "card", "note", "paper"... is "loose
    paper" and gets stackGroup "paper", and its MixedStacks lets every item
    of one stackGroup share a stack. So a disease flyer joined business
    cards, notes and tickets.

    Here every ExtensiveHealth.* entry of its BookItemDefinitions table gets
    its own copy WITHOUT stackGroup (same size and stack limit): a flyer
    stacks only with flyers of the same disease (Inventory Tetris' own rule).
    MixedStacks reads that table at every stacking decision, so the change
    works at once. GMT rebuilds the table at OnInitGlobalModData; this runs
    after that (OnGameStart) and once more on the first ticks.
    Soft: without Grand Master nothing happens. Client only, never touches
    items. A stack mixed before this keeps what it has until it is moved.
]]--

HM_TetrisFlyers = HM_TetrisFlyers or {}
local TF = HM_TetrisFlyers

local function log(fmt, ...) print(string.format("[HARMONIE_HM][TetrisFlyers] " .. fmt, ...)) end

local function gmtActive()
    local mods = getActivatedMods and getActivatedMods()
    return mods ~= nil and mods:contains("TetrisGMT")
end

local function ownGroup(fullType)
    return type(fullType) == "string" and fullType:find("^ExtensiveHealth%.") ~= nil
end

function TF.apply(where)
    if not gmtActive() then return 0 end
    local ok, pack = pcall(require, "TetrisGMT/Definitions/BookItemDefinitions")
    if not ok or type(pack) ~= "table" then return 0 end
    local n = 0
    for fullType, def in pairs(pack) do
        if ownGroup(fullType) and type(def) == "table" and def.stackGroup then
            -- a copy: the def is shared by every loose-paper item
            local copy = {}
            for k, v in pairs(def) do if k ~= "stackGroup" then copy[k] = v end end
            pack[fullType] = copy
            n = n + 1
        end
    end
    if n > 0 then log("%s: %d EHR flyer type(s) taken out of Grand Master's shared paper stack", tostring(where), n) end
    return n
end

local ticks = 0
local function onTick()
    ticks = ticks + 1
    if ticks == 30 or ticks == 600 then TF.apply("tick " .. ticks) end
    if ticks >= 600 then Events.OnTick.Remove(onTick) end
end

if Events then
    if Events.OnGameStart then Events.OnGameStart.Add(function() TF.apply("OnGameStart") end) end
    if Events.OnTick then Events.OnTick.Add(onTick) end
end

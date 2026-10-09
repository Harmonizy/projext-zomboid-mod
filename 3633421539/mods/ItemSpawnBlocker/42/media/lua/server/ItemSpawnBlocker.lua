-- Item Spawn Blocker (物品刷新屏蔽器)
-- Standalone sandbox mod: remove user-listed items from procedural loot.
--
-- Runs server-side (media/lua/server), so it is authoritative in multiplayer:
-- blocked items are simply never generated for any client.
--
-- Mechanism:
--   1. OnPostDistributionMerge walks every ProceduralDistribution table and
--      removes item/weight pairs whose item type matches the sandbox BlockList.
--   2. (Optional) OnFillContainer strips blocked items from containers that are
--      filled after the merge pass (zombie corpses, event containers, ...).

require "Items/ProceduralDistributions"

ItemSpawnBlocker = ItemSpawnBlocker or {}
local Blocker = ItemSpawnBlocker

Blocker.VERSION = "1.0.0"

-- Weak-keyed set of item tables already processed, so a repeated merge pass
-- never removes the same pairs twice.
Blocker._processed = Blocker._processed or setmetatable({}, { __mode = "k" })

-- Parse the sandbox "BlockList" ("a; b; c" -> { "a", "b", "c" }, lowercased).
-- Returns nil when the blocker is off or the list is empty.
local function parsePatterns()
    local opts = SandboxVars and SandboxVars.ItemSpawnBlocker
    if not opts or opts.Enabled ~= true then
        return nil
    end
    local raw = opts.BlockList
    if type(raw) ~= "string" or raw == "" then
        return nil
    end
    local patterns = {}
    for entry in string.gmatch(raw, "[^;,%s]+") do
        entry = string.lower(entry)
        if entry ~= "" then
            patterns[#patterns + 1] = entry
        end
    end
    if #patterns == 0 then
        return nil
    end
    return patterns
end

-- Case-insensitive partial match. "axe" matches "Base.Axe" and "Axe"; "gun"
-- matches "Base.AK12_cat". The "plain" flag treats each entry as a literal,
-- so "." or "-" are never parsed as Lua patterns. Bare entries (no ".") are
-- also tried with a "base." prefix so "Base.Axe" still matches a bare "Axe".
local function isBlocked(fullType, patterns)
    if type(fullType) ~= "string" then
        return false
    end
    local lower = string.lower(fullType)
    local qualified = lower
    if not string.find(lower, ".", 1, true) then
        qualified = "base." .. lower
    end
    for _, pattern in ipairs(patterns) do
        if string.find(lower, pattern, 1, true)
                or string.find(qualified, pattern, 1, true) then
            return true
        end
    end
    return false
end

-- Remove matching item/weight pairs from one flat items list, in place.
local function filterItems(items, patterns, stats)
    if type(items) ~= "table" or Blocker._processed[items] then
        return
    end
    Blocker._processed[items] = true

    local index = 1
    while index + 1 <= #items do
        if isBlocked(items[index], patterns) then
            table.remove(items, index + 1)
            table.remove(items, index)
            stats.removed = stats.removed + 1
        else
            index = index + 2
        end
    end
end

-- Remove blocked items from a single ItemContainer (snapshot then mutate, to
-- avoid invalidating the iterator while walking the Java list).
local function stripContainer(container, patterns)
    local ok, items = pcall(function()
        return container:getItems()
    end)
    if not ok or not items then
        return 0
    end
    local sizeOK, size = pcall(function()
        return items:size()
    end)
    if not sizeOK or not size then
        return 0
    end

    local toRemove = {}
    for i = 0, size - 1 do
        local getOK, item = pcall(function()
            return items:get(i)
        end)
        if getOK and item then
            local typeOK, fullType = pcall(function()
                return item:getFullType()
            end)
            if typeOK and isBlocked(fullType, patterns) then
                toRemove[#toRemove + 1] = item
            end
        end
    end

    for _, item in ipairs(toRemove) do
        pcall(function()
            container:Remove(item)
        end)
    end

    return #toRemove
end

local function applyBlocker()
    local patterns = parsePatterns()
    if not patterns then
        return
    end

    local lists = ProceduralDistributions and ProceduralDistributions.list
    if type(lists) ~= "table" then
        return
    end

    local stats = { distributions = 0, itemTables = 0, removed = 0 }
    for _, distribution in pairs(lists) do
        if type(distribution) == "table" then
            stats.distributions = stats.distributions + 1
            if type(distribution.items) == "table" then
                stats.itemTables = stats.itemTables + 1
                filterItems(distribution.items, patterns, stats)
            end
            if type(distribution.junk) == "table"
                    and type(distribution.junk.items) == "table" then
                stats.itemTables = stats.itemTables + 1
                filterItems(distribution.junk.items, patterns, stats)
            end
        end
    end

    Blocker.lastRun = stats
    if stats.removed > 0 then
        print("[ItemSpawnBlocker] removed " .. stats.removed
            .. " loot entries across " .. stats.distributions .. " distributions")
    end
end

-- Optional safety net for containers populated after the merge pass (zombie
-- corpses, event containers). Only active when FilterContainers is enabled.
local function stripFilledContainer(...)
    local opts = SandboxVars and SandboxVars.ItemSpawnBlocker
    if not opts or opts.FilterContainers ~= true then
        return
    end
    local patterns = parsePatterns()
    if not patterns then
        return
    end

    -- B42 may pass metadata objects (ItemPickerContainer) that cannot be
    -- indexed safely; scan the args for the real ItemContainer.
    local container = nil
    if instanceof then
        for index = 3, select("#", ...) do
            local candidate = select(index, ...)
            if candidate and instanceof(candidate, "ItemContainer") then
                container = candidate
                break
            end
        end
    end
    if not container then
        return
    end

    local removedCount = stripContainer(container, patterns)
    if removedCount > 0 then
        Blocker.containerRemoved = (Blocker.containerRemoved or 0) + removedCount
    end
end

Blocker.applyBlocker = applyBlocker
Blocker.filterItems = filterItems
Blocker.isBlocked = isBlocked
Blocker.parsePatterns = parsePatterns

if Blocker._callback then
    Events.OnPostDistributionMerge.Remove(Blocker._callback)
end
Blocker._callback = applyBlocker
Events.OnPostDistributionMerge.Add(Blocker._callback)

if Blocker._fillCallback then
    Events.OnFillContainer.Remove(Blocker._fillCallback)
end
Blocker._fillCallback = stripFilledContainer
Events.OnFillContainer.Add(Blocker._fillCallback)

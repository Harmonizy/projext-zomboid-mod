-- Item Spawn Blocker (物品刷新屏蔽器) — crafting recipe blocking
--
-- Client-side companion to the loot blocker: removes user-listed crafting
-- recipes (vanilla or mod, including forge / blacksmithing) from the crafting
-- menu and stops them from being performed.
--
-- Why client-side: the crafting UI and the craft action both run on the
-- client, so recipes must be disabled there for this to work in multiplayer.
-- The sandbox list is still synced from the server, so the server keeps
-- controlling what gets blocked.

ItemSpawnBlocker = ItemSpawnBlocker or {}
local Blocker = ItemSpawnBlocker

-- Parse the sandbox "RecipeBlockList" ("a; b; c" -> { "a", "b", "c" },
-- lowercased). Returns nil when recipe blocking is off or the list is empty.
local function parseRecipePatterns()
    local opts = SandboxVars and SandboxVars.ItemSpawnBlocker
    if not opts or opts.BlockRecipes ~= true then
        return nil
    end
    local raw = opts.RecipeBlockList
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

-- Case-insensitive plain substring match of one candidate string.
local function matchesCandidate(candidate, patterns)
    if type(candidate) ~= "string" or candidate == "" then
        return false
    end
    local lower = string.lower(candidate)
    for _, pattern in ipairs(patterns) do
        if string.find(lower, pattern, 1, true) then
            return true
        end
    end
    return false
end

-- Like matchesCandidate, but also tries a "base." prefix so a bare entry
-- ("axe") still matches a qualified item type ("Base.Axe").
local function matchesItemType(fullType, patterns)
    if type(fullType) ~= "string" or fullType == "" then
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

-- A recipe is blocked when any of its identifying strings (name, original
-- name, category, result item type) matches any pattern. Every access is
-- wrapped in pcall because some recipes lack a result or a category.
local function isRecipeBlocked(recipe, patterns)
    for _, method in ipairs({ "getName", "getOriginalname", "getCategory" }) do
        local ok, value = pcall(function()
            return recipe[method](recipe)
        end)
        if ok and matchesCandidate(value, patterns) then
            return true
        end
    end

    local ok, result = pcall(function()
        return recipe:getResult()
    end)
    if ok and result then
        local fullOK, fullType = pcall(function()
            return result:getFullType()
        end)
        if fullOK and matchesItemType(fullType, patterns) then
            return true
        end
        local shortOK, shortType = pcall(function()
            return result:getType()
        end)
        if shortOK and matchesItemType(shortType, patterns) then
            return true
        end
    end

    return false
end

local function applyRecipeBlocker()
    local patterns = parseRecipePatterns()
    if not patterns then
        return
    end

    local ok, recipes = pcall(function()
        return getScriptManager():getAllRecipes()
    end)
    if not ok or not recipes then
        return
    end

    local sizeOK, size = pcall(function()
        return recipes:size()
    end)
    if not sizeOK or not size then
        return
    end

    local blocked = 0
    for i = 0, size - 1 do
        local getOK, recipe = pcall(function()
            return recipes:get(i)
        end)
        if getOK and recipe and isRecipeBlocked(recipe, patterns) then
            -- Hide from the crafting menu, and refuse the recipe if the game
            -- still asks it whether it can be performed.
            local hiddenOK = pcall(function()
                recipe:setIsHidden(true)
            end)
            local canPerformOK = pcall(function()
                recipe:setCanPerform(function()
                    return false
                end)
            end)
            if hiddenOK or canPerformOK then
                blocked = blocked + 1
            end
        end
    end

    Blocker.recipesBlocked = blocked
    if blocked > 0 then
        print("[ItemSpawnBlocker] blocked " .. blocked .. " crafting recipes")
    end
end

Blocker.applyRecipeBlocker = applyRecipeBlocker

-- Apply on game start and again after the map loads. Re-running is idempotent
-- (it just re-sets the same flags), and the post-map-load pass catches any
-- recipes that are only materialised during world load.
Events.OnGameStart.Add(applyRecipeBlocker)
Events.OnPostMapLoad.Add(applyRecipeBlocker)

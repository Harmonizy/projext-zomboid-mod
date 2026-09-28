--============================================================================
-- HARMONIE_TheWayToAttack -- crafting state shared by client AND server
--
-- Request 2026-09-28 (procedure minigame, phase 1): every procedure is now
-- played as a minigame that scores it Miss/Bad/Good/Excellent (0/1/2/3).
-- A Miss does NOT count the procedure as done (it can be redone) but still
-- uses up its materials. When every procedure of a recipe is done, Finish
-- averages the scores into an overall quality (Bad < 1.67, Good < 2.34,
-- Excellent >= 2.34) and rolls the finished item's grade from that
-- quality's own pool (see GRADE_POOLS below) -- this REPLACES the old
-- flat S/A/B/C/D/E/F rarity roll entirely. The 6 Material recipes get no
-- quality and no grade at all.
--
-- Everything here is plain data + pure functions so the SAME code runs in
-- the timed actions' complete() (server in multiplayer, local in single
-- player) and in the client UI/tooltip -- the two ends always agree on what
-- a word means, how the average is cut, and how a bookmark is laid out.
--
-- Bookmark layout on a base item's ModData (written by Incomplete, updated
-- by every procedure performed while resuming that item):
--   TWA_RecipeId        = recipe id string
--   TWA_DoneProcedures  = { [procId] = true, ... }   (unchanged, older format)
--   TWA_ProcQuality     = { [procId] = "Excellent"|"Good"|"Bad"|"Miss", ... }
-- A bookmark made before this update has no TWA_ProcQuality at all; its
-- done procedures read as "Good" (request 2026-09-28).
--============================================================================

TWACraftState = TWACraftState or {}
local S = TWACraftState

S.WORDS = { "Miss", "Bad", "Good", "Excellent" }
S.SCORE = { Miss = 0, Bad = 1, Good = 2, Excellent = 3 }
S.LEGACY_WORD = "Good"
-- Minigame switched off in sandbox, or failed to open/run: always this.
S.FALLBACK_WORD = "Excellent"

S.WORD_KEY = {
    Miss = "IGUI_TWA_Quality_Miss", Bad = "IGUI_TWA_Quality_Bad",
    Good = "IGUI_TWA_Quality_Good", Excellent = "IGUI_TWA_Quality_Excellent",
}
S.WORD_COLOR = {
    Miss = { r = 0.90, g = 0.30, b = 0.30 }, Bad = { r = 0.95, g = 0.60, b = 0.25 },
    Good = { r = 0.50, g = 0.90, b = 0.50 }, Excellent = { r = 1.00, g = 0.85, b = 0.20 },
}

-- Overall-quality cut points on the 1..3 average (request 2026-09-28:
-- three equal bands).
S.BAD_BELOW = 1.67
S.GOOD_BELOW = 2.34

-- Grade pools per overall quality, each rolled with the SAME odds in the
-- same order (request 2026-09-28): 1% / 9% / 20% / 30% / 40%.
S.GRADE_POOLS = {
    Excellent = { "S", "A", "B", "C", "D" },
    Good      = { "A", "B", "C", "D", "E" },
    Bad       = { "B", "C", "D", "E", "F" },
}
S.GRADE_ODDS = { 1, 9, 20, 30, 40 }

function S.isWord(w)
    return S.SCORE[w] ~= nil
end

function S.wordText(w)
    local key = S.WORD_KEY[w]
    return key and getText(key) or tostring(w)
end

-- Recipe lookup by id -- lives here (shared) rather than in the client UI
-- so the server-side complete() of every crafting action can resolve the
-- same recipe from the plain id string it was handed.
local recipeByIdCache
function S.getRecipeById(id)
    if not id or not TWARecipeData or not TWARecipeData.List then return nil end
    if not recipeByIdCache then
        recipeByIdCache = {}
        for _, r in ipairs(TWARecipeData.List) do
            recipeByIdCache[r.id] = r
        end
    end
    return recipeByIdCache[id]
end

function S.isMaterialRecipe(recipe)
    return recipe ~= nil and recipe.category == "Material"
end

-- A {procId = word} map crosses the network as one plain string --
-- "SharpenEdge=Excellent;WrapCloth=Good" -- because a timed action's
-- constructor arguments are what multiplayer rebuilds the action from on
-- the server, and a Lua table is not one of the types that survives that.
function S.serializeMap(map)
    local parts = {}
    for procId, word in pairs(map or {}) do
        if S.isWord(word) then parts[#parts + 1] = procId .. "=" .. word end
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

function S.parseMap(str)
    local map = {}
    if type(str) ~= "string" then return map end
    for procId, word in str:gmatch("([%w_]+)=([%a]+)") do
        if S.isWord(word) then map[procId] = word end
    end
    return map
end

-- The word a procedure currently holds, given a done-table and a quality-
-- table (either the crafting window's own session tables or a bookmarked
-- item's ModData). A procedure that is done but has no word is a bookmark
-- from before this update -> LEGACY_WORD.
function S.wordFor(procId, doneTable, qualityTable)
    local w = qualityTable and qualityTable[procId]
    if doneTable and doneTable[procId] then
        if w and w ~= "Miss" then return w end
        return S.LEGACY_WORD
    end
    return w -- nil (never tried) or "Miss" (tried, failed)
end

-- Full {procId = word} map for a recipe, from done + quality tables --
-- what Incomplete/Finish send to the server.
function S.collectMap(recipe, doneTable, qualityTable)
    local map = {}
    for _, procId in ipairs(recipe.procedures) do
        local w = S.wordFor(procId, doneTable, qualityTable)
        if w then map[procId] = w end
    end
    return map
end

function S.allDone(recipe, map)
    for _, procId in ipairs(recipe.procedures) do
        local w = map[procId]
        if not w or w == "Miss" then return false end
    end
    return true
end

function S.wordForAverage(avg)
    if avg < S.BAD_BELOW then return "Bad" end
    if avg < S.GOOD_BELOW then return "Good" end
    return "Excellent"
end

-- Average of the procedures scored so far (Miss/untried left out), and its
-- word. nil when nothing is scored yet.
function S.overall(recipe, map)
    local sum, n = 0, 0
    for _, procId in ipairs(recipe.procedures) do
        local sc = S.SCORE[map[procId] or ""]
        if sc and sc > 0 then
            sum = sum + sc
            n = n + 1
        end
    end
    if n == 0 then return nil, nil end
    local avg = sum / n
    return S.wordForAverage(avg), avg
end

function S.rollGrade(word)
    local pool = S.GRADE_POOLS[word] or S.GRADE_POOLS.Bad
    local roll = ZombRand(100)
    local cumulative = 0
    for i, chance in ipairs(S.GRADE_ODDS) do
        cumulative = cumulative + chance
        if roll < cumulative then return pool[i] end
    end
    return pool[#pool]
end

-- Bookmark helpers ------------------------------------------------------------

function S.writeBookmark(item, recipeId, map)
    if not item then return end
    local md = item:getModData()
    local done, quality = {}, {}
    for procId, word in pairs(map or {}) do
        quality[procId] = word
        if word ~= "Miss" then done[procId] = true end
    end
    md.TWA_RecipeId = recipeId
    md.TWA_DoneProcedures = done
    md.TWA_ProcQuality = quality
end

-- One procedure's result, recorded straight onto a bookmarked item.
function S.recordOnItem(item, procId, word)
    if not item or not procId or not S.isWord(word) then return end
    local md = item:getModData()
    md.TWA_DoneProcedures = md.TWA_DoneProcedures or {}
    md.TWA_ProcQuality = md.TWA_ProcQuality or {}
    md.TWA_ProcQuality[procId] = word
    if word ~= "Miss" then md.TWA_DoneProcedures[procId] = true end
end

-- Cancel on a bookmarked item: the item goes back to being a plain base item.
function S.clearBookmark(item)
    if not item then return end
    local md = item:getModData()
    md.TWA_RecipeId = nil
    md.TWA_DoneProcedures = nil
    md.TWA_ProcQuality = nil
end

function S.isBookmarked(item)
    return item ~= nil and item:getModData().TWA_RecipeId ~= nil
end

-- Item helpers ----------------------------------------------------------------

-- The copy of `item` that THIS machine's inventory holds. On a multiplayer
-- server the item object a timed action was rebuilt with is not necessarily
-- the object the server's inventory holds (same lesson Casualties Undead
-- documents for its saline bags), so look it up again by id.
function S.findItem(character, item)
    if not character or not item then return nil end
    local inv = character:getInventory()
    if not inv then return nil end
    local id = item.getID and item:getID()
    if id then
        for _, m in ipairs({ "getItemWithIDRecursiv", "getItemById", "getItemWithID" }) do
            if inv[m] then
                local ok, found = pcall(inv[m], inv, id)
                if ok and found then return found end
            end
        end
    end
    local c = item.getContainer and item:getContainer()
    if c and c:isInCharacterInventory(character) then return item end
    return nil
end

-- Remove one specific item wherever in the character's inventory it sits
-- (a bag inside the main inventory included), and tell the owning client
-- when this runs on a server.
function S.removeItem(character, item)
    local it = S.findItem(character, item)
    if not it then return false end
    local c = it:getContainer() or character:getInventory()
    c:Remove(it)
    if isServer() and sendRemoveItemFromContainer then
        sendRemoveItemFromContainer(c, it)
    end
    return true
end

-- A base item to use for a FRESH craft (not resuming a bookmark): never one
-- that already carries a bookmark, so finishing or bookmarking a fresh craft
-- can't eat or overwrite someone else's saved progress -- and a bookmarked
-- copy can't be kept aside while an unbookmarked twin gets consumed in its
-- place (the old "farm the grade" exploit).
function S.pickFreshItem(character, fullType)
    if not character or not fullType then return nil end
    return character:getInventory():getFirstTypeEvalRecurse(fullType, function(it)
        return not S.isBookmarked(it)
    end)
end

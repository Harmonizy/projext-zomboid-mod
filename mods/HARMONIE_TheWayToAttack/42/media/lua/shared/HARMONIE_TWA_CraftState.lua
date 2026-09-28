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

-- Active craft (request 2026-09-28: "ทำให้ไม่สามารถทำได้หลายสูตรพร้อมกัน
-- เมื่อเลือกสูตรใดไปแล้ว ให้หักวัตถุดิบตั้งต้นและชิ้นงานเสริมไปทันที และไม่
-- สามารถเปลี่ยนไปทำสูตรอื่นได้จนกว่าจะกดยกเลิก การปิดหน้าต่างก่อนจะเสร็จจะถือ
-- ว่าเป็นการทำไม่สมบูรณ์ ได้ชิ้นงานไม่สมบูรณ์มาในกระเป๋าและคืนชิ้นงานเสริม
-- กลับมา") -----------------------------------------------------------------
--
-- Pressing Start takes the base item and the supplementary item (base2)
-- AWAY, and the craft becomes the character's one active craft until it is
-- finished, cancelled or left incomplete. The authoritative record lives in
-- the character's own ModData where the timed actions' complete() runs --
-- the server in multiplayer, this machine in single player:
--   TWA_ActiveCraft = { recipeId = "...", map = { [procId] = word, ... } }
-- Every way out goes through giveBack() below, which only ever pays out
-- against that record and clears it in the same step, so a client can't
-- make the server hand the same items back twice.

function S.getActive(character)
    local md = character and character:getModData()
    return md and md.TWA_ActiveCraft or nil
end

local BOOKMARK_KEYS = { TWA_RecipeId = true, TWA_DoneProcedures = true, TWA_ProcQuality = true }

local function copyPlain(v, depth)
    if type(v) ~= "table" then
        local t = type(v)
        return (t == "string" or t == "number" or t == "boolean") and v or nil
    end
    if depth > 4 then return nil end
    local out = {}
    for k, x in pairs(v) do out[k] = copyPlain(x, depth + 1) end
    return out
end

-- What a taken item has to come back as: its own type (a family variant,
-- not just the recipe's listed type), its condition, and its ModData (a
-- grade from an earlier craft, say) minus any old bookmark.
function S.snapshotItem(item)
    if not item then return nil end
    local snap = { type = item:getFullType() }
    if item.getCondition then snap.cond = item:getCondition() end
    local md = {}
    for k, v in pairs(item:getModData()) do
        if not BOOKMARK_KEYS[k] then md[k] = copyPlain(v, 0) end
    end
    snap.md = md
    return snap
end

function S.beginActive(character, recipeId, map, baseSnap, base2Snap)
    local m = {}
    for k, v in pairs(map or {}) do if S.isWord(v) then m[k] = v end end
    character:getModData().TWA_ActiveCraft = { recipeId = recipeId, map = m, base = baseSnap, base2 = base2Snap }
end

-- The progress a base item carries as a bookmark for `recipeId` (resuming),
-- or an empty map.
function S.bookmarkMap(item, recipeId)
    if not item then return {} end
    local md = item:getModData()
    if md.TWA_RecipeId ~= recipeId then return {} end
    local recipe = S.getRecipeById(recipeId)
    if not recipe then return {} end
    return S.collectMap(recipe, md.TWA_DoneProcedures, md.TWA_ProcQuality)
end

function S.clearActive(character)
    character:getModData().TWA_ActiveCraft = nil
end

-- One procedure's word, recorded into the active craft (only if that craft's
-- recipe actually has the procedure).
function S.recordActive(character, procId, word)
    local act = S.getActive(character)
    local recipe = act and S.getRecipeById(act.recipeId)
    if not recipe or not S.isWord(word) then return end
    for _, pid in ipairs(recipe.procedures) do
        if pid == procId then act.map[procId] = word return end
    end
end

local function addToInventory(character, snap, fallbackType)
    local inv = character:getInventory()
    local it = inv:AddItem((snap and snap.type) or fallbackType)
    if it and snap then
        if snap.cond and it.setCondition then it:setCondition(snap.cond) end
        local md = it:getModData()
        for k, v in pairs(snap.md or {}) do md[k] = copyPlain(v, 0) end
    end
    return it, inv
end

local function send(inv, it)
    if it and isServer() and sendAddItemToContainer then sendAddItemToContainer(inv, it) end
end

-- Hand the active craft's items back and end it.
--   kind "incomplete": the base item comes back carrying the progress as a
--                      bookmark (right-click it to resume), plus base2.
--   kind "cancel":     base and base2 come back plain; progress is dropped.
-- `recipeId` must match the active craft. Returns true when it paid out.
function S.giveBack(character, kind, recipeId)
    local act = S.getActive(character)
    if not act or act.recipeId ~= recipeId then return false end
    local recipe = S.getRecipeById(act.recipeId)
    S.clearActive(character)
    if not recipe then return false end
    if recipe.base then
        local it, inv = addToInventory(character, act.base, recipe.base)
        if it and kind == "incomplete" then S.writeBookmark(it, recipe.id, act.map) end
        send(inv, it)
    end
    if recipe.base2 then
        local it, inv = addToInventory(character, act.base2, recipe.base2)
        send(inv, it)
    end
    return true
end

-- Client -> authority: used when the crafting window is CLOSED mid-craft
-- (no timed action can run then). The authority re-checks everything
-- against its own record.
S.NET_MODULE = "HARMONIE_TWA"

function S.requestGiveBack(player, kind, recipeId)
    if isClient() then
        sendClientCommand(player, S.NET_MODULE, "giveBack", { kind = kind, recipeId = recipeId })
    else
        S.giveBack(player, kind, recipeId)
    end
end

-- Stale active craft (the game was left with the window open): hand it
-- back as incomplete. Multiplayer only -- in single player the window
-- restores the craft instead (see TWACraftUI.open).
function S.requestReturnStale(player)
    if isClient() then
        sendClientCommand(player, S.NET_MODULE, "returnStale", {})
    end
end

if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= S.NET_MODULE or not player then return end
        args = args or {}
        if command == "giveBack" and (args.kind == "incomplete" or args.kind == "cancel") then
            S.giveBack(player, args.kind, args.recipeId)
        elseif command == "returnStale" then
            local act = S.getActive(player)
            if act then S.giveBack(player, "incomplete", act.recipeId) end
        end
    end)
end

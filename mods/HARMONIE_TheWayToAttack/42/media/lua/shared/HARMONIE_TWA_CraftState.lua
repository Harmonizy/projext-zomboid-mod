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

require "HARMONIE_TWA_Config"
require "HARMONIE_TWA_Sources"

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
-- Round 17 ("ปรับให้ คุณภาพรวม แย่ หากต่ำกว่า 2.5 และ คุณภาพรวมดีหากต่ำกว่า 2.9"):
S.BAD_BELOW = 2.5 -- round 17 (was 2.0); the sandbox "BadBelow" is used
S.GOOD_BELOW = 2.9 -- round 17 (was 2.5); the sandbox "GoodBelow" is used

-- Grade pools per overall quality, each rolled with the SAME odds in the
-- same order. Round 17 ("(S,A,B),(B,C,D),(D,E,F) ... 10,30,60"): three
-- grades per pool, 10 / 30 / 60 percent (sandbox GradeChance1..3).
S.GRADE_POOLS = {
    Excellent = { "S", "A", "B" },
    Good      = { "B", "C", "D" },
    Bad       = { "D", "E", "F" },
}
S.GRADE_ODDS = { 10, 30, 60 }

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

-- Every item type that can fill a recipe's base slot: `base` itself, then
-- `baseAlt` -- a single type, or (round 10) a list of them, e.g. the chipped
-- stone spear's "any stone" ("หอกหินให้ใช้วัตถุดิบตั้งต้นเป็นหินอะไรก็ได้").
-- Types this game version doesn't have are left out (base itself always
-- stays, so a recipe never ends up with an empty slot).
function S.baseTypes(recipe)
    if not recipe or not recipe.base then return {} end
    local out = { recipe.base }
    local alts = recipe.baseAlt
    if type(alts) == "string" then alts = { alts } end
    local sm = ScriptManager and ScriptManager.instance
    for _, t in ipairs(alts or {}) do
        if not sm or sm:getItem(t) then out[#out + 1] = t end
    end
    return out
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

-- Round 7 (request 2026-09-28: "การกดคราฟปุ่มเสร็จสิ้นในวัตถุดิบต้องมีคุณภาพ
-- ดี หรือเยี่ยมเท่านั้น"): every procedure done, and for a Material recipe
-- the overall quality must also be Good or Excellent -- a Bad material has
-- its weak procedures redone first. (Weapons can still finish at Bad; the
-- quality then decides their grade pool.) Returns ok, reason.
-- Round 19: a gem's STATE, raised one step at a time by the gem-refining
-- recipes (recipe.gemFrom -> recipe.gemTo). Each state has its own tier
-- (the tooltip's colour strip) and socket strength (TWAGemSocket).
S.GEM_STATES = { "Raw", "Refined", "Cut", "Fine", "Radiant", "Pure" }
S.GEM_STATE_TIER = { Raw = 2, Refined = 3, Cut = 4, Fine = 5, Radiant = 6, Pure = 7 }

-- A gem's state ("Raw" for a gem that never got one); nil for a non-gem.
function S.gemState(item)
    if not item or not S.isRolledGem(item:getFullType()) then return nil end
    return item:getModData().TWA_GemState or "Raw"
end

-- Can `item` be this recipe's (fresh) base item? Not someone's bookmark,
-- one of the recipe's base types, and for a gem-refining recipe a gem in
-- the recipe's starting state.
function S.baseOk(recipe, item)
    if not recipe or not item or S.isBookmarked(item) then return false end
    local t = item:getFullType()
    local okType = false
    for _, bt in ipairs(S.baseTypes(recipe)) do if bt == t then okType = true break end end
    if not okType then return false end
    if recipe.gemFrom and S.gemState(item) ~= recipe.gemFrom then return false end
    return true
end

-- A usable base item of `fullType` for `recipe` (nearby containers too).
function S.pickBase(character, recipe, fullType)
    if not character or not fullType then return nil end
    return TWASources.get(character):getFirstTypeEvalRecurse(fullType, function(it) return S.baseOk(recipe, it) end)
end

function S.countBase(character, recipe, fullType)
    return TWASources.get(character):countEval(fullType, function(it) return S.baseOk(recipe, it) end)
end

-- Round 19: a refined gem can break at Finish -- chance by overall quality
-- (sandbox GemBreakBad 50 / GemBreakGood 10 (round 25, was 5) / GemBreakExcellent 0 percent).
S.GEM_BREAK_KEY = { Excellent = "GemBreakExcellent", Good = "GemBreakGood", Bad = "GemBreakBad" }
function S.gemBreakChance(word)
    return TWAConfig.num(S.GEM_BREAK_KEY[word] or "GemBreakBad", 0)
end

-- Round 18 ("ปุ่มฝึกกรรมวิธีจะขึ้นเฉพาะคนที่เคยทำกรรมวิธีนั้นๆแล้วเท่านั้น"):
-- every procedure a character has ever carried out for real (the timed
-- action finished, whatever its word), kept on the character's ModData.
-- Written both where complete() runs and in the client's perform(), so the
-- multiplayer client -- which draws the Practice button -- knows it too.
function S.markTried(character, procId)
    if not character or not procId then return end
    local md = character:getModData()
    md.TWA_ProcTried = md.TWA_ProcTried or {}
    md.TWA_ProcTried[procId] = true
end

function S.hasTried(character, procId)
    if not character or not procId then return false end
    local t = character:getModData().TWA_ProcTried
    if t and t[procId] then return true end
    -- also anything already scored in the craft in hand
    local act = S.getActive and S.getActive(character)
    return act ~= nil and act.map ~= nil and act.map[procId] ~= nil
end

-- Round 16: a recipe whose Finish ROLLS the item given (the Gemstone recipe)
-- instead of handing out its result with a grade.
function S.isRollRecipe(recipe)
    return recipe ~= nil and recipe.roll ~= nil
end

local function itemExists(fullType)
    local sm = ScriptManager and ScriptManager.instance
    return sm ~= nil and sm:getItem(fullType) ~= nil
end

-- Picks what a smashed stone held (TWARecipeData.GemRoll). Round 17: the
-- gem chance follows the overall quality `word` ("เยี่ยม,ดี,แย่ ... 100:0,
-- 75:25, 50:50 ยิ่งคุณภาพรวมสูงเท่าไหร่ โอกาสที่จะได้ pool อัญมณีก็มีมากขึ้น"):
-- sandbox GemChanceExcellent 50 / GemChanceGood 25 / GemChanceBad 0
-- percent a gem -- the diamond GemDiamondShare percent of that, the other
-- gems equal shares of the rest -- otherwise one of the `bad` slots, all
-- equally likely. Types missing from this game are skipped. Runs where
-- Finish's complete() runs (the server in multiplayer). Returns a fullType.
-- `rand(n)` (0..n-1) defaults to ZombRand.
S.GEM_CHANCE_KEY = { Excellent = "GemChanceExcellent", Good = "GemChanceGood", Bad = "GemChanceBad" }

function S.gemChance(word)
    return TWAConfig.num(S.GEM_CHANCE_KEY[word] or "GemChanceBad", 0) -- 0 allowed (floor 1 made 0 read as 1)
end

-- Is `fullType` one of the gems a stone can hold (diamond included)?
function S.isRolledGem(fullType)
    local pool = TWARecipeData.GemRoll
    if fullType == pool.diamond then return true end
    for _, g in ipairs(pool.gems) do if g == fullType then return true end end
    return false
end

function S.rollGemstone(recipe, rand, word)
    rand = rand or ZombRand
    local pool = TWARecipeData.GemRoll
    local roll = rand(10000)                                    -- 0..9999, hundredths of a percent
    local good = math.floor(S.gemChance(word) * 100 + 0.5)
    if roll < good then
        local dia = math.floor(good * TWAConfig.num("GemDiamondShare", 0) / 100 + 0.5)
        if roll < dia and itemExists(pool.diamond) then return pool.diamond end
        local gems = {}
        for _, g in ipairs(pool.gems) do if itemExists(g) then gems[#gems + 1] = g end end
        if #gems > 0 then return gems[rand(#gems) + 1] end
    end
    local slots = {}
    for _, slot in ipairs(pool.bad) do
        local have = {}
        for _, t in ipairs(slot) do if itemExists(t) then have[#have + 1] = t end end
        if #have > 0 then slots[#slots + 1] = have end
    end
    if #slots == 0 then return recipe and recipe.result end
    local slot = slots[rand(#slots) + 1]
    return slot[rand(#slot) + 1]
end

function S.canFinish(recipe, map)
    if not S.allDone(recipe, map) then return false, "notDone" end
    if S.isMaterialRecipe(recipe) and TWAConfig.on("MaterialNeedsGood") then
        local word = S.overall(recipe, map)
        if word ~= "Good" and word ~= "Excellent" then return false, "materialQuality" end
    end
    return true
end

function S.wordForAverage(avg)
    -- Cut points from the sandbox (round 9); S.BAD_BELOW/GOOD_BELOW are the defaults.
    if avg < TWAConfig.num("BadBelow") then return "Bad" end
    if avg < TWAConfig.num("GoodBelow") then return "Good" end
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
    -- Weights from the sandbox (round 9), rolled over their own total.
    local odds, total = {}, 0
    for i = 1, #pool do
        odds[i] = math.max(0, TWAConfig.num("GradeChance" .. i))
        total = total + odds[i]
    end
    if total <= 0 then odds, total = S.GRADE_ODDS, 100 end
    local roll = ZombRand(total)
    local cumulative = 0
    for i, chance in ipairs(odds) do
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
    -- Round 13: or in a container / on the floor nearby.
    return id and TWASources.get(character):findById(id) or nil
end

--- `ref` is an item, or (round 13) just its id -- what the Start action
--- passes, so an item in a crate or on the floor survives the trip to a
--- multiplayer server.
function S.resolveItem(character, ref)
    if type(ref) == "number" then return TWASources.get(character):findById(ref) end
    return S.findItem(character, ref)
end

-- Remove one specific item wherever in the character's inventory it sits
-- (a bag inside the main inventory included), and tell the owning client
-- when this runs on a server.
function S.removeItem(character, item)
    local it = S.resolveItem(character, item)
    if not it then return false end
    return TWASources.remove(it, character:getInventory())
end

-- A base item to use for a FRESH craft (not resuming a bookmark): never one
-- that already carries a bookmark, so finishing or bookmarking a fresh craft
-- can't eat or overwrite someone else's saved progress -- and a bookmarked
-- copy can't be kept aside while an unbookmarked twin gets consumed in its
-- place (the old "farm the grade" exploit).
function S.pickFreshItem(character, fullType)
    if not character or not fullType then return nil end
    return TWASources.get(character):getFirstTypeEvalRecurse(fullType, function(it)
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
-- the authority -- the server in multiplayer, this machine in single player
-- (Global ModData since round 30, see S.getActive):
--   [username] = { recipeId = "...", map = { [procId] = word, ... } }
-- Every way out goes through giveBack() below, which only ever pays out
-- against that record and clears it in the same step, so a client can't
-- make the server hand the same items back twice.

-- ROUND 30 (2026-10-02, real server bug: closing the window lost the items,
-- Finish gave nothing): the record USED to live in the character's ModData
-- on the server. Any client that calls player:transmitModData() (our own
-- Garden to Plate did, every 10 s) sends ITS copy of the whole player
-- ModData -- which never has TWA_ActiveCraft -- and the server's copy is
-- replaced, so the record vanished mid-craft. It now lives in the world's
-- Global ModData (ModData.getOrCreate), keyed by username: saved with the
-- world, and nothing a client sends about the player touches it.
S.ACTIVE_KEY = "HARMONIE_TWA_ActiveCrafts"

local function activeStore()
    if ModData and ModData.getOrCreate then
        local ok, t = pcall(ModData.getOrCreate, S.ACTIVE_KEY)
        if ok and type(t) == "table" then return t end
    end
    S._activeMem = S._activeMem or {}
    return S._activeMem
end

local function activeKey(character)
    local ok, name = pcall(function() return character:getUsername() end)
    return (ok and name and name ~= "") and name or tostring(character)
end

function S.getActive(character)
    if not character then return nil end
    local store, key = activeStore(), activeKey(character)
    local act = store[key]
    -- an older save still holding it on the character: move it over
    local md = character:getModData()
    if not act and md and type(md.TWA_ActiveCraft) == "table" then
        act = md.TWA_ActiveCraft
        store[key] = act
        md.TWA_ActiveCraft = nil
    end
    return act
end

local BOOKMARK_KEYS = { TWA_RecipeId = true, TWA_DoneProcedures = true, TWA_ProcQuality = true,
    TWA_Incomplete = true, TWA_OrigBase = true }

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
    -- An unfinished item handed out by Incomplete stands in for the base
    -- item it was started from: that original is what Cancel gives back.
    local imd = item:getModData()
    if imd.TWA_Incomplete then return copyPlain(imd.TWA_OrigBase, 0) end
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
    activeStore()[activeKey(character)] = { recipeId = recipeId, map = m, base = baseSnap, base2 = base2Snap }
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
    activeStore()[activeKey(character)] = nil
    local md = character:getModData()
    if md then md.TWA_ActiveCraft = nil end
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

-- Request 2026-09-28 (round 6): "การได้ของคืนจากการกดปุ่มไม่สมบูรณ์...ให้
-- ออกมาเป็นของชิ้นนั้นๆไม่ใช่ชิ้นงานตั้งต้นแต่ให้ ดาเมจสูงสุดและต่ำสุดคือ 0
-- แทน" -- an unfinished item is the RESULT item itself, with its damage at
-- 0 until the craft is finished, carrying the progress as a bookmark and
-- the original base item's snapshot (TWA_OrigBase) for a later Cancel.
function S.applyIncomplete(item)
    if not item or not item:getModData().TWA_Incomplete then return end
    if not TWAConfig.on("IncompleteZeroDamage") then return end
    if item.setMinDamage then item:setMinDamage(0) end
    if item.setMaxDamage then item:setMaxDamage(0) end
end

-- Hand the active craft's items back and end it.
--   kind "incomplete": the RESULT item, unfinished (0 damage, progress
--                      bookmarked -- right-click it to carry on), plus base2.
--   kind "cancel":     the original base and base2 come back as they were;
--                      progress is dropped.
-- `recipeId` must match the active craft. Returns true when it paid out.
function S.giveBack(character, kind, recipeId)
    local act = S.getActive(character)
    if not act or act.recipeId ~= recipeId then return false end
    local recipe = S.getRecipeById(act.recipeId)
    S.clearActive(character)
    if not recipe then return false end
    if kind == "incomplete" then
        local inv = character:getInventory()
        -- Round 19: a gem-refining recipe keeps the gem's own type (its
        -- `result` is only a stand-in picture) -- the same gem, unfinished.
        local it = (recipe.keepType and act.base) and addToInventory(character, act.base, recipe.result) or inv:AddItem(recipe.result)
        if it then
            S.writeBookmark(it, recipe.id, act.map)
            local md = it:getModData()
            md.TWA_Incomplete = true
            md.TWA_OrigBase = copyPlain(act.base, 0)
            S.applyIncomplete(it)
            send(inv, it)
        end
    elseif act.base then
        local it, inv = addToInventory(character, act.base, recipe.base)
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

-- An unfinished item's 0 damage is set on the item when Incomplete makes
-- it; set it again whenever one is taken in hand (and for what is already
-- in hand when a game loads), so it holds even if the weapon's per-item
-- damage isn't kept in the save.
if Events and Events.OnEquipPrimary then
    Events.OnEquipPrimary.Add(function(character, item)
        if item then S.applyIncomplete(item) end
    end)
end
if Events and Events.OnGameStart and getPlayer then
    Events.OnGameStart.Add(function()
        local p = getPlayer()
        local item = p and p:getPrimaryHandItem()
        if item then S.applyIncomplete(item) end
    end)
end

-- Round 19: how a gem-refining Finish went, for the client that pressed it
-- (the break window). Server -> that player's client; single player -> kept
-- here for the client code on this same machine.
S.REFINE_RESULTS = S.REFINE_RESULTS or {}
function S.reportRefine(character, token, broken, fullType, state)
    if not token or token == "" then return end
    local res = { token = token, broken = broken and true or false, type = fullType, state = state }
    if isServer() and sendServerCommand then
        sendServerCommand(character, "HARMONIE_TWA", "gemRefine", res)
    else
        S.REFINE_RESULTS[token] = res
    end
end


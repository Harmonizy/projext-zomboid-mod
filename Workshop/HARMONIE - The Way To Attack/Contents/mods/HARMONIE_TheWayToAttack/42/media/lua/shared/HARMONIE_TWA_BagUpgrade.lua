--[[
    HARMONIE - The Way To Attack: bag upgrades (TWA 1.2.0, owner 2026-11-20).

    Replaces 1.1.0's "craft Tomb's Wardrobe bags" (those bags are fashion now,
    HARMONIE_LWS_Tomb). Every WEARABLE VANILLA bag (back, satchel, webbing,
    fanny pack, ammo strap, shoulder holster -- 86 types, `B.BAGS`) can be:

      * raised one TIER at a time, 0 -> 5, by the "Bag tier N" recipes
        (keepType: the same bag comes back with md.TWA_BagTier = N). The bag
        must be EMPTY, not worn / on the hotbar, and at tier N-1;
      * fitted with UPGRADE ITEMS crafted here (35: 7 kinds x 5 tiers). A bag
        of tier N has N slots. An item of tier T fits only a bag of tier >= T;
        one item of a KIND per bag (1.3.0, owner: not the same item and not
        the same kind);
      * an upgrade can be taken out again: it comes back with a chance by
        Tailoring level (10 % + 9 % a level, 100 % at 10), else it is lost.

    Steps (1.3.1, owner): a bag TIER recipe is sewing (stitch + fit); an
    add-on recipe is cutting (the tier's cut + the kind's own step).
    Skill: every step of a tier-T recipe asks Tailoring T (owner: "the ceiling
    is the same as the weapon forging steps" = Blacksmith 1..5). Tier 3 / 4 /
    5 recipes (items and bag tiers) take Elunium / Oridecon / Bradium as their
    second item -- the same ores, same order, as the Epic / Elite / Legendary
    bars.

    Kinds (value per tier 1..5):
      cap     capacity +1..+5            (total <= 50)
      wr      weight reduction +2..+10   (total <= 95)
      run     run speed +0.005..+0.025   (total <= 1.00)
      combat  combat speed +0.005..0.025 (total <= 1.00)
      weight  the bag's own weight -0.1..-0.5 (stays >= 0.1)
      attachS one more SMALL hotbar slot (belt kind)
      attachL one more LARGE hotbar slot (holster kind)

    The game does NOT save an item's own capacity / weight reduction / speed:
    the bag keeps its upgrades in ModData (TWA_BagTier, TWA_BagUps =
    "type;type;..." -- a string, no table holes) and its first, untouched
    values in TWA_BagBase; `B.apply` puts the result back on the item. It runs
    on the SERVER and on every CLIENT (both judge transfers): every 5 s over
    each player's inventory, after every install / remove / tier, when a
    transfer touches a bag (ISInventoryTransferAction.isValid) and when the
    loot window refreshes (client).

    MULTIPLAYER: the client asks (sendClientCommand "bagUp" {op, bag, up |
    idx}); the server checks EVERYTHING again, takes / gives the items, writes
    the bag's ModData and answers "bagUpSync" (the new ModData) or "bagUpMsg"
    (why not). Nothing is decided on the client.
]]--

require "HARMONIE_TWA_RecipeData"
require "HARMONIE_TWA_Procedures"
require "HARMONIE_TWA_CraftState"

TWABagUp = TWABagUp or {}
local B = TWABagUp
local MODULE = "HARMONIE_TWA"
local IT = "HARMONIE_TheWayToAttack."
local log = function(fmt, ...) if TWALog then TWALog("BagUp", fmt, ...) end end

B.MAX_TIER = 5
B.CAT_ITEM, B.CAT_TIER = "BagUp", "BagTier"
-- 2026-11-22 (owner): Epic = Elunium, Elite = Oridecon, Legendary = Bradium
B.ORE = { [3] = IT .. "TWA_Elunium", [4] = IT .. "TWA_Oridecon", [5] = IT .. "TWA_Bradium" }
B.CAP = { cap = 50, wr = 95, run = 1.0, combat = 1.0, weight = 0.1 }
-- the colour strip / tier name of the crafting list: T1..T5 -> Uncommon..Legendary
function B.displayTier(t) return (tonumber(t) or 1) + 2 end

-- ------------------------------------------------------------ the 86 bags
B.BAGS = {
    "Bag_GolfBag", "Bag_GolfBag_Melee", "Bag_Schoolbag", "Bag_Schoolbag_Kids", "Bag_NormalHikingBag", "Bag_BigHikingBag",
    "Bag_SurvivorBag", "Bag_ALICEpack", "Bag_ALICEpack_Army", "Bag_WeaponBag", "Bag_InmateEscapedBag", "Bag_MoneyBag",
    "Bag_WorkerBag", "Bag_DuffelBag", "Bag_BreakdownBag", "Bag_DuffelBagTINT", "Bag_FannyPackFront", "Bag_FannyPackBack",
    "Bag_Satchel", "Bag_RifleCaseCloth", "Bag_RifleCaseCloth2", "Bag_ShotgunCaseCloth", "Bag_ShotgunCaseCloth2",
    "Bag_RifleCaseClothCamo", "Bag_ShotgunBag", "Bag_ShotgunSawnoffBag", "Bag_ShotgunDblBag", "Bag_ShotgunDblSawnoffBag",
    "Bag_ALICE_BeltSus", "Bag_ALICE_BeltSus_Camo", "Bag_ALICE_BeltSus_Green", "Bag_BurglarBag", "Bag_SatchelPhoto",
    "Bag_Police", "Bag_Sheriff", "Bag_SWAT", "Bag_FishingBasket", "Bag_Schoolbag_Patches", "Bag_Schoolbag_Travel",
    "Bag_BigHikingBag_Travel", "Bag_HikingBag_Travel", "Bag_Satchel_Fishing", "Bag_Satchel_Medical", "Bag_Satchel_Military",
    "Bag_Schoolbag_Medical", "Bag_Satchel_Mail", "Bag_Satchel_Leather", "Bag_BaseballBag", "Bag_TennisBag", "Bag_FoodCanned",
    "Bag_FoodSnacks", "Bag_MedicalBag", "Bag_Military", "Bag_ToolBag", "Bag_ALICEpack_DesertCamo", "Bag_ChestRig",
    "Bag_ChestRig_Tarp", "Bag_ClothSatchel_Burlap", "Bag_ClothSatchel_Cotton", "Bag_ClothSatchel_Denim",
    "Bag_ClothSatchel_DenimBlack", "Bag_ClothSatchel_DenimLight", "Bag_CrudeLeatherBag", "Bag_CrudeTarpBag", "Bag_HideSlingBag",
    "Bag_FannyPackFront_Hide", "Bag_FannyPackBack_Hide", "Bag_FannyPackFront_Tarp", "Bag_FannyPackBack_Tarp", "Bag_HideSatchel",
    "Bag_SheetSlingBag", "Bag_TarpSlingBag", "Bag_CraftedFramepack_Large", "Bag_CraftedFramepack_Small",
    "Bag_CraftedFramepack_Large2", "Bag_CraftedFramepack_Large3", "Bag_TarpFramepack_Small", "Bag_TarpFramepack_Large",
    "AmmoStrap_Bullets", "AmmoStrap_Brown_Bullets", "AmmoStrap_Bullets_308", "AmmoStrap_Shells", "AmmoStrap_Brown_Shells",
    "HolsterShoulder", "Bag_HydrationBackpack", "Bag_HydrationBackpack_Camo",
}
B.BAG = {}
for i, t in ipairs(B.BAGS) do
    B.BAGS[i] = "Base." .. t
    B.BAG[B.BAGS[i]] = true
end

-- ------------------------------------------------------------ the 35 items
-- base = the raw material every tier of the kind starts from
B.KINDS = {
    { key = "cap", step = 1, base = "Base.DenimStripsBundle", alt = { "Base.LeatherStripsBundle" },
        names = { "UtilityPouch", "ModularPocket", "ExpandableCompartment", "MilitaryExpansionKit", "RucksackConversionKit" } },
    { key = "wr", step = 2, base = "Base.LeatherStripsBundle", alt = { "Base.Leather_Crude_Small_Tan" },
        names = { "CompressionStraps", "CompressionCube", "LoadDistributionKit", "ErgonomicBackPanel", "TitaniumFrame" } },
    { key = "run", step = 0.005, base = "Base.Leather_Crude_Small_Tan", alt = { "Base.Leather_Crude_Medium_Tan" },
        names = { "PaddedStraps", "ChestHarness", "AluminumStays", "TacticalLoadFrame", "CarbonFiberPanel" } },
    { key = "combat", step = 0.005, base = "Base.Buckle", alt = {},
        names = { "LeatherPatches", "QuickReleaseBuckles", "ReinforcedCanvas", "BagReinforcementKit", "IndustrialHardware" } },
    { key = "weight", step = 0.1, base = "Base.FabricRoll_DenimBlack", alt = { "Base.Tarp" },
        names = { "WaxedThread", "WaterproofNylon", "AramidFabric", "BallisticNylon", "RigidPolymerSheet" } },
    { key = "attachS", step = 1, base = "Base.LeatherStripsBundle", alt = { "Base.DenimStripsBundle" },
        names = { "NylonWebbing", "StitchingAwl", "SteelRivets", "ParachuteHarness", "SalvagedPackFrame" } },
    { key = "attachL", step = 1, base = "Base.Tarp", alt = { "Base.FabricRoll_DenimBlack" },
        names = { "CargoNet", "MolleWebbingPanel", "HeavyDutyZipper", "WaterproofDryBag", "FieldRepairKit" } },
}
B.ITEMS, B.ITEM_LIST = {}, {}
for _, k in ipairs(B.KINDS) do
    for t = 1, B.MAX_TIER do
        local short = "TWA_BagUp_" .. k.names[t]
        local e = { type = IT .. short, short = short, kind = k.key, tier = t, value = k.step * t }
        B.ITEMS[e.type] = e
        B.ITEM_LIST[#B.ITEM_LIST + 1] = e
    end
end
function B.upOf(fullType) return fullType and B.ITEMS[fullType] or nil end

-- ------------------------------------------------------------ the steps
-- Every step of a tier-T recipe asks Tailoring T (time = T x 10 + 10, every
-- TWA step's rule). 1.3.0 (owner 2026-11-20): the five stitches have names of
-- their own and better thread (and a metal needle from tier 3) as the tier
-- rises; every add-on kind has ONE step of its own (B.KIND_STEP), not shared
-- with any other kind.
local STRIPS = { "Base.LeatherStrips", "Base.DenimStrips", "Base.RippedSheets" }
local ANY_NEEDLE = { { kind = "type", value = "Base.Needle" }, { kind = "type", value = "Base.Needle_Brass" },
    { kind = "type", value = "Base.Needle_Bone" } }
local METAL_NEEDLE = { { kind = "type", value = "Base.Needle" }, { kind = "type", value = "Base.Needle_Brass" } }
local AWL = { { kind = "type", value = "Base.Awl" }, { kind = "type", value = "Base.Awl_Bone" }, { kind = "type", value = "Base.Awl_Stone" } }
local CUTTER = { { kind = "type", value = "Base.Scissors" }, { kind = "tag", value = "SHARP_KNIFE" } }
-- the stitch of each tier: thread (rarer as it goes up) and needle
B.STITCH = {
    { needle = ANY_NEEDLE, consumes = { { itemTypes = { "Base.Thread", "Base.Twine" }, qty = 1 } } },
    { needle = ANY_NEEDLE, consumes = { { itemTypes = { "Base.Thread" }, qty = 2 } } },
    { needle = METAL_NEEDLE, consumes = { { itemTypes = { "Base.Thread" }, qty = 1 }, { itemTypes = { "Base.Thread_Sinew" }, qty = 1 } } },
    { needle = METAL_NEEDLE, consumes = { { itemTypes = { "Base.Thread_Sinew" }, qty = 2 } } },
    { needle = METAL_NEEDLE, consumes = { { itemTypes = { "Base.Thread_Aramid" }, qty = 2 } } },
}
-- 1.3.1 (owner): the five CUTS of the add-on recipes, rarer material as
-- the tier rises -- Basic / Pattern / Precision / Multi-Layer / Complex
-- Structural Cutting; tier 1 any cutter, then scissors
local SCISSORS = { { kind = "type", value = "Base.Scissors" } }
B.CUT = {
    { tool = CUTTER, consumes = { { itemTypes = { "Base.RippedSheets", "Base.DenimStrips" }, qty = 1 } } },
    { tool = SCISSORS, consumes = { { itemTypes = { "Base.DenimStrips" }, qty = 2 } } },
    { tool = SCISSORS, consumes = { { itemTypes = { "Base.LeatherStrips" }, qty = 2 } } },
    { tool = SCISSORS, consumes = { { itemTypes = { "Base.Leather_Crude_Small_Tan" }, qty = 1 }, { itemTypes = { "Base.DenimStrips" }, qty = 2 } } },
    { tool = SCISSORS, consumes = { { itemTypes = { "Base.Leather_Crude_Medium_Tan" }, qty = 1 }, { itemTypes = { "Base.LeatherStrips" }, qty = 2 } } },
}
-- the step of each add-on kind: id prefix, tool, what it takes (qty grows
-- with the tier where `grow`), minigame
local function q(t) return math.floor((t + 1) / 2) end -- 1,1,2,2,3
B.KIND_STEP = {
    cap = { id = "BagPocket", icon = "RippedSheets", tool = CUTTER, sound = "TWA_Craft",
        consumes = function(t) return { { itemTypes = { "Base.DenimStrips", "Base.RippedSheets" }, qty = q(t) } } end },
    wr = { id = "BagCompress", icon = "LeatherStrips", tool = AWL, sound = "TWA_Wrap",
        consumes = function(t) return { { itemTypes = { "Base.LeatherStrips" }, qty = q(t) } } end },
    run = { id = "BagPad", icon = "RippedSheets", tool = ANY_NEEDLE, sound = "TWA_Wrap",
        consumes = function(t) return { { itemTypes = { "Base.RippedSheets", "Base.DenimStrips" }, qty = q(t) } } end },
    combat = { id = "BagRivet", icon = "Nails", tool = { { kind = "type", value = "Base.Hammer" } }, sound = "TWA_Hammer",
        consumes = function(t) return { { itemTypes = { "Base.Nails" }, qty = t + 1 } } end },
    weight = { id = "BagTrim", icon = "Scissors", tool = CUTTER, sound = "TWA_Craft",
        consumes = function(t) return { { itemTypes = { "Base.Glue", "Base.Woodglue", "Base.Scotchtape" }, qty = 1 } } end },
    attachS = { id = "BagLoop", icon = "Twine", tool = AWL, sound = "TWA_Wrap",
        consumes = function(t) return { { itemTypes = { "Base.Twine", "Base.LeatherStrips" }, qty = q(t) } } end },
    attachL = { id = "BagHolster", icon = "Buckle", tool = AWL, sound = "TWA_Craft",
        consumes = function(t) return { { itemTypes = { "Base.Buckle" }, qty = 1 }, { itemTypes = { "Base.LeatherStrips" }, qty = q(t) } } end },
}
B.KIND_ORDER = { "cap", "wr", "run", "combat", "weight", "attachS", "attachL" }
local procIds = {}
for t = 1, B.MAX_TIER do
    local lvl, time = "Tailoring:" .. t, t * 10 + 10
    TWAProcedures.List["BagCut" .. t] = { category = "Tailoring", nameKey = "IGUI_TWA_Proc_BagCut" .. t, icon = "Scissors",
        tool = B.CUT[t].tool, consumes = B.CUT[t].consumes, skill = lvl, time = time, sound = "TWA_Craft" }
    TWAProcedures.List["BagSew" .. t] = { category = "Tailoring", nameKey = "IGUI_TWA_Proc_BagSew" .. t, icon = "Needle",
        tool = B.STITCH[t].needle, consumes = B.STITCH[t].consumes, skill = lvl, time = time, sound = "TWA_Craft" }
    TWAProcedures.List["BagFit" .. t] = { category = "Tailoring", nameKey = "IGUI_TWA_Proc_BagFit" .. t, icon = "LeatherStrips",
        consumes = { { itemTypes = STRIPS, qty = 1 } }, skill = lvl, time = time, sound = "TWA_Wrap" }
    procIds[#procIds + 1] = "BagCut" .. t
    procIds[#procIds + 1] = "BagSew" .. t
    procIds[#procIds + 1] = "BagFit" .. t
    for _, kind in ipairs(B.KIND_ORDER) do
        local s = B.KIND_STEP[kind]
        local id = s.id .. t
        TWAProcedures.List[id] = { category = "Tailoring", nameKey = "IGUI_TWA_Proc_" .. id, icon = s.icon,
            tool = s.tool, consumes = s.consumes(t), skill = lvl, time = time, sound = s.sound }
        procIds[#procIds + 1] = id
    end
end
local catAt
for _, c in ipairs(TWAProcedures.Categories) do if c.key == "Tailoring" then catAt = c end end
if not catAt then
    catAt = { key = "Tailoring", nameKey = "IGUI_TWA_ProcCat_Tailoring", ids = {} }
    TWAProcedures.Categories[#TWAProcedures.Categories + 1] = catAt
end
local inCat, inOrder = {}, {}
for _, id in ipairs(catAt.ids) do inCat[id] = true end
for _, id in ipairs(TWAProcedures.Order) do inOrder[id] = true end
for _, id in ipairs(procIds) do
    if not inCat[id] then catAt.ids[#catAt.ids + 1] = id end
    if not inOrder[id] then TWAProcedures.Order[#TWAProcedures.Order + 1] = id end
end

-- ------------------------------------------------------------ the recipes
B.RECIPES = {}
for _, e in ipairs(B.ITEM_LIST) do
    local k
    for _, kk in ipairs(B.KINDS) do if kk.key == e.kind then k = kk end end
    B.RECIPES[#B.RECIPES + 1] = { id = "Make_" .. e.short, result = e.type, base = k.base, baseAlt = k.alt, base2 = B.ORE[e.tier],
        category = B.CAT_ITEM, stats = { icon = e.short, tier = B.displayTier(e.tier), dps = 0 },
        procedures = { "BagCut" .. e.tier, B.KIND_STEP[e.kind].id .. e.tier }, bagUp = e.tier, bagKind = e.kind }
end
local alts = {}
for i = 2, #B.BAGS do alts[#alts + 1] = B.BAGS[i] end
for t = 1, B.MAX_TIER do
    B.RECIPES[#B.RECIPES + 1] = { id = "Make_BagTier" .. t, result = "Base.Bag_ALICEpack", nameKey = "IGUI_TWA_Recipe_BagTier" .. t,
        base = B.BAGS[1], baseAlt = alts, base2 = B.ORE[t], category = B.CAT_TIER, keepType = true, bagTier = t,
        stats = { icon = "AliceBag", tier = B.displayTier(t), dps = 0 },
        procedures = { "BagSew" .. t, "BagFit" .. t } }
end
do
    local have = {}
    for _, r in ipairs(TWARecipeData.List) do have[r.id] = true end
    for _, r in ipairs(B.RECIPES) do
        if not have[r.id] then TWARecipeData.List[#TWARecipeData.List + 1] = r end
    end
end
function B.isBagRecipe(recipe) return recipe ~= nil and (recipe.bagUp ~= nil or recipe.bagTier ~= nil) end

-- ------------------------------------------------------------ helpers
local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
B.call = call

function B.isBag(item)
    if not item or not instanceof or not instanceof(item, "InventoryContainer") then return false end
    return B.BAG[tostring(call(item, "getFullType") or "")] == true
end
local function mdOf(item)
    if not item or not item.getModData then return nil end
    return item:getModData()
end
function B.tierOf(item)
    local md = mdOf(item)
    return md and math.max(0, math.min(B.MAX_TIER, math.floor(tonumber(md.TWA_BagTier) or 0))) or 0
end
-- the upgrade item types in a bag, in slot order
function B.upsOf(item)
    local md, out = mdOf(item), {}
    local s = md and md.TWA_BagUps
    if type(s) ~= "string" or s == "" then return out end
    for part in string.gmatch(s, "[^;]+") do
        if B.ITEMS[part] then out[#out + 1] = part end
    end
    return out
end
-- 1.3.0: who made each fitted add-on (its TWA_CraftedBy), same order as
-- the types: TWA_BagUpBy = "name;name" (a string, like TWA_BagUps)
function B.upByOf(item)
    local md, out = mdOf(item), {}
    local s = md and md.TWA_BagUpBy
    if type(s) ~= "string" or s == "" then return out end
    for part in string.gmatch(s .. ";", "([^;]*);") do out[#out + 1] = part end
    return out
end
local function writeUps(item, list, byList)
    local md = mdOf(item)
    if not md then return end
    md.TWA_BagUps = #list > 0 and table.concat(list, ";") or nil
    if byList then
        local clean = {}
        for i = 1, #list do clean[i] = tostring(byList[i] or ""):gsub(";", ",") end
        md.TWA_BagUpBy = #list > 0 and table.concat(clean, ";") or nil
    end
end
-- the name stamped on what someone makes (as TWA_FinishCraftAction does)
function B.crafterName(character)
    local user = character and character.getUsername and character:getUsername()
    if (isServer() or isClient()) and user and user ~= "" then return user end
    local desc = character and character.getDescriptor and character:getDescriptor()
    return desc and (desc:getForename() .. " " .. desc:getSurname()) or (user or "")
end
function B.isEmpty(bag)
    local inv = call(bag, "getInventory")
    local items = inv and call(inv, "getItems")
    return not items or items:size() == 0
end
-- worn, in a hand or on the hotbar: not to be taken by a recipe
-- 1.5.3 (owner 2026-11-27: "can't pick the bag although it is off the
-- hotbar"): an item can keep its old attached slot number after it left the
-- hotbar (moved into a box / another bag). Only an item lying directly in a
-- character's own inventory can hang on the hotbar, so a slot number on
-- anything else is stale and ignored.
local staleLogged = {}
function B.inUse(item)
    if call(item, "isEquipped") then return true end
    local slot = tonumber(call(item, "getAttachedSlot")) or -1
    if slot < 0 then return false end
    local c = call(item, "getContainer")
    local holder = c and call(c, "getParent")
    local onBody = c ~= nil and call(c, "getContainingItem") == nil
        and holder ~= nil and instanceof(holder, "IsoGameCharacter")
    if not onBody then
        local id = tostring(call(item, "getID"))
        if not staleLogged[id] then
            staleLogged[id] = true
            log("%s (id %s) has hotbar slot %d but is not on a character -- treated as free", TWALogType and TWALogType(item) or "?", id, slot)
        end
        return false
    end
    -- on the body: ask the character's own attached-items list when it has one
    local ai = call(holder, "getAttachedItems")
    if ai and ai.contains then
        local has = call(ai, "contains", item)
        if has == false then return false end
    end
    return true
end
function B.returnChance(player)
    local lvl = 0
    if player and Perks and Perks.Tailoring then lvl = tonumber(call(player, "getPerkLevel", Perks.Tailoring)) or 0 end
    return math.min(100, 10 + 9 * lvl)
end

-- ------------------------------------------------------------ stats
-- which setters this game has (logged once; the admin test logs them too)
B.SETTERS = { "setCapacity", "setWeightReduction", "setRunSpeedModifier", "setCombatSpeedModifier", "setActualWeight" }
function B.probe(item)
    local have, miss = {}, {}
    for _, m in ipairs(B.SETTERS) do
        if item and item[m] then have[#have + 1] = m else miss[#miss + 1] = m end
    end
    return have, miss
end
local probed = false

function B.base(item)
    local md = mdOf(item)
    if not md then return nil end
    if type(md.TWA_BagBase) ~= "table" then
        md.TWA_BagBase = {
            cap = tonumber(call(item, "getCapacity")) or 0,
            wr = tonumber(call(item, "getWeightReduction")) or 0,
            run = tonumber(call(item, "getRunSpeedModifier")) or 1,
            combat = tonumber(call(item, "getCombatSpeedModifier")) or 1,
            weight = tonumber(call(item, "getActualWeight")) or 0,
        }
    end
    return md.TWA_BagBase
end

-- what the bag's values should be now: { cap, wr, run, combat, weight, attachS, attachL }
-- `extra` (optional): one more add-on type, for the UI's preview
function B.compute(item, extra)
    local base = B.base(item)
    if not base then return nil end
    local add = { cap = 0, wr = 0, run = 0, combat = 0, weight = 0, attachS = 0, attachL = 0 }
    local list = B.upsOf(item)
    if extra and B.ITEMS[extra] then list[#list + 1] = extra end
    for _, t in ipairs(list) do
        local e = B.ITEMS[t]
        add[e.kind] = add[e.kind] + e.value
    end
    local out = {
        cap = math.max(tonumber(base.cap) or 0, math.min(B.CAP.cap, (tonumber(base.cap) or 0) + add.cap)),
        wr = math.max(tonumber(base.wr) or 0, math.min(B.CAP.wr, (tonumber(base.wr) or 0) + add.wr)),
        run = math.max(tonumber(base.run) or 1, math.min(B.CAP.run, (tonumber(base.run) or 1) + add.run)),
        combat = math.max(tonumber(base.combat) or 1, math.min(B.CAP.combat, (tonumber(base.combat) or 1) + add.combat)),
        weight = math.min(tonumber(base.weight) or 0, math.max(B.CAP.weight, (tonumber(base.weight) or 0) - add.weight)),
        attachS = add.attachS, attachL = add.attachL,
    }
    -- an unfinished bag (a tier recipe stopped half-way) holds nothing
    local md = mdOf(item)
    if md and md.TWA_Incomplete then out.cap = 0 end
    return out
end

local function near(a, b) return math.abs((tonumber(a) or 0) - (tonumber(b) or 0)) < 0.0005 end
-- put the values on the item; returns how many changed
function B.apply(item)
    if not B.isBag(item) then return 0 end
    local md = mdOf(item)
    if not md or not (md.TWA_BagTier or md.TWA_BagUps or md.TWA_BagBase or md.TWA_Incomplete) then return 0 end
    if not probed then
        probed = true
        local have, miss = B.probe(item)
        log("setters here: %s%s", table.concat(have, ", "), #miss > 0 and (" -- MISSING: " .. table.concat(miss, ", ") .. " (those upgrades do nothing)") or "")
    end
    local v = B.compute(item)
    if not v then return 0 end
    local n = 0
    if item.setCapacity and not near(call(item, "getCapacity"), v.cap) then call(item, "setCapacity", math.floor(v.cap)); n = n + 1 end
    if item.setWeightReduction and not near(call(item, "getWeightReduction"), v.wr) then call(item, "setWeightReduction", math.floor(v.wr)); n = n + 1 end
    if item.setRunSpeedModifier and not near(call(item, "getRunSpeedModifier"), v.run) then call(item, "setRunSpeedModifier", v.run); n = n + 1 end
    if item.setCombatSpeedModifier and not near(call(item, "getCombatSpeedModifier"), v.combat) then call(item, "setCombatSpeedModifier", v.combat); n = n + 1 end
    if item.setActualWeight and not near(call(item, "getActualWeight"), v.weight) then
        call(item, "setActualWeight", v.weight)
        if item.setCustomWeight then call(item, "setCustomWeight", true) end
        n = n + 1
    end
    return n
end

local function walk(inv, depth)
    if not inv or depth > 4 then return 0 end
    local items, n = call(inv, "getItems"), 0
    for i = 0, (items and items:size() or 0) - 1 do
        local it = items:get(i)
        if it and instanceof(it, "InventoryContainer") then
            n = n + B.apply(it)
            n = n + walk(call(it, "getInventory"), depth + 1)
        end
    end
    return n
end
function B.maintain(player)
    return walk(call(player, "getInventory"), 0)
end

-- ------------------------------------------------------------ rules
-- may `up` (an item) go into `bag`? -> ok, reason key
function B.canInstall(bag, up)
    if not B.isBag(bag) then return false, "IGUI_TWA_BagUp_NotBag" end
    local md = mdOf(bag)
    if md and md.TWA_Incomplete then return false, "IGUI_TWA_BagUp_Unfinished" end
    local e = up and B.upOf(call(up, "getFullType"))
    if not e then return false, "IGUI_TWA_BagUp_NotUpgrade" end
    local umd = mdOf(up)
    if umd and umd.TWA_Incomplete then return false, "IGUI_TWA_BagUp_UpUnfinished" end
    local tier = B.tierOf(bag)
    if tier <= 0 then return false, "IGUI_TWA_BagUp_NoTier" end
    if e.tier > tier then return false, "IGUI_TWA_BagUp_TierLow" end
    local ups = B.upsOf(bag)
    if #ups >= tier then return false, "IGUI_TWA_BagUp_Full" end
    -- 1.3.0 (owner): neither the same item NOR the same kind twice in a bag
    for _, t in ipairs(ups) do
        if t == e.type then return false, "IGUI_TWA_BagUp_Same" end
        local o = B.ITEMS[t]
        if o and o.kind == e.kind then return false, "IGUI_TWA_BagUp_SameKind" end
    end
    return true, nil
end

-- may slot `idx` be emptied? -> ok, reason key
function B.canRemove(bag, idx)
    if not B.isBag(bag) then return false, "IGUI_TWA_BagUp_NotBag" end
    local ups = B.upsOf(bag)
    idx = tonumber(idx)
    if not idx or not ups[idx] then return false, "IGUI_TWA_BagUp_NoSlot" end
    local e = B.ITEMS[ups[idx]]
    if e.kind == "cap" then
        -- what is inside must still fit afterwards
        local list = {}
        for i, t in ipairs(ups) do if i ~= idx then list[#list + 1] = t end end
        local md = mdOf(bag)
        local keep = md.TWA_BagUps
        writeUps(bag, list)
        local v = B.compute(bag)
        md.TWA_BagUps = keep
        local inv = call(bag, "getInventory")
        local inside = tonumber(inv and call(inv, "getCapacityWeight")) or 0
        if v and inside > v.cap + 0.001 then return false, "IGUI_TWA_BagUp_TooFull" end
    end
    return true, nil
end

-- the tier recipe's base: the bag at tier N-1, empty, not in use, finished
function B.tierBaseOk(recipe, item)
    if not recipe or not recipe.bagTier then return true end
    if not B.isBag(item) then return false end
    local md = mdOf(item)
    if md and md.TWA_Incomplete then return false end
    if B.tierOf(item) ~= recipe.bagTier - 1 then return false end
    if not B.isEmpty(item) then return false end
    if B.inUse(item) then return false end
    return true
end
-- why a bag of the player's does not fit a tier recipe (UI)
function B.tierBaseWhy(recipe, item)
    local md = mdOf(item)
    if md and md.TWA_Incomplete then return "IGUI_TWA_BagUp_Unfinished" end
    if B.tierOf(item) ~= recipe.bagTier - 1 then return "IGUI_TWA_BagUp_WrongTier" end
    if not B.isEmpty(item) then return "IGUI_TWA_BagUp_NotEmpty" end
    if B.inUse(item) then return "IGUI_TWA_BagUp_InUse" end
    return nil
end

-- ------------------------------------------------------------ authority side
-- Finish of a tier recipe (TWA_FinishCraftAction): the same bag, one tier up
function B.finishTier(character, recipe, snap, token)
    if not snap or not snap.type then return nil end
    local inv = character:getInventory()
    local bag = inv:AddItem(snap.type)
    if not bag then log("tier %d: could NOT make %s again", recipe.bagTier, tostring(snap.type)); return nil end
    if snap.cond and bag.setCondition then call(bag, "setCondition", snap.cond) end
    local md = bag:getModData()
    for k, v in pairs(snap.md or {}) do md[k] = v end
    md.TWA_Incomplete = nil
    md.TWA_BagTier = recipe.bagTier
    md.TWA_BagBy = B.crafterName(character) -- 1.3.0: shown in the tooltip
    if token and token ~= "" then md.TWA_CraftToken = token end
    if snap.tex then pcall(function() local vis = bag:getVisual(); if vis and vis.setTextureChoice then vis:setTextureChoice(snap.tex) end end) end
    B.apply(bag)
    if isServer() and sendAddItemToContainer then sendAddItemToContainer(inv, bag) end
    log("%s: %s is now tier %d (%d upgrade(s) kept)", TWALogName and TWALogName(character) or "?", tostring(snap.type), recipe.bagTier, #B.upsOf(bag))
    return bag
end

local function find(player, id)
    id = tonumber(id)
    if not id or not TWASources then return nil end
    return TWASources.get(player):findById(id)
end
B.find = find

function B.doInstall(player, bagId, upId)
    local bag, up = find(player, bagId), find(player, upId)
    if not bag or not up then log("install REFUSED for %s: bag %s / item %s not found", TWALogName(player), tostring(bagId), tostring(upId)); return false, "IGUI_TWA_BagUp_Gone" end
    if TWACraftState.isBookmarked(up) then return false, "IGUI_TWA_BagUp_UpUnfinished" end
    local ok, why = B.canInstall(bag, up)
    if not ok then log("install REFUSED for %s: %s into %s -- %s", TWALogName(player), TWALogType(up), TWALogType(bag), tostring(why)); return false, why end
    B.base(bag)
    local t = up:getFullType()
    local by = mdOf(up) and mdOf(up).TWA_CraftedBy or ""
    TWASources.remove(up, player:getInventory())
    local list, byList = B.upsOf(bag), B.upByOf(bag)
    list[#list + 1] = t
    byList[#list] = by
    writeUps(bag, list, byList)
    B.apply(bag)
    log("%s put %s into %s (tier %d, %d/%d slots)", TWALogName(player), t, TWALogType(bag), B.tierOf(bag), #list, B.tierOf(bag))
    return true, bag
end

function B.doRemove(player, bagId, idx)
    local bag = find(player, bagId)
    if not bag then return false, "IGUI_TWA_BagUp_Gone" end
    local ok, why = B.canRemove(bag, idx)
    if not ok then log("remove REFUSED for %s: slot %s of %s -- %s", TWALogName(player), tostring(idx), TWALogType(bag), tostring(why)); return false, why end
    local list, byList = B.upsOf(bag), B.upByOf(bag)
    idx = tonumber(idx)
    -- the makers' list as long as the types' (an older bag has none)
    local fixed = {}
    for i = 1, #list do fixed[i] = byList[i] or "" end
    local t = table.remove(list, idx)
    local by = table.remove(fixed, idx)
    writeUps(bag, list, fixed)
    B.apply(bag)
    local chance = B.returnChance(player)
    local back = ZombRand(100) < chance
    if back then
        local inv = player:getInventory()
        local it = inv:AddItem(t)
        if it and by and by ~= "" then it:getModData().TWA_CraftedBy = by end
        if it and isServer() and sendAddItemToContainer then sendAddItemToContainer(inv, it) end
    end
    log("%s took %s out of %s: %s (chance %d%%)", TWALogName(player), t, TWALogType(bag), back and "came back" or "LOST", chance)
    return true, bag, back and "IGUI_TWA_BagUp_Back" or "IGUI_TWA_BagUp_Lost", t
end

-- ------------------------------------------------------------ client side
function B.requestInstall(player, bag, up)
    if not bag or not up then return end
    if isClient() then
        log("asking the server: %s into %s", TWALogType(up), TWALogType(bag))
        sendClientCommand(player, MODULE, "bagUp", { op = "install", bag = bag:getID(), up = up:getID() })
    else
        local ok, why = B.doInstall(player, bag:getID(), up:getID())
        if B.onResult then B.onResult(ok, ok and "IGUI_TWA_BagUp_Done" or why) end
    end
end
function B.requestRemove(player, bag, idx)
    if not bag then return end
    if isClient() then
        log("asking the server: empty slot %d of %s", idx, TWALogType(bag))
        sendClientCommand(player, MODULE, "bagUp", { op = "remove", bag = bag:getID(), idx = idx })
    else
        local ok, why, msg, t = B.doRemove(player, bag:getID(), idx)
        if B.onResult then B.onResult(ok, ok and msg or why, t) end
    end
end

if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= MODULE or command ~= "bagUp" or not player or not args then return end
        local ok, a, b, c
        if args.op == "install" then ok, a = B.doInstall(player, args.bag, args.up)
        elseif args.op == "remove" then ok, a, b, c = B.doRemove(player, args.bag, args.idx)
        else return end
        if ok then
            local md = a:getModData()
            sendServerCommand(player, MODULE, "bagUpSync", { id = args.bag, tier = md.TWA_BagTier, ups = md.TWA_BagUps or "",
                upBy = md.TWA_BagUpBy or "", bagBy = md.TWA_BagBy,
                base = md.TWA_BagBase, msg = b or "IGUI_TWA_BagUp_Done", up = c })
        else
            sendServerCommand(player, MODULE, "bagUpMsg", { msg = a or "IGUI_TWA_BagUp_Refused" })
        end
    end)
end

if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= MODULE or not args then return end
        if command == "bagUpSync" then
            local player = getPlayer and getPlayer()
            local bag = player and find(player, args.id)
            if TWASources and TWASources.forget and player then TWASources.forget(player) end
            if bag then
                local md = bag:getModData()
                md.TWA_BagTier = args.tier
                md.TWA_BagUps = (args.ups ~= "" and args.ups) or nil
                md.TWA_BagUpBy = (args.upBy and args.upBy ~= "" and args.upBy) or nil
                if args.bagBy then md.TWA_BagBy = args.bagBy end
                if type(args.base) == "table" then md.TWA_BagBase = args.base end
                B.apply(bag)
                log("server sync for bag id %s: tier %s, upgrades %s", tostring(args.id), tostring(args.tier), tostring(args.ups))
            else
                log("server sync for bag id %s: not at hand here", tostring(args.id))
            end
            if B.onResult then B.onResult(true, args.msg, args.up) end
        elseif command == "bagUpMsg" then
            if B.onResult then B.onResult(false, args.msg) end
        end
    end)
end

-- ------------------------------------------------------------ keep values on
local nextAt = 0
if Events and Events.OnTick then
    Events.OnTick.Add(function()
        local t = getTimestampMs and getTimestampMs() or 0
        if t < nextAt then return end
        nextAt = t + 5000
        if isServer and isServer() then
            local list = getOnlinePlayers and getOnlinePlayers()
            for i = 0, (list and list:size() or 0) - 1 do pcall(B.maintain, list:get(i)) end
        else
            for i = 0, (getNumActivePlayers and getNumActivePlayers() or 1) - 1 do
                local p = getSpecificPlayer and getSpecificPlayer(i)
                if p then pcall(B.maintain, p) end
            end
        end
    end)
end

-- a bag in a box / on the floor gets its values back the moment a transfer
-- touches it (both sides judge whether the item fits)
local wrapped = false
local function wrapTransfer()
    if wrapped or not ISInventoryTransferAction or not ISInventoryTransferAction.isValid then return end
    wrapped = true
    local orig = ISInventoryTransferAction.isValid
    ISInventoryTransferAction.isValid = function(self, ...)
        pcall(function()
            local d = self.destContainer and self.destContainer:getContainingItem()
            if d then B.apply(d) end
            if self.item then B.apply(self.item) end
        end)
        return orig(self, ...)
    end
    log("transfer check wrapped (upgraded bags keep their capacity anywhere)")
end
if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(wrapTransfer) end
    if Events.OnGameStart then Events.OnGameStart.Add(wrapTransfer) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(wrapTransfer) end
end

log("bag upgrades: %d bags, %d upgrade items, %d recipes, steps Tailoring 1..%d", #B.BAGS, #B.ITEM_LIST, #B.RECIPES, B.MAX_TIER)

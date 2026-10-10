--[[
    HARMONIE - From Garden to Plate
    Awards vitamins for every eat action.

    Solid food ONLY -- ISEatFoodAction (media/lua/shared/TimedActions/
    ISEatFoodAction.lua), driven by getBaseHunger()/getHungerChange() on
    the item itself. FluidContainer-based drinks (Milk and anything else
    consumed the same way, via ISDrinkFluidAction) are DELIBERATELY not
    tracked at all, per an explicit decision after a long debugging arc
    around them: a vanishingly small FluidContainer-based item list
    (essentially just the milk family) kept surfacing new edge cases --
    missing DB entries for item variants (Milk_Personalsized), and fluid
    content draining progressively throughout the WHOLE timed action via
    update() rather than at complete() the way solid food's character:
    Eat() does, which broke the "read hunger before calling through"
    pattern that works fine below. An ISDrinkFluidAction wrap and a
    profile-based fraction calculation (HARMONIE_GTP.
    GetVitaminGainsFromProfile) were built and made to work correctly,
    but the category was judged not worth the ongoing maintenance/support
    burden relative to how little of the food database it actually
    covers -- removed entirely rather than left half-supported. See
    HARMONIE_FoodVitaminDatabase.lua's Dairy section for where the DB
    rows used to be.

    Also occasionally comments in-character on the taste of food rich in
    any one of the 6 vitamins when eaten -- see maybeSayTasteReaction
    below. Pure flavor, no mechanical effect. A character with Cooking 3+
    (the same threshold HARMONIE_TooltipHook.lua uses to let someone read
    a food's vitamin content) comments on the actual nutrition instead of
    just the taste, since they'd genuinely recognize it.

    IMPORTANT (read BEFORE consuming, not after): the wrap below reads
    everything it needs from the item BEFORE calling through to the
    original complete(), which is what actually invokes vanilla's native
    character:Eat() call. That native call can fully consume and
    remove a single-serving item (a whole raw carrot eaten in one action,
    percentage=1) -- after which the item's own getHungerChange()/ModData
    reads are no longer trustworthy (confirmed as the actual cause of a
    reported bug: eating a whole raw item granted ZERO vitamins every
    time, while some other items over-granted wildly -- both symptoms
    trace back to reading mutable item state on an item the native call
    had already consumed out from under this code). An earlier version of
    this file read AFTER calling through, matching neither of the two
    safe patterns already used elsewhere in this mod: HARMONIE_
    RecipeVitamins.lua's ISAddItemInRecipe wrap explicitly reads hunger
    before/after specifically because of this exact hazard (see its own
    comments), and its ISCraftAction override reads ingredient data
    before RecipeManager.PerformMakeItem consumes them. Reading first here
    just applies that same lesson to eating.

    Also calls HARMONIE_GTP.LogMissingProfile (see
    HARMONIE_FoodVitaminDatabase.lua) whenever the eaten item resolves to
    no vitamin profile at all -- a permanent, always-on, one-line
    console.txt warning rather than another round of temporary debug
    prints, so a real DB gap surfaces immediately instead of needing a
    dedicated debugging session to notice.
]]--

require "TimedActions/ISEatFoodAction"
require "HARMONIEGardenToPlate/HARMONIE_FoodVitaminDatabase"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

local function applyGains(character, gains)
    if not gains then return end
    -- sandbox FoodVitaminMultiplier (default 5.0): food only
    local mult = tonumber(HARMONIE_GTP.Config and HARMONIE_GTP.Config.foodVitaminMultiplier) or 1
    if mult < 0 then mult = 0 end
    for vit, amount in pairs(gains) do
        HARMONIE_GTP.VitData.Add(character, vit, amount * mult)
    end
    if HARMONIE_GTP.LogOnce then HARMONIE_GTP.LogOnce("foodmult:" .. tostring(mult), "Eat", "food vitamins x%.2f (sandbox FoodVitaminMultiplier)", mult) end
end

--[[
    A small, occasional in-character reaction to what's actually in the
    food -- not tied to the mechanical vitamin gain above, just flavor,
    one candidate reaction per vitamin plus one for home-canned texture:

      A -- the richest A sources here (Carrots, SweetPotato,
           MixedVegetables, GrapeLeaves) are the sweet, earthy root
           vegetables, so this reads as a mellow sweetness.
      B -- the richest B sources are meat, fish, and hearty
           starches/legumes (Beef, Salmon, Chicken/Turkey, Potato, Dried
           Lentils), so this reads as a savory, filling meal.
      C -- genuinely sour/tangy in real life (citrus, peppers, etc).
      D -- the richest D sources here are oily fish (Salmon, FishFillet),
           so this reads as a briny, oceanic taste.
      E -- the richest E sources are nuts/oils (Avocado, Peanuts), so
           this reads as nutty and a little oily.
      K -- the richest K sources are leafy greens/brassicas (Spinach,
           BrusselSprouts, GrapeLeaves), which really do taste "grassy".

    Gated on the item's profile (not the amount just eaten) so a single
    bite of something genuinely rich in one of these can trigger it, and
    on a flat chance so it doesn't fire on literally every relevant meal
    -- that got old fast in testing. If a food qualifies for more than
    one (rare, since the thresholds are set fairly high), only one line
    is said, picked at random among whichever qualify, so eating one
    thing never talks over itself with two comments back to back.
]]--
local TASTE_CHANCE_PERCENT = 35
local TASTE_THRESHOLDS = {A = 200, B = 3, C = 30, D = 10, E = 2, K = 60}
local KNOWLEDGEABLE_COOKING_LEVEL = 3

-- Plain taste reaction -- what anyone would notice, no nutrition
-- knowledge required. One "funny" variant per vitamin mixed in with the
-- straight ones.
local TasteLineKeys = {
    A = {"IGUI_HARMONIE_TasteSweetA_1", "IGUI_HARMONIE_TasteSweetA_2", "IGUI_HARMONIE_TasteSweetA_Funny"},
    B = {"IGUI_HARMONIE_TasteHeartyB_1", "IGUI_HARMONIE_TasteHeartyB_2", "IGUI_HARMONIE_TasteHeartyB_Funny"},
    C = {"IGUI_HARMONIE_TasteSourC_1", "IGUI_HARMONIE_TasteSourC_2", "IGUI_HARMONIE_TasteSourC_3", "IGUI_HARMONIE_TasteSourC_Funny"},
    D = {"IGUI_HARMONIE_TasteBrinyD_1", "IGUI_HARMONIE_TasteBrinyD_2", "IGUI_HARMONIE_TasteBrinyD_Funny"},
    E = {"IGUI_HARMONIE_TasteNuttyE_1", "IGUI_HARMONIE_TasteNuttyE_2", "IGUI_HARMONIE_TasteNuttyE_Funny"},
    K = {"IGUI_HARMONIE_TasteGrassyK_1", "IGUI_HARMONIE_TasteGrassyK_2", "IGUI_HARMONIE_TasteGrassyK_3", "IGUI_HARMONIE_TasteGrassyK_Funny"},
}

-- Said instead of the plain reaction above when the character has
-- Cooking 3+ -- they recognize the actual nutritional value, not just
-- the taste, same threshold HARMONIE_TooltipHook.lua uses.
local KnowledgeableLineKeys = {
    A = {"IGUI_HARMONIE_KnowA_1", "IGUI_HARMONIE_KnowA_2"},
    B = {"IGUI_HARMONIE_KnowB_1", "IGUI_HARMONIE_KnowB_2"},
    C = {"IGUI_HARMONIE_KnowC_1", "IGUI_HARMONIE_KnowC_2"},
    D = {"IGUI_HARMONIE_KnowD_1", "IGUI_HARMONIE_KnowD_2"},
    E = {"IGUI_HARMONIE_KnowE_1", "IGUI_HARMONIE_KnowE_2"},
    K = {"IGUI_HARMONIE_KnowK_1", "IGUI_HARMONIE_KnowK_2"},
}

local CannedTasteLineKeys = {"IGUI_HARMONIE_TasteCanned_1", "IGUI_HARMONIE_TasteCanned_2", "IGUI_HARMONIE_TasteCanned_Funny"}
local HOME_CANNED_PREFIX = "HARMONIEGardenToPlate.HomeCanned"

-- Takes the already-resolved profile/fullType (read BEFORE the item was
-- consumed -- see the file header) rather than the item itself, since by
-- the time this is called the native eat/drink call may have already
-- removed or reset it.
local function maybeSayTasteReaction(character, profile, fullType)
    if not profile or not character.Say then return end

    -- Candidates are stored as the vitamin letter itself (or "CANNED"
    -- for the texture reaction), NOT the resolved line list -- which
    -- pool to actually read from (plain taste vs knowledgeable) is only
    -- decided after picking a winner, based on Cooking skill.
    local candidates = {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if profile[vit] and profile[vit] >= TASTE_THRESHOLDS[vit] then
            table.insert(candidates, vit)
        end
    end
    if fullType and fullType:find(HOME_CANNED_PREFIX, 1, true) == 1 then
        table.insert(candidates, "CANNED")
    end
    if #candidates == 0 then return end
    if ZombRand(100) >= TASTE_CHANCE_PERCENT then return end

    local picked = candidates[ZombRand(#candidates) + 1]
    local keys
    if picked == "CANNED" then
        keys = CannedTasteLineKeys
    elseif character:getPerkLevel(Perks.Cooking) >= KNOWLEDGEABLE_COOKING_LEVEL then
        keys = KnowledgeableLineKeys[picked]
    else
        keys = TasteLineKeys[picked]
    end
    character:Say(getText(keys[ZombRand(#keys) + 1]))
end

--[[
    MULTIPLAYER (2026-10-02 audit): B42 runs complete() on the SERVER in
    multiplayer, and the server never loads this client/ file -- so in MP
    eating granted no vitamins at all. The client's copy of the action ends
    through perform() instead (the same split EHR_MedicationHook handles).
    So: what to award is read at start() (the item is whole then), awarded
    in complete() in single player, in perform() on a multiplayer client;
    a flag on the action keeps it to exactly once.
]]--
local function readGains(self)
    local item = self.item
    local out = {}
    pcall(function()
        out.gains = HARMONIE_GTP.GetVitaminGains(item, self.percentage or 1)
        out.profile = HARMONIE_GTP.GetVitaminProfileForItem(item)
        out.fullType = item:getFullType()
    end)
    if not out.profile then pcall(HARMONIE_GTP.LogMissingProfile, item, "eat") end
    return out
end

local function award(self, r)
    if self.gtpAwarded or not r then return end
    self.gtpAwarded = true
    applyGains(self.character, r.gains)
    maybeSayTasteReaction(self.character, r.profile, r.fullType)
end

local original_ISEatFoodAction_start = ISEatFoodAction.start
function ISEatFoodAction:start()
    self.gtpRead = readGains(self)
    return original_ISEatFoodAction_start(self)
end

local original_ISEatFoodAction_complete = ISEatFoodAction.complete

function ISEatFoodAction:complete()
    if self.gtpAwarded then return original_ISEatFoodAction_complete(self) end
    -- Read everything BEFORE calling through -- see file header.
    local r = readGains(self)
    local result = original_ISEatFoodAction_complete(self)
    award(self, r)
    return result
end

local original_ISEatFoodAction_perform = ISEatFoodAction.perform
function ISEatFoodAction:perform()
    if isClient() and not self.gtpAwarded then award(self, self.gtpRead or readGains(self)) end
    return original_ISEatFoodAction_perform(self)
end

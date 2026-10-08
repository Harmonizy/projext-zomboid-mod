--[[
    HARMONIE - From Garden to Plate
    Fruit Farming's fruit seeds in loot (2026-10-08, from the suggestions
    list: "เมล็ดผลไม้ในของปล้น") -- so a survivor can start an orchard without
    first finding the fresh fruit to cut seeds from.

    No list names are guessed: at OnPreDistributionMerge every procedural
    loot list is scanned, and each list that already holds a vanilla seed
    (an item whose type ends in "Seed" or "BagSeed2" -- loose seeds and seed
    packets; not "Seeds", the snacks) also gets the fruit seeds, each at
    1/15 of the strongest vanilla seed weight in that list. Every entry of
    a list rolls on its own, so the 15 fruit seeds together turn up about
    as often as that one vanilla seed (0.11.1: was a fifth each, which
    added up to three times the vanilla seed -- a flood, not a find).
    console.txt lists the lists it touched.
]]--

HARMONIE_GTP = HARMONIE_GTP or {}

local FRUIT_SEEDS = {
    "FruitFarming.AppleSeed", "FruitFarming.AvocadoSeed", "FruitFarming.BananaSeed", "FruitFarming.CherrySeed",
    "FruitFarming.GrapefruitSeed", "FruitFarming.GrapesSeed", "FruitFarming.LemonSeed", "FruitFarming.LimeSeed",
    "FruitFarming.MangoSeed", "FruitFarming.OliveSeed", "FruitFarming.OrangeSeed", "FruitFarming.PeachSeed",
    "FruitFarming.PearSeed", "FruitFarming.PineappleSeed", "FruitFarming.CoffeeSeed",
}
HARMONIE_GTP.FruitSeedLootShare = 1 / #FRUIT_SEEDS

local function log(fmt, ...)
    if HARMONIE_GTP.Log then return HARMONIE_GTP.Log("SeedLoot", fmt, ...) end
    local ok, msg = pcall(string.format, fmt, ...)
    print("[HARMONIE_GTP][SeedLoot] " .. (ok and msg or tostring(fmt)))
end

local function isVanillaSeed(name)
    if type(name) ~= "string" or name:find("FruitFarming.", 1, true) then return false end
    -- not "...Seeds": that is how snacks are named (SunflowerSeeds, PumpkinSeeds)
    return name:sub(-4) == "Seed" or name:sub(-8) == "BagSeed2"
end

function HARMONIE_GTP.AddFruitSeedLoot()
    if HARMONIE_GTP.fruitSeedLootDone then log("already added, skipped a second call"); return end
    HARMONIE_GTP.fruitSeedLootDone = true
    local lists = ProceduralDistributions and ProceduralDistributions.list
    if type(lists) ~= "table" then log("ProceduralDistributions.list missing -- no fruit seeds added"); return end
    local touched = {}
    for listName, list in pairs(lists) do
        local items = type(list) == "table" and list.items
        if type(items) == "table" then
            local best = 0
            for i = 1, #items - 1, 2 do
                if isVanillaSeed(items[i]) and tonumber(items[i + 1]) then best = math.max(best, tonumber(items[i + 1])) end
            end
            if best > 0 then
                local w = best * HARMONIE_GTP.FruitSeedLootShare
                for _, seed in ipairs(FRUIT_SEEDS) do
                    table.insert(items, seed)
                    table.insert(items, w)
                end
                touched[#touched + 1] = string.format("%s (vanilla seed %.3g -> each fruit seed %.3g)", tostring(listName), best, w)
            end
        end
    end
    table.sort(touched)
    log("%d fruit seeds (share %.4f each) added to %d loot lists: %s", #FRUIT_SEEDS, HARMONIE_GTP.FruitSeedLootShare,
        #touched, #touched > 0 and table.concat(touched, ", ") or "(none found -- check the vanilla seed names)")
end

if Events and Events.OnPreDistributionMerge then
    Events.OnPreDistributionMerge.Add(HARMONIE_GTP.AddFruitSeedLoot)
end

-- From "Fruit Farming (B42)" by leina (Steam Workshop 3779625821), built into
-- HARMONIE - From Garden to Plate with credit -- see 42/CREDITS.txt. Changed
-- only by the marked HARMONIE lines (load order, a count in console.txt).
--***********************************************************
--**                    FruitFarming                       **
--**  Adds farmable crops for vanilla fruits. Harvested    **
--**  produce is the vanilla fruit item itself. Growth     **
--**  sprites are this mod's own tile sheets, assigned in  **
--**  FF_farmingSprites.lua; only the trampled sprite is   **
--**  still borrowed from the vanilla crop (spriteSrc).    **
--***********************************************************

require "Farming/farming_vegetableconf"
if not farming_vegetableconf then return end
-- HARMONIE (2026-10-10): the vanilla crops this file copies (BellPepper,
-- Cucumber, Corn, Tomato, Barley...) are defined in
-- farming_vegetableconf_vegetables.lua, which nothing requires -- it only
-- runs when the game reaches it in its file order. Should this file come
-- first, every fruit crop was switched off ("missing vanilla sprite
-- source"). Load them now; running them again later only re-assigns the
-- same vanilla entries.
pcall(require, "Farming/farming_vegetableconf_vegetables")
pcall(require, "Farming/farming_vegetableconf_vegetables_sprites")

local spriteKinds = { "sprite", "unhealthySprite", "dyingSprite", "deadSprite", "trampledSprite" }

-- key          : farming_vegetableconf key (also used for the Farming_<key> translation)
-- fruit        : vanilla harvest item
-- seed         : this mod's seed item
-- spriteSrc    : vanilla crop whose sprites this entry starts from; FF_farmingSprites.lua
--                then replaces the growth sprites and texture with the mod's own sheet
-- icon         : farming info panel icon (vanilla fruit inventory icon)
-- timeToGrow is HOURS PER GROWTH PHASE; total time to harvest = timeToGrow * harvestLevel(6).
-- e.g. 400 * 6 = 2400h = 100 in-game days (vanilla comparison: strawberry 360*6=90d, barley 432*6=108d)
local fruits = {
    { key = "FFApple",      fruit = "Base.Apple",      seed = "FruitFarming.AppleSeed",      spriteSrc = "BellPepper", icon = "Item_Apple",
      timeToGrow = 400, sowMonth = {3,4,5},  bestMonth = {4}, riskMonth = {5},  badMonth = {11,12,1,2}, coldHardy = true,
      minVeg = 4, maxVeg = 7, minVegAutorized = 9, maxVegAutorized = 13 },

    { key = "FFAvocado",    fruit = "Base.Avocado",    seed = "FruitFarming.AvocadoSeed",    spriteSrc = "Cucumber",   icon = "Item_Avocado",
      timeToGrow = 420, sowMonth = {4,5,6},  bestMonth = {5}, riskMonth = {6},  badMonth = {10,11,12,1,2,3},
      minVeg = 3, maxVeg = 5, minVegAutorized = 7, maxVegAutorized = 10 },

    { key = "FFBanana",     fruit = "Base.Banana",     seed = "FruitFarming.BananaSeed",     spriteSrc = "Corn",       icon = "Item_Banana",
      timeToGrow = 320, sowMonth = {5,6},    bestMonth = {5}, riskMonth = {6},  badMonth = {10,11,12,1,2,3},
      minVeg = 4, maxVeg = 8, minVegAutorized = 10, maxVegAutorized = 14 },

    { key = "FFCherry",     fruit = "Base.Cherry",     seed = "FruitFarming.CherrySeed",     spriteSrc = "Tomato",     icon = "Item_Cherry",
      timeToGrow = 380, sowMonth = {3,4},    bestMonth = {3}, riskMonth = {4},  badMonth = {10,11,12,1,2}, coldHardy = true,
      minVeg = 5, maxVeg = 9, minVegAutorized = 11, maxVegAutorized = 15 },

    { key = "FFGrapefruit", fruit = "Base.Grapefruit", seed = "FruitFarming.GrapefruitSeed", spriteSrc = "BellPepper", icon = "Item_Grapefruit",
      timeToGrow = 400, sowMonth = {4,5,6},  bestMonth = {5}, riskMonth = {6},  badMonth = {10,11,12,1,2,3},
      minVeg = 3, maxVeg = 6, minVegAutorized = 8, maxVegAutorized = 11 },

    { key = "FFGrapes",     fruit = "Base.Grapes",     seed = "FruitFarming.GrapesSeed",     spriteSrc = "Hops",       icon = "Item_Grapes",
      timeToGrow = 340, sowMonth = {4,5,6},  bestMonth = {5}, riskMonth = {6},  badMonth = {11,12,1,2,3},
      minVeg = 4, maxVeg = 7, minVegAutorized = 9, maxVegAutorized = 13 },

    { key = "FFLemon",      fruit = "Base.Lemon",      seed = "FruitFarming.LemonSeed",      spriteSrc = "Cucumber",   icon = "Item_Lemon",
      timeToGrow = 400, sowMonth = {4,5,6},  bestMonth = {5}, riskMonth = {6},  badMonth = {10,11,12,1,2,3},
      minVeg = 4, maxVeg = 7, minVegAutorized = 9, maxVegAutorized = 12 },

    { key = "FFLime",       fruit = "Base.Lime",       seed = "FruitFarming.LimeSeed",       spriteSrc = "Cucumber",   icon = "Item_Lime",
      timeToGrow = 400, sowMonth = {4,5,6},  bestMonth = {5}, riskMonth = {6},  badMonth = {10,11,12,1,2,3},
      minVeg = 4, maxVeg = 7, minVegAutorized = 9, maxVegAutorized = 12 },

    { key = "FFMango",      fruit = "Base.Mango",      seed = "FruitFarming.MangoSeed",      spriteSrc = "Corn",       icon = "Item_Mango",
      timeToGrow = 400, sowMonth = {5,6},    bestMonth = {5}, riskMonth = {6},  badMonth = {10,11,12,1,2,3},
      minVeg = 3, maxVeg = 6, minVegAutorized = 8, maxVegAutorized = 11 },

    { key = "FFOlive",      fruit = "Base.Olives",     seed = "FruitFarming.OliveSeed",      spriteSrc = "Cucumber",   icon = "Item_Olives",
      timeToGrow = 420, sowMonth = {4,5,6},  bestMonth = {5}, riskMonth = {6},  badMonth = {11,12,1,2},
      minVeg = 4, maxVeg = 8, minVegAutorized = 10, maxVegAutorized = 14 },

    { key = "FFOrange",     fruit = "Base.Orange",     seed = "FruitFarming.OrangeSeed",     spriteSrc = "BellPepper", icon = "Item_Orange",
      timeToGrow = 400, sowMonth = {4,5,6},  bestMonth = {5}, riskMonth = {6},  badMonth = {10,11,12,1,2,3},
      minVeg = 4, maxVeg = 7, minVegAutorized = 9, maxVegAutorized = 12 },

    { key = "FFPeach",      fruit = "Base.Peach",      seed = "FruitFarming.PeachSeed",      spriteSrc = "Tomato",     icon = "Item_Peach",
      timeToGrow = 380, sowMonth = {3,4,5},  bestMonth = {4}, riskMonth = {5},  badMonth = {11,12,1,2},
      minVeg = 4, maxVeg = 7, minVegAutorized = 9, maxVegAutorized = 12 },

    { key = "FFPear",       fruit = "Base.Pear",       seed = "FruitFarming.PearSeed",       spriteSrc = "BellPepper", icon = "Item_Pear",
      timeToGrow = 400, sowMonth = {3,4,5},  bestMonth = {4}, riskMonth = {5},  badMonth = {11,12,1,2}, coldHardy = true,
      minVeg = 4, maxVeg = 7, minVegAutorized = 9, maxVegAutorized = 12 },

    { key = "FFPineapple",  fruit = "Base.Pineapple",  seed = "FruitFarming.PineappleSeed",  spriteSrc = "Cabbages",   icon = "Item_Pineapple",
      timeToGrow = 440, sowMonth = {4,5,6},  bestMonth = {5}, riskMonth = {6},  badMonth = {10,11,12,1,2,3},
      minVeg = 1, maxVeg = 3, minVegAutorized = 4, maxVegAutorized = 6 },
}

local function seasonRecipeName(key)
    -- "FFApple" -> "fruitfarming:apple growing season"
    return "fruitfarming:" .. string.lower(string.sub(key, 3)) .. " growing season"
end

-- Vanilla conf entries hardcode icon = "Item_" .. <item Icon>; derive it from the
-- actual item script instead of guessing, falling back to the hardcoded name.
local function fruitIcon(fullType, fallback)
    local ok, scriptItem = pcall(function() return ScriptManager.instance:getItem(fullType) end)
    if ok and scriptItem then
        local icon = scriptItem:getIcon()
        if icon and icon ~= "" and icon ~= "None" then
            return "Item_" .. icon
        end
    end
    return fallback
end

for _, f in ipairs(fruits) do
    local src = farming_vegetableconf.props[f.spriteSrc]
    if src then
        -- borrow the source crop's full sprite sets (healthy/unhealthy/dying/dead/trampled)
        for _, kind in ipairs(spriteKinds) do
            farming_vegetableconf[kind] = farming_vegetableconf[kind] or {}
            if farming_vegetableconf[kind][f.spriteSrc] then
                farming_vegetableconf[kind][f.key] = farming_vegetableconf[kind][f.spriteSrc]
            end
        end

        farming_vegetableconf.props[f.key] = {
            icon = fruitIcon(f.fruit, f.icon),
            texture = src.texture,
            waterLvl = 70,
            waterNeeded = 70,
            timeToGrow = f.timeToGrow,
            minVeg = f.minVeg,
            maxVeg = f.maxVeg,
            minVegAutorized = f.minVegAutorized,
            maxVegAutorized = f.maxVegAutorized,
            vegetableName = f.fruit,
            seedName = f.seed,
            seedTypes = { f.seed },
            -- growth stage at which the plant becomes harvestable (hasVegetable).
            -- Must be <= fullGrown(6) or the plant rots first; growBack crops
            -- (strawberry, LSScrapBush) use 6 — same here.
            harvestLevel = 6,
            mature = 5,
            fullGrown = 6,
            badMonth = f.badMonth,
            sowMonth = f.sowMonth,
            bestMonth = f.bestMonth,
            riskMonth = f.riskMonth,
            seasonRecipe = seasonRecipeName(f.key),
            coldHardy = f.coldHardy,
            growBack = 3,               -- perennial: goes back to stage 3 after harvest
            harvestPosition = "High",
        }
    else
        print("[FruitFarming] missing vanilla sprite source '" .. tostring(f.spriteSrc) .. "' for " .. f.key .. " - crop disabled")
    end
end

--***********************************************************
--** Rice: annual grain, exact parallel of the vanilla     **
--** Barley entry (sheaf harvest -> dry -> thresh).        **
--***********************************************************
local barley = farming_vegetableconf.props["Barley"]
if barley then
    for _, kind in ipairs(spriteKinds) do
        farming_vegetableconf[kind] = farming_vegetableconf[kind] or {}
        if farming_vegetableconf[kind]["Barley"] then
            farming_vegetableconf[kind]["FFRice"] = farming_vegetableconf[kind]["Barley"]
        end
    end

    farming_vegetableconf.props["FFRice"] = {
        icon = fruitIcon("Base.Rice", "Item_RiceRaw"),
        texture = barley.texture,
        waterLvl = 75,              -- deliberate deviation from barley's 30: rice is a thirsty crop
        waterNeeded = 70,
        timeToGrow = 432,
        minVeg = 2,
        maxVeg = 4,
        minVegAutorized = 6,
        maxVegAutorized = 8,
        vegetableName = "FruitFarming.RiceSheaf",
        seedName = "FruitFarming.RiceSheaf",
        seedTypes = { "FruitFarming.RiceSeed" },
        harvestLevel = 6,
        mature = 5,
        fullGrown = 6,
        badMonth = { 10, 11, 12, 1, 2, 3 },
        sowMonth = { 5, 6 },
        bestMonth = { 5 },
        riskMonth = { 6 },
        seasonRecipe = "fruitfarming:rice growing season",
        scytheHarvest = true,
        harvestPosition = "High",
    }
else
    print("[FruitFarming] vanilla Barley conf not found - rice crop disabled")
end

--***********************************************************
--** Coffee: perennial shrub. Harvest is a pod, so it runs **
--** the grain-style dry/grind chain rather than the fruit **
--** one, but regrows after harvest like the fruit trees.  **
--***********************************************************
local coffeeSrc = farming_vegetableconf.props["Tomato"]
if coffeeSrc then
    for _, kind in ipairs(spriteKinds) do
        farming_vegetableconf[kind] = farming_vegetableconf[kind] or {}
        if farming_vegetableconf[kind]["Tomato"] then
            farming_vegetableconf[kind]["FFCoffee"] = farming_vegetableconf[kind]["Tomato"]
        end
    end

    farming_vegetableconf.props["FFCoffee"] = {
        icon = "Item_CoffeetreePod",
        texture = coffeeSrc.texture,
        waterLvl = 70,
        waterNeeded = 70,
        timeToGrow = 440,
        minVeg = 4,
        maxVeg = 8,
        minVegAutorized = 10,
        maxVegAutorized = 14,
        vegetableName = "FruitFarming.CoffeePod",
        seedName = "FruitFarming.CoffeeSeed",
        seedTypes = { "FruitFarming.CoffeeSeed" },
        harvestLevel = 6,
        mature = 5,
        fullGrown = 6,
        badMonth = { 11, 12, 1, 2 },
        sowMonth = { 3, 4, 5 },
        bestMonth = { 4 },
        riskMonth = { 5 },
        seasonRecipe = "fruitfarming:coffee growing season",
        coldHardy = true,
        growBack = 3,
        harvestPosition = "High",
    }
else
    print("[FruitFarming] vanilla Tomato conf not found - coffee crop disabled")
end

--***********************************************************
--** Ginger & peanuts: annual root/legume crops planted    **
--** directly from the vanilla food item — exact parallel  **
--** of vanilla potatoes (seedTypes lists Base.Potato      **
--** itself; no seed item, no extraction recipe needed).   **
--***********************************************************
local rootCrops = {
    { key = "FFGinger",  item = "Base.GingerRoot", spriteSrc = "SweetPotato", icon = "Item_RootGinger",
      timeToGrow = 432, sowMonth = {5,6},   bestMonth = {5}, riskMonth = {6}, badMonth = {10,11,12,1,2,3},
      minVeg = 2, maxVeg = 4, minVegAutorized = 5, maxVegAutorized = 9 },
    { key = "FFPeanuts", item = "Base.Peanuts",    spriteSrc = "Greenpeas",   icon = "Item_Peanut",
      timeToGrow = 432, sowMonth = {4,5,6}, bestMonth = {5}, riskMonth = {6}, badMonth = {10,11,12,1,2},
      minVeg = 3, maxVeg = 6, minVegAutorized = 7, maxVegAutorized = 10 },
}
for _, rc in ipairs(rootCrops) do
    local src = farming_vegetableconf.props[rc.spriteSrc]
    if src then
        for _, kind in ipairs(spriteKinds) do
            farming_vegetableconf[kind] = farming_vegetableconf[kind] or {}
            if farming_vegetableconf[kind][rc.spriteSrc] then
                farming_vegetableconf[kind][rc.key] = farming_vegetableconf[kind][rc.spriteSrc]
            end
        end
        farming_vegetableconf.props[rc.key] = {
            icon = fruitIcon(rc.item, rc.icon),
            texture = src.texture,
            waterLvl = 60,
            waterNeeded = 70,
            timeToGrow = rc.timeToGrow,
            minVeg = rc.minVeg,
            maxVeg = rc.maxVeg,
            minVegAutorized = rc.minVegAutorized,
            maxVegAutorized = rc.maxVegAutorized,
            vegetableName = rc.item,
            seedName = rc.item,
            seedTypes = { rc.item },
            harvestLevel = 5,
            mature = 5,
            fullGrown = 6,
            badMonth = rc.badMonth,
            sowMonth = rc.sowMonth,
            bestMonth = rc.bestMonth,
            riskMonth = rc.riskMonth,
            seasonRecipe = "fruitfarming:" .. string.lower(string.sub(rc.key, 3)) .. " growing season",
        }
    else
        print("[FruitFarming] missing vanilla sprite source '" .. rc.spriteSrc .. "' for " .. rc.key .. " - crop disabled")
    end
end

-- HARMONIE: how many crops made it, once at load (console.txt)
do
    local n, off = 0, {}
    for _, f in ipairs(fruits) do
        if farming_vegetableconf.props[f.key] then n = n + 1 else off[#off + 1] = f.key end
    end
    for _, k in ipairs({ "FFRice", "FFCoffee", "FFGinger", "FFPeanuts" }) do
        if farming_vegetableconf.props[k] then n = n + 1 else off[#off + 1] = k end
    end
    local msg = n .. " crops registered" .. (#off > 0 and (", OFF: " .. table.concat(off, " ")) or "")
    if HARMONIE_GTP and HARMONIE_GTP.Log then pcall(HARMONIE_GTP.Log, "FruitFarming", "%s", msg)
    else print("[HARMONIE_GTP][FruitFarming] " .. msg) end
end

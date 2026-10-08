--[[
    HARMONIE - From Garden to Plate
    Which foods a survivor can GROW (for the vitamin guide's "can be grown"
    marks and its growing section).

    The crops of Fruit Farming (B42) by leina, built into this mod with credit
    (see 42/CREDITS.txt): 14 fruits, rice, ginger and peanuts -- the fruit
    trees, vines and coffee regrow after harvest. Plus the vanilla Build 42
    crops whose harvest is a food this mod tracks.

    H.isGrowable(fullType) also asks the live farming config
    (farming_vegetableconf.props[*].vegetableName) when it is loaded -- single
    player and the host; a multiplayer client does not load server/ files, so
    the static lists below are what it has.
]]--

HARMONIE_GTP = HARMONIE_GTP or {}

-- Fruit Farming crop -> harvest, seed, and how its seeds are got
HARMONIE_GTP.FruitFarmingCrops = {
    { crop = "FFApple", food = "Base.Apple", seed = "FruitFarming.AppleSeed", tree = true },
    { crop = "FFAvocado", food = "Base.Avocado", seed = "FruitFarming.AvocadoSeed", tree = true },
    { crop = "FFBanana", food = "Base.Banana", seed = "FruitFarming.BananaSeed", tree = true },
    { crop = "FFCherry", food = "Base.Cherry", seed = "FruitFarming.CherrySeed", tree = true },
    { crop = "FFGrapefruit", food = "Base.Grapefruit", seed = "FruitFarming.GrapefruitSeed", tree = true },
    { crop = "FFGrapes", food = "Base.Grapes", seed = "FruitFarming.GrapesSeed", tree = true },
    { crop = "FFLemon", food = "Base.Lemon", seed = "FruitFarming.LemonSeed", tree = true },
    { crop = "FFLime", food = "Base.Lime", seed = "FruitFarming.LimeSeed", tree = true },
    { crop = "FFMango", food = "Base.Mango", seed = "FruitFarming.MangoSeed", tree = true },
    { crop = "FFOlive", food = "Base.Olives", seed = "FruitFarming.OliveSeed", tree = true },
    { crop = "FFOrange", food = "Base.Orange", seed = "FruitFarming.OrangeSeed", tree = true },
    { crop = "FFPeach", food = "Base.Peach", seed = "FruitFarming.PeachSeed", tree = true },
    { crop = "FFPear", food = "Base.Pear", seed = "FruitFarming.PearSeed", tree = true },
    { crop = "FFPineapple", food = "Base.Pineapple", seed = "FruitFarming.PineappleSeed", tree = true },
    { crop = "FFRice", food = "Base.Rice", seed = "FruitFarming.RiceSeed" },
    { crop = "FFGinger", food = "Base.GingerRoot", seed = "Base.GingerRoot" },
    { crop = "FFPeanuts", food = "Base.Peanuts", seed = "Base.Peanuts" },
}

-- vanilla Build 42 crops whose harvest is a tracked food
local VANILLA = { "Carrots", "Broccoli", "Cabbage", "Potato", "Tomato", "Strewberrie", "RedRadish",
    "Lettuce", "Onion", "Zucchini", "Watermelon", "Cucumber", "Corn", "BellPepper", "Kale", "Leek",
    "Greenpeas", "SugarBeet", "Turnip", "Cauliflower", "Spinach", "SweetPotato", "Soybeans", "Pumpkin" }

HARMONIE_GTP.GrowableFoods = HARMONIE_GTP.GrowableFoods or {}
for _, c in ipairs(HARMONIE_GTP.FruitFarmingCrops) do HARMONIE_GTP.GrowableFoods[c.food] = true end
for _, n in ipairs(VANILLA) do HARMONIE_GTP.GrowableFoods["Base." .. n] = true end

local fromConf
function HARMONIE_GTP.IsGrowable(fullType)
    if HARMONIE_GTP.GrowableFoods[fullType] then return true end
    if fromConf == nil and farming_vegetableconf and type(farming_vegetableconf.props) == "table" then
        fromConf = {}
        for _, p in pairs(farming_vegetableconf.props) do
            if type(p) == "table" and type(p.vegetableName) == "string" then fromConf[p.vegetableName] = true end
        end
    end
    return fromConf ~= nil and fromConf[fullType] == true
end

--[[
    HARMONIE - From Garden to Plate: the Cooking tab's data (2026-10-08,
    request: "เพิ่มแท็บทำอาหาร ... สูตรอาหารมากมายแบบสำเร็จรูป ... อ้างอิงทุก
    ระบบของ vanilla").

    Every dish here is cooked through one of vanilla Build 42's own
    EVOLVED RECIPES (soup, stew, stir fry, salad, sandwich, burger, pie,
    cake, pasta, rice, oatmeal, omelette, pizza, burrito, taco, ...). The
    tab only decides WHICH vanilla ingredients go in and runs the
    preparation steps first; every ingredient is then added with vanilla's
    own ISAddItemInRecipe action, so:
      - how much of an ingredient one addition uses (the item's evolved
        recipe "use"), the Cooking level saving (vanilla: 3 percent less
        per level) and the cooked-ingredient rule all stay vanilla's;
      - calories, carbohydrates, fat, protein, hunger, thirst, boredom,
        unhappiness, rotting, spices and the dish's name are vanilla's;
      - vitamins ride along through this mod's existing ISAddItemInRecipe
        wrap (HARMONIE_RecipeVitamins.lua), exactly as for a hand-made pot.
    The dish then cooks the vanilla way (stove, oven, campfire, grill).

    Item types below were checked against vanilla B42's own ItemName list
    (media/lua/shared/Translate/EN/ItemName.json). Whether vanilla lets an
    item into a given recipe is asked from vanilla at run time
    (EvolvedRecipe:getItemRecipe) -- an item it refuses is shown greyed
    out and logged, never forced in.
]]--

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.Cook = HARMONIE_GTP.Cook or {}
local K = HARMONIE_GTP.Cook

-- ------------------------------------------------------------------ tools
-- A tool group: item types (best first) and B42 item tags (checked with
-- pcall, so a tag a game version lacks is just skipped). `fallback` items
-- also work but make the minigame harder (a fork instead of a whisk).
K.TOOLS = {
    knife = { types = { "Base.KitchenKnife", "Base.KitchenKnifeForged", "Base.KnifeParing", "Base.KnifeSushi", "Base.KnifeFillet",
        "Base.BreadKnife", "Base.HuntingKnife", "Base.HuntingKnifeForged", "Base.LargeKnife", "Base.MeatCleaver", "Base.MeatCleaverForged",
        "Base.SteakKnife", "Base.KnifePocket", "Base.Handiknife", "Base.FightingKnife", "Base.CrudeKnife", "Base.FlintKnife" },
        tags = { "base:sharpknife" }, fallback = { "Base.CrudeKnife", "Base.FlintKnife", "Base.KnifePocket", "Base.Handiknife" } },
    cleaver = { types = { "Base.MeatCleaver", "Base.MeatCleaverForged", "Base.MeatCleaver_Scrap", "Base.KitchenKnife", "Base.KitchenKnifeForged",
        "Base.LargeKnife", "Base.HuntingKnife" }, fallback = { "Base.KitchenKnife", "Base.KitchenKnifeForged", "Base.LargeKnife", "Base.HuntingKnife" } },
    spoon = { types = { "Base.WoodenSpoon", "Base.Ladle", "Base.Spatula", "Base.Spoon", "Base.SpoonForged", "Base.Spoon_Bone", "Base.PlasticSpoon",
        "Base.Spoon_Silver", "Base.Spoon_Gold", "Base.Fork", "Base.WoodenFork" }, fallback = { "Base.Fork", "Base.WoodenFork", "Base.PlasticSpoon" } },
    whisk = { types = { "Base.Whisk", "Base.Fork", "Base.ForkForged", "Base.WoodenFork", "Base.Fork_Bone", "Base.PlasticFork", "Base.Spoon" },
        fallback = { "Base.Fork", "Base.ForkForged", "Base.WoodenFork", "Base.Fork_Bone", "Base.PlasticFork", "Base.Spoon" } },
    grater = { types = { "Base.CheeseGrater" } },
    -- never required: they make a step easier when they are at hand
    board = { types = { "Base.CuttingBoardWooden", "Base.CuttingBoardPlastic" }, optional = true },
    rollingpin = { types = { "Base.RollingPin" }, optional = true },
}

-- ------------------------------------------------------------- procedures
-- game: the minigame (HARMONIE_CookGames.lua); variant tunes it.
-- tools: required groups; help: optional groups that widen the tolerance.
-- level: Cooking level needed; time: seconds of the timed action at level
-- 0 (each level is 4 percent quicker). xp: vanilla Cooking XP when done.
K.PROCS = {
    wash    = { game = "scrub",  variant = "wash",    tools = {},           help = {},          level = 0, time = 3, xp = 1, icon = "wash" },
    peel    = { game = "scrub",  variant = "peel",    tools = { "knife" },  help = { "board" }, level = 1, time = 4, xp = 2, icon = "peel" },
    chop    = { game = "timing", variant = "chop",    tools = { "knife" },  help = { "board" }, level = 0, time = 4, xp = 2, icon = "chop" },
    mince   = { game = "timing", variant = "mince",   tools = { "cleaver" }, help = { "board" }, level = 3, time = 5, xp = 3, icon = "mince" },
    trim    = { game = "timing", variant = "trim",    tools = { "knife" },  help = { "board" }, level = 2, time = 4, xp = 3, icon = "trim" },
    crack   = { game = "timing", variant = "crack",   tools = {},           help = {},          level = 0, time = 2, xp = 1, icon = "crack" },
    knead   = { game = "timing", variant = "knead",   tools = {},           help = { "rollingpin" }, level = 2, time = 6, xp = 3, icon = "knead" },
    grate   = { game = "scrub",  variant = "grate",   tools = { "grater" }, help = {},          level = 1, time = 3, xp = 2, icon = "grate" },
    whisk   = { game = "circle", variant = "whisk",   tools = { "whisk" },  help = {},          level = 1, time = 4, xp = 2, icon = "whisk" },
    stir    = { game = "circle", variant = "stir",    tools = { "spoon" },  help = {},          level = 0, time = 4, xp = 2, icon = "stir" },
    season  = { game = "fill",   variant = "season",  tools = {},           help = {},          level = 0, time = 2, xp = 1, icon = "season" },
    measure = { game = "fill",   variant = "measure", tools = {},           help = {},          level = 1, time = 3, xp = 2, icon = "measure" },
}
K.PROC_ORDER = { "wash", "peel", "chop", "mince", "trim", "crack", "grate", "knead", "measure", "whisk", "season", "stir" }

-- ------------------------------------------------------------- families
-- One vanilla evolved recipe each, by its script TEMPLATE (vanilla's
-- evolvedrecipes.txt: Template = ...) -- the name items use in their own
-- EvolvedRecipe key. names / results are what the recipe is recognised by
-- at run time (its name, or the dish item it makes); the bases come from
-- vanilla's own table (HARMONIE_CookVanilla.lua, K.VANILLA.recipes).
-- Checked against vanilla B42's evolvedrecipes.txt (2026-10-08).
K.FAMILIES = {
    soup     = { template = "Soup", names = { "Soup", "SoupForged", "Prepare Soup" }, results = { "PotOfSoupRecipe", "PotForgedSoupRecipe", "PotOfSoup" }, icon = "Base.PotOfSoup" },
    stew     = { template = "Stew", names = { "Stew", "StewForged", "Prepare Stew" }, results = { "PotOfStew", "PotForgedStew" }, icon = "Base.PotOfStew" },
    stirfry  = { template = "Stir fry", names = { "Stir fry", "Stir fry Griddle Pan", "Stir fry Forged", "Prepare Stir-fry" }, results = { "PanFriedVegetables", "PanFriedVegetablesForged", "GriddlePanFriedVegetables" }, icon = "Base.PanFriedVegetables" },
    roast    = { template = "Stir fry", names = { "Roasted Vegetables", "Place Ingredients in Roasting Pan" }, results = { "PanFriedVegetables2" }, icon = "Base.PanFriedVegetables2" },
    salad    = { template = "Salad", names = { "Salad", "SaladClay", "Make Salad" }, results = { "Salad", "SaladClay" }, icon = "Base.Salad" },
    fruitsalad = { template = "FruitSalad", names = { "FruitSalad", "FruitSaladClay", "Make Fruit Salad" }, results = { "FruitSalad", "FruitSaladClay" }, icon = "Base.FruitSalad" },
    sandwich = { template = "Sandwich", names = { "Sandwich", "Sandwich Baguette", "Make Sandwich" }, results = { "Sandwich", "BaguetteSandwich" }, icon = "Base.Sandwich" },
    burger   = { template = "Burger", names = { "Burger", "Burger2", "Prepare Burger" }, results = { "BurgerRecipe", "Burger" }, icon = "Base.Burger" },
    hotdog   = { template = "Hotdog", names = { "Hotdog", "Prepare Hotdog" }, results = { "Hotdog" }, icon = "Base.Hotdog" },
    pie      = { template = "Pie", names = { "Pie", "Prepare Pie" }, results = { "PieWholeRaw" }, icon = "Base.PieWholeRaw" },
    sweetpie = { template = "PieSweet", names = { "PieSweet", "Prepare Sweet Pie" }, results = { "PieWholeRawSweet" }, icon = "Base.PieApple" },
    cake     = { template = "Cake", names = { "Cake", "Prepare Cake" }, results = { "CakeRaw" }, icon = "Base.CakeRaw" },
    muffin   = { template = "Muffin", names = { "Muffin" }, results = { "BakingTray_Muffin_Recipe" }, icon = "Base.MuffinFruit" },
    pasta    = { template = "Pasta", names = { "PastaPot", "PastaPan", "PastaPotForged", "PastaPanCopper", "Prepare Pasta" }, results = { "PastaPot", "PastaPan", "PastaPotForged", "PastaPanCopper" }, icon = "Base.PastaPot" },
    rice     = { template = "Rice", names = { "RicePot", "RicePan", "RicePotForged", "RicePanCopper", "Prepare Rice" }, results = { "RicePot", "RicePan", "RicePotForged", "RicePanCopper" }, icon = "Base.RicePot" },
    oatmeal  = { template = "Oatmeal", names = { "Oatmeal" }, results = { "Oatmeal" }, icon = "Base.Oatmeal" },
    omelette = { template = "Omelette", names = { "Omelette", "Omelette Forged" }, results = { "OmeletteRecipe", "OmeletteRecipeForged" }, icon = "Base.EggOmelette" },
    pizza    = { template = "Pizza", names = { "Pizza", "Prepare Pizza" }, results = { "PizzaRecipe" }, icon = "Base.PizzaWhole" },
    burrito  = { template = "Burrito", names = { "Burrito" }, results = { "BurritoRecipe" }, icon = "Base.Burrito" },
    taco     = { template = "Taco", names = { "Taco" }, results = { "TacoRecipe" }, icon = "Base.Taco" },
    pancakes = { template = "Pancakes", names = { "Pancakes", "Waffles" }, results = { "PancakesRecipe", "WafflesRecipe" }, icon = "Base.Pancakes" },
}

-- -------------------------------------------------------------- groups
-- Ingredient lists used by several dishes (best first).
local G = {}
G.root    = { "Base.Potato", "Base.SweetPotato", "Base.Carrots", "Base.Turnip", "Base.RedRadish" }
G.potato  = { "Base.Potato", "Base.SweetPotato" }
G.carrot  = { "Base.Carrots" }
G.onion   = { "Base.Onion", "Base.Leek", "Base.Garlic", "Base.Chives" }
G.garlic  = { "Base.Garlic", "Base.Onion", "Base.Chives" }
G.leafy   = { "Base.Cabbage", "Base.Kale", "Base.Spinach" }
G.lettuce = { "Base.Lettuce", "Base.Kale", "Base.Spinach", "Base.Cabbage" }
G.greens  = { "Base.Broccoli", "Base.Cauliflower", "Base.Greenpeas", "Base.Zucchini", "Base.BellPepper", "Base.Corn", "Base.Eggplant" }
G.pepper  = { "Base.BellPepper", "Base.PepperJalapeno", "Base.Zucchini" }
G.tomato  = { "Base.Tomato", "Base.CannedTomatoOpen" }
G.mushroom = { "Base.MushroomGeneric1", "Base.MushroomGeneric2", "Base.MushroomGeneric3", "Base.MushroomGeneric4",
    "Base.MushroomGeneric5", "Base.MushroomGeneric6", "Base.MushroomGeneric7", "Base.MushroomsButton" }
G.salad   = { "Base.Cucumber", "Base.Tomato", "Base.RedRadish", "Base.BellPepper", "Base.Carrots", "Base.Corn" }
G.beef    = { "Base.Beef", "Base.Steak", "Base.Venison", "Base.MincedMeat" }
G.mince   = { "Base.MincedMeat", "Base.Beef", "Base.Steak", "Base.Venison", "Base.Pork" }
G.game    = { "Base.Rabbitmeat", "Base.Smallanimalmeat", "Base.Smallbirdmeat", "Base.Venison", "Base.Chicken" }
G.chicken = { "Base.Chicken", "Base.Smallbirdmeat", "Base.Rabbitmeat" }
G.pork    = { "Base.Pork", "Base.PorkChop", "Base.Bacon", "Base.Ham", "Base.Sausage" }
G.cured   = { "Base.Bacon", "Base.Ham", "Base.Salami", "Base.Sausage" }
G.fish    = { "Base.FishFillet", "Base.Salmon", "Base.Shrimp", "Base.Crayfish", "Base.Squid", "Base.Oysters", "Base.Lobster" }
G.shrimp  = { "Base.Shrimp", "Base.Crayfish", "Base.Squid", "Base.FishFillet", "Base.Lobster" }
G.beans   = { "Base.OpenBeans", "Base.Blackbeans", "Base.RefriedBeans", "Base.Soybeans", "Base.Tofu" }
G.cheese  = { "Base.Cheese", "Base.SourCream" }
G.egg     = { "Base.Egg", "Base.EggBoiled" }
G.fruit   = { "Base.Apple", "Base.Banana", "Base.Orange", "Base.Peach", "Base.Pear", "Base.Grapes", "Base.Strewberrie",
    "Base.Cherry", "Base.Pineapple", "Base.Mango", "Base.WatermelonSliced" }
G.berry   = { "Base.Strewberrie", "Base.Cherry", "Base.Grapes", "Base.Peach", "Base.Apple" }
G.apple   = { "Base.Apple", "Base.Pear", "Base.Peach" }
G.sweet   = { "Base.Sugar", "Base.SugarBrown", "Base.Honey" }
G.herb    = { "Base.Thyme", "Base.Rosemary", "Base.Parsley", "Base.Basil", "Base.Oregano", "Base.Sage", "Base.Chives",
    "Base.Seasoning_Thyme", "Base.Seasoning_Rosemary", "Base.Seasoning_Parsley", "Base.Seasoning_Basil",
    "Base.Seasoning_Oregano", "Base.Seasoning_Sage", "Base.Seasoning_Chives" }
G.italian = { "Base.Basil", "Base.Oregano", "Base.Seasoning_Basil", "Base.Seasoning_Oregano", "Base.Garlic" }
G.salt    = { "Base.Salt", "Base.Pepper" }
G.hot     = { "Base.Hotsauce", "Base.PepperJalapeno", "Base.PepperJalapenoDried", "Base.Pepper" }
G.asian   = { "Base.Soysauce", "Base.GingerRoot", "Base.GingerPickled", "Base.RiceVinegar" }
G.sauce   = { "Base.Ketchup", "Base.Mustard", "Base.MayonnaiseFull", "Base.BBQSauce" }
G.oil     = { "Base.OilOlive", "Base.OilVegetable", "Base.Butter", "Base.Margarine", "Base.Lard" }
G.spice_sweet = { "Base.Cinnamon", "Base.Sugar", "Base.SugarBrown", "Base.Honey", "Base.CocoaPowder" }
K.GROUPS = G

-- ------------------------------------------------------------------ dishes
-- slots: { group = list or name, adds = vanilla additions, optional, spice }
-- adds is in vanilla's own steps: each one is one ISAddItemInRecipe, which
-- uses the item's own evolved-recipe portion (vanilla decides the amount).
-- The total stays at or under the recipe's own limit (getMaxItems; the
-- tab trims to it at run time and logs it).
local function s(group, adds, extra)
    local t = { group = group, adds = adds or 1 }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
end
local OPT = { optional = true }
local SPICE = { optional = true, spice = true }

K.DISHES = {
    -- soups (vanilla Soup: a cooking pot with water, 6 ingredients)
    { id = "VegSoup",      family = "soup", level = 0, procs = { "wash", "peel", "chop", "season", "stir" },
      slots = { s(G.root, 2), s(G.leafy, 1), s(G.onion, 1), s(G.greens, 1, OPT), s(G.herb, 1, SPICE), s(G.salt, 1, SPICE) } },
    { id = "ChickenSoup",  family = "soup", level = 1, procs = { "wash", "trim", "chop", "season", "stir" },
      slots = { s(G.chicken, 2), s(G.carrot, 1), s(G.onion, 1), s(G.leafy, 1, OPT), s(G.herb, 1, SPICE), s(G.salt, 1, SPICE) } },
    { id = "PumpkinSoup",  family = "soup", level = 2, procs = { "wash", "peel", "chop", "season", "whisk" },
      slots = { s({ "Base.Pumpkin", "Base.SweetPotato" }, 3), s(G.onion, 1), s(G.garlic, 1, OPT), s(G.salt, 1, SPICE) } },
    { id = "MushroomSoup", family = "soup", level = 2, procs = { "wash", "chop", "season", "stir" },
      slots = { s(G.mushroom, 3), s(G.onion, 1), s(G.potato, 1, OPT), s(G.herb, 1, SPICE) } },
    { id = "FishSoup",     family = "soup", level = 3, procs = { "wash", "trim", "peel", "chop", "season", "stir" },
      slots = { s(G.fish, 2), s(G.potato, 1), s({ "Base.Leek", "Base.Onion" }, 1), s(G.tomato, 1, OPT), s(G.herb, 1, SPICE) } },
    -- stews (vanilla Stew: a cooking pot with water, 6 ingredients)
    { id = "BeefStew",     family = "stew", level = 1, procs = { "wash", "peel", "trim", "chop", "season", "stir" },
      slots = { s(G.beef, 2), s(G.potato, 2), s(G.carrot, 1), s(G.onion, 1), s(G.salt, 1, SPICE), s(G.herb, 1, SPICE) } },
    { id = "GameStew",     family = "stew", level = 2, procs = { "wash", "trim", "peel", "chop", "season", "stir" },
      slots = { s(G.game, 2), s(G.root, 2), s(G.mushroom, 1, OPT), s(G.onion, 1), s({ "Base.Thyme", "Base.Rosemary", "Base.Seasoning_Thyme", "Base.Seasoning_Rosemary" }, 1, SPICE) } },
    { id = "Chili",        family = "stew", level = 3, procs = { "wash", "mince", "chop", "season", "stir" },
      slots = { s(G.mince, 2), s({ "Base.OpenBeans", "Base.Blackbeans", "Base.Soybeans", "Base.Tofu" }, 2), s(G.tomato, 1), s(G.pepper, 1, OPT),
                s({ "Base.PepperJalapeno", "Base.PepperJalapenoDried", "Base.Pepper", "Base.Garlic" }, 1, SPICE) } },
    { id = "PorkStew",     family = "stew", level = 2, procs = { "wash", "peel", "trim", "chop", "season", "stir" },
      slots = { s({ "Base.Pork", "Base.PorkChop", "Base.Bacon", "Base.Sausage" }, 2), s(G.potato, 1), s({ "Base.Cabbage", "Base.Kale", "Base.Spinach" }, 1), s(G.onion, 1), s(G.salt, 1, SPICE) } },
    -- pan dishes (vanilla Stir fry: a frying pan, 4 ingredients; Roasted
    -- Vegetables: a roasting pan, 6 -- both take the Stir fry ingredients)
    { id = "VegStirFry",   family = "stirfry", level = 0, procs = { "wash", "chop", "season", "stir" },
      slots = { s(G.greens, 2), s({ "Base.Cabbage", "Base.Kale" }, 1), s(G.onion, 1), s(G.asian, 1, SPICE) } },
    { id = "ChickenStirFry", family = "stirfry", level = 2, procs = { "wash", "trim", "chop", "season", "stir" },
      slots = { s(G.chicken, 2), s(G.pepper, 1), s(G.onion, 1), s(G.asian, 1, SPICE) } },
    { id = "ShrimpStirFry", family = "stirfry", level = 3, procs = { "wash", "trim", "chop", "season", "stir" },
      slots = { s(G.shrimp, 2), s({ "Base.Broccoli", "Base.Greenpeas", "Base.BellPepper" }, 1), s(G.garlic, 1), s(G.asian, 1, SPICE) } },
    { id = "RoastVeg",     family = "roast", level = 1, procs = { "wash", "peel", "chop", "season" },
      slots = { s(G.root, 3), s(G.onion, 1), s({ "Base.OilOlive", "Base.OilVegetable" }, 1, SPICE), s({ "Base.Rosemary", "Base.Thyme", "Base.Seasoning_Rosemary", "Base.Seasoning_Thyme" }, 1, SPICE) } },
    -- vanilla Omelette: the base is an omelette already started in a pan
    -- (vanilla "Prepare Omelette" uses the eggs); up to 3 fillings
    { id = "Omelette",     family = "omelette", level = 1, procs = { "wash", "chop", "grate", "season" },
      slots = { s({ "Base.Onion", "Base.Leek" }, 1), s({ "Base.BellPepper", "Base.Tomato", "Base.Zucchini", "Base.Broccoli", "Base.Kale" }, 1),
                s({ "Base.Cheese", "Base.HamSlice", "Base.MushroomGeneric1", "Base.MushroomsButton" }, 1, OPT),
                s({ "Base.Chives", "Base.Parsley", "Base.Basil", "Base.Garlic" }, 1, SPICE) } },
    -- cold dishes (vanilla Salad / Fruit Salad: a bowl, 6 ingredients)
    { id = "GardenSalad",  family = "salad", level = 0, procs = { "wash", "chop", "season" },
      slots = { s(G.lettuce, 2), s(G.salad, 2), s({ "Base.OilOlive", "Base.OilVegetable", "Base.BalsamicVinegar" }, 1, SPICE) } },
    { id = "ChefSalad",    family = "salad", level = 2, procs = { "wash", "chop", "grate", "season" },
      slots = { s(G.lettuce, 1), s({ "Base.EggBoiled" }, 1), s({ "Base.HamSlice", "Base.Chicken" }, 1), s({ "Base.Cheese" }, 1), s(G.tomato, 1, OPT) } },
    { id = "FruitSalad",   family = "fruitsalad", level = 0, procs = { "wash", "peel", "chop" },
      slots = { s(G.fruit, 3), s(G.berry, 1, OPT), s({ "Base.Honey", "Base.Lemon", "Base.Lime" }, 1, SPICE) } },
    -- breads (vanilla Sandwich: bread slices or a baguette, 4; Burger: a
    -- bun, 4; Hotdog: a hot dog to top, 2; Burrito: a tortilla, 5; Taco: a
    -- taco shell, 5)
    { id = "BLT",          family = "sandwich", level = 0, procs = { "wash", "chop" },
      slots = { s({ "Base.Bacon", "Base.BaconRashers" }, 1), s({ "Base.Lettuce", "Base.Kale", "Base.Cabbage" }, 1), s(G.tomato, 1), s({ "Base.MayonnaiseFull", "Base.Mustard" }, 1, SPICE) } },
    { id = "HamCheese",    family = "sandwich", level = 0, procs = { "chop", "grate" },
      slots = { s({ "Base.HamSlice", "Base.SalamiSlice", "Base.BaloneySlice" }, 1), s({ "Base.Cheese" }, 1), s({ "Base.Lettuce", "Base.Tomato" }, 1, OPT), s({ "Base.Mustard", "Base.MayonnaiseFull" }, 1, SPICE) } },
    { id = "Burger",       family = "burger", level = 1, procs = { "mince", "chop", "season" },
      slots = { s({ "Base.MeatPatty", "Base.MincedMeat" }, 1), s({ "Base.Cheese" }, 1, OPT), s({ "Base.Lettuce", "Base.Onion" }, 1, OPT), s(G.tomato, 1, OPT), s(G.sauce, 1, SPICE) } },
    { id = "HotDog",       family = "hotdog", level = 0, procs = { "chop" },
      slots = { s({ "Base.Onion", "Base.Tomato", "Base.Lettuce" }, 1), s({ "Base.Cheese", "Base.MincedMeat" }, 1, OPT), s({ "Base.Mustard", "Base.Ketchup" }, 1, SPICE) } },
    { id = "BeanBurrito",  family = "burrito", level = 2, procs = { "wash", "chop", "grate", "season" },
      slots = { s({ "Base.Blackbeans", "Base.RefriedBeans" }, 1), s({ "Base.Cheese" }, 1), s({ "Base.Onion", "Base.Lettuce" }, 1, OPT), s({ "Base.Tomato" }, 1, OPT), s({ "Base.Hotsauce", "Base.PepperJalapeno" }, 1, SPICE) } },
    { id = "BeefTaco",     family = "taco", level = 2, procs = { "mince", "wash", "chop", "grate", "season" },
      slots = { s({ "Base.MincedMeat", "Base.MeatPatty", "Base.Beef", "Base.Steak" }, 1), s({ "Base.Lettuce", "Base.Cabbage" }, 1), s({ "Base.Tomato" }, 1, OPT), s({ "Base.Cheese" }, 1, OPT), s({ "Base.Hotsauce", "Base.PepperJalapeno" }, 1, SPICE) } },
    -- baking (vanilla Pie / Sweet Pie / Cake: the "preparation" in its
    -- baking pan, 4; Muffin: the muffin tray, 1)
    { id = "MeatPie",      family = "pie", level = 3, procs = { "wash", "peel", "mince", "chop", "season", "knead" },
      slots = { s({ "Base.MincedMeat", "Base.Pork", "Base.Rabbitmeat", "Base.Chicken" }, 2), s(G.potato, 1), s({ "Base.Onion", "Base.Leek", "Base.Carrots" }, 1),
                s({ "Base.Salt", "Base.Pepper", "Base.Garlic" }, 1, SPICE) } },
    { id = "ApplePie",     family = "sweetpie", level = 3, procs = { "wash", "peel", "chop", "measure", "knead" },
      slots = { s({ "Base.Apple", "Base.Pear", "Base.Peach" }, 3), s({ "Base.Cinnamon" }, 1, SPICE), s({ "Base.Honey", "Base.Lemon" }, 1, SPICE) } },
    { id = "BerryPie",     family = "sweetpie", level = 4, procs = { "wash", "chop", "measure", "knead" },
      slots = { s({ "Base.Strewberrie", "Base.Cherry", "Base.BerryBlue", "Base.BerryBlack", "Base.Peach" }, 3), s({ "Base.Honey", "Base.Lemon" }, 1, SPICE) } },
    { id = "BananaCake",   family = "cake", level = 4, procs = { "wash", "peel", "chop", "measure", "whisk" },
      slots = { s({ "Base.Banana", "Base.Apple" }, 2), s({ "Base.Strewberrie", "Base.Orange", "Base.Peach" }, 1, OPT), s({ "Base.Cinnamon", "Base.Honey", "Base.Lemon" }, 1, SPICE) } },
    { id = "FruitMuffins", family = "muffin", level = 3, procs = { "wash", "chop", "measure", "whisk" },
      slots = { s({ "Base.BerryBlue", "Base.BerryBlack", "Base.Banana", "Base.Apple", "Base.Cherry", "Base.Peach" }, 1), s({ "Base.Cinnamon", "Base.Lemon" }, 1, SPICE) } },
    -- vanilla Pizza: a pizza already prepared on its tray, 6
    { id = "Margherita",   family = "pizza", level = 3, procs = { "knead", "wash", "chop", "grate", "season" },
      slots = { s(G.tomato, 2), s({ "Base.Cheese" }, 2), s(G.italian, 1, SPICE) } },
    { id = "SalamiPizza",  family = "pizza", level = 4, procs = { "knead", "wash", "chop", "grate", "season" },
      slots = { s({ "Base.Pepperoni", "Base.SalamiSlice", "Base.HamSlice", "Base.Sausage", "Base.Bacon" }, 2), s({ "Base.Cheese" }, 1), s(G.tomato, 1), s(G.pepper, 1, OPT), s(G.italian, 1, SPICE) } },
    -- pots of grains (vanilla Pasta / Rice: pasta or rice in a pot of
    -- water, 5 -- in a saucepan, 4)
    { id = "TomatoPasta",  family = "pasta", level = 1, procs = { "wash", "chop", "grate", "season", "stir" },
      slots = { s(G.tomato, 2), s({ "Base.Cheese" }, 1, OPT), s(G.italian, 1, SPICE) } },
    { id = "CarbonaraPasta", family = "pasta", level = 3, procs = { "chop", "crack", "whisk", "grate", "stir" },
      slots = { s({ "Base.Bacon", "Base.HamSlice" }, 1), s({ "Base.Egg" }, 1), s({ "Base.Cheese" }, 1), s({ "Base.Pepper" }, 1, SPICE) } },
    { id = "FriedRice",    family = "rice", level = 2, procs = { "wash", "chop", "crack", "season", "stir" },
      slots = { s({ "Base.Egg" }, 1), s({ "Base.Greenpeas", "Base.Carrots", "Base.Corn" }, 2), s({ "Base.Onion", "Base.Leek" }, 1), s({ "Base.Soysauce", "Base.RiceVinegar", "Base.Garlic" }, 1, SPICE) } },
    -- vanilla Oatmeal / Pancakes: the bowl of oatmeal / the pancakes, 3
    { id = "FruitOatmeal", family = "oatmeal", level = 0, procs = { "chop", "stir" },
      slots = { s({ "Base.Banana", "Base.Apple", "Base.Strewberrie", "Base.Peach" }, 2), s({ "Base.Honey", "Base.Sugar", "Base.Cinnamon" }, 1, SPICE) } },
    { id = "FruitPancakes", family = "pancakes", level = 1, procs = { "chop", "measure" },
      slots = { s({ "Base.Strewberrie", "Base.Cherry", "Base.BerryBlue", "Base.Banana" }, 1), s({ "Base.Banana", "Base.Peach", "Base.Orange" }, 1, OPT), s({ "Base.Honey", "Base.Cinnamon" }, 1, SPICE) } },
}

-- quick lookups
K.DISH_BY_ID = {}
for _, d in ipairs(K.DISHES) do K.DISH_BY_ID[d.id] = d end

-- quality words from the minigames (the same words The Way To Attack uses)
K.WORD_SCORE = { Excellent = 1.0, Good = 0.66, Bad = 0.33 }

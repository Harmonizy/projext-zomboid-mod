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
-- One vanilla evolved recipe each. names / results are what the recipe is
-- recognised by at run time (its name, or the dish item it makes); base
-- says, for the guide, what vanilla wants as the starting item.
K.FAMILIES = {
    soup     = { names = { "Soup" }, results = { "PotOfSoupRecipe", "PotForgedSoupRecipe", "PotOfSoup" }, base = "Pot", icon = "Base.PotOfSoup" },
    stew     = { names = { "Stew" }, results = { "PotOfStew", "PotForgedStew" }, base = "Pot", icon = "Base.PotOfStew" },
    stirfry  = { names = { "Stir fry", "Stirfry", "Stir-fry", "Stir fry Griddle Pan" }, results = { "PanFriedVegetables", "PanFriedVegetablesForged", "GriddlePanFriedVegetables" }, base = "Pan", icon = "Base.PanFriedVegetables" },
    roast    = { names = { "Roast", "Roasted Vegetables", "Roasting Pan" }, results = { "PanFriedVegetables2" }, base = "RoastingPan", icon = "Base.PanFriedVegetables2" },
    salad    = { names = { "Salad" }, results = { "Salad", "SaladClay" }, base = "Bowl", icon = "Base.Salad" },
    fruitsalad = { names = { "Fruit Salad", "FruitSalad" }, results = { "FruitSalad" }, base = "Bowl", icon = "Base.FruitSalad" },
    sandwich = { names = { "Sandwich", "Sandwich Baguette" }, results = { "Sandwich", "BaguetteSandwich" }, base = "Bread", icon = "Base.Sandwich" },
    burger   = { names = { "Burger" }, results = { "BurgerRecipe" }, base = "Bun", icon = "Base.Burger" },
    hotdog   = { names = { "Hotdog", "Hot Dog" }, results = { "Hotdog" }, base = "HotdogBun", icon = "Base.Hotdog" },
    pie      = { names = { "Pie", "Savory Pie" }, results = { "PiePrep", "PieWholeRaw" }, base = "PieDough", icon = "Base.PieWholeRaw" },
    sweetpie = { names = { "Pie Sweet", "PieSweet", "Sweet Pie" }, results = { "PieWholeRawSweet" }, base = "PieDough", icon = "Base.PieApple" },
    cake     = { names = { "Cake" }, results = { "CakePrep", "CakeRaw" }, base = "CakeBatter", icon = "Base.CakeRaw" },
    muffin   = { names = { "Muffin", "Muffins" }, results = { "BakingTray_Muffin_Recipe" }, base = "MuffinTray", icon = "Base.MuffinFruit" },
    pasta    = { names = { "Pasta" }, results = { "PastaPot", "PastaPan", "PastaPotForged", "PastaPanCopper" }, base = "PastaPot", icon = "Base.PastaPot" },
    rice     = { names = { "Rice" }, results = { "RicePot", "RicePan", "RicePotForged", "RicePanCopper" }, base = "RicePot", icon = "Base.RicePot" },
    oatmeal  = { names = { "Oatmeal" }, results = { "Oatmeal" }, base = "OatBowl", icon = "Base.Oatmeal" },
    omelette = { names = { "Omelette" }, results = { "OmeletteRecipe", "OmeletteRecipeForged" }, base = "EggPan", icon = "Base.EggOmelette" },
    pizza    = { names = { "Pizza" }, results = { "PizzaRecipe" }, base = "Dough", icon = "Base.PizzaWhole" },
    burrito  = { names = { "Burrito" }, results = { "BurritoRecipe" }, base = "Tortilla", icon = "Base.Burrito" },
    taco     = { names = { "Taco" }, results = { "TacoRecipe" }, base = "TacoShell", icon = "Base.Taco" },
    pancakes = { names = { "Pancakes" }, results = { "PancakesRecipe" }, base = "Batter", icon = "Base.Pancakes" },
}

-- -------------------------------------------------------------- groups
-- Ingredient lists used by several dishes (best first).
local G = {}
G.root    = { "Base.Potato", "Base.SweetPotato", "Base.Carrots", "Base.Turnip", "Base.RedRadish" }
G.potato  = { "Base.Potato", "Base.SweetPotato" }
G.carrot  = { "Base.Carrots" }
G.onion   = { "Base.Onion", "Base.Leek", "Base.Garlic", "Base.Chives" }
G.garlic  = { "Base.Garlic", "Base.Onion", "Base.Chives" }
G.leafy   = { "Base.Cabbage", "Base.Kale", "Base.Spinach", "Base.Lettuce" }
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
    "Base.Cherry", "Base.Pineapple", "Base.Mango", "Base.Watermelon" }
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
    -- soups
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
    -- stews
    { id = "BeefStew",     family = "stew", level = 1, procs = { "wash", "peel", "trim", "chop", "season", "stir" },
      slots = { s(G.beef, 2), s(G.potato, 2), s(G.carrot, 1), s(G.onion, 1), s(G.salt, 1, SPICE), s(G.herb, 1, SPICE) } },
    { id = "GameStew",     family = "stew", level = 2, procs = { "wash", "trim", "peel", "chop", "season", "stir" },
      slots = { s(G.game, 2), s(G.root, 2), s(G.mushroom, 1, OPT), s(G.onion, 1), s({ "Base.Thyme", "Base.Rosemary", "Base.Seasoning_Thyme", "Base.Seasoning_Rosemary" }, 1, SPICE) } },
    { id = "Chili",        family = "stew", level = 3, procs = { "wash", "mince", "chop", "season", "stir" },
      slots = { s(G.mince, 2), s(G.beans, 2), s(G.tomato, 1), s(G.pepper, 1, OPT), s(G.hot, 1, SPICE) } },
    { id = "PorkStew",     family = "stew", level = 2, procs = { "wash", "peel", "trim", "chop", "season", "stir" },
      slots = { s(G.pork, 2), s(G.potato, 1), s(G.leafy, 1), s(G.onion, 1), s(G.salt, 1, SPICE) } },
    -- pan dishes
    { id = "VegStirFry",   family = "stirfry", level = 0, procs = { "wash", "chop", "season", "stir" },
      slots = { s(G.greens, 2), s(G.leafy, 1), s(G.onion, 1), s(G.asian, 1, SPICE) } },
    { id = "ChickenStirFry", family = "stirfry", level = 2, procs = { "wash", "trim", "chop", "season", "stir" },
      slots = { s(G.chicken, 2), s(G.pepper, 1), s(G.onion, 1), s(G.greens, 1, OPT), s(G.asian, 1, SPICE) } },
    { id = "ShrimpStirFry", family = "stirfry", level = 3, procs = { "wash", "trim", "chop", "season", "stir" },
      slots = { s(G.shrimp, 2), s({ "Base.Broccoli", "Base.Greenpeas", "Base.BellPepper" }, 1), s(G.garlic, 1), s(G.asian, 1, SPICE) } },
    { id = "RoastVeg",     family = "roast", level = 1, procs = { "wash", "peel", "chop", "season" },
      slots = { s(G.root, 3), s(G.onion, 1), s(G.oil, 1, OPT), s({ "Base.Rosemary", "Base.Thyme", "Base.Seasoning_Rosemary", "Base.Seasoning_Thyme" }, 1, SPICE) } },
    { id = "Omelette",     family = "omelette", level = 1, procs = { "crack", "whisk", "chop", "season" },
      slots = { s(G.egg, 1), s(G.onion, 1, OPT), s(G.pepper, 1, OPT), s(G.cheese, 1, OPT), s(G.salt, 1, SPICE) } },
    -- cold dishes
    { id = "GardenSalad",  family = "salad", level = 0, procs = { "wash", "chop", "season" },
      slots = { s(G.lettuce, 2), s(G.salad, 2), s(G.oil, 1, OPT) } },
    { id = "ChefSalad",    family = "salad", level = 2, procs = { "wash", "chop", "grate", "season" },
      slots = { s(G.lettuce, 1), s({ "Base.EggBoiled" }, 1), s(G.cured, 1), s(G.cheese, 1), s(G.tomato, 1, OPT) } },
    { id = "FruitSalad",   family = "fruitsalad", level = 0, procs = { "wash", "peel", "chop" },
      slots = { s(G.fruit, 3), s(G.berry, 1, OPT), s({ "Base.Honey", "Base.Sugar" }, 1, SPICE) } },
    -- breads
    { id = "BLT",          family = "sandwich", level = 0, procs = { "wash", "chop" },
      slots = { s({ "Base.Bacon" }, 1), s(G.lettuce, 1), s(G.tomato, 1), s({ "Base.MayonnaiseFull", "Base.Mustard" }, 1, SPICE) } },
    { id = "HamCheese",    family = "sandwich", level = 0, procs = { "chop", "grate" },
      slots = { s({ "Base.Ham", "Base.Salami" }, 1), s(G.cheese, 1), s(G.lettuce, 1, OPT), s({ "Base.Mustard", "Base.MayonnaiseFull" }, 1, SPICE) } },
    { id = "Burger",       family = "burger", level = 1, procs = { "mince", "chop", "season" },
      slots = { s(G.mince, 1), s(G.cheese, 1, OPT), s(G.lettuce, 1, OPT), s(G.tomato, 1, OPT), s(G.sauce, 1, SPICE) } },
    { id = "HotDog",       family = "hotdog", level = 0, procs = { "chop" },
      slots = { s({ "Base.Sausage" }, 1), s(G.onion, 1, OPT), s({ "Base.Mustard", "Base.Ketchup" }, 1, SPICE) } },
    { id = "BeanBurrito",  family = "burrito", level = 2, procs = { "wash", "chop", "grate", "season" },
      slots = { s(G.beans, 1), s(G.cheese, 1), s(G.onion, 1, OPT), s(G.tomato, 1, OPT), s(G.hot, 1, SPICE) } },
    { id = "BeefTaco",     family = "taco", level = 2, procs = { "mince", "wash", "chop", "grate", "season" },
      slots = { s(G.mince, 1), s(G.lettuce, 1), s(G.tomato, 1, OPT), s(G.cheese, 1, OPT), s(G.hot, 1, SPICE) } },
    -- baking
    { id = "MeatPie",      family = "pie", level = 3, procs = { "wash", "peel", "mince", "chop", "season", "knead" },
      slots = { s(G.mince, 2), s(G.potato, 1), s(G.onion, 1), s(G.carrot, 1, OPT), s(G.herb, 1, SPICE) } },
    { id = "ApplePie",     family = "sweetpie", level = 3, procs = { "wash", "peel", "chop", "measure", "knead" },
      slots = { s(G.apple, 3), s(G.sweet, 1, SPICE), s({ "Base.Cinnamon" }, 1, SPICE) } },
    { id = "BerryPie",     family = "sweetpie", level = 4, procs = { "wash", "chop", "measure", "knead" },
      slots = { s(G.berry, 3), s(G.sweet, 1, SPICE) } },
    { id = "CarrotCake",   family = "cake", level = 4, procs = { "wash", "peel", "grate", "measure", "whisk" },
      slots = { s(G.carrot, 2), s({ "Base.Peanuts", "Base.Banana" }, 1, OPT), s(G.spice_sweet, 1, SPICE) } },
    { id = "FruitMuffins", family = "muffin", level = 3, procs = { "wash", "chop", "measure", "whisk" },
      slots = { s(G.berry, 2), s({ "Base.Banana", "Base.Apple" }, 1, OPT), s(G.spice_sweet, 1, SPICE) } },
    { id = "Margherita",   family = "pizza", level = 3, procs = { "knead", "wash", "chop", "grate", "season" },
      slots = { s(G.tomato, 2), s({ "Base.Cheese" }, 2), s(G.italian, 1, SPICE) } },
    { id = "SalamiPizza",  family = "pizza", level = 4, procs = { "knead", "wash", "chop", "grate", "season" },
      slots = { s({ "Base.Salami", "Base.Ham", "Base.Sausage", "Base.Bacon" }, 2), s({ "Base.Cheese" }, 1), s(G.tomato, 1), s(G.pepper, 1, OPT), s(G.italian, 1, SPICE) } },
    -- pots of grains
    { id = "TomatoPasta",  family = "pasta", level = 1, procs = { "wash", "chop", "grate", "season", "stir" },
      slots = { s(G.tomato, 2), s(G.garlic, 1), s(G.cheese, 1, OPT), s(G.italian, 1, SPICE) } },
    { id = "CarbonaraPasta", family = "pasta", level = 3, procs = { "chop", "crack", "whisk", "grate", "stir" },
      slots = { s({ "Base.Bacon", "Base.Ham" }, 1), s(G.egg, 1), s({ "Base.Cheese" }, 1), s({ "Base.Pepper" }, 1, SPICE) } },
    { id = "FriedRice",    family = "rice", level = 2, procs = { "wash", "chop", "crack", "season", "stir" },
      slots = { s(G.egg, 1), s({ "Base.Greenpeas", "Base.Carrots", "Base.Corn" }, 2), s(G.onion, 1), s(G.asian, 1, SPICE) } },
    { id = "FruitOatmeal", family = "oatmeal", level = 0, procs = { "chop", "stir" },
      slots = { s({ "Base.Banana", "Base.Apple", "Base.Strewberrie", "Base.Peach" }, 2), s({ "Base.Honey", "Base.Sugar", "Base.Cinnamon" }, 1, SPICE) } },
    { id = "FruitPancakes", family = "pancakes", level = 1, procs = { "crack", "whisk", "chop" },
      slots = { s(G.berry, 1), s({ "Base.Banana" }, 1, OPT), s({ "Base.Honey", "Base.Sugar" }, 1, SPICE) } },
}

-- quick lookups
K.DISH_BY_ID = {}
for _, d in ipairs(K.DISHES) do K.DISH_BY_ID[d.id] = d end

-- quality words from the minigames (the same words The Way To Attack uses)
K.WORD_SCORE = { Excellent = 1.0, Good = 0.66, Bad = 0.33 }

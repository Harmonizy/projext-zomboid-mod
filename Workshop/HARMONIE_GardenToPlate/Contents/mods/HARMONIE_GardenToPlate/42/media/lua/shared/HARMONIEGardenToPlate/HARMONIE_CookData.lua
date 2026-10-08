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

    0.13.0 (owner: "อุปกรณ์ ... ยืดหยุ่น ใช้ได้มากกว่า 1 แต่อันไหนไม่ได้ไม่เป็นไร",
    "วัตถุดิบที่ใส่ต้องยืดหยุ่นได้", "เพิ่มสูตรอาหาร ... กรรมวิธีมากกว่านี้",
    "ปลดล็อคสูตรตามเลเวลสกิล"):
      - a tool group takes many items, graded: best / ok / makeshift
        (harder), from vanilla's own item tags (base:sharpknife,
        base:spoon, base:fork, base:mortarpestle ...) plus named items.
        Where hands are a real option (kneading, mashing, rolling by
        hand) a missing tool never blocks the step -- it is just harder;
      - an ingredient slot lists the foods it prefers, then takes ANY food
        of its kinds (vanilla FoodType: Vegetables, Fruits, Berry, Beef,
        Poultry, Fish, Seafood, Bean, Herb ... -- so modded foods count
        too) that vanilla's own recipe accepts; poisonous food never;
      - 25 preparation steps, 99 dishes, hot drinks included. 0.13.2:
        every dish can be made at any Cooking level -- its `level` is the
        suggested one (shown in the tab; the steps are harder below it).
        Tossing, flipping and steeping need a stove, fire or grill within
        two tiles (K.findHeat).

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
-- best / ok / makeshift: { types = {...}, tags = {...} } (tags are vanilla
-- B42 item tags, checked with pcall). A makeshift tool works but makes the
-- minigame harder; ok a little. bare = true: the step can be done by hand
-- when nothing at all is there (harder still). optional = only helps.
K.TOOLS = {
    blade = {
        best = { types = { "Base.KitchenKnife", "Base.KitchenKnifeForged", "Base.KnifeParing", "Base.KnifeSushi", "Base.KnifeFillet",
            "Base.SteakKnife", "Base.SmallKnife", "Base.LargeKnife", "Base.HuntingKnife", "Base.HuntingKnifeForged" } },
        ok = { tags = { "base:sharpknife", "base:meatcleaver" } },
        makeshift = { tags = { "base:dullknife", "base:scissors" } },
    },
    cleaver = {
        best = { tags = { "base:meatcleaver" } },
        ok = { types = { "Base.KitchenKnife", "Base.KitchenKnifeForged", "Base.LargeKnife", "Base.HuntingKnife", "Base.HuntingKnifeForged",
            "Base.Machete", "Base.MacheteForged" } },
        makeshift = { tags = { "base:sharpknife" } },
    },
    peeler = {
        best = { types = { "Base.KnifeParing", "Base.KitchenKnife", "Base.KitchenKnifeForged", "Base.SmallKnife", "Base.KnifePocket", "Base.SteakKnife" } },
        ok = { tags = { "base:sharpknife" } },
        makeshift = { tags = { "base:dullknife" } },
    },
    scaler = {
        best = { types = { "Base.KnifeFillet", "Base.KitchenKnife", "Base.KitchenKnifeForged" } },
        ok = { tags = { "base:sharpknife", "base:dullknife" } },
        makeshift = { tags = { "base:spoon" } },
    },
    spreader = {
        best = { tags = { "base:dullknife" } },
        ok = { types = { "Base.Spatula" }, tags = { "base:spoon" } },
        makeshift = { tags = { "base:sharpknife" } },
    },
    spoon = {
        best = { types = { "Base.WoodenSpoon", "Base.Ladle", "Base.Spatula" } },
        ok = { types = { "Base.KitchenTongs", "Base.Chopsticks" }, tags = { "base:spoon" } },
        makeshift = { tags = { "base:fork" } },
    },
    whisk = {
        best = { types = { "Base.Whisk" } },
        ok = { types = { "Base.Chopsticks" }, tags = { "base:fork" } },
        makeshift = { tags = { "base:spoon" } },
    },
    spatula = {
        best = { types = { "Base.Spatula", "Base.KitchenTongs" } },
        ok = { types = { "Base.WoodenSpoon", "Base.Ladle" }, tags = { "base:fork" } },
        makeshift = { types = { "Base.Chopsticks" }, tags = { "base:spoon", "base:dullknife" } },
    },
    grater = {
        best = { tags = { "base:grater" } },
        makeshift = { tags = { "base:sharpknife" } },
    },
    masher = {
        best = { tags = { "base:fork", "base:mortarpestle" } },
        ok = { types = { "Base.RollingPin" }, tags = { "base:spoon" } },
        bare = true,
    },
    grinder = {
        best = { tags = { "base:mortarpestle" } },
        ok = { types = { "Base.RollingPin" } },
        makeshift = { tags = { "base:sharpknife", "base:meatcleaver" } },
    },
    pounder = {
        best = { types = { "Base.RollingPin" } },
        ok = { types = { "Base.Pan", "Base.PanForged", "Base.GridlePan" }, tags = { "base:meatcleaver" } },
        makeshift = { tags = { "base:hammer", "base:clubhammer", "base:ballpeenhammer" } },
    },
    roller = {
        best = { types = { "Base.RollingPin" } },
        ok = { tags = { "base:glassbottle" } },
        bare = true,
    },
    -- never required: they make a step easier when they are at hand
    board = { best = { types = { "Base.CuttingBoardWooden", "Base.CuttingBoardPlastic" } }, optional = true },
    rollingpin = { best = { types = { "Base.RollingPin" } }, optional = true },
    bowl = { best = { tags = { "base:bowl" } }, optional = true },
    mitt = { best = { types = { "Base.OvenMitt" } }, optional = true },
}
K.TOOL_GRADES = { "best", "ok", "makeshift" }

-- ------------------------------------------------------------- procedures
-- game / variant: the minigame (HARMONIE_CookGames.lua). tools: required
-- groups (a "bare" group never blocks); help: optional groups that make it
-- easier. cursor: what is drawn at the mouse -- "tool" (the real tool item),
-- "ingredient" (the food being worked), "spice" (the seasoning used),
-- "base" (the pan or pot), "hand". level: the suggested Cooking level
-- (0.13.2: never a lock -- below it the minigame is harder); time:
-- seconds of the timed action at level 0 (4 percent quicker per level);
-- xp: vanilla Cooking XP when done.
-- heat (0.13.2): the step needs a stove, fire or grill in reach (K.findHeat)
local function proc(game, variant, tools, help, level, time, xp, cursor, heat)
    return { game = game, variant = variant, tools = tools, help = help, level = level, time = time, xp = xp, icon = variant,
        cursor = cursor or (#tools > 0 and "tool" or "hand"), heat = heat == true }
end
K.PROCS = {
    wash    = proc("scrub",  "wash",    {},            {},           0, 3, 1, "hand"),
    scale   = proc("scrub",  "scale",   { "scaler" },  { "board" },  2, 4, 2),
    peel    = proc("scrub",  "peel",    { "peeler" },  { "board" },  1, 4, 2),
    spread  = proc("scrub",  "spread",  { "spreader" }, {},          0, 2, 1),
    chop    = proc("timing", "chop",    { "blade" },   { "board" },  0, 4, 2),
    slice   = proc("timing", "slice",   { "blade" },   { "board" },  1, 4, 2),
    mince   = proc("timing", "mince",   { "cleaver" }, { "board" },  3, 5, 3),
    trim    = proc("timing", "trim",    { "blade" },   { "board" },  2, 4, 3),
    core    = proc("timing", "core",    { "peeler" },  { "board" },  1, 3, 2),
    crack   = proc("ring",   "crack",   {},            { "bowl" },   0, 2, 1, "ingredient"),
    knead   = proc("ring",   "knead",   {},            { "rollingpin" }, 2, 6, 3, "hand"),
    pound   = proc("ring",   "pound",   { "pounder" }, { "board" },  2, 4, 2),
    toss    = proc("ring",   "toss",    {},            {},           1, 3, 2, "hand", true),
    flip    = proc("watch",  "flip",    { "spatula" }, {},           1, 3, 2, nil, true),
    steep   = proc("watch",  "steep",   {},            {},           0, 3, 1, "ingredient", true),
    roll    = proc("lane",   "roll",    { "roller" },  {},           2, 5, 3),
    grate   = proc("lane",   "grate",   { "grater" },  {},           1, 3, 2, "ingredient"),
    zest    = proc("lane",   "zest",    { "grater" },  {},           2, 3, 2, "ingredient"),
    whisk   = proc("circle", "whisk",   { "whisk" },   { "bowl" },   1, 4, 2),
    stir    = proc("circle", "stir",    { "spoon" },   {},           0, 4, 2),
    fold    = proc("circle", "fold",    { "spoon" },   { "bowl" },   3, 4, 3),
    grind   = proc("circle", "grind",   { "grinder" }, {},           2, 4, 2),
    mash    = proc("press",  "mash",    { "masher" },  { "bowl" },   1, 4, 2),
    season  = proc("fill",   "season",  {},            {},           0, 2, 1, "spice"),
    measure = proc("fill",   "measure", {},            { "bowl" },   1, 3, 2, "spice"),
}
K.PROC_ORDER = { "wash", "scale", "peel", "core", "trim", "chop", "slice", "mince", "pound", "crack", "grate", "zest", "grind", "mash",
    "knead", "roll", "measure", "whisk", "fold", "season", "spread", "stir", "toss", "flip", "steep" }

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
    -- 0.13.0
    toast    = { template = "Toast", names = { "Toast", "BagelPlain", "BagelPoppy", "BagelSesame", "Prepare Toast", "Prepare Bagel" }, results = { "Toast", "BagelPlain", "BagelPoppy", "BagelSesame" }, icon = "Base.Toast" },
    bread    = { template = "Bread", names = { "Bread", "Prepare Bread" }, results = { "BreadDough" }, icon = "Base.BreadDough" },
    icecream = { template = "ConeIcecream", names = { "ConeIcecream", "Prepare Ice Cream Cone" }, results = { "ConeIcecreamToppings" }, icon = "Base.ConeIcecream" },
    -- hot drinks: a mug / cup FULL of water (vanilla MinimumWater=1.0),
    -- heated afterwards like any other drink
    drink    = { template = "HotDrink", names = { "HotDrink", "HotDrinkClay", "HotDrinkTea", "HotDrinkTeaCeramic", "HotDrinkSpiffo", "HotDrinkWhite",
        "HotDrinkMetal", "HotDrinkGold", "HotDrinkCopper", "HotDrinkSilver", "HotDrinkTumbler", "Prepare Beverage" },
        results = { "HotDrink", "HotDrinkClay", "HotDrinkTea", "HotDrinkTeaCeramic", "HotDrinkSpiffo", "HotDrinkWhite", "HotDrinkMetal",
        "HotDrinkGold", "HotDrinkCopper", "HotDrinkSilver", "HotDrinkTumbler" }, icon = "Base.HotDrink" },
}

-- -------------------------------------------------------------- groups
-- Foods a slot prefers (best first). A slot also takes any food of its
-- kinds (K.CATS, vanilla FoodType) that the recipe accepts.
local G = {}
G.root    = { "Base.Potato", "Base.SweetPotato", "Base.Carrots", "Base.Turnip", "Base.RedRadish", "Base.Daikon" }
G.potato  = { "Base.Potato", "Base.SweetPotato" }
G.carrot  = { "Base.Carrots" }
G.onion   = { "Base.Onion", "Base.Leek", "Base.GreenOnions", "Base.Garlic", "Base.WildGarlic2", "Base.Chives" }
G.garlic  = { "Base.Garlic", "Base.WildGarlic2", "Base.Onion", "Base.Chives", "Base.PowderedGarlic" }
G.leafy   = { "Base.Cabbage", "Base.Kale", "Base.Spinach", "Base.Nettles", "Base.Dandelions" }
G.lettuce = { "Base.Lettuce", "Base.Kale", "Base.Spinach", "Base.Cabbage", "Base.Dandelions" }
G.greens  = { "Base.Broccoli", "Base.Cauliflower", "Base.Greenpeas", "Base.Zucchini", "Base.BellPepper", "Base.Corn", "Base.Eggplant",
    "Base.BrusselSprouts", "Base.Squash" }
G.pepper  = { "Base.BellPepper", "Base.PepperJalapeno", "Base.Zucchini" }
G.tomato  = { "Base.Tomato", "Base.CannedTomatoOpen", "Base.TomatoPaste" }
G.mushroom = { "Base.MushroomGeneric1", "Base.MushroomGeneric2", "Base.MushroomGeneric3", "Base.MushroomGeneric4",
    "Base.MushroomGeneric5", "Base.MushroomGeneric6", "Base.MushroomGeneric7", "Base.MushroomsButton" }
G.salad   = { "Base.Cucumber", "Base.Tomato", "Base.RedRadish", "Base.BellPepper", "Base.Carrots", "Base.Avocado", "Base.Olives" }
G.wild    = { "Base.Dandelions", "Base.Nettles", "Base.Violets", "Base.CommonMallow", "Base.Rosehips" }
G.beef    = { "Base.Beef", "Base.Steak", "Base.Venison", "Base.MincedMeat", "Base.MuttonChop" }
G.mince   = { "Base.MincedMeat", "Base.Beef", "Base.Steak", "Base.Venison", "Base.Pork" }
G.game    = { "Base.Rabbitmeat", "Base.Smallanimalmeat", "Base.Smallbirdmeat", "Base.Venison", "Base.FrogMeat" }
G.chicken = { "Base.Chicken", "Base.ChickenFillet", "Base.TurkeyFillet", "Base.Smallbirdmeat", "Base.Rabbitmeat" }
G.pork    = { "Base.Pork", "Base.PorkChop", "Base.Bacon", "Base.Ham", "Base.Sausage" }
G.cured   = { "Base.Bacon", "Base.BaconRashers", "Base.Ham", "Base.HamSlice", "Base.Salami", "Base.SalamiSlice", "Base.Sausage" }
G.fish    = { "Base.FishFillet", "Base.Salmon", "Base.Shrimp", "Base.Crayfish", "Base.Squid", "Base.Oysters", "Base.Lobster" }
G.shrimp  = { "Base.Shrimp", "Base.Crayfish", "Base.Squid", "Base.Lobster", "Base.FishFillet" }
G.beans   = { "Base.OpenBeans", "Base.Blackbeans", "Base.RefriedBeans", "Base.Soybeans", "Base.Tofu" }
G.drybeans = { "Base.DriedLentils", "Base.DriedSplitPeas", "Base.DriedChickpeas", "Base.DriedBlackBeans", "Base.DriedKidneyBeans", "Base.DriedWhiteBeans" }
G.cheese  = { "Base.Cheese", "Base.Processedcheese", "Base.SourCream" }
G.fruit   = { "Base.Apple", "Base.Banana", "Base.Orange", "Base.Peach", "Base.Pear", "Base.Grapes", "Base.Strewberrie",
    "Base.Cherry", "Base.Pineapple", "Base.Mango", "Base.WatermelonSliced", "Base.Grapefruit" }
G.berry   = { "Base.Strewberrie", "Base.BerryBlue", "Base.BerryBlack", "Base.Cherry", "Base.Grapes", "Base.WinterBerry" }
G.tropic  = { "Base.Pineapple", "Base.Mango", "Base.Banana", "Base.Orange", "Base.Grapefruit" }
G.apple   = { "Base.Apple", "Base.Pear", "Base.Peach" }
G.dried   = { "HARMONIEGardenToPlate.DriedApple", "HARMONIEGardenToPlate.DriedPear", "HARMONIEGardenToPlate.DriedPeach",
    "HARMONIEGardenToPlate.DriedMango", "HARMONIEGardenToPlate.DriedBanana", "HARMONIEGardenToPlate.DriedCherry",
    "HARMONIEGardenToPlate.DriedGrapes", "HARMONIEGardenToPlate.DriedPineapple", "Base.DriedApricots" }
G.sprouts = { "HARMONIEGardenToPlate.BeanSprouts", "HARMONIEGardenToPlate.BeanSproutsJar" }
G.sweet   = { "Base.Honey", "Base.Sugar", "Base.SugarBrown", "Base.MapleSyrup" }
G.herb    = { "Base.Thyme", "Base.Rosemary", "Base.Parsley", "Base.Basil", "Base.Oregano", "Base.Sage", "Base.Chives", "Base.Cilantro",
    "Base.ThymeDried", "Base.RosemaryDried", "Base.ParsleyDried", "Base.BasilDried", "Base.OreganoDried", "Base.SageDried",
    "Base.Seasoning_Thyme", "Base.Seasoning_Rosemary", "Base.Seasoning_Parsley", "Base.Seasoning_Basil",
    "Base.Seasoning_Oregano", "Base.Seasoning_Sage", "Base.Seasoning_Chives" }
G.roastherb = { "Base.Rosemary", "Base.Thyme", "Base.Sage", "Base.RosemaryDried", "Base.ThymeDried", "Base.Seasoning_Rosemary", "Base.Seasoning_Thyme" }
G.italian = { "Base.Basil", "Base.Oregano", "Base.BasilDried", "Base.OreganoDried", "Base.Seasoning_Basil", "Base.Seasoning_Oregano", "Base.Garlic" }
G.salt    = { "Base.Salt", "Base.SeasoningSalt", "Base.Pepper" }
G.hot     = { "Base.PepperJalapeno", "Base.PepperHabanero", "Base.PepperJalapenoDried", "Base.PepperHabaneroDried", "Base.Hotsauce", "Base.Pepper" }
G.asian   = { "Base.Soysauce", "Base.GingerRoot", "Base.RiceVinegar", "Base.SesameOil", "Base.Garlic" }
G.sauce   = { "Base.Ketchup", "Base.Mustard", "Base.MayonnaiseFull", "Base.BBQSauce", "Base.Pickles" }
G.oil     = { "Base.OilOlive", "Base.OilVegetable", "Base.Butter", "Base.Margarine", "Base.Lard" }
G.citrus  = { "Base.Lemon", "Base.Lime", "Base.Orange" }
G.choc    = { "Base.ChocolateChips", "Base.Chocolate", "Base.CocoaPowder" }
G.tea     = { "Base.Teabag2", "Base.MintHerb", "Base.MintHerbDried", "Base.Chamomile", "Base.ChamomileDried", "Base.LemonGrass",
    "Base.LavenderPetalsDried", "Base.CommonMallow", "Base.BlackSage" }
G.herbtea = { "Base.MintHerb", "Base.MintHerbDried", "Base.Chamomile", "Base.ChamomileDried", "Base.LemonGrass", "Base.LavenderPetalsDried",
    "Base.Lavender", "Base.MarigoldDried", "Base.BlackSage", "Base.CommonMallow" }
G.milk    = { "Base.CannedMilkOpen" }
G.seeds   = { "Base.SunflowerSeeds", "Base.PumpkinSeed", "Base.FlaxSeed", "Base.PoppySeed" }
K.GROUPS = G

-- food kinds (vanilla FoodType). A slot with cats = { "veg" } also takes
-- any vegetable the recipe accepts that is not in its list.
K.CATS = {
    veg = { "Vegetables", "Vegetable", "Greens" }, mushroom = { "Mushroom" }, fruit = { "Fruits", "Citrus" }, berry = { "Berry" },
    red = { "Beef", "Meat", "Venison", "Game" }, poultry = { "Poultry", "Game" }, fish = { "Fish", "Seafood" }, bean = { "Bean" },
    herb = { "Herb" }, hot = { "HotPepper" }, cheese = { "Cheese" }, cured = { "Sausage", "Bacon" },
}
-- never taken through a kind, even when vanilla would allow it
K.NEVER = { ["Base.BerryPoisonIvy"] = true, ["Base.HollyBerry"] = true }

-- ------------------------------------------------------------------ dishes
-- slots: { group = list, adds = vanilla additions, cats = kinds also
-- taken, optional, spice }. Each addition is one ISAddItemInRecipe, which
-- uses the item's own evolved-recipe portion (vanilla decides the amount).
-- The total stays at or under the recipe's own limit (getMaxItems; the
-- tab trims to it at run time and logs it). Checked against vanilla B42's
-- evolved-recipe tables (tools/ and the reference folder).
local function s(group, adds, extra)
    local t = { group = group, adds = adds or 1 }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
end
local function x(cats, opt, spice) return { cats = cats, optional = opt, spice = spice } end
local OPT = { optional = true }
local SPICE = { optional = true, spice = true }
local VEG, VEGO = x({ "veg" }), x({ "veg" }, true)
local FRUIT, BERRY = x({ "fruit", "berry" }), x({ "berry" })

-- 0.13.2: added one at a time -- a single 99-entry constructor broke the
-- game's Lua compiler (K.DISHES came out nil: "Expected a table" in the tab)
K.DISHES = {}
local function dish(t) K.DISHES[#K.DISHES + 1] = t end
do
    -- ===== soups (vanilla Soup: a cooking pot with water, 6)
    dish { id = "VegSoup",      family = "soup", level = 0, procs = { "wash", "peel", "chop", "season", "stir" },
      slots = { s(G.root, 2, VEG), s(G.leafy, 1, VEG), s(G.onion, 1), s(G.greens, 1, VEGO), s(G.herb, 1, SPICE), s(G.salt, 1, SPICE) } }
    dish { id = "NettleSoup",   family = "soup", level = 0, procs = { "wash", "chop", "season", "stir" },
      slots = { s({ "Base.Nettles", "Base.Dandelions", "Base.Spinach" }, 2), s(G.potato, 1), s(G.onion, 1), s(G.salt, 1, SPICE) } }
    dish { id = "TomatoSoup",   family = "soup", level = 1, procs = { "wash", "chop", "mash", "season", "stir" },
      slots = { s(G.tomato, 3), s(G.onion, 1), s(G.garlic, 1, OPT), s(G.italian, 1, SPICE) } }
    dish { id = "LentilSoup",   family = "soup", level = 1, procs = { "wash", "chop", "season", "stir" },
      slots = { s(G.drybeans, 2, x({ "bean" })), s(G.carrot, 1, VEG), s(G.onion, 1), s(G.garlic, 1, OPT), s(G.herb, 1, SPICE) } }
    dish { id = "ChickenSoup",  family = "soup", level = 1, procs = { "wash", "trim", "chop", "season", "stir" },
      slots = { s(G.chicken, 2, x({ "poultry" })), s(G.carrot, 1, VEG), s(G.onion, 1), s(G.leafy, 1, VEGO), s(G.herb, 1, SPICE), s(G.salt, 1, SPICE) } }
    dish { id = "PumpkinSoup",  family = "soup", level = 2, procs = { "wash", "peel", "chop", "mash", "season" },
      slots = { s({ "Base.Pumpkin", "Base.PumpkinSliced", "Base.PumpkinSmashed", "Base.Squash", "Base.SweetPotato" }, 3), s(G.onion, 1), s(G.garlic, 1, OPT), s(G.salt, 1, SPICE) } }
    dish { id = "MushroomSoup", family = "soup", level = 2, procs = { "wash", "slice", "season", "stir" },
      slots = { s(G.mushroom, 3, x({ "mushroom" })), s(G.onion, 1), s(G.potato, 1, OPT), s(G.herb, 1, SPICE) } }
    dish { id = "CornSoup",     family = "soup", level = 3, procs = { "wash", "peel", "slice", "chop", "stir" },
      slots = { s({ "Base.Corn", "Base.CannedCornOpen" }, 2), s(G.potato, 1), s(G.onion, 1), s({ "Base.Leek", "Base.GreenOnions" }, 1, OPT), s(G.salt, 1, SPICE) } }
    dish { id = "FishSoup",     family = "soup", level = 3, procs = { "scale", "trim", "peel", "chop", "season", "stir" },
      slots = { s(G.fish, 2, x({ "fish" })), s(G.potato, 1), s({ "Base.Leek", "Base.Onion" }, 1), s(G.tomato, 1, OPT), s(G.herb, 1, SPICE) } }
    dish { id = "GardenBroth",  family = "soup", level = 5, procs = { "wash", "peel", "chop", "grind", "season", "stir" },
      slots = { s(G.root, 2, VEG), s(G.greens, 2, VEG), s(G.leafy, 1, VEG), s(G.garlic, 1, SPICE), s(G.herb, 1, SPICE) } }
    -- ===== stews (vanilla Stew: a cooking pot with water, 6)
    dish { id = "BeanStew",     family = "stew", level = 1, procs = { "wash", "chop", "season", "stir" },
      slots = { s(G.beans, 2, x({ "bean" })), s(G.tomato, 1), s(G.onion, 1), s(G.pepper, 1, VEGO), s(G.herb, 1, SPICE) } }
    dish { id = "BeefStew",     family = "stew", level = 1, procs = { "wash", "peel", "trim", "chop", "season", "stir" },
      slots = { s(G.beef, 2, x({ "red" })), s(G.potato, 2), s(G.carrot, 1, VEG), s(G.onion, 1), s(G.salt, 1, SPICE), s(G.herb, 1, SPICE) } }
    dish { id = "ChickenStew",  family = "stew", level = 2, procs = { "wash", "trim", "peel", "chop", "season", "stir" },
      slots = { s(G.chicken, 2, x({ "poultry" })), s(G.potato, 1), s(G.carrot, 1, VEG), s(G.mushroom, 1, x({ "mushroom" }, true)), s(G.herb, 1, SPICE) } }
    dish { id = "GameStew",     family = "stew", level = 2, procs = { "wash", "trim", "peel", "chop", "season", "stir" },
      slots = { s(G.game, 2, x({ "red" })), s(G.root, 2, VEG), s(G.mushroom, 1, x({ "mushroom" }, true)), s(G.onion, 1), s(G.roastherb, 1, SPICE) } }
    dish { id = "PorkStew",     family = "stew", level = 2, procs = { "wash", "peel", "trim", "chop", "season", "stir" },
      slots = { s(G.pork, 2), s(G.potato, 1), s({ "Base.Cabbage", "Base.Kale", "Base.Spinach" }, 1, VEG), s(G.onion, 1), s(G.salt, 1, SPICE) } }
    dish { id = "Chili",        family = "stew", level = 3, procs = { "wash", "mince", "chop", "season", "stir" },
      slots = { s(G.mince, 2, x({ "red" })), s(G.beans, 2, x({ "bean" })), s(G.tomato, 1), s(G.pepper, 1, VEGO), s(G.hot, 1, SPICE) } }
    dish { id = "HuntersFeast", family = "stew", level = 10, procs = { "wash", "trim", "pound", "peel", "chop", "grind", "season", "stir" },
      slots = { s({ "Base.Venison", "Base.Beef", "Base.Rabbitmeat", "Base.Steak" }, 2, x({ "red" })), s(G.mushroom, 1, x({ "mushroom" })), s(G.root, 1, VEG),
                s(G.onion, 1), s({ "Base.Garlic", "Base.WildGarlic2" }, 1), s(G.roastherb, 1, SPICE) } }
    dish { id = "FishStew",     family = "stew", level = 8, procs = { "scale", "trim", "peel", "chop", "grind", "stir" },
      slots = { s(G.fish, 2, x({ "fish" })), s(G.shrimp, 1, x({ "fish" }, true)), s(G.tomato, 1), s({ "Base.Leek", "Base.Onion" }, 1), s(G.garlic, 1, SPICE) } }
    dish { id = "CurryStew",    family = "stew", level = 7, procs = { "wash", "trim", "peel", "chop", "grind", "season", "stir" },
      slots = { s(G.chicken, 2, x({ "poultry", "red" })), s(G.potato, 1), s(G.onion, 1), s({ "Base.GingerRoot", "Base.Garlic" }, 1), s(G.hot, 1, SPICE) } }
    -- ===== pan dishes (vanilla Stir fry: a frying pan, 4 / Roasted Vegetables: a roasting pan, 6)
    dish { id = "VegStirFry",   family = "stirfry", level = 0, procs = { "wash", "chop", "season", "toss" },
      slots = { s(G.greens, 2, VEG), s({ "Base.Cabbage", "Base.Kale" }, 1, VEG), s(G.onion, 1), s(G.asian, 1, SPICE) } }
    dish { id = "SproutStirFry", family = "stirfry", level = 1, procs = { "wash", "chop", "season", "toss" },
      slots = { s(G.sprouts, 2), s(G.carrot, 1, VEG), s(G.onion, 1), s(G.asian, 1, SPICE) } }
    dish { id = "MushroomStirFry", family = "stirfry", level = 1, procs = { "wash", "slice", "grind", "toss" },
      slots = { s(G.mushroom, 2, x({ "mushroom" })), s(G.greens, 1, VEG), s(G.garlic, 1), s(G.asian, 1, SPICE) } }
    dish { id = "TofuStirFry",  family = "stirfry", level = 2, procs = { "slice", "chop", "season", "toss" },
      slots = { s({ "Base.Tofu" }, 2), s(G.greens, 1, VEG), s(G.onion, 1), s(G.asian, 1, SPICE) } }
    dish { id = "ChickenStirFry", family = "stirfry", level = 2, procs = { "wash", "trim", "chop", "season", "toss" },
      slots = { s(G.chicken, 2, x({ "poultry" })), s(G.pepper, 1, VEG), s(G.onion, 1), s(G.asian, 1, SPICE) } }
    dish { id = "BeefStirFry",  family = "stirfry", level = 3, procs = { "trim", "slice", "chop", "season", "toss" },
      slots = { s({ "Base.Steak", "Base.Beef", "Base.Venison", "Base.Pork" }, 1, x({ "red" })), s({ "Base.BellPepper", "Base.Broccoli" }, 1, VEG), s(G.onion, 1), s(G.asian, 1, SPICE) } }
    dish { id = "ShrimpStirFry", family = "stirfry", level = 3, procs = { "wash", "trim", "chop", "season", "toss" },
      slots = { s(G.shrimp, 2, x({ "fish" })), s({ "Base.Broccoli", "Base.Greenpeas", "Base.BellPepper" }, 1, VEG), s(G.garlic, 1), s(G.asian, 1, SPICE) } }
    dish { id = "RoastVeg",     family = "roast", level = 1, procs = { "wash", "peel", "chop", "season" },
      slots = { s(G.root, 3, VEG), s(G.onion, 1), s(G.oil, 1, SPICE), s(G.roastherb, 1, SPICE) } }
    dish { id = "RoastChicken", family = "roast", level = 5, procs = { "wash", "trim", "peel", "chop", "season" },
      slots = { s(G.chicken, 2, x({ "poultry" })), s(G.potato, 2), s(G.carrot, 1, VEG), s(G.onion, 1), s(G.roastherb, 1, SPICE) } }
    -- ===== omelette (vanilla: an omelette already started in a pan, 3 fillings)
    dish { id = "Omelette",     family = "omelette", level = 1, procs = { "wash", "chop", "grate", "flip" },
      slots = { s({ "Base.Onion", "Base.Leek" }, 1), s({ "Base.BellPepper", "Base.Tomato", "Base.Zucchini", "Base.Broccoli", "Base.Kale" }, 1, VEG),
                s({ "Base.Cheese", "Base.HamSlice", "Base.MushroomGeneric1", "Base.MushroomsButton" }, 1, OPT),
                s({ "Base.Chives", "Base.Parsley", "Base.Basil", "Base.Garlic" }, 1, SPICE) } }
    dish { id = "HerbOmelette", family = "omelette", level = 2, procs = { "wash", "chop", "flip" },
      slots = { s({ "Base.Chives", "Base.Parsley", "Base.Basil" }, 2, x({ "herb" })), s({ "Base.Cheese" }, 1, OPT) } }
    dish { id = "PotatoOmelette", family = "omelette", level = 3, procs = { "wash", "peel", "slice", "flip" },
      slots = { s(G.potato, 2), s({ "Base.Onion" }, 1) } }
    -- ===== cold dishes (vanilla Salad / Fruit Salad: a bowl, 6)
    dish { id = "GardenSalad",  family = "salad", level = 0, procs = { "wash", "chop", "season" },
      slots = { s(G.lettuce, 2, VEG), s(G.salad, 2, VEG), s({ "Base.OilOlive", "Base.OilVegetable", "Base.BalsamicVinegar" }, 1, SPICE) } }
    dish { id = "WildSalad",    family = "salad", level = 1, procs = { "wash", "chop", "season" },
      slots = { s(G.wild, 3, x({ "herb" })), s({ "Base.Lettuce", "Base.Spinach" }, 1, OPT), s({ "Base.OilOlive", "Base.Lemon" }, 1, SPICE) } }
    dish { id = "Coleslaw",     family = "salad", level = 1, procs = { "wash", "grate", "season" },
      slots = { s({ "Base.Cabbage" }, 2), s(G.carrot, 1), s({ "Base.MayonnaiseFull", "Base.RemouladeFull", "Base.BalsamicVinegar" }, 1, SPICE) } }
    dish { id = "SproutSalad",  family = "salad", level = 1, procs = { "wash", "chop", "season" },
      slots = { s(G.sprouts, 2), s(G.carrot, 1, VEG), s({ "Base.Cucumber", "Base.RedRadish" }, 1, VEGO), s({ "Base.Soysauce", "Base.RiceVinegar", "Base.SesameOil" }, 1, SPICE) } }
    dish { id = "GreekSalad",   family = "salad", level = 2, procs = { "wash", "chop", "slice", "season" },
      slots = { s({ "Base.Tomato" }, 1), s({ "Base.Cucumber" }, 1), s({ "Base.Onion" }, 1), s({ "Base.Olives" }, 1, OPT), s({ "Base.Cheese" }, 1), s({ "Base.OilOlive" }, 1, SPICE) } }
    dish { id = "ChefSalad",    family = "salad", level = 2, procs = { "wash", "chop", "grate", "season" },
      slots = { s(G.lettuce, 1), s({ "Base.EggBoiled" }, 1), s({ "Base.HamSlice", "Base.Chicken" }, 1), s({ "Base.Cheese" }, 1), s(G.tomato, 1, OPT) } }
    dish { id = "AvocadoSalad", family = "salad", level = 3, procs = { "wash", "core", "slice", "season" },
      slots = { s({ "Base.Avocado" }, 2), s({ "Base.Tomato" }, 1), s({ "Base.Onion", "Base.GreenOnions" }, 1), s({ "Base.OilOlive", "Base.BalsamicVinegar", "Base.Salt", "Base.Pepper" }, 1, SPICE) } }
    dish { id = "FruitSalad",   family = "fruitsalad", level = 0, procs = { "wash", "peel", "chop" },
      slots = { s(G.fruit, 3, FRUIT), s(G.berry, 1, x({ "berry" }, true)), s({ "Base.Honey", "Base.Lemon", "Base.Lime" }, 1, SPICE) } }
    dish { id = "BerryBowl",    family = "fruitsalad", level = 1, procs = { "wash", "core" },
      slots = { s(G.berry, 3, BERRY), s({ "Base.Honey", "Base.Lemon" }, 1, SPICE) } }
    dish { id = "TropicalSalad", family = "fruitsalad", level = 2, procs = { "wash", "peel", "core", "chop", "zest" },
      slots = { s(G.tropic, 3, FRUIT), s({ "Base.Lime", "Base.Lemon" }, 1, SPICE) } }
    -- ===== breads (Sandwich: bread slices or a baguette, 4 / Burger: a bun, 4 /
    -- Hotdog: a hot dog to top, 2 / Burrito: a tortilla, 5 / Taco: a taco shell, 5)
    dish { id = "BLT",          family = "sandwich", level = 0, procs = { "wash", "slice" },
      slots = { s({ "Base.Bacon", "Base.BaconRashers" }, 1), s({ "Base.Lettuce", "Base.Kale", "Base.Cabbage" }, 1), s(G.tomato, 1), s({ "Base.MayonnaiseFull", "Base.Mustard" }, 1, SPICE) } }
    dish { id = "HamCheese",    family = "sandwich", level = 0, procs = { "slice", "grate" },
      slots = { s({ "Base.HamSlice", "Base.SalamiSlice", "Base.BaloneySlice" }, 1), s({ "Base.Cheese", "Base.Processedcheese" }, 1), s({ "Base.Lettuce", "Base.Tomato" }, 1, OPT), s({ "Base.Mustard", "Base.MayonnaiseFull" }, 1, SPICE) } }
    dish { id = "VeggieSandwich", family = "sandwich", level = 1, procs = { "wash", "slice" },
      slots = { s({ "Base.Cucumber", "Base.Tomato" }, 2, VEG), s({ "Base.Lettuce", "Base.Spinach" }, 1), s({ "Base.Cheese" }, 1, OPT) } }
    dish { id = "EggSandwich",  family = "sandwich", level = 1, procs = { "slice", "chop", "spread" },
      slots = { s({ "Base.EggBoiled" }, 1), s({ "Base.Lettuce", "Base.Chives" }, 1, OPT), s({ "Base.MayonnaiseFull", "Base.Mustard" }, 1, SPICE) } }
    dish { id = "TunaSandwich", family = "sandwich", level = 1, procs = { "chop", "mash", "spread" },
      slots = { s({ "Base.TunaTinOpen", "Base.CannedSardinesOpen" }, 1), s({ "Base.Lettuce", "Base.Onion" }, 1, OPT), s({ "Base.MayonnaiseFull" }, 1, SPICE) } }
    dish { id = "PBJ",          family = "sandwich", level = 0, procs = { "spread" },
      slots = { s({ "Base.PeanutButter" }, 1), s({ "Base.JamFruit", "Base.JamMarmalade", "Base.Banana" }, 1) } }
    dish { id = "Burger",       family = "burger", level = 1, procs = { "mince", "chop", "season" },
      slots = { s({ "Base.MeatPatty", "Base.MincedMeat" }, 1), s({ "Base.Cheese" }, 1, OPT), s({ "Base.Lettuce", "Base.Onion" }, 1, OPT), s(G.tomato, 1, OPT), s(G.sauce, 1, SPICE) } }
    dish { id = "BaconBurger",  family = "burger", level = 3, procs = { "slice", "chop", "grate", "season" },
      slots = { s({ "Base.MeatPatty" }, 1), s({ "Base.Bacon", "Base.BaconRashers" }, 1), s({ "Base.Cheese" }, 1), s({ "Base.Onion", "Base.Pickles" }, 1, OPT), s(G.sauce, 1, SPICE) } }
    dish { id = "HotDog",       family = "hotdog", level = 0, procs = { "chop" },
      slots = { s({ "Base.Onion", "Base.Tomato", "Base.Lettuce", "Base.Pickles" }, 1), s({ "Base.Cheese", "Base.MincedMeat" }, 1, OPT), s({ "Base.Mustard", "Base.Ketchup" }, 1, SPICE) } }
    dish { id = "ChiliDog",     family = "hotdog", level = 2, procs = { "chop", "grate" },
      slots = { s({ "Base.CannedChiliOpen" }, 1), s({ "Base.Cheese", "Base.Onion" }, 1) } }
    dish { id = "BeanBurrito",  family = "burrito", level = 2, procs = { "wash", "chop", "grate", "season" },
      slots = { s({ "Base.Blackbeans", "Base.RefriedBeans" }, 1), s({ "Base.Cheese" }, 1), s({ "Base.Onion", "Base.Lettuce" }, 1, OPT), s({ "Base.Tomato" }, 1, OPT), s(G.hot, 1, SPICE) } }
    dish { id = "ChickenBurrito", family = "burrito", level = 3, procs = { "chop", "slice", "mash", "season" },
      slots = { s({ "Base.Chicken", "Base.ChickenFillet" }, 1, x({ "poultry" })), s({ "Base.Avocado", "Base.Guacamole" }, 1, OPT), s({ "Base.Tomato", "Base.Dip_Salsa" }, 1), s({ "Base.Cheese" }, 1, OPT), s(G.hot, 1, SPICE) } }
    dish { id = "BeefTaco",     family = "taco", level = 2, procs = { "mince", "wash", "chop", "grate", "season" },
      slots = { s({ "Base.MincedMeat", "Base.MeatPatty", "Base.Beef", "Base.Steak" }, 1), s({ "Base.Lettuce", "Base.Cabbage" }, 1), s({ "Base.Tomato" }, 1, OPT), s({ "Base.Cheese" }, 1, OPT), s(G.hot, 1, SPICE) } }
    dish { id = "FishTaco",     family = "taco", level = 6, procs = { "scale", "trim", "grate", "zest" },
      slots = { s({ "Base.FishFillet", "Base.Salmon", "Base.Shrimp" }, 1, x({ "fish" })), s({ "Base.Cabbage", "Base.Lettuce" }, 1), s({ "Base.Avocado", "Base.Dip_Salsa" }, 1, OPT), s({ "Base.Lime", "Base.Lemon" }, 1, SPICE) } }
    -- ===== toast and bagels (vanilla Toast: a slice of toast / a bagel, 3)
    dish { id = "JamToast",     family = "toast", level = 0, procs = { "spread" },
      slots = { s({ "Base.Butter", "Base.Margarine" }, 1, OPT), s({ "Base.JamFruit", "Base.JamMarmalade", "Base.Honey", "Base.PeanutButter" }, 1) } }
    dish { id = "BeansOnToast", family = "toast", level = 0, procs = { "spread" },
      slots = { s({ "Base.OpenBeans" }, 1), s({ "Base.Cheese" }, 1, OPT) } }
    dish { id = "GarlicToast",  family = "toast", level = 1, procs = { "grind", "chop", "spread" },
      slots = { s({ "Base.Butter", "Base.Margarine" }, 1), s({ "Base.Garlic", "Base.WildGarlic2" }, 1), s({ "Base.Parsley", "Base.Chives", "Base.Oregano" }, 1, SPICE) } }
    dish { id = "AvocadoToast", family = "toast", level = 2, procs = { "core", "mash", "spread", "season" },
      slots = { s({ "Base.Avocado" }, 1), s({ "Base.Chives", "Base.GreenOnions", "Base.Parsley" }, 1, SPICE) } }
    dish { id = "RoeToast",     family = "toast", level = 4, procs = { "spread" },
      slots = { s({ "Base.Butter" }, 1, OPT), s({ "Base.FishRoe", "Base.CannedRoe_Open", "Base.Caviar" }, 1), s({ "Base.Chives" }, 1, SPICE) } }
    -- ===== bread dough (vanilla Bread: the dough itself, 2)
    dish { id = "HerbBread",    family = "bread", level = 3, procs = { "chop", "knead" },
      slots = { s({ "Base.Rosemary", "Base.Thyme", "Base.Oregano", "Base.Garlic" }, 1, x({ "herb" })), s({ "Base.Cheese" }, 1, OPT) } }
    dish { id = "SeedBread",    family = "bread", level = 3, procs = { "measure", "knead" },
      slots = { s(G.seeds, 2) } }
    dish { id = "BananaBread",  family = "bread", level = 4, procs = { "peel", "mash", "knead" },
      slots = { s({ "Base.Banana" }, 1), s({ "Base.ChocolateChips" }, 1, OPT) } }
    -- ===== baking (Pie / Sweet Pie / Cake: the preparation in its pan, 4 / Muffin: the tray, 1)
    dish { id = "VegPie",       family = "pie", level = 3, procs = { "wash", "peel", "chop", "season", "roll" },
      slots = { s(G.potato, 1), s(G.carrot, 1, VEG), s({ "Base.Leek", "Base.Onion" }, 1), s(G.mushroom, 1, x({ "mushroom", "veg" }, true)) } }
    dish { id = "MeatPie",      family = "pie", level = 3, procs = { "wash", "peel", "mince", "chop", "season", "roll" },
      slots = { s({ "Base.MincedMeat", "Base.Pork", "Base.Rabbitmeat", "Base.Chicken" }, 2, x({ "red", "poultry" })), s(G.potato, 1), s({ "Base.Onion", "Base.Leek", "Base.Carrots" }, 1),
                s({ "Base.Salt", "Base.Pepper", "Base.Garlic" }, 1, SPICE) } }
    dish { id = "ChickenPie",   family = "pie", level = 4, procs = { "trim", "peel", "chop", "season", "roll" },
      slots = { s(G.chicken, 1, x({ "poultry" })), s(G.carrot, 1), s({ "Base.Leek", "Base.Onion" }, 1), s(G.mushroom, 1, x({ "mushroom" }, true)) } }
    dish { id = "ForestPie",    family = "pie", level = 7, procs = { "wash", "trim", "mince", "slice", "grind", "roll" },
      slots = { s({ "Base.MincedMeat", "Base.Rabbitmeat", "Base.Pork" }, 1, x({ "red" })), s(G.mushroom, 2, x({ "mushroom" })), s({ "Base.Onion", "Base.Leek" }, 1),
                s({ "Base.Garlic", "Base.Pepper", "Base.Salt" }, 1, SPICE) } }
    dish { id = "ApplePie",     family = "sweetpie", level = 3, procs = { "wash", "peel", "core", "chop", "roll" },
      slots = { s(G.apple, 3, FRUIT), s({ "Base.Cinnamon" }, 1, SPICE) } }
    dish { id = "BerryPie",     family = "sweetpie", level = 4, procs = { "wash", "core", "measure", "roll" },
      slots = { s({ "Base.Strewberrie", "Base.Cherry", "Base.BerryBlue", "Base.BerryBlack", "Base.Peach" }, 3, BERRY), s({ "Base.Honey", "Base.Lemon" }, 1, SPICE) } }
    dish { id = "PumpkinPie",   family = "sweetpie", level = 6, procs = { "peel", "chop", "mash", "measure", "roll" },
      slots = { s({ "Base.Pumpkin", "Base.PumpkinSliced", "Base.PumpkinSmashed" }, 2), s({ "Base.Cinnamon" }, 1, SPICE), s({ "Base.Honey" }, 1, SPICE) } }
    dish { id = "BananaCake",   family = "cake", level = 4, procs = { "peel", "mash", "measure", "whisk", "fold" },
      slots = { s({ "Base.Banana", "Base.Apple" }, 2), s({ "Base.Strewberrie", "Base.Orange", "Base.Peach" }, 1, OPT), s({ "Base.Cinnamon", "Base.Honey", "Base.Lemon" }, 1, SPICE) } }
    dish { id = "ChocolateCake", family = "cake", level = 6, procs = { "grate", "measure", "whisk", "fold" },
      slots = { s({ "Base.Chocolate", "Base.ChocolateChips" }, 2), s({ "Base.Strewberrie", "Base.Cherry", "Base.Banana" }, 1, OPT) } }
    dish { id = "FruitCake",    family = "cake", level = 8, procs = { "chop", "zest", "measure", "fold" },
      slots = { s(G.dried, 3), s({ "Base.Lemon", "Base.Orange", "Base.Cinnamon" }, 1, SPICE) } }
    dish { id = "FruitMuffins", family = "muffin", level = 3, procs = { "wash", "chop", "measure", "fold" },
      slots = { s({ "Base.BerryBlue", "Base.BerryBlack", "Base.Banana", "Base.Apple", "Base.Cherry", "Base.Peach" }, 1, FRUIT), s({ "Base.Cinnamon", "Base.Lemon" }, 1, SPICE) } }
    dish { id = "ChocoMuffins", family = "muffin", level = 3, procs = { "measure", "fold" },
      slots = { s({ "Base.ChocolateChips", "Base.Chocolate" }, 1) } }
    -- ===== pizza (vanilla: a pizza already prepared on its tray, 6)
    dish { id = "Margherita",   family = "pizza", level = 3, procs = { "roll", "wash", "slice", "grate", "season" },
      slots = { s(G.tomato, 2), s({ "Base.Cheese" }, 2), s(G.italian, 1, SPICE) } }
    dish { id = "VeggiePizza",  family = "pizza", level = 4, procs = { "roll", "wash", "slice", "grate", "season" },
      slots = { s({ "Base.BellPepper", "Base.Onion", "Base.Olives" }, 2, VEG), s(G.mushroom, 1, x({ "mushroom" }, true)), s(G.tomato, 1), s({ "Base.Cheese" }, 1), s(G.italian, 1, SPICE) } }
    dish { id = "SalamiPizza",  family = "pizza", level = 4, procs = { "roll", "wash", "slice", "grate", "season" },
      slots = { s({ "Base.Pepperoni", "Base.SalamiSlice", "Base.HamSlice", "Base.Sausage", "Base.Bacon" }, 2), s({ "Base.Cheese" }, 1), s(G.tomato, 1), s(G.pepper, 1, VEGO), s(G.italian, 1, SPICE) } }
    -- ===== pasta and rice (pasta / rice in a pot of water, 5 -- a saucepan, 4)
    dish { id = "TomatoPasta",  family = "pasta", level = 1, procs = { "wash", "chop", "grate", "season", "stir" },
      slots = { s(G.tomato, 2), s({ "Base.Cheese" }, 1, OPT), s(G.italian, 1, SPICE) } }
    dish { id = "CarbonaraPasta", family = "pasta", level = 3, procs = { "chop", "crack", "whisk", "grate", "stir" },
      slots = { s({ "Base.Bacon", "Base.HamSlice" }, 1), s({ "Base.Egg" }, 1), s({ "Base.Cheese" }, 1), s({ "Base.Pepper" }, 1, SPICE) } }
    dish { id = "PestoPasta",   family = "pasta", level = 5, procs = { "wash", "grind", "grate", "stir" },
      slots = { s({ "Base.Basil", "Base.Parsley" }, 2), s({ "Base.Garlic" }, 1), s({ "Base.Cheese" }, 1, OPT), s({ "Base.OilOlive" }, 1, SPICE) } }
    dish { id = "SeafoodPasta", family = "pasta", level = 6, procs = { "trim", "chop", "grind", "season", "stir" },
      slots = { s(G.shrimp, 2, x({ "fish" })), s(G.tomato, 1), s({ "Base.Garlic" }, 1), s({ "Base.Parsley", "Base.Basil" }, 1, SPICE) } }
    dish { id = "FriedRice",    family = "rice", level = 2, procs = { "wash", "chop", "crack", "season", "stir" },
      slots = { s({ "Base.Egg" }, 1), s({ "Base.Greenpeas", "Base.Carrots", "Base.Corn" }, 2, VEG), s({ "Base.Onion", "Base.Leek" }, 1), s({ "Base.Soysauce", "Base.RiceVinegar", "Base.Garlic" }, 1, SPICE) } }
    dish { id = "ChickenRice",  family = "rice", level = 3, procs = { "trim", "chop", "grind", "stir" },
      slots = { s(G.chicken, 1, x({ "poultry" })), s({ "Base.Greenpeas", "Base.Carrots" }, 2, VEG), s({ "Base.Garlic", "Base.GingerRoot" }, 1, SPICE) } }
    dish { id = "MushroomRice", family = "rice", level = 4, procs = { "wash", "slice", "chop", "stir" },
      slots = { s(G.mushroom, 2, x({ "mushroom" })), s({ "Base.Onion" }, 1), s({ "Base.Parsley", "Base.Basil", "Base.Garlic", "Base.Pepper" }, 1, SPICE) } }
    dish { id = "SeafoodRice",  family = "rice", level = 9, procs = { "scale", "trim", "chop", "season", "stir" },
      slots = { s(G.shrimp, 2, x({ "fish" })), s({ "Base.BellPepper", "Base.Greenpeas" }, 1, VEG), s({ "Base.Onion", "Base.Garlic" }, 1), s(G.hot, 1, SPICE) } }
    -- ===== breakfast (vanilla Oatmeal / Pancakes: the bowl / the pancakes, 3)
    dish { id = "FruitOatmeal", family = "oatmeal", level = 0, procs = { "chop", "stir" },
      slots = { s({ "Base.Banana", "Base.Apple", "Base.Strewberrie", "Base.Peach" }, 2, FRUIT), s({ "Base.Honey", "Base.Sugar", "Base.Cinnamon" }, 1, SPICE) } }
    dish { id = "DriedFruitOatmeal", family = "oatmeal", level = 1, procs = { "chop", "stir" },
      slots = { s(G.dried, 2), s({ "Base.Yoghurt", "Base.CannedMilkOpen" }, 1, OPT), s({ "Base.Cinnamon", "Base.Honey" }, 1, SPICE) } }
    dish { id = "FruitPancakes", family = "pancakes", level = 1, procs = { "chop", "measure", "flip" },
      slots = { s({ "Base.Strewberrie", "Base.Cherry", "Base.BerryBlue", "Base.Banana" }, 1, FRUIT), s({ "Base.Banana", "Base.Peach", "Base.Orange" }, 1, OPT), s({ "Base.Honey", "Base.MapleSyrup", "Base.Cinnamon" }, 1, SPICE) } }
    dish { id = "ChocoPancakes", family = "pancakes", level = 2, procs = { "grate", "flip" },
      slots = { s(G.choc, 1), s({ "Base.Banana", "Base.Strewberrie" }, 1, OPT), s({ "Base.MapleSyrup", "Base.Honey" }, 1, SPICE) } }
    dish { id = "BerrySundae",  family = "icecream", level = 0, procs = { "wash", "chop" },
      slots = { s(G.berry, 2, BERRY), s({ "Base.Honey", "Base.MapleSyrup", "Base.Chocolate" }, 1, OPT) } }
    -- ===== hot drinks (vanilla Prepare Beverage: a mug or cup full of water, 3)
    dish { id = "HerbalTea",    family = "drink", level = 0, procs = { "wash", "steep" },
      slots = { s(G.herbtea, 1, x({ "herb" })), s({ "Base.Honey", "Base.Sugar" }, 1, OPT) } }
    dish { id = "LemonHoneyTea", family = "drink", level = 0, procs = { "slice", "steep", "measure" },
      slots = { s({ "Base.Lemon", "Base.Lime" }, 1), s({ "Base.Honey" }, 1), s({ "Base.Teabag2" }, 1, OPT) } }
    dish { id = "Coffee",       family = "drink", level = 0, procs = { "measure", "steep" },
      slots = { s({ "Base.Coffee2" }, 1), s({ "Base.Sugar", "Base.SugarCubes", "Base.SugarPacket" }, 1, OPT), s(G.milk, 1, OPT) } }
    dish { id = "RosehipTea",   family = "drink", level = 1, procs = { "wash", "grind", "steep" },
      slots = { s({ "Base.Rosehips" }, 2), s({ "Base.Honey" }, 1, OPT) } }
    dish { id = "GingerTea",    family = "drink", level = 1, procs = { "peel", "slice", "steep" },
      slots = { s({ "Base.GingerRoot" }, 1), s({ "Base.Lemon", "Base.Lime" }, 1, OPT), s({ "Base.Honey" }, 1, OPT) } }
    dish { id = "HotChocolate", family = "drink", level = 1, procs = { "measure", "stir" },
      slots = { s({ "Base.CocoaPowder" }, 1), s({ "Base.Sugar", "Base.SugarBrown", "Base.Honey" }, 1, OPT), s(G.milk, 1, OPT) } }
    dish { id = "ForagerTea",   family = "drink", level = 2, procs = { "wash", "chop", "steep" },
      slots = { s({ "Base.Nettles", "Base.Dandelions", "Base.Violets", "Base.Thistle" }, 2), s({ "Base.MintHerb", "Base.Honey" }, 1, OPT) } }
    dish { id = "BerryTea",     family = "drink", level = 2, procs = { "wash", "mash", "steep" },
      slots = { s({ "Base.Strewberrie" }, 1), s({ "Base.Teabag2", "Base.MintHerb" }, 1), s({ "Base.Sugar", "Base.Honey" }, 1, OPT) } }
end

-- quick lookups
K.DISH_BY_ID = {}
for _, d in ipairs(K.DISHES) do K.DISH_BY_ID[d.id] = d end

-- quality words from the minigames (the same words The Way To Attack uses)
K.WORD_SCORE = { Excellent = 1.0, Good = 0.66, Bad = 0.33 }

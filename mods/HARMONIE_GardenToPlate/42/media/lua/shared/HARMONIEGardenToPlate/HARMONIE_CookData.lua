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

-- 0.13.2: progress markers in console.txt while this file loads -- if the
-- game ever stops part way (0.13.1: "Expected a table" in the tab, the
-- dishes never arrived), the last marker printed shows where. This file
-- loads before the logger may exist, so it falls back to print.
local function mark(fmt, ...)
    if HARMONIE_GTP.Log then return HARMONIE_GTP.Log("CookData", fmt, ...) end
    local ok, line = pcall(string.format, fmt, ...)
    print("[HARMONIE_GTP][CookData] " .. (ok and line or tostring(fmt)))
end
local function count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end return n end
mark("loading the cooking data (1/5)")

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
mark("tools: %d groups (2/5)", count(K.TOOLS))

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
mark("steps: %d (3/5)", count(K.PROCS))

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

mark("dish kinds: %d (4/5)", count(K.FAMILIES))

-- food kinds (vanilla FoodType). A slot with cats = { "veg" } also takes
-- any vegetable the recipe accepts that is not in its list.
K.CATS = {
    veg = { "Vegetables", "Vegetable", "Greens" }, mushroom = { "Mushroom" }, fruit = { "Fruits", "Citrus" }, berry = { "Berry" },
    red = { "Beef", "Meat", "Venison", "Game" }, poultry = { "Poultry", "Game" }, fish = { "Fish", "Seafood" }, bean = { "Bean" },
    herb = { "Herb" }, hot = { "HotPepper" }, cheese = { "Cheese" }, cured = { "Sausage", "Bacon" },
}
-- never taken through a kind, even when vanilla would allow it
K.NEVER = { ["Base.BerryPoisonIvy"] = true, ["Base.HollyBerry"] = true }

-- GTP 1.1.0 (owner 2026-11-19): the 99 dishes of our own are gone -- the
-- Cooking tab now uses vanilla's own menus (evolved recipes + craftRecipes of
-- category Cooking) and our minigames only PREPARE ingredients
-- (HARMONIE_Prep.lua). Empty tables kept so an old reference never throws.
K.DISHES = {}
K.DISH_BY_ID = {}
K.GROUPS = {}
mark("cooking data loaded: tools, steps, kinds (5/5)")

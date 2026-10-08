VANILLA PROJECT ZOMBOID BUILD 42 -- LOOKUP REFERENCE
=====================================================

Made 2026-10-08 from the game's own files the owner sent
(scripts.zip = ProjectZomboid/media/scripts, 1004 files, and
EN.zip -> Translate/EN/ItemName.json). Request: "ทำ txt เก็บ key item
และ scripts ทั้งหมดไว้ ใน folder mod ใหญ่ เวลาต้องใช้จะได้อ้างอิงได้".

This folder is NOT a mod (no mod.info): the game never loads it and
sync_to_workshop.sh never copies it. It is here only so that item
types, food numbers and recipes can be looked up instead of guessed.

FILES (one line per thing, "|"-separated, easy to grep)
-------------------------------------------------------
items_index.txt                5105 items
    full type | English name | ItemType | DisplayCategory | Weight | Icon | file
    grep -i "kitchen knife" items_index.txt   -> the real type name
food_index.txt                 726 foods
    hunger, thirst, calories, carbohydrates, fat, protein, unhappy,
    boredom, fresh / rotten days, FoodType, cookable, EvolvedRecipe, Tags
evolvedrecipes_index.txt       63 evolved recipes (soup, stew, stir fry,
                               salad, sandwich, burger, pie, cake, pasta ...)
    script name | BaseItem | ResultItem | MaxItems | Name | Template | other keys | file
evolvedrecipe_ingredients.txt  31 recipe templates -> every item that may
                               go in, with its points (hunger used per
                               addition) and "|Cooked" when it must be
                               cooked first
craftrecipes_index.txt         969 craftRecipes: keys, inputs, outputs
tags_index.txt                 454 item tags -> the items that carry them

raw/   (NOT in git -- see below) the vanilla files themselves:
    raw/scripts/        the whole media/scripts folder from scripts.zip
    raw/ItemName.json   the English item names

WHY raw/ IS NOT COMMITTED
-------------------------
The GitHub repo is public. raw/ is The Indie Stone's own game files
(about 10 MB); putting them in a public repo would re-publish them.
The index files above are short lookup lists (names and numbers) for
our own work. raw/ is listed in .gitignore, so it only exists on the
computer where it was unpacked. To get it back on another computer:

    unzip scripts.zip  -> mods/_VanillaReference_B42/raw/scripts/
    copy ProjectZomboid/media/lua/shared/Translate/EN/ItemName.json
         -> mods/_VanillaReference_B42/raw/ItemName.json
    (or point build_index.py at the game's own folders directly)

REBUILD (after a game update)
-----------------------------
    python3 build_index.py <ProjectZomboid/media/scripts> <.../Translate/EN/ItemName.json>
    e.g. python3 build_index.py raw/scripts raw/ItemName.json

Then regenerate what our mods build from it:
    python3 ../HARMONIE_GardenToPlate/tools/gen_cook_vanilla.py
        -> HARMONIE_CookVanilla.lua (the Cooking tab's vanilla tables)

HOW TO READ AN ITEM'S EvolvedRecipe
-----------------------------------
    EvolvedRecipe = Soup:8;Stew:8;Salad:4|Cooked
    Soup / Stew / Salad = the recipe Template (evolvedrecipes_index.txt)
    8                   = hunger points (/100) one addition uses
    |Cooked             = vanilla only takes it once it is cooked


console.txt log (0.11.2)
------------------------
Search console.txt for "[HARMONIE_GTP]". Each line names the part
(VitData, SunD, SeedLoot, Guide, Assess, Panel, Keys, Admin, Grow, Foods)
and the side it ran on (SP / client / server). Things that repeat every
tick are logged once or as a daily summary, so the log stays short. When
reporting a bug, send these lines.

Cooking tab (0.12.0)
--------------------
The guide window (key N) has a Cooking tab with 35 ready-made dishes,
each one of the game's own evolved recipes (soup, stew, stir fry, roast,
salad, fruit salad, sandwich, burger, hot dog, savory and sweet pie, cake,
muffins, pasta, rice, oatmeal, omelette, pizza, burrito, taco, pancakes).
- The base (a pot with water, a frying pan, bread, ...) and the recipe are
  found from what is at hand by asking the game itself
  (RecipeManager.getEvolvedRecipe); whether an ingredient may go in is the
  game's answer too (shown greyed out and logged when it refuses).
- Preparation steps: wash, peel, chop, mince, trim, crack, grate, knead,
  measure, whisk, season, stir -- each needs its tools (knife, cleaver,
  spoon, whisk / fork, cheese grater) and a Cooking level; a cutting board
  or rolling pin at hand makes it easier, a makeshift tool harder. Each is
  a short minigame (sandbox CookMinigames) then a timed action, quicker at
  a higher Cooking level.
- The ingredients then go in with the game's own ISAddItemInRecipe, so
  calories, carbohydrates, fat, protein, hunger, rotting, spices and the
  portion rules stay vanilla's, and vitamins carry over through this mod's
  existing hook. The dish is cooked the usual way (stove, oven, campfire).
- Preparation quality (Excellent / Good / Poor) makes the dish 10 / 4 less
  or 5 more boring and unhappy to eat (sandbox CookQualityEffect) and gives
  Cooking XP (CookXPMultiplier). In multiplayer the server makes that change.
- console.txt: search "[HARMONIE_GTP][Cook]" -- every start, step, minigame,
  addition, refusal and the final dish with its vanilla values.

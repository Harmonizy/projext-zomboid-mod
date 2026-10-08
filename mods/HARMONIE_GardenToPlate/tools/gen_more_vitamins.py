#!/usr/bin/env python3
"""HARMONIE - From Garden to Plate: vitamin profiles for the vanilla foods the
hand-written table (HARMONIE_FoodVitaminDatabase.lua) does not cover --
herbs, chili peppers, pumpkin and squash, seaweed, roe, yogurt, sauces,
seeds, insects, small game ... (0.13.0, owner: "แม้ว่าจะใส่วัตถุดิบไหนก็ตาม
หากมี ต้องส่งไปยังอาหาร").

Each group below is an amount PER 10 HUNGER POINTS (rough real-world
figures for that much of the food). The profile of an item is that times
its own vanilla hunger (mods/_VanillaReference_B42/food_index.txt), so a
big jar of dried oregano (20 hunger) holds four times what a sprig of
fresh oregano (5) does. Units as everywhere in the mod: mcg for A / D / K,
mg for B / C / E.
Writes 42/media/lua/shared/HARMONIEGardenToPlate/HARMONIE_MoreFoodVitamins.lua.
An entry already in the hand-written table always wins (checked at load).
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, "..", "..", "_VanillaReference_B42", "food_index.txt")
OUT = os.path.join(HERE, "..", "42", "media", "lua", "shared", "HARMONIEGardenToPlate", "HARMONIE_MoreFoodVitamins.lua")

G = [
  # fresh herbs and wild greens
  ({"A": 150, "C": 40, "K": 300}, "Parsley"),
  ({"A": 100, "K": 120}, "Basil"),
  ({"A": 100, "C": 8, "K": 90}, "Cilantro CilantroSeed"),
  ({"A": 60, "C": 15, "K": 60}, "Chives"),
  ({"A": 30, "E": 1, "K": 100}, "Oregano"),
  ({"A": 30, "C": 5, "K": 50}, "Rosemary Sage Thyme"),
  ({"A": 40, "C": 6}, "MintHerb"),
  ({"A": 15, "C": 10, "K": 60}, "GreenOnions"),
  ({"A": 20, "C": 30, "K": 20}, "WildGarlic2"),
  ({"A": 100, "C": 10, "K": 250}, "Nettles"),
  ({"A": 50, "C": 10, "K": 50}, "CommonMallow"),
  ({"A": 50, "C": 20}, "Violets"),
  ({"C": 10}, "Roses FourLeafClover"),
  ({"K": 20}, "Thistle"),
  ({"A": 10}, "Chamomile Lavender Marigold BlackSage"),
  ({"B": 1}, "LemonGrass Ginseng"),
  ({"B": 1, "C": 3}, "Garlic"),
  ({"B": 1}, "PowderedGarlic PowderedOnion"),
  # dried herbs (most K and some A stay, the C is gone)
  ({"A": 90, "C": 8, "K": 210}, "ParsleyDried Seasoning_Parsley"),
  ({"A": 60, "K": 85}, "BasilDried Seasoning_Basil"),
  ({"A": 60, "K": 63}, "CilantroDried Seasoning_Cilantro"),
  ({"A": 36, "C": 3, "K": 42}, "ChivesDried Seasoning_Chives"),
  ({"A": 18, "E": 1, "K": 70}, "OreganoDried Seasoning_Oregano"),
  ({"A": 18, "C": 1, "K": 35}, "RosemaryDried SageDried ThymeDried Seasoning_Rosemary Seasoning_Sage Seasoning_Thyme"),
  ({"A": 24, "C": 1}, "MintHerbDried"),
  ({"A": 12, "C": 6, "K": 14}, "WildGarlicDried"),
  ({"A": 30, "C": 2, "K": 35}, "CommonMallowDried"),
  ({"C": 2}, "RosePetalsDried"),
  ({"A": 6}, "ChamomileDried LavenderPetalsDried MarigoldDried BlackSageDried"),
  # vegetables the table missed
  ({"A": 400, "C": 10, "E": 1}, "Pumpkin PumpkinSliced PumpkinSmashed"),
  ({"A": 300, "C": 15}, "Squash"),
  ({"A": 30, "C": 60}, "PepperJalapeno PepperHabanero"),
  ({"A": 25, "C": 10}, "PepperJalapenoDried PepperHabaneroDried"),
  ({"B": 1, "C": 3, "K": 60}, "Seaweed"),
  ({"K": 20}, "Pickles"),
  ({"C": 10}, "Wasabi"),
  ({"B": 2, "K": 5}, "SoybeansSeed GreenpeasSeed"),
  ({"B": 1}, "CornSeed"),
  # sauces and spreads
  ({"A": 50, "C": 10, "E": 1, "K": 5}, "TomatoPaste"),
  ({"A": 30, "C": 8, "E": 1}, "Marinara"),
  ({"A": 15, "C": 2}, "Ketchup BBQSauce"),
  ({"A": 20, "C": 10}, "Dip_Salsa"),
  ({"B": 1, "C": 6, "E": 2, "K": 15}, "Guacamole"),
  ({"K": 10}, "Dip_Ranch MayonnaiseFull RemouladeFull"),
  ({"A": 20, "D": 0.3}, "Dip_NachoCheese"),
  ({"A": 10, "C": 5}, "Hotsauce"),
  ({"C": 3}, "JamFruit"),
  ({"C": 4}, "JamMarmalade"),
  ({"C": 20}, "CannedFruitBeverageOpen"),
  ({"B": 0.3}, "MapleSyrup Gravy"),
  ({"K": 3}, "Cinnamon Pepper"),
  # dairy and fats
  ({"B": 1.5}, "Yoghurt"),
  ({"A": 40}, "SourCream"),
  ({"A": 150, "D": 2, "E": 2}, "Margarine"),
  ({"D": 1}, "Lard"),
  ({"E": 1, "K": 5}, "SesameOil"),
  # fish and roe
  ({"A": 30, "B": 3, "D": 5, "E": 2}, "FishRoe CannedRoe_Open Caviar"),
  ({"A": 200, "D": 5}, "FishGuts"),
  ({"B": 2, "D": 3}, "BaitFish"),
  ({"B": 2}, "ChickenFried"),
  # seeds, nuts
  ({"B": 1, "E": 0.5}, "FlaxSeed"),
  ({"E": 0.5, "K": 2}, "PumpkinSeed"),
  ({"B": 1, "E": 7}, "SunflowerSeeds"),
  ({"B": 0.5}, "PoppySeed CocoaPowder"),
  ({"B": 0.3, "E": 0.3}, "Chocolate ChocolateChips Chocolate_HeartBox"),
  # grain doughs (flour is usually enriched)
  ({"B": 0.5}, "Dough BreadDough BaguetteDough Cornbread Biscuit Crackers Flour2 Cornmeal2 Cornflour2"),
  # small game and bugs (B12, a little A from the organs)
  ({"A": 20, "B": 3}, "DeadMouse DeadMouseSkinned DeadMousePups DeadMousePupsSkinned DeadRat DeadRatSkinned DeadRatBaby DeadRatBabySkinned DeadBird DeadSquirrel"),
  ({"B": 3}, "Cricket Grasshopper Termites Worm Maggots Snail Slug Slug2 Pillbug Centipede Centipede2 Millipede Millipede2 Cockroach Leech Tadpole "
             "AmericanLadyCaterpillar BandedWoolyBearCaterpillar MonarchCaterpillar SawflyLarva SilkMothCaterpillar SwallowtailCaterpillar"),
  # pet food is fortified
  ({"A": 30, "B": 1, "D": 0.5, "E": 1}, "DogfoodOpen DogFoodBag CatFoodBag"),
]

hunger = {}
for l in open(REF, encoding="utf-8"):
    if not l.startswith("Base."): continue
    p = [x.strip() for x in l.split(" | ")]
    h = p[2]
    if h.startswith("HungerChange="):
        hunger[p[0]] = abs(float(h.split("=")[1]))

rows, missing = [], []
for prof, names in G:
    for n in names.split():
        t = "Base." + n
        h = hunger.get(t)
        if not h:
            missing.append(t); continue
        vals = ", ".join("%s = %s" % (k, ("%.2f" % (v * h / 10)).rstrip("0").rstrip(".")) for k, v in sorted(prof.items()))
        rows.append('    ["%s"] = { %s },' % (t, vals))

with open(OUT, "w", encoding="utf-8") as f:
    f.write("""--[[
    HARMONIE - From Garden to Plate: vitamin profiles for the rest of the
    vanilla foods (herbs, chili peppers, pumpkin, squash, seaweed, roe,
    yogurt, sauces, seeds, insects, small game ...), so whatever goes into a
    dish passes its vitamins on (HARMONIE_RecipeVitamins.lua).
    Generated by tools/gen_more_vitamins.py from the vanilla reference -- edit
    the groups there, not this file. A food already in the hand-written
    table (HARMONIE_FoodVitaminDatabase.lua) keeps its own entry.
]]--

require "HARMONIEGardenToPlate/HARMONIE_FoodVitaminDatabase"

local DB = HARMONIE_GTP.FoodVitaminDB
local MORE = {
%s
}
local added, kept = 0, 0
for fullType, profile in pairs(MORE) do
    if DB[fullType] then kept = kept + 1 else DB[fullType] = profile; added = added + 1 end
end
if HARMONIE_GTP.Log then
    HARMONIE_GTP.Log("Foods", "more vanilla foods: %%d vitamin profiles added, %%d already in the main table", added, kept)
else
    print(string.format("[HARMONIE_GTP][Foods] more vanilla foods: %%d vitamin profiles added, %%d already in the main table", added, kept))
end
""" % "\n".join(rows))
print("profiles", len(rows), "no hunger / not found:", missing)

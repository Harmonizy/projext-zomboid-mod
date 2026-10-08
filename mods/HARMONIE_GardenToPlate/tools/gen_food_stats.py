#!/usr/bin/env python3
"""HARMONIE - From Garden to Plate: sets the nutrition of our own foods from
vanilla's real numbers (mods/_VanillaReference_B42/food_index.txt), so they
can never drift from the produce they are made of.

  Home-Canned <Produce> (Open): 4 x the produce's calories / carbohydrates /
      fat / protein (the jar holds 4, see MakeHomeCannedProduce), and the
      produce's own EvolvedRecipe (without "|Cooked": a canned jar is
      already cooked) so the jar can go into soups, stews, pies ...
  Dried <Fruit>: one fresh fruit with the water taken out -- same calories /
      carbohydrates / fat / protein, 3/4 of its hunger, and an EvolvedRecipe
      shaped like vanilla's own Dried Apricots (Cake / PieSweet take the
      whole piece, FruitSalad / Pancakes / Muffin / Oatmeal / Salad half).
Run after a game update:  python3 tools/gen_food_stats.py
"""
import os, re

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, "..", "..", "_VanillaReference_B42", "food_index.txt")
SCRIPTS = os.path.join(HERE, "..", "42", "media", "scripts")

food = {}
for l in open(REF, encoding="utf-8"):
    if not l.startswith("Base."): continue
    p = [x.strip() for x in l.split(" | ")]
    d = {}
    for x in p[2:]:
        if "=" in x:
            k, v = x.split("=", 1); d[k] = v
    food[p[0]] = d

def num(d, k):
    try: return float(d.get(k, 0) or 0)
    except ValueError: return 0.0

def fmt(v): return ("%.2f" % v).rstrip("0").rstrip(".") if v != int(v) else "%.1f" % v

def set_prop(body, key, value, after=None):
    pat = re.compile(r"(\n(\s*)%s\s*=\s*)[^,\n]*," % re.escape(key))
    if pat.search(body):
        return pat.sub(lambda m: m.group(1) + value + ",", body, count=1)
    anchor = re.search(r"\n(\s*)%s\s*=[^\n]*\n" % re.escape(after), body)
    ind = anchor.group(1)
    return body[:anchor.end()] + "%s%s = %s,\n" % (ind, key, value) + body[anchor.end():]

def edit(path, fn):
    t = open(path, encoding="utf-8").read()
    n = [0]
    def rep(m):
        out = fn(m.group(1), m.group(2))
        if out is None: return m.group(0)
        n[0] += 1
        return "item %s\n    {%s}" % (m.group(1), out)
    t2 = re.sub(r"item (\w+)\n    \{(.*?)\}", rep, t, flags=re.S)
    open(path, "w", encoding="utf-8").write(t2)
    return n[0]

# ---------------------------------------------------------------- canned
def canned(name, body):
    m = re.match(r"HomeCanned(\w+)Open$", name)
    if not m: return None
    src = food.get("Base." + m.group(1))
    if not src: print("  no vanilla food for", name); return body
    for k in ("Calories", "Carbohydrates", "Lipids", "Proteins"):
        body = set_prop(body, k, fmt(4 * num(src, k)), "Proteins")
    er = src.get("EvolvedRecipe", "").replace("|Cooked", "")
    if er: body = set_prop(body, "EvolvedRecipe", er, "Proteins")
    return body

# ---------------------------------------------------------------- dried
DRIED = {"DriedApple": "Apple", "DriedPear": "Pear", "DriedPeach": "Peach", "DriedMango": "Mango",
         "DriedBanana": "Banana", "DriedCherry": "Cherry", "DriedGrapes": "Grapes", "DriedPineapple": "Pineapple"}
def dried(name, body):
    if name not in DRIED: return None
    src = food["Base." + DRIED[name]]
    hunger = round(abs(num(src, "HungerChange")) * 0.75)
    body = set_prop(body, "HungerChange", "-%.1f" % hunger, "DaysTotallyRotten")
    for k in ("Calories", "Carbohydrates", "Lipids", "Proteins"):
        body = set_prop(body, k, fmt(num(src, k)), "HungerChange")
    half = max(1, hunger // 2)
    body = set_prop(body, "EvolvedRecipe", "Cake:%d;PieSweet:%d;FruitSalad:%d;Pancakes:%d;Waffles:%d;Muffin:%d;Oatmeal:%d;Salad:%d"
                    % (hunger, hunger, half, half, half, half, half, half), "Proteins")
    return body

print("canned:", edit(os.path.join(SCRIPTS, "HARMONIE_GardenToPlate_Items.txt"), canned))
print("dried:", edit(os.path.join(SCRIPTS, "HARMONIE_GardenToPlate_Extras.txt"), dried))

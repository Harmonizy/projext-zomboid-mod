#!/usr/bin/env python3
"""HARMONIE - LWS: Tomb's Wardrobe -- generated files.

Reads Tomb's Wardrobe - Alternative (Workshop 3616536783, mod id
TombWardrobeALT) item scripts and its EN / TH item names, and writes the
fashion pieces made from its clothes AND its 26 bags (owner 2026-11-20: the
bags are fashion too -- the look only; real carrying is vanilla bags, which
The Way To Attack upgrades). Nothing of Tomb's mod is copied --
our pieces only name its ClothingItem and icon textures, which the game finds
because TombWardrobeALT is loaded (require= in mod.info).

    python3 tools/gen_lws_tomb.py "<...>/Tomb's Wardrobe - Alternative/42.20/media"

writes
  42/media/scripts/HARMONIE_LWS_tomb_items.txt        two items per piece, module HARMONIE_LWS:
        Tomb_<Type>       worn in lws:<slot>       (hides the real clothes of the slot)
        Tomb_<Type>_Over  worn in lws:<slot>_over  (drawn over them)
  42/media/lua/shared/HARMONIELWSTomb/LWST_Data.lua  the pieces (LWS.addPieces), Tomb's clothes and bags
  42/media/lua/shared/Translate/{EN,TH}/ItemName.json  the pieces' names (Tomb's own EN / TH names)
  TOMB_PIECES.txt (mod folder)                       the list for the Discord gacha: piece id, Tomb type, slot, colours, names
The pieces weigh nothing and protect nothing, like every Life With Style piece.
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(HERE)
ROOT = os.path.join(MOD, "42", "media")
MODULE = "HARMONIE_LWS"
SRC_MODULE = "TombAlternative"

# Tomb's body location -> our fashion slot (Life With Style SLOTS). An
# accessory that would otherwise hide whole real clothes goes to "extra".
SLOT_OF = {
    "base:shoes": "shoes", "base:eyes": "eyes", "base:hat": "hat", "base:mask": "mask", "base:ears": "ears",
    "base:nose": "extra", "base:neck": "neck", "base:necklace": "neck",
    "base:tshirt": "top", "base:tanktop": "top", "base:torso1": "top", "base:underweartop": "top",
    "base:dress": "full", "base:longdress": "full", "base:torso1legs1": "full",
    "base:pants": "bottom", "base:skirt": "bottom", "base:shortsshort": "bottom", "base:underwearbottom": "bottom",
    "twa:twjacket": "outer", "twa:twtrenchcoat": "outer", "base:webbing": "outer", "base:vesttexture": "outer",
    "base:hands": "hands", "twa:twsleeves": "wrist",
    "base:left_ringfinger": "rings", "base:left_middlefinger": "rings", "base:right_ringfinger": "rings",
    "base:right_middlefinger": "rings",
    "base:belt": "waist", "base:fannypackfront": "waist", "base:fannypackback": "waist",
    "base:underwearextra1": "extra", "base:underwearextra2": "extra", "base:thigh_left": "extra", "base:thigh_right": "extra",
    "base:back": "back", "base:satchel": "back", "twa:twduffel": "back", "twa:twduffellow": "back", "twa:twxlcoffin": "back",
    "twa:twharnessunder": "extra", "twa:twharnessover": "extra", "twa:twlegharnessunder": "extra", "twa:twlegharnessover": "extra",
}


def read_items(path):
    text = open(path, encoding="utf-8-sig", errors="replace").read().replace("\r", "")
    items = {}
    for m in re.finditer(r"\bitem\s+(\w+)\s*\{(.*?)\n\s*\}", text, re.S):
        kv = {}
        for k, v in re.findall(r"^\s*(\w+)\s*=\s*(.*?)\s*,?\s*$", m.group(2), re.M):
            kv.setdefault(k, v.rstrip(",").strip())
        items[m.group(1)] = kv
    return items


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", os.path.relpath(path, MOD))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = sys.argv[1]
    clothes = read_items(os.path.join(src, "scripts", "clothing", "tomb_clothingitems.txt"))
    bags = read_items(os.path.join(src, "scripts", "clothing", "tomb_containers.txt"))
    names = {}
    for lang in ("EN", "TH"):
        names[lang] = json.load(open(os.path.join(src, "lua", "shared", "Translate", lang, "ItemName.json"), encoding="utf-8-sig"))

    pieces, unmapped = [], []
    # owner 2026-11-20 (second plan): the bags are fashion too -- every one of
    # the 26 (loose / tight / satchel / low-slung look different); a bag is
    # placed by where it is worn (CanBeEquipped)
    allItems = list(clothes.items()) + [(t, dict(kv, BodyLocation=kv.get("CanBeEquipped", ""), isBag=True)) for t, kv in bags.items()]
    for t, kv in allItems:
        if kv.get("ItemType") not in ("base:clothing", "base:container") or "ClothingItem" not in kv:
            continue
        slot = SLOT_OF.get(kv.get("BodyLocation", ""))
        if not slot:
            unmapped.append((t, kv.get("BodyLocation")))
            continue
        icons = [i.strip() for i in kv.get("IconsForTexture", "").split(";") if i.strip()]
        icon = icons[0] if icons else kv.get("Icon", "")
        pieces.append({"id": "Tomb_" + t, "src": SRC_MODULE + "." + t, "slot": slot, "clothing": kv["ClothingItem"],
                       "icon": icon, "icons": icons, "iconsRaw": kv.get("IconsForTexture", ""),
                       "en": names["EN"].get(SRC_MODULE + "." + t, t), "th": names["TH"].get(SRC_MODULE + "." + t, names["EN"].get(SRC_MODULE + "." + t, t))})
    if unmapped:
        sys.exit("no slot for: %s -- add them to SLOT_OF" % unmapped)

    # item scripts (same stats as gen_lws.py: the picture only)
    out = ["/* GENERATED by tools/gen_lws_tomb.py -- do not edit. */",
           "/* HARMONIE - LWS: Tomb's Wardrobe. Life With Style fashion pieces made from the CLOTHES of",
           "   Tomb's Wardrobe - Alternative (TombWardrobeALT, required). They name its ClothingItem and icons only;",
           "   weigh nothing, warm nothing, protect nothing, change no speed (LWS.plainClothes). */",
           "module %s" % MODULE, "{", "    imports", "    {", "        Base", "    }", ""]
    for p in pieces:
        for suffix, loc in (("", "lws:%s" % p["slot"]), ("_Over", "lws:%s_over" % p["slot"])):
            out += ["    item %s%s" % (p["id"], suffix), "    {",
                    "        DisplayCategory = Fashion,",
                    "        ItemType = base:clothing,",
                    "        Weight = 0,"]
            if len(p["icons"]) > 1:
                out.append("        IconsForTexture = %s," % ";".join(p["icons"]))
            else:
                out.append("        Icon = %s," % p["icon"])
            out += ["        BodyLocation = %s," % loc,
                    "        ClothingItem = %s," % p["clothing"],
                    "        CanHaveHoles = false,",
                    "        ChanceToFall = 0,",
                    "        Insulation = 0,",
                    "        WindResistance = 0,",
                    "        WaterResistance = 0,",
                    "        BiteDefense = 0,",
                    "        ScratchDefense = 0,",
                    "        BulletDefense = 0,",
                    "        RunSpeedModifier = 1.0,",
                    "        CombatSpeedModifier = 1.0,",
                    "        DiscomfortModifier = 0,",
                    "    }", ""]
    out.append("}")
    write(os.path.join(ROOT, "scripts", "HARMONIE_LWS_tomb_items.txt"), "\n".join(out) + "\n")

    # Lua data
    lua = ["-- GENERATED by tools/gen_lws_tomb.py -- do not edit.",
           "-- HARMONIE - LWS: Tomb's Wardrobe: the fashion pieces made from Tomb's clothes, and",
           "-- Tomb's own item types (clothes and bags -> the piece made from them).",
           "require \"HARMONIELifeWithStyle/LWS_Core\"",
           "LWST = LWST or {}",
           "LWST.SRC_MODULE = %s" % lua_str(SRC_MODULE),
           "LWST.PIECES = {"]
    for p in pieces:
        icons = ", ".join(lua_str(i) for i in p["icons"])
        lua.append("    { id = %s, slot = %s, icon = %s, icons = { %s }, tex = %d, src = %s }," % (
            lua_str(p["id"]), lua_str(p["slot"]), lua_str(p["icon"]), icons, max(1, len(p["icons"])), lua_str(p["src"])))
    lua.append("}")
    lua.append("-- Tomb's bags (real containers): fashion pieces too; a real one converts only when empty")
    lua.append("LWST.BAGS = {")
    for t in bags:
        lua.append("    %s," % lua_str(SRC_MODULE + "." + t))
    lua.append("}")
    lua.append("LWST.BAG = {}")
    lua.append("for _, t in ipairs(LWST.BAGS) do LWST.BAG[t] = true end")
    lua.append("if LWS and LWS.addPieces then LWS.addPieces(LWST.PIECES, \"HARMONIE_LWS_Tomb\") end")
    write(os.path.join(ROOT, "lua", "shared", "HARMONIELWSTomb", "LWST_Data.lua"), "\n".join(lua) + "\n")

    for lang, key in (("EN", "en"), ("TH", "th")):
        n = {}
        for p in pieces:
            n["%s.%s" % (MODULE, p["id"])] = p[key]
            n["%s.%s_Over" % (MODULE, p["id"])] = p[key]
        write(os.path.join(ROOT, "lua", "shared", "Translate", lang, "ItemName.json"), json.dumps(n, indent=4, ensure_ascii=False) + "\n")

    rows = ["# HARMONIE - LWS: Tomb's Wardrobe -- fashion pieces for the Discord gacha (GENERATED by tools/gen_lws_tomb.py)",
            "# inbox line: <roll id> TAB <username> TAB piece TAB <piece id or Tomb type>[#colour 1..N]",
            "# piece id\tTomb type\tslot\tcolours\tEnglish\tThai"]
    for p in pieces:
        rows.append("\t".join([p["id"], p["src"], p["slot"], str(max(1, len(p["icons"]))), p["en"], p["th"]]))
    write(os.path.join(MOD, "TOMB_PIECES.txt"), "\n".join(rows) + "\n")
    slots = {}
    for p in pieces:
        slots[p["slot"]] = slots.get(p["slot"], 0) + 1
    print("pieces:", len(pieces), "colours:", sum(max(1, len(p["icons"])) for p in pieces), "bags:", len(bags), "by slot:", slots)


if __name__ == "__main__":
    main()

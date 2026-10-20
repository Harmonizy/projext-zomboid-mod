#!/usr/bin/env python3
"""HARMONIE - Life With Style: generated files (run after editing SLOTS / CATALOG).

One source for the fashion slots and the catalog. Writes:
  42/media/registries.lua                                  the lws:<slot> and lws:<slot>_over body locations
  42/media/scripts/HARMONIE_LWS_items.txt                  two items per fashion piece:
        <Id>       worn in lws:<slot>       -- hides the vanilla clothes of that slot (BodyLocations.setHideModel)
        <Id>_Over  worn in lws:<slot>_over  -- drawn over them ("show my real clothes" in the window)
  42/media/lua/shared/HARMONIELifeWithStyle/LWS_Data.lua   slots, what each hides, the catalog
  42/media/lua/shared/Translate/{EN,TH}/ItemName.json      the pieces' names
The pieces weigh nothing and protect nothing: only the picture.
Phase 1 test pieces reuse vanilla clothing models (ClothingItem = the vanilla one).
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(HERE), "42", "media")
MODULE = "HARMONIE_LWS"

# slot id, vanilla body locations it hides (base:<x>), window order = list order
SLOTS = [
    ("hat",    ["hat", "fullhat", "jackethat", "jackethat_bulky", "sweaterhat", "fullsuithead"]),
    ("mask",   ["mask", "maskeyes", "maskfull"]),
    ("eyes",   ["eyes", "lefteye", "righteye"]),
    ("ears",   ["ears", "eartop"]),
    ("neck",   ["necklace", "necklace_long", "neck", "neck_texture", "scarf", "gorget"]),
    ("top",    ["tshirt", "shirt", "shortsleeveshirt", "tanktop", "sweater", "jersey"]),
    ("outer",  ["jacket", "jacketsuit", "jacket_bulky", "jacket_down", "torsoextra", "torsoextravest",
                "torsoextravestbullet", "vesttexture", "cuirass", "fulltop", "shoulderpadleft", "shoulderpadright",
                "sportshoulderpad", "sportshoulderpadontop", "webbing", "ammostrap", "forearm_left", "forearm_right",
                "elbow_left", "elbow_right"]),
    ("full",   ["dress", "longdress", "boilersuit", "fullsuit", "bathrobe",
                "tshirt", "shirt", "shortsleeveshirt", "tanktop", "sweater", "jersey",
                "pants", "pants_skinny", "shortpants", "shortsshort", "skirt", "longskirt", "pantsextra"]),
    ("bottom", ["pants", "pants_skinny", "shortpants", "shortsshort", "skirt", "longskirt", "pantsextra",
                "codpiece", "knee_left", "knee_right", "thigh_left", "thigh_right", "calf_left", "calf_right",
                "calf_left_texture", "calf_right_texture"]),
    ("hands",  ["hands", "handsleft", "handsright"]),
    ("shoes",  ["shoes", "socks", "gaiter_left", "gaiter_right"]),
    ("wrist",  ["leftwrist", "rightwrist"]),
    ("rings",  ["left_ringfinger", "left_middlefinger", "right_ringfinger", "right_middlefinger"]),
    ("waist",  ["belt", "beltextra", "fannypackfront", "fannypackback"]),
    ("back",   ["back", "satchel"]),
    ("makeup", ["makeup_fullface", "makeup_eyesshadow", "makeup_eyes", "makeup_lips"]),
    ("tail",   ["tail"]),
    ("extra",  []),
]

SLOT_NAMES = {  # EN, TH
    "hat": ("Hat", "หมวก"), "mask": ("Mask", "หน้ากาก"), "eyes": ("Glasses", "แว่นตา"), "ears": ("Ears", "หู / ต่างหู"),
    "neck": ("Neck", "คอ / สร้อย"), "top": ("Top", "เสื้อตัวใน"), "outer": ("Outerwear", "เสื้อนอก"),
    "full": ("Full outfit", "ชุดเต็มตัว"), "bottom": ("Bottoms", "กางเกง / กระโปรง"), "hands": ("Gloves", "ถุงมือ"),
    "shoes": ("Shoes", "รองเท้า"), "wrist": ("Wrists", "ข้อมือ"), "rings": ("Rings", "แหวน"),
    "waist": ("Waist", "เข็มขัด / เอว"), "back": ("Back", "หลัง / กระเป๋า"), "makeup": ("Make-up", "แต่งหน้า"),
    "tail": ("Tail", "หาง"), "extra": ("Special", "ของพิเศษ"),
}

# id (our item), slot, vanilla ClothingItem, icon, EN name, TH name
CATALOG = [
    ("Test_BunnyEarsWhite", "hat", "Hat_BunnyEarsWhite", "RabbitearsWhite", "Bunny Ears (white)", "หูกระต่าย (ขาว)"),
    ("Test_Bandana", "hat", "Hat_Bandana", "BandanaBlack", "Bandana", "ผ้าโพกหัว"),
    ("Test_BalaclavaOpen", "mask", "Hat_BalaclavaFace", "BalaclavaOpen", "Open Balaclava", "โม่งเปิดหน้า"),
    ("Test_MaskDevil", "mask", "Hat_HalloweenMaskDevil", "Mask_Devil", "Devil Mask", "หน้ากากปีศาจ"),
    ("Test_Aviators", "eyes", "Glasses_Aviators", "GlassesAviator", "Aviator Glasses", "แว่นนักบิน"),
    ("Test_EarringsGold", "ears", "Earring_LoopLrg_Gold_Both", "Earring_LoopLrg_Gold", "Gold Hoop Earrings", "ต่างหูห่วงทอง"),
    ("Test_ScarfWhite", "neck", "Scarf_White", "ScarfGeneric", "White Scarf", "ผ้าพันคอสีขาว"),
    ("Test_DogTags", "neck", "Necklace_DogTag", "Necklace_Dogtags", "Dog Tags", "ป้ายทหาร"),
    ("Test_SweaterWhite", "top", "Jumper_RoundNeck", "SweaterWhite", "Round-neck Sweater", "เสื้อสเวตเตอร์คอกลม"),
    ("Test_TshirtUrban", "top", "Tshirt_CamoUrban", "TShirt_CamoGrey", "Urban Camo T-shirt", "เสื้อยืดลายพราง"),
    ("Test_VarsityJacket", "outer", "Jacket_Varsity", "JacketVarsity_KY", "Varsity Jacket", "แจ็กเก็ตวาร์ซิตี้"),
    ("Test_ApronBlack", "outer", "Apron_Black", "ApronBlack", "Black Apron", "ผ้ากันเปื้อนสีดำ"),
    ("Test_LongDress", "full", "Dress_Long", "DressLongWhite", "Long Dress", "ชุดเดรสยาว"),
    ("Test_PrisonSuit", "full", "Boilersuit_Prisoner", "JumpsuitPrisonOrange", "Prisoner Jumpsuit", "ชุดนักโทษ"),
    ("Test_LeatherPants", "bottom", "Trousers_LeatherBlack", "Trousers_Leather", "Leather Pants", "กางเกงหนัง"),
    ("Test_DeerSkirt", "bottom", "Skirt_Knees_DeerHide", "SkirtKnee_Deerhide", "Deer Hide Skirt", "กระโปรงหนังกวาง"),
    ("Test_FingerlessBlack", "hands", "Gloves_FingerlessLeatherGloves_Black", "GlovesFingerless_Black", "Fingerless Leather Gloves", "ถุงมือหนังตัดนิ้ว"),
    ("Test_HikingBoots", "shoes", "Shoes_HikingBoots", "BootsHiking", "Hiking Boots", "รองเท้าเดินป่า"),
    ("Test_GoldBangle", "wrist", "Bracelet_BangleLeftGold", "Bracelet_Bangle", "Gold Bangle", "กำไลทอง"),
    ("Test_RubyRing", "rings", "Ring_Right_RingFinger_GoldRuby", "Ring_GoldRuby", "Gold Ruby Ring", "แหวนทองทับทิม"),
    ("Test_Belt", "waist", "Belt", "Belt", "Leather Belt", "เข็มขัดหนัง"),
    ("Test_SchoolBag", "back", "Bag_SchoolBag", "Backpack_Black", "Small Backpack (look only)", "กระเป๋าเป้ใบเล็ก (แค่ภาพ)"),
    ("Test_LipsRed", "makeup", "MakeUp_LipsRed", "LWS_Makeup", "Red Lipstick", "ลิปสติกสีแดง"),
    ("Test_SpiffoTail", "tail", "SpiffoTail", "SpiffoTail", "Spiffo Tail", "หางสปิฟโฟ"),
    ("Test_BunnyEarsBlack", "extra", "Hat_BunnyEarsBlack", "RabbitearsBlack", "Bunny Ears (black, special)", "หูกระต่าย (ดำ ช่องพิเศษ)"),
]


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", os.path.relpath(path, os.path.dirname(HERE)))


def main():
    slot_ids = [s for s, _ in SLOTS]
    for _, slot, *_ in CATALOG:
        assert slot in slot_ids, slot
    # registries.lua -- read by the game before everything else
    reg = ["-- GENERATED by tools/gen_lws.py -- do not edit.",
           "-- HARMONIE - Life With Style: one body location per fashion slot, and an _over twin",
           "LWS_Registries = LWS_Registries or {}",
           "LWS_Registries.bodylocations = {"]
    for s in slot_ids:
        reg.append('    %s = ItemBodyLocation.register("lws:%s"),' % (s, s))
        reg.append('    %s_over = ItemBodyLocation.register("lws:%s_over"),' % (s, s))
    reg.append("}")
    write(os.path.join(ROOT, "registries.lua"), "\n".join(reg) + "\n")

    # item scripts
    out = ["/* GENERATED by tools/gen_lws.py -- do not edit. */",
           "/* HARMONIE - Life With Style: fashion pieces. They only exist while worn (the wardrobe lives",
           "   on the server), weigh nothing and protect nothing -- the picture only. */",
           "module %s" % MODULE, "{", "    imports", "    {", "        Base", "    }", ""]
    for cid, slot, clothing, icon, _, _ in CATALOG:
        for suffix, loc in (("", "lws:%s" % slot), ("_Over", "lws:%s_over" % slot)):
            out += ["    item %s%s" % (cid, suffix), "    {",
                    "        DisplayCategory = Fashion,",
                    "        ItemType = base:clothing,",
                    "        Weight = 0,",
                    "        Icon = %s," % icon,
                    "        BodyLocation = %s," % loc,
                    "        ClothingItem = %s," % clothing,
                    "        CanHaveHoles = false,",
                    "        ChanceToFall = 0,",
                    "        Insulation = 0,",
                    "        WindResistance = 0,",
                    "        WaterResistance = 0,",
                    "    }", ""]
    out.append("}")
    write(os.path.join(ROOT, "scripts", "HARMONIE_LWS_items.txt"), "\n".join(out) + "\n")

    # Lua data
    lua = ["-- GENERATED by tools/gen_lws.py -- do not edit.",
           "-- HARMONIE - Life With Style: the fashion slots (window order), the vanilla body",
           "-- locations each one hides, and the catalog of pieces.",
           "LWS = LWS or {}",
           "LWS.MODULE = %s" % lua_str(MODULE),
           "LWS.SLOTS = {"]
    for s, hides in SLOTS:
        lua.append("    { id = %s, hides = { %s } }," % (lua_str(s), ", ".join(lua_str(h) for h in hides)))
    lua.append("}")
    lua.append("LWS.CATALOG = {")
    for cid, slot, clothing, icon, _, _ in CATALOG:
        lua.append("    { id = %s, slot = %s, icon = %s }," % (lua_str(cid), lua_str(slot), lua_str(icon)))
    lua.append("}")
    write(os.path.join(ROOT, "lua", "shared", "HARMONIELifeWithStyle", "LWS_Data.lua"), "\n".join(lua) + "\n")

    # item names (both variants share a name) + slot names
    for i, lang in enumerate(("EN", "TH")):
        names = {}
        for cid, slot, clothing, icon, en, th in CATALOG:
            n = (en, th)[i]
            names["%s.%s" % (MODULE, cid)] = n
            names["%s.%s_Over" % (MODULE, cid)] = n
        write(os.path.join(ROOT, "lua", "shared", "Translate", lang, "ItemName.json"),
              json.dumps(names, indent=4, ensure_ascii=False) + "\n")
    # slot names go to IG_UI.json together with the window texts (texts.py), printed for reference
    print("slots:", len(SLOTS), "pieces:", len(CATALOG), "items:", 2 * len(CATALOG))


if __name__ == "__main__":
    main()

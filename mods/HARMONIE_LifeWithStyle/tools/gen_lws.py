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
    ("pet",    []),   # not a body location: the pet walks beside the owner (PETS below)
]
# slots that are not worn on the body: no body location, no item
NON_BODY = {"pet"}

SLOT_NAMES = {  # EN, TH
    "hat": ("Hat", "หมวก"), "mask": ("Mask", "หน้ากาก"), "eyes": ("Glasses", "แว่นตา"), "ears": ("Ears", "หู / ต่างหู"),
    "neck": ("Neck", "คอ / สร้อย"), "top": ("Top", "เสื้อตัวใน"), "outer": ("Outerwear", "เสื้อนอก"),
    "full": ("Full outfit", "ชุดเต็มตัว"), "bottom": ("Bottoms", "กางเกง / กระโปรง"), "hands": ("Gloves", "ถุงมือ"),
    "shoes": ("Shoes", "รองเท้า"), "wrist": ("Wrists", "ข้อมือ"), "rings": ("Rings", "แหวน"),
    "waist": ("Waist", "เข็มขัด / เอว"), "back": ("Back", "หลัง / กระเป๋า"), "makeup": ("Make-up", "แต่งหน้า"),
    "tail": ("Tail", "หาง"), "extra": ("Special", "ของพิเศษ"), "pet": ("Pet", "สัตว์เลี้ยง"),
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


# pets (owner, 2026-10-23): Companion Dogs' dogs and its "CD: Cats" add-on's cats,
# used with the author's permission (tools/import_pets.py copies the assets,
# CREDITS_PETS.txt). One adult animal type per dog breed and one for all cats
# (a coat = a breed of it), all ours ("lwspet_*"), never in the world on their own.
#   id, kind (dog / cat: voice, animations), animal type, breed (in the type),
#   model / texture / icon = our asset names (LWSPet_<name>), their files, size, EN, TH
def _dog(pid, breed, their_mesh, their_texture, their_portrait, size, en, th):
    return {"id": pid, "kind": "dog", "type": "lwspet_" + breed.lower(), "breed": breed,
            "model": breed, "texture": breed, "icon": breed, "src": "dogs",
            "their_mesh": their_mesh, "their_texture": their_texture, "their_portrait": their_portrait,
            "size": size, "en": en, "th": th}


def _cat(coat, their_texture, en, th):
    return {"id": "Pet_Cat" + coat, "kind": "cat", "type": "lwspet_cat", "breed": coat,
            "model": "Cat", "texture": "Cat_" + coat, "icon": "Cat_" + coat, "src": "cats",
            "their_mesh": "Cat_Body", "their_texture": their_texture, "their_portrait": "CDPortrait_cat",
            "size": 2.9, "en": en, "th": th}


PETS = [
    _dog("Pet_Caramelo", "Caramelo", "Caramelo_Body", "Caramelo", "CDPortrait_caramelo", 1.45, "Caramelo (street dog)", "คาราเมโล (หมาจร)"),
    _dog("Pet_GermanShepherd", "GermanShepherd", "GermanShepherd_Body", "GermanShepherd", "CDPortrait_germanshepherd", 2.05, "German Shepherd", "เยอรมันเชพเพิร์ด"),
    _dog("Pet_Retriever", "Retriever", "Retriever_Body", "RetrieverPoly", "CDPortrait_retriever", 1.85, "Golden Retriever", "โกลเด้นรีทรีฟเวอร์"),
    _dog("Pet_Husky", "Husky", "Husky_Body", "Husky", "CDPortrait_husky", 1.85, "Husky", "ไซบีเรียนฮัสกี้"),
    _dog("Pet_BorderCollie", "BorderCollie", "BorderCollie_Body", "BorderCollie", "CDPortrait_bordercollie", 1.8, "Border Collie", "บอร์เดอร์คอลลี่"),
    _cat("Black", "Cat", "Black Cat", "แมวดำ"),
    _cat("White", "Cat_White", "White Cat", "แมวขาว"),
    _cat("Orange", "Cat_Orange", "Orange Cat", "แมวส้ม"),
    _cat("Calico", "Cat_Calico", "Calico Cat", "แมวสามสี"),
    _cat("Tuxedo", "Cat_Tuxedo", "Tuxedo Cat", "แมวทักซิโด้ (ขาวดำ)"),
    _cat("BrownTabby", "Cat_BrownTabby", "Brown Tabby Cat", "แมวลายสลิดน้ำตาล"),
    _cat("GreyTabby", "Cat_GreyTabby", "Grey Tabby Cat", "แมวลายสลิดเทา"),
    _cat("OrangeTabby", "Cat_OrangeTabby", "Orange Tabby Cat", "แมวส้มลายสลิด"),
    _cat("Barley", "Cat_Barley", "Barley Cat", "แมวสีข้าวบาร์เลย์"),
    _cat("Cow", "Cat_Cow", "Cow Cat", "แมวลายวัว"),
    _cat("Tortie", "Cat_Tortie", "Tortoiseshell Cat", "แมวกระดองเต่า"),
]
# per model: the head attachment (their numbers)
PET_MODELS = {"Cat": "-0.0060 0.1619 0.0491"}
PET_HEAD_DEFAULT = "-0.0106 0.2881 0.0874"


def pet_definitions():
    """shared/Definitions/animal/LWS_PetDefinitions.lua: the AnimalDefinitions of our pets
    (the fields Companion Dogs' tested definitions use; animset = vanilla raccoon)"""
    L = ["-- GENERATED by tools/gen_lws.py -- do not edit.",
         "-- HARMONIE - Life With Style: the pets' animal types. One adult per dog breed, one for",
         "-- the cats (a coat = a breed), our own names (lwspet_*) so Companion Dogs can run on the",
         "-- same server. A pet never fights, never runs away, never starves the vanilla way",
         "-- (LWS_Pets.lua keeps it).",
         "AnimalDefinitions = AnimalDefinitions or {}",
         "AnimalDefinitions.stages = AnimalDefinitions.stages or {}",
         "AnimalDefinitions.breeds = AnimalDefinitions.breeds or {}",
         "AnimalDefinitions.genome = AnimalDefinitions.genome or {}",
         "AnimalDefinitions.animals = AnimalDefinitions.animals or {}",
         "",
         "local genes = {}",
         "for _, g in ipairs({ \"maxSize\", \"meatRatio\", \"maxWeight\", \"lifeExpectancy\", \"resistance\", \"strength\",",
         "        \"hungerResistance\", \"thirstResistance\", \"aggressiveness\", \"ageToGrow\", \"fertility\", \"stress\" }) do genes[g] = g end",
         "AnimalDefinitions.genome[\"lwspet\"] = AnimalDefinitions.genome[\"lwspet\"] or { genes = genes }",
         "",
         "local SOUNDS = {}",
         "for kind, pain in pairs({ dog = \"LWSPetWhine\", cat = \"LWSPetHiss\" }) do",
         "    SOUNDS[kind] = {",
         "        pain = { name = pain, slot = \"voice\", priority = 50 },",
         "        death = { name = pain, slot = \"voice\", priority = 100 },",
         "        fallover = { name = \"AnimalFoleyRaccoonBodyfall\" },",
         "        runloop = { name = \"AnimalFootstepsRaccoonRun\", slot = \"runloop\" },",
         "        walkBack = { name = \"AnimalFootstepsRaccoonWalkBack\" },",
         "        walkFront = { name = \"AnimalFootstepsRaccoonWalkFront\" },",
         "    }",
         "end",
         "",
         "-- coats = { { breed, texture, icon }, ... }",
         "local function pet(atype, kind, model, size, coats)",
         "    AnimalDefinitions.stages[atype] = { stages = { [atype] = { ageToGrow = 100000 } } }",
         "    local breeds = {}",
         "    for _, c in ipairs(coats) do",
         "        local icon = \"Item_LWSPet_\" .. c[3]",
         "        breeds[c[1]] = {",
         "            name = c[1], texture = \"LWSPet_\" .. c[2], textureMale = \"LWSPet_\" .. c[2],",
         "            rottenTexture = \"Raccoon_Rotting\",",
         "            invIconMale = icon, invIconFemale = icon, invIconBaby = icon,",
         "            invIconMaleDead = icon, invIconFemaleDead = icon, invIconBabyDead = icon,",
         "            invIconMaleSkel = \"Item_Skeleton_Raccoon\", invIconFemaleSkel = \"Item_Skeleton_Raccoon\", invIconBabySkel = \"Item_Skeleton_Raccoon\",",
         "            sounds = SOUNDS[kind],",
         "        }",
         "    end",
         "    AnimalDefinitions.breeds[atype] = { breeds = breeds }",
         "    AnimalDefinitions.animals[atype] = {",
         "        bodyModel = \"LWSPet_\" .. model, bodyModelSkel = \"Raccoon_Skeleton\", bodyModelSkelNoHead = \"Raccoon_Skeleton_NoHead\",",
         "        textureSkeleton = \"RaccoonSkeleton\", textureSkeletonBloody = \"RaccoonSkeleton_Butchered\",",
         "        animset = \"raccoon\",           -- the meshes are rigged to it (a renamed animset does not load)",
         "        feedByHandAnim = \"AnimalLureLow\",",
         "        group = \"lwspet\", male = true, wild = false,",
         "        alwaysFleeHumans = false, fleeHumansMod = 0, fleeZombies = false, canBeAlerted = false,",
         "        attackBack = false, dontAttackOtherMale = true,  -- owner: a pet never attacks",
         "        canBeDomesticated = true, canBePet = true, canBePicked = false, canClimbStairs = true, canClimbFences = false,",
         "        canBeKilledWithoutWeapon = false, collidable = false,",
         "        healthLossMultiplier = 0, hungerMultiplier = 0.0001, thirstMultiplier = 0.0001, thirstHungerTrigger = 0,",
         "        idleTypeNbr = 2, idleEmoteChance = 450, sitRandomly = false, turnDelta = 0.95,",
         "        animalSize = 0.25,               -- the path's arrival margin (0 = never arrives)",
         "        addTrackingXp = false, corpseSize = 0, dung = \"Dung_Raccoon\",",
         "        shadoww = 0.3, shadowfm = 0.5, shadowbm = 0.5,",
         "        minSize = size, maxSize = size, minWeight = 12, maxWeight = 12, wanderMul = 600,",
         "        minAge = 3 * 30, maxAgeGeriatric = 100000, baseEncumbrance = 20, trailerBaseSize = 50, minEnclosureSize = 40,",
         "        wildFleeTimeUntilDeadTimer = 1000000,",
         "        breeds = breeds, stages = AnimalDefinitions.stages[atype].stages,",
         "        genes = AnimalDefinitions.genome[\"lwspet\"].genes,",
         "    }",
         "end",
         ""]
    types = []
    for p in PETS:
        if p["type"] not in [t["type"] for t in types]:
            types.append({"type": p["type"], "kind": p["kind"], "model": p["model"], "size": p["size"], "coats": []})
        t = [t for t in types if t["type"] == p["type"]][0]
        t["coats"].append("{ %s, %s, %s }" % (lua_str(p["breed"]), lua_str(p["texture"]), lua_str(p["icon"])))
    for t in types:
        L.append("pet(%s, %s, %s, %s, {" % (lua_str(t["type"]), lua_str(t["kind"]), lua_str(t["model"]), t["size"]))
        for c in t["coats"]:
            L.append("    %s," % c)
        L.append("})")
    return "\n".join(L) + "\n"


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
        if s in NON_BODY:
            continue
        reg.append('    %s = ItemBodyLocation.register("lws:%s"),' % (s, s))
        reg.append('    %s_over = ItemBodyLocation.register("lws:%s_over"),' % (s, s))
    # the gacha Guardian Capsule's invisible armour (scripts/HARMONIE_LWS_gacha.txt)
    reg.append('    gacha_guardian = ItemBodyLocation.register("lws:gacha_guardian"),')
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
        extra = ", body = false" if s in NON_BODY else ""
        lua.append("    { id = %s, hides = { %s }%s }," % (lua_str(s), ", ".join(lua_str(h) for h in hides), extra))
    lua.append("}")
    lua.append("LWS.CATALOG = {")
    for cid, slot, clothing, icon, _, _ in CATALOG:
        lua.append("    { id = %s, slot = %s, icon = %s }," % (lua_str(cid), lua_str(slot), lua_str(icon)))
    for p in PETS:
        lua.append("    { id = %s, slot = \"pet\", icon = %s, pet = { type = %s, breed = %s, kind = %s } }," % (
            lua_str(p["id"]), lua_str("LWSPet_" + p["icon"]), lua_str(p["type"]), lua_str(p["breed"]), lua_str(p["kind"])))
    lua.append("}")
    write(os.path.join(ROOT, "lua", "shared", "HARMONIELifeWithStyle", "LWS_Data.lua"), "\n".join(lua) + "\n")

    # item names (both variants share a name) + slot names
    for i, lang in enumerate(("EN", "TH")):
        names = {}
        for cid, slot, clothing, icon, en, th in CATALOG:
            n = (en, th)[i]
            names["%s.%s" % (MODULE, cid)] = n
            names["%s.%s_Over" % (MODULE, cid)] = n
        # the gacha items' item types (tools/gen_gacha.py writes their scripts)
        from gen_gacha import ITEMS as GACHA_ITEMS, TEXTS as GACHA_TEXTS
        for g in GACHA_ITEMS:
            names["HARMONIE_LWSG.%s" % g["id"]] = GACHA_TEXTS["IGUI_LWSG_Name_" + g["id"]][i]
        write(os.path.join(ROOT, "lua", "shared", "Translate", lang, "ItemName.json"),
              json.dumps(names, indent=4, ensure_ascii=False) + "\n")
    write(os.path.join(ROOT, "lua", "shared", "Definitions", "animal", "LWS_PetDefinitions.lua"), pet_definitions())
    # slot names go to IG_UI.json together with the window texts (texts.py), printed for reference
    print("slots:", len(SLOTS), "pieces:", len(CATALOG), "items:", 2 * len(CATALOG), "pets:", len(PETS))


if __name__ == "__main__":
    main()

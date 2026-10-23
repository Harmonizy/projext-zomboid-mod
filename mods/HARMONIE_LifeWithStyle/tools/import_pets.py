#!/usr/bin/env python3
"""HARMONIE - Life With Style: copy the pet assets of Companion Dogs (and of its
"CD: Cats" add-on) into our mod, under our names.

Owner, 2026-10-23: the author allowed us to use the model assets (credit in
42/CREDITS_PETS.txt). Only assets are taken -- the code is ours. Everything
gets an LWSPet_ name so the mods can run on one server.

    python3 tools/import_pets.py --dogs <unzipped>/mods/CompanionDogs/42 --cats <unzipped>/mods/CompanionCat/42

Either source may be left out (its files stay as they are); the scripts are
always written for every pet in gen_lws.PETS.

Writes: models_X/Skinned/LWSPet_<model>.glb, textures/Body/LWSPet_<texture>.png,
textures/Item_LWSPet_<icon>.png (icon, from the portrait; a cat coat gets the
portrait painted in its fur), sound/LWSPet_*.ogg,
scripts/HARMONIE_LWS_pets_models.txt, scripts/HARMONIE_LWS_pets_sounds.txt,
AnimSets/raccoon/<state>/lws*.xml (their animation nodes, see ANIMS).

The animation nodes (owner, 2026-10-23: "ใช้อนิเมชั่นของม็อดอ้างอิง") are added
to the vanilla raccoon animset -- new files only, never a vanilla file
replaced (Companion Dogs replaces defaultPathfind / runPathfind, which also
changes real raccoons). Every node of ours needs a variable only our pets
have: lwsPet (walk / run while pathing), lwsNetGait (a remote copy moving,
set by the client), lwsIdle2 / lwsIdle3 / lwsRest / lwsSniff / lwsEat
(LWS_Pets.lua), and for cats only lwsSit / lwsSitIn / lwsSitOut / lwsSitGroom /
lwsSitGroom2 (those clips exist only in the cat model). Their attack nodes
are left out: a pet never attacks.
"""
import argparse, os, re, shutil, sys, uuid
from PIL import Image, ImageChops, ImageFilter, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(os.path.dirname(HERE), "42", "media")
sys.path.insert(0, HERE)
from gen_lws import PETS, PET_MODELS, PET_HEAD_DEFAULT

# their file -> ours
SOUNDS = {
    "CDDogBark1": "LWSPet_Bark1", "CDDogBark2": "LWSPet_Bark2", "CDDogBark3": "LWSPet_Bark3",
    "CDDogWhine1": "LWSPet_Whine1", "CDDogWhine2": "LWSPet_Whine2",
    "CDDogIdle1": "LWSPet_Idle1", "CDDogIdle2": "LWSPet_Idle2",
    "CDDogEat1": "LWSPet_Eat1",
}
CAT_SOUNDS = {
    "CDCatMeow1": "LWSPet_CatMeow1", "CDCatHiss1": "LWSPet_CatHiss1",
    "CDCatPurr1": "LWSPet_CatPurr1", "CDCatPurr2": "LWSPet_CatPurr2", "CDCatPurr3": "LWSPet_CatPurr3",
}
CAT_ANIMS = [
    ("idle", "cdSit", "idle", "lwsSit", None),
    ("idle", "cdSitIn", "idle", "lwsSitIn", None),
    ("idle", "cdSitOut", "idle", "lwsSitOut", None),
    ("idle", "cdSitGroom", "idle", "lwsSitGroom", None),
    ("idle", "cdSitGroom2", "idle", "lwsSitGroom2", None),
]


# (their state folder, their file, our state folder, our file, extra lwsPet condition + priority)
ANIMS = [
    ("idle", "cdIdle2", "idle", "lwsIdle2", None),
    ("idle", "cdIdle3", "idle", "lwsIdle3", None),
    ("idle", "cdRest", "idle", "lwsRest", None),
    ("idle", "cdSniff", "idle", "lwsSniff", None),
    ("idle", "cdEat", "idle", "lwsEat", None),
    ("idle", "cdNetWalk", "idle", "lwsNetWalk", None),
    ("idle", "cdNetRun", "idle", "lwsNetRun", None),
    ("walk", "cdNetWalk", "walk", "lwsNetWalk", None),
    ("walk", "cdNetRun", "walk", "lwsNetRun", None),
    ("pathfind", "defaultPathfind", "pathfind", "lwsPathWalk", 10),
    ("pathfind", "runPathfind", "pathfind", "lwsPathRun", 11),
]
# their variable / node names -> ours
ANIM_NAMES = [("cdWalkScale", "lwsWalkScale"), ("cdRunScale", "lwsRunScale"), ("cdNetGait", "lwsNetGait"),
              ("cdNetWalk", "lwsNetWalk"), ("cdNetRun", "lwsNetRun"), ("cdIdle2", "lwsIdle2"), ("cdIdle3", "lwsIdle3"),
              ("cdRest", "lwsRest"), ("cdSniff", "lwsSniff"), ("cdEat", "lwsEat"),
              ("cdSitGroom2", "lwsSitGroom2"), ("cdSitGroom", "lwsSitGroom"), ("cdSitIn", "lwsSitIn"),
              ("cdSitOut", "lwsSitOut"), ("cdSit", "lwsSit"),
              ("<m_Name>defaultPathfind<", "<m_Name>lwsPathWalk<"), ("<m_Name>runPathfind<", "<m_Name>lwsPathRun<")]


def anim(src_media, theirs_dir, theirs, ours_dir, ours, priority):
    with open(os.path.join(src_media, "AnimSets", "raccoon", theirs_dir, theirs + ".xml"), encoding="utf-8") as f:
        x = f.read()
    x = re.sub(r"<!--.*?-->\s*", "", x, flags=re.S)   # their notes are about their code
    for a, b in ANIM_NAMES:
        x = x.replace(a, b)
    n = [0]
    def guid(_m):
        n[0] += 1
        return 'x_name="%s"' % uuid.uuid5(uuid.NAMESPACE_URL, "lws-pet/%s/%s/%d" % (ours_dir, ours, n[0]))
    x = re.sub(r'x_name="[^"]*"', guid, x)
    if priority is not None:
        x = re.sub(r"\s*<m_ConditionPriority>\d+</m_ConditionPriority>", "", x)
        x = x.replace("</m_Name>", "</m_Name>\n\t<m_ConditionPriority>%d</m_ConditionPriority>" % priority, 1)
        cond = ('\t<m_Conditions x_name="%s">\n\t\t<m_Name>lwsPet</m_Name>\n\t\t<m_Type>BOOL</m_Type>\n'
                '\t\t<m_Value>true</m_Value>\n\t</m_Conditions>\n') % uuid.uuid5(uuid.NAMESPACE_URL, "lws-pet/%s/%s/pet" % (ours_dir, ours))
        i = x.index("\t<m_Conditions")
        x = x[:i] + cond + x[i:]
    assert not re.search(r">cd[A-Z]", x), (ours, x)   # none of their names left
    dst = os.path.join(MEDIA, "AnimSets", "raccoon", ours_dir, ours + ".xml")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    head = "<!-- GENERATED by tools/import_pets.py from %s' %s/%s.xml (used with permission) -->\n" % (
        "CD: Cats" if theirs.startswith("cdSit") else "Companion Dogs", theirs_dir, theirs)
    x = x.replace("<animNode>", head + "<animNode>", 1)
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(x)
    print("anim", os.path.relpath(dst, MEDIA))


def copy(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)
    print("copied", os.path.relpath(dst, MEDIA))


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", os.path.relpath(path, MEDIA))


def cat_icon(portrait, coat_texture):
    """the cat portrait (a black cat) with this coat's fur painted in, its shading and eyes kept"""
    por = Image.open(portrait).convert("RGBA").resize((256, 256), Image.LANCZOS)
    if coat_texture is None:
        return por.resize((128, 128), Image.LANCZOS)
    alpha = por.split()[3]
    shade = ImageOps.autocontrast(por.convert("L"), cutoff=1).point(lambda v: int(170 + 85 * v / 255))
    t = Image.open(coat_texture).convert("RGB")
    w, h = t.size
    fur = t.crop((int(w * .22), int(h * .18), int(w * .62), int(h * .58))).resize((256, 256), Image.LANCZOS)
    lit = ImageChops.multiply(fur.filter(ImageFilter.GaussianBlur(1.2)), Image.merge("RGB", [shade] * 3))
    out = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    out.paste(lit, (0, 0), alpha)
    px, po = por.load(), out.load()
    for y in range(256):
        for x in range(256):
            r, g, b, a = px[x, y]
            if a > 0 and g > 90 and r > 70 and b < 90:   # the eyes
                po[x, y] = (r, g, b, a)
    return out.resize((128, 128), Image.LANCZOS)


def main(dogs, cats):
    srcs = {"dogs": dogs and os.path.join(dogs, "media"), "cats": cats and os.path.join(cats, "media")}
    models = ["/* GENERATED by tools/import_pets.py -- do not edit.",
              "   Life With Style pets: Companion Dogs' dog meshes and CD: Cats' cat mesh (used with permission,",
              "   CREDITS_PETS.txt). They are rigged to the vanilla raccoon skeleton and keep their own animations. */",
              "module Base", "{"]
    done = set()
    for p in PETS:
        sm = srcs[p["src"]]
        if sm:
            if p["model"] not in done:
                copy(os.path.join(sm, "models_X", "Skinned", p["their_mesh"] + ".glb"),
                     os.path.join(MEDIA, "models_X", "Skinned", "LWSPet_%s.glb" % p["model"]))
            copy(os.path.join(sm, "textures", "Body", p["their_texture"] + ".png"),
                 os.path.join(MEDIA, "textures", "Body", "LWSPet_%s.png" % p["texture"]))
            portrait = os.path.join(sm, "textures", p["their_portrait"] + ".png")
            if p["kind"] == "cat":
                icon = cat_icon(portrait, None if p["their_texture"] == "Cat" else os.path.join(sm, "textures", "Body", p["their_texture"] + ".png"))
            else:
                icon = Image.open(portrait).convert("RGBA").resize((128, 128), Image.LANCZOS)
            icon.save(os.path.join(MEDIA, "textures", "Item_LWSPet_%s.png" % p["icon"]))
            print("icon", "Item_LWSPet_%s.png" % p["icon"])
        if p["model"] in done:
            continue
        done.add(p["model"])
        m = p["model"]
        models += ["    model LWSPet_%s" % m, "    {",
                   "        mesh = Skinned/LWSPet_%s," % m,
                   "        shader = animalEffect,",
                   "        static = false,",
                   "        animationsMesh = LWSPet_%sAnim," % m,
                   "        attachment head",
                   "        {",
                   "            offset = %s," % PET_MODELS.get(m, PET_HEAD_DEFAULT),
                   "            rotate = -179.0 -5.0 95.0,",
                   "            bone = Dummy01,",
                   "        }",
                   "    }", "",
                   "    animationsMesh LWSPet_%sAnim" % m, "    {",
                   "        meshFile = Skinned/LWSPet_%s," % m,
                   "        keepMeshAnimations = true,",
                   "    }", ""]
    models.append("}")
    write(os.path.join(MEDIA, "scripts", "HARMONIE_LWS_pets_models.txt"), "\n".join(models) + "\n")
    if srcs["dogs"]:
        sm = srcs["dogs"]
        for a in ANIMS:
            anim(sm, *a)
        for theirs, ours in SOUNDS.items():
            copy(os.path.join(sm, "sound", theirs + ".ogg"), os.path.join(MEDIA, "sound", ours + ".ogg"))
    if srcs["cats"]:
        sm = srcs["cats"]
        for a in CAT_ANIMS:
            anim(sm, *a)
        for theirs, ours in CAT_SOUNDS.items():
            copy(os.path.join(sm, "sound", theirs + ".ogg"), os.path.join(MEDIA, "sound", ours + ".ogg"))

    def clips(names, dmin, dmax, vol=None):
        v = "" if vol is None else " volume = %s," % vol
        return ["        clip { file = media/sound/%s.ogg, distanceMin = %d, distanceMax = %d,%s }" % (n, dmin, dmax, v) for n in names]
    snd = ["/* GENERATED by tools/import_pets.py -- do not edit.",
           "   Life With Style pet voices: Companion Dogs' and CD: Cats' clips (BigSoundBank / Freesound -- CREDITS_PETS.txt).",
           "   Played on the pet's own emitter only (no world sound: a pet never draws zombies). */",
           "module Base", "{"]
    for name, files, dmin, dmax, vol in (
            ("LWSPetBark", ["LWSPet_Bark1", "LWSPet_Bark2", "LWSPet_Bark3"], 4, 25, None),
            ("LWSPetWhine", ["LWSPet_Whine1", "LWSPet_Whine2"], 2, 15, None),
            ("LWSPetIdle", ["LWSPet_Idle1", "LWSPet_Idle2"], 2, 10, 0.4),
            ("LWSPetHappy", ["LWSPet_Idle1", "LWSPet_Idle2"], 2, 12, 0.9),
            ("LWSPetEat", ["LWSPet_Eat1"], 2, 10, None),
            ("LWSPetMeow", ["LWSPet_CatMeow1"], 3, 22, None),
            ("LWSPetHiss", ["LWSPet_CatHiss1"], 2, 14, None),
            ("LWSPetPurr", ["LWSPet_CatPurr1", "LWSPet_CatPurr2", "LWSPet_CatPurr3"], 1, 8, 0.6)):
        snd += ["    sound %s" % name, "    {", "        category = Animal,", "        maxInstancesPerEmitter = 1,"]
        snd += clips(files, dmin, dmax, vol)
        snd += ["    }"]
    snd.append("}")
    write(os.path.join(MEDIA, "scripts", "HARMONIE_LWS_pets_sounds.txt"), "\n".join(snd) + "\n")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dogs", help="the CompanionDogs/42 folder")
    ap.add_argument("--cats", help="the CompanionCat/42 folder")
    a = ap.parse_args()
    if not a.dogs and not a.cats:
        ap.error("give --dogs and/or --cats")
    main(a.dogs, a.cats)

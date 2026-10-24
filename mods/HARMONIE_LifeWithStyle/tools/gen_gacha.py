#!/usr/bin/env python3
"""HARMONIE - Life With Style: the gacha items (one source).

Owner, 2026-10-23: the items of "RWZ Retention Items" v0.4.2 (the owner's own
mod) move into Life With Style. Like fashion they are given by admins, never
spawn, never sit in the vanilla inventory and can not be dropped: they are
counts in the wardrobe (server data) and are used from the "Gacha items" tab.
The effects, numbers and the XP formula are RWZ's, unchanged.

Writes:
  42/media/lua/shared/HARMONIELifeWithStyle/LWS_GachaData.lua   items, buffs, the set
  42/media/textures/Item_LWSG_<icon>.png                        icons (--icons <RWZ folder>)
TEXTS (names + descriptions, EN/TH) is read by tools/texts_lws.py.

    python3 tools/gen_gacha.py [--icons <unzipped>/RWZ_Retention_Items]
"""
import argparse, os, re, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(os.path.dirname(HERE), "42", "media")
MIN = 60 * 1000

# category id -> EN, TH (the tab's filter chips, in this order)
CATEGORIES = [
    ("medical", "Medical", "การแพทย์"),
    ("stat", "Body & food", "ร่างกาย / อาหาร"),
    ("capsule", "Capsules", "แคปซูล"),
    ("guide", "Manuals & guides", "คู่มือ / ไกด์"),
    ("training", "Training manuals", "คู่มือฝึกทักษะ"),
    ("journey", "Survival journeys", "บันทึกการเอาชีวิตรอด"),
    ("set", "New Dawn set", "ชุด New Dawn"),
]

SKILLS = [  # perk id, EN, TH
    ("Aiming", "Aiming", "การเล็ง"), ("Reloading", "Reloading", "การบรรจุกระสุน"), ("Axe", "Axe", "ขวาน"),
    ("Blunt", "Long Blunt", "อาวุธทื่อยาว"), ("SmallBlunt", "Short Blunt", "อาวุธทื่อสั้น"),
    ("LongBlade", "Long Blade", "ดาบยาว"), ("SmallBlade", "Short Blade", "มีดสั้น"), ("Spear", "Spear", "หอก"),
    ("Maintenance", "Maintenance", "การบำรุงรักษา"), ("Woodwork", "Carpentry", "งานไม้"), ("Cooking", "Cooking", "ทำอาหาร"),
    ("Farming", "Farming", "การเกษตร"), ("Doctor", "First Aid", "ปฐมพยาบาล"), ("Electricity", "Electrical", "ไฟฟ้า"),
    ("Mechanics", "Mechanics", "ช่างยนต์"), ("MetalWelding", "Metalworking", "งานโลหะ"), ("Tailoring", "Tailoring", "ตัดเย็บ"),
    ("Fishing", "Fishing", "ตกปลา"), ("Trapping", "Trapping", "วางกับดัก"), ("PlantScavenging", "Foraging", "หาของป่า"),
]
SKILL = {p: (en, th) for p, en, th in SKILLS}

# buffs (RWZGacha.Config.Buffs): key -> dict
BUFFS = {
    "MasterTraining": dict(ms=60 * MIN, family="training", allXP=0.50, ui="exp"),
    "CombatFocus": dict(ms=30 * MIN, perks={"Aiming": 0.20, "Reloading": 0.20}, ui="exp"),
    "Mercenary": dict(ms=30 * MIN, perks={"Aiming": 0.20, "Reloading": 0.20, "Maintenance": 0.20}, ui="exp"),
    "Medic": dict(ms=30 * MIN, perks={"Doctor": 0.30}, ui="exp"),
    "Mechanic": dict(ms=30 * MIN, perks={"Mechanics": 0.30, "Electricity": 0.20}, ui="exp"),
    "Survivalist": dict(ms=30 * MIN, perks={"PlantScavenging": 0.20, "Fishing": 0.20, "Farming": 0.20}, ui="exp"),
    "Craftsmanship": dict(ms=30 * MIN, perks={"Woodwork": 0.20, "MetalWelding": 0.20, "Tailoring": 0.20}, ui="exp"),
    "DamageCapsule": dict(ms=30 * MIN, family="capsule", ui="capsule", icon="DamageCapsule",
                          effects={"damageMult": 1.10, "enduranceLossMult": 0.90}),
    "CriticalCapsule": dict(ms=30 * MIN, family="capsule", ui="capsule", icon="CriticalCapsule", effects={"critAdd": 5.0}),
    "SpeedCapsule": dict(ms=30 * MIN, family="capsule", ui="capsule", icon="SpeedCapsule",
                         effects={"swingTimeMult": 0.90, "fatigueGainMult": 0.90}),
    "RunnerCapsule": dict(ms=30 * MIN, family="capsule", ui="capsule", icon="RunnerCapsule", effects={"runSpeedMult": 1.05}),
    "GuardianCapsule": dict(ms=30 * MIN, family="capsule", ui="capsule", icon="GuardianCapsule",
                            effects={"effectiveMaxHealthMult": 1.10, "armorProtection": 5.0}),
    "MiniCompoundV": dict(ms=30 * MIN, family="capsule", ui="capsule", icon="MiniCompoundV",
                          effects={"damageMult": 1.10, "enduranceLossMult": 0.90, "critAdd": 5.0, "swingTimeMult": 0.90,
                                   "fatigueGainMult": 0.90, "runSpeedMult": 1.05, "effectiveMaxHealthMult": 1.10,
                                   "armorProtection": 5.0}),
}
for p, en, th in SKILLS:
    BUFFS["TrainingI_" + p] = dict(ms=30 * MIN, family="training", ui="exp", perks={p: 0.20})
    BUFFS["TrainingII_" + p] = dict(ms=30 * MIN, family="training", ui="exp", perks={p: 0.50})

# items: id, category, icon, use (action / buff / flat XP), EN name, TH name, EN effect, TH effect
ITEMS = []
def item(iid, cat, icon, use, en, th, den, dth):
    ITEMS.append(dict(id=iid, cat=cat, icon=icon, use=use, en=en, th=th, den=den, dth=dth))

item("AdvancedBandage", "medical", "AdvancedBandage", {"action": "AdvancedBandage"}, "Advanced Bandage", "ผ้าพันแผลขั้นสูง",
     "Bandages the wound that needs it most, and +5 overall health.", "พันแผลที่ต้องการที่สุด และเพิ่มพลังชีวิตรวม +5")
item("AdvancedMedkit", "medical", "AdvancedMedkit", {"action": "AdvancedMedkit"}, "Advanced Medkit", "ชุดปฐมพยาบาลขั้นสูง",
     "Bandages every wound (bleeding, scratch, cut, bite, deep wound, burn), and +20 overall health.",
     "พันแผลทุกแผล (เลือดออก ข่วน บาด กัด แผลลึก ไฟไหม้) และเพิ่มพลังชีวิตรวม +20")
item("StimHealthBooster", "medical", "StimHealthBooster", {"action": "StimHealthBooster"}, "Stim Health Booster", "ยากระตุ้นพลังชีวิต",
     "+30 overall health at once.", "เพิ่มพลังชีวิตรวม +30 ทันที")
item("ViagraPill", "stat", "ViagraPill", {"action": "ViagraPill"}, "Viagra Pill", "ยาไวอากร้า",
     "Endurance +10%.", "ความอดทน +10%")
item("GodOfCoffee", "stat", "GodOfCoffee", {"action": "GodOfCoffee"}, "God of Coffee", "เทพเจ้ากาแฟ",
     "Tiredness -35%.", "ความเหนื่อยล้า -35%")
item("WakeUpShot", "stat", "WakeUpShot", {"action": "WakeUpShot"}, "Wake-Up Shot", "เข็มปลุกตื่น",
     "Tiredness -50%, but stress to the maximum.", "ความเหนื่อยล้า -50% แต่ความเครียดขึ้นสูงสุด")
item("FieldRationPlus", "stat", "FieldRationPlus", {"action": "FieldRationPlus"}, "Field Ration+", "เสบียงสนาม+",
     "Hunger -20% and thirst -20%.", "ความหิว -20% และความกระหาย -20%")
item("MasterTrainingManual", "guide", "MasterTrainingManual", {"buff": "MasterTraining"}, "Master Training Manual", "คู่มือฝึกระดับปรมาจารย์",
     "+50% XP for every skill, 60 minutes. One training manual at a time.", "XP ทุกทักษะ +50% นาน 60 นาที ใช้คู่มือฝึกได้ทีละเล่ม")
item("CombatFocusManual", "guide", "CombatFocusManual", {"buff": "CombatFocus"}, "Combat Focus Manual", "คู่มือสมาธิการรบ",
     "Aiming and Reloading XP +20%, 30 minutes.", "XP การเล็งและการบรรจุกระสุน +20% นาน 30 นาที")
item("MercenaryFieldGuide", "guide", "MercenaryFieldGuide", {"buff": "Mercenary"}, "Mercenary Field Guide", "ไกด์ภาคสนามทหารรับจ้าง",
     "Aiming, Reloading and Maintenance XP +20%, 30 minutes.", "XP การเล็ง การบรรจุกระสุน และการบำรุงรักษา +20% นาน 30 นาที")
item("MedicFieldGuide", "guide", "MedicFieldGuide", {"buff": "Medic"}, "Medic Field Guide", "ไกด์ภาคสนามแพทย์",
     "First Aid XP +30%, 30 minutes.", "XP ปฐมพยาบาล +30% นาน 30 นาที")
item("MechanicFieldGuide", "guide", "MechanicFieldGuide", {"buff": "Mechanic"}, "Mechanic Field Guide", "ไกด์ภาคสนามช่างยนต์",
     "Mechanics XP +30% and Electrical XP +20%, 30 minutes.", "XP ช่างยนต์ +30% และไฟฟ้า +20% นาน 30 นาที")
item("SurvivalistFieldGuide", "guide", "SurvivalistFieldGuide", {"buff": "Survivalist"}, "Survivalist Field Guide", "ไกด์ภาคสนามนักเอาชีวิตรอด",
     "Foraging, Fishing and Farming XP +20%, 30 minutes.", "XP หาของป่า ตกปลา และการเกษตร +20% นาน 30 นาที")
item("CraftsmanshipFieldGuide", "guide", "CraftsmanshipFieldGuide", {"buff": "Craftsmanship"}, "Craftsmanship Field Guide", "ไกด์ภาคสนามช่างฝีมือ",
     "Carpentry, Metalworking and Tailoring XP +20%, 30 minutes.", "XP งานไม้ งานโลหะ และตัดเย็บ +20% นาน 30 นาที")
CAPS = "Only one capsule at a time (a new one replaces the old one). 30 minutes."
CAPS_TH = "ใช้แคปซูลได้ทีละเม็ด (เม็ดใหม่แทนเม็ดเดิม) นาน 30 นาที"
item("DamageCapsule", "capsule", "DamageCapsule", {"buff": "DamageCapsule"}, "Damage Capsule", "แคปซูลพลังโจมตี",
     "Weapon min/max damage +10%, endurance loss -10%. " + CAPS, "ความเสียหายต่ำสุด/สูงสุดของอาวุธ +10% เสียความอดทนน้อยลง 10% " + CAPS_TH)
item("CriticalCapsule", "capsule", "CriticalCapsule", {"buff": "CriticalCapsule"}, "Critical Capsule", "แคปซูลคริติคอล",
     "Critical chance +5%. " + CAPS, "โอกาสคริติคอล +5% " + CAPS_TH)
item("SpeedCapsule", "capsule", "SpeedCapsule", {"buff": "SpeedCapsule"}, "Speed Capsule", "แคปซูลความเร็ว",
     "Swing delay -10%, tiredness gain -10%. " + CAPS, "ดีเลย์การเหวี่ยงอาวุธ -10% เหนื่อยช้าลง 10% " + CAPS_TH)
item("RunnerCapsule", "capsule", "RunnerCapsule", {"buff": "RunnerCapsule"}, "Runner Capsule", "แคปซูลนักวิ่ง",
     "Run speed +5%. " + CAPS, "ความเร็ววิ่ง +5% " + CAPS_TH)
item("GuardianCapsule", "capsule", "GuardianCapsule", {"buff": "GuardianCapsule"}, "Guardian Capsule", "แคปซูลผู้พิทักษ์",
     "Effective max HP +10%, scratch / bite / bullet protection +5 on every body part. " + CAPS,
     "พลังชีวิตสูงสุดที่ใช้จริง +10% กันข่วน / กัด / กระสุน +5 ทุกส่วนของร่างกาย " + CAPS_TH)
item("MiniCompoundV", "capsule", "MiniCompoundV", {"buff": "MiniCompoundV"}, "Mini Compound-V", "มินิ คอมพาวด์-วี",
     "Every capsule at once: damage +10%, endurance loss -10%, critical +5%, swing delay -10%, tiredness gain -10%, run speed +5%, effective max HP +10%, protection +5. " + CAPS,
     "ทุกแคปซูลรวมกัน: ความเสียหาย +10% เสียความอดทน -10% คริติคอล +5% ดีเลย์เหวี่ยง -10% เหนื่อยช้าลง 10% วิ่งเร็ว +5% พลังชีวิตสูงสุด +10% การป้องกัน +5 " + CAPS_TH)
SET = "New Dawn set: equip pieces for XP on every skill (left ring +1%, right ring +1%, necklace +1%, gloves +2%; all four: +5% more, x1.10 in all)."
SET_TH = "ชุด New Dawn: สวมชิ้นส่วนเพื่อเพิ่ม XP ทุกทักษะ (แหวนซ้าย +1% แหวนขวา +1% สร้อย +1% ถุงมือ +2% ครบ 4 ชิ้น: เพิ่มอีก +5% รวมเป็น x1.10)"
item("NewDawnLeftRing", "set", "NewDawnLeftRing", {"set": 0.01}, "New Dawn Left Ring", "แหวนซ้าย New Dawn", SET, SET_TH)
item("NewDawnRightRing", "set", "NewDawnRightRing", {"set": 0.01}, "New Dawn Right Ring", "แหวนขวา New Dawn", SET, SET_TH)
item("NewDawnNecklace", "set", "NewDawnNecklace", {"set": 0.01}, "New Dawn Necklace", "สร้อยคอ New Dawn", SET, SET_TH)
item("NewDawnGloves", "set", "NewDawnGloves", {"set": 0.02}, "New Dawn Gloves", "ถุงมือ New Dawn", SET, SET_TH)
for p, en, th in SKILLS:
    item("TrainingManualI_" + p, "training", "TrainingManualI", {"buff": "TrainingI_" + p}, "Training Manual I - " + en, "คู่มือฝึก I - " + th,
         "%s XP +20%%, 30 minutes. One training manual at a time." % en, "XP %s +20%% นาน 30 นาที ใช้คู่มือฝึกได้ทีละเล่ม" % th)
    item("TrainingManualII_" + p, "training", "TrainingManualII", {"buff": "TrainingII_" + p}, "Training Manual II - " + en, "คู่มือฝึก II - " + th,
         "%s XP +50%%, 30 minutes. One training manual at a time." % en, "XP %s +50%% นาน 30 นาที ใช้คู่มือฝึกได้ทีละเล่ม" % th)
    item("SurvivalJourneyI_" + p, "journey", "SurvivalJourneyI", {"perk": p, "flatXP": 20}, "Survival Journey I - " + en, "บันทึกการเอาชีวิตรอด I - " + th,
         "+20 %s XP at once (flat: no book or buff multiplies it)." % en, "XP %s +20 ทันที (ค่าคงที่ ไม่มีหนังสือหรือบัฟคูณ)" % th)
    item("SurvivalJourneyII_" + p, "journey", "SurvivalJourneyII", {"perk": p, "flatXP": 50}, "Survival Journey II - " + en, "บันทึกการเอาชีวิตรอด II - " + th,
         "+50 %s XP at once (flat: no book or buff multiplies it)." % en, "XP %s +50 ทันที (ค่าคงที่ ไม่มีหนังสือหรือบัฟคูณ)" % th)

SET_FULL_BONUS = 0.05


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, dict):
        return "{ " + ", ".join(("%s = %s" % (k, lua(x))) if k.isidentifier() else ("[%s] = %s" % (lua(k), lua(x))) for k, x in v.items()) + " }"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x) for x in v) + " }"
    raise TypeError(v)


TEXTS = {}
for cid, en, th in CATEGORIES:
    TEXTS["IGUI_LWSG_Cat_" + cid] = (en, th)
for it in ITEMS:
    TEXTS["IGUI_LWSG_Name_" + it["id"]] = (it["en"], it["th"])
    TEXTS["IGUI_LWSG_Desc_" + it["id"]] = (it["den"], it["dth"])


# getText goes through java.util.Formatter: a bare "%" ("+20%") throws and the
# text shows wrong or blank (workflow.txt). Numbers in words instead (2026-10-24:
# all 122 gacha descriptions had one).
def _no_percent(en, th):
    en = re.sub(r"(\d+(?:\.\d+)?)\s*%", r"\1 percent", en)
    th = re.sub(r"(\d+(?:\.\d+)?)\s*%", r"\1 เปอร์เซ็นต์", th)
    assert "%" not in en and "%" not in th, (en, th)
    return en, th


for _k in list(TEXTS):
    TEXTS[_k] = _no_percent(*TEXTS[_k])


def main(icons):
    L = ["-- GENERATED by tools/gen_gacha.py -- do not edit.",
         "-- HARMONIE - Life With Style: the gacha items (RWZ Retention Items v0.4.2, the owner's",
         "-- own mod, moved here). Numbers and effects are RWZ's. Names: IGUI_LWSG_Name_<id>.",
         "LWS = LWS or {}",
         "LWS.GACHA_CATEGORIES = " + lua([c[0] for c in CATEGORIES]),
         "LWS.GACHA_BUFFS = {"]
    for k, b in BUFFS.items():
        L.append("    %s = %s," % (k, lua(b)))
    L.append("}")
    L.append("LWS.GACHA_ITEMS = {")
    for it in ITEMS:
        L.append("    { id = %s, cat = %s, icon = %s, use = %s }," % (lua(it["id"]), lua(it["cat"]), lua("Item_LWSG_" + it["icon"]), lua(it["use"])))
    L.append("}")
    L.append("LWS.GACHA_SET_FULL_BONUS = %s" % SET_FULL_BONUS)
    L.append("LWS.GACHA_SKILLS = " + lua([p for p, _, _ in SKILLS]))
    L.append("LWS.GACHA_ITEM = {}")
    L.append("for _, g in ipairs(LWS.GACHA_ITEMS) do LWS.GACHA_ITEM[g.id] = g end")
    # 2026-10-24, owner: "ไอเท็มกาชาให้เป็นไอเท็ม แต่เงื่อนไขเดียวกับแฟชั่น" -- each gacha item
    # has an item script (its name and picture in the game), but like a fashion
    # piece it lives in the wardrobe record: never in an inventory (the server
    # sweep deletes one), never in loot; used from the window, traded in the
    # Trade tab.
    S = ["/* GENERATED by tools/gen_gacha.py -- do not edit. */",
         "/* HARMONIE - Life With Style: the gacha items as item types (name + picture).",
         "   They live in the wardrobe record (counts), never in an inventory: the server",
         "   sweep deletes any HARMONIE_LWSG item but the Guardian armour layer. */",
         "module HARMONIE_LWSG", "{", "    imports", "    {", "        Base", "    }", ""]
    for it in ITEMS:
        S += ["    item %s" % it["id"], "    {",
              "        DisplayCategory = Fashion,",
              "        ItemType = base:normal,",
              "        Weight = 0,",
              "        Icon = LWSG_%s," % it["icon"],
              "        DisplayName = %s," % it["en"].replace(",", " "),
              "    }", ""]
    S.append("}")
    spath = os.path.join(MEDIA, "scripts", "HARMONIE_LWS_gacha_items.txt")
    with open(spath, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(S) + "\n")
    print("wrote", os.path.relpath(spath, MEDIA), len(ITEMS), "item types")
    path = os.path.join(MEDIA, "lua", "shared", "HARMONIELifeWithStyle", "LWS_GachaData.lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    print("wrote", os.path.relpath(path, MEDIA), len(ITEMS), "items", len(BUFFS), "buffs")
    if icons:
        src = os.path.join(icons, "common", "media", "textures")
        for name in sorted({it["icon"] for it in ITEMS}):
            shutil.copyfile(os.path.join(src, "Item_RWZ_%s.png" % name), os.path.join(MEDIA, "textures", "Item_LWSG_%s.png" % name))
        print("icons copied:", len({it["icon"] for it in ITEMS}))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--icons", help="the unzipped RWZ_Retention_Items folder")
    a = ap.parse_args()
    main(a.icons)

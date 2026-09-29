#!/usr/bin/env python3
"""Round 23 (request 2026-09-29): new weapons so every weapon category has
every high tier -- "tier epic ให้ครบทุกประเภทที่ยังไม่มีอย่างละ 5 อัน, tier
elite ... อย่างละ 3 อัน และ tier legendary อย่างละ 1 อันถ้ายังไม่มี".
Before this, Epic was missing for SmallBlade/SmallBlunt/Spear, Elite and
Legendary for everything but LongBlade.

For every weapon below this script writes:
  * its item script (42/media/scripts/TWA_weapons_r23.txt) -- a COPY of an
    existing weapon of the same category (so the 3D model, animations,
    sounds and tags are ones that already work), with its own name, icon
    and stats set to land in its tier (tier = DPS band, DPS = average damage
    x BaseSpeed: Epic 2-4, Elite 4-8, Legendary 8-10);
  * its recipe and its Stats entry in lua/shared/HARMONIE_TWA_RecipeData.lua
    (between the "round 23 weapons" markers -- rerunning replaces them):
    base = Material Lump, base2 = the tier's Material Bar (as every other
    weapon of that tier), procedures picked by the RULES ENGINE of
    PROCEDURES_REFERENCE.txt (A-G) from the new stats;
  * its Thai name in Translate/TH/ItemName.json.
Icons: tools/gen_weapon_icons.py (reads WEAPONS from here).
Round 24 ("เปลี่ยนชื่อและรูปอาวุธ ... tier legendary ให้มีความไซไฟมากกว่านี้ แต่
ยังอยู่บนกรอบแบบเป็นไปได้จริง"): the five Legendary weapons are now modern
materials-science pieces (titanium, tungsten carbide, carbon fibre, technical
ceramic) with a model code -- names only; their item keys stay the same so
saved games keep them.
"""
import json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "42", "media")
MOD = "HARMONIE_TheWayToAttack"

TIER_BAR = {5: "TWA_MaterialBar_Epic", 6: "TWA_MaterialBar_Elite", 7: "TWA_MaterialBar_Legendary"}
# stat bumps per tier over the template: crit +, condition x, wear-chance +
BUMP = {5: (5, 1.25, 5), 6: (10, 1.5, 10), 7: (15, 1.8, 15)}

def W(key, cat, tier, dps, template, en, th, look):
    return {"key": key, "cat": cat, "tier": tier, "dps": dps, "template": template, "en": en, "th": th,
            "look": look, "icon": "TWA_" + key}

WEAPONS = [
    # ---- Small Blade (Stab) -- Epic x5, Elite x3, Legendary x1
    W("hardened_tanto_fighter", "SmallBlade", 5, 2.7, "TWA_cgcombattanto", "Hardened Tanto Fighter", "มีดแทนโต้ชุบแข็ง", ("knife", "tanto", "steel", "black")),
    W("serrated_survival_bowie", "SmallBlade", 5, 2.9, "TWA_aitormonterobowieknife", "Serrated Survival Bowie", "มีดโบวี่ฟันเลื่อยเอาชีวิตรอด", ("knife", "bowie", "steel", "coyote", {"serrated": True})),
    W("trench_fighting_knife", "SmallBlade", 5, 3.1, "TWA_tops_us_combat_knife", "Trench Fighting Knife", "มีดต่อสู้สนามเพลาะ", ("knife", "fighter", "black", "darkwood", {"trench": True})),
    W("carbon_steel_combat_dagger", "SmallBlade", 5, 3.3, "TWA_assaultvknife", "Carbon Steel Combat Dagger", "มีดดาบสั้นเหล็กกล้าคาร์บอน", ("knife", "dagger", "steel", "black")),
    W("heavy_duty_field_knife", "SmallBlade", 5, 3.6, "TWA_finka_nkvd_knife", "Heavy Duty Field Knife", "มีดสนามงานหนัก", ("knife", "fighter", "steel", "olive", {"cord": True})),
    W("forged_military_fighting_knife", "SmallBlade", 6, 4.8, "TWA_tops_us_combat_knife", "Forged Military Fighting Knife", "มีดต่อสู้ทหารตีขึ้นรูป", ("knife", "fighter", "black", "olive")),
    W("damascus_hunting_bowie", "SmallBlade", 6, 5.6, "TWA_aitormonterobowieknife", "Damascus Hunting Bowie", "มีดโบวี่ล่าสัตว์ดามัสกัส", ("knife", "bowie", "damascus", "wood")),
    W("titanium_tactical_tanto", "SmallBlade", 6, 6.4, "TWA_kabar1245tanto", "Titanium Tactical Tanto", "มีดแทนโต้ยุทธวิธีไทเทเนียม", ("knife", "tanto", "black", "cord", {"cord": True})),
    W("master_forged_combat_knife", "SmallBlade", 7, 8.8, "TWA_mtech_xtreme_tactical_fighter_knife", "Ti-7 Carbide Combat Knife", "มีดต่อสู้คาร์ไบด์ Ti-7", ("tech", "knife")),
    # ---- Small Blunt -- Epic x5, Elite x3, Legendary x1
    W("steel_framing_hammer", "SmallBlunt", 5, 2.7, "TWA_oxnailhammer", "Steel Framing Hammer", "ค้อนตีโครงเหล็ก", ("hammer", "claw", "steel", "black")),
    W("weighted_riot_baton", "SmallBlunt", 5, 2.9, "TWA_cold_steel_expandable_baton", "Weighted Riot Baton", "กระบองปราบจลาจลถ่วงน้ำหนัก", ("baton", "black", "rubber")),
    W("forged_ball_peen_hammer", "SmallBlunt", 5, 3.1, "TWA_stanley_fatmax_nailing_hammer", "Forged Ball-Peen Hammer", "ค้อนหัวกลมตีขึ้นรูป", ("hammer", "ballpeen", "steel", "wood")),
    W("demolition_hand_sledge", "SmallBlunt", 5, 3.3, "TWA_fatmaxbrickhammer", "Demolition Hand Sledge", "ค้อนปอนด์มือรื้อถอน", ("hammer", "club", "steel", "red")),
    W("tactical_breaching_hammer", "SmallBlunt", 5, 3.6, "TWA_m48tacticalwarhammer", "Tactical Breaching Hammer", "ค้อนพังประตูยุทธวิธี", ("hammer", "war", "black", "black")),
    W("forged_tactical_war_hammer", "SmallBlunt", 6, 4.8, "TWA_m48tacticalwarhammer", "Forged Tactical War Hammer", "ค้อนศึกยุทธวิธีตีขึ้นรูป", ("hammer", "war", "steel", "olive")),
    W("tungsten_riot_baton", "SmallBlunt", 6, 5.6, "TWA_cold_steel_expandable_baton", "Tungsten Riot Baton", "กระบองปราบจลาจลทังสเตน", ("baton", "steel", "rubber")),
    W("heavy_framing_hammer", "SmallBlunt", 6, 6.4, "TWA_oxnailhammer", "Heavy Framing Hammer", "ค้อนตีโครงงานหนัก", ("hammer", "claw", "black", "wood")),
    W("master_forged_breaching_hammer", "SmallBlunt", 7, 8.8, "TWA_m48tacticalwarhammer", "W-7 Tungsten Breaching Hammer", "ค้อนทะลวงทังสเตน W-7", ("tech", "hammer")),
    # ---- Spear -- Epic x5, Elite x3, Legendary x1
    W("steel_boar_spear", "Spear", 5, 2.7, "TWA_coldsteelspear", "Steel Boar Spear", "หอกล่าหมูป่าเหล็กกล้า", ("spear", "boar", "steel", "wood")),
    W("firefighter_pike_pole", "Spear", 5, 2.9, "TWA_reapr_11003_survival_spear", "Firefighter Pike Pole", "ตะขอดับเพลิง", ("spear", "pike", "steel", "red")),
    W("tactical_survival_spear", "Spear", 5, 3.1, "TWA_reapr_11003_survival_spear", "Tactical Survival Spear", "หอกเอาชีวิตรอดยุทธวิธี", ("spear", "leaf", "black", "olive")),
    W("fishing_gig_spear", "Spear", 5, 3.3, "TWA_coldsteelspear", "Fishing Gig Spear", "หอกแทงปลา", ("spear", "gig", "steel", "wood")),
    W("bayonet_pole_spear", "Spear", 5, 3.6, "TWA_coldsteelspear", "Bayonet Pole Spear", "หอกด้ามดาบปลายปืน", ("spear", "bayonet", "black", "darkwood")),
    W("forged_boar_spear", "Spear", 6, 4.8, "TWA_coldsteelspear", "Forged Boar Spear", "หอกล่าหมูป่าตีขึ้นรูป", ("spear", "boar", "black", "darkwood")),
    W("hardened_naginata", "Spear", 6, 5.6, "TWA_m48_naginata", "Hardened Naginata", "ง้าวนางินาตะชุบแข็ง", ("spear", "naginata", "steel", "black")),
    W("forged_pike_pole", "Spear", 6, 6.4, "TWA_reapr_11003_survival_spear", "Forged Pike Pole", "ตะขอดับเพลิงตีขึ้นรูป", ("spear", "pike", "black", "red")),
    W("master_forged_hunting_spear", "Spear", 7, 8.8, "TWA_coldsteelspear", "CF-7 Carbon Ceramic Spear", "หอกคาร์บอนเซรามิก CF-7", ("tech", "spear")),
    # ---- Axe -- Elite x3, Legendary x1 (Epic already there)
    W("forged_felling_axe", "Axe", 6, 4.8, "TWA_browning_outdoorsman_axe", "Forged Felling Axe", "ขวานโค่นไม้ตีขึ้นรูป", ("axe", "felling", "steel", "wood")),
    W("hardened_breaching_axe", "Axe", 6, 5.6, "TWA_roughneckaxe", "Hardened Breaching Axe", "ขวานพังประตูชุบแข็ง", ("axe", "breach", "black", "black")),
    W("steel_tactical_tomahawk", "Axe", 6, 6.4, "TWA_gerberdownrangetomahawk", "Steel Tactical Tomahawk", "ขวานโทมาฮอว์กยุทธวิธีเหล็กกล้า", ("axe", "tomahawk", "steel", "black")),
    W("master_forged_double_bit_axe", "Axe", 7, 8.8, "TWA_browning_outdoorsman_axe", "Ti-7 Composite Double-Bit Axe", "ขวานสองคมคอมโพสิต Ti-7", ("tech", "axe")),
    # ---- Blunt -- Elite x3, Legendary x1 (Epic already there)
    W("forged_sledgehammer", "Blunt", 6, 4.8, "TWA_ox_trade_sledgehammer", "Forged Sledgehammer", "ค้อนปอนด์ตีขึ้นรูป", ("sledge", "sledge", "steel", "wood")),
    W("steel_demolition_maul", "Blunt", 6, 5.6, "TWA_fiskarsplittingmaul", "Steel Demolition Maul", "ค้อนผ่ารื้อถอนเหล็กกล้า", ("sledge", "maul", "black", "black")),
    W("reinforced_steel_bat", "Blunt", 6, 6.4, "TWA_avengebaseballbat", "Reinforced Steel Bat", "ไม้เบสบอลเหล็กเสริมแกน", ("bat", "steel", "black")),
    W("master_forged_splitting_maul", "Blunt", 7, 8.8, "TWA_fiskarsplittingmaul", "W-7 Tungsten Splitting Maul", "ค้อนผ่าทังสเตน W-7", ("tech", "maul")),
]

# ---- the rules engine (PROCEDURES_REFERENCE.txt, A-G) ----------------------

def procedures(sub, crit, rng, push, knock, cond, lower):
    out = []
    if crit and crit > 0:
        if sub == "Swinging":
            out.append("SharpenEdge" if crit < 20 else "StropLeather" if crit < 40 else "QuenchHarden" if crit < 60 else "AnnealMetal")
        elif sub in ("Spear", "Stab"):
            out.append("KnapHead" if crit < 20 else "TaperPoint" if crit < 40 else "QuenchHarden" if crit < 60 else "AnnealMetal")
    if rng >= 1.6: out += ["MakeRivetedHandle", "TightenBolts"]
    elif rng > 1.4: out += ["MakeLongHandle", "ReinforcedBind"]
    elif rng > 1.2: out += ["MakeHandle", "WrapBind"]
    if push >= 1.0: out.append("WeldMetal")
    elif push >= 0.5: out.append("CounterweightHead")
    elif push >= 0.3: out.append("HammerNails")
    if knock >= 3: out.append("DrillCore")
    elif knock >= 2: out.append("RivetPlate")
    if cond > 20: out.append("WeaveWire")
    elif cond > 15: out.append("StringSinew")
    elif cond > 10: out.append("WrapLeather")
    elif cond > 5: out.append("WrapCloth")
    if lower > 40: out.append("SurfaceCoating")
    elif lower > 30: out.append("FireTreat")
    elif lower > 20: out.append("CoatWax")
    elif lower > 10: out.append("CoatMud")
    return out

# ---- item scripts ----------------------------------------------------------

def load_templates():
    blocks = {}
    for f in sorted(os.listdir(os.path.join(MEDIA, "scripts"))):
        if not f.startswith("TWA_weapons_") or f == "TWA_weapons_r23.txt":
            continue
        s = open(os.path.join(MEDIA, "scripts", f), encoding="utf-8", errors="replace").read()
        for m in re.finditer(r'item\s+(\w+)\s*\{(.*?)\n\s*\}', s, re.S):
            blocks[m.group(1)] = m.group(2)
    return blocks

def field(body, name):
    m = re.search(r'^\s*' + name + r'\s*=\s*([^\n]*?)\s*,?\s*$', body, re.M)
    return m.group(1).strip().rstrip(",") if m else None

def set_field(body, name, value):
    pat = re.compile(r'^(\s*' + name + r'\s*=\s*)[^\n]*$', re.M)
    if pat.search(body):
        return pat.sub(lambda m: m.group(1) + str(value) + ",", body, count=1)
    return body.rstrip() + "\n\t\t%s = %s,\n" % (name, value)

def num(v, default):
    try: return float(v)
    except (TypeError, ValueError): return default

def fmt(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")

def build():
    tpl = load_templates()
    scripts, recipes, stats, th = [], [], [], {}
    for w in WEAPONS:
        body = tpl[w["template"]]
        speed = num(field(body, "BaseSpeed"), 1.0)
        avg = w["dps"] / speed
        mn, mx = round(avg * 0.85, 1), round(avg * 1.15, 1)
        dps = (mn + mx) / 2 * speed
        tb = {5: (2, 4), 6: (4, 8), 7: (8, 10)}[w["tier"]]
        assert tb[0] <= dps < tb[1], (w["key"], dps)
        cb, cm, lb = BUMP[w["tier"]]
        crit = min(90, num(field(body, "CriticalChance"), 0) + cb) if field(body, "CriticalChance") else 0
        cond = int(round(num(field(body, "ConditionMax"), 10) * cm))
        lower = int(num(field(body, "ConditionLowerChanceOneIn"), 10) + lb)
        rng = num(field(body, "MaxRange"), 1.0)
        push = num(field(body, "PushBackMod"), 0)
        knock = num(field(body, "KnockdownMod"), 0)
        sub = field(body, "SubCategory") or "Swinging"
        weight = num(field(body, "Weight"), 1.0)
        two = (field(body, "TwoHandWeapon") or "").upper() == "TRUE"
        dmgType = field(body, "DamageCategory") or "Slash"
        for k, v in (("DisplayName", w["en"]), ("Icon", w["icon"]), ("MinDamage", fmt(mn)), ("MaxDamage", fmt(mx)),
                     ("ConditionMax", cond), ("ConditionLowerChanceOneIn", lower)):
            body = set_field(body, k, v)
        if crit: body = set_field(body, "CriticalChance", fmt(crit))
        # the template may name its picture with IconsForTexture (which wins
        # over Icon): ours goes there too
        if field(body, "IconsForTexture"): body = set_field(body, "IconsForTexture", w["icon"])
        full = "%s.TWA_%s" % (MOD, w["key"])
        scripts.append("\t/* round 23: %s tier %d, from %s */\n\titem TWA_%s\n\t{%s\n\t}\n" % (w["cat"], w["tier"], w["template"], w["key"], body.rstrip()))
        procs = procedures(sub, crit, rng, push, knock, cond, lower)
        recipes.append('    { id = "Make_%s", result = "%s", base = "%s.TWA_MaterialLump", base2 = "%s.%s", category = "%s", procedures = { %s } },'
                       % (w["key"], full, MOD, MOD, TIER_BAR[w["tier"]], w["cat"], ", ".join('"%s"' % p for p in procs)))
        stats.append('    ["%s"] = { maxDamage = %s, minDamage = %s, conditionMax = %d, weight = %s, critChance = %s, maxRange = %s, baseSpeed = %s, knockdownMod = %s, damageType = "%s", twoHanded = %s, icon = "%s", tier = %d, dps = %s, categories = "%s", subCategory = "%s", conditionLowerChanceOneIn = %d, pushBackMod = %s },'
                     % (full, fmt(mx), fmt(mn), cond, fmt(weight), fmt(crit), fmt(rng), fmt(speed), fmt(knock), dmgType,
                        "true" if two else "nil", w["icon"], w["tier"], fmt(dps), w["cat"], sub, lower, fmt(push)))
        th[full] = w["th"]
    return scripts, recipes, stats, th

def replace_block(s, begin, end, body, anchor):
    if begin in s:
        i = s.index(begin); j = s.index(end, i) + len(end)
        return s[:i] + begin + "\n" + body + "\n" + end + s[j:]
    i = s.index(anchor)
    j = s.index("\n", i) + 1
    return s[:j] + begin + "\n" + body + "\n" + end + "\n" + s[j:]

def main():
    scripts, recipes, stats, th = build()
    out = os.path.join(MEDIA, "scripts", "TWA_weapons_r23.txt")
    open(out, "w", encoding="utf-8").write(
        "/* GENERATED by mods/HARMONIE_TheWayToAttack/tools/gen_new_weapons.py (round 23) -- each weapon\n"
        "   copies an existing weapon of its category (model, animations, sounds) with its own name,\n"
        "   icon and tier stats. Edit the WEAPONS table there and rerun. */\n"
        "module %s\n{\n\n\timports\n\t{\n\t\tBase,\n\t}\n\n%s\n}\n" % (MOD, "\n".join(scripts)))
    rp = os.path.join(MEDIA, "lua", "shared", "HARMONIE_TWA_RecipeData.lua")
    s = open(rp, encoding="utf-8").read()
    s = replace_block(s, "    -- >>> round 23 weapons (GENERATED by tools/gen_new_weapons.py) -- recipes",
                      "    -- <<< round 23 weapons -- recipes", "\n".join(recipes), '    { id = "Make_GemPure",')
    s = replace_block(s, "    -- >>> round 23 weapons (GENERATED by tools/gen_new_weapons.py) -- stats",
                      "    -- <<< round 23 weapons -- stats", "\n".join(stats), '    ["HARMONIE_TheWayToAttack.TWA_Gemstone"] = {')
    open(rp, "w", encoding="utf-8").write(s)
    tp = os.path.join(MEDIA, "lua", "shared", "Translate", "TH", "ItemName.json")
    # keys added at the end or changed in place -- never the whole file rewritten
    t = open(tp, encoding="utf-8").read()
    have = json.loads(t)
    add = []
    for k, v in th.items():
        if k in have:
            old = '    %s: %s' % (json.dumps(k), json.dumps(have[k], ensure_ascii=False))
            t = t.replace(old, '    %s: %s' % (json.dumps(k), json.dumps(v, ensure_ascii=False)))
        else:
            add.append('    %s: %s' % (json.dumps(k), json.dumps(v, ensure_ascii=False)))
    if add:
        t = t.rstrip()[:-1].rstrip() + ",\n" + ",\n".join(add) + "\n}\n"
    json.loads(t)
    open(tp, "w", encoding="utf-8").write(t)
    print("weapons:", len(WEAPONS))

if __name__ == "__main__":
    main()

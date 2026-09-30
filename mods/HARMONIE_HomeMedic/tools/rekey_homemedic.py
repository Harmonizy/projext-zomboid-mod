#!/usr/bin/env python3
"""HARMONIE - Home Medic: give the merged EHR / TOC text keys Home Medic names.

After merge_ehr.py / merge_toc.py the translation keys still carry the
original mods' names (UI_EHR_..., Tooltip_EHR_..., EHR_Dialogue_...,
Sandbox_TOC_..., TOC's plain ContextMenu_Amputate ...). This renames them to
HomeMedic keys everywhere at once -- Lua string literals, scripts,
sandbox-options.txt (page / translation) and every Translate/<LANG>/*.json --
so the mod owns its text and cannot clash with the original EHR / TOC or
with vanilla keys. It also rebrands the visible text ("EHR ...",
"Extensive Health Rework", "The Only Cure" page) to Home Medic in every
language, with hand-written EN / TH wording where a plain swap reads badly.

NOT renamed (saves, server settings and item scripts depend on them):
ModData keys, item / module / recipe ids, sandbox option names
(ExtensiveHealthRework.*, TOC.*, MultiplierConfig.*), perk ids, item
tooltips (Tooltip_<Item> -- some override vanilla items' own tooltips).

Rerunnable (a no-op once done) -- run it again after re-merging a newer
EHR / TOC. Usage (Python 3.8+):
  python mods/HARMONIE_HomeMedic/tools/rekey_homemedic.py [--dry-run]
"""
import argparse, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(os.path.dirname(HERE), "42", "media")

# (old prefix, new prefix) -- every key that starts with old.
PREFIXES = [
    ("UI_EHR_", "UI_HomeMedic_"),
    ("Tooltip_EHR_", "Tooltip_HomeMedic_"),
    ("Sandbox_EHR_", "Sandbox_HomeMedic_"),
    ("EHR_Dialogue_", "HomeMedic_Dialogue_"),
    ("EHR_Pain_", "HomeMedic_Pain_"),
    ("UI_SideEffect_", "UI_HomeMedic_SideEffect_"),
    ("UI_trait_EHR_", "UI_trait_HomeMedic_"),
    ("UI_prof_EHR", "UI_prof_HomeMedic_"),
    ("UI_profdesc_EHR", "UI_profdesc_HomeMedic_"),
    ("Sandbox_TOC_", "Sandbox_HomeMedic_Surgery_"),
    ("ContextMenu_Limb_", "ContextMenu_HomeMedic_Limb_"),
    ("ContextMenu_Amputate", "ContextMenu_HomeMedic_Amputate"),
    ("ContextMenu_Admin_", "ContextMenu_HomeMedic_Admin_"),
    ("IGUI_HealthPanel_", "IGUI_HomeMedic_HealthPanel_"),
    ("Tooltip_Surgery_", "Tooltip_HomeMedic_Surgery_"),
    ("UI_trait_Amputee_", "UI_trait_HomeMedic_Amputee_"),
]
# Exact keys (TOC's generic ones).
EXACT = {
    "Sandbox_TOC": "Sandbox_HomeMedic_Surgery",
    "Sandbox_ExtensiveHealthRework": "Sandbox_HomeMedic",
    "ContextMenu_Cauterize": "ContextMenu_HomeMedic_Cauterize",
    "ContextMenu_InstallProstRight": "ContextMenu_HomeMedic_InstallProstRight",
    "ContextMenu_InstallProstLeft": "ContextMenu_HomeMedic_InstallProstLeft",
    "ContextMenu_PutTourniquetArmLeft": "ContextMenu_HomeMedic_PutTourniquetArmLeft",
    "ContextMenu_PutTourniquetArmRight": "ContextMenu_HomeMedic_PutTourniquetArmRight",
    "ContextMenu_PutTourniquetLegL": "ContextMenu_HomeMedic_PutTourniquetLegL",
    "ContextMenu_PutTourniquetLegR": "ContextMenu_HomeMedic_PutTourniquetLegR",
    "ContextMenu_CleanWound": "ContextMenu_HomeMedic_CleanWound",
    "IGUI_Confirmation_Amputate": "IGUI_HomeMedic_Confirmation_Amputate",
    "IGUI_Yes": "IGUI_HomeMedic_Yes",
    "IGUI_No": "IGUI_HomeMedic_No",
    "UI_Say_CantEquip": "UI_HomeMedic_Say_CantEquip",
    "UI_trait_Insensitive": "UI_trait_HomeMedic_Insensitive",
    "UI_trait_Insensitive_desc": "UI_trait_HomeMedic_Insensitive_desc",
}
# sandbox-options.txt: page = X / translation = X  ->  key "Sandbox_" + X.
SANDBOX_NAMES = [("EHR_", "HomeMedic_"), ("TOC_", "HomeMedic_Surgery_")]
SANDBOX_EXACT = {"TOC": "HomeMedic_Surgery"}


# Visible text: exact wording per language (key -> text), then generic swaps.
VALUE_OVERRIDES = {
    "EN": {
        "Sandbox_HomeMedic": "HARMONIE - Home Medic",
        "Sandbox_HomeMedic_Surgery": "Home Medic: Surgery & Amputation",
        "ContextMenu_HomeMedic_Admin_TOC": "Home Medic: Amputation",
        "UI_HomeMedic_Tab_EHR_Compact": "Medic",
        "UI_HomeMedic_Tab_EHR": "Medic Monitor",
        "UI_prof_HomeMedic_Doctor": "Field Doctor",
        "UI_prof_HomeMedic_Surgeon": "Field Surgeon",
        "Sandbox_HomeMedic_StitchMinigameEnabled_tooltip":
            "Stitching minigame. Currently switched off by Home Medic (it will return in a later version): "
            "this setting has no effect for now and every stitch is the normal action.",
    },
    "TH": {
        "Sandbox_HomeMedic": "HARMONIE - Home Medic",
        "Sandbox_HomeMedic_Surgery": "Home Medic: ศัลยกรรมและการตัดแขน",
        "ContextMenu_HomeMedic_Admin_TOC": "Home Medic: การตัดแขน",
        "UI_HomeMedic_Tab_EHR_Compact": "Medic",
        "UI_HomeMedic_Tab_EHR": "หน้าจอเฝ้าระวัง",
        "UI_prof_HomeMedic_Doctor": "แพทย์สนาม",
        "UI_prof_HomeMedic_Surgeon": "ศัลยแพทย์สนาม",
        "Sandbox_HomeMedic_StitchMinigameEnabled_tooltip":
            "มินิเกมเย็บแผล ตอนนี้ Home Medic ปิดไว้ก่อน (จะกลับมาในเวอร์ชันหลัง) "
            "ตัวเลือกนี้จึงยังไม่มีผล การเย็บแผลทุกครั้งเป็นการกระทำปกติ",
    },
}
VALUE_SWAPS = [
    (r"Extensive Health Rework(?: Evolved)?(?: B42)?", "Home Medic"),
    (r"\bAn EHR-trained doctor\b", "A field-trained doctor"),
    (r"แพทย์ที่ผ่านการฝึกฝนแบบ EHR", "แพทย์ที่ผ่านการฝึกภาคสนาม"),
    (r"\bEHR MEDICAL\b", "HOME MEDIC"),
    (r"\bEHR\b", "Home Medic"),
]


def rebrand(lang, key, value):
    over = VALUE_OVERRIDES.get(lang, {})
    if key in over:
        return over[key]
    if not isinstance(value, str):
        return value
    if re.fullmatch(r"[A-Z0-9 :&'()/-]+", value):   # an all-caps English title
        value = re.sub(r"\bEHR MEDICAL\b", "HOME MEDIC", value)
        value = re.sub(r"\bEHR\b", "HOME MEDIC", value)
    for pat, rep in VALUE_SWAPS:
        value = re.sub(pat, rep, value)
    return value


def new_key(k):
    if k in EXACT:
        return EXACT[k]
    for old, new in PREFIXES:
        if k.startswith(old):
            return new + k[len(old):]
    return k


def lua_sub(text):
    """Rename key literals in Lua: exact keys and key prefixes, quoted."""
    for old, new in EXACT.items():
        text = re.sub(r"([\"'])" + re.escape(old) + r"\1", lambda m: m.group(1) + new + m.group(1), text)
    for old, new in PREFIXES:
        # A prefix literal: "UI_EHR_..." or "UI_EHR_" .. x (never a bare module
        # name such as "EHR_Dialogue", which has no trailing underscore).
        text = re.sub(r"([\"'])" + re.escape(old), lambda m: m.group(1) + new, text)
    return text


def script_sub(text):
    def repl(m):
        return m.group(1) + new_key(m.group(2))
    return re.sub(r"(\b(?:Tooltip|UIName|UIDescription|DisplayName)\s*=\s*)([A-Za-z0-9_]+)", repl, text)


def sandbox_sub(text):
    def repl(m):
        name = m.group(2)
        if name in SANDBOX_EXACT:
            return m.group(1) + SANDBOX_EXACT[name]
        for old, new in SANDBOX_NAMES:
            if name.startswith(old):
                return m.group(1) + new + name[len(old):]
        return m.group(0)
    return re.sub(r"^(\s*(?:page|translation)\s*=\s*)([A-Za-z0-9_]+)", repl, text, flags=re.M)


def rekey_json(path, lang):
    with open(path, encoding="utf-8-sig") as f:
        data = json.load(f)
    out, clash = {}, []
    for k, v in data.items():
        nk = new_key(k)
        if os.path.basename(path) != "Mod.json":
            v = rebrand(lang, nk, v)
        if nk in out and nk != k:
            clash.append(nk)
            continue
        if nk != k and nk in data and data[nk] != v:
            clash.append(nk)        # already migrated key wins
            continue
        out[nk] = v
    return data, out, clash


def write(path, text, dry):
    if not dry:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    changed = []
    for root, _, files in os.walk(MEDIA):
        for name in files:
            p = os.path.join(root, name)
            rel = os.path.relpath(p, MEDIA).replace(os.sep, "/")
            if name.endswith(".lua"):
                old = open(p, encoding="utf-8").read()
                new = lua_sub(old)
            elif rel.startswith("scripts/") and name.endswith(".txt"):
                old = open(p, encoding="utf-8").read()
                new = script_sub(old)
            elif rel == "sandbox-options.txt":
                old = open(p, encoding="utf-8").read()
                new = sandbox_sub(old)
            elif rel.startswith("lua/shared/Translate/") and name.endswith(".json"):
                data, out, clash = rekey_json(p, rel.split("/")[3])
                for c in clash:
                    print("  note: %s: kept the existing %s" % (rel, c))
                if list(out.items()) == list(data.items()):
                    continue
                raw = open(p, encoding="utf-8-sig").read()
                tail = "\n" if raw.endswith("\n") else ""
                write(p, json.dumps(out, ensure_ascii=False, indent=4) + tail, a.dry_run)
                changed.append(rel)
                continue
            else:
                continue
            if new != old:
                write(p, new, a.dry_run)
                changed.append(rel)
    print("%s %d files" % ("would change" if a.dry_run else "changed", len(changed)))
    for c in sorted(changed):
        print("  ", c)


if __name__ == "__main__":
    sys.exit(main())

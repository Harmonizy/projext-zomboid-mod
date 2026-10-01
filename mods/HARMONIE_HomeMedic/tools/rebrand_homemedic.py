#!/usr/bin/env python3
"""HARMONIE - Home Medic: rebrand the visible text of the merged EHR / TOC.

Translation KEYS keep the original mods' names (UI_EHR_..., Tooltip_EHR_...,
EHR_Dialogue_..., Sandbox_TOC_..., ContextMenu_Amputate, ...): other mods on
a server look them up. Only the VALUES are rebranded ("EHR ...",
"Extensive Health Rework", "The Only Cure" page) to Home Medic in every
language, with hand-written EN / TH wording where a plain swap reads badly.

Rerunnable (a no-op once done) -- run it again after re-merging a newer
EHR / TOC. Usage (Python 3.8+):
  python mods/HARMONIE_HomeMedic/tools/rebrand_homemedic.py [--dry-run]
"""
import argparse, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(os.path.dirname(HERE), "42", "media")


# Visible text: exact wording per language (key -> text), then generic swaps.
VALUE_OVERRIDES = {
    "EN": {
        "Sandbox_ExtensiveHealthRework": "HARMONIE - Home Medic",
        "Sandbox_TOC": "Home Medic: Surgery & Amputation",
        "ContextMenu_Admin_TOC": "Home Medic: Amputation",
        "UI_EHR_Tab_EHR_Compact": "Medic",
        "UI_EHR_Tab_EHR": "Medic Monitor",
        "UI_prof_EHRDoctor": "Field Doctor",
        "UI_prof_EHRSurgeon": "Field Surgeon",
        "Sandbox_EHR_StitchMinigameEnabled_tooltip":
            "Stitching minigame. Currently switched off by Home Medic (it will return in a later version): "
            "this setting has no effect for now and every stitch is the normal action.",
    },
    "TH": {
        "Sandbox_ExtensiveHealthRework": "HARMONIE - Home Medic",
        "Sandbox_TOC": "Home Medic: ศัลยกรรมและการตัดแขน",
        "ContextMenu_Admin_TOC": "Home Medic: การตัดแขน",
        "UI_EHR_Tab_EHR_Compact": "Medic",
        "UI_EHR_Tab_EHR": "หน้าจอเฝ้าระวัง",
        "UI_prof_EHRDoctor": "แพทย์สนาม",
        "UI_prof_EHRSurgeon": "ศัลยแพทย์สนาม",
        "Sandbox_EHR_StitchMinigameEnabled_tooltip":
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


def rebrand_json(path, lang):
    with open(path, encoding="utf-8-sig") as f:
        data = json.load(f)
    return data, {k: rebrand(lang, k, v) for k, v in data.items()}


def write(path, text, dry):
    if not dry:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    changed = []
    for root, _, files in os.walk(os.path.join(MEDIA, "lua", "shared", "Translate")):
        for name in files:
            if not name.endswith(".json") or name == "Mod.json":
                continue
            p = os.path.join(root, name)
            rel = os.path.relpath(p, MEDIA).replace(os.sep, "/")
            data, out = rebrand_json(p, rel.split("/")[3])
            if out == data:
                continue
            raw = open(p, encoding="utf-8-sig").read()
            tail = "\n" if raw.endswith("\n") else ""
            write(p, json.dumps(out, ensure_ascii=False, indent=4) + tail, a.dry_run)
            changed.append(rel)
    print("%s %d files" % ("would change" if a.dry_run else "changed", len(changed)))
    for c in sorted(changed):
        print("  ", c)


if __name__ == "__main__":
    sys.exit(main())

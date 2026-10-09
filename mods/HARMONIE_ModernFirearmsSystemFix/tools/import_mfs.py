#!/usr/bin/env python3
"""HARMONIE - Modern Firearms: bring the original mod's gun content in
(phase 1 of the standalone rework, 2026-10-09).

The owner got the original author's permission to use "Modern Firearms
System" (Workshop 3633421539) in this mod and to stop depending on it (it
is no longer developed). The owner asked for the gun-related parts only:
guns, ammo, magazines, parts / attachments, the 3D inspect UI, their sounds
and models, plus grenades / launchers, the flamethrower and shields. Air
drops and the radio trade are left out.

Usage:  python3 tools/import_mfs.py <path to .../Escape from Kentucky4215/42>
        (the owner keeps the original at <repo>/3633421539, gitignored)

What it does, every time from scratch (re-runnable):
  1. deletes the previously imported files (listed in IMPORTED.txt) and
     copies the original's 42/media again, minus EXCLUDE;
  2. keeps this mod's own files (HARMONIE_* lua, sandbox options, art);
  3. patches the two places that pointed at the left-out systems
     (PATCHES -- each must match exactly once, or the script stops);
  4. merges this mod's own English texts into the original's translation
     files (ours win: they are the fixes for its missing English), and
     appends our sandbox options to the original's sandbox-options.txt;
  5. writes IMPORTED.txt (every imported file) for the next run.
"""
import json, os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "42"))
OURS = os.path.join(HERE, "ours")          # this mod's own files, kept apart
LIST = os.path.join(HERE, "IMPORTED.txt")

# left out (paths relative to media/); a directory excludes all under it
EXCLUDE = [
    "lua/client/UseAirDropMarker.lua",
    "lua/client/ISUI/ISAirDropInComing.lua",
    "scripts/AirDropBGM.txt",
    "sound/AirDropBGM",
    "lua/client/UI/risky_trade.lua",
    "lua/client/UI/risky_trade_button.lua",
    "lua/shared/Trade",
    "lua/server/Trade",
]

PATCHES = [
    # the inspect window's radio-trade button (the trade is left out)
    ("lua/client/UI/risky_inspect_core.lua",
     """            item = tradeButton:new(1000 + 170, 585, 75, 75, function()
                riskyTradeUI.open(self)
            end)
            item:bringToTop()
            self:addChild(item)""",
     """            -- HARMONIE: the radio trade is not part of this mod (left out
            -- with the owner's scope); its button only if it exists
            if tradeButton and riskyTradeUI then
                item = tradeButton:new(1000 + 170, 585, 75, 75, function()
                    riskyTradeUI.open(self)
                end)
                item:bringToTop()
                self:addChild(item)
            end"""),
    # the air-drop marker in the zombie loot (air drops are left out; the
    # item is not even defined in the original's scripts)
    ("lua/server/item/item_cat.lua",
     """    { item = "Base.AirDropMarker",        chance = 0.02 }, """,
     """    -- HARMONIE: air drops are not part of this mod"""),
]


def excluded(rel):
    rel = rel.replace(os.sep, "/")
    return any(rel == e or rel.startswith(e + "/") for e in EXCLUDE)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src42 = sys.argv[1]
    src = os.path.join(src42, "media")
    if not os.path.isdir(src):
        sys.exit("no media/ in %s" % src42)
    dst = os.path.join(MOD, "media")

    # 1. remove the previous import
    if os.path.exists(LIST):
        for rel in open(LIST, encoding="utf-8").read().split("\n"):
            p = os.path.join(MOD, rel)
            if rel and os.path.isfile(p):
                os.remove(p)
    # our own files come back from tools/ours (they were saved there once)
    if os.path.isdir(OURS):
        for root, _, files in os.walk(OURS):
            for f in files:
                a = os.path.join(root, f)
                b = os.path.join(MOD, os.path.relpath(a, OURS))
                os.makedirs(os.path.dirname(b), exist_ok=True)
                shutil.copy2(a, b)

    # 2. copy
    imported, size = [], 0
    for root, dirs, files in os.walk(src):
        for f in files:
            a = os.path.join(root, f)
            rel = os.path.relpath(a, src)
            if excluded(rel):
                continue
            b = os.path.join(dst, rel)
            if os.path.exists(b) and os.path.relpath(b, MOD).replace(os.sep, "/") not in ("media/sandbox-options.txt",) \
                    and not rel.replace(os.sep, "/").startswith("lua/shared/Translate/EN/"):
                sys.exit("would overwrite our own file: %s" % b)
            os.makedirs(os.path.dirname(b), exist_ok=True)
            if rel.replace(os.sep, "/") == "sandbox-options.txt" or rel.replace(os.sep, "/").startswith("lua/shared/Translate/EN/"):
                continue  # merged below
            shutil.copy2(a, b)
            imported.append(os.path.relpath(b, MOD).replace(os.sep, "/"))
            size += os.path.getsize(a)

    # 3. patches
    for rel, old, new in PATCHES:
        p = os.path.join(dst, rel)
        s = open(p, encoding="utf-8").read()
        n = s.count(old)
        if n != 1:
            sys.exit("patch for %s matched %d times (expected 1)" % (rel, n))
        open(p, "w", encoding="utf-8").write(s.replace(old, new))

    # 4. English texts: the original's, then ours on top
    en_src = os.path.join(src, "lua", "shared", "Translate", "EN")
    en_dst = os.path.join(dst, "lua", "shared", "Translate", "EN")
    en_ours = os.path.join(OURS, "media", "lua", "shared", "Translate", "EN")
    for f in sorted(set(os.listdir(en_src)) | set(os.listdir(en_ours) if os.path.isdir(en_ours) else [])):
        merged = {}
        if os.path.exists(os.path.join(en_src, f)):
            merged.update(json.load(open(os.path.join(en_src, f), encoding="utf-8")))
        n_orig = len(merged)
        if os.path.exists(os.path.join(en_ours, f)):
            merged.update(json.load(open(os.path.join(en_ours, f), encoding="utf-8")))
        open(os.path.join(en_dst, f), "w", encoding="utf-8").write(json.dumps(merged, ensure_ascii=False, indent=4) + "\n")
        print("EN %-18s original %4d + ours -> %4d" % (f, n_orig, len(merged)))
    # sandbox options: the original's, then ours
    so = open(os.path.join(src, "sandbox-options.txt"), encoding="utf-8").read().rstrip()
    ours_so = os.path.join(OURS, "media", "sandbox-options.txt")
    if os.path.exists(ours_so):
        body = open(ours_so, encoding="utf-8").read()
        body = body.split("\n", 1)[1] if body.startswith("VERSION") else body
        so += "\n\n/* ---- HARMONIE options ---- */\n" + body
    open(os.path.join(dst, "sandbox-options.txt"), "w", encoding="utf-8").write(so + "\n")

    open(LIST, "w", encoding="utf-8").write("\n".join(sorted(imported)) + "\n")
    print("imported %d files, %.0f MB; left out: %s" % (len(imported), size / 1e6, ", ".join(EXCLUDE)))


if __name__ == "__main__":
    main()

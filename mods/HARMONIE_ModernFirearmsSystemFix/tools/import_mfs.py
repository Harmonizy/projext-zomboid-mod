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
import glob
import re
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
    # the original's Chinese mod-list name ("AAA_...") would show instead of ours
    "lua/shared/Translate/CN/Mod.json",
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

# HARMONIE Hub (2026-10-09): the original's right-click handlers are
# registered through HARMONIE_Ours, so their options get the H icon and stay
# together with our other mods' options (shared/000_HARMONIE_HubBoot.lua)
HUB_WRAP = "(HARMONIE_Ours or function(f) return f end)"
for _rel, _fn in [
        ("lua/server/FixWeapon.lua", "createInventoryMenuEntry"),
        ("lua/client/PartAbility/LaserAndLight/BatterySet.lua", "SendItem"),
        ("lua/client/UI/risky_inspect_set.lua", "riskyUI.createInventoryMenuEntry"),
        ("lua/client/FixWeapon.lua", "addRepairOption"),
        ("lua/client/IOInput.lua", "createInventoryMenuEntry")]:
    PATCHES.append((_rel, "Events.OnFillInventoryObjectContextMenu.Add(%s)" % _fn,
                    'Events.OnFillInventoryObjectContextMenu.Add(%s(%s, "MFS"))' % (HUB_WRAP, _fn)))


# translations merged (original + tools/ours on top) instead of copied
MERGED_LANGS = ["EN", "TH"]


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
            merged_here = rel.replace(os.sep, "/") == "sandbox-options.txt" or \
                any(rel.replace(os.sep, "/").startswith("lua/shared/Translate/%s/" % lang) for lang in MERGED_LANGS)
            if os.path.exists(b) and not merged_here:
                sys.exit("would overwrite our own file: %s" % b)
            os.makedirs(os.path.dirname(b), exist_ok=True)
            if merged_here:
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

    # 4. English and Thai texts: the original's, then ours on top (ours: the
    # missing English, and HARMONIE's Thai -- it used to live in the Thai
    # translation mod, which is now only for other people's mods)
    for lang in MERGED_LANGS:
        l_src = os.path.join(src, "lua", "shared", "Translate", lang)
        l_dst = os.path.join(dst, "lua", "shared", "Translate", lang)
        l_ours = os.path.join(OURS, "media", "lua", "shared", "Translate", lang)
        os.makedirs(l_dst, exist_ok=True)
        names = set(os.listdir(l_src) if os.path.isdir(l_src) else []) | set(os.listdir(l_ours) if os.path.isdir(l_ours) else [])
        for f in sorted(names):
            merged = {}
            if os.path.exists(os.path.join(l_src, f)):
                merged.update(json.load(open(os.path.join(l_src, f), encoding="utf-8")))
            n_orig = len(merged)
            if os.path.exists(os.path.join(l_ours, f)):
                merged.update(json.load(open(os.path.join(l_ours, f), encoding="utf-8")))
            open(os.path.join(l_dst, f), "w", encoding="utf-8").write(json.dumps(merged, ensure_ascii=False, indent=4) + "\n")
            print("%s %-18s original %4d + ours -> %4d" % (lang, f, n_orig, len(merged)))
    # sandbox options: the original's, then ours
    so = open(os.path.join(src, "sandbox-options.txt"), encoding="utf-8").read().rstrip()
    ours_so = os.path.join(OURS, "media", "sandbox-options.txt")
    if os.path.exists(ours_so):
        body = open(ours_so, encoding="utf-8").read()
        body = body.split("\n", 1)[1] if body.startswith("VERSION") else body
        so += "\n\n/* ---- HARMONIE options ---- */\n" + body
    # 2026-10-11 (owner: "ม็อด 1 ม็อด ต่อ 1 tab sandbox setting"): every
    # option on this mod's one sandbox page
    so = re.sub(r"(?m)^(\s*page\s*=\s*)[A-Za-z0-9_]+,", r"\1HARMONIE_ModernFirearmsSystemFix,", so)
    open(os.path.join(dst, "sandbox-options.txt"), "w", encoding="utf-8").write(so + "\n")

    open(LIST, "w", encoding="utf-8").write("\n".join(sorted(imported)) + "\n")
    print("imported %d files, %.0f MB; left out: %s" % (len(imported), size / 1e6, ", ".join(EXCLUDE)))
    strip_vanilla_copies(dst)


# 2026-10-11: the original ships, for ~25 languages, whole copies of the
# GAME's own text files (ContextMenu, UI, Sandbox, IG_UI...) from an older
# build. Loaded after vanilla they replaced the game's current texts -- a
# stale Thai "ContextMenu_EvolvedRecipe_RecipeNameNew" broke vanilla's
# ISAddItemInRecipe (MissingFormatArgumentException when a dish was made).
# Keep only what is this mod's: keys in its English files, keys its own code
# or scripts use, its item names, and anything named MFS / Gunpart.
def strip_vanilla_copies(dst):
    import json, re
    T = os.path.join(dst, "lua", "shared", "Translate")
    en = set()
    for f in glob.glob(os.path.join(T, "EN", "*.json")):
        en |= set(json.load(open(f, encoding="utf-8")))
    words, items = set(), set()
    for f in glob.glob(os.path.join(dst, "**", "*.lua"), recursive=True) + glob.glob(os.path.join(dst, "scripts", "**", "*.txt"), recursive=True):
        if os.sep + "Translate" + os.sep in f:
            continue
        text = open(f, encoding="utf-8", errors="ignore").read()
        words |= set(re.findall(r"[A-Za-z0-9_.]+", text))
        if f.endswith(".txt"):
            mod = re.findall(r"module\s+(\w+)", text)
            for it in re.findall(r"^\s*item\s+(\w+)", text, re.M):
                items.add((mod[0] if mod else "Base") + "." + it)
    def ours(k):
        return k in en or k in words or k in items or "MFS" in k or "Gunpart" in k or (k.startswith("ItemName_") and k[9:] in items)
    dropped = 0
    for lang in os.listdir(T):
        if lang in MERGED_LANGS:
            continue
        for f in glob.glob(os.path.join(T, lang, "*.json")):
            data = json.load(open(f, encoding="utf-8"))
            keep = {k: v for k, v in data.items() if ours(k)}
            dropped += len(data) - len(keep)
            if not keep:
                os.remove(f)
            elif len(keep) != len(data):
                open(f, "w", encoding="utf-8").write(json.dumps(keep, indent=4, ensure_ascii=False) + "\n")
    print("left out %d copied game texts (not this mod's)" % dropped)


if __name__ == "__main__":
    main()

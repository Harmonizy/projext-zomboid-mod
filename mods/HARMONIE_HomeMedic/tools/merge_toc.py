#!/usr/bin/env python3
"""HARMONIE - Home Medic: merge The Only Cure into this mod.

Run this on YOUR computer (Python 3.8+), like merge_ehr.py. It copies every
file of The Only Cure (Workshop 3580276809, mod id TheOnlyCure, by ZioPao --
https://github.com/ZioPao/The-Only-Cure) into mods/HARMONIE_HomeMedic/42/,
so Home Medic no longer needs TheOnlyCure enabled.

Kept exactly as TOC has them (saves and HARMONIE_TooManyModThai keep
working): Lua paths (require("TOC/...")), item/clothing/model names, the
sandbox namespace (SandboxVars.TOC), ModData, trait and body-location ids,
translation keys.

Merged instead of copied (a mod can only have one of each):
  * 42/media/registries.lua -- TOC's code appended between "The Only Cure"
    comment markers (replaced on a rerun);
  * 42/media/sandbox-options.txt -- no comments there: every option TOC
    defines is removed from ours by name and TOC's options appended (its
    "VERSION = 1," dropped);
  * Translate/*/*.json that Home Medic already has -- key by key, ours win.
TOC's common/media (lua_timers.lua) goes into 42/media, which B42 loads the
same way. mod.info: TheOnlyCure dropped from require=, versionMin raised to
TOC's, its loadModAfter= / incompatible= carried over, credit added.
Writes TOC_MERGE_MANIFEST.txt. Rerunnable; --dry-run; --force as in
merge_ehr.py.

Usage (from the Zomboid folder that holds mods/):
  python mods/HARMONIE_HomeMedic/tools/merge_toc.py --toc PATH [--force] [--dry-run]
then rebrand the visible text (keys keep their original names):
  python mods/HARMONIE_HomeMedic/tools/rebrand_homemedic.py
PATH = the TOC zip, its Workshop folder (...\\108600\\3580276809) or the mod
folder (The-Only-Cure).
"""
import argparse, os, re, shutil, sys, tempfile, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from merge_ehr import sha, read_info, merge_json  # noqa: E402

TOC_ID = "TheOnlyCure"
NEW_VERSION = (0, 4, 0)
CREDIT = ("Includes The Only Cure (Workshop 3580276809, mod id TheOnlyCure, by ZioPao, "
          "github.com/ZioPao/The-Only-Cure) merged in with permission.")
BEGIN = "The Only Cure (merged by tools/merge_toc.py) >>>"
END = "<<< The Only Cure"
APPENDED = {"media/registries.lua": "--", "media/sandbox-options.txt": "/*"}
SKIP_EXT = {".bak"}
SKIP_NAMES = {"Mod.json"}   # TOC's name/description would rename Home Medic in the mod list


def find_toc_root(start):
    for root, dirs, files in os.walk(start):
        if "mod.info" in files and os.path.basename(root) == "42":
            if read_info(os.path.join(root, "mod.info")).get("id") == TOC_ID:
                return os.path.dirname(root)
    return None


def append_block(src, dst, rel, dry):
    text = open(src, encoding="utf-8-sig").read()
    ours = open(dst, encoding="utf-8-sig").read() if os.path.exists(dst) else ""
    if rel.endswith("sandbox-options.txt"):
        # No comment markers in this file (its parser is not a Lua/script one):
        # drop every option block TOC defines (by name), then append TOC's.
        text = re.sub(r"^\s*VERSION\s*=\s*\d+\s*,\s*\n", "", text, count=1)
        names = re.findall(r"^option\s+(\S+)", text, re.M)   # TOC.* and MultiplierConfig.*
        base = ours
        for n in names:
            base = re.sub(r"^option\s+" + re.escape(n) + r"\s*\n\{.*?^\}\s*\n?", "", base, flags=re.S | re.M)
        base = base.rstrip()
        merged = base + "\n\n" + text.strip() + "\n"
    else:
        pat = re.compile(r"-- " + re.escape(BEGIN) + r".*?-- " + re.escape(END) + r"\n?", re.S)
        new_block = "-- " + BEGIN + "\n" + text.rstrip() + "\n-- " + END + "\n"
        if pat.search(ours):
            merged = pat.sub(lambda m: new_block, ours, count=1)
        else:
            merged = ours.rstrip() + "\n\n" + new_block
    if merged == ours:
        return "same"
    if not dry:
        with open(dst, "w", encoding="utf-8", newline="\n") as f:
            f.write(merged)
    return "merged"


def update_mod_info(path, toc_info, dry):
    with open(path, encoding="utf-8-sig") as f:
        lines = f.read().splitlines()
    keys = {l.split("=", 1)[0].strip() for l in lines if "=" in l}
    out, changed = [], []
    for line in lines:
        key = line.split("=", 1)[0].strip() if "=" in line else ""
        val = line.split("=", 1)[1] if "=" in line else ""
        if key == "require":
            reqs = [r.strip() for r in val.split(",") if r.strip()]
            kept = [r for r in reqs if r.lstrip("\\") != TOC_ID]
            if kept != reqs:
                changed.append("require: removed " + TOC_ID)
            if kept:
                out.append("require=" + ",".join(kept))
            continue
        if key == "modversion":
            cur = tuple(int(x) for x in re.findall(r"\d+", val)[:3])
            if cur < NEW_VERSION:
                line = "modversion=" + ".".join(map(str, NEW_VERSION))
                changed.append("modversion -> " + line.split("=")[1])
        if key == "versionMin" and toc_info.get("versionMin"):
            ver = lambda s: tuple(int(x) for x in re.findall(r"\d+", s))
            if ver(toc_info["versionMin"]) > ver(val):
                line = "versionMin=" + toc_info["versionMin"]
                changed.append("versionMin -> " + toc_info["versionMin"])
        if key in ("loadModAfter", "incompatible") and toc_info.get(key):
            have = [x.strip() for x in val.split(",") if x.strip()]
            add = [x.strip() for x in toc_info[key].split(",") if x.strip() and x.strip() not in have]
            if add:
                line = key + "=" + ",".join(have + add)
                changed.append(key + ": added " + ",".join(add))
        if key == "description" and "3580276809" not in line:
            line = line + " " + CREDIT + " (TOC " + toc_info.get("modversion", "?") + ")"
            changed.append("description: credit added")
        out.append(line)
    for key in ("loadModAfter", "incompatible"):
        if key not in keys and toc_info.get(key):
            out.append(key + "=" + toc_info[key])
            changed.append(key + " added")
    if changed and not dry:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(out) + "\n")
    return changed


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--toc", required=True, help="TOC zip / Workshop folder / mod folder")
    ap.add_argument("--mod", default=os.path.dirname(HERE), help="HARMONIE_HomeMedic folder (default: this script's mod)")
    ap.add_argument("--force", action="store_true", help="overwrite files of ours that differ from TOC's")
    ap.add_argument("--dry-run", action="store_true", help="only report what would happen")
    a = ap.parse_args()

    tmp, src = None, a.toc
    if os.path.isfile(src) and zipfile.is_zipfile(src):
        tmp = tempfile.mkdtemp(prefix="toc_")
        with zipfile.ZipFile(src) as z:
            z.extractall(tmp)
        src = tmp
    try:
        root = find_toc_root(src)
        if not root:
            sys.exit("ERROR: no 42/mod.info with id=%s found under %s" % (TOC_ID, a.toc))
        toc_info = read_info(os.path.join(root, "42", "mod.info"))
        mod42 = os.path.join(os.path.abspath(a.mod), "42")
        if not os.path.isfile(os.path.join(mod42, "mod.info")):
            sys.exit("ERROR: %s is not the Home Medic mod folder (no 42/mod.info)" % a.mod)
        print("TOC   :", root, "(version %s)" % toc_info.get("modversion", "?"))
        print("Target:", mod42, "(dry run)" if a.dry_run else "")

        sources = [os.path.join(root, "42", "media"), os.path.join(root, "common", "media")]
        copied = same = merged = 0
        conflicts, manifest = [], []
        for media_src in sources:
            if not os.path.isdir(media_src):
                continue
            base = os.path.dirname(media_src)
            for dirpath, _, files in os.walk(media_src):
                for name in files:
                    if os.path.splitext(name)[1].lower() in SKIP_EXT or name in SKIP_NAMES:
                        continue
                    s = os.path.join(dirpath, name)
                    rel = os.path.relpath(s, base).replace(os.sep, "/")      # media/...
                    d = os.path.join(mod42, rel)
                    manifest.append(rel)
                    if rel in APPENDED:
                        state = append_block(s, d, rel, a.dry_run)
                        merged += state == "merged"
                        same += state == "same"
                        continue
                    if os.path.exists(d):
                        if sha(s) == sha(d):
                            same += 1
                            continue
                        if rel.startswith("media/lua/shared/Translate/") and name.endswith(".json"):
                            state, clash = merge_json(s, d, a.dry_run)
                            merged += state == "merged"
                            same += state == "same"
                            for k in clash:
                                print("  note: kept our text for", k, "in", rel)
                            continue
                        if not a.force:
                            conflicts.append(rel)
                            continue
                    if not a.dry_run:
                        os.makedirs(os.path.dirname(d), exist_ok=True)
                        shutil.copy2(s, d)
                    copied += 1
        if conflicts:
            print("\nSTOPPED -- these files of ours differ from TOC's (rerun with --force to take TOC's):")
            for c in conflicts:
                print("  ", c)
            sys.exit(1)

        changes = update_mod_info(os.path.join(mod42, "mod.info"), toc_info, a.dry_run)
        if not a.dry_run:
            with open(os.path.join(os.path.abspath(a.mod), "TOC_MERGE_MANIFEST.txt"), "w", encoding="utf-8", newline="\n") as f:
                f.write("# Files merged from The Only Cure %s (Workshop 3580276809)\n" % toc_info.get("modversion", "?"))
                f.write("# by tools/merge_toc.py -- paths relative to 42/ (common/media mapped into 42/media)\n")
                f.write("\n".join(sorted(set(manifest))) + "\n")
        print("\ncopied %d, already identical %d, merged (translations / registries / sandbox) %d" % (copied, same, merged))
        for c in changes:
            print("mod.info:", c)
        print("\nNext: disable The Only Cure (do NOT run both), then")
        print("  bash mods/sync_to_workshop.sh HARMONIE_HomeMedic 42")
    finally:
        if tmp:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()

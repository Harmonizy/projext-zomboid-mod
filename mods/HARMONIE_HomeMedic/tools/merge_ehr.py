#!/usr/bin/env python3
"""HARMONIE - Home Medic: merge Extensive Health Rework Evolved into this mod.

Run this on YOUR computer (Python 3.8+). It copies every file of EHR B42
(Workshop 3726328119, mod id ExtensiveHealthReworkEvolved) into
mods/HARMONIE_HomeMedic/42/, so Home Medic no longer needs EHR enabled.

What it keeps exactly as EHR has them (so existing saves and the Thai
translation in HARMONIE_TooManyModThai keep working):
  * Lua file paths (require "ExtensiveHealth/...") and the global EHR table
  * item modules (ExtensiveHealth, Base), sound / trait / profession names
  * sandbox namespace (SandboxVars.ExtensiveHealthRework)
  * player ModData keys (EHR_Blood, EHR_Disease, ...)
  * translation keys

What it changes:
  * Translate/*/*.json that Home Medic already has: merged key by key --
    EHR's keys plus ours, ours win on a clash (none today).
  * 42/mod.info: ExtensiveHealthReworkEvolved removed from require=,
    modversion raised to 0.3.0 (if lower), a credit line added.
  * writes EHR_MERGE_MANIFEST.txt (every file copied, EHR's version).

Never touches EHR's own install. Rerunnable: files already identical are
skipped; a different file of the same path stops the run unless --force.

Usage (from the Zomboid folder that holds mods/):
  python mods/HARMONIE_HomeMedic/tools/merge_ehr.py --ehr PATH [--force] [--dry-run]
PATH = the EHR zip, its Workshop folder (...\\108600\\3726328119) or the mod
folder (ExtensiveHealthReworkB42) -- the script finds 42/media inside.
"""
import argparse, hashlib, json, os, re, shutil, sys, tempfile, zipfile

EHR_ID = "ExtensiveHealthReworkEvolved"
NEW_VERSION = (0, 3, 0)
CREDIT = ("Includes Extensive Health Rework Evolved B42 (Workshop 3726328119, "
          "mod id ExtensiveHealthReworkEvolved) merged in with its author's permission.")
SKIP_EXT = {".bak"}


def sha(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def read_info(path):
    info = {}
    with open(path, encoding="utf-8-sig") as f:
        for line in f:
            if "=" in line:
                k, v = line.rstrip("\r\n").split("=", 1)
                info.setdefault(k.strip(), v)
    return info


def find_ehr_root(start):
    """The folder with mod.info (id=EHR) and 42/media."""
    for root, dirs, files in os.walk(start):
        if "mod.info" in files and os.path.isdir(os.path.join(root, "42", "media")):
            if read_info(os.path.join(root, "mod.info")).get("id") == EHR_ID:
                return root
    return None


def merge_json(src, dst, dry):
    with open(src, encoding="utf-8-sig") as f:
        theirs = json.load(f)
    with open(dst, encoding="utf-8-sig") as f:
        ours = json.load(f)
    merged = dict(theirs)
    clash = [k for k in ours if k in theirs and ours[k] != theirs[k]]
    merged.update(ours)                                   # ours win
    if merged == ours:
        return "same", clash
    if not dry:
        with open(dst, "w", encoding="utf-8", newline="\n") as f:
            json.dump(merged, f, ensure_ascii=False, indent=4)
            f.write("\n")
    return "merged", clash


def update_mod_info(path, ehr_version, dry):
    with open(path, encoding="utf-8-sig") as f:
        lines = f.read().splitlines()
    out, changed = [], []
    for line in lines:
        key = line.split("=", 1)[0].strip() if "=" in line else ""
        if key == "require":
            reqs = [r.strip() for r in line.split("=", 1)[1].split(",") if r.strip()]
            kept = [r for r in reqs if r != EHR_ID]
            if kept != reqs:
                changed.append("require: removed " + EHR_ID)
            if kept:
                out.append("require=" + ",".join(kept))
            continue
        if key == "modversion":
            cur = tuple(int(x) for x in re.findall(r"\d+", line.split("=", 1)[1])[:3])
            if cur < NEW_VERSION:
                line = "modversion=" + ".".join(map(str, NEW_VERSION))
                changed.append("modversion -> " + ".".join(map(str, NEW_VERSION)))
        if key == "description" and "3726328119" not in line:
            line = line + " " + CREDIT + " (EHR " + ehr_version + ")"
            changed.append("description: credit added")
        out.append(line)
    if changed and not dry:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(out) + "\n")
    return changed


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ehr", required=True, help="EHR zip / Workshop folder / mod folder")
    ap.add_argument("--mod", default=os.path.dirname(here), help="HARMONIE_HomeMedic folder (default: this script's mod)")
    ap.add_argument("--force", action="store_true", help="overwrite files of ours that differ from EHR's")
    ap.add_argument("--dry-run", action="store_true", help="only report what would happen")
    a = ap.parse_args()

    tmp = None
    src = a.ehr
    if os.path.isfile(src) and zipfile.is_zipfile(src):
        tmp = tempfile.mkdtemp(prefix="ehr_")
        with zipfile.ZipFile(src) as z:
            z.extractall(tmp)
        src = tmp
    try:
        root = find_ehr_root(src)
        if not root:
            sys.exit("ERROR: no mod.info with id=%s and a 42/media folder found under %s" % (EHR_ID, a.ehr))
        ehr_version = read_info(os.path.join(root, "mod.info")).get("modversion", "?")
        mod42 = os.path.join(os.path.abspath(a.mod), "42")
        if not os.path.isfile(os.path.join(mod42, "mod.info")):
            sys.exit("ERROR: %s is not the Home Medic mod folder (no 42/mod.info)" % a.mod)
        print("EHR   :", root, "(version %s)" % ehr_version)
        print("Target:", mod42, "(dry run)" if a.dry_run else "")

        media_src = os.path.join(root, "42", "media")
        copied, same, merged, conflicts, manifest = 0, 0, 0, [], []
        for dirpath, _, files in os.walk(media_src):
            for name in files:
                if os.path.splitext(name)[1].lower() in SKIP_EXT:
                    continue
                s = os.path.join(dirpath, name)
                rel = os.path.relpath(s, os.path.join(root, "42"))
                d = os.path.join(mod42, rel)
                manifest.append(rel.replace(os.sep, "/"))
                if os.path.exists(d):
                    if sha(s) == sha(d):
                        same += 1
                        continue
                    if rel.replace(os.sep, "/").startswith("media/lua/shared/Translate/") and name.endswith(".json"):
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
            print("\nSTOPPED -- these files of ours differ from EHR's (rerun with --force to take EHR's):")
            for c in conflicts:
                print("  ", c)
            sys.exit(1)

        changes = update_mod_info(os.path.join(mod42, "mod.info"), ehr_version, a.dry_run)
        if not a.dry_run:
            with open(os.path.join(os.path.abspath(a.mod), "EHR_MERGE_MANIFEST.txt"), "w", encoding="utf-8", newline="\n") as f:
                f.write("# Files merged from Extensive Health Rework Evolved %s (Workshop 3726328119)\n" % ehr_version)
                f.write("# by tools/merge_ehr.py -- paths relative to 42/\n")
                f.write("\n".join(sorted(manifest)) + "\n")
        print("\ncopied %d, already identical %d, translation files merged %d" % (copied, same, merged))
        for c in changes:
            print("mod.info:", c)
        print("\nNext: disable Extensive Health Rework Evolved (do NOT run both), then")
        print("  bash mods/sync_to_workshop.sh HARMONIE_HomeMedic 42")
    finally:
        if tmp:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()

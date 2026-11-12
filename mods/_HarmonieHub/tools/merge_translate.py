#!/usr/bin/env python3
"""Hub texts (IGUI_HUB_*): master copy in mods/_HarmonieHub/translate/<LANG>.json.
Writes them into <target>/media/lua/shared/Translate/<LANG>/IG_UI.json of each
target given (replacing old values, adding new keys at the end)."""
import json, os, sys
here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for target in sys.argv[1:]:
    for lang in ("EN", "TH"):
        master = json.load(open(os.path.join(here, "translate", lang + ".json"), encoding="utf-8"))
        path = os.path.join(target, "media/lua/shared/Translate", lang, "IG_UI.json")
        if not os.path.exists(path):
            print("  no", path); continue
        d = json.load(open(path, encoding="utf-8"))
        n = 0
        for k, v in master.items():
            if d.get(k) != v:
                d[k] = v; n += 1
        with open(path, "w", encoding="utf-8") as f:
            json.dump(d, f, ensure_ascii=False, indent=4); f.write("\n")
        print("  texts %s -> %s (%d changed)" % (lang, os.path.relpath(path, os.path.dirname(here)), n))

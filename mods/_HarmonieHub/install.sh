#!/bin/bash
# HARMONIE Hub: copy the shared hub files (master copy here) into every
# HARMONIE mod that has a right-click or a window. The game loads one copy
# of a path, so the copies must stay identical -- always edit here, then run:
#     bash mods/_HarmonieHub/install.sh
# (then bump each mod's modversion and sync_to_workshop.sh as usual)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
MODS="$(dirname "$HERE")"
FILES="media/lua/shared/000_HARMONIE_HubBoot.lua media/lua/client/HARMONIE_Hub.lua media/lua/client/HARMONIE_UIKit.lua media/ui/HARMONIE_H.png media/ui/HARMONIE_icon_close.png media/ui/HARMONIE_icon_settings.png media/ui/HARMONIE_icon_check.png media/ui/HARMONIE_icon_minus.png media/ui/HARMONIE_icon_plus.png media/ui/HARMONIE_icon_left.png media/ui/HARMONIE_icon_right.png"
for mod in HARMONIE_GardenToPlate HARMONIE_TheWayToAttack HARMONIE_HomeMedic HARMONIE_SVU3Sandbox HARMONIE_ModernFirearmsSystemFix; do
    targets="$MODS/$mod/42"
    # Modern Firearms re-imports the original's files; its own files live in tools/ours
    [ -d "$MODS/$mod/tools/ours" ] && targets="$targets $MODS/$mod/tools/ours"
    for t in $targets; do
        for f in $FILES; do
            mkdir -p "$t/$(dirname "$f")"
            cp "$HERE/$f" "$t/$f"
        done
        echo "hub -> ${t#$MODS/}"
    done
done

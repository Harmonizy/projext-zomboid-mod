#!/usr/bin/env bash
# Read-only check: for every mod that has a Workshop/<ModId>/ staging folder,
# diff it against the corresponding mods/<ModId>/<version>/ dev copy and report
# whether they match. Does NOT modify anything -- use sync_to_workshop.sh to fix
# drift it finds.
#
# Note: the Contents/mods/<InnerId>/ subfolder name is NOT assumed to match
# <ModId> (the outer Workshop/ folder name) -- they can legitimately differ, e.g.
# HARMONIE_TooManyModThaiTranslate's own mod.info declares
# id=HARMONIE_TooManyModThai. This script diffs against whatever inner folder(s)
# actually exist in staging, whatever their name.
#
# Run this FIRST whenever a code/asset change "seems to have no effect" in-game,
# BEFORE assuming it's the learned-tracks cache bug (workflow.txt section 6.1) or
# anything else -- the game may simply be loading a stale Workshop/ staging copy
# instead of mods/. See workflow.txt section 1 for the incident this exists to
# catch quickly (JoJo_FightingGold silent-forever bug, 2026-09-16).
#
# Usage: mods/check_workshop_sync.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANY_DRIFT=0

for workshop_dir in "$REPO_ROOT"/Workshop/*/; do
    MOD_ID="$(basename "$workshop_dir")"
    [ "$MOD_ID" = "ModTemplate" ] && continue

    MODS_DIR="$REPO_ROOT/mods/$MOD_ID"
    STAGING_MODS_DIR="${workshop_dir}Contents/mods"

    if [ ! -d "$MODS_DIR" ] || [ ! -d "$STAGING_MODS_DIR" ]; then
        echo "SKIP  $MOD_ID (missing mods/ or staging Contents/mods/ folder)"
        continue
    fi

    # inner id folder(s) actually present in staging -- may differ from $MOD_ID
    INNER_IDS=()
    for d in "$STAGING_MODS_DIR"/*/; do
        [ -d "$d" ] && INNER_IDS+=("$(basename "$d")")
    done

    if [ "${#INNER_IDS[@]}" -eq 0 ]; then
        echo "DRIFT $MOD_ID -- staging Contents/mods/ is empty"
        ANY_DRIFT=1
        continue
    fi
    if [ "${#INNER_IDS[@]}" -gt 1 ]; then
        echo "WARN  $MOD_ID -- staging has multiple inner folders: ${INNER_IDS[*]} (unexpected)"
    fi
    INNER_ID="${INNER_IDS[0]}"
    STAGING_INNER_DIR="$STAGING_MODS_DIR/$INNER_ID"

    for version_dir in "$MODS_DIR"/*/; do
        VERSION="$(basename "$version_dir")"
        SRC="$MODS_DIR/$VERSION"
        DST="$STAGING_INNER_DIR/$VERSION"

        if [ ! -d "$DST" ]; then
            echo "DRIFT $MOD_ID/$VERSION -- staging copy missing entirely (looked in $STAGING_INNER_DIR)"
            ANY_DRIFT=1
            continue
        fi

        if diff -rq "$SRC" "$DST" > /tmp/workshop_sync_diff_$$.txt 2>&1; then
            echo "OK    $MOD_ID/$VERSION"
        else
            echo "DRIFT $MOD_ID/$VERSION"
            sed 's/^/      /' /tmp/workshop_sync_diff_$$.txt
            ANY_DRIFT=1
        fi
        rm -f /tmp/workshop_sync_diff_$$.txt
    done
done

if [ "$ANY_DRIFT" -eq 1 ]; then
    echo
    echo "Drift found. Fix with: mods/sync_to_workshop.sh <ModId> <version>"
    exit 1
else
    echo
    echo "All mods in sync."
fi

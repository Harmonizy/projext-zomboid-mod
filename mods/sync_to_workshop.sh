#!/usr/bin/env bash
# Mirrors mods/<ModId>/<version>/ -> Workshop/<ModId>/Contents/mods/<InnerId>/<version>/
# exactly (deletes stale files in the staging copy, then copies everything fresh,
# .ogg / other gitignored assets included). Run this after ANY edit to a mod that
# already has a Workshop/<ModId>/ staging folder -- the game may be loading mods
# from THAT copy, not from mods/, depending on which entry is enabled in the
# in-game mod list. See workflow.txt section 1 for the incident this fixes
# (JoJo_FightingGold silent-forever bug, 2026-09-16: staging copy was missing the
# .ogg file entirely and had a stale length= value, because sync was done by hand
# with selective `cp` calls that missed a file).
#
# <ModId> here is the folder name under mods/ and Workshop/ -- NOT necessarily the
# same as the mod's internal id= (HARMONIE_TooManyModThaiTranslate's own mod.info
# declares id=HARMONIE_TooManyModThai, a pre-existing mismatch; found and fixed a
# script bug over this exact case, 2026-09-16 -- never assume folder name == id=).
# <InnerId> (the Contents/mods/<InnerId>/ subfolder) is auto-detected from whatever
# already exists in the staging folder; only falls back to reading id= from mod.info
# if the staging folder doesn't exist yet at all.
#
# Usage: mods/sync_to_workshop.sh <ModId> [version]
#   version defaults to "42"

set -euo pipefail

MOD_ID="${1:?Usage: sync_to_workshop.sh <ModId> [version]}"
VERSION="${2:-42}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/mods/$MOD_ID/$VERSION"
STAGING_MODS_DIR="$REPO_ROOT/Workshop/$MOD_ID/Contents/mods"

if [ ! -d "$SRC" ]; then
    echo "ERROR: source folder not found: $SRC" >&2
    exit 1
fi
if [ ! -d "$STAGING_MODS_DIR" ]; then
    echo "ERROR: no Workshop/$MOD_ID/Contents/mods/ staging folder exists -- this mod" >&2
    echo "       has never been set up for Workshop upload, nothing to sync to." >&2
    exit 1
fi

# Auto-detect the inner id folder name from whatever already exists in staging,
# rather than assuming it matches $MOD_ID (see header note -- they can differ).
INNER_ID=""
for d in "$STAGING_MODS_DIR"/*/; do
    name="$(basename "$d")"
    if [ -z "$INNER_ID" ]; then
        INNER_ID="$name"
    elif [ "$name" != "$INNER_ID" ]; then
        echo "ERROR: $STAGING_MODS_DIR contains multiple differently-named folders" >&2
        echo "       ($INNER_ID, $name, ...) -- resolve manually before syncing." >&2
        exit 1
    fi
done

if [ -z "$INNER_ID" ]; then
    # Nothing staged yet at all -- fall back to id= from the local mod.info.
    INFO_FILE="$SRC/mod.info"
    if [ ! -f "$INFO_FILE" ]; then
        echo "ERROR: staging is empty and $INFO_FILE doesn't exist to read id= from." >&2
        exit 1
    fi
    INNER_ID="$(grep -m1 '^id=' "$INFO_FILE" | cut -d= -f2- | tr -d '\r')"
    if [ -z "$INNER_ID" ]; then
        echo "ERROR: could not read id= from $INFO_FILE" >&2
        exit 1
    fi
    echo "NOTE: staging folder was empty, using id=$INNER_ID from mod.info"
fi

DST_PARENT="$STAGING_MODS_DIR/$INNER_ID"
DST="$DST_PARENT/$VERSION"

echo "Syncing $SRC"
echo "     -> $DST"

rm -rf "$DST"
mkdir -p "$DST_PARENT"
cp -r "$SRC" "$DST"

if diff -r "$SRC" "$DST" > /dev/null 2>&1; then
    echo "OK: staging copy now matches mods/ exactly."
else
    echo "WARNING: staging copy still differs after sync -- investigate:" >&2
    diff -r "$SRC" "$DST" || true
    exit 1
fi

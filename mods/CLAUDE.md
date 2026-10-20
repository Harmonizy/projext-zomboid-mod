# Notes for Claude

## Logging (owner's rule, always)
- Every feature or fix writes to console.txt — when unsure, and also when sure,
  because a later edit might break it. The log is how bugs get found in the
  real game.
- GardenToPlate: use `HARMONIE_GTP.Log(tag, fmt, ...)` (prints
  `[HARMONIE_GTP][tag][SP|client|server] ...`). For anything that repeats
  every tick or every frame, use `HARMONIE_GTP.LogOnce(key, tag, fmt, ...)`
  or log only on state changes. Never flood the log every frame or tick.
- Other mods (same idea, each has its own helper):
  | mod | prefix | helper |
  |---|---|---|
  | TheWayToAttack | `[HARMONIE_TWA]` | `TWALog`, `TWALogOnce`, `TWALogErr`, `TWALogName`, `TWALogType`, `TWALogAction(cls, name)` (timed actions), `TWALogMethods(cls, tag, {names})` (window buttons) — `shared/000_HARMONIE_TWA_Log.lua` |
  | HomeMedic = "HARMONIE - How to Survive" (own HM code) | `[HARMONIE_HM]` | `HMLog`, `HMLogOnce`, `HMLogErr`, `HMLogName`, `HMLogType`, `HMLogMethods` — `shared/HARMONIEHomeMedic/000_HM_Log.lua` (bundled EHR / TOC keep their own `[EHR` / `[TOC` prints) |
  | SVU3Sandbox = "HARMONIE - Car for Crash" | `[HARMONIE_SVU3]` | local `log` / `logOnce` per file (`C.log` in SkillCap) |
  | ModernFirearmsSystemFix = "HARMONIE - Mercenary Is Life" | `[HARMONIE_MFSFix]` | local `log` / `logOnce` per file |
  | LifestyleAudioTune | `[HARMONIE_LAT]` | local `log` / `logOnce` per file |
  | LifeWithStyle = "HARMONIE - Life With Style" | `[HARMONIE_LWS]` | `LWS.log(tag, fmt, ...)`, `LWS.logOnce(key, tag, fmt, ...)` -- `shared/HARMONIELifeWithStyle/LWS_Core.lua` |
  | PerfProbe | `[PerfProbe` | the mod itself is a log |
- A log line must never break the game: read item / player names through
  the safe helpers (`TWALogType(item)`, `HMLogName(p)`, ...), never
  `item:getFullType()` directly inside a log call.
- Log: load or setup results (counts), every network message that is
  rejected or dropped, fallbacks taken (a missing API, a pcall failure),
  user actions in our windows, and first-time / daily summaries.

## Vanilla B42 reference (look things up, don't guess)
- `mods/_VanillaReference_B42/` -- lookup lists made from the game's own
  scripts: `items_index.txt` (every item type + English name),
  `food_index.txt` (nutrition, EvolvedRecipe), `evolvedrecipes_index.txt`,
  `evolvedrecipe_ingredients.txt` (what may go into each recipe, `|Cooked`),
  `craftrecipes_index.txt`, `tags_index.txt`. Read its README.txt.
- Check every vanilla item type, tag or recipe name there before using it.
- `raw/` (the vanilla files themselves) is gitignored on purpose: the repo
  is public. Rebuild with `build_index.py` after a game update.

## Known traps (each one already broke the real game once)
- `item:hasTag("base:x")` with a STRING: B42 wants an `ItemTag` object. It
  throws, and the game writes the exception to console.txt even inside
  pcall -- every frame if it is in a render path (GTP 0.13.4, 1618 times).
  Look item types up instead (GTP `HARMONIE_CookTagItems.lua`, generated
  from `tags_index.txt`), or use `ItemTag[...]` / `ItemTag.get(ResourceLocation.of(...))`.
- `getText(key, ...)` with fewer arguments than the text's `%N` ("Missing
  arguments"). No bare `%` in translations.
- Never `transmitModData()` from a client; MP stats and zombie health live
  on the server (`isClient()` = remote client).
- A PR that is merged is finished: check its state before pushing more.


## HARMONIE Hub (shared by our mods)
- Master copy: `mods/_HarmonieHub/` -- edit there, then
  `bash mods/_HarmonieHub/install.sh` (copies it into GTP, TWA, HomeMedic,
  SVU3, Modern Firearms and MFS `tools/ours`, Life With Style). The copies must stay
  identical: the game loads one copy of a path.
- Register every right-click handler of ours through it:
  `Events.OnFill...ContextMenu.Add((HARMONIE_Ours or function(f) return f end)(handler, "TAG"))`
  -- its options get the H icon and stay together (tag `"debug"` = last).
- Admin / -debug only things go in the HARMONIE debug right-click
  (`Hub.onDebugMenu`); a new window of ours gets a card in `Hub.CARDS`
  (with `need` when it needs a target first), a new sandbox page a line in
  `Hub.NAMESPACES`.

## Names and translations
- Display names (2026-10-09): HARMONIE_HomeMedic = "HARMONIE - How to
  Survive", HARMONIE_SVU3Sandbox = "HARMONIE - Car for Crash",
  HARMONIE_ModernFirearmsSystemFix = "HARMONIE - Mercenary Is Life",
  HARMONIE_LifeWithStyle = "HARMONIE - Life With Style" (2026-10-20). The mod
  IDs and folders stay as they are (saves, server configs and Workshop
  subscriptions use the ID).
- Each of our mods carries its own EN and TH texts. The Thai translation mod
  (HARMONIE_TooManyModThaiTranslate) is only for other people's mods: never
  put a key of ours there.

## Life With Style (fashion)
- The wardrobe is server data (global ModData "HARMONIE_LWS", by owner key
  -- `LWS.ownerKey`, the one place to change for Discord accounts). Pieces
  are entries, not items; only a WORN piece exists as an item, made by the
  server (`LWS.Server.ensure`) and worn by the client.
- Slots and the catalog live in `tools/gen_lws.py` (one source): run it to
  rewrite registries.lua, the item scripts, LWS_Data.lua and ItemName.json.
  Texts: `tools/texts_lws.py`. Art: `tools/gen_lws_art.py`.
- Every piece has two items: `<Id>` (lws:<slot>, hides the vanilla
  locations of the slot via setHideModel) and `<Id>_Over` (lws:<slot>_over,
  hides nothing). Never put a piece in a loot table.
- Only OUR pieces ever go in the wardrobe (owner, 2026-10-20): grant and
  trade take `LWS.isOurPiece` / catalog ids only, foreign entries are pruned
  at load (catalog check only -- never empty a wardrobe on a failed script
  lookup), and another mod's item worn in an `lws:` slot is taken off.
- Trading (`server/.../LWS_Trade.lua`): server sessions, both agree on the
  same revision, the server re-checks and swaps; any offer change unlocks
  both. Sandbox page HARMONIE_LifeWithStyle (TradeEnabled, TradeMaxDistance).


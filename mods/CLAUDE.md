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
- `next()` does not exist in Kahlua (the game's Lua): "Object tried to
  call nil" every tick (Life With Style 0.2.0). Test emptiness with
  `for _ in pairs(t) do ... end`. The lupa mock tests set `next = nil`.
- `local T = { f = function() return T.x end }`: inside its own
  constructor the local T does not exist yet, so T is the GLOBAL (nil) --
  "attempted index of non-table" (UIKit HMFont, settings window 2026-10-20).
  Declare first: `local T; T = { ... }`.
- Never `transmitModData()` from a client; MP stats and zombie health live
  on the server (`isClient()` = remote client).
- A PR that is merged is finished: check its state before pushing more.
- A firearm with an ammo type of a MOD (`AmmoType = efk:...`, anything
  `AmmoType.register`ed) crashes the game on its first shot in B42.20:
  `IsoBulletTracerEffects.createEffect` NPE, "isoBulletTracerEffectsConfigOption
  is null" -- tracer presets exist only for the ten vanilla ammo types and are
  read from the game's own media/effects, never a mod folder (MIL 0.7.3,
  Requiem_cat). Guns take vanilla ammo types; MIL's
  `shared/HARMONIE_MIL_AmmoCheck.lua` lists any left at game start.
  The three left on mod ammo (MTL30, interceptor crossbow, Flamethrower) are
  out of the world loot with their own ammo (`server/zzz_HARMONIE_MIL_RemovedLoot.lua`,
  MIL 0.7.4); keep Base.GrenadeAmmo (the under-barrel launchers use it).
  bolter_cat too (0.7.5).
- MIL sounds: a name that is neither a `sound` script (MIL or vanilla) nor a
  file in `media/sound/` is silent with no error. An empty `SwingSound = ,`
  fires silently unless `AWCWF_GunShotProfiles[<type>]` exists
  (`EFK_Gun_Shot_Profiles.lua`; aliases at its end). `MountOn` names are
  matched exactly (`MG338_cat` is not `mg338_cat`). AmmoCheck logs guns with
  no shot sound and magazines that are not items (MIL 0.7.5).
- A second mod that defines the same item types and loads LATER wins: the
  owner's MP server also ran the original `ModernFirearmsSystem`, which put its
  efk: ammo types back on our guns (Requiem crashed again, 2026-10-24). MIL
  0.7.7 warns when it is on and puts our vanilla ammo types back with
  `DoParam` (`shared/HARMONIE_MIL_AmmoTypes.lua`, generated from our scripts).
  Check the mod list in the console (`loading <id>` lines) first.
- Vanilla's `ISTimedActionQueue` CLEARS the whole queue when one action turns
  invalid: anything chained behind it (a wait action that calls the next step)
  is gone and the flow hangs. GTP cooking (0.13.14) has an OnTick watchdog
  (`CookFlow.F.watch`: no progress 8 s + character idle -> carry on, 3 times,
  then failed "stuck"); never disable a Cancel button during such a chain.
- Calling a method a Java object does not have (`scriptItem:getSwingSound()`)
  logs "Object tried to call nil" with a stack trace even inside pcall (MIL
  0.7.5 AmmoCheck: 142 per load). Test `obj.method` first.
- `OnWeaponHitCharacter(attacker, target, ...)` fires for EVERY hit -- zombies
  and players too, on the attacker's game, the nearby clients and the server.
  LWS 0.7.5 called `target:getAnimalType()` on zombies: an exception on every
  zombie hit for everyone near it (LWS 0.7.6). Animal checks go through
  `LWS.isAnimal` / `LWS.isPetAnimal` (`instanceof(o, "IsoAnimal")` + method test).
- A Lua syntax error kills the whole file with one console line and no other
  sign (HM_Settings.lua, 2026-10-10 to 10-23: settings rows gone). Before a
  release, load every changed .lua once (lupa `load()` is enough).


## HARMONIE Hub (shared by our mods)
- Master copy: `mods/_HarmonieHub/` -- edit there, then
  `bash mods/_HarmonieHub/install.sh` (copies it into GTP, TWA, HomeMedic,
  SVU3, Modern Firearms and MFS `tools/ours`, Life With Style). The copies must stay
  identical: the game loads one copy of a path.
- Register every right-click handler of ours through it:
  `Events.OnFill...ContextMenu.Add((HARMONIE_Ours or function(f) return f end)(handler, "TAG"))`
  -- its options get the H icon and stay together (tag `"debug"` = last).
- `Hub.CARDS[i].accent`: each card in its mod's window colour (Hub 3).
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
- `Workshop/` folders carry the display name (2026-10-23, the upload screen
  lists them): `Workshop/HARMONIE - Mercenary Is Life/Contents/mods/HARMONIE_ModernFirearmsSystemFix/`.
  `sync_to_workshop.sh <mods/ folder>` finds it by the id inside -- quote the
  path (spaces) when you diff it.
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
- The dress-up page is a paper doll (0.4.0): `doll.png` (256x512, drawn by
  `gen_lws_art.py`) and `LWSWindow.DOLL` (each slot's spot on it, in those
  pixels) go together -- redraw one, check the other. `H.LEFT` / `H.RIGHT`
  stay sorted by the spot's height so the dotted lines do not cross.
  Press + move 5 px = drag (`Win:drop`), no move = click (`Win:click`).
- Pets (0.5.0, `server/.../LWS_Pets.lua`): a piece of the "pet" slot
  (`body = false`: no body location, no item) brings out one animal of our
  own type `lwspet_<breed>` (`shared/Definitions/animal/LWS_PetDefinitions.lua`,
  generated from `PETS` in gen_lws.py; animset = vanilla "raccoon", the
  meshes are rigged to it). The server owns it: follow by pathToCharacter
  (at most every 2.5 s), stay, bring-back by despawn + spawn beside the
  owner, health kept full, never attacks. Every `lwspet_` animal that is not
  an out pet is deleted (`P.sweep`) -- saved chunks bring copies back.
  Deletes are repeated to clients with `PetGone` (the engine's notice is
  unreliable). Animations (0.5.1): Companion Dogs' nodes as NEW files
  `AnimSets/raccoon/<state>/lws*.xml` -- never replace a vanilla raccoon
  file -- each gated on a variable only our pets have (`lwsPet`,
  `lwsNetGait`, `lwsIdle2`...). Animation variables do not travel: the
  server sends `PetAnim`, and an MP client drives its own copies' walk
  (`C.petGaitTick`, from how fast they move). Cats (0.6.0): one type
  `lwspet_cat`, a coat = a breed; `kind` picks the voice (`LWS.PET_VOICE`)
  and the cat-only sit / groom nodes (those clips exist only in the cat
  model -- a node for a missing clip fails silently). Right-click (0.6.1,
  `client/.../LWS_PetMenu.lua`): vanilla's animal menu, pick-up, animal info
  (ISAnimalUI throws: no avatar definition for our types) and the interact
  key are wrapped OFF for `lwspet_` animals only; our menu instead. Petting
  is our timed action with the raccoon pose (`animal = "raccoonboar"`,
  `petanimal`) -- vanilla picks the pose by type and strokes the air. No
  `complete()` on a client-only timed action (MP net-action sync). A pet
  item in an inventory is deleted by the server sweep. Not scared, not hurt
  (0.7.5): `LWS.petProtect` (invincible on EVERY copy -- in MP the shooter's
  own game decides a hit) and `LWS.petCalm` (stress / fear reset each tick)
  call only methods the animal has and log which exist; running away from
  the owner re-paths at once, a stay pet that drifts is stopped, and
  OnWeaponHitCharacter on a pet puts its health back. Assets: Companion Dogs, with permission -- `tools/import_pets.py`
  copies them under `LWSPet_` names; credit in `42/CREDITS_PETS.txt`.
- Gacha items (0.7.0): the owner's own RWZ Retention Items v0.4.2, moved
  in. One source `tools/gen_gacha.py` (items, buffs, EN/TH names and
  descriptions -> `LWS_GachaData.lua`; texts_lws.py imports its TEXTS).
  Item TYPES since 0.7.3 (`scripts/HARMONIE_LWS_gacha_items.txt`, module
  HARMONIE_LWSG, generated; names in ItemName.json via gen_lws.py) but never
  in an inventory: the sweep deletes any `LWS.isGachaItem`. Traded in the Trade
  tab as counts (`TradeOfferGacha`, `s.goffer`, re-checked at the swap).
  Otherwise counts in the wardrobe record (`o.gacha`, `o.gachaSet` for the
  New Dawn pieces equipped, `o.gachaBuffs` in real-time ms), used from the
  "gacha" tab (`server/.../LWS_Gacha.lua`). Effects / numbers / the locked XP
  formula are RWZ's -- change them only when the owner asks. The one real
  item is the Guardian armour layer `HARMONIE_LWSG.GuardianProtectionProxy`
  (own module: the fashion sweep deletes any `HARMONIE_LWS` item it does not
  expect) in body location `lws:gacha_guardian`, worn by the server while
  Guardian / Compound-V runs. Buffs end on death. Client: XP hook, capsule
  runtime, buff tray (`client/.../LWS_GachaClient.lua`).
- Give tab (tab id "admin", 0.7.1): `LWS.isAdmin` = -debug or the access level
  (`LWS.hasAdminAccess`); single player without -debug is NOT an admin. A MP
  client's own -debug shows the tab but the server trusts only the access level
  (isDebugEnabled() on the server is the server's flag); the tab says so.
  `fit()` cuts whole UTF-8 characters (Thai is 3 bytes).
- Icons of things that are not items (gacha): `getTexture("Item_X")` finds a
  bare name only when an item script uses it; fall back to
  `media/textures/Item_X.png` (the window's `texture()` does, 0.7.2).
- Search boxes (`Win:searchBox(key, ...)`): the window's only child widgets,
  shown only in frames that ask for them (`hideUnusedSearch`).
- Trading (`server/.../LWS_Trade.lua`): server sessions, both agree on the
  same revision, the server re-checks and swaps; any offer change unlocks
  both. Sandbox page HARMONIE_LifeWithStyle (TradeEnabled, TradeMaxDistance).


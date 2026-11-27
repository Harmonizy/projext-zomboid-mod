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
- An automatic gun whose CyclicRateMultiplier sits in the engine's no-bullet
  zone (1.8 - 2.9, or 1.4 -- upstream notes in EFK_Exact_RPM.lua) swings and
  plays its shot sound while the trigger is held but fires ONE bullet per
  press (owner 2026-11-17, MP5). The seven that had it (MP5, Kriss Vector,
  AN-94, EMP, Groza, QBZ-192, Minigun: script 1.8 / 1.9, RPM band cyclic 8.0)
  are 1.75 in the scripts and 1020 RPM (cyclic 6.8) in EFK_Exact_RPM since
  MIL 1.0.5; `shared/HARMONIE_MIL_CyclicGuard.lua` (+ tools/ours) DoParams
  1.75 back if another mod overrides it and fixes a held gun still in the
  zone (logged). A new automatic gun: script cyclic below 1.8 and an RPM
  under 1076.
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
- A B42 ModOptions tick box can read back its old value after
  `setValue(false)` (TWA settings window could never untick, 0.73.5):
  `TWAOptions.set` reads it back, writes `.value` / the page's tick box, and
  if it still does not take keeps the value itself (wrapped getValue +
  onChange). Logged as "did not take".
- Calling a method a Java object does not have (`scriptItem:getSwingSound()`)
  logs "Object tried to call nil" with a stack trace even inside pcall (MIL
  0.7.5 AmmoCheck: 142 per load). Test `obj.method` first.
- `OnWeaponHitCharacter(attacker, target, ...)` fires for EVERY hit -- zombies
  and players too, on the attacker's game, the nearby clients and the server.
  LWS 0.7.5 called `target:getAnimalType()` on zombies: an exception on every
  zombie hit for everyone near it (LWS 0.7.6). Animal checks go through
  `LWS.isAnimal` / `LWS.isPetAnimal` (`instanceof(o, "IsoAnimal")` + method test).
- `ISToolTipInv:render()` hooks: other inventory mods render the tooltip with
  `self.item` that is NOT an InventoryItem (Inventory Tetris Grand Master's
  StackTooltips: a stack). `item:getFullType()` on it logs every frame (TWA
  0.73.4). Check `instanceof(item, "InventoryItem")` / `instanceof(item,
  "Food" | "HandWeapon")` before any method call.
- The game REUSES one context-menu object for every right-click (EHR even
  clears `context.origin` itself): a flag set on `context` stays for every
  later menu. LWS 0.6.1-0.7.11 marked `context.lwsPetMenu` and the pet menu
  never showed again. Mark the OPTION you added (`opt.lwsPetMenu`) and scan
  `context.options` -- that list is cleared each time (LWS 0.7.12).
- A line that STARTS with "(" after a complete statement --
  `(A or B)(x)` -- is "ambiguous syntax (function call x new statement)" in
  the game's Lua 5.1 parser: the whole file fails and in MP the client is
  thrown out while connecting (HM 1.0.2 EHR_FlyerHook.lua:308, owner
  2026-11-12). Lua 5.4/5.5 accepts it, so a lupa `load()` check missed it.
  Check with `lupa.lua51` + `loadstring` (scratchpad loadcheck.py does now),
  and call through a named local instead.
- A function that calls a `local function` defined LOWER in the same file
  calls a nil GLOBAL (Lua binds locals at compile time): "Object tried to
  call nil" -- every frame in a tooltip (GTP 1.1.0 buildPrepLines ->
  isPossiblyFood, 671 errors on hover in MP; fixed 1.1.1). The syntax check
  does not see it: define helpers above their first use.
- In the game a Lua string is a JAVA string: a Thai letter is ONE char and
  `s:byte(i)` gives its code point (~3600). UTF-8 byte patterns such as
  `"[\194-\244][\128-\191]*"` never match it -- plain Lua / lupa tests see
  bytes and pass. GTP 1.8.0's note counter did not count Thai, the hub's
  BN.clusters dropped every Thai letter of a word wider than the line. Walk
  characters with a code > 255 = one char, else a UTF-8 lead byte + tail
  (hub `HARMONIE_Banner.nextChar`, GTP `CookNotes.chars`, HM_Surgery charLen).
- `ipairs({ a, b, c })` stops at the first nil: GTP 1.8.0's note window added
  its buttons that way and got NONE in write mode (owner: "can't close").
  Loop over a list of names / keys instead.
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
- Every mod is 1.0.0 since 2026-11-12 (owner's 1.0.0 list: MP-safe items,
  items from body / bags / boxes in the room, admin things in the debug
  menu, an "open a tab" right-click, settings in the window AND sandbox).
- Hub texts (IGUI_HUB_*): master copy `_HarmonieHub/translate/{EN,TH}.json`;
  install.sh merges them into each mod's IG_UI.json
  (`tools/merge_translate.py`). Never edit IGUI_HUB_ keys in a mod.
  LWS's `tools/texts_lws.py` reads the master too.
- Hub 4 (1.0.0): right-click anywhere > "HARMONIE: open a tab" (H icon,
  first in our block) > each mod (card) > its tabs with the window's own tab
  icons -- `Hub.TABS[id]()` lists { id, key, icon }, `Hub.OPEN_TAB[id](p, tab)`
  opens one (GTPGuide.open(p,nil,tab) / TWACraftUI.window:setTab /
  HealthPanelInstance:setActiveTab / HSVU.window.tab / HMLWorkbench.instance:
  setTab / LWSWindow.open(p,tab)). A new window: add both.
- `shared/000_HARMONIE_Reach.lua` (hub, was HM_Reach): where an item may come
  from -- inventory + bags, every container in the player's ROOM (<= 12
  tiles, same z; 1 tile counts anyway), outdoors <= 3 tiles; floor bags.
  MP: only the server changes a world box (clientMustNotTouch / notePending /
  serverMissing -> "HARMONIE_Reach"/"Missing"); `bring(p, item)` walks to a
  far box (`walkTo`, luautils.walkToContainer) then transferIfNeeded. Used
  by How to Survive (HM_Reach = HARMONIE_Reach), TWA (TWASources.get adds
  the room's containers), GTP cooking (CookCore K.containers + CookFlow
  F.bring), MIL parts (W.installReach wraps getReachableContainers + walks
  before addAttachmentButton's transfer).
- Settings window server rules (UIKit `HARMONIE_SettingsUI.addServerRows(rows,
  {namespaces})`): each mod's gear window ends with its sandbox options --
  tick / step / choice rows reading the live value; admins (Hub.isAdmin)
  change them through Hub.setOption + Hub.applyAll (MP: sendToServer).
  Called as `(HARMONIE_SettingsUI.addServerRows or function(r) return r end)`.
- Admin things live in the debug menu only (1.0.0): TOC = ONE window per
  player (`HM_OpenTOCAdmin`, client/TOC/Admin.lua, settings-window rows);
  GTP vitamin admin for another player = HARMONIE_RegisterDebug("GTP");
  TWA weapon debug = the hub's "weapon in hand" (inventory option removed).
  In-window admin tools stay in their windows (TWA craft admin buttons, LWS
  Give tab -- also reachable from the debug menu).
- MIL item changes in MP (1.0.0, `shared/HARMONIE_MIL_NetItems.lua`, also in
  tools/ours): the original adds/removes items on the client in battery
  in/out, grenade launcher + under-barrel reload, repair kit, ammo bag and
  ChangeMagzine (gun replaced). On an MP client these send
  "HARMONIE_MIL_Items" ops (batteryIn/Out, consume, repair, bagIn/Out,
  swapGun); the server changes its copy and sends it (sendAdd/Remove/
  sendItemStats); the client only updates what it shows. SP unchanged.
- Admin test button (1.0.1, owner: "ในทุกหน้าต่างและแท็บให้มีปุ่มที่แอดมินสามารถกด
  เพื่อทดสอบ"): hub `shared/000_HARMONIE_AdminTest.lua` + `media/ui/HARMONIE_icon_test.png`
  (tools/gen_test_icon.py). `AT.decorate(WindowClass, {mod, tab(win), rect(win),
  player(win), ctx(win)})` draws a flask left of the header buttons (admins /
  -debug only) and opens `AT.open(mod, tab)` = settings-window rows of the
  tests registered with `AT.register(mod, tab | "*", {{key, fallback, run}})`.
  World changes are server ops (`AT.serverOp` / `AT.send`): the server runs
  them only for a sender with access level / role admin (or server -debug).
  Built-in ops: give {items}, skill {perk, level}. Per mod: HM
  `shared/HARMONIEHomeMedic/HM_AdminTests.lua` (hm_* ops call
  EHR.ServerCommands.*; on someone else's window args.target = their online
  id), TWA `client/HARMONIE_TWA_AdminTests.lua` (TWAAdminGrant.request),
  GTP `client/HARMONIEGardenToPlate/HARMONIE_GTP_AdminTests.lua` (VitData.Set),
  SVU `shared/HARMONIESVU3PartWear/HARMONIE_SVU3_AdminTests.lua` (svu_repair /
  svu_wear), MIL `shared/HARMONIE_MIL_AdminTests.lua` (+ tools/ours; mil_ammo /
  mil_parts / mil_condition on the gun in hand), LWS
  `client/HARMONIELifeWithStyle/LWS_AdminTests.lua` (AdminGrant /
  AdminGachaGrant). A new tab: register its tests under its tab id.
- Diagnose -> medicine (HM 1.0.6, owner "วินิจฉัย ให้ไปต่อที่ใช้ยาเลย ไม่ต้องหายาเอง"):
  "Use medicine" button in the diagnosis result window (success) and on a
  diagnosed illness's row (C.shortcuts action "medicine") ->
  `client/HARMONIEHomeMedic/HM_MedPick.lua`: medicines whose
  Database `treats` has the illness, found with HM_Reach.each (body, bags,
  room boxes), carried first; CanUseMedication checked every 2 s (reason
  shown, Use off); Use = EHR.MedicationAction.QueueUseMedication (carried) or
  HM_Reach.bring + EHRMedicationAction (box). Someone else's window -> EHR's
  Administer Medication (consent). Texts UI_HomeMedic_MedPick_* --
  UI_HomeMedic_Med_* belongs to the Medication Handbook, do not reuse it.
- Surgery tab (1.0.1, owner): every operation can be OPENED (view only when
  the patient has no indication: the prep checklist on every body part it
  can be done on, `opts.viewOnly`, Start off); Start works only with an
  indication (the server's S.evaluate checks again).
- Next-step banner (2026-11-16, owner's UX/UI plan, Phase 1): hub UIKit
  `HARMONIE_Banner.draw(ui, x, y, w, state, text, font)` -> height used (0
  when off). States READY / MISSING / LOCKED / IN_PROGRESS / COMPLETE /
  INFO_ONLY = a word chip (IGUI_HUB_State_*) + colour, max 2 lines; Thai
  wraps on whole letters (vowel / tone marks stay on their letter, เ แ โ ใ ไ
  go with the next, `BN.clusters`). Off switch = commonRows tick "hints"
  (Zomboid/Lua/HARMONIE_Hub_Hints.txt, this computer). Used on top of: GTP
  every tab (cook: pick > check > cook from F.run / plan.ready + reasons),
  SVU every tab (locked reason; upgrades = install in the game's window),
  MIL every tab except 3D inspect (its view covers the page), LWS every tab
  (trade: agree states + "offer changed, both agreements taken back" for 15 s
  when rev changes while you had agreed). Hub cards: `want` line (what you
  come to do) + small "How it works" button -> `guideTab` (gtp overview,
  others guide). TWA tooltips already describe Stop / Cancel / Incomplete /
  Finish exactly; HM / TWA pages got no banner yet (absolute layouts).
- Right-click > "HARMONIE: open a tab" > each mod row shows the H in that
  mod's colour (owner 2026-11-17): `media/ui/HARMONIE_H_<card id>.png` from
  `tools/gen_h_icons.py` (recolours HARMONIE_H.png to each `Hub.CARDS`
  accent -- keep its ACCENT list in step); the gold H if a file is missing.
  The owner turned DOWN the "symbols instead of words / text on hover" rework
  of the same day (PR #101 kept only this) -- ask before redoing the UI text.
- Every right-click option of ours wears its MOD's coloured H (Hub 5.2,
  owner 2026-11-22): HubBoot `B.iconFor(tag)` maps the HARMONIE_Ours tag to
  the card picture (B.TAG_CARD: GTP gtp, TWA twa, HM hm, SVU svu, MFS / MIL
  mfs, LWS lws -> media/ui/HARMONIE_H_<id>.png); HUB and "debug" keep the
  gold H, a missing picture falls back to it. The option-pool hook clears
  any of our H pictures (`B.isOurIcon`) from a reused option. A new mod tag:
  add it to B.TAG_CARD.
- Action bar (Hub 5.3, owner 2026-11-24: "our windows cover the vanilla
  progress bar -- show doing / started / done"): `client/HARMONIE_ActionBar.lua`
  -- while any of our windows is open (AB.anyOpen: GTPGuide.window,
  TWACraftUI.window, EHR.UI.HealthPanelInstance, HSVU.window,
  HMLWorkbench.instance, LWSWindow.isOpen) and player 0 runs a timed action,
  a bar at the top centre shows "Doing: <name>" + % (getJobDelta), then
  "Done" (green, reached >= 95 %) or "Stopped before the end" (orange) for
  2 s. Names IGUI_HUB_Act_<class> (hub translate), else the class name made
  readable. Mouse handlers return false. A new window: add it to anyOpen.
- Life With Style's right-click and window title are "แฟชั่นและไอเท็มกาชา" /
  "fashion and gacha items" (1.0.0, owner).

- Lists refresh by a BUTTON, never by themselves (owner 2026-11-21: "the
  recipes in the GTP tab keep refreshing as if searching -- a refresh button,
  nothing automatic, in every mod"). Hub `client/HARMONIE_Refresh.lua`:
  `HARMONIE_Refresh.gen(scope)` / `bump(scope, why)` / `afterActions(scope,
  player, why)` (one bump when that player's action queue has been empty
  for SETTLE_MS 1 s -- MP item changes arrive after the action) / `label()` /
  `tip()`; texts IGUI_HUB_Refresh(_Tip). A list scan keeps its result while
  `gen(scope)` is the same -- NO time-based re-scan. Scope goes up only on
  the window opening, its Refresh button, or one of OUR actions there.
  GTP 1.9.0 cooking tab (cookScan; button right of the page chips; prepare /
  add-to-dish -> afterActions), TWA 1.4.0 (header "Refresh" left of the gear;
  ownsBase, practice-cell CheckEligibility, procedure DescribeAll, bag
  candidates, unfinished-item scan, guidedData, bag add-on page scan, gem
  socket weaponOk / ownedGems; craft start / cancel / incomplete / finish and
  every step -> afterActions; TWASources' own 1 s cache stays for the
  actions), MIL 1.1.0 parts tab (also rescans when the gun's fitted parts
  change -- read from the gun), SVU 1.1.0 (header "Refresh"; rows read on
  open / car change / Refresh, no 2 s), HTS 1.2.0 surgery checklist (button
  left of Start; Start checks again) and medicine picker (no 2 s). Left as
  they are: state that is not a search of items (HTS diagnosis findings,
  surgery-tab indications, vitamin panel layout, LWS -- server data).
- RULE for any wrapper of a Java-exposed global (sendServerCommand,
  sendClientCommand, ...): forward with varargs `function(...) return
  orig(...) end`, NEVER a fixed list like (a1, a2, a3, a4). Java picks the
  overload by the exact argument count, and a padded nil makes a 3-argument
  call (String, String, table, nil) -> "No implementation found for function:
  sendServerCommand" and the packet is NOT sent. Hub 5.1 (GTP 1.8.8, TWA
  1.3.4, HTS 1.1.3, SVU 1.0.9, MIL 1.0.12, LWS 1.1.4, 2026-11-21) fixed this
  in the packet meter after it broke other mods' server commands (Waterpipes,
  Blackout Predators, RealWorldZ Vehicle Ownership in the owner's console).
- Packet meter (Hub 5, 2026-11-20, owner: "anything that sends too fast or
  can loop -- players get kicked"): `shared/000_HARMONIE_NetMeter.lua` wraps
  sendClientCommand / sendServerCommand ONCE (global flag) and only COUNTS by
  module/command: "[HARMONIE_Hub][NetMeter] client: X/Y sent 20 times within
  1 s" (once per 30 s per command) + a 10-minute top-5 when one went over 300.
  Counts other people's mods too. The audit that day fixed: MIL casings
  (world items added / moved / removed per shot -> CASING_PER_SEC 4 per
  player, CASING_MAX_ACTIVE 16, client sends <= 4 a second, impact sound
  only to the shooter, no broadcast), GTP vitamin sync (whole store sent on
  EVERY Set/Add -> one send per character per second, VitData.SYNC_GAP_MS),
  HTS full medical-state sync (EHR.SafeTransmitModData on the server marks
  and sends once per 250 ms per player, EHR.SYNC_COALESCE_MS). Checked and
  fine: TWA damage numbers (8 a second both sides), LWS sweep (10 s, sends
  only on change), pet anim (on change), EHR RequestSync (on events), MIL
  NetGuard (1.0.10), per-frame logs (all Once / state-change).
- New Dawn set: LWS 1.1.3 (owner): all four = +30 percent MORE -> 50 percent
  in all (SET_FULL_BONUS 0.30).

## The Way To Attack (TWA)
- Rare ores (TWA 1.5.0, owner 2026-11-22: "epic คือ อีลู elite คือโอริ
  legendary คือบราเดียม"): Elunium (อีลูเนียม) = EPIC (Epic bar, Make_GemFine,
  bag tier 3 / add-ons tier 3), Oridecon (โอริเดคอน) = ELITE (Elite bar,
  Make_GemRadiant, bag tier 4), Bradium (บราเดียม) = LEGENDARY (Legendary bar,
  Make_GemPure, bag tier 5). Hand-edited in HARMONIE_TWA_RecipeData.lua (its
  generator is not in the repo) + TWABagUp B.ORE.
- Forge by rarity (TWA 1.5.0, owner): a step with forgeTier asks for the
  forge of the RECIPE's tier, not its own -- `TWAProcedures.ForRecipe(proc,
  recipe)` (cached copy, logged once): Junk..Rare none, Epic Primitive (1),
  Elite Forge (2), Legendary / Prototype Advanced (3), "or better"
  (FORGE_BY_TIER). Used by tryPerformProcedure, the step details, the guided
  view and TWA_PerformProcedureAction (4th arg recipeId). Practice keeps the
  step's own forgeTier. A recipe with no stats tier keeps it too.
- One gem of each TYPE per weapon (TWA 1.5.0, owner): `TWAGemSocket.dupeKey`
  -- doInsert refuses (server), the socket page dims those gems and the
  button says IGUI_TWA_Socket_SameType. The same socket may still take a
  better gem of the same type.
- Craft button (TWA 1.0.3, owner): a base / extra item card whose item some
  recipe MAKES (`recipeMaking`: result map, keepType gem recipes excluded)
  shows "Craft" -> `TWACraftWindow:jumpToRecipe` (craft page, search cleared;
  locked while a recipe is under way). Rects in `self.craftLinks`.
- Guided craft mode (TWA 1.0.6, owner's HARMONIE_TWA_Guided_Mode_Redesign_TH.txt):
  `client/HARMONIE_TWA_GuidedCraft.lua` is a VIEW over the craft tab, default
  on (`TWAWorkbench.guided`, "guided=" in HARMONIE_TWA_Window.txt, gear-window
  tick, bottom-right switch in both views; switching never starts / stops a
  craft). Scene derived every frame (`guidedSceneOf`): PREPARE /
  PREPARE_RESUME / WORK / STEP_BUSY / FINISH / BUSY (center action) / LOCKED /
  PRACTICE -- no stored step number. Left card = header + hub banner + focus +
  ONE primary button (notes above it), right card = the recipe's steps only
  (click = `guidedPick`), bottom bar = back / "Manage craft..." (modal: pause =
  onIncompleteButtonClicked, cancel asks again = onCancelButtonClicked) /
  view switch. Every button calls the old handler; `selectedProcId` follows
  the step shown. Suggested step: running > picked > first not done and met >
  first not done (no fixed order -- the game has none). DescribeAll + item
  counts cached 750 ms (`guidedData`). Step result lines come from
  `window.lastProcResult` / `lastProcStopped`, set in tryPerformProcedure's
  onComplete / onEnd (the only controller change). Drawn buttons live in
  `self.guidedHits`, cleared at the top of renderBody. Helpers exported as
  `TWACraftUI.H`. Texts IGUI_TWA_G_*. Not done yet (plan P1/P2): "Available"
  as the default recipe filter, recipe cards "ready to start" vs "ready for
  every step", first-time-only hints (the hub banner + its hints switch are
  used instead), usability test.
- NEVER remove or skip a TWA procedure minigame (owner 2026-11-17, "ห้ามเอา
  ขั้นตอนการทำมินิเกมออก"): every step goes onConfirmProcedure ->
  tryPerformProcedure -> TWAMinigame.play -> the word -> the timed action.
  Only the player's own "minigames off" setting gives Excellent (as before).
- TWA lag fix (1.0.8, owner: "opening the craft window makes every other UI
  lag", long-standing): TWASources.get (client) keeps a scan 1000 ms and
  walks the items ONCE into `Multi:index()` (byType + all); count / first /
  countEval / forEachItem read it (server: plain container calls, no cache).
  Before, each question walked every item of every box in the room in Lua --
  per recipe row, per base card, per frame, and for EVERY recipe on a list
  refresh. Also: unfinished-item scan only on the recipe pages / empty craft
  tab, every 2 s; procedure details DescribeAll kept 500 ms; the practice
  grid's CheckEligibility per cell kept 750 ms; `S.isBookmarked` and
  findIncomplete test hasModData() first (getModData() makes a table on
  every item). An index over 15 ms logs "item index: N items ... took M ms".
- TWA 1.0.9 / LWS 1.0.5 (owner 2026-11-18): no right-click "Craft Weapon"
  (inventory + world) and no right-click "fashion and gacha items" -- the
  hub's HARMONIE: open a tab does it (TWA's "Continue" on an unfinished
  weapon stays). TWA has no "Craft" tab BUTTON (W.TABS starts at weapons):
  the craft page opens from a recipe / "back to the craft under way";
  setTab("craft") still works. Tab "Modify" is "ติดตั้งอัญมณี" / "Socket gems"
  (tab, socket window, its right-click, guide).
- TWA crafted weapons x2 durability was 1.0.9 only; 1.0.10 took it back
  (owner 2026-11-18): `TWAGemSocket.undoDurability` -- a weapon with
  md.TWA_Durability gets the script max (+ gems) again and its condition
  divided by that factor, once; run from applyDamage (equip, swing, game
  start for every carried crafted weapon). Toughness tiers: script
  ConditionMax > 5 / 10 / 15 / 20 as always.
- TWA 1.0.11 (owner 2026-11-18): Finish needs only every step done -- no
  quality gate (canFinish; sandbox MaterialNeedsGood is no longer read).
  Advanced view: overall quality shows its average "(2.67)" and a line under
  the step grid with the cut points (Bad < BadBelow, Good, Excellent >=
  excellentCut incl. the crafter's skill bonus). Guided header: no progress
  bar (it covered the sub line).
- TWA 1.0.12 (owner 2026-11-19): "open with the vanilla crafting window" is
  W.followVanilla in HARMONIE_TWA_Window.txt ("followVanilla=1"), OFF by
  default, ticked in the craft window's settings page; VanillaCraftLink
  V.enabled() reads it. The ModOptions tick box followVanillaCraft is no longer
  read. Root bug: settings oget was `O.get and O.get(id,d) or d`, so a false
  value read back as the default true -- never write and/or with a boolean
  value; oget now checks nil.
- TWA 1.2.0 (owner 2026-11-20, replaces 1.1.0's Tomb bag crafting -- Tomb's
  bags are LWS fashion now): BAG UPGRADES, `shared/HARMONIE_TWA_BagUpgrade.lua`
  (TWABagUp) + `client/HARMONIE_TWA_BagUpgradeUI.lua` (tab "bagmod" + hotbar).
  * 86 wearable vanilla bags (B.BAGS, from container.txt: back, satchel,
    webbing, fanny, ammo strap, shoulder holster). md.TWA_BagTier 0..5,
    md.TWA_BagUps = "type;type" (a STRING -- no table holes), md.TWA_BagBase =
    the bag's first values (captured once, never again).
  * Recipes (tab "bags", categories BagUp / BagTier, scopeOf -> "bags"): 35
    items TWA_BagUp_* (7 kinds x 5 tiers: cap +1..5, wr +2..10, run / combat
    +0.005..0.025, weight -0.1..0.5, attachS / attachL +1 hotbar slot), steps
    BagCutN + BagSewN; 5 tier recipes Make_BagTierN (keepType + bagTier,
    steps BagSewN + BagFitN). Every step of tier N = Tailoring N (owner: same
    ceiling as forging, Blacksmith 1..5), time N*10+10, minigames incision /
    suture / wrap (client Minigame.lua loop). T3/T4/T5 base2 = Oridecon /
    Elunium / Bradium (same order as Epic / Elite / Legendary bars).
  * Tier recipe base must be the bag at tier N-1, EMPTY, not worn / not on the
    hotbar, not unfinished (CraftState.baseOk -> TWABagUp.tierBaseOk; Start
    removes the base, so items inside would be lost). Finish ->
    TWABagUp.finishTier (same type, md copied, tier N, colour restored from
    snapshotItem's new `tex`); no break, no grade reveal. Unfinished bag ->
    capacity 0 (apply sees md.TWA_Incomplete).
  * Rules: item tier <= bag tier; slots = tier; the same item type once per
    bag (same kind from another item is fine); removing a capacity item is
    refused while the contents would not fit; removal returns the item with
    10 + 9 x Tailoring percent (100 at 10), else lost. Caps: cap 50, wr 95,
    run / combat 1.00, weight >= 0.1.
  * MP: client "bagUp" {op install|remove}, server re-checks everything,
    answers "bagUpSync" (md) / "bagUpMsg" (reason key). The game does not
    save an item's own capacity / WR / speeds -> TWABagUp.apply on server and
    clients every 5 s, after each change, in a wrapped
    ISInventoryTransferAction.isValid (bags in boxes / on the floor) and on
    OnRefreshInventoryWindowContainers. Setters are tested before use; the
    admin test "BagUpProbe" logs which exist (UNVERIFIED in game:
    setRunSpeedModifier / setCombatSpeedModifier on InventoryContainer).
  * Hotbar: our own slot types TWABagS1..10 / TWABagL1..10 (attachments
    COPIED at runtime from SmallBeltLeft/Right, HolsterRight/Left). Wrapped
    ISHotbar:haveThisSlot answers yes for the slots worn bags give (so
    refresh does not drop them), ISHotbar:refresh adds the missing ones after
    the original; a signature check every 2 s forces a refresh when attach
    upgrades change. No vanilla code is copied (repo is public).
    UNVERIFIED in MP: whether the server accepts an attach to our slot types.
- TWA 1.2.1 (owner 2026-11-20):
  * No crafted weapon above the vanilla Katana's DPS 8 (8-8, speed 1):
    master_forged x5 7.5-10.1 -> 7-9, apoc_tactical_longsword 8-9 -> 7.5-8.5
    (scripts TWA_weapons_r23 / MWP1 + RecipeData Stats). Grade does not
    change damage; gems (+0.0..0.5 each) can still lift a weapon past 8.
  * Tiers (TierTooltip tierFromDps, exported TWATier.fromDps): Junk < 0.25
    < Common < 0.5 < Uncommon < 1 < Rare < 2 < Epic < 4 < Elite < 7 <=
    Legendary <= 8 < Prototype. Only Elite / Legendary moved (were < 8 / < 10)
    so every baked Stats tier stays right.
  * Zombie drops (`shared/HARMONIE_TWA_ZombieDrop.lua`, server / SP,
    OnZombieDead -> zombie inventory): TWA_MaterialLump ZombieDropLump 5 %,
    TWA_Gemstone ZombieDropGemstone 2.5 % (1.2.2, owner; sandbox, logged).
  * 1.2.2: gems never change the TIER -- TWAGemSocket.tierDamage(item) = live
    damage minus the gems' bonus; TierTooltip and the socket page judge the
    tier on it (the damage / DPS shown stay the real ones). Gem max: S grade
    5 + 1 special sockets x Pure +0.5 = +3 min and max -> DPS + 3 x speed
    (Legendary 8 -> 11).
  * Ore cost: a recipe whose base2 is Oridecon / Elunium / Bradium takes
    sandbox OreCost (20) of it: S.base2Qty / base2Count / base2Ok /
    takeExtraBase2 (CraftState). Start checks the whole count, takes the
    chosen one + qty-1 more; snapshot base2.n; Cancel gives n back;
    Incomplete keeps n in TWA_OrigBase2. UI cards "Have: 5 / need 20"
    (IGUI_TWA_HaveNeed), guided row, list availability, AdminGrant gives the
    missing number.
- MIL 1.0.9 (owner 2026-11-20, a player thrown out twice while shoving
  zombies; console: ~110 "EquipPacket.set get invalid arguments" in the 7 s
  before, one every 2 frames): MFSTwoHandGripFix's watchdog put the weapon
  back in an emptied off-hand every 3 frames with no limit -- each is an
  equip packet. Now guns only (isRanged), never while shoving / attacking /
  staggered / on the floor / climbing, one restore per 1.5 s, and 3 restores
  within 15 s that do not hold -> stop 60 s (logged). Not proven to be the
  only source of that flood (other mods equip too).
- TWA 1.2.4 (owner 2026-11-20; 1.2.3's x5/8 damage + cuts were taken back,
  the stats restored from before it): cuts Junk < 0.25 < Common < 0.5 <
  Uncommon < 1 < Rare < 2 < Epic < 3.5 < Elite < 5 <= Legendary <= 6 <
  Prototype (TierTooltip, EPS: a DPS on a cut is the upper tier). Our Epic /
  Elite / Legendary weapons (54) moved into the new bands in a straight line
  (Epic 2..4 -> 2..3.5, Elite 4..7 -> 3.5..5, Legendary 7..8 -> 5..6;
  min / max x the same factor, 0.01) -> counts unchanged 3 / 33 / 80 / 30 /
  19 / 6; Rare's band did not move. Vanilla Stats tiers re-baked (vanilla
  Katana DPS 8 = Prototype). Procedures and the base2 bar of a recipe are
  FIXED lists in RecipeData (made once from durability / wear / push-back /
  knockdown, the bar from the tier then) -- nothing reads the tier at run
  time, and every weapon kept its tier. Gems +3 x speed -> 9 at most.
  G.syncScriptDamage (applyDamage): an older copy of OUR weapon without gems
  / override gets the script damage. DamageShare: the client caps itself at
  RATE_PER_SEC. Material Lump weight 2.0 -> 1.0 (owner).
- TWA 1.2.5: Material Lump stack 5 under Inventory Tetris (the owner's
  server runs it; vanilla has no stack limit) --
  `shared/HARMONIE_TWA_TetrisCompat.lua` calls
  TetrisItemData.registerItemDefinitions({ [type] = { width = 1, height = 1,
  maxStackSize = 5 } }) at load and OnGameBoot, ONLY when that function
  exists. The API shape is from memory (the mod's source was not readable):
  the console says registered / not loaded / no such function (and lists
  TetrisItemData's functions) -- check it on the server.
- MIL 1.0.10 (disconnect while shoving, second pass): the console's flood is
  "EquipPacket.set get invalid arguments" -- equip / attach packets for items
  the server cannot match. MIL draws gun parts and shields with FAKE items
  attached to the body (EFK_RenderPart TempNilItem, InitShield
  RenderPartItem), from OnPlayerUpdate: InitShield attached a new one EVERY
  update (and for every other player's update too); RenderPart removed and
  re-attached the parts whenever the gun model was missing for a frame (it
  flickers in a shove). Now `client/000_HARMONIE_MIL_NetGuard.lua`
  (MILNetGuard.allow(tag, n): 6 calls a second for all of ours in MP, one
  bigger batch allowed first in a second, held-back counts logged once a
  minute; isLocal(player)); InitShield attaches only when shield / place /
  pose changed; RenderPart: local player only, parts off only after the model
  is missing 1 s, a rebuild at most once a second; the grip watchdog uses the
  budget too. A clean cure would draw these without fake attached items.
- TWA 1.3.0 (owner 2026-11-20, bag UX round):
  * Tabs: the bar shows only "Weapons" / "Bags" (W.MAIN_TABS gWeapons /
    gBags); a main tab opens a CHOOSER page (W.CHOOSER, big cards:
    weapons / materials / modify / guide; bagitems / bagtiers / bagmod /
    bagguide). Every page under it gets "< Back" at the left of the tab bar
    (W.parentOf: craft / practice -> its recipe list, else the chooser).
    setTab ids stay (hub, W.TABS); new ids bagitems / bagtiers (bag list with
    filter BagUp / BagTier) and bagguide (guide chapter Bags). Window opens on
    gWeapons.
  * Add-on page (TWABagUpUI) laid out like the gem page: bags left (+ rules),
    the bag large + one slot per tier + values base > now > with the picked
    add-on in the centre, add-ons in a grid on the RIGHT card; hover a stat /
    add-on / slot = what it does (IGUI_TWA_BagUpStatTip_*). Pick + button
    "Fit add-on" / pick a filled slot + "Take out".
  * One add-on per KIND per bag (canInstall -> IGUI_TWA_BagUp_SameKind); a bag
    that already had two of a kind keeps them.
  * Tooltip (TierTooltip -> TWABagUp.tooltipLines): an upgraded bag shows its
    tier, md.TWA_BagBy (who raised it, set in finishTier) and each add-on with
    its maker (md.TWA_BagUpBy "name;name", same order as TWA_BagUps; the
    add-on's TWA_CraftedBy, given back on removal); an add-on item shows its
    effect and the rule.
  * Bag tier recipes: the craft page / guided row lists EVERY bag at hand
    (bagCandidates, TWAPicker rows `disabled` with the reason / `info`); the
    picked bag is kept by id (window.bagPick) and pickItems takes exactly it.
  * Steps: BagSew1..5 are Basic / Double / Reinforced / Cross Stitch /
    Advanced Load-Bearing Stitching (B.STITCH: thread or twine, 2 thread,
    thread + sinew, 2 sinew, 2 aramid; any needle T1-2, metal needle T3+).
    Each kind has its own step (B.KIND_STEP: BagPocket / BagCompress / BagPad /
    BagRivet / BagTrim / BagLoop / BagHolster 1..5, Tailoring T); an add-on
    recipe = BagCut + BagSew + its kind step. Recipes carry `bagKind`; the
    bag list has a filter per kind (BagK_<kind>).
  * "Base DPS" is "Average damage" = (min + max) / 2 (craft page, gem page);
    the tier still uses that x attack speed.
- TWA 1.3.1 (owner): a bag TIER recipe is sewing (BagSew + BagFit); an
  ADD-ON recipe is cutting: BagCut1..5 = Basic / Pattern / Precision /
  Multi-Layer / Complex Structural Cutting (B.CUT: rag or denim + any cutter;
  then scissors with 2 denim / 2 leather strips / small leather + 2 denim /
  medium leather + 2 leather strips) + the kind's own step. No stitch in an
  add-on recipe any more.
- TWA 1.3.2 (owner: hold a flashlight like vanilla's ALICE belt -- first a
  separate 8th kind, then "merge it into the small slot"): no new kind. The
  small slot TWABagS1..10 = vanilla SmallBeltLeft/Right attachments + the
  ones of WebbingLeft/Right it lacks ("Webbing" = FlashLight_AngleHead(_Army),
  model place "Webbing Left/Right Walkie"). Vanilla facts (owner's zip in
  mods/_VanillaReference_B42/raw/hotbar, gitignored): Bag_ALICE_BeltSus
  provides SmallBeltLeft;SmallBeltRight;WebbingRight;WebbingLeft; Torch /
  HandTorch have NO AttachmentType (no slot holds them). The console line
  "hotbar: ... small slot takes: ..." lists the kinds.
- TWA 1.5.3 (owner 2026-11-27: "can't pick the bag although it is off the
  hotbar"): an item can keep its attached slot number after leaving the
  hotbar (moved into a box / bag). `TWABagUp.inUse` counts a hotbar slot only
  for an item lying directly in a character's own inventory (container with
  no containing item, parent IsoGameCharacter) and, when the character has
  getAttachedItems():contains, only if that list has it; a stale slot is
  logged once per item ("treated as free"). An upgraded bag is still the
  SAME vanilla item type (finishTier AddItem(snap.type)) -- only modData,
  the stats B.apply sets and the tooltip lines under vanilla's are ours.
- TWA 1.5.4 (owner: "Inventory Tetris shows no grid in a tier-upgraded
  bag"): finishTier copied EVERY modData key of the old bag onto the new
  one, other mods' data about that bag included (Inventory Tetris keeps its
  grid data on the item). Now only "TWA_" keys are copied (the rest logged
  as "not copied") and the new bag gets md.TWA_BagFresh. B.apply takes the
  non-TWA_ keys off a tiered bag without TWA_BagFresh ONCE, both sides
  (logged with the key names -- tells which key Tetris uses).
- TWA 1.1.0 (removed in 1.2.0): Tomb bag recipes. Recipe tabs are scopes
  weapons / materials / bags via `TWACraftUI.scopeOf(category)`; W.TABS
  entries may have `when` (W.visibleTabs; the hub's fromTabs honours it).
- GTP vitamin tooltip box sits UNDER the item tooltip (above it when no room),
  GTP 1.0.2 (HARMONIE_TooltipHook.lua).
- GTP cutting minigame = rapid chop (GTP 1.0.3, owner "หั่นรัวๆ"): kind "timing"
  (chop / slice / mince / trim / core) in HARMONIE_CookGames.lua -- every
  click or Space is one cut (`P:chopOnce`), `CUTS[variant]` x (0.8 + 0.5 d)
  needed; no cut for CUT_GRACE_MS -> one cut lost every CUT_DECAY_MS; quality
  = full when done within 40% of the time limit, half at the limit; timeout
  before the last cut = Miss. Hints IGUI_GTPC_Hint_* / Tip lines say so.
- GTP 1.1.0 (owner 2026-11-19, "ไม่เอาเป็นการสร้างอาหารใหม่แล้ว อยากใช้เมนูเดิมที่
  vanilla มี"): our 99 dishes, CookFlow and CookServer (take / finish /
  pending) are GONE. Cooking = vanilla only. GTP never had dish ITEMS (the
  dishes made vanilla result types); its own items (home-canned produce,
  dried fruit, sprouts, fish oil, fruit farming) stay.
  `shared/HARMONIEGardenToPlate/HARMONIE_Prep.lua` (HARMONIE_GTP.Prep):
  ingredient modData.HARMONIE_Prep = { w, p, s } -- ONE minigame per food,
  Excellent +2 / Good +1 / Bad and Miss -1, none = 0; which minigames by
  FoodType / name (R.KIND_GAMES, R.FOODTYPE_KIND; cooked / rotten / frozen /
  spice / already prepared -> R.whyNot). Dish modData.HARMONIE_Dish =
  { sum, n, avg, fam, lvl }: average of every non-spice food that went in (a
  food base counts, a pot does not; a dish inside a dish counts with its
  avg). Written ONLY where items are real: wrappers of
  ISAddItemInRecipe:complete (R.onEvolvedAdd) and
  ISHandcraftAction:performRecipe (R.onCraft, only when a consumed food had
  a score), both skipped when isClient(). Prep: client minigame ->
  HARMONIE_GTP_CookStepAction -> "prep" command; the server checks the item
  is in that player's inventory, food, allowed game, not prepared, 800 ms
  per player, writes + XP and sends "set" with the final tables (client
  copies; retried 10 s if the item has not arrived). Buffs
  (HARMONIE_CookBuffs.lua): avg < 0 -> +10 x share unhappiness; 0.5 / 1.0 /
  1.5 -> tier 1 / 2 / 3 (strength x1 / 1.5 / 2, hours x0.5 / 1 / 1.5 of
  (2 + cook level)); kind from fam (K.BUFF_OF_FAMILY), else FoodType, else
  hearty. The buff record lives in GLOBAL ModData "HARMONIE_GTP_CookBuff"
  by "u:" .. username (an old player-modData buff moves once, "m:" mark).
  Tooltip: score box ABOVE the vitamin box (TooltipHook buildPrepLines).
  Cooking tab pages: prep / evo (vanilla evolved recipes at hand, Add =
  ISInventoryPaneContextMenu.onAddItemInEvoRecipe) / craft (89 Cooking
  craftRecipes from HARMONIE_CookCraftList.lua, generated from
  craftrecipes_index.txt; Open = ISEntityUI.OpenHandcraftWindow(p, nil,
  nil, false, recipe)). An old half-made dish (1.0.4-1.0.8 pending record)
  is given back once by the authority (HARMONIE_CookRefund.lua, "refunded:"
  mark in the world's data). Vanilla Lua for reference: the owner's
  pz_cook_lua.zip unpacked in mods/_VanillaReference_B42/raw/lua (gitignored).
- GTP 1.2.0 (owner's 42-point review, round 1 of 6 -- MP safety): buff
  cleared on death (K.clearBuff, OnPlayerDeath) and a record written later
  in a life than the character has lived (`b.hs` vs getHoursSurvived) is a
  new character's -> removed; records ended > 7 game days ago pruned daily
  (K.pruneBuffs). Anti-cheat: client sends "begin" {id, pid} when the
  minigame opens (R.begin); "prep" is taken only for that id + pid, 2.5 s to
  5 min after it (no minimum with sandbox CookMinigames off) -- refusals
  noBegin / timing. The client's "set" copy also looks in the room's boxes
  (HARMONIE_Reach.findById): a pot is put back on the stove after an
  addition. Per-event Prep logs only with sandbox CookDebugLog; an hourly
  summary always. Tab: watchdog 10 s (H.PREP_WATCHDOG_MS), Cancel button
  (clears the queue in bring / action), "inventory full" reason.
  Forward-local check: scratchpad fwdcheck.py (strips comments / strings).
- GTP 1.3.0 (review round 2 -- score balance): a dish average is WEIGHED by
  the hunger each ingredient brought (R.weightOf, x100, min 1; evolved
  additions use hunger before - after on the used item, captured in the
  wrapper) -> HARMONIE_Dish gets `w`; a pre-1.3 dish counts w = n.
  MINOR_INGREDIENT foods (oil, sauces) do not count (R.isMinor, ItemTag
  object). Rotten = score 0 and no buff (K.dishTier). Bad = -0.5. Minigames
  off in the sandbox -> word "Off" = 0. Scores are read LIVE from the word
  (R.wordScore), so a sandbox change counts for food prepared before.
  Buff level 3 needs a cook of Cooking >= CookBuffTier3Level (5), else 2.
  Sandbox (15 new): CookScoreExcellent / Good / Bad / Miss, CookBuffTier1-3,
  CookBuffTier3Level, CookBuffStrength1-3, CookBuffLength1-3,
  CookBadDishUnhappy.
- GTP 1.4.0 (review round 3 -- minigames): R.GAME_RULES pick the games per
  food (first rule whose kind + name words / FoodType / whole-fish hits;
  else the kind's list): citrus peel/slice/zest, berries + grapes + cherries
  wash only, leafy veg wash/chop/slice, minced meat none (whyNot noGame),
  cured meat slice. R.WHOLE_FISH = the 21 vanilla base:uncutfish types (they
  have no FoodType: kindOf checks them first) -> scale + trim; fillets
  trim + slice. Redo (#14): a Poor / Missed food can be washed off ONCE
  ("redo" command, md.HARMONIE_PrepRedo; a short wash action, no water used).
  Practice button per minigame: same game, no food, nothing sent, not
  counted. Record per minigame in Zomboid/Lua/HARMONIE_GTP_PrepStats.txt
  (this computer). R.hardness(item) is added to the difficulty (meat /
  poultry +0.08, whole fish +0.12, fillet +0.06, herb / bean / grain -0.05,
  over 1 kg +0.05).
- GTP 1.5.0 (review round 4 -- tab layout): ONE shared scan
  (Win:cookScan: a per-container item-count signature checked every 500 ms,
  full walk only when it changed or every 5 s; prepList / evoList derive from
  it by scan `gen`, `prepDirty` / `evoDirty` force a rebuild). Prep list
  groups the same type ("Carrot x20", carried first); "repeat for all" runs
  the same minigame on each one (Win:continueChain after every success).
  Minigame rows scroll ("prepGames"); the Practice button is registered
  BEFORE the row (first click area wins). Hover a row -> one vanilla
  ISToolTipInv per window (Win:updateCookTip after render; hidden on close
  and by an OnTick check). Game dishes: fresh bases of the same dish are one
  row with base chips; after the first Add the selection follows the new
  started dish (evoFollow); each ingredient shows "-> dish X" (previewScore,
  weight = vanilla use) and "Add the best". Craft page: unlearned hidden by
  default (isRecipeKnown(r, true)), "can make now" from one HandcraftLogic,
  4 recipes per frame, kept per scan gen; filters ready / known / all.
  Tooltip boxes are measured, placed, THEN drawn (were one frame late).
  Mock UI test: scratchpad test_tab.py renders every page.
- GTP 1.6.0 (review round 5 -- vanilla UI), `client/.../HARMONIE_CookVanillaHooks.lua`
  (display only): ISInventoryPaneContextMenu.addItemInEvoRecipe wrapped --
  the option it just added (opt.param2 == the item) gets "[+2.0]"; the
  crafting window's ISWidgetHandCraftControl:prerender appends "Dish score:
  X" to durationLabel (inputs = logic:getRecipeData():getAllInputItems(),
  same weighting as R.onCraft, recomputed every 500 ms); right-click a food
  -> "Prepare (Garden to Plate) >" its minigames (opens the tab, startPrep;
  no tool = notAvailable + tooltip) or "Wash off and redo"; MoodleFramework
  moodle "DishBuff" (good 1-3 = buff level, value 0.65 / 0.75 / 0.85, 0.5 =
  hidden; setDescription gives kind + hours; icon tools/gen_dishbuff_icon.py
  -> media/ui/DishBuff.png + Moodles/128/). #8 machines (coffee machine,
  toaster: ISStartCraftProcessorAction) finish in Java with no Lua callback
  -- not hooked; only 3 of the 89 Cooking recipes, coffee has no preparable
  input.
- GTP 1.7.0 (review round 6 -- words, guide, extras): Settings tick
  "tipprep" (H.tipUnprepared, HARMONIE_GTP_Guide.txt) hides the "not
  prepared yet" tooltip box. Hub GTP card text updated (master
  _HarmonieHub/translate + install.sh -> every mod's IG_UI, patch bumps).
  Guide "Other" tab page "Prep" (first). Thai result words unified:
  ยอดเยี่ยม / ดี / แย่ / พลาด (Word_Bad was พอใช้). 407 unused IGUI_GTPC_ keys
  removed (old dishes / flow; kept: literals in code + run-time prefixes
  such as IGUI_GTPC_Say_ / _Proc_ / _Word_ / _Tool_ / _Buff_) and the
  CookQualityEffect sandbox option. Admin tests (cook tab): server ops
  gtp_prepAll / gtp_buff {tier} / gtp_clearBuff in HARMONIE_Prep.lua.
  Variety bonus (#38): HARMONIE_Dish.kinds (R.kindOf of each ingredient,
  a dish inside merges its kinds); 3 kinds +CookVarietyBonus (0.25), 4+ x2,
  only when the base average >= 0 -> fields base / bonus / avg
  (R.finishDish; the tab preview uses it too). Chef XP (#39): dish.chef =
  the last adder / crafter; K.rewardChef gives CookChefXP x level x share
  to an ONLINE cook when someone else eats a buff dish ("chef" notice ->
  halo). Favorites (#41): Zomboid/Lua/HARMONIE_GTP_Favorites.txt
  ("dish|types"), saved from a started dish's getExtraItems(); "Add next"
  adds the next missing type, one per click (vanilla replaces the base
  item after each addition, so a queued chain would point at a stale base).
- GTP 1.8.0 cook's notes (owner 2026-11-20, paper picture):
  `shared/.../HARMONIE_CookNotes.lua` (N, net "HARMONIE_GTP_Note") +
  `client/.../HARMONIE_CookNoteUI.lua` (GTPNotePaper). Note = dish
  modData.HARMONIE_Dish.note { t, by, id }, written by the authority only
  ("note" {id, text}: item within reach incl. room boxes, dish.chef == sender,
  N.clean: no control chars, <= 4 lines, <= 120 UTF-8 letters, 1.5 s rate;
  empty = remove; back to the client with R.sendSet what "note"). Kept while
  the SAME cook adds / crafts on (Prep onEvolvedAdd / onCraft), dropped when
  another cook adds. Eating: ISInventoryPaneContextMenu.eatItem wrapped --
  a note shows on paper first (not to its writer, not with a gamepad, not
  when ticked away: Zomboid/Lua/HARMONIE_GTP_NotesHidden.txt, 300 kept), Eat
  calls the original with the same args. Eat wrapper (CookBuffs): K.rewardChef
  now RETURNS the XP (no "chef" command); N.onEaten sends "ateOf" to the eater
  and "likedBy" {eater, xp} to an online cook, once per eater + item per 10
  real min -> halo text. Settings ticks noteshow / eatnotice (guide prefs,
  this player). Right-click a dish: write / change (cook) or read (others);
  Cooking tab dish page button; tooltip "Made by X (- has a note)". Paper:
  tools/gen_note_paper.py -> media/ui/GTP_NotePaper.png (owner may save their
  own picture over it).
- GTP 1.8.1 (owner's test of 1.8.0): note window buttons fixed (ipairs
  trap above) + an "X" + Esc in the box; Thai counted (CookNotes.chars);
  write box text dark (javaObject:setTextColor, dark box fallback, like LWS
  search). Practice has its OWN page "practice" (H.COOK_PAGES 4th,
  Win:renderCookPractice, H.practiceGames = every game in KIND_GAMES /
  GAME_RULES, K.PROC_ORDER order) -- the Prepare page rows have a "Start"
  button instead (owner: a Practice button on every row read as "do it").
  Right-click recipe menu tags EVERY counting food "[+0.0 -> dish 1.25]"
  (R.previewDish, shared with the tab; use = getRealEvolvedItemUse). Game
  dishes list a pot first, the forged pot next, a bucket last (vanilla has
  SoupBucket / StewBucket recipes, so buckets stay).
- GTP 1.8.2 (owner: "anything of ours that makes cooking longer than
  vanilla -- take it out"): vanilla cooking was never slowed (no change to
  add-ingredient / craft / stove times; the hooks only read). The extra was
  OUR prep: a 3-6 s HARMONIE_GTP_CookStepAction after each minigame and a
  3 s wash for "redo" -- both gone (result / redo sent at once; only a
  5-tick wait after bringing an item from a box). Server minimum after
  "begin" 2.5 s -> 1 s (R.MIN_GAME_MS). CookStepAction stays defined (unused).
- GTP 1.8.3 (owner: "someone who is not the cook must not write over the
  cook's note"): a note belongs to its WRITER (note.by). It now stays on the
  dish whoever adds to it or crafts from it (bowls keep the note); only the
  writer may change / remove it (N.canWrite + server "notWriter" refusal);
  a dish's cook may write only when no one else's note is on it. Tooltip
  "Made by B - has a note from A" when they differ. N.told pruned every 50
  eats. R.MIN_GAME_MS 1 s -> 0.5 s (quick one-click games).
- GTP 1.8.5 (owner): (1) the crafting window's food recipes flickered --
  CookVanillaHooks set the duration label a SECOND time each frame (vanilla
  prerender sets it every frame), so its text / width flipped and the window
  re-laid out. Now the label's own setName adds the score in the same call
  (score rounded, refreshed every 500 ms). (2) "meat not found nearby": the
  cooking tab scan stopped after the first 800 items of any kind; now it walks
  everything and keeps every food (H.SCAN_FOOD_MAX 3000, logged when hit) and
  the evolved-recipe base / result items (H.EVO_BASE, from
  evolvedrecipes_index.txt); evoList asks RecipeManager only for those.
- GTP 1.8.6 (owner's console): the cooking tab's game-dish page called
  vanilla getRealEvolvedItemUse for NON-food ingredients -> "Object tried to
  call nil" (getHungerChange) every frame, logged even in pcall; now only for
  instanceof Food. The vitamin wrapper of ISAddItemInRecipe:complete is fully
  pcall'd (before and after) so it can never leave the action unfinished.
- GTP 1.9.1 (owner: "no idea what each food buff does"): IGUI_GTPC_BuffDesc_<kind>
  words, `K.buffEffectLine(kind, tier)` ("What it does: ... (strength xN)")
  under the dish tooltip's buff line, under the Cooking tab's "Buff now" and
  in the moodle; `K.buffListText()` (all five + family list + level
  strengths) added to every Cooking page's "i" help.
- GTP 1.9.4 (owner: "take out the minigame where you press as the ring
  meets the frame, put another one in"): the "ring" kind is GONE; knead /
  pound / crack / toss are kind "spot" (CookGames SPOT {hits, spread}):
  a target spot sits on the food (above the pan for toss) until it is hit;
  a hit scores 1 at the middle down to 0.4 at the rim (P:newSpot, spotR =
  30 (crack 22) x tol x (1 - 0.3 d), min 14), a click off the spot costs
  0.08 ("Splash"); quality = average x a time cut after half the limit.
  No beat. Texts IGUI_GTPC_Game_Hits + the four Tip lines rewritten.
- Chopping game: TWICE the cuts (`CUT_MUL` 2, one click = one cut; owner
  "หั่นเพิ่มเป็น 2 เท่า"). "Half the minigame time below the dish's level" was
  tried and taken back (owner: original time).

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

## How to Survive (HomeMedic)
- Patient Zero trait removed (0.32.8, owner): `EHR_Professions.lua`
  (PATIENT_ZERO_REMOVED: never grants immunity, taken off old characters,
  logged) + `EHR_PatientZeroTraitToggle.lua` (always hidden in creation).
  Sandbox PatientZeroTraitDisabled now only decides Gene Therapy's permanent
  immunity (`EHR.KnoxCure.IsPatientZeroTraitEnabled`, unchanged).
- A TOC amputation outside the Surgery tab costs 50% of full blood
  (0.32.8, `shared/HARMONIEHomeMedic/HM_AmputationBlood.lua`, wraps
  `AmputationHandler:execute(true)`; server / SP only -- blood lives on the
  server). The Surgery tab's amputation sets `HM_Surgery.amputatingNow` so it
  is not charged twice (its grade already costs -10..-50%).
  Never below 10% (0.33.4, owner choice "ข"): `HM_AmputationBlood.MIN_LEFT`
  -- the saw cut and the Surgery tab's amputation (HM_SurgeryServer) take
  only down to 10% of full blood, because blood under ~5% never regenerates.
- Overdose health cap (45..63, `medication_overdose` in EHR_Medication) is
  raised to `EHR.Lethal.floor()` when illnesses are not lethal (0.33.4).
- TOC Left/Right Side + Prosthesis Familiarity levels stay as TOC made them
  (owner, 2026-11-11, option 1).
- `TOC.CicatrizationSpeed` is a double 1.0-10.0 (0.33.4; was integer: 1 -> 2
  jumped from ~33 to ~3 in-game days for an uncleaned hand stump), with
  EN/TH tooltips giving the days per value.
- Hypothermia stage 4 talks like the worst stage (0.33.5): with the stage
  following the body temperature (default) stage 4 is <= 31 C, but the
  definition's stage 4 lines were recovery lines ("*warming up* I thought I
  was going to die..."). `temperatureStageEntryDialogue` / `temperatureDialogue`
  in its definition are used for a temperature-driven stage (BodyTemperature
  entry line, Disease CheckDialogue); the old lines stay for the time-based
  mode (body temperature off), where stage 4 really is recovery.
- Every listed sign is shown and real (0.33.6, owner): `HM_Diagnosis.STAGE_SIGNS`
  is the spec. Tab 3 (HM_Stats signRows) shows the measured signs AND every
  sign of the patient's illnesses at their current stage
  (`HM_SignEffects.currentSigns`): measured -> reading, measurable but low ->
  "not at the threshold yet", observed -> "N min ago" (event times in
  `EHR_Disease.hmSignEvents`, EHR syncs it) or "present". `HM_SignEffects`
  (server / SP, every 10 s) gives a mild real effect to the (illness, stage,
  sign) EHR leaves without one: stage 1 of the ApplyEffects illnesses (it runs
  from stage 2 only), corpse "eye_burn" (was a line), delirium "confusion"
  (had nothing). Never touches health; a medicine for that illness cuts it to
  40%. It wraps EHR.Environmental Trigger* + scabies ApplyScratch to record
  EHR's own events. Cellulitis' wound counts as inflamed (sourceBodyPart).
  A new sign or illness: add it to STAGE_SIGNS and, if EHR does not do it,
  an `E.EFFECT[tag]` (the console says "no effect written for it").
- Diagnosis tab (HM 1.0.9, owner 2026-11-18): THREE columns -- signs (left),
  likely illnesses (MIDDLE, two-line rows), findings (right); scrollL /
  scrollM / scrollR, each clipped. First chip group "Cause" =
  `D.CAUSE_GROUP` (c_raw_meat, c_dirty_hands, c_dirty_water, ...) with
  `D.CAUSES[illness]` from each illness's real EHR trigger (codex Cause
  lines); kept OUT of D.GROUPS / STAGE_SIGNS (tab 3 and the handbook read
  those) and only added to D.TAGSET, so D.candidates counts them like signs.
  Hover = UI_HomeMedic_Diag_CauseTip_<tag>.
- Prosthesis duplication (HM 1.0.8, owner 2026-11-18): B42 MP checks the
  wear / unequip actions on the client AND the server; TOC's
  ProsthesisHandler.Validate / CheckIfEquippable read getPlayer() (nil on a
  dedicated server) and the server's highest-amputated-limb cache could be
  empty, so the server refused what the client had done -> two copies. Now
  they take the action's character, the server runs
  CalculateHighestAmputatedLimbs when its cache is empty, "can't equip" is
  said only on the local game, each wear / remove of a prosthesis is logged
  on both sides (HMLog "Prosthesis", item id + done / NOT done), and the
  extra-action test item is made once per action, not every tick. Never use
  getPlayer() in a shared timed-action check.
- Prosthesis picture in the medical window's body diagram (HM 1.0.10, owner
  screenshot): TOCBridge drawMissingLimbs draws it at BODY_OFFSET +
  (PROST_PART_DX/DY = 9, 10) when the black arm came from the panel's own
  part textures (they land +9,+7 from BODY_OFFSET), + (0, 3) when the arm is
  TOC's picture at BODY_OFFSET. Measured from the screenshot by fitting
  TOC's ForeArm / ProstArm alphas. TOC's vanilla health panel is unchanged.
- Delirium starts on the SERVER in MP (0.33.8): EHR's trigger (12 game h at
  >= 98% stress) is in `client/ExtensiveHealth/EHR_Delirium.lua`, so in MP the
  illness was only in the client's modData -- the server never had it,
  Antipsychotics (UseMedication runs on the server and treats only
  `EHR_Disease.active[id]`) started no course, and the next sync wiped it.
  `shared/HARMONIEHomeMedic/HM_DeliriumServer.lua` runs the same rule on the
  server (logs the clock start / reset / start); the client trigger returns on
  `isClient()`. SP unchanged. Any other client-folder illness trigger has the
  same trap: illnesses must be contracted where EHR is authoritative.
  Audit (0.33.9): server-side or guarded already -- EHR_Disease food /
  environment / corpse / wound / sepsis / concussion (client nominates) /
  painkiller addiction / AHTR (MP transfusion on the server) / stitch
  cellulitis (StitchCellulitisRisk) / body temperature. Not guarded: insomnia
  (`EHR.Insomnia.Contract`) and scabies (`EHR.HyperkeratoticScabies.Start`):
  `shared/HARMONIEHomeMedic/HM_ContractRelay.lua` wraps them on an MP client to
  send `HARMONIE_HM_Contract/Request` instead; the server starts them with the
  same function (sender only, relayed ids only, 1 min per illness, logged).
- Scabies ground roll (HM 1.0.5, owner's audit): EHR_HyperkeratoticScabies
  OnTick ran on the MP client AND the server -> chance doubled (the relay
  already stopped client ghost copies). Now ONE roller: the MP client (sees
  its own sitting) -> HM_ContractRelay -> server Start; a server never rolls
  it; a client without the relay never rolls. Relay drops the request when
  HyperkeratoticScabiesEnabled is off. Symptom cooldowns
  (EHR_DiseaseCanTriggerSymptom) have a server Lua-memory mirror keyed
  owner|illness|startTime|key (owner set in ApplyEffects): a cooldown wiped by
  old modData is put back and logged ("symptom cooldown ... was lost").
  Owner's server: DiseaseSpeed 1.0, ScabiesChanceMultiplier 1.0 (console).
  Audit of every other illness (same day): server-only already --
  EHR_Disease, CorpseSickness, Environmental (heat stroke, pneumonia),
  BodyTemp (hypothermia), WoundInfection / sepsis; MP sent to the server --
  transfusion (AHTR), stitch cellulitis, food / poison; insomnia runs both
  sides but is a threshold (no roll) and the relay drops a second start;
  delirium fixed 0.33.8. Concussion (falls / vehicle crashes) WAS rolled twice
  (server tracking + the client's ConcussionCandidate after the 0.02 h failed
  cooldown): a dedicated server now rolls those two sources only inside
  ConcussionCandidate (`EHR.Concussion._fromCandidate`).
  Scabies wounds capped (owner choice 3): stage 2 / 3 scratch every 3 / 1
  in-game h (2.5 real min on the owner's DayLength 3). ApplyScratch keeps
  disease.hmScabiesParts (part index string -> true, healed ones pruned);
  at sandbox ScabiesMaxOpenWounds (default 3, 1..20) open, a new scratch
  re-opens one of them instead of a new wound.
- Sound volume (HTS 1.1.0, owner: "the delirium volume -> every HTS sound"):
  `client/HARMONIEHomeMedic/HM_SoundVolume.lua` (HM_Sound): master x group
  (cough / pain / delirium / medical), Options -> Mods + settings window
  (soundMaster, coughVolume, painVolume, medicalVolume, deliriumVolume ids).
  Emitter sounds: emitter:setVolume(handle, v) right after they start
  (HM_Sound.adjust / playOn); UI sounds (HM_Surg_*): playUISound at 100,
  nothing at 0, else PlayWorldSound at the player + setVolume (fallback full).
  Delirium keeps its loudness copies (level = master x delirium). Coughs /
  sneezes in MP: the server no longer sendPlaySound's them;
  `shared/HARMONIEHomeMedic/HM_SoundNet.lua` sends "HARMONIE_HM_Sound"/"play"
  {id, sfx} to clients within 60 tiles, each plays it on that player
  (getPlayerByOnlineID) at its own volume. A new HTS sound: play it through
  HM_Sound.playOn / playUI / adjust with its group.
- Long timed actions (HTS 1.1.1, owner: "the bar over the head takes 20 s+
  after adding food"): TOC's adjustMaxTime override logs "[ActionTime]" once
  a minute per action type whose final time >= 900: asked / after the game /
  after TOC (the cut-limb multiplier x2-x4 only applies with an amputation).
- NEVER raise health the base game took (HTS 1.2.1, owner 2026-11-21: "a
  neck scratch never takes HP below 30 -- do not touch vanilla wounds").
  HM_NonLethal `spare()` used to SET health back to the floor every time it
  skipped one of OUR kills -- EHR's blood loss check runs every second while
  EHR blood < 20 %, and a vanilla bleeding wound drains EHR blood, so a neck
  scratch could never take HP under the floor (owner's server: 30). Now
  spare() only skips our kill. The safety net (N.guard) counts only OUR
  illnesses (active EHR illness / sepsis; low blood, food sickness and
  poison no longer) and stands aside while a vanilla damage source is on the
  character (any body part bleeding / scratched / cut / deep wound / bitten /
  bullet / glass / burn, food sickness, poison, hunger or thirst > 0.6). The
  saline (hemodilution) path no longer lifts health either. Our own damage
  paths still clamp at the floor (EHR_Disease / Sepsis / Environmental /
  overdose cap) -- they only LOWER health, never raise it.
- A diagnosed illness shows stage / severity / progress / treatment at any
  Doctor level (HTS 1.2.2, owner: "why ??? after a diagnosis"): EHR showed
  them only from Doctor 4 / 6. HM_DiagnosisPanel's getDiseaseDisplayInfo
  wrapper (health panel rows) and EHR_MedicalMonitorUI (hmDiagnosed) turn
  them on for a gated illness the Diagnosis tab diagnosed (Knox and rows with
  their own detail text -- delirium, concussion -- unchanged).
- Right-click with many players (HTS 1.2.3 / GTP 1.9.2, owner 2026-11-22):
  ONE "Check Nutrition" (ตรวจโภชนาการ, IGUI_HARMONIE_AssessMenu) with the
  names (GTP Hotkeys). HTS 1.2.5 (owner: "the health check does not show as
  reliably -- always there, with a check-myself entry; draw blood its own
  entry when an empty bag is carried"): "Examine Health" (ตรวจสุขภาพ) is on
  EVERY right-click (SP too), first row "Check my own health"
  (UI_EHR_Context_ExamineSelf), then `EHR.MPExamination.NearbyPlayers`
  (clicked + online within LIST_RANGE 8, nearest first; beyond
  EXAMINE_RANGE 3 greyed "Too far"). "Draw Blood" (เจาะเลือด) is a separate
  entry only while DB.carriedEmptyBag (inventory + bags), same names, beyond
  DB.RANGE greyed. The hub's "HARMONIE: open a tab" stays as it was.
- Prostheses (HTS 1.2.3, owner): names say the side (แขนเทียม (ซ้าย) / (ขวา));
  any stump takes one, the UPPER ARM too (ProsthesisHandler.CheckIfEquippable
  no longer refuses UpperArm; group Top_L/R covers every arm part); a
  prosthesis of the other side is worn through vanilla's clothing extra
  action (the item's own "Install prosthesis on right / left arm" option) --
  the health panel's body-part menu lists both sides and uses
  ISClothingExtraAction for the other one; wearing the wrong side says which
  option to use (UI_Say_ProstUseRight / Left). Amputation tab art has
  UpperArm_prost (tools/gen_amputation_art.py). A prosthesis on an unhealed
  stump CAN bleed (TOC TryRandomBleed after each action, chance from the
  cicatrization time left): the bleed lands on the part ABOVE the stump
  (Hand -> ForeArm, ForeArm -> UpperArm, UpperArm -> Torso_Upper), which is
  not a missing limb, so HealArea never clears it -- now logged
  ("[Prosthesis] ... bleeding").
- TOC amputee traits (HTS 1.2.3, owner: "the trait takes the arm but nothing
  knows it is cut"): the client asked for the trait cut ONCE when its data
  arrived. Now ServerDataController.Initialize also applies it
  (ApplyTraitAmputation: hasTrait on the server, no damage, healed stump,
  skipped when already cut); RelayApplyTraitAmputation no longer throws on a
  missing instance; FinalizeAmputationAction carries patientUsername (the
  client wrote its cache under a nil key); [TOCTrait] logs the steps and every
  trait of the character once per login (an amputation trait of ANOTHER mod
  hides the arm but tells TOC nothing -- find it there).
- Stump care in the medical window (HTS 1.2.6, owner 2026-11-24):
  right-click the blacked-out (amputated) part -- yours or a patient's --
  opens ONE menu built by TOCBridge `T.stumpMenu` (wraps
  EHR_HealthPanelUI.openBodyPartContextMenu; a click on a missing hand under
  a cut forearm means the forearm, `stumpOf`): "Clean wound (dirt %)" with
  the carried disinfected bandages / rags ONE row per type (xN), or greyed
  with why (none carried / clean / healed); fit a prosthesis (yours:
  T.prosthesisOptions; a patient's: "Fit prosthesis on them" ->
  HM_StumpCare.requestFit); TOC's cut-higher option (T.addOptions skipClean).
  `shared/HARMONIEHomeMedic/HM_StumpCare.lua`: HM_CleanStumpAction does the
  cleaning in complete() (server in MP) on the PATIENT's TOC data + dc:apply
  -- TOC's CleanWoundAction sent UpdateDataControllerFromClient, which the
  server files under the SENDER, so cleaning a patient changed the doctor's
  data. Fit on another (MP): "HARMONIE_HM_Stump"/"Fit" {patient, item, side}
  -> server checks range 3, CheckIfEquippable, no prosthesis on that group,
  moves the item (side's own type) to the patient, sends "Wear" -> the
  patient's game queues its own ISWearClothing once the item arrives.
  Refusals "Refused" {why} -> UI_HomeMedic_Stump_No_<why>.
- HTS 1.2.7 (owner: "clean by right-clicking the row that shows the scar
  %"): the selected part's detail box remembers its rows (hmPartRows); a
  right-click on the stump's healing (toc_healing) or dirtiness (toc_dirt)
  row -> EHR_HealthPanelUI:onRightMouseUp -> T.stumpMenu(..., cleanOnly =
  true). The dirt row says " - right-click to clean". The body-part menu
  keeps its clean option too.
- HTS 1.2.8 (owner: "a fully healed stump came back fresh after the other
  hand was cut"): TOC heals stumps on the CLIENT (EveryHours) and only sends
  UpdateDataControllerFromClient; every new cut makes the server `apply`, and
  the client then REPLACES its tocData with the server's ModData copy. Guards:
  (1) server `DataController:apply` re-links ModData[key] to the live
  `self.tocData` when they differ (ServerDataHandler.AddTable can swap it);
  (2) `ClientDataController.KeepLocalHealing` (own player only): a limb cut
  in both copies that is healed here but fresh in the server copy stays
  healed, and a lower time-to-heal here wins; those limbs are sent again.
  A cut limb can only become fresh by being uncut first, so this never hides
  a real change. (3) UpdateDataControllerFromClient loads the instance
  (GetOrCreate, no apply) instead of throwing. Log tag [TOCSync].
- HTS 1.2.9 (owner 2026-11-27):
  * Saline to another player: EHR's "Administer Medication" window listed
    blood bags only. `isBloodBagFullType` (EHR_MPAdministerMedication) and the
    server's validateRemoteTreatment now count ExtensiveHealth.SalineBag as
    treatmentKind "blood_transfusion" (IV kit + patient consent);
    applyRemoteBloodTransfusion calls applyServerSalineBag for it (no XP,
    like self-use). Logged [Transfusion].
  * Our moodles `client/HARMONIEHomeMedic/HM_Moodles.lua` (owner: blood
    moodle like GTP's, then "any other moodle we should have -- all of
    them"). MoodleFramework, SOFT (HTS does not require it -- nothing
    without it). M.DEFS = { name, fn(player) -> level, title, desc, sig };
    title / description per level via setTitle / setDescription
    (UI_HomeMedic_Moodle_*): the reading, what this level does, the next
    level ("Next" = below, "NextUp" = from), the fix. Texts follow the
    sandbox (blackouts, LethalConditions, regen numbers).
    - HM_BloodLoss: EHR stages, 1 healthy > b >= mild, 2 >= moderate,
      3 >= 20 percent, 4 below (BloodImpact stamina ceiling + thirst,
      BloodVision, EHR blackout / lethal).
    - HM_Saline: transfusedSaline / currentVolume, 1 >= 20, 2 >= 30,
      3 >= EHR HEMODILUTION_WARNING (40: fatigue up, stamina <= 30),
      4 >= HEMODILUTION_THRESHOLD (60: exhausted, health falls / death).
    - HM_Stump: own TOC data, a visible cut limb not cicatrized; 1 healing,
      2 dirt >= 30, 3 dirt >= 60, 4 prosthesis worn on it; rows per stump.
    Icons tools/gen_moodle_icons.py -> media/ui/<name>.png + Moodles/128.
    EHR's own moodles stay off (EHR_Moodles ENABLED false, owner 2026-10-02).
    If an effect changes, change these texts too.
- Medical item pickers (remote panel, `collectDoctorInventoryItems`) list ONE
  item per type (carried first) since HTS 1.2.6 (owner: the same bandage
  listed once per item nearby).
- Amputation tab time left (HTS 1.2.6, owner: "days shown do not match the
  game"): TOC adds the arm's VISIBLE dirt + blood to the stored dirtiness
  every in-game hour, so hoursToHeal(cicTime, dirt, vis) counts it; the tab
  shows % healed, time left in game and in real time (getMinutesPerDay), and
  a "dirty: clean it" hint.
- Pills (0.33.10, `shared/HARMONIEHomeMedic/HM_MedLog.lua`): EHR's own log
  prints only errors by default, so nothing said a pill was taken. Tab 1's
  ACTIVE MEDICATIONS = `EHR_Medication.activeDoses` (shown while in effect:
  painkillers 3 h). Path: vanilla ISTakePillAction -> EHR_MedicationHook ->
  SP writes the dose / MP `UseConsumedMedication` on the server, which
  records ONLY items in `EHR.Medication.Database` (SP records any FirstAid /
  Medical item as generic). The wrapper logs each pill (client + server
  result with dose status) and records an unlisted medical item on the server
  with `TrackDoseOnly` (tier 0) like SP.
- A doctor draws a patient's blood with consent (0.33.11, MP,
  `shared/HARMONIEHomeMedic/HM_DrawBloodFrom.lua`, module HARMONIE_HM_DrawFrom):
  right-click a player within 3 tiles -> "Draw blood (name)" (needs an empty
  blood bag) -> server checks (alive, distance, doctor's empty bag, patient
  >= 80% blood, known type) -> patient's Yes/No (60 s) -> doctor's timed
  action (~13 s, perform only) -> server re-checks, takes the bag and 500 mL
  (EHR.Blood.ModifyBloodVolume), gives the doctor a fresh bag of the PATIENT's
  type (EHR_BloodSpoilage + EHR_DonorBloodType, like EHR's own DrawBlood).
  Every step logged ("[DrawBlood]").
  Button (0.33.12): "Draw Blood" (red) left of "Administer Medication" in
  the remote health panel header (tab 1, `drawBloodButton`, x = width-442),
  calls `HM_DrawBloodFrom.ask`; the right-click option stays.
- Medical items within reach (0.33.12, `shared/HARMONIEHomeMedic/HM_Reach.lua` -- since 1.0.0 an alias of the hub's HARMONIE_Reach,
  owner: "ต้องดูทั้งในตัว ในกระเป๋า และในกล่องรอบๆ ... ทั้งห้อง"): inventory +
  bags (any depth), then every container (+ bags lying on the floor, 3 deep)
  on squares of the player's ROOM (same z, <= 12 tiles; any container 1 tile
  away counts), outdoors <= 3 tiles. Client caches 500 ms; never per tick.
  Used by: `EHR.Medication.FindMedicalSupply` (IV kit / syringe fallback),
  `EHR.MPMedication.GetInventoryMedications` (doctor's list) + its
  `findInventoryItemByID`, server `findInventoryItemByID` /
  `findInventoryItemByFullType` (so RemoveItem / UpdateItemDelta / administer
  / transfusion / DrawBlood resolve a box item; server removes with
  sendRemoveItemFromContainer), `HM_DrawBloodFrom.findEmptyBag`, HM_Surgery
  `collect` (boxes room-wide; loose floor items still S.REACH = 1),
  HealthPanelUI `collectDoctorInventoryItems` (bandage / disinfectant / splint
  pickers), HM_DoseReminder `hasItem`, TOC cut-limb bandage / suture needle /
  needle / thread (moved into the inventory first: `toPlayerInventory` /
  `HM_Reach.bring` = vanilla transferIfNeeded).
  MP sync guards (0.33.13, owner: "ระวังปัญหา server ไม่ซิงก์"): a world box is
  changed by the SERVER only -- EHR ConsumeOneDose on an MP client sends
  RemoveItem / UpdateItemDelta for an item that is not carried
  (`HM_Reach.clientMustNotTouch` / `isCarried`) without touching it
  locally (`notePending`); the server looks it up itself (+2 tiles slack,
  `SERVER_SLACK`) and, when it is gone, `HM_Reach.serverMissing` logs once
  and sends `HARMONIE_HM_Reach/Missing` -> the client drops its cache and
  says "not there any more" (only for its own pending box requests).
- Disease flyers (HM 1.0.2, owner "หนังสือโรคอ่านไม่ได้"): other mods start
  vanilla ISReadABook themselves (AutoAll "Read" is on the owner's list) and
  skip EHR's readItem hook -- vanilla only marks the pages read, so nothing
  was learned. `client/ExtensiveHealth/EHR_FlyerHook.lua` now also wraps
  `ISReadABook.new` on the client: a flyer becomes ISEHRReadFlyerAction
  (`refused` = First Aid below half the unaided level -> isValid false).
  The refusal / learned / already-known lines use `EHR.Locale.SayAction`
  (the 1-line-a-minute limit dropped them: the flyer looked dead). Steps
  logged with HMLog "[Flyer]" (EHR.Log prints only errors).
- TOC XP multipliers (HM 1.0.3, owner choice 2): sandbox
  MultiplierConfig.Side_L / Side_R / ProstFamiliarity are the game's own
  per-skill multipliers, read by vanilla only with GlobalToggle OFF (owner's
  server: Global 3.0, toggle on -> they did nothing). `shared/HARMONIEHomeMedic/
  HM_TOCXp.lua`: with the toggle on, TOC XP x the TOC value before addXp (the
  game then adds the global): 3 x 2 = 6; toggle off -> x1 (no double). Every
  grant: ExpActions server branch + RelayAddXp (TOC perks only, <= 1000 per
  packet). The settings window shows only those three of MultiplierConfig --
  UIKit serverRows takes `{ ns = "...", only = { Name = true } }` (hub).
  Default 5.0 for all three (owner). A save made before keeps its 1.0.
  XP from EVERY timed action (HM 1.0.4, owner): shared/TOC/ExpActions.lua
  watches ISTimedActionQueue (current + getCharacterActions not empty) in
  OnPlayerUpdate for local players -- no per-class update() wraps (most
  actions override update without the base). MP client sums, RelayAddXp on
  action change / every 300 ticks; SP adds at once. ExpActionsClient.lua
  emptied (it double-counted transfer / grab). skipTOC / noExp still none.
  XP is 0.01 per action tick; level 10 = 29,350 XP. Levels only shorten
  actions (BaseTimedActionOverride: limb x2/3/4 - level/10, never < x1).
- No illness on a missing limb (0.32.9, owner): TOC clears only vanilla
  wounds; `shared/HARMONIEHomeMedic/HM_AmputatedParts.lua` clears EHR's
  per-part records (wound infection parts / incubating / antisepticBlocked /
  immuneContained -- keyed by the same names as TOC limbs -- the vanilla
  infected-wound flag, cellulitis whose sourceBodyPart is gone) at the cut
  (called from the HM_AmputationBlood wrapper) and every 5 s for players with
  a cut limb (stump or prosthesis). Whole-body illnesses stay. Server / SP.
- Amputation tab (0.33.0, `client/HARMONIEHomeMedic/HM_AmputationTab.lua`,
  tab id "amputation" after Surgery): per arm the highest cut part, stump
  healing (TOC cicatrization hours vs 120/144/192), cauterized, dirtiness,
  bite, prosthesis, action time multiplier; Left/Right Side and Prosthesis
  Familiarity levels. Read only, from TOC's DataController.
  Pictures (0.33.3): `tools/gen_amputation_art.py` (run with /usr/bin/python3,
  it has Pillow) writes `tab_amputation.png` and `amp/arm_<L|R>_<none|Hand|
  ForeArm|UpperArm|Hand_prost|ForeArm_prost>.png`. TOC's cicatrization time
  is NOT hours: every in-game hour it drops by max(0.1, CicatrizationSpeed -
  dirtiness) and dirtiness grows 0.01 x multiplier per hour (+ blood / dirt on
  the arm), so an uncleaned hand stump takes ~800 in-game hours. The tab shows
  that estimate in in-game time (`hoursToHeal`); CleanWoundAction lowers dirt.
- The medical window no longer opens with the character window by default
  (0.33.0): option id `followCharWindowV2` (new id so old saved "on" is not
  read), default off; the heart button follows the same option and leaves
  an open medical window alone when it is off.
- A kill site that runs every tick must not talk before `EHR.Lethal.spare`:
  EHR_Blood said "*collapses*" every second while blood stayed <= 5% with
  deaths off (0.33.1). With deaths off it now calls spare() only (spare says
  "*collapses*" once a minute); "*heart stops*" (< 20%) the same.
- Talking limits (0.33.2, owner): every line the character says by itself
  goes through `EHR.Locale.Say` (EHR_Localization.lua): at most ONE line a
  minute per player and 10 minutes per line (real time); a line that does not
  pass is dropped (logged: once per line on cooldown + a count every 10 min).
  Answers to something the player just did use `EHR.Locale.SayAction` /
  `EHR.Dialogue.SayAction` (never dropped, still start the 1-minute gap):
  Medication dose / can't-use / too-early lines, Knox cure item answers.
  A reverse illness (concussion) speaks only on a NEW lowest stage
  (`disease.lowestStageSaid`, reset by SetStage) and logs "went back UP" when
  its stage rises -- look for that line to find what writes old data.
- Two writers on one stage = a talking loop: heat stroke's CheckHeatCooling put
  stage 4 back to 3 while hot and UpdateProgression put it to 4 again 2 s later
  (two "Still too hot" lines in turns). The generic branch now holds stage 3
  while `disease.coolingBlocked` (like hypothermia's warmthBlocked), 0.33.2.
  Audit 2026-11-10: every other tick-driven "*collapses*" / death line sits
  behind `EHR.Lethal.spare`; random symptom lines have cooldowns;
  `EHR.Environmental.CheckTreatment` is never called (dead).

## From Garden to Plate (GTP) farming
- No vanilla farming Lua in the repo; function names come from
  PZ-Umbrella/pz-lua-stubdata (yml/server/Farming): SFarmingSystem has
  `destroyOnWalk(luaObject, square)` (trampling), `plowFadeCheck`,
  `removePlant`; SPlantGlobalObject has `destroyThis` (trampled state),
  `killThis`, `dryThis`, `rottenThis`.
- Grown fruit trees are not trampled (0.13.19, owner,
  `server/Farming/FF_trampleGuard.lua`): FF crops with growBack (trees,
  vines, coffee) from stage `FROM_STAGE` = 3 skip destroyOnWalk and
  destroyThis. Seedlings, annual FF crops and vanilla crops are trampled as
  before. Installed at OnGameBoot (SFarmingSystem loads after "FF_"); logs
  once per tree per game day.
- A destroyed (trampled) plant is cleared from the plot by vanilla later
  (owner saw a trampled apple vanish, 2026-11-12) -- not ours.

## Life With Style (fashion)
- The wardrobe is server data (global ModData "HARMONIE_LWS", by owner key
  -- `LWS.ownerKey`, the one place to change for Discord accounts). Pieces
  are entries, not items; only a WORN piece exists as an item, made by the
  server (`LWS.Server.ensure`) and worn by the client.
- Slots and the catalog live in `tools/gen_lws.py` (one source): run it to
  rewrite registries.lua, the item scripts, LWS_Data.lua and ItemName.json.
  Texts: `tools/texts_lws.py`. Art: `tools/gen_lws_art.py`.
- Picture only (0.7.15, owner): a piece changes nothing on the body -- the
  script zeroes warmth / wind / water / bite / scratch / bullet / discomfort
  and keeps speeds at 1.0, and `LWS.plainClothes` sets them again on the real
  item (server ensure + client wear; logs before / after once). The Guardian
  proxy (gacha) is the one item that protects, on purpose.
- Never in the world (0.7.16, owner): no loot table lists a piece, but a piece
  shares its vanilla ClothingItem and the game keeps ONE item type per
  clothing model (zombie clothes -> items), so a zombie could drop OUR piece.
  `server/.../LWS_WorldGuard.lua` finds each piece's Base twin, logs which
  models the game maps to us, and on OnZombieDead (server / SP) turns fashion
  types in the zombie's visuals and inventory back into the twin; the sweep
  gives the twin for a fashion item without an owner mark. A clean cure needs
  our own clothingItems XML copies (vanilla XML not in the repo).
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
  call only methods the animal has and log which exist; a pet that drifts
  off its stay / waiting spot is stopped there, and
  OnWeaponHitCharacter on a pet puts its health back. Following (0.7.7): WAITING by the owner
  (stopped, blocked, idles like a staying pet) until the owner is farther
  than `P.FOLLOW_FROM`, then FOLLOWING until within `P.REST_NEAR`; a follower
  that makes no progress waits when close (and its follow line moves out,
  `rec.waitFrom`, so it never flips back at once) or is brought over when
  far. The MP client shows the walk only above `C.WALK_MIN_SPEED`. Zombie fear (0.7.8, `P.fearTick`, sandbox PetZombieFear /
  PetFearRange): a zombie within the range -> pain voice (`scared` in
  `LWS.PET_VOICE`), runs `P.FLEE_DIST` away from the zombies' centre
  (`P.pathToXY`: the animal's pathToLocation, else PathFindBehavior2 -- the
  console says which), sits, runs again if one comes close; calm after
  `P.CALM_MS` without a zombie within range + `P.CALM_EXTRA` (a staying pet
  walks back to its spot, `rec.returning`). "Come" = brave for `P.BRAVE_MS`.
  Gunshots alone still do not scare it. Menu (0.7.11): every action of the
  owner's own pet works from the ground right-click -- `PM.comeThen` calls it
  over (PetCome) and acts once it is within `PM.COME_NEAR` (15 s timeout).
  Hunger: default 360 h; a sandbox still on the old 72 is read as 360. Pet state (0.7.14): the
  `PetState` sent at spawn says out = false (the animal is not in the world
  until a tick later) -- `P.step` re-sends it while `rec.sentOut` is wrong,
  and a client whose menu finds no pet asks with `PetStateAsk`. Assets: Companion Dogs, with permission -- `tools/import_pets.py`
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
- Discord gacha (0.7.9, the owner's file, `server/.../LWS_DiscordGachaBridge.lua`):
  the KnoxCoin bot writes `RWZ_GachaDeliveryInbox.txt` (Zomboid/Lua, SFTP);
  the server grants each new roll id (gacha item or pet piece) and writes
  `RWZ_GachaDeliveryReceipts.txt`; seen ids live in `HARMONIE_LWS`.discordGacha.
  Its owner key is `"u:" .. username` -- keep `LWS.ownerKey` in step with it.
- New Dawn set (LWS 1.1.2, owner): each piece +5 percent XP on every skill,
  all four +10 percent more = 30 percent (gen_gacha.py use.set 0.05 x4,
  SET_FULL_BONUS 0.10). The pieces are gacha COUNTS, not items or fashion:
  "equipped" in the Gacha tab (o.gachaSet, server), the client XP hook
  multiplies (GC.finalAward ... * (1 + setBonus)); taking one off, trading
  it away or using it up ends its share.
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
- LWS 1.1.1 (owner 2026-11-20, "the old vanilla test pieces confuse people"):
  the 25 "Test_*" pieces made from vanilla clothes are removed (gen_lws.py
  CATALOG = []). LWS has no fashion pieces of its own; they come from add-ons
  (LWS.addPieces -- HARMONIE_LWS_Tomb). LWS.CATALOG still holds the 16 pets.
  Wardrobe entries of the old pieces are pruned at load (catalog check);
  worn copies have no script any more and the game / sweep drops them.
- LWS 1.1.0 (owner 2026-11-20, Tomb's Wardrobe into the gacha): add-ons add
  pieces with `LWS.addPieces(list, source)` ({ id, slot, icon, icons, tex,
  src }; item scripts in OUR module so isOurPiece passes; `LWS.PIECE_BY_SRC`
  maps the other mod's full type -> piece). Colours: a piece with tex > 1
  keeps o.items[uid].tex (0-based); the worn item carries md.LWS_tex and
  `LWS.applyTex` sets its visual texture choice (server when made, client
  when worn); "SetTex" {uid, tex} command; the dress page shows "< Colour n /
  N >" for the worn piece; ensure re-makes the item when the colour changed;
  trade keeps tex. Discord bridge kind `piece` (piece id or source type,
  optional "#n" colour, 1-based). WorldGuard twins are Base-module only, so
  an add-on piece never turns into the other mod's real item.
- Add-on HARMONIE_LWS_Tomb 1.0.0 (`mods/HARMONIE_LWS_Tomb`, require
  HARMONIE_LifeWithStyle, TombBody, TombWardrobeALT): 181 pieces "Tomb_<Type>"
  from Tomb's Wardrobe - Alternative (Workshop 3616536783) clothes, generated
  by `tools/gen_lws_tomb.py <Tomb 42.20/media>` (SLOT_OF maps Tomb's body
  locations; names from Tomb's EN/TH ItemName; TOMB_PIECES.txt = the list for
  the bot). Nothing of Tomb's mod is copied (ClothingItem / icon names only);
  the extracted mod is NOT in the repo. LWST_NoDrop: TombAlternative.* loot rows
  removed on OnPostDistributionMerge, Tombwardrobe_* zombie outfits removed
  from ZombiesZoneDefinition at boot, a dying zombie loses any Tomb item.
  LWST_Convert (server / SP, every 10 s): a real Tomb CLOTHING item a player
  carries (any bag depth) becomes that player's wardrobe piece with its colour
  (owner choice). 1.1.0: Tomb's 26 bags are fashion pieces too (207 pieces;
  slot from CanBeEquipped: back / satchel / duffel / coffin -> "back", fanny
  -> waist, webbing -> outer); a real bag converts only when EMPTY, else the
  player is told (IGUI_LWST_EmptyBag, once a minute). Tomb's
  code uses a global `TWA` table and `twa:` body locations: unrelated to our
  The Way To Attack (we never use either); its log prefix is "[TWA]".
- Trading (`server/.../LWS_Trade.lua`): server sessions, both agree on the
  same revision, the server re-checks and swaps; any offer change unlocks
  both. Sandbox page HARMONIE_LifeWithStyle (TradeEnabled, TradeMaxDistance).


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
- Surgery tab (1.0.1, owner): every operation can be OPENED (view only when
  the patient has no indication: the prep checklist on every body part it
  can be done on, `opts.viewOnly`, Start off); Start works only with an
  indication (the server's S.evaluate checks again).
- Life With Style's right-click and window title are "แฟชั่นและไอเท็มกาชา" /
  "fashion and gacha items" (1.0.0, owner).

## The Way To Attack (TWA)
- Rare ores (2026-11-12, owner swapped them, TWA 1.0.2): Oridecon (โอริเดคอน)
  is the LOWER one -- base2 of the Epic bar and of Make_GemFine; Bradium
  (บราเดียม) the HIGHER one -- Legendary bar and Make_GemPure; Elunium stays
  on the Elite bar. Hand-edited in HARMONIE_TWA_RecipeData.lua (its generator
  is not in the repo; tools/gen_new_weapons.py only inserts weapon recipes).
- Craft button (TWA 1.0.3, owner): a base / extra item card whose item some
  recipe MAKES (`recipeMaking`: result map, keepType gem recipes excluded)
  shows "Craft" -> `TWACraftWindow:jumpToRecipe` (craft page, search cleared;
  locked while a recipe is under way). Rects in `self.craftLinks`.
- GTP vitamin tooltip box sits UNDER the item tooltip (above it when no room),
  GTP 1.0.2 (HARMONIE_TooltipHook.lua).
- GTP cutting minigame = rapid chop (GTP 1.0.3, owner "หั่นรัวๆ"): kind "timing"
  (chop / slice / mince / trim / core) in HARMONIE_CookGames.lua -- every
  click or Space is one cut (`P:chopOnce`), `CUTS[variant]` x (0.8 + 0.5 d)
  needed; no cut for CUT_GRACE_MS -> one cut lost every CUT_DECAY_MS; quality
  = full when done within 40% of the time limit, half at the limit; timeout
  before the last cut = Miss. Hints IGUI_GTPC_Hint_* / Tip lines say so.
- GTP cooking takes and makes (GTP 1.0.4, owner: the flow finished but never
  found the dish): `shared/HARMONIEGardenToPlate/HARMONIE_CookServer.lua`
  (module HARMONIE_GTP_CookTake, authority = server / SP). Start = "take":
  every planned ingredient AND the container are removed (inventory, bags,
  boxes in the room -- HARMONIE_Reach.findById), each snapshotted (type, age,
  cooked, hunger, condition, fluid, vitamins); a spice drainable loses ONE
  use. Nutrition + vitamins summed (whole items). Kept in player modData
  `HARMONIE_CookPending` {dish, result, items, nut, vit, units, step, words}.
  "progress" saves each finished step; "finish" AddItem(result type) with the
  summed hunger / kcal / carbs / fat / protein + AddVitaminsToItem, then
  K.applyQuality + K.giveXp; "cancel" recreates every snapshot (spice use
  back on the same shaker); death = cancel onto the body; "pending" lets a
  reopened window carry on (CookTab asks once, `F.resumeFrom`). No vanilla
  ISAddItemInRecipe any more; CookFlow phases: taking / game / action /
  paused / retry / blocked / finishing / done / failed (take | make) /
  cancelling. K.plan's preview = full values of the planned items.

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


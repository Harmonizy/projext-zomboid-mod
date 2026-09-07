CampFeverMod — a tiny starter mod (Build 42)
=============================================

What it does
------------
- Adds a disease, "Camp Fever", with 3 stages:
    Stage 1 (mild)    ~12h — light fatigue + a touch of vanilla sickness
    Stage 2 (peak)    ~24h — more fatigue/sickness + general pain
    Stage 3 (recovery)~24h — no new symptoms, just counts down to a cure
  It's rolled once per in-game hour (Events.EveryHours); risk goes up the
  hungrier/more tired your character already is.
- Adds one item, "Herbal Remedy" (uses the vanilla Pills icon for now).
  Right-click it in your inventory -> "Drink Herbal Remedy" -> cured instantly.

File map
--------
mod.info                                        - mod metadata, no poster/icon required to test
media/scripts/CampFever_Items.txt                - the HerbalRemedy item definition
media/lua/shared/CampFeverMod/CampFever_Disease.lua
                                                  - all disease logic + ModData (runs on both sides)
media/lua/client/CampFeverMod/CampFever_ItemUse.lua
                                                  - the right-click "Drink" context-menu option
media/lua/shared/Translate/EN/Tooltip_EN.txt     - the item's tooltip text

How to test
-----------
1. Launch Project Zomboid -> Mods -> enable "Camp Fever (Simple EHR-style)" -> restart.
2. Start/load a save. Camp Fever rolls automatically once an hour (very low base
   chance -- to force it instantly for testing, open the debug console and run:
       CampFeverMod.Disease.Contract(getSpecificPlayer(0))
   and to force-cure:
       CampFeverMod.Disease.Cure(getSpecificPlayer(0))
3. To get the cure item without crafting/loot, spawn it via the debug menu's
   item list (search "Herbal Remedy"), or add a starting-item cheat later.

Known limits (on purpose, to keep this readable as a first mod)
-----------------------------------------------------------------
- Singleplayer-focused: it drives `getSpecificPlayer(0)` directly and doesn't
  send/verify anything over the network. In multiplayer each client would run
  its own independent roll for itself, which happens to still "work" for
  self-contained single-player-style state like this, but isn't a properly
  synced MP design (no server authority, no client->server command). EHR's
  real approach uses server-side ModData + sendClientCommand for that.
- No loot table entry yet -- Herbal Remedy won't spawn naturally in containers
  until you add a `distributions.lua` / ProceduralDistributions entry for it.
- No stage-based icon/moodle, no immunity system, no dose-count tracking on
  the item (using it once always fully cures, regardless of stage).

Natural next steps, roughly in order of difficulty
----------------------------------------------------
1. Give Herbal Remedy a real recipe (media/scripts/CampFever_Recipes.txt +
   a `craftRecipe` block) instead of only spawning it via debug.
2. Add it to a loot list so it appears in medicine cabinets / herbalist bags.
3. Make the cure require 2-3 doses instead of one (track a dose counter in
   the same ModData table used for the disease).
4. Add a second stage-specific dialogue line or a UI moodle icon.
5. If you want multiplayer correctness, move the ModData writes to the
   server and gate them behind isServer()/sendClientCommand, the way EHR does.

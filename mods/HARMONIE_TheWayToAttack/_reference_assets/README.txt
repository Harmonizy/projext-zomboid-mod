Staging pool of art assets pulled from 2 reference mods (per user instruction,
2026-09-25) — NOT part of the mod's own media/ tree, so the game never loads
anything from here automatically. Pull individual files into 42/media/... as real
items get built.

Sources (give credit to these authors if this mod is ever published, and confirm
reuse permission was actually granted before publishing anything derived from
these files — see workflow.txt / WEAPON_CRAFTING_MOD_REFERENCE.txt for the fuller
note on this):

  MWPWeapons42/  <- from "[B42] MWPWeapons" (Madax's Melee Weapon Pack Reworked)
                    Steam Workshop ID: 3747202678
                    textures/, models_X/, scripts/ copied verbatim.

  SOMW/          <- from "Simple Overhaul: Melee Weapons (SOMW)"
                    Steam Workshop ID: 3052668642
                    textures/, models_X/, scripts/ copied verbatim.

Not copied (no texture/model assets to copy):
  - CraftedMeleeRebalance (Workshop 3769855058) — pure Lua stat rebalance, no new
    art. Its TECHNIQUE (ScriptManager+DoParam runtime item override) is already
    written up generically in mods/WEAPON_CRAFTING_MOD_REFERENCE.txt section 7 —
    reimplement it fresh under this mod's own namespace rather than copying its
    actual .lua files.
  - SOMW_EasySpearAttachments (also under 3052668642) — pure recipe scripts, no
    new art either.

The copied scripts/ folders still reference the SOURCE mod's own module name
(Base, or SOMW) and item IDs — when actually building HARMONIE_TheWayToAttack's
own items, re-namespace everything under `module HARMONIE_TheWayToAttack { ... }`
(see WEAPON_CRAFTING_MOD_REFERENCE.txt section 1) rather than leaving these files
as-is inside 42/media/scripts/.

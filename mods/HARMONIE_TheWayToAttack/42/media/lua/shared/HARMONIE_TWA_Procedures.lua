--============================================================================
-- HARMONIE_TheWayToAttack -- crafting procedure library (shared)
--
-- 2nd full rebuild (request 2026-09-26/27): 25 procedures this time, given
-- directly by the user in Thai with skill/tool/material per step, PLUS a
-- real rules engine (see gen_craftdata.js's `PROCEDURE_RULES`) that decides
-- which of these 25 a given recipe actually NEEDS from its own real stats
-- (CriticalChance/SubCategory/MaxRange/PushBackMod/KnockdownMod/
-- ConditionMax/ConditionLowerChanceOneIn) -- unlike the previous 31-
-- procedure library, THIS one is actually wired onto all 248 recipes.
--
-- Real item/tool verification (same discipline as every earlier round):
-- most materials were already grep-confirmed real in earlier rounds
-- (Whetstone/File/SmallFileSet, Tongs, Charcoal/CharcoalCrafted/Coke,
-- LeatherStrips, NutsBolts, Nails, ScrapMetal, BlowTorch, Wire, Pliers,
-- TinCanEmpty, SheetMetal, HandDrill, Rope, DuctTape, Bleach, Lighter,
-- MetalPipe). Newly confirmed THIS round: RippedSheets (real, Icon=Rag --
-- stands in for "เศษผ้า"/cloth scraps), Clay (real, exact match for
-- "ดินเหนียว"), Candle (real, exact match for "เทียน"), Thread (real,
-- base:drainable, no KeepOnDeplete -- used as a real substitute for
-- "เอ็น"/sinew, since neither "Sinew" nor "AnimalTendon" exist in vanilla,
-- grep-confirmed absent). LongStick/LongHandle already confirmed real
-- (used for the two handle-tier procedures' materials).
--
-- Real skill Perk names (see server/XpSystem/XPSystem_SkillBook.lua's own
-- mappings, confirmed in an earlier round this session): the user's own
-- category labels map to these real Perks -- "smith"->Blacksmith,
-- "carpentry"->Woodwork (matches vanilla's own real "Carpentry" skillbook
-- -> Perks.Woodwork mapping exactly), "tailoring"->Tailoring,
-- "wielding"(sic, welding)->MetalWelding.
--
-- Re-audited 2026-09-27 against the real in-game skill list (user posted a
-- screenshot of their own character panel): "carving" DOES have a real
-- vanilla equivalent after all -- Perks.Carving ("งานแกะสลัก"), grep-
-- confirmed real (server/XpSystem/XPSystem_SkillBook.lua, ISRadioInteractions.lua)
-- and its own real description is literally "อนุญาตให้แกะสลักหรือสร้างวัตถุ
-- ไม้ขนาดเล็ก" (carve/craft small wooden objects) -- a PERFECT match for
-- MakeHandle/MakeLongHandle (a SHARP_KNIFE whittling a stick into a
-- handle), which had been sitting under Woodwork only because Carving
-- wasn't known to exist yet -- moved to Carving:1/Carving:2 (same levels).
-- Balance's HammerNails (Hammer+Nails into a wooden weapon body) moved
-- Blacksmith:1 -> Woodwork:1, a real carpentry action (Assembly's separate,
-- noskill AssembleNails is untouched). CounterweightHead (Hammer/
-- Sledgehammer + tin can) moved FlintKnapping:1 -> Blacksmith:1, real
-- metalworking that had nothing to do with stone.
-- Maintenance and Mechanics were tried for several others in this same
-- pass (file/whetstone honing, wrench/bolts, hand drill, pliers+wire) but
-- explicitly REJECTED by the user ("ไม่อยากให้ใช้ Machanic กับ
-- maintenance") -- DON'T re-introduce either one, this was a deliberate
-- design choice, not an accuracy correction. Follow-up request: SharpenEdge/
-- StropLeather/CoatWax moved explicitly to Carving:1/Carving:2/Carving:1
-- (same levels as before) instead of back to FlintKnapping -- the user's
-- own call, given Carving already covers MakeHandle/MakeLongHandle's
-- knife-work just above. TightenBolts/PrecisionGrind/WeaveWire/
-- SurfaceCoating stayed on Blacksmith and DrillCore/TaperPoint stayed on
-- FlintKnapping (not named in that follow-up, so left alone -- don't move
-- these to Carving without being told to).
-- Every OTHER procedure's skill (ForgeShape/KnapHead/MakeRivetedHandle/
-- RivetPlate: Blacksmith with a real forge/hammer tool; ReinforcedBind/
-- WrapLeather/StringSinew: Tailoring with cloth/leather/thread; WeldMetal:
-- MetalWelding with a blowtorch; FireTreat: Woodwork, real fire-hardening)
-- was already correct and is unchanged.
--============================================================================

TWAProcedures = TWAProcedures or {}

local function predicateNotBroken(item)
    return not item:isBroken()
end

local function toolAlts(spec)
    if not spec then return nil end
    if spec[1] then return spec end
    return { spec }
end
TWAProcedures.ToolAlts = toolAlts

local function hasOneTool(spec, player)
    local inv = player:getInventory()
    if spec.kind == "tag" then
        return inv:containsTagEvalRecurse(ItemTag[spec.value], predicateNotBroken)
    elseif spec.kind == "type" then
        return inv:getFirstTypeEvalRecurse(spec.value, predicateNotBroken) ~= nil
    end
    return true
end

local function hasAnyTool(spec, player)
    if not spec then return true end
    for _, s in ipairs(toolAlts(spec)) do
        if hasOneTool(s, player) then return true end
    end
    return false
end

local function altTypes(c)
    if c.itemTypes then return c.itemTypes end
    return { c.itemType }
end

local function countAny(inv, types)
    local total = 0
    for _, t in ipairs(types) do
        total = total + inv:getItemCountRecurse(t)
    end
    return total
end

-- request 2026-09-27: "เตาตีเหล็กดั้งเดิมหรือดีกว่า / เตาตีเหล็กธรรมดา
-- หรือดีกว่า / เตาตีเหล็กขั้นสูง" -- real vanilla B42 blacksmithing gates
-- these on 3 tiers of PLACED forge entity (Forge_Primitive_Forge/Forge/
-- Advanced_Forge, real recipe Tags = PrimitiveForge/Forge/AdvancedForge,
-- grep-confirmed from entity_forge_i/ii/iii.txt and
-- recipes_blacksmith_bar.txt) -- a higher tier forge's own CraftBench
-- always lists every lower tier too (Forge II = "PrimitiveForge;Forge",
-- Forge III = all 3), so "or better" just means "highest tier found nearby
-- >= required".
--
-- Vanilla's REAL check is "is the player USING this specific placed
-- entity" -- a whole separate Entity/CraftBench subsystem this mod's own
-- standalone inventory-based UI has no hook into, and there's no confirmed
-- safe Lua path from a plain scanned IsoObject to its Entity definition
-- name (only found `logic:getEntity()` FROM an existing HandcraftLogic,
-- never a raw IsoObject -> entity accessor). Approximated instead as "is a
-- real forge of that tier's own sprite PLACED within 2 tiles", matched by
-- each entity's own real sprite row names (grep-confirmed from
-- entity_forge_i/ii/iii.txt's SpriteConfig blocks) via the same real
-- isoObject:getSprite():getName() API already used throughout vanilla.
-- FLAGGED (discussed with the user, who accepted this over not checking at
-- all): this is a practical, testable-and-fixable stand-in, not vanilla's
-- literal mechanism -- if it doesn't reliably detect a real placed forge
-- in-game, these sprite lists (possibly missing a tile/rotation not seen
-- in the entity's own multi-face SpriteConfig) are the first thing to
-- check.
local FORGE_TIER_SPRITES = {
    [1] = { crafted_01_61 = true, crafted_01_20 = true, crafted_01_21 = true, crafted_01_62 = true },
    [2] = { crafted_01_42 = true, crafted_01_116 = true, crafted_01_38 = true, crafted_01_54 = true, crafted_01_19 = true, crafted_01_36 = true },
    [3] = {
        crafted_02_25 = true, crafted_01_18 = true, crafted_01_39 = true, crafted_02_24 = true, crafted_02_32 = true,
        crafted_02_26 = true, crafted_02_27 = true, crafted_02_33 = true, crafted_01_35 = true, crafted_01_55 = true,
    },
}

local function nearbyForgeTier(player)
    local sq = player:getCurrentSquare()
    if not sq then return 0 end
    local cell = getCell()
    local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
    local best = 0
    for dx = -2, 2 do
        for dy = -2, 2 do
            local s = cell:getGridSquare(px + dx, py + dy, pz)
            if s then
                local objs = s:getObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    local sprite = obj and obj:getSprite()
                    local name = sprite and sprite:getName()
                    if name then
                        for tier, set in pairs(FORGE_TIER_SPRITES) do
                            if set[name] and tier > best then best = tier end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- 25 procedures, grouped into the 7 real gameplay-purpose categories the
-- rules engine (gen_craftdata.js) actually assigns by -- Sharpness/
-- Piercing/Handle/Balance/Structure/Toughness/WearResist. `category` here
-- drives the right-panel UI grouping only; the ACTUAL per-recipe
-- requirement logic lives in gen_craftdata.js's PROCEDURE_RULES, since it
-- needs each recipe's own real stat values (not available in this file).
TWAProcedures.List = {
    -- ===== Sharpness (สร้างความคม) -- Swinging weapons =====
    SharpenEdge = {
        category = "Sharpness", nameKey = "IGUI_TWA_Proc_SharpenEdge", icon = "Whetstone2",
        tool = { { kind = "type", value = "Base.Whetstone" }, { kind = "type", value = "Base.File" }, { kind = "type", value = "Base.SmallFileSet" } },
        consumes = {}, skill = "Carving:1", time = 100, sound = "SharpenBladeWhetstone",
    },
    -- Strop material widened to LeatherStrips OR RippedSheets (cloth strop
    -- is a real lower-grade substitute for a leather one) -- request
    -- 2026-09-27: "มีอุปกรณ์และวัตถุดิบที่ยืดหยุ่น ใช้อย่างอื่นแทนได้".
    StropLeather = {
        category = "Sharpness", nameKey = "IGUI_TWA_Proc_StropLeather", icon = "LeatherStrips",
        tool = { { kind = "type", value = "Base.Whetstone" }, { kind = "type", value = "Base.File" }, { kind = "type", value = "Base.SmallFileSet" } },
        consumes = { { itemTypes = { "Base.LeatherStrips", "Base.RippedSheets" }, qty = 1 } }, skill = "Carving:2", time = 150, sound = "SharpenBladeWhetstone",
    },
    -- Tool widened to any sharpening tool, not just a file (request
    -- 2026-09-27).
    PrecisionGrind = {
        category = "Sharpness", nameKey = "IGUI_TWA_Proc_PrecisionGrind", icon = "HotChisel_Forged",
        tool = { { kind = "type", value = "Base.File" }, { kind = "type", value = "Base.Whetstone" }, { kind = "type", value = "Base.SmallFileSet" } },
        consumes = {}, skill = "Blacksmith:3", time = 250, sound = "SharpenBladeWhetstone",
    },
    -- Tool widened to any heavy hammering tool (request 2026-09-27) -- same
    -- real ItemTag group KnapHead/StoneKnapping already used.
    ForgeShape = {
        category = "Sharpness", nameKey = "IGUI_TWA_Proc_ForgeShape", icon = "Ingot_Steel",
        tool = { { kind = "tag", value = "HAMMER" }, { kind = "tag", value = "SLEDGEHAMMER" }, { kind = "tag", value = "CLUB_HAMMER" } },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 2 } },
        skill = "Blacksmith:4", time = 400, sound = "Hammering",
    },

    -- ===== Piercing (สร้างความแหลม) -- Spear/Stab weapons =====
    -- Tool widened to any hammering tool -- real "any hammer" group already
    -- confirmed from ISPickAxeGroundCoverItem.lua's own check (request
    -- 2026-09-27).
    KnapHead = {
        category = "Piercing", nameKey = "IGUI_TWA_Proc_KnapHead", icon = "RockSharpened",
        tool = {
            { kind = "type", value = "Base.HammerStone" }, { kind = "tag", value = "HAMMER" },
            { kind = "tag", value = "SLEDGEHAMMER" }, { kind = "tag", value = "CLUB_HAMMER" }, { kind = "tag", value = "STONE_MAUL" },
        },
        consumes = {}, skill = "FlintKnapping:1", time = 150, sound = "SmashStoneHit",
    },
    TaperPoint = {
        category = "Piercing", nameKey = "IGUI_TWA_Proc_TaperPoint", icon = "Shaft",
        tool = { { kind = "type", value = "Base.File" }, { kind = "type", value = "Base.Whetstone" }, { kind = "type", value = "Base.SmallFileSet" } },
        consumes = {}, skill = "FlintKnapping:2", time = 150, sound = "SharpenBladeWhetstone",
    },

    -- ===== Handle (ติดตั้งด้าม) -- by MaxRange =====
    -- Material widened to LongStick OR Sapling (both real "long straight
    -- wood" items, already an established equivalent pair from this mod's
    -- own real spear-shaft alternatives).
    MakeHandle = {
        category = "Handle", nameKey = "IGUI_TWA_Proc_MakeHandle", icon = "Shaft",
        tool = { kind = "tag", value = "SHARP_KNIFE" },
        consumes = { { itemTypes = { "Base.LongStick", "Base.Sapling" }, qty = 1 } }, skill = "Carving:1", time = 150, sound = "CraftWeaponSpearWood",
    },
    WrapBind = {
        category = "Handle", nameKey = "IGUI_TWA_Proc_WrapBind", icon = "DuctTape",
        consumes = { { itemTypes = { "Base.DuctTape", "Base.RippedSheets", "Base.LeatherStrips", "Base.Rope" }, qty = 2 } },
        time = 100, sound = "FixWithTape",
    },
    -- Material widened to accept a raw LongStick too (more work, same
    -- result) alongside the finished LongHandle component.
    MakeLongHandle = {
        category = "Handle", nameKey = "IGUI_TWA_Proc_MakeLongHandle", icon = "LongHandle",
        tool = { kind = "tag", value = "SHARP_KNIFE" },
        consumes = { { itemTypes = { "Base.LongHandle", "Base.LongStick" }, qty = 1 } }, skill = "Carving:2", time = 200, sound = "CraftWeaponSpearWood",
    },
    -- Qty trimmed to reflect real relative scarcity (request 2026-09-27:
    -- "จำนวนที่สมเหตุสมผลต่อความหายาก") -- Thread/Glue are both single-slot
    -- craft materials in real play, not bulk-stackable like Nails/Charcoal,
    -- so 1 each is the realistic ask, not 2+.
    ReinforcedBind = {
        category = "Handle", nameKey = "IGUI_TWA_Proc_ReinforcedBind", icon = "Thread",
        consumes = { { itemType = "Base.Thread", qty = 1 }, { itemType = "Base.Glue", qty = 1 } },
        skill = "Tailoring:1", time = 150, sound = "CraftFixWeapon",
    },
    -- Material widened the same way as MakeLongHandle (LongHandle or raw
    -- LongStick); MetalPipe alt added (SteelBarHalf, real, already an
    -- established blacksmith-adjacent material this mod uses elsewhere).
    MakeRivetedHandle = {
        category = "Handle", nameKey = "IGUI_TWA_Proc_MakeRivetedHandle", icon = "MetalTube",
        consumes = { { itemTypes = { "Base.LongHandle", "Base.LongStick" }, qty = 1 }, { itemTypes = { "Base.MetalPipe", "Base.SteelBarHalf" }, qty = 1 } },
        skill = "Blacksmith:4", time = 350, sound = "Hammering",
    },
    TightenBolts = {
        category = "Handle", nameKey = "IGUI_TWA_Proc_TightenBolts", icon = "NutsBolts",
        tool = { { kind = "tag", value = "SCREWDRIVER" }, { kind = "tag", value = "WRENCH" } },
        consumes = { { itemType = "Base.NutsBolts", qty = 2 } }, skill = "Blacksmith:1", time = 150, sound = "Screwdriver",
    },

    -- ===== Balance (ถ่วงน้ำหนัก) -- by PushBackMod =====
    HammerNails = {
        category = "Balance", nameKey = "IGUI_TWA_Proc_HammerNails", icon = "Nails",
        tool = { { kind = "tag", value = "HAMMER" }, { kind = "tag", value = "SLEDGEHAMMER" }, { kind = "tag", value = "CLUB_HAMMER" } },
        consumes = { { itemType = "Base.Nails", qty = 5 } }, skill = "Woodwork:1", time = 150, sound = "Hammering",
    },
    -- Material widened to either real empty-can type (already an
    -- established real pair from this mod's own earlier AttachCan work).
    CounterweightHead = {
        category = "Balance", nameKey = "IGUI_TWA_Proc_CounterweightHead", icon = "TinCanEmpty",
        tool = { { kind = "tag", value = "HAMMER" }, { kind = "tag", value = "SLEDGEHAMMER" } },
        consumes = { { itemTypes = { "Base.TinCanEmpty", "Base.WaterRationCanEmpty" }, qty = 1 } }, skill = "Blacksmith:1", time = 150, sound = "Hammering",
    },
    WeldMetal = {
        category = "Balance", nameKey = "IGUI_TWA_Proc_WeldMetal", icon = "BlowTorch",
        tool = { kind = "tag", value = "WELDING_MASK" }, tool2 = { kind = "type", value = "Base.BlowTorch" },
        consumes = { { itemType = "Base.ScrapMetal", qty = 1 } }, skill = "MetalWelding:1", time = 400, sound = "CraftWelding",
    },

    -- ===== Structure (เสริมโครงสร้าง) -- by KnockdownMod =====
    -- Material widened to any real scrap-sheet-metal type (same established
    -- real alt group this mod's own AttachScrapSheet already used).
    RivetPlate = {
        category = "Structure", nameKey = "IGUI_TWA_Proc_RivetPlate", icon = "SheetMetal",
        tool = { kind = "tag", value = "HAMMER" },
        consumes = { { itemTypes = { "Base.SheetMetal", "Base.SmallSheetMetal", "Base.UnusableMetal", "Base.AluminumScrap" }, qty = 1 } },
        skill = "Blacksmith:1", time = 200, sound = "Hammering",
    },
    DrillCore = {
        category = "Structure", nameKey = "IGUI_TWA_Proc_DrillCore", icon = "Drill_OldFashioned",
        tool = { kind = "type", value = "Base.HandDrill" },
        consumes = {}, skill = "FlintKnapping:1", time = 150, sound = "CraftFixWeapon",
    },

    -- ===== Toughness (เสริมความคงทน) -- by ConditionMax =====
    -- Qty trimmed from 2->1: RippedSheets is common but this is already the
    -- FIRST/lightest reinforcement layer -- 1 is enough to feel like the
    -- cheap option it represents (request 2026-09-27: reasonable qty).
    WrapCloth = {
        category = "Toughness", nameKey = "IGUI_TWA_Proc_WrapCloth", icon = "Rag",
        consumes = { { itemType = "Base.RippedSheets", qty = 1 } }, time = 100, sound = "FixWithTape",
    },
    -- Qty trimmed from 2->1 -- LeatherStrips is scarcer than cloth (needs a
    -- real leather source + cutting first), so this 2nd reinforcement layer
    -- asks for less of a harder-to-get material, not more.
    WrapLeather = {
        category = "Toughness", nameKey = "IGUI_TWA_Proc_WrapLeather", icon = "LeatherStrips",
        consumes = { { itemType = "Base.LeatherStrips", qty = 1 } }, skill = "Tailoring:1", time = 150, sound = "CraftFixWeapon",
    },
    StringSinew = {
        category = "Toughness", nameKey = "IGUI_TWA_Proc_StringSinew", icon = "Thread",
        consumes = { { itemType = "Base.Thread", qty = 1 }, { itemType = "Base.Glue", qty = 1 } },
        skill = "Tailoring:1", time = 150, sound = "CraftFixWeapon",
    },
    -- Qty trimmed from 2->1: Wire is scarcer than cloth/leather (usually
    -- salvaged from fences/electronics, not found loose in bulk), and this
    -- is already the TOP/hardest reinforcement layer -- asking for less of
    -- the rarest material, not more, matches "reasonable relative to
    -- rarity" better than a flat qty across all 4 tiers.
    WeaveWire = {
        category = "Toughness", nameKey = "IGUI_TWA_Proc_WeaveWire", icon = "Wire",
        tool = { kind = "type", value = "Base.Pliers" },
        consumes = { { itemType = "Base.Wire", qty = 1 } }, skill = "Blacksmith:2", time = 200, sound = "CraftFixWeapon",
    },

    -- ===== WearResist (ลดการสึกหรอ) -- by ConditionLowerChanceOneIn =====
    CoatMud = {
        category = "WearResist", nameKey = "IGUI_TWA_Proc_CoatMud", icon = "Clay",
        consumes = { { itemType = "Base.Clay", qty = 1 } }, time = 150, sound = "CraftFixWeapon",
    },
    FireTreat = {
        category = "WearResist", nameKey = "IGUI_TWA_Proc_FireTreat", icon = "Charcoal",
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 1 } },
        skill = "Woodwork:1", time = 200, sound = "CraftFixWeapon",
    },
    -- Tool widened: Matches is a real, common alternative fire-starter to
    -- a Lighter (request 2026-09-27).
    CoatWax = {
        category = "WearResist", nameKey = "IGUI_TWA_Proc_CoatWax", icon = "Candle",
        tool = { { kind = "type", value = "Base.Lighter" }, { kind = "type", value = "Base.Matches" } },
        consumes = { { itemType = "Base.Candle", qty = 1 } }, skill = "Carving:1", time = 150, sound = "CraftFixWeapon",
    },
    SurfaceCoating = {
        category = "WearResist", nameKey = "IGUI_TWA_Proc_SurfaceCoating", icon = "Bleach",
        consumes = { { itemType = "Base.Bleach", qty = 1 } }, skill = "Blacksmith:2", time = 250, sound = "CraftFixWeapon",
    },

    -- ===== Assembly (การประกอบ) -- request 2026-09-27: real items whose
    -- own NAME describes a specific attached/constructed component (e.g.
    -- "BaseballBat_Nails", "Cudgel_Bone", "Plunger_BarbedWire") get the
    -- procedure matching THAT name instead of whatever the generic
    -- Sharpness/Piercing rule would otherwise assign -- see
    -- gen_craftdata.js's applyAssemblyOverrides() for the actual name-match
    -- rules. Every one of these is explicitly noskill, one real tool, one
    -- real material named after the procedure itself. =====
    WrapClothImprov = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_WrapClothImprov", icon = "Rag",
        consumes = { { itemType = "Base.RippedSheets", qty = 1 } }, time = 100, sound = "FixWithTape",
    },
    SawWood = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_SawWood", icon = "Plank",
        tool = { kind = "tag", value = "SAW" },
        time = 150, sound = "Sawing",
    },
    SmashBottle = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_SmashBottle", icon = "BeerBottle",
        time = 100, sound = "SmashStoneHit",
    },
    BreakBranch = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_BreakBranch", icon = "Branch",
        tool = { kind = "tag", value = "SHARP_KNIFE" },
        time = 100, sound = "CraftFixWeapon",
    },
    WrapBarbedWireAssembly = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_WrapBarbedWireAssembly", icon = "BarbedWire",
        tool = { kind = "type", value = "Base.Pliers" },
        consumes = { { itemType = "Base.BarbedWire", qty = 1 } }, time = 150, sound = "CraftFixWeapon",
    },
    WrapWireAssembly = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_WrapWireAssembly", icon = "Wire",
        tool = { kind = "type", value = "Base.Pliers" },
        consumes = { { itemType = "Base.Wire", qty = 1 } }, time = 150, sound = "CraftFixWeapon",
    },
    AssembleCan = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_AssembleCan", icon = "TinCanEmpty",
        tool = { kind = "tag", value = "SCREWDRIVER" },
        consumes = { { itemType = "Base.TinCanEmpty", qty = 1 } }, time = 150, sound = "Screwdriver",
    },
    AssembleNails = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_AssembleNails", icon = "Nails",
        tool = { kind = "tag", value = "HAMMER" },
        consumes = { { itemType = "Base.Nails", qty = 5 } }, time = 150, sound = "Hammering",
    },
    AssembleRailSpike = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_AssembleRailSpike", icon = "RailroadSpike",
        tool = { kind = "tag", value = "HAMMER" },
        consumes = { { itemType = "Base.RailroadSpike", qty = 1 } }, time = 200, sound = "Hammering",
    },
    AssembleBoneSpike = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_AssembleBoneSpike", icon = "Bone",
        tool = { kind = "tag", value = "SHARP_KNIFE" },
        consumes = { { itemType = "Base.AnimalBone", qty = 1 } }, time = 150, sound = "SmashBoneHit",
    },
    AssembleSawblade = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_AssembleSawblade", icon = "CircularSawBlade_Half",
        tool = { kind = "tag", value = "SAW" },
        consumes = { { itemType = "Base.CircularSawblade_Half", qty = 1 } }, time = 200, sound = "Sawing",
    },
    AssembleSheetMetal = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_AssembleSheetMetal", icon = "SheetMetal",
        tool = { kind = "tag", value = "SCREWDRIVER" },
        consumes = { { itemType = "Base.SheetMetal", qty = 1 } }, time = 150, sound = "Screwdriver",
    },
    AssembleSpike = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_AssembleSpike", icon = "ScrapMetal",
        tool = { kind = "tag", value = "HAMMER" },
        consumes = { { itemType = "Base.ScrapMetal", qty = 1 } }, time = 150, sound = "Hammering",
    },
    AssembleBrake = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_AssembleBrake", icon = "CarBrakes",
        tool = { kind = "tag", value = "WRENCH" },
        consumes = { { itemType = "Base.NormalBrake1", qty = 1 } }, time = 200, sound = "RepairWithWrench",
    },
    AssembleBucket = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_AssembleBucket", icon = "MetalBucket",
        tool = { kind = "tag", value = "HAMMER" },
        consumes = { { itemType = "Base.Bucket", qty = 1 } }, time = 200, sound = "Hammering",
    },
    AssembleKettle = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_AssembleKettle", icon = "Kettle",
        tool = { kind = "tag", value = "HAMMER" },
        consumes = { { itemType = "Base.Kettle", qty = 1 } }, time = 200, sound = "Hammering",
    },
    AssembleRakeHead = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_AssembleRakeHead", icon = "RakeHead",
        tool = { kind = "tag", value = "WRENCH" },
        consumes = { { itemType = "Base.RakeHead", qty = 1 } }, time = 200, sound = "RepairWithWrench",
    },
    AssembleSpadeHead = {
        category = "Assembly", nameKey = "IGUI_TWA_Proc_AssembleSpadeHead", icon = "ShovelHead_Forged",
        tool = { kind = "tag", value = "WRENCH" },
        consumes = { { itemType = "Base.SpadeHead", qty = 1 } }, time = 200, sound = "RepairWithWrench",
    },

    -- ===== Metallurgy (การถลุงโลหะ) -- request 2026-09-27: "กรรมวิธี
    -- พยายามใช้ vanilla ไปอ่านเงื่อนไขในสูตรคราฟ" -- a new raw-material
    -- refining chain (ore/scrap -> lump -> tiered bars), read straight from
    -- real vanilla B42 blacksmithing (recipes_blacksmith_bar.txt/
    -- _other_metals.txt). Real items grep-confirmed: Base.IronOre/
    -- CopperOre (raw ore), Base.IronChunk/SteelChunk/CopperScrap
    -- (part-refined), Base.Tongs, Base.CeramicCrucibleSmall/CeramicCrucible
    -- (real small/large ceramic crucibles). Skill levels are exactly as
    -- given and must not change; tools/materials for steps that didn't
    -- specify them are this mod's own judgment call, using only items/tags
    -- already established real elsewhere in this file. =====
    StartFire = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_StartFire", icon = "Matches",
        tool = { { kind = "type", value = "Base.Lighter" }, { kind = "type", value = "Base.Matches" } },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 1 } },
        time = 100, sound = "CraftFixWeapon",
    },
    -- "วัตถุดิบเป็นโลหะทุกประเภท โดยแต่ละประเภทก็มีจำนวนที่ใช้ต่างกัน" --
    -- a new `options` consume shape (one real real material picked from a
    -- list, each with its OWN quantity, not one shared qty across all
    -- alternatives like the existing itemTypes shape) -- see
    -- CheckEligibility/Consume/DescribeAll below for the matching logic.
    MeltMetal = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_MeltMetal", icon = "IronChunk",
        tool = { kind = "type", value = "Base.Tongs" },
        consumes = { { options = {
            { itemType = "Base.IronOre", qty = 4 },
            { itemType = "Base.CopperOre", qty = 4 },
            { itemType = "Base.IronChunk", qty = 2 },
            { itemType = "Base.SteelChunk", qty = 2 },
            { itemType = "Base.CopperScrap", qty = 3 },
        } } },
        time = 200, sound = "CraftFixWeapon",
    },
    PourMold = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_PourMold", icon = "Ceramic_Crucible_Fired",
        tool = { kind = "type", value = "Base.CeramicCrucibleSmall" },
        time = 150, sound = "CraftFixWeapon",
    },
    PourMoldLarge = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_PourMoldLarge", icon = "Ceramic_Crucible_Fired",
        tool = { kind = "type", value = "Base.CeramicCrucible" },
        time = 200, sound = "CraftFixWeapon",
    },
    CoolCast = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_CoolCast", icon = "BlacksmithTongs",
        tool = { kind = "type", value = "Base.Tongs" },
        skill = "Blacksmith:2", forgeTier = 1, time = 150, sound = "CraftFixWeapon",
    },
    QuenchHarden = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_QuenchHarden", icon = "BlacksmithTongs",
        tool = { kind = "type", value = "Base.Tongs" },
        skill = "Blacksmith:2", forgeTier = 1, time = 150, sound = "CraftFixWeapon",
    },
    WeldWork = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_WeldWork", icon = "BlowTorch",
        tool = { kind = "tag", value = "WELDING_MASK" }, tool2 = { kind = "type", value = "Base.BlowTorch" },
        consumes = { { itemType = "Base.ScrapMetal", qty = 1 } }, skill = "MetalWelding:1", time = 300, sound = "CraftWelding",
    },
    WeldWorkComplex = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_WeldWorkComplex", icon = "BlowTorch",
        tool = { kind = "tag", value = "WELDING_MASK" }, tool2 = { kind = "type", value = "Base.BlowTorch" },
        consumes = { { itemType = "Base.ScrapMetal", qty = 2 } }, skill = "MetalWelding:2", time = 400, sound = "CraftWelding",
    },
    PolishMetal = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_PolishMetal", icon = "Whetstone2",
        tool = { { kind = "type", value = "Base.Whetstone" }, { kind = "type", value = "Base.File" }, { kind = "type", value = "Base.SmallFileSet" } },
        skill = "Glassmaking:1", time = 200, sound = "CraftFixWeapon",
    },
    GrindMetal = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_GrindMetal", icon = "Whetstone2",
        tool = { { kind = "type", value = "Base.Whetstone" }, { kind = "type", value = "Base.File" }, { kind = "type", value = "Base.SmallFileSet" } },
        skill = "Glassmaking:2", time = 250, sound = "CraftFixWeapon",
    },
    EngravePattern = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_EngravePattern", icon = "Whetstone2",
        tool = { kind = "tag", value = "SHARP_KNIFE" },
        skill = "Carving:1", time = 200, sound = "CraftFixWeapon",
    },
    ForgeFold = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_ForgeFold", icon = "Ingot_Steel",
        tool = { { kind = "tag", value = "HAMMER" }, { kind = "tag", value = "SLEDGEHAMMER" }, { kind = "tag", value = "CLUB_HAMMER" } },
        tool2 = { kind = "type", value = "Base.Tongs" },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 2 } },
        skill = "Blacksmith:6", forgeTier = 2, time = 400, sound = "Hammering",
    },
    ForgeComplex = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_ForgeComplex", icon = "Ingot_Steel",
        tool = { { kind = "tag", value = "HAMMER" }, { kind = "tag", value = "SLEDGEHAMMER" }, { kind = "tag", value = "CLUB_HAMMER" } },
        tool2 = { kind = "type", value = "Base.Tongs" },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 3 } },
        skill = "Blacksmith:8", forgeTier = 3, time = 500, sound = "Hammering",
    },
    ForgeVacuum = {
        category = "Metallurgy", nameKey = "IGUI_TWA_Proc_ForgeVacuum", icon = "Ingot_Steel",
        tool = { { kind = "tag", value = "HAMMER" }, { kind = "tag", value = "SLEDGEHAMMER" }, { kind = "tag", value = "CLUB_HAMMER" } },
        tool2 = { kind = "type", value = "Base.Tongs" },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 4 } },
        skill = "Blacksmith:10", forgeTier = 3, time = 600, sound = "Hammering",
    },
}

-- 7 categories in display order, each with its own translated header and
-- the ordered list of procedure ids inside it -- both `Order` and the
-- right-panel grid grouping are derived from ONE list here so they can't
-- drift apart.
-- request 2026-09-27: "เอาหมวดหมู่ การประกอบ มาไว้บนสุด" -- Assembly moved
-- to the front of this list (display order only, no effect on the rules
-- engine). "อยากให้เจียระไน กับตีขึ้นรูปไปอยู่ในสร้างความแหลมด้วย" --
-- PrecisionGrind/ForgeShape now also appear under Piercing's own grid, not
-- just Sharpness -- they already show up here TWICE deliberately, matching
-- how gen_craftdata.js's own rules engine already treats them as SHARED
-- between the two categories (Rule A for Swinging, Rule B for Spear/Stab
-- both resolve to PrecisionGrind/ForgeShape at their top 2 crit bands) --
-- this just makes the right-panel UI grouping match that real behavior
-- instead of only showing them under Sharpness.
TWAProcedures.Categories = {
    { key = "Assembly", nameKey = "IGUI_TWA_ProcCat_Assembly", ids = {
        'WrapClothImprov', 'SawWood', 'SmashBottle', 'BreakBranch',
        'WrapBarbedWireAssembly', 'WrapWireAssembly', 'AssembleCan', 'AssembleNails',
        'AssembleRailSpike', 'AssembleBoneSpike', 'AssembleSawblade', 'AssembleSheetMetal',
        'AssembleSpike', 'AssembleBrake', 'AssembleBucket', 'AssembleKettle',
        'AssembleRakeHead', 'AssembleSpadeHead',
    } },
    { key = "Sharpness", nameKey = "IGUI_TWA_ProcCat_Sharpness", ids = { 'SharpenEdge', 'StropLeather', 'PrecisionGrind', 'ForgeShape' } },
    { key = "Piercing", nameKey = "IGUI_TWA_ProcCat_Piercing", ids = { 'KnapHead', 'TaperPoint', 'PrecisionGrind', 'ForgeShape' } },
    { key = "Handle", nameKey = "IGUI_TWA_ProcCat_Handle", ids = { 'MakeHandle', 'WrapBind', 'MakeLongHandle', 'ReinforcedBind', 'MakeRivetedHandle', 'TightenBolts' } },
    { key = "Balance", nameKey = "IGUI_TWA_ProcCat_Balance", ids = { 'HammerNails', 'CounterweightHead', 'WeldMetal' } },
    { key = "Structure", nameKey = "IGUI_TWA_ProcCat_Structure", ids = { 'RivetPlate', 'DrillCore' } },
    { key = "Toughness", nameKey = "IGUI_TWA_ProcCat_Toughness", ids = { 'WrapCloth', 'WrapLeather', 'StringSinew', 'WeaveWire' } },
    { key = "WearResist", nameKey = "IGUI_TWA_ProcCat_WearResist", ids = { 'CoatMud', 'FireTreat', 'CoatWax', 'SurfaceCoating' } },
    { key = "Metallurgy", nameKey = "IGUI_TWA_ProcCat_Metallurgy", ids = {
        'StartFire', 'MeltMetal', 'PourMold', 'PourMoldLarge', 'CoolCast', 'QuenchHarden',
        'WeldWork', 'WeldWorkComplex', 'PolishMetal', 'GrindMetal', 'EngravePattern',
        'ForgeFold', 'ForgeComplex', 'ForgeVacuum',
    } },
}

TWAProcedures.Order = {}
for _, cat in ipairs(TWAProcedures.Categories) do
    for _, id in ipairs(cat.ids) do
        TWAProcedures.Order[#TWAProcedures.Order + 1] = id
    end
end

-- request 2026-09-27: "เพิ่มเงื่อนไขในการทำกรรมวิธี ต้องมีแสงสว่าง เหมือนกับ
-- ตอนคราฟ มีหมายเหตุบอกด้วย" -- same real check vanilla's own crafting
-- window uses to grey out a recipe in the dark (ISWidgetTitleHeader.lua:
-- `self.player:tooDarkToRead()`), applied to every procedure with a "missing
-- light" note the same way a missing tool/item/skill already shows one.
function TWAProcedures.CheckEligibility(proc, player)
    local missing = {}

    if player:tooDarkToRead() then
        missing[#missing + 1] = { kind = "light" }
    end

    if proc.tool and not hasAnyTool(proc.tool, player) then
        missing[#missing + 1] = { kind = "tool", spec = proc.tool }
    end
    if proc.tool2 and not hasAnyTool(proc.tool2, player) then
        missing[#missing + 1] = { kind = "tool", spec = proc.tool2 }
    end

    local inv = player:getInventory()
    for _, c in ipairs(proc.consumes or {}) do
        if c.options then
            local met = false
            for _, opt in ipairs(c.options) do
                if inv:getItemCountRecurse(opt.itemType) >= opt.qty then met = true break end
            end
            if not met then
                missing[#missing + 1] = { kind = "consume_options", options = c.options }
            end
        else
            local types = altTypes(c)
            local have = countAny(inv, types)
            if have < c.qty then
                missing[#missing + 1] = { kind = "consume", itemType = types[1], itemTypes = types, qty = c.qty, have = have }
            end
        end
    end

    if proc.skill then
        local skillName, lvl = proc.skill:match("^(%a+):(%d+)$")
        lvl = tonumber(lvl)
        if skillName then
            local perk = Perks[skillName]
            if perk and player:getPerkLevel(perk) < lvl then
                missing[#missing + 1] = { kind = "skill", skill = skillName, level = lvl }
            end
        end
    end

    if proc.forgeTier and nearbyForgeTier(player) < proc.forgeTier then
        missing[#missing + 1] = { kind = "forge", tier = proc.forgeTier }
    end

    return #missing == 0, missing
end

function TWAProcedures.DescribeAll(proc, player)
    local reqs = {}
    reqs[#reqs + 1] = { kind = "light", met = not player:tooDarkToRead() }
    if proc.tool then
        reqs[#reqs + 1] = { kind = "tool", spec = proc.tool, met = hasAnyTool(proc.tool, player) }
    end
    if proc.tool2 then
        reqs[#reqs + 1] = { kind = "tool", spec = proc.tool2, met = hasAnyTool(proc.tool2, player) }
    end

    local inv = player:getInventory()
    for _, c in ipairs(proc.consumes or {}) do
        if c.options then
            local met = false
            for _, opt in ipairs(c.options) do
                if inv:getItemCountRecurse(opt.itemType) >= opt.qty then met = true break end
            end
            reqs[#reqs + 1] = { kind = "consume_options", options = c.options, met = met }
        else
            local types = altTypes(c)
            local have = countAny(inv, types)
            reqs[#reqs + 1] = { kind = "consume", itemType = types[1], itemTypes = types, qty = c.qty, have = have, met = have >= c.qty }
        end
    end

    if proc.skill then
        local skillName, lvl = proc.skill:match("^(%a+):(%d+)$")
        lvl = tonumber(lvl)
        if skillName then
            local perk = Perks[skillName]
            local have = perk and player:getPerkLevel(perk) or 0
            reqs[#reqs + 1] = { kind = "skill", skill = skillName, level = lvl, met = perk ~= nil and have >= lvl }
        end
    end

    if proc.forgeTier then
        reqs[#reqs + 1] = { kind = "forge", tier = proc.forgeTier, met = nearbyForgeTier(player) >= proc.forgeTier }
    end

    return reqs
end

-- request 2026-09-27: "หลอมโลหะ...แต่ละประเภทก็มีจำนวนที่ใช้ต่างกัน" -- a
-- consume slot shaped as `{ options = { {itemType, qty}, ... } }` needs
-- exactly ONE of those (type, qty) pairs, each with its OWN quantity
-- (unlike the existing `itemTypes` shape, which shares one qty across every
-- alternative). Consumes whichever real option the player actually has.
local function consumeOptions(inv, options)
    for _, opt in ipairs(options) do
        if inv:getItemCountRecurse(opt.itemType) >= opt.qty then
            for _ = 1, opt.qty do
                local it = inv:getFirstTypeEvalRecurse(opt.itemType, predicateNotBroken)
                    or inv:getFirstTypeEvalRecurse(opt.itemType, function() return true end)
                if it then inv:Remove(it) end
            end
            return
        end
    end
end

function TWAProcedures.Consume(proc, player)
    local inv = player:getInventory()
    for _, c in ipairs(proc.consumes or {}) do
        if c.options then
            consumeOptions(inv, c.options)
        else
            local types = altTypes(c)
            for _ = 1, c.qty do
                local it = nil
                for _, t in ipairs(types) do
                    it = inv:getFirstTypeEvalRecurse(t, predicateNotBroken)
                        or inv:getFirstTypeEvalRecurse(t, function() return true end)
                    if it then break end
                end
                if it then inv:Remove(it) end
            end
        end
    end
end

-- Balance pass 2026-09-27: "xp ที่ได้จะเฟ้อไหม ในการทำอาวุธ ปรับ balance ให้
-- หน่อย" -- checked the real numbers before picking a fix. At lvl*10, the
-- 248 real recipes averaged 47.9 total XP per finished weapon (up to 110 on
-- the worst offender, Make_browning_outdoorsman_axe's 12 procedures) versus
-- vanilla's own real single-craft xpAward range for weapons (grep-confirmed
-- from the actual recipe files: Woodwork 10-60, Maintenance 10-50,
-- MetalWelding a flat 25, FlintKnapping 10-70) -- our AVERAGE weapon was
-- already sitting mid-vanilla-range, but the WORST CASE (110) exceeded
-- vanilla's own highest observed award (70) by over 50%, because splitting
-- one craft into many small procedures pays XP once per step where vanilla
-- pays once per finished item. Halved the multiplier (lvl*10 -> lvl*5):
-- recomputed average drops to ~24 and the worst case to 55, comfortably
-- inside vanilla's real 10-70 band at both ends.
function TWAProcedures.AwardXP(proc, player)
    if not proc.skill then return end
    local skillName, lvl = proc.skill:match("^(%a+):(%d+)$")
    lvl = tonumber(lvl)
    local perk = skillName and Perks[skillName]
    if perk then
        player:getXp():AddXP(perk, lvl * 5)
    end
end

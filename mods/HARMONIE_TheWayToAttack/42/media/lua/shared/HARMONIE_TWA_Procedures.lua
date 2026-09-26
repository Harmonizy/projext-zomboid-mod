--============================================================================
-- HARMONIE_TheWayToAttack -- crafting procedure library (shared)
--
-- A "procedure" is a reusable crafting step: an optional TOOL (checked but not
-- consumed), a list of CONSUMED materials, an optional skill requirement, and
-- (2026-09-26) a real duration + sound so performing one is an actual timed
-- action with XP, not an instant click -- see TWA_PerformProcedureAction.lua.
-- A recipe (HARMONIE_TWA_RecipeData.lua) names a set of these; the crafting
-- UI (HARMONIE_TWA_CraftUI.lua) shows the full library on its right panel and
-- only lets the player perform a step once its own tool/material/skill
-- requirements are actually met.
--
-- *** Every Java-side API call below is grep-confirmed real from actual
-- vanilla Lua usage (not guessed) -- this matters because a wrong method name
-- here would crash Lua load/execution, unlike a missing icon/sound which just
-- logs a warning. Tool tags used here (HAMMER/SAW/WRENCH/WELDING_MASK/
-- SCREWDRIVER/CLUB_HAMMER/SLEDGEHAMMER/STONE_MAUL/PIPE_WRENCH) are all
-- confirmed real `ItemTag.X` members from vanilla's own Lua (grepped the full
-- media/lua tree) -- e.g. `ISPickAxeGroundCoverItem.lua`'s own real "any
-- hammering tool" check is `hasTag(HAMMER) or hasTag(SLEDGEHAMMER) or
-- hasTag(CLUB_HAMMER) or hasTag(STONE_MAUL)`, which is exactly the group
-- KnapStone below reuses. There is NO confirmed ItemTag for tongs/whetstone/
-- pliers/hammerstone/file/drill, so those use a concrete real item type
-- instead (Base.Tongs/Base.Whetstone/Base.Pliers/Base.HammerStone/Base.File/
-- Base.HandDrill) via getFirstTypeEvalRecurse, confirmed real for arbitrary
-- types. tags[base:x] from item/recipe SCRIPTS (a different, broader tag
-- namespace than the Lua ItemTag enum) has no confirmed generic Lua-side
-- query API, so it is not used here at all. Sound event names are all
-- grep-confirmed real from media/scripts/generated/sounds/player/*.txt. ***
--============================================================================

TWAProcedures = TWAProcedures or {}

local function predicateNotBroken(item)
    return not item:isBroken()
end

-- tool/tool2 = a single spec `{ kind = "tag"|"type", value = X }`, OR a LIST
-- of alternative specs `{ {kind=.., value=..}, {kind=.., value=..} }` meaning
-- "any one of these" (request 2026-09-26: "some procedures can use several
-- different tools -- make it flexible"). `toolAlts()` normalizes either form
-- to a plain array of specs.
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

-- A consume slot is either a single real type (`itemType = "Base.X"`) or a
-- list of interchangeable real types (`itemTypes = {"Base.A", "Base.B"}`) --
-- vanilla itself treats several concrete items as interchangeable for a lot
-- of these (e.g. Base.Charcoal/CharcoalCrafted/Coke all carry the same real
-- `Tags = base:charcoal`, SteelIngot/IronIngot/CopperIngot/BrassIngot all
-- carry `base:ingot`, and a spearhead can be lashed on with LeatherStrips/
-- Zipties/Twine OR taped on with DuctTape -- grep-confirmed from vanilla's
-- own BindSpear/DuctTapeSpear recipes) -- bug report 2026-09-26: only
-- accepting ONE of them was needlessly inflexible. `altTypes(c)` normalizes
-- either form to a plain array.
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

TWAProcedures.List = {
    -- Woodwork -----------------------------------------------------------------
    -- Any heavy hammering tool works for driving nails, not just a claw
    -- hammer (request 2026-09-26: "some procedures still aren't flexible").
    HammerNails = {
        nameKey = "IGUI_TWA_Proc_HammerNails", icon = "Nails",
        tool = { { kind = "tag", value = "HAMMER" }, { kind = "tag", value = "SLEDGEHAMMER" }, { kind = "tag", value = "CLUB_HAMMER" } },
        consumes = { { itemType = "Base.Nails", qty = 5 } },
        skill = "Woodwork:1", time = 150, sound = "Hammering",
    },
    HardenWood = {
        nameKey = "IGUI_TWA_Proc_HardenWood", icon = "LongHandle",
        consumes = {},
        skill = "Woodwork:1", time = 200, sound = "CraftFixWeapon",
    },
    CutShape = {
        -- icon: Base.Saw's own real Icon field is "Hacksaw" -- "HandSaw" was
        -- never a real icon name anywhere in vanilla, which is why this
        -- rendered as a blank grey square (bug report 2026-09-26).
        nameKey = "IGUI_TWA_Proc_CutShape", icon = "Hacksaw",
        tool = { kind = "tag", value = "SAW" },
        consumes = {},
        skill = "Woodwork:1", time = 150, sound = "Sawing",
    },
    SharpenEdge = {
        -- icon: Base.Whetstone's real Icon field is "Whetstone2", not the
        -- item's own type name "Whetstone" (same class of bug as CutShape).
        -- Tool accepts a File/SmallFileSet as an alternative to a whetstone
        -- (request 2026-09-26: "add a filing/polishing procedure" -- filing
        -- and whetstone-sharpening both do the same "finish the edge" job,
        -- so this is one flexible procedure rather than two separate ones).
        nameKey = "IGUI_TWA_Proc_SharpenEdge", icon = "Whetstone2",
        tool = {
            { kind = "type", value = "Base.Whetstone" },
            { kind = "type", value = "Base.File" },
            { kind = "type", value = "Base.SmallFileSet" },
        },
        consumes = {},
        skill = "Woodwork:1", time = 100, sound = "SharpenBladeWhetstone",
    },
    WrapGrip = {
        nameKey = "IGUI_TWA_Proc_WrapGrip", icon = "LeatherStrips",
        consumes = { { itemType = "Base.LeatherStrips", qty = 2 } },
        skill = "Woodwork:1", time = 150, sound = "CraftFixWeapon",
    },
    -- Same real material alternatives as AttachSpearhead (request 2026-09-26:
    -- "some procedures still aren't flexible" -- this is the exact same
    -- lashing/binding action, so it should accept the same alternatives).
    BindLashing = {
        nameKey = "IGUI_TWA_Proc_BindLashing", icon = "LeatherStrips",
        consumes = { { itemTypes = { "Base.LeatherStrips", "Base.Zipties", "Base.Twine", "Base.DuctTape" }, qty = 2 } },
        skill = "Woodwork:1", time = 150, sound = "CraftFixWeapon",
    },
    -- Replaces the entire old auto-generated `Attach_<Name>` procedure set
    -- (one hand-generated procedure per distinct spear-combo item -- 15 of
    -- them) -- request 2026-09-26: a spear-with-a-head recipe now requires
    -- TWO base items (the shaft AND the head component, see `base`/`base2`
    -- in HARMONIE_TWA_RecipeData.lua) instead of consuming the head through
    -- its own dedicated procedure, so only ONE simple lash-it-on step is
    -- left. Materials mirror vanilla's own real BindSpear (LeatherStrips/
    -- Zipties/Twine) AND DuctTapeSpear (DuctTape) recipes as flexible
    -- alternatives of the SAME procedure, since vanilla itself treats them
    -- as two equally-valid ways to finish the exact same spear.
    AttachSpearhead = {
        nameKey = "IGUI_TWA_Proc_AttachSpearhead", icon = "Shaft",
        consumes = { { itemTypes = { "Base.LeatherStrips", "Base.Zipties", "Base.Twine", "Base.DuctTape" }, qty = 2 } },
        skill = "Woodwork:1", time = 250, sound = "CraftWeaponSpearWood",
    },
    -- New procedures (request 2026-09-26: "add wrap-tape, drill-hole,
    -- weld (mask + torch), file, etc -- some tools weren't used at all").
    WrapTape = {
        nameKey = "IGUI_TWA_Proc_WrapTape", icon = "DuctTape",
        consumes = { { itemType = "Base.DuctTape", qty = 2 } },
        skill = "Woodwork:1", time = 100, sound = "FixWithTape",
    },
    DrillHole = {
        -- No confirmed ItemTag for a generic "drill" -- Base.HandDrill is
        -- vanilla's own real drill tool (real recipes reference
        -- `tags[base:drillmetal]`, a script-tag with no Lua query API, kept
        -- mode -- HandDrill is the concrete real item that tag sits on).
        nameKey = "IGUI_TWA_Proc_DrillHole", icon = "Drill_OldFashioned",
        tool = { kind = "type", value = "Base.HandDrill" },
        consumes = {},
        skill = "Woodwork:2", time = 150, sound = "CraftFixWeapon",
    },
    AttachHardware = {
        nameKey = "IGUI_TWA_Proc_AttachHardware", icon = "NutsBolts",
        tool = { { kind = "tag", value = "WRENCH" }, { kind = "tag", value = "PIPE_WRENCH" } },
        consumes = { { itemType = "Base.NutsBolts", qty = 2 } },
        skill = "Woodwork:1", time = 150, sound = "RepairWithWrench",
    },
    AttachScrews = {
        nameKey = "IGUI_TWA_Proc_AttachScrews", icon = "Screws",
        tool = { { kind = "tag", value = "WRENCH" }, { kind = "tag", value = "PIPE_WRENCH" } },
        consumes = { { itemType = "Base.Screws", qty = 4 } },
        skill = "Woodwork:2", time = 150, sound = "Screwdriver",
    },
    WrapWire = {
        nameKey = "IGUI_TWA_Proc_WrapWire", icon = "Wire",
        tool = { kind = "type", value = "Base.Pliers" },
        consumes = { { itemType = "Base.Wire", qty = 2 } },
        skill = "Woodwork:2", time = 150, sound = "CraftFixWeapon",
    },
    WrapBarbedWire = {
        nameKey = "IGUI_TWA_Proc_WrapBarbedWire", icon = "BarbedWire",
        tool = { kind = "type", value = "Base.Pliers" },
        consumes = { { itemType = "Base.BarbedWire", qty = 1 } },
        skill = "Woodwork:2", time = 150, sound = "CraftFixWeapon",
    },
    Disassemble = {
        nameKey = "IGUI_TWA_Proc_Disassemble", icon = "Screwdriver",
        tool = { kind = "tag", value = "SCREWDRIVER" },
        consumes = {},
        skill = "Woodwork:1", time = 100, sound = "Screwdriver",
    },
    AttachHandleSmall = {
        -- icon: Base.SmallHandle's real Icon field is "Handle" (its own type
        -- name is not the icon name -- same bug class as CutShape/Sharpen).
        nameKey = "IGUI_TWA_Proc_AttachHandleSmall", icon = "Handle",
        consumes = { { itemType = "Base.SmallHandle", qty = 1 } },
        skill = "Woodwork:1", time = 150, sound = "Hammering",
    },
    AttachHandleLong = {
        nameKey = "IGUI_TWA_Proc_AttachHandleLong", icon = "LongHandle",
        consumes = { { itemType = "Base.LongHandle", qty = 1 } },
        skill = "Woodwork:1", time = 150, sound = "Hammering",
    },
    AttachHaft = {
        -- icon: Base.LongStick's real Icon field is "Shaft".
        nameKey = "IGUI_TWA_Proc_AttachHaft", icon = "Shaft",
        consumes = { { itemType = "Base.LongStick", qty = 1 } },
        skill = "Woodwork:1", time = 150, sound = "CraftWeaponSpearWood",
    },

    -- Blacksmith -----------------------------------------------------------------
    -- Replaces the old ForgeBilletSmall/ForgeBilletMedium pair: those consumed
    -- a SteelBar and produced an intermediate category blank (TWA_Blank_*).
    -- Blanks are gone (request 2026-09-26 -- every recipe now consumes a
    -- single universal Base.SteelIngot "Metal Ingot" as its own base item
    -- instead), so this is just the initial hammer-and-tongs shaping step
    -- every ingot-based recipe starts with.
    ForgeShape = {
        nameKey = "IGUI_TWA_Proc_ForgeShape", icon = "Ingot_Steel",
        tool = { kind = "tag", value = "HAMMER" },
        tool2 = { kind = "type", value = "Base.Tongs" },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 2 } },
        skill = "Blacksmith:2", time = 400, sound = "Hammering",
    },
    PolishI = {
        nameKey = "IGUI_TWA_Proc_PolishI", icon = "Whetstone2",
        tool = {
            { kind = "type", value = "Base.Whetstone" },
            { kind = "type", value = "Base.File" },
            { kind = "type", value = "Base.SmallFileSet" },
        },
        consumes = {},
        skill = "Blacksmith:1", time = 150, sound = "SharpenBladeWhetstone",
    },
    TemperII = {
        nameKey = "IGUI_TWA_Proc_TemperII", icon = "Charcoal",
        tool = { kind = "type", value = "Base.Tongs" },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 3 } },
        skill = "Blacksmith:5", time = 300, sound = "CraftFixWeapon",
    },
    ReinforceIII = {
        nameKey = "IGUI_TWA_Proc_ReinforceIII", icon = "ScrapMetal",
        tool = { kind = "tag", value = "HAMMER" },
        tool2 = { kind = "type", value = "Base.Tongs" },
        consumes = { { itemType = "Base.ScrapMetal", qty = 3 }, { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 5 } },
        skill = "Blacksmith:8", time = 500, sound = "Hammering",
    },

    -- MetalWelding -----------------------------------------------------------------
    -- *** REAL BUG FIXED (2026-09-26): Base.BlowTorch is a real `base:
    -- drainable` item with `KeepOnDeplete = true` -- a rechargeable TOOL, not
    -- a single-use consumable. It was wrongly in `consumes` (destroying 2
    -- whole blowtorches per weld); it's a kept tool2 now, alongside the
    -- welding mask tool, matching the request "weld (mask + torch)" exactly.
    -- ***
    Weld = {
        nameKey = "IGUI_TWA_Proc_Weld", icon = "BlowTorch",
        tool = { kind = "tag", value = "WELDING_MASK" },
        tool2 = { kind = "type", value = "Base.BlowTorch" },
        consumes = { { itemType = "Base.ScrapMetal", qty = 1 } },
        skill = "MetalWelding:2", time = 400, sound = "CraftWelding",
    },
    BoltAssembly = {
        nameKey = "IGUI_TWA_Proc_BoltAssembly", icon = "NutsBolts",
        tool = { { kind = "tag", value = "WRENCH" }, { kind = "tag", value = "PIPE_WRENCH" } },
        consumes = { { itemType = "Base.NutsBolts", qty = 2 } },
        skill = "MetalWelding:1", time = 150, sound = "RepairWithWrench",
    },

    -- FlintKnapping -----------------------------------------------------------------
    -- Tool group matches vanilla's own real "any hammering tool" check 1:1
    -- (`ISPickAxeGroundCoverItem.lua`: hasTag(HAMMER) or hasTag(SLEDGEHAMMER)
    -- or hasTag(CLUB_HAMMER) or hasTag(PICK_AXE) or hasTag(STONE_MAUL)) --
    -- knapping stone is "hit rock with a heavy tool", not blacksmithing, so
    -- it isn't limited to Base.HammerStone specifically any more (request
    -- 2026-09-26: flexible tools).
    KnapStone = {
        -- icon: Base.SharpedStone's real Icon field is "RockSharpened".
        nameKey = "IGUI_TWA_Proc_KnapStone", icon = "RockSharpened",
        tool = {
            { kind = "type", value = "Base.HammerStone" },
            { kind = "tag", value = "HAMMER" },
            { kind = "tag", value = "SLEDGEHAMMER" },
            { kind = "tag", value = "CLUB_HAMMER" },
            { kind = "tag", value = "STONE_MAUL" },
            { kind = "tag", value = "PICK_AXE" },
        },
        consumes = { { itemType = "Base.SharpedStone", qty = 1 } },
        skill = "FlintKnapping:1", time = 200, sound = "SmashStoneHit",
    },
    -- Woodwork (carving) -- CarveBone replaces ForgeShape for bone-based
    -- vanilla weapons (bug report 2026-09-26: forging bone with a hammer,
    -- tongs and Metal Ingot the same way as a steel weapon made no sense --
    -- bone is carved, not smithed).
    -- A sharp knife works as well as a saw for carving bone (request
    -- 2026-09-26: flexible tools) -- ItemTag.SHARP_KNIFE confirmed real from
    -- ISMoveableDefinitions.lua's own real usage.
    CarveBone = {
        nameKey = "IGUI_TWA_Proc_CarveBone", icon = "Bone",
        tool = { { kind = "tag", value = "SAW" }, { kind = "tag", value = "SHARP_KNIFE" } },
        consumes = {},
        skill = "Woodwork:1", time = 200, sound = "SmashBoneHit",
    },

    -- Attach-a-salvaged-part procedures -- one real step each, mirroring
    -- vanilla's OWN "improvised weapon" crafting system 1:1 (real materials
    -- and skill levels grep-confirmed from
    -- media/scripts/generated/recipes/recipes_improvised_weapons.txt), used
    -- for vanilla weapon variants that are really "take a plain base object
    -- and bolt/nail/weld a scavenged part onto it" rather than a whole
    -- weapon forged from a Metal Ingot (bug report 2026-09-26: e.g. a
    -- circular-sawblade axe or a rake-head club was wrongly getting the same
    -- ForgeShape-from-ingot treatment as a real forged weapon).
    AttachSawblade = {
        nameKey = "IGUI_TWA_Proc_AttachSawblade", icon = "CircularSawBlade_Half",
        tool = { kind = "tag", value = "SAW" },
        consumes = { { itemType = "Base.CircularSawblade_Half", qty = 1 } },
        skill = "Woodwork:5", time = 300, sound = "Sawing",
    },
    AttachRakeHead = {
        nameKey = "IGUI_TWA_Proc_AttachRakeHead", icon = "RakeHead",
        tool = { { kind = "tag", value = "WRENCH" }, { kind = "tag", value = "PIPE_WRENCH" } },
        consumes = { { itemType = "Base.RakeHead", qty = 1 } },
        skill = "Woodwork:4", time = 250, sound = "RepairWithWrench",
    },
    AttachGardenForkHead = {
        nameKey = "IGUI_TWA_Proc_AttachGardenForkHead", icon = "Pitchfork_Broken_Head",
        tool = { { kind = "tag", value = "WRENCH" }, { kind = "tag", value = "PIPE_WRENCH" } },
        consumes = { { itemTypes = { "Base.GardenForkHead", "Base.GardenForkHead_Forged" }, qty = 1 } },
        skill = "Woodwork:6", time = 300, sound = "RepairWithWrench",
    },
    AttachSpadeHead = {
        nameKey = "IGUI_TWA_Proc_AttachSpadeHead", icon = "ShovelHead_Forged",
        tool = { { kind = "tag", value = "WRENCH" }, { kind = "tag", value = "PIPE_WRENCH" } },
        consumes = { { itemTypes = { "Base.SpadeHead", "Base.SpadeHead_Forged" }, qty = 1 } },
        skill = "Woodwork:6", time = 300, sound = "RepairWithWrench",
    },
    AttachRailspike = {
        nameKey = "IGUI_TWA_Proc_AttachRailspike", icon = "RailroadSpike",
        tool = { kind = "tag", value = "HAMMER" },
        consumes = { { itemType = "Base.RailroadSpike", qty = 1 } },
        skill = "Woodwork:3", time = 200, sound = "Hammering",
    },
    AttachCan = {
        nameKey = "IGUI_TWA_Proc_AttachCan", icon = "TinCanEmpty",
        tool = { kind = "tag", value = "SCREWDRIVER" },
        consumes = { { itemTypes = { "Base.TinCanEmpty", "Base.WaterRationCanEmpty" }, qty = 1 } },
        skill = "Woodwork:1", time = 150, sound = "Screwdriver",
    },
    AttachScrapSheet = {
        nameKey = "IGUI_TWA_Proc_AttachScrapSheet", icon = "MetalSheetSmall",
        tool = { kind = "tag", value = "SCREWDRIVER" },
        consumes = { { itemTypes = { "Base.SmallSheetMetal", "Base.UnusableMetal", "Base.AluminumScrap" }, qty = 2 } },
        skill = "Woodwork:4", time = 250, sound = "Screwdriver",
    },
    AttachBrake = {
        nameKey = "IGUI_TWA_Proc_AttachBrake", icon = "CarBrakes",
        tool = { { kind = "tag", value = "WRENCH" }, { kind = "tag", value = "PIPE_WRENCH" } },
        consumes = { { itemTypes = {
            "Base.NormalBrake1", "Base.NormalBrake2", "Base.NormalBrake3",
            "Base.OldBrake1", "Base.OldBrake2", "Base.OldBrake3",
            "Base.ModernBrake1", "Base.ModernBrake2", "Base.ModernBrake3",
        }, qty = 1 } },
        skill = "Woodwork:5", time = 300, sound = "RepairWithWrench",
    },
}

-- Stable display order (pairs() over TWAProcedures.List has no guaranteed
-- order, so the UI's procedure-library grid iterates this instead). Sorted
-- alphabetically by procedure id purely for maintainability here -- the UI's
-- own alphabetical sort (request 2026-09-26) is applied to RECIPE names, a
-- separate, generated list.
TWAProcedures.Order = {
    'HammerNails', 'HardenWood', 'CutShape', 'SharpenEdge', 'WrapGrip', 'BindLashing',
    'AttachSpearhead', 'WrapTape', 'DrillHole',
    'AttachHardware', 'AttachScrews', 'WrapWire', 'WrapBarbedWire', 'Disassemble',
    'AttachHandleSmall', 'AttachHandleLong', 'AttachHaft',
    'ForgeShape', 'PolishI', 'TemperII', 'ReinforceIII',
    'Weld', 'BoltAssembly', 'KnapStone', 'CarveBone',
    'AttachSawblade', 'AttachRakeHead', 'AttachGardenForkHead', 'AttachSpadeHead',
    'AttachRailspike', 'AttachCan', 'AttachScrapSheet', 'AttachBrake',
}

-- Live eligibility check against a player's current inventory/skills.
-- Returns (metAll: bool, missing: array of {kind, ...} describing every unmet requirement).
function TWAProcedures.CheckEligibility(proc, player)
    local missing = {}

    if proc.tool and not hasAnyTool(proc.tool, player) then
        missing[#missing + 1] = { kind = "tool", spec = proc.tool }
    end
    if proc.tool2 and not hasAnyTool(proc.tool2, player) then
        missing[#missing + 1] = { kind = "tool", spec = proc.tool2 }
    end

    local inv = player:getInventory()
    for _, c in ipairs(proc.consumes or {}) do
        local types = altTypes(c)
        local have = countAny(inv, types)
        if have < c.qty then
            missing[#missing + 1] = { kind = "consume", itemType = types[1], itemTypes = types, qty = c.qty, have = have }
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

    return #missing == 0, missing
end

-- Like CheckEligibility, but returns EVERY requirement (not just the unmet
-- ones), each tagged with its own `met` flag -- used by the crafting UI's
-- procedure-details box so the tool/materials/skill breakdown stays fully
-- visible and legible even once every condition is met, colored per-
-- condition instead of collapsing to a single all-or-nothing message (bug
-- report 2026-09-26: "when a procedure becomes ready, the requirement
-- details disappear -- keep them, just in a normal color instead of red per
-- condition that's actually satisfied").
function TWAProcedures.DescribeAll(proc, player)
    local reqs = {}
    if proc.tool then
        reqs[#reqs + 1] = { kind = "tool", spec = proc.tool, met = hasAnyTool(proc.tool, player) }
    end
    if proc.tool2 then
        reqs[#reqs + 1] = { kind = "tool", spec = proc.tool2, met = hasAnyTool(proc.tool2, player) }
    end

    local inv = player:getInventory()
    for _, c in ipairs(proc.consumes or {}) do
        local types = altTypes(c)
        local have = countAny(inv, types)
        reqs[#reqs + 1] = { kind = "consume", itemType = types[1], itemTypes = types, qty = c.qty, have = have, met = have >= c.qty }
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

    return reqs
end

-- Consumes the procedure's materials from the player's inventory. Assumes
-- CheckEligibility already confirmed everything is present. When a slot has
-- multiple interchangeable types, each unit is pulled from whichever
-- alternative actually has stock (tried in list order).
function TWAProcedures.Consume(proc, player)
    local inv = player:getInventory()
    for _, c in ipairs(proc.consumes or {}) do
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

-- Grants the procedure's skill XP on completion (request 2026-09-26: "give
-- XP like vanilla crafting does"). Real vanilla crafting XP scales roughly
-- with the recipe's own required skill level in every example grep-checked
-- this session (e.g. `xpAward = Blacksmith:50`/`MetalWelding:80` for
-- advanced recipes vs `xpAward = Woodwork:20` for simple ones) -- level*10
-- reuses that same ballpark without hand-tuning all 30+ procedures
-- individually. Real API: `character:getXp():AddXP(perk, amount)`, confirmed
-- from ISPlayerStatsUI.lua's own real usage.
function TWAProcedures.AwardXP(proc, player)
    if not proc.skill then return end
    local skillName, lvl = proc.skill:match("^(%a+):(%d+)$")
    lvl = tonumber(lvl)
    local perk = skillName and Perks[skillName]
    if perk then
        player:getXp():AddXP(perk, lvl * 10)
    end
end

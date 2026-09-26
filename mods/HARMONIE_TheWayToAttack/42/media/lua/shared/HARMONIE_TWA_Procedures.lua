--============================================================================
-- HARMONIE_TheWayToAttack -- crafting procedure library (shared)
--
-- A "procedure" is a reusable crafting step: an optional TOOL (checked but not
-- consumed), a list of CONSUMED materials, and an optional skill requirement.
-- A recipe (HARMONIE_TWA_RecipeData.lua) names a set of these; the crafting
-- UI (HARMONIE_TWA_CraftUI.lua) shows the full library on its right panel and
-- only lets the player perform a step once its own tool/material/skill
-- requirements are actually met.
--
-- *** Every Java-side API call below is grep-confirmed real from actual
-- vanilla Lua usage (not guessed) -- this matters because a wrong method name
-- here would crash Lua load/execution, unlike a missing icon/sound which just
-- logs a warning. Specifically: ItemTag.HAMMER/SAW/WRENCH/WELDING_MASK/
-- SCREWDRIVER are the only tool-relevant ItemTag enum members confirmed to
-- exist anywhere in vanilla's own Lua code (grepped the full
-- media/lua tree for every real `ItemTag.X` reference) -- there is NO
-- confirmed ItemTag for tongs/whetstone/pliers/hammerstone, so those use a
-- concrete real item type instead (Base.Tongs/Base.Whetstone/Base.Pliers/
-- Base.HammerStone) via containsTypeRecurse/getFirstTypeEvalRecurse, which
-- are confirmed real for arbitrary types. tags[base:x] from item/recipe
-- SCRIPTS (a different, broader tag namespace than the Lua ItemTag enum) has
-- no confirmed generic Lua-side query API, so it is not used here at all. ***
--============================================================================

TWAProcedures = TWAProcedures or {}

local function predicateNotBroken(item)
    return not item:isBroken()
end

-- tool = { kind = "tag", value = ItemTag.X } or { kind = "type", value = "Base.X" }
-- consumes = { { itemType = "Base.X", qty = N }, ... } for a single real type,
-- or { { itemTypes = {"Base.A", "Base.B"}, qty = N }, ... } when vanilla
-- itself treats several concrete items as interchangeable (see altTypes()
-- below CheckEligibility/Consume).
TWAProcedures.List = {
    -- Woodwork -----------------------------------------------------------------
    HammerNails = {
        nameKey = "IGUI_TWA_Proc_HammerNails", icon = "Nails",
        tool = { kind = "tag", value = "HAMMER" },
        consumes = { { itemType = "Base.Nails", qty = 5 } },
        skill = "Woodwork:1",
    },
    HardenWood = {
        nameKey = "IGUI_TWA_Proc_HardenWood", icon = "LongHandle",
        consumes = {},
        skill = "Woodwork:1",
    },
    CutShape = {
        -- icon: Base.Saw's own real Icon field is "Hacksaw" -- "HandSaw" was
        -- never a real icon name anywhere in vanilla, which is why this
        -- rendered as a blank grey square (bug report 2026-09-26).
        nameKey = "IGUI_TWA_Proc_CutShape", icon = "Hacksaw",
        tool = { kind = "tag", value = "SAW" },
        consumes = {},
        skill = "Woodwork:1",
    },
    SharpenEdge = {
        -- icon: Base.Whetstone's real Icon field is "Whetstone2", not the
        -- item's own type name "Whetstone" (same class of bug as CutShape).
        nameKey = "IGUI_TWA_Proc_SharpenEdge", icon = "Whetstone2",
        tool = { kind = "type", value = "Base.Whetstone" },
        consumes = {},
        skill = "Woodwork:1",
    },
    WrapGrip = {
        nameKey = "IGUI_TWA_Proc_WrapGrip", icon = "LeatherStrips",
        consumes = { { itemType = "Base.LeatherStrips", qty = 2 } },
        skill = "Woodwork:1",
    },
    BindLashing = {
        nameKey = "IGUI_TWA_Proc_BindLashing", icon = "LeatherStrips",
        consumes = { { itemType = "Base.LeatherStrips", qty = 2 } },
        skill = "Woodwork:1",
    },
    AttachHardware = {
        nameKey = "IGUI_TWA_Proc_AttachHardware", icon = "NutsBolts",
        tool = { kind = "tag", value = "WRENCH" },
        consumes = { { itemType = "Base.NutsBolts", qty = 2 } },
        skill = "Woodwork:1",
    },
    AttachScrews = {
        nameKey = "IGUI_TWA_Proc_AttachScrews", icon = "Screws",
        tool = { kind = "tag", value = "WRENCH" },
        consumes = { { itemType = "Base.Screws", qty = 4 } },
        skill = "Woodwork:2",
    },
    WrapWire = {
        nameKey = "IGUI_TWA_Proc_WrapWire", icon = "Wire",
        tool = { kind = "type", value = "Base.Pliers" },
        consumes = { { itemType = "Base.Wire", qty = 2 } },
        skill = "Woodwork:2",
    },
    WrapBarbedWire = {
        nameKey = "IGUI_TWA_Proc_WrapBarbedWire", icon = "BarbedWire",
        tool = { kind = "type", value = "Base.Pliers" },
        consumes = { { itemType = "Base.BarbedWire", qty = 1 } },
        skill = "Woodwork:2",
    },
    Disassemble = {
        nameKey = "IGUI_TWA_Proc_Disassemble", icon = "Screwdriver",
        tool = { kind = "tag", value = "SCREWDRIVER" },
        consumes = {},
        skill = "Woodwork:1",
    },
    AttachHandleSmall = {
        -- icon: Base.SmallHandle's real Icon field is "Handle" (its own type
        -- name is not the icon name -- same bug class as CutShape/Sharpen).
        nameKey = "IGUI_TWA_Proc_AttachHandleSmall", icon = "Handle",
        consumes = { { itemType = "Base.SmallHandle", qty = 1 } },
        skill = "Woodwork:1",
    },
    AttachHandleLong = {
        nameKey = "IGUI_TWA_Proc_AttachHandleLong", icon = "LongHandle",
        consumes = { { itemType = "Base.LongHandle", qty = 1 } },
        skill = "Woodwork:1",
    },
    AttachHaft = {
        -- icon: Base.LongStick's real Icon field is "Shaft".
        nameKey = "IGUI_TWA_Proc_AttachHaft", icon = "Shaft",
        consumes = { { itemType = "Base.LongStick", qty = 1 } },
        skill = "Woodwork:1",
    },

    -- Blacksmith -----------------------------------------------------------------
    -- Replaces the old ForgeBilletSmall/ForgeBilletMedium pair: those consumed
    -- a SteelBar and produced an intermediate category blank (TWA_Blank_*).
    -- Blanks are gone (request 2026-09-26 -- every recipe now consumes a
    -- single universal Base.SteelIngot "Metal Ingot" as its own base item
    -- instead), so this is just the initial hammer-and-tongs shaping step
    -- every ingot-based recipe starts with.
    -- Charcoal itself is one of 3 real interchangeable fuel items (Base.
    -- Charcoal/CharcoalCrafted/Coke all carry vanilla's own `Tags =
    -- base:charcoal`) -- bug report 2026-09-26: only accepting one of them
    -- was needlessly inflexible.
    ForgeShape = {
        nameKey = "IGUI_TWA_Proc_ForgeShape", icon = "Ingot_Steel",
        tool = { kind = "tag", value = "HAMMER" },
        tool2 = { kind = "type", value = "Base.Tongs" },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 2 } },
        skill = "Blacksmith:2",
    },
    PolishI = {
        nameKey = "IGUI_TWA_Proc_PolishI", icon = "Whetstone2",
        tool = { kind = "type", value = "Base.Whetstone" },
        consumes = {},
        skill = "Blacksmith:1",
    },
    TemperII = {
        nameKey = "IGUI_TWA_Proc_TemperII", icon = "Charcoal",
        tool = { kind = "type", value = "Base.Tongs" },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 3 } },
        skill = "Blacksmith:5",
    },
    ReinforceIII = {
        nameKey = "IGUI_TWA_Proc_ReinforceIII", icon = "ScrapMetal",
        tool = { kind = "tag", value = "HAMMER" },
        tool2 = { kind = "type", value = "Base.Tongs" },
        consumes = { { itemType = "Base.ScrapMetal", qty = 3 }, { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 5 } },
        skill = "Blacksmith:8",
    },

    -- MetalWelding -----------------------------------------------------------------
    Weld = {
        nameKey = "IGUI_TWA_Proc_Weld", icon = "BlowTorch",
        tool = { kind = "tag", value = "WELDING_MASK" },
        consumes = { { itemType = "Base.BlowTorch", qty = 2 }, { itemType = "Base.ScrapMetal", qty = 1 } },
        skill = "MetalWelding:2",
    },
    BoltAssembly = {
        nameKey = "IGUI_TWA_Proc_BoltAssembly", icon = "NutsBolts",
        tool = { kind = "tag", value = "WRENCH" },
        consumes = { { itemType = "Base.NutsBolts", qty = 2 } },
        skill = "MetalWelding:1",
    },

    -- FlintKnapping -----------------------------------------------------------------
    KnapStone = {
        -- icon: Base.SharpedStone's real Icon field is "RockSharpened".
        nameKey = "IGUI_TWA_Proc_KnapStone", icon = "RockSharpened",
        tool = { kind = "type", value = "Base.HammerStone" },
        consumes = { { itemType = "Base.SharpedStone", qty = 1 } },
        skill = "FlintKnapping:1",
    },
    -- Woodwork (carving) -- CarveBone replaces ForgeShape for bone-based
    -- vanilla weapons (bug report 2026-09-26: forging bone with a hammer,
    -- tongs and Metal Ingot the same way as a steel weapon made no sense --
    -- bone is carved, not smithed).
    CarveBone = {
        nameKey = "IGUI_TWA_Proc_CarveBone", icon = "Bone",
        tool = { kind = "tag", value = "SAW" },
        consumes = {},
        skill = "Woodwork:1",
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
        skill = "Woodwork:5",
    },
    AttachRakeHead = {
        nameKey = "IGUI_TWA_Proc_AttachRakeHead", icon = "RakeHead",
        tool = { kind = "tag", value = "WRENCH" },
        consumes = { { itemType = "Base.RakeHead", qty = 1 } },
        skill = "Woodwork:4",
    },
    AttachGardenForkHead = {
        nameKey = "IGUI_TWA_Proc_AttachGardenForkHead", icon = "Pitchfork_Broken_Head",
        tool = { kind = "tag", value = "WRENCH" },
        consumes = { { itemTypes = { "Base.GardenForkHead", "Base.GardenForkHead_Forged" }, qty = 1 } },
        skill = "Woodwork:6",
    },
    AttachSpadeHead = {
        nameKey = "IGUI_TWA_Proc_AttachSpadeHead", icon = "ShovelHead_Forged",
        tool = { kind = "tag", value = "WRENCH" },
        consumes = { { itemTypes = { "Base.SpadeHead", "Base.SpadeHead_Forged" }, qty = 1 } },
        skill = "Woodwork:6",
    },
    AttachRailspike = {
        nameKey = "IGUI_TWA_Proc_AttachRailspike", icon = "RailroadSpike",
        consumes = { { itemType = "Base.RailroadSpike", qty = 1 } },
        skill = "Woodwork:3",
    },
    AttachCan = {
        nameKey = "IGUI_TWA_Proc_AttachCan", icon = "TinCanEmpty",
        tool = { kind = "tag", value = "SCREWDRIVER" },
        consumes = { { itemTypes = { "Base.TinCanEmpty", "Base.WaterRationCanEmpty" }, qty = 1 } },
        skill = "Woodwork:1",
    },
    AttachScrapSheet = {
        nameKey = "IGUI_TWA_Proc_AttachScrapSheet", icon = "MetalSheetSmall",
        tool = { kind = "tag", value = "SCREWDRIVER" },
        consumes = { { itemTypes = { "Base.SmallSheetMetal", "Base.UnusableMetal", "Base.AluminumScrap" }, qty = 2 } },
        skill = "Woodwork:4",
    },
    AttachBrake = {
        nameKey = "IGUI_TWA_Proc_AttachBrake", icon = "CarBrakes",
        tool = { kind = "tag", value = "WRENCH" },
        consumes = { { itemTypes = {
            "Base.NormalBrake1", "Base.NormalBrake2", "Base.NormalBrake3",
            "Base.OldBrake1", "Base.OldBrake2", "Base.OldBrake3",
            "Base.ModernBrake1", "Base.ModernBrake2", "Base.ModernBrake3",
        }, qty = 1 } },
        skill = "Woodwork:5",
    },
}

-- Stable display order (pairs() over TWAProcedures.List has no guaranteed
-- order, so the UI's procedure-library grid iterates this instead).
-- Attach_<Name> ids (spear combo weapons) are appended here by
-- HARMONIE_TWA_RecipeData.lua at load time, since the set of distinct
-- attachment items is generated data, not hand-authored.
TWAProcedures.Order = {
    'HammerNails', 'HardenWood', 'CutShape', 'SharpenEdge', 'WrapGrip', 'BindLashing',
    'AttachHardware', 'AttachScrews', 'WrapWire', 'WrapBarbedWire', 'Disassemble',
    'AttachHandleSmall', 'AttachHandleLong', 'AttachHaft',
    'ForgeShape', 'PolishI', 'TemperII', 'ReinforceIII',
    'Weld', 'BoltAssembly', 'KnapStone', 'CarveBone',
    'AttachSawblade', 'AttachRakeHead', 'AttachGardenForkHead', 'AttachSpadeHead',
    'AttachRailspike', 'AttachCan', 'AttachScrapSheet', 'AttachBrake',
}

local function hasTool(spec, player)
    if not spec then return true end
    local inv = player:getInventory()
    if spec.kind == "tag" then
        return inv:containsTagEvalRecurse(ItemTag[spec.value], predicateNotBroken)
    elseif spec.kind == "type" then
        return inv:getFirstTypeEvalRecurse(spec.value, predicateNotBroken) ~= nil
    end
    return true
end

-- A consume slot is either a single real type (`itemType = "Base.X"`) or a
-- list of interchangeable real types (`itemTypes = {"Base.A", "Base.B"}`) --
-- vanilla itself treats these as equivalent (e.g. Base.Charcoal/
-- CharcoalCrafted/Coke all carry the same real `Tags = base:charcoal`, and
-- SteelIngot/IronIngot/CopperIngot/BrassIngot all carry `base:ingot`), so a
-- procedure that only accepted ONE of them was needlessly inflexible (bug
-- report 2026-09-26). `altTypes(c)` normalizes either form to a plain array.
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

-- Live eligibility check against a player's current inventory/skills.
-- Returns (metAll: bool, missing: array of {kind, ...} describing every unmet requirement).
function TWAProcedures.CheckEligibility(proc, player)
    local missing = {}

    if proc.tool and not hasTool(proc.tool, player) then
        missing[#missing + 1] = { kind = "tool", spec = proc.tool }
    end
    if proc.tool2 and not hasTool(proc.tool2, player) then
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
        reqs[#reqs + 1] = { kind = "tool", spec = proc.tool, met = hasTool(proc.tool, player) }
    end
    if proc.tool2 then
        reqs[#reqs + 1] = { kind = "tool", spec = proc.tool2, met = hasTool(proc.tool2, player) }
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

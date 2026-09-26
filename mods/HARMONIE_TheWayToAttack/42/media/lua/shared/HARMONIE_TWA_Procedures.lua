--============================================================================
-- HARMONIE_TheWayToAttack -- crafting procedure library (shared)
--
-- Full rebuild (request 2026-09-26: "ลบทุกอันก่อนหน้า และสร้างกรรมวิธีต่างๆ
-- ด้วยข้อมูลนี้" -- delete every previous procedure, build new ones from a
-- pasted 9-category/31-procedure design brief). The brief itself cites other
-- MODS (Hydrocraft/Metalworking Expanded) as design inspiration, not real
-- vanilla PZ data, so every tool/material/skill below was independently
-- grep-verified against the actual installed game before use, same
-- discipline as every earlier round -- a few concepts from the brief have NO
-- real vanilla equivalent (a "Crucible"/"Mold" item, an "AnimalTendon" item,
-- any acid item, a literal "WireCutters" item, a "Furnace" item) and are
-- flagged with *** SUBSTITUTED *** where a real, closely-related item/tool
-- stands in for them instead of inventing something fake.
--
-- Real per-procedure infrastructure (tool/tool2/consumes/skill/time/sound,
-- CheckEligibility/DescribeAll/Consume/AwardXP) is UNCHANGED from before --
-- only the actual procedure definitions and their category grouping are new.
-- `category` (a plain string) is new on every procedure -- used by
-- HARMONIE_TWA_CraftUI.lua's right-panel grid to draw a header per group
-- (request 2026-09-26: "จัดหมวดหมู่กรรมวิธีในหน้า ui ทางขวาด้วย").
--
-- Real skill Perk names used below (grep-confirmed from server/XpSystem/
-- XPSystem_SkillBook.lua's own real `SkillBook[x].perk = Perks.Y` mappings,
-- since several skill-BOOK display names do NOT match their real Perk enum
-- member -- e.g. the "Carpentry" skillbook is really `Perks.Woodwork`, and
-- the "Foraging" skillbook is really `Perks.PlantScavenging`, not
-- `Perks.Foraging`): Woodwork, Blacksmith, MetalWelding, FlintKnapping,
-- Masonry, Tailoring, Trapping.
--============================================================================

TWAProcedures = TWAProcedures or {}

local function predicateNotBroken(item)
    return not item:isBroken()
end

-- tool/tool2 = a single spec `{ kind = "tag"|"type", value = X }`, OR a LIST
-- of alternative specs `{ {kind=.., value=..}, {kind=.., value=..} }` meaning
-- "any one of these".
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
-- list of interchangeable real types (`itemTypes = {"Base.A", "Base.B"}`).
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

-- 9 categories, 31 procedures total (matches the pasted brief's own count).
-- Categories 6-9 come from the brief's own loosely-grouped "หมวดที่ 6 ถึง 9"
-- tail section (5 procedures, no explicit 1-per-category split given) --
-- split here into 4 categories by real subject matter (Chemical/Welding/
-- Balance+Rivets/Engraving) so the count lands on exactly 9/31 as named.
TWAProcedures.List = {
    -- ===== 1. Binding & Wrapping (การผูกและยึดติดด้วยวัสดุ) =====
    DuctTapeBinding = {
        category = "Binding", nameKey = "IGUI_TWA_Proc_DuctTapeBinding", icon = "DuctTape",
        consumes = { { itemType = "Base.DuctTape", qty = 2 } },
        skill = "Tailoring:1", time = 100, sound = "FixWithTape",
    },
    RopeTwineBinding = {
        category = "Binding", nameKey = "IGUI_TWA_Proc_RopeTwineBinding", icon = "Rope2",
        consumes = { { itemTypes = { "Base.Rope", "Base.Twine" }, qty = 2 } },
        skill = "Tailoring:1", time = 150, sound = "CraftFixWeapon",
    },
    -- *** SUBSTITUTED: the brief's "Wire Cutters" is not a real vanilla item
    -- (grep-confirmed absent) -- Base.Pliers is the real vanilla tool for
    -- wire work (already used this way by this mod in earlier rounds). ***
    WireBinding = {
        category = "Binding", nameKey = "IGUI_TWA_Proc_WireBinding", icon = "Wire",
        tool = { kind = "type", value = "Base.Pliers" },
        consumes = { { itemType = "Base.Wire", qty = 1 } },
        skill = "Tailoring:2", time = 150, sound = "CraftFixWeapon",
    },
    BarbedWireWrapping = {
        category = "Binding", nameKey = "IGUI_TWA_Proc_BarbedWireWrapping", icon = "BarbedWire",
        tool = { kind = "type", value = "Base.Pliers" },
        consumes = { { itemType = "Base.BarbedWire", qty = 1 } },
        skill = "Tailoring:2", time = 150, sound = "CraftFixWeapon",
    },
    LeatherStripsBinding = {
        category = "Binding", nameKey = "IGUI_TWA_Proc_LeatherStripsBinding", icon = "LeatherStrips",
        consumes = { { itemType = "Base.LeatherStrips", qty = 2 }, { itemType = "Base.Glue", qty = 1 } },
        skill = "Tailoring:1", time = 150, sound = "CraftFixWeapon",
    },

    -- ===== 2. Reinforcing & Impaling (การตอกย้ำและเสริมโครงสร้าง) =====
    Nailing = {
        category = "Reinforcing", nameKey = "IGUI_TWA_Proc_Nailing", icon = "Nails",
        tool = { { kind = "tag", value = "HAMMER" }, { kind = "type", value = "Base.WoodenMallet" } },
        consumes = { { itemType = "Base.Nails", qty = 5 } },
        skill = "Woodwork:1", time = 150, sound = "Hammering",
    },
    CanReinforcement = {
        category = "Reinforcing", nameKey = "IGUI_TWA_Proc_CanReinforcement", icon = "TinCanEmpty",
        tool = { kind = "tag", value = "HAMMER" },
        tool2 = { kind = "type", value = "Base.Pliers" },
        consumes = { { itemTypes = { "Base.TinCanEmpty", "Base.WaterRationCanEmpty" }, qty = 1 } },
        skill = "Blacksmith:1", time = 150, sound = "Hammering",
    },
    SheetMetalReinforcement = {
        category = "Reinforcing", nameKey = "IGUI_TWA_Proc_SheetMetalReinforcement", icon = "SheetMetal",
        tool = { kind = "tag", value = "WELDING_MASK" },
        tool2 = { kind = "type", value = "Base.BlowTorch" }, -- kept tool, real base:drainable KeepOnDeplete item
        consumes = { { itemType = "Base.SheetMetal", qty = 1 }, { itemType = "Base.ScrapMetal", qty = 1 } },
        skill = "MetalWelding:3", time = 400, sound = "CraftWelding",
    },
    BoneSpiking = {
        category = "Reinforcing", nameKey = "IGUI_TWA_Proc_BoneSpiking", icon = "Bone",
        tool = { kind = "tag", value = "SHARP_KNIFE" },
        consumes = { { itemTypes = { "Base.AnimalBone", "Base.LargeAnimalBone" }, qty = 1 } },
        skill = "Trapping:1", time = 200, sound = "SmashBoneHit",
    },

    -- ===== 3. Woodworking & Carving (งานไม้และแปรรูปจากธรรมชาติ) =====
    SawingPlankCutting = {
        category = "Woodworking", nameKey = "IGUI_TWA_Proc_SawingPlankCutting", icon = "Logs",
        tool = { kind = "tag", value = "SAW" },
        consumes = { { itemType = "Base.Log", qty = 1 } },
        skill = "Woodwork:1", time = 150, sound = "Sawing",
    },
    FireHardening = {
        category = "Woodworking", nameKey = "IGUI_TWA_Proc_FireHardening", icon = "LongHandle",
        consumes = {},
        skill = "Woodwork:1", time = 200, sound = "CraftFixWeapon",
    },
    WhittlingWoodCarving = {
        category = "Woodworking", nameKey = "IGUI_TWA_Proc_WhittlingWoodCarving", icon = "Handle",
        tool = { { kind = "tag", value = "SHARP_KNIFE" }, { kind = "type", value = "Base.KnifePocket" } },
        consumes = {},
        skill = "Woodwork:1", time = 150, sound = "CraftFixWeapon",
    },
    Chiseling = {
        category = "Woodworking", nameKey = "IGUI_TWA_Proc_Chiseling", icon = "HotChisel_Forged",
        tool = { kind = "type", value = "Base.CarpentryChisel" },
        tool2 = { kind = "type", value = "Base.WoodenMallet" },
        consumes = {},
        skill = "Woodwork:3", time = 250, sound = "Hammering",
    },

    -- ===== 4. Knapping & Stone Working (การกะเทาะหินและทำหินมีคม) =====
    StoneKnapping = {
        category = "Knapping", nameKey = "IGUI_TWA_Proc_StoneKnapping", icon = "RockSharpened",
        tool = {
            { kind = "type", value = "Base.HammerStone" },
            { kind = "tag", value = "HAMMER" }, { kind = "tag", value = "SLEDGEHAMMER" },
            { kind = "tag", value = "CLUB_HAMMER" }, { kind = "tag", value = "STONE_MAUL" },
            { kind = "tag", value = "PICK_AXE" },
        },
        consumes = { { itemType = "Base.SharpedStone", qty = 1 } },
        skill = "FlintKnapping:1", time = 200, sound = "SmashStoneHit",
    },
    StoneShaftFitting = {
        category = "Knapping", nameKey = "IGUI_TWA_Proc_StoneShaftFitting", icon = "Shaft",
        consumes = { { itemTypes = { "Base.Rope", "Base.Twine" }, qty = 1 } },
        skill = "FlintKnapping:1", time = 150, sound = "CraftWeaponSpearWood",
    },

    -- ===== 5. Forging & Metalworking (การตีเหล็กและหลอมโลหะ) =====
    -- *** SUBSTITUTED: no real vanilla "Furnace"/"Brick Furnace" item exists
    -- (grep-confirmed absent) -- Base.MasonsTrowel (real, Masonry skill) is
    -- the closest real vanilla tool for "build a stone/masonry base". ***
    FurnaceConstruction = {
        category = "Forging", nameKey = "IGUI_TWA_Proc_FurnaceConstruction", icon = "MasonsTrowel",
        tool = { kind = "type", value = "Base.MasonsTrowel" },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 2 } },
        skill = "Masonry:1", time = 300, sound = "CraftFixWeapon",
    },
    CharcoalBurning = {
        category = "Forging", nameKey = "IGUI_TWA_Proc_CharcoalBurning", icon = "Lighter",
        tool = { kind = "type", value = "Base.Lighter" },
        consumes = { { itemType = "Base.Log", qty = 1 } },
        skill = "Blacksmith:1", time = 300, sound = "CraftFixWeapon",
    },
    -- *** SUBSTITUTED: the brief's "Bellows" IS a real vanilla item
    -- (Base.LargeBellows), but it's placed FURNITURE (moveable.txt), not a
    -- carried tool -- this mod's procedure system only checks the player's
    -- own inventory, not nearby world objects, so it can't gate on it
    -- meaningfully. Base.Tongs (real, already used elsewhere here) stands in
    -- as the hand-held part of "tend the forge fire" instead. ***
    BellowsOperation = {
        category = "Forging", nameKey = "IGUI_TWA_Proc_BellowsOperation", icon = "Charcoal",
        tool = { kind = "type", value = "Base.Tongs" },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 1 } },
        skill = "Blacksmith:1", time = 200, sound = "CraftFixWeapon",
    },
    ScrapMetalCollection = {
        category = "Forging", nameKey = "IGUI_TWA_Proc_ScrapMetalCollection", icon = "ScrapMetal",
        tool = { { kind = "type", value = "Base.Crowbar" }, { kind = "tag", value = "WRENCH" }, { kind = "tag", value = "PIPE_WRENCH" } },
        consumes = {},
        skill = "Blacksmith:1", time = 150, sound = "CraftFixWeapon",
    },
    -- *** SUBSTITUTED: no real vanilla "Crucible" or "Metal/Sand Mold" item
    -- exists (grep-confirmed absent -- these are Hydrocraft/Metalworking-
    -- Expanded concepts, not vanilla PZ). Base.Tongs + Base.WeldingMask
    -- (both real, already used elsewhere here) stand in for "handle molten
    -- scrap safely" instead. ***
    CrucibleLoadingMelting = {
        category = "Forging", nameKey = "IGUI_TWA_Proc_CrucibleLoadingMelting", icon = "ScrapMetal",
        tool = { kind = "type", value = "Base.Tongs" },
        tool2 = { kind = "tag", value = "WELDING_MASK" },
        consumes = { { itemType = "Base.ScrapMetal", qty = 2 }, { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 2 } },
        skill = "Blacksmith:3", time = 400, sound = "Hammering",
    },
    -- *** SUBSTITUTED: no real vanilla mold item (see above) -- kept as a
    -- light real step (Tongs + a Charcoal top-up) rather than inventing a
    -- fake mold item. ***
    IngotCasting = {
        category = "Forging", nameKey = "IGUI_TWA_Proc_IngotCasting", icon = "Ingot_Steel",
        tool = { kind = "type", value = "Base.Tongs" },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 1 } },
        skill = "Blacksmith:3", time = 300, sound = "CraftFixWeapon",
    },
    HeatingTheMetal = {
        category = "Forging", nameKey = "IGUI_TWA_Proc_HeatingTheMetal", icon = "Charcoal",
        tool = { kind = "type", value = "Base.Tongs" },
        consumes = { { itemTypes = { "Base.Charcoal", "Base.CharcoalCrafted", "Base.Coke" }, qty = 2 } },
        skill = "Blacksmith:2", time = 300, sound = "CraftFixWeapon",
    },
    AnvilShaping = {
        category = "Forging", nameKey = "IGUI_TWA_Proc_AnvilShaping", icon = "Ingot_Steel",
        tool = { kind = "tag", value = "HAMMER" },
        tool2 = { kind = "type", value = "Base.Tongs" },
        consumes = {},
        skill = "Blacksmith:5", time = 500, sound = "Hammering",
    },
    Quenching = {
        category = "Forging", nameKey = "IGUI_TWA_Proc_Quenching", icon = "Ingot_Steel",
        consumes = {},
        skill = "Blacksmith:2", time = 150, sound = "CraftFixWeapon",
    },
    GrindingSharpening = {
        category = "Forging", nameKey = "IGUI_TWA_Proc_GrindingSharpening", icon = "Whetstone2",
        tool = {
            { kind = "type", value = "Base.Whetstone" },
            { kind = "type", value = "Base.File" },
            { kind = "type", value = "Base.SmallFileSet" },
        },
        consumes = {},
        skill = "Blacksmith:1", time = 150, sound = "SharpenBladeWhetstone",
    },
    HaftingHandleWrapping = {
        category = "Forging", nameKey = "IGUI_TWA_Proc_HaftingHandleWrapping", icon = "LeatherStrips",
        consumes = { { itemType = "Base.LeatherStrips", qty = 2 }, { itemType = "Base.Glue", qty = 1 } },
        skill = "Woodwork:1", time = 150, sound = "CraftFixWeapon",
    },

    -- ===== 6. Chemical Treatment (การกัดลายและปรับปรุงพื้นผิว) =====
    -- *** SUBSTITUTED: no real vanilla acid item (no MuriaticAcid/Vinegar
    -- Concentrate/generic "Acid" -- grep-confirmed absent) -- Base.Bleach
    -- (real, common vanilla cleaning item) stands in as the closest real
    -- corrosive liquid. ***
    ChemicalEtching = {
        category = "Chemical", nameKey = "IGUI_TWA_Proc_ChemicalEtching", icon = "Bleach",
        consumes = { { itemType = "Base.Bleach", qty = 1 } },
        skill = "Blacksmith:2", time = 300, sound = "CraftFixWeapon",
    },

    -- ===== 7. Welding & Assembly (การเชื่อมประกอบโครงเหล็ก) =====
    ScrapWelding = {
        category = "Welding", nameKey = "IGUI_TWA_Proc_ScrapWelding", icon = "BlowTorch",
        tool = { kind = "tag", value = "WELDING_MASK" },
        tool2 = { kind = "type", value = "Base.BlowTorch" },
        consumes = { { itemType = "Base.ScrapMetal", qty = 2 } },
        skill = "MetalWelding:2", time = 400, sound = "CraftWelding",
    },

    -- ===== 8. Balance & Rivets (การถ่วงสมดุลและตอกหมุด) =====
    Counterbalancing = {
        category = "Balance", nameKey = "IGUI_TWA_Proc_Counterbalancing", icon = "Drill_OldFashioned",
        tool = { kind = "type", value = "Base.HandDrill" },
        consumes = { { itemType = "Base.NutsBolts", qty = 2 } },
        skill = "Blacksmith:2", time = 200, sound = "CraftFixWeapon",
    },
    Riveting = {
        category = "Balance", nameKey = "IGUI_TWA_Proc_Riveting", icon = "Punch_Forged",
        tool = { kind = "type", value = "Base.MetalworkingPunch" },
        tool2 = { kind = "tag", value = "HAMMER" },
        consumes = { { itemType = "Base.NutsBolts", qty = 2 } },
        skill = "Blacksmith:2", time = 200, sound = "Hammering",
    },

    -- ===== 9. Finishing & Engraving (การแกะสลักแต่งขั้นสุด) =====
    CustomEngraving = {
        category = "Engraving", nameKey = "IGUI_TWA_Proc_CustomEngraving", icon = "HotChisel_Forged",
        tool = { { kind = "type", value = "Base.CarpentryChisel" }, { kind = "type", value = "Base.File" } },
        consumes = {},
        skill = "Blacksmith:3", time = 300, sound = "SharpenBladeWhetstone",
    },
}

-- 9 categories in display order, each with its own translated header and the
-- ordered list of procedure ids inside it -- both the flat `Order` (used
-- wherever a plain list is still needed) and the new `Categories` (used by
-- the right-panel grid to draw a header per group, request 2026-09-26:
-- "จัดหมวดหมู่กรรมวิธีในหน้า ui ทางขวาด้วย") are derived from ONE list here
-- so they can never drift apart.
TWAProcedures.Categories = {
    { key = "Binding", nameKey = "IGUI_TWA_ProcCat_Binding", ids = { 'DuctTapeBinding', 'RopeTwineBinding', 'WireBinding', 'BarbedWireWrapping', 'LeatherStripsBinding' } },
    { key = "Reinforcing", nameKey = "IGUI_TWA_ProcCat_Reinforcing", ids = { 'Nailing', 'CanReinforcement', 'SheetMetalReinforcement', 'BoneSpiking' } },
    { key = "Woodworking", nameKey = "IGUI_TWA_ProcCat_Woodworking", ids = { 'SawingPlankCutting', 'FireHardening', 'WhittlingWoodCarving', 'Chiseling' } },
    { key = "Knapping", nameKey = "IGUI_TWA_ProcCat_Knapping", ids = { 'StoneKnapping', 'StoneShaftFitting' } },
    { key = "Forging", nameKey = "IGUI_TWA_ProcCat_Forging", ids = {
        'FurnaceConstruction', 'CharcoalBurning', 'BellowsOperation', 'ScrapMetalCollection',
        'CrucibleLoadingMelting', 'IngotCasting', 'HeatingTheMetal', 'AnvilShaping',
        'Quenching', 'GrindingSharpening', 'HaftingHandleWrapping',
    } },
    { key = "Chemical", nameKey = "IGUI_TWA_ProcCat_Chemical", ids = { 'ChemicalEtching' } },
    { key = "Welding", nameKey = "IGUI_TWA_ProcCat_Welding", ids = { 'ScrapWelding' } },
    { key = "Balance", nameKey = "IGUI_TWA_ProcCat_Balance", ids = { 'Counterbalancing', 'Riveting' } },
    { key = "Engraving", nameKey = "IGUI_TWA_ProcCat_Engraving", ids = { 'CustomEngraving' } },
}

TWAProcedures.Order = {}
for _, cat in ipairs(TWAProcedures.Categories) do
    for _, id in ipairs(cat.ids) do
        TWAProcedures.Order[#TWAProcedures.Order + 1] = id
    end
end

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
-- ones), each tagged with its own `met` flag.
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
-- CheckEligibility already confirmed everything is present.
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

-- Grants the procedure's skill XP on completion. Real API:
-- `character:getXp():AddXP(perk, amount)`, confirmed from ISPlayerStatsUI.lua's
-- own real usage.
function TWAProcedures.AwardXP(proc, player)
    if not proc.skill then return end
    local skillName, lvl = proc.skill:match("^(%a+):(%d+)$")
    lvl = tonumber(lvl)
    local perk = skillName and Perks[skillName]
    if perk then
        player:getXp():AddXP(perk, lvl * 10)
    end
end

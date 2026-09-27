--============================================================================
-- HARMONIE_TheWayToAttack -- procedural weapon-crafting UI (client)
--
-- Replaces the old vanilla-craftRecipe-based "Weapon+" tab entirely. Three
-- panels: left = recipe list (search + category filter, greyed out unless
-- the recipe's base item is owned), center = selected recipe's preview,
-- stats, required-procedure checklist, Cancel/Finish, right = the full
-- procedure library (every procedure, clickable when its own tool/material/
-- skill requirements are met). Data comes from HARMONIE_TWA_RecipeData.lua
-- (generated) and HARMONIE_TWA_Procedures.lua (the procedure library).
--============================================================================

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "TimedActions/ISTimedActionQueue"

-- NeatUI Framework (Workshop 3508537032, require=NeatUI_Framework in
-- mod.info forces load order) -- no `require "neatui_framework/..."` needed,
-- its NeatTool.* tables declare themselves as globals at load time (see
-- mods/workflow.txt 8.3, researched from its own real source). Used here for
-- ThreePatch-stretched panel/button chrome, so this UI doesn't look like flat
-- vanilla-default rectangles.
-- innerBG/contentBG (NeatUI's DefaultPanel textures) were dropped 2026-09-26
-- -- their base pixels are too light to sit safely under white/red text, see
-- drawNeatCard's note below. Only the button chrome and the check icon are
-- still real NeatUI assets.
local TWA_NEAT = {
    btnL = getTexture("media/ui/NeatUI/Button/Button_FULL_L.png"),
    btnM = getTexture("media/ui/NeatUI/Button/Button_FULL_M.png"),
    btnR = getTexture("media/ui/NeatUI/Button/Button_FULL_R.png"),
    check = getTexture("media/ui/NeatUI/ICON/ICON_Check.png"),
}

-- A round-trip through this UI's second real bug report: the first pass used
-- NeatUI's own CategoryText_L/M/R texture for filter tabs, but that texture
-- set is a light/pale color -- plain white drawText on top of it was
-- unreadable on every non-active tab (only the orange-tinted active one had
-- enough contrast). Fixed everywhere in this file by never drawing bare
-- drawText for anything that sits on a textured or variable background:
-- always a 1px dark drop-shadow first, so the label stays legible regardless
-- of what's under it.
local function drawTextShadowed(panel, text, x, y, r, g, b, a, font)
    panel:drawText(text, x + 1, y + 1, 0, 0, 0, a * 0.8, font)
    panel:drawText(text, x, y, r, g, b, a, font)
end

-- Bug report 2026-09-27: "วัตถุดิบที่ใช้ในกรรมวิธีบางอันมันยาวเกินไปจนล้นออก
-- ui" -- a long flexible-material alt-list (e.g. "Charcoal / CharcoalCrafted
-- / Coke x2 (0/2)") drawn as one line can run past the panel's own right
-- edge. Greedy word-wrap on spaces (every alt-list is already joined with
-- " / ", so it wraps at a sensible point) into as many lines as needed.
local function wrapTextLines(text, maxWidth, font)
    local lines = {}
    local current = ""
    for word in text:gmatch("%S+") do
        local candidate = (current == "") and word or (current .. " " .. word)
        if getTextManager():MeasureStringX(font, candidate) > maxWidth and current ~= "" then
            lines[#lines + 1] = current
            current = word
        else
            current = candidate
        end
    end
    if current ~= "" then lines[#lines + 1] = current end
    if #lines == 0 then lines[1] = text end
    return lines
end

-- Draws a card behind a list row / checklist icon, tinted by state, with a
-- small green checkmark badge in the corner once true/owned/done.
-- *** REAL BUG FIXED (2026-09-26): this used to draw NeatUI's own
-- InnerPanel_BG texture under everything, tinted by multiplying the state
-- color by 3. That texture's own base pixels are light/pale (the same root
-- cause already found once for the filter-tab texture, 8.11 round 3), so the
-- result was a much brighter grey background than the state color alone
-- would suggest -- white and red text drawn on top lost contrast exactly as
-- reported. Fixed by dropping the texture for card backgrounds entirely and
-- always using a flat drawRect, so the background color is exactly what the
-- state colors above say it is, never lightened by an unpredictable source
-- texture. ***
-- `ok` here only darkens/brightens the card background+border (met/owned
-- vs not) -- it no longer draws the checkmark badge itself. See
-- drawCheckBadge below, called separately by callers AFTER their icon
-- texture, fixing 2 real bugs reported 2026-09-26: (1) the checkmark used to
-- render behind the icon because it was drawn here, before the caller's own
-- icon draw call in the same frame; (2) it used to appear whenever a
-- procedure's requirements were simply MET, not only once actually
-- performed -- conflating "ready to do" with "already done".
local function drawNeatCard(panel, x, y, w, h, ok, selected, hovered)
    local r, g, b, a = 0.1, 0.1, 0.1, 0.92
    if selected then
        r, g, b, a = 0.3, 0.2, 0.03, 0.95
    elseif hovered then
        r, g, b, a = 0.16, 0.16, 0.16, 0.92
    elseif not ok then
        r, g, b, a = 0.06, 0.06, 0.06, 0.85
    end
    panel:drawRect(x, y, w, h, a, r, g, b)
    local edgeR, edgeG, edgeB, edgeA = 0.35, 0.35, 0.35, 0.6
    if selected then edgeR, edgeG, edgeB, edgeA = 1, 0.7, 0.2, 1 end
    panel:drawRectBorder(x, y, w, h, edgeA, edgeR, edgeG, edgeB)
end

-- Small green checkmark badge -- call this AFTER drawing the cell's own icon
-- texture so it always renders on top, never underneath it.
local function drawCheckBadge(panel, x, y, w)
    if TWA_NEAT.check then
        panel:drawTextureScaled(TWA_NEAT.check, x + w - 20, y + 4, 16, 16, 1, 1, 1, 1)
    end
end

-- A ThreePatch-skinned ISButton (the exact pattern confirmed working from
-- Modern Status's own real MS_LongButton.lua, see mods/workflow.txt 8.3).
TWANeatButton = ISButton:derive("TWANeatButton")

function TWANeatButton:new(x, y, w, h, title, target, onclick)
    local o = ISButton:new(x, y, w, h, title, target, onclick)
    setmetatable(o, self)
    self.__index = self
    o:setDisplayBackground(false)
    o.neatTint = { r = 1, g = 1, b = 1 }
    o.neatTextures = { TWA_NEAT.btnL, TWA_NEAT.btnM, TWA_NEAT.btnR }
    return o
end

function TWANeatButton:render()
    local disabled = self.enable == false
    local alpha = disabled and 0.35 or (self:isMouseOver() and 1 or 0.85)
    local t = self.neatTint
    local drew = NeatTool.ThreePatch.drawHorizontal(self, 0, 0, self.width, self.height,
        self.neatTextures[1], self.neatTextures[2], self.neatTextures[3], alpha, t.r, t.g, t.b)
    if not drew then
        self:drawRectBorder(0, 0, self.width, self.height, alpha, t.r, t.g, t.b)
    end
    if self.title and self.title ~= "" then
        local font = self.font or UIFont.Small
        local textW = getTextManager():MeasureStringX(font, self.title)
        local textH = getTextManager():getFontHeight(font)
        drawTextShadowed(self, self.title, (self.width - textW) / 2, (self.height - textH) / 2, 1, 1, 1, 1, font)
    end
end

-- Flat, guaranteed-readable filter tab: NOT texture-based (that's what broke
-- last time -- pale ThreePatch chrome with plain white text on top made
-- every non-active tab's label invisible). A solid fill + shadowed text reads
-- correctly no matter the theme.
TWATabButton = ISButton:derive("TWATabButton")

function TWATabButton:new(x, y, w, h, title, target, onclick)
    local o = ISButton:new(x, y, w, h, title, target, onclick)
    setmetatable(o, self)
    self.__index = self
    o:setDisplayBackground(false)
    return o
end

function TWATabButton:isActiveTab()
    return self.target and self.target.recipeList and self.target.recipeList.filterCategory == self.internal
end

-- Same flat-fill button, checked against the tier filter instead of the
-- category filter (request 2026-09-26: "filter by tier too").
TWATierTabButton = TWATabButton:derive("TWATierTabButton")

function TWATierTabButton:isActiveTab()
    return self.target and self.target.recipeList and self.target.recipeList.filterTier == self.internal
end

-- Same layout as TWATabButton:render(), but the active/border color comes
-- from the tier's own real color (`self.neatTint`, set at creation) instead
-- of the fixed orange -- so each tier tab reads at a glance (request
-- 2026-09-26: "color-code by tier").
function TWATierTabButton:render()
    local active = self:isActiveTab()
    local hovered = self:isMouseOver()
    local t = self.neatTint
    local r, g, b, a = 0.18, 0.18, 0.18, 0.9
    if active and t then
        r, g, b, a = t.r, t.g, t.b, 1
    elseif hovered then
        r, g, b, a = 0.28, 0.28, 0.28, 0.95
    end
    self:drawRect(0, 0, self.width, self.height, a, r, g, b)
    local borderColor = t or { r = 0.4, g = 0.4, b = 0.4 }
    self:drawRectBorder(0, 0, self.width, self.height, active and 1 or 0.5, borderColor.r, borderColor.g, borderColor.b)
    -- Always-visible bottom strip in the tier's own color, even when inactive
    -- (request 2026-09-26: "arrange the filter section to look nicer") --
    -- so the rarity color reads at a glance instead of only appearing once a
    -- tab is clicked, same idea as the recipe list's own tier-color strip.
    if t then
        self:drawRect(0, self.height - 3, self.width, 3, 1, t.r, t.g, t.b)
    end
    if self.title and self.title ~= "" then
        local font = self.font or UIFont.Small
        local textW = getTextManager():MeasureStringX(font, self.title)
        local textH = getTextManager():getFontHeight(font)
        drawTextShadowed(self, self.title, (self.width - textW) / 2, (self.height - textH) / 2 - 1, 1, 1, 1, 1, font)
    end
end

function TWATabButton:render()
    local active = self:isActiveTab()
    local hovered = self:isMouseOver()
    local r, g, b, a = 0.18, 0.18, 0.18, 0.9
    if active then
        r, g, b, a = 0.85, 0.5, 0.1, 1
    elseif hovered then
        r, g, b, a = 0.28, 0.28, 0.28, 0.95
    end
    self:drawRect(0, 0, self.width, self.height, a, r, g, b)
    self:drawRectBorder(0, 0, self.width, self.height, active and 1 or 0.5,
        active and 1 or 0.4, active and 0.7 or 0.4, active and 0.2 or 0.4)
    if self.title and self.title ~= "" then
        local font = self.font or UIFont.Small
        local textW = getTextManager():MeasureStringX(font, self.title)
        local textH = getTextManager():getFontHeight(font)
        drawTextShadowed(self, self.title, (self.width - textW) / 2, (self.height - textH) / 2, 1, 1, 1, 1, font)
    end
end

TWACraftUI = TWACraftUI or {}

local WINDOW_W = 1000
local WINDOW_H = 640
local LEFT_W = 280
local CENTER_W = 380
local RIGHT_W = 300
local COL_GAP = 10
local PANEL_H = 520

-- Weapon-modification parts (Grip/Head/Tactical/Weight) are intentionally not
-- listed here any more -- request 2026-09-26: they're out of scope for this
-- crafting UI entirely (still real items, attached via the separate weapon-
-- modification UI, just no longer craftable through this one).
-- Bug report 2026-09-27: "ไอเท็มใหม่ที่ฉันให้สร้างอยู่ไหน ทำไมไม่มีใน ui
-- สร้าง" -- the 6 new Metallurgy material items (category = "Material")
-- were real and present in the data all along, but had no dedicated filter
-- tab -- they only ever showed under All/Available, which is exactly the
-- kind of thing easy to miss while clicking through category tabs looking
-- for them (a real usability gap flagged, not fixed, when they were added).
-- Added a real "Material" tab here instead of just re-explaining the
-- limitation.
-- Labels are plain English, NOT translated (request 2026-09-28: "filter
-- หมวดหมู่ให้ใช้ภาษาอังกฤษ") -- same convention already established for
-- tier names (TIER_INFO above) and TIER_TABS's own tier labels.
local CATEGORY_TABS = {
    { key = "All", label = "All" },
    { key = "Available", label = "Available" },
    { key = "Axe", label = "Axe" },
    { key = "SmallBlade", label = "Small Blade" },
    { key = "Blunt", label = "Blunt" },
    { key = "SmallBlunt", label = "Small Blunt" },
    { key = "LongBlade", label = "Long Blade" },
    { key = "Spear", label = "Spear" },
    { key = "Material", label = "Material" },
}

-- Rarity tiers (request 2026-09-26): computed at generation time from DPS
-- (avgDamage * BaseSpeed) against FIXED thresholds, baked into
-- TWARecipeData.Stats[x].tier. Full 8-tier scale. Legendary and Prototype
-- swapped positions (request 2026-09-26, given as a full explicit table):
-- Legendary is now DPS < 10 (was Prototype's old slot), Prototype is now
-- the unbounded top tier DPS >= 10 (was Legendary's old slot) -- gen_
-- craftdata.js's DPS_TIER_THRESHOLDS is the source of truth for the actual
-- boundary; only the NAMES/colors here need to track which number each one
-- is attached to. TIER_INFO below keeps all 8 (still used for the recipe-
-- list color strip and the center-panel tier label); TIER_TABS (the filter
-- row) omits Junk and Prototype on purpose -- that exclusion is about the
-- NAMES, not fixed tier numbers, so it moved with "Prototype" to slot 8.
-- Names are plain English, NOT translated (request 2026-09-26: "ไม่ต้องแปล
-- ชื่อ tier").
local TIER_INFO = {
    [1] = { name = "Junk", r = 1.0, g = 1.0, b = 1.0 },
    [2] = { name = "Common", r = 0.3, g = 0.7, b = 1.0 },
    [3] = { name = "Uncommon", r = 0.25, g = 0.85, b = 0.3 },
    [4] = { name = "Rare", r = 1.0, g = 0.45, b = 0.75 },
    [5] = { name = "Epic", r = 0.65, g = 0.3, b = 0.95 },
    [6] = { name = "Elite", r = 1.0, g = 0.55, b = 0.15 },
    [7] = { name = "Legendary", r = 1.0, g = 0.85, b = 0.15 },
    [8] = { name = "Prototype", r = 0.85, g = 0.2, b = 0.15 },
}
-- Junk (1) and Prototype (now 8) are intentionally left OUT of this list --
-- both tiers still exist (TIER_INFO above, the generated Stats table, and
-- the real-item tooltip all still know about them), they just aren't
-- offered as filter choices in this specific window.
local TIER_TABS = {
    { key = "All", labelKey = "IGUI_TWA_FilterAll" },
    { key = 2, label = "Common" },
    { key = 3, label = "Uncommon" },
    { key = 4, label = "Rare" },
    { key = 5, label = "Epic" },
    { key = 6, label = "Elite" },
    { key = 7, label = "Legendary" },
}

local function getItemScript(fullType)
    local ok, item = pcall(function() return ScriptManager.instance:getItem(fullType) end)
    if ok then return item end
    return nil
end

local function getItemTexture(icon)
    if not icon then return nil end
    return getTexture("media/textures/Item_" .. icon .. ".png")
end

-- Lazily-built id -> recipe lookup (request 2026-09-27: resuming an
-- Incomplete item only has the recipe's id, stamped into its own ModData --
-- see TWACraftWindow:resumeFromItem). Not baked into the GENERATED
-- HARMONIE_TWA_RecipeData.lua itself -- that file gets regenerated from
-- scratch by gen_craftdata.js often enough this session that adding to it
-- would mean also touching the generator; a small runtime cache here needs
-- no generator change and costs nothing (built once, on first use).
local recipeByIdCache
local function getRecipeById(id)
    if not recipeByIdCache then
        recipeByIdCache = {}
        for _, r in ipairs(TWARecipeData.List) do
            recipeByIdCache[r.id] = r
        end
    end
    return recipeByIdCache[id]
end
-- Exported so HARMONIE_TWA_TierTooltip.lua can resolve a bookmarked base
-- item's TWA_RecipeId into a real recipe too, for its own procedure-progress
-- checklist display -- both files are client Lua with no guaranteed load
-- order relative to each other, so this needs to be a real public field
-- rather than assumed reachable as a bare local.
TWACraftUI.getRecipeById = getRecipeById

-- Request 2026-09-27: "คลิกขวาเปิด ui ผ่านอาวุธจะค้นหาชื่ออาวุธนั้นโดย
-- อัตโนมัติ...คลิกขวาเปิด ui ผ่านชิ้นส่วนตั้งต้นจะค้นหาด้วยชื่อของชิ้นส่วน"
-- -- classifies a fullType as either something this UI can PRODUCE (any
-- recipe.result) or something it CONSUMES (any recipe's base/base2/baseAlt),
-- returning that item's own display name to prefill the search box with --
-- or nil for anything neither (falls through to a plain blank-search open,
-- covering "right-click any other item/floor/table" from the same request).
-- Checked in this order deliberately: some items (the 5 tiered MaterialBars)
-- are BOTH a Metallurgy recipe's own result AND a weapon recipe's base2 --
-- treating "producible" as the answer people actually want when right-
-- clicking that exact item (how do I make more of this) rather than "what
-- can I build WITH this", though either reading would be defensible.
function TWACraftUI.autoSearchNameFor(fullType)
    if not fullType then return nil end
    local isResult, isBase = false, false
    for _, recipe in ipairs(TWARecipeData.List) do
        if recipe.result == fullType then isResult = true break end
    end
    if not isResult then
        for _, recipe in ipairs(TWARecipeData.List) do
            if recipe.base == fullType or recipe.base2 == fullType or recipe.baseAlt == fullType then
                isBase = true
                break
            end
        end
    end
    if not isResult and not isBase then return nil end
    local it = getItemScript(fullType)
    return it and it:getDisplayName() or fullType
end

-- `recipe.base` is either nil (no starting item needed at all) or a SINGLE
-- real fullType string -- every recipe has exactly one starting item now
-- (request 2026-09-27: "ปรับให้ทุกอันมีชิ้นงานตั้งต้นเพียงชิ้นเดียว"). The
-- earlier base+base2 two-slot system and interchangeable-alternatives lists
-- (e.g. "any of 4 Metal Ingot types") are gone -- gen_craftdata.js now
-- resolves each recipe down to one specific real item at generation time.
-- `recipe.baseAlt`, when present, is a single OPTIONAL substitute for that
-- same slot -- NOT a return to multi-item lists (request 2026-09-27: "อะไรที่
-- ใช้แท่งแร่เป็นขิ้นงานตั้งต้น ให้สามารถใช้ท่อเหล็กแทนได้" -- anything based
-- on a Metal Ingot can also use a Metal Pipe).
-- request 2026-09-27: "ทำให้สูตรไอเท็ม uncommon ทุกชิ้นใช้ชิ้นส่วนตั้งต้น
-- ชิ้นที่ 2 (ไม่ใช่ optional) เป็น แท่งวัตถุดิบ Uncommon...โดยใช้แท่งวัตถุดิบ
-- ของ tier ตัวเอง" -- reintroduces a real, REQUIRED `base2` slot (both base
-- AND base2 must be owned) -- NOT an OR-alternative like the removed
-- MetalPipe `baseAlt`, which stays supported here too (still dead data-side
-- since nothing emits it any more, but harmless to leave).
local function ownsBase(recipe, player)
    if not recipe.base then return true end
    local inv = player:getInventory()
    local hasBase = inv:getItemCountRecurse(recipe.base) >= 1
    if not hasBase and recipe.baseAlt then
        hasBase = inv:getItemCountRecurse(recipe.baseAlt) >= 1
    end
    if not hasBase then return false end
    if recipe.base2 and inv:getItemCountRecurse(recipe.base2) < 1 then return false end
    return true
end

-- Prefer the baked icon (resolved at generation time from the item's real
-- Icon-or-first-IconsForTexture field -- see gen_craftdata.js) over a live
-- item:getIcon() lookup, which returns nothing for IconsForTexture-only
-- items (bug report 2026-09-26: several recipe rows showed no image at
-- all). Falls back to the runtime script lookup for anything not baked.
local function resultIcon(fullType)
    local stats = TWARecipeData.Stats[fullType]
    if stats and stats.icon then return getItemTexture(stats.icon) end
    local item = getItemScript(fullType)
    return item and getItemTexture(item:getIcon())
end

-- Readable name for the recipe's base requirement -- shows "X / Y" when a
-- baseAlt substitute exists.
local function baseDisplayName(base, baseAlt)
    if not base then return "" end
    local it = getItemScript(base)
    local name = it and it:getDisplayName() or base
    if baseAlt then
        local altIt = getItemScript(baseAlt)
        name = name .. " / " .. (altIt and altIt:getDisplayName() or baseAlt)
    end
    return name
end

-- Recipe list (left panel) -- a real ISScrollingListBox, the same proven
-- component every scrollable list in vanilla uses (confirmed by reading its
-- own source: it manages its own scrollbar/stencil-clipping/scroll-height
-- entirely internally via prerender(), which a hand-rolled ISPanel does not
-- get for free -- that was the real cause of the missing scrollbars before).

TWARecipeScrollList = ISScrollingListBox:derive("TWARecipeScrollList")

function TWARecipeScrollList:new(x, y, w, h, ui)
    local o = ISScrollingListBox:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.ui = ui
    o.itemheight = 52
    o.font = UIFont.Small
    o.drawBorder = true
    o.backgroundColor = { r = 0.07, g = 0.07, b = 0.08, a = 0.95 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.6 }
    o.filterCategory = "All"
    o.filterTier = "All"
    o.searchText = ""
    o:setOnMouseDownFunction(o, TWARecipeScrollList.onRowClick)
    return o
end

function TWARecipeScrollList:onRowClick(recipe)
    -- Always selectable, even without the base item owned yet -- the center
    -- panel is how the player finds out what's needed in the first place;
    -- Finish itself stays gated on actually owning it (see allProceduresDone).
    self.ui:selectRecipe(recipe)
end

function TWARecipeScrollList:setFilter(cat)
    self.filterCategory = cat
    self:refresh()
end

-- Tier filter (request 2026-09-26: "filter by tier too"), independent of and
-- combined (AND) with the category filter above.
function TWARecipeScrollList:setTierFilter(tier)
    self.filterTier = tier
    self:refresh()
end

function TWARecipeScrollList:setSearch(text)
    self.searchText = text or ""
    self:refresh()
end

function TWARecipeScrollList:matches(recipe)
    if self.filterCategory ~= "All" and self.filterCategory ~= "Available" and recipe.category ~= self.filterCategory then
        return false
    end
    if self.filterCategory == "Available" and not ownsBase(recipe, getPlayer()) then
        return false
    end
    if self.filterTier ~= "All" then
        local stats = TWARecipeData.Stats[recipe.result]
        if not stats or stats.tier ~= self.filterTier then
            return false
        end
    end
    -- Request 2026-09-27 (multiplayer collaborative crafting): "การ search
    -- ใน ui เพิ่มให้สามารถค้นหาด้วย ชื่อชิ้นส่วนตั้งต้น กรรมวิธีที่ต้องทำ" --
    -- search now also matches the recipe's base/base2 item name(s) and every
    -- required procedure's own translated name, not just the result's name.
    -- This is also the exact mechanism the new procedure-details magnifying-
    -- glass button reuses (TWACraftWindow:onSearchByProcedure) -- searching
    -- for a procedure's own name naturally filters down to every recipe that
    -- lists it, with no separate filter code path needed.
    if self.searchText ~= "" then
        local q = string.lower(self.searchText)
        local function nameMatches(fullType)
            if not fullType then return false end
            local it = getItemScript(fullType)
            local n = it and it:getDisplayName() or fullType
            return string.find(string.lower(n), q, 1, true) ~= nil
        end
        local matched = nameMatches(recipe.result) or nameMatches(recipe.base)
            or nameMatches(recipe.base2) or nameMatches(recipe.baseAlt)
        if not matched then
            for _, procId in ipairs(recipe.procedures) do
                local proc = TWAProcedures.List[procId]
                if proc and string.find(string.lower(getText(proc.nameKey)), q, 1, true) then
                    matched = true
                    break
                end
            end
        end
        if not matched then return false end
    end
    return true
end

function TWARecipeScrollList:refresh()
    self:clear()
    -- Sorted alphabetically by display name (request 2026-09-26) -- resolved
    -- at runtime since the display name only exists via getDisplayName(),
    -- not something the generator can pre-sort by.
    local matched = {}
    for _, recipe in ipairs(TWARecipeData.List) do
        if self:matches(recipe) then
            local item = getItemScript(recipe.result)
            local name = item and item:getDisplayName() or recipe.result
            matched[#matched + 1] = { name = name, recipe = recipe }
        end
    end
    table.sort(matched, function(a, b) return a.name < b.name end)
    for _, m in ipairs(matched) do
        self:addItem(m.name, m.recipe)
    end
end

function TWARecipeScrollList:doDrawItem(y, entry, alt)
    local recipe = entry.item
    local h = entry.height or self.itemheight
    local owned = ownsBase(recipe, getPlayer())
    local selected = self.ui.selectedRecipe == recipe
    local hovered = self.mouseoverselected == entry.index
    local pad = 6
    drawNeatCard(self, 2, y + 2, self:getWidth() - 4, h - 4, owned, selected, hovered)
    -- Rarity-tier color strip on the left edge of the card (request
    -- 2026-09-26: "color the recipe list by tier") -- a thin bar rather than
    -- tinting the whole card, so it stays legible alongside the owned/
    -- selected/hovered card-background states above.
    local stats = TWARecipeData.Stats[recipe.result]
    local tierInfo = stats and stats.tier and TIER_INFO[stats.tier]
    if tierInfo then
        self:drawRect(2, y + 2, 4, h - 4, 1, tierInfo.r, tierInfo.g, tierInfo.b)
    end
    local tex = resultIcon(recipe.result)
    local iconSize = h - 4 * pad
    local tint = owned and 1 or 0.4
    if tex then
        self:drawRect(pad + 2, y + pad, iconSize, iconSize, 0.5, 0, 0, 0)
        self:drawTextureScaled(tex, pad + 2, y + pad, iconSize, iconSize, 1, tint, tint, tint)
    end
    if owned then drawCheckBadge(self, 2, y + 2, self:getWidth() - 4) end
    local textX = pad + iconSize + 10
    drawTextShadowed(self, entry.text, textX, y + pad, 0.95, 0.95, 0.95, 1, self.font)
    local statusKey = owned and "IGUI_TWA_BaseItemOwned"
        or (recipe.base and "IGUI_TWA_BaseItemMissing" or "IGUI_TWA_NoBaseItemNeeded")
    local sr, sg, sb = owned and 0.45 or 0.9, owned and 0.95 or 0.45, 0.45
    drawTextShadowed(self, getText(statusKey), textX, y + h - 22, sr, sg, sb, 1, UIFont.Small)
    return y + h
end

-- Procedure library (right panel) -- an icon-frame GRID, not a text-row list
-- (request 2026-09-26). Each ISScrollingListBox "item" is one grid ROW (an
-- array of up to perRow procedure ids); doDrawItem draws every cell in that
-- row itself. Hover shows only the procedure's name (a 1-line tooltip);
-- clicking a cell hands off to the window, which shows full requirement
-- details in the fixed panel below the grid AND performs the procedure if
-- it's eligible and belongs to the selected recipe (see
-- TWACraftWindow:onProcedureCellClicked).

TWAProcScrollList = ISScrollingListBox:derive("TWAProcScrollList")

function TWAProcScrollList:new(x, y, w, h, ui)
    local o = ISScrollingListBox:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.ui = ui
    o.font = UIFont.Small
    o.drawBorder = true
    o.backgroundColor = { r = 0.07, g = 0.07, b = 0.08, a = 0.95 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.6 }
    o.cellSize = 52
    o.cellGap = 6
    o.cellPad = 6
    o.perRow = math.max(1, math.floor((w - 2 * o.cellPad + o.cellGap) / (o.cellSize + o.cellGap)))
    o.itemheight = o.cellSize + o.cellGap
    o.hoverCol = -1
    return o
end

-- Grouped by category (request 2026-09-26: "จัดหมวดหมู่กรรมวิธีในหน้า ui
-- ทางขวาด้วย" -- organize the procedures in the right-side UI panel into
-- categories too). Each `TWAProcedures.Categories` entry becomes one header
-- row (its own translated name) followed by that category's procedures
-- packed into grid rows, same cell layout as before. Header rows and grid
-- rows are told apart by shape (`entry.item.header` vs `entry.item.row`) --
-- see doDrawItem/onMouseDown below. `self.itemheight` is toggled around each
-- addItem() call so ISScrollingListBox's own real addItem() (which reads
-- `self.itemheight` to both stamp the new entry's height AND grow the
-- scrollbar) picks up the right height for whichever kind of row it's
-- adding -- confirmed real from ISScrollingListBox.lua's own source.
function TWAProcScrollList:populate()
    self:clear()
    local gridItemHeight = self.cellSize + self.cellGap
    self.headerHeight = 22
    for _, cat in ipairs(TWAProcedures.Categories) do
        local ids = {}
        for _, id in ipairs(cat.ids) do
            if TWAProcedures.List[id] then ids[#ids + 1] = id end
        end
        if #ids > 0 then
            self.itemheight = self.headerHeight
            self:addItem("", { header = cat.nameKey })
            self.itemheight = gridItemHeight
            local row = nil
            for _, id in ipairs(ids) do
                if not row or #row >= self.perRow then
                    row = {}
                    self:addItem("", { row = row })
                end
                row[#row + 1] = id
            end
        end
    end
    self.itemheight = gridItemHeight
end

function TWAProcScrollList:cellAt(mx)
    return math.floor((mx - self.cellPad) / (self.cellSize + self.cellGap)) + 1
end

function TWAProcScrollList:onMouseMove(dx, dy)
    if self:isMouseOverScrollBar() then
        self.mouseoverselected = -1
        self.hoverCol = -1
        return
    end
    self.mouseoverselected = self:rowAt(self:getMouseX(), self:getMouseY())
    self.hoverCol = self:cellAt(self:getMouseX())
end

function TWAProcScrollList:onMouseMoveOutside(x, y)
    self.mouseoverselected = -1
    self.hoverCol = -1
end

function TWAProcScrollList:onMouseDown(x, y)
    if #self.items == 0 then return end
    local row = self:rowAt(x, y)
    if row < 1 or row > #self.items then return end
    local entry = self.items[row]
    if not entry.item.row then return end -- header row, not clickable
    local ids = entry.item.row
    local col = self:cellAt(x)
    local id = ids[col]
    if not id then return end
    local proc = TWAProcedures.List[id]
    if not proc then return end
    getSoundManager():playUISound("UISelectListItem")
    self.ui:onProcedureCellClicked(id, proc)
end

-- Tag-based tools have no single real item to name (any hammer-tagged item
-- works) -- this is every ItemTag member this mod's procedures actually use
-- (see HARMONIE_TWA_Procedures.lua's own real-API verification note), so a
-- small fixed label table covers every case without guessing further.
local TOOL_TAG_LABELS = {
    HAMMER = "IGUI_TWA_Tool_Hammer",
    SAW = "IGUI_TWA_Tool_Saw",
    WRENCH = "IGUI_TWA_Tool_Wrench",
    WELDING_MASK = "IGUI_TWA_Tool_WeldingMask",
    SCREWDRIVER = "IGUI_TWA_Tool_Screwdriver",
    CLUB_HAMMER = "IGUI_TWA_Tool_ClubHammer",
    SLEDGEHAMMER = "IGUI_TWA_Tool_Sledgehammer",
    STONE_MAUL = "IGUI_TWA_Tool_StoneMaul",
    PIPE_WRENCH = "IGUI_TWA_Tool_PipeWrench",
    SHARP_KNIFE = "IGUI_TWA_Tool_SharpKnife",
    PICK_AXE = "IGUI_TWA_Tool_PickAxe",
}

-- `spec` is either a single tool spec `{kind=.., value=..}` or a LIST of
-- alternative specs (request 2026-09-26: "some procedures can use several
-- different tools") -- names every alternative, joined with " / ".
local function toolSpecName(spec)
    local specs = TWAProcedures.ToolAlts(spec)
    local names = {}
    for _, s in ipairs(specs) do
        if s.kind == "type" then
            local it = getItemScript(s.value)
            names[#names + 1] = it and it:getDisplayName() or s.value
        elseif s.kind == "tag" then
            local key = TOOL_TAG_LABELS[s.value]
            names[#names + 1] = key and getText(key) or s.value
        end
    end
    return #names > 0 and table.concat(names, " / ") or "?"
end

-- *** REAL BUG FIXED (2026-09-26, console warning
-- "Translator.reportMissingArgumentsFromPastAbuse ... Missing arguments for
-- IGUI_TWA_OrOtherVariants"): the translation string had a bare Java-style
-- "%d" in it, but PZ's own getText() placeholder syntax is "%1"/"%2" (its
-- own positional-arg convention, confirmed from real vanilla translation
-- strings, e.g. "Suspicion points: %1") -- AND getText() was being called
-- with no extra args at all, then `string.format` applied to the RESULT
-- afterward, so getText() itself already tried (and failed) to format the
-- lone unconsumed "%d" internally before this code ever ran string.format.
-- Fixed properly, not by patching the placeholder: request 2026-09-26 also
-- asked for the "other materials work too" case to be clearer than a bare
-- count, so every alternative is just named directly instead, with no
-- format-string indirection needed at all. ***
-- `itemTypes` is a list of alternative real fullTypes for one consume slot
-- -- names every alternative, joined with " / ", exactly like toolSpecName.
local function consumeSpecName(itemTypes)
    local names = {}
    for _, t in ipairs(itemTypes) do
        local it = getItemScript(t)
        names[#names + 1] = it and it:getDisplayName() or t
    end
    return table.concat(names, " / ")
end

-- Request 2026-09-27: skill requirements were showing the raw internal Perk
-- identifier (e.g. "Blacksmith") untranslated, always in English regardless
-- of the player's language. Every one of this mod's skill names IS a real
-- vanilla Perk, and vanilla already ships its own real translated name for
-- every one of them under "IGUI_perks_<PerkName>" (confirmed real, e.g.
-- IGUI_perks_Blacksmith/Carving/Maintenance/Mechanics -- same key the
-- user's own in-game skill panel uses), so this just reuses that directly
-- instead of inventing new duplicate keys.
local function skillDisplayName(skillName)
    return getText("IGUI_perks_" .. skillName)
end

-- Request 2026-09-27: "หลอมโลหะ...แต่ละประเภทก็มีจำนวนที่ใช้ต่างกัน" -- a
-- consume slot needing ONE of several real materials, each with its OWN
-- quantity (see the `options` shape in HARMONIE_TWA_Procedures.lua).
local function optionsSpecName(options)
    local names = {}
    for _, opt in ipairs(options) do
        local it = getItemScript(opt.itemType)
        local name = it and it:getDisplayName() or opt.itemType
        names[#names + 1] = name .. " x" .. opt.qty
    end
    return table.concat(names, " / ")
end

-- request 2026-09-27: "เตาตีเหล็กดั้งเดิมหรือดีกว่า / ธรรมดาหรือดีกว่า /
-- ขั้นสูง" -- real vanilla forge-tier wording, see
-- HARMONIE_TWA_Procedures.lua's nearbyForgeTier() for the real Tags this
-- maps to (PrimitiveForge/Forge/AdvancedForge).
local FORGE_TIER_KEYS = {
    [1] = "IGUI_TWA_ReqForgePrimitive",
    [2] = "IGUI_TWA_ReqForgeNormal",
    [3] = "IGUI_TWA_ReqForgeAdvanced",
}

function TWAProcScrollList:describeMissing(missing)
    local lines = {}
    for _, m in ipairs(missing) do
        if m.kind == "light" then
            lines[#lines + 1] = getText("IGUI_TWA_MissingLight")
        elseif m.kind == "tool" then
            lines[#lines + 1] = getText("IGUI_TWA_MissingTool") .. ": " .. toolSpecName(m.spec)
        elseif m.kind == "consume" then
            local name = consumeSpecName(m.itemTypes)
            lines[#lines + 1] = getText("IGUI_TWA_MissingItem") .. " " .. name .. " x" .. m.qty .. " (" .. m.have .. "/" .. m.qty .. ")"
        elseif m.kind == "consume_options" then
            lines[#lines + 1] = getText("IGUI_TWA_MissingItem") .. " " .. optionsSpecName(m.options)
        elseif m.kind == "skill" then
            lines[#lines + 1] = getText("IGUI_TWA_MissingSkill") .. " " .. skillDisplayName(m.skill) .. " " .. m.level
        elseif m.kind == "forge" then
            lines[#lines + 1] = getText(FORGE_TIER_KEYS[m.tier])
        end
    end
    return lines
end

-- Same text as describeMissing's per-kind formatting, but for ANY single
-- requirement regardless of met/unmet (no "Missing"/"Requires" framing,
-- since the caller colors met vs unmet lines itself -- see
-- TWACraftWindow:drawProcedureDetails).
function TWAProcScrollList:describeOne(req)
    if req.kind == "light" then
        return getText("IGUI_TWA_ReqLight")
    elseif req.kind == "tool" then
        return getText("IGUI_TWA_ReqTool") .. ": " .. toolSpecName(req.spec)
    elseif req.kind == "consume" then
        local name = consumeSpecName(req.itemTypes)
        return name .. " x" .. req.qty .. " (" .. req.have .. "/" .. req.qty .. ")"
    elseif req.kind == "consume_options" then
        return optionsSpecName(req.options)
    elseif req.kind == "skill" then
        return getText("IGUI_TWA_ReqSkill") .. ": " .. skillDisplayName(req.skill) .. " " .. req.level
    elseif req.kind == "forge" then
        return getText(FORGE_TIER_KEYS[req.tier])
    end
    return "?"
end

function TWAProcScrollList:getProcTexture(proc)
    local tex
    if proc.icon then tex = getItemTexture(proc.icon) end
    if not tex and proc.consumes and proc.consumes[1] then
        local it = getItemScript(proc.consumes[1].itemType)
        tex = it and getItemTexture(it:getIcon())
    end
    return tex
end

function TWAProcScrollList:doDrawItem(y, entry, alt)
    if entry.item.header then
        local h = entry.height or self.headerHeight
        self:drawRect(0, y, self:getWidth(), h, 0.9, 0.16, 0.13, 0.1)
        self:drawRectBorder(0, y, self:getWidth(), h, 0.5, 0.5, 0.4, 0.3)
        drawTextShadowed(self, getText(entry.item.header), self.cellPad, y + 3, 0.9, 0.75, 0.4, 1, UIFont.Small)
        return y + h
    end
    local ids = entry.item.row
    local h = entry.height or self.itemheight
    local hoveredRow = self.mouseoverselected == entry.index
    local cs, gap, pad = self.cellSize, self.cellGap, self.cellPad
    local px = pad
    for col, id in ipairs(ids) do
        local proc = TWAProcedures.List[id]
        if proc then
            local met = TWAProcedures.CheckEligibility(proc, getPlayer())
            -- "Done" (the checkmark) only means this exact procedure was
            -- actually performed as part of the CURRENTLY selected recipe --
            -- not merely that its requirements are currently met (bug report
            -- 2026-09-26: the checkmark used to show for every eligible
            -- procedure, done or not, which is misleading since an eligible-
            -- but-undone procedure can still be re-attempted while an
            -- already-done one for this recipe cannot).
            local done = self.ui and self.ui.selectedRecipe and self.ui:currentDone()[id] or false
            local selected = self.ui and self.ui.selectedProcId == id
            local hovered = hoveredRow and self.hoverCol == col
            drawNeatCard(self, px, y, cs, cs, met, selected, hovered)
            local tex = self:getProcTexture(proc)
            local tint = met and 1 or 0.4
            if tex then
                self:drawTextureScaled(tex, px + 6, y + 6, cs - 12, cs - 12, 1, tint, tint, tint)
            end
            if done then drawCheckBadge(self, px, y, cs) end
            -- Hover shows ONLY the procedure's name (request 2026-09-26) --
            -- the full requirement breakdown moved to the fixed details box
            -- below this grid, populated on click instead of on hover.
            if hovered and self.ui then
                -- Bug report 2026-09-27: "tooltip...ไม่อยู่ตรงเมาส์ชี้ เวลา
                -- เลื่อน scroll bar แล้วบัค" -- `y` here is this row's
                -- CONTENT-space position inside the scroll list (see
                -- ISScrollingListBox.lua's own prerender loop: `local y = 0`
                -- incremented per row, never itself scroll-adjusted --
                -- individual item draws made from inside this widget get an
                -- automatic +yScroll shift applied by the engine, which is
                -- exactly why the background fill has to draw at
                -- `-self:getYScroll()` to CANCEL that and stay pinned). This
                -- tooltip is drawn by a DIFFERENT widget (self.ui, the
                -- window, which has no scroll of its own), so that automatic
                -- shift never applies to it -- it has to be added by hand,
                -- or the tooltip drifts away from the actually-hovered cell
                -- by exactly the current scroll offset.
                self.ui.hoverTooltip = {
                    lines = { getText(proc.nameKey) },
                    x = self:getAbsoluteX() - self.ui:getAbsoluteX() + px,
                    y = self:getAbsoluteY() - self.ui:getAbsoluteY() + y + self:getYScroll(),
                }
            end
        end
        px = px + cs + gap
    end
    return y + h
end

-- Main window -----------------------------------------------------------------

TWACraftWindow = ISCollapsableWindow:derive("TWACraftWindow")

function TWACraftWindow:new(x, y, player)
    local o = ISCollapsableWindow:new(x, y, WINDOW_W, WINDOW_H)
    setmetatable(o, self)
    self.__index = self
    o.player = player or getPlayer()
    o.selectedRecipe = nil
    -- Keyed by recipe.id, NOT reset on every selection (request 2026-09-27:
    -- "ถ้าหากทำกรรมวิธีไปแล้ว แต่กดยกเลิกสูตร ควรทำยังไงดีกับกรรมวิธีที่ทำ
    -- ไปแล้ว") -- their materials are already spent either way (Consume()
    -- runs at procedure completion, never refunded), so wiping the DONE
    -- STATUS too on a plain Cancel would force redoing -- and re-spending
    -- fresh materials on -- a step that's already legitimately finished.
    -- Only cleared when that specific recipe is actually finished (see
    -- onFinish), so crafting a second copy of the same weapon later starts
    -- clean.
    o.progress = {}
    -- Request 2026-09-27 (multiplayer collaborative crafting): set only by
    -- resumeFromItem(), when this window was opened by right-clicking a
    -- base item that was previously bookmarked via the Incomplete button
    -- (its progress written straight into ITS OWN ModData, not this window's
    -- session state -- see onIncomplete). While set, currentDone() reads/
    -- writes straight into that item's ModData instead of self.progress.
    o.resumeItem = nil
    o.selectedProcId = nil
    o.activeProcId = nil
    o.activeAction = nil
    o.resizable = false
    o.title = getText("IGUI_TWA_CraftWindowTitle")
    return o
end

function TWACraftWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local leftX = 10
    local centerX = leftX + LEFT_W + COL_GAP
    local rightX = centerX + CENTER_W + COL_GAP
    local titleH = self:titleBarHeight()
    local contentTop = titleH + 8
    local panelBottom = contentTop + PANEL_H

    -- Filter tabs (wrap over rows as needed), directly under the title bar.
    -- Each row gets a small caption above it (drawn in render(), using the Y
    -- stored here) so it's clear at a glance which row filters by category
    -- and which by rarity (request 2026-09-26: "arrange the filter section
    -- to look nicer").
    -- Bug report 2026-09-27: "คำว่าหมวดหมู่ และระดับความหายาก อยู่ต่ำไปนิดนึง
    -- มันเลยไปบัง filter" -- UIFont.Small's real rendered height leaves only
    -- ~2px of clearance at 14, so the caption's own text bottom edge
    -- overlapped the button row starting right under it. Bumped to 18.
    local captionH = 18
    self.filterButtons = {}
    self.categoryRowY = contentTop
    local fx, fy = leftX, contentTop + captionH
    for _, tab in ipairs(CATEGORY_TABS) do
        local label = tab.label
        local w = getTextManager():MeasureStringX(UIFont.Small, label) + 20
        if fx + w > leftX + LEFT_W then
            fx = leftX
            fy = fy + 26
        end
        local btn = TWATabButton:new(fx, fy, w, 24, label, self, TWACraftWindow.onFilterClick)
        btn.internal = tab.key
        -- Note 2026-09-27: "เขียนหมายเหตุไว้ด้วยตามปุ่มต่างๆ" -- "Available"
        -- isn't self-explanatory from its label alone (unlike a category
        -- name), so it gets a real tooltip explaining what it filters by.
        if tab.key == "Available" then
            btn:setTooltip(getText("IGUI_TWA_Tooltip_FilterAvailable"))
        end
        btn:initialise()
        self:addChild(btn)
        self.filterButtons[#self.filterButtons + 1] = btn
        fx = fx + w + 5
    end
    fy = fy + 26

    -- Tier filter row (request 2026-09-26: "filter by tier too"), a second
    -- independent row of tabs under the category ones -- both apply
    -- together (AND), matching how "Available" already combines with a
    -- category pick. Extra gap + its own caption separates it visually from
    -- the category row above instead of the two blocks running together.
    fy = fy + 8
    self.tierRowY = fy
    fy = fy + captionH
    self.tierFilterButtons = {}
    local tfx = leftX
    for _, tab in ipairs(TIER_TABS) do
        local label = tab.label or getText(tab.labelKey)
        local w = getTextManager():MeasureStringX(UIFont.Small, label) + 20
        if tfx + w > leftX + LEFT_W then
            tfx = leftX
            fy = fy + 26
        end
        local btn = TWATierTabButton:new(tfx, fy, w, 24, label, self, TWACraftWindow.onTierFilterClick)
        btn.internal = tab.key
        if type(tab.key) == "number" and TIER_INFO[tab.key] then
            local c = TIER_INFO[tab.key]
            btn.neatTint = { r = c.r, g = c.g, b = c.b }
        end
        btn:initialise()
        self:addChild(btn)
        self.tierFilterButtons[#self.tierFilterButtons + 1] = btn
        tfx = tfx + w + 5
    end
    local searchY = fy + 30

    -- Search box + an explicit Search button beside it (request 2026-09-28:
    -- "มีปุ่มกดค้นหาในช่องค้นหาทางซ้าย") -- the box already searches live as
    -- you type (onTextChange below, unchanged), so this button is a
    -- redundant-but-explicit way to trigger the exact same search -- plain
    -- text, no icon, matching the "no icon" preference from the other
    -- search button just above.
    local searchBtnW = 60
    self.searchBox = ISTextEntryBox:new("", leftX, searchY, LEFT_W - searchBtnW - 5, 24)
    self.searchBox:initialise()
    self.searchBox:setPlaceholderText(getText("IGUI_TWA_SearchPlaceholder"))
    local window = self
    self.searchBox.onTextChange = function(box) window.recipeList:setSearch(box:getText()) end
    self:addChild(self.searchBox)

    self.searchButton = TWANeatButton:new(leftX + LEFT_W - searchBtnW, searchY, searchBtnW, 24, getText("IGUI_TWA_FindRecipes"), self, TWACraftWindow.onSearchButtonClicked)
    self.searchButton:initialise()
    self:addChild(self.searchButton)

    -- Recipe list (fills the rest of the left column down to the same bottom
    -- edge the center/right panels use).
    local listY = searchY + 30
    self.recipeList = TWARecipeScrollList:new(leftX, listY, LEFT_W, panelBottom - listY, self)
    self.recipeList:initialise()
    self:addChild(self.recipeList)
    self.recipeList:refresh()

    -- Procedure library: icon grid on top, fixed (non-scrolling) requirement
    -- details box for the clicked procedure underneath it (request
    -- 2026-09-26 -- replaces the old floating full-requirements tooltip).
    -- Bug report 2026-09-27: "มันไม่ขึ้นว่าต้องการสกิลอะไรเหมือนกรรมวิธี
    -- อื่นๆ" -- real cause found: at the old detailsH=150, only ~4 req lines
    -- fit before the requirement loop's own `if ty > textBottom then break`
    -- cutoff. DescribeAll always orders light, tool, tool2, consume, skill,
    -- forge -- so any procedure needing BOTH tool AND tool2 AND a consumed
    -- material (WeldMetal/WeldWork/WeldWorkComplex: WELDING_MASK + BlowTorch
    -- + ScrapMetal) already used all 4 slots on light+tool+tool2+consume,
    -- silently pushing skill (5th) past the cutoff -- not a welding-specific
    -- bug, just the first procedures to actually hit this space shortage.
    -- Bumped 150 -> 190 so 7 lines fit, covering even the heaviest real case
    -- (light+tool+tool2+consume+skill+forge = 6) with a line of headroom for
    -- word-wrap. Costs the scrollable procedure grid above ~1 visible row
    -- (gridH shrinks by the same 40px) -- a minor, purely cosmetic tradeoff
    -- since that grid already scrolls.
    local detailsH = 190
    local gridH = PANEL_H - detailsH - 8
    self.procLibrary = TWAProcScrollList:new(rightX, contentTop, RIGHT_W, gridH, self)
    self.procLibrary:initialise()
    self:addChild(self.procLibrary)
    self.procLibrary:populate()
    self.procDetailsY = contentTop + gridH + 8
    self.procDetailsH = detailsH

    -- Cancel / Incomplete / Finish buttons (center panel bottom). Incomplete
    -- (request 2026-09-27, multiplayer collaborative crafting) is the new
    -- middle button -- bookmarks whatever progress has been made so far
    -- straight onto the recipe's own base item's ModData (see onIncomplete),
    -- so someone else (or the same player later) can pick up that exact item
    -- and keep going. 3-way split of the same row Cancel/Finish already used.
    local btnW, btnH = (CENTER_W - 20) / 3, 30
    self.cancelButton = TWANeatButton:new(centerX, panelBottom - btnH, btnW, btnH, getText("IGUI_TWA_Cancel"), self, TWACraftWindow.onCancel)
    self.cancelButton:setTooltip(getText("IGUI_TWA_Tooltip_Cancel"))
    self.cancelButton:initialise()
    self:addChild(self.cancelButton)

    self.incompleteButton = TWANeatButton:new(centerX + btnW + 10, panelBottom - btnH, btnW, btnH, getText("IGUI_TWA_Incomplete"), self, TWACraftWindow.onIncomplete)
    self.incompleteButton.neatTint = { r = 0.55, g = 0.6, b = 0.95 }
    self.incompleteButton:setTooltip(getText("IGUI_TWA_Tooltip_Incomplete"))
    self.incompleteButton:initialise()
    self:addChild(self.incompleteButton)

    self.finishButton = TWANeatButton:new(centerX + 2 * (btnW + 10), panelBottom - btnH, btnW, btnH, getText("IGUI_TWA_Finish"), self, TWACraftWindow.onFinish)
    self.finishButton.neatTint = { r = 1, g = 0.55, b = 0.15 }
    self.finishButton:setTooltip(getText("IGUI_TWA_Tooltip_Finish"))
    self.finishButton:initialise()
    self:addChild(self.finishButton)

    -- Confirm / Cancel buttons for the selected procedure (request
    -- 2026-09-26: "performing a procedure needs a confirm button first, and
    -- a cancel button while it's in progress" -- clicking a grid icon only
    -- SELECTS it now, see onProcedureCellClicked; these two buttons, drawn
    -- in the same spot and toggled mutually exclusive every frame in
    -- drawProcedureDetails, are the only way to actually start/stop one).
    local procBtnH = 26
    local procBtnY = self.procDetailsY + detailsH - procBtnH - 8
    self.procConfirmButton = TWANeatButton:new(rightX + 10, procBtnY, RIGHT_W - 20, procBtnH, getText("IGUI_TWA_ConfirmProcedure"), self, TWACraftWindow.onConfirmProcedure)
    self.procConfirmButton.neatTint = { r = 1, g = 0.55, b = 0.15 }
    self.procConfirmButton:setTooltip(getText("IGUI_TWA_Tooltip_ConfirmProcedure"))
    self.procConfirmButton:initialise()
    self:addChild(self.procConfirmButton)

    self.procCancelButton = TWANeatButton:new(rightX + 10, procBtnY, RIGHT_W - 20, procBtnH, getText("IGUI_TWA_CancelProcedure"), self, TWACraftWindow.onCancelProcedure)
    self.procCancelButton.neatTint = { r = 0.9, g = 0.3, b = 0.25 }
    self.procCancelButton:setTooltip(getText("IGUI_TWA_Tooltip_CancelProcedure"))
    self.procCancelButton:initialise()
    self:addChild(self.procCancelButton)
    self.procBtnY = procBtnY

    -- "Find recipes" button (request 2026-09-27; request 2026-09-28: "รูปปุ่ม
    -- ค้นหา...ไม่สวย ไม่ต้องมีรูปก็ได้" -- dropped the magnifying-glass icon
    -- entirely in favor of a plain text button, the same TWANeatButton style
    -- every other button in this UI already uses) -- top-right corner of the
    -- procedure details box, beside its name line. Only meaningful once a
    -- procedure is actually selected there -- visibility toggled in
    -- drawProcedureDetails() the same way procConfirmButton/procCancelButton
    -- already are.
    self.procSearchButton = TWANeatButton:new(rightX + RIGHT_W - 70, self.procDetailsY + 6, 60, 22, getText("IGUI_TWA_FindRecipes"), self, TWACraftWindow.onSearchByProcedure)
    self.procSearchButton:setTooltip(getText("IGUI_TWA_Tooltip_FindRecipesForProcedure"))
    self.procSearchButton:initialise()
    self:addChild(self.procSearchButton)

    self.centerX = centerX
    self.contentTop = contentTop
    self.rightX = rightX
    self.panelBottom = panelBottom
    self.btnH = btnH
end

function TWACraftWindow:onFilterClick(button)
    self.recipeList:setFilter(button.internal)
end

function TWACraftWindow:onTierFilterClick(button)
    self.recipeList:setTierFilter(button.internal)
end

-- Returns THIS recipe's own persistent done-table (lazily created), never a
-- shared/reset one -- see the o.progress comment in :new() above.
--
-- Request 2026-09-27 (multiplayer collaborative crafting): when
-- self.resumeItem is set, progress lives DIRECTLY on that physical item's
-- own ModData instead of self.progress -- keyed by recipe.id the way
-- self.progress always has been would break the moment two different
-- physical half-finished copies of the SAME recipe exist at once (one
-- player's "take it out early" copy sitting in a chest while a second copy
-- is independently being started fresh) -- both would collide on the same
-- self.progress[id] slot. Reading/writing the item's own ModData table
-- keeps each physical item's progress correctly separate, and doubles as the
-- persistence itself: performing a procedure while resumed immediately
-- updates the real item, so there's no separate "save" step and nothing is
-- lost if the window is just closed without finishing again.
function TWACraftWindow:currentDone()
    if not self.selectedRecipe then return {} end
    if self.resumeItem then
        local md = self.resumeItem:getModData()
        md.TWA_DoneProcedures = md.TWA_DoneProcedures or {}
        return md.TWA_DoneProcedures
    end
    local id = self.selectedRecipe.id
    self.progress[id] = self.progress[id] or {}
    return self.progress[id]
end

-- Request 2026-09-27: reconnects this window to a physical BASE item that
-- was previously bookmarked via the Incomplete button (see onIncomplete
-- below) -- called from TWACraftUI.open() when the context menu that opened
-- it was a right-click on that exact item. Reads the recipe id + saved
-- progress straight off the item's own ModData (real per-item store,
-- network-synced -- same real mechanism vanilla itself relies on for any
-- per-item ModData to matter across clients at all, not a new assumption).
function TWACraftWindow:resumeFromItem(item)
    if self.activeProcId then return end
    local recipeId = item:getModData().TWA_RecipeId
    local recipe = recipeId and getRecipeById(recipeId)
    if not recipe then return end
    self.selectedRecipe = recipe
    self.resumeItem = item
    self.selectedProcId = nil
    self.searchBox:setText("")
    self.recipeList:setSearch("")
end

-- Recipe switching/backing out no longer touches progress at all (see
-- :currentDone()) -- blocked here only while a procedure is actively being
-- performed, purely so the right-panel "in progress" bar/button state
-- always reads against the recipe it actually belongs to; the timed action
-- itself now always credits the CORRECT recipe's table regardless (its
-- completion callback captures that table directly -- see
-- tryPerformProcedure), so this is a UX guard, not a correctness one.
function TWACraftWindow:selectRecipe(recipe)
    if self.activeProcId then return end
    self.selectedRecipe = recipe
    -- Manually picking a (possibly different) recipe from the list always
    -- detaches any resume link -- the item that was being resumed keeps
    -- whatever progress it already has saved on it either way (currentDone()
    -- writes straight into its ModData, never into self.progress), so
    -- nothing is lost, this only stops crediting THIS window's future clicks
    -- to that specific physical item.
    self.resumeItem = nil
end

function TWACraftWindow:onCancel()
    if self.activeProcId then return end
    self.selectedRecipe = nil
    self.resumeItem = nil
end

-- Base/base2 are NEVER pre-consumed any more (request 2026-09-28 corrected
-- the earlier design -- see onIncomplete below), so ownership is always
-- re-checked here the same way regardless of whether this recipe is being
-- resumed from a bookmarked base item or started completely fresh.
function TWACraftWindow:allProceduresDone()
    if not self.selectedRecipe then return false end
    if not ownsBase(self.selectedRecipe, self.player) then return false end
    local doneTable = self:currentDone()
    for _, procId in ipairs(self.selectedRecipe.procedures) do
        if not doneTable[procId] then return false end
    end
    return true
end

function TWACraftWindow:onFinish()
    if not self:allProceduresDone() then return end
    ISTimedActionQueue.add(TWA_FinishCraftAction:new(self.player, self.selectedRecipe, self:currentDone()))
    -- Cleared so crafting a SECOND copy of this same recipe later (once you
    -- have another base item) starts with nothing pre-marked done -- the
    -- queued finish action already holds its own reference to the table
    -- as it stands right now, so this doesn't affect it. When resuming a
    -- bookmarked base item, Finish consumes it (removeOneOf, in
    -- TWA_FinishCraftAction.lua) same as any other base item -- its
    -- TWA_RecipeId/TWA_DoneProcedures ModData simply ceases to exist along
    -- with the item, nothing needs to be manually cleared.
    self.progress[self.selectedRecipe.id] = nil
    self.selectedRecipe = nil
    self.resumeItem = nil
end

-- Request 2026-09-27 (corrected 2026-09-28 -- "ตอนกดปุ่มไม่สมบูรณ์ ให้ออกมา
-- เป็นชิ้นส่วนตั้งต้น...จริงๆใช่ไหม" -- shouldn't the Incomplete button leave
-- the BASE item as-is instead of spawning the finished result early?): does
-- NOT consume anything or spawn anything -- it just writes the current
-- procedure progress straight into the recipe's own base item's ModData
-- (TWA_RecipeId + a snapshot of done procedures), so someone (the same
-- player later, or someone else in MP) can right-click that SAME physical
-- base item to resume exactly where it was left off. Base2 (when present)
-- is intentionally left untagged and untouched -- it's just an ordinary
-- required material like always, re-checked at Finish the normal way
-- (ownsBase); only ONE item needs to carry the bookmark, and tagging just
-- the primary base avoids 2 separate copies of the same progress data
-- silently drifting out of sync with each other if they ever get separated.
-- No timed action needed -- nothing physically changes hands or transforms,
-- it's a pure metadata write, so this runs instantly instead of queuing.
function TWACraftWindow:canGoIncomplete()
    if not self.selectedRecipe or self.resumeItem or self.activeProcId then return false end
    local recipe = self.selectedRecipe
    if not recipe.base then return false end
    return self.player:getInventory():getItemCountRecurse(recipe.base) >= 1
end

function TWACraftWindow:onIncomplete()
    if not self:canGoIncomplete() then return end
    local recipe = self.selectedRecipe
    local inv = self.player:getInventory()
    local baseItem = inv:getFirstTypeEvalRecurse(recipe.base, function() return true end)
    if not baseItem then return end

    local snapshot = {}
    for procId, done in pairs(self:currentDone()) do
        if done then snapshot[procId] = true end
    end
    local md = baseItem:getModData()
    md.TWA_RecipeId = recipe.id
    md.TWA_DoneProcedures = snapshot

    getSoundManager():playUISound("UISelectListItem")
    self.progress[recipe.id] = nil
    self.selectedRecipe = nil
end

-- Shared by the search box's own typing handler and anything else that wants
-- to programmatically set the search (context-menu auto-search on open, and
-- the procedure-details magnifying-glass button below).
function TWACraftWindow:applySearch(text)
    self.searchBox:setText(text or "")
    self.recipeList:setSearch(text or "")
end

-- Request 2026-09-27: "เพิ่มปุ่มแว่นขยายในรายละเอียดกรรมวิธี...ไป search
-- สูตรอาวุธที่ต้องทำกรรมวิธีนั้นๆ" -- reuses the exact same search mechanism
-- as typing in the box, just pre-filled with the selected procedure's own
-- translated name (which the extended TWARecipeScrollList:matches now also
-- checks against every recipe's procedure list) -- no separate filter code
-- path needed. Also resets both filter-tab rows to "All" first, so an
-- active category/tier/Available filter never silently hides a real match.
function TWACraftWindow:onSearchByProcedure()
    if not self.selectedProcId then return end
    local proc = TWAProcedures.List[self.selectedProcId]
    if not proc then return end
    self.recipeList:setFilter("All")
    self.recipeList:setTierFilter("All")
    self:applySearch(getText(proc.nameKey))
end

-- Explicit Search button beside the left search box (request 2026-09-28) --
-- the box already searches live as you type via its own onTextChange, so
-- this just re-applies whatever text is currently in it; harmless to press
-- any time, including with an empty/unchanged box.
function TWACraftWindow:onSearchButtonClicked()
    self.recipeList:setSearch(self.searchBox:getText())
end

-- Performing a procedure is now a real queued timed action (request
-- 2026-09-26: "give it a button + real time + sound + XP like vanilla
-- crafting"), not an instant click -- see TWA_PerformProcedureAction.lua.
-- Only one procedure can be in progress at once per window; `onEnd` clears
-- `activeProcId`/`activeAction` whether the action finished OR was
-- cancelled/interrupted (walking away, etc.), so a cancelled attempt never
-- permanently blocks starting another one.
function TWACraftWindow:tryPerformProcedure(procId, proc)
    if not self.selectedRecipe then return end
    if self.activeProcId then return end
    local needed = false
    for _, pid in ipairs(self.selectedRecipe.procedures) do
        if pid == procId then needed = true break end
    end
    -- Captured directly (not looked up again inside the callback) so
    -- completion always credits THIS recipe's table, even if the player
    -- has switched to a different recipe by the time it finishes.
    local doneTable = self:currentDone()
    if not needed or doneTable[procId] then return end
    if not TWAProcedures.CheckEligibility(proc, self.player) then return end

    self.activeProcId = procId
    local window = self
    local action = TWA_PerformProcedureAction:new(self.player, proc,
        function() doneTable[procId] = true end,
        function()
            if window.activeProcId == procId then
                window.activeProcId = nil
                window.activeAction = nil
            end
        end)
    self.activeAction = action
    ISTimedActionQueue.add(action)
end

-- Clicking an icon in the procedure-library grid only SELECTS it now
-- (request 2026-09-26: "performing a procedure needs a confirm button
-- first") -- its full requirement breakdown shows in the fixed details box
-- below the grid, with a Confirm button to actually start it (see
-- onConfirmProcedure) and a Cancel button once it's in progress (see
-- onCancelProcedure).
function TWACraftWindow:onProcedureCellClicked(procId)
    self.selectedProcId = procId
end

function TWACraftWindow:onConfirmProcedure()
    if not self.selectedProcId then return end
    local proc = TWAProcedures.List[self.selectedProcId]
    if not proc then return end
    self:tryPerformProcedure(self.selectedProcId, proc)
end

function TWACraftWindow:onCancelProcedure()
    if self.activeAction then
        self.activeAction:forceStop()
    end
end

function TWACraftWindow:drawHoverTooltip()
    -- Drawn from one-frame-delayed data handed up by TWAProcScrollList:
    -- doDrawItem() (procedure library hover) or this window's own render()
    -- (required-procedure checklist hover) -- reset right after so it only
    -- stays alive by being set again on the next frame.
    local tip = self.hoverTooltip
    self.hoverTooltip = nil
    if not tip then return end

    local tw, th = 0, #tip.lines * 16 + 8
    for _, l in ipairs(tip.lines) do
        tw = math.max(tw, getTextManager():MeasureStringX(UIFont.Small, l))
    end
    tw = tw + 12
    -- Prefer drawing to the LEFT of the procedure button (toward the center
    -- panel) so the tooltip stays inside the window instead of running off
    -- its right edge; fall back to the right if that would run off the left.
    local tx = tip.x - tw - 8
    if tx < 0 then tx = tip.x + 40 end
    local ty = math.max(0, math.min(tip.y, self.height - th))

    self:drawRect(tx, ty, tw, th, 0.95, 0, 0, 0)
    self:drawRectBorder(tx, ty, tw, th, 1, 0.6, 0.6, 0.6)
    for i, l in ipairs(tip.lines) do
        self:drawText(l, tx + 6, ty + 4 + (i - 1) * 16, 1, 0.6, 0.6, 1, UIFont.Small)
    end
end

-- 2-column stat grid shown in the center panel (request 2026-09-26: "show
-- every stat, organized, easy to read", then reorganized + extended same
-- day: "track เพิ่มแสดงในหน้า ui คราฟตรงกลาง...จัดเรียงให้มีระเบียบ").
-- Each cell is {key, labelKey, fmt, always, default, derive}; `derive(stats)`
-- (when set) computes the display value instead of a plain `stats[key]`
-- lookup -- used for the two boolean/enum-derived cells below. Grouped by
-- subject: damage, combat effects, mobility, durability, physical, style --
-- `Categories` is intentionally NOT here (request: "หมวดหมู่ให้เอาไปไว้
-- ข้างๆ tier" -- put it next to the tier label instead, see the center-
-- panel render() call site below).
local HANDEDNESS_LABELS = { [true] = "IGUI_TWA_Stat_TwoHanded", [false] = "IGUI_TWA_Stat_OneHanded" }
-- Reordered 2026-09-27 to the exact sequence requested ("stats layout เดิม
-- แต่เรียงตามลำดับดังนี้ ดาเมจต่ำสุด ดาเมจสูงสุด ความเร็วโจมตี น้ำหนัก
-- ระยะโจมตี โอกาสคริติคอล ทนทาน สึกหรอ ล้มคว่ำ แรงผลัก การถือ รูปแบบ") --
-- same 2-column-per-row layout/cell definitions as before (fmt/always/
-- default/derive all unchanged), just filled into that order 2-at-a-time.
-- DPS kept as its own standalone row at the top, same as before -- it
-- wasn't named in the list, but nothing said to remove it either, and it's
-- the one stat everything else here explains (drives the whole tier
-- system) -- flag if you actually wanted it dropped.
local STAT_GRID = {
    { { key = "dps", labelKey = "IGUI_TWA_Stat_DPS", fmt = "%.2f", always = true } },
    { { key = "minDamage", labelKey = "IGUI_TWA_Stat_MinDamage", fmt = "%.1f" },
      { key = "maxDamage", labelKey = "IGUI_TWA_Stat_MaxDamage", fmt = "%.1f" } },
    -- `always = true` (request 2026-09-26: "always show attack speed") --
    -- shown even when the baked value is missing. `default = 1.0` (request
    -- 2026-09-26: "ความเร็วโจมตีหากไม่มีให้ขึ้น 1.0 แทน" -- if missing, show
    -- 1.0 instead) -- a display/design decision, not a claim this is the
    -- real Java default (still unconfirmed, no decompiler available).
    { { key = "baseSpeed", labelKey = "IGUI_TWA_Stat_Speed", fmt = "%.2f", always = true, default = 1.0 },
      { key = "weight", labelKey = "IGUI_TWA_StatWeight", fmt = "%.1f" } },
    -- `always = true, default = 0` (request 2026-09-26: "ทำไมโอกาสคริติคอล
    -- ไม่ขึ้น" -- why doesn't crit% show) -- real cause found: some real
    -- items (e.g. roughneckgorillasledgehammer) genuinely leave
    -- CriticalChance blank in their own script, so it baked to nil and the
    -- row silently disappeared with no `always` flag -- same fix pattern
    -- as BaseSpeed's own missing-value default.
    { { key = "maxRange", labelKey = "IGUI_TWA_Stat_Range", fmt = "%.2f" },
      { key = "critChance", labelKey = "IGUI_TWA_Stat_CritChance", fmt = "%.0f%%", always = true, default = 0 } },
    { { key = "conditionMax", labelKey = "IGUI_TWA_Stat_Condition", fmt = "%.0f" },
      -- Real "wear rate" mechanic (request 2026-09-26, relabeled same day:
      -- "ความทนทาน เปลี่ยนเป็น สึกหรอ ค่าก็เป็น 1:40") -- a 1-in-X chance PER
      -- HIT to lose Condition, higher = wears out slower; a different real
      -- field from `conditionMax` (max condition capacity) just above.
      { key = "conditionLowerChanceOneIn", labelKey = "IGUI_TWA_Stat_Durability", fmt = "1:%.0f" } },
    { { key = "knockdownMod", labelKey = "IGUI_TWA_Stat_Knockdown", fmt = "%.1f" },
      -- Real "push power" stagger-distance stat (request 2026-09-26) --
      -- separate from `knockdownMod` (knockdown chance/strength) just left.
      { key = "pushBackMod", labelKey = "IGUI_TWA_Stat_PushPower", fmt = "%.2f" } },
    { { key = "twoHanded", labelKey = "IGUI_TWA_Stat_Handedness", fmt = "%s", always = true,
        derive = function(s) return HANDEDNESS_LABELS[s.twoHanded] and getText(HANDEDNESS_LABELS[s.twoHanded]) or nil end },
      -- Real field, but NOT "One-Handed/Two-Handed" as first assumed --
      -- its real values are Swinging/Stab/Spear/Firearm (attack style),
      -- grep-confirmed and corrected for the user when this was asked.
      { key = "subCategory", labelKey = "IGUI_TWA_Stat_AttackStyle", fmt = "%s",
        derive = function(s) return s.subCategory and s.subCategory ~= "" and s.subCategory or nil end } },
}

function TWACraftWindow:drawStatGrid(x, y, w)
    local recipe = self.selectedRecipe
    local stats = TWARecipeData.Stats[recipe.result]
    if not stats then return y end
    drawTextShadowed(self, getText("IGUI_TWA_StatsHeader"), x, y, 0.9, 0.75, 0.4, 1, UIFont.Small)
    y = y + 20
    local colW = w / 2
    for _, row in ipairs(STAT_GRID) do
        for col, cellDef in ipairs(row) do
            local v = cellDef.derive and cellDef.derive(stats) or stats[cellDef.key]
            if v ~= nil or cellDef.always then
                local cx = x + (col - 1) * colW
                local valueText = (v ~= nil) and string.format(cellDef.fmt, v)
                    or (cellDef.default and string.format(cellDef.fmt, cellDef.default))
                    or "-"
                drawTextShadowed(self, getText(cellDef.labelKey) .. ": " .. valueText, cx, y, 0.85, 0.85, 0.85, 1, UIFont.Small)
            end
        end
        y = y + 18
    end
    -- `DamageCategory` ("Slash") is NOT shown as its own stat -- verified
    -- against media/lua/shared/Definitions/DamageModelDefinitions.lua
    -- (question raised 2026-09-26: "what does this actually do, don't
    -- guess"). It is real, but purely cosmetic: it only picks which visual
    -- gore/wound texture gets stamped onto a zombie's torso/head on hit
    -- (ZedDmg_*_Slash textures vs the default), nothing else -- it does NOT
    -- affect damage, bleeding, or infection chance (the "Causes Bleeding"
    -- label this UI showed briefly was a wrong guess and has been removed).
    -- Not meaningful to a crafting decision, so it stays out of the grid.
    return y
end

-- request 2026-09-27: reintroduced a real 2nd required base-item card
-- (recipe.base2, tier-matched MaterialBar) -- factored the single-card draw
-- (previously inline) into its own method so it can be called once per
-- slot instead of duplicating the 8 draw calls.
function TWACraftWindow:drawBaseCard(x, y, w, fullType, altType, owned)
    local CARD_H = 40
    self:drawRect(x, y, w, CARD_H, 0.85, 0.08, 0.08, 0.09)
    self:drawRectBorder(x, y, w, CARD_H, 0.4, 0.4, 0.4, 0.4)
    if owned and TWA_NEAT.check then
        self:drawTextureScaled(TWA_NEAT.check, x + w - 24, y + 12, 16, 16, 1, 1, 1, 1)
    end
    drawTextShadowed(self, baseDisplayName(fullType, altType), x + 8, y + 5, 0.9, 0.9, 0.9, 1, UIFont.Small)
    local statusKey = owned and "IGUI_TWA_BaseItemOwned" or "IGUI_TWA_BaseItemMissing"
    drawTextShadowed(self, getText(statusKey), x + 8, y + 21, owned and 0.45 or 0.95, owned and 0.95 or 0.45, 0.45, 1, UIFont.Small)
    return y + CARD_H + 6 + 4
end

-- Fixed (non-scrolling) box under the procedure-library grid showing exactly
-- what the currently-selected (clicked) procedure needs -- replaces the old
-- floating full-requirements tooltip, which rendered underneath the grid's
-- own icons every other frame (the z-order bug from testing) since it drew
-- before those icons in the same render pass instead of after.
-- Bug report 2026-09-27: "ปุ่มกดทำกรรมวิธีมันอยู่หลัง background" -- the
-- procConfirmButton/procCancelButton are real child widgets, drawn by
-- ISCollapsableWindow.render(self) at the TOP of render(). drawProcedureDetails()
-- used to run AFTER that and started by painting a full-panel background
-- rect over the same area the buttons sit in, visually covering them (they
-- stayed clickable since hit-testing doesn't care about draw order, just
-- looked wrong). Fix: draw this backdrop BEFORE the buttons render, in its
-- own function called first in render(); everything else (status text,
-- requirement list, button visibility toggles) still runs after, same as
-- before, since none of it overlaps the buttons.
function TWACraftWindow:drawProcedureDetailsBackground()
    local x, y, w, h = self.rightX, self.procDetailsY, RIGHT_W, self.procDetailsH
    -- Flat fill only (see drawNeatCard's 2026-09-26 note above) -- NeatUI's
    -- InnerPanel_BG texture is too light-colored to sit safely under white/
    -- red text, so it's never used as a background here any more.
    self:drawRect(x, y, w, h, 0.9, 0.06, 0.06, 0.07)
    self:drawRectBorder(x, y, w, h, 0.6, 0.4, 0.4, 0.4)
end

function TWACraftWindow:drawProcedureDetails()
    local x, y, w = self.rightX, self.procDetailsY, RIGHT_W

    local proc = self.selectedProcId and TWAProcedures.List[self.selectedProcId]
    if not proc then
        drawTextShadowed(self, getText("IGUI_TWA_SelectProcedureFirst"), x + 10, y + 10, 0.7, 0.7, 0.7, 1, UIFont.Small)
        self.procConfirmButton:setVisible(false)
        self.procCancelButton:setVisible(false)
        self.procSearchButton:setVisible(false)
        return
    end
    self.procSearchButton:setVisible(true)

    local ty = y + 8
    drawTextShadowed(self, getText(proc.nameKey), x + 10, ty, 1, 0.9, 0.6, 1, UIFont.Medium)
    ty = ty + 22

    local done = self.selectedRecipe and self:currentDone()[self.selectedProcId]
    local inProgress = self.activeProcId == self.selectedProcId and self.activeAction
    local reqs = TWAProcedures.DescribeAll(proc, self.player)
    local met = true
    for _, r in ipairs(reqs) do if not r.met then met = false break end end
    local statusKey = inProgress and "IGUI_TWA_ProcedureInProgress" or (done and "IGUI_TWA_ProcedureDone" or (met and "IGUI_TWA_ProcedureReady" or "IGUI_TWA_ProcedureNotReady"))
    local statusColor = (done or met) and { r = 0.5, g = 0.9, b = 0.5 } or { r = 0.95, g = 0.45, b = 0.45 }
    if inProgress then statusColor = { r = 1, g = 0.8, b = 0.3 } end
    drawTextShadowed(self, getText(statusKey), x + 10, ty, statusColor.r, statusColor.g, statusColor.b, 1, UIFont.Small)
    ty = ty + 20

    -- Confirm/Cancel buttons (request 2026-09-26: "performing a procedure
    -- needs a confirm button first, and a cancel button while it's in
    -- progress") -- mutually exclusive, toggled here every frame since this
    -- is the one place that already knows the full current state.
    local belongsToRecipe = false
    if self.selectedRecipe then
        for _, pid in ipairs(self.selectedRecipe.procedures) do
            if pid == self.selectedProcId then belongsToRecipe = true break end
        end
    end
    self.procCancelButton:setVisible(inProgress and true or false)
    local canConfirm = belongsToRecipe and not done and not inProgress and not self.activeProcId
    self.procConfirmButton:setVisible(canConfirm)
    self.procConfirmButton.enable = canConfirm and met

    -- Progress bar while the timed action is actually running (request
    -- 2026-09-26: "show the time as a bar/circle in the UI") -- real
    -- progress fraction from `getJobDelta()`, the same value vanilla's own
    -- built-in action-progress bar reads (ISBaseTimedAction:getJobDelta()).
    if inProgress then
        local barW, barH = w - 20, 14
        local frac = self.activeAction:getJobDelta() or 0
        self:drawRect(x + 10, ty, barW, barH, 0.9, 0.05, 0.05, 0.05)
        self:drawRect(x + 10, ty, barW * math.max(0, math.min(1, frac)), barH, 1, 1, 0.7, 0.2)
        self:drawRectBorder(x + 10, ty, barW, barH, 0.8, 0.5, 0.5, 0.5)
        ty = ty + barH + 10
    end

    -- Every requirement stays listed regardless of overall status (bug
    -- report 2026-09-26: "once a procedure becomes ready, the requirement
    -- details disappear -- keep them, just in a normal color per condition
    -- that's actually satisfied, red only for the ones that aren't"). Capped
    -- above the Confirm/Cancel button row (self.procBtnY), not the panel's
    -- own bottom edge, so text never overlaps the button.
    local textBottom = self.procBtnY - 4
    local reqMaxWidth = w - 20
    for _, r in ipairs(reqs) do
        if ty > textBottom then break end
        local line = self.procLibrary:describeOne(r)
        local wrapped = wrapTextLines(line, reqMaxWidth, UIFont.Small)
        for _, wline in ipairs(wrapped) do
            if ty > textBottom then break end
            if r.met then
                drawTextShadowed(self, wline, x + 10, ty, 0.85, 0.85, 0.85, 1, UIFont.Small)
            else
                drawTextShadowed(self, wline, x + 10, ty, 0.95, 0.6, 0.6, 1, UIFont.Small)
            end
            ty = ty + 16
        end
    end
    if #reqs == 0 then
        drawTextShadowed(self, getText("IGUI_TWA_ProcedureRequirementsMet"), x + 10, ty, 0.75, 0.75, 0.75, 1, UIFont.Small)
    end
end

-- Real fix 2026-09-27 for "ปุ่มยืนยันกรรมวิธีโดนบังอยู่หลัง card" (still
-- happening after last round's attempted fix): confirmed from the engine's
-- own real base classes (ISPanel:prerender() draws its background,
-- ISCollapsableWindow:render() draws its resize-widget AFTER children) that
-- prerender() ALWAYS runs before a widget's children render, and render()
-- ALWAYS runs after -- regardless of where inside render() a draw call sits.
-- Calling drawProcedureDetailsBackground() from inside TWACraftWindow:render()
-- (even first, before ISCollapsableWindow.render(self)) was therefore a
-- no-op fix -- the whole render() pass, wherever the call sits in it, still
-- happens after every child (including procConfirmButton/procCancelButton)
-- has already drawn. The ONLY way to draw genuinely BEFORE children is a
-- real prerender() override.
function TWACraftWindow:prerender()
    ISCollapsableWindow.prerender(self)
    self:drawProcedureDetailsBackground()
end

function TWACraftWindow:render()
    ISCollapsableWindow.render(self)

    -- Filter-section captions (request 2026-09-26: "arrange the filter
    -- section to look nicer") -- small labels above each tab row so it
    -- reads as "filter by category" / "filter by rarity" at a glance
    -- instead of two unlabeled rows running together.
    if self.categoryRowY then
        drawTextShadowed(self, getText("IGUI_TWA_FilterSectionCategory"), 10, self.categoryRowY, 0.6, 0.6, 0.6, 1, UIFont.Small)
    end
    if self.tierRowY then
        drawTextShadowed(self, getText("IGUI_TWA_FilterSectionRarity"), 10, self.tierRowY, 0.6, 0.6, 0.6, 1, UIFont.Small)
    end

    -- Center panel gets its own explicit dark card background so it reads as
    -- a distinct panel instead of bare text floating on the window's own
    -- translucent backdrop (the "empty/see-through-looking" complaint from
    -- testing). Flat fill only, not NeatUI's ContentPanel_BG texture -- that
    -- texture's own base color is light/pale, so tinting it at 0.5 still
    -- produced a noticeably light grey panel that washed out white and red
    -- text on top (bug report 2026-09-26; same root cause as drawNeatCard's
    -- note above).
    local centerX, centerY = self.centerX, self.contentTop
    local cardH = self.panelBottom - self.btnH - 10 - centerY
    self:drawRect(centerX - 8, centerY - 8, CENTER_W, cardH, 0.9, 0.06, 0.06, 0.07)
    self:drawRectBorder(centerX - 8, centerY - 8, CENTER_W, cardH, 0.6, 0.4, 0.4, 0.4)

    self:drawProcedureDetails()

    if not self.selectedRecipe then
        drawTextShadowed(self, getText("IGUI_TWA_SelectRecipeFirst"), centerX + 16, centerY + 20, 0.75, 0.75, 0.75, 1, UIFont.Medium)
        self.finishButton.enable = false
        self.incompleteButton.enable = false
        -- Drawn LAST so it sits on top of everything else this frame (the
        -- z-order bug from testing: drawing this before later draw calls in
        -- the same render pass put it visually behind them).
        self:drawHoverTooltip()
        return
    end

    local recipe = self.selectedRecipe
    local item = getItemScript(recipe.result)
    local name = item and item:getDisplayName() or recipe.result
    local tex = resultIcon(recipe.result)

    -- Big, prominent icon (request 2026-09-26: "make the icon bigger, make
    -- it stand out") with the item name beside it. The icon's own border is
    -- tinted by the recipe's rarity tier (request 2026-09-26: "show/filter
    -- by tier"), and the tier name itself is shown under the item name in
    -- that same color.
    local ICON = 100
    local stats = TWARecipeData.Stats[recipe.result]
    local tierInfo = stats and stats.tier and TIER_INFO[stats.tier]
    self:drawRect(centerX, centerY, ICON, ICON, 0.6, 0, 0, 0)
    if tex then
        self:drawTextureScaled(tex, centerX, centerY, ICON, ICON, 1, 1, 1, 1)
    end
    if tierInfo then
        self:drawRectBorder(centerX, centerY, ICON, ICON, 1, tierInfo.r, tierInfo.g, tierInfo.b)
    else
        self:drawRectBorder(centerX, centerY, ICON, ICON, 0.6, 0.5, 0.5, 0.5)
    end
    drawTextShadowed(self, name, centerX + ICON + 12, centerY + 6, 1, 1, 1, 1, UIFont.Medium)
    if tierInfo then
        -- Weapon category shown right next to the tier name (request
        -- 2026-09-26: "หมวดหมู่ให้เอาไปไว้ข้างๆ tier" -- put the category
        -- beside the tier), not in the generic stat grid below.
        local tierLabel = tierInfo.name
        if stats and stats.categories then
            tierLabel = tierLabel .. "  \194\183  " .. stats.categories
        end
        drawTextShadowed(self, tierLabel, centerX + ICON + 12, centerY + 24, tierInfo.r, tierInfo.g, tierInfo.b, 1, UIFont.Small)
    end

    -- Request 2026-09-28: "หมวดหมู่วัตถุดิบ ไม่ต้องแสดง stats สถานะ" --
    -- Material-category recipes (the 6 Metallurgy items) have no combat
    -- stats at all, so the grid below would only ever show placeholder "-"/
    -- default values for them -- skipped entirely for this one category,
    -- the base-item card/procedure grid just start higher up instead.
    local statY = centerY + 44
    if recipe.category ~= "Material" then
        statY = self:drawStatGrid(centerX + ICON + 12, centerY + 44, CENTER_W - ICON - 20)
    end

    -- Base-item requirement box(es) -- request 2026-09-26: the old bare-
    -- border-with-floating-text version ("looks disconnected/floaty") is
    -- replaced with a solid card (same dark fill drawNeatCard uses
    -- elsewhere, so it visually belongs to this panel). Every recipe has at
    -- most ONE base item now (request 2026-09-27: "ปรับให้ทุกอันมีชิ้นงาน
    -- ตั้งต้นเพียงชิ้นเดียว"), so there's only ever one card or none.
    local baseY = math.max(centerY + ICON + 12, statY + 8)
    if not recipe.base then
        self:drawRect(centerX, baseY, CENTER_W - 16, 30, 0.85, 0.08, 0.08, 0.09)
        self:drawRectBorder(centerX, baseY, CENTER_W - 16, 30, 0.4, 0.4, 0.4, 0.4)
        drawTextShadowed(self, getText("IGUI_TWA_NoBaseItemNeeded"), centerX + 8, baseY + 8, 0.75, 0.75, 0.75, 1, UIFont.Small)
        baseY = baseY + 30 + 10
    else
        -- request 2026-09-27: "ทำให้สูตรไอเท็ม uncommon ทุกชิ้นใช้ชิ้นส่วน
        -- ตั้งต้นชิ้นที่ 2 (ไม่ใช่ optional) เป็น แท่งวัตถุดิบ...ของ tier
        -- ตัวเอง" -- a 2nd required card (recipe.base2, tier-matched
        -- MaterialBar) is drawn right below the 1st when present -- both
        -- must be owned to craft, no longer "at most one card" like the
        -- single-base-item round assumed.
        local inv = self.player:getInventory()
        local owned1 = inv:getItemCountRecurse(recipe.base) >= 1
            or (recipe.baseAlt and inv:getItemCountRecurse(recipe.baseAlt) >= 1)
        baseY = self:drawBaseCard(centerX, baseY, CENTER_W - 16, recipe.base, recipe.baseAlt, owned1)
        if recipe.base2 then
            local owned2 = inv:getItemCountRecurse(recipe.base2) >= 1
            baseY = self:drawBaseCard(centerX, baseY, CENTER_W - 16, recipe.base2, nil, owned2)
        end
    end

    -- Required-procedure checklist grid
    drawTextShadowed(self, getText("IGUI_TWA_RequiredProcedures"), centerX, baseY, 0.85, 0.85, 0.85, 1, UIFont.Small)
    local gridLeft, gridTop = centerX, baseY + 20
    local cell, gap = 44, 8
    local perRow = math.max(1, math.floor((CENTER_W - 16 + gap) / (cell + gap)))
    local px, py = gridLeft, gridTop
    local mx, my = self:getMouseX(), self:getMouseY()
    for i, procId in ipairs(recipe.procedures) do
        local proc = TWAProcedures.List[procId]
        if proc then
            if i > 1 and (i - 1) % perRow == 0 then
                px = gridLeft
                py = py + cell + gap
            end
            local done = self:currentDone()[procId]
            local tex2
            if proc.icon then tex2 = getItemTexture(proc.icon) end
            if not tex2 and proc.consumes and proc.consumes[1] then
                local it = getItemScript(proc.consumes[1].itemType)
                tex2 = it and getItemTexture(it:getIcon())
            end
            local tint = done and 1 or 0.4
            local hovered = mx >= px and mx < px + cell and my >= py and my < py + cell
            drawNeatCard(self, px, py, cell, cell, done, false, hovered)
            if tex2 then
                self:drawTextureScaled(tex2, px + 6, py + 6, cell - 12, cell - 12, 1, tint, tint, tint)
            end
            if done then drawCheckBadge(self, px, py, cell) end
            -- These are plain drawn rects, not widgets, so hover has no free
            -- isMouseOver() -- check bounds directly and hand the name up
            -- the same way the procedure library does, so it isn't clipped
            -- either. Just the name, nothing else (request 2026-09-26: "in
            -- the center UI, hovering only needs to show the procedure's
            -- name") -- full requirement detail already lives in the right
            -- panel's own details box once a procedure is clicked there.
            if hovered then
                self.hoverTooltip = { lines = { getText(proc.nameKey) }, x = px, y = py }
            end
            px = px + cell + gap
        end
    end

    self.finishButton.enable = self:allProceduresDone()
    self.incompleteButton.enable = self:canGoIncomplete()

    -- Drawn LAST, after every icon/card this frame, so the tooltip always
    -- renders on top instead of being covered by whatever draws after it
    -- (the exact z-order bug reported from testing 2026-09-26).
    self:drawHoverTooltip()
end

function TWACraftWindow:update()
    ISCollapsableWindow.update(self)
end

function TWACraftWindow:close()
    TWACraftUI.close()
end

-- Open / close / toggle -------------------------------------------------------

-- `searchText`/`resumeItem` (request 2026-09-27/28, multiplayer
-- collaborative crafting): optional context from however the UI was opened
-- -- a right-click on a recognized weapon/base item prefills the search
-- (TWACraftUI.autoSearchNameFor, see HARMONIE_TWA_CraftTrigger.lua), and a
-- right-click on a base item previously bookmarked via the Incomplete
-- button resumes it directly (TWACraftWindow:resumeFromItem) instead. Both
-- are nil for the plain hotkey/generic-menu-option open, which behaves
-- exactly as before. If the window is already open, apply the new context
-- to it in place rather than silently no-op'ing like the old version did.
function TWACraftUI.open(player, searchText, resumeItem)
    player = player or getPlayer()
    if not player then return end
    if TWACraftUI.window and TWACraftUI.window:getIsVisible() then
        local win = TWACraftUI.window
        win:bringToTop()
        if resumeItem then
            win:resumeFromItem(resumeItem)
        elseif searchText then
            win:applySearch(searchText)
        end
        return
    end

    local core = getCore()
    local x = core and math.max(0, (core:getScreenWidth() - WINDOW_W) / 2) or 100
    local y = core and math.max(0, (core:getScreenHeight() - WINDOW_H) / 2) or 100

    local win = TWACraftWindow:new(x, y, player)
    TWACraftUI.window = win
    win:initialise()
    -- *** REAL BUG FIXED (2026-09-28, crash report: "attempted index:
    -- setText of non-table: null" at applySearch, HARMONIE_TWA_CraftUI.lua
    -- crash log): self.searchBox (and every other child widget) does NOT
    -- exist yet right after :initialise() -- confirmed from the engine's
    -- own real source: ISUIElement:initialise() only sets up self.children/
    -- self.ID, it never calls createChildren() at all; createChildren() is
    -- only ever called from :instantiate(), which :addToUIManager() is what
    -- actually triggers. Calling resumeFromItem()/applySearch() (both of
    -- which touch self.searchBox/self.recipeList) BEFORE addToUIManager()
    -- was therefore always going to crash the very first time either one
    -- ran against a brand new window -- moved both calls to AFTER
    -- addToUIManager() below, once every child widget genuinely exists. ***
    win:addToUIManager()
    if resumeItem then
        win:resumeFromItem(resumeItem)
    elseif searchText then
        win:applySearch(searchText)
    end
    win:bringToTop()
end

function TWACraftUI.close()
    local win = TWACraftUI.window
    if not win then return end
    win:setVisible(false)
    win:removeFromUIManager()
    TWACraftUI.window = nil
end

function TWACraftUI.toggle()
    if TWACraftUI.window and TWACraftUI.window:getIsVisible() then
        TWACraftUI.close()
    else
        TWACraftUI.open()
    end
end

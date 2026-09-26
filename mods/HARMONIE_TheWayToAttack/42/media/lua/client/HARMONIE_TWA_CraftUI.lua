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
local CATEGORY_TABS = {
    { key = "All", labelKey = "IGUI_TWA_FilterAll" },
    { key = "Available", labelKey = "IGUI_TWA_FilterAvailable" },
    { key = "Axe", labelKey = "IGUI_TWA_FilterAxe" },
    { key = "SmallBlade", labelKey = "IGUI_TWA_FilterSmallBlade" },
    { key = "Blunt", labelKey = "IGUI_TWA_FilterBlunt" },
    { key = "SmallBlunt", labelKey = "IGUI_TWA_FilterSmallBlunt" },
    { key = "LongBlade", labelKey = "IGUI_TWA_FilterLongBlade" },
    { key = "Spear", labelKey = "IGUI_TWA_FilterSpear" },
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

-- `recipe.base` (and TWARecipeData.Stats[x].icon, resultIcon() below) may be
-- nil, a single fullType string, or a LIST of interchangeable fullTypes --
-- e.g. the universal "Metal Ingot" base is really any of vanilla's own 4
-- real base:ingot items, not one hard-locked type (request 2026-09-26:
-- "materials used in procedures aren't flexible").
local function baseList(base)
    if base == nil then return {} end
    if type(base) == "table" then return base end
    return { base }
end

local function ownsBase(recipe, player)
    if not recipe.base then return true end
    local inv = player:getInventory()
    for _, t in ipairs(baseList(recipe.base)) do
        if inv:getItemCountRecurse(t) >= 1 then return true end
    end
    return false
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

-- Readable name for a (possibly multi-type) base requirement, e.g. "Steel
-- Ingot / Iron Ingot / Copper Ingot / Brass Ingot" for the universal Metal
-- Ingot group.
local function baseDisplayName(base)
    local names = {}
    for _, t in ipairs(baseList(base)) do
        local it = getItemScript(t)
        names[#names + 1] = it and it:getDisplayName() or t
    end
    return table.concat(names, " / ")
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
    if self.searchText ~= "" then
        local item = getItemScript(recipe.result)
        local name = item and item:getDisplayName() or recipe.result
        if not string.find(string.lower(name), string.lower(self.searchText), 1, true) then
            return false
        end
    end
    return true
end

function TWARecipeScrollList:refresh()
    self:clear()
    for _, recipe in ipairs(TWARecipeData.List) do
        if self:matches(recipe) then
            local item = getItemScript(recipe.result)
            local name = item and item:getDisplayName() or recipe.result
            self:addItem(name, recipe)
        end
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

function TWAProcScrollList:populate()
    self:clear()
    local row = nil
    for _, id in ipairs(TWAProcedures.Order) do
        local proc = TWAProcedures.List[id]
        if proc then
            if not row or #row >= self.perRow then
                row = {}
                self:addItem("", row)
            end
            row[#row + 1] = id
        end
    end
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
    local ids = self.items[row].item
    local col = self:cellAt(x)
    local id = ids[col]
    if not id then return end
    local proc = TWAProcedures.List[id]
    if not proc then return end
    getSoundManager():playUISound("UISelectListItem")
    self.ui:onProcedureCellClicked(id, proc)
end

-- Tag-based tools have no single real item to name (any hammer-tagged item
-- works) -- these are the only 5 ItemTag members this mod's procedures ever
-- use (see HARMONIE_TWA_Procedures.lua's own real-API verification note), so
-- a small fixed label table covers every case without guessing further.
local TOOL_TAG_LABELS = {
    HAMMER = "IGUI_TWA_Tool_Hammer",
    SAW = "IGUI_TWA_Tool_Saw",
    WRENCH = "IGUI_TWA_Tool_Wrench",
    WELDING_MASK = "IGUI_TWA_Tool_WeldingMask",
    SCREWDRIVER = "IGUI_TWA_Tool_Screwdriver",
}

function TWAProcScrollList:describeMissing(missing)
    local lines = {}
    for _, m in ipairs(missing) do
        if m.kind == "tool" then
            local toolName
            if m.spec.kind == "type" then
                local it = getItemScript(m.spec.value)
                toolName = it and it:getDisplayName() or m.spec.value
            elseif m.spec.kind == "tag" then
                local key = TOOL_TAG_LABELS[m.spec.value]
                toolName = key and getText(key) or m.spec.value
            end
            lines[#lines + 1] = getText("IGUI_TWA_MissingTool") .. ": " .. (toolName or "?")
        elseif m.kind == "consume" then
            local item = getItemScript(m.itemType)
            local name = item and item:getDisplayName() or m.itemType
            if m.itemTypes and #m.itemTypes > 1 then
                name = name .. " " .. string.format(getText("IGUI_TWA_OrOtherVariants"), #m.itemTypes - 1)
            end
            lines[#lines + 1] = getText("IGUI_TWA_MissingItem") .. " " .. name .. " x" .. m.qty .. " (" .. m.have .. "/" .. m.qty .. ")"
        elseif m.kind == "skill" then
            lines[#lines + 1] = getText("IGUI_TWA_MissingSkill") .. " " .. m.skill .. " " .. m.level
        end
    end
    return lines
end

-- Same text as describeMissing's per-kind formatting, but for ANY single
-- requirement regardless of met/unmet (no "Missing"/"Requires" framing,
-- since the caller colors met vs unmet lines itself -- see
-- TWACraftWindow:drawProcedureDetails).
function TWAProcScrollList:describeOne(req)
    if req.kind == "tool" then
        local toolName
        if req.spec.kind == "type" then
            local it = getItemScript(req.spec.value)
            toolName = it and it:getDisplayName() or req.spec.value
        elseif req.spec.kind == "tag" then
            local key = TOOL_TAG_LABELS[req.spec.value]
            toolName = key and getText(key) or req.spec.value
        end
        return getText("IGUI_TWA_ReqTool") .. ": " .. (toolName or "?")
    elseif req.kind == "consume" then
        local item = getItemScript(req.itemType)
        local name = item and item:getDisplayName() or req.itemType
        if req.itemTypes and #req.itemTypes > 1 then
            name = name .. " " .. string.format(getText("IGUI_TWA_OrOtherVariants"), #req.itemTypes - 1)
        end
        return name .. " x" .. req.qty .. " (" .. req.have .. "/" .. req.qty .. ")"
    elseif req.kind == "skill" then
        return getText("IGUI_TWA_ReqSkill") .. ": " .. req.skill .. " " .. req.level
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
    local ids = entry.item
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
            local done = self.ui and self.ui.selectedRecipe and self.ui.doneProcedures[id] or false
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
                self.ui.hoverTooltip = {
                    lines = { getText(proc.nameKey) },
                    x = self:getAbsoluteX() - self.ui:getAbsoluteX() + px,
                    y = self:getAbsoluteY() - self.ui:getAbsoluteY() + y,
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
    o.doneProcedures = {}
    o.selectedProcId = nil
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
    self.filterButtons = {}
    local fx, fy = leftX, contentTop
    for _, tab in ipairs(CATEGORY_TABS) do
        local label = getText(tab.labelKey)
        local w = getTextManager():MeasureStringX(UIFont.Small, label) + 20
        if fx + w > leftX + LEFT_W then
            fx = leftX
            fy = fy + 26
        end
        local btn = TWATabButton:new(fx, fy, w, 24, label, self, TWACraftWindow.onFilterClick)
        btn.internal = tab.key
        btn:initialise()
        self:addChild(btn)
        self.filterButtons[#self.filterButtons + 1] = btn
        fx = fx + w + 5
    end
    local searchY = fy + 30

    -- Search box
    self.searchBox = ISTextEntryBox:new("", leftX, searchY, LEFT_W, 24)
    self.searchBox:initialise()
    self.searchBox:setPlaceholderText(getText("IGUI_TWA_SearchPlaceholder"))
    local window = self
    self.searchBox.onTextChange = function(box) window.recipeList:setSearch(box:getText()) end
    self:addChild(self.searchBox)

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
    local detailsH = 150
    local gridH = PANEL_H - detailsH - 8
    self.procLibrary = TWAProcScrollList:new(rightX, contentTop, RIGHT_W, gridH, self)
    self.procLibrary:initialise()
    self:addChild(self.procLibrary)
    self.procLibrary:populate()
    self.procDetailsY = contentTop + gridH + 8
    self.procDetailsH = detailsH

    -- Cancel / Finish buttons (center panel bottom)
    local btnW, btnH = (CENTER_W - 10) / 2, 30
    self.cancelButton = TWANeatButton:new(centerX, panelBottom - btnH, btnW, btnH, getText("IGUI_TWA_Cancel"), self, TWACraftWindow.onCancel)
    self.cancelButton:initialise()
    self:addChild(self.cancelButton)

    self.finishButton = TWANeatButton:new(centerX + btnW + 10, panelBottom - btnH, btnW, btnH, getText("IGUI_TWA_Finish"), self, TWACraftWindow.onFinish)
    self.finishButton.neatTint = { r = 1, g = 0.55, b = 0.15 }
    self.finishButton:initialise()
    self:addChild(self.finishButton)

    self.centerX = centerX
    self.contentTop = contentTop
    self.rightX = rightX
    self.panelBottom = panelBottom
    self.btnH = btnH
end

function TWACraftWindow:onFilterClick(button)
    self.recipeList:setFilter(button.internal)
end

function TWACraftWindow:selectRecipe(recipe)
    self.selectedRecipe = recipe
    self.doneProcedures = {}
end

function TWACraftWindow:onCancel()
    self.selectedRecipe = nil
    self.doneProcedures = {}
end

function TWACraftWindow:allProceduresDone()
    if not self.selectedRecipe then return false end
    if not ownsBase(self.selectedRecipe, self.player) then return false end
    for _, procId in ipairs(self.selectedRecipe.procedures) do
        if not self.doneProcedures[procId] then return false end
    end
    return true
end

function TWACraftWindow:onFinish()
    if not self:allProceduresDone() then return end
    ISTimedActionQueue.add(TWA_FinishCraftAction:new(self.player, self.selectedRecipe, self.doneProcedures))
    self.selectedRecipe = nil
    self.doneProcedures = {}
end

function TWACraftWindow:tryPerformProcedure(procId, proc)
    if not self.selectedRecipe then return end
    local needed = false
    for _, pid in ipairs(self.selectedRecipe.procedures) do
        if pid == procId then needed = true break end
    end
    if not needed or self.doneProcedures[procId] then return end
    local met = TWAProcedures.CheckEligibility(proc, self.player)
    if not met then return end
    TWAProcedures.Consume(proc, self.player)
    self.doneProcedures[procId] = true
end

-- Clicking an icon in the procedure-library grid: always select it (so its
-- full requirement breakdown shows in the fixed details box below the grid
-- -- request 2026-09-26), and if it's both eligible and part of the current
-- recipe, perform it immediately too (same as the old click-to-perform
-- behavior, just no longer gated behind a floating hover tooltip).
function TWACraftWindow:onProcedureCellClicked(procId, proc)
    self.selectedProcId = procId
    self:tryPerformProcedure(procId, proc)
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
-- every stat, organized, easy to read"). Each cell is {statKey, labelKey,
-- fmt}; fmt receives the raw numeric stat value.
local STAT_GRID = {
    { { key = "minDamage", labelKey = "IGUI_TWA_Stat_MinDamage", fmt = "%.1f" },
      { key = "maxDamage", labelKey = "IGUI_TWA_Stat_MaxDamage", fmt = "%.1f" } },
    { { key = "critChance", labelKey = "IGUI_TWA_Stat_CritChance", fmt = "%.0f%%" },
      { key = "maxRange", labelKey = "IGUI_TWA_Stat_Range", fmt = "%.2f" } },
    { { key = "baseSpeed", labelKey = "IGUI_TWA_Stat_Speed", fmt = "%.2f" },
      { key = "knockdownMod", labelKey = "IGUI_TWA_Stat_Knockdown", fmt = "%.1f" } },
    { { key = "conditionMax", labelKey = "IGUI_TWA_Stat_Condition", fmt = "%.0f" },
      { key = "weight", labelKey = "IGUI_TWA_StatWeight", fmt = "%.1f" } },
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
            local v = stats[cellDef.key]
            if v then
                local cx = x + (col - 1) * colW
                drawTextShadowed(self, getText(cellDef.labelKey) .. ": " .. string.format(cellDef.fmt, v), cx, y, 0.85, 0.85, 0.85, 1, UIFont.Small)
            end
        end
        y = y + 18
    end
    -- `DamageCategory` ("Slash") is NOT shown as its own stat any more --
    -- verified against media/lua/shared/Definitions/DamageModelDefinitions.lua
    -- (question raised 2026-09-26: "what does this actually do, don't
    -- guess"). It is real, but purely cosmetic: it only picks which visual
    -- gore/wound texture gets stamped onto a zombie's torso/head on hit
    -- (ZedDmg_*_Slash textures vs the default), nothing else -- it does NOT
    -- affect damage, bleeding, or infection chance (the "Causes Bleeding"
    -- label this UI showed briefly was a wrong guess and has been removed).
    -- Not meaningful to a crafting decision, so it's left out of the stat
    -- grid entirely instead of showing a cosmetic-only detail as if it
    -- mattered.
    if stats.twoHanded ~= nil then
        drawTextShadowed(self, getText("IGUI_TWA_Stat_TwoHanded") .. ": " .. getText(stats.twoHanded and "IGUI_TWA_Yes" or "IGUI_TWA_No"),
            x, y, 0.85, 0.85, 0.85, 1, UIFont.Small)
        y = y + 18
    end
    return y
end

-- Fixed (non-scrolling) box under the procedure-library grid showing exactly
-- what the currently-selected (clicked) procedure needs -- replaces the old
-- floating full-requirements tooltip, which rendered underneath the grid's
-- own icons every other frame (the z-order bug from testing) since it drew
-- before those icons in the same render pass instead of after.
function TWACraftWindow:drawProcedureDetails()
    local x, y, w, h = self.rightX, self.procDetailsY, RIGHT_W, self.procDetailsH
    -- Flat fill only (see drawNeatCard's 2026-09-26 note above) -- NeatUI's
    -- InnerPanel_BG texture is too light-colored to sit safely under white/
    -- red text, so it's never used as a background here any more.
    self:drawRect(x, y, w, h, 0.9, 0.06, 0.06, 0.07)
    self:drawRectBorder(x, y, w, h, 0.6, 0.4, 0.4, 0.4)

    local proc = self.selectedProcId and TWAProcedures.List[self.selectedProcId]
    if not proc then
        drawTextShadowed(self, getText("IGUI_TWA_SelectProcedureFirst"), x + 10, y + 10, 0.7, 0.7, 0.7, 1, UIFont.Small)
        return
    end

    local ty = y + 8
    drawTextShadowed(self, getText(proc.nameKey), x + 10, ty, 1, 0.9, 0.6, 1, UIFont.Medium)
    ty = ty + 22

    local done = self.selectedRecipe and self.doneProcedures[self.selectedProcId]
    local reqs = TWAProcedures.DescribeAll(proc, self.player)
    local met = true
    for _, r in ipairs(reqs) do if not r.met then met = false break end end
    local statusKey = done and "IGUI_TWA_ProcedureDone" or (met and "IGUI_TWA_ProcedureReady" or "IGUI_TWA_ProcedureNotReady")
    local statusColor = (done or met) and { r = 0.5, g = 0.9, b = 0.5 } or { r = 0.95, g = 0.45, b = 0.45 }
    drawTextShadowed(self, getText(statusKey), x + 10, ty, statusColor.r, statusColor.g, statusColor.b, 1, UIFont.Small)
    ty = ty + 20

    -- Every requirement stays listed regardless of overall status (bug
    -- report 2026-09-26: "once a procedure becomes ready, the requirement
    -- details disappear -- keep them, just in a normal color per condition
    -- that's actually satisfied, red only for the ones that aren't").
    for _, r in ipairs(reqs) do
        if ty > y + h - 16 then break end
        local line = self.procLibrary:describeOne(r)
        if r.met then
            drawTextShadowed(self, line, x + 10, ty, 0.85, 0.85, 0.85, 1, UIFont.Small)
        else
            drawTextShadowed(self, line, x + 10, ty, 0.95, 0.6, 0.6, 1, UIFont.Small)
        end
        ty = ty + 16
    end
    if #reqs == 0 then
        drawTextShadowed(self, getText("IGUI_TWA_ProcedureRequirementsMet"), x + 10, ty, 0.75, 0.75, 0.75, 1, UIFont.Small)
    end
end

function TWACraftWindow:render()
    ISCollapsableWindow.render(self)

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
    -- it stand out") with the item name beside it.
    local ICON = 100
    self:drawRect(centerX, centerY, ICON, ICON, 0.6, 0, 0, 0)
    if tex then
        self:drawTextureScaled(tex, centerX, centerY, ICON, ICON, 1, 1, 1, 1)
    end
    self:drawRectBorder(centerX, centerY, ICON, ICON, 0.6, 0.5, 0.5, 0.5)
    drawTextShadowed(self, name, centerX + ICON + 12, centerY + 6, 1, 1, 1, 1, UIFont.Medium)

    local statY = self:drawStatGrid(centerX + ICON + 12, centerY + 32, CENTER_W - ICON - 20)

    local baseY = math.max(centerY + ICON + 12, statY + 8)
    self:drawRectBorder(centerX, baseY, CENTER_W - 16, 34, 0.4, 0.4, 0.4, 0.4)
    local baseOwned = ownsBase(recipe, self.player)
    local baseLabel = recipe.base and (getText(baseOwned and "IGUI_TWA_BaseItemOwned" or "IGUI_TWA_BaseItemMissing")) or getText("IGUI_TWA_NoBaseItemNeeded")
    if recipe.base then
        local baseName = baseDisplayName(recipe.base)
        drawTextShadowed(self, baseName, centerX + 8, baseY + 6, 0.9, 0.9, 0.9, 1, UIFont.Small)
        drawTextShadowed(self, baseLabel, centerX + 8, baseY + 20, baseOwned and 0.45 or 0.95, baseOwned and 0.95 or 0.45, 0.45, 1, UIFont.Small)
    else
        drawTextShadowed(self, baseLabel, centerX + 8, baseY + 12, 0.75, 0.75, 0.75, 1, UIFont.Small)
    end

    -- Required-procedure checklist grid
    drawTextShadowed(self, getText("IGUI_TWA_RequiredProcedures"), centerX, baseY + 46, 0.85, 0.85, 0.85, 1, UIFont.Small)
    local gridLeft, gridTop = centerX, baseY + 66
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
            local done = self.doneProcedures[procId]
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
            -- isMouseOver() -- check bounds directly and hand the name (plus
            -- missing-requirement text when relevant) up the same way the
            -- procedure library does, so it isn't clipped either.
            if hovered then
                local lines = { getText(proc.nameKey) }
                if not done then
                    local met, missing = TWAProcedures.CheckEligibility(proc, self.player)
                    if not met then
                        for _, l in ipairs(self.procLibrary:describeMissing(missing)) do
                            lines[#lines + 1] = l
                        end
                    end
                end
                self.hoverTooltip = { lines = lines, x = px, y = py }
            end
            px = px + cell + gap
        end
    end

    self.finishButton.enable = self:allProceduresDone()

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

function TWACraftUI.open(player)
    player = player or getPlayer()
    if not player then return end
    if TWACraftUI.window and TWACraftUI.window:getIsVisible() then return end

    local core = getCore()
    local x = core and math.max(0, (core:getScreenWidth() - WINDOW_W) / 2) or 100
    local y = core and math.max(0, (core:getScreenHeight() - WINDOW_H) / 2) or 100

    local win = TWACraftWindow:new(x, y, player)
    TWACraftUI.window = win
    win:initialise()
    win:addToUIManager()
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

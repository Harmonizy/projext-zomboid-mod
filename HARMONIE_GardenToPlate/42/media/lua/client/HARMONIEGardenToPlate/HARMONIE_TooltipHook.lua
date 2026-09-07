--[[
    HARMONIE - From Garden to Plate
    Shows a vitamin-content breakdown next to a food item's tooltip, for
    anyone with Cooking 3+ or vanilla's own "Nutritionist" trait
    (base:nutritionist -- its vanilla description is literally "Can see the
    nutritional values of any food", it just never had any actual
    Lua/Java hook doing that until now).

    Technique note: an earlier version tried to hook ISToolTip:setDescription
    to append text into the vanilla tooltip's own description string. That
    silently did nothing -- checking how Extensive Health Rework B42
    (Workshop 3726328119, EHR_TooltipSystem.lua) does custom tooltips shows
    real mods don't touch setDescription at all; they fully override
    ISToolTipInv:render() and either draw a whole custom box themselves or
    fall through to the original vanilla render. Fighting vanilla's own
    tooltip sizing to inject extra lines into it isn't the supported path.

    So instead: let the vanilla tooltip render completely untouched, then
    draw our OWN small box next to it with a second, independent panel
    that is never added to UIManager -- keeping it out of UIManager means
    it can never end up in the mouse click hit-test stack (an earlier,
    since-removed full-screen overlay panel got this wrong and ended up
    silently eating every mouse click game-wide).
]]--

require "ISUI/ISPanel"
require "ISUI/ISToolTipInv"
require "HARMONIEGardenToPlate/HARMONIE_FoodVitaminDatabase"
require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"

HARMONIE_GTP = HARMONIE_GTP or {}

local VitaminLabel = {
    A = "IGUI_HARMONIE_Vitamin_A",
    B = "IGUI_HARMONIE_Vitamin_B",
    C = "IGUI_HARMONIE_Vitamin_C",
    D = "IGUI_HARMONIE_Vitamin_D",
    E = "IGUI_HARMONIE_Vitamin_E",
    K = "IGUI_HARMONIE_Vitamin_K",
}
local VitaminUnit = { A = "mcg", B = "mg", C = "mg", D = "mcg", E = "mg", K = "mcg" }
local REQUIRED_COOKING_LEVEL = 3

local function playerCanSeeVitamins(playerObj)
    if playerObj:getPerkLevel(Perks.Cooking) >= REQUIRED_COOKING_LEVEL then
        return true
    end
    return playerObj:hasTrait(CharacterTrait.NUTRITIONIST)
end

-- ============================================
-- STANDALONE VITAMIN BOX (never added to UIManager)
-- ============================================

HARMONIE_VitaminTooltip = ISPanel:derive("HARMONIE_VitaminTooltip")

function HARMONIE_VitaminTooltip:renderLines(lines)
    local font = UIFont.Small
    local textManager = getTextManager()
    local fontHeight = textManager:getFontHeight(font)
    local lineGap = 4
    local padding = 8

    local maxWidth = 0
    for _, line in ipairs(lines) do
        maxWidth = math.max(maxWidth, textManager:MeasureStringX(font, line.text))
    end
    local boxWidth = maxWidth + padding * 2
    local boxHeight = (#lines * (fontHeight + lineGap)) + padding * 2

    self:setWidth(boxWidth)
    self:setHeight(boxHeight)

    self:drawRect(0, 0, boxWidth, boxHeight, 0.95, 0.08, 0.08, 0.10)
    self:drawRectBorder(0, 0, boxWidth, boxHeight, 1, 0.30, 0.62, 0.35)

    local y = padding
    for _, line in ipairs(lines) do
        self:drawText(line.text, padding, y, line.r, line.g, line.b, 1, font)
        y = y + fontHeight + lineGap
    end
end

local function createVitaminTooltip()
    HARMONIE_VitaminTooltip.instance = HARMONIE_VitaminTooltip:new(0, 0, 10, 10)
    HARMONIE_VitaminTooltip.instance:initialise()
    HARMONIE_VitaminTooltip.instance:noBackground()
    HARMONIE_VitaminTooltip.instance:instantiate()
end

local function buildVitaminLines(item)
    if not item then return nil end

    -- A legitimately-crafted sealed jar carries its real vitamin content
    -- as ModData (see HARMONIE_RecipeVitamins.lua), so this resolves for
    -- it exactly like any other tracked food. A sealed jar carries NO
    -- native HungerChange of its own though (see HARMONIE_Items.txt --
    -- deliberately, matching vanilla's own real sealed cans like
    -- Base.CannedCarrots2, so it can't be eaten around the can-opener
    -- requirement), so a debug-spawned one with no ModData at all won't
    -- show anything here until actually opened -- acceptable, since it
    -- was never eatable in that state either.
    local rates = HARMONIE_GTP.GetVitaminRatePerHunger(item)
    if not rates then return nil end

    local lines = {{ text = getText("IGUI_HARMONIE_TooltipHeader"), r = 1, g = 1, b = 1 }}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if rates[vit] then
            table.insert(lines, {
                text = getText(VitaminLabel[vit]) .. ": " .. string.format("%.1f", rates[vit]) .. " " .. VitaminUnit[vit],
                r = 0.55, g = 0.85, b = 0.6,
            })
        end
    end

    -- No separate freshness/rot line: vanilla already tracks how stale
    -- an item is on its own (Fresh/Stale/Rotten, visible on the item
    -- itself), and GetVitaminGains already pulls the ACTUAL current
    -- vitamin amount from that when you eat or cook with it -- this rate
    -- is deliberately the fixed "per hunger point" reference number
    -- (comparable between food types), not a live reading, so there's
    -- nothing further to display here.
    return lines
end

-- ============================================
-- HOOK: draw the box next to the vanilla tooltip
-- ============================================

local original_ISToolTipInv_render = ISToolTipInv.render
function ISToolTipInv:render()
    original_ISToolTipInv_render(self)

    if not HARMONIE_VitaminTooltip.instance then return end

    -- Not gated on instanceof(self.item, "Food") -- FluidContainer-based
    -- drinks like Milk carry vitamins too (see HARMONIE_EatHook.lua) but
    -- aren't a "Food" instance. buildVitaminLines already returns nil for
    -- anything without a vitamin profile, so that's the real gate.
    local playerObj = getSpecificPlayer(0)
    if not self.item or not playerObj or not playerCanSeeVitamins(playerObj) then
        return
    end

    local lines = buildVitaminLines(self.item)
    if not lines then return end

    local box = HARMONIE_VitaminTooltip.instance
    box:renderLines(lines)

    local core = getCore()
    local x = self:getX() + self:getWidth() + 6
    local y = self:getY()
    if x + box:getWidth() > core:getScreenWidth() then
        x = self:getX() - box:getWidth() - 6
    end
    if y + box:getHeight() > core:getScreenHeight() then
        y = core:getScreenHeight() - box:getHeight() - 5
    end
    box:setX(x)
    box:setY(y)
end

Events.OnGameStart.Add(createVitaminTooltip)

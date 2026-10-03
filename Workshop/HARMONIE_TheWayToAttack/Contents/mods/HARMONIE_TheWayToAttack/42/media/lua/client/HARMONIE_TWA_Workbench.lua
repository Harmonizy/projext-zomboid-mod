--============================================================================
-- HARMONIE_TheWayToAttack -- the workbench window's frame, tabs, volume,
-- modify tab and guide tab (client)
--
-- R69 ("ปรับให้ม็อด thewaytoattack ใช้ layout แบบเดียวกับ Home Medic แต่เปลี่ยน
-- เป็นธีมสีเหลืองแทนสีฟ้า"): the craft window (TWACraftWindow, an ISPanel
-- since R69) gets Home Medic's layout -- a header bar (title, volume, close),
-- a row of big icon tabs, the content in a framed area -- in yellow:
--   1 craft      the recipe being made (no recipe: buttons to tab 2 / 3)
--   2 weapons    weapon recipes   -> picking one opens tab 1
--   3 materials  material recipes (Material + Gem) -> tab 1
--   4 modify     the weapon in hand: parts and gem sockets
--   5 guide      how the mod works, chapter by chapter, with pictures
-- The megaphone (mute) became a volume slider in the header (0 = muted),
-- the same setting as Options > Mods.
--============================================================================

require "HARMONIE_TWA_Font"

TWAWorkbench = TWAWorkbench or {}
local W = TWAWorkbench

W.HEADER_H = 40
W.TAB_H = 64
W.TABS = {
    { id = "craft", key = "IGUI_TWA_Tab_Craft" },
    { id = "weapons", key = "IGUI_TWA_Tab_Weapons" },
    { id = "materials", key = "IGUI_TWA_Tab_Materials" },
    { id = "modify", key = "IGUI_TWA_Tab_Modify" },
    { id = "guide", key = "IGUI_TWA_Tab_Guide" },
}
-- yellow theme (Home Medic's palette with the blues turned amber)
W.C = {
    accent = { 1.0, 0.78, 0.2 },
    accentDark = { 0.30, 0.20, 0.03 },
    background = { 0.035, 0.028, 0.012, 0.97 },
    panel = { 0.07, 0.056, 0.026, 0.94 },
    header = { 0.06, 0.046, 0.016, 0.98 },
    border = { 0.85, 0.64, 0.18 },
    borderDim = { 0.40, 0.30, 0.10 },
    text = { 0.97, 0.94, 0.86 },
    textDim = { 0.72, 0.66, 0.54 },
}
W.GUIDE = {
    { key = "Open", pic = "guide_open" },
    { key = "Recipes", pic = "guide_recipes" },
    { key = "Steps", pic = "guide_flow" },
    { key = "Minigame", pic = "guide_minigame" },
    { key = "Quality", pic = "guide_quality" },
    { key = "Pause", pic = "guide_pause" },
    { key = "Practice", pic = "guide_practice" },
    { key = "Modify", pic = "guide_modify" },
    { key = "Settings", pic = "guide_settings" },
}

local MATERIAL_CATS = { Material = true, Gem = true }
function TWACraftUI.isMaterialCategory(cat) return MATERIAL_CATS[cat] == true end
-- which category filter tabs a recipe tab shows
function TWACraftUI.tabInScope(key, scope)
    if key == "All" or key == "Favorites" or key == "Available" then return true end
    if scope == "materials" then return MATERIAL_CATS[key] == true end
    return not MATERIAL_CATS[key]
end

function W.topHeight(S) return S(W.HEADER_H) + S(W.TAB_H) end

local tex = {}
local function texture(path)
    if tex[path] == nil then tex[path] = getTexture(path) or false end
    return tex[path] or nil
end

local function shadowText(panel, s, x, y, r, g, b, a, font)
    panel:drawText(s, x + 1, y + 1, 0, 0, 0, (a or 1) * 0.8, font)
    panel:drawText(s, x, y, r, g, b, a or 1, font)
end

local function wrap(text, maxW, font)
    local tm = getTextManager()
    local out = {}
    for para in tostring(text or ""):gmatch("[^\n]+") do
        local line = ""
        for word in para:gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            if tm:MeasureStringX(font, try) > maxW and line ~= "" then
                out[#out + 1] = line
                line = word
            else
                line = try
            end
        end
        out[#out + 1] = line
    end
    return out
end

local function scaleOf(win) return win.width / 1000 end
local function S(win, px) return math.floor(px * scaleOf(win) + 0.5) end

-- ----------------------------------------------------------------- children
function TWACraftWindow:createWorkbenchChildren(contentTop, panelBottom)
    local w = self.width
    -- close (top right)
    local cs = S(self, 26)
    self.closeX = TWANeatButton:new(w - cs - 8, math.floor((S(self, W.HEADER_H) - cs) / 2), cs, cs, "X", self, TWACraftWindow.close)
    self.closeX.neatTint = { r = 0.9, g = 0.35, b = 0.25 }
    self.closeX:initialise()
    self:addChild(self.closeX)

    -- tab 1 without a recipe: to tab 2 / tab 3
    local bw, bh = S(self, 260), S(self, 34)
    local cx = math.floor((w - bw) / 2)
    local cy = contentTop + S(self, 150)
    self.craftGoWeapons = TWANeatButton:new(cx, cy, bw, bh, getText("IGUI_TWA_GoWeaponRecipes"), self, function(win) win:setTab("weapons") end)
    self.craftGoWeapons.pulse = true
    self.craftGoWeapons:initialise()
    self:addChild(self.craftGoWeapons)
    self.craftGoMaterials = TWANeatButton:new(cx, cy + bh + S(self, 12), bw, bh, getText("IGUI_TWA_GoMaterialRecipes"), self, function(win) win:setTab("materials") end)
    self.craftGoMaterials:initialise()
    self:addChild(self.craftGoMaterials)
    table.insert(self.pageWidgets.craft, self.craftGoWeapons)
    table.insert(self.pageWidgets.craft, self.craftGoMaterials)

    -- tab 4: open the parts window / the gem socket window for the held weapon
    local mx = 10 + S(self, 440) + S(self, 20)
    local mw = w - mx - 20
    self.modifyParts = TWANeatButton:new(mx, panelBottom - S(self, 90), mw, S(self, 34), getText("IGUI_TWA_ModifyParts"), self, TWACraftWindow.onModifyParts)
    self.modifyParts:initialise()
    self:addChild(self.modifyParts)
    self.modifyGems = TWANeatButton:new(mx, panelBottom - S(self, 46), mw, S(self, 34), getText("IGUI_TWA_ModifyGems"), self, TWACraftWindow.onModifyGems)
    self.modifyGems.neatTint = { r = 0.45, g = 0.75, b = 1 }
    self.modifyGems:initialise()
    self:addChild(self.modifyGems)
    self.pageWidgets.modify = { self.modifyParts, self.modifyGems }

    -- tab 5: one button per chapter, previous / next
    self.guideButtons = {}
    local gy = contentTop
    local gw, gh = S(self, 220), S(self, 30)
    for i, ch in ipairs(W.GUIDE) do
        local b = TWATabButton:new(10, gy, gw, gh, tostring(i) .. ". " .. getText("IGUI_TWA_Guide_" .. ch.key .. "_Title"), self,
            function(win) win.guidePage = i end)
        b.internal = i
        b.isActiveTab = function(btn) return btn.target and btn.target.guidePage == btn.internal end
        b:initialise()
        self:addChild(b)
        self.guideButtons[#self.guideButtons + 1] = b
        gy = gy + gh + 4
    end
    local nx = 10 + gw + S(self, 20)
    self.guidePrev = TWANeatButton:new(nx, panelBottom - S(self, 30), S(self, 120), S(self, 30), getText("IGUI_TWA_GuidePrev"), self,
        function(win) win.guidePage = math.max(1, (win.guidePage or 1) - 1) end)
    self.guidePrev:initialise()
    self:addChild(self.guidePrev)
    self.guideNext = TWANeatButton:new(w - 20 - S(self, 120), panelBottom - S(self, 30), S(self, 120), S(self, 30), getText("IGUI_TWA_GuideNext"), self,
        function(win) win.guidePage = math.min(#W.GUIDE, (win.guidePage or 1) + 1) end)
    self.guideNext.pulse = true
    self.guideNext:initialise()
    self:addChild(self.guideNext)
    self.pageWidgets.guide = { self.guidePrev, self.guideNext }
    for _, b in ipairs(self.guideButtons) do table.insert(self.pageWidgets.guide, b) end
    self.guidePage = self.guidePage or 1
end

-- ----------------------------------------------------------------- tabs
function TWACraftWindow:setTab(tab)
    self.activeTab = tab
    if tab == "weapons" or tab == "materials" then
        if self.recipeList.scope ~= tab then
            self.recipeList.scope = tab
            self.recipeList.filterCategory = "All"
        end
        self:setPage("browse")
    elseif tab == "craft" then
        self:setPage("craft")
    else
        self:setPage(tab)
    end
end

-- ----------------------------------------------------------------- volume
function W.volume()
    if TWASound.muted then return 0 end
    return tonumber(TWASound.volume) or 1
end

function W.setVolume(v)
    -- steps of 25%: the sounds exist as files at 25..200% (TWASound.LEVELS),
    -- and Options > Mods' slider moves in the same steps
    v = math.max(0, math.min(2, math.floor(v * 4 + 0.5) / 4))
    local O = TWAOptions
    if O and O.applyVolume then O.applyVolume(v > 0 and v or (TWASound.volume or 1)) end
    if v > 0 then TWASound.volume = v end
    if O and O.volume and O.volume.setValue and v > 0 then pcall(O.volume.setValue, O.volume, v) end
    if O and O.setMuted then
        O.setMuted(v <= 0)
    else
        TWASound.muted = v <= 0
    end
end

function TWACraftWindow:volumeRect()
    local h = S(self, W.HEADER_H)
    local sw = S(self, 150)
    -- room right of the bar for "100%" / "Muted" before the X
    local x = self.closeX and (self.closeX.x - sw - S(self, 80)) or (self.width - sw - 100)
    return x, math.floor(h / 2) - 4, sw, 8
end

function TWACraftWindow:volumeFromMouse(mx)
    local x, _, w = self:volumeRect()
    W.setVolume(math.max(0, math.min(1, (mx - x) / w)) * 2)
end

-- ----------------------------------------------------------------- drawing
function TWACraftWindow:drawWorkbenchFrame()
    local C = W.C
    local hh, th = S(self, W.HEADER_H), S(self, W.TAB_H)
    self:drawRect(0, 0, self.width, self.height, C.background[4], C.background[1], C.background[2], C.background[3])
    self:drawRectBorder(0, 0, self.width, self.height, 1, C.border[1], C.border[2], C.border[3])
    self:drawRect(1, 1, self.width - 2, hh - 1, C.header[4], C.header[1], C.header[2], C.header[3])
    self:drawRect(0, hh - 1, self.width, 1, 0.8, C.border[1], C.border[2], C.border[3])
    -- tab bar
    self:drawRect(1, hh, self.width - 2, th, 0.92, 0.03, 0.024, 0.01)
    self:drawRect(0, hh + th - 1, self.width, 1, 0.8, C.border[1], C.border[2], C.border[3])
    local gap = 5
    local tabW = math.floor((self.width - 16 - gap * (#W.TABS - 1)) / #W.TABS)
    local x = 8
    self.tabBounds = {}
    for _, t in ipairs(W.TABS) do
        local active = self.activeTab == t.id
        local ty, tH = hh + 6, th - 12
        local bg = active and C.accentDark or C.background
        local bd = active and C.accent or C.borderDim
        self:drawRect(x, ty, tabW, tH, active and 0.98 or 0.82, bg[1], bg[2], bg[3])
        self:drawRectBorder(x, ty, tabW, tH, active and 0.95 or 0.62, bd[1], bd[2], bd[3])
        if active then
            self:drawRect(x + 2, ty + 2, tabW - 4, tH - 4, 0.16, C.accent[1], C.accent[2], C.accent[3])
            self:drawRect(x + 3, ty + tH - 5, tabW - 6, 2, 0.75, C.accent[1], C.accent[2], C.accent[3])
        end
        local size = math.min(tH - 8, S(self, 44))
        local label = getText(t.key)
        local font = TWAFont.small()
        local lw = getTextManager():MeasureStringX(font, label)
        local fh = getTextManager():getFontHeight(font)
        local icon = texture("media/textures/TWA_UI/tab_" .. t.id .. ".png")
        local total = size + 8 + lw
        local ix = x + math.floor((tabW - total) / 2)
        if icon then
            self:drawTextureScaled(icon, ix, ty + math.floor((tH - size) / 2), size, size, active and 1 or 0.65, 1, 1, 1)
        end
        local tc = active and C.text or C.textDim
        shadowText(self, label, ix + size + 8, ty + math.floor((tH - fh) / 2), tc[1], tc[2], tc[3], 1, font)
        self.tabBounds[#self.tabBounds + 1] = { id = t.id, x = x, y = ty, w = tabW, h = tH }
        x = x + tabW + gap
    end
    -- content frame
    local top = hh + th + 2
    self:drawRect(4, top, self.width - 8, self.height - top - 4, C.panel[4], C.panel[1], C.panel[2], C.panel[3])
end

function TWACraftWindow:drawWorkbenchHeader()
    local C = W.C
    local hh = S(self, W.HEADER_H)
    local font = TWAFont.medium()
    local fh = getTextManager():getFontHeight(font)
    local hammer = texture("media/textures/TWA_UI/tab_craft.png")
    local ix = 10
    if hammer then
        self:drawTextureScaled(hammer, ix, math.floor((hh - S(self, 28)) / 2), S(self, 28), S(self, 28), 1, 1, 1, 1)
        ix = ix + S(self, 34)
    end
    shadowText(self, getText("IGUI_TWA_CraftWindowTitle"), ix, math.floor((hh - fh) / 2), C.accent[1], C.accent[2], C.accent[3], 1, font)
    -- volume
    local vx, vy, vw, vh = self:volumeRect()
    local v = W.volume()
    local small = TWAFont.small()
    local label = getText("IGUI_TWA_Volume")
    local lw = getTextManager():MeasureStringX(small, label)
    local sfh = getTextManager():getFontHeight(small)
    shadowText(self, label, vx - lw - 10, math.floor((hh - sfh) / 2), C.textDim[1], C.textDim[2], C.textDim[3], 1, small)
    self:drawRect(vx, vy, vw, vh, 0.9, 0.12, 0.1, 0.05)
    self:drawRect(vx, vy, math.floor(vw * v / 2), vh, 1, C.accent[1], C.accent[2], C.accent[3])
    self:drawRectBorder(vx, vy, vw, vh, 0.8, C.borderDim[1], C.borderDim[2], C.borderDim[3])
    local kx = vx + math.floor(vw * v / 2)
    self:drawRect(kx - 4, vy - 5, 8, vh + 10, 1, C.text[1], C.text[2], C.text[3])
    local pct = v <= 0 and getText("IGUI_TWA_VolumeMuted") or (tostring(math.floor(v * 100 + 0.5)) .. "%")
    shadowText(self, pct, vx + vw + 8, math.floor((hh - sfh) / 2), C.text[1], C.text[2], C.text[3], 1, small)
    -- hovered tab: its name as a tooltip (Home Medic does the same)
    self:drawTabTooltip()
end

function TWACraftWindow:drawTabTooltip()
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, t in ipairs(self.tabBounds or {}) do
        if mx >= t.x and mx <= t.x + t.w and my >= t.y and my <= t.y + t.h then
            local tip = getText("IGUI_TWA_Tab_" .. t.id:sub(1, 1):upper() .. t.id:sub(2) .. "_Tip")
            if tip and tip ~= "" and not tip:find("IGUI_", 1, true) then
                self.hoverTooltip = { lines = { tip }, x = t.x + 40, y = t.y + t.h + 4 }
            end
        end
    end
end

-- tab 1 with no recipe
function TWACraftWindow:renderCraftEmpty()
    local C = W.C
    local font = TWAFont.medium()
    local s = getText("IGUI_TWA_CraftNoRecipe")
    local lines = wrap(s, self.width - 200, font)
    local fh = getTextManager():getFontHeight(font)
    local y = self.craftGoWeapons.y - (#lines + 1) * (fh + 2)
    for i, l in ipairs(lines) do
        local lw = getTextManager():MeasureStringX(font, l)
        shadowText(self, l, math.floor((self.width - lw) / 2), y + (i - 1) * (fh + 2), C.text[1], C.text[2], C.text[3], 1, font)
    end
end

-- tabs 4 and 5
function TWACraftWindow:renderWorkbenchPage()
    if self.page == "modify" then self:renderModify() else self:renderGuide() end
end

function TWACraftWindow:heldWeapon()
    local w = self.player and self.player:getPrimaryHandItem()
    if w and TWAPartSystem and TWAPartSystem.IsMeleeWeapon(w) then return w end
    return nil
end

function TWACraftWindow:renderModify()
    local C = W.C
    local small, med = TWAFont.small(), TWAFont.medium()
    local lh = TWAFont.lineH(small)
    local x, y = 18, self.contentTop
    local weapon = self:heldWeapon()
    self.modifyParts.enable = weapon ~= nil
    self.modifyGems.enable = weapon ~= nil and TWAGemSocket and TWAGemSocket.canUse(weapon) or false
    if not weapon then
        local lines = wrap(getText("IGUI_TWA_ModifyNoWeapon"), self.width - 80, med)
        for i, l in ipairs(lines) do
            shadowText(self, l, x, y + 20 + (i - 1) * (lh + 6), C.text[1], C.text[2], C.text[3], 1, med)
        end
        return
    end
    -- the weapon card
    local cardW = S(self, 440)
    local icon = weapon.getTex and weapon:getTex()
    local isz = S(self, 96)
    self:drawRect(x, y, isz, isz, 0.6, 0, 0, 0)
    if icon then self:drawTextureScaled(icon, x, y, isz, isz, 1, 1, 1, 1) end
    self:drawRectBorder(x, y, isz, isz, 1, C.border[1], C.border[2], C.border[3])
    local tx = x + isz + 12
    shadowText(self, weapon:getDisplayName(), tx, y + 4, 1, 1, 1, 1, med)
    local md = weapon:getModData()
    local ty = y + TWAFont.lineH(med) + 8
    if md.TWA_Grade then
        shadowText(self, getText("IGUI_TWA_ModifyGrade", tostring(md.TWA_Grade)), tx, ty, C.accent[1], C.accent[2], C.accent[3], 1, small)
        ty = ty + lh
    end
    local function stat(key, v)
        shadowText(self, getText(key) .. ": " .. v, tx, ty, 0.85, 0.85, 0.85, 1, small)
        ty = ty + lh
    end
    stat("IGUI_TWA_Stat_MinDamage", TWADisplay.fmt(weapon:getMinDamage()))
    stat("IGUI_TWA_Stat_MaxDamage", TWADisplay.fmt(weapon:getMaxDamage()))
    stat("IGUI_TWA_Stat_Speed", tostring(math.floor((tonumber(weapon:getBaseSpeed()) or 0) * 100 + 0.5)) .. "%")  -- no decimals on screen
    stat("IGUI_TWA_Stat_Condition", tostring(weapon:getCondition()) .. " / " .. tostring(weapon:getConditionMax()))

    -- parts
    local py = math.max(ty, y + isz) + 16
    shadowText(self, getText("IGUI_TWA_ModifyPartsHeader"), x, py, C.accent[1], C.accent[2], C.accent[3], 1, small)
    py = py + lh + 4
    for _, sl in ipairs(TWAPartSystem.Slots) do
        local part = TWAPartSystem.GetPart(weapon, sl.key)
        local name = part and part:getDisplayName() or getText("IGUI_TWA_ModifyEmpty")
        shadowText(self, getText(sl.label) .. ": " .. name, x + 10, py, part and 0.9 or 0.6, part and 0.9 or 0.6, part and 0.9 or 0.6, 1, small)
        py = py + lh
    end
    -- gems
    py = py + 10
    shadowText(self, getText("IGUI_TWA_ModifyGemsHeader"), x, py, C.accent[1], C.accent[2], C.accent[3], 1, small)
    py = py + lh + 4
    local G = TWAGemSocket
    if not G or not G.canUse(weapon) then
        shadowText(self, getText("IGUI_TWA_ModifyNoSockets"), x + 10, py, 0.65, 0.65, 0.65, 1, small)
    else
        shadowText(self, getText("IGUI_TWA_ModifySockets", tostring(G.filledCount(weapon)), tostring(G.totalSlots(weapon))), x + 10, py, 0.9, 0.9, 0.9, 1, small)
        py = py + lh
        for _, g in ipairs(G.list(weapon)) do
            local it = getScriptManager and getScriptManager():getItem(g.type)
            local n = it and it:getDisplayName() or g.type
            shadowText(self, "- " .. n .. "  (" .. getText("IGUI_TWA_GemState_" .. tostring(g.state or "Raw")) .. ")", x + 20, py, 0.75, 0.85, 1, 1, small)
            py = py + lh
        end
    end
    -- what the buttons do
    local mx = self.modifyParts.x
    local hy = self.contentTop
    for i, l in ipairs(wrap(getText("IGUI_TWA_ModifyHelp"), self.width - mx - 30, small)) do
        shadowText(self, l, mx, hy + (i - 1) * lh, C.textDim[1], C.textDim[2], C.textDim[3], 1, small)
    end
end

function TWACraftWindow:onModifyParts()
    if self:heldWeapon() and TWAPartsUI then TWAPartsUI.open(self.player) end
end

function TWACraftWindow:onModifyGems()
    local w = self:heldWeapon()
    if w and TWAGemSocketUI then TWAGemSocketUI.open(self.player, w) end
end

function TWACraftWindow:renderGuide()
    local C = W.C
    local i = math.max(1, math.min(#W.GUIDE, self.guidePage or 1))
    local ch = W.GUIDE[i]
    local small, med = TWAFont.small(), TWAFont.medium()
    local x = 10 + S(self, 220) + S(self, 20)
    local w = self.width - x - 20
    local y = self.contentTop
    shadowText(self, tostring(i) .. ". " .. getText("IGUI_TWA_Guide_" .. ch.key .. "_Title"), x, y, C.accent[1], C.accent[2], C.accent[3], 1, med)
    y = y + TWAFont.lineH(med) + 8
    local pic = texture("media/textures/TWA_UI/" .. ch.pic .. ".png")
    if pic then
        local pw = math.min(w, S(self, 512))
        local ph = math.floor(pw * 288 / 512)
        local px = x + math.floor((w - pw) / 2)
        self:drawTextureScaled(pic, px, y, pw, ph, 1, 1, 1, 1)
        self:drawRectBorder(px, y, pw, ph, 0.8, C.borderDim[1], C.borderDim[2], C.borderDim[3])
        y = y + ph + 10
    end
    local lh = TWAFont.lineH(small)
    local bottom = self.guidePrev.y - 8
    for _, l in ipairs(wrap(getText("IGUI_TWA_Guide_" .. ch.key .. "_Body"), w, small)) do
        if y + lh > bottom then break end
        shadowText(self, l, x, y, C.text[1], C.text[2], C.text[3], 1, small)
        y = y + lh
    end
    local pageText = getText("IGUI_TWA_GuidePage", tostring(i), tostring(#W.GUIDE))
    local pw = getTextManager():MeasureStringX(small, pageText)
    shadowText(self, pageText, x + math.floor((w - pw) / 2), self.guidePrev.y + 6, C.textDim[1], C.textDim[2], C.textDim[3], 1, small)
    self.guidePrev.enable = i > 1
    self.guideNext.enable = i < #W.GUIDE
    self.guideNext.pulse = i < #W.GUIDE
end

-- ----------------------------------------------------------------- mouse
function TWACraftWindow:workbenchMouseDown(x, y)
    for _, t in ipairs(self.tabBounds or {}) do
        if x >= t.x and x <= t.x + t.w and y >= t.y and y <= t.y + t.h then
            getSoundManager():playUISound("UISelectListItem")
            if t.id == "craft" and self.active then
                self.selectedRecipe = TWACraftUI.getRecipeById(self.active.recipeId) or self.selectedRecipe
            end
            self:setTab(t.id)
            return true
        end
    end
    if y < S(self, W.HEADER_H) then
        local vx, vy, vw = self:volumeRect()
        if x >= vx - 6 and x <= vx + vw + 6 then
            self.draggingVolume = true
            self:volumeFromMouse(x)
            return true
        end
        -- the header moves the window
        ISPanel.onMouseDown(self, x, y)
        return true
    end
    return false
end

function TWACraftWindow:onMouseMove(dx, dy)
    if self.draggingVolume then
        self:volumeFromMouse(self:getMouseX())
        return
    end
    ISPanel.onMouseMove(self, dx, dy)
end

function TWACraftWindow:onMouseMoveOutside(dx, dy)
    if self.draggingVolume then
        self:volumeFromMouse(self:getMouseX())
        return
    end
    ISPanel.onMouseMoveOutside(self, dx, dy)
end

function TWACraftWindow:onMouseUp(x, y)
    self.draggingVolume = false
    ISPanel.onMouseUp(self, x, y)
end

function TWACraftWindow:onMouseUpOutside(x, y)
    self.draggingVolume = false
    ISPanel.onMouseUpOutside(self, x, y)
end

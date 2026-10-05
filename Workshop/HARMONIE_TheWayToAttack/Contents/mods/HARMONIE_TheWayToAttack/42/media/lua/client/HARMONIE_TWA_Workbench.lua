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
    -- R73 ("ให้หน้าคู่มืออธิบายความหมายของแต่ละค่าในอาวุธที่แสดง เอาให้คนทั่วไป
    -- เข้าใจได้"): what every number in a weapon's tooltip means -- text
    -- only, so every line fits
    { key = "StatsDamage" },
    { key = "StatsHandling" },
    { key = "StatsWear" },
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
    self.closeX = TWANeatButton:new(w - cs - 8, math.floor((S(self, W.HEADER_H) - cs) / 2), cs, cs, "", self, TWACraftWindow.close)
    self.closeX.neatTint = { r = 0.9, g = 0.35, b = 0.25 }
    -- R71 ("เปลี่ยนจากคำในปุ่มเป็นสัญลักษณ์"): symbols, not words
    self.closeX.icon = texture("media/textures/TWA_UI/icon_close.png")
    if not self.closeX.icon then self.closeX:setTitle("X") end
    self.closeX:initialise()
    self:addChild(self.closeX)
    -- R70: the pin left of the X; the size grip is the bottom-right corner
    -- (drawn in drawWorkbenchOverlay). R71: the gear (settings window: text
    -- size, window size, sound, zombie health display...) replaces A- / A+.
    local hy = self.closeX.y
    self.pinBtn = TWANeatButton:new(self.closeX.x - cs - 6, hy, cs, cs, "", self, function(win) win:togglePin() end)
    self.pinBtn:initialise()
    self:addChild(self.pinBtn)
    self.settingsBtn = TWANeatButton:new(self.pinBtn.x - cs - 6, hy, cs, cs, "", self, function() W.openSettings() end)
    self.settingsBtn.icon = texture("media/textures/TWA_UI/icon_settings.png")
    if not self.settingsBtn.icon then self.settingsBtn:setTitle("S") end
    self.settingsBtn:setTooltip(getText("IGUI_TWA_Set_Title"))
    self.settingsBtn:initialise()
    self:addChild(self.settingsBtn)
    self:refreshHeaderButtons()

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

    -- tab 4 (R70: "เอาหน้าทั้งหน้าของหน้าต่างเปลี่ยนอัญมณีมาไว้ในแท็บ 4 ...
    -- ยังไม่ต้องการใช้หน้าเปลี่ยนชิ้นส่วนอาวุธ"): the whole gem socket page,
    -- in the card; no parts button
    self.gemPanel = TWAGemSocketUI.embed(self, 10, contentTop, w - 20, panelBottom - contentTop, self.player)
    self.pageWidgets.modify = { self.gemPanel }

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
    -- room right of the bar for "100%" / "Muted" before the header buttons
    local left = self.settingsBtn or self.closeX
    local x = left and (left.x - sw - S(self, 76)) or (self.width - sw - 100)
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
    if self.wbCollapsed then return end -- R70: folded up to the header
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

-- the weapon tab 4 works on: the one picked by right-click (while it is
-- still at hand), else the melee weapon in the main hand
function TWACraftWindow:modifyTarget()
    local w = self.modifyWeapon
    if w and TWASources and not TWASources.get(self.player):findById(w:getID()) then
        self.modifyWeapon, w = nil, nil
    end
    return w or self:heldWeapon()
end

function TWACraftWindow:renderModify()
    local C = W.C
    local weapon = self:modifyTarget()
    local G = TWAGemSocket
    local ok = weapon ~= nil and G and G.canUse(weapon)
    self.gemPanel:setWeapon(ok and weapon or nil)
    self.gemPanel:setVisible(ok and true or false)
    if ok then return end
    local med = TWAFont.medium()
    local lh = TWAFont.lineH(med)
    local key = weapon and "IGUI_TWA_ModifyNoSockets" or "IGUI_TWA_ModifyNoWeapon"
    local lines = wrap(getText(key), self.width - 80, med)
    local y = self.contentTop + S(self, 40)
    if weapon then
        shadowText(self, weapon:getDisplayName(), 30, y, 1, 1, 1, 1, med)
        y = y + lh + 6
    end
    for i, l in ipairs(lines) do
        shadowText(self, l, 30, y + (i - 1) * (lh + 6), C.text[1], C.text[2], C.text[3], 1, med)
    end
end

function TWACraftWindow:renderGuide()
    local C = W.C
    local i = math.max(1, math.min(#W.GUIDE, self.guidePage or 1))
    local ch = W.GUIDE[i]
    local small, med = TWAFont.small(), TWAFont.medium()
    local x = 10 + S(self, 220) + S(self, 20)
    local w = self.width - x - 20
    local y = self.contentTop
    local bottom = self.guidePrev.y - 8
    -- R73: the text always fits -- the picture shrinks (or is left out) to
    -- make room, and a text too long even then drops to the smallest font
    local body = getText("IGUI_TWA_Guide_" .. ch.key .. "_Body")
    local lh = TWAFont.lineH(small)
    local lines = wrap(body, w, small)
    if #lines * lh > bottom - y and small ~= UIFont.Small then
        small = UIFont.Small
        lh = TWAFont.lineH(small)
        lines = wrap(body, w, small)
    end
    local pic = ch.pic and texture("media/textures/TWA_UI/" .. ch.pic .. ".png")
    if pic then
        local pw = math.min(w, S(self, 512))
        local ph = math.floor(pw * 288 / 512)
        local room = bottom - y - #lines * lh - 10
        if room < ph then
            ph = room
            pw = math.floor(ph * 512 / 288)
        end
        if ph >= S(self, 90) then
            local px = x + math.floor((w - pw) / 2)
            self:drawTextureScaled(pic, px, y, pw, ph, 1, 1, 1, 1)
            self:drawRectBorder(px, y, pw, ph, 0.8, C.borderDim[1], C.borderDim[2], C.borderDim[3])
            y = y + ph + 10
        end
    end
    for _, l in ipairs(lines) do
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

-- ----------------------------------------------------------------- preferences
-- R70: the window's size (dragged), the text step (A- / A+) and the pin,
-- kept in Zomboid/Lua/HARMONIE_TWA_Window.txt (this computer only).
W.PREFS_FILE = "HARMONIE_TWA_Window.txt"
W.pinned = true

function W.ensurePrefs()
    if W.prefsLoaded then return end
    W.prefsLoaded = true
    if not getFileReader then return end
    local ok, reader = pcall(getFileReader, W.PREFS_FILE, true)
    if not ok or not reader then return end
    pcall(function()
        local line = reader:readLine()
        while line do
            local k, v = line:match("^%s*([%w_]+)%s*=%s*(%S+)")
            if k == "scale" then TWACraftUI.userScale = tonumber(v)
            elseif k == "text" then TWAFont.userStep = math.max(-4, math.min(4, math.floor(tonumber(v) or 0)))
            elseif k == "pinned" then W.pinned = v ~= "0" end
            line = reader:readLine()
        end
    end)
    pcall(function() reader:close() end)
end

function W.savePrefs()
    if not getFileWriter then return end
    local ok, writer = pcall(getFileWriter, W.PREFS_FILE, true, false)
    if not ok or not writer then return end
    pcall(function()
        if TWACraftUI.userScale then writer:write("scale=" .. string.format("%.3f", TWACraftUI.userScale) .. "\n") end
        writer:write("text=" .. tostring(TWAFont.userStep or 0) .. "\n")
        writer:write("pinned=" .. (W.pinned and "1" or "0") .. "\n")
    end)
    pcall(function() writer:close() end)
end

function TWACraftWindow:refreshHeaderButtons()
    if self.pinBtn then
        self.pinBtn.icon = texture("media/textures/TWA_UI/" .. (W.pinned and "pin_on" or "pin_off") .. ".png")
        if not self.pinBtn.icon then self.pinBtn:setTitle(W.pinned and "P" or "U") end
        self.pinBtn:setTooltip(getText(W.pinned and "IGUI_TWA_Unpin" or "IGUI_TWA_Pin"))
    end
end

-- busy: a procedure, a center action or a practice is running -- the window
-- is not rebuilt then (their results come back to this window)
function TWACraftWindow:isBusy()
    return self.activeProcId ~= nil or self.activeCenterAction ~= nil or self.practicing and true or false
end

function TWACraftWindow:changeTextSize(d) return W.stepText(d) end

-- R71: the window built again after a size / text change (when it is open
-- and not busy); the settings window stays on top
function W.relayout()
    local win = TWACraftUI.window
    if not win then return true end
    if win:isBusy() then win:flashLocked("IGUI_TWA_BusyCantResize") return false end
    TWACraftUI.rebuild()
    if TWASettingsUI and TWASettingsUI.instance then TWASettingsUI.instance:bringToTop() end
    return true
end

-- one text step up / down (Small..Large, on top of the window's own bump)
function W.stepText(d)
    W.ensurePrefs()
    local raw = TWAFont.rawLevel()
    if (d > 0 and raw >= (TWAFont.LEVELS or 3)) or (d < 0 and raw <= 1) then return false end
    local win = TWACraftUI.window
    if win and win:isBusy() then win:flashLocked("IGUI_TWA_BusyCantResize") return false end
    TWAFont.userStep = math.max(-4, math.min(4, (TWAFont.userStep or 0) + d))
    W.savePrefs()
    return W.relayout()
end

-- pin / unpin: unpinned, the window folds up to its header a moment after
-- the mouse leaves it and unfolds when the mouse comes back (Home Medic's pin)
W.FOLD_DELAY_MS = 350
function TWACraftWindow:togglePin()
    W.pinned = not W.pinned
    self.wbLeaveAt = nil
    if W.pinned then self:wbExpand() end
    self:refreshHeaderButtons()
    W.savePrefs()
end

local HEADER_KEEP = { "closeX", "pinBtn", "settingsBtn" }
function TWACraftWindow:wbCollapse()
    if self.wbCollapsed then return end
    local keep = {}
    for _, f in ipairs(HEADER_KEEP) do if self[f] then keep[self[f]] = true end end
    self.wbHidden = {}
    for _, child in pairs(self.children or {}) do
        if child and not keep[child] and child:getIsVisible() then
            child:setVisible(false)
            self.wbHidden[#self.wbHidden + 1] = child
        end
    end
    self.wbFullH = self.height
    self.wbCollapsed = true
    self:setHeight(S(self, W.HEADER_H))
end

function TWACraftWindow:wbExpand()
    if not self.wbCollapsed then return end
    self.wbCollapsed = false
    if self.wbFullH then self:setHeight(self.wbFullH) end
    for _, child in ipairs(self.wbHidden or {}) do child:setVisible(true) end
    self.wbHidden = nil
    self.wbLeaveAt = nil
    -- the page decides again what shows
    if self.page then self:setPage(self.page) end
end

function TWACraftWindow:updatePin()
    local busy = self:isBusy() or self.wbResizing or self.moving or self.draggingVolume
        or (TWAPicker and TWAPicker.current and TWAPicker.current.owner == self)
    if W.pinned or busy then
        if W.pinned and self.wbCollapsed then self:wbExpand() end
        self.wbLeaveAt = nil
        return
    end
    local mx, my = getMouseX(), getMouseY()
    local x, y = self:getAbsoluteX(), self:getAbsoluteY()
    local over = mx >= x and mx <= x + self.width and my >= y and my <= y + self.height
    local now = getTimestampMs and getTimestampMs() or 0
    if over then
        self.wbLeaveAt = nil
        if self.wbCollapsed then self:wbExpand() end
    elseif not self.wbCollapsed then
        self.wbLeaveAt = self.wbLeaveAt or now
        if now - self.wbLeaveAt >= W.FOLD_DELAY_MS then self:wbCollapse() end
    end
end

-- the size grip (bottom-right corner): drag to scale the whole window --
-- everything in it and the text grow / shrink together; right-click it to
-- go back to the size from Options > Mods
W.GRIP = 18
function TWACraftWindow:inGrip(x, y)
    if self.wbCollapsed then return false end
    local g = W.GRIP
    return x >= self.width - g and y >= self.height - g
end

function TWACraftWindow:drawWorkbenchOverlay()
    if self.wbCollapsed then return end
    local C = W.C
    local x, y = self.width - 16, self.height - 16
    for i, len in ipairs({ 12, 8, 4 }) do
        local o = (i - 1) * 4
        self:drawRect(x + 10 - o, y + 14 - len, 2, len, 0.85 - 0.15 * (i - 1), C.accent[1], C.accent[2], C.accent[3])
    end
    if self.wbResizing and self.wbPreview then
        local w, h = math.floor(1000 * self.wbPreview), math.floor(700 * self.wbPreview)
        self:drawRectBorder(0, 0, w, h, 0.9, C.accent[1], C.accent[2], C.accent[3])
        self:drawRectBorder(1, 1, w - 2, h - 2, 0.5, C.accent[1], C.accent[2], C.accent[3])
        local t = tostring(math.floor(self.wbPreview * 100 + 0.5)) .. "%"
        shadowText(self, t, w - 60, h - 40, C.accent[1], C.accent[2], C.accent[3], 1, TWAFont.medium())
    end
end

function TWACraftWindow:resizeMove()
    local dx = getMouseX() - self.wbResizeMX
    local dy = getMouseY() - self.wbResizeMY
    local s = math.max((self.wbResizeW + dx) / 1000, (self.wbResizeH + dy) / 700)
    self.wbPreview = math.max(TWACraftUI.MIN_SCALE, math.min(TWACraftUI.maxScale(), s))
end

function TWACraftWindow:resizeEnd()
    self.wbResizing = false
    local s = self.wbPreview
    self.wbPreview = nil
    if not s or math.abs(s - self.width / 1000) < 0.01 then return end
    if self:isBusy() then self:flashLocked("IGUI_TWA_BusyCantResize") return end
    TWACraftUI.userScale = s
    W.savePrefs()
    TWACraftUI.rebuild()
end

function TWACraftWindow:onRightMouseDown(x, y)
    if self:inGrip(x, y) and TWACraftUI.userScale then
        if self:isBusy() then self:flashLocked("IGUI_TWA_BusyCantResize") return true end
        TWACraftUI.userScale = nil
        W.savePrefs()
        TWACraftUI.rebuild()
        return true
    end
    return false
end

-- ----------------------------------------------------------------- settings
-- R71: the rows of the settings window (HARMONIE_TWA_Settings)
local SIZE_NAMES = { "Small", "Medium", "Large" }
function W.settingsRows()
    W.ensurePrefs()
    local O = TWAOptions or {}
    local function T(k) return getText("UI_options_HARMONIE_TWA_" .. k) end
    local function oget(id, d) return O.get and O.get(id, d) or d end
    local function oset(id, v) if O.set then O.set(id, v) end end
    local rows = {
        { kind = "section", label = getText("IGUI_TWA_Set_Window") },
        { kind = "step", label = getText("IGUI_TWA_Set_TextSize"), tip = getText("IGUI_TWA_Set_TextSize_Tip"),
            text = function() return T("size_" .. SIZE_NAMES[TWAFont.level()]) end,
            minus = function() W.stepText(-1) end, plus = function() W.stepText(1) end },
        { kind = "choice", label = T("uiWindowSize"), tip = getText("IGUI_TWA_Set_WindowSize_Tip"),
            values = { T("wsize_Auto"), T("wsize_Normal"), T("wsize_Large"), T("wsize_XLarge") },
            get = function()
                if TWACraftUI.userScale then return 0 end
                return math.floor(tonumber(oget("uiWindowSize", 1)) or 1)
            end,
            text = function() return getText("IGUI_TWA_Set_CustomSize", tostring(math.floor((TWACraftUI.userScale or 1) * 100 + 0.5))) end,
            set = function(i)
                TWACraftUI.userScale = nil
                oset("uiWindowSize", i)
                W.savePrefs()
                W.relayout()
            end },
        { kind = "tick", label = getText("IGUI_TWA_Set_Pin"), tip = getText("IGUI_TWA_Set_Pin_Tip"),
            get = function() return W.pinned end,
            set = function(v)
                if v == W.pinned then return end
                local win = TWACraftUI.window
                if win then win:togglePin() else W.pinned = v; W.savePrefs() end
            end },
        { kind = "tick", label = T("followVanillaCraft"), tip = T("followVanillaCraft_tooltip"),
            get = function() return oget("followVanillaCraft", true) == true end,
            set = function(v) oset("followVanillaCraft", v) end },
        { kind = "section", label = getText("IGUI_TWA_Set_Sound") },
        { kind = "slider", label = T("volume"), tip = getText("IGUI_TWA_Set_Volume_Tip"), min = 0, max = 2, step = 0.25,
            get = W.volume, set = W.setVolume,
            fmt = function(v) return v <= 0 and getText("IGUI_TWA_VolumeMuted") or (tostring(math.floor(v * 100 + 0.5)) .. "%") end },
        { kind = "section", label = getText("IGUI_TWA_Set_ZombieHP") },
    }
    for _, d in ipairs(O.DEFS or {}) do
        if d.id:sub(1, 3) == "zhp" then
            local id = d.id
            local r = { label = T(id), tip = T(id .. "_tooltip") }
            if d.kind == "tick" then
                r.kind = "tick"
                r.get = function() return oget(id, false) == true end
                r.set = function(v) oset(id, v) end
            elseif d.kind == "slider" then
                r.kind, r.min, r.max, r.step = "slider", d.min, d.max, d.step
                r.get = function() return tonumber(oget(id, d.min)) or d.min end
                r.set = function(v) oset(id, v) end
                r.fmt = function(v) return tostring(math.floor(v + 0.5)) end
            else
                r.kind = "choice"
                r.values = {}
                for i, k in ipairs(d.keys) do r.values[i] = T(d.prefix .. k) end
                r.get = function() return math.floor(tonumber(oget(id, 1)) or 1) end
                r.set = function(i) oset(id, i) end
            end
            rows[#rows + 1] = r
        end
    end
    rows[#rows + 1] = { kind = "note", label = getText("IGUI_TWA_Set_KeysNote") }
    return rows
end

function W.openSettings()
    if not TWASettingsUI then return end
    TWASettingsUI.open(getText("IGUI_TWA_Set_Title"), W.settingsRows)
end

-- ----------------------------------------------------------------- cards
-- R70 ("หน้าต่างคราฟอยากให้มี card ภายใน แบ่งส่วนต่างๆเหมือนหน้าต่าง ehr"):
-- every part of a page sits in a card -- a dark plate, a thin amber frame
-- with corner marks and a title strip on top (the content starts below it,
-- W.cardTitleH).
W.CARD_T = 26
function W.cardTitleH(S) return S(W.CARD_T) end

function TWACraftWindow:drawCard(x, y, w, h, title)
    local C = W.C
    self:drawRect(x, y, w, h, 0.93, 0.052, 0.042, 0.02)
    self:drawRectBorder(x, y, w, h, 0.75, C.borderDim[1], C.borderDim[2], C.borderDim[3])
    local th = S(self, W.CARD_T)
    self:drawRect(x + 1, y + 1, w - 2, th - 1, 0.55, C.accentDark[1], C.accentDark[2], C.accentDark[3])
    self:drawRect(x + 6, y + th - 1, w - 12, 1, 0.8, C.border[1], C.border[2], C.border[3])
    -- corner marks
    local k = S(self, 9)
    local a, r, g, b = 0.95, C.accent[1], C.accent[2], C.accent[3]
    for _, c in ipairs({ { x, y, 1, 1 }, { x + w, y, -1, 1 }, { x, y + h, 1, -1 }, { x + w, y + h, -1, -1 } }) do
        local cx, cy, dx, dy = c[1], c[2], c[3], c[4]
        self:drawRect(dx > 0 and cx or cx - k, dy > 0 and cy or cy - 2, k, 2, a, r, g, b)
        self:drawRect(dx > 0 and cx or cx - 2, dy > 0 and cy or cy - k, 2, k, a, r, g, b)
    end
    if title and title ~= "" then
        local font = TWAFont.small()
        local fh = getTextManager():getFontHeight(font)
        local t = TWACraftUI.fitText(title, w - 20, font)
        self:drawRect(x + 8, y + math.floor((th - 8) / 2), 3, 8, 1, r, g, b)
        shadowText(self, t, x + 16, y + math.floor((th - fh) / 2), r, g, b, 1, font)
    end
end

-- behind the children (prerender): the cards of the open page
function TWACraftWindow:drawPageCards()
    local th = S(self, W.CARD_T)
    local top = self.contentTop - th - 4
    local bottom = self.panelBottom + 4
    local page = self.page
    if page == "browse" then
        local lw = self.recipeList.x - 10 - 6
        self:drawCard(4, top, lw + 4, bottom - top, getText("IGUI_TWA_Card_Filters"))
        local lx = self.recipeList.x - 6
        local key = self.recipeList.scope == "materials" and "IGUI_TWA_Card_MaterialList" or "IGUI_TWA_Card_WeaponList"
        self:drawCard(lx, top, self.width - 4 - lx, bottom - top, getText(key, tostring(#self.recipeList.items)))
    elseif page == "craft" and not self.selectedRecipe then
        self:drawCard(4, top, self.width - 8, bottom - top, getText("IGUI_TWA_Tab_Craft"))
    elseif page == "craft" or page == "practice" then
        local rx = self.rightX - 4
        local leftKey = page == "practice" and "IGUI_TWA_Card_AllProcedures" or "IGUI_TWA_Card_Recipe"
        self:drawCard(4, top, rx - 6 - 4, bottom - top, getText(leftKey))
        local proc = self.selectedProcId and TWAProcedures.List[self.selectedProcId]
        local title = getText("IGUI_TWA_Card_Procedure")
        if proc then title = title .. ": " .. getText(proc.nameKey) end
        self:drawCard(rx, top, self.width - 4 - rx, bottom - top, title)
    elseif page == "modify" then
        local wpn = self:modifyTarget()
        local title = getText("IGUI_TWA_Card_GemSockets")
        if wpn then title = title .. ": " .. wpn:getDisplayName() end
        self:drawCard(4, top, self.width - 8, bottom - top, title)
    elseif page == "guide" then
        local gw = S(self, 220)
        self:drawCard(4, top, gw + 12, bottom - top, getText("IGUI_TWA_Card_Chapters"))
        local i = math.max(1, math.min(#W.GUIDE, self.guidePage or 1))
        local x = 10 + gw + S(self, 20) - 8
        self:drawCard(x, top, self.width - 4 - x, bottom - top,
            tostring(i) .. ". " .. getText("IGUI_TWA_Guide_" .. W.GUIDE[i].key .. "_Title"))
    end
end

-- ----------------------------------------------------------------- mouse
function TWACraftWindow:workbenchMouseDown(x, y)
    if self.wbCollapsed then
        if y < S(self, W.HEADER_H) then ISPanel.onMouseDown(self, x, y) end
        return true
    end
    if self:inGrip(x, y) then
        self.wbResizing = true
        self.wbResizeMX, self.wbResizeMY = getMouseX(), getMouseY()
        self.wbResizeW, self.wbResizeH = self.width, self.height
        self.wbPreview = self.width / 1000
        self:bringToTop()
        return true
    end
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
    if self.wbResizing then self:resizeMove() return end
    if self.draggingVolume then
        self:volumeFromMouse(self:getMouseX())
        return
    end
    ISPanel.onMouseMove(self, dx, dy)
end

function TWACraftWindow:onMouseMoveOutside(dx, dy)
    if self.wbResizing then self:resizeMove() return end
    if self.draggingVolume then
        self:volumeFromMouse(self:getMouseX())
        return
    end
    ISPanel.onMouseMoveOutside(self, dx, dy)
end

function TWACraftWindow:onMouseUp(x, y)
    if self.wbResizing then self:resizeEnd() return end
    self.draggingVolume = false
    ISPanel.onMouseUp(self, x, y)
end

function TWACraftWindow:onMouseUpOutside(x, y)
    if self.wbResizing then self:resizeEnd() return end
    self.draggingVolume = false
    ISPanel.onMouseUpOutside(self, x, y)
end

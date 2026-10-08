--============================================================================
-- HARMONIE - SVU3 Sandbox -- the vehicle upgrade window (client)
--
-- Request 2026-10-05 ("ทำหน้าต่างเหมือน ehr ได้ไหม แต่สีน้ำเงินเข้ม โดยใช้
-- เท็มเพลตเดียวกันเลย ... และอย่าลืมแท็บคู่มือ"): Home Medic's / The Way To
-- Attack's window layout -- a header bar (title, text size, pin, close), a
-- row of big icon tabs, the content in cards -- in dark navy:
--   1 vehicle   this car: its tier and why, its stats, what is installed,
--               the player's own skills
--   2 upgrades  every upgrade this car takes: the skills it needs (after
--               the tier) against the player's, time, materials, tools
--   3 tiers     every car SVU3 can upgrade, by tier
--   4 guide     how it all works, chapter by chapter
-- It only shows; installing is still done in tsarslib's upgrade window.
--
-- When it opens: together with tsarslib's upgrade window (ISVehicleTuning2,
-- one per player, shown / hidden with setVisible -- getPlayerTuningUI(n)
-- returns it), docked beside it, and it closes with it (Options > Mods can
-- turn that off). A key (Options > Mods, unbound by default) opens it for
-- the car the player sits in or stands next to.
--
-- Everything is drawn in render() (no child widgets), so dragging the size
-- grip just changes the size. The size, text step and pin are kept in
-- Zomboid/Lua/HARMONIE_SVU3_Window.txt (this computer only).
--============================================================================

require "ISUI/ISPanel"

HSVU = HSVU or {}
local H = HSVU

H.HEADER_H = 40
H.TAB_H = 58
H.CARD_T = 26
H.GRIP = 18
H.DEFAULT_W, H.DEFAULT_H = 900, 640
H.MIN_W, H.MIN_H = 720, 480
H.FOLD_DELAY_MS = 350
H.TABS = { "vehicle", "upgrades", "tiers", "guide" }
H.GUIDE = { "Window", "Tiers", "Skills", "Time", "Materials", "Wear", "Admin", "Buttons" }
H.STATS = { "mass", "ends", "seats", "trunk" }
H.SKILL_ORDER = { "MetalWelding", "Mechanics", "Electricity" }

-- dark navy (Home Medic's palette, deeper)
H.C = {
    accent = { 0.45, 0.68, 1.0 },
    accentDark = { 0.06, 0.13, 0.32 },
    background = { 0.012, 0.022, 0.058, 0.97 },
    panel = { 0.022, 0.04, 0.095, 0.94 },
    header = { 0.018, 0.036, 0.10, 0.98 },
    card = { 0.03, 0.055, 0.125, 0.93 },
    border = { 0.32, 0.50, 0.88 },
    borderDim = { 0.14, 0.22, 0.42 },
    text = { 0.93, 0.95, 1.0 },
    textDim = { 0.62, 0.70, 0.85 },
    good = { 0.45, 0.90, 0.50 },
    bad = { 1.0, 0.46, 0.40 },
    warn = { 1.0, 0.80, 0.32 },
}

local UI_DIR = "media/textures/HSVU_UI/"
local tex = {}
local function texture(path)
    if not path then return nil end
    if tex[path] == nil then tex[path] = getTexture(path) or false end
    return tex[path] or nil
end

-- ----------------------------------------------------------------- text
local FONTS = { "Small", "Medium", "Large" }
H.textStep = 0
local function fontAt(level)
    level = math.max(1, math.min(#FONTS, level))
    return UIFont[FONTS[level]] or UIFont.Small
end
function H.small() return fontAt(1 + H.textStep) end
function H.medium() return fontAt(2 + H.textStep) end
local function fh(font) return getTextManager():getFontHeight(font) end
local function lineH(font) return fh(font) + 2 end
local function tw(font, s) return getTextManager():MeasureStringX(font, s) end

local function T(key, ...)
    local ok, s = pcall(getText, key, ...)
    return ok and s or key
end

local function shadowText(panel, s, x, y, c, a, font)
    a = a or 1
    panel:drawText(s, x + 1, y + 1, 0, 0, 0, a * 0.8, font)
    panel:drawText(s, x, y, c[1], c[2], c[3], a, font)
end

local function fit(s, maxW, font)
    s = tostring(s or "")
    if tw(font, s) <= maxW then return s end
    while #s > 1 and tw(font, s .. "...") > maxW do s = s:sub(1, -2) end
    return s .. "..."
end

local function wrap(text, maxW, font)
    local out = {}
    for para in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in para:gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            if tw(font, try) > maxW and line ~= "" then
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

-- ----------------------------------------------------------------- data
local Cap = function() return HARMONIE_SVU3SkillCap end

function H.scriptName(vehicle)
    if not vehicle then return nil end
    local ok, n = pcall(function() return vehicle:getScript():getName() end)
    return ok and n or nil
end

function H.carName(name)
    if not name then return "" end
    local key = "IGUI_VehicleName" .. name
    local s = T(key)
    if s == key or s == "" then return name end
    return s
end

local perkNames = {}
function H.perkName(id)
    if perkNames[id] then return perkNames[id] end
    local ok, n = pcall(function() return PerkFactory.getPerk(Perks.FromString(id)):getName() end)
    perkNames[id] = (ok and n and n ~= "") and n or id
    return perkNames[id]
end

function H.perkLevel(player, id)
    if not player then return 0 end
    local ok, v = pcall(function() return player:getPerkLevel(Perks.FromString(id)) end)
    return ok and tonumber(v) or 0
end

local itemNames = {}
function H.itemName(t)
    t = tostring(t):gsub("__", ".")
    if itemNames[t] then return itemNames[t] end
    local full = t:find(".", 1, true) and t or ("Base." .. t)
    local name = t:match("([^%.]+)$") or t
    local ok, it = pcall(function() return getScriptManager():FindItem(full) end)
    if ok and it then
        local ok2, n = pcall(it.getDisplayName, it)
        if ok2 and n and n ~= "" then name = n end
    end
    itemNames[t] = name
    return name
end

-- the upgrade's own name; else the part's; else the part id made readable
-- ("ATA2RadioAntenna" -> "Radio Antenna")
local function modelName(info, partName)
    if info and info.name and info.name ~= "" then
        local s = T(info.name)
        if s ~= info.name then return s end
    end
    local key = "IGUI_VehiclePart" .. tostring(partName)
    local s = T(key)
    if s ~= key then return s end
    return (tostring(partName):gsub("^ATA2", ""):gsub("(%l)(%u)", "%1 %2"))
end

local function categoryName(info)
    if info and info.category and info.category ~= "" then return T("IGUI_TuningCategory_" .. info.category) end
    return T("IGUI_TuningCategory_General")
end

-- time an install takes for this player, against SVU3's full time
-- (tsarslib: (time - Mechanics x time / 15) x 100)
function H.timeFactor(player)
    return math.max(0, 1 - H.perkLevel(player, "Mechanics") / 15)
end

-- "x0.67" style (no percent sign: the game's text formatter rejects a bare one)
function H.factorText(f)
    return string.format("%.2f", f)
end

local function sortedSkills(skills, player)
    local out = {}
    for id, need in pairs(skills or {}) do
        if type(need) == "number" and need > 0 then
            out[#out + 1] = { id = id, need = need, have = H.perkLevel(player, id) }
        end
    end
    table.sort(out, function(a, b)
        if a.need ~= b.need then return a.need > b.need end
        return a.id < b.id
    end)
    return out
end

-- every upgrade this car takes (only parts the car has), with its state
function H.upgradeRows(vehicle, player)
    local rows = {}
    local name = H.scriptName(vehicle)
    local car = name and ATA2TuningTable and ATA2TuningTable[name]
    if type(car) ~= "table" or type(car.parts) ~= "table" then return rows end
    for partName, models in pairs(car.parts) do
        local vp = vehicle:getPartById(partName)
        if vp and type(models) == "table" then
            local installed
            if vp:getInventoryItem() then
                local md = vp:getModData() and vp:getModData().tuning2
                installed = md and md.model or "?"
            end
            for mName, info in pairs(models) do
                local inst = type(info) == "table" and info.install
                if type(inst) == "table" then
                    local r = {
                        part = partName, model = mName, info = info,
                        name = modelName(info, partName), category = categoryName(info),
                        icon = info.icon, time = tonumber(inst.time),
                        skills = sortedSkills(inst.skills, player),
                        installed = installed == mName,
                        condition = (installed == mName) and vp:getCondition() or nil,
                    }
                    r.skillOk = true
                    for _, s in ipairs(r.skills) do if s.have < s.need then r.skillOk = false end end
                    if inst.requireModel and inst.requireModel ~= "" and installed ~= inst.requireModel then
                        r.needFirst = modelName(models[inst.requireModel], partName)
                    elseif installed and not r.installed then
                        r.occupied = true
                    end
                    r.use = {}
                    for item, n in pairs(inst.use or {}) do
                        r.use[#r.use + 1] = H.itemName(item) .. " x" .. tostring(n)
                    end
                    table.sort(r.use)
                    r.tools = {}
                    for _, item in pairs(inst.tools or {}) do r.tools[#r.tools + 1] = H.itemName(item) end
                    table.sort(r.tools)
                    rows[#rows + 1] = r
                end
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.category ~= b.category then return a.category < b.category end
        if a.name ~= b.name then return a.name < b.name end
        return a.model < b.model
    end)
    return rows
end

function H.rowState(r)
    if r.installed then return "Installed", H.C.accent end
    if r.needFirst then return "NeedFirst", H.C.warn end
    if r.occupied then return "Occupied", H.C.textDim end
    if r.skillOk then return "Ready", H.C.good end
    return "NoSkill", H.C.bad
end

-- this car's tier and why
function H.tierInfo(name)
    local C = Cap()
    local car = name and ATA2TuningTable and ATA2TuningTable[name]
    if not C or not car then return nil end
    local info = { enabled = C.enabled and C.enabled() }
    info.tier = car.__harmonieTier
    info.manual = car.__harmonieManual
    info.stats = C.statsOf and C.statsOf[name]
    if info.tier and C.tierCeiling then info.main, info.second = C.tierCeiling(info.tier) end
    return info
end

-- where a car's stat sits among every car with that stat (0 = lowest, 1 = highest)
function H.statPlace(name, key)
    local C = Cap()
    local all = C and C.statsOf
    local mine = all and all[name] and all[name][key]
    if not mine then return nil end
    local below, n = 0, 0
    for _, st in pairs(all) do
        if st[key] then
            n = n + 1
            if st[key] < mine then below = below + 1 end
        end
    end
    if n <= 1 then return 1 end
    return below / (n - 1)
end

function H.tierLists()
    local lists = { {}, {}, {} }
    for name, car in pairs(ATA2TuningTable or {}) do
        if type(car) == "table" and car.__harmonieTier and lists[car.__harmonieTier] then
            table.insert(lists[car.__harmonieTier], { name = name, label = H.carName(name), manual = car.__harmonieManual })
        end
    end
    for _, l in ipairs(lists) do table.sort(l, function(a, b) return a.label < b.label end) end
    return lists
end

-- ----------------------------------------------------------------- prefs
H.PREFS_FILE = "HARMONIE_SVU3_Window.txt"
H.pinned = true
function H.ensurePrefs()
    if H.prefsLoaded then return end
    H.prefsLoaded = true
    if not getFileReader then return end
    local ok, reader = pcall(getFileReader, H.PREFS_FILE, true)
    if not ok or not reader then return end
    pcall(function()
        local line = reader:readLine()
        while line do
            local k, v = line:match("^%s*([%w_]+)%s*=%s*(%S+)")
            if k == "w" then H.prefW = tonumber(v)
            elseif k == "h" then H.prefH = tonumber(v)
            elseif k == "text" then H.textStep = math.max(0, math.min(2, math.floor(tonumber(v) or 0)))
            elseif k == "pinned" then H.pinned = v ~= "0" end
            line = reader:readLine()
        end
    end)
    pcall(function() reader:close() end)
end

function H.savePrefs()
    if not getFileWriter then return end
    local ok, writer = pcall(getFileWriter, H.PREFS_FILE, true, false)
    if not ok or not writer then return end
    pcall(function()
        if H.prefW then writer:write("w=" .. tostring(math.floor(H.prefW)) .. "\n") end
        if H.prefH then writer:write("h=" .. tostring(math.floor(H.prefH)) .. "\n") end
        writer:write("text=" .. tostring(H.textStep) .. "\n")
        writer:write("pinned=" .. (H.pinned and "1" or "0") .. "\n")
    end)
    pcall(function() writer:close() end)
end

-- ----------------------------------------------------------------- window
HSVUWindow = ISPanel:derive("HSVUWindow")
local Win = HSVUWindow

function Win:new(x, y, w, h, player)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.tab = "vehicle"
    o.scroll = {}
    o.maxScroll = {}
    o.filter = "all"
    o.guidePage = 1
    o.moveWithMouse = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    return o
end

function Win:setVehicle(vehicle)
    self.vehicle = vehicle
    self.scroll = {}
    self:refreshData()
end

function Win:refreshData()
    self.dataAt = getTimestampMs and getTimestampMs() or 0
    self.carName = H.scriptName(self.vehicle)
    self.rows = self.vehicle and H.upgradeRows(self.vehicle, self.player) or {}
    self.tiers = H.tierInfo(self.carName)
    self.tierLists = H.tierLists()
end

function Win:contentTop() return H.HEADER_H + H.TAB_H + 6 end

-- header buttons, right to left: close, pin, A+, A-
function Win:headerButtons()
    local s = 26
    local y = math.floor((H.HEADER_H - s) / 2)
    local x = self.width - s - 8
    local b = {}
    for _, id in ipairs({ "close", "pin", "plus", "minus" }) do
        b[#b + 1] = { id = id, x = x, y = y, w = s, h = s }
        x = x - s - 6
    end
    return b
end

local function inside(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- ----------------------------------------------------------------- drawing
function Win:drawCard(x, y, w, h, title)
    local C = H.C
    self:drawRect(x, y, w, h, C.card[4], C.card[1], C.card[2], C.card[3])
    self:drawRectBorder(x, y, w, h, 0.75, C.borderDim[1], C.borderDim[2], C.borderDim[3])
    local th = H.CARD_T
    self:drawRect(x + 1, y + 1, w - 2, th - 1, 0.6, C.accentDark[1], C.accentDark[2], C.accentDark[3])
    self:drawRect(x + 6, y + th - 1, w - 12, 1, 0.8, C.border[1], C.border[2], C.border[3])
    local k = 9
    for _, c in ipairs({ { x, y, 1, 1 }, { x + w, y, -1, 1 }, { x, y + h, 1, -1 }, { x + w, y + h, -1, -1 } }) do
        local cx, cy, dx, dy = c[1], c[2], c[3], c[4]
        self:drawRect(dx > 0 and cx or cx - k, dy > 0 and cy or cy - 2, k, 2, 0.95, C.accent[1], C.accent[2], C.accent[3])
        self:drawRect(dx > 0 and cx or cx - 2, dy > 0 and cy or cy - k, 2, k, 0.95, C.accent[1], C.accent[2], C.accent[3])
    end
    if title and title ~= "" then
        local font = H.small()
        self:drawRect(x + 8, y + math.floor((th - 8) / 2), 3, 8, 1, C.accent[1], C.accent[2], C.accent[3])
        shadowText(self, fit(title, w - 24, font), x + 16, y + math.floor((th - fh(font)) / 2), C.accent, 1, font)
    end
    return x + 10, y + th + 6, w - 20, h - th - 12
end

function Win:drawBar(x, y, w, h, frac, col)
    local C = H.C
    self:drawRect(x, y, w, h, 0.9, 0.05, 0.08, 0.16)
    self:drawRect(x, y, math.floor(w * math.max(0, math.min(1, frac))), h, 1, col[1], col[2], col[3])
    self:drawRectBorder(x, y, w, h, 0.8, C.borderDim[1], C.borderDim[2], C.borderDim[3])
end

function Win:prerender()
    local C = H.C
    local hh, th = H.HEADER_H, H.TAB_H
    self:drawRect(0, 0, self.width, self.height, C.background[4], C.background[1], C.background[2], C.background[3])
    self:drawRectBorder(0, 0, self.width, self.height, 1, C.border[1], C.border[2], C.border[3])
    self:drawRect(1, 1, self.width - 2, hh - 1, C.header[4], C.header[1], C.header[2], C.header[3])
    self:drawRect(0, hh - 1, self.width, 1, 0.8, C.border[1], C.border[2], C.border[3])
    -- title
    local font = H.medium()
    local ix = 10
    local logo = texture(UI_DIR .. "tab_vehicle.png")
    if logo then
        self:drawTextureScaled(logo, ix, math.floor((hh - 28) / 2), 28, 28, 1, 1, 1, 1)
        ix = ix + 34
    end
    local title = T("IGUI_HSVU_Title")
    if self.carName then title = title .. " - " .. H.carName(self.carName) end
    shadowText(self, fit(title, self.width - ix - 150, font), ix, math.floor((hh - fh(font)) / 2), C.accent, 1, font)
    -- header buttons
    self.hoverTip = nil
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, b in ipairs(self:headerButtons()) do
        local over = inside(b, mx, my)
        local tint = b.id == "close" and { 0.95, 0.4, 0.35 } or C.accent
        self:drawRect(b.x, b.y, b.w, b.h, over and 0.95 or 0.75, 0.04, 0.08, 0.2)
        self:drawRectBorder(b.x, b.y, b.w, b.h, over and 1 or 0.7, tint[1], tint[2], tint[3])
        local name = b.id == "pin" and (H.pinned and "pin_on" or "pin_off") or ("icon_" .. b.id)
        local icon = texture(UI_DIR .. name .. ".png")
        local disabled = (b.id == "plus" and H.textStep >= 2) or (b.id == "minus" and H.textStep <= 0)
        if icon then
            self:drawTextureScaled(icon, b.x + 3, b.y + 3, b.w - 6, b.h - 6, disabled and 0.35 or 1, 1, 1, 1)
        end
        if over then
            local key = ({ close = "IGUI_HSVU_Close", pin = H.pinned and "IGUI_HSVU_Unpin" or "IGUI_HSVU_Pin",
                plus = "IGUI_HSVU_TextBigger", minus = "IGUI_HSVU_TextSmaller" })[b.id]
            self.hoverTip = { text = T(key), x = b.x - 40, y = b.y + b.h + 4 }
        end
    end
    if self.collapsed then return end
    -- tabs
    self:drawRect(1, hh, self.width - 2, th, 0.92, 0.012, 0.024, 0.07)
    self:drawRect(0, hh + th - 1, self.width, 1, 0.8, C.border[1], C.border[2], C.border[3])
    local gap = 5
    local tabW = math.floor((self.width - 16 - gap * (#H.TABS - 1)) / #H.TABS)
    local x = 8
    self.tabBounds = {}
    local sf = H.small()
    for _, id in ipairs(H.TABS) do
        local active = self.tab == id
        local ty, tH = hh + 6, th - 12
        local bg = active and C.accentDark or C.background
        local bd = active and C.accent or C.borderDim
        self:drawRect(x, ty, tabW, tH, active and 0.98 or 0.82, bg[1], bg[2], bg[3])
        self:drawRectBorder(x, ty, tabW, tH, active and 0.95 or 0.62, bd[1], bd[2], bd[3])
        if active then
            self:drawRect(x + 2, ty + 2, tabW - 4, tH - 4, 0.16, C.accent[1], C.accent[2], C.accent[3])
            self:drawRect(x + 3, ty + tH - 5, tabW - 6, 2, 0.75, C.accent[1], C.accent[2], C.accent[3])
        end
        local size = math.min(tH - 8, 40)
        local label = fit(T("IGUI_HSVU_Tab_" .. id), tabW - size - 24, sf)
        local icon = texture(UI_DIR .. "tab_" .. id .. ".png")
        local total = size + 8 + tw(sf, label)
        local tx = x + math.floor((tabW - total) / 2)
        if icon then self:drawTextureScaled(icon, tx, ty + math.floor((tH - size) / 2), size, size, active and 1 or 0.65, 1, 1, 1) end
        shadowText(self, label, tx + size + 8, ty + math.floor((tH - fh(sf)) / 2), active and C.text or C.textDim, 1, sf)
        local bounds = { id = id, x = x, y = ty, w = tabW, h = tH }
        self.tabBounds[#self.tabBounds + 1] = bounds
        if inside(bounds, mx, my) then
            self.hoverTip = { text = T("IGUI_HSVU_Tab_" .. id .. "_Tip"), x = x + 30, y = ty + tH + 4 }
        end
        x = x + tabW + gap
    end
    local top = hh + th + 2
    self:drawRect(4, top, self.width - 8, self.height - top - 4, C.panel[4], C.panel[1], C.panel[2], C.panel[3])
end

function Win:render()
    if not self.collapsed then
        self.scrollBox = {}
        local now = getTimestampMs and getTimestampMs() or 0
        if not self.dataAt or now - self.dataAt > 2000 then self:refreshData() end
        local x, y = 8, self:contentTop()
        local w, h = self.width - 16, self.height - y - 8
        if self.tab == "vehicle" then self:renderVehicle(x, y, w, h)
        elseif self.tab == "upgrades" then self:renderUpgrades(x, y, w, h)
        elseif self.tab == "tiers" then self:renderTiers(x, y, w, h)
        else self:renderGuide(x, y, w, h) end
        -- size grip
        local C = H.C
        local gx, gy = self.width - 16, self.height - 16
        for i, len in ipairs({ 12, 8, 4 }) do
            local o = (i - 1) * 4
            self:drawRect(gx + 10 - o, gy + 14 - len, 2, len, 0.85 - 0.15 * (i - 1), C.accent[1], C.accent[2], C.accent[3])
        end
    end
    self:drawHoverTip()
    self:updatePin()
end

function Win:drawHoverTip()
    local t = self.hoverTip
    if not t or not t.text or t.text == "" or t.text:find("IGUI_", 1, true) then return end
    local C = H.C
    local font = H.small()
    local lines = wrap(t.text, 340, font)
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, tw(font, l)) end
    w = w + 16
    local h = #lines * lineH(font) + 10
    local x = math.max(4, math.min(self.width - w - 4, t.x))
    local y = t.y
    self:drawRect(x, y, w, h, 0.97, 0.02, 0.04, 0.1)
    self:drawRectBorder(x, y, w, h, 1, C.border[1], C.border[2], C.border[3])
    for i, l in ipairs(lines) do shadowText(self, l, x + 8, y + 5 + (i - 1) * lineH(font), C.text, 1, font) end
end

local function noVehicle(self, x, y, w)
    local font = H.medium()
    for i, l in ipairs(wrap(T("IGUI_HSVU_NoVehicle"), w - 40, font)) do
        shadowText(self, l, x + 20, y + 20 + (i - 1) * lineH(font), H.C.text, 1, font)
    end
end

-- scrolled content: draws f(yOffset) clipped to the box, remembers how far it can scroll
function Win:scrolled(key, x, y, w, h, f)
    local off = self.scroll[key] or 0
    -- registered before drawing (hover checks inside f use it); the list
    -- holds only this frame's areas -- render() empties it -- so the mouse
    -- wheel never lands on an area of another tab / vitamin / search that
    -- happens to sit at the same spot (2026-10-08 bug report: "บางอัน
    -- scroll ไม่ได้")
    self.scrollBox = self.scrollBox or {}
    self.scrollBox[key] = { x = x, y = y, w = w, h = h }
    self:setStencilRect(x, y, w, h)
    local used = f(y - off)
    self:clearStencilRect()
    self.maxScroll[key] = math.max(0, (used or 0) - h)
    if off > self.maxScroll[key] then self.scroll[key] = self.maxScroll[key] end
    if self.maxScroll[key] > 0 then
        local C = H.C
        local bh = math.max(20, math.floor(h * h / (h + self.maxScroll[key])))
        local by = y + math.floor((h - bh) * (self.scroll[key] or 0) / self.maxScroll[key])
        self:drawRect(x + w - 4, by, 3, bh, 0.8, C.accent[1], C.accent[2], C.accent[3])
    end
end

-- ----------------------------------------------------------------- tab 1
function Win:renderVehicle(x, y, w, h)
    local C = H.C
    if not self.vehicle then noVehicle(self, x, y, w) return end
    local sf, mf = H.small(), H.medium()
    local lh = lineH(sf)
    local half = math.floor((w - 8) / 2)
    local topH = math.floor(h * 0.52)
    -- card: this car
    local cx, cy, cw = self:drawCard(x, y, half, topH, T("IGUI_HSVU_Card_Car"))
    shadowText(self, fit(H.carName(self.carName), cw, mf), cx, cy, C.text, 1, mf)
    cy = cy + lineH(mf)
    shadowText(self, fit(self.carName or "", cw, sf), cx, cy, C.textDim, 1, sf)
    cy = cy + lh + 6
    local ti = self.tiers
    local lines
    if not ti or not ti.enabled then
        lines = { { T("IGUI_HSVU_TierOff"), C.warn } }
    elseif ti.tier then
        shadowText(self, T("IGUI_HSVU_TierLine", tostring(ti.tier), tostring(ti.main), tostring(ti.second)), cx, cy, C.accent, 1, mf)
        cy = cy + lineH(mf) + 2
        local why = ti.manual and "IGUI_HSVU_TierWhyAdmin" or (ti.stats and "IGUI_HSVU_TierWhyStats" or "IGUI_HSVU_TierWhyNone")
        lines = { { T(why), C.textDim } }
    else
        lines = { { T("IGUI_HSVU_TierNone"), C.textDim } }
    end
    for _, l in ipairs(lines) do
        for _, s in ipairs(wrap(l[1], cw, sf)) do
            if cy + lh > y + topH - 6 then break end
            shadowText(self, s, cx, cy, l[2], 1, sf)
            cy = cy + lh
        end
    end
    -- card: its stats
    local sx = x + half + 8
    cx, cy, cw = self:drawCard(sx, y, w - half - 8, topH, T("IGUI_HSVU_Card_Stats"))
    local st = ti and ti.stats
    if not st then
        for i, s in ipairs(wrap(T("IGUI_HSVU_NoStats"), cw, sf)) do shadowText(self, s, cx, cy + (i - 1) * lh, C.textDim, 1, sf) end
    else
        local rowH = lh * 2 + 6
        for _, key in ipairs(H.STATS) do
            if cy + rowH > y + topH - 4 then break end
            local v = st[key]
            local label = T("IGUI_HSVU_Stat_" .. key)
            shadowText(self, label, cx, cy, C.text, 1, sf)
            local vs = v and tostring(math.floor(v + 0.5)) or T("IGUI_HSVU_StatUnknown")
            shadowText(self, vs, cx + cw - tw(sf, vs), cy, v and C.text or C.textDim, 1, sf)
            local place = v and H.statPlace(self.carName, key)
            self:drawBar(cx, cy + lh + 2, cw, 6, place or 0, place and C.accent or C.borderDim)
            cy = cy + rowH
        end
    end
    -- card: installed upgrades
    local by = y + topH + 8
    local bh = h - topH - 8
    cx, cy, cw = self:drawCard(x, by, half, bh, T("IGUI_HSVU_Card_Installed"))
    local installed = {}
    for _, r in ipairs(self.rows or {}) do if r.installed then installed[#installed + 1] = r end end
    self:scrolled("installed", cx, cy, cw, by + bh - 6 - cy, function(yy)
        if #installed == 0 then
            shadowText(self, T("IGUI_HSVU_NothingInstalled"), cx, yy, C.textDim, 1, sf)
            return lh
        end
        local start = yy
        for _, r in ipairs(installed) do
            local icon = texture(r.icon)
            if icon then self:drawTextureScaled(icon, cx, yy, lh * 2, lh * 2, 1, 1, 1, 1) end
            local tx = cx + lh * 2 + 6
            shadowText(self, fit(r.name, cw - (tx - cx) - 60, sf), tx, yy, C.text, 1, sf)
            local cond = r.condition or 0
            local cs = tostring(cond) .. "%"
            shadowText(self, cs, cx + cw - tw(sf, cs) - 6, yy, cond >= 50 and C.good or (cond >= 20 and C.warn or C.bad), 1, sf)
            self:drawBar(tx, yy + lh + 2, cw - (tx - cx) - 6, 5, cond / 100, cond >= 50 and C.good or (cond >= 20 and C.warn or C.bad))
            yy = yy + lh * 2 + 8
        end
        return yy - start
    end)
    -- card: the player's skills
    cx, cy, cw = self:drawCard(sx, by, w - half - 8, bh, T("IGUI_HSVU_Card_You"))
    for _, id in ipairs(H.SKILL_ORDER) do
        if cy + lh > by + bh - 6 then break end
        local lvl = H.perkLevel(self.player, id)
        shadowText(self, fit(H.perkName(id), cw - 40, sf), cx, cy, C.text, 1, sf)
        local ls = tostring(lvl)
        shadowText(self, ls, cx + cw - tw(sf, ls) - 6, cy, C.accent, 1, sf)
        cy = cy + lh + 2
    end
    for _, s in ipairs(wrap(T("IGUI_HSVU_YourTime", H.factorText(H.timeFactor(self.player))), cw, sf)) do
        if cy + lh > by + bh - 6 then break end
        cy = cy + 2
        shadowText(self, s, cx, cy, C.textDim, 1, sf)
        cy = cy + lh
    end
end

-- ----------------------------------------------------------------- tab 2
H.FILTERS = { "all", "ready", "installed" }
local function passes(filter, r)
    if filter == "ready" then return not r.installed and not r.needFirst and not r.occupied and r.skillOk end
    if filter == "installed" then return r.installed end
    return true
end

function Win:renderUpgrades(x, y, w, h)
    local C = H.C
    if not self.vehicle then noVehicle(self, x, y, w) return end
    local sf = H.small()
    local lh = lineH(sf)
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, T("IGUI_HSVU_Card_Upgrades", tostring(#(self.rows or {}))))
    -- filter chips
    self.chips = {}
    local fx = cx
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, f in ipairs(H.FILTERS) do
        local label = T("IGUI_HSVU_Filter_" .. f)
        local bw = tw(sf, label) + 20
        local b = { id = f, x = fx, y = cy, w = bw, h = lh + 6 }
        local active = self.filter == f
        local over = inside(b, mx, my)
        self:drawRect(b.x, b.y, b.w, b.h, active and 0.95 or (over and 0.9 or 0.75), active and C.accentDark[1] or 0.03,
            active and C.accentDark[2] or 0.06, active and C.accentDark[3] or 0.14)
        self:drawRectBorder(b.x, b.y, b.w, b.h, active and 1 or 0.6, (active and C.accent or C.borderDim)[1],
            (active and C.accent or C.borderDim)[2], (active and C.accent or C.borderDim)[3])
        shadowText(self, label, b.x + 10, b.y + 3, active and C.text or C.textDim, 1, sf)
        self.chips[#self.chips + 1] = b
        fx = fx + bw + 6
    end
    local hint = fit(T("IGUI_HSVU_UpgradesHint"), cx + cw - fx - 10, sf)
    shadowText(self, hint, cx + cw - tw(sf, hint), cy + 3, C.textDim, 1, sf)
    cy = cy + lh + 12
    local factor = H.timeFactor(self.player)
    self:scrolled("upgrades", cx, cy, cw, y + h - 6 - cy, function(yy)
        local start = yy
        local cat
        local any = false
        for _, r in ipairs(self.rows or {}) do
            if passes(self.filter, r) then
                any = true
                if r.category ~= cat then
                    cat = r.category
                    yy = yy + 2
                    self:drawRect(cx, yy + lh - 1, cw - 8, 1, 0.6, C.border[1], C.border[2], C.border[3])
                    shadowText(self, cat, cx, yy, C.accent, 1, sf)
                    yy = yy + lh + 4
                end
                local rowH = lh * 3 + 10
                self:drawRect(cx, yy, cw - 8, rowH - 4, 0.55, 0.03, 0.06, 0.15)
                local icon = texture(r.icon)
                local isz = rowH - 12
                if icon then self:drawTextureScaled(icon, cx + 4, yy + 4, isz, isz, 1, 1, 1, 1) end
                local tx = cx + isz + 12
                local right = cx + cw - 14
                local stateKey, stateCol = H.rowState(r)
                local state = T("IGUI_HSVU_State_" .. stateKey, r.needFirst or "")
                local stW = tw(sf, state)
                shadowText(self, state, right - stW, yy + 3, stateCol, 1, sf)
                shadowText(self, fit(r.name, right - stW - 12 - tx, sf), tx, yy + 3, C.text, 1, sf)
                -- skills, the player's level beside each
                local sx = tx
                for i, s in ipairs(r.skills) do
                    local part = H.perkName(s.id) .. " " .. tostring(s.need) .. " (" .. tostring(s.have) .. ")"
                    if i < #r.skills then part = part .. "  " end
                    local col = s.have >= s.need and C.good or C.bad
                    if sx + tw(sf, part) > right then break end
                    shadowText(self, part, sx, yy + 3 + lh, col, 1, sf)
                    sx = sx + tw(sf, part)
                end
                if #r.skills == 0 then shadowText(self, T("IGUI_HSVU_NoSkillNeeded"), tx, yy + 3 + lh, C.textDim, 1, sf) end
                local ts = r.time and T("IGUI_HSVU_TimeShort", tostring(r.time), H.factorText(factor)) or ""
                shadowText(self, ts, right - tw(sf, ts), yy + 3 + lh, C.textDim, 1, sf)
                local mat = table.concat(r.use, ", ")
                if #r.tools > 0 then mat = mat .. "  |  " .. table.concat(r.tools, ", ") end
                shadowText(self, fit(mat, right - tx, sf), tx, yy + 3 + lh * 2, C.textDim, 1, sf)
                if inside({ x = tx, y = yy + 3 + lh * 2, w = right - tx, h = lh }, self:getMouseX(), self:getMouseY())
                    and inside(self.scrollBox and self.scrollBox.upgrades or { x = 0, y = 0, w = 0, h = 0 }, self:getMouseX(), self:getMouseY()) then
                    self.hoverTip = { text = T("IGUI_HSVU_Materials") .. ": " .. table.concat(r.use, ", ") .. "\n"
                        .. T("IGUI_HSVU_Tools") .. ": " .. table.concat(r.tools, ", "), x = tx, y = yy + rowH }
                end
                yy = yy + rowH
            end
        end
        if not any then
            shadowText(self, T("IGUI_HSVU_NoUpgrades"), cx, yy, C.textDim, 1, sf)
            yy = yy + lh
        end
        return yy - start
    end)
end

-- ----------------------------------------------------------------- tab 3
function Win:renderTiers(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local Cp = Cap()
    if not (Cp and Cp.enabled and Cp.enabled()) then
        local cx, cy, cw = self:drawCard(x, y, w, h, T("IGUI_HSVU_Tab_tiers"))
        for i, s in ipairs(wrap(T("IGUI_HSVU_TierOff"), cw, sf)) do shadowText(self, s, cx, cy + (i - 1) * lh, C.warn, 1, sf) end
        return
    end
    local gap = 8
    local colW = math.floor((w - gap * 2) / 3)
    for t = 1, 3 do
        local main, second = Cp.tierCeiling(t)
        local list = (self.tierLists or {})[t] or {}
        local cx, cy, cw = self:drawCard(x + (t - 1) * (colW + gap), y, colW, h,
            T("IGUI_HSVU_TierCard", tostring(t), tostring(main), tostring(second), tostring(#list)))
        self:scrolled("tier" .. t, cx, cy, cw, y + h - 6 - cy, function(yy)
            local start = yy
            for _, e in ipairs(list) do
                local mine = e.name == self.carName
                if mine then self:drawRect(cx, yy - 1, cw - 6, lh + 2, 0.5, C.accentDark[1], C.accentDark[2], C.accentDark[3]) end
                local label = e.label
                if e.label ~= e.name then label = label .. " (" .. e.name .. ")" end
                if e.manual then label = label .. " " .. T("IGUI_HSVU_AdminMark") end
                shadowText(self, fit(label, cw - 10, sf), cx + 2, yy, mine and C.accent or (e.manual and C.warn or C.text), 1, sf)
                yy = yy + lh
            end
            return yy - start
        end)
    end
end

-- ----------------------------------------------------------------- tab 4
function Win:renderGuide(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local listW = math.min(260, math.floor(w * 0.3))
    local cx, cy, cw = self:drawCard(x, y, listW, h, T("IGUI_HSVU_Card_Chapters"))
    self.chapterBounds = {}
    local mx, my = self:getMouseX(), self:getMouseY()
    for i, key in ipairs(H.GUIDE) do
        local b = { i = i, x = cx, y = cy, w = cw, h = lh + 8 }
        if b.y + b.h > y + h - 6 then break end
        local active = self.guidePage == i
        local over = inside(b, mx, my)
        if active or over then
            self:drawRect(b.x, b.y, b.w, b.h, active and 0.9 or 0.5, C.accentDark[1], C.accentDark[2], C.accentDark[3])
        end
        if active then self:drawRect(b.x, b.y, 3, b.h, 1, C.accent[1], C.accent[2], C.accent[3]) end
        shadowText(self, fit(tostring(i) .. ". " .. T("IGUI_HSVU_Guide_" .. key .. "_Title"), cw - 12, sf), b.x + 8, b.y + 4,
            active and C.text or C.textDim, 1, sf)
        self.chapterBounds[#self.chapterBounds + 1] = b
        cy = cy + b.h + 2
    end
    local key = H.GUIDE[self.guidePage] or H.GUIDE[1]
    local gx = x + listW + 8
    local tx, ty, tw2, th2 = self:drawCard(gx, y, w - listW - 8, h,
        tostring(self.guidePage) .. ". " .. T("IGUI_HSVU_Guide_" .. key .. "_Title"))
    local body = T("IGUI_HSVU_Guide_" .. key .. "_Body")
    self:scrolled("guide" .. key, tx, ty, tw2, th2, function(yy)
        local start = yy
        for _, l in ipairs(wrap(body, tw2 - 12, sf)) do
            shadowText(self, l, tx, yy, C.text, 1, sf)
            yy = yy + lh
        end
        return yy - start
    end)
end

-- ----------------------------------------------------------------- mouse
function Win:onMouseDown(x, y)
    if y < H.HEADER_H then
        for _, b in ipairs(self:headerButtons()) do
            if inside(b, x, y) then
                getSoundManager():playUISound("UISelectListItem")
                if b.id == "close" then H.close()
                elseif b.id == "pin" then self:togglePin()
                elseif b.id == "plus" then H.stepText(1)
                elseif b.id == "minus" then H.stepText(-1) end
                return true
            end
        end
        return ISPanel.onMouseDown(self, x, y)
    end
    if self.collapsed then return true end
    if x >= self.width - H.GRIP and y >= self.height - H.GRIP then
        self.resizing = true
        self.resizeMX, self.resizeMY = getMouseX(), getMouseY()
        self.resizeW, self.resizeH = self.width, self.height
        self:bringToTop()
        return true
    end
    for _, t in ipairs(self.tabBounds or {}) do
        if inside(t, x, y) then
            getSoundManager():playUISound("UISelectListItem")
            self.tab = t.id
            self:refreshData()
            return true
        end
    end
    if self.tab == "upgrades" then
        for _, c in ipairs(self.chips or {}) do
            if inside(c, x, y) then
                getSoundManager():playUISound("UISelectListItem")
                self.filter = c.id
                self.scroll.upgrades = 0
                return true
            end
        end
    elseif self.tab == "guide" then
        for _, b in ipairs(self.chapterBounds or {}) do
            if inside(b, x, y) then
                getSoundManager():playUISound("UISelectListItem")
                self.guidePage = b.i
                return true
            end
        end
    end
    return true
end

function Win:onMouseWheel(del)
    local x, y = self:getMouseX(), self:getMouseY()
    for key, box in pairs(self.scrollBox or {}) do
        if inside(box, x, y) and (self.maxScroll[key] or 0) > 0 then
            local step = lineH(H.small()) * 3
            self.scroll[key] = math.max(0, math.min(self.maxScroll[key], (self.scroll[key] or 0) + del * step))
            return true
        end
    end
    return true
end

function Win:resizeTo()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w = math.max(H.MIN_W, math.min(sw - 20, self.resizeW + getMouseX() - self.resizeMX))
    local h = math.max(H.MIN_H, math.min(sh - 20, self.resizeH + getMouseY() - self.resizeMY))
    self:setWidth(w)
    self:setHeight(h)
end

function Win:onMouseMove(dx, dy)
    if self.resizing then self:resizeTo() return end
    ISPanel.onMouseMove(self, dx, dy)
end

function Win:onMouseMoveOutside(dx, dy)
    if self.resizing then self:resizeTo() return end
    ISPanel.onMouseMoveOutside(self, dx, dy)
end

local function endResize(self)
    if not self.resizing then return false end
    self.resizing = false
    H.prefW, H.prefH = self.width, self.height
    H.savePrefs()
    return true
end

function Win:onMouseUp(x, y)
    if endResize(self) then return end
    ISPanel.onMouseUp(self, x, y)
end

function Win:onMouseUpOutside(x, y)
    if endResize(self) then return end
    ISPanel.onMouseUpOutside(self, x, y)
end

-- right-click on the grip: back to the default size
function Win:onRightMouseDown(x, y)
    if not self.collapsed and x >= self.width - H.GRIP and y >= self.height - H.GRIP then
        self:setWidth(H.DEFAULT_W)
        self:setHeight(H.DEFAULT_H)
        H.prefW, H.prefH = nil, nil
        H.savePrefs()
        return true
    end
    return false
end

-- ----------------------------------------------------------------- pin
-- unpinned, the window folds up to its header a moment after the mouse
-- leaves it and unfolds when the mouse comes back (Home Medic's pin)
function Win:togglePin()
    H.pinned = not H.pinned
    self.leaveAt = nil
    if H.pinned then self:expand() end
    H.savePrefs()
end

function Win:collapse()
    if self.collapsed then return end
    self.fullH = self.height
    self.collapsed = true
    self:setHeight(H.HEADER_H)
end

function Win:expand()
    if not self.collapsed then return end
    self.collapsed = false
    self:setHeight(self.fullH or H.DEFAULT_H)
    self.leaveAt = nil
end

function Win:updatePin()
    if H.pinned or self.resizing or self.moving then
        if H.pinned then self:expand() end
        self.leaveAt = nil
        return
    end
    local mx, my = getMouseX(), getMouseY()
    local x, y = self:getAbsoluteX(), self:getAbsoluteY()
    local over = mx >= x and mx <= x + self.width and my >= y and my <= y + self.height
    local now = getTimestampMs and getTimestampMs() or 0
    if over then
        self.leaveAt = nil
        self:expand()
    elseif not self.collapsed then
        self.leaveAt = self.leaveAt or now
        if now - self.leaveAt >= H.FOLD_DELAY_MS then self:collapse() end
    end
end

-- ----------------------------------------------------------------- open / close
function H.stepText(d)
    H.textStep = math.max(0, math.min(2, H.textStep + d))
    H.savePrefs()
end

-- beside tsarslib's window when there is room (right, else left), else centred
local function place(w, h, beside)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    if beside then
        local bx, by = beside:getAbsoluteX(), beside:getAbsoluteY()
        local y = math.max(10, math.min(sh - h - 10, by))
        if bx + beside.width + 8 + w <= sw then return bx + beside.width + 8, y end
        if bx - 8 - w >= 0 then return bx - 8 - w, y end
    end
    return math.floor((sw - w) / 2), math.floor((sh - h) / 2)
end

function H.open(player, vehicle, beside)
    H.ensurePrefs()
    player = player or getPlayer()
    if not player then return end
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w = math.max(H.MIN_W, math.min(sw - 20, H.prefW or H.DEFAULT_W))
    local h = math.max(H.MIN_H, math.min(sh - 20, H.prefH or H.DEFAULT_H))
    local win = H.window
    if not win then
        local x, y = place(w, h, beside)
        win = HSVUWindow:new(x, y, w, h, player)
        win:initialise()
        H.window = win
    elseif beside then
        local x, y = place(win.width, win.collapsed and (win.fullH or h) or win.height, beside)
        win:setX(x)
        win:setY(y)
    end
    win.player = player
    win.openedByLink = beside ~= nil
    win:setVehicle(vehicle)
    if not win:getIsVisible() or not win.inManager then
        win:addToUIManager()
        win.inManager = true
        win:setVisible(true)
    end
    win:bringToTop()
end

function H.close()
    local win = H.window
    if not win then return end
    win:setVisible(false)
    win:removeFromUIManager()
    win.inManager = false
end

function H.isOpen()
    return H.window ~= nil and H.window.inManager and H.window:getIsVisible()
end

-- the car the player is in, else the one beside them
function H.nearVehicle(player)
    if not player then return nil end
    local v = player:getVehicle()
    if v then return v end
    local ok, near = pcall(function() return player:getNearVehicle() end)
    return ok and near or nil
end

function H.toggle(player)
    if H.isOpen() then H.close() return end
    player = player or getPlayer()
    H.open(player, H.nearVehicle(player), nil)
end

-- ----------------------------------------------------------------- tsarslib link
H.CHECK_EVERY = 10
function H.tick()
    H.n = (H.n or 0) + 1
    if H.n % H.CHECK_EVERY ~= 0 then return end
    local player = getPlayer()
    if not player or not getPlayerTuningUI then return end
    local ui = getPlayerTuningUI(player:getPlayerNum())
    local showing = ui and ui.getIsVisible and ui:getIsVisible() and ui.vehicle
    if showing then
        if not H.linked then
            -- tsarslib's window just opened
            H.linked = true
            if H.followEnabled() then H.open(player, ui.vehicle, ui) end
        elseif H.isOpen() and H.window.vehicle ~= ui.vehicle then
            H.window:setVehicle(ui.vehicle)
        end
    elseif H.linked then
        -- ... and closed: so does ours, when it opened with it
        H.linked = false
        if H.isOpen() and H.window.openedByLink then H.close() end
    end
end

-- ----------------------------------------------------------------- options
function H.followEnabled()
    local o = H.optFollow
    if o and o.getValue then
        local ok, v = pcall(o.getValue, o)
        if ok and v ~= nil then return v == true end
    end
    return true
end

if PZAPI and PZAPI.ModOptions and not H.options then
    local ok = pcall(function()
        H.options = PZAPI.ModOptions:create("HARMONIE_SVU3Sandbox", getText("UI_options_HARMONIE_HSVU_title"))
        H.optFollow = H.options:addTickBox("followTuning", getText("UI_options_HARMONIE_HSVU_follow"), true,
            getText("UI_options_HARMONIE_HSVU_follow_tooltip"))
        if H.options.addKeyBind then
            H.optKey = H.options:addKeyBind("openWindow", getText("UI_options_HARMONIE_HSVU_key"), 0,
                getText("UI_options_HARMONIE_HSVU_key_tooltip"))
        end
        if PZAPI.ModOptions.load then PZAPI.ModOptions:load() end
    end)
    if not ok then H.options = nil end
end

function H.onKey(key)
    local o = H.optKey
    if not key or key == 0 or not o or not o.getValue then return end
    local ok, bound = pcall(o.getValue, o)
    if ok and bound and bound ~= 0 and bound == key then H.toggle(getPlayer()) end
end

if Events then
    if Events.OnTick then Events.OnTick.Add(function() pcall(H.tick) end) end
    if Events.OnKeyPressed then Events.OnKeyPressed.Add(H.onKey) end
end

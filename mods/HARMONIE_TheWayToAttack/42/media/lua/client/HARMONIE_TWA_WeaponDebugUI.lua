--============================================================================
-- HARMONIE_TheWayToAttack -- weapon stat debug editor, window + menu (client)
--
-- Round 11. Right-click any melee or ranged weapon (HandWeapon) while an
-- admin or with -debug: "TWA Debug: edit weapon stats". The window lists
-- every stat the weapon really has (TWAWeaponDebug.fieldsOf) plus this
-- mod's own values (grade, quality, crafted by, unfinished), and Apply
-- sends them through TWAWeaponDebug.request -- to the server in
-- multiplayer, which applies them and mirrors them back. See the shared
-- file's header for why the edit then actually counts in combat.
--============================================================================

require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextEntryBox"
require "ISUI/ISTickBox"
require "ISUI/ISComboBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "HARMONIE_TWA_WeaponDebug"

TWAWeaponDebugWindow = ISCollapsableWindow:derive("TWAWeaponDebugWindow")

local W = TWAWeaponDebug
local ROW_H, LABEL_W, INPUT_W, COL_W = 24, 150, 110, 280

local function label(key)
    local k = "IGUI_TWA_Debug_" .. key
    local t = getText(k)
    if t == k then return key end
    return t
end

function TWAWeaponDebugWindow:new(player, item)
    local fields = W.fieldsOf(item)
    local rows = math.ceil(#fields / 2) + math.ceil(#W.OURS / 2)
    local h = 90 + rows * ROW_H + 70
    local o = ISCollapsableWindow:new(200, 120, COL_W * 2 + 30, h)
    setmetatable(o, self)
    self.__index = self
    o.player, o.item, o.fields = player, item, fields
    o.title = getText("IGUI_TWA_Debug_Title")
    o.resizable = false
    o.inputs = {}
    return o
end

function TWAWeaponDebugWindow:addInput(def, x, y, value)
    local lbl = ISLabel:new(x, y + 3, 18, label(def.key), 0.85, 0.85, 0.85, 1, UIFont.Small, true)
    lbl:initialise(); self:addChild(lbl)
    local ctl
    if def.kind == "bool" then
        ctl = ISTickBox:new(x + LABEL_W, y + 2, 20, 20, "", nil, nil)
        ctl:initialise(); self:addChild(ctl)
        ctl:addOption("")
        ctl:setSelected(1, value == true)
    elseif def.kind == "choice" then
        ctl = ISComboBox:new(x + LABEL_W, y, INPUT_W, 20, nil, nil)
        ctl:initialise(); self:addChild(ctl)
        for i, c in ipairs(def.choices) do
            ctl:addOption(c == "" and "-" or c)
            if c == (value or "") then ctl.selected = i end
        end
    else
        local text = value
        if type(value) == "number" then
            text = (def.kind == "int") and tostring(math.floor(value + 0.5)) or string.format("%.4g", value)
        end
        ctl = ISTextEntryBox:new(tostring(text or ""), x + LABEL_W, y, INPUT_W, 20)
        ctl:initialise(); self:addChild(ctl)
    end
    self.inputs[#self.inputs + 1] = { def = def, ctl = ctl }
end

function TWAWeaponDebugWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 8
    local item = self.item
    local name = ISLabel:new(10, top, 18, item:getDisplayName() .. "  (" .. item:getFullType() .. ")", 1, 0.9, 0.6, 1, UIFont.Medium, true)
    name:initialise(); self:addChild(name)
    local note = ISLabel:new(10, top + 22, 18, getText(isClient() and "IGUI_TWA_Debug_NoteMP" or "IGUI_TWA_Debug_NoteSP"), 0.7, 0.7, 0.7, 1, UIFont.Small, true)
    note:initialise(); self:addChild(note)
    local y0 = top + 48
    for i, f in ipairs(self.fields) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        self:addInput(f, 10 + col * (COL_W + 10), y0 + row * ROW_H, W.read(item, f))
    end
    local y1 = y0 + math.ceil(#self.fields / 2) * ROW_H + 10
    local md = item:getModData()
    for i, o in ipairs(W.OURS) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        self:addInput(o, 10 + col * (COL_W + 10), y1 + row * ROW_H, md[o.key])
    end
    local by = self.height - 36
    local bw = 130
    local function btn(i, key, fn)
        local b = ISButton:new(10 + (i - 1) * (bw + 10), by, bw, 26, getText(key), self, fn)
        b:initialise(); self:addChild(b)
    end
    btn(1, "IGUI_TWA_Debug_Apply", TWAWeaponDebugWindow.onApply)
    btn(2, "IGUI_TWA_Debug_Reset", TWAWeaponDebugWindow.onReset)
    btn(3, "IGUI_TWA_Debug_Close", TWAWeaponDebugWindow.onCloseBtn)
end

function TWAWeaponDebugWindow:collect()
    local values = {}
    for _, e in ipairs(self.inputs) do
        local d = e.def
        if d.kind == "bool" then
            values[d.key] = e.ctl:isSelected(1) and true or false
        elseif d.kind == "choice" then
            local c = d.choices[e.ctl.selected or 1] or ""
            values[d.key] = c
        elseif d.kind == "text" then
            values[d.key] = e.ctl:getText() or ""
        else
            local n = tonumber(e.ctl:getText())
            if n then values[d.key] = n end
        end
    end
    return values
end

function TWAWeaponDebugWindow:onApply()
    W.request(self.player, self.item, self:collect(), false)
    getSoundManager():playUISound("UISelectListItem")
end

function TWAWeaponDebugWindow:onReset()
    W.request(self.player, self.item, {}, true)
    self:close()
end

function TWAWeaponDebugWindow:onCloseBtn()
    self:close()
end

function TWAWeaponDebugWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if TWAWeaponDebugWindow.instance == self then TWAWeaponDebugWindow.instance = nil end
end

function TWAWeaponDebugWindow.open(player, item)
    TWALog("Debug", "weapon debug window for %s", TWALogType(item))
    if TWAWeaponDebugWindow.instance then TWAWeaponDebugWindow.instance:close() end
    local w = TWAWeaponDebugWindow:new(player, item)
    w:initialise()
    w:addToUIManager()
    w:bringToTop()
    TWAWeaponDebugWindow.instance = w
end

Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or not W.isAllowed(player) then return end
    local item = items and items[1]
    if item and type(item) == "table" and item.items then item = item.items[1] end
    if not item or not instanceof(item, "HandWeapon") then return end
    context:addOption(getText("IGUI_TWA_Debug_Menu"), player, TWAWeaponDebugWindow.open, item)
end)

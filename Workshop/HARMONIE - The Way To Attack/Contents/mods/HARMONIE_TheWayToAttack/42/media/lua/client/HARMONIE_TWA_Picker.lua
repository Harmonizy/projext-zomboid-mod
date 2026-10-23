--============================================================================
-- HARMONIE_TheWayToAttack -- "choose one" window (client)
--
-- R67c ("ทำให้เป็นหน้าต่างเลื่อนได้ทั้งสองจุดเลย"): the craft window's two
-- choosers -- which unfinished weapon to continue, and which base item to
-- use -- were pop-up menus. They are this window now: it can be dragged by
-- its title bar, and the list scrolls (mouse wheel / scroll bar) however
-- many rows there are.
--
--   TWAPicker.open(title, rows, onPick, owner)
--     rows   = { { text = "...", sub = "..." (optional), icon = texture
--                  (optional), marked = true (the current one), value = x } }
--     onPick(value) runs when a row is clicked; the window then closes.
--     owner (optional): a window; the picker sits next to it and does
--     nothing if the owner is gone by the time a row is clicked.
-- Only one picker is open at a time (opening another replaces it).
--============================================================================

require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "HARMONIE_TWA_Font"

TWAPicker = TWAPicker or {}
local P = TWAPicker
P.W = 380
P.MAX_ROWS = 8

local function shadowText(panel, text, x, y, r, g, b, font)
    panel:drawText(text, x + 1, y + 1, 0, 0, 0, 0.8, font)
    panel:drawText(text, x, y, r, g, b, 1, font)
end

-- ---------------------------------------------------------------- list
TWAPickerList = ISScrollingListBox:derive("TWAPickerList")

function TWAPickerList:new(x, y, w, h, win)
    local o = ISScrollingListBox:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.win = win
    o.font = TWAFont.small()
    o.itemheight = 44 + 2 * TWAFont.grow(0)
    o.drawBorder = true
    o.backgroundColor = { r = 0.07, g = 0.07, b = 0.08, a = 0.95 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.6 }
    return o
end

function TWAPickerList:doDrawItem(y, entry, alt)
    local row = entry.item
    local h = entry.height or self.itemheight
    local w = self:getWidth()
    local hovered = self.mouseoverselected == entry.index
    local bg = hovered and 0.2 or 0.11
    self:drawRect(2, y + 2, w - 4, h - 4, 0.95, bg, bg, bg + 0.01)
    if row.marked then
        self:drawRectBorder(2, y + 2, w - 4, h - 4, 1, 1, 0.7, 0.2)
    else
        self:drawRectBorder(2, y + 2, w - 4, h - 4, 0.5, 0.35, 0.35, 0.35)
    end
    local tx = 10
    if row.icon then
        local s = math.min(32, h - 12)
        self:drawRect(8, y + (h - s) / 2, s, s, 0.6, 0, 0, 0)
        self:drawTextureScaled(row.icon, 8, y + (h - s) / 2, s, s, 1, 1, 1, 1)
        tx = 8 + s + 8
    end
    local font = TWAFont.small()
    local lh = TWAFont.lineH(font)
    local text = (row.marked and "> " or "") .. (row.text or "")
    if row.sub and row.sub ~= "" then
        shadowText(self, text, tx, y + h / 2 - lh, 0.95, 0.95, 0.95, font)
        shadowText(self, row.sub, tx, y + h / 2, 0.7, 0.8, 1, font)
    else
        shadowText(self, text, tx, y + (h - lh) / 2, 0.95, 0.95, 0.95, font)
    end
    return y + h
end

function TWAPickerList:onRowPicked(row)
    if self.win then self.win:pick(row) end
end

-- ---------------------------------------------------------------- window
TWAPickerWindow = ISCollapsableWindow:derive("TWAPickerWindow")

function TWAPickerWindow:new(x, y, w, h, title, rows, onPick, owner)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.title = title
    o.rows = rows
    o.onPick = onPick
    o.owner = owner
    o.resizable = false
    o.moveWithMouse = true
    return o
end

function TWAPickerWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 6
    local btnH = 24
    self.list = TWAPickerList:new(8, top, self.width - 16, self.height - top - btnH - 16, self)
    self.list:initialise()
    self.list:setOnMouseDownFunction(self.list, TWAPickerList.onRowPicked)
    self:addChild(self.list)
    for _, r in ipairs(self.rows) do self.list:addItem(r.text or "", r) end
    self.closeButton2 = ISButton:new(self.width - 98, self.height - btnH - 6, 90, btnH, getText("IGUI_TWA_PickerClose"), self, TWAPickerWindow.close)
    self.closeButton2:initialise()
    self:addChild(self.closeButton2)
end

function TWAPickerWindow:pick(row)
    local owner, onPick = self.owner, self.onPick
    self:close()
    TWALog("Picker", "%s: picked %s", tostring(self.title), tostring(row and (row.text or row.value)))
    if owner and not owner:getIsVisible() then TWALog("Picker", "owner window closed -- pick ignored"); return end
    if onPick and row then onPick(row.value) end
end

function TWAPickerWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if P.current == self then P.current = nil end
end

function P.close()
    if P.current then P.current:close() end
end

function P.open(title, rows, onPick, owner)
    P.close()
    if not rows or #rows == 0 then TWALog("Picker", "%s: nothing to pick from -- not opened", tostring(title)); return nil end
    TWALog("Picker", "%s: %d choices", tostring(title), #rows)
    local rowH = 44 + 2 * TWAFont.grow(0)
    local titleH = 20
    local h = titleH + 6 + rowH * math.min(#rows, P.MAX_ROWS) + 4 + 24 + 16
    local core = getCore()
    local sw, sh = core and core:getScreenWidth() or 1280, core and core:getScreenHeight() or 720
    local x, y = getMouseX() + 16, getMouseY() - 20
    if owner then
        -- beside the owner's right edge when it fits, else over it
        x = owner:getX() + owner:getWidth() + 6
        if x + P.W > sw then x = owner:getX() + owner:getWidth() - P.W - 20 end
        y = owner:getY() + 40
    end
    x = math.max(0, math.min(x, sw - P.W))
    y = math.max(0, math.min(y, sh - h))
    local win = TWAPickerWindow:new(x, y, P.W, h, title, rows, onPick, owner)
    win:initialise()
    win:addToUIManager()
    win:bringToTop()
    P.current = win
    return win
end

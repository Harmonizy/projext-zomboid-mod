--[[
    HARMONIE - From Garden to Plate: the cook's note on paper (GTP 1.8.0,
    owner 2026-11-20, picture: a crumpled sheet of paper).

      * write: the dish's cook opens a sheet (right-click the dish > "Write a
        note for whoever eats it", or the Cooking tab's dish page) and types
        up to N.MAX_CHARS letters / N.MAX_LINES lines; Save asks the server
        (HARMONIE_CookNotes.lua) -- the note is stored on the dish there.
      * read: eating a dish with a note (vanilla's
        ISInventoryPaneContextMenu.eatItem, right-click Eat / double-click)
        shows the sheet first -- the text, the cook's name bottom-right, a
        tick "do not show this note again" -- and eats only on "Eat". Not
        shown to the cook, not when the player turned it off (Settings tick
        "noteshow"), not for a note ticked away (Zomboid/Lua/
        HARMONIE_GTP_NotesHidden.txt, this computer), not with a gamepad.
      * notices: "X enjoyed the food you made" / "You ate food made by X" as
        halo text over the character (Settings tick "eatnotice").
]]--

require "HARMONIEGardenToPlate/HARMONIE_Prep"
require "HARMONIEGardenToPlate/HARMONIE_CookNotes"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISTextEntryBox"

local R = HARMONIE_GTP.Prep
local N = HARMONIE_GTP.CookNotes
local U = {}
HARMONIE_GTP.CookNoteUI = U

local function log(fmt, ...) if HARMONIE_GTP.Log then HARMONIE_GTP.Log("NoteUI", fmt, ...) end end
local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
local function T(key, ...)
    local ok, s = pcall(getText, key, ...)
    return ok and s or key
end
local function myName(p) return tostring(call(p, "getUsername") or "?") end
local function itemName(it) return tostring(call(it, "getDisplayName") or call(it, "getFullType") or "?") end

-- ------------------------------------------------------------ prefs (the guide's file)
local function prefs()
    local G = GTPGuide
    if G and G.ensurePrefs then pcall(G.ensurePrefs) end
    return G or {}
end
function U.showNotes() return prefs().noteShow ~= false end
function U.showEatNotice() return prefs().eatNotice ~= false end

-- notes ticked "do not show again" (this computer)
U.HIDDEN_FILE = "HARMONIE_GTP_NotesHidden.txt"
U.HIDDEN_KEEP = 300
local hidden, hiddenList
local function loadHidden()
    if hidden then return end
    hidden, hiddenList = {}, {}
    if not getFileReader then return end
    local ok, reader = pcall(getFileReader, U.HIDDEN_FILE, true)
    if not ok or not reader then return end
    pcall(function()
        local line = reader:readLine()
        while line do
            if line ~= "" and not hidden[line] then hidden[line] = true; hiddenList[#hiddenList + 1] = line end
            line = reader:readLine()
        end
    end)
    pcall(function() reader:close() end)
end
function U.isHidden(id) loadHidden(); return id ~= nil and hidden[id] == true end
function U.hide(id)
    if not id then return end
    loadHidden()
    if hidden[id] then return end
    hidden[id] = true
    hiddenList[#hiddenList + 1] = id
    while #hiddenList > U.HIDDEN_KEEP do hidden[table.remove(hiddenList, 1)] = nil end
    if not getFileWriter then return end
    local ok, w = pcall(getFileWriter, U.HIDDEN_FILE, true, false)
    if not ok or not w then log("could not write %s", U.HIDDEN_FILE); return end
    pcall(function() for _, l in ipairs(hiddenList) do w:write(l .. "\n") end end)
    pcall(function() w:close() end)
    log("note %s will not be shown again (%d hidden)", id, #hiddenList)
end

-- ------------------------------------------------------------ text helpers
local function wrapLines(text, w, font)
    local out = {}
    local BN = HARMONIE_Banner
    for para in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
        if para == "" then
            out[#out + 1] = ""
        elseif BN and BN.wrap then
            for _, l in ipairs(BN.wrap(para, w, font, 20)) do out[#out + 1] = l end
        else
            out[#out + 1] = para
        end
    end
    return out
end

-- ------------------------------------------------------------ the sheet
GTPNotePaper = ISPanel:derive("GTPNotePaper")
local PAPER_W, PAPER_H = 480, 300
local INK = { r = 0.13, g = 0.17, b = 0.36 }
local PAD = 34

function GTPNotePaper:new(mode, player, item, note, onEat)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w, h = PAPER_W, PAPER_H + 44
    local o = ISPanel:new(math.floor((sw - w) / 2), math.floor((sh - h) / 2), w, h)
    setmetatable(o, self)
    self.__index = self
    o.mode, o.player, o.item, o.note, o.onEat = mode, player, item, note, onEat
    o.background = false
    o.moveWithMouse = true
    o.paper = getTexture("media/ui/GTP_NotePaper.png")
    return o
end

function GTPNotePaper:createChildren()
    local by = PAPER_H + 8
    local bw, bh = 120, 28
    if self.mode == "read" then
        self.tick = ISTickBox:new(PAD, PAPER_H - 50, 200, 20, "", nil, nil)
        self.tick:initialise()
        self.tick:instantiate()
        self.tick.choicesColor = { r = INK.r, g = INK.g, b = INK.b, a = 1 }
        self.tick:addOption(T("IGUI_GTPN_DontShow"))
        self:addChild(self.tick)
        self.eatBtn = ISButton:new(self.width - bw * 2 - 18, by, bw, bh, T("IGUI_GTPN_Eat"), self, GTPNotePaper.onEatClick)
        self.closeBtn = ISButton:new(self.width - bw - 8, by, bw, bh, self.onEat and T("IGUI_GTPN_NotNow") or T("IGUI_GTPN_Close"), self, GTPNotePaper.onCloseClick)
        if not self.onEat then self.eatBtn = nil end
    else
        local entryH = getTextManager():getFontHeight(UIFont.Medium) * N.MAX_LINES + 12
        self.entry = ISTextEntryBox:new((self.note and self.note.t) or "", PAD, 72, self.width - PAD * 2, entryH)
        self.entry.font = UIFont.Medium
        self.entry:initialise()
        self.entry:instantiate()
        if self.entry.setMultipleLine then pcall(self.entry.setMultipleLine, self.entry, true) end
        if self.entry.setMaxLines then pcall(self.entry.setMaxLines, self.entry, N.MAX_LINES) end
        if self.entry.setMaxTextLength then pcall(self.entry.setMaxTextLength, self.entry, N.MAX_CHARS) end
        -- GTP 1.8.1: dark ink (the box's default text is white: unreadable on paper)
        local okInk = pcall(function() self.entry.javaObject:setTextColor(ColorInfo.new(0.08, 0.08, 0.1, 1)) end)
        if okInk then
            self.entry.backgroundColor = { r = 1, g = 1, b = 1, a = 0.55 }
        else
            self.entry.backgroundColor = { r = INK.r, g = INK.g, b = INK.b, a = 0.9 }
            log("note box: no setTextColor -- dark box instead")
        end
        self.entry.borderColor = { r = INK.r, g = INK.g, b = INK.b, a = 0.5 }
        -- Esc in the box closes the sheet too
        local win = self
        self.entry.onOtherKey = function(_, key) if key == Keyboard.KEY_ESCAPE then win:onCloseClick() end end
        self:addChild(self.entry)
        self.saveBtn = ISButton:new(self.width - bw * 3 - 28, by, bw, bh, T("IGUI_GTPN_Save"), self, GTPNotePaper.onSaveClick)
        self.removeBtn = ISButton:new(self.width - bw * 2 - 18, by, bw, bh, T("IGUI_GTPN_Remove"), self, GTPNotePaper.onRemoveClick)
        self.closeBtn = ISButton:new(self.width - bw - 8, by, bw, bh, T("IGUI_GTPN_Cancel"), self, GTPNotePaper.onCloseClick)
        if not self.note then self.removeBtn = nil end
    end
    -- an "x" in the paper's corner, in both modes
    self.xBtn = ISButton:new(self.width - 40, 14, 22, 22, "X", self, GTPNotePaper.onCloseClick)
    -- GTP 1.8.1: NOT ipairs over a list with nil holes -- it stopped at the
    -- first missing button, so the write sheet had no buttons at all (owner:
    -- "can't close the note")
    local added = 0
    for _, k in ipairs({ "eatBtn", "saveBtn", "removeBtn", "closeBtn", "xBtn" }) do
        local b = self[k]
        if b then b:initialise(); b:instantiate(); self:addChild(b); added = added + 1 end
    end
    log("note sheet (%s): %d buttons", tostring(self.mode), added)
end

function GTPNotePaper:prerender()
    if self.paper then
        self:drawTextureScaled(self.paper, 0, 0, self.width, PAPER_H, 1, 1, 1, 1)
    else
        self:drawRect(0, 0, self.width, PAPER_H, 0.97, 0.95, 0.94, 0.9)
    end
end

function GTPNotePaper:render()
    local tm = getTextManager()
    local title = self.mode == "read" and T("IGUI_GTPN_TitleRead") or T("IGUI_GTPN_TitleWrite")
    self:drawText(title, PAD, 26, INK.r, INK.g, INK.b, 0.75, UIFont.Small)
    self:drawText(itemName(self.item), PAD, 26 + tm:getFontHeight(UIFont.Small), INK.r, INK.g, INK.b, 0.55, UIFont.Small)
    local author
    if self.mode == "read" then
        local fh = tm:getFontHeight(UIFont.Medium)
        local y = 72
        for _, l in ipairs(wrapLines(self.note and self.note.t or "", self.width - PAD * 2, UIFont.Medium)) do
            self:drawText(l, PAD, y, INK.r, INK.g, INK.b, 1, UIFont.Medium)
            y = y + fh + 2
            if y > PAPER_H - 80 then break end
        end
        author = self.note and self.note.by or "?"
    else
        local text = self.entry and self.entry:getText() or ""
        local n = N.len(text)
        local col = n > N.MAX_CHARS and { 0.7, 0.1, 0.1 } or { INK.r, INK.g, INK.b }
        local s = T("IGUI_GTPN_Count", tostring(n), tostring(N.MAX_CHARS))
        self:drawText(s, PAD, PAPER_H - 52, col[1], col[2], col[3], 0.7, UIFont.Small)
        author = myName(self.player)
    end
    local sig = "- " .. tostring(author)
    self:drawText(sig, self.width - PAD - tm:MeasureStringX(UIFont.Medium, sig), PAPER_H - 30 - tm:getFontHeight(UIFont.Medium), INK.r, INK.g, INK.b, 1, UIFont.Medium)
end

function GTPNotePaper:finish()
    if self.mode == "read" and self.tick and self.tick:isSelected(1) and self.note then U.hide(self.note.id) end
    self:setVisible(false)
    self:removeFromUIManager()
    if U.window == self then U.window = nil end
end
function GTPNotePaper:onEatClick()
    log("note read, eating %s", itemName(self.item))
    local fn = self.onEat
    self:finish()
    if fn then pcall(fn) end
end
function GTPNotePaper:onCloseClick()
    log("note window closed (%s)%s", self.mode, (self.mode == "read" and self.onEat) and " -- not eaten" or "")
    self:finish()
end
function GTPNotePaper:onSaveClick()
    local raw = self.entry and self.entry:getText() or ""
    self:finish()
    local ok, err = pcall(function()
        local text = N.clean(raw)
        N.request(self.player, self.item, text)
        log("note %s on %s (%d letters)", text == "" and "removed" or "saved", itemName(self.item), N.len(text))
    end)
    if not ok then log("saving the note FAILED: %s", tostring(err)) end
end
function GTPNotePaper:onRemoveClick()
    self:finish()
    local ok, err = pcall(N.request, self.player, self.item, "")
    log("note removed from %s%s", itemName(self.item), ok and "" or (" -- FAILED: " .. tostring(err)))
end
function GTPNotePaper:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:onCloseClick(); return true end
end

local function open(mode, player, item, note, onEat)
    if U.window then U.window:finish() end
    local w = GTPNotePaper:new(mode, player, item, note, onEat)
    w:initialise()
    w:addToUIManager()
    w:setAlwaysOnTop(true)
    if mode == "write" and w.entry then pcall(function() w.entry:focus() end) end
    U.window = w
    return w
end
function U.openWrite(player, item)
    if not (player and item and N.canWrite(player, item)) then return end
    log("writing a note on %s", itemName(item))
    return open("write", player, item, N.noteOf(item), nil)
end
function U.openRead(player, item, onEat)
    local note = N.noteOf(item)
    if not note then return end
    return open("read", player, item, note, onEat)
end

-- should eating this item show its note first?
function U.shouldShow(item, player)
    local note = N.noteOf(item)
    if not note or not U.showNotes() then return false end
    if note.by == myName(player) then return false end
    if U.isHidden(note.id) then return false end
    if JoypadState and JoypadState.players and JoypadState.players[(call(player, "getPlayerNum") or 0) + 1] then return false end
    return true, note
end

-- ------------------------------------------------------------ vanilla eat
local function hookEat()
    local M = ISInventoryPaneContextMenu
    if not (M and M.eatItem) or M.gtpNoteHooked then return end
    M.gtpNoteHooked = true
    local orig = M.eatItem
    M.eatItem = function(item, percentage, player, ...)
        local n, args = select("#", ...), { ... }
        local okS, show = pcall(U.shouldShow, item, getSpecificPlayer and getSpecificPlayer(player or 0))
        if okS and show then
            log("showing the cook's note before eating %s", itemName(item))
            open("read", getSpecificPlayer(player or 0), item, N.noteOf(item), function()
                orig(item, percentage, player, (unpack or table.unpack)(args, 1, n))
            end)
            return
        end
        if not okS then log("note check before eating FAILED: %s", tostring(show)) end
        return orig(item, percentage, player, ...)
    end
    log("eating shows the cook's note first")
end

-- ------------------------------------------------------------ notices
local function halo(p, text, good)
    if not (p and HaloTextHelper) then return end
    local fn = good and (HaloTextHelper.addGoodText or HaloTextHelper.addText) or (HaloTextHelper.addBadText or HaloTextHelper.addText)
    if fn then pcall(fn, p, text) end
end
N.onNotice = function(what, args)
    local p = getPlayer and getPlayer()
    if not U.showEatNotice() then log("notice %s not shown (turned off)", tostring(what)); return end
    if what == "likedBy" then
        local xp = tonumber(args.xp)
        if xp and xp > 0 then
            halo(p, T("IGUI_GTPN_LikedByXp", tostring(args.eater or "?"), string.format("%.1f", xp)), true)
        else
            halo(p, T("IGUI_GTPN_LikedBy", tostring(args.eater or "?")), true)
        end
    elseif what == "ateOf" then
        halo(p, T("IGUI_GTPN_AteOf", tostring(args.chef or "?")), true)
    end
end
N.onRefused = function(args)
    halo(getPlayer and getPlayer(), T("IGUI_GTPN_Refused_" .. tostring(args and args.why or "missing")), false)
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        local ok, err = pcall(hookEat)
        if not ok then log("eat hook FAILED: %s", tostring(err)) end
    end)
end
log("cook's note window loaded")

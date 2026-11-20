--[[
    HARMONIE - The Way To Attack 1.2.0: the workbench's "Modify bag" tab, and
    the extra hotbar slots an upgraded bag gives (client).

    Page: left = the wearable vanilla bags at hand (worn first) with tier and
    slots used; centre = the picked bag: its slots (click a slot twice to take
    the upgrade out -- it comes back by chance, Tailoring), and its values
    before -> after; right = the upgrade items at hand (click one to fit it
    into the picked bag; a grey one says why not). Everything is decided on
    the server (TWABagUp).

    Hotbar: an "attach" upgrade adds a slot of our own type (TWABagS1..10 =
    a belt slot, TWABagL1..10 = a holster slot; their attachment tables are
    COPIED at runtime from the game's own belt / holster definitions). The
    game's ISHotbar:refresh drops every slot no worn item provides, so
    ISHotbar:haveThisSlot answers "yes" for the slots worn bags give, and the
    missing ones are added after the refresh. No vanilla code is copied.
]]--

require "ISUI/ISPanel"
require "HARMONIE_TWA_Font"
require "HARMONIE_TWA_BagUpgrade"

TWABagUpUI = ISPanel:derive("TWABagUpUI")
local U = TWABagUpUI
local B = TWABagUp
local log = function(fmt, ...) if TWALog then TWALog("BagUpUI", fmt, ...) end end

local function textW(s, f) return getTextManager():MeasureStringX(f, s) end
local function fit(s, w, f)
    if textW(s, f) <= w then return s end
    while #s > 1 and textW(s .. "...", f) > w do s = s:sub(1, -2) end
    return s .. "..."
end
local texCache = {}
local function itemTex(item)
    local ok, t = pcall(function() return item:getTex() end)
    return ok and t or nil
end
local function typeTex(fullType)
    if texCache[fullType] == nil then
        local sm = ScriptManager.instance
        local it = sm and sm:getItem(fullType)
        local icon = it and it:getIcon()
        texCache[fullType] = (icon and getTexture("Item_" .. tostring(icon))) or false
    end
    return texCache[fullType] or nil
end
local function typeName(fullType)
    local sm = ScriptManager.instance
    local it = sm and sm:getItem(fullType)
    return it and it:getDisplayName() or tostring(fullType)
end
B.typeName = typeName

-- "+1 capacity" etc.
function B.effectText(fullType)
    local e = B.ITEMS[fullType]
    if not e then return "" end
    local fmt = { cap = "+%d", wr = "+%d", run = "+%.3f", combat = "+%.3f", weight = "-%.1f", attachS = "+%d", attachL = "+%d" }
    return getText("IGUI_TWA_BagUpKind_" .. e.kind, string.format(fmt[e.kind], e.value))
end
function B.recipeNote(recipe)
    if recipe.bagTier then
        return getText("IGUI_TWA_BagTierRule", tostring(recipe.bagTier - 1), tostring(recipe.bagTier))
    end
    return getText("IGUI_TWA_BagUpRule", B.effectText(recipe.result), tostring(recipe.bagUp))
end

function U.embed(parent, x, y, w, h, player)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, U)
    U.__index = U
    o.player = player
    o.background = false
    o.moveWithMouse = false
    o.bagScroll, o.upScroll = 0, 0
    o:initialise()
    parent:addChild(o)
    B.onResult = function(ok, key, upType)
        o.msg = key and getText(key, upType and typeName(upType) or "") or nil
        o.msgOk = ok
        o.msgUntil = getTimestampMs() + 5000
        o.nextScan = 0
        o.armed = nil
        U.refreshHotbars()
    end
    return o
end

-- what is at hand (scanned twice a second)
function U:scan()
    local now = getTimestampMs()
    if self.nextScan and now < self.nextScan then return end
    self.nextScan = now + 500
    local bags, ups = {}, {}
    local src = TWASources.get(self.player)
    if src.index then src:index() end
    for _, it in ipairs(src.all or {}) do
        if B.isBag(it) then bags[#bags + 1] = it
        elseif B.upOf(it:getFullType()) and not TWACraftState.isBookmarked(it) then ups[#ups + 1] = it end
    end
    table.sort(bags, function(a, b)
        local wa, wb = B.inUse(a) and 0 or 1, B.inUse(b) and 0 or 1
        if wa ~= wb then return wa < wb end
        local ta, tb = B.tierOf(a), B.tierOf(b)
        if ta ~= tb then return ta > tb end
        return a:getID() < b:getID()
    end)
    table.sort(ups, function(a, b)
        local ea, eb = B.upOf(a:getFullType()), B.upOf(b:getFullType())
        if ea.tier ~= eb.tier then return ea.tier < eb.tier end
        return a:getFullType() < b:getFullType()
    end)
    self.bags, self.ups = bags, ups
    if self.bag then
        local still = false
        for _, b in ipairs(bags) do if b == self.bag then still = true end end
        if not still then self.bag = nil end
    end
    if not self.bag then self.bag = bags[1] end
end

function U:layout()
    local m, g = 8, 10
    local avail = self.width - 2 * m - 2 * g
    local L = { m = m, top = 8, bottom = self.height - 8 }
    L.lw = math.floor(avail * 0.30); L.cw = math.floor(avail * 0.37); L.rw = avail - L.lw - L.cw
    L.lx = m; L.cx = L.lx + L.lw + g; L.rx = L.cx + L.cw + g
    L.f = TWAFont.small(); L.lh = TWAFont.lineH(L.f)
    L.row = math.max(L.lh + 8, 34)
    return L
end

local C = { text = { 0.97, 0.94, 0.86 }, dim = { 0.72, 0.66, 0.54 }, acc = { 1.0, 0.78, 0.2 }, good = { 0.45, 0.95, 0.5 }, bad = { 1.0, 0.45, 0.4 } }
local function box(self, x, y, w, h, a)
    self:drawRect(x, y, w, h, a or 0.55, 0.05, 0.04, 0.02)
    self:drawRectBorder(x, y, w, h, 0.6, 0.40, 0.30, 0.10)
end

function U:prerender() end
function U:render()
    self:scan()
    local L = self:layout()
    self.hits = {}
    local f, lh, row = L.f, L.lh, L.row
    -- left: the bags
    box(self, L.lx, L.top, L.lw, L.bottom - L.top)
    self:drawText(getText("IGUI_TWA_BagUp_Bags"), L.lx + 6, L.top + 4, C.acc[1], C.acc[2], C.acc[3], 1, f)
    local y = L.top + lh + 10
    local shown = math.max(1, math.floor((L.bottom - y - 4) / row))
    self.bagScroll = math.max(0, math.min(self.bagScroll, math.max(0, #self.bags - shown)))
    if #self.bags == 0 then
        self:drawText(fit(getText("IGUI_TWA_BagUp_NoBags"), L.lw - 12, f), L.lx + 6, y, C.dim[1], C.dim[2], C.dim[3], 1, f)
    end
    for i = self.bagScroll + 1, math.min(#self.bags, self.bagScroll + shown) do
        local bag = self.bags[i]
        local sel = bag == self.bag
        if sel then self:drawRect(L.lx + 2, y, L.lw - 4, row - 2, 0.25, C.acc[1], C.acc[2], C.acc[3]) end
        local t = itemTex(bag)
        if t then self:drawTextureScaledAspect(t, L.lx + 6, y + 2, row - 6, row - 6, 1, 1, 1, 1) end
        local tier = B.tierOf(bag)
        local right = getText("IGUI_TWA_BagUp_TierShort", tostring(tier), tostring(#B.upsOf(bag)), tostring(tier))
        local rw = textW(right, f)
        local name = (B.inUse(bag) and "* " or "") .. bag:getDisplayName()
        self:drawText(fit(name, L.lw - row - rw - 20, f), L.lx + row + 4, y + math.floor((row - lh) / 2), C.text[1], C.text[2], C.text[3], 1, f)
        self:drawText(right, L.lx + L.lw - rw - 8, y + math.floor((row - lh) / 2), C.acc[1], C.acc[2], C.acc[3], 1, f)
        self.hits[#self.hits + 1] = { x = L.lx, y = y, w = L.lw, h = row, kind = "bag", item = bag }
        y = y + row
    end
    self.bagArea = { x = L.lx, y = L.top, w = L.lw, h = L.bottom - L.top, shown = shown }

    -- centre: the picked bag
    box(self, L.cx, L.top, L.cw, L.bottom - L.top)
    local bag = self.bag
    y = L.top + 4
    if not bag then
        self:drawText(fit(getText("IGUI_TWA_BagUp_PickBag"), L.cw - 12, f), L.cx + 6, y, C.dim[1], C.dim[2], C.dim[3], 1, f)
    else
        local tier = B.tierOf(bag)
        self:drawText(fit(bag:getDisplayName(), L.cw - 12, TWAFont.medium()), L.cx + 6, y, C.text[1], C.text[2], C.text[3], 1, TWAFont.medium())
        y = y + TWAFont.lineH(TWAFont.medium()) + 4
        self:drawText(getText("IGUI_TWA_BagUp_TierLine", tostring(tier), tostring(B.MAX_TIER)), L.cx + 6, y, C.acc[1], C.acc[2], C.acc[3], 1, f)
        y = y + lh + 6
        local ups = B.upsOf(bag)
        if tier == 0 then
            for _, l in ipairs({ getText("IGUI_TWA_BagUp_NeedTier") }) do
                self:drawText(fit(l, L.cw - 12, f), L.cx + 6, y, C.dim[1], C.dim[2], C.dim[3], 1, f)
                y = y + lh + 4
            end
        end
        for s = 1, tier do
            local t = ups[s]
            self:drawRect(L.cx + 6, y, L.cw - 12, row - 4, 0.5, 0.1, 0.08, 0.03)
            self:drawRectBorder(L.cx + 6, y, L.cw - 12, row - 4, 0.6, 0.4, 0.3, 0.1)
            if t then
                local tx = typeTex(t)
                if tx then self:drawTextureScaledAspect(tx, L.cx + 9, y + 2, row - 8, row - 8, 1, 1, 1, 1) end
                local armed = self.armed == s
                local label = armed and getText("IGUI_TWA_BagUp_ConfirmRemove", tostring(B.returnChance(self.player))) or (typeName(t) .. "  " .. B.effectText(t))
                local c = armed and C.bad or C.text
                self:drawText(fit(label, L.cw - row - 20, f), L.cx + row + 4, y + math.floor((row - 4 - lh) / 2), c[1], c[2], c[3], 1, f)
                self.hits[#self.hits + 1] = { x = L.cx + 6, y = y, w = L.cw - 12, h = row - 4, kind = "slot", idx = s }
            else
                self:drawText(getText("IGUI_TWA_BagUp_EmptySlot", tostring(s)), L.cx + 12, y + math.floor((row - 4 - lh) / 2), C.dim[1], C.dim[2], C.dim[3], 1, f)
            end
            y = y + row
        end
        -- values now (base -> now)
        y = y + 6
        local base, now = B.base(bag), B.compute(bag)
        if base and now then
            local rows = {
                { "IGUI_TWA_BagUpStat_cap", string.format("%d", base.cap), string.format("%d", now.cap) },
                { "IGUI_TWA_BagUpStat_wr", string.format("%d", base.wr), string.format("%d", now.wr) },
                { "IGUI_TWA_BagUpStat_run", string.format("%.3f", base.run), string.format("%.3f", now.run) },
                { "IGUI_TWA_BagUpStat_combat", string.format("%.3f", base.combat), string.format("%.3f", now.combat) },
                { "IGUI_TWA_BagUpStat_weight", string.format("%.2f", base.weight), string.format("%.2f", now.weight) },
                { "IGUI_TWA_BagUpStat_attach", "0", string.format("%d / %d", now.attachS, now.attachL) },
            }
            for _, r in ipairs(rows) do
                if y + lh > L.bottom - 4 then break end
                local changed = r[2] ~= r[3] and r[3] ~= "0 / 0"
                local c = changed and C.good or C.dim
                self:drawText(getText(r[1]), L.cx + 8, y, C.text[1], C.text[2], C.text[3], 1, f)
                local v = changed and (r[2] .. " -> " .. r[3]) or r[3]
                self:drawText(v, L.cx + L.cw - textW(v, f) - 10, y, c[1], c[2], c[3], 1, f)
                y = y + lh + 2
            end
        end
    end

    -- right: the upgrade items
    box(self, L.rx, L.top, L.rw, L.bottom - L.top)
    self:drawText(getText("IGUI_TWA_BagUp_Items"), L.rx + 6, L.top + 4, C.acc[1], C.acc[2], C.acc[3], 1, f)
    y = L.top + lh + 10
    local msgH = (self.msg and getTimestampMs() < (self.msgUntil or 0)) and (lh * 2 + 8) or 0
    local shownU = math.max(1, math.floor((L.bottom - y - 4 - msgH) / row))
    self.upScroll = math.max(0, math.min(self.upScroll, math.max(0, #self.ups - shownU)))
    if #self.ups == 0 then
        self:drawText(fit(getText("IGUI_TWA_BagUp_NoItems"), L.rw - 12, f), L.rx + 6, y, C.dim[1], C.dim[2], C.dim[3], 1, f)
    end
    for i = self.upScroll + 1, math.min(#self.ups, self.upScroll + shownU) do
        local up = self.ups[i]
        local e = B.upOf(up:getFullType())
        local ok, why = false, "IGUI_TWA_BagUp_PickBag"
        if self.bag then ok, why = B.canInstall(self.bag, up) end
        local a = ok and 1 or 0.45
        local tx = typeTex(up:getFullType())
        if tx then self:drawTextureScaledAspect(tx, L.rx + 6, y + 2, row - 6, row - 6, a, 1, 1, 1) end
        local tl = "T" .. tostring(e.tier)
        self:drawText(fit(up:getDisplayName(), L.rw - row - 40, f), L.rx + row + 4, y + 1, C.text[1], C.text[2], C.text[3], a, f)
        self:drawText(tl, L.rx + L.rw - textW(tl, f) - 8, y + 1, C.acc[1], C.acc[2], C.acc[3], a, f)
        local sub = ok and B.effectText(up:getFullType()) or getText(why or "IGUI_TWA_BagUp_Refused")
        local c = ok and C.good or C.dim
        if row >= lh * 2 then
            self:drawText(fit(sub, L.rw - row - 12, f), L.rx + row + 4, y + lh, c[1], c[2], c[3], 1, f)
        end
        self.hits[#self.hits + 1] = { x = L.rx, y = y, w = L.rw, h = row, kind = "up", item = up, ok = ok, why = why }
        y = y + row
    end
    self.upArea = { x = L.rx, y = L.top, w = L.rw, h = L.bottom - L.top }
    if msgH > 0 then
        local c = self.msgOk and C.good or C.bad
        local my = L.bottom - msgH
        self:drawRect(L.rx + 4, my, L.rw - 8, msgH - 4, 0.6, 0.05, 0.04, 0.02)
        self:drawText(fit(self.msg, L.rw - 16, f), L.rx + 8, my + 4, c[1], c[2], c[3], 1, f)
    end
end

function U:flash(key, ok)
    self.msg = getText(key)
    self.msgOk = ok
    self.msgUntil = getTimestampMs() + 4000
end

function U:onMouseDown(x, y)
    for _, h in ipairs(self.hits or {}) do
        if x >= h.x and x < h.x + h.w and y >= h.y and y < h.y + h.h then
            if h.kind == "bag" then
                if self.bag ~= h.item then self.armed = nil end
                self.bag = h.item
                log("bag picked: %s (tier %d)", TWALogType(h.item), B.tierOf(h.item))
            elseif h.kind == "slot" and self.bag then
                if self.armed == h.idx then
                    local ok, why = B.canRemove(self.bag, h.idx)
                    if ok then B.requestRemove(self.player, self.bag, h.idx) else self:flash(why, false) end
                    self.armed = nil
                else
                    self.armed = h.idx
                end
            elseif h.kind == "up" then
                if h.ok and self.bag then
                    B.requestInstall(self.player, self.bag, h.item)
                    self:flash("IGUI_TWA_BagUp_Asked", true)
                else
                    self:flash(h.why or "IGUI_TWA_BagUp_Refused", false)
                end
            end
            return true
        end
    end
    self.armed = nil
    return true
end
function U:onMouseWheel(del)
    local mx, my = self:getMouseX(), self:getMouseY()
    local a = self.upArea
    if a and mx >= a.x and mx < a.x + a.w then self.upScroll = self.upScroll + del
    else self.bagScroll = self.bagScroll + del end
    return true
end

-- ================================================================= hotbar
U.SLOT_MAX = 10
local function copyTable(t)
    local o = {}
    for k, v in pairs(t or {}) do o[k] = v end
    return o
end
local defsMade = false
local function makeDefs()
    if defsMade or not ISHotbarAttachDefinition then return defsMade end
    local src = {}
    for _, d in ipairs(ISHotbarAttachDefinition) do src[d.type] = d end
    local sL, sR, hR, hL = src.SmallBeltLeft, src.SmallBeltRight, src.HolsterRight, src.HolsterLeft
    if not (sL and sR and hR and hL) then log("hotbar: the game's belt / holster slots not found -- no extra slots"); return false end
    for i = 1, U.SLOT_MAX do
        local s = (i % 2 == 1) and sL or sR
        local h = (i % 2 == 1) and hR or hL
        table.insert(ISHotbarAttachDefinition, { type = "TWABagS" .. i, name = getText("IGUI_TWA_BagSlotS"), animset = s.animset, attachments = copyTable(s.attachments) })
        table.insert(ISHotbarAttachDefinition, { type = "TWABagL" .. i, name = getText("IGUI_TWA_BagSlotL"), animset = h.animset, attachments = copyTable(h.attachments) })
    end
    defsMade = true
    log("hotbar: %d extra slot types made (belt / holster copies)", U.SLOT_MAX * 2)
    return true
end

-- the extra slots this character's worn bags give: { [type] = bag }, and a signature
function U.extraSlots(chr)
    local out, sig = {}, ""
    if not chr then return out, sig end
    local worn = chr:getWornItems()
    local nS, nL = 0, 0
    for i = 0, (worn and worn:size() or 0) - 1 do
        local it = worn:getItemByIndex(i)
        if it and B.isBag(it) and not chr:isHandItem(it) then
            local v = B.compute(it)
            if v then
                for _ = 1, v.attachS do if nS < U.SLOT_MAX then nS = nS + 1; out["TWABagS" .. nS] = it end end
                for _ = 1, v.attachL do if nL < U.SLOT_MAX then nL = nL + 1; out["TWABagL" .. nL] = it end end
            end
        end
    end
    return out, nS .. "/" .. nL
end

local function addMissing(hb)
    local extra = hb.twaExtra
    if not extra then return end
    local added = 0
    for i = 1, U.SLOT_MAX * 2 do
        local t = (i <= U.SLOT_MAX) and ("TWABagS" .. i) or ("TWABagL" .. (i - U.SLOT_MAX))
        local bag = extra[t]
        if bag and not hb:haveThisSlot(t) then
            local def = hb:getSlotDef(t)
            if def then
                hb.availableSlot[#hb.availableSlot + 1] = { slotType = def.type, name = def.name, def = def, texture = bag:getTexture() }
                added = added + 1
            end
        end
    end
    if added > 0 then
        hb:savePosition()
        local width = #hb.availableSlot * hb.slotWidth + (#hb.availableSlot - 1) * 2
        hb:setWidth(width + 10)
        hb:reloadIcons()
        log("hotbar: %d bag slot(s) added", added)
    end
end

local installed = false
local function installHotbar()
    if installed or not ISHotbar or not ISHotbar.refresh or not ISHotbar.haveThisSlot then return end
    if not makeDefs() then return end
    installed = true
    local origHave, origRefresh = ISHotbar.haveThisSlot, ISHotbar.refresh
    function ISHotbar:haveThisSlot(slotType, list)
        if list and list ~= self.availableSlot and self.twaExtra and self.twaExtra[slotType] then return true end
        return origHave(self, slotType, list)
    end
    function ISHotbar:refresh()
        local ok, ex, sig = pcall(U.extraSlots, self.chr)
        if ok then self.twaExtra, self.twaSig = ex, sig end
        origRefresh(self)
        pcall(addMissing, self)
    end
    log("hotbar: upgraded bags add their slots")
end

-- a bag's attach upgrades changed without a clothing change: redo the hotbar
function U.refreshHotbars(force)
    if not installed then return end
    for i = 0, (getNumActivePlayers and getNumActivePlayers() or 1) - 1 do
        local p = getSpecificPlayer(i)
        local hb = p and getPlayerHotbar and getPlayerHotbar(i)
        if hb then
            local _, sig = U.extraSlots(p)
            if force or sig ~= hb.twaSig then
                hb.wornItems = nil
                hb:refresh()
            end
        end
    end
end

local nextHb = 0
if Events then
    if Events.OnGameStart then Events.OnGameStart.Add(installHotbar) end
    if Events.OnTick then
        Events.OnTick.Add(function()
            local t = getTimestampMs()
            if t < nextHb then return end
            nextHb = t + 2000
            pcall(U.refreshHotbars, false)
        end)
    end
    -- a bag in the loot window gets its values (tooltip, what fits)
    if Events.OnRefreshInventoryWindowContainers then
        Events.OnRefreshInventoryWindowContainers.Add(function(page, state)
            if state ~= "end" or not page or not page.backpacks then return end
            for _, bp in ipairs(page.backpacks) do
                local inv = bp.inventory
                local it = inv and inv.getContainingItem and inv:getContainingItem()
                if it then pcall(B.apply, it) end
            end
        end)
    end
end
installHotbar()

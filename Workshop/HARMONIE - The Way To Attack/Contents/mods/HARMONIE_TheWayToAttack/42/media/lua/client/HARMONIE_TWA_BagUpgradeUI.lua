--[[
    HARMONIE - The Way To Attack 1.2.0: the workbench's "Modify bag" tab, and
    the extra hotbar slots an upgraded bag gives (client).

    Page (1.3.0, laid out like the gem socket page): left = the wearable
    vanilla bags at hand (highest tier first) and the rules; centre = the
    picked bag large, its slots (one per tier) and its values before -> now
    (-> with the picked add-on); right = the add-ons at hand in a grid (grey =
    does not fit, why on hover). Pick an add-on or a filled slot, then the
    button fits it / takes it out (it comes back by chance, Tailoring).
    Hovering a stat says what it does. Everything is decided on the server
    (TWABagUp). B.tooltipLines feeds the item tooltip (TierTooltip).

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

-- ------------------------------------------------------------ tooltip lines
-- 1.3.0 (owner): under the vanilla tooltip (TierTooltip draws them) --
-- an upgraded bag: tier, who raised it, its add-ons and who made each;
-- an add-on item: what it does, the bag tier it needs, the one-per-kind rule.
local TC = { gold = { r = 1, g = 0.8, b = 0.3 }, text = { r = 0.9, g = 0.88, b = 0.82 }, dim = { r = 0.7, g = 0.66, b = 0.56 },
    good = { r = 0.45, g = 1, b = 0.5 } }
function B.tooltipLines(item)
    if B.isBag(item) then
        local md = item:getModData()
        local tier, ups = B.tierOf(item), B.upsOf(item)
        if tier <= 0 and #ups == 0 and not md.TWA_BagBy then return nil end
        local out = { { text = getText("IGUI_TWA_BagTip_Tier", tostring(tier), tostring(B.MAX_TIER)), color = TC.gold } }
        if md.TWA_BagBy and md.TWA_BagBy ~= "" then
            out[#out + 1] = { text = getText("IGUI_TWA_BagTip_By", tostring(md.TWA_BagBy)), color = TC.text }
        end
        out[#out + 1] = { text = getText("IGUI_TWA_BagTip_Ups", tostring(#ups), tostring(tier)), color = TC.text }
        local by = B.upByOf(item)
        for i, t in ipairs(ups) do
            local line = "- " .. typeName(t) .. ": " .. B.effectText(t)
            if by[i] and by[i] ~= "" then line = line .. " " .. getText("IGUI_TWA_BagTip_UpBy", by[i]) end
            out[#out + 1] = { text = line, color = TC.good }
        end
        if #ups == 0 then out[#out + 1] = { text = getText("IGUI_TWA_BagTip_NoUps"), color = TC.dim } end
        return out
    end
    local e = item and item.getFullType and B.upOf(item:getFullType())
    if not e then return nil end
    return {
        { text = getText("IGUI_TWA_UpTip_Effect", tostring(e.tier), B.effectText(e.type)), color = TC.good },
        { text = getText("IGUI_TWA_BagUpStatTip_" .. e.kind), color = TC.text },
        { text = getText("IGUI_TWA_UpTip_Rule", tostring(e.tier)), color = TC.dim },
    }
end

-- ------------------------------------------------------------ the page
-- 1.3.0 (owner: "fitting add-ons should look like fitting gems; the add-on
-- items in the card RIGHT of the picture; pointing at a stat says what it
-- does"): left = your bags (pick one) + the rules; centre = the bag large,
-- its slots (one per tier) and its values now -> with the picked add-on;
-- right = the add-ons at hand, a grid like the gem picker (grey = does not
-- fit, the reason on hover). Pick an add-on (or a filled slot) and press the
-- button: fit it / take it out. Everything is decided on the server.
local STATS = {
    { key = "cap", fmt = "%d" }, { key = "wr", fmt = "%d" }, { key = "run", fmt = "%.3f" },
    { key = "combat", fmt = "%.3f" }, { key = "weight", fmt = "%.2f" }, { key = "attach" },
}
local CELL, GAP = 52, 6

function U.embed(parent, x, y, w, h, player)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, U)
    U.__index = U
    o.player = player
    o.background = false
    o.moveWithMouse = false
    o.bagScroll, o.upRow = 0, 0
    o:initialise()
    parent:addChild(o)
    o.confirmBtn = TWANeatButton:new(w - 8 - 260, h - 46, 260, 40, getText("IGUI_TWA_BagUp_Fit"), o, U.onConfirm)
    o.confirmBtn.neatTint = { r = 1, g = 0.8, b = 0.4 }
    o.confirmBtn:initialise()
    o:addChild(o.confirmBtn)
    B.onResult = function(ok, key, upType)
        o.msg = key and getText(key, upType and typeName(upType) or "") or nil
        o.msgOk = ok
        o.msgUntil = getTimestampMs() + 5000
        o.scanGen = nil
        if TWACraftUI and TWACraftUI.lookAgain then TWACraftUI.lookAgain("bag add-on " .. tostring(ok and "done" or "refused")) end
        o.pick, o.selSlot = nil, nil
        U.refreshHotbars()
    end
    return o
end

-- what is at hand; add-ons grouped by type. 1.4.0: looked at again only when
-- the TWA refresh generation changes (Refresh button, window opened, an
-- add-on fitted / taken out) -- not twice a second
function U:scan()
    local g = HARMONIE_Refresh and HARMONIE_Refresh.gen("TWA") or 0
    if self.scanGen == g and self.bags then return end
    self.scanGen = g
    local bags, groups, ups = {}, {}, {}
    local src = TWASources.get(self.player)
    if src.index then src:index() end
    for _, it in ipairs(src.all or {}) do
        if B.isBag(it) then bags[#bags + 1] = it
        else
            local t = it:getFullType()
            if B.upOf(t) and not TWACraftState.isBookmarked(it) then
                local g = groups[t]
                if not g then g = { type = t, e = B.upOf(t), count = 0, item = it }; groups[t] = g; ups[#ups + 1] = g end
                g.count = g.count + 1
            end
        end
    end
    table.sort(bags, function(a, b)
        local ta, tb = B.tierOf(a), B.tierOf(b)
        if ta ~= tb then return ta > tb end
        local wa, wb = B.inUse(a) and 0 or 1, B.inUse(b) and 0 or 1
        if wa ~= wb then return wa < wb end
        return a:getID() < b:getID()
    end)
    local order = {}
    for i, k in ipairs(B.KIND_ORDER) do order[k] = i end
    table.sort(ups, function(a, b)
        if a.e.kind ~= b.e.kind then return (order[a.e.kind] or 9) < (order[b.e.kind] or 9) end
        return a.e.tier < b.e.tier
    end)
    self.bags, self.ups = bags, ups
    local still = false
    for _, b in ipairs(bags) do if b == self.bag then still = true end end
    if not still then self.bag, self.pick, self.selSlot = bags[1], nil, nil end
    if self.pick then
        local g = groups[self.pick]
        if g then self.pickItem = g.item else self.pick, self.pickItem = nil, nil end
    end
end

function U:layout()
    local m, g = 8, 10
    local avail = self.width - 2 * m - 2 * g
    local L = { top = 8, bottom = self.height - 54 }
    L.lw = math.floor(avail * 0.28); L.cw = math.floor(avail * 0.38); L.rw = avail - L.lw - L.cw
    L.lx = m; L.cx = L.lx + L.lw + g; L.rx = L.cx + L.cw + g
    L.f = TWAFont.small(); L.lh = TWAFont.lineH(L.f)
    L.fm = TWAFont.medium(); L.lhm = TWAFont.lineH(L.fm)
    L.row = math.max(L.lh * 2 + 8, 40)
    return L
end

local C = { text = { 0.97, 0.94, 0.86 }, dim = { 0.72, 0.66, 0.54 }, acc = { 1.0, 0.78, 0.2 }, good = { 0.45, 0.95, 0.5 }, bad = { 1.0, 0.45, 0.4 } }
local function panel(self, x, y, w, h)
    self:drawRect(x, y, w, h, 0.6, 0.05, 0.04, 0.02)
    self:drawRectBorder(x, y, w, h, 0.7, 0.40, 0.30, 0.10)
end
local function wrapText(s, w, f)
    local out, cur = {}, ""
    for word in tostring(s or ""):gmatch("%S+") do
        local cand = cur == "" and word or (cur .. " " .. word)
        if textW(cand, f) > w and cur ~= "" then out[#out + 1] = cur; cur = word else cur = cand end
    end
    if cur ~= "" then out[#out + 1] = cur end
    return out
end
local function inside(mx, my, x, y, w, h) return mx >= x and mx < x + w and my >= y and my < y + h end

-- the value of a stat row as text: { base, now, preview }
local function statText(st, base, now, prev)
    if st.key == "attach" then
        local function a(v) return v and string.format("%d / %d", v.attachS, v.attachL) or "-" end
        return "0 / 0", a(now), a(prev)
    end
    return string.format(st.fmt, base[st.key] or 0), string.format(st.fmt, now[st.key] or 0), prev and string.format(st.fmt, prev[st.key] or 0) or nil
end

function U:prerender()
    -- drawn BEFORE the children (the button stays on top)
    self:scan()
    local ok, err = pcall(self.drawAll, self)
    if not ok then TWALogOnce("bagui:" .. tostring(err), "BagUpUI", "bag page error: %s", tostring(err)) end
end

function U:drawAll()
    local L = self:layout()
    local f, lh, row = L.f, L.lh, L.row
    local mx, my = self:getMouseX(), self:getMouseY()
    self.hits, self.tip = {}, nil
    local H = L.bottom - L.top
    panel(self, L.lx, L.top, L.lw, H)
    panel(self, L.cx, L.top, L.cw, H)
    panel(self, L.rx, L.top, L.rw, H)

    -- ---------------------------------------------------- left: your bags
    self:drawText(getText("IGUI_TWA_BagUp_Bags"), L.lx + 8, L.top + 6, C.acc[1], C.acc[2], C.acc[3], 1, L.fm)
    local rules = wrapText(getText("IGUI_TWA_BagUp_PageRules"), L.lw - 20, f)
    local rulesH = #rules * (lh + 1) + 12
    local y = L.top + L.lhm + 12
    local listBottom = L.bottom - rulesH - 8
    local shown = math.max(1, math.floor((listBottom - y) / row))
    self.bagScroll = math.max(0, math.min(self.bagScroll, math.max(0, #self.bags - shown)))
    self.bagArea = { x = L.lx, y = y, w = L.lw, h = listBottom - y }
    if #self.bags == 0 then
        for i, l in ipairs(wrapText(getText("IGUI_TWA_BagUp_NoBags"), L.lw - 16, f)) do
            self:drawText(l, L.lx + 8, y + (i - 1) * (lh + 1), C.dim[1], C.dim[2], C.dim[3], 1, f)
        end
    end
    for i = self.bagScroll + 1, math.min(#self.bags, self.bagScroll + shown) do
        local bag = self.bags[i]
        local sel = bag == self.bag
        local hov = inside(mx, my, L.lx + 2, y, L.lw - 4, row - 2)
        if sel or hov then self:drawRect(L.lx + 2, y, L.lw - 4, row - 2, sel and 0.28 or 0.12, C.acc[1], C.acc[2], C.acc[3]) end
        if sel then self:drawRectBorder(L.lx + 2, y, L.lw - 4, row - 2, 0.9, C.acc[1], C.acc[2], C.acc[3]) end
        local t = itemTex(bag)
        if t then self:drawTextureScaledAspect(t, L.lx + 6, y + 3, row - 8, row - 8, 1, 1, 1, 1) end
        local tier = B.tierOf(bag)
        local tx = L.lx + row + 2
        self:drawText(fit((B.inUse(bag) and "* " or "") .. bag:getDisplayName(), L.lx + L.lw - 8 - tx, f), tx, y + 3, C.text[1], C.text[2], C.text[3], 1, f)
        local sub = tier > 0 and getText("IGUI_TWA_BagUp_TierShort", tostring(tier), tostring(#B.upsOf(bag)), tostring(tier)) or getText("IGUI_TWA_BagUp_Tier0Short")
        local c = tier > 0 and C.acc or C.dim
        self:drawText(fit(sub, L.lx + L.lw - 8 - tx, f), tx, y + 3 + lh, c[1], c[2], c[3], 1, f)
        self.hits[#self.hits + 1] = { x = L.lx, y = y, w = L.lw, h = row, kind = "bag", item = bag }
        if hov then self.tip = B.tooltipLines(bag) or { { text = getText("IGUI_TWA_BagUp_Tier0Tip"), color = TC.dim } } end
        y = y + row
    end
    if #self.bags > shown then
        local s = string.format("%d-%d / %d", self.bagScroll + 1, math.min(#self.bags, self.bagScroll + shown), #self.bags)
        self:drawText(s, L.lx + L.lw - textW(s, f) - 8, L.top + 8, C.dim[1], C.dim[2], C.dim[3], 1, f)
    end
    -- the rules
    local ry = L.bottom - rulesH - 4
    self:drawRect(L.lx + 6, ry, L.lw - 12, rulesH, 0.85, 0.10, 0.07, 0.02)
    self:drawRectBorder(L.lx + 6, ry, L.lw - 12, rulesH, 0.8, 1, 0.6, 0.2)
    for i, l in ipairs(rules) do self:drawText(l, L.lx + 12, ry + 6 + (i - 1) * (lh + 1), C.text[1], C.text[2], C.text[3], 1, f) end

    -- ---------------------------------------------------- centre: the bag
    local bag = self.bag
    if not bag then
        for i, l in ipairs(wrapText(getText("IGUI_TWA_BagUp_PickBag"), L.cw - 20, f)) do
            self:drawText(l, L.cx + 10, L.top + 10 + (i - 1) * (lh + 1), C.dim[1], C.dim[2], C.dim[3], 1, f)
        end
    else
        local tier, ups = B.tierOf(bag), B.upsOf(bag)
        y = L.top + 6
        self:drawText(fit(bag:getDisplayName(), L.cw - 16, L.fm), L.cx + 8, y, C.text[1], C.text[2], C.text[3], 1, L.fm)
        y = y + L.lhm + 2
        self:drawText(getText("IGUI_TWA_BagUp_TierLine", tostring(tier), tostring(B.MAX_TIER)), L.cx + 8, y, C.acc[1], C.acc[2], C.acc[3], 1, f)
        y = y + lh + 6
        -- the picture
        local statsH = (#STATS + 1) * (lh + 3) + 8
        local slotS = 46
        local picH = math.max(48, L.bottom - y - statsH - slotS - 30)
        local pic = math.min(picH, L.cw - 40, 180)
        self:drawRect(L.cx + 8, y, L.cw - 16, pic + 12, 0.8, 0.07, 0.055, 0.03)
        local t = itemTex(bag)
        if t then self:drawTextureScaledAspect(t, L.cx + (L.cw - pic) / 2, y + 6, pic, pic, 1, 1, 1, 1) end
        y = y + pic + 20
        -- the slots, one per tier
        local n = math.max(1, tier)
        local gap = 10
        local total = n * slotS + (n - 1) * gap
        local sx = L.cx + math.floor((L.cw - total) / 2)
        if tier == 0 then
            for i, l in ipairs(wrapText(getText("IGUI_TWA_BagUp_NeedTier"), L.cw - 20, f)) do
                self:drawText(l, L.cx + 10, y + (i - 1) * (lh + 1), C.bad[1], C.bad[2], C.bad[3], 1, f)
            end
        else
            for s = 1, tier do
                local x0 = sx + (s - 1) * (slotS + gap)
                local up = ups[s]
                local sel = self.selSlot == s
                local hov = inside(mx, my, x0, y, slotS, slotS)
                local showPick = (not up) and self.pick and s == #ups + 1
                self:drawRect(x0, y, slotS, slotS, 1, sel and 0.25 or 0.06, sel and 0.18 or 0.05, sel and 0.04 or 0.03)
                local bc = sel and C.acc or (up and { 0.7, 0.55, 0.2 } or { 0.35, 0.3, 0.2 })
                self:drawRectBorder(x0, y, slotS, slotS, 1, bc[1], bc[2], bc[3])
                local tt = up and typeTex(up) or (showPick and typeTex(self.pick))
                if tt then
                    local a = showPick and (0.55 + 0.35 * math.sin(getTimestampMs() * 0.008)) or 1
                    self:drawTextureScaledAspect(tt, x0 + 5, y + 5, slotS - 10, slotS - 10, a, 1, 1, 1)
                elseif not showPick then
                    self:drawText("+", x0 + slotS / 2 - 4, y + slotS / 2 - lh / 2, 0.4, 0.35, 0.25, 1, f)
                end
                self.hits[#self.hits + 1] = { x = x0, y = y, w = slotS, h = slotS, kind = "slot", idx = s, filled = up ~= nil }
                if hov then
                    if up then
                        self.tip = { { text = typeName(up), color = TC.gold }, { text = B.effectText(up), color = TC.good },
                            { text = getText("IGUI_TWA_BagUp_SlotTip", tostring(B.returnChance(self.player))), color = TC.dim } }
                    else
                        self.tip = { { text = getText("IGUI_TWA_BagUp_EmptySlot", tostring(s)), color = TC.dim } }
                    end
                end
            end
        end
        y = y + slotS + 10
        -- the values: base -> now (-> with the picked add-on)
        local base, now = B.base(bag), B.compute(bag)
        local prev = self.pick and B.canInstall(bag, self.pickItem) and B.compute(bag, self.pick) or nil
        if base and now then
            local vx = L.cx + math.floor(L.cw * 0.52)
            self:drawText(getText("IGUI_TWA_BagUp_StatsHead"), L.cx + 10, y, C.dim[1], C.dim[2], C.dim[3], 1, f)
            y = y + lh + 3
            for _, st in ipairs(STATS) do
                if y + lh > L.bottom - 4 then break end
                local b0, n0, p0 = statText(st, base, now, prev)
                local hov = inside(mx, my, L.cx + 4, y - 1, L.cw - 8, lh + 2)
                if hov then self:drawRect(L.cx + 4, y - 1, L.cw - 8, lh + 2, 0.15, C.acc[1], C.acc[2], C.acc[3]) end
                self:drawText(fit(getText("IGUI_TWA_BagUpStat_" .. st.key), vx - L.cx - 14, f), L.cx + 10, y, C.text[1], C.text[2], C.text[3], 1, f)
                local changed = n0 ~= b0
                local c = changed and C.good or C.text
                local v = changed and (b0 .. " > " .. n0) or n0
                self:drawText(v, vx, y, c[1], c[2], c[3], 1, f)
                if p0 and p0 ~= n0 then
                    self:drawText(" > " .. p0, vx + textW(v, f), y, C.acc[1], C.acc[2], C.acc[3], 1, f)
                end
                if hov then self.tip = { { text = getText("IGUI_TWA_BagUpStat_" .. st.key), color = TC.gold }, { text = getText("IGUI_TWA_BagUpStatTip_" .. st.key), color = TC.text } } end
                y = y + lh + 3
            end
        end
    end

    -- ---------------------------------------------------- right: add-ons
    self:drawText(getText("IGUI_TWA_BagUp_Items"), L.rx + 8, L.top + 6, C.acc[1], C.acc[2], C.acc[3], 1, L.fm)
    local perRow = math.max(2, math.floor((L.rw - 16 + GAP) / (CELL + GAP)))
    local gy0 = L.top + L.lhm + 14
    local rowsShown = math.max(1, math.floor((L.bottom - gy0 - 8) / (CELL + GAP)))
    local maxRow = math.max(0, math.ceil(#self.ups / perRow) - rowsShown)
    self.upRow = math.max(0, math.min(self.upRow, maxRow))
    self.upArea = { x = L.rx, y = L.top, w = L.rw, h = H }
    if maxRow > 0 then
        local s = string.format("%d / %d", self.upRow + 1, maxRow + 1)
        self:drawText(s, L.rx + L.rw - textW(s, f) - 8, L.top + 8, C.dim[1], C.dim[2], C.dim[3], 1, f)
    end
    if #self.ups == 0 then
        for i, l in ipairs(wrapText(getText("IGUI_TWA_BagUp_NoItems"), L.rw - 16, f)) do
            self:drawText(l, L.rx + 8, gy0 + (i - 1) * (lh + 1), C.dim[1], C.dim[2], C.dim[3], 1, f)
        end
    end
    local gridW = perRow * CELL + (perRow - 1) * GAP
    local gx0 = L.rx + math.floor((L.rw - gridW) / 2)
    for i = self.upRow * perRow + 1, math.min(#self.ups, (self.upRow + rowsShown) * perRow) do
        local g = self.ups[i]
        local k = i - self.upRow * perRow - 1
        local gx, gy = gx0 + (k % perRow) * (CELL + GAP), gy0 + math.floor(k / perRow) * (CELL + GAP)
        local ok, why = false, "IGUI_TWA_BagUp_PickBag"
        if self.bag then ok, why = B.canInstall(self.bag, g.item) end
        local sel = self.pick == g.type
        local hov = inside(mx, my, gx, gy, CELL, CELL)
        self:drawRect(gx, gy, CELL, CELL, 1, sel and 0.25 or (hov and 0.12 or 0.06), sel and 0.18 or (hov and 0.1 or 0.05), sel and 0.04 or 0.03)
        local bc = sel and C.acc or (ok and { 0.5, 0.42, 0.2 } or { 0.3, 0.27, 0.22 })
        self:drawRectBorder(gx, gy, CELL, CELL, 1, bc[1], bc[2], bc[3])
        local tx = typeTex(g.type)
        if tx then self:drawTextureScaledAspect(tx, gx + 6, gy + 5, CELL - 12, CELL - 12, ok and 1 or 0.3, 1, 1, 1) end
        local tl = "T" .. tostring(g.e.tier)
        self:drawText(tl, gx + 3, gy + 1, C.acc[1], C.acc[2], C.acc[3], ok and 1 or 0.5, f)
        local ct = "x" .. tostring(g.count)
        self:drawText(ct, gx + CELL - textW(ct, f) - 3, gy + CELL - lh - 1, 1, 1, 1, ok and 1 or 0.5, f)
        self.hits[#self.hits + 1] = { x = gx, y = gy, w = CELL, h = CELL, kind = "up", g = g, ok = ok, why = why }
        if hov then
            self.tip = {
                { text = typeName(g.type) .. " (T" .. g.e.tier .. ")", color = TC.gold },
                { text = B.effectText(g.type), color = TC.good },
                { text = getText("IGUI_TWA_BagUpStatTip_" .. g.e.kind), color = TC.text },
                { text = ok and getText("IGUI_TWA_BagUp_CanFit") or getText(why or "IGUI_TWA_BagUp_Refused"), color = ok and TC.good or { r = 1, g = 0.5, b = 0.4 } },
            }
        end
    end

    -- ---------------------------------------------------- the button
    local op = self:pendingOp()
    self.confirmBtn.enable = op ~= nil
    if op == "remove" then
        self.confirmBtn:setTitle(getText("IGUI_TWA_BagUp_RemoveBtn", tostring(B.returnChance(self.player))))
    else
        self.confirmBtn:setTitle(getText("IGUI_TWA_BagUp_Fit"))
    end
    self.confirmBtn:setX(self.width - 8 - self.confirmBtn.width)
    self.confirmBtn:setY(self.height - 46)
    -- what to do next / the server's answer, left of the button
    local msg, mc
    if self.msg and getTimestampMs() < (self.msgUntil or 0) then msg, mc = self.msg, self.msgOk and C.good or C.bad
    else msg, mc = getText(op == "remove" and "IGUI_TWA_BagUp_HintRemove" or (op and "IGUI_TWA_BagUp_HintFit" or "IGUI_TWA_BagUp_HintPick")), C.dim end
    local lines = wrapText(msg, self.width - 30 - self.confirmBtn.width, f)
    for i = 1, math.min(2, #lines) do
        self:drawText(lines[i], 12, self.height - 46 + (i - 1) * (lh + 1) + (#lines == 1 and 10 or 2), mc[1], mc[2], mc[3], 1, f)
    end
end

-- after the children: the hover box
function U:render()
    local tip = self.tip
    if not tip or #tip == 0 then return end
    local f = TWAFont.small()
    local lh = TWAFont.lineH(f)
    local maxW = 320
    local lines = {}
    for _, l in ipairs(tip) do
        for _, w in ipairs(wrapText(l.text, maxW, f)) do lines[#lines + 1] = { text = w, color = l.color } end
    end
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, textW(l.text, f)) end
    w = w + 16
    local h = #lines * (lh + 1) + 10
    local x, y = self:getMouseX() + 16, self:getMouseY() + 16
    if x + w > self.width then x = self:getMouseX() - w - 8 end
    if y + h > self.height then y = self.height - h end
    self:drawRect(x, y, w, h, 0.95, 0.05, 0.04, 0.02)
    self:drawRectBorder(x, y, w, h, 1, 0.85, 0.64, 0.18)
    for i, l in ipairs(lines) do
        self:drawText(l.text, x + 8, y + 5 + (i - 1) * (lh + 1), l.color.r, l.color.g, l.color.b, 1, f)
    end
end

-- "fit": an add-on picked that fits; "remove": a filled slot picked
function U:pendingOp()
    if not self.bag then return nil end
    if self.pick and self.pickItem and B.canInstall(self.bag, self.pickItem) then return "fit" end
    if self.selSlot and B.upsOf(self.bag)[self.selSlot] then return "remove" end
    return nil
end

function U:onConfirm()
    local op = self:pendingOp()
    if op == "fit" then
        log("fit %s into %s", TWALogType(self.pickItem), TWALogType(self.bag))
        B.requestInstall(self.player, self.bag, self.pickItem)
        self:flash("IGUI_TWA_BagUp_Asked", true)
    elseif op == "remove" then
        local ok, why = B.canRemove(self.bag, self.selSlot)
        if ok then
            log("take slot %d out of %s", self.selSlot, TWALogType(self.bag))
            B.requestRemove(self.player, self.bag, self.selSlot)
        else
            self:flash(why, false)
        end
    end
    self.pick, self.pickItem, self.selSlot = nil, nil, nil
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
                if self.bag ~= h.item then self.pick, self.pickItem, self.selSlot = nil, nil, nil end
                self.bag = h.item
                log("bag picked: %s (tier %d)", TWALogType(h.item), B.tierOf(h.item))
            elseif h.kind == "slot" then
                self.selSlot = (h.filled and self.selSlot ~= h.idx) and h.idx or nil
                if self.selSlot then self.pick, self.pickItem = nil, nil end
            elseif h.kind == "up" then
                if not h.ok then
                    self:flash(h.why or "IGUI_TWA_BagUp_Refused", false)
                elseif self.pick == h.g.type then
                    self.pick, self.pickItem = nil, nil
                else
                    self.pick, self.pickItem, self.selSlot = h.g.type, h.g.item, nil
                end
            end
            getSoundManager():playUISound("UISelectListItem")
            return true
        end
    end
    return ISPanel.onMouseDown(self, x, y)
end
function U:onMouseWheel(del)
    local mx = self:getMouseX()
    local a = self.upArea
    if a and mx >= a.x and mx < a.x + a.w then self.upRow = self.upRow + (del > 0 and 1 or -1)
    else self.bagScroll = self.bagScroll + (del > 0 and 1 or -1) end
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
    -- 1.3.2 (owner: "a flashlight like vanilla's ALICE belt", then "put it in
    -- the small slot"): the SMALL slot also takes what vanilla's ALICE webbing
    -- slot takes (WebbingLeft / WebbingRight: "Webbing" = the angle-head
    -- flashlights), hung at the webbing's own model place
    local wL, wR = src.WebbingLeft, src.WebbingRight
    local function smallAttach(belt, webbing)
        local a = copyTable(belt.attachments)
        for k, v in pairs((webbing and webbing.attachments) or {}) do
            if a[k] == nil then a[k] = v end
        end
        return a
    end
    for i = 1, U.SLOT_MAX do
        local s = (i % 2 == 1) and sL or sR
        local w = (i % 2 == 1) and wL or wR
        local h = (i % 2 == 1) and hR or hL
        table.insert(ISHotbarAttachDefinition, { type = "TWABagS" .. i, name = getText("IGUI_TWA_BagSlotS"), animset = s.animset, attachments = smallAttach(s, w) })
        table.insert(ISHotbarAttachDefinition, { type = "TWABagL" .. i, name = getText("IGUI_TWA_BagSlotL"), animset = h.animset, attachments = copyTable(h.attachments) })
    end
    defsMade = true
    local function kinds(t)
        local out = {}
        for k in pairs(t or {}) do out[#out + 1] = tostring(k) end
        table.sort(out)
        return table.concat(out, ", ")
    end
    log("hotbar: %d extra slot types made; small slot takes: %s%s; large slot takes: %s", U.SLOT_MAX * 2,
        kinds(smallAttach(sL, wL)), wL and "" or " (the game's WebbingLeft slot NOT found -- no flashlight)", kinds(hR.attachments))
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
            if not page or not page.backpacks then return end
            -- 1.5.7: broken Inventory Tetris grids off bags in the window
            -- (begin: before Tetris builds them, end: the new list)
            if state ~= "begin" and state ~= "end" then return end
            for _, bp in ipairs(page.backpacks) do
                local inv = bp.inventory
                local it = inv and inv.getContainingItem and inv:getContainingItem()
                if it then
                    pcall(B.repairTetrisGrid, it)
                    -- 1.5.8: capacity + Tetris grid key set before Tetris builds it
                    pcall(B.apply, it)
                end
            end
        end)
    end
end
installHotbar()

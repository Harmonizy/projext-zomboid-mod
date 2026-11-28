--[[
    HARMONIE Hub: Inventory Helper (the same file in every HARMONIE mod;
    master copy mods/_HarmonieHub, install.sh).

    Owner 2026-11-28: "buttons to manage what I carry and the boxes, a
    search, anything that makes it easier" -- chose: search, quick stack,
    grid sort, favourite lock; a SEPARATE window; inside the HARMONIE Hub.

    Tabs
      search  type a name (Thai or English): every matching item on you, in
              your bags and in the boxes of the room (HARMONIE_Reach: same
              room <= 12 tiles, outdoors <= 3), grouped by item type + where
              it lies. "Take" brings them to your main inventory (vanilla
              transfer; walks to a far box first). The star marks / unmarks
              the vanilla favourite of carried items.
      stack   "quick stack": every carried item whose type a box in the
              room already holds goes into that box (the one holding most
              of it, while it has room). Never moved: favourites (the lock),
              worn / equipped / hotbar items, bags. Your bags' contents only
              when ticked.
    (grid sort: needs Inventory Tetris' own code -- not here yet)

    Lists follow the hub's Refresh rule: a scan is kept until the Refresh
    button, the window opening or one of OUR moves (afterActions) -- scope
    "INV"; the button glows when your items changed meanwhile.
    Everything moves through vanilla ISInventoryTransferAction (MP-safe:
    the game checks it on the server). Logs [HARMONIE_Hub][InvHelper].
]]--

require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"

HARMONIE_InvHelper = HARMONIE_InvHelper or {}
local IH = HARMONIE_InvHelper
if IH.loaded then return end
IH.loaded = true
IH.SCOPE = "INV"
IH.TABS = { "search", "stack" }
IH.MAX_ROWS = 400

-- ------------------------------------------------------------------ helpers
local function log(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print("[HARMONIE_Hub][InvHelper] " .. (ok and s or tostring(fmt)))
end
local logged = {}
local function logOnce(key, fmt, ...)
    if logged[key] then return end
    logged[key] = true
    log(fmt, ...)
end
local function T(key, ...)
    local ok, s = pcall(getText, key, ...)
    if ok and s and s ~= key then return s end
    return key
end
local function call(o, m, ...)
    if not o then return nil end
    local f = o[m]
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, o, ...)
    if ok then return v end
    return nil
end
local function nameOf(p)
    local ok, n = pcall(function() return p:getUsername() end)
    return (ok and n) and tostring(n) or "?"
end
local function fontH(f) return getTextManager():getFontHeight(f or UIFont.Small) end
local function textW(s, f) return getTextManager():MeasureStringX(f or UIFont.Small, tostring(s or "")) end
local function inside(x, y, r) return r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h end
local function fit(s, maxW, f)
    s = tostring(s or "")
    if textW(s, f) <= maxW then return s end
    -- cut whole characters (a Thai letter is one char in the game's Lua)
    local n = #s
    while n > 0 and textW(s:sub(1, n) .. "..", f) > maxW do n = n - 1 end
    return s:sub(1, n) .. ".."
end
local function lower(s)
    local ok, r = pcall(string.lower, tostring(s or ""))
    return ok and r or tostring(s or "")
end

local function refresh() return HARMONIE_Refresh end
local function gen()
    local R = refresh()
    return R and R.gen and R.gen(IH.SCOPE) or 1
end

-- where an item lies, in words
local function containerLabel(c, where)
    if where == "inv" then
        local holder = call(c, "getContainingItem")
        if holder then return tostring(call(holder, "getDisplayName") or "?") end
        return T("IGUI_HUB_Inv_WhereMe")
    end
    local holder = call(c, "getContainingItem")
    if holder then return tostring(call(holder, "getDisplayName") or "?") end
    local ty = tostring(call(c, "getType") or "?")
    local key = "IGUI_ContainerTitle_" .. ty
    local s = T(key)
    if s == key then s = ty end
    return s
end

-- an item the quick stack / sort must never move
local function locked(player, item)
    if call(item, "isFavorite") == true then return "fav" end
    if call(item, "isEquipped") == true or call(item, "isWorn") == true then return "worn" end
    if call(player, "isEquipped", item) == true then return "worn" end
    local slot = tonumber(call(item, "getAttachedSlot")) or -1
    if slot > -1 then return "worn" end
    if instanceof and instanceof(item, "InventoryContainer") then return "bag" end
    return nil
end

-- ------------------------------------------------------------------ scan
-- one walk over everything within reach -> groups { key, ft, name, lname,
-- tex, where, label, cont, items = {...}, carried }
function IH.scan(player)
    local Reach = HARMONIE_Reach
    local out, byKey = {}, {}
    if not (player and Reach and Reach.each) then return out end
    if Reach.forget then Reach.forget(player) end
    local t0 = getTimestampMs and getTimestampMs() or 0
    local n = 0
    Reach.each(player, function(it, cont, where)
        n = n + 1
        local ft = call(it, "getFullType")
        if not ft then return nil end
        local key = ft .. "|" .. tostring(cont)
        local g = byKey[key]
        if not g then
            local name = tostring(call(it, "getDisplayName") or ft)
            g = { key = key, ft = ft, name = name, lname = lower(name) .. " " .. lower(ft), tex = call(it, "getTex"),
                where = where, cont = cont, label = containerLabel(cont, where), items = {},
                carried = where == "inv" }
            byKey[key] = g
            out[#out + 1] = g
        end
        g.items[#g.items + 1] = it
        return nil
    end)
    table.sort(out, function(a, b)
        if a.carried ~= b.carried then return a.carried end
        if a.name ~= b.name then return a.name < b.name end
        return a.label < b.label
    end)
    local t1 = getTimestampMs and getTimestampMs() or 0
    log("%s: scanned %d item(s) in %d group(s), %d ms", nameOf(player), n, #out, t1 - t0)
    return out
end

-- ------------------------------------------------------------------ actions
local function transfer(player, item, src, dest)
    if not (ISTimedActionQueue and ISInventoryTransferAction) then return false end
    local ok, err = pcall(function()
        ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, src, dest))
    end)
    if not ok then logOnce("tfail:" .. tostring(err), "transfer FAILED: %s", tostring(err)) end
    return ok
end

-- bring every item of a group to the main inventory
function IH.take(player, g)
    local inv = call(player, "getInventory")
    if not (inv and g) then return 0 end
    local Reach = HARMONIE_Reach
    local n = 0
    local walked = false
    for _, it in ipairs(g.items) do
        local src = call(it, "getContainer")
        if src and src ~= inv then
            if not g.carried and not walked and Reach and Reach.walkTo then
                Reach.walkTo(player, src)
                walked = true
            end
            if transfer(player, it, src, inv) then n = n + 1 end
        end
    end
    log("%s: take %d x %s from %s (%s)", nameOf(player), n, g.ft, g.label, g.where)
    if n > 0 and refresh() and refresh().afterActions then refresh().afterActions(IH.SCOPE, player, "take") end
    return n
end

-- star: mark / unmark the vanilla favourite of a carried group
function IH.toggleFav(player, g)
    if not (g and g.carried) then return end
    local all = true
    for _, it in ipairs(g.items) do if call(it, "isFavorite") ~= true then all = false end end
    local want = not all
    for _, it in ipairs(g.items) do pcall(function() it:setFavorite(want) end) end
    log("%s: favourite %s x%d -> %s", nameOf(player), g.ft, #g.items, tostring(want))
end
local function isFav(g)
    for _, it in ipairs(g.items) do if call(it, "isFavorite") ~= true then return false end end
    return #g.items > 0
end

-- room left in a box (kg); nil = unknown
local function roomLeft(player, c)
    local cap = tonumber(call(c, "getEffectiveCapacity", player)) or tonumber(call(c, "getCapacity"))
    local used = tonumber(call(c, "getCapacityWeight"))
    if not (cap and used) then return nil end
    return cap - used
end

-- quick stack plan: { moves = { {item, src, dest, g, label} }, skipped = { fav, worn, bag, full } }
function IH.planStack(player, groups, withBags)
    local plan = { moves = {}, rows = {}, skipped = { fav = 0, worn = 0, bag = 0, full = 0 } }
    local inv = call(player, "getInventory")
    -- boxes by item type: the box holding most of it first
    local boxesOf = {}
    for _, g in ipairs(groups or {}) do
        if not g.carried and (g.where == "box" or g.where == "floor") then
            local l = boxesOf[g.ft] or {}
            l[#l + 1] = g
            boxesOf[g.ft] = l
        end
    end
    for _, l in pairs(boxesOf) do table.sort(l, function(a, b) return #a.items > #b.items end) end
    local added = {}
    for _, g in ipairs(groups or {}) do
        local mine = g.carried and (withBags or g.cont == inv)
        local boxes = mine and boxesOf[g.ft]
        if boxes then
            local row = nil
            for _, it in ipairs(g.items) do
                local why = locked(player, it)
                if why then
                    plan.skipped[why] = plan.skipped[why] + 1
                else
                    local w = tonumber(call(it, "getUnequippedWeight")) or tonumber(call(it, "getActualWeight")) or 0
                    local dest = nil
                    for _, b in ipairs(boxes) do
                        local left = roomLeft(player, b.cont)
                        if left == nil or left - (added[b.cont] or 0) >= w then dest = b; break end
                    end
                    if dest then
                        added[dest.cont] = (added[dest.cont] or 0) + w
                        plan.moves[#plan.moves + 1] = { item = it, src = g.cont, dest = dest.cont }
                        if not row or row.dest ~= dest.cont then
                            row = { name = g.name, tex = g.tex, n = 0, dest = dest.cont, label = dest.label }
                            plan.rows[#plan.rows + 1] = row
                        end
                        row.n = row.n + 1
                    else
                        plan.skipped.full = plan.skipped.full + 1
                    end
                end
            end
        end
    end
    return plan
end

-- queue the moves, box by box (walking to each first)
function IH.runStack(player, plan)
    if not (plan and #plan.moves > 0) then return 0 end
    local Reach = HARMONIE_Reach
    local order, byDest = {}, {}
    for _, m in ipairs(plan.moves) do
        if not byDest[m.dest] then byDest[m.dest] = {}; order[#order + 1] = m.dest end
        table.insert(byDest[m.dest], m)
    end
    local n = 0
    for _, dest in ipairs(order) do
        if Reach and Reach.walkTo then Reach.walkTo(player, dest) end
        for _, m in ipairs(byDest[dest]) do
            if transfer(player, m.item, m.src, m.dest) then n = n + 1 end
        end
    end
    local s = plan.skipped
    log("%s: quick stack queued %d move(s) into %d box(es); kept: favourite %d, worn/hotbar %d, bags %d, no room %d",
        nameOf(player), n, #order, s.fav, s.worn, s.bag, s.full)
    if n > 0 and refresh() and refresh().afterActions then refresh().afterActions(IH.SCOPE, player, "quick stack") end
    return n
end

-- ------------------------------------------------------------------ window
HARMONIE_InvHelperUI = ISPanel:derive("HARMONIE_InvHelperUI")
local W = HARMONIE_InvHelperUI
local C = {
    bg = { 0.05, 0.06, 0.07 }, head = { 0.08, 0.12, 0.12 }, row = { 0.09, 0.10, 0.11 }, rowHi = { 0.13, 0.17, 0.17 },
    accent = { 0.36, 0.86, 0.74 }, text = { 0.92, 0.94, 0.94 }, dim = { 0.60, 0.66, 0.66 }, gold = { 1.0, 0.82, 0.25 },
    btn = { 0.12, 0.30, 0.27 }, off = { 0.18, 0.18, 0.19 },
}
local HEAD_H, TAB_H, PAD = 28, 26, 10

function W:new(x, y, player)
    local o = ISPanel:new(x, y, 600, 540)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.tab = "search"
    o.filter = "all"
    o.scroll = 0
    o.withBags = false
    o.moveWithMouse = true
    o.backgroundColor = { r = C.bg[1], g = C.bg[2], b = C.bg[3], a = 0.96 }
    o.borderColor = { r = C.accent[1], g = C.accent[2], b = C.accent[3], a = 0.8 }
    o.hits = {}
    return o
end

function W:createChildren()
    ISPanel.createChildren(self)
    local b = ISTextEntryBox:new("", PAD, HEAD_H + TAB_H + 8, 300, fontH() + 8)
    b.font = UIFont.Small
    b:initialise()
    b:instantiate()
    if b.setPlaceholderText then pcall(function() b:setPlaceholderText(T("IGUI_HUB_Inv_Placeholder")) end) end
    local win = self
    b.onTextChange = function() win.scroll = 0; win.cacheQ = nil end
    self:addChild(b)
    self.searchBox = b
end

function W:query()
    local ok, t = pcall(function() return self.searchBox:getText() end)
    return ok and lower(t or "") or ""
end

-- the scan of this window (kept until the scope's generation changes)
function W:groups()
    local g = gen()
    if not self.data or self.dataGen ~= g then
        self.data = IH.scan(self.player)
        self.dataGen = g
        self.cacheQ = nil
        self.plan = nil
    end
    return self.data
end

function W:filtered()
    local q, f = self:query(), self.filter
    local key = q .. "|" .. f .. "|" .. tostring(self.dataGen)
    if self.cacheQ == key then return self.cacheList end
    local out = {}
    if q ~= "" then
        for _, g in ipairs(self:groups()) do
            local where = (f == "all") or (f == "mine" and g.carried) or (f == "near" and not g.carried)
            if where and g.lname:find(q, 1, true) then
                out[#out + 1] = g
                if #out >= IH.MAX_ROWS then break end
            end
        end
    end
    self.cacheQ, self.cacheList = key, out
    return out
end

function W:btn(id, label, x, y, w, h, enabled, mx, my, tip)
    local hov = enabled and inside(mx, my, { x = x, y = y, w = w, h = h })
    local c = enabled and C.btn or C.off
    self:drawRect(x, y, w, h, hov and 1 or 0.85, c[1] + (hov and 0.08 or 0), c[2] + (hov and 0.08 or 0), c[3] + (hov and 0.08 or 0))
    self:drawRectBorder(x, y, w, h, 0.9, C.accent[1], C.accent[2], C.accent[3])
    local tc = enabled and C.text or C.dim
    self:drawTextCentre(label, x + w / 2, y + (h - fontH()) / 2, tc[1], tc[2], tc[3], 1, UIFont.Small)
    if enabled then self.hits[#self.hits + 1] = { id = id, x = x, y = y, w = w, h = h } end
    if hov and tip then self.tipText = tip end
end

function W:prerender()
    ISPanel.prerender(self)
    self.hits = {}
    self.tipText = nil
    local mx, my = self:getMouseX(), self:getMouseY()
    -- header
    self:drawRect(0, 0, self.width, HEAD_H, 0.95, C.head[1], C.head[2], C.head[3])
    self:drawText(T("IGUI_HUB_Inv_Title"), PAD, (HEAD_H - fontH(UIFont.Medium)) / 2, C.accent[1], C.accent[2], C.accent[3], 1, UIFont.Medium)
    self:btn("close", "X", self.width - 26, 4, 20, 20, true, mx, my)
    -- tabs
    local tx = PAD
    for _, id in ipairs(IH.TABS) do
        local label = T("IGUI_HUB_Inv_Tab_" .. id)
        local w = textW(label) + 24
        local on = self.tab == id
        local hov = inside(mx, my, { x = tx, y = HEAD_H + 2, w = w, h = TAB_H - 4 })
        self:drawRect(tx, HEAD_H + 2, w, TAB_H - 4, on and 0.95 or (hov and 0.6 or 0.35), on and C.btn[1] or C.off[1], on and C.btn[2] or C.off[2], on and C.btn[3] or C.off[3])
        local tc = on and C.text or C.dim
        self:drawTextCentre(label, tx + w / 2, HEAD_H + 2 + (TAB_H - 4 - fontH()) / 2, tc[1], tc[2], tc[3], 1, UIFont.Small)
        self.hits[#self.hits + 1] = { id = "tab:" .. id, x = tx, y = HEAD_H + 2, w = w, h = TAB_H - 4 }
        tx = tx + w + 4
    end
    if self.searchBox then self.searchBox:setVisible(self.tab == "search") end
    local top = HEAD_H + TAB_H + 8
    -- Refresh (both tabs): glows while your items changed since the scan
    local R = refresh()
    local rl = R and R.label and R.label() or "Refresh"
    local rw = textW(rl) + 20
    local rx = self.width - PAD - rw
    self:btn("refresh", rl, rx, top, rw, fontH() + 8, true, mx, my, R and R.tip and R.tip(IH.SCOPE) or nil)
    if R and R.glow then R.glow(self, rx, top, rw, fontH() + 8, IH.SCOPE) end
    self:groups()
    if self.tab == "search" then self:drawSearch(top, rx, mx, my) else self:drawStack(top, rx, mx, my) end
end

function W:drawSearch(top, rx, mx, my)
    local b = self.searchBox
    local bw = rx - PAD - 8 - PAD
    if b and (b.width ~= bw) then b:setWidth(bw) end
    if b and b.y ~= top then b:setY(top) end
    local y = top + fontH() + 16
    -- where: all / on me / boxes around
    local x = PAD
    for _, f in ipairs({ "all", "mine", "near" }) do
        local label = T("IGUI_HUB_Inv_Filter_" .. f)
        local w = textW(label) + 18
        local on = self.filter == f
        local c = on and C.btn or C.off
        self:drawRect(x, y, w, fontH() + 4, on and 0.95 or 0.5, c[1], c[2], c[3])
        local tc = on and C.text or C.dim
        self:drawTextCentre(label, x + w / 2, y + 2, tc[1], tc[2], tc[3], 1, UIFont.Small)
        self.hits[#self.hits + 1] = { id = "filter:" .. f, x = x, y = y, w = w, h = fontH() + 4 }
        x = x + w + 4
    end
    y = y + fontH() + 12
    local list = self:filtered()
    if self:query() == "" then
        self:drawText(T("IGUI_HUB_Inv_SearchHint"), PAD, y, C.dim[1], C.dim[2], C.dim[3], 1, UIFont.Small)
        return
    end
    if #list == 0 then
        self:drawText(T("IGUI_HUB_Inv_NoResult"), PAD, y, C.dim[1], C.dim[2], C.dim[3], 1, UIFont.Small)
        return
    end
    self:drawText(T("IGUI_HUB_Inv_Results", tostring(#list)), PAD, y, C.dim[1], C.dim[2], C.dim[3], 1, UIFont.Small)
    y = y + fontH() + 4
    self:drawRows(list, y, mx, my, function(g, ry, rh)
        -- star (carried only) + Take
        local takeL = T("IGUI_HUB_Inv_Take")
        local tw = textW(takeL) + 18
        local bx = self.width - PAD - 10 - tw
        local inv = call(self.player, "getInventory")
        local canTake = not (g.carried and g.cont == inv)
        self:btn("take:" .. g.key, takeL, bx, ry + 3, tw, rh - 6, canTake, mx, my, T("IGUI_HUB_Inv_TakeTip"))
        if g.carried then
            local fav = isFav(g)
            local sx = bx - 28
            local c = fav and C.gold or C.dim
            self:drawRectBorder(sx, ry + 3, 22, rh - 6, 0.8, c[1], c[2], c[3])
            self:drawTextCentre(fav and "*" or "-", sx + 11, ry + (rh - fontH(UIFont.Medium)) / 2, c[1], c[2], c[3], 1, UIFont.Medium)
            self.hits[#self.hits + 1] = { id = "fav:" .. g.key, x = sx, y = ry + 3, w = 22, h = rh - 6 }
            if inside(mx, my, { x = sx, y = ry + 3, w = 22, h = rh - 6 }) then self.tipText = T("IGUI_HUB_Inv_FavTip") end
            return sx - 6
        end
        return bx - 6
    end)
end

-- rows with an icon, name x count and where; right(g, y, h) draws the
-- buttons and returns the x where the text must stop
function W:drawRows(list, top, mx, my, right)
    local rh = math.max(26, fontH() + 10)
    local viewH = self.height - top - PAD
    local total = #list * rh
    self.maxScroll = math.max(0, total - viewH)
    if self.scroll > self.maxScroll then self.scroll = self.maxScroll end
    self.rowsByKey = {}
    self:setStencilRect(0, top, self.width, viewH)
    for i, g in ipairs(list) do
        local ry = top + (i - 1) * rh - self.scroll
        if ry + rh >= top and ry <= top + viewH then
            local hov = inside(mx, my, { x = PAD, y = ry, w = self.width - 2 * PAD, h = rh }) and my >= top and my <= top + viewH
            local c = hov and C.rowHi or C.row
            self:drawRect(PAD, ry + 1, self.width - 2 * PAD - 8, rh - 2, 0.9, c[1], c[2], c[3])
            if g.tex then pcall(function() self:drawTextureScaledAspect(g.tex, PAD + 4, ry + 3, rh - 6, rh - 6, 1, 1, 1, 1) end) end
            self.rowsByKey[g.key] = g
            -- buttons only on a row fully in view (a half-hidden row's
            -- button would sit over the chips above the list)
            local full = ry >= top - 1 and ry + rh <= top + viewH + 1
            local stopX = (right and full) and right(g, ry, rh) or (self.width - PAD - 12)
            local nx = PAD + rh + 4
            local name = g.name .. ((g.n or #(g.items or {})) > 1 and ("  x" .. tostring(g.n or #g.items)) or "")
            local avail = stopX - nx
            local where = g.label or ""
            local whereW = math.min(textW(where) + 8, math.floor(avail * 0.45))
            self:drawText(fit(name, avail - whereW - 6), nx, ry + (rh - fontH()) / 2, C.text[1], C.text[2], C.text[3], 1, UIFont.Small)
            local wc = g.carried and C.accent or C.dim
            local ws = fit(where, whereW)
            self:drawText(ws, stopX - textW(ws) - 4, ry + (rh - fontH()) / 2, wc[1], wc[2], wc[3], 1, UIFont.Small)
        end
    end
    self:clearStencilRect()
    if self.maxScroll > 0 then
        local barH = math.max(20, viewH * viewH / total)
        local barY = top + (viewH - barH) * (self.scroll / self.maxScroll)
        self:drawRect(self.width - PAD - 5, barY, 4, barH, 0.8, C.accent[1], C.accent[2], C.accent[3])
    end
end

function W:drawStack(top, rx, mx, my)
    local y = top + 4
    local intro = T("IGUI_HUB_Inv_StackIntro")
    for line in tostring(intro):gmatch("[^\n]+") do
        self:drawText(fit(line, rx - PAD - 10), PAD, y, C.dim[1], C.dim[2], C.dim[3], 1, UIFont.Small)
        y = y + fontH() + 2
    end
    y = math.max(y, top + fontH() + 14) + 4
    -- tick: your bags' contents too
    local box = fontH()
    self:drawRectBorder(PAD, y, box, box, 0.9, C.accent[1], C.accent[2], C.accent[3])
    if self.withBags then self:drawRect(PAD + 3, y + 3, box - 6, box - 6, 1, C.accent[1], C.accent[2], C.accent[3]) end
    local tl = T("IGUI_HUB_Inv_StackBags")
    self:drawText(tl, PAD + box + 6, y, C.text[1], C.text[2], C.text[3], 1, UIFont.Small)
    self.hits[#self.hits + 1] = { id = "bags", x = PAD, y = y, w = box + 8 + textW(tl), h = box }
    y = y + box + 10
    local key = tostring(self.dataGen) .. "|" .. tostring(self.withBags)
    if not self.plan or self.planKey ~= key then
        self.plan = IH.planStack(self.player, self:groups(), self.withBags)
        self.planKey = key
    end
    local plan = self.plan
    local n = #plan.moves
    local goL = n > 0 and T("IGUI_HUB_Inv_StackGo", tostring(n)) or T("IGUI_HUB_Inv_StackNone")
    local gw = textW(goL) + 30
    self:btn("stackgo", goL, PAD, y, gw, fontH() + 10, n > 0, mx, my)
    local s = plan.skipped
    local kept = T("IGUI_HUB_Inv_StackKept", tostring(s.fav), tostring(s.worn), tostring(s.bag), tostring(s.full))
    self:drawText(fit(kept, self.width - gw - 3 * PAD), PAD + gw + 10, y + 5, C.dim[1], C.dim[2], C.dim[3], 1, UIFont.Small)
    y = y + fontH() + 18
    local rows = {}
    for i, r in ipairs(plan.rows) do
        rows[i] = { key = "s" .. i, name = r.name, tex = r.tex, n = r.n, label = "> " .. r.label, carried = false, items = {} }
    end
    self:drawRows(rows, y, mx, my, nil)
end

function W:render()
    ISPanel.render(self)
    if self.tipText and self.tipText ~= "" then
        local mx, my = self:getMouseX(), self:getMouseY()
        local lines = {}
        for l in tostring(self.tipText):gmatch("[^\n]+") do lines[#lines + 1] = l end
        local w = 0
        for _, l in ipairs(lines) do w = math.max(w, textW(l)) end
        local h = #lines * (fontH() + 2) + 8
        local x = math.min(mx + 14, self.width - w - 14)
        local y = my + 18
        self:drawRect(x, y, w + 12, h, 0.95, 0.03, 0.03, 0.04)
        self:drawRectBorder(x, y, w + 12, h, 0.9, C.accent[1], C.accent[2], C.accent[3])
        for i, l in ipairs(lines) do self:drawText(l, x + 6, y + 4 + (i - 1) * (fontH() + 2), C.text[1], C.text[2], C.text[3], 1, UIFont.Small) end
    end
end

function W:onMouseDown(x, y)
    for i = #self.hits, 1, -1 do
        local h = self.hits[i]
        if inside(x, y, h) then
            self:click(h.id)
            return true
        end
    end
    return ISPanel.onMouseDown(self, x, y)
end

function W:click(id)
    local p = self.player
    if id == "close" then return self:close() end
    if id == "refresh" then
        if refresh() and refresh().bump then refresh().bump(IH.SCOPE, "Refresh button") end
        return
    end
    local tab = id:match("^tab:(.+)$")
    if tab then self.tab = tab; self.scroll = 0; log("%s: tab %s", nameOf(p), tab); return end
    local f = id:match("^filter:(.+)$")
    if f then self.filter = f; self.scroll = 0; return end
    if id == "bags" then self.withBags = not self.withBags; self.plan = nil; return end
    if id == "stackgo" then IH.runStack(p, self.plan); self.plan = nil; return end
    local k = id:match("^take:(.+)$")
    if k then local g = self.rowsByKey and self.rowsByKey[k]; if g then IH.take(p, g) end; return end
    k = id:match("^fav:(.+)$")
    if k then local g = self.rowsByKey and self.rowsByKey[k]; if g then IH.toggleFav(p, g) end; return end
end

function W:onMouseWheel(del)
    self.scroll = math.max(0, math.min(self.maxScroll or 0, self.scroll + del * 40))
    return true
end

function W:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if IH.window == self then IH.window = nil end
    log("%s: window closed", nameOf(self.player))
end

function IH.isOpen()
    return IH.window ~= nil and IH.window.getIsVisible and IH.window:getIsVisible() == true
end

function IH.open(player, tab)
    player = player or (getSpecificPlayer and getSpecificPlayer(0))
    if not player then return end
    local w = IH.window
    if not w then
        local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
        w = W:new(math.floor((sw - 600) / 2), math.floor((sh - 540) / 2), player)
        w:initialise()
        w:addToUIManager()
        IH.window = w
    else
        w.player = player
        w:setVisible(true)
        w:bringToTop()
    end
    if tab then w.tab = tab end
    -- opening the window looks again (hub Refresh rule)
    if refresh() and refresh().bump then refresh().bump(IH.SCOPE, "window opened") end
    log("%s: window opened (%s)", nameOf(player), tostring(w.tab))
    return w
end

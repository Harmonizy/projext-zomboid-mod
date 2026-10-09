--[[
    HARMONIE - From Garden to Plate: the guide window's Cooking tab.

    0.13.2 (owner: "มีสูตรอาหารที่ไม่ต้องการเลเวล ให้เห็นทุกสูตร และมี layout
    เหมือนการสร้างอาวุธของ TWA"): every recipe is open at any Cooking level,
    and the tab is laid out like The Way To Attack's craft window -- two
    pages:
      browse  left: search, what to show (all / can make now) and the dish
              kinds; right: every recipe as a card -- its icon, name, kind
              and suggested level, whether it can be made now, and the icons
              of its steps.
      craft   left: the chosen dish -- the vanilla base it starts from, its
              ingredients (what is at hand, what vanilla refuses), a preview
              of what it will be (vanilla calories, carbohydrates, fat,
              protein, hunger -- vitamins only to a cook who knows
              nutrition), and Back. Right: its steps as a checklist, the
              chosen step's details (tools, helpers, heat, suggested level)
              and Start. While a dish is being made the right side follows
              it step by step, and at the end shows the real vanilla dish
              item and how to cook it.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminGuide"
require "HARMONIEGardenToPlate/HARMONIE_CookFlow"
require "HARMONIEGardenToPlate/HARMONIE_CookGames"
require "HARMONIEGardenToPlate/HARMONIE_CookFX"

local H = GTPGuide
local Win = GTPGuideWindow
local K = HARMONIE_GTP.Cook
local F = HARMONIE_GTP.CookFlow
local U = H.util
local T, shadowText, fit, inside, clickable, lineH, fh, tw, texture =
    U.T, U.shadowText, U.fit, U.inside, U.clickable, U.lineH, U.fh, U.tw, U.texture
local log = function(...) K.log(...) end

H.COOK_FILTERS = { "all", "ready" }

-- the dish kinds, in the order the dishes list them
function H.cookFamilies()
    if H.cookFamList then return H.cookFamList end
    local out, seen = {}, {}
    for _, d in ipairs(K.DISHES) do
        if not seen[d.family] then seen[d.family] = true; out[#out + 1] = d.family end
    end
    H.cookFamList = out
    return out
end

local function dishName(d) return T("IGUI_GTPC_Dish_" .. d.id) end
local function procName(pid) return T("IGUI_GTPC_Proc_" .. pid) end
local function procIcon(pid) return texture(U.UI_DIR .. "cook_" .. pid .. ".png") end

local function itemName(t)
    local i = H.item(t)
    return i and i.name or t
end
local function itemIcon(t)
    local i = H.item(t)
    return i and i.icon or nil
end

local function famIcon(d)
    local fam = K.FAMILIES[d.family]
    return fam and itemIcon(fam.icon) or nil
end

-- a slot's label: up to three of its foods by name, and the kinds it also
-- takes ("or any vegetable")
local function slotLabel(slot)
    local names, seen = {}, {}
    for _, t in ipairs(K.slotTypes(slot)) do
        local n = itemName(t)
        if not seen[n] then seen[n] = true; names[#names + 1] = n end
        if #names >= 3 then break end
    end
    local more = #K.slotTypes(slot) > #names and " ..." or ""
    local label = table.concat(names, " / ") .. more
    if slot.cats and #slot.cats > 0 then
        local kinds = {}
        for _, c in ipairs(slot.cats) do kinds[#kinds + 1] = T("IGUI_GTPC_Kind_" .. c) end
        label = label .. " " .. T("IGUI_GTPC_OrAny", table.concat(kinds, " / "))
    end
    return label
end

-- plans are worked out at most every 1.5 s (the scan's own pace)
function Win:cookPlans()
    local scan = K.scan(self.player)
    if self.cookPlanAt == scan.at and self.cookPlanList then return self.cookPlanList, scan end
    self.cookPlanAt = scan.at
    local list = {}
    for _, d in ipairs(K.DISHES) do
        local ok, p = pcall(K.plan, self.player, d, scan)
        if ok then list[d.id] = p else K.logOnce("planfail:" .. d.id, "plan for %s FAILED: %s", d.id, tostring(p)) end
    end
    self.cookPlanList = list
    return list, scan
end

function Win:renderCook(x, y, w, h)
    local C = H.C
    if type(K.DISHES) ~= "table" or type(K.FAMILIES) ~= "table" then
        -- never throw every frame: say it once in console.txt and on screen
        K.logOnce("nodata", "ERROR: the cooking data did not load (K.DISHES is %s) -- the last [CookData] line in console.txt shows how far it got (5/5 = done)", type(K.DISHES))
        local tx, ty, tw2 = self:drawCard(x, y, w, h, T("IGUI_GTPC_Card_Intro"))
        self:paragraphs(T("IGUI_GTPC_NoData"), tx, ty, tw2 - 8, C.bad, H.small())
        return
    end
    local plans = self:cookPlans()
    -- a dish being made always shows its craft page
    if F.run then
        if self.cookSel ~= F.run.dish.id then self.cookSel = F.run.dish.id end
        self.cookPage = "craft"
    end
    local d = self.cookSel and K.DISH_BY_ID[self.cookSel]
    if self.cookPage == "craft" and d then return self:renderCookCraft(x, y, w, h, d, plans[d.id]) end
    self.cookPage = "browse"
    return self:renderCookBrowse(x, y, w, h, plans)
end

-- a row of chips that wraps; items = { { label, on, action } }; returns the height used
function Win:cookChips(items, x, y, wMax)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local cx, cy = x, y
    for _, it in ipairs(items) do
        local cw = tw(sf, it.label) + 18
        if cx > x and cx + cw > x + wMax then cx = x; cy = cy + lh + 10 end
        local r = { x = cx, y = cy, w = cw, h = lh + 6 }
        local over = inside(r, self:getMouseX(), self:getMouseY())
        self:drawRect(r.x, r.y, r.w, r.h, it.on and 0.95 or (over and 0.8 or 0.6), C.accentDark[1], C.accentDark[2], C.accentDark[3])
        self:drawRectBorder(r.x, r.y, r.w, r.h, it.on and 1 or 0.5, C.border[1], C.border[2], C.border[3])
        shadowText(self, it.label, r.x + 9, r.y + 3, it.on and C.text or C.textDim, 1, sf)
        r.action = it.action
        clickable(self, r)
        cx = cx + cw + 6
    end
    return cy + lh + 6 - y
end

-- ---------------------------------------------------------------- browse
function Win:renderCookBrowse(x, y, w, h, plans)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local mx, my = self:getMouseX(), self:getMouseY()
    local leftW = math.min(270, math.floor(w * 0.3))
    -- filters
    local cx, cy, cw = self:drawCard(x, y, leftW, h, T("IGUI_GTPC_Card_Filters"), texture(U.UI_DIR .. "tab_cook.png"))
    local used = self:placeSearch(cx, cy, cw - 4, true)
    cy = cy + used + 8
    shadowText(self, T("IGUI_GTPC_Show"), cx, cy, C.accent, 1, sf)
    cy = cy + lh + 2
    local items = {}
    for _, f in ipairs(H.COOK_FILTERS) do
        items[#items + 1] = { label = T("IGUI_GTPC_Filter_" .. f), on = (self.cookFilter or "all") == f,
            action = function(win) win.cookFilter = f; log("cooking filter: %s", f) end }
    end
    cy = cy + self:cookChips(items, cx, cy, cw - 6) + 8
    shadowText(self, T("IGUI_GTPC_Kinds"), cx, cy, C.accent, 1, sf)
    cy = cy + lh + 2
    items = { { label = T("IGUI_GTPC_AllKinds"), on = self.cookFam == nil, action = function(win) win.cookFam = nil; log("cooking kind: all") end } }
    for _, fam in ipairs(H.cookFamilies()) do
        items[#items + 1] = { label = T("IGUI_GTPC_Family_" .. fam), on = self.cookFam == fam,
            action = function(win) win.cookFam = fam; log("cooking kind: %s", fam) end }
    end
    cy = cy + self:cookChips(items, cx, cy, cw - 6) + 10
    -- the dish buff on this character now (an Excellent dish eaten)
    local buff = K.myBuffNow and K.myBuffNow(self.player)
    if buff then
        local line = T("IGUI_GTPC_BuffNow", T("IGUI_GTPC_Buff_" .. tostring(buff.kind)), string.format("%.1f", buff.hoursLeft))
        cy = cy + self:paragraphs(line, cx, cy, cw - 8, C.good, sf) + 6
    end
    if cy < y + h - lh * 4 then
        self:paragraphs(T("IGUI_GTPC_BrowseHint", tostring(K.level(self.player))), cx, cy, cw - 8, C.textDim, sf)
    end
    -- the recipes
    local q = self:query()
    local f = self.cookFilter or "all"
    local shown = {}
    for _, d in ipairs(K.DISHES) do
        local p = plans[d.id]
        local name = dishName(d)
        if (q == "" or name:lower():find(q, 1, true)) and (f ~= "ready" or (p and p.ready)) and (not self.cookFam or self.cookFam == d.family) then
            shown[#shown + 1] = d
        end
    end
    local rx, rw = x + leftW + 8, w - leftW - 8
    local lx, ly, lw, lh2 = self:drawCard(rx, y, rw, h, T("IGUI_GTPC_Card_Recipes", tostring(#shown), tostring(#K.DISHES)))
    local rowH = math.max(54, lh * 3 + 12)
    local boxTop, boxBottom = ly, ly + lh2
    self:scrolled("cookList", lx, ly, lw, lh2, function(yy)
        local start = yy
        for _, d in ipairs(shown) do
            local p = plans[d.id]
            local ready = p and p.ready
            local r = { x = lx, y = yy, w = lw - 10, h = rowH }
            local over = inside(r, mx, my) and inside(self.scrollBox and self.scrollBox.cookList, mx, my)
            local stateCol = ready and C.good or C.warn
            self:drawRect(r.x, r.y, r.w, r.h, over and 0.85 or 0.6, C.card[1] + 0.02, C.card[2] + 0.04, C.card[3] + 0.02)
            self:drawRectBorder(r.x, r.y, r.w, r.h, over and 1 or 0.6, (over and C.border or C.borderDim)[1], (over and C.border or C.borderDim)[2], (over and C.border or C.borderDim)[3])
            self:drawRect(r.x, r.y, 4, r.h, 1, stateCol[1], stateCol[2], stateCol[3])
            local isz = rowH - 12
            local icon = famIcon(d)
            self:drawRect(r.x + 10, r.y + 6, isz, isz, 0.5, 0, 0, 0)
            if icon then self:drawTextureScaled(icon, r.x + 10, r.y + 6, isz, isz, 1, 1, 1, 1) end
            local tx = r.x + 10 + isz + 10
            local textMax = r.x + r.w - 10 - tx
            local l1 = fit(dishName(d), textMax, sf)
            local l2 = fit(T("IGUI_GTPC_Family_" .. d.family) .. "  -  " .. T("IGUI_GTPC_Suggested", tostring(d.level or 0)), textMax, sf)
            local l3 = fit(ready and T("IGUI_GTPC_CanMake") or T("IGUI_GTPC_Why_" .. tostring(p and p.reasons[1] or "ingredients")), textMax, sf)
            local ty0 = r.y + math.floor((rowH - lh * 3) / 2)
            shadowText(self, l1, tx, ty0, C.text, 1, sf)
            shadowText(self, l2, tx, ty0 + lh, C.textDim, 1, sf)
            shadowText(self, l3, tx, ty0 + lh * 2, stateCol, 1, sf)
            -- the steps, right-aligned after the widest line (as many as fit)
            local widest = math.max(tw(sf, l1), tw(sf, l2), tw(sf, l3), 120)
            local ps, gap = math.min(28, rowH - 22), 4
            local room = r.x + r.w - 10 - (tx + widest + 14)
            local n = math.min(#d.procs, math.floor((room + gap) / (ps + gap)))
            if n > 0 then
                local px = r.x + r.w - 10 - n * (ps + gap) + gap
                local py = r.y + math.floor((rowH - ps) / 2)
                for i = 1, n do
                    local pid = d.procs[i]
                    local pp = p and p.procs[i]
                    self:drawRect(px, py, ps, ps, 0.6, 0.01, 0.04, 0.02)
                    local bc = (pp and not pp.ok) and C.bad or C.borderDim
                    self:drawRectBorder(px, py, ps, ps, 0.8, bc[1], bc[2], bc[3])
                    local pic = procIcon(pid)
                    if pic then self:drawTextureScaled(pic, px + 2, py + 2, ps - 4, ps - 4, 1, 1, 1, 1) end
                    if i == n and n < #d.procs then shadowText(self, "+" .. tostring(#d.procs - n + 1), px + 3, py + 3, C.text, 1, sf) end
                    px = px + ps + gap
                end
            end
            r.action = function(win)
                log("cooking: chose %s", d.id)
                win.cookSel = d.id
                win.cookPage = "craft"
                win.cookStep = 1
                win.scroll.cookDetail = 0
            end
            -- only cards that can be seen take clicks
            if r.y + r.h > boxTop and r.y < boxBottom then clickable(self, r) end
            yy = yy + rowH + 4
        end
        if #shown == 0 then
            shadowText(self, T("IGUI_GTPG_NoMatch"), lx, yy, C.textDim, 1, sf)
            yy = yy + lh
        end
        return yy - start
    end)
end

-- a coloured status line
local function status(self, text, x, y, ok, sf)
    local C = H.C
    local col = ok == true and C.good or (ok == false and C.bad or C.warn)
    self:drawRect(x, y + math.floor(lineH(sf) / 2) - 3, 6, 6, 1, col[1], col[2], col[3])
    shadowText(self, text, x + 12, y, ok == false and C.bad or C.text, 1, sf)
end

function Win:cookButton(x, y, label, enabled, action, wide)
    local C = H.C
    local sf = H.small()
    local r = { x = x, y = y, w = wide or (tw(sf, label) + 30), h = lineH(sf) + 12 }
    local over = inside(r, self:getMouseX(), self:getMouseY())
    self:drawRect(r.x, r.y, r.w, r.h, enabled and (over and 1 or 0.9) or 0.4, C.accentDark[1], C.accentDark[2], C.accentDark[3])
    self:drawRectBorder(r.x, r.y, r.w, r.h, enabled and 1 or 0.4, C.accent[1], C.accent[2], C.accent[3])
    shadowText(self, label, r.x + math.floor((r.w - tw(sf, label)) / 2), r.y + 6, enabled and C.text or C.textDim, 1, sf)
    if enabled then r.action = action; clickable(self, r) end
    return r.w, r.h
end

local VIT_ORDER = { "A", "B", "C", "D", "E", "K" }

-- ---------------------------------------------------------------- craft
function Win:renderCookCraft(x, y, w, h, d, p)
    local leftW = math.floor(w * 0.5)
    self:renderCookInfo(x, y, leftW, h, d, p)
    local rx, rw = x + leftW + 8, w - leftW - 8
    if F.run then return self:renderCookRun(rx, y, rw, h, F.run) end
    self:renderCookSteps(rx, y, rw, h, d, p)
end

-- left: the dish itself
function Win:renderCookInfo(x, y, w, h, d, p)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local tx, ty, tw2 = self:drawCard(x, y, w, h, dishName(d), famIcon(d))
    local btnY = y + h - lh - 22
    self:scrolled("cookDetail", tx, ty, tw2, btnY - ty - 6, function(yy)
        local start = yy
        yy = yy + self:paragraphs(T("IGUI_GTPC_DishDesc_" .. d.id), tx, yy, tw2 - 10, C.textDim, sf) + 6
        if K.buffOfDish and K.buffOfDish(d.id) and K.buffsOn() then
            local kind = K.buffOfDish(d.id)
            yy = yy + self:paragraphs(T("IGUI_GTPC_BuffIfExcellent", T("IGUI_GTPC_Buff_" .. kind), T("IGUI_GTPC_BuffDesc_" .. kind),
                string.format("%.0f", K.buffHours(p and p.level or 0))), tx, yy, tw2 - 10, C.accent, sf) + 6
        end
        -- suggested level (never a lock: below it the steps are harder)
        local lvl = p and p.level or 0
        local below = lvl < (d.level or 0)
        yy = yy + self:paragraphs(T(below and "IGUI_GTPC_SuggestedBelow" or "IGUI_GTPC_SuggestedOk", tostring(d.level or 0), tostring(lvl)),
            tx, yy, tw2 - 10, below and C.warn or C.good, sf) + 4
        -- base
        if p and p.base then
            local what = K.typeOf(p.base)
            status(self, T(p.fam.partial and "IGUI_GTPC_BaseStarted" or "IGUI_GTPC_BaseFound", itemName(what)), tx, yy, true, sf)
        else
            -- vanilla's own bases for this dish (evolvedrecipes.txt)
            local need = K.baseNeed(d.family)
            local names, seen = {}, {}
            for _, t in ipairs(need.types) do
                local n = itemName(t)
                if not seen[n] then seen[n] = true; names[#names + 1] = n end
            end
            local what = #names > 0 and table.concat(names, " / ") or "?"
            if need.water then what = T("IGUI_GTPC_WithWater", what) end
            -- like status(), but the text may wrap (several bases)
            self:drawRect(tx, yy + math.floor(lh / 2) - 3, 6, 6, 1, C.bad[1], C.bad[2], C.bad[3])
            yy = yy + math.max(lh, self:paragraphs(T("IGUI_GTPC_BaseNeed", what), tx + 12, yy, tw2 - 22, C.bad, sf)) - lh
        end
        yy = yy + lh + 6
        -- ingredients
        shadowText(self, T("IGUI_GTPC_Ingredients"), tx, yy, C.accent, 1, sf); yy = yy + lh + 2
        for _, sp in ipairs(p and p.slots or {}) do
            local slot = sp.slot
            local icon = sp.items[1] and K.call(sp.items[1], "getTexture") or itemIcon(K.slotTypes(slot)[1])
            if icon then self:drawTextureScaled(icon, tx, yy, lh + 4, lh + 4, (sp.have > 0) and 1 or 0.4, 1, 1, 1) end
            local label = slotLabel(slot)
            local tag = slot.spice and T("IGUI_GTPC_Spice") or (slot.optional and T("IGUI_GTPC_Optional") or "")
            local count = T("IGUI_GTPC_Have", tostring(sp.have), tostring(sp.need))
            local ok = sp.have >= sp.need
            local col = ok and C.good or (slot.optional and C.textDim or C.bad)
            -- the count at the right edge, the slot's name (and its tag) before it
            local cw = tw(sf, count)
            local cxr = tx + tw2 - 14 - cw
            shadowText(self, count, cxr, yy + 2, col, 1, sf)
            local nameW = cxr - (tx + lh + 10) - 10
            local tagW = tag ~= "" and math.min(tw(sf, tag), math.floor(nameW * 0.45)) or 0
            local lab = fit(label, nameW - tagW - (tagW > 0 and 8 or 0), sf)
            shadowText(self, lab, tx + lh + 10, yy + 2, C.text, 1, sf)
            if tagW > 0 then shadowText(self, fit(tag, tagW, sf), tx + lh + 10 + tw(sf, lab) + 8, yy + 2, C.textDim, 1, sf) end
            yy = yy + lh + 6
            local refused = {}
            for t in pairs(sp.refused) do refused[#refused + 1] = itemName(t) end
            if #refused > 0 then
                table.sort(refused)
                yy = yy + self:paragraphs(T("IGUI_GTPC_Refused", table.concat(refused, ", ")), tx + lh + 10, yy, tw2 - lh - 20, C.warn, sf) + 2
            end
            local raw = {}
            for t in pairs(sp.uncooked) do raw[#raw + 1] = itemName(t) end
            if #raw > 0 then
                table.sort(raw)
                yy = yy + self:paragraphs(T("IGUI_GTPC_CookFirst", table.concat(raw, ", ")), tx + lh + 10, yy, tw2 - lh - 20, C.warn, sf) + 2
            end
        end
        if p and p.trimmed then yy = yy + self:paragraphs(T("IGUI_GTPC_Trimmed", tostring(p.maxItems or "?")), tx, yy, tw2 - 10, C.warn, sf) + 2 end
        yy = yy + 6
        -- preview
        shadowText(self, T("IGUI_GTPC_Preview"), tx, yy, C.accent, 1, sf); yy = yy + lh + 2
        local pv = p and p.preview
        if pv and #p.adds > 0 then
            local line = T("IGUI_GTPC_PreviewLine", string.format("%.0f", pv.cal), string.format("%.0f", pv.carb),
                string.format("%.0f", pv.fat), string.format("%.0f", pv.prot), string.format("%.0f", pv.hunger * 100))
            yy = yy + self:paragraphs(line, tx, yy, tw2 - 10, C.text, sf) + 2
            if H.knows(self.player) then
                local vits = {}
                for _, v in ipairs(VIT_ORDER) do
                    if (pv.vit[v] or 0) > 0.05 then vits[#vits + 1] = string.format("%s %.1f %s", v, pv.vit[v], H.UNITS[v] or "") end
                end
                yy = yy + self:paragraphs(#vits > 0 and T("IGUI_GTPC_PreviewVit", table.concat(vits, ", ")) or T("IGUI_GTPC_PreviewNoVit"), tx, yy, tw2 - 10, C.text, sf) + 2
            else
                yy = yy + self:paragraphs(T("IGUI_GTPC_PreviewVitLocked", tostring(H.KNOW_COOKING)), tx, yy, tw2 - 10, C.textDim, sf) + 2
            end
            yy = yy + self:paragraphs(T("IGUI_GTPC_PreviewNote"), tx, yy, tw2 - 10, C.textDim, sf)
        else
            yy = yy + self:paragraphs(T("IGUI_GTPC_PreviewNone"), tx, yy, tw2 - 10, C.textDim, sf)
        end
        return yy - start
    end)
    -- back to the recipes (not while the dish is being made)
    if not F.run then
        self:cookButton(tx, btnY, T("IGUI_GTPC_Back"), true, function(win)
            win.cookPage = "browse"
            log("cooking: back to the recipes")
        end)
    end
end

-- right: the steps as a checklist, the chosen step's details, Start
function Win:renderCookSteps(x, y, w, h, d, p)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local mx, my = self:getMouseX(), self:getMouseY()
    local tx, ty, tw2 = self:drawCard(x, y, w, h, T("IGUI_GTPC_Steps"))
    local btnY = y + h - lh - 22
    local procs = p and p.procs or {}
    self.cookStep = math.max(1, math.min(#d.procs, self.cookStep or 1))
    local rowH = lh + 14
    local listH = math.min(#d.procs * (rowH + 3), math.floor((btnY - ty) * 0.5))
    self:scrolled("cookSteps", tx, ty, tw2, listH, function(yy)
        local start = yy
        for i, pid in ipairs(d.procs) do
            local pp = procs[i]
            local r = { x = tx, y = yy, w = tw2 - 10, h = rowH }
            local sel = self.cookStep == i
            local over = inside(r, mx, my) and inside(self.scrollBox and self.scrollBox.cookSteps, mx, my)
            local ok = pp and pp.ok
            local col = ok and C.good or C.bad
            self:drawRect(r.x, r.y, r.w, r.h, sel and 0.95 or (over and 0.75 or 0.5), C.accentDark[1], C.accentDark[2], C.accentDark[3])
            if sel then self:drawRectBorder(r.x, r.y, r.w, r.h, 1, C.accent[1], C.accent[2], C.accent[3]) end
            self:drawRect(r.x, r.y, 3, r.h, 1, col[1], col[2], col[3])
            local pic = procIcon(pid)
            if pic then self:drawTextureScaled(pic, r.x + 8, r.y + 3, rowH - 6, rowH - 6, 1, 1, 1, 1) end
            local state = not pp and "" or (pp.ok and T("IGUI_GTPC_StepReady") or T(pp.noHeat and "IGUI_GTPC_StepNoHeat" or "IGUI_GTPC_StepNoTool"))
            local sw = tw(sf, state)
            shadowText(self, state, r.x + r.w - 8 - sw, r.y + 7, col, 1, sf)
            shadowText(self, fit(tostring(i) .. ". " .. procName(pid), r.w - (rowH + 16) - sw - 16, sf), r.x + rowH + 8, r.y + 7, C.text, 1, sf)
            r.action = function(win) win.cookStep = i end
            clickable(self, r)
            yy = yy + rowH + 3
        end
        return yy - start
    end)
    -- the chosen step
    local dy = ty + listH + 8
    local pp = procs[self.cookStep]
    local pid = d.procs[self.cookStep]
    self:drawRect(tx, dy, tw2 - 10, btnY - dy - 8, 0.35, 0, 0, 0)
    self:drawRectBorder(tx, dy, tw2 - 10, btnY - dy - 8, 0.6, C.borderDim[1], C.borderDim[2], C.borderDim[3])
    local ix, iw = tx + 8, tw2 - 26
    self:scrolled("cookStepInfo", ix, dy + 6, iw + 8, btnY - dy - 20, function(yy)
        local start = yy
        local big = math.min(48, lh * 3)
        local pic = pid and procIcon(pid)
        if pic then self:drawTextureScaled(pic, ix, yy, big, big, 1, 1, 1, 1) end
        shadowText(self, pid and procName(pid) or "?", ix + big + 10, yy + 2, C.text, 1, H.medium())
        -- how its minigame is played (the hint it also shows)
        local hint = pid and T("IGUI_GTPC_Hint_" .. pid) or ""
        if hint:find("IGUI_", 1, true) then hint = "" end
        local used = self:paragraphs(hint, ix + big + 10, yy + lineH(H.medium()) + 4, iw - big - 10, C.textDim, sf)
        yy = yy + math.max(big, lineH(H.medium()) + 4 + used) + 8
        if pp then
            -- tools (a missing one with a "bare" fallback only makes it harder)
            for _, t in ipairs(pp.tools) do
                if t.item then
                    local grade = (t.grade == "ok" or t.grade == "makeshift") and (" " .. T("IGUI_GTPC_Grade_" .. t.grade)) or ""
                    status(self, fit(tostring(K.call(t.item, "getDisplayName")) .. grade, iw - 14, sf), ix, yy, t.grade == "best" and true or nil, sf)
                elseif t.grade == "bare" then
                    status(self, fit(T("IGUI_GTPC_Tool_" .. t.group) .. ": " .. T("IGUI_GTPC_Grade_bare"), iw - 14, sf), ix, yy, nil, sf)
                else
                    status(self, fit(T("IGUI_GTPC_NoTool", T("IGUI_GTPC_Tool_" .. t.group)), iw - 14, sf), ix, yy, false, sf)
                end
                yy = yy + lh + 2
            end
            if #pp.tools == 0 then status(self, T("IGUI_GTPC_NoToolNeeded"), ix, yy, true, sf); yy = yy + lh + 2 end
            for _, hp in ipairs(pp.help) do
                local name = hp.item and K.call(hp.item, "getDisplayName") or T("IGUI_GTPC_Tool_" .. hp.group)
                status(self, fit(T(hp.item and "IGUI_GTPC_Helps" or "IGUI_GTPC_WouldHelp", tostring(name)), iw - 14, sf), ix, yy, hp.item and true or nil, sf)
                yy = yy + lh + 2
            end
            -- heat
            if pp.proc and pp.proc.heat then
                status(self, fit(T(pp.heat and "IGUI_GTPC_HeatOk" or "IGUI_GTPC_HeatNeed", tostring(K.HEAT_RANGE)), iw - 14, sf), ix, yy, pp.heat ~= nil, sf)
                yy = yy + lh + 2
            end
            -- suggested level
            local sl = (pp.proc and pp.proc.level) or 0
            if sl > 0 then
                status(self, fit(T(pp.levelLow and "IGUI_GTPC_StepLevelLow" or "IGUI_GTPC_StepLevelOk", tostring(sl), tostring(p.level)), iw - 14, sf), ix, yy, (not pp.levelLow) or nil, sf)
                yy = yy + lh + 2
            end
        end
        return yy - start
    end)
    -- start
    local ready = p and p.ready
    local bw = self:cookButton(tx, btnY, T("IGUI_GTPC_Start"), ready, function(win)
        local ok, why = F.start(win.player, d)
        if not ok then log("start refused: %s", tostring(why)) end
    end)
    if not ready and p then
        local why = T("IGUI_GTPC_Why_" .. tostring(p.reasons[1] or "ingredients"))
        shadowText(self, fit(why, tw2 - bw - 16, sf), tx + bw + 10, btnY + 6, C.warn, 1, sf)
    end
end

local WORD_COL
local function wordCol(w)
    local C = H.C
    WORD_COL = WORD_COL or { Excellent = C.good, Good = C.accent, Bad = C.warn, Miss = C.bad }
    return WORD_COL[w] or C.textDim
end

function Win:renderCookRun(x, y, w, h, run)
    local C = H.C
    local sf, mf = H.small(), H.medium()
    local lh = lineH(sf)
    local d = run.dish
    local tx, ty, tw2 = self:drawCard(x, y, w, h, T("IGUI_GTPC_Making", dishName(d)), famIcon(d))
    local yy = ty
    -- step chips
    for i, pid in ipairs(d.procs) do
        local done = run.words[pid]
        local cur = i == run.step and run.phase ~= "adding" and run.phase ~= "done"
        local icon = procIcon(pid)
        if cur then self:drawRect(tx - 4, yy - 2, tw2, lh + 10, 0.7, C.accentDark[1], C.accentDark[2], C.accentDark[3]) end
        if icon then self:drawTextureScaled(icon, tx, yy, lh + 6, lh + 6, done and 1 or (cur and 1 or 0.5), 1, 1, 1) end
        local state = done and T("IGUI_GTPC_Word_" .. done) or (cur and T("IGUI_GTPC_Phase_" .. tostring(run.phase)) or "")
        shadowText(self, tostring(i) .. ". " .. procName(pid), tx + lh + 12, yy + 3, cur and C.text or C.textDim, 1, sf)
        shadowText(self, state, tx + tw2 - 170, yy + 3, done and wordCol(done) or C.warn, 1, sf)
        yy = yy + lh + 10
    end
    yy = yy + 4
    -- the ingredients going in
    if run.phase == "adding" then
        yy = yy + self:paragraphs(T("IGUI_GTPC_Adding", tostring(run.addIdx or 0), tostring(#(run.adds or {}))), tx, yy, tw2 - 10, C.text, sf) + 6
    end
    if run.phase == "failed" then
        yy = yy + self:paragraphs(T("IGUI_GTPC_Failed_" .. tostring(run.failReason or "ingredients")), tx, yy, tw2 - 10, C.bad, sf) + 6
    end
    if run.phase == "blocked" then
        yy = yy + self:paragraphs(T("IGUI_GTPC_Why_" .. tostring(run.blockedBy or "tools")), tx, yy, tw2 - 10, C.bad, sf) + 6
    end
    -- the finished dish (vanilla's own numbers)
    if run.phase == "done" then
        local item = F.resultItem()
        local q = run.quality or 0.66
        shadowText(self, T("IGUI_GTPC_Done", T("IGUI_GTPC_Word_" .. K.wordOf(q))), tx, yy, wordCol(K.wordOf(q)), 1, mf)
        yy = yy + lineH(mf) + 6
        if item then
            local icon = K.call(item, "getTexture")
            if icon then self:drawTextureScaled(icon, tx, yy, 48, 48, 1, 1, 1, 1) end
            local line = T("IGUI_GTPC_DishNow", tostring(K.call(item, "getDisplayName") or "?"),
                string.format("%.0f", tonumber(K.call(item, "getCalories")) or 0), string.format("%.0f", tonumber(K.call(item, "getCarbohydrates")) or 0),
                string.format("%.0f", tonumber(K.call(item, "getLipids")) or 0), string.format("%.0f", tonumber(K.call(item, "getProteins")) or 0),
                string.format("%.0f", math.abs(tonumber(K.call(item, "getHungerChange")) or 0) * 100))
            local used = self:paragraphs(line, tx + 58, yy, tw2 - 68, C.text, sf)
            yy = yy + math.max(52, used) + 4
            if H.knows(self.player) and HARMONIE_GTP.GetVitaminProfileForItem then
                local prof = HARMONIE_GTP.GetVitaminProfileForItem(item) or {}
                local vits = {}
                for _, v in ipairs(VIT_ORDER) do if (prof[v] or 0) > 0.05 then vits[#vits + 1] = string.format("%s %.1f %s", v, prof[v], H.UNITS[v] or "") end end
                yy = yy + self:paragraphs(#vits > 0 and T("IGUI_GTPC_PreviewVit", table.concat(vits, ", ")) or T("IGUI_GTPC_PreviewNoVit"), tx, yy, tw2 - 10, C.text, sf) + 4
            end
            local cooked = K.call(item, "isCooked") == true
            local cookable = K.call(item, "isIsCookable") == true or K.call(item, "isCookable") == true
            if K.wordOf(q) == "Excellent" and K.buffOfDish and K.buffOfDish(d.id) and K.buffsOn() then
                local kind = K.buffOfDish(d.id)
                local line = T("IGUI_GTPC_BuffWillGive", T("IGUI_GTPC_Buff_" .. kind), string.format("%.0f", K.buffHours(K.level(self.player))),
                    T("IGUI_GTPC_BuffDesc_" .. kind))
                yy = yy + self:paragraphs(line, tx, yy, tw2 - 10, C.good, sf) + 4
            end
            local key = cooked and "IGUI_GTPC_Cooked" or (cookable and "IGUI_GTPC_CookIt" or "IGUI_GTPC_ReadyToEat")
            yy = yy + self:paragraphs(T(key), tx, yy, tw2 - 10, cooked and C.good or C.warn, sf) + 6
        end
    end
    -- buttons
    local by = y + h - lh - 22
    local bx = tx
    if run.phase == "retry" or run.phase == "paused" or run.phase == "blocked" then
        bx = bx + self:cookButton(bx, by, T(run.phase == "retry" and "IGUI_GTPC_Retry" or "IGUI_GTPC_Continue"), true, function() F.retry() end) + 8
    end
    if run.phase == "done" or run.phase == "failed" then
        self:cookButton(bx, by, T("IGUI_GTPC_NewDish"), true, function() F.clear(); log("cooking: back to the list") end)
    else
        self:cookButton(bx, by, T("IGUI_GTPC_Cancel"), run.phase ~= "adding", function() F.cancel("button") end)
    end
end

if K.onQualityDone == nil then
    K.onQualityDone = function(args) log("cooking tab: server confirmed dish id %s", tostring(args and args.id)) end
end

-- 0.13.2: no recipes unlock with the Cooking level any more (all are open),
-- so the old "new recipes" notice on a level up is gone.

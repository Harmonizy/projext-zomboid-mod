--[[
    HARMONIE - From Garden to Plate: the guide window's Cooking tab.

    Left: the ready-made dishes (search, "can make now" filter). Right: the
    chosen dish -- the vanilla base it starts from, its ingredients (what is
    at hand, what vanilla refuses), the preparation steps with their tools
    and Cooking level, and a preview of what it will be (vanilla calories,
    carbohydrates, fat, protein, hunger -- and vitamins, shown like the
    rest of the guide only to a cook who knows nutrition). While a dish is
    being made the right side follows it step by step, and at the end shows
    the real vanilla dish item and how to cook it.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminGuide"
require "HARMONIEGardenToPlate/HARMONIE_CookFlow"
require "HARMONIEGardenToPlate/HARMONIE_CookGames"

local H = GTPGuide
local Win = GTPGuideWindow
local K = HARMONIE_GTP.Cook
local F = HARMONIE_GTP.CookFlow
local U = H.util
local T, shadowText, fit, inside, clickable, lineH, fh, tw, texture =
    U.T, U.shadowText, U.fit, U.inside, U.clickable, U.lineH, U.fh, U.tw, U.texture
local log = function(...) K.log(...) end

H.COOK_FILTERS = { "all", "ready" }

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

-- a slot's label: up to three of its foods by name
local function slotLabel(slot)
    local names, seen = {}, {}
    for _, t in ipairs(K.slotTypes(slot)) do
        local n = itemName(t)
        if not seen[n] then seen[n] = true; names[#names + 1] = n end
        if #names >= 3 then break end
    end
    local more = #K.slotTypes(slot) > #names and " ..." or ""
    return table.concat(names, " / ") .. more
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
    local sf, mf = H.small(), H.medium()
    local lh = lineH(sf)
    local mx, my = self:getMouseX(), self:getMouseY()
    local plans = self:cookPlans()
    local leftW = math.min(340, math.floor(w * 0.36))
    -- ---------------------------------------------------------- dish list
    local cx, cy, cw, ch = self:drawCard(x, y, leftW, h, T("IGUI_GTPC_Card_Dishes"), texture(U.UI_DIR .. "tab_cook.png"))
    local used = self:placeSearch(cx, cy, cw - 4, true)
    cy = cy + used + 6
    -- filter chips
    local chipX = cx
    for _, f in ipairs(H.COOK_FILTERS) do
        local label = T("IGUI_GTPC_Filter_" .. f)
        local r = { x = chipX, y = cy, w = tw(sf, label) + 18, h = lh + 6 }
        local on = (self.cookFilter or "all") == f
        self:drawRect(r.x, r.y, r.w, r.h, on and 0.95 or 0.6, C.accentDark[1], C.accentDark[2], C.accentDark[3])
        self:drawRectBorder(r.x, r.y, r.w, r.h, on and 1 or 0.5, C.border[1], C.border[2], C.border[3])
        shadowText(self, label, r.x + 9, r.y + 3, on and C.text or C.textDim, 1, sf)
        r.action = function(win) win.cookFilter = f; log("cooking filter: %s", f) end
        clickable(self, r)
        chipX = chipX + r.w + 6
    end
    cy = cy + lh + 12
    local q = self:query()
    local rowH = math.max(36, lh * 2 + 6)
    local boxTop, boxBottom = cy, y + h - 8
    self:scrolled("cookList", cx, cy, cw, y + h - 8 - cy, function(yy)
        local start = yy
        for _, d in ipairs(K.DISHES) do
            local p = plans[d.id]
            local name = dishName(d)
            local show = (q == "" or name:lower():find(q, 1, true)) and ((self.cookFilter or "all") ~= "ready" or (p and p.ready))
            if show then
                local r = { x = cx, y = yy, w = cw - 8, h = rowH }
                local sel = self.cookSel == d.id
                if sel or inside(r, mx, my) then self:drawRect(r.x, r.y, r.w, r.h, sel and 0.9 or 0.5, C.accentDark[1], C.accentDark[2], C.accentDark[3]) end
                if sel then self:drawRect(r.x, r.y, 3, r.h, 1, C.accent[1], C.accent[2], C.accent[3]) end
                local icon = famIcon(d)
                if icon then self:drawTextureScaled(icon, r.x + 6, r.y + 3, rowH - 6, rowH - 6, 1, 1, 1, 1) end
                local tx = r.x + rowH + 6
                shadowText(self, fit(name, r.w - (tx - r.x) - 24, sf), tx, r.y + 3, C.text, 1, sf)
                local sub = T("IGUI_GTPC_Family_" .. d.family) .. "  -  " .. T("IGUI_GTPC_LevelShort", tostring(d.level or 0))
                shadowText(self, fit(sub, r.w - (tx - r.x) - 24, sf), tx, r.y + 3 + lh, C.textDim, 1, sf)
                local col = (p and p.ready) and C.good or (p and p.level < (d.level or 0) and C.bad or C.warn)
                self:drawRect(r.x + r.w - 14, r.y + math.floor(rowH / 2) - 4, 8, 8, 1, col[1], col[2], col[3])
                r.action = function(win)
                    if win.cookSel ~= d.id then log("cooking: chose %s", d.id) end
                    win.cookSel = d.id
                    win.scroll.cookDetail = 0
                end
                -- only rows that can be seen take clicks (a row scrolled
                -- out of the box must not catch a click meant for the chips)
                if r.y + r.h > boxTop and r.y < boxBottom then clickable(self, r) end
                yy = yy + rowH + 2
            end
        end
        return yy - start
    end)
    -- ---------------------------------------------------------- right side
    local rx, rw = x + leftW + 8, w - leftW - 8
    local run = F.run
    if run then return self:renderCookRun(rx, y, rw, h, run) end
    local d = self.cookSel and K.DISH_BY_ID[self.cookSel]
    if not d then
        local tx, ty, tw2 = self:drawCard(rx, y, rw, h, T("IGUI_GTPC_Card_Intro"))
        self:paragraphs(T("IGUI_GTPC_Intro"), tx, ty, tw2 - 8, C.text, sf)
        return
    end
    self:renderCookDish(rx, y, rw, h, d, plans[d.id])
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

function Win:renderCookDish(x, y, w, h, d, p)
    local C = H.C
    local sf, mf = H.small(), H.medium()
    local lh = lineH(sf)
    local tx, ty, tw2, th2 = self:drawCard(x, y, w, h, dishName(d), famIcon(d))
    -- the start button sits at the bottom of the card
    local btnY = y + h - lh - 22
    self:scrolled("cookDetail", tx, ty, tw2, btnY - ty - 6, function(yy)
        local start = yy
        yy = yy + self:paragraphs(T("IGUI_GTPC_DishDesc_" .. d.id), tx, yy, tw2 - 10, C.textDim, sf) + 6
        -- base and level
        local lvl = p and p.level or 0
        status(self, T("IGUI_GTPC_NeedLevel", tostring(d.level or 0), tostring(lvl)), tx, yy, lvl >= (d.level or 0), sf); yy = yy + lh
        if p and p.base then
            local what = K.typeOf(p.base)
            status(self, T(p.fam.partial and "IGUI_GTPC_BaseStarted" or "IGUI_GTPC_BaseFound", itemName(what)), tx, yy, true, sf)
        else
            status(self, T("IGUI_GTPC_BaseNeed", T("IGUI_GTPC_Base_" .. (K.FAMILIES[d.family].base or "Pot"))), tx, yy, false, sf)
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
        end
        if p and p.trimmed then yy = yy + self:paragraphs(T("IGUI_GTPC_Trimmed", tostring(p.maxItems or "?")), tx, yy, tw2 - 10, C.warn, sf) + 2 end
        yy = yy + 6
        -- steps
        shadowText(self, T("IGUI_GTPC_Steps"), tx, yy, C.accent, 1, sf); yy = yy + lh + 2
        for i, pp in ipairs(p and p.procs or {}) do
            local icon = procIcon(pp.id)
            if icon then self:drawTextureScaled(icon, tx, yy, lh + 6, lh + 6, 1, 1, 1, 1) end
            local parts = { tostring(i) .. ". " .. procName(pp.id) }
            if (pp.proc.level or 0) > 0 then parts[#parts + 1] = T("IGUI_GTPC_LevelShort", tostring(pp.proc.level)) end
            for _, t in ipairs(pp.tools) do
                if t.item then
                    parts[#parts + 1] = K.call(t.item, "getDisplayName") .. (t.fallback and (" " .. T("IGUI_GTPC_Makeshift")) or "")
                else
                    parts[#parts + 1] = T("IGUI_GTPC_NoTool", T("IGUI_GTPC_Tool_" .. t.group))
                end
            end
            for _, hp in ipairs(pp.help) do
                if hp.item then parts[#parts + 1] = T("IGUI_GTPC_Helps", K.call(hp.item, "getDisplayName")) end
            end
            local line = table.concat(parts, "  -  ")
            shadowText(self, fit(line, tw2 - lh - 20, sf), tx + lh + 12, yy + 3, pp.ok and C.text or C.bad, 1, sf)
            yy = yy + lh + 8
        end
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

--[[
    HARMONIE - From Garden to Plate: the guide window's Cooking tab
    (GTP 1.1.0, owner 2026-11-19: vanilla's own menus, our minigames only
    prepare ingredients -- HARMONIE_Prep.lua has the rules).

    Three pages (chips at the top):
      prep   left: the foods at hand that can be prepared (and the ones
             already prepared, dimmed); right: the chosen food and its
             minigames (tools found, harder without them). Start = bring it
             into the inventory -> minigame -> a short timed action -> the
             server writes the score.
      evo    vanilla evolved recipes at hand (a pot with water, a pan, bread
             slices ...): the chosen one lists every ingredient vanilla
             accepts now with its score; Add = vanilla's own
             ISInventoryPaneContextMenu.onAddItemInEvoRecipe.
      craft  vanilla craftRecipes of category Cooking (89): Open = the
             game's crafting window on that recipe. Prepared ingredients
             carry their score into what it makes.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminGuide"
require "HARMONIEGardenToPlate/HARMONIE_CookGames"
require "HARMONIEGardenToPlate/HARMONIE_CookFX"
require "HARMONIEGardenToPlate/HARMONIE_Prep"
require "HARMONIEGardenToPlate/HARMONIE_CookCraftList"

local H = GTPGuide
local Win = GTPGuideWindow
local K = HARMONIE_GTP.Cook
local R = HARMONIE_GTP.Prep
local U = H.util
local T, shadowText, fit, inside, clickable, lineH, fh, tw, texture =
    U.T, U.shadowText, U.fit, U.inside, U.clickable, U.lineH, U.fh, U.tw, U.texture
local log = function(fmt, ...) R.log(fmt, ...) end

-- GTP 1.8.1: practice has its own page (owner: a Practice button on every
-- minigame row looked like the button that does it)
H.COOK_PAGES = { "prep", "evo", "craft", "practice" }
H.PREP_WATCHDOG_MS = 10000

-- GTP 1.4.0 (#15): this player's minigame record, kept on this computer
-- (Zomboid/Lua/HARMONIE_GTP_PrepStats.txt: "pid excellent good bad miss")
H.PREP_STATS_FILE = "HARMONIE_GTP_PrepStats.txt"
function H.prepStats()
    if H.prepStatsT then return H.prepStatsT end
    local t = {}
    H.prepStatsT = t
    if not getFileReader then return t end
    local ok, r = pcall(getFileReader, H.PREP_STATS_FILE, true)
    if not ok or not r then return t end
    pcall(function()
        local line = r:readLine()
        while line do
            local pid, a, b, c, d = line:match("^(%w+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")
            if pid then t[pid] = { Excellent = tonumber(a), Good = tonumber(b), Bad = tonumber(c), Miss = tonumber(d) } end
            line = r:readLine()
        end
    end)
    pcall(function() r:close() end)
    return t
end
function H.recordPrepStat(pid, word)
    local t = H.prepStats()
    local e = t[pid] or { Excellent = 0, Good = 0, Bad = 0, Miss = 0 }
    t[pid] = e
    if e[word] == nil then return end
    e[word] = e[word] + 1
    if not getFileWriter then return end
    local ok, w = pcall(getFileWriter, H.PREP_STATS_FILE, true, false)
    if not ok or not w then return end
    pcall(function()
        for k, v in pairs(t) do w:write(string.format("%s %d %d %d %d\n", k, v.Excellent, v.Good, v.Bad, v.Miss)) end
    end)
    pcall(function() w:close() end)
end
function H.prepStatLine(pid)
    local e = H.prepStats()[pid]
    if not e then return nil end
    local n = e.Excellent + e.Good + e.Bad + e.Miss
    if n == 0 then return nil end
    return T("IGUI_GTPP_StatLine", tostring(n), tostring(math.floor(e.Excellent * 100 / n + 0.5)))
end

local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end
local function itemName(it) return tostring(call(it, "getDisplayName") or call(it, "getName") or "?") end
local function procName(pid) return T("IGUI_GTPC_Proc_" .. tostring(pid)) end
local function procIcon(pid) return texture(U.UI_DIR .. "cook_" .. tostring(pid) .. ".png") end
local function wordName(w) return T("IGUI_GTPC_Word_" .. tostring(w)) end
local function wordCol(w)
    local C = H.C
    return ({ Excellent = C.good, Good = C.accent, Bad = C.warn, Miss = C.bad })[w] or C.text
end
local function scoreCol(s)
    local C = H.C
    s = tonumber(s) or 0
    if s >= 1.5 then return C.good elseif s >= 0.5 then return C.accent elseif s < 0 then return C.bad end
    return C.textDim
end

-- ------------------------------------------------------------------ widgets
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

-- a small "i" whose text shows on hover; returns the width it took
local function infoMark(self, x, y, s, text)
    local C = H.C
    self:drawRect(x, y, s, s, 0.9, C.accentDark[1], C.accentDark[2], C.accentDark[3])
    self:drawRectBorder(x, y, s, s, 1, C.accent[1], C.accent[2], C.accent[3])
    local sf = H.small()
    shadowText(self, "i", x + math.floor((s - tw(sf, "i")) / 2), y + math.floor((s - fh(sf)) / 2), C.accent, 1, sf)
    local mx, my = self:getMouseX(), self:getMouseY()
    if text and mx >= x - 2 and mx < x + s + 2 and my >= y - 2 and my < y + s + 2 then
        self.hoverTip = { text = text, x = x + s, y = y + s + 2 }
    end
    return s + 6
end

-- one item row in a list; returns the row rect
function Win:cookItemRow(x, y, w, rowH, it, l1, l2, col2, selected, boxKey)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local r = { x = x, y = y, w = w, h = rowH }
    local over = inside(r, self:getMouseX(), self:getMouseY()) and inside(self.scrollBox and self.scrollBox[boxKey], self:getMouseX(), self:getMouseY())
    -- GTP 1.5.0 (#19): the game's own item tooltip for the row under the mouse
    if over and it then self.cookHoverItem = it end
    self:drawRect(r.x, r.y, r.w, r.h, selected and 0.95 or (over and 0.8 or 0.55), C.card[1] + 0.02, C.card[2] + 0.04, C.card[3] + 0.02)
    local bc = selected and C.accent or (over and C.border or C.borderDim)
    self:drawRectBorder(r.x, r.y, r.w, r.h, 0.8, bc[1], bc[2], bc[3])
    local isz = rowH - 8
    local tex = call(it, "getTex") or call(it, "getTexture")
    self:drawRect(r.x + 5, r.y + 4, isz, isz, 0.45, 0, 0, 0)
    if tex then self:drawTextureScaled(tex, r.x + 5, r.y + 4, isz, isz, 1, 1, 1, 1) end
    local tx = r.x + 5 + isz + 8
    local maxW = r.x + r.w - 8 - tx
    local ty = r.y + math.floor((rowH - lh * 2) / 2)
    shadowText(self, fit(l1, maxW, sf), tx, ty, C.text, 1, sf)
    shadowText(self, fit(l2 or "", maxW, sf), tx, ty + lh, col2 or C.textDim, 1, sf)
    return r
end

-- GTP 1.5.0 (#19): one vanilla ISToolTipInv for the window, shown while a
-- row's item is under the mouse (our score / vitamin boxes come with it)
require "ISUI/ISToolTipInv"
function Win:updateCookTip()
    local it = (self.tab == "cook" and not self.settingsOpen and self:getIsVisible()) and self.cookHoverItem or nil
    local tip = self.cookTip
    if not it then
        if tip and tip:getIsVisible() then tip:setVisible(false) end
        return
    end
    if not tip then
        local ok, t = pcall(function()
            local t2 = ISToolTipInv:new(it)
            t2:initialise()
            t2:addToUIManager()
            return t2
        end)
        if not ok then R.logOnce("tipfail", "item tooltip could not be made: %s", tostring(t)); return end
        tip = t
        self.cookTip = tip
    end
    pcall(function()
        tip:setItem(it)
        if tip.setCharacter then tip:setCharacter(self.player) end
        tip:setVisible(true)
        tip:setAlwaysOnTop(true)
        tip:bringToTop()
    end)
end
function Win:hideCookTip()
    if self.cookTip then pcall(function() self.cookTip:setVisible(false) end) end
end
if not Win.gtpCookTipWrapped then
    Win.gtpCookTipWrapped = true
    local origRender = Win.render
    function Win:render()
        self.cookHoverItem = nil
        origRender(self)
        local ok, err = pcall(self.updateCookTip, self)
        if not ok then R.logOnce("tipupd", "item tooltip update FAILED: %s", tostring(err)) end
    end
    -- the window can go away without H.close (hub, other mods): never leave the tooltip up
    if Events and Events.OnTick then
        local n = 0
        Events.OnTick.Add(function()
            n = n + 1
            if n % 20 ~= 0 then return end
            local w = H.window
            if w and w.cookTip and w.cookTip:getIsVisible() and not (H.isOpen and H.isOpen()) then w:hideCookTip() end
        end)
    end
    local origClose = H.close
    if origClose then
        H.close = function(...)
            if H.window then H.window:hideCookTip() end
            return origClose(...)
        end
    end
end

-- an item's score line
local function scoreLine(it)
    local d = R.dishOf(it)
    if d then return T("IGUI_GTPP_RowDish", string.format("%.2f", tonumber(d.avg) or 0), tostring(tonumber(d.n) or 0)), scoreCol(d.avg) end
    local p = R.prepOf(it)
    if p then return T("IGUI_GTPP_RowPrep", procName(p.p), wordName(p.w), R.isRotten(it) and T("IGUI_GTPP_RottenZero") or string.format("%+.1f", R.scoreOf(it))), wordCol(p.w) end
    return T("IGUI_GTPP_RowPlain"), H.C.textDim
end

-- ------------------------------------------------------------------ the tab
function Win:renderCook(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local page = self.cookPage
    if page ~= "prep" and page ~= "evo" and page ~= "craft" and page ~= "practice" then page = "prep"; self.cookPage = page end
    -- the run watchdog: the queue can drop our chain (vanilla clears it when
    -- one action turns invalid) -- never leave the tab stuck "in progress"
    local run = self.prepRun
    -- GTP 1.2.0: 10 s (was 25), and the panel has a Cancel button
    if run and run.phase ~= "game" and nowMs() - (run.at or 0) > H.PREP_WATCHDOG_MS then
        log("preparation of %s stopped without an answer (phase %s, %d s) -- the tab is free again", tostring(run.name), tostring(run.phase), H.PREP_WATCHDOG_MS / 1000)
        self.prepRun = nil
        self.prepLast = { name = run.name, pid = run.pid, why = "timeout" }
    end
    local bh = 0
    if H.banner then
        if self.prepRun then bh = H.banner(self, x, y, w, "IN_PROGRESS", "IGUI_GTPP_Next_run")
        else bh = H.banner(self, x, y, w, "INFO_ONLY", "IGUI_GTPP_Next_" .. page) end
    end
    y, h = y + bh, h - bh
    local items = {}
    for _, p in ipairs(H.COOK_PAGES) do
        items[#items + 1] = { label = T("IGUI_GTPP_Page_" .. p), on = page == p, action = function(win)
            win.cookPage = p
            log("cooking tab page: %s", p)
        end }
    end
    local used = self:cookChips(items, x, y, w - 30)
    -- the dish buff on this character now
    local buff = K.myBuffNow and K.myBuffNow(self.player)
    local helpKey = "IGUI_GTPP_Help_" .. page
    infoMark(self, x + w - 22, y + 2, lineH(sf) + 2, T(helpKey))
    y, h = y + used + 4, h - used - 4
    if buff then
        local line = T("IGUI_GTPP_BuffNow", T("IGUI_GTPC_Buff_" .. tostring(buff.kind)), tostring(buff.tier or 1), string.format("%.1f", buff.hoursLeft))
        shadowText(self, fit(line, w, sf), x, y, C.good, 1, sf)
        y, h = y + lineH(sf) + 4, h - lineH(sf) - 4
    end
    if page == "prep" then return self:renderCookPrep(x, y, w, h) end
    if page == "evo" then return self:renderCookEvo(x, y, w, h) end
    if page == "practice" then return self:renderCookPractice(x, y, w, h) end
    return self:renderCookCraft(x, y, w, h)
end

-- ------------------------------------------------------------------ prepare
-- GTP 1.5.0 (#10): ONE walk over what is at hand, shared by the pages. A
-- cheap signature (how many items each container holds) is checked every
-- 500 ms; the full walk runs only when it changed, or every 5 s.
H.SCAN_SIG_MS, H.SCAN_MAX_MS = 500, 5000
H.SCAN_FOOD_MAX = 3000
-- the BaseItem and ResultItem of every vanilla evolved recipe (from
-- evolvedrecipes_index.txt): what can start or continue a dish
H.EVO_BASE = { ["Base.BagelPlain"] = true, ["Base.BagelPoppy"] = true, ["Base.BagelSesame"] = true, ["Base.Baguette"] = true, ["Base.BaguetteSandwich"] = true, ["Base.BakingTray_Muffin"] = true, ["Base.BakingTray_Muffin_Recipe"] = true, ["Base.Bowl"] = true, ["Base.BreadDough"] = true, ["Base.BreadSlices"] = true, ["Base.Bucket"] = true, ["Base.BucketEmpty"] = true, ["Base.BucketOfSoup"] = true, ["Base.BucketOfStew"] = true, ["Base.BunsHamburger_single"] = true, ["Base.Burger"] = true, ["Base.BurgerRecipe"] = true, ["Base.Burrito"] = true, ["Base.BurritoRecipe"] = true, ["Base.CakePrep"] = true, ["Base.CakeRaw"] = true, ["Base.CeramicTeacup"] = true, ["Base.Chum"] = true, ["Base.ClayBowl"] = true, ["Base.ClayMug"] = true, ["Base.ConeIcecream"] = true, ["Base.ConeIcecreamToppings"] = true, ["Base.CopperCup"] = true, ["Base.FruitSalad"] = true, ["Base.FruitSaladClay"] = true, ["Base.GlassTumbler"] = true, ["Base.GoldCup"] = true, ["Base.GriddlePanFriedVegetables"] = true, ["Base.GridlePan"] = true, ["Base.HotDrink"] = true, ["Base.HotDrinkClay"] = true, ["Base.HotDrinkCopper"] = true, ["Base.HotDrinkGold"] = true, ["Base.HotDrinkMetal"] = true, ["Base.HotDrinkSilver"] = true, ["Base.HotDrinkSpiffo"] = true, ["Base.HotDrinkTea"] = true, ["Base.HotDrinkTeaCeramic"] = true, ["Base.HotDrinkTumbler"] = true, ["Base.HotDrinkWhite"] = true, ["Base.Hotdog"] = true, ["Base.MetalCup"] = true, ["Base.MugSpiffo"] = true, ["Base.MugWhite"] = true, ["Base.Mugl"] = true, ["Base.Oatmeal"] = true, ["Base.OmeletteRecipe"] = true, ["Base.OmeletteRecipeForged"] = true, ["Base.Pan"] = true, ["Base.PanForged"] = true, ["Base.PanFriedVegetables"] = true, ["Base.PanFriedVegetables2"] = true, ["Base.PanFriedVegetablesForged"] = true, ["Base.Pancakes"] = true, ["Base.PancakesRecipe"] = true, ["Base.PastaPan"] = true, ["Base.PastaPanCopper"] = true, ["Base.PastaPot"] = true, ["Base.PastaPotForged"] = true, ["Base.PiePrep"] = true, ["Base.PieWholeRaw"] = true, ["Base.PieWholeRawSweet"] = true, ["Base.PizzaRecipe"] = true, ["Base.PizzaWhole"] = true, ["Base.Pot"] = true, ["Base.PotForged"] = true, ["Base.PotForgedSoupRecipe"] = true, ["Base.PotForgedStew"] = true, ["Base.PotOfSoup"] = true, ["Base.PotOfSoupRecipe"] = true, ["Base.PotOfStew"] = true, ["Base.RicePan"] = true, ["Base.RicePanCopper"] = true, ["Base.RicePot"] = true, ["Base.RicePotForged"] = true, ["Base.RoastingPan"] = true, ["Base.Salad"] = true, ["Base.SaladClay"] = true, ["Base.Sandwich"] = true, ["Base.SilverCup"] = true, ["Base.Taco"] = true, ["Base.TacoRecipe"] = true, ["Base.TacoShell"] = true, ["Base.Teacup"] = true, ["Base.Toast"] = true, ["Base.Tortilla"] = true, ["Base.Waffles"] = true, ["Base.WafflesRecipe"] = true, ["Base.WaterPotForgedPasta"] = true, ["Base.WaterPotForgedRice"] = true, ["Base.WaterPotPasta"] = true, ["Base.WaterPotRice"] = true, ["Base.WaterSaucepanPasta"] = true, ["Base.WaterSaucepanPastaCopper"] = true, ["Base.WaterSaucepanRice"] = true, ["Base.WaterSaucepanRiceCopper"] = true }
local function containerSig(containers)
    local parts, n = {}, containers and containers.size and containers:size() or 0
    for i = 0, n - 1 do
        local c = containers:get(i)
        local items = call(c, "getItems")
        parts[#parts + 1] = tostring(items and items.size and items:size() or 0)
    end
    return n .. ":" .. table.concat(parts, ",")
end
function Win:cookScan(force)
    local t = nowMs()
    local sc = self.cookScanData
    if sc and not force and t - sc.checked < H.SCAN_SIG_MS then return sc end
    local containers = K.containers(self.player)
    local sig = containerSig(containers)
    if sc and not force and sig == sc.sig and t - sc.at < H.SCAN_MAX_MS then sc.checked = t; return sc end
    local t0 = t
    sc = { at = t, checked = t, sig = sig, containers = containers, items = {}, gen = (sc and sc.gen or 0) + 1 }
    -- GTP 1.8.5 (owner: "meat is not found any more, even right next to
    -- me"): the walk stopped after the first 800 items of ANY kind, so in a
    -- full base the food further down the list (a fridge after the shelves)
    -- was never seen. Now only what the pages use is kept -- every food (up
    -- to H.SCAN_FOOD_MAX) and the vanilla evolved-recipe base items (pots,
    -- buckets, bread...) -- and the walk goes on to the end.
    local n, nFood = 0, 0
    K.eachItem(containers, function(it)
        n = n + 1
        if R.isFood(it) then
            nFood = nFood + 1
            if nFood <= H.SCAN_FOOD_MAX then sc.items[#sc.items + 1] = it end
        elseif H.EVO_BASE[tostring(call(it, "getFullType"))] then
            sc.items[#sc.items + 1] = it
        end
    end)
    if nFood > H.SCAN_FOOD_MAX then
        R.logOnce("scancap", "Cooking tab scan: %d foods at hand, only the first %d listed", nFood, H.SCAN_FOOD_MAX)
    end
    local took = nowMs() - t0
    if took > 15 then R.logOnce("scanslow:" .. tostring(math.floor(took / 10)), "Cooking tab scan: %d items took %d ms", #sc.items, took) end
    self.cookScanData = sc
    return sc
end

-- the foods to prepare, grouped by type (#17): { key, items = {...}, name, done }
function Win:prepList()
    local sc = self:cookScan()
    if self.prepCache and self.prepCache.gen == sc.gen and not self.prepDirty then return self.prepCache end
    self.prepDirty = nil
    local list = { gen = sc.gen, open = {}, done = {}, groups = {} }
    local byKey = {}
    for _, it in ipairs(sc.items) do
        if R.isFood(it) then
            local why = R.whyNot(it)
            if why == nil then
                list.open[#list.open + 1] = it
                local key = tostring(call(it, "getFullType"))
                local g = byKey[key]
                if not g then g = { key = key, items = {}, name = itemName(it) }; byKey[key] = g; list.groups[#list.groups + 1] = g end
                g.items[#g.items + 1] = it
            elseif why == "done" or why == "dish" then
                list.done[#list.done + 1] = it
            end
        end
    end
    -- the carried ones first in each group (no walk needed)
    for _, g in ipairs(list.groups) do
        table.sort(g.items, function(a, b)
            local ca = HARMONIE_Reach and HARMONIE_Reach.isCarried(self.player, a) or false
            local cb = HARMONIE_Reach and HARMONIE_Reach.isCarried(self.player, b) or false
            if ca ~= cb then return ca end
            return (call(a, "getID") or 0) < (call(b, "getID") or 0)
        end)
    end
    table.sort(list.groups, function(a, b) return a.name < b.name end)
    table.sort(list.done, function(a, b) return itemName(a) < itemName(b) end)
    self.prepCache = list
    return list
end

function Win:renderCookPrep(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local leftW = math.floor(w * 0.45)
    local list = self:prepList()
    local q = self:query()
    local groups, done = {}, {}
    for _, g in ipairs(list.groups) do if q == "" or g.name:lower():find(q, 1, true) then groups[#groups + 1] = g end end
    for _, it in ipairs(list.done) do if q == "" or itemName(it):lower():find(q, 1, true) then done[#done + 1] = it end end
    local cx, cy, cw, ch = self:drawCard(x, y, leftW, h, T("IGUI_GTPP_Card_Foods", tostring(#list.open)), texture(U.UI_DIR .. "tab_cook.png"))
    local used = self:placeSearch(cx, cy, cw - 4, true)
    cy, ch = cy + used + 6, ch - used - 6
    local rowH = math.max(40, lh * 2 + 10)
    local selKey = self.prepSelKey
    local selItem = self.prepSel
    local boxTop, boxBottom = cy, cy + ch
    self:scrolled("prepList", cx, cy, cw, ch, function(yy)
        local start = yy
        for _, g in ipairs(groups) do
            local it = g.items[1]
            local names = {}
            for j, pid in ipairs(R.gamesFor(it)) do if j <= 3 then names[#names + 1] = procName(pid) end end
            local l2 = T("IGUI_GTPP_RowCan", table.concat(names, ", "))
            if not (HARMONIE_Reach and HARMONIE_Reach.isCarried(self.player, it)) then l2 = l2 .. "  " .. T("IGUI_GTPP_InBox") end
            local l1 = #g.items > 1 and T("IGUI_GTPP_RowCount", g.name, tostring(#g.items)) or g.name
            local r = self:cookItemRow(cx, yy, cw - 10, rowH, it, l1, l2, C.textDim, selKey == g.key and not self.prepRedoSel, "prepList")
            r.action = function(win)
                win.prepSelKey = g.key
                win.prepSel = nil
                win.prepRedoSel = nil
                win.scroll.prepGames = 0
                log("prepare: chose %s (%d at hand)", g.name, #g.items)
            end
            if r.y + r.h > boxTop and r.y < boxBottom then clickable(self, r) end
            yy = yy + rowH + 4
        end
        if #done > 0 then
            shadowText(self, T("IGUI_GTPP_AlreadyDone"), cx, yy + 2, C.accent, 1, sf)
            yy = yy + lh + 6
        end
        for _, it in ipairs(done) do
            local l2, c2 = scoreLine(it)
            local redo = R.canRedo(it)
            if redo then l2 = l2 .. "  " .. T("IGUI_GTPP_CanRedo") end
            local r = self:cookItemRow(cx, yy, cw - 10, rowH, it, itemName(it), l2, c2, self.prepRedoSel and selItem == it, "prepList")
            -- GTP 1.4.0 (#14): a Poor / Missed one can be chosen to wash it off once
            if redo then
                r.action = function(win)
                    win.prepSel = it
                    win.prepRedoSel = true
                    win.prepSelKey = nil
                    log("prepare: chose %s to wash off", itemName(it))
                end
                if r.y + r.h > boxTop and r.y < boxBottom then clickable(self, r) end
            end
            yy = yy + rowH + 4
        end
        if #groups == 0 and #done == 0 then
            shadowText(self, T("IGUI_GTPP_NoFoods"), cx, yy, C.textDim, 1, sf)
            yy = yy + lh
        end
        return yy - start
    end)
    local rx, rw = x + leftW + 8, w - leftW - 8
    self:renderCookPrepDetail(rx, y, rw, h, list)
end

function Win:renderCookPrepDetail(x, y, w, h, list)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    -- what is chosen: a group of the same food (#17), or one food to wash off
    local group, it
    if self.prepRedoSel then
        it = self.prepSel
        if it and not R.canRedo(it) and not self.prepRun then self.prepSel = nil; self.prepRedoSel = nil; it = nil end
    elseif self.prepSelKey then
        for _, g in ipairs(list.groups) do if g.key == self.prepSelKey then group = g break end end
        if not group and not self.prepRun then self.prepSelKey = nil end
        it = group and group.items[1]
    end
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, T("IGUI_GTPP_Card_Prepare"))
    if self.prepRun then
        local run = self.prepRun
        shadowText(self, fit(T("IGUI_GTPP_Running", run.name, procName(run.pid)), cw - 8, sf), cx, cy, C.warn, 1, sf)
        cy = cy + lh + 6
        shadowText(self, fit(T("IGUI_GTPP_Phase_" .. tostring(run.phase)), cw - 8, sf), cx, cy, C.textDim, 1, sf)
        cy = cy + lh + 6
        if run.chainLeft and run.chainLeft > 0 then
            shadowText(self, fit(T("IGUI_GTPP_ChainLeft", tostring(run.chainLeft)), cw - 8, sf), cx, cy, C.accent, 1, sf)
            cy = cy + lh + 6
        end
        cy = cy + 4
        if run.phase ~= "game" then
            self:cookButton(cx, cy, T("IGUI_GTPP_Cancel"), true, function(win)
                log("preparation of %s cancelled by the player (phase %s)", tostring(run.name), tostring(run.phase))
                if run.phase == "bring" or run.phase == "action" then
                    pcall(ISTimedActionQueue.clear, win.player)
                end
                win.prepRun = nil
                win.prepDirty = true
                win.prepLast = { name = run.name, pid = run.pid, why = "cancelled" }
            end)
        end
        return
    end
    if self.prepLast then
        local L = self.prepLast
        local col = L.word and wordCol(L.word) or C.bad
        local line
        if L.redone then line = T("IGUI_GTPP_LastRedone", L.name); col = C.accent
        elseif L.practice then line = L.word and T("IGUI_GTPP_LastPractice", procName(L.pid), wordName(L.word)) or T("IGUI_GTPP_LastPracticeCancel")
        elseif L.word then line = T("IGUI_GTPP_LastDone", L.name, procName(L.pid), wordName(L.word), string.format("%+.1f", R.wordScore(L.word)))
        else line = T("IGUI_GTPP_LastRefused", L.name, T("IGUI_GTPP_Why_" .. tostring(L.why))) end
        cy = cy + self:paragraphs(line, cx, cy, cw - 8, col, sf) + 6
    end
    if not it then
        self:paragraphs(T("IGUI_GTPP_PickFood"), cx, cy, cw - 8, C.textDim, sf)
        return
    end
    -- the food
    local mf = H.medium and H.medium() or sf
    local isz = lh * 2 + 6
    local tex = call(it, "getTex") or call(it, "getTexture")
    self:drawRect(cx, cy, isz, isz, 0.45, 0, 0, 0)
    if tex then self:drawTextureScaled(tex, cx, cy, isz, isz, 1, 1, 1, 1) end
    local title = itemName(it)
    if group and #group.items > 1 then title = T("IGUI_GTPP_RowCount", title, tostring(#group.items)) end
    shadowText(self, fit(title, cw - isz - 16, mf), cx + isz + 8, cy, C.text, 1, mf)
    local games, kind = R.gamesFor(it)
    shadowText(self, fit(T("IGUI_GTPP_Kind_" .. tostring(kind)), cw - isz - 16, sf), cx + isz + 8, cy + lh + 4, C.textDim, 1, sf)
    if inside({ x = cx, y = cy, w = isz, h = isz }, self:getMouseX(), self:getMouseY()) then self.cookHoverItem = it end
    cy = cy + isz + 10
    if self.prepRedoSel then
        local l2, c2 = scoreLine(it)
        shadowText(self, fit(l2, cw - 8, sf), cx, cy, c2, 1, sf)
        cy = cy + lh + 6
        cy = cy + self:paragraphs(T("IGUI_GTPP_RedoHint"), cx, cy, cw - 8, C.textDim, sf) + 8
        self:cookButton(cx, cy, T("IGUI_GTPP_Redo"), true, function(win) win:startRedo(it) end)
        return
    end
    -- #17: do the same minigame on every one of this food, one after another
    if group and #group.items > 1 then
        local on = self.prepChain == true
        local label = T("IGUI_GTPP_ChainAll", tostring(#group.items))
        local r = { x = cx, y = cy, w = tw(sf, label) + 30, h = lh + 6 }
        local bs = lh - 2
        self:drawRectBorder(r.x + 2, r.y + 3, bs, bs, 1, C.accent[1], C.accent[2], C.accent[3])
        if on then self:drawRect(r.x + 5, r.y + 6, bs - 6, bs - 6, 1, C.accent[1], C.accent[2], C.accent[3]) end
        shadowText(self, label, r.x + bs + 10, r.y + 3, on and C.text or C.textDim, 1, sf)
        r.action = function(win) win.prepChain = not win.prepChain; log("prepare: repeat for all %s", tostring(win.prepChain)) end
        clickable(self, r)
        cy = cy + lh + 10
    end
    shadowText(self, T("IGUI_GTPP_ChooseGame"), cx, cy, C.accent, 1, sf)
    cy = cy + lh + 4
    -- #18: the minigames scroll when they do not fit
    local scan = K.scan(self.player)
    local rowH = lh * 2 + 12
    local boxTop, boxBottom = cy, y + h - 6
    local pl = T("IGUI_GTPP_StartGame")
    local pw = tw(sf, pl) + 20
    self:scrolled("prepGames", cx, cy, cw, boxBottom - cy, function(yy)
        local start = yy
        for _, pid in ipairs(games) do
            local proc = K.PROCS[pid]
            local toolItem, grade, tgroup = nil, "best", proc.tools and proc.tools[1]
            if tgroup then toolItem, grade = K.findTool(scan, tgroup) end
            local can = (not tgroup) or toolItem ~= nil or grade == "bare"
            local heatOk = not proc.heat or (scan and scan.heat ~= nil)
            local r = { x = cx, y = yy, w = cw - 14, h = rowH }
            local visible = r.y + r.h > boxTop and r.y < boxBottom
            local over = visible and inside(r, self:getMouseX(), self:getMouseY())
            local okAll = can and heatOk
            self:drawRect(r.x, r.y, r.w, r.h, okAll and (over and 0.95 or 0.75) or 0.35, C.accentDark[1], C.accentDark[2], C.accentDark[3])
            local bc = okAll and C.border or C.borderDim
            self:drawRectBorder(r.x, r.y, r.w, r.h, 0.8, bc[1], bc[2], bc[3])
            local ps = rowH - 8
            local pic = procIcon(pid)
            if pic then self:drawTextureScaled(pic, r.x + 4, r.y + 4, ps, ps, okAll and 1 or 0.4, 1, 1, 1) end
            local tx = r.x + ps + 12
            shadowText(self, fit(procName(pid), r.w - ps - 30 - pw, sf), tx, r.y + 4, okAll and C.text or C.textDim, 1, sf)
            local sub
            if not heatOk then sub = T("IGUI_GTPP_NeedHeat")
            elseif not tgroup then sub = T("IGUI_GTPP_NoTool")
            elseif toolItem then sub = T("IGUI_GTPP_Tool_" .. tostring(grade), itemName(toolItem))
            elseif grade == "bare" then sub = T("IGUI_GTPP_Tool_bare")
            else sub = T("IGUI_GTPP_NeedTool", T("IGUI_GTPC_Tool_" .. tostring(tgroup))) end
            local stat = H.prepStatLine(pid)
            if stat then sub = sub .. "  ·  " .. stat end
            shadowText(self, fit(sub, r.w - ps - 30 - pw, sf), tx, r.y + 4 + lh, okAll and C.textDim or C.bad, 1, sf)
            if okAll and visible then
                -- GTP 1.8.1: the row and its "Start" button both start the real one
                local function go(win)
                    local chain = (win.prepChain and group and #group.items > 1) and group.key or nil
                    win:startPrep(it, pid, toolItem, grade, tgroup, chain)
                end
                self:cookButton(r.x + r.w - pw - 6, r.y + math.floor((rowH - (lh + 12)) / 2), pl, true, go, pw)
                r.action = go
                clickable(self, r)
            end
            yy = yy + rowH + 4
        end
        return yy - start
    end)
end

-- GTP 1.8.1: practice page -- every minigame any food can take, each with
-- its tool line, the player's record and a Practice button (no food used,
-- nothing scored or sent)
function H.practiceGames()
    if H.practiceList then return H.practiceList end
    local used = {}
    for _, list in pairs(R.KIND_GAMES or {}) do for _, g in ipairs(list) do used[g] = true end end
    for _, rule in ipairs(R.GAME_RULES or {}) do for _, g in ipairs(rule.games or {}) do used[g] = true end end
    local out = {}
    for _, pid in ipairs(K.PROC_ORDER or {}) do if used[pid] and K.PROCS[pid] then out[#out + 1] = pid end end
    H.practiceList = out
    log("practice page: %d minigames", #out)
    return out
end

function Win:renderCookPractice(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, T("IGUI_GTPP_Card_Practice"))
    cy = cy + self:paragraphs(T("IGUI_GTPP_PracticeIntro"), cx, cy, cw - 8, C.textDim, sf) + 6
    if self.prepLast and self.prepLast.practice then
        local L = self.prepLast
        local line = L.word and T("IGUI_GTPP_LastPractice", procName(L.pid), wordName(L.word)) or T("IGUI_GTPP_LastPracticeCancel")
        shadowText(self, fit(line, cw - 8, sf), cx, cy, L.word and wordCol(L.word) or C.textDim, 1, sf)
        cy = cy + lh + 6
    end
    local scan = K.scan(self.player)
    local rowH = lh * 2 + 12
    local boxTop, boxBottom = cy, y + h - 6
    local pl = T("IGUI_GTPP_Practice")
    local pw = tw(sf, pl) + 20
    local busy = self.prepRun ~= nil
    self:scrolled("practiceGames", cx, cy, cw, boxBottom - cy, function(yy)
        local start = yy
        for _, pid in ipairs(H.practiceGames()) do
            local proc = K.PROCS[pid]
            local toolItem, grade, tgroup = nil, "best", proc.tools and proc.tools[1]
            if tgroup then toolItem, grade = K.findTool(scan, tgroup) end
            local can = (not tgroup) or toolItem ~= nil or grade == "bare"
            local r = { x = cx, y = yy, w = cw - 14, h = rowH }
            local visible = r.y + r.h > boxTop and r.y < boxBottom
            self:drawRect(r.x, r.y, r.w, r.h, can and 0.6 or 0.3, C.accentDark[1], C.accentDark[2], C.accentDark[3])
            local bc = can and C.border or C.borderDim
            self:drawRectBorder(r.x, r.y, r.w, r.h, 0.8, bc[1], bc[2], bc[3])
            local ps = rowH - 8
            local pic = procIcon(pid)
            if pic then self:drawTextureScaled(pic, r.x + 4, r.y + 4, ps, ps, can and 1 or 0.4, 1, 1, 1) end
            local tx = r.x + ps + 12
            shadowText(self, fit(procName(pid), r.w - ps - 30 - pw, sf), tx, r.y + 4, can and C.text or C.textDim, 1, sf)
            local sub
            if not tgroup then sub = T("IGUI_GTPP_NoTool")
            elseif toolItem then sub = T("IGUI_GTPP_Tool_" .. tostring(grade), itemName(toolItem))
            elseif grade == "bare" then sub = T("IGUI_GTPP_Tool_bare")
            else sub = T("IGUI_GTPP_NeedTool", T("IGUI_GTPC_Tool_" .. tostring(tgroup))) end
            local stat = H.prepStatLine(pid)
            if stat then sub = sub .. "  ·  " .. stat end
            shadowText(self, fit(sub, r.w - ps - 30 - pw, sf), tx, r.y + 4 + lh, can and C.textDim or C.bad, 1, sf)
            if visible then
                self:cookButton(r.x + r.w - pw - 6, r.y + math.floor((rowH - (lh + 12)) / 2), pl, can and not busy,
                    function(win) win:startPractice(pid, toolItem, grade, tgroup) end, pw)
            end
            yy = yy + rowH + 4
        end
        return yy - start
    end)
end

-- Start: bring it into the inventory -> minigame -> timed action -> server
function Win:startPrep(item, pid, toolItem, grade, group, chainKey)
    if self.prepRun then return end
    local player = self.player
    local Gm = HARMONIE_GTP.CookGames
    if Gm and Gm.busy and Gm.busy() then log("prepare: a minigame is already open"); return end
    local run = { item = item, pid = pid, name = itemName(item), phase = "bring", at = nowMs(), chainKey = chainKey,
        tool = { toolItem, grade, group } }
    if chainKey then
        for _, g in ipairs(self:prepList().groups) do if g.key == chainKey then run.chainLeft = #g.items - 1 end end
    end
    self.prepRun = run
    self.prepLast = nil
    local win = self
    local function finish(word, why)
        if win.prepRun ~= run then return end
        win.prepRun = nil
        win.prepDirty = true
        win.prepLast = { name = run.name, pid = pid, word = word, why = why }
        if word and chainKey then win:continueChain(run) end
    end
    local function play()
        if win.prepRun ~= run then return end
        if not (HARMONIE_Reach and HARMONIE_Reach.isCarried(player, item)) then
            -- GTP 1.2.0: say why -- usually a full inventory
            local inv = call(player, "getInventory")
            local full = inv and inv.hasRoomFor and call(inv, "hasRoomFor", player, item) == false
            log("prepare: %s did not reach the inventory (%s) -- stopped", run.name, full and "inventory full" or "not moved")
            finish(nil, full and "full" or "notCarried")
            return
        end
        local function onWord(word)
            if win.prepRun ~= run then return end
            if not word then log("prepare: minigame for %s cancelled", run.name); finish(nil, "cancelled"); return end
            if K.minigamesOn() then H.recordPrepStat(pid, word) end
            -- GTP 1.8.2 (owner: "anything of ours that makes cooking longer
            -- than vanilla -- take it out"): no extra 3-6 s timed action after
            -- the minigame any more; the result goes to the server at once
            run.word = word
            run.phase, run.at = "server", nowMs()
            R.request(player, item, pid, word)
            if not (isClient and isClient()) then
                local pr = R.prepOf(item)
                finish(pr and pr.w or word)
            end
        end
        run.phase, run.at = "game", nowMs()
        -- GTP 1.2.0: the server notes when the minigame began (anti-cheat)
        R.begin(player, item, pid)
        if K.minigamesOn() and Gm and Gm.play then
            local pp = { proc = K.PROCS[pid], tools = group and { { grade = grade, item = toolItem, group = group } } or {}, help = {} }
            -- GTP 1.4.0 (#16): the food itself makes it harder or easier
            local hard = R.hardness(item)
            local diff = math.max(0.05, math.min(1, K.difficulty(player, pp, nil) + hard))
            local ease = K.levelEase(K.level(player))
            local proc = K.PROCS[pid]
            local itemTex = call(item, "getTexture")
            local toolTex = toolItem and call(toolItem, "getTexture") or nil
            log("prepare %s with %s: difficulty %.2f (food %+.2f), tool %s (%s)", run.name, pid, diff, hard, toolItem and K.typeOf(toolItem) or "none", tostring(grade))
            local ok = Gm.play(player, pid, { difficulty = diff, slipMul = ease.slip, timeMul = ease.time * K.minigameTime(), icon = itemTex,
                tool = toolTex, cursor = (proc.cursor == "tool") and toolTex or itemTex, bare = grade == "bare",
                toolIsGrater = not (group == "grater" and grade ~= "best") }, onWord)
            if not ok then log("prepare: the minigame could not open"); finish(nil, "busy") end
        else
            onWord("Good")
        end
    end
    if HARMONIE_Reach and HARMONIE_Reach.isCarried(player, item) then
        play()
    else
        log("prepare: bringing %s into the inventory first", run.name)
        if HARMONIE_Reach and HARMONIE_Reach.bring then HARMONIE_Reach.bring(player, item)
        elseif ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then ISInventoryPaneContextMenu.transferIfNeeded(player, item) end
        ISTimedActionQueue.add(HARMONIE_GTP_CookWaitAction:new(player, 5, function() play() end))
    end
end

-- GTP 1.5.0 (#17): after one food of a group is done, the next one of the
-- same type gets the same minigame (stops on a cancel, a refusal or the end)
function Win:continueChain(run)
    if not run.chainKey or not self:getIsVisible() then return end
    for _, g in ipairs(self:prepList().groups) do
        if g.key == run.chainKey then
            local nextItem = g.items[1]
            if nextItem and nextItem ~= run.item then
                log("prepare: repeat -- next %s (%d left)", itemName(nextItem), #g.items)
                self:startPrep(nextItem, run.pid, run.tool[1], run.tool[2], run.tool[3], run.chainKey)
            end
            return
        end
    end
    log("prepare: repeat finished -- no more %s", tostring(run.name))
end

-- GTP 1.4.0 (#15): practice -- the same minigame with no food, no score,
-- no XP, nothing sent to the server, not counted in the record
function Win:startPractice(pid, toolItem, grade, group)
    local Gm = HARMONIE_GTP.CookGames
    if self.prepRun or not (Gm and Gm.play) or (Gm.busy and Gm.busy()) then return end
    local player = self.player
    local pp = { proc = K.PROCS[pid], tools = group and { { grade = grade, item = toolItem, group = group } } or {}, help = {} }
    local diff = K.difficulty(player, pp, nil)
    local ease = K.levelEase(K.level(player))
    local toolTex = toolItem and call(toolItem, "getTexture") or nil
    local win = self
    log("practice minigame %s (difficulty %.2f)", pid, diff)
    Gm.play(player, pid, { difficulty = diff, slipMul = ease.slip, timeMul = ease.time * K.minigameTime(), tool = toolTex,
        cursor = toolTex, bare = grade == "bare", toolIsGrater = not (group == "grater" and grade ~= "best") }, function(word)
        win.prepLast = { practice = true, pid = pid, word = word, name = T("IGUI_GTPP_PracticeName") }
        log("practice minigame %s: %s", pid, tostring(word))
    end)
end

-- GTP 1.4.0 (#14): wash off a Poor / Missed preparation (once per food)
function Win:startRedo(item)
    if self.prepRun then return end
    local player = self.player
    local run = { item = item, pid = "wash", name = itemName(item), phase = "action", at = nowMs(), redo = true }
    self.prepRun = run
    self.prepLast = nil
    local win = self
    -- GTP 1.8.2: no 3 s wash action any more (owner: nothing of ours may add
    -- time) -- asked at once, or right after the item reaches the inventory
    local function ask()
        if win.prepRun ~= run then return end
        run.phase, run.at = "server", nowMs()
        log("prepare: washing off the preparation of %s", run.name)
        R.requestRedo(player, item)
    end
    if HARMONIE_Reach and HARMONIE_Reach.isCarried(player, item) then
        ask()
    else
        if HARMONIE_Reach and HARMONIE_Reach.bring then HARMONIE_Reach.bring(player, item) end
        ISTimedActionQueue.add(HARMONIE_GTP_CookWaitAction:new(player, 5, ask))
    end
end

-- the server's answer (MP): the tab shows it
R.onSet = function(args, item)
    local win = GTPGuide and GTPGuide.window
    if not win or not win.prepRun then return end
    if args.what == "redo" and win.prepRun.redo and call(win.prepRun.item, "getID") == args.id then
        local run = win.prepRun
        win.prepRun = nil
        win.prepDirty = true
        win.prepLast = { name = run.name, redone = true }
        win.prepSel = nil
        win.prepRedoSel = nil
        win.prepSelKey = tostring(call(run.item, "getFullType"))
        return
    end
    if args.what ~= "prep" then return end
    local run = win.prepRun
    if call(run.item, "getID") == args.id then
        win.prepRun = nil
        win.prepDirty = true
        win.prepLast = { name = run.name, pid = run.pid, word = args.prep and args.prep.w or run.word }
        if run.chainKey then win:continueChain(run) end
    end
end
R.onRefused = function(args)
    local win = GTPGuide and GTPGuide.window
    if not win then return end
    local run = win.prepRun
    win.prepRun = nil
    win.prepDirty = true
    win.prepLast = { name = run and run.name or "?", pid = run and run.pid, why = args.why }
end

-- ------------------------------------------------------------------ vanilla evolved recipes
-- every evolved recipe that something at hand can start or continue, from
-- the shared scan (#10). A dish already started is its own row; fresh bases
-- of the same dish (pot, bucket, forged pot...) are ONE row (#22).
function Win:evoList()
    local sc = self:cookScan()
    if self.evoCache and self.evoCache.gen == sc.gen and not self.evoDirty then return self.evoCache end
    self.evoDirty = nil
    local list = { gen = sc.gen, entries = {}, containers = sc.containers }
    local fresh, seen = {}, {}
    if RecipeManager and RecipeManager.getEvolvedRecipe then
        for _, it in ipairs(sc.items) do
            -- 1.8.5: only a recipe's base item (or a dish already started) can
            -- start / continue one -- not every food of the (now longer) scan
            local can = H.EVO_BASE[tostring(call(it, "getFullType"))] or R.dishOf(it) ~= nil
            local ok, recipes = false, nil
            if can then ok, recipes = pcall(RecipeManager.getEvolvedRecipe, it, self.player, sc.containers, false) end
            if ok and recipes and recipes.size then
                for i = 0, recipes:size() - 1 do
                    local r = recipes:get(i)
                    local name = T("ContextMenu_EvolvedRecipe_" .. tostring(call(r, "getUntranslatedName")))
                    local started = call(r, "isResultItem", it) == true or R.dishOf(it) ~= nil
                    if started then
                        local key = "s:" .. tostring(call(it, "getID")) .. ":" .. tostring(call(r, "getName"))
                        if not seen[key] then
                            seen[key] = true
                            list.entries[#list.entries + 1] = { key = key, name = name, started = true, options = { { recipe = r, base = it } } }
                        end
                    else
                        local okey = tostring(call(r, "getName")) .. "|" .. tostring(call(it, "getFullType"))
                        if not seen[okey] then
                            seen[okey] = true
                            local g = fresh[name]
                            if not g then
                                g = { key = "f:" .. name, name = name, started = false, options = {} }
                                fresh[name] = g
                                list.entries[#list.entries + 1] = g
                            end
                            g.options[#g.options + 1] = { recipe = r, base = it }
                        end
                    end
                end
            end
        end
    else
        R.logOnce("noRM", "RecipeManager.getEvolvedRecipe missing -- no vanilla evolved recipes listed")
    end
    -- GTP 1.8.1 (owner): a cooking pot first for soup / stew (vanilla also
    -- allows a bucket, last); then a base the player carries
    local function baseRank(it)
        local t = tostring(call(it, "getFullType") or "")
        if t:find("Bucket", 1, true) then return 3 end
        if t:find("Pot", 1, true) then return t:find("Forged", 1, true) and 1 or 0 end
        return 2
    end
    for _, e in ipairs(list.entries) do
        table.sort(e.options, function(a, b)
            local ra, rb = baseRank(a.base), baseRank(b.base)
            if ra ~= rb then return ra < rb end
            local ca = HARMONIE_Reach and HARMONIE_Reach.isCarried(self.player, a.base) or false
            local cb = HARMONIE_Reach and HARMONIE_Reach.isCarried(self.player, b.base) or false
            if ca ~= cb then return ca end
            return itemName(a.base) < itemName(b.base)
        end)
    end
    table.sort(list.entries, function(a, b)
        if a.started ~= b.started then return a.started end
        return a.name < b.name
    end)
    self.evoCache = list
    return list
end

function Win:renderCookEvo(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local leftW = math.floor(w * 0.42)
    local list = self:evoList()
    local q = self:query()
    local shown = {}
    for _, e in ipairs(list.entries) do
        local hit = q == "" or e.name:lower():find(q, 1, true)
        if not hit then for _, o in ipairs(e.options) do if itemName(o.base):lower():find(q, 1, true) then hit = true break end end end
        if hit then shown[#shown + 1] = e end
    end
    local cx, cy, cw, ch = self:drawCard(x, y, leftW, h, T("IGUI_GTPP_Card_Evo", tostring(#list.entries)))
    local used = self:placeSearch(cx, cy, cw - 4, true)
    cy, ch = cy + used + 6, ch - used - 6
    local rowH = math.max(40, lh * 2 + 10)
    -- keep the choice across refreshes; a fresh base that just got its first
    -- ingredient becomes a started dish of the same name (the newest one)
    local cur
    for _, e in ipairs(list.entries) do if e.key == self.evoSelKey then cur = e break end end
    if not cur and self.evoFollow then
        local best
        for _, e in ipairs(list.entries) do
            if e.started and e.name == self.evoFollow then
                local id = call(e.options[1].base, "getID") or 0
                if not best or id > (call(best.options[1].base, "getID") or 0) then best = e end
            end
        end
        if best then cur = best; self.evoSelKey = best.key; self.evoFollow = nil end
    end
    local boxTop, boxBottom = cy, cy + ch
    self:scrolled("evoList", cx, cy, cw, ch, function(yy)
        local start = yy
        for _, e in ipairs(shown) do
            local base = e.options[1].base
            local l2, c2 = itemName(base), C.textDim
            if #e.options > 1 then l2 = T("IGUI_GTPP_EvoBases", tostring(#e.options)) end
            local d = R.dishOf(base)
            if d then l2 = l2 .. "  " .. T("IGUI_GTPP_RowDish", string.format("%.2f", tonumber(d.avg) or 0), tostring(tonumber(d.n) or 0)); c2 = scoreCol(d.avg) end
            local r = self:cookItemRow(cx, yy, cw - 10, rowH, base, e.name, l2, c2, cur == e, "evoList")
            r.action = function(win) win.evoSelKey = e.key; win.evoOpt = 1; win.scroll.evoIng = 0; log("vanilla dish: chose %s", e.name) end
            if r.y + r.h > boxTop and r.y < boxBottom then clickable(self, r) end
            yy = yy + rowH + 4
        end
        if #shown == 0 then
            yy = yy + self:paragraphs(T("IGUI_GTPP_NoEvo"), cx, yy, cw - 12, C.textDim, sf)
        end
        return yy - start
    end)
    self:renderCookEvoDetail(x + leftW + 8, y, w - leftW - 8, h, cur, list)
end

-- what the dish would score after adding `it` (#20)
-- GTP 1.7.0 (#41): favorite dishes -- the ingredient types of a dish made
-- before (vanilla keeps them on the dish: getExtraItems), on this computer
-- (Zomboid/Lua/HARMONIE_GTP_Favorites.txt: "dish name|Base.A,Base.B,...")
H.FAV_FILE, H.FAV_MAX = "HARMONIE_GTP_Favorites.txt", 30
function H.favorites()
    if H.favList then return H.favList end
    local list = {}
    H.favList = list
    if not getFileReader then return list end
    local ok, r = pcall(getFileReader, H.FAV_FILE, true)
    if not ok or not r then return list end
    pcall(function()
        local line = r:readLine()
        while line do
            local name, types = line:match("^(.-)|(.+)$")
            if name and types then
                local t = {}
                for ty in types:gmatch("[^,]+") do t[#t + 1] = ty end
                if #t > 0 then list[#list + 1] = { name = name, types = t } end
            end
            line = r:readLine()
        end
    end)
    pcall(function() r:close() end)
    return list
end
function H.saveFavorites()
    if not getFileWriter then return end
    local ok, w = pcall(getFileWriter, H.FAV_FILE, true, false)
    if not ok or not w then return end
    pcall(function()
        for _, f in ipairs(H.favorites()) do w:write(f.name .. "|" .. table.concat(f.types, ",") .. "\n") end
    end)
    pcall(function() w:close() end)
end
local function extraTypes(base)
    local out = {}
    local ex = call(base, "getExtraItems")
    for i = 0, (ex and ex.size and ex:size() or 0) - 1 do out[#out + 1] = tostring(ex:get(i)) end
    return out
end
function H.addFavorite(name, types)
    local list = H.favorites()
    local sig = table.concat(types, ",")
    for _, f in ipairs(list) do if f.name == name and table.concat(f.types, ",") == sig then return false end end
    table.insert(list, 1, { name = name, types = types })
    while #list > H.FAV_MAX do table.remove(list) end
    H.saveFavorites()
    return true
end

-- GTP 1.8.1: shared with the right-click recipe menu (R.previewDish)
local function previewScore(d, base, it, use) return R.previewDish(d, base, it, use) end

function Win:renderCookEvoDetail(x, y, w, h, e, list)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, e and e.name or T("IGUI_GTPP_Card_EvoPick"))
    if not e then
        self:paragraphs(T("IGUI_GTPP_EvoPick"), cx, cy, cw - 8, C.textDim, sf)
        return
    end
    -- #22: which base (pot, bucket, ...) when there are several
    local oi = math.max(1, math.min(#e.options, tonumber(self.evoOpt) or 1))
    if #e.options > 1 then
        local chips = {}
        for i, o in ipairs(e.options) do
            chips[#chips + 1] = { label = itemName(o.base), on = i == oi, action = function(win) win.evoOpt = i; log("vanilla dish: base %s", itemName(o.base)) end }
        end
        cy = cy + self:cookChips(chips, cx, cy, cw - 8) + 4
    end
    local opt = e.options[oi]
    local d = R.dishOf(opt.base)
    local head = d and T("IGUI_GTPP_EvoScore", string.format("%.2f", tonumber(d.avg) or 0), tostring(tonumber(d.n) or 0)) or T("IGUI_GTPP_EvoNoScore")
    cy = cy + self:paragraphs(itemName(opt.base) .. " - " .. head, cx, cy, cw - 8, d and scoreCol(d.avg) or C.textDim, sf) + 6
    local okI, items = pcall(function() return opt.recipe:getItemsCanBeUse(self.player, opt.base, list.containers) end)
    local rows = {}
    local lvl = K.level(self.player)
    if okI and items and items.size then
        local seenType = {}
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it and it ~= opt.base then
                -- same type and same score: shown once
                local key = tostring(call(it, "getFullType")) .. "|" .. tostring(R.scoreOf(it))
                if not seenType[key] then
                    seenType[key] = true
                    local needCooked = call(opt.recipe, "needToBeCooked", it) == false
                    local frozen = call(it, "isFrozen") == true and call(opt.recipe, "isAllowFrozenItem") ~= true
                    local use = ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.getRealEvolvedItemUse
                        and select(2, pcall(ISInventoryPaneContextMenu.getRealEvolvedItemUse, it, opt.recipe, lvl))
                    use = type(use) == "number" and use or nil
                    rows[#rows + 1] = { it = it, ok = not needCooked and not frozen, needCooked = needCooked, frozen = frozen, use = use,
                        after = previewScore(d, opt.base, it, use), score = R.scoreOf(it), counts = R.counts(it) }
                end
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.ok ~= b.ok then return a.ok end
        if a.score ~= b.score then return a.score > b.score end
        return itemName(a.it) < itemName(b.it)
    end)
    local function add(win, row)
        log("vanilla dish: add %s (score %+.2f, dish would be %.2f) to %s", itemName(row.it), row.score, row.after, itemName(opt.base))
        local pn = call(win.player, "getPlayerNum") or 0
        local okC, err = pcall(ISInventoryPaneContextMenu.onAddItemInEvoRecipe, opt.recipe, opt.base, row.it, pn)
        if not okC then log("adding through vanilla FAILED: %s", tostring(err)) end
        if not e.started then win.evoFollow = e.name end
        win.evoDirty = true
    end
    -- #41: remember this dish / make a favorite again, one ingredient per click
    local have = extraTypes(opt.base)
    -- GTP 1.8.0: the cook writes a note for whoever eats it
    local NU, Nn = HARMONIE_GTP.CookNoteUI, HARMONIE_GTP.CookNotes
    local canNote = e.started and NU and Nn and Nn.canWrite(self.player, opt.base)
    if e.started and (#have > 0 or canNote) then
        local bx = cx
        if #have > 0 then
            bx = bx + self:cookButton(bx, cy, T("IGUI_GTPP_FavSave"), true, function(win)
                if H.addFavorite(e.name, have) then log("favorite saved: %s (%s)", e.name, table.concat(have, ", ")) end
                win.favSaved = e.name
            end) + 8
        end
        if canNote then
            local label = Nn.noteOf(opt.base) and T("IGUI_GTPN_MenuEdit") or T("IGUI_GTPN_MenuWrite")
            bx = bx + self:cookButton(bx, cy, label, true, function(win)
                log("tab: write a note on %s", itemName(opt.base))
                NU.openWrite(win.player, opt.base)
            end) + 8
        end
        if self.favSaved == e.name then shadowText(self, T("IGUI_GTPP_FavSaved"), bx + 4, cy + 6, C.good, 1, sf) end
        cy = cy + lh + 18
    end
    local shownFav = 0
    for fi, fav in ipairs(H.favorites()) do
        if fav.name == e.name and shownFav < 3 then
            shownFav = shownFav + 1
            -- what is still missing from the favorite (counting repeats)
            local left = {}
            for _, ty in ipairs(fav.types) do left[#left + 1] = ty end
            for _, ty in ipairs(have) do
                for i, l in ipairs(left) do if l == ty then table.remove(left, i) break end end
            end
            local nextRow
            for _, ty in ipairs(left) do
                for _, row in ipairs(rows) do
                    if row.ok and tostring(call(row.it, "getFullType")) == ty then nextRow = row break end
                end
                if nextRow then break end
            end
            local names = {}
            for _, ty in ipairs(fav.types) do local i = H.item(ty); names[#names + 1] = i and i.name or (ty:match("%.(.+)$") or ty) end
            local line = T("IGUI_GTPP_FavLine", table.concat(names, ", "))
            local label = (#left == 0) and T("IGUI_GTPP_FavDone") or (nextRow and T("IGUI_GTPP_FavNext", itemName(nextRow.it)) or T("IGUI_GTPP_FavMissing"))
            local bw2 = tw(sf, label) + 30
            shadowText(self, fit(line, cw - bw2 - 40, sf), cx, cy + 6, C.accent, 1, sf)
            self:cookButton(cx + cw - bw2 - 30, cy, label, nextRow ~= nil and #left > 0, function(win) if nextRow then add(win, nextRow) end end, bw2)
            local xr = { x = cx + cw - 22, y = cy + 4, w = 16, h = lh }
            shadowText(self, "x", xr.x + 4, xr.y, C.bad, 1, sf)
            xr.action = function(win) table.remove(H.favorites(), fi); H.saveFavorites(); log("favorite removed: %s", fav.name) end
            clickable(self, xr)
            cy = cy + lh + 18
        end
    end
    -- #20: one click for the best prepared food that can go in
    local best
    for _, row in ipairs(rows) do if row.ok and row.counts and row.score > 0 then best = row break end end
    if best then
        self:cookButton(cx, cy, T("IGUI_GTPP_AddBest", itemName(best.it), string.format("%.2f", best.after)), true, function(win) add(win, best) end)
        cy = cy + lh + 18
    end
    local rowH = math.max(40, lh * 2 + 10)
    local boxTop, boxBottom = cy, y + h - 6
    self:scrolled("evoIng", cx, cy, cw, boxBottom - cy, function(yy)
        local start = yy
        for _, row in ipairs(rows) do
            local it = row.it
            local l2, c2 = scoreLine(it)
            if call(it, "isSpice") == true then l2 = T("IGUI_GTPP_Spice"); c2 = C.textDim
            elseif not row.counts then l2 = T("IGUI_GTPP_Minor"); c2 = C.textDim end
            if row.needCooked then l2 = T("IGUI_GTPP_NeedCooked"); c2 = C.bad
            elseif row.frozen then l2 = T("IGUI_GTPP_Frozen"); c2 = C.bad
            elseif row.counts then l2 = l2 .. "  " .. T("IGUI_GTPP_After", string.format("%.2f", row.after)) end
            local l1 = itemName(it) .. (row.use and (" (" .. tostring(row.use) .. ")") or "")
            local bw = tw(sf, T("IGUI_GTPP_Add")) + 24
            self:cookItemRow(cx, yy, cw - 14 - bw, rowH, it, l1, l2, c2, false, "evoIng")
            local bx, by = cx + cw - 10 - bw, yy + math.floor((rowH - (lh + 12)) / 2)
            if by + lh + 12 > boxTop and by < boxBottom then
                self:cookButton(bx, by, T("IGUI_GTPP_Add"), row.ok, function(win) add(win, row) end, bw)
            end
            yy = yy + rowH + 4
        end
        if #rows == 0 then yy = yy + self:paragraphs(T("IGUI_GTPP_EvoNothing"), cx, yy, cw - 12, C.textDim, sf) end
        return yy - start
    end)
end

-- ------------------------------------------------------------------ vanilla crafting recipes
function H.cookCraftRecipes()
    if H.cookCraftCache then return H.cookCraftCache end
    local want = {}
    for _, e in ipairs(K.CRAFT_LIST or {}) do want[e[1]] = e[2] or false end
    local out = {}
    local ok, all = pcall(function() return getScriptManager():getAllCraftRecipes() end)
    if not ok or not all then
        ok, all = pcall(function() return ScriptManager.instance:getAllCraftRecipes() end)
    end
    if ok and all and all.size then
        for i = 0, all:size() - 1 do
            local r = all:get(i)
            local name = tostring(call(r, "getName") or "")
            if want[name] ~= nil then
                local result = want[name] or nil
                out[#out + 1] = { recipe = r, id = name, name = tostring(call(r, "getTranslationName") or name), result = result,
                    icon = call(r, "getIconTexture") }
            end
        end
    else
        R.logOnce("nocraft", "could not read the game's craft recipes (%s)", tostring(all))
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    log("vanilla Cooking craft recipes found: %d of %d listed", #out, #(K.CRAFT_LIST or {}))
    H.cookCraftCache = out
    return out
end

-- GTP 1.5.0 (#21): known by this character? (recipes that need learning)
local function craftKnown(player, r)
    if not (player and player.isRecipeKnown) then return true end
    local ok, v = pcall(player.isRecipeKnown, player, r, true)
    return not ok or v == true
end

-- can it be made right now with what is at hand? vanilla's own HandcraftLogic,
-- a few recipes per frame, kept until what is at hand changes
H.CRAFT_CHECKS_PER_FRAME = 4
function Win:craftCanMake(e, sc)
    self.craftCan = self.craftCan or {}
    if self.craftCanGen ~= sc.gen then self.craftCan = {}; self.craftCanGen = sc.gen; self.craftChecked = 0 end
    local v = self.craftCan[e.id]
    if v ~= nil then return v end
    if (self.craftCheckedFrame or 0) >= H.CRAFT_CHECKS_PER_FRAME then return nil end
    self.craftCheckedFrame = (self.craftCheckedFrame or 0) + 1
    if not HandcraftLogic or not HandcraftLogic.new then self.craftCan[e.id] = "?"; return "?" end
    local ok, can = pcall(function()
        self.craftLogic = self.craftLogic or HandcraftLogic.new(self.player, nil, nil)
        local lg = self.craftLogic
        lg:setContainers(sc.containers)
        lg:setRecipe(e.recipe)
        return lg:canPerformCurrentRecipe() == true
    end)
    if not ok then R.logOnce("craftcan", "checking craft recipes FAILED (%s) -- shown without the mark", tostring(can)); can = "?" end
    self.craftCan[e.id] = can
    return can
end

function Win:renderCookCraft(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local sc = self:cookScan()
    self.craftCheckedFrame = 0
    local all = H.cookCraftRecipes()
    local q = self:query()
    local f = self.craftFilter or "known"
    local shown, known = {}, 0
    for _, e in ipairs(all) do
        local kn = craftKnown(self.player, e.recipe)
        if kn then known = known + 1 end
        local can = kn and self:craftCanMake(e, sc)
        local keep = (q == "" or e.name:lower():find(q, 1, true))
            and (f == "all" or kn) and (f ~= "ready" or can == true)
        if keep then shown[#shown + 1] = { e = e, known = kn, can = can } end
    end
    -- ready ones first
    table.sort(shown, function(a, b)
        local ra, rb = a.can == true, b.can == true
        if ra ~= rb then return ra end
        return a.e.name < b.e.name
    end)
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, T("IGUI_GTPP_Card_Craft", tostring(#shown), tostring(#all)))
    local used = self:placeSearch(cx, cy, math.min(cw - 4, 420), true)
    local chips = {}
    for _, k in ipairs({ "ready", "known", "all" }) do
        chips[#chips + 1] = { label = T("IGUI_GTPP_CraftFilter_" .. k), on = f == k, action = function(win) win.craftFilter = k; log("craft recipes filter: %s", k) end }
    end
    local chipX = cx + math.min(cw - 4, 420) + 10
    if chipX + 200 < cx + cw then
        self:cookChips(chips, chipX, cy, cx + cw - chipX)
        cy, ch = cy + used + 6, ch - used - 6
    else
        cy, ch = cy + used + 6, ch - used - 6
        local u2 = self:cookChips(chips, cx, cy, cw - 8)
        cy, ch = cy + u2 + 4, ch - u2 - 4
    end
    local rowH = math.max(36, lh * 2 + 10)
    local boxTop, boxBottom = cy, cy + ch
    local openLabel = T("IGUI_GTPP_OpenCraft")
    local bw = tw(sf, openLabel) + 24
    self:scrolled("craftList", cx, cy, cw, ch, function(yy)
        local start = yy
        for _, row in ipairs(shown) do
            local e = row.e
            local r = { x = cx, y = yy, w = cw - 10, h = rowH }
            local stateCol = row.can == true and C.good or (row.known and C.warn or C.bad)
            self:drawRect(r.x, r.y, r.w, r.h, 0.55, C.card[1] + 0.02, C.card[2] + 0.04, C.card[3] + 0.02)
            self:drawRectBorder(r.x, r.y, r.w, r.h, 0.6, C.borderDim[1], C.borderDim[2], C.borderDim[3])
            self:drawRect(r.x, r.y, 4, r.h, 1, stateCol[1], stateCol[2], stateCol[3])
            local isz = rowH - 8
            local icon = e.icon or (e.result and H.item(e.result) and H.item(e.result).icon)
            if icon then self:drawTextureScaled(icon, r.x + 8, r.y + 4, isz, isz, 1, 1, 1, 1) end
            local tx = r.x + isz + 16
            local ty = r.y + math.floor((rowH - lh * 2) / 2)
            shadowText(self, fit(e.name, r.w - isz - bw - 30, sf), tx, ty, C.text, 1, sf)
            local sub = not row.known and T("IGUI_GTPP_CraftUnknown") or (row.can == true and T("IGUI_GTPP_CraftReady")
                or (row.can == false and T("IGUI_GTPP_CraftMissing") or T("IGUI_GTPP_CraftChecking")))
            shadowText(self, fit(sub, r.w - isz - bw - 30, sf), tx, ty + lh, stateCol, 1, sf)
            local by = yy + math.floor((rowH - (lh + 12)) / 2)
            if by + lh + 12 > boxTop and by < boxBottom then
                self:cookButton(r.x + r.w - bw - 6, by, openLabel, true, function(win)
                    log("opening the crafting window on %s", e.id)
                    if ISEntityUI and ISEntityUI.OpenHandcraftWindow then
                        local okO, err = pcall(ISEntityUI.OpenHandcraftWindow, win.player, nil, nil, false, e.recipe)
                        if not okO then log("opening the crafting window FAILED: %s", tostring(err)) end
                    else
                        R.logOnce("noentityui", "ISEntityUI.OpenHandcraftWindow missing -- cannot open the crafting window")
                    end
                end, bw)
            end
            yy = yy + rowH + 4
        end
        if #shown == 0 then shadowText(self, T(f == "ready" and "IGUI_GTPP_CraftNoneReady" or "IGUI_GTPG_NoMatch"), cx, yy, C.textDim, 1, sf); yy = yy + lh end
        return yy - start
    end)
end

log("Cooking tab loaded (prepare / vanilla dishes / crafting recipes)")

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

H.COOK_PAGES = { "prep", "evo", "craft" }
H.PREP_WATCHDOG_MS = 10000

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

-- an item's score line
local function scoreLine(it)
    local d = R.dishOf(it)
    if d then return T("IGUI_GTPP_RowDish", string.format("%.2f", tonumber(d.avg) or 0), tostring(tonumber(d.n) or 0)), scoreCol(d.avg) end
    local p = R.prepOf(it)
    if p then return T("IGUI_GTPP_RowPrep", procName(p.p), wordName(p.w), string.format("%+d", tonumber(p.s) or 0)), wordCol(p.w) end
    return T("IGUI_GTPP_RowPlain"), H.C.textDim
end

-- ------------------------------------------------------------------ the tab
function Win:renderCook(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local page = self.cookPage
    if page ~= "prep" and page ~= "evo" and page ~= "craft" then page = "prep"; self.cookPage = page end
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
    return self:renderCookCraft(x, y, w, h)
end

-- ------------------------------------------------------------------ prepare
-- the foods at hand (inventory, bags, the room's boxes), 1 s cache
function Win:prepList()
    local t = nowMs()
    if self.prepCache and t - self.prepCache.at < 1000 then return self.prepCache end
    local list = { at = t, open = {}, done = {} }
    local containers = K.containers(self.player)
    local n = 0
    K.eachItem(containers, function(it)
        n = n + 1
        if n > 800 then return false end
        if R.isFood(it) then
            local why = R.whyNot(it)
            if why == nil then
                list.open[#list.open + 1] = it
            elseif why == "done" or why == "dish" then
                list.done[#list.done + 1] = it
            end
        end
    end)
    local function byName(a, b) return itemName(a) < itemName(b) end
    table.sort(list.open, byName)
    table.sort(list.done, byName)
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
    local shown = {}
    for _, it in ipairs(list.open) do if q == "" or itemName(it):lower():find(q, 1, true) then shown[#shown + 1] = it end end
    local firstDone = #shown + 1
    for _, it in ipairs(list.done) do if q == "" or itemName(it):lower():find(q, 1, true) then shown[#shown + 1] = it end end
    local cx, cy, cw, ch = self:drawCard(x, y, leftW, h, T("IGUI_GTPP_Card_Foods", tostring(#list.open)), texture(U.UI_DIR .. "tab_cook.png"))
    local used = self:placeSearch(cx, cy, cw - 4, true)
    cy, ch = cy + used + 6, ch - used - 6
    local rowH = math.max(40, lh * 2 + 10)
    local sel = self.prepSel
    local selId = sel and call(sel, "getID")
    local boxTop, boxBottom = cy, cy + ch
    self:scrolled("prepList", cx, cy, cw, ch, function(yy)
        local start = yy
        for i, it in ipairs(shown) do
            if i == firstDone and i > 1 then
                shadowText(self, T("IGUI_GTPP_AlreadyDone"), cx, yy + 2, C.accent, 1, sf)
                yy = yy + lh + 6
            elseif i == firstDone then
                shadowText(self, T("IGUI_GTPP_AlreadyDone"), cx, yy + 2, C.accent, 1, sf)
                yy = yy + lh + 6
            end
            local l2, c2 = scoreLine(it)
            if i < firstDone then
                local games = R.gamesFor(it)
                local names = {}
                for j, pid in ipairs(games) do if j <= 3 then names[#names + 1] = procName(pid) end end
                l2 = T("IGUI_GTPP_RowCan", table.concat(names, ", "))
                if not (HARMONIE_Reach and HARMONIE_Reach.isCarried(self.player, it)) then l2 = l2 .. "  " .. T("IGUI_GTPP_InBox") end
                c2 = C.textDim
            end
            local r = self:cookItemRow(cx, yy, cw - 10, rowH, it, itemName(it), l2, c2, selId ~= nil and call(it, "getID") == selId, "prepList")
            if i < firstDone then
                r.action = function(win)
                    win.prepSel = it
                    win.prepGame = nil
                    log("prepare: chose %s", itemName(it))
                end
                if r.y + r.h > boxTop and r.y < boxBottom then clickable(self, r) end
            end
            yy = yy + rowH + 4
        end
        if #shown == 0 then
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
    local it = self.prepSel
    -- the chosen food must still be at hand and not prepared
    if it then
        local still = false
        for _, o in ipairs(list.open) do if o == it then still = true break end end
        if not still and not self.prepRun then self.prepSel = nil; it = nil end
    end
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, T("IGUI_GTPP_Card_Prepare"))
    if self.prepRun then
        local run = self.prepRun
        shadowText(self, fit(T("IGUI_GTPP_Running", run.name, procName(run.pid)), cw - 8, sf), cx, cy, C.warn, 1, sf)
        cy = cy + lh + 6
        shadowText(self, fit(T("IGUI_GTPP_Phase_" .. tostring(run.phase)), cw - 8, sf), cx, cy, C.textDim, 1, sf)
        cy = cy + lh + 10
        if run.phase ~= "game" then
            self:cookButton(cx, cy, T("IGUI_GTPP_Cancel"), true, function(win)
                log("preparation of %s cancelled by the player (phase %s)", tostring(run.name), tostring(run.phase))
                if run.phase == "bring" or run.phase == "action" then
                    pcall(ISTimedActionQueue.clear, win.player)
                end
                win.prepRun = nil
                win.prepCache = nil
                win.prepLast = { name = run.name, pid = run.pid, why = "cancelled" }
            end)
        end
        return
    end
    if self.prepLast then
        local L = self.prepLast
        local col = L.word and wordCol(L.word) or C.bad
        local line = L.word and T("IGUI_GTPP_LastDone", L.name, procName(L.pid), wordName(L.word), string.format("%+d", R.WORD_SCORE[L.word] or 0))
            or T("IGUI_GTPP_LastRefused", L.name, T("IGUI_GTPP_Why_" .. tostring(L.why)))
        cy = cy + self:paragraphs(line, cx, cy, cw - 8, col, sf) + 6
    end
    if not it then
        self:paragraphs(T("IGUI_GTPP_PickFood"), cx, cy, cw - 8, C.textDim, sf)
        return
    end
    -- the food
    local isz = lh * 2 + 6
    local tex = call(it, "getTex") or call(it, "getTexture")
    self:drawRect(cx, cy, isz, isz, 0.45, 0, 0, 0)
    if tex then self:drawTextureScaled(tex, cx, cy, isz, isz, 1, 1, 1, 1) end
    shadowText(self, fit(itemName(it), cw - isz - 16, H.medium and H.medium() or sf), cx + isz + 8, cy, C.text, 1, H.medium and H.medium() or sf)
    local games, kind = R.gamesFor(it)
    shadowText(self, fit(T("IGUI_GTPP_Kind_" .. tostring(kind)), cw - isz - 16, sf), cx + isz + 8, cy + lh + 4, C.textDim, 1, sf)
    cy = cy + isz + 10
    shadowText(self, T("IGUI_GTPP_ChooseGame"), cx, cy, C.accent, 1, sf)
    cy = cy + lh + 4
    local scan = K.scan(self.player)
    local rowH = lh * 2 + 12
    for _, pid in ipairs(games) do
        local proc = K.PROCS[pid]
        local toolItem, grade, group = nil, "best", proc.tools and proc.tools[1]
        if group then toolItem, grade = K.findTool(scan, group) end
        local can = (not group) or toolItem ~= nil or grade == "bare"
        local heatOk = not proc.heat or (scan and scan.heat ~= nil)
        local r = { x = cx, y = cy, w = cw - 8, h = rowH }
        local over = inside(r, self:getMouseX(), self:getMouseY())
        local okAll = can and heatOk
        self:drawRect(r.x, r.y, r.w, r.h, okAll and (over and 0.95 or 0.75) or 0.35, C.accentDark[1], C.accentDark[2], C.accentDark[3])
        self:drawRectBorder(r.x, r.y, r.w, r.h, 0.8, (okAll and C.border or C.borderDim)[1], (okAll and C.border or C.borderDim)[2], (okAll and C.border or C.borderDim)[3])
        local ps = rowH - 8
        local pic = procIcon(pid)
        if pic then self:drawTextureScaled(pic, r.x + 4, r.y + 4, ps, ps, okAll and 1 or 0.4, 1, 1, 1) end
        local tx = r.x + ps + 12
        shadowText(self, fit(procName(pid), r.w - ps - 20, sf), tx, r.y + 4, okAll and C.text or C.textDim, 1, sf)
        local sub
        if not heatOk then sub = T("IGUI_GTPP_NeedHeat")
        elseif not group then sub = T("IGUI_GTPP_NoTool")
        elseif toolItem then sub = T("IGUI_GTPP_Tool_" .. tostring(grade), itemName(toolItem))
        elseif grade == "bare" then sub = T("IGUI_GTPP_Tool_bare")
        else sub = T("IGUI_GTPP_NeedTool", T("IGUI_GTPC_Tool_" .. tostring(group))) end
        shadowText(self, fit(sub, r.w - ps - 20, sf), tx, r.y + 4 + lh, okAll and C.textDim or C.bad, 1, sf)
        if okAll then
            r.action = function(win) win:startPrep(it, pid, toolItem, grade, group) end
            clickable(self, r)
        end
        cy = cy + rowH + 4
        if cy > y + h - rowH then break end
    end
end

-- Start: bring it into the inventory -> minigame -> timed action -> server
function Win:startPrep(item, pid, toolItem, grade, group)
    if self.prepRun then return end
    local player = self.player
    local Gm = HARMONIE_GTP.CookGames
    if Gm and Gm.busy and Gm.busy() then log("prepare: a minigame is already open"); return end
    local run = { item = item, pid = pid, name = itemName(item), phase = "bring", at = nowMs() }
    self.prepRun = run
    self.prepLast = nil
    local win = self
    local function finish(word, why)
        if win.prepRun ~= run then return end
        win.prepRun = nil
        win.prepCache = nil
        win.prepLast = { name = run.name, pid = pid, word = word, why = why }
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
            run.phase, run.at, run.word = "action", nowMs(), word
            local action = HARMONIE_GTP_CookStepAction:new(player, pid, word, toolItem or item)
            action.onEnd = function(done, w)
                if win.prepRun ~= run then return end
                if not done then log("prepare: the action for %s was stopped", run.name); finish(nil, "stopped"); return end
                run.phase, run.at = "server", nowMs()
                R.request(player, item, pid, w or word)
                if not (isClient and isClient()) then finish(w or word) end
            end
            ISTimedActionQueue.add(action)
        end
        run.phase, run.at = "game", nowMs()
        -- GTP 1.2.0: the server notes when the minigame began (anti-cheat)
        R.begin(player, item, pid)
        if K.minigamesOn() and Gm and Gm.play then
            local pp = { proc = K.PROCS[pid], tools = group and { { grade = grade, item = toolItem, group = group } } or {}, help = {} }
            local diff = K.difficulty(player, pp, nil)
            local ease = K.levelEase(K.level(player))
            local proc = K.PROCS[pid]
            local itemTex = call(item, "getTexture")
            local toolTex = toolItem and call(toolItem, "getTexture") or nil
            log("prepare %s with %s: difficulty %.2f, tool %s (%s)", run.name, pid, diff, toolItem and K.typeOf(toolItem) or "none", tostring(grade))
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

-- the server's answer (MP): the tab shows it
R.onSet = function(args, item)
    local win = GTPGuide and GTPGuide.window
    if not win or not win.prepRun or args.what ~= "prep" then return end
    local run = win.prepRun
    if call(run.item, "getID") == args.id then
        win.prepRun = nil
        win.prepCache = nil
        win.prepLast = { name = run.name, pid = run.pid, word = args.prep and args.prep.w or run.word }
    end
end
R.onRefused = function(args)
    local win = GTPGuide and GTPGuide.window
    if not win then return end
    local run = win.prepRun
    win.prepRun = nil
    win.prepCache = nil
    win.prepLast = { name = run and run.name or "?", pid = run and run.pid, why = args.why }
end

-- ------------------------------------------------------------------ vanilla evolved recipes
-- every evolved recipe that something at hand can start or continue (1.5 s cache)
function Win:evoList()
    local t = nowMs()
    if self.evoCache and t - self.evoCache.at < 1500 then return self.evoCache end
    local list = { at = t, entries = {} }
    local containers = K.containers(self.player)
    list.containers = containers
    local seen, n = {}, 0
    if RecipeManager and RecipeManager.getEvolvedRecipe then
        K.eachItem(containers, function(it)
            n = n + 1
            if n > 800 then return false end
            local ok, recipes = pcall(RecipeManager.getEvolvedRecipe, it, self.player, containers, false)
            if ok and recipes and recipes.size then
                for i = 0, recipes:size() - 1 do
                    local r = recipes:get(i)
                    local key = tostring(call(r, "getName")) .. "|" .. tostring(call(it, "getFullType"))
                    -- a dish already started is listed by itself, fresh bases once per type
                    if R.dishOf(it) or call(r, "isResultItem", it) == true then key = key .. "|" .. tostring(call(it, "getID")) end
                    if not seen[key] then
                        seen[key] = true
                        list.entries[#list.entries + 1] = { recipe = r, base = it, name = T("ContextMenu_EvolvedRecipe_" .. tostring(call(r, "getUntranslatedName"))),
                            started = call(r, "isResultItem", it) == true }
                    end
                end
            end
        end)
    else
        R.logOnce("noRM", "RecipeManager.getEvolvedRecipe missing -- no vanilla evolved recipes listed")
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
        if q == "" or e.name:lower():find(q, 1, true) or itemName(e.base):lower():find(q, 1, true) then shown[#shown + 1] = e end
    end
    local cx, cy, cw, ch = self:drawCard(x, y, leftW, h, T("IGUI_GTPP_Card_Evo", tostring(#list.entries)))
    local used = self:placeSearch(cx, cy, cw - 4, true)
    cy, ch = cy + used + 6, ch - used - 6
    local rowH = math.max(40, lh * 2 + 10)
    local sel = self.evoSel
    -- keep the choice across the 1.5 s refresh (the base becomes the dish)
    local cur
    if sel then
        for _, e in ipairs(list.entries) do
            if e.base == sel.base and call(e.recipe, "getName") == call(sel.recipe, "getName") then cur = e break end
        end
        if not cur then
            for _, e in ipairs(list.entries) do
                if e.started and call(e.recipe, "getName") == call(sel.recipe, "getName") and sel.started == false then cur = e break end
            end
        end
        self.evoSel = cur
    end
    local boxTop, boxBottom = cy, cy + ch
    self:scrolled("evoList", cx, cy, cw, ch, function(yy)
        local start = yy
        for _, e in ipairs(shown) do
            local l2, c2 = itemName(e.base), C.textDim
            local d = R.dishOf(e.base)
            if d then l2 = l2 .. "  " .. T("IGUI_GTPP_RowDish", string.format("%.2f", tonumber(d.avg) or 0), tostring(tonumber(d.n) or 0)); c2 = scoreCol(d.avg) end
            local r = self:cookItemRow(cx, yy, cw - 10, rowH, e.base, e.name, l2, c2, cur == e, "evoList")
            r.action = function(win) win.evoSel = e; win.scroll.evoIng = 0; log("vanilla dish: chose %s on %s", e.name, itemName(e.base)) end
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

function Win:renderCookEvoDetail(x, y, w, h, e, list)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, e and e.name or T("IGUI_GTPP_Card_EvoPick"))
    if not e then
        self:paragraphs(T("IGUI_GTPP_EvoPick"), cx, cy, cw - 8, C.textDim, sf)
        return
    end
    local d = R.dishOf(e.base)
    local head = d and T("IGUI_GTPP_EvoScore", string.format("%.2f", tonumber(d.avg) or 0), tostring(tonumber(d.n) or 0)) or T("IGUI_GTPP_EvoNoScore")
    cy = cy + self:paragraphs(itemName(e.base) .. " - " .. head, cx, cy, cw - 8, d and scoreCol(d.avg) or C.textDim, sf) + 6
    local okI, items = pcall(function() return e.recipe:getItemsCanBeUse(self.player, e.base, list.containers) end)
    local rows = {}
    if okI and items and items.size then
        local seenType = {}
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it and it ~= e.base then
                -- same type and same score: shown once
                local key = tostring(call(it, "getFullType")) .. "|" .. tostring(R.scoreOf(it))
                if not seenType[key] then seenType[key] = true; rows[#rows + 1] = it end
            end
        end
    end
    table.sort(rows, function(a, b)
        local sa, sb = R.scoreOf(a), R.scoreOf(b)
        if sa ~= sb then return sa > sb end
        return itemName(a) < itemName(b)
    end)
    local rowH = math.max(40, lh * 2 + 10)
    local lvl = K.level(self.player)
    local boxTop, boxBottom = cy, y + h - 6
    self:scrolled("evoIng", cx, cy, cw, boxBottom - cy, function(yy)
        local start = yy
        for _, it in ipairs(rows) do
            local l2, c2 = scoreLine(it)
            local spice = call(it, "isSpice") == true
            if spice then l2 = T("IGUI_GTPP_Spice"); c2 = C.textDim end
            local needCooked = call(e.recipe, "needToBeCooked", it) == false
            local frozen = call(it, "isFrozen") == true and call(e.recipe, "isAllowFrozenItem") ~= true
            local use = ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.getRealEvolvedItemUse
                and select(2, pcall(ISInventoryPaneContextMenu.getRealEvolvedItemUse, it, e.recipe, lvl))
            local l1 = itemName(it) .. ((type(use) == "number") and (" (" .. tostring(use) .. ")") or "")
            if needCooked then l2 = T("IGUI_GTPP_NeedCooked"); c2 = C.bad elseif frozen then l2 = T("IGUI_GTPP_Frozen"); c2 = C.bad end
            local bw = tw(sf, T("IGUI_GTPP_Add")) + 24
            local r = self:cookItemRow(cx, yy, cw - 14 - bw, rowH, it, l1, l2, c2, false, "evoIng")
            local okAdd = not needCooked and not frozen
            local bx, by = cx + cw - 10 - bw, yy + math.floor((rowH - (lh + 12)) / 2)
            if by + lh + 12 > boxTop and by < boxBottom then
                self:cookButton(bx, by, T("IGUI_GTPP_Add"), okAdd, function(win)
                    log("vanilla dish: add %s (score %+.2f) to %s", itemName(it), R.scoreOf(it), itemName(e.base))
                    local pn = call(win.player, "getPlayerNum") or 0
                    local okC, err = pcall(ISInventoryPaneContextMenu.onAddItemInEvoRecipe, e.recipe, e.base, it, pn)
                    if not okC then log("adding through vanilla FAILED: %s", tostring(err)) end
                    win.evoCache = nil
                end, bw)
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

function Win:renderCookCraft(x, y, w, h)
    local C = H.C
    local sf = H.small()
    local lh = lineH(sf)
    local all = H.cookCraftRecipes()
    local q = self:query()
    local shown = {}
    for _, e in ipairs(all) do if q == "" or e.name:lower():find(q, 1, true) then shown[#shown + 1] = e end end
    local cx, cy, cw, ch = self:drawCard(x, y, w, h, T("IGUI_GTPP_Card_Craft", tostring(#shown), tostring(#all)))
    local used = self:placeSearch(cx, cy, math.min(cw - 4, 420), true)
    cy, ch = cy + used + 6, ch - used - 6
    local rowH = math.max(36, lh + 20)
    local boxTop, boxBottom = cy, cy + ch
    local openLabel = T("IGUI_GTPP_OpenCraft")
    local bw = tw(sf, openLabel) + 24
    self:scrolled("craftList", cx, cy, cw, ch, function(yy)
        local start = yy
        for _, e in ipairs(shown) do
            local r = { x = cx, y = yy, w = cw - 10, h = rowH }
            self:drawRect(r.x, r.y, r.w, r.h, 0.55, C.card[1] + 0.02, C.card[2] + 0.04, C.card[3] + 0.02)
            self:drawRectBorder(r.x, r.y, r.w, r.h, 0.6, C.borderDim[1], C.borderDim[2], C.borderDim[3])
            local isz = rowH - 8
            local icon = e.icon or (e.result and H.item(e.result) and H.item(e.result).icon)
            if icon then self:drawTextureScaled(icon, r.x + 5, r.y + 4, isz, isz, 1, 1, 1, 1) end
            shadowText(self, fit(e.name, r.w - isz - bw - 30, sf), r.x + isz + 14, r.y + math.floor((rowH - lh) / 2), C.text, 1, sf)
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
        if #shown == 0 then shadowText(self, T("IGUI_GTPG_NoMatch"), cx, yy, C.textDim, 1, sf); yy = yy + lh end
        return yy - start
    end)
end

log("Cooking tab loaded (prepare / vanilla dishes / crafting recipes)")

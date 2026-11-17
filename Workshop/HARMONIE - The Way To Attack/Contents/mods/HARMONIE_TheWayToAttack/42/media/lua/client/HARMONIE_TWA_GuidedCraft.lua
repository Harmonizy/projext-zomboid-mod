--============================================================================
-- HARMONIE_TheWayToAttack -- Guided craft mode (client, TWA 1.0.6 / 1.0.7)
--
-- Owner's plan HARMONIE_TWA_Guided_Mode_Redesign_TH.txt (2026-11-16): the
-- craft tab tells a new player what they are making, what is missing and
-- which ONE button to press next. A new VIEW over the old controller only:
--   * every button calls an existing TWACraftWindow handler
--     (onStartButtonClicked, onConfirmProcedure, onFinishButtonClicked,
--     onIncompleteButtonClicked, onCancelButtonClicked, onAbortCenterAction,
--     onPracticeProcedure, openBaseChooser, jumpToRecipe, onContinueClicked,
--     onBackClicked) -- those check everything again; timed actions, server,
--     MINIGAMES (never skipped: "Do this step" = onConfirmProcedure ->
--     TWAMinigame.play), taking / giving back items are untouched;
--   * the state shown is derived every frame from the window's real fields
--     (selectedRecipe, active, resumeItem, activeProcId, activeAction,
--     activeCenterAction, practicing) -- nothing is stored as a step number;
--   * requirement checks (DescribeAll = what CheckEligibility checks) and
--     the item counts are cached for CACHE_MS, never per frame;
--   * Guided <-> Advanced (the old 3-panel page) is a view switch only.
-- 1.0.7 (owner 2026-11-17: "as few words as possible, symbols, only what to
-- do now, the explanation on hover, careful nothing overlaps"): glyphs
-- (hub HARMONIE_Glyph) instead of words, every explanation in a hover text
-- (hub HARMONIE_HoverTip), one short line per item, each area clipped
-- (setStencilRect) so nothing draws over the next one.
--============================================================================

require "HARMONIE_TWA_CraftUI"

TWAGuided = TWAGuided or {}
local G = TWAGuided
G.CACHE_MS = 750
G.RESULT_MS = 15000
local WORD_RANK = { Miss = 0, Bad = 1, Good = 2, Excellent = 3 }

local H
local function h() H = H or TWACraftUI.H; return H end
local function now() return getTimestampMs and getTimestampMs() or 0 end
local function sc(px) return h().S(px) end
local function small() return TWAFont.small() end
local function medium() return TWAFont.medium() end
local function fh(f) return getTextManager():getFontHeight(f or small()) end
local function tw(s, f) return getTextManager():MeasureStringX(f or small(), s or "") end
local function fit(s, w, f) return TWACraftUI.fitText(s, w, f or small()) end
local function text(win, s, x, y, c, f) h().drawTextShadowed(win, s, x, y, c[1], c[2], c[3], c[4] or 1, f or small()) end
local function wrap(s, w, f, maxLines)
    local BN = HARMONIE_Banner
    if BN and BN.wrap then return BN.wrap(s or "", math.max(20, w), f or small(), maxLines or 4) end
    return h().wrapTextLines(s or "", w, f or small())
end
local function procName(pid)
    local p = pid and TWAProcedures.List[pid]
    return p and getText(p.nameKey) or tostring(pid)
end

local C = {
    text = { 0.95, 0.93, 0.86 }, dim = { 0.70, 0.66, 0.56 }, accent = { 1.0, 0.78, 0.2 },
    ok = { 0.50, 0.90, 0.50 }, bad = { 0.98, 0.55, 0.45 }, warn = { 1.0, 0.80, 0.35 }, info = { 0.62, 0.78, 1.0 },
}

-- a glyph (hub); `fallback` text when the hub's glyphs are missing
local function glyph(win, name, x, y, size, col, fallback)
    local GL = HARMONIE_Glyph
    if GL and GL.draw and GL.draw(win, name, x, y, size, col or C.text) then return true end
    if fallback then text(win, fallback, x, y + math.floor((size - fh()) / 2), col or C.text) end
    return false
end
-- hover text for a rect (hub HoverTip, else the window's own tooltip)
local function hover(win, s, x, y, w, ht)
    if not s or s == "" then return false end
    local mx, my = win:getMouseX(), win:getMouseY()
    if not (mx >= x and mx < x + w and my >= y and my < y + ht) then return false end
    local HT = HARMONIE_HoverTip
    if HT and HT.set then HT.set(win, s, mx, my) else win.hoverTooltip = { lines = { s }, x = x, y = y + ht + 2 } end
    return true
end
-- an area nothing may draw out of
local function clip(win, x, y, w, ht)
    if win.setStencilRect then pcall(win.setStencilRect, win, x, y, w, ht) end
end
local function unclip(win)
    if win.clearStencilRect then pcall(win.clearStencilRect, win) end
end
-- one short line, the whole text on hover
local function line1(win, s, x, y, w, col, glyphName, gcol)
    local gs = fh()
    local tx = x
    if glyphName then glyph(win, glyphName, x, y, gs, gcol or col); tx = x + gs + 6 end
    local t = fit(s, x + w - tx)
    text(win, t, tx, y, col)
    if t ~= s then hover(win, s, x, y, w, fh() + 2) end
    return y + fh() + 4
end

-- ---------------------------------------------------------------- mode
function TWACraftWindow:guidedOn()
    local W = TWAWorkbench
    if W and W.ensurePrefs then W.ensurePrefs() end
    return not (W and W.guided == false)
end

-- a view switch only: the started craft, the running action, the selected
-- recipe all stay exactly as they are
function TWACraftWindow:setGuided(on)
    local W = TWAWorkbench
    if not W then return end
    W.guided = on and true or false
    if W.savePrefs then W.savePrefs() end
    TWALog("Guided", "view -> %s (recipe %s, active %s, busy %s)", W.guided and "guided" or "advanced",
        tostring(self.selectedRecipe and self.selectedRecipe.id), tostring(self.active and self.active.recipeId), tostring(self:isBusy()))
    self.guidedMenu = nil
    if self.page then self:setPage(self.page) end
end

-- the old page's widgets stay hidden under the guided view
local OLD = { "startButton", "cancelButton", "incompleteButton", "finishButton", "centerAbortButton", "procConfirmButton",
    "procCancelButton", "procPracticeButton", "procSearchButton", "adminItemsButton", "adminSkillsButton", "backButton",
    "craftGoWeapons", "craftGoMaterials" }
function TWACraftWindow:guidedHideOld()
    for _, f in ipairs(OLD) do
        local w = self[f]
        if w and w:getIsVisible() then w:setVisible(false) end
    end
end

-- ---------------------------------------------------------------- geometry
function TWACraftWindow:guidedGeom()
    local lw = math.floor((self.width - 8) * 0.6)
    local rx = 4 + lw + 6
    return {
        lx = 4 + 8, lw = lw - 16, cardL = { x = 4, w = lw },
        rx = rx + 8, rw = self.width - 4 - rx - 16, cardR = { x = rx, w = self.width - 4 - rx },
        top = self.contentTop, bottom = self.panelBottom,
    }
end

function TWACraftWindow:drawGuidedCards(top, bottom)
    local g = self:guidedGeom()
    -- no title words on the left (the header says what it is)
    self:drawCard(g.cardL.x, top, g.cardL.w, bottom - top, "")
    local recipe = self.selectedRecipe
    local n, d = 0, 0
    local done = self:currentDone()
    for _, pid in ipairs(recipe and recipe.procedures or {}) do
        if TWAProcedures.List[pid] then
            n = n + 1
            if done[pid] then d = d + 1 end
        end
    end
    self:drawCard(g.cardR.x, top, g.cardR.w, bottom - top, getText("IGUI_TWA_G_Card_Steps", tostring(d), tostring(n)))
end

-- ---------------------------------------------------------------- buttons
-- drawn buttons: registered every frame in self.guidedHits (renderBody
-- clears them first, so nothing stale is ever clicked). opts.icon = a glyph
-- (alone when label is "" -- the tip then says what it does); opts.info =
-- a small "i" at the right: there is more to read on hover.
local KIND = {
    primary = { 0.55, 0.30, 0.04 }, danger = { 0.55, 0.12, 0.08 }, secondary = { 0.22, 0.17, 0.06 },
}
function TWACraftWindow:guidedButton(id, label, x, y, w, ht, opts)
    opts = opts or {}
    label = label or ""
    local enabled = opts.enabled ~= false
    local kind = opts.kind or "secondary"
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = mx >= x and mx < x + w and my >= y and my < y + ht
    local bg = KIND[kind] or KIND.secondary
    if not enabled then
        self:drawRect(x, y, w, ht, 0.85, 0.09, 0.085, 0.08)
        self:drawRectBorder(x, y, w, ht, 0.6, 0.35, 0.33, 0.3)
    else
        local a = over and 1 or 0.88
        self:drawRect(x, y, w, ht, a, bg[1], bg[2], bg[3])
        local ba = 0.9
        if kind == "primary" and TWABlink and TWABlink.level then ba = 0.55 + 0.45 * TWABlink.level() end
        local bc = kind == "danger" and { 1, 0.45, 0.35 } or C.accent
        self:drawRectBorder(x, y, w, ht, over and 1 or ba, bc[1], bc[2], bc[3])
        if kind == "primary" then self:drawRectBorder(x + 1, y + 1, w - 2, ht - 2, (over and 1 or ba) * 0.5, bc[1], bc[2], bc[3]) end
    end
    local c = enabled and C.text or { 0.6, 0.58, 0.54 }
    local f = opts.font or small()
    local gs = math.min(ht - 8, math.max(fh(), math.floor(ht * 0.6)))
    local infoW = opts.info and (fh() + 6) or 0
    if label == "" and opts.icon then
        glyph(self, opts.icon, x + math.floor((w - gs) / 2), y + math.floor((ht - gs) / 2), gs, c, "?")
    else
        local iconW = opts.icon and (gs + 6) or 0
        if tw(label, f) > w - 12 - iconW - infoW and f ~= small() then f = small() end
        local s = fit(label, w - 12 - iconW - infoW, f)
        local total = iconW + tw(s, f)
        local sx = x + math.floor((w - infoW - total) / 2)
        if opts.icon then glyph(self, opts.icon, sx, y + math.floor((ht - gs) / 2), gs, c) end
        text(self, s, sx + iconW, y + math.floor((ht - fh(f)) / 2), c, f)
    end
    if opts.info then glyph(self, "info", x + w - infoW, y + math.floor((ht - fh()) / 2), fh(), C.info) end
    if over then
        if opts.tip then hover(self, opts.tip, x, y, w, ht) end
    end
    self.guidedHits = self.guidedHits or {}
    self.guidedHits[#self.guidedHits + 1] = { id = id, x = x, y = y, w = w, h = ht, enabled = enabled, fn = opts.fn }
end

function TWACraftWindow:guidedMouseDown(x, y)
    local list = self.guidedHits or {}
    for i = #list, 1, -1 do
        local b = list[i]
        if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
            if b.enabled and b.fn then
                pcall(function() getSoundManager():playUISound("UISelectListItem") end)
                TWALog("Guided", "button %s (scene %s, recipe %s, step %s)", tostring(b.id), tostring(self.guidedScene),
                    tostring(self.selectedRecipe and self.selectedRecipe.id), tostring(self.selectedProcId))
                b.fn(self)
            end
            return true
        end
    end
    -- the guided craft view: nothing of the old page's drawn parts is live
    if self.page == "craft" and self.selectedRecipe and self:guidedOn() then return true end
    return false
end

-- ---------------------------------------------------------------- data (cached)
function TWACraftWindow:guidedData()
    local recipe = self.selectedRecipe
    local key = table.concat({ tostring(recipe and recipe.id), tostring(self.active and self.active.recipeId),
        tostring(self.resumeItem), tostring(self.activeProcId), tostring(self.activeCenterKind), tostring(self.practicing) }, "|")
    local c = self.guidedCache
    local t = now()
    if c and c.key == key and t - c.at < G.CACHE_MS then return c end
    c = { key = key, at = t, procs = {}, ready = 0, total = 0 }
    self.guidedCache = c
    if not recipe then return c end
    local S = TWACraftState
    local done = self:currentDone()
    local seenC, seenK = {}, {}
    c.consume, c.cond = {}, {}
    for _, pid in ipairs(recipe.procedures or {}) do
        local proc = TWAProcedures.List[pid]
        if proc then
            c.total = c.total + 1
            local ok, reqs = pcall(TWAProcedures.DescribeAll, proc, self.player)
            if not ok then TWALogOnce("guided_desc_" .. tostring(pid), "Guided", "DescribeAll failed for %s: %s", tostring(pid), tostring(reqs)); reqs = {} end
            local met = true
            for _, r in ipairs(reqs) do if not r.met then met = false break end end
            c.procs[pid] = { reqs = reqs, met = met }
            if met then c.ready = c.ready + 1 end
            -- what the steps still to do lack (the prepare checklist)
            if not done[pid] then
                for _, r in ipairs(reqs) do
                    if not r.met then
                        local line = self.procLibrary:describeOne(r)
                        local isUse = r.kind == "consume" or r.kind == "consume_options"
                        local seen = isUse and seenC or seenK
                        if line and not seen[line] then
                            seen[line] = true
                            local list = isUse and c.consume or c.cond
                            list[#list + 1] = line
                        end
                    end
                end
            end
        end
    end
    -- the start items (the same rules as the old base cards)
    if not self:isActiveRecipe() then
        local ok, can = pcall(self.canStart, self)
        c.canStart = ok and can and true or false
        local rows, missing = {}, {}
        if self.resumeItem then
            local it = self.resumeItem
            local here = S.findItem(self.player, it) ~= nil
            rows[#rows + 1] = { type = it:getFullType(), name = it:getDisplayName(), ok = here,
                status = getText(here and "IGUI_TWA_G_ResumePiece" or "IGUI_TWA_G_PieceGone") }
            if not here then missing[#missing + 1] = it:getDisplayName() end
        elseif recipe.base then
            local chosen = self:baseChoiceType(recipe)
            local typ = chosen or recipe.base
            local row = { type = typ, ok = chosen ~= nil }
            row.name = h().baseDisplayName(typ, (not chosen) and recipe.baseAlt or nil)
            row.count = row.ok and S.countBase(self.player, recipe, chosen) or nil
            row.status = row.ok and getText("IGUI_TWA_G_Have", tostring(row.count)) or getText("IGUI_TWA_G_Missing")
            if not row.ok and recipe.gemFrom then
                row.status = getText("IGUI_TWA_BaseNeedsState", getText("IGUI_TWA_GemState_" .. recipe.gemFrom))
            end
            if row.ok and #S.baseTypes(recipe) > 1 and #self:baseChoices(recipe) > 1 then
                row.btn = { id = "changeBase", icon = "redo", label = getText("IGUI_TWA_G_ChangeBase"), fn = function(win) win:openBaseChooser(recipe) end }
            elseif not row.ok then
                missing[#missing + 1] = row.name
                local maker = h().recipeMaking(typ)
                if maker and maker ~= recipe and not self.active then
                    row.btn = { id = "recipeOf", icon = "tool", label = getText("IGUI_TWA_G_RecipeOf"), tip = getText("IGUI_TWA_G_RecipeOf_Tip", row.name),
                        fn = function(win) win:jumpToRecipe(maker) end }
                end
            end
            rows[#rows + 1] = row
        else
            rows[#rows + 1] = { name = getText("IGUI_TWA_NoBaseItemNeeded"), ok = true, status = "" }
        end
        if recipe.base2 then
            local row = { type = recipe.base2, name = h().baseDisplayName(recipe.base2) }
            if self.resumeItem and S.carriedBase2(self.resumeItem, recipe) then
                row.ok, row.status = true, getText("IGUI_TWA_G_InPiece")
            else
                local n = TWASources.get(self.player):countEval(recipe.base2, function(it) return not S.isBookmarked(it) end)
                row.ok = S.pickFreshItem(self.player, recipe.base2) ~= nil
                row.count = row.ok and n or nil
                row.status = row.ok and getText("IGUI_TWA_G_Have", tostring(n)) or getText("IGUI_TWA_G_Missing")
                if not row.ok then
                    missing[#missing + 1] = row.name
                    local maker = h().recipeMaking(recipe.base2)
                    if maker and maker ~= recipe and not self.active and not self.resumeItem then
                        row.btn = { id = "recipeOf2", icon = "tool", label = getText("IGUI_TWA_G_RecipeOf"), tip = getText("IGUI_TWA_G_RecipeOf_Tip", row.name),
                            fn = function(win) win:jumpToRecipe(maker) end }
                    end
                end
            end
            rows[#rows + 1] = row
        end
        c.rows, c.missing = rows, missing
    end
    return c
end

-- ---------------------------------------------------------------- scene + next step
function TWACraftWindow:guidedSceneOf()
    if self.activeCenterAction then return "BUSY" end
    if self.practicing then return "PRACTICE" end
    if self.active and not self:isActiveRecipe() then return "LOCKED" end
    if self:isActiveRecipe() then
        if self.activeProcId then return "STEP_BUSY" end
        local done = self:currentDone()
        for _, pid in ipairs(self.selectedRecipe.procedures or {}) do
            if TWAProcedures.List[pid] and not done[pid] then return "WORK" end
        end
        return self.guidedImprove and "WORK" or "FINISH"
    end
    if self.resumeItem then return "PREPARE_RESUME" end
    return "PREPARE"
end

-- the step to show: the one running > the one the player picked > the first
-- not done that can be done now > the first not done (with its blockers).
-- The game has no fixed order, so neither does this.
function TWACraftWindow:guidedRecommend(data)
    local recipe = self.selectedRecipe
    if self.activeProcId then return self.activeProcId, "running" end
    local inRecipe = {}
    for _, pid in ipairs(recipe.procedures or {}) do inRecipe[pid] = true end
    local m = self.guidedManual
    if m and not inRecipe[m] then m = nil; self.guidedManual = nil end
    local res = self.lastProcResult
    if m and not self.guidedImprove and res and res.procId == m and res.word ~= "Miss" and res.at >= (self.guidedManualAt or 0) then
        self.guidedManual, m = nil, nil
    end
    if m then return m, self.guidedImprove and "improve" or "manual" end
    local done = self:currentDone()
    for _, pid in ipairs(recipe.procedures or {}) do
        local p = data.procs[pid]
        if p and not done[pid] and p.met then return pid, "ready" end
    end
    for _, pid in ipairs(recipe.procedures or {}) do
        if data.procs[pid] and not done[pid] then return pid, "blocked" end
    end
    return nil, "allDone"
end

-- the step with the lowest word (to redo for a better overall quality)
function TWACraftWindow:guidedLowest()
    local recipe = self.selectedRecipe
    local done, quality = self:currentDone(), self:currentQuality()
    local best, rank
    for _, pid in ipairs(recipe and recipe.procedures or {}) do
        local w = TWACraftState.wordFor(pid, done, quality)
        local r = WORD_RANK[w or "Miss"] or 0
        if TWAProcedures.List[pid] and (not rank or r < rank) then best, rank = pid, r end
    end
    return best
end

function TWACraftWindow:guidedPick(pid, improve)
    if self.activeProcId or self.activeCenterAction or self.practicing then return end
    self.guidedManual, self.guidedManualAt = pid, now()
    if improve ~= nil then self.guidedImprove = improve end
    self.selectedProcId = pid
    TWALog("Guided", "step picked: %s%s", tostring(pid), self.guidedImprove and " (redo for quality)" or "")
end

-- ---------------------------------------------------------------- drawing helpers
function TWACraftWindow:guidedBar(x, y, w, ht, frac)
    self:drawRect(x, y, w, ht, 0.9, 0.05, 0.05, 0.05)
    self:drawRect(x, y, math.floor(w * math.max(0, math.min(1, frac or 0))), ht, 1, 1, 0.7, 0.2)
    self:drawRectBorder(x, y, w, ht, 0.8, 0.5, 0.5, 0.5)
end

-- a word chip (Good / Miss ...) -> its width
function TWACraftWindow:guidedWordChip(word, x, y, tipText)
    if not word then return 0 end
    local wc = TWACraftState.WORD_COLOR[word] or { r = 1, g = 1, b = 1 }
    local s = TWACraftState.wordText(word)
    local w, ht = tw(s) + 12, fh() + 4
    self:drawRect(x, y, w, ht, 0.9, wc.r * 0.2, wc.g * 0.2, wc.b * 0.2)
    self:drawRectBorder(x, y, w, ht, 0.9, wc.r, wc.g, wc.b)
    text(self, s, x + 6, y + 2, { wc.r, wc.g, wc.b })
    if tipText then hover(self, tipText, x, y, w, ht) end
    return w
end

-- requirement lines: a tick or a warning glyph + what it is (one line each)
function TWACraftWindow:guidedReqLines(reqs, x, y, w, yMax)
    local lh = fh() + 4
    if #reqs == 0 then
        return line1(self, getText("IGUI_TWA_G_NoNeeds"), x, y, w, C.ok, "check")
    end
    for i, r in ipairs(reqs) do
        if y + lh > yMax then
            line1(self, getText("IGUI_TWA_G_MoreLines", tostring(#reqs - i + 1)), x, y - lh, w, C.dim)
            break
        end
        local s = tostring(self.procLibrary:describeOne(r))
        y = line1(self, s, x, y, w, r.met and C.text or C.bad, r.met and "check" or "warn", r.met and C.ok or C.bad)
    end
    return y
end

-- ---------------------------------------------------------------- scenes
-- each returns { banner = {state, text}, title, titleGlyph, titleTip,
--   primary = {label, fn, enabled, kind, tip, icon}, reason = text (one
--   visible line above the primary), info = { text } (on the primary's
--   hover), draw(win, x, y, w, yMax) }

function TWACraftWindow:guidedScenePrepare(data, resume)
    local recipe = self.selectedRecipe
    local name = h().recipeName(recipe)
    local sp = { info = {} }
    sp.title = getText(resume and "IGUI_TWA_G_ResumeTitle" or "IGUI_TWA_G_PrepareTitle", name)
    sp.titleGlyph = resume and "redo" or "box"
    if data.canStart then
        sp.banner = { "READY", getText(resume and "IGUI_TWA_G_B_Resume" or "IGUI_TWA_G_B_PrepareReady") }
        sp.primary = { id = "start", label = getText(resume and "IGUI_TWA_G_Resume" or "IGUI_TWA_G_Start", name), kind = "primary", icon = "play",
            tip = getText("IGUI_TWA_Tooltip_StartCraft"), fn = function(win) win:onStartButtonClicked() end }
    else
        sp.banner = { "MISSING", getText("IGUI_TWA_G_B_PrepareMissing") }
        sp.primary = { id = "showMissing", label = getText("IGUI_TWA_G_ShowMissing"), kind = "primary", icon = "warn",
            fn = function(win) win.guidedFlashUntil = now() + 3000 end }
        if #(data.missing or {}) > 0 then sp.reason = getText("IGUI_TWA_G_CantStart", table.concat(data.missing, ", ")) end
    end
    sp.info[#sp.info + 1] = getText("IGUI_TWA_G_StartCost")
    sp.info[#sp.info + 1] = getText("IGUI_TWA_G_MissCost")
    sp.draw = function(win, x, y, w, yMax)
        local lh = fh() + 4
        local gs = fh()
        local flash = (win.guidedFlashUntil or 0) > now() and TWABlink and TWABlink.level() or nil
        -- 1) the start items: picture, name, a tick / warning (+ how many)
        local hy = y
        glyph(win, "box", x, y, gs, C.accent)
        text(win, getText("IGUI_TWA_G_GroupStart"), x + gs + 6, y, C.accent)
        hover(win, getText("IGUI_TWA_G_GroupStart_Tip"), x, hy, w, lh)
        y = y + lh
        local rowH = math.max(sc(30), fh() + 12)
        for _, r in ipairs(data.rows or {}) do
            if y + rowH > yMax then break end
            win:drawRect(x, y, w, rowH, 0.8, 0.08, 0.07, 0.05)
            win:drawRectBorder(x, y, w, rowH, 0.5, 0.4, 0.33, 0.15)
            if flash and not r.ok then win:drawRectBorder(x - 1, y - 1, w + 2, rowH + 2, 0.4 + 0.6 * flash, 1, 0.45, 0.3) end
            local ix = x + 6
            local script = r.type and h().getItemScript(r.type)
            local icon = script and h().getItemTexture(script:getIcon())
            if icon then
                local s = rowH - 8
                win:drawTextureScaled(icon, ix, y + 4, s, s, r.ok and 1 or 0.5, 1, 1, 1)
                ix = ix + s + 6
            end
            local right = x + w - 4
            if r.btn then
                local bs = rowH - 8
                win:guidedButton(r.btn.id, "", right - bs, y + 4, bs, bs, { icon = r.btn.icon, fn = r.btn.fn, tip = r.btn.tip or r.btn.label })
                right = right - bs - 6
            end
            local sg = math.min(rowH - 10, sc(20))
            glyph(win, r.ok and "check" or "warn", right - sg, y + math.floor((rowH - sg) / 2), sg, r.ok and C.ok or C.bad, r.ok and "+" or "!")
            right = right - sg - 6
            if r.count then
                local cs = "x" .. tostring(r.count)
                text(win, cs, right - tw(cs), y + math.floor((rowH - fh()) / 2), C.dim)
                right = right - tw(cs) - 6
            end
            text(win, fit(r.name, right - ix - 4), ix, y + math.floor((rowH - fh()) / 2), C.text)
            hover(win, r.name .. (r.status and r.status ~= "" and (" - " .. r.status) or ""), x, y, right - x, rowH)
            y = y + rowH + 4
        end
        y = y + 4
        -- 2) materials the steps still need, 3) step conditions -- only what is missing
        local groups = { { "tool", "IGUI_TWA_G_GroupConsume", data.consume or {} }, { "flag", "IGUI_TWA_G_GroupCond", data.cond or {} } }
        for _, gr in ipairs(groups) do
            if y + lh > yMax then break end
            local missing = #gr[3]
            glyph(win, gr[1], x, y, gs, C.accent)
            text(win, getText(gr[2]), x + gs + 6, y, C.accent)
            local mark = missing == 0 and "check" or "warn"
            local lw2 = tw(getText(gr[2]))
            glyph(win, mark, x + gs + 6 + lw2 + 8, y, gs, missing == 0 and C.ok or C.bad)
            hover(win, getText(gr[2] .. "_Tip"), x, y, w, lh)
            y = y + lh
            for i, s in ipairs(gr[3]) do
                if i > 3 or y + lh > yMax then
                    line1(win, getText("IGUI_TWA_G_MoreLines", tostring(missing - i + 1)), x + gs, y, w - gs, C.dim)
                    y = y + lh
                    break
                end
                y = line1(win, s, x + gs, y, w - gs, C.bad, "warn", C.bad)
            end
            y = y + 2
        end
        if y + lh <= yMax then
            local s = tostring(data.ready) .. " / " .. tostring(data.total)
            glyph(win, "play", x, y, gs, data.ready == data.total and C.ok or C.warn)
            text(win, s, x + gs + 6, y, data.ready == data.total and C.ok or C.warn)
            hover(win, getText("IGUI_TWA_G_StepsReady", tostring(data.ready), tostring(data.total)), x, y, w, lh)
        end
    end
    return sp
end

-- the last step's result -> text, colour, glyph
function TWACraftWindow:guidedResultLine()
    local recipe = self.selectedRecipe
    local res, stop = self.lastProcResult, self.lastProcStopped
    local t = now()
    local latest
    if res and res.recipeId == recipe.id and t - res.at < G.RESULT_MS then latest = res end
    if stop and stop.recipeId == recipe.id and t - stop.at < G.RESULT_MS and (not latest or stop.at > latest.at) then
        return getText("IGUI_TWA_G_ResultStopped", procName(stop.procId)), C.warn, "busy"
    end
    if not latest then return nil end
    if latest.word == "Miss" then return getText("IGUI_TWA_G_ResultMiss", procName(latest.procId)), C.bad, "cross" end
    local done = self:currentDone()
    local nextPid
    for _, pid in ipairs(recipe.procedures or {}) do
        if TWAProcedures.List[pid] and not done[pid] then nextPid = pid break end
    end
    local word = TWACraftState.wordText(latest.word)
    if nextPid then return getText("IGUI_TWA_G_ResultGood", procName(latest.procId), word, procName(nextPid)), C.ok, "check" end
    return getText("IGUI_TWA_G_ResultGoodLast", procName(latest.procId), word), C.ok, "check"
end

local TITLE_GLYPH = { manual = "target", improve = "redo", blocked = "warn", ready = "play" }
function TWACraftWindow:guidedSceneWork(data, pid, why)
    local sp = { info = {} }
    local name = procName(pid)
    local p = data.procs[pid] or { reqs = {}, met = false }
    local done, quality = self:currentDone(), self:currentQuality()
    local isDone = done[pid] and true or false
    local key = ({ manual = "IGUI_TWA_G_WorkTitleManual", improve = "IGUI_TWA_G_WorkTitleImprove", blocked = "IGUI_TWA_G_WorkTitleBlocked" })[why] or "IGUI_TWA_G_WorkTitleRec"
    sp.title, sp.titleGlyph, sp.titleTip = name, TITLE_GLYPH[why] or "play", getText(key, name)
    sp.banner = why == "blocked" and { "MISSING", getText("IGUI_TWA_G_B_WorkBlocked") } or { "IN_PROGRESS", getText("IGUI_TWA_G_B_Work") }
    if p.met then
        sp.primary = { id = "doStep", label = getText(isDone and "IGUI_TWA_G_RedoStep" or "IGUI_TWA_G_DoStep", name), kind = "primary",
            icon = isDone and "redo" or "play", tip = getText("IGUI_TWA_Tooltip_ConfirmProcedure"),
            fn = function(win) win.selectedProcId = pid; win:onConfirmProcedure() end }
    else
        sp.primary = { id = "cantStep", label = getText("IGUI_TWA_G_CantStep"), enabled = false, icon = "lock" }
        local first
        for _, r in ipairs(p.reqs) do if not r.met then first = self.procLibrary:describeOne(r) break end end
        sp.reason = getText("IGUI_TWA_G_CantStepWhy", name, tostring(first or "?"))
        for _, q in ipairs(self.selectedRecipe.procedures or {}) do
            if q ~= pid and not done[q] and data.procs[q] and data.procs[q].met then sp.info[#sp.info + 1] = getText("IGUI_TWA_G_PickOther") break end
        end
    end
    sp.info[#sp.info + 1] = getText("IGUI_TWA_G_MissNote")
    sp.draw = function(win, x, y, w, yMax)
        local lh = fh() + 4
        -- last result of this step: a word chip (or "not done yet" as a dim dash)
        local word = TWACraftState.wordFor(pid, done, quality)
        if word then
            win:guidedWordChip(word, x, y, getText("IGUI_TWA_G_LastWord", TWACraftState.wordText(word)))
        else
            text(win, "-", x, y, C.dim)
            hover(win, getText("IGUI_TWA_G_NotDoneYet"), x, y, tw("-") + 20, lh)
        end
        -- the last result, one line (all of it on hover)
        local rl, rc, rg = win:guidedResultLine()
        if rl then
            local cx = x + sc(70)
            line1(win, rl, cx, y + 2, w - (cx - x), rc, rg, rc)
        end
        if win.practiceWord and win.practiceProc == pid and now() < (win.practiceUntil or 0) then
            local pc = TWACraftState.WORD_COLOR[win.practiceWord] or { r = 1, g = 1, b = 1 }
            y = y + lh
            line1(win, getText("IGUI_TWA_PracticeResult", TWACraftState.wordText(win.practiceWord)), x, y, w, { pc.r, pc.g, pc.b }, "target", { pc.r, pc.g, pc.b })
        end
        y = y + lh + 4
        -- secondary actions: small icon buttons at the bottom of the area
        local sec = {}
        if TWACraftState.hasTried(win.player, pid) and TWAMinigame and TWAMinigame.enabled and TWAMinigame.enabled() then
            sec[#sec + 1] = { id = "practice", icon = "target", tip = getText("IGUI_TWA_G_Practice") .. "\n" .. getText("IGUI_TWA_Tooltip_Practice"),
                fn = function(w2) w2.selectedProcId = pid; w2:onPracticeProcedure() end }
        end
        if win.guidedImprove then
            sec[#sec + 1] = { id = "backToFinish", icon = "flag", tip = getText("IGUI_TWA_G_BackToFinish"),
                fn = function(w2) w2.guidedImprove, w2.guidedManual = nil, nil end }
        end
        local bs = sc(28)
        local reqMax = #sec > 0 and (yMax - bs - 6) or yMax
        win:guidedReqLines(p.reqs, x, y, w, reqMax)
        for i, b in ipairs(sec) do
            win:guidedButton(b.id, "", x + (i - 1) * (bs + 6), yMax - bs, bs, bs, { icon = b.icon, fn = b.fn, tip = b.tip })
        end
    end
    return sp
end

function TWACraftWindow:guidedSceneStepBusy(data)
    local pid = self.activeProcId
    local sp = { info = {} }
    sp.title, sp.titleGlyph, sp.titleTip = procName(pid), "busy", getText("IGUI_TWA_G_WorkTitleRec", procName(pid))
    sp.banner = { "IN_PROGRESS", getText("IGUI_TWA_G_B_StepBusy") }
    if self.activeAction then
        sp.primary = { id = "stopStep", label = getText("IGUI_TWA_G_StopStep"), kind = "danger", icon = "cross",
            tip = getText("IGUI_TWA_Tooltip_CancelProcedure"),
            fn = function(win) win.selectedProcId = win.activeProcId; win:onConfirmProcedure() end }
        sp.info[#sp.info + 1] = getText("IGUI_TWA_G_StopStepNote")
    else
        sp.primary = { id = "minigame", label = getText("IGUI_TWA_G_Minigame"), enabled = false, icon = "busy" }
    end
    sp.draw = function(win, x, y, w, yMax)
        if win.activeAction then
            win:guidedBar(x, y, w, sc(14), TWACraftWindow.jobDelta(win.activeAction))
            y = y + sc(14) + 8
        end
        local p = data.procs[pid]
        if p then win:guidedReqLines(p.reqs, x, y, w, yMax) end
    end
    return sp
end

function TWACraftWindow:guidedScenePractice()
    local pid = self.activeProcId or self.selectedProcId
    local sp = { info = {} }
    sp.title, sp.titleGlyph, sp.titleTip = procName(pid), "target", getText("IGUI_TWA_G_Practicing", procName(pid))
    sp.banner = { "INFO_ONLY", getText("IGUI_TWA_G_B_Practice") }
    sp.primary = { id = "stopPractice", label = getText("IGUI_TWA_G_StopPractice"), kind = "danger", icon = "cross",
        enabled = self.activeAction ~= nil, fn = function(win) win:onPracticeProcedure() end }
    sp.draw = function(win, x, y, w, yMax)
        if win.activeAction then win:guidedBar(x, y, w, sc(14), TWACraftWindow.jobDelta(win.activeAction)) end
    end
    return sp
end

function TWACraftWindow:guidedSceneFinish(data)
    local recipe = self.selectedRecipe
    local S = TWACraftState
    local map = self:currentMap()
    local ok = S.canFinish(recipe, map, self.player)
    local oWord = S.overall(recipe, map, self.player)
    local sp = { info = {} }
    sp.title, sp.titleGlyph = getText("IGUI_TWA_G_FinishTitle"), "flag"
    local rule
    if S.isMaterialRecipe(recipe) then rule = getText("IGUI_TWA_MaterialFinishRule")
    elseif recipe.roll then rule = getText("IGUI_TWA_GemFinishRule", tostring(S.gemChance("Excellent")), tostring(S.gemChance("Good")), tostring(S.gemChance("Bad")))
    elseif recipe.keepType then
        rule = getText("IGUI_TWA_GemRefineRule", getText("IGUI_TWA_GemState_" .. (recipe.gemFrom or "Raw")),
            tostring(S.gemBreakChance("Bad")), tostring(S.gemBreakChance("Good")), tostring(S.gemBreakChance("Excellent")))
    else rule = getText("IGUI_TWA_G_GradeNote") end
    sp.info[#sp.info + 1] = rule
    if ok then
        sp.banner = { "COMPLETE", getText("IGUI_TWA_G_B_Finish") }
        sp.primary = { id = "finish", label = getText("IGUI_TWA_G_Finish"), kind = "primary", icon = "check",
            tip = getText("IGUI_TWA_Tooltip_Finish"), fn = function(win) win:onFinishButtonClicked() end }
    else
        sp.banner = { "MISSING", getText("IGUI_TWA_G_B_FinishBlocked") }
        sp.reason = getText("IGUI_TWA_G_FinishNo")
        sp.primary = { id = "showImprove", label = getText("IGUI_TWA_G_ShowImprove"), kind = "primary", icon = "redo",
            fn = function(win) win:guidedPick(win:guidedLowest(), true) end }
    end
    sp.draw = function(win, x, y, w, yMax)
        local lh = fh() + 4
        if oWord then
            local cw = win:guidedWordChip(oWord, x, y, getText("IGUI_TWA_G_Overall", S.wordText(oWord)))
            glyph(win, ok and "check" or "warn", x + cw + 8, y + 2, fh(), ok and C.ok or C.bad)
            hover(win, getText(ok and "IGUI_TWA_G_FinishOk" or "IGUI_TWA_G_FinishNo"), x + cw + 4, y, fh() + 8, lh)
            y = y + lh + 4
        end
        local gs = fh()
        glyph(win, "info", x, y, gs, C.info)
        hover(win, rule, x, y, gs + 4, lh)
        if ok then
            local bs = sc(28)
            win:guidedButton("improve", "", x, yMax - bs, bs, bs, { icon = "redo", tip = getText("IGUI_TWA_G_Improve"),
                fn = function(w2) w2:guidedPick(w2:guidedLowest(), true) end })
        end
    end
    return sp
end

function TWACraftWindow:guidedSceneBusy()
    local kind = self.activeCenterKind or "finish"
    local sp = { info = { getText("IGUI_TWA_G_StopNote") } }
    sp.title, sp.titleGlyph = getText("IGUI_TWA_G_Busy_" .. kind), "busy"
    sp.banner = { "IN_PROGRESS", getText("IGUI_TWA_G_B_Busy") }
    sp.primary = { id = "abort", label = getText("IGUI_TWA_G_Stop"), kind = "danger", icon = "cross", tip = getText("IGUI_TWA_Tooltip_AbortAction"),
        fn = function(win) win:onAbortCenterAction() end }
    sp.draw = function(win, x, y, w, yMax)
        win:guidedBar(x, y, w, sc(16), TWACraftWindow.jobDelta(win.activeCenterAction))
    end
    return sp
end

function TWACraftWindow:guidedSceneLocked()
    local r = TWACraftUI.getRecipeById(self.active.recipeId)
    local name = r and h().recipeName(r) or "?"
    local sp = { info = { getText("IGUI_TWA_G_LockedBody") } }
    sp.title, sp.titleGlyph, sp.titleTip = name, "lock", getText("IGUI_TWA_G_LockedTitle", name)
    sp.banner = { "LOCKED", getText("IGUI_TWA_G_B_Locked") }
    sp.primary = { id = "backToActive", label = getText("IGUI_TWA_G_BackToActive", name), kind = "primary", icon = "back",
        fn = function(win) win:onContinueClicked() end }
    return sp
end

-- ---------------------------------------------------------------- the step list (right)
-- each row: number, picture, name, a status glyph (+ the word when done);
-- what the status means is on hover
function TWACraftWindow:guidedDrawSteps(g, data, rec, why)
    local recipe = self.selectedRecipe
    local pids = {}
    for _, pid in ipairs(recipe.procedures or {}) do
        if TWAProcedures.List[pid] then pids[#pids + 1] = pid end
    end
    local n = #pids
    if n == 0 then return end
    local x, w = g.rx, g.rw
    local avail = g.bottom - g.top
    local gap = 4
    local rowH = math.floor((avail - (n - 1) * gap) / n)
    rowH = math.max(fh() + 8, math.min(sc(42), rowH))
    local done, quality = self:currentDone(), self:currentQuality()
    local active = self:isActiveRecipe()
    local clickable = active and not self.activeProcId and not self.activeCenterAction and not self.practicing
    local allDone = true
    for _, pid in ipairs(pids) do if not done[pid] then allDone = false end end
    local y = g.top
    clip(self, x - 2, g.top - 2, w + 4, avail + 4)
    for i, pid in ipairs(pids) do
        if y + rowH > g.bottom then break end
        local proc = TWAProcedures.List[pid]
        local p = data.procs[pid]
        local word = TWACraftState.wordFor(pid, done, quality)
        local isRec = active and pid == rec
        local status, col, gname
        if self.activeProcId == pid and not self.practicing then status, col, gname = getText("IGUI_TWA_G_St_Running"), C.warn, "busy"
        elseif word == "Miss" then status, col, gname = getText("IGUI_TWA_G_St_Miss"), C.bad, "cross"
        elseif done[pid] then status, col, gname = getText("IGUI_TWA_G_St_Done", TWACraftState.wordText(word or "Good")), C.ok, "check"
        elseif isRec then status, col, gname = getText(why == "manual" and "IGUI_TWA_G_St_Picked" or "IGUI_TWA_G_St_Rec"), C.accent, "play"
        elseif p and not p.met then status, col, gname = getText("IGUI_TWA_G_St_Blocked"), C.bad, "warn"
        else status, col, gname = getText("IGUI_TWA_G_St_Todo"), C.dim, nil end
        if isRec and done[pid] then status = status .. " - " .. getText("IGUI_TWA_G_St_Picked") end
        local mx, my = self:getMouseX(), self:getMouseY()
        local over = mx >= x and mx < x + w and my >= y and my < y + rowH
        self:drawRect(x, y, w, rowH, 0.85, isRec and 0.22 or (over and clickable and 0.14 or 0.08), isRec and 0.15 or (over and clickable and 0.11 or 0.07), isRec and 0.04 or 0.05)
        if isRec then
            local a = TWABlink and TWABlink.level and (0.55 + 0.45 * TWABlink.level()) or 1
            self:drawRectBorder(x, y, w, rowH, a, C.accent[1], C.accent[2], C.accent[3])
        else
            self:drawRectBorder(x, y, w, rowH, 0.5, 0.4, 0.33, 0.15)
        end
        local is = math.min(rowH - 6, sc(30))
        local ix = x + 4
        text(self, tostring(i), ix, y + math.floor((rowH - fh()) / 2), C.dim)
        ix = ix + tw("00") + 2
        local tex = self.procLibrary:getProcTexture(proc)
        if tex then
            local tint = done[pid] and 1 or 0.55
            self:drawTextureScaled(tex, ix, y + math.floor((rowH - is) / 2), is, is, 1, tint, tint, tint)
        end
        local right = x + w - 6
        local gs = math.min(rowH - 8, sc(18))
        if gname then glyph(self, gname, right - gs, y + math.floor((rowH - gs) / 2), gs, col) end
        right = right - gs - 6
        if done[pid] and word then
            local ws = TWACraftState.wordText(word)
            local wc = TWACraftState.WORD_COLOR[word] or { r = 1, g = 1, b = 1 }
            text(self, ws, right - tw(ws), y + math.floor((rowH - fh()) / 2), { wc.r, wc.g, wc.b })
            right = right - tw(ws) - 6
        end
        local tx = ix + is + 6
        text(self, fit(getText(proc.nameKey), right - tx), tx, y + math.floor((rowH - fh()) / 2), C.text)
        local tipText = getText(proc.nameKey) .. ": " .. status
        if clickable then
            tipText = tipText .. "\n" .. getText("IGUI_TWA_G_StepTip")
            self.guidedHits = self.guidedHits or {}
            self.guidedHits[#self.guidedHits + 1] = { id = "step:" .. tostring(pid), x = x, y = y, w = w, h = rowH, enabled = true,
                fn = function(win) win:guidedPick(pid, allDone or nil) end }
        end
        hover(self, tipText, x, y, w, rowH)
        y = y + rowH + gap
    end
    unclip(self)
end

-- wrapped paragraph -> new y (stops at yMax); the manage menu uses it
function TWACraftWindow:guidedPara(s, x, y, w, col, f, yMax, maxLines)
    f = f or small()
    local lh = fh(f) + 2
    for _, l in ipairs(wrap(s, w, f, maxLines or 4)) do
        if yMax and y + lh > yMax then break end
        text(self, l, x, y, col, f)
        y = y + lh
    end
    return y
end

-- ---------------------------------------------------------------- manage menu (modal)
function TWACraftWindow:guidedDrawMenu(g)
    self.guidedHits = {}
    local x, w = g.lx, g.lw
    local y0, y1 = g.top, g.bottom
    self:drawRect(x - 4, y0 - 4, w + 8, y1 - y0 + 8, 0.97, 0.04, 0.032, 0.014)
    self:drawRectBorder(x - 4, y0 - 4, w + 8, y1 - y0 + 8, 1, C.accent[1], C.accent[2], C.accent[3])
    local lh = fh() + 2
    local r = self.selectedRecipe
    local y = y0 + 6
    local bh = sc(30)
    local idle = self:isActiveRecipe() and not self.activeProcId and not self.activeCenterAction and not self.practicing
    if self.guidedMenu == "confirm" then
        text(self, getText("IGUI_TWA_G_ConfirmTitle"), x + 6, y, C.bad, medium()); y = y + fh(medium()) + 8
        for _, k in ipairs({ "IGUI_TWA_G_Confirm1", "IGUI_TWA_G_Confirm2", "IGUI_TWA_G_Confirm3" }) do
            y = self:guidedPara(getText(k), x + 10, y, w - 20, C.text, small(), y1 - 2 * bh - 20)
        end
        local by = y1 - bh - 6
        local bw = math.floor((w - 20) / 2)
        self:guidedButton("cancelYes", getText("IGUI_TWA_G_ConfirmYes"), x + 6, by, bw, bh, { kind = "danger", enabled = idle,
            fn = function(win) win.guidedMenu = nil; win:onCancelButtonClicked() end })
        self:guidedButton("cancelNo", getText("IGUI_TWA_G_ConfirmNo"), x + 14 + bw, by, bw, bh,
            { fn = function(win) win.guidedMenu = "menu" end })
        return
    end
    text(self, getText("IGUI_TWA_G_MenuTitle", r and h().recipeName(r) or "?"), x + 6, y, C.accent, medium())
    y = y + fh(medium()) + 8
    -- 1.0.7: short buttons with a glyph; what each one does is on hover
    local opts = {
        { id = "pause", key = "IGUI_TWA_G_MenuPause", desc = "IGUI_TWA_G_MenuPauseDesc", enabled = self:canGoIncomplete(), icon = "flag",
            fn = function(win) win.guidedMenu = nil; win:onIncompleteButtonClicked() end },
        { id = "cancelAll", key = "IGUI_TWA_G_MenuCancel", desc = "IGUI_TWA_G_MenuCancelDesc", enabled = idle, kind = "danger", icon = "cross",
            fn = function(win) win.guidedMenu = "confirm" end },
        { id = "menuBack", key = "IGUI_TWA_G_MenuBack", icon = "back", fn = function(win) win.guidedMenu = nil end },
    }
    for _, o in ipairs(opts) do
        if y + bh > y1 - lh * 2 then break end
        local tip = o.desc and getText(o.desc) or nil
        if o.enabled == false then tip = (tip and (tip .. "\n") or "") .. getText("IGUI_TWA_G_MenuDisabled") end
        self:guidedButton(o.id, getText(o.key), x + 6, y, w - 12, bh, { fn = o.fn, enabled = o.enabled ~= false, kind = o.kind,
            icon = o.icon, tip = tip, info = tip ~= nil })
        y = y + bh + 6
    end
    local gs = fh()
    glyph(self, "info", x + 6, y1 - gs - 6, gs, C.info)
    hover(self, getText("IGUI_TWA_G_MenuCloseNote"), x + 6, y1 - gs - 6, gs + 4, gs + 4)
end

-- ---------------------------------------------------------------- the page
function TWACraftWindow:renderGuided()
    local recipe = self.selectedRecipe
    if not recipe then return false end
    self:guidedHideOld()
    self.guidedHits = {}
    if not self.active then self.guidedImprove, self.guidedMenu = nil, nil end
    if self.guidedMenu and not self:isActiveRecipe() then self.guidedMenu = nil end
    local data = self:guidedData()
    local scene = self:guidedSceneOf()
    local rec, why
    if self:isActiveRecipe() then rec, why = self:guidedRecommend(data) end
    -- the old view and the handlers read selectedProcId: keep it on the step shown
    if rec and not self.activeProcId and not self.practicing then self.selectedProcId = rec end
    local logKey = scene .. "|" .. tostring(rec) .. "|" .. tostring(why)
    if logKey ~= self.guidedLogKey then
        self.guidedLogKey = logKey
        TWALog("Guided", "%s: scene %s, step %s (%s), ready %d/%d", tostring(recipe.id), scene, tostring(rec), tostring(why), data.ready or 0, data.total or 0)
    end
    self.guidedScene = scene

    local sp
    if scene == "BUSY" then sp = self:guidedSceneBusy()
    elseif scene == "PRACTICE" then sp = self:guidedScenePractice()
    elseif scene == "LOCKED" then sp = self:guidedSceneLocked()
    elseif scene == "STEP_BUSY" then sp = self:guidedSceneStepBusy(data)
    elseif scene == "WORK" and rec then sp = self:guidedSceneWork(data, rec, why)
    elseif scene == "WORK" or scene == "FINISH" then sp = self:guidedSceneFinish(data)
    else sp = self:guidedScenePrepare(data, scene == "PREPARE_RESUME") end

    local g = self:guidedGeom()
    local x, w = g.lx, g.lw
    local y = g.top
    local lh = fh() + 4
    clip(self, x - 2, g.top - 2, w + 4, g.bottom - g.top + 4)
    -- header: picture, name; tier + progress as a bar (numbers on hover)
    local ic = sc(40)
    local stats = h().recipeStats(recipe)
    local tier = stats and stats.tier and h().TIER_INFO[stats.tier]
    self:drawRect(x, y, ic, ic, 0.6, 0, 0, 0)
    local icon = h().recipeIcon(recipe)
    if icon then self:drawTextureScaled(icon, x, y, ic, ic, 1, 1, 1, 1) end
    if tier then self:drawRectBorder(x, y, ic, ic, 1, tier.r, tier.g, tier.b) else self:drawRectBorder(x, y, ic, ic, 0.6, 0.5, 0.5, 0.5) end
    local hx = x + ic + 10
    local nm = h().recipeName(recipe)
    text(self, fit(nm, x + w - hx, medium()), hx, y, tier and { tier.r, tier.g, tier.b } or C.text, medium())
    local total, doneN = 0, 0
    local done = self:currentDone()
    for _, pid in ipairs(recipe.procedures or {}) do
        if TWAProcedures.List[pid] then total = total + 1; if done[pid] then doneN = doneN + 1 end end
    end
    local sub
    if self:isActiveRecipe() then sub = getText("IGUI_TWA_G_Progress", tostring(doneN), tostring(total))
    elseif self.resumeItem then sub = getText("IGUI_TWA_G_PreviewProgress", tostring(doneN), tostring(total))
    else sub = getText("IGUI_TWA_G_NotStarted") end
    if tier then sub = tier.name .. " - " .. sub end
    local by0 = y + fh(medium()) + 6
    if self:isActiveRecipe() or self.resumeItem then
        local ns = tostring(doneN) .. "/" .. tostring(total)
        local bw = x + w - hx - tw(ns) - 8
        self:guidedBar(hx, by0 + 2, bw, sc(8), total > 0 and doneN / total or 0)
        text(self, ns, hx + bw + 6, by0 - 2, C.dim)
    end
    hover(self, nm .. "\n" .. sub, x, y, w, ic)
    y = y + ic + sc(8)
    -- next-step banner: one line (the hub's; all of it on hover)
    local BN = HARMONIE_Banner
    if BN and BN.draw and sp.banner then
        y = y + BN.draw(self, x, y, w, sp.banner[1], sp.banner[2], small())
    end
    -- the focus: one line with a glyph (what it means on hover)
    if sp.title then
        local gs = fh(medium())
        local tx = x
        if sp.titleGlyph then glyph(self, sp.titleGlyph, x, y, gs, C.accent); tx = x + gs + 8 end
        text(self, fit(sp.title, x + w - tx, medium()), tx, y, C.accent, medium())
        if sp.titleTip then hover(self, sp.titleTip, x, y, w, gs + 2) end
        y = y + gs + 8
    end
    -- primary button (bottom); the reason it is off on ONE line above it;
    -- everything else to read is on the button's hover (the small "i")
    local pbH = sc(36)
    local pbY = g.bottom - pbH - 2
    local ny = pbY - 4
    if sp.reason then
        ny = pbY - lh - 2
        line1(self, sp.reason, x, ny, w, C.bad, "warn", C.bad)
        ny = ny - 2
    end
    if sp.primary then
        local p = sp.primary
        local tip = p.tip
        local info = sp.info or {}
        if #info > 0 then tip = (tip and (tip .. "\n") or "") .. table.concat(info, "\n") end
        if not tip and p.enabled == false and sp.reason then tip = sp.reason end
        self:guidedButton(p.id, p.label, x, pbY, w, pbH, { kind = p.kind or "primary", enabled = p.enabled ~= false, fn = p.fn,
            tip = tip, font = medium(), icon = p.icon, info = #info > 0 })
    end
    unclip(self)
    -- the scene's own content between the title and the reason line, clipped
    if sp.draw then
        clip(self, x - 2, y - 2, w + 4, ny - y)
        sp.draw(self, x, y, w, ny - 4)
        unclip(self)
    end
    -- step list
    self:guidedDrawSteps(g, data, rec, why)
    -- bottom bar (under the cards): icons only, what each does on hover
    local by, bs = g.bottom + 10, sc(28)
    self:guidedButton("back", "", 10, by, bs, bs, { icon = "back", tip = getText("IGUI_TWA_BackToRecipes"),
        fn = function(win) win:onBackClicked() end })
    if self:isActiveRecipe() then
        local idle = not self.activeProcId and not self.activeCenterAction and not self.practicing
        self:guidedButton("manage", "", 10 + bs + 8, by, bs, bs, { icon = "menu", enabled = idle,
            tip = getText("IGUI_TWA_G_Manage") .. "\n" .. getText("IGUI_TWA_G_Manage_Tip"), fn = function(win) win.guidedMenu = "menu" end })
    end
    self:drawGuidedModeToggle(true)
    if self.guidedMenu then self:guidedDrawMenu(g) end
    return true
end

-- the view switch, bottom right of the craft page (both views): a glyph
function TWACraftWindow:drawGuidedModeToggle(guided)
    local bs = sc(28)
    local x = self.width - 10 - bs
    local y = self.panelBottom + 10
    self:guidedButton(guided and "toAdvanced" or "toGuided", "", x, y, bs, bs, {
        icon = "mode",
        tip = getText(guided and "IGUI_TWA_G_ModeAdvanced" or "IGUI_TWA_G_ModeGuided") .. "\n" ..
            getText(guided and "IGUI_TWA_G_ModeAdvanced_Tip" or "IGUI_TWA_G_ModeGuided_Tip"),
        fn = function(win) win:setGuided(not guided) end })
end

-- tab 1 with no recipe (guided): the two big buttons stay, the banner says
-- what to do, and continue / back to the craft under way when there is one
function TWACraftWindow:renderGuidedChoose()
    self.guidedHits = {}
    local w = math.min(self.width - 40, sc(560))
    local x = math.floor((self.width - w) / 2)
    local BN = HARMONIE_Banner
    if BN and BN.draw then BN.draw(self, x, self.contentTop, w, "INFO_ONLY", getText("IGUI_TWA_G_B_Choose"), small()) end
    local y = self.craftGoMaterials.y + self.craftGoMaterials.height + sc(20)
    local bw, bh = self.craftGoMaterials.width, self.craftGoMaterials.height
    local bx = self.craftGoMaterials.x
    if self.active then
        local r = TWACraftUI.getRecipeById(self.active.recipeId)
        self:guidedButton("chooseBackToActive", getText("IGUI_TWA_G_BackToActive", r and h().recipeName(r) or "?"), bx, y, bw, bh,
            { kind = "primary", icon = "back", fn = function(win) win:onContinueClicked() end })
    elseif self.incompleteList and #self.incompleteList > 0 and not self.activeProcId and not self.activeCenterAction then
        self:guidedButton("chooseContinue", getText("IGUI_TWA_ContinueCraft", tostring(#self.incompleteList)), bx, y, bw, bh,
            { icon = "redo", tip = getText("IGUI_TWA_Tooltip_ContinueCraft"), fn = function(win) win:onContinueClicked() end })
    end
end

TWALog("Guided", "guided craft mode loaded (cache %d ms)", G.CACHE_MS)

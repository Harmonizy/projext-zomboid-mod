--[[
    HARMONIE - From Garden to Plate: the dish score inside vanilla's own UI
    (GTP 1.6.0, review round 5).

      #30 right-click "Prepare Soup >" (vanilla evolved-recipe menu): each
          ingredient with a score gets a tag, e.g. "Carrots (5) [+2.0]"
      #31 the game's crafting window: the time line also shows the score the
          result will get from the prepared ingredients chosen
      #32 right-click a food -> "Prepare (Garden to Plate) >" its minigames
          (opens the Cooking tab and starts it), or "wash off and redo"
      #23 a moodle while a dish buff is on (level 1-3, kind and time left)

    Display only: nothing here writes a score (HARMONIE_Prep.lua does that on
    the server). Every hook is pcall-guarded and logged once when it fails.
]]--

require "HARMONIEGardenToPlate/HARMONIE_Prep"
require "HARMONIEGardenToPlate/HARMONIE_CookCore"

local R = HARMONIE_GTP.Prep
local K = HARMONIE_GTP.Cook
local log, logOnce = R.log, R.logOnce

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
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end

-- a short score tag for an item, or nil when it has none
local function scoreTag(it)
    if not it or not R.isFood(it) then return nil end
    if R.dishOf(it) or R.prepOf(it) then
        return T("IGUI_GTPP_MenuTag", string.format("%+.1f", R.scoreOf(it)))
    end
    return nil
end

-- ------------------------------------------------------------ #30 evolved-recipe menu
local function hookEvoMenu()
    local M = ISInventoryPaneContextMenu
    if not (M and M.addItemInEvoRecipe) or M.gtpScoreTagged then return end
    M.gtpScoreTagged = true
    local orig = M.addItemInEvoRecipe
    M.addItemInEvoRecipe = function(subMenu, baseItem, evoItem, extraInfo, evorecipe, player, ...)
        local r = orig(subMenu, baseItem, evoItem, extraInfo, evorecipe, player, ...)
        local ok, err = pcall(function()
            local tag = scoreTag(evoItem)
            if not tag or not subMenu or not subMenu.options then return end
            local n = subMenu.numOptions and (subMenu.numOptions - 1) or #subMenu.options
            local opt = subMenu.options[n]
            -- only the option vanilla just added for this very item
            if opt and opt.param2 == evoItem and type(opt.name) == "string" then opt.name = opt.name .. " " .. tag end
        end)
        if not ok then logOnce("evotag", "score tag in the right-click recipe menu FAILED: %s", tostring(err)) end
        return r
    end
    log("right-click recipe menu shows ingredient scores")
end

-- ------------------------------------------------------------ #31 crafting window
-- the score the result would get from the inputs chosen (same rule as R.onCraft)
local function craftPreview(logic)
    local data = logic and logic:getRecipeData()
    local items = data and data:getAllInputItems()
    if not items then return nil end
    local sum, w, any = 0, 0, false
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if R.counts(it) then
            local iw = R.weightOf(it)
            w = w + iw
            sum = sum + R.scoreOf(it) * iw
            if R.dishOf(it) or R.prepOf(it) then any = true end
        end
    end
    if not any or w <= 0 then return nil end
    return sum / w
end

local function hookCraftWindow()
    local C = ISWidgetHandCraftControl
    if not (C and C.prerender) or C.gtpScoreShown then return end
    C.gtpScoreShown = true
    local orig = C.prerender
    function C:prerender(...)
        local r = orig(self, ...)
        local ok, err = pcall(function()
            if not (self.durationLabel and self.logic) then return end
            local t = nowMs()
            if not self.gtpScoreAt or t - self.gtpScoreAt > 500 then
                self.gtpScoreAt = t
                self.gtpScore = craftPreview(self.logic)
            end
            if self.gtpScore then
                local base = self.durationLabel.name or ""
                self.durationLabel:setName(base .. "   " .. T("IGUI_GTPP_CraftScore", string.format("%.2f", self.gtpScore)))
            end
        end)
        if not ok then logOnce("craftscore", "score in the crafting window FAILED: %s", tostring(err)) end
        return r
    end
    log("crafting window shows the score from prepared ingredients")
end

-- ------------------------------------------------------------ #32 right-click a food
local function firstItem(items)
    local it = items and items[1]
    if type(it) == "table" and it.items then it = it.items[1] end
    return it
end

local function openAndRun(player, fn)
    if not (GTPGuide and GTPGuide.open) then return end
    GTPGuide.open(player, nil, "cook")
    local win = GTPGuide.window
    if not win then return end
    win.cookPage = "prep"
    fn(win)
end

local function onInventoryMenu(playerNum, context, items)
    local player = getSpecificPlayer and getSpecificPlayer(playerNum)
    local it = firstItem(items)
    if not player or not it or not R.isFood(it) then return end
    if R.canRedo(it) then
        context:addOption(T("IGUI_GTPP_MenuRedo"), player, function(p)
            log("right-click: wash off %s", tostring(call(it, "getFullType")))
            openAndRun(p, function(win)
                win.prepSel, win.prepRedoSel, win.prepSelKey = it, true, nil
                if win.startRedo then win:startRedo(it) end
            end)
        end)
        return
    end
    if R.whyNot(it) ~= nil then return end
    local games = R.gamesFor(it)
    if #games == 0 then return end
    local parent = context:addOption(T("IGUI_GTPP_MenuPrepare"), nil, nil)
    local sub = context:getNew(context)
    context:addSubMenu(parent, sub)
    local scan = K.scan and K.scan(player)
    for _, pid in ipairs(games) do
        local proc = K.PROCS[pid] or {}
        local group = proc.tools and proc.tools[1]
        local toolItem, grade = nil, "best"
        if group and scan then toolItem, grade = K.findTool(scan, group) end
        local can = (not group) or toolItem ~= nil or grade == "bare"
        local o = sub:addOption(T("IGUI_GTPC_Proc_" .. pid), player, function(p)
            log("right-click: prepare %s with %s", tostring(call(it, "getFullType")), pid)
            openAndRun(p, function(win)
                win.prepSelKey, win.prepSel, win.prepRedoSel = tostring(call(it, "getFullType")), nil, nil
                if win.startPrep then win:startPrep(it, pid, toolItem, grade, group, nil) end
            end)
        end)
        if not can then
            o.notAvailable = true
            local tip = ISInventoryPaneContextMenu.addToolTip()
            tip.description = T("IGUI_GTPP_NeedTool", T("IGUI_GTPC_Tool_" .. tostring(group)))
            o.toolTip = tip
        end
    end
end

-- ------------------------------------------------------------ #23 buff moodle
local MOODLE = "DishBuff"
local moodleReady = false
local function setupMoodle()
    if moodleReady or not MF or not MF.createMoodle then return end
    MF.createMoodle(MOODLE)
    moodleReady = true
end
-- the value per buff level (0.5 = neutral = hidden)
local LEVEL_VALUE = { 0.65, 0.75, 0.85 }
local thresholdsSet = setmetatable({}, { __mode = "k" })
local function updateMoodle(player)
    if not moodleReady or not MF.getMoodle then return end
    local m = MF.getMoodle(MOODLE, player:getPlayerNum())
    if not m then return end
    if not thresholdsSet[m] then
        -- bad side never reached (the value is 0.5 .. 0.85); good 1 / 2 / 3 at 0.6 / 0.7 / 0.8, 4 never
        pcall(m.setThresholds, m, -1, -1, -1, -1, 0.6, 0.7, 0.8, 2.0)
        thresholdsSet[m] = true
    end
    local b = K.myBuffNow and K.myBuffNow(player)
    local tier = b and math.max(1, math.min(3, tonumber(b.tier) or 1)) or nil
    pcall(m.setValue, m, tier and LEVEL_VALUE[tier] or 0.5)
    if tier and m.setDescription then
        local text = T("IGUI_GTPP_MoodleDesc", T("IGUI_GTPC_Buff_" .. tostring(b.kind)), tostring(tier), string.format("%.1f", b.hoursLeft or 0))
        pcall(m.setDescription, m, 1, tier, text)
    end
end

local lastMoodle = 0
local function onTick()
    local t = nowMs()
    if t - lastMoodle < 2000 then return end
    lastMoodle = t
    for i = 0, (getNumActivePlayers and getNumActivePlayers() or 1) - 1 do
        local p = getSpecificPlayer and getSpecificPlayer(i)
        if p and not p:isDead() then
            local ok, err = pcall(updateMoodle, p)
            if not ok then logOnce("moodle", "dish buff moodle FAILED: %s", tostring(err)) end
        end
    end
end

-- ------------------------------------------------------------ install
if MF == nil then pcall(require, "MF_ISMoodle") end
local okM, errM = pcall(setupMoodle)
if not okM then logOnce("moodlesetup", "dish buff moodle could not be made: %s", tostring(errM)) end

if Events then
    if Events.OnGameStart then
        Events.OnGameStart.Add(function()
            local ok1, e1 = pcall(hookEvoMenu)
            if not ok1 then logOnce("evohook", "right-click recipe menu hook FAILED: %s", tostring(e1)) end
            local ok2, e2 = pcall(hookCraftWindow)
            if not ok2 then logOnce("crafthook", "crafting window hook FAILED: %s", tostring(e2)) end
        end)
    end
    if Events.OnFillInventoryObjectContextMenu then
        Events.OnFillInventoryObjectContextMenu.Add((HARMONIE_Ours or function(f) return f end)(function(playerNum, context, items)
            local ok, err = pcall(onInventoryMenu, playerNum, context, items)
            if not ok then logOnce("invmenu", "right-click Prepare FAILED: %s", tostring(err)) end
        end, "GTP"))
    end
    if Events.OnTick then Events.OnTick.Add(onTick) end
    if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(function() thresholdsSet = setmetatable({}, { __mode = "k" }) end) end
end

log("vanilla UI hooks loaded (recipe menu tags, crafting window score, right-click Prepare, buff moodle)")

--[[
    HARMONIE - Life With Style : gacha items (client)

    The client half of RWZ Retention Items v0.4.2, moved here (owner,
    2026-10-23), its rules unchanged:
      * the locked XP formula (AddXP): Final XP = Base x [vanilla / book
        multiplier + manual bonus + guide bonus] x New Dawn set multiplier;
        a Survival Journey's flat XP is never multiplied (pending guard);
      * the capsule runtime: weapon damage / critical / swing time on the
        weapon in hand (restored after, only where still ours), run speed,
        endurance-loss and tiredness-gain scaling, the +10% effective max HP
        bridge on direct hits (the +5 protection is the server's armour layer);
      * the buff tray on the right: one EXP moodle (hover: every boost and its
        timer), one capsule moodle, New Dawn only at 4/4.
    The state comes from the server (GachaState): items, the set, buffs.
]]--

require "ISUI/ISPanel"
require "HARMONIELifeWithStyle/LWS_Core"
require "HARMONIELifeWithStyle/LWS_GachaData"
require "HARMONIELifeWithStyle/LWS_Client"

local C = LWS.Client
local GC = {}
LWS.GachaClient = GC
local log = function(...) LWS.log("GachaClient", ...) end
local function now() return getTimestampMs and getTimestampMs() or 0 end

C.gacha = C.gacha or { items = {}, set = {}, buffs = {} }   -- buffs[key] = { u = until (local ms), s = start }

function GC.handle(command, args)
    if command == "GachaState" then
        local t = now()
        local buffs = {}
        for k, b in pairs(args.buffs or {}) do buffs[k] = { u = t + (tonumber(b.rem) or 0), s = tonumber(b.s) or t } end
        C.gacha = { items = args.items or {}, set = args.set or {}, buffs = buffs }
        return true
    elseif command == "GachaJourney" then
        C.say(LWS.T("IGUI_LWSG_Msg_Journey", tostring(args.amount or "?"), tostring(args.perk or "?")))
        return true
    elseif command == "AdminGacha" then
        C.adminGacha = args
        return true
    end
    return false
end

-- ------------------------------------------------------------- what the player has
function GC.count(id) return tonumber(C.gacha.items and C.gacha.items[id]) or 0 end
function GC.equipped(id) return C.gacha.set and C.gacha.set[id] == true end

function GC.activeBuffs()
    local t, out = now(), {}
    for k, b in pairs(C.gacha.buffs or {}) do if b.u > t then out[k] = b end end
    return out
end

function GC.activeCapsule()
    for k, b in pairs(GC.activeBuffs()) do
        local def = LWS.GACHA_BUFFS[k]
        if def and def.family == "capsule" then return k, def, b end
    end
    return nil
end

-- the manual / guide bonus for a perk (RWZGacha.getActiveBuffBonus)
function GC.buffBonus(perkId)
    local bonus = 0
    for k in pairs(GC.activeBuffs()) do
        local def = LWS.GACHA_BUFFS[k]
        if def then
            if def.allXP then bonus = bonus + def.allXP
            elseif def.perks and def.perks[perkId] then bonus = bonus + def.perks[perkId] end
        end
    end
    return bonus
end

-- New Dawn (RWZGacha.getNewDawnBonus): the pieces equipped in the window
function GC.setBonus()
    local bonus, count = 0, 0
    for id in pairs(C.gacha.set or {}) do
        local g = LWS.GACHA_ITEM[id]
        if g and g.use and g.use.set and GC.count(id) > 0 then bonus = bonus + g.use.set; count = count + 1 end
    end
    if count == 4 then bonus = bonus + (LWS.GACHA_SET_FULL_BONUS or 0) end
    return bonus, count
end

-- the canonical locked XP formula (RWZGacha.calculateFinalAward)
function GC.finalAward(vanillaAward, bookMult, additiveBonus, setBonus)
    vanillaAward = tonumber(vanillaAward) or 0
    bookMult = tonumber(bookMult) or 1.0
    additiveBonus = tonumber(additiveBonus) or 0
    setBonus = tonumber(setBonus) or 0
    if bookMult <= 0 then bookMult = 1.0 end
    local recoveredBase = vanillaAward / bookMult
    return (vanillaAward + recoveredBase * additiveBonus) * (1.0 + setBonus)
end

-- ------------------------------------------------------------- using
GC.pendingFlat = nil
function GC.use(id)
    local g = LWS.GACHA_ITEM[id]
    if not g then return end
    if g.use and g.use.perk then
        -- the flat Journey XP must not be multiplied by our own AddXP hook
        GC.pendingFlat = { perk = g.use.perk, amount = tonumber(g.use.flatXP) or 0, untilMs = now() + 5000 }
    end
    log("use %s", id)
    C.send("GachaUse", { id = id })
end
function GC.equip(id, on) log("%s %s", on and "equip" or "take off", id); C.send("GachaEquip", { id = id, on = on == true }) end

local function consumePending(perkId, amount)
    local p = GC.pendingFlat
    if not p then return false end
    if now() > p.untilMs then GC.pendingFlat = nil; return false end
    if perkId == p.perk and math.abs((tonumber(amount) or 0) - p.amount) < 0.01 then GC.pendingFlat = nil; return true end
    return false
end

-- ------------------------------------------------------------- XP
local xpGuard = false
function GC.onAddXP(character, perk, amount)
    if xpGuard or not character or character ~= getPlayer() then return end
    if not perk or not amount or amount <= 0 then return end
    local perkId
    pcall(function() perkId = perk:getId() end)
    if consumePending(perkId, amount) then return end
    local bonus = GC.buffBonus(perkId)
    local setBonus = GC.setBonus()
    if bonus <= 0 and setBonus <= 0 then return end
    local bookMult = 1.0
    pcall(function()
        local m = character:getXp():getMultiplier(perk)
        if m and m > 0 then bookMult = m end
    end)
    local extra = GC.finalAward(amount, bookMult, bonus, setBonus) - amount
    if extra <= 0 then return end
    xpGuard = true
    local ok, err = pcall(function() character:getXp():AddXPNoMultiplier(perk, extra) end)
    xpGuard = false
    if not ok then LWS.logOnce("xperr", "GachaClient", "extra XP FAILED: %s", tostring(err)) end
end

-- ------------------------------------------------------------- capsule runtime (RWZ CapsuleEffects)
local RT = {}
local function clamp01(v) if v < 0 then return 0 elseif v > 1 then return 1 end return v end
local function near(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 0.0005 end

local function restoreWeapon(st)
    local p = st.weaponPatch
    if not p or not p.weapon then return end
    local w = p.weapon
    pcall(function() if near(w:getMinDamage(), p.aMin) then w:setMinDamage(p.minDamage) end end)
    pcall(function() if near(w:getMaxDamage(), p.aMax) then w:setMaxDamage(p.maxDamage) end end)
    pcall(function() if near(w:getCriticalChance(), p.aCrit) then w:setCriticalChance(p.crit) end end)
    pcall(function() if near(w:getSwingTime(), p.aSwing) then w:setSwingTime(p.swing) end end)
    pcall(function() if near(w:getMinimumSwingTime(), p.aMinSwing) then w:setMinimumSwingTime(p.minSwing) end end)
    st.weaponPatch = nil
end

local function pickWeapon(player)
    local w = player:getPrimaryHandItem()
    if w and instanceof(w, "HandWeapon") then return w end
    w = player:getSecondaryHandItem()
    if w and instanceof(w, "HandWeapon") then return w end
    return nil
end

local function applyWeapon(player, st, e)
    local needs = e.damageMult or e.critAdd or e.swingTimeMult
    local weapon = needs and pickWeapon(player) or nil
    if not weapon then restoreWeapon(st); return end
    local sig = tostring(e.damageMult or 1) .. ":" .. tostring(e.critAdd or 0) .. ":" .. tostring(e.swingTimeMult or 1)
    if st.weaponPatch and st.weaponPatch.weapon == weapon and st.weaponPatch.sig == sig then return end
    restoreWeapon(st)
    local p = { weapon = weapon, sig = sig, minDamage = weapon:getMinDamage(), maxDamage = weapon:getMaxDamage(),
        crit = weapon:getCriticalChance(), swing = weapon:getSwingTime(), minSwing = weapon:getMinimumSwingTime() }
    p.aMin, p.aMax, p.aCrit, p.aSwing, p.aMinSwing = p.minDamage, p.maxDamage, p.crit, p.swing, p.minSwing
    st.weaponPatch = p
    if e.damageMult then
        p.aMin, p.aMax = p.minDamage * e.damageMult, p.maxDamage * e.damageMult
        weapon:setMinDamage(p.aMin); weapon:setMaxDamage(p.aMax)
    end
    if e.critAdd then p.aCrit = p.crit + e.critAdd; weapon:setCriticalChance(p.aCrit) end
    if e.swingTimeMult then
        p.aSwing, p.aMinSwing = p.swing * e.swingTimeMult, p.minSwing * e.swingTimeMult
        weapon:setSwingTime(p.aSwing); weapon:setMinimumSwingTime(p.aMinSwing)
    end
end

local function restoreMove(player, st)
    if not st.move then return end
    if math.abs(player:getMoveSpeed() - st.move.applied) < 0.0005 then pcall(function() player:setMoveSpeed(st.move.base) end) end
    st.move = nil
end

local function applyRun(player, st, mult)
    if not mult or mult == 1 or not (player:IsRunning() or player:isSprinting()) then restoreMove(player, st); return end
    local cur = player:getMoveSpeed()
    local base = (st.move and math.abs(cur - st.move.applied) < 0.0005) and st.move.base or cur
    local applied = base * mult
    if math.abs(cur - applied) > 0.0005 then pcall(function() player:setMoveSpeed(applied) end) end
    st.move = { base = base, applied = applied }
end

local function applyLoss(player, st, e)
    local stats = player:getStats()
    local endurance = stats:get(CharacterStat.ENDURANCE)
    local fatigue = stats:get(CharacterStat.FATIGUE)
    if e.enduranceLossMult and st.lastEndurance and endurance < st.lastEndurance then
        endurance = clamp01(endurance + (st.lastEndurance - endurance) * (1.0 - e.enduranceLossMult))
        stats:set(CharacterStat.ENDURANCE, endurance)
    end
    if e.fatigueGainMult and st.lastFatigue and fatigue > st.lastFatigue then
        fatigue = clamp01(fatigue - (fatigue - st.lastFatigue) * (1.0 - e.fatigueGainMult))
        stats:set(CharacterStat.FATIGUE, fatigue)
    end
    st.lastEndurance, st.lastFatigue = endurance, fatigue
end

function GC.onPlayerUpdate(player)
    if not player or player ~= getPlayer() then return end
    local n = player:getPlayerNum()
    local st = RT[n] or {}
    RT[n] = st
    local key, def = GC.activeCapsule()
    if key ~= st.activeKey then
        restoreWeapon(st)
        restoreMove(player, st)
        st.activeKey = key
        st.lastEndurance = player:getStats():get(CharacterStat.ENDURANCE)
        st.lastFatigue = player:getStats():get(CharacterStat.FATIGUE)
        log("capsule: %s", tostring(key or "none"))
    end
    if not def then
        restoreWeapon(st); restoreMove(player, st)
        st.lastEndurance, st.lastFatigue = nil, nil
        return
    end
    local e = def.effects or {}
    applyWeapon(player, st, e)
    applyLoss(player, st, e)
    applyRun(player, st, e.runSpeedMult)
end

-- +10% effective max HP on direct hits (RWZ's conservative bridge; never touches wounds or infection)
local damageGuard = false
function GC.onPlayerGetDamage(character, damageType, damage)
    if damageGuard or not character or character ~= getPlayer() then return end
    local _, def = GC.activeCapsule()
    local mult = def and def.effects and def.effects.effectiveMaxHealthMult
    if not mult or mult <= 1.0 or not damage or damage <= 0 then return end
    if not (damageType == "WEAPONHIT" or damageType == "CARHITDAMAGE" or damageType == "CARCRASHDAMAGE" or damageType == "FALLDOWN") then return end
    local refund = damage * (1.0 - 1.0 / mult)
    if refund <= 0 then return end
    damageGuard = true
    pcall(function() character:getBodyDamage():AddGeneralHealth(refund) end)
    damageGuard = false
end

-- ------------------------------------------------------------- the buff tray (RWZ's layout)
GC.UI = { top = 170, rightMargin = 82, rowHeight = 42, iconSize = 34, tooltipWidth = 320 }

local function fmt(ms)
    local sec = math.max(0, math.floor(ms / 1000))
    local h, m, s = math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end
GC.fmt = fmt

local texCache = {}
local function tex(name)
    if not name then return nil end
    if texCache[name] == nil then texCache[name] = getTexture(name) or getTexture("media/textures/" .. name .. ".png") or false end
    return texCache[name] or nil
end
GC.tex = tex

-- the label of a buff: the name of the item that gives it
function GC.buffLabel(key)
    for _, g in ipairs(LWS.GACHA_ITEMS) do
        if g.use and g.use.buff == key then return LWS.T("IGUI_LWSG_Name_" .. g.id), g end
    end
    return key, nil
end

function GC.trayEntries()
    local t = now()
    local entries, exp = {}, {}
    local expOrder, expSoon
    for k, b in pairs(GC.activeBuffs()) do
        local def = LWS.GACHA_BUFFS[k]
        if def and def.ui == "exp" then
            exp[#exp + 1] = { label = GC.buffLabel(k), rem = b.u - t, s = b.s }
            expOrder = math.min(expOrder or math.huge, b.s)
            expSoon = math.min(expSoon or math.huge, b.u - t)
        end
    end
    table.sort(exp, function(a, b) return a.s < b.s end)
    if #exp > 0 then
        local tip = { LWS.T("IGUI_LWSG_TrayExp") }
        for _, l in ipairs(exp) do tip[#tip + 1] = l.label .. "  [" .. fmt(l.rem) .. "]" end
        entries[#entries + 1] = { id = "exp", order = expOrder, icon = "Item_LWSG_MasterTrainingManual", timer = fmt(expSoon), tip = tip }
    end
    local key, def, b = GC.activeCapsule()
    if key then
        local label, g = GC.buffLabel(key)
        local tip = { label, LWS.T(g and ("IGUI_LWSG_Desc_" .. g.id) or ""), LWS.T("IGUI_LWSG_Left", fmt(b.u - t)) }
        entries[#entries + 1] = { id = "capsule", order = b.s, icon = "Item_LWSG_" .. tostring(def.icon), timer = fmt(b.u - t), tip = tip }
    end
    local _, count = GC.setBonus()
    if count == 4 then
        GC.setSince = GC.setSince or t
        entries[#entries + 1] = { id = "set", order = GC.setSince, icon = "Item_LWSG_NewDawnNecklace", timer = "SET",
            tip = { LWS.T("IGUI_LWSG_TraySet"), LWS.T("IGUI_LWSG_TraySetFull") } }
    else
        GC.setSince = nil
    end
    table.sort(entries, function(a, b) if a.order == b.order then return a.id < b.id end return a.order < b.order end)
    return entries
end

LWSGachaTray = ISPanel:derive("LWSGachaTray")
function LWSGachaTray:new()
    local ui = GC.UI
    local w = ui.tooltipWidth + 104
    local o = ISPanel:new(getCore():getScreenWidth() - ui.rightMargin - w, ui.top, w, 400)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    return o
end
function LWSGachaTray:prerender()
    local ui = GC.UI
    self:setX(getCore():getScreenWidth() - ui.rightMargin - self.width)
    self:setY(ui.top)
    local entries = GC.trayEntries()
    self:setHeight(math.max(1, #entries * ui.rowHeight + 200))
    local lane = self.width - 98
    local mx, my = getMouseX() - self:getAbsoluteX(), getMouseY() - self:getAbsoluteY()
    local hovered
    for i, e in ipairs(entries) do
        local y = (i - 1) * ui.rowHeight
        self:drawRect(lane, y, 96, ui.rowHeight - 3, 0.62, 0.03, 0.035, 0.04)
        self:drawRectBorder(lane, y, 96, ui.rowHeight - 3, 0.72, 0.32, 0.34, 0.36)
        local t = tex(e.icon)
        if t then self:drawTextureScaledAspect(t, lane + 3, y + 3, ui.iconSize, ui.iconSize, 1, 1, 1, 1) end
        self:drawTextRight(e.timer or "", self.width - 5, y + 11, 0.95, 0.95, 0.95, 1, UIFont.Small)
        if mx >= lane and mx <= self.width and my >= y and my < y + ui.rowHeight then
            hovered = { e = e, y = y }
            self:drawRectBorder(lane - 1, y - 1, 98, ui.rowHeight - 1, 1.0, 0.95, 0.72, 0.20)
        end
    end
    if hovered then
        local lines = hovered.e.tip
        local lh = getTextManager():getFontHeight(UIFont.Small) + 3
        local h = 12 + #lines * lh
        local y = math.max(0, math.min(hovered.y, self.height - h))
        self:drawRect(0, y, ui.tooltipWidth, h, 0.88, 0.035, 0.04, 0.045)
        self:drawRectBorder(0, y, ui.tooltipWidth, h, 0.85, 0.55, 0.55, 0.55)
        for i, line in ipairs(lines) do
            local c = i == 1 and { 1.0, 0.82, 0.32 } or { 0.92, 0.92, 0.92 }
            self:drawText(tostring(line), 9, y + 6 + (i - 1) * lh, c[1], c[2], c[3], 1, UIFont.Small)
        end
    end
end

function GC.makeTray()
    if GC.tray then return end
    local ok, err = pcall(function()
        GC.tray = LWSGachaTray:new()
        GC.tray:initialise()
        GC.tray:addToUIManager()
    end)
    log(ok and "buff tray made" or ("buff tray FAILED: " .. tostring(err)))
end

-- ------------------------------------------------------------- events
local function safe(name, f)
    return function(...)
        local ok, err = pcall(f, ...)
        if not ok then LWS.logOnce("gc:" .. name, "GachaClient", "%s FAILED: %s", name, tostring(err)) end
    end
end

if Events and not GC.registered then
    GC.registered = true
    if Events.AddXP then Events.AddXP.Add(safe("AddXP", GC.onAddXP)) end
    if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(safe("capsule", GC.onPlayerUpdate)) end
    if Events.OnPlayerGetDamage then Events.OnPlayerGetDamage.Add(safe("damage", GC.onPlayerGetDamage)) end
    if Events.OnGameStart then Events.OnGameStart.Add(GC.makeTray) end
end

return GC

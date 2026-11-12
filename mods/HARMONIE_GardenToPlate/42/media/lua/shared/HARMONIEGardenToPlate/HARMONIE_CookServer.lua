--[[
    HARMONIE - From Garden to Plate: cooking takes the ingredients at the
    start and makes the dish at the end (the authority: server, or single
    player).

    Owner, 2026-11-12: "บัคทำเสร็จหมดแล้วแต่หาของไม่เจอ ฉันอยากเปลี่ยนให้เป็นการทำ
    เสร็จแล้ว เสกขึ้นมาเลย ... ส่วนการใช้ภาชนะอะไรก็ให้เป็นหนึ่งในวัตถุดิบเลย ให้หาย
    ไปเหมือนวัตถุดิบ ... เอาของไปตอนกดทำ แล้วเสกอันที่เสร็จตอนทำเสร็จสิ้น และหากกด
    ยกเลิกให้คืนของที่ใช้ทำ ส่วนหากออกแท็บตอนกำลังทำให้บันทึกไว้ว่าทำอยู่แล้วทำต่อ
    เมื่อไหร่ก็ได้".

    Before: the ingredients went in one by one through vanilla's evolved
    recipe actions, and the flow had to find the dish item vanilla made --
    it sometimes never did ("finished but the dish was not found").
    Now:
      take     Start: every ingredient AND the container (pot, pan, bowl...)
               are taken from the player (inventory, bags, boxes in the
               room). Each is remembered (type, freshness, cooked, hunger,
               uses, fluid, vitamins) so it can be given back. A seasoning
               that has uses (salt, pepper...) loses ONE use instead.
               The total nutrition and vitamins are worked out now.
      progress after each step: which step and the results so far
      finish   the dish item (the recipe's result type) is MADE in the
               inventory with the ingredients' total hunger, calories,
               carbs, fat, protein and vitamins, then the cooking quality
               and XP as before (K.applyQuality / K.giveXp).
      cancel   everything taken is given back (as new items with the same
               freshness / hunger / uses; a seasoning gets its use back).
      pending  what is being made, for a window opened later (relog too).
    It all lives in the player's modData (HARMONIE_CookPending), kept by
    the authority, so closing the tab, the window or the game loses
    nothing. A player who dies mid-dish gets the ingredients back on the
    body. Logged as [HARMONIE_GTP][CookServer].
]]--

require "HARMONIEGardenToPlate/HARMONIE_CookCore"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.CookServer = HARMONIE_GTP.CookServer or {}
local S = HARMONIE_GTP.CookServer
local K = HARMONIE_GTP.Cook
S.NET = "HARMONIE_GTP_CookTake"
S.KEY = "HARMONIE_CookPending"

local function log(fmt, ...) if HARMONIE_GTP.Log then HARMONIE_GTP.Log("CookServer", fmt, ...) end end
local function call(o, m, ...)
    if not o or type(o[m]) ~= "function" then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
local function nameOf(p) return tostring(call(p, "getUsername") or "?") end
local function isServerSide() return isServer and isServer() end
local function pureClient() return isClient and isClient() and not isServerSide() end
local function isFood(it) return it ~= nil and instanceof and instanceof(it, "Food") end
local function isDrainable(it) return it ~= nil and instanceof and instanceof(it, "DrainableComboItem") end
local function hours() local gt = getGameTime and getGameTime(); return gt and gt:getWorldAgeHours() or 0 end

local function findItem(player, id)
    if id == nil then return nil end
    if HARMONIE_Reach and HARMONIE_Reach.findById then
        local it, c = HARMONIE_Reach.findById(player, id)
        if it then return it, c end
    end
    local it = K.findInInventory and K.findInInventory(player, tonumber(id))
    return it, it and call(it, "getContainer")
end

local function removeItem(item, cont)
    cont = call(item, "getContainer") or cont
    if not cont then return false end
    local ok = pcall(function() cont:Remove(item) end)
    if ok and isServerSide() and sendRemoveItemFromContainer then pcall(sendRemoveItemFromContainer, cont, item) end
    return ok
end

local function addItem(player, t)
    local inv = call(player, "getInventory")
    local it = inv and call(inv, "AddItem", t)
    if it and isServerSide() and sendAddItemToContainer then pcall(sendAddItemToContainer, inv, it) end
    return it, inv
end

local function sync(player, item)
    if not isServerSide() then return end
    if sendItemStats then pcall(sendItemStats, item) end
    if syncItemModData then pcall(function() syncItemModData(player, item) end) end
end

local function plainCopy(t, depth)
    if type(t) ~= "table" or (depth or 0) > 3 then return t end
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" then out[k] = plainCopy(v, (depth or 0) + 1)
        elseif type(v) ~= "function" and type(v) ~= "userdata" then out[k] = v end
    end
    return out
end

local function reply(player, command, args)
    if isServerSide() then
        if sendServerCommand then sendServerCommand(player, S.NET, command, args or {}) end
    elseif S.onReply then
        S.onReply(command, args or {})
    end
end

function S.pending(player)
    local md = call(player, "getModData")
    local p = md and md[S.KEY]
    if type(p) == "table" and p.dish then return p end
    return nil
end

-- what an item is now, to give it back later
local function snapshot(item)
    local s = { t = call(item, "getFullType") }
    s.age = tonumber(call(item, "getAge"))
    if isFood(item) then
        s.food = true
        s.cooked = call(item, "isCooked") == true
        s.burnt = call(item, "isBurnt") == true
        s.hunger = tonumber(call(item, "getHungerChange"))
        s.baseHunger = tonumber(call(item, "getBaseHunger"))
    end
    s.cond = tonumber(call(item, "getCondition"))
    local md = call(item, "getModData")
    if md and md.HARMONIE_Vitamins then
        s.vit = plainCopy(md.HARMONIE_Vitamins)
        s.units = md.HARMONIE_HungerUnits
    end
    local fc = call(item, "getFluidContainer")
    if fc then
        s.fluidAmount = tonumber(call(fc, "getAmount"))
        local pf = call(fc, "getPrimaryFluid")
        s.fluid = pf and tostring(call(pf, "getFluidTypeString") or call(pf, "toString") or pf) or nil
    end
    return s
end

-- nutrition and vitamins one item brings into the dish (all of it)
local function nutritionOf(item, nut, vit)
    if not isFood(item) then return 0 end
    local h = math.abs(tonumber(call(item, "getHungerChange")) or 0)
    nut.hunger = nut.hunger + h
    nut.cal = nut.cal + (tonumber(call(item, "getCalories")) or 0)
    nut.carb = nut.carb + (tonumber(call(item, "getCarbohydrates")) or 0)
    nut.fat = nut.fat + (tonumber(call(item, "getLipids")) or 0)
    nut.prot = nut.prot + (tonumber(call(item, "getProteins")) or 0)
    nut.unhappy = nut.unhappy + (tonumber(call(item, "getUnhappyChange")) or 0)
    nut.boredom = nut.boredom + (tonumber(call(item, "getBoredomChange")) or 0)
    local units = h * 100
    local rates = HARMONIE_GTP.GetVitaminRatePerHunger and HARMONIE_GTP.GetVitaminRatePerHunger(item)
    for v, r in pairs(rates or {}) do vit[v] = (vit[v] or 0) + r * units end
    return units
end

-- ------------------------------------------------------------------ take
function S.take(player, args)
    args = type(args) == "table" and args or {}
    local dish = K.DISH_BY_ID and K.DISH_BY_ID[tostring(args.dish)]
    if not dish then return reply(player, "refused", { why = "dish" }) end
    if S.pending(player) then
        log("%s asked to start %s while %s is still being made -- refused", nameOf(player), dish.id, S.pending(player).dish)
        return reply(player, "refused", { why = "busy", pending = plainCopy(S.pending(player)) })
    end
    local resultType = tostring(args.result or "")
    local sm = getScriptManager and getScriptManager()
    if resultType == "" or not (sm and call(sm, "FindItem", resultType)) then
        log("%s: %s has no valid result item (%s) -- refused", nameOf(player), dish.id, resultType)
        return reply(player, "refused", { why = "result" })
    end
    -- every item first: nothing is taken unless all of them are there
    local list, seen = {}, {}
    for _, e in ipairs(type(args.items) == "table" and args.items or {}) do
        local id = tonumber(type(e) == "table" and e.id or e)
        if id and not seen[id] then
            seen[id] = true
            local it, c = findItem(player, id)
            if not it then
                log("%s: ingredient id %s for %s is not within reach on the server -- refused, nothing taken", nameOf(player), tostring(id), dish.id)
                return reply(player, "refused", { why = "missing" })
            end
            list[#list + 1] = { item = it, cont = c, spice = type(e) == "table" and e.spice == true }
        end
    end
    if #list == 0 then return reply(player, "refused", { why = "ingredients" }) end
    local nut = { hunger = 0, cal = 0, carb = 0, fat = 0, prot = 0, unhappy = 0, boredom = 0 }
    local vit, units = {}, 0
    local snaps = {}
    for _, e in ipairs(list) do
        local it = e.item
        if e.spice and isDrainable(it) and (tonumber(call(it, "getCurrentUsesFloat")) or 0) > 0 then
            -- a seasoning with uses: one use goes into the dish
            local before = tonumber(call(it, "getCurrentUsesFloat")) or 0
            pcall(function() it:Use() end)
            sync(player, it)
            snaps[#snaps + 1] = { t = call(it, "getFullType"), usedFrom = call(it, "getID"), uses = before - (tonumber(call(it, "getCurrentUsesFloat")) or 0) }
        else
            local s = snapshot(it)
            units = units + nutritionOf(it, nut, vit)
            removeItem(it, e.cont)
            snaps[#snaps + 1] = s
        end
    end
    local md = player:getModData()
    md[S.KEY] = { dish = dish.id, result = resultType, items = snaps, nut = nut, vit = vit, units = units, step = 1, words = {}, at = hours() }
    log("%s started %s: %d item(s) taken (container included), %.0f hunger, %.0f kcal, result %s",
        nameOf(player), dish.id, #snaps, nut.hunger * 100, nut.cal, resultType)
    reply(player, "taken", { pending = plainCopy(md[S.KEY]) })
end

-- ------------------------------------------------------------------ progress
function S.progress(player, args)
    local p = S.pending(player)
    if not p then return end
    p.step = math.max(1, math.floor(tonumber(args and args.step) or p.step or 1))
    if type(args and args.words) == "table" then
        p.words = {}
        for k, v in pairs(args.words) do if type(k) == "string" and type(v) == "string" then p.words[k] = v end end
    end
end

-- ------------------------------------------------------------------ finish
function S.finish(player, args)
    local p = S.pending(player)
    if not p then log("%s finished a dish but nothing is pending -- ignored", nameOf(player)); return reply(player, "refused", { why = "nothing" }) end
    local dish = K.DISH_BY_ID and K.DISH_BY_ID[p.dish]
    local q = math.max(0, math.min(1, tonumber(args and args.q) or 0.66))
    local item = addItem(player, p.result)
    if not item then
        log("%s: making %s (%s) FAILED -- the ingredients stay pending (cancel gives them back)", nameOf(player), p.dish, tostring(p.result))
        return reply(player, "refused", { why = "make" })
    end
    local n = p.nut or {}
    if isFood(item) then
        local h = -(n.hunger or 0)
        if h < 0 then
            pcall(function() item:setBaseHunger(h) end)
            pcall(function() item:setHungChange(h) end)
        end
        pcall(function() item:setCalories(n.cal or 0) end)
        pcall(function() item:setCarbohydrates(n.carb or 0) end)
        pcall(function() item:setLipids(n.fat or 0) end)
        pcall(function() item:setProteins(n.prot or 0) end)
    end
    if HARMONIE_GTP.AddVitaminsToItem and (p.units or 0) > 0 then
        local md = call(item, "getModData")
        if md then md.HARMONIE_Vitamins, md.HARMONIE_HungerUnits = nil, nil end
        pcall(HARMONIE_GTP.AddVitaminsToItem, item, p.vit or {}, p.units)
    end
    local done = K.applyQuality and K.applyQuality(item, q, p.dish, player)
    if done and K.giveXp and K.dishXp then K.giveXp(player, K.dishXp(dish, q)) end
    sync(player, item)
    player:getModData()[S.KEY] = nil
    log("%s made %s: %s id %s, quality %.2f (%s), %.0f hunger, %.0f kcal", nameOf(player), p.dish, tostring(p.result),
        tostring(call(item, "getID")), q, K.wordOf and K.wordOf(q) or "?", (n.hunger or 0) * 100, n.cal or 0)
    reply(player, "made", { id = call(item, "getID"), q = q, dish = p.dish, unhappy = tonumber(call(item, "getUnhappyChange")),
        boredom = tonumber(call(item, "getBoredomChange")), level = K.level and K.level(player) })
end

-- ------------------------------------------------------------------ give back
local function restore(player, s, into)
    if s.usedFrom then
        -- a seasoning: its use back on the same shaker, when it is still there
        local it = findItem(player, s.usedFrom)
        if it and isDrainable(it) then
            local cur = tonumber(call(it, "getCurrentUsesFloat")) or 0
            pcall(function() it:setCurrentUsesFloat(math.min(1, cur + (s.uses or 0))) end)
            sync(player, it)
            return true
        end
        return false
    end
    local inv = into or call(player, "getInventory")
    local it = inv and call(inv, "AddItem", s.t)
    if not it then return false end
    if s.age then pcall(function() it:setAge(s.age) end) end
    if s.food then
        if s.cooked then pcall(function() it:setCooked(true) end) end
        if s.burnt then pcall(function() it:setBurnt(true) end) end
        if s.baseHunger then pcall(function() it:setBaseHunger(s.baseHunger) end) end
        if s.hunger then pcall(function() it:setHungChange(s.hunger) end) end
    end
    if s.cond then pcall(function() it:setCondition(s.cond) end) end
    if s.vit then
        local md = call(it, "getModData")
        if md then md.HARMONIE_Vitamins, md.HARMONIE_HungerUnits = plainCopy(s.vit), s.units end
    end
    if s.fluidAmount and s.fluidAmount > 0 then
        local fc = call(it, "getFluidContainer")
        local fluid = (s.fluid and Fluid and (Fluid.Get and call(Fluid, "Get", s.fluid) or Fluid[s.fluid])) or (Fluid and Fluid.Water)
        if fc and fluid then pcall(function() fc:addFluid(fluid, s.fluidAmount) end) end
    end
    if isServerSide() and sendAddItemToContainer then pcall(sendAddItemToContainer, inv, it) end
    sync(player, it)
    return true
end

function S.cancel(player, why, into)
    local p = S.pending(player)
    if not p then return reply(player, "returned", { n = 0 }) end
    local n, lost = 0, 0
    for _, s in ipairs(p.items or {}) do
        if restore(player, s, into) then n = n + 1 else lost = lost + 1 end
    end
    player:getModData()[S.KEY] = nil
    log("%s: %s cancelled (%s) -- %d item(s) given back%s", nameOf(player), p.dish, tostring(why or "button"), n,
        lost > 0 and string.format(", %d seasoning use(s) lost (shaker gone)", lost) or "")
    reply(player, "returned", { n = n })
end

-- ------------------------------------------------------------------ network
function S.onCommand(module, command, player, args)
    if module ~= S.NET or not player then return end
    args = type(args) == "table" and args or {}
    if command == "take" then S.take(player, args)
    elseif command == "progress" then S.progress(player, args)
    elseif command == "finish" then S.finish(player, args)
    elseif command == "cancel" then S.cancel(player, "button")
    elseif command == "pending" then reply(player, "pending", { pending = plainCopy(S.pending(player)) })
    else log("%s sent unknown command %s", nameOf(player), tostring(command)) end
end

-- the client side asks; single player runs it here
function S.request(player, command, args)
    if pureClient() then
        sendClientCommand(player, S.NET, command, args or {})
    else
        S.onCommand(S.NET, command, player, args or {})
    end
end

if Events then
    if Events.OnClientCommand then Events.OnClientCommand.Add(S.onCommand) end
    if Events.OnServerCommand then
        Events.OnServerCommand.Add(function(module, command, args)
            if module ~= S.NET then return end
            if S.onReply then S.onReply(command, type(args) == "table" and args or {}) end
        end)
    end
    -- died mid-dish: the ingredients go back, onto the body
    if Events.OnPlayerDeath then
        Events.OnPlayerDeath.Add(function(player)
            if pureClient() or not S.pending(player) then return end
            S.cancel(player, "death")
        end)
    end
end

return S

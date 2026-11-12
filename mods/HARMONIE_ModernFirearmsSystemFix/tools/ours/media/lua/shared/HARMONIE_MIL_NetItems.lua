--[[
    HARMONIE - Mercenary Is Life: item changes go through the server in MP

    Owner, 2026-11-12 (1.0.0): "รองรับ MP ต้องไม่มีของหายเพราะการคอนเนคกับเซิฟเวอร์
    และเครื่อง". The original mod (Modern Firearms System) adds and removes
    items on the CLIENT in a few places. In B42 multiplayer the server owns
    every inventory: an item made only on a client is gone after the next sync
    or a reconnect, and an item removed only on a client comes back (or the
    two sides disagree until then). Those places:
      * laser / light battery in (ISGunAddBatteryAction) and out
        (ISGunRemoveBatteryAction);
      * grenade launcher reload (ISShootGrenadeReload) and the under-barrel
        launcher reload (ShootGrenadeReload): the ammo used;
      * repair kit (RepairKitAction);
      * the ammo bag (AmmoBagFunction.InitItem / ItemOut);
      * changing a gun's magazine type (ChangeMagzine): the gun is replaced
        by a new one.
    On an MP client those now ask the server ("HARMONIE_MIL_Items"), which
    makes the change on its own copy and sends it to the client
    (sendAddItemToContainer / sendRemoveItemFromContainer / sendItemStats).
    The client changes only what it shows at once (weapon modData, hands).
    Single player and the server are unchanged (the original code runs).
    Every request and every refusal is logged ([HARMONIE_MFSFix][NetItems]).
]]--

HARMONIE_MIL_NetItems = HARMONIE_MIL_NetItems or {}
local N = HARMONIE_MIL_NetItems
N.MODULE = "HARMONIE_MIL_Items"
N.MAX_BAG_OUT = 1000
N.LOADED_KEY = "GrenadeLauncherLoaded"

local function log(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print("[HARMONIE_MFSFix][NetItems] " .. (ok and s or tostring(fmt)))
end
local once = {}
local function logOnce(key, fmt, ...) if once[key] then return end; once[key] = true; log(fmt, ...) end
local function call(o, m, ...)
    if not o or type(o[m]) ~= "function" then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
local function nameOf(p) return tostring(call(p, "getUsername") or "?") end
local function ft(it) return tostring(call(it, "getFullType") or "?") end
local function pureClient() return isClient and isClient() and not (isServer and isServer()) end
local function isServerSide() return isServer and isServer() end

-- ------------------------------------------------------------------ server
-- an item carried by the player (inventory + bags), by id
local function findCarried(player, id)
    if id == nil then return nil end
    local want = tostring(id)
    local function walk(cont, depth)
        local items = call(cont, "getItems")
        if not items then return nil end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then
                if tostring(call(it, "getID")) == want then return it, cont end
                if depth < 6 and instanceof and instanceof(it, "InventoryContainer") then
                    local f, c = walk(call(it, "getInventory"), depth + 1)
                    if f then return f, c end
                end
            end
        end
        return nil
    end
    return walk(call(player, "getInventory"), 0)
end

local function removeItem(item, cont)
    cont = call(item, "getContainer") or cont
    if not cont then return false end
    local ok = pcall(function() cont:Remove(item) end)
    if ok and sendRemoveItemFromContainer then pcall(sendRemoveItemFromContainer, cont, item) end
    return ok
end

local function addItem(player, item)
    local inv = call(player, "getInventory")
    if not inv or not item then return nil end
    local added
    if type(item) == "string" then added = call(inv, "AddItem", item)
    else pcall(function() inv:AddItem(item) end); added = item end
    if added and sendAddItemToContainer then pcall(sendAddItemToContainer, inv, added) end
    return added
end

local function syncItem(player, item)
    if sendItemStats then pcall(sendItemStats, item) end
    if syncItemFields then pcall(syncItemFields, player, item) end
end

local function refuse(player, op, why)
    log("%s: %s refused -- %s", nameOf(player), op, why)
    if sendServerCommand then pcall(sendServerCommand, player, N.MODULE, "Refused", { op = op, why = why }) end
end

local function batteryKey(part) return part == "Laser" and "LaserBatteryReamin" or "LightBatteryReamin" end

N.OPS = {}

-- a battery into a laser / light: its charge goes into the gun's modData
function N.OPS.batteryIn(player, a)
    local w = findCarried(player, a.w)
    local b, bc = findCarried(player, a.b)
    if not w or not b then return refuse(player, "batteryIn", "gun or battery not carried (stale client view)") end
    local uses = tonumber(call(b, "getCurrentUsesFloat")) or 0
    w:getModData()[batteryKey(a.part)] = uses * 100
    removeItem(b, bc)
    syncItem(player, w)
    log("%s: battery (%.0f%%) into the %s of %s", nameOf(player), uses * 100, tostring(a.part), ft(w))
end

-- a battery out of a laser / light
function N.OPS.batteryOut(player, a)
    local w = findCarried(player, a.w)
    if not w then return refuse(player, "batteryOut", "gun not carried") end
    local key = batteryKey(a.part)
    local remain = tonumber(w:getModData()[key])
    if not remain or remain <= 0 then
        -- the gun's battery was put in before 1.0.0 (client only): trust the client once, capped
        remain = math.max(0, math.min(100, (tonumber(a.uses) or 0) * 100))
        log("%s: the server had no battery charge on %s -- using the client's %.0f%% (put in before 1.0.0)", nameOf(player), ft(w), remain)
    end
    w:getModData()[key] = 0
    local bat = addItem(player, "Base.Battery")
    if bat then pcall(function() bat:setCurrentUsesFloat(remain / 100) end); syncItem(player, bat) end
    syncItem(player, w)
    log("%s: battery (%.0f%%) out of the %s of %s", nameOf(player), remain, tostring(a.part), ft(w))
end

-- one round of a type used (grenade / launcher reload)
function N.OPS.consume(player, a)
    local inv = call(player, "getInventory")
    local it = inv and (call(inv, "getFirstTypeRecurse", tostring(a.type)) or call(inv, "FindAndReturn", tostring(a.type)))
    if not it then return refuse(player, "consume", "no " .. tostring(a.type) .. " carried") end
    removeItem(it)
    if a.w and a.loaded then
        local w = findCarried(player, a.w)
        if w then w:getModData()[N.LOADED_KEY] = true; syncItem(player, w) end
    end
    log("%s: used one %s (%s)", nameOf(player), tostring(a.type), tostring(a.why or "reload"))
end

-- a repair kit used on a gun
function N.OPS.repair(player, a)
    local w = findCarried(player, a.w)
    local k, kc = findCarried(player, a.kit)
    if not w or not k then return refuse(player, "repair", "gun or kit not carried") end
    removeItem(k, kc)
    pcall(function() w:setCondition(w:getConditionMax()) end)
    syncItem(player, w)
    log("%s: repaired %s with %s", nameOf(player), ft(w), ft(k))
end

-- ammo bag: loose rounds of its type (ids) go in; the count is the bag's modData (synced by the client)
function N.OPS.bagIn(player, a)
    local n = 0
    for _, id in ipairs(type(a.ids) == "table" and a.ids or {}) do
        local it, c = findCarried(player, id)
        if it and (not a.type or ft(it) == a.type) then removeItem(it, c); n = n + 1 end
    end
    log("%s: %d round(s) of %s into an ammo bag", nameOf(player), n, tostring(a.type))
end

function N.OPS.bagOut(player, a)
    local bag = findCarried(player, a.bag)
    local n = math.max(0, math.min(N.MAX_BAG_OUT, math.floor(tonumber(a.n) or 0)))
    if not bag or n == 0 then return refuse(player, "bagOut", "bag not carried or nothing asked") end
    local md = bag:getModData().IO
    local t = tostring(a.type or "")
    if md and md.ItemType and md.ItemType ~= t then return refuse(player, "bagOut", "type " .. t .. " is not the bag's " .. tostring(md.ItemType)) end
    if not (getScriptManager and getScriptManager():FindItem(t)) then return refuse(player, "bagOut", "unknown item " .. t) end
    for _ = 1, n do addItem(player, t) end
    log("%s: %d x %s out of an ammo bag", nameOf(player), n, t)
end

-- a gun's magazine type changed: the gun is replaced by a new one (the original's ChangeMagzine)
function N.OPS.swapGun(player, a)
    local g, gc = findCarried(player, a.gun)
    if not g then return refuse(player, "swapGun", "gun not carried") end
    local result = instanceItem and instanceItem(call(g, "getType") and g:getFullType() or "")
    if not result then return refuse(player, "swapGun", "could not make a new " .. ft(g)) end
    local mag = a.mag and tostring(a.mag) or nil
    pcall(function()
        result:setCondition(g:getCondition())
        result:setFireMode(g:getFireMode())
        if mag then
            local tmp = instanceItem(mag)
            result:setMagazineType(mag)
            if tmp then result:setMaxAmmo(tmp:getMaxAmmo()) end
        end
        result:setCurrentAmmoCount(g:getCurrentAmmoCount())
        result:setRoundChambered(g:isRoundChambered())
        local old, new = g:getModData(), result:getModData()
        for k, v in pairs(old or {}) do
            if not AWCWF_AllowModDataTable or AWCWF_AllowModDataTable[k] then new[k] = v end
        end
        local parts = g:getAllWeaponParts()
        for i = 0, parts:size() - 1 do result:setWeaponPart(parts:get(i)) end
        if a.refresh and g:isContainsClip() then result:setContainsClip(true) end
        new.MagzineTypeNow = mag
    end)
    removeItem(g, gc)
    local added = addItem(player, result)
    if added then syncItem(player, added) end
    log("%s: %s replaced for magazine type %s (new id %s)", nameOf(player), ft(g), tostring(mag), tostring(call(added, "getID")))
    if sendServerCommand then pcall(sendServerCommand, player, N.MODULE, "Swapped", { id = call(added, "getID"), refresh = a.refresh == true }) end
end

function N.onClientCommand(module, command, player, args)
    if module ~= N.MODULE then return end
    local op = N.OPS[command]
    if not op then logOnce("cmd:" .. tostring(command), "unknown command %s from %s", tostring(command), nameOf(player)); return end
    local ok, err = pcall(op, player, type(args) == "table" and args or {})
    if not ok then log("%s from %s FAILED: %s", tostring(command), nameOf(player), tostring(err)) end
end

-- ------------------------------------------------------------------ client
local function send(player, op, args)
    sendClientCommand(player, N.MODULE, op, args)
    log("asked the server: %s", op)
end

function N.onServerCommand(module, command, args)
    if module ~= N.MODULE then return end
    local me = getPlayer and getPlayer()
    if command == "Refused" then
        log("the server refused %s: %s", tostring(args and args.op), tostring(args and args.why))
    elseif command == "Swapped" and me then
        -- equip the new gun once it has arrived
        local id = args and args.id
        local tries = 0
        local function equip()
            tries = tries + 1
            local inv = me:getInventory()
            local g = inv and inv.getItemById and inv:getItemById(id)
            if g then
                Events.OnTick.Remove(equip)
                me:setPrimaryHandItem(g)
                if call(g, "isRequiresEquippedBothHands") or call(g, "isTwoHandWeapon") then me:setSecondaryHandItem(g) end
                pcall(function() me:resetEquippedHandsModels() end)
                if not args.refresh and riskyInspectAction then ISTimedActionQueue.add(riskyInspectAction:new(me, 1)) end
                log("new gun %s equipped", tostring(id))
            elseif tries > 300 then
                Events.OnTick.Remove(equip)
                log("the new gun %s never arrived -- equip it by hand", tostring(id))
            end
        end
        Events.OnTick.Add(equip)
    end
end

function N.installClient()
    if N.clientInstalled or not pureClient() then return end
    N.clientInstalled = true
    local done = {}
    if ISGunAddBatteryAction then
        ISGunAddBatteryAction.perform = function(self)
            ISBaseTimedAction.perform(self)
            local uses = tonumber(call(self.BatteryItem, "getCurrentUsesFloat")) or 0
            self.Weapon:getModData()[batteryKey(self.PartType)] = uses * 100
            send(self.character, "batteryIn", { w = self.Weapon:getID(), b = self.BatteryItem:getID(), part = self.PartType })
        end
        done[#done + 1] = "battery in"
    end
    if ISGunRemoveBatteryAction then
        ISGunRemoveBatteryAction.perform = function(self)
            ISBaseTimedAction.perform(self)
            local key = batteryKey(self.PartType)
            local remain = tonumber(self.Weapon:getModData()[key]) or 0
            self.Weapon:getModData()[key] = 0
            send(self.character, "batteryOut", { w = self.Weapon:getID(), part = self.PartType, uses = remain / 100 })
        end
        done[#done + 1] = "battery out"
    end
    if ISShootGrenadeReload then
        ISShootGrenadeReload.perform = function(self)
            ISBaseTimedAction.perform(self)
            self.weaopon:getModData()[N.LOADED_KEY] = true
            send(self.character, "consume", { type = self.GrenadelauncherType.AmmoType, w = self.weaopon:getID(), loaded = true, why = "grenade launcher" })
        end
        done[#done + 1] = "grenade launcher reload"
    end
    if ShootGrenadeReload then
        local AMMO = { grenade = { "Gunpart.M203_cat", "Base.GrenadeAmmo" }, ShotGun = { "Gunpart.M26_cat", "Base.ShotgunShells" },
            RPG = { "Gunpart.RPGLauncher_cat", "Base.RPGRocket" } }
        ShootGrenadeReload.perform = function(self)
            ISBaseTimedAction.perform(self)
            local t = AMMO[self.type]
            if not t then return end
            local part = instanceItem(t[1])
            if part then self.weaopon:setWeaponPart("Stool", part) end
            if syncHandWeaponFields then pcall(syncHandWeaponFields, self.character, self.weaopon) end
            send(self.character, "consume", { type = t[2], why = "under-barrel " .. tostring(self.type) })
        end
        done[#done + 1] = "under-barrel reload"
    end
    if RepairKitAction then
        RepairKitAction.perform = function(self)
            pcall(function() self.weapon:setCondition(self.weapon:getConditionMax()) end)
            send(self.character, "repair", { w = self.weapon:getID(), kit = self.kit:getID() })
            ISBaseTimedAction.perform(self)
        end
        done[#done + 1] = "repair kit"
    end
    if AmmoBagFunction and AmmoBagFunction.InitItem and AmmoBagFunction.ItemOut then
        local origIn = AmmoBagFunction.InitItem
        AmmoBagFunction.InitItem = function(IOBox)
            local md = IOBox:getModData().IO
            local t = md and md.ItemType
            local cont = IOBox:getContainer()
            if not t or not cont then return origIn(IOBox) end
            local ids, items = {}, cont:getItems()
            for i = 0, items:size() - 1 do
                local it = items:get(i)
                if it:getFullType() == t then ids[#ids + 1] = it:getID() end
            end
            if #ids == 0 then return end
            AmmoBagFunction.AddNum(IOBox, #ids)
            if syncItemModData then pcall(syncItemModData, getPlayer(), IOBox) end
            send(getPlayer(), "bagIn", { bag = IOBox:getID(), type = t, ids = ids })
        end
        AmmoBagFunction.ItemOut = function(IOBox, num)
            local md = IOBox:getModData().IO
            if not md or not md.ItemType then return end
            if num == -1 then num = md.Count end
            num = math.max(0, math.min(tonumber(num) or 0, tonumber(md.Count) or 0))
            if num == 0 then return end
            AmmoBagFunction.SetNum(IOBox, (tonumber(md.Count) or 0) - num)
            if syncItemModData then pcall(syncItemModData, getPlayer(), IOBox) end
            send(getPlayer(), "bagOut", { bag = IOBox:getID(), type = md.ItemType, n = num })
        end
        done[#done + 1] = "ammo bag"
    end
    if type(ChangeMagzine) == "function" then
        local orig = ChangeMagzine
        ChangeMagzine = function(playerObj, MainGun, MagazineType, Tag, Need)
            if not MagazineType or not Need then return end
            if MainGun:isContainsClip() and Tag ~= "ReFresh" then return orig(playerObj, MainGun, MagazineType, Tag, Need) end
            send(playerObj, "swapGun", { gun = MainGun:getID(), mag = MagazineType, refresh = Tag == "ReFresh" })
        end
        done[#done + 1] = "magazine type change"
    end
    log("MP client: %s go through the server", #done > 0 and table.concat(done, ", ") or "NOTHING (the original's functions were not found)")
end

if Events then
    if Events.OnClientCommand then Events.OnClientCommand.Add(N.onClientCommand) end
    if Events.OnServerCommand then Events.OnServerCommand.Add(N.onServerCommand) end
    if Events.OnGameStart then Events.OnGameStart.Add(N.installClient) end
end

return N

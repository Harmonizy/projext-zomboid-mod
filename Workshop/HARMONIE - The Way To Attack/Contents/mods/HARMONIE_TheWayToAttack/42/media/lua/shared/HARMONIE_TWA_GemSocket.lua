--============================================================================
-- HARMONIE_TheWayToAttack -- gem sockets on crafted weapons (shared)
--
-- Round 18 (request 2026-09-29): "เพิ่มหน้าต่าง ui สำหรับดัดแปลงอาวุธ ... เฉพาะ
-- ที่มีเกรดที่ได้จากการคราฟของม็อดเราเท่านั้น ... ช่องให้สามารถใส่ มณี (อนุญาต
-- ให้ใส่เฉพาะมณีของม็อดเรา) F 0 ช่อง, E 1, D 2, C 3, B 4, A 5, S 5 + 1 ช่อง
-- พิเศษ โดยการใส่ในช่อง ใส่แล้วใส่เลยถอดไม่ได้ แต่ใส่แทนได้ แต่ช่องพิเศษถอด
-- ได้" and "อัญมณีทุกอันตอนนี้ให้ 0.1 ดาเมจต่ำสุดและดาเมจสูงสุด ... เพชรให้ 1".
--
-- A weapon's sockets live in its ModData: TWA_Gems = { ["1"] = fullType,
-- ..., sp = fullType, spState = "Raw" } (string keys -- ModData tables
-- with holes do not survive a save reliably). Only a weapon carrying this
-- mod's TWA_Grade (crafted and finished here) has sockets.
--   * a normal socket, once filled, can't be emptied -- a new gem can be
--     set over the old one, which is destroyed;
--   * the special socket (S only) can be emptied: the gem comes back.
-- The damage bonus goes on the weapon's RAW Min/MaxDamage on top of its base
-- (the debug editor's override if there is one, else the item script's own
-- value), and is put back whenever TWAWeaponDebug.reapply runs (equip, game
-- start, every swing) -- so it holds in combat and after a reload.
--
-- MULTIPLAYER: the client asks (sendClientCommand "gemSocket"), the server
-- checks everything again, takes/gives the gem items, changes the weapon and
-- sends the new socket table back to the owner ("gemSocketSync").
--============================================================================

require "HARMONIE_TWA_CraftState"
require "HARMONIE_TWA_Display"
require "HARMONIE_TWA_RecipeData"

TWAGemSocket = TWAGemSocket or {}
local G = TWAGemSocket
local MODULE = "HARMONIE_TWA"

G.SLOTS_BY_GRADE = { F = 0, E = 1, D = 2, C = 3, B = 4, A = 5, S = 5 }
G.SPECIAL_GRADE = "S"

-- Round 19 ("อัญมณีแต่ละอันให้ ... ดาเมจต่ำสุดและดาเมจสูงสุดตามสถานะมณี ดิบ
-- +0.0 ขัดเกลา +0.1 เจียระไน +0.2 ประณีต +0.3 เจิดจรัส +0.4 บริสุทธิ์ +0.5"
-- and "เพชรเปลี่ยนเป็น เพิ่มความทนทาน 100 แทน"): what a gem gives depends on
-- WHICH gem and its STATE. G.ABILITIES maps a gem's short name to a
-- function(state) returning { Field = amount }; a gem without an entry uses
-- `default`. ("ทำระบบให้รองรับในอนาคต อัญมณีแต่ละอันจะให้ความสามารถที่ต่าง
-- กัน": give a gem its own entry here -- any field of G.FIELDS.)
G.STATE_DAMAGE = { Raw = 0, Refined = 0.1, Cut = 0.2, Fine = 0.3, Radiant = 0.4, Pure = 0.5 }
G.ABILITIES = {
    default = function(state)
        local d = G.STATE_DAMAGE[state] or 0
        return { MinDamage = d, MaxDamage = d }
    end,
    TWA_Diamond = function(state) return { ConditionMax = 100 } end,
}
-- The weapon fields a gem can raise: getter/setter names and the label key.
G.FIELDS = {
    { key = "MinDamage", get = "getMinDamage", set = "setMinDamage", label = "IGUI_TWA_Stat_MinDamage", fmt = "%s", scale = true },
    { key = "MaxDamage", get = "getMaxDamage", set = "setMaxDamage", label = "IGUI_TWA_Stat_MaxDamage", fmt = "%s", scale = true },
    { key = "ConditionMax", get = "getConditionMax", set = "setConditionMax", label = "IGUI_TWA_Stat_Condition", fmt = "%.0f" },
}

-- The gems that fit: every cut gem of this mod (the rough TWA_Gemstone is a
-- stone, not a gem).
function G.gemTypes()
    local pool = TWARecipeData.GemRoll
    local out = {}
    for _, g in ipairs(pool.gems) do out[#out + 1] = g end
    out[#out + 1] = pool.diamond
    return out
end

function G.isGem(fullType)
    return fullType ~= nil and TWACraftState.isRolledGem(fullType)
end

-- What one gem gives: { Field = amount }.
function G.ability(fullType, state)
    local short = fullType and fullType:match("%.([^%.]+)$") or ""
    local f = G.ABILITIES[short] or G.ABILITIES.default
    return f(state or "Raw") or {}
end

-- "Min damage +0.1, Max damage +0.1" -- what an ability gives, in words.
function G.describe(ab)
    local parts = {}
    ab = ab or {}
    local both = ab.MinDamage and ab.MinDamage ~= 0 and ab.MinDamage == ab.MaxDamage
    -- damage shown multiplied (TWADisplay)
    if both then parts[1] = getText("IGUI_TWA_Socket_Damage") .. " +" .. TWADisplay.fmt(ab.MinDamage) end
    for _, f in ipairs(G.FIELDS) do
        local v = ab[f.key]
        local skip = both and (f.key == "MinDamage" or f.key == "MaxDamage")
        if v and v ~= 0 and not skip then parts[#parts + 1] = getText(f.label) .. " +" .. string.format(f.fmt, f.scale and TWADisplay.fmt(v) or v) end
    end
    if #parts == 0 then return getText("IGUI_TWA_Socket_NoAbility") end
    return table.concat(parts, ", ")
end

-- A socket holds "fullType|State" (round 19; a plain fullType from round 18
-- reads as Raw, or the special socket's old separate spState).
function G.pack(fullType, state) return fullType .. "|" .. (state or "Raw") end
function G.unpack(v, oldState)
    if not v then return nil end
    local t, st = v:match("^([^|]+)|(.+)$")
    if t then return t, st end
    return v, oldState or "Raw"
end

function G.grade(weapon)
    return weapon and weapon:getModData().TWA_Grade
end

-- Only a finished weapon of this mod's crafting (it carries a grade).
function G.canUse(weapon)
    if not weapon or not weapon.getModData then return false end
    if TWAPartSystem and TWAPartSystem.IsMeleeWeapon and not TWAPartSystem.IsMeleeWeapon(weapon) then return false end
    local md = weapon:getModData()
    return md.TWA_Grade ~= nil and G.SLOTS_BY_GRADE[md.TWA_Grade] ~= nil and not md.TWA_Incomplete
end

function G.slotCount(weapon)
    return G.SLOTS_BY_GRADE[G.grade(weapon) or ""] or 0
end

function G.hasSpecial(weapon)
    return G.grade(weapon) == G.SPECIAL_GRADE
end

function G.sockets(weapon)
    return (weapon and weapon:getModData().TWA_Gems) or {}
end

-- The gem in socket `key` ("1".."5" or "sp"): fullType, state (or nil).
function G.gemIn(weapon, key)
    local s = G.sockets(weapon)
    key = tostring(key)
    return G.unpack(s[key], key == "sp" and s.spState or nil)
end

function G.filledCount(weapon)
    local s, n = G.sockets(weapon), 0
    for i = 1, G.slotCount(weapon) do if s[tostring(i)] then n = n + 1 end end
    if G.hasSpecial(weapon) and s.sp then n = n + 1 end
    return n
end

function G.totalSlots(weapon)
    return G.slotCount(weapon) + (G.hasSpecial(weapon) and 1 or 0)
end

function G.validKey(weapon, key)
    key = tostring(key)
    if key == "sp" then return G.hasSpecial(weapon) end
    local i = tonumber(key)
    return i ~= nil and i >= 1 and i <= G.slotCount(weapon) and math.floor(i) == i
end

-- Every socketed gem: list of { key, type, state }.
function G.list(weapon)
    local out = {}
    for i = 1, G.slotCount(weapon) do
        local t, st = G.gemIn(weapon, i)
        if t then out[#out + 1] = { key = tostring(i), type = t, state = st } end
    end
    if G.hasSpecial(weapon) then
        local t, st = G.gemIn(weapon, "sp")
        if t then out[#out + 1] = { key = "sp", type = t, state = st } end
    end
    return out
end

-- 2026-11-22 (owner: "อัญมณีห้ามใส่อันเดียวกันซ้ำ"): one weapon holds
-- each gem TYPE once, whatever its state. Returns the OTHER socket key that
-- already holds `gemType` (the socket being filled itself does not count, so
-- a better gem of the same type may still replace it there), else nil.
function G.dupeKey(weapon, key, gemType)
    key = tostring(key)
    for _, g in ipairs(G.list(weapon)) do
        if g.key ~= key and g.type == gemType then return g.key end
    end
    return nil
end

-- Sum of the socketed gems' abilities: { Field = amount }. `swap` (optional)
-- = { key, type, state } pretends that gem sits in that socket (the preview).
function G.totalBonus(weapon, swap)
    local sum = {}
    local list = G.list(weapon)
    if swap then
        local kept = {}
        for _, g in ipairs(list) do if g.key ~= swap.key then kept[#kept + 1] = g end end
        kept[#kept + 1] = swap
        list = kept
    end
    for _, g in ipairs(list) do
        for f, v in pairs(G.ability(g.type, g.state)) do sum[f] = (sum[f] or 0) + v end
    end
    return sum
end

-- Put the base damage + the gems' bonus on the weapon. No socket table at all:
-- the weapon is left alone (never touched by this system).
-- 1.0.10 (owner 2026-11-18: "durability back as it was, the step tiers
-- too"): 1.0.9 gave crafted weapons x2 max condition (md.TWA_Durability).
-- That is taken back once per weapon: the max goes back to the script's (+
-- gems) and the current condition is divided by the same factor, so a weapon
-- keeps the same share of its durability. The Toughness tiers never changed.
function G.undoDurability(item, md)
    local mul = tonumber(md.TWA_Durability) or 1
    md.TWA_Durability = nil
    if mul <= 1 or not (item.getCondition and item.setCondition) then return end
    local script = item.getScriptItem and item:getScriptItem()
    local base = (md.TWA_StatOverride or {}).ConditionMax
    if base == nil and script and script.getConditionMax then base = script:getConditionMax() end
    local max = base and (base + (md.TWA_Gems and (G.totalBonus(item).ConditionMax or 0) or 0)) or nil
    if max and item.setConditionMax then item:setConditionMax(max) end
    local before = item:getCondition()
    local c = math.ceil(before / mul)
    if max then c = math.min(c, max) end
    item:setCondition(c)
    TWALog("Socket", "%s: x%d durability taken back (condition %s -> %s, max %s)", TWALogType(item), mul, tostring(before), tostring(c), tostring(max))
end

-- 1.2.2 (owner 2026-11-20: "the gems' damage must not change the tier"):
-- the damage a weapon's TIER is judged on -- the live damage minus what its
-- gems add (TierTooltip and the socket page use it; the DPS shown with gems
-- stays the real one).
function G.tierDamage(item)
    local minD, maxD = item:getMinDamage(), item:getMaxDamage()
    local md = item.hasModData and item:hasModData() and item:getModData() or nil
    if md and md.TWA_Gems and not md.TWA_Incomplete then
        local b = G.totalBonus(item)
        minD = minD - (b.MinDamage or 0)
        maxD = maxD - (b.MaxDamage or 0)
    end
    return minD, maxD
end

-- 1.2.3 (damage x5/8 rebalance): a weapon of OURS made before keeps the old
-- damage on the item if the game saved it -> back to the script's (or the
-- admin override's) value. Only our item types; only when it differs; one
-- log line per type.
local synced = {}
local OUR_PREFIX = "HARMONIE_TheWayToAttack."
function G.syncScriptDamage(item, md)
    local ok, ft = pcall(function() return item:getFullType() end)
    if not ok or type(ft) ~= "string" or ft:sub(1, #OUR_PREFIX) ~= OUR_PREFIX then return end
    if not (item.setMinDamage and item.setMaxDamage) then return end
    local ov = md.TWA_StatOverride or {}
    local script = item.getScriptItem and item:getScriptItem()
    if not script then return end
    local changed = false
    for _, f in ipairs(G.FIELDS) do
        if f.key ~= "ConditionMax" then
            local base = ov[f.key]
            if base == nil and script[f.get] then base = script[f.get](script) end
            local now = item[f.get] and item[f.get](item)
            if base ~= nil and now ~= nil and math.abs(now - base) > 0.0001 then
                item[f.set](item, base)
                changed = true
            end
        end
    end
    if changed and not synced[ft] then
        synced[ft] = true
        TWALog("Socket", "%s carried old damage -- set to the current %s-%s", ft, tostring(item:getMinDamage()), tostring(item:getMaxDamage()))
    end
end

function G.applyDamage(item)
    if not item then return end
    local md = item:getModData()
    if md.TWA_Durability then G.undoDurability(item, md) end
    if md.TWA_Incomplete then return end
    if not md.TWA_Gems then G.syncScriptDamage(item, md) return end
    if not (item.setMinDamage and item.setMaxDamage) then return end
    local ov = md.TWA_StatOverride or {}
    local script = item.getScriptItem and item:getScriptItem()
    local bonus = G.totalBonus(item)
    for _, f in ipairs(G.FIELDS) do
        local base = ov[f.key]
        if base == nil and script and script[f.get] then base = script[f.get](script) end
        if base ~= nil and item[f.set] then item[f.set](item, base + (bonus[f.key] or 0)) end
    end
    -- never more condition than the (possibly lowered) maximum
    if item.getCondition and item.getConditionMax and item.setCondition and item:getCondition() > item:getConditionMax() then
        item:setCondition(item:getConditionMax())
    end
end

-- A change of ConditionMax from a gem also moves the current condition by
-- the same amount (a diamond set in makes the weapon that much tougher now).
local function applyKeepingCondition(weapon)
    local before = weapon.getConditionMax and weapon:getConditionMax()
    G.applyDamage(weapon)
    local after = weapon.getConditionMax and weapon:getConditionMax()
    if before and after and after > before and weapon.setCondition then
        weapon:setCondition(math.min(after, weapon:getCondition() + (after - before)))
    end
end

-- Server-side (or single player) work -------------------------------------

-- Round 22 ("สามารถเห็นไอเท็มบนพื้นแล้วกล่องรอบตัวได้"): the weapon and the
-- gems may be in the player's bags, a container nearby or on the floor
-- (TWASources, sandbox NearbyRadius).
local function findWeapon(player, id)
    local w = TWAWeaponDebug and TWAWeaponDebug.findById and TWAWeaponDebug.findById(player, id)
    if w then return w end
    return TWASources and TWASources.get(player):findById(id) or nil
end
G.findWeapon = findWeapon

-- A gem item of the player's (inventory, bags included) by id.
local function findGem(player, id)
    local it = id and TWASources.get(player):findById(id)
    if not it or not G.isGem(it:getFullType()) or TWACraftState.isBookmarked(it) then return nil end
    return it
end

-- Set gem `gemId` into socket `key`; returns true when done.
function G.doInsert(player, weapon, key, gemId)
    key = tostring(key)
    if not G.canUse(weapon) or not G.validKey(weapon, key) then
        TWALog("Socket", "insert REFUSED: weapon %s cannot take a gem in socket %s", TWALogType(weapon), key)
        return false
    end
    local gem = findGem(player, gemId)
    if not gem then TWALog("Socket", "insert REFUSED: gem id %s not found on %s", tostring(gemId), TWALogName(player)); return false end
    local gemType = gem:getFullType()
    local dk = G.dupeKey(weapon, key, gemType)
    if dk then
        TWALog("Socket", "insert REFUSED: %s already holds %s in socket %s (one of each gem type)", TWALogType(weapon), tostring(gemType), tostring(dk))
        return false
    end
    local md = weapon:getModData()
    md.TWA_Gems = md.TWA_Gems or {}
    local oldType, oldState = G.gemIn(weapon, key)
    local gemState = TWACraftState.gemState(gem) or "Raw"
    TWASources.remove(gem, player:getInventory())
    md.TWA_Gems[key] = G.pack(gemType, gemState)
    if key == "sp" then
        md.TWA_Gems.spState = nil
        -- the special socket's old gem comes back; a normal socket's is lost
        if oldType then G.giveGem(player, oldType, oldState) end
    end
    applyKeepingCondition(weapon)
    TWALog("Socket", "%s put %s (%s) into socket %s of %s%s", TWALogName(player), tostring(gemType), tostring(gemState), key,
        TWALogType(weapon), oldType and (" (replaced " .. tostring(oldType) .. ")") or "")
    return true
end

-- Empty the special socket; the gem goes back into the inventory.
function G.doRemove(player, weapon)
    if not G.canUse(weapon) or not G.hasSpecial(weapon) then TWALog("Socket", "remove REFUSED: no special socket on %s", TWALogType(weapon)); return false end
    local md = weapon:getModData()
    local old, st = G.gemIn(weapon, "sp")
    if not old then TWALog("Socket", "remove REFUSED: special socket already empty"); return false end
    TWALog("Socket", "%s took %s (%s) out of %s", TWALogName(player), tostring(old), tostring(st), TWALogType(weapon))
    md.TWA_Gems.sp, md.TWA_Gems.spState = nil, nil
    G.giveGem(player, old, st)
    applyKeepingCondition(weapon)
    return true
end

function G.giveGem(player, fullType, state)
    local inv = player:getInventory()
    local it = inv:AddItem(fullType)
    if not it then TWALog("Socket", "could NOT give gem %s back (unknown item?)", tostring(fullType)) end
    if it then
        if state then it:getModData().TWA_GemState = state end
        if isServer() and sendAddItemToContainer then sendAddItemToContainer(inv, it) end
    end
    return it
end

-- Client entry points --------------------------------------------------------

function G.requestInsert(player, weapon, key, gemItem)
    if not weapon or not gemItem then return end
    if isClient() then
        TWALog("Socket", "asking the server: insert %s into socket %s", TWALogType(gemItem), tostring(key))
        sendClientCommand(player, MODULE, "gemSocket", { op = "insert", id = weapon:getID(), key = tostring(key), gem = gemItem:getID() })
    else
        G.doInsert(player, weapon, key, gemItem:getID())
    end
end

function G.requestRemove(player, weapon)
    if not weapon then return end
    if isClient() then
        TWALog("Socket", "asking the server: remove the special gem")
        sendClientCommand(player, MODULE, "gemSocket", { op = "remove", id = weapon:getID() })
    else
        G.doRemove(player, weapon)
    end
end

-- Copy of a socket table for the network (plain strings only).
local function copy(t)
    local o = {}
    for k, v in pairs(t or {}) do o[k] = v end
    return o
end

if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= MODULE or command ~= "gemSocket" or not player or not args then return end
        local weapon = findWeapon(player, args.id)
        if not weapon then TWALog("Socket", "%s: weapon id %s not found -- %s ignored", TWALogName(player), tostring(args.id), tostring(args.op)); return end
        local ok
        if args.op == "insert" then ok = G.doInsert(player, weapon, args.key, args.gem)
        elseif args.op == "remove" then ok = G.doRemove(player, weapon) end
        if not ok then TWALog("Socket", "%s: %s on weapon id %s did nothing", TWALogName(player), tostring(args.op), tostring(args.id)) end
        if ok and sendServerCommand then
            sendServerCommand(player, MODULE, "gemSocketSync", { id = args.id, gems = copy(weapon:getModData().TWA_Gems) })
        end
    end)
end

if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= MODULE or command ~= "gemSocketSync" or not args then return end
        local player = getPlayer and getPlayer()
        local weapon = findWeapon(player, args.id)
        if not weapon then TWALog("Socket", "socket sync for weapon id %s: not in this inventory", tostring(args.id)); return end
        TWALog("Socket", "socket sync from the server for weapon id %s", tostring(args.id))
        weapon:getModData().TWA_Gems = copy(args.gems)
        G.applyDamage(weapon)
        if G.onSync then G.onSync(weapon) end
    end)
end

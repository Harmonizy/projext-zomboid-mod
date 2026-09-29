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
    { key = "MinDamage", get = "getMinDamage", set = "setMinDamage", label = "IGUI_TWA_Stat_MinDamage", fmt = "%.1f" },
    { key = "MaxDamage", get = "getMaxDamage", set = "setMaxDamage", label = "IGUI_TWA_Stat_MaxDamage", fmt = "%.1f" },
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
    if both then parts[1] = getText("IGUI_TWA_Socket_Damage") .. " +" .. string.format("%.1f", ab.MinDamage) end
    for _, f in ipairs(G.FIELDS) do
        local v = ab[f.key]
        local skip = both and (f.key == "MinDamage" or f.key == "MaxDamage")
        if v and v ~= 0 and not skip then parts[#parts + 1] = getText(f.label) .. " +" .. string.format(f.fmt, v) end
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
function G.applyDamage(item)
    if not item then return end
    local md = item:getModData()
    if not md.TWA_Gems or md.TWA_Incomplete then return end
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

local function findWeapon(player, id)
    if TWAWeaponDebug and TWAWeaponDebug.findById then return TWAWeaponDebug.findById(player, id) end
    return nil
end

-- A gem item of the player's (inventory, bags included) by id.
local function findGem(player, id)
    local it = id and TWACraftState.resolveItem(player, id)
    if not it or not G.isGem(it:getFullType()) or TWACraftState.isBookmarked(it) then return nil end
    local c = it.getContainer and it:getContainer()
    if not c or not c:isInCharacterInventory(player) then return nil end -- the player's own gems only
    return it
end

-- Set gem `gemId` into socket `key`; returns true when done.
function G.doInsert(player, weapon, key, gemId)
    key = tostring(key)
    if not G.canUse(weapon) or not G.validKey(weapon, key) then return false end
    local gem = findGem(player, gemId)
    if not gem then return false end
    local md = weapon:getModData()
    md.TWA_Gems = md.TWA_Gems or {}
    local oldType, oldState = G.gemIn(weapon, key)
    local gemType = gem:getFullType()
    local gemState = TWACraftState.gemState(gem) or "Raw"
    TWASources.remove(gem, player:getInventory())
    md.TWA_Gems[key] = G.pack(gemType, gemState)
    if key == "sp" then
        md.TWA_Gems.spState = nil
        -- the special socket's old gem comes back; a normal socket's is lost
        if oldType then G.giveGem(player, oldType, oldState) end
    end
    applyKeepingCondition(weapon)
    return true
end

-- Empty the special socket; the gem goes back into the inventory.
function G.doRemove(player, weapon)
    if not G.canUse(weapon) or not G.hasSpecial(weapon) then return false end
    local md = weapon:getModData()
    local old, st = G.gemIn(weapon, "sp")
    if not old then return false end
    md.TWA_Gems.sp, md.TWA_Gems.spState = nil, nil
    G.giveGem(player, old, st)
    applyKeepingCondition(weapon)
    return true
end

function G.giveGem(player, fullType, state)
    local inv = player:getInventory()
    local it = inv:AddItem(fullType)
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
        sendClientCommand(player, MODULE, "gemSocket", { op = "insert", id = weapon:getID(), key = tostring(key), gem = gemItem:getID() })
    else
        G.doInsert(player, weapon, key, gemItem:getID())
    end
end

function G.requestRemove(player, weapon)
    if not weapon then return end
    if isClient() then
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
        if not weapon then return end
        local ok
        if args.op == "insert" then ok = G.doInsert(player, weapon, args.key, args.gem)
        elseif args.op == "remove" then ok = G.doRemove(player, weapon) end
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
        if not weapon then return end
        weapon:getModData().TWA_Gems = copy(args.gems)
        G.applyDamage(weapon)
        if G.onSync then G.onSync(weapon) end
    end)
end

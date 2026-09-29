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
G.DEFAULT_BONUS = { min = 0.1, max = 0.1 }
G.DIAMOND_BONUS = { min = 1, max = 1 }

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

function G.bonus(fullType)
    if fullType == TWARecipeData.GemRoll.diamond then return G.DIAMOND_BONUS end
    return G.DEFAULT_BONUS
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

-- The gem in socket `key` ("1".."5" or "sp"), or nil.
function G.gemIn(weapon, key)
    return G.sockets(weapon)[tostring(key)]
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

-- Sum of the socketed gems' bonuses.
function G.totalBonus(weapon)
    local s = G.sockets(weapon)
    local mn, mx = 0, 0
    local function add(t)
        if t then local b = G.bonus(t); mn, mx = mn + b.min, mx + b.max end
    end
    for i = 1, G.slotCount(weapon) do add(s[tostring(i)]) end
    if G.hasSpecial(weapon) then add(s.sp) end
    return mn, mx
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
    local baseMin = ov.MinDamage or (script and script.getMinDamage and script:getMinDamage())
    local baseMax = ov.MaxDamage or (script and script.getMaxDamage and script:getMaxDamage())
    if not baseMin or not baseMax then return end
    local bmin, bmax = G.totalBonus(item)
    item:setMinDamage(baseMin + bmin)
    item:setMaxDamage(baseMax + bmax)
end

-- Server-side (or single player) work -------------------------------------

local function findWeapon(player, id)
    if TWAWeaponDebug and TWAWeaponDebug.findById then return TWAWeaponDebug.findById(player, id) end
    return nil
end

-- A gem item of the player's (inventory, bags included) by id.
local function findGem(player, id)
    local it = id and TWACraftState.resolveItem(player, id)
    if not it or not G.isGem(it:getFullType()) then return nil end
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
    local old = md.TWA_Gems[key]
    local oldState = key == "sp" and md.TWA_Gems.spState or nil
    local gemType = gem:getFullType()
    local gemState = gem:getModData().TWA_GemState
    TWASources.remove(gem, player:getInventory())
    md.TWA_Gems[key] = gemType
    if key == "sp" then
        md.TWA_Gems.spState = gemState
        -- the special socket's old gem comes back; a normal socket's is lost
        if old then G.giveGem(player, old, oldState) end
    end
    G.applyDamage(weapon)
    return true
end

-- Empty the special socket; the gem goes back into the inventory.
function G.doRemove(player, weapon)
    if not G.canUse(weapon) or not G.hasSpecial(weapon) then return false end
    local md = weapon:getModData()
    local old = md.TWA_Gems and md.TWA_Gems.sp
    if not old then return false end
    local st = md.TWA_Gems.spState
    md.TWA_Gems.sp, md.TWA_Gems.spState = nil, nil
    G.giveGem(player, old, st)
    G.applyDamage(weapon)
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

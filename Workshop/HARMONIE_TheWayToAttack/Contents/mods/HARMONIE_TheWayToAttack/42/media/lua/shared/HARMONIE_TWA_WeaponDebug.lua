--============================================================================
-- HARMONIE_TheWayToAttack -- weapon stat debug editor, shared part
--
-- Round 11 (request 2026-09-28: "อยากทำ ดีบักอาวุธ ... คลิกขวาที่อาวุธและมี
-- สิทธิแอดมินหรือเปิด -debug ต้องสามารถปรับแต่ง stats ได้ทุกประเภทที่อาวุธมี
-- และจากของเราด้วย ต้องรองรับ mp และต้องปรับ stats จริงๆ เพราะฉันใช้ของ vanilla
-- แล้ว stats ใน tooltip เปลี่ยนจริง แต่เหมือนไม่ส่งผลเลย").
--
-- Why an edit can show in the tooltip yet do nothing:
--   1. In multiplayer the SERVER's copy of the weapon is the one combat
--      trusts; editing only the client copy changes the tooltip and nothing
--      else. Here the edit goes to the server, which applies it and sends it
--      back, so both copies agree.
--   2. A HandWeapon's per-item stats are not guaranteed to survive a reload
--      (or anything else that refreshes the item from its script). Here the
--      edit is also stored in the item's ModData (TWA_StatOverride) and put
--      back on the weapon when it is equipped, when a game loads and --
--      most importantly -- at OnWeaponSwingHitPoint, right before the game
--      rolls the hit's damage between MinDamage and MaxDamage.
--   3. MaxDamage reads back through the blade's sharpness (shown = min +
--      (raw - min) * sharpness multiplier); the editor sets the RAW value, so
--      what the roll uses is exactly what was typed at full sharpness.
--
-- Every field is used only if the item really has both its getter and its
-- setter (checked by name first -- never pcall, the debugger stops on it).
--============================================================================

require "HARMONIE_TWA_Config"
require "HARMONIE_TWA_CraftState"

TWAWeaponDebug = TWAWeaponDebug or {}
local W = TWAWeaponDebug

-- kind: "num" / "int" / "bool". get/set: method names.
W.FIELDS = {
    { key = "MinDamage", kind = "num", get = "getMinDamage", set = "setMinDamage" },
    { key = "MaxDamage", kind = "num", get = "getMaxDamage", set = "setMaxDamage", raw = true },
    { key = "MinRange", kind = "num", get = "getMinRange", set = "setMinRange" },
    { key = "MaxRange", kind = "num", get = "getMaxRange", set = "setMaxRange" },
    { key = "BaseSpeed", kind = "num", get = "getBaseSpeed", set = "setBaseSpeed" },
    { key = "CriticalChance", kind = "num", get = "getCriticalChance", set = "setCriticalChance" },
    { key = "CritDmgMultiplier", kind = "num", get = "getCritDmgMultiplier", set = "setCritDmgMultiplier" },
    { key = "KnockdownMod", kind = "num", get = "getKnockdownMod", set = "setKnockdownMod" },
    { key = "PushBackMod", kind = "num", get = "getPushBackMod", set = "setPushBackMod" },
    { key = "MaxHitCount", kind = "int", get = "getMaxHitCount", set = "setMaxHitCount" },
    { key = "MinAngle", kind = "num", get = "getMinAngle", set = "setMinAngle" },
    { key = "SwingTime", kind = "num", get = "getSwingTime", set = "setSwingTime" },
    { key = "MinimumSwingTime", kind = "num", get = "getMinimumSwingTime", set = "setMinimumSwingTime" },
    { key = "EnduranceMod", kind = "num", get = "getEnduranceMod", set = "setEnduranceMod" },
    { key = "TreeDamage", kind = "int", get = "getTreeDamage", set = "setTreeDamage" },
    { key = "DoorDamage", kind = "int", get = "getDoorDamage", set = "setDoorDamage" },
    { key = "Sharpness", kind = "num", get = "getSharpness", set = "setSharpness" },
    { key = "ConditionMax", kind = "int", get = "getConditionMax", set = "setConditionMax" },
    { key = "Condition", kind = "int", get = "getCondition", set = "setCondition" },
    { key = "ConditionLowerChance", kind = "int", get = "getConditionLowerChance", set = "setConditionLowerChance" },
    { key = "Weight", kind = "num", get = "getActualWeight", set = "setActualWeight" },
    { key = "KnockBackOnNoDeath", kind = "bool", get = "isKnockBackOnNoDeath", set = "setKnockBackOnNoDeath" },
    { key = "AlwaysKnockdown", kind = "bool", get = "isAlwaysKnockdown", set = "setAlwaysKnockdown" },
    { key = "SplatBloodOnNoDeath", kind = "bool", get = "isSplatBloodOnNoDeath", set = "setSplatBloodOnNoDeath" },
    { key = "TwoHandWeapon", kind = "bool", get = "isTwoHandWeapon", set = "setTwoHandWeapon" },
}
-- This mod's own values on the item (ModData).
W.OURS = {
    { key = "TWA_Grade", kind = "choice", choices = { "", "S", "A", "B", "C", "D", "E", "F" } },
    { key = "TWA_Quality", kind = "choice", choices = { "", "Excellent", "Good", "Bad" } },
    { key = "TWA_CraftedBy", kind = "text" },
    { key = "TWA_Incomplete", kind = "bool" },
}

function W.hasField(item, f)
    return item ~= nil and item[f.get] ~= nil and item[f.set] ~= nil
end

function W.fieldsOf(item)
    local out = {}
    for _, f in ipairs(W.FIELDS) do if W.hasField(item, f) then out[#out + 1] = f end end
    return out
end

-- MaxDamage without the sharpness factor (see header, point 3).
local function rawMaxDamage(item)
    local shown, min = item:getMaxDamage(), item:getMinDamage()
    if item.hasSharpness and item:hasSharpness() and item.getSharpnessMultiplier and shown > min then
        local m = item:getSharpnessMultiplier()
        if m and m > 0 then return min + (shown - min) / m end
    end
    return shown
end

function W.read(item, f)
    if f.raw then return rawMaxDamage(item) end
    return item[f.get](item)
end

local function coerce(f, v)
    if f.kind == "bool" then return v == true or v == "true" end
    local n = tonumber(v)
    if not n then return nil end
    if f.kind == "int" then n = math.floor(n + 0.5) end
    return n
end

-- 2026-10-02: B42 roles -- an ordinary player's access level is "user"
-- (not "None"), so "anything but none" let every player through. Only
-- these staff roles count (same names EHR's server checks use).
local STAFF_ROLES = { admin = true, moderator = true, overseer = true, gm = true }
local function isStaff(player)
    local ok, lvl = pcall(function() return player:getAccessLevel() end)
    return ok and lvl ~= nil and STAFF_ROLES[string.lower(tostring(lvl))] == true
end

function W.isAllowed(player)
    if not TWAConfig.on("AllowWeaponDebug") then return false end
    if not player then return false end
    -- Round 25: on a server the -debug / isAdmin() globals describe the
    -- SERVER (and on its clients, only that client), not the player -- in
    -- multiplayer only the player's own staff role counts.
    local mp = (isServer and isServer()) or (isClient and isClient())
    if not mp then
        if isDebugEnabled and isDebugEnabled() then return true end
        if isAdmin and isAdmin() then return true end
    end
    return isStaff(player)
end

-- Put the stored overrides back on the weapon (also the unfinished item's 0
-- damage). Cheap; safe to call on every swing.
function W.reapply(item)
    if not item then return end
    local md = item:getModData()
    local ov = md.TWA_StatOverride
    if ov then
        for _, f in ipairs(W.FIELDS) do
            local v = ov[f.key]
            if v ~= nil and W.hasField(item, f) then item[f.set](item, v) end
        end
    end
    -- Round 18: socketed gems add their damage on top (TWAGemSocket).
    if TWAGemSocket and TWAGemSocket.applyDamage then TWAGemSocket.applyDamage(item) end
    TWACraftState.applyIncomplete(item)
end

-- Apply edited values: `values` {key = value} for weapon fields and this
-- mod's ModData keys; `reset` = forget every override and go back to the
-- item script's own values. Runs where the authoritative item lives.
function W.apply(item, values, reset)
    if not item then return end
    local md = item:getModData()
    if reset then
        md.TWA_StatOverride = nil
        local script = item.getScriptItem and item:getScriptItem()
        if script then
            for _, f in ipairs(W.FIELDS) do
                if W.hasField(item, f) and script[f.get] ~= nil and f.key ~= "Condition" and f.key ~= "Sharpness" then
                    item[f.set](item, script[f.get](script))
                end
            end
        end
        if TWAGemSocket and TWAGemSocket.applyDamage then TWAGemSocket.applyDamage(item) end -- round 18
        return
    end
    md.TWA_StatOverride = md.TWA_StatOverride or {}
    for _, f in ipairs(W.FIELDS) do
        local v = values[f.key]
        if v ~= nil and W.hasField(item, f) then
            v = coerce(f, v)
            if v ~= nil then
                item[f.set](item, v)
                -- Condition and sharpness wear down in use: set once, not pinned.
                if f.key ~= "Condition" and f.key ~= "Sharpness" then md.TWA_StatOverride[f.key] = v end
            end
        end
    end
    for _, o in ipairs(W.OURS) do
        local v = values[o.key]
        if v ~= nil then
            if o.kind == "bool" then v = (v == true or v == "true") or nil
            elseif v == "" then v = nil end
            md[o.key] = v
        end
    end
    W.reapply(item)
end

-- Networking --------------------------------------------------------------
local MODULE = "HARMONIE_TWA"

local function findById(player, id)
    local inv = player and player:getInventory()
    if not inv or not id then return nil end
    for _, m in ipairs({ "getItemWithIDRecursiv", "getItemById", "getItemWithID" }) do
        if inv[m] then
            local it = inv[m](inv, id)
            if it then return it end
        end
    end
    return nil
end
W.findById = findById

--- Client entry point: edit `item` (in `player`'s inventory).
function W.request(player, item, values, reset)
    if not W.isAllowed(player) then return end
    if isClient() then
        sendClientCommand(player, MODULE, "debugWeapon", { id = item:getID(), values = values, reset = reset and true or false })
    else
        W.apply(item, values, reset)
    end
end

if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= MODULE or command ~= "debugWeapon" or not player or not args then return end
        if not W.isAllowed(player) then return end
        local item = findById(player, args.id)
        if not item then return end
        W.apply(item, args.values or {}, args.reset)
        -- Tell the owner's client to make its copy match.
        if sendServerCommand then
            sendServerCommand(player, MODULE, "debugWeapon", { id = args.id, values = args.values or {}, reset = args.reset })
        end
    end)
end

if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= MODULE or command ~= "debugWeapon" or not args then return end
        local player = getPlayer and getPlayer()
        local item = findById(player, args.id)
        if item then W.apply(item, args.values or {}, args.reset) end
    end)
end

-- Keep overrides in force ---------------------------------------------------
if Events and Events.OnWeaponSwingHitPoint then
    Events.OnWeaponSwingHitPoint.Add(function(character, weapon)
        if weapon then W.reapply(weapon) end
    end)
end
if Events and Events.OnEquipPrimary then
    Events.OnEquipPrimary.Add(function(character, item)
        if item then W.reapply(item) end
    end)
end
if Events and Events.OnGameStart and getPlayer then
    Events.OnGameStart.Add(function()
        local p = getPlayer()
        local item = p and p:getPrimaryHandItem()
        if item then W.reapply(item) end
    end)
end

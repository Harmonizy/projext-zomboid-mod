--============================================================================
-- HARMONIE_TheWayToAttack -- admin helpers for the crafting window (shared)
--
-- Request 2026-10-02: buttons only an admin sees in the crafting window --
--   "items":  spawn what the selected recipe still lacks: the base item
--             and the supplementary item, every procedure's tools (one of
--             each kind) and materials (added up over all its procedures)
--   "skills": raise each skill to the highest level the recipe's
--             procedures ask for
-- Only what is MISSING is given (nearby containers count, like crafting
-- itself). A forge / light requirement can't be spawned.
--
-- MULTIPLAYER: the client sends ("HARMONIE_TWA", "adminGrant",
-- { recipeId, what }); the server checks the SENDER's access level (not
-- isAdmin(), which describes the server itself) and does the work: items
-- with AddItem + sendAddItemToContainer, skills on the server's player and
-- echoed to the client ("adminSkills") so the window updates at once.
--============================================================================

require "HARMONIE_TWA_Procedures"
require "HARMONIE_TWA_CraftState"

TWAAdminGrant = TWAAdminGrant or {}
local A = TWAAdminGrant
local S = TWACraftState
local P = TWAProcedures

A.NET = "HARMONIE_TWA"

-- a real item for a tool given by tag (first one this game has)
A.TAG_ITEMS = {
    HAMMER = { "Base.Hammer", "Base.BallPeenHammer" },
    CLUB_HAMMER = { "Base.ClubHammer" },
    SLEDGEHAMMER = { "Base.Sledgehammer", "Base.Sledgehammer2" },
    SAW = { "Base.Saw", "Base.GardenSaw" },
    SCREWDRIVER = { "Base.Screwdriver" },
    SHARP_KNIFE = { "Base.KitchenKnife", "Base.HuntingKnife" },
    WELDING_MASK = { "Base.WeldingMask" },
    WRENCH = { "Base.Wrench", "Base.PipeWrench" },
}

local function exists(fullType)
    local sm = getScriptManager and getScriptManager()
    if not sm then return true end
    local ok, it = pcall(function() return sm:FindItem(fullType) end)
    return ok and it ~= nil
end

local function firstExisting(list)
    for _, t in ipairs(list or {}) do if exists(t) then return t end end
    return nil
end

-- who may use it: the player's own access level (on a server), or an admin
-- / -debug game locally
function A.isAllowed(player)
    if isServer and isServer() then
        local ok, lvl = pcall(function() return player:getAccessLevel() end)
        return ok and lvl ~= nil and lvl ~= "" and string.lower(tostring(lvl)) ~= "none"
    end
    if isDebugEnabled and isDebugEnabled() then return true end
    if isAdmin and isAdmin() then return true end
    local ok, lvl = pcall(function() return player:getAccessLevel() end)
    return ok and lvl ~= nil and lvl ~= "" and string.lower(tostring(lvl)) ~= "none"
end

local function procsOf(recipe)
    local out = {}
    for _, pid in ipairs(recipe and recipe.procedures or {}) do
        local proc = P.List[pid]
        if proc then out[#out + 1] = proc end
    end
    return out
end

local function toolType(spec)
    for _, s in ipairs(P.ToolAlts(spec) or {}) do
        local t
        if s.kind == "type" then t = firstExisting({ s.value }) or firstExisting(P.Family and P.Family(s.value) or {})
        elseif s.kind == "tag" then t = firstExisting(A.TAG_ITEMS[s.value]) end
        if t then return t end
    end
    return nil
end

local function countIn(src, types)
    local n = 0
    for _, t in ipairs(types or {}) do n = n + (src:getItemCountRecurse(t) or 0) end
    return n
end

local function hasTool(spec, player)
    local ok, missing = P.CheckEligibility({ tool = spec }, player, true)
    return ok
end

-- -> { { type = fullType, qty = n }, ... } still missing for `recipe`
function A.missingItems(player, recipe)
    local out, add = {}, {}
    local function want(t, q)
        if not t or q <= 0 then return end
        if not add[t] then add[t] = 0; out[#out + 1] = t end
        add[t] = add[t] + q
    end
    local src = TWASources.get(player)
    -- base / supplementary item
    if recipe.base then
        local types = S.baseTypes(recipe)
        local have = 0
        for _, t in ipairs(types) do have = have + (S.countBase(player, recipe, t) or 0) end
        if have < 1 then want(firstExisting(types), 1) end
    end
    if recipe.base2 then
        local types = type(recipe.base2) == "table" and recipe.base2 or { recipe.base2 }
        if countIn(src, types) < 1 then want(firstExisting(types), 1) end
    end
    -- tools: one of each kind, materials: added up over the procedures
    local toolSeen, need = {}, {}
    for _, proc in ipairs(procsOf(recipe)) do
        for _, spec in ipairs({ proc.tool, proc.tool2 }) do
            if spec then
                local t = toolType(spec)
                if t and not toolSeen[t] and not hasTool(spec, player) then
                    toolSeen[t] = true
                    want(t, 1)
                end
            end
        end
        for _, c in ipairs(proc.consumes or {}) do
            local slot = c
            if c.options then
                -- any option already covered -> nothing to add for this slot
                slot = c.options[1]
                for _, opt in ipairs(c.options) do
                    if countIn(src, P.AltTypes(opt)) >= (tonumber(opt.qty) or 1) then slot = nil break end
                end
            end
            local types = slot and P.AltTypes(slot) or {}
            local key = types[1]
            if key then
                need[key] = need[key] or { types = types, qty = 0 }
                need[key].qty = need[key].qty + (tonumber(slot.qty) or 1)
            end
        end
    end
    for key, n in pairs(need) do
        local have = countIn(src, n.types)
        want(firstExisting({ key }) or firstExisting(n.types), n.qty - have)
    end
    local list = {}
    for _, t in ipairs(out) do list[#list + 1] = { type = t, qty = add[t] } end
    return list
end

-- -> { [PerkName] = level } the recipe asks for that the player is below
function A.missingSkills(player, recipe)
    local out = {}
    for _, proc in ipairs(procsOf(recipe)) do
        local name, lvl = tostring(proc.skill or ""):match("^(%a+):(%d+)$")
        lvl = tonumber(lvl)
        local perk = name and Perks and Perks[name]
        if perk and lvl and player:getPerkLevel(perk) < lvl and lvl > (out[name] or 0) then out[name] = lvl end
    end
    return out
end

function A.setSkills(player, levels)
    for name, lvl in pairs(levels or {}) do
        local perk = Perks and Perks[name]
        if perk and player:getPerkLevel(perk) < lvl then
            pcall(function() player:getXp():setXPToLevel(perk, lvl) end)
            pcall(function() player:setPerkLevelDebug(perk, lvl) end)
        end
    end
end

-- the work, where the authority is (server in MP, here in SP)
function A.grant(player, recipeId, what)
    local recipe = S.getRecipeById(recipeId)
    if not player or not recipe or not A.isAllowed(player) then return false end
    TWASources.forget(player)
    if what == "items" then
        local inv = player:getInventory()
        for _, e in ipairs(A.missingItems(player, recipe)) do
            for _ = 1, e.qty do
                local it = inv:AddItem(e.type)
                if it and isServer() and sendAddItemToContainer then sendAddItemToContainer(inv, it) end
            end
        end
    elseif what == "skills" then
        local levels = A.missingSkills(player, recipe)
        A.setSkills(player, levels)
        if isServer() and sendServerCommand then sendServerCommand(player, A.NET, "adminSkills", { levels = levels }) end
    end
    TWASources.forget(player)
    return true
end

function A.request(player, recipeId, what)
    if isClient() then
        sendClientCommand(player, A.NET, "adminGrant", { recipeId = recipeId, what = what })
    else
        A.grant(player, recipeId, what)
    end
end

if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= A.NET or command ~= "adminGrant" or not player or type(args) ~= "table" then return end
        if args.what ~= "items" and args.what ~= "skills" then return end
        A.grant(player, args.recipeId, args.what)
    end)
end
if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= A.NET or command ~= "adminSkills" or type(args) ~= "table" then return end
        local p = getPlayer and getPlayer()
        if p then A.setSkills(p, args.levels) end
    end)
end

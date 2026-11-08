--[[
    HARMONIE - Life With Style: fashion never turns up in the world (0.7.16).

    Our fashion pieces reuse vanilla clothing models (ClothingItem = the
    vanilla one). The game keeps ONE item type per clothing model and uses it
    to turn a zombie's clothes into items, so a model shared with a fashion
    piece may come out of a zombie as OUR weightless, protect-nothing piece
    instead of the real vanilla item. This file:
      * at start, finds the vanilla twin (module Base, same ClothingItem) of
        every fashion piece and logs which models the game maps to OUR item;
      * on a zombie's death (server / single player), turns any fashion type
        in its clothes or its inventory back into the vanilla twin;
      * LWS.Server.ensure gives a player the vanilla twin for a fashion item
        that came from the world (no owner mark) instead of only deleting it.
    No loot table ever lists a fashion piece (see CLAUDE.md).
]]
LWS = LWS or {}
local G = {}
LWS.WorldGuard = G

local function log(fmt, ...) LWS.log("WorldGuard", fmt, ...) end

-- our full type -> vanilla full type (false: no vanilla twin)
G.twin = nil

function G.build()
    G.twin = {}
    local sm = (ScriptManager and ScriptManager.instance) or (getScriptManager and getScriptManager())
    if not sm or not sm.getAllItems then
        log("no ScriptManager:getAllItems -- the world guard cannot find vanilla twins")
        return
    end
    local ok, all = pcall(function() return sm:getAllItems() end)
    if not ok or not all then log("getAllItems failed: %s", tostring(all)); return end
    local vanilla, ours = {}, {}
    for i = 0, all:size() - 1 do
        local it = all:get(i)
        local okC, ci = pcall(function() return it.getClothingItem and it:getClothingItem() end)
        if okC and ci and tostring(ci) ~= "" then
            ci = tostring(ci)
            local mod = tostring(it:getModuleName())
            local full = tostring(it:getFullName())
            if mod == LWS.MODULE then
                ours[#ours + 1] = { full, ci }
            elseif mod == "Base" and not vanilla[ci] then
                vanilla[ci] = full
            end
        end
    end
    local taken, lonely = {}, {}
    for _, o in ipairs(ours) do
        G.twin[o[1]] = vanilla[o[2]] or false
        if not vanilla[o[2]] then lonely[#lonely + 1] = o[1] end
        if sm.getItemTypeForClothingItem then
            local okT, t = pcall(function() return sm:getItemTypeForClothingItem(o[2]) end)
            if okT and t and tostring(t) == o[1] then taken[#taken + 1] = o[2] end
        end
    end
    log("%d fashion items share a vanilla clothing model; the game maps %d of those models to OUR item%s; no vanilla twin: %s",
        #ours, #taken, #taken > 0 and (" (fixed on zombie death: " .. table.concat(taken, ", ") .. ")") or "",
        #lonely > 0 and table.concat(lonely, ", ") or "none")
end

function G.twinOf(fullType)
    if not G.twin then G.build() end
    return G.twin[tostring(fullType or "")]
end

-- a zombie's clothes and inventory: fashion -> the vanilla twin
function G.onZombieDead(zombie)
    -- only the server (or single player) changes corpse loot; the corpse
    -- container reaches clients by the game's own death sync
    if isClient and isClient() then return end
    if not zombie then return end
    if not G.twin then G.build() end
    local visuals, items = 0, 0
    pcall(function()
        local vis = zombie:getItemVisuals()
        for i = 0, vis:size() - 1 do
            local v = vis:get(i)
            local t = v and v.getItemType and v:getItemType()
            local tw = t and G.twin[tostring(t)]
            if tw then
                if v.setItemType then
                    v:setItemType(tw)
                    visuals = visuals + 1
                else
                    LWS.logOnce("wg_novisualset", "WorldGuard", "ItemVisual has no setItemType -- zombie clothes %s not changed", tostring(t))
                end
            end
        end
    end)
    pcall(function()
        local inv = zombie:getInventory()
        local list, its = {}, inv:getItems()
        for i = 0, its:size() - 1 do
            local it = its:get(i)
            if LWS.isFashion(it) then list[#list + 1] = it end
        end
        for _, it in ipairs(list) do
            local tw = G.twinOf(LWS.typeOf(it))
            pcall(function() inv:Remove(it) end)
            if tw then pcall(function() inv:AddItem(tw) end) end
            items = items + 1
        end
    end)
    if visuals > 0 or items > 0 then
        log("zombie died wearing fashion types: %d clothes and %d items turned back into vanilla", visuals, items)
    end
end

if Events then
    if Events.OnGameStart then Events.OnGameStart.Add(function() if not G.twin then G.build() end end) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(function() if not G.twin then G.build() end end) end
    if Events.OnZombieDead then Events.OnZombieDead.Add(G.onZombieDead) end
end

return G

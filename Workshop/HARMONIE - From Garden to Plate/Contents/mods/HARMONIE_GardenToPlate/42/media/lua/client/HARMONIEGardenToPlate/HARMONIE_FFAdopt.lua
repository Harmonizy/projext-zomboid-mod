-- HARMONIE - From Garden to Plate: right-click a Fruit Farming tree that was
-- placed (Brush Tool / map) rather than planted -> "Tend this fruit tree":
-- the server turns it into a real plant (server/Farming/FF_adoptTree.lua),
-- after which vanilla's own Crops menu (Harvest, Water, Info...) works on it.
local NET = "HARMONIE_GTP_FF"

local function log(fmt, ...)
    local G = HARMONIE_GTP
    if G and G.Log then pcall(G.Log, "FruitFarming", fmt, ...) end
end

local function T(key, fallback)
    local t = getText(key)
    if not t or t == key then return fallback end
    return t
end

local function placedTree(worldobjects)
    for _, o in ipairs(worldobjects or {}) do
        local sq = o and o.getSquare and o:getSquare()
        if sq then
            local objs = sq:getObjects()
            for i = 0, objs:size() - 1 do
                local obj = objs:get(i)
                local spr = obj and obj.getSprite and obj:getSprite()
                local name = spr and spr.getName and spr:getName()
                if type(name) == "string" and name:match("^ff_[%w]+_%d+_%d+$") then
                    local plant = CFarmingSystem and CFarmingSystem.instance and CFarmingSystem.instance:getLuaObjectOnSquare(sq)
                    if not plant then return sq, name end
                end
            end
        end
    end
    return nil
end

local function onMenu(playerNum, context, worldobjects, test)
    local ok, sq, name = pcall(placedTree, worldobjects)
    if not ok or not sq then return end
    if test then return true end
    local player = getSpecificPlayer(playerNum)
    local opt = context:addOption(T("ContextMenu_HARMONIE_FFAdopt", "Tend this fruit tree"), sq, function(square)
        log("asking to turn the placed %s at %d,%d into a real plant", tostring(name), square:getX(), square:getY())
        sendClientCommand(player, NET, "adopt", { x = square:getX(), y = square:getY(), z = square:getZ() })
    end)
    local tip = ISToolTip:new()
    tip:initialise()
    tip.description = T("Tooltip_HARMONIE_FFAdopt", "This tree was placed, not planted, so it cannot grow or be harvested yet. Tend it to make it a real fruit tree; then use its Crops menu.")
    opt.toolTip = tip
end

Events.OnFillWorldObjectContextMenu.Add((HARMONIE_Ours or function(f) return f end)(onMenu, "GTP"))

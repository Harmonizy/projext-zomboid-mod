--[[
    HARMONIE - From Garden to Plate: open the Cooking tab from a kitchen
    appliance (0.13.2, owner: "สามารถกดคลิกขาเปิดผ่านอุปกรณ์ทำอาหารได้ เช่น
    เตา กองไฟ ตู้เย็น และอื่นๆ").

    Right-clicking a stove, oven, microwave, fireplace, grill, campfire,
    fridge or freezer adds "Cooking (Garden to Plate)" to the menu; it opens
    the guide window straight on its Cooking tab. What counts as a heat
    source is K.heatKind (HARMONIE_CookCore.lua) -- the same check the hot
    steps use -- plus the cold and microwave containers here.
]]--

require "HARMONIEGardenToPlate/HARMONIE_CookCore"
require "HARMONIEGardenToPlate/HARMONIE_VitaminGuide"

local K = HARMONIE_GTP.Cook
local log = function(...) K.log(...) end

-- containers that are kitchen appliances without being a heat source
local APPLIANCE_CONTAINERS = { fridge = true, freezer = true, microwave = true }

local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end

-- what kind of appliance an object is (for the log), or nil
local function applianceOf(obj)
    if not obj then return nil end
    local cont = call(obj, "getContainer")
    local ct = cont and tostring(call(cont, "getType") or "") or ""
    if APPLIANCE_CONTAINERS[ct] then return ct end
    local ok, kind = pcall(K.heatKind, obj)
    if ok and kind then return kind end
    -- a fridge with a freezer keeps its second container apart
    local n = tonumber(call(obj, "getContainerCount")) or 0
    for i = 0, n - 1 do
        local c = call(obj, "getContainerByIndex", i)
        local t = c and tostring(call(c, "getType") or "") or ""
        if APPLIANCE_CONTAINERS[t] then return t end
    end
    return nil
end

local function findAppliance(worldobjects)
    for _, obj in ipairs(worldobjects or {}) do
        local kind = applianceOf(obj)
        if kind then return kind end
        -- the click may land on the floor tile of a stove: look at its square
        local sq = call(obj, "getSquare")
        local objs = sq and call(sq, "getObjects")
        for i = 0, (objs and objs:size() or 0) - 1 do
            kind = applianceOf(objs:get(i))
            if kind then return kind end
        end
    end
    return nil
end

local function onWorldMenu(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer and getSpecificPlayer(playerNum)
    if not player or not context then return end
    local ok, kind = pcall(findAppliance, worldobjects)
    if not ok then
        K.logOnce("ctxfail", "appliance right-click check FAILED: %s", tostring(kind))
        return
    end
    if not kind then return end
    K.logOnce("ctx:" .. tostring(kind), "right-click menu on a %s offers the Cooking tab (repeats not logged)", tostring(kind))
    local option = context:addOption(getText("IGUI_GTPC_OpenFromAppliance"), player, function(p)
        log("opened the Cooking tab from a %s (right-click)", tostring(kind))
        GTPGuide.open(p, nil, "cook")
    end)
    local tex = getTexture and getTexture("media/textures/GTP_UI/tab_cook.png")
    if option and tex then option.iconTexture = tex end
end

if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(onWorldMenu)
end

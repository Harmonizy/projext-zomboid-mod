--[[
    HARMONIE - The Way To Attack 1.2.5: Inventory Tetris sizes (owner
    2026-11-20: "can the Material Lump stack 5?").

    Vanilla has no stack limit (items of a type are just grouped). The owner's
    server runs Inventory Tetris, which gives every item a grid size and a
    max stack. This registers ours when that mod is loaded:
      * TWA_MaterialLump: 1x1, stack 5 (owner).
    Registered through TetrisItemData.registerItemDefinitions(pack), pack =
    { [fullType] = { width, height, maxStackSize } } -- the function is
    TESTED first (its shape is from memory, not from the mod's source: the
    console says which way it went). Without Inventory Tetris nothing happens.
]]--

TWATetris = TWATetris or {}
local T = TWATetris
local log = function(fmt, ...) if TWALog then TWALog("Tetris", fmt, ...) end end

T.PACK = {
    ["HARMONIE_TheWayToAttack.TWA_MaterialLump"] = { width = 1, height = 1, maxStackSize = 5 },
}

local done = false
function T.register(when)
    if done then return end
    local D = rawget(_G, "TetrisItemData")
    if type(D) ~= "table" then
        log("%s: Inventory Tetris not loaded -- nothing to register", tostring(when))
        return
    end
    if type(D.registerItemDefinitions) ~= "function" then
        local names = {}
        for k, v in pairs(D) do if type(v) == "function" then names[#names + 1] = tostring(k) end end
        table.sort(names)
        log("%s: TetrisItemData has no registerItemDefinitions -- Material Lump stack NOT set. Its functions: %s", tostring(when), table.concat(names, ", "))
        done = true
        return
    end
    local ok, err = pcall(D.registerItemDefinitions, T.PACK)
    done = true
    if ok then
        local n = 0
        for _ in pairs(T.PACK) do n = n + 1 end
        log("%s: %d item size(s) registered with Inventory Tetris (Material Lump 1x1, stack 5)", tostring(when), n)
    else
        log("%s: registering with Inventory Tetris FAILED: %s", tostring(when), tostring(err))
    end
end

-- Inventory Tetris loads its data with the other shared files; try again at boot
T.register("load")
if Events and Events.OnGameBoot then Events.OnGameBoot.Add(function() T.register("OnGameBoot") end) end

-- ------------------------------------------------------------ bag grids
-- TWA 1.5.8 (owner 2026-11-27: "make the bag add-ons fit Inventory Tetris"
-- -- "some kinds"). Facts from Tetris 42.20 (owner's zip, not in the repo):
--   * a bag's grid = the container definition keyed "<type>_<capacity>";
--   * 70 of our 86 bags have NO hand-made definition: Tetris calculates one
--     from capacity (2 cells per capacity point) + weight reduction, so the
--     capacity add-on already gives them a bigger grid;
--   * 16 have a hand-made shape (fanny packs 2x2 + pockets, rifle / shotgun
--     cases 7x2 for long guns, golf bags, fishing basket, holster, ammo
--     straps). A capacity add-on changes the key, Tetris finds nothing and
--     falls back to a calculated square-ish grid -- the rifle case would
--     lose its long row.
-- So for a bag whose BASE capacity has a hand-made definition and whose
-- capacity an add-on raised, we register "<type>_<new capacity>" = the
-- hand-made shape with rows added to its widest grid (2 cells per point,
-- as Tetris counts). Client only (TetrisContainerData is a client file);
-- each new key once, logged. Weight reduction / speed / weight / hotbar
-- add-ons do not touch the grid.
T.bagKeysDone = T.bagKeysDone or {}

local function deepCopy(t, d)
    if type(t) ~= "table" or (d or 0) > 8 then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = deepCopy(v, (d or 0) + 1) end
    return o
end

local function capKey(n)
    n = tonumber(n) or 0
    if n == math.floor(n) then return tostring(math.floor(n)) end
    return tostring(n)
end

function T.ensureBagGrid(item, baseCap, newCap)
    local CD = rawget(_G, "TetrisContainerData")
    if type(CD) ~= "table" or type(CD._containerDefinitions) ~= "table" then return false end
    baseCap, newCap = tonumber(baseCap), tonumber(newCap)
    if not baseCap or not newCap or newCap <= baseCap then return false end
    local okT, typ = pcall(function() return item:getInventory():getType() end)
    if not okT or not typ then return false end
    local newKey = typ .. "_" .. capKey(newCap)
    if T.bagKeysDone[newKey] then return false end
    T.bagKeysDone[newKey] = true
    local base = CD._containerDefinitions[typ .. "_" .. capKey(baseCap)]
    if type(base) ~= "table" or base._autoCalculated or type(base.gridDefinitions) ~= "table" then
        return false -- a calculated grid follows the capacity by itself
    end
    if CD._containerDefinitions[newKey] then return false end
    local def = deepCopy(base)
    def._autoCalculated = nil
    local widest, w = nil, 0
    for _, g in ipairs(def.gridDefinitions) do
        local gw = g.size and tonumber(g.size.width) or 0
        if gw > w then widest, w = g, gw end
    end
    if not widest or w <= 0 then return false end
    local extra = math.ceil((newCap - baseCap) * 2)
    local rows = math.ceil(extra / w)
    widest.size.height = (tonumber(widest.size.height) or 1) + rows
    -- grids below the widest one move down with it
    local wy = widest.position and tonumber(widest.position.y) or 0
    for _, g in ipairs(def.gridDefinitions) do
        if g ~= widest and g.position and (tonumber(g.position.y) or 0) > wy then
            g.position.y = g.position.y + rows
        end
    end
    local ok, err = pcall(CD.registerContainerDefinitions, { [newKey] = def })
    log("bag grid %s: %s (hand-made %s_%s + %d row(s) of %d)", newKey, ok and "registered" or ("FAILED: " .. tostring(err)),
        typ, capKey(baseCap), rows, w)
    return ok
end

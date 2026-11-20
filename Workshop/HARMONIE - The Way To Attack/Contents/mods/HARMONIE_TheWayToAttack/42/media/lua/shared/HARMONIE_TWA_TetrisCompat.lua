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

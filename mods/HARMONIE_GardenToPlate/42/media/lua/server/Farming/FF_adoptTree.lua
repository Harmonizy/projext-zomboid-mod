-- HARMONIE - From Garden to Plate: a Fruit Farming tree that was PLACED
-- (vanilla Brush Tool, a map) instead of planted is only a picture -- the
-- farming system has no plant there, so nothing grows and nothing can be
-- harvested (owner, 2026-10-11: "ยังคงไม่สามารถเก็บผลไม้ได้ เพราะคลิกขวาแล้ว
-- ไม่มีให้เก็บ (เสกต้นไม้ขึ้นมาด้วย Brushtool vanilla)").
-- Right-click it -> "Tend this fruit tree" (client/HARMONIEGardenToPlate/
-- HARMONIE_FFAdopt.lua) -> this server command turns the picture into a
-- real plant of that crop at the stage the picture shows (in fruit = ready
-- to pick), the same way vanilla plows and seeds a square.
require "Farming/farming_vegetableconf"
require "Farming/FF_farmingConf"

FF_Adopt = FF_Adopt or {}
local A = FF_Adopt
A.NET = "HARMONIE_GTP_FF"

local function log(fmt, ...)
    local G = HARMONIE_GTP
    if G and G.Log then pcall(G.Log, "FruitFarming", fmt, ...) else print("[HARMONIE_GTP][FruitFarming] " .. string.format(fmt, ...)) end
end

-- sprite sheet ("ff_apple_01") -> crop key ("FFApple"), from the crops' own sprite lists
function A.sheetToKey()
    local out = {}
    for key, list in pairs(farming_vegetableconf.sprite or {}) do
        if type(key) == "string" and key:sub(1, 2) == "FF" and type(list) == "table" and type(list[1]) == "string" then
            local sheet = list[1]:match("^(ff_[%w]+_%d+)_%d+$")
            if sheet then out[sheet] = key end
        end
    end
    return out
end

-- -> crop key, sprite index (0..31) of a placed FF tile object, or nil
function A.identify(obj)
    local spr = obj and obj.getSprite and obj:getSprite()
    local name = spr and spr.getName and spr:getName()
    if type(name) ~= "string" then return nil end
    local sheet, n = name:match("^(ff_[%w]+_%d+)_(%d+)$")
    if not sheet then return nil end
    local key = A.sheetToKey()[sheet]
    return key, tonumber(n)
end

function A.adopt(player, args)
    local sys = SFarmingSystem and SFarmingSystem.instance
    if not sys or type(args) ~= "table" then log("adopt IGNORED: no farming system / bad args"); return end
    local sq = getCell() and getCell():getGridSquare(tonumber(args.x) or -1, tonumber(args.y) or -1, tonumber(args.z) or 0)
    if not sq then log("adopt IGNORED: no square at %s,%s,%s", tostring(args.x), tostring(args.y), tostring(args.z)); return end
    if sys.getLuaObjectOnSquare and sys:getLuaObjectOnSquare(sq) then log("adopt IGNORED: already a plant at %d,%d", sq:getX(), sq:getY()); return end
    local objs = sq:getObjects()
    local found, key, n
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        local k, idx = A.identify(o)
        if k then found, key, n = o, k, idx; break end
    end
    if not found then log("adopt IGNORED: no Fruit Farming picture at %d,%d", sq:getX(), sq:getY()); return end
    local props = farming_vegetableconf.props[key]
    if not props then log("adopt IGNORED: crop %s is not registered", tostring(key)); return end
    -- the picture goes, a real plant takes its place
    local ok = pcall(function() sq:transmitRemoveItemFromSquare(found) end)
    if not ok then pcall(function() sq:RemoveTileObject(found) end) end
    sys:plow(sq)
    local plant = sys:getLuaObjectOnSquare(sq)
    if not plant then log("adopt FAILED: plowing %d,%d made no plant", sq:getX(), sq:getY()); return end
    plant:seed(key, 0)
    -- the stage the picture showed: column 0..5 growing, 6 in fruit, 7 picked
    local col = (n or 0) % 8
    local hours = sys.hoursElapsed or 0
    if col == 6 then
        plant.nbOfGrow = (props.fullGrown or 6) + 1
        plant.hasVegetable, plant.hasSeed = true, true
        plant.nextGrowing = hours + (props.rotTime or math.floor((props.timeToGrow or 400) / 2))
    elseif col == 7 then
        plant.nbOfGrow = (props.growBack or 3) + 1
        plant.nextGrowing = hours + (props.timeToGrow or 400)
    else
        plant.nbOfGrow = col + 1
        plant.nextGrowing = hours + (props.timeToGrow or 400)
    end
    plant.waterLvl = math.max(tonumber(plant.waterLvl) or 0, 80)
    plant.health = math.max(tonumber(plant.health) or 0, 80)
    local sprite = farming_vegetableconf.getSpriteName(plant)
    if sprite then plant:setSpriteName(sprite) end
    if plant.setObjectName then plant:setObjectName(farming_vegetableconf.getObjectName(plant)) end
    plant:saveData()
    log("%s turned the placed %s at %d,%d into a real plant (stage %d%s)", tostring(player and player.getUsername and player:getUsername() or "?"),
        tostring(key), sq:getX(), sq:getY(), plant.nbOfGrow, plant.hasVegetable and ", in fruit" or "")
end

if Events and Events.OnClientCommand and not A.registered then
    A.registered = true
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= A.NET then return end
        if command == "adopt" then
            local ok, err = pcall(A.adopt, player, args)
            if not ok then log("adopt ERROR: %s", tostring(err)) end
        end
    end)
end

-- HARMONIE - From Garden to Plate: a fruit tree that has grown up is not
-- trampled to death (owner, 2026-11-12: "บางอันถ้าขึ้นต้นแล้วต้องไม่ถูกซอมบี้
-- เหยียบตาย ทำได้ไหม").
--
-- B42 farming tramples a crop someone walks over (zombies included):
-- SFarmingSystem:destroyOnWalk(luaObject, square) -> the plant turns
-- "destroyed" (the trampled sprite), and a destroyed plant is later cleared
-- from the plot by the farming system itself.
--
-- Here, for the Fruit Farming PERENNIALS only (trees, vines, coffee: the FF
-- crops with growBack) from growth stage FROM_STAGE on, the trample is
-- skipped: the tree keeps its stage, fruit and health. Seedlings below that
-- stage, annual FF crops (rice, ginger, peanuts) and every vanilla crop are
-- trampled as before. Server / SP only (the farming system lives there).
require "Farming/farming_vegetableconf"
require "Farming/FF_farmingConf"

FF_TrampleGuard = FF_TrampleGuard or {}
local T = FF_TrampleGuard
T.FROM_STAGE = 3          -- growth stage (0..6, fruit at 6) from which a tree stands firm
T.LOG_EVERY_H = 24        -- one "saved" line per tree per game day

local function log(fmt, ...)
    local G = HARMONIE_GTP
    if G and G.Log then pcall(G.Log, "TrampleGuard", fmt, ...) else print("[HARMONIE_GTP][TrampleGuard] " .. string.format(fmt, ...)) end
end

local function worldHours()
    local gt = getGameTime and getGameTime()
    return gt and gt:getWorldAgeHours() or 0
end

local perennial
local function isPerennial(key)
    if not perennial then
        perennial = {}
        for k, props in pairs(farming_vegetableconf.props or {}) do
            if type(k) == "string" and k:sub(1, 2) == "FF" and props.growBack then perennial[k] = true end
        end
    end
    return key ~= nil and perennial[key] == true
end

-- the plant (SPlantGlobalObject) stands firm?
function T.isProtected(plant)
    if type(plant) ~= "table" then return false end
    if not isPerennial(plant.typeOfSeed) then return false end
    local st = plant.state
    if st == "dead" or st == "destroyed" or st == "dry" or st == "rotten" or st == "plow" then return false end
    local nb = tonumber(plant.nbOfGrow) or 0
    return nb >= T.FROM_STAGE
end

local lastSaid = {}
local function note(plant, how)
    local key = tostring(plant.x) .. "," .. tostring(plant.y) .. "," .. tostring(plant.z)
    local now = worldHours()
    if lastSaid[key] and now - lastSaid[key] < T.LOG_EVERY_H then return end
    lastSaid[key] = now
    log("%s at %s (stage %s): walked over -- not trampled, a grown fruit tree stands firm (%s; logged once a game day per tree)",
        tostring(plant.typeOfSeed), key, tostring(plant.nbOfGrow), how)
end

local function noteTrampled(plant)
    if type(plant) ~= "table" or not tostring(plant.typeOfSeed or ""):find("^FF") then return end
    if plant.state == "destroyed" or plant.state == "dead" then return end
    local key = "t:" .. tostring(plant.x) .. "," .. tostring(plant.y) .. "," .. tostring(plant.z)
    local now = worldHours()
    if lastSaid[key] and now - lastSaid[key] < T.LOG_EVERY_H then return end
    lastSaid[key] = now
    log("%s at %s,%s (stage %s, state %s): trampled (below stage %d or not a tree)",
        tostring(plant.typeOfSeed), tostring(plant.x), tostring(plant.y), tostring(plant.nbOfGrow), tostring(plant.state), T.FROM_STAGE)
end

function T.install()
    if T.installed then return end
    local Sys, Plant = SFarmingSystem, SPlantGlobalObject
    local done = {}
    if Sys and type(Sys.destroyOnWalk) == "function" then
        local orig = Sys.destroyOnWalk
        Sys.destroyOnWalk = function(self, luaObject, square, ...)
            if T.isProtected(luaObject) then note(luaObject, "destroyOnWalk"); return end
            noteTrampled(luaObject)
            return orig(self, luaObject, square, ...)
        end
        done[#done + 1] = "SFarmingSystem.destroyOnWalk"
        local inst = Sys.instance
        if inst and rawget(inst, "destroyOnWalk") then inst.destroyOnWalk = Sys.destroyOnWalk end
    end
    -- the trampled state itself, in case another path tramples a plant
    if Plant and type(Plant.destroyThis) == "function" then
        local orig = Plant.destroyThis
        Plant.destroyThis = function(self, ...)
            if T.isProtected(self) then note(self, "destroyThis"); return end
            return orig(self, ...)
        end
        done[#done + 1] = "SPlantGlobalObject.destroyThis"
    end
    T.installed = #done > 0
    if T.installed then
        log("installed (%s): Fruit Farming trees / vines from stage %d are not trampled", table.concat(done, ", "), T.FROM_STAGE)
    else
        log("NOT installed: SFarmingSystem.destroyOnWalk / SPlantGlobalObject.destroyThis missing -- trees can still be trampled")
    end
end

if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(T.install) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(T.install) end
    if Events.OnGameStart then Events.OnGameStart.Add(T.install) end
end

return T

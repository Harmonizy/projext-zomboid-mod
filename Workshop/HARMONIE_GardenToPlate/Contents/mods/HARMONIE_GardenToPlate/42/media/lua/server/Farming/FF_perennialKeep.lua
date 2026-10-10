-- HARMONIE - From Garden to Plate: fruit trees outlive an unpicked crop
-- (2026-10-10). Fruit Farming (B42, leina -- see 42/CREDITS.txt) makes its
-- trees, vines and coffee perennial the vanilla strawberry way (growBack):
-- picked, they go back to an earlier growth stage. But vanilla's grow()
-- treats every crop left past fullGrown as rotten -- so a fruit tree nobody
-- picked within rotTime (about 8 days) died, trunk and all. Now, for these
-- perennials only, the fruit falls and rots instead: the tree goes back to
-- its growBack stage as if it had been picked (no harvest), and fruits again.
-- Vanilla crops and the annual FF crops (rice, ginger, peanuts) are untouched.
require "Farming/farming_vegetableconf"
require "Farming/FF_farmingConf"
if not farming_vegetableconf or not farming_vegetableconf.grow then return end

local PERENNIAL = {}
for key, props in pairs(farming_vegetableconf.props or {}) do
    if type(key) == "string" and key:sub(1, 2) == "FF" and props.growBack then PERENNIAL[key] = true end
end

local function log(fmt, ...)
    local G = HARMONIE_GTP
    if G and G.Log then pcall(G.Log, "FruitFarming", fmt, ...) end
end

local vanillaGrow = farming_vegetableconf.grow
farming_vegetableconf.grow = function(planting, nextGrowing, updateNbOfGrow)
    local key = planting and planting.typeOfSeed
    local props = key and PERENNIAL[key] and farming_vegetableconf.props[key]
    local nb = planting and tonumber(planting.nbOfGrow)
    local alive = planting and planting.isAlive and planting:isAlive()
    if props and nb and alive and props.fullGrown and nb > props.fullGrown then
        -- over-ripe: drop the fruit, keep the tree (SFarmingSystem:harvest's
        -- growBack path without the harvest)
        planting.hasVegetable = false
        planting.hasSeed = false
        planting.nbOfGrow = props.growBack
        log("%s at %s,%s: fruit left unpicked fell and rotted -- the tree lives on (stage %s)",
            tostring(key), tostring(planting.x), tostring(planting.y), tostring(props.growBack))
    end
    return vanillaGrow(planting, nextGrowing, updateNbOfGrow)
end

--[[
    HARMONIE - The Way To Attack 1.2.1: rare zombie drops (owner 2026-11-20:
    "zombies can drop a Material Lump and a Gemstone -- never enough to flood
    the server, only so players know they exist; the Gemstone half as often").

    Server / single player only: when a zombie dies, one roll each, put in
    its inventory before the corpse is made (the corpse keeps it). Chances
    are sandbox (percent per zombie): ZombieDropLump 5, ZombieDropGemstone
    2.5 (owner, second ask: "lump 5, gemstone 2.5") -- about 1 lump in 20
    kills, 1 Gemstone in 40. Every drop is logged with the running total.
]]--

require "HARMONIE_TWA_Config"

TWAZombieDrop = TWAZombieDrop or {}
local Z = TWAZombieDrop
local log = function(fmt, ...) if TWALog then TWALog("ZombieDrop", fmt, ...) end end

Z.DROPS = {
    { key = "ZombieDropLump", type = "HARMONIE_TheWayToAttack.TWA_MaterialLump" },
    { key = "ZombieDropGemstone", type = "HARMONIE_TheWayToAttack.TWA_Gemstone" },
}
Z.given = Z.given or {}
Z.kills = Z.kills or 0

-- roll with 1/100 of a percent precision
local function hit(pct)
    pct = tonumber(pct) or 0
    if pct <= 0 then return false end
    return ZombRand(10000) < math.floor(pct * 100 + 0.5)
end

function Z.onZombieDead(zombie)
    if isClient and isClient() then return end
    if not zombie or not zombie.getInventory then return end
    Z.kills = Z.kills + 1
    for _, d in ipairs(Z.DROPS) do
        if hit(TWAConfig.num(d.key, 0)) then
            local ok, it = pcall(function() return zombie:getInventory():AddItem(d.type) end)
            if ok and it then
                Z.given[d.type] = (Z.given[d.type] or 0) + 1
                log("a zombie dropped %s (%d so far in %d kills this session)", d.type, Z.given[d.type], Z.kills)
            else
                log("could NOT put %s on a dead zombie", d.type)
            end
        end
    end
end

if Events and Events.OnZombieDead then
    Events.OnZombieDead.Add(Z.onZombieDead)
end

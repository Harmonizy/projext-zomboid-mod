-- Independent drop chance for each item (percentage)
local lootTable = {
    { item = "Base.AirDropMarker",        chance = 0.02 }, 
   
    --Boxes--
    { item = "Base.Bullets9mmBox",        chance = 0.02 },
    { item = "Base.Bullets38Box",         chance = 0.02 },
    { item = "Base.Bullets44Box",         chance = 0.02 },
    { item = "Base.Bullets45Box",         chance = 0.02 },
    { item = "Base.Bullets50Box",         chance = 0.015 },
    { item = "Base.Bullets58Box",         chance = 0.02 },
    { item = "Base.Bullets86Box",         chance = 0.015 },
    { item = "Base.545box",               chance = 0.02 },
    --{ item = "Base.223Box",               chance = 0.02 },
    { item = "Base.ShotgunShellsBox",     chance = 0.02 },
    { item = "Base.308Box",               chance = 0.015 },

    --Shells--

    --{ item = "Base.ShotgunShells",        chance = 0.02 },
    --{ item = "Base.Bullets9mm",           chance = 0.04 },
    --{ item = "Base.Bullets38",            chance = 0.04 },
    --{ item = "Base.Bullets44",            chance = 0.04 },
    --{ item = "Base.Bullets45",            chance = 0.04 },
    --{ item = "Base.Bullets50",            chance = 0.04 },
    --{ item = "Base.58Bullets",            chance = 0.04 },
    --{ item = "Base.Bullets86",            chance = 0.04 },
    --{ item = "Base.545Bullets",           chance = 0.04 },
    --{ item = "Base.223Bullets",           chance = 0.04 },
    --{ item = "Base.308Bullets",           chance = 0.04 }, 
}

-- Global switch/multiplier settings (optional, e.g., a global multiplication factor)
local function getGlobalMultiplier()
    local settings = SandboxVars.DahuobangLootDrop or {}
    return settings.GlobalMultiplier or 1.0
end

-- Zombie death drop logic
local function onZombieDead(zombie)
    if not zombie or not zombie:isDead() then return end
    
    -- Check if zombie drops are enabled
    if not SandboxVars.EFKARB or SandboxVars.EFKARB.EnableZombieDrops == false then
        return
    end

    local inventory = zombie:getInventory()
    local multiplier = getGlobalMultiplier()

    for _, entry in ipairs(lootTable) do
        local effectiveChance = math.min(100, entry.chance * multiplier)
        if ZombRand(100) < effectiveChance then
            inventory:AddItem(entry.item)
        end
    end
end

Events.OnZombieDead.Add(onZombieDead)

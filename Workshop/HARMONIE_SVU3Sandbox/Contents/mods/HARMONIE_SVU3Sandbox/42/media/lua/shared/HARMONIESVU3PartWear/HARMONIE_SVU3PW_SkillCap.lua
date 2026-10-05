--[[
    HARMONIE - SVU3 Sandbox: cap on the skills an upgrade needs to install.

    Request 2026-10-05: "ติดตั้งอัปเกรดแต่ละชิ้น ต้องใช้สกิลรวมกันไม่เกิน 14".
    Standardized Vehicle Upgrades 3 lists, per upgrade, the skill levels its
    install needs (install.skills, e.g. the plow: MetalWelding 8 +
    Mechanics 6). tsarslib copies that table into the tuning menu and
    compares each level with the player's (ISVehicleTuning2:IsRecipeValid),
    as it is -- no multiplier anywhere. Read from SVU3 Core
    SVUC_TuningTable.lua, the Vanilla addon's SVUV_TuningTable.lua and
    tsarslib's ATA2TuningTable.lua / ISVehicleTuning2.lua.

    The sandbox option MaxInstallSkillTotal (default 14) is the highest the
    install levels of one upgrade may add up to. When an upgrade needs
    more, its highest skill is lowered one level at a time until the total
    fits (MetalWelding 8 + Mechanics 6 with a cap of 12 -> 6 + 6). Nothing
    else in the table is touched; uninstalling is left as SVU3 has it.

    Vehicle tiers (request 2026-10-05: "ปรับตามรถที่จะทำการอัปเกรด ... รถไหน
    ดีกว่า ไม่ดีกว่า มีกี่ระดับ ก็ให้สเกลเลเวลตามนั้น" -> durability / size,
    3 tiers, the lowest 50%): every car SVU3 can upgrade is ranked by its
    vehicle script's weight (mass) and front + rear end strength (the two
    ranks averaged) and split into VehicleTierCount tiers (default 3). The
    install levels of a car in tier t are SVU3's own levels times
    VehicleTierLowestPercent (default 50%) .. 100% (top tier = SVU3's
    values), rounded, at least 1; then the total cap above. SVU3 shares one
    table between many cars (every van variant points at "Van"), so each
    car gets its own copy of parts / models / install (the rest -- items,
    tools -- stays shared, read only); the original levels are kept, so a
    second pass gives the same numbers.

    When: SVU3 builds its tables in OnInitGlobalModData
    (ATA2Tuning_AddNewCars fills ATA2TuningTable). This mod requires SVU3,
    so this file -- and its handler -- load after theirs and run after
    them. The same pass runs again at OnGameStart / OnServerStarted, and
    ATA2Tuning_AddNewCars is wrapped for cars added later. Capping a table
    that already fits changes nothing, so running it again is harmless.
    Shared: the client's menu and the server read the same numbers.
]]--

HARMONIE_SVU3SkillCap = HARMONIE_SVU3SkillCap or {}
local C = HARMONIE_SVU3SkillCap
C.DEFAULT = 14

function C.maxTotal()
    local sv = SandboxVars and SandboxVars.HARMONIE_SVU3PartWear
    local v = sv and tonumber(sv.MaxInstallSkillTotal)
    if not v or v < 1 then return C.DEFAULT end
    return math.floor(v)
end

-- lower the highest level first (ties: by name, so every machine agrees)
-- until the levels add up to `max` or less; returns how many levels came off
function C.capSkills(skills, max)
    if type(skills) ~= "table" then return 0 end
    local total, names = 0, {}
    for name, lvl in pairs(skills) do
        if type(lvl) == "number" then
            total = total + lvl
            names[#names + 1] = name
        end
    end
    table.sort(names)
    local removed = 0
    while total > max do
        local best
        for _, n in ipairs(names) do
            if not best or skills[n] > skills[best] then best = n end
        end
        if not best or skills[best] <= 0 then break end
        skills[best] = skills[best] - 1
        total = total - 1
        removed = removed + 1
    end
    return removed
end

-- every install of every upgrade of every car in a tuning table
-- (returns how many, and "part.model" -> number of cars, for the console)
function C.capTable(carsTable, max)
    local changed, which = 0, {}
    for _, car in pairs(carsTable or {}) do
        if type(car) == "table" and type(car.parts) == "table" then
            for partName, models in pairs(car.parts) do
                if type(models) == "table" then
                    for modelName, model in pairs(models) do
                        local install = type(model) == "table" and model.install
                        if type(install) == "table" and C.capSkills(install.skills, max) > 0 then
                            changed = changed + 1
                            local key = tostring(partName) .. "." .. tostring(modelName)
                            which[key] = (which[key] or 0) + 1
                        end
                    end
                end
            end
        end
    end
    return changed, which
end

-- ------------------------------------------------------------ vehicle tiers
local function sv(name, default)
    local t = SandboxVars and SandboxVars.HARMONIE_SVU3PartWear
    local v = t and t[name]
    if v == nil then return default end
    return v
end

local function num(script, getter)
    if not script or not script[getter] then return nil end
    local ok, v = pcall(script[getter], script)
    return ok and tonumber(v) or nil
end

-- durability / size of a vehicle script: weight, and front + rear end strength
function C.vehicleStats(vehicleName)
    local sm = getScriptManager and getScriptManager()
    local script = sm and sm:getVehicle(vehicleName)
    if not script then return nil end
    local mass = num(script, "getMass")
    local front, rear = num(script, "getFrontEndHealth"), num(script, "getRearEndHealth")
    local ends = (front or rear) and ((front or 0) + (rear or 0)) or nil
    if not mass and not ends then return nil end
    return { mass = mass, ends = ends }
end

-- 1-based rank of every name by one stat (ties share the lower rank)
local function ranks(names, stats, key)
    local list = {}
    for _, n in ipairs(names) do if stats[n][key] then list[#list + 1] = n end end
    table.sort(list, function(a, b)
        if stats[a][key] ~= stats[b][key] then return stats[a][key] < stats[b][key] end
        return a < b
    end)
    local r, prevV, prevR = {}, nil, 0
    for i, n in ipairs(list) do
        local v = stats[n][key]
        if v ~= prevV then prevR = i; prevV = v end
        r[n] = prevR
    end
    return r, #list
end

-- vehicle name -> tier 1 (weakest) .. count
function C.vehicleTiers(names, count)
    local stats, have = {}, {}
    for _, n in ipairs(names) do
        local st = C.vehicleStats(n)
        if st then stats[n] = st; have[#have + 1] = n end
    end
    local tiers = {}
    if #have == 0 or count <= 1 then return tiers end
    local rm, nm = ranks(have, stats, "mass")
    local re, ne = ranks(have, stats, "ends")
    local score = {}
    for _, n in ipairs(have) do
        local parts, sum = 0, 0
        if rm[n] then sum = sum + rm[n] / nm; parts = parts + 1 end
        if re[n] then sum = sum + re[n] / ne; parts = parts + 1 end
        score[n] = sum / math.max(1, parts)
    end
    table.sort(have, function(a, b)
        if score[a] ~= score[b] then return score[a] < score[b] end
        return a < b
    end)
    -- equal stats share a tier: the tier of the first car with that score
    local first, prev = 1, nil
    for i, n in ipairs(have) do
        if score[n] ~= prev then first = i; prev = score[n] end
        tiers[n] = math.min(count, math.floor((first - 1) * count / #have) + 1)
    end
    return tiers
end

function C.tierFactor(tier, count, lowestPct)
    if not tier or count <= 1 then return 1 end
    local low = math.max(0.1, math.min(1, (lowestPct or 50) / 100))
    return low + (1 - low) * (tier - 1) / (count - 1)
end

local function shallow(t)
    local o = {}
    for k, v in pairs(t) do o[k] = v end
    return o
end

-- give a car its own parts / models / install tables, remembering SVU3's
-- original install levels (C.orig[car][part][model])
C.orig = C.orig or {}
local function ownCopy(name, car)
    if car.__harmonieOwn then return car end
    local orig = {}
    local mine = shallow(car)
    mine.parts = {}
    for partName, models in pairs(car.parts or {}) do
        local m2 = {}
        orig[partName] = {}
        for modelName, model in pairs(models) do
            if type(model) == "table" and type(model.install) == "table" then
                local mc = shallow(model)
                mc.install = shallow(model.install)
                if type(model.install.skills) == "table" then
                    orig[partName][modelName] = shallow(model.install.skills)
                    mc.install.skills = shallow(model.install.skills)
                end
                m2[modelName] = mc
            else
                m2[modelName] = model
            end
        end
        mine.parts[partName] = m2
    end
    mine.__harmonieOwn = true
    C.orig[name] = orig
    return mine
end

function C.applyTiers()
    if not ATA2TuningTable then return 0 end
    local count = math.floor(tonumber(sv("VehicleTierCount", 3)) or 3)
    local enabled = sv("VehicleTierScaling", true) ~= false
    local names = {}
    for name, car in pairs(ATA2TuningTable) do
        if type(car) == "table" and type(car.parts) == "table" then names[#names + 1] = name end
    end
    table.sort(names)
    local tiers = enabled and C.vehicleTiers(names, count) or {}
    local lowest = tonumber(sv("VehicleTierLowestPercent", 50)) or 50
    -- once per run of tiers: which car is in which tier (console.txt), or
    -- why there are none
    if enabled and count > 1 then
        local byTier, any = {}, false
        for _, n in ipairs(names) do
            local t = tiers[n]
            if t then any = true; byTier[t] = byTier[t] or {}; table.insert(byTier[t], n) end
        end
        local key = tostring(#names) .. ":" .. tostring(any)
        if C.lastReport ~= key then
            C.lastReport = key
            if not any then
                print("HARMONIE SVU3 Sandbox: no vehicle weight / front-rear strength readable -- vehicle tiers off, SVU3's own skill levels used.")
            else
                for t = 1, count do
                    print(string.format("HARMONIE SVU3 Sandbox: tier %d (%d%%): %s", t,
                        math.floor(C.tierFactor(t, count, lowest) * 100 + 0.5), table.concat(byTier[t] or {}, ", ")))
                end
            end
        end
    end
    local changed = 0
    for _, name in ipairs(names) do
        local car = ownCopy(name, ATA2TuningTable[name])
        ATA2TuningTable[name] = car
        car.__harmonieTier = tiers[name]
        local f = enabled and C.tierFactor(tiers[name], count, lowest) or 1
        for partName, models in pairs(car.parts) do
            for modelName, model in pairs(models) do
                local o = C.orig[name][partName] and C.orig[name][partName][modelName]
                local skills = type(model) == "table" and model.install and model.install.skills
                if o and type(skills) == "table" then
                    for k, v in pairs(o) do
                        if type(v) == "number" then
                            local nv = v > 0 and math.max(1, math.floor(v * f + 0.5)) or v
                            if nv ~= skills[k] then changed = changed + 1 end
                            skills[k] = nv
                        end
                    end
                end
            end
        end
    end
    return changed
end

function C.capAll()
    if not ATA2TuningTable then return end
    C.applyTiers()
    local max = C.maxTotal()
    local n, which = C.capTable(ATA2TuningTable, max)
    if n > 0 then
        local list = {}
        for key, cars in pairs(which) do list[#list + 1] = key .. " x" .. cars end
        table.sort(list)
        print(string.format("HARMONIE SVU3 Sandbox: %d upgrade install(s) lowered to a skill total of %d: %s", n, max, table.concat(list, ", ")))
    end
end

local function wrapAddNewCars()
    if C.wrapped or not ATA2Tuning_AddNewCars then return end
    C.wrapped = true
    local orig = ATA2Tuning_AddNewCars
    ATA2Tuning_AddNewCars = function(carsTable, ...)
        local r = orig(carsTable, ...)
        C.capAll()
        return r
    end
end

local function run()
    wrapAddNewCars()
    C.capAll()
end

if Events then
    if Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(run) end
    if Events.OnGameStart then Events.OnGameStart.Add(run) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(run) end
end

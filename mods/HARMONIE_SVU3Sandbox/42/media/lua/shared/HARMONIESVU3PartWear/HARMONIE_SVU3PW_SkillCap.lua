--[[
    HARMONIE - SVU3 Sandbox: the skills an upgrade needs to install, set by
    vehicle tier.

    Standardized Vehicle Upgrades 3 lists, per upgrade, the skill levels its
    install needs (install.skills, e.g. the plow: MetalWelding 8 +
    Mechanics 6). tsarslib copies that table into the tuning menu and
    compares each level with the player's (ISVehicleTuning2:IsRecipeValid),
    as it is -- no multiplier anywhere. Read from SVU3 Core
    SVUC_TuningTable.lua, the Vanilla addon's SVUV_TuningTable.lua and
    tsarslib's ATA2TuningTable.lua / ISVehicleTuning2.lua. This file only
    changes those install levels; times, items, tools and uninstalling stay
    as SVU3 has them.

    Request 2026-10-05: "ให้ม็อดของเรามีส่วนในการแค่ตั้งค่าสกิลที่ใช้ในรถแต่ละคัน
    4+2/6+4/8+6 โดยการ ใช้จำนวนที่นั่ง หรือความจุท้ายรถ (trunk) มาช่วยคำนวณด้วย
    และ ใส่ช่อง sandbox ให้ admin กำหนดระดับของรถบางคันเองได้ด้วย".

    Tiers: every car SVU3 can upgrade is ranked by its vehicle script's
    weight (getMass), front + rear end strength (getFrontEndHealth +
    getRearEndHealth), seats (getPassengerCount, else counting
    getPassenger) and trunk size (capacity of its TruckBed* parts, when the
    script part tells it). Each car's rank in every stat it has is averaged,
    and the list is cut in 3 equal tiers (1 = smallest). Cars with equal
    scores share a tier. Sandbox VehicleTierOverrides puts named cars in a
    tier by hand ("Van*=2; StepVan=3"; "*" at the end = every name starting
    so; an exact name wins over a "*" one, the longer "*" over the shorter).
    A car with no readable stats and no override is tier 3.

    Levels: a tier has a main and a second skill ceiling (sandbox, default
    tier 1 = 4+2, tier 2 = 6+4, tier 3 = 8+6). In each install the highest
    skill is the main one (ties: by name), the others are second ones. A
    level is scaled from SVU3's own so that SVU3's hardest upgrade lands on
    the ceiling exactly: new = SVU3 level x ceiling / SVU3's highest (main:
    the highest main level of all upgrades, 8 in SVU3 3; second: the
    highest second level, 6), rounded, at least 1, at most the ceiling.
    With the defaults tier 3 is SVU3's own levels; the plow is 4+2 / 6+4 /
    8+6, the large bullbar (6+4) 3+1 / 5+3 / 6+4, reinforced armor (8)
    4 / 6 / 8.

    SVU3 shares one table between many cars (every van variant points at
    "Van"), so each car gets its own copy of parts / models / install (the
    rest -- items, tools -- stays shared, read only); SVU3's original levels
    are kept, so a second pass gives the same numbers.

    When: SVU3 builds its tables in OnInitGlobalModData
    (ATA2Tuning_AddNewCars fills ATA2TuningTable). This mod requires SVU3,
    so this file -- and its handler -- load after theirs and run after
    them. The same pass runs again at OnGameStart / OnServerStarted, and
    ATA2Tuning_AddNewCars is wrapped for cars added later. Shared: the
    client's menu and the server work out the same numbers from the same
    scripts and sandbox values.
]]--

HARMONIE_SVU3SkillCap = HARMONIE_SVU3SkillCap or {}
local C = HARMONIE_SVU3SkillCap
C.TIERS = 3
C.DEFAULT_CEILING = { { 4, 2 }, { 6, 4 }, { 8, 6 } }
C.DEFAULT_REF = { 8, 6 } -- SVU3 3's hardest upgrade (the plow), if none read

local function sv(name, default)
    local t = SandboxVars and SandboxVars.HARMONIE_SVU3PartWear
    local v = t and t[name]
    if v == nil then return default end
    return v
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- main / second ceiling of a tier (1..3)
function C.tierCeiling(tier)
    local d = C.DEFAULT_CEILING[tier] or C.DEFAULT_CEILING[C.TIERS]
    local main = math.floor(tonumber(sv("Tier" .. tier .. "MainSkill", d[1])) or d[1])
    local second = math.floor(tonumber(sv("Tier" .. tier .. "SecondSkill", d[2])) or d[2])
    return clamp(main, 1, 10), clamp(second, 1, 10)
end

-- skill names of one install, highest level first (ties: by name, so every
-- machine agrees)
local function ordered(skills)
    local names = {}
    for name, lvl in pairs(skills) do
        if type(lvl) == "number" then names[#names + 1] = name end
    end
    table.sort(names, function(a, b)
        if skills[a] ~= skills[b] then return skills[a] > skills[b] end
        return a < b
    end)
    return names
end

-- SVU3's level -> this tier's level (see the header)
function C.scaleSkills(orig, main, second, refMain, refSecond)
    local out = {}
    for k, v in pairs(orig) do out[k] = v end
    for i, name in ipairs(ordered(orig)) do
        local v = orig[name]
        local cap, ref = main, refMain
        if i > 1 then cap, ref = second, refSecond end
        if v > 0 then out[name] = clamp(math.floor(v * cap / math.max(1, ref) + 0.5), 1, cap) end
    end
    return out
end

-- ------------------------------------------------------------ vehicle stats
local function num(obj, getter, ...)
    if not obj or not obj[getter] then return nil end
    local ok, v = pcall(obj[getter], obj, ...)
    return ok and tonumber(v) or nil
end

local function seatCount(script)
    local n = num(script, "getPassengerCount")
    if n and n > 0 then return n end
    if not script.getPassenger then return nil end
    local c = 0
    for i = 0, 31 do
        local ok, p = pcall(script.getPassenger, script, i)
        if not ok or not p then break end
        c = c + 1
    end
    return c > 0 and c or nil
end

-- capacity of one script part's container, by whichever getter the game has
local function partCapacity(p)
    local v = num(p, "getContainerCapacity")
    if v then return v end
    if p.getContainer then
        local ok, c = pcall(p.getContainer, p)
        if ok and c then
            v = num(c, "getCapacity")
            if v then return v end
            local ok2, f = pcall(function() return c.capacity end)
            if ok2 and tonumber(f) then return tonumber(f) end
        end
    end
    return nil
end

local function trunkSize(script)
    local n = num(script, "getPartCount")
    if not n or not script.getPart then return nil end
    local total, found = 0, false
    for i = 0, n - 1 do
        local ok, p = pcall(script.getPart, script, i)
        if ok and p then
            local okId, id = pcall(p.getId, p)
            if okId and type(id) == "string" and id:sub(1, 8) == "TruckBed" then
                local cap = partCapacity(p)
                if cap then total = total + cap; found = true end
            end
        end
    end
    return found and total or nil
end

C.STATS = { "mass", "ends", "seats", "trunk" }

-- weight, front + rear end strength, seats and trunk of a vehicle script
function C.vehicleStats(vehicleName)
    local sm = getScriptManager and getScriptManager()
    local script = sm and sm:getVehicle(vehicleName)
    if not script then return nil end
    local front, rear = num(script, "getFrontEndHealth"), num(script, "getRearEndHealth")
    local st = {
        mass = num(script, "getMass"),
        ends = (front or rear) and ((front or 0) + (rear or 0)) or nil,
        seats = seatCount(script),
        trunk = trunkSize(script),
    }
    if not (st.mass or st.ends or st.seats or st.trunk) then return nil end
    return st
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

-- vehicle name -> tier 1 (smallest) .. C.TIERS, for cars with stats;
-- also returns how many cars each stat was read from
function C.vehicleTiers(names)
    local stats, have = {}, {}
    for _, n in ipairs(names) do
        local st = C.vehicleStats(n)
        if st then stats[n] = st; have[#have + 1] = n end
    end
    local tiers, read = {}, {}
    C.statsOf = stats -- for the window (HARMONIE_SVU3_Window)
    if #have == 0 then return tiers, read end
    local rk = {}
    for _, key in ipairs(C.STATS) do
        local r, cnt = ranks(have, stats, key)
        read[key] = cnt
        rk[key] = { r = r, n = cnt }
    end
    local score = {}
    for _, n in ipairs(have) do
        local parts, sum = 0, 0
        for _, key in ipairs(C.STATS) do
            local r = rk[key]
            if r.r[n] then sum = sum + r.r[n] / r.n; parts = parts + 1 end
        end
        score[n] = sum / math.max(1, parts)
    end
    table.sort(have, function(a, b)
        if score[a] ~= score[b] then return score[a] < score[b] end
        return a < b
    end)
    -- equal scores share a tier: the tier of the first car with that score
    local first, prev = 1, nil
    for i, n in ipairs(have) do
        if score[n] ~= prev then first = i; prev = score[n] end
        tiers[n] = math.min(C.TIERS, math.floor((first - 1) * C.TIERS / #have) + 1)
    end
    return tiers, read
end

-- ------------------------------------------------------------ admin overrides
-- "Van*=2; StepVan=3, PickUpVan:1" -> exact names, "*" prefixes (longest first)
function C.parseOverrides(s)
    local exact, prefix = {}, {}
    for entry in tostring(s or ""):gmatch("[^;,]+") do
        local name, t = entry:match("^%s*([%w_%.%-%*]+)%s*[=:]%s*(%d+)%s*$")
        t = tonumber(t)
        if name and t and t >= 1 and t <= C.TIERS then
            if name:sub(-1) == "*" then
                prefix[#prefix + 1] = { name:sub(1, -2), t }
            else
                exact[name] = t
            end
        end
    end
    table.sort(prefix, function(a, b)
        if #a[1] ~= #b[1] then return #a[1] > #b[1] end
        return a[1] < b[1]
    end)
    return exact, prefix
end

function C.overrideTier(name, exact, prefix)
    if exact[name] then return exact[name] end
    for _, p in ipairs(prefix) do
        if name:sub(1, #p[1]) == p[1] then return p[2] end
    end
    return nil
end

-- ------------------------------------------------------------ apply
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

-- SVU3's highest main and second level over every upgrade of every car
function C.reference(names)
    local refMain, refSecond = 0, 0
    for _, name in ipairs(names) do
        for _, models in pairs(C.orig[name] or {}) do
            for _, o in pairs(models) do
                for i, k in ipairs(ordered(o)) do
                    if i == 1 then refMain = math.max(refMain, o[k])
                    else refSecond = math.max(refSecond, o[k]) end
                end
            end
        end
    end
    if refMain <= 0 then refMain = C.DEFAULT_REF[1] end
    if refSecond <= 0 then refSecond = C.DEFAULT_REF[2] end
    return refMain, refSecond
end

local function report(names, tiers, read, manual, refMain, refSecond)
    local byTier, unranked = {}, {}
    for _, n in ipairs(names) do
        local t = tiers[n]
        if t then
            byTier[t] = byTier[t] or {}
            table.insert(byTier[t], manual[n] and (n .. "(admin)") or n)
        else
            unranked[#unranked + 1] = n
        end
    end
    local readList = {}
    for _, key in ipairs(C.STATS) do readList[#readList + 1] = key .. " " .. tostring(read[key] or 0) end
    local lines = {}
    lines[#lines + 1] = string.format("HARMONIE SVU3 Sandbox: vehicle stats read (cars): %s; SVU3's hardest upgrade %d+%d.",
        table.concat(readList, ", "), refMain, refSecond)
    for t = 1, C.TIERS do
        local m, s = C.tierCeiling(t)
        lines[#lines + 1] = string.format("HARMONIE SVU3 Sandbox: tier %d (%d+%d): %s", t, m, s,
            table.concat(byTier[t] or {}, ", "))
    end
    if #unranked > 0 then
        lines[#lines + 1] = "HARMONIE SVU3 Sandbox: no stats, SVU3's own levels (tier 3 ceiling): " .. table.concat(unranked, ", ")
    end
    local key = table.concat(lines, "\n")
    if C.lastReport ~= key then
        C.lastReport = key
        for _, l in ipairs(lines) do print(l) end
    end
end

-- returns how many install levels differ from SVU3's own
function C.applyTiers()
    if not ATA2TuningTable then return 0 end
    local enabled = sv("VehicleTierScaling", true) ~= false
    local names = {}
    for name, car in pairs(ATA2TuningTable) do
        if type(car) == "table" and type(car.parts) == "table" then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        ATA2TuningTable[name] = ownCopy(name, ATA2TuningTable[name])
    end
    local refMain, refSecond = C.reference(names)
    local tiers, read, manual = {}, {}, {}
    C.statsOf = {}
    if enabled then
        tiers, read = C.vehicleTiers(names)
        local exact, prefix = C.parseOverrides(sv("VehicleTierOverrides", ""))
        for _, n in ipairs(names) do
            local t = C.overrideTier(n, exact, prefix)
            if t then tiers[n] = t; manual[n] = true end
        end
        report(names, tiers, read, manual, refMain, refSecond)
    end
    local changed = 0
    for _, name in ipairs(names) do
        local car = ATA2TuningTable[name]
        local tier = tiers[name] or C.TIERS
        car.__harmonieTier = enabled and tier or nil
        car.__harmonieManual = manual[name] or nil
        local main, second = C.tierCeiling(tier)
        for partName, models in pairs(car.parts) do
            for modelName, model in pairs(models) do
                local o = C.orig[name][partName] and C.orig[name][partName][modelName]
                local skills = type(model) == "table" and model.install and model.install.skills
                if o and type(skills) == "table" then
                    local nv = enabled and C.scaleSkills(o, main, second, refMain, refSecond) or o
                    for k, v in pairs(nv) do
                        if v ~= o[k] then changed = changed + 1 end
                        skills[k] = v
                    end
                end
            end
        end
    end
    return changed
end

C.applyAll = C.applyTiers

function C.enabled() return sv("VehicleTierScaling", true) ~= false end

local function wrapAddNewCars()
    if C.wrapped or not ATA2Tuning_AddNewCars then return end
    C.wrapped = true
    local orig = ATA2Tuning_AddNewCars
    ATA2Tuning_AddNewCars = function(carsTable, ...)
        local r = orig(carsTable, ...)
        C.applyTiers()
        return r
    end
end

local function run()
    wrapAddNewCars()
    C.applyTiers()
end

if Events then
    if Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(run) end
    if Events.OnGameStart then Events.OnGameStart.Add(run) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(run) end
end

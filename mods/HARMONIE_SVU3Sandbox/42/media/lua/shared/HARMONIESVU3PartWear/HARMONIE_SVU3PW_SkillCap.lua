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
function C.capTable(carsTable, max)
    local changed = 0
    for _, car in pairs(carsTable or {}) do
        if type(car) == "table" and type(car.parts) == "table" then
            for _, models in pairs(car.parts) do
                if type(models) == "table" then
                    for _, model in pairs(models) do
                        local install = type(model) == "table" and model.install
                        if type(install) == "table" and C.capSkills(install.skills, max) > 0 then
                            changed = changed + 1
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
    local max = C.maxTotal()
    local n = C.capTable(ATA2TuningTable, max)
    if n > 0 then
        print(string.format("HARMONIE SVU3 Sandbox: %d upgrade install(s) lowered to a skill total of %d.", n, max))
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

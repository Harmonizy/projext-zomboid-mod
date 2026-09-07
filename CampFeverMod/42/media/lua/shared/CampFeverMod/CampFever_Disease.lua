--[[
    Camp Fever — a tiny 3-stage disease, built as a learning example
    modelled loosely on Extensive Health Rework Evolved's approach:
    ModData holds state, Events.EveryHours advances it, one item cures it.

    Stats note (Build 42): most CharacterStat values are 0-1, but PAIN is 0-100.
    Always read/write stats through CharacterStat, e.g. stats:get(CharacterStat.PAIN),
    not the old stats:getPain() style getters from Build 41.
]]--

CampFeverMod = CampFeverMod or {}
CampFeverMod.Disease = {}

-- ===== Tunables (edit these to retune the disease) =====
local BASE_CHANCE_PER_HOUR = 0.004   -- ~0.4%/hour baseline risk, before run-down scaling
local STAGE_HOURS = { 12, 24, 24 }   -- hours spent in Stage 1 (mild), 2 (peak), 3 (recovery)

-- ===== Stat helpers (B42-safe: goes through CharacterStat, falls back quietly if missing) =====
local function getStat(stats, statName)
    if CharacterStat and CharacterStat[statName] then
        local ok, v = pcall(function() return stats:get(CharacterStat[statName]) end)
        if ok and v then return v end
    end
    return 0
end

local function bumpStat(stats, statName, delta, cap)
    if not (CharacterStat and CharacterStat[statName]) then return end
    local current = getStat(stats, statName)
    local target = math.min(cap, current + delta)
    pcall(function() stats:set(CharacterStat[statName], target) end)
end

-- ===== ModData =====
local function getData(player)
    local modData = player:getModData()
    if not modData.CampFever then
        modData.CampFever = { active = false, stage = 1, hoursInStage = 0 }
    end
    return modData.CampFever
end

function CampFeverMod.Disease.IsSick(player)
    return getData(player).active == true
end

function CampFeverMod.Disease.GetStage(player)
    return getData(player).stage
end

function CampFeverMod.Disease.Contract(player)
    local data = getData(player)
    if data.active then return end
    data.active = true
    data.stage = 1
    data.hoursInStage = 0
    if player.Say then player:Say("I don't feel so good... must be Camp Fever.") end
end

function CampFeverMod.Disease.SetStage(player, stage)
    if stage < 1 or stage > 3 then
        if player.Say then player:Say("Camp Fever only has stages 1 to 3.") end
        return
    end
    local data = getData(player)
    data.active = true
    data.stage = stage
    data.hoursInStage = 0
    if player.Say then player:Say("Camp Fever jumped to stage " .. stage .. ".") end
end

function CampFeverMod.Disease.Cure(player)
    local data = getData(player)
    if not data.active then
        if player.Say then player:Say("I don't have Camp Fever right now.") end
        return
    end
    data.active = false
    data.stage = 1
    data.hoursInStage = 0
    if player.Say then player:Say("The fever's finally breaking. I feel a lot better.") end
end

-- ===== Progression, called once per in-game hour for a sick player =====
local function progressDisease(player)
    local data = getData(player)
    if not data.active then return end

    data.hoursInStage = data.hoursInStage + 1
    local stats = player:getStats()

    if data.stage == 1 then
        -- Mild: a little tired, a little "off" (SICKNESS is 0-1 like fatigue)
        bumpStat(stats, "FATIGUE", 0.02, 1.0)
        bumpStat(stats, "SICKNESS", 0.01, 0.30)
        if data.hoursInStage >= STAGE_HOURS[1] then
            data.stage = 2
            data.hoursInStage = 0
            if player.Say then player:Say("The fever's getting worse...") end
        end

    elseif data.stage == 2 then
        -- Peak: worse fatigue/sickness, plus some general pain (PAIN is 0-100, not 0-1!)
        bumpStat(stats, "FATIGUE", 0.04, 1.0)
        bumpStat(stats, "SICKNESS", 0.02, 0.60)
        bumpStat(stats, "PAIN", 3, 30)
        if data.hoursInStage >= STAGE_HOURS[2] then
            data.stage = 3
            data.hoursInStage = 0
            if player.Say then player:Say("I think the worst has passed...") end
        end

    elseif data.stage == 3 then
        -- Recovery: no new symptoms added; vanilla recovery (rest/food/water) handles the rest.
        if data.hoursInStage >= STAGE_HOURS[3] then
            CampFeverMod.Disease.Cure(player)
        end
    end
end

-- ===== Infection roll for a currently-healthy player =====
local function tryInfect(player)
    if CampFeverMod.Disease.IsSick(player) then return end
    local stats = player:getStats()
    -- Being run down (hungry/tired) raises risk — a simple stand-in for "weak immune system".
    local fatigue = getStat(stats, "FATIGUE")
    local hunger = getStat(stats, "HUNGER")
    local riskMultiplier = 1.0 + fatigue + hunger
    local chance = BASE_CHANCE_PER_HOUR * riskMultiplier
    if ZombRand(1000) / 1000 < chance then
        CampFeverMod.Disease.Contract(player)
    end
end

-- ===== Hourly tick (singleplayer-focused: drives the local player only) =====
local function onEveryHours()
    local player = getSpecificPlayer(0)
    if not player then return end
    if CampFeverMod.Disease.IsSick(player) then
        progressDisease(player)
    else
        tryInfect(player)
    end
end

Events.EveryHours.Add(onEveryHours)

print("CampFeverMod: Camp Fever disease module loaded")

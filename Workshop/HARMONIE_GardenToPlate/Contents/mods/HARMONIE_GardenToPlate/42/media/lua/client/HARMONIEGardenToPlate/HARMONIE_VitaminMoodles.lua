--[[
    HARMONIE - From Garden to Plate
    One moodle per vitamin (6 total: VitaminA..VitaminE, VitaminK), built on
    MoodleFramework (Workshop 3396446795, id=MoodleFramework, require=MoodleFramework
    in mod.info -- see mods/workflow.txt section 8.2 for the framework API this
    file relies on).

    Soft-dependency guarded (mirrors the pattern documented in workflow.txt,
    itself taken from More Traits' own MoodleFramework usage): if MoodleFramework
    isn't active, this whole file becomes a no-op instead of erroring, since
    require= already guarantees load order but not that the player actually
    kept the mod enabled.

    Read-only presentation on top of the existing, unmodified vitamin system --
    this file never writes to VitData, never grants/revokes anything. All the
    real effect logic stays exactly where it already lives, in
    HARMONIE_VitaminEffects.lua / HARMONIE_VitaminChecker.lua.

    One moodle, four MoodleFramework severity levels, deliberately collapsed
    onto this mod's own two real bands (not four invented ones) rather than
    the other way around:
      - levels 1-2 = "Low" band (value < sufficientThreshold) -- title/desc
        warn what happens if it keeps dropping (Moodles.json lvl1/lvl2, same
        text for both).
      - levels 3-4 = "Critical" band (value < criticalThreshold) -- title/desc
        say what's actually wrong right now, and how to clear it (Moodles.json
        lvl3/lvl4, same text for both).
      - Good side (levels 1-4) is set to unreachable values via nil so the
        moodle only ever shows Bad or is hidden entirely at Sufficient --
        there's no "your vitamins are amazing" moodle, only "something's
        wrong" feedback.
    Thresholds are read from HARMONIE_GTP.Config every time they change (see
    onCheckerTick below) so a live sandbox/admin-panel edit to
    criticalThreshold/sufficientThreshold is reflected here too, not just in
    the Reserve/effect logic.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

local function isMoodleFrameworkActive()
    local activatedMods = getActivatedMods()
    for i = 0, activatedMods:size() - 1 do
        if activatedMods:get(i) == "MoodleFramework" then
            return true
        end
    end
    return false
end

if not isMoodleFrameworkActive() then
    return
end

local status, MF_ISMoodle = pcall(require, "MF_ISMoodle")
if not status or not MF_ISMoodle or not MF_ISMoodle.createMoodle then
    print("HARMONIE_GardenToPlate: MoodleFramework detected but MF_ISMoodle failed to load, skipping vitamin moodles.")
    return
end

local MOODLE_NAMES = {
    A = "VitaminA",
    B = "VitaminB",
    C = "VitaminC",
    D = "VitaminD",
    E = "VitaminE",
    K = "VitaminK",
}

for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
    MF.createMoodle(MOODLE_NAMES[vit])
end

-- Applies (or re-applies, on a live threshold change) this mod's own band
-- boundaries onto the moodle's 4 MoodleFramework levels, per the header note.
local function applyThresholds(moodle)
    local sufficientRatio = HARMONIE_GTP.Config.sufficientThreshold / HARMONIE_GTP.Config.maxValue
    local criticalRatio = HARMONIE_GTP.Config.criticalThreshold / HARMONIE_GTP.Config.maxValue
    moodle:setThresholds(
        criticalRatio, criticalRatio, sufficientRatio, sufficientRatio, -- bad4, bad3, bad2, bad1
        nil, nil, nil, nil -- good1..good4: unreachable, no Good side wanted
    )
end

local CHECK_INTERVAL_MS = 10000
local lastCheckMs = 0

-- MF.createMoodle() above only registers a lazy Events.OnCreatePlayer hook
-- (see MF_ISMoodle.lua) -- the actual per-player moodle instance doesn't
-- exist until that fires, so thresholds can't be set at file-load time.
-- Tracked per playerNum+vitamin so a threshold only needs re-applying once
-- right after the moodle first exists, or again later if the sandbox/admin
-- panel changes criticalThreshold/sufficientThreshold live.
local appliedThresholdKey = {}

local function updatePlayerMoodles(player)
    local playerNum = player:getPlayerNum()
    local currentKey = HARMONIE_GTP.Config.criticalThreshold .. ":" .. HARMONIE_GTP.Config.sufficientThreshold

    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        local moodle = MF.getMoodle(MOODLE_NAMES[vit], playerNum)
        if moodle then
            local trackKey = playerNum .. ":" .. vit
            if appliedThresholdKey[trackKey] ~= currentKey then
                applyThresholds(moodle)
                appliedThresholdKey[trackKey] = currentKey
            end

            local value = HARMONIE_GTP.VitData.Get(player, vit) / HARMONIE_GTP.Config.maxValue
            moodle:setValue(value)
        end
    end
end

local function onMoodleTick()
    local now = getTimestampMs and getTimestampMs() or 0
    if now - lastCheckMs < CHECK_INTERVAL_MS then return end
    lastCheckMs = now

    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            updatePlayerMoodles(player)
        end
    end
end

Events.OnTick.Add(onMoodleTick)

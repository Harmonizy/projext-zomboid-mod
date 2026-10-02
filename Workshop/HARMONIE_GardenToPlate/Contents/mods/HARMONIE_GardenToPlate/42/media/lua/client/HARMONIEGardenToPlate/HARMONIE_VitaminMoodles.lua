--[[
    HARMONIE - From Garden to Plate
    One moodle per vitamin (6 total: VitaminA..VitaminE, VitaminK), built on
    MoodleFramework (Workshop 3396446795, id=MoodleFramework). Hard dependency
    via require=MoodleFramework in mod.info (see mods/workflow.txt section 8.2
    for the framework API this file relies on) -- confirmed real/tested in
    this repo (workflow.txt section 1) that require= orders the WHOLE requiring
    mod's Lua after the required mod's, so by the time this file's top level
    runs, MoodleFramework's own files (including MF_ISMoodle.lua) have already
    executed. No getActivatedMods()/pcall gating needed, matching every other
    HARMONIE mod's hard-require= files (HomeMedic, LifestyleAudioTune, etc.) --
    that pattern is only for a genuinely optional/soft dependency.

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
    onMoodleTick below) so a live sandbox/admin-panel edit to
    criticalThreshold/sufficientThreshold is reflected here too, not just in
    the Reserve/effect logic.

    BOUNDARY NOTE (confirmed the hard way from a real user report -- setting
    Reserve to exactly 20 via the admin panel showed the moodle as Critical
    while the actual penalty/band logic still read Low): MoodleFramework's
    own MF_ISMoodle.lua:getLevel() compares with "value <= threasholdBad3"
    (INCLUSIVE), while HARMONIE_GTP.GetBand compares with
    "value < criticalThreshold" (EXCLUSIVE) -- both read the exact same
    live Config.criticalThreshold/sufficientThreshold, there is no separate
    hardcoded copy anywhere, but the two systems disagree right AT the
    threshold value itself because of the different comparison operator.
    Fixed by feeding MoodleFramework a threshold ratio nudged down by a
    tiny BOUNDARY_EPSILON, so its inclusive "<=" only ever fires for the
    same values our own exclusive "<" already would -- imperceptible for
    real Reserve values (which only ever move by real food amounts, never
    by 0.01), but makes an admin-panel test landing on the exact integer
    threshold agree between moodle and actual effect.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"
require "MF_ISMoodle"

local MOODLE_NAMES = {
    A = "VitaminA",
    B = "VitaminB",
    C = "VitaminC",
    D = "VitaminD",
    E = "VitaminE",
    K = "VitaminK",
}

-- See the header's BOUNDARY NOTE -- MoodleFramework's own threshold check
-- is "<=" (inclusive), ours is "<" (exclusive); nudging the ratio fed to
-- MoodleFramework down by this amount makes the two agree everywhere it
-- actually matters, without visibly shifting the real threshold (0.0001
-- of the 0-1 ratio scale = 0.01 out of a 0-100 Reserve value).
local BOUNDARY_EPSILON = 0.0001
-- above any value the moodle is ever given (0..1): the Good side never shows
local NO_GOOD = 2.0

-- Applies (or re-applies, on a live threshold change) this mod's own band
-- boundaries onto the moodle's 4 MoodleFramework levels, per the header note.
local function applyThresholds(moodle)
    local sufficientRatio = HARMONIE_GTP.Config.sufficientThreshold / HARMONIE_GTP.Config.maxValue - BOUNDARY_EPSILON
    local criticalRatio = HARMONIE_GTP.Config.criticalThreshold / HARMONIE_GTP.Config.maxValue - BOUNDARY_EPSILON
    moodle:setThresholds(
        criticalRatio, criticalRatio, sufficientRatio, sufficientRatio, -- bad4, bad3, bad2, bad1
        -- good1..good4: UNREACHABLE (the value is 0..1). 0.7.5 fix: these used
        -- to be nil, which MoodleFramework does NOT read as "off" -- a nil
        -- falls back to its defaults (0.6/0.7/0.8/0.9), so a full reserve
        -- showed a "Good" level-4 moodle with no text (the raw key
        -- Moodles_VitaminA_Good_lvl4 on screen, reported on a server).
        NO_GOOD, NO_GOOD, NO_GOOD, NO_GOOD
    )
end

-- MF.createMoodle() only registers a lazy Events.OnCreatePlayer hook (see
-- MF_ISMoodle.lua) -- the actual per-player moodle instance doesn't exist
-- until that fires, so thresholds can't be set right after createMoodle.
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

local CHECK_INTERVAL_MS = 10000
local lastCheckMs = 0

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

for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
    MF.createMoodle(MOODLE_NAMES[vit])
end

Events.OnTick.Add(onMoodleTick)

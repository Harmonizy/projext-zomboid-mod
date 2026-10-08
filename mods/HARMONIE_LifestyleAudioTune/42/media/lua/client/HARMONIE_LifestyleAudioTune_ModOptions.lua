--[[
    Replaces this mod's earlier SandboxVars-based volume slider (which only
    took effect on world load/reload, since sandbox vars are a fixed
    snapshot for the life of a save -- confirmed the hard way after the
    user reported the old slider not doing anything without a restart).

    This uses Project Zomboid's own PZAPI.ModOptions + GameSounds
    category-volume API instead -- the same mechanism ModernFirearmsSystem's
    own media/lua/client/EFK_Mod_Options.lua uses for its "Weapon Shot
    Volume"/"Weapon Reload Volume" sliders (read directly while patching
    that mod). It creates a real page under Options -> Mods, and
    GameSounds.getSoundsInCategory + sound:setUserVolume() apply live,
    per-player, with no restart.

    This only works for a mod's sounds when their sound scripts declare an
    exclusive `category` value vanilla doesn't already use for something
    else -- confirmed by grepping every vanilla media/scripts file for
    `category = X` and counting: "Item" (1521 uses) and "Object" (351
    uses) are shared with huge amounts of vanilla content, so scaling
    those categories would affect the whole game, not just this mod.
    "DJ", "Oldies" and "SFX", however, have zero vanilla usage and are
    exclusive to Lifestyle: Hobbies' own DJ Booth, Jukebox/genre-track and
    general equipment sound scripts respectively (confirmed the same way)
    -- safe to scale directly.

    Instruments and Effects_sounds_player.txt use the shared "Item"
    category, so they're NOT covered here; HARMONIE_LifestyleAudioTune_Hooks.lua
    still handles those individually, but now reads the same live
    multiplier this file sets (HARMONIE_LifestyleAudioTune_LiveMultiplier,
    declared in HARMONIE_LifestyleAudioTune_Volumes.lua) instead of a
    sandbox var, so everything moves together and updates live.

    Does NOT touch the Jukebox's own actual song playback -- that already
    has its own native, working right-click "Jukebox Volume" menu in
    Lifestyle itself (JukeboxContextMenu.lua), set via an explicit
    emitter:setVolume() call that overrides whatever category user-volume
    says. This slider still correctly covers the Jukebox's idle hum and
    turn-on/off/switch chimes (plain playSoundImpl/playSound, no override).

    Does NOT and cannot adjust hearing distance/range live -- confirmed
    (again) no Lua API exists for that; distance stays at this mod's
    static 25-tile override in the HARMONIE_AudioTune_*.txt sound scripts.
]]--

local LIVE_CATEGORIES = {"DJ", "Oldies", "SFX"}
-- console.txt: "[HARMONIE_LAT][Options][SP|client|server]" lines
local function log(fmt, ...)
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    local side = (isServer and isServer()) and "server" or ((isClient and isClient()) and "client" or "SP")
    print("[HARMONIE_LAT][Options][" .. side .. "] " .. (ok and msg or tostring(fmt)))
end
local logSeen = {}
local function logOnce(key, fmt, ...)
    if logSeen[key] then return end
    logSeen[key] = true
    log(fmt, ...)
end

local function getStartingVolume()
    local sounds = GameSounds.getSoundsInCategory("DJ")
    if sounds and sounds:size() > 0 then
        local sound = sounds:get(0)
        if sound then return sound:getUserVolume() end
    end
    return 1.0
end

local function applyVolume(volume)
    HARMONIE_LifestyleAudioTune_LiveMultiplier = volume

    local counts = {}
    for _, category in ipairs(LIVE_CATEGORIES) do
        local sounds = GameSounds.getSoundsInCategory(category)
        counts[#counts + 1] = category .. "=" .. (sounds and sounds:size() or 0)
        if sounds then
            for i = 1, sounds:size() do
                local sound = sounds:get(i - 1)
                if sound then sound:setUserVolume(volume) end
            end
        end
    end

    GameSounds.saveINI()
    return table.concat(counts, ", ")
end

local function Init()
    local options = PZAPI.ModOptions:create("HARMONIE_LifestyleAudioTune", getText("UI_options_HARMONIE_LAT_title"))

    options:addTitle(getText("UI_options_HARMONIE_LAT_section"))
    options:addDescription(getText("UI_options_HARMONIE_LAT_desc"))

    local startingVolume = getStartingVolume()
    HARMONIE_LifestyleAudioTune_LiveMultiplier = startingVolume

    local volumeSlider = options:addSlider("volume", getText("UI_options_HARMONIE_LAT_volume"), 0, 2, 0.01,
        startingVolume, getText("UI_options_HARMONIE_LAT_volume_tooltip"))

    volumeSlider.onChange = function(_, value) applyVolume(value) end
    volumeSlider.onChangeApply = function(_, value)
        -- logged on Apply only (onChange fires for every slider step)
        log("volume applied: %.2f (sounds per category: %s)", value, applyVolume(value))
    end
    log("options page made, starting volume %.2f", startingVolume)
end

Init()

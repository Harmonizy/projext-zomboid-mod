--[[
    "He-Man / HEYYEYAAEYAAAEYAEYAA" meme song, added to Lifestyle: Hobbies'
    instrument system the same way as AddMoreTracks_HARMONIE_JoJo.lua (see
    that file for the mechanism explanation). Kept in a separate file/sound
    script/media folder from JoJo since it's an unrelated franchise.

    Registered on Harmonica, Keytar and Flute, matching the requested
    instrumentation (harmonica, keyboard, flute).

    Real .ogg file already in place with confirmed length:
        media/sound/HeMan/HeMan_HEYYEYAAEYAAAEYAEYAA.ogg   (127s)
]]--

local HarmonicaTracks = require "TimedActions/PlayHarmonicaTracks"
table.insert(HarmonicaTracks, {level=0, sound="HeMan_HEYYEYAAEYAAAEYAEYAA", length=127, name="HEYYEYAAEYAAAEYAEYAA"})

local KeytarTracks = require "TimedActions/PlayKeytarTracks"
table.insert(KeytarTracks, {level=0, sound="HeMan_HEYYEYAAEYAAAEYAEYAA", length=127, name="HEYYEYAAEYAAAEYAEYAA"})

local FluteTracks = require "TimedActions/PlayFluteTracks"
table.insert(FluteTracks, {level=0, sound="HeMan_HEYYEYAAEYAAAEYAEYAA", length=127, name="HEYYEYAAEYAAAEYAEYAA"})

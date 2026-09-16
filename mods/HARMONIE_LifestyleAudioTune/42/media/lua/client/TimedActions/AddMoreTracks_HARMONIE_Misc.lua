--[[
    Extra one-off instrument tracks, registered the same way as
    AddMoreTracks_HARMONIE_JoJo.lua (see that file for the mechanism
    explanation and the full list of instrument tables Lifestyle's addon
    extension point actually supports).

    Bothnia - Someday I'll Wait -> Acoustic Guitar only. Ukulele was
    requested if available, but Lifestyle's addon extension point has no
    PlayUkuleleTracks module (not one of the 9 supported instrument tables),
    so there's no ukulele option to register it on -- Acoustic Guitar is the
    closest match available.

    Violette Wautier - Wanna Be Yours -> Keytar. Piano isn't in the 9
    supported instrument tables either (same reason JoJo's Fighting Gold /
    Giorno's Theme use Keytar as a piano stand-in) -- Keytar again here.

    Real .ogg files already in place with confirmed lengths:
        media/sound/Bothnia_SomedayIllWait.ogg          (193s)
        media/sound/VioletteWautier_WannaBeYours.ogg    (230s)
]]--

local GuitarAcousticTracks = require "TimedActions/PlayGuitarAcousticTracks"
table.insert(GuitarAcousticTracks, {level=0, sound="Bothnia_SomedayIllWait", length=193, name="Bothnia - Someday I'll Wait"})

local KeytarTracks = require "TimedActions/PlayKeytarTracks"
table.insert(KeytarTracks, {level=0, sound="VioletteWautier_WannaBeYours", length=230, name="Violette Wautier - Wanna Be Yours"})

--[[
    JoJo's Bizarre Adventure openings, added to Lifestyle: Hobbies' instrument
    system via its own addon extension point (same mechanism as the reference
    addon mods studied first: Workshop 3783028777 "LifestyleRedemptionB42",
    3016221184 "Hazy Lifestyle", 3782768673 "UndertaleOnGuitar") -- require
    "TimedActions/Play<Instrument>Tracks" then table.insert a
    {level, sound, length, name} entry, no changes to Lifestyle's own files.

    Each song is registered into MULTIPLE instrument tables on purpose (same
    sound= name reused across several table.insert calls) to match the real
    instrumentation described for each track -- a song isn't tied to a single
    instrument, it can be played on any of the instruments that suit it. Only
    the 9 instrument tables Lifestyle's addon extension point actually
    supports are used (see workflow.txt section 6.1): PlayTrumpetTracks,
    PlayGuitarAcousticTracks, PlayBanjoTracks, PlayFluteTracks,
    PlayGuitarElectricBassTracks, PlayGuitarElectricTracks, PlayKeytarTracks,
    PlaySaxophoneTracks, PlayHarmonicaTracks. Piano/Violin/Drums are NOT in
    this set (different, unconfirmed registration mechanism) -- Keytar is
    used as the closest available stand-in wherever a song calls for
    keyboard/piano/synth/orchestral textures.

    All 4 songs already have real .ogg files in place with confirmed lengths:
        media/sound/JoJo_SonoChiNoSadame.ogg   (92s)
        media/sound/JoJo_BloodyStream.ogg      (89s)
        media/sound/JoJo_FightingGold.ogg      (253s)
        media/sound/JoJo_GiornosTheme.ogg      (296s)
    (He-Man's HEYYEYAAEYAAAEYAEYAA is a separate franchise -- registered in
    AddMoreTracks_HARMONIE_HeMan.lua instead, not here.)
]]--

local GuitarElectricTracks = require "TimedActions/PlayGuitarElectricTracks"
-- Sono Chi no Sadame: brass + heavy electric guitar
table.insert(GuitarElectricTracks, {level=0, sound="JoJo_SonoChiNoSadame", length=92, name="JoJo: Sono Chi no Sadame (Phantom Blood/Battle Tendency OP)"})
-- Fighting Gold: rock mixed with orchestral hits
table.insert(GuitarElectricTracks, {level=0, sound="JoJo_FightingGold", length=253, name="JoJo: Fighting Gold (Golden Wind OP1)"})

local GuitarElectricBassTracks = require "TimedActions/PlayGuitarElectricBassTracks"
-- Bloody Stream: bassline-driven disco groove
table.insert(GuitarElectricBassTracks, {level=0, sound="JoJo_BloodyStream", length=89, name="JoJo: Bloody Stream (Stardust Crusaders OP1)"})
-- Fighting Gold: rock mixed with orchestral hits
table.insert(GuitarElectricBassTracks, {level=0, sound="JoJo_FightingGold", length=253, name="JoJo: Fighting Gold (Golden Wind OP1)"})

local SaxophoneTracks = require "TimedActions/PlaySaxophoneTracks"
-- Sono Chi no Sadame: brass section
table.insert(SaxophoneTracks, {level=0, sound="JoJo_SonoChiNoSadame", length=92, name="JoJo: Sono Chi no Sadame (Phantom Blood/Battle Tendency OP)"})
-- Bloody Stream: disco horn stabs
table.insert(SaxophoneTracks, {level=0, sound="JoJo_BloodyStream", length=89, name="JoJo: Bloody Stream (Stardust Crusaders OP1)"})
-- Giorno's Theme: scat/saxophone build-up
table.insert(SaxophoneTracks, {level=0, sound="JoJo_GiornosTheme", length=296, name="JoJo: Giorno's Theme (Golden Wind OP2)"})

local TrumpetTracks = require "TimedActions/PlayTrumpetTracks"
-- Sono Chi no Sadame: brass section
table.insert(TrumpetTracks, {level=0, sound="JoJo_SonoChiNoSadame", length=92, name="JoJo: Sono Chi no Sadame (Phantom Blood/Battle Tendency OP)"})
-- Bloody Stream: disco horn stabs
table.insert(TrumpetTracks, {level=0, sound="JoJo_BloodyStream", length=89, name="JoJo: Bloody Stream (Stardust Crusaders OP1)"})

local KeytarTracks = require "TimedActions/PlayKeytarTracks"
-- Fighting Gold: orchestral synth textures (Keytar stands in for orchestra/keys)
table.insert(KeytarTracks, {level=0, sound="JoJo_FightingGold", length=253, name="JoJo: Fighting Gold (Golden Wind OP1)"})
-- Giorno's Theme: piano breakdown (Keytar stands in for piano)
table.insert(KeytarTracks, {level=0, sound="JoJo_GiornosTheme", length=296, name="JoJo: Giorno's Theme (Golden Wind OP2)"})

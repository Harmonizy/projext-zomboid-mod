--[[
    JoJo's Bizarre Adventure openings, added to Lifestyle: Hobbies' instrument
    system via its own addon extension point (same mechanism as the reference
    addon mods studied first: Workshop 3783028777 "LifestyleRedemptionB42",
    3016221184 "Hazy Lifestyle", 3782768673 "UndertaleOnGuitar") -- require
    "TimedActions/Play<Instrument>Tracks" then table.insert a
    {level, sound, length, name} entry, no changes to Lifestyle's own files.

    *** length below is a PLACEHOLDER (90 = a typical TV-size OP length) for
    every track -- replace it with the real duration in seconds of whichever
    .ogg file you actually drop in, or the song will cut off early / leave
    dead air. Sound file paths expected (not included -- see
    HARMONIE_AudioTune_JoJo_sounds_item.txt for why): ***

        media/sound/JoJo/JoJo_SonoChiNoSadame.ogg
        media/sound/JoJo/JoJo_BloodyStream.ogg
        media/sound/JoJo/JoJo_StandProud.ogg
        media/sound/JoJo/JoJo_CrazyNoisyBizarreTown.ogg
        media/sound/JoJo/JoJo_Chase.ogg
        media/sound/JoJo/JoJo_FightingGold.ogg
        media/sound/JoJo/JoJo_TraitorsRequiem.ogg
        media/sound/JoJo/JoJo_GreatDays.ogg
        media/sound/JoJo/JoJo_StoneOcean.ogg
]]--

local GuitarElectricTracks = require "TimedActions/PlayGuitarElectricTracks"
table.insert(GuitarElectricTracks, {level=0, sound="JoJo_SonoChiNoSadame", length=92, name="JoJo: Sono Chi no Sadame (Phantom Blood/Battle Tendency OP)"})
table.insert(GuitarElectricTracks, {level=0, sound="JoJo_BloodyStream", length=89, name="JoJo: Bloody Stream (Stardust Crusaders OP1)"})
table.insert(GuitarElectricTracks, {level=0, sound="JoJo_FightingGold", length=90, name="JoJo: Fighting Gold (Golden Wind OP1)"})
table.insert(GuitarElectricTracks, {level=0, sound="JoJo_GreatDays", length=90, name="JoJo: Great Days (Golden Wind OP3)"})

local GuitarElectricBassTracks = require "TimedActions/PlayGuitarElectricBassTracks"
table.insert(GuitarElectricBassTracks, {level=0, sound="JoJo_StandProud", length=90, name="JoJo: Stand Proud (Stardust Crusaders OP2)"})
table.insert(GuitarElectricBassTracks, {level=0, sound="JoJo_TraitorsRequiem", length=90, name="JoJo: Traitor's Requiem (Golden Wind OP2)"})
table.insert(GuitarElectricBassTracks, {level=0, sound="JoJo_StoneOcean", length=90, name="JoJo: STONE OCEAN (Stone Ocean OP1)"})

local SaxophoneTracks = require "TimedActions/PlaySaxophoneTracks"
table.insert(SaxophoneTracks, {level=0, sound="JoJo_CrazyNoisyBizarreTown", length=90, name="JoJo: Crazy Noisy Bizarre Town (Diamond is Unbreakable OP1)"})

local TrumpetTracks = require "TimedActions/PlayTrumpetTracks"
table.insert(TrumpetTracks, {level=0, sound="JoJo_Chase", length=90, name="JoJo: Chase (Diamond is Unbreakable OP2)"})

-- console.txt: "[HARMONIE_LAT][Tracks][SP|client|server]" lines
local function log(fmt, ...)
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    local side = (isServer and isServer()) and "server" or ((isClient and isClient()) and "client" or "SP")
    print("[HARMONIE_LAT][Tracks][" .. side .. "] " .. (ok and msg or tostring(fmt)))
end
local logSeen = {}
local function logOnce(key, fmt, ...)
    if logSeen[key] then return end
    logSeen[key] = true
    log(fmt, ...)
end

-- a missing Lifestyle track list (renamed or removed) is logged and skipped
-- instead of erroring the whole file
local added, missing = 0, 0
local function addTrack(list, track)
    if type(list) ~= "table" then
        missing = missing + 1
        log("track list missing -- not added: %s", tostring(track and track.name))
        return
    end
    table.insert(list, track)
    added = added + 1
end
local realRequire = require
local function require(name)
    local ok, v = pcall(realRequire, name)
    if not ok or type(v) ~= "table" then log("require %s failed: %s", tostring(name), tostring(v)); return nil end
    return v
end

local GuitarElectricTracks = require "TimedActions/PlayGuitarElectricTracks"
addTrack(GuitarElectricTracks, {level=0, sound="JoJo_SonoChiNoSadame", length=92, name="JoJo: Sono Chi no Sadame (Phantom Blood/Battle Tendency OP)"})
addTrack(GuitarElectricTracks, {level=0, sound="JoJo_FightingGold", length=253, name="JoJo: Fighting Gold (Golden Wind OP1)"})

local GuitarElectricBassTracks = require "TimedActions/PlayGuitarElectricBassTracks"
addTrack(GuitarElectricBassTracks, {level=0, sound="JoJo_BloodyStream", length=90, name="JoJo: Bloody Stream (Stardust Crusaders OP1)"})
addTrack(GuitarElectricBassTracks, {level=0, sound="JoJo_FightingGold", length=253, name="JoJo: Fighting Gold (Golden Wind OP1)"})

local GuitarAcousticTracks = require "TimedActions/PlayGuitarAcousticTracks"
addTrack(GuitarAcousticTracks, {level=0, sound="Bothnia_SomedayIllWait", length=193, name="Bothnia - Someday I'll Wait"})

local SaxophoneTracks = require "TimedActions/PlaySaxophoneTracks"
addTrack(SaxophoneTracks, {level=0, sound="JoJo_SonoChiNoSadame", length=92, name="JoJo: Sono Chi no Sadame (Phantom Blood/Battle Tendency OP)"})
addTrack(SaxophoneTracks, {level=0, sound="JoJo_BloodyStream", length=90, name="JoJo: Bloody Stream (Stardust Crusaders OP1)"})
addTrack(SaxophoneTracks, {level=0, sound="JoJo_GiornosTheme", length=296, name="JoJo: Giorno's Theme (Golden Wind OP2)"})

local TrumpetTracks = require "TimedActions/PlayTrumpetTracks"
addTrack(TrumpetTracks, {level=0, sound="JoJo_SonoChiNoSadame", length=92, name="JoJo: Sono Chi no Sadame (Phantom Blood/Battle Tendency OP)"})
addTrack(TrumpetTracks, {level=0, sound="JoJo_BloodyStream", length=90, name="JoJo: Bloody Stream (Stardust Crusaders OP1)"})

local KeytarTracks = require "TimedActions/PlayKeytarTracks"
addTrack(KeytarTracks, {level=0, sound="JoJo_FightingGold", length=253, name="JoJo: Fighting Gold (Golden Wind OP1)"})
addTrack(KeytarTracks, {level=0, sound="JoJo_GiornosTheme", length=296, name="JoJo: Giorno's Theme (Golden Wind OP2)"})
addTrack(KeytarTracks, {level=0, sound="HeMan_HEYYEYAAEYAAAEYAEYAA", length=127, name="HEYYEYAAEYAAAEYAEYAA"})
addTrack(KeytarTracks, {level=0, sound="VioletteWautier_WannaBeYours", length=230, name="Violette Wautier - Wanna Be Yours"})

local HarmonicaTracks = require "TimedActions/PlayHarmonicaTracks"
addTrack(HarmonicaTracks, {level=0, sound="HeMan_HEYYEYAAEYAAAEYAEYAA", length=127, name="HEYYEYAAEYAAAEYAEYAA"})

local FluteTracks = require "TimedActions/PlayFluteTracks"
addTrack(FluteTracks, {level=0, sound="HeMan_HEYYEYAAEYAAAEYAEYAA", length=127, name="HEYYEYAAEYAAAEYAEYAA"})

local ViolinTracks = require "TimedActions/PlayViolinTracks"
addTrack(ViolinTracks, {level=0, sound="HSR_WhattheRippleSees", length=259, name="Honkai: Star Rail - What the Ripple Sees"})

log("added %d extra instrument tracks (%d skipped)", added, missing)

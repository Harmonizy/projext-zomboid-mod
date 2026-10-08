--============================================================================
-- HARMONIE_TheWayToAttack -- sound playback (shared, plays on clients only)
--
-- Round 12 (bug report 2026-09-28: "มีแต่เสียงตอนทำสำเร็จหรือทำพลาดเท่านั้น ที่
-- เหลือเงียบกริบ ... ลองไปดูวิธีในม็อดอ้างอิง"): the only sounds heard were the
-- two played with getSoundManager():playUISound(). Casualties Undead plays
-- every one of its own sounds that way (category UI in its sound script);
-- our working sounds were 3D "Item" sounds played through the character
-- and never sounded. So every TWA sound is now a short UI one-shot, and a
-- working sound is simply played again each time the previous one ends
-- (TWASound.LENGTH, generated with the sounds by tools/gen_sounds.py).
--============================================================================

require "HARMONIE_TWA_Config"
require "HARMONIE_TWA_SoundLengths"

TWASound = TWASound or {}

--- Play `name` once (client only). `switch` = sandbox option that must be on.
function TWASound.play(name, switch)
    if not name or (isServer and isServer()) then return end
    if switch and not TWAConfig.on(switch) then return end
    -- The player's own volume (Options > Mods) and the craft window's mute
    -- button. Round 14: loudness is chosen by FILE -- every sound exists at
    -- several levels (NAME_v25 .. NAME_v200, generated), since the game's
    -- per-sound volume didn't reach UI sounds.
    if TWASound.muted then return end
    local v = TWASound.volume or 1
    if v <= 0.001 then return end
    local pct, best, bestD = v * 100, 100, math.huge
    for _, lvl in ipairs(TWASound.LEVELS or { 100 }) do
        local d = math.abs(lvl - pct)
        if d < bestD then best, bestD = lvl, d end
    end
    if best ~= 100 then name = name .. "_v" .. best end
    local sm = getSoundManager and getSoundManager()
    if sm and sm.playUISound then
        local ok, err = pcall(sm.playUISound, sm, name)
        if not ok then TWALogOnce("snd:" .. name, "Sound", "could not play %s: %s", name, tostring(err)) end
    end
    TWALogOnce("sndfirst:" .. name, "Sound", "first play of %s (repeats not logged)", name)
end

--- Call every frame/tick while the work goes on: plays `name` again as soon
--- as the previous one has finished. `state` is any table kept by the caller.
function TWASound.keepPlaying(state, name, switch)
    if not name or not getTimestampMs then return end
    local now = getTimestampMs()
    if now >= (state.twaNextSound or 0) then
        TWASound.play(name, switch)
        state.twaNextSound = now + math.max(120, (TWASound.LENGTH[name] or 500) - 30)
    end
end

--- Stop repeating (the one playing just runs out -- they are short).
function TWASound.stop(state)
    if state then state.twaNextSound = nil end
end

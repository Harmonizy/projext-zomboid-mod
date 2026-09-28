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
    local sm = getSoundManager and getSoundManager()
    if sm and sm.playUISound then sm:playUISound(name) end
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

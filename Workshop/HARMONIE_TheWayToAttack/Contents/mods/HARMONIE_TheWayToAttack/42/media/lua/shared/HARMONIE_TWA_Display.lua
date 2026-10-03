--============================================================================
-- HARMONIE_TheWayToAttack -- how damage numbers are SHOWN (shared)
--
-- Request 2026-10-03: every damage the player sees -- min / max damage and
-- DPS in the weapon tooltip and windows, the numbers that pop up on a hit,
-- a zombie's HP -- is shown x100 (a 0.8 hit reads 80). Only the display:
-- the game keeps computing with its own values (weapons keep MinDamage 0.5
-- etc., zombies keep their health ~1-2).
--============================================================================

TWADisplay = TWADisplay or {}
local D = TWADisplay

D.SCALE = 100

-- a game damage / health value -> the number shown
function D.dmg(v)
    return (tonumber(v) or 0) * D.SCALE
end

-- -> "80" (rounded to a whole number)
function D.fmt(v)
    local n = D.dmg(v)
    if n >= 0 then return tostring(math.floor(n + 0.5)) end
    return "-" .. tostring(math.floor(-n + 0.5))
end

--============================================================================
-- HARMONIE_TheWayToAttack -- how damage numbers are SHOWN (shared)
--
-- Request 2026-10-03: every damage the player sees -- min / max damage and
-- DPS in the weapon tooltip and windows, the numbers that pop up on a hit,
-- a zombie's HP -- is shown multiplied (a 0.85 hit reads 85 at x100). Only
-- the display: the game keeps computing with its own values (weapons keep
-- MinDamage 0.5 etc., zombies keep their health ~1-2).
-- The multiplier is the sandbox option DamageDisplayScale (default 100).
--============================================================================

require "HARMONIE_TWA_Config"

TWADisplay = TWADisplay or {}
local D = TWADisplay

function D.scale()
    return TWAConfig.num("DamageDisplayScale", 1)
end

-- a game damage / health value -> the number shown
function D.dmg(v)
    return (tonumber(v) or 0) * D.scale()
end

-- -> "8.5" / "12" (one decimal, none when it is .0)
function D.fmt(v)
    local n = D.dmg(v)
    local neg = n < 0
    if neg then n = -n end
    local r = math.floor(n * 10 + 0.5) / 10
    local s
    if r == math.floor(r) then s = tostring(math.floor(r)) else s = string.format("%.1f", r) end
    return neg and ("-" .. s) or s
end

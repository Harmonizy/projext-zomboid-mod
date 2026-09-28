--============================================================================
-- HARMONIE_TheWayToAttack -- sandbox settings (shared)
--
-- Round 9 (request 2026-09-28: "ทำ sandbox แบบละเอียด ทุกค่าตัวเลข และ true
-- false ที่อยู่ในม็อดต้องสามารถปรับได้ทุกอัน จัดหมวดหมู่ให้เรียบร้อย ใช้ง่าย"):
-- every tunable number and switch lives in the sandbox, in 8 pages. The
-- options, their defaults and their EN/TH text come from ONE table,
-- mods/HARMONIE_TheWayToAttack/tools/gen_sandbox.py, which writes
-- sandbox-options.txt, HARMONIE_TWA_ConfigDefaults.lua and Sandbox.json.
--
-- TWAConfig.get("Key") -> the server's sandbox value, or the default when the
-- save has none yet (an old save, or a new option added after it was made).
--============================================================================

require "HARMONIE_TWA_ConfigDefaults"

TWAConfig = TWAConfig or {}

function TWAConfig.get(key)
    local sv = SandboxVars and SandboxVars.HARMONIE_TheWayToAttack
    local v = sv and sv[key]
    if v == nil then return TWAConfig.DEFAULTS[key] end
    return v
end

-- A number option, clamped to a sane floor (a 0 would divide by zero).
function TWAConfig.num(key, floor)
    local v = tonumber(TWAConfig.get(key)) or tonumber(TWAConfig.DEFAULTS[key]) or 0
    if floor and v < floor then v = floor end
    return v
end

function TWAConfig.on(key)
    return TWAConfig.get(key) ~= false
end

-- Real seconds -> timed-action time units (B42 runs 50 per real second at
-- normal speed; Casualties Undead's heat action converts the same way).
TWAConfig.TICKS_PER_SECOND = 50
function TWAConfig.secondsToTicks(sec)
    return math.max(1, math.floor(sec * TWAConfig.TICKS_PER_SECOND + 0.5))
end

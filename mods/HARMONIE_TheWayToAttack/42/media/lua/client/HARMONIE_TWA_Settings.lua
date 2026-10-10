--============================================================================
-- HARMONIE_TheWayToAttack -- the settings window (client)
--
-- R71 ("เพิ่มปุ่มตั้งค่า เพื่อกดเปิดหน้าต่างตั้งค่า ... ปรับขนาดตัวอักษร หน้าต่าง
-- เสียง และอื่นๆอีกที่เกี่ยวข้อง"): the gear in the craft window's header
-- opens this window. Every row changes the setting at once and saves it
-- (the same values as Options > Mods, plus the craft window's own size /
-- text step / pin from HARMONIE_TWA_Window.txt).
--
--   TWASettingsUI.open(title, buildRows, theme)  (opening again closes it)
--   rows: { kind = "section", label }
--         { kind = "tick",   label, tip, get() -> bool, set(bool) }
--         { kind = "slider", label, tip, min, max, step, get() -> n, set(n), fmt(n) -> text }
--         { kind = "choice", label, tip, values = { names }, get() -> index (0 = none of
--                            them, then text() says what), set(index), text() (optional) }
--         { kind = "step",   label, tip, text() -> shown, minus(), plus() }
--         { kind = "button", label, tip, text, run() }
--         { kind = "note",   label }
-- Drawn by hand (no child widgets): the rows scroll with the mouse wheel,
-- the hovered row's explanation shows at the bottom.
--============================================================================

require "ISUI/ISPanel"
require "HARMONIE_TWA_Font"

-- 2026-10-11: the window itself is now the HARMONIE Hub's shared settings
-- window (client/HARMONIE_UIKit.lua) -- the same in all our mods; this file
-- keeps The Way To Attack's colours.
require "HARMONIE_UIKit"

TWASettingsUI = TWASettingsUI or {}
TWASettingsUI.THEME = {
    bg = { 0.035, 0.028, 0.012, 0.97 }, header = { 0.06, 0.046, 0.016, 0.98 },
    row = { 0.07, 0.056, 0.026 }, rowHover = { 0.13, 0.10, 0.04 },
    border = { 0.85, 0.64, 0.18 }, borderDim = { 0.40, 0.30, 0.10 },
    accent = { 1.0, 0.78, 0.2 }, accentDark = { 0.30, 0.20, 0.03 },
    text = { 0.97, 0.94, 0.86 }, textDim = { 0.72, 0.66, 0.54 },
}

function TWASettingsUI.open(title, buildRows, theme, opts)
    return HARMONIE_SettingsUI.open(title, buildRows, theme or TWASettingsUI.THEME, opts)
end

--[[
    HARMONIE - Home Medic : one blue theme for every window of the mod.
    The window colour tables (EHR_HealthPanelUI.Colors, the journal, the
    Medical Monitor, surgery, debug menu, ...) use these values; red stays
    for danger and blood only.
]]--

HM_Theme = HM_Theme or {}
local T = HM_Theme
local function c(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end

T.bg = c(0.020, 0.032, 0.050, 0.97)
T.panel = c(0.040, 0.062, 0.090, 0.94)
T.panelSoft = c(0.070, 0.105, 0.150, 0.72)
T.header = c(0.030, 0.052, 0.080, 0.98)
T.border = c(0.22, 0.50, 0.85, 1)
T.borderDim = c(0.11, 0.24, 0.42, 1)
T.accent = c(0.32, 0.70, 1.00, 1)
T.accentDark = c(0.05, 0.16, 0.32, 1)
T.text = c(0.90, 0.93, 0.97, 1)
T.textDim = c(0.60, 0.67, 0.74, 1)
T.button = { border = c(0.30, 0.60, 0.95, 1), bg = c(0.03, 0.07, 0.12, 0.85), over = c(0.08, 0.22, 0.40, 0.95) }

-- {r,g,b} triples for code that uses arrays
function T.rgb(col) return { col.r, col.g, col.b } end

return T

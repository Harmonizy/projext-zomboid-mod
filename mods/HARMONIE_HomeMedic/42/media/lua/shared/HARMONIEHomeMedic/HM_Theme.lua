--[[
    HARMONIE - Home Medic : one blue theme for every window of the mod.
    The window colour tables (EHR_HealthPanelUI.Colors, the journal, the
    Medical Monitor, surgery, debug menu, ...) use these values; red stays
    for danger and blood only.
]]--

HM_Theme = HM_Theme or {}
local T = HM_Theme
local function c(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end

T.bg = c(0.012, 0.05, 0.068, 0.97)
T.panel = c(0.025, 0.085, 0.115, 0.94)
T.panelSoft = c(0.05, 0.14, 0.18, 0.72)
T.header = c(0.02, 0.075, 0.1, 0.98)
T.border = c(0.22, 0.72, 0.95, 1)
T.borderDim = c(0.1, 0.34, 0.46, 1)
T.accent = c(0.3, 0.84, 1.0, 1)
T.accentDark = c(0.03, 0.24, 0.34, 1)
T.text = c(0.90, 0.93, 0.97, 1)
T.textDim = c(0.60, 0.67, 0.74, 1)
T.button = { border = c(0.24, 0.74, 0.96, 1), bg = c(0.02, 0.09, 0.12, 0.85), over = c(0.06, 0.28, 0.38, 0.95) }

-- {r,g,b} triples for code that uses arrays
function T.rgb(col) return { col.r, col.g, col.b } end

return T

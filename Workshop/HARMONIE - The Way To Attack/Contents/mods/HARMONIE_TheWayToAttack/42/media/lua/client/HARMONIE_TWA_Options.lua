--============================================================================
-- HARMONIE_TheWayToAttack -- per-player options (Options > Mods)
--
-- Round 13/14: this mod's sound volume and a mute switch, per player.
-- The volume picks which pre-made loudness file plays (TWASound.play; the
-- game's own per-sound user volume did not change our UI sounds -- round
-- 14 bug report "เสียงตอนนี้เหมือนมีแค่เปิดกับปิด"). The craft window's
-- megaphone button flips the same mute switch.
--============================================================================

require "HARMONIE_TWA_Sound"

TWAOptions = TWAOptions or {}
local O = TWAOptions

function O.applyVolume(v)
    TWASound.volume = tonumber(v) or 1
end

function O.setMuted(on)
    TWALog("Options", "sound muted: %s", tostring(on and true or false))
    TWASound.muted = on and true or false
    if O.mute and O.mute.setValue then O.mute:setValue(TWASound.muted) end
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then PZAPI.ModOptions:save() end
end

function O.toggleMute()
    O.setMuted(not TWASound.muted)
end

-- R71: read / change one option from code (the settings window): the value
-- is set, the option's own change handler runs, and it is saved
function O.get(id, default)
    local o = O[id]
    if o and o.getValue then
        local ok, v = pcall(o.getValue, o)
        if ok and v ~= nil then return v end
    end
    return default
end

function O.set(id, v)
    local o = O[id]
    if not o then TWALog("Options", "set %s: no such option", tostring(id)); return end
    TWALog("Options", "set %s = %s", tostring(id), tostring(v))
    if o.setValue then TWALogErr("Options", "setValue " .. tostring(id), pcall(o.setValue, o, v)) end
    -- a combo box keeps its choice in .selected (1-based), like getValue()
    if type(v) == "number" and type(o.selected) == "number" then o.selected = v end
    if o.onChangeApply then TWALogErr("Options", "onChangeApply " .. tostring(id), pcall(o.onChangeApply, o, v)) end
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then pcall(PZAPI.ModOptions.save, PZAPI.ModOptions) end
end

if PZAPI and PZAPI.ModOptions and not O.options then
    O.options = PZAPI.ModOptions:create("HARMONIE_TheWayToAttack", getText("UI_options_HARMONIE_TWA_title"))
    O.volume = O.options:addSlider("soundVolume", getText("UI_options_HARMONIE_TWA_volume"), 0, 2, 0.25, 1,
        getText("UI_options_HARMONIE_TWA_volume_tooltip"))
    O.volume.onChange = function(_, value) O.applyVolume(value) end
    O.volume.onChangeApply = function(_, value) TWALog("Options", "volume applied: %s", tostring(value)); O.applyVolume(value) end
    O.mute = O.options:addTickBox("soundMuted", getText("UI_options_HARMONIE_TWA_mute"), false,
        getText("UI_options_HARMONIE_TWA_mute_tooltip"))
    O.mute.onChange = function(_, value) TWASound.muted = value and true or false end
    O.mute.onChangeApply = function(_, value) TWALog("Options", "mute applied: %s", tostring(value)); TWASound.muted = value and true or false end
    -- 2026-10-03: zombie health bars / HP numbers / damage numbers and how
    -- they look (HARMONIE_TWA_ZombieHP reads these itself)
    local function T(k) return getText("UI_options_HARMONIE_TWA_" .. k) end
    -- R71: every option is also listed in O.DEFS (in order) for the
    -- settings window (HARMONIE_TWA_Settings)
    O.DEFS = {}
    local function def(d) O.DEFS[#O.DEFS + 1] = d end
    local function tick(id, default)
        O[id] = O.options:addTickBox(id, T(id), default, T(id .. "_tooltip"))
        def({ id = id, kind = "tick" })
    end
    local function slider(id, lo, hi, step, default, keep)
        O[id] = O.options:addSlider(id, T(id), lo, hi, step, default, T(id .. "_tooltip"))
        if not keep then def({ id = id, kind = "slider", min = lo, max = hi, step = step }) end
    end
    -- a list of named choices: a combo box when this game's ModOptions has
    -- one, else a numbered slider (getValue() is the 1-based index either way)
    local function list(id, prefix, keys, default)
        local o = O.options
        if o.addComboBox then
            local ok, box = pcall(o.addComboBox, o, id, T(id), T(id .. "_tooltip"))
            if ok and box and box.addItem then
                for i, k in ipairs(keys) do box:addItem(T(prefix .. k), i == default) end
                O[id] = box
                def({ id = id, kind = "choice", prefix = prefix, keys = keys })
                return
            end
        end
        slider(id, 1, #keys, 1, default, true)
        def({ id = id, kind = "choice", prefix = prefix, keys = keys })
    end
    local Z = { COLORS = { "Yellow", "White", "Orange", "Red", "Green", "Cyan", "Pink", "Purple" },
        BARS = { "Health", "Red", "Green", "Blue", "Purple" }, FONTS = { "Small", "Medium", "Large" } }
    -- R67: text size of this mod's windows (HARMONIE_TWA_Font)
    list("uiFontSize", "size_", Z.FONTS, 1)
    -- R68: size of the craft window (Auto follows the screen height)
    list("uiWindowSize", "wsize_", { "Auto", "Normal", "Large", "XLarge" }, 1)
    -- R70: open / close the craft window together with the vanilla one
    tick("followVanillaCraft", true)
    tick("zhpBar", true)
    tick("zhpText", true)
    tick("zhpDamage", true)
    list("zhpBarColor", "bar_", Z.BARS, 1)
    slider("zhpBarWidth", 20, 100, 2, 44)
    slider("zhpBarThick", 2, 14, 1, 6)
    slider("zhpHeight", 0, 20, 1, 0)
    list("zhpNumColor", "color_", Z.COLORS, 1)
    list("zhpCritColor", "color_", Z.COLORS, 4)
    list("zhpNumSize", "size_", Z.FONTS, 2)
    slider("zhpNumHeight", 0, 20, 1, 0)
    tick("zhpLog", false)
    if PZAPI.ModOptions.load then PZAPI.ModOptions:load() end
    local function readSaved()
        if O.volume.getValue then O.applyVolume(O.volume:getValue()) end
        if O.mute.getValue then TWASound.muted = O.mute:getValue() == true end
    end
    readSaved()
    if Events and Events.OnGameStart then Events.OnGameStart.Add(readSaved) end
end

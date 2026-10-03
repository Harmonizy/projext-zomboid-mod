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
    TWASound.muted = on and true or false
    if O.mute and O.mute.setValue then O.mute:setValue(TWASound.muted) end
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then PZAPI.ModOptions:save() end
end

function O.toggleMute()
    O.setMuted(not TWASound.muted)
end

if PZAPI and PZAPI.ModOptions and not O.options then
    O.options = PZAPI.ModOptions:create("HARMONIE_TheWayToAttack", getText("UI_options_HARMONIE_TWA_title"))
    O.volume = O.options:addSlider("soundVolume", getText("UI_options_HARMONIE_TWA_volume"), 0, 2, 0.25, 1,
        getText("UI_options_HARMONIE_TWA_volume_tooltip"))
    O.volume.onChange = function(_, value) O.applyVolume(value) end
    O.volume.onChangeApply = function(_, value) O.applyVolume(value) end
    O.mute = O.options:addTickBox("soundMuted", getText("UI_options_HARMONIE_TWA_mute"), false,
        getText("UI_options_HARMONIE_TWA_mute_tooltip"))
    O.mute.onChange = function(_, value) TWASound.muted = value and true or false end
    O.mute.onChangeApply = function(_, value) TWASound.muted = value and true or false end
    -- 2026-10-03: zombie health bars / HP numbers / damage numbers and how
    -- they look (HARMONIE_TWA_ZombieHP reads these itself)
    local function T(k) return getText("UI_options_HARMONIE_TWA_" .. k) end
    local function tick(id, default) O[id] = O.options:addTickBox(id, T(id), default, T(id .. "_tooltip")) end
    local function slider(id, lo, hi, step, default) O[id] = O.options:addSlider(id, T(id), lo, hi, step, default, T(id .. "_tooltip")) end
    -- a list of named choices: a combo box when this game's ModOptions has
    -- one, else a numbered slider (getValue() is the 1-based index either way)
    local function list(id, prefix, keys, default)
        local o = O.options
        if o.addComboBox then
            local ok, box = pcall(o.addComboBox, o, id, T(id), T(id .. "_tooltip"))
            if ok and box and box.addItem then
                for i, k in ipairs(keys) do box:addItem(T(prefix .. k), i == default) end
                O[id] = box
                return
            end
        end
        slider(id, 1, #keys, 1, default)
    end
    local Z = { COLORS = { "Yellow", "White", "Orange", "Red", "Green", "Cyan", "Pink", "Purple" },
        BARS = { "Health", "Red", "Green", "Blue", "Purple" }, FONTS = { "Small", "Medium", "Large" } }
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

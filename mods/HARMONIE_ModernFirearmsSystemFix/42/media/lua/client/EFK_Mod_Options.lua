AWCWF_Options = AWCWF_Options or {}

local SOUND_CATEGORY_SHOT = "AW_Weapon_Shot"
local SOUND_CATEGORY_RELOAD = "AW_Weapon_Reload"

-- Live toggles for the visual / shell-ejection effects. They default to on and
-- are overridden from ModOptions.ini on startup (loadSavedEffectToggles below),
-- then updated when the player applies settings.
AWCWF_Options._muzzleSmokeEnabled = true
AWCWF_Options._shellEjectionEnabled = true

-- Shell ejection is server-authoritative; in single-player the client and
-- server share one Lua state, so writing MFSEject._enabled here is enough.
local MFSEject = nil
pcall(function() MFSEject = require("MFSEject/Init") end)

function AWCWF_Options.isNewGunshotEnabled()
    local options = PZAPI.ModOptions:getOptions("AWCWF_42_Patch")
    if not options then
        return true
    end
    local opt = options:getOption("enable_new_gunshot")
    if not opt then
        return true
    end
    return opt:getValue()
end

function AWCWF_Options.isMuzzleSmokeEnabled()
    if PZAPI and PZAPI.ModOptions then
        local opts = PZAPI.ModOptions:getOptions("AWCWF_42_Patch")
        if opts then
            local opt = opts:getOption("muzzle_smoke")
            if opt then return opt:getValue() end
        end
    end
    return AWCWF_Options._muzzleSmokeEnabled
end

function AWCWF_Options.isShellEjectionEnabled()
    if PZAPI and PZAPI.ModOptions then
        local opts = PZAPI.ModOptions:getOptions("AWCWF_42_Patch")
        if opts then
            local opt = opts:getOption("shell_ejection")
            if opt then return opt:getValue() end
        end
    end
    return AWCWF_Options._shellEjectionEnabled
end

local function applyShellEjection(value)
    AWCWF_Options._shellEjectionEnabled = (value ~= false)
    if MFSEject then
        MFSEject._enabled = AWCWF_Options._shellEjectionEnabled
    end
end

-- Read our effect toggles from ModOptions.ini before PZAPI loads, so the
-- server-side ejection gate is correct from the first frame in single-player.
local function loadSavedEffectToggles()
    if not getFileReader then return end
    local file = getFileReader("ModOptions.ini", true)
    if not file then return end
    while true do
        local line = file:readLine()
        if not line then break end
        local t = luautils and luautils.split(line, "|")
        if t and t[2] == "AWCWF_42_Patch" and t[1] == "tickbox" then
            local enabled = (t[4] == "true")
            if t[3] == "muzzle_smoke" then
                AWCWF_Options._muzzleSmokeEnabled = enabled
            elseif t[3] == "shell_ejection" then
                applyShellEjection(enabled)
            end
        end
    end
    file:close()
end

loadSavedEffectToggles()

local function getCategorySoundVolume(category)
    local sounds = GameSounds.getSoundsInCategory(category)
    local total = 0
    local count = 0

    if sounds then
        for i = 1, sounds:size() do
            local sound = sounds:get(i - 1)
            if sound then
                total = total + sound:getUserVolume()
                count = count + 1
            end
        end
    end

    if count == 0 then
        return 1
    end

    return total / count
end

local function applyCategorySoundVolume(category, volume)
    local changed = false
    local sounds = GameSounds.getSoundsInCategory(category)

    if sounds then
        for i = 1, sounds:size() do
            local sound = sounds:get(i - 1)
            if sound and sound:getUserVolume() ~= volume then
                sound:setUserVolume(volume)
                changed = true
            end
        end
    end

    if changed then
        GameSounds.saveINI()
    end
end

-- Casing impact sounds share the vanilla "Item" category with all other item
-- audio, so filter by name prefix instead of adjusting the whole category.
local SOUND_CATEGORY_CASING = "Item"
local CASING_DEFAULT_VOLUME = 0.5
local CASING_SOUND_PREFIXES = { "Bullet_", "Shells_", "40mm_" }

local function isCasingSound(name)
    if not name then
        return false
    end

    for _, prefix in ipairs(CASING_SOUND_PREFIXES) do
        if string.sub(name, 1, #prefix) == prefix then
            return true
        end
    end

    return false
end

local function getCasingSoundVolume()
    local sounds = GameSounds.getSoundsInCategory(SOUND_CATEGORY_CASING)
    local total = 0
    local count = 0

    if sounds then
        for i = 1, sounds:size() do
            local sound = sounds:get(i - 1)
            if sound and isCasingSound(sound:getName()) then
                total = total + sound:getUserVolume()
                count = count + 1
            end
        end
    end

    if count == 0 then
        return CASING_DEFAULT_VOLUME
    end

    return total / count
end

local function applyCasingSoundVolume(volume)
    local changed = false
    local sounds = GameSounds.getSoundsInCategory(SOUND_CATEGORY_CASING)

    if sounds then
        for i = 1, sounds:size() do
            local sound = sounds:get(i - 1)
            if sound and isCasingSound(sound:getName()) and sound:getUserVolume() ~= volume then
                sound:setUserVolume(volume)
                changed = true
            end
        end
    end

    if changed then
        GameSounds.saveINI()
    end
end

function AWCWF_Options.Init()
    local options = PZAPI.ModOptions:create("AWCWF_42_Patch", getText("UI_options_AWCWF_title"))

    options:addTitle(getText("UI_options_AWCWF_section_general"))
    options:addDescription(getText("UI_options_AWCWF_desc_general"))

    options:addTitle(getText("UI_options_AWCWF_section_keybinds"))
    options:addDescription(getText("UI_options_AWCWF_desc_keybinds"))

    options:addKeyBind("keybind_grenade_launcher", getText("UI_options_AWCWF_keybind_grenade_launcher"), Keyboard.KEY_G,
        getText("UI_options_AWCWF_keybind_grenade_launcher_tooltip"))

    options:addKeyBind("keybind_inspect_window", getText("UI_options_AWCWF_keybind_inspect_window"), Keyboard.KEY_T,
        getText("UI_options_AWCWF_keybind_inspect_window_tooltip"))

    options:addKeyBind("keybind_tactical_stance", getText("UI_options_AWCWF_keybind_tactical_stance"), Keyboard.KEY_Z,
        getText("UI_options_AWCWF_keybind_tactical_stance_tooltip"))

    options:addKeyBind("keybind_light_mode", getText("UI_options_AWCWF_keybind_light_mode"), Keyboard.KEY_F,
        getText("UI_options_AWCWF_keybind_light_mode_tooltip"))

    options:addTitle(getText("UI_options_AWCWF_section_weapon_sounds"))
    options:addDescription(getText("UI_options_AWCWF_desc_weapon_sounds"))

    local enableNewGunshot = options:addTickBox("enable_new_gunshot", getText("UI_options_AWCWF_enable_new_gunshot"),
        true, getText("UI_options_AWCWF_enable_new_gunshot_tooltip"))

    local weaponShotVolume = options:addSlider("weapon_shot_volume", getText("UI_options_AWCWF_weapon_shot_volume"), 0,
        2, 0.01, getCategorySoundVolume(SOUND_CATEGORY_SHOT), getText("UI_options_AWCWF_weapon_shot_volume_tooltip"))

    weaponShotVolume.onChange = function(_, volume)
        applyCategorySoundVolume(SOUND_CATEGORY_SHOT, volume)
    end

    weaponShotVolume.onChangeApply = function(_, volume)
        applyCategorySoundVolume(SOUND_CATEGORY_SHOT, volume)
    end

    local weaponReloadVolume = options:addSlider("weapon_reload_volume",
        getText("UI_options_AWCWF_weapon_reload_volume"), 0, 2, 0.01, getCategorySoundVolume(SOUND_CATEGORY_RELOAD),
        getText("UI_options_AWCWF_weapon_reload_volume_tooltip"))

    weaponReloadVolume.onChange = function(_, volume)
        applyCategorySoundVolume(SOUND_CATEGORY_RELOAD, volume)
    end

    weaponReloadVolume.onChangeApply = function(_, volume)
        applyCategorySoundVolume(SOUND_CATEGORY_RELOAD, volume)
    end

    options:addTitle(getText("UI_options_AWCWF_section_effects"))
    options:addDescription(getText("UI_options_AWCWF_desc_effects"))

    local muzzleSmoke = options:addTickBox("muzzle_smoke", getText("UI_options_AWCWF_enable_muzzle_smoke"),
        AWCWF_Options._muzzleSmokeEnabled, getText("UI_options_AWCWF_enable_muzzle_smoke_tooltip"))
    muzzleSmoke.onChangeApply = function(_, value)
        AWCWF_Options._muzzleSmokeEnabled = (value == true)
    end

    local shellEjection = options:addTickBox("shell_ejection", getText("UI_options_AWCWF_enable_shell_ejection"),
        AWCWF_Options._shellEjectionEnabled, getText("UI_options_AWCWF_enable_shell_ejection_tooltip"))
    shellEjection.onChangeApply = function(_, value)
        applyShellEjection(value)
    end

    -- Seed the 50% default the first time the casing sounds are still at their
    -- untouched (100%) level; afterwards the persisted value is respected.
    if getCasingSoundVolume() >= 1.0 then
        applyCasingSoundVolume(CASING_DEFAULT_VOLUME)
    end

    local shellCasingVolume = options:addSlider("shell_casing_volume",
        getText("UI_options_AWCWF_shell_casing_volume"), 0, 2, 0.01, getCasingSoundVolume(),
        getText("UI_options_AWCWF_shell_casing_volume_tooltip"))

    shellCasingVolume.onChange = function(_, volume)
        applyCasingSoundVolume(volume)
    end

    shellCasingVolume.onChangeApply = function(_, volume)
        applyCasingSoundVolume(volume)
    end
end

AWCWF_Options.Init()
SystemDisabler.setEnableAdvancedSoundOptions(true)

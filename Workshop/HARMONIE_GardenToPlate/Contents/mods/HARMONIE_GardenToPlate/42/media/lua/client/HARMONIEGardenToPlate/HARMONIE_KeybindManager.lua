--[[
    HARMONIE - From Garden to Plate
    Registers our hotkeys as real, rebindable entries under
    Options -> Mods -> HARMONIE: Garden to Plate, using PZAPI.ModOptions
    (the B42 API for per-client mod settings/keybinds).

    Modeled directly on how Extensive Health Rework B42
    (EHR_KeybindManager.lua, Workshop 3726328119) does this -- including its
    fallback path for game contexts where PZAPI.ModOptions isn't available,
    so a fixed default key still works instead of the feature going dark.

    IDs:
      AssessNutritionKey -> no key by default (R67, 2026-10-03: "เอาปุ่มดู
                         vitamin ด้วยตัว N ออก แต่ให้ยังสามารถตั้งค่าได้
                         ด้วยผู้เล่นเองว่าเอาปุ่มอะไร"). Renamed from
                         "AssessNutrition": ModOptions saves every option,
                         so the old id would keep N for anyone who already
                         had a saved options file.
      OpenAdminPanel  -> default Keyboard.KEY_SLASH ("/"); still gated at
                         use-time by isAdmin()/getDebug() in
                         HARMONIE_Hotkeys.lua, so non-admins holding this
                         default simply have a key that does nothing
]]--

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.Keybinds = {}

local MOD_OPTIONS_ID = "HARMONIE_GardenToPlate"
local MOD_NAME = "HARMONIE: Garden to Plate"

HARMONIE_GTP.Keybinds.IDs = {
    ASSESS_NUTRITION = "AssessNutritionKey",
    OPEN_ADMIN_PANEL = "OpenAdminPanel",
    -- the vitamin guide window (HARMONIE_VitaminGuide.lua). 2026-10-08
    -- ("keybind ไว้ที่ตัว n"): N by default, renamed id so a saved "none"
    -- from the first build does not stick
    OPEN_GUIDE = "OpenVitaminGuideKey",
}

local DEFAULT_KEYS = {
    [HARMONIE_GTP.Keybinds.IDs.ASSESS_NUTRITION] = 0, -- none: the player picks one
    [HARMONIE_GTP.Keybinds.IDs.OPEN_ADMIN_PANEL] = 53, -- Keyboard.KEY_SLASH ("/")
    [HARMONIE_GTP.Keybinds.IDs.OPEN_GUIDE] = 49, -- Keyboard.KEY_N
}

HARMONIE_GTP.Keybinds.initialized = false
HARMONIE_GTP.Keybinds.useFallback = false
HARMONIE_GTP.Keybinds.modOptions = nil

local function optionText(key, fallback)
    local text = getText and getText(key) or nil
    if not text or text == key or text == "?" then
        return fallback
    end
    return text
end

local function ensureKeyBind(id, labelKey, fallbackLabel, defaultKey, tooltipKey, fallbackTooltip)
    if not HARMONIE_GTP.Keybinds.modOptions then return end
    if HARMONIE_GTP.Keybinds.modOptions:getOption(id) then return end

    HARMONIE_GTP.Keybinds.modOptions:addKeyBind(
        id,
        optionText(labelKey, fallbackLabel),
        defaultKey,
        optionText(tooltipKey, fallbackTooltip)
    )
end

function HARMONIE_GTP.Keybinds.Initialize()
    if HARMONIE_GTP.Keybinds.initialized then return end

    if not PZAPI or not PZAPI.ModOptions then
        HARMONIE_GTP.Keybinds.useFallback = true
        HARMONIE_GTP.Keybinds.initialized = true
        return
    end

    HARMONIE_GTP.Keybinds.modOptions = PZAPI.ModOptions:getOptions(MOD_OPTIONS_ID)
    if not HARMONIE_GTP.Keybinds.modOptions then
        HARMONIE_GTP.Keybinds.modOptions = PZAPI.ModOptions:create(MOD_OPTIONS_ID, MOD_NAME)
    end

    ensureKeyBind(
        HARMONIE_GTP.Keybinds.IDs.ASSESS_NUTRITION,
        "IGUI_HARMONIE_KeybindAssess", "Assess Nutritional Status",
        DEFAULT_KEYS[HARMONIE_GTP.Keybinds.IDs.ASSESS_NUTRITION],
        "IGUI_HARMONIE_KeybindAssess_tt", "Opens the Nutrition Assessment window for yourself, or the nearest other player if one is close by. No key by default: pick one here."
    )
    ensureKeyBind(
        HARMONIE_GTP.Keybinds.IDs.OPEN_ADMIN_PANEL,
        "IGUI_HARMONIE_KeybindAdmin", "Nutrition Admin Panel",
        DEFAULT_KEYS[HARMONIE_GTP.Keybinds.IDs.OPEN_ADMIN_PANEL],
        "IGUI_HARMONIE_KeybindAdmin_tt", "Admin/debug only: opens the live vitamin + sandbox tuning panel. Bound to / by default."
    )
    ensureKeyBind(
        HARMONIE_GTP.Keybinds.IDs.OPEN_GUIDE,
        "IGUI_GTPG_KeybindGuide", "Open Vitamin Guide",
        DEFAULT_KEYS[HARMONIE_GTP.Keybinds.IDs.OPEN_GUIDE],
        "IGUI_GTPG_KeybindGuide_tt", "Opens / closes the vitamin guide window. N by default."
    )
    -- the guide opens / closes with the Nutritional Assessment window
    local mo = HARMONIE_GTP.Keybinds.modOptions
    if mo and mo.addTickBox and not mo:getOption("GuideWithAssessment") then
        mo:addTickBox("GuideWithAssessment", optionText("IGUI_GTPG_OptFollow", "Open the vitamin guide with the assessment"),
            true, optionText("IGUI_GTPG_OptFollow_tt", "The vitamin guide window opens beside the Nutritional Assessment window and closes with it."))
    end

    HARMONIE_GTP.Keybinds.initialized = true
end

function HARMONIE_GTP.Keybinds.GetKey(id)
    HARMONIE_GTP.Keybinds.Initialize()

    if HARMONIE_GTP.Keybinds.useFallback then
        return DEFAULT_KEYS[id] or 0
    end

    if HARMONIE_GTP.Keybinds.modOptions then
        local option = HARMONIE_GTP.Keybinds.modOptions:getOption(id)
        if option and option.key ~= nil then
            return tonumber(option.key) or 0
        end
    end

    return DEFAULT_KEYS[id] or 0
end

Events.OnGameStart.Add(HARMONIE_GTP.Keybinds.Initialize)

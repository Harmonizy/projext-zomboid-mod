-- GunpartTooltip - Client Mod Options
-- Registers the per-client runtime options for compact gunpart tooltip
-- Values persist across sessions in Zomboid/Lua/ModOptions.ini.

pcall(require, "PZAPI/ModOptions")

-- ─── Client options namespace ────────────────────────────────────────────────

GunpartTooltipOptions = GunpartTooltipOptions or {}
local GTO = GunpartTooltipOptions
GTO.MOD_OPTIONS_ID = "EFKDE_GunpartTooltip"

-- Live values — updated immediately when the player changes settings
GTO._enableCompactTooltip = (GTO._enableCompactTooltip ~= nil) and GTO._enableCompactTooltip or true
GTO._showMountList = (GTO._showMountList ~= nil) and GTO._showMountList or false
GTO._initialized = GTO._initialized or false

-- ─── Accessors ───────────────────────────────────────────────────────────────

--- Returns whether compact tooltip is enabled.
--- Reads from PZAPI at call time (after Options screen apply) if registered,
--- otherwise falls back to the value loaded from ModOptions.ini at startup.
function GTO.isCompactTooltipEnabled()
    if PZAPI and PZAPI.ModOptions then
        local opts = PZAPI.ModOptions:getOptions(GTO.MOD_OPTIONS_ID)
        if opts then
            local opt = opts:getOption("EnableCompactTooltip")
            if opt then return opt:getValue() end
        end
    end
    return GTO._enableCompactTooltip
end

--- Returns whether mount list should be shown.
function GTO.shouldShowMountList()
    if PZAPI and PZAPI.ModOptions then
        local opts = PZAPI.ModOptions:getOptions(GTO.MOD_OPTIONS_ID)
        if opts then
            local opt = opts:getOption("ShowMountList")
            if opt then return opt:getValue() end
        end
    end
    return GTO._showMountList
end

-- ─── Save file bootstrap ─────────────────────────────────────────────────────
-- Read our values from ModOptions.ini before MainOptions calls
-- PZAPI.ModOptions:load(), so the live values are correct from the first frame

local function loadSaved()
    if not getFileReader then return end
    local file = getFileReader("ModOptions.ini", true)
    if not file then return end
    while true do
        local line = file:readLine()
        if not line then break end
        -- Format: type|modID|optionID|value
        local t = luautils and luautils.split(line, "|")
        if t and t[2] == GTO.MOD_OPTIONS_ID then
            if t[1] == "tickbox" and t[3] == "EnableCompactTooltip" then
                if t[4] == "true"  then GTO._enableCompactTooltip = true  end
                if t[4] == "false" then GTO._enableCompactTooltip = false end
            elseif t[1] == "tickbox" and t[3] == "ShowMountList" then
                if t[4] == "true"  then GTO._showMountList = true  end
                if t[4] == "false" then GTO._showMountList = false end
            end
        end
    end
    file:close()
end

loadSaved()
GTO._initialized = true

-- ─── PZAPI registration ──────────────────────────────────────────────────────

local _registered = false
local function registerModOptions()
    if _registered then return end
    if not (PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.create) then return end

    local options = PZAPI.ModOptions:getOptions(GTO.MOD_OPTIONS_ID)
    if not options then
        options = PZAPI.ModOptions:create(GTO.MOD_OPTIONS_ID, getText("UI_GunpartTooltip_ModOptions_Title"))
    end
    if not options then return end

    -- Avoid registering controls twice (hot-reload safety)
    if options:getOption("EnableCompactTooltip") then
        _registered = true
        return
    end

    options:addTitle(getText("UI_GunpartTooltip_ModOptions_Display"))

    -- ── Enable compact tooltip toggle ──────────────────────────────────────
    local tick1 = options:addTickBox(
        "EnableCompactTooltip",
        getText("UI_GunpartTooltip_EnableCompact"),
        GTO._enableCompactTooltip,
        getText("UI_GunpartTooltip_EnableCompact_tooltip")
    )
    tick1.onChangeApply = function(self, value)
        GTO._enableCompactTooltip = (value == true)
    end

    -- ── Show mount list toggle ──────────────────────────────────────
    local tick2 = options:addTickBox(
        "ShowMountList",
        getText("UI_GunpartTooltip_ShowMountList"),
        GTO._showMountList,
        getText("UI_GunpartTooltip_ShowMountList_tooltip")
    )
    tick2.onChangeApply = function(self, value)
        GTO._showMountList = (value == true)
    end

    _registered = true
end

registerModOptions()

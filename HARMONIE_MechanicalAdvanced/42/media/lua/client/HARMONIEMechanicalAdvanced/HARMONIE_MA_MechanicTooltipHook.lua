--[[
    The vehicle mechanic window's install/uninstall tooltip
    (ISVehicleMechanics:doMenuTooltip) only ever lists REQUIREMENTS --
    tools, skills, recipes needed -- built from part:getTable(lua). It
    never includes the item's own Tooltip script field describing what
    the part actually DOES (confirmed by reading the whole function:
    every branch only appends tool/skill/recipe lines). So a player
    hovering "Install" for one of our parts never saw our functional
    description at all, even though the item itself has one.

    Wraps the function and prepends our own description (reusing the
    exact same Tooltip_HARMONIE_MA_* text already on the item) onto
    option.toolTip.description -- option is a table reference, so
    mutating it after calling through works regardless of what the
    original function returns.
]]--

require "Vehicles/ISUI/ISVehicleMechanics"

local PART_DESCRIPTION_KEY = {
    HARMONIE_MA_Bullbar = "Tooltip_HARMONIE_MA_Bullbar",
    HARMONIE_MA_WindowArmorWindshield = "Tooltip_HARMONIE_MA_WindowArmorPlate",
    HARMONIE_MA_WindowArmorDoorLeft = "Tooltip_HARMONIE_MA_WindowArmorPlate",
    HARMONIE_MA_WindowArmorDoorRight = "Tooltip_HARMONIE_MA_WindowArmorPlate",
    HARMONIE_MA_CargoRack = "Tooltip_HARMONIE_MA_CargoRack",
}

-- HARMONIE_MA_PerfExhaust now holds one of 3 alternative items
-- (itemType = A;B;C, specificItem = false on the vehicle template), so
-- its tooltip can't be looked up by part id alone anymore -- it needs
-- the specific item's full type instead.
local ENGINE_TUNE_DESCRIPTION_KEY = {
    ["HARMONIEMechanicalAdvanced.PerformanceExhaustKit"] = "Tooltip_HARMONIE_MA_PerformanceExhaustKit",
    ["HARMONIEMechanicalAdvanced.StealthExhaustKit"] = "Tooltip_HARMONIE_MA_StealthExhaustKit",
    ["HARMONIEMechanicalAdvanced.FuelEfficientTuneKit"] = "Tooltip_HARMONIE_MA_FuelEfficientTuneKit",
}

local original_doMenuTooltip = ISVehicleMechanics.doMenuTooltip
function ISVehicleMechanics:doMenuTooltip(part, option, lua, name)
    local result = original_doMenuTooltip(self, part, option, lua, name)

    if not (part and option and option.toolTip) then return result end

    local key
    if part:getId() == "HARMONIE_MA_PerfExhaust" then
        -- "name" is the specific alternative item's full type, but only
        -- for the install submenu (ISVehicleMechanics.lua:257/267) --
        -- for the uninstall option it's nil, so fall back to whatever
        -- item is actually installed right now.
        local fullType = name
        if not fullType then
            local installed = part:getInventoryItem()
            fullType = installed and installed:getFullType()
        end
        key = fullType and ENGINE_TUNE_DESCRIPTION_KEY[fullType]
    else
        key = PART_DESCRIPTION_KEY[part:getId()]
    end

    if key then
        option.toolTip.description = getText(key) .. " <LINE> <LINE> " .. (option.toolTip.description or "")
    end

    return result
end

--[[
    HARMONIE - Home Medic : the medical window follows the character window (client)

    Request 2026-10-02: the EHR medical window opens and closes together
    with vanilla's character window (ISCharacterInfoWindow: info / skills /
    health ...), however that window is opened or closed -- its toolbar
    button, its key, its own X. Before, only the heart button did this
    (EHR_HealthPanelUI patches ISEquippedItem.onOptionMouseDown).

    Watched a few times a second for the first local player (the medical
    window is one instance, bound to that player): when the character
    window turns visible the medical window opens; when it is closed the
    medical window closes. Opening or closing the medical window on its own
    does not touch the character window. Options > Mods > Extensive Health
    Rework > "Open with the character window" turns it off.
]]--

require "ExtensiveHealth/EHR_HealthPanelUI"

HM_FollowCharacterWindow = HM_FollowCharacterWindow or {}
local F = HM_FollowCharacterWindow
F.EVERY_TICKS = 6

local function enabled()
    local O = HARMONIE_HomeMedic_Options
    local opt = O and O.followCharWindow
    if opt and opt.getValue then
        local ok, v = pcall(opt.getValue, opt)
        if ok and v == false then return false end
    end
    return true
end

local function visible(panel)
    if not panel then return false end
    local ok, v = pcall(function() return panel:isVisible() end)
    return ok and v == true
end

-- -> is the character window of player 0 open?
function F.characterWindowOpen()
    local info = getPlayerInfoPanel and getPlayerInfoPanel(0) or nil
    return visible(info)
end

local count = 0
function F.check()
    count = count + 1
    if count < F.EVERY_TICKS then return end
    count = 0
    if not enabled() or not (EHR and EHR.UI) then F.last = nil return end
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then F.last = nil return end
    local open = F.characterWindowOpen()
    if F.last == nil then F.last = open return end   -- (no jump on load)
    if open == F.last then return end
    F.last = open
    local ehrOpen = visible(EHR.UI.HealthPanelInstance)
    if open and not ehrOpen and EHR.UI.ShowHealthPanel then
        EHR.UI.ShowHealthPanel(player)
    elseif not open and ehrOpen and EHR.UI.HideHealthPanelOnly then
        EHR.UI.HideHealthPanelOnly()
    end
end

if Events and Events.OnTick and not F.registered then
    F.registered = true
    Events.OnTick.Add(F.check)
end

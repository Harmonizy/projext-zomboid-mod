--[[
    HARMONIE - Home Medic : The Only Cure inside the EHR health window (client)

    Request 2026-09-30 ("เอาให้ใช้ onlycure ได้ใน ui ehr ด้วยเลย").

    The Only Cure puts its surgery options (amputate with a saw, cauterize,
    prosthesis, clean the stump) into vanilla ISHealthPanel's body-part menu
    by replacing ISHealthPanel.doBodyPartContextMenu. The EHR window's OWN
    body menu already goes through that function (EHR hands it a stand-in
    panel carrying .character / .otherPlayer / :checkItems / :getDoctor,
    which are all TOC's handlers read), so those options show there.

    The EHR window for ANOTHER player (the remote, snapshot-driven panel)
    builds its menu itself and never calls vanilla -- so no TOC options, and
    no menu at all on an uninjured limb. This wraps
    EHR_HealthPanelUI.openRemoteBodyPartContextMenu and adds TOC's two
    handlers (CutLimbInteractionHandler, WoundCleaningInteractionHandler) to
    that menu with the same stand-in panel (character = patient,
    otherPlayer = the doctor). TOC's own actions and server commands then run
    exactly as they do from the vanilla window.

    Inactive unless The Only Cure's client code is loaded (it defines the
    global SetHealthPanelTOC). Installed at OnGameStart so both EHR's and
    TOC's files have loaded, whatever the load order.
]]--

HARMONIE_HomeMedic_TOCBridge = HARMONIE_HomeMedic_TOCBridge or {}
local T = HARMONIE_HomeMedic_TOCBridge

function T.available()
    return SetHealthPanelTOC ~= nil and ISHealthPanel ~= nil and ISHealthPanel.checkItems ~= nil
end

-- Add TOC's options for `bodyPart` to `context`, acting through `panel`
-- (anything with .character / .otherPlayer and ISHealthPanel's item helpers).
-- Returns true when at least one option was added.
function T.addOptions(panel, bodyPart, context)
    if not T.available() or not panel or not bodyPart or not context then return false end
    local before = context.numOptions or 0
    local Cut = require("TOC/UI/Interactions/CutLimbInteractionHandler")
    local Clean = require("TOC/UI/Interactions/WoundCleaningInteractionHandler")
    if Cut then
        local cut = Cut:new(panel, bodyPart)
        panel:checkItems({ cut })
        cut:addToMenu(context)
    end
    if Clean and panel.character then
        local clean = Clean:new(panel, bodyPart, panel.character:getUsername())
        panel:checkItems({ clean })
        clean:addToMenu(context)
    end
    return (context.numOptions or 0) > before
end

function T.install()
    if T.installed or not EHR_HealthPanelUI or not EHR_HealthPanelUI.openRemoteBodyPartContextMenu then return end
    if not T.available() then return end
    T.installed = true
    local original = EHR_HealthPanelUI.openRemoteBodyPartContextMenu
    function EHR_HealthPanelUI:openRemoteBodyPartContextMenu(bodyPart, x, y, bodyPartType)
        local shown = original(self, bodyPart, x, y, bodyPartType)
        if not self.isRemoteHealthPanel or not bodyPart or not self.getVanillaHealthAdapter then return shown end
        local playerNum = self.playerNum
            or (self.remoteDoctor and self.remoteDoctor.getPlayerNum and self.remoteDoctor:getPlayerNum()) or 0
        local context
        if shown then
            context = getPlayerContextMenu and getPlayerContextMenu(playerNum)
        else
            context = ISContextMenu.get(playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY())
            context.origin = self.bodyPartPanel or self
        end
        if not context then return shown end
        local added = T.addOptions(self:getVanillaHealthAdapter(), bodyPart, context)
        if added or shown then
            context:setVisible(true)
            context:bringToTop()
            return true
        end
        context:setVisible(false)
        return shown
    end
end

if Events and Events.OnGameStart then Events.OnGameStart.Add(T.install) end

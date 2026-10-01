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

    Also shows TOC's limb state in the medical window's body-part statuses
    (vanilla's window gets it from TOC's own ISHealthPanel override; the EHR
    window knew nothing about amputations): amputated / missing limb,
    healing %, cauterized or healed stump, wound dirtiness, prosthesis. Data
    comes from TOC's client-side DataController; for another player it is
    requested once, the way TOC's own medical check does.

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

local function text(key, fallback)
    local t = getText and getText(key)
    if not t or t == key or t == "?" then return fallback end
    return t
end

-- TOC's limb state for one body part of `patient`, as EHR status rows
-- ({key, label, color, visualValue, priority}); nil when there is none.
T.requested = T.requested or {}
function T.limbStatuses(patient, bodyPart, colors)
    if not patient or not bodyPart or not T.available() then return nil end
    local okS, StaticData = pcall(require, "TOC/StaticData")
    local okD, DataController = pcall(require, "TOC/Controllers/DataController")
    if not okS or not okD or not StaticData or not DataController then return nil end
    local okT, typeStr = pcall(function() return BodyPartType.ToString(bodyPart:getType()) end)
    local limb = okT and StaticData.LIMBS_IND_STR and StaticData.LIMBS_IND_STR[typeStr]
    if not limb then return nil end
    local username = patient.getUsername and patient:getUsername()
    if not username then return nil end
    local dc = DataController.GetInstance(username)
    if not dc then
        if not T.requested[username] then
            T.requested[username] = true
            pcall(function() require("TOC/Controllers/ClientDataController").Request(username, false) end)
        end
        return nil
    end
    if not dc:getIsCut(limb) then return nil end
    local c = colors or {}
    local rows = {}
    local function add(key, label, color, visual, priority)
        rows[#rows + 1] = { key = key, label = label, color = color or c.textDim, visualValue = visual, priority = priority }
    end
    if not dc:getIsVisible(limb) then
        add("toc_missing", text("UI_EHR_LimbMissing", "Missing (amputated above)"), c.textDim, 0, 130)
        return rows
    end
    add("toc_amputated", text("UI_EHR_Amputated", "Amputated"), c.red, 1.00, 130)
    if dc:getIsCicatrized(limb) then
        if dc:getIsCauterized(limb) then
            add("toc_cauterized", text("IGUI_HealthPanel_Cauterized", "Cauterized"), c.green, 0.20, 129)
        else
            add("toc_healed", text("IGUI_HealthPanel_Cicatrized", "Healed"), c.green, 0.20, 129)
        end
    else
        local maxTime = StaticData.LIMBS_CICATRIZATION_TIME_IND_NUM and StaticData.LIMBS_CICATRIZATION_TIME_IND_NUM[limb]
        local cic = tonumber(dc:getCicatrizationTime(limb)) or -1
        if maxTime and maxTime > 0 and cic >= 0 then
            local pct = math.max(0, math.min(100, math.floor((1 - cic / maxTime) * 100)))
            add("toc_healing", text("IGUI_HealthPanel_Cicatrization", "Cicatrization") .. " " .. pct .. "%", c.orange, 0.60, 128)
        end
        local dirt = tonumber(dc:getWoundDirtyness(limb)) or -1
        if dirt >= 0 then
            add("toc_dirt", text("IGUI_HealthPanel_WoundDirtyness", "Wound dirtiness") .. " " .. math.floor(dirt * 100) .. "%",
                dirt >= 0.5 and c.red or c.yellow, 0.60, 127)
        end
    end
    if dc:getIsProstEquipped(limb) then
        add("toc_prosthesis", text("IGUI_HealthPanel_ProstEquipped", "Prosthesis equipped"), c.blue or c.green, 0.20, 126)
    end
    return rows
end

function T.installStatuses()
    if T.statusesInstalled or not EHR_HealthPanelUI or not EHR_HealthPanelUI.getBodyPartStatuses then return end
    if not T.available() then return end
    T.statusesInstalled = true
    local original = EHR_HealthPanelUI.getBodyPartStatuses
    function EHR_HealthPanelUI:getBodyPartStatuses(bodyPart)
        local statuses = original(self, bodyPart)
        local ok, rows = pcall(T.limbStatuses, self.player, bodyPart, EHR_HealthPanelUI.Colors)
        if ok and rows and #rows > 0 then
            -- TOC rows first (highest priority), then EHR's own
            for i = #rows, 1, -1 do table.insert(statuses, 1, rows[i]) end
        end
        return statuses
    end
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

-- The body diagram of the medical window: an amputated limb disappears.
-- TOC paints the missing limb (its own 123x302 overlay of the vanilla body,
-- media/ui/<Sex>/<Limb>.png) on the vanilla health panel; here the same
-- overlay is painted in the window's background colour, so the limb is gone
-- (a fitted prosthesis is drawn on top). Offset -5,-13 = TOC's B42 alignment.
T.BODY_OFFSET_X, T.BODY_OFFSET_Y = -5, -13
function T.drawMissingLimbs(panel)
    if not T.available() then return end
    local player = (panel.parent and panel.parent.player) or panel.character or panel.player
    local username = player and player.getUsername and player:getUsername()
    if not username then return end
    local okS, StaticData = pcall(require, "TOC/StaticData")
    local okC, Cached = pcall(require, "TOC/Handlers/CachedDataHandler")
    local okD, DataController = pcall(require, "TOC/Controllers/DataController")
    if not (okS and okC and StaticData and Cached and Cached.GetHighestAmputatedLimbs) then return end
    local okH, highest = pcall(Cached.GetHighestAmputatedLimbs, username)
    if not okH or type(highest) ~= "table" then return end
    local sex = player.isFemale and player:isFemale() and "Female" or "Male"
    local textures = StaticData.HEALTH_PANEL_TEXTURES and StaticData.HEALTH_PANEL_TEXTURES[sex]
    local bg = EHR_HealthPanelUI and EHR_HealthPanelUI.Colors and EHR_HealthPanelUI.Colors.panel or { r = 0.04, g = 0.062, b = 0.09 }
    local dc = okD and DataController and DataController.GetInstance(username)
    for _, side in ipairs({ "L", "R" }) do
        local limb = highest[side]
        local tex = limb and textures and textures[limb]
        if tex then
            panel:drawTexture(tex, T.BODY_OFFSET_X, T.BODY_OFFSET_Y, 1, bg.r, bg.g, bg.b)
            local prost = dc and dc.getIsProstEquipped and dc:getIsProstEquipped(limb)
            local ptex = prost and StaticData.HEALTH_PANEL_TEXTURES.ProstArm and StaticData.HEALTH_PANEL_TEXTURES.ProstArm[side]
            if ptex then panel:drawTexture(ptex, T.BODY_OFFSET_X, T.BODY_OFFSET_Y, 1, 1, 1, 1) end
        end
    end
end

function T.installBody()
    if T.bodyInstalled or not EHR_HealthBodyPartPanel or not T.available() then return end
    T.bodyInstalled = true
    local original = EHR_HealthBodyPartPanel.render
    function EHR_HealthBodyPartPanel:render()
        if original then original(self) end
        pcall(T.drawMissingLimbs, self)
    end
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(T.install)
    Events.OnGameStart.Add(T.installStatuses)
    Events.OnGameStart.Add(T.installBody)
end

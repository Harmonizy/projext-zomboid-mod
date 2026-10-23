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
    if not T.available() then HMLogOnce("tocoff", "TOC", "The Only Cure not available -- no limb statuses"); return end
    T.statusesInstalled = true
    HMLog("TOC", "limb statuses added to the medical window")
    local original = EHR_HealthPanelUI.getBodyPartStatuses
    function EHR_HealthPanelUI:getBodyPartStatuses(bodyPart)
        local statuses = original(self, bodyPart)
        local ok, rows = pcall(T.limbStatuses, self.player, bodyPart, EHR_HealthPanelUI.Colors)
        if not ok then HMLogOnce("tocst:" .. tostring(rows), "TOC", "limb status FAILED: %s", tostring(rows)) end
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
    HMLog("TOC", "TOC options added to the remote body-part menu")
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

-- The body diagram of the medical window: an amputated limb turns black.
-- The body-part panel keeps one entry per part in panel.bps (bodyPartType +
-- the part's own shape texture); the parts of the missing limb are drawn
-- again in black on top, so exactly that shape goes dark. If a part's
-- texture cannot be found, TOC's own limb overlay (media/ui/<Sex>/<Limb>.png,
-- offset -5,-13 = TOC's B42 alignment) is painted black instead.
-- A fitted prosthesis is drawn on top.
T.BODY_OFFSET_X, T.BODY_OFFSET_Y = -5, -13
local LIMB_PARTS = {
    Hand_L = { "Hand_L" }, ForeArm_L = { "Hand_L", "ForeArm_L" }, UpperArm_L = { "Hand_L", "ForeArm_L", "UpperArm_L" },
    Hand_R = { "Hand_R" }, ForeArm_R = { "Hand_R", "ForeArm_R" }, UpperArm_R = { "Hand_R", "ForeArm_R", "UpperArm_R" },
}

-- the Texture stored in a body-part entry (field name not relied upon)
local function partTexture(bp)
    for _, key in ipairs({ "texture", "tex", "partTexture", "mask", "overlay" }) do
        local v = bp[key]
        if v and type(v) ~= "table" and type(v) ~= "string" then return v, bp.texX or bp.x or 0, bp.texY or bp.y or 0 end
    end
    for _, v in pairs(bp) do
        if type(v) == "userdata" then
            local ok, w = pcall(function() return v:getWidth() end)
            local okN, n = pcall(function() return v:getName() end)
            if ok and tonumber(w) and okN and n then return v, bp.texX or 0, bp.texY or 0 end
        end
    end
    return nil
end

local function logFields(panel)
    if T.loggedFields or not panel.bps or not panel.bps[1] then return end
    T.loggedFields = true
    local keys = {}
    for k, v in pairs(panel.bps[1]) do keys[#keys + 1] = tostring(k) .. ":" .. type(v) end
    HMLog("TOC", "body-part entry fields: %s", table.concat(keys, ", "))
end

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
    logFields(panel)
    local sex = player.isFemale and player:isFemale() and "Female" or "Male"
    local textures = StaticData.HEALTH_PANEL_TEXTURES and StaticData.HEALTH_PANEL_TEXTURES[sex]
    local dc = okD and DataController and DataController.GetInstance(username)
    for _, side in ipairs({ "L", "R" }) do
        local limb = highest[side]
        if limb then
            local drawn = false
            local want = {}
            for _, n in ipairs(LIMB_PARTS[limb] or {}) do want[n] = true end
            for _, bp in ipairs(panel.bps or {}) do
                local okT, name = pcall(function() return BodyPartType.ToString(bp.bodyPartType) end)
                if okT and want[name] then
                    local tex, tx, ty = partTexture(bp)
                    if tex then
                        panel:drawTexture(tex, tx, ty, 1, 0.02, 0.02, 0.03)
                        drawn = true
                    end
                end
            end
            if not drawn and textures and textures[limb] then
                panel:drawTexture(textures[limb], T.BODY_OFFSET_X, T.BODY_OFFSET_Y, 0.92, 0, 0, 0)
            end
            local prost = dc and dc.getIsProstEquipped and dc:getIsProstEquipped(limb)
            local ptex = prost and StaticData.HEALTH_PANEL_TEXTURES.ProstArm and StaticData.HEALTH_PANEL_TEXTURES.ProstArm[side]
            if ptex then panel:drawTexture(ptex, T.BODY_OFFSET_X, T.BODY_OFFSET_Y, 1, 1, 1, 1) end
        end
    end
end

-- ------------------------------------------------------------- prosthesis from the body menu
-- Request 2026-10-02: fit / remove a prosthesis by right-clicking the stump
-- in the body diagram (the medical window or the vanilla health window)
-- instead of through the item. The action is TOC's own: a prosthesis is worn
-- like clothing (ISWearClothing / ISUnequipAction, which TOC hooks).
local function tocModules()
    local okS, StaticData = pcall(require, "TOC/StaticData")
    local okD, DataController = pcall(require, "TOC/Controllers/DataController")
    local okC, Cached = pcall(require, "TOC/Handlers/CachedDataHandler")
    local okP, Prost = pcall(require, "TOC/Handlers/ProsthesisHandler")
    if okS and okD and okC and okP and StaticData and DataController and Cached and Prost then
        return StaticData, DataController, Cached, Prost
    end
end

local function sideOf(fullType)
    return string.find(fullType or "", "_L") and "L" or "R"
end

function T.prosthesisOptions(context, player, bodyPart)
    if not context or not player or not bodyPart or not T.available() then return false end
    local StaticData, DataController, Cached, Prost = tocModules()
    if not StaticData then return false end
    local okT, typeStr = pcall(function() return BodyPartType.ToString(bodyPart:getType()) end)
    local limb = okT and StaticData.LIMBS_IND_STR and StaticData.LIMBS_IND_STR[typeStr]
    if not limb then return false end
    local username = player:getUsername()
    local dc = DataController.GetInstance(username)
    if not dc or not dc:getIsCut(limb) then return false end
    local side = limb:sub(-1)
    local okH, highest = pcall(Cached.GetHighestAmputatedLimbs, username)
    if not okH or type(highest) ~= "table" or highest[side] ~= limb then return false end
    if string.find(limb, "UpperArm") then
        local o = context:addOption(text("UI_HomeMedic_Prost_NoUpper", "Prosthesis: not possible above the elbow"), nil, nil)
        o.notAvailable = true
        return true
    end
    if dc:getIsProstEquipped(limb) then
        local worn = player:getWornItems()
        for i = 0, (worn and worn:size() or 0) - 1 do
            local it = worn:get(i) and worn:get(i):getItem()
            if it and Prost.CheckIfProst(it) and sideOf(it:getFullType()) == side then
                context:addOption(text("UI_HomeMedic_Prost_Remove", "Remove prosthesis") .. ": " .. it:getDisplayName(), player,
                    function(p) ISTimedActionQueue.add(ISUnequipAction:new(p, it, 50)) end)
                return true
            end
        end
        return false
    end
    local found = {}
    local items = player:getInventory():getAllEvalRecurse(function(it) return Prost.CheckIfProst(it) end)
    for i = 0, (items and items:size() or 0) - 1 do
        local it = items:get(i)
        if sideOf(it:getFullType()) == side then found[#found + 1] = it end
    end
    if #found == 0 then
        local o = context:addOption(text("UI_HomeMedic_Prost_None", "Fit prosthesis (none for this side in your bags)"), nil, nil)
        o.notAvailable = true
        return true
    end
    for _, it in ipairs(found) do
        context:addOption(text("UI_HomeMedic_Prost_Fit", "Fit prosthesis") .. ": " .. it:getDisplayName(), player, function(p)
            if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then
                ISInventoryPaneContextMenu.transferIfNeeded(p, it)
            end
            ISTimedActionQueue.add(ISWearClothing:new(p, it, 50))
        end)
    end
    return true
end

function T.installProsthesis()
    if T.prostInstalled or not T.available() or not ISHealthPanel or not ISHealthPanel.doBodyPartContextMenu then return end
    T.prostInstalled = true
    local orig = ISHealthPanel.doBodyPartContextMenu
    ISHealthPanel.doBodyPartContextMenu = function(self, bodyPart, x, y, ...)
        local r = orig(self, bodyPart, x, y, ...)
        -- only on your own body (you cannot dress someone else)
        if self.otherPlayer == nil and self.character and self.character.getPlayerNum then
            local context = getPlayerContextMenu and getPlayerContextMenu(self.character:getPlayerNum())
            local ok, added = pcall(T.prosthesisOptions, context, self.character, bodyPart)
            if ok and added then context:setVisible(true); context:bringToTop() end
        end
        return r
    end
    -- the item's own "Wear" goes: prostheses are fitted from the body menu
    if Events and Events.OnFillInventoryObjectContextMenu then
        Events.OnFillInventoryObjectContextMenu.Add((HARMONIE_Ours or function(f) return f end)(function(playerNum, context, items)
            local _, _, _, Prost = tocModules()
            if not Prost or not context then return end
            local all, any = true, false
            for _, entry in ipairs(items or {}) do
                local it = entry
                if type(entry) == "table" and entry.items then it = entry.items[1] end
                if it and type(it) ~= "table" then
                    any = true
                    if not Prost.CheckIfProst(it) then all = false end
                end
            end
            if any and all then
                pcall(function() context:removeOptionByName(getText("ContextMenu_Wear")) end)
                local o = context:addOption(text("UI_HomeMedic_Prost_Hint", "Fit it from the body menu (right-click the stump)"), nil, nil)
                o.notAvailable = true
            end
        end, "HM"))
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
    Events.OnGameStart.Add(T.installProsthesis)
end

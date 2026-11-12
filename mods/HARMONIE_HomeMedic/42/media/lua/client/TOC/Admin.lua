local CommandsData = require("TOC/CommandsData")
local ClientRelayCommands = require("TOC/ClientRelayCommands")
local StaticData = require("TOC/StaticData")
-------------------

---@param playerNum number
---@param context ISContextMenu
---@param worldobjects table
local function AddAdminTocOptions(playerNum, context, worldobjects)
    if not(isClient() and isAdmin() or isDebugEnabled()) then return end

    local players = {}
    for _, v in ipairs(worldobjects) do
        for x = v:getSquare():getX() - 1, v:getSquare():getX() + 1 do
            for y = v:getSquare():getY() - 1, v:getSquare():getY() + 1 do
                local sq = getCell():getGridSquare(x, y, v:getSquare():getZ());
                if sq then
                    for z = 0, sq:getMovingObjects():size() - 1 do
                        local o = sq:getMovingObjects():get(z)
                        if instanceof(o, "IsoPlayer") then
                            ---@cast o IsoPlayer

                            local oId = o:getOnlineID()
                            players[oId] = o
                        end
                    end
                end
            end
        end
    end


    -- ugly This whole section should be done better
    for _, pl in pairs(players) do
        ---@cast pl IsoPlayer

        local clickedPlayerNum = pl:getOnlineID()

        local option = context:addOption(getText("ContextMenu_Admin_TOC") .. " - " .. pl:getUsername(), nil, nil)
        local subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(option, subMenu)

        subMenu:addOption(getText("ContextMenu_Admin_ResetTOC"), nil, function()
            if isClient() then
                sendClientCommand(CommandsData.modules.TOC_RELAY, CommandsData.server.Relay.RelayExecuteInitialization,
                    { patientNum = clickedPlayerNum })
            else
                ClientRelayCommands.ReceiveExecuteInitialization()
            end
        end)

        -- Force amputation
        local forceAmpOption = subMenu:addOption(getText("ContextMenu_Admin_ForceAmputation"), nil, nil)
        local forceAmpSubMenu = ISContextMenu:getNew(subMenu)
        context:addSubMenu(forceAmpOption, forceAmpSubMenu)

        for i = 1, #StaticData.LIMBS_STR do
            local limbName = StaticData.LIMBS_STR[i]
            local limbTranslatedName = getText("ContextMenu_Limb_" .. limbName)

            forceAmpSubMenu:addOption(limbTranslatedName, nil, function()
                --if isClient() then
                sendClientCommand(CommandsData.modules.TOC_RELAY, CommandsData.server.Relay.RelayForcedAmputation,
                { patientNum = clickedPlayerNum, limbName = limbName })


            end)
        end
    end

    
end
-- HARMONIE (2026-10-11, owner: "เอา ดีบัก TOC ไปรวมใน ดีบัก HARMONIE"): with
-- the HARMONIE hub these actions sit inside the one "HARMONIE debug" menu.
-- 1.0.0 (2026-11-12, owner: "กรณีของ onlycure ให้ไปรวมอยู่ในหน้าต่างเดียว ไม่ใช่
-- ออกมาเยอะแบบนี้"): ONE option per player opens ONE window
-- (HARMONIE_SettingsUI rows): each limb with its state and an Amputate
-- button, and Reset at the top. Same server relay commands as before.
local DataController = require("TOC/Controllers/DataController")
local function tocLog(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print("[HARMONIE_HM][TOCAdmin] " .. (ok and s or tostring(fmt)))
end

local function resetTOC(pl)
    local num = pl:getOnlineID()
    if isClient() then
        sendClientCommand(CommandsData.modules.TOC_RELAY, CommandsData.server.Relay.RelayExecuteInitialization, { patientNum = num })
    else
        ClientRelayCommands.ReceiveExecuteInitialization()
    end
    tocLog("reset TOC for %s (online id %s)", tostring(pl:getUsername()), tostring(num))
end

local function amputate(pl, limbName)
    sendClientCommand(CommandsData.modules.TOC_RELAY, CommandsData.server.Relay.RelayForcedAmputation,
        { patientNum = pl:getOnlineID(), limbName = limbName })
    tocLog("force amputation %s on %s", tostring(limbName), tostring(pl:getUsername()))
end

local function isCut(pl, limbName)
    local ok, cut = pcall(function() return DataController.GetInstance(pl:getUsername()):getIsCut(limbName) end)
    return ok and cut == true
end

function HM_OpenTOCAdmin(pl)
    if not pl or not HARMONIE_SettingsUI then tocLog("no player / no HARMONIE settings window -- not opened"); return end
    local name = tostring(pl:getUsername() or "?")
    HARMONIE_SettingsUI.open(getText("ContextMenu_Admin_TOC") .. " - " .. name, function()
        local rows = {
            { kind = "note", label = getText("IGUI_HM_TOCAdmin_Note") },
            { kind = "button", id = "toc_reset", label = getText("ContextMenu_Admin_ResetTOC"), text = getText("IGUI_HM_TOCAdmin_Reset"),
              run = function() resetTOC(pl) end },
            { kind = "section", label = getText("ContextMenu_Admin_ForceAmputation") },
        }
        for i = 1, #StaticData.LIMBS_STR do
            local limbName = StaticData.LIMBS_STR[i]
            rows[#rows + 1] = { kind = "button", id = "toc_" .. limbName,
                label = getText("ContextMenu_Limb_" .. limbName) .. (isCut(pl, limbName) and (" (" .. getText("IGUI_HM_TOCAdmin_Cut") .. ")") or ""),
                text = getText("IGUI_HM_TOCAdmin_Amputate"), run = function() amputate(pl, limbName) end }
        end
        return rows
    end, HMSettingsUI and HMSettingsUI.THEME or nil)
    tocLog("admin window opened for %s", name)
end

local function tocDebug(add, player, target)
    local pl = target or player
    if not pl then return end
    local who = target and "" or (" (" .. getText("IGUI_HUB_DebugSelf") .. ")")
    add(getText("ContextMenu_Admin_TOC") .. who, function() HM_OpenTOCAdmin(pl) end)
end
if HARMONIE_RegisterDebug then
    HARMONIE_RegisterDebug("TOC", tocDebug)
else
    Events.OnFillWorldObjectContextMenu.Add((HARMONIE_Ours or function(f) return f end)(AddAdminTocOptions, "debug"))
end


--* Override to cheats to fix stuff

local og_ISHealthPanel_onCheatCurrentPlayer = ISHealthPanel.onCheatCurrentPlayer

---Override to onCheatCurrentPlayer to fix behaviour with TOC
---@param bodyPart BodyPart
---@param action any
---@param player IsoPlayer
function ISHealthPanel.onCheatCurrentPlayer(bodyPart, action, player)
    og_ISHealthPanel_onCheatCurrentPlayer(bodyPart, action, player)
    if action == "healthFullBody" or action == 'healthFull' then
        if isClient() then

            sendClientCommand(CommandsData.modules.TOC_RELAY, CommandsData.server.Relay.RelayExecuteInitialization,
                { patientNum = player:getOnlineID() })
        else
            ClientRelayCommands.ReceiveExecuteInitialization()
        end
    end
end

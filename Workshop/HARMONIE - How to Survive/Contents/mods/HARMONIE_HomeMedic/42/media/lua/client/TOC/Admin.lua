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
-- the HARMONIE hub the same actions sit inside the one "HARMONIE debug"
-- menu -- under the clicked player's name, or for yourself in its general
-- part -- instead of a separate "TOC admin" entry per player.
local function tocDebug(add, player, target)
    local pl = target or player
    if not pl then return end
    local num = pl:getOnlineID()
    local who = target and "" or (" (" .. getText("IGUI_HUB_DebugSelf") .. ")")
    add(getText("ContextMenu_Admin_TOC") .. ": " .. getText("ContextMenu_Admin_ResetTOC") .. who, function()
        if isClient() then
            sendClientCommand(CommandsData.modules.TOC_RELAY, CommandsData.server.Relay.RelayExecuteInitialization, { patientNum = num })
        else
            ClientRelayCommands.ReceiveExecuteInitialization()
        end
    end)
    for i = 1, #StaticData.LIMBS_STR do
        local limbName = StaticData.LIMBS_STR[i]
        add(getText("ContextMenu_Admin_TOC") .. ": " .. getText("ContextMenu_Admin_ForceAmputation") .. " - " .. getText("ContextMenu_Limb_" .. limbName) .. who, function()
            sendClientCommand(CommandsData.modules.TOC_RELAY, CommandsData.server.Relay.RelayForcedAmputation, { patientNum = num, limbName = limbName })
        end)
    end
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

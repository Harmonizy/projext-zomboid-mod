local DataController = require("TOC/Controllers/DataController")
local CommandsData = require("TOC/CommandsData")
local StaticData = require("TOC/StaticData")

---Owns the client-side async data load cycle.
---In SP: initializes DC directly via ServerDataController (no relay command, no double-init).
---In MP client: creates a placeholder DC and requests data from server via relay command.
---@class ClientDataController
local ClientDataController = {}

---Request DC data for a username.
---SP path: calls ServerDataController.Initialize directly — synchronous, no relay.
---MP path: creates placeholder DC shell, sends relay command to server.
---@param username string
---@param isForced boolean?
---@param playerObj IsoPlayer?
function ClientDataController.Request(username, isForced, playerObj)
    TOC_DEBUG.print("ClientDataController.Request for " .. username)

    if not isClient() then
        -- SP: server scripts are in the same Lua state, initialize directly
        local ServerDataController = require("TOC/Controllers/ServerDataController")
        ServerDataController.Initialize(username, isForced, playerObj)
    else
        -- MP client: create placeholder shell, server will respond with data
        DataController:new(username, isForced)
        sendClientCommand(CommandsData.modules.TOC_RELAY,
            CommandsData.server.Relay.RelayRequestDataController,
            {username = username, isForced = isForced})
    end
end

---HM 1.2.8: keep the healing this client already did when a server copy lacks it.
---Only for the local player (its client runs cicatrization). Returns the limbs
---to send back to the server.
---@param username string
---@param handler DataController
---@param data tocModDataType
---@return string[]
function ClientDataController.KeepLocalHealing(username, handler, data)
    local resend = {}
    local pl = getPlayer and getPlayer()
    if not pl or pl:getUsername() ~= username then return resend end
    local old = handler.tocData
    if type(old) ~= "table" or type(old.limbs) ~= "table" or type(data.limbs) ~= "table" then return resend end
    if old == data then return resend end
    for limbName, o in pairs(old.limbs) do
        local n = data.limbs[limbName]
        if type(o) == "table" and type(n) == "table" and o.isCut and n.isCut then
            if o.isCicatrized and not n.isCicatrized then
                n.isCicatrized = true
                n.cicatrizationTime = 0
                if o.isCauterized then n.isCauterized = true end
                resend[#resend + 1] = limbName
                if HMLog then HMLog("TOCSync", "%s: server copy had healed %s as fresh -- kept healed, sent again", tostring(username), tostring(limbName)) end
            elseif not o.isCicatrized and not n.isCicatrized
                and tonumber(o.cicatrizationTime) and tonumber(n.cicatrizationTime)
                and o.cicatrizationTime < n.cicatrizationTime then
                if HMLog then HMLog("TOCSync", "%s: server copy had %s at %.1f h to heal, here %.1f -- kept ours, sent again",
                    tostring(username), tostring(limbName), n.cicatrizationTime, o.cicatrizationTime) end
                n.cicatrizationTime = o.cicatrizationTime
                resend[#resend + 1] = limbName
            end
        end
    end
    return resend
end

---Called when server data arrives via OnReceiveGlobalModData.
---Fills the DC instance with received data and fires WhenReady callbacks.
---@param key string  ModData key e.g. "TOC_Bob"
---@param data tocModDataType
function ClientDataController.OnDataReceived(key, data)
    -- During startup the game can return Bob as the player username, skip it
    if key == "TOC_Bob" then return end
    if not luautils.stringStarts(key, StaticData.MOD_NAME .. "_") then return end

    TOC_DEBUG.print("ClientDataController.OnDataReceived for " .. key)
    local username = key:sub(#StaticData.MOD_NAME + 2)  -- strip "TOC_" prefix
    local handler = DataController.GetInstance(username)

    if not handler then
        TOC_DEBUG.print("No DC instance found for " .. username .. ", ignoring")
        return
    end

    if data == nil or data == false or data.limbs == nil then
        TOC_DEBUG.print("data/data.limbs is nil — new character or something is wrong")
        return
    end

    -- HM 1.2.8 (owner 2026-11-27: "a fully healed stump came back as a fresh
    -- wound after the other hand was cut"): healing runs on THIS client and is
    -- only sent to the server; a server copy that missed it would wipe it here.
    -- A stump can only go from healed back to fresh by being cut again, which
    -- needs it to be uncut first, so a cut limb healed here stays healed.
    local resend = ClientDataController.KeepLocalHealing(username, handler, data)

    -- Populate DC and fire WhenReady callbacks
    handler:save(data)

    for i = 1, #resend do
        pcall(function() handler:updateAmputationsFromClient(resend[i]) end)
    end

    -- Activate TOC override for the health panel
    SetHealthPanelTOC()
end

Events.OnReceiveGlobalModData.Add(ClientDataController.OnDataReceived)

return ClientDataController

local CommandsData = require("TOC/CommandsData")
local CommonMethods = require("TOC/CommonMethods")
local StaticData = require("TOC/StaticData")
local DataController = require("TOC/Controllers/DataController")
local CachedDataHandler = require("TOC/Handlers/CachedDataHandler")

local OverridenMethodsArchive = require("TOC/OverridenMethodsArchive")
-------------------------

LuaEventManager.AddEvent("OnProsthesisUnequipped")  -- args: playerObj, limbName

---@class ProsthesisHandler
local ProsthesisHandler = {}

local bodylocArmProstBaseline = "toc:armprost_"
--local bodyLocLegProst = "TOC_LegProst"

---Check if the following item is a prosthesis or not
---@param item InventoryItem?
---@return boolean
function ProsthesisHandler.CheckIfProst(item)
    -- TODO Won't be correct when prost for legs are gonna be in
    if item == nil or item:getBodyLocation() == nil then
        --TOC_DEBUG.print("Not prost or no body location")
        return false
    end
    --TOC_DEBUG.print("CheckIfProst")
    return item:getBodyLocation():toString():contains(bodylocArmProstBaseline)
end

---Get the grouping for the prosthesis
---@param item InventoryItem
---@return string
function ProsthesisHandler.GetGroup(item)
    local fullType = item:getFullType()
    local side = CommonMethods.GetSide(fullType)

    local bodyLocation = item:getBodyLocation()
    local position
    if bodyLocation:toString():contains(bodylocArmProstBaseline) then
        position = "Top_"
    else
        TOC_DEBUG.print("Something is wrong, no position in this item")
        position = nil
    end

    local index = position .. side
    local group = StaticData.AMP_GROUPS_IND_STR[index]
    return group
end

-- HM 1.0.8 (owner 2026-11-18: "taking off and putting on a prosthesis
-- duplicates it"): in B42 multiplayer the wear / unequip actions are checked
-- on the client AND on the server. These checks read getPlayer(), which is
-- nil on a dedicated server, and the server's cached "highest amputated
-- limb" can be empty -- so the server refused (or errored on) an action the
-- client had already done, the two copies of the inventory went apart and
-- the prosthesis showed up twice. Now the action's own character is used,
-- the server works the value out itself when its cache is empty, the "can't
-- equip" line is said only on the player's own game, and every wear / remove
-- of a prosthesis is logged on both sides ([HARMONIE_HM][Prosthesis]).
local function hmlog(fmt, ...) if HMLog then HMLog("Prosthesis", fmt, ...) end end
local function sideName() return (isServer and isServer()) and "server" or ((isClient and isClient()) and "client" or "SP") end
ProsthesisHandler.log = hmlog

local function highestFor(username)
    local h = username and CachedDataHandler.GetHighestAmputatedLimbs(username)
    if (h == nil or (h.L == nil and h.R == nil)) and username and isServer and isServer() then
        pcall(CachedDataHandler.CalculateHighestAmputatedLimbs, username)
        h = CachedDataHandler.GetHighestAmputatedLimbs(username)
    end
    return h
end

---Check if a prosthesis is equippable. It depends whether the player has a cut limb or not on that specific side. There's an exception for Upper arm, obviously
---@param fullType string
---@param character IsoPlayer? the one wearing it (getPlayer() only as a last resort -- nil on a server)
---@return boolean
function ProsthesisHandler.CheckIfEquippable(fullType, character)
    --TOC_DEBUG.print("Current item is a prosthesis")
    local side = CommonMethods.GetSide(fullType)
    --TOC_DEBUG.print("Checking side: " .. tostring(side))

    local who = character or (getPlayer and getPlayer())
    local username = who and who.getUsername and who:getUsername()
    local highestAmputatedLimbs = highestFor(username)

    --TOC_DEBUG.print("highestAmputatedLimbs")
    --TOC_DEBUG.printTable(highestAmputatedLimbs)
    if highestAmputatedLimbs then
        local hal = highestAmputatedLimbs[side]
        if hal and not string.contains(hal, "UpperArm") then
            TOC_DEBUG.print("Found acceptable limb to use prosthesis => " .. tostring(hal))
            return true
        end
    end

    -- No acceptable cut limbs
    return false
end

---Handle equipping or unequipping prosthetics.
---This was annotated @server, but all three callers below are timed action complete()
---methods, and a timed action is only ever ticked by the client that owns the character.
---In MP it therefore always runs on a client.
---@param character IsoPlayer
---@param item InventoryItem
---@param isEquipping boolean
---@return boolean
function ProsthesisHandler.SearchAndSetupProsthesis(character, item, isEquipping)
    if not ProsthesisHandler.CheckIfProst(item) then return false end

    local username = character:getUsername()

    local group = ProsthesisHandler.GetGroup(item)
    TOC_DEBUG.print("Setup Prosthesis => " .. group .. " - is equipping? " .. tostring(isEquipping))
    local dcInst = DataController.GetInstance(username)
    if not dcInst then return false end     -- DC not ready yet, bail safely
    dcInst:setIsProstEquipped(group, isEquipping)

    -- apply() does nothing on a client, and nothing else carried the flag up, so the
    -- server's copy stayed false forever. That copy wins at the next login, so a worn
    -- prosthesis silently stopped counting after a relog - hand feasibility back to
    -- unusable, no adjustMaxTime bonus, no "Prosthesis Equipped" in the health panel -
    -- until it was taken off and put back on. Mirror the change to the server instead.
    if isClient() and character:isLocalPlayer() then
        sendClientCommand(CommandsData.modules.TOC_RELAY, CommandsData.server.Relay.RelayProsthesisState,
            {group = group, isEquipped = isEquipping})
    end

    dcInst:apply(character)
    return true
end

function ProsthesisHandler.Validate(item, isEquippable, character)
    local isProst = ProsthesisHandler.CheckIfProst(item)
    if not isProst then return isEquippable end

    local fullType = item:getFullType() -- use fulltype for side
    if isEquippable then
        isEquippable = ProsthesisHandler.CheckIfEquippable(fullType, character)
        if not isEquippable then
            hmlog("%s: %s cannot be worn here (%s) -- no fitting stump on that side", tostring(character and character.getUsername and character:getUsername() or "?"), tostring(fullType), sideName())
        end
    else
        TOC_DEBUG.print("Should say cant equip")
        -- only on the player's own game (getPlayer() is nil on a server)
        local who = character or (getPlayer and getPlayer())
        if who and who.Say and not (isServer and isServer()) and (not who.isLocalPlayer or who:isLocalPlayer()) then
            who:Say(getText("UI_Say_CantEquip"))
        end
    end

    return isEquippable
end



-------------------------
--* Overrides *--


local og_ISWearClothing_isValid = ISWearClothing.isValid
---@diagnostic disable-next-line: duplicate-set-field
function ISWearClothing:isValid()
    --TOC_DEBUG.print("ISWearClothing override")
    local isEquippable = og_ISWearClothing_isValid(self)
    return ProsthesisHandler.Validate(self.item, isEquippable, self.character)
end

local og_ISWearClothing_complete = ISWearClothing.complete
---@diagnostic disable-next-line: duplicate-set-field
function ISWearClothing:complete()
    local result = og_ISWearClothing_complete(self)
    if ProsthesisHandler.CheckIfProst(self.item) then
        hmlog("%s wore %s id %s (%s, %s)", tostring(self.character and self.character:getUsername() or "?"), tostring(self.item:getFullType()),
            tostring(self.item:getID()), sideName(), result and "done" or "NOT done")
    end
    if result then
        ProsthesisHandler.SearchAndSetupProsthesis(self.character, self.item, true)
    end
    return result
end


local og_ISClothingExtraAction_isValid = OverridenMethodsArchive.Save("ISClothingExtraAction_isValid", ISClothingExtraAction.isValid)

---@diagnostic disable-next-line: duplicate-set-field
function ISClothingExtraAction:isValid()
    local isEquippable = og_ISClothingExtraAction_isValid(self)
    -- self.extra is a string, not the item; made once per action (isValid
    -- runs every tick -- it made a new item every tick)
    self.tocExtraTest = self.tocExtraTest or instanceItem(self.extra)
    return ProsthesisHandler.Validate(self.tocExtraTest, isEquippable, self.character)
end

local og_ISClothingExtraAction_complete = OverridenMethodsArchive.Save("ISClothingExtraAction_complete", ISClothingExtraAction.complete)
---@diagnostic disable-next-line: duplicate-set-field
function ISClothingExtraAction:complete()
    local extraItem = instanceItem(self.extra)
    --TOC_DEBUG.print("ISClothingExtraAction_complete 1")
    ProsthesisHandler.SearchAndSetupProsthesis(self.character, extraItem, true)
    --TOC_DEBUG.print("ISClothingExtraAction_complete 2")

    return og_ISClothingExtraAction_complete(self)
end

local og_ISUnequipAction_complete = ISUnequipAction.complete
---@diagnostic disable-next-line: duplicate-set-field
function ISUnequipAction:complete()

    local isProst = ProsthesisHandler.SearchAndSetupProsthesis(self.character, self.item, false)
    local result = og_ISUnequipAction_complete(self)
    if isProst then
        hmlog("%s took off %s id %s (%s, %s)", tostring(self.character and self.character:getUsername() or "?"), tostring(self.item:getFullType()),
            tostring(self.item:getID()), sideName(), result == false and "NOT done" or "done")
    end

    if isProst then
        -- we need to fetch the limbname associated to the prosthesis
        local side = CommonMethods.GetSide(self.item:getFullType())
        local highestAmputatedLimbs = CachedDataHandler.GetHighestAmputatedLimbs(self.character:getUsername())
        if highestAmputatedLimbs then
            local hal = highestAmputatedLimbs[side]
            if hal then
                TOC_DEBUG.print("Triggered OnProsthesisUnequipped")
                triggerEvent("OnProsthesisUnequipped", self.character, hal)
            end
        end
    end

    return result
end

return ProsthesisHandler

local DataController = require("TOC/Controllers/DataController")
local CachedDataHandler = require("TOC/Handlers/CachedDataHandler")
local CommonMethods = require("TOC/CommonMethods")
local StaticData = require("TOC/StaticData")


--* Time to perform actions overrides
local og_ISBaseTimedAction_adjustMaxTime = ISBaseTimedAction.adjustMaxTime
--- Adjust time
---@diagnostic disable-next-line: duplicate-set-field
-- HTS 1.1.1 (owner: "after adding food or doing anything the bar over the
-- head takes more than 20 s"): every action that ends up long is logged
-- once a minute per kind -- the time asked, after the game's own changes,
-- and after TOC's cut-limb multiplier -- so console.txt shows who made it long.
local longSeen = {}
local function logLong(self, asked, vanilla, final)
    if not final or final < 900 then return end
    local kind = tostring(self.Type or "?")
    local now = getTimestampMs and getTimestampMs() or 0
    if longSeen[kind] and now - longSeen[kind] < 60000 then return end
    longSeen[kind] = now
    if HMLog then
        HMLog("ActionTime", "%s: asked %s, after the game %s, after TOC %s%s", kind, tostring(asked), tostring(vanilla), tostring(final),
            final > (vanilla or 0) and " (cut-limb multiplier)" or "")
    end
end

function ISBaseTimedAction:adjustMaxTime(maxTime)
    local time = og_ISBaseTimedAction_adjustMaxTime(self, maxTime)
    local vanillaTime = time
    --TOC_DEBUG.print("Running override for adjustMaxTime")
    -- Exceptions handling, if we find that parameter then we just use the original time

    if self.skipTOC then
        --TOC_DEBUG.print("Should skip TOC stuff")
        pcall(logLong, self, maxTime, vanillaTime, time)
        return time
    end

    -- Action is valid, check if we have any cut limb and then modify maxTime
    local dcInst = DataController.GetInstance(self.character:getUsername())
    local amputatedLimbs = dcInst and dcInst:getIsAnyLimbCut() and CachedDataHandler.GetAmputatedLimbs(self.character:getUsername())
    if time ~= -1 and amputatedLimbs then
        --TOC_DEBUG.print("Overriding adjustMaxTime")
        for k, _ in pairs(amputatedLimbs) do
            local limbName = k
            local perkAmp = Perks["Side_" .. CommonMethods.GetSide(limbName)]
            local perkLevel = self.character:getPerkLevel(perkAmp)

            if dcInst:getIsProstEquipped(limbName) then
                local perkProst = Perks["ProstFamiliarity"]
                perkLevel = perkLevel + self.character:getPerkLevel(perkProst)
            end

            local perkLevelScaled
            if perkLevel ~= 0 then perkLevelScaled = perkLevel / 10 else perkLevelScaled = 0 end
            --TOC_DEBUG.print("Perk Level: " .. tostring(perkLevel))
            --TOC_DEBUG.print("OG time: " .. tostring(time))

            -- Modified Time shouldn't EVER be lower compared to the og one.
            local modifiedTime = time * (StaticData.LIMBS_TIME_MULTIPLIER_IND_NUM[limbName] - perkLevelScaled)

            if modifiedTime >= time then
                time = modifiedTime
            end

            --TOC_DEBUG.print("Modified time: " .. tostring(time))
        end

    end

    pcall(logLong, self, maxTime, vanillaTime, time)
    return time
end


---@param character IsoPlayer
---@param limbName string
local function TryRandomBleed(character, limbName)
    -- Chance should be determined by the cicatrization time
    local cicTime = DataController.GetInstance(character:getUsername()):getCicatrizationTime(limbName)
    if cicTime == 0 then return end

    local normCicTime = CommonMethods.Normalize(cicTime, 0, StaticData.LIMBS_CICATRIZATION_TIME_IND_NUM[limbName]) / 2
    TOC_DEBUG.print("OG cicTime: " .. tostring(cicTime))
    TOC_DEBUG.print("Normalized cic time : " .. tostring(normCicTime))

    local chance = ZombRandFloat(0.0, 1.0)
    if chance < normCicTime then
        local bleedingTime = math.max(1, math.floor(normCicTime * 2 * 20))
        TOC_DEBUG.print("Triggered bleeding from non cicatrized wound, secs: " .. tostring(bleedingTime))
        -- HM 1.2.3: logged -- the bleed lands on the part ABOVE the stump
        -- (Hand -> ForeArm, ForeArm -> UpperArm, UpperArm -> Torso_Upper),
        -- which still exists, so "no wounds on a missing limb" never stops it
        if HMLog then HMLog("Prosthesis", "%s: prosthesis on the unhealed %s stump -> bleeding %s s on %s (chance %.2f)",
            tostring(character:getUsername()), tostring(limbName), tostring(bleedingTime), tostring(StaticData.LIMBS_ADJACENT_IND_STR[limbName]), normCicTime) end

        if isClient() then
            -- MP: client-side setBleedingTime does not sync to server — relay the call
            local CommandsData = require("TOC/CommandsData")
            sendClientCommand(CommandsData.modules.TOC_RELAY, CommandsData.server.Relay.RelayTriggerBleed, {
                patientNum = character:getOnlineID(),
                limbName = limbName,
                bleedingTime = bleedingTime,
            })
        else
            -- SP: same Lua state as server, apply directly
            local adjacentBodyPartType = BodyPartType[StaticData.LIMBS_ADJACENT_IND_STR[limbName]]
            local bp = character:getBodyDamage():getBodyPart(adjacentBodyPartType)
            bp:setBleedingTime(bleedingTime)
        end
    end
end


--* Random bleeding during cicatrization
local og_ISBaseTimedAction_perform = ISBaseTimedAction.perform
---@diagnostic disable-next-line: duplicate-set-field
function ISBaseTimedAction:perform()
    og_ISBaseTimedAction_perform(self)

    if isServer() then return end   -- would never be server anyway I guess, it's perform...

    local username = self.character:getUsername()
    local dcInst = DataController.GetInstance(username)
    if not dcInst or not dcInst:getIsAnyLimbCut() then return end

    local amputatedLimbs = CachedDataHandler.GetAmputatedLimbs(username)
    if not amputatedLimbs then return end

    for k, _ in pairs(amputatedLimbs) do
        local limbName = k
        if dcInst:getIsCut(limbName) and dcInst:getIsVisible(limbName) then
            if not dcInst:getIsCicatrized(limbName) and dcInst:getIsProstEquipped(limbName) then
                TryRandomBleed(self.character, limbName)
            end
        end
    end
end

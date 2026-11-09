--[[
    HARMONIE - How to Survive : a plain amputation costs half the blood

    Owner, 2026-11-09: "อยากปรับให้การตัดแขนโดยไม่ใช่การผ่าตัดเสียเลือด 50%".
    The Only Cure's own "amputate with a saw" (CutLimbAction ->
    AmputationHandler:execute(true)) now takes HM_AmputationBlood.SHARE (50%)
    of the patient's FULL blood volume (EHR blood) from what they have now.

    Not counted here:
      * our Surgery tab's amputation (HM_SurgeryServer sets
        HM_Surgery.amputatingNow around its call: it already costs blood by
        grade, -10% excellent ... -50% failed);
      * execute(false): trait amputations and TOC's own tests (no damage).

    Where it runs: blood lives on the server in multiplayer (EHR syncs it to
    the client), so a MP client skips -- the server's relay runs execute
    first and sends the change with EHR.SafeTransmitModData. Single player
    runs it on the spot. Under 20% blood EHR's heart can stop (when sandbox
    HomeMedic.LethalConditions is on), so have a blood bag ready.
]]--
HM_AmputationBlood = HM_AmputationBlood or {}
local M = HM_AmputationBlood
M.SHARE = 0.50

local function log(fmt, ...)
    if HMLog then HMLog("AmputationBlood", fmt, ...) else print("[HARMONIE_HM][AmputationBlood] " .. string.format(fmt, ...)) end
end
local function nameOf(p)
    if HMLogName then return HMLogName(p) end
    local ok, n = pcall(function() return p:getUsername() end)
    return ok and tostring(n) or "?"
end

function M.afterCut(handler, damagePlayer)
    if isClient and isClient() then return false end
    if damagePlayer == false then return false end
    local patient = handler and handler.patientPl
    if not patient then return false end
    if HM_Surgery and HM_Surgery.amputatingNow then
        log("%s: %s cut in the Surgery tab -- its grade already took the blood", nameOf(patient), tostring(handler.limbName))
        return false
    end
    local B = EHR and EHR.Blood
    local bd = patient:getModData().EHR_Blood
    local maxV = type(bd) == "table" and tonumber(bd.maxVolume) or nil
    local curV = type(bd) == "table" and tonumber(bd.currentVolume) or nil
    if not (B and B.ModifyBloodVolume and maxV and curV and maxV > 0) then
        log("%s: %s cut, but no EHR blood data -- no blood taken", nameOf(patient), tostring(handler.limbName))
        return false
    end
    local loss = math.floor(M.SHARE * maxV + 0.5)
    pcall(B.ModifyBloodVolume, patient, -loss)
    local nowV = tonumber(bd.currentVolume) or (curV - loss)
    log("%s: %s amputated without surgery -- blood %.0f%% -> %.0f%% (-%d mL, %d%% of full)", nameOf(patient),
        tostring(handler.limbName), curV / maxV * 100, nowV / maxV * 100, loss, math.floor(M.SHARE * 100 + 0.5))
    if EHR.SafeTransmitModData then pcall(EHR.SafeTransmitModData, patient) end
    return true
end

function M.install()
    if M.installed then return true end
    local ok, AH = pcall(require, "TOC/Handlers/AmputationHandler")
    if not ok or type(AH) ~= "table" or type(AH.execute) ~= "function" then
        log("The Only Cure's AmputationHandler not found (%s) -- plain amputations take no extra blood", tostring(ok and "no execute" or AH))
        return false
    end
    local original = AH.execute
    AH.execute = function(self, damagePlayer, ...)
        local r = original(self, damagePlayer, ...)
        local okA, err = pcall(M.afterCut, self, damagePlayer)
        if not okA then log("blood after amputation FAILED: %s", tostring(err)) end
        return r
    end
    M.installed = true
    log("installed: an amputation outside the Surgery tab costs %d%% of full blood", math.floor(M.SHARE * 100 + 0.5))
    return true
end

if Events then
    if Events.OnGameStart then Events.OnGameStart.Add(M.install) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(M.install) end
end

return M

--[[
    HARMONIE - How to Survive : no illness on a limb that is gone

    Owner, 2026-11-09: "โรคที่อยู่บนอวัยวะที่ถูกตัดไปแล้วควรหาย และโรคไม่ควรเกิด
    บนแขนเทียม".

    The Only Cure clears the VANILLA wounds of a cut limb (AmputationHandler
    :healArea), but EHR keeps its own per-part records that it never touched:
      * wound infection (EHR.WoundInfection data: parts / incubating /
        antisepticBlocked / immuneContained, keyed by the body part name,
        which is the same name as TOC's limb: Hand_L, ForeArm_L, UpperArm_L...)
        and the vanilla infected-wound flag it reads;
      * cellulitis, which remembers the part it started on (sourceBodyPart).
    This file:
      1. at the amputation (HM_AmputationBlood's wrapper calls M.onCut) clears
         those records on every limb that is now cut (the cut one and the
         ones below it), and cures cellulitis whose source part is gone;
      2. every M.INTERVAL_MS checks players with a cut limb and clears any
         record that appeared on a missing limb again -- a stump or a
         prosthesis has no skin to get infected.
    Illnesses of the whole body stay: sepsis (already in the blood), tetanus,
    scabies, Knox elsewhere (TOC decides Knox itself).
    Server and single player only (EHR's records live on the server in MP).
]]--
HM_AmputatedParts = HM_AmputatedParts or {}
local M = HM_AmputatedParts
M.LIMBS = { "Hand_L", "ForeArm_L", "UpperArm_L", "Hand_R", "ForeArm_R", "UpperArm_R" }
M.INTERVAL_MS = 5000

local function log(fmt, ...)
    if HMLog then HMLog("AmputatedParts", fmt, ...) else print("[HARMONIE_HM][AmputatedParts] " .. string.format(fmt, ...)) end
end
local function nameOf(p)
    if HMLogName then return HMLogName(p) end
    local ok, n = pcall(function() return p:getUsername() end)
    return ok and tostring(n) or "?"
end
local function norm(s) return (tostring(s or ""):lower():gsub("[%s_%-]", "")) end
local function mpClient() return isClient and isClient() end

-- the set of cut limbs of this player (nil = TOC data not ready / no cut)
function M.cutLimbs(player)
    local ok, DC = pcall(require, "TOC/Controllers/DataController")
    if not ok or type(DC) ~= "table" or not DC.GetInstance then return nil end
    local uok, user = pcall(function() return player:getUsername() end)
    local dc = uok and DC.GetInstance(user) or nil
    if not dc or not dc.getIsCut then return nil end
    local cut, any = {}, false
    for _, limb in ipairs(M.LIMBS) do
        local okC, isCut = pcall(dc.getIsCut, dc, limb)
        if okC and isCut then cut[limb] = true; any = true end
    end
    return any and cut or nil
end

local function bodyPartOf(player, limb)
    local part
    pcall(function()
        part = player:getBodyDamage():getBodyPart(BodyPartType.FromString(limb))
    end)
    return part
end

-- clear what EHR keeps on the cut limbs; returns a list of what was cleared
function M.clean(player, cut, why)
    if not player or not cut then return {} end
    local done = {}
    local WI = EHR and EHR.WoundInfection
    local data = WI and WI.GetData and WI.GetData(player) or nil
    for limb in pairs(cut) do
        if WI and WI.ClearPartSymptomPain then pcall(WI.ClearPartSymptomPain, player, limb) end
        if type(data) == "table" then
            for _, key in ipairs({ "parts", "incubating", "antisepticBlocked", "immuneContained" }) do
                local t = data[key]
                if type(t) == "table" and t[limb] ~= nil then
                    t[limb] = nil
                    done[#done + 1] = limb .. " wound infection (" .. key .. ")"
                end
            end
        end
        local bp = bodyPartOf(player, limb)
        if bp and bp.isInfectedWound then
            local okI, infected = pcall(bp.isInfectedWound, bp)
            if okI and infected then
                if WI and WI.ClearVanillaInfection then
                    pcall(WI.ClearVanillaInfection, bp, "amputated limb")
                else
                    pcall(function() bp:setWoundInfectionLevel(-1); bp:setInfectedWound(false) end)
                end
                done[#done + 1] = limb .. " infected wound"
            end
        end
    end
    local D = EHR and EHR.Disease
    local dd = D and D.GetDiseaseData and D.GetDiseaseData(player) or nil
    local cel = dd and dd.active and dd.active.cellulitis or nil
    if type(cel) == "table" and cel.sourceBodyPart and D.Cure then
        for limb in pairs(cut) do
            if norm(limb) == norm(cel.sourceBodyPart) then
                pcall(D.Cure, player, "cellulitis")
                done[#done + 1] = "cellulitis (started on " .. limb .. ")"
                break
            end
        end
    end
    if #done > 0 then
        if WI and WI.RecalculateStats then pcall(WI.RecalculateStats, player) end
        log("%s: cleared on missing limbs (%s): %s", nameOf(player), tostring(why), table.concat(done, ", "))
        if EHR and EHR.SafeTransmitModData then pcall(EHR.SafeTransmitModData, player) end
    end
    return done
end

-- called right after TOC's AmputationHandler:execute (HM_AmputationBlood)
function M.onCut(handler)
    if mpClient() then return end
    local patient = handler and handler.patientPl
    if not patient then return end
    local cut = M.cutLimbs(patient)
    if not cut then
        log("%s: %s cut, but TOC data not ready -- illnesses on it cleared by the next check", nameOf(patient), tostring(handler.limbName))
        return
    end
    M.clean(patient, cut, "amputation of " .. tostring(handler.limbName))
end

-- the periodic check
local function players()
    local out = {}
    if isServer and isServer() and getOnlinePlayers then
        local list = getOnlinePlayers()
        for i = 0, (list and list:size() or 0) - 1 do out[#out + 1] = list:get(i) end
    elseif getNumActivePlayers and getSpecificPlayer then
        for i = 0, getNumActivePlayers() - 1 do
            local p = getSpecificPlayer(i)
            if p then out[#out + 1] = p end
        end
    end
    return out
end

M.nextAt = 0
function M.tick()
    if mpClient() then return end
    local now = getTimestampMs and getTimestampMs() or 0
    if now < M.nextAt then return end
    M.nextAt = now + M.INTERVAL_MS
    for _, p in ipairs(players()) do
        local alive = true
        pcall(function() alive = not p:isDead() end)
        if alive then
            local cut = M.cutLimbs(p)
            if cut then
                local ok, err = pcall(M.clean, p, cut, "check")
                if not ok then log("check FAILED for %s: %s", nameOf(p), tostring(err)) end
            end
        end
    end
end

if Events and Events.OnTick then
    Events.OnTick.Add(M.tick)
    log("loaded: illnesses on cut limbs (stumps, prostheses) are cleared at the cut and every %d s", math.floor(M.INTERVAL_MS / 1000))
end

return M

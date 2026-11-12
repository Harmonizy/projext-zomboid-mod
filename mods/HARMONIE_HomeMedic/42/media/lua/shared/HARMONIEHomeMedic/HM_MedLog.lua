--[[
    HARMONIE - How to Survive : every pill taken is logged, and recorded in MP too

    Owner, 2026-11-12: "มีคนกินยาแก้ปวด แล้วไม่ขึ้นว่าใช้ยาแก้ปวดในแท็บแรก".
    Tab 1's ACTIVE MEDICATIONS reads EHR_Medication.activeDoses (a dose shows
    while in effect: painkillers 3 h). The way there:
      vanilla "Take pills" (ISTakePillAction) -> EHR_MedicationHook
        SP: writes the dose itself (any FirstAid / Medical item);
        MP client: EHR.Medication.UseConsumedMedication -> server command ->
          the server records it ONLY if the item is in EHR.Medication.Database.
    Two gaps, both silent (EHR's own log prints only errors by default):
      * nothing in the console said a pill was taken or recorded;
      * in MP a medical item EHR does not list (another mod's painkiller...)
        was never recorded, while SP recorded it as a generic medicine.
    This file logs each pill (client) and each server recording, and records
    an unlisted medical item on the server the SP way (dose only, tier 0).
]]--

HM_MedLog = HM_MedLog or {}
local ML = HM_MedLog

local function log(fmt, ...) if HMLog then HMLog("Medication", fmt, ...) end end
local function nameOf(p) return HMLogName and HMLogName(p) or "?" end
local function pureClient() return isClient and isClient() and not (isServer and isServer()) end

local function itemName(ft)
    if getItemNameFromFullType then
        local ok, n = pcall(getItemNameFromFullType, ft)
        if ok and n and n ~= "" then return n end
    end
    return ft
end

-- a script item the game marks as medicine (EHR_MedicationHook's own rule)
local function isMedicalType(ft)
    local sm = getScriptManager and getScriptManager()
    local si
    if sm then pcall(function() si = sm:FindItem(ft) end) end
    if not si then return false end
    local ok, cat = pcall(function() return si.getDisplayCategory and si:getDisplayCategory() end)
    if ok and cat == "FirstAid" then return true end
    local okM, med = pcall(function() return si.isMedical and si:isMedical() end)
    return okM and med == true
end

local function doseLine(p, ft)
    local M = EHR and EHR.Medication
    local st = M and M.GetDoseStatus and M.GetDoseStatus(p, ft)
    if type(st) ~= "table" then return "no dose record" end
    return string.format("dose %d/%d, in effect %s (%.1f h left)", tonumber(st.doseCount) or 0, tonumber(st.totalDosesNeeded) or 0,
        tostring(st.isDoseActive == true), tonumber(st.hoursActiveRemaining) or 0)
end

function ML.install()
    if ML.installed then return end
    local M = EHR and EHR.Medication
    if not (M and type(M.UseConsumedMedication) == "function") then
        log("EHR.Medication.UseConsumedMedication missing -- pills are not logged"); return
    end
    local orig = M.UseConsumedMedication
    M.UseConsumedMedication = function(player, itemFullType, administeringPlayer, ...)
        local ft = tostring(itemFullType)
        local listed = M.Database and M.Database[ft] ~= nil
        if pureClient() then
            log("%s took %s (%s) -- asked the server to record it%s", nameOf(player), itemName(ft), ft,
                listed and "" or " [not in EHR's medicine list]")
            return orig(player, itemFullType, administeringPlayer, ...)
        end
        local r = orig(player, itemFullType, administeringPlayer, ...)
        if not listed and isMedicalType(ft) and M.TrackDoseOnly then
            -- the SP hook records an unlisted medical item as a generic dose
            local generic = { tier = 0, treats = {}, displayName = itemName(ft), isGeneric = true }
            local ok, err = pcall(M.TrackDoseOnly, player, generic, ft)
            if ok then
                if EHR.SafeTransmitModData then pcall(EHR.SafeTransmitModData, player) end
                log("%s took %s (%s): not in EHR's medicine list -- recorded as a generic medicine (%s)",
                    nameOf(player), itemName(ft), ft, doseLine(player, ft))
            else
                log("%s took %s: generic record FAILED: %s", nameOf(player), ft, tostring(err))
            end
            return true
        end
        log("%s took %s (%s): recorded=%s -- %s", nameOf(player), itemName(ft), ft, tostring(r), doseLine(player, ft))
        return r
    end
    ML.installed = true
    log("installed: pills taken are logged; an unlisted medical item is recorded in MP too")
end

-- SP / MP client: one line per pill the vanilla action completes
function ML.installPillLog()
    if ML.pillLog or not ISTakePillAction then return end
    local function wrap(name)
        local orig = ISTakePillAction[name]
        if type(orig) ~= "function" then return end
        ISTakePillAction[name] = function(self, ...)
            if not self.hmPillLogged then
                self.hmPillLogged = true
                local ft
                pcall(function() ft = self.item and self.item:getFullType() end)
                local M = EHR and EHR.Medication
                if ft and not pureClient() then
                    log("%s took %s (%s) via Take pills -- EHR medicine: %s", nameOf(self.character), itemName(ft), ft,
                        tostring(M and M.Database and M.Database[ft] ~= nil))
                end
            end
            return orig(self, ...)
        end
    end
    wrap("perform"); wrap("complete")
    ML.pillLog = true
end

if Events then
    if Events.OnGameStart then Events.OnGameStart.Add(function() ML.install(); ML.installPillLog() end) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(ML.install) end
end

return ML

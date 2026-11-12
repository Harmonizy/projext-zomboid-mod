--[[
    HARMONIE - How to Survive : admin tests for every tab of the medical window

    Owner, 2026-11-12 (1.0.0): "ในทุกหน้าต่างและแท็บให้มีปุ่มที่แอดมินสามารถกดเพื่อ
    ทดสอบอะไรต่างๆได้". The hub's flask button (000_HARMONIE_AdminTest.lua) in
    the medical window's header lists these for the open tab. Everything that
    changes the patient runs on the server (or in single player) through the
    hub's ops, which call EHR's own admin debug commands
    (EHR.ServerCommands.*: they already sync the patient back). The tests
    work on yourself; in someone else's window on that patient.
]]--

local AT = HARMONIE_AdminTest
if not AT then print("[HARMONIE_HM][AdminTests] no HARMONIE_AdminTest -- no admin tests"); return end

local function log(fmt, ...) if HMLog then HMLog("AdminTests", fmt, ...) end end
local function SC() return EHR and EHR.ServerCommands end
local function byOnline(id)
    if id == nil or not getPlayerByOnlineID then return nil end
    local ok, p = pcall(getPlayerByOnlineID, tonumber(id))
    return ok and p or nil
end
-- the op's patient: args.target (online id) when given, else the sender
local function patientOf(sender, args)
    return byOnline(args and args.target) or sender
end
local function ehr(name, sender, args)
    local f = SC() and SC()[name]
    if type(f) ~= "function" then log("EHR.ServerCommands.%s missing", name); return end
    local p = patientOf(sender, args)
    f(p, args)
    log("%s ran %s on %s", HMLogName and HMLogName(sender) or "?", name, HMLogName and HMLogName(p) or "?")
end

-- ------------------------------------------------------------------ server ops
for _, name in ipairs({ "FullHeal", "CureAllDiseases", "InflictDisease", "SetBloodPercent", "ApplyVanillaInjury",
    "InfectRandom", "ClearAllMedications", "StatPresetPerfect", "StatPresetNearDeath", "ApplyScenario", "TriggerSepsis",
    "ClearAllInfections", "ClearVanillaInjuries" }) do
    AT.serverOp("hm_" .. name, function(sender, args) ehr(name, sender, args) end)
end

-- every illness known (diagnosis tab / handbooks)
AT.serverOp("hm_KnowAll", function(sender, args)
    local f = SC() and SC().UnlockDiseaseKnowledge
    local p = patientOf(sender, args)
    local n = 0
    for id in pairs(EHR and EHR.Disease and EHR.Disease.Diseases or {}) do
        if f then pcall(f, p, { diseaseId = id }); n = n + 1 end
    end
    log("knowledge of %d illnesses unlocked for %s", n, HMLogName and HMLogName(p) or "?")
end)

-- ------------------------------------------------------------------ client side
local function target(ctx) return ctx and ctx.target or nil end
local function send(p, op, ctx, args)
    args = args or {}
    args.target = target(ctx)
    return AT.send(p, op, args)
end

local function supplyTypes()
    local S = HM_Surgery
    local out, seen = {}, {}
    for _, slot in pairs(S and S.Supplies or {}) do
        if not slot.transfusion then
            for _, o in ipairs(slot.options or {}) do
                if o.type and not seen[o.type] then seen[o.type] = true; out[#out + 1] = { o.type, 2 }; break end
            end
        end
    end
    return out
end

local function medicineTypes(limit)
    local out = {}
    for ft in pairs(EHR and EHR.Medication and EHR.Medication.Database or {}) do
        out[#out + 1] = { ft, 1 }
        if #out >= (limit or 60) then break end
    end
    table.sort(out, function(a, b) return a[1] < b[1] end)
    return out
end

local function surgicalIllness()
    local list = {}
    for id in pairs(HM_Surgery and HM_Surgery.SURGICAL or {}) do list[#list + 1] = id end
    table.sort(list)
    return list[ZombRand and (ZombRand(#list) + 1) or 1] or "cellulitis"
end

local function randomIllness()
    local list = {}
    for id in pairs(EHR and EHR.Disease and EHR.Disease.Diseases or {}) do list[#list + 1] = id end
    table.sort(list)
    return list[ZombRand and (ZombRand(#list) + 1) or 1] or "common_cold"
end

local function T(id, en) return { key = "UI_HomeMedic_Test_" .. id, fallback = en } end
local function test(id, en, run) local t = T(id, en); t.run = run; return t end

-- every tab
AT.register("hm", "*", {
    test("FullHeal", "Full heal (wounds, blood, illnesses)", function(p, ctx) send(p, "hm_FullHeal", ctx) end),
    test("Perfect", "Body stats perfect", function(p, ctx) send(p, "hm_StatPresetPerfect", ctx) end),
    test("Debug", "Open EHR's debug window", function() if EHR and EHR.DebugV2 and EHR.DebugV2.Toggle then EHR.DebugV2.Toggle() end end),
})
AT.register("hm", "ehr", {
    test("Wound", "Deep wound on the left hand", function(p, ctx) send(p, "hm_ApplyVanillaInjury", ctx, { partId = "Hand_L", injuryId = "deep_wound" }) end),
    test("Bite", "Bite on the right forearm", function(p, ctx) send(p, "hm_ApplyVanillaInjury", ctx, { partId = "ForeArm_R", injuryId = "bite" }) end),
    test("Infect", "Infect a random wound", function(p, ctx) send(p, "hm_InfectRandom", ctx, { severity = 2 }) end),
    test("ClearWounds", "Clear all injuries", function(p, ctx) send(p, "hm_ClearVanillaInjuries", ctx); send(p, "hm_ClearAllInfections", ctx) end),
    test("Blood40", "Blood to 40%", function(p, ctx) send(p, "hm_SetBloodPercent", ctx, { percent = 40 }) end),
    test("Blood100", "Blood to 100%", function(p, ctx) send(p, "hm_SetBloodPercent", ctx, { percent = 100 }) end),
    test("GiveBags", "Give blood bags, saline, IV kits and empty bags", function(p)
        AT.give(p, { { "ExtensiveHealth.BloodBagAPos", 1 }, { "ExtensiveHealth.BloodBagONeg", 1 }, { "ExtensiveHealth.SalineBag", 2 },
            { "ExtensiveHealth.IVKit", 3 }, { "ExtensiveHealth.EmptyBloodBag", 3 } })
    end),
})
AT.register("hm", "immunity", {
    test("Sepsis", "Start sepsis", function(p, ctx) send(p, "hm_TriggerSepsis", ctx) end),
    test("NearDeath", "Body stats near death", function(p, ctx) send(p, "hm_StatPresetNearDeath", ctx) end),
})
AT.register("hm", "stats", {
    test("Watch", "Give a medical watch and batteries", function(p)
        AT.give(p, { { "ExtensiveHealth.EHRMedicalWatch_Left", 1 }, { "Base.Battery", 3 } })
    end),
    test("NearDeath", "Body stats near death", function(p, ctx) send(p, "hm_StatPresetNearDeath", ctx) end),
})
AT.register("hm", "diagnosis", {
    test("Random", "Give a random illness", function(p, ctx) send(p, "hm_InflictDisease", ctx, { diseaseId = randomIllness() }) end),
    test("KnowAll", "Know every illness (handbook and diagnosis)", function(p, ctx) send(p, "hm_KnowAll", ctx) end),
    test("CureAll", "Cure every illness", function(p, ctx) send(p, "hm_CureAllDiseases", ctx) end),
    test("Doctor10", "First Aid to 10", function(p) AT.skill(p, "Doctor", 10) end),
})
AT.register("hm", "surgery", {
    test("Surgical", "Give an illness that needs surgery", function(p, ctx) send(p, "hm_InflictDisease", ctx, { diseaseId = surgicalIllness() }) end),
    test("Supplies", "Give every surgery supply", function(p) AT.give(p, supplyTypes()) end),
    test("Doctor10", "First Aid to 10", function(p) AT.skill(p, "Doctor", 10) end),
})
AT.register("hm", "amputation", {
    test("TOC", "Amputation admin window (amputate / reset)", function(p, ctx)
        if HM_OpenTOCAdmin then HM_OpenTOCAdmin(ctx and ctx.patient or p) end
    end),
    test("Saw", "Give a saw, bandages and suture needles", function(p)
        AT.give(p, { { "Base.Saw", 1 }, { "Base.Bandage", 4 }, { "Base.SutureNeedle", 2 } })
    end),
})
AT.register("hm", "handbook", {
    test("KnowAll", "Know every illness (handbook and diagnosis)", function(p, ctx) send(p, "hm_KnowAll", ctx) end),
})
AT.register("hm", "meds", {
    test("Meds", "Give one of every medicine", function(p) AT.give(p, medicineTypes(80)) end),
    test("ClearMeds", "Clear all medications in effect", function(p, ctx) send(p, "hm_ClearAllMedications", ctx) end),
})
AT.register("hm", "guide", {
    test("Healthy", "Scenario: healthy reset", function(p, ctx) send(p, "hm_ApplyScenario", ctx, { scenarioId = "healthy" }) end),
    test("Bleeding", "Scenario: severe blood loss", function(p, ctx) send(p, "hm_ApplyScenario", ctx, { scenarioId = "severe_blood_loss" }) end),
})

-- the button in the medical window's header: left of the gear (own window)
-- or left of Draw Blood (someone else's window)
local function installButton()
    if not (EHR_HealthPanelUI and AT.decorate) then return end
    AT.decorate(EHR_HealthPanelUI, {
        mod = "hm",
        tab = function(win) return win.activeTab or "ehr" end,
        player = function(win) return win.remoteDoctor or win.player end,
        ctx = function(win)
            local patient = win.remotePatient or win.player
            local t = nil
            if win.isRemoteHealthPanel and patient and patient.getOnlineID then t = patient:getOnlineID() end
            return { target = t, patient = patient }
        end,
        rect = function(win)
            local s = 24
            local y = math.floor(((win.HEADER_HEIGHT or 36) - s) / 2)
            if win.isRemoteHealthPanel then return win.width - 472, y, s end
            return win.width - 182, y, s
        end,
    })
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(installButton) end

return true

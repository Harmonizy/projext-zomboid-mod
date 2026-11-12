--[[
    HARMONIE - How to Survive : a doctor draws a patient's blood, with consent (MP)

    Owner, 2026-11-12: "ตอนนี้คนไข้ต้องกดด้วยตัวเอง อยากให้หมอกดให้คนไข้ได้
    แต่คนไข้ต้องยินยอมบริจาคเลือดก่อน". EHR's "Draw blood" is self only (the
    empty bag's right-click). Now:
      1. the doctor, with an empty blood bag (EHR's or homemade) and within
         RANGE tiles, right-clicks the patient -> "Draw blood (name)";
      2. the server checks (both online and alive, distance, the doctor's
         empty bag, the patient has >= 80% blood) and asks the PATIENT;
      3. the patient answers a Yes / No window (60 s);
      4. on yes the doctor's timed action runs (about 13 s, the patient must
         stay within RANGE); at its end the server checks everything again,
         takes the empty bag, takes 500 mL from the patient (EHR.Blood) and
         gives the doctor a fresh bag of the PATIENT's blood type -- the same
         result as EHR's own draw (EHR_ServerCommands.DrawBlood), donor marked.
    Everything is decided on the server; every step is logged.
]]--

require "HARMONIEHomeMedic/HM_Text"

HM_DrawBloodFrom = HM_DrawBloodFrom or {}
local DB = HM_DrawBloodFrom
DB.MODULE = "HARMONIE_HM_DrawFrom"
DB.RANGE = 3
DB.ASK_TIMEOUT_MS = 60 * 1000
DB.GRANT_TIMEOUT_MS = 3 * 60 * 1000
DB.MIN_BLOOD = 0.80
DB.AMOUNT = 500
DB.ACTION_TIME = 400
DB.EMPTY_BAGS = { "ExtensiveHealth.EmptyBloodBag", "ExtensiveHealth.HomemadeEmptyBloodBag" }
DB.BAG_OF = {
    ["O-"] = "ExtensiveHealth.BloodBagONeg", ["O+"] = "ExtensiveHealth.BloodBagOPos",
    ["A-"] = "ExtensiveHealth.BloodBagANeg", ["A+"] = "ExtensiveHealth.BloodBagAPos",
    ["B-"] = "ExtensiveHealth.BloodBagBNeg", ["B+"] = "ExtensiveHealth.BloodBagBPos",
    ["AB-"] = "ExtensiveHealth.BloodBagABNeg", ["AB+"] = "ExtensiveHealth.BloodBagABPos",
}

local function L(key, fallback, ...) return HM_Text("UI_HomeMedic_DrawFrom_" .. key, fallback, ...) end
local function log(fmt, ...) if HMLog then HMLog("DrawBlood", fmt, ...) end end
local function nameOf(p) return HMLogName and HMLogName(p) or "?" end
local function call(obj, m, ...)
    if not obj or not obj[m] then return nil end
    local ok, v = pcall(obj[m], obj, ...)
    if ok then return v end
    return nil
end
local function nowMs()
    if getTimestampMs then
        local ok, v = pcall(getTimestampMs)
        if ok and tonumber(v) then return tonumber(v) end
    end
    return (os and os.time and os.time() or 0) * 1000
end
local function onlineId(p) return tonumber(call(p, "getOnlineID")) end
local function byOnline(id)
    id = tonumber(id)
    if not id or not getOnlinePlayers then return nil end
    local list = getOnlinePlayers()
    for i = 0, list:size() - 1 do
        local p = list:get(i)
        if p and onlineId(p) == id then return p end
    end
    return nil
end
local function distance(a, b)
    local ax, ay, bx, by = call(a, "getX"), call(a, "getY"), call(b, "getX"), call(b, "getY")
    if not (ax and ay and bx and by) then return 999 end
    if call(a, "getZ") ~= call(b, "getZ") then return 999 end
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end
local function alive(p) return p ~= nil and not call(p, "isDead") end

-- the first empty blood bag: inventory (bags included), then the boxes in the room
function DB.findEmptyBag(p)
    local inv = call(p, "getInventory")
    if not inv then return nil end
    for _, ft in ipairs(DB.EMPTY_BAGS) do
        local it = inv.getFirstTypeRecurse and call(inv, "getFirstTypeRecurse", ft) or call(inv, "getFirstType", ft)
        if it then return it end
    end
    -- not carried: a box / bag in the same room (HM_Reach)
    if HM_Reach and HM_Reach.findType then
        local near = HM_Reach.findType(p, DB.EMPTY_BAGS)
        if near then return near end
    end
    return nil
end

local function bloodShare(p)
    local md = call(p, "getModData") or {}
    local b = md.EHR_Blood
    local cur, max = type(b) == "table" and tonumber(b.currentVolume), type(b) == "table" and tonumber(b.maxVolume)
    if not cur or not max or max <= 0 then return nil end
    return cur / max
end

local function bloodType(p)
    local B = EHR and EHR.Blood
    if B and B.GetPlayerBloodType then
        local ok, t = pcall(B.GetPlayerBloodType, p)
        if ok and t and DB.BAG_OF[t] then return t end
    end
    local md = call(p, "getModData") or {}
    local t = type(md.EHR_Blood) == "table" and md.EHR_Blood.bloodType or nil
    return DB.BAG_OF[t] and t or nil
end

-- ------------------------------------------------------------- server
DB.req = DB.req or {}
local nextId = 1

local function tell(p, command, args)
    if p and sendServerCommand then sendServerCommand(p, DB.MODULE, command, args or {}) end
end
local function refuse(doctor, reason, logFmt, ...)
    tell(doctor, "Refused", { reason = reason })
    log(logFmt, ...)
end

-- the shared checks of Ask and Perform; nil = fine, else (reasonKey, reasonText)
local function problem(doctor, patient)
    if not alive(doctor) or not alive(patient) then return "Gone", "The patient is no longer here." end
    if doctor == patient then return "Self", "Use the empty bag's own Draw blood for yourself." end
    if distance(doctor, patient) > DB.RANGE + 0.5 then return "Far", "Stand closer to the patient (3 tiles)." end
    if not DB.findEmptyBag(doctor) then return "NoBag", "You need an empty blood bag." end
    local share = bloodShare(patient)
    if not share then return "NoData", "The patient's blood data is not ready." end
    if share < DB.MIN_BLOOD then return "LowBlood", "The patient has too little blood to donate (needs 80%%)." end
    if not bloodType(patient) then return "NoType", "The patient's blood type is unknown." end
    return nil
end

function DB.serverAsk(doctor, args)
    local patient = byOnline(type(args) == "table" and args.patientOnline)
    local key, text = problem(doctor, patient)
    if key then
        return refuse(doctor, L("No_" .. key, text), "%s -> %s: draw blood refused (%s)", nameOf(doctor), nameOf(patient), key)
    end
    for id, r in pairs(DB.req) do
        if r.patient == onlineId(patient) and nowMs() - r.t < DB.ASK_TIMEOUT_MS and r.state == "asked" then
            return refuse(doctor, L("No_Busy", "The patient is already answering a request."), "%s -> %s: refused, a request is open", nameOf(doctor), nameOf(patient))
        end
    end
    local id = nextId; nextId = nextId + 1
    DB.req[id] = { doctor = onlineId(doctor), patient = onlineId(patient), state = "asked", t = nowMs() }
    tell(patient, "Consent", { requestId = id, doctorName = call(doctor, "getDisplayName") or call(doctor, "getUsername") or "?", amount = DB.AMOUNT })
    tell(doctor, "Waiting", { requestId = id })
    log("%s asks %s to donate blood (request %d)", nameOf(doctor), nameOf(patient), id)
end

function DB.serverAnswer(patient, args)
    args = type(args) == "table" and args or {}
    local id = tonumber(args.requestId)
    local r = id and DB.req[id]
    if not r or r.patient ~= onlineId(patient) or r.state ~= "asked" then
        log("%s answered request %s that is not open -- dropped", nameOf(patient), tostring(id)); return
    end
    local doctor = byOnline(r.doctor)
    if nowMs() - r.t > DB.ASK_TIMEOUT_MS then
        DB.req[id] = nil
        tell(doctor, "Refused", { reason = L("No_Timeout", "The patient did not answer in time.") })
        log("%s answered request %d too late -- dropped", nameOf(patient), id); return
    end
    if args.accepted ~= true then
        DB.req[id] = nil
        tell(doctor, "Refused", { reason = L("No_Declined", "The patient declined to donate blood.") })
        log("%s declined to donate blood to %s (request %d)", nameOf(patient), nameOf(doctor), id); return
    end
    r.state, r.t = "granted", nowMs()
    tell(doctor, "Granted", { requestId = id, patientOnline = r.patient })
    log("%s agreed to donate blood -- %s may draw it (request %d)", nameOf(patient), nameOf(doctor), id)
end

function DB.serverPerform(doctor, args)
    args = type(args) == "table" and args or {}
    local id = tonumber(args.requestId)
    local r = id and DB.req[id]
    if not r or r.doctor ~= onlineId(doctor) or r.state ~= "granted" then
        return refuse(doctor, L("No_NoConsent", "The patient has not agreed."), "%s: perform for request %s without consent -- dropped", nameOf(doctor), tostring(id))
    end
    DB.req[id] = nil
    if nowMs() - r.t > DB.GRANT_TIMEOUT_MS then
        return refuse(doctor, L("No_Timeout", "The consent ran out; ask again."), "%s: request %d consent ran out", nameOf(doctor), id)
    end
    local patient = byOnline(r.patient)
    local key, text = problem(doctor, patient)
    if key then
        return refuse(doctor, L("No_" .. key, text), "%s -> %s: draw blood stopped at the end (%s)", nameOf(doctor), nameOf(patient), key)
    end
    local btype = bloodType(patient)
    local bag = DB.findEmptyBag(doctor)
    local container = call(bag, "getContainer")
    local filled
    local okAdd = pcall(function() filled = doctor:getInventory():AddItem(DB.BAG_OF[btype]) end)
    if not okAdd or not filled then
        return refuse(doctor, L("No_Failed", "Something went wrong."), "%s: could not create %s", nameOf(doctor), tostring(DB.BAG_OF[btype]))
    end
    pcall(function() filled:setAge(0) end)
    pcall(function()
        local now = getGameTime() and getGameTime():getWorldAgeHours() or 0
        local md = filled:getModData()
        md.EHR_BloodSpoilage = { createdHour = now, lastCheckHour = now, warmElapsed = 0, stale = false, rotten = false, isFrozen = false }
        md.EHR_DonorBloodType = btype
        md.HM_DonorName = call(patient, "getUsername")
    end)
    if container then
        pcall(function() container:Remove(bag) end)
        if sendRemoveItemFromContainer then pcall(sendRemoveItemFromContainer, container, bag) end
    end
    if sendAddItemToContainer then pcall(sendAddItemToContainer, doctor:getInventory(), filled) end
    local before = bloodShare(patient) or 0
    if EHR and EHR.Blood and EHR.Blood.ModifyBloodVolume then
        pcall(EHR.Blood.ModifyBloodVolume, patient, -DB.AMOUNT)
    else
        local b = patient:getModData().EHR_Blood
        b.currentVolume = math.max(0, (tonumber(b.currentVolume) or 0) - DB.AMOUNT)
    end
    pcall(function()
        local st = patient:getStats()
        if st and CharacterStat and CharacterStat.FATIGUE then st:set(CharacterStat.FATIGUE, math.min(0.7, (st:get(CharacterStat.FATIGUE) or 0) + 0.15)) end
        if st and CharacterStat and CharacterStat.ENDURANCE then st:set(CharacterStat.ENDURANCE, math.max(0.3, (st:get(CharacterStat.ENDURANCE) or 1) - 0.2)) end
    end)
    if EHR and EHR.SafeTransmitModData then pcall(EHR.SafeTransmitModData, patient) end
    if EHR and EHR.Locale and EHR.Locale.SayAction then
        pcall(EHR.Locale.SayAction, patient, getText and getText("UI_EHR_DrawBlood_Complete") or "That made me lightheaded...")
    end
    if EHR and EHR.SkillXP and EHR.SkillXP.OnTransfusion then pcall(EHR.SkillXP.OnTransfusion, doctor, true) end
    tell(doctor, "Done", { bloodType = btype })
    tell(patient, "Donated", { doctorName = call(doctor, "getDisplayName") or "?" })
    log("%s drew %d mL from %s: blood %.0f%% -> %.0f%%, got %s (request %d)", nameOf(doctor), DB.AMOUNT, nameOf(patient),
        before * 100, (bloodShare(patient) or 0) * 100, tostring(DB.BAG_OF[btype]), id)
end

-- ------------------------------------------------------------- client
DB.pending = DB.pending or {}

local function say(p, text)
    if EHR and EHR.Locale and EHR.Locale.SayAction then pcall(EHR.Locale.SayAction, p, text)
    elseif p and p.Say then p:Say(text) end
end

function DB.ask(doctor, patient)
    if not doctor or not patient then return end
    log("asking the server: draw blood from %s", nameOf(patient))
    sendClientCommand(doctor, DB.MODULE, "Ask", { patientOnline = onlineId(patient) })
end

-- the patient's Yes / No
function DB.onConsent(args)
    local me = getPlayer and getPlayer()
    if not me or type(args) ~= "table" then return end
    if DB.modal then pcall(function() DB.modal:destroy() end); DB.modal = nil end
    local text = L("ConsentText", "%1 wants to draw your blood (%2 mL) into a blood bag.\nYour blood drops by about 10%%, and you feel weak for a while.\n\nDonate blood?",
        tostring(args.doctorName or "?"), tostring(args.amount or DB.AMOUNT))
    local core = getCore()
    local modal = ISModalDialog:new(math.floor(core:getScreenWidth() / 2 - 200), math.floor(core:getScreenHeight() / 2 - 80),
        400, 160, text, true, nil, function(_, button)
            local yes = button and button.internal == "YES"
            sendClientCommand(me, DB.MODULE, "Answer", { requestId = args.requestId, accepted = yes })
            log("answered %s's blood draw request: %s", tostring(args.doctorName), yes and "yes" or "no")
            DB.modal = nil
        end, me:getPlayerNum())
    modal:initialise()
    modal:addToUIManager()
    DB.modal = modal
    log("asked to donate blood by %s", tostring(args.doctorName))
end

if ISBaseTimedAction then
    HM_DrawBloodFromAction = ISBaseTimedAction:derive("HM_DrawBloodFromAction")
    function HM_DrawBloodFromAction:isValid()
        return alive(self.character) and alive(self.patient) and distance(self.character, self.patient) <= DB.RANGE + 0.5
            and DB.findEmptyBag(self.character) ~= nil
    end
    function HM_DrawBloodFromAction:update() if self.character.faceThisObject then self.character:faceThisObject(self.patient) end end
    function HM_DrawBloodFromAction:start()
        if self.character.setMetabolicTarget and Metabolics then pcall(function() self.character:setMetabolicTarget(Metabolics.LightWork) end) end
    end
    function HM_DrawBloodFromAction:stop()
        log("blood draw from %s stopped before the end (request %s)", nameOf(self.patient), tostring(self.requestId))
        ISBaseTimedAction.stop(self)
    end
    function HM_DrawBloodFromAction:perform()
        sendClientCommand(self.character, DB.MODULE, "Perform", { requestId = self.requestId })
        ISBaseTimedAction.perform(self)
    end
    function HM_DrawBloodFromAction:new(character, patient, requestId)
        local o = ISBaseTimedAction.new(self, character)
        o.patient, o.requestId = patient, requestId
        o.maxTime = DB.ACTION_TIME
        o.stopOnWalk, o.stopOnRun = true, true
        return o
    end
end

function DB.onServerCommand(module, command, args)
    if module ~= DB.MODULE then return end
    local me = getPlayer and getPlayer()
    args = type(args) == "table" and args or {}
    if command == "Consent" then DB.onConsent(args)
    elseif command == "Waiting" then say(me, L("Waiting", "Waiting for the patient to agree..."))
    elseif command == "Refused" then
        say(me, tostring(args.reason or L("No_Failed", "Something went wrong.")))
        log("blood draw refused: %s", tostring(args.reason))
    elseif command == "Granted" then
        local patient = byOnline(args.patientOnline)
        if patient and HM_DrawBloodFromAction then
            ISTimedActionQueue.add(HM_DrawBloodFromAction:new(me, patient, args.requestId))
            log("patient %s agreed -- drawing blood (request %s)", nameOf(patient), tostring(args.requestId))
        else
            log("consent arrived but the patient is not here (request %s)", tostring(args.requestId))
        end
    elseif command == "Done" then say(me, L("Done", "Got a bag of %1 blood.", tostring(args.bloodType)))
    elseif command == "Donated" then log("donated blood to %s", tostring(args.doctorName))
    end
end

-- right-click a player within range
local function onMenu(playerNum, context, worldobjects, test)
    if not (isClient and isClient()) then return end
    local me = getSpecificPlayer(playerNum)
    if not me or not (EHR and EHR.MPExamination and EHR.MPExamination.GetContextPlayerCandidates) then return end
    local ok, list = pcall(EHR.MPExamination.GetContextPlayerCandidates, me, worldobjects)
    if not ok or type(list) ~= "table" then return end
    for _, p in ipairs(list) do
        if p ~= me and alive(p) and distance(me, p) <= DB.RANGE + 0.5 then
            if test then return true end
            local name = call(p, "getDisplayName") or call(p, "getUsername") or "?"
            local hasBag = DB.findEmptyBag(me) ~= nil
            local opt = context:addOption(L("Option", "Draw blood (%1)", name), me, function() DB.ask(me, p) end)
            local tip = ISToolTip:new()
            tip:initialise()
            tip.description = L("Tooltip", "Draw %1 mL of this patient's blood into an empty blood bag. The patient must agree, have at least 80%% blood and stay close until it is done.",
                tostring(DB.AMOUNT))
            if not hasBag then
                opt.notAvailable = true
                tip.description = tip.description .. " <LINE> <RGB:1,0.3,0.3> " .. L("No_NoBag", "You need an empty blood bag.")
            end
            opt.toolTip = tip
        end
    end
end

if Events then
    if Events.OnClientCommand then
        Events.OnClientCommand.Add(function(module, command, player, args)
            if module ~= DB.MODULE then return end
            if command == "Ask" then DB.serverAsk(player, args)
            elseif command == "Answer" then DB.serverAnswer(player, args)
            elseif command == "Perform" then DB.serverPerform(player, args)
            else log("unknown command %s from %s", tostring(command), nameOf(player)) end
        end)
    end
    if Events.OnServerCommand then Events.OnServerCommand.Add(DB.onServerCommand) end
    if Events.OnFillWorldObjectContextMenu then
        Events.OnFillWorldObjectContextMenu.Add((HARMONIE_Ours or function(f) return f end)(onMenu, "HM"))
    end
end

return DB

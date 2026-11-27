--[[
    HARMONIE - How to Survive: stump care from the medical window (HTS 1.2.6)

    Owner 2026-11-24:
      "fit a prosthesis on someone else by right-clicking the blacked-out
       part of the cut limb" and "clean the stump from the body right-click
       -- players have to use the vanilla window for it now".

    1. HM_CleanStumpAction -- clean an unhealed stump (yourself or a
       patient). The Only Cure's own CleanWoundAction writes the result on
       the DOCTOR's client and sends it with UpdateDataControllerFromClient,
       which the server files under the SENDER's name: cleaning someone
       else's stump changed the doctor's data, not the patient's. This
       action does the work in complete() -- on the server in multiplayer,
       here in single player -- on the PATIENT's TOC data, then pushes it to
       the patient (dc:apply). Item: a disinfected bandage / rag (bandage
       power 2+ and alcoholic, TOC's own rule), carried by the doctor.
       Dirtiness falls by bandage power x 10 percent points (TOC's numbers);
       the arm's dirt and blood are washed off; Doctor XP 10.

    2. Fit a prosthesis on another player (multiplayer). The doctor picks a
       prosthesis he carries; the server checks distance, that the patient
       has a stump on that side and no prosthesis there yet, moves the item
       to the patient (as the side's own type) and tells the patient's game
       to wear it -- the patient's own ISWearClothing, so The Only Cure
       sets everything up the normal way. Logged at every step.
]]--

require "TimedActions/ISBaseTimedAction"

HM_StumpCare = HM_StumpCare or {}
local S = HM_StumpCare
S.MODULE = "HARMONIE_HM_Stump"
S.RANGE = 3

local function log(fmt, ...) if HMLog then HMLog("Stump", fmt, ...) end end
local function nameOf(p)
    local ok, n = pcall(function() return p:getUsername() end)
    return ok and tostring(n) or "?"
end
local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, r = pcall(o[m], o, ...)
    if ok then return r end
    return nil
end
local function dist(a, b)
    local ax, ay, bx, by = call(a, "getX"), call(a, "getY"), call(b, "getX"), call(b, "getY")
    if not (ax and ay and bx and by) then return 999 end
    if call(a, "getZ") ~= call(b, "getZ") then return 999 end
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end
S.dist = dist

local function toc()
    local okD, DC = pcall(require, "TOC/Controllers/DataController")
    local okS, SD = pcall(require, "TOC/StaticData")
    if okD and okS and type(DC) == "table" and type(SD) == "table" then return DC, SD end
    return nil, nil
end

-- TOC's cleaning rule: a disinfected bandage or rag
function S.isCleaner(item)
    if not item or not item.getBandagePower then return false end
    local okP, p = pcall(function() return item:getBandagePower() end)
    local okA, a = pcall(function() return item:isAlcoholic() end)
    return okP and okA and (tonumber(p) or 0) >= 2 and a == true
end

-- one entry per item type the doctor carries (inventory + bags): { item, count, name }
function S.carriedByType(doctor, pred)
    local out, byType = {}, {}
    local inv = call(doctor, "getInventory")
    if not inv then return out end
    local list = call(inv, "getAllEvalRecurse", function(it) return pred(it) end)
    for i = 0, (list and list:size() or 0) - 1 do
        local it = list:get(i)
        local ft = call(it, "getFullType") or "?"
        local e = byType[ft]
        if not e then
            e = { item = it, count = 0, name = call(it, "getName") or call(it, "getDisplayName") or ft }
            byType[ft] = e
            out[#out + 1] = e
        end
        e.count = e.count + 1
    end
    table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return out
end

local function findById(container, id)
    if not container or not id then return nil end
    for _, m in ipairs({ "getItemWithIDRecursiv", "getItemById", "getItemWithID" }) do
        local it = call(container, m, id)
        if it then return it end
    end
    return nil
end
S.findById = findById

-- ------------------------------------------------------------- clean action
HM_CleanStumpAction = ISBaseTimedAction:derive("HM_CleanStumpAction")

function HM_CleanStumpAction:isValid()
    if not self.character or not self.patient or not self.item then return false end
    if self.character ~= self.patient and dist(self.character, self.patient) > S.RANGE + 0.5 then return false end
    local inv = call(self.character, "getInventory")
    return inv ~= nil and call(inv, "containsRecursive", self.item) ~= false
end

function HM_CleanStumpAction:waitToStart()
    if self.character == self.patient then return false end
    self.character:faceThisObject(self.patient)
    return self.character:shouldBeTurning()
end

function HM_CleanStumpAction:update()
    if self.character ~= self.patient then self.character:faceThisObject(self.patient) end
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function HM_CleanStumpAction:start()
    if self.character == self.patient then
        self:setActionAnim(CharacterActionAnims.Bandage)
    else
        self:setActionAnim("Loot")
        self.character:SetVariable("LootPosition", "Mid")
    end
    self:setOverrideHandModels(nil, nil)
end

function HM_CleanStumpAction:stop()
    ISBaseTimedAction.stop(self)
end

-- the real work: where TOC's data lives (server in MP, here in SP)
function HM_CleanStumpAction:complete()
    local DC = toc()
    local patient = self.patient
    local doctor = self.character
    local limb = self.limb
    local dc = DC and patient and DC.GetInstance(nameOf(patient))
    if not dc then
        log("clean %s for %s: no TOC data on this side -- nothing changed", tostring(limb), nameOf(patient))
        return true
    end
    if not call(dc, "getIsCut", limb) or call(dc, "getIsCicatrized", limb) then
        log("clean %s for %s: no unhealed stump there -- nothing changed", tostring(limb), nameOf(patient))
        return true
    end
    local item = self.item
    local power = tonumber(call(item, "getBandagePower")) or 2
    local before = tonumber(call(dc, "getWoundDirtyness", limb)) or 0
    local after = math.max(0, before - power * 0.1)
    dc:setWoundDirtyness(limb, after)
    -- the item: one use
    if item then
        if item.UseAndSync then pcall(function() item:UseAndSync() end)
        else pcall(function() item:Use() end) end
    end
    -- the arm's dirt and blood come off
    pcall(function()
        local bb = BloodBodyPartType[limb]
        local visual = patient:getHumanVisual()
        visual:setDirt(bb, 0)
        visual:setBlood(bb, 0)
        if sendVisual then sendVisual(patient) end
    end)
    pcall(function()
        if addXp then addXp(doctor, Perks.Doctor, 10) else doctor:getXp():AddXP(Perks.Doctor, 10) end
    end)
    pcall(function() dc:apply(patient) end)
    log("%s cleaned %s's %s stump: dirtiness %.2f -> %.2f (bandage power %s)", nameOf(doctor), nameOf(patient), tostring(limb), before, after, tostring(power))
    return true
end

function HM_CleanStumpAction:perform()
    ISBaseTimedAction.perform(self)
end

-- character = doctor; patient = IsoPlayer; item = the cleaner; limb = TOC limb name
function HM_CleanStumpAction:new(character, patient, item, limb)
    local o = ISBaseTimedAction.new(self, character)
    o.patient = patient
    o.item = item
    o.limb = limb
    o.stopOnWalk = true
    o.stopOnRun = true
    o.forceProgressBar = true
    local lvl = tonumber(call(character, "getPerkLevel", Perks.Doctor)) or 0
    o.maxTime = character:isTimedActionInstant() and 1 or (250 - lvl * 6)
    return o
end

-- client: bring the item into the main inventory, then clean
function S.queueClean(doctor, patient, item, limb)
    if not doctor or not patient or not item or not limb then return end
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then
        pcall(ISInventoryPaneContextMenu.transferIfNeeded, doctor, item)
    end
    ISTimedActionQueue.add(HM_CleanStumpAction:new(doctor, patient, item, limb))
    log("%s starts cleaning %s's %s stump with %s", nameOf(doctor), nameOf(patient), tostring(limb), tostring(call(item, "getFullType")))
end

-- ------------------------------------------------- fit on another player
-- client (doctor)
function S.requestFit(doctor, patient, item, side)
    if not (isClient and isClient()) then log("fit on another player: multiplayer only"); return end
    local pid = call(patient, "getOnlineID")
    local iid = call(item, "getID")
    if not pid or not iid then return end
    log("%s asks to fit %s on %s (%s arm)", nameOf(doctor), tostring(call(item, "getFullType")), nameOf(patient), tostring(side))
    sendClientCommand(doctor, S.MODULE, "Fit", { patient = pid, item = iid, side = side })
end

local function refuse(doctor, why)
    log("fit refused for %s: %s", nameOf(doctor), why)
    if sendServerCommand then sendServerCommand(doctor, S.MODULE, "Refused", { why = why }) end
end

-- server
function S.serverFit(doctor, args)
    local patient = getPlayerByOnlineID and getPlayerByOnlineID(tonumber(args.patient) or -1)
    if not patient or call(patient, "isDead") then return refuse(doctor, "noPatient") end
    if patient == doctor then return refuse(doctor, "self") end
    if dist(doctor, patient) > S.RANGE + 0.5 then return refuse(doctor, "far") end
    local inv = call(doctor, "getInventory")
    local item = findById(inv, tonumber(args.item))
    local okP, Prost = pcall(require, "TOC/Handlers/ProsthesisHandler")
    if not item or not okP or not Prost or not Prost.CheckIfProst(item) then return refuse(doctor, "noItem") end
    local side = (args.side == "L") and "L" or "R"
    local target = call(item, "getFullType"):gsub("_[LR]$", "_" .. side)
    if not Prost.CheckIfEquippable(target, patient) then return refuse(doctor, "noStump") end
    local DC, SD = toc()
    local dc = DC and DC.GetInstance(nameOf(patient))
    if dc and SD then
        local group = SD.AMP_GROUPS_IND_STR and SD.AMP_GROUPS_IND_STR["Top_" .. side]
        local okE, worn = pcall(function() return group and dc:getIsProstEquipped(group) end)
        if okE and worn then return refuse(doctor, "already") end
    end
    -- move it: off the doctor, a fresh one of the side's type to the patient
    local from = call(item, "getContainer") or inv
    pcall(function() from:Remove(item) end)
    if sendRemoveItemFromContainer then pcall(sendRemoveItemFromContainer, from, item) end
    local pinv = patient:getInventory()
    local given = pinv:AddItem(target)
    if not given then
        -- put it back
        pcall(function() from:AddItem(item) end)
        if sendAddItemToContainer then pcall(sendAddItemToContainer, from, item) end
        return refuse(doctor, "noItem")
    end
    if sendAddItemToContainer then pcall(sendAddItemToContainer, pinv, given) end
    log("%s fitted %s on %s: item moved (new id %s), asking the patient's game to wear it", nameOf(doctor), target, nameOf(patient), tostring(call(given, "getID")))
    sendServerCommand(patient, S.MODULE, "Wear", { id = call(given, "getID"), by = nameOf(doctor) })
    sendServerCommand(doctor, S.MODULE, "Done", { who = nameOf(patient) })
end

-- client (patient): wear it once the item has arrived
S.pendingWear = S.pendingWear or nil
local function tryWear()
    local w = S.pendingWear
    if not w then return end
    local p = getPlayer and getPlayer()
    local it = p and findById(p:getInventory(), w.id)
    if it then
        S.pendingWear = nil
        ISTimedActionQueue.add(ISWearClothing:new(p, it, 50))
        log("wearing the prosthesis %s fitted (id %s)", tostring(w.by), tostring(w.id))
        if HaloTextHelper and HaloTextHelper.addText then
            pcall(HaloTextHelper.addText, p, (getText and getText("UI_HomeMedic_Stump_FittedBy", tostring(w.by))) or tostring(w.by))
        end
        return
    end
    w.tries = (w.tries or 0) + 1
    if w.tries > 300 then
        log("prosthesis id %s never arrived -- not worn", tostring(w.id))
        S.pendingWear = nil
    end
end

if Events then
    if Events.OnClientCommand then
        Events.OnClientCommand.Add(function(module, command, player, args)
            if module ~= S.MODULE then return end
            if command == "Fit" then pcall(S.serverFit, player, args or {})
            else log("unknown command %s from %s", tostring(command), nameOf(player)) end
        end)
    end
    if Events.OnServerCommand then
        Events.OnServerCommand.Add(function(module, command, args)
            if module ~= S.MODULE then return end
            args = args or {}
            local p = getPlayer and getPlayer()
            if command == "Wear" then
                S.pendingWear = { id = args.id, by = args.by, tries = 0 }
            elseif command == "Refused" then
                log("the server refused the fit: %s", tostring(args.why))
                if p and p.Say then p:Say(getText("UI_HomeMedic_Stump_No_" .. tostring(args.why))) end
            elseif command == "Done" then
                if p and HaloTextHelper and HaloTextHelper.addText then
                    pcall(HaloTextHelper.addText, p, getText("UI_HomeMedic_Stump_FitDone", tostring(args.who)))
                end
            end
        end)
    end
    if Events.OnTick then Events.OnTick.Add(function() if S.pendingWear then tryWear() end end) end
end

return S

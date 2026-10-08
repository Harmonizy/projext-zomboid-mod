--[[
    HARMONIE - Home Medic : put your medical monitor watch on the patient

    Request 2026-10-02: while examining someone, a button puts a medical
    monitor watch from the doctor's inventory onto the patient's wrist, so
    the Body Stats tab (which needs a powered watch ON THE PATIENT) opens.

    The server does the move (MP: dedicated server; SP: same Lua state):
      - the doctor and the patient within D.MAX_DISTANCE, both alive
      - the watch is a medical watch in the doctor's inventory (bags too),
        with battery left; a powered one is preferred
      - not when the patient already wears a powered one
    It leaves the doctor's inventory (sendRemoveItemFromContainer), goes
    into the patient's (sendAddItemToContainer) and is worn on its own
    wrist (setWornItem + sendClothing, which every client sees). Whatever
    the patient wore on that wrist stays in the patient's inventory.
]]--

HM_WatchGive = HM_WatchGive or {}
local W = HM_WatchGive
W.MODULE = "HARMONIE_HM_Watch"

local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end

function W.isWatch(item)
    local B = EHR and EHR.WatchBattery
    return item ~= nil and B ~= nil and B.IsMedicalWatch(item) == true
end

function W.powered(item)
    local B = EHR and EHR.WatchBattery
    if not B or not B.IsPowered then return true end
    local ok, v = pcall(B.IsPowered, item)
    return ok and v == true
end

-- does the patient wear a powered medical watch?
function W.wearing(patient)
    local B = EHR and EHR.WatchBattery
    if not B or not B.PlayerHasPoweredWatch then return false end
    local ok, v = pcall(B.PlayerHasPoweredWatch, patient)
    return ok and v == true
end

local function isWorn(player, item)
    local worn = call(player, "getWornItems")
    local n = worn and call(worn, "size") or 0
    for i = 0, n - 1 do
        if call(worn, "getItemByIndex", i) == item then return true end
    end
    return false
end

-- every medical watch the doctor carries but does not wear:
-- { { item, container, powered } }, powered ones first
function W.watchesOf(doctor)
    local out = {}
    local seen = {}
    local function scan(container, depth)
        if not container or seen[container] or depth > 3 then return end
        seen[container] = true
        local items = call(container, "getItems")
        local n = items and call(items, "size") or 0
        for i = 0, n - 1 do
            local it = call(items, "get", i)
            if it then
                if W.isWatch(it) and not isWorn(doctor, it) then
                    out[#out + 1] = { item = it, container = container, powered = W.powered(it) }
                end
                local inner = call(it, "getInventory")
                if inner then scan(inner, depth + 1) end
            end
        end
    end
    scan(call(doctor, "getInventory"), 0)
    table.sort(out, function(a, b) return a.powered and not b.powered end)
    return out
end

local function distance(a, b)
    if a == b then return 0 end
    local ax, ay, bx, by = call(a, "getX"), call(a, "getY"), call(b, "getX"), call(b, "getY")
    if not (ax and ay and bx and by) then return 999 end
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- -> ok, reason ("Done", "NoWatch", "NoBattery", "TooFar", "Already", "Invalid")
function W.give(doctor, patient, itemID)
    if not doctor or not patient or doctor == patient then return false, "Invalid" end
    if call(doctor, "isDead") or call(patient, "isDead") then return false, "Invalid" end
    local maxD = HM_Diagnosis and HM_Diagnosis.MAX_DISTANCE or 3
    if distance(doctor, patient) > maxD then return false, "TooFar" end
    if W.wearing(patient) then return false, "Already" end
    local list = W.watchesOf(doctor)
    local pick
    for _, e in ipairs(list) do
        if itemID == nil or tostring(call(e.item, "getID")) == tostring(itemID) then pick = e; break end
    end
    if not pick then pick = list[1] end
    if not pick then return false, "NoWatch" end
    if not pick.powered then return false, "NoBattery" end
    local item, from = pick.item, pick.container
    local inv = call(patient, "getInventory")
    local loc = call(item, "getBodyLocation")
    if not inv or not loc then return false, "Invalid" end

    local server = isServer and isServer()
    call(from, "Remove", item)
    if server and sendRemoveItemFromContainer then pcall(sendRemoveItemFromContainer, from, item) end
    call(inv, "AddItem", item)
    if server and sendAddItemToContainer then pcall(sendAddItemToContainer, inv, item) end
    local ok = pcall(function() patient:setWornItem(loc, item) end)
    if not ok then return false, "Invalid" end
    if server and sendClothing then pcall(sendClothing, patient, loc, item) end
    if server and syncVisuals then pcall(syncVisuals, patient) end
    return true, "Done"
end

-- ------------------------------------------------------------- network
local function findOnline(id)
    id = tonumber(id)
    if not id then return nil end
    local online = getOnlinePlayers and getOnlinePlayers()
    for i = 0, (online and online:size() or 0) - 1 do
        local p = online:get(i)
        if p and call(p, "getOnlineID") == id then return p end
    end
    return nil
end

-- server side of a request (or the same Lua state in single player)
function W.serve(doctor, args)
    args = type(args) == "table" and args or {}
    local patient
    if isServer and isServer() then
        patient = findOnline(args.patientOnline)
    else
        patient = getSpecificPlayer and getSpecificPlayer(tonumber(args.patientNum) or 0)
    end
    local ok, reason = W.give(doctor, patient, args.itemID)
    HMLog("Watch", "%s putting a watch (item %s) on %s: %s (%s)", HMLogName(doctor), tostring(args.itemID), HMLogName(patient), ok and "done" or "REFUSED", tostring(reason))
    local res = { ok = ok, reason = reason }
    if isServer and isServer() then
        if sendServerCommand then sendServerCommand(doctor, W.MODULE, "Result", res) end
    elseif W.onResult then
        W.onResult(res)
    end
    return ok, reason
end

-- client: ask for it (doctor = this client's player)
function W.request(doctor, patient, itemID)
    if not doctor or not patient then return end
    HMLog("Watch", "asking to put watch %s on %s", tostring(itemID), HMLogName(patient))
    if isClient and isClient() then
        sendClientCommand(doctor, W.MODULE, "Give", { patientOnline = call(patient, "getOnlineID"), itemID = itemID })
    else
        W.serve(doctor, { patientNum = call(patient, "getPlayerNum") or 0, itemID = itemID })
    end
end

if Events and not W.registered then
    W.registered = true
    if Events.OnClientCommand then
        Events.OnClientCommand.Add(function(module, command, player, args)
            if module == W.MODULE and command == "Give" and player then W.serve(player, args) end
        end)
    end
    if Events.OnServerCommand then
        Events.OnServerCommand.Add(function(module, command, args)
            if module == W.MODULE and command == "Result" then
                HMLog("Watch", "server answer: %s (%s)", (args and args.ok) and "done" or "refused", tostring(args and args.reason))
                if W.onResult then W.onResult(args or {}) end
            end
        end)
    end
end

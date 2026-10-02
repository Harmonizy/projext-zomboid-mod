--[[
    HARMONIE - Home Medic : surgery system core (shared: client + server)

    * Sources   -- supplies are found on the doctor (bags too), on the floor
                   and in any container within S.REACH tiles (request: "การใช้
                   อุปกรณ์หรือวัตถุดิบให้สามารถดูบนพื้นหรือในกล่องรอบตัวและใน
                   inventory ได้"). The server consumes from wherever they are.
    * Unlocks   -- a procedure needs First Aid at its tier and, if it lists
                   diseases, EHR knowledge of one of them.
    * Indication-- what the operation would treat on this body part.
    * Readiness -- one row per check (indication, skill, each supply,
                   asepsis, anesthesia, blood, distance, cooldown) for the
                   "pre-op" window; the server runs the same checks again.
    * Quality   -- step scores (0..1 from the minigames) x tool quality.
    Pure data / questions only; changes happen in server/HARMONIEHomeMedic/HM_SurgeryServer.lua.
]]--

require "HARMONIEHomeMedic/HM_Text"
require "HARMONIEHomeMedic/Surgery/HM_SurgeryData"

local S = HM_Surgery

-- ---------------------------------------------------------------- text
function S.T(key, fallback, ...)
    return HM_Text("UI_HomeMedic_Surg_" .. key, fallback or key, ...)
end

local function now() return getGameTime and getGameTime():getWorldAgeHours() or 0 end

local function call(obj, method, ...)
    if not obj or not obj[method] then return nil end
    local ok, v = pcall(obj[method], obj, ...)
    if ok then return v end
    return nil
end

-- ---------------------------------------------------------------- text wrap (client)
-- Wraps at spaces, and inside a "word" wider than the line at character
-- boundaries -- Thai writes whole sentences without spaces.
-- Honours "\n" and EHR's "<LINE>". -> list of lines
--
-- Kahlua strings are Java strings: there string.byte returns the UTF-16
-- code (a Thai letter is ONE char, code ~3600), while plain Lua sees the
-- UTF-8 bytes (three). Byte-class patterns like "[\194-\244][\128-\191]*"
-- never match in Kahlua, so a "drop the last char" gsub would not shorten
-- the text and a truncation loop would never end (game freeze). These
-- helpers work in both.

-- length of the character starting at i
local function charLen(s, i)
    local b = s:byte(i)
    if not b or b < 192 or b > 247 then return 1 end
    local n = b >= 240 and 4 or (b >= 224 and 3 or 2)
    for k = 1, n - 1 do
        local c = s:byte(i + k)
        if not c or c < 128 or c > 191 then return 1 end
    end
    return n
end

-- the text without its last character; always shorter (never loops)
function S.dropLast(text)
    text = tostring(text or "")
    local len = #text
    if len <= 1 then return "" end
    local cut = len
    while cut > 1 do
        local b = text:byte(cut)
        if not b or b < 128 or b >= 192 then break end
        cut = cut - 1
    end
    if cut < len and charLen(text, cut) ~= len - cut + 1 then cut = len end
    return text:sub(1, cut - 1)
end

-- text cut to maxW pixels with "..." (measure(text) -> width)
function S.fitText(text, maxW, measure, suffix)
    text = tostring(text or "")
    suffix = suffix or "..."
    if measure(text) <= maxW then return text end
    local guard = #text + 1
    while #text > 0 and guard > 0 and measure(text .. suffix) > maxW do
        text = S.dropLast(text)
        guard = guard - 1
    end
    return text .. suffix
end

local function codepoint(ch)
    local a, b, c = ch:byte(1, 3)
    if not a then return 0 end
    if a > 255 then return a end                       -- Kahlua: already a code
    if a >= 224 and a < 240 and b and c then
        return (a - 224) * 4096 + (b - 128) * 64 + (c - 128)
    end
    return a
end
-- Thai marks that sit on the previous letter (U+0E31, U+0E33-0E3A, U+0E47-0E4E)
local function attaches(ch)
    local cp = codepoint(ch)
    return cp == 0x0E31 or (cp >= 0x0E33 and cp <= 0x0E3A) or (cp >= 0x0E47 and cp <= 0x0E4E)
end
-- iterator over display clusters (a letter plus its marks)
function S.clusters(word)
    local list = {}
    local i, n = 1, #word
    while i <= n do
        local l = charLen(word, i)
        local ch = word:sub(i, i + l - 1)
        if #list > 0 and attaches(ch) then list[#list] = list[#list] .. ch else list[#list + 1] = ch end
        i = i + l
    end
    local k = 0
    return function() k = k + 1; return list[k] end
end

function S.wrap(text, width, font)
    local tm = getTextManager()
    local function w(t) return tm:MeasureStringX(font or UIFont.Small, t) end
    local lines = {}
    text = tostring(text or ""):gsub("<LINE>", "\n"):gsub("\r\n", "\n")
    for para in (text .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in para:gmatch("%S+") do
            local test = line == "" and word or (line .. " " .. word)
            if w(test) <= width then
                line = test
            else
                if line ~= "" then lines[#lines + 1] = line; line = "" end
                if w(word) <= width then
                    line = word
                else
                    for ch in S.clusters(word) do
                        if line ~= "" and w(line .. ch) > width then lines[#lines + 1] = line; line = ch
                        else line = line .. ch end
                    end
                end
            end
        end
        lines[#lines + 1] = line
    end
    while #lines > 0 and lines[#lines] == "" do lines[#lines] = nil end
    return lines
end

-- ---------------------------------------------------------------- sources
S.Sources = S.Sources or {}
local Src = S.Sources

local function collect(player)
    local conts, floor = {}, {}
    local inv = call(player, "getInventory")
    if inv then conts[#conts + 1] = { c = inv, where = "inv" } end
    local sq = call(player, "getCurrentSquare")
    local cell = getCell and getCell()
    if sq and cell and S.REACH > 0 then
        local x, y, z = sq:getX(), sq:getY(), sq:getZ()
        for dx = -S.REACH, S.REACH do
            for dy = -S.REACH, S.REACH do
                local s = cell:getGridSquare(x + dx, y + dy, z)
                if s then
                    local objs = s:getObjects()
                    for i = 0, objs:size() - 1 do
                        local o = objs:get(i)
                        local n = o and call(o, "getContainerCount") or 0
                        for k = 0, n - 1 do
                            local c = call(o, "getContainerByIndex", k)
                            if c then conts[#conts + 1] = { c = c, where = "box" } end
                        end
                    end
                    local w = call(s, "getWorldObjects")
                    if w then
                        for i = 0, w:size() - 1 do
                            local it = call(w:get(i), "getItem")
                            if it then floor[#floor + 1] = it end
                        end
                    end
                end
            end
        end
    end
    return { conts = conts, floor = floor }
end

local cache = {}
function Src.get(player)
    local client = not (isServer and isServer())
    local t = getTimestampMs and getTimestampMs() or 0
    local c = client and cache[player]
    if c and t - c.at < 500 then return c.src end
    local src = collect(player)
    if client then cache[player] = { at = t, src = src } end
    return src
end
function Src.forget(player) if player then cache[player] = nil else cache = {} end end

-- every item: fn(item, where) -- bags inside containers too (3 deep); stop when fn returns true
function Src.each(src, fn)
    local function walk(cont, where, depth)
        local items = cont and call(cont, "getItems")
        if not items then return false end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then
                if fn(it, where) then return true end
                if depth < 3 and instanceof and instanceof(it, "InventoryContainer") then
                    if walk(it:getInventory(), where, depth + 1) then return true end
                end
            end
        end
        return false
    end
    for _, c in ipairs(src.conts) do
        if walk(c.c, c.where, 0) then return end
    end
    for _, it in ipairs(src.floor) do
        if fn(it, "floor") then return end
    end
end

-- ---------------------------------------------------------------- item tests
local function fullType(it) return call(it, "getFullType") or "" end
local function isBroken(it) return call(it, "isBroken") == true end

local function hasUses(it)
    if call(it, "IsDrainable") then
        local u = call(it, "getCurrentUsesFloat")
        if u ~= nil then return u > 0.001 end
        u = call(it, "getCurrentUses")
        if u ~= nil then return u > 0 end
    end
    return true
end

local function lowType(it) return (call(it, "getType") or ""):lower() end
local function has(it, word) return lowType(it):find(word, 1, true) ~= nil end

local MATCH = {
    scalpel = function(it) return has(it, "scalpel") end,
    razor = function(it) return has(it, "razor") end,
    blade = function(it) return has(it, "blade") and not has(it, "saw") end,
    tweezers = function(it) return has(it, "tweezer") end,
    pliers = function(it) return has(it, "pliers") end,
    suture = function(it) return has(it, "sutureneedle") and not has(it, "holder") end,
    thread = function(it) return has(it, "thread") end,
    rag = function(it) local t = lowType(it); return t == "rippedsheets" or t == "rag" or t == "denimstrips" end,
    syringe = function(it) return has(it, "syringe") and not has(it, "empty") end,
    saline = function(it) return has(it, "saline") end,
    bloodbag = function(it)
        local B = EHR and EHR.Blood
        if B and B.BloodBagTypes and B.BloodBagTypes[call(it, "getFullType") or ""] then return true end
        return has(it, "bloodbag") and not has(it, "empty")
    end,
    knife = function(it)
        local ty = (call(it, "getType") or ""):lower()
        return ty:find("knife", 1, true) ~= nil and not ty:find("butter", 1, true)
    end,
    bandage = function(it)
        return call(it, "isCanBandage") == true or (tonumber(call(it, "getBandagePower")) or 0) > 0
    end,
    disinfectant = function(it)
        -- same test as EHR's health panel: a fluid that is >= 40% alcohol, or an old-style alcohol drainable
        local fc = call(it, "getFluidContainer")
        if fc then
            local amount = tonumber(call(fc, "getAmount")) or 0
            if amount <= 0.15 then return false end
            local props = call(fc, "getProperties")
            local alcohol = tonumber(props and call(props, "getAlcohol")) or 0
            return (alcohol / amount + 0.001) >= 0.4
        end
        return call(it, "IsDrainable") == true and tonumber(call(it, "getAlcoholPower")) == 4.0
    end,
}

local function optionMatches(opt, it)
    if isBroken(it) or not hasUses(it) then return false end
    if opt.type then return fullType(it) == opt.type end
    return opt.match and MATCH[opt.match] and MATCH[opt.match](it) or false
end

local function findType(src, t)
    local found, where
    Src.each(src, function(it, w)
        if fullType(it) == t and not isBroken(it) then found, where = it, w; return true end
    end)
    return found, where
end

-- Best option for a supply slot: { slot, opt, item, where, need, needWhere, q } or nil
function S.donorType(it)
    local B = EHR and EHR.Blood
    return B and B.BloodBagTypes and B.BloodBagTypes[fullType(it)] or nil
end

function S.compatible(donor, recipient)
    local B = EHR and EHR.Blood
    if not donor or not recipient or not B or not B.IsCompatible then return false end
    local ok, r = pcall(B.IsCompatible, donor, recipient)
    return ok and r == true
end

function S.fillSlot(src, slotId, recipientType)
    local slot = S.Supplies[slotId]
    if not slot then return nil end
    if slot.transfusion == "blood" then
        -- prefer a bag the patient can take
        local any
        local best
        Src.each(src, function(it, w)
            if optionMatches(slot.options[1], it) then
                local f = { slot = slotId, opt = slot.options[1], item = it, where = w, q = 1, donor = S.donorType(it) }
                f.compatible = S.compatible(f.donor, recipientType)
                any = any or f
                if f.compatible then best = f; return true end
            end
        end)
        return best or any
    end
    for _, opt in ipairs(slot.options) do
        local item, where
        Src.each(src, function(it, w)
            if optionMatches(opt, it) then item, where = it, w; return true end
        end)
        if item then
            local need, needWhere
            if opt.needs then need, needWhere = findType(src, opt.needs) end
            if not opt.needs or need then
                return { slot = slotId, opt = opt, item = item, where = where, need = need, needWhere = needWhere, q = opt.q or 1 }
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- people
function S.firstAid(player)
    if not player or not Perks or not Perks.Doctor then return 0 end
    return tonumber(call(player, "getPerkLevel", Perks.Doctor)) or 0
end

function S.knows(player, diseaseId)
    local F = EHR and EHR.DiseaseFlyers
    if F and F.HasMedicalKnowledge then
        local ok, r = pcall(F.HasMedicalKnowledge, player, diseaseId, 8)
        if ok then return r == true end
    end
    return S.firstAid(player) >= 8
end

-- procedure unlocked for `doctor`? -> ok, needFirstAid, missingKnowledge(list or nil)
function S.procedureUnlocked(doctor, pid)
    local p = S.Procedures[pid]
    if not p or p.planned then return false, 99, nil end
    local need = S.TIERS[p.tier].firstAid
    local fa = S.firstAid(doctor)
    local knowOk = true
    if p.knowledge then
        knowOk = false
        for _, id in ipairs(p.knowledge) do
            if S.knows(doctor, id) then knowOk = true; break end
        end
    end
    return fa >= need and knowOk, need, (not knowOk) and p.knowledge or nil
end

function S.tocAvailable()
    return SetHealthPanelTOC ~= nil or (TOC_DEBUG ~= nil)
end

-- -> ok, reasonKey ("Tier" | "Knowledge" | "Steps" | "TOC")
function S.surgeryUnlocked(doctor, sid)
    local s = S.Surgeries[sid]
    if not s or s.planned then return false, "Unknown" end
    if s.needsTOC and not S.tocAvailable() then return false, "TOC" end
    if S.firstAid(doctor) < S.TIERS[s.tier].firstAid then return false, "Tier" end
    if s.knowledge then
        local ok = false
        for _, id in ipairs(s.knowledge) do
            if S.knows(doctor, id) then ok = true; break end
        end
        if not ok then return false, "Knowledge" end
    end
    for _, pid in ipairs(s.steps) do
        if not S.procedureUnlocked(doctor, pid) then return false, "Steps" end
    end
    return true
end

-- ---------------------------------------------------------------- body part
function S.partName(bodyPart)
    local t = call(bodyPart, "getType")
    if not t then return nil end
    if BodyPartType and BodyPartType.ToString then
        local ok, s = pcall(BodyPartType.ToString, t)
        if ok and s then return s end
    end
    return tostring(t)
end

function S.partByName(patient, name)
    local bd = call(patient, "getBodyDamage")
    if not bd or not name or not BodyPartType or not BodyPartType.FromString then return nil end
    local ok, t = pcall(BodyPartType.FromString, name)
    if not ok or not t then return nil end
    return call(bd, "getBodyPart", t)
end

function S.hasWound(bodyPart)
    for _, m in ipairs(S.WOUND_METHODS) do
        if call(bodyPart, m) == true then return true end
    end
    return false
end

-- ---------------------------------------------------------------- indication
-- `exam` (optional): the snapshot EHR's remote health panel keeps for a
-- patient on another machine (their ModData is not synced to our client).
local function modData(patient, exam, key)
    if exam and exam[key] ~= nil then return exam[key] end
    local md = call(patient, "getModData")
    return md and md[key]
end

-- the patient's blood type (EHR), from the exam snapshot for another player
function S.bloodType(patient, exam)
    local b = modData(patient, exam, "EHR_Blood")
    local t = type(b) == "table" and b.bloodType or nil
    if t == "PENDING" then return nil end
    return t
end


-- Stage of a disease (0 = not active). Sepsis lives in its own module.
function S.stageOf(patient, id, exam)
    if id == "sepsis" then
        local d = modData(patient, exam, "EHR_Sepsis")
        if type(d) == "table" and (d.active == true or (tonumber(d.stage) or 0) > 0) then return tonumber(d.stage) or 0 end
        return 0
    end
    local data = modData(patient, exam, "EHR_Disease")
    local d = type(data) == "table" and data.active and data.active[id]
    return d and (tonumber(d.stage) or 1) or 0
end

-- The table holding a disease's state (where the hold flag lives).
function S.diseaseEntry(patient, id)
    local md = call(patient, "getModData")
    if not md then return nil end
    if id == "sepsis" then
        local d = md.EHR_Sepsis
        if type(d) == "table" and (tonumber(d.stage) or 0) > 0 then return d end
        return nil
    end
    return md.EHR_Disease and md.EHR_Disease.active and md.EHR_Disease.active[id] or nil
end

function S.isHeld(patient, id, exam)
    if id == "sepsis" then
        local d = modData(patient, exam, "EHR_Sepsis")
        return type(d) == "table" and d.harmonieHold ~= nil
    end
    local data = modData(patient, exam, "EHR_Disease")
    local d = type(data) == "table" and data.active and data.active[id]
    return type(d) == "table" and d.harmonieHold ~= nil
end

function S.needsSurgery(patient, id, exam)
    local from = S.SURGICAL[id]
    return from ~= nil and S.stageOf(patient, id, exam) >= from
end

local function woundInfectionStage(patient, bodyPart, exam)
    local name = S.partName(bodyPart)
    local data = modData(patient, exam, "EHR_WoundInfection")
    local pd = type(data) == "table" and data.parts and data.parts[name]
    local stage = pd and tonumber(pd.stage) or 0
    if stage <= 0 and call(bodyPart, "isInfectedWound") == true then stage = 1 end
    return stage
end

local function inList(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end

-- TOC limb name of a body part (nil if not an arm part TOC handles)
function S.tocLimb(bodyPart)
    local ok, SD = pcall(require, "TOC/StaticData")
    local name = S.partName(bodyPart)
    return ok and SD and SD.LIMBS_IND_STR and name and SD.LIMBS_IND_STR[name] or nil
end

local function tocIsCut(patient, limb)
    local ok, DC = pcall(require, "TOC/Controllers/DataController")
    local inst = ok and DC and DC.GetInstance and DC.GetInstance(call(patient, "getUsername") or "")
    return inst and inst.getIsCut and inst:getIsCut(limb) == true or false
end

-- Special targets
local SPECIAL = {}
function SPECIAL.wound_infection(patient, part, exam)
    local st = woundInfectionStage(patient, part, exam)
    return st > 0 and st or nil
end
function SPECIAL.foreign_body(patient, part)
    if call(part, "haveBullet") == true or call(part, "haveGlass") == true then return 1 end
    return nil
end
function SPECIAL.knox(patient)
    local K = EHR and EHR.KnoxCure
    if K and K.IsInfected then
        local ok, r = pcall(K.IsInfected, patient)
        if ok and r then return 1 end
    end
    return nil
end
function SPECIAL.knox_bite(patient, part)
    local limb = S.tocLimb(part)
    if not limb or tocIsCut(patient, limb) then return nil end
    local ok, SD = pcall(require, "TOC/StaticData")
    local parts = { part }
    local deps = ok and SD and SD.LIMBS_DEPENDENCIES_IND_STR and SD.LIMBS_DEPENDENCIES_IND_STR[limb] or {}
    for _, d in ipairs(deps) do parts[#parts + 1] = S.partByName(patient, d) end
    for _, p in ipairs(parts) do
        if p and (call(p, "bitten") == true or call(p, "IsInfected") == true) then return 1 end
    end
    return nil
end
function SPECIAL.necrosis(patient, part, exam)
    local limb = S.tocLimb(part)
    if not limb or tocIsCut(patient, limb) then return nil end
    if woundInfectionStage(patient, part, exam) >= 3 then return 3 end
    return nil
end

-- Conditions this operation would treat through this body part.
-- -> list of { id, stage, cool = hours left or nil, held = bool, needs = bool }
function S.indications(patient, bodyPart, sid, exam)
    local s = S.Surgeries[sid]
    local out = {}
    if not s or not patient or not bodyPart then return out end
    local pname = S.partName(bodyPart)
    if s.parts and not inList(s.parts, pname) then return out end
    local wound = S.hasWound(bodyPart)
    for id, t in pairs(s.targets) do
        local stage
        if SPECIAL[id] then
            stage = SPECIAL[id](patient, bodyPart, exam)
        elseif wound or t.anyPart then
            stage = S.stageOf(patient, id, exam)
            if stage <= 0 then stage = nil end
        end
        if stage then
            -- no operation for an illness nobody has diagnosed yet (HM_Diagnosis)
            local D = HM_Diagnosis
            local did = (id == "knox") and "knox_infection" or id
            local undiagnosed = D and D.gated and D.gated(did) and not D.isDiagnosed(patient, did, exam) or nil
            out[#out + 1] = { id = id, stage = stage, cool = S.cooldownLeft(patient, id, bodyPart),
                held = S.isHeld(patient, id, exam), needs = S.needsSurgery(patient, id, exam),
                undiagnosed = undiagnosed }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- A patient on another machine whose data we cannot see: the server checks.
function S.isRemote(doctor, patient)
    return doctor ~= patient and isClient and isClient() and call(patient, "isLocalPlayer") ~= true
end

-- ---------------------------------------------------------------- cooldown
function S.coolKey(id, bodyPart)
    if id == "wound_infection" then return id .. ":" .. tostring(S.partName(bodyPart)) end
    return id
end

function S.cooldownLeft(patient, id, bodyPart)
    local md = call(patient, "getModData")
    local c = md and md.HARMONIE_Surgery and md.HARMONIE_Surgery.cool
    local last = c and tonumber(c[S.coolKey(id, bodyPart)])
    if not last then return nil end
    local left = S.COOLDOWN_HOURS - (now() - last)
    if left > 0 then return left end
    return nil
end

-- ---------------------------------------------------------------- asepsis / anesthesia
local function wearsGloves(player)
    local worn = call(player, "getWornItems")
    if not worn then return false end
    for i = 0, worn:size() - 1 do
        local w = worn:get(i)
        local it = w and call(w, "getItem")
        local ty = (it and call(it, "getType") or ""):lower()
        if ty:find("glove", 1, true) and (ty:find("surg", 1, true) or ty:find("latex", 1, true) or ty:find("medical", 1, true)) then
            return true
        end
    end
    return false
end

local function handsClean(player)
    local W = EHR and EHR.WashHands
    if W and W.GetDirtyPartCount then
        local ok, n = pcall(W.GetDirtyPartCount, player)
        if ok then return (tonumber(n) or 0) == 0 end
    end
    return false
end

-- -> value 0..1, list of { key, ok, weight }
function S.asepsis(doctor, antisepticFound)
    local parts = {
        { key = "Antiseptic", ok = antisepticFound == true, weight = 0.45 },
        { key = "Gloves", ok = wearsGloves(doctor), weight = 0.25 },
        { key = "CleanHands", ok = handsClean(doctor), weight = 0.20 },
        { key = "Indoors", ok = call(call(doctor, "getCurrentSquare"), "isOutside") == false, weight = 0.10 },
    }
    local v = 0
    for _, p in ipairs(parts) do if p.ok then v = v + p.weight end end
    return v, parts
end

-- -> value 0..1, list of { key, ok }
function S.anesthesia(patient)
    local asleep = call(patient, "isAsleep") == true
    local analgesic = false
    local M = EHR and EHR.Medication
    if M and M.IsAnalgesicActive then
        local ok, r = pcall(M.IsAnalgesicActive, patient)
        analgesic = ok and r == true
    end
    if not analgesic then
        local bd = call(patient, "getBodyDamage")
        analgesic = (tonumber(call(bd, "getPainReduction")) or 0) > 0
    end
    local drunk = false
    local stats = call(patient, "getStats")
    if stats and CharacterStat and CharacterStat.INTOXICATION then
        drunk = (tonumber(call(stats, "get", CharacterStat.INTOXICATION)) or 0) >= 30
    end
    local v = asleep and 1 or math.min(1, (analgesic and 0.7 or 0) + (drunk and 0.3 or 0))
    return v, {
        { key = "Analgesic", ok = analgesic },
        { key = "Alcohol", ok = drunk },
        { key = "Asleep", ok = asleep },
    }
end

-- -debug game or a server admin: may bypass the "not on yourself" lock
function S.privileged(player)
    if isDebugEnabled and isDebugEnabled() then return true end
    local level = call(player, "getAccessLevel")
    return level == "admin" or level == "Admin"
end

-- has the patient eaten recently (full stomach)? -> full, hunger, risk %
function S.fasting(patient, anesthesia)
    local hunger
    local stats = call(patient, "getStats")
    if stats and CharacterStat and CharacterStat.HUNGER then
        hunger = tonumber(call(stats, "get", CharacterStat.HUNGER))
    end
    if not hunger then return false, nil, 0 end
    local full = hunger < S.FULL_STOMACH_HUNGER
    if not full then return false, hunger, 0 end
    local sedated = (anesthesia or 0) >= 0.6
    return true, hunger, sedated and S.ASPIRATION_CHANCE_SEDATED or S.ASPIRATION_CHANCE
end

function S.bloodFraction(patient)
    local B = HARMONIE_HomeMedic_BloodImpact
    if B and B.bloodFraction then
        local ok, f = pcall(B.bloodFraction, patient)
        if ok and f then return f end
    end
    return nil
end

function S.distance(a, b)
    if a == b then return 0 end
    local dx = (call(a, "getX") or 0) - (call(b, "getX") or 0)
    local dy = (call(a, "getY") or 0) - (call(b, "getY") or 0)
    if math.abs((call(a, "getZ") or 0) - (call(b, "getZ") or 0)) > 0.1 then return 99 end
    return math.sqrt(dx * dx + dy * dy)
end

-- Generated description of what an operation does to each condition.
function S.targetsTip(sid)
    local s = S.Surgeries[sid]
    if not s then return "" end
    local ids = {}
    for id in pairs(s.targets) do ids[#ids + 1] = id end
    table.sort(ids)
    local lines = {}
    for _, id in ipairs(ids) do
        local t = s.targets[id]
        local what
        if t.treat then
            what = S.T("Eff_Treat", "treatment, clears in ~%1h (%2h if excellent)", t.treat, math.floor(t.treat * S.EXCELLENT_TREAT + 0.5))
        elseif t.cure then
            what = S.T("Eff_Cure", "cured at once")
        else
            what = S.T("Eff_" .. id, id)
        end
        lines[#lines + 1] = "- " .. S.T("Cond_" .. id, id) .. ": " .. what
    end
    return table.concat(lines, "\n")
end

-- Handbook text: which operations treat a disease and when they are needed.
function S.handbookText(id)
    id = tostring(id or ""):lower()
    if id == "knox_infection" or id == "knox" then
        return S.T("Hb_knox", "Amputate the bitten arm in time (Amputation), or try Experimental surgery with a Gene Therapy Kit.")
    end
    local list = S.surgeriesFor(id)
    if #list == 0 then return nil end
    local names = {}
    local treat, cure
    for _, sid in ipairs(list) do
        names[#names + 1] = S.T("Name_" .. sid, sid) .. " (" .. S.T("Tier_" .. S.Surgeries[sid].tier, S.Surgeries[sid].tier) .. ")"
        local t = S.Surgeries[sid].targets[id]
        if t and t.treat then treat = math.min(treat or t.treat, t.treat) end
        if t and t.cure then cure = true end
    end
    local lines = { table.concat(names, ", ") }
    if id == "wound_infection" then
        lines[#lines + 1] = S.T("Hb_Clear", "A successful operation clears the infected wound at once.")
    elseif cure then
        lines[#lines + 1] = S.T("Hb_Cure", "It heals by itself in time; a successful operation ends it at once, with all its symptoms.")
    elseif treat then
        lines[#lines + 1] = S.T("Hb_Treat", "Success starts treatment: it clears in about %1 hours (%2 if excellent).", treat, math.floor(treat * S.EXCELLENT_TREAT + 0.5))
    end
    if S.SURGICAL[id] then
        lines[#lines + 1] = S.T("Hb_Required", "From stage %1 surgery is needed: a finished medicine course only holds it there (Awaiting surgery).", S.SURGICAL[id])
    elseif not cure then
        lines[#lines + 1] = S.T("Hb_Optional", "Optional: medicine alone can still cure it.")
    end
    return table.concat(lines, " ")
end

-- ---------------------------------------------------------------- readiness
-- -> { rows = {...}, canStart, slots = {slotId = fill}, indications, asepsis, anesthesia, toolQ }
-- row = { key, state = "ok"|"warn"|"fail"|"info", required, label, value, tip }
function S.evaluate(doctor, patient, bodyPart, sid, exam)
    local s = S.Surgeries[sid]
    local r = { rows = {}, slots = {}, canStart = true }
    if not s then r.canStart = false; return r end
    local function row(t)
        r.rows[#r.rows + 1] = t
        if t.required and t.state == "fail" then r.canStart = false end
    end

    -- indication
    local ind = S.indications(patient, bodyPart, sid, exam)
    r.indications = ind
    local remoteUnknown = #ind == 0 and not exam and S.isRemote(doctor, patient)
    local usable = 0
    local names = {}
    local undiagnosed = 0
    for _, i in ipairs(ind) do
        if i.undiagnosed then
            undiagnosed = undiagnosed + 1
        else
            if not i.cool then usable = usable + 1 end
            local special = i.id == "wound_infection" or i.id == "foreign_body" or i.id == "knox" or i.id == "knox_bite" or i.id == "necrosis"
            names[#names + 1] = S.T("Cond_" .. i.id, i.id)
                .. ((not special) and (" " .. S.T("Stage", "St.%1", i.stage)) or "")
                .. (i.held and (" - " .. S.T("HeldShort", "awaiting")) or "")
                .. (i.cool and (" (" .. S.T("CoolShort", "%1h", math.ceil(i.cool)) .. ")") or "")
        end
    end
    -- the name stays hidden until someone diagnoses it
    if undiagnosed > 0 then names[#names + 1] = S.T("Ind_Undiagnosed", "Undiagnosed illness - diagnose it first") end
    row({ key = "indication", required = not remoteUnknown,
          state = usable > 0 and "ok" or (remoteUnknown and "info" or "fail"),
          label = S.T("Row_Indication", "Indication"),
          value = #names > 0 and table.concat(names, ", ")
              or (remoteUnknown and S.T("ServerChecks", "Checked when you start") or S.T("None", "None")),
          tip = S.T("Tip_Indication", "What this operation treats through this body part.")
              .. (undiagnosed > 0 and ("\n\n" .. S.T("Tip_Undiagnosed", "An illness must be diagnosed (Diagnosis tab) before it can be operated on.")) or "")
              .. "\n\n" .. S.targetsTip(sid) })

    -- the operation itself (tier / disease knowledge / The Only Cure)
    local sok, why = S.surgeryUnlocked(doctor, sid)
    if not sok and why ~= "Steps" then
        local k = {}
        for _, id in ipairs(s.knowledge or {}) do k[#k + 1] = S.T("Cond_" .. id, id) end
        row({ key = "operation", required = true, state = "fail",
              label = S.T("Row_Operation", "Operation"), value = S.T("Lock_" .. tostring(why), "Locked"),
              tip = S.T("Tip_Lock_" .. tostring(why), "", S.TIERS[s.tier].firstAid, table.concat(k, " / ")) })
    end

    -- skill: one row per procedure (step)
    for n, pid in ipairs(s.steps) do
        local ok, needFa, missing = S.procedureUnlocked(doctor, pid)
        local tip = S.T("Tip_" .. pid, "") .. "\n\n" .. S.T("Tip_UnlockFA", "Needs First Aid %1.", needFa)
        if S.Procedures[pid].knowledge then
            local k = {}
            for _, id in ipairs(S.Procedures[pid].knowledge) do k[#k + 1] = S.T("Cond_" .. id, id) end
            tip = tip .. "\n" .. S.T("Tip_UnlockKnow", "And knowledge of: %1 (a disease flyer, or First Aid 8).", table.concat(k, " / "))
        end
        row({ key = "step" .. n, required = true, state = ok and "ok" or "fail",
              label = n .. ". " .. S.T("Proc_" .. pid, pid),
              value = ok and S.T("Ready", "Ready") or S.T("Locked", "Locked"),
              tip = tip })
    end

    -- supplies
    local qSum, qN = 0, 0
    -- transfusion: needed when the operation would leave the patient low on blood
    local ptype = S.bloodType(patient, exam)
    local bv = modData(patient, exam, "EHR_Blood")
    local cur = type(bv) == "table" and tonumber(bv.currentVolume) or nil
    local max = type(bv) == "table" and tonumber(bv.maxVolume) or nil
    local raw = (cur and max and max > 0) and (cur - (s.bloodLoss or 0)) / max or nil
    -- every operation leaves the patient at S.POSTOP_MAX at most; a
    -- transfusion is worth it only for someone who would end below that
    local after = raw and math.min(raw, S.POSTOP_MAX) or nil
    local worth = raw ~= nil and raw < S.POSTOP_MAX
    local must = after ~= nil and after < S.TRANSFUSE_BELOW
    r.bloodAfter, r.mustTransfuse = after, must
    local function optionNames(slot, n)
        local out = {}
        for _, o in ipairs(slot.options) do
            if #out >= n then break end
            out[#out + 1] = o.type and (getItemNameFromFullType and getItemNameFromFullType(o.type) or o.type) or S.T("Match_" .. o.match, o.match)
        end
        return table.concat(out, " / ")
    end
    for _, slotId in ipairs(s.supplies) do
        local slot = S.Supplies[slotId]
        local fill
        local value, state
        if slot.transfusion and not worth then
            value = after and S.T("Transfuse_NotNeeded", "Not needed (blood after ~%1%)", math.floor(after * 100 + 0.5)) or S.T("Optional", "optional")
            state = "info"
        elseif slot.transfusion == "saline" and r.slots.blood and r.slots.blood.compatible then
            value, state = S.T("Transfuse_UseBlood", "Not used: the blood bag goes in"), "info"
        else
            fill = S.fillSlot(Src.get(doctor), slotId, ptype)
            r.slots[slotId] = fill
            if fill then
                value = (call(fill.item, "getDisplayName") or fullType(fill.item)) .. " - " .. S.T("Where_" .. fill.where, fill.where)
                state = fill.q >= 0.8 and "ok" or "warn"
                if slot.kind == "tool" then qSum = qSum + fill.q; qN = qN + 1 end
                if slot.transfusion == "blood" then
                    value = value .. "  [" .. tostring(fill.donor or "?") .. " -> " .. tostring(ptype or "?") .. "] "
                        .. (fill.compatible and S.T("Compatible", "compatible") or S.T("Incompatible", "INCOMPATIBLE"))
                    state = fill.compatible and "ok" or "warn"
                end
            else
                value = S.T("MissingNeed", "Missing: %1", optionNames(slot, 2))
                state = slot.required and "fail" or (slot.transfusion and must and "warn" or "warn")
            end
        end
        local opts = {}
        for _, o in ipairs(slot.options) do
            local nm = o.type and (getItemNameFromFullType and getItemNameFromFullType(o.type) or o.type) or S.T("Match_" .. o.match, o.match)
            opts[#opts + 1] = nm .. (o.needs and (" + " .. (getItemNameFromFullType and getItemNameFromFullType(o.needs) or o.needs)) or "")
        end
        row({ key = "slot_" .. slotId, required = slot.required, state = state,
              label = S.T("Slot_" .. slotId, slotId) .. (slot.kind == "use" and (" " .. S.T("Consumed", "(used up)")) or ""),
              value = value,
              tip = S.T("Tip_Slot_" .. slotId, "") .. "\n\n" .. S.T("Tip_Options", "Accepts: %1", table.concat(opts, ", "))
                  .. "\n" .. S.T("Tip_Sources", "Found in your inventory, on the floor or in containers next to you.") })
    end
    if must and not r.slots.blood and not r.slots.saline then
        row({ key = "transfusion", required = true, state = "fail",
              label = S.T("Row_Transfusion", "Transfusion"),
              value = S.T("Transfuse_Must", "Needed: blood after ~%1% (blood bag or saline)", math.floor(after * 100 + 0.5)),
              tip = S.T("Tip_Transfusion", "This operation would leave the patient with too little blood. Have a blood bag of a compatible type (or saline) at hand: it goes in during the operation.") })
    end
    r.toolQ = qN > 0 and (qSum / qN) or 1

    -- asepsis
    local asep, parts = S.asepsis(doctor, r.slots.antiseptic ~= nil)
    r.asepsis = asep
    local lines = {}
    for _, p in ipairs(parts) do lines[#lines + 1] = (p.ok and "+ " or "- ") .. S.T("Asep_" .. p.key, p.key) end
    row({ key = "asepsis", state = asep >= 0.6 and "ok" or (asep >= 0.3 and "warn" or "fail"),
          label = S.T("Row_Asepsis", "Asepsis"), value = math.floor(asep * 100 + 0.5) .. "%",
          tip = S.T("Tip_Asepsis", "Low asepsis = risk of a surgical-site infection (Cellulitis).") .. "\n" .. table.concat(lines, "\n") })

    -- anesthesia
    local an, aparts = S.anesthesia(patient)
    r.anesthesia = an
    lines = {}
    for _, p in ipairs(aparts) do lines[#lines + 1] = (p.ok and "+ " or "- ") .. S.T("Anes_" .. p.key, p.key) end
    row({ key = "anesthesia", state = an >= 0.6 and "ok" or "warn",
          label = S.T("Row_Anesthesia", "Anesthesia"), value = math.floor(an * 100 + 0.5) .. "%",
          tip = S.T("Tip_Anesthesia", "Without pain relief the patient flinches: the steps shake and hurt more.") .. "\n" .. table.concat(lines, "\n") })

    -- fasting (NPO): a full stomach can be breathed in during the operation
    local full, _, risk = S.fasting(patient, an)
    r.aspiration = risk
    row({ key = "fasting", state = full and "warn" or "ok",
          label = S.T("Row_Fasting", "Fasting (NPO)"),
          value = full and S.T("Fasting_Full", "Ate recently - aspiration %1%", risk) or S.T("Fasting_Ok", "Empty stomach"),
          tip = S.T("Tip_Fasting", "A patient who has just eaten may vomit and breathe it in during the operation (aspiration pneumonia), more so when asleep or sedated. Wait a few hours after a meal.") })

    -- blood
    local bf = S.bloodFraction(patient)
    if bf then
        row({ key = "blood", state = bf >= 0.7 and "ok" or (bf >= 0.55 and "warn" or "fail"),
              label = S.T("Row_Blood", "Blood volume"), value = math.floor(bf * 100 + 0.5) .. "%",
              tip = S.T("Tip_Blood", "The operation costs about %1 mL of blood (more if hemostasis goes badly).", s.bloodLoss) })
    end

    -- some operations cannot be done on yourself
    if doctor == patient and S.NO_SELF[sid] then
        local bypass = S.privileged(doctor)
        row({ key = "self", required = true, state = bypass and "warn" or "fail",
              label = S.T("Row_Self", "On yourself"),
              value = bypass and S.T("Self_Bypass", "Allowed (debug / admin)") or S.T("Self_No", "Not possible"),
              tip = S.T("Tip_Self", "Nobody can open their own chest, abdomen or skull, run their own dialysis or gene therapy. Another player has to operate.") })
    end

    -- position
    local dist = S.distance(doctor, patient)
    row({ key = "distance", required = true, state = dist <= S.MAX_DISTANCE and "ok" or "fail",
          label = S.T("Row_Patient", "Patient"),
          value = doctor == patient and S.T("Self", "Yourself (harder)") or (call(patient, "getDisplayName") or call(patient, "getUsername") or "?"),
          tip = S.T("Tip_Patient", "Stay next to the patient. Operating on yourself makes every step shakier.") })
    return r
end

-- ---------------------------------------------------------------- quality
-- steps: { [n] = score 0..1 }; returns 0..1
function S.quality(sid, scores, toolQ)
    local s = S.Surgeries[sid]
    if not s then return 0 end
    local sum, wsum = 0, 0
    for n, pid in ipairs(s.steps) do
        local w = S.Procedures[pid].weight or 1
        local v = tonumber(scores and scores[n]) or 0
        if v < 0 then v = 0 elseif v > 1 then v = 1 end
        sum = sum + v * w
        wsum = wsum + w
    end
    local q = wsum > 0 and sum / wsum or 0
    return q * (0.75 + 0.25 * math.max(0, math.min(1, toolQ or 1)))
end

-- Difficulty knobs for the minigames (client) from who operates and how.
function S.difficulty(doctor, patient, anesthesia, toolQ)
    local fa = S.firstAid(doctor)
    local skill = math.min(1, fa / 10)
    local shake = (1 - (anesthesia or 0)) * 0.8 + ((doctor == patient) and 0.5 or 0)
    return {
        skill = skill,                                   -- 0..1 wider windows / slower timers
        shake = math.min(1.2, shake),                    -- patient movement
        tool = toolQ or 1,
    }
end

return S

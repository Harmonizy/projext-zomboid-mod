--[[
    HARMONIE - How to Survive : health log (HTS 1.2.11)

    Owner 2026-11-27: "does EHR log what happens -- what lowered or raised
    what, and what caused it? Every 10 health lost -- is it EHR, and why?"

    EHR's own log prints only errors, so nothing said where health went.
    This writes to console.txt, where health is decided (server in MP,
    the game itself in SP):

      [HARMONIE_HM][HealthLog][server] Bob: health 85.0 -> 74.0 (-11.0 in 8 s)
          | EHR: illness trichinosis -6.0, health cap 80 -3.0
          | not EHR (vanilla / other mods) -2.0: bleeding Hand_L, hunger 0.72
          | blood 72 percent, saline 10 percent, illnesses: trichinosis st2

    * Every place EHR lowers health reports itself (HMHealthLog.note): the
      illness damage and health caps of EHR_Disease / Sepsis /
      Environmental, the medication overdose cap, hemodilution.
    * Health is read every second; a line is written each time health is
      10 lower than at the last line (owner: "log when health drops 10").
      Healing above that point moves the starting point up.
    * Whatever EHR did not report is "not EHR": the line lists the vanilla
      conditions on the character at that moment (wounds, hunger, thirst,
      sickness, poison, temperature, zombie infection) as the likely cause.
    Read only: never changes health.

    BLOOD (owner: "is blood volume logged?" -- it was not: EHR.Log is quiet
    unless verbose). The same reader writes a [BloodLog] line each time the
    blood volume is 10 percent of full lower (or higher) than at the last
    line:
      Bob: blood 4100 -> 3600 mL (82 -> 72 percent, -500 in 3 min)
          | bleeding -380: Hand_L, Neck | amputation -120 | regen +0
    Named changes: every EHR.Blood.ModifyBloodVolume / SetBloodVolume call
    (labelled by HMHealthLog.bloodWhy(label) just before it, else by its
    amount: +500 transfusion, +250 saline, -500 blood drawn, -150 reaction),
    regeneration (ApplyBloodRegeneration) and transfusion processing; what is
    left is the bleeding EHR takes every update, listed with the parts that
    bleed.
]]--

HMHealthLog = HMHealthLog or {}
local HL = HMHealthLog

HL.READ_MS = 1000
HL.FLUSH_DROP = 10
HL.state = HL.state or setmetatable({}, { __mode = "k" })

local function log(fmt, ...)
    if HMLog then HMLog("HealthLog", fmt, ...) else print(string.format("[HARMONIE_HM][HealthLog] " .. fmt, ...)) end
end
local function nameOf(p)
    if HMLogName then return HMLogName(p) end
    local ok, n = pcall(function() return p:getUsername() end)
    return ok and tostring(n) or "?"
end
local function now() return getTimestampMs and getTimestampMs() or 0 end

function HL.hp(p)
    local ok, v = pcall(function() return p:getBodyDamage():getOverallBodyHealth() end)
    return ok and tonumber(v) or nil
end

local function st(p)
    local s = HL.state[p]
    if not s then
        s = { last = HL.hp(p), ref = nil, at = nil, rose = 0, ehr = {}, order = {} }
        HL.state[p] = s
    end
    return s
end

-- EHR calls this right after it lowered (or capped) health
function HL.note(p, src, before, detail)
    if not p or not before then return end
    local after = HL.hp(p)
    if not after then return end
    local d = after - tonumber(before)
    if d > -0.01 then return end
    local s = st(p)
    local key = tostring(src) .. (detail and detail ~= "" and (" " .. tostring(detail)) or "")
    if not s.ehr[key] then s.order[#s.order + 1] = key end
    s.ehr[key] = (s.ehr[key] or 0) + d
end

local function fmt1(v) return string.format("%+.1f", v) end

-- vanilla things on the character that take health
local function vanillaCauses(p)
    local out = {}
    pcall(function()
        local bd = p:getBodyDamage()
        local parts = bd:getBodyParts()
        local wounds = {}
        for i = 0, parts:size() - 1 do
            local bp = parts:get(i)
            local w = {}
            local function has(m) local ok, v = pcall(function() return bp[m](bp) end); return ok and v == true end
            if has("bleeding") then w[#w + 1] = "bleeding" end
            if has("bitten") then w[#w + 1] = "bite" end
            if has("deepWounded") then w[#w + 1] = "deep wound" end
            if has("isCut") then w[#w + 1] = "laceration" end
            if has("scratched") then w[#w + 1] = "scratch" end
            if has("isBurnt") then w[#w + 1] = "burn" end
            if has("haveBullet") then w[#w + 1] = "bullet" end
            if has("haveGlass") then w[#w + 1] = "glass" end
            if has("isInfectedWound") then w[#w + 1] = "infected" end
            if #w > 0 then
                local okT, t = pcall(function() return BodyPartType.ToString(bp:getType()) end)
                wounds[#wounds + 1] = (okT and t or "?") .. " " .. table.concat(w, "+")
            end
        end
        if #wounds > 0 then out[#out + 1] = "wounds: " .. table.concat(wounds, ", ") end
        local okI, inf = pcall(function() return bd:getInfectionLevel() end)
        if okI and tonumber(inf) and inf > 0 then out[#out + 1] = string.format("zombie infection %.0f", inf) end
        local okT, temp = pcall(function() return bd:getTemperature() end)
        if okT and tonumber(temp) and (temp < 35 or temp > 39) then out[#out + 1] = string.format("body temp %.1f C", temp) end
    end)
    pcall(function()
        local stats = p:getStats()
        if not stats or not CharacterStat then return end
        local function stat(k, limit, label)
            if not CharacterStat[k] then return end
            local ok, v = pcall(function() return stats:get(CharacterStat[k]) end)
            if ok and tonumber(v) and v >= limit then out[#out + 1] = string.format("%s %.2f", label, v) end
        end
        stat("HUNGER", 0.6, "hunger")
        stat("THIRST", 0.6, "thirst")
        stat("FOOD_SICKNESS", 0.25, "food sickness")
        stat("POISON", 0.1, "poison")
        stat("SICKNESS", 0.25, "sickness")
    end)
    return out
end

-- EHR's state that matters for health
local function ehrContext(p)
    local out = {}
    pcall(function()
        local data = EHR and EHR.GetPlayerData and EHR.GetPlayerData(p)
        local b = data and data.EHR_Blood
        local cur, max = b and tonumber(b.currentVolume), b and tonumber(b.maxVolume)
        if cur and max and max > 0 then
            out[#out + 1] = string.format("blood %.0f percent", cur / max * 100)
            local sal = tonumber(b.transfusedSaline) or 0
            if sal > 0 and cur > 0 then out[#out + 1] = string.format("saline %.0f percent", sal / cur * 100) end
        end
    end)
    pcall(function()
        local dd = EHR and EHR.Disease and EHR.Disease.GetDiseaseData and EHR.Disease.GetDiseaseData(p)
        local act = dd and dd.active
        if type(act) == "table" then
            local list = {}
            for id, d in pairs(act) do list[#list + 1] = tostring(id) .. (type(d) == "table" and d.stage and (" st" .. tostring(d.stage)) or "") end
            table.sort(list)
            if #list > 0 then out[#out + 1] = "illnesses: " .. table.concat(list, ", ") end
        end
    end)
    pcall(function()
        local sd = EHR and EHR.Sepsis and EHR.Sepsis.GetData and EHR.Sepsis.GetData(p)
        if sd and sd.active then out[#out + 1] = "sepsis stage " .. tostring(sd.stage) end
    end)
    return out
end

local function flush(p, s, cur)
    local delta = cur - s.ref
    local secs = math.max(1, math.floor((now() - s.at) / 1000 + 0.5))
    local parts = {}
    local ehrSum = 0
    local ehrList = {}
    for _, k in ipairs(s.order) do
        ehrSum = ehrSum + s.ehr[k]
        ehrList[#ehrList + 1] = k .. " " .. fmt1(s.ehr[k])
    end
    parts[#parts + 1] = #ehrList > 0 and ("EHR " .. fmt1(ehrSum) .. ": " .. table.concat(ehrList, ", ")) or "EHR: nothing"
    local rest = delta - ehrSum
    if rest < -0.05 then
        local v = vanillaCauses(p)
        parts[#parts + 1] = "not EHR (vanilla / other mods) " .. fmt1(rest) .. ": " .. (#v > 0 and table.concat(v, "; ") or "no vanilla cause seen now")
    end
    if s.rose > 0.05 then parts[#parts + 1] = string.format("also rose +%.1f on the way (healing / medicine)", s.rose) end
    local c = ehrContext(p)
    if #c > 0 then parts[#parts + 1] = table.concat(c, ", ") end
    log("%s: health %.1f -> %.1f (%s in %s) | %s", nameOf(p), s.ref, cur, fmt1(delta),
        secs >= 120 and (math.floor(secs / 60) .. " min") or (secs .. " s"), table.concat(parts, " | "))
end

-- owner: "write the log when health has dropped 10". The reference is the
-- health at the last line (or the highest since); a line is written each
-- time health is 10 below it, with everything EHR took since then.
function HL.check(p)
    if not p or (p.isDead and p:isDead()) then return end
    local s = st(p)
    local cur = HL.hp(p)
    if not cur then return end
    if not s.ref then s.ref, s.at, s.rose = cur, now(), 0 end
    if s.last and cur > s.last then s.rose = s.rose + (cur - s.last) end
    s.last = cur
    if cur > s.ref then
        -- healed above the reference: start counting from here
        s.ref, s.at, s.rose, s.ehr, s.order = cur, now(), 0, {}, {}
        return
    end
    if s.ref - cur >= HL.FLUSH_DROP then
        flush(p, s, cur)
        s.ref, s.at, s.rose, s.ehr, s.order = cur, now(), 0, {}, {}
    end
end

-- ------------------------------------------------------------- blood
HL.BLOOD_STEP = 0.10      -- a line every 10 percent of full blood
HL.bstate = HL.bstate or setmetatable({}, { __mode = "k" })

local function bloodOf(p)
    local ok, cur, max = pcall(function()
        local data = EHR and EHR.GetPlayerData and EHR.GetPlayerData(p)
        local b = data and data.EHR_Blood
        return tonumber(b and b.currentVolume), tonumber(b and b.maxVolume)
    end)
    if ok and cur and max and max > 0 then return cur, max end
    return nil
end

local function bst(p)
    local s = HL.bstate[p]
    if not s then s = { ref = nil, at = nil, parts = {}, order = {} }; HL.bstate[p] = s end
    return s
end

-- the next ModifyBloodVolume / SetBloodVolume of this player is "label"
HL.pendingWhy = HL.pendingWhy or setmetatable({}, { __mode = "k" })
function HL.bloodWhy(p, label) if p then HL.pendingWhy[p] = label end end

function HL.bloodNote(p, label, delta)
    delta = tonumber(delta) or 0
    if math.abs(delta) < 0.01 then return end
    local s = bst(p)
    if not s.parts[label] then s.order[#s.order + 1] = label end
    s.parts[label] = (s.parts[label] or 0) + delta
end

local function guessLabel(delta)
    local d = math.floor(delta + 0.5)
    if d == 500 then return "transfusion (blood bag)" end
    if d == 250 then return "saline" end
    if d == -500 then return "blood drawn" end
    if d == -150 then return "transfusion reaction" end
    return d > 0 and "added" or "taken"
end

local function bleedingParts(p)
    local list = {}
    pcall(function()
        local parts = p:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local bp = parts:get(i)
            local ok, b = pcall(function() return bp:bleeding() end)
            if ok and b then
                local okT, t = pcall(function() return BodyPartType.ToString(bp:getType()) end)
                list[#list + 1] = okT and t or "?"
            end
        end
    end)
    return list
end

local function blog(fmt, ...)
    if HMLog then HMLog("BloodLog", fmt, ...) else print(string.format("[HARMONIE_HM][BloodLog] " .. fmt, ...)) end
end

local function bloodFlush(p, s, cur, max)
    local delta = cur - s.ref
    local secs = math.max(1, math.floor((now() - s.at) / 1000 + 0.5))
    local parts, named = {}, 0
    for _, k in ipairs(s.order) do
        named = named + s.parts[k]
        parts[#parts + 1] = string.format("%s %+.0f", k, s.parts[k])
    end
    local rest = delta - named
    if rest < -1 then
        local bl = bleedingParts(p)
        table.insert(parts, 1, string.format("bleeding %+.0f: %s", rest, #bl > 0 and table.concat(bl, ", ") or "none bleeding now (stopped)"))
    elseif rest > 1 then
        parts[#parts + 1] = string.format("other %+.0f", rest)
    end
    local ctx = {}
    pcall(function()
        local data = EHR.GetPlayerData(p)
        local sal = tonumber(data.EHR_Blood.transfusedSaline) or 0
        if sal > 0 and cur > 0 then ctx[#ctx + 1] = string.format("saline %.0f percent", sal / cur * 100) end
    end)
    local hp = HL.hp(p)
    if hp then ctx[#ctx + 1] = string.format("health %.0f", hp) end
    blog("%s: blood %.0f -> %.0f mL (%.0f -> %.0f percent, %+.0f in %s) | %s%s", nameOf(p), s.ref, cur,
        s.ref / max * 100, cur / max * 100, delta, secs >= 120 and (math.floor(secs / 60) .. " min") or (secs .. " s"),
        #parts > 0 and table.concat(parts, " | ") or "no named change", #ctx > 0 and (" | " .. table.concat(ctx, ", ")) or "")
end

function HL.checkBlood(p)
    if not p or (p.isDead and p:isDead()) then return end
    local cur, max = bloodOf(p)
    if not cur then return end
    local s = bst(p)
    if not s.ref then s.ref, s.at = cur, now(); return end
    if math.abs(cur - s.ref) >= max * HL.BLOOD_STEP then
        bloodFlush(p, s, cur, max)
        s.ref, s.at, s.parts, s.order = cur, now(), {}, {}
    end
end

local function wrapBloodChanges()
    local B = EHR and EHR.Blood
    if HL.bloodChangesWrapped or not B then return end
    HL.bloodChangesWrapped = true
    local function around(name, label)
        local orig = B[name]
        if type(orig) ~= "function" then return end
        B[name] = function(player, ...)
            local before = bloodOf(player)
            local r = orig(player, ...)
            local after = before and bloodOf(player)
            if before and after then
                local d = after - before
                local why = label or HL.pendingWhy[player] or guessLabel(d)
                if not label then HL.pendingWhy[player] = nil end
                HL.bloodNote(player, why, d)
            end
            return r
        end
    end
    around("ModifyBloodVolume", nil)
    around("SetBloodVolume", nil)
    around("ApplyBloodRegeneration", "regeneration")
    around("ProcessTransfusionDecay", "transfusion processed")
    log("blood log on: a line every %d percent of full blood lost or gained", math.floor(HL.BLOOD_STEP * 100))
end

local nextRead = 0
local function tick()
    local t = now()
    if t < nextRead then return end
    nextRead = t + HL.READ_MS
    if isClient and isClient() then return end -- health is decided on the server in MP
    if isServer and isServer() then
        local list = getOnlinePlayers and getOnlinePlayers()
        for i = 0, (list and list:size() or 0) - 1 do pcall(HL.check, list:get(i)); pcall(HL.checkBlood, list:get(i)) end
    else
        for i = 0, (getNumActivePlayers and getNumActivePlayers() or 1) - 1 do
            local p = getSpecificPlayer and getSpecificPlayer(i)
            if p then pcall(HL.check, p); pcall(HL.checkBlood, p) end
        end
    end
end

-- hemodilution (EHR_Blood global): wrap it here
local function wrapBlood()
    if HL.bloodWrapped or not (EHR and EHR.Blood and EHR.Blood.ApplyHemodilutionDeath) then return end
    HL.bloodWrapped = true
    local orig = EHR.Blood.ApplyHemodilutionDeath
    EHR.Blood.ApplyHemodilutionDeath = function(player, ratio, ...)
        local b = HL.hp(player)
        local r = orig(player, ratio, ...)
        HL.note(player, "hemodilution", b, string.format("saline %.0f percent", (tonumber(ratio) or 0) * 100))
        return r
    end
end

if not HL.ticking and Events and Events.OnTick then
    HL.ticking = true
    Events.OnTick.Add(tick)
    if Events.OnGameStart then Events.OnGameStart.Add(wrapBlood); Events.OnGameStart.Add(wrapBloodChanges) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(wrapBlood); Events.OnServerStarted.Add(wrapBloodChanges) end
    log("health log on: a line every 10 health lost, with EHR's share and the vanilla causes")
end

return HL

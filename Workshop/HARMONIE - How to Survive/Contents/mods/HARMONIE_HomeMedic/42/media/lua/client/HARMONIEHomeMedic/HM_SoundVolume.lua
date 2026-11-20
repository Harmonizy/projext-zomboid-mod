--[[
    HARMONIE - How to Survive 1.1.0: a volume for EVERY sound of this mod,
    per player, on their own machine (owner 2026-11-20: "the old delirium
    volume -> make it turn down every HTS sound instead: sneeze, cough,
    delirium and the others").

    Groups (Options -> Mods and the settings window, 0 .. 150 percent each),
    all times the master volume:
      cough    sneezes and coughs (anyone's -- see the relay below)
      pain     the pain cries of EHR_PainSounds
      delirium the hallucination sounds (HARMONIE_DeliriumAudio's loudness
               copies; its own mute stays)
      medical  surgery / diagnosis / dose-reminder sounds, amputation and
               cauterising, washing, bandaging, the heat-stroke bath
    How: a sound played on a character's emitter gets emitter:setVolume
    (handle, v) right after it starts (as Lifestyle Audio Tune does); a UI
    sound plays as playUISound at 100 percent, not at all at 0, otherwise as
    a quiet world sound at the player (PlayWorldSound + setVolume). In MP the
    server no longer broadcasts a cough with sendPlaySound (no volume there):
    it asks each client near the cougher ("HARMONIE_HM_Sound"/"play", HM_SoundNet)
    and each client plays it at its own volume.
]]--

HM_Sound = HM_Sound or {}
local S = HM_Sound

S.GROUPS = { "cough", "pain", "delirium", "medical" }
S.master = S.master or 1
S.group = S.group or { cough = 1, pain = 1, delirium = 1, medical = 1 }

local function log(fmt, ...) if HMLog then HMLog("Sound", fmt, ...) end end
local function logOnce(key, fmt, ...) if HMLogOnce then HMLogOnce("sound:" .. key, "Sound", fmt, ...) end end

-- the volume for a group now (0 = silent, 1 = as made)
function S.vol(group)
    local g = tonumber(S.group[group or "medical"]) or 1
    return math.max(0, (tonumber(S.master) or 1) * g)
end

local function near1(v) return math.abs(v - 1) < 0.01 end

-- a sound already started on `chr`'s emitter: bring it to the group's volume
function S.adjust(chr, handle, group)
    if not chr or not handle or handle == 0 then return handle end
    local v = S.vol(group)
    if near1(v) then return handle end
    local ok = pcall(function() chr:getEmitter():setVolume(handle, v) end)
    if not ok then logOnce("setVolume", "emitter:setVolume failed -- %s sounds stay at full volume", tostring(group)) end
    return handle
end

-- play `name` on `chr` at the group's volume; returns the handle (nil when silent)
function S.playOn(chr, name, group)
    if not chr or not name then return nil end
    if S.vol(group) <= 0.001 then return nil end
    local ok, h = pcall(function() return chr:getEmitter():playSound(name) end)
    if not ok or not h then
        ok, h = pcall(function() return chr:playSound(name) end)
    end
    if ok and h then S.adjust(chr, h, group) end
    return ok and h or nil
end

-- a UI sound (no position) at the group's volume
function S.playUI(name, group)
    if not name or not getSoundManager then return end
    local v = S.vol(group)
    if v <= 0.001 then return end
    local sm = getSoundManager()
    if near1(v) then pcall(function() sm:playUISound(name) end) return end
    local p = getPlayer and getPlayer()
    local sq = p and p:getCurrentSquare()
    local ok = sq and pcall(function()
        local snd = sm:PlayWorldSound(name, sq, 0, 8, v, false)
        if snd and snd.setVolume then snd:setVolume(v) end
    end)
    if not ok then
        logOnce("uiQuiet", "quiet UI sound not possible here -- %s plays at full volume", tostring(name))
        pcall(function() sm:playUISound(name) end)
    end
end

-- delirium keeps its loudness copies: their level = master x delirium
function S.apply()
    local A = HARMONIE_HomeMedic_DeliriumAudio
    if A and A.setVolume then A.setVolume(S.vol("delirium")) end
    local parts = {}
    for _, g in ipairs(S.GROUPS) do parts[#parts + 1] = g .. " " .. math.floor(S.vol(g) * 100 + 0.5) end
    local line = table.concat(parts, ", ")
    if line ~= S.lastLine then
        S.lastLine = line
        log("volumes (master %d percent): %s", math.floor((tonumber(S.master) or 1) * 100 + 0.5), line)
    end
end
function S.setMaster(v) S.master = tonumber(v) or 1; S.apply() end
function S.setGroup(g, v) S.group[g] = tonumber(v) or 1; S.apply() end

-- MP: a cough / sneeze the server relays (HM_SoundNet) -- played here on
-- that player, at this machine's volume
if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= "HARMONIE_HM_Sound" or command ~= "play" or type(args) ~= "table" then return end
        local who = args.id and getPlayerByOnlineID and getPlayerByOnlineID(args.id)
        if not who then logOnce("noWho", "relayed sound %s: player %s not here", tostring(args.sfx), tostring(args.id)) return end
        S.playOn(who, args.sfx, args.group or "cough")
    end)
end

--[[
    HARMONIE - Home Medic : blood-loss vision (client only)

    Request 2026-09-30 ("ปรับปรุงระบบเลือดให้ impact มากกว่านี้"). As blood
    falls below the healthy threshold the edges of the screen darken
    (tools/gen_blood_vignette.py -- our own texture); below the moderate
    threshold the whole view dims too and the darkness throbs like a
    heartbeat, faster the less blood is left. Reads the blood EHR keeps in
    the player's ModData (synced to the client in multiplayer), so it only
    draws on the player's own screen. Turned off / scaled from
    Options -> Mods (HARMONIE_ModOptions.lua).
]]--

require "ISUI/ISPanel"
require "HARMONIEHomeMedic/HARMONIE_BloodImpact"

HARMONIE_HomeMedic_BloodVision = HARMONIE_HomeMedic_BloodVision or {}
local V = HARMONIE_HomeMedic_BloodVision

V.enabled = (V.enabled ~= false)
V.strength = V.strength or 1
V.TEXTURE = "media/textures/HARMONIE_HomeMedic/blood_vignette.png"
V.EDGE_AT_FLOOR = 0.40       -- blood fraction where the edges are darkest

-- Drawing needs a UI element's javaObject; this one is never added to the
-- UI manager, so it never takes mouse input (same trick as EHR's delirium).
local function bridge()
    if V.bridge and V.bridge.javaObject then return V.bridge end
    local b = ISPanel:new(0, 0, 1, 1)
    b.background = false
    b.border = false
    b:initialise()
    b:instantiate()
    if b.javaObject and b.javaObject.setConsumeMouseEvents then b.javaObject:setConsumeMouseEvents(false) end
    V.bridge = b
    return b
end

-- How dark, 0..1, for a blood fraction: edges (vignette) and whole view.
function V.levels(fraction, healthy, moderate, timeMs)
    if not fraction or fraction >= healthy then return 0, 0 end
    local edge = math.max(0, math.min(1, (healthy - fraction) / math.max(0.01, healthy - V.EDGE_AT_FLOOR)))
    edge = 0.15 + 0.85 * edge
    local dim = 0
    if fraction < moderate then
        local depth = math.max(0, math.min(1, (moderate - fraction) / math.max(0.01, moderate - 0.20)))
        -- heartbeat: 70 bpm at the threshold, up to 140 bpm near the end
        local bpm = 70 + 70 * depth
        local phase = ((timeMs or 0) / 60000 * bpm) % 1
        local beat = math.max(0, 1 - phase * 4)          -- a short thump at the start of each beat
        dim = depth * (0.35 + 0.25 * beat)
        edge = math.min(1, edge + 0.2 * beat * depth)
    end
    return edge, dim
end

function V.render()
    if not V.enabled or V.strength <= 0 then return end
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player or (player.isDead and player:isDead()) then return end
    local B = HARMONIE_HomeMedic_BloodImpact
    local fraction = B and B.bloodFraction(player)
    if not fraction then return end
    local t = EHR and EHR.Blood and EHR.Blood.GetThresholds and EHR.Blood.GetThresholds() or {}
    local healthy, moderate = tonumber(t.healthy) or 0.85, tonumber(t.moderate) or 0.70
    local edge, dim = V.levels(fraction, healthy, moderate, getTimestampMs and getTimestampMs() or 0)
    if edge <= 0 and dim <= 0 then return end
    local b = bridge()
    local core = getCore and getCore()
    if not b or not b.javaObject or not core then return end
    local w, h = core:getScreenWidth(), core:getScreenHeight()
    V.tex = V.tex or (getTexture and getTexture(V.TEXTURE)) or false
    if V.tex and edge > 0 then
        b.javaObject:DrawTextureScaledColor(V.tex, 0, 0, w, h, 1, 1, 1, math.min(1, edge * V.strength))
    end
    if dim > 0 then
        b.javaObject:DrawTextureScaledColor(nil, 0, 0, w, h, 0.05, 0, 0, math.min(0.85, dim * V.strength))
    end
end

if Events then
    if Events.OnPostUIDraw then Events.OnPostUIDraw.Add(V.render)
    elseif Events.OnRenderTick then Events.OnRenderTick.Add(V.render) end
end

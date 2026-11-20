--[[
    HARMONIE - How to Survive 1.1.0: the server side of HM_Sound (client
    HM_SoundVolume.lua). sendPlaySound gives every client the sound at full
    volume; instead the server tells each client within RANGE tiles which
    player makes which sound, and each client plays it at its own volume.
    SP / a client: plays it on the character (HM_Sound when loaded).
]]--

HM_SoundNet = HM_SoundNet or {}
local N = HM_SoundNet
N.RANGE = 60

function N.play(player, sfx, group)
    if not player or not sfx or sfx == "" then return end
    if isServer and isServer() then
        local list = getOnlinePlayers and getOnlinePlayers()
        local id = player.getOnlineID and player:getOnlineID()
        local n = 0
        for i = 0, (list and list:size() or 0) - 1 do
            local p = list:get(i)
            local dx, dy = p:getX() - player:getX(), p:getY() - player:getY()
            if dx * dx + dy * dy <= N.RANGE * N.RANGE then
                sendServerCommand(p, "HARMONIE_HM_Sound", "play", { id = id, sfx = sfx, group = group or "cough" })
                n = n + 1
            end
        end
        if HMLogOnce then HMLogOnce("soundnet:" .. tostring(sfx), "Sound", "relaying %s to nearby clients (%d this time; logged once per sound)", tostring(sfx), n) end
    elseif HM_Sound and HM_Sound.playOn then
        HM_Sound.playOn(player, sfx, group or "cough")
    elseif player.playSound then
        player:playSound(sfx)
    end
end

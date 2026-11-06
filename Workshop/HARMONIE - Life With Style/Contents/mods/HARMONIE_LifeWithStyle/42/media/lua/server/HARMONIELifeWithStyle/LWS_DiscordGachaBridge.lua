--[[
    HARMONIE - Life With Style : Discord gacha delivery bridge (server only)

    The KnoxCoin Discord bot writes RWZ_GachaDeliveryInbox.txt into this server's
    Lua folder over SFTP (the same link as the other RWZ bridges). One line per roll:
        <roll id> TAB <PZ username, %XX encoded> TAB gacha|pet TAB <gacha item id | pet piece id>
    Every 10 s the server grants each roll id it has not seen before and remembers
    the id in the same ModData ("HARMONIE_LWS".discordGacha) as the wardrobe itself:
      * a resent inbox never gives twice;
      * a world rollback forgets the item and the id together, and the bot keeps
        resending delivered rolls for 7 days, so the item comes back.
    Answer, RWZ_GachaDeliveryReceipts.txt:  <roll id> TAB OK | REJECT TAB <reason>
    Both files start with a header and end with "END <count>"; a file cut short
    is ignored until the next read. Only Life With Style's own gacha items and
    pets can be granted -- anything else is rejected and logged.
]]--

require "HARMONIELifeWithStyle/LWS_Core"
require "HARMONIELifeWithStyle/LWS_GachaData"
require "HARMONIELifeWithStyle/LWS_Server"

local INBOX, RECEIPTS = "RWZ_GachaDeliveryInbox.txt", "RWZ_GachaDeliveryReceipts.txt"
local INBOX_HEADER, RECEIPT_HEADER = "RWZ_GACHA_INBOX v1", "RWZ_GACHA_RECEIPTS v1"
local POLL_MS = 10000
local log = function(...) LWS.log("DiscordGacha", ...) end

local function decode(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function split(line)
    local parts = {}
    for part in (line .. "\t"):gmatch("([^\t]*)\t") do parts[#parts + 1] = part end
    return parts
end

local function readInbox()
    local reader
    if not pcall(function() reader = getFileReader(INBOX, false) end) or not reader then return nil end
    local lines = {}
    pcall(function()
        while true do
            local line = reader:readLine()
            if not line then break end
            line = line:gsub("\r$", "")
            if line ~= "" then lines[#lines + 1] = line end
        end
    end)
    pcall(function() reader:close() end)
    if lines[1] ~= INBOX_HEADER then return nil end
    local tail = split(lines[#lines] or "")
    if tail[1] ~= "END" or tonumber(tail[2]) ~= #lines - 2 then return nil end
    local rows = {}
    for i = 2, #lines - 1 do rows[#rows + 1] = split(lines[i]) end
    return rows
end

local function grant(user, kind, target)
    if user == "" or #user > 64 then return false, "bad username" end
    local key = "u:" .. user
    if kind == "gacha" then
        if not LWS.GACHA_ITEM[target] then return false, "not a gacha item" end
        local o = LWS.Server.owner(key, true)
        o.gacha = o.gacha or {}
        o.gacha[target] = (o.gacha[target] or 0) + 1
        local player = LWS.Server.onlineByKey(key)
        if player and LWS.Gacha then
            LWS.toClient(player, "GachaState", LWS.Gacha.stateOf(o))
            LWS.toClient(player, "Msg", { key = "IGUI_LWSG_Msg_Got", arg = LWS.T("IGUI_LWSG_Name_" .. target), text = true })
        end
        return true
    elseif kind == "pet" then
        local piece = LWS.PIECE[target]
        if not piece or not piece.pet or not LWS.isOurPiece(target) then return false, "not a pet piece" end
        local o = LWS.Server.owner(key, true)
        local uid = tostring(o.nextId)
        o.nextId = o.nextId + 1
        local gt = getGameTime and getGameTime()
        o.items[uid] = { p = target, at = gt and math.floor(gt:getWorldAgeHours()) or 0, by = "Discord Gacha" }
        local player = LWS.Server.onlineByKey(key)
        if player then
            LWS.Server.sendState(player, o)
            LWS.toClient(player, "Msg", { key = "IGUI_LWS_Msg_Got", arg = target })
        end
        return true
    end
    return false, "unknown kind"
end

local lastReceipts
local function writeReceipts(lines)
    local text = table.concat(lines, "\n")
    if text == lastReceipts then return end
    local writer
    local ok, err = pcall(function()
        writer = getFileWriter(RECEIPTS, true, false)
        writer:writeln(RECEIPT_HEADER)
        for _, line in ipairs(lines) do writer:writeln(line) end
        writer:writeln("END\t" .. tostring(#lines))
    end)
    if writer then pcall(function() writer:close() end) end
    if ok then lastReceipts = text else log("could NOT write %s: %s", RECEIPTS, tostring(err)) end
end

local function poll()
    local rows = readInbox()
    if not rows then return end
    local db = LWS.Server.db()
    db.discordGacha = db.discordGacha or {}
    local seen = db.discordGacha
    local out = {}
    for _, r in ipairs(rows) do
        local id = r[1]
        if id and id:match("^%d+$") and #id <= 25 then
            if not seen[id] then
                local user, kind, target = decode(r[2] or ""), r[3] or "", r[4] or ""
                local okCall, ok, why = pcall(grant, user, kind, target)
                if not okCall then
                    -- an engine error is not the player's fault: no mark, try again next poll
                    log("roll %s for %s FAILED, will retry: %s", id, user, tostring(ok))
                elseif ok then
                    seen[id] = "OK"
                    log("roll %s: GAVE %s %s to %s", id, kind, target, user)
                else
                    seen[id] = "REJECT " .. tostring(why)
                    log("roll %s REJECTED (%s): %s %s for %s", id, tostring(why), kind, target, user)
                end
            end
            local state = seen[id]
            if state == "OK" then
                out[#out + 1] = id .. "\tOK"
            elseif state then
                out[#out + 1] = id .. "\tREJECT\t" .. state:sub(8)
            end
        end
    end
    writeReceipts(out)
end

local nextPoll = 0
local function onTick()
    local t = getTimestampMs and getTimestampMs() or 0
    if t < nextPoll then return end
    nextPoll = t + POLL_MS
    local ok, err = pcall(poll)
    if not ok then LWS.logOnce("dgpoll", "DiscordGacha", "poll FAILED: %s", tostring(err)) end
end

if Events and Events.OnTick and isServer and isServer() and not LWS.DiscordGachaBridge then
    LWS.DiscordGachaBridge = true
    Events.OnTick.Add(onTick)
    log("Discord gacha bridge on: %s -> %s every %d s", INBOX, RECEIPTS, POLL_MS / 1000)
end

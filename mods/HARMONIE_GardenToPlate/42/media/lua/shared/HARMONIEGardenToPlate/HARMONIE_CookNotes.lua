--[[
    HARMONIE - From Garden to Plate: the cook's note (GTP 1.8.0, owner
    2026-11-20). The cook of a dish can leave a short note for whoever eats
    it; the eater sees it on a sheet of paper before the first bite
    (client/HARMONIE_CookNoteUI.lua). Who ate whose food is told to both.

    Data: the note lives in the dish's own record,
        modData.HARMONIE_Dish.note = { t = text, by = username, id = "..." }
    written ONLY by the authority (SP / MP server), like the score:
      * "note" {id, text}: the item must be within this player's reach (body,
        bags, the room's boxes: a pot on the stove), have a dish record whose
        cook (dish.chef) is this player; text cleaned (control characters out,
        at most N.MAX_LINES lines and N.MAX_CHARS letters); one per 1.5 s.
        An empty text removes the note. The final record goes back with
        R.sendSet (what = "note"), which the client copies.
      * the note follows the dish while the SAME cook keeps adding to it or
        crafts it further (HARMONIE_Prep.lua carries it); another cook's
        addition drops it (it is their dish then).
    Eating (HARMONIE_CookBuffs.lua eat wrapper, authority): N.onEaten tells
    the eater "you ate food made by X" and an online cook "Y enjoyed your
    food" (+ the Chef XP when some was given), once per eater + dish per
    10 real minutes (a dish is eaten in several bites).
]]--

require "HARMONIEGardenToPlate/HARMONIE_Prep"
require "HARMONIEGardenToPlate/HARMONIE_CookCore"

HARMONIE_GTP = HARMONIE_GTP or {}
local N = {}
HARMONIE_GTP.CookNotes = N
local R = HARMONIE_GTP.Prep
local K = HARMONIE_GTP.Cook

N.NET = "HARMONIE_GTP_Note"
N.MAX_CHARS = 120
N.MAX_LINES = 4
N.RATE_MS = 1500
N.EAT_NOTICE_MS = 10 * 60 * 1000

local function log(fmt, ...) if HARMONIE_GTP.Log then HARMONIE_GTP.Log("Note", fmt, ...) end end
local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
local function nameOf(p) return tostring(call(p, "getUsername") or "?") end
local function typeOf(it) return tostring(call(it, "getFullType") or "?") end
local function nowMs() return getTimestampMs and getTimestampMs() or 0 end
local function isClientSide() return isClient and isClient() end
local function isServerSide() return isServer and isServer() end

-- whole UTF-8 characters
local function chars(s)
    local out = {}
    for ch in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = ch end
    return out
end
function N.len(s) return #chars(s) end

-- what may be stored: no control characters (a new line is kept), at most
-- MAX_LINES lines and MAX_CHARS letters, no spaces at the ends
function N.clean(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("[%z\1-\9\11-\31\127]", "")
    local lines = {}
    for line in (s .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        -- no blank line first, never two blank lines in a row
        if line ~= "" or (#lines > 0 and lines[#lines] ~= "") then lines[#lines + 1] = line end
        if #lines >= N.MAX_LINES then break end
    end
    while #lines > 0 and lines[#lines] == "" do lines[#lines] = nil end
    s = table.concat(lines, "\n")
    local c = chars(s)
    if #c > N.MAX_CHARS then
        local keep = {}
        for i = 1, N.MAX_CHARS do keep[i] = c[i] end
        s = table.concat(keep):gsub("%s+$", "")
    end
    return s
end

function N.noteOf(item)
    local d = R.dishOf(item)
    local n = d and d.note
    if type(n) == "table" and type(n.t) == "string" and n.t ~= "" then return n end
    return nil
end
-- only the dish's cook writes on it
function N.canWrite(player, item)
    local d = R.dishOf(item)
    return d ~= nil and d.chef ~= nil and d.chef == nameOf(player)
end

local function findItem(player, id)
    id = tonumber(id)
    if not id then return nil end
    local it = K.findInInventory and K.findInInventory(player, id)
    if it then return it end
    if HARMONIE_Reach and HARMONIE_Reach.findById then
        if HARMONIE_Reach.forget then pcall(HARMONIE_Reach.forget, player) end
        local ok, r = pcall(HARMONIE_Reach.findById, player, id)
        if ok then return r end
    end
    return nil
end

-- ------------------------------------------------------------ authority
N.last = {}
function N.serveNote(player, args)
    args = type(args) == "table" and args or {}
    local who = nameOf(player)
    local t = nowMs()
    if t - (N.last[who] or 0) < N.RATE_MS then log("note from %s: too fast -- rejected", who); return false, "fast" end
    local item = findItem(player, args.id)
    if not item then log("note from %s: item id %s not within reach -- rejected", who, tostring(args.id)); return false, "missing" end
    local md = call(item, "getModData")
    local d = md and md.HARMONIE_Dish
    if type(d) ~= "table" then log("note from %s on %s: not a scored dish -- rejected", who, typeOf(item)); return false, "noDish" end
    if d.chef ~= who then log("note from %s on %s: the cook is %s -- rejected", who, typeOf(item), tostring(d.chef)); return false, "notChef" end
    N.last[who] = t
    local text = N.clean(args.text)
    if text == "" then
        d.note = nil
        log("%s removed the note on %s (id %s)", who, typeOf(item), tostring(args.id))
    else
        d.note = { t = text, by = who, id = who .. ":" .. tostring(call(item, "getID")) .. ":" .. tostring(t) }
        log("%s left a note on %s (id %s, %d letters)", who, typeOf(item), tostring(args.id), N.len(text))
    end
    md.HARMONIE_Dish = d
    if R.sendSet then R.sendSet(player, item, "note") end
    return true
end

-- the dish was eaten: tell the eater and its cook (authority side)
N.told = {}   -- eater|itemId -> ms
local function onlinePlayer(username)
    local list = getOnlinePlayers and getOnlinePlayers()
    for i = 0, (list and list:size() or 0) - 1 do
        local p = list:get(i)
        if p and nameOf(p) == username then return p end
    end
    return nil
end
function N.onEaten(eater, dish, item, xp)
    local chef = type(dish) == "table" and dish.chef or nil
    local who = nameOf(eater)
    if not chef or chef == who then return false end
    local key = who .. "|" .. tostring(call(item, "getID"))
    local t = nowMs()
    if N.told[key] and t - N.told[key] < N.EAT_NOTICE_MS then return false end
    N.told[key] = t
    log("%s ate food made by %s%s", who, chef, xp and string.format(" (+%.1f Cooking XP to the cook)", xp) or "")
    if isServerSide() and sendServerCommand then
        pcall(sendServerCommand, eater, N.NET, "ateOf", { chef = chef })
        local cp = onlinePlayer(chef)
        if cp then pcall(sendServerCommand, cp, N.NET, "likedBy", { eater = who, xp = xp }) end
    elseif N.onNotice then
        pcall(N.onNotice, "ateOf", { chef = chef })
    end
    return true
end

-- ------------------------------------------------------------ network
if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= N.NET or not player then return end
        if command == "note" then
            local ok, why = N.serveNote(player, args)
            if not ok and sendServerCommand then
                pcall(sendServerCommand, player, N.NET, "refused", { id = type(args) == "table" and args.id or nil, why = why })
            end
        else
            log("%s sent unknown note command %s -- dropped", nameOf(player), tostring(command))
        end
    end)
end

if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= N.NET or type(args) ~= "table" then return end
        if command == "refused" then
            log("server refused the note on item id %s: %s", tostring(args.id), tostring(args.why))
            if N.onRefused then pcall(N.onRefused, args) end
        elseif command == "ateOf" or command == "likedBy" then
            log("notice %s: %s", command, tostring(args.chef or args.eater))
            if N.onNotice then pcall(N.onNotice, command, args) end
        end
    end)
end

-- client side: write / remove a note (SP: done at once)
function N.request(player, item, text)
    local args = { id = call(item, "getID"), text = N.clean(text) }
    if isClientSide() then
        sendClientCommand(player, N.NET, "note", args)
        log("asked the server to %s the note on %s (id %s)", args.text == "" and "remove" or "write", typeOf(item), tostring(args.id))
        return true
    end
    local ok, why = N.serveNote(player, args)
    if not ok and N.onRefused then pcall(N.onRefused, { id = args.id, why = why }) end
    if ok and R.onSet then pcall(R.onSet, { id = args.id, what = "note" }, item) end
    return ok
end

log("cook's notes loaded (max %d letters, %d lines)", N.MAX_CHARS, N.MAX_LINES)

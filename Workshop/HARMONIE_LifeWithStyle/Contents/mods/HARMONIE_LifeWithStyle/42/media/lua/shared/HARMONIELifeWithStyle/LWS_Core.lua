--[[
    HARMONIE - Life With Style : shared core

    Owner, 2026-10-20: a fashion mod for the server. Pieces never spawn in
    the world; an admin gives them. They belong to the PLAYER (the account,
    later a Discord account), never drop, never leave the player, and stay
    after death. A separate wardrobe window holds them and a separate set of
    fashion slots wears them; the picture replaces the vanilla clothes of
    that slot.

    How (see LWS_Server.lua):
      * the wardrobe is a list kept on the server (global ModData), by owner
        key -- the pieces in it are not items at all;
      * a piece being WORN is a weightless, protectionless clothing item in
        the mod's own body location lws:<slot> (registries.lua), made by the
        server and worn by the client (The Only Cure's pattern). lws:<slot>
        hides the vanilla body locations of that slot (setHideModel,
        LWS_BodyLocations.lua): the real clothes keep protecting and warming,
        they are just not drawn -- nothing pokes through;
      * the _Over twin (lws:<slot>_over) hides nothing: "show my real
        clothes" for that slot.

    Here: logging, the owner key, catalog / slot lookups, the network helpers
    (the same code runs in single player, where client and server are one).
]]--

require "HARMONIELifeWithStyle/LWS_Data"

LWS = LWS or {}
LWS.NET = "HARMONIE_LWS"
LWS.VERSION = 1

-- ------------------------------------------------------------- logging
local function side()
    if isServer and isServer() then return "server" end
    if isClient and isClient() then return "client" end
    return "SP"
end
function LWS.log(tag, fmt, ...)
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    print("[HARMONIE_LWS][" .. tostring(tag) .. "][" .. side() .. "] " .. (ok and msg or tostring(fmt)))
end
LWS.logSeen = LWS.logSeen or {}
function LWS.logOnce(key, tag, fmt, ...)
    if LWS.logSeen[key] then return end
    LWS.logSeen[key] = true
    LWS.log(tag, fmt, ...)
end
function LWS.name(p)
    if not p then return "?" end
    local ok, n = pcall(function() return p:getUsername() end)
    if ok and n and n ~= "" then return tostring(n) end
    ok, n = pcall(function() return p:getDisplayName() end)
    return ok and tostring(n) or "?"
end
function LWS.typeOf(item)
    local ok, t = pcall(function() return item:getFullType() end)
    return ok and tostring(t) or "?"
end

-- ------------------------------------------------------------- lookups
LWS.SLOT = {}
for i, s in ipairs(LWS.SLOTS) do s.order = i; LWS.SLOT[s.id] = s end
LWS.PIECE = {}
for _, c in ipairs(LWS.CATALOG) do LWS.PIECE[c.id] = c end

-- the worn item of a piece: <module>.<id> hides the vanilla clothes, <id>_Over shows them
function LWS.carrierType(pieceId, showReal)
    return LWS.MODULE .. "." .. tostring(pieceId) .. (showReal and "_Over" or "")
end

-- full type "HARMONIE_LWS.<id>[_Over]" -> id, over?
function LWS.parseType(fullType)
    local id = tostring(fullType or ""):match("^" .. LWS.MODULE .. "%.(.+)$")
    if not id then return nil end
    local base = id:match("^(.-)_Over$")
    if base and LWS.PIECE[base] then return base, true end
    if LWS.PIECE[id] then return id, false end
    return nil
end

-- a piece of OUR catalog whose item script is in OUR module -- nothing of
-- another mod ever goes into the wardrobe (owner, 2026-10-20)
function LWS.isOurPiece(pieceId)
    pieceId = tostring(pieceId or "")
    if not LWS.PIECE[pieceId] then return false end
    if not getScriptManager then return true end
    local ok, it = pcall(function() return getScriptManager():FindItem(LWS.MODULE .. "." .. pieceId) end)
    if not ok then return true end
    if not it then return false end
    local okM, m = pcall(function() return it:getModuleName() end)
    if okM and m then return tostring(m) == LWS.MODULE end
    return true
end

function LWS.isFashion(item)
    if not item then return false end
    local ok, m = pcall(function() return item:getModule() end)
    if ok and m then return tostring(m) == LWS.MODULE end
    return LWS.typeOf(item):sub(1, #LWS.MODULE + 1) == LWS.MODULE .. "."
end

-- ------------------------------------------------------------- owner
-- One key per owner. Now: the account name in multiplayer, the save itself
-- in single player (a new character in the same save gets the wardrobe
-- back). Later: a Discord account -- LWS.ownerKey is the only place that
-- will change (owner, 2026-10-20: "ในอนาคตจะเป็นบัญชีดิสคอร์ด").
function LWS.ownerKey(player)
    if not player then return nil end
    if (isServer and isServer()) or (isClient and isClient()) then
        local ok, u = pcall(function() return player:getUsername() end)
        if ok and u and u ~= "" then return "u:" .. tostring(u) end
        return nil
    end
    return "sp:local"
end

function LWS.isAdmin(player)
    if not player then return false end
    if isDebugEnabled and isDebugEnabled() then return true end
    if not (isServer and isServer()) and not (isClient and isClient()) then return true end -- single player
    local ok, a = pcall(function() return player:isAccessLevel("admin") end)
    if ok and a then return true end
    local ok2, lvl = pcall(function() return player:getAccessLevel() end)
    lvl = ok2 and lvl and tostring(lvl):lower() or "none"
    if lvl == "admin" or lvl == "moderator" or lvl == "overseer" then return true end
    if isClient and isClient() and isAdmin then
        local ok3, me = pcall(isAdmin)
        if ok3 and me then return true end
    end
    return false
end

-- ------------------------------------------------------------- texts
function LWS.T(key, ...)
    local ok, s = pcall(getText, key, ...)
    if ok and s and s ~= key then return s end
    return key
end
function LWS.slotName(slot) return LWS.T("IGUI_LWS_Slot_" .. tostring(slot)) end
function LWS.pieceName(pieceId)
    local key = LWS.MODULE .. "." .. tostring(pieceId)
    local ok, it = pcall(function() return getScriptManager():FindItem(key) end)
    if ok and it then
        local ok2, n = pcall(function() return it:getDisplayName() end)
        if ok2 and n and n ~= "" then return tostring(n) end
    end
    return tostring(pieceId)
end

-- ------------------------------------------------------------- network
-- In single player the client and the server are the same Lua state: the
-- calls go straight to the other side (no network).
local function mp() return (isServer and isServer()) or (isClient and isClient()) end
function LWS.toServer(player, command, args)
    args = args or {}
    if isClient and isClient() then
        sendClientCommand(player, LWS.NET, command, args)
    elseif LWS.Server and LWS.Server.handle then
        LWS.Server.handle(player, command, args)
    else
        LWS.logOnce("noserver", "Net", "no server side loaded: %s dropped", tostring(command))
    end
end
function LWS.toClient(player, command, args)
    args = args or {}
    if isServer and isServer() then
        sendServerCommand(player, LWS.NET, command, args)
    elseif not mp() and LWS.Client and LWS.Client.handle then
        LWS.Client.handle(command, args)
    end
end

return LWS

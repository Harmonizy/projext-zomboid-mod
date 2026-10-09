--[[
    HARMONIE Hub boot (the same file in every HARMONIE mod -- the game loads
    one copy of a path; master copy: mods/_HarmonieHub, install.sh).

    HARMONIE_Ours(fn, tag) wraps one of OUR right-click handlers
    (Events.OnFill...ContextMenu.Add(HARMONIE_Ours(handler, "TWA"))): every
    option the handler adds to the menu is marked as ours and gets the
    HARMONIE "H" icon (owner, 2026-10-09: "คลิกขวาทุกๆอันที่มาจากม็อด HARMONIE
    ของเรา เป็นรูปตัว H ให้หมด"). HARMONIE_Hub.lua (client) then keeps all
    marked options together in one block, so no other mod's option sits
    between ours ("ทำให้คลิกขวาของเรารวมอยู่ติดกันเสมอ").

    shared/ and "000_" so it loads before any of our files that register a
    handler (some are in shared/). Never breaks a handler: it only reads
    the menu before and after.
]]--

HARMONIE_HubBoot = HARMONIE_HubBoot or {}
local B = HARMONIE_HubBoot
B.VERSION = 1

function B.icon()
    if B.tex == nil then
        local ok, t = pcall(function() return getTexture("media/ui/HARMONIE_H.png") end)
        B.tex = (ok and t) or false
        if not B.tex then print("[HARMONIE_Hub] the H icon (media/ui/HARMONIE_H.png) did not load -- options stay without it") end
    end
    return B.tex or nil
end

-- every option of `context` added since `before` (a set of the options
-- that were there) is ours: mark it, give it the H
function B.markNew(context, before, tag)
    local opts = type(context) == "table" and context.options
    if type(opts) ~= "table" then return 0 end
    local icon = B.icon()
    local n = 0
    for _, o in ipairs(opts) do
        if type(o) == "table" and not before[o] then
            o.harmonie = tag or "HARMONIE"
            if icon then o.iconTexture = icon end
            n = n + 1
        end
    end
    return n
end

function B.snapshot(context)
    local before = {}
    local opts = type(context) == "table" and context.options
    if type(opts) == "table" then
        for _, o in ipairs(opts) do before[o] = true end
    end
    return before
end

-- wraps a right-click handler (playerNum, context, ...) -> same handler
function HARMONIE_Ours(fn, tag)
    if type(fn) ~= "function" then return fn end
    return function(playerNum, context, a, b, c, d)
        local before = B.snapshot(context)
        local r = fn(playerNum, context, a, b, c, d)
        B.markNew(context, before, tag)
        return r
    end
end

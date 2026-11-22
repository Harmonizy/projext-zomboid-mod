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
B.VERSION = 2

function B.icon()
    if B.tex == nil then
        local ok, t = pcall(function() return getTexture("media/ui/HARMONIE_H.png") end)
        B.tex = (ok and t) or false
        if not B.tex then print("[HARMONIE_Hub] the H icon (media/ui/HARMONIE_H.png) did not load -- options stay without it") end
    end
    return B.tex or nil
end

-- Hub 5.2 (owner 2026-11-22: "each mod's right-click options in that mod's
-- colour"): the handler's tag picks the H of its mod -- the same pictures as
-- the "HARMONIE: open a tab" rows (media/ui/HARMONIE_H_<card id>.png, from
-- tools/gen_h_icons.py, the Hub.CARDS accents). The hub's own options (HUB)
-- and the debug menu keep the gold H; a missing picture falls back to it.
B.TAG_CARD = { GTP = "gtp", TWA = "twa", HM = "hm", SVU = "svu", MFS = "mfs", MIL = "mfs", LWS = "lws" }
B.tagTex = B.tagTex or {}
function B.iconFor(tag)
    local card = tag and B.TAG_CARD[tag]
    if not card then return B.icon() end
    local t = B.tagTex[card]
    if t == nil then
        local ok, tx = pcall(function() return getTexture("media/ui/HARMONIE_H_" .. card .. ".png") end)
        t = (ok and tx) or false
        B.tagTex[card] = t
        if not t then print("[HARMONIE_Hub] media/ui/HARMONIE_H_" .. card .. ".png did not load -- " .. tostring(tag) .. " options keep the gold H") end
    end
    return t or B.icon()
end
-- true for the gold H and every mod-coloured H we hand out
function B.isOurIcon(tex)
    if tex == nil or tex == false then return false end
    if tex == B.icon() then return true end
    for _, t in pairs(B.tagTex) do if t and t == tex then return true end end
    return false
end

-- every option of `context` added since `before` (a set of the options
-- that were there) is ours: mark it, give it the H
function B.markNew(context, before, tag)
    local opts = type(context) == "table" and context.options
    if type(opts) ~= "table" then return 0 end
    local icon = B.iconFor(tag)
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

-- Debug registry (2026-10-11, owner: "ทุกม็อดต้องมีดีบักให้ ดีบักเปิดให้เห็นเฉพาะคน
-- ที่เป็นแอดมินหรือเปิด debug" / "เอา ดีบัก TOC ไปรวมใน ดีบัก HARMONIE"): any
-- of our mods (and the bundled ones, like The Only Cure) adds its admin /
-- -debug options to the ONE "HARMONIE debug" right-click menu instead of a
-- menu of its own. fn(add, player, target):
--   add(label, function(player) ... end)   -- one option
--   target = nil for the general part, or another player the click was on
--            (then the options go under that player's name)
-- HARMONIE_Hub.lua draws them, admins and -debug only.
HARMONIE_HubDebug = HARMONIE_HubDebug or {}
function HARMONIE_RegisterDebug(id, fn)
    if type(id) ~= "string" or type(fn) ~= "function" then return end
    for _, e in ipairs(HARMONIE_HubDebug) do
        if e.id == id then e.fn = fn; return end
    end
    HARMONIE_HubDebug[#HARMONIE_HubDebug + 1] = { id = id, fn = fn }
end

--[[
    HARMONIE Hub: the admin TEST button in every window and tab (the same file
    in every HARMONIE mod; master copy mods/_HarmonieHub, install.sh).

    Owner, 2026-11-12: "ในทุกหน้าต่างและแท็บให้มีปุ่มที่แอดมินสามารถกดเพื่อทดสอบ
    อะไรต่างๆได้ เอาให้ครบทุกม็อด".

    A flask button sits in the header of each of our windows, left of the
    header buttons -- shown to admins and -debug only (HARMONIE_Hub.isAdmin).
    It opens a list of tests for the window's CURRENT tab (and the ones for
    every tab of that window). Each mod registers its own:

      HARMONIE_AdminTest.register(mod, tab, {           -- tab "*" = every tab
          { key = "IGUI_X_Test_Y", fallback = "Give ...", run = function(player, ctx) ... end },
      })
      HARMONIE_AdminTest.serverOp(name, function(player, args) ... end)
      HARMONIE_AdminTest.send(player, name, args)       -- runs a server op
      HARMONIE_AdminTest.give(player, { {"Base.Apple", 3}, ... })
      HARMONIE_AdminTest.decorate(WindowClass, {
          mod = "gtp",
          tab = function(win) return win.tab end,       -- current tab id
          rect = function(win) return x, y, size end,    -- where the button goes
          player = function(win) return win.player end,
          ctx = function(win) return { ... } end,        -- optional, passed to run()
      })

    Multiplayer: everything that changes the world (items, skills, health,
    illness...) is a SERVER op: the client sends "HARMONIE_AdminTest" and the
    server runs it only when the SENDER is an admin (access level / role
    admin; the server's own -debug flag), then sends what changed
    (sendAddItemToContainer, sendItemStats...). Single player runs the op at
    once. Every test pressed, every op run and every refusal is logged
    ([HARMONIE_Hub][AdminTest]).
]]--

if HARMONIE_AdminTest and HARMONIE_AdminTest.loaded then return end
HARMONIE_AdminTest = HARMONIE_AdminTest or {}
local AT = HARMONIE_AdminTest
AT.loaded = true
AT.MODULE = "HARMONIE_AdminTest"
AT.tests = AT.tests or {}
AT.OPS = AT.OPS or {}
AT.MAX_GIVE = 100

local function log(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print("[HARMONIE_Hub][AdminTest] " .. (ok and s or tostring(fmt)))
end
AT.log = log
local function call(o, m, ...)
    if not o or type(o[m]) ~= "function" then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
local function nameOf(p) return tostring(call(p, "getUsername") or "?") end
local function isServerSide() return isServer and isServer() end
local function pureClient() return isClient and isClient() and not isServerSide() end

function AT.T(key, fallback, ...)
    if not getText or not key then return fallback or key end
    local ok, s
    if select("#", ...) > 0 then ok, s = pcall(getText, key, ...) else ok, s = pcall(getText, key) end
    if not ok or not s or s == key then return fallback or key end
    return s
end

-- --------------------------------------------------------------- who is an admin
-- client: the hub's rule (admin access level / role, isAdmin(), -debug)
function AT.isAdmin(player)
    local Hub = HARMONIE_Hub
    if Hub and Hub.isAdmin then return Hub.isAdmin(player) end
    if getDebug and getDebug() then return true, "debug" end
    return false, "no hub"
end

-- server: the SENDER's access level or role (isAdmin() describes the server)
function AT.serverAllows(player)
    if not isServerSide() then return true, "single player" end
    if isDebugEnabled then
        local ok, d = pcall(isDebugEnabled)
        if ok and d then return true, "server -debug" end
    end
    local lvl = string.lower(tostring(call(player, "getAccessLevel") or ""))
    if lvl == "admin" then return true, "access level admin" end
    local role = call(player, "getRole")
    local rname = role and string.lower(tostring(call(role, "getName") or role)) or ""
    if rname == "admin" then return true, "role admin" end
    return false, "access level '" .. lvl .. "', role '" .. rname .. "'"
end

-- --------------------------------------------------------------- registry
function AT.register(mod, tab, list)
    if type(mod) ~= "string" or type(list) ~= "table" then return end
    tab = tab or "*"
    AT.tests[mod] = AT.tests[mod] or {}
    AT.tests[mod][tab] = AT.tests[mod][tab] or {}
    local into = AT.tests[mod][tab]
    for _, t in ipairs(list) do
        local replaced = false
        for i, old in ipairs(into) do
            if old.key == t.key then into[i] = t; replaced = true end
        end
        if not replaced then into[#into + 1] = t end
    end
end

function AT.serverOp(name, fn)
    if type(name) == "string" and type(fn) == "function" then AT.OPS[name] = fn end
end

-- run a server op: SP at once, MP through the server
function AT.send(player, name, args)
    args = type(args) == "table" and args or {}
    if pureClient() then
        sendClientCommand(player, AT.MODULE, name, args)
        log("%s asked the server: %s", nameOf(player), name)
        return true
    end
    local op = AT.OPS[name]
    if not op then log("op %s is not registered", tostring(name)); return false end
    local ok, err = pcall(op, player, args)
    if not ok then log("op %s FAILED: %s", name, tostring(err)) end
    return ok
end

function AT.onClientCommand(module, command, player, args)
    if module ~= AT.MODULE then return end
    local allowed, why = AT.serverAllows(player)
    if not allowed then log("%s asked for %s but is not an admin (%s) -- refused", nameOf(player), tostring(command), why); return end
    local op = AT.OPS[command]
    if not op then log("%s asked for unknown op %s", nameOf(player), tostring(command)); return end
    local ok, err = pcall(op, player, type(args) == "table" and args or {})
    if ok then log("%s ran %s (%s)", nameOf(player), tostring(command), why)
    else log("%s: op %s FAILED: %s", nameOf(player), tostring(command), tostring(err)) end
end

-- --------------------------------------------------------------- built-in server ops
-- give items: args.items = { {type, count}, ... }
AT.serverOp("give", function(player, args)
    local inv = call(player, "getInventory")
    if not inv then return end
    local sm = getScriptManager and getScriptManager()
    local given = {}
    for _, e in ipairs(type(args.items) == "table" and args.items or {}) do
        local t, n = tostring(e[1] or e.type or ""), math.max(1, math.min(AT.MAX_GIVE, math.floor(tonumber(e[2] or e.n) or 1)))
        if sm and call(sm, "FindItem", t) then
            for _ = 1, n do
                local it = call(inv, "AddItem", t)
                if it and sendAddItemToContainer then pcall(sendAddItemToContainer, inv, it) end
            end
            given[#given + 1] = t .. " x" .. n
        else
            log("give: %s is not an item -- skipped", t)
        end
    end
    log("gave %s: %s", nameOf(player), #given > 0 and table.concat(given, ", ") or "nothing")
end)

-- a perk to a level: args.perk = "Doctor", args.level = 0..10 (or "max")
AT.serverOp("skill", function(player, args)
    local perk = Perks and Perks[tostring(args.perk)]
    if not perk then log("skill: no perk %s", tostring(args.perk)); return end
    local target = args.level == "max" and 10 or math.max(0, math.min(10, math.floor(tonumber(args.level) or 0)))
    local cur = tonumber(call(player, "getPerkLevel", perk)) or 0
    for _ = cur + 1, target do pcall(function() player:LevelPerk(perk) end) end
    for _ = target + 1, cur do pcall(function() player:LoseLevel(perk) end) end
    pcall(function() player:getXp():setXPToLevel(perk, target) end)
    if isServerSide() and SyncXp then pcall(SyncXp, player) end
    log("%s: %s %d -> %d", nameOf(player), tostring(args.perk), cur, target)
end)

-- --------------------------------------------------------------- client helpers
function AT.give(player, items) return AT.send(player, "give", { items = items }) end
function AT.skill(player, perk, level) return AT.send(player, "skill", { perk = perk, level = level }) end

-- the tests of a window's tab: that tab's, then the window's "*" ones
function AT.list(mod, tab)
    local out = {}
    local m = AT.tests[mod] or {}
    for _, t in ipairs(m[tab or ""] or {}) do out[#out + 1] = t end
    if tab ~= "*" then for _, t in ipairs(m["*"] or {}) do out[#out + 1] = t end end
    return out
end

function AT.open(mod, tab, player, ctx)
    local admin, why = AT.isAdmin(player)
    if not admin then log("%s pressed the test button without admin rights (%s)", nameOf(player), tostring(why)); return end
    if not HARMONIE_SettingsUI then log("no settings window (UIKit) -- test list not shown"); return end
    local tests = AT.list(mod, tab)
    log("%s opened the tests of %s > %s (%d)", nameOf(player), tostring(mod), tostring(tab), #tests)
    HARMONIE_SettingsUI.open(AT.T("IGUI_HUB_Test_Title", "Admin tests") .. " - " .. tostring(mod) .. " / " .. tostring(tab), function()
        local rows = { { kind = "note", label = AT.T("IGUI_HUB_Test_Note", "Admins only. Changes are made by the server and are real: use a test character or a test server.") } }
        if #tests == 0 then rows[#rows + 1] = { kind = "note", label = AT.T("IGUI_HUB_Test_None", "No tests for this tab.") } end
        for i, t in ipairs(tests) do
            local label = AT.T(t.key, t.fallback or t.key)
            rows[#rows + 1] = { kind = "button", id = "test_" .. i, label = label, tip = t.tip and AT.T(t.tip, t.tipFallback) or label,
                text = AT.T("IGUI_HUB_Test_Run", "Run"),
                run = function()
                    log("%s: test %s > %s > %s", nameOf(player), tostring(mod), tostring(tab), tostring(t.key))
                    local ok, err = pcall(t.run, player, ctx or {})
                    if not ok then log("test %s FAILED: %s", tostring(t.key), tostring(err)) end
                end }
        end
        return rows
    end)
end

-- --------------------------------------------------------------- the button
local testTex
local function testIcon()
    if testTex == nil then
        local ok, t = pcall(getTexture, "media/ui/HARMONIE_icon_test.png")
        testTex = (ok and t) or false
    end
    return testTex or nil
end

function AT.decorate(cls, opts)
    if type(cls) ~= "table" or type(opts) ~= "table" or cls.hmAdminTestDecorated then return end
    cls.hmAdminTestDecorated = true
    local function playerOf(win) return (opts.player and opts.player(win)) or win.player or (getPlayer and getPlayer()) end
    local function rectOf(win)
        local ok, x, y, s = pcall(opts.rect, win)
        if ok and x then return x, y, s or 26 end
        return nil
    end
    local function shown(win)
        local p = playerOf(win)
        local ok, admin = pcall(AT.isAdmin, p)
        return ok and admin
    end
    local origRender = cls.render
    cls.render = function(win, ...)
        if origRender then origRender(win, ...) end
        if not shown(win) then return end
        local x, y, s = rectOf(win)
        if not x then return end
        local mx, my = win:getMouseX(), win:getMouseY()
        local over = mx >= x and mx <= x + s and my >= y and my <= y + s
        win:drawRect(x, y, s, s, over and 0.95 or 0.8, 0.18, 0.05, 0.05)
        win:drawRectBorder(x, y, s, s, over and 1 or 0.7, 0.95, 0.35, 0.3)
        local icon = testIcon()
        if icon then win:drawTextureScaled(icon, x + 2, y + 2, s - 4, s - 4, 1, 1, 1, 1)
        else win:drawText("T", x + 8, y + 4, 1, 0.5, 0.4, 1, UIFont.Small) end
        if over then
            local tip = AT.T("IGUI_HUB_Test_Button", "Admin tests for this tab")
            local tw = getTextManager():MeasureStringX(UIFont.Small, tip)
            local tx = math.max(2, math.min(x - tw / 2, win.width - tw - 8))
            win:drawRect(tx - 4, y + s + 4, tw + 8, 20, 0.9, 0.05, 0.03, 0.03)
            win:drawText(tip, tx, y + s + 6, 1, 0.85, 0.8, 1, UIFont.Small)
        end
    end
    local origDown = cls.onMouseDown
    cls.onMouseDown = function(win, x, y, ...)
        if shown(win) then
            local bx, by, s = rectOf(win)
            if bx and x >= bx and x <= bx + s and y >= by and y <= by + s then
                local okT, tab = pcall(opts.tab or function() return "*" end, win)
                local okC, ctx = pcall(opts.ctx or function() return nil end, win)
                AT.open(opts.mod, okT and tab or "*", playerOf(win), okC and ctx or nil)
                return true
            end
        end
        if origDown then return origDown(win, x, y, ...) end
        return false
    end
    log("test button on %s windows", tostring(opts.mod))
end

if Events and Events.OnClientCommand then Events.OnClientCommand.Add(AT.onClientCommand) end

return AT

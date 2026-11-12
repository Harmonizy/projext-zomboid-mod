--[[
    HARMONIE - Life With Style: admin tests for every tab of the fashion and
    gacha window (owner, 2026-11-12, 1.0.0: "ในทุกหน้าต่างและแท็บให้มีปุ่มที่
    แอดมินสามารถกดเพื่อทดสอบอะไรต่างๆได้"). The hub's flask button
    (000_HARMONIE_AdminTest) sits left of the header buttons. Pieces and gacha
    items go through LWS's own server commands (AdminGrant / AdminGachaGrant),
    which check the admin again; take things back in the Give tab.
]]--

local AT = HARMONIE_AdminTest
if not AT then print("[HARMONIE_LWS][AdminTests] no HARMONIE_AdminTest -- no admin tests"); return end

local function T(id, en, run) return { key = "IGUI_LWS_Test_" .. id, fallback = en, run = run } end
local function C() return LWS and LWS.Client end
local function me(p) return LWS and LWS.ownerKey and LWS.ownerKey(p) end

local function giveSet(p)
    local key = me(p)
    if not key or not C() then return end
    for _, c in ipairs(LWS.CATALOG or {}) do C().send("AdminGrant", { owner = key, piece = c.id }) end
    LWS.log("AdminTests", "test: the whole catalog (%d pieces) asked for", #(LWS.CATALOG or {}))
end
local function giveGacha(p, n)
    local key = me(p)
    if not key or not C() then return end
    for _, g in ipairs(LWS.GACHA_ITEMS or {}) do C().send("AdminGachaGrant", { owner = key, id = g.id, n = n or 1 }) end
    LWS.log("AdminTests", "test: %d of every gacha item (%d kinds) asked for", n or 1, #(LWS.GACHA_ITEMS or {}))
end

AT.register("lws", "*", {
    T("Give", "Open the Give tab", function(p) if LWSWindow and LWSWindow.open then LWSWindow.open(p, "admin") end end),
})
AT.register("lws", "dress", {
    T("Set", "Give yourself every fashion piece", giveSet),
})
AT.register("lws", "collection", {
    T("Set", "Give yourself every fashion piece", giveSet),
})
AT.register("lws", "gacha", {
    T("Gacha1", "Give yourself one of every gacha item", function(p) giveGacha(p, 1) end),
    T("Gacha5", "Give yourself five of every gacha item", function(p) giveGacha(p, 5) end),
})
AT.register("lws", "trade", {
    T("Set", "Give yourself every fashion piece (to trade)", giveSet),
    T("Gacha1", "Give yourself one of every gacha item", function(p) giveGacha(p, 1) end),
})
AT.register("lws", "guide", {})
AT.register("lws", "admin", {})

local function install()
    if not (LWSWindowPanel and AT.decorate) then return end
    AT.decorate(LWSWindowPanel, {
        mod = "lws",
        tab = function(win) return win.tab or "dress" end,
        rect = function(win)
            local list = win:headerButtons()
            local last = list[#list]
            return last.x - last.w - 6, last.y, last.w
        end,
    })
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(install) end

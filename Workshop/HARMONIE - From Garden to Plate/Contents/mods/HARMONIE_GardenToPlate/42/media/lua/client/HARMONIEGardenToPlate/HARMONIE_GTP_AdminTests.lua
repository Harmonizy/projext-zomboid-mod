--[[
    HARMONIE - From Garden to Plate: admin tests for every tab of the guide
    window (owner, 2026-11-12, 1.0.0: "ในทุกหน้าต่างและแท็บให้มีปุ่มที่แอดมินสามารถ
    กดเพื่อทดสอบอะไรต่างๆได้"). The hub's flask button (000_HARMONIE_AdminTest)
    sits left of the header buttons. Items come from the server (the hub's
    give op). Vitamins are kept by the player's own game and synced to the
    server (HARMONIE_GTP.VitData, like the vitamin admin panel).
]]--

local AT = HARMONIE_AdminTest
if not AT then print("[HARMONIE_GTP][AdminTests] no HARMONIE_AdminTest -- no admin tests"); return end

local function log(fmt, ...) if HARMONIE_GTP and HARMONIE_GTP.Log then HARMONIE_GTP.Log("AdminTests", fmt, ...) end end
local function T(id, en, run) return { key = "IGUI_GTP_Test_" .. id, fallback = en, run = run } end

local function setAll(p, value)
    local V = HARMONIE_GTP and HARMONIE_GTP.VitData
    if not V then return end
    local max = HARMONIE_GTP.Config and HARMONIE_GTP.Config.maxValue or 100
    if value == "max" then value = max end
    for _, vit in ipairs(HARMONIE_GTP.Vitamins or {}) do
        V.Set(p, vit, value)
        if V.RefreshAffliction then pcall(V.RefreshAffliction, p, vit) end
    end
    log("every vitamin set to %s (test)", tostring(value))
end

AT.register("gtp", "*", {
    T("Panel", "Open the vitamin admin panel (yourself)", function(p) if HARMONIE_AdminPanel and HARMONIE_AdminPanel.Open then HARMONIE_AdminPanel.Open(p) end end),
    T("Full", "Every vitamin full", function(p) setAll(p, "max") end),
    T("Low", "Every vitamin low", function(p)
        local c = HARMONIE_GTP.Config and HARMONIE_GTP.Config.criticalThreshold or 20
        setAll(p, c + 10)
    end),
    T("Critical", "Every vitamin critical", function(p) setAll(p, 5) end),
})
AT.register("gtp", "cook", {
    T("Tools", "Give cooking tools (pot, saucepan, pan, knife, bowl, spoon)", function(p)
        AT.give(p, { { "Base.Pot", 1 }, { "Base.Saucepan", 1 }, { "Base.Pan", 1 }, { "Base.KitchenKnife", 1 }, { "Base.Bowl", 2 }, { "Base.Spoon", 1 } })
    end),
    T("Ingredients", "Give basic ingredients (vegetables, meat, eggs, salt)", function(p)
        AT.give(p, { { "Base.Carrots", 3 }, { "Base.Potato", 3 }, { "Base.Onion", 2 }, { "Base.Cabbage", 1 }, { "Base.Steak", 2 },
            { "Base.Egg", 4 }, { "Base.Salt", 1 }, { "Base.Butter", 1 } })
    end),
})
AT.register("gtp", "foods", {
    T("VitFoods", "Give a food rich in each vitamin", function(p)
        AT.give(p, { { "Base.Carrots", 1 }, { "Base.Steak", 1 }, { "Base.Orange", 1 }, { "Base.Salmon", 1 }, { "Base.Avocado", 1 }, { "Base.Broccoli", 1 } })
    end),
})
AT.register("gtp", "other", {
    T("Seeds", "Give fruit seeds (apple, orange)", function(p) AT.give(p, { { "FruitFarming.AppleSeed", 5 }, { "FruitFarming.OrangeSeed", 5 } }) end),
    T("Pills", "Give vitamin pills", function(p) AT.give(p, { { "Base.PillsVitamins", 2 } }) end),
    T("Canning", "Give a canning set (empty tin cans, salt, carrots)", function(p)
        AT.give(p, { { "Base.TinCanEmpty", 3 }, { "Base.Salt", 1 }, { "Base.Carrots", 12 } })
    end),
})

local function install()
    if not (GTPGuideWindow and AT.decorate) then return end
    AT.decorate(GTPGuideWindow, {
        mod = "gtp",
        tab = function(win) return win.tab or "cook" end,
        rect = function(win)
            local list = win:headerButtons()
            local last = list[#list]
            return last.x - last.w - 6, last.y, last.w
        end,
    })
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(install) end

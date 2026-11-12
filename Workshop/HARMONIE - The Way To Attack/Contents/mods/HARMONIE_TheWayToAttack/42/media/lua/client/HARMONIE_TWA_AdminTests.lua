--[[
    HARMONIE - The Way To Attack: admin tests for every tab of the crafting
    window (owner, 2026-11-12, 1.0.0: "ในทุกหน้าต่างและแท็บให้มีปุ่มที่แอดมินสามารถ
    กดเพื่อทดสอบอะไรต่างๆได้"). The hub's flask button (000_HARMONIE_AdminTest)
    sits left of the volume slider. Items and skills are given by the server
    (TWAAdminGrant's own checked command, the hub's give / skill ops).
]]--

local AT = HARMONIE_AdminTest
if not AT then print("[HARMONIE_TWA][AdminTests] no HARMONIE_AdminTest -- no admin tests"); return end

local function T(id, en, run) return { key = "IGUI_TWA_Test_" .. id, fallback = en, run = run } end
local function recipeOf(ctx)
    local w = TWACraftUI and TWACraftUI.window
    local r = w and w.selectedRecipe
    return r and r.id or nil
end
local function grant(p, what)
    local id = recipeOf()
    if not id then TWALog("AdminTests", "no recipe picked -- pick one first"); p:Say(AT.T("IGUI_TWA_Test_PickFirst", "Pick a recipe first.")); return end
    if TWAAdminGrant and TWAAdminGrant.request then TWAAdminGrant.request(p, id, what) end
end
local SKILLS = { "Blacksmith", "MetalWelding", "Woodwork", "Carving", "Tailoring" }

AT.register("twa", "*", {
    T("Skills", "Crafting skills to 10 (smithing, welding, carpentry, carving, tailoring)", function(p)
        for _, s in ipairs(SKILLS) do AT.skill(p, s, 10) end
    end),
    T("SkillsZero", "Crafting skills to 0", function(p) for _, s in ipairs(SKILLS) do AT.skill(p, s, 0) end end),
})
local recipeTests = {
    T("Items", "Give what the picked recipe still lacks", function(p) grant(p, "items") end),
    T("RecipeSkills", "Skills the picked recipe asks for", function(p) grant(p, "skills") end),
}
AT.register("twa", "craft", recipeTests)
AT.register("twa", "weapons", recipeTests)
AT.register("twa", "materials", recipeTests)
AT.register("twa", "modify", {
    T("Gems", "Give one of every gem", function(p)
        local list = {}
        for _, g in ipairs(TWAGemSocket and TWAGemSocket.gemTypes and TWAGemSocket.gemTypes() or {}) do list[#list + 1] = { g, 1 } end
        AT.give(p, list)
    end),
})
AT.register("twa", "guide", {})

local function install()
    if not (TWACraftWindow and AT.decorate) then return end
    AT.decorate(TWACraftWindow, {
        mod = "twa",
        tab = function(win) return win.activeTab or "craft" end,
        player = function(win) return win.player or win.character end,
        rect = function(win)
            local s = 26
            local x = win.volumeRect and select(1, win:volumeRect()) or (win.width - 300)
            local hh = (TWAWorkbench and TWAWorkbench.HEADER_H or 40) * (win.width / 1000)
            return x - s - 14, math.floor((hh - s) / 2), s
        end,
    })
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(install) end

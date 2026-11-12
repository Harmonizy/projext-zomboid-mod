--[[
    HARMONIE - How to Survive : The Only Cure XP multipliers (1.0.3)

    Owner, 2026-11-12 (choice 2): the three TOC XP multipliers (sandbox
    MultiplierConfig.Side_L / Side_R / ProstFamiliarity) always count, ON TOP
    of the game's global XP multiplier.

    They are the game's own per-skill multipliers, which vanilla reads only
    when "use the global multiplier" (MultiplierConfig.GlobalToggle) is OFF --
    the owner's server has it on (Global 3.0), so they did nothing. With the
    toggle on, TOC's XP is multiplied here before the game's addXp (which then
    applies the global one): global 3 x Side_L 2 = 6. With the toggle off the
    game already uses the per-skill value, so nothing is added (no double).

    Every TOC XP grant goes through HM_TOCXp.add (server / single player):
    shared/TOC/ExpActions.lua and server/TOC/ServerRelayCommands.lua RelayAddXp.
]]--

HM_TOCXp = HM_TOCXp or {}
local X = HM_TOCXp

X.PERKS = { Side_L = true, Side_R = true, ProstFamiliarity = true }

local function mc() return SandboxVars and SandboxVars.MultiplierConfig or {} end

-- true when the game uses the one global multiplier for every skill
function X.globalOn()
    return mc().GlobalToggle ~= false
end

-- the extra factor our code applies (1 when vanilla already uses the value)
function X.mult(perkName)
    if not X.PERKS[perkName] or not X.globalOn() then return 1 end
    local v = tonumber(mc()[perkName])
    if not v or v < 0 then return 1 end
    return v
end

function X.add(character, perkName, xp)
    if not character or not perkName or not Perks or not Perks[perkName] then return end
    local m = X.mult(perkName)
    if HMLogOnce then
        HMLogOnce("tocxp_" .. tostring(perkName) .. "_" .. tostring(m), "TOCXp",
            "%s XP x%s from the TOC multiplier (%s)", tostring(perkName), tostring(m),
            X.globalOn() and ("global multiplier on: the game adds x" .. tostring(mc().Global or "?"))
                or "global multiplier off: the game uses the per-skill value itself")
    end
    if m <= 0 then return end
    addXp(character, Perks[perkName], (tonumber(xp) or 0) * m)
end

return X

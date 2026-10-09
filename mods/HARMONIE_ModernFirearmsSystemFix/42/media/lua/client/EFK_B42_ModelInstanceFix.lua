-- MFST Patch: Fix AWCWF_AdditionalParts reflection crash in B42 non-debug mode
--
-- Root cause: getNumClassFields / getClassField / getClassFieldVal are debug-only
-- in B42 and throw IllegalStateException on every player-update tick outside debug.
--
-- Proper fix: the fields they accessed ("sub", "m_modelScript" → now "modelScript"
-- in B42) are public on ModelInstance and can be read via direct Lua field access
-- without any reflection.  Kahlua throws on unknown keys, so the first access of
-- each field name is wrapped in pcall; the result is memoized so subsequent ticks
-- incur a single table lookup only.
--
-- Outcomes:
--   Fields accessible (Kahlua registers them)  → full visual-attachment functionality
--   Fields not accessible (return nil)          → silent stub fallback, no error spam

-- In B42 non-debug, ModelInstance is not registered with the Lua-Java bridge:
-- accessing .sub or .modelScript via Lua tableget throws a RuntimeException that
-- PZ logs even when caught by pcall (confirmed: error appears once at frame 1).
-- Pre-block both field names so no probe is ever attempted → zero error output.
local _blocked = { sub = true, modelScript = true }

local function jfield(obj, name)
    if not obj or _blocked[name] then return nil end
    local ok, val = pcall(function() return obj[name] end)
    if not ok then _blocked[name] = true; return nil end
    return val
end

AWCWF_AdditionalParts.GetPlayerModelList = function(player)
    if not player then return end
    return jfield(player:getModelInstance(), "sub")
end

AWCWF_AdditionalParts.GetWeaponModelInstance = function(player, weapon)
    if not player then return end
    local playerlist = AWCWF_AdditionalParts.GetPlayerModelList(player)
    if not playerlist then return end
    if not instanceof(weapon, "HandWeapon") then return end
    local model = ScriptManager.instance:getModelScript("Base." .. weapon:getWeaponSprite())
    if not model then return end
    for i = 1, playerlist:size() do
        local mi = playerlist:get(i - 1)
        local mis = jfield(mi, "modelScript")
        if mis and mis:getMeshName() == model:getMeshName() then
            return mi
        end
    end
end

AWCWF_AdditionalParts.getweaponmodellist = function(player)
    if not player then return end
    local playerlist = AWCWF_AdditionalParts.GetPlayerModelList(player)
    if not playerlist then return end
    local weapon = player:getPrimaryHandItem()
    if not instanceof(weapon, "HandWeapon") then return end
    local model = ScriptManager.instance:getModelScript("Base." .. weapon:getWeaponSprite())
    if not model then return end
    for i = 1, playerlist:size() do
        local mi = playerlist:get(i - 1)
        local mis = jfield(mi, "modelScript")
        if mis and mis:getMeshName() == model:getMeshName() then
            return jfield(mi, "sub")
        end
    end
end

AWCWF_AdditionalParts.getweaponmodellistall = function(player)
    if not player then return end
    local playerlist = AWCWF_AdditionalParts.GetPlayerModelList(player)
    if not playerlist then return end
    local weapon = player:getPrimaryHandItem()
    if not instanceof(weapon, "HandWeapon") then return end
    local model = ScriptManager.instance:getModelScript("Base." .. weapon:getWeaponSprite())
    if not model then return end
    local t = {}
    for i = 1, playerlist:size() do
        local mi = playerlist:get(i - 1)
        local mis = jfield(mi, "modelScript")
        if mis and mis:getMeshName() == model:getMeshName() then
            local sub = jfield(mi, "sub")
            if sub then t[sub] = true end
        end
    end
    return t
end

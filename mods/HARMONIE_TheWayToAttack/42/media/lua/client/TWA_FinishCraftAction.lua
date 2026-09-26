--============================================================================
-- HARMONIE_TheWayToAttack -- finish-craft timed action (client)
--
-- Queued by HARMONIE_TWA_CraftUI.lua's Finish button once every procedure a
-- recipe requires has been performed (and its materials already consumed
-- procedure-by-procedure, not here). This action just does the final step:
-- consume the base item (if the recipe has one) and produce the result item,
-- through the same ISBaseTimedAction/ISTimedActionQueue path every other
-- crafting action in the game uses (isValid/perform only overridden; every
-- other method -- update/start/stop/getDuration -- uses ISBaseTimedAction's
-- own real default implementation, confirmed from its own source rather than
-- guessed, matching this mod's usual verification discipline).
--============================================================================

require "TimedActions/ISBaseTimedAction"

TWA_FinishCraftAction = ISBaseTimedAction:derive("TWA_FinishCraftAction")

-- `recipe.base` may be nil, a single fullType string, or a LIST of
-- interchangeable fullTypes (e.g. the universal "Metal Ingot" base is really
-- any of vanilla's own 4 real base:ingot items -- request 2026-09-26:
-- "materials aren't flexible").
local function baseList(base)
    if base == nil then return {} end
    if type(base) == "table" then return base end
    return { base }
end

function TWA_FinishCraftAction:isValid()
    if not self.character or not self.recipe then return false end
    if self.recipe.base then
        local inv = self.character:getInventory()
        local owned = false
        for _, t in ipairs(baseList(self.recipe.base)) do
            if inv:getItemCountRecurse(t) >= 1 then owned = true break end
        end
        if not owned then return false end
    end
    for _, procId in ipairs(self.recipe.procedures) do
        if not self.doneProcedures[procId] then return false end
    end
    return true
end

function TWA_FinishCraftAction:perform()
    local inv = self.character:getInventory()
    if self.recipe.base then
        for _, t in ipairs(baseList(self.recipe.base)) do
            local baseItem = inv:getFirstTypeEvalRecurse(t, function() return true end)
            if baseItem then
                inv:Remove(baseItem)
                break
            end
        end
    end
    inv:AddItem(self.recipe.result)
    ISBaseTimedAction.perform(self)
end

function TWA_FinishCraftAction:new(character, recipe, doneProcedures)
    local o = ISBaseTimedAction.new(self, character)
    o.recipe = recipe
    o.doneProcedures = doneProcedures
    o.maxTime = 100
    return o
end

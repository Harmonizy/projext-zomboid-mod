-- AB_Lightsaber.lua
--
-- Base.lightsaber is a B42 weapon whose blade (光剑) deploys while held in hand
-- and retracts (光剑收) when it is sheathed onto its belt (AttachmentType
-- "LightsaberBelt").
--
-- B42 renders an attached weapon with the SAME `model` block as the in-hand
-- weapon, and there is no item-script property to override the attached-state
-- model, so we flip the item's static model in Lua at the attach/equip
-- boundaries instead.

local ITEM_TYPE      = "Base.lightsaber"
local MODEL_DRAWN    = "lightsaber"          -- model lightsaber        { mesh = 光剑   }
local MODEL_SHEATHED = "lightsaberSheathed"  -- model lightsaberSheathed { mesh = 光剑收 }

local function isLightsaber(item)
    return item ~= nil and item:getFullType() == ITEM_TYPE
end

local function applyModel(item, sheathed)
    if not isLightsaber(item) then
        return
    end
    local model = sheathed and MODEL_SHEATHED or MODEL_DRAWN
    pcall(item.setStaticModel, item, model)
    pcall(item.setWorldStaticModel, item, model)
end

-- Wrap a timed-action method so the lightsaber's model is swapped right before
-- the original method runs (sheathedFn returns true = retracted hilt).
local function wrapModelSwap(cls, method, sheathedFn)
    if not cls or not cls[method] then
        return
    end
    local orig = cls[method]
    cls[method] = function(self, ...)
        applyModel(self.item, sheathedFn(self))
        return orig(self, ...)
    end
end

-- Attach to belt (from inventory) / unequip back to belt -> retracted hilt.
wrapModelSwap(ISAttachItemHotbar, "start",   function() return true end)
wrapModelSwap(ISAttachItemHotbar, "perform", function() return true end)
wrapModelSwap(ISUnequipAction,    "start",   function(self) return self.fromHotbar end)
wrapModelSwap(ISUnequipAction,    "perform", function(self) return self.fromHotbar end)

-- Detach from belt (back to inventory) -> deployed blade.
wrapModelSwap(ISDetachItemHotbar, "start",   function() return false end)
wrapModelSwap(ISDetachItemHotbar, "perform", function() return false end)

-- Drawn into hand -> deployed blade.
local function onEquip(player, item)
    applyModel(item, false)
end
Events.OnEquipPrimary.Add(onEquip)
Events.OnEquipSecondary.Add(onEquip)

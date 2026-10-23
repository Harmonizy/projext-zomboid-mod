local function TweakItem(item, field, value)
    local item = ScriptManager.instance:getItem(item)
    item:DoParam(field .. " = " .. value);
end

-- local function CheckAdd()
--     local items = getAllItems();
--     for i = 0, items:size() - 1 do
--         local item = items:get(i);
--         if item then
--         local RealItem = instanceItem(item:getFullName());
--         if RealItem then
--             if AWCWF_WeaponMustPartList[RealItem:getType()] then
--                 TweakItem(item:getFullName(), "OnCreate", "SpawnInitPart.OnCreatePart");
--             end
--             if RealItem:IsWeapon() then
--                 if RealItem:isRanged() then
--                     TweakItem(item:getFullName(), "DisplayCategory", "WepFire");
--                 else
--                     if not RealItem:getDisplayCategory() == "Tool" then
--                         TweakItem(item:getFullName(), "DisplayCategory", "WepMelee");
--                     end
--                 end
--             end
--             if RealItem:getCategory() == "Ammo" then
--                 if RealItem:getMaxAmmo() then
--                     TweakItem(item:getFullName(), "DisplayCategory", "WepAmmoMag");
--                 else
--                     TweakItem(item:getFullName(), "DisplayCategory", "Ammo");
--                 end
--             end
--             if RealItem:getCategory() == "WeaponPart" then
--                 local PartType = RealItem:getPartType();
--                 if PartType then
--                     TweakItem(item:getFullName(), "DisplayCategory", PartType);
--                 end
--             end
--         end
            
--         end
        
--     end
-- end

-- Events.OnGameBoot.Add(CheckAdd)

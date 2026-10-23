local function GetOrCreatModData(item)

    local modData = item:getModData();
    if modData.IO == nil then
        modData.IO = {};
        modData.IO.ItemType = nil
        modData.IO.ItemName = nil
        modData.IO.Count = 0
        modData.IO.Weight = 0
        modData.IO.UsedDelta = 0
        modData.IO.UsedDeltaTotal = 0
    end
    return modData;
end
local reloadMagazine = function(playerObj, magazine)
    if not magazine then
        return 0
    end

    local ammoCount = ISInventoryPaneContextMenu.transferBullets(playerObj, magazine:getAmmoType():getItemKey(),
        magazine:getCurrentAmmoCount(), magazine:getMaxAmmo())
    if ammoCount > 0 then
        ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(playerObj, magazine, ammoCount))
    else
        local Items = playerObj:getInventory():getItems()
        local AvaiableBox = nil
        for i = 0, Items:size() - 1 do
            if Items:get(i):getType() == "AmmoBag" and AmmoBagFunction.GetLoadType(Items:get(i)) ==
                magazine:getAmmoType():getItemKey() then
                AvaiableBox = Items:get(i)
                break
            end
        end
        if AvaiableBox then
            ammoCount = AmmoBagFunction.GetNum(AvaiableBox)
            ammoCount = math.min(ammoCount, magazine:getMaxAmmo() - magazine:getCurrentAmmoCount())
            if ammoCount > 0 then
                AmmoBagFunction.ItemOut(AvaiableBox, ammoCount)
                ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(playerObj, magazine, ammoCount))
            end
        end

        if ammoCount <= 0 then
            return
        end
    end
    return ammoCount
end
ISReloadWeaponAction.ReloadBestMagazine = function(playerObj, gun)
    local magazine = gun:getBestMagazine(playerObj)
    local ammoCount = reloadMagazine(playerObj, magazine)
    if not magazine or ammoCount == 0 then
        return
    end
    ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
end

-- Called by ISFirearmRadialMenu.onKeyReleased()
ISReloadWeaponAction.BeginAutomaticReload = function(playerObj, gun)
    if gun:getMagazineType() then
        -- clip inside, pressing R will remove it, other wise we load another
        local magazine = gun:getBestMagazine(playerObj)
        local hasMagazine = gun:isContainsClip()
        if hasMagazine then
            ISTimedActionQueue.add(ISEjectMagazine:new(playerObj, gun))
            if magazine and magazine:getCurrentAmmoCount() > 0 then
                ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
                ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
                return
            end
            -- reload the ejected magazine and insert it
            ISTimedActionQueue.queueActions(playerObj, ISReloadWeaponAction.ReloadBestMagazine, gun)
            return
        end
        if not magazine then
            return
        end
        if magazine:getCurrentAmmoCount() > 0 then
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
            ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
            return
        end
        local ammoCount = reloadMagazine(playerObj, magazine)
        -- if ammoCount is 0 then player has no more ammo.
        -- if hasMagazine is false, reload was started from an empty gun, so insert an empty magazine.
        if ammoCount and (ammoCount > 0 or not hasMagazine) then
            ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
        end
    else

        -- if can't have more bullets, we don't do anything, this doesn't apply for magazine-type guns (you'll still remove the current clip)
        if gun:getCurrentAmmoCount() >= gun:getMaxAmmo() then
            return
        end
        -- can't load bullet into a jammed gun, clip works tho
        if gun:isJammed() then
            return
        end
        local ammoCount = ISInventoryPaneContextMenu.transferBullets(playerObj, gun:getAmmoType():getItemKey(),
            gun:getCurrentAmmoCount(), gun:getMaxAmmo())

        if ammoCount == 0 then
            local Items = playerObj:getInventory():getItems()
            local AvaiableBox = nil
            for i = 0, Items:size() - 1 do
                if Items:get(i):getType() == "AmmoBag" and AmmoBagFunction.GetLoadType(Items:get(i)) ==
                    gun:getAmmoType():getItemKey() then
                    AvaiableBox = Items:get(i)
                    break
                end
            end

            if AvaiableBox then
                ammoCount = AmmoBagFunction.GetNum(AvaiableBox)
                ammoCount = math.min(ammoCount, gun:getMaxAmmo() - gun:getCurrentAmmoCount())
                if ammoCount > 0 then
                    AmmoBagFunction.ItemOut(AvaiableBox, ammoCount)
                end
            end

            if ammoCount <= 0 then
                return
            end

        end
        ISTimedActionQueue.add(ISReloadWeaponAction:new(playerObj, gun))
    end
end

-- ISReloadWeaponAction.ReloadBestMagazine = function(playerObj, gun)
--     local magazine = gun:getBestMagazine(playerObj)
--     if not magazine then
--         magazine = playerObj:getInventory():getFirstTypeRecurse(gun:getMagazineType())
--     end
--     if not magazine then
--         return
--     end
--     local ammoCount = ISInventoryPaneContextMenu.transferBullets(playerObj, magazine:getAmmoType(),
--         magazine:getCurrentAmmoCount(), magazine:getMaxAmmo())
--     local AmmoNeed = magazine:getMaxAmmo() - magazine:getCurrentAmmoCount()
--     if ammoCount == 0 then
--         local AmmoType = gun:getAmmoType()
--         local AmmoItem = IinstanceItem(AmmoType)
--         local Items = playerObj:getInventory():getItems()
--         local AvaiableBox = nil
--         for i = 0, Items:size() - 1 do
--             if Items:get(i):getType() == "IOContainer" and
--                 string.find(Items:get(i):getDisplayName(), AmmoItem:getDisplayName()) then
--                 AvaiableBox = Items:get(i)
--                 break
--             end
--         end
--         if AvaiableBox then
--             local modData = GetOrCreatModData(AvaiableBox);

--             if modData.IO.Count >= AmmoNeed then
--                 ISTimedActionQueue.add(ISInventoryTransferAction:new(getPlayer(), AvaiableBox,
--                     AvaiableBox:getContainer(), getPlayer():getInventory()))
--                 IOContainerFunction.ItemOut(AvaiableBox, AmmoNeed)

--             elseif modData.IO.Count < AmmoNeed then
--                 ISTimedActionQueue.add(ISInventoryTransferAction:new(getPlayer(), AvaiableBox,
--                     AvaiableBox:getContainer(), getPlayer():getInventory()))
--                 IOContainerFunction.ItemOut(AvaiableBox, modData.IO.Count)

--             end
--             ammoCount = ISInventoryPaneContextMenu.transferBullets(playerObj, magazine:getAmmoType(),
--                 magazine:getCurrentAmmoCount(), magazine:getMaxAmmo())
--         end
--     end
--     ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(playerObj, magazine, ammoCount))
--     ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
--     local magazine = gun:getBestMagazine(playerObj)
--     if magazine then
--         ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
--         ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
--         return
--     end
-- end

-- ISReloadWeaponAction.BeginAutomaticReload = function(playerObj, gun)

--     if gun:getMagazineType() then
--         -- clip inside, pressing R will remove it, other wise we load another
--         if gun:isContainsClip() then
--             ISTimedActionQueue.add(ISEjectMagazine:new(playerObj, gun))
--             -- insert a different non-empty magazine
--             local mags = playerObj:getInventory():getAllTypeRecurse(gun:getMagazineType())
--             for i = 1, mags:size() do
--                 local magazine = mags:get(i - 1)
--                 if magazine and magazine:getCurrentAmmoCount() > 0 then
--                     ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
--                     return
--                 end
--             end
--             -- reload the ejected magazine and insert it
--             ISTimedActionQueue.queueActions(playerObj, ISReloadWeaponAction.ReloadBestMagazine, gun)
--             return
--         end

--         local magazine = gun:getBestMagazine(playerObj)
--         if magazine then
--             ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
--             ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
--             return
--         end
--         -- check if we have an empty magazine for the current gun
--         ISReloadWeaponAction.ReloadBestMagazine(playerObj, gun)
--     else
--         -- if can't have more bullets, we don't do anything, this doesn't apply for magazine-type guns (you'll still remove the current clip)
--         if gun:getCurrentAmmoCount() >= gun:getMaxAmmo() then
--             return
--         end
--         -- can't load bullet into a jammed gun, clip works tho
--         if gun:isJammed() then
--             return
--         end
--         local ammoCount = ISInventoryPaneContextMenu.transferBullets(playerObj, gun:getAmmoType(),
--             gun:getCurrentAmmoCount(), gun:getMaxAmmo())
--         if ammoCount == 0 then
--             local AmmoNeed = gun:getMaxAmmo() - gun:getCurrentAmmoCount()
--             local AmmoType = gun:getAmmoType()
--             local AmmoItem = IinstanceItem(AmmoType)
--             local Items = playerObj:getInventory():getItems()
--             local AvaiableBox = nil
--             for i = 0, Items:size() - 1 do
--                 if Items:get(i):getType() == "IOContainer" and
--                     string.find(Items:get(i):getDisplayName(), AmmoItem:getDisplayName()) then
--                     AvaiableBox = Items:get(i)
--                     break
--                 end
--             end
--             if AvaiableBox then

--                 local modData = GetOrCreatModData(AvaiableBox);
--                 if modData.IO.Count > AmmoNeed then
--                     ISTimedActionQueue.add(ISInventoryTransferAction:new(getPlayer(), AvaiableBox,
--                         AvaiableBox:getContainer(), getPlayer():getInventory()))
--                     IOContainerFunction.ItemOut(AvaiableBox, AmmoNeed)
--                 elseif modData.IO.Count < AmmoNeed then
--                     ISTimedActionQueue.add(ISInventoryTransferAction:new(getPlayer(), AvaiableBox,
--                         AvaiableBox:getContainer(), getPlayer():getInventory()))
--                     IOContainerFunction.ItemOut(AvaiableBox, modData.IO.Count)
--                 end
--                 ammoCount = ISInventoryPaneContextMenu.transferBullets(playerObj, gun:getAmmoType(),
--                     gun:getCurrentAmmoCount(), gun:getMaxAmmo())
--             end
--         end
--         ISTimedActionQueue.add(ISReloadWeaponAction:new(playerObj, gun))
--     end
-- end

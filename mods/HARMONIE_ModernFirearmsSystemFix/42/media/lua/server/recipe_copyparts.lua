RecipeCodeOnCreate = RecipeCodeOnCreate or {}

RecipeCodeOnCreate.copyparts = function(CraftRecipeData, IsoGameCharacter, var1)
    local items = CraftRecipeData:getAllConsumedItems()
    local handweapon = items:get(0)
    if instanceof(handweapon, "HandWeapon") then
        local createditems = CraftRecipeData:getAllCreatedItems() 
        local handweapon2 = createditems:get(0)
        if instanceof(handweapon2, "HandWeapon") then
            for i = 0, handweapon:getAllWeaponParts():size() - 1 do
                local part = handweapon:getAllWeaponParts():get(i)
                -- 判断配件类型，如果是弹匣(Clip)则跳过，不复制到新武器
                -- print(part:getPartType())
                -- if part:getPartType() ~= "Clip" then
                --     handweapon2:setWeaponPart(part)
                -- end
            end
            handweapon2:setContainsClip(false)
            -- handweapon2:copyModData(handweapon:getModData())  
        end
    end
end
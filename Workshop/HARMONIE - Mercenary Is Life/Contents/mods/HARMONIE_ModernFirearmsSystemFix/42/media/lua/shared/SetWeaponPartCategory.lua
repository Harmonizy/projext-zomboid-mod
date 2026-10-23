-- Set DisplayCategory for all WeaponParts and Firearms
local function setWeaponPartCategories()
    local items = getAllItems()
    if not items then return end
    
    for i = 0, items:size() - 1 do
        local itemScript = items:get(i)
        if itemScript then
            local module = itemScript:getModuleName()
            
            -- Check if it's a Gunpart item
            if module == "Gunpart" then
                itemScript:DoParam("DisplayCategory = WeaponPart")
            else
                if itemScript:hasTag(ItemTag.FIREARM) then
                --local wname = itemScript:getFullName()
                --print(wname .."= Firearm true")
                        itemScript:DoParam("DisplayCategory = FireArm")
                        --itemScript:DoParam("Tags = base:hasmetal;base:firearm;base:repairwithepoxy") -- not working, has to be done in script for recipe to recognize it !
                end
            end
        end
    end
end

Events.OnGameStart.Add(setWeaponPartCategories)
Events.OnGameBoot.Add(setWeaponPartCategories)
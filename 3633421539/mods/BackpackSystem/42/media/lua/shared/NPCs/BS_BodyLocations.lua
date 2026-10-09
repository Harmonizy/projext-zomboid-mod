
if BodyLocations and BodyLocations.getGroup and ABWeapon then
    local group = BodyLocations.getGroup("Human")
    if group then
        local locations = {

            ABWeapon.Sling_S_cat_1,
            ABWeapon.Sling_S_cat_2,
        }

        for _, location in ipairs(locations) do
            if location then
                group:getOrCreateLocation(location)
            end
        end
    end
end


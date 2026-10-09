-- In B42.17 vanilla initializes BodyLocations as a shared global script.
-- Requiring it by bare name now emits a warning, so we only register when both
-- the vanilla registry and the mod's custom item-body locations already exist.
if BodyLocations and BodyLocations.getGroup and ABWeapon then
    local group = BodyLocations.getGroup("Human")
    if group then
        local locations = {
            ABWeapon.MurasamaBladeScabbard,
            ABWeapon.OnimaruKunitusnaS,
            ABWeapon.Avalon_cat,
            ABWeapon.FantasyKnightSwordScabbard,
            ABWeapon.MiaoSwordS,
            ABWeapon.YamatoScabbard,
            ABWeapon.NoctisScabbard,
            ABWeapon.YulinSwordS,
            ABWeapon.TacticalTangCrossbladeScabbard,
            ABWeapon.HaliasturIndusCrossbladeScabbard,
            ABWeapon.YanlingSwordScabbard,
            ABWeapon.LightsaberBelt,
        }

        for _, location in ipairs(locations) do
            if location then
                group:getOrCreateLocation(location)
            end
        end
    end
end


if isServer() then
    return
end
ISShootGrenade = ISBuildingObject:derive("ISShootGrenade")
function ISShootGrenade:create(x, y, z, north, sprite)
end
function ISShootGrenade:isValid(square)
    local distan = ((square:getX() - self.character:getX()) ^ 2 + (square:getY() - self.character:getY()) ^ 2) ^ 0.5
    Grenade_Tajectory.aimtexdistance = distan
    if distan < (self.maxrange + self.strength) * 1.7 and distan > 5 then
        return true
    else
        return false
    end
end
function ISShootGrenade:render(x, y, z, square)
    if not self.floorSprite then
        self.floorSprite = IsoSprite.new()
        self.floorSprite:LoadFramesNoDirPageSimple('media/ui/FloorTileCursor.png')
    end
    local r, g, b, a = 0.0, 1.0, 0.0, 0.8
    Grenade_Tajectory.aimcursorsq = square
    if not self:isValid(square) then
        r = 1.0
        g = 0.0
        Grenade_Tajectory.aimcursorsq = nil
    end
    self.floorSprite:RenderGhostTileColor(x + 1.8, y + 1.8, z, r, g, b, a)
end
function ISShootGrenade:new(sprite, northSprite, character, weapon)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    o:setSprite(sprite)
    o:setNorthSprite(northSprite)
    o.character = character
    o.type = "ISShootGrenade"
    o.player = character:getPlayerNum()
    o.noNeedHammer = true
    o.skipBuildAction = true
    o.maxrange = weapon:getMaxRange(character)
    o.strength = character:getPerkLevel(Perks.Strength)
    return o
end

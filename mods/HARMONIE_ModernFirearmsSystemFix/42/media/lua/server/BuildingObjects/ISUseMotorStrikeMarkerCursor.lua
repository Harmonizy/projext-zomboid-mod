if isServer() then
    return
end

require "Advanced_trajectory_core"
ISMotorStrikeMarker = ISBuildingObject:derive("ISMotorStrikeMarker")

function ISMotorStrikeMarker:create(x, y, z, north, sprite)
    local sq = getWorld():getCell():getGridSquare(x, y, z)
    ISTimedActionQueue.add(GuideWeaponAttacking:new(self.character, 300, "AirStrike", sq, self.weapon))
    getCell():setDrag(nil, 0)
    return
end
function ISMotorStrikeMarker:isValid(square) -- local distan = 10
    local distan = ((square:getX() - self.character:getX()) ^ 2 + (square:getY() - self.character:getY()) ^ 2) ^ 0.5
    if distan > 5 and self.weapon:getContainer():getType() ~= "floor" and not square:isInARoom() then
        return true
    else
        return false
    end

end

function ISMotorStrikeMarker:render(x, y, z, square)
    if not self.floorSprite then
        self.floorSprite = IsoSprite.new()
        self.floorSprite:LoadFramesNoDirPageSimple('media/ui/FloorTileCursor.png')
    end
    local r, g, b, a = 0.0, 1.0, 0.0, 0.8
    if not self:isValid(square) then
        r = 1.0
        g = 0.0
    end
    self.floorSprite:RenderGhostTileColor(x + 1.8, y + 1.8, z, r, g, b, a)
end

function ISMotorStrikeMarker:new(sprite, northSprite, character, weapon)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    o:setSprite(sprite)
    o:setNorthSprite(northSprite)
    o.weapon = weapon
    o.character = character
    o.noNeedHammer = true
    o.skipBuildAction = true
    o.skipWalk2 = true
    o.maxrange = 100
    return o
end


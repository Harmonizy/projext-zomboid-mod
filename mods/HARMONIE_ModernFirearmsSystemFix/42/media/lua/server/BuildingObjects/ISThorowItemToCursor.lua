if isServer() then
    return
end

ISThorowitemToCursor = ISBuildingObject:derive("ISThorowitemToCursor")

function ISThorowitemToCursor:create(x, y, z, north, sprite)
end

function ISThorowitemToCursor:isValid(square)
    local distan = ((square:getX() - self.character:getX()) ^ 2 + (square:getY() - self.character:getY()) ^ 2) ^ 0.5
    BombCursor.aimtexdistance = distan
    if distan < (self.maxrange + self.strength) * 1.7 and distan > 0 then
        return true
    else
        return false
    end
end

function ISThorowitemToCursor:render(x, y, z, square)
    if not self.floorSprite then
        self.floorSprite = IsoSprite.new()
        self.floorSprite:LoadFramesNoDirPageSimple('media/ui/FloorTileCursor.png')
    end
    local r, g, b, a = 0.0, 1.0, 0.0, 0.8
    BombCursor.aimcursorsq = square
    if not self:isValid(square) then
        r = 1.0
        g = 0.0
        BombCursor.aimcursorsq = nil
    end
    for i = -BombCursor.Range, BombCursor.Range, BombCursor.Range * 2 do
        for j = -BombCursor.Range, BombCursor.Range, BombCursor.Range * 2 do
            self.floorSprite:RenderGhostTileColor(x + i, y + j, z, 1, 1, 0, a)
        end
    end
    self.floorSprite:RenderGhostTileColor(x + 1.8, y + 1.8, z, r, g, b, a)
end

function ISThorowitemToCursor:new(sprite, northSprite, character, weapon)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    o:setSprite(sprite)
    o:setNorthSprite(northSprite)
    o.character = character
    o.player = character:getPlayerNum()
    o.noNeedHammer = true
    o.skipBuildAction = true
    o.maxrange = weapon:getMaxRange(character)
    o.strength = character:getPerkLevel(Perks.Strength)
    return o
end


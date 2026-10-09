--============================================================================
-- BladesmithSystem — melee inspection 3D scene (client)
--
-- ISUI3DScene subclass mirroring MFS's Carshopscenetk. Drag to orbit (base
-- ISUI3DScene), hold left Alt + drag for manual rotationX/Y/Z. The initial view
-- is fixed with setViewRotation so the weapon shows at a pleasant angle.
--============================================================================

require "Vehicles/ISUI/ISUI3DScene"

ABMeleeScene = ISUI3DScene:derive("ABMeleeScene")

function ABMeleeScene:new(x, y, width, height)
    local o = ISUI3DScene.new(self, x, y, width, height)
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0 }
    o.startRotate = false
    o.rotationX = -70
    o.rotationY = 0
    o.rotationZ = 130
    o.onMousenow = false
    return o
end

function ABMeleeScene:onMouseDown(x, y)
    ISUI3DScene.onMouseDown(self, x, y)
    self.onMousenow = true
end

function ABMeleeScene:onMouseMove(dx, dy)
    -- 56 = left Alt: hold to rotate with the on-screen dials, otherwise drag orbits.
    if not isKeyDown(56) then
        ISUI3DScene.onMouseMove(self, dx, dy)
    else
        if self.onMousenow then
            if math.abs(dx) >= math.abs(dy) then
                self.rotationZ = self.rotationZ + dx
            else
                self.rotationX = self.rotationX + dy
            end
            self:setView("UserDefined")
        end
    end
end

function ABMeleeScene:onMouseUp(x, y)
    ISUI3DScene.onMouseUp(self, x, y)
    self.onMousenow = false
end

function ABMeleeScene:onMouseUpOutside(x, y)
    self:onMouseUp(x, y)
end

function ABMeleeScene:render()
    ISUI3DScene.render(self)
    if self.startRotate then
        self.rotationZ = self.rotationZ + 0.5
    end
    self.javaObject:fromLua3("setViewRotation", self.rotationX, self.rotationY, self.rotationZ)
end

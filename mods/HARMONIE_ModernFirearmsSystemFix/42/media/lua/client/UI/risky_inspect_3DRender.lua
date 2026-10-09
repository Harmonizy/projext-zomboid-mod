require('Vehicles/ISUI/ISUI3DScene')
Carshopscenetk = ISUI3DScene:derive("Carshopscenetk")
ShopSwitchView = ISUI3DScene:derive("ShopSwitchView")
function Carshopscenetk:prerenderEditor()
    self.javaObject:fromLua1("setGizmoVisible", "none")
    self.javaObject:fromLua1("setGizmoOrigin", "none")
    self.javaObject:fromLua1("setTransformMode", "Global")
    self.javaObject:fromLua0("clearGizmoRotate")
    self.javaObject:fromLua0("clearAABBs")
    self.javaObject:fromLua0("clearAxes")
    self.javaObject:fromLua0("clearBox3Ds")
end
function Carshopscenetk:prerender()
    ISUI3DScene.prerender(self)
end
function Carshopscenetk:onMouseDown(x, y)
    ISUI3DScene.onMouseDown(self, x, y)
    self.gizmoAxis = self.javaObject:fromLua2("testGizmoAxis", x, y)
    if self.gizmoAxis ~= "None" then
        local scenePos = self.javaObject:fromLua0("getGizmoPos")
        self.gizmoStartScenePos = alignVectorToGrid(Vector3f.new(scenePos))
        self.gizmoClickScenePos = alignVectorToGrid(self.javaObject:uiToScene(x, y, 0, Vector3f.new()))
        self.javaObject:fromLua3("startGizmoTracking", x, y, self.gizmoAxis)
        self:onGizmoStart()
    end
    self.onMousenow = true
end
function Carshopscenetk:onMouseMove(dx, dy)
    if not isKeyDown(56) then
        if self.gizmoAxis == "None" then
            ISUI3DScene.onMouseMove(self, dx, dy)
        else
            local x, y = self:getMouseX(), self:getMouseY()
            local newPos = alignVectorToGrid(self.javaObject:uiToScene(x, y, 0, Vector3f.new()))
            newPos:sub(self.gizmoClickScenePos)
            newPos:add(self.gizmoStartScenePos)
            self.javaObject:fromLua2("dragGizmo", x, y)
        end
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
function Carshopscenetk:render()
    ISUI3DScene.render(self)
    if isKeyDown(75) then
        self.rotationX = self.rotationX + 5
        self:setView("UserDefined")
    end
    if isKeyDown(76) then
        self.rotationY = self.rotationY + 5
        self:setView("UserDefined")
    end
    if isKeyDown(77) then
        self.rotationZ = self.rotationZ + 5
        self:setView("UserDefined")
    end
    if self.startRotate then
        self.rotationZ = self.rotationZ + 0.5
    end
    self.javaObject:fromLua3("setViewRotation", self.rotationX, self.rotationY, self.rotationZ)
end
function Carshopscenetk:onMouseUp(x, y)
    ISUI3DScene.onMouseUp(self, x, y)
    if self.gizmoAxis ~= "None" then
        self.gizmoAxis = "None"
        self.javaObject:fromLua0("stopGizmoTracking")
        self:onGizmoAccept()
    end
    self.onMousenow = false
end
function Carshopscenetk:onMouseUpOutside(x, y)
    self:onMouseUp()
    self.onMousenow = false
end
function Carshopscenetk:onRightMouseDown(x, y)
    if self.gizmoAxis ~= "None" then
        self.gizmoAxis = "None"
        self.javaObject:fromLua0("stopGizmoTracking")
        self.mouseDown = false
        self.javaObject:fromLua1("setGizmoPos", self.gizmoStartScenePos)
        self:onGizmoCancel()
    end
end
function Carshopscenetk:onGizmoStart()
    self.parent.editUI.current:onGizmoStart()
end
function Carshopscenetk:onGizmoChanged(delta)
    if self.gizmoAxis == "None" then
        return
    end -- cancelled via onRightMouseUp
    self.parent.editUI.current:onGizmoChanged(delta)
end
function Carshopscenetk:onGizmoAccept()
    self.parent.editUI.current:onGizmoAccept()
end
function Carshopscenetk:onGizmoCancel()
    self.parent.editUI.current:onGizmoCancel()
end
function Carshopscenetk:new(x, y, width, height)
    local o = ISUI3DScene.new(self, x, y, width, height)
    o.gizmoAxis = "None"
    o.backgroundColor = {
        r = 0,
        g = 0,
        b = 0,
        a = 0
    }
    o.borderColor = {
        r = 0.4,
        g = 0.4,
        b = 0.4,
        a = 0
    }
    o.startRotate = false
    o.rotationX = -70
    o.rotationY = 0
    o.rotationZ = 130
    return o
end
function ShopSwitchView:prerender()
    if self:isMouseOver() or (self:getView() == self.editor.scene:getView()) then
        self.borderColor.r = 0.8
        self.borderColor.g = 0.8
        self.borderColor.b = 0.8
    else
        self.borderColor.r = 0.4
        self.borderColor.g = 0.4
        self.borderColor.b = 0.4
    end
    ISUI3DScene.prerender(self)
end
function ShopSwitchView:onMouseDown(x, y)
    self.editor.prevView = self:getView()
    self.editor.scene:setView(self:getView())
end
function ShopSwitchView:onMouseMove(dx, dy)
    if self.editor.mouseOverView ~= self then
        if self.editor.mouseOverView then
            self.editor.mouseOverView:onMouseMoveOutside(-1, -1)
        end
        self.editor.mouseOverView = self
        self.editor.prevView = self.editor.scene:getView()
        self.editor.scene:setView(self:getView())
    end
end
function ShopSwitchView:onMouseMoveOutside(dx, dy)
    if self.editor.mouseOverView == self then
        self.editor.mouseOverView = nil
        self.editor.scene:setView(self.editor.prevView)
        self.editor.prevView = nil
    end
end
function ShopSwitchView:onMouseWheel(del)
    return true
end
function ShopSwitchView:new(editor, x, y, width, height)
    local o = ISUI3DScene.new(self, x, y, width, height)
    o.editor = editor
    return o
end

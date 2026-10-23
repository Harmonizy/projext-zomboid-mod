require "ISUI/ISPanel"

HeartbeatSensor = ISPanel:derive("HeartbeatSensor");
local this = HeartbeatSensor
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.NewSmall)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.NewMedium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.NewLarge)
local btnClose = getText("IGUI_CraftUI_Close")
local btnUpload = getText("IGUI_ISTigerCrewLevel_Equip")
local btnCloseWid = getTextManager():MeasureStringX(UIFont.NewSmall, btnClose) + 10
local btnCloseHgt = getTextManager():MeasureStringY(UIFont.NewSmall, btnClose) + 10
local btnUploadWid = getTextManager():MeasureStringX(UIFont.NewSmall, btnUpload) + 10
local btnUploadHgt = getTextManager():MeasureStringY(UIFont.NewSmall, btnUpload) + 10
local LastScale = 1
local LastPointScale = 1
local LastSpeed = 1
function HeartbeatSensor:initialise()
    ISPanel.initialise(self);
    self:create();
end

function HeartbeatSensor:prerender()
    ISPanel.prerender(self);
end

function HeartbeatSensor:destroy()
    UIManager.setShowPausedMessage(true)
    self:setVisible(false)
    self:removeFromUIManager()
    this.instance = nil
end

local function getDistance(x1, y1, x2, y2)
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
end

function HeartbeatSensor:updateTickReach()
    self.ZombieList = {}
    local playerX = self.character:getX()
    local playerY = self.character:getY()
    local Zombies = getCell():getZombieList()
    for i = 0, Zombies:size() - 1 do
        local ZombieNow = Zombies:get(i)
        if ZombieNow then
            local ZombieX = ZombieNow:getX()
            local ZombieY = ZombieNow:getY()
            local distance = getDistance(playerX, playerY, ZombieX, ZombieY)
            if distance < 50 then
                self.ZombieList[ZombieNow] = {
                    x = ZombieX,
                    y = ZombieY,
                    z = ZombieNow:getZ(),
                    distance = distance,
                    canSeePlayer = ZombieNow:isTargetLocationKnown()
                }
            end
        end
    end
end

function HeartbeatSensor:render()
    self:setStencilRect(0, 0, self.width, self.height);
    self.ScanLineX = self.ScanLineX + self.Speed * (60 / getAverageFPS())
    if self.ScanLineX > (219 - 36) * self.scale then
        self.ScanLineX = 57 * self.scale
        self:updateTickReach()
    end
    if self.plus then
        self:drawTextureScaled(getTexture("media/textures/HeartbeatSensor_PlusGUI.png"), 5, 5, 253 * self.scale,
            183 * self.scale, 1, 1, 1, 1)
    else
        self:drawTextureScaled(getTexture("media/textures/HeartbeatSensorGUI.png"), 5, 5, 253 * self.scale,
            183 * self.scale, 1, 1, 1, 1)
    end
    local StartX = 57 * self.scale
    local EndX = 219 * self.scale
    local StartY = 17 * self.scale
    local EndY = 169 * self.scale
    local Width = EndX - StartX
    local Height = EndY - StartY
    local MidPointX = Width / 2 + StartX
    local MidPointY = Height / 2 + StartY

    self:drawRect(MidPointX - 5, MidPointY - 5, 5 * self.PointScale, 5 * self.PointScale, 0.8, 1, 1, 0.5)
    if self.plus then
        self:drawTextureScaled(getTexture("media/textures/HeartbeatSensor_PlusScanLine.png"), self.ScanLineX, StartY,
            36, Height, 1, 1, 1, 1)
    else
        self:drawTextureScaled(getTexture("media/textures/HeartbeatSensorScanLine.png"), self.ScanLineX, StartY, 36,
            Height, 1, 1, 1, 1)
    end
    local PlayerX = self.character:getX()
    local PlayerY = self.character:getY()
    local radarRadius = Width / 2
    local maxDistance = 50
    for id, zombieData in pairs(self.ZombieList) do
        local relX = zombieData.x - PlayerX
        local relY = zombieData.y - PlayerY
        local radarX = MidPointX + (relX / maxDistance) * radarRadius
        local radarY = MidPointY + (relY / maxDistance) * radarRadius

        local distanceFromCenter = getDistance(MidPointX, MidPointY, radarX, radarY)
        if distanceFromCenter <= radarRadius then
            local dotSize = 4 * self.PointScale
            local intensity = 1 - (zombieData.distance / maxDistance) -- Closer zombies are brighter
            if self.plus then
                if zombieData.z > self.character:getZ() then
                    self:drawRect(radarX - dotSize / 2, radarY - dotSize / 2, dotSize, dotSize, 1, 0, 0, 1)
                else
                    if zombieData.z < self.character:getZ() then
                        self:drawRect(radarX - dotSize / 2, radarY - dotSize / 2, dotSize, dotSize, 1, 0, 1, 1)
                    else
                        self:drawRect(radarX - dotSize / 2, radarY - dotSize / 2, dotSize, dotSize, 1, 1, 0, 0)
                    end
                end
                if zombieData.canSeePlayer then
                    self:drawRectBorder(radarX - dotSize / 2, radarY - dotSize / 2, dotSize, dotSize, 1, 1, 1, 0)
                end
            else
                self:drawRect(radarX - dotSize / 2, radarY - dotSize / 2, dotSize, dotSize, intensity, 1, 0, 0)
            end
        end
    end
    self:clearStencilRect();
end

function HeartbeatSensor:onOptionMouseDown(button, x, y)
    if button.internal == "Close" then
        self:destroy()
    end
    if button.internal == "ScaleUP" then
        self.scale = self.scale + 0.1
        LastScale = self.scale
    end
    if button.internal == "ScaleDown" then
        self.scale = self.scale - 0.1
        LastScale = self.scale
    end
    if button.internal == "PointScaleUP" then
        self.PointScale = self.PointScale + 0.1
        LastPointScale = self.PointScale
    end
    if button.internal == "PointScaleDown" then
        self.PointScale = self.PointScale - 0.1
        LastPointScale = self.PointScale
    end
    if button.internal == "SpeedUP" then
        self.Speed = self.Speed + 0.1
        LastSpeed = self.Speed
    end
    if button.internal == "SpeedDown" then
        self.Speed = self.Speed - 0.1
        LastSpeed = self.Speed
    end
end

function HeartbeatSensor:onMouseDown(x, y)
    -- Only the top-left quarter of the radar acts as a drag handle; clicks anywhere else
    -- are left unconsumed so the mouse keeps interacting with the game world.
    if x < 0 or x > self.width / 2 or y < 0 or y > self.height / 2 then
        return false
    end
    self.moving = true
    self.javaObject:setConsumeMouseEvents(true)
    self:setCapture(true)
    self:bringToTop()
    return true
end

function HeartbeatSensor:onMouseMove(dx, dy)
    if not self.moving then
        return false
    end
    self:setX(self.x + dx)
    self:setY(self.y + dy)
    self:bringToTop()
    return true
end

function HeartbeatSensor:onMouseMoveOutside(dx, dy)
    return self:onMouseMove(dx, dy)
end

function HeartbeatSensor:onMouseUp(x, y)
    if self.moving then
        self.moving = false
        self:setCapture(false)
        self.javaObject:setConsumeMouseEvents(false)
    end
    return false
end

function HeartbeatSensor:onMouseUpOutside(x, y)
    return self:onMouseUp(x, y)
end

function HeartbeatSensor:create()
    if getDebug() then
        self.close = ISButton:new(0, 0, btnCloseWid, btnCloseHgt, btnClose, self, self.onOptionMouseDown);
        self.close.internal = "Close";
        self.close:initialise();
        self.close:instantiate();

        self.close.borderColor = {
            r = 1,
            g = 1,
            b = 1,
            a = 0
        }
        self:addChild(self.close);
    end
    self.ScaleUP = ISButton:new(0, btnCloseHgt * 2, 32, 32, "+", self, self.onOptionMouseDown);
    self.ScaleUP.internal = "ScaleUP";
    self.ScaleUP:initialise();
    self.ScaleUP:instantiate();
    self:addChild(self.ScaleUP);
    self.ScaleDown = ISButton:new(0, btnCloseHgt * 3, 32, 32, "-", self, self.onOptionMouseDown);
    self.ScaleDown.internal = "ScaleDown";
    self.ScaleDown:initialise();
    self.ScaleDown:instantiate();
    self:addChild(self.ScaleDown);

    self.PointScaleUP = ISButton:new(0, btnCloseHgt * 4, 32, 32, "P+", self, self.onOptionMouseDown);
    self.PointScaleUP.internal = "PointScaleUP";
    self.PointScaleUP:initialise();
    self.PointScaleUP:instantiate();
    self:addChild(self.PointScaleUP);
    self.PointScaleDown = ISButton:new(0, btnCloseHgt * 5, 32, 32, "P-", self, self.onOptionMouseDown);
    self.PointScaleDown.internal = "PointScaleDown";
    self.PointScaleDown:initialise();
    self.PointScaleDown:instantiate();
    self:addChild(self.PointScaleDown);

    self.SpeedUP = ISButton:new(0, btnCloseHgt * 6, 32, 32, "S+", self, self.onOptionMouseDown);
    self.SpeedUP.internal = "SpeedUP";
    self.SpeedUP:initialise();
    self.SpeedUP:instantiate();
    self:addChild(self.SpeedUP);

    self.SpeedDown = ISButton:new(0, btnCloseHgt * 7, 32, 32, "S-", self, self.onOptionMouseDown);
    self.SpeedDown.internal = "SpeedDown";
    self.SpeedDown:initialise();
    self.SpeedDown:instantiate();
    self:addChild(self.SpeedDown);
    self:updateTickReach()
end

function HeartbeatSensor:update()

end

function HeartbeatSensor:new(x, y, width, height, player, scale, plus)
    local o = {};
    o = ISPanel:new(x, y, width, height);
    setmetatable(o, self);
    o.character = player;
    self.__index = self;
    this.instance = o
    o.anchorRight = true
    o.anchorBottom = true
    o.ScanLineX = 57
    o.Speed = LastSpeed
    o.anchorTop = true
    o.scale = LastScale
    o.PointScale = LastPointScale
    o.plus = plus
    o.anchorLeft = true
    o.ZombieList = {}
    o.moveWithMouse = true
    o.wantMouseEvents = false
    o.backgroundColor = {
        r = 0,
        g = 0,
        b = 0,
        a = 0
    }
    o.borderColor = {
        r = 1,
        g = 1,
        b = 1,
        a = 0
    }

    return o;
end

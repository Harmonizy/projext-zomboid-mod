require "ISUI/ISPanel"

ISAirDropInComing = ISPanel:derive("ISAirDropInComing");
local this = ISAirDropInComing

function ISAirDropInComing:initialise()
    ISPanel.initialise(self);
    self:create();
end

function ISAirDropInComing:prerender()
    ISPanel.prerender(self);
end

function ISAirDropInComing:destroy()
    UIManager.setShowPausedMessage(true)
    this.instance = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

function ISAirDropInComing:render()
    local width = getPlayerScreenWidth(1)
    local hight = getPlayerScreenHeight(1)
    local Zombies = 0
    for Time, Action in pairs(AirDropFunction.AirDropActionList) do
        if Time ~= "BGMInt" then
            Zombies = Zombies + Action.ZombieCount
        end
    end
    local text = getText("IGUI_ZombieLeft") .. " " .. Zombies
    local W = 128
    local TextLength = getTextManager():MeasureStringX(UIFont.NewLarge, text)
    -- 按原始比例
    self:drawText(text, width / 2 - TextLength / 2, W, 1, 0.1, 0.1, self.alpha, UIFont.NewLarge);
    if Zombies == 0 then
        self:destroy()
    end
end

function ISAirDropInComing:create()

end

function ISAirDropInComing:new(x, y, width, height, player, Status, Time)
    local o = {};
    o = ISPanel:new(x, y, width, height);
    setmetatable(o, self);
    o.character = player;
    self.__index = self;
    this.instance = o
    o.anchorRight = true
    o.Status = Status
    o.Time = Time
    o.anchorBottom = true
    o.anchorTop = true
    o.anchorLeft = true
    o.alpha = 1
    return o;
end


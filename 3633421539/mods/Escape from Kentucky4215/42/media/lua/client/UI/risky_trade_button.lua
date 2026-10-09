-- ============================================================================
-- Trade button. Same frame/style as ammoButton (yellow border, grey fill),
-- placed to the right of the boxed-bullet icon. Shows the vanilla walkie-talkie
-- icon. Greyed out while the player has no radio; lit once a radio is present.
-- Left-click opens the trade UI.
-- ============================================================================

require "ISUI/ISButton"

tradeButton = ISButton:derive("tradeButton")

function tradeButton:new(x, y, w, h, onClick)
    local o = {}
    o = ISButton:new(x, y, w, h)

    setmetatable(o, self)
    self.__index = self

    o.onClick = onClick
    o.hasRadio = false

    -- Same frame as ammoButton (the boxed-bullet slot this button sits beside).
    o.borderColor.r = 1
    o.borderColor.g = 1
    o.borderColor.b = 0.0
    o.borderColor.a = 0.5

    o.backgroundColor.r = 0.5
    o.backgroundColor.g = 0.5
    o.backgroundColor.b = 0.5
    o.backgroundColor.a = 0.3

    o.backgroundColorMouseOver.r = 0.5
    o.backgroundColorMouseOver.g = 0.5
    o.backgroundColorMouseOver.b = 0.5
    o.backgroundColorMouseOver.a = 0.8

    -- Walkie-talkie icon (vanilla). Fall back through the radio items.
    o.radioTexture = nil
    for _, t in ipairs(MFSTrade.Config.RadioItems) do
        local seed = ScriptManager.instance:getItem(t)
        local icon = seed and seed:getIcon()
        if icon then
            o.radioTexture = getTexture("media/textures/Item_" .. icon .. ".png")
            if o.radioTexture then break end
        end
    end
    if o.radioTexture then
        o:setImage(o.radioTexture)
    end

    o:bringToTop()
    return o
end

function tradeButton:render()
    ISButton.render(self)

    self.hasRadio = MFSTrade.HasRadio(getPlayer())
    self.enabled = MFSTrade.IsEnabled()

    if self.radioTexture then
        self:setImage(self.radioTexture)
        if self.hasRadio and self.enabled then
            self:setTextureRGBA(1.0, 1.0, 1.0, 1.0)
            self.tooltip = nil
        else
            -- Greyed out while the player carries no radio or trading is disabled.
            self:setTextureRGBA(0.35, 0.35, 0.35, 0.6)
        end
    end

    if not self.enabled then
        self:drawText(getText("IGUI_MFSTrade_Disabled"), 4, self.height - 14, 1, 1, 1, 1, UIFont.Small)
    elseif not self.hasRadio then
        self:drawText(getText("IGUI_MFSTrade_NeedRadio"), 4, self.height - 14, 1, 1, 1, 1, UIFont.Small)
    end
end

function tradeButton:onMouseDown(x, y)
    if not self.hasRadio or not self.enabled then
        return
    end
    ISButton.onMouseDown(self, x, y)
    if self.onClick then
        self.onClick(self)
    end
end

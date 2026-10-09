riskyUI_slider = ISCollapsableWindow:derive("riskyUI_slider")

local function roundOffset(value)
    return math.floor(value * 10000 + 0.5) / 10000
end

local function formatAxisValue(value, axis)
    -- X/Z: 0..200 maps to -0.10..+0.10.
    -- Y:   0..600 maps to -0.30..+0.30 for long weapons and unusual mounts.
    -- A normal arrow step is 0.001; Shift uses the slider's 10-unit step = 0.01.
    local center = axis == 2 and 300 or 100
    return roundOffset((value - center) * 0.001)
end

function riskyUI_slider:callback(value, slider)
    if not self.worldmodel then
        return
    end

    local list = {formatAxisValue(self.slider1.currentValue, 1), formatAxisValue(self.slider2.currentValue, 2),
                  formatAxisValue(self.slider3.currentValue, 3)}

    local Gun = getPlayer():getPrimaryHandItem()

    -- MFS RC6: risky_inspect_core.lua rotates handgun scene models 180 degrees about Y.
    -- That flips Z between the inspection scene and the weapon model-script attachment
    -- space that actually places the part on the held weapon. Negate Z for handguns so
    -- the held model follows the GUI preview. Scene position below keeps the raw value.
    local heldZ = list[3]
    if Gun and Gun:getSwingAnim() == "Handgun" then
        heldZ = -heldZ
    end

    self.itempartoffsetment:getOffset():set(list[1], list[2], heldZ)

    local ModData = Gun:getModData().GunPos
    if not ModData then
        ModData = {}
        Gun:getModData().GunPos = ModData
    end

    if not ModData[self.itempart] then
        ModData[self.itempart] = {
            x = 0,
            y = 0,
            z = 0
        }
    end

    ModData[self.itempart].x = list[1]
    ModData[self.itempart].y = list[2]
    ModData[self.itempart].z = list[3]

    -- RC2-1: mark the item dirty on every slider update, but let the network
    -- sync debounce the actual client/server command.
    if MFS_GunPosChanged then
        MFS_GunPosChanged(Gun)
    end

    if not string.find(self.worldmodel, "nil") then
        self.parenta.scene.javaObject:fromLua4("setObjectPosition", self.worldmodel, list[1], list[2], list[3])
    end

    -- The held-model renderer caches attached items and otherwise compares only part IDs.
    -- Force a refresh so edited GunPos values are reflected immediately on the character.
    if AWCWF_Attach and AWCWF_Attach.Apply_Effect then
        AWCWF_Attach.Apply_Effect(getPlayer(), Gun, true)
    end
end


function riskyUI_slider:onReset()
    if not self.itempart then return end
    self.slider1.currentValue = 100
    self.slider2.currentValue = 300
    self.slider3.currentValue = 100
    self:callback(100, self.slider1)
end

function riskyUI_slider:render()
    ISCollapsableWindow.render(self)

    local itemname = "None"
    local itemtexture = nil

    if self.itempart then
        local itemseed = ScriptManager.instance:getItem(self.itempart)
        local icon = itemseed:getIcon()
        itemtexture = getTexture("media/textures/Item_" .. icon .. ".png")
        itemname = itemseed:getDisplayName()
    end

    if itemtexture then
        self:drawTextureScaled(itemtexture, self.baselenth * 3, self.baselenth * 3, self.width - self.baselenth * 12,
            self.width - self.baselenth * 12, 1.0, 1.0, 1.0, 1.0)
    end

    self:drawText(itemname, self.baselenth * 4, self.width - self.baselenth * 8, 1, 1, 1, 0.9, UIFont.Medium)

    local sliders = {self.slider1, self.slider2, self.slider3}
    local offsets = {self.offsetX, self.offsetY, self.offsetZ}
    local labels = {"X", "Y", "Z"}

    for i, slider in ipairs(sliders) do
        local value = formatAxisValue(slider.currentValue, i)
        self:drawText(labels[i] .. ": " .. value, self.baselenth * 4, offsets[i], 1, 1, 1, 0.9, UIFont.Medium)
    end
end

function riskyUI_slider:createChildren()
    ISCollapsableWindow.createChildren(self)

    local y = self.height / 2
    local x = self.baselenth
    local width = self.width - 2 * self.baselenth
    local height = 1.5 * self.baselenth

    local sliders = {}
    local offsets = {}

    for i = 1, 3 do
        local slider = ISSliderPanel:new(x, y, width, height, self, self.callback)
        slider:initialise()
        slider:instantiate()
        if i == 2 then
            slider:setValues(0, 600, 1, 10)
            slider.currentValue = 300
        else
            slider:setValues(0, 200, 1, 10)
            slider.currentValue = 100
        end
        self:addChild(slider)
        sliders[i] = slider
        offsets[i] = y + self.baselenth + height
        y = y + self.baselenth * 3 + height
    end

    self.slider1, self.slider2, self.slider3 = sliders[1], sliders[2], sliders[3]
    self.offsetX, self.offsetY, self.offsetZ = offsets[1], offsets[2], offsets[3]

    self.resetButton = ISButton:new(self.baselenth, self.height - self.baselenth * 3,
        self.width - self.baselenth * 2, self.baselenth * 2, "Reset selected part", self, self.onReset)
    self.resetButton:initialise()
    self.resetButton:instantiate()
    self:addChild(self.resetButton)
end

function riskyUI_slider:new(x, y, width, height, parent)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o:setResizable(true)
    o.title = "part"
    o.parenta = parent
    o.parttype = "Wrench"
    o.baselenth = width / 20
    return o
end

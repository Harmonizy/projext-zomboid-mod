--[[ AWCWF Weapon Tooltip - 按住 Alt 键显示枪械详细信息 ]] --
AWCWF_Tooltip = AWCWF_Tooltip or {}
AWCWF_Tooltip.maxPartMountLineLength = AWCWF_Tooltip.maxPartMountLineLength or 70
AWCWF_Tooltip.maxPartMountLineWidth = AWCWF_Tooltip.maxPartMountLineWidth or 520

-- 检测是否为 AWCWF 武器（有 weaponpart modData）
local function isAWCWFWeapon(item)
    if not item or not instanceof(item, "HandWeapon") then
        return false
    end
    local md = item:getModData()
    if not md or not md.weaponpart then
        return false
    end
    for _ in pairs(md.weaponpart) do
        return true
    end
    return false
end

local function isWeaponPart(item)
    return item and instanceof(item, "WeaponPart")
end

-- 获取已安装部件列表
local function getInstalledParts(item)
    local parts = {}
    local md = item:getModData()
    if not md or not md.weaponpart then
        return parts
    end
    local IGNORE_SLOTS = {
        Clip = true,
        Bolt = true
    }
    for slotName, partFullType in pairs(md.weaponpart) do
        if not IGNORE_SLOTS[slotName] then
            local scriptItem = getScriptManager():getItem(partFullType)
            if scriptItem then
                table.insert(parts, {
                    slot = slotName,
                    name = scriptItem:getDisplayName(),
                    fullType = partFullType
                })
            end
        end
    end
    -- 按插槽名排序，保持一致的显示顺序
    table.sort(parts, function(a, b)
        return a.slot < b.slot
    end)
    return parts
end

-- 颜色常量
local CLR_YELLOW = {1.0, 1.0, 0.8}
local CLR_GREY = {0.7, 0.7, 0.7}
local CLR_CYAN = {0.6, 0.85, 1.0}

local function addLabelValueLine(lines, label, value)
    table.insert(lines, {
        type = "labelvalue",
        label = label .. ": ",
        value = value,
        labelR = CLR_GREY[1],
        labelG = CLR_GREY[2],
        labelB = CLR_GREY[3],
        valueR = CLR_CYAN[1],
        valueG = CLR_CYAN[2],
        valueB = CLR_CYAN[3]
    })
end

local function addSeparatorLine(lines)
    table.insert(lines, {
        type = "separator"
    })
end

local function addTitleLine(lines, text)
    table.insert(lines, {
        type = "simple",
        text = text,
        r = CLR_YELLOW[1],
        g = CLR_YELLOW[2],
        b = CLR_YELLOW[3]
    })
end

local function getTextOrFallback(key, fallback)
    local text = getText(key)
    if text == key then
        return fallback
    end
    return text
end

local function formatSignedNumber(value, precision, suffix)
    local sign = value > 0 and "+" or ""
    local pattern = "%." .. precision .. "f"
    return sign .. string.format(pattern, value):gsub("^%s+", "") .. (suffix or "")
end

local function addPartStatLine(lines, item, methodName, labelKey, precision, suffix)
    if not item[methodName] then
        return
    end

    local value = item[methodName](item)
    if not value or value == 0 then
        return
    end

    addLabelValueLine(lines, getText(labelKey), formatSignedNumber(value, precision, suffix))
end

local function getMountWeaponNames(item)
    local mountOn = item:getMountOn()
    local weapons = {}
    if not mountOn or mountOn:size() == 0 then
        return weapons
    end

    for i = 0, mountOn:size() - 1 do
        local fullType = tostring(mountOn:get(i))
        local scriptItem = getScriptManager():getItem(fullType)
        table.insert(weapons, scriptItem and scriptItem:getDisplayName() or fullType)
    end

    table.sort(weapons)
    return weapons
end

local function addWrappedWeaponList(lines, weapons)
    local font = ISToolTip.GetFont()
    local currentSegments = {{
        text = "  ",
        r = CLR_GREY[1],
        g = CLR_GREY[2],
        b = CLR_GREY[3]
    }}
    local currentText = "  "

    for i, weapon in ipairs(weapons) do
        local isLast = i == #weapons
        local commaText = isLast and "" or ","
        local testText = currentText .. weapon .. commaText

        if getTextManager():MeasureStringX(font, testText) > AWCWF_Tooltip.maxPartMountLineWidth
                and #currentSegments > 1 then
            table.insert(lines, {
                type = "segments",
                segments = currentSegments
            })
            currentSegments = {{
                text = "  ",
                r = CLR_GREY[1],
                g = CLR_GREY[2],
                b = CLR_GREY[3]
            }}
            currentText = "  "
        end

        table.insert(currentSegments, {
            text = weapon,
            r = CLR_CYAN[1],
            g = CLR_CYAN[2],
            b = CLR_CYAN[3]
        })
        currentText = currentText .. weapon

        if not isLast then
            table.insert(currentSegments, {
                text = ", ",
                r = CLR_GREY[1],
                g = CLR_GREY[2],
                b = CLR_GREY[3]
            })
            currentText = currentText .. ", "
        end
    end

    if #currentSegments > 1 then
        table.insert(lines, {
            type = "segments",
            segments = currentSegments
        })
    end
end

-- 构建武器 Tooltip 行数据
local function buildWeaponTooltipLines(item)
    local lines = {}

    local minDmg = item:getMinDamage()
    local maxDmg = item:getMaxDamage()
    if minDmg ~= 0 or maxDmg ~= 0 then
        addLabelValueLine(lines, getText("Tooltip_weapon_Damage"), string.format("%.1f ~ %.1f", minDmg, maxDmg))
    end

    local hitChance = item:getHitChance()
    if hitChance ~= 0 then
        addLabelValueLine(lines, getText("Tooltip_weapon_HitChance"), hitChance .. "%")
    end

    local aimTime = item:getAimingTime()
    if aimTime ~= 0 then
        addLabelValueLine(lines, getText("Tooltip_weapon_AimingTime"), tostring(aimTime))
    end

    local maxRange = item:getMaxRange()
    if maxRange ~= 0 then
        addLabelValueLine(lines, getText("Tooltip_weapon_MaxRange"), string.format("%.1f", maxRange))
    end

    local recoil = item:getRecoilDelay()
    if recoil ~= 0 then
        addLabelValueLine(lines, getText("Tooltip_weapon_RecoilDelay"), tostring(recoil))
    end

    local reloadTime = item:getReloadTime()
    if reloadTime ~= 0 then
        addLabelValueLine(lines, getText("Tooltip_weapon_ReloadTime"), tostring(reloadTime))
    end

    local soundRadius = item:getSoundRadius()
    if soundRadius ~= 0 then
        addLabelValueLine(lines, getText("Tooltip_weapon_SoundRadius"), tostring(soundRadius))
    end

    local parts = getInstalledParts(item)
    if #parts > 0 then
        if #lines > 0 then
            addSeparatorLine(lines)
        end
        addTitleLine(lines, getText("Tooltip_weapon_ModifyWeapon") .. ":")
        addSeparatorLine(lines)

        for _, part in ipairs(parts) do
            local slotKey = "IGUI_" .. part.slot
            local slotLabel = getText(slotKey)
            if slotLabel == slotKey then
                slotLabel = part.slot
            end
            addLabelValueLine(lines, "  " .. slotLabel, part.name)
        end
    end

    return lines
end

local function buildWeaponPartTooltipLines(item, altDown)
    local lines = {}

    addTitleLine(lines, item:getDisplayName())
    addLabelValueLine(lines, getText("Tooltip_item_Weight"), string.format("%.2f", item:getActualWeight()))

    if item:getConditionMax() > 0 then
        addLabelValueLine(lines, getText("IGUI_invpanel_Condition"), math.floor(item:getCondition()) .. "/" .. item:getConditionMax())
    end

    if item.getPartType then
        local partType = item:getPartType()
        if partType and partType ~= "" then
            addLabelValueLine(lines, getText("Tooltip_weapon_PartType"), getTextOrFallback("IGUI_" .. partType, partType))
        end
    end

    addSeparatorLine(lines)
    if item.getDamage then
        local damage = item:getDamage()
        if damage and math.abs(damage) >= 0.5 then
            addLabelValueLine(lines, getText("Tooltip_weapon_Damage"), formatSignedNumber(damage, 1))
        end
    end
    addPartStatLine(lines, item, "getHitChance", "Tooltip_weapon_HitChance", 0, "%")
    addPartStatLine(lines, item, "getAimingTime", "Tooltip_weapon_AimingTime", 0)
    addPartStatLine(lines, item, "getMinRange", "Tooltip_weapon_MinRange", 0)
    addPartStatLine(lines, item, "getMaxRange", "Tooltip_weapon_MaxRange", 0)
    addPartStatLine(lines, item, "getAngle", "Tooltip_weapon_Angle", 2)
    addPartStatLine(lines, item, "getReloadTime", "Tooltip_weapon_ReloadTime", 0)
    addPartStatLine(lines, item, "getRecoilDelay", "Tooltip_weapon_RecoilDelay", 0)
    addPartStatLine(lines, item, "getSoundRadius", "Tooltip_weapon_SoundRadius", 0, "%")
    addPartStatLine(lines, item, "getClipSizeModifier", "Tooltip_weapon_ClipSize", 0)

    local weapons = getMountWeaponNames(item)
    if #weapons > 0 and altDown then
        addSeparatorLine(lines)
        addTitleLine(lines, getText("Tooltip_weapon_CanBeMountOn") .. ":")
        addSeparatorLine(lines)
        addWrappedWeaponList(lines, weapons)
    end

    return lines
end

-- 计算自定义 Tooltip 区域尺寸
local function getTooltipLinesSize(lines, font, padding)
    local lineHeight = getTextManager():getFontHeight(font)
    local maxWidth = 0
    local totalHeight = 0

    for _, line in ipairs(lines) do
        if line.type == "simple" then
            local w = getTextManager():MeasureStringX(font, line.text)
            if w > maxWidth then
                maxWidth = w
            end
            totalHeight = totalHeight + lineHeight
        elseif line.type == "segments" then
            local w = 0
            for _, seg in ipairs(line.segments) do
                w = w + getTextManager():MeasureStringX(font, seg.text)
            end
            if w > maxWidth then
                maxWidth = w
            end
            totalHeight = totalHeight + lineHeight
        elseif line.type == "labelvalue" then
            local w = getTextManager():MeasureStringX(font, line.label .. line.value)
            if w > maxWidth then
                maxWidth = w
            end
            totalHeight = totalHeight + lineHeight
        elseif line.type == "separator" then
            totalHeight = totalHeight + 4
        end
    end

    if lines[1] and lines[1].type == "simple" then
        totalHeight = totalHeight + (lineHeight / 2)
    end

    return maxWidth + (padding * 2) + 2, totalHeight + (padding * 2) + 2, lineHeight
end

-- 通用绘制：将行数据绘制到指定区域
local function drawTooltipLines(self, lines, x, y, width, height, font, padding, lineHeight)
    self:drawRect(x, y, width, height, 0.9, 0, 0, 0)
    self:drawRectBorder(x, y, width, height, 1, 0.4, 0.4, 0.4)

    local yPos = y + padding
    for i, line in ipairs(lines) do
        if line.type == "simple" then
            self:drawText(line.text, x + padding, yPos, line.r, line.g, line.b, 1, font)
            yPos = yPos + lineHeight
            if i == 1 then
                yPos = yPos + (lineHeight / 2)
            end
        elseif line.type == "segments" then
            local xOff = x + padding
            for _, seg in ipairs(line.segments) do
                self:drawText(seg.text, xOff, yPos, seg.r, seg.g, seg.b, 1, font)
                xOff = xOff + getTextManager():MeasureStringX(font, seg.text)
            end
            yPos = yPos + lineHeight
        elseif line.type == "labelvalue" then
            local labelW = getTextManager():MeasureStringX(font, line.label)
            self:drawText(line.label, x + padding, yPos, line.labelR, line.labelG, line.labelB, 1, font)
            self:drawText(line.value, x + padding + labelW, yPos, line.valueR, line.valueG, line.valueB, 1, font)
            yPos = yPos + lineHeight
        elseif line.type == "separator" then
            self:drawRect(x + padding, yPos + 2, width - (padding * 2), 1, 1, 0.4, 0.4, 0.4)
            yPos = yPos + 4
        end
    end
end

-- Keep a tooltip completely to one side of the cursor whenever the screen has
-- room.  Clamping a wide translated tooltip back across its inventory row can
-- make that row lose and regain hover every frame, producing visible flicker.
local function getTooltipPositionAwayFromMouse(width, height)
    local mouseX = getMouseX()
    local mouseY = getMouseY()
    local gap = 24
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local rightSpace = screenW - mouseX - gap
    local leftSpace = mouseX - gap

    local x
    local y

    -- Prefer the roomier horizontal side. Horizontal separation also prevents
    -- a tall tooltip from covering the hovered inventory row.
    if leftSpace >= rightSpace and leftSpace >= width then
        x = mouseX - gap - width
        y = math.max(0, math.min(mouseY + gap, screenH - height - 1))
    elseif rightSpace >= width then
        x = mouseX + gap
        y = math.max(0, math.min(mouseY + gap, screenH - height - 1))
    elseif leftSpace >= width then
        x = mouseX - gap - width
        y = math.max(0, math.min(mouseY + gap, screenH - height - 1))
    elseif screenH - mouseY - gap >= height then
        x = math.max(0, math.min(mouseX + gap, screenW - width - 1))
        y = mouseY + gap
    elseif mouseY - gap >= height then
        x = math.max(0, math.min(mouseX + gap, screenW - width - 1))
        y = mouseY - gap - height
    else
        -- Pathological case: the tooltip itself is larger than the available
        -- screen area. Keep it visible; normal compact wrapping avoids this.
        x = math.max(0, math.min(mouseX + gap, screenW - width - 1))
        y = math.max(0, math.min(mouseY + gap, screenH - height - 1))
    end

    return x, y
end

local function renderTooltipLinesAtMouse(self, lines)
    if not lines or #lines == 0 then
        return
    end

    local font = ISToolTip.GetFont()
    local padding = 6
    local width, height, lineHeight = getTooltipLinesSize(lines, font, padding)
    local tooltipX, tooltipY = getTooltipPositionAwayFromMouse(width, height)

    self:setX(tooltipX)
    self:setY(tooltipY)
    self:setWidth(width)
    self:setHeight(height)

    drawTooltipLines(self, lines, 0, 0, width, height, font, padding, lineHeight)
end

-- 在原版 Tooltip 下方追加自定义区域
local function renderTooltipLinesBelowOriginal(self, lines)
    if not lines or #lines == 0 then
        return
    end

    local font = ISToolTip.GetFont()
    local padding = 6
    local gap = 4
    local customWidth, customHeight, lineHeight = getTooltipLinesSize(lines, font, padding)
    local originalWidth = self:getWidth()
    local originalHeight = self:getHeight()
    local finalWidth = math.max(originalWidth, customWidth)
    local finalHeight = originalHeight + gap + customHeight

    self:setWidth(finalWidth)
    self:setHeight(finalHeight)

    drawTooltipLines(self, lines, 0, originalHeight + gap, finalWidth, customHeight, font, padding, lineHeight)
end

-- Hook ISToolTipInv:render，按住 Alt 时在原版 Tooltip 下方追加自定义信息
local original_render = ISToolTipInv.render

function ISToolTipInv:render()
    local canRenderCustom = not ISContextMenu.instance or not ISContextMenu.instance.visibleCheck

    if canRenderCustom and isWeaponPart(self.item) then
        local altDown = isKeyDown(Keyboard.KEY_LMENU) or isKeyDown(Keyboard.KEY_RMENU)
        local lines = buildWeaponPartTooltipLines(self.item, altDown)
        renderTooltipLinesAtMouse(self, lines)
        return
    end

    local shouldAppend = canRenderCustom
            and (isKeyDown(Keyboard.KEY_LMENU) or isKeyDown(Keyboard.KEY_RMENU))
            and self.item
            and isAWCWFWeapon(self.item)

    original_render(self)

    if shouldAppend then
        local lines = buildWeaponTooltipLines(self.item)
        renderTooltipLinesBelowOriginal(self, lines)
    end
end

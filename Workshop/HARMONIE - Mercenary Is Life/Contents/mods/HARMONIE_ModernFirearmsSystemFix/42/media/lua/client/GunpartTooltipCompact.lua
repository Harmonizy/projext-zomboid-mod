--[[
  Gunpart Tooltip Compactor for EFKDE
  Wraps long weapon compatibility lists to prevent tooltip overflow
]]--

require "GunpartTooltipOptions"

GunpartTooltipCompact = GunpartTooltipCompact or {}
GunpartTooltipCompact.maxLineLength = 70 -- Characters per line
GunpartTooltipCompact.maxLineWidth = 520 -- Rendered pixels; Unicode-safe

-- Helper: Get color for stat value (returns r, g, b)
local function getStatColor(value, isReversed)
    -- Reversed stats: positive is bad (red), negative is good (green)
    -- Normal stats: positive is good (green), negative is bad (red)
    if isReversed then
        if value > 0 then
            return 0.8, 0.2, 0.2  -- Red for bad (positive on reversed stats)
        else
            return 0.2, 0.8, 0.2  -- Green for good (negative on reversed stats)
        end
    else
        if value > 0 then
            return 0.2, 0.8, 0.2  -- Green for good (positive on normal stats)
        else
            return 0.8, 0.2, 0.2  -- Red for bad (negative on normal stats)
        end
    end
end

-- Build custom tooltip text with wrapped weapon list
-- Returns array of line objects with different types:
-- {type="simple", text=string, r=number, g=number, b=number}
-- {type="labelvalue", label=string, value=string, labelR=..., valueR=...}
-- {type="separator"}
local function buildCustomTooltipText(item)
    local lines = {}
    
    -- Vanilla light yellow for normal text
    local yellowR, yellowG, yellowB = 1.0, 1.0, 0.8
    local whiteR, whiteG, whiteB = 1, 1, 1
    
    -- Add basic item info using proper vanilla methods
    table.insert(lines, {type = "simple", text = item:getDisplayName(), r = yellowR, g = yellowG, b = yellowB})
    
    -- Add weight - label in yellow, value in white
    local weight = item:getActualWeight()
    table.insert(lines, {
        type = "labelvalue",
        label = getText("Tooltip_item_Weight") .. ": ",
        value = string.format("%.2f", weight),
        labelR = yellowR, labelG = yellowG, labelB = yellowB,
        valueR = whiteR, valueG = whiteG, valueB = whiteB
    })
    
    -- Add condition if applicable - label in yellow, value in white
    if item:getConditionMax() > 0 then
        local condition = math.floor(item:getCondition())
        local conditionMax = item:getConditionMax()
        table.insert(lines, {
            type = "labelvalue",
            label = getText("IGUI_invpanel_Condition") .. ": ",
            value = condition .. "/" .. conditionMax,
            labelR = yellowR, labelG = yellowG, labelB = yellowB,
            valueR = whiteR, valueG = whiteG, valueB = whiteB
        })
    end
    
    -- Add weapon part specific stats using vanilla translation - label in yellow, value in white
    local partType = item:getPartType()
    if partType and partType ~= "" then
        table.insert(lines, {
            type = "labelvalue",
            label = getText("Tooltip_weapon_PartType") .. ": ",
            value = getText("Tooltip_weapon_" .. partType, partType),
            labelR = yellowR, labelG = yellowG, labelB = yellowB,
            valueR = whiteR, valueG = whiteG, valueB = whiteB
        })
    end
    
    -- Add horizontal separator line after parttype
    table.insert(lines, {type = "separator"})
    
    -- Add damage modifier if present and significant (>= 0.5)
    local damage = item:getDamage()
    if math.abs(damage) >= 0.5 then
        local sign = damage > 0 and "+" or ""
        local r, g, b = getStatColor(damage, false)
        table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_Damage") .. ": ", value = sign .. string.format("%.1f", damage), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
    end
    
    -- Add other relevant stats (only if non-zero and method exists)
    if item.getHitChance then
        local hitChance = item:getHitChance()
        if hitChance ~= 0 then
            local sign = hitChance > 0 and "+" or ""
            local r, g, b = getStatColor(hitChance, false)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_HitChance") .. ": ", value = sign .. string.format("%.0f", hitChance) .. "%", labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
    
    if item.getAimingTime then
        local aimTime = item:getAimingTime()
        if aimTime ~= 0 then
            local sign = aimTime > 0 and "+" or ""
            local r, g, b = getStatColor(aimTime, true)  -- REVERSED: positive is bad (slower)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_AimingTime") .. ": ", value = sign .. string.format("%.0f", aimTime), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
        
    if item.getAngle then
        local Angle = item:getAngle()
        if Angle ~= 0 then
            local sign = Angle > 0 and "+" or ""
            local r, g, b = getStatColor(Angle, true)  -- REVERSED: positive is bad (slower)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_Angle") .. ": ", value = sign .. string.format("%.0f", Angle), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
            
    if item.getMinSightRange then
        local MinSightRange = item:getMinSightRange()
        if MinSightRange ~= 0 then
            local sign = MinSightRange > 0 and "+" or ""
            local r, g, b = getStatColor(MinSightRange, false)  -- REVERSED: positive is bad (slower)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_MinSightRange") .. ": ", value = sign .. string.format("%.0f", MinSightRange), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
                 
    if item.getMaxSightRange then
        local MaxSightRange = item:getMaxSightRange()
        if MaxSightRange ~= 0 then
            local sign = MaxSightRange > 0 and "+" or ""
            local r, g, b = getStatColor(MaxSightRange, false)  -- REVERSED: positive is bad (slower)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_MaxSightRange") .. ": ", value = sign .. string.format("%.0f", MaxSightRange), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
            
    if item.getLowLightBonus then
        local LowLightBonus = item:getLowLightBonus()
        if LowLightBonus ~= 0 then
            local sign = LowLightBonus > 0 and "+" or ""
            local r, g, b = getStatColor(LowLightBonus, false)  -- REVERSED: positive is bad (slower)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_LowLightBonus") .. ": ", value = sign .. string.format("%.0f", LowLightBonus), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
            
    if item.getWeightModifier then
        local Weight = item:getWeightModifier()
        if Weight ~= 0 then
            local sign = Weight > 0 and "+" or ""
            local r, g, b = getStatColor(Weight, true)  -- REVERSED: heavier is bad
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_Weight") .. ": ", value = sign .. string.format("%.2f", Weight), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end

    if item.getMinRange then
        local minRange = item:getMinRange()
        if minRange ~= 0 then
            local sign = minRange > 0 and "+" or ""
            local r, g, b = getStatColor(minRange, false)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_MinRange") .. ": ", value = sign .. string.format("%.0f", minRange), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
    
    if item.getMaxRange then
        local maxRange = item:getMaxRange()
        if maxRange ~= 0 then
            local sign = maxRange > 0 and "+" or ""
            local r, g, b = getStatColor(maxRange, false)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_MaxRange") .. ": ", value = sign .. string.format("%.0f", maxRange), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end

    if item.getMinRange then
        local minRange = item:getMinRange()
        if minRange ~= 0 then
            local sign = minRange > 0 and "+" or ""
            local r, g, b = getStatColor(minRange, false)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_MinRange") .. ": ", value = sign .. string.format("%.0f", minRange), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
            
    if item.getCrit then
        local Crit = item:getCrit()
        if Crit ~= 0 then
            local sign = Crit > 0 and "+" or ""
            local r, g, b = getStatColor(Crit, false)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_Crit") .. ": ", value = sign .. string.format("%.0f", Crit), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end

    -- CriticalChance / CritDmgMultiplier / CyclicRateMultiplier have no native
    -- WeaponPart fields; their values live in AWCWF_PartStatSet keyed by part type.
    if AWCWF_GetPartStatBonus then
        local statBonus = AWCWF_GetPartStatBonus(item)
        if statBonus then
            local critChance = statBonus.CriticalChance or 0
            if critChance ~= 0 then
                local sign = critChance > 0 and "+" or ""
                local r, g, b = getStatColor(critChance, false)
                table.insert(lines, {type = "labelvalue", label = getText("IGUI_WeaponUI_CriticalChance") .. ": ", value = sign .. string.format("%.0f", critChance) .. "%", labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
            end
            local critDmg = statBonus.CritDmgMultiplier or 0
            if critDmg ~= 0 then
                local sign = critDmg > 0 and "+" or ""
                local r, g, b = getStatColor(critDmg, false)
                table.insert(lines, {type = "labelvalue", label = getText("IGUI_WeaponUI_CritDmg") .. ": ", value = sign .. string.format("%.2f", critDmg) .. "x", labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
            end
            local cyclic = statBonus.CyclicRateMultiplier or 0
            if cyclic ~= 0 then
                local sign = cyclic > 0 and "+" or ""
                local r, g, b = getStatColor(cyclic, false)
                table.insert(lines, {type = "labelvalue", label = getText("IGUI_WeaponUI_CyclicRate") .. ": ", value = sign .. string.format("%.2f", cyclic) .. "x", labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
            end
        end
    end
    
    if item.getAngle then
        local angle = item:getAngle()
        if angle ~= 0 then
            local sign = angle > 0 and "+" or ""
            local r, g, b = getStatColor(angle, false)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_Angle") .. ": ", value = sign .. string.format("%.2f", angle), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
    
    if item.getReloadTime then
        local reloadTime = item:getReloadTime()
        if reloadTime ~= 0 then
            local sign = reloadTime > 0 and "+" or ""
            local r, g, b = getStatColor(reloadTime, true)  -- REVERSED: positive is bad (slower)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_ReloadTime") .. ": ", value = sign .. string.format("%.0f", reloadTime), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
    
    if item.getRecoilDelay then
        local recoil = item:getRecoilDelay()
        if recoil ~= 0 then
            local sign = recoil > 0 and "+" or ""
            local r, g, b = getStatColor(recoil, true)  -- REVERSED: positive is bad (more delay)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_RecoilDelay") .. ": ", value = sign .. string.format("%.0f", recoil), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
    
    if item.getSoundRadius then
        local soundRadius = item:getSoundRadius()
        if soundRadius ~= 0 then
            local sign = soundRadius > 0 and "+" or ""
            local r, g, b = getStatColor(soundRadius, true)  -- REVERSED: positive is bad (louder)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_SoundRadius") .. ": ", value = sign .. string.format("%.0f", soundRadius) .. "%", labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
    
    if item.getClipSizeModifier then
        local clipSize = item:getClipSizeModifier()
        if clipSize ~= 0 then
            local sign = clipSize > 0 and "+" or ""
            local r, g, b = getStatColor(clipSize, false)
            table.insert(lines, {type = "labelvalue", label = getText("Tooltip_weapon_ClipSize") .. ": ", value = sign .. string.format("%.0f", clipSize), labelR = 1.0, labelG = 1.0, labelB = 0.8, valueR = r, valueG = g, valueB = b})
        end
    end
    
    -- Get and wrap mount list (only if option is enabled)
    if GunpartTooltipOptions.shouldShowMountList() then

        local mountOn = item:getMountOn()
        if mountOn and mountOn:size() > 0 then
        local weapons = {}
        for i = 0, mountOn:size() - 1 do
            local scriptName = tostring(mountOn:get(i))
            -- Try to get actual item display name instead of script ID
            local scriptItem = getScriptManager():getItem(scriptName)
            if scriptItem then
                table.insert(weapons, scriptItem:getDisplayName())
            else
                table.insert(weapons, scriptName)
            end
        end
        
        local prefix = getText("Tooltip_weapon_CanBeMountOn")

        -- Weapon names in vanilla yellow, commas in dim grey
        local yellowR, yellowG, yellowB = 1.0, 1.0, 0.8
        local sepR, sepG, sepB = 0.8, 0.3, 0.3
        
        -- Emit the prefix line on its own, then weapons start on the next line
        table.insert(lines, {type = "simple", text = prefix .. ":", r = yellowR, g = yellowG, b = yellowB})
        -- Add horizontal separator line after CanBeMountOn
        table.insert(lines, {type = "separator"})
        -- Build segments: each weapon name + comma as separate colored segments
        local currentSegments = {{text = "  ", r = yellowR, g = yellowG, b = yellowB}}
        local currentLineText = "  "
        
        for i, weapon in ipairs(weapons) do
            local isLast = (i == #weapons)
            local weaponText = weapon
            local commaText = isLast and "" or ","
            local testLineText = currentLineText .. weaponText .. commaText
            
            -- Check if adding this weapon would exceed the line length
            if getTextManager():MeasureStringX(ISToolTip.GetFont(), testLineText)
                    > GunpartTooltipCompact.maxLineWidth and #currentSegments > 1 then
                -- Flush current line
                table.insert(lines, {type = "segments", segments = currentSegments})
                -- Start new continuation line with indent
                currentSegments = {{text = "  ", r = yellowR, g = yellowG, b = yellowB}}
                currentLineText = "  "
                testLineText = "  " .. weaponText .. commaText
            end
            
            table.insert(currentSegments, {text = weaponText, r = yellowR, g = yellowG, b = yellowB})
            currentLineText = currentLineText .. weaponText
            
            if not isLast then
                table.insert(currentSegments, {text = ",", r = sepR, g = sepG, b = sepB})
                table.insert(currentSegments, {text = " ", r = yellowR, g = yellowG, b = yellowB})
                currentLineText = currentLineText .. ", "
            end
        end
        -- Flush last line
        if #currentSegments > 0 then
            table.insert(lines, {type = "segments", segments = currentSegments})
        end
        end
    end
    
    return lines
end

-- Hook WeaponPart tooltips by building custom compact tooltip
-- Base-game Lua (including ISToolTipInv) is always loaded before mod Lua,
-- so we can hook directly at module load time without any event wrapper.
local original_ISToolTipInv_render = ISToolTipInv.render

-- Put wide translated tooltips wholly to one side of the cursor. The previous
-- screen-edge clamp could move a long compatibility tooltip back over the
-- container row being hovered, repeatedly closing and reopening the tooltip.
local function getCompactTooltipPosition(width, height)
    local mouseX = getMouseX()
    local mouseY = getMouseY()
    local gap = 24
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local rightSpace = screenW - mouseX - gap
    local leftSpace = mouseX - gap

    if leftSpace >= rightSpace and leftSpace >= width then
        return mouseX - gap - width,
                math.max(0, math.min(mouseY + gap, screenH - height - 1))
    end
    if rightSpace >= width then
        return mouseX + gap,
                math.max(0, math.min(mouseY + gap, screenH - height - 1))
    end
    if leftSpace >= width then
        return mouseX - gap - width,
                math.max(0, math.min(mouseY + gap, screenH - height - 1))
    end
    if screenH - mouseY - gap >= height then
        return math.max(0, math.min(mouseX + gap, screenW - width - 1)),
                mouseY + gap
    end
    if mouseY - gap >= height then
        return math.max(0, math.min(mouseX + gap, screenW - width - 1)),
                mouseY - gap - height
    end

    return math.max(0, math.min(mouseX + gap, screenW - width - 1)),
            math.max(0, math.min(mouseY + gap, screenH - height - 1))
end

function ISToolTipInv:render()
        -- Check if compact tooltip is enabled in mod options
        if not GunpartTooltipOptions.isCompactTooltipEnabled() then
            return original_ISToolTipInv_render(self)
        end
        
        -- Check if this is a weapon part with many mount points
        if self.item and instanceof(self.item, "WeaponPart") then
            local mountPoints = self.item:getMountOn()
            if mountPoints and mountPoints:size() > 5 then
                -- Build and render custom compact tooltip
                local tooltipLines = buildCustomTooltipText(self.item)
                
                if not ISContextMenu.instance or not ISContextMenu.instance.visibleCheck then
                    -- Use vanilla font and calculate size
                    local font = ISToolTip.GetFont()
                    local padding = 6
                    local lineHeight = getTextManager():getFontHeight(font)
                    
                    local maxWidth = 0
                    local totalHeight = 0
                    for _, line in ipairs(tooltipLines) do
                        if line.type == "simple" then
                            local lineWidth = getTextManager():MeasureStringX(font, line.text)
                            if lineWidth > maxWidth then maxWidth = lineWidth end
                            totalHeight = totalHeight + lineHeight
                        elseif line.type == "segments" then
                            local lineWidth = 0
                            for _, seg in ipairs(line.segments) do
                                lineWidth = lineWidth + getTextManager():MeasureStringX(font, seg.text)
                            end
                            if lineWidth > maxWidth then maxWidth = lineWidth end
                            totalHeight = totalHeight + lineHeight
                        elseif line.type == "labelvalue" then
                            local lineWidth = getTextManager():MeasureStringX(font, line.label .. line.value)
                            if lineWidth > maxWidth then maxWidth = lineWidth end
                            totalHeight = totalHeight + lineHeight
                        elseif line.type == "separator" then
                            -- Separator takes minimal space
                            totalHeight = totalHeight + 4
                        end
                    end
                    
                    -- Add half line space after item name (first line)
                    totalHeight = totalHeight + (lineHeight / 2)
                    
                    local tw = maxWidth + (padding * 2) + 2
                    local th = totalHeight + (padding * 2) + 2
                    
                    -- Position tooltip
                    local tx, ty = getCompactTooltipPosition(tw, th)
                    
                    self:setX(tx)
                    self:setY(ty)
                    self:setWidth(tw)
                    self:setHeight(th)
                    
                    -- Draw tooltip with vanilla styling
                    self:drawRect(0, 0, tw, th, 0.9, 0, 0, 0)
                    self:drawRectBorder(0, 0, tw, th, 1, 0.4, 0.4, 0.4)
                    
                    -- Draw text with proper colors from line data
                    local yPos = padding
                    for i, line in ipairs(tooltipLines) do
                        if line.type == "simple" then
                            self:drawText(line.text, padding, yPos, line.r, line.g, line.b, 1, font)
                            yPos = yPos + lineHeight
                            -- Add half line space after item name (first line)
                            if i == 1 then
                                yPos = yPos + (lineHeight / 2)
                            end
                        elseif line.type == "segments" then
                            local xOff = padding
                            for _, seg in ipairs(line.segments) do
                                self:drawText(seg.text, xOff, yPos, seg.r, seg.g, seg.b, 1, font)
                                xOff = xOff + getTextManager():MeasureStringX(font, seg.text)
                            end
                            yPos = yPos + lineHeight
                        elseif line.type == "labelvalue" then
                            -- Draw label and value separately with different colors
                            local labelWidth = getTextManager():MeasureStringX(font, line.label)
                            self:drawText(line.label, padding, yPos, line.labelR, line.labelG, line.labelB, 1, font)
                            self:drawText(line.value, padding + labelWidth, yPos, line.valueR, line.valueG, line.valueB, 1, font)
                            yPos = yPos + lineHeight
                        elseif line.type == "separator" then
                            -- Draw horizontal line (minimal spacing)
                            local lineY = yPos + 2
                            self:drawRect(padding, lineY, tw - (padding * 2), 1, 1, 0.4, 0.4, 0.4)
                            yPos = yPos + 4
                        end
                    end
                end
                return
            end
        end
        
        -- Use vanilla render for everything else
        return original_ISToolTipInv_render(self)
    end

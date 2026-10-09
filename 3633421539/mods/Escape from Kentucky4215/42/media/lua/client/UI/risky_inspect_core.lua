

require "ISUI/ISPanel"
require "TimedActions/ISEquipWeaponAction"
require "Gun_Vars/Weapon_Ability/AWCWF_Exact_RPM"
require "Gun_Vars/AWCWF_Part_Stat_Set"

function scanParts(container, player, weapon, slot, result, visited)
    if not container or visited[tostring(container)] then return end
    visited[tostring(container)] = true
    local items = container:getItems()
    if not items then return end
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item then
            local isWeaponPart = instanceof(item, "WeaponPart")
            if not isWeaponPart then
                local okCategory, category = pcall(function() return item:getCategory() end)
                isWeaponPart = okCategory and category == "WeaponPart"
            end
            if isWeaponPart and item:getPartType() == slot and not item:isBroken() then
                local ok, allowed = pcall(function() return item:canAttach(player, weapon) end)
                if ok and allowed then result[#result + 1] = item end
            end
            if instanceof(item, "InventoryContainer") then
                scanParts(item:getInventory(), player, weapon, slot, result, visited)
            end
        end
    end
end
-- Collect every ItemContainer the player can currently reach: their own
-- inventory plus floor-dropped containers (backpacks/boxes) and built
-- containers (crates, fridges, shelves, ...) on the player's square and the
-- eight surrounding squares on the same floor. Used by the attachment pane so
-- parts stored outside the player's backpack can be offered and installed.
function getReachableContainers(player)
    local containers = {}
    local seen = {}
    local function addContainer(container)
        if container and not seen[tostring(container)] then
            seen[tostring(container)] = true
            containers[#containers + 1] = container
        end
    end

    addContainer(player:getInventory())

    local square = player:getCurrentSquare()
    if not square then return containers end
    local cx, cy, cz = square:getX(), square:getY(), square:getZ()

    for dx = -1, 1 do
        for dy = -1, 1 do
            local gridSquare = getCell():getGridSquare(cx + dx, cy + dy, cz)
            if gridSquare then
                local objects = gridSquare:getObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj then
                            local ok, container = pcall(function() return obj:getContainer() end)
                            if ok then addContainer(container) end
                        end
                    end
                end
                local worldObjects = gridSquare:getWorldObjects()
                if worldObjects then
                    for i = 0, worldObjects:size() - 1 do
                        local worldObject = worldObjects:get(i)
                        if worldObject then
                            local ok, item = pcall(function() return worldObject:getItem() end)
                            if ok and item and instanceof(item, "InventoryContainer") then
                                addContainer(item:getInventory())
                            end
                        end
                    end
                end
            end
        end
    end
    return containers
end
riskyInspectWindow = nil
riskyShowPotentialAttachment = true
riskyUI = ISPanel:derive("riskyUI")
local btnView = getText("IGUI_RISKY_VIEW")
local btnViewWid = getTextManager():MeasureStringX(UIFont.NewSmall, btnView) + 10
local btnViewHgt = getTextManager():MeasureStringY(UIFont.NewSmall, btnView) + 10
function riskyUI:onOptionMouseDown(button)
    if button.internal == "close" then
        self:close()
    end
    if button.internal == "Rotate" then
        self.scene.startRotate = not self.scene.startRotate
    end
end
function riskyUI:close()
    -- RC2-1: do not leave the final slider position waiting on the debounce
    -- when the player explicitly closes the inspection window.
    if MFS_FlushGunPos then
        MFS_FlushGunPos(self.currentPrimaryItem, "inspect-close")
    end
    self:setVisible(false)
    if riskyTradeWindow then
        riskyTradeWindow:close()
    end
    -- AWCWF_Attach.Apply_Effect(getPlayer(), self.currentPrimaryItem)
    getPlayer():clearVariable("IsInspectOneHandedRanged")
    getPlayer():clearVariable("IsInspectTwoHandedRanged")
    if ItemPreviewUI and ItemPreviewUI.instance then
        ItemPreviewUI.instance:destroy()
        ItemPreviewUI.instance = nil
    end
end
function riskyUI:new(x, y, width, height)
    local o = {}
    o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.panelWidth = 0
    o.backgroundColor.a = 1;
    o.panelHeight = 0
    o.currentPrimaryItem = getPlayer():getPrimaryHandItem()
    o.itemWeight = getPlayer():getInventory():getCapacityWeight()
    o.itemCap = getPlayer():getInventory():getItems():size()
    o.weaponCondition = (getPlayer():getPrimaryHandItem():getCondition() * 100) /
                            getPlayer():getPrimaryHandItem():getConditionMax()
    o.moveWithMouse = true
    local weapon = getPlayer():getPrimaryHandItem()
    if (weapon:IsWeapon() and weapon:isRanged()) then
        if (weapon:isTwoHandWeapon()) then
            print("Two Handed Ranged")
            getPlayer():setVariable("IsInspectTwoHandedRanged", "true")
        else
            print("One Handed Ranged")
            getPlayer():setVariable("IsInspectOneHandedRanged", "true")
        end
    end
    return o
end
function riskyUI:update()
    if self and self:getIsVisible() then
        if (self.currentPrimaryItem ~= getPlayer():getPrimaryHandItem()) then
            self:close()
        end
        if self.itemCap ~= getPlayer():getInventory():getItems():size() or self.itemWeight ~=
            getPlayer():getInventory():getCapacityWeight() or self.weaponCondition ~=
            (getPlayer():getPrimaryHandItem():getCondition() * 100) / getPlayer():getPrimaryHandItem():getConditionMax() then
            self.itemCap = getPlayer():getInventory():getItems():size()
            self.itemWeight = getPlayer():getInventory():getCapacityWeight()
            self.weaponCondition = (getPlayer():getPrimaryHandItem():getCondition() * 100) /
                                       getPlayer():getPrimaryHandItem():getConditionMax()
            self:renderInventory()
        end
    end
end

local function drawAttachment(self, weapon, type, x, y)
    local attachment = weapon:getWeaponPart(type);
    local displayName = getText('IGUI_NONE')
    if attachment ~= nil then
        displayName = attachment:getDisplayName();
    end
    self:drawText(displayName, x, y, 1, 1, 1, 1, UIFont.Small);
    self:drawText(getText('IGUI_' .. type), x, y + 20, 1, 1, 1, 1, UIFont.Small);
end

local partlist = AWCWF_AdditionalParts.partlist

local function getAttacheMentCount(weapon)
    local ReturnList = {
        WeightModifier = 0,
        SpreadModifier = 0,
        Angle = 0,
        Damage = 0,
        ReloadTime = 0,
        LowLightBonus = 0,
        HitChance = 0,
        MinRangeRanged = 0,
        AimingTime = 0,
        MinSightRange = 0,
        MaxRange = 0,
        RecoilDelay = 0,
        RecoilDelayModifier = 0,
        MaxSightRange = 0,
        SoundModifier = 0,
        CriticalChance = 0,
        CritDmgMultiplier = 0,
        CyclicRateMultiplier = 0
    }
    for i, v in ipairs(partlist) do
        if weapon:getWeaponPart(v) and v ~= "Clip" then
            local item = weapon:getWeaponPart(v)
            if item then
                if item:getWeightModifier() then
                    ReturnList["WeightModifier"] = ReturnList["WeightModifier"] + item:getWeightModifier()
                end
                if item:getSpreadModifier() then
                    ReturnList["SpreadModifier"] = ReturnList["SpreadModifier"] + item:getSpreadModifier()
                end
                if item:getAngle() then
                    ReturnList["Angle"] = ReturnList["Angle"] + item:getAngle()
                end
                if item:getDamage() then
                    ReturnList["Damage"] = ReturnList["Damage"] + item:getDamage()
                    if ReturnList["Damage"] >= 10 then  -- avoid overflow value
                        ReturnList["Damage"] = 10
                    end
                end
                if item:getReloadTime() then
                    ReturnList["ReloadTime"] = ReturnList["ReloadTime"] + item:getReloadTime()
                end
                if item:getLowLightBonus() then
                    ReturnList["LowLightBonus"] = ReturnList["LowLightBonus"] + item:getLowLightBonus()
                end
                if item:getHitChance() then
                    ReturnList["HitChance"] = ReturnList["HitChance"] + item:getHitChance()
                end
                if item:getMinRangeRanged() then
                    ReturnList["MinRangeRanged"] = ReturnList["MinRangeRanged"] + item:getMinRangeRanged()
                end
                if item:getAimingTime() then
                    ReturnList["AimingTime"] = ReturnList["AimingTime"] + item:getAimingTime()
                    if ReturnList["AimingTime"] > 49 then  -- avoid overflow value
                        ReturnList["AimingTime"] = 50
                    end
                end
                if item:getMinSightRange() then
                    ReturnList["MinSightRange"] = ReturnList["MinSightRange"] + item:getMinSightRange()
                end
                if item:getMaxRange() then
                    ReturnList["MaxRange"] = ReturnList["MaxRange"] + item:getMaxRange()
                    if ReturnList["MaxRange"] >= 100 then 
                        ReturnList["MaxRange"] = 100
                    end
                end
                if item:getRecoilDelay() then
                    ReturnList["RecoilDelay"] = ReturnList["RecoilDelay"] + item:getRecoilDelay()
                    if ReturnList["RecoilDelay"] <= 0 then  -- avoid negative value
                        ReturnList["RecoilDelay"] = 0
                    end
                end
                -- RecoilDelayModifier is the raw (signed) part recoil-delay bonus;
                -- keep negatives so the UI can show "less recoil" as an improvement.
                if item:getRecoilDelay() then
                    ReturnList["RecoilDelayModifier"] = ReturnList["RecoilDelayModifier"] + item:getRecoilDelay()
                end
                if item:getMaxSightRange() then
                    ReturnList["MaxSightRange"] = ReturnList["MaxSightRange"] + item:getMaxSightRange()
                end
                if AWCWF_GetPartStatBonus then
                    local statBonus = AWCWF_GetPartStatBonus(item)
                    if statBonus then
                        ReturnList["CriticalChance"] = ReturnList["CriticalChance"] + (statBonus.CriticalChance or 0)
                        ReturnList["CritDmgMultiplier"] = ReturnList["CritDmgMultiplier"] + (statBonus.CritDmgMultiplier or 0)
                        ReturnList["CyclicRateMultiplier"] = ReturnList["CyclicRateMultiplier"] + (statBonus.CyclicRateMultiplier or 0)
                    end
                end
            end
            if item:getPartType() == "Canon" then
                if (string.find(item:getDisplayName(), getText("IGUI_Slience")) or
                    string.find(item:getType(), "Silencer") or string.find(item:getType(), "silencer")) then
                    ReturnList["SoundModifier"] = ReturnList["SoundModifier"] - 40
                end
            end
        end
    end
    return ReturnList
end

local function formatStatNumber(value)
    if value == nil then return "--" end
    if math.abs(value - math.floor(value + 0.5)) < 0.0001 then
        return tostring(math.floor(value + 0.5))
    end
    return string.format("%.2f", value)
end

local function getCurrentStatDisplay(weapon, statName, attachMentCount)
    if statName == "IGUI_WeaponUI_DamegeMax" then return formatStatNumber(weapon:getMaxDamage()) end
    if statName == "IGUI_WeaponUI_DamegeMin" then return formatStatNumber(weapon:getMinDamage()) end
    if statName == "IGUI_WeaponUI_RangeMax" then return formatStatNumber(weapon:getMaxRange()) end
    if statName == "IGUI_WeaponUI_DoorDamage" then return formatStatNumber(weapon:getDoorDamage()) end
    if statName == "IGUI_WeaponUI_AngleMax" then return formatStatNumber(weapon:getMaxAngle()) end
    if statName == "IGUI_WeaponUI_AngleMin" then return formatStatNumber(weapon:getMinAngle()) end
    if statName == "IGUI_WeaponUI_CriticalChance" then return formatStatNumber(weapon:getCriticalChance()) .. "%" end
    if statName == "IGUI_WeaponUI_CritDmg" then return formatStatNumber(weapon:getCriticalDamageMultiplier()) .. "x" end
    if statName == "IGUI_WeaponUI_CyclicRate" then return formatStatNumber(weapon:getCyclicRateMultiplier()) .. "x" end
    if statName == "IGUI_WeaponUI_AimingTime" then return formatStatNumber(weapon:getAimingTime()) end
    if statName == "IGUI_WeaponUI_ReloadTime" then return formatStatNumber(weapon:getReloadTime()) end
    if statName == "IGUI_WeaponUI_FireRate" then
        local rpm = AWCWF_GetDisplayRPM and AWCWF_GetDisplayRPM(weapon) or
            (AWCWF_GetConfiguredRPM and AWCWF_GetConfiguredRPM(weapon) or nil)
        return rpm and (formatStatNumber(rpm) .. " RPM") or "--"
    end
    if statName == "IGUI_WeaponUI_MaxHitCount" then return formatStatNumber(weapon:getMaxHitCount()) end
    if statName == "IGUI_WeaponUI_Sound" then return formatStatNumber(weapon:getSoundRadius()) end
    if statName == "IGUI_WeaponUI_Weight" then return formatStatNumber(weapon:getWeight()) end
    if statName == "IGUI_WeaponUI_ClipNow" then return formatStatNumber(weapon:getMaxAmmo()) end
    if statName == "IGUI_WeaponUI_RecoilDelayModifier" then
        -- weapon:getRecoilDelay() already includes attached parts' RecoilDelayModifier
        -- (EFK_AdditionalParts bakes it in on attach/detach), so this is the effective value.
        return formatStatNumber(weapon:getRecoilDelay())
    end
    return "--"
end

function riskyUI:prerender()
    ISPanel.prerender(self)
    local BackGroundPanelTexture = getTexture("media/textures/UI/EFK_BackGround.png")
    self:drawTextureScaled(BackGroundPanelTexture, 0, 0, self.width, self.height, 1, 0.5, 0.5, 0.5)
    if getPlayer():getPrimaryHandItem() ~= nil and getPlayer():getPrimaryHandItem():IsWeapon() then
        local weapon = getPlayer():getPrimaryHandItem()
        local conditionPerc = (weapon:getCondition() * 100) / weapon:getConditionMax()
        self:drawTextureScaled(weapon:getTexture(), 40, 35, 64, 64, 1, 1, 1, 1)
        local weaponrate = weapon:getCondition() / weapon:getConditionMax()
        local dely = (1 - weaponrate) * 64
        local adely = weaponrate * 64
        local colorr = 1 - weaponrate
        local colorg = weaponrate
        self:drawRectStatic(40, 35 + dely, 64, adely, 0.1, colorr, colorg, 0);
        self:drawRectBorder(40, 35, 64, 64, 0.3, 1, 1, 1)
        local conditionText = tostring(math.floor(conditionPerc)) .. "%"

        self:drawText(conditionText, 75 + 32, 55, 1, 1, 1, 1, UIFont.Small)
        local repairText = ""

        self:drawText(weapon:getDisplayName(), 75 + 32, 35, 1, 1, 1, 1, UIFont.Small)
        self:drawText(repairText, 75 + 32, 70, 1, 1, 1, 1, UIFont.Small)
        if weapon:isRanged() then
            local OriginItem = instanceItem(weapon:getFullType())
            local WeaponDataList = {{
                Name = "IGUI_WeaponUI_DamegeMax",
                Value = OriginItem:getMaxDamage(),
                BonusType = "Damage",
                BounsAdd = true,
                MaxValue = 7,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_RangeMax",
                Value = OriginItem:getMaxRange(),
                BonusType = "MaxRange",
                BounsAdd = true,
                MaxValue = 500,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_DoorDamage",
                Value = OriginItem:getDoorDamage(),
                MaxValue = 100,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_CriticalChance",
                Value = OriginItem:getCriticalChance(),
                BonusType = "CriticalChance",
                BounsAdd = true,
                MaxValue = 100,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_CritDmg",
                Value = OriginItem:getCriticalDamageMultiplier(),
                BonusType = "CritDmgMultiplier",
                BounsAdd = true,
                MaxValue = 25,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_AimingTime",
                Value = OriginItem:getAimingTime(),
                BonusType = "AimingTime",
                BounsAdd = false,
                MaxValue = 100,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_ReloadTime",
                Value = OriginItem:getReloadTime(),
                BounsAdd = false,
                BonusType = "ReloadTime",
                MaxValue = 200,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_FireRate",
                Value = OriginItem:getRecoilDelay(),
                BounsAdd = false,
                BonusType = "RecoilDelay",
                MaxValue = 100, --msr rifle max 90
                MinValue = 0,
                IsReversed = true -- 反过来显示 越小越长
            }, {
                Name = "IGUI_WeaponUI_RecoilDelayModifier",
                Value = OriginItem:getRecoilDelay(),
                BounsAdd = false,
                BonusType = "RecoilDelayModifier",
                MaxValue = 100,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_MaxHitCount",
                Value = OriginItem:getMaxHitCount(),
                MaxValue = 7,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_Sound",
                Value = weapon:getSoundRadius(),
                MaxValue = 200,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_Weight",
                Value = OriginItem:getWeight(),
                BounsAdd = false,
                BonusType = "WeightModifier",
                MaxValue = 10,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_ClipNow",
                Value = OriginItem:getMaxAmmo(),
                MaxValue = 100,
                MinValue = 0
            }}
            local indeX = 1000
            local indexY = 85
            self:drawText(getText("IGUI_WeaponUI_Data"), indeX + 60, indexY + 15, 1, 1, 0, 1, UIFont.Medium)
            local lineHeight = getTextManager():MeasureStringY(UIFont.Medium, getText(''))
            self:drawRectStatic(indeX + 5, indexY, 200 + 25, lineHeight * 2, 0.0, 0.8, 0.8, 0.8, 1);
            indexY = indexY + lineHeight
            -- 获得配件加成
            local AttachMentCount = getAttacheMentCount(weapon)

            for k, v in pairs(WeaponDataList) do
                local text = getText(v.Name)

                lineHeight = getTextManager():MeasureStringY(UIFont.Medium, getText(''))
                if k % 2 == 1 then
                    -- indeX + 5
                    self:drawRectStatic(indeX + 5, indexY + (k * lineHeight), 200 + 25, lineHeight +2, 0.0, 1, 1, 1, 1);
                else
                    self:drawRectStatic(indeX + 5, indexY + (k * lineHeight), 200 + 25, lineHeight +2, 0.0, 0.8, 0.8, 0.8, 1);
                end
                -- indeX + 20
                self:drawText(text, indeX + 8, indexY + (k * lineHeight) +4 , 0.6, 1, 1, 1, UIFont.Small)

                local value = v.Value
                local maxValue = v.MaxValue
                local minValue = v.MinValue
                local valuePerc = (value - minValue) / (maxValue - minValue)
                if v.IsReversed then
                    valuePerc = 1 - valuePerc
                end
                local LastWidth = 100 * valuePerc
                self:drawRectStatic(indeX + 15 + 100, indexY + (k * lineHeight) + lineHeight / 2 - 8, LastWidth, 15, 0.5, 1, 1, 0, 1);

                if v.BonusType and AttachMentCount[v.BonusType] then
                    local bouns = AttachMentCount[v.BonusType]
                    valuePerc = (bouns - minValue) / (maxValue - minValue)
                    if v.BounsAdd then
                        -- 大于0显示绿色，小于0显示红色
                        if bouns > 0 then

                            self:drawRectStatic(indeX + 15 + 100 + LastWidth,
                                indexY + (k * lineHeight) + lineHeight / 2 - 8, 100 * valuePerc, 15, 0.8, 0, 1, 0, 1);
                        else
                            self:drawRectStatic(indeX + 15 + 100 + LastWidth,
                                indexY + (k * lineHeight) + lineHeight / 2 - 8, 100 * valuePerc, 15, 0.8, 1, 0, 0, 1);
                        end
                    else
                        if bouns > 0 then
                            self:drawRectStatic(indeX + 15 + 100 + LastWidth,
                                indexY + (k * lineHeight) + lineHeight / 2 - 8, 100 * valuePerc, 15, 0.8, 1, 0, 0, 1);
                        else

                            self:drawRectStatic(indeX + 15 + 100 + LastWidth,
                                indexY + (k * lineHeight) + lineHeight / 2 - 8, 100 * valuePerc, 15, 0.8, 0, 1, 0, 1);
                        end
                    end
                end

                -- Numeric values use the current weapon instance, so installed parts are reflected.
                -- Fire rate shows the calibrated category RPM expected in gameplay.
                local numericText = getCurrentStatDisplay(weapon, v.Name, AttachMentCount)
                self:drawTextRight(numericText, indeX + 222, indexY + (k * lineHeight) + 4,
                    1, 1, 1, 1, UIFont.Small)
            end
            self:drawText(getText(''), 20 + 475, 50, 1, 1, 1, 1, UIFont.Small)

            if weapon:getMagazineType() ~= nil then
                local MagazineItem = instanceItem(weapon:getMagazineType());
                if MagazineItem ~= nil then
                    local clip = MagazineItem:getDisplayName()
                    self:drawText(clip, 472 + 200, 416 + 144, 1, 1, 1, 1, UIFont.Small)
                    self:drawText(getText('IGUI_CLIP'), 472 + 200, 436 + 144, 1, 1, 1, 1, UIFont.Small)
                    -- Current ammo / magazine capacity below the magazine-type button.
                    self:drawText(tostring(weapon:getCurrentAmmoCount()) .. " / " ..
                        tostring(weapon:getMaxAmmo()), 422 + 200, 416 + 144 + 45, 1, 1, 1, 1, UIFont.Small)
                end
            end
            if AWCWF_WeaponAttackType[weapon:getType()] then
                local AttackType = getWeaponAttackType(weapon, AWCWF_WeaponAttackType[weapon:getType()])
                local AttackTypeItem = instanceItem(AttackType);
                if AttackTypeItem then
                    AttackType = AttackTypeItem:getDisplayName()
                    self:drawText(AttackType, 608, 100, 1, 1, 1, 1, UIFont.Small)
                    self:drawText(getText('IGUI_WeaponAttackType'), 608, 120, 1, 1, 1, 1, UIFont.Small)
                end
            end
            for _, info in ipairs(attachmentInfo) do
                drawAttachment(self, weapon, info.type, info.x, info.y);
            end

        end
    else
        self:close()
    end
    if self.scene then
        self.scene:setY(self.height / 12)
        self.scene:setX(0)
        self.scene:setWidth(self.width)
        self.scene:setHeight(self.height * 10 / 12)
        -- Keep the wrench immediately to the right of the ammunition controls.
        if self.settingbutton then
            self.settingbutton:setX(65)
            self.settingbutton:setY(590)
            self.settingbutton:setWidth(34)
            self.settingbutton:setHeight(34)
        end
        if self.closebutton then
            self.closebutton:setX(self.width - 28)
            self.closebutton:setY(6)
        end
    end
end
-- MFS community fix: guard world-model strings before handing them to UI3DScene.
-- getpartmodeldel already rejected "nil"/"null"/Gun_Magazine_Ground, but getpartmodel
-- only rejected "nil". A part resolving to e.g. "Gunpart.null" therefore reached
-- createModel and threw NullPointerException: model script not found -- and was still
-- written into scene.partlist, so the next cleanup pass threw a second NPE from
-- removeModel. Reject known-bad strings, and let anything else fail quietly via pcall
-- so a bad value from another mod's part can never poison scene.partlist.
local reportedBadWorldModels = {}

local function isUsableWorldModel(worldmodel)
    if not worldmodel or worldmodel == "" then return false end
    if string.find(worldmodel, "nil") then return false end
    if string.find(worldmodel, "null") then return false end
    if worldmodel == "Base.Gun_Magazine_Ground" then return false end
    return true
end

local function reportBadWorldModel(slot, fullType, worldmodel, reason)
    local key = tostring(fullType) .. "|" .. tostring(worldmodel)
    if reportedBadWorldModels[key] then return end
    reportedBadWorldModels[key] = true
    print("[MFSInspect] skipped part slot=" .. tostring(slot)
        .. " item=" .. tostring(fullType)
        .. " worldModel=" .. tostring(worldmodel)
        .. " reason=" .. tostring(reason))
end

local function getpartmodel(weapon, scene)
    for i, v in pairs(partlist) do
        local part = weapon:getWeaponPart(v)
        if part then
            local item = ScriptManager.instance:getItem(part:getFullType())
            if item then
                local worldmodel = item:getWorldStaticModel()
                scene.partlist = scene.partlist or {}
                if not isUsableWorldModel(worldmodel) then
                    reportBadWorldModel(v, part:getFullType(), worldmodel, "invalid-world-model")
                elseif not scene.partlist[worldmodel] then
                    local ok, err = pcall(function()
                        scene.javaObject:fromLua2("createModel", worldmodel, worldmodel)
                    end)
                    if ok then
                        scene.partlist[worldmodel] = true
                    else
                        reportBadWorldModel(v, part:getFullType(), worldmodel, tostring(err))
                    end
                end
            end
        end
    end
end
local function getpartmodeldel(weapon, scene)
    local partlistnow = {}
    scene.partlist = scene.partlist or {}
    for i, v in pairs(partlist) do
        if weapon:getWeaponPart(v) then
            local item = ScriptManager.instance:getItem(weapon:getWeaponPart(v):getFullType())
            if item then
                local worldmodel = item:getWorldStaticModel()
                -- scene.javaObject:fromLua1("removeModel", worldmodel, worldmodel)

                if not isUsableWorldModel(worldmodel) then
                    reportBadWorldModel(v, weapon:getWeaponPart(v):getFullType(), worldmodel,
                        "invalid-world-model")
                else
                    if not scene.partlist[worldmodel] then
                        local ok, err = pcall(function()
                            scene.javaObject:fromLua2("createModel", worldmodel, worldmodel)
                        end)
                        if ok then
                            scene.partlist[worldmodel] = true
                            partlistnow[worldmodel] = true
                        else
                            reportBadWorldModel(v, weapon:getWeaponPart(v):getFullType(), worldmodel,
                                tostring(err))
                        end
                    else
                        partlistnow[worldmodel] = true
                    end
                end
            end
        end
    end
    scene.partlist = scene.partlist or {}
    for i, v in pairs(scene.partlist) do
        if not partlistnow[i] then
            scene.partlist[i] = nil
            -- pcall: a scene object that was never successfully created would otherwise
            -- throw NullPointerException from UI3DScene.getSceneObjectById.
            local ok, err = pcall(function()
                scene.javaObject:fromLua1("removeModel", i)
            end)
            if not ok then
                reportBadWorldModel("cleanup", "n/a", i, tostring(err))
            end
        end
    end
end
function riskyUI:openSettingPanel()
    if riskyUI_slider and riskyUI_slider.instance then
        riskyUI_slider.instance:close()
        riskyUI_slider.instance = nil
    end
    local width = self.width / 3
    self.settingpanel = riskyUI_slider:new(self.x - width, self.y, width, self.height, self)
    self.settingpanel:initialise()
    riskyUI_slider.instance = self.settingpanel
    self.settingpanel:addToUIManager()
end
function riskyUI:reopenSettingPanel()
    if riskyUI_slider and riskyUI_slider.instance then
        riskyUI_slider.instance:close()
        riskyUI_slider.instance = nil
    end
    local width = self.width / 3
    self.settingpanel = riskyUI_slider:new(self.x - width, self.y, width, self.height, self)
    self.settingpanel:initialise()
    riskyUI_slider.instance = self.settingpanel
    self.settingpanel:addToUIManager()
end
function riskyUI:createChildren()
    ISPanel.createChildren(self)
    self.scene = Carshopscenetk:new(self.width / 10, self.height / 8, self.width * 8 / 10, self.height * 6 / 8)
    self.scene:initialise()
    self.scene:instantiate()
    self.scene:setAnchorRight(true)
    self.scene:setAnchorBottom(true)
    self:addChild(self.scene)

    self.scene.javaObject:fromLua1("setDrawGrid", false)
    self.scene.javaObject:fromLua1("setDrawGridAxes", false)

    self.scene.javaObject:fromLua1("setMaxZoom", 100)
    self.scene.javaObject:fromLua1("setZoom", 15)
    self.scene.javaObject:fromLua2("dragView", -30, 30)
    -- self.scene:java7("createDepthTexture", "depthTexture", getTexture("media/white.png"), 0, 0, 64, 128, 0.0)
    -- self.scene:java2("setObjectVisible", "depthTexture", false)
    self.scene:setView("UserDefined")
    local weapon = getPlayer():getPrimaryHandItem()
    self.gunmodelCreated = false
    local sprite = weapon and weapon:getWeaponSprite() or nil
    if sprite and sprite ~= "nil" and not string.find(sprite, "_0") then
        local inspectionSprite = (AWCWF_InspectionModelMap and AWCWF_InspectionModelMap[sprite]) or sprite
        local model = ScriptManager.instance:getItem(weapon:getFullType()):getModuleName() .. "." .. inspectionSprite
        -- pcall: an unresolvable model string would otherwise throw NullPointerException
        -- ("model script not found") from UI3DScene.createModel. Remember success so
        -- renderInventory never queries a "Gunmodel" that was never created.
        self.gunmodelCreated = pcall(function()
            self.scene.javaObject:fromLua2("createModel", "Gunmodel", model)
        end)
    end
    getpartmodel(weapon, self.scene)
    self.settingbutton = ISButton:new(1000 + 10, 585, 75, 75, "", self, self.openSettingPanel);
    self.settingbutton.anchorTop = false
    self.settingbutton.anchorBottom = false
    self.settingbutton:initialise();
    self.settingbutton:instantiate();
    self.settingbutton.borderColor = {
        r = 1,
        g = 1,
        b = 1,
        a = 0
    };
    self:addChild(self.settingbutton);
    local itemseed = ScriptManager.instance:getItem("Base.Wrench") or ScriptManager.instance:getItem("Wrench")
    local icon = itemseed and itemseed:getIcon()
    local itemtexture = icon and getTexture("media/textures/Item_" .. icon .. ".png")
    if itemtexture then self.settingbutton:setImage(itemtexture) end

    -- Vanilla-style close button (same "X" icon as the base game UI).
    self.closebutton = ISButton:new(self.width - 30, 10, 22, 22, "", self, self.onOptionMouseDown)
    self.closebutton.internal = "close"
    self.closebutton:initialise()
    self.closebutton:instantiate()
    self.closebutton.borderColor = { r = 1, g = 1, b = 1, a = 0 }
    self.closebutton:setImage(getTexture("media/textures/UI/EFK_Close.png"))
    self:addChild(self.closebutton)
end

function riskyUI:renderInventory()

    -- clearChildren() detaches the ammo/repair buttons from the panel but does
    -- NOT remove the ISToolTipInv each button added to the global UI manager
    -- (a separate top-level element). Remove those tooltips explicitly or they
    -- accumulate on every redraw and gradually stall the game.
    for _, child in ipairs(self:getChildrenInOrder() or {}) do
        if child and child.toolTip then
            child.toolTip:setVisible(false)
            child.toolTip:removeFromUIManager()
            child.toolTip = nil
        end
    end

    self:clearChildren()
    if self.settingpanel then
        self.settingpanel:close()
        self.settingpanel = nil
        self:reopenSettingPanel()
    end
    -----------------------------------------------------------
    -- self.scene = nil
    local weapon = getPlayer():getPrimaryHandItem()
    if not self.scene then
        self:createChildren()
    else
        self:addChild(self.scene)
        getpartmodeldel(weapon, self.scene)
        if self.settingbutton then self:addChild(self.settingbutton) end
        if self.closebutton then self:addChild(self.closebutton) end
    end
    if weapon:getSwingAnim() == "Handgun" and not AWCWF_WeaponSkin[weapon:getType()] then
        if self.gunmodelCreated then
            local ok, vector = pcall(function()
                return self.scene.javaObject:fromLua1("getObjectRotation", "Gunmodel")
            end)
            if ok and vector then
                vector:set(vector:x(), 180, vector:z())
            end
        end
    elseif weapon:getSwingAnim() == "Handgun" and AWCWF_WeaponSkin[weapon:getType()] then
        if weapon:getWeaponPart("Skin") then
            local item = ScriptManager.instance:getItem(weapon:getWeaponPart("Skin"):getFullType())
            if item then
                local worldmodel = item:getWorldStaticModel()
                if isUsableWorldModel(worldmodel) then
                    local ok, vector = pcall(function()
                        return self.scene.javaObject:fromLua1("getObjectRotation", worldmodel)
                    end)
                    if ok and vector then
                        vector:set(vector:x(), 180, vector:z())
                    end
                end
            end
        end
    end
    for uy, ur in pairs(partlist) do
        if weapon:getWeaponPart(ur) then
            local item = ScriptManager.instance:getItem(weapon:getWeaponPart(ur):getFullType())
            if item then
                local worldmodel = item:getWorldStaticModel()
                local modelscript = "Base." .. weapon:getWeaponSprite()
                local model = ScriptManager.instance:getModelScript(modelscript)
                if model and worldmodel then
                    local attachment0 = model:getAttachmentById(ur)
                    if attachment0 and not string.find(worldmodel, "nil") and worldmodel ~= "Base.Gun_Magazine_Ground" then
                        local offset = attachment0:getOffset()
                        local list = {offset:x(), offset:y(), offset:z()}

                        -- RC2-1 follow-up: GunPos stores inspection-scene coordinates.
                        -- For handguns the held-model attachment uses the opposite Z sign,
                        -- so rebuilding the scene from attachment0 inverted the preview each
                        -- time the UI reopened. Prefer the raw saved position when available;
                        -- retain the model-script offset as the fallback for untouched parts.
                        local part = weapon:getWeaponPart(ur)
                        local gunPos = weapon:getModData().GunPos
                        local saved = part and type(gunPos) == "table" and gunPos[part:getFullType()] or nil
                        if type(saved) == "table" and type(saved.x) == "number"
                            and type(saved.y) == "number" and type(saved.z) == "number" then
                            list[1] = saved.x
                            list[2] = saved.y
                            list[3] = saved.z
                        end
                        local vector = self.scene.javaObject:fromLua4("setObjectPosition", worldmodel, list[1], list[2],
                            list[3])
                    end
                end
            end
        end
    end
    for oi, op in pairs(AWCWF_WeaponSkin) do
        if weapon:getType() == oi then
            weapon:setWeaponSprite(oi .. "_0")
        end
    end
    if getPlayer():getPrimaryHandItem() ~= nil and getPlayer():getPrimaryHandItem():IsWeapon() then

        if (weapon:isRanged()) then
            -- Width/Height
            self.panelHeight = 110
            self:setHeight(self.panelHeight)
            local itemList = getPlayer():getInventory():getItems()
            local containerCount = 1
            local allContainers = {}
            -- Probe containers
            for i = 0, itemList:size() - 1, 1 do
                if instanceof(itemList:get(i), 'InventoryContainer') and (itemList:get(i):isEquipped()) then
                    table.insert(allContainers, itemList:get(i))
                    containerCount = containerCount + 1
                end
            end
            -- Not an ideal way to get the object loose ammo and box ammo object, but for the time being...
            local looseAmmo = instanceItem(weapon:getAmmoType():getItemKey())
            local boxAmmo = instanceItem(weapon:getAmmoBox())
            -- local looseAmmoCount = getPlayer():getInventory():getItemCount(weapon:getAmmoType())

            local looseAmmoCount = 0
            if weapon:getAmmoType() then
                local itemKey = weapon:getAmmoType():getItemKey();
                looseAmmoCount = getPlayer():getInventory():getItemCountRecurse(itemKey);
                
            end
            local boxAmmoCount = getPlayer():getInventory():getItemCount(weapon:getAmmoBox())
            if (containerCount > 1) then
                for i = 1, containerCount - 1 do
                    looseAmmoCount = looseAmmoCount + allContainers[i]:getInventory():getItemCount(weapon:getAmmoType():getItemKey())
                    boxAmmoCount = boxAmmoCount + allContainers[i]:getInventory():getItemCount(weapon:getAmmoBox())
                end
            end
            -- Repair kit button: to the left of the loose ammo. Shows how many
            -- Base.gongjvxiuli_cat are in the main backpack; clicking repairs the
            -- held gun to full condition and consumes one.
            local repairKitBtn = repairKitButton:new(1000 + 10 - 80, 585, 75, 75,
                instanceItem("Base.gongjvxiuli_cat"), weapon)
            repairKitBtn:bringToTop()
            self:addChild(repairKitBtn)
            local looseType = looseAmmo and looseAmmo:getFullType() or nil
            local boxType = boxAmmo and boxAmmo:getFullType() or nil
            local item = ammoButton:new(1000 + 10, 585, 75, 75, looseAmmo, looseAmmoCount, "loose", looseType, boxType)
            item:bringToTop()
            self:addChild(item)
            item = ammoButton:new(1000 + 90, 585, 75, 75, boxAmmo, boxAmmoCount, "box", looseType, boxType)
            item:bringToTop()
            self:addChild(item)
            -- Trade button (walkie-talkie icon) to the right of the boxed ammo.
            -- Greyed out without a radio; opens the trade UI when clicked.
            item = tradeButton:new(1000 + 170, 585, 75, 75, function()
                riskyTradeUI.open(self)
            end)
            item:bringToTop()
            self:addChild(item)
            self.panelWidth = self.panelWidth + 130
            self.panelHeight = self.panelHeight + 180

            if weapon:getMagazineType() ~= nil then
                local MagazineItem = instanceItem(weapon:getMagazineType());
                if MagazineItem then
                    item = attachmentButton:new(422 + 200, 416 + 144, 40, 40, MagazineItem, weapon, "ClipType")
                    item:bringToTop()
                    self:addChild(item)
                end
            end
            if AWCWF_WeaponAttackType[weapon:getType()] then
                local AttackType = getWeaponAttackType(weapon, AWCWF_WeaponAttackType[weapon:getType()])
                local AttackTypeItem = instanceItem(AttackType);
                if AttackTypeItem then
                    item = attachmentButton:new(558, 100, 40, 40, AttackTypeItem, weapon, "WeaponAttackType")
                    item:bringToTop()
                    self:addChild(item)
                end
            end

            for _, info in ipairs(attachmentButtonsInfo) do
                local attachmentItem = weapon:getWeaponPart(info.type)
                local item = attachmentButton:new(info.x, info.y, 40, 40, attachmentItem, weapon, info.type);
                item:bringToTop();
                self:addChild(item);
            end
        end
    end
    self:setWidth(698 + 300 + 300)
    self:setHeight(516 + 200)
end


riskyUI.inspectOnKey = function(_keyPressed)
    if _keyPressed == getCore():getKey("OpenWindownCat") then
        local weapon = getPlayer():getPrimaryHandItem()
        if (weapon ~= nil and weapon:IsWeapon()) then
            if riskyInspectWindow == nil or not riskyInspectWindow:getIsVisible() then
                riskyInspectWindow = riskyUI:new(getPlayer():getModData().inspectWindowPos[1],
                    getPlayer():getModData().inspectWindowPos[2], 0, 0)
                riskyInspectWindow:addToUIManager()
                riskyInspectWindow.resizable = false
                riskyInspectWindow.collapsable = false
                riskyInspectWindow:renderInventory()
            else
                riskyInspectWindow:close()
                riskyInspectWindow = nil
            end
        end
    end
end

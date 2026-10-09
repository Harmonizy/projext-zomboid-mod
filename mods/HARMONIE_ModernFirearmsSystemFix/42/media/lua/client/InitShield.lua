ShieldFunction = ShieldFunction or {}
ShieldFunction.ShieldItem = {}

ShieldFunction.ShieldItem["Base.ArmorShieldHand"] = "HandShield"
ShieldFunction.ShieldItem["Base.ArmorShieldBody"] = "BodyShield"

local Localtiongroup = AttachedLocations.getGroup("Human")
local isfemale = "MaleBody"
local lastBoneandtype = nil
function ShieldFunction.updateShield(ShieldItem, AttachetName, boneandtype, posTable, rotateTable)
    local player = getPlayer()
    if player:isFemale() then
        isfemale = "FemaleBody"
    else
        isfemale = "MaleBody"
    end

    local location = Localtiongroup:getOrCreateLocation(AttachetName)
    local model = ScriptManager.instance:getModelScript(isfemale)
    local modelattchment = nil
    if not model:getAttachmentById(AttachetName) then
        modelattchment = ModelAttachment.new(AttachetName)
    else
        modelattchment = model:getAttachmentById(AttachetName)
    end
    local rotate = modelattchment:getRotate()
    local offset = modelattchment:getOffset()
    offset:set(posTable.x / 100, posTable.y / 100, posTable.z / 100)
    rotate:set(rotateTable.x, rotateTable.y, rotateTable.z)
    model:addAttachment(modelattchment):setBone(boneandtype)
    location:setAttachmentName(AttachetName)
    local item = instanceItem("Base.RenderPartItem")

    item:setWeaponSprite(ShieldItem)
    player:setAttachedItem(AttachetName, item)
    if lastBoneandtype ~= AttachetName then
        if model:getAttachmentById(lastBoneandtype) then
            local AttachMentitem = player:getAttachedItem(lastBoneandtype)
            if AttachMentitem then
                AttachMentitem:setWeaponSprite(nil)
            end
        end
    end
    lastBoneandtype = AttachetName
end

function ShieldFunction.RemoveAllAttachMentSprite()
    local player = getPlayer()
    if player:isFemale() then
        isfemale = "FemaleBody"
    else
        isfemale = "MaleBody"
    end
    local model = ScriptManager.instance:getModelScript(isfemale)
    if model:getAttachmentById("ShieldPart") then
        local AttachMentitem = player:getAttachedItem("ShieldPart")
        if AttachMentitem then
            AttachMentitem:setWeaponSprite(nil)
        end
    end
end

function ShieldFunction.CheckIfShield(player)

    local Shield = player:getSecondaryHandItem()
    if Shield and ShieldFunction.ShieldItem[Shield:getFullType()] then
        return Shield, ShieldFunction.ShieldItem[Shield:getFullType()]
    end
    local pl = getPlayer()
    local wornItems = pl:getWornItems()
    if not wornItems then
        return nil, false
    end
    for i = 0, wornItems:size() - 1 do
        local wornitem = wornItems:get(i)
        local FullType = wornitem:getItem():getFullType()
        if ShieldFunction.ShieldItem[FullType] then
            return wornitem:getItem(), ShieldFunction.ShieldItem[FullType]
        end
    end
    return nil, false
end

function ShieldFunction.LocaltionSetFunction(player)
    local Shield, Type = ShieldFunction.CheckIfShield(player)
    if not Type then
        ShieldFunction.RemoveAllAttachMentSprite()
        return
    end
    if Type == "HandShield" then
        local AnimMode = "ShieldPart"
        local boneandtype = "Bip01_Prop2"
        local pos = {
            x = 0,
            y = 0,
            z = 0
        }
        local rotate = {
            x = 10,
            y = 0,
            z = 0
        }
        if player:isAiming() then
            local weapon = player:getPrimaryHandItem()
            if weapon then
                if weapon:isRanged() then
                    boneandtype = "Bip01_Prop1"
                    pos = {
                        x = -5,
                        y = 5,
                        z = 20
                    }
                    rotate = {
                        x = 0,
                        y = 180,
                        z = -60
                    }
                else
                    pos = {
                        x = -5,
                        y = 5,
                        z = 5
                    }
                    rotate = {
                        x = 0,
                        y = 0,
                        z = 0
                    }
                end

            end
        end
        ShieldFunction.updateShield(Shield:getFullType(), AnimMode, boneandtype, pos, rotate)
    end
    ShieldFunction.ShieldDef(Shield, player)
end

Events.OnPlayerUpdate.Add(ShieldFunction.LocaltionSetFunction)

local function healBodyPart(bodyPart, player, BD, ArmorTempBodyDamage)
    bodyPart:SetInfected(false);
    bodyPart:setInfectedWound(false);
    bodyPart:SetFakeInfected(false);
    bodyPart:setWoundInfectionLevel(0);
    if (ArmorTempBodyDamage["IsInfected"] == false) and (BD:IsInfected() == true) then
        BD:setInf(false); -- remove infection if did not have before the blocked scratch
        BD:setInfectionLevel(0);
        BD:setInfectionGrowthRate(0);
        BD:setFakeInfectionLevel(0);
    end
    bodyPart:RestoreToFullHealth();
end
local function ArmorSaveBodyDamage(player)
    local ArmorTempBodyDamage = {}
    local BD = player:getBodyDamage();
    ArmorTempBodyDamage["IsInfected"] = BD:IsInfected();
    local BPs = BD:getBodyParts();
    for i = 0, BPs:size() - 1 do
        ArmorTempBodyDamage[tostring(BPs:get(i):getType())] = {
            Splint = false,
            Bandage = false,
            Bite = false,
            Scratch = false,
            DeepWound = false,
            Burn = false,
            Bullet = false,
            Fracture = false,
            Glass = false
        };
        ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Splint"] = BPs:get(i):isSplint();
        ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Bandage"] = BPs:get(i):bandaged();
        ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Scratch"] = BPs:get(i):scratched();
        ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["DeepWound"] = BPs:get(i):deepWounded();
        ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Burn"] = BPs:get(i):getBurnTime();
        ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Bullet"] = BPs:get(i):haveBullet();
        ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Fracture"] = BPs:get(i):getFractureTime();
        ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Glass"] = BPs:get(i):haveGlass();
        ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Bite"] = BPs:get(i):bitten();
        ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["IsCut"] = BPs:get(i):isCut();
        ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["HasInjury"] = BPs:get(i):HasInjury();
    end
    player:getModData().ArmorTempBodyDamage = ArmorTempBodyDamage;
    player:getModData().ArmorBDamageSaved = true;

end
function ShieldFunction.ShieldDef(Shield, player)
    local ArmorbInjuryDetected = false;
    if Shield:getCondition() <= 0 then
        return
    end
    if (player:getModData().ArmorBDamageSaved ~= nil) and (player ~= nil) then
        local BD = player:getBodyDamage();
        local ArmorTempBodyDamage = player:getModData().ArmorTempBodyDamage;
        local BPs = BD:getBodyParts();
        for i = 0, BPs:size() - 1 do
            if BPs:get(i):scratched() then
                print(BPs:get(i):scratched())
            end
            if ((ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Bandage"] == false)) then
                if (ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Scratch"] ~= BPs:get(i):scratched()) and
                    (BPs:get(i):scratched() == true) then
                    healBodyPart(BPs:get(i), player, BD, ArmorTempBodyDamage);
                    ArmorbInjuryDetected = true;
                end
                if (ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["IsCut"] ~= BPs:get(i):isCut()) and
                    (BPs:get(i):isCut() == true) then
                    healBodyPart(BPs:get(i), player, BD, ArmorTempBodyDamage);
                    ArmorbInjuryDetected = true;
                end
                if (ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["DeepWound"] ~= BPs:get(i):deepWounded()) and
                    (BPs:get(i):deepWounded() == true) and
                    (ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Bullet"] ~= true) and
                    (ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Glass"] ~= true) then
                    if (ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Bullet"]) or
                        (ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Glass"]) then
                        ArmorbInjuryDetected = true;
                    else
                        healBodyPart(BPs:get(i), player, BD, ArmorTempBodyDamage);
                    end
                    ArmorbInjuryDetected = true;
                end
                if (ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Bite"] ~= BPs:get(i):bitten()) and
                    (BPs:get(i):bitten() == true) then
                    healBodyPart(BPs:get(i), player, BD, ArmorTempBodyDamage);
                    ArmorbInjuryDetected = true;
                end
                if (ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Burn"] ~= BPs:get(i):getBurnTime()) and
                    (BPs:get(i):getBurnTime() ~= 0) then
                    healBodyPart(BPs:get(i), player, BD, ArmorTempBodyDamage);
                    ArmorbInjuryDetected = true;
                end
                if (ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Bullet"] ~= BPs:get(i):haveBullet()) and
                    (BPs:get(i):haveBullet() == true) and (BPs:get(i):deepWounded() == false) then
                    healBodyPart(BPs:get(i), player, BD, ArmorTempBodyDamage);
                    ArmorbInjuryDetected = true;
                end
                if (ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Fracture"] ~= BPs:get(i):getFractureTime()) and
                    (BPs:get(i):getFractureTime() ~= 0) and (BPs:get(i):isSplint() == false) then
                    healBodyPart(BPs:get(i), player, BD, ArmorTempBodyDamage);
                    ArmorbInjuryDetected = true;
                end
                if (ArmorTempBodyDamage[tostring(BPs:get(i):getType())]["Glass"] ~= BPs:get(i):haveGlass()) and
                    (BPs:get(i):haveGlass() == true) and (BPs:get(i):deepWounded() == false) then
                    healBodyPart(BPs:get(i), player, BD, ArmorTempBodyDamage);
                    ArmorbInjuryDetected = true;
                end
            end
        end
    end
    local enemies = player:getSpottedList();
    local zombie = player:getAttackedBy()
    if zombie == nil then
        return
    end
    local Shell = player:getSecondaryHandItem()
    local playerx = player:getX()
    local playery = player:getY()
    local zombieX = zombie:getX()
    local zombieY = zombie:getY()
    local playerDir = player:getDirectionAngle()
    local zombieDir = zombie:getDirectionAngle()
    if zombie:isZombie() then
        zombie:setOutlineHighlight(true)
        zombie:setOutlineHighlightCol(0.51, 0.51, 1, 1)
        player:playSound("ShieldSoundBlocked")
        player:setAttackedBy(nil)
        player:setDeathDragDown(false)
        zombie:setKnockedDown(true);
        zombie:setHitReaction("HeadLeft");
        player:setHitReaction(nil)
        Shield:setCondition(Shield:getCondition() - getSandboxOptions():getOptionByName("ShieldCondition"):getValue())
        player:Say(getText("IGUI_ShellConditonDown") .. " " .. Shield:getCondition())
    end
    if (ArmorbInjuryDetected) then
        ArmorSaveBodyDamage(player);
    end

end

function ShieldFunction.InitModData(player)
    ArmorSaveBodyDamage(getPlayer())
end

Events.OnCreatePlayer.Add(ShieldFunction.InitModData)

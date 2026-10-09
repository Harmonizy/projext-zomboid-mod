local EnterFlag = false
local FakeEnterFlag = false
-- MFS Patch 5: getJavaFieldNum() removed - see the note in UI/risky_inspect_button.lua.
-- getNumClassFields/getClassField/getClassFieldVal are debug-only in B42.20 and
-- throw IllegalStateException("Not in debug") in a normal game, which would abort
-- every bolt-cycle animation frame. item:getWorldStaticModel() is the public
-- equivalent on the same ScriptItem object.
local function SetGunMoved(playerObj, weapon, PartFullID, PartType, offset, rotate)
    local item = ScriptManager.instance:getItem(PartFullID)
    if not item then return end
    local worldmodel = item:getWorldStaticModel()
    local modelscript = "Base." .. weapon:getWeaponSprite()
    local model = ScriptManager.instance:getModelScript(modelscript)
    if model and worldmodel then
        local attachment0 = model:getAttachmentById(PartType)
        if not attachment0 then
            attachment0 = ModelAttachment.new(PartType)
            model:addAttachment(attachment0)
        end
        if attachment0 then
            local ModData = weapon:getModData().GunPos
            if not ModData then
                ModData = {}
                weapon:getModData().GunPos = ModData
            end
            if not ModData[PartType] then
                ModData[PartType] = {}
                ModData[PartType].x = 0
                ModData[PartType].y = 0
                ModData[PartType].z = 0
            end
            EnterFlag = true
            attachment0:getOffset():set(ModData[PartType].x + offset.x, ModData[PartType].y + offset.y,
                ModData[PartType].z + offset.z)
            if rotate then
                attachment0:getRotate():set(rotate.x, rotate.y, rotate.z)
            end

            AWCWF_Attach.Apply_Effect(playerObj, weapon, true)
        end
    end
end

local function onAttack()
    local playerObj = getPlayer()
    local weapon = playerObj:getPrimaryHandItem()
    if weapon and AWCWF_WeaponWithBoltAnim[weapon:getType()] then
        local TableNow = AWCWF_WeaponWithBoltAnim[weapon:getType()]
        if TableNow.Immediately then
            for PartType, PartFullID in pairs(weapon:getModData().weaponpart) do
                if PartFullID == TableNow.TargetPart or TableNow[PartType] then
                    SetGunMoved(playerObj, weapon, PartFullID, PartType, TableNow.TargetPartOffset,
                        TableNow.TargetPartRotate)
                end
            end
        else
            FakeEnterFlag = true
        end
    end
end

Events.OnWeaponSwing.Add(onAttack)

local WaitFunctionTick = nil

local function SetWaitPostion(playerObj, TableNow, weapon)
    if not WaitFunctionTick then
        WaitFunctionTick = TableNow.WaitTick / (60 / getAverageFPS())
    end
    WaitFunctionTick = WaitFunctionTick - 1
    if WaitFunctionTick > 0 then
        return
    end
    local TableNow = AWCWF_WeaponWithBoltAnim[weapon:getType()]
    WaitFunctionTick = TableNow.WaitTick / (60 / getAverageFPS())
    for PartType, PartFullID in pairs(weapon:getModData().weaponpart) do
        if PartFullID == TableNow.TargetPart or TableNow[PartType] then
            SetGunMoved(playerObj, weapon, PartFullID, PartType, TableNow.TargetPartOffset, TableNow.TargetPartRotate)
        end
    end
    EnterFlag = true
    FakeEnterFlag = false

end
local function CheckEmpty(weapon)
    local CurrentAmmo = weapon:getCurrentAmmoCount()
    if weapon:haveChamber() and weapon:isRoundChambered() then
        return CurrentAmmo + 1 > 0
    else
        return CurrentAmmo > 0
    end
end

local WaitTick = nil
local function ReturnPostion()
    local playerObj = getPlayer()
    if not playerObj then
        return
    end
    local weapon = playerObj:getPrimaryHandItem()
    if not weapon or not AWCWF_WeaponWithBoltAnim[weapon:getType()] then
        return
    end
    local TableNow = AWCWF_WeaponWithBoltAnim[weapon:getType()]
    if FakeEnterFlag then
        SetWaitPostion(playerObj, TableNow, weapon)
        return
    end
    if not EnterFlag then
        return
    end
    if not WaitTick then
        WaitTick = TableNow.TickRemain / (60 / getAverageFPS())
    end
    WaitTick = WaitTick - 1
    if WaitTick > 0 then
        return
    end
    EnterFlag = false
    if CheckEmpty(weapon) then
        WaitTick = TableNow.TickRemain / (60 / getAverageFPS())
        for PartType, PartFullID in pairs(weapon:getModData().weaponpart) do
            if PartFullID == TableNow.TargetPart or TableNow[PartType] then
                local ModData = weapon:getModData().GunPos
                if not ModData then
                    return
                end
                if not ModData[PartType] then
                    return
                end
                SetGunMoved(playerObj, weapon, PartFullID, PartType, {
                    x = 0,
                    y = 0,
                    z = 0
                }, {
                    x = 0,
                    y = 0,
                    z = 0
                })
            end
        end
    end
end

Events.OnTick.Add(ReturnPostion)

local Old_ISRackFirearm_perform = ISRackFirearm.perform
function ISRackFirearm:perform()
    Old_ISRackFirearm_perform(self)
    if AWCWF_WeaponWithBoltAnim[self.gun:getType()] then
        EnterFlag = true
    end
end

local Old_ISRackFirearm_start = ISRackFirearm.start
function ISRackFirearm:start()
    Old_ISRackFirearm_start(self)
    if AWCWF_WeaponWithBoltAnim[self.gun:getType()] then
        local TableNow = AWCWF_WeaponWithBoltAnim[self.gun:getType()]
        WaitTick = TableNow.RackTick / (60 / getAverageFPS())
        if TableNow.Immediately then
            onAttack()
        else
            FakeEnterFlag = true
        end
    end
end


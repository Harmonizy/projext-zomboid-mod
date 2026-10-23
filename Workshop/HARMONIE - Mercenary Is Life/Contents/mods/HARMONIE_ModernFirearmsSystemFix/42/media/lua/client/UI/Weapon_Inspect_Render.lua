require('Vehicles/ISUI/ISUI3DScene')
require "UI/Weapon_Inspect_Theme"
require "Gun_Vars/Weapon_Ability/AWCWF_Gun_Shot_Profiles"
require "Gun_Vars/AWCWF_Weapon_With_Bolt_Anim"
WeaponScene = ISUI3DScene:derive("WeaponScene")

function WeaponScene:prerenderEditor()
    self.javaObject:fromLua1("setGizmoVisible", "none")
    self.javaObject:fromLua1("setGizmoOrigin", "none")
    self.javaObject:fromLua1("setTransformMode", "Global")
    self.javaObject:fromLua0("clearGizmoRotate")
    self.javaObject:fromLua0("clearAABBs")
    self.javaObject:fromLua0("clearAxes")
    self.javaObject:fromLua0("clearBox3Ds")
end
function WeaponScene:prerender()
    ISUI3DScene.prerender(self)
end

function WeaponScene:onMouseDown()
    -- Future restore point for drag rotation / gizmo editing:
    -- ISUI3DScene.onMouseDown(self, x, y)
    -- self.gizmoAxis = self.javaObject:fromLua2("testGizmoAxis", x, y)
    -- self.javaObject:fromLua3("startGizmoTracking", x, y, self.gizmoAxis)
    self.gizmoAxis = "None"
    self.onMousenow = true
    self.mouseDown = false
    self.recoilActive = true
    self.recoilFrame = 0
    self:addRecoilImpulse()
end
function WeaponScene:onMouseMove()
    -- Future restore point for drag rotation / scene dragging:
    -- ISUI3DScene.onMouseMove(self, dx, dy)
    -- self.rotationZ = self.rotationZ + dx
    -- self.rotationX = self.rotationX + dy
end
function WeaponScene:onMouseWheel()
    -- Future restore point for wheel zoom:
    -- ISUI3DScene.onMouseWheel(self, del)
    -- self.javaObject:fromLua1("zoom", del)
    return true
end

local function AWCWF_GetInspectWeapon(scene)
    if scene and scene.parent and scene.parent.currentPrimaryItem then
        return scene.parent.currentPrimaryItem
    end
    if getPlayer and getPlayer() then
        return getPlayer():getPrimaryHandItem()
    end
    return nil
end

local function AWCWF_HasInspectSuppressor(weapon)
    if not weapon or not AWCWF_SilencerSet then
        return false
    end

    for partType, silencerSet in pairs(AWCWF_SilencerSet) do
        local part = weapon:getWeaponPart(partType)
        if part and silencerSet[part:getType()] then
            return true
        end
    end

    return false
end

local function AWCWF_HasInspectShootableRound(weapon)
    if not weapon then
        return false
    end
    if weapon.getCurrentAmmoCount and weapon:getCurrentAmmoCount() and weapon:getCurrentAmmoCount() > 0 then
        return true
    end
    return weapon.isRoundChambered and weapon:isRoundChambered()
end

local function AWCWF_PlayInspectSoundLayers(emitter, layers)
    if not emitter or not layers then
        return
    end

    for _, soundName in ipairs(layers) do
        emitter:playSound(soundName)
    end
end

local function AWCWF_PlayInspectFallbackGunshot(emitter, weapon, profile)
    if not emitter then
        return
    end

    if profile and profile.fallback then
        emitter:playSound(profile.fallback)
        return
    end

    if weapon and weapon.getSwingSound and weapon:getSwingSound() and weapon:getSwingSound() ~= "nil" then
        emitter:playSound(weapon:getSwingSound())
        return
    end

    emitter:playSound("GunShot")
end

local function AWCWF_PlayInspectGunshot(scene)
    local weapon = AWCWF_GetInspectWeapon(scene)
    if not weapon or not weapon:IsWeapon() or not weapon:isRanged() then
        return
    end

    local profile = AWCWF_GunShotProfiles and AWCWF_GunShotProfiles[weapon:getType()]
    local playerObj = getPlayer and getPlayer()
    if not playerObj then
        return
    end

    local emitter = playerObj:getEmitter()
    if not profile then
        AWCWF_PlayInspectFallbackGunshot(emitter, weapon, nil)
        return
    end

    if not AWCWF_HasInspectShootableRound(weapon) then
        AWCWF_PlayInspectSoundLayers(emitter, profile.triggerLayers)
        return
    end

    if AWCWF_HasInspectSuppressor(weapon) then
        AWCWF_PlayInspectSoundLayers(emitter, profile.suppressorLayers)
    else
        AWCWF_PlayInspectSoundLayers(emitter, profile.normalLayers)
    end
end

local function AWCWF_GetRecoilYawImpulse(scene, recoil)
    local yawImpulse = recoil.yawImpulse or 0
    scene.recoilYawSign = (scene.recoilYawSign or -1) * -1
    local jitter = 1
    if ZombRandFloat then
        jitter = ZombRandFloat(0.65, 1.0)
    elseif ZombRand then
        jitter = 0.65 + (ZombRand(36) / 100)
    end
    return yawImpulse * scene.recoilYawSign * jitter
end

local function AWCWF_GetInspectBoltModel(weapon, boltAnim)
    if not weapon or not boltAnim then
        return nil
    end

    local boltPart = weapon:getWeaponPart("Bolt")
    if not boltPart and boltAnim.TargetPart then
        boltPart = instanceItem(boltAnim.TargetPart)
    end
    if not boltPart then
        return nil
    end

    local item = ScriptManager.instance:getItem(boltPart:getFullType())
    if not item then
        return nil
    end

    local worldmodel = item:getWorldStaticModel()
    if not worldmodel or string.find(worldmodel, "nil") or string.find(worldmodel, "null") then
        return nil
    end

    return worldmodel
end

local function AWCWF_GetInspectBoltBasePosition(weapon)
    if not weapon or not weapon.getWeaponSprite then
        return nil
    end

    local sprite = weapon:getWeaponSprite()
    if not sprite or sprite == "nil" then
        return nil
    end

    local model = ScriptManager.instance:getModelScript("Base." .. sprite)
    if not model then
        return nil
    end

    local attachment = model:getAttachmentById("Bolt")
    if not attachment then
        return nil
    end

    local offset = attachment:getOffset()
    if not offset then
        return nil
    end

    return offset:x(), offset:y(), offset:z()
end

local function AWCWF_StartInspectBoltAnim(scene, weapon)
    if not scene or not scene.javaObject or not weapon or not AWCWF_WeaponWithBoltAnim then
        return
    end

    local boltAnim = AWCWF_WeaponWithBoltAnim[weapon:getType()]
    if not boltAnim or not boltAnim.TargetPartOffset then
        return
    end

    local worldmodel = AWCWF_GetInspectBoltModel(weapon, boltAnim)
    if not worldmodel then
        return
    end

    local baseX, baseY, baseZ = AWCWF_GetInspectBoltBasePosition(weapon)
    if not baseX then
        return
    end

    scene.inspectBoltAnim = {
        model = worldmodel,
        baseX = baseX,
        baseY = baseY,
        baseZ = baseZ,
        offset = boltAnim.TargetPartOffset,
        rotate = boltAnim.TargetPartRotate,
        tick = 0,
        rackTick = math.max(1, boltAnim.RackTick or 1),
        waitTick = math.max(0, boltAnim.WaitTick or 0),
        returnTick = math.max(1, boltAnim.TickRemain or 1)
    }
end

local function AWCWF_SetInspectBoltPosition(scene, anim, ratio)
    local offset = anim.offset
    scene.javaObject:fromLua4("setObjectPosition", anim.model, anim.baseX + ((offset.x or 0) * ratio),
        anim.baseY + ((offset.y or 0) * ratio), anim.baseZ + ((offset.z or 0) * ratio))
end

local function AWCWF_UpdateInspectBoltAnim(scene)
    local anim = scene.inspectBoltAnim
    if not anim then
        return
    end

    anim.tick = anim.tick + 1
    local rackEnd = anim.rackTick
    local waitEnd = rackEnd + anim.waitTick
    local doneTick = waitEnd + anim.returnTick

    if anim.tick <= rackEnd then
        AWCWF_SetInspectBoltPosition(scene, anim, anim.tick / rackEnd)
        return
    end

    if anim.tick <= waitEnd then
        AWCWF_SetInspectBoltPosition(scene, anim, 1)
        return
    end

    if anim.tick <= doneTick then
        local returnProgress = (anim.tick - waitEnd) / anim.returnTick
        AWCWF_SetInspectBoltPosition(scene, anim, 1 - returnProgress)
        return
    end

    AWCWF_SetInspectBoltPosition(scene, anim, 0)
    scene.inspectBoltAnim = nil
end

function WeaponScene:addRecoilImpulse()
    local recoil = WeaponInspect_Theme.recoil
    if not recoil then
        return
    end

    local weapon = AWCWF_GetInspectWeapon(self)
    local hasShootableRound = AWCWF_HasInspectShootableRound(weapon)

    self.recoilPitch = math.min((self.recoilPitch or 0) + (recoil.pitchImpulse or 0), recoil.maxPitch or 0)
    local yaw = (self.recoilYaw or 0) + AWCWF_GetRecoilYawImpulse(self, recoil)
    local maxYaw = recoil.maxYaw or 0
    if yaw > maxYaw then
        yaw = maxYaw
    elseif yaw < -maxYaw then
        yaw = -maxYaw
    end
    self.recoilYaw = yaw
    AWCWF_PlayInspectGunshot(self)
    if hasShootableRound then
        AWCWF_StartInspectBoltAnim(self, weapon)
    end
end

function WeaponScene:updateRecoilFeedback()
    local recoil = WeaponInspect_Theme.recoil
    if not recoil then
        return 0, 0
    end

    self.recoilFrame = (self.recoilFrame or 0) + 1
    if self.recoilActive and self.recoilFrame >= (recoil.interval or 1) then
        self.recoilFrame = 0
        self:addRecoilImpulse()
    end

    local recovery = recoil.recovery or 0
    self.recoilPitch = (self.recoilPitch or 0) * recovery
    self.recoilYaw = (self.recoilYaw or 0) * recovery

    local threshold = recoil.settleThreshold or 0
    if math.abs(self.recoilPitch) < threshold then
        self.recoilPitch = 0
    end
    if math.abs(self.recoilYaw) < threshold then
        self.recoilYaw = 0
    end

    return self.recoilPitch or 0, self.recoilYaw or 0
end
function WeaponScene:render()
    ISUI3DScene.render(self)
    if self.startRotate then
        self.rotationZ = self.rotationZ + 0.5
    end
    AWCWF_UpdateInspectBoltAnim(self)
    local recoilPitch, recoilYaw = self:updateRecoilFeedback()
    self.javaObject:fromLua3("setViewRotation", self.rotationX - recoilPitch, self.rotationY + recoilYaw, self.rotationZ)
end
function WeaponScene:onMouseUp()
    -- Future restore point for drag rotation / gizmo editing:
    -- ISUI3DScene.onMouseUp(self, x, y)
    -- self.javaObject:fromLua0("stopGizmoTracking")
    self.gizmoAxis = "None"
    self.mouseDown = false
    self.onMousenow = false
    self.recoilActive = false
end
function WeaponScene:onMouseUpOutside()
    self.gizmoAxis = "None"
    self.mouseDown = false
    self.onMousenow = false
    self.recoilActive = false
end
function WeaponScene:onRightMouseDown()
    -- Future restore point for gizmo cancel:
    -- self.javaObject:fromLua0("stopGizmoTracking")
    -- self.javaObject:fromLua1("setGizmoPos", self.gizmoStartScenePos)
    self.gizmoAxis = "None"
    self.mouseDown = false
    self.recoilActive = false
end
function WeaponScene:onGizmoStart()
    if not self.parent or not self.parent.editUI or not self.parent.editUI.current then
        return
    end
    self.parent.editUI.current:onGizmoStart()
end
function WeaponScene:onGizmoChanged(delta)
    if self.gizmoAxis == "None" then
        return
    end -- cancelled via onRightMouseUp
    if not self.parent or not self.parent.editUI or not self.parent.editUI.current then
        return
    end
    self.parent.editUI.current:onGizmoChanged(delta)
end
function WeaponScene:onGizmoAccept()
    if not self.parent or not self.parent.editUI or not self.parent.editUI.current then
        return
    end
    self.parent.editUI.current:onGizmoAccept()
end
function WeaponScene:onGizmoCancel()
    if not self.parent or not self.parent.editUI or not self.parent.editUI.current then
        return
    end
    self.parent.editUI.current:onGizmoCancel()
end
function WeaponScene:new(x, y, width, height)
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
    -- MFS patch: show the same side orientation used by the world model.
    o.rotationY = 180
    o.rotationZ = 130
    o.recoilActive = false
    o.recoilFrame = 0
    o.recoilPitch = 0
    o.recoilYaw = 0
    o.recoilYawSign = -1
    o.inspectBoltAnim = nil
    return o
end

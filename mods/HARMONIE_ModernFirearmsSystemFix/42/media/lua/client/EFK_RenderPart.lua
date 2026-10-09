require "NewBigGuns2024"

AWCWF_Attach = {}
function AWCWF_Attach.CheckIsWeapon(item)
    if instanceof(item, "HandWeapon") and item:getFullType() ~= "Base.TempNilItem" and item:getModData().weaponpart then
        for i, v in pairs(item:getModData().weaponpart) do
            return true
        end
    end
end
function AWCWF_Attach.CompareTwoList(list1, list2)
    for i, v in pairs(list1) do
        if not list2[i] then
            return false
        else
            if v:getWeaponSprite() ~= list2[i].part then
                return false
            end
        end
    end
    for i, v in pairs(list2) do
        if not list1[i] then
            return false
        else
            if list1[i]:getWeaponSprite() ~= v.part then
                return false
            end
        end
    end
    return true
end

local cos = math.cos
local sin = math.sin
-- 定义旋转函数
function AWCWF_Attach.rotate_point(x, y, z, alpha, beta, gamma)
    local y1 = y * cos(alpha) - z * sin(alpha)
    local z1 = y * sin(alpha) + z * cos(alpha)
    local x1 = x
    -- 绕 Y 轴旋转 beta 角度
    local x2 = x1 * cos(beta) + z1 * sin(beta)
    local y2 = y1
    local z2 = -x1 * sin(beta) + z1 * cos(beta)
    -- 绕 Z 轴旋转 gamma 角度
    local x3 = x2 * cos(gamma) - y2 * sin(gamma)
    local y3 = x2 * sin(gamma) + y2 * cos(gamma)
    local z3 = z2
    return x3, y3, z3
end
local function rotate_point(a, b, c, alpha, beta, gamma)
    -- 转换角度为弧度
    local rad_alpha = math.rad(alpha)
    local rad_beta = math.rad(beta)
    local rad_gamma = math.rad(gamma)
    -- 计算各个旋转矩阵
    local Rx =
        {{1, 0, 0}, {0, math.cos(rad_alpha), -math.sin(rad_alpha)}, {0, math.sin(rad_alpha), math.cos(rad_alpha)}}
    local Ry = {{math.cos(rad_beta), 0, math.sin(rad_beta)}, {0, 1, 0}, {-math.sin(rad_beta), 0, math.cos(rad_beta)}}
    local Rz =
        {{math.cos(rad_gamma), -math.sin(rad_gamma), 0}, {math.sin(rad_gamma), math.cos(rad_gamma), 0}, {0, 0, 1}}
    -- 矩阵乘法函数
    local function mat_mult(A, B)
        local result = {}
        for i = 1, 3 do
            result[i] = {}
            for j = 1, 3 do
                result[i][j] = 0
                for k = 1, 3 do
                    result[i][j] = result[i][j] + A[i][k] * B[k][j]
                end
            end
        end
        return result
    end
    -- 矩阵与向量乘法函数
    local function mat_vec_mult(M, v)
        local result = {}
        for i = 1, 3 do
            result[i] = 0
            for j = 1, 3 do
                result[i] = result[i] + M[i][j] * v[j]
            end
        end
        return result
    end
    -- 计算总的旋转矩阵 R
    local R = mat_mult(Rz, mat_mult(Ry, Rx))
    -- 原始点向量
    local point = {a, b, c}
    -- 计算新点的坐标
    local new_point = mat_vec_mult(R, point)
    return new_point[1], new_point[2], new_point[3]
end
AWCWF_Attach.group = AttachedLocations.getGroup("Human")

function AWCWF_Attach.Apply_Effect(player, weapon, froceUpdate)
    if not instanceof(player, 'IsoPlayer') then
        return
    end
    if not player then
        player = getPlayer()
    end
    if not weapon then
        weapon = player:getPrimaryHandItem()
    end
    local isfemale
    if player:isFemale() then
        isfemale = "FemaleBody"
    else
        isfemale = "MaleBody"
    end
    local AttachWeaponList = {}
    local handweapon = nil
    local LocalAttachItems = {}

    local attachitems = getPlayer():getAttachedItems()
    for i = 1, attachitems:size() do
        local attachitem = attachitems:get(i - 1)
        local invitem = attachitem:getItem()
        if AWCWF_Attach.CheckIsWeapon(invitem) then
            AttachWeaponList[attachitem] = true
        end
        if invitem:getFullType() == "Base.TempNilItem" then
            LocalAttachItems[attachitem:getLocation()] = invitem

        end
    end
    if instanceof(weapon, "HandWeapon") then
        handweapon = weapon
    end
    local LocationList = {}
    -- 身体
    local Cursor = getCell():getDrag(0)
    for AttachWeapon, v in pairs(AttachWeaponList) do
        if not Cursor or (Cursor and not Cursor.isPlace3DCursor) then
            AttachWeapon:getItem():RemoveAllRealPart()
        end
        for PartType, PartFullID in pairs(AttachWeapon:getItem():getModData().weaponpart) do
            local modelscript = AttachWeapon:getItem():getModule() .. "." .. AttachWeapon:getItem():getWeaponSprite()
            local model = ScriptManager.instance:getModelScript(modelscript)
            local partmodel = ScriptManager.instance:getModelScript(PartFullID)
            if model and partmodel then
                local attachment0 = model:getAttachmentById(PartType)
                if not attachment0 then
                    attachment0 = ModelAttachment.new(PartType)
                end
                local offset = attachment0:getOffset()
                local rotate = attachment0:getRotate()
                local scale = attachment0:getScale()
                local attachmentid = AttachedLocations.getGroup("Human"):getOrCreateLocation(AttachWeapon:getLocation())
                    :getAttachmentName()
                local modelbody = ScriptManager.instance:getModelScript(isfemale)
                local bodyattachment = modelbody:getAttachmentById(attachmentid)
                local bone = bodyattachment:getBone()
                local Boffset = bodyattachment:getOffset()
                local Brotate = bodyattachment:getRotate()
                local boneandtype = bone .. "[]" .. PartType
                local ax, ay, az = offset:x(), offset:y(), offset:z()
                local alpha, beta, gamma = Brotate:x(), Brotate:y(), Brotate:z()

                local x_new, y_new, z_new = rotate_point(ax, ay, az, 0, 0, gamma)
                x_new, y_new, z_new = rotate_point(x_new, y_new, z_new, 0, beta, 0)
                x_new, y_new, z_new = rotate_point(x_new, y_new, z_new, alpha, 0, 0)

                LocationList[boneandtype] = {
                    part = PartFullID,
                    x = Boffset:x() + x_new,
                    y = Boffset:y() + y_new,
                    z = Boffset:z() + z_new,
                    rx = rotate:x() + Brotate:x(),
                    ry = rotate:y() + Brotate:y(),
                    rz = rotate:z() + Brotate:z(),
                    scale = scale
                }
            end
        end
    end
    -- 手上的
    if AWCWF_Attach.CheckIsWeapon(handweapon) then
        if not Cursor or (Cursor and not Cursor.isPlace3DCursor) then
            -- handweapon:RemoveAllRealPart()
        end
        if not handweapon:getModData().weaponpart then
            return
        end
        for PartType, PartFullID in pairs(handweapon:getModData().weaponpart) do
            local modelscript = handweapon:getModule() .. "." .. handweapon:getWeaponSprite()
            local model = ScriptManager.instance:getModelScript(modelscript)
            local partmodel = ScriptManager.instance:getModelScript(PartFullID)
            local PartItem = handweapon:getModData().weaponpart[PartType]
            if model and partmodel and PartItem then

                local attachment0 = model:getAttachmentById(PartType)
                -- print(attachment0)
                if not attachment0 then
                    attachment0 = ModelAttachment.new(PartType)
                end
                local offset = attachment0:getOffset()

                -- The inspection editor stores absolute per-part offsets by full item type.
                -- Use those values for the held model instead of always falling back to the
                -- weapon model script's default attachment offset.
                local savedPos = nil
                local gunPos = handweapon:getModData().GunPos
                if gunPos then
                    savedPos = gunPos[PartFullID]
                end
                local posX = savedPos and savedPos.x or offset:x()
                local posY = savedPos and savedPos.y or offset:y()
                local posZ = savedPos and savedPos.z or offset:z()

                local rotate = attachment0:getRotate()
                local scale = attachment0:getScale()
                local bone = "Bip01_Prop1"
                local Boffset = Vector3f.new()
                local Brotate = Vector3f.new()
                local boneandtype = bone .. "[]" .. PartType
                LocationList[boneandtype] = {
                    ishandweapon = true,
                    part = PartFullID,
                    -- The held-weapon attachment coordinate system is mirrored laterally
                    -- relative to the inspection scene. Mirror X only for the character model.
                    x = -posX + Boffset:x(),
                    y = posY + Boffset:y(),
                    z = posZ + Boffset:z(),
                    rx = rotate:x() + Brotate:x(),
                    ry = rotate:y() + Brotate:y(),
                    rz = rotate:z() + Brotate:z(),
                    scale = scale
                }
            end
        end

    end
    if handweapon and not AWCWF_AdditionalParts.GetWeaponModelInstance(player, handweapon) then
        for i, v in pairs(LocalAttachItems) do
            if v:getModData().ishandweapon then
                player:removeAttachedItem(v);
            end
        end
        return
    end
    if not AWCWF_Attach.CompareTwoList(LocalAttachItems, LocationList) or froceUpdate then
        for boneandtype, v in pairs(LocalAttachItems) do
            player:removeAttachedItem(v);
        end
        for boneandtype, PosTable in pairs(LocationList) do
            -- print(boneandtype)
            local location = AWCWF_Attach.group:getOrCreateLocation(boneandtype)

            local model = ScriptManager.instance:getModelScript(isfemale)
            local modelattchment = nil
            if not model:getAttachmentById(boneandtype) then
                modelattchment = ModelAttachment.new(boneandtype)
            else
                modelattchment = model:getAttachmentById(boneandtype)
            end
            local input = boneandtype
            local pattern = "(.-)%[%](.+)"
            local before, after = string.match(input, pattern)
            local rotate = modelattchment:getRotate()
            local offset = modelattchment:getOffset()
            offset:set(PosTable.x, PosTable.y, PosTable.z)
            rotate:set(PosTable.rx, PosTable.ry, PosTable.rz)
            modelattchment:setScale(PosTable.scale)

            model:addAttachment(modelattchment):setBone(before)
            location:setAttachmentName(boneandtype)

            local item = instanceItem("Base.TempNilItem")
            if PosTable.ishandweapon then
                item:getModData().ishandweapon = true
            end
            item:setWeaponSprite(PosTable.part)
            player:setAttachedItem(boneandtype, item)
        end
    end
end
-- Events.OnEquipPrimary.Add(AWCWF_Attach.Apply_Effect);
-- Events.OnGameStart.Add(function()
--     local player = getPlayer()
--     AWCWF_Attach.Apply_Effect(player, player:getPrimaryHandItem())
-- end)

Events.OnPlayerUpdate.Add(AWCWF_Attach.Apply_Effect)

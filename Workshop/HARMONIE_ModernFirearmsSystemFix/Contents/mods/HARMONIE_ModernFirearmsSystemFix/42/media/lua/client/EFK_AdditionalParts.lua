AWCWF_AdditionalParts = {}
local function patchClassMetaMethod(class, methodName, createPatch)

    if true then return end 
    local metatable = __classmetatables[class]
    if not metatable then
        error("Unable to find metatable for class " .. tostring(class))
    end
    local metatable__index = metatable.__index
    if not metatable__index then
        error("Unable to find __index in metatable for class " .. tostring(class))
    end
    local originalMethod = metatable__index[methodName]
    metatable__index[methodName] = createPatch(originalMethod)
end
AWCWF_AdditionalParts.partlist = {"Scope", "Canon", "Stock", "Grip", "Laser", "Light", "Stool", "R_Scope", "L_Scope",
                                  "Skin", "Sling", "RecoilPad", "Misc", "Clip", "Hide_Beam", "Barrel", "Barrel_Shroud"}
AWCWF_AdditionalParts.getpartfunc = {}
AWCWF_AdditionalParts.setpartfunc = {}
for i, v in pairs(AWCWF_AdditionalParts.partlist) do
    AWCWF_AdditionalParts.getpartfunc[v] = function()
        return function(item)
            -- item:getWeaponPart(v)
            item:getModData().weaponpart = item:getModData().weaponpart or {}
            if item:getModData().weaponpart[v] then
                return instanceItem(item:getModData().weaponpart[v])
            end
        end
    end
    patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "get" .. v, AWCWF_AdditionalParts.getpartfunc[v])
    AWCWF_AdditionalParts.setpartfunc[v] = function()
        return function(item, part)
            -- item:setWeaponPart(v, part)
            item:getModData().weaponpart = item:getModData().weaponpart or {}
            if part then
                item:getModData().weaponpart[v] = part:getFullType()
            else
                item:getModData().weaponpart[v] = part
            end
        end
    end
    patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "set" .. v, AWCWF_AdditionalParts.setpartfunc[v])
end

AWCWF_AdditionalParts.setWeaponPart = function(setWeaponPart)
    return function(item, type, weaponpart, isReal, setOnly)
        if not instanceof(item, "HandWeapon") then
            return
        end
        if weaponpart == nil then
            if item:getWeaponPart(type, true) then
                item:clearWeaponPart(type)
            end
        else
            if isReal then
                -- print("setWeaponPart", type, weaponpart)
                setWeaponPart(item, type, weaponpart)
            end
            if setOnly then
                return
            end
        end
        item:getModData().weaponpart = item:getModData().weaponpart or {}
        if weaponpart then
            item:getModData().weaponpart[type] = weaponpart:getFullType()
        else
            item:getModData().weaponpart[type] = nil
        end
    end
end

patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "setWeaponPart", AWCWF_AdditionalParts.setWeaponPart)

AWCWF_AdditionalParts.RemoveAllRealPart = function(RemoveAllRealPart)
    return function(item)
        item:getModData().weaponpart = item:getModData().weaponpart or {}
        for k, v in pairs(item:getModData().weaponpart) do
            local RealPart = item:getWeaponPart(k, true)
            if RealPart then
                item:clearWeaponPart(k)
            end
        end
    end
end

patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "RemoveAllRealPart",
    AWCWF_AdditionalParts.RemoveAllRealPart)

AWCWF_AdditionalParts.getWeaponPart = function(getWeaponPart)
    return function(item, type, isReal)
        if isReal then
            return getWeaponPart(item, type)
        end
        item:getModData().weaponpart = item:getModData().weaponpart or {}
        local itema = item:getModData().weaponpart[type]
        if itema then

            return instanceItem(itema)
        end
    end
end
patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "getWeaponPart", AWCWF_AdditionalParts.getWeaponPart)

AWCWF_AdditionalParts.detachWeaponPart = function(detachWeaponPart)
    return function(item, player, weaponpart)
        item:getModData().weaponpart = item:getModData().weaponpart or {}
        if instanceof(weaponpart, "WeaponPart") and weaponpart:getFullType() ==
            item:getModData().weaponpart[weaponpart:getPartType()] then
            item:setWeaponPart(weaponpart:getPartType(), nil);
            item:setMaxRange(item:getMaxRange() - weaponpart:getMaxRange())
            item:setClipSize(item:getClipSize() - weaponpart:getClipSize())
            item:setReloadTime(item:getReloadTime() - weaponpart:getReloadTime())
            item:setRecoilDelay(math.floor((item:getRecoilDelay() - weaponpart:getRecoilDelay()) + 0.5))
            item:setAimingTime(item:getAimingTime() - weaponpart:getAimingTime())
            item:setHitChance(item:getHitChance() - weaponpart:getHitChance())
            item:setProjectileSpread(item:getProjectileSpread() - weaponpart:getSpreadModifier())
            item:setMinDamage(item:getMinDamage() - weaponpart:getDamage())
            item:setMaxDamage(item:getMaxDamage() - weaponpart:getDamage())
            weaponpart:onDetach(player, item)
        end
    end
end

patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "detachWeaponPart", AWCWF_AdditionalParts.detachWeaponPart)
AWCWF_AdditionalParts.attachWeaponPart = function(attachWeaponPart)
    return function(item, player, weaponpart)
        item:getModData().weaponpart = item:getModData().weaponpart or {}
        if weaponpart ~= nil and instanceof(weaponpart, "WeaponPart") then
            local otherpart = item:getModData().weaponpart[weaponpart:getPartType()]
            if otherpart then
                local otherpartitem = instanceItem(otherpart)
                item:detachWeaponPart(otherpartitem)
            end
            item:setWeaponPart(weaponpart:getPartType(), weaponpart);
            item:setMaxRange(item:getMaxRange() + weaponpart:getMaxRange());
            item:setMinRangeRanged(item:getMinRangeRanged() + weaponpart:getMinRangeRanged());
            item:setClipSize(item:getClipSize() + weaponpart:getClipSize());
            item:setReloadTime(item:getReloadTime() + weaponpart:getReloadTime());
            item:setRecoilDelay(item:getRecoilDelay() + weaponpart:getRecoilDelay())
            item:setAimingTime(item:getAimingTime() + weaponpart:getAimingTime());
            item:setHitChance(item:getHitChance() + weaponpart:getHitChance());
            item:setMinAngle(item:getMinAngle() + weaponpart:getAngle());
            item:setMinDamage(item:getMinDamage() + weaponpart:getDamage());
            item:setMaxDamage(item:getMaxDamage() + weaponpart:getDamage());
            weaponpart:onAttach(player, item)
        end
    end
end
patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "attachWeaponPart", AWCWF_AdditionalParts.attachWeaponPart)
AWCWF_AdditionalParts.setContainsClip = function(setContainsClip)
    return function(item, bool)
        setContainsClip(item, bool)
        item:getModData().weaponpart = item:getModData().weaponpart or {}
        if bool then
            item:getModData().weaponpart["Clip"] = item:getMagazineType()
        else
            item:getModData().weaponpart["Clip"] = nil
        end
    end
end
patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "setContainsClip", AWCWF_AdditionalParts.setContainsClip)

AWCWF_AdditionalParts.getAllWeaponParts = function(getAllWeaponParts)
    return function(item)
        local Parts = ArrayList.new();
        for i, v in pairs(AWCWF_AdditionalParts.partlist) do
            local part = item:getWeaponPart(v)
            if part then
                Parts:add(part)
            end
        end
        return Parts
    end
end
patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "getAllWeaponParts",
    AWCWF_AdditionalParts.getAllWeaponParts)

AWCWF_AdditionalParts.getAllWeaponParts = function(getAllWeaponParts)
    return function(item, ArrayListReturn)
        if not ArrayListReturn then
            ArrayListReturn = ArrayList.new()
        end
        for i, v in pairs(AWCWF_AdditionalParts.partlist) do
            local part = item:getWeaponPart(v)
            if part then
                ArrayListReturn:add(part)
            end
        end
        return ArrayListReturn
    end
end
patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "getAllWeaponParts",
    AWCWF_AdditionalParts.getAllWeaponParts)

AWCWF_AdditionalParts.clearAllWeaponParts = function(getWeaponPart)
    return function(item)
        item:getModData().weaponpart = {}
    end
end

patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "clearAllWeaponParts",
    AWCWF_AdditionalParts.clearAllWeaponParts)

local function getJavaFieldNum(object, fieldName)
    for i = 0, getNumClassFields(object) - 1 do
        local javaField = getClassField(object, i)
        if luautils.stringEnds(tostring(javaField), '.' .. fieldName) then
            return i
        end
    end
end

local classfieldtable = {}
function spfunction(obj, stringa)
    if not obj then
        return
    end
    local wTransformFieldNum
    if classfieldtable[stringa] == nil then
        wTransformFieldNum = getJavaFieldNum(obj, stringa)
        classfieldtable[stringa] = wTransformFieldNum
    else
        wTransformFieldNum = classfieldtable[stringa]
    end
    if wTransformFieldNum then
        local worldmodel = getClassFieldVal(obj, getClassField(obj, wTransformFieldNum))
        return worldmodel
    else
        return false
    end
end
function AWCWF_AdditionalParts.GetPlayerModelList(player)
    if not player then
        return
    end

    return spfunction(player:getModelInstance(), "sub")
end
function AWCWF_AdditionalParts.getweaponmodellist(player)
    local playerlist = AWCWF_AdditionalParts.GetPlayerModelList(player)
    local weapon = player:getPrimaryHandItem()
    if not instanceof(weapon, "HandWeapon") then
        return
    end
    for i = 1, playerlist:size() do
        local modelinstance = playerlist:get(i - 1)
        local modelscriptins = spfunction(modelinstance, "m_modelScript")
        local modelscript = "Base." .. weapon:getWeaponSprite()
        local model = ScriptManager.instance:getModelScript(modelscript)
        if modelscriptins and modelscriptins:getMeshName() == model:getMeshName() then
            return spfunction(modelinstance, "sub")
        end
    end
end
function AWCWF_AdditionalParts.getweaponmodellistall(player)
    local playerlist = AWCWF_AdditionalParts.GetPlayerModelList(player)
    local weapon = player:getPrimaryHandItem()
    if not instanceof(weapon, "HandWeapon") then
        return
    end
    local tableweapon = {}
    for i = 1, playerlist:size() do
        local modelinstance = playerlist:get(i - 1)
        local modelscriptins = spfunction(modelinstance, "m_modelScript")
        local modelscript = "Base." .. weapon:getWeaponSprite()
        local model = ScriptManager.instance:getModelScript(modelscript)
        if modelscriptins and modelscriptins:getMeshName() == model:getMeshName() then
            tableweapon[spfunction(modelinstance, "sub")] = true
        end
    end
    return tableweapon
end
function AWCWF_AdditionalParts.GetWeaponModelInstance(player, weapon)
    local playerlist = AWCWF_AdditionalParts.GetPlayerModelList(player)
    if not playerlist then
        return
    end
    -- local weapon  = player:getPrimaryHandItem()
    if not instanceof(weapon, "HandWeapon") then
        return
    end
    for i = 1, playerlist:size() do
        local modelinstance = playerlist:get(i - 1)
        local modelscriptins = spfunction(modelinstance, "m_modelScript")
        local modelscript = "Base." .. weapon:getWeaponSprite()
        local model = ScriptManager.instance:getModelScript(modelscript)
        if modelscriptins and modelscriptins and model and modelscriptins:getMeshName() == model:getMeshName() then
            return modelinstance
        end
    end
end

function spfunctionset(obj, stringa, value)
    for i = 1, getNumClassFields(obj) do
        local fielda = getClassField(obj, i - 1)
        -- print(fielda)
        -- print(tostring(fielda))
        if fielda and fielda:getName() == stringa then
            -- fielda:setAccessible(true)
            fielda:set(obj, value)
            return
        end
    end
end

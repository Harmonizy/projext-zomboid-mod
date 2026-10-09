require "TimedActions/ISLoadBulletsInMagazine"

-- 自动装填弹匣补丁：人物进行装填弹匣时，每个装填动画循环装 5 发(原版 1 发)。
-- 仅当佩戴(左手中指)或主背包携带 Base.cat_AutoReload 时生效。
--
-- 放在 shared 下，因为实际装填发生在服务端(animEvent 的 not isClient() 分支)，
-- 服务器也需要执行本补丁。速度/动画仍由原版 ReloadSpeed 驱动，与原版一致。

local ROUNDS_PER_CYCLE = 5

local function fullType(item)
    return (item:getModule() or "") .. "." .. (item:getType() or "")
end

-- 是否佩戴/主背包携带自动装填机构
local function hasAutoReloadDevice(character)
    if not character then return false end

    local ok, worn = pcall(function()
        return character:getWornItem(ItemBodyLocation.LEFT_MIDDLE_FINGER)
    end)
    if ok and worn and fullType(worn) == "Base.cat_AutoReload" then
        return true
    end

    local inv = character:getInventory()
    if inv then
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it and fullType(it) == "Base.cat_AutoReload" then
                return true
            end
        end
    end
    return false
end

local origAnimEvent = ISLoadBulletsInMagazine.animEvent

function ISLoadBulletsInMagazine:animEvent(event, parameter)
    if event ~= 'InsertBullet' then
        return origAnimEvent(self, event, parameter)
    end

    -- 以下复刻原版 'InsertBullet' 分支，仅把“装 1 发”改为“装 5 发”。
    if self:isLoadFinished() then return end
    if self:isLocal() then
        if self.loadedThisLoop then return end
    end
    self.loadedThisLoop = true
    if not isClient() then
        local chance = 5
        local xp = 1
        if self.character:getPerkLevel(Perks.Reloading) < 5 then
            chance = 2
            xp = 4
        end
        if ZombRand(chance) == 0 then
            addXp(self.character, Perks.Reloading, xp)
        end

        local itemKey = self.magazine:getAmmoType():getItemKey()
        local rounds = 1
        if hasAutoReloadDevice(self.character) then
            rounds = ROUNDS_PER_CYCLE
        end

        local current = self.magazine:getCurrentAmmoCount()
        local maxAmmo = self.magazine:getMaxAmmo()
        if rounds > maxAmmo - current then
            rounds = maxAmmo - current
        end

        for _ = 1, rounds do
            local removedBullet = self.character:getInventory():RemoveOneOf(itemKey, true)
            if not removedBullet then break end
            self.magazine:setCurrentAmmoCount(self.magazine:getCurrentAmmoCount() + 1)
            sendRemoveItemFromContainer(self.character:getInventory(), removedBullet)
        end
        syncItemFields(self.character, self.magazine)
    end
end

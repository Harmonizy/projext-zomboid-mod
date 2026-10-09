MFSPerformanceSafety = MFSPerformanceSafety or {}

local Fix = MFSPerformanceSafety
Fix.VERSION = "1.4.0"
Fix.RENDER_PROBE_TICKS = 6
Fix.RENDER_WATCHDOG_TICKS = 30
Fix.rendererCache = Fix.rendererCache or setmetatable({}, { __mode = "k" })
Fix.logged = Fix.logged or {}

function Fix.invalidateRenderer(player)
    local entry = player and Fix.rendererCache[player] or nil
    if not entry then
        return
    end
    entry.signature = nil
    entry.shallow = nil
    entry.probeTicks = Fix.RENDER_PROBE_TICKS
    entry.watchdogTicks = Fix.RENDER_WATCHDOG_TICKS
end

function MFS_RefreshWeaponAttachmentState(player, weapon)
    if not player then
        return
    end

    if weapon and (player:getPrimaryHandItem() == weapon or player:getSecondaryHandItem() == weapon) then
        player:resetEquippedHandsModels()
    end
    Fix.invalidateRenderer(player)

    if MFS_SyncEquippedWeaponState then
        MFS_SyncEquippedWeaponState(player, weapon, true)
    end
end

local function logOnce(key, message)
    if Fix.logged[key] then
        return
    end
    Fix.logged[key] = true
    print("[MFSPerformanceSafety] " .. message)
end

local function sortedPartSignature(parts)
    if type(parts) ~= "table" then
        return "-"
    end

    local keys = {}
    for key in pairs(parts) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    local result = {}
    for i = 1, #keys do
        local key = keys[i]
        result[#result + 1] = tostring(key) .. "=" .. tostring(parts[key])
    end
    return table.concat(result, "\30")
end

local function inventoryItemSignature(item)
    if not item then
        return "-"
    end

    local isWeapon = instanceof(item, "HandWeapon")
    local parts = nil
    local weaponSprite = "-"
    if isWeapon then
        local modData = item:getModData()
        parts = modData and modData.weaponpart or nil
        weaponSprite = item:getWeaponSprite()
    end
    return table.concat({
        tostring(item),
        tostring(item:getID()),
        tostring(item:getFullType()),
        tostring(weaponSprite),
        sortedPartSignature(parts)
    }, "\31")
end

local function isRenderedWeapon(item)
    if not item or not instanceof(item, "HandWeapon") then
        return false
    end
    if item:getFullType() == "Base.TempNilItem" then
        return false
    end

    local modData = item:getModData()
    local parts = modData and modData.weaponpart or nil
    if type(parts) ~= "table" then
        return false
    end
    for _ in pairs(parts) do
        return true
    end
    return false
end

local function buildRendererSignature(player)
    local signature = {
        player:isFemale() and "female" or "male",
        inventoryItemSignature(player:getPrimaryHandItem())
    }

    -- AWCWF_RenderPart.lua uses getPlayer() for attached items even when an
    -- IsoPlayer is passed in. Match that behavior instead of changing it here.
    local attachedOwner = getPlayer() or player
    local attachedItems = attachedOwner and attachedOwner:getAttachedItems() or nil
    if attachedItems then
        for i = 0, attachedItems:size() - 1 do
            local attachedItem = attachedItems:get(i)
            local item = attachedItem and attachedItem:getItem() or nil
            if item and (item:getFullType() == "Base.TempNilItem" or isRenderedWeapon(item)) then
                signature[#signature + 1] =
                    tostring(attachedItem:getLocation()) .. "\31" .. inventoryItemSignature(item)
            end
        end
    end

    local cell = getCell()
    local cursor = cell and cell:getDrag(0) or nil
    signature[#signature + 1] = cursor and cursor.isPlace3DCursor and "placing" or "normal"

    table.sort(signature)
    return table.concat(signature, "\29")
end

local function rendererShallowSignature(player)
    local attachedOwner = getPlayer() or player
    local attachedItems = attachedOwner and attachedOwner:getAttachedItems() or nil
    return table.concat({
        tostring(player:getPrimaryHandItem()),
        tostring(attachedItems and attachedItems:size() or -1),
        player:isFemale() and "female" or "male"
    }, "\31")
end

local function rendererUpdate(player)
    if not player or not instanceof(player, "IsoPlayer") then
        return
    end

    local entry = Fix.rendererCache[player]
    if not entry then
        entry = {
            probeTicks = Fix.RENDER_PROBE_TICKS,
            watchdogTicks = Fix.RENDER_WATCHDOG_TICKS
        }
        Fix.rendererCache[player] = entry
    end

    entry.probeTicks = entry.probeTicks + 1
    entry.watchdogTicks = entry.watchdogTicks + 1

    local shallow = rendererShallowSignature(player)
    if shallow ~= entry.shallow then
        entry.shallow = shallow
        entry.probeTicks = Fix.RENDER_PROBE_TICKS
    end

    if entry.probeTicks < Fix.RENDER_PROBE_TICKS then
        return
    end
    entry.probeTicks = 0

    local signatureOk, signature = pcall(buildRendererSignature, player)
    if not signatureOk then
        logOnce("renderer-signature-error",
            "renderer signature failed; falling back to the original renderer: " .. tostring(signature))
        signature = nil
    end

    if signature and signature == entry.signature
        and entry.watchdogTicks < Fix.RENDER_WATCHDOG_TICKS then
        return
    end

    entry.watchdogTicks = 0
    local original = Fix.rendererOriginal
    if type(original) ~= "function" then
        return
    end

    local renderOk, renderError = pcall(original, player)
    if not renderOk then
        entry.signature = nil
        logOnce("renderer-original-error",
            "original part renderer raised an error; retries are throttled: " .. tostring(renderError))
        return
    end

    local finalOk, finalSignature = pcall(buildRendererSignature, player)
    entry.signature = finalOk and finalSignature or signature
end

local function installRendererOptimization()
    if type(AWCWF_Attach) ~= "table"
        or type(AWCWF_Attach.Apply_Effect) ~= "function" then
        return false
    end

    if Fix.rendererWrapper then
        Events.OnPlayerUpdate.Remove(Fix.rendererWrapper)
    end
    if Fix.rendererOriginal then
        Events.OnPlayerUpdate.Remove(Fix.rendererOriginal)
    end

    local current = AWCWF_Attach.Apply_Effect
    if current ~= Fix.rendererWrapper then
        Fix.rendererOriginal = current
    end

    Events.OnPlayerUpdate.Remove(Fix.rendererOriginal)
    Fix.rendererWrapper = rendererUpdate
    Events.OnPlayerUpdate.Remove(Fix.rendererWrapper)
    Events.OnPlayerUpdate.Add(Fix.rendererWrapper)
    return true
end

local function heartbeatUpdateTickReach(self)
    if not self or not self.character then
        return
    end

    self.ZombieList = {}
    local playerX = self.character:getX()
    local playerY = self.character:getY()
    local zombies = getCell():getZombieList()
    if not zombies then
        return
    end

    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie then
            local zombieX = zombie:getX()
            local zombieY = zombie:getY()
            local dx = playerX - zombieX
            local dy = playerY - zombieY
            local distanceSquared = dx * dx + dy * dy
            if distanceSquared < 2500 then
                self.ZombieList[zombie] = {
                    x = zombieX,
                    y = zombieY,
                    z = zombie:getZ(),
                    distance = math.sqrt(distanceSquared),
                    canSeePlayer = zombie:isTargetLocationKnown()
                }
            end
        end
    end
end

local function installHeartbeatOptimization()
    if type(HeartbeatSensor) ~= "table"
        or type(HeartbeatSensor.updateTickReach) ~= "function" then
        return false
    end

    local current = HeartbeatSensor.updateTickReach
    if current ~= Fix.heartbeatWrapper then
        Fix.heartbeatOriginal = current
    end

    Fix.heartbeatWrapper = heartbeatUpdateTickReach
    HeartbeatSensor.updateTickReach = Fix.heartbeatWrapper
    return true
end

local function hasRegisteredShieldItem()
    if type(ShieldFunction) ~= "table"
        or type(ShieldFunction.ShieldItem) ~= "table"
        or not ScriptManager
        or not ScriptManager.instance then
        return nil
    end

    local checked = false
    for fullType in pairs(ShieldFunction.ShieldItem) do
        checked = true
        local ok, scriptItem = pcall(function()
            return ScriptManager.instance:getItem(fullType)
        end)
        if not ok then
            return nil
        end
        if scriptItem then
            return true
        end
    end

    if not checked then
        return nil
    end
    return false
end

local function configureShieldUpdater()
    if type(ShieldFunction) ~= "table"
        or type(ShieldFunction.LocaltionSetFunction) ~= "function" then
        return "unavailable"
    end

    Fix.shieldUpdateCallback = ShieldFunction.LocaltionSetFunction
    local registered = hasRegisteredShieldItem()
    if registered == nil then
        return "unchecked"
    end

    Events.OnPlayerUpdate.Remove(Fix.shieldUpdateCallback)
    if registered then
        Events.OnPlayerUpdate.Add(Fix.shieldUpdateCallback)
        Fix.shieldUpdaterDisabled = false
        return "active"
    end

    Fix.shieldUpdaterDisabled = true
    return "disabled-no-items"
end

local function clearTransientCaches()
    Fix.rendererCache = setmetatable({}, { __mode = "k" })
end

local function installAll(writeStatusLog)
    local rendererInstalled = installRendererOptimization()
    local heartbeatInstalled = installHeartbeatOptimization()
    local shieldStatus = configureShieldUpdater()

    if writeStatusLog then
        logOnce("installed", "version " .. Fix.VERSION
            .. " loaded; ShowMagazine=" .. tostring(Fix.showMagazineOverride == Fix.VERSION)
            .. ", renderer=" .. tostring(rendererInstalled)
            .. ", heartbeat=" .. tostring(heartbeatInstalled)
            .. ", grenade=" .. tostring(Fix.grenadeOverride == Fix.VERSION)
            .. ", shield=" .. shieldStatus
            .. "; no gun, ammo, chamber, inventory, or save data is replaced")
    end
end

if Fix.onGameStart then
    Events.OnGameStart.Remove(Fix.onGameStart)
end
if Fix.onDisconnect then
    Events.OnDisconnect.Remove(Fix.onDisconnect)
end
if Fix.onMainMenuEnter then
    Events.OnMainMenuEnter.Remove(Fix.onMainMenuEnter)
end

Fix.onGameStart = function()
    installAll(true)
end
Fix.onDisconnect = clearTransientCaches
Fix.onMainMenuEnter = clearTransientCaches

Events.OnGameStart.Add(Fix.onGameStart)
Events.OnDisconnect.Add(Fix.onDisconnect)
Events.OnMainMenuEnter.Add(Fix.onMainMenuEnter)

-- The MFS client files have already loaded because this mod is ordered after
-- ModernFirearmsSystem. Installing here prevents even the first game update
-- from using the unthrottled callbacks; OnGameStart safely verifies again.
installAll(false)

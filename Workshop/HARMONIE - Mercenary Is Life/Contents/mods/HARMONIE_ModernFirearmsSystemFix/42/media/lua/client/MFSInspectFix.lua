MFSInspectFix = MFSInspectFix or {}

local Fix = MFSInspectFix

Fix.VERSION = "1.3.0"
Fix.DEFAULT_X = 100
Fix.DEFAULT_Y = 100
Fix.MIN_VISIBLE_WIDTH = 200
Fix.MIN_VISIBLE_HEIGHT = 80

local function log(message)
    print("[MFSInspectFix] " .. tostring(message))
end

local function isUsableNumber(value)
    return type(value) == "number" and value == value and math.abs(value) < 1000000
end

local function clamp(value, minimum, maximum)
    if maximum < minimum then
        return minimum
    end
    return math.max(minimum, math.min(value, maximum))
end

function Fix.ensurePosition(player)
    if not player then
        return Fix.DEFAULT_X, Fix.DEFAULT_Y
    end

    local modData = player:getModData()
    if not modData then
        return Fix.DEFAULT_X, Fix.DEFAULT_Y
    end

    local position = modData.inspectWindowPos
    local x = nil
    local y = nil

    if type(position) == "table" then
        x = tonumber(position[1])
        y = tonumber(position[2])
    end

    if not isUsableNumber(x) then
        x = Fix.DEFAULT_X
    end
    if not isUsableNumber(y) then
        y = Fix.DEFAULT_Y
    end

    local core = getCore and getCore() or nil
    if core then
        x = clamp(x, 0, math.max(0, core:getScreenWidth() - Fix.MIN_VISIBLE_WIDTH))
        y = clamp(y, 0, math.max(0, core:getScreenHeight() - Fix.MIN_VISIBLE_HEIGHT))
    end

    modData.inspectWindowPos = { x, y }
    return x, y
end

function Fix.rememberPosition(window, player)
    if not window or not player then
        return
    end

    local ok, x, y = pcall(function()
        return window:getX(), window:getY()
    end)
    if not ok or not isUsableNumber(x) or not isUsableNumber(y) then
        return
    end

    local modData = player:getModData()
    if modData then
        modData.inspectWindowPos = { math.floor(x), math.floor(y) }
    end
end

function Fix.isInspectableWeapon(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then
        return false
    end
    return weapon:IsWeapon() and weapon:isRanged()
end

function Fix.getInspectableWeapon(player, expectedWeaponId)
    if not player then
        return nil
    end

    local weapon = player:getPrimaryHandItem()
    if not Fix.isInspectableWeapon(weapon) then
        return nil
    end

    if expectedWeaponId and weapon:getID() ~= expectedWeaponId then
        return nil
    end

    return weapon
end

function Fix.isWindowVisible(window)
    if not window then
        return false
    end

    local ok, visible = pcall(function()
        return window:getIsVisible()
    end)
    return ok and visible == true
end

function Fix.removeWindow(window)
    if not window then
        return
    end

    local player = getPlayer and getPlayer() or nil
    Fix.rememberPosition(window, player)

    pcall(function()
        window:setVisible(false)
    end)
    pcall(function()
        window:removeFromUIManager()
    end)

    if riskyInspectWindow == window then
        riskyInspectWindow = nil
    end
end

function Fix.closeCurrentWindow()
    local window = riskyInspectWindow
    if not window then
        return
    end

    local closed = pcall(function()
        window:close()
    end)
    if not closed then
        Fix.removeWindow(window)
    end

    if riskyInspectWindow == window then
        Fix.removeWindow(window)
    end
end

function Fix.clampWindowToScreen(window)
    if not window then
        return
    end

    local core = getCore and getCore() or nil
    if not core then
        return
    end

    pcall(function()
        local width = math.max(Fix.MIN_VISIBLE_WIDTH, window:getWidth())
        local height = math.max(Fix.MIN_VISIBLE_HEIGHT, window:getHeight())
        local x = clamp(window:getX(), 0, math.max(0, core:getScreenWidth() - width))
        local y = clamp(window:getY(), 0, math.max(0, core:getScreenHeight() - height))
        window:setX(x)
        window:setY(y)
    end)
end

function Fix.open(player, expectedWeaponId)
    player = player or (getPlayer and getPlayer() or nil)
    local weapon = Fix.getInspectableWeapon(player, expectedWeaponId)
    if not weapon then
        return false
    end

    if not riskyUI or not riskyUI.new then
        log("riskyUI is unavailable; inspection was cancelled")
        return false
    end

    if riskyInspectWindow then
        Fix.closeCurrentWindow()
    end

    local x, y = Fix.ensurePosition(player)
    local created, windowOrError = pcall(function()
        return riskyUI:new(x, y, 0, 0)
    end)

    if not created or not windowOrError then
        log("failed to create inspection window: " .. tostring(windowOrError))
        return false
    end

    local window = windowOrError
    riskyInspectWindow = window

    local rendered, renderError = pcall(function()
        window:addToUIManager()
        window.resizable = false
        window.collapsable = false
        window:renderInventory()
        Fix.clampWindowToScreen(window)
        window:bringToTop()
    end)

    if not rendered then
        log("failed to render inspection window: " .. tostring(renderError))
        Fix.removeWindow(window)
        return false
    end

    return true
end

function Fix.getInspectKey()
    local configuredKey = nil

    pcall(function()
        if PZAPI and PZAPI.ModOptions then
            local options = PZAPI.ModOptions:getOptions("AWCWF_42_Patch")
            local option = options and options:getOption("keybind_inspect_window") or nil
            if option then
                configuredKey = tonumber(option:getValue())
            end
        end
    end)

    if configuredKey then
        return configuredKey
    end

    local core = getCore and getCore() or nil
    return core and core:getKey("OpenWindownCat") or nil
end

function Fix.inspectOnKey(keyPressed)
    local inspectKey = Fix.getInspectKey()
    if not inspectKey or keyPressed ~= inspectKey then
        return
    end

    if Fix.isWindowVisible(riskyInspectWindow) then
        Fix.closeCurrentWindow()
        return
    end

    Fix.open(getPlayer and getPlayer() or nil)
end

function Fix.patchRiskyUI()
    if not riskyUI then
        return false
    end

    if riskyUI.__MFSInspectFixPatched then
        riskyUI.inspectOnKey = Fix.inspectOnKey
        return true
    end

    local originalClose = riskyUI.close
    local originalUpdate = riskyUI.update

    function riskyUI:close()
        local player = getPlayer and getPlayer() or nil
        Fix.rememberPosition(self, player)

        if originalClose then
            pcall(originalClose, self)
        else
            pcall(function()
                self:setVisible(false)
            end)
        end

        pcall(function()
            self:removeFromUIManager()
        end)

        if riskyInspectWindow == self then
            riskyInspectWindow = nil
        end
    end

    function riskyUI:update()
        if Fix.isWindowVisible(self) then
            local player = getPlayer and getPlayer() or nil
            local weapon = Fix.getInspectableWeapon(player)

            if not weapon or self.currentPrimaryItem ~= weapon then
                self:close()
                return
            end
        end

        if originalUpdate then
            local ok, result = pcall(originalUpdate, self)
            if not ok then
                log("inspection window update failed: " .. tostring(result))
                self:close()
                return
            end
            return result
        end
    end

    riskyUI.inspectOnKey = Fix.inspectOnKey
    riskyUI.__MFSInspectFixPatched = true
    return true
end

function Fix.patchInspectAction()
    if not riskyInspectAction then
        return false
    end

    if riskyInspectAction.__MFSInspectFixPatched then
        return true
    end

    function riskyInspectAction:isValid()
        local player = self.character or (getPlayer and getPlayer() or nil)
        return Fix.getInspectableWeapon(player) ~= nil
    end

    function riskyInspectAction:perform()
        local player = self.character or (getPlayer and getPlayer() or nil)
        Fix.open(player)
        ISBaseTimedAction.perform(self)
    end

    riskyInspectAction.__MFSInspectFixPatched = true
    return true
end

function Fix.install()
    local uiPatched = Fix.patchRiskyUI()
    local actionPatched = Fix.patchInspectAction()

    local player = getPlayer and getPlayer() or nil
    if player then
        Fix.ensurePosition(player)
    end

    if uiPatched and actionPatched and not Fix._installLogged then
        Fix._installLogged = true
        log("version " .. Fix.VERSION .. " installed")
    end
end

function Fix.onCreatePlayer(_, player)
    Fix.ensurePosition(player)
    Fix.install()
end

Fix.install()

if not Fix._eventsRegistered then
    Events.OnGameStart.Add(Fix.install)
    Events.OnCreatePlayer.Add(Fix.onCreatePlayer)
    Fix._eventsRegistered = true
end

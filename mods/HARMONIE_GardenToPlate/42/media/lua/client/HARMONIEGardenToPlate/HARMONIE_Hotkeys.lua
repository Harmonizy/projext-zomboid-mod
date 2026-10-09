--[[
    HARMONIE - From Garden to Plate
    Two ways to open the Nutrition Assessment / Admin Panel, matching how
    Extensive Health Rework B42 (Workshop 3726328119) splits singleplayer
    vs multiplayer targeting:

    1. Hotkeys (HARMONIE_KeybindManager.lua), rebindable under Options ->
       Mods -> HARMONIE: Garden to Plate. This is the ONLY reliable path in
       singleplayer -- right-clicking a player character does not feed an
       IsoPlayer into Events.OnFillWorldObjectContextMenu at all here.
    2. A world-context-menu entry, but only in real multiplayer
       (isClient() true), following EHR_MPExamination.lua's approach:
       scan `worldobjects` for IsoPlayer, then ALSO fall back to
       getOnlinePlayers() within range, because (their comment, confirmed
       true in testing here too) "B42 sometimes does not include the
       remote IsoPlayer in worldObjects on clients".
]]--

require "HARMONIEGardenToPlate/HARMONIE_KeybindManager"
require "HARMONIEGardenToPlate/HARMONIE_NutritionUI"
require "HARMONIEGardenToPlate/HARMONIE_AdminPanel"
require "HARMONIEGardenToPlate/HARMONIE_VitaminGuide"

HARMONIE_GTP = HARMONIE_GTP or {}

local NEARBY_TILE_RANGE = 3

--[[
    Picks who the action should apply to: the closest other player within
    NEARBY_TILE_RANGE tiles if one exists, otherwise the acting player
    themselves. In singleplayer this is always the acting player, since
    IsoPlayer.getPlayers() only ever contains one entry.
]]--
local function findNearestOtherPlayer(playerObj)
    local players = IsoPlayer.getPlayers()
    local nearest, nearestDist

    for i = 0, players:size() - 1 do
        local other = players:get(i)
        if other and other ~= playerObj and not other:isDead() then
            local dist = math.abs(playerObj:getX() - other:getX()) + math.abs(playerObj:getY() - other:getY())
            if not nearestDist or dist < nearestDist then
                nearest, nearestDist = other, dist
            end
        end
    end

    if nearest and nearestDist <= NEARBY_TILE_RANGE then
        return nearest
    end
    return nil
end

-- ============================================
-- HOTKEY PATH (self, or nearest other player)
-- ============================================

-- core:getGameUI() was never a real method (confirmed via Core.class --
-- it doesn't exist at all), so the old version of this always silently
-- returned false via the "not core.getGameUI" guard -- meaning the
-- hotkey below could fire while actively typing in chat. ISChat.focused
-- is vanilla's own real, plain boolean flag for this exact question
-- (confirmed via ISChat.lua, used throughout that file for the same
-- "ignore other input while chat is focused" purpose).
local function isChatWindowOpen()
    if GTPGuide and GTPGuide.typing and GTPGuide.typing() then return true end -- typing in the guide's search box
    return ISChat and ISChat.focused or false
end

local function onKeyPressed(key)
    if isChatWindowOpen() then return end
    if not key or key == 0 then return end -- an unbound action is key 0

    local playerObj = getSpecificPlayer(0)
    if not playerObj or playerObj:isDead() then return end

    if key == HARMONIE_GTP.Keybinds.GetKey(HARMONIE_GTP.Keybinds.IDs.ASSESS_NUTRITION) then
        local target = findNearestOtherPlayer(playerObj) or playerObj
        HARMONIE_NutritionUI.Open(target, playerObj)
    elseif key == HARMONIE_GTP.Keybinds.GetKey(HARMONIE_GTP.Keybinds.IDs.OPEN_GUIDE) then
        if HARMONIE_GTP.Log then HARMONIE_GTP.Log("Keys", "open-guide key (%s) pressed", tostring(key)) end
        GTPGuide.toggle(playerObj)
    elseif key == HARMONIE_GTP.Keybinds.GetKey(HARMONIE_GTP.Keybinds.IDs.OPEN_ADMIN_PANEL) then
        if isAdmin() or getDebug() then
            local target = findNearestOtherPlayer(playerObj) or playerObj
            HARMONIE_AdminPanel.Open(target)
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)

-- ============================================
-- MULTIPLAYER-ONLY RIGHT-CLICK PATH
-- ============================================

local function getContextPlayerCandidates(localPlayer, worldobjects)
    local candidates, seen = {}, {}

    local function addCandidate(p)
        if not p or p == localPlayer or seen[p] then return end
        seen[p] = true
        table.insert(candidates, p)
    end

    if worldobjects then
        for _, obj in ipairs(worldobjects) do
            if obj and instanceof(obj, "IsoPlayer") then
                addCandidate(obj)
            end
        end
    end

    -- B42 doesn't reliably put the remote IsoPlayer into `worldobjects` on
    -- clients, so also offer any other online player within range.
    if getOnlinePlayers then
        local ok, online = pcall(getOnlinePlayers)
        if ok and online then
            for i = 0, online:size() - 1 do
                local p = online:get(i)
                if p and p ~= localPlayer and not p:isDead() then
                    local dist = math.abs(localPlayer:getX() - p:getX()) + math.abs(localPlayer:getY() - p:getY())
                    if dist <= NEARBY_TILE_RANGE then
                        addCandidate(p)
                    end
                end
            end
        end
    end

    return candidates
end

local function onFillWorldObjectContextMenu(playerIndex, context, worldobjects, _test)
    if not isClient() then return end -- singleplayer uses the hotkey instead

    local playerObj = getSpecificPlayer(playerIndex)
    if not playerObj then return end

    for _, target in ipairs(getContextPlayerCandidates(playerObj, worldobjects)) do
        local optionText = getText("IGUI_HARMONIE_AssessOther", target:getDisplayName())
        -- ISContextMenu:addOption(name, X, onSelect, ...args) invokes
        -- onSelect(X, ...args) (confirmed in ISContextMenu.lua's
        -- option.onSelect(option.target, option.param1, ...) call) -- so
        -- the SECOND positional arg here becomes Open's first parameter.
        -- HARMONIE_NutritionUI.Open(target, assessor) needs `target` (the
        -- other player) first and `playerObj` (the local assessor)
        -- second, so that order goes here, not the other way around.
        local option = context:addOption(optionText, target, HARMONIE_NutritionUI.Open, playerObj)

        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip:setName(optionText)
        -- description only appears once the assessor can actually read the
        -- result -- otherwise it explains why not, same idea as EHR's
        -- "Too Far Away" vs normal description switch on its Examine Health option
        -- 0.13.2: never locked; it says how much this assessor will see
        -- (the one rule every vitamin window uses, HARMONIE_GTP.VitaminView)
        local view = HARMONIE_GTP.VitaminView(playerObj)
        local n2, n5 = HARMONIE_GTP.VitaminViewLevels()
        if HARMONIE_GTP.LogOnce then HARMONIE_GTP.LogOnce("assessview:" .. view, "Assess", "assess option offered; the assessor will see: %s", view) end
        tooltip.description = getText("IGUI_HARMONIE_AssessOtherDesc") .. " <LINE> " ..
            getText("IGUI_HARMONIE_AssessView_" .. view, n2, n5)
        option.toolTip = tooltip
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

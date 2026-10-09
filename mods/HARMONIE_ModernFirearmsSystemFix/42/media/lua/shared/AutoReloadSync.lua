-- ============================================================================
-- 自动装弹机构 (auto-loading device) shared module — loaded on BOTH client and
-- server.
--
-- The device is a worn bag (Base.cat_AutoReload) that continuously feeds loose
-- bullets into compatible magazines kept inside it. The bullet -> magazine
-- transfer is performed authoritatively on the SERVER (see
-- AutoReloadSyncServer.lua) so the ammo changes replicate correctly in
-- multiplayer; the client only plays the loading sound when the server reports
-- a transfer (see AutoReloadMagazineBag.lua).
-- ============================================================================

AutoReloadSync = AutoReloadSync or {}

AutoReloadSync.MODULE = "AutoReloadSync"
AutoReloadSync.CMD_LOADED = "Loaded"    -- server -> client: play the insert sound

-- Full types of the worn auto-loading bag (equipped on the left middle finger).
AutoReloadSync.BagTypes = {
    "Base.cat_AutoReload",
}

function AutoReloadSync.IsAutoReloadBag(item)
    if not item or type(item.getModule) ~= "function" or type(item.getType) ~= "function" then
        return false
    end
    local fullType = item:getModule() .. "." .. item:getType()
    for _, t in ipairs(AutoReloadSync.BagTypes) do
        if fullType == t then
            return true
        end
    end
    return false
end

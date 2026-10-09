MFSDataIntegrityFix = MFSDataIntegrityFix or {}

local Fix = MFSDataIntegrityFix

Fix.VERSION = "1.3.0"

local function log(message)
    print("[MFSDataIntegrityFix] " .. tostring(message))
end

local itemPatches = {
    {
        fullType = "Base.68Clip",
        parameter = "AmmoType = base:bullets_38"
    },
    {
        fullType = "Base.M7_cat",
        parameter = "AmmoType = base:bullets_38"
    }
}

function Fix.apply()
    if not ScriptManager or not ScriptManager.instance then
        return false
    end

    local applied = 0
    for _, patch in ipairs(itemPatches) do
        local item = ScriptManager.instance:getItem(patch.fullType)
        if item then
            local ok, err = pcall(function()
                item:DoParam(patch.parameter)
            end)
            if ok then
                applied = applied + 1
            else
                log("failed to patch " .. patch.fullType .. ": " .. tostring(err))
            end
        else
            log("script item not found: " .. patch.fullType)
        end
    end

    if applied == #itemPatches and not Fix._appliedLogged then
        Fix._appliedLogged = true
        log("version " .. Fix.VERSION .. " corrected M7/68Clip AmmoType")
    end
    return applied == #itemPatches
end

Fix.apply()

if not Fix._eventsRegistered then
    Events.OnInitGlobalModData.Add(Fix.apply)
    Fix._eventsRegistered = true
end

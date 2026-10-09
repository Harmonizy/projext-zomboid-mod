MFSPartSafetyFix = MFSPartSafetyFix or {}

local Fix = MFSPartSafetyFix

Fix.VERSION = "1.3.0"

local function log(message)
    print("[MFSPartSafetyFix] " .. tostring(message))
end

local function patchInfoList(list)
    local changed = false
    if type(list) ~= "table" then
        return changed
    end

    for _, info in ipairs(list) do
        if type(info) == "table" and info.type == "RecoilPad" then
            info.type = "Recoilpad"
            changed = true
        end
    end
    return changed
end

local function patchPartList(list)
    local changed = false
    if type(list) ~= "table" then
        return changed
    end

    for index, partType in ipairs(list) do
        if partType == "RecoilPad" then
            list[index] = "Recoilpad"
            changed = true
        end
    end
    return changed
end

function Fix.install()
    local changed = false
    changed = patchInfoList(attachmentInfo) or changed
    changed = patchInfoList(attachmentButtonsInfo) or changed

    if AWCWF_AdditionalParts then
        changed = patchPartList(AWCWF_AdditionalParts.partlist) or changed
    end

    if changed and not Fix._installLogged then
        Fix._installLogged = true
        log("version " .. Fix.VERSION .. " corrected Recoilpad UI slot")
    end
    return changed or Fix._installLogged == true
end

Fix.install()
Events.OnGameStart.Add(Fix.install)

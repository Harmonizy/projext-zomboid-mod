-- Requires I SEE THEM 3.6.36 or newer. Remove this file and restart to disable.
local started = false
local function enable()
    if started then return end
    if not ISTAttributes or not ISTAttributes.configureDiagnostics then
        print("[IST-DIAG] NOT ENABLED: requires I SEE THEM 3.6.36 diagnostic API")
        return
    end
    local ok, err = pcall(function() ISTAttributes.configureDiagnostics(true) end)
    if ok then started = true else print("[IST-DIAG] enable failed: " .. tostring(err)) end
end
Events.OnGameStart.Add(enable)

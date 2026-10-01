--[[
    HARMONIE - Home Medic : translated text with arguments

    PZ's getText formats "%1".."%4" itself (Java String.format with "%1$s"):
    asking for a key whose text holds "%1" WITHOUT passing the arguments logs
    "Missing arguments" and leaves "$s" in the text. So the arguments always
    go to getText; only a missing key falls back to our own substitution.
]]--

-- put the arguments in; also catches "%1$s" left by the Translator
local function fill(t, args)
    for i = 1, #args do
        local v = tostring(args[i])
        t = t:gsub("%%" .. i .. "%$%a", function() return v end)
        t = t:gsub("%%" .. i, function() return v end)
    end
    -- "%%" is a literal percent for Java's formatter; show it as one "%"
    -- when the text did not go through it
    t = t:gsub("%%%%", "%%")
    return t
end

function HM_Text(key, fallback, ...)
    local n = select("#", ...)
    local a = {}
    for i = 1, n do a[i] = tostring((select(i, ...))) end
    local t
    if getText and n <= 4 then
        local ok, r
        if n == 0 then ok, r = pcall(getText, key)
        elseif n == 1 then ok, r = pcall(getText, key, a[1])
        elseif n == 2 then ok, r = pcall(getText, key, a[1], a[2])
        elseif n == 3 then ok, r = pcall(getText, key, a[1], a[2], a[3])
        else ok, r = pcall(getText, key, a[1], a[2], a[3], a[4]) end
        if ok then t = r end
    end
    if not t or t == key or t == "?" or t == "" then return fill(fallback or key, a) end
    return fill(t, a)
end

return HM_Text

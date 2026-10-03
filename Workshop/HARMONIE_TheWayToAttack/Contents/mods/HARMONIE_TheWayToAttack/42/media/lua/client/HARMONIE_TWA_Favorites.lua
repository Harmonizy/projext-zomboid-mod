--============================================================================
-- HARMONIE_TheWayToAttack -- favourite recipes (client)
--
-- R68 ("คราฟอาวุธ มีการกด favorite สูตร"): the star on a recipe row in the
-- craft window marks it as a favourite. Favourites come first in the list
-- and have their own filter tab. Kept on this computer only (a small text
-- file in Zomboid/Lua, one recipe id per line) -- nothing goes to a server.
--============================================================================

TWAFavorites = TWAFavorites or {}
local F = TWAFavorites
F.FILE = "HARMONIE_TWA_Favorites.txt"

function F.load()
    F.set = {}
    if not getFileReader then return end
    local ok, reader = pcall(getFileReader, F.FILE, true)
    if not ok or not reader then return end
    pcall(function()
        local line = reader:readLine()
        while line do
            line = line:gsub("^%s+", ""):gsub("%s+$", "")
            if line ~= "" then F.set[line] = true end
            line = reader:readLine()
        end
    end)
    pcall(function() reader:close() end)
end

function F.save()
    if not getFileWriter then return end
    local ok, writer = pcall(getFileWriter, F.FILE, true, false)
    if not ok or not writer then return end
    pcall(function()
        for id in pairs(F.set or {}) do writer:write(id .. "\n") end
    end)
    pcall(function() writer:close() end)
end

function F.isFav(id)
    if not F.set then F.load() end
    return id ~= nil and F.set[id] == true
end

function F.toggle(id)
    if not id then return false end
    if not F.set then F.load() end
    F.set[id] = (not F.set[id]) and true or nil
    F.save()
    return F.set[id] == true
end

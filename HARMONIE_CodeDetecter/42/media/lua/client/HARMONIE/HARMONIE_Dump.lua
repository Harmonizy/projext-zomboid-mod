--[[
    HARMONIE - Code Detecter

    Debug/diagnostic tool. Dumps the current save/server's loaded mods, all
    item definitions, all crafting recipes, and sandbox settings to plain
    text log files so they can be handed to an outside tool (an AI assistant,
    a spreadsheet, grep, whatever) for analysis. Changes nothing about
    gameplay - read-only, manual trigger only.

    Run from the debug console (F11 / Lua console):
        HARMONIE.DumpAll()
    or run one section at a time:
        HARMONIE.DumpMods()
        HARMONIE.DumpItems()
        HARMONIE.DumpRecipes()
        HARMONIE.DumpSandbox()

    Output files land in: Zomboid\Lua\HARMONIE_*.log
    (that's where getFileWriter() always writes, same folder used for
    layout.ini / ModOptions.ini / etc.)
]]--

HARMONIE = HARMONIE or {}

local function safe(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function writeLine(writer, text)
    writer:write(tostring(text) .. "\r\n")
end

-- ============================================
-- MODS
-- ============================================
function HARMONIE.DumpMods()
    local writer = getFileWriter("HARMONIE_Mods.log", true, false)
    writeLine(writer, "# HARMONIE Mods Dump")
    writeLine(writer, "# Columns: ModID | Name | Version | WorkshopID | Require | Incompatible")

    local activated = getActivatedMods()
    local count = 0
    for i = 0, activated:size() - 1 do
        local modID = activated:get(i)
        local modInfo = safe(getModInfoByID, modID)
        if modInfo then
            local name = safe(function() return modInfo:getName() end) or modID
            local version = safe(function() return modInfo:getModVersion() end) or ""
            local workshopID = safe(function() return modInfo:getWorkshopID() end) or ""
            local require = safe(function() return modInfo:getRequire() end)
            local incompatible = safe(function() return modInfo:getIncompatible() end)
            writeLine(writer, string.format(
                "%s | %s | %s | %s | %s | %s",
                modID, name, tostring(version), tostring(workshopID),
                tostring(require), tostring(incompatible)
            ))
        else
            writeLine(writer, modID .. " | [modInfo not found]")
        end
        count = count + 1
    end

    writeLine(writer, "# Total mods: " .. count)
    writer:close()
    print("HARMONIE: wrote " .. count .. " mods to HARMONIE_Mods.log")
end

-- ============================================
-- ITEMS
-- ============================================
function HARMONIE.DumpItems()
    local writer = getFileWriter("HARMONIE_Items.log", true, false)
    writeLine(writer, "# HARMONIE Items Dump")
    writeLine(writer, "# Columns: FullType | DisplayName | DisplayCategory | Weight | ItemType | Obsolete")

    local allItems = getAllItems()
    local count = 0
    for item in iterList(allItems) do
        local fullName = safe(function() return item:getFullName() end)
        if fullName then
            local displayName = safe(function() return item:getDisplayName() end) or ""
            local category = safe(function() return item:getDisplayCategory() end) or ""
            local weight = safe(function() return item:getActualWeight() end)
                or safe(function() return item:getWeight() end) or ""
            local itemType = safe(function() return item:getType() end) or ""
            local obsolete = safe(function() return item:getObsolete() end)
            writeLine(writer, string.format(
                "%s | %s | %s | %s | %s | %s",
                fullName, displayName, category, tostring(weight), itemType, tostring(obsolete)
            ))
            count = count + 1
        end
    end

    writeLine(writer, "# Total items: " .. count)
    writer:close()
    print("HARMONIE: wrote " .. count .. " items to HARMONIE_Items.log")
end

-- ============================================
-- RECIPES
-- ============================================
function HARMONIE.DumpRecipes()
    local writer = getFileWriter("HARMONIE_Recipes.log", true, false)
    writeLine(writer, "# HARMONIE Recipes Dump")
    writeLine(writer, "# Columns: Module.Name | ResultFullType | ResultCount | TimeToMake | RequiredNearObject | Sources")

    local recipes = getAllRecipes()
    local count = 0
    for i = 1, recipes:size() do
        local recipe = recipes:get(i - 1)

        local originalName = safe(function() return recipe:getOriginalname() end) or ("recipe_" .. i)
        local moduleName = safe(function() return recipe:getModule():getName() end) or "?"
        local fullName = moduleName .. "." .. originalName

        local resultType, resultCount = "", ""
        local result = safe(function() return recipe:getResult() end)
        if result then
            resultType = safe(function() return result:getFullType() end) or ""
            resultCount = safe(function() return result:getCount() end) or ""
        end

        local timeToMake = safe(function() return recipe:getTimeToMake() end) or ""
        local requiredNear = safe(function() return recipe:getRequiredNearObject() end) or ""

        -- Sources: each source slot may accept several alternative item types
        local sourceParts = {}
        local sources = safe(function() return recipe:getSource() end)
        if sources then
            for j = 1, sources:size() do
                local source = sources:get(j - 1)
                local isKeep = safe(function() return source:isKeep() end)
                local itemTypes = safe(function() return source:getItems() end)
                local typeList = {}
                if itemTypes then
                    for k = 1, itemTypes:size() do
                        table.insert(typeList, tostring(itemTypes:get(k - 1)))
                    end
                end
                local slotText = table.concat(typeList, "/")
                if isKeep then slotText = slotText .. "[keep]" end
                table.insert(sourceParts, slotText)
            end
        end

        writeLine(writer, string.format(
            "%s | %s | %s | %s | %s | %s",
            fullName, resultType, tostring(resultCount), tostring(timeToMake),
            requiredNear, table.concat(sourceParts, "; ")
        ))
        count = count + 1
    end

    writeLine(writer, "# Total recipes: " .. count)
    writer:close()
    print("HARMONIE: wrote " .. count .. " recipes to HARMONIE_Recipes.log")
end

-- ============================================
-- SANDBOX SETTINGS
-- ============================================
local function dumpSandboxTable(writer, tbl, prefix, seen)
    seen = seen or {}
    if seen[tbl] then return end
    seen[tbl] = true

    -- Sort keys for stable, readable output
    local keys = {}
    for k in pairs(tbl) do table.insert(keys, tostring(k)) end
    table.sort(keys)

    for _, k in ipairs(keys) do
        local v = tbl[k]
        local path = (prefix == "" and k) or (prefix .. "." .. k)
        if type(v) == "table" then
            dumpSandboxTable(writer, v, path, seen)
        else
            writeLine(writer, path .. " = " .. tostring(v))
        end
    end
end

function HARMONIE.DumpSandbox()
    local writer = getFileWriter("HARMONIE_Sandbox.log", true, false)
    writeLine(writer, "# HARMONIE Sandbox Settings Dump")

    if SandboxVars then
        dumpSandboxTable(writer, SandboxVars, "")
    else
        writeLine(writer, "# SandboxVars not available in this context")
    end

    writer:close()
    print("HARMONIE: wrote sandbox settings to HARMONIE_Sandbox.log")
end

-- ============================================
-- RUN EVERYTHING
-- ============================================
function HARMONIE.DumpAll()
    print("HARMONIE: starting full dump...")
    HARMONIE.DumpMods()
    HARMONIE.DumpItems()
    HARMONIE.DumpRecipes()
    HARMONIE.DumpSandbox()
    print("HARMONIE: full dump complete. Files are in Zomboid\\Lua\\HARMONIE_*.log")
end

print("HARMONIE Code Detecter loaded. Run HARMONIE.DumpAll() from the debug console.")

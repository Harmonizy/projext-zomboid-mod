--[[
    Request 2026-10-03 (R67): "คลิกขวา Inspect weapon ม็อด ModernFirearm
    ให้กดได้เฉพาะอาวุธปืน" -- ModernFirearmsSystem puts its "Inspect"
    (weapon inspection window) option on the right-click menu of every
    weapon, melee ones included. This takes it off again unless the item
    is a firearm (a HandWeapon whose isRanged() is true).

    How: one more OnFillInventoryObjectContextMenu handler, added at
    OnGameStart so it runs AFTER the one ModernFirearmsSystem added when its
    files loaded (handlers run in the order they were added). It removes
    every top-level option whose label contains "inspect" (any case; the
    Thai and Chinese wordings too) when the clicked item is a weapon that
    is not ranged. Nothing else on the menu is touched, and guns keep the
    option as before. Client only; nothing is sent anywhere.
]]--

HARMONIE_MFSFix = HARMONIE_MFSFix or {}
local M = HARMONIE_MFSFix

M.INSPECT_WORDS = { "inspect", "ตรวจสอบอาวุธ", "检视", "检查武器" }

local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end

-- the first real item of the right-clicked stack(s)
local function firstItem(items)
    for _, v in ipairs(items or {}) do
        local it = v
        if type(v) == "table" and v.items then it = v.items[1] end
        if it then return it end
    end
    return nil
end

function M.isInspectLabel(name)
    if type(name) ~= "string" then return false end
    local low = string.lower(name)
    for _, w in ipairs(M.INSPECT_WORDS) do
        if string.find(low, w, 1, true) then return true end
    end
    return false
end

-- a weapon that is not a gun
function M.isMeleeWeapon(item)
    if not item then return false end
    if instanceof and not instanceof(item, "HandWeapon") then return false end
    return call(item, "isRanged") ~= true
end

function M.dropInspect(context)
    local opts = context and context.options
    if type(opts) ~= "table" then return 0 end
    local names = {}
    for _, o in ipairs(opts) do
        if o and M.isInspectLabel(o.name) then names[#names + 1] = o.name end
    end
    for _, n in ipairs(names) do
        if context.removeOptionByName then
            context:removeOptionByName(n)
        else
            for i = #opts, 1, -1 do
                if opts[i] and opts[i].name == n then
                    table.remove(opts, i)
                    if context.numOptions then context.numOptions = context.numOptions - 1 end
                end
            end
        end
    end
    return #names
end

function M.onFillInventoryMenu(playerNum, context, items)
    if not M.isMeleeWeapon(firstItem(items)) then return end
    M.dropInspect(context)
end

if Events and Events.OnGameStart and not M.inspectRegistered then
    M.inspectRegistered = true
    Events.OnGameStart.Add(function()
        if M.inspectAdded then return end
        M.inspectAdded = true
        Events.OnFillInventoryObjectContextMenu.Add(M.onFillInventoryMenu)
    end)
end

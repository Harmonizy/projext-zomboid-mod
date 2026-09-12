--[[
    A genuine correctness checker -- not another "did the hook run"
    ping like logAliveOnce in HARMONIE_MA_PerformanceHooks.lua, but a
    read-back check that the live vehicle state actually matches what
    the mod intended. Runs automatically and periodically off the same
    lua { update = ... } mechanism every HARMONIE part already uses
    (vanilla calls this on its own schedule while the part is
    installed and the vehicle is loaded -- no player action needed).

    Warns to console.txt (search "HARMONIE Mechanical Advanced: WARNING")
    the first time a given problem is seen on a given part instance,
    tracked via part:getModData() so it survives save/reload and never
    spams -- and clears that flag again if the problem goes away (e.g.
    after a save-editing fix), so a stale warning can't linger forever.
]]--

if not HARMONIE_MA then HARMONIE_MA = {} end
if not HARMONIE_MA.Update then HARMONIE_MA.Update = {} end

-- Which item(s) are actually allowed to sit in each of our part slots.
-- Anything else showing up here would mean something outside this mod
-- (or a bug in our own item/template definitions) put an unexpected
-- item into one of our slots.
local EXPECTED_ITEM_FOR_PART = {
    HARMONIE_MA_Bullbar = { ["HARMONIEMechanicalAdvanced.Bullbar"] = true },
    HARMONIE_MA_WindowArmorWindshield = { ["HARMONIEMechanicalAdvanced.WindowArmorPlate"] = true },
    HARMONIE_MA_WindowArmorDoorLeft = { ["HARMONIEMechanicalAdvanced.WindowArmorPlate"] = true },
    HARMONIE_MA_WindowArmorDoorRight = { ["HARMONIEMechanicalAdvanced.WindowArmorPlate"] = true },
    HARMONIE_MA_CargoRack = { ["HARMONIEMechanicalAdvanced.CargoRackFrame"] = true },
    HARMONIE_MA_PerfExhaust = {
        ["HARMONIEMechanicalAdvanced.PerformanceExhaustKit"] = true,
        ["HARMONIEMechanicalAdvanced.StealthExhaustKit"] = true,
        ["HARMONIEMechanicalAdvanced.FuelEfficientTuneKit"] = true,
    },
}

function HARMONIE_MA.WarnOnce(part, reason, message)
    local data = part:getModData()
    local key = "HARMONIE_warned_" .. reason
    if not data[key] then
        data[key] = true
        print("HARMONIE Mechanical Advanced: WARNING -- " .. message)
    end
end

function HARMONIE_MA.ClearWarning(part, reason)
    local data = part:getModData()
    data["HARMONIE_warned_" .. reason] = nil
end

--[[
    Shared by every HARMONIE part's own update hook (and by the 3
    parts below that have no functional effect of their own): confirms
    the installed item is genuinely one of ours and that its condition
    is a sane, in-range number. Returns the installed item (or nil if
    the slot is empty) so callers can skip their own checks early.
]]--
function HARMONIE_MA.CheckPartBasics(vehicle, part)
    local item = part:getInventoryItem()
    if not item then return nil end

    local partId = part:getId()
    local expected = EXPECTED_ITEM_FOR_PART[partId]
    local fullType = item:getFullType()
    if expected and not expected[fullType] then
        HARMONIE_MA.WarnOnce(part, "wrongitem", string.format(
            "part %s has an unexpected item installed (%s is not one of our own kits for this slot).",
            partId, tostring(fullType)
        ))
    else
        HARMONIE_MA.ClearWarning(part, "wrongitem")
    end

    local condition = part:getCondition()
    if type(condition) ~= "number" or condition < 0 or condition > 100 then
        HARMONIE_MA.WarnOnce(part, "condition", string.format(
            "part %s has an out-of-range condition value (%s).",
            partId, tostring(condition)
        ))
    else
        HARMONIE_MA.ClearWarning(part, "condition")
    end

    return item
end

--[[
    CargoRack and the 3 WindowArmorPlate slots have no functional lua
    of their own (CargoRack's capacity comes entirely from the item
    script's MaxCapacity field, window armor is passive durability
    only) -- wired as their own lua { update = ... } purely so they
    get the same periodic, self-verifying confirmation the other 2
    parts get inside their own update hooks.
]]--
function HARMONIE_MA.Update.PartsChecker(vehicle, part, elapsedMinutes)
    local item = HARMONIE_MA.CheckPartBasics(vehicle, part)
    if not item then return end

    if part:getId() == "HARMONIE_MA_CargoRack" then
        if item:getMaxCapacity() ~= 30 then
            HARMONIE_MA.WarnOnce(part, "cargocapacity", string.format(
                "CargoRack item's MaxCapacity is %s, expected 30 -- check HARMONIE_MA_items.txt.",
                tostring(item:getMaxCapacity())
            ))
        else
            HARMONIE_MA.ClearWarning(part, "cargocapacity")
        end
    end

    local data = part:getModData()
    if not data.HARMONIE_checkerConfirmed then
        data.HARMONIE_checkerConfirmed = true
        print(string.format(
            "HARMONIE Mechanical Advanced: PartsChecker confirmed %s is installed correctly (item %s, condition %d%%).",
            part:getId(), item:getFullType(), part:getCondition()
        ))
    end
end

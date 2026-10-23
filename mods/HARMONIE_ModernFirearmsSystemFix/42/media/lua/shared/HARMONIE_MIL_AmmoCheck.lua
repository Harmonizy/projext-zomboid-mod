--[[
    HARMONIE - Mercenary Is Life : ammo type check (console.txt)

    Owner, 2026-10-23: the game crashed on the first shot of Requiem_cat:
      NullPointerException: Cannot read field "projectileRed" because
      "isoBulletTracerEffectsConfigOption" is null
      IsoBulletTracerEffects.createEffect <- CombatManager.fireWeapon
    B42 has bullet tracer presets for its ten vanilla ammo types only, and reads
    them from the game's own media/effects (never from a mod folder). A firearm
    with an ammo type of a mod has no preset and crashes the game when it fires.
    MIL's .50 / .338 / 14.5 guns now take 7.62x51, its 5.45 / 5.8 guns 5.56
    (scripts/HARMONIE_MIL_AmmoConvert.txt turns the old rounds into those).

    At game start every firearm of the loaded mods with a non-vanilla ammo type
    is written to console.txt, so the next one is found before it is fired.
]]--

local VANILLA = {
    ["base:bullets_3030"] = true, ["base:bullets_308"] = true, ["base:bullets_357"] = true,
    ["base:bullets_38"] = true, ["base:bullets_44"] = true, ["base:bullets_45"] = true,
    ["base:bullets_556"] = true, ["base:bullets_9mm"] = true, ["base:cap_gun_cap"] = true,
    ["base:shotgun_shells"] = true,
}

local function side()
    if isServer and isServer() then return "server" end
    if isClient and isClient() then return "client" end
    return "SP"
end
local function log(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    print("[HARMONIE_MFSFix][AmmoCheck][" .. side() .. "] " .. (ok and msg or tostring(fmt)))
end

-- the vanilla ammo type objects (the game's own lookup, as Item.Load does)
local function vanillaTypes()
    local set, n = {}, 0
    if not (AmmoType and AmmoType.get and ResourceLocation and ResourceLocation.of) then return nil end
    for key in pairs(VANILLA) do
        local ok, t = pcall(function() return AmmoType.get(ResourceLocation.of(key)) end)
        if ok and t then set[#set + 1] = t; n = n + 1 end
    end
    return n > 0 and set or nil
end

local function check()
    local sm = getScriptManager and getScriptManager()
    if not sm then return end
    local items
    if not pcall(function() items = sm:getAllItems() end) or not items then log("could not list the item scripts -- no check"); return end
    local vt = vanillaTypes()
    if not vt then log("AmmoType.get not available -- no check"); return end
    local guns, risky, list = 0, 0, {}
    -- flow check (2026-10-23): a gun with no shot sound, or whose magazine type
    -- is not an item, still loads -- it only fails when used
    local silent, noMag = {}, {}
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local ranged = false
        pcall(function() ranged = it:isRanged() end)
        if ranged then
            guns = guns + 1
            local t
            pcall(function() t = it:getAmmoType() end)
            local known = false
            for _, v in ipairs(vt) do if t == v then known = true end end
            local name0 = "?"
            pcall(function() name0 = it:getFullName() end)
            local swing, typ, mag
            -- the script Item has no getSwingSound (calling it logs "Object tried
            -- to call nil" even inside pcall -- 0.7.5, once per gun): read it from
            -- a weapon made from the script, and only if the methods exist
            local swingRead = false
            if instanceItem and name0 ~= "?" then
                local w
                pcall(function() w = instanceItem(name0) end)
                if w and w.getSwingSound then
                    swingRead = pcall(function() swing = w:getSwingSound() end)
                end
            end
            if it.getName then pcall(function() typ = it:getName() end) end
            if it.getMagazineType then pcall(function() mag = it:getMagazineType() end) end
            local profiles = AWCWF_GunShotProfiles
            if swingRead and (swing == nil or swing == "") and not (profiles and typ and profiles[typ]) then
                silent[#silent + 1] = name0
            end
            if mag and mag ~= "" and not sm:getItem(mag) then
                noMag[#noMag + 1] = name0 .. " (" .. tostring(mag) .. ")"
            end
            if t and not known then
                local key = "?"
                pcall(function() key = tostring(t) end)
                risky = risky + 1
                local name = "?"
                pcall(function() name = it:getFullName() end)
                list[#list + 1] = name .. " (" .. key .. ")"
            end
        end
    end
    if not instanceItem then
        log("instanceItem not available -- shot sounds not checked")
    elseif #silent > 0 then
        log("%d firearms have no shot sound (empty SwingSound, no shot profile): %s", #silent, table.concat(silent, ", "))
    else
        log("every firearm has a shot sound (SwingSound or a shot profile)")
    end
    if #noMag > 0 then
        log("%d firearms take a magazine that is not an item: %s", #noMag, table.concat(noMag, ", "))
    end
    if risky == 0 then
        log("%d firearms checked: every one uses a vanilla ammo type (no tracer crash)", guns)
    else
        log("%d firearms checked: %d use an ammo type of a mod and may CRASH the game when fired (no bullet tracer preset): %s",
            guns, risky, table.concat(list, ", "))
    end
end

-- An item whose icon texture does not exist has getTex() == nil, and dropping it
-- on the floor throws in IsoWorldInventoryObject.updateSprite (console 2026-10-23,
-- 12x "getTex() is null" from ISInventoryTransferAction). List them once, on a
-- client (a dedicated server has no textures).
local function iconCheck()
    if isServer and isServer() then return end
    if not getTexture then log("getTexture not available -- icons not checked"); return end
    local sm = getScriptManager and getScriptManager()
    local items
    if not sm or not pcall(function() items = sm:getAllItems() end) or not items then return end
    local n, missing = 0, {}
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local icon, name
        if it.getIcon then pcall(function() icon = it:getIcon() end) end
        if icon and icon ~= "" and icon ~= "None" then
            n = n + 1
            local tex
            pcall(function() tex = getTexture("Item_" .. icon) or getTexture(icon) end)
            if not tex then
                pcall(function() name = it:getFullName() end)
                missing[#missing + 1] = tostring(name) .. " (" .. tostring(icon) .. ")"
            end
        end
    end
    if #missing == 0 then
        log("%d item icons checked: all found", n)
    else
        local shown = {}
        for i = 1, math.min(#missing, 80) do shown[i] = missing[i] end
        log("%d item icons checked: %d have no texture (blank icon; dropping one on the floor throws)%s: %s",
            n, #missing, #missing > 80 and " -- first 80" or "", table.concat(shown, ", "))
    end
end

if Events and Events.OnGameStart then Events.OnGameStart.Add(function() pcall(check) end) end
if Events and Events.OnGameStart then Events.OnGameStart.Add(function() pcall(iconCheck) end) end
if Events and Events.OnServerStarted then Events.OnServerStarted.Add(function() pcall(check) end) end

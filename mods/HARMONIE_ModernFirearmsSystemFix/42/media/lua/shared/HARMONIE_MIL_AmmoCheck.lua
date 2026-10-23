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
            local swingRead = pcall(function() swing = it:getSwingSound() end)
            pcall(function() typ = it:getName() end)
            pcall(function() mag = it:getMagazineType() end)
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
    if #silent > 0 then
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

if Events and Events.OnGameStart then Events.OnGameStart.Add(function() pcall(check) end) end
if Events and Events.OnServerStarted then Events.OnServerStarted.Add(function() pcall(check) end) end

--[[
    HARMONIE - Mercenary Is Life: admin tests for every tab of the gun window
    (owner, 2026-11-12, 1.0.0: "ในทุกหน้าต่างและแท็บให้มีปุ่มที่แอดมินสามารถกด
    เพื่อทดสอบอะไรต่างๆได้"). The hub's flask button (000_HARMONIE_AdminTest)
    sits left of the header buttons. Everything runs on the server on the gun
    in the admin's main hand (mil_ammo / mil_parts / mil_condition ops).
]]--

local AT = HARMONIE_AdminTest
if not AT then print("[HARMONIE_MFSFix][AdminTests] no HARMONIE_AdminTest -- no admin tests"); return end

local function log(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print("[HARMONIE_MFSFix][AdminTests] " .. (ok and s or tostring(fmt)))
end
local function call(o, m, ...)
    if not o or type(o[m]) ~= "function" then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end
local function heldGun(p)
    local w = call(p, "getPrimaryHandItem")
    if w and instanceof(w, "HandWeapon") and call(w, "isRanged") then return w end
    return nil
end
local function addTo(p, t, n)
    local inv = p:getInventory()
    for _ = 1, n do
        local it = call(inv, "AddItem", t)
        if it and sendAddItemToContainer then pcall(sendAddItemToContainer, inv, it) end
    end
end

AT.serverOp("mil_ammo", function(p)
    local g = heldGun(p)
    if not g then log("ammo: no gun in hand"); return end
    local at = call(g, "getAmmoType")
    local key = at and call(at, "getItemKey")
    if key then addTo(p, tostring(key), 60) end
    local box = call(g, "getAmmoBox"); if box then addTo(p, tostring(box), 2) end
    local mag = call(g, "getMagazineType"); if mag then addTo(p, tostring(mag), 2) end
    log("ammo for %s: %s, box %s, magazine %s", tostring(call(g, "getFullType")), tostring(key), tostring(box), tostring(mag))
end)

AT.serverOp("mil_parts", function(p)
    local g = heldGun(p)
    if not g then log("parts: no gun in hand"); return end
    local sm = getScriptManager and getScriptManager()
    local all = sm and call(sm, "getAllItems")
    local n, max = 0, 40
    for i = 0, (all and all:size() or 0) - 1 do
        local si = all:get(i)
        local ft = si and call(si, "getFullName")
        local ty = si and (call(si, "getTypeString") or tostring(call(si, "getType") or ""))
        if ft and n < max and tostring(ty):find("WeaponPart") then
            local ok, it = pcall(instanceItem, ft)
            if ok and it and instanceof(it, "WeaponPart") and it.canAttach then
                local okA, fits = pcall(function() return it:canAttach(p, g) end)
                if okA and fits then addTo(p, ft, 1); n = n + 1 end
            end
        end
    end
    log("parts for %s: %d given", tostring(call(g, "getFullType")), n)
end)

AT.serverOp("mil_condition", function(p, args)
    local g = heldGun(p)
    if not g then log("condition: no gun in hand"); return end
    local max = call(g, "getConditionMax") or 10
    local v = args.full and max or math.max(1, math.floor(max * 0.2))
    pcall(function() g:setCondition(v) end)
    if sendItemStats then pcall(sendItemStats, g) end
    if syncHandWeaponFields then pcall(syncHandWeaponFields, p, g) end
    log("%s condition -> %d/%d", tostring(call(g, "getFullType")), v, max)
end)

local function T(id, en, run) return { key = "IGUI_MIL_Test_" .. id, fallback = en, run = run } end
local function needGun(p)
    if heldGun(p) then return true end
    p:Say(AT.T("IGUI_MIL_Test_NoGun", "Hold a gun first."))
    return false
end

AT.register("mfs", "*", {
    T("Guns", "Give test guns (pistol, assault rifle) with ammo", function(p)
        AT.give(p, { { "Base.Pistol", 1 }, { "Base.AssaultRifle", 1 }, { "Base.Bullets9mm", 60 }, { "Base.556Bullets", 60 } })
    end),
    T("Aiming", "Aiming and Reloading to 10", function(p) AT.skill(p, "Aiming", 10); AT.skill(p, "Reloading", 10) end),
})
AT.register("mfs", "inspect", {
    T("Parts", "Give every part that fits the gun in hand", function(p) if needGun(p) then AT.send(p, "mil_parts") end end),
})
AT.register("mfs", "parts", {
    T("Parts", "Give every part that fits the gun in hand", function(p) if needGun(p) then AT.send(p, "mil_parts") end end),
})
AT.register("mfs", "stats", {
    T("Repair", "Repair the gun in hand", function(p) if needGun(p) then AT.send(p, "mil_condition", { full = true }) end end),
    T("Wear", "Wear the gun in hand to 20%", function(p) if needGun(p) then AT.send(p, "mil_condition", { full = false }) end end),
})
AT.register("mfs", "ammo", {
    T("Ammo", "Give ammo, boxes and magazines for the gun in hand", function(p) if needGun(p) then AT.send(p, "mil_ammo") end end),
})
AT.register("mfs", "guide", {})

local function install()
    if not (HMLWorkbench and AT.decorate) then return end
    AT.decorate(HMLWorkbench, {
        mod = "mfs",
        tab = function(win) return win.tab or "guide" end,
        rect = function(win)
            local list = win:headerButtons()
            local last = list[#list]
            return last.x - last.w - 6, last.y, last.w
        end,
    })
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(install) end

--[[
    HARMONIE - Car for Crash: admin tests for every tab of the vehicle window
    (owner, 2026-11-12, 1.0.0: "ในทุกหน้าต่างและแท็บให้มีปุ่มที่แอดมินสามารถกด
    เพื่อทดสอบอะไรต่างๆได้"). The hub's flask button (000_HARMONIE_AdminTest)
    sits left of the header buttons. Vehicle changes run on the server
    (svu_repair / svu_wear ops) on the vehicle the window shows.
]]--

local AT = HARMONIE_AdminTest
if not AT then print("[HARMONIE_SVU3][AdminTests] no HARMONIE_AdminTest -- no admin tests"); return end

local function log(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print("[HARMONIE_SVU3][AdminTests] " .. (ok and s or tostring(fmt)))
end
local function vehicleById(id)
    if id == nil or not getVehicleById then return nil end
    local ok, v = pcall(getVehicleById, tonumber(id))
    return ok and v or nil
end

-- every part of the vehicle to a condition (100 = repaired)
local function setParts(v, cond)
    local n = 0
    for i = 0, v:getPartCount() - 1 do
        local part = v:getPartByIndex(i)
        if part and part.setCondition then
            pcall(function() part:setCondition(cond) end)
            if v.transmitPartCondition then pcall(function() v:transmitPartCondition(part) end) end
            n = n + 1
        end
    end
    return n
end

AT.serverOp("svu_repair", function(player, args)
    local v = vehicleById(args.vid)
    if not v then log("repair: vehicle %s not found", tostring(args.vid)); return end
    local n
    if v.repair then pcall(function() v:repair() end); n = "all (vehicle:repair)" else n = setParts(v, 100) end
    log("vehicle %s repaired: %s parts", tostring(args.vid), tostring(n))
end)
AT.serverOp("svu_wear", function(player, args)
    local v = vehicleById(args.vid)
    if not v then log("wear: vehicle %s not found", tostring(args.vid)); return end
    log("vehicle %s: %d parts set to 30%% condition", tostring(args.vid), setParts(v, 30))
end)

local function T(id, en, run) return { key = "IGUI_HSVU_Test_" .. id, fallback = en, run = run } end
local function vid(ctx, p)
    local v = ctx and ctx.vehicle
    if not v then p:Say(AT.T("IGUI_HSVU_Test_NoVehicle", "Stand next to a vehicle first.")); return nil end
    return v:getId()
end

AT.register("svu", "*", {
    T("Skills", "Mechanics, Metalworking and Electrical to 10", function(p)
        AT.skill(p, "Mechanics", 10); AT.skill(p, "MetalWelding", 10); AT.skill(p, "Electricity", 10)
    end),
    T("Tools", "Give mechanic and welding tools", function(p)
        AT.give(p, { { "Base.Wrench", 1 }, { "Base.Screwdriver", 1 }, { "Base.LugWrench", 1 }, { "Base.Jack", 1 },
            { "Base.BlowTorch", 1 }, { "Base.WeldingMask", 1 }, { "Base.WeldingRods", 5 }, { "Base.SheetMetal", 6 } })
    end),
})
AT.register("svu", "vehicle", {
    T("Repair", "Repair this vehicle completely", function(p, ctx) local id = vid(ctx, p); if id then AT.send(p, "svu_repair", { vid = id }) end end),
    T("Wear", "Wear every part of this vehicle to 30%", function(p, ctx) local id = vid(ctx, p); if id then AT.send(p, "svu_wear", { vid = id }) end end),
})
AT.register("svu", "upgrades", {
    T("Repair", "Repair this vehicle completely", function(p, ctx) local id = vid(ctx, p); if id then AT.send(p, "svu_repair", { vid = id }) end end),
})
AT.register("svu", "tiers", {
    T("Tiers", "Apply the vehicle tiers again (after a sandbox change)", function()
        if HARMONIE_SVU3SkillCap and HARMONIE_SVU3SkillCap.applyTiers then HARMONIE_SVU3SkillCap.applyTiers() end
    end),
})
AT.register("svu", "guide", {})

local function install()
    if not (HSVUWindow and AT.decorate) then return end
    AT.decorate(HSVUWindow, {
        mod = "svu",
        tab = function(win) return win.tab or "vehicle" end,
        ctx = function(win) return { vehicle = win.vehicle } end,
        rect = function(win)
            local list = win:headerButtons()
            local last = list[#list]
            return last.x - last.w - 6, last.y, last.w
        end,
    })
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(install) end

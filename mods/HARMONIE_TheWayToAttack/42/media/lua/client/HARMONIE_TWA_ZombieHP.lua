--============================================================================
-- HARMONIE_TheWayToAttack -- zombie health bars, HP numbers, damage numbers
--
-- Request 2026-10-03: what the "Zombie Health Bars" Workshop mod shows,
-- built into this mod (our own code): over every zombie you can see near
-- you, a health bar and its HP, and the damage of each hit rising from the
-- zombie. Follow-up the same day:
--   * other players near you see your damage numbers too (multiplayer,
--     HARMONIE_TWA_DamageShare.lua relays them through the server)
--   * a critical hit (attacker:isCriticalHit()) pops a bigger number in
--     its own colour with a "!"
--   * Options > Mods > The Way To Attack: on/off for each part, colours,
--     sizes and heights of the bar and the numbers
--   * drawn on OnPreUIDraw: under every window, never over the UI
--   * numbers multiplied by the sandbox DamageDisplayScale (TWADisplay)
--
-- How it works (client):
--   * every SCAN_TICKS ticks: the zombies of the cell within RADIUS tiles,
--     on your floor, on a square you can see, alive
--   * a zombie's "full" HP is the highest health seen on it (the game has
--     no max-health getter); forgotten when it dies
--   * OnHitZombie (your own hits): health before + crit flag, read again
--     on the next tick -> the difference is the damage popup (and is sent
--     to the server to share when that is on)
--============================================================================

require "HARMONIE_TWA_Display"
require "HARMONIE_TWA_Config"

TWAZombieHP = TWAZombieHP or {}
local Z = TWAZombieHP

Z.RADIUS = 15
Z.SCAN_TICKS = 10
Z.HEAD_Z = 0.8          -- above the head (in floors)
Z.DOWN_Z = 0.2          -- lying on the ground
Z.LIFT_PX = 12          -- base gap above that point
Z.HEIGHT_STEP_PX = 3    -- per step of a height option
Z.POPUP_MS = 800
Z.CRIT_MS = 1200
Z.POPUP_RISE = 22

-- choices shared with HARMONIE_TWA_Options (the order = the option index)
Z.COLORS = {
    { key = "Yellow", 1.00, 0.82, 0.25 }, { key = "White", 1, 1, 1 }, { key = "Orange", 1.00, 0.55, 0.15 },
    { key = "Red", 1.00, 0.25, 0.22 }, { key = "Green", 0.40, 1.00, 0.40 }, { key = "Cyan", 0.35, 0.90, 1.00 },
    { key = "Pink", 1.00, 0.45, 0.80 }, { key = "Purple", 0.75, 0.50, 1.00 },
}
Z.BAR_STYLES = { "Health", "Red", "Green", "Blue", "Purple" }
Z.FONTS = { "Small", "Medium", "Large" }

Z.visible = {}          -- zombies to draw (refreshed every scan)
Z.full = {}             -- zombie -> highest health seen (dropped on death / scan)
Z.pending = {}          -- { zombie, before, crit, ticks } waiting for the next tick
Z.popups = {}           -- { zombie | x,y,z, amount, crit, born, slot }

-- ------------------------------------------------------------- options
local function opt(name, default)
    local O = TWAOptions
    local o = O and O[name]
    if o and o.getValue then
        local ok, v = pcall(o.getValue, o)
        if ok and v ~= nil then return v end
    end
    return default
end
local function choice(name, default, n)
    local v = math.floor(tonumber(opt(name, default)) or default)
    if v < 1 or v > n then v = default end
    return v
end
function Z.showBar() return opt("zhpBar", true) == true end
function Z.showText() return opt("zhpText", true) == true end
function Z.showDamage() return opt("zhpDamage", true) == true end
function Z.barLift() return Z.LIFT_PX + (tonumber(opt("zhpHeight", 0)) or 0) * Z.HEIGHT_STEP_PX end
function Z.numberLift() return Z.LIFT_PX + (tonumber(opt("zhpNumHeight", 0)) or 0) * Z.HEIGHT_STEP_PX end
function Z.barSize() return math.floor(tonumber(opt("zhpBarWidth", 44)) or 44), math.floor(tonumber(opt("zhpBarThick", 6)) or 6) end
function Z.barStyle() return Z.BAR_STYLES[choice("zhpBarColor", 1, #Z.BAR_STYLES)] end
local function color(name, default)
    local c = Z.COLORS[choice(name, default, #Z.COLORS)]
    return c[1], c[2], c[3]
end
function Z.numberColor() return color("zhpNumColor", 1) end
function Z.critColor() return color("zhpCritColor", 4) end
function Z.numberFont(crit)
    local i = choice("zhpNumSize", 2, #Z.FONTS)
    if crit then i = i + 1 end   -- a crit is one size up (Large -> Massive)
    local names = { "Small", "Medium", "Large", "Massive" }
    return UIFont[names[math.min(i, 4)]] or UIFont.Medium
end

-- ------------------------------------------------------------- tracking
local function call(o, m, ...)
    if not o or not o[m] then return nil end
    local ok, v = pcall(o[m], o, ...)
    if ok then return v end
    return nil
end

local function down(zed)
    return call(zed, "isProne") == true or call(zed, "isKnockedDown") == true
end

-- remember the highest health seen -> health, full
function Z.track(zed)
    local hp = tonumber(call(zed, "getHealth")) or 0
    local full = Z.full[zed]
    if not full or hp > full then full = hp; Z.full[zed] = hp end
    return hp, full
end

function Z.scan()
    local player = getSpecificPlayer and getSpecificPlayer(0)
    local out = {}
    Z.visible = out
    if not player or call(player, "isDead") then return end
    local cell = getCell and getCell()
    local list = cell and call(cell, "getZombieList")
    if not list then return end
    local num = call(player, "getPlayerNum") or 0
    local pz = math.floor(call(player, "getZ") or 0)
    local px, py = call(player, "getX") or 0, call(player, "getY") or 0
    local r2 = Z.RADIUS * Z.RADIUS
    local keep = {}
    for i = 0, list:size() - 1 do
        local zed = list:get(i)
        if zed and not call(zed, "isDead") then
            keep[zed] = Z.full[zed]
            if math.floor(call(zed, "getZ") or -99) == pz then
                local dx, dy = (call(zed, "getX") or 0) - px, (call(zed, "getY") or 0) - py
                if dx * dx + dy * dy <= r2 then
                    local sq = call(zed, "getCurrentSquare")
                    if sq and call(sq, "isCanSee", num) then
                        out[#out + 1] = zed
                    end
                end
            end
        end
    end
    -- zombies no longer in the cell are forgotten (no table growing forever)
    Z.full = keep
    for _, zed in ipairs(out) do Z.track(zed) end
end

-- ------------------------------------------------------------- hits
local function slotFor(zed)
    local n = 0
    for _, p in ipairs(Z.popups) do if zed and p.zombie == zed then n = n + 1 end end
    return n
end

function Z.addPopup(zed, amount, crit, x, y, z)
    Z.popups[#Z.popups + 1] = { zombie = zed, x = x, y = y, z = z, amount = amount, crit = crit and true or false,
        born = getTimestampMs(), slot = slotFor(zed) }
end

function Z.onHit(zed, attacker)
    if not zed then return end
    local me = getSpecificPlayer and getSpecificPlayer(0)
    if not me or attacker ~= me then return end
    local before = Z.track(zed)
    local crit = call(attacker, "isCriticalHit") == true
    Z.pending[#Z.pending + 1] = { zombie = zed, before = before, crit = crit, ticks = 1 }
end

function Z.settle()
    for i = #Z.pending, 1, -1 do
        local c = Z.pending[i]
        c.ticks = c.ticks - 1
        if c.ticks <= 0 then
            table.remove(Z.pending, i)
            local after = tonumber(call(c.zombie, "getHealth")) or c.before
            local dealt = c.before - after
            if dealt > 0 then
                if Z.showDamage() then Z.addPopup(c.zombie, dealt, c.crit) end
                if TWADamageShare and TWADamageShare.send then TWADamageShare.send(c.zombie, dealt, c.crit) end
            end
        end
    end
end

-- someone else's hit, relayed by the server (TWADamageShare)
function Z.onRemote(args)
    if not Z.showDamage() or type(args) ~= "table" then return end
    local amount = tonumber(args.a)
    if not amount or amount <= 0 then return end
    local zed
    local id = tonumber(args.id)
    local cell = getCell and getCell()
    local list = id and cell and call(cell, "getZombieList")
    for i = 0, (list and list:size() or 0) - 1 do
        local zz = list:get(i)
        if zz and call(zz, "getOnlineID") == id then zed = zz; break end
    end
    Z.addPopup(zed, amount, args.c == true, tonumber(args.x), tonumber(args.y), tonumber(args.z))
end

local count = 0
function Z.onTick()
    if #Z.pending > 0 then Z.settle() end
    count = count + 1
    if count >= Z.SCAN_TICKS then
        count = 0
        if Z.showBar() or Z.showText() then Z.scan() else Z.visible = {} end
    end
end

function Z.onZombieDead(zed)
    if zed then Z.full[zed] = nil end
end

function Z.reset()
    Z.visible, Z.pending, Z.popups, Z.full = {}, {}, {}, {}
end

-- ------------------------------------------------------------- drawing
local function screenAt(num, x, y, z)
    if not (x and y and z) then return nil end
    return isoToScreenX(num, x, y, z), isoToScreenY(num, x, y, z)
end

-- the bar colour for a fill f (0..1)
function Z.barColor(f)
    local s = Z.barStyle()
    if s == "Red" then return 0.9, 0.15, 0.15 end
    if s == "Green" then return 0.25, 0.85, 0.25 end
    if s == "Blue" then return 0.25, 0.55, 1.0 end
    if s == "Purple" then return 0.7, 0.35, 0.95 end
    if f > 0.5 then return 1 - (f - 0.5) * 2 * 0.8, 0.85, 0.15 end   -- green -> yellow
    return 0.95, 0.2 + f * 1.3, 0.12                                  -- yellow -> red
end

local function text(tm, font, s, x, y, r, g, b, a)
    tm:DrawStringCentre(font, x + 1, y + 1, s, 0, 0, 0, a * 0.85)
    tm:DrawStringCentre(font, x, y, s, r, g, b, a)
end

function Z.render()
    if isGamePaused and isGamePaused() then return end
    local bar, txt, dmg = Z.showBar(), Z.showText(), Z.showDamage()
    if not dmg then Z.popups = {} end
    if not (bar or txt or dmg) then return end
    local player = getSpecificPlayer and getSpecificPlayer(0)
    local rend = getRenderer and getRenderer()
    local tm = getTextManager and getTextManager()
    if not player or not rend or not tm then return end
    local num = call(player, "getPlayerNum") or 0
    local fh = tm:getFontHeight(UIFont.Small)

    if bar or txt then
        local bw, bh = Z.barSize()
        local lift = Z.barLift()
        for _, zed in ipairs(Z.visible) do
            if not call(zed, "isDead") then
                local hp, full = Z.track(zed)
                local f = full > 0 and math.max(0, math.min(1, hp / full)) or 0
                local zUp = down(zed) and Z.DOWN_Z or Z.HEAD_Z
                local sx, sy = screenAt(num, call(zed, "getX"), call(zed, "getY"), (call(zed, "getZ") or 0) + zUp)
                if sx then
                    local x = math.floor(sx - bw / 2)
                    local y = math.floor(sy - lift - bh)
                    if bar then
                        rend:renderRect(x - 1, y - 1, bw + 2, bh + 2, 0, 0, 0, 0.85)
                        rend:renderRect(x, y, bw, bh, 0.18, 0.05, 0.05, 0.9)
                        local w = math.floor(bw * f + 0.5)
                        if w > 0 then
                            local r, g, b = Z.barColor(f)
                            rend:renderRect(x, y, w, bh, r, g, b, 1)
                            rend:renderRect(x, y, w, 1, 1, 1, 1, 0.25)   -- a little shine
                        end
                    end
                    if txt then
                        local s = TWADisplay.fmt(math.max(0, hp)) .. " / " .. TWADisplay.fmt(full)
                        local ty = bar and (y - fh - 1) or (y + bh - fh)
                        text(tm, UIFont.Small, s, math.floor(sx), ty, 1, 1, 1, 1)
                    end
                end
            end
        end
    end

    if dmg and #Z.popups > 0 then
        local now = getTimestampMs()
        local lift = Z.numberLift()
        local nr, ng, nb = Z.numberColor()
        local cr, cg, cb = Z.critColor()
        for i = #Z.popups, 1, -1 do
            local p = Z.popups[i]
            local life = p.crit and Z.CRIT_MS or Z.POPUP_MS
            local age = now - p.born
            local zed = p.zombie
            if zed and call(zed, "getCurrentSquare") then
                local zUp = down(zed) and Z.DOWN_Z or Z.HEAD_Z
                p.x, p.y, p.z = call(zed, "getX"), call(zed, "getY"), (call(zed, "getZ") or 0) + zUp
            elseif p.z and not p.zUp then
                p.z, p.zUp = p.z + Z.HEAD_Z, true    -- a relayed hit on a zombie we do not have
            end
            if age >= life or not p.x then
                table.remove(Z.popups, i)
            else
                local t = age / life
                local sx, sy = screenAt(num, p.x, p.y, p.z)
                if sx then
                    local x = math.floor(sx + 26 + (p.slot % 3) * 10)
                    local y = math.floor(sy - lift - 4 - p.slot * 6 - Z.POPUP_RISE * t)
                    local a = t < 0.7 and 1 or (1 - (t - 0.7) / 0.3)
                    local s = TWADisplay.fmt(p.amount)
                    if p.crit then
                        -- a short shake at the start makes it stand out
                        if age < 180 then x = x + ((math.floor(age / 30) % 2 == 0) and 2 or -2) end
                        text(tm, Z.numberFont(true), s .. "!", x, y - 4, cr, cg, cb, a)
                    else
                        text(tm, Z.numberFont(false), s, x, y, nr, ng, nb, a)
                    end
                end
            end
        end
    end
end

if Events and not Z.registered then
    Z.registered = true
    if Events.OnTick then Events.OnTick.Add(Z.onTick) end
    -- OnPreUIDraw: after the world, before the UI -> under every window
    if Events.OnPreUIDraw then Events.OnPreUIDraw.Add(Z.render)
    elseif Events.OnPostUIDraw then Events.OnPostUIDraw.Add(Z.render) end
    if Events.OnHitZombie then Events.OnHitZombie.Add(Z.onHit) end
    if Events.OnZombieDead then Events.OnZombieDead.Add(Z.onZombieDead) end
    if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(Z.reset) end
end

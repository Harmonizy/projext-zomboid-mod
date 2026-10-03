--============================================================================
-- HARMONIE_TheWayToAttack -- zombie health bars, HP numbers, damage numbers
--
-- Request 2026-10-03: what the "Zombie Health Bars" Workshop mod shows,
-- built into this mod (our own code): over every zombie you can see near
-- you, a health bar and its HP, and the damage of each of your hits rising
-- from the zombie. Options > Mods > The Way To Attack switches each one on
-- or off and sets how high they sit. Numbers are shown x100 (TWADisplay).
--
-- How it works (client only, nothing is sent anywhere):
--   * every SCAN_TICKS ticks: the zombies of the cell within RADIUS tiles,
--     on your floor, on a square you can see, alive
--   * a zombie's "full" HP is the highest health seen on it (the game has
--     no max-health getter); forgotten when it dies
--   * OnHitZombie (your own hits): health before, read again on the next
--     tick -> the difference is the damage popup
--   * drawn on OnPostUIDraw at the zombie's screen position
--============================================================================

require "HARMONIE_TWA_Display"

TWAZombieHP = TWAZombieHP or {}
local Z = TWAZombieHP

Z.RADIUS = 15
Z.SCAN_TICKS = 10
Z.BAR_W, Z.BAR_H = 44, 6
Z.HEAD_Z = 0.8          -- above the head (in floors)
Z.DOWN_Z = 0.2          -- lying on the ground
Z.LIFT_PX = 12          -- base gap above that point
Z.HEIGHT_STEP_PX = 3    -- per step of the height option
Z.POPUP_MS = 800
Z.POPUP_RISE = 22

Z.visible = {}          -- zombies to draw (refreshed every scan)
Z.full = setmetatable({}, { __mode = "k" })   -- zombie -> highest health seen
Z.pending = {}          -- { zombie, before, ticks } waiting for the next tick
Z.popups = {}           -- { zombie, amount, born, slot }

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
function Z.showBar() return opt("zhpBar", true) == true end
function Z.showText() return opt("zhpText", true) == true end
function Z.showDamage() return opt("zhpDamage", true) == true end
function Z.lift() return Z.LIFT_PX + (tonumber(opt("zhpHeight", 0)) or 0) * Z.HEIGHT_STEP_PX end

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
    for i = 0, list:size() - 1 do
        local zed = list:get(i)
        if zed and not call(zed, "isDead") and math.floor(call(zed, "getZ") or -99) == pz then
            local dx, dy = (call(zed, "getX") or 0) - px, (call(zed, "getY") or 0) - py
            if dx * dx + dy * dy <= r2 then
                local sq = call(zed, "getCurrentSquare")
                if sq and call(sq, "isCanSee", num) then
                    Z.track(zed)
                    out[#out + 1] = zed
                end
            end
        end
    end
end

-- ------------------------------------------------------------- hits
function Z.onHit(zed, attacker)
    if not zed or not Z.showDamage() then return end
    local me = getSpecificPlayer and getSpecificPlayer(0)
    if not me or attacker ~= me then return end
    local before = Z.track(zed)
    Z.pending[#Z.pending + 1] = { zombie = zed, before = before, ticks = 1 }
end

local function slotFor(zed)
    local n = 0
    for _, p in ipairs(Z.popups) do if p.zombie == zed then n = n + 1 end end
    return n
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
                Z.popups[#Z.popups + 1] = { zombie = c.zombie, amount = dealt, born = getTimestampMs(), slot = slotFor(c.zombie) }
            end
        end
    end
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
    Z.visible, Z.pending, Z.popups = {}, {}, {}
end

-- ------------------------------------------------------------- drawing
local function screenPos(num, zed, zUp)
    local x, y, z = call(zed, "getX"), call(zed, "getY"), call(zed, "getZ")
    if not (x and y and z) then return nil end
    return isoToScreenX(num, x, y, z + zUp), isoToScreenY(num, x, y, z + zUp)
end

-- full -> green, half -> yellow, low -> red
local function hpColor(f)
    if f > 0.5 then return 1 - (f - 0.5) * 2 * 0.8, 0.85, 0.15 end
    return 0.95, 0.2 + f * 1.3, 0.12
end

local function text(tm, font, s, x, y, r, g, b, a, centre)
    if centre then
        tm:DrawStringCentre(font, x + 1, y + 1, s, 0, 0, 0, a * 0.85)
        tm:DrawStringCentre(font, x, y, s, r, g, b, a)
    else
        tm:DrawString(font, x + 1, y + 1, s, 0, 0, 0, a * 0.85)
        tm:DrawString(font, x, y, s, r, g, b, a)
    end
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
    local lift = Z.lift()
    local fh = tm:getFontHeight(UIFont.Small)

    if bar or txt then
        for _, zed in ipairs(Z.visible) do
            if not call(zed, "isDead") then
                local hp, full = Z.track(zed)
                local f = full > 0 and math.max(0, math.min(1, hp / full)) or 0
                local zUp = down(zed) and Z.DOWN_Z or Z.HEAD_Z
                local sx, sy = screenPos(num, zed, zUp)
                if sx then
                    local x = math.floor(sx - Z.BAR_W / 2)
                    local y = math.floor(sy - lift - Z.BAR_H)
                    if bar then
                        rend:renderRect(x - 1, y - 1, Z.BAR_W + 2, Z.BAR_H + 2, 0, 0, 0, 0.85)
                        rend:renderRect(x, y, Z.BAR_W, Z.BAR_H, 0.18, 0.05, 0.05, 0.9)
                        local w = math.floor(Z.BAR_W * f + 0.5)
                        if w > 0 then
                            local r, g, b = hpColor(f)
                            rend:renderRect(x, y, w, Z.BAR_H, r, g, b, 1)
                            rend:renderRect(x, y, w, 1, 1, 1, 1, 0.25)   -- a little shine
                        end
                    end
                    if txt then
                        local s = TWADisplay.fmt(math.max(0, hp)) .. " / " .. TWADisplay.fmt(full)
                        local ty = bar and (y - fh - 1) or (y + Z.BAR_H - fh)
                        text(tm, UIFont.Small, s, math.floor(sx), ty, 1, 1, 1, 1, true)
                    end
                end
            end
        end
    end

    if dmg and #Z.popups > 0 then
        local now = getTimestampMs()
        for i = #Z.popups, 1, -1 do
            local p = Z.popups[i]
            local age = now - p.born
            if age >= Z.POPUP_MS or not call(p.zombie, "getCurrentSquare") then
                table.remove(Z.popups, i)
            else
                local t = age / Z.POPUP_MS
                local zUp = down(p.zombie) and Z.DOWN_Z or Z.HEAD_Z
                local sx, sy = screenPos(num, p.zombie, zUp)
                if sx then
                    local x = math.floor(sx + 26 + (p.slot % 3) * 10)
                    local y = math.floor(sy - lift - 4 - p.slot * 6 - Z.POPUP_RISE * t)
                    local a = t < 0.7 and 1 or (1 - (t - 0.7) / 0.3)
                    text(tm, UIFont.Medium, TWADisplay.fmt(p.amount), x, y, 1, 0.82, 0.25, a, true)
                end
            end
        end
    end
end

if Events and not Z.registered then
    Z.registered = true
    if Events.OnTick then Events.OnTick.Add(Z.onTick) end
    if Events.OnPostUIDraw then Events.OnPostUIDraw.Add(Z.render) end
    if Events.OnHitZombie then Events.OnHitZombie.Add(Z.onHit) end
    if Events.OnZombieDead then Events.OnZombieDead.Add(Z.onZombieDead) end
    if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(Z.reset) end
end

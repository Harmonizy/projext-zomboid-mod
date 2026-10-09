-- AB_Reticle.lua
--
-- Replaces the vanilla (Java-rendered) aiming reticle with a Lua-drawn overlay.
--
-- Reticle: each scope gets its own texture, named after the scope's short item
-- type (the part of the full type after the module dot). e.g. the scope
-- "Base.RedDot" uses media/textures/ABReticle/reddot.png, "Brita.HAMR_cat" uses
-- hamr_cat.png, and so on. A scope without its own texture falls back to its
-- category texture (cat1..cat5.png) selected by scope type / magnification:
--   1) no scope (iron sights)
--   2) red dot / holo
--   3) mid-range scope
--   4) long-range modern scope
--   5) WWII-era scope
--
-- Behaviour:
--   * Fixed-size reticle (no vanilla spread shrink), a small "pulse" enlargement
--     on each shot for categories 1-3 (4-5 stay fixed).
--
-- Lifecycle follows the ATYB42fix pattern: the overlay panel is created lazily
-- (and shown/hidden) from Events.OnTick while a ranged weapon is being aimed,
-- and it draws in prerender().

require "ISUI/ISPanel"

local ABReticle = {}

-- ---------------------------------------------------------------------------
-- Sandbox toggle: whether to use the MFS reticle overlay (true by default) or
-- fall back to the vanilla Java-rendered reticle (MFSSandbox.EnableReticle).
-- ---------------------------------------------------------------------------
local function reticleEnabled()
    return not (SandboxVars and SandboxVars.MFSSandbox and SandboxVars.MFSSandbox.EnableReticle == false)
end

-- ---------------------------------------------------------------------------
-- Tuning
-- ---------------------------------------------------------------------------
local TEX_DIR        = "media/textures/ABReticle/"

local RECOIL_MAX     = 0.15   -- extra scale added instantly on a shot
local RECOIL_DECAY   = 2.0    -- per second, linear decay back to 1.0

-- Magnification fallback thresholds (MaxSightRange) for scopes not in any list.
local MAG_REDDOT_MAX = 10.0
local MAG_MID_MAX    = 16.0

-- ---------------------------------------------------------------------------
-- Scope name lists (matched case-insensitively against the item type, i.e. the
-- part of the full type after the module dot).
-- ---------------------------------------------------------------------------
local function buildSet(list)
    local s = {}
    for _, name in ipairs(list) do
        s[string.lower(name)] = true
    end
    return s
end

local SCOPE_REDDOT = buildSet {
    "lee_enfield_scope", "walthermrs_1", "mz_uh1", "walthermrs_2",
    "hd511a_cat", "mz_lthy", "558holo", "mz_hco",
}
local SCOPE_MID = buildSet {
    "hamr_cat", "ta11_4x_scope", "carryhandle", "vortexsight",
    "compm4", "cqbr_acog_ru",
}
local SCOPE_LONG = buildSet {
    "mz_paoduijing", "snipex24", "atacr", "xm157_cat",
}
local SCOPE_WWII = buildSet {
    "pescope_cat", "pso_1_cat", "mz_m6d", "unertl8x_cat",
}

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local state = {
    recoil = 0,             -- current extra scale (0 .. RECOIL_MAX)
    lastMs = 0,             -- previous frame timestamp, for dt
}

-- ---------------------------------------------------------------------------
-- Textures (lazy + nil-safe so a missing PNG never crashes)
-- ---------------------------------------------------------------------------
local TEX = {}
local function getTex(name)
    if TEX[name] == nil then
        local ok, tex = pcall(getTexture, TEX_DIR .. name .. ".png")
        TEX[name] = (ok and tex) or false
    end
    return TEX[name] ~= false and TEX[name] or nil
end

-- ---------------------------------------------------------------------------
-- Scope -> category (fallback when a scope has no dedicated texture)
-- ---------------------------------------------------------------------------
local function categoryByMagnification(weapon, part)
    local maxSight
    local ok, v = pcall(function() return weapon:getMaxSightRange() end)
    if ok and v then maxSight = v end
    if not maxSight and part then
        ok, v = pcall(function() return part:getScriptItem():getMaxSightRange() end)
        if ok and v then maxSight = v end
    end
    if not maxSight then return 3 end
    if maxSight <= MAG_REDDOT_MAX then return 2 end
    if maxSight <= MAG_MID_MAX then return 3 end
    return 4
end

-- getType() returns the module-qualified type (e.g. "Base.RedDot"); the texture
-- names only use the short part after the dot, so strip any module prefix.
local function shortType(item)
    local t = tostring(item:getType() or "")
    local dot = t:find("%.")
    if dot then t = t:sub(dot + 1) end
    return string.lower(t)
end

local function getCategory(weapon)
    local part = weapon:getWeaponPart("Scope")
    if not part then return 1 end
    local name = shortType(part)
    if SCOPE_REDDOT[name] then return 2 end
    if SCOPE_MID[name]    then return 3 end
    if SCOPE_LONG[name]   then return 4 end
    if SCOPE_WWII[name]   then return 5 end
    return categoryByMagnification(weapon, part)
end

-- ---------------------------------------------------------------------------
-- Overlay panel
-- ---------------------------------------------------------------------------
local ReticlePanel = ISPanel:derive("ABReticlePanel")

function ReticlePanel:initialise()
    ISPanel.initialise(self)
end

function ReticlePanel:new()
    local o = ISPanel:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    o.background = false
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor     = { r = 0, g = 0, b = 0, a = 0 }
    o.width = 0
    o.height = 0
    o.anchorLeft = false
    o.anchorRight = false
    o.anchorTop = false
    o.anchorBottom = false
    o.moveWithMouse = false
    o.keepOnScreen = false
    -- Preload the fallback category textures now that we are in-game.
    for _, name in ipairs { "cat1", "cat2", "cat3", "cat4", "cat5" } do
        getTex(name)
    end
    return o
end

function ReticlePanel:prerender()
    local now = getTimestampMs()
    local dt = state.lastMs > 0 and (now - state.lastMs) / 1000 or 0
    state.lastMs = now
    if dt > 0.1 then dt = 0.1 end

    -- Decay the recoil pulse back to normal size.
    if state.recoil > 0 then
        state.recoil = state.recoil - RECOIL_DECAY * dt
        if state.recoil < 0 then state.recoil = 0 end
    end

    local player = getPlayer()
    if not player then return end
    local weapon = player:getPrimaryHandItem()
    local aiming = player:isAiming()
        and weapon
        and instanceof(weapon, "HandWeapon")
        and weapon:isRanged()
    if not aiming then return end

    -- Position the panel so its origin sits at the aim point (the mouse cursor,
    -- same as the ATYB42fix reticle), then draw the reticle centered on it.
    self:setX(getMouseX())
    self:setY(getMouseY())

    local part = weapon:getWeaponPart("Scope")
    local category = part and getCategory(weapon) or 1

    -- Pick the reticle: the scope's own texture if provided, else its category.
    local tex = nil
    if part then tex = getTex(shortType(part)) end
    if not tex then tex = getTex("cat" .. category) end
    if not tex then return end

    -- Recoil pulse (the "jitter" enlargement on shot) only for categories 1-3;
    -- long-range and WWII scopes (4-5) keep a fixed size.
    local scale = 1.0
    if category <= 3 then
        scale = 1 + state.recoil
    end
    local w = tex:getWidth() * scale
    local h = tex:getHeight() * scale
    self:drawTextureScaled(tex, -w / 2, -h / 2, w, h, 1.0, 1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Show the overlay while aiming (created lazily); hidden again as soon as
-- aiming stops or the reticle is disabled.
-- ---------------------------------------------------------------------------
local function onTick()
    if not reticleEnabled() then
        if ABReticle.panel then ABReticle.panel:setVisible(false) end
        return
    end

    local player = getPlayer()
    if not player then
        if ABReticle.panel then ABReticle.panel:setVisible(false) end
        return
    end

    local weapon = player:getPrimaryHandItem()
    local aiming = player:isAiming()
        and weapon
        and instanceof(weapon, "HandWeapon")
        and weapon:isRanged()

    if aiming then
        if not ABReticle.panel then
            ABReticle.panel = ReticlePanel:new()
            ABReticle.panel:initialise()
            ABReticle.panel:addToUIManager()
        end
        ABReticle.panel:setVisible(true)
    else
        state.recoil = 0
        if ABReticle.panel then ABReticle.panel:setVisible(false) end
    end
end

Events.OnTick.Add(onTick)

-- ---------------------------------------------------------------------------
-- Recoil pulse on shot
-- ---------------------------------------------------------------------------
if Events.OnWeaponSwingHitPoint then
    Events.OnWeaponSwingHitPoint.Add(function(player, weapon)
        if reticleEnabled() and player == getPlayer() and weapon and weapon:isRanged() then
            state.recoil = RECOIL_MAX
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Disable the vanilla Java-rendered reticle; our overlay replaces it.
--
-- The vanilla reticle is drawn in IsoReticle.render() (Java). The main reticle
-- texture and the scope vignette are toggleable (disabled below), but the spread
-- "crosshair" (the 4 lines that slowly shrink while you aim) is drawn
-- UNCONDITIONALLY and has no option to turn it off. To fully remove it we
-- override its textures with transparent PNGs shipped in
-- media/ui/Reticle/crosshair00..23.png (the game loads mod files over the
-- vanilla ones, so those 12 textures now draw nothing).
--
-- The vanilla "valid target" red dot (drawn over a zombie you can hit) is kept
-- enabled and handled natively by the game.
--
-- When the sandbox option MFSSandbox.EnableReticle is off, the vanilla reticle
-- options are restored instead. (The transparent crosshair PNG overrides are
-- static file replacements and cannot be toggled at runtime, so the vanilla
-- spread lines stay hidden regardless.)
-- ---------------------------------------------------------------------------
local function applyReticleOption()
    if reticleEnabled() then
        getCore():setOptionShowReticleTexture(false)
        getCore():setOptionShowValidTargetReticleTexture(true)
        -- Hide the vanilla scope vignette (the small circular scope view); only
        -- the reticle texture is drawn.
        getCore():setOptionShowAimTexture(false)
    else
        getCore():setOptionShowReticleTexture(true)
        getCore():setOptionShowValidTargetReticleTexture(true)
        getCore():setOptionShowAimTexture(true)
    end
end

applyReticleOption()
if Events.OnGameStart then
    Events.OnGameStart.Add(applyReticleOption)
end

--============================================================================
-- HARMONIE_TheWayToAttack -- generic procedure minigame (client)
--
-- Request 2026-09-28 (phase 1): one minigame shared by every procedure,
-- scoring it Miss/Bad/Good/Excellent. Hold the left mouse button and a
-- needle travels along a gauge; let go inside the zones. Three zones sit
-- one inside another around a random point: the widest scores Bad, the
-- middle one Good, the narrowest Excellent. Letting go outside all of them,
-- letting the needle run off the end, pressing Cancel, right-clicking or
-- ESC all score Miss. One attempt per play.
--
-- Written from scratch after studying how Casualties Undead (Workshop
-- 3805748433) builds its minigames -- the IDEAS are the same (a modal panel
-- that captures the mouse, a result state machine, fall back to a plain
-- progress bar rather than ever blocking the player), none of its code or
-- art is used.
--
-- Contract: TWAMinigame.play(player, procId, onResult) calls
-- onResult(word) exactly once -- the minigame's word, or "Excellent"
-- straight away when the minigame is switched off in sandbox or fails to
-- open or errors while running (request 2026-09-28). It is NOT called if
-- the character dies with the panel open (nothing left to credit).
--
-- Phase 2 (later): per-category games replace this one by registering a
-- different class per procedure category; everything outside this file
-- only ever sees the word.
--============================================================================

require "ISUI/ISPanel"
require "HARMONIE_TWA_Config"

TWAMinigame = ISPanel:derive("TWAMinigame")
TWAMinigame.instance = nil

local W, H = 540, 250
local GAUGE_X, GAUGE_Y, GAUGE_W, GAUGE_H = 30, 118, 480, 30
local CANCEL_W, CANCEL_H = 150, 28
-- Zone widths as a fraction of the gauge (request 2026-09-28: smallest =
-- Excellent, middle = Good, widest = Bad).
local ZONE_W = { Bad = 0.15, Good = 0.075, Excellent = 0.03 } -- halved (request 2026-09-28)
local RESULT_LINGER_MS = 900

local ZONE_COLOR = {
    Bad = { r = 0.55, g = 0.32, b = 0.12 },
    Good = { r = 0.20, g = 0.55, b = 0.22 },
    Excellent = { r = 0.95, g = 0.78, b = 0.18 },
}

function TWAMinigame.enabled()
    return TWAConfig.on("EnableMinigame")
end

-- Something else holds the mouse right now: another TWA minigame, or a
-- Casualties Undead treatment minigame (both capture the mouse; two at once
-- would fight over it).
function TWAMinigame.busy()
    if TWAMinigame.instance then return true end
    if ISMinigameBaseUI and ISMinigameBaseUI.instance then return true end
    return false
end

local function skillLevels(player, proc)
    if not proc or not proc.skill then return 0, 0 end
    local name, lvl = proc.skill:match("^(%a+):(%d+)$")
    local perk = name and Perks[name]
    return tonumber(lvl) or 0, perk and player:getPerkLevel(perk) or 0
end

-- Phase 2 (request 2026-09-28: "เริ่มทำ minigame เพิ่ม ให้แยบยลเหมือน
-- ม็อดอ้างอิง"): which game -- and which variant of it -- each procedure
-- plays, chosen by what the procedure physically IS rather than just its UI
-- category. Games live in HARMONIE_TWA_MG_*.lua on TWAMinigameBase. Any
-- procedure not listed (or whose game class failed to load) falls back to
-- the generic needle game below.
-- Round 5 (request 2026-09-28, "ชอบไอเดียมินิเกม 2, 3, 6"): Suture
-- (StringSinew, ReinforcedBind), Extract (DrillCore), Incision (MakeHandle,
-- MakeLongHandle, EngravePattern).
TWAMinigame.GAME_FOR = {
    -- Assembly
    WrapClothImprov        = { "TWAWrapGame", "cloth" },
    SawWood                = { "TWAStrokeGame", "saw" },
    SmashBottle            = { "TWAStrikeGame", "smash" },
    BreakBranch            = { "TWAHeatGame", "bend" },
    WrapBarbedWireAssembly = { "TWAWrapGame", "wire" },
    WrapWireAssembly       = { "TWAWrapGame", "wire" },
    AssembleCan            = { "TWAWrapGame", "screw" },
    AssembleNails          = { "TWAStrikeGame", "nails" },
    AssembleRailSpike      = { "TWAStrikeGame", "nails" },
    AssembleBoneSpike      = { "TWAStrokeGame", "carve" },
    AssembleSawblade       = { "TWAStrokeGame", "saw" },
    AssembleSheetMetal     = { "TWAWrapGame", "screw" },
    AssembleSpike          = { "TWAStrikeGame", "nails" },
    AssembleBrake          = { "TWAWrapGame", "screw" },
    AssembleBucket         = { "TWAStrikeGame", "rivet" },
    AssembleKettle         = { "TWAStrikeGame", "rivet" },
    AssembleRakeHead       = { "TWAWrapGame", "screw" },
    AssembleSpadeHead      = { "TWAWrapGame", "screw" },
    -- Blacksmithing (internal key "Metallurgy")
    StartFire              = { "TWAHeatGame", "fire" },
    MeltMetal              = { "TWAHeatGame", "melt" },
    PourMold               = { "TWAPourGame" },
    PourMoldLarge          = { "TWAPourGame" },
    CoolCast               = { "TWAHeatGame", "cool" },
    WeldWork               = { "TWAStrokeGame", "weld" },
    WeldWorkComplex        = { "TWAStrokeGame", "weld" },
    PolishMetal            = { "TWAStrokeGame", "polish" },
    GrindMetal             = { "TWAWrapGame", "grind" },
    EngravePattern         = { "TWAIncisionGame", "engrave" },
    ForgeShape             = { "TWAStrikeGame", "forge" },
    ForgeFold              = { "TWAStrikeGame", "forge" },
    ForgeComplex           = { "TWAStrikeGame", "forge" },
    ForgeVacuum            = { "TWAStrikeGame", "forge" },
    -- Sharpness / Piercing / Density
    SharpenEdge            = { "TWAStrokeGame", "sharpen" },
    StropLeather           = { "TWAStrokeGame", "sharpen" },
    KnapHead               = { "TWAStrikeGame", "knap" },
    TaperPoint             = { "TWAStrokeGame", "sharpen" },
    QuenchHarden           = { "TWAHeatGame", "cool" },
    AnnealMetal            = { "TWAHeatGame", "anneal" },
    -- Handle
    MakeHandle             = { "TWAIncisionGame", "carve" },
    WrapBind               = { "TWAWrapGame", "tape" },
    MakeLongHandle         = { "TWAIncisionGame", "carve" },
    ReinforcedBind         = { "TWASutureGame" },
    MakeRivetedHandle      = { "TWAStrikeGame", "rivet" },
    TightenBolts           = { "TWAWrapGame", "screw" },
    -- Balance / Structure
    HammerNails            = { "TWAStrikeGame", "nails" },
    CounterweightHead      = { "TWAStrikeGame", "rivet" },
    WeldMetal              = { "TWAStrokeGame", "weld" },
    RivetPlate             = { "TWAStrikeGame", "rivet" },
    DrillCore              = { "TWAExtractGame" },
    -- Toughness
    WrapCloth              = { "TWAWrapGame", "cloth" },
    WrapLeather            = { "TWAWrapGame", "leather" },
    StringSinew            = { "TWASutureGame" },
    WeaveWire              = { "TWAWrapGame", "wire" },
    -- Wear resistance
    CoatMud                = { "TWACoatGame", "mud" },
    FireTreat              = { "TWACoatGame", "fire" },
    CoatWax                = { "TWACoatGame", "wax" },
    SurfaceCoating         = { "TWACoatGame", "bleach" },
}

--- Returns false (and does not call onResult) only when busy; the caller
--- then just doesn't start the procedure. `recipe` (optional) lets a game
--- show the item being made.
function TWAMinigame.play(player, procId, onResult, recipe)
    if not TWAMinigame.enabled() then
        onResult(TWACraftState.FALLBACK_WORD)
        return true
    end
    if TWAMinigame.busy() then return false end
    local spec = TWAMinigame.GAME_FOR[procId]
    local cls = spec and _G[spec[1]]
    local ok, err
    if cls and cls.openFor then
        ok, err = pcall(cls.openFor, cls, player, procId, recipe, onResult, spec[2])
    else
        ok, err = pcall(TWAMinigame.open, player, procId, onResult)
    end
    if not ok then
        print("[HARMONIE_TheWayToAttack] minigame failed to open (" .. tostring(err) .. "), scoring Excellent")
        local ui = TWAMinigame.instance
        if ui then
            ui.onResult = nil
            ui:teardown()
        end
        onResult(TWACraftState.FALLBACK_WORD)
    end
    return true
end

function TWAMinigame.open(player, procId, onResult)
    local proc = TWAProcedures.List[procId]
    local playerNum = player:getPlayerNum()
    local x = getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - W) / 2
    local y = getPlayerScreenTop(playerNum) + (getPlayerScreenHeight(playerNum) - H) / 2
    local ui = TWAMinigame:new(math.floor(x), math.floor(y), player, procId, proc, onResult)
    TWAMinigame.instance = ui
    ui:initialise()
    ui:instantiate()
    ui:addToUIManager()
    ui:setAlwaysOnTop(true)
    ui:setWantKeyEvents(true)
    ui:setCapture(true)
    ui:bringToTop()
    return ui
end

function TWAMinigame:new(x, y, player, procId, proc, onResult)
    local o = ISPanel:new(x, y, W, H)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.procId = procId
    o.proc = proc
    o.onResult = onResult
    o.moveWithMouse = false
    o.background = false
    o.title = proc and getText(proc.nameKey) or tostring(procId)

    -- Difficulty: the needle is quicker for a procedure that needs more
    -- skill, and every level the player has ABOVE that requirement widens
    -- the zones a little (capped), so practice pays off.
    local req, have = skillLevels(player, proc)
    o.speed = 0.45 + 0.04 * req                           -- gauge widths per second
    o.zoneScale = math.min(1.6, 1 + 0.06 * math.max(0, have - req))
    local halfBad = ZONE_W.Bad * o.zoneScale / 2
    o.center = ZombRandFloat(0.25 + halfBad, 0.97 - halfBad)

    o.needle = 0
    o.holding = false
    o.word = nil
    return o
end

function TWAMinigame:zoneHalf(name)
    return ZONE_W[name] * self.zoneScale / 2
end

function TWAMinigame:judge(pos)
    local d = math.abs(pos - self.center)
    if d <= self:zoneHalf("Excellent") then return "Excellent" end
    if d <= self:zoneHalf("Good") then return "Good" end
    if d <= self:zoneHalf("Bad") then return "Bad" end
    return "Miss"
end

function TWAMinigame:cancelRect()
    return (W - CANCEL_W) / 2, H - CANCEL_H - 14, CANCEL_W, CANCEL_H
end

function TWAMinigame:inCancel(x, y)
    local cx, cy, cw, ch = self:cancelRect()
    return x >= cx and x <= cx + cw and y >= cy and y <= cy + ch
end

-- Result state ----------------------------------------------------------------

function TWAMinigame:finish(word)
    if self.word then return end
    self.word = word
    self.holding = false
    self.resultAt = getTimestampMs()
    getSoundManager():playUISound("UISelectListItem")
end

function TWAMinigame:deliver()
    local cb = self.onResult
    self.onResult = nil
    local word = self.word
    self:teardown()
    if cb then cb(word) end
end

-- Remove the panel and give the mouse back. Safe to call twice.
function TWAMinigame:teardown()
    if self.closed then return end
    self.closed = true
    if self.javaObject then
        self:setCapture(false)
        self:setWantKeyEvents(false)
    end
    self:setVisible(false)
    self:removeFromUIManager()
    if TWAMinigame.instance == self then TWAMinigame.instance = nil end
end

-- Any runtime error: never leave a panel holding the mouse -- close it and
-- score Excellent (request 2026-09-28).
function TWAMinigame:crash(err)
    print("[HARMONIE_TheWayToAttack] minigame error (" .. tostring(err) .. "), scoring Excellent")
    self.word = TWACraftState.FALLBACK_WORD
    self:deliver()
end

-- Frame loop ------------------------------------------------------------------

function TWAMinigame:tick()
    local now = getTimestampMs()
    local dt = math.min(200, now - (self.lastTick or now))
    self.lastTick = now

    if self.player:isDead() then
        self.onResult = nil
        self:teardown()
        return
    end
    if self.word then
        if now - self.resultAt >= RESULT_LINGER_MS then self:deliver() end
        return
    end
    if self.holding then
        self.needle = self.needle + self.speed * dt / 1000
        if self.needle >= 1 then
            self.needle = 1
            self:finish("Miss")
        end
    end
end

function TWAMinigame:prerender()
    if self.closed then return end
    local ok, err = pcall(self.tick, self)
    if not ok then self:crash(err) end
end

function TWAMinigame:draw()
    local S = TWACraftState
    -- Dim the world behind, then the panel.
    self:drawRect(-self.x, -self.y, getCore():getScreenWidth(), getCore():getScreenHeight(), 0.55, 0, 0, 0)
    self:drawRect(0, 0, W, H, 0.96, 0.06, 0.06, 0.07)
    self:drawRectBorder(0, 0, W, H, 1, 0.55, 0.55, 0.55)

    self:drawTextCentre(self.title, W / 2, 12, 1, 0.9, 0.6, 1, UIFont.Medium)
    self:drawTextCentre(getText("IGUI_TWA_MG_Hint"), W / 2, 44, 0.85, 0.85, 0.85, 1, UIFont.Small)
    self:drawTextCentre(getText("IGUI_TWA_MG_Hint2"), W / 2, 62, 0.65, 0.65, 0.65, 1, UIFont.Small)

    -- Gauge: track, then the zones widest-first so the narrow ones sit on top.
    self:drawRect(GAUGE_X, GAUGE_Y, GAUGE_W, GAUGE_H, 1, 0.12, 0.12, 0.13)
    for _, name in ipairs({ "Bad", "Good", "Excellent" }) do
        local half = self:zoneHalf(name)
        local x0 = GAUGE_X + math.max(0, self.center - half) * GAUGE_W
        local x1 = GAUGE_X + math.min(1, self.center + half) * GAUGE_W
        local c = ZONE_COLOR[name]
        self:drawRect(x0, GAUGE_Y, x1 - x0, GAUGE_H, 0.9, c.r, c.g, c.b)
    end
    self:drawRectBorder(GAUGE_X, GAUGE_Y, GAUGE_W, GAUGE_H, 1, 0.6, 0.6, 0.6)

    -- Needle.
    local nx = GAUGE_X + self.needle * GAUGE_W
    self:drawRect(nx - 2, GAUGE_Y - 8, 4, GAUGE_H + 16, 1, 1, 1, 1)

    -- Zone legend under the gauge.
    local ly = GAUGE_Y + GAUGE_H + 10
    local lx = GAUGE_X
    for _, name in ipairs({ "Excellent", "Good", "Bad" }) do
        local c = ZONE_COLOR[name]
        self:drawRect(lx, ly + 3, 12, 12, 1, c.r, c.g, c.b)
        local label = S.wordText(name)
        self:drawText(label, lx + 18, ly, 0.85, 0.85, 0.85, 1, UIFont.Small)
        lx = lx + 18 + getTextManager():MeasureStringX(UIFont.Small, label) + 20
    end

    if self.word then
        local c = S.WORD_COLOR[self.word]
        self:drawTextCentre(S.wordText(self.word), W / 2, H - CANCEL_H - 22, c.r, c.g, c.b, 1, UIFont.Large)
    else
        local cx, cy, cw, ch = self:cancelRect()
        local over = self:inCancel(self:getMouseX(), self:getMouseY())
        self:drawRect(cx, cy, cw, ch, 1, over and 0.45 or 0.3, 0.1, 0.1)
        self:drawRectBorder(cx, cy, cw, ch, 1, 0.8, 0.35, 0.35)
        self:drawTextCentre(getText("IGUI_TWA_MG_Cancel"), cx + cw / 2, cy + 5, 1, 1, 1, 1, UIFont.Small)
    end
end

function TWAMinigame:render()
    if self.closed then return end
    local ok, err = pcall(self.draw, self)
    if not ok then self:crash(err) end
end

-- Input (the panel holds mouse capture, so every event lands here) ------------

function TWAMinigame:onMouseDown(x, y)
    if self.word or self.closed then return true end
    if self:inCancel(x, y) then
        self:finish("Miss")
        return true
    end
    if self.needle == 0 then self.holding = true end
    return true
end

function TWAMinigame:onMouseUp(x, y)
    if self.holding and not self.word then
        self.holding = false
        self:finish(self:judge(self.needle))
    end
    return true
end

function TWAMinigame:onMouseUpOutside(x, y)
    return self:onMouseUp(x, y)
end

function TWAMinigame:onMouseDownOutside(x, y)
    return self:onMouseDown(-1, -1)
end

function TWAMinigame:onRightMouseUp(x, y)
    self:finish("Miss")
    return true
end

function TWAMinigame:onRightMouseUpOutside(x, y)
    self:finish("Miss")
    return true
end

function TWAMinigame:onMouseWheel(del)
    return true
end

function TWAMinigame:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function TWAMinigame:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:finish("Miss") end
end

Events.OnPlayerDeath.Add(function(player)
    local ui = TWAMinigame.instance
    if ui and ui.player == player then
        ui.onResult = nil
        ui:teardown()
    end
end)

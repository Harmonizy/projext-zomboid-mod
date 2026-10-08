--============================================================================
-- HARMONIE_TheWayToAttack -- the craft window follows the vanilla one (client)
--
-- R70 ("ผูกหน้าต่างคราฟอาวุธให้เปิด ปิด พร้อม หน้าต่างคราฟอาวุธของ vanilla"):
-- when the game's own crafting window (B42 handcraft window) opens, our
-- weapon crafting window opens too; when it closes, ours closes (the same
-- as pressing our X -- a started craft is put aside as unfinished, and not
-- while a procedure is running). Options > Mods > "Open with the vanilla
-- crafting window" switches it off.
--
-- How the vanilla window is found -- every step guarded, since other mods
-- (Neat Crafting...) replace parts of it:
--   * ISEntityUI.OpenHandcraftWindow is wrapped at OnGameStart (after the
--     other mods put theirs in): every open of the crafting window passes
--     through it;
--   * the window itself: the newest one built by ISHandcraftWindow:new (when
--     that class exists), else any visible window under
--     ISEntityUI.players[n] whose key or Type has "Handcraft" in it;
--   * closed = that window hidden or taken off the screen (its own
--     removeFromUIManager is wrapped), checked every few ticks.
--============================================================================

require "HARMONIE_TWA_CraftUI"

TWAVanillaLink = TWAVanillaLink or {}
local V = TWAVanillaLink
V.CHECK_EVERY = 10 -- ticks

function V.enabled()
    local o = TWAOptions and TWAOptions.followVanillaCraft
    if o and o.getValue then
        local ok, v = pcall(o.getValue, o)
        if ok then return v and true or false end
    end
    return true
end

local function isCraftWindow(key, w)
    local name = tostring(key or "") .. " " .. tostring(type(w) == "table" and w.Type or "")
    return name:find("Handcraft") ~= nil
end

local function visible(w)
    if type(w) ~= "table" or not w.getIsVisible then return false end
    local ok, v = pcall(w.getIsVisible, w)
    return ok and v and true or false
end

-- the vanilla crafting window of this player, when one is showing
function V.find(playerNum)
    if V.lastCreated and visible(V.lastCreated) then return V.lastCreated end
    local E = ISEntityUI
    local p = E and type(E.players) == "table" and E.players[playerNum or 0]
    if type(p) == "table" then
        for _, group in pairs(p) do
            if type(group) == "table" then
                for k, v in pairs(group) do
                    local w = type(v) == "table" and (v.instance or v) or nil
                    if w and isCraftWindow(k, w) and visible(w) then return w end
                end
            end
        end
    end
    local cls = ISHandcraftWindow
    if cls and visible(cls.instance) then return cls.instance end
    return nil
end

function V.track(w)
    if not w or V.tracked == w then return end
    V.tracked = w
    if not w.twaLinkWrapped and w.removeFromUIManager then
        w.twaLinkWrapped = true
        local orig = w.removeFromUIManager
        w.removeFromUIManager = function(self, ...)
            if V.tracked == self then V.onVanillaClosed() end
            return orig(self, ...)
        end
    end
end

function V.onVanillaOpened(player)
    if not V.enabled() then return end
    player = player or getPlayer()
    if not player then return end
    V.track(V.find(player:getPlayerNum()))
    local win = TWACraftUI.window
    if win and win:getIsVisible() then return end
    TWALog("VanillaLink", "vanilla crafting window opened -> opening ours")
    TWACraftUI.open(player)
end

function V.onVanillaClosed()
    V.tracked = nil
    if not V.enabled() then return end
    local win = TWACraftUI.window
    if win and win:getIsVisible() then TWALog("VanillaLink", "vanilla crafting window closed -> closing ours"); TWACraftUI.close() end
end

-- every few ticks: the tracked window went away without passing through
-- removeFromUIManager (hidden only), or one opened by a path we did not wrap
function V.tick()
    V.n = (V.n or 0) + 1
    if V.n % V.CHECK_EVERY ~= 0 then return end
    if V.tracked then
        if not visible(V.tracked) then V.onVanillaClosed() end
        return
    end
    local player = getPlayer()
    if not player or not V.enabled() then return end
    local w = V.find(player:getPlayerNum())
    if w then
        V.track(w)
        local win = TWACraftUI.window
        if not (win and win:getIsVisible()) then TWALog("VanillaLink", "found an open vanilla crafting window -> opening ours"); TWACraftUI.open(player) end
    end
end

function V.install()
    if V.installed then return end
    V.installed = true
    local cls = ISHandcraftWindow
    if cls and cls.new and not cls.twaLinkNew then
        cls.twaLinkNew = true
        local origNew = cls.new
        cls.new = function(...)
            local o = origNew(...)
            if type(o) == "table" then V.lastCreated = o end
            return o
        end
    end
    local E = ISEntityUI
    if E and E.OpenHandcraftWindow and not E.twaLinkOpen then
        E.twaLinkOpen = true
        local origOpen = E.OpenHandcraftWindow
        E.OpenHandcraftWindow = function(player, ...)
            local r = origOpen(player, ...)
            TWALogErr("VanillaLink", "onVanillaOpened", pcall(V.onVanillaOpened, type(player) == "userdata" and player or nil))
            return r
        end
    end
    TWALog("VanillaLink", "installed (ISHandcraftWindow %s, ISEntityUI.OpenHandcraftWindow %s)", cls and "found" or "MISSING", E and E.OpenHandcraftWindow and "found" or "MISSING")
    if Events and Events.OnTick then Events.OnTick.Add(function()
        local ok, err = pcall(V.tick)
        if not ok then TWALogOnce("vlink:" .. tostring(err), "VanillaLink", "tick FAILED: %s", tostring(err)) end
    end) end
end

if Events and Events.OnGameStart then Events.OnGameStart.Add(V.install) end

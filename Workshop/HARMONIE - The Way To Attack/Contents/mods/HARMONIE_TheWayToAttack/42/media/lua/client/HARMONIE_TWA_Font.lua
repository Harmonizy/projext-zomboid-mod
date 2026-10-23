--============================================================================
-- HARMONIE_TheWayToAttack -- text size of this mod's windows (client)
--
-- R67 ("Client setting ปรับขนาด font ได้"): Options > Mods > "Window text
-- size" (TWAOptions.uiFontSize: Small / Medium / Large). The windows ask
-- TWAFont for their fonts instead of naming UIFont.Small / UIFont.Medium:
--   TWAFont.small()   body text      Small  / Medium / Large
--   TWAFont.medium()  headings       Medium / Large  / Large
--   TWAFont.lineH(f)  line height of a font (for multi-line text)
--   TWAFont.grow(px, f) a spacing laid out for UIFont.Small, grown by how
--                     much taller font `f` (default small()) is
-- Small is the old look. F.bump (set by the craft window's size, R68) adds
-- one or two steps on top of the chosen size.
--============================================================================

TWAFont = TWAFont or {}
local F = TWAFont

local BODY = { "Small", "Medium", "Large" }
F.LEVELS = #BODY
local HEAD = { "Medium", "Large", "Large" }

function F.level()
    local o = TWAOptions and TWAOptions.uiFontSize
    local v = 1
    if o and o.getValue then
        local ok, r = pcall(o.getValue, o)
        if ok then v = math.floor(tonumber(r) or 1) end
    end
    if v < 1 or v > #BODY then v = 1 end
    -- R68: a bigger window (TWACraftUI layout scale) brings bigger text;
    -- R70: plus the craft window's A- / A+ (F.userStep, saved)
    return math.max(1, math.min(#BODY, F.rawLevel(v)))
end

-- the level before it is held to Small..Large (the A- / A+ buttons stop there)
function F.rawLevel(v)
    if not v then
        local o = TWAOptions and TWAOptions.uiFontSize
        v = 1
        if o and o.getValue then
            local ok, r = pcall(o.getValue, o)
            if ok then v = math.floor(tonumber(r) or 1) end
        end
        if v < 1 or v > #BODY then v = 1 end
    end
    return v + (tonumber(F.bump) or 0) + (tonumber(F.userStep) or 0)
end

local function font(name)
    return (UIFont and UIFont[name]) or UIFont.Small
end

function F.small() return font(BODY[F.level()]) end
function F.medium() return font(HEAD[F.level()]) end

function F.lineH(f)
    f = f or F.small()
    local tm = getTextManager and getTextManager()
    return tm and (tm:getFontHeight(f) + 1) or 15
end

function F.grow(px, f)
    return px + math.max(0, F.lineH(f or F.small()) - F.lineH(UIFont.Small))
end

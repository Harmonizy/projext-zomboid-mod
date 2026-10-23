--[[
    HARMONIE - Life With Style : the fashion body locations (shared, at load)

    registries.lua registers lws:<slot> and lws:<slot>_over. Here they join
    the "Human" group, at the END of it -- drawn last, over everything -- and
    each lws:<slot> HIDES the vanilla locations of its slot (LWS.SLOTS[].hides):
    while a fashion piece is worn there, the game does not draw the real
    clothes of that slot, so nothing pokes through. The real clothes are still
    worn: protection, warmth and pockets work as before. lws:<slot>_over hides
    nothing (the window's "show my real clothes").

    Appending needs no BodyLocations.reset() (The Only Cure's
    TOC/BodyLocations.lua resets and copies every location and its hide
    rules, ours included, so the order the two files run in does not matter).
]]--

require "HARMONIELifeWithStyle/LWS_Core"

local function loc(name)
    local ok, l = pcall(function() return ItemBodyLocation.get(ResourceLocation.of(name)) end)
    if ok and l then return l end
    return nil
end

local function setup()
    if not BodyLocations or not ItemBodyLocation or not ResourceLocation then
        LWS.log("BodyLocations", "B42 body location API missing -- fashion slots NOT made")
        return
    end
    local group = BodyLocations.getGroup("Human")
    if not group then LWS.log("BodyLocations", "no Human body location group -- fashion slots NOT made"); return end
    local made, hides, missing = 0, 0, {}
    for _, s in ipairs(LWS.SLOTS) do
      -- the pet slot is not on the body (LWS_Pets.lua)
      if s.body ~= false then
        for _, suffix in ipairs({ "", "_over" }) do
            local id = loc("lws:" .. s.id .. suffix)
            if id then
                local ok = pcall(function()
                    group:getOrCreateLocation(id)
                    group:setMultiItem(id, false)
                end)
                if ok then made = made + 1 else missing[#missing + 1] = "lws:" .. s.id .. suffix end
            else
                missing[#missing + 1] = "lws:" .. s.id .. suffix
            end
        end
        local mine = loc("lws:" .. s.id)
        if mine then
            for _, v in ipairs(s.hides) do
                local other = loc("base:" .. v)
                if other and pcall(function() group:setHideModel(mine, other) end) then
                    hides = hides + 1
                else
                    missing[#missing + 1] = "base:" .. v
                end
            end
        end
      end
    end
    -- the gacha Guardian Capsule's invisible armour layer (LWS_Gacha.lua), hides nothing
    local g = loc("lws:gacha_guardian")
    if g and pcall(function() group:getOrCreateLocation(g) end) then made = made + 1 else missing[#missing + 1] = "lws:gacha_guardian" end
    LWS.log("BodyLocations", "%d fashion body locations, %d hide rules%s", made, hides,
        #missing > 0 and (" -- not found: " .. table.concat(missing, ", ")) or "")
end

local ok, err = pcall(setup)
if not ok then LWS.log("BodyLocations", "setup FAILED: %s", tostring(err)) end

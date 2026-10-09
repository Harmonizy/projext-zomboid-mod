-- ============================================================================
-- MFSTrade shared data + logic (loaded on BOTH client and server).
--
-- The trade lists are generated deterministically from a per-world random seed
-- combined with a 12 in-game-hour block index, so every client and the server
-- derive the same trader for the same block without any network handshake. The
-- per-world seed is generated once on the server (and shared to clients), which
-- makes each new game start from a different random list. Prices are likewise
-- deterministic, letting the server re-derive a transaction's price/count
-- instead of trusting the client (anti-cheat / anti-dupe).
-- ============================================================================

MFSTrade = MFSTrade or {}

MFSTrade.MODULE = "MFSTrade"
MFSTrade.CMD_BUY = "Buy"              -- player buys from trader  (贩卖)
MFSTrade.CMD_SELL = "Sell"            -- player sells to trader   (收购)
MFSTrade.ACK = "TradeResult"
MFSTrade.CMD_MONEY = "RequestMoney"   -- client asks server for current money
MFSTrade.CMD_SEED = "RequestSeed"     -- client asks server for the per-world seed

-- modData field holding the player's trade money (a pure number, no item).
MFSTrade.MoneyKey = "MFSTrade_Money"

-- ============================================================================
-- Config
-- ============================================================================
MFSTrade.Config = {
    -- The walkie-talkie item(s) that enable the trade button.
    RadioItems = {
        "Base.WalkieTalkie1",
        "Base.WalkieTalkie2",
        "Base.WalkieTalkie3",
        "Base.WalkieTalkie4",
        "Base.WalkieTalkie5",
        "Base.WalkieTalkieMakeShift",
    },
    MoneyItem = "Base.Money",
    RefreshHours = 12,

    -- 贩卖 (trader -> player) pricing.
    BulletBasePrice = 100,
    BulletPriceFloat = 0.6,   -- +/-60%
    GunPartBasePrice = 2000,
    GunPartPriceFloat = 2.0,  -- +/-200%

    -- 贩卖 flat random price range for guns / attachments.
    SellMinPrice = 1500,
    SellMaxPrice = 6000,

    -- 收购 (player -> trader) price bounds, mapped from vanilla rarity.
    BuyMinPrice = 3000,
    BuyMaxPrice = 5000,

    -- Vanilla firearms (short type names). Anything with the FIREARM tag that
    -- is NOT one of these is treated as a MOD gun and becomes sellable.
    VanillaGuns = {
        "AssaultRifle", "AssaultRifle2", "TempNilItem", "HuntingRifle", "VarmintRifle",
        "JS14_Rifle", "JS3T_Shotgun", "L92_Carbine", "L94_Rifle",
        "MSR7T_Rifle", "TrapperCarbine", "Pistol", "Pistol2", "Pistol3",
        "Revolver", "Revolver_Long", "Shotgun", "ShotgunSawnoff",
        "DoubleBarrelShotgun",
    },

    -- Boxed bullets the trader sells.
    -- VanillaBoxes: vanilla ammo boxes (full type strings).
    VanillaBoxes = {
        "Base.Bullets9mmBox", "Base.Bullets38Box", "Base.Bullets44Box",
        "Base.Bullets45Box", "Base.Bullets50Box", "Base.Bullets58Box",
        "Base.Bullets86Box", "Base.545box", "Base.ShotgunShellsBox",
        "Base.308Box", "Base.223Box", "Base.556Box",
    },
    -- ModBoxes: this mod's own ammo boxes/cartons. These are excluded from the
    -- 收购 pool automatically (they are mod items, not vanilla).
    ModBoxes = {
        "Base.58Box", "Base.545Box", "Base.50Carton", "Base.86Carton",
        "Base.58Carton", "Base.545Carton", "Base.556Carton", "Base.145Carton",
        "Base.Bullets44Carton", "Base.Bullets45Carton", "Base.Bullets9mmCarton",
        "Base.ShotgunShellsCarton", "Base.308Carton", "Base.Bullets38Carton",
        "Base.Bullets145Box", "Base.CrossbowBoltBox", "Base.M240BeltBox",
    },

    -- Extra item types to exclude from the 收购 pool. Firearms, Gunpart items
    -- and ModBoxes are already excluded; add any other mod item type here as a
    -- full type string (e.g. "Base.SomeModItem").
    BuyExclusions = {},

    -- Vanilla items that must never be traded even though they are "normal"
    -- (currency, keyring, debug keys). Short or full names both accepted.
    VanillaPoolExclusions = {
        "Money", "KeyRing", "Key1", "Key2", "Key3", "Key4", "Key5",
    },

    -- Blacklists: full type strings that must NEVER be sold by the trader.
    GunBlacklist = {},
    PartBlacklist = {},
}

-- ============================================================================
-- Deterministic hashing / random helpers.
-- ============================================================================

-- Stable hash of (seed, key) -> [0,1). Used so every client/server derives the
-- same lists and prices for a given 12h block.
function MFSTrade.HashFloat(seed, key)
    local h = math.floor(tonumber(seed) or 0) % 2147483647
    for i = 1, #key do
        h = (h * 31 + string.byte(key, i)) % 2147483647
    end
    return (h % 1000000) / 1000000
end

-- Current 12 in-game-hour block index (shared by all clients + server).
function MFSTrade.GetBlock()
    local hours = 0
    if getGameTime and getGameTime() then
        local ok, v = pcall(function() return getGameTime():getWorldAgeHours() end)
        if ok and v then hours = v end
    end
    return math.floor(hours / MFSTrade.Config.RefreshHours)
end

-- Hours remaining until the 12h block rolls over and the lists refresh.
function MFSTrade.GetRefreshRemainingHours()
    local hours = 0
    if getGameTime and getGameTime() then
        local ok, v = pcall(function() return getGameTime():getWorldAgeHours() end)
        if ok and v then hours = v end
    end
    local block = math.floor(hours / MFSTrade.Config.RefreshHours)
    local remain = (block + 1) * MFSTrade.Config.RefreshHours - hours
    if remain < 0 then remain = 0 end
    return remain
end

-- ============================================================================
-- Per-world random seed. Generated once on the server and shared to clients so
-- every world gets its own, genuinely random trade lists (instead of the same
-- block-deterministic lists every game). The seed is mixed with the 12h block
-- index below, so the lists still reshuffle on every refresh while staying
-- unique per world and identical between the server and every client.
-- ============================================================================

MFSTrade.WorldSeed = nil
MFSTrade.SeedMultiplier = 1000003

function MFSTrade.GetWorldSeed()
    return MFSTrade.WorldSeed or 0
end

-- Generate the seed once, server-side only. Clients stay at 0 until the server
-- shares the real value via the RequestSeed command; singleplayer shares the
-- same Lua state, so the global is visible to both sides directly.
function MFSTrade.EnsureWorldSeed()
    if not MFSTrade.WorldSeed then
        local ok, isSrv = pcall(isServer)
        if ok and isSrv then
            MFSTrade.WorldSeed = ZombRand(1000000, 2000000000)
        end
    end
    return MFSTrade.GetWorldSeed()
end

-- Effective seed for the current 12h block: world seed mixed with block index.
function MFSTrade.GetEffectiveSeed()
    return MFSTrade.GetWorldSeed() * MFSTrade.SeedMultiplier + MFSTrade.GetBlock()
end

-- ============================================================================
-- Sandbox options. Read once and cached; the sandbox vars are static for the
-- whole game (the server hosts them and syncs them to every client), so caching
-- is safe. Each accessor falls back to MFSTrade.Config defaults when the var is
-- absent (sandbox options not loaded, or an older save).
-- ============================================================================

local sandboxCache = nil

function MFSTrade.GetSandbox()
    if sandboxCache ~= nil then
        return sandboxCache
    end
    local sv = {}
    if SandboxVars and SandboxVars.MFSTrade then
        sv = SandboxVars.MFSTrade
    end
    sandboxCache = sv
    return sv
end

-- Whether radio trading is enabled at all (sandbox toggle).
function MFSTrade.IsEnabled()
    return MFSTrade.GetSandbox().Enabled ~= false
end

-- 贩卖 price range (trader -> player).
function MFSTrade.GetSellMinPrice()
    local v = MFSTrade.GetSandbox().SellMinPrice
    return (type(v) == "number" and v) or MFSTrade.Config.SellMinPrice
end

function MFSTrade.GetSellMaxPrice()
    local v = MFSTrade.GetSandbox().SellMaxPrice
    return (type(v) == "number" and v) or MFSTrade.Config.SellMaxPrice
end

-- 收购 price range (player -> trader).
function MFSTrade.GetBuyMinPrice()
    local v = MFSTrade.GetSandbox().BuyMinPrice
    return (type(v) == "number" and v) or MFSTrade.Config.BuyMinPrice
end

function MFSTrade.GetBuyMaxPrice()
    local v = MFSTrade.GetSandbox().BuyMaxPrice
    return (type(v) == "number" and v) or MFSTrade.Config.BuyMaxPrice
end

-- Parse a comma-separated list of item full types from a sandbox string. Each
-- token is trimmed and validated against the script manager; unknown/invalid
-- types are dropped. Returns a table of full types ({} when unset/empty).
function MFSTrade.ParseItemList(str)
    local out, seen = {}, {}
    if type(str) ~= "string" or str == "" then
        return out
    end
    for token in string.gmatch(str, "[^,]+") do
        local ft = token:match("^%s*(.-)%s*$")
        if ft ~= "" and not seen[ft] and ScriptManager.instance:getItem(ft) then
            seen[ft] = true
            out[#out + 1] = ft
        end
    end
    return out
end

-- Custom 贩卖 item list (trader sells exactly these). Empty = default mod pool.
function MFSTrade.GetCustomSellList()
    return MFSTrade.ParseItemList(MFSTrade.GetSandbox().SellList)
end

-- Custom 收购 item list (trader buys exactly these). Empty = default vanilla pool.
function MFSTrade.GetCustomBuyList()
    return MFSTrade.ParseItemList(MFSTrade.GetSandbox().BuyList)
end

-- ============================================================================
-- Item pools (built lazily, cached).
-- ============================================================================

local cachedBoxPool, cachedGunPool, cachedPartPool = nil, nil, nil

local function shortName(fullType)
    local i = string.find(fullType, ".", 1, true)
    return i and string.sub(fullType, i + 1) or fullType
end

-- Boxed bullets (vanilla + mod), validated against the script manager.
function MFSTrade.GetBoxedBullets()
    if cachedBoxPool then return cachedBoxPool end
    local list, seen = {}, {}
    local function add(t)
        if not seen[t] and ScriptManager.instance:getItem(t) then
            seen[t] = true
            list[#list + 1] = t
        end
    end
    for _, t in ipairs(MFSTrade.Config.VanillaBoxes) do add(t) end
    for _, t in ipairs(MFSTrade.Config.ModBoxes) do add(t) end
    cachedBoxPool = list
    return list
end

-- MOD guns: Base-module firearms that are not vanilla guns, minus blacklist.
function MFSTrade.GetModGunPool()
    if cachedGunPool then return cachedGunPool end
    local vanilla, black = {}, {}
    for _, t in ipairs(MFSTrade.Config.VanillaGuns) do vanilla[t] = true end
    for _, t in ipairs(MFSTrade.Config.GunBlacklist) do black[t] = true; black["Base." .. t] = true end

    local list = {}
    local items = getAllItems()
    if items then
        for i = 0, items:size() - 1 do
            local sc = items:get(i)
            if sc and sc:getModuleName() == "Base" and sc:hasTag(ItemTag.FIREARM) then
                local full = sc:getFullName()
                local name = sc:getName()
                if full and not vanilla[name] and not black[full] and not black[name] then
                    list[#list + 1] = full
                end
            end
        end
    end
    cachedGunPool = list
    return list
end

-- MOD attachments: Gunpart-module weapon parts, excluding the Clip class and
-- the blacklist.
function MFSTrade.GetModPartPool()
    if cachedPartPool then return cachedPartPool end
    local black = {}
    for _, t in ipairs(MFSTrade.Config.PartBlacklist) do black[t] = true; black["Gunpart." .. t] = true end

    local list = {}
    local items = getAllItems()
    if items then
        for i = 0, items:size() - 1 do
            local sc = items:get(i)
            if sc and sc:getModuleName() == "Gunpart" then
                local full = sc:getFullName()
                local name = sc:getName()
                if full and not black[full] and not black[name] then
                    local ok, part = pcall(instanceItem, full)
                    if ok and part and instanceof(part, "WeaponPart") and part:getPartType() ~= "Clip" then
                        list[#list + 1] = full
                    end
                end
            end
        end
    end
    cachedPartPool = list
    return list
end

-- Category info for a sellable item type (used for deterministic pricing).
function MFSTrade.GetSellInfo(fullType)
    local cfg = MFSTrade.Config
    for _, t in ipairs(MFSTrade.GetBoxedBullets()) do
        if t == fullType then return { base = cfg.BulletBasePrice, float = cfg.BulletPriceFloat, isBox = true } end
    end
    for _, t in ipairs(MFSTrade.GetModGunPool()) do
        if t == fullType then return { base = cfg.GunPartBasePrice, float = cfg.GunPartPriceFloat, isBox = false } end
    end
    for _, t in ipairs(MFSTrade.GetModPartPool()) do
        if t == fullType then return { base = cfg.GunPartBasePrice, float = cfg.GunPartPriceFloat, isBox = false } end
    end
    return nil
end

-- Deterministic unit price for a sellable item (trader -> player).
function MFSTrade.ComputeSellPrice(seed, fullType, base, float)
    local r = MFSTrade.HashFloat(seed, "sellprice:" .. fullType)
    local mult = 1 + (r * 2 - 1) * float
    local price = math.floor(base * mult + 0.5)
    if price < 1 then price = 1 end
    return price
end

-- 贩卖 unit price: deterministic uniform random in [min, max] inclusive.
function MFSTrade.ComputeSellRange(seed, fullType, minP, maxP)
    if maxP < minP then
        minP, maxP = maxP, minP
    end
    local r = MFSTrade.HashFloat(seed, "sellprice:" .. fullType)
    local price = minP + math.floor(r * (maxP - minP + 1))
    if price > maxP then price = maxP end
    return price
end

function MFSTrade.GetSellUnitPrice(seed, fullType)
    local info = MFSTrade.GetSellInfo(fullType)
    if not info then return nil end
    return MFSTrade.ComputeSellPrice(seed, fullType, info.base, info.float)
end

-- ============================================================================
-- 收购 pool: vanilla items from the base game's generated item scripts
-- (media/scripts/generated/items/*.txt) whose pickup category (拾取物品分类) is
-- 纪念品 / Memento. Built from getAllItems(), which is available on BOTH client
-- and server, so no server round-trip is needed.
-- ============================================================================

local cachedVanillaPool = nil

function MFSTrade.GetVanillaPool()
    if cachedVanillaPool then return cachedVanillaPool end

    local exclude = {}
    for _, t in ipairs(MFSTrade.Config.ModBoxes) do exclude[t] = true; exclude["Base." .. t] = true end
    for _, t in ipairs(MFSTrade.Config.BuyExclusions) do exclude[t] = true; exclude["Base." .. t] = true end
    for _, t in ipairs(MFSTrade.Config.VanillaPoolExclusions) do exclude[t] = true; exclude["Base." .. t] = true end

    local list, seen = {}, {}
    local items = getAllItems()
    if items then
        for i = 0, items:size() - 1 do
            local sc = items:get(i)
            if sc then
                local full = sc:getFullName()
                local name = sc:getName()
                if full and name and not seen[full]
                    and not exclude[full] and not exclude[name]
                    and sc:getDisplayCategory() == "Memento"
                    and sc:getModuleName() ~= "Gunpart"
                    and not sc:hasTag(ItemTag.FIREARM)
                    and name:sub(1, 4) ~= "Mov_"
                    and name:sub(1, 13) ~= "Construction_" then
                    seen[full] = true
                    list[#list + 1] = full
                end
            end
        end
    end
    cachedVanillaPool = list
    return list
end

-- 收购 price (player -> trader): deterministic payout in [BuyMin, BuyMax].
function MFSTrade.GetBuyPrice(seed, fullType)
    local minP = MFSTrade.GetBuyMinPrice()
    local maxP = MFSTrade.GetBuyMaxPrice()
    if maxP < minP then
        minP, maxP = maxP, minP
    end
    local r = MFSTrade.HashFloat(seed, "buyprice:" .. fullType)
    local price = minP + math.floor(r * (maxP - minP + 1))
    if price > maxP then price = maxP end
    return price
end

-- ============================================================================
-- Deterministic list generation.
-- ============================================================================

-- Pick up to `n` distinct items from `pool` deterministically.
local function pickN(pool, seed, n, salt)
    local scored = {}
    for _, ft in ipairs(pool) do
        scored[#scored + 1] = { ft = ft, k = MFSTrade.HashFloat(seed, salt .. ft) }
    end
    table.sort(scored, function(a, b) return a.k < b.k end)
    local out = {}
    for i = 1, math.min(n, #scored) do
        out[#out + 1] = scored[i].ft
    end
    return out
end

-- 收购 list: 5 random vanilla items, always 1 copy, deterministic payout. When a
-- custom buy list is set in the sandbox it replaces the random pool entirely.
function MFSTrade.BuildBuyList(seed)
    seed = seed or MFSTrade.GetEffectiveSeed()
    local custom = MFSTrade.GetCustomBuyList()
    local items
    if #custom > 0 then
        items = custom
    else
        items = pickN(MFSTrade.GetVanillaPool(), seed, 5, "buy:")
    end
    local list = {}
    for _, ft in ipairs(items) do
        list[#list + 1] = {
            itemType = ft,
            count = 1,
            price = MFSTrade.GetBuyPrice(seed, ft), -- total payout for the whole batch
        }
    end
    return list
end

-- 贩卖 list: 7 random, distinct mod guns / attachments (always 1 copy). When a
-- custom sell list is set in the sandbox it replaces the random pool entirely.
function MFSTrade.BuildSellList(seed)
    seed = seed or MFSTrade.GetEffectiveSeed()
    local minP = MFSTrade.GetSellMinPrice()
    local maxP = MFSTrade.GetSellMaxPrice()

    local custom = MFSTrade.GetCustomSellList()
    local items
    if #custom > 0 then
        items = custom
    else
        local guns = MFSTrade.GetModGunPool()
        local parts = MFSTrade.GetModPartPool()

        -- One combined pool of mod guns + parts; pickN guarantees distinct items.
        local pool = {}
        for _, ft in ipairs(guns) do pool[#pool + 1] = ft end
        for _, ft in ipairs(parts) do pool[#pool + 1] = ft end
        items = pickN(pool, seed, 7, "sell:")
    end

    local list = {}
    for _, ft in ipairs(items) do
        list[#list + 1] = {
            itemType = ft,
            count = 1,
            unitPrice = MFSTrade.ComputeSellRange(seed, ft, minP, maxP),
        }
    end
    return list
end

-- ============================================================================
-- Inventory helpers (shared so the server can reuse them).
-- ============================================================================

function MFSTrade.HasRadio(player)
    local inv = player and player:getInventory()
    if not inv then return false end
    for _, t in ipairs(MFSTrade.Config.RadioItems) do
        if inv:getItemCountRecurse(t) > 0 then
            return true
        end
    end
    return false
end

function MFSTrade.GetMoney(player)
    local md = player and player:getModData()
    if not md then return 0 end
    return md[MFSTrade.MoneyKey] or 0
end

-- Add `count` of `fullType` to the player. Used for non-stackable goods
-- (ammo boxes / guns / parts); currency uses MFSTrade.GiveMoney below.
function MFSTrade.GiveItem(player, fullType, count)
    local inv = player:getInventory()
    count = count or 1
    for _ = 1, count do
        local item = inv:AddItem(fullType)
        -- In multiplayer the server is authoritative: AddItem only mutates the
        -- server's copy, so push the new item to the client(s) explicitly or it
        -- will never appear in their inventory.
        if item and isServer() then
            sendAddItemToContainer(inv, item)
        end
    end
    return true
end

-- Recursively remove `remaining` units of `fullType` from a container tree,
-- returning how many units are still left to remove.
local function removeFromContainer(inv, fullType, remaining)
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        if remaining <= 0 then break end
        local it = items:get(i)
        if it then
            if it:getFullType() == fullType then
                local c = it:getCount() or 1
                if c <= remaining then
                    remaining = remaining - c
                    inv:DoRemoveItem(it)
                    -- In multiplayer the server is authoritative: tell the
                    -- client(s) the item is gone so it does not linger in their
                    -- inventory view.
                    if isServer() then
                        sendRemoveItemFromContainer(inv, it)
                    end
                else
                    it:setCount(c - remaining)
                    -- Partial stack removal only changes the count; sync that.
                    if isServer() then
                        sendItemStats(it)
                    end
                    remaining = 0
                end
            elseif instanceof(it, "InventoryContainer") then
                remaining = removeFromContainer(it:getInventory(), fullType, remaining)
            end
        end
    end
    return remaining
end

-- Remove `count` of `fullType` from the player (recursively). True on success.
function MFSTrade.TakeItem(player, fullType, count)
    local inv = player:getInventory()
    return removeFromContainer(inv, fullType, count) <= 0
end

function MFSTrade.TakeMoney(player, amount)
    local md = player and player:getModData()
    if not md then return false end
    local cur = md[MFSTrade.MoneyKey] or 0
    if cur < amount then return false end
    md[MFSTrade.MoneyKey] = cur - amount
    return true
end

function MFSTrade.GiveMoney(player, amount)
    if amount <= 0 then return true end
    local md = player:getModData()
    md[MFSTrade.MoneyKey] = (md[MFSTrade.MoneyKey] or 0) + amount
    return true
end

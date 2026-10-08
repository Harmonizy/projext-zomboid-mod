--[[
    HARMONIE - From Garden to Plate
    Vitamin profiles for the winter foods in HARMONIE_GardenToPlate_Extras.txt
    (2026-10-08):
      Dried<Fruit>  one fresh fruit dried: the fresh fruit's own profile
                    (looked up from the database, so it follows any retune),
                    with vitamin C cut to 40 percent -- drying in air and
                    light destroys most of it; A, B, E, K mostly stay.
      BeanSprouts   per sprout: C 13 mg, K 33 mcg, B 1 mg (mung / soy sprouts
                    are a classic winter vitamin C source)
      BeanSproutsJar  4 sprouts' worth (the jar empties into 4 BeanSprouts)
      SproutingJar  soaking dried beans: the B of the beans, no C yet
                    (vitamin C only appears as the beans sprout)
      FishLiverOil  one jar: A 600 mcg, D 10 mcg, E 1 mg -- a strong A and D
                    source for anyone who fishes
]]--

require "HARMONIEGardenToPlate/HARMONIE_FoodVitaminDatabase"

local DB = HARMONIE_GTP.FoodVitaminDB
local function log(tag, fmt, ...)
    if HARMONIE_GTP.Log then return HARMONIE_GTP.Log(tag, fmt, ...) end
    local ok, msg = pcall(string.format, fmt, ...)
    print("[HARMONIE_GTP][" .. tag .. "] " .. (ok and msg or tostring(fmt)))
end
local dried = 0
local C_KEPT = 0.4

for _, fr in ipairs({ "Apple", "Pear", "Peach", "Mango", "Banana", "Cherry", "Grapes", "Pineapple" }) do
    local fresh = DB["Base." .. fr]
    if fresh then
        local p = {}
        for vit, amount in pairs(fresh) do
            p[vit] = vit == "C" and amount * C_KEPT or amount
        end
        DB["HARMONIEGardenToPlate.Dried" .. fr] = p
        dried = dried + 1
    else
        log("Foods", "WARNING no base vitamin profile for Base.%s -- Dried%s has no vitamins", fr, fr)
    end
end

DB["HARMONIEGardenToPlate.BeanSprouts"] = { C = 13, K = 33, B = 1 }
DB["HARMONIEGardenToPlate.BeanSproutsJar"] = { C = 52, K = 132, B = 4 }
DB["HARMONIEGardenToPlate.SproutingJar"] = { B = 2 }
DB["HARMONIEGardenToPlate.FishLiverOil"] = { A = 600, D = 10, E = 1 }
log("Foods", "extra foods: %d dried fruits, BeanSprouts, BeanSproutsJar, SproutingJar, FishLiverOil added to the vitamin table", dried)

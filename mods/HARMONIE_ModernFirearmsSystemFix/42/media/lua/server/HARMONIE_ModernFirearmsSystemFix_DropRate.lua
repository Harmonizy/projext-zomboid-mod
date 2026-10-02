--[[
    ModernFirearmsSystem (Workshop 3633421539, mod id "ModernFirearmsSystem")
    adds every one of its ~230 guns and ammo items to vanilla loot containers
    via ProceduralDistributions["list"][Container].items -- confirmed by
    reading its own media/lua/server/item/gun/*.lua, ammo/*.lua and
    ammoF/*.lua files directly (e.g. AK103_cat.lua inserts "Base.AK103_cat"
    into ~18 vanilla container lists with a hardcoded weight of 0.13, every
    time, with no sandbox multiplier -- only a per-gun on/off toggle exists
    in the mod's own sandbox-options.txt, no rate control).

    Since ProceduralDistributions is a plain Lua table (not a Java object),
    and every one of that mod's inserts already ran by the time this file's
    mod loads (this mod requires ModernFirearmsSystem, so it loads after --
    same load-order guarantee HARMONIE's other patch mods rely on), this
    file scales the weight of every entry whose item name is one of this
    mod's own guns/ammo (listed below, extracted from the mod's own
    media/scripts/gun/**/*.txt and media/scripts/Ammo/*.txt item
    declarations) by a single sandbox multiplier -- leaving every vanilla
    item's own weight in the same containers untouched.

    Run from the distribution-merge events (see the bottom of this file):
    every mod's file-load Lua (including that mod's ~165 distribution-
    editing files) has executed by then, and the loot is not built yet.

    Scope: guns and ammo only. Attachments/parts (media/lua/server/item/Part,
    ~236 more items) are NOT included -- left at the mod's own hardcoded
    rate. Extend HARMONIE_ModernFirearmsSystemFix_Items below if you want
    those scaled too.
]]--

require 'Items/ProceduralDistributions'

local HARMONIE_ModernFirearmsSystemFix_Items = {
    ["AA12_cat"] = true,
    ["AEK971_cat"] = true,
    ["AEK971_cat_Drum"] = true,
    ["AK103_cat"] = true,
    ["AK103_cat_Drum"] = true,
    ["AK12_cat"] = true,
    ["AK12_cat_Drum"] = true,
    ["AKS74U_cat"] = true,
    ["AKS74U_cat_Drum"] = true,
    ["AMB17_cat"] = true,
    ["AMB17_cat_Drum"] = true,
    ["AN94_cat"] = true,
    ["AN94_cat_Drum"] = true,
    ["AR57Drum_cat"] = true,
    ["ARX200_cat"] = true,
    ["ARX200_cat_Drum"] = true,
    ["AS_VAL_MOD4_cat"] = true,
    ["AS_VAL_MOD4_cat_Drum"] = true,
    ["AS_VAL_cat"] = true,
    ["AS_VAL_cat_Drum"] = true,
    ["AWMClip"] = true,
    ["AWM_cat"] = true,
    ["AX50_cat"] = true,
    ["AX50_cat_Drum"] = true,
    ["A_58bullets"] = true,
    ["Ammo145"] = true,
    ["Ammo44"] = true,
    ["Ammo45"] = true,
    ["Ammo50"] = true,
    ["Ammo545"] = true,
    ["Ammo556"] = true,
    ["Ammo58"] = true,
    ["Ammo68"] = true,
    ["Ammo762"] = true,
    ["Ammo86"] = true,
    ["Ammo9mm"] = true,
    ["AmmoGrenade"] = true,
    ["AmmoReloadingKit"] = true,
    ["Anaconda_cat"] = true,
    ["AssaultRifle"] = true,
    ["AssaultRifle2"] = true,
    ["AssaultRifle_Drum"] = true,
    ["BAR_cat"] = true,
    ["BRAuto5_cat"] = true,
    ["BalanceScale"] = true,
    ["BerettaM93R_cat"] = true,
    ["BerettaM93R_cat_Drum"] = true,
    ["Berthier_cat"] = true,
    ["Bullets145"] = true,
    ["Bullets145Box"] = true,
    ["Bullets145Clip"] = true,
    ["Bullets38"] = true,
    ["Bullets38Box"] = true,
    ["Bullets38Carton"] = true,
    ["Bullets44"] = true,
    ["Bullets44Box"] = true,
    ["Bullets44Carton"] = true,
    ["Bullets45"] = true,
    ["Bullets45Box"] = true,
    ["Bullets45Carton"] = true,
    ["Bullets50"] = true,
    ["Bullets50Box"] = true,
    ["Bullets50Clip"] = true,
    ["Bullets86"] = true,
    ["Bullets86Box"] = true,
    ["Bullets9mm"] = true,
    ["Bullets9mmBox"] = true,
    ["Bullets9mmCarton"] = true,
    ["C96_cat"] = true,
    ["ChiappaTripleThreat_cat"] = true,
    ["Christine45_cat"] = true,
    ["CrossbowBolt"] = true,
    ["CrossbowBoltBox"] = true,
    ["CrossbowClip"] = true,
    ["CycloneAK_cat"] = true,
    ["DP12_cat"] = true,
    ["DoubleBarrelShotgun"] = true,
    ["EMP_cat"] = true,
    ["FAL_cat"] = true,
    ["FN57_cat"] = true,
    ["FN57_cat_Drum"] = true,
    ["FN_Evolys_cat"] = true,
    ["G17_cat"] = true,
    ["G17_cat_Drum"] = true,
    ["G18_cat"] = true,
    ["G18_cat_Drum"] = true,
    ["G19_cat"] = true,
    ["G19_cat_Drum"] = true,
    ["G34_cat"] = true,
    ["G34_cat_Drum"] = true,
    ["GM6_cat"] = true,
    ["Groza_cat"] = true,
    ["Groza_cat_Drum"] = true,
    ["HK416_cat"] = true,
    ["HK416_cat_Drum"] = true,
    ["HK51_cat"] = true,
    ["HK51_cat_Drum"] = true,
    ["HoneyBadger_cat"] = true,
    ["HoneyBadger_cat_Drum"] = true,
    ["HuntingRifle"] = true,
    ["KS1_KAC_cat"] = true,
    ["KS1_KAC_cat_Drum"] = true,
    ["KrissVector_cat"] = true,
    ["KrissVector_cat_Drum"] = true,
    ["LWMMG_cat"] = true,
    ["LebelM1886_cat"] = true,
    ["M134_cat"] = true,
    ["M14Clip"] = true,
    ["M14Drum_cat"] = true,
    ["M14_Albedo"] = true,
    ["M14_Albedo_Drum"] = true,
    ["M16D_cat"] = true,
    ["M1866_cat"] = true,
    ["M1873_cat"] = true,
    ["M1887_cat"] = true,
    ["M1918_cat"] = true,
    ["M1919a6_cat"] = true,
    ["M1Garand_cat"] = true,
    ["M200_cat"] = true,
    ["M240BeltBox"] = true,
    ["M240_cat"] = true,
    ["M4A1S_cat"] = true,
    ["M4A1S_cat_Drum"] = true,
    ["M4Mk18_cat"] = true,
    ["M4Mk18_cat_Drum"] = true,
    ["M500_cat"] = true,
    ["M7_cat"] = true,
    ["M7_cat_Drum"] = true,
    ["M82_cat"] = true,
    ["M82_cat_Drum"] = true,
    ["M870_cat"] = true,
    ["M91Drum_cat"] = true,
    ["M91_cat"] = true,
    ["M9A4_cat"] = true,
    ["M9A4_cat_Drum"] = true,
    ["MCX_cat"] = true,
    ["MCX_cat_Drum"] = true,
    ["MG42Drum_cat"] = true,
    ["MK12_cat"] = true,
    ["MK12_cat_Drum"] = true,
    ["MK18_cat"] = true,
    ["MP7_cat"] = true,
    ["MP7_cat_Drum"] = true,
    ["MTL30_cat"] = true,
    ["Marlin1894"] = true,
    ["Mosin"] = true,
    ["NoveskeN4_cat"] = true,
    ["NoveskeN4_cat_Drum"] = true,
    ["PKM_cat"] = true,
    ["Pistol"] = true,
    ["Pistol2"] = true,
    ["Pistol2_Drum"] = true,
    ["Pistol3"] = true,
    ["Pistol_Drum"] = true,
    ["QBU191_cat"] = true,
    ["QBU191_cat_Drum"] = true,
    ["QBU203_cat"] = true,
    ["QBZ191_cat"] = true,
    ["QBZ191_cat_Drum"] = true,
    ["QBZ192_cat"] = true,
    ["QBZ192_cat_Drum"] = true,
    ["QJY201_cat"] = true,
    ["QSZ_92G"] = true,
    ["REAPR_cat"] = true,
    ["ROSE_cat"] = true,
    ["RPK16_cat"] = true,
    ["RPK16_cat_Drum"] = true,
    ["RSC_cat"] = true,
    ["ReloadingPress"] = true,
    ["Requiem_cat"] = true,
    ["Revolver"] = true,
    ["Revolver_Long"] = true,
    ["SAI_GRY_cat"] = true,
    ["SAI_GRY_cat_Drum"] = true,
    ["SG553_cat"] = true,
    ["SG553_cat_Drum"] = true,
    ["SIGP226_cat"] = true,
    ["SIGP226_cat_Drum"] = true,
    ["SRM3_cat"] = true,
    ["SRM3_cat_Drum"] = true,
    ["SVD_cat"] = true,
    ["SVT40_cat"] = true,
    ["SW629_cat"] = true,
    ["Saiga12_cat"] = true,
    ["ScarH_cat"] = true,
    ["ScarH_cat_Drum"] = true,
    ["Shotgun"] = true,
    ["ShotgunSawnoff"] = true,
    ["ShotgunShells"] = true,
    ["ShotgunShellsBox"] = true,
    ["ShotgunShellsCarton"] = true,
    ["SnipeX_T_Rex_cat"] = true,
    ["Striker12_cat"] = true,
    ["TTI_Benelli_M4_cat"] = true,
    ["Taran2011_cat"] = true,
    ["Taran2011_cat_Drum"] = true,
    ["Taurus_cat"] = true,
    ["Thompson_cat"] = true,
    ["Thoridal"] = true,
    ["Type81_cat"] = true,
    ["Type81_cat_Drum"] = true,
    ["TyphoonF12Mag"] = true,
    ["UMP45_cat"] = true,
    ["UMP45_cat_Drum"] = true,
    ["URG_S_cat"] = true,
    ["URG_S_cat_Drum"] = true,
    ["UTS15_cat"] = true,
    ["VSSM_cat"] = true,
    ["VSSM_cat_Drum"] = true,
    ["VarmintRifle"] = true,
    ["XM109_cat"] = true,
    ["ar_10_cat"] = true,
    ["ar_10_cat_Drum"] = true,
    ["bolter_cat"] = true,
    ["interceptor_cat"] = true,
    ["lee_enfield_cat"] = true,
    ["lewis_cat"] = true,
    ["lugerP08_cat"] = true,
    ["m1903_cat"] = true,
    ["mg338_cat"] = true,
    ["minigun_cat"] = true,
    ["mk47_cat"] = true,
    ["mk47_cat_Drum"] = true,
    ["mp5_cat"] = true,
    ["mp5_cat_Drum"] = true,
    ["nagant_m1895_cat"] = true,
    ["origin12_cat"] = true,
    ["usp45_cat"] = true,
    ["usp45_cat_Drum"] = true,
    ["uzi_cat"] = true,
    ["uzi_cat_Drum"] = true,
}

local function getMultiplier()
    if SandboxVars.HARMONIE_ModernFirearmsSystemFix and SandboxVars.HARMONIE_ModernFirearmsSystemFix.DropRateMultiplier then
        return SandboxVars.HARMONIE_ModernFirearmsSystemFix.DropRateMultiplier
    end
    return 1.0
end

-- each entry is scaled once, however many times this runs: [items table]
-- = { [weight index] = true } (weak keys, so a dropped table is not held)
local done = setmetatable({}, { __mode = "k" })
local function scaleDropRates()
    if not ProceduralDistributions or not ProceduralDistributions.list then
        print("HARMONIE ModernFirearmsSystem Fix: ProceduralDistributions.list not found -- is ModernFirearmsSystem installed and enabled?")
        return
    end

    local multiplier = getMultiplier()
    if multiplier == 1.0 then return end

    local scaledCount = 0
    for _, containerData in pairs(ProceduralDistributions.list) do
        if containerData and containerData.items then
            local items = containerData.items
            local mark = done[items]
            if not mark then mark = {}; done[items] = mark end
            for i = 1, #items - 1, 2 do
                local name = items[i]
                local weight = items[i + 1]
                if not mark[i + 1] and type(name) == "string" and type(weight) == "number" then
                    local shortName = name:match("^Base%.(.+)$")
                    if shortName and HARMONIE_ModernFirearmsSystemFix_Items[shortName] then
                        items[i + 1] = weight * multiplier
                        mark[i + 1] = true
                        scaledCount = scaledCount + 1
                    end
                end
            end
        end
    end

    print(string.format("HARMONIE ModernFirearmsSystem Fix: scaled %d loot entries by x%.2f.", scaledCount, multiplier))
end

-- 2026-10-02 (MP audit): OnGameStart was the wrong place: it is a CLIENT
-- event (a dedicated server, where loot is rolled, never fires it), and the
-- game builds its loot tables from ProceduralDistributions during world
-- load, before OnGameStart. Now it runs at both distribution-merge events
-- (they fire in single player and on the server): OnPreDistributionMerge
-- is where EHR adds its own loot and is known to reach the loot tables;
-- OnPostDistributionMerge catches anything added later. Every entry is
-- scaled only once (see `done`), so running twice is safe.
local hooked = false
if Events.OnPreDistributionMerge then Events.OnPreDistributionMerge.Add(scaleDropRates); hooked = true end
if Events.OnPostDistributionMerge then Events.OnPostDistributionMerge.Add(scaleDropRates); hooked = true end
if not hooked then Events.OnGameStart.Add(scaleDropRates) end

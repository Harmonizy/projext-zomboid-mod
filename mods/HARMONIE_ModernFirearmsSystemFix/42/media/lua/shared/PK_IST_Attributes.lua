-- PolyKentucky / ModernFirearmsSystem: IST 作者数据，2026-10-08
-- 放入 ModernFirearmsSystem/42/media/lua/shared/PK_IST_Attributes.lua
-- 沿用 2026-10-07 建议值。不修改原生伤害、弹种、重量或其他物品字段。
local loaded=false
local function load()
 if loaded then return end
 local mods=getActivatedMods()
 if not mods or not (mods:contains("ISeeThem") or mods:contains("\\ISeeThem")) then return end
 local ok=pcall(require,"ISTAttributeRegistry")
 if not ok or not ISTAttributeRegistry then return end
 local R=ISTAttributeRegistry
-- 9mm（模组共用弹种） | AmmoType=base:bullets_9mm
R.ammo("Base.Bullets9mm", {
    istinitial = { mode = "base", value = 360 },
    istrecoil = { mode = "base", value = 180 },
    istpenetra = { mode = "base", value = 16 },
    istpower = { mode = "base", value = 75 },
    -- istHMEfficacy：弹药不支持此项；不要注册。
})

-- .45（模组共用弹种） | AmmoType=base:bullets_45
R.ammo("Base.Bullets45", {
    istinitial = { mode = "base", value = 330 },
    istrecoil = { mode = "base", value = 230 },
    istpenetra = { mode = "base", value = 15 },
    istpower = { mode = "base", value = 85 },
    -- istHMEfficacy：弹药不支持此项；不要注册。
})

-- .44（含狙击枪共用，枪级修正） | AmmoType=base:bullets_44
R.ammo("Base.Bullets44", {
    istinitial = { mode = "base", value = 400 },
    istrecoil = { mode = "base", value = 330 },
    istpenetra = { mode = "base", value = 25 },
    istpower = { mode = "base", value = 105 },
    -- istHMEfficacy：弹药不支持此项；不要注册。
})

-- 5.56 | AmmoType=base:bullets_556
R.ammo("Base.556Bullets", {
    istinitial = { mode = "base", value = 450 },
    istrecoil = { mode = "base", value = 200 },
    istpenetra = { mode = "base", value = 40 },
    istpower = { mode = "base", value = 100 },
    -- istHMEfficacy：弹药不支持此项；不要注册。
})

-- 7.62／.308（模组共用） | AmmoType=base:bullets_308
R.ammo("Base.308Bullets", {
    istinitial = { mode = "base", value = 480 },
    istrecoil = { mode = "base", value = 320 },
    istpenetra = { mode = "base", value = 60 },
    istpower = { mode = "base", value = 125 },
    -- istHMEfficacy：弹药不支持此项；不要注册。
})

-- 模组重定义为6.8mm，非.38建议值 | AmmoType=base:bullets_38
R.ammo("Base.Bullets38", {
    istinitial = { mode = "base", value = 475 },
    istrecoil = { mode = "base", value = 240 },
    istpenetra = { mode = "base", value = 55 },
    istpower = { mode = "base", value = 115 },
    -- istHMEfficacy：弹药不支持此项；不要注册。
})

-- 5.45 | AmmoType=efk:cat_545bullets
R.ammo("Base.545Bullets", {
    istinitial = { mode = "base", value = 455 },
    istrecoil = { mode = "base", value = 195 },
    istpenetra = { mode = "base", value = 38 },
    istpower = { mode = "base", value = 98 },
    -- istHMEfficacy：弹药不支持此项；不要注册。
})

-- 5.8mm（步枪与手枪共用） | AmmoType=efk:cat_58bullets
R.ammo("Base.A_58bullets", {
    istinitial = { mode = "base", value = 460 },
    istrecoil = { mode = "base", value = 205 },
    istpenetra = { mode = "base", value = 43 },
    istpower = { mode = "base", value = 105 },
    -- istHMEfficacy：弹药不支持此项；不要注册。
})

-- 8.6mm／.338 | AmmoType=efk:cat_bullets86
R.ammo("Base.Bullets86", {
    istinitial = { mode = "base", value = 510 },
    istrecoil = { mode = "base", value = 380 },
    istpenetra = { mode = "base", value = 95 },
    istpower = { mode = "base", value = 150 },
    -- istHMEfficacy：弹药不支持此项；不要注册。
})

-- .50 BMG基准；非.50 AE | AmmoType=efk:cat_bullets50
R.ammo("Base.Bullets50", {
    istinitial = { mode = "base", value = 540 },
    istrecoil = { mode = "base", value = 500 },
    istpenetra = { mode = "base", value = 150 },
    istpower = { mode = "base", value = 185 },
    -- istHMEfficacy：弹药不支持此项；不要注册。
})

-- 14.5mm | AmmoType=efk:cat_bullets145
R.ammo("Base.Bullets145", {
    istinitial = { mode = "base", value = 560 },
    istrecoil = { mode = "base", value = 620 },
    istpenetra = { mode = "base", value = 185 },
    istpower = { mode = "base", value = 220 },
    -- istHMEfficacy：弹药不支持此项；不要注册。
})

-- 霰弹：威力按每颗弹丸 | AmmoType=base:shotgun_shells
R.ammo("Base.ShotgunShells", {
    istinitial = { mode = "base", value = 400 },
    istrecoil = { mode = "base", value = 480 },
    istpenetra = { mode = "base", value = 5 },
    istpower = { mode = "base", value = 25 },
    -- istHMEfficacy：弹药不支持此项；不要注册。
})

-- 北方工业 56S 型步枪 | scripts/gun/762/cat_56S.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.56S_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 53 },
})

-- Kar98k 栓动步枪 | scripts/gun/762/cat_98k.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.98k_cat", {
    istinitial = { mode = "add", value = 25 },
    istrecoil = { mode = "add", value = 45 },
    istpenetra = { mode = "add", value = 20 },
    istpower = { mode = "add", value = 20 },
    istHMEfficacy = { mode = "base", value = 53 },
})

-- AK-103 突击步枪 | scripts/gun/762/cat_AK103.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.AK103_cat", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = -4 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- AK-103 突击步枪 (弹鼓) | scripts/gun/762/cat_AK103_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.AK103_cat_Drum", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = -4 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- 贝瑞塔 ARX200 战斗步枪 | scripts/gun/762/cat_ARX200.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.ARX200_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 49 },
})

-- 贝瑞塔 ARX200 战斗步枪 (弹鼓) | scripts/gun/762/cat_ARX200_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.ARX200_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 45 },
})

-- M14 步枪 | scripts/gun/762/cat_1_M14.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.AssaultRifle2", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 51 },
})

-- 勃朗宁自动步枪 | scripts/gun/762/cat_BAR.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.BAR_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = -30 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 29 },
})

-- 贝蒂埃步兵步枪 | scripts/gun/762/cat_Berthier.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.Berthier_cat", {
    istinitial = { mode = "add", value = 25 },
    istrecoil = { mode = "add", value = 45 },
    istpenetra = { mode = "add", value = 20 },
    istpower = { mode = "add", value = 20 },
    istHMEfficacy = { mode = "base", value = 53 },
})

-- C96 毛瑟扫把柄手枪 | scripts/gun/762/cat_C96.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base
R.weapon("Base.C96_cat", {
    istinitial = { mode = "base", value = 390 },
    istrecoil = { mode = "base", value = 210 },
    istpenetra = { mode = "base", value = 20 },
    istpower = { mode = "base", value = 80 },
    istHMEfficacy = { mode = "base", value = 69 },
})

-- 飓风 AK 突击步枪 | scripts/gun/762/cat_CycloneAK.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.CycloneAK_cat", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = -4 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- FN FAL 战斗步枪 | scripts/gun/762/cat_FAL.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.FAL_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 50 },
})

-- FN Evolys 轻机枪 | scripts/gun/762/cat_FN_Evolys.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.FN_Evolys_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -20 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 40 },
})

-- OTs-14 Groza 突击步枪 | scripts/gun/762/cat_Groza.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.Groza_cat", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = -4 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 60 },
})

-- OTs-14 Groza 突击步枪 (弹鼓) | scripts/gun/762/cat_Groza_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.Groza_cat_Drum", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = -4 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- HK51 卡宾枪 | scripts/gun/762/cat_HK51.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.HK51_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 58 },
})

-- HK51 卡宾枪 (弹鼓) | scripts/gun/762/cat_HK51_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.HK51_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 54 },
})

-- Honey Badger 个人防卫武器 | scripts/gun/762/HoneyBadger_cat.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.HoneyBadger_cat", {
    istinitial = { mode = "base", value = 380 },
    istrecoil = { mode = "base", value = 230 },
    istpenetra = { mode = "base", value = 35 },
    istpower = { mode = "base", value = 105 },
    istHMEfficacy = { mode = "base", value = 60 },
})

-- Honey Badger 个人防卫武器 (弹鼓) | scripts/gun/762/HoneyBadger_cat_Drum.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪；弹鼓版本人机-4（装饰弹匣不重复扣）
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.HoneyBadger_cat_Drum", {
    istinitial = { mode = "base", value = 380 },
    istrecoil = { mode = "base", value = 230 },
    istpenetra = { mode = "base", value = 35 },
    istpower = { mode = "base", value = 105 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- 雷明顿 MSR | scripts/gun/762/cat_1_MSR.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.HuntingRifle", {
    istinitial = { mode = "add", value = 15 },
    istrecoil = { mode = "add", value = 15 },
    istpenetra = { mode = "add", value = 10 },
    istpower = { mode = "add", value = 10 },
    istHMEfficacy = { mode = "base", value = 49 },
})

-- Lebel M1886 步枪 | scripts/gun/762/cat_LebelM1886.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.LebelM1886_cat", {
    istinitial = { mode = "add", value = 25 },
    istrecoil = { mode = "add", value = 40 },
    istpenetra = { mode = "add", value = 20 },
    istpower = { mode = "add", value = 20 },
    istHMEfficacy = { mode = "base", value = 51 },
})

-- M14 Albedo 步枪 | scripts/gun/762/cat_m14_Albedo.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M14_Albedo", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 45 },
})

-- M14 Albedo 步枪 (弹鼓) | scripts/gun/762/cat_m14_Albedo_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.M14_Albedo_Drum", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 41 },
})

-- 现代化 BAR M1918 | scripts/gun/762/cat_M1918.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M1918_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = -25 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 31 },
})

-- M1919A6 机枪 | scripts/gun/762/cat_M1919a6.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M1919a6_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = -25 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 31 },
})

-- M1 加兰德半自动步枪 | scripts/gun/762/cat_M1Garand.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M1Garand_cat", {
    istinitial = { mode = "add", value = 25 },
    istrecoil = { mode = "add", value = 40 },
    istpenetra = { mode = "add", value = 20 },
    istpower = { mode = "add", value = 20 },
    istHMEfficacy = { mode = "base", value = 50 },
})

-- M240 通用机枪 | scripts/gun/762/cat_M240.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M240_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = -15 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 38 },
})

-- MG3通用机枪 | scripts/gun/762/cat_MG3.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.MG3_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = -25 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 31 },
})

-- PKM 通用机枪 | scripts/gun/762/cat_PKM.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.PKM_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = -25 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 31 },
})

-- QBU-203 步枪 | scripts/gun/762/cat_QBU203.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.QBU203_cat", {
    istinitial = { mode = "add", value = 25 },
    istrecoil = { mode = "add", value = 30 },
    istpenetra = { mode = "add", value = 20 },
    istpower = { mode = "add", value = 20 },
    istHMEfficacy = { mode = "base", value = 45 },
})

-- QJY201 通用机枪 | scripts/gun/58/cat_QJY201.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.QJY201_cat", {
    istinitial = { mode = "add", value = -15 },
    istrecoil = { mode = "add", value = -50 },
    istpenetra = { mode = "add", value = -10 },
    istpower = { mode = "add", value = -10 },
    istHMEfficacy = { mode = "base", value = 37 },
})

-- RPK-16 轻机枪 | scripts/gun/762/cat_RPK16.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.RPK16_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 49 },
})

-- RPK-16 轻机枪 (弹鼓) | scripts/gun/762/cat_RPK16_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.RPK16_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 45 },
})

-- RSC 步兵步枪 | scripts/gun/762/cat_RSC.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.RSC_cat", {
    istinitial = { mode = "add", value = 25 },
    istrecoil = { mode = "add", value = 40 },
    istpenetra = { mode = "add", value = 20 },
    istpower = { mode = "add", value = 20 },
    istHMEfficacy = { mode = "base", value = 49 },
})

-- SVD 德拉古诺夫狙击步枪 | scripts/gun/762/cat_SVD.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.SVD_cat", {
    istinitial = { mode = "add", value = 10 },
    istrecoil = { mode = "add", value = 10 },
    istpenetra = { mode = "add", value = 8 },
    istpower = { mode = "add", value = 10 },
    istHMEfficacy = { mode = "base", value = 46 },
})

-- SVT-40 半自动步枪 | scripts/gun/762/cat_SVT40.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.SVT40_cat", {
    istinitial = { mode = "add", value = 10 },
    istrecoil = { mode = "add", value = 15 },
    istpenetra = { mode = "add", value = 8 },
    istpower = { mode = "add", value = 10 },
    istHMEfficacy = { mode = "base", value = 53 },
})

-- FN SCAR-H 战斗步枪 | scripts/gun/762/cat_ScarH.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.ScarH_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 54 },
})

-- FN SCAR-H 战斗步枪 (弹鼓) | scripts/gun/762/cat_ScarH_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.ScarH_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 50 },
})

-- 81 式突击步枪 | scripts/gun/762/cat_Type81.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.Type81_cat", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = -4 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- 81 式突击步枪 (弹鼓) | scripts/gun/762/cat_Type81_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.Type81_cat_Drum", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = -4 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- 奈特军械 M110 SASS | scripts/gun/762/cat_AR_10.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.ar_10_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 49 },
})

-- 奈特军械 M110 SASS (弹鼓) | scripts/gun/762/cat_AR_10_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
-- 原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.ar_10_cat_Drum", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 45 },
})

-- 李-恩菲尔德步枪 | scripts/gun/762/cat_lee_enfield.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.lee_enfield_cat", {
    istinitial = { mode = "add", value = 25 },
    istrecoil = { mode = "add", value = 40 },
    istpenetra = { mode = "add", value = 20 },
    istpower = { mode = "add", value = 20 },
    istHMEfficacy = { mode = "base", value = 51 },
})

-- 路易斯轻机枪 | scripts/gun/762/cat_lewis.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.lewis_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 36 },
})

-- 春田 M1903 步枪 | scripts/gun/762/cat_m1903.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.m1903_cat", {
    istinitial = { mode = "add", value = 25 },
    istrecoil = { mode = "add", value = 45 },
    istpenetra = { mode = "add", value = 20 },
    istpower = { mode = "add", value = 20 },
    istHMEfficacy = { mode = "base", value = 53 },
})

-- CMMG Mk47“突变者”步枪 | scripts/gun/762/cat_MK47.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.mk47_cat", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = -4 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- CMMG Mk47“突变者”步枪 (弹鼓) | scripts/gun/762/cat_MK47_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.mk47_cat_Drum", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = -4 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- 纳甘 M1895 左轮手枪 | scripts/gun/762/cat_M1895.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.nagant_m1895_cat", {
    istinitial = { mode = "base", value = 330 },
    istrecoil = { mode = "base", value = 220 },
    istpenetra = { mode = "base", value = 14 },
    istpower = { mode = "base", value = 75 },
    istHMEfficacy = { mode = "base", value = 71 },
})

-- ots38 | scripts/gun/762/cat_ots38.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.ots38_cat", {
    istinitial = { mode = "base", value = 330 },
    istrecoil = { mode = "base", value = 250 },
    istpenetra = { mode = "base", value = 18 },
    istpower = { mode = "base", value = 85 },
    istHMEfficacy = { mode = "base", value = 68 },
})

-- AEK-971 突击步枪 | scripts/gun/545/cat_AEK971.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.AEK971_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 2 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- AEK-971 突击步枪 (弹鼓) | scripts/gun/545/cat_AEK971_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.AEK971_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 2 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- AK-12 突击步枪 | scripts/gun/545/cat_AK12.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.AK12_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 2 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- AK-12 突击步枪 (弹鼓) | scripts/gun/545/cat_AK12_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.AK12_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 2 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- AKS-74U 卡宾枪 | scripts/gun/545/cat_AKS74U.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.AKS74U_cat", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = -3 },
    istpower = { mode = "add", value = -3 },
    istHMEfficacy = { mode = "base", value = 60 },
})

-- AKS-74U 卡宾枪 (弹鼓) | scripts/gun/545/cat_AKS74U_Drum.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.AKS74U_cat_Drum", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = -3 },
    istpower = { mode = "add", value = -3 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- AN-94 突击步枪 | scripts/gun/545/cat_AN94.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.AN94_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 2 },
    istHMEfficacy = { mode = "base", value = 53 },
})

-- AN-94 突击步枪 (弹鼓) | scripts/gun/545/cat_AN94_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.AN94_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 2 },
    istHMEfficacy = { mode = "base", value = 49 },
})

-- M16 突击步枪 | scripts/gun/556/cat_1_M16.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.AssaultRifle", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 5 },
    istpenetra = { mode = "add", value = 2 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- M16 突击步枪 (弹鼓) | scripts/gun/556/cat_1_M16_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.AssaultRifle_Drum", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 5 },
    istpenetra = { mode = "add", value = 2 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- HK416 突击步枪 | scripts/gun/556/cat_HK416.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.HK416_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 55 },
})

-- HK416 突击步枪 (弹鼓) | scripts/gun/556/cat_HK416_Drum.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.HK416_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 51 },
})

-- 奈特军械 KS-1 突击步枪 | scripts/gun/556/cat_KS1_KAC.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.KS1_KAC_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 57 },
})

-- 奈特军械 KS-1 突击步枪 (弹鼓) | scripts/gun/556/cat_KS1_KAC_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.KS1_KAC_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 53 },
})

-- M16D 突击步枪 | scripts/gun/556/cat_M16D.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M16D_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 5 },
    istpenetra = { mode = "add", value = 2 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- M4A1-S 卡宾枪 | scripts/gun/556/cat_M4A1S.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M4A1S_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 59 },
})

-- M4A1-S 卡宾枪 (弹鼓) | scripts/gun/556/cat_M4A1S_Drum.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.M4A1S_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 55 },
})

-- MK18 卡宾枪 | scripts/gun/556/cat_M4Mk18.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M4Mk18_cat", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = -4 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 60 },
})

-- MK18 卡宾枪 (弹鼓) | scripts/gun/556/cat_M4Mk18_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.M4Mk18_cat_Drum", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = -4 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- HK121 通用机枪 | scripts/gun/556/cat_M91.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M91_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 43 },
})

-- SIG Sauer MCX 卡宾枪 | scripts/gun/556/cat_MCX.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.MCX_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 60 },
})

-- SIG Sauer MCX 卡宾枪 (弹鼓) | scripts/gun/556/cat_MCX_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.MCX_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- Mk 12 特种用途步枪 | scripts/gun/556/cat_MK12.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.MK12_cat", {
    istinitial = { mode = "add", value = 10 },
    istrecoil = { mode = "add", value = 10 },
    istpenetra = { mode = "add", value = 5 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 51 },
})

-- Mk 12 特种用途步枪 (弹鼓) | scripts/gun/556/cat_MK12_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.MK12_cat_Drum", {
    istinitial = { mode = "add", value = 10 },
    istrecoil = { mode = "add", value = 10 },
    istpenetra = { mode = "add", value = 5 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 47 },
})

-- Noveske N4 卡宾枪 | scripts/gun/556/cat_NoveskeN4.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.NoveskeN4_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 59 },
})

-- Noveske N4 卡宾枪 (弹鼓) | scripts/gun/556/cat_NoveskeN4_Drum.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.NoveskeN4_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 55 },
})

-- Salient Arms GRY 步枪 | scripts/gun/556/cat_SAI_GRY.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.SAI_GRY_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 57 },
})

-- Salient Arms GRY 步枪 (弹鼓) | scripts/gun/556/cat_SAI_GRY_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.SAI_GRY_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 53 },
})

-- SIG SG 553 卡宾枪 | scripts/gun/556/cat_SG553.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.SG553_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 57 },
})

-- SIG SG 553 卡宾枪 (弹鼓) | scripts/gun/556/cat_SG553_Drum.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.SG553_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 53 },
})

-- URG-S 突击步枪 | scripts/gun/556/cat_URG_S_cat.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.URG_S_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 5 },
    istpenetra = { mode = "add", value = 2 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 58 },
})

-- URG-S 突击步枪 (弹鼓) | scripts/gun/556/cat_URG_S_cat_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.URG_S_cat_Drum", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 5 },
    istpenetra = { mode = "add", value = 2 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 54 },
})

-- MSR700 步枪 | scripts/gun/223/cat_1_MSR2.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.VarmintRifle", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 10 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 57 },
})

-- QBU-191 精确射手步枪 | scripts/gun/58/cat_QBU191.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.QBU191_cat", {
    istinitial = { mode = "add", value = 15 },
    istrecoil = { mode = "add", value = 15 },
    istpenetra = { mode = "add", value = 7 },
    istpower = { mode = "add", value = 10 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- QBU-191 精确射手步枪 (弹鼓) | scripts/gun/58/cat_QBU191_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.QBU191_cat_Drum", {
    istinitial = { mode = "add", value = 15 },
    istrecoil = { mode = "add", value = 15 },
    istpenetra = { mode = "add", value = 7 },
    istpower = { mode = "add", value = 10 },
    istHMEfficacy = { mode = "base", value = 48 },
})

-- QBZ-191 突击步枪 | scripts/gun/58/cat_QBZ191.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.QBZ191_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- QBZ-191 突击步枪 (弹鼓) | scripts/gun/58/cat_QBZ191_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.QBZ191_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- QBZ-192 卡宾枪 | scripts/gun/58/cat_QBZ192.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.QBZ192_cat", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = -2 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 58 },
})

-- QBZ-192 卡宾枪 (弹鼓) | scripts/gun/58/cat_QBZ192_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.QBZ192_cat_Drum", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = -2 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 54 },
})

-- QSZ-92G 手枪 | scripts/gun/58/cat_QSZ_92G.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base
R.weapon("Base.QSZ_92G", {
    istinitial = { mode = "base", value = 360 },
    istrecoil = { mode = "base", value = 185 },
    istpenetra = { mode = "base", value = 18 },
    istpower = { mode = "base", value = 78 },
    istHMEfficacy = { mode = "base", value = 71 },
})

-- T-Rex 反器材步枪 | scripts/gun/50/cat_SnipeX_T_Rex.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.SnipeX_T_Rex_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -55 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 34 },
})

-- M7 突击步枪 | scripts/gun/556/cat_M7.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 原脚本base:Bullets_38大小写异常；需作者核对注册解析
R.weapon("Base.M7_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 53 },
})

-- M7 突击步枪 (弹鼓) | scripts/gun/556/cat_M7_Drum.txt:4
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.M7_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 49 },
})

-- AWM 马格南狙击步枪 | scripts/gun/44/cat_AWM.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base
R.weapon("Base.AWM_cat", {
    istinitial = { mode = "base", value = 500 },
    istrecoil = { mode = "base", value = 400 },
    istpenetra = { mode = "base", value = 90 },
    istpower = { mode = "base", value = 150 },
    istHMEfficacy = { mode = "base", value = 37 },
})

-- 柯尔特“蟒蛇”左轮手枪 | scripts/gun/44/cat_Anaconda.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.Anaconda_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 45 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 68 },
})

-- 温彻斯特 1866 型步枪 | scripts/gun/44/cat_M1866.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M1866_cat", {
    istinitial = { mode = "add", value = 15 },
    istrecoil = { mode = "add", value = 20 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 10 },
    istHMEfficacy = { mode = "base", value = 53 },
})

-- CheyTac M200“干预者” | scripts/gun/44/cat_M200.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base
R.weapon("Base.M200_cat", {
    istinitial = { mode = "base", value = 520 },
    istrecoil = { mode = "base", value = 430 },
    istpenetra = { mode = "base", value = 110 },
    istpower = { mode = "base", value = 165 },
    istHMEfficacy = { mode = "base", value = 38 },
})

-- 史密斯威森 500 型左轮手枪 | scripts/gun/44/cat_M500.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M500_cat", {
    istinitial = { mode = "add", value = 20 },
    istrecoil = { mode = "add", value = 85 },
    istpenetra = { mode = "add", value = 7 },
    istpower = { mode = "add", value = 15 },
    istHMEfficacy = { mode = "base", value = 66 },
})

-- 马林 1894 型杠杆式步枪 | scripts/gun/44/Marlin1894.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.Marlin1894", {
    istinitial = { mode = "add", value = 20 },
    istrecoil = { mode = "add", value = 45 },
    istpenetra = { mode = "add", value = 7 },
    istpower = { mode = "add", value = 15 },
    istHMEfficacy = { mode = "base", value = 59 },
})

-- 沙漠之鹰手枪 | scripts/gun/44/shamozhiying.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.Pistol3", {
    istinitial = { mode = "add", value = 15 },
    istrecoil = { mode = "add", value = 70 },
    istpenetra = { mode = "add", value = 4 },
    istpower = { mode = "add", value = 10 },
    istHMEfficacy = { mode = "base", value = 65 },
})

-- “蔷薇”狙击步枪 | scripts/gun/44/cat_ROSE.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.ROSE_cat", {
    istinitial = { mode = "base", value = 520 },
    istrecoil = { mode = "base", value = 450 },
    istpenetra = { mode = "base", value = 110 },
    istpower = { mode = "base", value = 170 },
    istHMEfficacy = { mode = "base", value = 39 },
})

-- 史密斯威森 625 型左轮手枪 | scripts/gun/44/cat_1_M625.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.Revolver", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = 35 },
    istpenetra = { mode = "add", value = -1 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 69 },
})

-- 史密斯威森 500 型左轮手枪 | scripts/gun/44/cat_1_magenan.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.Revolver_Long", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = 30 },
    istpenetra = { mode = "add", value = -1 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 68 },
})

-- 史密斯威森 629 左轮手枪 | scripts/gun/44/cat_SW629.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.SW629_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 45 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 69 },
})

-- Taurus 左轮手枪 | scripts/gun/44/cat_6_Taurus.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.Taurus_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 45 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 68 },
})

-- Christine .45-70 精确射手步枪 | scripts/gun/45/cat_Christine45.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.Christine45_cat", {
    istinitial = { mode = "add", value = 35 },
    istrecoil = { mode = "add", value = 95 },
    istpenetra = { mode = "add", value = 5 },
    istpower = { mode = "add", value = 20 },
    istHMEfficacy = { mode = "base", value = 65 },
})

-- 柯尔特“和平使者”M1873 | scripts/gun/45/cat_M1873.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M1873_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 35 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 70 },
})

-- M1911 手枪 | scripts/gun/45/cat_1_M1911.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.Pistol2", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 35 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 69 },
})

-- M1911 手枪 (弹鼓) | scripts/gun/45/cat_1_M1911_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.Pistol2_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 35 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 65 },
})

-- SRM3 突击步枪 | scripts/gun/45/cat_SRM3.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.SRM3_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 35 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 70 },
})

-- SRM3 突击步枪 (弹鼓) | scripts/gun/45/cat_SRM3_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.SRM3_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 35 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 66 },
})

-- HK UMP45 冲锋枪 | scripts/gun/45/cat_UMP45.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.UMP45_cat", {
    istinitial = { mode = "add", value = 10 },
    istrecoil = { mode = "add", value = 20 },
    istpenetra = { mode = "add", value = 2 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 62 },
})

-- HK UMP45 冲锋枪 (弹鼓) | scripts/gun/45/cat_UMP45_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.UMP45_cat_Drum", {
    istinitial = { mode = "add", value = 10 },
    istrecoil = { mode = "add", value = 20 },
    istpenetra = { mode = "add", value = 2 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "base", value = 58 },
})

-- HK USP .45 手枪 | scripts/gun/45/cat_usp45.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.usp45_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 35 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 71 },
})

-- HK USP .45 手枪 (弹鼓) | scripts/gun/45/cat_usp45_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.usp45_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 35 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 67 },
})

-- 精密国际 AX50 反器材步枪 | scripts/gun/50/cat_AX50.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 游戏用Base.Bullets50；M82/AX50等按BMG基准；不新建AE弹种
R.weapon("Base.AX50_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -40 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 37 },
})

-- 精密国际 AX50 反器材步枪 (弹鼓) | scripts/gun/50/cat_AX50_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
-- 游戏用Base.Bullets50；M82/AX50等按BMG基准；不新建AE弹种
R.weapon("Base.AX50_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -40 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 33 },
})

-- GM6 犊牛式反器材步枪 | scripts/gun/50/cat_GM6.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 游戏用Base.Bullets50；M82/AX50等按BMG基准；不新建AE弹种
R.weapon("Base.GM6_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -40 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 37 },
})

-- 巴雷特 M82 反器材步枪 | scripts/gun/50/cat_M82.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 游戏用Base.Bullets50；M82/AX50等按BMG基准；不新建AE弹种
R.weapon("Base.M82_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = -25 },
    istpenetra = { mode = "add", value = 14 },
    istpower = { mode = "add", value = 10 },
    istHMEfficacy = { mode = "base", value = 34 },
})

-- 巴雷特 M82 反器材步枪 (弹鼓) | scripts/gun/50/cat_M82_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
-- 游戏用Base.Bullets50；M82/AX50等按BMG基准；不新建AE弹种
R.weapon("Base.M82_cat_Drum", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = -25 },
    istpenetra = { mode = "add", value = 14 },
    istpower = { mode = "add", value = 10 },
    istHMEfficacy = { mode = "base", value = 30 },
})

-- “安魂曲”重型左轮手枪 | scripts/gun/50/cat_Requiem.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 游戏用Base.Bullets50；M82/AX50等按BMG基准；不新建AE弹种；枪base优先于弹药base
R.weapon("Base.Requiem_cat", {
    istinitial = { mode = "base", value = 420 },
    istrecoil = { mode = "base", value = 430 },
    istpenetra = { mode = "base", value = 32 },
    istpower = { mode = "base", value = 120 },
    istHMEfficacy = { mode = "base", value = 66 },
})

-- 索利达尔 | scripts/gun/50/cat_Beowulf.txt:246
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 游戏用Base.Bullets50；M82/AX50等按BMG基准；不新建AE弹种
R.weapon("Base.Thoridal", {
    istinitial = { mode = "add", value = -25 },
    istrecoil = { mode = "add", value = -110 },
    istpenetra = { mode = "add", value = -45 },
    istpower = { mode = "add", value = -35 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- XM109 反器材酬载步枪 | scripts/gun/50/cat_XM109.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 游戏用Base.Bullets50；M82/AX50等按BMG基准；不新建AE弹种；保留脚本.50用弹，不擅自改为现实口径或爆炸弹
R.weapon("Base.XM109_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = -25 },
    istpenetra = { mode = "add", value = 14 },
    istpower = { mode = "add", value = 10 },
    istHMEfficacy = { mode = "base", value = 34 },
})

-- 索利达尔 | scripts/gun/50/cat_Beowulf.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 游戏用Base.Bullets50；M82/AX50等按BMG基准；不新建AE弹种
R.weapon("Base.索利达尔", {
    istinitial = { mode = "add", value = -25 },
    istrecoil = { mode = "add", value = -110 },
    istpenetra = { mode = "add", value = -45 },
    istpower = { mode = "add", value = -35 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- LWMMG 中型机枪 | scripts/gun/86/cat_LWMMG.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.LWMMG_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -45 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 29 },
})

-- MK18“雷神之锤”卡宾枪 | scripts/gun/86/cat_MK18.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.MK18_cat", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -20 },
    istpenetra = { mode = "add", value = -5 },
    istpower = { mode = "add", value = -5 },
    istHMEfficacy = { mode = "base", value = 49 },
})

-- REAPR 通用机枪 | scripts/gun/86/cat_REAPR.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.REAPR_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -30 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 38 },
})

-- .338 MG338 机枪 | scripts/gun/86/cat_mg338.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.mg338_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -40 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 31 },
})

-- AMB-17“梦魇”步枪 | scripts/gun/9mm/cat_AMB17.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.AMB17_cat", {
    istinitial = { mode = "base", value = 320 },
    istrecoil = { mode = "base", value = 235 },
    istpenetra = { mode = "base", value = 40 },
    istpower = { mode = "base", value = 110 },
    istHMEfficacy = { mode = "base", value = 58 },
})

-- AMB-17“梦魇”步枪 (弹鼓) | scripts/gun/9mm/cat_AMB17_Drum.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪；弹鼓版本人机-4（装饰弹匣不重复扣）
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.AMB17_cat_Drum", {
    istinitial = { mode = "base", value = 320 },
    istrecoil = { mode = "base", value = 235 },
    istpenetra = { mode = "base", value = 40 },
    istpower = { mode = "base", value = 110 },
    istHMEfficacy = { mode = "base", value = 54 },
})

-- AS Val MOD4 消音步枪 | scripts/gun/9mm/cat_AS_VAL_MOD4.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.AS_VAL_MOD4_cat", {
    istinitial = { mode = "base", value = 320 },
    istrecoil = { mode = "base", value = 250 },
    istpenetra = { mode = "base", value = 45 },
    istpower = { mode = "base", value = 115 },
    istHMEfficacy = { mode = "base", value = 60 },
})

-- AS Val MOD4 消音步枪 (弹鼓) | scripts/gun/9mm/cat_AS_VAL_MOD4_Drum.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪；弹鼓版本人机-4（装饰弹匣不重复扣）
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.AS_VAL_MOD4_cat_Drum", {
    istinitial = { mode = "base", value = 320 },
    istrecoil = { mode = "base", value = 250 },
    istpenetra = { mode = "base", value = 45 },
    istpower = { mode = "base", value = 115 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- AS Val 消音步枪 | scripts/gun/9mm/cat_AS_VAL.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.AS_VAL_cat", {
    istinitial = { mode = "base", value = 320 },
    istrecoil = { mode = "base", value = 260 },
    istpenetra = { mode = "base", value = 45 },
    istpower = { mode = "base", value = 115 },
    istHMEfficacy = { mode = "base", value = 61 },
})

-- AS Val 消音步枪 (弹鼓) | scripts/gun/9mm/cat_AS_VAL_Drum.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪；弹鼓版本人机-4（装饰弹匣不重复扣）
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.AS_VAL_cat_Drum", {
    istinitial = { mode = "base", value = 320 },
    istrecoil = { mode = "base", value = 260 },
    istpenetra = { mode = "base", value = 45 },
    istpower = { mode = "base", value = 115 },
    istHMEfficacy = { mode = "base", value = 57 },
})

-- 贝瑞塔 M93R 全自动手枪 | scripts/gun/9mm/cat_BerettaM93R.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.BerettaM93R_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 69 },
})

-- 贝瑞塔 M93R 全自动手枪 (弹鼓) | scripts/gun/9mm/cat_BerettaM93R_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.BerettaM93R_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 65 },
})

-- Erma EMP 冲锋枪 | scripts/gun/9mm/cat_EMP.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.EMP_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- FN Five-seveN 手枪 | scripts/gun/9mm/cat_FN57.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 保留脚本9mm共用弹种，不按现实口径改AmmoType
R.weapon("Base.FN57_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 72 },
})

-- FN Five-seveN 手枪 (弹鼓) | scripts/gun/9mm/cat_FN57_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
-- 保留脚本9mm共用弹种，不按现实口径改AmmoType
R.weapon("Base.FN57_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 68 },
})

-- 格洛克 17 手枪 | scripts/gun/9mm/cat_G17.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.G17_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 72 },
})

-- 格洛克 17 手枪 (弹鼓) | scripts/gun/9mm/cat_G17_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.G17_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 68 },
})

-- 格洛克 18 全自动手枪 | scripts/gun/9mm/cat_G18.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.G18_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 72 },
})

-- 格洛克 18 全自动手枪 (弹鼓) | scripts/gun/9mm/cat_G18_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.G18_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 68 },
})

-- 格洛克 19 紧凑型手枪 | scripts/gun/9mm/cat_G19.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.G19_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 72 },
})

-- 格洛克 19 紧凑型手枪 (弹鼓) | scripts/gun/9mm/cat_G19_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.G19_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 68 },
})

-- 格洛克 34 竞赛型手枪 | scripts/gun/9mm/cat_G34.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.G34_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 30 },
    istpenetra = { mode = "add", value = 1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 72 },
})

-- 格洛克 34 竞赛型手枪 (弹鼓) | scripts/gun/9mm/cat_G34_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.G34_cat_Drum", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 30 },
    istpenetra = { mode = "add", value = 1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 68 },
})

-- KRISS Vector 冲锋枪 | scripts/gun/9mm/cat_KrissVector.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.KrissVector_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 10 },
    istpenetra = { mode = "add", value = 1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 60 },
})

-- KRISS Vector 冲锋枪 (弹鼓) | scripts/gun/9mm/cat_KrissVector_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.KrissVector_cat_Drum", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 10 },
    istpenetra = { mode = "add", value = 1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- 贝瑞塔 M9A4 手枪 | scripts/gun/9mm/cat_M9A4.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.M9A4_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 30 },
    istpenetra = { mode = "add", value = 1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 70 },
})

-- 贝瑞塔 M9A4 手枪 (弹鼓) | scripts/gun/9mm/cat_M9A4_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.M9A4_cat_Drum", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 30 },
    istpenetra = { mode = "add", value = 1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 66 },
})

-- HK MP7 个人防卫武器 | scripts/gun/9mm/cat_MP7.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 保留脚本9mm共用弹种，不按现实口径改AmmoType
R.weapon("Base.MP7_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 20 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 65 },
})

-- HK MP7 个人防卫武器 (弹鼓) | scripts/gun/9mm/cat_MP7_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
-- 保留脚本9mm共用弹种，不按现实口径改AmmoType
R.weapon("Base.MP7_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 20 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 61 },
})

-- 贝瑞塔 M9 手枪 | scripts/gun/9mm/cat_1_M9.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.Pistol", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 70 },
})

-- 贝瑞塔 M9 手枪 (弹鼓) | scripts/gun/9mm/cat_1_M9_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.Pistol_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 66 },
})

-- SIG Sauer P226 手枪 | scripts/gun/9mm/cat_SIGP226.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.SIGP226_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 71 },
})

-- SIG Sauer P226 手枪 (弹鼓) | scripts/gun/9mm/cat_SIGP226_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.SIGP226_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 67 },
})

-- Taran Tactical 2011 手枪 | scripts/gun/9mm/cat_Taran2011.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.Taran2011_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 30 },
    istpenetra = { mode = "add", value = 1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 69 },
})

-- Taran Tactical 2011 手枪 (弹鼓) | scripts/gun/9mm/cat_Taran2011_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.Taran2011_cat_Drum", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 30 },
    istpenetra = { mode = "add", value = 1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 65 },
})

-- 汤普森冲锋枪 | scripts/gun/9mm/cat_Thompson.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 保留脚本9mm共用弹种，不按现实口径改AmmoType
R.weapon("Base.Thompson_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 47 },
})

-- VSSM 消音精确射手步枪 | scripts/gun/9mm/cat_VSSM.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.VSSM_cat", {
    istinitial = { mode = "base", value = 320 },
    istrecoil = { mode = "base", value = 255 },
    istpenetra = { mode = "base", value = 45 },
    istpower = { mode = "base", value = 115 },
    istHMEfficacy = { mode = "base", value = 56 },
})

-- VSSM 消音精确射手步枪 (弹鼓) | scripts/gun/9mm/cat_VSSM_Drum.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪；弹鼓版本人机-4（装饰弹匣不重复扣）
-- 枪base优先于弹药base；原声音半径<30；现规则会进入320+add分支，即使未装消音器
R.weapon("Base.VSSM_cat_Drum", {
    istinitial = { mode = "base", value = 320 },
    istrecoil = { mode = "base", value = 255 },
    istpenetra = { mode = "base", value = 45 },
    istpower = { mode = "base", value = 115 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- 鲁格 P08 手枪 | scripts/gun/9mm/cat_lugerP08.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.lugerP08_cat", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = 20 },
    istpenetra = { mode = "add", value = -1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 71 },
})

-- M134 转轮机枪 (9mm) | scripts/gun/9mm/cat_minigun.txt:3
-- 共用弹药但枪械定位不同：枪级base隔离，避免更改其他枪
-- 枪base优先于弹药base
R.weapon("Base.minigun_cat", {
    istinitial = { mode = "base", value = 450 },
    istrecoil = { mode = "base", value = 170 },
    istpenetra = { mode = "base", value = 40 },
    istpower = { mode = "base", value = 100 },
    istHMEfficacy = { mode = "base", value = 28 },
})

-- HK MP5 冲锋枪 | scripts/gun/9mm/cat_mp5.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.mp5_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 10 },
    istpenetra = { mode = "add", value = 1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 61 },
})

-- HK MP5 冲锋枪 (弹鼓) | scripts/gun/9mm/cat_mp5_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.mp5_cat_Drum", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 10 },
    istpenetra = { mode = "add", value = 1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 57 },
})

-- 乌兹冲锋枪 | scripts/gun/9mm/cat_uzi.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
R.weapon("Base.uzi_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 55 },
})

-- 乌兹冲锋枪 (弹鼓) | scripts/gun/9mm/cat_uzi_Drum.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分；弹鼓版本人机-4（装饰弹匣不重复扣）
R.weapon("Base.uzi_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 51 },
})

-- AA12 全自动霰弹枪 | scripts/gun/Shotgun/cat_AA12.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.AA12_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -25 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 45 },
})

-- 勃朗宁 Auto-5 半自动霰弹枪 | scripts/gun/Shotgun/cat_BRAuto5.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.BRAuto5_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 51 },
})

-- Chiappa“三重威胁”霰弹枪 | scripts/gun/Shotgun/cat_ChiappaTripleThreat.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.ChiappaTripleThreat_cat", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 15 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 54 },
})

-- DP-12 双管泵动式霰弹枪 | scripts/gun/Shotgun/cat_DP12.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.DP12_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 50 },
})

-- 双管霰弹枪 | scripts/gun/Shotgun/cat_1_shuangpen.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.DoubleBarrelShotgun", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 20 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 57 },
})

-- M1887 杠杆式霰弹枪 | scripts/gun/Shotgun/cat_M1887.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.M1887_cat", {
    istinitial = { mode = "add", value = -5 },
    istrecoil = { mode = "add", value = -20 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 55 },
})

-- 雷明顿 870 泵动式霰弹枪 | scripts/gun/Shotgun/cat_M870.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.M870_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 54 },
})

-- Saiga-12 半自动霰弹枪 | scripts/gun/Shotgun/cat_Saiga12.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.Saiga12_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 54 },
})

-- JS-2000 霰弹枪 | scripts/gun/Shotgun/cat_1_JS2000.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.Shotgun", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 54 },
})

-- 锯短双管霰弹枪 | scripts/gun/Shotgun/cat_1_shuangpen_juduan.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.ShotgunSawnoff", {
    istinitial = { mode = "add", value = -10 },
    istrecoil = { mode = "add", value = -30 },
    istpenetra = { mode = "add", value = -1 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 61 },
})

-- Striker 12 转轮式霰弹枪 | scripts/gun/Shotgun/cat_Striker12.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.Striker12_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 51 },
})

-- TTI Benelli M4 战术霰弹枪 | scripts/gun/Shotgun/cat_TTI_Benelli_M4.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.TTI_Benelli_M4_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 53 },
})

-- UTS-15 犊牛式霰弹枪 | scripts/gun/Shotgun/cat_UTS-15.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.UTS15_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -5 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 54 },
})

-- Fostech Origin-12 霰弹枪 | scripts/gun/Shotgun/cat_origin12.txt:3
-- 弹药base＋枪械add；按原最小伤害相对弹种基准、重量细分
-- 威力每颗弹丸；须游戏实测整枪总伤害，不能按单颗等于整枪
R.weapon("Base.origin12_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -10 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "base", value = 52 },
})

-- 合金工具钢枪管 | scripts/Part/Barrel.txt:113
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整；枪管初速add=原射程加成×2，上限20
R.attachment("Gunpart.QG_ATSB", {
    istinitial = { mode = "add", value = 10 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 陶瓷复合枪管 | scripts/Part/Barrel.txt:166
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整；枪管初速add=原射程加成×2，上限20
R.attachment("Gunpart.QG_CCB", {
    istinitial = { mode = "add", value = 5 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -1 },
})

-- 特制复合钢枪管 | scripts/Part/Barrel.txt:32
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整；枪管初速add=原射程加成×2，上限20
R.attachment("Gunpart.QG_CCTB", {
    istinitial = { mode = "add", value = 10 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 3 },
})

-- 碳纤维包钢枪管 | scripts/Part/Barrel.txt:86
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整；枪管初速add=原射程加成×2，上限20
R.attachment("Gunpart.QG_CFWSB", {
    istinitial = { mode = "add", value = 15 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 2 },
})

-- 碳素钢枪管 | scripts/Part/Barrel.txt:59
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整；枪管初速add=原射程加成×2，上限20
R.attachment("Gunpart.QG_CSB", {
    istinitial = { mode = "add", value = 10 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 5 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 钛合金枪管 | scripts/Part/Barrel.txt:6
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整；枪管初速add=原射程加成×2，上限20
R.attachment("Gunpart.QG_TAB", {
    istinitial = { mode = "add", value = 10 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 3 },
})

-- 钨合金枪管 | scripts/Part/Barrel.txt:140
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整；枪管初速add=原射程加成×2，上限20
R.attachment("Gunpart.QG_TTAB", {
    istinitial = { mode = "add", value = 20 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -2 },
})

-- 损坏的枪械配件 | scripts/generated/items/weaponpart.txt:187
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Base.ChokeTubeFull", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 损坏的枪械配件 | scripts/generated/items/weaponpart.txt:206
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Base.ChokeTubeImproved", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 损坏的枪械配件 | scripts/generated/items/weaponpart.txt:160
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Base.GunLight", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 损坏的枪械配件 | scripts/generated/items/weaponpart.txt:119
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Base.Laser", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AAC消音器 | scripts/Part/Canon.txt:254
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.3；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.AACMini7_Silencer", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = -10 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AAC手枪圆形消音器 | scripts/Part/Canon.txt:279
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.3；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.AAC_Silencer_2", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = -10 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 枪口消音器SD | scripts/Part/Canon.txt:673
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.3；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.AR15_slience", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = -10 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 反器材步枪枪口消音器 | scripts/Part/Canon.txt:625
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.5；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.M82_cat_Silencer", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = -20 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 反器材步枪枪口制退器 | scripts/Part/Canon.txt:524
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.M82_cat_muzzle", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 8 },
})

-- 霰弹枪枪口消音器 | scripts/Part/Canon.txt:649
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.3；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.SMSUP_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = -10 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 斜切枪口制退器 | scripts/Part/Canon.txt:499
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.VP09", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 5 },
})

-- 109枪口制退器 | scripts/Part/Canon.txt:198
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.XY_109", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 4 },
})

-- S1911枪口制退器 | scripts/Part/Canon.txt:76
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.XY_1911", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 5 },
})

-- Beowulf枪口制退器 | scripts/Part/Canon.txt:3
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.XY_Beowulf", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 4 },
})

-- CARVER枪口制退器 | scripts/Part/Canon.txt:173
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.XY_CARVER", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 6 },
})

-- MK18枪口消音器 | scripts/Part/Canon.txt:400
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.2；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.XY_M4MK18", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = -10 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- MK18枪口制退器 | scripts/Part/Canon.txt:223
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.XY_MK18", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 6 },
})

-- 汽车滤罐消音器 | scripts/Part/Canon.txt:697
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.75；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.XY_OF", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- SnipeX 消音器 | scripts/Part/Canon.txt:549
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.4；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.XY_SnipeX", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- XDZT枪口制退器 | scripts/Part/Canon.txt:51
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.XY_XDZT", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 7 },
})

-- BG消音器 | scripts/Part/Canon.txt:328
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.25；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.XY_baoguo", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = -15 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- FAN消音器 | scripts/Part/Canon.txt:376
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.3；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.XY_fang", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = -10 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 手枪方形消音器 | scripts/Part/Canon.txt:304
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.2；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.XY_fang1_Silencer", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = -10 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- NT4消音器 | scripts/Part/Canon.txt:352
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.3；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.XY_kac", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = -10 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- PO枪口制退器 | scripts/Part/Canon.txt:424
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.XY_pomen", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 4 },
})

-- SRS消音器 | scripts/Part/Canon.txt:28
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.2；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.XY_sr_s", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = -10 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- YZ枪口制退器 | scripts/Part/Canon.txt:449
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.XY_yazhui", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 重型消音器 | scripts/Part/Canon.txt:474
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 名称含消音，但未在当前AWCWF_SilencerSet找到同ID；仍由实际声音半径决定速度分支
R.attachment("Gunpart.XY_yazhuiX", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- IPSC 手枪枪口制退器 | scripts/Part/Canon.txt:148
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.ipsc1_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 6 },
})

-- 支架 | scripts/Part/Canon.txt:112
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.ipsc_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 6 },
})

-- 短剑冲锋枪枪口消音器 | scripts/Part/Canon.txt:601
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- 原声音半径×0.2；仅结果<30才走320+add；初速不重复填-130
R.attachment("Gunpart.kriss_muzzle_d_Silencer", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = -10 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 5.56 弹鼓 (装饰配件) | scripts/Part/Clip.txt:1122
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_556Drum_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 7.62 弹鼓 (装饰配件) | scripts/Part/Clip.txt:1193
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_762Drum_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 9mm 50 发弹鼓 (装饰配件) | scripts/Part/Clip.txt:763
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_9mmDrum_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 9mm 手枪弹鼓 (装饰配件) | scripts/Part/Clip.txt:787
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_9mmDrum_p_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AA12 弹鼓 (装饰配件) | scripts/Part/Clip.txt:947
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AA12_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AEK-971 弹匣 (装饰配件) | scripts/Part/Clip.txt:662
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AEK971_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AEK-971 弹鼓 (装饰配件) | scripts/Part/Drum545.txt:6
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AEK971_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AK-103 弹匣 (装饰配件) | scripts/Part/Clip.txt:1217
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AK103_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AK-103 弹鼓 (装饰配件) | scripts/Part/Drum762.txt:32
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AK103_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AK-12 弹匣 (装饰配件) | scripts/Part/Clip.txt:351
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AK12_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AK-12 弹鼓 (装饰配件) | scripts/Part/Drum545.txt:30
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AK12_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AKS-74U 弹匣 (装饰配件) | scripts/Part/Clip.txt:213
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AKS74U_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AKS-74U 弹鼓 (装饰配件) | scripts/Part/Drum545.txt:54
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AKS74U_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AMB-17 弹匣 (装饰配件) | scripts/Part/Clip.txt:167
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AMB17_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AMB-17 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:317
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AMB17_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AN-94 弹匣 (装饰配件) | scripts/Part/Clip.txt:1840
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AN94_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AN-94 弹鼓 (装饰配件) | scripts/Part/Drum545.txt:78
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AN94_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AR57 弹匣 (装饰配件) | scripts/Part/Clip.txt:1887
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AR57_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 贝瑞塔 ARX200 弹匣 (装饰配件) | scripts/Part/Clip.txt:98
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_ARX200_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 贝瑞塔 ARX200 弹鼓 (装饰配件) | scripts/Part/Drum762.txt:80
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_ARX200_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AR 弹匣 (装饰配件) | scripts/Part/Clip.txt:1978
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AR_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AS Val MOD4 弹匣 (装饰配件) | scripts/Part/Clip.txt:144
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AS_VAL_MOD4_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AS Val MOD4 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:413
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AS_VAL_MOD4_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AS Val 弹匣 (装饰配件) | scripts/Part/Clip.txt:52
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AS_VAL_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AS Val 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:6
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AS_VAL_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- AWM 弹匣 (装饰配件) | scripts/Part/Clip.txt:996
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AWM_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 精密国际 AX50 弹匣 (装饰配件) | scripts/Part/Clip.txt:1313
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AX50_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 精密国际 AX50 弹鼓 (装饰配件) | scripts/Part/Drum50.txt:29
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AX50_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M16 弹匣 (装饰配件) | scripts/Part/Clip.txt:1361
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AssaultRifle", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M16 弹鼓 (装饰配件) | scripts/Part/Drum556.txt:6
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_AssaultRifle_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 勃朗宁自动步枪弹匣 (装饰配件) | scripts/Part/Clip.txt:638
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_BAR_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Beowulf 弹匣 (装饰配件) | scripts/Part/Clip.txt:1337
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_Beowulf_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 贝瑞塔 M93R 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:53
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_BerettaM93R_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M16 100 发弹鼓 (装饰配件) | scripts/Part/Clip.txt:1434
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_COLT902_100cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M16 60 发弹鼓 (装饰配件) | scripts/Part/Clip.txt:1409
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_COLT902_60cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Christine .45-70 弹匣 (装饰配件) | scripts/Part/Clip.txt:1651
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_Christine45_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- FN FAL 弹匣 (装饰配件) | scripts/Part/Clip.txt:613
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_FAL_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- FN Five-seveN 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:77
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_FN57_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- FN Evolys 弹匣 (装饰配件) | scripts/Part/Clip.txt:589
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_FN_Evolys_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Factor .50 原型弹匣 (装饰配件) | scripts/Part/Clip.txt:1073
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_FactorMax_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Factor .50 量产型弹匣 (装饰配件) | scripts/Part/Clip.txt:1048
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_Factor_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 格洛克 17 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:101
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_G17_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 格洛克 18 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:125
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_G18_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 格洛克 19 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:149
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_G19_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 格洛克 34 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:173
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_G34_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- GM6 弹匣 (装饰配件) | scripts/Part/Clip.txt:972
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_GM6_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- OTs-14 Groza 弹匣 (装饰配件) | scripts/Part/Clip.txt:1863
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_Groza_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- OTs-14 Groza 弹鼓 (装饰配件) | scripts/Part/Drum762.txt:104
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_Groza_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- HK416 弹匣 (装饰配件) | scripts/Part/Clip.txt:1699
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_HK416_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- HK416 弹鼓 (装饰配件) | scripts/Part/Drum556.txt:30
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_HK416_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- HK417 弹匣 (装饰配件) | scripts/Part/Clip.txt:516
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_HK417_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- HK51 弹匣 (装饰配件) | scripts/Part/Clip.txt:75
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_HK51_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- HK51 弹鼓 (装饰配件) | scripts/Part/Drum762.txt:128
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_HK51_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Honey Badger 弹匣 (装饰配件) | scripts/Part/Clip.txt:190
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_HoneyBadger_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Honey Badger 弹鼓 (装饰配件) | scripts/Part/Drum762.txt:272
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_HoneyBadger_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 雷明顿 MSR 弹匣 (装饰配件) | scripts/Part/Clip.txt:1507
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_HuntingRifle", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 奈特军械 KS-1 弹匣 (装饰配件) | scripts/Part/Clip.txt:305
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_KS1_KAC_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 奈特军械 KS-1 弹鼓 (装饰配件) | scripts/Part/Drum556.txt:54
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_KS1_KAC_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- KRISS Vector 弹匣 (装饰配件) | scripts/Part/Clip.txt:1459
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_KrissVector_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- KRISS Vector 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:365
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_KrissVector_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- LWMMG 弹匣 (装饰配件) | scripts/Part/Clip.txt:690
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_LWMMG_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M14 弹鼓 (装饰配件) | scripts/Part/Clip.txt:1146
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M14Drum_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M14 Albedo 弹匣 (装饰配件) | scripts/Part/Clip.txt:1170
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M14_Albedo", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M14 Albedo 弹鼓 (装饰配件) | scripts/Part/Drum762.txt:152
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M14_Albedo_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M14 弹匣 (装饰配件) | scripts/Part/Clip.txt:1746
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M14_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M16D 弹匣（装饰部件） | scripts/Part/Clip.txt:1385
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M16D_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- CheyTac M200 弹匣 (装饰配件) | scripts/Part/Clip.txt:1023
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M200_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M240 弹链箱 (装饰配件) | scripts/Part/Clip.txt:470
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M240_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M4A1-S 弹匣 (装饰配件) | scripts/Part/Clip.txt:259
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M4A1S_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M4A1-S 弹鼓 (装饰配件) | scripts/Part/Drum556.txt:78
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M4A1S_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- MK18 卡宾枪弹匣 (装饰配件) | scripts/Part/Clip.txt:374
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M4Mk18_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- MK18 卡宾枪弹鼓 (装饰配件) | scripts/Part/Drum556.txt:102
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M4Mk18_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M7 弹匣 (装饰配件) | scripts/Part/Clip.txt:6
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M7_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M7 弹鼓 (装饰配件) | scripts/Part/Drum556.txt:126
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M7_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 巴雷特 M82 弹匣 (装饰配件) | scripts/Part/Clip.txt:1483
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M82_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 巴雷特 M82 弹鼓 (装饰配件) | scripts/Part/Drum50.txt:6
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M82_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- HK121 弹匣 (装饰配件) | scripts/Part/Clip.txt:714
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M91_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 贝瑞塔 M9A4 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:197
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_M9A4_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- SIG Sauer MCX 弹匣 (装饰配件) | scripts/Part/Clip.txt:565
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_MCX_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- SIG Sauer MCX 弹鼓 (装饰配件) | scripts/Part/Drum556.txt:150
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_MCX_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- MDR 弹匣 (装饰配件) | scripts/Part/Clip.txt:897
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_MDR_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- MG42 弹鼓 (装饰配件) | scripts/Part/Clip.txt:1956
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_MG42_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Mk 12 弹匣 (装饰配件) | scripts/Part/Clip.txt:1675
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_MK12_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Mk 12 弹鼓 (装饰配件) | scripts/Part/Drum556.txt:174
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_MK12_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- MK18“雷神之锤”弹匣 (装饰配件) | scripts/Part/Clip.txt:541
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_MK18_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- MK47 弹匣（装饰配件） | scripts/Part/Clip.txt:1265
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_MK47_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- HK MP7 弹匣 (装饰配件) | scripts/Part/Clip.txt:1098
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_MP7_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- HK MP7 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:221
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_MP7_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Noveske N4 弹鼓 (装饰配件) | scripts/Part/Drum556.txt:198
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_NoveskeN4_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- PKM 弹药箱 (装饰配件) | scripts/Part/Clip.txt:493
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_PKM_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- M1911 弹鼓 (装饰配件) | scripts/Part/Drum45.txt:6
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_Pistol2_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 贝瑞塔 M9 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:29
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_Pistol_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- QBU-191 弹匣 (装饰配件) | scripts/Part/Clip.txt:1555
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_QBU191_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- QBU-191 弹鼓 (装饰配件) | scripts/Part/Drum58.txt:53
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_QBU191_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- QBZ-191 弹匣 (装饰配件) | scripts/Part/Clip.txt:1531
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_QBZ191_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- QBZ-191 弹鼓 (装饰配件) | scripts/Part/Drum58.txt:30
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_QBZ191_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- QBZ-192 弹匣 (装饰配件) | scripts/Part/Clip.txt:1579
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_QBZ192_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- QBZ-192 弹鼓 (装饰配件) | scripts/Part/Drum58.txt:6
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_QBZ192_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- QBZ-95 弹匣 (装饰配件) | scripts/Part/Clip.txt:1770
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_QBZ95_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- QJS201 弹链箱 (装饰配件) | scripts/Part/Clip.txt:1910
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_QJS201_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- QLU-11 弹匣 (装饰配件) | scripts/Part/Clip.txt:823
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_QLU_11", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- QLU-11 弹匣 (装饰配件) | scripts/Part/Clip.txt:922
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_QLU_11_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- R301 弹匣 (装饰配件) | scripts/Part/Clip.txt:1603
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_R301_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- REAPR 弹匣 (装饰配件) | scripts/Part/Clip.txt:421
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_REAPR_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- RPK-16 弹匣 (装饰配件) | scripts/Part/Clip.txt:1241
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_RPK16_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- RPK-16 弹鼓 (装饰配件) | scripts/Part/Drum762.txt:8
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_RPK16_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Salient Arms GRY 弹匣 (装饰配件) | scripts/Part/Clip.txt:282
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_SAI_GRY_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Salient Arms GRY 弹鼓 (装饰配件) | scripts/Part/Drum556.txt:222
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_SAI_GRY_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- SIG SG 553 弹匣 (装饰配件) | scripts/Part/Clip.txt:236
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_SG553_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- SIG SG 553 弹鼓 (装饰配件) | scripts/Part/Drum556.txt:246
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_SG553_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- SIG Sauer P226 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:245
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_SIGP226_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- SRM3 弹匣 (装饰配件) | scripts/Part/Clip.txt:121
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_SRM3_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- SRM3 弹鼓 (装饰配件) | scripts/Part/Drum45.txt:79
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_SRM3_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Saiga-12 弹鼓 (装饰配件) | scripts/Part/Clip.txt:848
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_Saiga12_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- FN SCAR-H 弹匣 (装饰配件) | scripts/Part/Clip.txt:1627
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_ScarH_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- FN SCAR-H 弹鼓 (装饰配件) | scripts/Part/Drum762.txt:200
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_ScarH_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Taran Tactical 2011 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:269
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_Taran2011_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 81 式弹匣 (装饰配件) | scripts/Part/Clip.txt:328
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_Type81_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 81 式弹鼓 (装饰配件) | scripts/Part/Drum762.txt:224
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_Type81_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Typhoon F12 弹匣 (装饰配件) | scripts/Part/Clip.txt:1723
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_Typhoon_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- HK UMP45 弹匣 (装饰配件) | scripts/Part/Clip.txt:1933
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_UMP45_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- HK UMP45 弹鼓 (装饰配件) | scripts/Part/Drum45.txt:55
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_UMP45_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- URG-S 弹匣 (装饰配件) | scripts/Part/Clip.txt:29
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_URG_S_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- URG-S 弹鼓 (装饰配件) | scripts/Part/Drum762.txt:248
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_URG_S_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- VSSM 弹匣 (装饰配件) | scripts/Part/Clip.txt:1793
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_VSSM_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- VSSM 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:341
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_VSSM_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- XM109 弹匣 (装饰配件) | scripts/Part/Clip.txt:1817
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_XM109_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 奈特军械 M110 SASS 弹匣 (装饰配件) | scripts/Part/Clip.txt:1289
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_ar_10_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 奈特军械 M110 SASS 弹鼓 (装饰配件) | scripts/Part/Drum762.txt:56
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_ar_10_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 鲁格 P08 弹匣 (装饰配件) | scripts/Part/Clip.txt:445
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_lugerP80_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- MG338 弹匣 (装饰配件) | scripts/Part/Clip.txt:398
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_mg338_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- CMMG Mk47 弹匣 (装饰配件) | scripts/Part/Clip.txt:738
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_mk47_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- CMMG Mk47 弹鼓 (装饰配件) | scripts/Part/Drum762.txt:176
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_mk47_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- HK MP5 弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:389
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_mp5_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- Fostech Origin-12 弹鼓 (装饰配件) | scripts/Part/Clip.txt:873
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_origin12_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 杀戮者弹匣 (装饰配件) | scripts/Part/Clip.txt:2001
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_shaluzhiren", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- HK USP .45 弹鼓 (装饰配件) | scripts/Part/Drum45.txt:30
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_usp45_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 乌兹弹鼓 (装饰配件) | scripts/Part/Drum9mm.txt:293
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Clip_uzi_cat_Drum", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 马格普尔AFG战术前握把 | scripts/Part/Grip.txt:83
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.AFG_Blk", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 2 },
})

-- 眼镜蛇握把 | scripts/Part/Grip.txt:157
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.CobraGrip", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 1 },
})

-- 赫拉CQR战术前握把 | scripts/Part/Grip.txt:183
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.HeraCQR_Grip", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 4 },
})

-- Tshift握把 | scripts/Part/Grip.txt:32
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.TshiftGrip", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 5 },
})

-- SST握把 | scripts/Part/Grip.txt:6
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.WB_SST", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 3 },
})

-- 斜角握把 | scripts/Part/Grip.txt:132
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.WB_xie", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -2 },
})

-- 子弹编程器 | scripts/Part/L_Scope.txt:77
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.AmmoPD", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -2 },
})

-- 病毒侦测器 | scripts/Part/L_Scope.txt:32
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.HeartbeatSensor", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 病毒侦测器II | scripts/Part/L_Scope.txt:54
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.HeartbeatSensorPlus", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 热成像 | scripts/Part/L_Scope.txt:7
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.ThermalImaging_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- DBAL77镭射 | scripts/Part/Laser.txt:33
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.DBAL77Laser_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 1 },
})

-- 通用镭射设备 | scripts/Part/Laser.txt:6
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.DBAL_9021_Bottom", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 1 },
})

-- PEQ激光镭射 | scripts/Part/Laser.txt:61
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.PEQ_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 通用军用枪灯T1 | scripts/Part/Light.txt:6
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.ArmytekPredator_Bottom", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 通用军用枪灯T2 | scripts/Part/Light.txt:30
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.ArmytekPredator_Bottom1", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 手枪枪灯T1 | scripts/Part/Light.txt:54
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.ArmytekPredator_Bottom2", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 手枪枪灯T2 | scripts/Part/Light.txt:90
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.ArmytekPredator_Bottom3", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 万用武器修理包 | scripts/tools/wuqixiuli.txt:6
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Base.gongjvxiuli_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 十三 | scripts/Part/Misc.txt:56
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Misc_13", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- WTigerTw | scripts/Part/Misc.txt:8
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Misc_WTigerTw", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 白芷 | scripts/Part/Misc.txt:176
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Misc_baizhi", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 旧猫 | scripts/Part/Misc.txt:32
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Misc_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- ES | scripts/Part/Misc.txt:80
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Misc_es", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 猫鲨 | scripts/Part/Misc.txt:200
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Misc_maosha", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 楠楠 | scripts/Part/Misc.txt:152
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Misc_nannan", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 苏老师 | scripts/Part/Misc.txt:128
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Misc_subieli", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 栀子 | scripts/Part/Misc.txt:104
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Gunpart.Misc_zhizi", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- G33组合瞄准镜 | scripts/Part/R_Scope.txt:32
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.G33_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 2 },
})

-- leupold组合瞄准镜 | scripts/Part/R_Scope.txt:6
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.leupold", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 1 },
})

-- 损坏的枪械配件 | scripts/generated/items/weaponpart.txt:102
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Base.RecoilPad", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 缓冲垫 | scripts/Part/Sling.txt:84
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.Recoilpad_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 损坏的枪械配件 | scripts/generated/items/weaponpart.txt:138
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Base.RedDot", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 损坏的枪械配件 | scripts/generated/items/weaponpart.txt:81
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Base.TritiumSights", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 损坏的瞄准镜 | scripts/generated/items/weaponpart.txt:3
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Base.x2Scope", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 损坏的瞄准镜 | scripts/generated/items/weaponpart.txt:24
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Base.x4Scope", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 损坏的瞄准镜 | scripts/generated/items/weaponpart.txt:45
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Base.x8Scope", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 558全息 | scripts/Part/Scope.txt:594
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.558holo", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 2 },
})

-- ATACR八倍瞄准镜 | scripts/Part/Scope.txt:338
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.ATACR", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -17 },
})

-- COMPM4桶内红点瞄准镜 | scripts/Part/Scope.txt:275
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.COMPM4", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -4 },
})

-- 552全息战斗光学瞄準镜 | scripts/Part/Scope.txt:536
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.CQBR_ACOG_RU", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 1 },
})

-- AR系列上提把 | scripts/Part/Scope.txt:565
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.Carryhandle", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 3 },
})

-- HAMR瞄准镜 | scripts/Part/Scope.txt:183
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.HAMR_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -8 },
})

-- 沼泽鹿HD511a红点镜 | scripts/Part/Scope.txt:465
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.HD511a_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 2 },
})

-- HCO全息瞄准镜 | scripts/Part/Scope.txt:622
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.MZ_HCO", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 2 },
})

-- LT红点瞄准镜 | scripts/Part/Scope.txt:506
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.MZ_LTHY", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 2 },
})

-- M16 提把瞄准镜 | scripts/Part/Scope.txt:126
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.MZ_M6D", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -3 },
})

-- MZ_UH1 | scripts/Part/Scope.txt:396
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.MZ_UH1", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 2 },
})

-- 炮队镜 | scripts/Part/Scope.txt:7
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.MZ_paoduijing", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -4 },
})

-- PE瞄准镜 | scripts/Part/Scope.txt:38
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.PEScope_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -2 },
})

-- PSO_1瞄准镜 | scripts/Part/Scope.txt:96
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.PSO_1_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -3 },
})

-- 24倍径镜 | scripts/Part/Scope.txt:307
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.Snipex24", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -17 },
})

-- TA11四倍瞄准镜 | scripts/Part/Scope.txt:214
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.TA11_4X_Scope", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -8 },
})

-- Ul8X瞄准镜 | scripts/Part/Scope.txt:155
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.Unertl8X_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -4 },
})

-- VortexSight三倍瞄准镜 | scripts/Part/Scope.txt:245
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.VortexSight", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -6 },
})

-- WaltherMRS反射式红点瞄准镜 | scripts/Part/Scope.txt:369
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.WaltherMRS_1", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 2 },
})

-- RMR手枪反射式红点瞄准镜 | scripts/Part/Scope.txt:424
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.WaltherMRS_2", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 2 },
})

-- XM157瞄准镜 | scripts/Part/Scope.txt:650
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.XM157_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -4 },
})

-- 李-恩菲尔德瞄准镜 | scripts/Part/Scope.txt:67
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.lee_enfield_scope", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -2 },
})

-- 损坏的弹药带 | scripts/generated/items/weaponpart.txt:66
-- 装饰/工具/损坏占位：五项add=0，避免重复影响
R.attachment("Base.AmmoStraps", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 霰弹弹药皿 | scripts/Part/Sling.txt:58
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.AmmoShellDish_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -1 },
})

-- 子弹带 | scripts/Part/Sling.txt:32
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.AmmoStraps_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -2 },
})

-- 轻量化枪背带 | scripts/Part/Sling.txt:6
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.Sling_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 3 },
})

-- MCNN枪托 | scripts/Part/Stock.txt:201
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.AK12Stock", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 36 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 4 },
})

-- AKS枪托 | scripts/Part/Stock.txt:69
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.AKSStock", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 7 },
})

-- CombatOpsM4枪托 | scripts/Part/Stock.txt:258
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.CombatOps_Stock_blk", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 2 },
})

-- HeraCQR枪托 | scripts/Part/Stock.txt:285
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.HeraCQR_Stock", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 2 },
})

-- Magpul枪托 | scripts/Part/Stock.txt:368
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.MagpulStock", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 1 },
})

-- Mk18枪托 | scripts/Part/Stock.txt:96
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.Mk18Stock", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 4 },
})

-- F93枪托 | scripts/Part/Stock.txt:43
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.QT_F93", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 4 },
})

-- Gen3枪托 | scripts/Part/Stock.txt:148
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.QT_Gen3", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 5 },
})

-- LDT416枪托 | scripts/Part/Stock.txt:122
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.QT_LDT416", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 8 },
})

-- 木制枪托 | scripts/Part/Stock.txt:6
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.QT_lugerP80", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 4 },
})

-- SR AK折叠枪托 | scripts/Part/Stock.txt:229
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.QT_sr", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 4 },
})

-- Troy M7 枪托 | scripts/Part/Stock.txt:313
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.TroyM7_Blk", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 3 },
})

-- Viper枪托 | scripts/Part/Stock.txt:340
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.ViperStock", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -24 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 1 },
})

-- VltorEmod枪托 | scripts/Part/Stock.txt:174
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.VltorEmod_Blk_Stock", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 4 },
})

-- R15枪托 | scripts/Part/Stock.txt:395
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.ar15Stock", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 1 },
})

-- 红隼枪托 | scripts/Part/Stock.txt:423
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.ar15_ddStock", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 1 },
})

-- 下挂火焰喷射器（右键+G装填/发射，每次装填消耗5L汽油） | scripts/Part/Stool.txt:33
-- 下挂武器只建议降低人机8；不把榴弹/火焰伤害加到主枪子弹
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.Flamethrower", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -8 },
})

-- GP-25榴弹发射器(瞄准+G发射装填) | scripts/Part/Stool.txt:109
-- 下挂武器只建议降低人机8；不把榴弹/火焰伤害加到主枪子弹
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.GP25_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -8 },
})

-- 通用脚架 | scripts/Part/Stool.txt:6
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.Harris_Open", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = -12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 8 },
})

-- 重型脚架 | scripts/Part/Stool.txt:59
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
R.attachment("Gunpart.Harris_Open1", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 12 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 3 },
})

-- M203榴弹发射器(瞄准+G发射装填) | scripts/Part/Stool.txt:86
-- 下挂武器只建议降低人机8；不把榴弹/火焰伤害加到主枪子弹
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.M203_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -8 },
})

-- M28_cat | scripts/Part/Stool.txt:132
-- 下挂武器只建议降低人机8；不把榴弹/火焰伤害加到主枪子弹
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.M28_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = -8 },
})

-- M9军用刺刀(瞄准+空格攻击) | scripts/Part/Stool.txt:182
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.bayonet1_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 9X1军用刺刀(瞄准+空格攻击) | scripts/Part/Stool.txt:209
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.bayonet2_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})

-- 基础刺刀(瞄准+空格攻击) | scripts/Part/Stool.txt:155
-- 保留原配件取舍：后坐add=原RecoilDelayModifier×12；威力add=DamageModifier×20；人机add=-0.8×AimingTimeModifier-5×WeightModifier，按说明限幅取整
-- ；原脚本未给后坐修正，本表不额外假定后坐收益
R.attachment("Gunpart.bayonet_cat", {
    istinitial = { mode = "add", value = 0 },
    istrecoil = { mode = "add", value = 0 },
    istpenetra = { mode = "add", value = 0 },
    istpower = { mode = "add", value = 0 },
    istHMEfficacy = { mode = "add", value = 0 },
})


 loaded=true
 print("[PK-IST-AUTHOR] 五项属性作者数据已提交；优先于 IST 临时兼容数据")
end
Events.OnGameBoot.Add(load)
Events.OnGameStart.Add(load)
load()

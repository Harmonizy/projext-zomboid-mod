-- SoundVolumeModifier / SoundRadiusModifier — 装备时自动调用
-- SilenceSound — 默认不调用，需自行在逻辑中按需使用（如替换 SwingSound）
AWCWF_SilencerSet = AWCWF_SilencerSet or {}
AWCWF_SilencerSet.Canon = AWCWF_SilencerSet.Canon or {}
AWCWF_SilencerSet.Canon["silencer_cat"] = {
    SoundVolumeModifier = 0.36,
    SoundRadiusModifier = 0.36,
    SilenceSound = "Silencer_Silence"
}

AWCWF_SilencerSet.Canon["kriss_muzzle_d_Silencer"] = {
    SoundVolumeModifier = 0.24,
    SoundRadiusModifier = 0.24,
    SilenceSound = "WPN_Rifle_Vector_Sup_Fire_Player_01"
}

AWCWF_SilencerSet.Canon["AACMini7_Silencer"] = {
    SoundVolumeModifier = 0.36,
    SoundRadiusModifier = 0.36,
    SilenceSound = "COLT902Shoot_s"
}

-- Visual variant of AACMini7_Silencer. It uses the same tooltip, mounting
-- family and acoustic profile, so it must participate in the same runtime
-- suppressor lookup rather than behaving as an inert muzzle attachment.
AWCWF_SilencerSet.Canon["AAC_Silencer_2"] = {
    SoundVolumeModifier = 0.36,
    SoundRadiusModifier = 0.36,
    SilenceSound = "COLT902Shoot_s"
}

AWCWF_SilencerSet.Canon["usp_cat_yuan_Silencer"] = {
    SoundVolumeModifier = 0.24,
    SoundRadiusModifier = 0.24,
    SilenceSound = "usp45_cat"
}

AWCWF_SilencerSet.Canon["XY_fang1_Silencer"] = {
    SoundVolumeModifier = 0.24,
    SoundRadiusModifier = 0.24,
    SilenceSound = "usp45_cat"
}

AWCWF_SilencerSet.Canon["usp_cat_fang_Silencer"] = {
    SoundVolumeModifier = 0.24,
    SoundRadiusModifier = 0.24,
    SilenceSound = "usp45_cat"
}

AWCWF_SilencerSet.Canon["M82_cat_Silencer"] = {
    SoundVolumeModifier = 0.60,
    SoundRadiusModifier = 0.60,
    SilenceSound = "AW_SIGNAL50_Fire_Sup"
}

AWCWF_SilencerSet.Canon["XY_SnipeX"] = {
    SoundVolumeModifier = 0.48,
    SoundRadiusModifier = 0.48,
    SilenceSound = "AW_SIGNAL50_Fire_Sup"
}

AWCWF_SilencerSet.Canon["wave_dd_slience"] = {
    SoundVolumeModifier = 0.42,
    SoundRadiusModifier = 0.42,
    SilenceSound = "XY_5"
}

AWCWF_SilencerSet.Canon["XY_sr_s"] = {
    SoundVolumeModifier = 0.24,
    SoundRadiusModifier = 0.24,
    SilenceSound = "XY_5"
}

AWCWF_SilencerSet.Canon["SMSUP_cat"] = {
    SoundVolumeModifier = 0.36,
    SoundRadiusModifier = 0.36,
    SilenceSound = "XY_4"
}

AWCWF_SilencerSet.Canon["XY_M4MK18"] = {
    SoundVolumeModifier = 0.24,
    SoundRadiusModifier = 0.24,
    SilenceSound = "XY_4"
}

AWCWF_SilencerSet.Canon["XY_4guan"] = {
    SoundVolumeModifier = 0.24,
    SoundRadiusModifier = 0.24,
    SilenceSound = "AW_SIGNAL50_Fire_Sup"
}

AWCWF_SilencerSet.Canon["AR15_slience"] = {
    SoundVolumeModifier = 0.36,
    SoundRadiusModifier = 0.36,
    SilenceSound = "XY_4"
}

AWCWF_SilencerSet.Canon["XY_baoguo"] = {
    SoundVolumeModifier = 0.30,
    SoundRadiusModifier = 0.30,
    SilenceSound = "XY_6"
}

AWCWF_SilencerSet.Canon["XY_kac"] = {
    SoundVolumeModifier = 0.36,
    SoundRadiusModifier = 0.36,
    SilenceSound = "XY_2"
}

AWCWF_SilencerSet.Canon["XY_fang"] = {
    SoundVolumeModifier = 0.36,
    SoundRadiusModifier = 0.36,
    SilenceSound = "XY_4"
}

AWCWF_SilencerSet.Canon["XY_SP"] = {
    SoundVolumeModifier = 0.96,
    SoundRadiusModifier = 0.96,
    SilenceSound = nil
}

AWCWF_SilencerSet.Canon["XY_OF"] = {
    SoundVolumeModifier = 0.90,
    SoundRadiusModifier = 0.90,
    SilenceSound = nil
}

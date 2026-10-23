-- MFS B42 patch: inspection-model aliases for corrected held firearm meshes.
--
-- WeaponSprite must reference the pre-mirrored mesh expected by the character
-- renderer. The neutral inspection scene must instead show the original
-- Blender-space model. Add future held-to-inspection aliases here rather than
-- adding firearm-specific conditions to risky_inspect_core.lua.
AWCWF_InspectionModelMap = AWCWF_InspectionModelMap or {}
-- 44 Pistol
AWCWF_InspectionModelMap.Taurus_cat_Held = "Taurus_cat"
-- 7.62 GUN
AWCWF_InspectionModelMap.M240_cat_Held = "M240_cat"
-- 5.45 GUN
AWCWF_InspectionModelMap.AEK971_cat_Held = "AEK971_cat"
AWCWF_InspectionModelMap.AK12_cat_Held = "AK12_cat"
AWCWF_InspectionModelMap.AKS74U_cat_Held = "AKS74U_cat"
AWCWF_InspectionModelMap.AN94_cat_Held = "AN94_cat"
-- .50 GUN
AWCWF_InspectionModelMap.AX50_cat_Held = "AX50_cat"
AWCWF_InspectionModelMap.GM6_cat_Held = "GM6_cat"
AWCWF_InspectionModelMap.M82_cat_Held = "M82_cat"
AWCWF_InspectionModelMap.SnipeX_T_Rex_cat_Held = "SnipeX_T_Rex_cat"
AWCWF_InspectionModelMap.XM109_cat_Held = "XM109_cat"
-- 8.6 GUN
AWCWF_InspectionModelMap.REAPR_cat_Held = "REAPR_cat"
AWCWF_InspectionModelMap.LWMMG_cat_Held = "LWMMG_cat"
AWCWF_InspectionModelMap.mg338_cat_Held = "mg338_cat"
AWCWF_InspectionModelMap.MK18_cat_Held = "MK18_cat"
-- 5.8 GUN
AWCWF_InspectionModelMap.QBU191_cat_Held = "QBU191_cat"
AWCWF_InspectionModelMap.QBZ191_cat_Held = "QBZ191_cat"
AWCWF_InspectionModelMap.QBZ192_cat_Held = "QBZ192_cat"
--7.62 but in 5.8 folder
AWCWF_InspectionModelMap.QJY201_cat_Held = "QJY201_cat"
-- 5.56 GUN
AWCWF_InspectionModelMap.AssaultRifle_Held = "AssaultRifle"
AWCWF_InspectionModelMap.M16D_cat_Held = "M16D_cat"
AWCWF_InspectionModelMap.HK416_cat_Held = "HK416_cat"
AWCWF_InspectionModelMap.KS1_KAC_cat_Held = "KS1_KAC_cat"
AWCWF_InspectionModelMap.M4A1S_cat_Held = "M4A1S_cat"
AWCWF_InspectionModelMap.M4Mk18_cat_Held = "M4Mk18_cat"
AWCWF_InspectionModelMap.M7_cat_Held = "M7_cat"
AWCWF_InspectionModelMap.M91_cat_Held = "M91_cat"
AWCWF_InspectionModelMap.MEGA_AR15_cat_Held = "MEGA_AR15_cat"
AWCWF_InspectionModelMap.MCX_cat_Held = "MCX_cat"
AWCWF_InspectionModelMap.MK12_cat_Held = "MK12_cat"
AWCWF_InspectionModelMap.NoveskeN4_cat_Held = "NoveskeN4_cat"
AWCWF_InspectionModelMap.SAI_GRY_cat_Held = "SAI_GRY_cat"
AWCWF_InspectionModelMap.SG553_cat_Held = "SG553_cat"
AWCWF_InspectionModelMap.URG_S_cat_Held = "URG_S_cat"
-- Shotgun (Exclude symmetric shotgun)
AWCWF_InspectionModelMap.AA12_cat_Held = "AA12_cat"
AWCWF_InspectionModelMap.BRAuto5_cat_Held = "BRAuto5_cat"
AWCWF_InspectionModelMap.M870_cat_Held = "M870_cat"
AWCWF_InspectionModelMap.origin12_cat_Held = "origin12_cat"
AWCWF_InspectionModelMap.Saiga12_cat_Held = "Saiga12_cat"
AWCWF_InspectionModelMap.Striker12_cat_Held = "Striker12_cat"
AWCWF_InspectionModelMap.TTI_Benelli_M4_cat_Held = "TTI_Benelli_M4_cat"
-- 44 Gun (Exclude symmetric and low poly mesh)
AWCWF_InspectionModelMap.Taurus_cat_Held = "Taurus_cat"
AWCWF_InspectionModelMap.AWM_cat_Held = "AWM_cat"
AWCWF_InspectionModelMap.M200_cat_Held = "M200_cat"
AWCWF_InspectionModelMap.M500_cat_Held = "M500_cat"
AWCWF_InspectionModelMap.Marlin1894_Held = "Marlin1894"
-- DE model def using Hadngun intead of Pistol3
AWCWF_InspectionModelMap.Handgun_Held = "Handgun"
-- 9mm
-- M9 
AWCWF_InspectionModelMap.Pistol_Held = "Pistol"
AWCWF_InspectionModelMap.AMB17_cat_Held = "AMB17_cat"
AWCWF_InspectionModelMap.AS_VAL_cat_Held = "AS_VAL_cat"
AWCWF_InspectionModelMap.AS_VAL_MOD4_cat_Held = "AS_VAL_MOD4_cat"
AWCWF_InspectionModelMap.BerettaM93R_cat_Held = "BerettaM93R_cat"
AWCWF_InspectionModelMap.EMP_cat_Held = "EMP_cat"
AWCWF_InspectionModelMap.FN57_cat_Held = "FN57_cat"
AWCWF_InspectionModelMap.G17_cat_Held = "G17_cat"
AWCWF_InspectionModelMap.G18_cat_Held = "G18_cat"
AWCWF_InspectionModelMap.G19_cat_Held = "G19_cat"
AWCWF_InspectionModelMap.G34_cat_Held = "G34_cat"
AWCWF_InspectionModelMap.KrissVector_cat_Held = "KrissVector_cat"
AWCWF_InspectionModelMap.lugerP08_cat_Held = "lugerP08_cat"
AWCWF_InspectionModelMap.M9A4_cat_Held = "M9A4_cat"
AWCWF_InspectionModelMap.minigun_cat_Held = "minigun_cat"
AWCWF_InspectionModelMap.M134_cat_Held = "M134_cat"
AWCWF_InspectionModelMap.mp5_cat_Held = "mp5_cat"
AWCWF_InspectionModelMap.MP7_cat_Held = "MP7_cat"
AWCWF_InspectionModelMap.SIGP226_cat_Held = "SIGP226_cat"
AWCWF_InspectionModelMap.Taran2011_cat_Held = "Taran2011_cat"
AWCWF_InspectionModelMap.uzi_cat_Held = "uzi_cat"
AWCWF_InspectionModelMap.Thompson_cat_Held = "Thompson_cat"
AWCWF_InspectionModelMap.VSSM_cat_Held = "VSSM_cat"
-- COMMUNITY PATCH 2026-09-16 - Pistol part default offsets
-- After 2026-09-08 Patch6 RC3 update, the pistol weapon part do not need second part anymore as now
-- weapon Part also is copied to rotate 180 degree along Y axis, same as the pistol
-- RC4F: default offsets are held-model coordinates. Convert them to scene
-- coordinates before previewing or first editing a part, including magazines.
-- Keep identical authored offsets in normal and _Held model definitions.
-- Read the actual WeaponSprite model; an ordinary sprite needs no _Held alias.
-- Dedicated zero-offset magazine meshes are not required for this conversion.
-- PISTOL Z AUTHORING: increasing attachment offset Z in the gun definition
-- moves the part DOWN; decreasing Z moves it UP (including Clip/magazines).
-- Use the same values in normal and _Held definitions.
-- IN-GAME OFFSET TOOL: increasing Z moves UP; decreasing Z moves DOWN.
-- The tool/GunPos uses scene coordinates; Lua negates Z for the held pistol.
-- Saved GunPos overrides the authored default. These rules are handgun-only.
-- COMMUNITY PATCH 2026-09-08 - held-weapon attachment axis signs.
--
-- GunPos values are authored in inspection-scene space and replayed into the
-- weapon model script's attachment offsets, which is what the engine actually
-- draws the held parts from.  Two transforms sit between those two spaces:
--
--   Z  the inspection scene rotates handgun models 180 degrees about Y
--      (risky_inspect_core.lua).  Long guns are never rotated.
--
--   X  a gun whose WeaponSprite points at a pre-mirrored "_Held" mesh has its
--      whole model space mirrored, attachment offsets included, so a raw X
--      renders on the wrong side.  This table IS the set of such sprites.
--
-- Confirmed in game 2026-09-08:
--   Taurus  handgun, mirrored _Held   X -1  Z -1
--   P226   handgun, plain mesh        X +1  Z -1
--
-- The X rule is deliberately limited to handguns.  It very likely applies to a
-- mirrored long gun too, but that has never been tested and enabling it would
-- move every saved offset on every mirrored rifle.  If someone confirms it,
-- delete the getSwingAnim() test around the X branch below.
--
-- Every writer of a model-script attachment offset must call this so the live
-- drag, the reset button and the on-equip replay cannot drift apart:
--   client/UI/risky_inspect_slider.lua
--   client/UI/risky_inspect_button.lua
--   client/MFSPartOffsetPersistence.lua
function MFS_HeldAttachmentSigns(weapon)
    local xSign, zSign = 1, 1
    if weapon and weapon:getSwingAnim() == "Handgun" then
        zSign = -1
        if AWCWF_InspectionModelMap
            and AWCWF_InspectionModelMap[weapon:getWeaponSprite()] then
            xSign = -1
        end
    end
    return xSign, zSign
end
-- The sign transform is its own inverse. Existing GunPos values already use
-- scene coordinates and must bypass this conversion when read by the GUI.
function MFS_InspectionAttachmentPosition(weapon, offset)
    local xSign, zSign = MFS_HeldAttachmentSigns(weapon)
    return xSign * offset:x(), offset:y(), zSign * offset:z()
end

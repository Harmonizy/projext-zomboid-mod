--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

-- 获取人类角色的装备挂载位置组
local group = AttachedLocations.getGroup("Human")

group:getOrCreateLocation("MurasamaBladeScabbard"):setAttachmentName("MurasamaBladeScabbard")
group:getOrCreateLocation("OnimaruKunitusnaS"):setAttachmentName("OnimaruKunitusnaS")
group:getOrCreateLocation("FantasyKnightSwordScabbard"):setAttachmentName("FantasyKnightSwordScabbard")
group:getOrCreateLocation("Avalon_cat"):setAttachmentName("Avalon_cat")
group:getOrCreateLocation("MiaoSwordS"):setAttachmentName("MiaoSwordS")
group:getOrCreateLocation("YamatoScabbard"):setAttachmentName("YamatoScabbard")
group:getOrCreateLocation("NoctisScabbard"):setAttachmentName("NoctisScabbard")
group:getOrCreateLocation("YulinSwordS"):setAttachmentName("YulinSwordS")
group:getOrCreateLocation("TacticalTangCrossbladeScabbard"):setAttachmentName("TacticalTangCrossbladeScabbard")
group:getOrCreateLocation("HaliasturIndusCrossbladeScabbard"):setAttachmentName("HaliasturIndusCrossbladeScabbard")
group:getOrCreateLocation("YanlingSwordScabbard"):setAttachmentName("YanlingSwordScabbard")
group:getOrCreateLocation("LightsaberBelt"):setAttachmentName("LightsaberBelt")

-- 调试模式下注册背部基础挂载点
if getDebug() then
	group:getOrCreateLocation("OnBack"):setAttachmentName("back")
end

-- 创建大型武器背部挂载点
group:getOrCreateLocation("XixiBigWeaponBelt"):setAttachmentName("XixiBigWeaponBelt")

-- 调试模式下注册背部基础挂载点
if getDebug() then
	group:getOrCreateLocation("OnBack"):setAttachmentName("back")
end
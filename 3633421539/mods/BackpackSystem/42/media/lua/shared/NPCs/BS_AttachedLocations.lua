--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

-- 获取人类角色的装备挂载位置组
local group = AttachedLocations.getGroup("Human")




-- 调试模式下注册背部基础挂载点
if getDebug() then
	group:getOrCreateLocation("OnBack"):setAttachmentName("back")
end

-- 创建大型武器背部挂载点
group:getOrCreateLocation("Sling_S_cat_1"):setAttachmentName("Sling_S_cat_1")
group:getOrCreateLocation("Sling_S_cat_2"):setAttachmentName("Sling_S_cat_2")

-- 调试模式下注册背部基础挂载点
if getDebug() then
	group:getOrCreateLocation("OnBack"):setAttachmentName("back")
end
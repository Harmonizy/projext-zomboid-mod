--[[
    ModernFirearmsSystem 镭射下挂 → RE4LaserContact 3D 镭射瞄准效果 桥接
    -------------------------------------------------------------------
    参考 id=RE4LaserContact（生化危机4 风格的荧红镭射线 + 接触红点），
    将本 mod 的三个镭射下挂显式注册到其渲染管线。

    - Gunpart.DBAL_9021_Bottom  (DBAL_9021_Bottom)
    - Gunpart.DBAL77Laser_cat   (DBAL77镭射Laser)
    - Gunpart.PEQ_cat           (PEQ镭射)

    说明：
    1. RE4LaserContact 本身会根据 PartType = "Laser" 自动识别这些下挂，
       此处显式注册是为了让支持关系稳定、明确，不受其自动识别规则变化影响。
    2. RE4LaserContact 的 Java 端已读取本 mod 的 modData 约定：
        - LaserBatteryReamin（电量）：<= 0 时不点亮
        - NowLightSet.Type（模式）："Laser" / "LaserAndGunLight" 点亮，
          "GunLight" / "nil" 熄灭
       因此本 mod 的“镭射/枪灯切换”与“电量”直接控制该效果开关，无需额外代码。
    3. 未安装 RE4LaserContact 时本文件静默跳过，不影响 ModernFirearmsSystem 运行。
]]

local MFS_LASER_UNDERBARRELS = {
    "Gunpart.DBAL_9021_Bottom",
    "Gunpart.DBAL77Laser_cat",
    "Gunpart.PEQ_cat",
}

local function registerWithRE4Laser()
    if not RE4LaserAPI or not RE4LaserAPI.registerLaser then
        return
    end
    for _, fullType in ipairs(MFS_LASER_UNDERBARRELS) do
        RE4LaserAPI.registerLaser(fullType)
    end
end

-- 注册集合为静态、幂等，重复注册安全；与 RE4LaserContact 自身初始化时机保持一致。
Events.OnGameStart.Add(registerWithRE4Laser)
Events.OnMainMenuEnter.Add(registerWithRE4Laser)

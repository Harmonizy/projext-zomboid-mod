-- Flamethrower 共享配置
-- 客户端与服务端都会加载，用于统一武器参数。

Flamethrower = Flamethrower or {}

Flamethrower.WEAPON_TYPE = "Flamethrower.Flamethrower"   -- 武器完整类型
Flamethrower.FUEL_TYPE   = "Flamethrower.FlameFuel"      -- 燃料（弹药）完整类型

-- 触发方式：瞄准时按住 F 键持续喷射
Flamethrower.TRIGGER_KEY = (Keyboard and Keyboard.KEY_F) or 33

-- 火焰射流参数（世界单位 = 格）
Flamethrower.RANGE             = 7.5                     -- 射流最大射程
Flamethrower.CONE_HALF_ANGLE   = math.rad(15)            -- 射流锥形半角
Flamethrower.MIN_IGNITE_DIST   = 1.3                     -- 小于该距离不点燃（保护射手脚下）

-- 喷射/判定节奏（秒）
Flamethrower.EMIT_INTERVAL     = 0.03   -- 喷射脉冲间隔
Flamethrower.IGNITE_INTERVAL   = 0.12   -- 点燃判定间隔
Flamethrower.FUEL_INTERVAL     = 0.15   -- 燃料消耗间隔（100 燃料 ≈ 15 秒持续喷射）

-- 点燃概率（随距离从近到远线性衰减，每个判定周期）
Flamethrower.SQUARE_IGNITE_NEAR = 0.28                   -- 每个采样格近距离点燃概率
Flamethrower.SQUARE_IGNITE_FAR  = 0.04                   -- 每个采样格远距离点燃概率
Flamethrower.SQUARE_SAMPLES     = 3                      -- 每个判定周期对地面的采样点数
Flamethrower.ZOMBIE_IGNITE_NEAR = 0.95                   -- 僵尸近距离点燃概率
Flamethrower.ZOMBIE_IGNITE_FAR  = 0.45                   -- 僵尸远距离点燃概率

-- 直接灼伤（每个判定周期命中锥形范围内的僵尸）
Flamethrower.DAMAGE_MIN = 0.02
Flamethrower.DAMAGE_MAX = 0.05

-- 射流冲击力：把僵尸往后推（每个判定周期，近强远弱）
Flamethrower.PUSH_NEAR = 0.05          -- 近处后推距离(格)
Flamethrower.PUSH_FAR  = 0.015         -- 远处后推距离(格)
Flamethrower.HIT_REACTION_CHANCE = 12  -- 触发踉跄动画的概率(%)

-- 火焰视觉参数
Flamethrower.FLAME_FRAMES   = 16    -- media/textures/ft_flame_X.png 帧数
Flamethrower.SMOKE_FRAMES   = 8     -- media/textures/ft_smoke_X.png 帧数
Flamethrower.PARTICLES_PER_SHOT = 4 -- 每个喷射脉冲的火焰粒子数
Flamethrower.EMBER_CHANCE   = 45    -- 每个脉冲产生火星的概率(%)

-- ==================== 火焰外形可调参数 ====================
-- 半径：起点(喷口) -> 终点(末端火团)，飞行途中按膨胀曲线过渡
Flamethrower.SPAWN_R0_MIN = 0.05    -- 起点半径最小值(格)：喷口细度
Flamethrower.SPAWN_R0_RAND = 0.05   -- 起点半径随机幅度
Flamethrower.END_R1_MIN   = 0.45    -- 终点半径最小值(格)：末端火团大小
Flamethrower.END_R1_RAND  = 0.20    -- 终点半径随机幅度
Flamethrower.GROW_CURVE   = 0.65    -- 膨胀曲线指数：=1 匀速变粗；
                                    --   <1 离开喷口后迅速变粗(推荐0.5~0.8)；
                                    --   >1 前段保持纤细、末段才膨开
-- 非等比拉伸（相对半径的系数，随生命周期从起点渐变到终点）
Flamethrower.WIDTH_START  = 0.60    -- 近端横向宽度系数：越小喷口越窄
Flamethrower.WIDTH_END    = 1.15    -- 末端横向宽度系数：越大火团越宽
Flamethrower.LENGTH_START = 2.2     -- 近端纵向拉伸系数：沿飞行方向拉长
Flamethrower.LENGTH_END   = 1.1     -- 末端纵向拉伸系数：=1为正圆
-- ==========================================================

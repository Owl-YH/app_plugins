# API 命名审查

本次审查覆盖当前 `spatial_confetti` 的公开粒子配置、发射器、尺寸与形状、风场、相机、播放控制及诊断接口。以下区分已按用户选择落实的名称与尚未实施的建议；不会将建议名称作为当前可调用 API 展示。

## 已落实：纸片必须显式选择弯曲行为

| 原接口 | 当前接口 | 行为 |
| --- | --- | --- |
| `PaperParticle.flexible(...)` | `PaperParticle.bend(...)` | 允许局部受力引起长边轻微弯曲 |
| `PaperParticle.rigid(...)` | `PaperParticle.noBend(...)` | 始终保持平面，保留飞行、翻转和气动 |
| `PaperParticle(...)` | 已移除，迁移为 `PaperParticle.noBend(...)` | 不保留默认构造或兼容别名 |
| `PaperParticle.flexible` 布尔标记 | `PaperParticle.bendEnabled` | 表示所选弯曲模式；最大弓高限制为 0 时复用不弯曲路径 |

两种构造保留原有数值、尺寸采样、受力公式和生命周期。示例开关使用“纸片不弯曲”，避免让调用者先理解刚体术语。

## 推荐修正的歧义：尚未修改

以下建议均基于实际源码含义，迁移时应保持数值和单位不变。

| 当前接口 | 推荐名称 | 原因 |
| --- | --- | --- |
| `WindField.spatialScale` | `turbulenceFrequency` | 实际是涡流空间频率，单位 1/m；越大变化越密集，不能让名称暗示更大的涡流尺寸 |
| `ConfettiCamera.unproject(..., depth: ...)` | `unproject(..., z: ...)` | 入参实际直接成为返回位置的世界 Z，不是到相机的距离 |
| `ConfettiEmitter.spread` | `spreadHalfAngle` | 表示圆锥半角，避免误当成总张角或距离 |
| `ConfettiEmitter.radius` | `spawnRadius` | 表示出生点随机球的半径，区别于粒子宽度和风场衰减半径 |
| `ConfettiEmitter.rate` | `particlesPerSecond` | 明确是生成数量/秒，区别于粒子飞行 speed |
| `PaperParticle.damping`、`RibbonParticle.damping` | `deformationDamping` | 只衰减内部形变；彩带还包含拉伸、剪切与扭转，不能统称 bendDamping 或运动阻力 |
| `MaterialParticle.angularSpeed` | `initialSpinSpeed` | 出生时采样的旋转速率，明确它不锁定后续角速度 |
| `controller.gust(...)`、`simulation.gust(...)` | `addGust(...)` | 明确是叠加一阵风，区别于 setWind 替换基础风场 |
| `WindSource.variation` | `speedVariation` | 表示风速强度的相对波动，并不随机改变风向 |
| `WindSource.radius`、`WindGust.radius` | `falloffRadius` | 表示指数衰减的尺度，半径之外仍有风；不是硬影响边界 |
| `PaperSize.proportional(...)` | `PaperSize.longestSide(...)` | 入参是米制最长边范围，明确可调尺寸；保持轮廓比例仍需注释说明 |
| `PaperSize.stretched(...)` | `PaperSize.widthAndHeight(...)` | 明确独立指定实际宽和高，而不是提供拉伸倍数 |
| `ParticleSnapshot.alive` | `isAlive` | 布尔查询与已有 isIdle/isPaused 命名一致 |

## 数量和几何接口

建议统计中的数量统一使用 Count 后缀，让 `particles`、`vertices` 等复数名优先表示集合。例如 `ConfettiStats.particles → particleCount`，`ConfettiRenderStats.vertices → vertexCount`、`triangles → triangleCount`、`visibleParticles → visibleParticleCount`、`streaks → streakCount`。ConfettiLimits 已通过类型表达上限，可保持现名，避免机械叠加冗长前缀。

`ConfettiStats.particles` 与 `livingParticles` 在移除历史保留阶段后目前相等，属于重复诊断；是否合并应单独决定，不能在改名时悄悄移除一个语义入口。

`ParticleSnapshot.nodes` 同时表示纸片轮廓点和彩带物理节点，`surfaceTriangles` 实际存储三角形索引。后者可明确为 `surfaceIndices`；前者若需拆成轮廓与物理节点，是诊断结构调整，应与纯命名迁移分开。

## 建议保留

- 包名 `spatial_confetti` 与 `ConfettiEffect`、`ConfettiEmitter`、`PaperParticle`、`RibbonParticle`、`StreakParticle` 等类型继续表达当前装饰粒子的职责；不改成暗示完整物理引擎的名称。
- `PaperShape.rectangle/circle/triangle/star/heart/polygon/path`、`NumberRange`、`DurationRange`、`ParticleLifetime` 的含义和结构已经明确。
- `origin`、`direction`、`speed`、`lifetime`、`fadeIn/fadeOut`、`weight`、`colors` 在所属对象内足够清楚，不为统一字数而增加前缀。
- `burst/stream` 区分出生时序，`stopEmission/cancel` 区分停止出生与取消现有粒子；保持这些有实际行为差异的名称。
- `massPerArea`、`bendingStiffness`、`maximumBendRatio` 保留必要物理含义，不简化成会丢失单位或意义的 weight、strength、bend。当前 `torsionalStiffness` 也不直接恢复为历史艺术化参数 `twistStiffness`，避免同名不同义。
- 不把 `airResistance`、`surfaceFriction`、`dragCoefficient` 合并为一个 drag：它们的单位、作用方向及物理模型不同。让注释明确这些区别比使用相同短名更准确。

后续有两种明确范围可选：先迁移“推荐修正的歧义”表，保留诊断结构（推荐）；或连同统计与几何诊断一起重整，后者需要额外确定合并与结构拆分规则。当前只落实了用户已选定的纸片构造命名。

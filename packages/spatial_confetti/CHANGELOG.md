# Changelog

## 0.1.0

- 所有粒子正反面使用配置原色；移除纸片和彩带的方向光照、背面压暗及仅供着色的法线计算，保留透明度渐变与速度色带柔边。
- **Breaking:** PaperParticle 必须显式使用 bend() 或 noBend()；移除默认、rigid()、flexible() 构造，模式标记改为 bendEnabled。迁移只改名称，不改变现有受力与参数值。
- **Breaking:** StreakParticle 删除 stretchDuration、maximumLength、expandDuration、shrinkDuration、fullSpeed、maximumBlur，保留 width 与 airResistance；保留发射器和风场配置。
- **Breaking:** 移除 TrailStyle、粒子 trail / trailMaterialPosition、历史缓存与预算/统计。新增独立 StreakParticle，按当前速度拉伸，实色主干与末端渐细，仅保留 width / airResistance，速度自动计算长度和柔边，发射器的 Duration 寿命推导展开收回与退出。共享重力、XYZ 风、发射调度和深度渲染；Paper/Ribbon 的材料参数归属 MaterialParticle。App、示例、诊断与中文指南同步迁移。


- PaperShape.rectangle 内置轻微圆角，无新增配置；圆角与面积、惯量、受力和柔性显示共用材料轮廓。

- 新增 PaperParticle.flexible 长边轻弧，默认 PaperParticle 及 .rigid() 保持刚性。只沿出生实际长边弯曲，短边保持直线；保留 bendingStiffness（N·m）、damping（1/s），用 maximumBendRatio（默认2%）限制弓高，移除原完整薄片的 stretchingStiffness。单弧与整体飞行共用局部受力和7×7隐式速度解，显示细分不增加物理自由度；拖尾绑定解析弧面。快照新增 surfaceVertices/surfaceTriangles、bendRatio 与弹性能。示例及真实图文说明同步更新。

- **破坏性变更**：ConfettiEmitter.lifetime 改为 ParticleLifetime，集中配置 DurationRange duration 与 Duration fadeIn/fadeOut。默认无淡入、350 ms 淡出；过长窗口按随机寿命同比缩短，取代旧寿命四分之一的隐式限制。纸片和彩带共用透明度包络，拖尾继承历史透明度；物理与回收时机保持。迁移 App、示例和文档调用，示例新增淡入淡出滑块。

- 纸片气动加入攻角压力、可移动压力中心及旋转环流，倾斜释放时可以从零初始角速度产生飘摆、翻滚和弧线运动。受力点积分保留中心可见轮廓的对称性，使用 4～16 子步推进位置与姿态；公开构造和默认值保持，轨迹和 CPU 成本会变化。示例新增静止释放观察入口，图文指南与真实动画同步更新。

- **破坏性变更**：PaperParticle 改用 PaperShape + PaperSize；新增矩形、圆形、三角形、星形、心形与自定义 polygon/path、独立 surfaceFriction、真实面积惯量与刚性薄片方向受力。复用 ParticleChoice 权重混合，新增 paperTriangles 预算。纸片快照提供轮廓顶点、面积、角速度、动能与总角动量。App、示例和六组图文配方同步迁移；纸片轨迹不保证与旧经验模型一致。

- **破坏性变更**：公开时间参数和读数统一为 Duration；lifetime 改为 DurationRange（支持 fixed）。覆盖发射/拖尾/阵风时长、延迟、风场过渡、风场采样时间、模拟推进与 time/age/lifetime 快照。
- 保持 120 Hz 物理步，用整数微秒余量累计输入；公开 stepsPerSecond 替代 stepSeconds。随机寿命量化到微秒，物理速度、速率、频率与阻尼仍为数值。
- 迁移 App、示例、五组文档预设与完整图文指南；固定寿命真实基线用于验证材料运动和风场未发生意外变化。

- **破坏性变更**：WindSource/WindGust 改为 `.global()` / `.local()`，ConfettiEmitter 改为 `.burst()` / `.stream()`；通用构造私有化。stream 支持同一发射器的开场 burstCount，默认 0；迁移旧省略值时需保留原来的 50。
- **破坏性变更**：TrailStyle 移除 enabled/materialPosition 入参，新增 const `.none()`；固定材料点迁到 RibbonParticle.trailMaterialPosition。关闭拖尾不占用历史资源、不生成拖尾几何。
- 上述四种配置成为 final class。保留现有 const 粒子和运行时校验；仓库调用同步迁移，运动、采样、随机流及出生调度保持。

- 重构柔性彩带：采用分方向弯曲、动态扭转、联合 XPBD 约束与局部表面气动力；内部阻尼改为应变率耗散。
- 使用共享 Hermite 材质曲线、连续截面和顶点光照；每物理段最多四等分，增加细分上限诊断，高速拖尾绑定同一材质点。
- **破坏性变更**：移除 `RibbonGuide`、`RibbonParticle.guide`、`guideProgress`；`showGuides` 改为 `showNodes`。不再强制头尾迁移。
- **破坏性变更**：移除艺术系数 `twistStiffness`，新增 `torsionalStiffness`（N·m²）、`inPlaneBendingStiffness`（N·m²）、`thickness`（m）及 `surfaceFriction`。旧参数无直接数值换算，默认材料未经实物标定。
- 新增彩带能量/角动量、材质点位置/速度诊断及物理不变量测试；示例支持长彩带和物理段数观察。新模型的真机性能与实物对照验收尚未完成。

- Add Confetti.launch and request-scoped ConfettiOverlayPlayback with per-Overlay replacement, pause/resume, completion, reduced-motion and disposal cleanup. The launcher reuses the existing controller, host and engine.
- Show trails only above half of TrailStyle.fullSpeed. Smoothly scale duration, length, opacity and blur with speed, eliminating low-speed residual streaks; update the example's fullSpeed to 900 logical pixels per second.
- Replace per-segment trail filters with connected soft meshes, shared depth-ordered vertex batches and explicit native vertex disposal.
- Preserve visible trail sections when the latest sample crosses a near/far plane; use analytic projected velocity and bounded chronological history.
- Add ConfettiLimits.birthAttemptsPerStep (default 512), aggregate rejection and reason-specific cumulative statistics. Excess attempts are dropped at the current simulation boundary, including across repeated emit/clear calls.
- Derive each birth's random stream from its ordinal. Seeded patterns change from 0.1.0; reproducibility requires the same implementation, SDK, configuration and initial wind clock.
- Expose ConfettiPainter.stats for visible geometry and Canvas submission diagnostics.
- Reuse painter/history and ribbon solver work buffers; reduce constraint-loop temporary vectors while preserving the fixed-step physical model.
- Calibrate the example's material/launch/camera preset, connect single-ribbon speed to its control, and reset the example wind clock for deterministic replay.

- Add free-flight paper and flexible ribbon particles with weighted emission recipes.
- Add XYZ wind composition, coherent curl turbulence and finite gusts.
- Add descent-triggered head-to-tail guidance and fixed-material temporal trails.
- Add perspective rendering, clipping, resource budgets and scoped Flutter playback.
- Add an independent interactive example and focused real-engine checks.

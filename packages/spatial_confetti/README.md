# spatial_confetti

独立 Flutter 三维 confetti 包，包含纸片、柔性彩带、多风源和独立速度色带。只有一种运动方式：从三维起点按方向和初速度发射，然后持续受重力与相对气流影响。

`0.1.0` 已发布到 pub.dev，应用可添加：

```yaml
dependencies:
  spatial_confetti: ^0.1.0
```

所有粒子正反面统一使用 `ParticleChoice.colors` 中选定的颜色，朝向不改变明暗。淡入淡出与速度色带的柔边只调整透明度。

纸片必须显式选择构造方式：

```dart
const PaperParticle.bend();   // 受力时允许长边轻微弯曲
const PaperParticle.noBend(); // 始终保持平面，仍会飞行和翻转
```

不提供 `PaperParticle()` 默认构造；旧 `flexible()` 迁移到 `bend()`，旧默认或 `rigid()` 迁移到 `noBend()`。`bendEnabled` 表示所选弯曲模式。

## 图文使用指南

[打开完整中文指南](doc/guide.md) · [离线阅读版（含真实动画视频）](doc/guide.html)

指南包含六组可复制预设、真实 Flutter 渲染截图与视频、八张原理图和实际求解轨迹图，
以及各配置项的默认值、单位、范围、调节效果和常见误区。
[完整配方](doc/presets.dart) 与 [可运行画廊](doc/gallery.dart) 使用同一份配置。
[API 命名审查](doc/api-naming.md)记录已完成的构造调整和其余命名建议。

多形状纸片已接入：矩形、圆形、三角形、星形、心形和自定义 polygon/path。
矩形 `PaperShape.rectangle()` 内置轻微圆角，无需额外配置。圆角半径为规范轮廓短边的 20%，
`PaperSize.stretched` 会同时拉伸圆角。圆角与物理、绘制共用同一份几何，计入已有三角形预算。
通过 PaperShape + PaperSize 声明轮廓与尺寸，复用 ParticleChoice + weight 混合纸片和彩带。
历史实施设计与验证来源见[迁入记录](doc/history.md)。

## 使用

~~~dart
import 'package:spatial_confetti/spatial_confetti.dart';

final controller = ConfettiController(
  wind: WindField(
    sources: [WindSource.global(velocity: const Vec3(1.2, 0, .5))],
    turbulence: .4,
  ),
);

// 放入具有有限宽高的容器，例如 Stack 中的 Positioned.fill。
ConfettiView(controller: controller);

final playback = controller.emit(ConfettiEffect(
  seed: 42,
  emitters: [
    ConfettiEmitter.burst(
      origin: const Vec3(-1, 2, 0),
      direction: const Vec3(.3, -1, .2),
      speed: const NumberRange(6, 10),
      spread: .45,
      burstCount: 60,
      lifetime: const ParticleLifetime(duration: DurationRange(Duration(seconds: 3), Duration(seconds: 5))),
      particles: [
        ParticleChoice(particle: const PaperParticle.noBend(), weight: 3),
        ParticleChoice(particle: const RibbonParticle(), weight: 1),
      ],),
  ],
));

playback.stopEmission(); // 已生成的粒子继续退出。
// playback.cancel();   // 立即取消这一组效果。
await playback.done;    // completed 或 cancelled。

// 页面/拥有者销毁时调用。
controller.dispose();
~~~

ConfettiView 是透明绘制层并忽略指针事件。一个 controller 同时只能连接一个 host。
host 卸载时清空其播放；controller 由创建它的调用方销毁。暂停、后台和 TickerMode
停止推进时间，恢复时不补算离开期间的时间。默认尊重 MediaQuery.disableAnimations：
清空已有动画并取消新请求。

需要临时全屏反馈时，在已有布局的 Overlay 内调用包拥有的入口：

~~~dart
final playback = Confetti.launch(context, effect: effect, camera: camera);
playback.pause();
playback.resume();
// playback.stopEmission(); // 停止后续出生，已有粒子自然退出。
// playback.finish();       // 立即正常结束。
// playback.cancel();       // 立即取消。
final reason = await playback.done;
~~~

ConfettiOverlayPlayback 只控制本次临时 host。同一个最近 Overlay 的新请求替换旧请求，
不同 Overlay 独立；旧 handle 的取消不会影响新请求。完成、取消、替换、host 卸载或
减少动态效果都会移除临时入口并释放 controller；不留下全局常驻画布。
ConfettiOverlayCompletion 区分 completed/cancelled/replaced/hostDisposed/reducedMotion。
像素起点使用 camera.unproject 转成世界坐标，并给 launch 传入同一个 camera。

## 时间类型

所有公开时长与相对时间均使用 `Duration`，包括 `duration`、`delay`、
`setWind.transition`、`advance`、`WindField.velocityAt` 的时间入参，
以及 `simulation.time` 和快照的 `age/lifetime`。发射器 `lifetime` 使用 `ParticleLifetime`，
其随机时长 `duration` 使用 `DurationRange`，`fadeIn/fadeOut` 使用 `Duration`。
速度、出生速率和阻尼等物理量仍使用数值。

```dart
ConfettiEmitter.stream(
  particles: [ParticleChoice(particle: const PaperParticle.noBend())],
  rate: 12,
  duration: const Duration(seconds: 2),
  delay: const Duration(milliseconds: 420),
  lifetime: const ParticleLifetime(duration: DurationRange(
    Duration(milliseconds: 1500),
    Duration(seconds: 3),
  )),
);
// 固定寿命：const DurationRange.fixed(Duration(seconds: 2))
```

淡入淡出集中在同一份寿命配置中，纸片和彩带通用：

```dart
lifetime: const ParticleLifetime(
  duration: DurationRange(Duration(seconds: 3), Duration(seconds: 5)),
  fadeIn: Duration(milliseconds: 200),
  fadeOut: Duration(milliseconds: 600),
),
```

默认无淡入、350 ms 线性淡出；0 关闭对应过渡，两项均允许 0～60 秒。
过渡包含在寿命内；两者之和超过实际随机寿命时按同比例缩短，不延长寿命。
所有粒子透明度乘以原色 alpha，寿命包含完整退出过程。
旧的 `lifetime: range` 改为 `lifetime: ParticleLifetime(duration: range)`，范围读取移到
`emitter.lifetime.duration`；短寿命不再采用旧的寿命四分之一淡出限制。

内部仍以精确的 1/120 秒推进；输入微秒按整数累计，不把单步四舍五入为
8 ms 或重复累计 8333 μs。`ConfettiSimulation.stepsPerSecond` 为 120。
`simulation.time` 是完整步的时刻舍入到最近微秒，不含输入余量；离线推进
应传入实际累计时间的相邻差值，而不是每次减去这个已量化的快照时刻。

## 参数组合

| 配置 | 作用 |
| --- | --- |
| ConfettiEffect | 独立随机种子、多发射源 |
| ConfettiEmitter | burst / stream 分别限制批量与持续出生参数；共享起点、方向、速度、寿命和延迟 |
| ParticleLifetime | duration 随机寿命、fadeIn 淡入、fadeOut 淡出；窗口包含在寿命内 |
| ParticleChoice | 粒子参数、权重、颜色列表；多个条目可表达关联选择 |
| PaperParticle | shape、size、面密度、压力气动、切向摩擦、初始角速度；flexible 另有抗弯、最大弓高比例和内部阻尼 |
| PaperShape | rectangle、circle、triangle、star、heart、polygon、path；单个有效闭合轮廓 |
| PaperSize | proportional 等比随机最长边；stretched 独立随机宽高 |
| RibbonParticle | 长宽、物理分段、分方向弯曲、扭转刚度、应变阻尼、表面气动力 |
| WindField | 多个局部或全局空气速度源、XYZ 连续涡流 |
| StreakParticle | 只配置 width、airResistance；速度自动控制长度与柔边，发射器声明生命周期 |
| ConfettiLimits | 粒子、纸片三角形、彩带分段、并行播放、每步出生尝试上限 |

批量发射使用 `ConfettiEmitter.burst(particles: choices, burstCount: 60)`，
持续生成使用 `ConfettiEmitter.stream(particles: choices, rate: 14, duration: const Duration(seconds: 20))`。
stream 的 `burstCount` 默认为 0，可设为正数生成开场批次；开场和持续出生共用同一个
发射器身份、出生序号及随机流。两种构造只区分出生时序，均使用同一种自由飞行模型。
`duration` 只描述持续出生时长，`delay` 表示出生前的等待，`lifetime` 表示每个粒子的寿命。
公开时长统一使用 Duration，随机寿命使用 DurationRange。burst 不接收 rate/duration，其只读值分别为 0 与 Duration.zero。

全局风与全局阵风分别使用 `WindSource.global` / `WindGust.global`，不接收 center/radius。
局部风与局部阵风使用 `.local`，必须传入非空 center，radius 默认为 2 m。
半径表示指数衰减尺度，半径外仍有风。WindField 保持组合构造，多个风源与涡流可以同时存在。

`StreakParticle()` 是独立的开场速度色带，与纸片、柔性彩带使用相同发射器。
推荐在同一 Effect 增加少量色带的独立发射器，lifetime 设为 260 ms，fadeOut 设为 100 ms。
色带沿当前速度展开，保留实色主干，仅末端明显收窄淡出；不记录历史。
StreakParticle 仅保留 width（米）和 airResistance（1/秒）；起点、方向、速度与 Duration 寿命沿用发射器。
色带长度随当前速度自动变化，柔边随投影速度与宽度自动调整，不需要手动配置长度上限或模糊量。
完整参数见[独立速度色带](doc/guide.md#streak)。
stopEmission() 停止该次效果的所有待生成粒子，cancel() 清理该次效果；
controller.clear() 清空整个 host。风参数实时影响已存在粒子；粒子配方在出生时采样。

~~~dart
controller.setWind(
  WindField(sources: [
    WindSource.global(velocity: const Vec3(-2, 0, 1)),
    WindSource.local(
      velocity: const Vec3(0, -2, 0),
      center: const Vec3(1, 0, 0),
      radius: 1.5,
    ),
  ], turbulence: .6),
  transition: const Duration(milliseconds: 300),
);
controller.gust(WindGust.global(velocity: const Vec3(3, -1, 2), duration: const Duration(seconds: 2)));
~~~

风源先合成当地空气速度，再计算空气与材料的相对速度。涡流使用连续 XYZ 旋度模式，
阵风使用有限时长的平滑包络。局部风和涡流是视觉气流模型，不是流体求解器。
连续快速修改风源时保留最多八个过渡分量。

## 坐标与时间

世界长度单位为米、公开时间使用 Duration；X 向右、Y 向下、Z 朝镜头。
ConfettiCamera.viewHeight 是 Z=0 平面可见的世界高度。改变容器大小只改变投影，
不改写物理位置或速度。

~~~dart
const camera = ConfettiCamera(viewHeight: 6.5);
final origin = camera.unproject(localTapPosition, canvasSize, depth: 0);
// 将 origin 用作 ConfettiEmitter.origin，并给 ConfettiView 传入同一 camera。
~~~

模拟采用固定 1/120 秒步长，生成时间量化到首个不早于指定时间的模拟边界。
host 每帧最多补算 0.1 秒，避免卡顿后大跨度跳跃；离线复现可直接使用
ConfettiSimulation.emit/advance/snapshot。ConfettiPainter 可配合调用方拥有的时钟
绘制同一 simulation；不要同时让 host 与外部时钟推进同一 simulation。

## 柔性彩带

整条彩带出生时已存在，前端位于发射起点，两端随后自由飞行。质量固定在材料上，
不再用主动目标把引导点从头移到尾，也不保证某个端点始终领先。初始小幅预弯只在
出生时生成，计入弹性能；运行中不叠加正弦摆动或随机形变。

中心线节点承担质量与弯曲惯性，材质截面具有绕切线的动态扭转自由度。每个固定
1/120 秒步内执行 8 轮耦合求解：接头的两种弯曲和扭转组成 3×3 XPBD 系统，
整条链的段长约束联合求解。惯量、柔度和节点质量随实际材料段长缩放，增加段数
不会增加总材料。它是窄薄带的离散弹性近似，不是完整薄壳或流体仿真。

每段以固定 2×2 表面积分点读取 XYZ 气流，以当地材质速度求相对风，分别计算
法向阻力和切向摩擦，通过同一位置的雅可比分配节点力与扭转力矩。没有额外经验
翻转力；静止空气耗散能量，运动空气可以输入能量。模型忽略截面横向惯量、
尾流、遮风及宽度方向褶皱，不能保证复现真实材料的颤振频率。

| 参数 | 单位 / 默认值 | 含义 |
| --- | --- | --- |
| `bendingStiffness` | N·m² / 0.000002 | 带面外弯曲刚度，控制翻卷难度 |
| `inPlaneBendingStiffness` | N·m² / 0.0002 | 带面内弯曲刚度，控制侧向弯折难度 |
| `torsionalStiffness` | N·m² / 0.000001 | 扭转刚度，控制相邻材料截面的扭转回复 |
| `thickness` | m / 0.00005 | 截面纵轴惯量所用厚度；总质量仍由面密度决定 |
| `damping` | s⁻¹ / 1.5 | 内部应变率耗散，不直接衰减整体平移或刚性旋转 |
| `dragCoefficient` | 无量纲 / 1.15 | 彩带表面法向阻力系数 |
| `surfaceFriction` | 无量纲 / 0.02 | 表面切向空气摩擦；真空测试需将两个空气系数都置零 |

这些是可调的有效材料参数，**未经过匹配实物标定**。轴向刚度内部固定为 100 N，
用于近似不易拉伸的材料。适合长度远大于宽度的窄彩带；更宽或极端折叠的材料不在真实性保证范围内。

物理节点之间使用共享切线的 Hermite 曲线；材质截面通过最小旋转传输和连续展开
的扭转角采样。普通非退化接头保持中心线 C1 连续，不承诺曲率 C2 连续。
绘制按左右边缘及截面误差选择 1/2/4 级细分，与物理段数分开；触及上限时可能
仍有近似误差。`showNodes` 可观察真实物理节点。

彩带的材料中点可用于诊断；独立色带不绑定材料，也不参与丝带形变。
`ParticleSnapshot` 提供 `materialPosition`、`materialVelocity`；彩带还提供动能、
弹性能（J）和相对于世界原点的角动量（kg·m²/s）。纸片同样提供这些诊断，只有刚性模式弹性能为 0；
纸片 angularVelocity 为整体世界角速度（不包含内部弧形速度），nodes 为轮廓顶点，area 为出生面积；
surfaceVertices/surfaceTriangles 为当前纸面材料网格。

### 多形状纸片与方向空气阻力

```dart
const star = PaperParticle.noBend(
  shape: PaperShape.star(points: 5, innerRadiusRatio: .45),
  size: PaperSize.proportional(NumberRange(.03, .06)),
  dragCoefficient: 1.15,
  surfaceFriction: .02,
);
```

proportional 保持形状比例，参数为包围盒最长边的米制随机范围；stretched 的宽高独立采样。
两者最终宽高须位于 .002～.5 m。每种形状使用一个 ParticleChoice，权重表示选择概率，
不保证精确数量或每种必定出现；不同形状可以拥有不同材料、尺寸、配色。

纸片用 dragCoefficient 缩放攻角压力及旋转气动，彩带用它控制法向阻力；surfaceFriction 独立控制切向摩擦。
两个系数都为 0 时关闭全部空气力和气动力矩；重力另由宿主控制。
纸片根据实际轮廓计算质量；单弧使用模态惯量修正，刚性使用完整薄片惯量。
按材料表面局部相对气流同时求解平移、旋转与柔性形变。
压力中心随攻角移动，翻转产生的旋转气动改变速度方向，倾斜纸片从零初始转速也能启动飘摆或翻滚。
`PaperParticle.bend()` 只沿长边轻微弯成一个浅弧，局部受力驱动单弧变化，法线和材料速度反过来影响气动；
`PaperParticle.noBend()` 保持平面；两种都要显式选择，不提供默认构造器。两者均为未经实物标定的实时近似。
详见 [受力弯曲、参数与真实图像](doc/paper-bending.md) 和 [刚性气动参考](doc/paper-aerodynamics.md)。

自定义 polygon/path 复制输入，仅支持单个闭合无自交外轮廓，最多 128 顶点；
不支持孔洞、分离区域或自交填充。Path 默认相对采样偏差阈值 .002，超出点数限制时拒绝。
几何在配方准备阶段缓存；绘制细分不改变物理属性。paperTriangles 默认预算 4096，
预算范围 0～64000；0 拒绝纸片出生，完整退出后释放。单张 T 个规范三角形，柔性最多
24T 个显示面；两种模式受力点均最多3(T+2)。
外层120Hz，每步4～16子步；单弧只新增一个弯曲自由度，显示细分不参与物理求解。

### 从旧版迁移

柔性纸片接入：需要弯曲时使用 `PaperParticle.bend(...)`；不需要弯曲时使用 `PaperParticle.noBend(...)`，两种均须显式选择。
长边轻弧默认抗弯 `.00002 N·m`、最大弓高比例 `.02`、内部阻尼 `1.5 s⁻¹`。
`stretchingStiffness` 已移除；不模拟面内拉伸或局部折叠。

多形状与纸片受力迁移：

- `PaperParticle.noBend(width: w, height: h)` → `PaperParticle.noBend(size: PaperSize.stretched(width: w, height: h))`。
- width 不再是 ConfettiParticle 的公共配置；RibbonParticle 继续声明自己的 width。
- 纸片新增 surfaceFriction（默认 .02）。原来仅用 dragCoefficient: 0 的无空气作用测试，需要同时设置 surfaceFriction: 0。
- 删除旧固定 4% 侧向面积项和不受材料系数控制的经验翻转力；新增攻角压力中心与旋转气动，既有纸片轨迹会变化。公开构造和默认值不因本轮气动改进而改变。
- 快照新增 area 和纸片 angularVelocity；纸片 nodes 改为全部轮廓顶点，能量和总角动量不再为 null。
- 凹形质心可在材料之外；材料诊断点取最近有效位置，不生成拖尾。


时间类型迁移：

- `duration: .24` → `duration: const Duration(milliseconds: 240)`。
- `delay: 0` → `delay: Duration.zero`；`transition: .3` → `transition: const Duration(milliseconds: 300)`。
- `lifetime: NumberRange(3, 5)` → `lifetime: const ParticleLifetime(duration: DurationRange(Duration(seconds: 3), Duration(seconds: 5)))`。
- `advance(.1)` → `advance(const Duration(milliseconds: 100))`；`velocityAt(point, 2)` → `velocityAt(point, const Duration(seconds: 2))`。
- time/age/lifetime 读数也改为 Duration；需要秒用于数值分析时，使用 `inMicroseconds / Duration.microsecondsPerSecond`，不要用 `inSeconds` 丢掉小数部分。
- `stepSeconds` 改为表示物理频率的 `stepsPerSecond`；随机寿命以整数微秒采样，跨迁移的随机寿命可能相差不到 1 μs。


配置构造收紧（本仓库一次性迁移）：

- `WindSource(...)` / `WindGust(...)` 根据 center 是否为空迁到 `.global(...)` / `.local(...)`；全局调用删除 center/radius。
- `ConfettiEmitter(...)` 根据 rate 是否大于 0 迁到 `.stream(...)` / `.burst(...)`；burst 删除 rate/duration 并显式传 burstCount。
- stream 显式传 rate/duration；旧调用未提供 burstCount 时原默认值为 **50**，迁移时须显式补 50，不能误用新 stream 的默认 0。旧 duration 默认 1 s，迁移时显式补入。
- 删除 TrailStyle、粒子的 trail / trailMaterialPosition，以及 trailSamples 预算和历史统计。
- 用独立 StreakParticle 发射器组合开场色带；旧历史参数不能直接换算。
- 光迹没有材料属性，快照的 mass、area、kineticEnergy、elasticEnergy、angularMomentum、materialPosition、materialVelocity 为 null；材料粒子的对应诊断值保持。
- ConfettiParticle 为共同配方，Paper/Ribbon 的共用物理属性位于 MaterialParticle。
- StreakParticle 删除 stretchDuration、maximumLength、expandDuration、shrinkDuration、fullSpeed、maximumBlur；只保留 width 与 airResistance，外观时间由发射器寿命推导。


先前的柔性彩带重构：

- 删除 `RibbonParticle.guide`、`RibbonGuide` 及 `ParticleSnapshot.guideProgress`；不再支持固定头尾迁移。
- 用 `showNodes` 替换 `ConfettiView` / `ConfettiPainter` 的 `showGuides`。
- 删除艺术系数 `twistStiffness`，重新设置有物理单位的 `torsionalStiffness`；旧数值不能直接换算。
- 复核 `bendingStiffness`、`damping` 与气动系数的新语义；新轨迹不保证与旧版一致。
- App 的三个彩带配方已显式填写新增参数，尺寸、数量、速度及发射时序保持本次修改前的配置。

## 渲染与资源

- 透视投影前进行 near/far 平面裁剪；纸片、彩带分段和光迹共用深度顺序。
- 独立色带沿当前速度拉伸；世界长度由速度乘自动拉伸时间计算，并受已行进路程及寿命包络限制；无固定米制长度截断。
- 速度显隐使用每秒跨越的画布高度，等比调整画布尺寸保持门限一致；柔边自动计算并保留实色主干。
- 每条色带固定最多 35 个四边形，近远面裁剪前 70 个三角形；不保存历史，寿命结束即回收。
- 超预算出生请求直接丢弃；材料几何额度在寿命结束时释放，没有历史保留阶段。
- birthAttemptsPerStep 默认 512，限制同一 1/120 秒模拟边界上的实际出生尝试。
  多次 emit 与到期的持续发射共用配额；clear 不恢复当前步配额，超额请求不在后续补发。
  粒子容量全满时批量拒绝，避免遍历大量无效请求。稳定的效果/发射源顺序决定先后。
- stats.capacityRejections、workLimitRejections、invalidParticles 分别记录容量拒绝、
  计算预算拒绝与数值异常；birthAttempts 记录实际候选处理数。计数从 simulation 创建起累计。
- 出生随机流由效果种子、发射源和出生序号派生。此次优化改变旧版本同一种子的具体图案；
  在相同实现/SDK、初始风场和时间基准下保持可复现，不保证跨版本的精确轨迹兼容。
- ConfettiPainter.stats 提供最近一次绘制的 drawCalls、vertices、triangles、
  visibleParticles、streaks、ribbonSegments 和 refinementLimited；统计不含物理节点标记，也不等同于底层 GPU 命令数。
- 透明自交采用深度排序近似；没有碰撞、自碰撞、完整布料或精确三维透明遮挡。
- 初始预算是资源上限，不是设备性能承诺。目标设备与同屏数量需要实际 profile 测量。

## 示例与验证

example 使用同一公开 API 和真实引擎，包含混合/单粒子观察、批量/持续发射、
XYZ 风、局部风、阵风、物理节点、单条长度/段数及播放控制。
“淡入”“淡出”滑块以毫秒调节，作用于后续出生的纸片和彩带。

示例批量发射使用独立调校的材料预设：纸片面密度 .16、压力气动 .35、切向摩擦 .02，可选择六种形状或随机混合，彩带面密度 .12、阻力 .6，
默认材料速度 11 m/s，相机 viewHeight=4.5；混合发射可加入 6 条独立高速色带，也可选择“光迹”模式单独观察。
旧版上升高度测量不适用于本次新求解器；单条彩带采用当前速度滑块的固定值。
“重播同一种子”按当前配方重建示例时钟与初始风场，普通 clear 仍保留模拟时间。
“静止释放单张纸片”使用最长边 30 cm、面密度 .08、零初速和零初始角速度，沿用当前形状、风和空气系数。

本轮桌面 CPU 证据：64 张矩形物理步进 p95 1.14 ms，64 张圆形 p95 7.48 ms；
这些不包含 GPU 和屏幕呈现，也不构成手机帧率保证。参见[迁入记录](doc/history.md)中的气动改进历史验收位置。

~~~bash
cd packages/spatial_confetti
flutter pub get
cd example
flutter pub get
flutter run -d chrome
~~~

在本包目录运行窄范围验证：`bash tool/verify.sh`。单独执行时：

~~~bash
cd packages/spatial_confetti
flutter analyze --no-pub
flutter test --no-pub test/simulation_test.dart test/rendering_test.dart test/optimization_test.dart test/config_test.dart test/duration_test.dart test/fade_test.dart test/paper_shapes_test.dart test/paper_aerodynamics_test.dart test/paper_bending_test.dart test/ribbon_physics_test.dart test/host_test.dart test/overlay_test.dart
cd example
flutter test --no-pub test/example_test.dart
flutter build web --no-pub
~~~

真实绘制测试可通过 CONFETTI_CAPTURE_DIRECTORY 将画面保存为 PNG。
测试不使用旧引擎、mock 接口或伪渲染。Web 本地构建/交互证据与真机性能证据
分别记录在本次 OpenSpec 变更中。

本次重构的数值验证、桌面成本对比和未完成验收见
[迁入记录](doc/history.md)中的丝带实施证据位置。
桌面测试显示新模型显著更慢；当前未取得真机 profile 和匹配实物录像，不能宣称性能或真实运动效果已经达标。

配置构造迁移的历史验证位置见[迁入记录](doc/history.md)。
该迁移保持运动和风场算法，不改变先前彩带性能与实物对照的验收状态。

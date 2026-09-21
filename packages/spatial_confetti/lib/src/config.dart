part of '../spatial_confetti.dart';

/// 不可变粒子配方；各类型的随机范围在每个粒子出生时独立采样。
@immutable
sealed class ConfettiParticle {
  /// 创建粒子配方；发射时机与初始运动由 [ConfettiEmitter] 声明。
  const ConfettiParticle();
  void _validate();
}

/// 纸片与柔性彩带共有的材料参数；光迹不具有薄片材料属性。
@immutable
sealed class MaterialParticle extends ConfettiParticle {
  /// 声明纸片与彩带共用的材料与初始旋转配置。
  const MaterialParticle({
    this.massPerArea = .08,
    this.dragCoefficient = 1.15,
    this.surfaceFriction = .02,
    this.angularSpeed = const NumberRange(-5, 5),
  });

  /// 面密度，单位千克/米²，范围 [0.005, 5]；总质量由实际面积计算。
  final double massPerArea;

  /// 垂直材料表面的法向空气阻力系数，无量纲，范围 [0, 4]。
  /// 根据当地空气与材料点的相对速度产生受力，并可产生旋转力矩。
  /// 对纸片还统一缩放攻角压力分布和旋转环流，0 关闭这些压力气动项；
  /// 对彩带继续表示各截面的法向阻力。不会关闭独立的 surfaceFriction。
  final double dragCoefficient;

  /// 沿材料表面的切向空气摩擦系数，无量纲，范围 [0, 1]。
  /// 与 dragCoefficient 独立；两者均为 0 才关闭全部空气作用。
  final double surfaceFriction;

  /// 初始角速度随机范围，单位弧度/秒，两端须位于 [-30, 30]。
  /// 纸片绕随机轴旋转，彩带绕各段切线扭转；正负值表示相反转向。
  final NumberRange angularSpeed;

  void _validate() {
    _number('massPerArea', massPerArea, .005, 5);
    _number('dragCoefficient', dragCoefficient, 0, 4);
    _number('surfaceFriction', surfaceFriction, 0, 1);
    angularSpeed._validate('angularSpeed', -30, 30);
  }
}

/// 任意有效轮廓的薄纸片，具有攻角压力、气动力矩与旋转环流。
/// 必须通过 [PaperParticle.bend] 或 [PaperParticle.noBend] 明确选择是否启用受力弯曲。
/// 翻转和弯曲轨迹由气动力与重力耦合产生，不保证每种条件都出现持续翻滚。
@immutable
final class PaperParticle extends MaterialParticle {
  /// 创建仅沿出生尺寸长边轻微弯曲的纸片；尺寸相等时固定选择局部 Y 轴。
  /// 发射起点为质心，不模拟短边弯曲、拉伸或局部折叠。
  const PaperParticle.bend({
    this.shape = const PaperShape.rectangle(),
    this.size = const PaperSize.stretched(
      width: NumberRange(.025, .055),
      height: NumberRange(.035, .075),
    ),
    this.bendingStiffness = .00002,
    this.maximumBendRatio = .02,
    this.damping = 1.5,
    super.massPerArea,
    super.dragCoefficient,
    super.surfaceFriction,
    super.angularSpeed,
  }) : bendEnabled = true;

  /// 创建始终保持平面的纸片；仍会飞行、翻转并响应气动力矩，不分配弯曲状态。
  const PaperParticle.noBend({
    this.shape = const PaperShape.rectangle(),
    this.size = const PaperSize.stretched(
      width: NumberRange(.025, .055),
      height: NumberRange(.035, .075),
    ),
    super.massPerArea,
    super.dragCoefficient,
    super.surfaceFriction,
    super.angularSpeed,
  }) : bendEnabled = false,
       bendingStiffness = 0,
       maximumBendRatio = 0,
       damping = 0;

  /// 是否选择 bend 构造启用弯曲；maximumBendRatio 为 0 时使用不弯曲路径。
  final bool bendEnabled;

  /// 纸面抗弯刚度，单位牛顿·米，范围 [1e-8, 1]。
  /// 越大越难弯曲；与彩带的截面抗弯刚度（牛顿·米²）不可直接比较。
  /// bend 默认值为实时动画参数，未经过实物材料标定。noBend 构造固定为 0 且不使用。
  final double bendingStiffness;

  /// 长边中点相对端点弦线的最大弓高 / 长边长度，无量纲，范围 [0, 0.05]。
  /// 默认 0.02 即最多 2%；限制为轻微单弧，0 保持平面。短边方向保持直线。
  /// 达到限制时吸收继续向外弯曲的速度；这是外观幅度约束，不是纸张材料常数。
  final double maximumBendRatio;

  /// 内部形变速度的阻尼率，单位 1/秒，范围 [0, 20]。
  /// 控制回弹振荡的衰减，不直接衰减整体平移或旋转；0 关闭材料阻尼。
  /// 数值积分本身仍有耗散。noBend 构造不使用。
  final double damping;

  /// 平面形状；内置曲线和自定义轮廓在配方准备时生成有界几何。
  final PaperShape shape;

  /// 米制尺寸随机策略；默认保留矩形宽高独立采样的分布。
  final PaperSize size;

  @override
  void _validate() {
    super._validate();
    size._validate(shape._geometry);
    if (bendEnabled) {
      _number('bendingStiffness', bendingStiffness, 1e-8, 1);
      _number('maximumBendRatio', maximumBendRatio, 0, .05);
      _number('damping', damping, 0, 20);
    }
  }
}

/// 由节点和带状截面组成的柔性彩带，可弯曲、扭转并逐段响应气流。
///
/// 出生时整条材料已经存在，前端位于采样后的发射起点，其余部分向后展开。
/// 各节点质量固定，增加分段数不会改变总质量；不模拟碰撞或自碰撞。
@immutable
final class RibbonParticle extends MaterialParticle {
  /// 创建彩带配方；分段越多，形变越细致，模拟与绘制成本也越高。
  const RibbonParticle({
    this.width = const NumberRange(.012, .024),
    this.length = const NumberRange(.35, .75),
    this.segments = 14,
    this.bendingStiffness = .000002,
    this.inPlaneBendingStiffness = .0002,
    this.torsionalStiffness = .000001,
    this.thickness = .00005,
    super.surfaceFriction,
    this.damping = 1.5,
    super.massPerArea,
    super.dragCoefficient,
    super.angularSpeed = const NumberRange(-3, 3),
  });

  /// 宽度随机范围，单位米，两端须位于 [0.002, 0.5]。
  final NumberRange width;

  /// 总长度随机范围，单位米，两端须位于 [0.04, 3]。
  final NumberRange length;

  /// 长度方向的分段数，范围 [4, 32]；节点数为此值加 1。
  final int segments;

  /// 带面外弯曲刚度，单位牛顿·米²，范围 [1e-9, 0.001]。
  /// 越大越不容易弯曲。
  final double bendingStiffness;

  /// 带面内弯曲刚度，单位牛顿·米²，范围 [1e-9, 1]。
  /// 通常大于带面外刚度，表达薄带侧向弯折比翻卷困难。
  final double inPlaneBendingStiffness;

  /// 扭转刚度，单位牛顿·米²，范围 [0, 0.01]。
  /// 与旧艺术化 twistStiffness 无直接数值换算；默认值未经过实物标定。
  final double torsionalStiffness;

  /// 材料厚度，单位米，范围 [1e-6, 0.001]，且不能超过最小宽度的十分之一。
  /// 用于截面转动惯量，不额外改变由面积和面密度确定的总质量。
  final double thickness;

  /// 内部应变率的耗散率，单位 1/秒，范围 [0, 20]。
  /// 不直接衰减整体平移或刚性旋转，0 关闭材料阻尼。
  final double damping;

  @override
  void _validate() {
    super._validate();
    width._validate('width', .002, .5);
    length._validate('length', .04, 3);
    if (segments < 4 || segments > 32) {
      throw ArgumentError.value(segments, 'segments', 'Expected 4 through 32');
    }
    _number('bendingStiffness', bendingStiffness, 1e-9, .001);
    _number('inPlaneBendingStiffness', inPlaneBendingStiffness, 1e-9, 1);
    _number('torsionalStiffness', torsionalStiffness, 0, .01);
    _number('thickness', thickness, 1e-6, math.min(.001, width.minimum / 10));
    _number('damping', damping, 0, 20);
  }
}

/// 独立速度色带；头部受重力和相对气流影响，沿当前运动方向向后拉伸。
/// 不附着于纸片或彩带，不保存历史，不模拟薄片翻转或弯曲。
/// 通过独立发射器设置较短 lifetime，可与长寿命的材料粒子组成开场效果。
@immutable
final class StreakParticle extends ConfettiParticle {
  /// 创建实色主干、末端渐细的光迹；长度、显隐和柔边由速度自动计算。
  /// 展开与收回由发射器寿命推导，非法参数在配方准备时拒绝。
  const StreakParticle({
    this.width = const NumberRange(.018, .03),
    this.airResistance = 1.5,
  });

  /// 实色头部宽度随机范围，单位米，两端须位于 [0.002, 0.5]。
  final NumberRange width;

  /// 相对气流速度的线性衰减率，单位 1/秒，范围 [0, 60]。
  /// 加速度为 gravity + airResistance × (当地风速 − 自身速度)；0 关闭空气作用。
  final double airResistance;

  @override
  void _validate() {
    width._validate('streak.width', .002, .5);
    _number('streak.airResistance', airResistance, 0, 60);
  }
}

/// 一组带权重的粒子配方与配色，用多个条目表达粒子类型与颜色的关联。
@immutable
class ParticleChoice {
  /// 校验 [particle]、[weight] 和 [colors]，并保存不可修改的颜色列表。
  ParticleChoice({
    required this.particle,
    this.weight = 1,
    List<Color> colors = const [
      Color(0xffffbf69),
      Color(0xffff6b6b),
      Color(0xff4ecdc4),
      Color(0xffc7a4ff),
      Color(0xfffff2cc),
    ],
  }) : colors = List.unmodifiable(colors) {
    particle._validate();
    _number('weight', weight, .0001, 10000);
    if (colors.isEmpty || colors.length > 64) {
      throw ArgumentError('Provide 1 through 64 colors');
    }
  }

  /// 被选中后用于生成粒子的完整配方。
  final ConfettiParticle particle;

  /// 相对于同一发射器其他条目的选择权重，范围 [0.0001, 10000]。
  /// 实际概率为此权重除以所有条目的权重和。
  final double weight;

  /// 1～64 个候选颜色；选中本条目后，从列表中等概率选择一个颜色。
  /// 所有粒子正反面保持所选颜色，不因朝向改变明暗；透明度参与寿命渐变与光迹柔边。
  final List<Color> colors;
}

/// 粒子寿命与其内部的淡入淡出，所有粒子共用。
///
/// 时间均为 [Duration]。淡入淡出不额外延长寿命；若二者之和超过实际采样寿命，
/// 出生时按相同比例缩短两段，使透明度能够连续经过 1 后降至 0。
/// 构造支持 const；在加入发射器时校验参数。
@immutable
final class ParticleLifetime {
  /// 默认寿命 3～5 秒，无淡入，最后 350 毫秒线性淡出。
  const ParticleLifetime({
    this.duration = const DurationRange(
      Duration(seconds: 3),
      Duration(seconds: 5),
    ),
    this.fadeIn = Duration.zero,
    this.fadeOut = const Duration(milliseconds: 350),
  });

  /// 从每个粒子实际出生起算的寿命随机范围，两端须位于 20 毫秒～60 秒。
  /// 淡入、淡出均包含在此范围内；寿命结束即释放粒子，不额外延长显示时间。
  final DurationRange duration;

  /// 出生后的线性淡入时长，范围 0～60 秒；0 表示出生即达到原色透明度。
  final Duration fadeIn;

  /// 寿命结束前的线性淡出时长，范围 0～60 秒；0 表示本体在寿命结束时直接消失。
  final Duration fadeOut;

  void _validate() {
    duration._validate(
      'lifetime.duration',
      const Duration(milliseconds: 20),
      const Duration(seconds: 60),
    );
    _validateDuration(
      'lifetime.fadeIn',
      fadeIn,
      Duration.zero,
      const Duration(seconds: 60),
    );
    _validateDuration(
      'lifetime.fadeOut',
      fadeOut,
      Duration.zero,
      const Duration(seconds: 60),
    );
  }
}

/// 一个自由飞行发射源，可组合一次性批量出生与持续出生。
///
/// 两者仅决定出生时机；所有粒子均按初始速度、重力和气流自由运动，
/// 不设置终点。出生时刻量化到首个不早于计划时间的模拟步边界。
@immutable
final class ConfettiEmitter {
  /// 在 [delay] 结束时一次性生成 [burstCount] 个粒子，数量须为正数。
  /// 不包含持续出生阶段；位置、速度与寿命等单位见同名属性。
  /// 校验参数并复制 [particles]；非法参数抛出 [ArgumentError]。
  ConfettiEmitter.burst({
    required List<ParticleChoice> particles,
    required int burstCount,
    Vec3 origin = Vec3.zero,
    Vec3 direction = const Vec3(0, -1, 0),
    NumberRange speed = const NumberRange(5, 9),
    double spread = .45,
    double radius = 0,
    ParticleLifetime lifetime = const ParticleLifetime(),
    Duration delay = Duration.zero,
  }) : this._(
         particles: particles,
         burstCount: burstCount,
         origin: origin,
         direction: direction,
         speed: speed,
         spread: spread,
         radius: radius,
         lifetime: lifetime,
         delay: delay,
         rate: 0,
         duration: Duration.zero,
         continuous: false,
       );

  /// 在 [delay] 结束后以 [rate] 个/秒持续生成，持续 [duration] 时长。
  /// [rate] 必须大于 0；[burstCount] 是同一发射器的开场批次，默认 0。
  /// 开场批次与后续出生共用身份、出生序号和随机流，均采用自由飞行。
  /// 校验参数并复制 [particles]；非法参数抛出 [ArgumentError]。
  ConfettiEmitter.stream({
    required List<ParticleChoice> particles,
    required double rate,
    required Duration duration,
    int burstCount = 0,
    Vec3 origin = Vec3.zero,
    Vec3 direction = const Vec3(0, -1, 0),
    NumberRange speed = const NumberRange(5, 9),
    double spread = .45,
    double radius = 0,
    ParticleLifetime lifetime = const ParticleLifetime(),
    Duration delay = Duration.zero,
  }) : this._(
         particles: particles,
         burstCount: burstCount,
         origin: origin,
         direction: direction,
         speed: speed,
         spread: spread,
         radius: radius,
         lifetime: lifetime,
         delay: delay,
         rate: rate,
         duration: duration,
         continuous: true,
       );

  ConfettiEmitter._({
    required List<ParticleChoice> particles,
    required this.origin,
    required this.direction,
    required this.speed,
    required this.spread,
    required this.radius,
    required this.lifetime,
    required this.burstCount,
    required this.rate,
    required this.duration,
    required this.delay,
    required bool continuous,
  }) : particles = List.unmodifiable(particles),
       _durationSeconds = _seconds(duration),
       _delaySeconds = _seconds(delay) {
    if (particles.isEmpty || particles.length > 64) {
      throw ArgumentError('Provide 1 through 64 particle choices');
    }
    _vector('origin', origin);
    _vector('direction', direction, nonzero: true);
    speed._validate('speed', 0, 100);
    lifetime._validate();
    _number('spread', spread, 0, math.pi);
    _number('radius', radius, 0, 10);
    _number('rate', rate, 0, 2000);
    if (continuous) {
      if (rate == 0) {
        throw ArgumentError.value(rate, 'rate', 'Expected a positive rate');
      }
      _validateDuration(
        'duration',
        duration,
        const Duration(milliseconds: 10),
        const Duration(seconds: 120),
      );
    }
    _validateDuration(
      'delay',
      delay,
      Duration.zero,
      const Duration(seconds: 120),
    );
    if (burstCount < 0 ||
        burstCount > 10000 ||
        (burstCount == 0 && rate == 0)) {
      throw ArgumentError.value(
        burstCount,
        'burstCount',
        continuous ? 'Expected 0 through 10000' : 'Expected 1 through 10000',
      );
    }
  }

  /// 1～64 个带权重的粒子候选项，不可修改。
  final List<ParticleChoice> particles;

  /// 世界发射起点，单位米；实际起点还会叠加 [radius] 指定的随机偏移。
  final Vec3 origin;

  /// 非零世界方向，内部归一化；其模长不会改变发射速度。
  final Vec3 direction;

  /// 初始速率随机范围，单位米/秒，两端须位于 [0, 100]。
  final NumberRange speed;

  /// 发射圆锥的半角，单位弧度，范围 [0, π]，按立体角均匀采样。
  /// 0 为固定方向，π 为整个球面的随机方向。
  final double spread;

  /// 起点随机球的半径，单位米，范围 [0, 10]；按球体体积均匀采样。
  /// 0 表示精确从 [origin] 出生。
  final double radius;

  /// 每个粒子的随机寿命与淡入淡出配置，从各自出生时刻起算。
  /// 寿命包含淡入淡出，结束后立即释放资源。
  final ParticleLifetime lifetime;

  /// 延迟结束时一次性生成的数量，范围 [0, 10000]。
  /// burst 构造要求大于 0；stream 中可为 0，实际出生仍受资源预算限制。
  final int burstCount;

  /// 延迟结束后的持续出生速率，单位粒子/秒，范围 [0, 2000]。
  /// stream 要求大于 0，在 [duration] 内累计生成，与 [burstCount] 叠加。
  /// burst 内部固定为 0，不开放构造入参。
  final double rate;

  /// 持续出生阶段的时长；stream 要求位于 10 毫秒～120 秒。
  /// 不包含 [delay]，也不限制已经出生粒子的寿命。
  /// burst 内部固定为 Duration.zero，不开放构造入参。
  final Duration duration;

  /// 相对本次效果开始时间的发射延迟，范围 Duration.zero～120 秒。
  final Duration delay;

  final double _durationSeconds;
  final double _delaySeconds;
}

/// 一次播放的不可变动画配方，组合多个发射源与一个随机种子。
@immutable
class ConfettiEffect {
  /// 保存 1～32 个发射源；数量不合法时抛出 [ArgumentError]。
  ConfettiEffect({required List<ConfettiEmitter> emitters, this.seed = 1})
    : emitters = List.unmodifiable(emitters) {
    if (emitters.isEmpty || emitters.length > 32) {
      throw ArgumentError('Provide 1 through 32 emitters');
    }
  }

  /// 不可修改的发射源列表；同时到期时按列表顺序消耗出生预算。
  final List<ConfettiEmitter> emitters;

  /// 出生随机序列的种子，每个发射源和出生序号派生各自的随机流。
  /// 同一实现、SDK、初始状态和时间基准下可复现，不保证跨版本轨迹一致。
  final int seed;
}

/// 单个模拟实例的资源硬上限，超额出生直接丢弃并计入统计，不延后补发。
@immutable
class ConfettiLimits {
  /// 创建资源预算，在 [ConfettiSimulation] 构造时校验。
  const ConfettiLimits({
    this.particles = 400,
    this.ribbonSegments = 840,
    this.paperTriangles = 4096,
    this.playbacks = 32,
    this.birthAttemptsPerStep = 512,
  });

  /// 同时保留的粒子数上限，范围 [1, 2000]。
  final int particles;

  /// 同时保留的彩带分段总数上限，范围 [0, 12000]；0 会拒绝彩带出生。
  final int ribbonSegments;

  /// 同时保留的纸片规范绘制三角形预算，范围 [0, 64000]。
  /// 若单张规范三角形数为 T，两种模式受力点均最多 3(T+2) 个。
  /// 单弧只新增一个物理自由度；显示最多 24T 个面，另受粒子总量约束。
  /// 规范三角形预算不等于实际显示面数量，也不能据此保证设备帧率。
  /// 0 拒绝纸片出生；几何、积分点及其占用在粒子寿命结束后释放。
  final int paperTriangles;

  /// 并行效果数上限，范围 [1, 128]；超出时 emit 抛出 [StateError]。
  final int playbacks;

  /// 同一 1/120 秒模拟步边界上的出生尝试上限，范围 [1, 10000]。
  /// 所有发射源及多次 emit 共用额度；clear 不恢复当前步额度。
  final int birthAttemptsPerStep;

  void _validate() {
    if (particles < 1 ||
        particles > 2000 ||
        ribbonSegments < 0 ||
        ribbonSegments > 12000 ||
        paperTriangles < 0 ||
        paperTriangles > 64000 ||
        playbacks < 1 ||
        playbacks > 128 ||
        birthAttemptsPerStep < 1 ||
        birthAttemptsPerStep > 10000) {
      throw ArgumentError('Invalid confetti resource limits');
    }
  }
}

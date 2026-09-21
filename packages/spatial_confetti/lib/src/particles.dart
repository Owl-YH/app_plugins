part of '../spatial_confetti.dart';

/// 不可变粒子诊断数据，仅在读取 [ConfettiSimulation.snapshot] 时复制生成。
/// 修改模拟器不会改变已取得的快照。
@immutable
class ParticleSnapshot {
  ParticleSnapshot._(_Body body, double time)
    : id = body.id,
      particle = body.recipe,
      position = body.center,
      velocity = body.velocity,
      width = body.width,
      mass = body.mass,
      area = body.area,
      materialPosition = body.materialPosition,
      materialVelocity = body.materialVelocity,
      angularVelocity = body is _PaperBody ? body.angularVelocity : null,
      bendRatio = body is _PaperBody
          ? (body.bending == null
                ? 0
                : body.bending!.displacement / body.bending!.length)
          : null,
      kineticEnergy = switch (body) {
        _RibbonBody() => body.dynamics.kineticEnergy,
        _PaperBody() => body.kineticEnergy,
        _ => null,
      },
      elasticEnergy = switch (body) {
        _RibbonBody() => body.dynamics.elasticEnergy,
        _PaperBody() => body.elasticEnergy,
        _ => null,
      },
      surfaceVertices = List.unmodifiable(
        body is _PaperBody ? body.surfaceVertices : <Vec3>[],
      ),
      surfaceTriangles = List.unmodifiable(
        body is _PaperBody ? body.surfaceTriangles : <int>[],
      ),
      angularMomentum = switch (body) {
        _RibbonBody() => body.dynamics.angularMomentum,
        _PaperBody() => body.angularMomentum,
        _ => null,
      },
      age = _asDuration(time - body.birth),
      lifetime = _asDuration(body.lifetime),
      alive = body.alive,
      nodes = List.unmodifiable(switch (body) {
        _RibbonBody() => body.points,
        _PaperBody() => body.vertices,
        _ => <Vec3>[],
      }),
      widthDirections = List.unmodifiable(switch (body) {
        _RibbonBody() => body.widthAxes,
        _PaperBody() => [body.right],
        _ => <Vec3>[],
      }),
      streakLength = body is _StreakBody ? body.lengthAt(time) : null;

  /// 模拟器内的粒子编号；被拒绝的出生可能使编号不连续。
  final int id;

  /// 此粒子使用的原始配方；随机尺寸的实际值见快照与节点数据。
  final ConfettiParticle particle;

  /// 世界中心位置，单位米；彩带使用节点质量加权得到的质心，光迹为头部。
  final Vec3 position;

  /// 中心速度，单位米/秒；彩带使用节点速度的质量加权平均，光迹为头部速度。
  final Vec3 velocity;

  /// 出生时实际采样的宽度，单位米。
  final double width;

  /// 由实际面积与面密度计算的总质量，单位千克。
  /// 光迹没有材料属性，返回 null。
  final double? mass;

  /// 材料实际面积，单位平方米；由轮廓和出生尺寸计算。
  /// 光迹没有材料属性，返回 null。
  final double? area;

  /// 材料诊断点位置；纸片取有效锚点，彩带取固定材料中点，单位米，与连续曲面共用定义。
  /// 光迹没有材料属性，返回 null。
  final Vec3? materialPosition;

  /// 材质点在固定仿真步内的实际速度，单位米/秒，不计入镜头移动。
  /// 光迹没有材料属性，返回 null。
  final Vec3? materialVelocity;

  /// 纸片整体角速度，单位弧度/秒，不包含单弧形变速度。
  /// 彩带各截面不同，光迹没有旋转状态，因此均为 null。
  final Vec3? angularVelocity;

  /// 纸片有符号弓高 / 长边长度，无量纲；刚性为 0，其他类型为 null。
  /// 正负值表示相对材料法线的相反弯曲方向。
  final double? bendRatio;

  /// 粒子的平移、旋转及内部形变总动能，单位焦耳。
  /// 光迹没有材料属性，返回 null。
  final double? kineticEnergy;

  /// 材料伸长、剪切及弯曲（彩带另含扭转）的弹性能，单位焦耳；刚性纸片为 0。
  /// 光迹没有材料属性，返回 null。
  final double? elasticEnergy;

  /// 粒子关于世界原点的总角动量，单位千克·米²/秒。
  /// 光迹没有材料属性，返回 null。
  final Vec3? angularMomentum;

  /// 从出生到当前模拟时间的年龄，舍入到微秒。
  final Duration age;

  /// 出生时实际采样的寿命。
  final Duration lifetime;

  /// 本体是否仍参与物理模拟；快照捕获后不再随模拟更新。
  final bool alive;

  /// 世界节点位置，单位米；彩带按前端到尾部排列，共 segments + 1 个。
  /// 纸片包含按轮廓顺序排列的全部世界顶点；光迹为空。
  final List<Vec3> nodes;

  /// 纸片实际绘制的曲面顶点，单位米；显示细分不增加物理自由度，其他类型为空。
  final List<Vec3> surfaceVertices;

  /// 纸片材料面索引，每三个索引组成一个三角形；其他类型为空。
  final List<int> surfaceTriangles;

  /// 截面宽度方向的单位向量；彩带每段一个，纸片仅包含其宽度轴；光迹为空。
  final List<Vec3> widthDirections;

  /// 当前世界拉伸长度，单位米；仅光迹非 null，尚未应用投影速度的可见门限。
  final double? streakLength;
}

/// 内部粒子状态，统一管理寿命与逐步更新。
abstract class _Body {
  _Body({
    required this.id,
    required this.owner,
    required this.recipe,
    required this.color,
    required this.birth,
    required this.lifetime,
    required ParticleLifetime lifetimeSettings,
    required this.width,
  }) {
    final fadeIn = _seconds(lifetimeSettings.fadeIn),
        fadeOut = _seconds(lifetimeSettings.fadeOut);
    final total = fadeIn + fadeOut;
    final scale = total > lifetime ? lifetime / total : 1.0;
    fadeInSeconds = fadeIn * scale;
    fadeOutSeconds = fadeOut * scale;
  }
  final int id;
  final int owner;
  final ConfettiParticle recipe;
  final Color color;
  final double birth;
  final double lifetime;
  late final double fadeInSeconds, fadeOutSeconds;
  final double width;
  bool alive = true;
  Vec3 get center;
  Vec3 get velocity;
  Vec3? get materialPosition => null;
  Vec3? get materialVelocity => null;
  double? get mass => null;
  double? get area => null;
  int get paperCost => 0;
  int get segmentCost => 0;
  void step(ConfettiSimulation simulation, double step);

  /// 按粒子自身年龄计算透明度。
  double opacity(double time) {
    final age = time - birth;
    if (age < 0 || age >= lifetime) return 0;
    final incoming = fadeInSeconds == 0
        ? 1.0
        : _clamp(age / fadeInSeconds, 0, 1);
    final outgoing = fadeOutSeconds == 0
        ? 1.0
        : _clamp((lifetime - age) / fadeOutSeconds, 0, 1);
    return math.min(incoming, outgoing);
  }
}

/// 节点与材料截面耦合的薄带。出生后两端自由，无固定头尾牵引。
class _RibbonBody extends _Body {
  _RibbonBody({
    required super.id,
    required super.owner,
    required RibbonParticle super.recipe,
    required super.color,
    required super.birth,
    required super.lifetime,
    required super.lifetimeSettings,
    required super.width,
    required this.length,
    required Vec3 origin,
    required Vec3 initialVelocity,
    required Vec3 direction,
    required math.Random random,
  }) {
    final count = settings.segments;
    restLength = length / count;
    final phase = random.nextDouble() * math.pi * 2;
    var tangent = -direction;
    var widthAxis = _perpendicular(
      tangent,
    ).rotated(tangent, random.nextDouble() * math.pi * 2);
    final normal = tangent.cross(widthAxis);
    points = [origin];
    widthAxes = [];
    // 只在出生时产生连续的小幅预弯，材料静止形状仍为平直；不逐步注入摆动。
    for (var i = 0; i < count; i++) {
      final next =
          (-direction +
                  normal *
                      (.03 * math.sin((i + .5) / count * math.pi * 2 + phase)))
              .normalized();
      widthAxis = _transportWidth(widthAxis, tangent, next);
      tangent = next;
      points.add(points.last + tangent * restLength);
      widthAxes.add(widthAxis);
    }
    masses = List.generate(
      count + 1,
      (i) =>
          restLength *
          width *
          settings.massPerArea *
          (i == 0 || i == count ? .5 : 1),
    );
    final spin = -direction * settings.angularSpeed.sample(random);
    final centroid = center;
    velocities = [
      for (final point in points)
        initialVelocity + spin.cross(point - centroid),
    ];
    dynamics = _RibbonDynamics(this, spin);
    geometry = _RibbonGeometry(points, widthAxes, width, dynamics.twistAngles);
    _materialVelocity =
        initialVelocity + spin.cross(materialPosition - centroid);
  }
  RibbonParticle get settings => recipe as RibbonParticle;
  final double length;
  late final double restLength;
  late final List<Vec3> points, velocities, widthAxes;
  late final List<double> masses;
  late final _RibbonDynamics dynamics;
  late final _RibbonGeometry geometry;
  late Vec3 _materialVelocity;
  @override
  int get segmentCost => settings.segments;
  @override
  double get mass => area * settings.massPerArea;
  @override
  double get area => length * width;
  Vec3 _weighted(List<Vec3> values) {
    var x = 0.0, y = 0.0, z = 0.0;
    for (var i = 0; i < values.length; i++) {
      x += values[i].x * masses[i];
      y += values[i].y * masses[i];
      z += values[i].z * masses[i];
    }
    return Vec3(x / mass, y / mass, z / mass);
  }

  @override
  Vec3 get center => _weighted(points);
  @override
  Vec3 get velocity => _weighted(velocities);
  @override
  Vec3 get materialPosition => geometry.position(.5);
  @override
  Vec3 get materialVelocity => _materialVelocity;
  @override
  void step(ConfettiSimulation simulation, double step) {
    final previous = materialPosition;
    dynamics.step(simulation, step);
    geometry.update();
    _materialVelocity = (materialPosition - previous) / step;
  }
}

/// 在整个单位球面上均匀采样方向。
Vec3 _randomDirection(math.Random random) {
  final z = random.nextDouble() * 2 - 1;
  final angle = random.nextDouble() * math.pi * 2;
  final radius = math.sqrt(math.max(0, 1 - z * z));
  return Vec3(radius * math.cos(angle), radius * math.sin(angle), z);
}

/// 在指定方向的圆锥内按立体角均匀采样，spread 为半角弧度。
Vec3 _coneDirection(math.Random random, Vec3 direction, double spread) {
  final forward = direction.normalized();
  final right = _perpendicular(forward);
  final up = forward.cross(right);
  final cosine = 1 - random.nextDouble() * (1 - math.cos(spread));
  final sine = math.sqrt(math.max(0, 1 - cosine * cosine));
  final angle = random.nextDouble() * math.pi * 2;
  return forward * cosine +
      (right * math.cos(angle) + up * math.sin(angle)) * sine;
}

part of '../spatial_confetti.dart';

/// 纸片生命周期及派生姿态；仅追加一个长边弧形自由度。
/// 规范轮廓同时拥有面积、惯量与受力积分点；模型边界见 doc/paper-aerodynamics.md。
class _PaperBody extends _Body {
  _PaperBody({
    required super.id,
    required super.owner,
    required PaperParticle super.recipe,
    required super.color,
    required super.birth,
    required super.lifetime,
    required super.lifetimeSettings,
    required this.geometry,
    required Size dimensions,
    required this.position,
    required this.speed,
    required math.Random random,
  }) : height = dimensions.height,
       sx = dimensions.width / geometry.width,
       sy = dimensions.height / geometry.height,
       super(width: dimensions.width) {
    localVertices = [
      for (final p in geometry.vertices) Offset(p.dx * sx, p.dy * sy),
    ];
    area = geometry.area * sx * sy;
    mass = area * settings.massPerArea;
    ixx = geometry.yy * sx * sy * sy * sy * settings.massPerArea;
    iyy = geometry.xx * sx * sx * sx * sy * settings.massPerArea;
    ixy = -geometry.xy * sx * sx * sy * sy * settings.massPerArea;
    izz = ixx + iyy;
    determinant = ixx * iyy - ixy * ixy;
    // sqrt(12 I平面 / mass)：对矩形，两个对角元分别为绕该轴翻转的弦长。
    // 保留非对角元，任意旋转的同一轮廓不会因选择不同局部坐标而改变气动。
    final root = math.sqrt(determinant);
    final scale = math.sqrt(12 / mass) / math.sqrt(ixx + iyy + 2 * root);
    chordXX = (ixx + root) * scale;
    chordXY = ixy * scale;
    chordYY = (iyy + root) * scale;
    sampleData = Float64List(geometry.samples.length * 3);
    pressureWeights = Float64List(geometry.samples.length);
    for (var i = 0; i < geometry.samples.length; i++) {
      final sample = geometry.samples[i];
      sampleData[i * 3] = sample.$1.dx * sx;
      sampleData[i * 3 + 1] = sample.$1.dy * sy;
      sampleData[i * 3 + 2] = sample.$2 * sx * sy;
    }
    final material = geometry.scaledAnchor(localVertices);
    anchor = Vec3(material.dx, material.dy, 0);
    final axis = _randomDirection(random);
    right = Vec3.right.rotated(axis, random.nextDouble() * math.pi * 2);
    up = _perpendicular(
      right,
    ).rotated(right, random.nextDouble() * math.pi * 2);
    normal = right.cross(up).normalized(Vec3.forward);
    momentum = _world(
      _inertia(
        _local(_randomDirection(random) * settings.angularSpeed.sample(random)),
      ),
    );
    if (settings.bendEnabled && settings.maximumBendRatio > 0)
      bending = _PaperBending(this);
  }

  _PaperBending? bending;
  final _PaperGeometry geometry;
  final double height, sx, sy;
  late final List<Offset> localVertices;
  late final Float64List sampleData;
  late final Float64List pressureWeights;
  late final Vec3 anchor;
  @override
  late final double area;
  @override
  late final double mass;
  late final double ixx, iyy, ixy, izz, determinant;
  late final double chordXX, chordXY, chordYY;
  Vec3 position, speed;
  late Vec3 right, up, normal, momentum;
  final _matrix = Float64List(36),
      _rhs = Float64List(6),
      _scales = Float64List(6);
  PaperParticle get settings => recipe as PaperParticle;
  Vec3 _local(Vec3 value) =>
      Vec3(right.dot(value), up.dot(value), normal.dot(value));
  Vec3 _world(Vec3 value) => right * value.x + up * value.y + normal * value.z;
  Vec3 _inertia(Vec3 value) => Vec3(
    (ixx + bendInertia) * value.x + ixy * value.y,
    ixy * value.x + (iyy + bendInertia) * value.y,
    izz * value.z,
  );
  double get bendInertia => bending?.rotationInertia ?? 0;
  Vec3 _inverseInertia(Vec3 value) {
    final x = ixx + bendInertia, y = iyy + bendInertia;
    final det = x * y - ixy * ixy;
    return Vec3(
      (y * value.x - ixy * value.y) / det,
      (x * value.y - ixy * value.x) / det,
      value.z / izz,
    );
  }

  Vec3 get angularVelocity => _world(_inverseInertia(_local(momentum)));
  Vec3 get angularMomentum => position.cross(speed * mass) + momentum;
  double get kineticEnergy =>
      mass * speed.lengthSquared * .5 +
      momentum.dot(angularVelocity) * .5 +
      (bending?.kineticEnergy ?? 0);
  double get elasticEnergy => bending?.elasticEnergy ?? 0;
  Vec3 localMaterial(Offset p) =>
      Vec3(p.dx, p.dy, bending == null ? 0 : bending!.heightAt(p));
  List<Vec3> get vertices => [
    for (final p in localVertices) position + _world(localMaterial(p)),
  ];
  List<Vec3> get surfaceVertices => bending?.surfaceVertices ?? vertices;
  List<int> get surfaceTriangles =>
      bending?.mesh.triangles ?? geometry.triangles;
  @override
  Vec3 get center => position;
  @override
  Vec3 get velocity => speed;
  @override
  Vec3 get materialPosition =>
      position + _world(localMaterial(Offset(anchor.x, anchor.y)));
  @override
  Vec3 get materialVelocity =>
      speed +
      angularVelocity.cross(materialPosition - position) +
      normal * (bending?.velocityAt(Offset(anchor.x, anchor.y)) ?? 0);
  @override
  int get paperCost => geometry.triangleCount;

  @override
  void step(ConfettiSimulation simulation, double step) {
    // 通常 4 个子步；快速转动时按每子步约 0.12 rad 细分，最多 16 个。
    // 仅依赖物理状态，不按显示帧率或当前设备耗时切换精度。
    final substeps = (angularVelocity.length * step / .12).ceil().clamp(4, 16);
    final dt = step / substeps;
    for (var i = 0; i < substeps; i++) {
      speed += simulation.gravity * (dt * .5);
      position += speed * (dt * .5);
      _rotate(dt * .5);
      if (bending case final arc?) {
        arc.step(simulation, dt, (i + .5) * dt - step);
      } else if (settings.dragCoefficient != 0 ||
          settings.surfaceFriction != 0) {
        _air(simulation, dt, (i + .5) * dt - step);
      }
      _rotate(dt * .5);
      position += speed * (dt * .5);
      speed += simulation.gravity * (dt * .5);
    }
  }

  /// 保持世界角动量，使用中点姿态估计角速度；无经验阻尼或主动翻转力。
  void _rotate(double dt) {
    final first = angularVelocity;
    if (first.lengthSquared < 1e-20) return;
    final halfAngle = first.length * dt * .5, axis = first.normalized();
    final r = right.rotated(axis, halfAngle),
        u = up.rotated(axis, halfAngle),
        n = r.cross(u);
    final local = _inverseInertia(
      Vec3(r.dot(momentum), u.dot(momentum), n.dot(momentum)),
    );
    final middle = r * local.x + u * local.y + n * local.z;
    final direction = middle.normalized(), angle = middle.length * dt;
    right = right.rotated(direction, angle).normalized();
    up = up.rotated(direction, angle);
    up = (up - right * right.dot(up)).normalized(_perpendicular(right));
    normal = right.cross(up).normalized(Vec3.forward);
  }

  /// 用同一 6×6 正定系统同时解全部表面冲量，避免采样顺序制造净力矩。
  /// 切平面两个方向共用相对切向速度模长，摩擦不依赖平面坐标轴选择。
  void _air(ConfettiSimulation simulation, double dt, double offset) {
    final centerAir = simulation._airAt(position, offset: offset);
    _rotationalLift(centerAir, dt * .5);
    final v = _local(speed), w = _inverseInertia(_local(momentum));
    final pressureFactor = _pressureProfile(_local(centerAir) - v);
    _matrix.fillRange(0, 36, 0);
    _matrix[0] = _matrix[7] = _matrix[14] = mass;
    _matrix[21] = ixx;
    _matrix[28] = iyy;
    _matrix[35] = izz;
    _matrix[22] = _matrix[27] = ixy;
    _rhs[0] = mass * v.x;
    _rhs[1] = mass * v.y;
    _rhs[2] = mass * v.z;
    final spin = _inertia(w);
    _rhs[3] = spin.x;
    _rhs[4] = spin.y;
    _rhs[5] = spin.z;
    for (var i = 0; i < sampleData.length; i += 3) {
      final x = sampleData[i], y = sampleData[i + 1];
      final worldAir = simulation._airAt(
        position + right * x + up * y,
        offset: offset,
      );
      final air = _local(worldAir);
      final rx = air.x - v.x + w.z * y, ry = air.y - v.y - w.z * x;
      final rz = air.z - v.z - w.x * y + w.y * x;
      final factor = .5 * 1.225 * sampleData[i + 2] * dt;
      // 正面压力以 |u| u_n 缩放，攻角响应包含已有的平移升/阻力分量。
      // 正权重、局部材料速度和力臂配对：静止空气中的总功率不会为正。
      final normalRate =
          factor *
          settings.dragCoefficient *
          pressureFactor *
          pressureWeights[i ~/ 3] *
          math.sqrt(rx * rx + ry * ry + rz * rz);
      final tangentRate =
          factor * settings.surfaceFriction * math.sqrt(rx * rx + ry * ry);
      _normalRow(normalRate, air.z, x, y);
      _tangentRow(tangentRate, air.x, 0, -y);
      _tangentRow(tangentRate, air.y, 1, x);
    }
    _solve();
    speed = _world(Vec3(_rhs[0], _rhs[1], _rhs[2]));
    momentum = _world(_inertia(Vec3(_rhs[3], _rhs[4], _rhs[5])));
    _rotationalLift(centerAir, dt * .5);
  }

  /// 攻角相关的迎流载荷。正权重归一化保持面积，力矩由实际材料点产生。
  /// 参考二维薄片的附着/分离流及压力中心形式；任意轮廓的载荷分布为工程近似。
  double _pressureProfile(Vec3 relative) {
    final tangentSpeed = math.sqrt(
      relative.x * relative.x + relative.y * relative.y,
    );
    if (settings.dragCoefficient == 0 || tangentSpeed < 1e-9) {
      pressureWeights.fillRange(0, pressureWeights.length, 1);
      return 1;
    }
    final alpha = math.atan2(relative.z.abs(), tangentSpeed);
    final (pressureFactor, centerFraction) = _paperPressureResponse(alpha);
    final tx = relative.x / tangentSpeed, ty = relative.y / tangentSpeed;
    final variance = (iyy * tx * tx - 2 * ixy * tx * ty + ixx * ty * ty) / mass;
    final chord = math.sqrt(12 * variance);
    final bias = 12 * math.max(0, centerFraction) / chord;
    var weightedArea = 0.0;
    for (var i = 0; i < pressureWeights.length; i++) {
      final exponent =
          -bias * (sampleData[i * 3] * tx + sampleData[i * 3 + 1] * ty);
      // 对极细凹轮廓约束指数动态范围，不移动质量、不替换真实轮廓。
      final weight = math.exp(_clamp(exponent, -12, 12));
      pressureWeights[i] = weight;
      weightedArea += weight * sampleData[i * 3 + 2];
    }
    final normalization = area / weightedArea;
    for (var i = 0; i < pressureWeights.length; i++)
      pressureWeights[i] *= normalization;
    return pressureFactor;
  }

  /// 旋转环流 F = ρ A C_R (弦长张量·ω平面) × (v - wind) / 2。
  /// 使用速度空间精确旋转，保持相对质心速度模长，避免升力凭空增加动能。
  /// 绕法线的纯自转不产生这一项；力矩已由压力分布与表面摩擦负责。
  void _rotationalLift(Vec3 air, double dt) {
    if (settings.dragCoefficient == 0) return;
    final w = _inverseInertia(_local(momentum));
    final circulation = _world(
      Vec3(chordXX * w.x + chordXY * w.y, chordXY * w.x + chordYY * w.y, 0),
    );
    final rate =
        circulation *
        (.5 * 1.225 * area / mass * 1.1 * settings.dragCoefficient / 1.15);
    final magnitude = rate.length;
    if (magnitude < 1e-12) return;
    speed = air + (speed - air).rotated(rate / magnitude, magnitude * dt);
  }

  void _normalRow(double rate, double air, double x, double y) {
    if (rate == 0) return;
    _matrix[14] += rate;
    _matrix[15] += rate * y;
    _matrix[20] += rate * y;
    _matrix[16] -= rate * x;
    _matrix[26] -= rate * x;
    _matrix[21] += rate * y * y;
    _matrix[28] += rate * x * x;
    _matrix[22] -= rate * x * y;
    _matrix[27] -= rate * x * y;
    _rhs[2] += rate * air;
    _rhs[3] += rate * air * y;
    _rhs[4] -= rate * air * x;
  }

  void _tangentRow(double rate, double air, int axis, double arm) {
    if (rate == 0) return;
    _matrix[axis * 7] += rate;
    _matrix[axis * 6 + 5] += rate * arm;
    _matrix[30 + axis] += rate * arm;
    _matrix[35] += rate * arm * arm;
    _rhs[axis] += rate * air;
    _rhs[5] += rate * air * arm;
  }

  /// 对角缩放后的 Cholesky 分解；复用缓冲，避免质量和惯量的单位尺度差。
  void _solve() => _solvePaperSystem(_matrix, _rhs, _scales, 6);
}

/// 攻角压力与压力中心响应；刚性和柔性纸片共用，属于薄片气动近似。
(double, double) _paperPressureResponse(double alpha) {
  final attached =
      1 /
      (1 + math.exp(2 * (alpha - 14 * math.pi / 180) / (6 * math.pi / 180)));
  final sine = math.sin(alpha), cosine = math.cos(alpha);
  return (
    attached * (5.2 * cosine + 5 * sine * sine) / 1.9 + 1 - attached,
    attached * (.3 - 3.5 * alpha * alpha) +
        (1 - attached) * .2 * (1 - alpha / (math.pi * .5)),
  );
}

/// 对角缩放后原位求解正定气动系统；缓冲按粒子复用。
void _solvePaperSystem(
  Float64List matrix,
  Float64List rhs,
  Float64List scales,
  int size,
) {
  for (var i = 0; i < size; i++) scales[i] = math.sqrt(matrix[i * (size + 1)]);
  for (var i = 0; i < size; i++) {
    rhs[i] /= scales[i];
    for (var j = 0; j < size; j++)
      matrix[i * size + j] /= scales[i] * scales[j];
  }
  for (var i = 0; i < size; i++) {
    for (var j = 0; j <= i; j++) {
      var value = matrix[i * size + j];
      for (var k = 0; k < j; k++)
        value -= matrix[i * size + k] * matrix[j * size + k];
      matrix[i * size + j] = i == j
          ? math.sqrt(value)
          : value / matrix[j * (size + 1)];
    }
    for (var j = 0; j < i; j++) rhs[i] -= matrix[i * size + j] * rhs[j];
    rhs[i] /= matrix[i * (size + 1)];
  }
  for (var i = size - 1; i >= 0; i--) {
    for (var j = i + 1; j < size; j++) rhs[i] -= matrix[j * size + i] * rhs[j];
    rhs[i] /= matrix[i * (size + 1)];
  }
  for (var i = 0; i < size; i++) rhs[i] /= scales[i];
}

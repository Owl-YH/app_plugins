part of '../spatial_confetti.dart';

/// 将宽度方向沿两条切线最小旋转传递；反向退化沿已有材质宽度翻转。
Vec3 _transportWidth(Vec3 width, Vec3 from, Vec3 to) {
  final c = _clamp(from.dot(to), -1, 1);
  if (c <= -1 + 1e-8) {
    final axis = (width - from * width.dot(from)).normalized(
      _perpendicular(from),
    );
    final result = width.rotated(axis, math.pi);
    return (result - to * result.dot(to)).normalized(width);
  }
  final kx = from.y * to.z - from.z * to.y,
      ky = from.z * to.x - from.x * to.z,
      kz = from.x * to.y - from.y * to.x;
  final ax = ky * width.z - kz * width.y,
      ay = kz * width.x - kx * width.z,
      az = kx * width.y - ky * width.x;
  var x = width.x + ax + (ky * az - kz * ay) / (1 + c),
      y = width.y + ay + (kz * ax - kx * az) / (1 + c),
      z = width.z + az + (kx * ay - ky * ax) / (1 + c);
  final along = x * to.x + y * to.y + z * to.z;
  x -= to.x * along;
  y -= to.y * along;
  z -= to.z * along;
  final n = math.sqrt(x * x + y * y + z * z);
  return n > 1e-12 ? Vec3(x / n, y / n, z / n) : width;
}

/// 降维薄带求解器。切线由中心线确定，截面独立自由度仅为绕切线的扭转。
/// 位置梯度包含截面平行传输，弯曲与扭转双向耦合；忽略很小的截面横向惯量。
class _RibbonDynamics {
  _RibbonDynamics(this.body, Vec3 initialSpin)
    : spin = Float64List(body.segmentCost),
      lengths = Float64List(body.segmentCost),
      twistAngles = Float64List(body.segmentCost - 1),
      rotations = Float64List(body.segmentCost),
      tangents = List.filled(body.segmentCost, Vec3.forward),
      previousTangents = List.filled(body.segmentCost, Vec3.forward),
      previousWidths = List.of(body.widthAxes),
      previousPoints = List.of(body.points),
      stretchLambda = Float64List(body.segmentCost),
      _upper = Float64List(body.segmentCost),
      _rhs = Float64List(body.segmentCost),
      _lengthImpulse = Float64List(body.segmentCost),
      bendLambda = Float64List((body.segmentCost - 1) * 3) {
    final m = body.mass / body.segmentCost;
    inertia =
        m *
        (body.width * body.width +
            body.settings.thickness * body.settings.thickness) /
        12;
    for (var i = 0; i < spin.length; i++) {
      final edge = body.points[i + 1] - body.points[i];
      lengths[i] = edge.length;
      tangents[i] = edge.normalized();
      spin[i] = initialSpin.dot(tangents[i]);
    }
  }
  final _RibbonBody body;
  final Float64List spin, lengths, stretchLambda, bendLambda;
  final Float64List twistAngles, rotations;
  final _gradients = Float64List(33), _matrix = Float64List(9);
  final _jointRhs = Float64List(3), _delta = Float64List(3);
  final Float64List _upper, _rhs, _lengthImpulse;
  final List<Vec3> tangents, previousTangents, previousWidths, previousPoints;
  late final double inertia;
  static const substeps = 1, iterations = 8;

  double get kineticEnergy {
    var total = 0.0;
    for (var i = 0; i < body.points.length; i++)
      total += body.masses[i] * body.velocities[i].lengthSquared * .5;
    for (final speed in spin) total += inertia * speed * speed * .5;
    return total;
  }

  Vec3 get angularMomentum {
    var result = Vec3.zero;
    for (var i = 0; i < body.points.length; i++)
      result += body.points[i].cross(body.velocities[i] * body.masses[i]);
    for (var i = 0; i < spin.length; i++)
      result += tangents[i] * (inertia * spin[i]);
    return result;
  }

  double get elasticEnergy {
    var result = 0.0;
    final h = body.restLength;
    for (var i = 0; i < spin.length; i++) {
      final error = (body.points[i + 1] - body.points[i]).length - h;
      result += 100 / (2 * h) * error * error;
      if (i + 1 < spin.length) {
        final kb =
            tangents[i].cross(tangents[i + 1]) *
            (2 / math.max(1e-6, 1 + tangents[i].dot(tangents[i + 1])));
        final out = kb.dot(body.widthAxes[i] + body.widthAxes[i + 1]) * .5;
        final inside =
            kb.dot(
              tangents[i].cross(body.widthAxes[i]) +
                  tangents[i + 1].cross(body.widthAxes[i + 1]),
            ) *
            .5;
        final twist = _twist(i);
        result +=
            (body.settings.bendingStiffness * out * out +
                body.settings.inPlaneBendingStiffness * inside * inside +
                body.settings.torsionalStiffness * twist * twist) /
            (2 * h);
      }
    }
    return result;
  }

  double _angle(Vec3 a, Vec3 b, Vec3 tangent) =>
      math.atan2(tangent.dot(a.cross(b)), _clamp(a.dot(b), -1, 1));
  double _twist(int i) {
    final principal = _angle(
      _transportWidth(body.widthAxes[i], tangents[i], tangents[i + 1]),
      body.widthAxes[i + 1],
      tangents[i + 1],
    );
    return principal +
        ((twistAngles[i] - principal) / (2 * math.pi)).round() * 2 * math.pi;
  }

  void _rotateMaterial(int i, double angle) {
    body.widthAxes[i] = body.widthAxes[i].rotated(tangents[i], angle);
    rotations[i] += angle;
    if (i > 0) twistAngles[i - 1] += angle;
    if (i < twistAngles.length) twistAngles[i] -= angle;
  }

  void _refresh(int first, int last) {
    for (
      var i = math.max(0, first);
      i <= math.min(spin.length - 1, last);
      i++
    ) {
      final a = body.points[i], b = body.points[i + 1];
      final dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z;
      final length = math.sqrt(dx * dx + dy * dy + dz * dz);
      lengths[i] = length;
      final next = length > 1e-12
          ? Vec3(dx / length, dy / length, dz / length)
          : tangents[i];
      body.widthAxes[i] = _transportWidth(body.widthAxes[i], tangents[i], next);
      tangents[i] = next;
    }
    for (
      var i = math.max(0, first - 1);
      i <= math.min(twistAngles.length - 1, last);
      i++
    ) {
      twistAngles[i] = _twist(i);
    }
  }

  void step(ConfettiSimulation simulation, double outerStep) {
    final dt = outerStep / substeps;
    for (var sub = 0; sub < substeps; sub++) {
      rotations.fillRange(0, rotations.length, 0);
      previousPoints.setAll(0, body.points);
      previousWidths.setAll(0, body.widthAxes);
      previousTangents.setAll(0, tangents);
      for (var i = 0; i < body.points.length; i++)
        body.velocities[i] += simulation.gravity * dt;
      _air(simulation, dt, -outerStep + (sub + .5) * dt);
      for (var i = 0; i < body.points.length; i++)
        body.points[i] += body.velocities[i] * dt;
      _refresh(0, spin.length - 1);
      for (var i = 0; i < spin.length; i++) _rotateMaterial(i, spin[i] * dt);
      stretchLambda.fillRange(0, stretchLambda.length, 0);
      bendLambda.fillRange(0, bendLambda.length, 0);
      for (var pass = 0; pass < iterations; pass++) {
        for (var j = 0; j < spin.length - 1; j++) {
          final i = pass.isEven ? j : spin.length - 2 - j;
          _joint(i, dt, false);
        }
        _projectLengths(dt, false);
      }
      for (var i = 0; i < body.points.length; i++)
        body.velocities[i] = (body.points[i] - previousPoints[i]) / dt;
      for (var i = 0; i < spin.length; i++) {
        final transported = _transportWidth(
          previousWidths[i],
          previousTangents[i],
          tangents[i],
        );
        final angle = _angle(transported, body.widthAxes[i], tangents[i]);
        spin[i] =
            (angle +
                ((rotations[i] - angle) / (2 * math.pi)).round() *
                    2 *
                    math.pi) /
            dt;
      }
      if (body.settings.damping > 0) {
        for (var i = 0; i < spin.length - 1; i++) _joint(i, dt, true);
        _projectLengths(dt, true);
      }
    }
  }

  /// 整条节点链的长度约束构成三对角系统，一次传播端点张力。
  /// 每轮重新线性化长度，仍保留 XPBD 柔度和质量加权修正。
  void _projectLengths(double dt, bool damping) {
    final alpha = damping ? 0.0 : body.restLength / 100 / (dt * dt);
    final decay = 1 - math.exp(-body.settings.damping * dt);
    for (var i = 0; i < spin.length; i++) {
      final length = (body.points[i + 1] - body.points[i]).length;
      final wa = 1 / body.masses[i], wb = 1 / body.masses[i + 1];
      final lower = i > 0 ? -wa * tangents[i - 1].dot(tangents[i]) : 0.0;
      final upper = i + 1 < spin.length
          ? -wb * tangents[i].dot(tangents[i + 1])
          : 0.0;
      final diagonal = wa + wb + alpha - (i > 0 ? lower * _upper[i - 1] : 0);
      final value = damping
          ? -decay *
                (body.velocities[i + 1] - body.velocities[i]).dot(tangents[i])
          : -(length - body.restLength) - alpha * stretchLambda[i];
      _upper[i] = upper / diagonal;
      _rhs[i] = (value - (i > 0 ? lower * _rhs[i - 1] : 0)) / diagonal;
    }
    for (var i = spin.length - 1; i >= 0; i--) {
      _lengthImpulse[i] =
          _rhs[i] -
          (i + 1 < spin.length ? _upper[i] * _lengthImpulse[i + 1] : 0);
      if (!damping) stretchLambda[i] += _lengthImpulse[i];
    }
    for (var i = 0; i < body.points.length; i++) {
      final impulse =
          (i > 0 ? tangents[i - 1] * _lengthImpulse[i - 1] : Vec3.zero) -
          (i < spin.length ? tangents[i] * _lengthImpulse[i] : Vec3.zero);
      if (damping) {
        body.velocities[i] += impulse / body.masses[i];
      } else {
        body.points[i] += impulse / body.masses[i];
      }
    }
    if (!damping) _refresh(0, spin.length - 1);
  }

  /// 离散曲率及扭转的解析梯度，含材料轴随切线最小旋转的导数。
  void _joint(int i, double dt, bool damping) {
    final w0 = 1 / body.masses[i],
        w1 = 1 / body.masses[i + 1],
        w2 = 1 / body.masses[i + 2];
    _gradients.fillRange(0, 33, 0);
    _matrix.fillRange(0, 9, 0);
    _jointRhs.fillRange(0, 3, 0);
    for (var component = 0; component < 3; component++) {
      final settings = body.settings;
      final stiffness = component == 0
          ? settings.bendingStiffness
          : component == 1
          ? settings.inPlaneBendingStiffness
          : settings.torsionalStiffness;
      if (stiffness == 0) {
        _matrix[component * 3 + component] = 1;
        continue;
      }
      final t0 = tangents[i], t1 = tangents[i + 1];
      final l0 = math.max(1e-9, lengths[i]),
          l1 = math.max(1e-9, lengths[i + 1]);
      final denominator = math.max(1e-6, 1 + t0.dot(t1)),
          scale = 2 / denominator;
      final kx = (t0.y * t1.z - t0.z * t1.y) * scale,
          ky = (t0.z * t1.x - t0.x * t1.z) * scale,
          kz = (t0.x * t1.y - t0.y * t1.x) * scale;
      late double ax, ay, az, bx, by, bz, value, s0, s1;
      if (component == 2) {
        value = _twist(i);
        ax = kx / (2 * l0);
        ay = ky / (2 * l0);
        az = kz / (2 * l0);
        bx = kx / (2 * l1);
        by = ky / (2 * l1);
        bz = kz / (2 * l1);
        s0 = -1;
        s1 = 1;
      } else {
        final w0 = body.widthAxes[i], w1 = body.widthAxes[i + 1];
        final d0x = component == 0 ? w0.x : t0.y * w0.z - t0.z * w0.y,
            d0y = component == 0 ? w0.y : t0.z * w0.x - t0.x * w0.z,
            d0z = component == 0 ? w0.z : t0.x * w0.y - t0.y * w0.x;
        final d1x = component == 0 ? w1.x : t1.y * w1.z - t1.z * w1.y,
            d1y = component == 0 ? w1.y : t1.z * w1.x - t1.x * w1.z,
            d1z = component == 0 ? w1.z : t1.x * w1.y - t1.y * w1.x;
        final mx = (d0x + d1x) * .5,
            my = (d0y + d1y) * .5,
            mz = (d0z + d1z) * .5;
        value = kx * mx + ky * my + kz * mz;
        ax = (t1.y * mz - t1.z * my) * scale - t1.x * value / denominator;
        ay = (t1.z * mx - t1.x * mz) * scale - t1.y * value / denominator;
        az = (t1.x * my - t1.y * mx) * scale - t1.z * value / denominator;
        bx = (my * t0.z - mz * t0.y) * scale - t0.x * value / denominator;
        by = (mz * t0.x - mx * t0.z) * scale - t0.y * value / denominator;
        bz = (mx * t0.y - my * t0.x) * scale - t0.z * value / denominator;
        final aDot = ax * t0.x + ay * t0.y + az * t0.z,
            bDot = bx * t1.x + by * t1.y + bz * t1.z;
        ax = (ax - t0.x * aDot) / l0;
        ay = (ay - t0.y * aDot) / l0;
        az = (az - t0.z * aDot) / l0;
        bx = (bx - t1.x * bDot) / l1;
        by = (by - t1.y * bDot) / l1;
        bz = (bz - t1.z * bDot) / l1;
        // 平行传输的横向导数沿切线，与曲率二项向量正交；扭转导数保留。
        s0 =
            (kx * (t0.y * d0z - t0.z * d0y) +
                ky * (t0.z * d0x - t0.x * d0z) +
                kz * (t0.x * d0y - t0.y * d0x)) *
            .5;
        s1 =
            (kx * (t1.y * d1z - t1.z * d1y) +
                ky * (t1.z * d1x - t1.x * d1z) +
                kz * (t1.x * d1y - t1.y * d1x)) *
            .5;
      }
      final cx = ax - bx, cy = ay - by, cz = az - bz;
      final alpha = damping ? 0.0 : body.restLength / stiffness / (dt * dt),
          index = i * 3 + component;
      var rhs = -value - alpha * bendLambda[index];
      if (damping) {
        final v0 = body.velocities[i],
            v1 = body.velocities[i + 1],
            v2 = body.velocities[i + 2];
        final rate =
            -ax * v0.x -
            ay * v0.y -
            az * v0.z +
            cx * v1.x +
            cy * v1.y +
            cz * v1.z +
            bx * v2.x +
            by * v2.y +
            bz * v2.z +
            s0 * spin[i] +
            s1 * spin[i + 1];
        rhs = -(1 - math.exp(-settings.damping * dt)) * rate;
      }
      final base = component * 11;
      _gradients[base] = -ax;
      _gradients[base + 1] = -ay;
      _gradients[base + 2] = -az;
      _gradients[base + 3] = cx;
      _gradients[base + 4] = cy;
      _gradients[base + 5] = cz;
      _gradients[base + 6] = bx;
      _gradients[base + 7] = by;
      _gradients[base + 8] = bz;
      _gradients[base + 9] = s0;
      _gradients[base + 10] = s1;
      _matrix[component * 3 + component] = alpha;
      _jointRhs[component] = rhs;
    }
    // 同一接头的三种应变共用一次 3×3 对称系统，避免逐标量刷新截面。
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col <= row; col++) {
        final a = row * 11, b = col * 11;
        var value = 0.0;
        for (var k = 0; k < 3; k++) {
          value +=
              _gradients[a + k] * _gradients[b + k] * w0 +
              _gradients[a + k + 3] * _gradients[b + k + 3] * w1 +
              _gradients[a + k + 6] * _gradients[b + k + 6] * w2;
        }
        value +=
            (_gradients[a + 9] * _gradients[b + 9] +
                _gradients[a + 10] * _gradients[b + 10]) /
            inertia;
        _matrix[row * 3 + col] += value;
      }
    }
    // Cholesky 分解；柔度为正，零刚度分量采用独立单位行。
    final l00 = math.sqrt(math.max(1e-30, _matrix[0]));
    final l10 = _matrix[3] / l00, l20 = _matrix[6] / l00;
    final l11 = math.sqrt(math.max(1e-30, _matrix[4] - l10 * l10));
    final l21 = (_matrix[7] - l20 * l10) / l11;
    final l22 = math.sqrt(math.max(1e-30, _matrix[8] - l20 * l20 - l21 * l21));
    final y0 = _jointRhs[0] / l00, y1 = (_jointRhs[1] - l10 * y0) / l11;
    _delta[2] = (_jointRhs[2] - l20 * y0 - l21 * y1) / l22 / l22;
    _delta[1] = (y1 - l21 * _delta[2]) / l11;
    _delta[0] = (y0 - l10 * _delta[1] - l20 * _delta[2]) / l00;
    final values = damping ? body.velocities : body.points;
    for (var node = 0; node < 3; node++) {
      var x = 0.0, y = 0.0, z = 0.0;
      for (var component = 0; component < 3; component++) {
        final base = component * 11 + node * 3, delta = _delta[component];
        x += _gradients[base] * delta;
        y += _gradients[base + 1] * delta;
        z += _gradients[base + 2] * delta;
      }
      final p = values[i + node], mass = body.masses[i + node];
      values[i + node] = Vec3(p.x + x / mass, p.y + y / mass, p.z + z / mass);
    }
    if (!damping) _refresh(i - 1, i + 2);
    for (var edge = 0; edge < 2; edge++) {
      var angle = 0.0;
      for (var c = 0; c < 3; c++)
        angle += _gradients[c * 11 + 9 + edge] * _delta[c] / inertia;
      if (damping) {
        spin[i + edge] += angle;
      } else {
        _rotateMaterial(i + edge, angle);
      }
    }
    if (!damping) {
      for (var c = 0; c < 3; c++) bendLambda[i * 3 + c] += _delta[c];
    }
  }

  /// 固定 2×2 积分点；截面横向运动由节点导数给出，扭转速度单独计入。
  /// 力通过同一材质位置的雅可比分配，保证虚功一致、不重复计算力矩。
  void _air(ConfettiSimulation simulation, double dt, double offset) {
    final settings = body.settings;
    if (settings.dragCoefficient == 0 && settings.surfaceFriction == 0) return;
    const gauss = .5773502691896258;
    for (var i = 0; i < spin.length; i++) {
      final tangent = tangents[i],
          widthAxis = body.widthAxes[i],
          normal = tangent.cross(widthAxis);
      final length = math.max(
        1e-9,
        (body.points[i + 1] - body.points[i]).length,
      );
      final area = body.restLength * body.width * .25;
      for (final along in const [-gauss, gauss]) {
        final b = (1 + along) * .5, a = 1 - b;
        for (final across in const [-gauss, gauss]) {
          final arm = widthAxis * (across * body.width * .5);
          final position = body.points[i] * a + body.points[i + 1] * b + arm;
          final air = simulation._airAt(position, offset: offset);
          for (var component = 0; component < 3; component++) {
            final axis = component == 0
                ? normal
                : component == 1
                ? widthAxis
                : tangent;
            final coefficient = component == 0
                ? settings.dragCoefficient
                : settings.surfaceFriction;
            if (coefficient == 0) continue;
            final correction = arm * (axis.dot(tangent) / length);
            final g0 = axis * a + correction, g1 = axis * b - correction;
            final gs = axis.dot(tangent.cross(arm));
            final speed =
                air.dot(axis) -
                g0.dot(body.velocities[i]) -
                g1.dot(body.velocities[i + 1]) -
                gs * spin[i];
            final effective =
                g0.lengthSquared / body.masses[i] +
                g1.lengthSquared / body.masses[i + 1] +
                gs * gs / inertia;
            final rate = .5 * 1.225 * area * coefficient * speed.abs() * dt;
            final impulse = rate * speed / (1 + rate * effective);
            body.velocities[i] += g0 * (impulse / body.masses[i]);
            body.velocities[i + 1] += g1 * (impulse / body.masses[i + 1]);
            spin[i] += gs * impulse / inertia;
          }
        }
      }
    }
  }
}

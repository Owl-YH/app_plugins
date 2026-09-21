part of '../spatial_confetti.dart';

/// 固定材质坐标的几何缓存；只在物理步结束更新，绘制细分不会改变曲面。
class _RibbonGeometry {
  _RibbonGeometry(this.points, this.widthAxes, this.width, this.twistAngles)
    : derivatives = List.filled(points.length, Vec3.zero),
      tangents = List.filled(points.length, Vec3.forward),
      references = List.filled(points.length, Vec3.right),
      angles = Float64List(points.length),
      angleDerivatives = Float64List(points.length) {
    update();
  }
  final List<Vec3> points, widthAxes, derivatives, tangents, references;
  final Float64List angles, angleDerivatives, twistAngles;
  final double width;
  int get count => points.length - 1;
  void update() {
    for (var i = 0; i <= count; i++) {
      final left = points[i] - points[math.max(0, i - 1)];
      final right = points[math.min(count, i + 1)] - points[i];
      final derivative = i == 0
          ? right
          : i == count
          ? left
          : (left + right) * .5;
      final limit = i == 0
          ? right.length
          : i == count
          ? left.length
          : math.min(left.length, right.length);
      derivatives[i] = derivative.limited(limit);
      tangents[i] = derivative.normalized(
        i == 0 ? Vec3.forward : tangents[i - 1],
      );
    }
    final firstT = (points[1] - points[0]).normalized(tangents[0]);
    references[0] = _transportWidth(widthAxes[0], firstT, tangents[0]);
    for (var i = 0; i <= count; i++) {
      if (i > 0)
        references[i] = _transportWidth(
          references[i - 1],
          tangents[i - 1],
          tangents[i],
        );
      final a = math.max(0, i - 1), b = math.min(count - 1, i);
      final ta = (points[a + 1] - points[a]).normalized(tangents[i]);
      final tb = (points[b + 1] - points[b]).normalized(tangents[i]);
      final wa = _transportWidth(widthAxes[a], ta, tangents[i]);
      final wb = _transportWidth(widthAxes[b], tb, tangents[i]);
      var jointAngle = _angle(wa, wb, tangents[i]);
      if (a != b)
        jointAngle +=
            ((twistAngles[a] - jointAngle) / (2 * math.pi)).round() *
            2 *
            math.pi;
      final axis = wa.rotated(tangents[i], jointAngle * .5);
      var angle = _angle(references[i], axis, tangents[i]);
      if (i > 0)
        angle +=
            ((angles[i - 1] +
                        (i > 1 ? twistAngles[i - 2] * .5 : 0) +
                        (i < count ? twistAngles[i - 1] * .5 : 0) -
                        angle) /
                    (2 * math.pi))
                .round() *
            2 *
            math.pi;
      angles[i] = angle;
    }
    for (var i = 0; i <= count; i++) {
      angleDerivatives[i] = i == 0
          ? angles[1] - angles[0]
          : i == count
          ? angles[count] - angles[count - 1]
          : (angles[i + 1] - angles[i - 1]) * .5;
    }
  }

  double _angle(Vec3 a, Vec3 b, Vec3 axis) =>
      math.atan2(axis.dot(a.cross(b)), _clamp(a.dot(b), -1, 1));
  (int, double) _interval(double u) {
    final s = _clamp(u, 0, 1) * count;
    final i = math.min(count - 1, s.floor());
    return (i, s - i);
  }

  Vec3 position(double u) {
    final (i, t) = _interval(u);
    final t2 = t * t, t3 = t2 * t;
    final a = 2 * t3 - 3 * t2 + 1,
        b = t3 - 2 * t2 + t,
        c = -2 * t3 + 3 * t2,
        d = t3 - t2;
    final p = points[i],
        q = points[i + 1],
        r = derivatives[i],
        s = derivatives[i + 1];
    return Vec3(
      p.x * a + r.x * b + q.x * c + s.x * d,
      p.y * a + r.y * b + q.y * c + s.y * d,
      p.z * a + r.z * b + q.z * c + s.z * d,
    );
  }

  Vec3 tangent(double u) {
    final (i, t) = _interval(u);
    final t2 = t * t,
        a = 6 * t2 - 6 * t,
        b = 3 * t2 - 4 * t + 1,
        c = -a,
        d = 3 * t2 - 2 * t;
    final p = points[i],
        q = points[i + 1],
        r = derivatives[i],
        s = derivatives[i + 1];
    final x = p.x * a + r.x * b + q.x * c + s.x * d,
        y = p.y * a + r.y * b + q.y * c + s.y * d,
        z = p.z * a + r.z * b + q.z * c + s.z * d;
    final n = math.sqrt(x * x + y * y + z * z);
    return n > 1e-12 ? Vec3(x / n, y / n, z / n) : tangents[i];
  }

  double materialAngle(double u) {
    final (i, t) = _interval(u);
    final t2 = t * t, t3 = t2 * t;
    return angles[i] * (2 * t3 - 3 * t2 + 1) +
        angleDerivatives[i] * (t3 - 2 * t2 + t) +
        angles[i + 1] * (-2 * t3 + 3 * t2) +
        angleDerivatives[i + 1] * (t3 - t2);
  }

  Vec3 director(double u) {
    final (i, _) = _interval(u);
    final axis = tangent(u), angle = materialAngle(u);
    return _transportWidth(
      references[i],
      tangents[i],
      axis,
    ).rotated(axis, angle);
  }

  Vec3 edge(double u, double side) =>
      position(u) + director(u) * (side * width * .5);
}

part of '../spatial_confetti.dart';

/// 单一长边弧形模态：z = q φ(x,y)，q 是长边中点相对端点弦线的弓高。
/// φ 去除面积平均和线性分量，避免弯曲重复驱动刚体平移、旋转。
/// 小弯曲近似保留一个自由度，不求解面内拉伸、短边弯曲或局部褶皱。
class _PaperBending {
  _PaperBending(this.body) : alongX = body.width > body.height {
    length = alongX ? body.width : body.height;
    mesh = alongX ? body.geometry.arcAlongX : body.geometry.arcAlongY;
    localMesh = [
      for (final p in mesh.vertices) Offset(p.dx * body.sx, p.dy * body.sy),
    ];
    var sum = 0.0, xSum = 0.0, ySum = 0.0;
    final data = body.sampleData;
    for (var i = 0; i < data.length; i += 3) {
      final x = data[i], y = data[i + 1], area = data[i + 2];
      final value = _raw(x, y);
      sum += value * area;
      xSum += x * value * area;
      ySum += y * value * area;
    }
    mean = sum / body.area;
    final xx = body.iyy / body.settings.massPerArea,
        yy = body.ixx / body.settings.massPerArea;
    final xy = -body.ixy / body.settings.massPerArea,
        determinant = xx * yy - xy * xy;
    fitX = (yy * xSum - xy * ySum) / determinant;
    fitY = (xx * ySum - xy * xSum) / determinant;
    shapes = Float64List(data.length ~/ 3);
    var squareIntegral = 0.0;
    for (var i = 0; i < shapes.length; i++) {
      final phi = shapeAt(Offset(data[i * 3], data[i * 3 + 1]));
      shapes[i] = phi;
      squareIntegral += phi * phi * data[i * 3 + 2];
    }
    modalMass = squareIntegral * body.settings.massPerArea;
    // 曲率为 -8q/L²，薄片弯曲能 D∫κ²dA/2 = stiffness*q²/2。
    stiffness =
        64 * body.settings.bendingStiffness * body.area / math.pow(length, 4);
  }
  final _PaperBody body;
  final bool alongX;
  late final double length, mean, fitX, fitY, modalMass, stiffness;
  late final _PaperArcMesh mesh;
  late final List<Offset> localMesh;
  late final Float64List shapes;
  double displacement = 0, speed = 0;
  final matrix = Float64List(49),
      rhs = Float64List(7),
      scales = Float64List(7),
      row = Float64List(7);

  double _raw(double x, double y) {
    final coordinate = alongX ? x : y;
    return -4 * coordinate * coordinate / (length * length);
  }

  double shapeAt(Offset p) =>
      _raw(p.dx, p.dy) - mean - fitX * p.dx - fitY * p.dy;
  double heightAt(Offset p) => displacement * shapeAt(p);
  double velocityAt(Offset p) => speed * shapeAt(p);
  Vec3 normalAt(Offset p) {
    final dx =
        displacement * (-(alongX ? 8 * p.dx / (length * length) : 0) - fitX);
    final dy =
        displacement * (-(alongX ? 0 : 8 * p.dy / (length * length)) - fitY);
    return Vec3(-dx, -dy, 1).normalized(Vec3.forward);
  }

  List<Vec3> get surfaceVertices => [
    for (final p in localMesh)
      body.position + body._world(Vec3(p.dx, p.dy, heightAt(p))),
  ];
  double get rotationInertia => modalMass * displacement * displacement;
  double get kineticEnergy => .5 * modalMass * speed * speed;
  double get elasticEnergy => .5 * stiffness * displacement * displacement;

  /// 六个刚体速度与一个弯曲速度共用隐式气动系统，局部载荷按虚功投影到弧形。
  void step(ConfettiSimulation simulation, double dt, double offset) {
    final hasAir =
        body.settings.dragCoefficient != 0 ||
        body.settings.surfaceFriction != 0;
    final centerAir = hasAir
        ? simulation._airAt(body.position, offset: offset)
        : Vec3.zero;
    if (hasAir) body._rotationalLift(centerAir, dt * .5);
    final velocity = body._local(body.speed),
        angular = body._local(body.angularVelocity);
    matrix.fillRange(0, 49, 0);
    matrix[0] = matrix[8] = matrix[16] = body.mass;
    matrix[24] = body.ixx + rotationInertia;
    matrix[32] = body.iyy + rotationInertia;
    matrix[40] = body.izz;
    matrix[31] = body.ixy;
    matrix[48] =
        modalMass * (1 + body.settings.damping * dt) + stiffness * dt * dt;
    rhs[0] = velocity.x * body.mass;
    rhs[1] = velocity.y * body.mass;
    rhs[2] = velocity.z * body.mass;
    final momentum = body._local(body.momentum);
    rhs[3] = momentum.x;
    rhs[4] = momentum.y;
    rhs[5] = momentum.z;
    // 弯曲使面内转动惯量增加；离心广义力对应同一个 q² 惯量项。
    rhs[6] =
        modalMass * speed -
        stiffness * displacement * dt +
        modalMass *
            displacement *
            (angular.x * angular.x + angular.y * angular.y) *
            dt;
    if (hasAir) {
      final pressure = body._pressureProfile(body._local(centerAir) - velocity);
      final data = body.sampleData;
      for (var i = 0; i < shapes.length; i++) {
        final p = Offset(data[i * 3], data[i * 3 + 1]), phi = shapes[i];
        final r = Vec3(p.dx, p.dy, displacement * phi), normal = normalAt(p);
        final air = body._local(
          simulation._airAt(body.position + body._world(r), offset: offset),
        );
        final relative =
            air - velocity - angular.cross(r) - Vec3(0, 0, speed * phi);
        final normalSpeed = relative.dot(normal),
            tangent = relative - normal * normalSpeed;
        // 小弯曲面积修正；质量仍按出生材料面积定义。
        final factor = .5 * 1.225 * data[i * 3 + 2] * dt / normal.z;
        final normalRate =
            factor *
            body.settings.dragCoefficient *
            pressure *
            body.pressureWeights[i] *
            relative.length;
        final tangentRate =
            factor * body.settings.surfaceFriction * tangent.length;
        _addRow(normal, r, phi, normalRate, air);
        if (tangentRate > 0) {
          final first =
              (alongX
                      ? Vec3(1, 0, -normal.x / normal.z)
                      : Vec3(0, 1, -normal.y / normal.z))
                  .normalized();
          _addRow(first, r, phi, tangentRate, air);
          _addRow(normal.cross(first), r, phi, tangentRate, air);
        }
      }
    }
    for (var i = 0; i < 7; i++)
      for (var j = 0; j < i; j++) matrix[j * 7 + i] = matrix[i * 7 + j];
    _solvePaperSystem(matrix, rhs, scales, 7);
    body.speed = body._world(Vec3(rhs[0], rhs[1], rhs[2]));
    body.momentum = body._world(body._inertia(Vec3(rhs[3], rhs[4], rhs[5])));
    speed = rhs[6];
    final limit = length * body.settings.maximumBendRatio;
    displacement += speed * dt;
    if (displacement.abs() >= limit) {
      displacement = _clamp(displacement, -limit, limit);
      if (displacement * speed >= 0) speed = 0;
    }
    if (hasAir) body._rotationalLift(centerAir, dt * .5);
  }

  void _addRow(Vec3 axis, Vec3 r, double phi, double rate, Vec3 air) {
    if (rate == 0) return;
    final torque = r.cross(axis);
    row[0] = axis.x;
    row[1] = axis.y;
    row[2] = axis.z;
    row[3] = torque.x;
    row[4] = torque.y;
    row[5] = torque.z;
    row[6] = phi * axis.z;
    final target = axis.dot(air);
    for (var i = 0; i < 7; i++) {
      final weight = rate * row[i];
      rhs[i] += weight * target;
      for (var j = 0; j <= i; j++) matrix[i * 7 + j] += weight * row[j];
    }
  }
}

/// 只用于显示的长边八等分网格；不新增物理自由度。
/// 在已校验的材料三角形内裁切，凹轮廓与空白区域保持不变。
class _PaperArcMesh {
  _PaperArcMesh(_PaperGeometry geometry, bool alongX) {
    vertices.addAll(geometry.vertices);
    final indices = <(int, int), int>{};
    (int, int) key(Offset p) => ((p.dx * 1e12).round(), (p.dy * 1e12).round());
    for (var i = 0; i < vertices.length; i++) indices[key(vertices[i])] = i;
    int index(Offset p) => indices.putIfAbsent(key(p), () {
      vertices.add(p);
      return vertices.length - 1;
    });
    double coordinate(Offset p) => alongX ? p.dx : p.dy;
    var low = double.infinity, high = double.negativeInfinity;
    for (final p in geometry.vertices) {
      low = math.min(low, coordinate(p));
      high = math.max(high, coordinate(p));
    }
    List<Offset> clip(List<Offset> polygon, double bound, bool greater) {
      if (polygon.isEmpty) return polygon;
      final result = <Offset>[];
      var previous = polygon.last;
      var wasInside = greater
          ? coordinate(previous) >= bound
          : coordinate(previous) <= bound;
      for (final current in polygon) {
        final inside = greater
            ? coordinate(current) >= bound
            : coordinate(current) <= bound;
        if (inside != wasInside) {
          final fraction =
              (bound - coordinate(previous)) /
              (coordinate(current) - coordinate(previous));
          final point = previous + (current - previous) * fraction;
          result.add(
            alongX ? Offset(bound, point.dy) : Offset(point.dx, bound),
          );
        }
        if (inside) result.add(current);
        previous = current;
        wasInside = inside;
      }
      return result;
    }

    // 凸轮廓可直接裁成条带，避免圆形的耳切对角线制造多余显示面。
    // 凹轮廓仍逐个有效材料三角形处理，不能跨缺口连接。
    final outline = geometry.vertices;
    final convex = List.generate(
      outline.length,
      (i) =>
          _PaperGeometry.turn(
            outline[i],
            outline[(i + 1) % outline.length],
            outline[(i + 2) % outline.length],
          ) >=
          0,
    ).every((v) => v);
    final polygons = convex
        ? [outline]
        : [
            for (var i = 0; i < geometry.triangles.length; i += 3)
              [
                for (var j = 0; j < 3; j++)
                  geometry.vertices[geometry.triangles[i + j]],
              ],
          ];
    for (final original in polygons) {
      for (var strip = 0; strip < 8; strip++) {
        var polygon = clip(original, low + (high - low) * strip / 8, true);
        polygon = clip(polygon, low + (high - low) * (strip + 1) / 8, false);
        for (var j = 1; j + 1 < polygon.length; j++) {
          if (_PaperGeometry.turn(polygon[0], polygon[j], polygon[j + 1]) <=
              1e-16)
            continue;
          triangles.addAll([
            index(polygon[0]),
            index(polygon[j]),
            index(polygon[j + 1]),
          ]);
        }
      }
    }
  }
  final vertices = <Offset>[];
  final triangles = <int>[];
}

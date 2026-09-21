part of '../spatial_confetti.dart';

/// 与绘制细分无关的规范纸片几何，原点为均匀面密度质心，最长边为 1。
class _PaperGeometry {
  _PaperGeometry(
    this.vertices,
    this.triangles,
    this.width,
    this.height,
    this.area,
    this.xx,
    this.yy,
    this.xy,
    this.anchor,
    this.samples,
  );
  final List<Offset> vertices;
  final List<int> triangles;
  final double width, height, area, xx, yy, xy;
  final Offset anchor;
  final List<(Offset, double)> samples;
  int get triangleCount => triangles.length ~/ 3;
  late final _PaperArcMesh arcAlongX = _PaperArcMesh(this, true);
  late final _PaperArcMesh arcAlongY = _PaperArcMesh(this, false);

  /// 非等比出生尺寸下重新求最近材料点；质心在材料内时无需重新搜索。
  Offset scaledAnchor(List<Offset> points) {
    if (anchor == Offset.zero) return Offset.zero;
    var nearest = points.first;
    for (var i = 0; i < points.length; i++) {
      final a = points[i], edge = points[(i + 1) % points.length] - a;
      final fraction = _clamp(
        -(a.dx * edge.dx + a.dy * edge.dy) / edge.distanceSquared,
        0,
        1,
      );
      final point = a + edge * fraction;
      if (point.distanceSquared < nearest.distanceSquared) nearest = point;
    }
    return nearest;
  }

  static const maximumVertices = 128;
  static const epsilon = 1e-10;
  static double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static double turn(Offset a, Offset b, Offset c) => cross(b - a, c - a);

  static _PaperGeometry prepare(List<Offset> input) {
    if (input.length < 3 || input.length > maximumVertices + 1) {
      throw ArgumentError('A paper outline needs 3 through 128 vertices');
    }
    var left = double.infinity, top = double.infinity;
    var right = double.negativeInfinity, bottom = double.negativeInfinity;
    for (final point in input) {
      if (!point.dx.isFinite ||
          !point.dy.isFinite ||
          point.dx.abs() > 1e6 ||
          point.dy.abs() > 1e6) {
        throw ArgumentError(
          'Paper vertices must be finite and within ±1000000',
        );
      }
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }
    final scale = math.max(right - left, bottom - top);
    if (scale <= 1e-12) throw ArgumentError('Paper outline has zero extent');
    var points = <Offset>[];
    for (final point in input) {
      final normalized = (point - Offset(left, top)) / scale;
      if (points.isEmpty || (normalized - points.last).distance > epsilon)
        points.add(normalized);
    }
    if (points.length > 1 && (points.last - points.first).distance <= epsilon)
      points.removeLast();
    if (points.length > maximumVertices)
      throw ArgumentError('Paper outline exceeds 128 vertices');
    // 仅删除同向共线中间点，不将回折、接触或自交形状悄悄修成有效轮廓。
    var changed = true;
    while (changed && points.length > 3) {
      changed = false;
      for (var i = 0; i < points.length; i++) {
        final a = points[(i + points.length - 1) % points.length],
            b = points[i],
            c = points[(i + 1) % points.length];
        if (turn(a, b, c).abs() <= epsilon &&
            (b - a).dx * (c - b).dx + (b - a).dy * (c - b).dy >= 0) {
          points.removeAt(i);
          changed = true;
          break;
        }
      }
    }
    if (points.length < 3) throw ArgumentError('Paper outline is degenerate');
    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length];
      final c = points[(i + 2) % points.length];
      if (turn(a, b, c).abs() <= epsilon)
        throw ArgumentError('Paper outline contains a folded edge');
      for (var j = i + 1; j < points.length; j++) {
        if (j == i + 1 || (i == 0 && j == points.length - 1)) continue;
        if (_intersects(a, b, points[j], points[(j + 1) % points.length])) {
          throw ArgumentError(
            'Paper outline must not intersect or touch itself',
          );
        }
      }
    }
    var twiceArea = 0.0, cx = 0.0, cy = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length], k = cross(a, b);
      twiceArea += k;
      cx += (a.dx + b.dx) * k;
      cy += (a.dy + b.dy) * k;
    }
    if (twiceArea.abs() < 2e-5)
      throw ArgumentError('Paper outline has insufficient area');
    final centroid = Offset(cx, cy) / (3 * twiceArea);
    points = [for (final point in points) point - centroid];
    if (twiceArea < 0) points = points.reversed.toList();
    final area = twiceArea.abs() * .5;
    var xx = 0.0, yy = 0.0, xy = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length], k = cross(a, b);
      xx += (a.dx * a.dx + a.dx * b.dx + b.dx * b.dx) * k / 12;
      yy += (a.dy * a.dy + a.dy * b.dy + b.dy * b.dy) * k / 12;
      xy +=
          (2 * a.dx * a.dy + a.dx * b.dy + b.dx * a.dy + 2 * b.dx * b.dy) *
          k /
          24;
    }
    if (xx <= 0 || yy <= 0 || xx * yy - xy * xy <= 1e-16 * area * area) {
      throw ArgumentError('Paper outline has degenerate area moments');
    }
    final triangles = _triangulate(points);
    var triangleArea = 0.0;
    var anchor = points.first;
    final samples = <(Offset, double)>[];
    for (var i = 0; i < triangles.length; i += 3) {
      final a = points[triangles[i]],
          b = points[triangles[i + 1]],
          c = points[triangles[i + 2]];
      final weight = turn(a, b, c) * .5;
      triangleArea += weight;
      if (_inside(Offset.zero, a, b, c)) {
        anchor = Offset.zero;
      } else if (anchor != Offset.zero) {
        for (final edge in [(a, b), (b, c), (c, a)]) {
          final delta = edge.$2 - edge.$1;
          final t = _clamp(
            -(edge.$1.dx * delta.dx + edge.$1.dy * delta.dy) /
                delta.distanceSquared,
            0,
            1,
          );
          final candidate = edge.$1 + delta * t;
          if (candidate.distanceSquared < anchor.distanceSquared)
            anchor = candidate;
        }
      }
    }
    if ((triangleArea - area).abs() > area * 1e-8)
      throw ArgumentError('Paper triangulation area mismatch');
    void sampleTriangle(Offset a, Offset b, Offset c) {
      final weight = turn(a, b, c) / 6;
      samples.add((a * (2 / 3) + (b + c) / 6, weight));
      samples.add((b * (2 / 3) + (a + c) / 6, weight));
      samples.add((c * (2 / 3) + (a + b) / 6, weight));
    }

    // 质心位于可见核时，受力积分使用中心扇形，保留轮廓的镜像对称性。
    // 避免绘制耳切的对角线在非均匀压力中引入偏向；仍是三点二次精确积分。
    // U 形等不满足条件的轮廓使用已经校验的耳切，绝不跨凹处填充材料。
    final centerFan = List.generate(
      points.length,
      (i) =>
          turn(Offset.zero, points[i], points[(i + 1) % points.length]) >
          epsilon,
    ).every((inside) => inside);
    if (centerFan) {
      for (var i = 0; i < points.length; i++)
        sampleTriangle(Offset.zero, points[i], points[(i + 1) % points.length]);
    } else {
      for (var i = 0; i < triangles.length; i += 3)
        sampleTriangle(
          points[triangles[i]],
          points[triangles[i + 1]],
          points[triangles[i + 2]],
        );
    }
    return _PaperGeometry(
      List.unmodifiable(points),
      List.unmodifiable(triangles),
      (right - left) / scale,
      (bottom - top) / scale,
      area,
      xx,
      yy,
      xy,
      anchor,
      List.unmodifiable(samples),
    );
  }

  static bool _inside(Offset p, Offset a, Offset b, Offset c) =>
      turn(a, b, p) >= -epsilon &&
      turn(b, c, p) >= -epsilon &&
      turn(c, a, p) >= -epsilon;

  static bool _intersects(Offset a, Offset b, Offset c, Offset d) {
    bool on(Offset p, Offset q, Offset r) =>
        turn(p, q, r).abs() <= epsilon &&
        r.dx >= math.min(p.dx, q.dx) - epsilon &&
        r.dx <= math.max(p.dx, q.dx) + epsilon &&
        r.dy >= math.min(p.dy, q.dy) - epsilon &&
        r.dy <= math.max(p.dy, q.dy) + epsilon;
    final abC = turn(a, b, c),
        abD = turn(a, b, d),
        cdA = turn(c, d, a),
        cdB = turn(c, d, b);
    return (abC * abD < 0 && cdA * cdB < 0) ||
        on(a, b, c) ||
        on(a, b, d) ||
        on(c, d, a) ||
        on(c, d, b);
  }

  static List<int> _triangulate(List<Offset> points) {
    final remaining = List.generate(points.length, (i) => i),
        triangles = <int>[];
    while (remaining.length > 3) {
      var found = false;
      for (var i = 0; i < remaining.length; i++) {
        final a = remaining[(i + remaining.length - 1) % remaining.length],
            b = remaining[i],
            c = remaining[(i + 1) % remaining.length];
        if (turn(points[a], points[b], points[c]) <= epsilon) continue;
        if (remaining.any(
          (p) =>
              p != a &&
              p != b &&
              p != c &&
              _inside(points[p], points[a], points[b], points[c]),
        ))
          continue;
        triangles.addAll([a, b, c]);
        remaining.removeAt(i);
        found = true;
        break;
      }
      if (!found)
        throw ArgumentError(
          'Paper outline cannot be triangulated within tolerance',
        );
    }
    triangles.addAll(remaining);
    return triangles;
  }

  static _PaperGeometry fromPath(ui.Path path, double tolerance) {
    _number('shape.tolerance', tolerance, .0001, .01);
    final bounds = path.getBounds(),
        metrics = path.computeMetrics().take(2).toList();
    final scale = math.max(bounds.width, bounds.height);
    if (!scale.isFinite ||
        scale <= 1e-12 ||
        metrics.length != 1 ||
        !metrics.single.isClosed) {
      throw ArgumentError(
        'Paper Path needs one explicitly closed, nonempty contour',
      );
    }
    final metric = metrics.single;
    if (!metric.length.isFinite || metric.length / scale > 64)
      throw ArgumentError('Paper Path is too complex');
    Offset point(double distance) {
      final tangent = metric.getTangentForOffset(distance);
      if (tangent == null)
        throw ArgumentError('Paper Path has an invalid segment');
      return tangent.position;
    }

    final vertices = <Offset>[point(0)];
    void segment(double start, double end, Offset a, Offset b, int depth) {
      final chord = b - a;
      double deviation(Offset p) {
        if (chord.distanceSquared < 1e-24) return (p - a).distance;
        final t = _clamp(
          ((p - a).dx * chord.dx + (p - a).dy * chord.dy) /
              chord.distanceSquared,
          0,
          1,
        );
        return (p - a - chord * t).distance;
      }

      final middle = (start + end) * .5, p = point(middle);
      final error = math.max(
        deviation(p),
        math.max(
          deviation(point((start * 3 + end) / 4)),
          deviation(point((start + end * 3) / 4)),
        ),
      );
      if (error > scale * tolerance || end - start > scale * .1) {
        if (depth >= 16)
          throw ArgumentError('Paper Path exceeds subdivision depth');
        segment(start, middle, a, p, depth + 1);
        segment(middle, end, p, b, depth + 1);
      } else {
        vertices.add(b);
        if (vertices.length > maximumVertices + 1)
          throw ArgumentError('Paper Path requires more than 128 vertices');
      }
    }

    segment(0, metric.length, vertices.first, point(metric.length), 0);
    return prepare(vertices);
  }
}

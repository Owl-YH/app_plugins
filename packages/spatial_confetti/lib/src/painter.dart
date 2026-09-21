part of '../spatial_confetti.dart';

class _Vertex {
  const _Vertex(this.position, this.color);
  final Vec3 position;
  final Color color;
  _Vertex lerp(_Vertex other, double amount) => _Vertex(
    position.lerp(other.position, amount),
    Color.lerp(color, other.color, amount)!,
  );
}

class _Surface {
  _Surface(this.vertices);
  final List<_Vertex> vertices;
  double get depth =>
      vertices.fold(0.0, (sum, vertex) => sum + vertex.position.z) /
      vertices.length;
}

/// 最近一次绘制的几何与提交统计；读取时不复制世界状态。
/// 不包含物理节点标记，也不等同于底层 GPU 指令数量。
@immutable
class ConfettiRenderStats {
  /// 创建一次绘制的统计值，各字段均为数量而非时间或显存大小。
  const ConfettiRenderStats({
    required this.drawCalls,
    required this.vertices,
    required this.triangles,
    required this.visibleParticles,
    required this.streaks,
    this.ribbonSegments = 0,
    this.refinementLimited = 0,
  });

  /// 材料与光迹合计调用 Canvas.drawVertices 的次数。
  final int drawCalls;

  /// 向 Canvas 提交的顶点总数，跨批次重复提交的顶点会重复计数。
  final int vertices;

  /// 本次网格包含的三角形数量。
  final int triangles;

  /// 材料或光迹贡献了可提交三角形的粒子数，不判断是否被其他粒子遮挡。
  final int visibleParticles;

  /// 本帧生成几何的光迹数，最终像素仍可能被视口裁剪。
  final int streaks;

  /// 本次生成的彩带绘制小段数，不改变物理节点数。
  final int ribbonSegments;

  /// 达到四等分上限后仍超出边缘/截面误差或跨裁剪面的段数。
  final int refinementLimited;
}

/// 只读取模拟状态的绘制器，不推进时间，可配合调用方拥有的时钟使用。
/// 材料与光迹共用按深度排序的网格，以近似三维透明遮挡。
/// 所有粒子正反面使用配置原色，不因朝向或光照改变 RGB。
class ConfettiPainter extends CustomPainter {
  /// 绑定 [simulation] 并校验 [camera]。
  /// [repaint] 可接收控制器等 Listenable，通知变化时请求重绘而不重建组件。
  ConfettiPainter({
    required this.simulation,
    this.camera = const ConfettiCamera(),
    this.showNodes = false,
    super.repaint,
  }) {
    camera._validate();
  }

  /// 提供粒子状态的模拟器；其时钟与生命周期由外部管理。
  final ConfettiSimulation simulation;

  /// 将米制世界投影到逻辑像素画布的相机。
  final ConfettiCamera camera;

  /// 是否绘制真实物理节点的调试标记。
  final bool showNodes;

  final _mesh = _FrameMesh();
  final _surfaces = <_Surface>[];
  int _visibleParticles = 0;
  int _streaks = 0;
  int _ribbonSegments = 0, _refinementLimited = 0;

  /// 最近一次 paint 的统计值，绘制前各计数为 0。
  ConfettiRenderStats get stats => ConfettiRenderStats(
    drawCalls: _mesh.drawCalls,
    vertices: _mesh.submittedVertices,
    triangles: _mesh.indexCount ~/ 3,
    visibleParticles: _visibleParticles,
    streaks: _streaks,
    ribbonSegments: _ribbonSegments,
    refinementLimited: _refinementLimited,
  );

  /// 按当前模拟状态绘制到 [canvas]，裁剪在 [size] 指定的逻辑像素范围内。
  /// 空尺寸时只清空本次统计，不生成几何；本方法不会推进物理模拟。
  @override
  void paint(Canvas canvas, Size size) {
    _mesh.reset();
    _surfaces.clear();
    _visibleParticles = 0;
    _streaks = 0;
    _ribbonSegments = 0;
    _refinementLimited = 0;
    if (size.isEmpty) return;
    for (final body in simulation._bodies) {
      final before = _mesh.indexCount;
      if (body.alive) {
        _surfaces.clear();
        _body(_surfaces, body, size);
        for (final surface in _surfaces) {
          _draw(size, surface);
        }
      }
      if (_mesh.indexCount != before) _visibleParticles++;
    }
    canvas.save();
    try {
      canvas.clipRect(Offset.zero & size);
      _mesh.draw(canvas);
      if (showNodes) _nodes(canvas, size);
    } finally {
      canvas.restore();
    }
  }

  /// 生成纸片三角网格或彩带各段表面；彩带内部节点混合相邻宽度轴保持连接。
  void _body(List<_Surface> surfaces, _Body body, Size size) {
    final opacity = body.opacity(simulation._timeSeconds);
    if (opacity <= 0) return;
    if (body is _PaperBody) {
      final points = body.surfaceVertices;
      final color = body.color.withValues(alpha: body.color.a * opacity);
      final indices = body.surfaceTriangles;
      for (var i = 0; i < indices.length; i += 3) {
        surfaces.add(
          _Surface([
            _Vertex(points[indices[i]], color),
            _Vertex(points[indices[i + 1]], color),
            _Vertex(points[indices[i + 2]], color),
          ]),
        );
      }
    } else if (body is _StreakBody) {
      if (_StreakGeometry.append(
        surfaces,
        body,
        simulation._timeSeconds,
        camera,
        size,
      ))
        _streaks++;
    } else if (body is _RibbonBody) {
      _ribbon(surfaces, body, size, opacity);
    }
  }

  /// 左右边缘按固定四等分采样检查屏幕误差，不依赖帧历史或实时性能。
  void _ribbon(
    List<_Surface> surfaces,
    _RibbonBody body,
    Size size,
    double opacity,
  ) {
    final geometry = body.geometry;
    final color = body.color.withValues(alpha: body.color.a * opacity);
    for (var segment = 0; segment < body.settings.segments; segment++) {
      final left = <Vec3>[], right = <Vec3>[];
      final directors = <Vec3>[];
      for (var j = 0; j <= 4; j++) {
        final u = (segment + j / 4) / body.settings.segments;
        final center = geometry.position(u), director = geometry.director(u);
        left.add(center - director * (body.width * .5));
        right.add(center + director * (body.width * .5));
        directors.add(director);
      }
      bool acceptable(int start, int end) {
        if ((geometry.materialAngle((segment + end / 4) / body.segmentCost) -
                    geometry.materialAngle(
                      (segment + start / 4) / body.segmentCost,
                    ))
                .abs() >
            math.pi / 15)
          return false;
        for (var j = start; j <= end; j++) {
          for (final edge in [left, right]) {
            final p = camera.project(edge[j], size),
                a = camera.project(edge[start], size),
                b = camera.project(edge[end], size);
            if (p == null || a == null || b == null) return false;
            if ((p - Offset.lerp(a, b, (j - start) / (end - start))!).distance >
                .75)
              return false;
          }
          if (directors[start].dot(directors[j]) < .9781476007338057)
            return false;
        }
        return true;
      }

      final divisions = acceptable(0, 4)
          ? 1
          : acceptable(0, 2) && acceptable(2, 4)
          ? 2
          : 4;
      _ribbonSegments += divisions;
      if (divisions == 4) {
        for (var j = 0; j < 4; j++) {
          final u = (segment + (j + .5) / 4) / body.segmentCost;
          final center = geometry.position(u), axis = geometry.director(u);
          var limited = !acceptable(j, j + 1);
          for (final side in [-1.0, 1.0]) {
            final edge = side < 0 ? left : right;
            final a = camera.project(edge[j], size),
                b = camera.project(edge[j + 1], size);
            final mid = camera.project(
              center + axis * (side * body.width * .5),
              size,
            );
            if (a == null ||
                b == null ||
                mid == null ||
                (mid - (a + b) * .5).distance > .75)
              limited = true;
          }
          if (limited) _refinementLimited++;
        }
      }
      (_Vertex, _Vertex) vertices(int j) =>
          (_Vertex(left[j], color), _Vertex(right[j], color));

      var (l, r) = vertices(0);
      for (var j = 4 ~/ divisions; j <= 4; j += 4 ~/ divisions) {
        final (nextL, nextR) = vertices(j);
        surfaces.add(_Surface([l, r, nextR]));
        surfaces.add(_Surface([l, nextR, nextL]));
        l = nextL;
        r = nextR;
      }
    }
  }

  double _scale(Vec3 position, Size size) =>
      size.height /
      camera.viewHeight *
      camera.distance /
      _clamp(camera.distance - position.z, camera.near, camera.far);

  Offset _project(Vec3 position, Size size) {
    final scale = _scale(position, size);
    return Offset(
      size.width * .5 + position.x * scale,
      size.height * .5 + position.y * scale,
    );
  }

  /// 在世界 Z 平面裁剪多边形，并在交点插值颜色，避免近相机处投影发散。
  List<_Vertex> _clip(List<_Vertex> input, double plane, bool keepBelow) {
    if (input.isEmpty) return input;
    final result = <_Vertex>[];
    var previous = input.last;
    var previousInside = keepBelow
        ? previous.position.z <= plane
        : previous.position.z >= plane;
    for (final current in input) {
      final inside = keepBelow
          ? current.position.z <= plane
          : current.position.z >= plane;
      if (inside != previousInside) {
        final fraction =
            (plane - previous.position.z) /
            (current.position.z - previous.position.z);
        result.add(previous.lerp(current, fraction));
      }
      if (inside) result.add(current);
      previous = current;
      previousInside = inside;
    }
    return result;
  }

  /// 裁剪近远平面、投影并剔除画布外表面，将剩余多边形写入共享网格。
  void _draw(Size size, _Surface surface) {
    var vertices = surface.vertices;
    final near = camera.distance - camera.near,
        far = camera.distance - camera.far;
    if (vertices.any((v) => v.position.z > near))
      vertices = _clip(vertices, near, true);
    if (vertices.any((v) => v.position.z < far))
      vertices = _clip(vertices, far, false);
    if (vertices.length < 3) return;
    final positions = vertices
        .map((v) => _project(v.position, size))
        .toList(growable: false);
    var left = double.infinity, top = double.infinity;
    var right = double.negativeInfinity, bottom = double.negativeInfinity;
    for (final position in positions) {
      left = math.min(left, position.dx);
      right = math.max(right, position.dx);
      top = math.min(top, position.dy);
      bottom = math.max(bottom, position.dy);
    }
    if (right < 0 || bottom < 0 || left > size.width || top > size.height)
      return;
    final first = _mesh.vertexCount;
    var depth = 0.0;
    for (var i = 0; i < vertices.length; i++) {
      _mesh.vertex(positions[i].dx, positions[i].dy, vertices[i].color);
      depth += vertices[i].position.z;
    }
    _mesh.polygon(first, vertices.length, depth / vertices.length);
  }

  /// 标记真实节点，帮助区分物理分辨率与绘制细分。
  void _nodes(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xffffe7a4);
    for (final body in simulation._bodies.whereType<_RibbonBody>()) {
      if (!body.alive) continue;
      for (final point in body.points) {
        final screen = camera.project(point, size);
        if (screen != null) canvas.drawCircle(screen, 2, paint);
      }
    }
  }

  /// 模拟器实例、相机或调试标记开关变化时要求重新绘制。
  /// 同一模拟器的逐帧变化由构造时的 repaint 通知驱动。
  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) =>
      !identical(simulation, oldDelegate.simulation) ||
      camera != oldDelegate.camera ||
      showNodes != oldDelegate.showNodes;

  /// 绘制层不参与命中测试，允许指针交互落到其他组件。
  @override
  bool? hitTest(Offset position) => false;
}

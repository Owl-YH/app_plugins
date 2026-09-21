part of '../spatial_confetti.dart';

/// 一个可独立排序的网格片段，记录索引范围、平均世界深度和原始提交顺序。
class _MeshSection {
  _MeshSection(this.start, this.count, this.depth, this.order);
  final int start;
  final int count;
  final double depth;
  final int order;
}

/// 绘制器拥有并复用的帧几何缓冲，将排序后的网格按原生索引容量分批提交。
class _FrameMesh {
  Float32List _positions = Float32List(2048);
  Int32List _colors = Int32List(1024);
  Int32List _indices = Int32List(4096);
  Int32List _mapped = Int32List(1024);
  Int32List _stamps = Int32List(1024);
  final _sections = <_MeshSection>[];
  final _paint = Paint();
  // 即使用户配置大量粒子，也保证每次原生提交的索引不超出 Uint16 范围。
  static const _batchVertices = 65520;
  static const _batchIndices = 196560;
  Float32List? _batchPositions;
  Int32List? _batchColors;
  Uint16List? _batchTriangles;
  int vertexCount = 0;
  int indexCount = 0;
  int drawCalls = 0;
  int submittedVertices = 0;
  int _generation = 0;

  /// 重置本帧计数与排序片段，保留已分配的数组供后续帧复用。
  void reset() {
    vertexCount = 0;
    indexCount = 0;
    drawCalls = 0;
    submittedVertices = 0;
    _sections.clear();
  }

  /// 写入逻辑像素位置与颜色并返回顶点索引，缓冲不足时按倍数扩容。
  int vertex(double x, double y, Color color) {
    if (vertexCount == _colors.length) {
      final capacity = _colors.length * 2;
      _positions = Float32List(capacity * 2)..setAll(0, _positions);
      _colors = Int32List(capacity)..setAll(0, _colors);
      _mapped = Int32List(capacity)..setAll(0, _mapped);
      _stamps = Int32List(capacity)..setAll(0, _stamps);
    }
    final index = vertexCount++;
    _positions[index * 2] = x;
    _positions[index * 2 + 1] = y;
    _colors[index] = color.toARGB32();
    return index;
  }

  void _triangle(int a, int b, int c) {
    if (indexCount + 3 > _indices.length) {
      _indices = Int32List(_indices.length * 2)..setAll(0, _indices);
    }
    _indices[indexCount++] = a;
    _indices[indexCount++] = b;
    _indices[indexCount++] = c;
  }

  /// 将凸多边形三角化并记录平均世界 Z 深度，供材料与光迹统一排序。
  void polygon(int first, int count, double depth) {
    final start = indexCount;
    for (var i = 1; i < count - 1; i++) {
      _triangle(first, first + i, first + i + 1);
    }
    _sections.add(
      _MeshSection(start, indexCount - start, depth, _sections.length),
    );
  }

  /// 按世界 Z 从远到近稳定排序后分批绘制；同深度保持原提交顺序。
  /// 各批次重映射共享顶点索引，提交结束立即释放临时原生 Vertices。
  void draw(Canvas canvas) {
    if (indexCount == 0) return;
    _sections.sort((a, b) {
      final depth = a.depth.compareTo(b.depth);
      return depth == 0 ? a.order.compareTo(b.order) : depth;
    });
    // 原生提交数组最多增长到单批容量，并跨帧复用。
    final requiredVertices = math.min(_batchVertices, vertexCount);
    final requiredIndices = math.min(_batchIndices, indexCount);
    if ((_batchColors?.length ?? 0) < requiredVertices) {
      final capacity = math.min(
        _batchVertices,
        math.max(1024, requiredVertices * 2),
      );
      _batchPositions = Float32List(capacity * 2);
      _batchColors = Int32List(capacity);
    }
    if ((_batchTriangles?.length ?? 0) < requiredIndices) {
      _batchTriangles = Uint16List(
        math.min(_batchIndices, math.max(4096, requiredIndices * 2)),
      );
    }
    var count = 0;
    var triangles = 0;
    void nextGeneration() {
      // 各 Dart 平台上的标记均为有符号 32 位整数，到边界时统一重置。
      if (_generation == 0x7fffffff) {
        _stamps.fillRange(0, _stamps.length, 0);
        _generation = 0;
      }
      _generation++;
    }

    void flush() {
      if (triangles == 0) return;
      final vertices = ui.Vertices.raw(
        VertexMode.triangles,
        Float32List.sublistView(_batchPositions!, 0, count * 2),
        colors: Int32List.sublistView(_batchColors!, 0, count),
        indices: Uint16List.sublistView(_batchTriangles!, 0, triangles),
      );
      try {
        canvas.drawVertices(vertices, BlendMode.dst, _paint);
      } finally {
        vertices.dispose();
      }
      drawCalls++;
      submittedVertices += count;
      count = 0;
      triangles = 0;
      nextGeneration();
    }

    nextGeneration();
    for (final section in _sections) {
      for (var i = section.start; i < section.start + section.count; i += 3) {
        if (count + 3 > _batchColors!.length ||
            triangles + 3 > _batchTriangles!.length) {
          flush();
        }
        for (var corner = 0; corner < 3; corner++) {
          final source = _indices[i + corner];
          if (_stamps[source] != _generation) {
            _mapped[source] = count;
            _stamps[source] = _generation;
            _batchPositions![count * 2] = _positions[source * 2];
            _batchPositions![count * 2 + 1] = _positions[source * 2 + 1];
            _batchColors![count] = _colors[source];
            count++;
          }
          _batchTriangles![triangles++] = _mapped[source];
        }
      }
    }
    flush();
  }
}

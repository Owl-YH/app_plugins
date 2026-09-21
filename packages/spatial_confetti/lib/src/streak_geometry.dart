part of '../spatial_confetti.dart';

/// 固定规模的速度色带网格；输出世界表面，统一交给 Painter 裁剪、投影和排序。
abstract final class _StreakGeometry {
  static const _stations = [0.0, .12, .4, .65, .78, .88, .95, 1.0];
  static const _coverage = [0.0, .45, 1.0, 1.0, .45, 0.0];

  /// 投影只决定可见强度与像素柔边；物理状态和长度包络与相机无关。
  static bool append(
    List<_Surface> surfaces,
    _StreakBody body,
    double time,
    ConfettiCamera camera,
    Size size,
  ) {
    final length = body.lengthAt(time),
        opacity = body.opacity(time) * body.color.a;
    if (length <= 1e-9 || opacity <= 0 || body.speed.lengthSquared <= 1e-18)
      return false;
    final head = body.position,
        axis = body.speed.normalized(),
        tail = head - axis * length;
    final near = camera.distance - camera.near,
        far = camera.distance - camera.far;
    var enter = 0.0, leave = 1.0;
    final dz = tail.z - head.z;
    if (dz.abs() < 1e-12) {
      if (head.z < far || head.z > near) return false;
    } else {
      final a = (far - head.z) / dz, b = (near - head.z) / dz;
      enter = math.max(enter, math.min(a, b));
      leave = math.min(leave, math.max(a, b));
      if (leave <= enter) return false;
    }
    // 头部已越过裁剪面时，在可见区间求速度，不把不可见位置投影到近面。
    final point = head.lerp(tail, (enter + leave) * .5);
    final depth = camera.distance - point.z;
    final projection = size.height / camera.viewHeight * camera.distance;
    final v = body.speed;
    final screenVelocity = Offset(
      projection * (v.x * depth + point.x * v.z) / (depth * depth),
      projection * (v.y * depth + point.y * v.z) / (depth * depth),
    );
    // 每秒跨越的画布高度，消除画布像素尺寸对速度门限的影响；不使用帧间位移。
    final viewportSpeed = screenVelocity.distance / size.height;
    final factor = _smooth((viewportSpeed - .625) / .625);
    if (factor == 0) return false;
    final side = axis
        .cross((Vec3(0, 0, camera.distance) - point).normalized())
        .normalized(_perpendicular(axis));
    List<_Vertex>? previous;
    for (final u in _stations) {
      final center = head - axis * (length * u);
      final taper = u <= .65
          ? 1 - .12 * u
          : .922 * (1 - _smooth((u - .65) / .35));
      final fade = u <= .6 ? 1.0 : 1 - _smooth((u - .6) / .4);
      final halfWidth = body.width * .5 * taper;
      final scale =
          projection /
          _clamp(camera.distance - center.z, camera.near, camera.far);
      // 柔边随速度与投影宽度增加；保留实色主干，并将边缘限制在 0.25～4 逻辑像素。
      final blur = _clamp(
        body.width * scale * .35 * viewportSpeed / 1.25,
        .25,
        4,
      );
      final feather = blur / scale * taper;
      final offsets = [
        -halfWidth - feather,
        -halfWidth - feather * .35,
        -halfWidth,
        halfWidth,
        halfWidth + feather * .35,
        halfWidth + feather,
      ];
      final ring = [
        for (var j = 0; j < offsets.length; j++)
          _Vertex(
            center + side * offsets[j],
            body.color.withValues(
              alpha: opacity * factor * fade * _coverage[j],
            ),
          ),
      ];
      if (previous != null) {
        for (var j = 0; j < ring.length - 1; j++) {
          surfaces.add(
            _Surface([previous[j], previous[j + 1], ring[j + 1], ring[j]]),
          );
        }
      }
      previous = ring;
    }
    return true;
  }
}

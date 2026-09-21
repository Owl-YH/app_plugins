part of '../spatial_confetti.dart';

/// 全局或球形衰减的局部空气速度源，支持任意 XYZ 方向。
@immutable
final class WindSource {
  /// 创建全局风；不随位置衰减，速度、波动和相位的含义见同名属性。
  /// 非法向量或数值抛出 [ArgumentError]。
  WindSource.global({
    required Vec3 velocity,
    double variation = .15,
    double phase = 0,
  }) : this._(velocity, null, 2, variation, phase);

  /// 创建以 [center] 为中心的局部风；[radius] 是指数衰减尺度，单位米。
  /// 半径外仍有风；非法中心、半径或其他数值抛出 [ArgumentError]。
  WindSource.local({
    required Vec3 velocity,
    required Vec3 center,
    double radius = 2,
    double variation = .15,
    double phase = 0,
  }) : this._(velocity, center, radius, variation, phase);

  WindSource._(
    this.velocity,
    this.center,
    this.radius,
    this.variation,
    this.phase,
  ) {
    _vector('wind.velocity', velocity);
    if (center != null) {
      _vector('wind.center', center!);
      _number('wind.radius', radius, .01, 1000);
    }
    _number('wind.variation', variation, 0, .5);
    _number('wind.phase', phase, -10000, 10000);
  }

  /// 基础空气速度，单位米/秒；不是直接施加到粒子的力或加速度。
  final Vec3 velocity;

  /// 局部风的世界中心，单位米；null 表示不随位置衰减的全局风。
  final Vec3? center;

  /// 局部风的衰减尺度，单位米，范围 [0.01, 1000]。
  /// 距中心 r 处乘以 exp(-r²/radius²)，半径外仍有风。
  /// 全局风不使用此值，规范为 2，且不开放构造入参。
  final double radius;

  /// 两个连续正弦分量的相对风速波动幅度，范围 [0, 0.5]；0 为恒定强度。
  final double variation;

  /// 时间波动的相位偏移，单位弧度，范围 [-10000, 10000]。
  final double phase;

  /// 将球形空间衰减与平滑时间波动相乘，得到当地空气速度。
  Vec3 _sample(Vec3 position, double time) {
    final envelope = center == null
        ? 1.0
        : math.exp(-(position - center!).lengthSquared / (radius * radius));
    final variationScale =
        1 +
        variation *
            (.65 * math.sin(time * .43 + phase) +
                .35 * math.sin(time * 1.17 + phase + 2.1));
    return velocity * (envelope * variationScale);
  }
}

/// 叠加多个独立风源和连续 XYZ 涡流的不可变风场。
/// 所有分量先合成当地空气速度，再由粒子按相对气流计算阻力。
@immutable
class WindField {
  /// 保存不可修改的风源列表；默认没有风源且涡流强度为 0，即静止空气。
  WindField({
    List<WindSource> sources = const [],
    this.turbulence = 0,
    this.spatialScale = .8,
    this.seed = 1,
  }) : sources = List.unmodifiable(sources) {
    if (sources.length > 16) throw ArgumentError('At most 16 wind sources');
    _number('turbulence', turbulence, 0, 10);
    _number('spatialScale', spatialScale, .01, 10);
  }

  /// 最多 16 个可同时来自不同方向的风源，速度逐项相加。
  final List<WindSource> sources;

  /// 涡流速度的幅度系数，单位米/秒，范围 [0, 10]；0 关闭涡流。
  /// 多个模式叠加后，实际速度模长不以此值为硬上限。
  final double turbulence;

  /// 涡流的基础空间频率，单位 1/米，范围 [0.01, 10]。
  /// 数值越大，空间中的方向变化越密集；内部叠加三个倍频模式。
  final double spatialScale;

  /// 涡流相位的种子；不消耗粒子出生的随机序列。
  final int seed;

  /// 采样世界位置 [position]、时间 [time] 处的空气速度，返回单位米/秒。
  /// 输入位置使用米、时间为相对时间 Duration；不包含模拟器额外叠加的阵风与风场过渡。
  Vec3 velocityAt(Vec3 position, Duration time) =>
      _velocityAt(position, _seconds(time));

  /// 求解器使用精确物理秒采样，避免在每个积分点创建 Duration。
  Vec3 _velocityAt(Vec3 position, double time) {
    var air = Vec3.zero;
    for (final source in sources) {
      air += source._sample(position, time);
    }
    if (turbulence == 0) return air;
    final phase = (seed % 65521) * .0137;
    for (var octave = 0; octave < 3; octave++) {
      final frequency = spatialScale * (1 << octave);
      final x = position.x * frequency - time * (.24 + octave * .08) + phase;
      final y =
          position.y * frequency + time * (.18 + octave * .06) + 2.3 * octave;
      final z =
          position.z * frequency - time * (.21 + octave * .05) - phase * .7;
      final sx = math.sin(x), sy = math.sin(y), sz = math.sin(z);
      final cx = math.cos(x), cy = math.cos(y), cz = math.cos(z);
      // 对 A=(sin(y)cos(z), sin(z)cos(x), sin(x)cos(y))/frequency 求旋度。
      // XYZ 坐标共同参与，各模式散度为零；三角函数使空间与时间变化连续。
      air +=
          Vec3(-sx * sy - cz * cx, -sy * sz - cx * cy, -sz * sx - cy * cz) *
          (turbulence * .42 / (1 << octave));
    }
    return air;
  }
}

/// 叠加到当前风场的有限时长阵风，使用 sin² 包络平滑增强再减弱。
@immutable
final class WindGust {
  /// 创建有限时长的全局阵风，由控制器或模拟器的 gust 方法启动。
  /// [duration] 使用模拟时长；非法参数抛出 [ArgumentError]。
  WindGust.global({
    required Vec3 velocity,
    Duration duration = const Duration(seconds: 2),
  }) : this._(velocity, duration, null, 2);

  /// 创建围绕 [center] 指数衰减的局部阵风，半径外仍有风。
  /// [duration] 为模拟时长，[radius] 单位米；非法参数抛出 [ArgumentError]。
  WindGust.local({
    required Vec3 velocity,
    required Vec3 center,
    Duration duration = const Duration(seconds: 2),
    double radius = 2,
  }) : this._(velocity, duration, center, radius);

  WindGust._(this.velocity, this.duration, this.center, this.radius)
    : _durationSeconds = _seconds(duration) {
    _vector('gust.velocity', velocity);
    _validateDuration(
      'gust.duration',
      duration,
      const Duration(milliseconds: 50),
      const Duration(seconds: 30),
    );
    if (center != null) {
      _vector('gust.center', center!);
      _number('gust.radius', radius, .01, 1000);
    }
  }

  /// 阵风中点时刻的峰值空气速度，单位米/秒；局部阵风还受空间衰减影响。
  final Vec3 velocity;

  /// 阵风持续时间，范围 50 毫秒～30 秒；暂停模拟也暂停阵风。
  final Duration duration;
  final double _durationSeconds;

  /// 局部阵风的世界中心，单位米；null 表示全局阵风。
  final Vec3? center;

  /// 球形指数衰减尺度，单位米，范围 [0.01, 1000]；含义同 [WindSource.radius]。
  /// 全局阵风内部规范为 2，不开放构造入参。
  final double radius;
}

/// 记录阵风在模拟时钟上的开始时间，并采样其时间和空间包络。
class _ActiveGust {
  _ActiveGust(this.gust, this.start);
  final WindGust gust;
  final double start;
  Vec3 sample(Vec3 position, double time) {
    final progress = (time - start) / gust._durationSeconds;
    if (progress <= 0 || progress >= 1) return Vec3.zero;
    final pulse = math.sin(math.pi * progress);
    final falloff = gust.center == null
        ? 1.0
        : math.exp(
            -(position - gust.center!).lengthSquared /
                (gust.radius * gust.radius),
          );
    return gust.velocity * (pulse * pulse * falloff);
  }
}

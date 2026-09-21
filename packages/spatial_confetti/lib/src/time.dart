part of '../spatial_confetti.dart';

/// 均匀采样的时长范围，端点和采样结果均使用 [Duration]。
///
/// 构造支持 const；加入发射器时校验范围顺序与寿命限制。
/// 非固定范围按整数微秒在 [minimum, maximum) 内采样。
@immutable
final class DurationRange {
  /// 声明最小、最大时长，两端允许相等。
  const DurationRange(this.minimum, this.maximum);

  /// 声明始终返回 [value] 的固定时长。
  const DurationRange.fixed(Duration value) : minimum = value, maximum = value;

  /// 最小时长，不能大于 [maximum]。
  final Duration minimum;

  /// 最大时长，不能小于 [minimum]。
  final Duration maximum;

  /// 使用调用方随机源采样；每次消耗一个随机数，包括固定值范围。
  /// 返回微秒精度的 Duration；逆序范围抛出 [ArgumentError]。
  Duration sample(math.Random random) {
    if (maximum < minimum) {
      throw ArgumentError('DurationRange minimum must not exceed maximum');
    }
    final fraction = random.nextDouble();
    final span = maximum.inMicroseconds - minimum.inMicroseconds;
    return Duration(
      microseconds: minimum.inMicroseconds + (span * fraction).floor(),
    );
  }

  void _validate(String name, Duration low, Duration high) {
    _validateDuration('$name.minimum', minimum, low, high);
    _validateDuration('$name.maximum', maximum, minimum, high);
  }
}

/// 只在 API 或出生边界转换；内部物理计算继续使用秒。
double _seconds(Duration value) =>
    value.inMicroseconds / Duration.microsecondsPerSecond;

/// 将内部物理时间转换为最接近的整数微秒，不改变内部时钟。
Duration _asDuration(double seconds) =>
    Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());

void _validateDuration(
  String name,
  Duration value,
  Duration minimum,
  Duration maximum,
) {
  if (value < minimum || value > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'Expected $minimum through $maximum',
    );
  }
}

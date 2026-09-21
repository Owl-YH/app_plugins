part of '../spatial_confetti.dart';

/// 不可变三维向量：X 向右、Y 向下、Z 朝向相机。
/// 单位由用途决定，例如位置用米、速度用米/秒、加速度用米/秒²。
@immutable
class Vec3 {
  /// 从三个分量构造向量；本构造函数不做归一化或数值校验。
  const Vec3(this.x, this.y, this.z);

  /// 零向量。
  static const zero = Vec3(0, 0, 0);

  /// 沿 X 正方向的单位向量。
  static const right = Vec3(1, 0, 0);

  /// 沿 Y 正方向的单位向量，即屏幕向下。
  static const down = Vec3(0, 1, 0);

  /// 沿 Z 正方向的单位向量，即朝向相机。
  static const forward = Vec3(0, 0, 1);

  /// 水平分量，正值向右。
  final double x;

  /// 垂直分量，正值向下。
  final double y;

  /// 深度分量，正值朝向相机。
  final double z;

  /// 逐分量相加并返回新向量。
  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);

  /// 逐分量相减并返回新向量。
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);

  /// 返回反方向向量。
  Vec3 operator -() => Vec3(-x, -y, -z);

  /// 将三个分量乘以标量 [value]。
  Vec3 operator *(double value) => Vec3(x * value, y * value, z * value);

  /// 将三个分量除以 [value]；调用方应保证除数非零且有限。
  Vec3 operator /(double value) => this * (1 / value);

  /// 与 [other] 的点积，可用于计算方向投影。
  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  /// 与 [other] 的叉积，方向遵循当前 XYZ 分量的右手规则。
  Vec3 cross(Vec3 other) => Vec3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );

  /// 模长平方，适用于无需开方的距离与阈值比较。
  double get lengthSquared => dot(this);

  /// 欧氏模长。
  double get length => math.sqrt(lengthSquared);

  /// 三个分量是否都不是 NaN 或无穷大。
  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;

  /// 返回同方向单位向量；模长平方不大于 1e-18 时直接返回 [fallback]。
  /// 不会再次归一化 [fallback]。
  Vec3 normalized([Vec3 fallback = Vec3.right]) =>
      lengthSquared > 1e-18 ? this / length : fallback;

  /// 将模长限制到 [maximum]，保留方向；调用方应传入非负且有限的上限。
  Vec3 limited(double maximum) =>
      lengthSquared > maximum * maximum ? normalized() * maximum : this;

  /// 向 [other] 线性插值；[fraction] 不截断，超出 [0, 1] 时进行外插。
  Vec3 lerp(Vec3 other, double fraction) => Vec3(
    x + (other.x - x) * fraction,
    y + (other.y - y) * fraction,
    z + (other.z - z) * fraction,
  );

  /// 使用 Rodrigues 公式绕单位轴 [axis] 旋转 [angle] 弧度。
  /// 调用方须保证旋转轴已归一化。
  Vec3 rotated(Vec3 axis, double angle) {
    final cosine = math.cos(angle);
    final sine = math.sin(angle);
    final along = axis.dot(this) * (1 - cosine);
    return Vec3(
      x * cosine + (axis.y * z - axis.z * y) * sine + axis.x * along,
      y * cosine + (axis.z * x - axis.x * z) * sine + axis.y * along,
      z * cosine + (axis.x * y - axis.y * x) * sine + axis.z * along,
    );
  }

  /// 比较三个分量是否精确相等，不使用浮点误差容限。
  @override
  bool operator ==(Object other) =>
      other is Vec3 && x == other.x && y == other.y && z == other.z;

  /// 根据三个分量生成与相等比较一致的哈希值。
  @override
  int get hashCode => Object.hash(x, y, z);

  /// 返回包含 XYZ 分量的调试文本。
  @override
  String toString() => 'Vec3($x, $y, $z)';
}

/// 选取不接近平行的参考轴，构造与切线垂直的单位向量。
Vec3 _perpendicular(Vec3 tangent) {
  final reference = tangent.z.abs() < .8 ? Vec3.forward : Vec3.down;
  return reference.cross(tangent).normalized();
}

double _clamp(double value, double low, double high) =>
    value.clamp(low, high).toDouble();

/// 将输入截断到 [0, 1]，使用两端斜率为零的三次平滑曲线。
double _smooth(double value) {
  final t = _clamp(value, 0, 1);
  return t * t * (3 - 2 * t);
}

void _number(String name, double value, double minimum, double maximum) {
  if (!value.isFinite || value < minimum || value > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'Expected $minimum through $maximum',
    );
  }
}

void _vector(String name, Vec3 value, {bool nonzero = false}) {
  if (!value.isFinite ||
      value.length > 10000 ||
      (nonzero && value.lengthSquared < 1e-18)) {
    throw ArgumentError.value(value, name, 'Expected a finite world vector');
  }
}

/// 均匀采样的标量范围，单位由使用它的参数决定。
/// 构造时不校验；加入发射配方时校验上下界、顺序与有限性。
@immutable
class NumberRange {
  /// 声明从 [minimum] 到 [maximum] 的采样范围，两端允许相等。
  const NumberRange(this.minimum, this.maximum);

  /// 声明始终返回 [value] 的固定值范围。
  const NumberRange.fixed(double value) : minimum = value, maximum = value;

  /// 最小值，不能大于 [maximum]。
  final double minimum;

  /// 最大值，不能小于 [minimum]。
  final double maximum;

  /// 使用调用方的 [random] 均匀采样；上下界相等时返回固定值。
  /// 不相等时按 [math.Random.nextDouble] 的左闭右开区间映射。
  double sample(math.Random random) =>
      minimum + random.nextDouble() * (maximum - minimum);
  void _validate(String name, double low, double high) {
    _number(name, minimum, low, high);
    _number(name, maximum, minimum, high);
  }
}

/// 沿 Z 轴观察世界原点的固定透视相机，世界原点投影到视口中心。
/// [viewHeight] 指定 Z = 0 平面可见的世界高度，宽度由视口宽高比确定。
@immutable
class ConfettiCamera {
  /// 创建相机参数，在反投影或创建绘制器时校验。
  const ConfettiCamera({
    this.viewHeight = 8,
    this.distance = 10,
    this.near = .25,
    this.far = 60,
  });

  /// Z = 0 平面可见高度，单位米，范围 [0.1, 1000]；越小画面越放大。
  final double viewHeight;

  /// 相机到 Z = 0 平面的距离，单位米，范围 [0.1, 1000]。
  /// 相机位置为 (0, 0, distance)。
  final double distance;

  /// 近裁剪面距相机的距离，单位米，范围为 0.01 到 [distance]。
  final double near;

  /// 远裁剪面距相机的距离，单位米，范围为 distance + 0.01 到 10000。
  final double far;

  void _validate() {
    _number('viewHeight', viewHeight, .1, 1000);
    _number('distance', distance, .1, 1000);
    _number('near', near, .01, distance);
    _number('far', far, distance + .01, 10000);
  }

  /// 将世界位置 [position] 投影为 [viewport] 内的局部逻辑像素坐标。
  ///
  /// 世界位置非有限、视口为空或超出近远裁剪面时返回 null。
  /// 不按视口左右上下边界裁剪，返回坐标仍可能位于画布外。
  Offset? project(Vec3 position, Size viewport) {
    final depth = distance - position.z;
    if (!position.isFinite || viewport.isEmpty || depth < near || depth > far) {
      return null;
    }
    final scale = viewport.height / viewHeight * distance / depth;
    return Offset(
      viewport.width * .5 + position.x * scale,
      viewport.height * .5 + position.y * scale,
    );
  }

  /// 将局部逻辑像素位置 [position] 反投影到指定的世界 Z 平面。
  ///
  /// [viewport] 是绘制区域尺寸；[depth] 是世界 Z 坐标，单位米，
  /// 不是到相机的距离，必须位于近远裁剪面之间。
  /// 绘制时应使用同一个相机；非法相机、深度、位置或空视口抛出 [ArgumentError]。
  Vec3 unproject(Offset position, Size viewport, {double depth = 0}) {
    _validate();
    _number('depth', distance - depth, near, far);
    if (viewport.isEmpty || !position.dx.isFinite || !position.dy.isFinite) {
      throw ArgumentError('A finite point and nonempty viewport are required');
    }
    final scale = viewport.height / viewHeight * distance / (distance - depth);
    return Vec3(
      (position.dx - viewport.width * .5) / scale,
      (position.dy - viewport.height * .5) / scale,
      depth,
    );
  }
}

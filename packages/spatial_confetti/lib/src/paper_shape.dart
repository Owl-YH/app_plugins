part of '../spatial_confetti.dart';

/// 纸片的不可变平面轮廓；实际米制尺寸由 [PaperSize] 决定。
///
/// 支持一个闭合、无自交、非零面积的外轮廓，不支持孔洞或分离区域。
/// 内置构造支持 const，在加入 [ParticleChoice] 时校验和准备几何。
/// 曲线是有界多边形近似，最多 128 个顶点；准备结果不消耗随机数。
@immutable
sealed class PaperShape {
  const PaperShape._();

  /// 矩形；[aspectRatio] 为宽/高，范围 [0.01, 100]，1 表示正方形。
  /// 内置轻微圆角，半径为本轮廓短边的 20%；每个圆角用四段近似，共 20 个顶点。
  /// 圆角参与面积、惯量、受力和绘制；使用 stretched 尺寸时随轮廓非等比拉伸。
  const factory PaperShape.rectangle({double aspectRatio}) = _RectangleShape;

  /// 圆形；使用 64 个轮廓顶点近似，等比尺寸下保持圆形比例。
  const factory PaperShape.circle() = _CircleShape;

  /// 尖角朝局部 Y 负方向的等边三角形；任意三角形使用 polygon。
  const factory PaperShape.triangle() = _TriangleShape;

  /// 星形；[points] 为 3～32 个尖角，内外半径比范围 [0.05, 0.95]。
  const factory PaperShape.star({int points, double innerRadiusRatio}) =
      _StarShape;

  /// 上端双弧、尖端朝局部 Y 正方向的心形，以 64 个顶点近似曲线。
  const factory PaperShape.heart() = _HeartShape;

  /// 复制 3～128 个顶点并按顺序闭合；可省略末尾重复的首点。
  /// 坐标可用任意比例，统一归一化；顺/逆时针均可，凹轮廓受支持。
  /// 自交、接触、退化或超出复杂度限制时立即抛出 ArgumentError。
  factory PaperShape.polygon({required List<Offset> vertices}) =>
      _CustomPaperShape(_PaperGeometry.prepare(vertices));

  /// 复制并导入单个显式闭合的 Path；后续修改原 Path 不影响本形状。
  /// [tolerance] 是相对包围盒最长边的采样偏差阈值，范围 [0.0001, 0.01]。
  /// 曲线测量和离散仅在本次导入执行；需要超过 128 点时拒绝配置。
  factory PaperShape.path(ui.Path path, {double tolerance = .002}) =>
      _CustomPaperShape(_PaperGeometry.fromPath(ui.Path.from(path), tolerance));

  static final _cache = Expando<_PaperGeometry>('paper geometry');
  _PaperGeometry get _geometry =>
      _cache[this] ??= _PaperGeometry.prepare(_outline());
  List<Offset> _outline();
}

final class _RectangleShape extends PaperShape {
  const _RectangleShape({this.aspectRatio = 1}) : super._();
  final double aspectRatio;
  @override
  List<Offset> _outline() {
    _number('shape.aspectRatio', aspectRatio, .01, 100);
    final radius = math.min(aspectRatio, 1.0) * .2;
    final centers = [
      Offset(aspectRatio - radius, radius),
      Offset(aspectRatio - radius, 1 - radius),
      Offset(radius, 1 - radius),
      Offset(radius, radius),
    ];
    // 与其他曲线轮廓一样只在准备时离散，并复用规范几何缓存。
    return [
      for (var corner = 0; corner < 4; corner++)
        for (var step = 0; step <= 4; step++)
          centers[corner] +
              Offset(
                    math.cos((corner - 1 + step / 4) * math.pi / 2),
                    math.sin((corner - 1 + step / 4) * math.pi / 2),
                  ) *
                  radius,
    ];
  }
}

final class _CircleShape extends PaperShape {
  const _CircleShape() : super._();
  @override
  List<Offset> _outline() => [
    for (var i = 0; i < 64; i++)
      Offset(math.cos(i * math.pi / 32), math.sin(i * math.pi / 32)),
  ];
}

final class _TriangleShape extends PaperShape {
  const _TriangleShape() : super._();
  @override
  List<Offset> _outline() => [
    Offset(0, -math.sqrt(3) / 2),
    const Offset(.5, 0),
    const Offset(-.5, 0),
  ];
}

final class _StarShape extends PaperShape {
  const _StarShape({this.points = 5, this.innerRadiusRatio = .45}) : super._();
  final int points;
  final double innerRadiusRatio;
  @override
  List<Offset> _outline() {
    if (points < 3 || points > 32)
      throw ArgumentError.value(
        points,
        'shape.points',
        'Expected 3 through 32',
      );
    _number('shape.innerRadiusRatio', innerRadiusRatio, .05, .95);
    return [
      for (var i = 0; i < points * 2; i++)
        Offset(
              math.cos(i * math.pi / points - math.pi / 2),
              math.sin(i * math.pi / points - math.pi / 2),
            ) *
            (i.isEven ? 1 : innerRadiusRatio),
    ];
  }
}

final class _HeartShape extends PaperShape {
  const _HeartShape() : super._();
  @override
  List<Offset> _outline() => [
    for (var i = 0; i < 64; i++) _point(i * math.pi / 32),
  ];
  Offset _point(double t) => Offset(
    16 * math.pow(math.sin(t), 3).toDouble(),
    -(13 * math.cos(t) -
        5 * math.cos(2 * t) -
        2 * math.cos(3 * t) -
        math.cos(4 * t)),
  );
}

final class _CustomPaperShape extends PaperShape {
  const _CustomPaperShape(this.geometry) : super._();
  final _PaperGeometry geometry;
  @override
  _PaperGeometry get _geometry => geometry;
  @override
  List<Offset> _outline() => geometry.vertices;
}

/// 纸片出生时的尺寸采样策略；米制宽高均须处于 [0.002, 0.5]。
/// 两个构造分开表达保持形状比例与主动拉伸，支持 const。
@immutable
sealed class PaperSize {
  const PaperSize._();

  /// 等比缩放；[longestSide] 是轮廓局部包围盒最长边的米制随机范围。
  const factory PaperSize.proportional(NumberRange longestSide) =
      _ProportionalPaperSize;

  /// 独立随机采样实际宽高；圆形可被拉伸成椭圆，其他轮廓同样非等比变形。
  const factory PaperSize.stretched({
    required NumberRange width,
    required NumberRange height,
  }) = _StretchedPaperSize;

  void _validate(_PaperGeometry geometry);
  Size _sample(math.Random random, _PaperGeometry geometry);
}

final class _ProportionalPaperSize extends PaperSize {
  const _ProportionalPaperSize(this.longestSide) : super._();
  final NumberRange longestSide;
  @override
  void _validate(_PaperGeometry geometry) {
    longestSide._validate('size.longestSide', .002, .5);
    _number(
      'size.minimumSide',
      longestSide.minimum * math.min(geometry.width, geometry.height),
      .002,
      .5,
    );
  }

  @override
  Size _sample(math.Random random, _PaperGeometry geometry) {
    final side = longestSide.sample(random);
    return Size(geometry.width * side, geometry.height * side);
  }
}

final class _StretchedPaperSize extends PaperSize {
  const _StretchedPaperSize({required this.width, required this.height})
    : super._();
  final NumberRange width, height;
  @override
  void _validate(_PaperGeometry geometry) {
    width._validate('size.width', .002, .5);
    height._validate('size.height', .002, .5);
  }

  @override
  Size _sample(math.Random random, _PaperGeometry geometry) =>
      Size(width.sample(random), height.sample(random));
}

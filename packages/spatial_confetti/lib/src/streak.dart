part of '../spatial_confetti.dart';

/// 光迹头部的点运动状态；只保存当前位置、速度和累计路程，不分配历史或材料网格。
class _StreakBody extends _Body {
  _StreakBody({
    required super.id,
    required super.owner,
    required StreakParticle super.recipe,
    required super.color,
    required super.birth,
    required super.lifetime,
    required super.lifetimeSettings,
    required super.width,
    required this.position,
    required this.speed,
  }) {
    // 风格时间尺度由寿命推导并封顶；短寿命按比例收缩，长寿命不无限拉长。
    // 以下为内部物理秒数，不额外暴露一组与发射器寿命重复的时间配置。
    stretchSeconds = math.min(.08, lifetime * .3);
    expandSeconds = math.min(.04, lifetime * .15);
    shrinkSeconds = math.min(.13, lifetime * .5);
  }

  StreakParticle get settings => recipe as StreakParticle;
  Vec3 position, speed;
  double distance = 0;
  late final double stretchSeconds, expandSeconds, shrinkSeconds;
  @override
  Vec3 get center => position;
  @override
  Vec3 get velocity => speed;

  /// 展开、收回与速度长度分别计算；年龄超出寿命时严格为零。
  double lengthAt(double time) {
    final age = time - birth;
    if (age < 0 || age >= lifetime) return 0;
    final expand = _smooth(age / expandSeconds);
    final shrink = _smooth((lifetime - age) / shrinkSeconds);
    return math.min(distance, speed.length * stretchSeconds) * expand * shrink;
  }

  @override
  void step(ConfettiSimulation simulation, double step) {
    final resistance = settings.airResistance;
    final air = resistance == 0
        ? Vec3.zero
        : simulation._airAt(
            position +
                speed * (step * .5) +
                simulation.gravity * (step * step / 8),
            offset: -step * .5,
          );
    final acceleration = simulation.gravity + (air - speed) * resistance;
    final x = resistance * step;
    // 小指数使用级数避免 (1-exp(-x)) 与 (dt-a) 消减；k=0 时退化为精确抛体。
    final a = x < 1e-4
        ? step * (1 - x / 2 + x * x / 6 - x * x * x / 24)
        : (1 - math.exp(-x)) / resistance;
    final b = x < 1e-4
        ? step * step * (.5 - x / 6 + x * x / 24 - x * x * x / 120)
        : (step - a) / resistance;
    position += speed * step + acceleration * b;
    final next = speed + acceleration * a;
    distance += (speed.length + next.length) * (step * .5);
    speed = next;
  }
}

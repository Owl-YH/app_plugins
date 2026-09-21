import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'simulation_test.dart' show effect;

/// 固定最初验收的直角轮廓；内置 rectangle 的圆角属于独立物理工况。
final sharpRectangle = PaperShape.polygon(
  vertices: const [
    ui.Offset(0, 0),
    ui.Offset(1, 0),
    ui.Offset(1, 1),
    ui.Offset(0, 1),
  ],
);

/// 从真实出生姿态定义释放角，不向模拟器注入姿态或伪造气动力。
({ConfettiSimulation simulation, Vec3 down, Vec3 across, Vec3 axis})
fallingPaper({
  PaperShape shape = const PaperShape.rectangle(),
  double density = .08,
  double degrees = 40,
  double timeScale = 1,
  double pressure = 1.15,
  double friction = .02,
}) {
  final simulation = ConfettiSimulation(gravity: Vec3.zero);
  simulation.emit(
    effect(
      speed: 0,
      lifetime: const Duration(seconds: 60),
      particle: PaperParticle.noBend(
        shape: shape,
        size: const PaperSize.stretched(
          width: NumberRange.fixed(.1),
          height: NumberRange.fixed(.3),
        ),
        massPerArea: density,
        dragCoefficient: pressure,
        surfaceFriction: friction,
        angularSpeed: const NumberRange.fixed(0),
      ),
    ),
  );
  final p = simulation.snapshot.single;
  final right = p.widthDirections.single;
  // 轮廓含圆角，使用覆盖整张纸片的三点求平面，避免把圆角切线当成高度轴。
  final normal = (p.nodes[p.nodes.length ~/ 3] - p.nodes[0])
      .cross(p.nodes[p.nodes.length * 2 ~/ 3] - p.nodes[0])
      .normalized();
  final axis = normal.cross(right).normalized();
  final angle = degrees * math.pi / 180;
  final down = normal * math.cos(angle) + right * math.sin(angle);
  final across = right * math.cos(angle) - normal * math.sin(angle);
  simulation.gravity = down * (9.81 / (timeScale * timeScale));
  return (simulation: simulation, down: down, across: across, axis: axis);
}

void main() {
  test(
    'oblique pressure starts rotation while exact broadside release preserves symmetry',
    () {
      for (final degrees in [0.0, 20.0, -20.0]) {
        final flight = fallingPaper(degrees: degrees);
        final sim = flight.simulation;
        addTearDown(sim.dispose);
        sim.advance(const Duration(milliseconds: 500));
        final p = sim.snapshot.single;
        expect(
          p.angularVelocity!.length,
          degrees == 0 ? lessThan(1e-9) : greaterThan(.5),
        );
        expect(
          p.angularVelocity!.dot(flight.axis) * degrees,
          lessThanOrEqualTo(1e-9),
        );
        expect(p.velocity.dot(flight.axis).abs(), lessThan(1e-9));
        expect(
          (p.angularVelocity! -
                  flight.axis * p.angularVelocity!.dot(flight.axis))
              .length,
          lessThan(1e-8),
          reason:
              'The integration mesh must not choose a sideways turning direction',
        );
      }
      final a = fallingPaper(degrees: 20), b = fallingPaper(degrees: -20);
      addTearDown(a.simulation.dispose);
      addTearDown(b.simulation.dispose);
      a.simulation.advance(const Duration(seconds: 1));
      b.simulation.advance(const Duration(seconds: 1));
      final pa = a.simulation.snapshot.single,
          pb = b.simulation.snapshot.single;
      expect(
        pa.position.dot(a.across),
        closeTo(-pb.position.dot(b.across), 1e-8),
      );
      expect(pa.position.dot(a.down), closeTo(pb.position.dot(b.down), 1e-8));
    },
  );

  test(
    'sharp-rectangle zero-spin free fall produces bounded flutter and complete tumbling for distinct loadings',
    () {
      for (final density in [.02, .08]) {
        final flight = fallingPaper(shape: sharpRectangle, density: density);
        final sim = flight.simulation;
        addTearDown(sim.dispose);
        var last = 40 * math.pi / 180, pitch = last, low = last, high = last;
        var reversals = 0, previousSign = 0;
        var outOfPlane = 0.0;
        // 六秒覆盖多次飘摆/完整翻转。更长时间的三维不稳定运动不约束在二维平面。
        for (var i = 0; i < 300; i++) {
          sim.advance(const Duration(milliseconds: 20));
          final p = sim.snapshot.single, right = p.widthDirections.single;
          final angle = math.atan2(
            right.dot(flight.down),
            right.dot(flight.across),
          );
          pitch += math.atan2(math.sin(angle - last), math.cos(angle - last));
          last = angle;
          low = math.min(low, pitch);
          high = math.max(high, pitch);
          final velocity = p.velocity.dot(flight.across);
          final sign = velocity.abs() > .03
              ? velocity.sign.toInt()
              : previousSign;
          if (previousSign != 0 && sign != previousSign) reversals++;
          previousSign = sign;
          outOfPlane = math.max(outOfPlane, p.position.dot(flight.axis).abs());
          expect(
            p.kineticEnergy! - p.mass! * sim.gravity.dot(p.position),
            lessThan(1e-6),
            reason:
                'Total mechanical energy cannot grow beyond the initially zero energy',
          );
        }
        expect(reversals, greaterThanOrEqualTo(3));
        expect(
          outOfPlane,
          lessThan(1e-5),
          reason: 'Six-second reference, density $density, in metres',
        );
        expect(
          high - low,
          density == .02
              ? inExclusiveRange(.8, math.pi)
              : greaterThan(2 * math.pi),
        );
        expect(sim.stats.invalidParticles, 0);
      }
    },
  );

  for (final density in [.02, .08]) {
    test(
      'rounded-rectangle zero-spin free fall at density $density preserves its flight mode and energy',
      () {
        final flight = fallingPaper(
          shape: const PaperShape.rectangle(),
          density: density,
        );
        final sim = flight.simulation;
        addTearDown(sim.dispose);
        var last = 40 * math.pi / 180, pitch = last, low = last, high = last;
        var reversals = 0, previousSign = 0;
        for (var i = 0; i < 300; i++) {
          sim.advance(const Duration(milliseconds: 20));
          final p = sim.snapshot.single, right = p.widthDirections.single;
          final down = right.dot(flight.down),
              across = right.dot(flight.across);
          // 宽度轴须保持在参考平面 45° 内，避免把投影奇点误计为完整翻滚。
          expect(down * down + across * across, greaterThan(.5));
          final angle = math.atan2(down, across);
          pitch += math.atan2(math.sin(angle - last), math.cos(angle - last));
          last = angle;
          low = math.min(low, pitch);
          high = math.max(high, pitch);
          final velocity = p.velocity.dot(flight.across);
          final sign = velocity.abs() > .03
              ? velocity.sign.toInt()
              : previousSign;
          if (previousSign != 0 && sign != previousSign) reversals++;
          previousSign = sign;
          expect(p.position.isFinite, isTrue);
          expect(p.velocity.isFinite, isTrue);
          expect(p.angularVelocity!.isFinite, isTrue);
          expect(
            p.kineticEnergy! - p.mass! * sim.gravity.dot(p.position),
            lessThan(1e-6),
            reason:
                'Still air must not increase total mechanical energy above its initial zero value',
          );
        }
        if (density == .02) {
          expect(reversals, greaterThanOrEqualTo(3));
          expect(high - low, inExclusiveRange(.8, math.pi));
        } else {
          // 翻滚由姿态跨越完整一周定义，不要求质心横向速度反复变号。
          expect(high - low, greaterThan(2 * math.pi));
        }
        // 圆角的平面对称性由上面的短时正面/倾斜/镜像释放用例验证。
        // 此处不沿用直角参考片的六秒离平面误差阈值。
        expect(sim.stats.invalidParticles, 0);
      },
    );
  }

  test(
    'pressure and friction remain independent and neither injects unforced energy',
    () {
      for (final (pressure, friction) in [
        (1.15, .02),
        (1.15, 0.0),
        (0.0, .2),
        (0.0, 0.0),
      ]) {
        for (final shape in [
          const PaperShape.rectangle(),
          const PaperShape.triangle(),
          const PaperShape.circle(),
          const PaperShape.heart(),
        ]) {
          final sim = ConfettiSimulation(gravity: Vec3.zero);
          addTearDown(sim.dispose);
          sim.emit(
            effect(
              speed: 4,
              particle: PaperParticle.noBend(
                shape: shape,
                size: const PaperSize.proportional(NumberRange.fixed(.1)),
                dragCoefficient: pressure,
                surfaceFriction: friction,
                angularSpeed: const NumberRange.fixed(4),
              ),
            ),
          );
          final first = sim.snapshot.single;
          var previous = first.kineticEnergy!;
          for (var i = 0; i < 100; i++) {
            sim.advance(const Duration(milliseconds: 10));
            final current = sim.snapshot.single.kineticEnergy!;
            expect(
              current,
              lessThanOrEqualTo(previous + first.kineticEnergy! * 1e-6),
            );
            previous = current;
          }
          if (pressure == 0 && friction == 0) {
            expect(
              (sim.snapshot.single.angularMomentum! - first.angularMomentum!)
                  .length,
              lessThan(1e-12),
            );
          } else {
            expect(previous, lessThan(first.kineticEnergy! * .95));
          }
        }
      }
    },
  );

  test('slowing the same physical system shows time-step convergence', () {
    final results = <ParticleSnapshot>[];
    for (final scale in [1.0, 2.0, 4.0]) {
      final flight = fallingPaper(timeScale: scale, degrees: 25);
      addTearDown(flight.simulation.dispose);
      flight.simulation.advance(Duration(milliseconds: (750 * scale).round()));
      results.add(flight.simulation.snapshot.single);
    }
    double difference(ParticleSnapshot a, ParticleSnapshot b) =>
        (a.position - b.position).length +
        .1 * (a.widthDirections.single - b.widthDirections.single).length;
    final coarse = difference(results[0], results[1]),
        fine = difference(results[1], results[2]);
    expect(fine, lessThan(coarse * .8));
    expect(difference(results[0], results[2]), lessThan(.02));
  });

  test('uniform XYZ wind obeys a Galilean change of reference frame', () {
    const boost = Vec3(1.3, -.7, 2.1);
    final a = ConfettiSimulation(),
        b = ConfettiSimulation(
          wind: WindField(
            sources: [WindSource.global(velocity: boost, variation: 0)],
          ),
        );
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    const recipe = PaperParticle.noBend(
      shape: PaperShape.star(),
      size: PaperSize.proportional(NumberRange.fixed(.1)),
      angularSpeed: NumberRange.fixed(0),
    );
    a.emit(effect(particle: recipe, speed: 0, direction: boost));
    b.emit(effect(particle: recipe, speed: boost.length, direction: boost));
    a.advance(const Duration(seconds: 1));
    b.advance(const Duration(seconds: 1));
    final pa = a.snapshot.single, pb = b.snapshot.single;
    expect((pb.position - pa.position - boost).length, lessThan(1e-8));
    expect((pb.velocity - pa.velocity - boost).length, lessThan(1e-8));
    expect((pb.angularVelocity! - pa.angularVelocity!).length, lessThan(1e-7));
  });

  test(
    'a local gust changes the three-dimensional fall and preserves frame partitioning',
    () {
      final a = fallingPaper(), b = fallingPaper(), control = fallingPaper();
      for (final flight in [a, b, control])
        addTearDown(flight.simulation.dispose);
      for (final flight in [a, b]) {
        flight.simulation.gust(
          WindGust.local(
            velocity: const Vec3(2, -1, 3),
            center: Vec3.zero,
            radius: 2,
            duration: const Duration(seconds: 1),
          ),
        );
      }
      a.simulation.advance(const Duration(seconds: 1));
      for (var i = 0; i < 100; i++)
        b.simulation.advance(const Duration(milliseconds: 10));
      control.simulation.advance(const Duration(seconds: 1));
      expect(
        a.simulation.snapshot.single.nodes,
        b.simulation.snapshot.single.nodes,
      );
      expect(
        (a.simulation.snapshot.single.position -
                control.simulation.snapshot.single.position)
            .length,
        greaterThan(.1),
      );
      expect(
        (a.simulation.snapshot.single.angularVelocity! -
                control.simulation.snapshot.single.angularVelocity!)
            .length,
        greaterThan(.1),
      );
    },
  );

  test(
    'small light sheets and large stretched concave sheets stay finite under strong air',
    () {
      final concave = PaperShape.polygon(
        vertices: const [
          ui.Offset(0, 0),
          ui.Offset(1, 0),
          ui.Offset(1, .2),
          ui.Offset(.2, .2),
          ui.Offset(.2, .8),
          ui.Offset(1, .8),
          ui.Offset(1, 1),
          ui.Offset(0, 1),
        ],
      );
      for (final size in [
        const PaperSize.proportional(NumberRange.fixed(.0025)),
        const PaperSize.stretched(
          width: NumberRange.fixed(.002),
          height: NumberRange.fixed(.5),
        ),
      ]) {
        for (final shape in [const PaperShape.rectangle(), concave]) {
          final sim = ConfettiSimulation(
            wind: WindField(
              sources: [
                WindSource.global(
                  velocity: const Vec3(15, -8, 20),
                  variation: 0,
                ),
              ],
              turbulence: 2,
            ),
          );
          addTearDown(sim.dispose);
          sim.emit(
            effect(
              speed: 30,
              count: 3,
              particle: PaperParticle.noBend(
                shape: shape,
                size: size,
                massPerArea: .005,
                dragCoefficient: 4,
                surfaceFriction: 1,
                angularSpeed: const NumberRange.fixed(30),
              ),
            ),
          );
          sim.advance(const Duration(seconds: 1));
          expect(sim.stats.invalidParticles, 0);
          expect(sim.snapshot.length, 3);
          for (final p in sim.snapshot) {
            expect(p.kineticEnergy!.isFinite, isTrue);
            expect(p.angularVelocity!.isFinite, isTrue);
            expect(p.velocity.length, lessThan(100));
          }
        }
      }
    },
  );
}

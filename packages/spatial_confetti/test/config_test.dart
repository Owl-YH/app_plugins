import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final choices = [ParticleChoice(particle: const PaperParticle.noBend())];

  test('global and local wind retain their actual spatial meaning', () {
    final global = WindField(
      sources: [WindSource.global(velocity: const Vec3(2, 0, 0), variation: 0)],
    );
    expect(
      global.velocityAt(Vec3.zero, const Duration(milliseconds: 500)),
      const Vec3(2, 0, 0),
    );
    expect(
      global.velocityAt(
        const Vec3(10, -5, 3),
        const Duration(milliseconds: 500),
      ),
      const Vec3(2, 0, 0),
    );
    final local = WindField(
      sources: [
        WindSource.local(
          velocity: const Vec3(2, 0, 0),
          center: Vec3.zero,
          radius: 2,
          variation: 0,
        ),
      ],
    );
    expect(local.velocityAt(Vec3.zero, const Duration(milliseconds: 500)).x, 2);
    expect(
      local
          .velocityAt(const Vec3(2, 0, 0), const Duration(milliseconds: 500))
          .x,
      closeTo(2 / math.e, 1e-12),
    );
    expect(
      local
          .velocityAt(const Vec3(4, 0, 0), const Duration(milliseconds: 500))
          .x,
      greaterThan(0),
    );
  });

  test('wind constructors validate only the supported spatial inputs', () {
    expect(
      () => WindSource.global(velocity: const Vec3(double.nan, 0, 0)),
      throwsArgumentError,
    );
    expect(
      () =>
          WindSource.local(velocity: Vec3.right, center: Vec3.zero, radius: 0),
      throwsArgumentError,
    );
    expect(
      () => WindSource.local(
        velocity: Vec3.right,
        center: const Vec3(0, double.infinity, 0),
      ),
      throwsArgumentError,
    );
    expect(
      () => WindGust.global(velocity: Vec3.right, duration: Duration.zero),
      throwsArgumentError,
    );
    expect(
      () => WindGust.local(velocity: Vec3.right, center: Vec3.zero, radius: -1),
      throwsArgumentError,
    );
    expect(WindGust.global(velocity: Vec3.right).center, isNull);
    expect(
      WindGust.local(velocity: Vec3.right, center: Vec3.down).center,
      Vec3.down,
    );
  });

  test(
    'a stream keeps its opening burst and exact delayed birth boundaries',
    () {
      final sim = ConfettiSimulation(gravity: Vec3.zero);
      addTearDown(sim.dispose);
      sim.emit(
        ConfettiEffect(
          emitters: [
            ConfettiEmitter.stream(
              particles: choices,
              burstCount: 3,
              rate: 4,
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 250),
              lifetime: const ParticleLifetime(
                duration: DurationRange.fixed(Duration(seconds: 2)),
              ),
              speed: const NumberRange.fixed(0),
            ),
          ],
        ),
      );
      expect(sim.snapshot, isEmpty);
      sim.advance(const Duration(milliseconds: 250));
      expect(sim.snapshot.length, 3);
      sim.advance(const Duration(milliseconds: 250));
      expect(sim.snapshot.length, 4);
      sim.advance(const Duration(milliseconds: 250));
      expect(sim.snapshot.map((p) => p.age), const [
        Duration(milliseconds: 500),
        Duration(milliseconds: 500),
        Duration(milliseconds: 500),
        Duration(milliseconds: 250),
        Duration.zero,
      ]);
      final burst = ConfettiEmitter.burst(particles: choices, burstCount: 2);
      expect(burst.rate, 0);
      expect(burst.duration, Duration.zero);
      final stream = ConfettiEmitter.stream(
        particles: choices,
        rate: 4,
        duration: const Duration(seconds: 1),
      );
      expect(stream.burstCount, 0);
    },
  );

  test('invalid emission timing is rejected before a playback exists', () {
    expect(
      () => ConfettiEmitter.burst(particles: choices, burstCount: 0),
      throwsArgumentError,
    );
    expect(
      () => ConfettiEmitter.burst(particles: choices, burstCount: 10001),
      throwsArgumentError,
    );
    for (final rate in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => ConfettiEmitter.stream(
          particles: choices,
          rate: rate,
          duration: const Duration(seconds: 1),
          burstCount: 3,
        ),
        throwsArgumentError,
      );
    }
    for (final duration in const [
      Duration.zero,
      Duration(microseconds: -1),
      Duration(milliseconds: 9),
      Duration(seconds: 121),
    ]) {
      expect(
        () => ConfettiEmitter.stream(
          particles: choices,
          rate: 1,
          duration: duration,
        ),
        throwsArgumentError,
      );
    }
  });
}

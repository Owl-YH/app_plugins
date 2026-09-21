import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'simulation_test.dart' show effect;

void main() {
  test('microsecond inputs retain a precise 120 Hz clock', () {
    final split = ConfettiSimulation(gravity: Vec3.zero);
    final whole = ConfettiSimulation(gravity: Vec3.zero);
    addTearDown(split.dispose);
    addTearDown(whole.dispose);
    for (final sim in [split, whole]) {
      sim.emit(
        effect(
          particle: const PaperParticle.noBend(
            dragCoefficient: 0,
            surfaceFriction: 0,
          ),
        ),
      );
    }
    split.advance(const Duration(microseconds: 8333));
    expect(split.time, Duration.zero);
    split.advance(const Duration(microseconds: 1));
    expect(split.time, const Duration(microseconds: 8333));
    split.advance(const Duration(microseconds: 991666));
    whole.advance(const Duration(seconds: 1));
    expect(split.time, const Duration(seconds: 1));
    expect(split.snapshot.single.age, const Duration(seconds: 1));
    expect(split.snapshot.single.position, whole.snapshot.single.position);
    expect(split.snapshot.single.velocity, whole.snapshot.single.velocity);
  });

  test(
    'duration ranges sample whole microseconds without changing random consumption',
    () {
      const range = DurationRange(
        Duration(microseconds: 20000),
        Duration(microseconds: 20003),
      );
      final random = math.Random(41);
      final seen = <Duration>{};
      for (var i = 0; i < 80; i++) {
        final value = range.sample(random);
        expect(value, greaterThanOrEqualTo(range.minimum));
        expect(value, lessThan(range.maximum));
        seen.add(value);
      }
      expect(seen.length, 3);
      final fixedRandom = math.Random(73), numericRandom = math.Random(73);
      expect(
        const DurationRange.fixed(
          Duration(milliseconds: 25),
        ).sample(fixedRandom),
        const Duration(milliseconds: 25),
      );
      const NumberRange.fixed(.025).sample(numericRandom);
      expect(fixedRandom.nextDouble(), numericRandom.nextDouble());
    },
  );

  test('duration limits reject invalid ranges before playback', () {
    final choices = [ParticleChoice(particle: const PaperParticle.noBend())];
    for (final range in const [
      DurationRange(Duration(seconds: 2), Duration(seconds: 1)),
      DurationRange.fixed(Duration(microseconds: 19999)),
      DurationRange.fixed(Duration(microseconds: 60000001)),
    ]) {
      expect(
        () => ConfettiEmitter.burst(
          particles: choices,
          burstCount: 1,
          lifetime: ParticleLifetime(duration: range),
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => WindGust.global(
        velocity: Vec3.right,
        duration: const Duration(milliseconds: 49),
      ),
      throwsArgumentError,
    );
    final sim = ConfettiSimulation();
    addTearDown(sim.dispose);
    expect(
      () => sim.advance(const Duration(microseconds: -1)),
      throwsArgumentError,
    );
    expect(
      () => sim.advance(const Duration(microseconds: 60000001)),
      throwsArgumentError,
    );
    expect(
      () => sim.setWind(
        WindField(),
        transition: const Duration(microseconds: 5000001),
      ),
      throwsArgumentError,
    );
  });

  test(
    'typed delay, stream duration and sampled lifetime retain their boundary',
    () async {
      final sim = ConfettiSimulation(gravity: Vec3.zero);
      addTearDown(sim.dispose);
      final playback = sim.emit(
        ConfettiEffect(
          emitters: [
            ConfettiEmitter.stream(
              particles: [
                ParticleChoice(particle: const PaperParticle.noBend()),
              ],
              burstCount: 1,
              rate: 4,
              delay: const Duration(microseconds: 100001),
              duration: const Duration(milliseconds: 250),
              lifetime: const ParticleLifetime(
                duration: DurationRange.fixed(Duration(milliseconds: 500)),
              ),
            ),
          ],
        ),
      );
      sim.advance(const Duration(milliseconds: 100));
      expect(sim.snapshot, isEmpty);
      sim.advance(const Duration(microseconds: 8334));
      expect(sim.snapshot.single.age, Duration.zero);
      expect(sim.snapshot.single.lifetime, const Duration(milliseconds: 500));
      sim.advance(const Duration(seconds: 1));
      expect(await playback.done, ConfettiCompletion.completed);
      expect(sim.stats.birthAttempts, 2);
    },
  );
}

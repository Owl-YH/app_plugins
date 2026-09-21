import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'simulation_test.dart' show effect;
import 'time_helpers.dart';

void main() {
  test(
    'unforced material energy and angular momentum converge across resolutions',
    () {
      final endLengths = <double>[];
      for (final segments in [16, 24, 32]) {
        final sim = ConfettiSimulation(gravity: Vec3.zero);
        sim.emit(
          effect(
            speed: 0,
            particle: RibbonParticle(
              width: const NumberRange.fixed(.025),
              length: const NumberRange.fixed(2),
              segments: segments,
              dragCoefficient: 0,
              surfaceFriction: 0,
              damping: 0,
              angularSpeed: const NumberRange.fixed(2),
            ),
          ),
        );
        final birth = sim.snapshot.single;
        final initialEnergy = birth.kineticEnergy! + birth.elasticEnergy!;
        for (var tick = 0; tick < 240; tick++) {
          sim.advance(elapsedForFrame(tick, 120));
          final p = sim.snapshot.single;
          expect(
            p.kineticEnergy! + p.elasticEnergy!,
            lessThan(initialEnergy * 1.01),
          );
          expect(p.velocity.length, lessThan(1e-8));
          expect(
            (p.angularMomentum! - birth.angularMomentum!).length,
            lessThan(birth.angularMomentum!.length * .03),
          );
          for (var i = 1; i < p.nodes.length; i++) {
            expect(
              ((p.nodes[i] - p.nodes[i - 1]).length - 2 / segments).abs(),
              lessThan(2 / segments * .01),
            );
          }
        }
        final p = sim.snapshot.single;
        endLengths.add((p.nodes.last - p.nodes.first).length);
        sim.dispose();
      }
      expect(
        (endLengths[2] - endLengths[1]).abs() / endLengths[2],
        lessThan(.01),
      );
    },
  );

  test('stationary air dissipates mechanical energy without gravity', () {
    final sim = ConfettiSimulation(gravity: Vec3.zero);
    addTearDown(sim.dispose);
    sim.emit(
      effect(
        speed: 4,
        particle: const RibbonParticle(
          length: NumberRange.fixed(1.5),
          width: NumberRange.fixed(.03),
          segments: 24,
          damping: 0,
          angularSpeed: NumberRange.fixed(3),
        ),
      ),
    );
    final birth = sim.snapshot.single;
    final initialEnergy = birth.kineticEnergy! + birth.elasticEnergy!;
    for (var i = 0; i < 180; i++) {
      sim.advance(elapsedForFrame(i, 120));
      final p = sim.snapshot.single;
      expect(
        p.kineticEnergy! + p.elasticEnergy!,
        lessThan(initialEnergy * 1.01),
      );
    }
    expect(sim.snapshot.single.kineticEnergy!, lessThan(birth.kineticEnergy!));
  });

  test(
    'internal damping preserves resultant momentum including rigid spin',
    () {
      final results = <ParticleSnapshot>[];
      for (final damping in [0.0, 20.0]) {
        final sim = ConfettiSimulation(gravity: Vec3.zero);
        sim.emit(
          effect(
            speed: 0,
            particle: RibbonParticle(
              length: const NumberRange.fixed(2),
              width: const NumberRange.fixed(.025),
              segments: 20,
              damping: damping,
              dragCoefficient: 0,
              surfaceFriction: 0,
              angularSpeed: const NumberRange.fixed(2),
            ),
          ),
        );
        sim.advance(elapsedForFrame(0, 120));
        results.add(sim.snapshot.single);
        sim.dispose();
      }
      expect(
        (results[0].velocity - results[1].velocity).length,
        lessThan(1e-10),
      );
      expect(
        (results[0].angularMomentum! - results[1].angularMomentum!).length,
        lessThan(1e-10),
      );
    },
  );
}

import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'time_helpers.dart';

ConfettiEffect effect({
  ConfettiParticle particle = const PaperParticle.noBend(),
  Vec3 origin = Vec3.zero,
  Vec3 direction = const Vec3(0, -1, 0),
  double speed = 5,
  Duration lifetime = const Duration(seconds: 6),
  int count = 1,
  int seed = 12,
}) => ConfettiEffect(
  seed: seed,
  emitters: [
    ConfettiEmitter.burst(
      particles: [ParticleChoice(particle: particle)],
      origin: origin,
      direction: direction,
      speed: NumberRange.fixed(speed),
      spread: 0,
      lifetime: ParticleLifetime(duration: DurationRange.fixed(lifetime)),
      burstCount: count,
    ),
  ],
);

void main() {
  test('rejects invalid values before starting a release-mode simulation', () {
    expect(
      () => ConfettiEmitter.burst(
        particles: [],
        direction: Vec3.zero,
        burstCount: 50,
      ),
      throwsArgumentError,
    );
    expect(
      () => ParticleChoice(particle: const RibbonParticle(segments: 2)),
      throwsArgumentError,
    );
    expect(
      () => ParticleChoice(
        particle: const PaperParticle.noBend(
          size: PaperSize.stretched(
            width: NumberRange(1, .1),
            height: const NumberRange(.035, .075),
          ),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => ParticleChoice(
        particle: const RibbonParticle(torsionalStiffness: -1),
      ),
      throwsArgumentError,
    );
    expect(
      () => WindSource.global(velocity: const Vec3(double.nan, 0, 0)),
      throwsArgumentError,
    );
  });

  test(
    'fixed-step births and motion are independent of caller frame partitions',
    () {
      final a = ConfettiSimulation(wind: WindField(turbulence: .3));
      final b = ConfettiSimulation(wind: WindField(turbulence: .3));
      final mixed = ConfettiEffect(
        seed: 84,
        emitters: [
          ConfettiEmitter.stream(
            particles: [
              ParticleChoice(particle: const PaperParticle.noBend(), weight: 2),
              ParticleChoice(particle: const RibbonParticle(segments: 8)),
            ],
            burstCount: 5,
            rate: 5,
            duration: const Duration(seconds: 1),
            lifetime: const ParticleLifetime(
              duration: DurationRange.fixed(Duration(seconds: 6)),
            ),
          ),
        ],
      );
      a.emit(mixed);
      b.emit(mixed);
      a.advance(const Duration(seconds: 2));
      for (var i = 0; i < 60; i++) {
        b.advance(elapsedForFrame(i, 30));
      }
      expect(a.snapshot.length, 10);
      expect(b.snapshot.length, a.snapshot.length);
      for (var i = 0; i < a.snapshot.length; i++) {
        expect(
          (a.snapshot[i].position - b.snapshot[i].position).length,
          lessThan(1e-9),
        );
      }
      a.dispose();
      b.dispose();
    },
  );

  test(
    'delayed births exist at their due boundary without premature motion',
    () {
      final simulation = ConfettiSimulation(gravity: Vec3.zero);
      simulation.emit(
        ConfettiEffect(
          emitters: [
            ConfettiEmitter.burst(
              particles: [
                ParticleChoice(
                  particle: const PaperParticle.noBend(
                    dragCoefficient: 0,
                    surfaceFriction: 0,
                  ),
                ),
              ],
              origin: const Vec3(1, 2, 3),
              direction: const Vec3(1, 0, 0),
              speed: const NumberRange.fixed(2),
              spread: 0,
              burstCount: 1,
              delay: const Duration(milliseconds: 100),
            ),
          ],
        ),
      );
      simulation.advance(const Duration(milliseconds: 100));
      expect(simulation.snapshot.single.age, Duration.zero);
      expect(simulation.snapshot.single.position, const Vec3(1, 2, 3));
      simulation.advance(elapsedForFrame(0, 120));
      expect(simulation.snapshot.single.position.x, closeTo(1 + 2 / 120, 1e-9));
      simulation.dispose();
    },
  );

  test(
    'gravity is applied once and ballistic motion matches the fixed-step solution',
    () {
      final simulation = ConfettiSimulation();
      simulation.emit(
        effect(
          particle: const PaperParticle.noBend(
            dragCoefficient: 0,
            surfaceFriction: 0,
          ),
        ),
      );
      simulation.advance(const Duration(seconds: 1));
      final particle = simulation.snapshot.single;
      expect(particle.velocity.y, closeTo(4.81, 1e-8));
      expect(particle.position.y, closeTo(-5 + 9.81 / 2, 1e-8));
      expect(particle.position.x, closeTo(0, 1e-9));
      simulation.dispose();
    },
  );

  test(
    'wind sources combine before response and turbulence varies along Z',
    () {
      final field = WindField(
        sources: [
          WindSource.global(velocity: const Vec3(2, -1, 3), variation: 0),
          WindSource.global(velocity: const Vec3(-2, 1, -3), variation: 0),
        ],
      );
      expect(
        field
            .velocityAt(const Vec3(.2, .5, 1), const Duration(seconds: 3))
            .length,
        closeTo(0, 1e-10),
      );
      final turbulent = WindField(turbulence: 1, seed: 3);
      final front = turbulent.velocityAt(
        const Vec3(.2, .5, 1),
        const Duration(seconds: 3),
      );
      final back = turbulent.velocityAt(
        const Vec3(.2, .5, -1),
        const Duration(seconds: 3),
      );
      expect((front - back).length, greaterThan(.05));
      final nearby = turbulent.velocityAt(
        const Vec3(.20001, .5, 1),
        const Duration(microseconds: 3000010),
      );
      expect((front - nearby).length, lessThan(.001));
    },
  );

  test('depth wind changes Z motion and apparent size', () {
    final simulation = ConfettiSimulation(
      gravity: Vec3.zero,
      wind: WindField(
        sources: [
          WindSource.global(velocity: const Vec3(0, 0, 3), variation: 0),
        ],
      ),
    );
    simulation.emit(effect(speed: 0, origin: const Vec3(.5, 0, 0)));
    simulation.advance(const Duration(seconds: 1));
    final particle = simulation.snapshot.single;
    expect(particle.position.z, greaterThan(.2));
    expect(particle.velocity.z, greaterThan(0));
    const camera = ConfettiCamera();
    const viewport = Size(500, 500);
    expect(
      camera.project(particle.position, viewport)!.dx,
      greaterThan(camera.project(const Vec3(.5, 0, 0), viewport)!.dx),
    );
    simulation.dispose();
  });

  test('ribbon free flight preserves lengths and fixed material midpoint', () {
    const recipe = RibbonParticle(
      width: NumberRange.fixed(.025),
      length: NumberRange.fixed(.7),
      segments: 12,
    );
    final simulation = ConfettiSimulation(
      wind: WindField(
        sources: [WindSource.global(velocity: const Vec3(.8, 0, .6))],
        turbulence: .2,
      ),
    );
    simulation.emit(effect(particle: recipe, speed: 3));
    final birth = simulation.snapshot.single;
    expect(birth.nodes.first, Vec3.zero);
    var maximumLengthError = 0.0;
    for (var i = 0; i < 300; i++) {
      simulation.advance(elapsedForFrame(i, 120));
      final particle = simulation.snapshot.single;
      expect(particle.position.isFinite && particle.velocity.isFinite, isTrue);
      for (var j = 1; j < particle.nodes.length; j++) {
        final error =
            ((particle.nodes[j] - particle.nodes[j - 1]).length - .7 / 12)
                .abs();
        if (error > maximumLengthError) maximumLengthError = error;
      }
    }
    expect(maximumLengthError, lessThan(.7 / 12 * .01));
    simulation.dispose();
  });

  test('internal constraints do not add centroid acceleration in vacuum', () {
    final falling = ConfettiSimulation();
    final free = ConfettiSimulation(gravity: Vec3.zero);
    const recipe = RibbonParticle(
      dragCoefficient: 0,
      surfaceFriction: 0,
      angularSpeed: NumberRange.fixed(0),
      length: NumberRange.fixed(.6),
      width: NumberRange.fixed(.02),
    );
    falling.emit(effect(particle: recipe));
    free.emit(effect(particle: recipe));
    falling.advance(const Duration(milliseconds: 500));
    free.advance(const Duration(milliseconds: 500));
    expect(
      (falling.snapshot.single.velocity -
              free.snapshot.single.velocity -
              const Vec3(0, 4.905, 0))
          .length,
      lessThan(1e-6),
    );
    falling.dispose();
    free.dispose();
  });

  test('ribbon mass is independent of segment resolution', () {
    final a = ConfettiSimulation(gravity: Vec3.zero);
    final b = ConfettiSimulation(gravity: Vec3.zero);
    a.emit(
      effect(
        particle: const RibbonParticle(
          segments: 8,
          width: NumberRange.fixed(.02),
          length: NumberRange.fixed(.6),
        ),
      ),
    );
    b.emit(
      effect(
        particle: const RibbonParticle(
          segments: 24,
          width: NumberRange.fixed(.02),
          length: NumberRange.fixed(.6),
        ),
      ),
    );
    a.advance(const Duration(milliseconds: 500));
    b.advance(const Duration(milliseconds: 500));
    expect(a.snapshot.single.mass!, closeTo(b.snapshot.single.mass!, 1e-12));
    a.dispose();
    b.dispose();
  });

  test(
    'stop-generation and cancellation are scoped to their particles',
    () async {
      final simulation = ConfettiSimulation();
      final stream = ConfettiEffect(
        emitters: [
          ConfettiEmitter.stream(
            particles: [ParticleChoice(particle: const PaperParticle.noBend())],
            burstCount: 0,
            rate: 10,
            duration: const Duration(seconds: 2),
            lifetime: const ParticleLifetime(
              duration: DurationRange.fixed(Duration(milliseconds: 200)),
            ),
          ),
        ],
      );
      final first = simulation.emit(stream);
      final second = simulation.emit(stream);
      simulation.advance(const Duration(milliseconds: 400));
      first.stopEmission();
      simulation.advance(const Duration(milliseconds: 600));
      expect(await first.done, ConfettiCompletion.completed);
      expect(second.isComplete, isFalse);
      second.cancel();
      expect(await second.done, ConfettiCompletion.cancelled);
      expect(simulation.isIdle, isTrue);
      simulation.dispose();
    },
  );

  test(
    'capacity is bounded and geometry is released at lifetime completion',
    () async {
      final simulation = ConfettiSimulation(
        limits: const ConfettiLimits(particles: 3, ribbonSegments: 28),
      );
      final handle = simulation.emit(
        effect(count: 30, lifetime: const Duration(milliseconds: 100)),
      );
      expect(simulation.stats.particles, 3);
      expect(simulation.stats.droppedParticles, 27);
      simulation.advance(const Duration(milliseconds: 200));
      expect(handle.isComplete, isTrue);
      expect(simulation.stats.livingParticles, 0);
      expect(await handle.done, ConfettiCompletion.completed);
      expect(simulation.stats.particles, 0);
      simulation.emit(effect(count: 3));
      expect(simulation.stats.particles, 3);
      simulation.dispose();
    },
  );
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'optimization_test.dart' show draw, nontransparent;

ConfettiEffect streak({
  StreakParticle particle = const StreakParticle(airResistance: 0),
  Vec3 origin = Vec3.zero,
  Vec3 direction = Vec3.right,
  double speed = 8,
  Duration lifetime = const Duration(seconds: 2),
  int count = 1,
}) => ConfettiEffect(
  emitters: [
    ConfettiEmitter.burst(
      origin: origin,
      direction: direction,
      speed: NumberRange.fixed(speed),
      spread: 0,
      burstCount: count,
      lifetime: ParticleLifetime(
        duration: DurationRange.fixed(lifetime),
        fadeOut: Duration.zero,
      ),
      particles: [
        ParticleChoice(
          particle: particle,
          colors: const [ui.Color(0xffffcc44)],
        ),
      ],
    ),
  ],
);

ConfettiSimulation simulation({Vec3 gravity = Vec3.zero, WindField? wind}) {
  final sim = ConfettiSimulation(gravity: gravity, wind: wind ?? WindField());
  addTearDown(sim.dispose);
  return sim;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('streak recipes validate independent visual and motion parameters', () {
    for (final particle in const [
      StreakParticle(width: NumberRange.fixed(0)),
      StreakParticle(width: NumberRange.fixed(double.infinity)),
      StreakParticle(width: NumberRange(.1, .01)),
      StreakParticle(airResistance: -1),
      StreakParticle(airResistance: double.nan),
      StreakParticle(airResistance: 61),
    ]) {
      expect(() => ParticleChoice(particle: particle), throwsArgumentError);
    }
    expect(
      ParticleChoice(particle: const StreakParticle()).particle,
      isNot(isA<MaterialParticle>()),
    );
    expect(const PaperParticle.noBend(), isA<MaterialParticle>());
    expect(const RibbonParticle(), isA<MaterialParticle>());
  });

  test(
    'point motion obeys gravity and exact constant XYZ airflow response',
    () {
      const gravity = Vec3(1, 3, -2),
          air = Vec3(-2, 1, 4),
          initial = Vec3(8, 0, 0);
      for (final resistance in [0.0, 1e-10, 2.0, 60.0]) {
        final sim = simulation(
          gravity: gravity,
          wind: WindField(
            sources: [WindSource.global(velocity: air, variation: 0)],
          ),
        );
        sim.emit(streak(particle: StreakParticle(airResistance: resistance)));
        sim.advance(const Duration(milliseconds: 500));
        final p = sim.snapshot.single;
        final Vec3 expectedSpeed, expectedPosition;
        if (resistance < 1e-8) {
          expectedSpeed = initial + gravity * .5;
          expectedPosition = initial * .5 + gravity * .125;
        } else {
          final terminal = air + gravity / resistance;
          final decay = math.exp(-resistance * .5);
          expectedSpeed = terminal + (initial - terminal) * decay;
          expectedPosition =
              terminal * .5 + (initial - terminal) * ((1 - decay) / resistance);
        }
        expect((p.velocity - expectedSpeed).length, lessThan(1e-8));
        expect((p.position - expectedPosition).length, lessThan(1e-8));
        expect(p.mass, isNull);
        expect(p.area, isNull);
        expect(p.kineticEnergy, isNull);
        expect(p.materialPosition, isNull);
        expect(p.nodes, isEmpty);
      }
    },
  );

  test(
    'spatial wind and fixed-step partitioning preserve deterministic point motion',
    () {
      final field = WindField(
        sources: [
          WindSource.local(
            velocity: const Vec3(-2, 3, 4),
            center: Vec3.zero,
            radius: 3,
          ),
          WindSource.global(velocity: const Vec3(1, -2, .5)),
        ],
        turbulence: .3,
        seed: 9,
      );
      final a = simulation(wind: field), b = simulation(wind: field);
      for (final sim in [a, b])
        sim.emit(streak(particle: const StreakParticle(), count: 8));
      a.advance(const Duration(milliseconds: 500));
      for (var i = 0; i < 50; i++) b.advance(const Duration(milliseconds: 10));
      for (var i = 0; i < a.snapshot.length; i++) {
        expect(a.snapshot[i].position, b.snapshot[i].position);
        expect(a.snapshot[i].velocity, b.snapshot[i].velocity);
        expect(a.snapshot[i].streakLength, b.snapshot[i].streakLength);
      }
      expect(a.snapshot.first.position.z.abs(), greaterThan(.001));
    },
  );

  test(
    'constant-speed streak expands retracts and completes exactly within lifetime',
    () async {
      final sim = simulation();
      final handle = sim.emit(
        streak(lifetime: const Duration(milliseconds: 260)),
      );
      expect(sim.snapshot.single.streakLength, 0);
      sim.advance(const Duration(milliseconds: 25));
      final expanding = sim.snapshot.single.streakLength!;
      sim.advance(const Duration(milliseconds: 100));
      final full = sim.snapshot.single.streakLength!;
      sim.advance(const Duration(milliseconds: 100));
      final shrinking = sim.snapshot.single.streakLength!;
      expect(full, greaterThan(expanding));
      expect(full, greaterThan(shrinking));
      expect(sim.snapshot.single.velocity, const Vec3(8, 0, 0));
      sim.advance(const Duration(milliseconds: 42));
      expect(await handle.done, ConfettiCompletion.completed);
      expect(sim.stats.streakParticles, 0);
      expect(sim.isIdle, isTrue);
      expect(nontransparent((await draw(sim)).$1), 0);
    },
  );

  test(
    'projected speed gates visibility and camera changes cannot stretch a stationary point',
    () async {
      var lastAlpha = 0;
      for (final speed in [0.0, 2.0, 3.75, 5.0, 6.5, 8.0]) {
        final sim = simulation();
        sim.emit(streak(speed: speed, origin: Vec3(-speed * .2, 0, 0)));
        sim.advance(const Duration(milliseconds: 200));
        final (pixels, stats) = await draw(sim);
        if (speed <= 3.75) {
          expect(stats.streaks, 0);
          expect(nontransparent(pixels), 0);
        } else {
          final alpha = [
            for (var i = 3; i < pixels.length; i += 4) pixels[i],
          ].fold(0, (a, b) => a + b);
          expect(alpha, greaterThan(lastAlpha));
          lastAlpha = alpha;
          expect(stats.streaks, 1);
        }
        if (speed == 0) {
          expect(
            nontransparent(
              (await draw(
                sim,
                camera: const ConfettiCamera(viewHeight: .2),
              )).$1,
            ),
            0,
          );
        }
      }
    },
  );

  test(
    'solid core retains width and opacity while only the final section tapers',
    () async {
      final sim = simulation();
      sim.emit(
        streak(
          origin: const Vec3(-1.6, 0, 0),
          particle: const StreakParticle(
            width: NumberRange.fixed(.2),
            airResistance: 0,
          ),
        ),
      );
      sim.advance(const Duration(milliseconds: 200));
      final (pixels, stats) = await draw(sim);
      final length = sim.snapshot.single.streakLength! * 320 / 6;
      int alpha(double fraction, int row) =>
          pixels[(row * 480 + (240 - length * fraction).floor()) * 4 + 3];
      int solidWidth(double fraction) => [
        for (var y = 0; y < 320; y++)
          if (alpha(fraction, y) > 200) y,
      ].length;
      expect(alpha(.2, 160), greaterThan(240));
      expect(alpha(.5, 160), greaterThan(240));
      expect(solidWidth(.5) / solidWidth(.2), greaterThan(.8));
      expect(alpha(.88, 160), lessThan(100));
      expect(stats.drawCalls, 1);
    },
  );

  test(
    'higher speed automatically softens edges while retaining a solid core',
    () async {
      final counts = <int>[];
      for (final speed in [8.0, 32.0]) {
        final sim = simulation();
        sim.emit(
          streak(
            speed: speed,
            origin: Vec3(-speed * .2, 0, 0),
            particle: const StreakParticle(
              width: NumberRange.fixed(.1),
              airResistance: 0,
            ),
          ),
        );
        sim.advance(const Duration(milliseconds: 200));
        final (pixels, _) = await draw(sim);
        // 只比较头部附近同一截面，避免把更长色带的像素数误当成更宽柔边。
        counts.add(
          [
            for (var y = 0; y < 320; y++)
              if (pixels[(y * 480 + 230) * 4 + 3] > 0) y,
          ].length,
        );
        expect(pixels[(160 * 480 + 230) * 4 + 3], greaterThan(240));
      }
      expect(counts.last, greaterThan(counts.first));
    },
  );

  test(
    'length follows speed without a fixed world cap and recedes under air resistance',
    () async {
      final lengths = <double>[];
      for (final speed in [8.0, 16.0, 32.0]) {
        final sim = simulation();
        sim.emit(streak(speed: speed));
        sim.advance(const Duration(milliseconds: 125));
        lengths.add(sim.snapshot.single.streakLength!);
      }
      expect(lengths[1], closeTo(lengths[0] * 2, 1e-9));
      expect(lengths[2], closeTo(lengths[1] * 2, 1e-9));
      expect(lengths.last, greaterThan(2.4));
      final sim = simulation();
      sim.emit(
        streak(speed: 24, particle: const StreakParticle(airResistance: 12)),
      );
      sim.advance(const Duration(milliseconds: 50));
      final fast = sim.snapshot.single.streakLength!;
      expect(nontransparent((await draw(sim)).$1), greaterThan(0));
      sim.advance(const Duration(milliseconds: 150));
      expect(sim.snapshot.single.streakLength, lessThan(fast));
      expect(sim.stats.streakParticles, 1);
      expect(nontransparent((await draw(sim)).$1), 0);
    },
  );

  test(
    'automatic visibility is consistent across proportional viewport sizes',
    () {
      for (final speed in [3.0, 5.0, 8.0]) {
        final sim = simulation();
        sim.emit(streak(speed: speed, origin: Vec3(-speed * .2, 0, 0)));
        sim.advance(const Duration(milliseconds: 200));
        final counts = <int>[];
        for (final size in const [ui.Size(480, 320), ui.Size(960, 640)]) {
          final painter = ConfettiPainter(
            simulation: sim,
            camera: const ConfettiCamera(viewHeight: 6),
          );
          final recorder = ui.PictureRecorder();
          painter.paint(ui.Canvas(recorder), size);
          recorder.endRecording().dispose();
          counts.add(painter.stats.streaks);
        }
        expect(counts[0], speed < 3.75 ? 0 : 1);
        expect(counts[1], counts[0]);
      }
    },
  );

  test(
    'near and far crossings remain visible and finite without path history',
    () async {
      for (final scene in [
        (
          const Vec3(.1, 0, 8.1),
          Vec3.forward,
          const Duration(milliseconds: 125),
          const ConfettiCamera(viewHeight: 6),
        ),
        (
          const Vec3(.5, 0, .7),
          const Vec3(0, 0, -1),
          const Duration(milliseconds: 125),
          const ConfettiCamera(viewHeight: 1, far: 11),
        ),
      ]) {
        final sim = simulation();
        sim.emit(
          streak(
            origin: scene.$1,
            direction: scene.$2,
            speed: 16,
            particle: const StreakParticle(
              width: NumberRange.fixed(.02),
              airResistance: 0,
            ),
          ),
        );
        sim.advance(scene.$3);
        final (pixels, stats) = await draw(sim, camera: scene.$4);
        expect(nontransparent(pixels), greaterThan(0));
        expect(stats.triangles, lessThanOrEqualTo(140));
        expect(sim.stats.invalidParticles, 0);
      }
      final sim = simulation();
      sim.emit(streak(direction: Vec3.forward));
      sim.advance(const Duration(milliseconds: 200));
      expect(nontransparent((await draw(sim)).$1), 0);
    },
  );

  test(
    'many streaks use bounded native batches and rendering leaves motion unchanged',
    () async {
      final sim = simulation();
      sim.emit(streak(count: 400, origin: const Vec3(-1.6, 0, 0)));
      sim.advance(const Duration(milliseconds: 200));
      final before = sim.snapshot.first;
      final (_, stats) = await draw(sim);
      expect(sim.stats.particles, 400);
      expect(sim.stats.paperTriangles, 0);
      expect(stats.streaks, 400);
      expect(stats.triangles, lessThanOrEqualTo(400 * 70));
      expect(stats.drawCalls, lessThan(10));
      expect(sim.snapshot.first.position, before.position);
      expect(sim.snapshot.first.streakLength, before.streakLength);
    },
  );

  test(
    'stream stop and cancellation share ownership with material emitters',
    () async {
      final sim = simulation();
      final short = sim.emit(
        ConfettiEffect(
          emitters: [
            ConfettiEmitter.stream(
              rate: 20,
              duration: const Duration(seconds: 1),
              burstCount: 1,
              lifetime: const ParticleLifetime(
                duration: DurationRange.fixed(Duration(milliseconds: 100)),
              ),
              particles: [ParticleChoice(particle: const StreakParticle())],
            ),
          ],
        ),
      );
      final long = sim.emit(
        ConfettiEffect(
          emitters: [
            ConfettiEmitter.burst(
              burstCount: 1,
              particles: [
                ParticleChoice(particle: const PaperParticle.noBend()),
              ],
            ),
          ],
        ),
      );
      sim.advance(const Duration(milliseconds: 100));
      short.stopEmission();
      sim.advance(const Duration(milliseconds: 110));
      expect(await short.done, ConfettiCompletion.completed);
      expect(sim.stats.streakParticles, 0);
      expect(sim.stats.particles, 1);
      long.cancel();
      expect(await long.done, ConfettiCompletion.cancelled);
      expect(sim.isIdle, isTrue);
    },
  );
}

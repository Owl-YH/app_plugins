import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'optimization_test.dart' show draw;

const _paper = PaperParticle.noBend(
  size: PaperSize.proportional(NumberRange.fixed(.3)),
  dragCoefficient: 0,
  surfaceFriction: 0,
  angularSpeed: NumberRange.fixed(0),
);
const _ribbon = RibbonParticle(
  width: NumberRange.fixed(.1),
  length: NumberRange.fixed(.4),
  segments: 4,
  dragCoefficient: 0,
  surfaceFriction: 0,
  angularSpeed: NumberRange.fixed(0),
);

ConfettiSimulation _scene(
  ParticleLifetime lifetime, {
  ConfettiParticle particle = _paper,
}) {
  final sim = ConfettiSimulation(gravity: Vec3.zero);
  sim.emit(
    ConfettiEffect(
      seed: 12,
      emitters: [
        ConfettiEmitter.burst(
          particles: [
            ParticleChoice(
              particle: particle,
              colors: const [Color(0xb3ffcc55)],
            ),
          ],
          burstCount: 1,
          speed: const NumberRange.fixed(0),
          lifetime: lifetime,
        ),
      ],
    ),
  );
  return sim;
}

int _alpha(Uint8List pixels) {
  var result = 0;
  for (var i = 3; i < pixels.length; i += 4) result += pixels[i];
  return result;
}

Future<void> _expectEnvelope(
  ParticleLifetime lifetime,
  List<(int, double)> samples, {
  ConfettiParticle particle = _paper,
}) async {
  final sim = _scene(lifetime, particle: particle);
  final reference = _scene(
    ParticleLifetime(duration: lifetime.duration, fadeOut: Duration.zero),
    particle: particle,
  );
  addTearDown(sim.dispose);
  addTearDown(reference.dispose);
  var previous = 0;
  for (final (milliseconds, expected) in samples) {
    final delta = Duration(milliseconds: milliseconds - previous);
    sim.advance(delta);
    reference.advance(delta);
    previous = milliseconds;
    final actual = _alpha(
      (await draw(sim, camera: const ConfettiCamera(viewHeight: 1))).$1,
    );
    if (expected == 0) {
      expect(actual, 0, reason: 'at $milliseconds ms');
    } else {
      final full = _alpha(
        (await draw(reference, camera: const ConfettiCamera(viewHeight: 1))).$1,
      );
      expect(full, greaterThan(1000));
      expect(
        actual / full,
        closeTo(expected, .015),
        reason: 'at $milliseconds ms',
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lifetime validates typed fades at both emitter constructors', () {
    const defaults = ParticleLifetime();
    expect(defaults.fadeIn, Duration.zero);
    expect(defaults.fadeOut, const Duration(milliseconds: 350));
    final choices = [ParticleChoice(particle: _paper)];
    for (final invalid in const [
      ParticleLifetime(fadeIn: Duration(microseconds: -1)),
      ParticleLifetime(fadeOut: Duration(microseconds: -1)),
      ParticleLifetime(fadeIn: Duration(microseconds: 60000001)),
      ParticleLifetime(fadeOut: Duration(microseconds: 60000001)),
    ]) {
      expect(
        () => ConfettiEmitter.burst(
          particles: choices,
          burstCount: 1,
          lifetime: invalid,
        ),
        throwsArgumentError,
      );
      expect(
        () => ConfettiEmitter.stream(
          particles: choices,
          rate: 1,
          duration: const Duration(seconds: 1),
          lifetime: invalid,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => ConfettiEmitter.burst(
        particles: choices,
        burstCount: 1,
        lifetime: const ParticleLifetime(
          fadeIn: Duration(seconds: 60),
          fadeOut: Duration(seconds: 60),
        ),
      ),
      returnsNormally,
    );
  });

  for (final particle in [_paper, _ribbon]) {
    test(
      '${particle.runtimeType} renders fade-in hold fade-out and original color alpha',
      () async {
        await _expectEnvelope(
          const ParticleLifetime(
            duration: DurationRange.fixed(Duration(seconds: 2)),
            fadeIn: Duration(milliseconds: 500),
            fadeOut: Duration(milliseconds: 500),
          ),
          [(0, 0), (250, .5), (500, 1), (1500, 1), (1750, .5), (2000, 0)],
          particle: particle,
        );
      },
    );
  }

  test(
    'short lifetimes proportionally fit both windows with no dim overlap',
    () async {
      await _expectEnvelope(
        const ParticleLifetime(
          duration: DurationRange.fixed(Duration(milliseconds: 600)),
          fadeIn: Duration(seconds: 1),
          fadeOut: Duration(seconds: 2),
        ),
        [(0, 0), (100, .5), (200, 1), (400, .5), (600, 0)],
      );
    },
  );

  test(
    'zero durations disable each transition and default short fade ends on time',
    () async {
      await _expectEnvelope(
        const ParticleLifetime(
          duration: DurationRange.fixed(Duration(milliseconds: 100)),
          fadeOut: Duration.zero,
        ),
        [(0, 1), (50, 1), (100, 0)],
      );
      await _expectEnvelope(
        const ParticleLifetime(
          duration: DurationRange.fixed(Duration(milliseconds: 100)),
        ),
        [(0, 1), (50, .5), (100, 0)],
      );
      await _expectEnvelope(
        const ParticleLifetime(
          duration: DurationRange.fixed(Duration(milliseconds: 200)),
          fadeIn: Duration(milliseconds: 100),
          fadeOut: Duration.zero,
        ),
        [(0, 0), (50, .5), (100, 1), (150, 1), (200, 0)],
      );
    },
  );

  test(
    'delayed births start their own fade without using effect age',
    () async {
      final sim = ConfettiSimulation(gravity: Vec3.zero);
      addTearDown(sim.dispose);
      sim.emit(
        ConfettiEffect(
          emitters: [
            ConfettiEmitter.burst(
              particles: [ParticleChoice(particle: _paper)],
              burstCount: 1,
              speed: const NumberRange.fixed(0),
              delay: const Duration(seconds: 1),
              lifetime: const ParticleLifetime(
                fadeIn: Duration(milliseconds: 500),
              ),
            ),
          ],
        ),
      );
      sim.advance(const Duration(seconds: 1));
      expect(sim.snapshot.single.age, Duration.zero);
      expect(_alpha((await draw(sim)).$1), 0);
      sim.advance(const Duration(milliseconds: 250));
      expect(_alpha((await draw(sim)).$1), greaterThan(0));
    },
  );

  test(
    'fades preserve sampled lifetimes seeded motion and release of stream resources',
    () async {
      final a = ConfettiSimulation(), b = ConfettiSimulation();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      ConfettiPlayback start(ConfettiSimulation sim, bool fades) => sim.emit(
        ConfettiEffect(
          seed: 51,
          emitters: [
            ConfettiEmitter.stream(
              particles: [
                ParticleChoice(particle: const PaperParticle.noBend()),
                ParticleChoice(particle: const RibbonParticle(segments: 4)),
              ],
              burstCount: 1,
              rate: 4,
              duration: const Duration(seconds: 1),
              delay: const Duration(milliseconds: 250),
              lifetime: ParticleLifetime(
                duration: const DurationRange(
                  Duration(seconds: 1),
                  Duration(seconds: 2),
                ),
                fadeIn: fades ? const Duration(seconds: 1) : Duration.zero,
                fadeOut: fades ? const Duration(seconds: 1) : Duration.zero,
              ),
            ),
          ],
        ),
      );
      final pa = start(a, true), pb = start(b, false);
      for (var frame = 0; frame < 20; frame++) {
        a.advance(const Duration(milliseconds: 250));
        b.advance(const Duration(milliseconds: 250));
        final sa = a.snapshot, sb = b.snapshot;
        expect(sa.length, sb.length);
        for (var i = 0; i < sa.length; i++) {
          expect(sa[i].lifetime, sb[i].lifetime);
          expect(sa[i].age, sb[i].age);
          expect(sa[i].nodes, sb[i].nodes);
          expect(sa[i].velocity, sb[i].velocity);
          expect(sa[i].width, sb[i].width);
        }
      }
      expect(await pa.done, ConfettiCompletion.completed);
      expect(await pb.done, ConfettiCompletion.completed);
      expect(a.stats.birthAttempts, 5);
      expect(a.stats.particles, 0);
      expect(a.stats.playbacks, 0);
      expect(a.stats.paperTriangles, 0);
      expect(a.stats.ribbonSegments, 0);
    },
  );
}

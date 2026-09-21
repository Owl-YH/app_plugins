import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'simulation_test.dart' show effect;
import 'time_helpers.dart';

Future<(Uint8List, ConfettiRenderStats)> draw(
  ConfettiSimulation simulation, {
  ConfettiCamera camera = const ConfettiCamera(viewHeight: 6),
}) async {
  final painter = ConfettiPainter(simulation: simulation, camera: camera);
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), const ui.Size(480, 320));
  final picture = recorder.endRecording();
  // Native vertices have already been disposed; the recorded picture must survive.
  final image = await picture.toImage(480, 320);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = Uint8List.fromList(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  return (pixels, painter.stats);
}

int nontransparent(Uint8List pixels) {
  var count = 0;
  for (var i = 3; i < pixels.length; i += 4) {
    if (pixels[i] != 0) count++;
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'one batch retains transparent front-to-back color relationships',
    () async {
      final sim = ConfettiSimulation(gravity: Vec3.zero);
      for (final entry in [
        (1.0, const ui.Color(0x80ff0000)),
        (-1.0, const ui.Color(0x800000ff)),
      ]) {
        sim.emit(
          ConfettiEffect(
            emitters: [
              ConfettiEmitter.burst(
                particles: [
                  ParticleChoice(
                    colors: [entry.$2],
                    particle: const PaperParticle.noBend(
                      size: PaperSize.stretched(
                        width: NumberRange.fixed(.5),
                        height: NumberRange.fixed(.5),
                      ),
                    ),
                  ),
                ],
                origin: Vec3(0, 0, entry.$1),
                burstCount: 1,
                speed: const NumberRange.fixed(0),
              ),
            ],
          ),
        );
      }
      final (pixels, stats) = await draw(sim);
      final center = (160 * 480 + 240) * 4;
      expect(pixels[center], greaterThan(pixels[center + 2]));
      expect(stats.drawCalls, 1);
      expect(stats.visibleParticles, 2);
      sim.dispose();
    },
  );

  test(
    'extreme burst is rejected in aggregate once particle capacity is full',
    () {
      final recipe = ParticleChoice(particle: const PaperParticle.noBend());
      final sim = ConfettiSimulation(
        limits: const ConfettiLimits(particles: 1),
      );
      sim.emit(
        ConfettiEffect(
          emitters: List.generate(
            32,
            (_) => ConfettiEmitter.burst(
              particles: List.filled(64, recipe),
              burstCount: 10000,
            ),
          ),
        ),
      );
      expect(sim.stats.livingParticles, 1);
      expect(sim.stats.droppedParticles, 319999);
      expect(sim.stats.capacityRejections, 319999);
      expect(sim.stats.birthAttempts, 1);
      sim.dispose();
    },
  );

  test(
    'same-step emits and clear share quota, dropped bursts do not catch up',
    () async {
      final sim = ConfettiSimulation(
        limits: const ConfettiLimits(birthAttemptsPerStep: 2),
      );
      sim.emit(effect(count: 1));
      sim.emit(effect(count: 3));
      expect(sim.stats.livingParticles, 2);
      expect(sim.stats.workLimitRejections, 2);
      sim.clear();
      final rejected = sim.emit(effect(count: 3));
      expect(await rejected.done, ConfettiCompletion.completed);
      expect(sim.stats.birthAttempts, 2);
      expect(sim.stats.workLimitRejections, 5);
      sim.advance(elapsedForFrame(0, 120));
      expect(sim.stats.livingParticles, 0);
      sim.emit(effect(count: 2));
      expect(sim.stats.livingParticles, 2);
      sim.dispose();
    },
  );

  test('skipped birth ordinals do not perturb later stream particles', () {
    final full = ConfettiSimulation();
    final limited = ConfettiSimulation(
      limits: const ConfettiLimits(birthAttemptsPerStep: 2),
    );
    final recipe = ConfettiEffect(
      seed: 94,
      emitters: [
        ConfettiEmitter.stream(
          particles: [ParticleChoice(particle: const PaperParticle.noBend())],
          burstCount: 100,
          rate: 2,
          duration: const Duration(seconds: 1),
          lifetime: const ParticleLifetime(
            duration: DurationRange.fixed(Duration(milliseconds: 100)),
          ),
        ),
      ],
    );
    full.emit(recipe);
    limited.emit(recipe);
    full.advance(const Duration(milliseconds: 500));
    for (var i = 0; i < 30; i++) {
      limited.advance(elapsedForFrame(i, 60));
    }
    final a = full.snapshot.single, b = limited.snapshot.single;
    expect(a.id, b.id);
    expect(a.width, b.width);
    expect(a.velocity, b.velocity);
    expect(a.position, b.position);
    full.dispose();
    limited.dispose();
  });

  test('unavailable ribbon capacity does not renormalize weighted choices', () {
    final full = ConfettiSimulation();
    final limited = ConfettiSimulation(
      limits: const ConfettiLimits(ribbonSegments: 0),
    );
    final mixed = ConfettiEffect(
      seed: 48,
      emitters: [
        ConfettiEmitter.burst(
          burstCount: 30,
          particles: [
            ParticleChoice(particle: const PaperParticle.noBend()),
            ParticleChoice(particle: const RibbonParticle()),
          ],
        ),
      ],
    );
    full.emit(mixed);
    limited.emit(mixed);
    final paper = full.snapshot
        .where((p) => p.particle is PaperParticle)
        .toList();
    expect(paper.length, greaterThan(0));
    expect(limited.snapshot.map((p) => p.id), paper.map((p) => p.id));
    expect(limited.stats.capacityRejections, 30 - paper.length);
    expect(limited.stats.birthAttempts, 30);
    full.dispose();
    limited.dispose();
  });
}

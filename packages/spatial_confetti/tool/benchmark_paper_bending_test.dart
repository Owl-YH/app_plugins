import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import '../test/simulation_test.dart' show effect;
import '../test/time_helpers.dart';

/// 本机 Flutter test/JIT 的 CPU 成本记录，不能用来承诺真机帧率。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('record flexible and rigid paper CPU costs', () {
    final rows = <Map<String, Object>>[];
    for (final (name, shape) in [
      ('rectangle', const PaperShape.rectangle()),
      ('circle', const PaperShape.circle()),
    ]) {
      for (final rigid in [true, false]) {
        final recipe = rigid
            ? PaperParticle.noBend(shape: shape, )
            : PaperParticle.bend(shape: shape, );
        final sim = ConfettiSimulation(
          wind: WindField(sources: [WindSource.global(velocity: const Vec3(1, 0, .5))]),
        );
        final timer = Stopwatch()..start();
        sim.emit(effect(particle: recipe, count: 64));
        timer.stop();
        final birth = timer.elapsedMicroseconds / 1000;
        final painter = ConfettiPainter(simulation: sim);
        final physics = <double>[], paint = <double>[];
        for (var frame = 0; frame < 144; frame++) {
          timer
            ..reset()
            ..start();
          sim.advance(elapsedForFrame(frame, 120));
          timer.stop();
          if (frame >= 24) physics.add(timer.elapsedMicroseconds / 1000);
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          timer
            ..reset()
            ..start();
          painter.paint(canvas, const ui.Size(390, 844));
          timer.stop();
          if (frame >= 24) paint.add(timer.elapsedMicroseconds / 1000);
          recorder.endRecording().dispose();
        }
        physics.sort();
        paint.sort();
        final row = <String, Object>{
          'shape': name,
          'rigid': rigid,
          'particles': 64,
          'birthMs': birth,
          'physicsP50Ms': physics[60],
          'physicsP95Ms': physics[114],
          'paintP50Ms': paint[60],
          'paintP95Ms': paint[114],
          'invalidParticles': sim.stats.invalidParticles,
          'triangles': painter.stats.triangles,
        };
        rows.add(row);
        stdout.writeln(jsonEncode(row));
        expect(sim.stats.invalidParticles, 0);
        sim.dispose();
      }
    }
    File(
      'docs/assets/paper-bending-cost.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  });
}

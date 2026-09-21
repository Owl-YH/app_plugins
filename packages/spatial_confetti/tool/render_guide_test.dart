import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import '../doc/presets.dart';

/// 使用 flutter test 提供的真实 Flutter 引擎导出素材，不替代粒子求解或绘制。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'render documented presets with the real simulation and painter',
    () async {
      const size = ui.Size(420, 640);
      const fps = 24;
      final root = Directory('build/guide-frames')..createSync(recursive: true);
      final assets = Directory('doc/assets')..createSync(recursive: true);
      const selected = String.fromEnvironment('GUIDE_SCENES');
      final requested = selected
          .split(',')
          .where((id) => id.isNotEmpty)
          .toSet();
      final existingFile = File('${assets.path}/capture.json');
      final existing = requested.isNotEmpty && existingFile.existsSync()
          ? (jsonDecode(existingFile.readAsStringSync()) as List)
                .cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      final report = <Map<String, Object>>[];
      for (final scene in guideScenes(size)) {
        if (requested.isNotEmpty && !requested.contains(scene.id)) {
          report.add(
            Map<String, Object>.from(
              existing.singleWhere((row) => row['id'] == scene.id),
            ),
          );
          continue;
        }
        final directory = Directory('${root.path}/${scene.id}')
          ..createSync(recursive: true);
        final sim = ConfettiSimulation(wind: scene.wind);
        final playback = sim.emit(scene.effect);
        final painter = ConfettiPainter(simulation: sim, camera: scene.camera);
        var peakParticles = 0, peakStreaks = 0;
        var previousElapsed = Duration.zero;
        for (
          var frame = 0;
          frame <=
              (scene.duration.inMicroseconds *
                      fps /
                      Duration.microsecondsPerSecond)
                  .round();
          frame++
        ) {
          final elapsed = Duration(
            microseconds:
                (frame * Duration.microsecondsPerSecond + fps - 1) ~/ fps,
          );
          sim.advance(elapsed - previousElapsed);
          previousElapsed = elapsed;
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          canvas.drawColor(const ui.Color(0xff101827), ui.BlendMode.src);
          painter.paint(canvas, size);
          final picture = recorder.endRecording();
          final image = await picture.toImage(
            size.width.toInt(),
            size.height.toInt(),
          );
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          File(
            '${directory.path}/${frame.toString().padLeft(4, '0')}.png',
          ).writeAsBytesSync(data);
          if (frame ==
              (scene.posterTime.inMicroseconds *
                      fps /
                      Duration.microsecondsPerSecond)
                  .round())
            File('${assets.path}/${scene.id}.png').writeAsBytesSync(data);
          image.dispose();
          picture.dispose();
          if (sim.stats.particles > peakParticles)
            peakParticles = sim.stats.particles;
          if (painter.stats.streaks > peakStreaks)
            peakStreaks = painter.stats.streaks;
        }
        expect(sim.stats.invalidParticles, 0, reason: scene.id);
        expect(sim.stats.droppedParticles, 0, reason: scene.id);
        expect(peakParticles, greaterThan(0), reason: scene.id);
        if (scene.id == 'streak-burst') expect(peakStreaks, greaterThan(0));
        sim.advance(const Duration(seconds: 10));
        expect(await playback.done, ConfettiCompletion.completed);
        report.add({
          'id': scene.id,
          'frames':
              (scene.duration.inMicroseconds *
                      fps /
                      Duration.microsecondsPerSecond)
                  .round() +
              1,
          'fps': fps,
          'width': size.width.toInt(),
          'height': size.height.toInt(),
          'seed': scene.effect.seed,
          'peakParticles': peakParticles,
          'peakStreaks': peakStreaks,
          'droppedParticles': sim.stats.droppedParticles,
          'invalidParticles': sim.stats.invalidParticles,
          'completion': 'completed',
        });
        sim.dispose();
      }
      File(
        '${assets.path}/capture.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

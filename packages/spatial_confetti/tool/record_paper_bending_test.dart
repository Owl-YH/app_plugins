import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import '../test/paper_bending_test.dart' show flexiblePaper, loadPaper, bendingDepth, sheetNormal;
import '../test/time_helpers.dart';

/// 所有坐标来自实际模拟；PNG 由正式 ConfettiPainter 在 Flutter 引擎中绘制。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('record force-driven paper bending and recovery', () async {
    final rows = <Map<String, Object>>[];
    for (final (name, stiffness) in [('soft', .000002), ('standard', .00002), ('stiff', .002)]) {
      final sim = flexiblePaper(bending: stiffness, damping: 10);
      final initial = sim.snapshot.single;
      loadPaper(sim);
      final samples = <Map<String, Object>>[];
      for (var frame = 0; frame <= 69; frame++) {
        if (frame > 0) sim.advance(elapsedForFrame(frame - 1, 60));
        if (frame == 9) sim.setWind(WindField(), transition: Duration.zero);
        final p = sim.snapshot.single;
        final normal = sheetNormal(p), right = p.widthDirections.single;
        final up = normal.cross(right).normalized();
        final r = up.cross(normal).normalized();
        samples.add({
          'time': frame / 60,
          'depth': bendingDepth(p),
          'bendRatio': p.bendRatio!,
          'kinetic': p.kineticEnergy!,
          'elastic': p.elasticEnergy!,
          'vertices': [
            for (final v in p.surfaceVertices)
              [(v - p.position).dot(r), (v - p.position).dot(up), (v - p.position).dot(normal)],
          ],
        });
        if ([0, 6, 9, 30, 69].contains(frame)) {
          const size = ui.Size(320, 320), camera = ConfettiCamera(viewHeight: .24);
          final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
          canvas.drawColor(const ui.Color(0xff101827), ui.BlendMode.src);
          final center = camera.project(p.position, size)!;
          canvas.translate(160 - center.dx, 160 - center.dy);
          ConfettiPainter(simulation: sim, camera: camera).paint(canvas, size);
          final picture = recorder.endRecording(), image = await picture.toImage(320, 320);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          File('docs/assets/paper-$name-$frame.png').writeAsBytesSync(bytes);
          image.dispose();
          picture.dispose();
        }
      }
      expect(sim.stats.invalidParticles, 0);
      rows.add({
        'id': name,
        'bendingStiffness': stiffness,
        'maximumBendRatio': .02,
        'damping': 10,
        'size': .15,
        'massPerArea': .08,
        'gravity': [0, 0, 0],
        'windSpeed': 2,
        'windRadius': .055,
        'windStop': .15,
        'triangles': initial.surfaceTriangles,
        'samples': samples,
      });
      sim.dispose();
    }
    File('docs/assets/paper-bending.json').writeAsStringSync(jsonEncode(rows));
  });
}

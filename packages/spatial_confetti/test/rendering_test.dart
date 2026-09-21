import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'simulation_test.dart' show effect;

Future<Uint8List> raster(
  ConfettiSimulation simulation, {
  String? capture,
}) async {
  final recorder = ui.PictureRecorder();
  ConfettiPainter(
    simulation: simulation,
    camera: const ConfettiCamera(viewHeight: 6),
  ).paint(ui.Canvas(recorder), const ui.Size(480, 320));
  final picture = recorder.endRecording();
  final image = await picture.toImage(480, 320);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  final directory = Platform.environment['CONFETTI_CAPTURE_DIRECTORY'];
  if (directory != null && capture != null) {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$capture.png',
    ).writeAsBytes(png!.buffer.asUint8List());
  }
  image.dispose();
  picture.dispose();
  return bytes;
}

int visiblePixels(Uint8List pixels) {
  var count = 0;
  for (var i = 3; i < pixels.length; i += 4) {
    if (pixels[i] > 0) count++;
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'ribbon refinement is bounded and paint never changes material motion',
    () {
      final sim = ConfettiSimulation();
      addTearDown(sim.dispose);
      sim.emit(
        effect(
          particle: const RibbonParticle(
            length: NumberRange.fixed(2),
            segments: 32,
          ),
        ),
      );
      sim.advance(const Duration(milliseconds: 400));
      final before = sim.snapshot.single;
      for (final height in [6.0, .4]) {
        final painter = ConfettiPainter(
          simulation: sim,
          camera: ConfettiCamera(viewHeight: height),
        );
        final recorder = ui.PictureRecorder();
        painter.paint(ui.Canvas(recorder), const ui.Size(480, 640));
        recorder.endRecording().dispose();
        expect(painter.stats.ribbonSegments, inInclusiveRange(32, 128));
        expect(painter.stats.vertices, lessThanOrEqualTo(40 * 32));
        expect(painter.stats.refinementLimited, lessThanOrEqualTo(128));
        final after = sim.snapshot.single;
        expect(after.nodes, before.nodes);
        expect(after.widthDirections, before.widthDirections);
        expect(after.materialPosition!, before.materialPosition!);
        expect(after.materialVelocity!, before.materialVelocity!);
      }
    },
  );

  test(
    'near-plane crossing clips finite geometry and a body behind the camera is invisible',
    () async {
      final crossing = ConfettiSimulation(gravity: Vec3.zero);
      crossing.emit(
        effect(
          particle: const PaperParticle.noBend(
            size: PaperSize.stretched(
              width: NumberRange.fixed(.5),
              height: NumberRange.fixed(.5),
            ),
          ),
          origin: const Vec3(0, 0, 9.75),
          speed: 0,
        ),
      );
      expect(
        visiblePixels(await raster(crossing, capture: 'near-clip')),
        greaterThan(0),
      );
      final hidden = ConfettiSimulation(gravity: Vec3.zero);
      hidden.emit(effect(origin: const Vec3(0, 0, 11), speed: 0));
      expect(visiblePixels(await raster(hidden)), 0);
      crossing.dispose();
      hidden.dispose();
    },
  );

  test('rendering does not alter world state or material geometry', () async {
    final simulation = ConfettiSimulation(wind: WindField(turbulence: .4));
    simulation.emit(
      effect(
        particle: const RibbonParticle(
          width: NumberRange.fixed(.06),
          length: NumberRange.fixed(1.2),
        ),
        origin: const Vec3(-.5, .5, 0),
        speed: 2,
      ),
    );
    simulation.advance(const Duration(milliseconds: 800));
    final before = simulation.snapshot.single;
    final pixels = await raster(simulation, capture: 'flexible-ribbon');
    expect(visiblePixels(pixels), greaterThan(10));
    final after = simulation.snapshot.single;
    expect(after.nodes, before.nodes);
    simulation.dispose();
  });
}

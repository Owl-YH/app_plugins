import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import '../test/paper_aerodynamics_test.dart' show fallingPaper, sharpRectangle;
import '../test/time_helpers.dart';

/// 导出真实求解器轨迹；时间、坐标、姿态都来自模拟快照。
void main() {
  test('record reproducible flutter and tumble trajectories for the guide', () {
    final cases = <Map<String, Object>>[];
    for (final density in [.02, .08]) {
      final flight = fallingPaper(shape: sharpRectangle, density: density);
      final sim = flight.simulation;
      final samples = <List<double>>[];
      var previousAngle = 40 * math.pi / 180, pitch = previousAngle;
      var minPitch = pitch, maxPitch = pitch, maxSpin = 0.0, maxPlaneError = 0.0;
      for (var frame = 0; frame <= 360; frame++) {
        if (frame > 0) sim.advance(elapsedForFrame(frame - 1, 60));
        final p = sim.snapshot.single, r = p.widthDirections.single;
        final angle = math.atan2(r.dot(flight.down), r.dot(flight.across));
        pitch += math.atan2(math.sin(angle - previousAngle), math.cos(angle - previousAngle));
        previousAngle = angle;
        minPitch = math.min(minPitch, pitch);
        maxPitch = math.max(maxPitch, pitch);
        maxSpin = math.max(maxSpin, p.angularVelocity!.length);
        maxPlaneError = math.max(maxPlaneError, p.position.dot(flight.axis).abs());
        samples.add([
          frame / 60,
          p.position.dot(flight.across),
          p.position.dot(flight.down),
          pitch * 180 / math.pi,
          p.angularVelocity!.dot(flight.axis),
          p.kineticEnergy!,
          p.kineticEnergy! - p.mass! * sim.gravity.dot(p.position),
        ]);
      }
      final summary = <String, Object>{
        'id': density == .02 ? 'flutter' : 'tumble',
        'shape': 'sharp rectangle',
        'massPerArea': density,
        'width': .1,
        'height': .3,
        'releaseDegrees': 40,
        'initialSpeed': 0,
        'initialAngularSpeed': 0,
        'dragCoefficient': 1.15,
        'surfaceFriction': .02,
        'gravity': 9.81,
        'wind': 'still air',
        'seed': 12,
        'durationSeconds': 6,
        'sampleRate': 60,
        'pitchSpanDegrees': (maxPitch - minPitch) * 180 / math.pi,
        'maximumAngularSpeed': maxSpin,
        'maximumOutOfPlaneMetres': maxPlaneError,
        'invalidParticles': sim.stats.invalidParticles,
        'columns': [
          'timeSeconds',
          'acrossMetres',
          'downMetres',
          'pitchDegrees',
          'angularSpeed',
          'kineticJoules',
          'mechanicalJoules',
        ],
      };
      stdout.writeln(jsonEncode(summary));
      cases.add({...summary, 'samples': samples});
      expect(sim.stats.invalidParticles, 0);
      sim.dispose();
    }
    File(
      'docs/assets/paper-flight.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(cases));
  });
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'simulation_test.dart' show effect;

ConfettiSimulation flexiblePaper({
  double bending = .00002,
  double damping = 1.5,
  double drag = 1.15,
  double friction = .02,
  double spin = 0,
  double speed = 0,
  PaperShape shape = const PaperShape.rectangle(),
  double scale = .15,
}) {
  final sim = ConfettiSimulation(gravity: Vec3.zero);
  sim.emit(
    effect(
      speed: speed,
      lifetime: const Duration(seconds: 10),
      particle: PaperParticle.bend(
        shape: shape,
        size: PaperSize.proportional(NumberRange.fixed(scale)),
        bendingStiffness: bending,
        damping: damping,
        dragCoefficient: drag,
        surfaceFriction: friction,
        angularSpeed: NumberRange.fixed(spin),
      ),
    ),
  );
  return sim;
}

Vec3 sheetNormal(ParticleSnapshot p) {
  var normal = Vec3.zero;
  for (var i = 0; i < p.surfaceTriangles.length; i += 3) {
    final a = p.surfaceVertices[p.surfaceTriangles[i]],
        b = p.surfaceVertices[p.surfaceTriangles[i + 1]],
        c = p.surfaceVertices[p.surfaceTriangles[i + 2]];
    normal += (b - a).cross(c - a);
  }
  return normal.normalized();
}

double bendingDepth(ParticleSnapshot p) {
  final normal = sheetNormal(p);
  var low = double.infinity, high = double.negativeInfinity;
  for (final vertex in p.surfaceVertices) {
    final z = (vertex - p.position).dot(normal);
    low = math.min(low, z);
    high = math.max(high, z);
  }
  return high - low;
}

void loadPaper(ConfettiSimulation sim) {
  final p = sim.snapshot.single;
  sim.setWind(
    WindField(
      sources: [
        WindSource.local(
          velocity: sheetNormal(p) * 2,
          center: p.nodes.first,
          radius: .055,
          variation: 0,
        ),
      ],
    ),
    transition: Duration.zero,
  );
}

void main() {
  test(
    'bend validates bending inputs and noBend allocates no bending state',
    () {
      for (final recipe in [
        const PaperParticle.bend(bendingStiffness: 0),
        const PaperParticle.bend(maximumBendRatio: double.nan),
        const PaperParticle.bend(damping: -1),
      ]) {
        expect(() => ParticleChoice(particle: recipe), throwsArgumentError);
      }
      expect(const PaperParticle.noBend().bendEnabled, isFalse);
      expect(const PaperParticle.bend().bendEnabled, isTrue);
      final sim = ConfettiSimulation();
      addTearDown(sim.dispose);
      sim.emit(effect(particle: const PaperParticle.noBend()));
      final p = sim.snapshot.single;
      expect((p.particle as PaperParticle).bendEnabled, isFalse);
      expect(p.surfaceVertices, p.nodes);
      expect(p.surfaceTriangles.length, sim.stats.paperTriangles * 3);
      expect(p.elasticEnergy!, 0);
    },
  );

  test('material topology preserves concave area and has bounded work', () {
    final concave = PaperShape.polygon(
      vertices: const [
        ui.Offset(0, 0),
        ui.Offset(1, 0),
        ui.Offset(1, .2),
        ui.Offset(.2, .2),
        ui.Offset(.2, .8),
        ui.Offset(1, .8),
        ui.Offset(1, 1),
        ui.Offset(0, 1),
      ],
    );
    for (final shape in [
      const PaperShape.rectangle(),
      const PaperShape.circle(),
      const PaperShape.heart(),
      concave,
    ]) {
      final sim = flexiblePaper(shape: shape);
      addTearDown(sim.dispose);
      final p = sim.snapshot.single;
      var area = 0.0;
      var center = Vec3.zero;
      for (var i = 0; i < p.surfaceTriangles.length; i += 3) {
        final a = p.surfaceVertices[p.surfaceTriangles[i]],
            b = p.surfaceVertices[p.surfaceTriangles[i + 1]],
            c = p.surfaceVertices[p.surfaceTriangles[i + 2]];
        final weight = (b - a).cross(c - a).length / 2;
        area += weight;
        center += (a + b + c) * (weight / 3);
      }
      expect(area, closeTo(p.area!, 1e-12));
      expect((center / area - p.position).length, lessThan(1e-12));
      expect(p.mass!, closeTo(p.area! * .08, 1e-12));
      expect(
        p.surfaceTriangles.length ~/ 3,
        lessThanOrEqualTo(24 * sim.stats.paperTriangles),
      );
      expect(
        p.surfaceVertices.length,
        lessThanOrEqualTo(40 * sim.stats.paperTriangles + p.nodes.length),
      );
      expect(p.nodes, p.surfaceVertices.take(p.nodes.length).toList());
    }
  });

  test(
    'flexible flight respects uniform moving air reference frames and frame partitioning',
    () {
      const boost = Vec3(1.3, -.7, 2.1);
      final a = ConfettiSimulation(),
          b = ConfettiSimulation(
            wind: WindField(
              sources: [WindSource.global(velocity: boost, variation: 0)],
            ),
          );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      const recipe = PaperParticle.bend(
        shape: PaperShape.star(),
        angularSpeed: NumberRange.fixed(0),
      );
      a.emit(effect(particle: recipe, speed: 0));
      b.emit(effect(particle: recipe, speed: boost.length, direction: boost));
      a.advance(const Duration(seconds: 1));
      for (var i = 0; i < 100; i++) b.advance(const Duration(milliseconds: 10));
      final pa = a.snapshot.single, pb = b.snapshot.single;
      expect((pb.position - pa.position - boost).length, lessThan(1e-7));
      expect((pb.velocity - pa.velocity - boost).length, lessThan(1e-7));
      for (var i = 0; i < pa.surfaceVertices.length; i++) {
        expect(
          (pb.surfaceVertices[i] - pa.surfaceVertices[i] - boost).length,
          lessThan(1e-7),
        );
      }
    },
  );

  test(
    'material attachment uses the moving surface and lifetime releases its budget',
    () {
      final sim = ConfettiSimulation(gravity: Vec3.zero);
      addTearDown(sim.dispose);
      sim.emit(
        effect(
          particle: const PaperParticle.bend(),
          lifetime: const Duration(milliseconds: 100),
          speed: 0,
        ),
      );
      final before = sim.snapshot.single;
      loadPaper(sim);
      sim.advance(const Duration(milliseconds: 50));
      final after = sim.snapshot.single;
      expect(
        (after.materialPosition! - before.materialPosition!).length,
        greaterThan(1e-6),
      );
      expect(after.materialVelocity!.length, greaterThan(1e-5));
      sim.advance(const Duration(seconds: 1));
      expect(sim.snapshot, isEmpty);
      expect(sim.stats.paperTriangles, 0);
      expect(sim.isIdle, isTrue);
    },
  );

  test('small and stretched sheets remain finite under strong XYZ wind', () {
    for (final size in [
      const PaperSize.proportional(NumberRange.fixed(.0025)),
      const PaperSize.stretched(
        width: NumberRange.fixed(.002),
        height: NumberRange.fixed(.5),
      ),
    ]) {
      for (final shape in [
        const PaperShape.rectangle(),
        const PaperShape.heart(),
      ]) {
        final sim = ConfettiSimulation(
          wind: WindField(
            sources: [
              WindSource.global(velocity: const Vec3(15, -8, 20), variation: 0),
            ],
          ),
        );
        addTearDown(sim.dispose);
        sim.emit(
          effect(
            speed: 30,
            particle: PaperParticle.bend(
              shape: shape,
              size: size,
              massPerArea: .005,
              dragCoefficient: 4,
              surfaceFriction: 1,
              angularSpeed: const NumberRange.fixed(30),
            ),
          ),
        );
        sim.advance(const Duration(milliseconds: 500));
        expect(sim.stats.invalidParticles, 0);
        final p = sim.snapshot.single;
        expect(p.surfaceVertices.every((v) => v.isFinite), isTrue);
        expect(p.velocity.length, lessThan(100));
        expect(p.elasticEnergy!.isFinite, isTrue);
      }
    }
  });

  test('accepted material stiffness endpoints produce finite trajectories', () {
    for (final bending in [1e-8, 1.0])
      for (final maximum in [0.0, .05]) {
        final sim = ConfettiSimulation();
        addTearDown(sim.dispose);
        sim.emit(
          effect(
            particle: PaperParticle.bend(
              shape: const PaperShape.heart(),
              bendingStiffness: bending,
              maximumBendRatio: maximum,
              massPerArea: .005,
            ),
          ),
        );
        sim.advance(const Duration(milliseconds: 100));
        expect(sim.stats.invalidParticles, 0);
        expect(sim.snapshot.single.elasticEnergy!.isFinite, isTrue);
      }
  });

  test(
    'both long-edge choices remain a single shallow arc with a straight short edge',
    () {
      for (final alongX in [true, false]) {
        final sim = ConfettiSimulation(gravity: Vec3.zero);
        addTearDown(sim.dispose);
        sim.emit(
          effect(
            speed: 0,
            particle: PaperParticle.bend(
              size: PaperSize.stretched(
                width: NumberRange.fixed(alongX ? .3 : .1),
                height: NumberRange.fixed(alongX ? .1 : .3),
              ),
              angularSpeed: const NumberRange.fixed(0),
            ),
          ),
        );
        loadPaper(sim);
        for (var frame = 0; frame < 40; frame++) {
          sim.advance(const Duration(milliseconds: 10));
          final p = sim.snapshot.single, right = p.widthDirections.single;
          final normal = sheetNormal(p);
          final up = normal.cross(right).normalized();
          final q = p.bendRatio! * .3;
          expect(p.bendRatio!.abs(), lessThanOrEqualTo(.02 + 1e-12));
          double intercept(Vec3 vertex) {
            final r = vertex - p.position,
                coordinate = r.dot(alongX ? right : up);
            return r.dot(normal) + 4 * q * coordinate * coordinate / (.3 * .3);
          }

          final constant = intercept(p.surfaceVertices.first);
          for (final v in p.surfaceVertices)
            expect(intercept(v), closeTo(constant, 1e-10));
        }
        expect(sim.snapshot.single.elasticEnergy!, greaterThan(0));
      }
    },
  );

  test('zero bend limit uses exactly the rigid flight path', () {
    final a = ConfettiSimulation(), b = ConfettiSimulation();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    a.emit(effect(particle: const PaperParticle.bend(maximumBendRatio: 0)));
    b.emit(effect(particle: const PaperParticle.noBend()));
    a.advance(const Duration(milliseconds: 500));
    b.advance(const Duration(milliseconds: 500));
    expect(a.snapshot.single.nodes, b.snapshot.single.nodes);
    expect(a.snapshot.single.velocity, b.snapshot.single.velocity);
    expect(a.snapshot.single.bendRatio, 0);
  });

  test(
    'uniform vacuum gravity translates a flat sheet without bending or elastic energy',
    () {
      final sim = flexiblePaper(drag: 0, friction: 0, speed: 2);
      addTearDown(sim.dispose);
      final first = sim.snapshot.single;
      sim.gravity = const Vec3(2, 9, -1);
      sim.advance(const Duration(seconds: 1));
      final p = sim.snapshot.single;
      expect(
        (p.position - first.position - first.velocity - sim.gravity * .5)
            .length,
        lessThan(1e-8),
      );
      expect(
        (p.velocity - first.velocity - sim.gravity).length,
        lessThan(1e-8),
      );
      expect(bendingDepth(p), lessThan(1e-9));
      expect(p.elasticEnergy!, lessThan(1e-14));
      expect(p.angularVelocity!.length, lessThan(1e-8));
    },
  );

  test('local air bends material and a stiffer sheet responds less', () {
    final depths = <double>[];
    for (final stiffness in [.000002, .002]) {
      final sim = flexiblePaper(bending: stiffness);
      addTearDown(sim.dispose);
      loadPaper(sim);
      sim.advance(const Duration(milliseconds: 100));
      final p = sim.snapshot.single;
      depths.add(bendingDepth(p));
      expect(p.elasticEnergy!, greaterThan(1e-10));
      expect(sim.stats.invalidParticles, 0);
    }
    expect(depths.first, greaterThan(.0001));
    expect(depths.last, lessThan(depths.first * .7));
  });

  test('wind removal allows elastic recovery with bounded total energy', () {
    final sim = flexiblePaper(bending: .0002, damping: 10);
    addTearDown(sim.dispose);
    loadPaper(sim);
    sim.advance(const Duration(milliseconds: 150));
    final loaded = sim.snapshot.single, depth = bendingDepth(loaded);
    sim.setWind(WindField(), transition: Duration.zero);
    var minimum = depth, maxEnergy = 0.0;
    for (var i = 0; i < 100; i++) {
      sim.advance(const Duration(milliseconds: 10));
      final p = sim.snapshot.single;
      minimum = math.min(minimum, bendingDepth(p));
      maxEnergy = math.max(maxEnergy, p.kineticEnergy! + p.elasticEnergy!);
    }
    expect(minimum, lessThan(depth * .5));
    expect(
      maxEnergy,
      lessThan((loaded.kineticEnergy! + loaded.elasticEnergy!) * 1.02),
    );
    expect(sim.stats.invalidParticles, 0);
  });

  test(
    'unforced sheets do not gain mechanical energy across supported contours',
    () {
      for (final shape in [
        const PaperShape.rectangle(),
        const PaperShape.star(),
        const PaperShape.heart(),
      ]) {
        final sim = flexiblePaper(shape: shape, speed: 4, spin: 4);
        addTearDown(sim.dispose);
        final initial = sim.snapshot.single;
        var peak = initial.kineticEnergy!;
        for (var i = 0; i < 50; i++) {
          sim.advance(const Duration(milliseconds: 10));
          final p = sim.snapshot.single;
          peak = math.max(peak, p.kineticEnergy! + p.elasticEnergy!);
          expect(p.surfaceVertices.every((v) => v.isFinite), isTrue);
        }
        expect(peak, lessThanOrEqualTo(initial.kineticEnergy! * 1.01));
        expect(sim.stats.invalidParticles, 0);
      }
    },
  );
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'simulation_test.dart' show effect;

const fixedSize = PaperSize.proportional(NumberRange.fixed(.2));

ConfettiSimulation paper(
  PaperShape shape, {
  PaperSize size = fixedSize,
  double drag = 0,
  double friction = 0,
  double spin = 0,
  double speed = 0,
  int count = 1,
}) {
  final sim = ConfettiSimulation(gravity: Vec3.zero);
  addTearDown(sim.dispose);
  sim.emit(
    effect(
      speed: speed,
      count: count,
      particle: PaperParticle.noBend(
        shape: shape,
        size: size,
        dragCoefficient: drag,
        surfaceFriction: friction,
        angularSpeed: NumberRange.fixed(spin),
      ),
    ),
  );
  return sim;
}

Vec3 normal(ParticleSnapshot p) {
  var areaVector = Vec3.zero;
  for (var i = 0; i < p.nodes.length; i++) {
    areaVector += (p.nodes[i] - p.position).cross(
      p.nodes[(i + 1) % p.nodes.length] - p.position,
    );
  }
  return areaVector.normalized();
}

void wind(ConfettiSimulation sim, Vec3 velocity) => sim.setWind(
  WindField(sources: [WindSource.global(velocity: velocity, variation: 0)]),
  transition: Duration.zero,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'rectangles have built-in rounded corners with consistent material area',
    () {
      for (final aspect in [.01, 1.0, 2.0, 100.0]) {
        final p = paper(
          PaperShape.rectangle(aspectRatio: aspect),
        ).snapshot.single;
        final width = .2 * math.min(aspect, 1.0),
            height = .2 / math.max(aspect, 1.0);
        final radius = math.min(width, height) * .2;
        final expectedArea = width * height - (4 - math.pi) * radius * radius;
        // 四段圆弧近似的面积误差应小于半径平方的 9%。
        expect(p.area!, closeTo(expectedArea, radius * radius * .09 + 1e-12));
        expect(p.mass!, closeTo(p.area! * .08, 1e-15));
        expect(p.nodes.length, 20);
        final right = p.widthDirections.single, up = normal(p).cross(right);
        final xs = p.nodes.map((v) => (v - p.position).dot(right)).toList();
        final ys = p.nodes.map((v) => (v - p.position).dot(up)).toList();
        expect(
          xs.reduce(math.max) - xs.reduce(math.min),
          closeTo(width, 1e-10),
        );
        expect(
          ys.reduce(math.max) - ys.reduce(math.min),
          closeTo(height, 1e-10),
        );
        expect(p.area!, lessThan(width * height));
        // 尖角从材料轮廓切除，不能只是 Painter 的外观遮罩。
        expect(
          p.nodes.every(
            (v) =>
                (v - p.position).length <
                math.sqrt(width * width + height * height) / 2,
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'analytic areas and full rectangular inertia match real birth geometry',
    () {
      // 保留直角矩形的解析解基准；内置 rectangle 的圆角面积由独立用例验证。
      final square = PaperShape.polygon(
        vertices: const [
          ui.Offset(0, 0),
          ui.Offset(1, 0),
          ui.Offset(1, 1),
          ui.Offset(0, 1),
        ],
      );
      for (final (shape, expected, tolerance) in [
        (square, .04, 1e-12),
        (const PaperShape.triangle(), math.sqrt(3) * .01, 1e-12),
        (const PaperShape.circle(), math.pi * .01, .00006),
      ]) {
        final p = paper(shape, spin: 2).snapshot.single;
        expect(p.area!, closeTo(expected, tolerance));
        expect(p.mass!, closeTo(p.area! * .08, 1e-15));
      }
      final sim = paper(
        square,
        size: const PaperSize.stretched(
          width: NumberRange.fixed(.12),
          height: NumberRange.fixed(.24),
        ),
        spin: 3,
      );
      final p = sim.snapshot.single;
      final r = (p.nodes[1] - p.nodes[0]).normalized(),
          u = (p.nodes[2] - p.nodes[1]).normalized(),
          n = r.cross(u);
      final w = p.angularVelocity!;
      final expected =
          r * (p.mass! * .24 * .24 / 12 * w.dot(r)) +
          u * (p.mass! * .12 * .12 / 12 * w.dot(u)) +
          n * (p.mass! * (.12 * .12 + .24 * .24) / 12 * w.dot(n));
      expect((p.angularMomentum! - expected).length, lessThan(1e-15));
    },
  );

  test(
    'proportional sizes preserve circles and stretched sizes sample independently',
    () {
      final proportional = paper(
        const PaperShape.circle(),
        size: const PaperSize.proportional(NumberRange(.05, .1)),
        count: 30,
      );
      final widths = <double>{};
      for (final p in proportional.snapshot) {
        widths.add(p.width);
        for (final vertex in p.nodes)
          expect((vertex - p.position).length, closeTo(p.width * .5, 1e-12));
      }
      expect(widths.length, 30);
      final stretched = paper(
        const PaperShape.rectangle(),
        size: const PaperSize.stretched(
          width: NumberRange(.05, .1),
          height: NumberRange(.05, .1),
        ),
        count: 20,
      );
      expect(
        stretched.snapshot.any((p) {
          final up = normal(p).cross(p.widthDirections.single);
          final ys = p.nodes.map((v) => (v - p.position).dot(up)).toList();
          final height = ys.reduce(math.max) - ys.reduce(math.min);
          return (p.width - height).abs() > .001;
        }),
        isTrue,
      );
    },
  );

  test(
    'custom polygon and curved Path copy inputs and reject unsupported topology',
    () {
      final vertices = <ui.Offset>[
        const ui.Offset(0, 0),
        const ui.Offset(1, 0),
        const ui.Offset(0, 1),
      ];
      final polygon = PaperShape.polygon(vertices: vertices);
      vertices.clear();
      expect(paper(polygon).snapshot.single.area!, closeTo(.02, 1e-12));
      final path = ui.Path()..addOval(const ui.Rect.fromLTWH(0, 0, 100, 100));
      final curved = PaperShape.path(path);
      path.reset();
      expect(
        paper(curved).snapshot.single.area!,
        closeTo(math.pi * .01, .0002),
      );
      for (final invalid in [
        [
          const ui.Offset(0, 0),
          const ui.Offset(1, 1),
          const ui.Offset(0, 1),
          const ui.Offset(1, 0),
        ],
        [const ui.Offset(0, 0), const ui.Offset(1, 0), const ui.Offset(2, 0)],
        [
          const ui.Offset(double.nan, 0),
          const ui.Offset(1, 0),
          const ui.Offset(0, 1),
        ],
        List.generate(
          130,
          (i) => ui.Offset(
            math.cos(i / 130 * 2 * math.pi),
            math.sin(i / 130 * 2 * math.pi),
          ),
        ),
      ])
        expect(
          () => PaperShape.polygon(vertices: invalid),
          throwsArgumentError,
        );
      expect(
        () => PaperShape.path(
          ui.Path()
            ..moveTo(0, 0)
            ..lineTo(1, 0)
            ..lineTo(0, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => PaperShape.path(
          ui.Path()
            ..addRect(const ui.Rect.fromLTWH(0, 0, 1, 1))
            ..addRect(const ui.Rect.fromLTWH(.2, .2, .2, .2)),
        ),
        throwsArgumentError,
      );
      expect(
        () => ParticleChoice(
          particle: const PaperParticle.noBend(
            shape: PaperShape.star(points: 2),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => ParticleChoice(
          particle: const PaperParticle.noBend(surfaceFriction: -1),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'normal and tangential air coefficients independently control real motion',
    () {
      for (final alongNormal in [true, false]) {
        for (final enabled in [true, false]) {
          final sim = paper(
            const PaperShape.rectangle(),
            drag: alongNormal && enabled ? 1.15 : 0,
            friction: !alongNormal && enabled ? .2 : 0,
          );
          final p = sim.snapshot.single;
          final direction = alongNormal
              ? normal(p)
              : (p.nodes[1] - p.nodes[0]).normalized();
          wind(sim, direction * 3);
          sim.advance(const Duration(milliseconds: 200));
          final after = sim.snapshot.single;
          expect(
            after.velocity.dot(direction),
            enabled ? greaterThan(.15) : closeTo(0, 1e-12),
          );
          expect(after.angularVelocity!.length, lessThan(1e-9));
        }
      }
      // 切向风不应被纯法向系数减速，纯法向风不应被切向系数减速。
      for (final normalOnly in [true, false]) {
        final sim = paper(
          const PaperShape.rectangle(),
          drag: normalOnly ? 1.15 : 0,
          friction: normalOnly ? 0 : .2,
        );
        final p = sim.snapshot.single;
        wind(
          sim,
          (normalOnly ? (p.nodes[1] - p.nodes[0]).normalized() : normal(p)) * 3,
        );
        sim.advance(const Duration(milliseconds: 200));
        expect(sim.snapshot.single.velocity.length, lessThan(1e-10));
      }
    },
  );

  test(
    'vacuum preserves free angular momentum and energy while air dissipates spin',
    () {
      final shape = PaperShape.polygon(
        vertices: const [
          ui.Offset(0, 0),
          ui.Offset(1, 0),
          ui.Offset(.3, .7),
          ui.Offset(0, 1),
        ],
      );
      final free = paper(shape, spin: 5, speed: 2);
      wind(free, const Vec3(3, -7, 9));
      final before = free.snapshot.single;
      free.advance(const Duration(seconds: 2));
      final after = free.snapshot.single;
      expect(
        (after.angularMomentum! - before.angularMomentum!).length,
        lessThan(1e-12),
      );
      expect(after.velocity, before.velocity);
      expect(
        after.kineticEnergy!,
        closeTo(before.kineticEnergy!, before.kineticEnergy! * .001),
      );
      final damped = paper(shape, drag: 1.15, friction: .1, spin: 5, speed: 0);
      var energy = damped.snapshot.single.kineticEnergy!;
      for (var i = 0; i < 20; i++) {
        damped.advance(const Duration(milliseconds: 50));
        final current = damped.snapshot.single.kineticEnergy!;
        expect(current, lessThanOrEqualTo(energy * 1.001));
        energy = current;
      }
    },
  );

  test(
    'concave centroid remains physical with a valid rotating material diagnostic point',
    () {
      final shape = PaperShape.polygon(
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
      final sim = paper(
        shape,
        spin: 3,
        size: const PaperSize.stretched(
          width: NumberRange.fixed(.4),
          height: NumberRange.fixed(.12),
        ),
      );
      final p = sim.snapshot.single;
      expect((p.materialPosition! - p.position).length, greaterThan(.01));
      final expected =
          p.velocity +
          p.angularVelocity!.cross(p.materialPosition! - p.position);
      expect((p.materialVelocity! - expected).length, lessThan(1e-12));
      final arm = (p.materialPosition! - p.position).length;
      var nearest = double.infinity;
      for (var i = 0; i < p.nodes.length; i++) {
        final a = p.nodes[i] - p.position,
            edge = p.nodes[(i + 1) % p.nodes.length] - p.nodes[i];
        final t = (-a.dot(edge) / edge.lengthSquared).clamp(0.0, 1.0);
        final distance = (a + edge * t).length;
        if (distance < nearest) nearest = distance;
      }
      expect(arm, closeTo(nearest, 1e-12));
      sim.advance(const Duration(milliseconds: 500));
      expect(
        (sim.snapshot.single.materialPosition! - sim.snapshot.single.position)
            .length,
        closeTo(arm, 1e-12),
      );
    },
  );

  test(
    'shape mixing reuses weights, survives frame partitioning and releases budgets',
    () async {
      final shapes = [
        const PaperShape.rectangle(),
        const PaperShape.circle(),
        const PaperShape.triangle(),
        const PaperShape.star(),
        const PaperShape.heart(),
        PaperShape.polygon(
          vertices: const [
            ui.Offset(0, 0),
            ui.Offset(1, 0),
            ui.Offset(.3, .5),
            ui.Offset(0, 1),
          ],
        ),
      ];
      final choices = [
        for (final shape in shapes)
          ParticleChoice(
            particle: PaperParticle.noBend(shape: shape, size: fixedSize),
          ),
        ParticleChoice(particle: const RibbonParticle(segments: 4)),
      ];
      final recipe = ConfettiEffect(
        seed: 42,
        emitters: [
          ConfettiEmitter.stream(
            particles: choices,
            burstCount: 50,
            rate: 20,
            duration: const Duration(seconds: 1),
            lifetime: const ParticleLifetime(
              duration: DurationRange.fixed(Duration(seconds: 2)),
            ),
          ),
        ],
      );
      final a = ConfettiSimulation(), b = ConfettiSimulation();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final playback = a.emit(recipe);
      b.emit(recipe);
      a.advance(const Duration(milliseconds: 500));
      for (var i = 0; i < 10; i++) b.advance(const Duration(milliseconds: 50));
      expect(a.snapshot.length, 60);
      for (var i = 0; i < a.snapshot.length; i++) {
        expect(a.snapshot[i].particle, b.snapshot[i].particle);
        expect(a.snapshot[i].nodes, b.snapshot[i].nodes);
      }
      expect(a.snapshot.map((p) => p.particle).toSet().length, 7);
      expect(a.stats.paperTriangles, greaterThan(0));
      a.advance(const Duration(seconds: 4));
      expect(await playback.done, ConfettiCompletion.completed);
      expect(a.stats.paperTriangles, 0);
      final limited = ConfettiSimulation(
        limits: const ConfettiLimits(paperTriangles: 1),
      );
      addTearDown(limited.dispose);
      limited.emit(effect(count: 3));
      expect(limited.stats.capacityRejections, 3);
      expect(limited.stats.particles, 0);
    },
  );

  test(
    'rounded and concave raster agrees with Flutter path filling without internal gaps',
    () async {
      for (final shape in [
        const PaperShape.rectangle(),
        const PaperShape.star(),
        const PaperShape.heart(),
      ]) {
        final sim = paper(
          shape,
          size: const PaperSize.proportional(NumberRange.fixed(.5)),
        );
        const camera = ConfettiCamera(viewHeight: .7),
            viewport = ui.Size(420, 420);
        final p = sim.snapshot.single;
        final projected = [
          for (final v in p.nodes) camera.project(v, viewport)!,
        ];
        Future<List<int>> alpha(bool reference) async {
          final recorder = ui.PictureRecorder();
          // 每次绘制独立 Picture；参考填充走 Flutter Path，不复用插件三角化。
          final target = ui.Canvas(recorder);
          if (reference) {
            final path = ui.Path()..addPolygon(projected, true);
            target.drawPath(
              path,
              ui.Paint()
                ..color = const ui.Color(0xffffffff)
                ..isAntiAlias = false,
            );
          } else {
            ConfettiPainter(
              simulation: sim,
              camera: camera,
            ).paint(target, viewport);
          }
          final picture = recorder.endRecording();
          final image = await picture.toImage(420, 420);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final result = [
            for (var i = 3; i < data.length; i += 4) data[i] > 127 ? 1 : 0,
          ];
          image.dispose();
          picture.dispose();
          return result;
        }

        final actual = await alpha(false), expected = await alpha(true);
        var filled = 0, differing = 0;
        for (var i = 0; i < actual.length; i++) {
          filled += expected[i];
          differing += actual[i] == expected[i] ? 0 : 1;
        }
        expect(filled, greaterThan(100));
        expect(differing / filled, lessThan(.025));
      }
    },
  );

  test(
    'concave clipping agrees with independent ray and contour intersections',
    () async {
      const camera = ConfettiCamera(
        viewHeight: 1,
        distance: 1,
        near: .5,
        far: 1.1,
      );
      const viewport = ui.Size(180, 180);
      for (final z in [.5, -.1]) {
        final sim = ConfettiSimulation(gravity: Vec3.zero);
        addTearDown(sim.dispose);
        sim.emit(
          effect(
            origin: Vec3(0, 0, z),
            speed: 0,
            particle: const PaperParticle.noBend(
              shape: PaperShape.star(),
              size: PaperSize.proportional(NumberRange.fixed(.5)),
              angularSpeed: NumberRange.fixed(0),
            ),
          ),
        );
        final p = sim.snapshot.single, n = normal(sim.snapshot.single);
        final r = p.widthDirections.single, u = n.cross(r);
        final path = ui.Path()
          ..addPolygon([
            for (final v in p.nodes)
              ui.Offset((v - p.position).dot(r), (v - p.position).dot(u)),
          ], true);
        final recorder = ui.PictureRecorder();
        ConfettiPainter(
          simulation: sim,
          camera: camera,
        ).paint(ui.Canvas(recorder), viewport);
        final picture = recorder.endRecording(),
            image = await recorderImage(picture);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var filled = 0, difference = 0;
        const eye = Vec3(0, 0, 1);
        for (var y = 0; y < 180; y++) {
          for (var x = 0; x < 180; x++) {
            final ray = Vec3((x + .5 - 90) / 180, (y + .5 - 90) / 180, -1);
            final t = n.dot(p.position - eye) / n.dot(ray);
            final hit = eye + ray * t, arm = hit - p.position;
            final expected =
                t >= camera.near &&
                t <= camera.far &&
                path.contains(ui.Offset(arm.dot(r), arm.dot(u)));
            final actual = bytes[(y * 180 + x) * 4 + 3] > 127;
            if (expected) filled++;
            if (actual != expected) difference++;
          }
        }
        image.dispose();
        picture.dispose();
        expect(filled, greaterThan(20));
        expect(difference / filled, lessThan(.06));
      }
    },
  );
}

Future<ui.Image> recorderImage(ui.Picture picture) => picture.toImage(180, 180);
